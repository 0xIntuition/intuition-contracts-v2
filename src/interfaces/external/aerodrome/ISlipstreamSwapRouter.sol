// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title ISlipstreamSwapRouter
/// @notice Interface for the Aerodrome Slipstream (CL) SwapRouter's exactInput function
interface ISlipstreamSwapRouter {
    /// @notice Parameters for multi-hop exact input swaps
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as ExactInputParams
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}
