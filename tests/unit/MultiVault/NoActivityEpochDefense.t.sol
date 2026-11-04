// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";

/// @title  NoActivityEpochDefenseTest
/// @notice End-to-end scenario for the multi-epoch quiescence carry-forward defense.
/// @dev    Runs against the real `deposit` / `redeem` entry points via {BaseTest}'s helpers
///         (not the unit-level harness in {RolloverSystemUtilization.t.sol}). Reinitializer
///         pre-seed semantics — the upgrade-transition path that bootstraps the
///         `lastSystemUtilizationEpoch` slot — are covered at the harness level; this file
///         covers the steady-state gap behaviour that real users observe post-upgrade.
contract NoActivityEpochDefenseTest is BaseTest {
    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /// @dev Alice seeds utilization at epoch N. Protocol falls silent for several epochs.
    ///      Bob's deposit at epoch N+gap must see Alice's utilization carried forward into
    ///      its own epoch — pre-fix the carry was lost because `_rollover` read from
    ///      `currentEpoch - 1` (which was zero across the gap).
    function test_scenario_MultiEpochQuiescenceThenDeposit() external {
        // BaseTest deploys at `block.timestamp == 0`, where TrustBonding reports
        // `currentEpoch() == 0`. The pre-existing `currentEpochLocal > 0` guard in
        // `_rollover` means epoch 0 never writes `lastSystemUtilizationEpoch`, so any
        // activity-at-epoch-0 followed by a gap relies on the sentinel fallback rather
        // than the new slot. Step out of epoch 0 so this scenario exercises the new
        // path end-to-end. The umbrella's "worst-case gap is bounded" framing is the
        // real-world reason this is fine: the protocol starts producing utilization at
        // epoch >= 1 in any meaningful deployment.
        vm.warp(block.timestamp + 14 days + 1);

        bytes32 atomId = createSimpleAtom("gap-defense", ATOM_COST[0], users.alice);

        uint256 epochN = protocol.multiVault.currentEpoch();
        assertGt(epochN, 0, "test must seed activity at epoch >= 1");
        int256 totalAfterCreate = protocol.multiVault.totalUtilization(epochN);
        assertGt(totalAfterCreate, int256(0), "atom creation must produce utilization");

        uint256 depositA = 3 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, depositA, 0);
        int256 totalAtN = protocol.multiVault.totalUtilization(epochN);
        assertEq(totalAtN, totalAfterCreate + int256(depositA), "alice deposit lands in epoch N");
        assertEq(
            protocol.multiVault.lastSystemUtilizationEpoch(),
            epochN,
            "lastSystemUtilizationEpoch tracks epoch N after first activity"
        );

        // Fast-forward several epochs without any protocol activity. 5 * 14 days clears at
        // least 4 full epoch boundaries (BaseTest configures TrustBonding with 14-day epochs).
        vm.warp(block.timestamp + 5 * 14 days + 1);
        uint256 epochM = protocol.multiVault.currentEpoch();
        assertGt(epochM - epochN, 1, "gap must span more than one epoch to exercise the fix");

        // Pre-fix this would observe `totalUtilization[epochM] == 0` because the rollover
        // read `totalUtilization[epochM - 1]` (=0 inside the quiescent gap).
        uint256 depositB = 2 ether;
        makeDeposit(users.bob, users.bob, atomId, CURVE_ID, depositB, 0);

        int256 totalAtM = protocol.multiVault.totalUtilization(epochM);
        assertEq(totalAtM, totalAtN + int256(depositB), "carry across gap + bob's deposit");
        assertEq(
            protocol.multiVault.lastSystemUtilizationEpoch(), epochM, "lastSystemUtilizationEpoch advances to epoch M"
        );
        assertTrue(protocol.multiVault.hasRolledOverSystemUtilization(epochM), "rollover flag set for epoch M");

        // Intermediate epochs remain at zero — snap-forward, not walk-fill. Documents the
        // chosen design relative to the rejected walk-back variant from D3.
        for (uint256 e = epochN + 1; e < epochM; e++) {
            assertEq(protocol.multiVault.totalUtilization(e), int256(0), "intermediate epoch utilization unchanged");
            assertFalse(
                protocol.multiVault.hasRolledOverSystemUtilization(e), "intermediate epoch rollover flag stays false"
            );
        }

        // Advance one more epoch (a single-step transition from the tracked slot). The carry
        // must continue to work — `lastSystemUtilizationEpoch` is now `epochM`, not zero, so
        // the sentinel fallback is not triggered.
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochL = protocol.multiVault.currentEpoch();
        assertEq(epochL, epochM + 1, "single-step advance");

        // Charlie has no position to redeem, so use a small deposit instead to trigger rollover.
        uint256 depositC = 1 ether;
        makeDeposit(users.charlie, users.charlie, atomId, CURVE_ID, depositC, 0);
        assertEq(
            protocol.multiVault.totalUtilization(epochL),
            totalAtM + int256(depositC),
            "single-step carry continues from tracked slot"
        );
        assertEq(protocol.multiVault.lastSystemUtilizationEpoch(), epochL);
    }

    function test_scenario_MultiEpochQuiescenceThenPartialRedeem() external {
        vm.warp(block.timestamp + TRUST_BONDING_EPOCH_LENGTH + 1);

        bytes32 atomId = createSimpleAtom("gap-defense-redeem", ATOM_COST[0], users.alice);
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 4 ether, 0);

        uint256 epochN = protocol.multiVault.currentEpoch();
        int256 totalAtN = protocol.multiVault.totalUtilization(epochN);
        int256 personalAtN = protocol.multiVault.personalUtilization(users.alice, epochN);
        assertGt(totalAtN, int256(0), "epoch N must have system utilization");
        assertGt(personalAtN, int256(0), "epoch N must have personal utilization");

        vm.warp(block.timestamp + 5 * TRUST_BONDING_EPOCH_LENGTH + 1);
        uint256 epochM = protocol.multiVault.currentEpoch();
        assertGt(epochM - epochN, 1, "gap must span multiple epochs");

        uint256 sharesToRedeem = shares / 2;
        uint256 rawAssets = convertToAssets(sharesToRedeem, atomId, CURVE_ID);
        redeemShares(users.alice, users.alice, atomId, CURVE_ID, sharesToRedeem, 0);

        assertEq(
            protocol.multiVault.totalUtilization(epochM),
            totalAtN - int256(rawAssets),
            "system utilization must carry before subtraction"
        );
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epochM),
            personalAtN - int256(rawAssets),
            "personal utilization must carry before subtraction"
        );
        assertEq(protocol.multiVault.userEpochHistory(users.alice, 0), epochM, "current epoch must lead history");
        assertEq(protocol.multiVault.userEpochHistory(users.alice, 1), epochN, "prior active epoch must shift");
        assertEq(protocol.multiVault.userEpochHistory(users.alice, 2), 0, "oldest history slot remains empty");
        assertEq(protocol.multiVault.lastSystemUtilizationEpoch(), epochM, "system epoch must advance");
        assertTrue(protocol.multiVault.hasRolledOverSystemUtilization(epochM), "epoch M must be rolled over");

        for (uint256 epoch = epochN + 1; epoch < epochM; epoch++) {
            assertEq(protocol.multiVault.totalUtilization(epoch), int256(0), "intermediate utilization stays empty");
            assertFalse(
                protocol.multiVault.hasRolledOverSystemUtilization(epoch), "intermediate rollover flag stays false"
            );
        }

        vm.warp(block.timestamp + TRUST_BONDING_EPOCH_LENGTH + 1);
        uint256 inactiveEpoch = protocol.multiVault.currentEpoch();
        assertEq(inactiveEpoch, epochM + 1, "must advance one inactive epoch");
        assertEq(
            protocol.trustBonding.getSystemUtilizationRatio(inactiveEpoch),
            protocol.trustBonding.systemUtilizationLowerBound(),
            "an inactive epoch must use the system utilization floor"
        );
    }
}
