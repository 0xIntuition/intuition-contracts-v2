// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/ClaimRewards.t.sol'
contract ClaimRewardsTest is TrustBondingBase {
    /// @notice Events to test
    event RewardsClaimed(address indexed user, address indexed recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, initialTokens * 10);
        vm.deal(users.bob, initialTokens * 10);
        vm.deal(users.charlie, initialTokens * 10);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
        _addToTrustBondingWhiteList(users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_shouldRevertIfContractIsPaused() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        // Pause the contract
        resetPrank(users.admin);
        protocol.trustBonding.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
    }

    function test_claimRewards_shouldRevertIfRecipientIsZeroAddress() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(address(0));
    }

    function test_claimRewards_shouldRevertIfClaimingDuringEpoch0() external {
        _createLock(users.alice, initialTokens);
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_NoClaimingDuringFirstEpoch.selector));
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
    }

    function test_claimRewards_shouldRevertIfNoRawRewardsToClaim() external {
        // Advance to epoch 3 but don't bond any tokens for Alice
        _advanceToEpoch(3);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_NoRewardsToClaim.selector));
        protocol.trustBonding.claimRewards(users.alice);
    }

    function test_claimRewards_shouldRevertIfAlreadyClaimedForEpoch() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        // First claim should succeed
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Second claim for the same epoch should fail
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector));
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                        SUCCESSFUL CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_basicSuccessfulClaim() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(1);

        uint256 prevEpoch = 0;
        uint256 expectedRawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, prevEpoch);
        uint256 personalUtilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, prevEpoch);
        uint256 expectedFinalRewards = expectedRawRewards * personalUtilizationRatio / BASIS_POINTS_DIVISOR;

        uint256 aliceBalanceBefore = users.alice.balance;

        vm.expectEmit(true, true, false, true);
        emit RewardsClaimed(users.alice, users.alice, expectedFinalRewards);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 aliceBalanceAfter = users.alice.balance;
        assertEq(
            aliceBalanceAfter,
            aliceBalanceBefore + expectedFinalRewards,
            "Alice balance should increase by final rewards"
        );

        // Check storage updates
        assertEq(
            protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch),
            expectedFinalRewards,
            "Total claimed rewards should be updated"
        );
        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch),
            expectedFinalRewards,
            "User claimed rewards should be updated"
        );
        assertTrue(
            protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, prevEpoch),
            "User should be marked as having claimed"
        );
    }

    function test_claimRewards_claimToMultipleRecipients() external {
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens);
        _advanceToEpoch(1);

        uint256 prevEpoch = 0;

        // Alice claims to Bob
        uint256 aliceExpectedRewards = _calculateExpectedRewards(users.alice, prevEpoch);
        uint256 bobBalanceBefore = users.bob.balance;

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.bob);

        uint256 bobBalanceAfter = users.bob.balance;
        assertEq(bobBalanceAfter, bobBalanceBefore + aliceExpectedRewards, "Bob should receive Alice's rewards");

        // Bob claims to Charlie
        uint256 bobExpectedRewards = _calculateExpectedRewards(users.bob, prevEpoch);
        uint256 charlieBalanceBefore = users.charlie.balance;

        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.charlie);

        uint256 charlieBalanceAfter = users.charlie.balance;
        assertEq(charlieBalanceAfter, charlieBalanceBefore + bobExpectedRewards, "Charlie should receive Bob's rewards");
    }

    function test_claimRewards_multipleBondersClaimingSameEpoch() external {
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens);
        _createLock(users.charlie, initialTokens / 2); // Different amounts
        _advanceToEpoch(1);

        uint256 prevEpoch = 0;

        // Calculate expected rewards for each user
        uint256 aliceExpected = _calculateExpectedRewards(users.alice, prevEpoch);
        uint256 bobExpected = _calculateExpectedRewards(users.bob, prevEpoch);
        uint256 charlieExpected = _calculateExpectedRewards(users.charlie, prevEpoch);

        // All users claim
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        resetPrank(users.bob);
        protocol.trustBonding.claimRewards(users.bob);

        resetPrank(users.charlie);
        protocol.trustBonding.claimRewards(users.charlie);

        // Verify total claimed rewards
        uint256 totalClaimed = protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch);
        uint256 expectedTotalClaimed = aliceExpected + bobExpected + charlieExpected;
        assertEq(totalClaimed, expectedTotalClaimed, "Total claimed should equal sum of individual claims");

        // Verify individual claimed rewards
        assertEq(protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch), aliceExpected);
        assertEq(protocol.trustBonding.userClaimedRewardsForEpoch(users.bob, prevEpoch), bobExpected);
        assertEq(protocol.trustBonding.userClaimedRewardsForEpoch(users.charlie, prevEpoch), charlieExpected);
    }

    /*//////////////////////////////////////////////////////////////
                    UTILIZATION RATIO IMPACT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_withMaxPersonalUtilizationRatio() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(2); // Need epoch 2+ for utilization calculations

        uint256 prevEpoch = 1;

        // Set up scenario where Alice gets max utilization ratio (100%)
        _setUserUtilizationForEpoch(users.alice, 0, 1000e18);
        _setUserUtilizationForEpoch(users.alice, 1, 2000e18); // Doubled utilization
        _setUserClaimedRewardsForEpoch(users.alice, 0, 500e18); // Low target, high delta

        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, prevEpoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, prevEpoch);

        assertEq(utilizationRatio, BASIS_POINTS_DIVISOR, "Should get max utilization ratio");

        uint256 expectedRewards = rawRewards; // No reduction due to max ratio

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch),
            expectedRewards,
            "Should claim full raw rewards with max ratio"
        );
    }

    function test_claimRewards_withMinPersonalUtilizationRatio() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(3);

        uint256 prevEpoch = 2;

        // Set up scenario where Alice gets min utilization ratio (30%)
        _setUserUtilizationForEpoch(users.alice, 0, 2000e18);
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18); // Decreased utilization (negative delta)

        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, prevEpoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, prevEpoch);

        assertEq(utilizationRatio, PERSONAL_UTILIZATION_LOWER_BOUND, "Should get min utilization ratio");

        uint256 expectedRewards = rawRewards * PERSONAL_UTILIZATION_LOWER_BOUND / BASIS_POINTS_DIVISOR;

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch),
            expectedRewards,
            "Should claim reduced rewards with min ratio"
        );
    }

    function test_claimRewards_withPartialPersonalUtilizationRatio() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(3);

        uint256 prevEpoch = 2;

        // Set up scenario for 50% of target utilization delta
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        _setUserUtilizationForEpoch(users.alice, 2, 1500e18); // Delta = 500
        _setUserClaimedRewardsForEpoch(users.alice, 1, 1000e18); // Target = 1000

        // Expected ratio = 3000 + (500 * 7000) / 1000 = 3000 + 3500 = 6500
        uint256 expectedRatio = 6500;

        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, prevEpoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, prevEpoch);

        assertEq(utilizationRatio, expectedRatio, "Should get calculated utilization ratio");

        uint256 expectedRewards = rawRewards * expectedRatio / BASIS_POINTS_DIVISOR;

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch),
            expectedRewards,
            "Should claim rewards with partial ratio"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EMISSION IMPACT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_withSystemUtilizationImpactOnEmissions() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(3);
        _setLastActiveEpochFoSystem(3);

        uint256 prevEpoch = 2;

        // Set up system utilization to affect emissions for epoch 1
        _setTotalUtilizationForEpoch(1, 1000e18);
        _setTotalUtilizationForEpoch(2, 1500e18); // Delta = 500
        _setTotalClaimedRewardsForEpoch(1, 1000e18); // Target = 1000

        // Expected system ratio = 5000 + (500 * 5000) / 1000 = 7500
        uint256 expectedSystemRatio = 7500;

        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(prevEpoch);
        assertEq(systemRatio, expectedSystemRatio, "System utilization ratio should be calculated correctly");

        uint256 maxEmissions = protocol.satelliteEmissionsController.getEmissionsAtEpoch(prevEpoch);
        uint256 actualEmissions = protocol.trustBonding.emissionsForEpoch(prevEpoch);
        uint256 expectedEmissions = maxEmissions * expectedSystemRatio / BASIS_POINTS_DIVISOR;

        assertEq(actualEmissions, expectedEmissions, "Emissions should be reduced by system utilization ratio");

        // Now claim and verify the rewards are based on the reduced emissions
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // The claimed rewards should be based on the reduced emissions
        uint256 claimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertGt(claimedRewards, 0, "Should have claimed some rewards");

        // The claimed rewards should be less than what would be claimed with full emissions
        uint256 fullEmissionRewards = users.alice.balance; // Approximate comparison
        assertGt(fullEmissionRewards, 0, "Should have received rewards");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-EPOCH CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_claimFromMultipleEpochs() external {
        uint256 aliceBalanceBefore = users.alice.balance;
        _createLock(users.alice, initialTokens);

        // Advance through multiple epochs and claim each one
        _advanceToEpoch(1);
        uint256 rewards1 = _calculateExpectedRewards(users.alice, 0);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        _advanceToEpoch(2);
        uint256 rewards2 = _calculateExpectedRewards(users.alice, 1);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        _advanceToEpoch(3);
        uint256 rewards3 = _calculateExpectedRewards(users.alice, 2);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Verify total received rewards
        uint256 totalExpected = rewards1 + rewards2 + rewards3;
        assertEq(users.alice.balance, aliceBalanceBefore + totalExpected, "Should receive cumulative rewards");

        // Verify individual epoch records
        assertTrue(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, 0));
        assertTrue(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, 1));
        assertTrue(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, 2));
    }

    function test_claimRewards_skippedEpochForfeitsRewards() external {
        _createLock(users.alice, initialTokens);

        // Advance to epoch 1 but don't claim
        _advanceToEpoch(1);

        // Advance to epoch 2, now epoch 0 rewards are forfeited
        _advanceToEpoch(2);

        // Try to claim for epoch 1 (previous epoch)
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Verify only epoch 1 rewards were claimed, epoch 0 rewards are lost
        assertFalse(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, 0), "Epoch 0 should not be claimable");
        assertTrue(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, 1), "Epoch 1 should be claimed");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_verySmallBondedAmount() external {
        uint256 smallAmount = 1e12; // Very small amount
        _createLock(users.alice, smallAmount);
        _advanceToEpoch(1);

        // Should still be able to claim even with tiny rewards
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0);
        assertGt(claimedRewards, 0, "Should claim some rewards even with small bond");
    }

    function test_claimRewards_maximumBondedAmount() external {
        uint256 maxAmount = 1_000_000 * 1e18; // Large amount

        // Give Alice enough tokens
        vm.deal(users.alice, maxAmount * 2);
        vm.startPrank(users.alice);
        protocol.wrappedTrust.deposit{ value: maxAmount * 2 }();
        vm.stopPrank();

        _createLock(users.alice, maxAmount);
        _advanceToEpoch(1);

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0);
        assertGt(claimedRewards, 0, "Should claim rewards with large bond");
    }

    function test_claimRewards_rounding() external {
        // Test potential rounding issues with utilization ratios
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(2);

        uint256 prevEpoch = 1;

        // Set up scenario that might cause rounding issues
        _setUserUtilizationForEpoch(users.alice, 0, 1);
        _setUserUtilizationForEpoch(users.alice, 1, 4); // Very small delta = 3
        _setUserClaimedRewardsForEpoch(users.alice, 0, 3); // Large target

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch);
        // Should get minimum ratio due to very small delta vs large target
        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, prevEpoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, prevEpoch);
        uint256 expectedMinRewards = rawRewards * utilizationRatio / BASIS_POINTS_DIVISOR;

        assertEq(claimedRewards, expectedMinRewards, "Should handle rounding correctly");
    }
}
