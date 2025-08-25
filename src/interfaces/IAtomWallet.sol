// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title IAtomWallet
 * @author 0xIntuition
 * @notice The minimal interface for the AtomWallet contract - ERC-4337 compatible smart account
 * @dev AtomWallets are smart contract accounts associated with atoms in the protocol
 */
interface IAtomWallet {
    /**
     * @notice Initiates the ownership transfer over the wallet to a new owner
     * @dev Uses the two-step ownership transfer pattern for security
     * @param newOwner The new owner of the wallet (becomes the pending owner)
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Returns the current owner of the AtomWallet
     * @return owner The address of the current owner
     */
    function owner() external view returns (address);
}
