// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title ICLQuoter
/// @notice Interface for Aerodrome CL Quoter contract for accurate swap quotes
interface ICLQuoter {
    /// @notice Returns the amount out received for a given exact input single-hop swap
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param tickSpacing The tick spacing of the pool
    /// @param amountIn The amount of tokenIn to be swapped
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of tokenOut that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks crossed by the swap
    /// @return gasEstimate The estimate of the gas that the swap consumes
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        int24 tickSpacing,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    )
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

    /// @notice Returns the amount out received for a given exact input multi-hop swap
    /// @param path The encoded path of the swap (tokenIn, tickSpacing, tokenOut, ...)
    /// @param amountIn The amount of the first token to swap
    /// @return amountOut The amount of the last token that would be received
    /// @return sqrtPriceX96AfterList List of the sqrt price after the swap for each pool in the path
    /// @return initializedTicksCrossedList List of initialized ticks crossed for each pool in the path
    /// @return gasEstimate The estimate of the gas that the swap consumes
    function quoteExactInput(
        bytes memory path,
        uint256 amountIn
    )
        external
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );
}
