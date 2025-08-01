// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {IUnlock} from "src/interfaces/IUnlock.sol";

/**
 * @title  TrustUnlock
 * @author 0xIntuition
 * @notice This contract is used to unlock Trust tokens to a recipient over a period of time, with an unlock cliff,
 *         and a linear unlock period after the unlock cliff. The intended recipients are Intuition's investors.
 * @dev    Inspired by the Uniswap's TreasuryVester.sol contract (https://github.com/Uniswap/governance/blob/master/contracts/TreasuryVester.sol)
 */
contract TrustUnlock is IUnlock, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to hold the parameters for the TrustUnlock contract constructor
     * @param trustToken The address of the Trust token contract
     * @param recipient The address of the recipient
     * @param trustBonding The address of the TrustBonding contract
     * @param multiVault The address of the MultiVault contract
     * @param unlockAmount The amount of Trust tokens to unlock
     * @param unlockBegin The timestamp at which the unlock begins
     * @param unlockCliff The timestamp at which the unlock cliff ends
     * @param unlockEnd The timestamp at which the unlock ends (i.e. all tokens are unlocked)
     * @param cliffPercentage The percentage of tokens unlocked at the unlock cliff (expressed in basis points)
     */
    struct UnlockParams {
        address trustToken;
        address recipient;
        address trustBonding;
        address multiVault;
        uint256 unlockAmount;
        uint256 unlockBegin;
        uint256 unlockCliff;
        uint256 unlockEnd;
        uint256 cliffPercentage;
    }

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points divisor used for calculations within the contract
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    /// @notice One week in seconds
    uint256 public constant ONE_WEEK = 1 weeks;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The TRUST token contract
    IERC20 public immutable trustToken;

    /// @notice The TrustBonding contract
    TrustBonding public immutable trustBonding;

    /// @notice The MultiVault contract
    IMultiVault public immutable multiVault;

    /// @notice The amount of Trust tokens to unlock
    uint256 public immutable unlockAmount;

    /// @notice The timestamp at which the unlock begins
    uint256 public immutable unlockBegin;

    /// @notice The timestamp at which the unlock cliff ends
    uint256 public immutable unlockCliff;

    /// @notice The timestamp at which the unlock ends (i.e. all tokens are unlocked)
    uint256 public immutable unlockEnd;

    /// @notice The percentage of tokens unlocked at the unlock cliff (expressed in basis points)
    uint256 public immutable cliffPercentage;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The recipient of the unlocked Trust tokens
    address public recipient;

    /// @notice The last time the Trust tokens were claimed
    uint256 public lastUpdate;

    /// @notice The amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the recipient
    /// @dev This variable is used for internal accounting purposes and is reset to 0 when the tokens are withdrawn from the
    ///      TrustBonding contract
    uint256 public bondedAmount;

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

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for a new TrustUnlock contract
     * @param unlockParams The parameters for the new TrustUnlock contract
     */
    constructor(UnlockParams memory unlockParams) {
        if (
            unlockParams.trustToken == address(0) || unlockParams.recipient == address(0)
                || unlockParams.trustBonding == address(0) || unlockParams.multiVault == address(0)
        ) {
            revert Errors.Unlock_ZeroAddress();
        }

        if (unlockParams.unlockAmount == 0) {
            revert Errors.Unlock_ZeroAmount();
        }

        if (unlockParams.unlockBegin < block.timestamp) {
            revert Errors.Unlock_UnlockBeginTooEarly();
        }

        if (unlockParams.unlockCliff < unlockParams.unlockBegin) {
            revert Errors.Unlock_CliffIsTooEarly();
        }

        if (unlockParams.cliffPercentage > BASIS_POINTS_DIVISOR) {
            revert Errors.Unlock_InvalidCliffPercentage();
        }

        // Since the contract uses a weekly unlock schedule, we want to make sure that the `unlockEnd`
        // is at least one week after the `unlockCliff` in order to avoid division by zero
        if (unlockParams.unlockEnd < unlockParams.unlockCliff + ONE_WEEK) {
            revert Errors.Unlock_EndIsTooEarly();
        }

        trustToken = IERC20(unlockParams.trustToken);
        unlockAmount = unlockParams.unlockAmount;
        unlockBegin = unlockParams.unlockBegin;
        unlockCliff = unlockParams.unlockCliff;
        cliffPercentage = unlockParams.cliffPercentage;
        unlockEnd = unlockParams.unlockEnd;

        recipient = unlockParams.recipient;
        trustBonding = TrustBonding(unlockParams.trustBonding);
        multiVault = IMultiVault(unlockParams.multiVault);
        lastUpdate = unlockBegin;
    }

    /*//////////////////////////////////////////////////////////////
                            RECIPIENT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the recipient of the unlocked Trust tokens
     * @param newRecipient The address of the new recipient
     */
    function setRecipient(address newRecipient) external onlyRecipient {
        if (newRecipient == address(0)) {
            revert Errors.Unlock_ZeroAddress();
        }

        recipient = newRecipient;

        emit RecipientSet(newRecipient);
    }

    /// @notice Claims the unlocked Trust tokens and transfers them to the recipient
    function claim() external onlyRecipient nonReentrant {
        if (block.timestamp < unlockCliff) {
            revert Errors.Unlock_NotTimeYet();
        }

        uint256 unlockedNow = unlockedAmount(block.timestamp);
        uint256 unlockedBefore = unlockedAmount(lastUpdate);

        uint256 amount = unlockedNow - unlockedBefore;
        lastUpdate = block.timestamp;

        if (amount == 0) {
            revert Errors.Unlock_ZeroAmount();
        }

        trustToken.safeTransfer(recipient, amount);

        emit Claimed(recipient, amount, block.timestamp);
    }

    /*////////////////////////////////////////////////////////////////
                            TRUSTBONDING ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves the TrustBonding contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveTrustBonding(uint256 amount) external onlyRecipient {
        trustToken.forceApprove(address(trustBonding), amount);
    }

    /**
     * @notice Bonds Trust tokens to the TrustBonding contract
     * @param amount The amount of Trust tokens to bond
     * @param lockDuration The duration in seconds for which the Trust tokens are locked in bonding
     */
    function createBond(uint256 amount, uint256 lockDuration) external onlyRecipient nonReentrant {
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
    function increaseBondedAmount(uint256 amount) external onlyRecipient nonReentrant {
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
                            MULTIVAULT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves the MultiVault contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveMultiVault(uint256 amount) external onlyRecipient {
        trustToken.forceApprove(address(multiVault), amount);
    }

    /**
     * @notice Creates new atoms in the MultiVault contract
     * @param atomDataArray An array of bytes containing the data for each atom to be created
     * @param value The amount of Trust tokens to use for creating each atom
     */
    function batchCreateAtom(bytes[] calldata atomDataArray, uint256 value)
        external
        onlyRecipient
        nonReentrant
        returns (bytes32[] memory atomIds)
    {
        atomIds = multiVault.batchCreateAtom(atomDataArray, value);
    }

    /**
     * @notice Creates new triples in the MultiVault contract
     * @param subjectIds An array of subject IDs for the triples
     * @param predicateIds An array of predicate IDs for the triples
     * @param objectIds An array of object IDs for the triples
     * @param value The amount of Trust tokens to use for creating each triple
     */
    function batchCreateTriple(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256 value
    ) external onlyRecipient nonReentrant returns (bytes32[] memory tripleIds) {
        tripleIds = multiVault.batchCreateTriple(subjectIds, predicateIds, objectIds, value);
    }

    /**
     * @notice Deposits Trust tokens into the MultiVault contract and receives shares in return
     * @dev Receiver can only be the TrustUnlock contract itself
     * @param termId The ID of the term to deposit into
     * @param bondingCurveId The ID of the bonding curve to use for the deposit
     * @param value The amount of Trust tokens to deposit
     * @param minSharesToReceive The minimum number of shares to receive in return for the deposit
     */
    function depositIntoMultiVault(bytes32 termId, uint256 bondingCurveId, uint256 value, uint256 minSharesToReceive)
        external
        onlyRecipient
        nonReentrant
        returns (uint256 shares)
    {
        shares = multiVault.deposit(address(this), termId, bondingCurveId, value, minSharesToReceive);
    }

    /**
     * @notice Batch deposits Trust tokens into the MultiVault contract and receives shares in return
     * @dev Receiver can only be the TrustUnlock contract itself
     * @param termIds An array of term IDs to deposit into
     * @param bondingCurveIds An array of bonding curve IDs to use for the deposits
     * @param amounts An array of amounts of Trust tokens to deposit for each term
     * @param minSharesToReceive An array of minimum shares to receive in return for each deposit
     */
    function batchDepositIntoMultiVault(
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata amounts,
        uint256[] calldata minSharesToReceive
    ) external onlyRecipient nonReentrant returns (uint256[] memory shares) {
        shares = multiVault.batchDeposit(address(this), termIds, bondingCurveIds, amounts, minSharesToReceive);
    }

    /**
     * @notice Redeems shares from the MultiVault contract and receives Trust tokens in return
     * @dev Receiver of the withdrawn assets can only be the TrustUnlock contract itself
     * @param shares The number of shares to redeem
     * @param termId The ID of the term to redeem from
     * @param bondingCurveId The ID of the bonding curve to use for the redemption
     * @param minAssetsToReceive The minimum amount of Trust tokens to receive in return for the redemption
     */
    function redeemFromMultiVault(uint256 shares, bytes32 termId, uint256 bondingCurveId, uint256 minAssetsToReceive)
        external
        onlyRecipient
        nonReentrant
        returns (uint256 assets)
    {
        assets = multiVault.redeem(shares, address(this), termId, bondingCurveId, minAssetsToReceive);
    }

    /**
     * @notice Batch redeems shares from the MultiVault contract and receives Trust tokens in return
     * @dev Receiver of the withdrawn assets can only be the TrustUnlock contract itself
     * @param shares An array of numbers of shares to redeem
     * @param termIds An array of term IDs to redeem from
     * @param bondingCurveIds An array of bonding curve IDs to use for the redemptions
     * @param minAssetsToReceive An array of minimum amounts of Trust tokens to receive in return for the redemptions
     */
    function batchRedeemFromMultiVault(
        uint256[] calldata shares,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata minAssetsToReceive
    ) external onlyRecipient nonReentrant returns (uint256[] memory assets) {
        assets = multiVault.batchRedeem(shares, address(this), termIds, bondingCurveIds, minAssetsToReceive);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Calculates the amount of Trust tokens that are unlocked at a given timestamp
     * @param timestamp The timestamp to calculate the unlocked amount at
     * @return The amount of Trust tokens unlocked at the given timestamp
     */
    function unlockedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < unlockCliff) {
            // Before cliff, no tokens are unlocked
            return 0;
        } else if (timestamp >= unlockEnd) {
            // After end, all tokens are unlocked
            return unlockAmount;
        } else {
            // At or after cliff but before end:
            // 1) Cliff portion unlocked at unlockCliff
            uint256 cliffAmount = (unlockAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;

            // 2) Remaining amount is unlocked weekly from unlockCliff to unlockEnd
            uint256 remainingAmount = unlockAmount - cliffAmount;

            // Calculate total number of full weeks in the vesting schedule (after the cliff)
            uint256 totalWeeks = (unlockEnd - unlockCliff) / ONE_WEEK;

            // Calculate how many full weeks have elapsed so far
            uint256 elapsedWeeks = (timestamp - unlockCliff) / ONE_WEEK;

            // Clamp elapsedWeeks to totalWeeks (just in case 'timestamp' is close to unlockEnd)
            if (elapsedWeeks > totalWeeks) {
                elapsedWeeks = totalWeeks;
            }

            // Unlock a proportional chunk of the remainingAmount based on the elapsed weeks
            uint256 weeklyUnlocked = (remainingAmount * elapsedWeeks) / totalWeeks;

            return cliffAmount + weeklyUnlocked;
        }
    }
}
