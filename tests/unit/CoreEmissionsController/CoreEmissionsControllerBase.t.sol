// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CoreEmissionsControllerMock } from "tests/mocks/CoreEmissionsControllerMock.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

abstract contract CoreEmissionsControllerBase is Test {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    CoreEmissionsControllerMock internal controller;

    // Test constants
    uint256 internal constant BASIS_POINTS_DIVISOR = 10_000;
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;
    uint256 internal constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000; // 10%

    // Common test parameters
    uint256 internal constant DEFAULT_START_TIMESTAMP = 1;
    uint256 internal constant DEFAULT_EPOCH_LENGTH = 2 weeks;
    uint256 internal constant DEFAULT_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18; // 1M tokens
    uint256 internal constant DEFAULT_CLIFF = 26; // 26 epochs = ~1 year
    uint256 internal constant DEFAULT_REDUCTION_BP = 1000; // 10%

    // Time constants for easier reading
    uint256 internal constant ONE_HOUR = 1 hours;
    uint256 internal constant ONE_DAY = 3 days;
    uint256 internal constant ONE_WEEK = 1 weeks;
    uint256 internal constant TWO_WEEKS = 2 weeks;
    uint256 internal constant ONE_YEAR = 52 weeks;
    uint256 internal constant TWO_YEARS = 104 weeks;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual {
        controller = new CoreEmissionsControllerMock();
        vm.warp(DEFAULT_START_TIMESTAMP);
    }

    /* =================================================== */
    /*                  HELPER FUNCTIONS                   */
    /* =================================================== */

    function _initializeController() internal {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            DEFAULT_REDUCTION_BP
        );
    }

    function _initializeControllerWithParams(
        uint256 startTimestamp,
        uint256 epochLength,
        uint256 emissionsPerEpoch,
        uint256 cliff,
        uint256 reductionBp
    )
        internal
    {
        controller.initCoreEmissionsController(startTimestamp, epochLength, emissionsPerEpoch, cliff, reductionBp);
    }

    function _createCheckpoint(
        uint256 startTimestamp,
        uint256 epochLength,
        uint256 cliff,
        uint256 emissionsPerEpoch,
        uint256 reductionBp
    )
        internal
    {
        controller.createCheckpoint(startTimestamp, epochLength, cliff, emissionsPerEpoch, reductionBp);
    }

    function _createMockCheckpoint(
        uint256 startTimestamp,
        uint256 epochLength,
        uint256 emissionsPerEpoch,
        uint256 cliff,
        uint256 reductionBp
    )
        internal
        returns (EmissionsCheckpoint memory)
    {
        uint256 retentionFactor = BASIS_POINTS_DIVISOR - reductionBp;
        return EmissionsCheckpoint({
            startTimestamp: startTimestamp,
            emissionsLength: epochLength,
            emissionsPerEpoch: emissionsPerEpoch,
            emissionsReductionCliff: cliff,
            emissionsReductionBasisPoints: reductionBp,
            retentionFactor: retentionFactor
        });
    }

    function _warpToTimestamp(uint256 timestamp) internal {
        vm.warp(timestamp);
    }

    function _warpToEpochStart(uint256 epoch) internal {
        uint256 timestamp = controller.getEpochStartTimestamp(epoch);
        vm.warp(timestamp);
    }

    function _warpToEpochEnd(uint256 epoch) internal {
        uint256 endTimestamp = controller.epochEndTimestamp(epoch);
        vm.warp(endTimestamp - 1); // 1 second before end
    }

    function _warpByDuration(uint256 duration) internal {
        vm.warp(block.timestamp + duration);
    }

    function _assertApproxEqual(uint256 actual, uint256 expected, uint256 tolerance) internal {
        if (expected > actual) {
            assertLe(expected - actual, tolerance, "Actual value too low");
        } else {
            assertLe(actual - expected, tolerance, "Actual value too high");
        }
    }

    function _assertCheckpointEqual(EmissionsCheckpoint memory actual, EmissionsCheckpoint memory expected) internal {
        assertEq(actual.startTimestamp, expected.startTimestamp, "startTimestamp mismatch");
        assertEq(actual.emissionsLength, expected.emissionsLength, "emissionsLength mismatch");
        assertEq(actual.emissionsPerEpoch, expected.emissionsPerEpoch, "emissionsPerEpoch mismatch");
        assertEq(actual.emissionsReductionCliff, expected.emissionsReductionCliff, "cliff mismatch");
        assertEq(actual.emissionsReductionBasisPoints, expected.emissionsReductionBasisPoints, "reductionBp mismatch");
        assertEq(actual.retentionFactor, expected.retentionFactor, "retentionFactor mismatch");
    }

    /* =================================================== */
    /*              CALCULATION HELPERS                    */
    /* =================================================== */

    function _calculateExpectedEmissionsAfterCliffs(
        uint256 baseEmissions,
        uint256 reductionBp,
        uint256 cliffs
    )
        internal
        pure
        returns (uint256)
    {
        if (cliffs == 0) return baseEmissions;

        uint256 retentionFactor = BASIS_POINTS_DIVISOR - reductionBp;
        uint256 numerator = _powHelper(retentionFactor, cliffs);
        uint256 denominator = _powHelper(BASIS_POINTS_DIVISOR, cliffs);

        return (baseEmissions * numerator) / denominator;
    }

    function _powHelper(uint256 base, uint256 exponent) internal pure returns (uint256) {
        if (exponent == 0) return 1;

        uint256 result = 1;
        uint256 currentBase = base;

        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = result * currentBase;
            }
            currentBase = currentBase * currentBase;
            exponent >>= 1;
        }

        return result;
    }

    /* =================================================== */
    /*               SCENARIO BUILDERS                     */
    /* =================================================== */

    function _setupSingleCheckpointScenario() internal {
        _initializeController();
    }

    function _setupMultipleCheckpointScenario() internal {
        // Initial checkpoint: 2-week epochs, 1M per epoch, 26 epoch cliff, 10% reduction
        _initializeController();

        // Calculate correct start times for new checkpoints using proper epoch boundaries
        // Second checkpoint should start at epoch 26 (after 1 year = 26 * 2 weeks)
        uint256 secondCheckpointEpoch = 26;
        uint256 secondCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(secondCheckpointEpoch);
        _createCheckpoint(
            secondCheckpointStart,
            ONE_WEEK,
            52, // 52 weeks = 1 year
            500_000 * 1e18, // 500K tokens
            500 // 5%
        );

        // Third checkpoint should start at epoch 78 (26 from first period + 52 from second period)
        uint256 thirdCheckpointEpoch = 78;
        uint256 thirdCheckpointStart = controller.calculateExpectedCheckpointStartTimestamp(thirdCheckpointEpoch);
        _createCheckpoint(
            thirdCheckpointStart,
            ONE_DAY,
            365, // 365 days = 1 year
            100_000 * 1e18, // 100K tokens
            MAX_CLIFF_REDUCTION_BASIS_POINTS // 10% - max allowed
        );
    }

    function _setupEdgeCaseScenario() internal {
        // Very short epochs, high emissions, frequent cliffs
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            ONE_HOUR, // 1 hour epochs
            10_000 * 1e18, // 10K tokens per epoch
            24, // 24 hours = 1 day cliff
            100 // 1% reduction
        );
    }
}
