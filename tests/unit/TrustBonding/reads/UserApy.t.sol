// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/reads/UserApy.t.sol'

/**
 * @title TrustBondingUserApyTest
 * @notice Comprehensive unit tests for TrustBonding.getUserApy() function
 * @dev Tests cover edge cases, single/multiple users, multi-epoch scenarios, and varying utilization
 *
 *      IMPORTANT UTILIZATION LOGIC:
 *      - getUserApy returns (currentApy, maxApy) for a specific user
 *      - currentApy = (userRewardsPerYear * personalUtilization) / lockedAmount
 *      - maxApy = (userRewardsPerYear * 100%) / lockedAmount
 *      - Epochs 0 and 1: Always have 100% personal utilization (currentApy == maxApy)
 *      - Epoch 2+: Personal utilization based on user's MultiVault usage delta
 *      - Personal utilization ratio = (userUtilizationAfter - userUtilizationBefore) /
 * userClaimedRewardsInPreviousEpoch
 *      - If delta >= target: 100% utilization
 *      - If delta <= 0: floor utilization (personalUtilizationLowerBound)
 *      - Otherwise: normalized between floor and 100%
 */
contract TrustBondingUserApyTest is TrustBondingBase {
    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.deal(users.alice, DEAL_AMOUNT);
        vm.deal(users.bob, DEAL_AMOUNT);
        vm.deal(users.charlie, DEAL_AMOUNT);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /* =================================================== */
    /*                    EDGE CASES                       */
    /* =================================================== */

    /**
     * @notice Test getUserApy for user with no lock
     * @dev Should return 0 for both currentApy and maxApy
     */
    function test_getUserApy_noLock() external view {
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertEq(currentApy, 0, "Current APY should be 0 for user with no lock");
        assertEq(maxApy, 0, "Max APY should be 0 for user with no lock");
    }

    /**
     * @notice Test getUserApy with very small lock amount
     * @dev Verifies calculation doesn't overflow/underflow with small values
     */
    function test_getUserApy_verySmallLock() external {
        uint256 tinyAmount = 1 ether;
        _createLock(users.alice, tinyAmount);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test getUserApy immediately after lock creation in epoch 0
     * @dev Verifies APY is calculated correctly in epoch 0 - always 100% utilization
     */
    function test_getUserApy_epochZero() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% personal utilization");
    }

    /**
     * @notice Test getUserApy in epoch 1 - should always have 100% utilization
     * @dev Epochs 0 and 1 always have 100% utilization by design
     */
    function test_getUserApy_epoch1AlwaysFullUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        _advanceToEpoch(1);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 1 always has 100% personal utilization");
    }

    /* =================================================== */
    /*               SINGLE USER SCENARIOS                 */
    /* =================================================== */

    /**
     * @notice Test getUserApy with MINTIME lock duration
     * @dev Verifies APY calculation with minimum lock duration
     */
    function test_getUserApy_minTimeLock() external {
        uint256 minTime = protocol.trustBonding.MINTIME();
        uint256 unlockTime = _calculateUnlockTime(minTime);

        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, unlockTime);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test getUserApy with MAXTIME lock duration
     * @dev Verifies APY calculation with maximum lock duration
     */
    function test_getUserApy_maxTimeLock() external {
        uint256 maxTime = protocol.trustBonding.MAXTIME();
        uint256 unlockTime = _calculateUnlockTime(maxTime);

        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, unlockTime);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test getUserApy with different lock amounts
     * @dev Larger locks should result in lower APY (same rewards, more locked)
     */
    function test_getUserApy_differentLockAmounts() external {
        // Alice: Small lock
        _createLock(users.alice, SMALL_DEPOSIT_AMOUNT);
        (uint256 aliceCurrentApy, uint256 aliceMaxApy) = protocol.trustBonding.getUserApy(users.alice);

        // Bob: XLarge lock
        _createLock(users.bob, XLARGE_DEPOSIT_AMOUNT);
        (uint256 bobCurrentApy, uint256 bobMaxApy) = protocol.trustBonding.getUserApy(users.bob);

        // Alice should have higher APY (smaller denominator)
        assertGt(aliceCurrentApy, bobCurrentApy, "Smaller lock should have higher current APY");
        assertGt(aliceMaxApy, bobMaxApy, "Smaller lock should have higher max APY");
    }

    /* =================================================== */
    /*              MULTIPLE USER SCENARIOS                */
    /* =================================================== */

    /**
     * @notice Test getUserApy with two users having equal locks
     * @dev Both users should have same APY
     */
    function test_getUserApy_twoUsersEqualLocks() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);

        (uint256 aliceCurrentApy, uint256 aliceMaxApy) = protocol.trustBonding.getUserApy(users.alice);
        (uint256 bobCurrentApy, uint256 bobMaxApy) = protocol.trustBonding.getUserApy(users.bob);

        assertEq(aliceCurrentApy, bobCurrentApy, "Equal locks should have equal current APY");
        assertEq(aliceMaxApy, bobMaxApy, "Equal locks should have equal max APY");
    }

    /**
     * @notice Test getUserApy with three users having different lock amounts
     * @dev All users get same rewards proportion based on their veTRUST share, so APY depends on reward/locked ratio
     */
    function test_getUserApy_threeUsersDifferentAmounts() external {
        _createLock(users.alice, SMALL_DEPOSIT_AMOUNT);
        _createLock(users.bob, LARGE_DEPOSIT_AMOUNT);
        _createLock(users.charlie, XLARGE_DEPOSIT_AMOUNT);

        (uint256 aliceCurrentApy,) = protocol.trustBonding.getUserApy(users.alice);
        (uint256 bobCurrentApy,) = protocol.trustBonding.getUserApy(users.bob);
        (uint256 charlieCurrentApy,) = protocol.trustBonding.getUserApy(users.charlie);

        // All users should have positive APY
        assertGt(aliceCurrentApy, 0, "Alice should have positive APY");
        assertGt(bobCurrentApy, 0, "Bob should have positive APY");
        assertGt(charlieCurrentApy, 0, "Charlie should have positive APY");

        // APY is based on (userRewards / lockedAmount)
        // Since rewards are proportional to veTRUST (time-weighted), users with same lock time have similar APY
    }

    /* =================================================== */
    /*              MULTI-EPOCH SCENARIOS                  */
    /* =================================================== */

    /**
     * @notice Test getUserApy in epoch 2 with low personal utilization
     * @dev First epoch where personal utilization can be < 100%
     */
    function test_getUserApy_epoch2LowUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1 - claim some rewards to establish baseline
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        // Set utilization for epoch 1 (baseline)
        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        // Epoch 2: Low delta (250 ether increase, target was 1000 ether claimed)
        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 250 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, currentApy, "Max APY should be greater than current with partial utilization");
    }

    /**
     * @notice Test getUserApy in epoch 2 with high personal utilization
     * @dev Tests when delta meets or exceeds target
     */
    function test_getUserApy_epoch2HighUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        // Epoch 2: High delta (>= 1000 ether increase)
        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 1000 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY with full utilization");
    }

    /**
     * @notice Test getUserApy in epoch 2 with negative utilization delta
     * @dev Should return floor utilization when delta <= 0
     */
    function test_getUserApy_epoch2NegativeDelta() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        int256 userUtilizationEpoch1 = 1000 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        // Epoch 2: Negative delta (utilization decreased)
        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = 500 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, currentApy, "Max APY should be greater than current with floor utilization");

        // Current APY should be based on floor utilization (personalUtilizationLowerBound)
        uint256 personalUtilizationLowerBound = protocol.trustBonding.personalUtilizationLowerBound();
        uint256 expectedCurrentApy = (maxApy * personalUtilizationLowerBound) / BASIS_POINTS_DIVISOR;
        assertEq(currentApy, expectedCurrentApy, "APY should be at floor with negative delta");
    }

    /**
     * @notice Test getUserApy in epoch 2 with no claimed rewards in epoch 1 but had eligibility
     * @dev User had eligible rewards but didn't claim - should get floor utilization
     */
    function test_getUserApy_epoch2NoClaimButEligible() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1 - user didn't claim (claimedRewards = 0) but was eligible
        _advanceToEpoch(1);
        // Don't set claimed rewards for alice (defaults to 0)

        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        // Epoch 2: Increase utilization
        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 500 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, currentApy, "Max APY should be greater than current");

        // Should be at floor since they didn't claim in previous epoch despite eligibility
        uint256 personalUtilizationLowerBound = protocol.trustBonding.personalUtilizationLowerBound();
        uint256 expectedCurrentApy = (maxApy * personalUtilizationLowerBound) / BASIS_POINTS_DIVISOR;
        assertEq(currentApy, expectedCurrentApy, "APY should be at floor when user didn't claim");
    }

    /**
     * @notice Test getUserApy when user had 0 eligible rewards in previous epoch
     * @dev User locks just before epoch 2, so has 0 eligible rewards in epoch 1
     */
    function test_getUserApy_zeroEligibilityPreviousEpoch() external {
        // Move to epoch 1 before Alice locks
        _advanceToEpoch(1);

        // Alice locks in epoch 1 (late), so she has 0 eligible rewards for epoch 1
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        // Epoch 2: alice uses the protocol
        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 500 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        // Since user had 0 claimed rewards in epoch 1 but DID have eligible rewards,
        // they get floor utilization (didn't claim despite being eligible)
        uint256 personalUtilizationLowerBound = protocol.trustBonding.personalUtilizationLowerBound();
        uint256 expectedCurrentApy = (maxApy * personalUtilizationLowerBound) / BASIS_POINTS_DIVISOR;
        assertEq(currentApy, expectedCurrentApy, "User who didn't claim should get floor utilization");
    }

    /**
     * @notice Test getUserApy across multiple epochs with varying utilization
     * @dev Epoch 1: 100%, Epoch 2: Low, Epoch 3: High
     */
    function test_getUserApy_threeEpochsVaryingUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);
        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getUserApy(users.alice);

        // Epoch 2: Low utilization (300/1000 = 30%)
        _advanceToEpoch(2);
        uint256 claimedInEpoch2 = 500 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 2, claimedInEpoch2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 300 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getUserApy(users.alice);

        // Epoch 3: High utilization (600/500 = 120% > 100%)
        _advanceToEpoch(3);
        int256 userUtilizationEpoch3 = userUtilizationEpoch2 + 600 ether;
        _setUserUtilizationForEpoch(users.alice, 3, userUtilizationEpoch3);

        (uint256 currentApy3, uint256 maxApy3) = protocol.trustBonding.getUserApy(users.alice);

        // Verify progression
        assertEq(currentApy1, maxApy1, "Epoch 1 should be 100%");
        assertLt(currentApy2, maxApy2, "Epoch 2 should have partial utilization");
        assertEq(currentApy3, maxApy3, "Epoch 3 should have 100% utilization (delta >= target)");
        assertGt(currentApy3, currentApy2, "Epoch 3 APY should be higher than epoch 2");
    }

    /**
     * @notice Test getUserApy across four epochs with fluctuating utilization
     * @dev Tests realistic utilization pattern for a single user
     */
    function test_getUserApy_fourEpochsFluctuatingUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);
        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getUserApy(users.alice);

        // Epoch 2: Medium utilization (500/1000 = 50%)
        _advanceToEpoch(2);
        uint256 claimedInEpoch2 = 800 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 2, claimedInEpoch2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 500 ether;
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getUserApy(users.alice);

        // Epoch 3: Low utilization (200/800 = 25%)
        _advanceToEpoch(3);
        uint256 claimedInEpoch3 = 600 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 3, claimedInEpoch3);
        int256 userUtilizationEpoch3 = userUtilizationEpoch2 + 200 ether;
        _setUserUtilizationForEpoch(users.alice, 3, userUtilizationEpoch3);

        (uint256 currentApy3, uint256 maxApy3) = protocol.trustBonding.getUserApy(users.alice);

        // Epoch 4: High utilization (700/600 = 116% > 100%)
        _advanceToEpoch(4);
        int256 userUtilizationEpoch4 = userUtilizationEpoch3 + 700 ether;
        _setUserUtilizationForEpoch(users.alice, 4, userUtilizationEpoch4);

        (uint256 currentApy4, uint256 maxApy4) = protocol.trustBonding.getUserApy(users.alice);

        // Verify progression
        assertEq(currentApy1, maxApy1, "Epoch 1 should be 100%");
        assertLt(currentApy2, maxApy2, "Epoch 2 should have partial utilization");
        assertLt(currentApy3, currentApy2, "Epoch 3 APY should be lower (decreased utilization)");
        assertGt(currentApy4, currentApy3, "Epoch 4 APY should be higher (increased utilization)");
        assertEq(currentApy4, maxApy4, "Epoch 4 should have 100% utilization");
    }

    /* =================================================== */
    /*           MULTI-USER MULTI-EPOCH SCENARIOS          */
    /* =================================================== */

    /**
     * @notice Test getUserApy with different users having different utilization patterns
     * @dev Verifies that each user's APY is independent based on their own utilization
     */
    function test_getUserApy_multipleUsersDifferentUtilization() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);

        // Epoch 1: Both 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 500 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);
        _setUserClaimedRewardsForEpoch(users.bob, 1, claimedInEpoch1);

        int256 utilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, utilizationEpoch1);
        _setUserUtilizationForEpoch(users.bob, 1, utilizationEpoch1);

        // Epoch 2: Alice has high utilization, Bob has low
        _advanceToEpoch(2);

        // Alice: High utilization (500/500 = 100%)
        int256 aliceUtilizationEpoch2 = utilizationEpoch1 + 500 ether;
        _setUserUtilizationForEpoch(users.alice, 2, aliceUtilizationEpoch2);

        // Bob: Low utilization (100/500 = 20%)
        int256 bobUtilizationEpoch2 = utilizationEpoch1 + 100 ether;
        _setUserUtilizationForEpoch(users.bob, 2, bobUtilizationEpoch2);

        (uint256 aliceCurrentApy, uint256 aliceMaxApy) = protocol.trustBonding.getUserApy(users.alice);
        (uint256 bobCurrentApy, uint256 bobMaxApy) = protocol.trustBonding.getUserApy(users.bob);

        // Alice should have higher current APY due to higher utilization
        assertEq(aliceCurrentApy, aliceMaxApy, "Alice should have 100% utilization");
        assertLt(bobCurrentApy, bobMaxApy, "Bob should have partial utilization");
        assertGt(aliceCurrentApy, bobCurrentApy, "Alice's current APY should be higher than Bob's");

        // Max APY should be same (same lock amount)
        assertEq(aliceMaxApy, bobMaxApy, "Max APY should be equal with equal locks");
    }

    /* =================================================== */
    /*              APY CALCULATION ACCURACY               */
    /* =================================================== */

    /**
     * @notice Test getUserApy calculation accuracy
     * @dev Verifies the mathematical correctness of APY formula
     */
    function test_getUserApy_calculationAccuracy() external {
        _createLock(users.alice, XLARGE_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        // Verify basic properties
        assertGt(currentApy, 0, "Current APY should be positive");
        assertGt(maxApy, 0, "Max APY should be positive");
        assertGe(maxApy, currentApy, "Max APY should be >= current APY");

        // In epoch 0, current should equal max (100% utilization)
        assertEq(currentApy, maxApy, "Epoch 0 should have 100% personal utilization");
    }

    /**
     * @notice Test getUserApy formula verification
     * @dev Manually calculates expected APY and compares
     */
    function test_getUserApy_formulaVerification() external {
        uint256 lockAmount = LARGE_DEPOSIT_AMOUNT;
        _createLock(users.alice, lockAmount);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        // Manually calculate expected APY
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 userRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currentEpoch);
        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 personalUtilization = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, currentEpoch);

        uint256 expectedCurrentApy = (userRewards * epochsPerYear * personalUtilization) / lockAmount;
        uint256 expectedMaxApy = (userRewards * epochsPerYear * BASIS_POINTS_DIVISOR) / lockAmount;

        assertEq(currentApy, expectedCurrentApy, "Current APY should match manual calculation");
        assertEq(maxApy, expectedMaxApy, "Max APY should match manual calculation");
    }

    /**
     * @notice Test getUserApy relationship between current and max
     * @dev currentApy = maxApy * personalUtilization / BASIS_POINTS_DIVISOR
     */
    function test_getUserApy_currentMaxRelationship() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up for epoch 2 with 60% utilization
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);
        int256 userUtilizationEpoch1 = 100 ether;
        _setUserUtilizationForEpoch(users.alice, 1, userUtilizationEpoch1);

        _advanceToEpoch(2);
        int256 userUtilizationEpoch2 = userUtilizationEpoch1 + 600 ether; // 60%
        _setUserUtilizationForEpoch(users.alice, 2, userUtilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        // Get personal utilization ratio
        uint256 personalUtilization = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);

        // Calculate expected current APY
        uint256 expectedCurrentApy = (maxApy * personalUtilization) / BASIS_POINTS_DIVISOR;

        assertApproxEqRel(
            currentApy, expectedCurrentApy, 0.01e18, "Current APY should match expected based on utilization ratio"
        );
    }

    /**
     * @notice Test getUserApy when user increases lock amount
     * @dev APY should adjust based on new lock amount
     */
    function test_getUserApy_increaseLockAmount() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        (uint256 initialCurrentApy, uint256 initialMaxApy) = protocol.trustBonding.getUserApy(users.alice);

        // Increase lock - need to approve first
        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT);
        protocol.trustBonding.increase_amount(DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        (uint256 newCurrentApy, uint256 newMaxApy) = protocol.trustBonding.getUserApy(users.alice);

        // APY should decrease (same rewards, more locked)
        assertLt(newCurrentApy, initialCurrentApy, "Current APY should decrease with increased lock");
        assertLt(newMaxApy, initialMaxApy, "Max APY should decrease with increased lock");
    }
}
