// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { ICoreEmissionsController, EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract CoreEmissionsController is ICoreEmissionsController {
    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;

    uint256 public constant MAX_POSSIBLE_EPOCH_EMISSIONS = (INITIAL_SUPPLY * 750) / BASIS_POINTS_DIVISOR / 26; // ~2.88M
        // tokens per epoch

    uint256 public constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000; // 10% reduction per cliff

    /* =================================================== */
    /*                     STORAGE                         */
    /* =================================================== */

    uint256 internal EMISSIONS_START_TIMESTAMP;

    /// @notice Array of emissions checkpoints, sorted by startTimestamp
    EmissionsCheckpoint[] public checkpoints;

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error CoreEmissionsController_InvalidReductionBasisPoints();
    error CoreEmissionsController_InvalidCliff();
    error CoreEmissionsController_NoCheckpoints();
    error CoreEmissionsController_CheckpointInPast();
    error CoreEmissionsController_CheckpointExists();
    error CoreEmissionsController_InvalidCheckpointOrder();
    error CoreEmissionsController_ExcessiveEmissions();

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    event CheckpointCreated(
        uint256 indexed startTimestamp,
        uint256 epochLength,
        uint256 emissionsReductionCliff,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionBasisPoints
    );

    /* =================================================== */
    /*                 INITIALIZATION                      */
    /* =================================================== */

    function _initCoreEmissionsController(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    )
        internal
    {
        EMISSIONS_START_TIMESTAMP = startTimestamp;

        // Create initial checkpoint
        _createCheckpoint(
            startTimestamp, emissionsLength, emissionsReductionCliff, emissionsPerEpoch, emissionsReductionBasisPoints
        );
    }

    /* =================================================== */
    /*                  MAIN FUNCTIONS                     */
    /* =================================================== */

    function currentEpochEmissions() external view returns (uint256) {
        return _calculateCurrentEpochEmissions();
    }

    function currentEpoch() external view returns (uint256) {
        return _currentEpoch();
    }

    function _currentEpoch() internal view returns (uint256) {
        if (block.timestamp < EMISSIONS_START_TIMESTAMP) {
            return 0;
        }

        return _calculateTotalEpochsToTimestamp(block.timestamp);
    }

    function _calculateCurrentEpochEmissions() internal view returns (uint256) {
        return _calculateEpochEmissionsAt(block.timestamp);
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function epochLength() external view returns (uint256) {
        if (checkpoints.length == 0) {
            revert CoreEmissionsController_NoCheckpoints();
        }
        return _findCheckpointForTimestamp(block.timestamp).emissionsLength;
    }

    function getCheckpointCount() external view returns (uint256) {
        return checkpoints.length;
    }

    function getCheckpoint(uint256 index) external view returns (EmissionsCheckpoint memory) {
        require(index < checkpoints.length, "Checkpoint index out of bounds");
        return checkpoints[index];
    }

    function getCurrentCheckpoint() external view returns (EmissionsCheckpoint memory) {
        return _findCheckpointForTimestamp(block.timestamp);
    }

    function getAllCheckpoints() external view returns (EmissionsCheckpoint[] memory) {
        return checkpoints;
    }

    function previewEmissionsAt(uint256 timestamp) external view returns (uint256) {
        return _calculateEpochEmissionsAt(timestamp);
    }

    /**
     * @notice Get the current epoch number
     * @return Current epoch number (0-indexed)
     */
    function getCurrentEpochNumber() external view returns (uint256) {
        return _currentEpoch();
    }

    /**
     * @notice Calculate the epoch number for a given timestamp
     * @param timestamp The timestamp to calculate epoch for
     * @return The cumulative epoch number (0-indexed) at that timestamp
     */
    function epochAtTimestamp(uint256 timestamp) external view returns (uint256) {
        return _calculateTotalEpochsToTimestamp(timestamp);
    }

    /**
     * @notice Calculate the end timestamp for a given epoch number
     * @param epochNumber The epoch number to get end timestamp for
     * @return The timestamp when the given epoch ends
     */
    function epochEndTimestamp(uint256 epochNumber) external view returns (uint256) {
        uint256 startTimestamp = _calculateTimestampForEpoch(epochNumber);
        // Find the checkpoint that contains this epoch
        EmissionsCheckpoint memory checkpoint = _findCheckpointForTimestamp(startTimestamp);

        // Calculate the end timestamp by adding the epoch length
        return startTimestamp + checkpoint.emissionsLength;
    }

    /**
     * @notice Calculate emissions for a specific epoch number
     * @param epochNumber The epoch number to calculate for
     * @return Emissions amount for that epoch
     */
    function epochEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256) {
        return _epochEmissionsAtEpoch(epochNumber);
    }

    function _epochEmissionsAtEpoch(uint256 epochNumber) internal view returns (uint256) {
        uint256 epochTimestamp = _calculateTimestampForEpoch(epochNumber);
        return _calculateEpochEmissionsAt(epochTimestamp);
    }

    /* =================================================== */
    /*                 CORE CALCULATIONS                   */
    /* =================================================== */

    /**
     * @notice Calculate epoch emissions for any given timestamp
     * @param timestamp The timestamp to calculate emissions for
     * @return Emissions amount for the epoch containing the timestamp
     */
    function _calculateEpochEmissionsAt(uint256 timestamp) internal view returns (uint256) {
        if (checkpoints.length == 0 || timestamp < checkpoints[0].startTimestamp) {
            return 0;
        }

        // Find the relevant checkpoint using binary search
        EmissionsCheckpoint memory checkpoint = _findCheckpointForTimestamp(timestamp);

        // Calculate current epoch number based on timestamp
        uint256 currentEpochNumber = _calculateEpochNumber(timestamp, checkpoint);

        // Calculate checkpoint start epoch number
        uint256 checkpointStartEpoch = _calculateEpochNumber(checkpoint.startTimestamp, checkpoint);

        // Calculate how many complete cliff periods have passed since this checkpoint
        uint256 epochsSinceCheckpoint = currentEpochNumber - checkpointStartEpoch;
        uint256 cliffsSinceCheckpoint = epochsSinceCheckpoint / checkpoint.emissionsReductionCliff;

        // Apply cliff reductions to base emissions
        return _applyCliffReductions(checkpoint.emissionsPerEpoch, checkpoint.retentionFactor, cliffsSinceCheckpoint);
    }

    /**
     * @notice Calculate epoch number for a given timestamp using checkpoint's emission length
     * @param timestamp The timestamp to calculate epoch for
     * @param checkpoint The checkpoint containing emission parameters
     * @return The epoch number (0-indexed)
     */
    /**
     * @notice Calculate total cumulative epoch number across all checkpoints to a given timestamp
     * @param timestamp The timestamp to calculate total epochs for
     * @return Total cumulative epoch number (0-indexed)
     */
    function _calculateTotalEpochsToTimestamp(uint256 timestamp) internal view returns (uint256) {
        if (checkpoints.length == 0 || timestamp < EMISSIONS_START_TIMESTAMP) {
            return 0;
        }

        uint256 totalEpochs = 0;
        uint256 currentTimestamp = EMISSIONS_START_TIMESTAMP;

        for (uint256 i = 0; i < checkpoints.length; i++) {
            EmissionsCheckpoint memory checkpoint = checkpoints[i];

            // Determine the end timestamp for this checkpoint period
            uint256 checkpointEndTimestamp;
            if (i == checkpoints.length - 1) {
                // Last checkpoint: use the target timestamp
                checkpointEndTimestamp = timestamp;
            } else {
                // Not last checkpoint: use next checkpoint start or target timestamp, whichever is earlier
                checkpointEndTimestamp =
                    timestamp < checkpoints[i + 1].startTimestamp ? timestamp : checkpoints[i + 1].startTimestamp;
            }

            // If target timestamp is before this checkpoint, we're done
            if (timestamp < checkpoint.startTimestamp) {
                break;
            }

            // Calculate epochs in this checkpoint period
            uint256 periodStartTimestamp =
                checkpoint.startTimestamp > currentTimestamp ? checkpoint.startTimestamp : currentTimestamp;

            if (checkpointEndTimestamp > periodStartTimestamp) {
                uint256 epochsInPeriod = (checkpointEndTimestamp - periodStartTimestamp) / checkpoint.emissionsLength;
                totalEpochs += epochsInPeriod;
            }

            // Update current timestamp for next iteration
            currentTimestamp = checkpointEndTimestamp;

            // If we've reached the target timestamp, we're done
            if (currentTimestamp >= timestamp) {
                break;
            }
        }

        return totalEpochs;
    }

    /**
     * @notice Calculate epoch number for a given timestamp using checkpoint's emission length
     * @param timestamp The timestamp to calculate epoch for
     * @param checkpoint The checkpoint containing emission parameters
     * @return The epoch number (0-indexed)
     */
    function _calculateEpochNumber(
        uint256 timestamp,
        EmissionsCheckpoint memory checkpoint
    )
        internal
        view
        returns (uint256)
    {
        if (timestamp < EMISSIONS_START_TIMESTAMP) {
            return 0;
        }
        return (timestamp - EMISSIONS_START_TIMESTAMP) / checkpoint.emissionsLength;
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
     * @notice Find the most recent checkpoint applicable to the given timestamp
     * @param timestamp The timestamp to find checkpoint for
     * @return The applicable checkpoint
     */
    function _findCheckpointForTimestamp(uint256 timestamp) internal view returns (EmissionsCheckpoint memory) {
        if (checkpoints.length == 0) {
            revert CoreEmissionsController_NoCheckpoints();
        }

        // Binary search for the checkpoint
        uint256 left = 0;
        uint256 right = checkpoints.length - 1;
        uint256 result = 0;

        while (left <= right) {
            uint256 mid = left + (right - left) / 2;

            if (checkpoints[mid].startTimestamp <= timestamp) {
                result = mid;
                if (mid == type(uint256).max) break; // Prevent underflow
                left = mid + 1;
            } else {
                if (mid == 0) break; // Prevent underflow
                right = mid - 1;
            }
        }

        return checkpoints[result];
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

    /* =================================================== */
    /*                CHECKPOINT MANAGEMENT                */
    /* =================================================== */

    function _createCheckpoint(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsReductionCliff,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionBasisPoints
    )
        internal
    {
        _validateReductionBasisPoints(emissionsReductionBasisPoints);
        _validateCliff(emissionsReductionCliff);

        // Ensure chronological order
        if (checkpoints.length > 0 && startTimestamp <= checkpoints[checkpoints.length - 1].startTimestamp) {
            revert CoreEmissionsController_InvalidCheckpointOrder();
        }

        uint256 retentionFactor = BASIS_POINTS_DIVISOR - emissionsReductionBasisPoints;

        checkpoints.push(
            EmissionsCheckpoint({
                startTimestamp: startTimestamp,
                emissionsLength: emissionsLength,
                emissionsReductionCliff: emissionsReductionCliff,
                emissionsPerEpoch: emissionsPerEpoch,
                emissionsReductionBasisPoints: emissionsReductionBasisPoints,
                retentionFactor: retentionFactor
            })
        );

        emit CheckpointCreated(
            startTimestamp, emissionsLength, emissionsReductionCliff, emissionsPerEpoch, emissionsReductionBasisPoints
        );
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

    /**
     * @notice Calculate the timestamp for a given epoch number across all checkpoints
     * @param epochNumber The epoch number to find timestamp for
     * @return The timestamp when the given epoch starts
     */
    function _calculateTimestampForEpoch(uint256 epochNumber) internal view returns (uint256) {
        if (checkpoints.length == 0 || epochNumber == 0) {
            return EMISSIONS_START_TIMESTAMP;
        }

        uint256 remainingEpochs = epochNumber;
        uint256 currentTimestamp = EMISSIONS_START_TIMESTAMP;

        for (uint256 i = 0; i < checkpoints.length; i++) {
            EmissionsCheckpoint memory checkpoint = checkpoints[i];

            // Determine how many epochs are available in this checkpoint period
            uint256 epochsInPeriod;
            if (i == checkpoints.length - 1) {
                // Last checkpoint: calculate epochs needed to reach target
                epochsInPeriod = remainingEpochs;
            } else {
                // Not last checkpoint: calculate max epochs in this period
                uint256 periodDuration = checkpoints[i + 1].startTimestamp - checkpoint.startTimestamp;
                uint256 maxEpochsInPeriod = periodDuration / checkpoint.emissionsLength;
                epochsInPeriod = remainingEpochs < maxEpochsInPeriod ? remainingEpochs : maxEpochsInPeriod;
            }

            // If we can satisfy remaining epochs in this checkpoint period
            if (remainingEpochs <= epochsInPeriod) {
                return checkpoint.startTimestamp + uint256(remainingEpochs * checkpoint.emissionsLength);
            }

            // Move to next checkpoint period
            remainingEpochs -= epochsInPeriod;
            if (i < checkpoints.length - 1) {
                currentTimestamp = checkpoints[i + 1].startTimestamp;
            }
        }

        // If we get here, the epoch number is beyond all checkpoints
        // Return timestamp based on the last checkpoint's epoch length
        EmissionsCheckpoint memory lastCheckpoint = checkpoints[checkpoints.length - 1];
        return lastCheckpoint.startTimestamp + uint256(remainingEpochs * lastCheckpoint.emissionsLength);
    }
}
