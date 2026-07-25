// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IAtomWallet
 * @author 0xIntuition
 * @notice The minimal interface for the AtomWallet contract - ERC-4337 compatible smart account
 * @dev AtomWallets are smart contract accounts associated with atoms in the protocol
 */
interface IAtomWallet {
    /**
     * @notice Transfers ownership of a claimed wallet directly to a new owner
     * @param newOwner The new owner of the wallet
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Completes a Warden-driven wallet claim in a single step
     * @param newOwner The new owner of the wallet
     */
    function completeClaim(address newOwner) external;

    /**
     * @notice Returns the current owner of the AtomWallet
     * @return owner The address of the current owner
     */
    function owner() external view returns (address);

    /**
     * @notice Returns whether the wallet has been claimed away from AtomWarden
     * @return claimed True when the wallet is claimed
     */
    function isClaimed() external view returns (bool claimed);

    /**
     * @notice Adds an address as an authorized signer (post-claim only)
     * @param signer The address to add
     */
    function addOwnerAddress(address signer) external;

    /**
     * @notice Adds a passkey public key as an authorized signer (post-claim only)
     * @param x The x coordinate of the P-256 public key
     * @param y The y coordinate of the P-256 public key
     */
    function addOwnerPublicKey(bytes32 x, bytes32 y) external;

    /**
     * @notice Removes a signer at the given index (post-claim only, cannot remove protocol owner)
     * @param index The index of the owner to remove
     * @param ownr The expected owner bytes at that index
     */
    function removeOwnerAtIndex(uint256 index, bytes calldata ownr) external;

    /**
     * @notice Returns whether the given address is a registered MultiOwnable owner
     * @param account The address to check
     * @return True if the address is a registered owner
     */
    function isOwnerAddress(address account) external view returns (bool);

    /**
     * @notice Returns whether the given P-256 public key is a registered MultiOwnable owner
     * @param x The x coordinate
     * @param y The y coordinate
     * @return True if the public key is a registered owner
     */
    function isOwnerPublicKey(bytes32 x, bytes32 y) external view returns (bool);

    /**
     * @notice Returns the owner bytes at the given MultiOwnable index
     * @param index The index to query
     * @return The owner bytes at that index
     */
    function ownerAtIndex(uint256 index) external view returns (bytes memory);

    /**
     * @notice Returns the current MultiOwnable owner count
     * @return The number of registered owners
     */
    function ownerCount() external view returns (uint256);

    /**
     * @notice Returns the next MultiOwnable owner index
     * @return The next available index
     */
    function nextOwnerIndex() external view returns (uint256);
}
