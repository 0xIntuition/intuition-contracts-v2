// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title  TestTrust
 * @author 0xIntuition
 * @notice A mintable ERC20 for testing purposes.
 */
contract TestTrust is ERC20, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address admin) ERC20("Intuition Testnet", "tTRUST") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, admin);
        _mint(admin, 100e18); // Mint initial supply to admin
    }

    /**
     * @notice Mint new tokens to an address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from an address
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _burn(msg.sender, amount);
    }
}
