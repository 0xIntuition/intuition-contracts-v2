// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IAtomWarden
 * @author 0xIntuition
 * @notice Interface for the AtomWarden contract
 */
interface IAtomWarden {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Event emitted when the MultiVault contract address is set
     * @param multiVault MultiVault contract address
     */
    event MultiVaultSet(address multiVault);

    /**
     * @notice Event emitted when ownership transfer over an atom wallet has been claimed
     * @param atomId The atom ID
     * @param pendingOwner The address of the pending owner
     */
    event AtomWalletOwnershipClaimed(bytes32 atomId, address pendingOwner);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error AtomWarden_InvalidAddress();
    error AtomWarden_AtomIdDoesNotExist();
    error AtomWarden_ClaimOwnershipFailed();
    error AtomWarden_AtomWalletNotDeployed();
    error AtomWarden_InvalidNewOwnerAddress();

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    /**
     * @notice Allows the caller to claim ownership over an atom wallet address in case
     *         atomUri is equal to the caller's address
     * @param atomId The atom ID
     */
    function claimOwnershipOverAddressAtom(bytes32 atomId) external;

    /**
     * @notice Allows the owner to assign ownership of an atom wallet to a new owner in
     *         cases where the automated ownership recovery is not possible yet
     * @param atomId The atom ID
     * @param newOwner The new owner address
     */
    function claimOwnership(bytes32 atomId, address newOwner) external;

    /**
     * @notice Sets the MultiVault contract address
     * @param _multiVault MultiVault contract address
     */
    function setMultiVault(address _multiVault) external;
}
