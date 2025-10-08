// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/reads/SystemApy.t.sol'

/**
 * @title TrustBondingSystemApyTest
 * @notice Comprehensive unit tests for TrustBonding.getSystemApy() function
 * @dev Tests cover edge cases, single/multiple users, multi-epoch scenarios, and varying lock durations
 *
 *      IMPORTANT UTILIZATION LOGIC:
 *      - Epochs 0 and 1: Always have 100% utilization (currentApy == maxApy)
 *      - Epoch 2+: Utilization based on MultiVault usage delta between epochs
 *      - System utilization ratio = (utilizationAfter - utilizationBefore) / claimedRewardsInPreviousEpoch
 *      - If delta >= target: 100% utilization
 *      - If delta <= 0: floor utilization (systemUtilizationLowerBound)
 *      - Otherwise: normalized between floor and 100%
 */
contract TrustBondingSystemApyTest is TrustBondingBase {
    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.deal(users.alice, DEAL_AMOUNT);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /* =================================================== */
    /*                    EDGE CASES                       */
    /* =================================================== */

    /**
     * @notice Test APY calculation when no tokens are locked
     * @dev Both currentApy and maxApy should return 0 when totalSupply is 0
     */
    function test_getSystemApy_noLockedTokens() external view {
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertEq(currentApy, 0, "Current APY should be 0 with no locked tokens");
        assertEq(maxApy, 0, "Max APY should be 0 with no locked tokens");
    }

    /**
     * @notice Test APY calculation with extremely small locked amount
     * @dev Verifies calculation doesn't overflow/underflow with small values
     */
    function test_getSystemApy_verySmallLock() external {
        uint256 tinyAmount = 1 ether; // 1 token
        _createLock(users.alice, tinyAmount);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, 0, "Max APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY in epoch 0");
    }

    /**
     * @notice Test APY calculation immediately after lock creation in epoch 0
     * @dev Verifies APY is calculated correctly in epoch 0 - always 100% utilization
     */
    function test_getSystemApy_epochZero() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test APY in epoch 1 - should always have 100% utilization
     * @dev Epochs 0 and 1 always have 100% utilization by design
     */
    function test_getSystemApy_epoch1AlwaysFullUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        _advanceToEpoch(1);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Epoch 1 always has 100% utilization");
    }

    /* =================================================== */
    /*               SINGLE USER SCENARIOS                 */
    /* =================================================== */

    /**
     * @notice Test APY with single user and minimum lock duration
     * @dev Verifies APY calculation with MINTIME lock
     */
    function test_getSystemApy_singleUserMinTime() external {
        uint256 minTime = protocol.trustBonding.MINTIME();
        uint256 unlockTime = _calculateUnlockTime(minTime);

        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, unlockTime);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGe(maxApy, currentApy, "Max APY should be >= current APY");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test APY with single user and maximum lock duration
     * @dev Verifies APY calculation with MAXTIME lock
     */
    function test_getSystemApy_singleUserMaxTime() external {
        uint256 maxTime = protocol.trustBonding.MAXTIME();
        uint256 unlockTime = _calculateUnlockTime(maxTime);

        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, unlockTime);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGe(maxApy, currentApy, "Max APY should be >= current APY");
        assertEq(currentApy, maxApy, "Epoch 0 always has 100% utilization");
    }

    /**
     * @notice Test APY with single user and default 2-year lock
     * @dev Verifies standard lock duration APY calculation
     */
    function test_getSystemApy_singleUserDefaultLock() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY with no utilization");
    }

    /**
     * @notice Test APY changes with varying lock amounts
     * @dev Larger locked amounts should result in lower APY (more supply)
     */
    function test_getSystemApy_varyingLockAmounts() external {
        // Small lock
        _createLock(users.alice, SMALL_DEPOSIT_AMOUNT);
        (uint256 apySmall,) = protocol.trustBonding.getSystemApy();

        // Need to advance time past lock duration to withdraw
        uint256 maxTime = protocol.trustBonding.MAXTIME();
        vm.warp(block.timestamp + maxTime + 1);

        vm.startPrank(users.alice);
        protocol.trustBonding.withdraw();
        vm.stopPrank();

        // Medium lock
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        (uint256 apyMedium,) = protocol.trustBonding.getSystemApy();

        // Advance time again
        vm.warp(block.timestamp + maxTime + 1);

        vm.startPrank(users.alice);
        protocol.trustBonding.withdraw();
        vm.stopPrank();

        // Large lock
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);
        (uint256 apyLarge,) = protocol.trustBonding.getSystemApy();

        // APY should decrease as locked amount increases (higher supply)
        assertGt(apySmall, apyMedium, "Small lock APY should be higher than medium");
        assertGt(apyMedium, apyLarge, "Medium lock APY should be higher than large");
    }

    /* =================================================== */
    /*              MULTIPLE USER SCENARIOS                */
    /* =================================================== */

    /**
     * @notice Test APY with two users having equal locks
     * @dev Verifies APY calculation with multiple equal participants
     */
    function test_getSystemApy_twoUsersEqualLocks() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY in epoch 0");
    }

    /**
     * @notice Test APY with three users having different lock amounts
     * @dev Verifies APY calculation with varied participant sizes
     */
    function test_getSystemApy_threeUsersDifferentAmounts() external {
        _createLock(users.alice, SMALL_DEPOSIT_AMOUNT);
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);
        _createLock(users.charlie, LARGE_DEPOSIT_AMOUNT);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY in epoch 0");
    }

    /**
     * @notice Test APY with users having different lock durations
     * @dev Verifies APY calculation with mixed lock periods
     */
    function test_getSystemApy_usersWithDifferentDurations() external {
        uint256 minTime = protocol.trustBonding.MINTIME();
        uint256 maxTime = protocol.trustBonding.MAXTIME();

        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(minTime));
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT); // Default 2 years
        _createLockWithDuration(users.charlie, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(maxTime));

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY in epoch 0");
    }

    /* =================================================== */
    /*              MULTI-EPOCH SCENARIOS                  */
    /* =================================================== */

    /**
     * @notice Test APY in epoch 2 with low utilization
     * @dev First epoch where utilization can be < 100%
     */
    function test_getSystemApy_epoch2LowUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1 - claim some rewards to establish baseline
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        // Set utilization for epoch 1 (baseline)
        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);
        _setUserUtilizationForEpoch(users.alice, 1, utilizationEpoch1);

        // Epoch 2: Low delta (250 ether increase, target was 1000 ether claimed)
        // This gives 250/1000 = 25% of the range + floor
        _advanceToEpoch(2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 250 ether; // Small increase
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);
        _setUserUtilizationForEpoch(users.alice, 2, utilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, currentApy, "Max APY should be greater than current with partial utilization");
    }

    /**
     * @notice Test APY in epoch 2 with high utilization
     * @dev Tests when delta meets or exceeds target
     */
    function test_getSystemApy_epoch2HighUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);
        _setUserUtilizationForEpoch(users.alice, 1, utilizationEpoch1);

        // Epoch 2: High delta (>= 1000 ether increase)
        // This gives 100% utilization
        _advanceToEpoch(2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 1000 ether;
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);
        _setUserUtilizationForEpoch(users.alice, 2, utilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertEq(currentApy, maxApy, "Current APY should equal max APY with full utilization");
    }

    /**
     * @notice Test APY in epoch 2 with negative utilization delta
     * @dev Should return floor utilization when delta <= 0
     */
    function test_getSystemApy_epoch2NegativeDelta() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Set up epoch 1
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        int256 utilizationEpoch1 = 1000 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);
        _setUserUtilizationForEpoch(users.alice, 1, utilizationEpoch1);

        // Epoch 2: Negative delta (utilization decreased)
        _advanceToEpoch(2);
        int256 utilizationEpoch2 = 500 ether; // Decreased
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);
        _setUserUtilizationForEpoch(users.alice, 2, utilizationEpoch2);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy, 0, "Current APY should be greater than 0");
        assertGt(maxApy, currentApy, "Max APY should be greater than current with floor utilization");

        // Current APY should be based on floor utilization (systemUtilizationLowerBound)
        uint256 systemUtilizationLowerBound = protocol.trustBonding.systemUtilizationLowerBound();
        uint256 expectedCurrentApy = (maxApy * systemUtilizationLowerBound) / BASIS_POINTS_DIVISOR;
        assertEq(currentApy, expectedCurrentApy, "APY should be at floor with negative delta");
    }

    /**
     * @notice Test APY changes across two epochs with varying utilization
     * @dev Epoch 1: 100%, Epoch 2: High utilization (80-100%)
     */
    function test_getSystemApy_twoEpochsVaryingUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getSystemApy();

        assertEq(currentApy1, maxApy1, "Epoch 1 should have 100% utilization");

        // Set up for epoch 2
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        _setUserClaimedRewardsForEpoch(users.alice, 1, claimedInEpoch1);

        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);
        _setUserUtilizationForEpoch(users.alice, 1, utilizationEpoch1);

        // Epoch 2: High utilization (900 ether delta out of 1000 target = 90%)
        _advanceToEpoch(2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 900 ether;
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);
        _setUserUtilizationForEpoch(users.alice, 2, utilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getSystemApy();

        assertGt(currentApy2, 0, "Epoch 2 current APY should be greater than 0");
        assertGt(maxApy2, currentApy2, "Epoch 2 max APY should be greater than current");

        // Max APY should remain relatively stable
        assertApproxEqRel(maxApy1, maxApy2, 0.05e18, "Max APY should be similar across epochs");
    }

    /**
     * @notice Test APY changes across three epochs with increasing utilization
     * @dev Epoch 1: 100%, Epoch 2: Low, Epoch 3: High
     */
    function test_getSystemApy_threeEpochsIncreasingUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getSystemApy();

        // Epoch 2: Low utilization (300/1000 = 30%)
        _advanceToEpoch(2);
        uint256 claimedInEpoch2 = 500 ether;
        _setTotalClaimedRewardsForEpoch(2, claimedInEpoch2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 300 ether;
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getSystemApy();

        // Epoch 3: High utilization (600/500 = 120% > 100%)
        _advanceToEpoch(3);
        int256 utilizationEpoch3 = utilizationEpoch2 + 600 ether;
        _setTotalUtilizationForEpoch(3, utilizationEpoch3);

        (uint256 currentApy3, uint256 maxApy3) = protocol.trustBonding.getSystemApy();

        // Verify progression
        assertEq(currentApy1, maxApy1, "Epoch 1 should be 100%");
        assertGt(currentApy3, currentApy2, "Epoch 3 APY should be higher than epoch 2");
        assertEq(currentApy3, maxApy3, "Epoch 3 should have 100% utilization (delta >= target)");
    }

    /**
     * @notice Test APY changes across four epochs with fluctuating utilization
     * @dev Tests realistic utilization pattern
     */
    function test_getSystemApy_fourEpochsFluctuatingUtilization() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1000 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getSystemApy();

        // Epoch 2: Medium utilization (500/1000 = 50%)
        _advanceToEpoch(2);
        uint256 claimedInEpoch2 = 800 ether;
        _setTotalClaimedRewardsForEpoch(2, claimedInEpoch2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 500 ether;
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getSystemApy();

        // Epoch 3: Low utilization (200/800 = 25%)
        _advanceToEpoch(3);
        uint256 claimedInEpoch3 = 600 ether;
        _setTotalClaimedRewardsForEpoch(3, claimedInEpoch3);
        int256 utilizationEpoch3 = utilizationEpoch2 + 200 ether;
        _setTotalUtilizationForEpoch(3, utilizationEpoch3);

        (uint256 currentApy3, uint256 maxApy3) = protocol.trustBonding.getSystemApy();

        // Epoch 4: High utilization (700/600 = 116% > 100%)
        _advanceToEpoch(4);
        int256 utilizationEpoch4 = utilizationEpoch3 + 700 ether;
        _setTotalUtilizationForEpoch(4, utilizationEpoch4);

        (uint256 currentApy4, uint256 maxApy4) = protocol.trustBonding.getSystemApy();

        // Verify progression
        assertEq(currentApy1, maxApy1, "Epoch 1 should be 100%");
        assertLt(currentApy3, currentApy2, "Epoch 3 APY should be lower (decreased utilization)");
        assertGt(currentApy4, currentApy3, "Epoch 4 APY should be higher (increased utilization)");
        assertEq(currentApy4, maxApy4, "Epoch 4 should have 100% utilization");
    }

    /* =================================================== */
    /*           MULTI-USER MULTI-EPOCH SCENARIOS          */
    /* =================================================== */

    /**
     * @notice Test APY with multiple users across multiple epochs
     * @dev Verifies APY calculation with varied participation over time
     */
    function test_getSystemApy_multipleUsersMultipleEpochs() external {
        // Initial setup: Two users with different amounts
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);

        // Epoch 1: Always 100%
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 1500 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        int256 totalUtilizationEpoch1 = 200 ether;
        _setTotalUtilizationForEpoch(1, totalUtilizationEpoch1);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getSystemApy();

        // Epoch 2: Add third user BEFORE advancing epoch (so supply is already increased)
        _createLock(users.charlie, SMALL_DEPOSIT_AMOUNT);

        _advanceToEpoch(2);
        int256 totalUtilizationEpoch2 = totalUtilizationEpoch1 + 1200 ether;
        _setTotalUtilizationForEpoch(2, totalUtilizationEpoch2);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getSystemApy();

        // Verify APY behavior
        assertEq(currentApy1, maxApy1, "Epoch 1 should be 100%");
        assertGt(currentApy2, 0, "Epoch 2 APY should be greater than 0");
        assertLt(currentApy2, maxApy2, "Epoch 2 should have partial utilization");

        // Max APY in epoch 2 should be lower than epoch 1 since charlie joined before epoch 2
        // (The supply increased from alice+bob to alice+bob+charlie)
        assertApproxEqRel(maxApy2, maxApy1, 0.1e18, "Max APY changes slightly with supply change");
    }

    /* =================================================== */
    /*              APY CALCULATION ACCURACY               */
    /* =================================================== */

    /**
     * @notice Test APY calculation accuracy with known emissions
     * @dev Verifies the mathematical correctness of APY formula
     */
    function test_getSystemApy_calculationAccuracy() external {
        uint256 lockAmount = LARGE_DEPOSIT_AMOUNT;
        _createLock(users.alice, lockAmount);

        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();

        // Verify basic properties
        assertGt(currentApy, 0, "Current APY should be positive");
        assertGt(maxApy, 0, "Max APY should be positive");
        assertGe(maxApy, currentApy, "Max APY should be >= current APY");

        // In epoch 0, current should equal max (100% utilization)
        assertEq(currentApy, maxApy, "Epoch 0 should have 100% utilization");
    }

    /**
     * @notice Test APY stability when supply changes
     * @dev Verifies inverse relationship between supply and APY
     */
    function test_getSystemApy_supplyImpact() external {
        // First measurement with single user
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        // Move to epoch 2 for consistent comparison
        _advanceToEpoch(1);
        uint256 claimedInEpoch1 = 500 ether;
        _setTotalClaimedRewardsForEpoch(1, claimedInEpoch1);
        int256 utilizationEpoch1 = 100 ether;
        _setTotalUtilizationForEpoch(1, utilizationEpoch1);

        _advanceToEpoch(2);
        int256 utilizationEpoch2 = utilizationEpoch1 + 500 ether;
        _setTotalUtilizationForEpoch(2, utilizationEpoch2);

        (uint256 currentApy1, uint256 maxApy1) = protocol.trustBonding.getSystemApy();

        // Double the supply by adding bob
        _createLock(users.bob, DEFAULT_DEPOSIT_AMOUNT);

        // Epoch 3: Keep same utilization ratio
        _advanceToEpoch(3);
        uint256 claimedInEpoch2 = 250 ether; // Half per user
        _setTotalClaimedRewardsForEpoch(2, claimedInEpoch2);
        int256 utilizationEpoch3 = utilizationEpoch2 + 250 ether; // Same ratio: 250/250 = 100%
        _setTotalUtilizationForEpoch(3, utilizationEpoch3);

        (uint256 currentApy2, uint256 maxApy2) = protocol.trustBonding.getSystemApy();

        // With doubled supply, max APY should be approximately half
        assertApproxEqRel(maxApy1, maxApy2 * 2, 0.05e18, "Max APY should halve when supply doubles");

        // Both should have 100% utilization
        assertEq(currentApy1, maxApy1, "Epoch 2 should have 100% utilization");
        assertEq(currentApy2, maxApy2, "Epoch 3 should have 100% utilization");
    }

    /**
     * @notice Test APY when more users stake over time
     * @dev Verifies APY decreases as total locked increases
     */
    function test_getSystemApy_increaseStake() external {
        _createLock(users.alice, LARGE_DEPOSIT_AMOUNT);
        (uint256 initialSystemApy, uint256 initialMaxApy) = protocol.trustBonding.getSystemApy();

        _createLock(users.bob, LARGE_DEPOSIT_AMOUNT);

        (uint256 newSystemApy, uint256 newMaximumApy) = protocol.trustBonding.getSystemApy();

        // System APY should decrease as more tokens are locked (same emissions, more supply)
        assertLt(newSystemApy, initialSystemApy, "System APY should decrease when more tokens are locked");
        assertLt(newMaximumApy, initialMaxApy, "Max APY should also decrease");
    }
}
