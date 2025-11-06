// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { IMultiVault, ApprovalTypes, VaultState, VaultType } from "src/interfaces/IMultiVault.sol";
import { IAtomWalletFactory } from "src/interfaces/IAtomWalletFactory.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { IAtomWallet } from "src/interfaces/IAtomWallet.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";

/**
 * @title  MultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated with atoms & triples using TRUST as the base asset.
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
    uint256 public constant MAX_BATCH_SIZE = 150;

    /// @notice Constant representing the burn address, which receives the "ghost (min) shares"
    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    /// @notice Mapping of the receiver's approved status for a given sender
    // Receiver -> Sender -> Approval Type (0 = none, 1 = deposit approval, 2 = redemption approval, 3 = both)
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
    // Epoch -> TRUST token amount used by all users, defined as the difference between the amount of TRUST
    // deposited and redeemed by actions of all users
    mapping(uint256 epoch => int256 utilizationAmount) public totalUtilization;

    /// @notice Mapping of the TRUST token amount utilization for each user in each epoch
    // User address -> Epoch -> TRUST token amount used by the user, defined as the difference between the amount of
    // TRUST
    // deposited and redeemed by the user
    mapping(address user => mapping(uint256 epoch => int256 utilizationAmount)) public personalUtilization;

    /// @notice Mapping of the last 3 active epochs for each user
    mapping(address user => uint256[3] epoch) public userEpochHistory;

    /* =================================================== */
    /*                        Errors                       */
    /* =================================================== */

    error MultiVault_ArraysNotSameLength();

    error MultiVault_AtomExists(bytes atomData);

    error MultiVault_AtomDoesNotExist(bytes32 atomId);

    error MultiVault_AtomDataTooLong();

    error MultiVault_BurnFromZeroAddress();

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

    error MultiVault_RedeemerNotApproved();

    error MultiVault_SenderNotApproved();

    error MultiVault_SlippageExceeded();

    error MultiVault_TripleExists(bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId);

    error MultiVault_TermNotTriple();

    error MultiVault_ActionExceedsMaxAssets();

    error MultiVault_ActionExceedsMaxShares();

    error MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();

    error MultiVault_DepositTooSmallToCoverMinShares();

    error MultiVault_TermDoesNotExist(bytes32 termId);

    error MultiVault_EpochNotTracked();

    error MultiVault_InvalidEpoch();

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
    )
        external
        initializer
    {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __MultiVaultCore_init(
            _generalConfig, _atomConfig, _tripleConfig, _walletConfig, _vaultFees, _bondingCurveConfig
        );
        _grantRole(DEFAULT_ADMIN_ROLE, _generalConfig.admin);
    }

    /* =================================================== */
    /*                        VIEWS                        */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function isTermCreated(bytes32 id) external view returns (bool) {
        return _isTermCreated(id);
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
        uint256 _currentEpoch = _currentEpoch();

        // Revert if calling with future epoch
        if (epoch > _currentEpoch) revert MultiVault_InvalidEpoch();

        uint256[3] memory _userEpochHistory = userEpochHistory[user];

        // Case A: check most recent activity
        if (_userEpochHistory[0] <= epoch) {
            return personalUtilization[user][_userEpochHistory[0]];
        }

        // Case B: check previous activity
        if (_userEpochHistory[1] <= epoch) {
            return personalUtilization[user][_userEpochHistory[1]];
        }

        // Case C: check previous-previous activity
        if (_userEpochHistory[2] <= epoch) {
            return personalUtilization[user][_userEpochHistory[2]];
        }

        // No tracked epoch strictly earlier than `epoch`
        revert MultiVault_EpochNotTracked();
    }

    /// @inheritdoc IMultiVault
    function getAtomWarden() external view returns (address) {
        return walletConfig.atomWarden;
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
        return _maxRedeem(sender, termId, curveId);
    }

    /// @inheritdoc IMultiVault
    function currentEpoch() external view returns (uint256) {
        return _currentEpoch();
    }

    /// @inheritdoc IMultiVault
    function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256) {
        VaultState storage vaultState = _vaults[termId][curveId];
        return IBondingCurveRegistry(bondingCurveConfig.registry)
            .currentPrice(curveId, vaultState.totalShares, vaultState.totalAssets);
    }

    /// @inheritdoc IMultiVault
    function previewAtomCreate(
        bytes32 termId,
        uint256 assets
    )
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateAtomCreate(termId, assets);
    }

    /// @inheritdoc IMultiVault
    function previewTripleCreate(
        bytes32 termId,
        uint256 assets
    )
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateTripleCreate(termId, assets);
    }

    /// @inheritdoc IMultiVault
    function previewDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        public
        view
        returns (uint256 shares, uint256 assetsAfterFees)
    {
        if (!_isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        bool isAtomVault = _isAtom(termId);
        (shares,, assetsAfterFees) = _calculateDeposit(termId, curveId, assets, isAtomVault);
    }

    /// @inheritdoc IMultiVault
    function previewRedeem(
        bytes32 termId,
        uint256 curveId,
        uint256 shares
    )
        public
        view
        returns (uint256 assetsAfterFees, uint256 sharesUsed)
    {
        if (!_isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return _calculateRedeem(termId, curveId, shares);
    }

    /// @inheritdoc IMultiVault
    function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) external view returns (uint256) {
        if (!_isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return _convertToShares(termId, curveId, assets);
    }

    /// @inheritdoc IMultiVault
    function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256) {
        if (!_isTermCreated(termId)) revert MultiVault_TermDoesNotExist(termId);
        return _convertToAssets(termId, curveId, shares);
    }

    /* =================================================== */
    /*                      Approvals                      */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function approve(address sender, ApprovalTypes approvalType) external {
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
    /*                      Atoms                          */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function createAtoms(
        bytes[] calldata data,
        uint256[] calldata assets
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32[] memory)
    {
        uint256 _amount = _validatePayment(assets);
        return _createAtoms(data, assets, _amount);
    }

    /// @notice Internal utility function to handle the creation of multiple atom vaults
    /// @param _data The array of atom data to create atoms with
    /// @param _assets The total value sent with the transaction
    /// @param _payment The total value sent with the transaction
    /// @return ids The new term IDs created for the atoms
    function _createAtoms(
        bytes[] calldata _data,
        uint256[] calldata _assets,
        uint256 _payment
    )
        internal
        returns (bytes32[] memory)
    {
        uint256 length = _data.length;
        if (length == 0) {
            revert MultiVault_NoAtomDataProvided();
        }

        if (length != _assets.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        bytes32[] memory ids = new bytes32[](length);

        for (uint256 i = 0; i < length;) {
            ids[i] = _createAtom(msg.sender, _data[i], _assets[i]);
            unchecked {
                ++i;
            }
        }

        // Add the static portion of the fee that is yet to be accounted for
        uint256 atomCreationProtocolFees = atomConfig.atomCreationProtocolFee * length;
        _accumulateStaticProtocolFees(atomCreationProtocolFees);

        _addUtilization(msg.sender, int256(_payment));

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    /// @param data The atom data to create the atom with
    /// @param assets The value to deposit into the atom
    /// @param sender The address of the sender
    /// @return atomId The new vault ID created for the atom
    function _createAtom(address sender, bytes calldata data, uint256 assets) internal returns (bytes32 atomId) {
        uint256 length = data.length;

        if (length == 0) {
            revert MultiVault_NoAtomDataProvided();
        }

        // Check if atom data length is valid.
        if (length > generalConfig.atomDataMaxLength) {
            revert MultiVault_AtomDataTooLong();
        }

        // Check if atom already exists.
        atomId = _calculateAtomId(data);
        if (_atoms[atomId].length != 0) {
            revert MultiVault_AtomExists(data);
        }

        // Map atom ID to atom data
        _atoms[atomId] = data;
        uint256 curveId = bondingCurveConfig.defaultCurveId;

        /* --- Calculate final shares and assets after fees --- */
        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateAtomCreate(atomId, assets);

        /* --- Handle protocol fees --- */
        _accumulateVaultProtocolFees(assetsAfterFixedFees);
        address atomWallet = _accumulateAtomWalletFees(atomId, assetsAfterFixedFees);

        /* --- Add assets after fees to Atom Vault (User Owned) --- */
        uint256 userSharesAfter =
            _updateVaultOnCreation(sender, atomId, curveId, assetsAfterFees, sharesForReceiver, VaultType.ATOM);

        /* --- Emit Events --- */
        emit AtomCreated(sender, atomId, data, atomWallet);

        emit Deposited(
            sender, sender, atomId, curveId, assets, assetsAfterFees, sharesForReceiver, userSharesAfter, VaultType.ATOM
        );

        // Increment total terms created
        ++totalTermsCreated;

        return atomId;
    }

    /* =================================================== */
    /*                      Triples                        */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32[] memory)
    {
        uint256 _amount = _validatePayment(assets);
        return _createTriples(subjectIds, predicateIds, objectIds, assets, _amount);
    }

    /// @notice Internal utility function to create triples and handle vault creation
    /// @param _subjectIds vault ids array of subject atoms
    /// @param _predicateIds vault ids array of predicate atoms
    /// @param _objectIds vault ids array of object atoms
    /// @param _assets The total value sent with the transaction
    /// @return ids The new vault IDs created for the triples
    function _createTriples(
        bytes32[] calldata _subjectIds,
        bytes32[] calldata _predicateIds,
        bytes32[] calldata _objectIds,
        uint256[] calldata _assets,
        uint256 _amount
    )
        internal
        returns (bytes32[] memory)
    {
        uint256 length = _subjectIds.length;
        uint256 minCost = _getTripleCost() * _assets.length;

        if (length == 0) {
            revert MultiVault_InvalidArrayLength();
        }

        if (_predicateIds.length != length || _objectIds.length != length || _assets.length != length) {
            revert MultiVault_ArraysNotSameLength();
        }

        if (_amount < minCost) {
            revert MultiVault_InsufficientBalance();
        }

        bytes32[] memory ids = new bytes32[](length);
        for (uint256 i = 0; i < length;) {
            ids[i] = _createTriple(msg.sender, _subjectIds[i], _predicateIds[i], _objectIds[i], _assets[i]);
            unchecked {
                ++i;
            }
        }

        // Add the static portion of the fee that is yet to be accounted for
        uint256 tripleCreationProtocolFees = tripleConfig.tripleCreationProtocolFee * length;
        _accumulateStaticProtocolFees(tripleCreationProtocolFees);

        /* --- Increase the users utilization ratio to calculate rewards --- */
        _addUtilization(msg.sender, int256(_amount));

        return ids;
    }

    /// @notice Internal utility function to create a triple and handle vault creation
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param assets The value to deposit into the triple
    /// @param sender The address of the sender
    /// @return tripleId The new vault ID created for the triple
    function _createTriple(
        address sender,
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId,
        uint256 assets
    )
        internal
        returns (bytes32 tripleId)
    {
        tripleId = _calculateTripleId(subjectId, predicateId, objectId);
        _tripleExists(tripleId, subjectId, predicateId, objectId);

        _requireTermExists(subjectId);
        _requireTermExists(predicateId);
        _requireTermExists(objectId);

        // Initialize the triple vault state.
        bytes32[3] memory _atomsArray = [subjectId, predicateId, objectId];
        bytes32 _counterTripleId = _calculateCounterTripleId(tripleId);

        // Set the triple mappings.
        _initializeTripleState(tripleId, _counterTripleId, _atomsArray);

        uint256 curveId = bondingCurveConfig.defaultCurveId;

        /* --- Calculate final shares and assets after fees --- */
        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateTripleCreate(tripleId, assets);

        /* --- Accumulate dynamic fees --- */
        _accumulateVaultProtocolFees(assetsAfterFixedFees);

        /* --- Add user assets after fees to vault (User Owned) --- */
        uint256 userSharesAfter =
            _updateVaultOnCreation(sender, tripleId, curveId, assetsAfterFees, sharesForReceiver, VaultType.TRIPLE);

        /* --- Add vault and triple fees to vault (Protocol Owned) --- */
        if (_shouldChargeAtomDepositFraction(tripleId)) {
            _increaseProRataVaultsAssets(
                tripleId, _feeOnRaw(assetsAfterFixedFees, tripleConfig.atomDepositFractionForTriple)
            );
        }

        /* --- Initialize the counter triple vault with min shares --- */
        _initializeInverseTripleVault(_counterTripleId, curveId, VaultType.COUNTER_TRIPLE);

        /* --- Emit events --- */
        emit TripleCreated(sender, tripleId, subjectId, predicateId, objectId);

        emit Deposited(
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

        // Increment total terms created by 2 (triple + counter triple)
        totalTermsCreated += 2;

        return tripleId;
    }

    /// @notice Internal utility function to initialize the counter triple vault with minimum shares
    /// @param tripleId The ID of the triple
    /// @param counterTripleId The ID of the counter triple
    /// @param _atomsArray The array of atom IDs that make up the triple
    function _initializeTripleState(bytes32 tripleId, bytes32 counterTripleId, bytes32[3] memory _atomsArray) internal {
        _triples[tripleId] = _atomsArray;
        _isTriple[tripleId] = true;

        // Set the counter triple mappings.
        _isTriple[counterTripleId] = true;
        _triples[counterTripleId] = _atomsArray;
        _tripleIdFromCounterId[counterTripleId] = tripleId;
    }

    /* =================================================== */
    /*                       Deposit                       */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function deposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 minShares
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        if (!_isApprovedToDeposit(msg.sender, receiver)) {
            revert MultiVault_SenderNotApproved();
        }

        _addUtilization(receiver, int256(msg.value));

        return _processDeposit(msg.sender, receiver, termId, curveId, msg.value, minShares);
    }

    /// @inheritdoc IMultiVault
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256[] memory shares)
    {
        uint256 _assetsSum = _validatePayment(assets);
        uint256 length = termIds.length;

        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert MultiVault_InvalidArrayLength();
        }

        shares = new uint256[](length);

        if (length != curveIds.length || length != assets.length || length != minShares.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        if (!_isApprovedToDeposit(msg.sender, receiver)) {
            revert MultiVault_SenderNotApproved();
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

    /// @notice Internal utility function to process a deposit
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @param assets The amount of assets to deposit
    /// @param minShares The minimum amount of shares to receive
    /// @return sharesForReceiver The amount of shares minted for the receiver
    function _processDeposit(
        address sender,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 minShares
    )
        internal
        returns (uint256)
    {
        // --- validations independent of vault type ---
        _validateMinDeposit(assets);

        // --- discover vault type and basic flags up front ---
        VaultType _vaultType = _getVaultType(termId);
        bool isNew = _isNewVault(termId, curveId);
        bool isDefault = curveId == bondingCurveConfig.defaultCurveId;

        // --- triple-only invariants before any state changes ---
        if (_vaultType != VaultType.ATOM) {
            if (_hasCounterStake(termId, curveId, receiver)) revert MultiVault_HasCounterStake();
        }

        // default curve vaults must be created via createAtoms/createTriples
        if (isNew && isDefault) {
            revert MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();
        }

        /* --- Calculate final shares and assets after fees --- */
        (uint256 sharesForReceiver, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees) =
            _calculateDeposit(termId, curveId, assets, _vaultType == VaultType.ATOM);

        /* --- Slippage check --- */
        _validateMinShares(
            termId, curveId, assets, sharesForReceiver, assetsAfterMinSharesCost, assetsAfterFees, minShares
        );

        /* --- Accumulate dynamic fees --- */
        _accumulateVaultProtocolFees(assetsAfterMinSharesCost);

        /* --- Add entry fee to vault (Protocol Owned) --- */
        if (_shouldChargeFees(termId)) {
            _increaseProRataVaultAssets(termId, _feeOnRaw(assetsAfterMinSharesCost, vaultFees.entryFee), _vaultType);
        }

        /* --- Apply atom or triple specific fees --- */
        if (_vaultType == VaultType.ATOM) {
            _accumulateAtomWalletFees(termId, assetsAfterMinSharesCost);
        } else {
            if (_shouldChargeAtomDepositFraction(termId)) {
                _increaseProRataVaultsAssets(
                    termId, _feeOnRaw(assetsAfterMinSharesCost, tripleConfig.atomDepositFractionForTriple)
                );
            }
        }

        uint256 userBalanceAfter;

        // --- user accounting (returns the user's total balance after mint) ---
        if (isNew && !isDefault) {
            userBalanceAfter =
                _updateVaultOnCreation(receiver, termId, curveId, assetsAfterFees, sharesForReceiver, _vaultType);

            if (_vaultType != VaultType.ATOM) {
                // Initialize the opposite (inverse) side of this triple for this curve.
                // Using _getInverseTripleId lets us support initializing from either side.
                bytes32 _inverseTripleId = _getInverseTripleId(termId);

                /* --- Initialize the inverse triple vault with min shares --- */
                _initializeInverseTripleVault(
                    _inverseTripleId,
                    curveId,
                    _vaultType == VaultType.TRIPLE ? VaultType.COUNTER_TRIPLE : VaultType.TRIPLE
                );
            }
        } else {
            userBalanceAfter =
                _updateVaultOnDeposit(receiver, termId, curveId, assetsAfterFees, sharesForReceiver, _vaultType);
        }

        emit Deposited(
            sender, receiver, termId, curveId, assets, assetsAfterFees, sharesForReceiver, userBalanceAfter, _vaultType
        );

        return sharesForReceiver;
    }

    /* =================================================== */
    /*                        Redeem                       */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function redeem(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        if (!_isApprovedToRedeem(msg.sender, receiver)) {
            revert MultiVault_RedeemerNotApproved();
        }

        (uint256 rawAssetsBeforeFees, uint256 assetsAfterFees) =
            _processRedeem(msg.sender, receiver, termId, curveId, shares, minAssets);
        _removeUtilization(receiver, int256(rawAssetsBeforeFees));

        return assetsAfterFees;
    }

    /// @inheritdoc IMultiVault
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256[] memory received)
    {
        if (termIds.length == 0 || termIds.length > MAX_BATCH_SIZE) {
            revert MultiVault_InvalidArrayLength();
        }

        received = new uint256[](termIds.length);

        if (termIds.length != curveIds.length || termIds.length != shares.length || termIds.length != minAssets.length)
        {
            revert MultiVault_ArraysNotSameLength();
        }

        if (!_isApprovedToRedeem(msg.sender, receiver)) {
            revert MultiVault_SenderNotApproved();
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

    /// @notice Internal utility function to process a redemption
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @param shares The amount of shares to redeem
    /// @param minAssets The minimum amount of assets to receive after fees
    /// @return rawAssetsBeforeFees The raw assets before fees
    /// @return assetsAfterFees The assets after fees
    function _processRedeem(
        address sender,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        internal
        returns (uint256, uint256)
    {
        VaultType _vaultType = _getVaultType(termId);

        _validateRedeem(termId, curveId, receiver, shares, minAssets);

        uint256 rawAssetsBeforeFees = _convertToAssets(termId, curveId, shares);

        (uint256 assetsAfterFees,) = _calculateRedeem(termId, curveId, shares);

        /* --- Accumulate fees for all vault types --- */
        _accumulateVaultProtocolFees(rawAssetsBeforeFees);

        /* --- Add vault and triple fees to vault (Protocol Owned) --- */
        if (_shouldChargeExitFees(termId, curveId, shares)) {
            _increaseProRataVaultAssets(termId, _feeOnRaw(rawAssetsBeforeFees, vaultFees.exitFee), _vaultType);
        }

        /* --- Release user assets after fees from vault (User Owned) --- */
        uint256 userSharesAfter =
            _updateVaultOnRedeem(receiver, termId, curveId, rawAssetsBeforeFees, shares, _vaultType);

        Address.sendValue(payable(receiver), assetsAfterFees);

        emit Redeemed(
            sender,
            receiver,
            termId,
            curveId,
            shares,
            userSharesAfter,
            assetsAfterFees, // net assets sent to user
            rawAssetsBeforeFees - assetsAfterFees, // total fees charged
            _vaultType
        );

        return (rawAssetsBeforeFees, assetsAfterFees);
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
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    /// @inheritdoc IMultiVault
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /// @inheritdoc IMultiVault
    function setGeneralConfig(GeneralConfig memory _generalConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
    function setAtomConfig(AtomConfig memory _atomConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        atomConfig = _atomConfig;
        emit AtomConfigUpdated(_atomConfig.atomCreationProtocolFee, _atomConfig.atomWalletDepositFee);
    }

    /// @inheritdoc IMultiVault
    function setTripleConfig(TripleConfig memory _tripleConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tripleConfig = _tripleConfig;
        emit TripleConfigUpdated(_tripleConfig.tripleCreationProtocolFee, _tripleConfig.atomDepositFractionForTriple);
    }

    /// @inheritdoc IMultiVault
    function setWalletConfig(WalletConfig memory _walletConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        walletConfig = _walletConfig;
        emit WalletConfigUpdated(
            _walletConfig.entryPoint,
            _walletConfig.atomWarden,
            _walletConfig.atomWalletBeacon,
            _walletConfig.atomWalletFactory
        );
    }

    /// @inheritdoc IMultiVault
    function setVaultFees(VaultFees memory _vaultFees) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultFees = _vaultFees;
        emit VaultFeesUpdated(_vaultFees.entryFee, _vaultFees.exitFee, _vaultFees.protocolFee);
    }

    /// @inheritdoc IMultiVault
    function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bondingCurveConfig = _bondingCurveConfig;
        emit BondingCurveConfigUpdated(_bondingCurveConfig.registry, _bondingCurveConfig.defaultCurveId);
    }

    /// @inheritdoc IMultiVault
    function sweepAccumulatedProtocolFees(uint256 epoch) external {
        _claimAccumulatedProtocolFees(epoch);
    }

    /* =================================================== */
    /*                    Accumulators                     */
    /* =================================================== */

    /// @dev Increase the accumulated protocol fees in a given epoch by a percentage of the raw assets
    /// @param _assets the raw amount of assets to calculate fees on
    function _accumulateVaultProtocolFees(uint256 _assets) internal {
        uint256 _fees = _feeOnRaw(_assets, vaultFees.protocolFee);
        uint256 epoch = _currentEpoch();
        accumulatedProtocolFees[epoch] += _fees;
        emit ProtocolFeeAccrued(epoch, msg.sender, _fees);
    }

    /// @dev Increase the accumulated protocol fees in a given epoch by an absolute amount
    /// @param _assets the absolute amount of assets to add to the accumulated protocol fees
    function _accumulateStaticProtocolFees(uint256 _assets) internal {
        uint256 epoch = _currentEpoch();
        accumulatedProtocolFees[epoch] += _assets;
        emit ProtocolFeeAccrued(epoch, msg.sender, _assets);
    }

    /// @dev Increase the accumulated atom wallet fees
    /// @param _termId the atom ID
    /// @param _assets the number of assets to calculate fees on
    /// @return atomWalletAddress the address of the atom wallet for the given atom ID
    function _accumulateAtomWalletFees(bytes32 _termId, uint256 _assets) internal returns (address) {
        address atomWalletAddress = _computeAtomWalletAddr(_termId);
        uint256 atomWalletDepositFee = _feeOnRaw(_assets, atomConfig.atomWalletDepositFee);
        accumulatedAtomWalletDepositFees[atomWalletAddress] += atomWalletDepositFee;
        emit AtomWalletDepositFeeCollected(_termId, msg.sender, atomWalletDepositFee);
        return atomWalletAddress;
    }

    /* =================================================== */
    /*                    Calculate                        */
    /* =================================================== */

    /// @dev calculates the assets received after fees and shares minted for a given deposit
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the number of assets to deposit
    /// @param isAtomVault whether the vault is an atom or triple vault
    /// @return shares the number of shares that would be minted for the deposit
    /// @return assetsAfterMinSharesCost the assets remaining after min shares cost (if applicable)
    /// @return assetsAfterFees the assets remaining after all fees
    function _calculateDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        bool isAtomVault
    )
        internal
        view
        returns (uint256 shares, uint256 assetsAfterMinSharesCost, uint256 assetsAfterFees)
    {
        if (isAtomVault) {
            return _calculateAtomDeposit(termId, curveId, assets);
        } else {
            return _calculateTripleDeposit(termId, curveId, assets);
        }
    }

    /// @dev calculates the assets received after fees and shares minted for a given creation deposit
    /// @param termId the atom or triple ID
    /// @param assets the number of assets to deposit
    /// @return shares the number of shares that would be minted for the deposit
    /// @return assetsAfterFixedFees the assets remaining after fixed fees (atom/triple cost)
    /// @return assetsAfterFees the assets remaining after all fees
    function _calculateAtomCreate(
        bytes32 termId,
        uint256 assets
    )
        internal
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        uint256 curveId = bondingCurveConfig.defaultCurveId;
        uint256 atomCost = _getAtomCost();

        if (assets < atomCost) {
            revert MultiVault_InsufficientAssets();
        }

        assetsAfterFixedFees = assets - atomCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.protocolFee);
        uint256 atomWalletDepositFee = _feeOnRaw(assetsAfterFixedFees, atomConfig.atomWalletDepositFee);

        assetsAfterFees = assetsAfterFixedFees - protocolFee - atomWalletDepositFee;
        shares = _convertToShares(termId, curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    /// @dev calculates the assets received after fees and shares minted for a given deposit
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the number of assets to deposit
    /// @return shares the number of shares that would be minted for the deposit
    /// @return assetsAfterFees the assets remaining after all fees
    function _calculateAtomDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets // assets before any fees
    )
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 assetsAfterFees;
        uint256 assetsAfterMinSharesCost = assets;

        // Account for the minShare cost
        if (_isNewVault(termId, curveId)) {
            uint256 minShareCost = _minShareCostFor(VaultType.ATOM, curveId);
            if (assets <= minShareCost) revert MultiVault_DepositTooSmallToCoverMinShares();
            assetsAfterMinSharesCost -= minShareCost;
        }

        uint256 protocolFee = _feeOnRaw(assetsAfterMinSharesCost, vaultFees.protocolFee);
        uint256 entryFee = _shouldChargeFees(termId) ? _feeOnRaw(assetsAfterMinSharesCost, vaultFees.entryFee) : 0;
        uint256 atomWalletDepositFee = _feeOnRaw(assetsAfterMinSharesCost, atomConfig.atomWalletDepositFee);

        assetsAfterFees = assetsAfterMinSharesCost - protocolFee - entryFee - atomWalletDepositFee;

        // If it's an initial deposit into a non-default curve vault, we calculate user's shares as if minShare was
        // already minted
        uint256 shares = _isNewVault(termId, curveId)
            ? IBondingCurveRegistry(bondingCurveConfig.registry)
                .previewDeposit(
                    assetsAfterFees,
                    _minAssetsForCurve(curveId, generalConfig.minShare),
                    generalConfig.minShare,
                    curveId
                )
            : _convertToShares(termId, curveId, assetsAfterFees);
        return (shares, assetsAfterMinSharesCost, assetsAfterFees);
    }

    /// @dev calculates the assets received after fees and shares minted for a given creation deposit
    /// @param termId the atom or triple ID
    /// @param assets the number of assets to deposit
    /// @return shares the number of shares that would be minted for the deposit
    /// @return assetsAfterFixedFees the assets remaining after fixed fees (atom/triple cost)
    /// @return assetsAfterFees the assets remaining after all fees
    function _calculateTripleCreate(bytes32 termId, uint256 assets) internal view returns (uint256, uint256, uint256) {
        uint256 curveId = bondingCurveConfig.defaultCurveId;
        uint256 tripleCost = _getTripleCost();

        if (assets < tripleCost) {
            revert MultiVault_InsufficientAssets();
        }

        uint256 assetsAfterFixedFees = assets - tripleCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.protocolFee);
        uint256 atomDepositFraction = _shouldChargeAtomDepositFraction(termId)
            ? _feeOnRaw(assetsAfterFixedFees, tripleConfig.atomDepositFractionForTriple)
            : 0;

        uint256 assetsAfterFees = assetsAfterFixedFees - protocolFee - atomDepositFraction;
        uint256 shares = _convertToShares(termId, curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    /// @dev calculates the assets received after fees and shares minted for a given deposit
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the number of assets to deposit
    /// @return shares the number of shares that would be minted for the deposit
    /// @return assetsAfterFees the assets remaining after all fees
    function _calculateTripleDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets // assets before any fees
    )
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 assetsAfterFees;
        uint256 assetsAfterMinSharesCost = assets;

        // Account for the minShare cost
        if (_isNewVault(termId, curveId)) {
            uint256 minShareCost = _minShareCostFor(VaultType.TRIPLE, curveId);
            if (assets <= minShareCost) revert MultiVault_DepositTooSmallToCoverMinShares();
            assetsAfterMinSharesCost -= minShareCost;
        }

        uint256 protocolFee = _feeOnRaw(assetsAfterMinSharesCost, vaultFees.protocolFee);
        uint256 entryFee = _shouldChargeFees(termId) ? _feeOnRaw(assetsAfterMinSharesCost, vaultFees.entryFee) : 0;
        uint256 atomDepositFraction = _shouldChargeAtomDepositFraction(termId)
            ? _feeOnRaw(assetsAfterMinSharesCost, tripleConfig.atomDepositFractionForTriple)
            : 0;

        assetsAfterFees = assetsAfterMinSharesCost - protocolFee - entryFee - atomDepositFraction;

        // If it's an initial deposit into a non-default curve vault, we calculate user's shares as if minShare was
        // already minted
        uint256 shares = _isNewVault(termId, curveId)
            ? IBondingCurveRegistry(bondingCurveConfig.registry)
                .previewDeposit(
                    assetsAfterFees,
                    _minAssetsForCurve(curveId, generalConfig.minShare),
                    generalConfig.minShare,
                    curveId
                )
            : _convertToShares(termId, curveId, assetsAfterFees);
        return (shares, assetsAfterMinSharesCost, assetsAfterFees);
    }

    /// @dev calculates the assets received after fees and shares burned for a given share redemption
    /// @param _termId the atom or triple ID
    /// @param _curveId the bonding curve ID
    /// @param _shares the number of shares to redeem
    /// @return assetsAfterFees the assets remaining after all fees
    /// @return sharesUsed the number of shares that would be burned for the redemption
    function _calculateRedeem(
        bytes32 _termId,
        uint256 _curveId,
        uint256 _shares
    )
        internal
        view
        returns (uint256, uint256)
    {
        uint256 assets = _convertToAssets(_termId, _curveId, _shares);

        uint256 protocolFee = _feeOnRaw(assets, vaultFees.protocolFee);
        uint256 exitFee = _shouldChargeExitFees(_termId, _curveId, _shares) ? _feeOnRaw(assets, vaultFees.exitFee) : 0;

        uint256 assetsAfterFees = assets - protocolFee - exitFee;

        return (assetsAfterFees, _shares);
    }

    /* =================================================== */
    /*                      Pro Rata                       */
    /* =================================================== */

    /// @dev Increases the total assets of the pro-rata vaults for each atom in a triple
    /// @param tripleId the triple ID
    /// @param amount the amount to increase the total assets by
    /// @notice the amount is split equally among the three atom vaults, any negligible dust amount stays in the
    /// contract
    function _increaseProRataVaultsAssets(bytes32 tripleId, uint256 amount) internal {
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _getTriple(tripleId);

        uint256 amountPerTerm = amount / 3; // negligible dust amount stays in the contract (i.e. only one or a few wei)

        _increaseProRataVaultAssets(subjectId, amountPerTerm, _getVaultType(subjectId));
        _increaseProRataVaultAssets(predicateId, amountPerTerm, _getVaultType(predicateId));
        _increaseProRataVaultAssets(objectId, amountPerTerm, _getVaultType(objectId));
    }

    /// @dev Increases the total assets of the pro-rata vault for a given termId and curveId
    /// @param termId the atom or triple ID
    /// @param amount the amount to increase the total assets by
    /// @param vaultType the type of vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    function _increaseProRataVaultAssets(bytes32 termId, uint256 amount, VaultType vaultType) internal {
        uint256 curveId = bondingCurveConfig.defaultCurveId;
        VaultState storage vaultState = _vaults[termId][curveId];
        _setVaultTotals(termId, curveId, vaultState.totalAssets + amount, vaultState.totalShares, vaultType);
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    /// @dev internal function to compute the address of the atom wallet for a given atom ID
    /// @param atomId the atom ID
    /// @return the address of the atom wallet
    function _computeAtomWalletAddr(bytes32 atomId) internal view returns (address) {
        return IAtomWalletFactory(walletConfig.atomWalletFactory).computeAtomWalletAddr(atomId);
    }

    /// @dev internal function that returns the current epoch from the TrustBonding contract
    /// @return the current epoch number
    function _currentEpoch() internal view returns (uint256) {
        return ITrustBonding(generalConfig.trustBonding).currentEpoch();
    }

    /// @dev checks if a vault for the given termId and curveId is new (i.e. has never had shares minted)
    /// @param termId the atom or triple ID
    function _isTermCreated(bytes32 termId) internal view returns (bool) {
        return _atoms[termId].length > 0 || _isTriple[termId];
    }

    function _requireVaultType(bytes32 termId) internal view returns (bool isAtomType, VaultType vaultType) {
        vaultType = _getVaultType(termId);
        return (vaultType == VaultType.ATOM, vaultType);
    }

    /// @dev calculates the fee on a raw amount provided as input
    /// @param amount the raw amount to calculate the fee on
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    /// @dev checks if an atom with the given termId exists
    /// @param termId the atom ID
    function _requireAtom(bytes32 termId) internal view {
        if (_atoms[termId].length == 0) {
            revert MultiVault_AtomDoesNotExist(termId);
        }
    }

    /// @dev checks if a triple with the given termId already exists
    /// @param termId the triple ID
    /// @param subjectId the subject atom ID
    /// @param predicateId the predicate atom ID
    /// @param objectId the object atom ID
    /// @notice reverts if the triple already exists
    function _tripleExists(bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId) internal view {
        if (_triples[termId][0] != bytes32(0)) {
            revert MultiVault_TripleExists(termId, subjectId, predicateId, objectId);
        }
    }

    function _requireTermExists(bytes32 termId) internal view {
        if (!_isTermCreated(termId)) {
            revert MultiVault_TermDoesNotExist(termId);
        }
    }

    /// @dev checks if the receiver has any shares in the opposite side of a triple vault
    /// @param tripleId the triple ID
    /// @param curveId the bonding curve ID
    /// @param receiver the address to check for counter stake
    /// @return true if the receiver has shares in the opposite side of the triple, false otherwise
    function _hasCounterStake(bytes32 tripleId, uint256 curveId, address receiver) internal view returns (bool) {
        if (!_isTriple[tripleId]) {
            revert MultiVault_TermNotTriple();
        }

        // Find the "other side" of this triple
        bytes32 oppositeId = _getInverseTripleId(tripleId);

        return _vaults[oppositeId][curveId].balanceOf[receiver] > 0;
    }

    /// @dev calculates the number of shares that would be received for a given asset deposit into a vault of a given
    /// curve
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the amount of assets to deposit
    /// @return the number of shares that would be received
    function _convertToShares(bytes32 termId, uint256 curveId, uint256 assets) internal view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewDeposit(
            assets, _vaults[termId][curveId].totalAssets, _vaults[termId][curveId].totalShares, curveId
        );
    }

    /// @dev calculates the amount of assets that would be received for a given share redemption from a vault of a given
    /// curve
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param shares the amount of shares to redeem
    /// @return the amount of assets that would be received
    function _convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) internal view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(
            shares, _vaults[termId][curveId].totalShares, _vaults[termId][curveId].totalAssets, curveId
        );
    }

    /// @dev Initializes the inverse triple vault with min shares minted to the burn address.
    ///      For regular triple vaults, the inverse is the counter triple vault, and vice versa
    /// @param inverseTripleId the ID of the inverse triple (counter or regular)
    /// @param curveId the bonding curve ID
    /// @param vaultType the vault type of the inverse triple vault
    function _initializeInverseTripleVault(bytes32 inverseTripleId, uint256 curveId, VaultType vaultType) internal {
        VaultState storage vaultState = _vaults[inverseTripleId][curveId];
        uint256 minShare = generalConfig.minShare;

        _setVaultTotals(
            inverseTripleId,
            curveId,
            vaultState.totalAssets + _minAssetsForCurve(curveId, minShare),
            vaultState.totalShares + minShare,
            vaultType
        );

        // Mint min shares to the burn address for the inverse triple vault
        _mint(BURN_ADDRESS, inverseTripleId, curveId, minShare);
    }

    /// @dev mint vault shares to address `to`
    /// @param to address to mint shares to
    /// @param termId atom or triple ID to mint shares for (term)
    /// @param curveId bonding curve ID to mint shares for
    /// @param amount amount of shares to mint
    function _mint(address to, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256) {
        _vaults[termId][curveId].balanceOf[to] += amount;
        return _vaults[termId][curveId].balanceOf[to];
    }

    /// @dev burn `amount` vault shares from address `from`
    /// @param from address to burn shares from
    /// @param termId atom or triple ID to burn shares from (term)
    /// @param curveId bonding curve ID to burn shares from
    /// @param amount amount of shares to burn
    function _burn(address from, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256) {
        if (from == address(0)) revert MultiVault_BurnFromZeroAddress();

        mapping(address => uint256) storage balances = _vaults[termId][curveId].balanceOf;
        uint256 fromBalance = balances[from];

        if (fromBalance < amount) {
            revert MultiVault_BurnInsufficientBalance();
        }

        uint256 newBalance;
        unchecked {
            newBalance = fromBalance - amount;
            balances[from] = newBalance;
        }

        return newBalance;
    }

    /// @dev Adds the new utilization of the system and the user
    /// @param user the address of the user
    /// @param totalValue the total value of the deposit
    function _addUtilization(address user, int256 totalValue) internal {
        // First, roll the user's old epoch usage forward so we adjust the current epoch’s usage
        _rollover(user);

        uint256 epoch = _currentEpoch();

        uint256[3] storage _userEpochHistory = userEpochHistory[user];
        if (_userEpochHistory[0] != epoch) {
            if (_userEpochHistory[0] != 0) {
                // Shift the history: ppa <- pa <- prev
                _userEpochHistory[2] = _userEpochHistory[1];
                _userEpochHistory[1] = _userEpochHistory[0];
            }

            _userEpochHistory[0] = epoch;
        }

        totalUtilization[epoch] += totalValue;
        emit TotalUtilizationAdded(epoch, totalValue, totalUtilization[epoch]);

        personalUtilization[user][epoch] += totalValue;
        emit PersonalUtilizationAdded(user, epoch, totalValue, personalUtilization[user][epoch]);
    }

    /// @dev Removes the utilization of the system and the user
    /// @param user the address of the user
    /// @param amountToRemove the amount of utilization to remove
    function _removeUtilization(address user, int256 amountToRemove) internal {
        // First, roll the user's old epoch usage forward so we adjust the current epoch’s usage
        _rollover(user);

        uint256 epoch = _currentEpoch();
        uint256[3] storage _userEpochHistory = userEpochHistory[user];
        if (_userEpochHistory[0] != epoch) {
            if (_userEpochHistory[0] != 0) {
                // Shift the history: ppa <- pa <- prev
                _userEpochHistory[2] = _userEpochHistory[1];
                _userEpochHistory[1] = _userEpochHistory[0];
            }

            _userEpochHistory[0] = epoch;
        }

        totalUtilization[epoch] -= amountToRemove;
        emit TotalUtilizationRemoved(epoch, amountToRemove, totalUtilization[epoch]);

        personalUtilization[user][epoch] -= amountToRemove;
        emit PersonalUtilizationRemoved(user, epoch, amountToRemove, personalUtilization[user][epoch]);
    }

    /// @dev Rollover utilization if needed: move leftover from old epoch to current epoch
    ///      and update the system utilization accordingly
    /// @param user the address of the user
    function _rollover(address user) internal {
        uint256 currentEpochLocal = _currentEpoch();
        uint256 userLastEpoch = userEpochHistory[user][0];

        // First, handle the system-wide rollover if this is the first action in the new epoch
        if (currentEpochLocal > 0 && totalUtilization[currentEpochLocal] == 0) {
            // Roll over from the immediately previous epoch
            uint256 previousEpoch = currentEpochLocal - 1;
            if (totalUtilization[previousEpoch] != 0) {
                totalUtilization[currentEpochLocal] = totalUtilization[previousEpoch];
            }
        }

        // Then handle the user-specific rollover
        if (userLastEpoch == currentEpochLocal) {
            return; // already up to date; no rollover needed
        }

        // User's first action in a new epoch - roll over their personal utilization from their respective last active
        // epoch
        int256 lastEpochUtilization = personalUtilization[user][userLastEpoch];
        if (lastEpochUtilization != 0 && personalUtilization[user][currentEpochLocal] == 0) {
            personalUtilization[user][currentEpochLocal] = lastEpochUtilization;
        }
    }

    /// @dev collects the accumulated protocol fees and transfers them to the protocol multisig
    /// @param epoch the epoch to claim the protocol fees for
    function _claimAccumulatedProtocolFees(uint256 epoch) internal {
        uint256 protocolFees = accumulatedProtocolFees[epoch];
        if (protocolFees == 0) return;

        accumulatedProtocolFees[epoch] = 0;

        Address.sendValue(payable(generalConfig.protocolMultisig), protocolFees);

        emit ProtocolFeeTransferred(epoch, generalConfig.protocolMultisig, protocolFees);
    }

    /// @dev Updates the vault state on creation of a new vault
    /// @param receiver the address of the user receiving shares
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the amount of assets being deposited
    /// @param shares the amount of shares being minted
    /// @param vaultType the type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    /// @return userSharesAfter the user's share balance after the creation
    function _updateVaultOnCreation(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType vaultType
    )
        internal
        returns (uint256)
    {
        uint256 minShare = generalConfig.minShare;
        VaultState storage vaultState = _vaults[termId][curveId];

        _setVaultTotals(
            termId,
            curveId,
            vaultState.totalAssets + assets + _minAssetsForCurve(curveId, minShare),
            vaultState.totalShares + shares + minShare,
            vaultType
        );

        uint256 sharesTotal = _mint(receiver, termId, curveId, shares);

        // Mint min shares to the burn address. Once created, the vault can never have less than min shares.
        _mint(BURN_ADDRESS, termId, curveId, minShare);

        return sharesTotal;
    }

    /// @dev Updates the vault state on a deposit operation
    /// @param receiver the address of the user receiving shares
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the amount of assets being deposited
    /// @param shares the amount of shares being minted
    /// @param _vaultType the type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    /// @return userSharesAfter the user's share balance after the deposit
    function _updateVaultOnDeposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType _vaultType
    )
        internal
        returns (uint256)
    {
        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets + assets,
            _vaults[termId][curveId].totalShares + shares,
            _vaultType
        );

        return _mint(receiver, termId, curveId, shares);
    }

    /// @dev Updates the vault state on a redeem operation
    /// @param sender the address of the user redeeming shares
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param assets the amount of assets being redeemed
    /// @param shares the amount of shares being redeemed
    /// @param vaultType the type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    /// @return userSharesAfter the user's share balance after the redeem
    function _updateVaultOnRedeem(
        address sender,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 shares,
        VaultType vaultType
    )
        internal
        returns (uint256)
    {
        VaultState storage vaultState = _vaults[termId][curveId];

        _setVaultTotals(termId, curveId, vaultState.totalAssets - assets, vaultState.totalShares - shares, vaultType);

        return _burn(sender, termId, curveId, shares);
    }

    /// @dev Sets the total assets and shares for a given vault, and emits a SharePriceChanged event
    /// @param termId the atom or triple ID
    /// @param curveId the bonding curve ID
    /// @param totalAssets the new total assets for the vault
    /// @param totalShares the new total shares for the vault
    /// @param vaultType the type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    function _setVaultTotals(
        bytes32 termId,
        uint256 curveId,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    )
        internal
    {
        IBondingCurveRegistry registry = IBondingCurveRegistry(bondingCurveConfig.registry);

        uint256 maxAssets = registry.getCurveMaxAssets(curveId);
        uint256 maxShares = registry.getCurveMaxShares(curveId);
        if (totalAssets > maxAssets) revert MultiVault_ActionExceedsMaxAssets();
        if (totalShares > maxShares) revert MultiVault_ActionExceedsMaxShares();

        VaultState storage vaultState = _vaults[termId][curveId];
        vaultState.totalAssets = totalAssets;
        vaultState.totalShares = totalShares;

        uint256 price = registry.currentPrice(curveId, totalShares, totalAssets);

        emit SharePriceChanged(termId, curveId, price, totalAssets, totalShares, vaultType);
    }

    /// @dev Validate that a deposit meets the minimum deposit requirement
    /// @param _assets the amount of assets to deposit
    function _validateMinDeposit(uint256 _assets) internal view {
        if (_assets < generalConfig.minDeposit) {
            revert MultiVault_DepositBelowMinimumDeposit();
        }
    }

    /// @dev Validate the payment for a batch operation
    /// @param assets the array of asset amounts for each operation in the batch
    /// @return total the total amount of assets for the batch
    function _validatePayment(uint256[] calldata assets) internal view returns (uint256 total) {
        uint256 length = assets.length;

        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert MultiVault_InvalidArrayLength();
        }
        for (uint256 i = 0; i < length;) {
            total += assets[i];
            unchecked {
                ++i;
            }
        }

        if (msg.value != total) {
            revert MultiVault_InsufficientBalance();
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
    )
        internal
        view
    {
        IBondingCurveRegistry registry = IBondingCurveRegistry(bondingCurveConfig.registry);

        // Prevent zero share deposits
        if (sharesForReceiver == 0) revert MultiVault_DepositOrRedeemZeroShares();

        bool isNew = _isNewVault(termId, curveId);
        uint256 minShareCost = assets - assetsAfterMinSharesCost;

        // Check the incoming assets will not exceed max assets for the curve
        uint256 projectedAssets = _vaults[termId][curveId].totalAssets + assetsAfterFees + minShareCost;
        if (projectedAssets > registry.getCurveMaxAssets(curveId)) revert MultiVault_ActionExceedsMaxAssets();

        // Check the incoming shares will not exceed max shares for the curve
        uint256 projectedShares =
            _vaults[termId][curveId].totalShares + sharesForReceiver + (isNew ? generalConfig.minShare : 0);
        if (projectedShares > registry.getCurveMaxShares(curveId)) revert MultiVault_ActionExceedsMaxShares();

        // Ensure the deposit converts to at least minSharesForReceiver shares
        if (sharesForReceiver < minSharesForReceiver) {
            revert MultiVault_SlippageExceeded();
        }
    }

    /// @dev Validate a redeem operation
    /// @param _termId the atom or triple ID
    /// @param _curveId the bonding curve ID
    /// @param _account the address of the account performing the redeem
    /// @param _shares the amount of shares to redeem
    /// @param _minAssets the minimum amount of assets to receive
    function _validateRedeem(
        bytes32 _termId,
        uint256 _curveId,
        address _account,
        uint256 _shares,
        uint256 _minAssets
    )
        internal
        view
    {
        if (_shares == 0) {
            revert MultiVault_DepositOrRedeemZeroShares();
        }

        if (_maxRedeem(_account, _termId, _curveId) < _shares) {
            revert MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = _vaults[_termId][_curveId].totalShares - _shares;
        if (remainingShares < generalConfig.minShare) {
            revert MultiVault_InsufficientRemainingSharesInVault(remainingShares);
        }

        (uint256 expectedAssets,) = _calculateRedeem(_termId, _curveId, _shares);

        if (expectedAssets < _minAssets) {
            revert MultiVault_SlippageExceeded();
        }
    }

    /// @notice Check if a sender is approved to deposit on behalf of a receiver
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @return bool Whether the sender is approved to deposit
    function _isApprovedToDeposit(address sender, address receiver) internal view returns (bool) {
        return sender == receiver || (approvals[receiver][sender] & uint8(ApprovalTypes.DEPOSIT)) != 0;
    }

    /// @notice Check if a sender is approved to redeem on behalf of a receiver
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @return bool Whether the sender is approved to redeem
    function _isApprovedToRedeem(address sender, address receiver) internal view returns (bool) {
        return sender == receiver || (approvals[receiver][sender] & uint8(ApprovalTypes.REDEMPTION)) != 0;
    }

    /// @notice Check if a vault is new (i.e. has no shares)
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @return bool Whether the vault is new or not
    function _isNewVault(bytes32 termId, uint256 curveId) internal view returns (bool) {
        return _vaults[termId][curveId].totalShares == 0;
    }

    /// @notice Get the min shares cost for creating an atom or triple vault
    /// @param vaultType The type of vault
    /// @param curveId The ID of the bonding curve
    /// @return uint256 The min shares cost for a given vault
    function _minShareCostFor(VaultType vaultType, uint256 curveId) internal view returns (uint256) {
        uint256 minShareCost = _minAssetsForCurve(curveId, generalConfig.minShare);
        return vaultType == VaultType.ATOM ? minShareCost : minShareCost * 2;
    }

    /// @notice Get the amount of assets required to mint minShare shares for a given bonding curve
    /// @param curveId The ID of the bonding curve
    /// @param minShare The minimum shares required
    /// @return uint256 The amount of assets required to mint minShare shares
    function _minAssetsForCurve(uint256 curveId, uint256 minShare) internal view returns (uint256) {
        return IBondingCurveRegistry(bondingCurveConfig.registry).previewMint(minShare, 0, 0, curveId);
    }

    /// @notice Determine if fees should be charged based on the total shares in the default curve vault
    /// @dev This is put in place in order to avoid hyperinflating the share price on a default curve vault when flowing
    /// the fees from other curves to the default curve vault (entry fees, exit fees, or atom deposit fractions)
    /// @param termId The ID of the atom or triple
    /// @return bool Whether fees should be charged or not
    function _shouldChargeFees(bytes32 termId) internal view returns (bool) {
        uint256 defaultCurveId = bondingCurveConfig.defaultCurveId;
        uint256 totalShares = _vaults[termId][defaultCurveId].totalShares;
        if (totalShares < generalConfig.feeThreshold) return false;
        return true;
    }

    /// @notice Determine if exit fees should be charged based on the remaining total shares in the default curve vault
    /// after redemption
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @param sharesToRedeem The number of shares to be redeemed
    /// @return bool Whether exit fees should be charged or not
    function _shouldChargeExitFees(
        bytes32 termId,
        uint256 curveId,
        uint256 sharesToRedeem
    )
        internal
        view
        returns (bool)
    {
        uint256 defaultCurveId = bondingCurveConfig.defaultCurveId;
        uint256 totalShares = _vaults[termId][defaultCurveId].totalShares;
        uint256 remainingSharesInDefaultVault;

        if (curveId == defaultCurveId) {
            remainingSharesInDefaultVault = totalShares - sharesToRedeem;
        } else {
            remainingSharesInDefaultVault = totalShares;
        }

        if (remainingSharesInDefaultVault < generalConfig.feeThreshold) return false;
        return true;
    }

    /// @notice Determine if the atom deposit fraction should be charged for a triple deposit
    /// @dev The atom deposit fraction is only charged if all three atoms in the triple should be charged fees (i.e. if
    /// their respective default curve vaults have enough shares already)
    /// @param tripleId The ID of the triple
    /// @return bool Whether the atom deposit fraction should be charged or not
    function _shouldChargeAtomDepositFraction(bytes32 tripleId) internal view returns (bool) {
        bytes32[3] memory atomIds = _triples[tripleId];
        return _shouldChargeFees(atomIds[0]) && _shouldChargeFees(atomIds[1]) && _shouldChargeFees(atomIds[2]);
    }

    /// @notice Get the maximum shares that can be redeemed by a user for a given vault
    /// @param sender The address of the user
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    function _maxRedeem(address sender, bytes32 termId, uint256 curveId) internal view returns (uint256) {
        return _vaults[termId][curveId].balanceOf[sender];
    }
}
