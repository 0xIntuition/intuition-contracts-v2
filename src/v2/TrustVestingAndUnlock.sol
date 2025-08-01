// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "src/libraries/Errors.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {IUnlock} from "src/interfaces/IUnlock.sol";

/**
 * @title  TrustVestingAndUnlock
 * @author 0xIntuition
 * @notice This contract manages a two-phase token distribution:
 *         First, tokens vest over time with a cliff and a monthly step‐wise vesting period.
 *         Once vested, tokens remain locked until an unlock cliff is reached,
 *         after which they unlock weekly over an additional period.
 *         Additionally, vesting (i.e. new vesting) can be suspended while allowing the unlocking schedule to continue.
 * @dev    Inspired by the Uniswap's TreasuryVester.sol contract (https://github.com/Uniswap/governance/blob/master/contracts/TreasuryVester.sol)
 */
contract TrustVestingAndUnlock is IUnlock, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to hold the parameters for the TrustVestingAndUnlock contract constructor
     * @param trustToken The address of the Trust token contract
     * @param recipient The address of the recipient
     * @param admin The address of the admin (owner) of the contract
     * @param trustBonding The address of the TrustBonding contract
     * @param vestingAmount The amount of Trust tokens to vest and subsequently unlock
     * @param vestingBegin The timestamp at which the vesting begins
     * @param vestingCliff The timestamp at which the vesting cliff ends
     * @param cliffPercentage The percentage of tokens vested at the vesting cliff (expressed in basis points)
     * @param vestingEnd The timestamp at which the vesting ends
     * @param unlockCliff The time in seconds required to unlock the tokens after the unlock cliff is reached
     * @param unlockDuration The duration in seconds over which the tokens unlock after the unlock cliff is reached
     * @param unlockCliffPercentage The percentage of tokens unlocked at the unlock cliff (expressed in basis points)
     */
    struct VestingParams {
        address trustToken;
        address recipient;
        address admin;
        address trustBonding;
        uint256 vestingAmount;
        uint256 vestingBegin;
        uint256 vestingCliff;
        uint256 cliffPercentage;
        uint256 vestingEnd;
        uint256 unlockCliff;
        uint256 unlockDuration;
        uint256 unlockCliffPercentage;
    }

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points divisor used for calculations within the contract
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    /// @notice One week in seconds
    uint256 public constant ONE_WEEK = 1 weeks;

    /// @notice One month in seconds
    uint256 public constant ONE_MONTH = 30 days;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Trust token contract
    IERC20 public immutable trustToken;

    /// @notice The TrustBonding contract
    TrustBonding public immutable trustBonding;

    /// @notice The amount of Trust tokens to vest and subsequently unlock
    uint256 public immutable vestingAmount;

    /// @notice The timestamp at which the vesting begins
    uint256 public immutable vestingBegin;

    /// @notice The timestamp at which the vesting cliff ends
    uint256 public immutable vestingCliff;

    /// @notice The timestamp at which the vesting ends
    uint256 public immutable vestingEnd;

    /// @notice The percentage of tokens vested at the vesting cliff (expressed in basis points)
    uint256 public immutable cliffPercentage;

    /// @notice The time in seconds required to unlock the tokens after the unlocking has begun
    uint256 public immutable unlockCliff;

    /// @notice The duration in seconds over which the tokens unlock after the unlock cliff is reached
    uint256 public immutable unlockDuration;

    /// @notice The percentage of tokens unlocked at the unlock cliff (expressed in basis points)
    uint256 public immutable unlockCliffPercentage;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The recipient of the unlocked Trust tokens
    address public recipient;

    /// @notice The last time the Trust tokens were claimed
    uint256 public lastUpdate;

    /// @notice The timestamp at which the TGE occurred. Marks the beginning of the unlock period
    uint256 public tgeTimestamp;

    /// @notice The amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the recipient
    /// @dev This variable is used for internal accounting purposes, in order to ensure that the recipient can only bond
    ///      vested but not yet unlocked tokens
    uint256 public bondedAmount;

    /// @notice If non-zero, this is the timestampt at which the vesting was suspended
    uint256 public vestingSuspendedAt;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to check if the caller is the recipient
    modifier onlyRecipient() {
        if (msg.sender != recipient) {
            revert Errors.Unlock_OnlyRecipient();
        }
        _;
    }

    /**
     * @notice Modifier to check if the new bonded amount is within the maximum vested amount
     * @param amount The amount of Trust tokens to bond
     */
    modifier checkMaxVested(uint256 amount) {
        uint256 effectiveTimestamp = isVestingSuspended() ? vestingSuspendedAt : block.timestamp;
        uint256 maxVested = vestedAmount(effectiveTimestamp);

        if (bondedAmount + amount > maxVested) {
            revert Errors.Unlock_NotEnoughVested();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for a new TrustVestingAndUnlock contract
     * @param vestingParams The parameters for the TrustVestingAndUnlock contract
     */
    constructor(VestingParams memory vestingParams) Ownable(vestingParams.admin) {
        if (
            vestingParams.trustToken == address(0) || vestingParams.recipient == address(0)
                || vestingParams.trustBonding == address(0)
        ) {
            revert Errors.Unlock_ZeroAddress();
        }

        if (vestingParams.vestingAmount == 0) {
            revert Errors.Unlock_ZeroAmount();
        }

        if (vestingParams.vestingBegin < block.timestamp) {
            revert Errors.Unlock_VestingBeginTooEarly();
        }

        if (vestingParams.vestingCliff < vestingParams.vestingBegin) {
            revert Errors.Unlock_CliffIsTooEarly();
        }

        // Since the contract uses a monthly vesting schedule, we want to make sure that the `vestingEnd`
        // is at least one month after the `vestingCliff`
        if (vestingParams.vestingEnd < vestingParams.vestingCliff + ONE_MONTH) {
            revert Errors.Unlock_EndIsTooEarly();
        }

        if (vestingParams.unlockCliff == 0) {
            revert Errors.Unlock_InvalidUnlockCliff();
        }

        // Since the contract uses a weekly unlock schedule, we want to make sure that the `unlockEnd`
        // is at least one week after the `unlockCliff`
        if (vestingParams.unlockDuration < ONE_WEEK) {
            revert Errors.Unlock_InvalidUnlockDuration();
        }

        if (
            vestingParams.cliffPercentage > BASIS_POINTS_DIVISOR
                || vestingParams.unlockCliffPercentage > BASIS_POINTS_DIVISOR
        ) {
            revert Errors.Unlock_InvalidCliffPercentage();
        }

        trustToken = IERC20(vestingParams.trustToken);
        recipient = vestingParams.recipient;
        trustBonding = TrustBonding(vestingParams.trustBonding);

        vestingAmount = vestingParams.vestingAmount;
        vestingBegin = vestingParams.vestingBegin;
        vestingCliff = vestingParams.vestingCliff;
        vestingEnd = vestingParams.vestingEnd;
        cliffPercentage = vestingParams.cliffPercentage;

        unlockCliff = vestingParams.unlockCliff;
        unlockDuration = vestingParams.unlockDuration;
        unlockCliffPercentage = vestingParams.unlockCliffPercentage;

        lastUpdate = vestingBegin;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the TGE timestamp. Marks the beginning of the unlock period
     * @dev This function can only be called once
     * @param _tgeTimestamp The timestamp at which the TGE occurred
     */
    function setTGETimestamp(uint256 _tgeTimestamp) external onlyOwner {
        if (tgeTimestamp != 0) {
            revert Errors.Unlock_TGETimestampAlreadySet();
        }

        tgeTimestamp = _tgeTimestamp;

        emit TGETimestampSet(_tgeTimestamp);
    }

    /**
     * @notice Suspends vesting at a given timestamp
     * @dev This function calculates the final vested and unlocked amounts as of suspension,
     *      halts new vesting, and withdraws the non-vested/non-unlocked tokens to the owner
     * @param vestingSuspensionTimestamp The timestamp at which vesting is suspended
     */
    function suspendVesting(uint256 vestingSuspensionTimestamp) external onlyOwner {
        if (block.timestamp >= vestingEnd) {
            revert Errors.Unlock_VestingAlreadyEnded();
        }

        if (isVestingSuspended()) {
            revert Errors.Unlock_VestingAlreadySuspended();
        }

        if (vestingSuspensionTimestamp < vestingBegin) {
            revert Errors.Unlock_SuspensionBeforeVestingBegin();
        }

        if (vestingSuspensionTimestamp > block.timestamp) {
            revert Errors.Unlock_SuspensionTimestampInFuture();
        }

        vestingSuspendedAt = vestingSuspensionTimestamp;

        uint256 finalVested = vestedAmount(vestingSuspensionTimestamp);
        uint256 finalUnlocked = unlockedAmount(block.timestamp, finalVested);
        uint256 alreadyClaimed = vestingAmount - trustToken.balanceOf(address(this)) - bondedAmount;

        uint256 recipientRemaining = finalUnlocked - alreadyClaimed;
        uint256 contractBalance = trustToken.balanceOf(address(this));

        if (contractBalance < recipientRemaining) {
            revert Errors.Unlock_NotEnoughBalance();
        }

        uint256 withdrawAmount = contractBalance - recipientRemaining;
        if (withdrawAmount > 0) {
            trustToken.safeTransfer(owner(), withdrawAmount);
        }

        emit VestingSuspended(vestingSuspensionTimestamp, finalVested, finalUnlocked, alreadyClaimed, withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            RECIPIENT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the recipient of the unlocked Trust tokens
     * @param _recipient The address of the recipient
     */
    function setRecipient(address _recipient) external onlyRecipient {
        if (_recipient == address(0)) {
            revert Errors.Unlock_ZeroAddress();
        }

        recipient = _recipient;

        emit RecipientSet(_recipient);
    }

    /// @notice Claims the unlocked Trust tokens and transfers them to the recipient
    function claim() external onlyRecipient nonReentrant {
        uint256 vestedNow = vestedAmount(block.timestamp);
        uint256 unlockedNow = unlockedAmount(block.timestamp, vestedNow);

        uint256 vestedBefore = vestedAmount(lastUpdate);
        uint256 unlockedBefore = unlockedAmount(lastUpdate, vestedBefore);

        // Revert if no new tokens are unlocked
        if (unlockedNow <= unlockedBefore) {
            revert Errors.Unlock_NotTimeYet();
        }

        uint256 amount = unlockedNow - unlockedBefore;
        lastUpdate = block.timestamp;

        if (amount == 0) {
            revert Errors.Unlock_ZeroAmount();
        }

        trustToken.safeTransfer(recipient, amount);

        emit Claimed(recipient, amount, block.timestamp);
    }

    /**
     * @notice Approves the TrustBonding contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveTrustBonding(uint256 amount) external onlyRecipient {
        trustToken.forceApprove(address(trustBonding), amount);
    }

    /**
     * @notice Bonds Trust tokens to the TrustBonding contract
     * @dev Users can only bond vested but not yet unlocked tokens
     * @param amount The amount of Trust tokens to bond
     * @param lockDuration The duration in seconds for which the Trust tokens are locked in bonding
     */
    function createBond(uint256 amount, uint256 lockDuration)
        external
        onlyRecipient
        checkMaxVested(amount)
        nonReentrant
    {
        // Increase internal accounting of bonded amount and create the bonding lock
        bondedAmount += amount;

        uint256 unlockTime = block.timestamp + lockDuration;
        trustBonding.create_lock(amount, unlockTime);

        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the amount locked in an existing bonding lock
     * @param amount The amount of Trust tokens to add to the lock
     */
    function increaseBondedAmount(uint256 amount) external onlyRecipient checkMaxVested(amount) nonReentrant {
        // Increase internal accounting of bonded amount and increase the amount in the TrustBonding lock
        bondedAmount += amount;
        trustBonding.increase_amount(amount);

        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the unlock time of an existing bonding lock
     * @param newUnlockTime The new unlock time for the existing bonding lock
     */
    function increaseBondingUnlockTime(uint256 newUnlockTime) external onlyRecipient nonReentrant {
        trustBonding.increase_unlock_time(newUnlockTime);
    }

    /// @notice Claim unlocked tokens back from TrustBonding to this contract
    function withdrawFromBonding() external onlyRecipient nonReentrant {
        // Decrease internal accounting of bonded amount and withdraw Trust from TrustBonding to this contract
        bondedAmount = 0;
        trustBonding.withdraw();

        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Claims Trust token rewards
     * @dev `rewardsRecipient` can be any address, not necessarily the recipient of the unlocked Trust tokens
     * @param rewardsRecipient The address to which the rewards are sent
     */
    function claimRewards(address rewardsRecipient) external onlyRecipient nonReentrant {
        trustBonding.claimRewards(rewardsRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether or not the vesting has been suspended
     * @return True if the vesting has been suspended, false otherwise
     */
    function isVestingSuspended() public view returns (bool) {
        return vestingSuspendedAt != 0;
    }

    /**
     * @notice Returns the timestamp at which all of the vesting tokens are unlocked
     * @dev If the TGE has not occurred yet, the function returns 0, meaning that the `unlockEnd` is not known yet
     * @return The timestamp at which all of the vesting tokens are unlocked and ready to be claimed
     */
    function unlockEnd() public view returns (uint256) {
        if (tgeTimestamp == 0 || isVestingSuspended()) {
            return 0;
        }

        return tgeTimestamp + unlockCliff + unlockDuration;
    }

    /**
     * @notice Returns the timestamp at which the bonding lock ends for this contract
     * @return lockEndTimestamp The timestamp at which the bonding lock ends
     */
    function bondingLockEndTimestamp() external view returns (uint256 lockEndTimestamp) {
        (, lockEndTimestamp) = trustBonding.locked(address(this));
    }

    /**
     * @notice Returns the amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the recipient
     * @return The amount of Trust tokens bonded
     */
    function bondingLockedAmount() external view returns (uint256) {
        (int128 lockedAmount,) = trustBonding.locked(address(this));
        return uint256(uint128(lockedAmount));
    }

    /**
     * @notice Calculates the amount of Trust tokens that are vested at a given timestamp
     * @param timestamp The timestamp to calculate the vested amount at
     * @return The amount of Trust tokens vested at the given timestamp
     */
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < vestingCliff) {
            return 0;
        } else if (timestamp >= vestingEnd) {
            return vestingAmount;
        } else {
            uint256 cliffAmount = (vestingAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;
            uint256 remainingAmount = vestingAmount - cliffAmount;

            uint256 totalMonths = (vestingEnd - vestingCliff) / ONE_MONTH;
            uint256 elapsedMonths = (timestamp - vestingCliff) / ONE_MONTH;
            uint256 monthlyVested = (remainingAmount * elapsedMonths) / totalMonths;

            return cliffAmount + monthlyVested;
        }
    }

    /**
     * @notice Calculates the amount of Trust tokens that are unlocked at a given timestamp
     * @param timestamp The timestamp to calculate the unlocked amount at
     * @param vestedTokens The amount of Trust tokens vested at the given timestamp
     * @return The amount of Trust tokens unlocked at the given timestamp
     */
    function unlockedAmount(uint256 timestamp, uint256 vestedTokens) public view returns (uint256) {
        // Unlocking doesn't start until the TGE has occurred and the unlock cliff has passed
        if (tgeTimestamp == 0 || timestamp < tgeTimestamp + unlockCliff) {
            return 0;
        } else if (timestamp >= unlockEnd()) {
            return vestedTokens;
        } else {
            uint256 unlockedAtCliff = (vestedTokens * unlockCliffPercentage) / BASIS_POINTS_DIVISOR;
            uint256 remainingToUnlock = vestedTokens - unlockedAtCliff;

            uint256 totalWeeks = unlockDuration / ONE_WEEK;
            uint256 unlockCliffTimestamp = tgeTimestamp + unlockCliff;
            uint256 elapsedWeeks = (timestamp - unlockCliffTimestamp) / ONE_WEEK;
            uint256 weeklyUnlocked = (remainingToUnlock * elapsedWeeks) / totalWeeks;

            return unlockedAtCliff + weeklyUnlocked;
        }
    }
}
