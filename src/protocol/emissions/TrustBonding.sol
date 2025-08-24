// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VotingEscrow } from "src/external/curve/VotingEscrow.sol";

import { Errors } from "src/libraries/Errors.sol";

/**
 * @title  TrustBonding
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract manages the locking of TRUST tokens
 *         and the distribution of inflationary rewards based on a time-weighted (bonded) balance known
 *         as veTRUST (vote-escrowed TRUST).
 *
 *         - "Locked" refers to the raw deposit of TRUST tokens into the contract.
 *         - "Bonded" (or veTRUST) is a time-weighted voting power derived from the locked tokens.
 *           It decays linearly over time, and uses the same formula as the Curve's veCRV.
 *         - Rewards for each epoch are allocated pro rata to users’ shares of the total bonded
 *           (veTRUST) balance at the end of that epoch.
 *         - Certain APR and emission formulas reference the raw locked balance rather than the
 *           bonded balance. For example, the maximum emission rate is determined by what percentage
 *           of the total TRUST supply has been locked.
 *         - Rewards for epoch `n` become claimable in epoch `n+1` and are forfeited if not claimed
 *           before the next epoch ends (i.e. only the previous epoch's rewards are claimable).
 *         - This version of the TrustBonding contract introduces the utilization-based rewards model,
 *           where the emitted rewards are based on the system utilizationRatio from the MultiVault
 *           contract, whereas the user's rewards are based on their own (personal) utilizationRatio.
 *         - utilizationRatio is defined as percentage of how much did the personal or system utilization
 *           change from epoch to epoch when compared to the target utilization, which represents the
 *           amount of TRUST tokens that were claimed as rewards in the previous epoch (on both the
 *           personal and the system level).
 *
 * @dev    Extended from the Solidity implementation of the Curve Finance's `VotingEscrow`
 *         contract (originally written in Vyper), as used by the Stargate Finance protocol:
 *         https://github.com/stargate-protocol/stargate-dao/blob/main/contracts/VotingEscrow.sol
 */
