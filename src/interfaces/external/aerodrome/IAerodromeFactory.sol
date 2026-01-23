// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title  IAerodromeFactory
 * @notice Interface for Aerodrome V2 Pool Factory
 * @dev    Used to query pool addresses for token pairs
 */
interface IAerodromeFactory {
    /**
     * @notice Returns the pool address for a given token pair and stability
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param stable Whether to check for stable or volatile pool
     * @return pool Pool address (address(0) if pool doesn't exist)
     */
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address pool);
}
