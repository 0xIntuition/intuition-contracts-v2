// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
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
contract MultiVault is MultiVaultCore, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using FixedPointMathLib for uint256;

    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    /// @notice Role used for the timelocked operations
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Role for the state migration
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    /// @notice Constant representing 1 share in the vault (1e18)
    uint256 public constant ONE_SHARE = 1e18;

    uint256 public constant MAX_BATCH_SIZE = 150;

    /// @notice Constant representing the burn address, which receives the "ghost shares"
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

    /// @notice Mapping of the last active epoch for each user
    // User address -> Last active epoch
    mapping(address user => uint256 epoch) public lastActiveEpoch;

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

    error MultiVault_TermDoesNotExist();

    error MultiVault_TermNotTriple();

    error MultiVault_ZeroAddress();

    error MultiVault_ZeroValue();

    error MultiVault_ActionExceedsMaxAssets();

    error MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();

    error MultiVault_DepositTooSmallToCoverGhostShares();

    error MultiVault_CannotDirectlyInitializeCounterTriple();

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
    /*                        Public                       */
    /* =================================================== */

    /// @inheritdoc IMultiVault
    function isTermCreated(bytes32 id) public view returns (bool) {
        return _atoms[id].length > 0 || isTriple(id);
    }

    /// @notice Returns the total cost of creating an atom, including protocol fees.
    /// @return The total cost of creating an atom.
    function getAtomCreationCost() external view returns (uint256) {
        return getAtomCost();
    }

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    /// @param assets amount of assets to calculate fee on
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets) public view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.protocolFee);
    }

    /// @notice returns amount of assets that would be charged for the entry fee given an amount of 'assets' provided
    /// @dev if the vault being deposited on has a vault total shares of 0, the entry fee is not applied
    /// @param assets amount of assets to calculate fee on
    /// @return feeAmount amount of assets that would be charged for the entry fee
    function entryFeeAmount(uint256 assets) public view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.entryFee);
    }

    /// @notice returns amount of assets that would be charged for the exit fee given an amount of 'assets' provided
    /// @dev if the vault  being redeemed from given the shares to redeem results in a total shares after of 0,
    ///      the exit fee is not applied
    /// @param assets amount of assets to calculate fee on
    /// @return feeAmount amount of assets that would be charged for the exit fee
    function exitFeeAmount(uint256 assets) public view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.exitFee);
    }

    function atomDepositFractionAmount(uint256 assets) public view returns (uint256) {
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
    function getAtomWarden() external view returns (address) {
        return walletConfig.atomWarden;
    }

    function getVault(bytes32 termId, uint256 curveId) public view returns (uint256, uint256) {
        VaultState storage vault = _vaults[termId][curveId];
        return (vault.totalAssets, vault.totalShares);
    }

    /// @notice number of shares held by an account in a term and curve
    ///
    /// @param account address of the account to get shares for
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param curveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that can be redeemed.address
    function getShares(address account, bytes32 termId, uint256 curveId) public view returns (uint256) {
        return _vaults[termId][curveId].balanceOf[account];
    }

    /// @notice computes the address of the atom wallet for the given atom id
    function computeAtomWalletAddr(bytes32 atomId) public view returns (address) {
        return IAtomWalletFactory(walletConfig.atomWalletFactory).computeAtomWalletAddr(atomId);
    }

    /* =================================================== */
    /*                    Utilities                        */
    /* =================================================== */

    /// @dev returns the current epoch
    /// @return uint256 the current epoch
    function currentEpoch() public view returns (uint256) {
        return ITrustBonding(generalConfig.trustBonding).currentEpoch();
    }

    /// @notice returns the current share price for the given vault id
    /// @dev This method is here mostly for ERC4626 compatibility reasons, and is not called internally anywhere
    ///
    /// @param termId atom or triple (term) id to get corresponding share price for
    /// @param curveId bonding curve ID to get corresponding share price for
    ///
    /// @return price current share price for the given vault id
    function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256) {
        return convertToAssets(termId, curveId, ONE_SHARE);
    }

    function previewAtomCreate(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        public
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateAtomCreate(termId, curveId, assets);
    }

    function previewTripleCreate(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        public
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        return _calculateTripleCreate(termId, curveId, assets);
    }

    /// @notice simulates the effects of the deposited amount of 'assets' and returns the estimated
    ///         amount of shares that would be minted from the deposit of `assets`
    /// @param assets amount of assets to calculate shares on
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param curveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that would be minted from the deposit of `assets`
    function previewDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        public
        view
        returns (uint256 shares, uint256 assetsAfterFees)
    {
        bool _isAtom = isAtom(termId);
        return _calculateDeposit(termId, curveId, assets, _isAtom);
    }

    function previewRedeem(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        public
        view
        returns (uint256 shares, uint256 assetsAfterFees)
    {
        bool _isAtom = isAtom(termId);
        return _calculateRedeem(termId, curveId, assets, _isAtom);
    }

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param curveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) public view returns (uint256) {
        return _convertToShares(termId, curveId, assets);
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param termId atom or triple (term) id to get corresponding assets for
    /// @param curveId bonding curve ID to get corresponding assets for
    ///
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) public view returns (uint256) {
        return _convertToAssets(termId, curveId, shares);
    }

    /* =================================================== */
    /*                      Approvals                      */
    /* =================================================== */

    /// @notice Set the approval type for a sender to act on behalf of the receiver
    /// @param sender address to set approval for
    /// @param approvalType type of approval to grant (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
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

    function _createAtoms(
        bytes[] memory _data,
        uint256[] memory _assets,
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

        for (uint256 i = 0; i < length; i++) {
            ids[i] = _createAtom(msg.sender, _data[i], _assets[i]);
        }

        _addUtilization(msg.sender, int256(_payment));

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    ///
    /// @param data The atom data to create the atom with
    /// @param assets The value to deposit into the atom
    /// @param sender The address of the sender
    ///
    /// @return atomId The new vault ID created for the atom
    function _createAtom(address sender, bytes memory data, uint256 assets) internal returns (bytes32 atomId) {
        if (data.length == 0) {
            revert MultiVault_NoAtomDataProvided();
        }

        // Check if atom data length is valid.
        if (data.length > generalConfig.atomDataMaxLength) {
            revert MultiVault_AtomDataTooLong();
        }

        // Check if atom already exists.
        atomId = calculateAtomId(data);
        if (_atoms[atomId].length != 0) {
            revert MultiVault_AtomExists(data);
        }

        // Map atom ID to atom data
        _atoms[atomId] = data;
        uint256 curveId = bondingCurveConfig.defaultCurveId;

        /* --- Calculate final shares and assets after fees --- */
        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateAtomCreate(atomId, curveId, assets);

        /* --- Handle protocol fees --- */
        _accumulateVaultProtocolFees(assetsAfterFixedFees);
        address atomWallet = _accumulateAtomWalletFees(atomId, assetsAfterFixedFees);

        /* --- Add assets after fees to Atom Vault (User Owned) --- */
        _updateVaultOnCreation(sender, atomId, curveId, assetsAfterFees, sharesForReceiver, VaultType.ATOM);

        /* --- Add entry fee to Atom Vault (Protocol Owned) --- */
        _increaseProRataVaultAssets(atomId, _feeOnRaw(assetsAfterFixedFees, vaultFees.entryFee), VaultType.ATOM);

        /* --- Emit Events --- */
        emit AtomCreated(sender, atomId, data, atomWallet);
        emit Deposited(
            sender,
            sender,
            atomId,
            curveId,
            assets,
            assetsAfterFees,
            sharesForReceiver,
            _vaults[atomId][curveId].totalShares,
            VaultType.ATOM
        );

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
    ///
    /// @param _subjectIds vault ids array of subject atoms
    /// @param _predicateIds vault ids array of predicate atoms
    /// @param _objectIds vault ids array of object atoms
    /// @param _assets The total value sent with the transaction
    ///
    /// @return ids The new vault IDs created for the triples
    function _createTriples(
        bytes32[] memory _subjectIds,
        bytes32[] memory _predicateIds,
        bytes32[] memory _objectIds,
        uint256[] memory _assets,
        uint256 _amount
    )
        internal
        returns (bytes32[] memory)
    {
        uint256 length = _subjectIds.length;
        uint256 tripleCost = getTripleCost();
        uint256 minCost = tripleCost * _assets.length;

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
        for (uint256 i = 0; i < length; i++) {
            ids[i] = _createTriple(msg.sender, _subjectIds[i], _predicateIds[i], _objectIds[i], _assets[i]);
        }

        // Add the static portion of the fee that is yet to be accounted for
        uint256 tripleCreationProtocolFees = tripleConfig.tripleCreationProtocolFee * length;
        _accumulateVaultProtocolFees(tripleCreationProtocolFees);

        /* --- Increase the users utilization ratio to calculate rewards --- */
        _addUtilization(msg.sender, int256(_amount));

        return ids;
    }

    /// @notice Internal utility function to create a triple and handle vault creation
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param assets The value to deposit into the triple
    /// @param sender The address of the sender
    ///
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
        tripleId = calculateTripleId(subjectId, predicateId, objectId);
        _tripleExists(tripleId, subjectId, predicateId, objectId);
        _requireAtom(subjectId);
        _requireAtom(predicateId);
        _requireAtom(objectId);

        // Initialize the triple vault state.
        bytes32[3] memory _atomsArray = [subjectId, predicateId, objectId];
        bytes32 _counterTripleId = getCounterIdFromTripleId(tripleId);

        // Set the triple mappings.
        _initializeTripleState(tripleId, _counterTripleId, _atomsArray);

        uint256 curveId = bondingCurveConfig.defaultCurveId;

        /* --- Calculate final shares and assets after fees --- */
        (uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
            _calculateTripleCreate(tripleId, curveId, assets);

        /* --- Accumulate dynamic fees --- */
        _accumulateVaultProtocolFees(assetsAfterFixedFees);

        /* --- Add user assets after fees to vault (User Owned) --- */
        _updateVaultOnCreation(sender, tripleId, curveId, assetsAfterFees, sharesForReceiver, VaultType.TRIPLE);

        /* --- Add vault and triple fees to vault (Protocol Owned) --- */
        _increaseProRataVaultAssets(tripleId, _feeOnRaw(assetsAfterFixedFees, vaultFees.entryFee), VaultType.TRIPLE);
        _increaseProRataVaultsAssets(
            tripleId, _feeOnRaw(assetsAfterFixedFees, tripleConfig.atomDepositFractionForTriple)
        );

        /* --- Initialize the counter vault with min shares --- */
        _initializeCounterTripleVault(_counterTripleId, curveId);

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
            _vaults[tripleId][curveId].totalShares,
            VaultType.TRIPLE
        );

        ++totalTermsCreated;
        return tripleId;
    }

    function _initializeTripleState(
        bytes32 tripleId,
        bytes32 counterTripleId,
        bytes32[3] memory _atomsArray
    )
        internal
    {
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
        if (!_isApprovedToDeposit(_msgSender(), receiver)) {
            revert MultiVault_SenderNotApproved();
        }

        _addUtilization(receiver, int256(msg.value));

        return _processDeposit(_msgSender(), receiver, termId, curveId, msg.value, minShares);
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

        if (!_isApprovedToDeposit(_msgSender(), receiver)) {
            revert MultiVault_SenderNotApproved();
        }

        for (uint256 i = 0; i < length; ++i) {
            shares[i] = _processDeposit(_msgSender(), receiver, termIds[i], curveIds[i], assets[i], minShares[i]);
        }

        _addUtilization(receiver, int256(_assetsSum));

        return shares;
    }

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
        _validateMinDeposit(assets);
        _validateMinShares(termId, curveId, assets, minShares);

        VaultType _vaultType;
        uint256 assetsAfterFees;
        uint256 sharesForReceiver;

        {
            (bool _isAtom, VaultType vt) = _requireVaultType(termId);
            _vaultType = vt;

            bool isNew = _isNewVault(termId, curveId);
            bool isDefault = curveId == bondingCurveConfig.defaultCurveId;

            if (!_isAtom) {
                if (_hasCounterStake(termId, curveId, receiver)) revert MultiVault_HasCounterStake();
                if (isNew && isCounterTriple(termId)) revert MultiVault_CannotDirectlyInitializeCounterTriple();
            }

            if (isNew && isDefault) {
                // default curve (pro-rata) vaults must be created via createAtoms/createTriples
                revert MultiVault_DefaultCurveMustBeInitializedViaCreatePaths();
            }

            // ----- fee base (after ghost-cost if lazy-init) -----
            uint256 base = assets;

            if (isNew && !isDefault) {
                uint256 ghostCost = _ghostCostFor(_vaultType);
                if (assets <= ghostCost) revert MultiVault_DepositTooSmallToCoverGhostShares();
                base = assets - ghostCost;
            }

            // ----- fee math + side effects -----
            assetsAfterFees = _applyDepositFeesAndAccumulators(termId, curveId, base, _isAtom, _vaultType, isNew);
            sharesForReceiver = _convertToShares(termId, curveId, assetsAfterFees);

            // ----- ghost shares lazy-init for brand-new non-default curve vaults -----
            if (isNew && !isDefault) {
                _lazyInitNonDefaultVault(termId, curveId, _vaultType); // mint + account for ghost shares
            }

            // ----- user accounting -----
            _updateVaultOnDeposit(receiver, termId, curveId, assetsAfterFees, minShares, _vaultType);
        }

        emit Deposited(
            sender,
            receiver,
            termId,
            curveId,
            assets,
            assetsAfterFees,
            minShares,
            _vaults[termId][curveId].totalShares,
            _vaultType
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
        if (!_isApprovedToRedeem(_msgSender(), receiver)) {
            revert MultiVault_RedeemerNotApproved();
        }

        (uint256 rawAssetsBeforeFees, uint256 assetsAfterFees) =
            _processRedeem(_msgSender(), receiver, termId, curveId, shares, minAssets);
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

        if (!_isApprovedToRedeem(_msgSender(), receiver)) {
            revert MultiVault_SenderNotApproved();
        }

        uint256 _totalAssetsBeforeFees;
        for (uint256 i = 0; i < termIds.length; ++i) {
            (uint256 assetsBeforeFees, uint256 assetsAfterFees) =
                _processRedeem(_msgSender(), receiver, termIds[i], curveIds[i], shares[i], minAssets[i]);
            _totalAssetsBeforeFees += assetsBeforeFees;
            received[i] = assetsAfterFees;
        }

        _removeUtilization(receiver, int256(_totalAssetsBeforeFees));

        return received;
    }

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
        (bool _isAtom, VaultType _vaultType) = _requireVaultType(termId);
        _validateRedeem(termId, curveId, receiver, shares, minAssets);

        uint256 rawAssetsBeforeFees = _convertToAssets(termId, curveId, shares);

        (uint256 assetsAfterFees,) = _calculateRedeem(termId, curveId, shares, _isAtom);

        /* --- Accumulate fees for all vault types --- */
        _accumulateVaultProtocolFees(rawAssetsBeforeFees);

        /* --- Add vault and triple fees to vault (Protocol Owned) --- */
        _increaseProRataVaultAssets(termId, _feeOnRaw(rawAssetsBeforeFees, vaultFees.exitFee), _vaultType);

        /* --- Release user assets after fees from vault (User Owned) --- */
        uint256 sharesTotal = _updateVaultOnRedeem(receiver, termId, curveId, assetsAfterFees, shares, _vaultType);

        Address.sendValue(payable(receiver), assetsAfterFees);

        emit Redeemed(
            sender,
            receiver,
            termId,
            curveId,
            shares,
            sharesTotal,
            rawAssetsBeforeFees,
            rawAssetsBeforeFees - assetsAfterFees,
            _vaultType
        );

        return (rawAssetsBeforeFees, assetsAfterFees);
    }

    /* =================================================== */
    /*                       Wallet                        */
    /* =================================================== */
    /// @inheritdoc IMultiVault
    function claimAtomWalletDepositFees(bytes32 termId) external nonReentrant {
        address atomWalletAddress = computeAtomWalletAddr(termId);

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

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /// @notice returns the general configuration struct
    function setGeneralConfig(GeneralConfig memory _generalConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        generalConfig = _generalConfig;
    }

    /// @notice returns the atom configuration struct
    function setAtomConfig(AtomConfig memory _atomConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        atomConfig = _atomConfig;
    }

    /// @notice returns the triple configuration struct
    function setTripleConfig(TripleConfig memory _tripleConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tripleConfig = _tripleConfig;
    }

    /// @notice returns the vault fees struct
    function setVaultFees(VaultFees memory _vaultFees) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultFees = _vaultFees;
    }

    /// @notice returns the bonding curve configuration struct
    function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bondingCurveConfig = _bondingCurveConfig;
    }

    /// @notice returns the wallet configuration struct
    function setWalletConfig(WalletConfig memory _walletConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        walletConfig = _walletConfig;
    }

    /* =================================================== */
    /*                    Accumulators                     */
    /* =================================================== */

    function _accumulateVaultProtocolFees(uint256 _assets) internal {
        uint256 _fees = _feeOnRaw(_assets, vaultFees.protocolFee);
        uint256 epoch = currentEpoch();
        accumulatedProtocolFees[epoch] += _fees;
        emit ProtocolFeeAccrued(epoch, _fees);
    }

    /// @dev Increase the accumulated atom wallet fees
    function _accumulateAtomWalletFees(bytes32 _termId, uint256 _assets) internal returns (address) {
        address atomWalletAddress = computeAtomWalletAddr(_termId);
        uint256 atomWalletDepositFee = _feeOnRaw(_assets, atomConfig.atomWalletDepositFee);
        accumulatedAtomWalletDepositFees[atomWalletAddress] += atomWalletDepositFee;
        emit AtomWalletDepositFeeCollected(_termId, msg.sender, atomWalletDepositFee);
        return atomWalletAddress;
    }

    /* =================================================== */
    /*                    Calculate                        */
    /* =================================================== */

    function _calculateDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        bool _isAtom
    )
        internal
        view
        returns (uint256 shares, uint256 assetsAfterFees)
    {
        if (_isAtom) {
            return _calculateAtomDeposit(termId, curveId, assets);
        } else {
            return _calculateTripleDeposit(termId, curveId, assets);
        }
    }

    function _calculateAtomCreate(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        internal
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
    {
        uint256 atomCost = getAtomCost();

        if (assets < atomCost) {
            revert MultiVault_InsufficientAssets();
        }

        assetsAfterFixedFees = assets - atomCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.protocolFee);
        uint256 entryFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.entryFee);
        uint256 atomWalletDepositFee = _feeOnRaw(assetsAfterFixedFees, atomConfig.atomWalletDepositFee);

        assetsAfterFees = assetsAfterFixedFees - entryFee - protocolFee - atomWalletDepositFee;
        shares = _convertToShares(termId, curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    function _calculateAtomDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        internal
        view
        returns (uint256, uint256)
    {
        bool isNew = _isNewVault(termId, curveId);
        bool isDefault = curveId == bondingCurveConfig.defaultCurveId;

        uint256 base = assets; // assets before any fees

        // Lazy init only for non-default curve
        if (isNew && !isDefault) {
            uint256 ghostCost = generalConfig.minShare;
            if (assets <= ghostCost) revert MultiVault_DepositTooSmallToCoverGhostShares();
            base = assets - ghostCost;
        }

        uint256 protocolFee = _feeOnRaw(base, vaultFees.protocolFee);
        uint256 entryFee = isNew ? 0 : _feeOnRaw(base, vaultFees.entryFee); // waive entry fee on brand-new vaults
        uint256 atomWalletDepositFee = _feeOnRaw(base, atomConfig.atomWalletDepositFee);

        uint256 assetsAfterFees = base - protocolFee - entryFee - atomWalletDepositFee;
        uint256 shares = _convertToShares(termId, curveId, assetsAfterFees);
        return (shares, assetsAfterFees);
    }

    function _calculateTripleCreate(
        bytes32 termId,
        uint256 _curveId,
        uint256 assets
    )
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 tripleCost = getTripleCost();
        if (assets < tripleCost) {
            revert MultiVault_InsufficientAssets();
        }

        uint256 assetsAfterFixedFees = assets - tripleCost;

        uint256 protocolFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.protocolFee);
        uint256 entryFee = _feeOnRaw(assetsAfterFixedFees, vaultFees.entryFee);
        uint256 atomDepositFraction = _feeOnRaw(assetsAfterFixedFees, tripleConfig.atomDepositFractionForTriple);

        uint256 assetsAfterFees = assetsAfterFixedFees - protocolFee - entryFee - atomDepositFraction;
        uint256 shares = _convertToShares(termId, _curveId, assetsAfterFees);

        return (shares, assetsAfterFixedFees, assetsAfterFees);
    }

    function _calculateTripleDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        internal
        view
        returns (uint256, uint256)
    {
        bool isNew = _isNewVault(termId, curveId);
        bool isDefault = curveId == bondingCurveConfig.defaultCurveId;

        if (isNew && isCounterTriple(termId)) {
            revert MultiVault_CannotDirectlyInitializeCounterTriple();
        }

        uint256 base = assets; // assets before any fees

        // Lazy init only for non-default curve
        if (isNew && !isDefault) {
            uint256 ghostCost = generalConfig.minShare * 2; // positive + counter triple ghost shares
            if (assets <= ghostCost) revert MultiVault_DepositTooSmallToCoverGhostShares();
            base = assets - ghostCost;
        }

        uint256 protocolFee = _feeOnRaw(base, vaultFees.protocolFee);
        uint256 entryFee = isNew ? 0 : _feeOnRaw(base, vaultFees.entryFee); // waive entry fee on brand-new vaults
        uint256 atomDepositFraction = _feeOnRaw(base, tripleConfig.atomDepositFractionForTriple);

        uint256 assetsAfterFees = base - protocolFee - entryFee - atomDepositFraction;
        uint256 shares = _convertToShares(termId, curveId, assetsAfterFees);
        return (shares, assetsAfterFees);
    }

    function _calculateRedeem(
        bytes32 termId,
        uint256 curveId,
        uint256 _shares,
        bool _isAtom
    )
        internal
        view
        returns (uint256, uint256)
    {
        if (_isAtom) {
            return _calculateAtomRedeem(termId, curveId, _shares);
        } else {
            return _calculateTripleRedeem(termId, curveId, _shares);
        }
    }

    function _calculateAtomRedeem(
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
        uint256 exitFee = _feeOnRaw(assets, vaultFees.exitFee);

        uint256 assetsAfterFees = assets - protocolFee - exitFee;

        return (assetsAfterFees, _shares);
    }

    function _calculateTripleRedeem(
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
        uint256 exitFee = _feeOnRaw(assets, vaultFees.exitFee);

        uint256 assetsAfterFees = assets - protocolFee - exitFee;

        return (assetsAfterFees, _shares);
    }

    /* =================================================== */
    /*                      Pro Rata                       */
    /* =================================================== */

    function _increaseProRataVaultsAssets(bytes32 tripleId, uint256 amount) internal {
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = getTriple(tripleId);

        uint256 amountPerAtom = amount / 3; // negligible dust amount stays in the contract (i.e. only one or a few wei)

        _increaseProRataVaultAssets(subjectId, amountPerAtom, VaultType.ATOM);
        _increaseProRataVaultAssets(predicateId, amountPerAtom, VaultType.ATOM);
        _increaseProRataVaultAssets(objectId, amountPerAtom, VaultType.ATOM);
    }

    function _increaseProRataVaultAssets(bytes32 termId, uint256 amount, VaultType vaultType) internal {
        uint256 curveId = bondingCurveConfig.defaultCurveId;
        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets + amount,
            _vaults[termId][curveId].totalShares,
            vaultType
        );
    }

    /* =================================================== */
    /*                      INTERNAL                       */
    /* =================================================== */

    function _requireVaultType(bytes32 termId) internal view returns (bool isAtomType, VaultType vaultType) {
        bool _isAtom = isAtom(termId);
        bool _isTripleVault = _isTriple[termId];
        bool _isCounterTriple = isCounterTriple(termId);

        if (!_isAtom && !_isTripleVault && !_isCounterTriple) {
            revert MultiVault_TermDoesNotExist();
        }

        VaultType _vaultType = _isAtom ? VaultType.ATOM : _isCounterTriple ? VaultType.COUNTER_TRIPLE : VaultType.TRIPLE;
        return (_isAtom, _vaultType);
    }

    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    function _requireAtom(bytes32 termId) internal view {
        if (_atoms[termId].length == 0) {
            revert MultiVault_AtomDoesNotExist(termId);
        }
    }

    function _tripleExists(bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId) internal view {
        if (_triples[termId][0] != bytes32(0)) {
            revert MultiVault_TripleExists(termId, subjectId, predicateId, objectId);
        }
    }

    function _hasCounterStake(bytes32 tripleId, uint256 curveId, address receiver) internal view returns (bool) {
        if (!isTriple(tripleId)) {
            revert MultiVault_TermNotTriple();
        }

        // Find the "other side" of this triple
        bytes32 oppositeId = isCounterTriple(tripleId)
            ? getTripleIdFromCounterId(tripleId) // we were given a counter triple -> check positive triple balance
            : getCounterIdFromTripleId(tripleId); // we were given a positive triple -> check counter triple balance

        return _vaults[oppositeId][curveId].balanceOf[receiver] > 0;
    }

    function _convertToShares(bytes32 termId, uint256 curveId, uint256 assets) internal view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewDeposit(
            assets, _vaults[termId][curveId].totalAssets, _vaults[termId][curveId].totalShares, curveId
        );
    }

    function _convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) internal view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(
            shares, _vaults[termId][curveId].totalShares, _vaults[termId][curveId].totalAssets, curveId
        );
    }

    /// @dev Initializes the counter triple vault with ghost shares for the admin
    /// @param counterTripleId the ID of the counter triple
    function _initializeCounterTripleVault(bytes32 counterTripleId, uint256 curveId) internal {
        _setVaultTotals(
            counterTripleId,
            curveId,
            _vaults[counterTripleId][curveId].totalAssets + generalConfig.minShare,
            _vaults[counterTripleId][curveId].totalShares + generalConfig.minShare,
            VaultType.COUNTER_TRIPLE
        );

        // Mint ghost shares to admin for the counter vault
        _mint(BURN_ADDRESS, counterTripleId, curveId, generalConfig.minShare);
    }

    /// @dev mint vault shares to address `to`
    ///
    /// @param to address to mint shares to
    /// @param termId atom or triple ID to mint shares for (term)
    /// @param curveId bonding curve ID to mint shares for
    /// @param amount amount of shares to mint
    function _mint(address to, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256) {
        _vaults[termId][curveId].balanceOf[to] += amount;
        return _vaults[termId][curveId].balanceOf[to];
    }

    /// @dev burn `amount` vault shares from address `from`
    ///
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
    ///
    /// @param user the address of the user
    /// @param totalValue the total value of the deposit
    function _addUtilization(address user, int256 totalValue) internal {
        // First, roll the user's old epoch usage forward so we adjust the current epoch’s usage
        _rollover(user);

        uint256 epoch = currentEpoch();

        totalUtilization[epoch] += totalValue;
        emit TotalUtilizationAdded(epoch, totalValue, totalUtilization[epoch]);

        personalUtilization[user][epoch] += totalValue;
        emit PersonalUtilizationAdded(user, epoch, totalValue, personalUtilization[user][epoch]);

        // Mark lastActiveEpoch for the user
        lastActiveEpoch[user] = epoch;
    }

    /// @dev Removes the utilization of the system and the user
    ///
    /// @param user the address of the user
    /// @param amountToRemove the amount of utilization to remove
    function _removeUtilization(address user, int256 amountToRemove) internal {
        // First, roll the user's old epoch usage forward so we adjust the current epoch’s usage
        _rollover(user);

        uint256 epoch = currentEpoch();

        totalUtilization[epoch] -= amountToRemove;
        emit TotalUtilizationRemoved(epoch, amountToRemove, totalUtilization[epoch]);

        personalUtilization[user][epoch] -= amountToRemove;
        emit PersonalUtilizationRemoved(user, epoch, amountToRemove, personalUtilization[user][epoch]);

        // Mark lastActiveEpoch for the user
        lastActiveEpoch[user] = epoch;
    }

    /// @dev Rollover utilization if needed: move leftover from old epoch to current epoch
    ///      and update the system utilization accordingly
    /// @param user the address of the user
    function _rollover(address user) internal {
        uint256 currentEpochLocal = currentEpoch();
        uint256 oldEpoch = lastActiveEpoch[user];

        // If user has never deposited before, oldEpoch might be 0
        // or if oldEpoch == currentEpochLocal, no rollover is needed
        if (oldEpoch == 0 || oldEpoch == currentEpochLocal) {
            // first ever action done by the user
            if (oldEpoch == 0) {
                lastActiveEpoch[user] = currentEpochLocal;
            }
            return;
        }

        // first action in the new epoch automatically rolls over the totalUtilization
        if (totalUtilization[currentEpochLocal] == 0) {
            totalUtilization[currentEpochLocal] = totalUtilization[oldEpoch];
            uint256 previousEpoch = currentEpochLocal - 1;
            if (currentEpochLocal > 0) {
                _claimAccumulatedProtocolFees(previousEpoch);
            }
        }

        if (personalUtilization[user][currentEpochLocal] == 0) {
            personalUtilization[user][currentEpochLocal] = personalUtilization[user][oldEpoch];
        }

        // set user’s lastActiveEpoch to the currentEpochLocal
        lastActiveEpoch[user] = currentEpochLocal;
    }

    /// @dev collects the accumulated protocol fees and transfers them to the TrustBonding contract for claiming by the
    /// users
    /// @param epoch the epoch to claim the protocol fees for
    function _claimAccumulatedProtocolFees(uint256 epoch) internal {
        uint256 protocolFees = accumulatedProtocolFees[epoch];
        if (protocolFees == 0) return;
        Address.sendValue(payable(generalConfig.protocolMultisig), protocolFees);
        emit ProtocolFeeTransferred(epoch, generalConfig.protocolMultisig, protocolFees);
    }

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
        uint256 minShares = generalConfig.minShare;

        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets + assets + minShares,
            _vaults[termId][curveId].totalShares + shares + minShares,
            vaultType
        );

        uint256 sharesTotal = _mint(receiver, termId, curveId, shares);

        // Mint ghost shares to burn address. Vault can never have less than ghost shares.
        _mint(BURN_ADDRESS, termId, curveId, minShares);

        return sharesTotal;
    }

    function _updateVaultOnDeposit(
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
        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets + assets,
            _vaults[termId][curveId].totalShares + shares,
            vaultType
        );

        return _mint(receiver, termId, curveId, shares);
    }

    /// @dev internal helper function to lazy-init non-default curve vaults with ghost shares
    function _lazyInitNonDefaultVault(bytes32 termId, uint256 curveId, VaultType _vaultType) internal {
        uint256 minShare = generalConfig.minShare;

        // mint + account for ghost shares on the target vault
        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets + minShare,
            _vaults[termId][curveId].totalShares + minShare,
            _vaultType // ATOM or TRIPLE
        );
        _mint(BURN_ADDRESS, termId, curveId, minShare);

        // if the vault is triple, also mint + account for ghost shares on the counter vault
        if (_vaultType != VaultType.ATOM) {
            bytes32 counterId = getCounterIdFromTripleId(termId);
            _setVaultTotals(
                counterId,
                curveId,
                _vaults[counterId][curveId].totalAssets + minShare,
                _vaults[counterId][curveId].totalShares + minShare,
                VaultType.COUNTER_TRIPLE
            );
            _mint(BURN_ADDRESS, counterId, curveId, minShare);
        }
    }

    /// @dev internal helper function that performs side-effects to avoid stack-too-deep errors
    function _applyDepositFeesAndAccumulators(
        bytes32 termId,
        uint256 curveId,
        uint256 base, // assets after ghost cost is subtracted
        bool isAtomVault,
        VaultType _vaultType,
        bool isNew
    )
        internal
        returns (uint256)
    {
        uint256 protocolFee = _feeOnRaw(base, vaultFees.protocolFee);
        uint256 entryFee = isNew ? 0 : _feeOnRaw(base, vaultFees.entryFee); // waive entry fee on new vaults

        // first apply the side-effects that don't alter the vault totals
        _accumulateVaultProtocolFees(base);
        _increaseProRataVaultAssets(termId, entryFee, _vaultType);

        uint256 assetsAfterFees = 0;

        // Calculate assetsAfterFees and apply side-effects that alter the vault totals
        if (isAtomVault) {
            uint256 atomWalletDepositFee = _feeOnRaw(base, atomConfig.atomWalletDepositFee);
            assetsAfterFees = base - protocolFee - entryFee - atomWalletDepositFee;
            _accumulateAtomWalletFees(termId, base);
        } else {
            uint256 atomDepositFraction = _feeOnRaw(base, tripleConfig.atomDepositFractionForTriple);
            assetsAfterFees = base - protocolFee - entryFee - atomDepositFraction;
            _increaseProRataVaultsAssets(termId, atomDepositFraction);
        }

        return assetsAfterFees;
    }

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
        _setVaultTotals(
            termId,
            curveId,
            _vaults[termId][curveId].totalAssets - assets,
            _vaults[termId][curveId].totalShares - shares,
            vaultType
        );

        return _burn(sender, termId, curveId, shares);
    }

    function _setVaultTotals(
        bytes32 termId,
        uint256 curveId,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    )
        internal
    {
        _vaults[termId][curveId].totalAssets = totalAssets;
        _vaults[termId][curveId].totalShares = totalShares;

        uint256 price;
        if (totalShares == 0) {
            price = 0; // brand‑new vault
        } else if (totalShares >= ONE_SHARE) {
            // 1 share <= supply
            price = _convertToAssets(termId, curveId, ONE_SHARE);
        } else {
            // supply smaller than 1 share --> we fallback to the curve’s marginal price
            price = IBondingCurveRegistry(bondingCurveConfig.registry).currentPrice(totalShares, curveId);
        }

        emit SharePriceChanged(termId, curveId, price, totalAssets, totalShares, vaultType);
    }

    function _sumAmounts(uint256[] memory amounts) internal pure returns (uint256 total) {
        uint256 length = amounts.length;
        for (uint256 i = 0; i < length; i++) {
            total += amounts[i];
        }
    }

    function _validateMinDeposit(uint256 _assets) internal view {
        if (_assets < generalConfig.minDeposit) {
            revert MultiVault_DepositBelowMinimumDeposit();
        }
    }

    function _validatePayment(uint256[] calldata assets) internal view returns (uint256 total) {
        if (assets.length == 0 || assets.length > MAX_BATCH_SIZE) {
            revert MultiVault_InvalidArrayLength();
        }
        for (uint256 i = 0; i < assets.length; i++) {
            total += assets[i];
        }

        if (msg.value != total) {
            revert MultiVault_InsufficientBalance();
        }

        return total;
    }

    function _validateMinShares(bytes32 _termId, uint256 _curveId, uint256 _assets, uint256 _minShares) internal view {
        uint256 maxAssets = IBondingCurveRegistry(bondingCurveConfig.registry).getCurveMaxAssets(_curveId);
        if (_assets + _vaults[_termId][_curveId].totalAssets > maxAssets) {
            revert MultiVault_ActionExceedsMaxAssets();
        }

        (uint256 expectedShares,) = previewDeposit(_termId, _curveId, _assets);

        if (expectedShares == 0) {
            revert MultiVault_DepositOrRedeemZeroShares();
        }

        if (expectedShares < _minShares) {
            revert MultiVault_SlippageExceeded();
        }
    }

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

        (, uint256 expectedAssets) = previewRedeem(_termId, _curveId, _shares);

        if (expectedAssets < _minAssets) {
            revert MultiVault_SlippageExceeded();
        }

        if (_maxRedeem(_account, _termId, _curveId) < _shares) {
            revert MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = _vaults[_termId][_curveId].totalShares - _shares;
        if (remainingShares < generalConfig.minShare) {
            revert MultiVault_InsufficientRemainingSharesInVault(remainingShares);
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

    /// @notice Get the maximum redeemable shares for a user in a vault
    /// @param sender The address of the user
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @return uint256 The maximum redeemable shares for a user in a vault
    function _maxRedeem(address sender, bytes32 termId, uint256 curveId) public view returns (uint256) {
        return _vaults[termId][curveId].balanceOf[sender];
    }

    /// @notice Check if a vault is new (i.e. has no shares)
    /// @param termId The ID of the atom or triple
    /// @param curveId The ID of the bonding curve
    /// @return bool Whether the vault is new or not
    function _isNewVault(bytes32 termId, uint256 curveId) internal view returns (bool) {
        return _vaults[termId][curveId].totalShares == 0;
    }

    /// @notice Get the ghost shares cost for creating an atom or triple vault
    /// @param vaultType The type of vault
    /// @return uint256 The ghost shares cost for a given vault
    function _ghostCostFor(VaultType vaultType) internal view returns (uint256) {
        uint256 minShare = generalConfig.minShare;
        return vaultType == VaultType.ATOM ? minShare : minShare * 2;
    }
}
