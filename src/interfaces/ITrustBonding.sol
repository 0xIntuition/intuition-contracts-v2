// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

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
     * @notice Emitted when a user claims their protocol fees rewards
     * @param user The user who claimed the protocol fees
     * @param recipient The address to which the protocol fees were sent
     * @param amount The amount of protocol fees claimed
     */
    event ProtocolFeesClaimed(address indexed user, address indexed recipient, uint256 amount);

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

    /**
     * @notice Emitted when the maximum claimable protocol fees for the previous epoch are set
     * @param epoch The epoch for which the maximum claimable protocol fees are set
     * @param maxClaimableProtocolFees The maximum claimable protocol fees for the previous epoch
     */
    event MaxClaimableProtocolFeesForPreviousEpochSet(uint256 epoch, uint256 maxClaimableProtocolFees);

    /**
     * @notice Emitted when the unclaimed protocol fees are withdrawn by the owner
     * @param recipient The address to which the unclaimed protocol fees were sent
     * @param feesWithdrawn The amount of unclaimed protocol fees withdrawn
     */
    event UnclaimedProtocolFeesWithdrawn(address indexed recipient, uint256 feesWithdrawn);

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    function initialize(
        address _owner,
        address _trustToken,
        uint256 _epochLength,
        uint256 _startTimestamp,
        address _multiVault,
        address _satelliteEmissionsController,
        uint256 _systemUtilizationLowerBound,
        uint256 _personalUtilizationLowerBound
    )
        external;

    function epochLength() external view returns (uint256);

    function epochsPerYear() external view returns (uint256);

    function epochTimestampEnd(uint256 _epoch) external view returns (uint256);

    function epochAtTimestamp(uint256 timestamp) external view returns (uint256);

    function currentEpoch() external view returns (uint256);

    function totalLocked() external view returns (uint256);

    function totalBondedBalance() external view returns (uint256);

    function totalBondedBalanceAtEpochEnd(uint256 _epoch) external view returns (uint256);

    function userBondedBalanceAtEpochEnd(address _account, uint256 _epoch) external view returns (uint256);

    function userEligibleRewardsForEpoch(address _account, uint256 _epoch) external view returns (uint256);

    function hasClaimedRewardsForEpoch(address _account, uint256 _epoch) external view returns (bool);

    function getAprAtEpoch(uint256 _epoch) external view returns (uint256);

    function getSystemUtilizationRatio(uint256 _epoch) external view returns (uint256);

    function getPersonalUtilizationRatio(address _account, uint256 _epoch) external view returns (uint256);

    function getUnclaimedRewards() external view returns (uint256);

    function claimRewards(address recipient) external;

    function pause() external;

    function unpause() external;

    function setMultiVault(address _multiVault) external;

    function updateSystemUtilizationLowerBound(uint256 newLowerBound) external;

    function updatePersonalUtilizationLowerBound(uint256 newLowerBound) external;
}
