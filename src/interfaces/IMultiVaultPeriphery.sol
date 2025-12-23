// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IMultiVaultPeriphery
 * @author 0xIntuition
 * @notice Interface for the MultiVaultPeriphery contract
 */
interface IMultiVaultPeriphery {
    /* =================================================== */
    /*                    EVENTS                           */
    /* =================================================== */

    /**
     * @notice Emitted when the MultiVault address is set
     * @param multiVault The address of the new MultiVault contract
     */
    event MultiVaultSet(address indexed multiVault);

    /**
     * @notice Emitted when the periphery contract creates an atom on behalf of a user
     * @param payer msg.sender that funded this call (could be a relayer)
     * @param creator logical/attributed creator (off-chain identity you care about)
     * @param termId id of the atom in MultiVault
     * @param atomData raw atom data
     */
    event AtomCreatedBy(address indexed payer, address indexed creator, bytes32 indexed termId, bytes atomData);

    /**
     * @notice Emitted when the periphery contract creates a triple on behalf of a user
     * @param payer msg.sender that funded this call (could be a relayer)
     * @param creator logical/attributed creator
     * @param termId id of the triple in MultiVault
     * @param subjectId subject atom id
     * @param predicateId predicate atom id
     * @param objectId  object atom id
     */
    event TripleCreatedBy(
        address indexed payer,
        address indexed creator,
        bytes32 indexed termId,
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    );

    /**
     * @notice Emitted when a counter triple vault is bootstrapped (if needed) and a user deposit is made into it
     * @param caller The address that initiated the periphery call
     * @param receiver The final receiver of the counter triple shares
     * @param tripleId The positive triple ID (termId)
     * @param counterTripleId The corresponding counter triple ID
     * @param curveId The non-default bonding curve ID used
     * @param userAssets The amount of assets forwarded for the user deposit into the counter triple
     * @param userShares The amount of shares minted for the receiver in the counter triple vault
     */
    event CounterTripleVaultBootstrappedAndDeposited(
        address indexed caller,
        address indexed receiver,
        bytes32 indexed tripleId,
        bytes32 counterTripleId,
        uint256 curveId,
        uint256 userAssets,
        uint256 userShares
    );

    /* =================================================== */
    /*                    ERRORS                           */
    /* =================================================== */

    /// @notice Thrown when an invalid address is provided
    error MultiVaultPeriphery_InvalidAddress();

    /// @notice Thrown when the msg.value provided is not enough to cover expected costs
    error MultiVaultPeriphery_InsufficientMsgValue(uint256 expected, uint256 provided);

    /// @notice Thrown when a zero-length array is provided where at least one element is required
    error MultiVaultPeriphery_ZeroLengthArray();

    /// @notice Thrown when the lengths of dependent arrays do not match
    error MultiVaultPeriphery_ArrayLengthMismatch();

    /// @notice Thrown when a refund of excess value fails
    error MultiVaultPeriphery_RefundFailed();

    /// @notice Thrown when only triple terms are allowed
    error MultiVaultPeriphery_OnlyTriplesAllowed();

    /// @notice Thrown when the default curve ID is supplied where not allowed
    error MultiVaultPeriphery_DefaultCurveIdNotAllowed();

    /// @notice Thrown when user assets provided are invalid (e.g. zero assets)
    error MultiVaultPeriphery_InvalidUserAssets();

    /// @notice Thrown when attempting to initialize a vault that is already initialized
    error MultiVaultPeriphery_VaultAlreadyInitialized(bytes32 tripleId, uint256 curveId);

    /* =================================================== */
    /*                    FUNCTIONS                        */
    /* =================================================== */

    /**
     * @notice Initializer for MultiVaultPeriphery
     * @param _admin Admin address for AccessControl
     * @param _multiVault MultiVault contract address
     */
    function initialize(address _admin, address _multiVault) external;

    /**
     * @notice Sets the MultiVault contract address
     * @param _multiVault New MultiVault contract address
     */
    function setMultiVault(address _multiVault) external;

    /**
     * @notice Creates multiple atoms on behalf of a user
     * @dev Each atom gets created with exactly `atomCost` in assets to avoid minting extra shares to this contract.
     *      Excess msg.value is refunded to the sender to avoid any TRUST sitting in this contract.
     * @param atomData Array of raw atom data
     * @param creator Logical/attributed creator address
     * @return atomIds Array of created atom ids
     */
    function createAtomsFor(
        bytes[] calldata atomData,
        address creator
    )
        external
        payable
        returns (bytes32[] memory atomIds);

    /**
     * @notice Creates multiple triples on behalf of a user
     * @dev Each atom gets created with exactly `tripleCost` in assets to avoid minting extra shares to this contract.
     *      Excess msg.value is refunded to the sender to avoid any TRUST sitting in this contract.
     * @param subjects Array of subject atom ids
     * @param predicates Array of predicate atom ids
     * @param objects Array of object atom ids
     * @param creator Logical/attributed creator address
     * @return tripleIds Array of created triple ids
     */
    function createTriplesFor(
        bytes32[] calldata subjects,
        bytes32[] calldata predicates,
        bytes32[] calldata objects,
        address creator
    )
        external
        payable
        returns (bytes32[] memory tripleIds);
}
