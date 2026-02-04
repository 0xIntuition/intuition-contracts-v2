// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface ICLFactory {
    function tickSpacings() external view returns (int24[] memory);
    function tickSpacingToFee(int24 tickSpacing) external view returns (uint24);
    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address);
}
