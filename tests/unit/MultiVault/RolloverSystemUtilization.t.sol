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
    function addUtilizationForTest(address user, int256 assets) external {
        _addUtilization(user, assets);
    }

    function removeUtilizationForTest(address user, int256 assets) external {
        _removeUtilization(user, assets);
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

    /*//////////////////////////////////////////////////////////////
            NO-ACTIVITY EPOCH DEFENSE — gap-spanning rollover
    //////////////////////////////////////////////////////////////*/

    /// @dev Activity at epoch 1, then a 1-epoch silent gap (epoch 2), then activity at epoch 3.
    ///      The fix carries `totalUtilization[1]` directly into `totalUtilization[3]` via the
    ///      `lastSystemUtilizationEpoch` slot. Intermediate epoch 2 stays at zero — this is
    ///      snap-forward, not walk-fill.
    function test_rollover_carriesAcrossSingleEpochGap() external {
        address alice = makeAddr("alice");

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 100);
        assertEq(harness.totalUtilization(1), 100);
        assertEq(harness.lastSystemUtilizationEpoch(), 1);

        trustBondingEpochMock.setCurrentEpoch(3);
        harness.addUtilizationForTest(alice, 0);

        assertEq(harness.totalUtilization(3), 100, "carry across single-epoch gap");
        assertEq(harness.totalUtilization(2), 0, "intermediate epoch untouched (snap-forward)");
        assertEq(harness.hasRolledOverSystemUtilization(3), true);
        assertEq(harness.hasRolledOverSystemUtilization(2), false);
        assertEq(harness.lastSystemUtilizationEpoch(), 3);
    }

    /// @dev Activity at epoch 1, then 3 silent epochs (2,3,4), then activity at epoch 5.
    ///      Pre-fix this lost the carry; the fix preserves it.
    function test_rollover_carriesAcrossMultiEpochGap() external {
        address alice = makeAddr("alice");

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 100);
        assertEq(harness.lastSystemUtilizationEpoch(), 1);

        trustBondingEpochMock.setCurrentEpoch(5);
        harness.addUtilizationForTest(alice, 0);

        assertEq(harness.totalUtilization(5), 100, "carry across multi-epoch gap");
        assertEq(harness.totalUtilization(2), 0);
        assertEq(harness.totalUtilization(3), 0);
        assertEq(harness.totalUtilization(4), 0);
        assertEq(harness.hasRolledOverSystemUtilization(2), false);
        assertEq(harness.hasRolledOverSystemUtilization(3), false);
        assertEq(harness.hasRolledOverSystemUtilization(4), false);
        assertEq(harness.hasRolledOverSystemUtilization(5), true);
        assertEq(harness.lastSystemUtilizationEpoch(), 5);
    }

    /// @dev `lastSystemUtilizationEpoch` is written exactly once per epoch — only on the
    ///      first `_rollover` call. Subsequent same-epoch calls hit the `hasRolledOver`
    ///      early-exit and pay zero SSTOREs against the new slot.
    function test_rollover_lastSystemUtilizationEpochUpdatedOnFirstCallOnly() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, 100);
        assertEq(harness.lastSystemUtilizationEpoch(), 1);

        trustBondingEpochMock.setCurrentEpoch(2);
        harness.addUtilizationForTest(alice, 50);
        assertEq(harness.lastSystemUtilizationEpoch(), 2);

        harness.addUtilizationForTest(bob, 25);
        assertEq(harness.lastSystemUtilizationEpoch(), 2, "no re-write within the same epoch");

        harness.addUtilizationForTest(alice, 10);
        assertEq(harness.lastSystemUtilizationEpoch(), 2);
    }

    /// @dev `MultiVault.reinitialize` pre-seeds `lastSystemUtilizationEpoch` to the current
    ///      epoch at upgrade time. This is what guarantees every post-upgrade `_rollover`
    ///      reads a meaningful source — there is no `== 0` sentinel branch in `_rollover`.
    function test_rollover_reinitializerPreSeedsLastSystemUtilizationEpoch() external {
        // Pretend the upgrade lands at epoch 7 by advancing the mock before the operator
        // calls `reinitialize`.
        trustBondingEpochMock.setCurrentEpoch(7);
        assertEq(harness.lastSystemUtilizationEpoch(), 0, "uninitialised pre-reinitialize");

        harness.reinitialize(makeAddr("timelock"));

        assertEq(harness.lastSystemUtilizationEpoch(), 7, "reinitialize pre-seeds the slot to currentEpoch()");
    }

    /// @dev End-to-end: pre-upgrade utilization at epoch K, operator calls `reinitialize` at
    ///      epoch K, protocol then goes silent across several epochs. The carry must source
    ///      from K — not from the silent gap epoch immediately before currentEpoch.
    function test_rollover_carriesAcrossGapAfterReinitializerPreSeed() external {
        address alice = makeAddr("alice");

        // Stage 1: simulate pre-upgrade activity at epoch 7.
        trustBondingEpochMock.setCurrentEpoch(7);
        harness.setTotalUtilizationForTest(7, 1234);

        // Stage 2: operator calls reinitialize at the same epoch as part of the upgrade.
        harness.reinitialize(makeAddr("timelock"));
        assertEq(harness.lastSystemUtilizationEpoch(), 7);

        // Stage 3: protocol falls silent across epochs 8–11, first activity at epoch 12.
        trustBondingEpochMock.setCurrentEpoch(12);
        harness.addUtilizationForTest(alice, 0);

        assertEq(harness.totalUtilization(12), 1234, "carry sourced from reinitializer pre-seed");
        assertEq(harness.lastSystemUtilizationEpoch(), 12);
        assertEq(harness.hasRolledOverSystemUtilization(12), true);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_rollover_carriesAcrossArbitraryGap(uint256 gap, uint128 utilizationSeed) external {
        gap = bound(gap, 1, 256);
        vm.assume(utilizationSeed > 0);
        address alice = makeAddr("alice");

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.setTotalUtilizationForTest(1, int256(uint256(utilizationSeed)));
        // Trigger _rollover with a zero delta so `totalUtilization[1]` is preserved exactly
        // (the rollover branch sets `lastSystemUtilizationEpoch = 1` without overwriting the
        // already-non-zero current epoch).
        harness.addUtilizationForTest(alice, 0);
        assertEq(harness.totalUtilization(1), int256(uint256(utilizationSeed)));
        assertEq(harness.lastSystemUtilizationEpoch(), 1);

        uint256 nextEpoch = 1 + gap;
        trustBondingEpochMock.setCurrentEpoch(nextEpoch);
        harness.addUtilizationForTest(alice, 0);

        assertEq(harness.totalUtilization(nextEpoch), int256(uint256(utilizationSeed)));
        assertEq(harness.lastSystemUtilizationEpoch(), nextEpoch);
        assertEq(harness.hasRolledOverSystemUtilization(nextEpoch), true);
    }

    function testFuzz_rollover_idempotentWithinEpoch(uint128 utilizationSeed, uint8 calls) external {
        calls = uint8(bound(calls, 1, 16));
        vm.assume(utilizationSeed > 0);
        address alice = makeAddr("alice");

        trustBondingEpochMock.setCurrentEpoch(1);
        harness.addUtilizationForTest(alice, int256(uint256(utilizationSeed)));
        assertEq(harness.lastSystemUtilizationEpoch(), 1);

        for (uint256 i = 0; i < calls; i++) {
            harness.addUtilizationForTest(alice, 0);
            assertEq(harness.lastSystemUtilizationEpoch(), 1, "slot stable within epoch");
        }
    }
}
