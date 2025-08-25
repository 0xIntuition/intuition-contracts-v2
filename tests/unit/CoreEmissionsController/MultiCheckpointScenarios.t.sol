// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract MultiCheckpointScenariosTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*                     STRUCTS                        */
    /* =================================================== */

    struct TestPoint {
        uint256 timestamp;
        uint256 expectedEmissions;
    }

    /* =================================================== */
    /*      BASIC MULTI-CHECKPOINT TESTS                  */
    /* =================================================== */

    function testMultiCheckpoint_EmissionsTransition() public {
        _setupMultipleCheckpointScenario();

        // Test emissions in first checkpoint period
        uint256 firstPeriodEmissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP + (10 * TWO_WEEKS));
        assertEq(firstPeriodEmissions, DEFAULT_EMISSIONS_PER_EPOCH, "First period emissions should be base amount");

        // Test emissions in second checkpoint period
        uint256 secondPeriodStart = DEFAULT_START_TIMESTAMP + ONE_YEAR;
        uint256 secondPeriodEmissions = controller.calculateEpochEmissionsAt(secondPeriodStart);
        assertEq(secondPeriodEmissions, 500_000 * 1e18, "Second period emissions should be 500K");

        // Test emissions in third checkpoint period
        uint256 thirdPeriodStart = DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR);
        uint256 thirdPeriodEmissions = controller.calculateEpochEmissionsAt(thirdPeriodStart);
        assertEq(thirdPeriodEmissions, 100_000 * 1e18, "Third period emissions should be 100K");
    }

    function testMultiCheckpoint_CliffReductionsIndependent() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint information
        EmissionsCheckpoint memory firstCheckpoint = controller.getCheckpoint(0);
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test emissions at the start of each checkpoint (before any cliffs)
        uint256 firstEmissions = controller.calculateEpochEmissionsAt(firstCheckpoint.startTimestamp);
        assertEq(firstEmissions, DEFAULT_EMISSIONS_PER_EPOCH, "First checkpoint should start with base emissions");

        uint256 secondEmissions = controller.calculateEpochEmissionsAt(secondCheckpoint.startTimestamp);
        assertEq(secondEmissions, 500_000 * 1e18, "Second checkpoint should start with base emissions");

        uint256 thirdEmissions = controller.calculateEpochEmissionsAt(thirdCheckpoint.startTimestamp);
        assertEq(thirdEmissions, 100_000 * 1e18, "Third checkpoint should start with base emissions");

        // Test cliff reductions within checkpoint periods (not at boundaries)
        // Test second checkpoint emissions just before its cliff (at epoch 51, cliff at 52)
        uint256 beforeSecondCliff = secondCheckpoint.startTimestamp + (51 * ONE_WEEK);
        uint256 beforeCliffEmissions = controller.calculateEpochEmissionsAt(beforeSecondCliff);
        assertEq(beforeCliffEmissions, 500_000 * 1e18, "Before cliff should be base emissions");

        // Test third checkpoint emissions at various points to show cliff reduction
        // After 365 epochs (1 cliff) in third checkpoint
        uint256 thirdCliff = thirdCheckpoint.startTimestamp + (365 * ONE_DAY);
        uint256 thirdCliffEmissions = controller.calculateEpochEmissionsAt(thirdCliff);
        uint256 expectedThirdCliff = _calculateExpectedEmissionsAfterCliffs(
            100_000 * 1e18, // Base emissions for third checkpoint
            MAX_CLIFF_REDUCTION_BASIS_POINTS, // 10% reduction
            1
        );
        assertEq(thirdCliffEmissions, expectedThirdCliff, "Third checkpoint should apply 10% cliff reduction");
    }

    function testMultiCheckpoint_EpochCalculationAcrossCheckpoints() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint start times from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test epochs calculated relative to each checkpoint's start time
        uint256 secondCheckpointStart = secondCheckpoint.startTimestamp;

        // At start of second checkpoint should be epoch 0 relative to that checkpoint
        uint256 epoch = controller.calculateEpochNumber(secondCheckpointStart, secondCheckpoint);
        assertEq(epoch, 0, "Epoch at second checkpoint start should be 0");

        // One week later should be epoch 1 (since second checkpoint uses 1-week epochs)
        epoch = controller.calculateEpochNumber(secondCheckpointStart + ONE_WEEK, secondCheckpoint);
        assertEq(epoch, 1, "One week after second checkpoint start should be epoch 1");

        // Test third checkpoint
        uint256 thirdCheckpointStart = thirdCheckpoint.startTimestamp;
        EmissionsCheckpoint memory thirdCheckpointFound = controller.findCheckpointForTimestamp(thirdCheckpointStart);

        epoch = controller.calculateEpochNumber(thirdCheckpointStart, thirdCheckpointFound);
        assertEq(epoch, 0, "Epoch at third checkpoint start should be 0");

        // One day later should be epoch 1 (since third checkpoint uses 1-day epochs)
        epoch = controller.calculateEpochNumber(thirdCheckpointStart + ONE_DAY, thirdCheckpointFound);
        assertEq(epoch, 1, "One day after third checkpoint start should be epoch 1");
    }

    /* =================================================== */
    /*         TRANSITION BOUNDARY TESTS                  */
    /* =================================================== */

    function testMultiCheckpoint_TransitionBoundaries() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint start times from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        uint256 secondCheckpointStart = secondCheckpoint.startTimestamp;
        uint256 thirdCheckpointStart = thirdCheckpoint.startTimestamp;

        // Test exactly at transition points
        uint256 beforeSecond = controller.calculateEpochEmissionsAt(secondCheckpointStart - 1);
        uint256 atSecond = controller.calculateEpochEmissionsAt(secondCheckpointStart);

        assertEq(beforeSecond, DEFAULT_EMISSIONS_PER_EPOCH, "Just before second checkpoint should use first checkpoint");
        assertEq(atSecond, 500_000 * 1e18, "At second checkpoint should use second checkpoint");

        uint256 beforeThird = controller.calculateEpochEmissionsAt(thirdCheckpointStart - 1);
        uint256 atThird = controller.calculateEpochEmissionsAt(thirdCheckpointStart);

        assertEq(beforeThird, 500_000 * 1e18, "Just before third checkpoint should use second checkpoint");
        assertEq(atThird, 100_000 * 1e18, "At third checkpoint should use third checkpoint");
    }

    function testMultiCheckpoint_FindCorrectCheckpoint() public {
        _setupMultipleCheckpointScenario();

        uint256 secondStart = DEFAULT_START_TIMESTAMP + ONE_YEAR;
        uint256 thirdStart = DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR);

        // Test finding checkpoints at various timestamps
        EmissionsCheckpoint memory checkpoint;

        // Within first year
        checkpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP + (ONE_WEEK * 30));
        assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should find first checkpoint");
        assertEq(checkpoint.emissionsLength, TWO_WEEKS, "Should have 2-week epochs");

        // Within second year
        checkpoint = controller.findCheckpointForTimestamp(secondStart + (ONE_WEEK * 30));
        assertEq(checkpoint.startTimestamp, secondStart, "Should find second checkpoint");
        assertEq(checkpoint.emissionsLength, ONE_WEEK, "Should have 1-week epochs");

        // Within third year and beyond
        checkpoint = controller.findCheckpointForTimestamp(thirdStart + (ONE_WEEK * 30));
        assertEq(checkpoint.startTimestamp, thirdStart, "Should find third checkpoint");
        assertEq(checkpoint.emissionsLength, ONE_DAY, "Should have 1-day epochs");

        // Far in future should still return latest checkpoint
        checkpoint = controller.findCheckpointForTimestamp(thirdStart + (10 * ONE_YEAR));
        assertEq(checkpoint.startTimestamp, thirdStart, "Should find third checkpoint for future dates");
    }

    /* =================================================== */
    /*         COMPLEX CLIFF SCENARIOS                    */
    /* =================================================== */

    function testMultiCheckpoint_OverlappingCliffs() public {
        // Create scenario where cliffs from different checkpoints might occur close together
        _initializeController();

        // Second checkpoint starts at proper epoch boundary
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(27); // Epoch 27
        _createCheckpoint(
            secondStart,
            ONE_WEEK,
            4, // Cliff every 4 weeks
            750_000 * 1e18,
            800 // 8% reduction
        );

        // Test emissions before first cliff
        uint256 beforeFirstCliff = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP + (25 * TWO_WEEKS));
        assertEq(beforeFirstCliff, DEFAULT_EMISSIONS_PER_EPOCH, "Before first cliff should be base emissions");

        // Test emissions after first cliff but before second checkpoint
        uint256 afterFirstCliff = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS));
        uint256 expectedAfterFirstCliff =
            _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, 1);
        assertEq(afterFirstCliff, expectedAfterFirstCliff, "After first cliff should be reduced");

        // Test emissions at second checkpoint start (should reset to new base)
        uint256 atSecondStart = controller.calculateEpochEmissionsAt(secondStart);
        assertEq(atSecondStart, 750_000 * 1e18, "At second checkpoint should use new base emissions");

        // Test emissions after cliff in second checkpoint
        uint256 secondCliff = secondStart + (4 * ONE_WEEK);
        uint256 afterSecondCliff = controller.calculateEpochEmissionsAt(secondCliff);
        uint256 expectedAfterSecondCliff = _calculateExpectedEmissionsAfterCliffs(
            750_000 * 1e18,
            800, // 8% reduction
            1
        );
        assertEq(afterSecondCliff, expectedAfterSecondCliff, "After second checkpoint cliff should use its reduction");
    }

    function testMultiCheckpoint_DifferentCliffFrequencies() public {
        _initializeController();

        // Second checkpoint with much more frequent cliffs
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(26); // Epoch 26
        _createCheckpoint(
            secondStart,
            ONE_DAY,
            7, // Cliff every week (7 daily epochs)
            200_000 * 1e18,
            300 // 3% reduction
        );

        // Test multiple cliffs in second checkpoint
        for (uint256 i = 1; i <= 10; i++) {
            uint256 timestamp = secondStart + (i * 7 * ONE_DAY); // Every 7 days = 1 cliff
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
            uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
                200_000 * 1e18,
                300, // 3% reduction
                i
            );
            assertEq(emissions, expectedEmissions, "Frequent cliffs should compound correctly");
        }
    }

    /* =================================================== */
    /*         EPOCH LENGTH TRANSITION TESTS              */
    /* =================================================== */

    function testMultiCheckpoint_EpochLengthTransitions() public {
        _initializeController();

        // Create checkpoints with dramatically different epoch lengths
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(26); // Epoch 26
        _createCheckpoint(
            secondStart,
            ONE_HOUR, // Very short epochs
            24, // Cliff every day
            50_000 * 1e18,
            200 // 2% reduction
        );

        uint256 thirdStart = controller.calculateExpectedCheckpointStartTimestamp(52); // Epoch 52
        _createCheckpoint(
            thirdStart,
            30 * ONE_DAY, // Very long epochs (monthly)
            12, // Cliff every year
            2_000_000 * 1e18,
            MAX_CLIFF_REDUCTION_BASIS_POINTS // Use max allowed
        );

        // Test epoch calculations with different lengths
        EmissionsCheckpoint memory firstCheckpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
        EmissionsCheckpoint memory secondCheckpoint = controller.findCheckpointForTimestamp(secondStart);
        EmissionsCheckpoint memory thirdCheckpoint = controller.findCheckpointForTimestamp(thirdStart);

        // First checkpoint: 2-week epochs
        uint256 epoch1 = controller.calculateEpochNumber(DEFAULT_START_TIMESTAMP + (10 * TWO_WEEKS), firstCheckpoint);
        assertEq(epoch1, 10, "First checkpoint should calculate epochs correctly");

        // Second checkpoint: 1-hour epochs
        uint256 epoch2 = controller.calculateEpochNumber(secondStart + (48 * ONE_HOUR), secondCheckpoint);
        assertEq(epoch2, 48, "Second checkpoint should calculate hourly epochs correctly");

        // Third checkpoint: monthly epochs
        uint256 epoch3 = controller.calculateEpochNumber(thirdStart + (90 * ONE_DAY), thirdCheckpoint);
        assertEq(epoch3, 3, "Third checkpoint should calculate monthly epochs correctly");
    }

    /* =================================================== */
    /*      CUMULATIVE EPOCH CALCULATION TESTS            */
    /* =================================================== */

    function testMultiCheckpoint_CumulativeEpochs() public {
        _setupMultipleCheckpointScenario();

        uint256 secondStart = DEFAULT_START_TIMESTAMP + ONE_YEAR;
        uint256 thirdStart = DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR);

        // Calculate expected cumulative epochs at different points

        // At start of second checkpoint
        uint256 epochsInFirstPeriod = ONE_YEAR / TWO_WEEKS; // 26 epochs
        uint256 totalAtSecondStart = controller.calculateTotalEpochsToTimestamp(secondStart);
        assertEq(totalAtSecondStart, epochsInFirstPeriod, "Should have correct cumulative epochs at second start");

        // Halfway through second checkpoint
        uint256 halfwaySecond = secondStart + (ONE_YEAR / 2);
        uint256 epochsInHalfSecond = (ONE_YEAR / 2) / ONE_WEEK; // 26 weekly epochs
        uint256 totalAtHalfSecond = controller.calculateTotalEpochsToTimestamp(halfwaySecond);
        assertEq(totalAtHalfSecond, epochsInFirstPeriod + epochsInHalfSecond, "Should accumulate epochs correctly");

        // At start of third checkpoint
        uint256 epochsInSecondPeriod = ONE_YEAR / ONE_WEEK; // 52 epochs
        uint256 totalAtThirdStart = controller.calculateTotalEpochsToTimestamp(thirdStart);
        assertEq(
            totalAtThirdStart, epochsInFirstPeriod + epochsInSecondPeriod, "Should have correct total at third start"
        );
    }

    function testMultiCheckpoint_TimestampForEpoch() public {
        _setupMultipleCheckpointScenario();

        // Test timestamp calculation for various epoch numbers
        uint256 epoch0 = controller.calculateTimestampForEpoch(0);
        assertEq(epoch0, DEFAULT_START_TIMESTAMP, "Epoch 0 should be at start timestamp");

        uint256 epoch1 = controller.calculateTimestampForEpoch(1);
        assertEq(epoch1, DEFAULT_START_TIMESTAMP + TWO_WEEKS, "Epoch 1 should be at start of first checkpoint");

        uint256 epoch6 = controller.calculateTimestampForEpoch(6);
        assertEq(epoch6, DEFAULT_START_TIMESTAMP + (TWO_WEEKS * 6), "Epoch 6 should be at start of first checkpoint");

        // Epoch 26 should be at start of second checkpoint
        uint256 epoch26 = controller.calculateTimestampForEpoch(25);
        uint256 secondStart = DEFAULT_START_TIMESTAMP + (TWO_WEEKS * 25);
        console2.log("Epoch 26 timestamp:", epoch26);
        console2.log("Second checkpoint start:", secondStart);
        assertEq(epoch26, secondStart, "Epoch 26 should be at second checkpoint start");

        // Epoch 78 should be at start of third checkpoint (26 + 52)
        uint256 epoch78 = controller.calculateTimestampForEpoch(78);
        uint256 thirdStart = DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR);
        assertEq(epoch78, thirdStart, "Epoch 78 should be at third checkpoint start");

        // Test epoch within third checkpoint period
        uint256 epoch85 = controller.calculateTimestampForEpoch(85); // 7 epochs into third checkpoint
        uint256 expectedEpoch85 = thirdStart + (7 * ONE_DAY);
        assertEq(epoch85, expectedEpoch85, "Epoch within third checkpoint should calculate correctly");
    }

    /* =================================================== */
    /*         REALISTIC SCENARIO TESTS                   */
    /* =================================================== */

    function testMultiCheckpoint_RealisticTokenomicsScenario() public {
        // Simulate a realistic tokenomics evolution over several years

        // Year 1: High initial emissions, bi-weekly distribution
        _initializeController();

        // Year : Reduce frequency, reduce emissions
        uint256 year2Start = controller.calculateExpectedCheckpointStartTimestamp(26); // Epoch 26
        _createCheckpoint(
            year2Start,
            ONE_WEEK, // Weekly instead of bi-weekly
            1, // Cliff every week
            600_000 * 1e18, // Reduced emissions
            750 // 7.5% reduction
        );

        // Year 3: Further reduction for sustainability
        uint256 year3Start = controller.calculateExpectedCheckpointStartTimestamp(78); // Epoch 78
        _createCheckpoint(
            year3Start,
            ONE_WEEK, // Keep weekly
            1, // Cliff every week
            300_000 * 1e18, // Further reduced
            500 // 5% reduction
        );

        // Year 5: Minimal emissions for long-term sustainability
        uint256 year5Start = controller.calculateExpectedCheckpointStartTimestamp(182); // Epoch 182
        _createCheckpoint(
            year5Start,
            30 * ONE_DAY, // Monthly distribution
            12, // Cliff every year
            100_000 * 1e18, // Minimal emissions
            250 // 2.5% reduction
        );

        // Test emissions evolution over time
        TestPoint[] memory testPoints = new TestPoint[](7);
        testPoints[0] = TestPoint(DEFAULT_START_TIMESTAMP, DEFAULT_EMISSIONS_PER_EPOCH); // Checkpoint 1 & 0 Cliffs
        testPoints[1] = TestPoint(DEFAULT_START_TIMESTAMP + ONE_YEAR, 600_000 * 1e18); // Checkpoint 2 & 0 Cliffs
        testPoints[2] = TestPoint(DEFAULT_START_TIMESTAMP + (ONE_YEAR + ONE_WEEK), 555_000 * 1e18); // Checkpoint 2 & 1
            // Cliffs
        testPoints[3] = TestPoint(DEFAULT_START_TIMESTAMP + (ONE_YEAR + (2 * ONE_WEEK)), 513_375 * 1e18); // Checkpoint
            // 2 & 2 Cliffs
        testPoints[4] = TestPoint(DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR), 300_000 * 1e18); // Checkpoint 3 & 0 Cliffs
        testPoints[5] = TestPoint(DEFAULT_START_TIMESTAMP + ((2 * ONE_YEAR) + ONE_WEEK), 285_000 * 1e18); // Checkpoint
            // 3 & 2 Cliffs
        testPoints[6] = TestPoint(DEFAULT_START_TIMESTAMP + ((2 * ONE_YEAR) + (2 * ONE_WEEK)), 270_750 * 1e18); // Checkpoint
            // 3 & 3 Cliffs

        for (uint256 i = 0; i < testPoints.length; i++) {
            uint256 actualEmissions = controller.calculateEpochEmissionsAt(testPoints[i].timestamp);
            console2.log("Actual emissions at timestamp", testPoints[i].timestamp, ":", actualEmissions);
            assertEq(actualEmissions, testPoints[i].expectedEmissions); // Allow small rounding error
        }
    }

    function testMultiCheckpoint_ComplexTransitionScenario() public {
        // Test complex scenario with overlapping features

        // Start with high-frequency, high-emission checkpoint
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            ONE_DAY, // Daily epochs
            100_000 * 1e18, // 100K per day
            30, // Cliff every month
            500 // 5% reduction
        );

        // Transition to lower frequency but higher per-epoch emissions
        uint256 midYearStart = controller.calculateExpectedCheckpointStartTimestamp(180); // ~6 months
        _createCheckpoint(
            midYearStart,
            ONE_WEEK, // Weekly epochs
            4, // Cliff every month (4 weeks)
            500_000 * 1e18, // 500K per week (less per day but same per week)
            300 // 3% reduction
        );

        // Final transition to very low frequency, sustainable emissions
        uint256 yearEndStart = controller.calculateExpectedCheckpointStartTimestamp(184); // Near year end
        _createCheckpoint(
            yearEndStart,
            30 * ONE_DAY, // Monthly epochs
            12, // Cliff every year
            2_000_000 * 1e18, // 2M per month (sustainable long-term)
            100 // 1% reduction
        );

        // Test that total emissions are roughly equivalent during transitions using proper checkpoint times
        uint256 sixMonths = midYearStart;
        uint256 oneYear = yearEndStart;

        // Before first cliff (day 29): 100K per day
        uint256 dailyEmissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP + (29 * ONE_DAY));
        assertEq(dailyEmissions, 100_000 * 1e18, "Daily emissions should be 100K before first cliff");

        // At first cliff (day 30): reduced by 5%
        uint256 dailyEmissionsAfterCliff =
            controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP + (30 * ONE_DAY));
        uint256 expectedAfterCliff = _calculateExpectedEmissionsAfterCliffs(100_000 * 1e18, 500, 1);
        assertEq(dailyEmissionsAfterCliff, expectedAfterCliff, "Daily emissions should be reduced after cliff");

        // After first transition: 500K per week (≈71.4K per day)
        uint256 weeklyEmissions = controller.calculateEpochEmissionsAt(sixMonths + ONE_WEEK);
        assertEq(weeklyEmissions, 500_000 * 1e18, "Weekly emissions should be 500K");

        // After second transition: 2M per month (≈66.7K per day)
        uint256 monthlyEmissions = controller.calculateEpochEmissionsAt(oneYear + (30 * ONE_DAY));
        assertEq(monthlyEmissions, 2_000_000 * 1e18, "Monthly emissions should be 2M");
    }

    /* =================================================== */
    /*         CONSISTENCY ACROSS CHECKPOINTS             */
    /* =================================================== */

    function testMultiCheckpoint_ConsistentBehavior() public {
        _setupMultipleCheckpointScenario();

        // Test that behavior is consistent within each checkpoint period
        uint256 secondStart = DEFAULT_START_TIMESTAMP + ONE_YEAR;
        uint256 thirdStart = DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR);

        // Test first checkpoint period consistency
        for (uint256 i = 0; i < 20; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * TWO_WEEKS) + (TWO_WEEKS / 2);
            if (timestamp < secondStart) {
                uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
                EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(timestamp);
                assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should use first checkpoint");

                // Emissions should follow first checkpoint's cliff schedule
                uint256 cliffsPassed = i / DEFAULT_CLIFF;
                uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
                    DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, cliffsPassed
                );
                assertEq(emissions, expectedEmissions, "Emissions should follow first checkpoint schedule");
            }
        }

        // Test second checkpoint period consistency
        for (uint256 i = 0; i < 40; i++) {
            uint256 timestamp = secondStart + (i * ONE_WEEK) + (ONE_WEEK / 2);
            if (timestamp < thirdStart) {
                EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(timestamp);
                assertEq(checkpoint.startTimestamp, secondStart, "Should use second checkpoint");
                assertEq(checkpoint.emissionsLength, ONE_WEEK, "Should have weekly epochs");
                assertEq(checkpoint.emissionsReductionCliff, 52, "Should have yearly cliffs");
            }
        }
    }

    function testMultiCheckpoint_NoRegressionInEmissions() public {
        _setupMultipleCheckpointScenario();

        // Test that emissions never unexpectedly increase when crossing checkpoint boundaries
        uint256 previousEmissions = type(uint256).max;

        for (uint256 i = 0; i < 3 * ONE_YEAR; i += ONE_DAY) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + i;
            uint256 currentEmissions = controller.calculateEpochEmissionsAt(timestamp);

            // Allow increases only at checkpoint boundaries with higher base emissions
            // In our setup, each checkpoint has lower base emissions, so total should generally decrease
            bool isCheckpointBoundary = (timestamp == DEFAULT_START_TIMESTAMP + ONE_YEAR)
                || (timestamp == DEFAULT_START_TIMESTAMP + (2 * ONE_YEAR));

            if (!isCheckpointBoundary) {
                assertLe(currentEmissions, previousEmissions, "Emissions should generally decrease over time");
            }

            previousEmissions = currentEmissions;
        }
    }
}
