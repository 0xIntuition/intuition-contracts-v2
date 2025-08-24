// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import "src/protocol/emissions/CoreEmissionsController.sol";

/**
 * @title CoreEmissionsControllerMock
 * @notice Mock contract exposing internal functions for testing
 */
contract CoreEmissionsControllerMock is CoreEmissionsController {
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
        _initCoreEmissionsController(
            startTimestamp, emissionsLength, emissionsPerEpoch, emissionsReductionCliff, emissionsReductionBasisPoints
        );
    }

    function createCheckpoint(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsReductionCliff,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionBasisPoints
    )
        external
    {
        _createCheckpoint(
            startTimestamp, emissionsLength, emissionsReductionCliff, emissionsPerEpoch, emissionsReductionBasisPoints
        );
    }

    function calculateEpochEmissionsAt(uint256 timestamp) external view returns (uint256) {
        return _calculateEpochEmissionsAt(timestamp);
    }

    function calculateCurrentEpochEmissions() external view returns (uint256) {
        return _calculateCurrentEpochEmissions();
    }

    function findCheckpointForTimestamp(uint256 timestamp) external view returns (EmissionsCheckpoint memory) {
        return _findCheckpointForTimestamp(timestamp);
    }

    function calculateTotalEpochsToTimestamp(uint256 timestamp) external view returns (uint256) {
        return _calculateTotalEpochsToTimestamp(timestamp);
    }

    function calculateTimestampForEpoch(uint256 epochNumber) external view returns (uint256) {
        return _calculateTimestampForEpoch(epochNumber);
    }

    function calculateEpochEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256) {
        return _epochEmissionsAtEpoch(epochNumber);
    }

    function calculateEpochNumber(
        uint256 timestamp,
        EmissionsCheckpoint memory checkpoint
    )
        external
        view
        returns (uint256)
    {
        return _calculateEpochNumber(timestamp, checkpoint);
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

    function getEmissionsStartTimestamp() external view returns (uint256) {
        return EMISSIONS_START_TIMESTAMP;
    }

    function setEmissionsStartTimestamp(uint256 timestamp) external {
        EMISSIONS_START_TIMESTAMP = timestamp;
    }

    function clearCheckpoints() external {
        delete checkpoints;
    }

    function getCheckpointsLength() external view returns (uint256) {
        return checkpoints.length;
    }

    function addMockCheckpoint(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints,
        uint256 retentionFactor
    )
        external
    {
        checkpoints.push(
            EmissionsCheckpoint({
                startTimestamp: startTimestamp,
                emissionsLength: emissionsLength,
                emissionsPerEpoch: emissionsPerEpoch,
                emissionsReductionCliff: emissionsReductionCliff,
                emissionsReductionBasisPoints: emissionsReductionBasisPoints,
                retentionFactor: retentionFactor
            })
        );
    }

    /* =================================================== */
    /*            EPOCH UTILITY FUNCTIONS                 */
    /* =================================================== */

    function getEpochStartTimestamp(uint256 epochNumber) external view returns (uint256) {
        return _calculateTimestampForEpoch(epochNumber);
    }

    function getCurrentEpochStartTimestamp() external view returns (uint256) {
        uint256 currentEpoch = _currentEpoch();
        return _calculateTimestampForEpoch(currentEpoch);
    }

    function getCurrentEpochEndTimestamp() external view returns (uint256) {
        uint256 currentEpoch = _currentEpoch();
        return this.epochEndTimestamp(currentEpoch);
    }

    function getEpochDuration(uint256 epochNumber) external view returns (uint256) {
        uint256 start = _calculateTimestampForEpoch(epochNumber);
        uint256 end = this.epochEndTimestamp(epochNumber);
        return end - start;
    }

    /* =================================================== */
    /*               SCENARIO HELPERS                      */
    /* =================================================== */

    function setupBiWeeklyScenario() external {
        // 2-week epochs, 26 epochs = 1 year, 10% reduction
        _initCoreEmissionsController({
            startTimestamp: uint256(block.timestamp),
            emissionsLength: 2 weeks,
            emissionsPerEpoch: 2_884_615 * 1e18, // ~2.88M tokens per epoch
            emissionsReductionCliff: 26, // 26 * 2 weeks = 52 weeks = 1 year
            emissionsReductionBasisPoints: 1000 // 10%
         });
    }

    function setupWeeklyScenario() external {
        // 1-week epochs, 52 epochs = 1 year, 10% reduction
        _initCoreEmissionsController({
            startTimestamp: uint256(block.timestamp),
            emissionsLength: 1 weeks,
            emissionsPerEpoch: 1_442_307 * 1e18, // ~1.44M tokens per epoch
            emissionsReductionCliff: 52, // 52 * 1 week = 52 weeks = 1 year
            emissionsReductionBasisPoints: 1000 // 10%
         });
    }

    function setupDailyScenario() external {
        // 1-day epochs, 365 epochs = 1 year, 10% reduction
        _initCoreEmissionsController({
            startTimestamp: uint256(block.timestamp),
            emissionsLength: 1 days,
            emissionsPerEpoch: 205_479 * 1e18, // ~205K tokens per epoch
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
        _initCoreEmissionsController({
            startTimestamp: uint256(block.timestamp),
            emissionsLength: emissionsLength,
            emissionsPerEpoch: emissionsPerEpoch,
            emissionsReductionCliff: emissionsReductionCliff,
            emissionsReductionBasisPoints: emissionsReductionBasisPoints
        });
    }
}
