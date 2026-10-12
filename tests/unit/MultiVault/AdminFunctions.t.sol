// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import {
    IMultiVaultCore,
    GeneralConfig,
    AtomConfig,
    AtomUriConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MockFeeHookCurve } from "tests/mocks/MockFeeHookCurve.sol";

contract MultiVaultAdminFunctionsTest is BaseTest {
    /// @dev Define a reusable GeneralConfig struct for tests to avoid stack too deep
    GeneralConfig public gc;

    /*////////////////////////////////////////////////////////////////////
                                INTERNAL HELPERS
    ////////////////////////////////////////////////////////////////////*/

    function _expectUnauthorizedAdmin(address caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                caller,
                protocol.multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
    }

    function _expectUnauthorizedPauser(address caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, protocol.multiVault.PAUSER_ROLE()
            )
        );
    }

    function _expectOnlyTimelock() internal {
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
    }

    /*////////////////////////////////////////////////////////////////////
                                  PAUSE / UNPAUSE
    ////////////////////////////////////////////////////////////////////*/

    function testPause_OnlyPauser_SetsPausedAndBlocksDeposit() public {
        // pause as admin (who has PAUSER_ROLE)
        resetPrank({ msgSender: users.admin });
        protocol.multiVault.pause();

        // pausing twice should revert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        protocol.multiVault.pause();

        // any whenNotPaused fn must revert; use deposit (modifier executes first)
        resetPrank({ msgSender: users.alice });
        vm.deal(users.alice, 10 ether);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, bytes32(0), 1, 0);
    }

    function testPause_RevertWhen_CalledByNonPauser() public {
        resetPrank({ msgSender: users.alice });
        _expectUnauthorizedPauser(users.alice);
        protocol.multiVault.pause();
    }

    function testUnpause_OnlyAdmin_ClearsPausedAndAllowsDeposit() public {
        // first pause
        resetPrank({ msgSender: users.admin });
        protocol.multiVault.pause();

        // unpause as admin
        protocol.multiVault.unpause();

        // unpausing when not paused should revert
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        protocol.multiVault.unpause();

        // Create a valid atom so we can perform a real deposit after unpause
        bytes32 atomId = createSimpleAtom("admin-atom", getAtomCreationCost(), users.admin);

        // Alice deposits into default curve
        resetPrank({ msgSender: users.alice });
        vm.deal(users.alice, 10 ether);
        uint256 curveId = getDefaultCurveId();
        uint256 amount = MIN_DEPOSIT * 2;

        // minShares=0 to avoid slippage failure in test
        // Should NOT revert now (unpaused)
        protocol.multiVault.deposit{ value: amount }(users.alice, atomId, curveId, 0);
    }

    function testUnpause_RevertWhen_CalledByNonAdmin() public {
        resetPrank({ msgSender: users.admin });
        protocol.multiVault.pause();

        resetPrank({ msgSender: users.bob });
        _expectUnauthorizedAdmin(users.bob);
        protocol.multiVault.unpause();
    }

    /*////////////////////////////////////////////////////////////////////
                               setGeneralConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetGeneralConfig_OnlyTimelock_UpdatesFields() public {
        // Read current config
        (
            address admin,
            address protocolMultisig,
            uint256 feeDenominator,
            address trustBonding,
            uint256 minDeposit,
            uint256 minShare,
            uint256 atomDataMaxLength,
            uint256 feeThreshold
        ) = protocol.multiVault.generalConfig();

        // Prepare a new config with changed values (keep admin same to not disturb roles)
        gc = GeneralConfig({
            admin: admin,
            protocolMultisig: users.controller,
            feeDenominator: feeDenominator + 1,
            trustBonding: address(0xB0B),
            minDeposit: minDeposit + 1,
            minShare: minShare + 1,
            atomDataMaxLength: atomDataMaxLength + 7,
            feeThreshold: feeThreshold
        });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setGeneralConfig(gc);

        // Verify updated
        (
            ,
            address newMultisig,
            uint256 newFeeDenominator,
            address newTrustBonding,
            uint256 newMinDeposit,
            uint256 newMinShare,
            uint256 newAtomDataMaxLength,
            uint256 newFeeThreshold
        ) = protocol.multiVault.generalConfig();

        assertEq(newMultisig, users.controller);
        assertEq(newFeeDenominator, feeDenominator + 1);
        assertEq(newTrustBonding, address(0xB0B));
        assertEq(newMinDeposit, minDeposit + 1);
        assertEq(newMinShare, minShare + 1);
        assertEq(newAtomDataMaxLength, atomDataMaxLength + 7);
        assertEq(newFeeThreshold, feeThreshold);
    }

    function testSetGeneralConfig_RevertWhen_NotTimelock() public {
        GeneralConfig memory generalConfig = _getDefaultGeneralConfig();
        generalConfig.protocolMultisig = users.bob;

        resetPrank({ msgSender: users.alice });
        _expectOnlyTimelock();
        protocol.multiVault.setGeneralConfig(generalConfig);
    }

    /*////////////////////////////////////////////////////////////////////
                               setAtomConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetAtomConfig_OnlyTimelock_UpdatesFields() public {
        (uint256 creationFee, uint256 walletDepositFee) = protocol.multiVault.atomConfig();

        AtomConfig memory ac =
            AtomConfig({ atomCreationProtocolFee: creationFee + 123, atomWalletDepositFee: walletDepositFee + 5 });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setAtomConfig(ac);

        (uint256 newCreationFee, uint256 newWalletDepositFee) = protocol.multiVault.atomConfig();
        assertEq(newCreationFee, creationFee + 123);
        assertEq(newWalletDepositFee, walletDepositFee + 5);
    }

    function testSetAtomConfig_RevertWhen_NotTimelock() public {
        AtomConfig memory ac = _getDefaultAtomConfig();
        ac.atomWalletDepositFee = ac.atomWalletDepositFee + 1;

        resetPrank({ msgSender: users.charlie });
        _expectOnlyTimelock();
        protocol.multiVault.setAtomConfig(ac);
    }

    /*////////////////////////////////////////////////////////////////////
                             setAtomUriConfig
    ////////////////////////////////////////////////////////////////////*/

    function testGetAtomUriConfig_ReturnsDefaultsBeforeExplicitConfiguration() public view {
        (uint32 maxUriCount, uint32 maxUriLength) = protocol.multiVault.getAtomUriConfig();
        assertEq(maxUriCount, 5);
        assertEq(maxUriLength, 700);
    }

    function testSetAtomUriConfig_OnlyTimelock_UpdatesFields() public {
        AtomUriConfig memory config = AtomUriConfig({ maxUriCount: 3, maxUriLength: 512 });

        vm.expectEmit(false, false, false, true, address(protocol.multiVault));
        emit IMultiVaultCore.AtomUriConfigUpdated(config.maxUriCount, config.maxUriLength);

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setAtomUriConfig(config.maxUriCount, config.maxUriLength);

        (uint32 maxUriCount, uint32 maxUriLength) = protocol.multiVault.getAtomUriConfig();
        assertEq(maxUriCount, config.maxUriCount);
        assertEq(maxUriLength, config.maxUriLength);
    }

    function testSetAtomUriConfig_RevertWhen_NotTimelock() public {
        resetPrank({ msgSender: users.alice });
        _expectOnlyTimelock();
        protocol.multiVault.setAtomUriConfig(3, 512);
    }

    function testSetAtomUriConfig_RevertWhen_AnyLimitIsZero() public {
        resetPrank({ msgSender: users.timelock });

        vm.expectRevert(MultiVault.MultiVault_InvalidAtomUriConfig.selector);
        protocol.multiVault.setAtomUriConfig(0, 512);

        vm.expectRevert(MultiVault.MultiVault_InvalidAtomUriConfig.selector);
        protocol.multiVault.setAtomUriConfig(3, 0);
    }

    /*////////////////////////////////////////////////////////////////////
                               setTripleConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetTripleConfig_OnlyTimelock_UpdatesFields() public {
        (uint256 creationFee, uint256 atomDepositFrac) = protocol.multiVault.tripleConfig();

        TripleConfig memory tc = TripleConfig({
            tripleCreationProtocolFee: creationFee + 1, atomDepositFractionForTriple: atomDepositFrac + 3
        });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setTripleConfig(tc);

        (uint256 nCreationFee, uint256 nFrac) = protocol.multiVault.tripleConfig();
        assertEq(nCreationFee, creationFee + 1);
        assertEq(nFrac, atomDepositFrac + 3);
    }

    function testSetTripleConfig_RevertWhen_NotTimelock() public {
        TripleConfig memory tc = _getDefaultTripleConfig();
        tc.atomDepositFractionForTriple = tc.atomDepositFractionForTriple + 1;

        resetPrank({ msgSender: users.alice });
        _expectOnlyTimelock();
        protocol.multiVault.setTripleConfig(tc);
    }

    /*////////////////////////////////////////////////////////////////////
                               setVaultFees (+ fuzz)
    ////////////////////////////////////////////////////////////////////*/

    function testSetVaultFees_OnlyTimelock_UpdatesFields() public {
        (uint256 entryFee, uint256 exitFee, uint256 protocolFee) = protocol.multiVault.vaultFees();

        VaultFees memory vf = VaultFees({ entryFee: entryFee + 7, exitFee: exitFee + 9, protocolFee: protocolFee + 11 });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setVaultFees(vf);

        (uint256 nEntry, uint256 nExit, uint256 nProt) = protocol.multiVault.vaultFees();
        assertEq(nEntry, entryFee + 7);
        assertEq(nExit, exitFee + 9);
        assertEq(nProt, protocolFee + 11);
    }

    function testSetVaultFees_RevertWhen_NotTimelock() public {
        VaultFees memory vf = _getDefaultVaultFees();
        vf.protocolFee = vf.protocolFee + 1;

        resetPrank({ msgSender: users.bob });
        _expectOnlyTimelock();
        protocol.multiVault.setVaultFees(vf);
    }

    function testFuzz_SetVaultFees_OnlyTimelock(uint16 entryFee, uint16 exitFee, uint16 protocolFee) public {
        // Bound to sensible ranges (<= fee denominator)
        uint256 denom = FEE_DENOMINATOR;
        uint256 e = uint256(entryFee) % (denom + 1);
        uint256 x = uint256(exitFee) % (denom + 1);
        uint256 p = uint256(protocolFee) % (denom + 1);

        VaultFees memory vf = VaultFees({ entryFee: e, exitFee: x, protocolFee: p });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setVaultFees(vf);

        (uint256 ne, uint256 nx, uint256 np) = protocol.multiVault.vaultFees();
        assertEq(ne, e);
        assertEq(nx, x);
        assertEq(np, p);
    }

    /*////////////////////////////////////////////////////////////////////
                           setBondingCurveConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetBondingCurveConfig_OnlyTimelock_UpdatesFields() public {
        // Deploy a fresh registry and at least one curve so defaultCurveId=1 is valid
        BondingCurveRegistry newRegImpl = new BondingCurveRegistry();
        TransparentUpgradeableProxy newReg = new TransparentUpgradeableProxy(
            address(newRegImpl),
            users.admin,
            abi.encodeWithSelector(BondingCurveRegistry.initialize.selector, users.admin)
        );
        BondingCurveRegistry newRegInstance = BondingCurveRegistry(address(newReg));

        LinearCurve lc = new LinearCurve();
        TransparentUpgradeableProxy lcProxy = new TransparentUpgradeableProxy(
            address(lc), users.admin, abi.encodeWithSelector(LinearCurve.initialize.selector, "Linear")
        );

        resetPrank(users.admin);
        newRegInstance.addBondingCurve(address(lcProxy));

        // set to the fresh registry, default curve id 1
        BondingCurveConfig memory bc = BondingCurveConfig({ registry: address(newReg), defaultCurveId: 1 });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setBondingCurveConfig(bc);

        (address regAddr, uint256 defId) = protocol.multiVault.bondingCurveConfig();
        assertEq(regAddr, address(newReg));
        assertEq(defId, 1);
    }

    function testSetBondingCurveConfig_RevertWhen_NotTimelock() public {
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();
        bc.defaultCurveId = 2;

        resetPrank({ msgSender: users.charlie });
        _expectOnlyTimelock();
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    function testSetBondingCurveConfig_RevertWhen_DefaultCurveHasFeeHook() public {
        (address registry,) = protocol.multiVault.bondingCurveConfig();
        assertTrue(dynamicFeeCurve.hasDepositFeeHook(), "fixture curve must carry a deposit hook");

        BondingCurveConfig memory bc = BondingCurveConfig({ registry: registry, defaultCurveId: DYNAMIC_FEE_CURVE_ID });

        resetPrank({ msgSender: users.timelock });
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveHasFeeHook.selector);
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    function testSetBondingCurveConfig_RevertWhen_DefaultCurveNotRegistered() public {
        (address registry,) = protocol.multiVault.bondingCurveConfig();
        uint256 unregisteredId = 99;
        assertEq(BondingCurveRegistry(registry).curveAddresses(unregisteredId), address(0), "id must be free");

        BondingCurveConfig memory bc = BondingCurveConfig({ registry: registry, defaultCurveId: unregisteredId });

        resetPrank({ msgSender: users.timelock });
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveNotRegistered.selector);
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    function testSetBondingCurveConfig_RevertWhen_FreshRegistryDefaultHasFeeHook() public {
        // The hook check must resolve the curve through the registry being installed, not the
        // one currently stored: a fresh registry whose id 1 is a hook curve is rejected even
        // though id 1 in the live registry is the hookless linear curve.
        BondingCurveRegistry newRegImpl = new BondingCurveRegistry();
        TransparentUpgradeableProxy newReg = new TransparentUpgradeableProxy(
            address(newRegImpl),
            users.admin,
            abi.encodeWithSelector(BondingCurveRegistry.initialize.selector, users.admin)
        );
        BondingCurveRegistry newRegInstance = BondingCurveRegistry(address(newReg));

        resetPrank(users.admin);
        newRegInstance.addBondingCurve(address(dynamicFeeCurve));

        BondingCurveConfig memory bc = BondingCurveConfig({ registry: address(newReg), defaultCurveId: 1 });

        resetPrank({ msgSender: users.timelock });
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveHasFeeHook.selector);
        protocol.multiVault.setBondingCurveConfig(bc);

        (address regAddr, uint256 defId) = protocol.multiVault.bondingCurveConfig();
        assertTrue(regAddr != address(newReg), "rejected registry must not be stored");
        assertEq(defId, getDefaultCurveId(), "default curve id unchanged");
    }

    /// @dev Fresh registry whose id 1 is a {MockFeeHookCurve} with the given hook flags, so each
    ///      flag can be tested on its own rather than through a curve that sets both.
    function _freshRegistryWithMockDefault(bool depositHookEnabled, bool redeemHookEnabled)
        internal
        returns (address registry)
    {
        BondingCurveRegistry newRegImpl = new BondingCurveRegistry();
        TransparentUpgradeableProxy newReg = new TransparentUpgradeableProxy(
            address(newRegImpl),
            users.admin,
            abi.encodeWithSelector(BondingCurveRegistry.initialize.selector, users.admin)
        );

        MockFeeHookCurve mockImpl = new MockFeeHookCurve();
        // The mock reuses {LinearCurve.initialize} unchanged; the parent selector is the precise spelling.
        TransparentUpgradeableProxy mockProxy = new TransparentUpgradeableProxy(
            address(mockImpl), users.admin, abi.encodeWithSelector(LinearCurve.initialize.selector, "Mock Hook Curve")
        );
        MockFeeHookCurve(address(mockProxy)).setHooks(depositHookEnabled, redeemHookEnabled);

        resetPrank(users.admin);
        BondingCurveRegistry(address(newReg)).addBondingCurve(address(mockProxy));
        return address(newReg);
    }

    function testSetBondingCurveConfig_RevertWhen_DefaultCurveHasDepositHookOnly() public {
        address registry = _freshRegistryWithMockDefault(true, false);

        resetPrank({ msgSender: users.timelock });
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveHasFeeHook.selector);
        protocol.multiVault.setBondingCurveConfig(BondingCurveConfig({ registry: registry, defaultCurveId: 1 }));
    }

    function testSetBondingCurveConfig_RevertWhen_DefaultCurveHasRedeemHookOnly() public {
        address registry = _freshRegistryWithMockDefault(false, true);

        resetPrank({ msgSender: users.timelock });
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveHasFeeHook.selector);
        protocol.multiVault.setBondingCurveConfig(BondingCurveConfig({ registry: registry, defaultCurveId: 1 }));
    }

    function testSetBondingCurveConfig_AcceptsHooklessDefaultInFreshRegistry() public {
        address registry = _freshRegistryWithMockDefault(false, false);

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setBondingCurveConfig(BondingCurveConfig({ registry: registry, defaultCurveId: 1 }));

        (address regAddr, uint256 defId) = protocol.multiVault.bondingCurveConfig();
        assertEq(regAddr, registry, "hookless default accepted");
        assertEq(defId, 1);
    }

    /*////////////////////////////////////////////////////////////////////
                    initialize: same default-curve guard
    ////////////////////////////////////////////////////////////////////*/

    /// @dev Deploys an uninitialized MultiVault proxy and calls `initialize` with `bc`. The revert
    ///      expectation, when given, is armed immediately before the `initialize` call so it cannot
    ///      attach to the deployments above it.
    function _initializeFreshMultiVault(BondingCurveConfig memory bc, bytes4 expectedRevert) internal {
        MultiVault freshImpl = new MultiVault();
        MultiVault fresh =
            MultiVault(payable(address(new TransparentUpgradeableProxy(address(freshImpl), users.admin, ""))));
        if (expectedRevert != bytes4(0)) {
            vm.expectRevert(abi.encodeWithSelector(expectedRevert));
        }
        fresh.initialize(
            _getDefaultGeneralConfig(),
            _getDefaultAtomConfig(),
            _getDefaultTripleConfig(),
            _getDefaultWalletConfig(address(0)),
            _getDefaultVaultFees(),
            bc
        );
    }

    function testInitialize_RevertWhen_DefaultCurveHasFeeHook() public {
        (address registry,) = protocol.multiVault.bondingCurveConfig();

        _initializeFreshMultiVault(
            BondingCurveConfig({ registry: registry, defaultCurveId: DYNAMIC_FEE_CURVE_ID }),
            MultiVault.MultiVault_DefaultCurveHasFeeHook.selector
        );
    }

    function testInitialize_RevertWhen_DefaultCurveNotRegistered() public {
        (address registry,) = protocol.multiVault.bondingCurveConfig();

        _initializeFreshMultiVault(
            BondingCurveConfig({ registry: registry, defaultCurveId: 99 }),
            MultiVault.MultiVault_DefaultCurveNotRegistered.selector
        );
    }

    function testInitialize_AcceptsHooklessDefault() public {
        (address registry,) = protocol.multiVault.bondingCurveConfig();

        _initializeFreshMultiVault(BondingCurveConfig({ registry: registry, defaultCurveId: 1 }), bytes4(0));
    }

    /*////////////////////////////////////////////////////////////////////
                               setWalletConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetWalletConfig_OnlyTimelock_UpdatesFields() public {
        (address entryPoint, address atomWarden, address atomWalletBeacon, address atomWalletFactory) =
            protocol.multiVault.walletConfig();

        WalletConfig memory wc = WalletConfig({
            entryPoint: address(0xBEEF),
            atomWarden: address(0xCAFE),
            atomWalletBeacon: address(0xFEED),
            atomWalletFactory: atomWalletFactory // leave same
        });

        resetPrank({ msgSender: users.timelock });
        protocol.multiVault.setWalletConfig(wc);

        (address nEntry, address nWarden, address nBeacon, address nFactory) = protocol.multiVault.walletConfig();

        assertEq(nEntry, address(0xBEEF));
        assertEq(nWarden, address(0xCAFE));
        assertEq(nBeacon, address(0xFEED));
        assertEq(nFactory, atomWalletFactory);

        // Silence warnings for unused originals
        entryPoint;
        atomWarden;
        atomWalletBeacon;
    }

    function testSetWalletConfig_RevertWhen_NotTimelock() public {
        WalletConfig memory wc = _getDefaultWalletConfig(address(1));
        wc.entryPoint = address(0x99);

        resetPrank({ msgSender: users.bob });
        _expectOnlyTimelock();
        protocol.multiVault.setWalletConfig(wc);
    }
}
