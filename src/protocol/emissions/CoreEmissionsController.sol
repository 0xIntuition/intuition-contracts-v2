// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";

contract CoreEmissionsController is ICoreEmissionsController {
    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @dev Divisor for basis point calculations (100% = 10,000 basis points)
    uint256 internal constant BASIS_POINTS_DIVISOR = 10_000;

    /// @dev Initial supply of TRUST tokens (1 billion tokens with 18 decimals)
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;

    /// @dev Maximum allowed cliff reduction in basis points (10% = 1000 basis points)
    uint256 internal constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000;

    /* =================================================== */
    /*                        STORAGE                      */
    /* =================================================== */

    /// @dev Timestamp when emissions schedule begins
    uint256 internal START_TIMESTAMP;

    /// @dev Duration of each epoch in seconds
    uint256 internal EPOCH_LENGTH;

    /// @dev Base amount of TRUST tokens emitted per epoch
    uint256 internal EMISSIONS_PER_EPOCH;

    /// @dev Number of epochs between emissions reductions
    uint256 internal EMISSIONS_REDUCTION_CLIFF;

    /// @dev Percentage reduction applied at each cliff in basis points
    uint256 internal EMISSIONS_REDUCTION_BASIS_POINTS;

    /// @dev Factor used to calculate retained emissions after reduction (10000 - reduction_basis_points)
    uint256 internal EMISSIONS_RETENTION_FACTOR;

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @dev Thrown when reduction basis points exceed the maximum allowed value
    error CoreEmissionsController_InvalidReductionBasisPoints();
    /// @dev Thrown when cliff value is zero or exceeds 365 epochs
    error CoreEmissionsController_InvalidCliff();

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
        _validateReductionBasisPoints(emissionsReductionBasisPoints);
        _validateCliff(emissionsReductionCliff);

        START_TIMESTAMP = startTimestamp;
        EPOCH_LENGTH = emissionsLength;
        EMISSIONS_PER_EPOCH = emissionsPerEpoch;
        EMISSIONS_REDUCTION_CLIFF = emissionsReductionCliff;
        EMISSIONS_REDUCTION_BASIS_POINTS = emissionsReductionBasisPoints;
        EMISSIONS_RETENTION_FACTOR = BASIS_POINTS_DIVISOR - emissionsReductionBasisPoints;

        emit Initialized(
            startTimestamp, emissionsLength, emissionsPerEpoch, emissionsReductionCliff, emissionsReductionBasisPoints
        );
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc ICoreEmissionsController
    function getStartTimestamp() external view returns (uint256) {
        return START_TIMESTAMP;
    }

    /// @inheritdoc ICoreEmissionsController
    function getEpochLength() external view returns (uint256) {
        return EPOCH_LENGTH;
    }

    /// @inheritdoc ICoreEmissionsController
    function epochLength() external view returns (uint256) {
        return EPOCH_LENGTH;
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
        uint256 cliffsPassed = epoch / EMISSIONS_REDUCTION_CLIFF;

        // Apply cliff reductions to base emissions
        return _applyCliffReductions(EMISSIONS_PER_EPOCH, EMISSIONS_RETENTION_FACTOR, cliffsPassed);
    }

    function _currentEpoch() internal view returns (uint256) {
        if (block.timestamp < START_TIMESTAMP) {
            return 0;
        }

        return _calculateTotalEpochsToTimestamp(block.timestamp);
    }

    function _calculateEpochTimestampStart(uint256 epoch) internal view returns (uint256) {
        return START_TIMESTAMP + (epoch * EPOCH_LENGTH);
    }

    function _calculateEpochTimestampEnd(uint256 epoch) internal view returns (uint256) {
        return START_TIMESTAMP + (epoch * EPOCH_LENGTH) + EPOCH_LENGTH;
    }

    /**
     * @notice Calculate epoch emissions for any given timestamp
     * @param timestamp The timestamp to calculate emissions for
     * @return Emissions amount for the epoch containing the timestamp
     */
    function _calculateEpochEmissionsAt(uint256 timestamp) internal view returns (uint256) {
        if (timestamp < START_TIMESTAMP) {
            return 0;
        }

        // Calculate current epoch number
        uint256 currentEpochNumber = (timestamp - START_TIMESTAMP) / EPOCH_LENGTH;

        // Calculate how many complete cliff periods have passed
        uint256 cliffsPassed = currentEpochNumber / EMISSIONS_REDUCTION_CLIFF;

        // Apply cliff reductions to base emissions
        return _applyCliffReductions(EMISSIONS_PER_EPOCH, EMISSIONS_RETENTION_FACTOR, cliffsPassed);
    }

    function _calculateTotalEpochsToTimestamp(uint256 timestamp) internal view returns (uint256) {
        if (timestamp < START_TIMESTAMP) {
            return 0;
        }

        return (timestamp - START_TIMESTAMP) / EPOCH_LENGTH;
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
        if (cliffsToApply == 0) {
            return baseEmissions;
        }

        // Apply compound reduction: emissions * (retentionFactor / 10000)^cliffs
        uint256 numerator = _pow(retentionFactor, cliffsToApply);
        uint256 denominator = _pow(BASIS_POINTS_DIVISOR, cliffsToApply);

        return (baseEmissions * numerator) / denominator;
    }

    /**
     * @notice Calculates base^exponent using binary exponentiation for O(log n) complexity
     * @param base The base number
     * @param exponent The exponent
     * @return result The result of base^exponent
     */
    function _pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        if (exponent == 0) {
            return 1;
        }

        uint256 result = 1;
        uint256 currentBase = base;

        // Use binary exponentiation for O(log n) complexity
        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = result * currentBase;
            }
            currentBase = currentBase * currentBase;
            exponent >>= 1; // Right shift by 1 (divide by 2)
        }

        return result;
    }
}
