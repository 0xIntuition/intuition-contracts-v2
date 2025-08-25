// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Trust } from "src/Trust.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract TrustAccessControlTest is BaseTest {
    Trust public trust;
    address public admin;
    address public minter;
    address public user;

    uint256 constant ANNUAL_REDUCTION_BASIS_POINTS = 500; // 5%
    uint256 constant START_TIMESTAMP = 2_000_000_000; // Future timestamp

    function setUp() public override {
        BaseTest.setUp();

        admin = users.admin;
        minter = users.admin;
        user = users.alice;
    }

    function test_AccessControl_Roles_Setup() public view {
        // Check that roles were set up correctly
        assertTrue(
            protocol.trust.hasRole(protocol.trust.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE"
        );
        assertTrue(protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), minter), "Minter should have CONTROLLER_ROLE");
    }

    function test_AccessControl_OnlyAdmin_WithRoleFallback() public {
        address newAdmin = makeAddr("newAdmin");

        // Grant DEFAULT_ADMIN_ROLE to newAdmin
        resetPrank(admin);
        protocol.trust.grantRole(protocol.trust.DEFAULT_ADMIN_ROLE(), newAdmin);

        // Verify role was granted
        assertTrue(
            protocol.trust.hasRole(protocol.trust.DEFAULT_ADMIN_ROLE(), newAdmin),
            "newAdmin should have DEFAULT_ADMIN_ROLE"
        );

        // newAdmin should be able to use admin functions via role
        resetPrank(newAdmin);
        protocol.trust.grantRole(protocol.trust.CONTROLLER_ROLE(), user);

        assertTrue(
            protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), user), "newAdmin should be able to set minter via role"
        );
    }

    /*//////////////////////////////////////////////////////////////
                               MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint_Success() public {
        uint256 mintAmount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        uint256 initialBalance = protocol.trust.balanceOf(recipient);
        uint256 initialSupply = protocol.trust.totalSupply();

        // Minter should be able to mint
        resetPrank(minter);
        protocol.trust.mint(recipient, mintAmount);

        assertEq(protocol.trust.balanceOf(recipient), initialBalance + mintAmount, "Recipient balance should increase");
        assertEq(protocol.trust.totalSupply(), initialSupply + mintAmount, "Total supply should increase");
    }

    function test_Mint_OnlyMinter() public {
        uint256 mintAmount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        // Non-minter should not be able to mint
        resetPrank(user);
        vm.expectRevert();
        protocol.trust.mint(recipient, mintAmount);
    }

    function test_Mint_ZeroAmount() public {
        address recipient = makeAddr("recipient");

        uint256 initialBalance = protocol.trust.balanceOf(recipient);
        uint256 initialSupply = protocol.trust.totalSupply();

        // Minting zero amount should work (ERC20 allows it)
        resetPrank(minter);
        protocol.trust.mint(recipient, 0);

        assertEq(protocol.trust.balanceOf(recipient), initialBalance, "Balance should remain unchanged");
        assertEq(protocol.trust.totalSupply(), initialSupply, "Total supply should remain unchanged");
    }

    function test_Mint_ToZeroAddress() public {
        uint256 mintAmount = 1000 * 1e18;

        // Minting to zero address should revert (ERC20 restriction)
        resetPrank(minter);
        vm.expectRevert();
        protocol.trust.mint(address(0), mintAmount);
    }

    function test_Mint_LargeAmount() public {
        uint256 mintAmount = 1e30; // Very large amount
        address recipient = makeAddr("recipient");

        uint256 initialBalance = protocol.trust.balanceOf(recipient);
        uint256 initialSupply = protocol.trust.totalSupply();

        // Should be able to mint large amounts
        resetPrank(minter);
        protocol.trust.mint(recipient, mintAmount);

        assertEq(protocol.trust.balanceOf(recipient), initialBalance + mintAmount, "Recipient balance should increase");
        assertEq(protocol.trust.totalSupply(), initialSupply + mintAmount, "Total supply should increase");
    }

    function test_Mint_MultipleMinters() public {
        address newMinter = makeAddr("newMinter");
        uint256 mintAmount = 500 * 1e18;
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");

        // Grant CONTROLLER_ROLE to newMinter
        resetPrank(admin);
        protocol.trust.grantRole(protocol.trust.CONTROLLER_ROLE(), newMinter);

        uint256 initialSupply = protocol.trust.totalSupply();

        // Both minters should be able to mint
        resetPrank(minter);
        protocol.trust.mint(recipient1, mintAmount);

        resetPrank(newMinter);
        protocol.trust.mint(recipient2, mintAmount);

        assertEq(protocol.trust.balanceOf(recipient1), mintAmount, "First recipient should receive tokens");
        assertEq(protocol.trust.balanceOf(recipient2), mintAmount, "Second recipient should receive tokens");
        assertEq(
            protocol.trust.totalSupply(), initialSupply + (2 * mintAmount), "Total supply should increase by both mints"
        );
    }

    function test_Mint_RevokeRole() public {
        uint256 mintAmount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        // First mint should succeed
        resetPrank(minter);
        protocol.trust.mint(recipient, mintAmount);

        // Revoke CONTROLLER_ROLE
        resetPrank(admin);
        protocol.trust.revokeRole(protocol.trust.CONTROLLER_ROLE(), minter);

        // Second mint should fail
        resetPrank(minter);
        vm.expectRevert();
        protocol.trust.mint(recipient, mintAmount);

        assertFalse(
            protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), minter), "Minter should no longer have CONTROLLER_ROLE"
        );
    }

    function test_Mint_AdminCanGrantMinterRole() public {
        address newMinter = makeAddr("newMinter");
        uint256 mintAmount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        // Admin grants CONTROLLER_ROLE to new address
        resetPrank(admin);
        protocol.trust.grantRole(protocol.trust.CONTROLLER_ROLE(), newMinter);

        assertTrue(
            protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), newMinter), "New address should have CONTROLLER_ROLE"
        );

        // New minter should be able to mint
        resetPrank(newMinter);
        protocol.trust.mint(recipient, mintAmount);

        assertEq(protocol.trust.balanceOf(recipient), mintAmount, "Recipient should receive tokens");
    }

    function test_Mint_NonAdminCannotGrantMinterRole() public {
        address newMinter = makeAddr("newMinter");

        // Non-admin cannot grant CONTROLLER_ROLE
        resetPrank(user);

        // Expect revert when non-admin tries to grant role
        bytes32 minterRole = protocol.trust.CONTROLLER_ROLE();

        vm.expectRevert();
        protocol.trust.grantRole(minterRole, newMinter);

        assertFalse(protocol.trust.hasRole(minterRole, newMinter), "New address should not have CONTROLLER_ROLE");
    }

    function test_Mint_EventEmission() public {
        uint256 mintAmount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        // Expect Transfer event from minting
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), recipient, mintAmount);

        resetPrank(minter);
        protocol.trust.mint(recipient, mintAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_AccessControl_RenounceRole() public {
        // Minter can renounce their own role
        resetPrank(minter);
        protocol.trust.renounceRole(protocol.trust.CONTROLLER_ROLE(), minter);

        assertFalse(
            protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), minter), "Minter should no longer have CONTROLLER_ROLE"
        );

        // Should not be able to mint after renouncing
        resetPrank(minter);
        vm.expectRevert();
        protocol.trust.mint(makeAddr("recipient"), 1000 * 1e18);
    }

    function test_AccessControl_AdminRenounceRole() public {
        // Admin can renounce admin role, but this would be dangerous in practice
        resetPrank(admin);
        protocol.trust.renounceRole(protocol.trust.DEFAULT_ADMIN_ROLE(), admin);

        assertFalse(
            protocol.trust.hasRole(protocol.trust.DEFAULT_ADMIN_ROLE(), admin),
            "Admin should no longer have DEFAULT_ADMIN_ROLE"
        );

        bytes32 adminRole = protocol.trust.DEFAULT_ADMIN_ROLE();

        // Should not be able to grant roles after renouncing admin
        resetPrank(admin);
        vm.expectRevert();
        protocol.trust.grantRole(adminRole, makeAddr("newMinter"));
    }

    function test_AccessControl_MultipleAdmins() public {
        address secondAdmin = makeAddr("secondAdmin");
        address newMinter = makeAddr("newMinter");

        // First admin grants admin role to second address
        resetPrank(admin);
        protocol.trust.grantRole(protocol.trust.DEFAULT_ADMIN_ROLE(), secondAdmin);

        assertTrue(
            protocol.trust.hasRole(protocol.trust.DEFAULT_ADMIN_ROLE(), secondAdmin),
            "Second address should have admin role"
        );

        // Second admin should be able to grant minter role
        resetPrank(secondAdmin);
        protocol.trust.grantRole(protocol.trust.CONTROLLER_ROLE(), newMinter);

        assertTrue(
            protocol.trust.hasRole(protocol.trust.CONTROLLER_ROLE(), newMinter), "New minter should have CONTROLLER_ROLE"
        );

        // New minter should be able to mint
        resetPrank(newMinter);
        protocol.trust.mint(makeAddr("recipient"), 1000 * 1e18);
    }
}