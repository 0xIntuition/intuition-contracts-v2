// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ITrust
 * @author 0xIntuition
 * @notice The minimal interface for the Trust token contract.
 */
interface ITrust is IERC20 {
    /**
     * @notice Mints the Trust token to the specified address
     * @param to The address to mint the Trust token to
     * @param amount The amount of Trust token to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burns the Trust token from the specified address
     * @param from The address to burn the Trust token from
     * @param amount The amount of Trust token to burn
     */
    function burn(address from, uint256 amount) external;
}
