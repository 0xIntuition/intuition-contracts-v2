// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IWETH
 * @notice Minimal interface for WETH (Wrapped ETH) functionality
 */
interface IWETH is IERC20 {
    /**
     * @notice Deposit ETH to receive WETH
     */
    function deposit() external payable;

    /**
     * @notice Withdraw WETH to receive ETH
     * @param amount Amount of WETH to withdraw
     */
    function withdraw(uint256 amount) external;
}
