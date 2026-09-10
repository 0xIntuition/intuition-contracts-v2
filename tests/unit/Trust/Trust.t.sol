// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ITrust } from "src/interfaces/ITrust.sol";
import { Trust } from "src/Trust.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

/// @dev Exposes Trust's internal ERC20 primitives so their own zero-address guards can be tested
///      directly: `transfer`/`approve`/`burn` always call these with `_msgSender()`, which can
///      never be `address(0)` for a real transaction, so the guards are unreachable via the public
///      API and only reachable through a subclass calling the `internal` functions directly.
contract TrustHarness is Trust {
    function transferForTest(address from, address to, uint256 amount) external {
        _transfer(from, to, amount);
    }

    function burnForTest(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function approveForTest(address owner_, address spender, uint256 amount) external {
        _approve(owner_, spender, amount);
    }
}

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

    function test_AccessControl_GetRoleAdmin_DefaultsToDefaultAdminRole() public view {
        // DEFAULT_ADMIN_ROLE is its own admin (OZ default), and freshly-declared roles admin to it too.
        assertEq(protocol.trust.getRoleAdmin(DEFAULT_ADMIN_ROLE), DEFAULT_ADMIN_ROLE);
        assertEq(protocol.trust.getRoleAdmin(keccak256("SOME_UNUSED_ROLE")), DEFAULT_ADMIN_ROLE);
    }

    function test_AccessControl_RevokeRole_Success() public {
        address grantee = makeAddr("grantee");

        resetPrank(admin);
        protocol.trust.grantRole(DEFAULT_ADMIN_ROLE, grantee);
        assertTrue(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, grantee));

        protocol.trust.revokeRole(DEFAULT_ADMIN_ROLE, grantee);
        assertFalse(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, grantee));
    }

    function test_AccessControl_RevokeRole_Revert_NotAdmin() public {
        resetPrank(user);
        vm.expectRevert(_missingRoleRevert(user, DEFAULT_ADMIN_ROLE));
        protocol.trust.revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_AccessControl_RevokeRole_NoOpWhenNotHeld() public {
        address neverGranted = makeAddr("neverGranted");
        assertFalse(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, neverGranted));

        // Revoking a role the account never had is a silent no-op (matches _revokeRole's own hasRole guard).
        resetPrank(admin);
        protocol.trust.revokeRole(DEFAULT_ADMIN_ROLE, neverGranted);
        assertFalse(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, neverGranted));
    }

    function test_AccessControl_RenounceRole_Success() public {
        address grantee = makeAddr("grantee");

        resetPrank(admin);
        protocol.trust.grantRole(DEFAULT_ADMIN_ROLE, grantee);

        resetPrank(grantee);
        protocol.trust.renounceRole(DEFAULT_ADMIN_ROLE, grantee);

        assertFalse(protocol.trust.hasRole(DEFAULT_ADMIN_ROLE, grantee));
    }

    function test_AccessControl_RenounceRole_Revert_NotSelf() public {
        resetPrank(user);
        vm.expectRevert(bytes("AccessControl: can only renounce roles for self"));
        protocol.trust.renounceRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_AccessControl_SupportsInterface() public view {
        // type(IAccessControlUpgradeable).interfaceId
        assertTrue(protocol.trust.supportsInterface(0x7965db0b));
        // type(IERC165Upgradeable).interfaceId, reached via the AccessControl override's `super` call
        assertTrue(protocol.trust.supportsInterface(0x01ffc9a7));
        assertFalse(protocol.trust.supportsInterface(0xdeadbeef));
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
        vm.expectRevert(ITrust.Trust_OnlyBaseEmissionsController.selector);
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
    /*                    ERC20 TRANSFER                    */
    /* =================================================== */

    function test_Transfer_Success() public {
        address recipient = makeAddr("recipient");
        resetPrank(users.controller);
        protocol.trust.mint(user, 1000e18);

        uint256 userBalBefore = protocol.trust.balanceOf(user);

        resetPrank(user);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user, recipient, 400e18);
        protocol.trust.transfer(recipient, 400e18);

        assertEq(protocol.trust.balanceOf(user), userBalBefore - 400e18);
        assertEq(protocol.trust.balanceOf(recipient), 400e18);
    }

    function test_Transfer_Revert_ToZeroAddress() public {
        resetPrank(users.controller);
        protocol.trust.mint(user, 1e18);

        resetPrank(user);
        vm.expectRevert(bytes("ERC20: transfer to the zero address"));
        protocol.trust.transfer(address(0), 1e18);
    }

    function test_Transfer_Revert_InsufficientBalance() public {
        uint256 userBalance = protocol.trust.balanceOf(user);

        resetPrank(user);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        protocol.trust.transfer(makeAddr("recipient"), userBalance + 1);
    }

    /* =================================================== */
    /*                ERC20 APPROVE / ALLOWANCE             */
    /* =================================================== */

    function test_Approve_And_Allowance_Success() public {
        address spender = makeAddr("spender");

        resetPrank(user);
        protocol.trust.approve(spender, 500e18);

        assertEq(protocol.trust.allowance(user, spender), 500e18);
    }

    function test_Approve_Revert_ToZeroAddress() public {
        resetPrank(user);
        vm.expectRevert(bytes("ERC20: approve to the zero address"));
        protocol.trust.approve(address(0), 1e18);
    }

    function test_IncreaseAllowance_Success() public {
        address spender = makeAddr("spender");

        resetPrank(user);
        protocol.trust.approve(spender, 100e18);
        protocol.trust.increaseAllowance(spender, 50e18);

        assertEq(protocol.trust.allowance(user, spender), 150e18);
    }

    function test_DecreaseAllowance_Success() public {
        address spender = makeAddr("spender");

        resetPrank(user);
        protocol.trust.approve(spender, 100e18);
        protocol.trust.decreaseAllowance(spender, 40e18);

        assertEq(protocol.trust.allowance(user, spender), 60e18);
    }

    function test_DecreaseAllowance_Revert_BelowZero() public {
        address spender = makeAddr("spender");

        resetPrank(user);
        protocol.trust.approve(spender, 10e18);

        vm.expectRevert(bytes("ERC20: decreased allowance below zero"));
        protocol.trust.decreaseAllowance(spender, 11e18);
    }

    /* =================================================== */
    /*                    ERC20 TRANSFERFROM                */
    /* =================================================== */

    function test_TransferFrom_Success() public {
        address spender = makeAddr("spender");
        address recipient = makeAddr("recipient");

        resetPrank(users.controller);
        protocol.trust.mint(user, 1000e18);

        resetPrank(user);
        protocol.trust.approve(spender, 300e18);

        resetPrank(spender);
        protocol.trust.transferFrom(user, recipient, 300e18);

        assertEq(protocol.trust.balanceOf(recipient), 300e18);
        assertEq(protocol.trust.allowance(user, spender), 0);
    }

    function test_TransferFrom_Revert_InsufficientAllowance() public {
        address spender = makeAddr("spender");
        address recipient = makeAddr("recipient");

        resetPrank(users.controller);
        protocol.trust.mint(user, 1000e18);

        resetPrank(user);
        protocol.trust.approve(spender, 100e18);

        resetPrank(spender);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        protocol.trust.transferFrom(user, recipient, 101e18);
    }

    function test_TransferFrom_MaxAllowance_DoesNotDecrement() public {
        address spender = makeAddr("spender");
        address recipient = makeAddr("recipient");

        resetPrank(users.controller);
        protocol.trust.mint(user, 1000e18);

        resetPrank(user);
        protocol.trust.approve(spender, type(uint256).max);

        resetPrank(spender);
        protocol.trust.transferFrom(user, recipient, 300e18);

        assertEq(protocol.trust.allowance(user, spender), type(uint256).max);
    }

    /* =================================================== */
    /*        INTERNAL ERC20 ZERO-ADDRESS GUARDS            */
    /* =================================================== */

    function test_InternalTransfer_Revert_FromZeroAddress() public {
        TrustHarness harness = new TrustHarness();

        vm.expectRevert(bytes("ERC20: transfer from the zero address"));
        harness.transferForTest(address(0), user, 1e18);
    }

    function test_InternalBurn_Revert_FromZeroAddress() public {
        TrustHarness harness = new TrustHarness();

        vm.expectRevert(bytes("ERC20: burn from the zero address"));
        harness.burnForTest(address(0), 1e18);
    }

    function test_InternalApprove_Revert_OwnerZeroAddress() public {
        TrustHarness harness = new TrustHarness();

        vm.expectRevert(bytes("ERC20: approve from the zero address"));
        harness.approveForTest(address(0), user, 1e18);
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

    function test_Reinitialize_Success() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        address newAdmin = makeAddr("newAdmin");
        address controller = makeAddr("controller");

        fresh.reinitialize(newAdmin, controller);

        assertTrue(fresh.hasRole(DEFAULT_ADMIN_ROLE, newAdmin));

        vm.startPrank(controller);
        fresh.mint(user, 1e18);
        vm.stopPrank();

        assertEq(fresh.balanceOf(user), 1e18);
    }

    function test_Reinitialize_Revert_ZeroAddresses() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        vm.expectRevert(ITrust.Trust_ZeroAddress.selector);
        fresh.reinitialize(address(0), makeAddr("controller"));

        vm.expectRevert(ITrust.Trust_ZeroAddress.selector);
        fresh.reinitialize(makeAddr("admin"), address(0));
    }

    function test_Reinitialize_Revert_SecondCall() public {
        Trust fresh = _deployTrustProxy();
        fresh.init();

        fresh.reinitialize(makeAddr("admin"), makeAddr("controller"));

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Initializable: contract is already initialized"));
        fresh.reinitialize(makeAddr("admin2"), makeAddr("controller2"));
    }

    /* =================================================== */
    /*                      ADMIN TESTS                    */
    /* =================================================== */

    function test_setBaseEmissionsController_Success() public {
        address newController = makeAddr("newController");

        resetPrank(admin);
        protocol.trust.setBaseEmissionsController(newController);

        assertEq(protocol.trust.baseEmissionsController(), newController);
    }

    function test_setBaseEmissionsController_Revert_NotAdmin() public {
        address newController = makeAddr("newController");

        resetPrank(user);
        vm.expectRevert(_missingRoleRevert(user, DEFAULT_ADMIN_ROLE));
        protocol.trust.setBaseEmissionsController(newController);
    }

    function test_setBaseEmissionsController_Revert_ZeroAddress() public {
        resetPrank(admin);
        vm.expectRevert(ITrust.Trust_ZeroAddress.selector);
        protocol.trust.setBaseEmissionsController(address(0));
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
