// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

contract TrustBondingEpochMock {
    uint256 internal _currentEpochValue;

    function setCurrentEpoch(uint256 newEpoch) external {
        _currentEpochValue = newEpoch;
    }

    function currentEpoch() external view returns (uint256) {
        return _currentEpochValue;
    }
}

contract MultiVaultUtilizationHarness is MultiVault {
    function addUtilizationForTest(address user, int256 totalValue) external {
        _addUtilization(user, totalValue);
    }

    function removeUtilizationForTest(address user, int256 amountToRemove) external {
        _removeUtilization(user, amountToRemove);
    }

    function setTotalUtilizationForTest(uint256 epoch, int256 utilization) external {
        totalUtilization[epoch] = utilization;
    }
}

contract RolloverSystemUtilizationTest is Test {
    MultiVaultUtilizationHarness internal harness;
    TrustBondingEpochMock internal trustBondingEpochMock;

    function setUp() external {
        trustBondingEpochMock = new TrustBondingEpochMock();
        MultiVaultUtilizationHarness implementation = new MultiVaultUtilizationHarness();

        GeneralConfig memory generalConfig = GeneralConfig({
            admin: address(this),
            protocolMultisig: address(this),
            feeDenominator: 10_000,
            trustBonding: address(trustBondingEpochMock),
            minDeposit: 1,
            minShare: 1,
            atomDataMaxLength: 1,
            feeThreshold: 1
        });

        AtomConfig memory atomConfig = AtomConfig({ atomCreationProtocolFee: 0, atomWalletDepositFee: 0 });
        TripleConfig memory tripleConfig =
            TripleConfig({ tripleCreationProtocolFee: 0, atomDepositFractionForTriple: 0 });
        WalletConfig memory walletConfig = WalletConfig({
            entryPoint: address(1), atomWarden: address(1), atomWalletBeacon: address(1), atomWalletFactory: address(1)
        });
        VaultFees memory vaultFees = VaultFees({ entryFee: 0, exitFee: 0, protocolFee: 0 });
        BondingCurveConfig memory bondingCurveConfig = BondingCurveConfig({ registry: address(1), defaultCurveId: 1 });

        bytes memory initData = abi.encodeWithSelector(
            MultiVault.initialize.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig
        );
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), address(this), initData);
        harness = MultiVaultUtilizationHarness(payable(address(proxy)));
    }

    function test_rollover_systemUtilizationInitializedOncePerEpoch_afterZeroCrossing() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");

        trustBondingEpochMock.setCurrentEpoch(0);
        harness.addUtilizationForTest(alice, 1000);
        assertEq(harness.totalUtilization(0), 1000);

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 500);
        assertEq(harness.totalUtilization(1), 1500);

        harness.removeUtilizationForTest(bob, 1500);
        assertEq(harness.totalUtilization(1), 0);

        harness.addUtilizationForTest(charlie, 100);
        assertEq(harness.totalUtilization(1), 100);
    }

    function test_rollover_systemUtilizationCarriesPreviousEpoch_onFirstActionOnly() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        trustBondingEpochMock.setCurrentEpoch(0);
        harness.addUtilizationForTest(alice, 250);

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 50);
        assertEq(harness.totalUtilization(1), 300);

        harness.addUtilizationForTest(bob, 25);
        assertEq(harness.totalUtilization(1), 325);
    }

    function test_getHasRolledOverSystemUtilizationGetter_returnsExpectedValue() external {
        address alice = makeAddr("alice");

        assertEq(harness.hasRolledOverSystemUtilization(1), false);

        trustBondingEpochMock.setCurrentEpoch(0);
        harness.addUtilizationForTest(alice, 100);

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 1);

        assertEq(harness.hasRolledOverSystemUtilization(1), true);
    }

    function test_rollover_doesNotOverwriteCurrentEpochUtilization_whenAlreadyInitializedPreUpgrade() external {
        address alice = makeAddr("alice");

        // Simulate an upgrade into the new implementation mid-epoch:
        // current epoch utilization already exists, while the new rollover flag is still false.
        harness.setTotalUtilizationForTest(0, 1000);
        harness.setTotalUtilizationForTest(1, 777);

        trustBondingEpochMock.setCurrentEpoch(1);
        assertEq(harness.hasRolledOverSystemUtilization(1), false);

        harness.addUtilizationForTest(alice, 5);

        // Must preserve existing epoch utilization and only apply the new delta.
        assertEq(harness.totalUtilization(1), 782);
        assertEq(harness.hasRolledOverSystemUtilization(1), true);
    }
}
