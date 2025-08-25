// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract CheckpointManagementTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*            INITIALIZATION TESTS                    */
    /* =================================================== */

    function testInitialization_CreatesFirstCheckpoint() public {
        _initializeController();

        uint256 checkpointCount = controller.getCheckpointCount();
        assertEq(checkpointCount, 1, "Should create exactly one checkpoint on initialization");

        EmissionsCheckpoint memory checkpoint = controller.getCheckpoint(0);
        _assertCheckpointEqual(
            checkpoint,
            _createMockCheckpoint(
                DEFAULT_START_TIMESTAMP,
                DEFAULT_EPOCH_LENGTH,
                DEFAULT_EMISSIONS_PER_EPOCH,
                DEFAULT_CLIFF,
                DEFAULT_REDUCTION_BP
            )
        );
    }

    function testInitialization_SetsEmissionsStartTimestamp() public {
        _initializeController();

        uint256 startTimestamp = controller.getEmissionsStartTimestamp();
        assertEq(startTimestamp, DEFAULT_START_TIMESTAMP, "Emissions start timestamp should be set correctly");
    }

    function testInitialization_CalculatesRetentionFactor() public {
        _initializeController();

        EmissionsCheckpoint memory checkpoint = controller.getCheckpoint(0);
        uint256 expectedRetentionFactor = BASIS_POINTS_DIVISOR - DEFAULT_REDUCTION_BP;
        assertEq(checkpoint.retentionFactor, expectedRetentionFactor, "Retention factor should be calculated correctly");
    }

    /* =================================================== */
    /*            CHECKPOINT CREATION TESTS               */
    /* =================================================== */

    function testCreateCheckpoint_AddsNewCheckpoint() public {
        _initializeController();

        // Use proper epoch boundary (epoch 26 = 1 year with 2-week epochs)
        uint256 newCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(26);
        _createCheckpoint(
            newCheckpointStart,
            ONE_WEEK,
            52, // 52 weeks = 1 year
            500_000 * 1e18, // 500K tokens
            500 // 5%
        );

        uint256 checkpointCount = controller.getCheckpointCount();
        assertEq(checkpointCount, 2, "Should have 2 checkpoints after creation");

        EmissionsCheckpoint memory newCheckpoint = controller.getCheckpoint(1);
        _assertCheckpointEqual(
            newCheckpoint, _createMockCheckpoint(newCheckpointStart, ONE_WEEK, 500_000 * 1e18, 52, 500)
        );
    }

    function testCreateCheckpoint_MaintainsChronologicalOrder() public {
        _initializeController();

        // Add checkpoints at proper epoch boundaries
        uint256[] memory epochs = new uint256[](3);
        epochs[0] = 26; // 1 year
        epochs[1] = 52; // 2 years
        epochs[2] = 78; // 3 years

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 checkpointStart = controller.calculateExpectedCheckpointStartTimestamp(epochs[i]);
            _createCheckpoint(
                checkpointStart,
                ONE_WEEK,
                52,
                (1000 - i * 100) * 1000 * 1e18, // Decreasing emissions
                DEFAULT_REDUCTION_BP
            );
        }

        uint256 checkpointCount = controller.getCheckpointCount();
        assertEq(checkpointCount, 4, "Should have 4 checkpoints total"); // Including initial

        // Verify chronological order
        for (uint256 i = 1; i < checkpointCount; i++) {
            EmissionsCheckpoint memory prev = controller.getCheckpoint(i - 1);
            EmissionsCheckpoint memory curr = controller.getCheckpoint(i);
            assertLt(prev.startTimestamp, curr.startTimestamp, "Checkpoints should be in chronological order");
        }
    }

    function testCreateCheckpoint_RejectsInvalidOrder() public {
        _initializeController();

        // Try to create checkpoint in the past
        vm.expectRevert();
        _createCheckpoint(DEFAULT_START_TIMESTAMP - 1, ONE_WEEK, 52, 500_000 * 1e18, 500);

        // Try to create checkpoint at same timestamp
        vm.expectRevert();
        _createCheckpoint(DEFAULT_START_TIMESTAMP, ONE_WEEK, 52, 500_000 * 1e18, 500);
    }

    function testCreateCheckpoint_ValidatesReductionBasisPoints() public {
        _initializeController();

        // Try to create checkpoint with reduction > max allowed
        vm.expectRevert();
        _createCheckpoint(
            DEFAULT_START_TIMESTAMP + ONE_YEAR, ONE_WEEK, 52, 500_000 * 1e18, MAX_CLIFF_REDUCTION_BASIS_POINTS + 1
        );
    }

    function testCreateCheckpoint_ValidatesCliff() public {
        _initializeController();

        // Try to create checkpoint with cliff = 0
        vm.expectRevert();
        _createCheckpoint(
            DEFAULT_START_TIMESTAMP + ONE_YEAR,
            ONE_WEEK,
            0, // Invalid cliff
            500_000 * 1e18,
            500
        );

        // Try to create checkpoint with cliff > 365
        vm.expectRevert();
        _createCheckpoint(
            DEFAULT_START_TIMESTAMP + ONE_YEAR,
            ONE_WEEK,
            366, // Invalid cliff
            500_000 * 1e18,
            500
        );
    }

    /* =================================================== */
    /*          CHECKPOINT RETRIEVAL TESTS                */
    /* =================================================== */

    function testFindCheckpointForTimestamp_ReturnsCorrectCheckpoint() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint start times from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test finding checkpoints at different timestamps
        EmissionsCheckpoint memory checkpoint;

        // At start - should return first checkpoint
        checkpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
        assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should return first checkpoint");

        // Within first period - should return first checkpoint
        checkpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP + (13 * TWO_WEEKS));
        assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should return first checkpoint");

        // At second checkpoint start - should return second checkpoint
        checkpoint = controller.findCheckpointForTimestamp(secondCheckpoint.startTimestamp);
        assertEq(checkpoint.startTimestamp, secondCheckpoint.startTimestamp, "Should return second checkpoint");

        // Within second period - should return second checkpoint
        checkpoint = controller.findCheckpointForTimestamp(secondCheckpoint.startTimestamp + (26 * ONE_WEEK));
        assertEq(checkpoint.startTimestamp, secondCheckpoint.startTimestamp, "Should return second checkpoint");

        // At third checkpoint start - should return third checkpoint
        checkpoint = controller.findCheckpointForTimestamp(thirdCheckpoint.startTimestamp);
        assertEq(checkpoint.startTimestamp, thirdCheckpoint.startTimestamp, "Should return third checkpoint");
    }

    function testFindCheckpointForTimestamp_HandlesEdgeCases() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint start time from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        uint256 secondStart = secondCheckpoint.startTimestamp;

        // Test 1 second before second checkpoint
        EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(secondStart - 1);
        assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should return first checkpoint");

        // Test exactly at second checkpoint
        checkpoint = controller.findCheckpointForTimestamp(secondStart);
        assertEq(checkpoint.startTimestamp, secondStart, "Should return second checkpoint");

        // Test 1 second after second checkpoint
        checkpoint = controller.findCheckpointForTimestamp(secondStart + 1);
        assertEq(checkpoint.startTimestamp, secondStart, "Should return second checkpoint");
    }

    function testFindCheckpointForTimestamp_ReturnsLatestForFutureTimestamp() public {
        _setupMultipleCheckpointScenario();

        // Get actual third checkpoint start time from the setup
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test very far in future
        uint256 futureTimestamp = thirdCheckpoint.startTimestamp + (10 * ONE_YEAR);
        EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(futureTimestamp);

        assertEq(
            checkpoint.startTimestamp,
            thirdCheckpoint.startTimestamp,
            "Should return latest checkpoint for future timestamp"
        );
    }

    function testFindCheckpointForTimestamp_RevertsWithNoCheckpoints() public {
        // Don't initialize controller
        vm.expectRevert();
        controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
    }

    /* =================================================== */
    /*         CHECKPOINT ACCESS FUNCTIONS                */
    /* =================================================== */

    function testGetCurrentCheckpoint_ReturnsCorrectCheckpoint() public {
        _setupMultipleCheckpointScenario();

        // Get actual checkpoint start times from the setup
        EmissionsCheckpoint memory secondCheckpoint = controller.getCheckpoint(1);
        EmissionsCheckpoint memory thirdCheckpoint = controller.getCheckpoint(2);

        // Test at different timestamps
        _warpToTimestamp(DEFAULT_START_TIMESTAMP);
        EmissionsCheckpoint memory checkpoint = controller.getCurrentCheckpoint();
        assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "Should return first checkpoint at start");

        _warpToTimestamp(secondCheckpoint.startTimestamp);
        checkpoint = controller.getCurrentCheckpoint();
        assertEq(checkpoint.startTimestamp, secondCheckpoint.startTimestamp, "Should return second checkpoint");

        _warpToTimestamp(thirdCheckpoint.startTimestamp);
        checkpoint = controller.getCurrentCheckpoint();
        assertEq(checkpoint.startTimestamp, thirdCheckpoint.startTimestamp, "Should return third checkpoint");
    }

    function testGetAllCheckpoints_ReturnsAllCheckpoints() public {
        _setupMultipleCheckpointScenario();

        EmissionsCheckpoint[] memory allCheckpoints = controller.getAllCheckpoints();
        assertEq(allCheckpoints.length, 3, "Should return all 3 checkpoints");

        // Verify they're in chronological order
        for (uint256 i = 1; i < allCheckpoints.length; i++) {
            assertLt(
                allCheckpoints[i - 1].startTimestamp,
                allCheckpoints[i].startTimestamp,
                "Checkpoints should be chronological"
            );
        }
    }

    function testGetCheckpointCount_ReturnsCorrectCount() public {
        assertEq(controller.getCheckpointCount(), 0, "Should start with 0 checkpoints");

        _initializeController();
        assertEq(controller.getCheckpointCount(), 1, "Should have 1 checkpoint after init");

        // Add additional checkpoints (not calling _setupMultipleCheckpointScenario since it reinitializes)
        uint256 secondStart = controller.calculateExpectedCheckpointStartTimestamp(26);
        _createCheckpoint(secondStart, ONE_WEEK, 52, 500_000 * 1e18, 500);

        uint256 thirdStart = controller.calculateExpectedCheckpointStartTimestamp(78);
        _createCheckpoint(thirdStart, ONE_DAY, 365, 100_000 * 1e18, MAX_CLIFF_REDUCTION_BASIS_POINTS);

        assertEq(controller.getCheckpointCount(), 3, "Should have 3 checkpoints after adding two more");
    }

    function testGetCheckpoint_ReturnsCorrectCheckpoint() public {
        _setupMultipleCheckpointScenario();

        EmissionsCheckpoint memory first = controller.getCheckpoint(0);
        assertEq(first.startTimestamp, DEFAULT_START_TIMESTAMP, "First checkpoint should have correct timestamp");

        EmissionsCheckpoint memory second = controller.getCheckpoint(1);
        uint256 expectedSecondStart = controller.calculateExpectedCheckpointStartTimestamp(26);
        assertEq(second.startTimestamp, expectedSecondStart, "Second checkpoint should have correct timestamp");

        EmissionsCheckpoint memory third = controller.getCheckpoint(2);
        uint256 expectedThirdStart = controller.calculateExpectedCheckpointStartTimestamp(78);
        assertEq(third.startTimestamp, expectedThirdStart, "Third checkpoint should have correct timestamp");
    }

    function testGetCheckpoint_RevertsOnInvalidIndex() public {
        _initializeController();

        vm.expectRevert("Checkpoint index out of bounds");
        controller.getCheckpoint(1); // Only index 0 should exist

        vm.expectRevert("Checkpoint index out of bounds");
        controller.getCheckpoint(100); // Way out of bounds
    }

    /* =================================================== */
    /*           CHECKPOINT PROPERTIES TESTS              */
    /* =================================================== */

    function testCheckpointProperties_AllFieldsSetCorrectly() public {
        _initializeController();
        uint256 startTimestamp = controller.calculateExpectedCheckpointStartTimestamp(26); // Epoch 26
        uint256 epochLength = ONE_WEEK;
        uint256 emissionsPerEpoch = 750_000 * 1e18;
        uint256 cliff = 52;
        uint256 reductionBp = 750; // 7.5%

        _createCheckpoint(startTimestamp, epochLength, cliff, emissionsPerEpoch, reductionBp);

        EmissionsCheckpoint memory checkpoint = controller.getCheckpoint(1);

        assertEq(checkpoint.startTimestamp, startTimestamp, "Start timestamp incorrect");
        assertEq(checkpoint.emissionsLength, epochLength, "Emissions length incorrect");
        assertEq(checkpoint.emissionsPerEpoch, emissionsPerEpoch, "Emissions per epoch incorrect");
        assertEq(checkpoint.emissionsReductionCliff, cliff, "Cliff incorrect");
        assertEq(checkpoint.emissionsReductionBasisPoints, reductionBp, "Reduction basis points incorrect");
        assertEq(checkpoint.retentionFactor, BASIS_POINTS_DIVISOR - reductionBp, "Retention factor incorrect");
    }

    struct CheckpointConfig {
        uint256 startTimestamp;
        uint256 epochLength;
        uint256 cliff;
        uint256 emissionsPerEpoch;
        uint256 reductionBp;
    }

    function testCheckpointProperties_DifferentConfigurations() public {
        _initializeController();

        CheckpointConfig[] memory configs = new CheckpointConfig[](3);
        configs[0] = CheckpointConfig(
            controller.calculateExpectedCheckpointStartTimestamp(26), // Epoch 26
            ONE_WEEK, // Weekly instead of bi-weekly
            52, // Cliff every week
            600_000 * 1e18, // Reduced emissions
            750 // 7.5% reduction
        );
        configs[1] = CheckpointConfig(
            controller.calculateExpectedCheckpointStartTimestamp(78), // Epoch 78
            ONE_WEEK, // Keep weekly
            1, // Cliff every week
            300_000 * 1e18, // Further reduced
            500 // 5% reduction
        );
        configs[2] = CheckpointConfig(
            controller.calculateExpectedCheckpointStartTimestamp(130), // Epoch 130
            30 * ONE_DAY,
            12,
            5_000_000 * 1e18,
            MAX_CLIFF_REDUCTION_BASIS_POINTS // 10%
        );

        // Create checkpoints
        for (uint256 i = 0; i < configs.length; i++) {
            CheckpointConfig memory config = configs[i];
            _createCheckpoint(
                config.startTimestamp, config.epochLength, config.cliff, config.emissionsPerEpoch, config.reductionBp
            );
        }

        // Verify all checkpoints
        for (uint256 i = 0; i < configs.length; i++) {
            CheckpointConfig memory config = configs[i];
            EmissionsCheckpoint memory checkpoint = controller.getCheckpoint(i + 1); // +1 because index 0 is initial
                // checkpoint

            assertEq(checkpoint.startTimestamp, config.startTimestamp, "Start timestamp mismatch");
            assertEq(checkpoint.emissionsLength, config.epochLength, "Epoch length mismatch");
            assertEq(checkpoint.emissionsPerEpoch, config.emissionsPerEpoch, "Emissions per epoch mismatch");
            assertEq(checkpoint.emissionsReductionCliff, config.cliff, "Cliff mismatch");
            assertEq(checkpoint.emissionsReductionBasisPoints, config.reductionBp, "Reduction BP mismatch");
            assertEq(checkpoint.retentionFactor, BASIS_POINTS_DIVISOR - config.reductionBp, "Retention factor mismatch");
        }
    }

    /* =================================================== */
    /*         CHECKPOINT EVENT TESTS                     */
    /* =================================================== */

    function testCheckpointCreation_EmitsEvent() public {
        _initializeController();

        uint256 startTimestamp = controller.calculateExpectedCheckpointStartTimestamp(26); // Epoch 26
        uint256 epochLength = ONE_WEEK;
        uint256 cliff = 52;
        uint256 emissionsPerEpoch = 500_000 * 1e18;
        uint256 reductionBp = 500;

        vm.expectEmit(true, true, true, true);
        emit CheckpointCreated(startTimestamp, epochLength, cliff, emissionsPerEpoch, reductionBp);

        _createCheckpoint(startTimestamp, epochLength, cliff, emissionsPerEpoch, reductionBp);
    }

    /* =================================================== */
    /*            BOUNDARY CONDITION TESTS               */
    /* =================================================== */

    function testCheckpointManagement_MaximumCheckpoints() public {
        _initializeController();

        // Create many checkpoints to test array handling
        uint256 checkpointCount = 100;

        for (uint256 i = 1; i <= checkpointCount; i++) {
            uint256 epochNumber = i * 26; // Every 26 epochs (1 year each)
            uint256 startTimestamp = controller.calculateExpectedCheckpointStartTimestamp(epochNumber);
            _createCheckpoint(
                startTimestamp,
                TWO_WEEKS,
                26,
                DEFAULT_EMISSIONS_PER_EPOCH - (i * 1000 * 1e18), // Decreasing emissions
                DEFAULT_REDUCTION_BP
            );
        }

        assertEq(controller.getCheckpointCount(), checkpointCount + 1, "Should have correct number of checkpoints"); // +1
            // for initial

        // Test that we can still access all checkpoints
        for (uint256 i = 0; i <= checkpointCount; i++) {
            EmissionsCheckpoint memory checkpoint = controller.getCheckpoint(i);
            if (i == 0) {
                assertEq(checkpoint.startTimestamp, DEFAULT_START_TIMESTAMP, "First checkpoint timestamp incorrect");
            } else {
                uint256 expectedTimestamp = controller.calculateExpectedCheckpointStartTimestamp(i * 26);
                assertEq(checkpoint.startTimestamp, expectedTimestamp, "Checkpoint timestamp incorrect");
            }
        }
    }

    /* =================================================== */
    /*                 EVENTS                             */
    /* =================================================== */

    event CheckpointCreated(
        uint256 indexed startTimestamp,
        uint256 epochLength,
        uint256 emissionsReductionCliff,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionBasisPoints
    );
}
