// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

/// @title MultiVault Access Control Tests
/// @notice Comprehensive tests for PAUSER_ROLE, onlyTimelock, and DEFAULT_ADMIN_ROLE boundaries
contract MultiVaultAccessControlTest is BaseTest {
    /// @dev A dedicated pauser address (not admin) for testing role separation
    address internal pauser;

    function setUp() public override {
        super.setUp();
        pauser = createUser("pauser");

        // Grant PAUSER_ROLE to the dedicated pauser
        resetPrank(users.admin);
        protocol.multiVault.grantRole(protocol.multiVault.PAUSER_ROLE(), pauser);
    }

    /*////////////////////////////////////////////////////////////////////
                              PAUSER_ROLE TESTS
    ////////////////////////////////////////////////////////////////////*/

    function test_pause_shouldSucceedWithPauserRole() public {
        resetPrank(pauser);
        protocol.multiVault.pause();

        assertTrue(protocol.multiVault.paused());
    }

    function test_pause_shouldSucceedWithAdminWhoPauserRole() public {
        // admin also has PAUSER_ROLE (granted in BaseTest setUp)
        resetPrank(users.admin);
        protocol.multiVault.pause();

        assertTrue(protocol.multiVault.paused());
    }

    function test_pause_shouldRevertWithUnauthorizedUser() public {
        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, protocol.multiVault.PAUSER_ROLE()
            )
        );
        protocol.multiVault.pause();
    }

    function test_pause_shouldRevertWhenAlreadyPaused() public {
        resetPrank(pauser);
        protocol.multiVault.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        protocol.multiVault.pause();
    }

    /*////////////////////////////////////////////////////////////////////
                          UNPAUSE (DEFAULT_ADMIN_ROLE)
    ////////////////////////////////////////////////////////////////////*/

    function test_unpause_shouldSucceedWithAdminRole() public {
        resetPrank(pauser);
        protocol.multiVault.pause();

        resetPrank(users.admin);
        protocol.multiVault.unpause();

        assertFalse(protocol.multiVault.paused());
    }

    function test_unpause_shouldRevertWithPauserOnly() public {
        // Dedicated pauser only has PAUSER_ROLE and no DEFAULT_ADMIN_ROLE
        resetPrank(pauser);
        protocol.multiVault.pause();

        // pauser does not have DEFAULT_ADMIN_ROLE, cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                pauser,
                protocol.multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
        protocol.multiVault.unpause();
    }

    function test_unpause_shouldRevertWithUnauthorizedUser() public {
        resetPrank(pauser);
        protocol.multiVault.pause();

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.alice,
                protocol.multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
        protocol.multiVault.unpause();
    }

    function test_unpause_shouldRevertWhenNotPaused() public {
        resetPrank(users.admin);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        protocol.multiVault.unpause();
    }

    /*////////////////////////////////////////////////////////////////////
                     ONLY_TIMELOCK: setGeneralConfig
    ////////////////////////////////////////////////////////////////////*/

    function test_setGeneralConfig_shouldSucceedWithTimelock() public {
        GeneralConfig memory gc = _getDefaultGeneralConfig();
        gc.minDeposit = gc.minDeposit + 1;

        resetPrank(users.timelock);
        protocol.multiVault.setGeneralConfig(gc);

        (,,,, uint256 newMinDeposit,,,) = protocol.multiVault.generalConfig();
        assertEq(newMinDeposit, gc.minDeposit);
    }

    function test_setGeneralConfig_shouldRevertWithAdmin() public {
        GeneralConfig memory gc = _getDefaultGeneralConfig();

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setGeneralConfig(gc);
    }

    function test_setGeneralConfig_shouldRevertWithUnauthorizedUser() public {
        GeneralConfig memory gc = _getDefaultGeneralConfig();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setGeneralConfig(gc);
    }

    /*////////////////////////////////////////////////////////////////////
                       ONLY_TIMELOCK: setAtomConfig
    ////////////////////////////////////////////////////////////////////*/

    function test_setAtomConfig_shouldSucceedWithTimelock() public {
        AtomConfig memory ac = _getDefaultAtomConfig();
        ac.atomCreationProtocolFee = ac.atomCreationProtocolFee + 1;

        resetPrank(users.timelock);
        protocol.multiVault.setAtomConfig(ac);

        (uint256 newFee,) = protocol.multiVault.atomConfig();
        assertEq(newFee, ac.atomCreationProtocolFee);
    }

    function test_setAtomConfig_shouldRevertWithAdmin() public {
        AtomConfig memory ac = _getDefaultAtomConfig();

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setAtomConfig(ac);
    }

    function test_setAtomConfig_shouldRevertWithUnauthorizedUser() public {
        AtomConfig memory ac = _getDefaultAtomConfig();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setAtomConfig(ac);
    }

    /*////////////////////////////////////////////////////////////////////
                      ONLY_TIMELOCK: setTripleConfig
    ////////////////////////////////////////////////////////////////////*/

    function test_setTripleConfig_shouldSucceedWithTimelock() public {
        TripleConfig memory tc = _getDefaultTripleConfig();
        tc.tripleCreationProtocolFee = tc.tripleCreationProtocolFee + 1;

        resetPrank(users.timelock);
        protocol.multiVault.setTripleConfig(tc);

        (uint256 newFee,) = protocol.multiVault.tripleConfig();
        assertEq(newFee, tc.tripleCreationProtocolFee);
    }

    function test_setTripleConfig_shouldRevertWithAdmin() public {
        TripleConfig memory tc = _getDefaultTripleConfig();

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setTripleConfig(tc);
    }

    function test_setTripleConfig_shouldRevertWithUnauthorizedUser() public {
        TripleConfig memory tc = _getDefaultTripleConfig();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setTripleConfig(tc);
    }

    /*////////////////////////////////////////////////////////////////////
                      ONLY_TIMELOCK: setWalletConfig
    ////////////////////////////////////////////////////////////////////*/

    function test_setWalletConfig_shouldSucceedWithTimelock() public {
        WalletConfig memory wc = _getDefaultWalletConfig(address(protocol.atomWalletFactory));
        wc.atomWarden = address(0xCAFE);

        resetPrank(users.timelock);
        protocol.multiVault.setWalletConfig(wc);

        (, address newWarden,,) = protocol.multiVault.walletConfig();
        assertEq(newWarden, address(0xCAFE));
    }

    function test_setWalletConfig_shouldRevertWithAdmin() public {
        WalletConfig memory wc = _getDefaultWalletConfig(address(1));

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setWalletConfig(wc);
    }

    function test_setWalletConfig_shouldRevertWithUnauthorizedUser() public {
        WalletConfig memory wc = _getDefaultWalletConfig(address(1));

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setWalletConfig(wc);
    }

    /*////////////////////////////////////////////////////////////////////
                       ONLY_TIMELOCK: setVaultFees
    ////////////////////////////////////////////////////////////////////*/

    function test_setVaultFees_shouldSucceedWithTimelock() public {
        VaultFees memory vf = _getDefaultVaultFees();
        vf.entryFee = vf.entryFee + 1;

        resetPrank(users.timelock);
        protocol.multiVault.setVaultFees(vf);

        (uint256 newEntry,,) = protocol.multiVault.vaultFees();
        assertEq(newEntry, vf.entryFee);
    }

    function test_setVaultFees_shouldRevertWithAdmin() public {
        VaultFees memory vf = _getDefaultVaultFees();

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setVaultFees(vf);
    }

    function test_setVaultFees_shouldRevertWithUnauthorizedUser() public {
        VaultFees memory vf = _getDefaultVaultFees();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setVaultFees(vf);
    }

    /*////////////////////////////////////////////////////////////////////
                   ONLY_TIMELOCK: setBondingCurveConfig
    ////////////////////////////////////////////////////////////////////*/

    function test_setBondingCurveConfig_shouldSucceedWithTimelock() public {
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();
        bc.registry = address(protocol.curveRegistry);
        bc.defaultCurveId = 2;

        resetPrank(users.timelock);
        protocol.multiVault.setBondingCurveConfig(bc);

        (, uint256 newId) = protocol.multiVault.bondingCurveConfig();
        assertEq(newId, 2);
    }

    function test_setBondingCurveConfig_shouldRevertWithAdmin() public {
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    function test_setBondingCurveConfig_shouldRevertWithUnauthorizedUser() public {
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    /*////////////////////////////////////////////////////////////////////
                        ONLY_TIMELOCK: setTimelock
    ////////////////////////////////////////////////////////////////////*/

    function test_setTimelock_shouldSucceedWithTimelock() public {
        address newTimelock = makeAddr("newTimelock");

        resetPrank(users.timelock);
        protocol.multiVault.setTimelock(newTimelock);

        assertEq(protocol.multiVault.timelock(), newTimelock);
    }

    function test_setTimelock_shouldRevertWithZeroAddress() public {
        resetPrank(users.timelock);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ZeroAddress.selector));
        protocol.multiVault.setTimelock(address(0));
    }

    function test_setTimelock_shouldRevertWithAdmin() public {
        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setTimelock(makeAddr("newTimelock"));
    }

    function test_setTimelock_shouldRevertWithUnauthorizedUser() public {
        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setTimelock(makeAddr("newTimelock"));
    }

    function test_setTimelock_emitsTimelockSetEvent() public {
        address newTimelock = makeAddr("newTimelock");

        resetPrank(users.timelock);
        vm.expectEmit(true, true, true, true);
        emit IMultiVault.TimelockSet(newTimelock);
        protocol.multiVault.setTimelock(newTimelock);
    }

    /*////////////////////////////////////////////////////////////////////
                            REINITIALIZE
    ////////////////////////////////////////////////////////////////////*/

    function test_reinitialize_cannotBeCalledTwice() public {
        // reinitialize was already called in BaseTest setUp
        resetPrank(users.admin);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        protocol.multiVault.reinitialize(users.timelock);
    }

    function test_reinitialize_shouldRevertWithNonAdmin() public {
        // Even if reinitializer weren't already used, non-admin cannot call it
        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.alice,
                protocol.multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
        protocol.multiVault.reinitialize(users.timelock);
    }

    /*////////////////////////////////////////////////////////////////////
                          ROLE MANAGEMENT
    ////////////////////////////////////////////////////////////////////*/

    function test_adminCanGrantPauserRole() public {
        address newPauser = makeAddr("newPauser");

        resetPrank(users.admin);
        protocol.multiVault.grantRole(protocol.multiVault.PAUSER_ROLE(), newPauser);

        assertTrue(protocol.multiVault.hasRole(protocol.multiVault.PAUSER_ROLE(), newPauser));
    }

    function test_adminCanRevokePauserRole() public {
        // pauser was granted role in setUp
        assertTrue(protocol.multiVault.hasRole(protocol.multiVault.PAUSER_ROLE(), pauser));

        resetPrank(users.admin);
        protocol.multiVault.revokeRole(protocol.multiVault.PAUSER_ROLE(), pauser);

        assertFalse(protocol.multiVault.hasRole(protocol.multiVault.PAUSER_ROLE(), pauser));
    }

    function test_nonAdminCannotGrantPauserRole() public {
        address newPauser = makeAddr("newPauser");
        bytes32 pauserRole = protocol.multiVault.PAUSER_ROLE();
        bytes32 adminRole = protocol.multiVault.DEFAULT_ADMIN_ROLE();

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, adminRole)
        );
        protocol.multiVault.grantRole(pauserRole, newPauser);
    }

    function test_pauserCannotPauseAfterRoleRevocation() public {
        // Pauser pauses, admin revokes PAUSER_ROLE, then pauser cannot pause again
        resetPrank(pauser);
        protocol.multiVault.pause();

        resetPrank(users.admin);
        protocol.multiVault.revokeRole(protocol.multiVault.PAUSER_ROLE(), pauser);

        // pauser can no longer pause (role revoked)
        protocol.multiVault.unpause();

        resetPrank(pauser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, pauser, protocol.multiVault.PAUSER_ROLE()
            )
        );
        protocol.multiVault.pause();
    }

    /*////////////////////////////////////////////////////////////////////
                     TIMELOCK TRANSFER INTEGRATION
    ////////////////////////////////////////////////////////////////////*/

    function test_timelockTransfer_fullFlow() public {
        // 1. Current timelock updates config
        resetPrank(users.timelock);
        VaultFees memory vf = _getDefaultVaultFees();
        vf.entryFee = 200;
        protocol.multiVault.setVaultFees(vf);

        // 2. Transfer timelock to new address
        address newTimelock = makeAddr("newTimelock");
        protocol.multiVault.setTimelock(newTimelock);

        // 3. Old timelock can no longer call
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        protocol.multiVault.setVaultFees(vf);

        // 4. New timelock can call
        resetPrank(newTimelock);
        vf.entryFee = 300;
        protocol.multiVault.setVaultFees(vf);

        (uint256 entry,,) = protocol.multiVault.vaultFees();
        assertEq(entry, 300);
    }
}
