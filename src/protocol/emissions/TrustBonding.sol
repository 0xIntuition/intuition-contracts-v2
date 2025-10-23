// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";

import { VotingEscrow, LockedBalance } from "src/external/curve/VotingEscrow.sol";

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
contract TrustBonding is ITrustBonding, PausableUpgradeable, VotingEscrow {
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

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

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

    /// @notice The address of the Timelock contract that can update certain parameters
    address public timelock;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to restrict access to functions to only the timelock address
     */
    modifier onlyTimelock() {
        if (msg.sender != timelock) {
            revert TrustBonding_OnlyTimelock();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ITrustBonding
    function initialize(
        address _owner,
        address _timelock,
        address _trustToken,
        uint256 _epochLength,
        address _satelliteEmissionsController,
        uint256 _systemUtilizationLowerBound,
        uint256 _personalUtilizationLowerBound
    )
        external
        initializer
    {
        if (_owner == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        __Pausable_init();
        __VotingEscrow_init(_owner, _trustToken, _epochLength);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _owner);

        _setTimelock(_timelock);
        _updateSatelliteEmissionsController(_satelliteEmissionsController);
        _updateSystemUtilizationLowerBound(_systemUtilizationLowerBound);
        _updatePersonalUtilizationLowerBound(_personalUtilizationLowerBound);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustBonding
    function epochLength() public view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).getEpochLength();
    }

    /// @inheritdoc ITrustBonding
    function epochsPerYear() public view returns (uint256) {
        return _epochsPerYear();
    }

    /// @inheritdoc ITrustBonding
    function epochTimestampEnd(uint256 epoch) public view returns (uint256) {
        return _epochTimestampEnd(epoch);
    }

    /// @inheritdoc ITrustBonding
    function epochAtTimestamp(uint256 timestamp) public view returns (uint256) {
        return _epochAtTimestamp(timestamp);
    }

    /// @inheritdoc ITrustBonding
    function currentEpoch() public view returns (uint256) {
        return _currentEpoch();
    }

    /// @inheritdoc ITrustBonding
    function previousEpoch() public view returns (uint256) {
        return _previousEpoch();
    }

    /// @inheritdoc ITrustBonding
    function emissionsForEpoch(uint256 epoch) public view returns (uint256) {
        return _emissionsForEpoch(epoch);
    }

    /// @inheritdoc ITrustBonding
    function totalLocked() public view returns (uint256) {
        return supply;
    }

    /// @inheritdoc ITrustBonding
    function totalBondedBalance() external view returns (uint256) {
        return _totalSupply(block.timestamp);
    }

    /// @inheritdoc ITrustBonding
    function totalBondedBalanceAtEpochEnd(uint256 epoch) public view returns (uint256) {
        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        return _totalSupply(_epochTimestampEnd(epoch));
    }

    /// @inheritdoc ITrustBonding
    function userBondedBalanceAtEpochEnd(address account, uint256 epoch) public view returns (uint256) {
        if (account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        return _balanceOf(account, _epochTimestampEnd(epoch));
    }

    /// @inheritdoc ITrustBonding
    function userEligibleRewardsForEpoch(address account, uint256 epoch) public view returns (uint256) {
        return _userEligibleRewardsForEpoch(account, epoch);
    }

    /// @inheritdoc ITrustBonding
    function hasClaimedRewardsForEpoch(address account, uint256 epoch) public view returns (bool) {
        return _hasClaimedRewardsForEpoch(account, epoch);
    }

    /// @inheritdoc ITrustBonding
    function getSystemUtilizationRatio(uint256 epoch) public view returns (uint256) {
        return _getSystemUtilizationRatio(epoch);
    }

    /// @inheritdoc ITrustBonding
    function getPersonalUtilizationRatio(address account, uint256 epoch) public view returns (uint256) {
        return _getPersonalUtilizationRatio(account, epoch);
    }

    function getUserInfo(address account) external view returns (UserInfo memory) {
        uint256 _currEpoch = _currentEpoch();
        uint256 userRewards;
        uint256 personalUtilization;

        if (_currEpoch > 0) {
            userRewards = _userEligibleRewardsForEpoch(account, _currEpoch);
            personalUtilization = _getPersonalUtilizationRatio(account, _currEpoch);
        }

        LockedBalance memory userLocked = locked[account];
        return UserInfo({
            personalUtilization: personalUtilization,
            eligibleRewards: (userRewards * personalUtilization) / BASIS_POINTS_DIVISOR,
            maxRewards: userRewards,
            lockedAmount: userLocked.amount >= 0 ? uint256(uint128(userLocked.amount)) : 0,
            lockEnd: userLocked.end,
            bondedBalance: _balanceOf(account, block.timestamp)
        });
    }

    /// @inheritdoc ITrustBonding
    function getUserApy(address account) external view returns (uint256 currentApy, uint256 maxApy) {
        uint256 currEpoch = _currentEpoch();
        uint256 userRewards = _userEligibleRewardsForEpoch(account, currEpoch);
        uint256 personalUtilization = _getPersonalUtilizationRatio(account, currEpoch);
        int256 locked = locked[account].amount;

        if (userRewards == 0 || locked <= 0) {
            return (currentApy, maxApy);
        }

        uint256 userRewardsPerYear = userRewards * _epochsPerYear();
        currentApy = (userRewardsPerYear * personalUtilization) / uint256(locked);
        maxApy = (userRewardsPerYear * BASIS_POINTS_DIVISOR) / uint256(locked);
        return (currentApy, maxApy);
    }

    /// @inheritdoc ITrustBonding
    function getUserCurrentClaimableRewards(address account) external view returns (uint256) {
        uint256 _currEpoch = _currentEpoch();

        if (_currEpoch == 0) {
            return 0;
        }

        uint256 prevEpoch = _currEpoch - 1;
        uint256 userClaimedReward = userClaimedRewardsForEpoch[account][prevEpoch];
        uint256 userEligibleReward =
            _userEligibleRewardsForEpoch(account, prevEpoch) * _getPersonalUtilizationRatio(account, prevEpoch)
            / BASIS_POINTS_DIVISOR;

        if (userEligibleReward <= userClaimedReward) {
            return 0;
        }

        return userEligibleReward - userClaimedReward;
    }

    /// @inheritdoc ITrustBonding
    function getUserRewardsForEpoch(address account, uint256 epoch) external view returns (uint256, uint256) {
        uint256 _currEpoch = _currentEpoch();
        if (_currEpoch == 0 || epoch > _currEpoch) {
            return (0, 0);
        }
        uint256 userRewards = _userEligibleRewardsForEpoch(account, epoch);
        uint256 personalUtilization = _getPersonalUtilizationRatio(account, epoch);
        return ((userRewards * personalUtilization) / BASIS_POINTS_DIVISOR, userRewards);
    }

    /// @inheritdoc ITrustBonding
    function getSystemApy() external view returns (uint256 currentApy, uint256 maxApy) {
        uint256 _supply = _totalSupply(block.timestamp);
        if (_supply == 0) {
            return (0, 0);
        }
        uint256 _currEpoch = _currentEpoch();
        uint256 emissionsPerYear = _emissionsForEpoch(_currEpoch) * _epochsPerYear();
        uint256 maxEmissions = ICoreEmissionsController(satelliteEmissionsController).getEmissionsAtEpoch(_currEpoch);
        uint256 maxEmissionsPerYear = maxEmissions * _epochsPerYear();
        currentApy = (emissionsPerYear * BASIS_POINTS_DIVISOR) / _supply;
        maxApy = (maxEmissionsPerYear * BASIS_POINTS_DIVISOR) / _supply;
        return (currentApy, maxApy);
    }

    /// @inheritdoc ITrustBonding
    function getUnclaimedRewardsForEpoch(uint256 epoch) external view returns (uint256) {
        uint256 currentEpochLocal = currentEpoch();
        // There cannot be any unclaimed rewards during the first two epochs, so we return 0.
        if (currentEpochLocal < 2) {
            return 0;
        }

        // We only want unclaimed rewards from epochs that are no longer claimable.
        // For epochs that are still claimable, we return 0.
        // This means we only consider epochs that are at least two epochs old.
        if (epoch > currentEpochLocal - 2) {
            return 0;
        }

        uint256 epochRewards = _emissionsForEpoch(epoch);
        uint256 claimedRewards = totalClaimedRewardsForEpoch[epoch];
        return epochRewards - claimedRewards;
    }

    /*//////////////////////////////////////////////////////////////
                            USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustBonding
    function claimRewards(address recipient) external whenNotPaused nonReentrant {
        if (recipient == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        uint256 currentEpochLocal = currentEpoch();

        // No rewards can be claimed during the first epoch
        if (currentEpochLocal == 0) {
            revert TrustBonding_NoClaimingDuringFirstEpoch();
        }

        // Fetch the raw (pro-rata) rewards for the previous epoch
        uint256 prevEpoch = currentEpochLocal - 1;
        uint256 rawUserRewards = _userEligibleRewardsForEpoch(msg.sender, prevEpoch);

        // Check if the user has any rewards to claim
        if (rawUserRewards == 0) {
            revert TrustBonding_NoRewardsToClaim();
        }

        // Apply the personal utilization ratio to the raw rewards
        uint256 personalUtilizationRatio = _getPersonalUtilizationRatio(msg.sender, prevEpoch);
        uint256 userRewards = rawUserRewards * personalUtilizationRatio / BASIS_POINTS_DIVISOR;

        // Check if the user has any rewards to claim after applying the personal utilization ratio.
        // This check is here mostly to prevent claiming 0 rewards in case the lower bound for the
        // personal utilization ratio is set to 0.
        if (userRewards == 0) {
            revert TrustBonding_NoRewardsToClaim();
        }

        // Check if the user has already claimed rewards for the previous epoch
        if (_hasClaimedRewardsForEpoch(msg.sender, prevEpoch)) {
            revert TrustBonding_RewardsAlreadyClaimedForEpoch();
        }

        // Increment the total claimed inflationary rewards for the previous epoch and set the user's claimed rewards
        totalClaimedRewardsForEpoch[prevEpoch] += userRewards;
        userClaimedRewardsForEpoch[msg.sender][prevEpoch] = userRewards;

        // Mint the rewards to the recipient address
        ISatelliteEmissionsController(satelliteEmissionsController).transfer(recipient, userRewards);

        emit RewardsClaimed(msg.sender, recipient, userRewards);
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS-RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustBonding
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ITrustBonding
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @inheritdoc ITrustBonding
    function setMultiVault(address _multiVault) external onlyTimelock {
        _setMultiVault(_multiVault);
    }

    /// @inheritdoc ITrustBonding
    function setTimelock(address _timelock) external onlyTimelock {
        _setTimelock(_timelock);
    }

    /// @inheritdoc ITrustBonding
    function updateSatelliteEmissionsController(address _satelliteEmissionsController) external onlyTimelock {
        _updateSatelliteEmissionsController(_satelliteEmissionsController);
    }

    /// @inheritdoc ITrustBonding
    function updateSystemUtilizationLowerBound(uint256 newLowerBound) external onlyTimelock {
        _updateSystemUtilizationLowerBound(newLowerBound);
    }

    /// @inheritdoc ITrustBonding
    function updatePersonalUtilizationLowerBound(uint256 newLowerBound) external onlyTimelock {
        _updatePersonalUtilizationLowerBound(newLowerBound);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _currentEpoch() internal view returns (uint256) {
        return _epochAtTimestamp(block.timestamp);
    }

    function _epochsPerYear() internal view returns (uint256) {
        return YEAR / ICoreEmissionsController(satelliteEmissionsController).getEpochLength();
    }

    function _epochTimestampEnd(uint256 epoch) internal view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).getEpochTimestampEnd(epoch);
    }

    function _epochAtTimestamp(uint256 timestamp) internal view returns (uint256) {
        return ICoreEmissionsController(satelliteEmissionsController).getEpochAtTimestamp(timestamp);
    }

    function _emissionsForEpoch(uint256 epoch) internal view returns (uint256) {
        if (epoch > currentEpoch()) {
            revert TrustBonding_InvalidEpoch();
        }

        uint256 maxEpochEmissions = ICoreEmissionsController(satelliteEmissionsController).getEmissionsAtEpoch(epoch);

        if (epoch < 2) {
            return maxEpochEmissions;
        }

        uint256 systemUtilizationRatio = _getSystemUtilizationRatio(epoch);
        uint256 epochEmissions = maxEpochEmissions * systemUtilizationRatio / BASIS_POINTS_DIVISOR;

        return epochEmissions;
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

    function _getPersonalUtilizationRatio(address _account, uint256 _epoch) internal view returns (uint256) {
        if (_account == address(0)) {
            revert TrustBonding_ZeroAddress();
        }

        // If the epoch is in the future, return 0 and exit early
        if (_epoch > currentEpoch()) {
            return 0;
        }

        // In epochs 0 and 1, the utilization ratio is set to the maximum value (100%)
        if (_epoch < 2) {
            return BASIS_POINTS_DIVISOR;
        }

        // Fetch the personal utilization before and after the epoch
        int256 userUtilizationBefore = IMultiVault(multiVault).getUserUtilization(_account, _epoch - 1);
        int256 userUtilizationAfter = IMultiVault(multiVault).getUserUtilization(_account, _epoch);

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

        if (userUtilizationTarget == 0) {
            // If the user had nothing claimable last epoch, don't penalize them as it's their first ever claim
            if (_userEligibleRewardsForEpoch(_account, _epoch - 1) == 0) {
                return BASIS_POINTS_DIVISOR; // 100%
            }

            // They did have eligibility last epoch but chose not to claim --> give them only the floor allocation
            return personalUtilizationLowerBound;
        }

        // If the userUtilizationDelta is greater than the target, we also return the max ratio.
        if (userUtilizationDelta >= userUtilizationTarget) {
            return BASIS_POINTS_DIVISOR; // 100%
        }

        // Normalize the final utilizationRatio to be within the bounds of the personalUtilizationLowerBound and
        // BASIS_POINTS_DIVISOR
        return
            _getNormalizedUtilizationRatio(userUtilizationDelta, userUtilizationTarget, personalUtilizationLowerBound);
    }

    function _getSystemUtilizationRatio(uint256 _epoch) internal view returns (uint256) {
        // If the epoch is in the future, return 0 and exit early
        if (_epoch > currentEpoch()) {
            return 0;
        }

        // In epochs 0 and 1, the utilization ratio is set to the maximum value (100%)
        if (_epoch < 2) {
            return BASIS_POINTS_DIVISOR;
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

        // If the utilizationDelta is greater than the target, we return the max ratio
        if (utilizationDelta >= utilizationTarget) {
            return BASIS_POINTS_DIVISOR;
        }

        // Normalize the final utilizationRatio to be within the bounds of the systemUtilizationLowerBound and
        // BASIS_POINTS_DIVISOR
        return _getNormalizedUtilizationRatio(utilizationDelta, utilizationTarget, systemUtilizationLowerBound);
    }

    /**
     * @notice Returns the normalized utilization ratio, adjusted for the desired range (lowerBound,
     * BASIS_POINTS_DIVISOR)
     * @param delta The change in utilization from the previous epoch
     * @param target The target utilization for the previous epoch
     * @param lowerBound The lower bound for the utilization ratio
     * @return The normalized utilization ratio for the given parameters
     */
    function _getNormalizedUtilizationRatio(uint256 delta, uint256 target, uint256 lowerBound)
        internal
        pure
        returns (uint256)
    {
        uint256 ratioRange = BASIS_POINTS_DIVISOR - lowerBound;
        uint256 utilizationRatio = lowerBound + (delta * ratioRange) / target;
        return utilizationRatio;
    }

    function _setTimelock(address _timelock) internal {
        if (_timelock == address(0)) {
            revert TrustBonding_ZeroAddress();
        }
        timelock = _timelock;
        emit TimelockSet(_timelock);
    }

    function _setMultiVault(address newMultiVault) internal {
        if (newMultiVault == address(0)) {
            revert TrustBonding_ZeroAddress();
        }
        multiVault = newMultiVault;
        emit MultiVaultSet(newMultiVault);
    }

    function _updateSatelliteEmissionsController(address newSatelliteEmissionsController) internal {
        if (newSatelliteEmissionsController == address(0)) {
            revert TrustBonding_ZeroAddress();
        }
        satelliteEmissionsController = newSatelliteEmissionsController;
        emit SatelliteEmissionsControllerSet(newSatelliteEmissionsController);
    }

    function _updateSystemUtilizationLowerBound(uint256 newLowerBound) internal {
        if (newLowerBound > BASIS_POINTS_DIVISOR || newLowerBound < MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        systemUtilizationLowerBound = newLowerBound;

        emit SystemUtilizationLowerBoundUpdated(newLowerBound);
    }

    function _updatePersonalUtilizationLowerBound(uint256 newLowerBound) internal {
        if (newLowerBound > BASIS_POINTS_DIVISOR || newLowerBound < MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND) {
            revert TrustBonding_InvalidUtilizationLowerBound();
        }

        personalUtilizationLowerBound = newLowerBound;

        emit PersonalUtilizationLowerBoundUpdated(newLowerBound);
    }

    function _previousEpoch() internal view returns (uint256) {
        uint256 curr = _currentEpoch();
        return curr == 0 ? 0 : curr - 1;
    }
}
