// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";

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

    /**
     * @notice Deploys a new WrappedERC20 contract for a specific term and bonding curve
     * @param termId The ID of the term (atom or triple) to create a wrapper for
     * @param bondingCurveId The bonding curve ID to create a wrapper for
     * @param name The name for the WrappedERC20 token
     * @param symbol The symbol for the WrappedERC20 token
     * @return The address of the newly deployed WrappedERC20 contract
     */
    function deployWrapper(
        bytes32 termId,
        uint256 bondingCurveId,
        string calldata name,
        string calldata symbol
    )
        external
        returns (address);

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Returns the MultiVault contract address
     * @return The MultiVault contract instance
     */
    function multiVault() external view returns (IMultiVault);

    /**
     * @notice Computes the deterministic address of a WrappedERC20 contract
     * @param termId The ID of the term (atom or triple)
     * @param bondingCurveId The bonding curve ID
     * @param name The name for the WrappedERC20 token
     * @param symbol The symbol for the WrappedERC20 token
     * @return The computed address where the WrappedERC20 would be deployed
     */
    function computeWrappedERC20Address(
        bytes32 termId,
        uint256 bondingCurveId,
        string calldata name,
        string calldata symbol
    )
        external
        view
        returns (address);
}
