// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";
import { FeeProxy } from "src/periphery/FeeProxy.sol";

contract AccessControlTest is FeeProxyBaseTest {
    function test_roles_initialAssignments() external view {
        assertTrue(feeProxy.hasRole(feeProxy.DEFAULT_ADMIN_ROLE(), feeProxyAdmin), "admin holds DEFAULT_ADMIN_ROLE");
        assertTrue(feeProxy.hasRole(feeProxy.PAUSER_ROLE(), feeProxyAdmin), "admin holds PAUSER_ROLE");
    }

    function test_pauseAffiliate_OnlyPauserRole() external {
        _registerSampleAffiliate();

        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.PAUSER_ROLE()
            )
        );
        feeProxy.pauseAffiliate(affiliate);
        vm.stopPrank();
    }

    function test_unpauseAffiliate_OnlyAdminRole() external {
        _registerSampleAffiliate();

        // Even the pauser cannot unpause once we revoke admin from them.
        address pauserOnly = makeAddr("pauserOnly");
        vm.startPrank(feeProxyAdmin);
        feeProxy.grantRole(feeProxy.PAUSER_ROLE(), pauserOnly);
        vm.stopPrank();

        vm.startPrank(pauserOnly);
        feeProxy.pauseAffiliate(affiliate);
        vm.stopPrank();

        vm.startPrank(pauserOnly);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, pauserOnly, feeProxy.DEFAULT_ADMIN_ROLE()
            )
        );
        feeProxy.unpauseAffiliate(affiliate);
        vm.stopPrank();
    }

    function test_pause_OnlyPauserRole() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.PAUSER_ROLE()
            )
        );
        feeProxy.pause();
        vm.stopPrank();
    }

    function test_unpause_OnlyAdminRole() external {
        // A pauser without DEFAULT_ADMIN_ROLE cannot reverse the global pause.
        address pauserOnly = makeAddr("pauserOnly");
        vm.startPrank(feeProxyAdmin);
        feeProxy.grantRole(feeProxy.PAUSER_ROLE(), pauserOnly);
        vm.stopPrank();

        vm.startPrank(pauserOnly);
        feeProxy.pause();
        vm.stopPrank();

        vm.startPrank(pauserOnly);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, pauserOnly, feeProxy.DEFAULT_ADMIN_ROLE()
            )
        );
        feeProxy.unpause();
        vm.stopPrank();
    }

    function test_setMaxBps_OnlyAdminRole() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.DEFAULT_ADMIN_ROLE()
            )
        );
        feeProxy.setMaxBps(500);
        vm.stopPrank();
    }

    function test_setMaxFixedFee_OnlyAdminRole() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.DEFAULT_ADMIN_ROLE()
            )
        );
        feeProxy.setMaxFixedFee(1 ether);
        vm.stopPrank();
    }

    function test_setRegistrationFee_OnlyAdminRole() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.DEFAULT_ADMIN_ROLE()
            )
        );
        feeProxy.setRegistrationFee(1 ether);
        vm.stopPrank();
    }

    function test_adminCan_grantAndRevokePauserRole() external {
        address newPauser = makeAddr("newPauser");
        bytes32 pauserRole = feeProxy.PAUSER_ROLE();

        vm.startPrank(feeProxyAdmin);
        feeProxy.grantRole(pauserRole, newPauser);
        vm.stopPrank();
        assertTrue(feeProxy.hasRole(pauserRole, newPauser), "newPauser granted");

        vm.startPrank(feeProxyAdmin);
        feeProxy.revokeRole(pauserRole, newPauser);
        vm.stopPrank();
        assertFalse(feeProxy.hasRole(pauserRole, newPauser), "newPauser revoked");
    }

    function test_initialize_revertsWhen_alreadyInitialized() external {
        vm.startPrank(feeProxyAdmin);
        vm.expectRevert();
        feeProxy.initialize(address(protocol.multiVault), treasury, feeProxyAdmin, 0, 0, 0);
        vm.stopPrank();
    }

    function test_initialize_revertsWhen_multiVaultIsZero() external {
        FeeProxy impl = new FeeProxy();
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(impl),
            users.admin,
            abi.encodeWithSelector(FeeProxy.initialize.selector, address(0), treasury, feeProxyAdmin, 0, 0, 0)
        );
    }

    function test_initialize_revertsWhen_treasuryIsZero() external {
        FeeProxy impl = new FeeProxy();
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(impl),
            users.admin,
            abi.encodeWithSelector(
                FeeProxy.initialize.selector, address(protocol.multiVault), address(0), feeProxyAdmin, 0, 0, 0
            )
        );
    }

    function test_initialize_revertsWhen_adminIsZero() external {
        FeeProxy impl = new FeeProxy();
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(impl),
            users.admin,
            abi.encodeWithSelector(
                FeeProxy.initialize.selector, address(protocol.multiVault), treasury, address(0), 0, 0, 0
            )
        );
    }

    function test_initialize_revertsWhen_maxBpsAboveDivisor() external {
        FeeProxy impl = new FeeProxy();
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_MaxBpsOutOfRange.selector, 10_001));
        new TransparentUpgradeableProxy(
            address(impl),
            users.admin,
            abi.encodeWithSelector(
                FeeProxy.initialize.selector, address(protocol.multiVault), treasury, feeProxyAdmin, 10_001, 0, 0
            )
        );
    }
}
