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

interface ICoreEmissionsController {
    function epochLength() external view returns (uint256);
    function epochAtTimestamp(uint256 timestamp) external view returns (uint256);
    function epochEndTimestamp(uint256 epochNumber) external view returns (uint256);
    // function trustPerEpoch(uint256 epochNumber) external view returns (uint256);
    function emissionsAtEpoch(uint256 epochNumber) external view returns (uint256);
}
