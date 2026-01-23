// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title  IAerodromePool
 * @notice Interface for Aerodrome V2 Liquidity Pool
 * @dev    Used to query pool reserves and verify liquidity
 */
interface IAerodromePool {
    /**
     * @notice Returns the reserves of the pool
     * @return reserve0 Reserve of token0
     * @return reserve1 Reserve of token1
     * @return blockTimestampLast Last block timestamp when reserves were updated
     */
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);

    /**
     * @notice Returns the address of token0
     * @return Address of the first token in the pair
     */
    function token0() external view returns (address);

    /**
     * @notice Returns the address of token1
     * @return Address of the second token in the pair
     */
    function token1() external view returns (address);

    /**
     * @notice Returns whether the pool uses stable curve
     * @return True if pool is stable, false if volatile
     */
    function stable() external view returns (bool);
}
