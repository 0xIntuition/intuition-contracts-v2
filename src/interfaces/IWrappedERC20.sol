// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";

/**
 * @title IWrappedERC20
 * @author 0xIntuition
 * @notice The interface for the WrappedERC20 contract
 */
interface IWrappedERC20 {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when MultiVault shares are wrapped into an WrappedERC20 token
    ///
    /// @param from The address wrapping the shares
    /// @param to The address receiving the WrappedERC20 tokens
    /// @param termId The term ID of the MultiVault shares being wrapped
    /// @param curveId The bonding curve ID of the MultiVault shares being wrapped
    /// @param shares The amount of shares being wrapped
    event Wrapped(address indexed from, address indexed to, bytes32 termId, uint256 curveId, uint256 shares);

    /// @notice Emitted when WrappedERC20 tokens are unwrapped back into MultiVault shares
    ///
    /// @param from The address unwrapping the WrappedERC20 tokens
    /// @param to The address receiving the MultiVault shares
    /// @param termId The term ID of the MultiVault shares being unwrapped
    /// @param curveId The bonding curve ID of the MultiVault shares being unwrapped
    /// @param shares The amount of WrappedERC20 tokens being unwrapped
    event Unwrapped(address indexed from, address indexed to, bytes32 termId, uint256 curveId, uint256 shares);

    /* =================================================== */
    /*                   WRITE FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice Wraps MultiVault shares into WrappedERC20 tokens
     * @param shares The amount of shares to wrap
     */
    function wrap(uint256 shares) external;

    /**
     * @notice Unwraps WrappedERC20 tokens back into MultiVault shares
     * @param shares The amount of WrappedERC20 tokens to unwrap
     */
    function unwrap(uint256 shares) external;

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Returns the MultiVault contract address
     * @return The MultiVault contract instance
     */
    function multiVault() external view returns (IMultiVault);

    /**
     * @notice Returns the term ID associated with this wrapped token
     * @return The term ID (atom or triple ID)
     */
    function termId() external view returns (bytes32);

    /**
     * @notice Returns the bonding curve ID associated with this wrapped token
     * @return The bonding curve ID
     */
    function bondingCurveId() external view returns (uint256);
}
