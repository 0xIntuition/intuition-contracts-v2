// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IMultiVault} from "src/interfaces/IMultiVault.sol";

/**
 * @title IWrappedERC20Factory
 * @author 0xIntuition
 * @notice The interface for the WrappedERC20Factory contract
 */
interface IWrappedERC20Factory {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when the WrappedERC20 token contract is deployed
    ///
    /// @param termId The term ID for which this wrapper is created
    /// @param bondingCurveId The bonding curve ID for which this wrapper is created
    /// @param wrappedERC20 The address of the deployed WrappedERC20 contract
    event WrappedERC20Deployed(bytes32 indexed termId, uint256 indexed bondingCurveId, address wrappedERC20);

    /* =================================================== */
    /*                   WRITE FUNCTIONS                   */
    /* =================================================== */

    function deployWrapper(bytes32 termId, uint256 bondingCurveId, string calldata name, string calldata symbol)
        external
        returns (address);

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function multiVault() external view returns (IMultiVault);

    function computeWrappedERC20Address(
        bytes32 termId,
        uint256 bondingCurveId,
        string calldata name,
        string calldata symbol
    ) external view returns (address);
}
