// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUnlock } from "src/interfaces/IUnlock.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

/**
 * @title  TrustUnlock
 * @author 0xIntuition
 * @notice This contract is used to unlock Trust tokens to a recipient over a period of time, with an unlock cliff,
 *         and a linear unlock period after the unlock cliff. The intended recipients are Intuition's investors.
 * @dev    Inspired by the Uniswap's TreasuryVester.sol contract
 * (https://github.com/Uniswap/governance/blob/master/contracts/TreasuryVester.sol)
 */
contract TrustUnlock is IUnlock, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to hold the parameters for the TrustUnlock contract constructor
     * @param token The address of the Trust token contract
     * @param owner The address of the owner
     * @param trustBonding The address of the TrustBonding contract
     * @param multiVault The address of the MultiVault contract
     * @param unlockAmount The amount of Trust tokens to unlock
     * @param unlockBegin The timestamp at which the unlock begins
     * @param unlockCliff The timestamp at which the unlock cliff ends
     * @param unlockEnd The timestamp at which the unlock ends (i.e. all tokens are unlocked)
     * @param cliffPercentage The percentage of tokens unlocked at the unlock cliff (expressed in basis points)
     */
    struct UnlockParams {
        address owner;
        address payable token;
        address trustBonding;
        address payable multiVault;
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

    /// @notice The Trust (WTRUST) token contract
    address payable public immutable trustToken;

    /// @notice The TrustBonding contract
    address public immutable trustBonding;

    /// @notice The MultiVault contract
    address payable public immutable multiVault;

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

    /// @notice The amount of Trust tokens bonded to the TrustBonding contract by this contract on behalf of the
    /// recipient
    /// @dev This variable is used for internal accounting purposes and is reset to 0 when the tokens are withdrawn from
    /// the
    ///      TrustBonding contract
    uint256 public bondedAmount;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unlock_CliffIsTooEarly();
    error Unlock_EndIsTooEarly();
    error Unlock_InvalidCliffPercentage();
    error Unlock_InsufficientUnlockedTokens();
    error Unlock_UnlockBeginTooEarly();
    error Unlock_ZeroAddress();
    error Unlock_ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to ensure that the amount of Trust tokens used in a MultiVault action is not the amount that's
     * subject to the unlock
     * @param amount The amount of Trust tokens to check against the required locked amount
     */
    modifier onlyNonLockedTokens(uint256 amount) {
        if (address(this).balance < amount + unlockAmount - _unlockedAmount(block.timestamp)) {
            revert Unlock_InsufficientUnlockedTokens();
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
    constructor(UnlockParams memory unlockParams) Ownable(unlockParams.owner) {
        if (
            unlockParams.token == address(0) || unlockParams.owner == address(0)
                || unlockParams.trustBonding == address(0) || unlockParams.multiVault == address(0)
        ) {
            revert Unlock_ZeroAddress();
        }

        if (unlockParams.unlockAmount == 0) {
            revert Unlock_ZeroAmount();
        }

        if (unlockParams.unlockBegin < block.timestamp) {
            revert Unlock_UnlockBeginTooEarly();
        }

        if (unlockParams.unlockCliff < unlockParams.unlockBegin) {
            revert Unlock_CliffIsTooEarly();
        }

        if (unlockParams.cliffPercentage > BASIS_POINTS_DIVISOR) {
            revert Unlock_InvalidCliffPercentage();
        }

        // Since the contract uses a weekly unlock schedule, we want to make sure that the `unlockEnd`
        // is at least one week after the `unlockCliff` in order to avoid division by zero
        if (unlockParams.unlockEnd < unlockParams.unlockCliff + ONE_WEEK) {
            revert Unlock_EndIsTooEarly();
        }

        trustToken = unlockParams.token;
        unlockAmount = unlockParams.unlockAmount;
        unlockBegin = unlockParams.unlockBegin;
        unlockCliff = unlockParams.unlockCliff;
        cliffPercentage = unlockParams.cliffPercentage;
        unlockEnd = unlockParams.unlockEnd;
        trustBonding = unlockParams.trustBonding;
        multiVault = unlockParams.multiVault;
    }

    /// @notice Allow the contract to receive TRUST directly
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            OWNER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves the TrustBonding contract to spend Trust tokens held by this contract
     * @param amount The amount of Trust tokens to approve
     */
    function approveTrustBonding(uint256 amount) external onlyOwner {
        IERC20(trustToken).forceApprove(address(trustBonding), amount);
    }

    /**
     * @notice Withdraws non-locked Trust tokens from this contract to the specified receiver
     * @param to The address that will receive the withdrawn Trust tokens
     * @param amount The amount of Trust tokens to withdraw
     */
    function withdraw(address to, uint256 amount) external nonReentrant onlyOwner onlyNonLockedTokens(amount) {
        if (to == address(0)) {
            revert Unlock_ZeroAddress();
        }

        if (amount == 0) {
            revert Unlock_ZeroAmount();
        }

        Address.sendValue(payable(to), amount);
    }

    /*////////////////////////////////////////////////////////////////
                            TRUST BONDING ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bonds Trust tokens to the TrustBonding contract
     * @param amount The amount of Trust tokens to bond
     * @param unlockTime The timestamp at which the bonding lock will end
     */
    function create_lock(uint256 amount, uint256 unlockTime) external nonReentrant onlyOwner {
        bondedAmount += amount;
        _wrapTrustTokens(amount);
        TrustBonding(trustBonding).create_lock(amount, unlockTime);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the amount locked in an existing bonding lock
     * @param amount The amount of Trust tokens to add to the lock
     */
    function increase_amount(uint256 amount) external nonReentrant onlyOwner {
        bondedAmount += amount;
        _wrapTrustTokens(amount);
        TrustBonding(trustBonding).increase_amount(amount);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the unlock time of an existing bonding lock
     * @param newUnlockTime The new unlock time for the existing bonding lock
     */
    function increase_unlock_time(uint256 newUnlockTime) external nonReentrant onlyOwner {
        TrustBonding(trustBonding).increase_unlock_time(newUnlockTime);
    }

    /// @notice Claim unlocked tokens back from TrustBonding to this contract
    function withdraw() external onlyOwner nonReentrant {
        // Decrease internal accounting of bonded amount and withdraw Trust from TrustBonding to this contract
        bondedAmount = 0;
        TrustBonding(trustBonding).withdraw();
        _unwrapTrustTokens(IERC20(trustToken).balanceOf(address(this)));
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Claims Trust token rewards
     * @dev `rewardsRecipient` can be any address, not necessarily the recipient of the unlocked Trust tokens
     * @param rewardsRecipient The address to which the rewards are sent
     */
    function claimRewards(address rewardsRecipient) external nonReentrant onlyOwner {
        TrustBonding(trustBonding).claimRewards(rewardsRecipient);
        _unwrapTrustTokens(IERC20(trustToken).balanceOf(address(this)));
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
        onlyOwner
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
        onlyOwner
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
        onlyOwner
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
        onlyOwner
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
        onlyOwner
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
        onlyOwner
        returns (uint256[] memory assets)
    {
        assets = IMultiVault(multiVault).redeemBatch(receiver, termIds, curveIds, shares, minAssets);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Calculates the amount of Trust tokens that are unlocked at a given timestamp
     * @param timestamp The timestamp to calculate the unlocked amount at
     * @return The amount of Trust tokens unlocked at the given timestamp
     */
    function unlockedAmount(uint256 timestamp) public view returns (uint256) {
        return _unlockedAmount(timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _unlockedAmount(uint256 timestamp) internal view returns (uint256) {
        uint256 _unlockAmount = unlockAmount;
        if (timestamp < unlockCliff) {
            // Before cliff, no tokens are unlocked
            return 0;
        } else if (timestamp >= unlockEnd) {
            // After end, all tokens are unlocked
            return _unlockAmount;
        } else {
            // At or after cliff but before end:
            // 1) Cliff portion unlocked at unlockCliff
            uint256 cliffAmount = (_unlockAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;

            // 2) Remaining amount is unlocked weekly from unlockCliff to unlockEnd
            uint256 remainingAmount = _unlockAmount - cliffAmount;

            // Calculate how many full weeks have elapsed so far
            uint256 elapsedWeeks = (timestamp - unlockCliff) / ONE_WEEK;

            // Calculate total number of full weeks in the vesting schedule (after the cliff)
            uint256 totalWeeks = (unlockEnd - unlockCliff) / ONE_WEEK;

            // Clamp elapsedWeeks to totalWeeks (just in case 'timestamp' is close to unlockEnd)
            if (elapsedWeeks > totalWeeks) {
                elapsedWeeks = totalWeeks;
            }

            // Unlock a proportional chunk of the remainingAmount based on the elapsed weeks
            uint256 weeklyUnlocked = (remainingAmount * elapsedWeeks) / totalWeeks;

            return cliffAmount + weeklyUnlocked;
        }
    }

    function _wrapTrustTokens(uint256 amount) internal {
        WrappedTrust(trustToken).deposit{ value: amount }();
        WrappedTrust(trustToken).approve(address(trustBonding), amount);
    }

    function _unwrapTrustTokens(uint256 amount) internal {
        WrappedTrust(trustToken).withdraw(amount);
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
}
