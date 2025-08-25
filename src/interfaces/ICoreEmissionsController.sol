// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

struct CoreEmissionsControllerInit {
    uint256 startTimestamp;
    uint256 emissionsLength;
    uint256 emissionsPerEpoch;
    uint256 emissionsReductionCliff;
    uint256 emissionsReductionBasisPoints;
}

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
    /**
     * @notice Returns the length of each epoch in seconds
     * @return The epoch length in seconds
     */
    function epochLength() external view returns (uint256);

    /**
     * @notice Returns the epoch number for a given timestamp
     * @param timestamp The timestamp to query
     * @return The epoch number corresponding to the timestamp
     */
    function epochAtTimestamp(uint256 timestamp) external view returns (uint256);

    /**
     * @notice Returns the end timestamp for a given epoch number
     * @param epochNumber The epoch number to query
     * @return The timestamp when the epoch ends
     */
    function epochEndTimestamp(uint256 epochNumber) external view returns (uint256);

    /**
     * @notice Returns the number of TRUST tokens to be emitted for a given epoch
     * @param epochNumber The epoch number to query
     * @return The amount of TRUST tokens to emit for the epoch
     */
    function emissionsAtEpoch(uint256 epochNumber) external view returns (uint256);
}
