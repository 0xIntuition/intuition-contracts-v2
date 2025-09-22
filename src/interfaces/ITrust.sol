// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title ITrust
 * @author 0xIntuition
 * @notice The minimal interface for the Trust token contract.
 */
interface ITrust {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when the BaseEmissionsController address is set
    /// @param newBaseEmissionsController The new BaseEmissionsController address
    event BaseEmissionsControllerSet(address indexed newBaseEmissionsController);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @notice Custom error for when a zero address is provided
    error Trust_ZeroAddress();

    /// @notice Custom error for when the caller is not the BaseEmissionsController
    error Trust_OnlyBaseEmissionsController();

    /* =================================================== */
    /*                     FUNCTIONS                       */
    /* =================================================== */

    /**
     * @notice Sets the BaseEmissionsController contract address
     * @param newBaseEmissionsController The new BaseEmissionsController address
     */
    function setBaseEmissionsController(address newBaseEmissionsController) external;

    /**
     * @notice Mint new TRUST tokens to an address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burn TRUST tokens from the caller's address
     * @dev Caller must have enough balance to burn and can only burn their own tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external;
}
