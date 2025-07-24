// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Errors} from "src/libraries/Errors.sol";

import {MultiVault} from "src/MultiVault.sol";
import {MultiVaultConfig} from "src/v2/MultiVaultConfig.sol";
import {
    IMultiVaultConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultConfig.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {MultiVaultBase} from "test/MultiVaultBase.sol";

contract MultiVault_InitTest is MultiVaultBase {
    event ConfigSynced(address indexed caller);

    /*//////////////////////////////////////////////////////////////
                              HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that the proxy-initialized vault pulls every field
    ///         from MultiVaultConfig and stores it correctly.
    function test_initialize_setsStateAndSyncsConfig() external view {
        // GeneralConfig
        GeneralConfig memory gConf = multiVaultConfig.getGeneralConfig();
        GeneralConfig memory multiVaultGConf = getGeneralConfig();
        assertEq(multiVaultGConf.trust, gConf.trust);
        assertEq(multiVaultGConf.admin, gConf.admin);
        assertEq(multiVaultGConf.minDeposit, gConf.minDeposit);
        assertEq(multiVaultGConf.minShare, gConf.minShare);
        assertEq(multiVaultGConf.protocolMultisig, gConf.protocolMultisig);
        assertEq(multiVaultGConf.baseURI, gConf.baseURI);

        // AtomConfig
        AtomConfig memory aConf = multiVaultConfig.getAtomConfig();
        AtomConfig memory multiVaultAConf = getAtomConfig();
        assertEq(multiVaultAConf.atomCreationProtocolFee, aConf.atomCreationProtocolFee);
        assertEq(multiVaultAConf.atomWalletDepositFee, aConf.atomWalletDepositFee);

        // TripleConfig
        TripleConfig memory tConf = multiVaultConfig.getTripleConfig();
        TripleConfig memory multiVaultTConf = getTripleConfig();
        assertEq(multiVaultTConf.tripleCreationProtocolFee, tConf.tripleCreationProtocolFee);
        assertEq(multiVaultTConf.totalAtomDepositsOnTripleCreation, tConf.totalAtomDepositsOnTripleCreation);

        // WalletConfig
        WalletConfig memory wConf = multiVaultConfig.getWalletConfig();
        WalletConfig memory multiVaultWConf = getWalletConfig();
        assertEq(multiVaultWConf.atomWarden, wConf.atomWarden);

        // VaultFees
        VaultFees memory vFees = multiVaultConfig.getVaultFees();
        VaultFees memory multiVaultVFees = getVaultFees();
        assertEq(multiVaultVFees.entryFee, vFees.entryFee);
        assertEq(multiVaultVFees.exitFee, vFees.exitFee);
        assertEq(multiVaultVFees.protocolFee, vFees.protocolFee);

        // BondingCurveConfig
        BondingCurveConfig memory bcConf = multiVaultConfig.getBondingCurveConfig();
        BondingCurveConfig memory multiVaultBCConf = getBondingCurveConfig();
        assertEq(multiVaultBCConf.registry, bcConf.registry);
        assertEq(multiVaultBCConf.defaultCurveId, bcConf.defaultCurveId);

        // Paused flag pulled from config
        assertTrue(!multiVault.paused());
    }

    /// @notice Anyone can re-sync the config;              branch-test when
    ///         config _is not paused_  → paused == false.
    function test_syncConfig_unpausedBranch_anyCaller() external {
        vm.startPrank(alice);
        multiVault.syncConfig();
        vm.stopPrank();

        assertTrue(!multiVault.paused());
    }

    /// @notice Branch-test when MultiVaultConfig **is paused**.
    function test_syncConfig_pausedBranch_reflectsState() external {
        vm.prank(multiVaultConfig.getGeneralConfig().admin);
        multiVaultConfig.pause();
        assertTrue(PausableUpgradeable(address(multiVaultConfig)).paused());

        // Sync via arbitrary caller
        vm.prank(bob);
        multiVault.syncConfig();

        assertTrue(multiVault.paused());
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT PATHS
    //////////////////////////////////////////////////////////////*/

    /// @notice `initialize` must revert if the config address is zero.
    function test_initialize_shouldRevertIfZeroAddress() external {
        // Deploy a fresh MultiVault proxy (uninitialised)
        MultiVault logic = new MultiVault();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), admin, "");
        MultiVault mv = MultiVault(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        mv.initialize(address(0));
    }

    /// @notice Second call to `initialize` reverts (Initializable guard).
    function test_initialize_shouldRevertOnSecondCall() external {
        vm.expectRevert(); // OZ reverts with "contract is already initialized"
        multiVault.initialize(address(multiVaultConfig));
    }

    /*//////////////////////////////////////////////////////////////
                       EVENT / SMALL-INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensure `ConfigSynced` is emitted and carries caller address.
    function test_syncConfig_emitsEvent() external {
        vm.startPrank(rich);
        vm.expectEmit(true, false, false, false);
        emit ConfigSynced(rich);
        multiVault.syncConfig();
        vm.stopPrank();
    }
}
