// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { IMultiVault, ApprovalTypes, VaultState, VaultType } from "src/interfaces/IMultiVault.sol";
import { IAtomWallet } from "src/interfaces/IAtomWallet.sol";
import {
    IMultiVaultCore,
    GeneralConfig,
    AtomConfig,
    AtomUriConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { MultiVaultLib } from "src/libraries/MultiVaultLib.sol";

/**
 * @title  MultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated with atoms & triples using TRUST as the base asset.
 *
 * @dev    Heavy write-path bodies (`createAtoms`, `createTriples`, `deposit`, `depositBatch`,
 *         `redeem`, `redeemBatch`, plus the full transitive call graph they used to inline) live in
 *         {MultiVaultLib}, a separately-deployed `public`-function library linked into this
 *         contract's bytecode via the Solidity placeholder mechanism. Every library call from this
 *         contract compiles to a single `DELEGATECALL`, under which the library executes in this
 *         contract's storage context (`address(this)`, `msg.sender`, `msg.value`, and storage all
 *         reflect the {MultiVault} call). The split itself is a pure-refactor for runtime bytecode
 *         size; storage layout, function selectors, errors, events, and semantics are unchanged by
 *         the extraction. Subsequent upgrades may extend the contract — including appending new
 *         state — provided storage extensions remain append-only at the tail of the layout and the
 *         {MultiVaultLib.Storage} mirror stays slot-aligned with the contract, so previously
 *         occupied slot positions are preserved across upgrades.
 */
contract MultiVault is
    IMultiVault,
    MultiVaultCore,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using FixedPointMathLib for uint256;

    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    /// @notice Maximum number of actions allowed in a single batch
    /// @dev    Source of truth lives in {MultiVaultLib} so the library and the migrated bodies stay
    ///         in sync; this re-export preserves the `MAX_BATCH_SIZE()` public-getter selector.
    uint256 public constant MAX_BATCH_SIZE = MultiVaultLib.MAX_BATCH_SIZE;

    /// @notice Constant representing the burn address, which receives the "ghost (min) shares"
    /// @dev    Source of truth lives in {MultiVaultLib} so the library and the migrated bodies stay
    ///         in sync; this re-export preserves the `BURN_ADDRESS()` public-getter selector.
    address public constant BURN_ADDRESS = MultiVaultLib.BURN_ADDRESS;

    /// @notice Role identifier for addresses that can pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint32 private constant DEFAULT_ATOM_URI_COUNT = 5;
    uint32 private constant DEFAULT_ATOM_URI_LENGTH = 700;

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    /// @notice Mapping of the receiver's approved status for a given sender.
    /// @dev Stored value is the bit-flag union of DEPOSIT (0b001), REDEMPTION
    ///      (0b010), and CREATION (0b100). Spans `[0, 7]`; see {ApprovalTypes}
    ///      in {IMultiVault} for the full enumeration of named combinations.
    mapping(address receiver => mapping(address sender => uint8 approvalType)) internal approvals;

    /// @notice Mapping of term ID to bonding curve ID to vault state
    // Term ID (atom or triple ID) -> Bonding Curve ID -> Vault State
    mapping(bytes32 termId => mapping(uint256 curveId => VaultState vaultState)) internal _vaults;

    /// @notice Mapping of the accumulated protocol fees for each epoch
    // Epoch -> Accumulated protocol fees
    mapping(uint256 epoch => uint256 accumulatedFees) public accumulatedProtocolFees;

    /// @notice Mapping of the atom wallet address to the accumulated fees for that wallet
    // Atom wallet address -> Accumulated fees
    mapping(address atomWallet => uint256 accumulatedFees) public accumulatedAtomWalletDepositFees;

    /// @notice Mapping of the TRUST token amount utilization for each epoch
    /// @dev Epoch -> aggregate TRUST moved through the protocol by all users during that epoch.
    ///      Credited on deposit with the full amount sent in, and debited on redeem with the asset value that
    ///      leaves the vault. Those two bases differ by the fees charged on the way in, so aggregate activity
    ///      that deposits and then fully redeems does NOT net back to its prior value. See
    ///      `personalUtilization` for the full rationale; the same semantics apply here.
    mapping(uint256 epoch => int256 utilizationAmount) public totalUtilization;

    /// @notice Mapping of the TRUST token amount utilization for each user in each epoch
    /// @dev User -> Epoch -> TRUST moved through the protocol by that user during that epoch.
    ///      Utilization is credited on deposit with the FULL amount sent in (`msg.value`) and debited on redeem
    ///      with the asset value that LEAVES the vault for the redeemed shares (`rawAssetsBeforeFees`). Those two
    ///      bases deliberately differ by the fees charged on the way in, so a deposit followed by a full redeem
    ///      intentionally does NOT net to zero: it leaves a residue equal to the fees the user paid and the
    ///      protocol retained.
    ///
    ///      This asymmetry is by design. Utilization measures a user's net economic contribution to the protocol
    ///      during the epoch — capital committed, plus the fees they contributed — and NOT their vault balance.
    ///      There is deliberately NO invariant that `personalUtilization` equals a user's share value or TVL, and
    ///      NO invariant that a deposit/redeem round-trip restores it to its prior value. Consumers must not
    ///      assume either property.
    ///
    ///      Utilization is also deliberately NOT time-weighted. It is a running signed counter mutated at the
    ///      moment of each deposit and redeem; it carries no notion of how long capital stayed in the vault.
    ///      Capital committed in the final block of an epoch counts exactly the same as identical capital held
    ///      for the whole epoch. This is intentional — utilization gates reward eligibility on activity, not on
    ///      duration, because duration is already priced by the bonding lock in `TrustBonding`. Consumers must
    ///      NOT read this as a time-weighted average balance.
    mapping(address user => mapping(uint256 epoch => int256 utilizationAmount)) public personalUtilization;

    /// @notice Mapping of the last 3 active epochs for each user
    mapping(address user => uint256[3] epoch) public userEpochHistory;

    /// @notice Tracks whether system-wide utilization rollover has been initialized for a given epoch
    mapping(uint256 epoch => bool hasRolledOver) public hasRolledOverSystemUtilization;

    /// @notice The address of the parameters timelock controller
    address public timelock;

    /// @notice Mapping of atom IDs to the creator who created them on-chain.
    ///         Defaults to address(0) for atoms created before the upgrade.
    mapping(bytes32 atomId => address creator) public atomCreators;

    /// @notice Mapping of atom IDs to the timestamp at which they were created on-chain.
    ///         Defaults to 0 for atoms created before the upgrade.
    mapping(bytes32 atomId => uint48 createdAt) public atomCreatedAt;

    /// @notice Most recent epoch at which system-utilization carry-forward ran inside `_rollover`.
    ///         The system-side mirror of the per-user `userEpochHistory[user][0]` shape, used as the
    ///         source-of-truth for the carry so utilization survives multi-epoch quiescence. The
    ///         slot is pre-seeded by {reinitialize} to the current epoch at upgrade time, so every
    ///         post-upgrade rollover reads a meaningful source.
    uint256 public lastSystemUtilizationEpoch;

    /// @dev Atom URI limits added in the first reserved storage slot. Zero values
    ///      resolve to protocol defaults so upgraded proxies are safe before the
    ///      timelock writes an explicit configuration.
    AtomUriConfig private _atomUriConfig;

    /// @dev Storage gap for future upgrade safety
    uint256[46] private __gap;

    /* =================================================== */
    /*                  TRANSIENT STATE                    */
    /* =================================================== */

    /// @dev Set to true while a multicall is active.
    ///      Lives in transient storage (EIP-1153) so it is reset between
    ///      transactions and does not consume persistent storage slots.
    ///      EIP-1153 requires a Cancun+ chain; the Intuition deployment target
    ///      supports transient storage.
    bool private transient _inMulticall;

    /// @dev Per-sub-call value allocated by `multicall`. Read by
    ///      `_effectiveMsgValue()` so payable entry points see their share
    ///      of the outer transaction's `msg.value` instead of the full
    ///      `CALLVALUE` propagated by `delegatecall`.
    uint256 private transient _virtualMsgValue;

    /* =================================================== */
    /*                        Errors                       */
    /* =================================================== */

    error MultiVault_ArraysNotSameLength();

    error MultiVault_AtomExists(bytes atomData);

    error MultiVault_AtomDoesNotExist(bytes32 atomId);

    error MultiVault_AtomDataTooLong();

    error MultiVault_AtomUriCountExceeded();

    error MultiVault_AtomUriLengthExceeded();

    error MultiVault_BurnFromZeroAddress();

    /// @notice Thrown when a redemption's total fees would consume the entire payout, leaving the
    ///         redeemer with zero assets for burned shares.
    error MultiVault_RedeemYieldsNoAssets();

    error MultiVault_BurnInsufficientBalance();

    error MultiVault_CannotApproveOrRevokeSelf();

    error MultiVault_DepositBelowMinimumDeposit();

    error MultiVault_DepositOrRedeemZeroShares();

    error MultiVault_HasCounterStake();

    error MultiVault_InvalidArrayLength();

    error MultiVault_InsufficientAssets();

    error MultiVault_InsufficientBalance();

    error MultiVault_InsufficientRemainingSharesInVault(uint256 remainingShares);

    error MultiVault_InsufficientSharesInVault();

    error MultiVault_NoAtomDataProvided();

    error MultiVault_OnlyAssociatedAtomWallet();

    error MultiVault_CreatorNotApproved();

    error MultiVault_RedeemerNotApproved();

    error MultiVault_SenderNotApproved();

    error MultiVault_SlippageExceeded();

    error MultiVault_TripleExists(bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId);

    error MultiVault_TermNotTriple();

    error MultiVault_ActionExceedsMaxAssets();

    error MultiVault_ActionExceedsMaxShares();

    error MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();

    error MultiVault_DepositTooSmallToCoverMinShares();

    error MultiVault_CannotDirectlyInitializeCounterTriple();

    error MultiVault_TermDoesNotExist(bytes32 termId);

    error MultiVault_EpochNotTracked();

    error MultiVault_InvalidEpoch();

    error MultiVault_InvalidAtomUriConfig();

    error MultiVault_OnlyTimelock();

    error MultiVault_ZeroAddress();

    error MultiVault_MulticallValueMismatch();

    error MultiVault_NestedMulticall();

    error MultiVault_UnexpectedValue();

    /* =================================================== */
    /*                      MODIFIERS                      */
    /* =================================================== */

    /// @notice Restricts function access to the timelock controller
    modifier onlyTimelock() {
        _checkTimelock();
        _;
    }

    /// @dev Rejects value attributed to entry points that do not consume it.
    ///      Inside a multicall this checks the leg's virtual allocation; on a
    ///      direct call it checks the physical `msg.value`.
    modifier requiresZeroValue() {
        _checkZeroValue();
        _;
    }

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializer function for the MultiVault contract
    /// @param _generalConfig General configuration parameters for the MultiVault
    /// @param _atomConfig Atom-specific configuration parameters
    /// @param _tripleConfig Triple-specific configuration parameters
    /// @param _walletConfig AtomWallet-specific configuration parameters
    /// @param _vaultFees Fee structure for the vault operations
    /// @param _bondingCurveConfig Configuration parameters for the bonding curves
    function initialize(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _vaultFees,
        BondingCurveConfig memory _bondingCurveConfig
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __MultiVaultCore_init(
            _generalConfig, _atomConfig, _tripleConfig, _walletConfig, _vaultFees, _bondingCurveConfig
        );
        _grantRole(DEFAULT_ADMIN_ROLE, _generalConfig.admin);
    }

    /// @notice Reinitializer to bootstrap the timelock address after upgrade and pre-seed the
    ///         system-utilization rollover source slot to the current epoch.
    /// @param _timelock The timelock controller address
    function reinitialize(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE) reinitializer(2) {
        _setTimelock(_timelock);
        _grantRole(PAUSER_ROLE, generalConfig.admin);
        // Pre-seed the system-utilization rollover source so the first post-upgrade
        // `_rollover` reads a meaningful epoch instead of slot zero.
        lastSystemUtilizationEpoch = _currentEpoch();
    }

    /* =================================================== */
    /*                        VIEWS                        */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function isTermCreated(bytes32 id) external view returns (bool) {
        return MultiVaultLib.isTermCreated(id);
    }

    /// @inheritdoc IMultiVaultCore
    function getAtomUriConfig() external view returns (uint32 maxUriCount, uint32 maxUriLength) {
        AtomUriConfig memory config = _atomUriConfig;
        maxUriCount = config.maxUriCount == 0 ? DEFAULT_ATOM_URI_COUNT : config.maxUriCount;
        maxUriLength = config.maxUriLength == 0 ? DEFAULT_ATOM_URI_LENGTH : config.maxUriLength;
    }

    /// @inheritdoc IMultiVault
    function protocolFeeAmount(uint256 assets) external view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.protocolFee);
    }

    /// @inheritdoc IMultiVault
    function entryFeeAmount(uint256 assets) external view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.entryFee);
    }

    /// @inheritdoc IMultiVault
    function exitFeeAmount(uint256 assets) external view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.exitFee);
    }

    /// @inheritdoc IMultiVault
    function atomDepositFractionAmount(uint256 assets) external view returns (uint256) {
        return _feeOnRaw(assets, tripleConfig.atomDepositFractionForTriple);
    }

    /// @inheritdoc IMultiVault
    function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256) {
        return totalUtilization[epoch];
    }

    /// @inheritdoc IMultiVault
    function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256) {
        return personalUtilization[user][epoch];
    }

    /// @inheritdoc IMultiVault
    function getUserLastActiveEpoch(address user) external view returns (uint256) {
        return userEpochHistory[user][0];
    }

    /// @inheritdoc IMultiVault
    function getUserUtilizationInEpoch(address user, uint256 epoch) external view returns (int256) {
        return MultiVaultLib.getUserUtilizationInEpoch(user, epoch);
    }

    /// @inheritdoc IMultiVault
    function getAtomWarden() external view returns (address) {
        return walletConfig.atomWarden;
    }

    /// @inheritdoc IMultiVault
    function getAtomCreator(bytes32 termId) external view override(IMultiVault, IMultiVaultCore) returns (address) {
        return atomCreators[termId];
    }

    /// @inheritdoc IMultiVault
    function getAtomCreatedAt(bytes32 termId) external view override(IMultiVault, IMultiVaultCore) returns (uint48) {
        return atomCreatedAt[termId];
    }

    /// @inheritdoc IMultiVault
    function getVault(bytes32 termId, uint256 curveId) external view returns (uint256, uint256) {
        VaultState storage vault = _vaults[termId][curveId];
        return (vault.totalAssets, vault.totalShares);
    }

    /// @inheritdoc IMultiVault
    function getShares(address account, bytes32 termId, uint256 curveId) public view returns (uint256) {
        return _vaults[termId][curveId].balanceOf[account];
    }

    /// @inheritdoc IMultiVault
    function computeAtomWalletAddr(bytes32 atomId) external view returns (address) {
        return _computeAtomWalletAddr(atomId);
    }

    /// @inheritdoc IMultiVault
    function maxRedeem(address sender, bytes32 termId, uint256 curveId) external view returns (uint256) {
        return MultiVaultLib.maxRedeem(sender, termId, curveId);
    }

    /// @inheritdoc IMultiVault
    function isApprovedToDeposit(address sender, address receiver) external view returns (bool approved) {
        return MultiVaultLib.isApprovedToDeposit(sender, receiver);
    }

    /// @inheritdoc IMultiVault
    function isApprovedToRedeem(address sender, address receiver) external view returns (bool approved) {
        return MultiVaultLib.isApprovedToRedeem(sender, receiver);
    }

    /// @inheritdoc IMultiVault
    function isApprovedToCreate(address sender, address creator) external view returns (bool approved) {
        return MultiVaultLib.isApprovedToCreate(sender, creator);
    }

    /// @inheritdoc IMultiVault
    function currentEpoch() external view returns (uint256) {
        return _currentEpoch();
    }

    /// @inheritdoc IMultiVault
    function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256) {
        return MultiVaultLib.currentSharePrice(termId, curveId);
    }

    /// @inheritdoc IMultiVault
    function previewAtomCreate(bytes32 termId, uint256 assets)
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return MultiVaultLib.calculateAtomCreate(termId, assets);
    }

    /// @inheritdoc IMultiVault
    function previewTripleCreate(bytes32 termId, uint256 assets)
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return MultiVaultLib.calculateTripleCreate(termId, assets);
    }

    /// @inheritdoc IMultiVault
    function previewDeposit(bytes32 termId, uint256 curveId, uint256 assets)
        public
        view
        returns (uint256 shares, uint256 assetsAfterFees)
    {
        if (!MultiVaultLib.isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        bool isAtomVault = _isAtom(termId);
        (shares,, assetsAfterFees) = MultiVaultLib.calculateDeposit(termId, curveId, assets, isAtomVault);
    }

    /// @inheritdoc IMultiVault
    function previewRedeem(bytes32 termId, uint256 curveId, uint256 shares)
        public
        view
        returns (uint256 assetsAfterFees, uint256 sharesUsed)
    {
        if (!MultiVaultLib.isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return MultiVaultLib.calculateRedeem(termId, curveId, shares);
    }

    /// @inheritdoc IMultiVault
    function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) external view returns (uint256) {
        if (!MultiVaultLib.isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return MultiVaultLib.convertToShares(termId, curveId, assets);
    }

    /// @inheritdoc IMultiVault
    function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256) {
        if (!MultiVaultLib.isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return _convertToAssets(termId, curveId, shares);
    }

    /* =================================================== */
    /*                      Approvals                      */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function approve(address sender, ApprovalTypes approvalType) external payable requiresZeroValue nonReentrant {
        address receiver = msg.sender;

        if (receiver == sender) {
            revert MultiVault_CannotApproveOrRevokeSelf();
        }

        if (approvalType == ApprovalTypes.NONE) {
            delete approvals[receiver][sender];
        } else {
            approvals[receiver][sender] = uint8(approvalType);
        }

        emit ApprovalTypeUpdated(sender, receiver, approvalType);
    }

    /* =================================================== */
    /*                     Multicall                       */
    /* =================================================== */

    /// @notice Execute calls on this contract atomically with explicit per-call
    ///         value allocation.
    /// @dev    The sum of `values` must equal `msg.value`. Each sub-call is
    ///         dispatched through `delegatecall` so it preserves the original
    ///         `msg.sender`, storage context, and modifier checks. Payable write
    ///         paths consume only their virtual allocation through
    ///         `_effectiveMsgValue`; `redeem`, `redeemBatch`, and `approve`
    ///         require an allocation of zero.
    ///
    ///         A zero-value batch can call the full entry-point surface. In a
    ///         value-bearing batch, Solidity's dispatcher still rejects other
    ///         non-payable functions, including view functions, because every
    ///         delegatecall observes the outer call's physical `CALLVALUE`.
    ///
    ///         SECURITY INVARIANT: every payable external entry point added in
    ///         a future upgrade, other than this dispatcher, must be
    ///         `nonReentrant` and must either consume only
    ///         `_effectiveMsgValue()` or enforce `requiresZeroValue`. Any
    ///         multicall-compatible path that yields external control must also
    ///         be `nonReentrant`. Reading raw `msg.value`, ignoring an allocated
    ///         value, or yielding control without the guard is unsafe while the
    ///         transient multicall context is active.
    ///
    ///         Nested multicalls are rejected by `_inMulticall`. The first
    ///         sub-call revert bubbles raw revert data unchanged.
    /// @param  data The array of ABI-encoded calls to execute against this contract
    /// @param  values The array of per-sub-call value allocations; must satisfy
    ///         `sum(values) == msg.value`
    /// @return results The array of return data from each sub-call
    function multicall(bytes[] calldata data, uint256[] calldata values)
        external
        payable
        returns (bytes[] memory results)
    {
        if (_inMulticall) revert MultiVault_NestedMulticall();
        if (data.length != values.length) revert MultiVault_ArraysNotSameLength();

        uint256 length = data.length;
        uint256 total;
        for (uint256 i = 0; i < length;) {
            total += values[i];
            unchecked {
                ++i;
            }
        }
        if (total != msg.value) revert MultiVault_MulticallValueMismatch();

        _inMulticall = true;
        results = new bytes[](length);

        for (uint256 i = 0; i < length;) {
            _virtualMsgValue = values[i];
            (bool ok, bytes memory ret) = address(this).delegatecall(data[i]);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
            results[i] = ret;
            unchecked {
                ++i;
            }
        }

        _virtualMsgValue = 0;
        _inMulticall = false;
    }

    /// @dev Returns the effective `msg.value` for the currently executing
    ///      payable entry point. Inside `multicall`, this is the
    ///      per-sub-call allocation set in `_virtualMsgValue`; outside any
    ///      multicall, it is the raw `msg.value` of the direct call.
    function _effectiveMsgValue() internal view returns (uint256) {
        return _inMulticall ? _virtualMsgValue : msg.value;
    }

    /// @dev Shared implementation for the `requiresZeroValue` entry-point guard.
    function _checkZeroValue() internal view {
        if (_effectiveMsgValue() != 0) revert MultiVault_UnexpectedValue();
    }

    /* =================================================== */
    /*               WRITE PATHS (FORWARDED)               */
    /* =================================================== */
    /* Every external write-path body lives in {MultiVaultLib}. Each forward below is one
       `DELEGATECALL` from this contract into the library; the library executes the entire call
       graph (validation, fee accounting, vault mutations, event emission) in this contract's
       storage context before returning. Modifiers (`whenNotPaused`, `nonReentrant`, role checks)
       execute on this contract before the forward — they need slots on this contract's storage. */

    /// @inheritdoc IMultiVault
    function createAtoms(bytes[] calldata data, uint256[] calldata assets)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32[] memory)
    {
        return MultiVaultLib.createAtoms(data, assets, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function createAtomsWithUris(
        address creator,
        bytes[] calldata data,
        uint256[] calldata assets,
        bytes[][] calldata uris
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory) {
        return MultiVaultLib.createAtomsWithUris(creator, data, assets, uris, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory) {
        return MultiVaultLib.createTriples(subjectIds, predicateIds, objectIds, assets, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function createAtomsFor(address creator, bytes[] calldata data, uint256[] calldata assets)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32[] memory)
    {
        return MultiVaultLib.createAtomsFor(creator, data, assets, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function createTriplesFor(
        address creator,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory) {
        return MultiVaultLib.createTriplesFor(
            creator, subjectIds, predicateIds, objectIds, assets, _effectiveMsgValue()
        );
    }

    /// @inheritdoc IMultiVault
    function deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return MultiVaultLib.deposit(receiver, termId, curveId, minShares, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    ) external payable whenNotPaused nonReentrant returns (uint256[] memory) {
        return MultiVaultLib.depositBatch(receiver, termIds, curveIds, assets, minShares, _effectiveMsgValue());
    }

    /// @inheritdoc IMultiVault
    function redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets)
        external
        payable
        requiresZeroValue
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return MultiVaultLib.redeem(receiver, termId, curveId, shares, minAssets);
    }

    /// @inheritdoc IMultiVault
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    ) external payable requiresZeroValue whenNotPaused nonReentrant returns (uint256[] memory) {
        return MultiVaultLib.redeemBatch(receiver, termIds, curveIds, shares, minAssets);
    }

    /* =================================================== */
    /*                       Wallet                        */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function claimAtomWalletDepositFees(bytes32 termId) external nonReentrant {
        address atomWalletAddress = _computeAtomWalletAddr(termId);

        // Restrict access to the associated atom wallet
        if (msg.sender != atomWalletAddress) {
            revert MultiVault_OnlyAssociatedAtomWallet();
        }

        uint256 accumulatedFeesForAtomWallet = accumulatedAtomWalletDepositFees[atomWalletAddress];

        // Transfer accumulated fees to the atom wallet owner
        if (accumulatedFeesForAtomWallet > 0) {
            accumulatedAtomWalletDepositFees[atomWalletAddress] = 0;
            address atomWalletOwner = IAtomWallet(payable(atomWalletAddress)).owner();

            Address.sendValue(payable(atomWalletOwner), accumulatedFeesForAtomWallet);

            emit AtomWalletDepositFeesClaimed(termId, atomWalletOwner, accumulatedFeesForAtomWallet);
        }
    }

    /* =================================================== */
    /*                        Protocol                     */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function pause() external onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /// @inheritdoc IMultiVault
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /// @inheritdoc IMultiVault
    function setGeneralConfig(GeneralConfig memory _generalConfig) external onlyTimelock {
        _setGeneralConfig(_generalConfig);
        emit GeneralConfigUpdated(
            _generalConfig.admin,
            _generalConfig.protocolMultisig,
            _generalConfig.feeDenominator,
            _generalConfig.trustBonding,
            _generalConfig.minDeposit,
            _generalConfig.minShare,
            _generalConfig.atomDataMaxLength,
            _generalConfig.feeThreshold
        );
    }

    /// @inheritdoc IMultiVault
    function setAtomConfig(AtomConfig memory _atomConfig) external onlyTimelock {
        atomConfig = _atomConfig;
        emit AtomConfigUpdated(_atomConfig.atomCreationProtocolFee, _atomConfig.atomWalletDepositFee);
    }

    /// @inheritdoc IMultiVault
    function setAtomUriConfig(uint32 maxUriCount, uint32 maxUriLength) external onlyTimelock {
        if (maxUriCount == 0 || maxUriLength == 0) {
            revert MultiVault_InvalidAtomUriConfig();
        }
        _atomUriConfig = AtomUriConfig({ maxUriCount: maxUriCount, maxUriLength: maxUriLength });
        emit AtomUriConfigUpdated(maxUriCount, maxUriLength);
    }

    /// @inheritdoc IMultiVault
    function setTripleConfig(TripleConfig memory _tripleConfig) external onlyTimelock {
        tripleConfig = _tripleConfig;
        emit TripleConfigUpdated(_tripleConfig.tripleCreationProtocolFee, _tripleConfig.atomDepositFractionForTriple);
    }

    /// @inheritdoc IMultiVault
    function setWalletConfig(WalletConfig memory _walletConfig) external onlyTimelock {
        walletConfig = _walletConfig;
        emit WalletConfigUpdated(
            _walletConfig.entryPoint,
            _walletConfig.atomWarden,
            _walletConfig.atomWalletBeacon,
            _walletConfig.atomWalletFactory
        );
    }

    /// @inheritdoc IMultiVault
    function setVaultFees(VaultFees memory _vaultFees) external onlyTimelock {
        vaultFees = _vaultFees;
        emit VaultFeesUpdated(_vaultFees.entryFee, _vaultFees.exitFee, _vaultFees.protocolFee);
    }

    /// @inheritdoc IMultiVault
    function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyTimelock {
        bondingCurveConfig = _bondingCurveConfig;
        emit BondingCurveConfigUpdated(_bondingCurveConfig.registry, _bondingCurveConfig.defaultCurveId);
    }

    /// @inheritdoc IMultiVault
    /// @dev Permissionless by design. The recipient is always `generalConfig.protocolMultisig`, which only
    ///      timelocked governance can change — never the caller and never a parameter. An arbitrary caller
    ///      can therefore only push already-accrued fees to their intended destination, at their own gas.
    function sweepAccumulatedProtocolFees(uint256 epoch) external nonReentrant {
        uint256 protocolFees = accumulatedProtocolFees[epoch];
        if (protocolFees == 0) return;

        accumulatedProtocolFees[epoch] = 0;

        Address.sendValue(payable(generalConfig.protocolMultisig), protocolFees);

        emit ProtocolFeeTransferred(epoch, generalConfig.protocolMultisig, protocolFees);
    }

    /// @inheritdoc IMultiVault
    function setTimelock(address _timelock) external onlyTimelock {
        _setTimelock(_timelock);
    }

    /* =================================================== */
    /*                 INTERNAL WRAPPERS                   */
    /* =================================================== */
    /* Thin internal wrappers retained for inheritance / harness compatibility. Each wraps a single
       `DELEGATECALL` into the linked {MultiVaultLib}. The four MVMM-compat wrappers below
       (`_computeAtomWalletAddr`, `_initializeTripleState`, `_setVaultTotals`, `_convertToAssets`)
       keep {MultiVaultMigrationMode} resolving the legacy symbols through inheritance with zero
       source edit. The four test-harness wrappers (`_burn`, `_validateRedeem`, `_addUtilization`,
       `_removeUtilization`) keep `MultiVaultHarness` / `MultiVaultUtilizationHarness` unchanged. */

    /// @dev internal function to compute the address of the atom wallet for a given atom ID
    /// @param atomId the atom ID
    /// @return the address of the atom wallet
    function _computeAtomWalletAddr(bytes32 atomId) internal view returns (address) {
        return MultiVaultLib.computeAtomWalletAddr(atomId);
    }

    /// @dev internal function that returns the current epoch from the TrustBonding contract
    /// @return the current epoch number
    function _currentEpoch() internal view returns (uint256) {
        return MultiVaultLib.currentEpoch();
    }

    /// @dev calculates the fee on a raw amount provided as input. Kept inline on the contract so the
    ///      four single-line fee-amount external view getters above (`protocolFeeAmount` &c.) don't
    ///      pay a DELEGATECALL per query — they're hot off-chain reads.
    /// @param amount the raw amount to calculate the fee on
    /// @param fee the fee bps (numerator)
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    /// @dev Initialize the triple-state mappings. Wrapped here so {MultiVaultMigrationMode} resolves
    ///      `_initializeTripleState` through inheritance.
    function _initializeTripleState(bytes32 tripleId, bytes32 counterTripleId, bytes32[3] memory atomsArray) internal {
        MultiVaultLib.initializeTripleState(tripleId, counterTripleId, atomsArray);
    }

    /// @dev Read-side conversion. Wrapped here so {MultiVaultMigrationMode} resolves
    ///      `_convertToAssets` through inheritance.
    function _convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) internal view returns (uint256) {
        return MultiVaultLib.convertToAssets(termId, curveId, shares);
    }

    /// @dev Burn vault shares. Wrapped here so `MultiVaultHarness.burnForTest` resolves through
    ///      inheritance with no test edit.
    function _burn(address from, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256) {
        return MultiVaultLib.burn(from, termId, curveId, amount);
    }

    /// @dev Validate a redeem operation. Wrapped here so `MultiVaultHarness.validateRedeemForTest`
    ///      resolves through inheritance with no test edit.
    function _validateRedeem(bytes32 termId, uint256 curveId, address account, uint256 shares, uint256 minAssets)
        internal
        view
    {
        MultiVaultLib.validateRedeem(termId, curveId, account, shares, minAssets);
    }

    /// @dev Set vault totals + emit `SharePriceChanged`. Wrapped here so {MultiVaultMigrationMode}
    ///      resolves `_setVaultTotals` through inheritance.
    function _setVaultTotals(
        bytes32 termId,
        uint256 curveId,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    ) internal {
        MultiVaultLib.setVaultTotals(termId, curveId, totalAssets, totalShares, vaultType);
    }

    /// @dev Add user utilization. Wrapped here so `MultiVaultUtilizationHarness.addUtilizationForTest`
    ///      resolves through inheritance with no test edit.
    function _addUtilization(address user, int256 totalValue) internal {
        MultiVaultLib.addUtilization(user, totalValue);
    }

    /// @dev Remove user utilization. Wrapped here so
    ///      `MultiVaultUtilizationHarness.removeUtilizationForTest` resolves through inheritance.
    function _removeUtilization(address user, int256 amountToRemove) internal {
        MultiVaultLib.removeUtilization(user, amountToRemove);
    }

    /// @dev Shared implementation for the `onlyTimelock` entry-point guard.
    function _checkTimelock() internal view {
        if (msg.sender != timelock) revert MultiVault_OnlyTimelock();
    }

    /// @dev Internal function to set and validate the timelock address. Tiny body, kept inline
    ///      because it's only used by `reinitialize` and the `setTimelock` external function.
    function _setTimelock(address _timelock) internal {
        if (_timelock == address(0)) revert MultiVault_ZeroAddress();
        timelock = _timelock;
        emit TimelockSet(_timelock);
    }
}
