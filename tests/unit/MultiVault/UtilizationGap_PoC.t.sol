// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

/**
 * @title  UtilizationGap_PoC
 * @notice Proof of concept: MultiVault's SYSTEM-WIDE utilization tracking (`totalUtilization`,
 *         gated by `hasRolledOverSystemUtilization`) silently resets its rollover baseline to 0
 *         after an idle gap of 2+ epochs with zero protocol-wide deposit/redeem activity --
 *         while PER-USER utilization tracking (`personalUtilization`, via the 3-slot
 *         `userEpochHistory` checkpoint and `getUserUtilizationInEpoch`) correctly survives the
 *         identical gap.
 *
 *         Root cause (MultiVault._rollover, internal): the system-wide branch only ever looks
 *         back exactly ONE epoch:
 *             uint256 previousEpoch = currentEpochLocal - 1;
 *             int256 previousEpochUtilization = totalUtilization[previousEpoch];
 *             if (previousEpochUtilization != 0 && totalUtilization[currentEpochLocal] == 0) {
 *                 totalUtilization[currentEpochLocal] = previousEpochUtilization;
 *             }
 *         If that one epoch is ALSO empty (0), the rollover gives up silently -- it never walks
 *         further back to find the last epoch that actually had a nonzero running total, unlike
 *         the per-user path.
 *
 *         Downstream impact: TrustBonding._getSystemUtilizationRatio(epoch) computes
 *             delta = totalUtilization[epoch] - totalUtilization[epoch - 1]
 *         via MultiVault.getTotalUtilizationForEpoch(), which is a NAIVE raw mapping read with NO
 *         checkpoint fallback at all (unlike getUserUtilizationInEpoch). After an idle gap,
 *         totalUtilization[epoch - 1] reads back as 0, so the next real deposit is measured as if
 *         it were 100% "new growth" from a zero baseline, instead of growth relative to the true
 *         prior running total. This artificially inflates the system utilization ratio, defeating
 *         its purpose of throttling reward emissions when real usage lags prior claims.
 */
contract UtilizationGap_PoC is BaseTest {
    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /// @notice Control case: existing suite behavior for a SINGLE-epoch gap (already covered by
    ///         UtilizationTest.t.sol) -- included here only to anchor the epoch-length assumption
    ///         used below (`14 days + 1`) before extending it to a multi-epoch gap.
    function test_control_singleEpochGap_carriesForwardCorrectly() public {
        bytes32 atomId = createSimpleAtom("poc-control", ATOM_COST[0], users.alice);

        uint256 epochN = protocol.multiVault.currentEpoch();
        uint256 amountN = 500 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN, 0);

        int256 sysN_total = protocol.multiVault.totalUtilization(epochN);
        assertGt(sysN_total, 0, "sanity: epoch N should have nonzero system utilization");

        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochN1 = protocol.multiVault.currentEpoch();
        assertEq(epochN1, epochN + 1, "sanity: single epoch advance");

        uint256 amountN1 = 10 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN1, 0);

        // Matches UtilizationTest.t.sol's existing, passing expectation for a 1-epoch gap.
        assertEq(
            protocol.multiVault.totalUtilization(epochN1),
            sysN_total + int256(amountN1),
            "control: single-epoch gap correctly carries the full prior total forward"
        );
    }

    /// @notice THE BUG: a 2+ epoch idle gap with zero system-wide activity causes
    ///         totalUtilization's rollover baseline to reset to 0, even though the true prior
    ///         running total was large and well-established.
    function test_bug_multiEpochIdleGap_resetsSystemUtilizationToZero() public {
        bytes32 atomId = createSimpleAtom("poc-bug", ATOM_COST[0], users.alice);

        // --- Epoch N: establish a large, real running utilization total ---
        uint256 epochN = protocol.multiVault.currentEpoch();
        uint256 bigDeposit = 5000 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, bigDeposit, 0);

        int256 sysN_total = protocol.multiVault.totalUtilization(epochN);
        console2.log("epoch N total utilization:");
        console2.logInt(sysN_total);
        assertGt(sysN_total, 0, "sanity: epoch N should have large nonzero system utilization");

        // --- Epochs N+1 and N+2: total silence, system-wide. No one deposits or redeems. ---
        vm.warp(block.timestamp + 14 days + 1); // -> epoch N+1, untouched
        vm.warp(block.timestamp + 14 days + 1); // -> epoch N+2, untouched
        uint256 epochN2 = protocol.multiVault.currentEpoch();
        assertEq(epochN2, epochN + 2, "sanity: advanced exactly 2 epochs with zero activity");

        // Confirm the intermediate epoch was genuinely never written on-chain.
        int256 rawAtN1 = protocol.multiVault.totalUtilization(epochN + 1);
        console2.log("raw totalUtilization[N+1] (never rolled over, naive read):");
        console2.logInt(rawAtN1);
        assertEq(rawAtN1, 0, "confirms totalUtilization[N+1] was never written by any rollover");

        // --- Epoch N+3: Alice makes a SMALL deposit, far smaller than her original 5000 ether ---
        vm.warp(block.timestamp + 14 days + 1); // -> epoch N+3
        uint256 epochN3 = protocol.multiVault.currentEpoch();

        uint256 smallDeposit = 100 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, smallDeposit, 0);

        int256 utilizationBefore = protocol.multiVault.getTotalUtilizationForEpoch(epochN3 - 1); // epoch N+2
        int256 utilizationAfter = protocol.multiVault.getTotalUtilizationForEpoch(epochN3); // epoch N+3

        console2.log("epoch N+3 utilizationBefore (epoch N+2, as TrustBonding reads it):");
        console2.logInt(utilizationBefore);
        console2.log("epoch N+3 utilizationAfter:");
        console2.logInt(utilizationAfter);

        // THE BUG: utilizationBefore reads as 0 -- the true prior running total (5000 ether,
        // established at epoch N) was silently forgotten, because the rollover only checked
        // exactly one epoch back (N+2), found it empty, and gave up instead of walking back to N.
        assertEq(
            utilizationBefore,
            0,
            "BUG: system utilization baseline silently reset to 0 after a multi-epoch idle gap, "
            "even though the true prior running total was 5000 ether (established at epoch N)"
        );

        // --- Contrast: the PER-USER checkpoint model does NOT suffer the same reset. ---
        int256 userUtilBefore = protocol.multiVault.getUserUtilizationInEpoch(users.alice, epochN3 - 1);
        console2.log("per-user getUserUtilizationInEpoch(alice, N+2) over the SAME gap:");
        console2.logInt(userUtilBefore);
        assertEq(
            userUtilBefore,
            int256(bigDeposit),
            "per-user tracking correctly preserves the true running total across the identical gap"
        );

        // Core asymmetry: identical idle gap, identical contract, two tracking mechanisms for
        // conceptually the same running total -- one is gap-safe (per-user), one is not (system).
        assertTrue(
            userUtilBefore != utilizationBefore,
            "ASYMMETRY: per-user utilization (correct, 5000 ether) diverges from system-wide "
            "utilization (incorrectly reset to 0) across the identical idle gap"
        );

        // Show the resulting distortion in the actual reward-throttling ratio TrustBonding uses.
        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(epochN3 - 1);
        console2.log("getSystemUtilizationRatio(epoch N+2), as read when claiming in epoch N+3:");
        console2.log(systemRatio);
    }
}
