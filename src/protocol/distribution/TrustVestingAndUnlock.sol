// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUnlock } from "src/interfaces/IUnlock.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

/**
 * @title  TrustVestingAndUnlock
 * @author 0xIntuition
 * @notice This contract manages a two-phase token distribution:
 *         First, tokens vest over time with a cliff and a monthly step‐wise vesting period.
 *         Once vested, tokens remain locked until an unlock cliff is reached,
 *         after which they unlock weekly over an additional period.
 *         Additionally, vesting (i.e. new vesting) can be suspended while allowing the unlocking schedule to continue.
 * @dev    Inspired by the Uniswap's TreasuryVester.sol contract
 * (https://github.com/Uniswap/governance/blob/master/contracts/TreasuryVester.sol)
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
     * @param multiVault The address of the MultiVault contract
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
        address admin;
        address recipient;
        address payable token;
        address trustBonding;
        address payable multiVault;
        uint256 vestingAmount;
        uint256 vestingBegin;
        uint256 vestingCliff;
        uint256 cliffPercentage;
        uint256 vestingEnd;
        uint256 unlockCliff;
        uint256 unlockDuration;
        uint256 unlockCliffPercentage;
    }

    /**
     * @notice Struct to hold the data for creating triples in the MultiVault contract
     * @param subjectIds An array of subject IDs for the triples
     * @param predicateIds An array of predicate IDs for the triples
     * @param objectIds An array of object IDs for the triples
     * @param value The amount of Trust tokens to use for creating the triples
     */
    struct CreateTriplesData {
        bytes32[] subjectIds;
        bytes32[] predicateIds;
        bytes32[] objectIds;
        uint256 value;
    }

    /**
     * @notice Struct to hold the data for batch depositing into the MultiVault contract
     * @param receiver The address that will receive the shares
     * @param termIds An array of term IDs to deposit into
     * @param bondingCurveIds An array of bonding curve IDs to use for the deposits
     * @param amounts An array of amounts of Trust tokens to deposit for each term
     * @param minSharesToReceive An array of minimum shares to receive in return for each deposit
     */
    struct BatchDepositData {
        address receiver;
        bytes32[] termIds;
        uint256[] bondingCurveIds;
        uint256[] amounts;
        uint256[] minSharesToReceive;
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

    /// @notice The Trust (WTRUST) token contract
    address payable public immutable trustToken;

    /// @notice The TrustBonding contract
    address public immutable trustBonding;

    /// @notice The MultiVault contract
    address payable public immutable multiVault;

    /// @notice The amount of Trust tokens to vest and subsequently unlock
    uint256 public immutable vestingAmount;

    /// @notice Vesting start metadata used for admin guards (e.g., suspension checks).
    ///         Accrual before the cliff is 0; actual vesting accrual is defined by vestingCliff/vestingEnd.
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

    /// @notice Global unlock start timestamp (i.e., the TGE timestamp). Controls the unlock schedule only.
    ///         Vesting accrual is independent and defined by vestingCliff/vestingEnd.
    uint256 public unlockStartTimestamp;

    /// @notice The amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the
    ///         recipient
    /// @dev This variable is used for internal accounting purposes, in order to ensure that the recipient can only bond
    ///      vested but not yet unlocked tokens
    uint256 public bondedAmount;

    /// @notice If non-zero, this is the timestampt at which the vesting was suspended
    uint256 public vestingSuspendedAt;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unlock_ApprovalFailed();
    error Unlock_ArrayLengthMismatch();
    error Unlock_CliffIsTooEarly();
    error Unlock_EndIsTooEarly();
    error Unlock_InsufficientBalance(uint256 balance, uint256 required);
    error Unlock_InvalidCliffPercentage();
    error Unlock_InvalidUnlockCliff();
    error Unlock_InvalidUnlockDuration();
    error Unlock_InsufficientUnlockedTokens();
    error Unlock_NotEnoughBalance();
    error Unlock_NotEnoughVested();
    error Unlock_NotTimeYet();
    error Unlock_OnlyAdmin();
    error Unlock_OnlyRecipient();
    error Unlock_SuspensionBeforeVestingBegin();
    error Unlock_SuspensionTimestampInFuture();
    error Unlock_UnlockStartTimestampAlreadySet();
    error Unlock_TrustUnlockAlreadyExists();
    error Unlock_UnlockBeginTooEarly();
    error Unlock_VestingAlreadyEnded();
    error Unlock_VestingAlreadySuspended();
    error Unlock_VestingBeginTooEarly();
    error Unlock_ZeroAddress();
    error Unlock_ZeroAmount();
    error Unlock_ZeroLengthArray();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to check if the caller is the recipient
    modifier onlyRecipient() {
        if (msg.sender != recipient) {
            revert Unlock_OnlyRecipient();
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
            revert Unlock_NotEnoughVested();
        }
        _;
    }

    /**
     * @notice Modifier to ensure that the amount of Trust tokens used in a MultiVault action is not the amount that's
     * subject to the unlock and vesting
     * @param amount The amount of Trust tokens to check against the required locked amount
     */
    modifier onlyNonLockedTokens(uint256 amount) {
        _requireNonLockedTokens(amount);
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
            vestingParams.token == address(0) || vestingParams.recipient == address(0)
                || vestingParams.trustBonding == address(0) || vestingParams.multiVault == address(0)
        ) {
            revert Unlock_ZeroAddress();
        }

        if (vestingParams.vestingAmount == 0) {
            revert Unlock_ZeroAmount();
        }

        if (vestingParams.vestingCliff < vestingParams.vestingBegin) {
            revert Unlock_CliffIsTooEarly();
        }

        // Since the contract uses a monthly vesting schedule, we want to make sure that the `vestingEnd`
        // is at least one month after the `vestingCliff`
        if (vestingParams.vestingEnd < vestingParams.vestingCliff + ONE_MONTH) {
            revert Unlock_EndIsTooEarly();
        }

        if (vestingParams.unlockCliff == 0) {
            revert Unlock_InvalidUnlockCliff();
        }

        // Since the contract uses a weekly unlock schedule, we want to make sure that the `unlockEnd`
        // is at least one week after the `unlockCliff`
        if (vestingParams.unlockDuration < ONE_WEEK) {
            revert Unlock_InvalidUnlockDuration();
        }

        if (
            vestingParams.cliffPercentage > BASIS_POINTS_DIVISOR
                || vestingParams.unlockCliffPercentage > BASIS_POINTS_DIVISOR
        ) {
            revert Unlock_InvalidCliffPercentage();
        }

        trustToken = vestingParams.token;
        recipient = vestingParams.recipient;
        trustBonding = vestingParams.trustBonding;
        multiVault = vestingParams.multiVault;

        vestingAmount = vestingParams.vestingAmount;
        vestingBegin = vestingParams.vestingBegin;
        vestingCliff = vestingParams.vestingCliff;
        vestingEnd = vestingParams.vestingEnd;
        cliffPercentage = vestingParams.cliffPercentage;

        unlockCliff = vestingParams.unlockCliff;
        unlockDuration = vestingParams.unlockDuration;
        unlockCliffPercentage = vestingParams.unlockCliffPercentage;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Sets the global unlock start timestamp (i.e., the TGE timestamp). Begins the unlock schedule.
     * @dev This function can only be called once and it does not affect vesting accrual, which is governed by
     * vestingCliff/vestingEnd.
     * @param _unlockStartTimestamp The timestamp at which the TGE has occurred & the unlock schedule began
     */
    function setUnlockStartTimestamp(uint256 _unlockStartTimestamp) external onlyOwner {
        if (unlockStartTimestamp != 0) {
            revert Unlock_UnlockStartTimestampAlreadySet();
        }

        unlockStartTimestamp = _unlockStartTimestamp;

        emit UnlockStartTimestampSet(_unlockStartTimestamp);
    }

    /**
     * @notice Suspends vesting at a given timestamp
     * @dev This function calculates the final vested and unlocked amounts as of suspension,
     *      halts new vesting, and withdraws the non-vested/non-unlocked tokens to the owner
     * @param vestingSuspensionTimestamp The timestamp at which vesting is suspended
     */
    function suspendVesting(uint256 vestingSuspensionTimestamp) external onlyOwner {
        if (block.timestamp >= vestingEnd) {
            revert Unlock_VestingAlreadyEnded();
        }

        if (isVestingSuspended()) {
            revert Unlock_VestingAlreadySuspended();
        }

        if (vestingSuspensionTimestamp < vestingBegin) {
            revert Unlock_SuspensionBeforeVestingBegin();
        }

        if (vestingSuspensionTimestamp > block.timestamp) {
            revert Unlock_SuspensionTimestampInFuture();
        }

        uint256 finalVested = vestedAmount(vestingSuspensionTimestamp);
        uint256 finalUnlocked = unlockedAmount(block.timestamp, finalVested);

        vestingSuspendedAt = vestingSuspensionTimestamp;

        uint256 alreadyClaimed = vestingAmount - address(this).balance - bondedAmount;

        uint256 recipientRemaining = finalUnlocked - alreadyClaimed;
        uint256 contractBalance = address(this).balance;

        if (contractBalance < recipientRemaining) {
            revert Unlock_NotEnoughBalance();
        }

        uint256 withdrawAmount = contractBalance - recipientRemaining;
        if (withdrawAmount > 0) {
            Address.sendValue(payable(owner()), withdrawAmount);
        }

        emit VestingSuspended(vestingSuspensionTimestamp, finalVested, finalUnlocked, alreadyClaimed, withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            RECIPIENT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves the MultiVault contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveMultiVault(uint256 amount) external onlyRecipient {
        IERC20(trustToken).forceApprove(address(multiVault), amount);
    }

    /**
     * @notice Sets the recipient of the unlocked Trust tokens
     * @param _recipient The address of the recipient
     */
    function setRecipient(address _recipient) external onlyRecipient {
        if (_recipient == address(0)) {
            revert Unlock_ZeroAddress();
        }

        recipient = _recipient;

        emit RecipientSet(_recipient);
    }

    /**
     * @notice Approves the TrustBonding contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveTrustBonding(uint256 amount) external onlyRecipient {
        IERC20(trustToken).forceApprove(address(trustBonding), amount);
    }

    /**
     * @notice Bonds Trust tokens to the TrustBonding contract
     * @param amount The amount of Trust tokens to bond
     * @param lockDuration The duration in seconds for which the Trust tokens are locked in bonding
     */
    function createBond(uint256 amount, uint256 lockDuration) external nonReentrant onlyRecipient {
        bondedAmount += amount;
        uint256 unlockTime = block.timestamp + lockDuration;
        _wrapTrustTokens(amount);
        TrustBonding(trustBonding).create_lock(amount, unlockTime);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the amount locked in an existing bonding lock
     * @param amount The amount of Trust tokens to add to the lock
     */
    function increaseBondedAmount(uint256 amount) external nonReentrant onlyRecipient {
        bondedAmount += amount;
        _wrapTrustTokens(amount);
        TrustBonding(trustBonding).increase_amount(amount);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the unlock time of an existing bonding lock
     * @param newUnlockTime The new unlock time for the existing bonding lock
     */
    function increaseBondingUnlockTime(uint256 newUnlockTime) external nonReentrant onlyRecipient {
        TrustBonding(trustBonding).increase_unlock_time(newUnlockTime);
    }

    /// @notice Claim unlocked tokens back from TrustBonding to this contract
    function withdrawFromBonding() external onlyRecipient nonReentrant {
        // Decrease internal accounting of bonded amount and withdraw Trust from TrustBonding to this contract
        bondedAmount = 0;
        TrustBonding(trustBonding).withdraw();
        _unwrapTrustTokens(address(this).balance);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Claims Trust token rewards
     * @dev `rewardsRecipient` can be any address, not necessarily the recipient of the unlocked Trust tokens
     * @param rewardsRecipient The address to which the rewards are sent
     */
    function claimRewards(address rewardsRecipient) external nonReentrant onlyRecipient {
        TrustBonding(trustBonding).claimRewards(rewardsRecipient);
        _unwrapTrustTokens(IERC20(trustToken).balanceOf(address(this)));
    }

    /**
     * @notice Withdraws non-locked Trust tokens from this contract to the specified receiver
     * @param to The address that will receive the withdrawn Trust tokens
     * @param amount The amount of Trust tokens to withdraw
     */
    function withdraw(address to, uint256 amount) external nonReentrant onlyRecipient onlyNonLockedTokens(amount) {
        if (to == address(0)) {
            revert Unlock_ZeroAddress();
        }

        if (amount == 0) {
            revert Unlock_ZeroAmount();
        }

        Address.sendValue(payable(to), amount);
        emit Transferred(to, amount, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            MULTIVAULT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates new atoms in the MultiVault contract
     * @param atomDataArray An array of bytes containing the data for each atom to be created
     * @param assets The amount of Trust tokens to use for creating each atom
     */
    function createAtoms(
        bytes[] calldata atomDataArray,
        uint256[] calldata assets
    )
        external
        payable
        nonReentrant
        onlyRecipient
        onlyNonLockedTokens(_sum(assets))
        returns (bytes32[] memory atomIds)
    {
        uint256 _totalAssets = _sum(assets);
        atomIds = IMultiVault(multiVault).createAtoms{ value: _totalAssets }(atomDataArray, assets);
    }

    /**
     * @notice Creates new triples in the MultiVault contract
     * @param subjectIds An array of subject IDs for the triples
     * @param predicateIds An array of predicate IDs for the triples
     * @param objectIds An array of object IDs for the triples
     * @param assets The amount of Trust tokens to use for creating each triple
     */
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    )
        external
        payable
        nonReentrant
        onlyRecipient
        onlyNonLockedTokens(_sum(assets))
        returns (bytes32[] memory tripleIds)
    {
        tripleIds =
            IMultiVault(multiVault).createTriples{ value: msg.value }(subjectIds, predicateIds, objectIds, assets);
    }

    /**
     * @notice Deposits Trust tokens into the MultiVault contract and receives shares in return
     * @param receiver The address that will receive the shares
     * @param termId The ID of the term to deposit into
     * @param curveId The ID of the bonding curve to use for the deposit
     * @param minShares The minimum number of shares to receive in return for the deposit
     */
    function deposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 minShares
    )
        external
        payable
        nonReentrant
        onlyRecipient
        onlyNonLockedTokens(msg.value)
        returns (uint256 shares)
    {
        shares = IMultiVault(multiVault).deposit{ value: msg.value }(receiver, termId, curveId, minShares);
    }

    /**
     * @notice Batch deposits Trust tokens into the MultiVault contract and receives shares in return
     * @param receiver The address that will receive the shares
     * @param termIds An array of term IDs to deposit into
     * @param curveIds An array of bonding curve IDs to use for the deposits
     * @param assets An array of assets of Trust tokens to deposit for each term
     * @param minShares An array of minimum shares to receive in return for each deposit
     */
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    )
        external
        payable
        nonReentrant
        onlyRecipient
        onlyNonLockedTokens(_sum(assets))
        returns (uint256[] memory shares)
    {
        shares =
            IMultiVault(multiVault).depositBatch{ value: msg.value }(receiver, termIds, curveIds, assets, minShares);
    }

    /**
     * @notice Redeems shares from the MultiVault contract and receives Trust tokens in return
     * @param receiver The address that will receive the withdrawn Trust tokens
     * @param termId The ID of the term to redeem from
     * @param curveId The ID of the bonding curve to use for the redemption
     * @param shares The number of shares to redeem
     * @param minAssets The minimum amount of Trust tokens to receive in return for the redemption
     */
    function redeem(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        external
        nonReentrant
        onlyRecipient
        returns (uint256 assets)
    {
        assets = IMultiVault(multiVault).redeem(receiver, termId, curveId, shares, minAssets);
    }

    /**
     * @notice Batch redeems shares from the MultiVault contract and receives Trust tokens in return
     * @param receiver The address that will receive the withdrawn Trust tokens
     * @param termIds An array of term IDs to redeem from
     * @param curveIds An array of bonding curve IDs to use for the redemptions
     * @param shares An array of numbers of shares to redeem
     * @param minAssets An array of minimum amounts of Trust tokens to receive in return for the redemptions
     */
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    )
        external
        nonReentrant
        onlyRecipient
        returns (uint256[] memory assets)
    {
        assets = IMultiVault(multiVault).redeemBatch(receiver, termIds, curveIds, shares, minAssets);
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
     * @dev If the TGE has not occurred yet (and thus unlock schedule has not started), the function returns 0, meaning
     * that the `unlockEnd` is not known yet
     * @return The timestamp at which all of the vesting tokens are unlocked and ready to be claimed
     */
    function unlockEnd() public view returns (uint256) {
        if (unlockStartTimestamp == 0) {
            return 0;
        }

        return unlockStartTimestamp + unlockCliff + unlockDuration;
    }

    /**
     * @notice Returns the timestamp at which the bonding lock ends for this contract
     * @return lockEndTimestamp The timestamp at which the bonding lock ends
     */
    function bondingLockEndTimestamp() external view returns (uint256 lockEndTimestamp) {
        (, lockEndTimestamp) = TrustBonding(trustBonding).locked(address(this));
    }

    /**
     * @notice Returns the amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the
     * recipient
     * @return The amount of Trust tokens bonded
     */
    function bondingLockedAmount() external view returns (uint256) {
        (int128 lockedAmount,) = TrustBonding(trustBonding).locked(address(this));
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
        // Unlocking doesn't start until the TGE has occurred (i.e. unlock schedule started) and the unlock cliff has
        // passed
        if (unlockStartTimestamp == 0 || timestamp < unlockStartTimestamp + unlockCliff) {
            return 0;
        } else if (timestamp >= unlockEnd()) {
            return vestedTokens;
        } else {
            uint256 unlockedAtCliff = (vestedTokens * unlockCliffPercentage) / BASIS_POINTS_DIVISOR;
            uint256 remainingToUnlock = vestedTokens - unlockedAtCliff;

            uint256 totalWeeks = unlockDuration / ONE_WEEK;
            uint256 unlockCliffTimestamp = unlockStartTimestamp + unlockCliff;
            uint256 elapsedWeeks = (timestamp - unlockCliffTimestamp) / ONE_WEEK;
            uint256 weeklyUnlocked = (remainingToUnlock * elapsedWeeks) / totalWeeks;

            return unlockedAtCliff + weeklyUnlocked;
        }
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures that the amount of Trust tokens used in a MultiVault action is not the amount that's subject to
     * the unlock and vesting
     * @param amount The amount of Trust tokens to check against the required locked amount
     */
    function _requireNonLockedTokens(uint256 amount) internal view {
        // Calculate vested amount (considering suspension if applicable)
        uint256 effectiveVestingTimestamp = isVestingSuspended() ? vestingSuspendedAt : block.timestamp;
        uint256 vestedNow = vestedAmount(effectiveVestingTimestamp);

        // Calculate unlocked amount
        uint256 unlockedNow = unlockedAmount(block.timestamp, vestedNow);

        // Required locked = vested but not yet unlocked
        uint256 requiredLockedAmount = vestedNow - unlockedNow;

        // Current balance including bonded
        uint256 balanceBefore = IERC20(trustToken).balanceOf(address(this)) + bondedAmount;
        uint256 balanceAfter = balanceBefore > amount ? balanceBefore - amount : 0;

        if (balanceAfter < requiredLockedAmount) {
            revert Unlock_InsufficientUnlockedTokens();
        }
    }

    /**
     * @notice Sums the elements of an array of uint256
     * @param values The array of uint256 values to sum
     * @return total The sum of the elements in the array
     */
    function _sum(uint256[] memory values) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
    }

    /**
     * @notice Wraps Trust tokens into the WrappedTrust contract and approves the TrustBonding contract to spend them
     * @param amount The amount of Trust tokens to wrap
     */
    function _wrapTrustTokens(uint256 amount) internal {
        WrappedTrust(trustToken).deposit{ value: amount }();
        WrappedTrust(trustToken).approve(address(trustBonding), amount);
    }

    /**
     * @notice Unwraps Trust tokens from the WrappedTrust contract
     * @param amount The amount of Trust tokens to unwrap
     */
    function _unwrapTrustTokens(uint256 amount) internal {
        WrappedTrust(trustToken).withdraw(amount);
    }
}
