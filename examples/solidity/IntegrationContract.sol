// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title IntegrationContract
 * @notice Production example of integrating Intuition Protocol into a smart contract
 * @dev Demonstrates best practices for:
 *      - Creating atoms and triples from contracts
 *      - Managing vault deposits and redemptions
 *      - Handling approvals and errors
 *      - Event emission and tracking
 *
 * @author 0xIntuition
 *
 * Usage:
 *   1. Deploy this contract
 *   2. Approve WTRUST spending to this contract
 *   3. Call createAtomAndDeposit() or other functions
 *
 * Example:
 *   IntegrationContract integration = new IntegrationContract(multiVaultAddress, wtrustAddress);
 *   IERC20(wtrustAddress).approve(address(integration), 100 ether);
 *   bytes32 atomId = integration.createAtomAndDeposit("My Data", 10 ether);
 */

import "src/interfaces/IMultiVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IntegrationContract is Ownable {
    /* =================================================== */
    /*                    STATE VARIABLES                  */
    /* =================================================== */

    /// @notice The MultiVault contract interface
    IMultiVault public immutable multiVault;

    /// @notice The WTRUST token interface
    IERC20 public immutable wtrust;

    /// @notice Default curve ID to use (1 = LinearCurve)
    uint256 public constant DEFAULT_CURVE_ID = 1;

    /// @notice Mapping to track atoms created by this contract
    mapping(bytes32 atomId => bool created) public atomsCreated;

    /// @notice Mapping to track triples created by this contract
    mapping(bytes32 tripleId => bool created) public triplesCreated;

    /// @notice Mapping to track user shares in vaults
    mapping(address user => mapping(bytes32 termId => uint256 shares)) public userShares;

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when this contract creates an atom
    event AtomCreatedByContract(bytes32 indexed atomId, bytes atomData, uint256 shares);

    /// @notice Emitted when this contract creates a triple
    event TripleCreatedByContract(
        bytes32 indexed tripleId,
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId,
        uint256 shares
    );

    /// @notice Emitted when a user deposits through this contract
    event UserDeposited(address indexed user, bytes32 indexed termId, uint256 assets, uint256 shares);

    /// @notice Emitted when a user redeems through this contract
    event UserRedeemed(address indexed user, bytes32 indexed termId, uint256 shares, uint256 assets);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error InsufficientShares();
    error AtomAlreadyExists();
    error TripleAlreadyExists();
    error AtomDoesNotExist();
    error InsufficientAllowance();
    error TransferFailed();

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /**
     * @notice Initializes the integration contract
     * @param _multiVault Address of the MultiVault contract
     * @param _wtrust Address of the WTRUST token
     */
    constructor(address _multiVault, address _wtrust) Ownable(msg.sender) {
        multiVault = IMultiVault(_multiVault);
        wtrust = IERC20(_wtrust);

        // Pre-approve MultiVault for maximum efficiency
        // This avoids needing approval for each operation
        wtrust.approve(_multiVault, type(uint256).max);
    }

    /* =================================================== */
    /*                  ATOM OPERATIONS                    */
    /* =================================================== */

    /**
     * @notice Creates a new atom vault and deposits initial assets
     * @dev Pulls WTRUST from msg.sender, requires prior approval
     *
     * @param atomData The metadata for the atom (any bytes data)
     * @param initialDeposit Amount of WTRUST to deposit initially
     *
     * @return atomId The ID of the created atom
     *
     * @custom:example
     *   bytes32 atomId = integration.createAtomAndDeposit("User Profile", 10 ether);
     */
    function createAtomAndDeposit(
        bytes calldata atomData,
        uint256 initialDeposit
    )
        external
        returns (bytes32 atomId)
    {
        // Calculate atom ID
        atomId = multiVault.calculateAtomId(atomData);

        // Check if atom already exists
        if (multiVault.isTermCreated(atomId)) {
            revert AtomAlreadyExists();
        }

        // Calculate total amount needed (deposit + atom creation cost)
        uint256 atomCost = multiVault.getAtomCost();
        uint256 totalAmount = initialDeposit + atomCost;

        // Pull WTRUST from sender
        if (!wtrust.transferFrom(msg.sender, address(this), totalAmount)) {
            revert TransferFailed();
        }

        // Create atom (contract already has infinite approval)
        bytes[] memory atomDatas = new bytes[](1);
        atomDatas[0] = atomData;

        uint256[] memory assets = new uint256[](1);
        assets[0] = initialDeposit;

        bytes32[] memory atomIds = multiVault.createAtoms(atomDatas, assets);

        // Track atom creation
        atomsCreated[atomIds[0]] = true;

        // Get shares received
        uint256 shares = multiVault.getShares(address(this), atomId, DEFAULT_CURVE_ID);

        emit AtomCreatedByContract(atomId, atomData, shares);

        return atomIds[0];
    }

    /* =================================================== */
    /*                 TRIPLE OPERATIONS                   */
    /* =================================================== */

    /**
     * @notice Creates a new triple vault (Subject-Predicate-Object)
     * @dev All three atoms must already exist
     *
     * @param subjectId The ID of the subject atom
     * @param predicateId The ID of the predicate atom
     * @param objectId The ID of the object atom
     * @param initialDeposit Amount of WTRUST to deposit initially
     *
     * @return tripleId The ID of the created triple
     *
     * @custom:example
     *   bytes32 tripleId = integration.createTripleAndDeposit(
     *       aliceId, likesId, bobId, 20 ether
     *   );
     */
    function createTripleAndDeposit(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId,
        uint256 initialDeposit
    )
        external
        returns (bytes32 tripleId)
    {
        // Verify all atoms exist
        if (!multiVault.isTermCreated(subjectId)) revert AtomDoesNotExist();
        if (!multiVault.isTermCreated(predicateId)) revert AtomDoesNotExist();
        if (!multiVault.isTermCreated(objectId)) revert AtomDoesNotExist();

        // Calculate triple ID
        tripleId = multiVault.calculateTripleId(subjectId, predicateId, objectId);

        // Check if triple already exists
        if (multiVault.isTermCreated(tripleId)) {
            revert TripleAlreadyExists();
        }

        // Calculate total amount needed
        uint256 tripleCost = multiVault.getTripleCost();
        uint256 totalAmount = initialDeposit + tripleCost;

        // Pull WTRUST from sender
        if (!wtrust.transferFrom(msg.sender, address(this), totalAmount)) {
            revert TransferFailed();
        }

        // Create triple
        bytes32[] memory subjectIds = new bytes32[](1);
        subjectIds[0] = subjectId;

        bytes32[] memory predicateIds = new bytes32[](1);
        predicateIds[0] = predicateId;

        bytes32[] memory objectIds = new bytes32[](1);
        objectIds[0] = objectId;

        uint256[] memory assets = new uint256[](1);
        assets[0] = initialDeposit;

        bytes32[] memory tripleIds = multiVault.createTriples(subjectIds, predicateIds, objectIds, assets);

        // Track triple creation
        triplesCreated[tripleIds[0]] = true;

        // Get shares received
        uint256 shares = multiVault.getShares(address(this), tripleId, DEFAULT_CURVE_ID);

        emit TripleCreatedByContract(tripleId, subjectId, predicateId, objectId, shares);

        return tripleIds[0];
    }

    /* =================================================== */
    /*                  VAULT OPERATIONS                   */
    /* =================================================== */

    /**
     * @notice Deposits assets into a vault on behalf of a user
     * @dev Tracks user shares internally for later redemption
     *
     * @param termId The ID of the atom or triple vault
     * @param amount Amount of WTRUST to deposit
     *
     * @return shares Number of shares minted
     *
     * @custom:example
     *   uint256 shares = integration.depositForUser(atomId, 5 ether);
     */
    function depositForUser(bytes32 termId, uint256 amount) external returns (uint256 shares) {
        // Verify vault exists
        if (!multiVault.isTermCreated(termId)) {
            revert AtomDoesNotExist();
        }

        // Pull WTRUST from sender
        if (!wtrust.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        // Preview deposit to calculate min shares (with 1% slippage tolerance)
        (uint256 expectedShares,) = multiVault.previewDeposit(termId, DEFAULT_CURVE_ID, amount);
        uint256 minShares = (expectedShares * 99) / 100;

        // Deposit into vault
        shares = multiVault.deposit(address(this), termId, DEFAULT_CURVE_ID, minShares);

        // Track user shares
        userShares[msg.sender][termId] += shares;

        emit UserDeposited(msg.sender, termId, amount, shares);

        return shares;
    }

    /**
     * @notice Redeems shares from a vault for a user
     * @dev User must have shares tracked by this contract
     *
     * @param termId The ID of the atom or triple vault
     * @param shares Number of shares to redeem
     *
     * @return assets Amount of WTRUST received
     *
     * @custom:example
     *   uint256 assets = integration.redeemForUser(atomId, 5 ether);
     */
    function redeemForUser(bytes32 termId, uint256 shares) external returns (uint256 assets) {
        // Check user has sufficient shares
        if (userShares[msg.sender][termId] < shares) {
            revert InsufficientShares();
        }

        // Preview redemption to calculate min assets (with 1% slippage tolerance)
        (uint256 expectedAssets,) = multiVault.previewRedeem(termId, DEFAULT_CURVE_ID, shares);
        uint256 minAssets = (expectedAssets * 99) / 100;

        // Redeem from vault
        assets = multiVault.redeem(address(this), termId, DEFAULT_CURVE_ID, shares, minAssets);

        // Update user shares
        userShares[msg.sender][termId] -= shares;

        // Transfer WTRUST to user
        if (!wtrust.transfer(msg.sender, assets)) {
            revert TransferFailed();
        }

        emit UserRedeemed(msg.sender, termId, shares, assets);

        return assets;
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Get the value of a user's position in a vault
     * @param user Address of the user
     * @param termId The ID of the vault
     * @return assets Current value in WTRUST
     */
    function getUserPositionValue(address user, bytes32 termId) external view returns (uint256 assets) {
        uint256 shares = userShares[user][termId];
        return multiVault.convertToAssets(termId, DEFAULT_CURVE_ID, shares);
    }

    /**
     * @notice Check if an atom was created by this contract
     * @param atomId The atom ID to check
     * @return True if created by this contract
     */
    function isAtomCreatedByContract(bytes32 atomId) external view returns (bool) {
        return atomsCreated[atomId];
    }

    /**
     * @notice Check if a triple was created by this contract
     * @param tripleId The triple ID to check
     * @return True if created by this contract
     */
    function isTripleCreatedByContract(bytes32 tripleId) external view returns (bool) {
        return triplesCreated[tripleId];
    }

    /* =================================================== */
    /*                  ADMIN FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Emergency function to recover stuck tokens
     * @dev Only owner can call this
     * @param token Address of the token to recover
     * @param amount Amount to recover
     */
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
