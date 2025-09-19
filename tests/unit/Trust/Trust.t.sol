// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Trust } from "src/Trust.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract TrustTest is BaseTest {
    /* =================================================== */
    /*                        ROLE                         */
    /* =================================================== */

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    address public admin;
    address public user;

    // Event mirror (ERC20)
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        vm.stopPrank();

        admin = users.admin;
        user = users.alice;
    }

    /* =================================================== */
    /*                      HELPERS                        */
    /* =================================================== */

    function _missingRoleRevert(address account, bytes32 role) internal pure returns (bytes memory) {
        // OZ v4 AccessControl revert: "AccessControl: account 0x.. is missing role 0x.."
        string memory reason = string.concat(
            "AccessControl: account ",
            Strings.toHexString(uint160(account), 20),
            " is missing role ",
            Strings.toHexString(uint256(role), 32)
        );
        return abi.encodeWithSignature("Error(string)", reason);
    }

    /* =================================================== */
    /*                 ROLE / ACCESS CONTROL               */
    /* =================================================== */

    function test_AccessControl_Roles_Setup() public view {
        assertTrue(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, admin), "Admin should have DEFAULT_ADMIN_ROLE");
    }

    function test_AccessControl_OnlyAdmin_WithRoleFallback() public {
        address newAdmin = makeAddr("newAdmin");

        resetPrank(admin);
        protocol.trust.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertTrue(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), "newAdmin should have DEFAULT_ADMIN_ROLE");
    }

    /* =================================================== */
    /*                     MINT TESTS                      */
    /* =================================================== */

    function test_Mint_Success() public {
        uint256 amount = 1000e18;
        address recipient = makeAddr("recipient");

        uint256 bal0 = protocol.trust.balanceOf(recipient);
        uint256 sup0 = protocol.trust.totalSupply();

        resetPrank(users.controller);
        protocol.trust.mint(recipient, amount);

        assertEq(protocol.trust.balanceOf(recipient), bal0 + amount);
        assertEq(protocol.trust.totalSupply(), sup0 + amount);
    }

    function test_Mint_OnlyController() public {
        uint256 amount = 1000e18;
        address recipient = makeAddr("recipient");

        resetPrank(user);
        vm.expectRevert(Trust.Trust_OnlyBaseEmissionsController.selector);
        protocol.trust.mint(recipient, amount);
    }

    function test_Mint_ZeroAmount() public {
        address recipient = makeAddr("recipient");

        uint256 bal0 = protocol.trust.balanceOf(recipient);
        uint256 sup0 = protocol.trust.totalSupply();

        resetPrank(users.controller);
        protocol.trust.mint(recipient, 0);

        assertEq(protocol.trust.balanceOf(recipient), bal0);
        assertEq(protocol.trust.totalSupply(), sup0);
    }

    function test_Mint_ToZeroAddress_Revert() public {
        resetPrank(users.controller);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ERC20: mint to the zero address"));
        protocol.trust.mint(address(0), 1e18);
    }

    function test_Mint_LargeAmount() public {
        uint256 amount = 1e30;
        address recipient = makeAddr("recipient");

        uint256 bal0 = protocol.trust.balanceOf(recipient);
        uint256 sup0 = protocol.trust.totalSupply();

        resetPrank(users.controller);
        protocol.trust.mint(recipient, amount);

        assertEq(protocol.trust.balanceOf(recipient), bal0 + amount);
        assertEq(protocol.trust.totalSupply(), sup0 + amount);
    }

    function test_Mint_EmitsTransferEvent() public {
        uint256 amount = 1000e18;
        address recipient = makeAddr("recipient");

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), recipient, amount);

        resetPrank(users.controller);
        protocol.trust.mint(recipient, amount);
    }

    /* =================================================== */
    /*                      BURN TESTS                     */
    /* =================================================== */

    function test_Burn_Success_ByHolder() public {
        uint256 amount = 500e18;

        resetPrank(users.controller);
        protocol.trust.mint(user, amount);

        resetPrank(user);

        uint256 bal0 = protocol.trust.balanceOf(user);
        uint256 sup0 = protocol.trust.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(user, address(0), 200e18);

        protocol.trust.burn(200e18);

        assertEq(protocol.trust.balanceOf(user), bal0 - 200e18);
        assertEq(protocol.trust.totalSupply(), sup0 - 200e18);
    }

    function test_Burn_Revert_InsufficientBalance() public {
        resetPrank(users.controller);
        protocol.trust.mint(user, 1e18);

        uint256 userBalance = protocol.trust.balanceOf(user);

        resetPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ERC20: burn amount exceeds balance"));
        protocol.trust.burn(userBalance + 1);
    }

    /* =================================================== */
    /*                   METADATA OVERRIDES                */
    /* =================================================== */

    function test_Metadata_NameOverrideAndSymbol() public view {
        assertEq(protocol.trust.name(), "Intuition");
        assertEq(protocol.trust.symbol(), "TRUST");
    }

    /* =================================================== */
    /*                   REINITIALIZER TESTS               */
    /* =================================================== */

    function test_Reinitialize_Success_ByInitialAdmin() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        address initialAdmin = fresh.INITIAL_ADMIN();
        address newAdmin = makeAddr("newAdmin");
        address controller = makeAddr("controller");

        vm.prank(initialAdmin);
        fresh.reinitialize(newAdmin, controller);

        assertTrue(fresh.hasRole(DEFAULT_ADMIN_ROLE, newAdmin));

        vm.startPrank(controller);
        fresh.mint(user, 1e18);
        vm.stopPrank();

        assertEq(fresh.balanceOf(user), 1e18);
    }

    function test_Reinitialize_Revert_OnlyInitialAdmin() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        address notInitial = makeAddr("notInitial");

        vm.prank(notInitial);
        vm.expectRevert(Trust.Trust_OnlyInitialAdmin.selector);
        fresh.reinitialize(makeAddr("admin"), makeAddr("controller"));
    }

    function test_Reinitialize_Revert_ZeroAddresses() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        address initialAdmin = fresh.INITIAL_ADMIN();

        vm.prank(initialAdmin);
        vm.expectRevert(Trust.Trust_ZeroAddress.selector);
        fresh.reinitialize(address(0), makeAddr("controller"));

        vm.prank(initialAdmin);
        vm.expectRevert(Trust.Trust_ZeroAddress.selector);
        fresh.reinitialize(makeAddr("admin"), address(0));
    }

    function test_Reinitialize_Revert_SecondCall() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        address initialAdmin = fresh.INITIAL_ADMIN();

        vm.prank(initialAdmin);
        fresh.reinitialize(makeAddr("admin"), makeAddr("controller"));

        vm.prank(initialAdmin);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Initializable: contract is already initialized"));
        fresh.reinitialize(makeAddr("admin2"), makeAddr("controller2"));
    }

    /* =================================================== */
    /*                        HELPERS                      */
    /* =================================================== */

    function _deployTrustProxy() internal returns (Trust) {
        Trust impl = new Trust();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(this), "");
        return Trust(address(proxy));
    }
}
