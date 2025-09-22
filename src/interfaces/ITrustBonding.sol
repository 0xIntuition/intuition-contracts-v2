// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title  ITrustBonding
 * @author 0xIntuition
 * @notice Interface for the Intuition's TrustBondingV2 contract
 */
interface ITrustBonding {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when a user claims their accrued Trust rewards
     * @param user The user who claimed the rewards
     * @param recipient The address to which the rewards were sent
     * @param amount The amount of TRUST tokens minted as rewards
     */
    event RewardsClaimed(address indexed user, address indexed recipient, uint256 amount);

    /**
     * @notice Emitted when the MultiVault contract is set
     * @param multiVault The address of the MultiVault contract
     */
    event MultiVaultSet(address indexed multiVault);

    /**
     * @notice Emitted when the SatelliteEmissionsController contract is set
     * @param satelliteEmissionsController The address of the SatelliteEmissionsController contract
     */
    event SatelliteEmissionsControllerSet(address indexed satelliteEmissionsController);

    /**
     * @notice Emitted when the lower bound for the system utilization ratio is updated
     * @param newLowerBound The new lower bound for the system utilization ratio
     */
    event SystemUtilizationLowerBoundUpdated(uint256 newLowerBound);

    /**
     * @notice Emitted when the lower bound for the personal utilization ratio is updated
     * @param newLowerBound The new lower bound for the personal utilization ratio
     */
    event PersonalUtilizationLowerBoundUpdated(uint256 newLowerBound);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @dev Thrown when attempting to claim protocol fees that exceed the available balance
    error TrustBonding_ClaimableProtocolFeesExceedBalance();

    /// @dev Thrown when an invalid epoch number is provided
    error TrustBonding_InvalidEpoch();

    /// @dev Thrown when an invalid utilization lower bound is provided (must be between 0 and 1e18)
    error TrustBonding_InvalidUtilizationLowerBound();

    /// @dev Thrown when an invalid start timestamp is provided during initialization
    error TrustBonding_InvalidStartTimestamp();

    /// @dev Thrown when attempting to claim rewards during the first epoch
    error TrustBonding_NoClaimingDuringFirstEpoch();

    /// @dev Thrown when a user has no rewards to claim
    error TrustBonding_NoRewardsToClaim();

    /// @dev Thrown when a function is called by an address other than the timelock
    error TrustBonding_OnlyTimelock();

    /// @dev Thrown when attempting to claim rewards for an epoch that has already been claimed
    error TrustBonding_RewardsAlreadyClaimedForEpoch();

    /// @dev Thrown when a zero address is provided where a valid address is required
    error TrustBonding_ZeroAddress();

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    /**
     * @notice Initializes the TrustBonding contract
     * @param _owner The owner of the contract
     * @param _timelock The address of the timelock contract
     * @param _trustToken The address of the WTRUST token
     * @param _epochLength The length of an epoch in seconds
     * @param _multiVault The address of the MultiVault contract
     * @param _satelliteEmissionsController The address of the SatelliteEmissionsController contract
     * @param _systemUtilizationLowerBound The lower bound for the system utilization ratio
     * @param _personalUtilizationLowerBound The lower bound for the personal utilization ratio
     */
    function initialize(
        address _owner,
        address _timelock,
        address _trustToken,
        uint256 _epochLength,
        address _multiVault,
        address _satelliteEmissionsController,
        uint256 _systemUtilizationLowerBound,
        uint256 _personalUtilizationLowerBound
    )
        external;

    /**
     * @notice Returns the length of an epoch in seconds
     * @return The epoch length in seconds
     */
    function epochLength() external view returns (uint256);

    /**
     * @notice Returns the number of epochs per year
     * @return The number of epochs that occur in one year
     */
    function epochsPerYear() external view returns (uint256);

    /**
     * @notice Returns the timestamp when a specific epoch ends
     * @param _epoch The epoch number
     * @return The timestamp when the epoch ends
     */
    function epochTimestampEnd(uint256 _epoch) external view returns (uint256);

    /**
     * @notice Returns the epoch number for a given timestamp
     * @param timestamp The timestamp to query
     * @return The epoch number that contains the given timestamp
     */
    function epochAtTimestamp(uint256 timestamp) external view returns (uint256);

    /**
     * @notice Returns the current epoch number
     * @return The current epoch number based on block.timestamp
     */
    function currentEpoch() external view returns (uint256);

    /// @notice Returns the previous epoch number
    /// @return The previous epoch number
    function previousEpoch() external view returns (uint256);

    /// @notice Returns the eligible rewards for a specific user
    /// @param account The address of the user
    /// @return The eligible rewards for the user
    function eligibleRewards(address account) external view returns (uint256);

