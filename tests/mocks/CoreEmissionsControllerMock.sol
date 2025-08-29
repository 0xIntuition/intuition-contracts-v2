// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import "src/protocol/emissions/CoreEmissionsController.sol";

/**
 * @title CoreEmissionsControllerMock
 * @notice Mock contract exposing internal functions for testing
 */
contract CoreEmissionsControllerMock is CoreEmissionsController {
    // Common test parameters
    uint256 internal constant DEFAULT_START_TIMESTAMP = 1;
    uint256 internal constant DEFAULT_EPOCH_LENGTH = 2 weeks;
    uint256 internal constant DEFAULT_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18; // 1M tokens
    uint256 internal constant DEFAULT_REDUCTION_CLIFF = 26; // 26 epochs = ~1 year
    uint256 internal constant DEFAULT_REDUCTION_BASIS_POINTS = 1000; // 10%

    // Time constants for easier reading
    uint256 internal constant ONE_HOUR = 1 hours;
    uint256 internal constant ONE_DAY = 1 days;
    uint256 internal constant ONE_WEEK = 7 * ONE_DAY;
    uint256 internal constant TWO_WEEKS = 2 * ONE_WEEK;
    uint256 internal constant ONE_YEAR = 365 * ONE_DAY;
    uint256 internal constant TWO_YEARS = 2 * ONE_YEAR;

    /* =================================================== */
    /*            EXPOSED INTERNAL FUNCTIONS              */
    /* =================================================== */

    function initCoreEmissionsController(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    )
        external
    {
        __CoreEmissionsController_init(
            startTimestamp, emissionsLength, emissionsPerEpoch, emissionsReductionCliff, emissionsReductionBasisPoints
        );
    }

    function calculateEpochEmissionsAt(uint256 timestamp) external view returns (uint256) {
        return _calculateEpochEmissionsAt(timestamp);
    }

    function calculateTotalEpochsToTimestamp(uint256 timestamp) external view returns (uint256) {
        return _calculateTotalEpochsToTimestamp(timestamp);
    }

    function calculateEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256) {
        return _emissionsAtEpoch(epochNumber);
    }

    function applyCliffReductions(
        uint256 baseEmissions,
        uint256 retentionFactor,
        uint256 cliffsToApply
    )
        external
        pure
        returns (uint256)
    {
        return _applyCliffReductions(baseEmissions, retentionFactor, cliffsToApply);
    }

    function pow(uint256 base, uint256 exponent) external pure returns (uint256) {
        return _pow(base, exponent);
    }

    function validateReductionBasisPoints(uint256 emissionsReductionBasisPoints) external pure {
        _validateReductionBasisPoints(emissionsReductionBasisPoints);
    }

    function validateCliff(uint256 emissionsReductionCliff) external pure {
        _validateCliff(emissionsReductionCliff);
    }

    /* =================================================== */
    /*                TESTING UTILITIES                    */
    /* =================================================== */

    /* =================================================== */
    /*               SCENARIO HELPERS                      */
    /* =================================================== */

    function setupBiWeeklyScenario() external {
        // 2-week epochs, 26 epochs = 1 year, 10% reduction
        __CoreEmissionsController_init({
            startTimestamp: DEFAULT_START_TIMESTAMP,
            emissionsLength: TWO_WEEKS,
            emissionsPerEpoch: 1_000_000 * 1e18, // 1M tokens
            emissionsReductionCliff: 26, // 26 * 2 weeks = 52 weeks = 1 year
            emissionsReductionBasisPoints: 1000 // 10%
         });
    }

    function setupWeeklyScenario() external {
        // 1-week epochs, 52 epochs = 1 year, 10% reduction
        __CoreEmissionsController_init({
            startTimestamp: DEFAULT_START_TIMESTAMP,
            emissionsLength: ONE_WEEK,
            emissionsPerEpoch: 1_000_000 * 1e18, // 1M tokens
            emissionsReductionCliff: 52, // 52 * 1 week = 52 weeks = 1 year
            emissionsReductionBasisPoints: 1000 // 10%
         });
    }

    function setupDailyScenario() external {
        // 1-day epochs, 365 epochs = 1 year, 10% reduction
        __CoreEmissionsController_init({
            startTimestamp: DEFAULT_START_TIMESTAMP,
            emissionsLength: 1 days,
            emissionsPerEpoch: 1_000_000 * 1e18, // 1M tokens
            emissionsReductionCliff: 365, // 365 * 1 day = 365 days = 1 year
            emissionsReductionBasisPoints: 1000 // 10%
         });
    }

    function setupCustomScenario(
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    )
        external
    {
        __CoreEmissionsController_init({
            startTimestamp: DEFAULT_START_TIMESTAMP,
            emissionsLength: emissionsLength,
            emissionsPerEpoch: 1_000_000 * 1e18, // 1M tokens
            emissionsReductionCliff: emissionsReductionCliff,
            emissionsReductionBasisPoints: emissionsReductionBasisPoints
        });
    }
}
