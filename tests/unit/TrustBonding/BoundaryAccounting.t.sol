// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

contract BoundaryAccountingTest is TrustBondingBase {
    event RewardsClaimed(address indexed user, address indexed recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    EPOCH BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice CoreEmissionsController now returns epochTimestampEnd(N) as the last second
    ///         of epoch N (closed interval [start, end]). A lock at epochTimestampEnd(N)
    ///         is a legitimate epoch-N action and MUST be included in the epoch-N snapshot.
    function test_totalBondedBalanceAtEpochEnd_includesLockAtEpochEnd() external {
        _createLock(users.alice, initialTokens);

        uint256 targetEpoch = 0;
        uint256 epochEnd = protocol.trustBonding.epochTimestampEnd(targetEpoch);

        vm.warp(epochEnd);
        uint256 totalBefore = protocol.trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        _createLock(users.bob, initialTokens);

        uint256 bobBalanceAtEpochEnd = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.bob, targetEpoch);
        uint256 totalAfter = protocol.trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        assertGt(bobBalanceAtEpochEnd, 0, "lock at epoch end must be included (legitimate participation)");
        assertGt(totalAfter, totalBefore, "total must increase for epoch-end lock");
    }

    /// @notice S-112 core protection: a lock at epochTimestampEnd(N) + 1 is the first second
    ///         of epoch N+1 and must NOT be included in epoch N's reward snapshot.
    function test_totalBondedBalanceAtEpochEnd_excludesNextEpochStartLock() external {
        _createLock(users.alice, initialTokens);

        uint256 targetEpoch = 0;
        uint256 nextEpochStart = protocol.trustBonding.epochTimestampEnd(targetEpoch) + 1;

        vm.warp(nextEpochStart);
        uint256 totalBefore = protocol.trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        _createLock(users.bob, initialTokens);

        uint256 bobBalanceAtEpochEnd = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.bob, targetEpoch);
        uint256 bobRewardsAtEpochEnd = protocol.trustBonding.userEligibleRewardsForEpoch(users.bob, targetEpoch);
        uint256 totalAfter = protocol.trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        assertEq(bobBalanceAtEpochEnd, 0, "next-epoch-start lock must be excluded from closed epoch");
        assertEq(bobRewardsAtEpochEnd, 0, "next-epoch-start lock must have no prior-epoch rewards");
        assertEq(totalAfter, totalBefore, "total must remain immutable after epoch end");
    }

    /// @notice Verify that epochTimestampEnd(N) + 1 == epochTimestampStart(N+1),
    ///         proving no timestamp overlap between adjacent epochs.
    function test_epochBoundaries_noOverlap() external view {
        ICoreEmissionsController controller =
            ICoreEmissionsController(protocol.trustBonding.satelliteEmissionsController());

        for (uint256 epoch = 0; epoch < 5; epoch++) {
            uint256 epochEnd = controller.getEpochTimestampEnd(epoch);
            uint256 nextEpochStart = controller.getEpochTimestampStart(epoch + 1);
            assertEq(epochEnd + 1, nextEpochStart, "epoch boundaries must be contiguous with no overlap");

            // Boundary timestamp belongs to current epoch
            assertEq(controller.getEpochAtTimestamp(epochEnd), epoch, "epoch end must belong to current epoch");
            assertEq(controller.getEpochAtTimestamp(epochEnd + 1), epoch + 1, "epochEnd+1 must belong to next epoch");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    BUDGET GUARDRAIL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_clampsToRemainingBudget_whenRemainingIsLessThanUserRewards() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        uint256 previousEpoch = 0;
        uint256 userRewardsWithoutCap = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, previousEpoch);

        // Assert the user's eligible reward exceeds the remaining budget (1 wei),
        // proving the clamp will actually reduce the payout.
        assertGt(userRewardsWithoutCap, 1, "Eligible rewards should exceed remaining budget before clamping");

        _setTotalClaimedRewardsForEpoch(previousEpoch, userRewardsWithoutCap - 1);

        uint256 aliceBalanceBefore = users.alice.balance;

        vm.expectEmit(true, true, false, true);
        emit RewardsClaimed(users.alice, users.alice, 1);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(previousEpoch);
        uint256 totalClaimed = protocol.trustBonding.totalClaimedRewardsForEpoch(previousEpoch);

        assertEq(users.alice.balance, aliceBalanceBefore + 1);
        assertEq(protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, previousEpoch), 1);
        assertEq(totalClaimed, epochBudget);
        assertLe(totalClaimed, epochBudget);
    }

    function test_claimRewards_revertsWhenEpochBudgetAlreadyExhausted() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        uint256 previousEpoch = 0;
        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(previousEpoch);
        _setTotalClaimedRewardsForEpoch(previousEpoch, epochBudget);

        vm.expectRevert(ITrustBonding.TrustBonding_EpochBudgetExhausted.selector);
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
    }

    /// @notice After Alice claims full budget, Bob locks at the start of the next epoch and tries
    ///         to claim.  Bob has zero eligible rewards for the closing epoch (his lock is excluded
    ///         from the epoch's snapshot), so he gets NoRewardsToClaim.
    function test_claimRewards_revertsWhenNextEpochStartLockHasNoEligibleRewards() external {
        _createLock(users.alice, initialTokens);

        uint256 targetEpoch = 1;
        uint256 nextEpochStart = protocol.trustBonding.epochTimestampEnd(targetEpoch) + 1;

        vm.warp(nextEpochStart);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        _createLock(users.bob, initialTokens);

        // Bob's lock at next-epoch-start is excluded from epoch 1's snapshot — no rewards.
        vm.expectRevert(ITrustBonding.TrustBonding_NoRewardsToClaim.selector);
        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.bob);

        uint256 totalClaimed = protocol.trustBonding.totalClaimedRewardsForEpoch(targetEpoch);
        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(targetEpoch);
        assertEq(totalClaimed, epochBudget);
        assertLe(totalClaimed, epochBudget);
    }

    /*//////////////////////////////////////////////////////////////
                    S-595 REGRESSION TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Regression test for S-595: proves that correct epoch boundaries prevent
    ///         share inflation.  Locks at the start of the next epoch have zero eligible
    ///         rewards for the prior epoch, so they revert with NoRewardsToClaim (primary
    ///         defense).  The budget guardrail provides additional defense-in-depth.
    function test_claimRewards_S595_nextEpochLocksHaveNoEligibleRewards() external {
        // Alice locks 100 ether before epoch boundary
        _createLock(users.alice, 100 ether);

        // Advance past epoch 1's end into epoch 2
        uint256 targetEpoch = 1;
        uint256 nextEpochStart = protocol.trustBonding.epochTimestampEnd(targetEpoch) + 1;
        vm.warp(nextEpochStart);

        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(targetEpoch);

        // Alice claims rewards for epoch 1 — she was the only locker, gets full budget
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 totalClaimedAfterAlice = protocol.trustBonding.totalClaimedRewardsForEpoch(targetEpoch);
        assertEq(totalClaimedAfterAlice, epochBudget, "Alice should claim full epoch budget");

        // Bob locks 5000 ether at next-epoch-start — excluded from epoch 1's snapshot.
        _createLock(users.bob, 5000 ether);

        // Bob has zero eligible rewards for epoch 1.
        vm.expectRevert(ITrustBonding.TrustBonding_NoRewardsToClaim.selector);
        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.bob);

        // Charlie locks 5000 ether at next-epoch-start — same result.
        _createLock(users.charlie, 5000 ether);

        vm.expectRevert(ITrustBonding.TrustBonding_NoRewardsToClaim.selector);
        resetPrank(users.charlie);
        protocol.trustBonding.claimRewards(users.charlie);

        // Invariant: totalClaimed <= epochBudget always holds
        uint256 finalTotalClaimed = protocol.trustBonding.totalClaimedRewardsForEpoch(targetEpoch);
        assertLe(finalTotalClaimed, epochBudget, "Invariant: totalClaimed <= epochBudget");
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_claimRewards_totalClaimedNeverExceedsBudget(uint256 lockAmount) external {
        // Bound to reasonable lock amounts (min 1 ether to avoid dust, max 100k ether)
        lockAmount = bound(lockAmount, 1 ether, 100_000 ether);

        // Ensure alice has enough tokens
        vm.deal(users.alice, lockAmount * 10);
        resetPrank(users.alice);
        protocol.wrappedTrust.deposit{ value: lockAmount }();
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);

        _createLock(users.alice, lockAmount);
        _advanceToEpoch(1);

        uint256 previousEpoch = 0;
        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(previousEpoch);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 totalClaimed = protocol.trustBonding.totalClaimedRewardsForEpoch(previousEpoch);
        assertLe(totalClaimed, epochBudget, "Invariant: totalClaimed <= epochBudget");
    }

    function testFuzz_claimRewards_totalClaimedNeverExceedsBudget_acrossClaimOrders(uint8 orderSeed) external {
        orderSeed = uint8(bound(orderSeed, 0, 5));

        _createLock(users.alice, 100 ether);
        _createLock(users.bob, 60 ether);
        _createLock(users.charlie, 40 ether);
        _advanceToEpoch(1);

        uint256 previousEpoch = 0;
        uint256 epochBudget = protocol.trustBonding.emissionsForEpoch(previousEpoch);
        address[3] memory claimers = _resolveClaimOrder(orderSeed);

        uint256 runningSum = 0;

        for (uint256 i = 0; i < claimers.length; i++) {
            address claimer = claimers[i];
            uint256 expectedRewards = _calculateExpectedRewards(claimer, previousEpoch);

            resetPrank(claimer);
            protocol.trustBonding.claimRewards(claimer);

            uint256 claimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(claimer, previousEpoch);
            runningSum += claimedRewards;

            assertEq(claimedRewards, expectedRewards, "claimed rewards mismatch");
            assertEq(
                protocol.trustBonding.totalClaimedRewardsForEpoch(previousEpoch), runningSum, "total claimed mismatch"
            );
            assertLe(
                protocol.trustBonding.totalClaimedRewardsForEpoch(previousEpoch),
                epochBudget,
                "Invariant: totalClaimed <= epochBudget"
            );
        }
    }

    function _resolveClaimOrder(uint8 orderSeed) internal view returns (address[3] memory claimers) {
        if (orderSeed == 0) {
            claimers[0] = users.alice;
            claimers[1] = users.bob;
            claimers[2] = users.charlie;
            return claimers;
        }
        if (orderSeed == 1) {
            claimers[0] = users.alice;
            claimers[1] = users.charlie;
            claimers[2] = users.bob;
            return claimers;
        }
        if (orderSeed == 2) {
            claimers[0] = users.bob;
            claimers[1] = users.alice;
            claimers[2] = users.charlie;
            return claimers;
        }
        if (orderSeed == 3) {
            claimers[0] = users.bob;
            claimers[1] = users.charlie;
            claimers[2] = users.alice;
            return claimers;
        }
        if (orderSeed == 4) {
            claimers[0] = users.charlie;
            claimers[1] = users.alice;
            claimers[2] = users.bob;
            return claimers;
        }

        claimers[0] = users.charlie;
        claimers[1] = users.bob;
        claimers[2] = users.alice;
    }
}