    /// @notice Returns the amount of TRUST tokens emitted per epoch
    /// @param epoch The epoch to query
    /// @return The amount of TRUST tokens emitted in the specified epoch
    function trustPerEpoch(uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns the total amount of tokens currently locked in the system
     * @return The total locked token amount
     */
    function totalLocked() external view returns (uint256);

    /**
     * @notice Returns the current total bonded balance across all users
     * @return The total bonded balance
     */
    function totalBondedBalance() external view returns (uint256);

    /**
     * @notice Returns the total bonded balance at the end of a specific epoch
     * @param _epoch The epoch number to query
     * @return The total bonded balance at the end of the specified epoch
     */
    function totalBondedBalanceAtEpochEnd(uint256 _epoch) external view returns (uint256);

    /**
     * @notice Returns a user's bonded balance at the end of a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch number to query
     * @return The user's bonded balance at the end of the specified epoch
     */
    function userBondedBalanceAtEpochEnd(address _account, uint256 _epoch) external view returns (uint256);

    /**
     * @notice Returns the amount of rewards a user is eligible for in a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch number to query
     * @return The amount of rewards the user is eligible for
     */
    function userEligibleRewardsForEpoch(address _account, uint256 _epoch) external view returns (uint256);

    /**
     * @notice Checks if a user has already claimed rewards for a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch number to query
     * @return True if the user has claimed rewards for the epoch, false otherwise
     */
    function hasClaimedRewardsForEpoch(address _account, uint256 _epoch) external view returns (bool);

    /**
     * @notice Returns the Annual Percentage Rate (APR) for a specific epoch
     * @param _epoch The epoch number to query
     * @return The APR for the specified epoch (scaled by 1e18)
     */
    function getAprAtEpoch(uint256 _epoch) external view returns (uint256);

    /**
     * @notice Returns the system utilization ratio for a specific epoch
     * @param _epoch The epoch number to query
     * @return The system utilization ratio (scaled by 1e18)
     */
    function getSystemUtilizationRatio(uint256 _epoch) external view returns (uint256);

    /**
     * @notice Returns the personal utilization ratio for a user in a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch number to query
     * @return The personal utilization ratio for the user (scaled by 1e18)
     */
    function getPersonalUtilizationRatio(address _account, uint256 _epoch) external view returns (uint256);

    /**
     * @notice Calculates the amount of unclaimed rewards for a specific epoch.
     * @dev Can be called by anyone to determine unclaimed rewards, but used specifically by the
     * SatelliteEmissionsController to determine how much TRUST should be bridged back to the BaseEmissionsController
     * and burned.
     * @param epoch The epoch to calculate the unclaimed rewards for
     * @return Amount of unclaimed rewards available for reclaiming
     */
    function getUnclaimedRewardsForEpoch(uint256 epoch) external view returns (uint256);

    /**
     * @notice Claims eligible Trust token rewards. Claims are always for the previous epoch (`currentEpoch() - 1`)
     * @dev Rewards for epoch `n` are claimable in epoch `n + 1`. If the user forgets to claim their rewards for epoch
     * `n`, they are effectively forfeited. Note that the user is free to claim their rewards to any address they
     * choose.
     * @param recipient The address to receive the Trust rewards
     */
    function claimRewards(address recipient) external;

    /**
     * @notice Pauses the contract, preventing certain operations
     * @dev Can only be called by the owner
     */
    function pause() external;

    /**
     * @notice Unpauses the contract, allowing all operations to resume
     * @dev Can only be called by the owner
     */
    function unpause() external;

    /**
     * @notice Sets the MultiVault contract address
     * @param _multiVault The address of the MultiVault contract
     * @dev Can only be called by the owner. Reverts if _multiVault is the zero address
     */
    function setMultiVault(address _multiVault) external;

    /**
     * @notice Updates the lower bound for the system utilization ratio
     * @param newLowerBound The new lower bound for the system utilization ratio (must be between 0 and 1e18)
     * @dev Can only be called by the owner. Reverts if newLowerBound is invalid
     */
    function updateSystemUtilizationLowerBound(uint256 newLowerBound) external;

    /**
     * @notice Updates the lower bound for the personal utilization ratio
     * @param newLowerBound The new lower bound for the personal utilization ratio (must be between 0 and 1e18)
     * @dev Can only be called by the owner. Reverts if newLowerBound is invalid
     */
    function updatePersonalUtilizationLowerBound(uint256 newLowerBound) external;

    /**
     * @notice Updates the SatelliteEmissionsController contract address
     * @param _satelliteEmissionsController The address of the SatelliteEmissionsController contract
     * @dev Can only be called by the owner. Reverts if _satelliteEmissionsController is the zero address
     */
    function updateSatelliteEmissionsController(address _satelliteEmissionsController) external;
}