contract TrustBonding is ITrustBonding, AccessControlUpgradeable, VotingEscrow {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number of seconds in a year
    uint256 public constant YEAR = 365 days;

    /// @notice Basis points divisor used for calculations within the contract
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    /// @notice Minimum system utilization lower bound in basis points
    uint256 public constant MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND = 4000;

    /// @notice Minimum personal utilization lower bound in basis points
    uint256 public constant MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND = 2500;

    /// @notice Role used for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role used for the timelocked operations
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Starting timestamp of the bonding contract's first epoch (epoch 0)
    uint256 public startTimestamp;

    uint256 public maxAnnualEmission;

    /// @notice Mapping of epochs to the total claimed rewards for that epoch among all users
    mapping(uint256 epoch => uint256 totalClaimedRewards) public totalClaimedRewardsForEpoch;

    /// @notice Mapping of users to their respective claimed rewards for a specific epoch
    mapping(address user => mapping(uint256 epoch => uint256 claimedRewards)) public userClaimedRewardsForEpoch;

    /// @notice The MultiVault contract address
    address public multiVault;

    /// @notice The SatelliteEmissionsController contract address
    address public satelliteEmissionsController;

    /// @notice The system utilization lower bound in basis points (represents the minimum possible system utilization
    /// ratio)
    uint256 public systemUtilizationLowerBound;

    /// @notice The personal utilization lower bound in basis points (represents the minimum possible personal
    /// utilization ratio)
    uint256 public personalUtilizationLowerBound;

    /// @notice The maximum claimable protocol fees for a specific epoch
    mapping(uint256 epoch => uint256 totalClaimableProtocolFees) public maxClaimableProtocolFeesForEpoch;

    /// @notice Mapping of epochs to the total claimed protocol fees for that epoch among all users
    mapping(uint256 epoch => uint256 totalClaimedProtocolFees) public totalClaimedProtocolFeesForEpoch;

    /// @notice Mapping of users to their respective claimed protocol fees for a specific epoch
    mapping(address user => mapping(uint256 epoch => uint256 claimedProtocolFees)) public
        userClaimedProtocolFeesForEpoch;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TrustBonding_ClaimableProtocolFeesExceedBalance();
    error TrustBonding_InvalidEpoch();
    error TrustBonding_InvalidUtilizationLowerBound();
    error TrustBonding_InvalidStartTimestamp();
    error TrustBonding_ProtocolFeesNotSentToTrustBondingYet();
    error TrustBonding_MaxClaimableProtocolFeesAlreadySet();
    error TrustBonding_NoClaimingDuringFirstEpoch();
    error TrustBonding_NoRewardsToClaim();
    error TrustBonding_OnlyMultiVault();
    error TrustBonding_ProtocolFeesAlreadyClaimedForEpoch();
    error TrustBonding_ProtocolFeesExceedMaxClaimable();
    error TrustBonding_RewardsAlreadyClaimedForEpoch();
    error TrustBonding_ZeroAddress();
    error TrustBonding_InsufficientBalanceForRewards();

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TrustBonding contract
     * @param _owner The owner of the contract
     * @param _trustToken The address of the TRUST token
     * @param _epochLength The length of an epoch in seconds
     * @param _startTimestamp The starting timestamp of the first epoch
     */
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
        external
        initializer
    {
        // Ensure the start timestamp is in the future
        if (_startTimestamp < block.timestamp) {
            revert TrustBonding_InvalidStartTimestamp();
        }

        if (_multiVault == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        if (
            _systemUtilizationLowerBound > BASIS_POINTS_DIVISOR
                || _systemUtilizationLowerBound < MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND
        ) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        if (
            _personalUtilizationLowerBound > BASIS_POINTS_DIVISOR
                || _personalUtilizationLowerBound < MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND
        ) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        __AccessControl_init();
        __VotingEscrow_init(_owner, _trustToken, _epochLength);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _owner);

        startTimestamp = _startTimestamp;
        multiVault = _multiVault;
        satelliteEmissionsController = _satelliteEmissionsController;
        systemUtilizationLowerBound = _systemUtilizationLowerBound;
        personalUtilizationLowerBound = _personalUtilizationLowerBound;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the length of an epoch in seconds
     * @return The length of an epoch in seconds
     */
    function epochLength() public view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).epochLength();
    }

    /**
     * @notice Returns the number of epochs in a year
     * @return The number of epochs in a year
     */
    function epochsPerYear() public view returns (uint256) {
        return YEAR / epochLength();
    }

    /**
     * @notice Returns the timestamp at the end of a specific epoch
     * @param epoch The epoch to get the end timestamp for
     * @return The timestamp at the end of the given epoch
     */
    function epochEndTimestamp(uint256 epoch) public view returns (uint256) {
        return _epochEndTimestamp(epoch);
    }

    /**
     * @notice Get the epoch at a given timestamp
     * @param timestamp Timestamp to get the epoch of
     * @return Epoch at the given timestamp
     */
    function epochAtTimestamp(uint256 timestamp) public view returns (uint256) {
        return _epochAtTimestamp(timestamp);
    }
    /**
     * @notice Returns the current epoch
     * @return Current epoch
     */

    function currentEpoch() public view returns (uint256) {
        return _currentEpoch();
    }

    /**
     * @notice Returns the total amount of TRUST tokens locked in the contract
     * @return The total amount of TRUST tokens locked in the contract
     */
    function totalLocked() public view returns (uint256) {
        return supply;
    }

    /**
     * @notice Returns the total bonded balance (i.e. the sum of all users’ veTRUST)
     *         at the current block timestamp
     * @return The total amount of veTRUST at the current block timestamp
     */
    function totalBondedBalance() external view returns (uint256) {
        return _totalSupply(block.timestamp);
    }

    /**
     * @notice Returns the current APR (annual percentage rate) for bonding TRUST tokens
     * @param _epoch The epoch to calculate the APR for
     * @return The current APR in basis points for bonding TRUST tokens
     */
    function getAprAtEpoch(uint256 _epoch) external view returns (uint256) {
        if (_epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        uint256 totalLockedAmount = totalLocked();

        if (totalLockedAmount == 0) {
            return 0;
        }

        uint256 trustPerYear = trustPerEpoch(_epoch) * epochsPerYear();

        return trustPerYear * BASIS_POINTS_DIVISOR / totalLockedAmount;
    }

    /**
     * @notice Returns the total veTRUST balance at the end of a specific epoch
     * @param epoch The epoch to get the total veTRUST balance for
     * @return The total amount of veTRUST at the end of the given epoch
     */
    function totalBondedBalanceAtEpochEnd(uint256 epoch) public view returns (uint256) {
        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        return _totalSupply(_epochEndTimestamp(epoch));
    }

    /**
     * @notice Returns the user's veTRUST balance at the end of a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch to get the user's veTRUST balance for
     * @return The user's veTRUST balance at the end of the given epoch
     */
    function userBondedBalanceAtEpochEnd(address _account, uint256 _epoch) public view returns (uint256) {
        if (_account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        if (_epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        return _balanceOf(_account, _epochEndTimestamp(_epoch));
    }

    /**
     * @notice Returns the user's raw eligible rewards for a specific epoch.
     * @param account The user's address
     * @param epoch The epoch to get the eligible rewards for
     * @return The user's eligible rewards for the given epoch
     */
    function userEligibleRewardsForEpoch(address account, uint256 epoch) public view returns (uint256) {
        return _userEligibleRewardsForEpoch(account, epoch);
    }

    /**
     * @notice Returns the user's eligible protocol fee rewards for the previous epoch they can claim now
     * @param account The user's address
     * @return The user's eligible protocol fee rewards for the previous epoch they can claim now
     */
    function userEligibleProtocolFeeRewards(address account) public view returns (uint256) {
        return _userEligibleProtocolFeeRewards(account);
    }

    /**
     * @notice Returns whether the user has claimed rewards for a specific epoch
     * @param account The user's address
     * @param epoch The epoch to check if the user has claimed rewards for
     * @return Whether the user has claimed rewards for the given epoch
     */
    function hasClaimedRewardsForEpoch(address account, uint256 epoch) public view returns (bool) {
        return _hasClaimedRewardsForEpoch(account, epoch);
    }

    /**
     * @notice Calculates the amount of TRUST tokens to be emitted per epoch, based on bonding percentage and max
     * emission
     * @param epoch The epoch to calculate the TRUST emission for
     * @return The amount of TRUST emitted per epoch
     */
    function trustPerEpoch(uint256 epoch) public view returns (uint256) {
        return _emissionsForEpoch(epoch);
    }

    /**
     * @notice Returns the system utilization ratio for a specific epoch
     * @param _epoch The epoch to calculate the system utilization ratio for
     * @return The system utilization ratio for the given epoch
     */
    function getSystemUtilizationRatio(uint256 _epoch) public view returns (uint256) {
        return _getSystemUtilizationRatio(_epoch);
    }

    /**
     * @notice Returns the user's personal utilization ratio for a specific epoch
     * @param _account The user's address
     * @param _epoch The epoch to calculate the personal utilization ratio for
     * @return The personal utilization ratio for the given epoch
     */
    function getPersonalUtilizationRatio(address _account, uint256 _epoch) public view returns (uint256) {
        return _getPersonalUtilizationRatio(_account, _epoch);
    }

    /*//////////////////////////////////////////////////////////////
                            USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims eligible Trust token rewards. Claims are always for the previous epoch (`currentEpoch() - 1`)
     * @dev Rewards for epoch `n` are claimable in epoch `n + 1`. If the user forgets to claim their rewards for epoch
     * `n`,
     *      they are effectively forfeited. Note that the user is free to claim their rewards to any address they
     * choose.
     * @param recipient The address to receive the Trust rewards
     */
    function claimRewards(address recipient) external nonReentrant {
        if (recipient == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        uint256 currentEpochLocal = currentEpoch();

        // No rewards can be claimed during the first epoch
        if (currentEpochLocal == 0) {
            revert TrustBonding_NoClaimingDuringFirstEpoch();
        }

        // Fetch the raw (pro-rata) rewards for the previous epoch
        uint256 previousEpoch = currentEpochLocal - 1;
        uint256 rawUserRewards = _userEligibleRewardsForEpoch(msg.sender, previousEpoch);

        // Check if the user has any rewards to claim
        if (rawUserRewards == 0) {
            revert TrustBonding_NoRewardsToClaim();
        }

        // Apply the personal utilization ratio to the raw rewards
        uint256 personalUtilizationRatio = _getPersonalUtilizationRatio(msg.sender, previousEpoch);
        uint256 userRewards = rawUserRewards * personalUtilizationRatio / BASIS_POINTS_DIVISOR;

        // Check if the user has any rewards to claim after applying the personal utilization ratio.
        // This check is here mostly to prevent claiming 0 rewards in case the lower bound for the
        // personal utilization ratio is set to 0.
        if (userRewards == 0) {
            revert TrustBonding_NoRewardsToClaim();
        }

        // Check if the user has already claimed rewards for the previous epoch
        if (_hasClaimedRewardsForEpoch(msg.sender, previousEpoch)) {
            revert TrustBonding_RewardsAlreadyClaimedForEpoch();
        }

        if (IMultiVault(multiVault).protocolFeeDistributionEnabledAtEpoch(previousEpoch)) {
            uint256 accumulatedProtocolFeesForPreviousEpoch =
                IMultiVault(multiVault).accumulatedProtocolFees(previousEpoch);
            uint256 maxClaimableProtocolFees = maxClaimableProtocolFeesForEpoch[previousEpoch];

            // Check if the accumulated protocol fees from the previous epoch are sent to the TrustBonding contract
            if (accumulatedProtocolFeesForPreviousEpoch > 0 && maxClaimableProtocolFees == 0) {
                revert TrustBonding_ProtocolFeesNotSentToTrustBondingYet();
            }

            // Once we're sure there are protocol fees to claim, we can check if the user is eligible for them
            if (accumulatedProtocolFeesForPreviousEpoch > 0 && maxClaimableProtocolFees > 0) {
                uint256 userProtocolFees = _userEligibleProtocolFeeRewards(msg.sender);

                // Check if the user has any protocol fees to claim
                if (userProtocolFees > 0) {
                    // Check if the user has already claimed protocol fees for the previous epoch
                    if (userClaimedProtocolFeesForEpoch[msg.sender][previousEpoch] > 0) {
                        revert TrustBonding_ProtocolFeesAlreadyClaimedForEpoch();
                    }

                    // Increment the total claimed protocol fees for the previous epoch and set the user's claimed
                    // protocol fees
                    totalClaimedProtocolFeesForEpoch[previousEpoch] += userProtocolFees;
                    userClaimedProtocolFeesForEpoch[msg.sender][previousEpoch] = userProtocolFees;

                    // At this point, we should be sure that there are enough protocol fees to claim for the user,
                    // but we're also adding a few sanity checks here that should never fail
                    if (userProtocolFees + totalClaimedProtocolFeesForEpoch[previousEpoch] > maxClaimableProtocolFees) {
                        revert TrustBonding_ProtocolFeesExceedMaxClaimable();
                    }

                    // Also ensure that the user is not trying to claim more protocol fees than the contract has
                    if (userProtocolFees > address(this).balance) {
                        revert TrustBonding_ClaimableProtocolFeesExceedBalance();
                    }

                    // Transfer the protocol fees to the recipient address
                    Address.sendValue(payable(recipient), userProtocolFees);

                    emit ProtocolFeesClaimed(msg.sender, recipient, userProtocolFees);
                }
            }
        }

        // Increment the total claimed inflationary rewards for the previous epoch and set the user's claimed rewards
        totalClaimedRewardsForEpoch[previousEpoch] += userRewards;
        userClaimedRewardsForEpoch[msg.sender][previousEpoch] = userRewards;

        // Mint the rewards to the recipient address
        ISatelliteEmissionsController(satelliteEmissionsController).transfer(recipient, userRewards);

        emit RewardsClaimed(msg.sender, recipient, userRewards);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS-RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the MultiVault contract address
     * @param _multiVault The address of the MultiVault contract
     */
    function setMultiVault(address _multiVault) external onlyRole(TIMELOCK_ROLE) {
        if (_multiVault == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        multiVault = _multiVault;

        emit MultiVaultSet(_multiVault);
    }

    /**
     * @notice Sets the SatelliteEmissionsController contract address
     * @param _satelliteEmissionsController The address of the SatelliteEmissionsController contract
     */
    function setSatelliteEmissionsController(address _satelliteEmissionsController) external onlyRole(TIMELOCK_ROLE) {
        if (_satelliteEmissionsController == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        satelliteEmissionsController = _satelliteEmissionsController;

        emit SatelliteEmissionsControllerSet(_satelliteEmissionsController);
    }

    /**
     * @notice Updates the lower bound for the system utilization ratio
     * @param newLowerBound The new lower bound for the system utilization ratio
     */
    function updateSystemUtilizationLowerBound(uint256 newLowerBound) external onlyRole(TIMELOCK_ROLE) {
        if (newLowerBound > BASIS_POINTS_DIVISOR || newLowerBound < MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        systemUtilizationLowerBound = newLowerBound;

        emit SystemUtilizationLowerBoundUpdated(newLowerBound);
    }

    /**
     * @notice Updates the lower bound for the personal utilization ratio
     * @param newLowerBound The new lower bound for the personal utilization ratio
     */
    function updatePersonalUtilizationLowerBound(uint256 newLowerBound) external onlyRole(TIMELOCK_ROLE) {
        if (newLowerBound > BASIS_POINTS_DIVISOR || newLowerBound < MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        personalUtilizationLowerBound = newLowerBound;

        emit PersonalUtilizationLowerBoundUpdated(newLowerBound);
    }

    /**
     * @notice Sets the maximum claimable protocol fees for the previous epoch
     * @dev This function can only be called by the MultiVault contract, which is only ever able to
     *      set the maximum claimable protocol fees for the previous epoch (i.e. `currentEpoch() - 1`).
     *      This function is called automatically as the part of the first action in the MultiVault contract
     *      in the new epoch (i.e. current epoch). This function can only be called once per epoch.
     * @param _maxClaimableProtocolFees The maximum claimable protocol fees for the epoch
     */
    function setMaxClaimableProtocolFeesForPreviousEpoch(uint256 _maxClaimableProtocolFees) external {
        // Ensure that the caller is the MultiVault contract
        if (msg.sender != address(multiVault)) {
            revert TrustBonding_OnlyMultiVault();
        }

        // Sanity check to ensure that the max claimable protocol fees are not set during the first epoch
        if (currentEpoch() == 0) {
            return;
        }

        uint256 previousEpoch = currentEpoch() - 1;

        // Ensure that the max claimable protocol fees are not set multiple times for the same epoch
        if (maxClaimableProtocolFeesForEpoch[previousEpoch] > 0) {
            revert TrustBonding_MaxClaimableProtocolFeesAlreadySet();
        }

        maxClaimableProtocolFeesForEpoch[previousEpoch] = _maxClaimableProtocolFees;

        emit MaxClaimableProtocolFeesForPreviousEpochSet(previousEpoch, _maxClaimableProtocolFees);
    }

    /**
     * @notice Returns the amount of unclaimed rewards that can be reclaimed by admin/controller
     * @dev Calculates unclaimed rewards from past epochs, excluding rewards that can still be claimed
     *      for the previous epoch
     * @return The amount of unclaimed rewards available for reclaiming
     */
    function getUnclaimedRewards() external view returns (uint256) {
        // There cannot be any unclaimed rewards during the first epoch as the first epoch is not claimable
        if (currentEpoch() == 0) {
            return 0;
        }

        uint256 previousEpoch = currentEpoch() - 1;
        uint256 totalUnclaimedRewards = 0;

        // Sum up all unclaimed rewards from all past epochs except the previous epoch
        // The previous epoch's rewards can still be claimed, so we exclude them
        for (uint256 epoch = 1; epoch < previousEpoch; epoch++) {
            uint256 epochRewards = trustPerEpoch(epoch);
            uint256 claimedRewards = totalClaimedRewardsForEpoch[epoch];

            if (epochRewards > claimedRewards) {
                totalUnclaimedRewards += epochRewards - claimedRewards;
            }
        }

        return totalUnclaimedRewards;
    }

    /**
     * @notice Withdraws all of the unclaimed protocol fees from the contract
     * @dev This function withdraws all unclaimed protocol fees from the contract, except for the ones
     *      that can still be claimed for the previous epoch, whose claim period is still open.
     * @param recipient The address to which the unclaimed protocol fees will be sent
     */
    function withdrawUnclaimedProtocolFees(address recipient) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        // There cannot be any unclaimed protocol fees during the first epoch as the first epoch is not claimable
        if (currentEpoch() == 0) {
            revert TrustBonding_NoClaimingDuringFirstEpoch();
        }

        uint256 previousEpoch = currentEpoch() - 1;

        // Owner can withdraw all unclaimed protocol fees, except for the ones that can still be claimed for the
        // previous epoch
        uint256 currentlyClaimableProtocolFees =
            maxClaimableProtocolFeesForEpoch[previousEpoch] - totalClaimedProtocolFeesForEpoch[previousEpoch];

        // Calculate the withdrawable protocol fees
        uint256 unclaimedProtocolFees = address(this).balance - currentlyClaimableProtocolFees;

        if (unclaimedProtocolFees > 0) {
            // Transfer the unclaimed protocol fees to the recipient address specified by the owner
            Address.sendValue(payable(recipient), unclaimedProtocolFees);

            emit UnclaimedProtocolFeesWithdrawn(recipient, unclaimedProtocolFees);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _currentEpoch() internal view returns (uint256) {
        return _epochAtTimestamp(block.timestamp);
    }

    function _epochEndTimestamp(uint256 epoch) internal view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).epochEndTimestamp(epoch);
    }

    function _epochAtTimestamp(uint256 timestamp) internal view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).epochAtTimestamp(timestamp);
    }

    function _emissionsForEpoch(uint256 epoch) internal view returns (uint256) {
        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        uint256 maxEpochEmissions = ICoreEmissionsController(satelliteEmissionsController).epochEmissionsAtEpoch(epoch);

        if (epoch < 2) {
            return maxEpochEmissions;
        }

        uint256 systemUtilizationRatio = getSystemUtilizationRatio(epoch);
        uint256 emissionPerEpoch = maxEpochEmissions * systemUtilizationRatio / BASIS_POINTS_DIVISOR;

        return emissionPerEpoch;
    }

    function _hasClaimedRewardsForEpoch(address account, uint256 epoch) internal view returns (bool) {
        return userClaimedRewardsForEpoch[account][epoch] > 0;
    }

    function _userEligibleRewardsForEpoch(address account, uint256 epoch) internal view returns (uint256) {
        if (account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        uint256 userBalance = userBondedBalanceAtEpochEnd(account, epoch);
        uint256 totalBalance = totalBondedBalanceAtEpochEnd(epoch);

        if (userBalance == 0 || totalBalance == 0) {
            return 0;
        }

        return userBalance * _emissionsForEpoch(epoch) / totalBalance;
    }

    function _userEligibleProtocolFeeRewards(address account) internal view returns (uint256) {
        if (account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        uint256 previousEpoch = currentEpoch() - 1;
        uint256 accumulatedProtocolFeesForPreviousEpoch = IMultiVault(multiVault).accumulatedProtocolFees(previousEpoch);

        if (accumulatedProtocolFeesForPreviousEpoch == 0) {
            return 0;
        }

        uint256 userBalance = userBondedBalanceAtEpochEnd(account, previousEpoch);
        uint256 totalBalance = totalBondedBalanceAtEpochEnd(previousEpoch);

        if (userBalance == 0 || totalBalance == 0) {
            return 0;
        }

        return userBalance * accumulatedProtocolFeesForPreviousEpoch / totalBalance;
    }

    /**
     * @notice Returns the normalized utilization ratio, adjusted for the desired range (lowerBound,
     * BASIS_POINTS_DIVISOR)
     * @param delta The change in utilization from the previous epoch
     * @param target The target utilization for the previous epoch
     * @param lowerBound The lower bound for the utilization ratio
     * @return The normalized utilization ratio for the given parameters
     */
    function _getNormalizedUtilizationRatio(
        uint256 delta,
        uint256 target,
        uint256 lowerBound
    )
        internal
        pure
        returns (uint256)
    {
        uint256 ratioRange = BASIS_POINTS_DIVISOR - lowerBound;
        uint256 utilizationRatio = lowerBound + (delta * ratioRange) / target;
        return utilizationRatio;
    }

    function _getPersonalUtilizationRatio(address _account, uint256 _epoch) internal view returns (uint256) {
        // In epochs 0 and 1, the utilization ratio is set to the maximum value (100%)
        if (_account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        // If the epoch is in the future, return 0 and exit early
        if (_epoch < 2) {
            return BASIS_POINTS_DIVISOR;
        }

        // If the epoch is in the future, return 0 and exit early
        if (_epoch > currentEpoch()) {
            return 0;
        }

        // Fetch the personal utilization before and after the epoch
        int256 userUtilizationBefore = IMultiVault(multiVault).getUserUtilizationForEpoch(_account, _epoch - 1);
        int256 userUtilizationAfter = IMultiVault(multiVault).getUserUtilizationForEpoch(_account, _epoch);

        // Since rawUtilizationDelta is signed, we only do a sign check, as the explicit underflow check is not needed
        int256 rawUtilizationDelta = userUtilizationAfter - userUtilizationBefore;

        // If the utilizationDelta is negative or zero, we return the minimum personal utilization ratio
        if (rawUtilizationDelta <= 0) {
            return personalUtilizationLowerBound;
        }

        // Since we previously ensured that userUtilizationDelta > 0, we can now safely cast it to uint256
        uint256 userUtilizationDelta = uint256(rawUtilizationDelta);

        // Fetch the target utilization for the previous epoch
        uint256 userUtilizationTarget = userClaimedRewardsForEpoch[_account][_epoch - 1];

        // If there was no target utilization in the previous epoch, any increase in utilization is rewarded with the
        // max ratio.
        // Similarly, if the userUtilizationDelta is greater than the target, we also return the max ratio.
        if (userUtilizationTarget == 0 || userUtilizationDelta >= userUtilizationTarget) {
            return BASIS_POINTS_DIVISOR;
        }

        // Normalize the final utilizationRatio to be within the bounds of the personalUtilizationLowerBound and
        // BASIS_POINTS_DIVISOR
        return
            _getNormalizedUtilizationRatio(userUtilizationDelta, userUtilizationTarget, personalUtilizationLowerBound);
    }

    function _getSystemUtilizationRatio(uint256 _epoch) internal view returns (uint256) {
        // In epochs 0 and 1, the utilization ratio is set to the maximum value (100%)
        if (_epoch < 2) {
            return BASIS_POINTS_DIVISOR;
        }

        // If the epoch is in the future, return 0 and exit early
        if (_epoch > currentEpoch()) {
            return 0;
        }

        // Fetch the system utilization before and after the epoch
        int256 utilizationBefore = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch - 1);
        int256 utilizationAfter = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch);

        // Since rawUtilizationDelta is signed, we only do a sign check, as the explicit underflow check is not needed
        int256 rawUtilizationDelta = utilizationAfter - utilizationBefore;

        // If the utilizationDelta is negative or zero, we return the minimum system utilization ratio
        if (rawUtilizationDelta <= 0) {
            return systemUtilizationLowerBound;
        }

        // Since we previously ensured that utilizationDelta > 0, we can now safely cast it to uint256
        uint256 utilizationDelta = uint256(rawUtilizationDelta);

        // Fetch the target utilization for the previous epoch
        uint256 utilizationTarget = totalClaimedRewardsForEpoch[_epoch - 1];

        // If there was no target utilization in the previous epoch, any increase in utilization is rewarded with the
        // max ratio.
        // Similarly, if the utilizationDelta is greater than the target, we also return the max ratio.
        if (utilizationTarget == 0 || utilizationDelta >= utilizationTarget) {
            return BASIS_POINTS_DIVISOR;
        }

        // Normalize the final utilizationRatio to be within the bounds of the systemUtilizationLowerBound and
        // BASIS_POINTS_DIVISOR
        return _getNormalizedUtilizationRatio(utilizationDelta, utilizationTarget, systemUtilizationLowerBound);
    }
}
