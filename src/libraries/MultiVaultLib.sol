// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { IMultiVault, ApprovalTypes, VaultState, VaultType } from "src/interfaces/IMultiVault.sol";
import { IAtomWalletFactory } from "src/interfaces/IAtomWalletFactory.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";

/**
 * @title  MultiVaultLib
 * @author 0xIntuition
 * @notice Stateless logic library extracted from {MultiVault}. Its exported entrypoints are declared
 *         `public` (internal helpers remain `private`), so the Solidity compiler treats this library as a
 *         separately-deployed contract and emits
 *         a 20-byte placeholder (`__$keccak256("src/libraries/MultiVaultLib.sol:MultiVaultLib")$__`)
 *         at every call site in {MultiVault}'s bytecode. The standard Solidity linker resolves the
 *         placeholder to the library's deployed address at link time; consumer deployment tooling
 *         performs this step as part of the implementation deployment, so no dedicated library-deployment
 *         step is required in the deploy script. Each resolved call site executes as a `DELEGATECALL`
 *         into the linked library.
 *
 *         Every call from {MultiVault} into a library function compiles to `DELEGATECALL`. Under
 *         `DELEGATECALL`, `address(this)`, `msg.sender`, `msg.value`, and storage all reflect the
 *         {MultiVault} call context — the library is logic-only and operates on {MultiVault}'s
 *         storage in place. Payable entrypoints receive an explicit `payment` argument from
 *         {MultiVault} so direct calls use raw `msg.value` and `multicall` sub-calls use
 *         their allocated virtual value without teaching this library about multicall state.
 *
 *         Conventions (load-bearing):
 *           1. The library has no state variables. All state lives on {MultiVault}.
 *           2. Storage access goes through a single `Storage` struct anchored at slot 0, whose
 *              field layout mirrors {MultiVault}'s storage layout exactly. The slot order is
 *              load-bearing and needs to be carefully maintained.
 *           3. Errors stay declared on {MultiVault} and {MultiVaultCore}. The library reverts via
 *              `revert MultiVault.MultiVault_X()` / `revert MultiVaultCore.MultiVaultCore_X()`,
 *              preserving every selector exactly so test references like
 *              `MultiVault.MultiVault_X.selector` continue to resolve.
 *           4. Events stay declared on {IMultiVault} and are emitted from the library via
 *              `emit IMultiVault.X(...)`. Because emit runs under `DELEGATECALL`, every event topic
 *              carries {MultiVault}'s address as the emitter — indexer semantics are bit-identical
 *              to the pre-refactor implementation.
 *           5. Calls between library functions are not `DELEGATECALL` — they compile to internal
 *              `JUMP`s within the library's own bytecode. So one external `DELEGATECALL` from
 *              {MultiVault} into a library entrypoint executes the entire transitive call graph
 *              inside the library with no further boundary cost.
 *
 *         Access control and pausability are enforced by {MultiVault}'s modifiers on the calling
 *         external function. The library does not re-check them.
 */
