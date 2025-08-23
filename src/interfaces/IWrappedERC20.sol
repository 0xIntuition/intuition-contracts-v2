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

    function wrap(uint256 shares) external;

    function unwrap(uint256 shares) external;

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function multiVault() external view returns (IMultiVault);

    function termId() external view returns (bytes32);

    function bondingCurveId() external view returns (uint256);
}
