// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";

contract CoreEmissionsController is ICoreEmissionsController {
    using FixedPointMathLib for uint256;

    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @dev Divisor for basis point calculations (100% = 10,000 basis points)
    uint256 internal constant BASIS_POINTS_DIVISOR = 10_000;

    /// @dev Maximum allowed cliff reduction in basis points (10% = 1000 basis points)
    uint256 internal constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000;

    /* =================================================== */
    /*                        STORAGE                      */
    /* =================================================== */

    /// @dev Timestamp when emissions schedule begins
    uint256 internal _START_TIMESTAMP;

    /// @dev Duration of each epoch in seconds
    uint256 internal _EPOCH_LENGTH;

    /// @dev Base amount of TRUST tokens emitted per epoch
    uint256 internal _EMISSIONS_PER_EPOCH;

    /// @dev Number of epochs between emissions reductions
    uint256 internal _EMISSIONS_REDUCTION_CLIFF;

    /// @dev Factor used to calculate retained emissions after reduction (10000 - reduction_basis_points)
    uint256 internal _EMISSIONS_RETENTION_FACTOR;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                 INITIALIZATION                      */
    /* =================================================== */

    function __CoreEmissionsController_init(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    )
        internal
    {
        _validateTimestampStart(startTimestamp);
        _validateEmissionsPerEpoch(emissionsPerEpoch);
        _validateCliff(emissionsReductionCliff);
        _validateReductionBasisPoints(emissionsReductionBasisPoints);

        _START_TIMESTAMP = startTimestamp;
        _EPOCH_LENGTH = emissionsLength;
        _EMISSIONS_PER_EPOCH = emissionsPerEpoch;
        _EMISSIONS_REDUCTION_CLIFF = emissionsReductionCliff;
        _EMISSIONS_RETENTION_FACTOR = BASIS_POINTS_DIVISOR - emissionsReductionBasisPoints;

        emit Initialized(
            startTimestamp, emissionsLength, emissionsPerEpoch, emissionsReductionCliff, emissionsReductionBasisPoints
        );
    }

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    /// @inheritdoc ICoreEmissionsController
    function getStartTimestamp() external view returns (uint256) {
        return _START_TIMESTAMP;
    }

    /// @inheritdoc ICoreEmissionsController
    function getEpochLength() external view returns (uint256) {
        return _EPOCH_LENGTH;
    }

    /// @inheritdoc ICoreEmissionsController
    function getCurrentEpoch() external view returns (uint256) {
        return _currentEpoch();
    }

    /// @inheritdoc ICoreEmissionsController
    function getEpochAtTimestamp(uint256 timestamp) external view returns (uint256) {
        return _calculateTotalEpochsToTimestamp(timestamp);
    }

    /// @inheritdoc ICoreEmissionsController
    function getEpochTimestampStart(uint256 epochNumber) external view returns (uint256) {
        return _calculateEpochTimestampStart(epochNumber);
    }

    /// @inheritdoc ICoreEmissionsController
    function getEpochTimestampEnd(uint256 epochNumber) external view returns (uint256) {
        return _calculateEpochTimestampEnd(epochNumber);
    }

    /// @inheritdoc ICoreEmissionsController
    function getCurrentEpochTimestampStart() external view returns (uint256) {
        uint256 currentEpoch = _currentEpoch();
        return _calculateEpochTimestampStart(currentEpoch);
    }

    /// @inheritdoc ICoreEmissionsController
    function getEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256) {
        return _emissionsAtEpoch(epochNumber);
    }

    /// @inheritdoc ICoreEmissionsController
    function getEmissionsAtTimestamp(uint256 timestamp) external view returns (uint256) {
        return _calculateEpochEmissionsAt(timestamp);
    }

    /// @inheritdoc ICoreEmissionsController
    function getCurrentEpochEmissions() external view returns (uint256) {
        return _calculateEpochEmissionsAt(block.timestamp);
    }

    /* =================================================== */
    /*                   VALIDATION                        */
    /* =================================================== */

    function _validateEmissionsPerEpoch(uint256 emissionsPerEpoch) internal pure {
        if (emissionsPerEpoch == 0) {
            revert CoreEmissionsController_InvalidEmissionsPerEpoch();
        }
    }

    function _validateTimestampStart(uint256 timestampStart) internal view {
        if (timestampStart < block.timestamp) {
            revert CoreEmissionsController_InvalidTimestampStart();
        }
    }

    function _validateReductionBasisPoints(uint256 emissionsReductionBasisPoints) internal pure {
        if (emissionsReductionBasisPoints > MAX_CLIFF_REDUCTION_BASIS_POINTS) {
            revert CoreEmissionsController_InvalidReductionBasisPoints();
        }
    }

    function _validateCliff(uint256 emissionsReductionCliff) internal pure {
        if (emissionsReductionCliff == 0 || emissionsReductionCliff > 365) {
            revert CoreEmissionsController_InvalidCliff();
        }
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    function _emissionsAtEpoch(uint256 epoch) internal view returns (uint256) {
        // Calculate how many complete cliff periods have passed
        uint256 cliffsPassed = epoch / _EMISSIONS_REDUCTION_CLIFF;

        // Apply cliff reductions to base emissions
        return _applyCliffReductions(_EMISSIONS_PER_EPOCH, _EMISSIONS_RETENTION_FACTOR, cliffsPassed);
    }

    function _currentEpoch() internal view returns (uint256) {
        if (block.timestamp < _START_TIMESTAMP) {
            return 0;
        }

        return _calculateTotalEpochsToTimestamp(block.timestamp);
    }

    function _calculateEpochTimestampStart(uint256 epoch) internal view returns (uint256) {
        return _START_TIMESTAMP + (epoch * _EPOCH_LENGTH);
    }

    function _calculateEpochTimestampEnd(uint256 epoch) internal view returns (uint256) {
        return _START_TIMESTAMP + (epoch * _EPOCH_LENGTH) + _EPOCH_LENGTH;
    }

    /**
     * @notice Calculate epoch emissions for any given timestamp
     * @param timestamp The timestamp to calculate emissions for
     * @return Emissions amount for the epoch containing the timestamp
     */
    function _calculateEpochEmissionsAt(uint256 timestamp) internal view returns (uint256) {
        if (timestamp < _START_TIMESTAMP) {
            return 0;
        }

        // Calculate current epoch number
        uint256 currentEpochNumber = _calculateTotalEpochsToTimestamp(timestamp);

        // Calculate how many complete cliff periods have passed
        uint256 cliffsPassed = currentEpochNumber / _EMISSIONS_REDUCTION_CLIFF;

        // Apply cliff reductions to base emissions
        return _applyCliffReductions(_EMISSIONS_PER_EPOCH, _EMISSIONS_RETENTION_FACTOR, cliffsPassed);
    }

    /**
     * @notice Calculate total epochs that have passed up to a given timestamp
     * @param timestamp The timestamp to calculate epochs for
     * @return Total number of complete epochs that have passed since start
     */
    function _calculateTotalEpochsToTimestamp(uint256 timestamp) internal view returns (uint256) {
        if (timestamp < _START_TIMESTAMP) {
            return 0;
        }

        return (timestamp - _START_TIMESTAMP) / _EPOCH_LENGTH;
    }

    /**
     * @notice Apply compound cliff reductions to base emissions
     * @param baseEmissions Starting emissions amount per epoch
     * @param retentionFactor Retention factor (10000 - reductionBasisPoints)
     * @param cliffsToApply Number of cliff reductions to apply
     * @return Final emissions after all cliff reductions
     */
    function _applyCliffReductions(
        uint256 baseEmissions,
        uint256 retentionFactor,
        uint256 cliffsToApply
    )
        internal
        pure
        returns (uint256)
    {
        if (cliffsToApply == 0) return baseEmissions;

        // Convert retentionFactor to WAD (1e18) ratio
        uint256 rWad = (retentionFactor * 1e18) / BASIS_POINTS_DIVISOR;

        // factorWad = rWad^cliffs (scaled by 1e18) - O(log n) time complexity thanks to FixedPointMathLib
        uint256 factorWad = FixedPointMathLib.rpow(rWad, cliffsToApply, 1e18);

        // baseEmissions * factorWad / 1e18
        return FixedPointMathLib.mulWad(baseEmissions, factorWad);
    }
}
