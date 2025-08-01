// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IAtomWalletFactory} from "src/interfaces/IAtomWalletFactory.sol";
import {IBondingCurveRegistry} from "src/interfaces/IBondingCurveRegistry.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {
    IMultiVaultConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    WrapperConfig
} from "src/interfaces/IMultiVaultConfig.sol";
import {ITrustBonding} from "src/interfaces/ITrustBonding.sol";

/**
 * @title  MultiVault
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages the creation and management of vaults
 *         associated with atoms & triples using Trust as the base asset.
 */
contract MultiVault is IMultiVault, Initializable, ReentrancyGuardUpgradeable {
    using FixedPointMathLib for uint256;
    using LibZip for bytes;
    using SafeERC20 for IERC20;
    using Strings for uint256;

    /* =================================================== */
    /*                  CONSTANTS                          */
    /* =================================================== */

    /// @notice Role used for the admin of the contract
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Constant representing 1 share in the vault (1e18)
    uint256 public constant ONE_SHARE = 1e18;

    /// @notice Constant representing the salt used to compute the counter triple IDs
    bytes32 public constant COUNTER_SALT = keccak256("COUNTER");

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;
    VaultFees public vaultFees;
    BondingCurveConfig public bondingCurveConfig;
    WrapperConfig public wrapperConfig;

    /// @notice MultiVaultConfig contract address
    IMultiVaultConfig public multiVaultConfig;

    /// @notice Flag indicating whether the contract is paused or not
    bool public paused;

    /// @notice ID of the last term to be created
    uint256 public termCount;

    /// @notice Mapping of term ID to bonding curve ID to vault state
    // Term ID (atom or triple ID) -> Bonding Curve ID -> Vault State
    mapping(bytes32 termId => mapping(uint256 bondingCurveId => VaultState vaultState)) public vaults;

    /// @notice Mapping of the receiver's approved status for a given sender
    // Receiver -> Sender -> Approval Type (0 = none, 1 = deposit approval, 2 = redemption approval, 3 = both)
    mapping(address receiver => mapping(address sender => uint8 approvalType)) public approvals;

    /// @notice Mapping of vault ID to atom data
    // Vault ID -> Atom Data
    mapping(bytes32 atomId => bytes data) public atomData;

    /// @notice Mapping of triple vault ID to the underlying atom IDs that make up the triple
    // Triple ID -> atomIDs that comprise the triple
    mapping(bytes32 tripleId => bytes32[3] tripleAtomIds) public triples;

    /// @notice Mapping of term IDs to determine whether a term is a triple or not
    // Term ID -> (Is Triple)
    mapping(bytes32 termId => bool isTriple) public isTriple;

    /// @notice Mapping of counter triple IDs to the corresponding triple IDs
    mapping(bytes32 counterTripleId => bytes32 tripleId) public tripleIdFromCounter;

    /// @notice Mapping of the TRUST token amount utilization for each epoch
    // Epoch -> TRUST token amount used by all users, defined as the difference between the amount of TRUST
    // deposited and redeemed by actions of all users
    mapping(uint256 epoch => int256 utilizationAmount) public totalUtilization;

    /// @notice Mapping of the TRUST token amount utilization for each user in each epoch
    // User address -> Epoch -> TRUST token amount used by the user, defined as the difference between the amount of TRUST
    // deposited and redeemed by the user
    mapping(address user => mapping(uint256 epoch => int256 utilizationAmount)) public personalUtilization;

    /// @notice Mapping of the last active epoch for each user
    // User address -> Last active epoch
    mapping(address user => uint256 epoch) public lastActiveEpoch;

    /// @notice Mapping of the accumulated protocol fees for each epoch
    // Epoch -> Accumulated protocol fees
    mapping(uint256 epoch => uint256 accumulatedFees) public accumulatedProtocolFees;

    /// @notice Mapping of epochs to whether protocol fee distribution is enabled for that epoch or not
    // Epoch -> Is protocol fee distribution enabled for that epoch
    mapping(uint256 epoch => bool isProtocolFeeDistributionEnabled) public protocolFeeDistributionEnabledAtEpoch;

    /// @notice Mapping of the atom wallet address to the accumulated fees for that wallet
    // Atom wallet address -> Accumulated fees
    mapping(address atomWallet => uint256 accumulatedFees) public accumulatedAtomWalletDepositFees;

    /// @notice Mapping of the associated wrapped ERC20 token for each term ID and bonding curve ID
    mapping(bytes32 termId => mapping(uint256 curveId => address wrappedERC20)) public wrappedERC20Tokens;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

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

    /// @notice Initializes the MultiVault contract
    /// @dev This function is called only once (during the contract initialization)
    /// @param _multiVaultConfig address of the MultiVaultConfig contract
    function initialize(address _multiVaultConfig) external initializer {
        __ReentrancyGuard_init();

        if (_multiVaultConfig == address(0)) {
            revert Errors.MultiVault_ZeroAddress();
        }

        multiVaultConfig = IMultiVaultConfig(_multiVaultConfig);

        // synchronize the config when the contract is initialized
        syncConfig();
    }

    /* =================================================== */
    /*                     FALLBACK                        */
    /* =================================================== */

    /// @notice fallback function to decompress the calldata and call the appropriate function
    fallback() external {
        LibZip.cdFallback();
    }

    /* =================================================== */
    /*                     MODIFIERS                       */
    /* =================================================== */

    /// @dev Modifier that checks that an account has a specific role
    /// @param role The role to check
    modifier onlyRole(bytes32 role) {
        if (!AccessControl(address(multiVaultConfig)).hasRole(role, msg.sender)) {
            revert Errors.MultiVault_AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is not paused
    modifier whenNotPaused() {
        if (paused) {
            revert Errors.MultiVault_ContractPaused();
        }
        _;
    }

    /* =================================================== */
    /*              ACCESS-RESTRICTED FUNCTIONS            */
    /* =================================================== */

    /// @dev recovers the accidentally sent tokens to the contract. Trust token can never be recovered
    ///      since it is the base asset of the protocol
    ///
    /// @param token address of the token to recover
    /// @param recipient address to send the recovered tokens to
    function recoverTokens(address token, address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            revert Errors.MultiVault_ZeroAddress();
        }

        if (token == generalConfig.trust) {
            revert Errors.MultiVault_CannotRecoverTrust();
        }

        if (recipient == address(0)) {
            revert Errors.MultiVault_ZeroAddress();
        }

        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(recipient, balance);

        emit TokensRecovered(token, recipient, balance);
    }

    /// @notice Registers a wrapped ERC20 token for a specific term ID and bonding curve ID
    /// @dev This function can only be called by the wrapped ERC20 factory
    ///
    /// @param termId The ID of the term (atom or triple)
    /// @param bondingCurveId The ID of the bonding curve
    /// @param wrappedERC20 The address of the wrapped ERC20 token to register
    function registerWrappedERC20(bytes32 termId, uint256 bondingCurveId, address wrappedERC20) external {
        if (msg.sender != wrapperConfig.wrappedERC20Factory) {
            revert Errors.MultiVault_OnlyWrappedERC20Factory();
        }

        if (wrappedERC20Tokens[termId][bondingCurveId] != address(0)) {
            revert Errors.MultiVault_WrappedERC20AlreadySet();
        }

        wrappedERC20Tokens[termId][bondingCurveId] = wrappedERC20;

        emit WrappedERC20Registered(termId, bondingCurveId, wrappedERC20);
    }

    /// @notice This method allocates user’s internal balance to the wrapper’s address if they are wrapping, or returns the wrapper’s
    ///         internal balance to the user if they are unwrapping, always keeping the internal and external accounting totals in sync
    ///
    /// @dev This function can only be called by the associated wrapped ERC20 token for the given term ID and bonding curve ID
    ///
    /// @param from The address from which the shares are being transferred
    /// @param to The address to which the shares are being transferred
    /// @param termId The ID of the term (atom or triple)
    /// @param bondingCurveId The ID of the bonding curve
    /// @param shares The amount of shares to transfer
    function wrapperTransfer(address from, address to, bytes32 termId, uint256 bondingCurveId, uint256 shares)
        external
        nonReentrant
    {
        if (msg.sender != wrappedERC20Tokens[termId][bondingCurveId]) {
            revert Errors.MultiVault_OnlyAssociatedWrappedERC20();
        }
        if (from == address(0) || to == address(0)) {
            revert Errors.MultiVault_ZeroAddress();
        }
        if (!isBondingCurveIdValid(bondingCurveId)) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }
        // early return in case no shares are being transferred
        if (from == to || shares == 0) return;

        if (vaults[termId][bondingCurveId].balanceOf[from] < shares) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        unchecked {
            vaults[termId][bondingCurveId].balanceOf[from] -= shares;
            vaults[termId][bondingCurveId].balanceOf[to] += shares;
        }

        emit WrapperTransfer(from, to, termId, bondingCurveId, shares);
    }

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /* -------------------------- */
    /*         Config Sync        */
    /* -------------------------- */

    /// @notice This function is used to synchronize the configuration of the MultiVault contract,
    ///         using the MultiVaultConfig contract as the single source of truth. Anyone can call
    ///         this function at any time, and it's also automatically called as the part of any
    ///         config-changing function in the MultiVaultConfig contract.
    function syncConfig() public nonReentrant {
        GeneralConfig memory _generalConfig = multiVaultConfig.getGeneralConfig();
        AtomConfig memory _atomConfig = multiVaultConfig.getAtomConfig();
        TripleConfig memory _tripleConfig = multiVaultConfig.getTripleConfig();
        WalletConfig memory _walletConfig = multiVaultConfig.getWalletConfig();
        VaultFees memory _vaultFees = multiVaultConfig.getVaultFees();
        BondingCurveConfig memory _bondingCurveConfig = multiVaultConfig.getBondingCurveConfig();
        WrapperConfig memory _wrapperConfig = multiVaultConfig.getWrapperConfig();

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
        vaultFees = _vaultFees;
        bondingCurveConfig = _bondingCurveConfig;
        wrapperConfig = _wrapperConfig;
        paused = Pausable(address(multiVaultConfig)).paused();

        emit ConfigSynced(msg.sender);
    }

    /* -------------------------- */
    /*         AtomWallet         */
    /* -------------------------- */

    /// @notice Claims the accumulated fees for the atom wallet associated with the given atom ID
    /// @dev The caller must be the corresponding atom wallet to make sure the AtomWallet contract actually exists
    function claimAtomWalletDepositFees(bytes32 atomId) external {
        address atomWalletAddress = computeAtomWalletAddr(atomId);

        // Restrict access to the associated atom wallet
        if (msg.sender != atomWalletAddress) {
            revert Errors.MultiVault_OnlyAssociatedAtomWallet();
        }

        uint256 accumulatedFeesForAtomWallet = accumulatedAtomWalletDepositFees[atomWalletAddress];

        // Transfer accumulated fees to the atom wallet owner
        if (accumulatedFeesForAtomWallet > 0) {
            accumulatedAtomWalletDepositFees[atomWalletAddress] = 0;
            address atomWalletOwner = AtomWallet(payable(atomWalletAddress)).owner();

            IERC20(generalConfig.trust).safeTransfer(atomWalletOwner, accumulatedFeesForAtomWallet);

            emit AtomWalletDepositFeesClaimed(atomId, atomWalletOwner, accumulatedFeesForAtomWallet);
        }
    }

    /* -------------------------- */
    /*      ERC1155 Transfers     */
    /* -------------------------- */

    /// @notice Transfer vault shares from one user to another
    /// @dev This function is added to comply with the ERC1155 standard, but share transfers are not enabled yet
    function safeTransferFrom(
        address, /* from */
        address, /* to */
        bytes32, /* termId */
        uint256, /* bondingCurveId */
        uint256, /* amount */
        bytes calldata /* data */
    ) external pure {
        revert Errors.MultiVault_TransfersNotEnabled();
    }

    /// @notice Transfer vault shares from one user to another in a batch
    /// @dev This function is added to comply with the ERC1155 standard, but share transfers are not enabled yet
    function safeBatchTransferFrom(
        address, /* from */
        address, /* to */
        uint256[] calldata, /* ids */
        uint256, /* bondingCurveId */
        uint256[] calldata, /* values */
        bytes calldata /* data */
    ) external pure {
        revert Errors.MultiVault_TransfersNotEnabled();
    }

    /* -------------------------- */
    /*         Approvals          */
    /* -------------------------- */

    /// @notice Set the approval type for a sender to act on behalf of the receiver
    /// @param sender address to set approval for
    /// @param approvalType type of approval to grant (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
    function approve(address sender, ApprovalTypes approvalType) external {
        address receiver = msg.sender;

        if (receiver == sender) {
            revert Errors.MultiVault_CannotApproveOrRevokeSelf();
        }

        if (approvalType == ApprovalTypes.NONE) {
            delete approvals[receiver][sender];
        } else {
            approvals[receiver][sender] = uint8(approvalType);
        }

        emit ApprovalTypeUpdated(sender, receiver, approvalType);
    }

    /* -------------------------- */
    /*         Create Atom        */
    /* -------------------------- */

    /// @notice Create an atom and return its vault id
    ///
    /// @param data atom data to create atom with
    /// @param value amount of Trust to deposit into the atom
    ///
    /// @return id vault id of the atom
    function createAtom(bytes calldata data, uint256 value) external whenNotPaused nonReentrant returns (bytes32) {
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = data;
        bytes32[] memory ids = _createAtoms(atomDataArray, value);
        return ids[0];
    }

    /// @notice Batch create atoms and return their vault ids
    ///
    /// @param atomDataArray atom data array to create atoms with
    /// @param value amount of Trust to deposit into all atoms combined
    ///
    /// @return ids vault ids array of the atoms
    function batchCreateAtom(bytes[] calldata atomDataArray, uint256 value)
        external
        whenNotPaused
        nonReentrant
        returns (bytes32[] memory)
    {
        return _createAtoms(atomDataArray, value);
    }

    /// @notice Internal utility function to create atoms and handle vault creation
    ///
    /// @param atomDataArray The atom data array to create atoms with
    /// @param totalValue The total value sent with the transaction
    ///
    /// @return ids The new vault IDs created for the atoms
    function _createAtoms(bytes[] memory atomDataArray, uint256 totalValue) internal returns (bytes32[] memory) {
        IERC20(generalConfig.trust).safeTransferFrom(msg.sender, address(this), totalValue);

        uint256 length = atomDataArray.length;
        if (length == 0) {
            revert Errors.MultiVault_NoAtomDataProvided();
        }

        uint256 atomCost = getAtomCost();
        uint256 requiredValue = atomCost * length;

        if (totalValue < requiredValue) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        uint256 valuePerAtom = totalValue / length;
        bytes32[] memory ids = new bytes32[](length);

        for (uint256 i = 0; i < length; i++) {
            ids[i] = _createAtomSubprocess(atomDataArray[i], valuePerAtom, atomCost, msg.sender);
        }

        // Add the static portion of the fee that is yet to be accounted for
        uint256 atomCreationProtocolFees = atomConfig.atomCreationProtocolFee * length;

        _addUtilization(msg.sender, int256(totalValue));
        _accumulateProtocolFees(atomCreationProtocolFees);

        return ids;
    }

    /// @notice Internal utility function to create an atom and handle vault creation
    ///
    /// @param data The atom data to create the atom with
    /// @param valuePerAtom The value to deposit into the atom
    /// @param atomCost The cost of creating the atom
    /// @param sender The address of the sender
    ///
    /// @return atomId The new vault ID created for the atom
    function _createAtomSubprocess(bytes memory data, uint256 valuePerAtom, uint256 atomCost, address sender)
        internal
        returns (bytes32 atomId)
    {
        // Validate atom data length
        if (data.length > generalConfig.atomDataMaxLength) {
            revert Errors.MultiVault_AtomDataTooLong();
        }

        // Check if atom already exists based on hash
        atomId = getAtomIdFromData(data);
        if (atomData[atomId].length != 0) {
            revert Errors.MultiVault_AtomExists(data);
        }

        // Calculate user deposit amount after deducting the static fees to create the atom
        uint256 userDeposit = valuePerAtom - atomCost;

        // Map the new atom ID to the atom data
        atomData[atomId] = data;
        termCount = termCount + 1;

        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(userDeposit, atomId, bondingCurveConfig.defaultCurveId, true, false, 0);

        // Deposit user funds into vault and mint shares
        _depositOnVaultCreation(atomId, sender, feesAndSharesBreakdown.assetsDelta, valuePerAtom);

        // Call _applyFees to make sure atomWalletDepositFees are accumulated correctly
        _applyFees(atomId, bondingCurveConfig.defaultCurveId, feesAndSharesBreakdown, false);

        // Get atom wallet address for the corresponding atom
        address atomWallet = computeAtomWalletAddr(atomId);

        emit AtomCreated(atomId, sender, atomWallet);

        return atomId;
    }

    /* -------------------------- */
    /*        Create Triple       */
    /* -------------------------- */

    /// @notice Create a triple and return its vault id
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param value amount of Trust to deposit into the triple
    ///
    /// @return id vault id of the triple
    function createTriple(bytes32 subjectId, bytes32 predicateId, bytes32 objectId, uint256 value)
        external
        whenNotPaused
        nonReentrant
        returns (bytes32)
    {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);

        subjectIds[0] = subjectId;
        predicateIds[0] = predicateId;
        objectIds[0] = objectId;

        bytes32[] memory ids = _createTriples(subjectIds, predicateIds, objectIds, value);

        return ids[0];
    }

    /// @notice Batch create triples and return their ids
    ///
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// @param value amount of Trust to deposit into the triples
    ///
    /// @return ids vault ids array of the triples
    function batchCreateTriple(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256 value
    ) external whenNotPaused nonReentrant returns (bytes32[] memory) {
        return _createTriples(subjectIds, predicateIds, objectIds, value);
    }

    /// @notice Internal utility function to create triples and handle vault creation
    ///
    /// @param subjectIds vault ids array of subject atoms
    /// @param predicateIds vault ids array of predicate atoms
    /// @param objectIds vault ids array of object atoms
    /// @param totalValue The total value sent with the transaction
    ///
    /// @return ids The new vault IDs created for the triples
    function _createTriples(
        bytes32[] memory subjectIds,
        bytes32[] memory predicateIds,
        bytes32[] memory objectIds,
        uint256 totalValue
    ) internal returns (bytes32[] memory) {
        IERC20(generalConfig.trust).safeTransferFrom(msg.sender, address(this), totalValue);

        uint256 length = subjectIds.length;

        if (length == 0) {
            revert Errors.MultiVault_NoTriplesProvided();
        }

        if (predicateIds.length != length || objectIds.length != length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        uint256 tripleCost = getTripleCost();
        uint256 requiredValue = tripleCost * length;

        if (totalValue < requiredValue) {
            revert Errors.MultiVault_InsufficientBalance();
        }

        uint256 valuePerTriple = totalValue / length;
        bytes32[] memory ids = new bytes32[](length);

        for (uint256 i = 0; i < length; i++) {
            ids[i] = _createTripleSubprocess(
                subjectIds[i], predicateIds[i], objectIds[i], valuePerTriple, tripleCost, msg.sender
            );
        }

        // Add the static portion of the fee that is yet to be accounted for
        uint256 tripleCreationProtocolFees = tripleConfig.tripleCreationProtocolFee * length;

        _addUtilization(msg.sender, int256(totalValue));
        _accumulateProtocolFees(tripleCreationProtocolFees);

        return ids;
    }

    /// @notice Internal utility function to create a triple and handle vault creation
    ///
    /// @param subjectId vault id of the subject atom
    /// @param predicateId vault id of the predicate atom
    /// @param objectId vault id of the object atom
    /// @param valuePerTriple The value to deposit into the triple
    /// @param tripleCost The cost of creating the triple
    /// @param sender The address of the sender
    ///
    /// @return tripleId The new vault ID created for the triple
    function _createTripleSubprocess(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId,
        uint256 valuePerTriple,
        uint256 tripleCost,
        address sender
    ) internal returns (bytes32 tripleId) {
        bytes32[3] memory tripleAtomIds = [subjectId, predicateId, objectId];

        // Validate atoms
        for (uint256 j = 0; j < 3; j++) {
            bytes32 atomId = tripleAtomIds[j];
            if (!isAtomInstantiated(atomId)) {
                revert Errors.MultiVault_AtomDoesNotExist(atomId);
            }
        }

        // Check if triple already exists
        tripleId = tripleIdFromAtomIds(subjectId, predicateId, objectId);

        // Check if the first element of the triple is not zero, which indicates that the triple already exists.
        if (triples[tripleId][0] != bytes32(0)) {
            revert Errors.MultiVault_TripleExists(subjectId, predicateId, objectId);
        }

        // Calculate user deposit amount after deducting the static fees to create the triple
        uint256 userDeposit = valuePerTriple - tripleCost;

        // Initialize the triple vault state.
        triples[tripleId] = tripleAtomIds;
        termCount = termCount + 1;
        isTriple[tripleId] = true;
        tripleIdFromCounter[getCounterIdFromTriple(tripleId)] = tripleId;

        uint256 defaultBondingCurveId = bondingCurveConfig.defaultCurveId;

        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(userDeposit, tripleId, bondingCurveConfig.defaultCurveId, true, false, 0);

        // Deposit user funds into vault and mint shares
        _depositOnVaultCreation(tripleId, sender, feesAndSharesBreakdown.assetsDelta, valuePerTriple);

        // Call _applyFees to make sure atomDepositFraction is distributed correctly
        _applyFees(tripleId, bondingCurveConfig.defaultCurveId, feesAndSharesBreakdown, true);

        // Update underlying atom vaults
        if (tripleConfig.totalAtomDepositsOnTripleCreation > 0) {
            uint256 amountPerAtom = tripleConfig.totalAtomDepositsOnTripleCreation / 3;
            for (uint256 j = 0; j < 3; j++) {
                bytes32 atomId = tripleAtomIds[j];
                _setVaultTotals(
                    atomId,
                    defaultBondingCurveId,
                    vaults[atomId][defaultBondingCurveId].totalAssets + amountPerAtom,
                    vaults[atomId][defaultBondingCurveId].totalShares
                );
            }
        }

        emit TripleCreated(tripleId, sender, subjectId, predicateId, objectId);

        return tripleId;
    }

    /* -------------------------- */
    /*      Deposit/Redeem        */
    /* -------------------------- */

    /// @notice Deposit Trust into a vault using a specified bonding curve and grant ownership of 'shares' to 'receiver'
    ///
    /// @param receiver The address to receive the shares
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param value The amount of Trust to deposit
    /// @param minSharesToReceive The minimum amount of shares to receive in return for the deposit
    ///
    /// @return shares The amount of shares minted
    function deposit(
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 value,
        uint256 minSharesToReceive
    ) external whenNotPaused nonReentrant returns (uint256) {
        if (!isApprovedToDeposit(msg.sender, receiver)) {
            revert Errors.MultiVault_SenderNotApproved();
        }

        IERC20(generalConfig.trust).safeTransferFrom(msg.sender, address(this), value);

        return _deposit(receiver, termId, bondingCurveId, value, minSharesToReceive);
    }

    /// @notice Batch deposit Trust into multiple vaults using specified bonding curves and grant ownership of 'shares' to 'receiver'
    ///
    /// @param receiver The address to receive the shares
    /// @param termIds The IDs of the atoms or triples (terms)
    /// @param bondingCurveIds The IDs of the bonding curves to use
    /// @param amounts The amounts of Trust to deposit
    /// @param minSharesToReceive The minimum amounts of shares to receive in return for the deposits
    ///
    /// @return shares The amounts of shares minted for each respective vault
    function batchDeposit(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata amounts,
        uint256[] calldata minSharesToReceive
    ) external whenNotPaused nonReentrant returns (uint256[] memory) {
        uint256 length = termIds.length;

        if (length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        if (length != bondingCurveIds.length || length != amounts.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        if (!isApprovedToDeposit(msg.sender, receiver)) {
            revert Errors.MultiVault_SenderNotApproved();
        }

        // Pull the total required Trust amount from the user in a single transfer to save gas
        IERC20(generalConfig.trust).safeTransferFrom(msg.sender, address(this), _getSum(amounts));

        uint256[] memory shares = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            shares[i] = _deposit(receiver, termIds[i], bondingCurveIds[i], amounts[i], minSharesToReceive[i]);
        }

        return shares;
    }

    /// @notice Internal utility function to deposit Trust into a vault
    ///
    /// @param receiver The address to receive the shares
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param value The amount of Trust to deposit
    /// @param minSharesToReceive The minimum amount of shares to receive in return for the deposit
    ///
    /// @return shares The amount of shares minted
    function _deposit(
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 value,
        uint256 minSharesToReceive
    ) internal returns (uint256) {
        uint256 grossAssets = value;
        bool isTripleVault = isTripleId(termId);
        bool isCounterTripleVault = isCounterTripleId(termId);

        if (!isTermIdValid(termId)) {
            revert Errors.MultiVault_TermDoesNotExist();
        }

        if (value < generalConfig.minDeposit) {
            revert Errors.MultiVault_DepositBelowMinimumDeposit();
        }

        if (!isBondingCurveIdValid(bondingCurveId)) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        if (isTripleVault) {
            if (_hasCounterStake(termId, bondingCurveId, receiver)) {
                revert Errors.MultiVault_HasCounterStake();
            }
        }

        bool isCreation = vaults[termId][bondingCurveId].totalShares == 0;

        // If the totalShares are 0, it means that the vault is being initialized.
        // For this reason, we need to deduct the minShare amount from the user deposit
        // to be able to mint the ghost shares that are minted to the vault for security
        // reasons (inflation attack prevention, etc.). Effectively, the first depositor
        // in a non-default bonding curve vault is minting the ghost shares to the vault,
        // thus bypassing the need to initialize (create) the vault before allowing the
        // deposits into it. This is also done in order to prevent having multiple users
        // being labeled as "creators" for a certain term, as only the one who creted
        // the vault with the default bonding curve Id is considered the creator.
        if (isCreation) {
            uint256 ghostCost = generalConfig.minShare; // first minShare for the atom or positive triple vault
            if (isTripleVault) ghostCost += generalConfig.minShare; // second minShare for counter triple vault
            if (value < ghostCost) revert Errors.MultiVault_DepositTooSmallToCoverGhostShares(); // sanity check to ensure the user has enough Trust to cover the ghost shares

            // deduct the ghost shares cost from the user deposit
            value -= ghostCost;

            // adjust minSharesToReceive to account for the ghost shares and avoid underflow
            minSharesToReceive = minSharesToReceive > ghostCost ? minSharesToReceive - ghostCost : 0;

            if (isCounterTripleVault) {
                revert Errors.MultiVault_CannotDirectlyInitializeCounterTripleVault();
            }
        }

        _validateDeposit(value, minSharesToReceive, termId, bondingCurveId);

        // compute shares and fees
        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(value, termId, bondingCurveId, true, false, 0);

        // process the deposit using pre-calculated shares and net assets (assetsDelta)
        _processDeposit(
            receiver,
            termId,
            bondingCurveId,
            feesAndSharesBreakdown.sharesForReceiver,
            feesAndSharesBreakdown.assetsDelta,
            isTripleVault,
            isCreation
        );

        // apply relevant fees
        _applyFees(termId, bondingCurveId, feesAndSharesBreakdown, isTripleVault);

        // increase user's utilization
        _addUtilization(receiver, int256(value));

        emit Deposited(
            termId,
            bondingCurveId,
            msg.sender,
            receiver,
            grossAssets,
            feesAndSharesBreakdown.assetsDelta,
            feesAndSharesBreakdown.sharesForReceiver
        );

        return feesAndSharesBreakdown.sharesForReceiver;
    }

    /// @dev writes vault‐state and mints shares using numbers that were
    ///      already pre-calculated in `_computeFeesAndShares`.
    ///
    /// @param receiver address to mint shares to
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sharesForReceiver  shares to mint to `receiver`
    /// @param assetsDelta amount of assets to add to the vault
    /// @param isTripleVault whether the vault is a triple vault or not
    /// @param isCreation whether the vault is being created or not (i.e. is this the first deposit into the vault)
    function _processDeposit(
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 sharesForReceiver,
        uint256 assetsDelta,
        bool isTripleVault,
        bool isCreation
    ) internal {
        if (isCreation) {
            // On creation, user buys `minShare` ghost shares for the vault, plus (for triples) another
            // `minShare` for the counter triple vault

            uint256 minShare = generalConfig.minShare;

            _setVaultTotals(
                termId,
                bondingCurveId,
                vaults[termId][bondingCurveId].totalAssets + assetsDelta + minShare,
                vaults[termId][bondingCurveId].totalShares + sharesForReceiver + minShare
            );

            _mint(generalConfig.admin, termId, bondingCurveId, minShare);
            _mint(receiver, termId, bondingCurveId, sharesForReceiver);

            if (isTripleVault) {
                bytes32 counterTripleId = getCounterIdFromTriple(termId);
                _setVaultTotals(
                    counterTripleId,
                    bondingCurveId,
                    vaults[counterTripleId][bondingCurveId].totalAssets + minShare,
                    vaults[counterTripleId][bondingCurveId].totalShares + minShare
                );
                _mint(generalConfig.admin, counterTripleId, bondingCurveId, minShare);
            }
        } else {
            // If not creation, just update the vault totals and mint shares for the user
            _setVaultTotals(
                termId,
                bondingCurveId,
                vaults[termId][bondingCurveId].totalAssets + assetsDelta,
                vaults[termId][bondingCurveId].totalShares + sharesForReceiver
            );

            _mint(receiver, termId, bondingCurveId, sharesForReceiver);
        }
    }

    /// @notice Internal utility function to validate a deposit
    ///
    /// @param amount The amount of Trust to deposit
    /// @param minSharesToReceive The minimum amount of shares to receive (for slippage checks)
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    function _validateDeposit(uint256 amount, uint256 minSharesToReceive, bytes32 termId, uint256 bondingCurveId)
        internal
        view
    {
        uint256 maxAssets = IBondingCurveRegistry(bondingCurveConfig.registry).getCurveMaxAssets(bondingCurveId);
        if (amount + vaults[termId][bondingCurveId].totalAssets > maxAssets) {
            revert Errors.BondingCurve_ActionExceedsMaxAssets();
        }

        uint256 expectedShares = previewDeposit(amount, termId, bondingCurveId);

        if (expectedShares == 0) {
            revert Errors.MultiVault_DepositOrRedeemZeroShares();
        }

        if (expectedShares < minSharesToReceive) {
            revert Errors.MultiVault_SlippageExceeded();
        }
    }

    /// @notice Redeem shares from a vault for assets using a specified bonding curve
    ///
    /// @param shares The amount of shares to redeem
    /// @param receiver The address to receive the assets
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param minAssetsToReceive The minimum amount of assets to receive in return for the shares being redeemed
    ///
    /// @return assets The amount of assets withdrawn
    function redeem(
        uint256 shares,
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 minAssetsToReceive
    ) external nonReentrant returns (uint256) {
        if (!isApprovedToRedeem(msg.sender, receiver)) {
            revert Errors.MultiVault_RedeemerNotApproved();
        }

        uint256 assets = _redeem(shares, receiver, termId, bondingCurveId, minAssetsToReceive);

        // Transfer assets to receiver
        IERC20(generalConfig.trust).safeTransfer(receiver, assets);

        return assets;
    }

    /// @notice Batch redeem shares from multiple vaults for assets using specified bonding curves
    ///
    /// @param shares The amounts of shares to redeem
    /// @param receiver The address to receive the assets
    /// @param termIds The IDs of the atoms or triples (terms)
    /// @param bondingCurveIds The IDs of the bonding curves to use
    /// @param minAssetsToReceive The minimum amounts of assets to receive in return for the shares being redeemed
    ///
    /// @return assets The amounts of assets withdrawn for each respective vault
    function batchRedeem(
        uint256[] calldata shares,
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata minAssetsToReceive
    ) external nonReentrant returns (uint256[] memory) {
        uint256 length = termIds.length;

        if (length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        if (length != shares.length || length != bondingCurveIds.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        if (!isApprovedToRedeem(msg.sender, receiver)) {
            revert Errors.MultiVault_RedeemerNotApproved();
        }

        uint256 totalAssetsForReceiver = 0;
        uint256[] memory assets = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            uint256 amount = _redeem(shares[i], receiver, termIds[i], bondingCurveIds[i], minAssetsToReceive[i]);
            assets[i] = amount;
            totalAssetsForReceiver += amount;
        }

        // Transfer total redeemed assets to receiver in a single transfer to save gas
        IERC20(generalConfig.trust).safeTransfer(receiver, totalAssetsForReceiver);

        return assets;
    }

    /// @notice Internal utility function to redeem shares from a vault
    ///
    /// @param shares The amount of shares to redeem
    /// @param receiver The address to receive the assets
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param minAssetsToReceive The minimum amount of assets to receive in return for the shares being redeemed
    ///
    /// @return assetsForReceiver The amount of assets withdrawn
    function _redeem(
        uint256 shares,
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 minAssetsToReceive
    ) internal returns (uint256) {
        if (!isTermIdValid(termId)) {
            revert Errors.MultiVault_TermDoesNotExist();
        }

        if (!isBondingCurveIdValid(bondingCurveId)) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        // Process redeem
        uint256 assetsForReceiver =
            _processRedeem(termId, bondingCurveId, msg.sender, receiver, shares, minAssetsToReceive);

        _removeUtilization(msg.sender, int256(assetsForReceiver));

        return assetsForReceiver;
    }

    /// @notice Internal utility function to process a redeem
    ///
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param sender The address to redeem shares from
    /// @param receiver The address to receive the assets
    /// @param shares The amount of shares to redeem
    /// @param minAssetsToReceive The minimum amount of assets to receive in return for the shares being redeemed
    ///
    /// @return assetsForReceiver The amount of assets withdrawn
    function _processRedeem(
        bytes32 termId,
        uint256 bondingCurveId,
        address sender,
        address receiver,
        uint256 shares,
        uint256 minAssetsToReceive
    ) internal returns (uint256) {
        _validateRedeem(termId, bondingCurveId, sender, shares, minAssetsToReceive);

        // rawAssetsBeforeFees = how many assets these shares represent
        uint256 rawAssetsBeforeFees = convertToAssets(shares, termId, bondingCurveId);

        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(rawAssetsBeforeFees, termId, bondingCurveId, false, false, shares);

        _setVaultTotals(
            termId,
            bondingCurveId,
            vaults[termId][bondingCurveId].totalAssets - feesAndSharesBreakdown.assetsDelta, // assetsDelta == assetsForReceiver
            vaults[termId][bondingCurveId].totalShares - shares
        );
        _burn(sender, termId, bondingCurveId, shares);

        _applyFees(termId, bondingCurveId, feesAndSharesBreakdown, isTripleId(termId));

        emit Redeemed(termId, bondingCurveId, msg.sender, receiver, shares, feesAndSharesBreakdown.assetsForReceiver);

        return feesAndSharesBreakdown.assetsForReceiver;
    }

    /// @notice Internal utility function to validate a redeem
    ///
    /// @param termId The ID of the atom or triple (term)
    /// @param bondingCurveId The ID of the bonding curve to use
    /// @param sender The address to redeem shares from
    /// @param shares The amount of shares to redeem
    /// @param minAssetsToReceive The minimum amount of assets to receive in return for the shares being redeemed
    function _validateRedeem(
        bytes32 termId,
        uint256 bondingCurveId,
        address sender,
        uint256 shares,
        uint256 minAssetsToReceive
    ) internal view {
        if (shares == 0) {
            revert Errors.MultiVault_DepositOrRedeemZeroShares();
        }

        uint256 expectedAssets = previewRedeem(shares, termId, bondingCurveId);

        if (expectedAssets < minAssetsToReceive) {
            revert Errors.MultiVault_SlippageExceeded();
        }

        if (maxRedeem(sender, termId, bondingCurveId) < shares) {
            revert Errors.MultiVault_InsufficientSharesInVault();
        }

        uint256 remainingShares = vaults[termId][bondingCurveId].totalShares - shares;
        if (remainingShares < generalConfig.minShare) {
            revert Errors.MultiVault_InsufficientRemainingSharesInVault(remainingShares);
        }
    }

    /* =================================================== */
    /*                 INTERNAL METHODS                    */
    /* =================================================== */

    /// @dev Increase the accumulated protocol fees
    /// @param protocolFees the amount of protocol fees to accumulate
    function _accumulateProtocolFees(uint256 protocolFees) internal {
        if (protocolFees > 0) {
            uint256 epoch = currentEpoch();
            accumulatedProtocolFees[epoch] += protocolFees;
            emit ProtocolFeeAccrued(epoch, protocolFees);
        }
    }

    /// @dev collects the accumulated protocol fees and transfers them to the TrustBonding contract for claiming by the users
    /// @param epoch the epoch to claim the protocol fees for
    function _claimAccumulatedProtocolFees(uint256 epoch) internal {
        uint256 protocolFees = accumulatedProtocolFees[epoch];
        if (protocolFees == 0) return;

        // Check if the protocol fee distribution is enabled using the snapshot instead of the live value to
        // prevent mid-epoch changes to the protocol fee distribution
        bool distributionEnabled = protocolFeeDistributionEnabledAtEpoch[epoch];

        // Set the destination to the TrustBonding contract if distribution is enabled, otherwise set it to the protocol multisig
        address destination;

        if (distributionEnabled) {
            destination = generalConfig.trustBonding;

            // Set the max claimable protocol fees for the previous epoch in the TrustBonding contract to the amount
            // of TRUST tokens being sent to the TrustBonding contract. This is done to be sure that the internal
            // accounting works as intended, instead of relying simply on the `balanceOf` of the contract
            ITrustBonding(generalConfig.trustBonding).setMaxClaimableProtocolFeesForPreviousEpoch(protocolFees);

            // Transfer the protocol fees to the TrustBonding contract
            IERC20(generalConfig.trust).safeTransfer(destination, protocolFees);
        } else {
            destination = generalConfig.protocolMultisig;

            // If the protocol fee distribution is not enabled, we simply transfer the protocol fees to the protocol multisig
            IERC20(generalConfig.trust).safeTransfer(destination, protocolFees);
        }

        emit ProtocolFeeTransferred(epoch, destination, protocolFees);
    }

    /// @dev Divides amount across the three vaults composing the triple and issues shares to the receiver.
    ///      Doesn't charge additional protocol fees, but it does charge entry fees on each deposit into
    ///      an underlying vault.
    /// @dev Assumes funds have already been transferred to this contract
    /// @dev Funds flow directly into the vaults of the default bonding curve of the underlying vaults.
    ///
    /// @param tripleId the ID of the triple
    /// @param receiver the address to receive the shares
    /// @param amount the amount of Trust to deposit
    function _depositAtomFraction(bytes32 tripleId, address receiver, uint256 amount) internal {
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = getTripleAtoms(tripleId);
        uint256 amountPerAtom = amount / 3; // negligible remainder stays in the contract (typically only a few wei, if any)

        _depositIntoUnderlyingAtom(subjectId, receiver, amountPerAtom);
        _depositIntoUnderlyingAtom(predicateId, receiver, amountPerAtom);
        _depositIntoUnderlyingAtom(objectId, receiver, amountPerAtom);

        emit AtomDepositFractionDeposited(tripleId, msg.sender, amount);
    }

    /// @dev deposits `amount` into `termId` treating it as an underlying atom vault of a triple:
    ///     - charge only the entry fee
    ///     – never recurses (i.e. the fees only go one layer deep, even if triple is nested more than once)
    ///     – always bumps up the pro-rata (deafault) bonding curve
    ///
    /// @param termId the ID of the atom
    /// @param receiver the address to receive the shares
    /// @param amount the amount of Trust to deposit
    function _depositIntoUnderlyingAtom(bytes32 termId, address receiver, uint256 amount) internal {
        uint256 defaultBondingCurveId = bondingCurveConfig.defaultCurveId;

        // charges only the entry fee, since it's an underlying atom deposit
        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(amount, termId, defaultBondingCurveId, true, true, 0);

        // accounting is identical to `_processDeposit`, but we pass `false` for `isTripleVault`
        // so no recursive actions related to atomDepositFraction are triggered, regardless of
        // how many layers deep the triple is nested
        _processDeposit(
            receiver,
            termId,
            defaultBondingCurveId,
            feesAndSharesBreakdown.sharesForReceiver,
            // this avoids the need to separately flow the entry fees to their respective vaults
            // on the pro-rata curve. We do this since the underlying atom deposits are always
            // made on the pro-rata curve
            feesAndSharesBreakdown.assetsDelta + feesAndSharesBreakdown.entryFee,
            false,
            false
        );

        emit EntryFeeCollected(termId, defaultBondingCurveId, msg.sender, feesAndSharesBreakdown.entryFee);

        emit Deposited(
            termId,
            defaultBondingCurveId,
            msg.sender,
            receiver,
            amount,
            feesAndSharesBreakdown.assetsDelta,
            feesAndSharesBreakdown.sharesForReceiver
        );
    }

    /// @dev deposit assets into a vault upon creation.
    ///      Changes the vault's total assets, total shares and balanceOf mappings to reflect the deposit.
    ///      Additionally, initializes a counter vault with ghost shares.
    ///
    /// @param termId the vault ID of the atom or triple
    /// @param receiver the address to receive the shares
    /// @param assets the amount of Trust to deposit in the vault (after fees)
    /// @param grossAssets the amount of Trust to deposit before fees
    function _depositOnVaultCreation(bytes32 termId, address receiver, uint256 assets, uint256 grossAssets) internal {
        uint256 defaultBondingCurveId = bondingCurveConfig.defaultCurveId;

        // Apply bonding curve to calculate initial shares for receiver
        uint256 sharesForReceiver = convertToShares(assets, termId, defaultBondingCurveId);

        // Compute total delta (will be the same for both assets and shares since the share price is 1 on creation)
        uint256 totalDelta = sharesForReceiver + generalConfig.minShare;

        // Set vault totals for the vault without storing ghostShares
        _setVaultTotals(
            termId,
            defaultBondingCurveId,
            vaults[termId][defaultBondingCurveId].totalAssets + totalDelta,
            vaults[termId][defaultBondingCurveId].totalShares + totalDelta
        );

        // Mint `sharesForReceiver` shares to sender
        _mint(receiver, termId, defaultBondingCurveId, sharesForReceiver);

        // Mint ghost shares to admin
        _mint(generalConfig.admin, termId, defaultBondingCurveId, generalConfig.minShare);

        // Initialize the counter triple vault if it's a triple creation flow
        if (isTripleId(termId)) {
            _initializeCounterTripleVault(termId);
        }

        emit Deposited(termId, defaultBondingCurveId, msg.sender, receiver, grossAssets, assets, sharesForReceiver);
    }

    /// @dev Initializes the counter triple vault with ghost shares for the admin
    /// @param tripleId the ID of the triple
    function _initializeCounterTripleVault(bytes32 tripleId) internal {
        bytes32 counterTripleId = getCounterIdFromTriple(tripleId);

        uint256 defaultBondingCurveId = bondingCurveConfig.defaultCurveId;

        // Set vault totals directly using generalConfig.minShare
        _setVaultTotals(
            counterTripleId,
            defaultBondingCurveId,
            vaults[counterTripleId][defaultBondingCurveId].totalAssets + generalConfig.minShare,
            vaults[counterTripleId][defaultBondingCurveId].totalShares + generalConfig.minShare
        );

        // Mint ghost shares to admin for the counter vault
        _mint(generalConfig.admin, counterTripleId, defaultBondingCurveId, generalConfig.minShare);
    }

    /// @dev mint vault shares to address `to`
    ///
    /// @param to address to mint shares to
    /// @param termId atom or triple ID to mint shares for (term)
    /// @param bondingCurveId bonding curve ID to mint shares for
    /// @param amount amount of shares to mint
    function _mint(address to, bytes32 termId, uint256 bondingCurveId, uint256 amount) internal {
        vaults[termId][bondingCurveId].balanceOf[to] += amount;
    }

    /// @dev burn `amount` vault shares from address `from`
    ///
    /// @param from address to burn shares from
    /// @param termId atom or triple ID to burn shares from (term)
    /// @param bondingCurveId bonding curve ID to burn shares from
    /// @param amount amount of shares to burn
    function _burn(address from, bytes32 termId, uint256 bondingCurveId, uint256 amount) internal {
        if (from == address(0)) revert Errors.MultiVault_BurnFromZeroAddress();

        uint256 fromBalance = vaults[termId][bondingCurveId].balanceOf[from];
        if (fromBalance < amount) {
            revert Errors.MultiVault_BurnInsufficientBalance();
        }

        unchecked {
            vaults[termId][bondingCurveId].balanceOf[from] = fromBalance - amount;
        }
    }

    /// @dev set total assets and shares for a vault
    ///
    /// @param termId atom or triple ID to set totals for (term)
    /// @param bondingCurveId bonding curve ID to set totals for
    /// @param totalAssets new total assets for the vault
    /// @param totalShares new total shares for the vault
    function _setVaultTotals(bytes32 termId, uint256 bondingCurveId, uint256 totalAssets, uint256 totalShares)
        internal
    {
        vaults[termId][bondingCurveId].totalAssets = totalAssets;
        vaults[termId][bondingCurveId].totalShares = totalShares;

        uint256 price;
        if (totalShares == 0) {
            price = 0; // brand‑new vault
        } else if (totalShares >= ONE_SHARE) {
            // 1 share <= supply
            price = convertToAssets(ONE_SHARE, termId, bondingCurveId);
        } else {
            // supply smaller than 1 share --> we fallback to the curve’s marginal price
            price = IBondingCurveRegistry(bondingCurveConfig.registry).currentPrice(totalShares, bondingCurveId);
        }

        emit VaultTotalsChanged(termId, bondingCurveId, totalAssets, totalShares);
        emit SharePriceChanged(termId, bondingCurveId, price);
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

            // snapshot the protocol fee distribution status for the current epoch to make sure it's not altered
            // mid-epoch (any changes to the protocol fee distribution status will be reflected in the next epoch)
            protocolFeeDistributionEnabledAtEpoch[currentEpochLocal] = generalConfig.protocolFeeDistributionEnabled;

            uint256 previousEpoch = currentEpochLocal - 1;

            // since this is the first action in the new epoch, we should now claim the accumulated protocol fees
            // from the previous epoch and send them to the TrustBonding contract for users to claim. The only
            // exception is the very first epoch, where this is skipped since there are no previous epochs to claim
            // the accumulated protocol fees for
            if (currentEpochLocal > 0) {
                _claimAccumulatedProtocolFees(previousEpoch);
            }
        }

        // if user’s oldEpoch < currentEpochLocal, we do a rollover
        if (personalUtilization[user][currentEpochLocal] == 0) {
            // move leftover from oldEpoch to currentEpoch on the first action in the new epoch
            personalUtilization[user][currentEpochLocal] = personalUtilization[user][oldEpoch];
        }

        // set user’s lastActiveEpoch to the currentEpochLocal
        lastActiveEpoch[user] = currentEpochLocal;
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /* -------------------------- */
    /*         Fee Helpers        */
    /* -------------------------- */

    /// @notice returns the cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() public view returns (uint256) {
        return atomConfig.atomCreationProtocolFee + generalConfig.minShare; // paid to protocol // for purchasing ghost shares
    }

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() public view returns (uint256) {
        return tripleConfig.tripleCreationProtocolFee // paid to protocol
            + tripleConfig.totalAtomDepositsOnTripleCreation // goes towards increasing the amount of assets in the underlying atom vaults
            + generalConfig.minShare * 2; // for purchasing ghost shares for the positive and counter triple vaults
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

    /// @notice returns amount of assets that would be charged by a vault on protocol fee given amount of 'assets'
    ///         provided
    /// @param assets amount of assets to calculate fee on
    /// @return feeAmount amount of assets that would be charged by vault on protocol fee
    function protocolFeeAmount(uint256 assets) public view returns (uint256) {
        return _feeOnRaw(assets, vaultFees.protocolFee);
    }

    /// @notice returns atom deposit fraction given amount of 'assets' provided
    /// @dev only applies to triple vaults
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param termId atom or triple (term) id to get corresponding atom deposit fraction amount for
    ///
    /// @return feeAmount amount of assets that would be used as atom deposit fraction
    function atomDepositFractionAmount(uint256 assets, bytes32 termId) public view returns (uint256) {
        return isTripleId(termId) ? _feeOnRaw(assets, tripleConfig.atomDepositFractionForTriple) : 0;
    }

    /// @notice returns amount of assets that would be charged as the atom wallet fee given amount of 'assets'
    /// @dev only applies to atom vaults
    ///
    /// @param assets amount of assets to calculate fee on
    /// @param termId atom or triple (term) id to get corresponding atom wallet fee amount for
    /// @return feeAmount amount of assets that would be charged as the atom wallet fee
    function atomWalletDepositFeeAmount(uint256 assets, bytes32 termId) public view returns (uint256) {
        return isTripleId(termId) ? 0 : _feeOnRaw(assets, atomConfig.atomWalletDepositFee);
    }

    /// @notice calculates fee on raw amount
    ///
    /// @param amount amount of assets to calculate fee on
    /// @param fee fee in %
    ///
    /// @return amount of assets that would be charged as fee
    function _feeOnRaw(uint256 amount, uint256 fee) internal view returns (uint256) {
        return amount.mulDivUp(fee, generalConfig.feeDenominator);
    }

    /* -------------------------- */
    /*     Accounting Helpers     */
    /* -------------------------- */

    /// @notice returns the current share price for the given vault id
    /// @dev This method is here mostly for ERC4626 compatibility reasons, and is not called internally anywhere
    ///
    /// @param termId atom or triple (term) id to get corresponding share price for
    /// @param bondingCurveId bonding curve ID to get corresponding share price for
    ///
    /// @return price current share price for the given vault id
    function currentSharePrice(bytes32 termId, uint256 bondingCurveId) external view returns (uint256) {
        return convertToAssets(ONE_SHARE, termId, bondingCurveId);
    }

    /// @notice returns max amount of Trust that can be deposited into the vault
    /// @return maxDeposit max amount of Trust that can be deposited into the vault
    function maxDeposit() public pure returns (uint256) {
        return type(uint256).max;
    }

    /// @notice returns max amount of shares that can be redeemed from the 'sender' balance through a redeem call
    ///
    /// @param sender address of the account to get max redeemable shares for
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param bondingCurveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that can be redeemed from the 'sender' balance through a redeem call
    function maxRedeem(address sender, bytes32 termId, uint256 bondingCurveId) public view returns (uint256) {
        return vaults[termId][bondingCurveId].balanceOf[sender];
    }

    /// @notice returns amount of shares that would be exchanged by vault given amount of 'assets' provided
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param bondingCurveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that would be exchanged by vault given amount of 'assets' provided
    function convertToShares(uint256 assets, bytes32 termId, uint256 bondingCurveId) public view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewDeposit(
            assets,
            vaults[termId][bondingCurveId].totalAssets,
            vaults[termId][bondingCurveId].totalShares,
            bondingCurveId
        );
    }

    /// @notice returns amount of assets that would be exchanged by vault given amount of 'shares' provided
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param termId atom or triple (term) id to get corresponding assets for
    /// @param bondingCurveId bonding curve ID to get corresponding assets for
    ///
    /// @return assets amount of assets that would be exchanged by vault given amount of 'shares' provided
    function convertToAssets(uint256 shares, bytes32 termId, uint256 bondingCurveId) public view returns (uint256) {
        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(
            shares,
            vaults[termId][bondingCurveId].totalShares,
            vaults[termId][bondingCurveId].totalAssets,
            bondingCurveId
        );
    }

    /// @notice simulates the effects of the deposited amount of 'assets' and returns the estimated
    ///         amount of shares that would be minted from the deposit of `assets`
    /// @dev  this function pessimistically estimates the amount of shares that would be minted from the
    ///       input amount of assets so if the vault is empty before the deposit the caller receives more
    ///       shares than returned by this function, reference internal `_computeFeesAndShares` logic for
    ///       more details
    ///
    /// @param assets amount of assets to calculate shares on
    /// @param termId atom or triple (term) id to get corresponding shares for
    /// @param bondingCurveId bonding curve ID to get corresponding shares for
    ///
    /// @return shares amount of shares that would be minted from the deposit of `assets`
    function previewDeposit(
        uint256 assets, // should always be the raw deposit amount
        bytes32 termId,
        uint256 bondingCurveId
    ) public view returns (uint256) {
        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(assets, termId, bondingCurveId, true, false, 0);
        return feesAndSharesBreakdown.sharesForReceiver;
    }

    /// @notice simulates the effects of the redemption of `shares` and returns the estimated
    ///         amount of assets estimated to be returned to the receiver of the redemption
    ///
    /// @param shares amount of shares to calculate assets on
    /// @param termId atom or triple (term) id to get corresponding assets for
    /// @param bondingCurveId bonding curve ID to get corresponding assets for
    ///
    /// @return assets amount of assets estimated to be returned to the receiver
    function previewRedeem(uint256 shares, bytes32 termId, uint256 bondingCurveId) public view returns (uint256) {
        uint256 rawAssets = convertToAssets(shares, termId, bondingCurveId);
        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(rawAssets, termId, bondingCurveId, false, false, shares);
        return feesAndSharesBreakdown.assetsForReceiver;
    }

    /* -------------------------- */
    /*        Atom Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the triple vault id
    /// @param data id of the triple
    /// @return id the corresponding id for the atom based on the data
    function getAtomIdFromData(bytes memory data) public pure returns (bytes32 id) {
        return keccak256(abi.encodePacked(data));
    }

    /// @notice returns whether the atom with the given id is instantiated
    /// @param atomId the id of the atom to check
    /// @return bool whether the atom with the given id is instantiated
    function isAtomInstantiated(bytes32 atomId) public view returns (bool) {
        return atomData[atomId].length != 0;
    }

    /* -------------------------- */
    /*       Triple Helpers       */
    /* -------------------------- */

    /// @notice returns the corresponding hash for the given RDF triple, given the atom IDs that make up the triple
    ///
    /// @param subjectId the subject atom's id
    /// @param predicateId the predicate atom's id
    /// @param objectId the object atom's id
    ///
    /// @return hash the corresponding hash for the given RDF triple based on the atom vault ids
    function tripleIdFromAtomIds(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(subjectId, predicateId, objectId));
    }

    /// @notice returns the atoms that make up a triple/counter-triple
    /// @param tripleId term id of the triple/counter-triple
    /// @return tuple(atomIds) the atoms that make up the triple/counter-triple
    function getTripleAtoms(bytes32 tripleId) public view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds =
            isCounterTripleId(tripleId) ? triples[getTripleIdFromCounter(tripleId)] : triples[tripleId];
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @notice returns whether the supplied vault id is a triple
    /// @param termId atom or triple (term) id to check
    /// @return bool whether the supplied term id is a triple
    function isTripleId(bytes32 termId) public view returns (bool) {
        return isCounterTripleId(termId) ? isTriple[getTripleIdFromCounter(termId)] : isTriple[termId];
    }

    /// @notice returns whether the supplied vault id is a counter triple
    /// @param termId atom or triple (term) id to check
    /// @return bool whether the supplied term id is a counter triple
    function isCounterTripleId(bytes32 termId) public view returns (bool) {
        return tripleIdFromCounter[termId] != bytes32(0);
    }

    /// @notice returns the counter id from the given triple id
    /// @param tripleId term id of the triple
    /// @return counterId the counter vault id from the given triple id
    function getCounterIdFromTriple(bytes32 tripleId) public pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(COUNTER_SALT, tripleId)));
    }

    /// @notice returns the triple id from the given counter id
    /// @param counterId term id of the counter triple
    /// @return tripleId the triple vault id from the given counter id
    function getTripleIdFromCounter(bytes32 counterId) public view returns (bytes32) {
        return tripleIdFromCounter[counterId];
    }

    /* -------------------------- */
    /*       ERC1155 Helpers      */
    /* -------------------------- */

    /// @notice Returns the balance of the given account for the given vault id and bonding curve id
    ///
    /// @param account address of the account to get the balance for
    /// @param termId atom or triple (term) id to get the balance for
    /// @param bondingCurveId bonding curve id to get the balance for
    ///
    /// @return uint256 the balance of the given account for the given vault id and bonding curve id
    function balanceOf(address account, bytes32 termId, uint256 bondingCurveId) external view returns (uint256) {
        return vaults[termId][bondingCurveId].balanceOf[account];
    }

    /// @notice Returns the balances of the given accounts for the given vault ids and bonding curve ids
    ///
    /// @param accounts addresses of the accounts to get the balances for
    /// @param termIds atom or triple (term) ids to get the balances for
    /// @param bondingCurveId bonding curve id to get the balances for
    ///
    /// @return balances the balances of the given accounts for the given vault ids and bonding curve ids
    function balanceOfBatch(address[] calldata accounts, bytes32[] calldata termIds, uint256 bondingCurveId)
        external
        view
        returns (uint256[] memory)
    {
        if (!isBondingCurveIdValid(bondingCurveId)) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        if (accounts.length != termIds.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        uint256[] memory balances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            balances[i] = vaults[termIds[i]][bondingCurveId].balanceOf[accounts[i]];
        }

        return balances;
    }

    /* -------------------------- */
    /*        Misc. Helpers       */
    /* -------------------------- */

    /// @notice returns whether the protocol fee distribution among bonders is enabled or not
    function getIsProtocolFeeDistributionEnabled() external view returns (bool) {
        return generalConfig.protocolFeeDistributionEnabled;
    }

    /// @notice returns the address of the atom warden
    function getAtomWarden() external view returns (address) {
        return walletConfig.atomWarden;
    }

    /// @notice returns the number of shares and assets (less fees) user has in the vault
    ///
    /// @param termId atom or triple (term) id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param receiver address of the receiver
    ///
    /// @return shares number of shares user has in the vault
    /// @return assets number of assets user has in the vault
    function getVaultStateForUser(bytes32 termId, uint256 bondingCurveId, address receiver)
        external
        view
        returns (uint256, uint256)
    {
        uint256 shares = vaults[termId][bondingCurveId].balanceOf[receiver];
        uint256 rawAssets = convertToAssets(shares, termId, bondingCurveId);
        FeesAndSharesBreakdown memory feesAndSharesBreakdown =
            _computeFeesAndShares(rawAssets, termId, bondingCurveId, false, false, shares);
        return (shares, feesAndSharesBreakdown.assetsForReceiver);
    }

    /// @notice returns the vault totals for the given atom and bonding curve id
    /// @param termId id of the atom or triple (term)
    /// @param bondingCurveId id of the bonding curve
    /// @return totalShares total shares in the vault
    /// @return totalAssets total assets in the vault
    function getVaultTotals(bytes32 termId, uint256 bondingCurveId) public view returns (uint256, uint256) {
        VaultState storage vaultState = vaults[termId][bondingCurveId];
        return (vaultState.totalShares, vaultState.totalAssets);
    }

    /// @dev returns the current epoch
    /// @return uint256 the current epoch
    function currentEpoch() public view returns (uint256) {
        return ITrustBonding(generalConfig.trustBonding).currentEpoch();
    }

    /// @dev returns the total utilization of the TRUST token for the given epoch
    /// @param epoch the epoch to get the total utilization for
    /// @return int256 the total utilization of the TRUST token for the given epoch
    function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256) {
        return totalUtilization[epoch];
    }

    /// @notice computes the address of the atom wallet for the given atom id
    function computeAtomWalletAddr(bytes32 atomId) public view returns (address) {
        return IAtomWalletFactory(walletConfig.atomWalletFactory).computeAtomWalletAddr(atomId);
    }

    /// @notice Check if a sender is approved to deposit on behalf of a receiver
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @return bool Whether the sender is approved to deposit
    function isApprovedToDeposit(address sender, address receiver) public view returns (bool) {
        return sender == receiver || (approvals[receiver][sender] & uint8(ApprovalTypes.DEPOSIT)) != 0;
    }

    /// @notice Check if a sender is approved to redeem on behalf of a receiver
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @return bool Whether the sender is approved to redeem
    function isApprovedToRedeem(address sender, address receiver) public view returns (bool) {
        return sender == receiver || (approvals[receiver][sender] & uint8(ApprovalTypes.REDEMPTION)) != 0;
    }

    /// @dev returns the personal utilization of the user for the given epoch
    /// @param user the address of the user
    /// @param epoch the epoch to get the personal utilization for
    /// @return int256 the personal utilization of the user for the given epoch
    function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256) {
        return personalUtilization[user][epoch];
    }

    /// @dev checks if the atom or triple id is valid
    /// @param id the id of the atom or triple to check
    /// @return bool whether the atom or triple id is valid
    function isTermIdValid(bytes32 id) public view returns (bool) {
        return atomData[id].length > 0 || isTripleId(id);
    }

    /// @dev checks if the bonding curve id is valid
    /// @param bondingCurveId the id of the bonding curve to check
    /// @return bool whether the bonding curve id is valid
    function isBondingCurveIdValid(uint256 bondingCurveId) public view returns (bool) {
        if (bondingCurveId == 0 || bondingCurveId > IBondingCurveRegistry(bondingCurveConfig.registry).count()) {
            return false;
        }
        return true;
    }

    /// @dev checks if an account holds shares in the triple counter to the id provided.
    ///      We only check for the counter stake in the default bonding curve id (i.e.
    ///      the pro rata curve), since the purpose of alternative bonding curves is not
    ///      primarily to provide a signal, but to be used for the economic games.
    ///
    /// @param tripleId the id of the triple to check
    /// @param bondingCurveId the id of the bonding curve to check
    /// @param receiver the account to check
    ///
    /// @return bool whether the account holds shares in the counter vault to the id provided or not
    function _hasCounterStake(bytes32 tripleId, uint256 bondingCurveId, address receiver)
        internal
        view
        returns (bool)
    {
        if (!isTripleId(tripleId)) {
            revert Errors.MultiVault_TermNotTriple();
        }

        bytes32 counterTripleId = getCounterIdFromTriple(tripleId);

        if (vaults[counterTripleId][bondingCurveId].balanceOf[receiver] > 0) {
            return true;
        }

        return false;
    }

    /// @dev returns the sum of the values in the array
    /// @param values the array of values to sum
    /// @return uint256 the sum of the values in the array
    function _getSum(uint256[] calldata values) internal pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }
        return sum;
    }

    /// @notice computes the fees and shares/assets for a given deposit/redeem action
    /// @dev fee computation is single-sourced in this function to help with easier auditing and testing
    ///
    /// @param rawAssets the amount of assets to deposit/redeem
    /// @param termId atom or triple (term) id to get corresponding fees for
    /// @param bondingCurveId bonding curve id to get corresponding fees for
    /// @param isDeposit true if the action is a deposit, false if it is a redeem
    /// @param isUnderlyingAtomDeposit true if the action is a deposit into an underlying atom vault, false otherwise
    /// @param sharesToRedeem the amount of shares to redeem, only used for redeems, 0 for deposits
    ///
    /// @return feesAndSharesBreakdown the fees, shares and assets data for the action
    function _computeFeesAndShares(
        uint256 rawAssets,
        bytes32 termId,
        uint256 bondingCurveId,
        bool isDeposit,
        bool isUnderlyingAtomDeposit,
        uint256 sharesToRedeem
    ) internal view returns (FeesAndSharesBreakdown memory feesAndSharesBreakdown) {
        uint256 protocolFee = protocolFeeAmount(rawAssets);
        uint256 atomWalletDepositFee = atomWalletDepositFeeAmount(rawAssets, termId); // 0 for triple vaults
        uint256 atomDepositFraction = atomDepositFractionAmount(rawAssets, termId); // 0 for atom vaults

        if (isDeposit) {
            // no entry fees are charged if the vault is empty (i.e. total shares are equal to the min share or less)
            uint256 entryFee =
                vaults[termId][bondingCurveId].totalShares > generalConfig.minShare ? entryFeeAmount(rawAssets) : 0;
            uint256 netAssets = rawAssets - protocolFee - entryFee - atomWalletDepositFee - atomDepositFraction;
            uint256 sharesForReceiver = convertToShares(netAssets, termId, bondingCurveId);

            feesAndSharesBreakdown = FeesAndSharesBreakdown({
                sharesForReceiver: sharesForReceiver,
                assetsForReceiver: 0, // always 0 for deposits
                assetsDelta: netAssets,
                entryFee: entryFee,
                exitFee: 0, // always 0 for deposits
                protocolFee: protocolFee,
                atomWalletDepositFee: atomWalletDepositFee,
                atomDepositFraction: atomDepositFraction
            });

            if (isUnderlyingAtomDeposit) {
                // only entry fees are charged for deposits into underlying atom vaults
                netAssets = rawAssets - entryFee;
                sharesForReceiver = convertToShares(netAssets, termId, bondingCurveId);

                feesAndSharesBreakdown = FeesAndSharesBreakdown({
                    sharesForReceiver: sharesForReceiver,
                    assetsForReceiver: 0, // always 0 for deposits
                    assetsDelta: netAssets,
                    entryFee: entryFee,
                    exitFee: 0, // always 0 for deposits
                    protocolFee: 0,
                    atomWalletDepositFee: 0,
                    atomDepositFraction: 0
                });
            }
        } else {
            if (paused) {
                feesAndSharesBreakdown = FeesAndSharesBreakdown({
                    sharesForReceiver: 0, // always 0 for redeems
                    assetsForReceiver: rawAssets,
                    assetsDelta: rawAssets,
                    // no fees of any kind are charged if the protocol is paused
                    entryFee: 0,
                    exitFee: 0,
                    protocolFee: 0,
                    atomWalletDepositFee: 0,
                    atomDepositFraction: 0
                });
            } else {
                // no exit fees are charged if the remaining shares after redeeming would be less than or equal to the min share
                uint256 exitFee = (vaults[termId][bondingCurveId].totalShares - sharesToRedeem) > generalConfig.minShare
                    ? exitFeeAmount(rawAssets)
                    : 0;
                uint256 assetsForReceiver = rawAssets - protocolFee - exitFee; // equals the net assets

                feesAndSharesBreakdown = FeesAndSharesBreakdown({
                    sharesForReceiver: 0, // always 0 for redeems
                    assetsForReceiver: assetsForReceiver,
                    assetsDelta: assetsForReceiver,
                    entryFee: 0, // always 0 for redeems
                    exitFee: exitFee,
                    protocolFee: protocolFee,
                    atomWalletDepositFee: 0, // always 0 for all redeem actions
                    atomDepositFraction: 0 // always 0 for all redeem actions
                });
            }
        }
    }

    /// @notice all fee-related side effects are single-sourced in this function
    ///
    /// @param termId atom or triple (term) id to apply fees for
    /// @param bondingCurveId bonding curve id to apply fees for
    /// @param feesAndSharesBreakdown the fees and shares data for the action
    /// @param isTripleVault true if the vault is a triple vault, false if it is an atom vault
    function _applyFees(
        bytes32 termId,
        uint256 bondingCurveId,
        FeesAndSharesBreakdown memory feesAndSharesBreakdown,
        bool isTripleVault
    ) internal {
        // accumulate protocol fees in an internal ledger
        if (feesAndSharesBreakdown.protocolFee != 0) {
            _accumulateProtocolFees(feesAndSharesBreakdown.protocolFee);
        }

        // accumulate atom wallet deposit fees in an internal ledger for the respective atom wallet
        if (feesAndSharesBreakdown.atomWalletDepositFee != 0) {
            address atomWalletAddress = computeAtomWalletAddr(termId);
            accumulatedAtomWalletDepositFees[atomWalletAddress] += feesAndSharesBreakdown.atomWalletDepositFee;
            emit AtomWalletDepositFeeCollected(termId, msg.sender, feesAndSharesBreakdown.atomWalletDepositFee);
        }

        // entry and exit fee flow-through to the pro-rata vaults
        uint256 proRataFee = feesAndSharesBreakdown.entryFee + feesAndSharesBreakdown.exitFee; // zero for the opposite fee (i.e. entry fee on redeem or exit fee on deposit)
        if (proRataFee != 0) {
            if (isTripleVault) {
                _bumpUnderlyingProRataVaults(termId, proRataFee);
            } else {
                _bumpProRataVault(termId, proRataFee);
            }
        }

        // emit event for entry fees if they are not zero
        if (feesAndSharesBreakdown.entryFee != 0) {
            emit EntryFeeCollected(termId, bondingCurveId, msg.sender, feesAndSharesBreakdown.entryFee);
        }

        // emit event for exit fees if they are not zero
        if (feesAndSharesBreakdown.exitFee != 0) {
            emit ExitFeeCollected(termId, bondingCurveId, msg.sender, feesAndSharesBreakdown.exitFee);
        }

        // apply the atom deposit fraction to the underlying atom vaults
        if (feesAndSharesBreakdown.atomDepositFraction != 0) {
            _depositAtomFraction(termId, msg.sender, feesAndSharesBreakdown.atomDepositFraction);
        }
    }

    /// @dev bumps the total assets for the pro rata vault
    ///
    /// @param termId atom or triple (term) id to bump totals for
    /// @param amount amount to bump the total assets for
    function _bumpProRataVault(bytes32 termId, uint256 amount) internal {
        uint256 curveId = bondingCurveConfig.defaultCurveId;
        vaults[termId][curveId].totalAssets += amount;

        emit VaultTotalsChanged(
            termId, curveId, vaults[termId][curveId].totalAssets, vaults[termId][curveId].totalShares
        );
        emit SharePriceChanged(termId, curveId, convertToAssets(ONE_SHARE, termId, curveId));
    }

    /// @dev bumps the total assets for the pro rata vaults of the underlying vaults of a triple vault
    ///
    /// @param tripleId id of the triple vault to bump totals for
    /// @param amount total amount to bump the total assets for (gets distributed equally to the three underlying vaults)
    function _bumpUnderlyingProRataVaults(bytes32 tripleId, uint256 amount) internal {
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = getTripleAtoms(tripleId);
        uint256 amountPerAtom = amount / 3; // negligible dust amount stays in the contract (i.e. only one or a few wei)

        _bumpProRataVault(subjectId, amountPerAtom);
        _bumpProRataVault(predicateId, amountPerAtom);
        _bumpProRataVault(objectId, amountPerAtom);
    }
}
