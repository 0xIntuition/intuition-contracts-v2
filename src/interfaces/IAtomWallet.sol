// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title IAtomWallet
 * @author 0xIntuition
 * @notice The minimal interface for the AtomWallet contract
 */
interface IAtomWallet {
    /// @notice Initiates the ownership transfer over the wallet to a new owner
    /// @param newOwner the new owner of the wallet (becomes the pending owner)
    /// NOTE: Overrides the transferOwnership function of Ownable2StepUpgradeable
    function transferOwnership(address newOwner) external;
}
