// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IAerodromeRouter {
    /// @notice Struct representing a trade route between two tokens
    struct Route {
        /// @dev Address of the input token
        address from;
        /// @dev Address of the output token
        address to;
        /// @dev Whether the pool is stable or volatile
        bool stable;
        /// @dev Address of the pool factory
        address factory;
    }

    /// @notice Perform chained getAmountOut calculations on any number of pools
    /// @param amountIn Amount of token in
    /// @param routes Array of trade routes used in the calculation
    /// @return amounts Array of amounts returned per route
    function getAmountsOut(uint256 amountIn, Route[] calldata routes) external view returns (uint256[] memory amounts);

    /// @notice Swap one token for another
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    )
        external
        returns (uint256[] memory amounts);
}
