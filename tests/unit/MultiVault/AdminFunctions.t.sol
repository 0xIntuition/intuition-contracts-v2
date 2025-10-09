// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

contract MultiVaultAdminFunctionsTest is BaseTest {
    /// @dev Define a reusable GeneralConfig struct for tests to avoid stack too deep
    GeneralConfig public gc;

    /*////////////////////////////////////////////////////////////////////
                                INTERNAL HELPERS
    ////////////////////////////////////////////////////////////////////*/

    function _expectUnauthorized(address caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                caller,
                protocol.multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
    }

    /*////////////////////////////////////////////////////////////////////
                                  PAUSE / UNPAUSE
    ////////////////////////////////////////////////////////////////////*/

    function testPause_OnlyAdmin_SetsPausedAndBlocksDeposit() public {
        // pause as admin
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

    function testPause_RevertWhen_CalledByNonAdmin() public {
        resetPrank({ msgSender: users.alice });
        _expectUnauthorized(users.alice);
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
        // (default curve already exists; deposit into default curve works)
        bytes32 atomId = createSimpleAtom("admin-atom", getAtomCreationCost(), users.admin);

        // Alice deposits into default curve (onlySelf approval OK)
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
        _expectUnauthorized(users.bob);
        protocol.multiVault.unpause();
    }

    /*////////////////////////////////////////////////////////////////////
                               setGeneralConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetGeneralConfig_OnlyAdmin_UpdatesFields() public {
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

        resetPrank({ msgSender: users.admin });
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

    function testSetGeneralConfig_RevertWhen_NonAdmin() public {
        // Craft a dummy config
        GeneralConfig memory generalConfig = _getDefaultGeneralConfig();
        generalConfig.protocolMultisig = users.bob;

        resetPrank({ msgSender: users.alice });
        _expectUnauthorized(users.alice);
        protocol.multiVault.setGeneralConfig(generalConfig);
    }

    /*////////////////////////////////////////////////////////////////////
                               setAtomConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetAtomConfig_OnlyAdmin_UpdatesFields() public {
        (uint256 creationFee, uint256 walletDepositFee) = protocol.multiVault.atomConfig();

        AtomConfig memory ac =
            AtomConfig({ atomCreationProtocolFee: creationFee + 123, atomWalletDepositFee: walletDepositFee + 5 });

        resetPrank({ msgSender: users.admin });
        protocol.multiVault.setAtomConfig(ac);

        (uint256 newCreationFee, uint256 newWalletDepositFee) = protocol.multiVault.atomConfig();
        assertEq(newCreationFee, creationFee + 123);
        assertEq(newWalletDepositFee, walletDepositFee + 5);
    }

    function testSetAtomConfig_RevertWhen_NonAdmin() public {
        AtomConfig memory ac = _getDefaultAtomConfig();
        ac.atomWalletDepositFee = ac.atomWalletDepositFee + 1;

        resetPrank({ msgSender: users.charlie });
        _expectUnauthorized(users.charlie);
        protocol.multiVault.setAtomConfig(ac);
    }

    /*////////////////////////////////////////////////////////////////////
                               setTripleConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetTripleConfig_OnlyAdmin_UpdatesFields() public {
        (uint256 creationFee, uint256 staticAtomDeposits, uint256 atomDepositFrac) = protocol.multiVault.tripleConfig();

        TripleConfig memory tc = TripleConfig({
            tripleCreationProtocolFee: creationFee + 1,
            totalAtomDepositsOnTripleCreation: staticAtomDeposits + 2,
            atomDepositFractionForTriple: atomDepositFrac + 3
        });

        resetPrank({ msgSender: users.admin });
        protocol.multiVault.setTripleConfig(tc);

        (uint256 nCreationFee, uint256 nStaticDeposits, uint256 nFrac) = protocol.multiVault.tripleConfig();
        assertEq(nCreationFee, creationFee + 1);
        assertEq(nStaticDeposits, staticAtomDeposits + 2);
        assertEq(nFrac, atomDepositFrac + 3);
    }

    function testSetTripleConfig_RevertWhen_NonAdmin() public {
        TripleConfig memory tc = _getDefaultTripleConfig();
        tc.atomDepositFractionForTriple = tc.atomDepositFractionForTriple + 1;

        resetPrank({ msgSender: users.alice });
        _expectUnauthorized(users.alice);
        protocol.multiVault.setTripleConfig(tc);
    }

    /*////////////////////////////////////////////////////////////////////
                               setVaultFees (+ fuzz)
    ////////////////////////////////////////////////////////////////////*/

    function testSetVaultFees_OnlyAdmin_UpdatesFields() public {
        (uint256 entryFee, uint256 exitFee, uint256 protocolFee) = protocol.multiVault.vaultFees();

        VaultFees memory vf = VaultFees({ entryFee: entryFee + 7, exitFee: exitFee + 9, protocolFee: protocolFee + 11 });

        resetPrank({ msgSender: users.admin });
        protocol.multiVault.setVaultFees(vf);

        (uint256 nEntry, uint256 nExit, uint256 nProt) = protocol.multiVault.vaultFees();
        assertEq(nEntry, entryFee + 7);
        assertEq(nExit, exitFee + 9);
        assertEq(nProt, protocolFee + 11);
    }

    function testSetVaultFees_RevertWhen_NonAdmin() public {
        VaultFees memory vf = _getDefaultVaultFees();
        vf.protocolFee = vf.protocolFee + 1;

        resetPrank({ msgSender: users.bob });
        _expectUnauthorized(users.bob);
        protocol.multiVault.setVaultFees(vf);
    }

    function testFuzz_SetVaultFees_OnlyAdmin(uint16 entryFee, uint16 exitFee, uint16 protocolFee) public {
        // Bound to sensible ranges (<= fee denominator)
        uint256 denom = FEE_DENOMINATOR;
        uint256 e = uint256(entryFee) % (denom + 1);
        uint256 x = uint256(exitFee) % (denom + 1);
        uint256 p = uint256(protocolFee) % (denom + 1);

        VaultFees memory vf = VaultFees({ entryFee: e, exitFee: x, protocolFee: p });

        resetPrank({ msgSender: users.admin });
        protocol.multiVault.setVaultFees(vf);

        (uint256 ne, uint256 nx, uint256 np) = protocol.multiVault.vaultFees();
        assertEq(ne, e);
        assertEq(nx, x);
        assertEq(np, p);
    }

    /*////////////////////////////////////////////////////////////////////
                           setBondingCurveConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetBondingCurveConfig_OnlyAdmin_UpdatesFields() public {
        // Deploy a fresh registry and at least one curve so defaultCurveId=1 is valid
        BondingCurveRegistry newReg = new BondingCurveRegistry(users.admin);
        resetPrank(users.admin);
        newReg.addBondingCurve(address(new LinearCurve("Linear")));
        // set to the fresh registry, default curve id 1
        BondingCurveConfig memory bc = BondingCurveConfig({ registry: address(newReg), defaultCurveId: 1 });

        protocol.multiVault.setBondingCurveConfig(bc);

        (address regAddr, uint256 defId) = protocol.multiVault.bondingCurveConfig();
        assertEq(regAddr, address(newReg));
        assertEq(defId, 1);
    }

    function testSetBondingCurveConfig_RevertWhen_NonAdmin() public {
        BondingCurveConfig memory bc = _getDefaultBondingCurveConfig();
        bc.defaultCurveId = 2;

        resetPrank({ msgSender: users.charlie });
        _expectUnauthorized(users.charlie);
        protocol.multiVault.setBondingCurveConfig(bc);
    }

    /*////////////////////////////////////////////////////////////////////
                               setWalletConfig
    ////////////////////////////////////////////////////////////////////*/

    function testSetWalletConfig_OnlyAdmin_UpdatesFields() public {
        (address entryPoint, address atomWarden, address atomWalletBeacon, address atomWalletFactory) =
            protocol.multiVault.walletConfig();

        WalletConfig memory wc = WalletConfig({
            entryPoint: address(0xBEEF),
            atomWarden: address(0xCAFE),
            atomWalletBeacon: address(0xFEED),
            atomWalletFactory: atomWalletFactory // leave same
         });

        resetPrank({ msgSender: users.admin });
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

    function testSetWalletConfig_RevertWhen_NonAdmin() public {
        WalletConfig memory wc = _getDefaultWalletConfig(address(1));
        wc.entryPoint = address(0x99);

        resetPrank({ msgSender: users.bob });
        _expectUnauthorized(users.bob);
        protocol.multiVault.setWalletConfig(wc);
    }
}