library MultiVaultLib {
    using FixedPointMathLib for uint256;

    /* =================================================== */
    /*                      CONSTANTS                      */
    /* =================================================== */
    /* Source of truth for the protocol constants used in the migrated bodies. {MultiVault} and
       {MultiVaultCore} re-export these as `public constant`s so their auto-generated public-getter
       ABI (`MAX_BATCH_SIZE()`, `BURN_ADDRESS()`, `ATOM_SALT()`, `TRIPLE_SALT()`, `COUNTER_SALT()`)
       continues to resolve at the same selectors. Solidity inlines the literal at every reference
       site, so there is no runtime indirection; single-source-of-truth here eliminates the drift
       risk that two redeclarations would carry. */

    /// @dev Maximum number of actions allowed in a single batch.
    uint256 internal constant MAX_BATCH_SIZE = 150;

    /// @dev Recipient of the "ghost (min) shares" minted when a vault is initialized.
    address internal constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    /// @dev Salts used to derive deterministic atom / triple / counter-triple IDs.
    bytes32 internal constant ATOM_SALT = keccak256("ATOM_SALT");
    bytes32 internal constant TRIPLE_SALT = keccak256("TRIPLE_SALT");
    bytes32 internal constant COUNTER_SALT = keccak256("COUNTER_SALT");

    /* =================================================== */
    /*                  STORAGE LAYOUT VIEW                */
    /* =================================================== */

    /// @dev Struct that mirrors {MultiVault}'s storage layout starting at slot 0. The field order
    ///      and packing must match `forge inspect MultiVault storage-layout` exactly — pinned by the
    ///      storage-layout regression suite in CI and re-verified on every upgrade. Field names here
    ///      are library-local; the SLOT positions are what's load-bearing.
    struct Storage {
        // slot 0
        uint256 totalTermsCreated;
        // slots 1-8 (GeneralConfig is 256 bytes / 8 slots)
        GeneralConfig generalConfig;
        // slots 9-10
        AtomConfig atomConfig;
        // slots 11-12
        TripleConfig tripleConfig;
        // slots 13-16
        WalletConfig walletConfig;
        // slots 17-19
        VaultFees vaultFees;
        // slots 20-21
        BondingCurveConfig bondingCurveConfig;
        // slot 22
        mapping(bytes32 => bytes) atoms;
        // slot 23
        mapping(bytes32 => bytes32[3]) triples;
        // slot 24
        mapping(bytes32 => bool) isTriple;
        // slot 25
        mapping(bytes32 => bytes32) tripleIdFromCounterId;
        // slot 26
        mapping(address => mapping(address => uint8)) approvals;
        // slot 27
        mapping(bytes32 => mapping(uint256 => VaultState)) vaults;
        // slot 28
        mapping(uint256 => uint256) accumulatedProtocolFees;
        // slot 29
        mapping(address => uint256) accumulatedAtomWalletDepositFees;
        // slot 30
        // Credited on deposit with the full amount sent in, debited on redeem with the asset value leaving the
        // vault; the bases differ by the entry-side fees, so a round-trip intentionally does not net to zero.
        // See the `totalUtilization` / `personalUtilization` NatSpec on MultiVault for the full rationale.
        mapping(uint256 => int256) totalUtilization;
        // slot 31
        mapping(address => mapping(uint256 => int256)) personalUtilization;
        // slot 32
        mapping(address => uint256[3]) userEpochHistory;
        // slot 33
        mapping(uint256 => bool) hasRolledOverSystemUtilization;
        // slot 34
        address timelock;
        // slot 35
        mapping(bytes32 => address) atomCreators;
        // slot 36
        mapping(bytes32 => uint48) atomCreatedAt;
        // slot 37 — most recent epoch at which system-utilization carry-forward ran;
        //           source-of-truth for `_rollover`, pre-seeded to the current epoch by
        //           `MultiVault.reinitialize` at upgrade time so the slot is always
        //           meaningful before the first `_rollover` runs.
        uint256 lastSystemUtilizationEpoch;
    }

    /// @dev Resolves the {Storage} struct view at slot 0. Under `DELEGATECALL` from {MultiVault} the
    ///      caller's storage context applies, so this pointer indexes into {MultiVault}'s actual
    ///      slots. Marked `pure` because no storage is read by the assembly itself — the read
    ///      happens at the call site through `s.field`.
    function _s() private pure returns (Storage storage s) {
        assembly {
            s.slot := 0
        }
    }

    /// @dev The fee-hook decision and quote for one deposit/redeem, resolved EXACTLY ONCE during
    ///      calculation and carried verbatim to the record phase. This makes netted == forwarded a
    ///      dataflow guarantee rather than a convention: a curve whose quote or hook getter reads
    ///      MultiVault state (which mutates between calculation and record) can no longer produce a
    ///      forwarded value that differs from what was withheld from the user.
    struct CurveHook {
        /// @dev The vault's curve iff it advertises the hook for this path; address(0) = no hook.
        address curve;
        /// @dev The curve-level fee quoted at calculation time; forwarded verbatim as `msg.value`.
        uint256 fee;
    }

    /* =================================================== */
    /*                  PUBLIC ENTRYPOINTS                 */
    /* =================================================== */

    /// @dev Mirror of {MultiVault.createAtoms}. {MultiVault}'s external function forwards to this
    ///      one via `DELEGATECALL`; the library handles the full call graph (payment validation,
    ///      per-atom creation loop, fee accumulation, utilization tracking) internally.
    function createAtoms(bytes[] calldata data, uint256[] calldata assets, uint256 payment)
        public
        returns (bytes32[] memory)
    {
        uint256 _amount = _validatePayment(assets, payment);
        return _createAtoms(msg.sender, data, assets, _amount);
    }

    /// @dev Mirror of {MultiVault.createTriples}.
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets,
        uint256 payment
    ) public returns (bytes32[] memory) {
        uint256 _amount = _validatePayment(assets, payment);
        return _createTriples(msg.sender, subjectIds, predicateIds, objectIds, assets, _amount);
    }

    /// @dev Mirror of {MultiVault.createAtomsFor}. On-behalf-of variant that
    ///      attributes the created atoms (and the create-payment utilization)
    ///      to `creator` instead of `msg.sender`. Requires `creator` to have
    ///      granted `msg.sender` an approval whose CREATION bit is set, unless
    ///      `creator == msg.sender` (self-creation short-circuit).
    function createAtomsFor(address creator, bytes[] calldata data, uint256[] calldata assets, uint256 payment)
        public
        returns (bytes32[] memory)
    {
        if (!_isApprovedToCreate(msg.sender, creator)) {
            revert MultiVault.MultiVault_CreatorNotApproved();
        }
        uint256 _amount = _validatePayment(assets, payment);
        return _createAtoms(creator, data, assets, _amount);
    }

    /// @dev Mirror of {MultiVault.createTriplesFor}. On-behalf-of variant that
    ///      attributes the create-payment utilization to `creator` instead of
    ///      `msg.sender`. Same approval rules as {createAtomsFor}.
    function createTriplesFor(
        address creator,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets,
        uint256 payment
    ) public returns (bytes32[] memory) {
        if (!_isApprovedToCreate(msg.sender, creator)) {
            revert MultiVault.MultiVault_CreatorNotApproved();
        }
        uint256 _amount = _validatePayment(assets, payment);
        return _createTriples(creator, subjectIds, predicateIds, objectIds, assets, _amount);
    }

    /// @dev Mirror of {MultiVault.deposit}.
    function deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares, uint256 payment)
        public
        returns (uint256)
    {
        if (!_isApprovedToDeposit(msg.sender, receiver)) {
            revert MultiVault.MultiVault_SenderNotApproved();
        }

        _addUtilization(receiver, int256(payment));

        return _processDeposit(msg.sender, receiver, termId, curveId, payment, minShares);
    }

    /// @dev Mirror of {MultiVault.depositBatch}. The library owns the iteration so the user pays one
    ///      `DELEGATECALL` boundary regardless of batch size.
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares,
        uint256 payment
    ) public returns (uint256[] memory shares) {
        uint256 _assetsSum = _validatePayment(assets, payment);
        uint256 length = termIds.length;

        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert MultiVault.MultiVault_InvalidArrayLength();
        }

        shares = new uint256[](length);

        if (length != curveIds.length || length != assets.length || length != minShares.length) {
            revert MultiVault.MultiVault_ArraysNotSameLength();
        }

        if (!_isApprovedToDeposit(msg.sender, receiver)) {
            revert MultiVault.MultiVault_SenderNotApproved();
        }

        for (uint256 i = 0; i < length;) {
            shares[i] = _processDeposit(msg.sender, receiver, termIds[i], curveIds[i], assets[i], minShares[i]);
            unchecked {
                ++i;
            }
        }

        _addUtilization(receiver, int256(_assetsSum));

        return shares;
    }

    /// @dev Mirror of {MultiVault.redeem}.
    function redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets)
        public
        returns (uint256)
    {
        if (!_isApprovedToRedeem(msg.sender, receiver)) {
            revert MultiVault.MultiVault_RedeemerNotApproved();
        }

        (uint256 rawAssetsBeforeFees, uint256 assetsAfterFees) =
            _processRedeem(msg.sender, receiver, termId, curveId, shares, minAssets);
        _removeUtilization(receiver, int256(rawAssetsBeforeFees));

        return assetsAfterFees;
    }

    /// @dev Mirror of {MultiVault.redeemBatch}.
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    ) public returns (uint256[] memory received) {
        if (termIds.length == 0 || termIds.length > MAX_BATCH_SIZE) {
            revert MultiVault.MultiVault_InvalidArrayLength();
        }

        received = new uint256[](termIds.length);

        if (termIds.length != curveIds.length || termIds.length != shares.length || termIds.length != minAssets.length)
        {
            revert MultiVault.MultiVault_ArraysNotSameLength();
        }

        if (!_isApprovedToRedeem(msg.sender, receiver)) {
            revert MultiVault.MultiVault_RedeemerNotApproved();
        }

        uint256 _totalAssetsBeforeFees;
        for (uint256 i = 0; i < termIds.length;) {
            (uint256 assetsBeforeFees, uint256 assetsAfterFees) =
                _processRedeem(msg.sender, receiver, termIds[i], curveIds[i], shares[i], minAssets[i]);
            _totalAssetsBeforeFees += assetsBeforeFees;
            received[i] = assetsAfterFees;
            unchecked {
                ++i;
            }
        }

        _removeUtilization(receiver, int256(_totalAssetsBeforeFees));

        return received;
    }

    /* =================================================== */
    /*               MVMM / HARNESS COMPAT                 */
    /* =================================================== */
    /* Public functions called by {MultiVault}'s thin internal wrappers so that
       {MultiVaultMigrationMode} (inherits {MultiVault}) and the unit-test harnesses can keep
       resolving the legacy `_internalName` symbols through inheritance with zero source edit. */

    /// @dev Mirror of {MultiVault._computeAtomWalletAddr}.
    function computeAtomWalletAddr(bytes32 atomId) public view returns (address) {
        return IAtomWalletFactory(_s().walletConfig.atomWalletFactory).computeAtomWalletAddr(atomId);
    }

    /// @dev Mirror of {MultiVault._initializeTripleState}.
    function initializeTripleState(bytes32 tripleId, bytes32 counterTripleId, bytes32[3] memory atomsArray) public {
        _initializeTripleState(tripleId, counterTripleId, atomsArray);
    }

    /// @dev Mirror of {MultiVault._setVaultTotals}. Validates curve max-assets/max-shares limits,
    ///      writes the new totals, emits {SharePriceChanged} via the same path as the migrated
    ///      entrypoints.
    function setVaultTotals(
        bytes32 termId,
        uint256 curveId,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    ) public {
        _setVaultTotals(termId, curveId, totalAssets, totalShares, vaultType);
    }

    /// @dev Mirror of {MultiVault._convertToAssets}.
    function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) public view returns (uint256) {
        return _convertToAssets(termId, curveId, shares);
    }

    /// @dev Mirror of {MultiVault._burn}.
    function burn(address from, bytes32 termId, uint256 curveId, uint256 amount) public returns (uint256) {
        return _burn(from, termId, curveId, amount);
    }

    /// @dev Mirror of {MultiVault._validateRedeem}.
    function validateRedeem(bytes32 termId, uint256 curveId, address account, uint256 shares, uint256 minAssets)
        public
        view
    {
        _validateRedeem(termId, curveId, account, shares, minAssets);
    }

    /// @dev Mirror of {MultiVault._addUtilization}.
    function addUtilization(address user, int256 totalValue) public {
        _addUtilization(user, totalValue);
    }

    /// @dev Mirror of {MultiVault._removeUtilization}.
    function removeUtilization(address user, int256 amountToRemove) public {
        _removeUtilization(user, amountToRemove);
    }

    /* =================================================== */
    /*               PUBLIC VIEW HELPERS                   */
    /* =================================================== */
    /* Used by {MultiVault}'s external view functions (`previewDeposit`, `previewRedeem`,
       `previewAtomCreate`, `previewTripleCreate`, `convertToShares`, and approval readers).
       Public so they can be invoked across the DELEGATECALL boundary. */

    /// @dev Mirror of {MultiVault._calculateAtomCreate}.
    function calculateAtomCreate(bytes32 termId, uint256 assets)
        public
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateAtomCreate(termId, assets);
    }

    /// @dev Mirror of {MultiVault._calculateTripleCreate}.
    function calculateTripleCreate(bytes32 termId, uint256 assets)
        public
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateTripleCreate(termId, assets);
    }

    /// @dev Mirror of {MultiVault._calculateDeposit}. The internal calc also resolves the fee-hook
    ///      carry for the write path; this view mirror drops it.
    function calculateDeposit(bytes32 termId, uint256 curveId, uint256 assets, bool isAtomVault)
        public
        view
        returns (uint256 shares, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees)
    {
        (shares, assetsAfterMinSharesCost, assetsAfterFees,) = _calculateDeposit(termId, curveId, assets, isAtomVault);
    }

    /// @dev Mirror of {MultiVault._calculateRedeem}. Account-less preview path: passes `address(0)`
    ///      to the curve's redeem-fee quote. The fee-hook carry is dropped on this view mirror.
    function calculateRedeem(bytes32 termId, uint256 curveId, uint256 shares)
        public
        view
        returns (uint256 assetsAfterFees, uint256 sharesUsed)
    {
        (assetsAfterFees, sharesUsed,) = _calculateRedeem(termId, curveId, shares, address(0));
    }

    /// @dev Mirror of {MultiVault._convertToShares}.
    function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) public view returns (uint256) {
        return _convertToShares(termId, curveId, assets);
    }

    /// @dev Returns the user's redeemable share balance for a vault. Used by {MultiVault.maxRedeem}.
    function maxRedeem(address sender, bytes32 termId, uint256 curveId) public view returns (uint256) {
        return _s().vaults[termId][curveId].balanceOf[sender];
    }

    /// @dev Mirror of {MultiVault._currentEpoch}.
    function currentEpoch() public view returns (uint256) {
        return ITrustBonding(_s().generalConfig.trustBonding).currentEpoch();
    }

    /// @dev Mirror of {MultiVault._isTermCreated}.
    function isTermCreated(bytes32 termId) public view returns (bool) {
        return _isTermCreated(termId);
    }

    /// @dev Mirror of {MultiVault._isApprovedToDeposit}.
    function isApprovedToDeposit(address sender, address receiver) public view returns (bool) {
        return _isApprovedToDeposit(sender, receiver);
    }

    /// @dev Mirror of {MultiVault._isApprovedToRedeem}.
    function isApprovedToRedeem(address sender, address receiver) public view returns (bool) {
        return _isApprovedToRedeem(sender, receiver);
    }

    /// @dev Mirror of {MultiVault._isApprovedToCreate}.
    function isApprovedToCreate(address sender, address creator) public view returns (bool) {
        return _isApprovedToCreate(sender, creator);
    }

    /// @dev Resolution of {MultiVault.getUserUtilizationInEpoch}'s 3-slot lookback chain.
    function getUserUtilizationInEpoch(address user, uint256 epoch) public view returns (int256) {
        uint256 _currentEpochLocal = currentEpoch();

        if (epoch > _currentEpochLocal) revert MultiVault.MultiVault_InvalidEpoch();

        Storage storage s = _s();
        uint256[3] memory _userEpochHistory = s.userEpochHistory[user];

        if (_userEpochHistory[0] <= epoch) {
            return s.personalUtilization[user][_userEpochHistory[0]];
        }

        if (_userEpochHistory[1] <= epoch) {
            return s.personalUtilization[user][_userEpochHistory[1]];
        }

        if (_userEpochHistory[2] <= epoch) {
            return s.personalUtilization[user][_userEpochHistory[2]];
        }

        revert MultiVault.MultiVault_EpochNotTracked();
    }

    /// @dev Helper used by {MultiVault.currentSharePrice}.
    function currentSharePrice(bytes32 termId, uint256 curveId) public view returns (uint256) {
        Storage storage s = _s();
        VaultState storage vaultState = s.vaults[termId][curveId];
        return IBondingCurveRegistry(s.bondingCurveConfig.registry)
            .currentPrice(curveId, vaultState.totalShares, vaultState.totalAssets);
    }

    /* =================================================== */
    /*                  ATOM / TRIPLE CREATION             */
    /* =================================================== */

    function _createAtoms(address sender, bytes[] calldata data, uint256[] calldata assets, uint256 payment)
        private
        returns (bytes32[] memory)
    {
        uint256 length = data.length;
        if (length == 0) {
            revert MultiVault.MultiVault_NoAtomDataProvided();
        }

        if (length != assets.length) {
            revert MultiVault.MultiVault_ArraysNotSameLength();
        }

        bytes32[] memory ids = new bytes32[](length);

        for (uint256 i = 0; i < length;) {
            ids[i] = _createAtom(sender, data[i], assets[i]);
            unchecked {
                ++i;
            }
        }

        uint256 atomCreationProtocolFees = _s().atomConfig.atomCreationProtocolFee * length;
        _accumulateStaticProtocolFees(atomCreationProtocolFees);

        _addUtilization(sender, int256(payment));

        return ids;
    }

    function _createAtom(address sender, bytes calldata data, uint256 assets) private returns (bytes32 atomId) {
        uint256 length = data.length;

        if (length == 0) {
            revert MultiVault.MultiVault_NoAtomDataProvided();
        }

        Storage storage s = _s();

        if (length > s.generalConfig.atomDataMaxLength) {
            revert MultiVault.MultiVault_AtomDataTooLong();
        }

        atomId = _calculateAtomId(data);
        if (s.atoms[atomId].length != 0) {
            revert MultiVault.MultiVault_AtomExists(data);
        }

        s.atoms[atomId] = data;
        s.atomCreators[atomId] = sender;
        s.atomCreatedAt[atomId] = uint48(block.timestamp);
        uint256 curveId = s.bondingCurveConfig.defaultCurveId;

        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateAtomCreate(atomId, assets);

        _accumulateVaultProtocolFees(assetsAfterFixedFees);
        address atomWallet = _accumulateAtomWalletFees(atomId, assetsAfterFixedFees);

        uint256 userSharesAfter =
            _updateVaultOnCreation(sender, atomId, curveId, assetsAfterFees, sharesForReceiver, VaultType.ATOM);

        emit IMultiVault.AtomCreated(sender, atomId, data, atomWallet);

        emit IMultiVault.Deposited(
            sender, sender, atomId, curveId, assets, assetsAfterFees, sharesForReceiver, userSharesAfter, VaultType.ATOM
        );

        ++s.totalTermsCreated;

        return atomId;
    }

    function _createTriples(
        address creator,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets,
        uint256 amount
    ) private returns (bytes32[] memory) {
        uint256 length = subjectIds.length;
        uint256 minCost = _getTripleCost() * assets.length;

        if (length == 0) {
            revert MultiVault.MultiVault_InvalidArrayLength();
        }

        if (predicateIds.length != length || objectIds.length != length || assets.length != length) {
            revert MultiVault.MultiVault_ArraysNotSameLength();
        }

        if (amount < minCost) {
            revert MultiVault.MultiVault_InsufficientBalance();
        }

        bytes32[] memory ids = new bytes32[](length);
        for (uint256 i = 0; i < length;) {
            ids[i] = _createTriple(creator, subjectIds[i], predicateIds[i], objectIds[i], assets[i]);
            unchecked {
                ++i;
            }
        }

        uint256 tripleCreationProtocolFees = _s().tripleConfig.tripleCreationProtocolFee * length;
        _accumulateStaticProtocolFees(tripleCreationProtocolFees);

        _addUtilization(creator, int256(amount));

        return ids;
    }

    function _createTriple(address sender, bytes32 subjectId, bytes32 predicateId, bytes32 objectId, uint256 assets)
        private
        returns (bytes32 tripleId)
    {
        tripleId = _calculateTripleId(subjectId, predicateId, objectId);
        _tripleExists(tripleId, subjectId, predicateId, objectId);

        _requireTermExists(subjectId);
        _requireTermExists(predicateId);
        _requireTermExists(objectId);

        bytes32[3] memory atomsArray = [subjectId, predicateId, objectId];
        bytes32 counterTripleId = _calculateCounterTripleId(tripleId);

        _initializeTripleState(tripleId, counterTripleId, atomsArray);

        Storage storage s = _s();
        uint256 curveId = s.bondingCurveConfig.defaultCurveId;

        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateTripleCreate(tripleId, assets);

        _accumulateVaultProtocolFees(assetsAfterFixedFees);

        uint256 userSharesAfter =
            _updateVaultOnCreation(sender, tripleId, curveId, assetsAfterFees, sharesForReceiver, VaultType.TRIPLE);

        if (_shouldChargeAtomDepositFraction(tripleId)) {
            _increaseProRataVaultsAssets(
                tripleId, _feeOnRaw(assetsAfterFixedFees, s.tripleConfig.atomDepositFractionForTriple)
            );
        }

        _initializeOppositeTripleVault(tripleId, curveId);

        emit IMultiVault.TripleCreated(sender, tripleId, subjectId, predicateId, objectId);

        emit IMultiVault.Deposited(
            sender,
            sender,
            tripleId,
            curveId,
            assets,
            assetsAfterFees,
            sharesForReceiver,
            userSharesAfter,
            VaultType.TRIPLE
        );

        s.totalTermsCreated += 2;

        return tripleId;
    }

    function _initializeTripleState(bytes32 tripleId, bytes32 counterTripleId, bytes32[3] memory atomsArray) private {
        Storage storage s = _s();
        s.triples[tripleId] = atomsArray;
        s.isTriple[tripleId] = true;

        s.isTriple[counterTripleId] = true;
        s.triples[counterTripleId] = atomsArray;
        s.tripleIdFromCounterId[counterTripleId] = tripleId;
    }

    /* =================================================== */
    /*                    DEPOSIT / REDEEM                 */
    /* =================================================== */

    function _processDeposit(
        address sender,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 minShares
    ) private returns (uint256) {
        _validateMinDeposit(assets);

        VaultType _vaultType = _getVaultType(termId);

        if (_vaultType != VaultType.ATOM) {
            if (_hasCounterStake(termId, curveId, receiver)) revert MultiVault.MultiVault_HasCounterStake();
            if (_isDirectCounterTripleTermInit(termId, curveId)) {
                revert MultiVault.MultiVault_CannotDirectlyInitializeCounterTriple();
            }
        }

        // Collapsed to a single flag to stay under the 16-slot stack ceiling: after the
        // default-curve guard fires, the only distinction the rest of the flow needs is
        // "new non-default vault" (creation-style update) vs everything else.
        bool isNewNonDefault;
        {
            bool isNew = _isNewVault(termId, curveId);
            bool isDefault = curveId == _s().bondingCurveConfig.defaultCurveId;
            if (isNew && isDefault) {
                revert MultiVault.MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();
            }
            isNewNonDefault = isNew && !isDefault;
        }

        (uint256 sharesForReceiver, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees, CurveHook memory hook) =
            _calculateDeposit(termId, curveId, assets, _vaultType == VaultType.ATOM);

        _validateMinShares(
            termId, curveId, assets, sharesForReceiver, assetsAfterMinSharesCost, assetsAfterFees, minShares
        );

        _accumulateVaultProtocolFees(assetsAfterMinSharesCost);

        if (_shouldChargeFees(termId)) {
            _increaseProRataVaultAssets(
                termId, _feeOnRaw(assetsAfterMinSharesCost, _s().vaultFees.entryFee), _vaultType
            );
        }

        if (_vaultType == VaultType.ATOM) {
            _accumulateAtomWalletFees(termId, assetsAfterMinSharesCost);
        } else {
            if (_shouldChargeAtomDepositFraction(termId)) {
                _increaseProRataVaultsAssets(
                    termId, _feeOnRaw(assetsAfterMinSharesCost, _s().tripleConfig.atomDepositFractionForTriple)
                );
            }
        }

        uint256 userBalanceAfter;
        if (isNewNonDefault) {
            userBalanceAfter =
                _updateVaultOnCreation(receiver, termId, curveId, assetsAfterFees, sharesForReceiver, _vaultType);

            if (_vaultType != VaultType.ATOM) {
                _initializeOppositeTripleVault(termId, curveId);
            }
        } else {
            userBalanceAfter =
                _updateVaultOnDeposit(receiver, termId, curveId, assetsAfterFees, sharesForReceiver, _vaultType);
        }

        // Curve deposit hook: forward the fee withheld during calculation (carried in `hook`, never
        // re-quoted) to the vault's curve and book the depositor's position. Runs after every
        // vault-state write (CEI); registered curves are admin-vetted and cannot re-enter (the
        // whole path is `nonReentrant`). A no-op for hookless curves.
        _recordCurveDeposit(termId, receiver, hook, sharesForReceiver);

        emit IMultiVault.Deposited(
            sender, receiver, termId, curveId, assets, assetsAfterFees, sharesForReceiver, userBalanceAfter, _vaultType
        );

        return sharesForReceiver;
    }

    function _processRedeem(
        address sender,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    ) private returns (uint256, uint256) {
        VaultType _vaultType = _getVaultType(termId);

        _validateRedeem(termId, curveId, receiver, shares, minAssets);

        uint256 rawAssetsBeforeFees = _convertToAssets(termId, curveId, shares);

        (uint256 assetsAfterFees,, CurveHook memory hook) = _calculateRedeem(termId, curveId, shares, receiver);

        _accumulateVaultProtocolFees(rawAssetsBeforeFees);

        if (_shouldChargeExitFees(termId, curveId, shares)) {
            _increaseProRataVaultAssets(termId, _feeOnRaw(rawAssetsBeforeFees, _s().vaultFees.exitFee), _vaultType);
        }

        uint256 userSharesAfter =
            _updateVaultOnRedeem(receiver, termId, curveId, rawAssetsBeforeFees, shares, _vaultType);

        // Curve redeem hook: forward the fee withheld during calculation (carried in `hook`, never
        // re-quoted) to the vault's curve and book the exit. Runs after the shares are burned and
        // totals lowered, and before the receiver payout (CEI). A no-op for hookless curves.
        _recordCurveRedeem(termId, receiver, hook, shares);

        Address.sendValue(payable(receiver), assetsAfterFees);

        emit IMultiVault.Redeemed(
            sender,
            receiver,
            termId,
            curveId,
            shares,
            userSharesAfter,
            assetsAfterFees,
            rawAssetsBeforeFees - assetsAfterFees,
            _vaultType
        );

        return (rawAssetsBeforeFees, assetsAfterFees);
    }

    /// @dev Resolve `curveId` through the registry and return the curve address iff it exposes the
    ///      standardized deposit fee hook; address(0) otherwise. The explicit zero-address guard is
    ///      load-bearing: an unregistered id must fall through so the canonical
    ///      `BondingCurveRegistry_InvalidCurveId` still surfaces from the pricing call, instead of a
    ///      bare call-to-codeless-account revert here.
    function _depositFeeHookCurve(uint256 curveId) private view returns (address) {
        address curve = IBondingCurveRegistry(_s().bondingCurveConfig.registry).curveAddresses(curveId);
        if (curve == address(0) || !IBaseCurve(curve).hasDepositFeeHook()) return address(0);
        return curve;
    }

    /// @dev Redeem-path mirror of {_depositFeeHookCurve}, gated on {IBaseCurve.hasRedeemFeeHook}.
    function _redeemFeeHookCurve(uint256 curveId) private view returns (address) {
        address curve = IBondingCurveRegistry(_s().bondingCurveConfig.registry).curveAddresses(curveId);
        if (curve == address(0) || !IBaseCurve(curve).hasRedeemFeeHook()) return address(0);
        return curve;
    }

    /// @dev Forward the curve-level deposit fee (native) to the vault's curve and book the
    ///      depositor's position; a no-op for any curve without the deposit hook. Always invoked on
    ///      a hook curve — even at a zero fee — so the curve's per-user share ledger stays in
    ///      lockstep with the vault. `hook` carries the decision and quote resolved during
    ///      {_calculateDeposit}, so the forwarded value equals the withheld fee by dataflow — the
    ///      hook is never re-resolved or re-quoted after the vault-state writes.
    function _recordCurveDeposit(bytes32 termId, address receiver, CurveHook memory hook, uint256 sharesForReceiver)
        private
    {
        if (hook.curve == address(0)) return;
        IBaseCurve(hook.curve).recordDeposit{ value: hook.fee }(termId, receiver, sharesForReceiver);
    }

    /// @dev Forward the curve-level withdrawal fee (native) to the vault's curve and book the exit;
    ///      a no-op for any curve without the redeem hook. Always invoked on a hook curve so the
    ///      curve's per-user share ledger stays in lockstep with the vault. `hook` carries the
    ///      decision and quote resolved during {_calculateRedeem} — never re-resolved here.
    function _recordCurveRedeem(bytes32 termId, address receiver, CurveHook memory hook, uint256 shares) private {
        if (hook.curve == address(0)) return;
        IBaseCurve(hook.curve).recordRedeem{ value: hook.fee }(termId, receiver, shares);
    }

    /* =================================================== */
    /*                    ACCUMULATORS                     */
    /* =================================================== */

    function _accumulateVaultProtocolFees(uint256 assets) private {
        Storage storage s = _s();
        uint256 fees = _feeOnRaw(assets, s.vaultFees.protocolFee);
        uint256 epoch = currentEpoch();
        s.accumulatedProtocolFees[epoch] += fees;
        emit IMultiVault.ProtocolFeeAccrued(epoch, msg.sender, fees);
    }

    function _accumulateStaticProtocolFees(uint256 assets) private {
        uint256 epoch = currentEpoch();
        _s().accumulatedProtocolFees[epoch] += assets;
        emit IMultiVault.ProtocolFeeAccrued(epoch, msg.sender, assets);
    }

    function _accumulateAtomWalletFees(bytes32 termId, uint256 assets) private returns (address) {
        Storage storage s = _s();
        address atomWalletAddress = IAtomWalletFactory(s.walletConfig.atomWalletFactory).computeAtomWalletAddr(termId);
        uint256 atomWalletDepositFee = _feeOnRaw(assets, s.atomConfig.atomWalletDepositFee);
        s.accumulatedAtomWalletDepositFees[atomWalletAddress] += atomWalletDepositFee;
        emit IMultiVault.AtomWalletDepositFeeCollected(termId, msg.sender, atomWalletDepositFee);
        return atomWalletAddress;
    }

    /* =================================================== */
    /*                      CALCULATE                      */
    /* =================================================== */

    function _calculateDeposit(bytes32 termId, uint256 curveId, uint256 assets, bool isAtomVault)
        private
        view
        returns (uint256 shares, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees, CurveHook memory hook)
    {
        if (isAtomVault) {
            return _calculateAtomDeposit(termId, curveId, assets);
        } else {
            return _calculateTripleDeposit(termId, curveId, assets);
        }
    }

    function _calculateAtomCreate(bytes32 termId, uint256 assets)
        private
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        Storage storage s = _s();
        uint256 curveId = s.bondingCurveConfig.defaultCurveId;
        uint256 atomCost = _getAtomCost();

        if (assets < atomCost) {
            revert MultiVault.MultiVault_InsufficientAssets();
        }

        assetsAfterFixedFees = assets - atomCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, s.vaultFees.protocolFee);
        uint256 atomWalletDepositFee = _feeOnRaw(assetsAfterFixedFees, s.atomConfig.atomWalletDepositFee);

        assetsAfterFees = assetsAfterFixedFees - protocolFee - atomWalletDepositFee;
        shares = _convertToShares(termId, curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    function _calculateAtomDeposit(bytes32 termId, uint256 curveId, uint256 assets)
        private
        view
        returns (uint256 shares, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees, CurveHook memory hook)
    {
        assetsAfterMinSharesCost = assets;

        if (_isNewVault(termId, curveId)) {
            uint256 minShareCost = _minShareCostFor(VaultType.ATOM, curveId);
            if (assets <= minShareCost) revert MultiVault.MultiVault_DepositTooSmallToCoverMinShares();
            assetsAfterMinSharesCost -= minShareCost;
        }

        // Scope blocks free fee locals before the share-calc branch loads its own.
        {
            uint256 protocolFee = _feeOnRaw(assetsAfterMinSharesCost, _s().vaultFees.protocolFee);
            uint256 entryFee =
                _shouldChargeFees(termId) ? _feeOnRaw(assetsAfterMinSharesCost, _s().vaultFees.entryFee) : 0;
            uint256 atomWalletDepositFee = _feeOnRaw(assetsAfterMinSharesCost, _s().atomConfig.atomWalletDepositFee);
            assetsAfterFees = assetsAfterMinSharesCost - protocolFee - entryFee - atomWalletDepositFee;
        }

        // Layer the curve's own deposit fee on top of MultiVault's fees (0 for any hookless curve);
        // it is withheld from the minted net here and the SAME quote is forwarded to the curve in
        // `_processDeposit` via the carried `hook` — quoted exactly once.
        hook.curve = _depositFeeHookCurve(curveId);
        if (hook.curve != address(0)) {
            hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
            assetsAfterFees -= hook.fee;
        }

        shares = _depositShares(termId, curveId, assetsAfterFees);
    }

    function _calculateTripleCreate(bytes32 termId, uint256 assets) private view returns (uint256, uint256, uint256) {
        Storage storage s = _s();
        uint256 curveId = s.bondingCurveConfig.defaultCurveId;
        uint256 tripleCost = _getTripleCost();

        if (assets < tripleCost) {
            revert MultiVault.MultiVault_InsufficientAssets();
        }

        uint256 assetsAfterFixedFees = assets - tripleCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, s.vaultFees.protocolFee);
        uint256 atomDepositFraction = _shouldChargeAtomDepositFraction(termId)
            ? _feeOnRaw(assetsAfterFixedFees, s.tripleConfig.atomDepositFractionForTriple)
            : 0;

        uint256 assetsAfterFees = assetsAfterFixedFees - protocolFee - atomDepositFraction;
        uint256 shares = _convertToShares(termId, curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    function _calculateTripleDeposit(bytes32 termId, uint256 curveId, uint256 assets)
        private
        view
        returns (uint256 shares, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees, CurveHook memory hook)
    {
        assetsAfterMinSharesCost = assets;

        if (_isDirectCounterTripleTermInit(termId, curveId)) {
            revert MultiVault.MultiVault_CannotDirectlyInitializeCounterTriple();
        }

        if (_isNewVault(termId, curveId)) {
            uint256 minShareCost = _minShareCostFor(VaultType.TRIPLE, curveId);
            if (assets <= minShareCost) revert MultiVault.MultiVault_DepositTooSmallToCoverMinShares();
            assetsAfterMinSharesCost -= minShareCost;
        }

        // Scope blocks free fee locals before the share-calc branch loads its own.
        {
            uint256 protocolFee = _feeOnRaw(assetsAfterMinSharesCost, _s().vaultFees.protocolFee);
            uint256 entryFee =
                _shouldChargeFees(termId) ? _feeOnRaw(assetsAfterMinSharesCost, _s().vaultFees.entryFee) : 0;
            uint256 atomDepositFraction = _shouldChargeAtomDepositFraction(termId)
                ? _feeOnRaw(assetsAfterMinSharesCost, _s().tripleConfig.atomDepositFractionForTriple)
                : 0;
            assetsAfterFees = assetsAfterMinSharesCost - protocolFee - entryFee - atomDepositFraction;
        }

        // Layer the curve's own deposit fee on top of MultiVault's fees (0 for any hookless curve);
        // it is withheld from the minted net here and the SAME quote is forwarded to the curve in
        // `_processDeposit` via the carried `hook` — quoted exactly once.
        hook.curve = _depositFeeHookCurve(curveId);
        if (hook.curve != address(0)) {
            hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
            assetsAfterFees -= hook.fee;
        }

        shares = _depositShares(termId, curveId, assetsAfterFees);
    }

    /// @dev Shared share-mint computation used by atom and triple deposit calcs. For a new vault the
    ///      curve treats it as if `minShare` shares were already seeded (initial deposit accounting);
    ///      existing vaults use the stored totalAssets / totalShares.
    function _depositShares(bytes32 termId, uint256 curveId, uint256 assetsAfterFees) private view returns (uint256) {
        Storage storage s = _s();
        if (_isNewVault(termId, curveId)) {
            return IBondingCurveRegistry(s.bondingCurveConfig.registry)
                .previewDeposit(
                    assetsAfterFees,
                    _minAssetsForCurve(curveId, s.generalConfig.minShare),
                    s.generalConfig.minShare,
                    curveId
                );
        }
        return _convertToShares(termId, curveId, assetsAfterFees);
    }

    function _calculateRedeem(bytes32 termId, uint256 curveId, uint256 shares, address account)
        private
        view
        returns (uint256, uint256, CurveHook memory hook)
    {
        Storage storage s = _s();
        uint256 assets = _convertToAssets(termId, curveId, shares);

        uint256 protocolFee = _feeOnRaw(assets, s.vaultFees.protocolFee);
        uint256 exitFee = _shouldChargeExitFees(termId, curveId, shares) ? _feeOnRaw(assets, s.vaultFees.exitFee) : 0;

        // Layer the curve's own withdrawal fee on top of MultiVault's fees (0 for any hookless
        // curve); the SAME quote is forwarded to the curve in `_processRedeem` via the carried
        // `hook` — quoted exactly once. The account-less preview path passes `address(0)`; the hook
        // curve decides its own fallback semantics for it.
        hook.curve = _redeemFeeHookCurve(curveId);
        if (hook.curve != address(0)) {
            hook.fee = IBaseCurve(hook.curve).quoteRedeemFee(termId, account, assets);
        }

        // Defense in depth: reject a redemption that would return nothing, independently of the
        // caller-supplied `minAssets`. Without this, a curve fee rate that consumes the whole
        // redemption burns the redeemer's shares for a zero payout WITHOUT reverting, and the
        // account-less preview reports the same zero, so a front end deriving `minAssets` from it
        // derives no protection either. The curve's own immutable cap ceilings are the primary
        // guard; this floor holds regardless of which curve is attached.
        uint256 totalFees = protocolFee + exitFee + hook.fee;
        if (totalFees >= assets) {
            revert MultiVault.MultiVault_RedeemYieldsNoAssets();
        }

        uint256 assetsAfterFees = assets - totalFees;

        return (assetsAfterFees, shares, hook);
    }

    /* =================================================== */
    /*                      PRO-RATA                       */
    /* =================================================== */

    function _increaseProRataVaultsAssets(bytes32 tripleId, uint256 amount) private {
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _getTriple(tripleId);

        uint256 amountPerTerm = amount / 3;

        _increaseProRataVaultAssets(subjectId, amountPerTerm, _getVaultType(subjectId));
        _increaseProRataVaultAssets(predicateId, amountPerTerm, _getVaultType(predicateId));
        _increaseProRataVaultAssets(objectId, amountPerTerm, _getVaultType(objectId));
    }

    function _increaseProRataVaultAssets(bytes32 termId, uint256 amount, VaultType vaultType) private {
        Storage storage s = _s();
        uint256 curveId = s.bondingCurveConfig.defaultCurveId;
        VaultState storage vaultState = s.vaults[termId][curveId];
        _setVaultTotals(termId, curveId, vaultState.totalAssets + amount, vaultState.totalShares, vaultType);
    }

    /* =================================================== */
    /*                 UTILIZATION TRACKING                */
    /* =================================================== */

    function _addUtilization(address user, int256 totalValue) private {
        _rollover(user);

        Storage storage s = _s();
        uint256 epoch = currentEpoch();

        uint256[3] storage userEpoch = s.userEpochHistory[user];
        if (userEpoch[0] != epoch) {
            if (userEpoch[0] != 0) {
                userEpoch[2] = userEpoch[1];
                userEpoch[1] = userEpoch[0];
            }
            userEpoch[0] = epoch;
        }

        s.totalUtilization[epoch] += totalValue;
        emit IMultiVault.TotalUtilizationAdded(epoch, totalValue, s.totalUtilization[epoch]);

        s.personalUtilization[user][epoch] += totalValue;
        emit IMultiVault.PersonalUtilizationAdded(user, epoch, totalValue, s.personalUtilization[user][epoch]);
    }

    function _removeUtilization(address user, int256 amountToRemove) private {
        _rollover(user);

        Storage storage s = _s();
        uint256 epoch = currentEpoch();
        uint256[3] storage userEpoch = s.userEpochHistory[user];
        if (userEpoch[0] != epoch) {
            if (userEpoch[0] != 0) {
                userEpoch[2] = userEpoch[1];
                userEpoch[1] = userEpoch[0];
            }
            userEpoch[0] = epoch;
        }

        s.totalUtilization[epoch] -= amountToRemove;
        emit IMultiVault.TotalUtilizationRemoved(epoch, amountToRemove, s.totalUtilization[epoch]);

        s.personalUtilization[user][epoch] -= amountToRemove;
        emit IMultiVault.PersonalUtilizationRemoved(user, epoch, amountToRemove, s.personalUtilization[user][epoch]);
    }

    function _rollover(address user) private {
        Storage storage s = _s();
        uint256 currentEpochLocal = currentEpoch();
        uint256 userLastEpoch = s.userEpochHistory[user][0];

        if (currentEpochLocal > 0 && !s.hasRolledOverSystemUtilization[currentEpochLocal]) {
            s.hasRolledOverSystemUtilization[currentEpochLocal] = true;

            // Carry from the tracked last-active system epoch so utilization survives
            // multi-epoch quiescence. `MultiVault.reinitialize` pre-seeds this slot at
            // upgrade time, so it always points at a meaningful prior epoch here.
            uint256 sourceEpoch = s.lastSystemUtilizationEpoch;
            int256 sourceUtilization = s.totalUtilization[sourceEpoch];
            if (sourceUtilization != 0 && s.totalUtilization[currentEpochLocal] == 0) {
                s.totalUtilization[currentEpochLocal] = sourceUtilization;
            }

            s.lastSystemUtilizationEpoch = currentEpochLocal;
        }

        if (userLastEpoch == currentEpochLocal) {
            return;
        }

        int256 lastEpochUtilization = s.personalUtilization[user][userLastEpoch];
        if (lastEpochUtilization != 0 && s.personalUtilization[user][currentEpochLocal] == 0) {
            s.personalUtilization[user][currentEpochLocal] = lastEpochUtilization;
        }
    }

    /* =================================================== */
    /*                  VAULT UPDATES                      */
    /* =================================================== */

    function _updateVaultOnCreation(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType vaultType
    ) private returns (uint256) {
        Storage storage s = _s();
        uint256 minShare = s.generalConfig.minShare;
        VaultState storage vaultState = s.vaults[termId][curveId];

        _setVaultTotals(
            termId,
            curveId,
            vaultState.totalAssets + assets + _minAssetsForCurve(curveId, minShare),
            vaultState.totalShares + shares + minShare,
            vaultType
        );

        uint256 sharesTotal = _mint(receiver, termId, curveId, shares);

        _mint(BURN_ADDRESS, termId, curveId, minShare);

        return sharesTotal;
    }

    function _updateVaultOnDeposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType _vaultType
    ) private returns (uint256) {
        Storage storage s = _s();
        _setVaultTotals(
            termId,
            curveId,
            s.vaults[termId][curveId].totalAssets + assets,
            s.vaults[termId][curveId].totalShares + shares,
            _vaultType
        );

        return _mint(receiver, termId, curveId, shares);
    }

    function _updateVaultOnRedeem(
        address sender,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType vaultType
    ) private returns (uint256) {
        VaultState storage vaultState = _s().vaults[termId][curveId];

        _setVaultTotals(termId, curveId, vaultState.totalAssets - assets, vaultState.totalShares - shares, vaultType);

        return _burn(sender, termId, curveId, shares);
    }

    /// @dev Seeds the opposite-side triple vault with min-shares minted to {BURN_ADDRESS}. Called
    ///      from the positive-triple create path (seeds counter-side default-curve vault) and from
    ///      the first-deposit-on-non-default-curve branch in {_processDeposit} (seeds the opposite
    ///      side regardless of which direction the deposit came from). The direction is resolved
    ///      from {termId} via the existing {_getInverseTripleId} / {_isCounterTriple} helpers so the
    ///      same min-share invariant applies symmetrically.
    function _initializeOppositeTripleVault(bytes32 termId, uint256 curveId) private {
        Storage storage s = _s();
        bytes32 oppositeId = _getInverseTripleId(termId);
        VaultType oppositeType = _isCounterTriple(termId) ? VaultType.TRIPLE : VaultType.COUNTER_TRIPLE;
        VaultState storage vaultState = s.vaults[oppositeId][curveId];
        uint256 minShare = s.generalConfig.minShare;

        _setVaultTotals(
            oppositeId,
            curveId,
            vaultState.totalAssets + _minAssetsForCurve(curveId, minShare),
            vaultState.totalShares + minShare,
            oppositeType
        );

        _mint(BURN_ADDRESS, oppositeId, curveId, minShare);
    }

    function _setVaultTotals(
        bytes32 termId,
        uint256 curveId,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    ) private {
        Storage storage s = _s();
        IBondingCurveRegistry registry = IBondingCurveRegistry(s.bondingCurveConfig.registry);

        uint256 maxAssets = registry.getCurveMaxAssets(curveId);
        uint256 maxShares = registry.getCurveMaxShares(curveId);
        if (totalAssets > maxAssets) revert MultiVault.MultiVault_ActionExceedsMaxAssets();
        if (totalShares > maxShares) revert MultiVault.MultiVault_ActionExceedsMaxShares();

        VaultState storage vaultState = s.vaults[termId][curveId];
        vaultState.totalAssets = totalAssets;
        vaultState.totalShares = totalShares;

        uint256 price = registry.currentPrice(curveId, totalShares, totalAssets);

        emit IMultiVault.SharePriceChanged(termId, curveId, price, totalAssets, totalShares, vaultType);
    }

    function _mint(address to, bytes32 termId, uint256 curveId, uint256 amount) private returns (uint256) {
        Storage storage s = _s();
        s.vaults[termId][curveId].balanceOf[to] += amount;
        return s.vaults[termId][curveId].balanceOf[to];
    }

    function _burn(address from, bytes32 termId, uint256 curveId, uint256 amount) private returns (uint256) {
        if (from == address(0)) revert MultiVault.MultiVault_BurnFromZeroAddress();

        mapping(address => uint256) storage balances = _s().vaults[termId][curveId].balanceOf;
        uint256 fromBalance = balances[from];

        if (fromBalance < amount) {
            revert MultiVault.MultiVault_BurnInsufficientBalance();
        }

        uint256 newBalance;
        unchecked {
            newBalance = fromBalance - amount;
            balances[from] = newBalance;
        }

        return newBalance;
    }

    /* =================================================== */
    /*                      VALIDATION                     */
    /* =================================================== */

    function _validateMinDeposit(uint256 assets) private view {
        if (assets < _s().generalConfig.minDeposit) {
            revert MultiVault.MultiVault_DepositBelowMinimumDeposit();
        }
    }

    function _validatePayment(uint256[] calldata assets, uint256 payment) private pure returns (uint256 total) {
        uint256 length = assets.length;

        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert MultiVault.MultiVault_InvalidArrayLength();
        }
        for (uint256 i = 0; i < length;) {
            total += assets[i];
            unchecked {
                ++i;
            }
        }

        if (payment != total) {
            revert MultiVault.MultiVault_InsufficientBalance();
        }

        return total;
    }

    function _validateMinShares(
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 sharesForReceiver,
        uint256 assetsAfterMinSharesCost,
        uint256 assetsAfterFees,
        uint256 minSharesForReceiver
    ) private view {
        if (sharesForReceiver == 0) revert MultiVault.MultiVault_DepositOrRedeemZeroShares();
        if (sharesForReceiver < minSharesForReceiver) revert MultiVault.MultiVault_SlippageExceeded();

        // Scope blocks release locals before the next check so the legacy codegen pipeline doesn't
        // blow its 16-slot stack ceiling.
        address registry = _s().bondingCurveConfig.registry;
        {
            uint256 projectedAssets =
                _s().vaults[termId][curveId].totalAssets + assetsAfterFees + (assets - assetsAfterMinSharesCost);
            if (projectedAssets > IBondingCurveRegistry(registry).getCurveMaxAssets(curveId)) {
                revert MultiVault.MultiVault_ActionExceedsMaxAssets();
            }
        }
        {
            uint256 projectedShares = _s().vaults[termId][curveId].totalShares + sharesForReceiver
                + (_isNewVault(termId, curveId) ? _s().generalConfig.minShare : 0);
            if (projectedShares > IBondingCurveRegistry(registry).getCurveMaxShares(curveId)) {
                revert MultiVault.MultiVault_ActionExceedsMaxShares();
            }
        }
    }

    function _validateRedeem(bytes32 termId, uint256 curveId, address account, uint256 shares, uint256 minAssets)
        private
        view
    {
        Storage storage s = _s();
        if (shares == 0) {
            revert MultiVault.MultiVault_DepositOrRedeemZeroShares();
        }

        if (s.vaults[termId][curveId].balanceOf[account] < shares) {
            revert MultiVault.MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = s.vaults[termId][curveId].totalShares - shares;
        if (remainingShares < s.generalConfig.minShare) {
            revert MultiVault.MultiVault_InsufficientRemainingSharesInVault(remainingShares);
        }

        (uint256 expectedAssets,,) = _calculateRedeem(termId, curveId, shares, account);

        if (expectedAssets < minAssets) {
            revert MultiVault.MultiVault_SlippageExceeded();
        }
    }

    /* =================================================== */
    /*                   READS / PREDICATES                */
    /* =================================================== */

    function _isApprovedToDeposit(address sender, address receiver) private view returns (bool) {
        return sender == receiver || (_s().approvals[receiver][sender] & uint8(ApprovalTypes.DEPOSIT)) != 0;
    }

    function _isApprovedToRedeem(address sender, address receiver) private view returns (bool) {
        return sender == receiver || (_s().approvals[receiver][sender] & uint8(ApprovalTypes.REDEMPTION)) != 0;
    }

    function _isApprovedToCreate(address sender, address creator) private view returns (bool) {
        return sender == creator || (_s().approvals[creator][sender] & uint8(ApprovalTypes.CREATION)) != 0;
    }

    function _isNewVault(bytes32 termId, uint256 curveId) private view returns (bool) {
        return _s().vaults[termId][curveId].totalShares == 0;
    }

    /// @dev True iff a deposit would directly initialize the counter-triple *as a term*. Fires only
    ///      when (a) the targeted vault is uninitialized, (b) the term is a counter-triple, and
    ///      (c) the counter-triple's default-curve vault has not yet been seeded by the
    ///      positive-triple create path. Once the term is bootstrapped, per-curve first-deposits
    ///      (on either side) are allowed and symmetrically seed the opposite-side vault via
    ///      {_initializeOppositeTripleVault}. Mirrored at both the execution-path
    ///      ({_processDeposit}) and calc-path ({_calculateTripleDeposit}) guard sites so
    ///      {previewDeposit} cannot disagree with {deposit} about feasibility.
    function _isDirectCounterTripleTermInit(bytes32 termId, uint256 curveId) private view returns (bool) {
        return _isNewVault(termId, curveId) && _isCounterTriple(termId)
            && _isNewVault(termId, _s().bondingCurveConfig.defaultCurveId);
    }

    function _minShareCostFor(VaultType vaultType, uint256 curveId) private view returns (uint256) {
        uint256 minShareCost = _minAssetsForCurve(curveId, _s().generalConfig.minShare);
        return vaultType == VaultType.ATOM ? minShareCost : minShareCost * 2;
    }

    function _minAssetsForCurve(uint256 curveId, uint256 minShare) private view returns (uint256) {
        return IBondingCurveRegistry(_s().bondingCurveConfig.registry).previewMint(minShare, 0, 0, curveId);
    }

    /// @dev Fees from every curve are routed to the default (linear) curve's vault, so the threshold is
    ///      measured in that vault's `totalShares` rather than in assets. Below it, donating fees into a
    ///      near-empty share supply would drive its share price to unintended values, so fees are waived
    ///      until the default vault has enough depth to absorb them. Uncharged dust is the intended cost.
    function _shouldChargeFees(bytes32 termId) private view returns (bool) {
        Storage storage s = _s();
        uint256 defaultCurveId = s.bondingCurveConfig.defaultCurveId;
        uint256 totalShares = s.vaults[termId][defaultCurveId].totalShares;
        if (totalShares < s.generalConfig.feeThreshold) return false;
        return true;
    }

    function _shouldChargeExitFees(bytes32 termId, uint256 curveId, uint256 sharesToRedeem)
        private
        view
        returns (bool)
    {
        Storage storage s = _s();
        uint256 defaultCurveId = s.bondingCurveConfig.defaultCurveId;
        uint256 totalShares = s.vaults[termId][defaultCurveId].totalShares;
        uint256 remainingSharesInDefaultVault;

        if (curveId == defaultCurveId) {
            remainingSharesInDefaultVault = totalShares - sharesToRedeem;
        } else {
            remainingSharesInDefaultVault = totalShares;
        }

        if (remainingSharesInDefaultVault < s.generalConfig.feeThreshold) return false;
        return true;
    }

    function _shouldChargeAtomDepositFraction(bytes32 tripleId) private view returns (bool) {
        bytes32[3] memory atomIds = _s().triples[tripleId];
        return _shouldChargeFees(atomIds[0]) && _shouldChargeFees(atomIds[1]) && _shouldChargeFees(atomIds[2]);
    }

    /// @dev Counter-stake is intentionally scoped per curve: it only blocks holding both sides of a triple on
    ///      the SAME curve. Holding opposing sides on different curves is allowed and is not a bypass — each
    ///      curve prices its own vault independently, so the two positions carry genuine opposing exposure.
    function _hasCounterStake(bytes32 tripleId, uint256 curveId, address receiver) private view returns (bool) {
        Storage storage s = _s();
        if (!s.isTriple[tripleId]) {
            revert MultiVault.MultiVault_TermNotTriple();
        }

        bytes32 oppositeId = _getInverseTripleId(tripleId);

        return s.vaults[oppositeId][curveId].balanceOf[receiver] > 0;
    }

    function _convertToShares(bytes32 termId, uint256 curveId, uint256 assets) private view returns (uint256) {
        Storage storage s = _s();
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(s.bondingCurveConfig.registry);
        return bcRegistry.previewDeposit(
            assets, s.vaults[termId][curveId].totalAssets, s.vaults[termId][curveId].totalShares, curveId
        );
    }

    function _convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) private view returns (uint256) {
        Storage storage s = _s();
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(s.bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(
            shares, s.vaults[termId][curveId].totalShares, s.vaults[termId][curveId].totalAssets, curveId
        );
    }

    function _feeOnRaw(uint256 amount, uint256 fee) private view returns (uint256) {
        return amount.mulDivUp(fee, _s().generalConfig.feeDenominator);
    }

    function _isTermCreated(bytes32 termId) private view returns (bool) {
        Storage storage s = _s();
        return s.atoms[termId].length > 0 || s.isTriple[termId];
    }

    function _tripleExists(bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId) private view {
        if (_s().triples[termId][0] != bytes32(0)) {
            revert MultiVault.MultiVault_TripleExists(termId, subjectId, predicateId, objectId);
        }
    }

    function _requireTermExists(bytes32 termId) private view {
        if (!_isTermCreated(termId)) {
            revert MultiVault.MultiVault_TermDoesNotExist(termId);
        }
    }

    /* =================================================== */
    /*           MULTIVAULT CORE INTERNALS (READ)          */
    /* =================================================== */
    /* Local reimplementations of {MultiVaultCore}'s internal getters so the library doesn't need
       to cross back into {MultiVault}/{MultiVaultCore} for primitives that operate purely on the
       same storage slots. Logic-identical to the parent contract; {MultiVaultCore} stays
       untouched and remains the public-getter source of truth. */

    function _calculateAtomId(bytes memory data) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(ATOM_SALT, keccak256(data)));
    }

    function _calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(TRIPLE_SALT, subjectId, predicateId, objectId));
    }

    function _calculateCounterTripleId(bytes32 tripleId) private pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(COUNTER_SALT, tripleId)));
    }

    function _isAtom(bytes32 atomId) private view returns (bool) {
        return _s().atoms[atomId].length != 0;
    }

    function _isCounterTriple(bytes32 termId) private view returns (bool) {
        return _s().tripleIdFromCounterId[termId] != bytes32(0);
    }

    function _getTriple(bytes32 tripleId) private view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds = _s().triples[tripleId];
        if (atomIds[0] == bytes32(0) && atomIds[1] == bytes32(0) && atomIds[2] == bytes32(0)) {
            revert MultiVaultCore.MultiVaultCore_TripleDoesNotExist(tripleId);
        }
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    function _getInverseTripleId(bytes32 tripleId) private view returns (bytes32) {
        if (_isCounterTriple(tripleId)) {
            return _s().tripleIdFromCounterId[tripleId];
        } else {
            return _calculateCounterTripleId(tripleId);
        }
    }

    function _getVaultType(bytes32 termId) private view returns (VaultType) {
        bool _isVaultAtom = _isAtom(termId);
        bool _isVaultTriple = _s().isTriple[termId];
        bool _isVaultCounterTriple = _isCounterTriple(termId);

        if (!_isVaultAtom && !_isVaultTriple && !_isVaultCounterTriple) {
            revert MultiVaultCore.MultiVaultCore_TermDoesNotExist(termId);
        }

        if (_isVaultAtom) return VaultType.ATOM;
        if (_isVaultCounterTriple) return VaultType.COUNTER_TRIPLE;
        return VaultType.TRIPLE;
    }

    function _getAtomCost() private view returns (uint256) {
        Storage storage s = _s();
        return s.atomConfig.atomCreationProtocolFee + s.generalConfig.minShare;
    }

    function _getTripleCost() private view returns (uint256) {
        Storage storage s = _s();
        return s.tripleConfig.tripleCreationProtocolFee + s.generalConfig.minShare * 2;
    }
}
