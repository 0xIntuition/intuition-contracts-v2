// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract CheckpointValidationTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*                     STRUCTS                        */
    /* =================================================== */

    struct TestCase {
        uint256 timestamp;
        uint256 expectedEpoch;
    }

    /* =================================================== */
    /*          EXPECTED START TIMESTAMP TESTS            */
    /* =================================================== */

    function testCalculateExpectedCheckpointStartTimestamp_FirstCheckpoint() public {
        // This function is not meant to be used before any checkpoints exist
        // It should revert for any epoch when no checkpoints exist
        vm.expectRevert();
        controller.calculateExpectedCheckpointStartTimestamp(0);

        vm.expectRevert();
        controller.calculateExpectedCheckpointStartTimestamp(1);

        // After initializing the controller, it should work properly
        _initializeController();
        uint256 expectedStart = controller.calculateExpectedCheckpointStartTimestamp(0);
        assertEq(expectedStart, DEFAULT_START_TIMESTAMP, "Epoch 0 should start at emissions start timestamp");
    }

    function testCalculateExpectedCheckpointStartTimestamp_AtEpochBoundaries() public {
        _initializeController();

        // Test various epoch numbers
        uint256[] memory epochs = new uint256[](6);
        epochs[0] = 0; // Should be start timestamp
        epochs[1] = 1; // After 2 weeks
        epochs[2] = 13; // After 6 months (13 * 2 weeks)
        epochs[3] = 26; // After 1 year (26 * 2 weeks)
        epochs[4] = 52; // After 2 years (52 * 2 weeks)
        epochs[5] = 78; // After 3 years (78 * 2 weeks)

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 expectedTimestamp = controller.calculateExpectedCheckpointStartTimestamp(epochs[i]);
            uint256 manualCalculation = DEFAULT_START_TIMESTAMP + (epochs[i] * TWO_WEEKS);
            assertEq(expectedTimestamp, manualCalculation, "Expected timestamp calculation incorrect");
        }
    }

    function testCalculateExpectedCheckpointStartTimestamp_WithMultipleCheckpoints() public {
        _initializeController();

        // Create a second checkpoint at epoch 26
        uint256 secondCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(26);
        _createCheckpoint(secondCheckpointStart, ONE_WEEK, 52, 500_000 * 1e18, 500);

        // Now test expected timestamps after the second checkpoint
        uint256 epoch78Start = controller.calculateExpectedCheckpointStartTimestamp(78);
        uint256 expectedTimestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) + (52 * ONE_WEEK);
        assertEq(epoch78Start, expectedTimestamp, "Multi-checkpoint timestamp calculation incorrect");
    }

    /* =================================================== */
    /*          EPOCH END TIMESTAMP TESTS                 */
    /* =================================================== */

    function testGetEpochEndTimestamp_SingleCheckpoint() public {
        _initializeController();

        uint256[] memory epochs = new uint256[](4);
        epochs[0] = 0; // First epoch
        epochs[1] = 1; // Second epoch
        epochs[2] = 12; // Mid-year
        epochs[3] = 25; // Just before typical cliff

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 epochEnd = controller.getEpochEndTimestamp(epochs[i]);
            uint256 expectedEnd = DEFAULT_START_TIMESTAMP + ((epochs[i] + 1) * TWO_WEEKS);
            assertEq(epochEnd, expectedEnd, "Epoch end timestamp calculation incorrect");
        }
    }

    function testGetEpochEndTimestamp_MultipleCheckpoints() public {
        _setupMultipleCheckpointScenario();

        // Test epoch end in first checkpoint period (2-week epochs)
        uint256 epoch10End = controller.getEpochEndTimestamp(10);
        uint256 expectedEpoch10End = DEFAULT_START_TIMESTAMP + (11 * TWO_WEEKS);
        assertEq(epoch10End, expectedEpoch10End, "First checkpoint period epoch end incorrect");

        // Test epoch end in second checkpoint period (1-week epochs)
        uint256 epoch50End = controller.getEpochEndTimestamp(50);
        // Epoch 50 = 26 from first period (26 * 2 weeks) + 24 from second period (24 * 1 week)
        // End timestamp = start + 26 * 2 weeks + 25 * 1 week
        uint256 expectedEpoch50End = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) + (25 * ONE_WEEK);
        assertEq(epoch50End, expectedEpoch50End, "Second checkpoint period epoch end incorrect");
    }

    /* =================================================== */
    /*          CHECKPOINT START VALIDATION TESTS         */
    /* =================================================== */

    function testValidateCheckpointStartTimestamp_ValidTimestamp() public {
        _initializeController();

        // Test valid timestamps at epoch boundaries
        uint256[] memory validEpochs = new uint256[](4);
        validEpochs[0] = 13; // 6 months
        validEpochs[1] = 26; // 1 year
        validEpochs[2] = 39; // 1.5 years
        validEpochs[3] = 52; // 2 years

        for (uint256 i = 0; i < validEpochs.length; i++) {
            uint256 validTimestamp = controller.calculateExpectedCheckpointStartTimestamp(validEpochs[i]);
            // Should not revert
            controller.validateCheckpointStartTimestamp(validTimestamp);
        }
    }

    function testValidateCheckpointStartTimestamp_InvalidTimestamp() public {
        _initializeController();

        // Test timestamps that are NOT at epoch boundaries
        uint256[] memory invalidOffsets = new uint256[](5);
        invalidOffsets[0] = 1; // 1 second after start
        invalidOffsets[1] = ONE_DAY; // 1 day after start
        invalidOffsets[2] = ONE_WEEK; // 1 week after start
        invalidOffsets[3] = TWO_WEEKS - 1; // 1 second before epoch boundary
        invalidOffsets[4] = TWO_WEEKS + 1; // 1 second after epoch boundary

        for (uint256 i = 0; i < invalidOffsets.length; i++) {
            uint256 invalidTimestamp = DEFAULT_START_TIMESTAMP + invalidOffsets[i];
            vm.expectRevert();
            controller.validateCheckpointStartTimestamp(invalidTimestamp);
        }
    }

    function testValidateCheckpointStartTimestamp_FirstCheckpoint() public {
        // First checkpoint can start at any valid timestamp
        controller.validateCheckpointStartTimestamp(DEFAULT_START_TIMESTAMP);
        controller.validateCheckpointStartTimestamp(DEFAULT_START_TIMESTAMP + ONE_DAY);
        controller.validateCheckpointStartTimestamp(DEFAULT_START_TIMESTAMP + ONE_WEEK);

        // None of these should revert for the first checkpoint
    }

    /* =================================================== */
    /*          CURRENT EPOCH AT TIMESTAMP TESTS          */
    /* =================================================== */

    function testGetCurrentEpochAtTimestamp_SingleCheckpoint() public {
        _initializeController();

        // Test various timestamps and their corresponding epochs
        TestCase[] memory testCases = new TestCase[](6);
        testCases[0] = TestCase(DEFAULT_START_TIMESTAMP, 0);
        testCases[1] = TestCase(DEFAULT_START_TIMESTAMP + TWO_WEEKS, 1);
        testCases[2] = TestCase(DEFAULT_START_TIMESTAMP + (13 * TWO_WEEKS), 13);
        testCases[3] = TestCase(DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS), 26);
        testCases[4] = TestCase(DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) - 1, 25);
        testCases[5] = TestCase(DEFAULT_START_TIMESTAMP + (52 * TWO_WEEKS), 52);

        for (uint256 i = 0; i < testCases.length; i++) {
            uint256 currentEpoch = controller.getCurrentEpochAtTimestamp(testCases[i].timestamp);
            assertEq(currentEpoch, testCases[i].expectedEpoch, "Current epoch at timestamp incorrect");
        }
    }

    function testGetCurrentEpochAtTimestamp_MultipleCheckpoints() public {
        _setupMultipleCheckpointScenario();

        // Get the actual start times from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test epoch calculations across different checkpoint periods
        uint256 epochInFirst = controller.getCurrentEpochAtTimestamp(DEFAULT_START_TIMESTAMP + (10 * TWO_WEEKS));
        assertEq(epochInFirst, 10, "Epoch in first checkpoint period incorrect");

        uint256 epochInSecond = controller.getCurrentEpochAtTimestamp(secondCheckpoint.startTimestamp + (10 * ONE_WEEK));
        assertEq(epochInSecond, 36, "Epoch in second checkpoint period incorrect"); // 26 + 10

        uint256 epochInThird = controller.getCurrentEpochAtTimestamp(thirdCheckpoint.startTimestamp + (10 * ONE_DAY));
        assertEq(epochInThird, 88, "Epoch in third checkpoint period incorrect"); // 26 + 52 + 10
    }

    /* =================================================== */
    /*          CHECKPOINT CREATION WITH VALIDATION       */
    /* =================================================== */

    function testCreateCheckpoint_ValidStartTime() public {
        _initializeController();

        // Should succeed with correct epoch boundary timestamp
        uint256 validStartTime = controller.calculateExpectedCheckpointStartTimestamp(26);
        _createCheckpoint(validStartTime, ONE_WEEK, 52, 500_000 * 1e18, 500);

        uint256 checkpointCount = controller.getCheckpointCount();
        assertEq(checkpointCount, 2, "Checkpoint should be created successfully");
    }

    function testCreateCheckpoint_InvalidStartTime() public {
        _initializeController();

        // Should fail with incorrect timestamp (not at epoch boundary)
        uint256 invalidStartTime = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) + ONE_DAY; // Off by 1 day

        vm.expectRevert();
        _createCheckpoint(invalidStartTime, ONE_WEEK, 52, 500_000 * 1e18, 500);
    }

    function testCreateCheckpoint_MultipleValidCheckpoints() public {
        _initializeController();

        // Create second checkpoint at epoch 13
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(13);
        _createCheckpoint(secondStart, ONE_WEEK, 26, 750_000 * 1e18, 300);

        // Create third checkpoint at epoch 39 (13 + 26)
        uint256 thirdStart = controller.calculateExpectedCheckpointStartTimestamp(39);
        _createCheckpoint(thirdStart, ONE_DAY, 365, 100_000 * 1e18, 200);

        uint256 checkpointCount = controller.getCheckpointCount();
        assertEq(checkpointCount, 3, "All checkpoints should be created successfully");

        // Verify the timestamps are correct
        EmissionsCheckpoint memory second = controller.getCheckpoint(1);
        EmissionsCheckpoint memory third = controller.getCheckpoint(2);

        assertEq(second.startTimestamp, secondStart, "Second checkpoint timestamp incorrect");
        assertEq(third.startTimestamp, thirdStart, "Third checkpoint timestamp incorrect");
    }

    /* =================================================== */
    /*          COMPLEX SCENARIO TESTS                    */
    /* =================================================== */

    function testCheckpointValidation_ComplexScenario() public {
        // Start with daily epochs
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            ONE_DAY,
            50_000 * 1e18,
            30, // Cliff every month
            200 // 2%
        );

        // Create checkpoint after 60 days (2 months)
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(60);
        _createCheckpoint(
            secondStart,
            ONE_WEEK,
            8, // Cliff every 2 months
            300_000 * 1e18,
            150 // 1.5%
        );

        // Verify the timestamp is exactly 60 days from start
        uint256 expectedSecondStart = DEFAULT_START_TIMESTAMP + (60 * ONE_DAY);
        assertEq(secondStart, expectedSecondStart, "Second checkpoint start time incorrect");

        // Create third checkpoint after 8 weeks from second checkpoint start
        uint256 thirdStart = controller.calculateExpectedCheckpointStartTimestamp(68); // 60 + 8
        _createCheckpoint(
            thirdStart,
            ONE_HOUR,
            168, // Cliff every week
            10_000 * 1e18,
            100 // 1%
        );

        uint256 expectedThirdStart = expectedSecondStart + (8 * ONE_WEEK);
        assertEq(thirdStart, expectedThirdStart, "Third checkpoint start time incorrect");

        // Verify all checkpoints are properly aligned
        assertEq(controller.getCheckpointCount(), 3, "Should have 3 checkpoints");
    }

    function testCheckpointValidation_EdgeCases() public {
        _initializeController();

        // Test creating checkpoint at epoch 0 (should fail after first checkpoint exists)
        vm.expectRevert();
        _createCheckpoint(DEFAULT_START_TIMESTAMP, ONE_WEEK, 52, 500_000 * 1e18, 500);

        // Test creating checkpoint at epoch 1
        uint256 epoch1Start = controller.calculateExpectedCheckpointStartTimestamp(1);
        _createCheckpoint(epoch1Start, ONE_DAY, 30, 100_000 * 1e18, 300);

        // Verify it was created at the right time
        assertEq(epoch1Start, DEFAULT_START_TIMESTAMP + TWO_WEEKS, "Epoch 1 start time incorrect");
    }
}
