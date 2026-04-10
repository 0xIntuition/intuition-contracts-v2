// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { GeneralConfig } from "src/interfaces/IMultiVaultCore.sol";

/// @title MultiVault Upgrade Regression Test
/// @notice Fork-based test verifying that the RBAC hardening upgrade preserves state and activates new access controls
/// @dev Uses Intuition Mainnet.
contract MultiVaultUpgradeRegressionTest is Test {
    // --- Intuition Mainnet addresses (chain ID 1155) ---
    // These should be updated to mainnet addresses for production regression testing
    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant PROXY_ADMIN = 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8;
    uint256 internal constant INTUITION_FORK_BLOCK = 2_369_449;

    // --- State snapshots ---
    MultiVault internal multiVault;
    ProxyAdmin internal proxyAdmin;

    // Pre-upgrade state
    uint256 internal preUpgradeTotalTerms;
    address internal preUpgradeAdmin;
    address internal preUpgradeMultisig;
    uint256 internal preUpgradeFeeDenominator;
    uint256 internal preUpgradeMinDeposit;

    function setUp() external {
        vm.createSelectFork("intuition", INTUITION_FORK_BLOCK);

        multiVault = MultiVault(MULTIVAULT_PROXY);
        proxyAdmin = ProxyAdmin(PROXY_ADMIN);

        // Snapshot pre-upgrade state
        preUpgradeTotalTerms = multiVault.totalTermsCreated();
        (preUpgradeAdmin, preUpgradeMultisig, preUpgradeFeeDenominator,, preUpgradeMinDeposit,,,) =
            multiVault.generalConfig();
    }

    function test_upgradePreservesStateAndActivatesRBAC() external {
        // 1. Deploy new implementation
        MultiVault newImpl = new MultiVault();

        // 2. Upgrade via ProxyAdmin (as upgrades timelock)
        vm.startPrank(UPGRADES_TIMELOCK);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY)), address(newImpl), bytes(""));
        vm.stopPrank();

        // 3. Verify state preserved
        assertEq(multiVault.totalTermsCreated(), preUpgradeTotalTerms, "totalTermsCreated changed");
        (address admin, address multisig, uint256 feeDenom,, uint256 minDep,,,) = multiVault.generalConfig();
        assertEq(admin, preUpgradeAdmin, "admin changed");
        assertEq(multisig, preUpgradeMultisig, "protocolMultisig changed");
        assertEq(feeDenom, preUpgradeFeeDenominator, "feeDenominator changed");
        assertEq(minDep, preUpgradeMinDeposit, "minDeposit changed");

        // 4. Verify timelock is unset (zero before reinitialize)
        assertEq(multiVault.timelock(), address(0), "timelock should be zero before reinitialize");

        // 5. Admin calls reinitialize to set timelock
        assertTrue(
            multiVault.hasRole(multiVault.DEFAULT_ADMIN_ROLE(), preUpgradeAdmin),
            "preUpgradeAdmin must hold DEFAULT_ADMIN_ROLE"
        );
        vm.startPrank(preUpgradeAdmin);
        multiVault.reinitialize(preUpgradeAdmin); // Set admin as initial timelock
        vm.stopPrank();

        assertEq(multiVault.timelock(), preUpgradeAdmin, "timelock should be admin after reinitialize");

        // 6. Verify config setters now require timelock (admin IS the timelock temporarily)
        vm.startPrank(preUpgradeAdmin);
        GeneralConfig memory gc = GeneralConfig({
            admin: preUpgradeAdmin,
            protocolMultisig: preUpgradeMultisig,
            feeDenominator: preUpgradeFeeDenominator,
            trustBonding: address(0),
            minDeposit: preUpgradeMinDeposit + 1,
            minShare: 0,
            atomDataMaxLength: 0,
            feeThreshold: 0
        });
        // This should succeed since admin is currently the timelock
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // 7. Non-timelock user cannot call config setters
        address randomUser = makeAddr("random");
        vm.startPrank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // 8. Verify reinitialize granted PAUSER_ROLE to admin and pause works
        assertTrue(multiVault.hasRole(multiVault.PAUSER_ROLE(), preUpgradeAdmin), "admin should have PAUSER_ROLE");
        vm.startPrank(preUpgradeAdmin);
        multiVault.pause();
        assertTrue(multiVault.paused(), "should be paused");
        multiVault.unpause();
        assertFalse(multiVault.paused(), "should be unpaused");
        vm.stopPrank();

        // 9. User without PAUSER_ROLE cannot pause
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, multiVault.PAUSER_ROLE()
            )
        );
        multiVault.pause();
        vm.stopPrank();

        // 10. Transfer timelock to a new address and verify old timelock loses access
        address newTimelock = makeAddr("newTimelock");
        vm.startPrank(preUpgradeAdmin);
        multiVault.setTimelock(newTimelock);
        vm.stopPrank();

        assertEq(multiVault.timelock(), newTimelock, "timelock should be updated");

        // Old timelock (admin) can no longer call config setters
        vm.startPrank(preUpgradeAdmin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // New timelock can call config setters
        vm.startPrank(newTimelock);
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();
    }

    function test_reinitializeCannotBeCalledTwice() external {
        // Deploy and upgrade
        MultiVault newImpl = new MultiVault();
        vm.startPrank(UPGRADES_TIMELOCK);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY)), address(newImpl), bytes(""));
        vm.stopPrank();

        // First reinitialize succeeds
        vm.startPrank(preUpgradeAdmin);
        multiVault.reinitialize(preUpgradeAdmin);

        // Second reinitialize reverts
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        multiVault.reinitialize(preUpgradeAdmin);
        vm.stopPrank();
    }

    function test_reinitializeRevertsForNonAdmin() external {
        // Deploy and upgrade
        MultiVault newImpl = new MultiVault();
        vm.startPrank(UPGRADES_TIMELOCK);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY)), address(newImpl), bytes(""));
        vm.stopPrank();

        // Non-admin cannot call reinitialize
        address randomUser = makeAddr("random");
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
        multiVault.reinitialize(randomUser);
        vm.stopPrank();
    }
}
