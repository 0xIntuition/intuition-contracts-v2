// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {MultiVaultConfig} from "src/v2/MultiVaultConfig.sol";
import {MultiVault} from "src/MultiVault.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

contract MultiVaultConfigTest is MultiVaultBase {
    // ──────────────────────────────────────────────────────────────────────────
    //                               set-up helpers
    // ──────────────────────────────────────────────────────────────────────────

    address public timelock = makeAddr("timelock");

    /// @dev Grant TIMELOCK_ROLE to `timelock` so we can test time-locked setters.
    function _grantTimelock() internal {
        vm.startPrank(admin);
        multiVaultConfig.grantRole(multiVaultConfig.TIMELOCK_ROLE(), timelock);
        vm.stopPrank();
    }

    // ──────────────────────────────────────────────────────────────────────────
    //                       INITIALIZER  (fresh deployment)
    // ──────────────────────────────────────────────────────────────────────────

    function test_initialize_happyPath_setsStateAndRoles() external {
        // Deploy fresh logic + proxy
        MultiVaultConfig logic = new MultiVaultConfig();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), admin, "");
        MultiVaultConfig cfg = MultiVaultConfig(address(proxy));

        // Reuse existing structs from base
        vm.prank(address(this));
        cfg.initialize(
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig,
            wrapperConfig,
            migrator,
            address(multiVault)
        );

        // Role membership
        assertTrue(cfg.hasRole(cfg.DEFAULT_ADMIN_ROLE(), generalConfig.admin));
        assertTrue(cfg.hasRole(cfg.PAUSER_ROLE(), generalConfig.admin));
        assertTrue(cfg.hasRole(cfg.MIGRATOR_ROLE(), migrator));

        // Immutable pointer to MultiVault
        assertEq(address(cfg.multiVault()), address(multiVault));

        // A single field check per struct is enough to prove storage assignment
        assertEq(cfg.getGeneralConfig().minDeposit, generalConfig.minDeposit);
        assertEq(cfg.getAtomConfig().atomCreationProtocolFee, atomConfig.atomCreationProtocolFee);
        assertEq(cfg.getVaultFees().entryFee, vaultFees.entryFee);
    }

    function test_initialize_revertsOnZeroAddrs() external {
        MultiVaultConfig logic = new MultiVaultConfig();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), admin, "");
        MultiVaultConfig cfg = MultiVaultConfig(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        cfg.initialize(
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig,
            wrapperConfig,
            address(0), // _migrator
            address(multiVault)
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        cfg.initialize(
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig,
            wrapperConfig,
            migrator,
            address(0) // _multiVault
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    //                            PAUSE / UNPAUSE
    // ──────────────────────────────────────────────────────────────────────────

    function test_pause_unpause_rolesAndState() external {
        // ─ pause by PAUSER_ROLE (admin)
        vm.prank(admin);
        multiVaultConfig.pause();
        assertTrue(PausableUpgradeable(address(multiVaultConfig)).paused());

        // attempt by non-pauser reverts
        vm.prank(bob);
        vm.expectRevert(); // AccessControl revert string is fine
        multiVaultConfig.pause();

        // ─ unpause by DEFAULT_ADMIN_ROLE (admin)
        vm.prank(admin);
        multiVaultConfig.unpause();
        assertTrue(!PausableUpgradeable(address(multiVaultConfig)).paused());

        // attempt by non-admin reverts
        vm.prank(alice);
        vm.expectRevert();
        multiVaultConfig.unpause();
    }

    // ──────────────────────────────────────────────────────────────────────────
    //                     TIMELOCK-GATED: setMultiVault / setAdmin / setExitFee
    // ──────────────────────────────────────────────────────────────────────────

    function test_setMultiVault_happyPath() external {
        _grantTimelock();

        // Deploy a brand-new MultiVault, initialise it
        MultiVault newMVLogic = new MultiVault();
        TransparentUpgradeableProxy p = new TransparentUpgradeableProxy(address(newMVLogic), admin, "");
        MultiVault newMV = MultiVault(address(p));
        newMV.initialize(address(multiVaultConfig));

        // timelock performs the switch
        vm.prank(timelock);
        multiVaultConfig.setMultiVault(address(newMV));

        assertEq(address(multiVaultConfig.multiVault()), address(newMV));
    }

    function test_setMultiVault_revertsIfZeroAddr() external {
        _grantTimelock();
        vm.prank(timelock);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        multiVaultConfig.setMultiVault(address(0));
    }

    function test_setMultiVault_revertsIfCallerNotTimelock() external {
        vm.prank(bob);
        vm.expectRevert();
        multiVaultConfig.setMultiVault(address(multiVault));
    }

    function test_setAdmin_updatesAdminAndSyncs() external {
        _grantTimelock();
        address newAdmin = makeAddr("newAdmin");

        vm.prank(timelock);
        multiVaultConfig.setAdmin(newAdmin);

        // reflected inside config
        assertEq(multiVaultConfig.getGeneralConfig().admin, newAdmin);
        // reflected in vault after automatic sync
        assertEq(getGeneralConfig().admin, newAdmin);
    }

    function test_setExitFee_happyPathAndBounds() external {
        _grantTimelock();

        uint256 newFee = 900; // within MAX_EXIT_FEE (1000)
        vm.prank(timelock);
        multiVaultConfig.setExitFee(newFee);
        assertEq(multiVaultConfig.getVaultFees().exitFee, newFee);

        // > MAX_EXIT_FEE reverts
        vm.prank(timelock);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_InvalidExitFee.selector));
        multiVaultConfig.setExitFee(1001);
    }

    // ──────────────────────────────────────────────────────────────────────────
    //               DEFAULT-ADMIN setters with numeric bounds
    // ──────────────────────────────────────────────────────────────────────────

    function test_setEntryFee_branches() external {
        vm.startPrank(admin);

        // happy path
        uint256 fee = 250;
        multiVaultConfig.setEntryFee(fee);
        assertEq(multiVaultConfig.getVaultFees().entryFee, fee);

        // out-of-bounds
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_InvalidEntryFee.selector));
        multiVaultConfig.setEntryFee(1001);

        vm.stopPrank();
    }

    function test_setAtomWalletDepositFee_branches() external {
        vm.startPrank(admin);

        uint256 ok = 750;
        multiVaultConfig.setAtomWalletDepositFee(ok);
        assertEq(multiVaultConfig.getAtomConfig().atomWalletDepositFee, ok);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_InvalidAtomWalletDepositFee.selector));
        multiVaultConfig.setAtomWalletDepositFee(1001);

        vm.stopPrank();
    }

    function test_setAtomDepositFractionForTriple_branches() external {
        vm.startPrank(admin);

        uint256 ok = 8000;
        multiVaultConfig.setAtomDepositFractionForTriple(ok);
        assertEq(multiVaultConfig.getTripleConfig().atomDepositFractionForTriple, ok);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_InvalidAtomDepositFractionForTriple.selector));
        multiVaultConfig.setAtomDepositFractionForTriple(9001);

        vm.stopPrank();
    }

    // ──────────────────────────────────────────────────────────────────────────
    //                  MIN-VALUE guards (ZeroValue / ZeroAddress)
    // ──────────────────────────────────────────────────────────────────────────

    function test_setMinDeposit_zeroReverts() external {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroValue.selector));
        multiVaultConfig.setMinDeposit(0);
        vm.stopPrank();
    }

    function test_setAtomWarden_zeroAddrReverts() external {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        multiVaultConfig.setAtomWarden(address(0));
        vm.stopPrank();
    }

    // ──────────────────────────────────────────────────────────────────────────
    //                     OTHER ADMIN METHOD TESTS
    // ──────────────────────────────────────────────────────────────────────────

    // ───────── DEFAULT-ADMIN: setProtocolMultisig (zero-addr + happy)
    function test_setProtocolMultisig_branches() external {
        address newMultisig = makeAddr("newMultisig");

        // happy path
        vm.prank(admin);
        multiVaultConfig.setProtocolMultisig(newMultisig);
        assertEq(multiVaultConfig.getGeneralConfig().protocolMultisig, newMultisig);
        // reflected in vault
        assertEq(getGeneralConfig().protocolMultisig, newMultisig);

        // zero-address revert
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        multiVaultConfig.setProtocolMultisig(address(0));
    }

    // ───────── TIMELOCK-ROLE: setTrustBonding (zero-addr + happy)
    function test_setTrustBonding_branches() external {
        _grantTimelock();
        address newTB = makeAddr("newTrustBonding");

        // happy path via timelock
        vm.prank(timelock);
        multiVaultConfig.setTrustBonding(newTB);
        assertEq(multiVaultConfig.getGeneralConfig().trustBonding, newTB);
        assertEq(getGeneralConfig().trustBonding, newTB);

        // zero-address revert
        vm.prank(timelock);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroAddress.selector));
        multiVaultConfig.setTrustBonding(address(0));
    }

    // ───────── setMinShare (zero-value + happy)
    function test_setMinShare_branches() external {
        uint256 newVal = 2e6;
        vm.startPrank(admin);

        // happy
        multiVaultConfig.setMinShare(newVal);
        assertEq(multiVaultConfig.getGeneralConfig().minShare, newVal);

        // zero revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroValue.selector));
        multiVaultConfig.setMinShare(0);

        vm.stopPrank();
    }

    // ───────── setProtocolFee (bounds)
    function test_setProtocolFee_branches() external {
        vm.startPrank(admin);

        uint256 ok = 777;
        multiVaultConfig.setProtocolFee(ok);
        assertEq(multiVaultConfig.getVaultFees().protocolFee, ok);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_InvalidProtocolFee.selector));
        multiVaultConfig.setProtocolFee(1001); // > MAX_PROTOCOL_FEE

        vm.stopPrank();
    }

    // ───────── setAtomDataMaxLength (zero-value + happy)
    function test_setAtomDataMaxLength_branches() external {
        vm.startPrank(admin);

        uint256 ok = 500;
        multiVaultConfig.setAtomDataMaxLength(ok);
        assertEq(multiVaultConfig.getGeneralConfig().atomDataMaxLength, ok);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVaultConfig_ZeroValue.selector));
        multiVaultConfig.setAtomDataMaxLength(0);

        vm.stopPrank();
    }

    // ───────── setAtomWarden happy-path (zero-addr revert already covered)
    function test_setAtomWarden_happyPath() external {
        address warden = makeAddr("warden");
        vm.prank(admin);
        multiVaultConfig.setAtomWarden(warden);
        assertEq(multiVaultConfig.getWalletConfig().atomWarden, warden);
        assertEq(getWalletConfig().atomWarden, warden);
    }
}
