// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract CalculateEpochTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*          BASIC EPOCH CALCULATION TESTS             */
    /* =================================================== */

    function testCalculateEpoch_AtCheckpointStart() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 epoch = controller.calculateEpochNumber(DEFAULT_START_TIMESTAMP, checkpoint);
        assertEq(epoch, 0, "Epoch at checkpoint start should be 0");
    }

    function testCalculateEpoch_BeforeCheckpointStart() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 epoch = controller.calculateEpochNumber(DEFAULT_START_TIMESTAMP - 1, checkpoint);
        assertEq(epoch, 0, "Epoch before checkpoint start should be 0");
    }

    function testCalculateEpoch_OneEpochLater() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 oneEpochLater = DEFAULT_START_TIMESTAMP + TWO_WEEKS;
        uint256 epoch = controller.calculateEpochNumber(oneEpochLater, checkpoint);
        assertEq(epoch, 1, "One epoch later should be epoch 1");
    }

    function testCalculateEpoch_PartialEpoch() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 halfEpochLater = DEFAULT_START_TIMESTAMP + ONE_WEEK;
        uint256 epoch = controller.calculateEpochNumber(halfEpochLater, checkpoint);
        assertEq(epoch, 0, "Partial epoch should still be epoch 0");
    }

    function testCalculateEpoch_ExactEpochBoundary() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        // Test exactly at epoch boundaries
        for (uint256 i = 0; i < 10; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * TWO_WEEKS);
            uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
            assertEq(epoch, i, "Epoch at boundary should match expected");
        }
    }

    function testCalculateEpoch_JustBeforeEpochBoundary() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        // Test 1 second before epoch boundaries
        for (uint256 i = 1; i < 10; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * TWO_WEEKS) - 1;
            uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
            assertEq(epoch, i - 1, "Epoch just before boundary should be previous epoch");
        }
    }

    /* =================================================== */
    /*       DIFFERENT EPOCH LENGTH TESTS                 */
    /* =================================================== */

    function testCalculateEpoch_WithDailyEpochs() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP,
            ONE_DAY,
            DEFAULT_EMISSIONS_PER_EPOCH,
            365, // 365 days = 1 year
            DEFAULT_REDUCTION_BP
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (7 * ONE_DAY); // 7 days later
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        assertEq(epoch, 7, "Should be epoch 7 after 7 days");
    }

    function testCalculateEpoch_WithWeeklyEpochs() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP,
            ONE_WEEK,
            DEFAULT_EMISSIONS_PER_EPOCH,
            52, // 52 weeks = 1 year
            DEFAULT_REDUCTION_BP
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (10 * ONE_WEEK); // 10 weeks later
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        assertEq(epoch, 10, "Should be epoch 10 after 10 weeks");
    }

    function testCalculateEpoch_WithHourlyEpochs() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP,
            ONE_HOUR,
            DEFAULT_EMISSIONS_PER_EPOCH,
            24, // 24 hours = 1 day
            DEFAULT_REDUCTION_BP
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (48 * ONE_HOUR); // 48 hours later
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        assertEq(epoch, 48, "Should be epoch 48 after 48 hours");
    }

    /* =================================================== */
    /*          LARGE NUMBER TESTS                        */
    /* =================================================== */

    function testCalculateEpoch_LargeTimestamp() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        // Test after 10 years (approximately 260 epochs)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (10 * ONE_YEAR);
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        uint256 expectedEpoch = (10 * ONE_YEAR) / TWO_WEEKS;
        assertEq(epoch, expectedEpoch, "Large timestamp epoch calculation incorrect");
    }

    function testCalculateEpoch_VeryLargeTimestamp() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            1000, // Small start timestamp
            ONE_DAY,
            DEFAULT_EMISSIONS_PER_EPOCH,
            365,
            DEFAULT_REDUCTION_BP
        );

        // Test with very large timestamp (100 years from Unix epoch)
        uint256 timestamp = 100 * ONE_YEAR;
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        uint256 expectedEpoch = (timestamp - 1000) / ONE_DAY;
        assertEq(epoch, expectedEpoch, "Very large timestamp epoch calculation incorrect");
    }

    /* =================================================== */
    /*          DIFFERENT START TIMESTAMP TESTS           */
    /* =================================================== */

    function testCalculateEpoch_WithDifferentStartTimestamps() public {
        uint256[] memory startTimestamps = new uint256[](5);
        startTimestamps[0] = 100;
        startTimestamps[1] = 1_000_000;
        startTimestamps[2] = block.timestamp;
        startTimestamps[3] = block.timestamp + ONE_YEAR;
        startTimestamps[4] = type(uint128).max;

        for (uint256 i = 0; i < startTimestamps.length; i++) {
            uint256 startTimestamp = startTimestamps[i];

            EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
                startTimestamp, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
            );

            // Test at start
            uint256 epoch = controller.calculateEpochNumber(startTimestamp, checkpoint);
            assertEq(epoch, 0, "Epoch at start should be 0");

            // Test after one epoch
            if (startTimestamp <= type(uint256).max - TWO_WEEKS) {
                epoch = controller.calculateEpochNumber(startTimestamp + TWO_WEEKS, checkpoint);
                assertEq(epoch, 1, "Epoch after one period should be 1");
            }
        }
    }

    /* =================================================== */
    /*            PRECISION AND ROUNDING TESTS            */
    /* =================================================== */

    function testCalculateEpoch_RoundingDown() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP,
            1000, // 1000 seconds per epoch
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );

        // Test timestamps that should round down
        uint256[] memory offsets = new uint256[](4);
        offsets[0] = 999; // Just before first epoch boundary
        offsets[1] = 1999; // Just before second epoch boundary
        offsets[2] = 5500; // In middle of epoch 5
        offsets[3] = 9999; // Just before epoch 10 boundary

        uint256[] memory expectedEpochs = new uint256[](4);
        expectedEpochs[0] = 0;
        expectedEpochs[1] = 1;
        expectedEpochs[2] = 5;
        expectedEpochs[3] = 9;

        for (uint256 i = 0; i < offsets.length; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + offsets[i];
            uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
            assertEq(epoch, expectedEpochs[i], "Rounding down failed");
        }
    }

    /* =================================================== */
    /*            EDGE CASE TESTS                         */
    /* =================================================== */

    function testCalculateEpoch_MinimumEpochLength() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP,
            1, // 1 second per epoch
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + 100; // 100 seconds later
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        assertEq(epoch, 100, "Should be epoch 100 after 100 seconds with 1s epochs");
    }

    function testCalculateEpoch_MaximumValues() public {
        // Test with maximum reasonable values
        uint256 maxStartTime = type(uint128).max;
        uint256 maxEpochLength = type(uint128).max;

        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            maxStartTime, maxEpochLength, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 epoch = controller.calculateEpochNumber(maxStartTime, checkpoint);
        assertEq(epoch, 0, "Epoch at max start time should be 0");

        // Test one epoch later (if we don't overflow)
        if (maxStartTime <= type(uint256).max - maxEpochLength) {
            epoch = controller.calculateEpochNumber(maxStartTime + maxEpochLength, checkpoint);
            assertEq(epoch, 1, "One epoch later should be epoch 1");
        }
    }

    /* =================================================== */
    /*          CONSISTENCY TESTS                         */
    /* =================================================== */

    function testCalculateEpoch_ConsistencyAcrossTimeRange() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        // Test consistency over a large time range
        uint256 startTime = DEFAULT_START_TIMESTAMP;
        uint256 epochLength = TWO_WEEKS;

        for (uint256 i = 0; i < 100; i++) {
            uint256 timestamp = startTime + (i * epochLength);
            uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
            assertEq(epoch, i, "Epoch consistency check failed");

            // Also test timestamp in middle of epoch
            if (i > 0) {
                uint256 midEpochTimestamp = timestamp - (epochLength / 2);
                uint256 midEpoch = controller.calculateEpochNumber(midEpochTimestamp, checkpoint);
                assertEq(midEpoch, i - 1, "Mid-epoch consistency check failed");
            }
        }
    }

    function testCalculateEpoch_MonotonicIncreasing() public {
        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            DEFAULT_START_TIMESTAMP, TWO_WEEKS, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 previousEpoch = 0;
        uint256 timeStep = ONE_DAY; // 1 day steps

        for (uint256 i = 0; i < 365; i++) {
            // Test for 1 year
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * timeStep);
            uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);

            // Epoch should never decrease
            assertGe(epoch, previousEpoch, "Epoch should be monotonically increasing");
            previousEpoch = epoch;
        }
    }

    /* =================================================== */
    /*              FUZZ TESTS                            */
    /* =================================================== */

    function testFuzzCalculateEpoch_ValidInputs(
        uint128 startTimestamp,
        uint128 epochLength,
        uint128 timestampOffset
    )
        public
    {
        vm.assume(epochLength > 0);
        vm.assume(epochLength <= type(uint64).max); // Reasonable epoch length limit
        vm.assume(startTimestamp <= type(uint128).max / 2); // Prevent overflow
        vm.assume(timestampOffset <= type(uint128).max / 2); // Prevent overflow
        vm.assume(startTimestamp <= type(uint256).max - timestampOffset);

        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            startTimestamp, epochLength, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 timestamp = startTimestamp + timestampOffset;
        uint256 epoch = controller.calculateEpochNumber(timestamp, checkpoint);
        uint256 expectedEpoch = timestampOffset / epochLength;

        assertEq(epoch, expectedEpoch, "Fuzz test: epoch calculation incorrect");
    }

    function testFuzzCalculateEpoch_BeforeStart(
        uint128 startTimestamp,
        uint128 epochLength,
        uint128 timestampBefore
    )
        public
    {
        vm.assume(epochLength > 0);
        vm.assume(timestampBefore < startTimestamp);

        EmissionsCheckpoint memory checkpoint = _createMockCheckpoint(
            startTimestamp, epochLength, DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_CLIFF, DEFAULT_REDUCTION_BP
        );

        uint256 epoch = controller.calculateEpochNumber(timestampBefore, checkpoint);
        assertEq(epoch, 0, "Fuzz test: epoch before start should be 0");
    }
}
