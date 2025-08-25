// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract EdgeCasesAndErrorsTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*            VALIDATION ERROR TESTS                  */
    /* =================================================== */

    function testValidateReductionBasisPoints_RevertsOnExcess() public {
        vm.expectRevert();
        controller.validateReductionBasisPoints(MAX_CLIFF_REDUCTION_BASIS_POINTS + 1);

        vm.expectRevert();
        controller.validateReductionBasisPoints(5000); // 50%

        vm.expectRevert();
        controller.validateReductionBasisPoints(type(uint256).max);
    }

    function testValidateReductionBasisPoints_AcceptsValidValues() public {
        // Should not revert for valid values
        controller.validateReductionBasisPoints(0);
        controller.validateReductionBasisPoints(100); // 1%
        controller.validateReductionBasisPoints(500); // 5%
        controller.validateReductionBasisPoints(MAX_CLIFF_REDUCTION_BASIS_POINTS); // 10%
    }

    function testValidateCliff_RevertsOnInvalidValues() public {
        vm.expectRevert();
        controller.validateCliff(0); // Zero cliff

        vm.expectRevert();
        controller.validateCliff(366); // Too large

        vm.expectRevert();
        controller.validateCliff(type(uint256).max); // Way too large
    }

    function testValidateCliff_AcceptsValidValues() public {
        // Should not revert for valid values
        controller.validateCliff(1); // Minimum
        controller.validateCliff(26); // Common value
        controller.validateCliff(52); // Common value
        controller.validateCliff(365); // Maximum
    }

    /* =================================================== */
    /*          NO CHECKPOINTS ERROR TESTS                */
    /* =================================================== */

    function testNoCheckpoints_EpochLength() public {
        vm.expectRevert();
        controller.epochLength();
    }

    function testNoCheckpoints_FindCheckpointForTimestamp() public {
        vm.expectRevert();
        controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
    }

    function testNoCheckpoints_GetCurrentCheckpoint() public {
        vm.expectRevert();
        controller.getCurrentCheckpoint();
    }

    function testNoCheckpoints_CurrentEpoch() public {
        uint256 epoch = controller.currentEpoch();
        assertEq(epoch, 0, "Current epoch should be 0 with no checkpoints");
    }

    function testNoCheckpoints_CurrentEpochEmissions() public {
        uint256 emissions = controller.currentEpochEmissions();
        assertEq(emissions, 0, "Current emissions should be 0 with no checkpoints");
    }

    function testNoCheckpoints_EmissionsAtTimestamp() public {
        uint256 emissions = controller.emissionsAtTimestamp(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, 0, "Emissions should be 0 with no checkpoints");
    }

    /* =================================================== */
    /*           INITIALIZATION ERROR TESTS               */
    /* =================================================== */

    function testInitialization_InvalidReductionBasisPoints() public {
        vm.expectRevert();
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            MAX_CLIFF_REDUCTION_BASIS_POINTS + 1
        );
    }

    function testInitialization_InvalidCliff() public {
        vm.expectRevert();
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            0, // Invalid cliff
            DEFAULT_REDUCTION_BP
        );

        vm.expectRevert();
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            366, // Invalid cliff
            DEFAULT_REDUCTION_BP
        );
    }

    /* =================================================== */
    /*           CHECKPOINT ORDER ERROR TESTS             */
    /* =================================================== */

    function testCheckpointOrder_RejectsEqualTimestamp() public {
        _initializeController();

        vm.expectRevert();
        _createCheckpoint(
            DEFAULT_START_TIMESTAMP, // Same as initial
            ONE_WEEK,
            52,
            500_000 * 1e18,
            500
        );
    }

    function testCheckpointOrder_RejectsPastTimestamp() public {
        _initializeController();

        vm.expectRevert();
        _createCheckpoint(
            DEFAULT_START_TIMESTAMP - 1, // Before initial
            ONE_WEEK,
            52,
            500_000 * 1e18,
            500
        );
    }

    function testCheckpointOrder_RejectsOutOfOrder() public {
        _initializeController();

        // Create first checkpoint at proper epoch boundary
        uint256 firstCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(26); // epoch 26
        _createCheckpoint(firstCheckpointStart, ONE_WEEK, 52, 500_000 * 1e18, 500);

        // Try to create a second checkpoint that would violate chronological order
        // We need to create at an earlier epoch timestamp
        uint256 secondCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(13); // epoch 13, before
            // epoch 26

        // This should definitely be less than the first checkpoint start
        require(secondCheckpointStart < firstCheckpointStart, "Test setup error: epoch 13 should be before epoch 26");

        // This should fail due to chronological order check
        vm.expectRevert(abi.encodeWithSignature("CoreEmissionsController_InvalidCheckpointOrder()"));
        _createCheckpoint(secondCheckpointStart, ONE_WEEK, 52, 500_000 * 1e18, 500);
    }

    /* =================================================== */
    /*            EXTREME VALUE TESTS                     */
    /* =================================================== */

    function testExtremeValues_ZeroEmissionsPerEpoch() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            0, // Zero emissions
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, 0, "Zero emissions should remain zero");

        // Even after cliffs, should still be zero
        uint256 cliffTimestamp = DEFAULT_START_TIMESTAMP + (DEFAULT_CLIFF * DEFAULT_EPOCH_LENGTH);
        emissions = controller.calculateEpochEmissionsAt(cliffTimestamp);
        assertEq(emissions, 0, "Zero emissions should remain zero after cliff");
    }

    function testExtremeValues_MaxEmissionsPerEpoch() public {
        uint256 maxEmissions = type(uint128).max; // Large but not overflow-prone

        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP, DEFAULT_EPOCH_LENGTH, maxEmissions, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, maxEmissions, "Max emissions should be preserved");
    }

    function testExtremeValues_MinimumEpochLength() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            1, // 1 second epochs
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Minimum epoch length should work");

        // Test epoch calculation with minimum length
        EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
        uint256 epoch = controller.calculateEpochNumber(DEFAULT_START_TIMESTAMP + 100, checkpoint);
        assertEq(epoch, 100, "Should be epoch 100 with 1-second epochs");
    }

    function testExtremeValues_MaximumEpochLength() public {
        uint256 maxEpochLength = type(uint128).max;

        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP, maxEpochLength, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Maximum epoch length should work");
    }

    /* =================================================== */
    /*         TIMESTAMP EDGE CASES                       */
    /* =================================================== */

    function testTimestampEdgeCases_ZeroTimestamp() public {
        controller.initCoreEmissionsController(
            0, // Zero start timestamp
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(0);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Zero timestamp should work as start");

        emissions = controller.calculateEpochEmissionsAt(DEFAULT_EPOCH_LENGTH);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "First epoch from zero should work");
    }

    function testTimestampEdgeCases_LargeTimestamps() public {
        uint256 largeStart = type(uint128).max;

        controller.initCoreEmissionsController(
            largeStart, DEFAULT_EPOCH_LENGTH, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 emissions = controller.calculateEpochEmissionsAt(largeStart);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Large start timestamp should work");
    }

    function testTimestampEdgeCases_BeforeEmissionsStart() public {
        _initializeController();

        uint256 emissions = controller.calculateEpochEmissionsAt(0);
        assertEq(emissions, 0, "Emissions before start should be 0");

        emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP - 1);
        assertEq(emissions, 0, "Emissions just before start should be 0");
    }

    /* =================================================== */
    /*         OVERFLOW PROTECTION TESTS                  */
    /* =================================================== */

    function testOverflowProtection_PowerFunction() public {
        // Test power function with values that could cause overflow
        uint256 result;

        // These should not cause overflow
        result = controller.pow(2, 10);
        assertEq(result, 1024, "2^10 should be 1024");

        result = controller.pow(10, 5);
        assertEq(result, 100_000, "10^5 should be 100000");

        result = controller.pow(3, 20);
        assertEq(result, 3_486_784_401, "3^20 should be correct");

        // Edge case: base^0 should always be 1
        result = controller.pow(type(uint256).max, 0);
        assertEq(result, 1, "Any number to power 0 should be 1");
    }

    function testOverflowProtection_CliffReductions() public {
        // Test with values that could cause overflow in cliff calculations
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            1_000_000 * 1e18, // Large but reasonable emissions
            10, // Moderate cliff for multiple reductions
            100 // Small reduction to avoid rapid decay
        );

        // Test after several cliffs - should not overflow
        uint256 severalCliffs = 10;
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (severalCliffs * 10 * DEFAULT_EPOCH_LENGTH);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Should be reduced but not zero
        assertLt(emissions, 1_000_000 * 1e18, "Emissions should be reduced");
        assertGt(emissions, 0, "Emissions should not be zero after many reductions");
    }

    /* =================================================== */
    /*         PRECISION EDGE CASES                       */
    /* =================================================== */

    function testPrecisionEdgeCases_VerySmallReductions() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            1 // 0.01% reduction
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (DEFAULT_CLIFF * DEFAULT_EPOCH_LENGTH);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Should be very close to original emissions
        uint256 expectedEmissions = (DEFAULT_EMISSIONS_PER_EPOCH * 9999) / 10_000;
        assertEq(emissions, expectedEmissions, "Very small reduction should be precise");
    }

    function testPrecisionEdgeCases_CompoundSmallReductions() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            1_000_000 * 1e18, // Clean round number
            10, // Small cliff for multiple reductions
            50 // 0.5% reduction
        );

        // Test multiple small reductions
        for (uint256 i = 1; i <= 10; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * 10 * DEFAULT_EPOCH_LENGTH);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

            // Each reduction should be 0.5%
            uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(1_000_000 * 1e18, 50, i);

            assertEq(emissions, expectedEmissions, "Compound small reductions should be precise");
        }
    }

    /* =================================================== */
    /*            BOUNDARY CONDITION TESTS               */
    /* =================================================== */

    function testBoundaryConditions_EpochBoundaries() public {
        _initializeController();

        // Test exactly at epoch boundaries vs just before/after
        for (uint256 epoch = 1; epoch < 30; epoch++) {
            uint256 epochStart = DEFAULT_START_TIMESTAMP + (epoch * DEFAULT_EPOCH_LENGTH);
            uint256 epochBefore = epochStart - 1;
            uint256 epochAfter = epochStart + 1;

            uint256 emissionsBefore = controller.calculateEpochEmissionsAt(epochBefore);
            uint256 emissionsAt = controller.calculateEpochEmissionsAt(epochStart);
            uint256 emissionsAfter = controller.calculateEpochEmissionsAt(epochAfter);

            // Emissions within same epoch should be identical
            assertEq(emissionsAt, emissionsAfter, "Emissions at epoch start and after should be equal");

            // Before might be different if we crossed a cliff
            if (epoch % DEFAULT_CLIFF == 0) {
                // This is a cliff epoch, so before should be higher than at/after
                assertGt(emissionsBefore, emissionsAt, "Emissions should be higher before cliff");
            } else {
                // Not a cliff epoch, so all should be equal
                assertEq(emissionsBefore, emissionsAt, "Emissions should be equal within non-cliff epochs");
            }
        }
    }

    function testBoundaryConditions_CliffBoundaries() public {
        _initializeController();

        // Test exactly at cliff boundaries
        for (uint256 cliff = 1; cliff <= 5; cliff++) {
            uint256 cliffEpoch = cliff * DEFAULT_CLIFF;
            uint256 cliffTimestamp = DEFAULT_START_TIMESTAMP + (cliffEpoch * DEFAULT_EPOCH_LENGTH);

            uint256 beforeCliff = controller.calculateEpochEmissionsAt(cliffTimestamp - 1);
            uint256 atCliff = controller.calculateEpochEmissionsAt(cliffTimestamp);

            // Before cliff should be higher than at cliff
            assertGt(beforeCliff, atCliff, "Emissions before cliff should be higher");

            // At cliff should match expected reduced amount
            uint256 expectedEmissions =
                _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, cliff);
            assertEq(atCliff, expectedEmissions, "Emissions at cliff should match expected");
        }
    }

    /* =================================================== */
    /*            CONSISTENCY TESTS                       */
    /* =================================================== */

    function testConsistency_EmissionsNeverIncrease() public {
        _initializeController();

        uint256 previousEmissions = type(uint256).max;

        // Test over 5 years with various time steps
        for (uint256 i = 0; i < 5 * ONE_YEAR; i += ONE_DAY) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + i;
            uint256 currentEmissions = controller.calculateEpochEmissionsAt(timestamp);

            assertLe(currentEmissions, previousEmissions, "Emissions should never increase");
            previousEmissions = currentEmissions;
        }
    }

    function testConsistency_EpochCalculationMonotonic() public {
        _initializeController();

        EmissionsCheckpoint memory checkpoint = controller.findCheckpointForTimestamp(DEFAULT_START_TIMESTAMP);
        uint256 previousEpoch = 0;

        // Test epoch calculation is monotonically increasing
        for (uint256 i = 0; i < 100 * DEFAULT_EPOCH_LENGTH; i += ONE_HOUR) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + i;
            uint256 currentEpoch = controller.calculateEpochNumber(timestamp, checkpoint);

            assertGe(currentEpoch, previousEpoch, "Epochs should be monotonically increasing");
            previousEpoch = currentEpoch;
        }
    }

    /* =================================================== */
    /*            STRESS TESTS                            */
    /* =================================================== */

    function testStress_ManyEpochsCalculation() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            ONE_DAY, // Daily epochs (more reasonable than hourly)
            DEFAULT_EMISSIONS_PER_EPOCH,
            30, // Monthly cliffs
            50 // 0.5% reduction
        );

        // Test after 1 year of daily epochs
        uint256 timestamp = DEFAULT_START_TIMESTAMP + ONE_YEAR;
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Should be reduced but still positive
        assertLt(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions should be reduced");
        assertGt(emissions, 0, "Emissions should still be positive");
    }

    function testStress_FrequentCliffs() public {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            ONE_DAY,
            DEFAULT_EMISSIONS_PER_EPOCH,
            7, // Cliff every week (7 days)
            25 // 0.25% reduction
        );

        // Test after 10 weeks (10 cliffs)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (70 * ONE_DAY);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, 25, 10);

        assertEq(emissions, expectedEmissions, "Frequent cliffs should calculate correctly");
    }
}
