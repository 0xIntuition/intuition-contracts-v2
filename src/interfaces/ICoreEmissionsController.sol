// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

/**
 * @dev Initialization parameters for CoreEmissionsController
 * @param startTimestamp The timestamp when emissions begin
 * @param emissionsLength The length of each epoch in seconds
 * @param emissionsPerEpoch The base amount of TRUST tokens emitted per epoch
 * @param emissionsReductionCliff The number of epochs between emissions reductions
 * @param emissionsReductionBasisPoints The reduction percentage in basis points (100 = 1%)
 */
struct CoreEmissionsControllerInit {
    uint256 startTimestamp;
    uint256 emissionsLength;
    uint256 emissionsPerEpoch;
    uint256 emissionsReductionCliff;
    uint256 emissionsReductionBasisPoints;
}

/**
 * @dev Emissions checkpoint structure containing all emissions parameters
 * @param startTimestamp The timestamp when emissions begin
 * @param emissionsLength The length of each epoch in seconds
 * @param emissionsPerEpoch The base amount of TRUST tokens emitted per epoch
 * @param emissionsReductionCliff The number of epochs between emissions reductions
 * @param emissionsReductionBasisPoints The reduction percentage in basis points (100 = 1%)
 * @param retentionFactor The factor used to calculate reduced emissions (10000 - reductionBasisPoints)
 */
struct EmissionsCheckpoint {
    uint256 startTimestamp;
    uint256 emissionsLength;
    uint256 emissionsPerEpoch;
    uint256 emissionsReductionCliff;
    uint256 emissionsReductionBasisPoints;
    uint256 retentionFactor;
}

/**
 * @title ICoreEmissionsController
 * @author 0xIntuition
 * @notice Interface for the CoreEmissionsController that manages TRUST token emissions
 */
interface ICoreEmissionsController {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @dev Emitted when the CoreEmissionsController is initialized
     * @param startTimestamp The timestamp when emissions begin
     * @param emissionsLength The length of each epoch in seconds
     * @param emissionsPerEpoch The base amount of TRUST tokens emitted per epoch
     * @param emissionsReductionCliff The number of epochs between emissions reductions
     * @param emissionsReductionBasisPoints The reduction percentage in basis points
     */
    event Initialized(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    );

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @notice Thrown when reduction basis points exceed the maximum allowed value
    error CoreEmissionsController_InvalidReductionBasisPoints();

    /// @notice Thrown when cliff value is zero or exceeds 365 epochs
    error CoreEmissionsController_InvalidCliff();

    /// @notice Thrown when the start timestamp is in the past
    error CoreEmissionsController_InvalidTimestampStart();

    /// @notice Thrown when emissions per epoch is zero
    error CoreEmissionsController_InvalidEmissionsPerEpoch();

    /// @notice Thrown when epoch length is zero
    error CoreEmissionsController_InvalidEpochLength();

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    /**
     * @notice Returns the timestamp when emissions started
     * @return The start timestamp of the emissions schedule
     */
    function getStartTimestamp() external view returns (uint256);

    /**
     * @notice Returns the length of each epoch in seconds
     * @return The epoch length in seconds
     */
    function getEpochLength() external view returns (uint256);

    /**
     * @notice Returns the current epoch number based on the current block timestamp
     * @return The current epoch number
     */
    function getCurrentEpoch() external view returns (uint256);

    /**
     * @notice Returns the start timestamp of the current epoch
     * @return The timestamp when the current epoch started
     */
    function getCurrentEpochTimestampStart() external view returns (uint256);

    /**
     * @notice Returns the emissions amount for the current epoch
     * @return The amount of TRUST tokens to emit for the current epoch
     */
    function getCurrentEpochEmissions() external view returns (uint256);

    /**
     * @notice Returns the start timestamp for a given epoch number
     * @param epochNumber The epoch number to query
     * @return The timestamp when the epoch starts
     */
    function getEpochTimestampStart(uint256 epochNumber) external view returns (uint256);

    /**
     * @notice Returns the end timestamp for a given epoch number
     * @param epochNumber The epoch number to query
     * @return The timestamp when the epoch ends
     */
    function getEpochTimestampEnd(uint256 epochNumber) external view returns (uint256);

    /**
     * @notice Returns the epoch number for a given timestamp
     * @param timestamp The timestamp to query
     * @return The epoch number corresponding to the timestamp
     */
    function getEpochAtTimestamp(uint256 timestamp) external view returns (uint256);

    /**
     * @notice Returns the number of TRUST tokens to be emitted for a given epoch
     * @param epochNumber The epoch number to query
     * @return The amount of TRUST tokens to emit for the epoch
     */
    function getEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256);

    /// @notice Returns the number of TRUST tokens to be emitted at a given timestamp
    /// @param timestamp The timestamp to query
    /// @return The amount of TRUST tokens to emit at the timestamp
    function getEmissionsAtTimestamp(uint256 timestamp) external view returns (uint256);
}
