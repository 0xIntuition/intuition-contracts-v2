// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface IMultiVaultPeriphery {
    /* =================================================== */
    /*                    EVENTS                           */
    /* =================================================== */

    /**
     * @notice Emitted when the periphery contract creates an atom on behalf of a user
     * @param payer msg.sender that funded this call (could be a relayer)
     * @param creator logical/attributed creator (off-chain identity you care about)
     * @param termId id of the atom in MultiVault
     * @param atomData raw atom data
     */
    event AtomCreatedFor(address indexed payer, address indexed creator, bytes32 indexed termId, bytes atomData);

    /**
     * @notice Emitted when the periphery contract creates a triple on behalf of a user
     * @param payer msg.sender that funded this call (could be a relayer)
     * @param creator logical/attributed creator
     * @param termId id of the triple in MultiVault
     * @param subjectId subject atom id
     * @param predicateId predicate atom id
     * @param objectId  object atom id
     */
    event TripleCreatedFor(
        address indexed payer,
        address indexed creator,
        bytes32 indexed termId,
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    );

    /**
     * @notice Emitted when the MultiVault address is set
     * @param multiVault The address of the new MultiVault contract
     */
    event MultiVaultSet(address indexed multiVault);

    /* =================================================== */
    /*                    ERRORS                           */
    /* =================================================== */

    /// @notice Thrown when an invalid address is provided
    error MultiVaultPeriphery_InvalidAddress();

    /// @notice Thrown when the creator address is invalid
    error MultiVaultPeriphery_InvalidCreator();

    /// @notice Thrown when the msg.value provided is not enough to cover expected costs
    error MultiVaultPeriphery_InsufficientMsgValue(uint256 expected, uint256 provided);

    /// @notice Thrown when the lengths of dependent arrays do not match
    error MultiVaultPeriphery_InvalidArrayLength();

    /// @notice Thrown when either the predicate or object is invalid
    error MultiVaultPeriphery_InvalidPredicateOrObject();

    /// @notice Thrown when a refund of excess value fails
    error MultiVaultPeriphery_RefundFailed();

    /* =================================================== */
    /*                    FUNCTIONS                        */
    /* =================================================== */
}
