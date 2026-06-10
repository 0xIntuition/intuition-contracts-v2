// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

/// @title  EmissionBudgetConservation
/// @notice Hypothesis 6 (deep pre-audit): emission-budget conservation.
///
/// Invariant under test: across all users and epochs, the sum of claimed rewards for any epoch is
/// bounded by that epoch's emissions budget, the budget is bounded by the controller's maximum
/// emissions (the system utilization ratio can only scale it DOWN, never up), and the epoch
/// boundary cannot enable a double-claim. The net-new angle over the existing single-user epoch
/// suite is: (a) multi-user sum conservation, (b) the budget<=maxEmissions ceiling under an
/// adversarially inflated system-utilization delta, (c) the floor under zero utilization, and
/// (d) the claim-time remaining-budget cap binding.
///
/// Verdict: DEFENDED. claimRewards caps every claim to the remaining per-epoch budget
/// (TrustBonding.sol:claimRewards) and the budget is `maxEmissions * ratio / 10000` with the ratio
/// in [lowerBound, 10000] (TrustBonding._emissionsForEpoch / _getSystemUtilizationRatio). All tests
/// below are negatives (no over-claim found); recorded with their defending mechanism.
contract EmissionBudgetConservationTest is TrustBondingBase {
    function setUp() public override {
        super.setUp();
        // Fund the emissions source so native reward transfers succeed.
        vm.deal(address(protocol.satelliteEmissionsController), 100_000_000 ether);
    }

    /// @dev Multiple users claiming the same epoch: the per-user ledger entries sum exactly to the
    ///      epoch total, and the total never exceeds the epoch emissions budget.
    function test_multiUserClaims_sumExactlyEqualsTotalAndStaysWithinBudget() external {
        _createLock(users.alice, 4000 ether);
        _createLock(users.bob, 2500 ether);
        _createLock(users.charlie, 1000 ether);

        uint256 prevEpoch = 0;
        vm.warp(protocol.trustBonding.epochTimestampEnd(prevEpoch) + 1);
        assertEq(protocol.trustBonding.currentEpoch(), 1, "claim window for epoch 0 is open");

        uint256 aliceExpected = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        uint256 bobExpected = protocol.trustBonding.getUserCurrentClaimableRewards(users.bob);
        uint256 charlieExpected = protocol.trustBonding.getUserCurrentClaimableRewards(users.charlie);
        assertGt(aliceExpected, 0, "precondition: alice has rewards");

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.bob);
        resetPrank(users.charlie);
        protocol.trustBonding.claimRewards(users.charlie);

        uint256 total = protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch);
        assertEq(
            total,
            aliceExpected + bobExpected + charlieExpected,
            "epoch total equals the sum of per-user ledger entries"
        );
        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch),
            aliceExpected,
            "alice ledger matches preview"
        );
        assertLe(total, protocol.trustBonding.emissionsForEpoch(prevEpoch), "budget invariant: total <= epoch budget");
    }

    /// @dev Adversarially inflate the system-utilization delta for a past epoch via direct storage
    ///      writes (the strongest possible attacker primitive — far beyond what real deposits can
    ///      churn). The budget must still cap at the controller's maximum emissions because the
    ///      ratio saturates at 100%.
    function test_inflatedSystemUtilization_capsBudgetAtMaxEmissions() external {
        vm.warp(protocol.trustBonding.epochTimestampEnd(1) + 1);
        uint256 epoch = 2;
        assertEq(protocol.trustBonding.currentEpoch(), epoch, "precondition: current epoch is 2");

        // Drive an enormous positive delta: utilization-before = 0, utilization-after = huge.
        // Target (totalClaimedRewardsForEpoch[epoch-1]) is 0, so any positive delta yields 100%.
        _setTotalUtilizationForEpoch(epoch - 1, 0);
        _setTotalUtilizationForEpoch(epoch, type(int128).max);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "ratio saturates at 100%, never above");

        uint256 maxEmissions =
            ICoreEmissionsController(address(protocol.satelliteEmissionsController)).getEmissionsAtEpoch(epoch);
        assertEq(
            protocol.trustBonding.emissionsForEpoch(epoch),
            maxEmissions,
            "inflated utilization cannot push the budget above the controller maximum"
        );
        assertEq(
            protocol.trustBonding.emissionsForEpoch(epoch),
            maxEmissions * ratio / BASIS_POINTS_DIVISOR,
            "budget == maxEmissions * ratio / 10000"
        );
    }

    /// @dev With no net utilization in an epoch, the ratio floors at the configured lower bound and
    ///      the budget is strictly below the maximum — the opposite extreme of the inflation case.
    function test_zeroSystemUtilization_floorsBudgetAtLowerBound() external {
        vm.warp(protocol.trustBonding.epochTimestampEnd(1) + 1);
        uint256 epoch = 2;

        // Equal before/after => delta == 0 => floor.
        _setTotalUtilizationForEpoch(epoch - 1, 1000 ether);
        _setTotalUtilizationForEpoch(epoch, 1000 ether);

        uint256 lowerBound = protocol.trustBonding.systemUtilizationLowerBound();
        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);
        assertEq(ratio, lowerBound, "zero-delta floors at the system lower bound");
        assertLt(ratio, BASIS_POINTS_DIVISOR, "floor is strictly below 100%");

        uint256 maxEmissions =
            ICoreEmissionsController(address(protocol.satelliteEmissionsController)).getEmissionsAtEpoch(epoch);
        assertEq(
            protocol.trustBonding.emissionsForEpoch(epoch),
            maxEmissions * lowerBound / BASIS_POINTS_DIVISOR,
            "budget == maxEmissions * lowerBound / 10000"
        );
    }

    /// @dev When the epoch budget is nearly exhausted, a claim is capped to exactly the remaining
    ///      budget; the user cannot pull more than what is left and the total lands exactly on the
    ///      budget ceiling.
    function test_claim_cappedToRemainingBudget() external {
        _createLock(users.alice, 5000 ether);

        uint256 prevEpoch = 0;
        vm.warp(protocol.trustBonding.epochTimestampEnd(prevEpoch) + 1);

        uint256 budget = protocol.trustBonding.emissionsForEpoch(prevEpoch);
        uint256 remainder = 1234 wei;
        // Pre-fill the epoch's claimed total to leave only `remainder` of budget.
        _setTotalClaimedRewardsForEpoch(prevEpoch, budget - remainder);

        uint256 rawClaimable = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertGt(rawClaimable, remainder, "precondition: alice would otherwise claim more than remains");

        uint256 balanceBefore = users.alice.balance;
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(users.alice.balance - balanceBefore, remainder, "claim capped to remaining budget");
        assertEq(
            protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch),
            budget,
            "total lands exactly on the budget ceiling, never above"
        );
    }

    /// @dev A second claim for the same already-claimed epoch reverts; the epoch boundary does not
    ///      reopen a claimed epoch.
    function test_doubleClaim_sameEpochReverts() external {
        _createLock(users.alice, 3000 ether);
        vm.warp(protocol.trustBonding.epochTimestampEnd(0) + 1);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        vm.expectRevert(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector);
        protocol.trustBonding.claimRewards(users.alice);
    }

    /// @dev Fuzzed lock sizes for two users: regardless of relative stake, the epoch total stays
    ///      within budget and equals the sum of the two ledger entries.
    function testFuzz_twoUserClaims_neverExceedEpochBudget(uint256 aliceLock, uint256 bobLock) external {
        aliceLock = bound(aliceLock, 1 ether, 8000 ether);
        bobLock = bound(bobLock, 1 ether, 8000 ether);

        _createLock(users.alice, aliceLock);
        _createLock(users.bob, bobLock);

        uint256 prevEpoch = 0;
        vm.warp(protocol.trustBonding.epochTimestampEnd(prevEpoch) + 1);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.bob);

        uint256 total = protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch);
        assertEq(
            total,
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch)
                + protocol.trustBonding.userClaimedRewardsForEpoch(users.bob, prevEpoch),
            "total equals sum of ledger entries"
        );
        assertLe(total, protocol.trustBonding.emissionsForEpoch(prevEpoch), "total stays within budget");
    }
}
