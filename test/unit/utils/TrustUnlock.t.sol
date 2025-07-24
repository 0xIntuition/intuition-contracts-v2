// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Errors} from "src/libraries/Errors.sol";
import {ITrustBonding} from "src/interfaces/ITrustBonding.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {TrustUnlock} from "src/v2/TrustUnlock.sol";

import {MockMultiVault} from "test/mocks/MockMultiVault.sol";
import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract TrustUnlockTest is Test {
    /// @notice Core contracts to be deployed
    TrustUnlock public trustUnlock;
    MockTrust public trustToken;
    TrustBonding public trustBonding;
    MockMultiVault public multiVault;

    /// @notice Constants
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = 1e8 * 1e18; // 10% of the initial supply (100 million tokens)
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    address public owner = makeAddr("owner");
    address public recipient = makeAddr("recipient");
    address public someAddress = makeAddr("someAddress");
    uint256 public constant unlockAmount = 1_000_000 * 1e18;
    uint256 public constant systemUtilizationLowerBound = 2_500;
    uint256 public constant personalUtilizationLowerBound = 2_500;

    /// @notice TrustUnlock config
    uint256 public constant oneWeek = 1 weeks;
    uint256 public unlockBegin;
    uint256 public unlockCliff;
    uint256 public constant cliffPercentage = 2500;
    uint256 public unlockEnd;

    /// @notice TrustBonding config
    uint256 public epochLength_ = 14 days;
    uint256 public startTimestamp = block.timestamp + 10 minutes;
    uint256 public defaultUnlockDuration = 2 * 365 days; // 2 years

    function setUp() external {
        vm.startPrank(owner);

        // Deploy MockTrust contract
        trustToken = new MockTrust("Intuition", "TRUST", MAX_POSSIBLE_ANNUAL_EMISSION);

        // Deploy TrustBonding contract
        trustBonding = new TrustBonding();

        // Deploy MultiVault contract
        multiVault = new MockMultiVault();

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), owner, "");

        trustBonding = TrustBonding(address(trustBondingProxy));

        // Initialize TrustBonding contract
        trustBonding.initialize(owner, address(trustToken), epochLength_, startTimestamp);

        // Reinitialize TrustBonding contract with MultiVault and utilization bounds
        trustBonding.reinitialize(address(multiVault), systemUtilizationLowerBound, personalUtilizationLowerBound);

        // Mint tokens to the owner
        trustToken.mint(owner, unlockAmount);

        // Deploy TrustUnlock contract
        unlockBegin = block.timestamp;
        unlockCliff = unlockBegin + 365 days; // 1‑year cliff
        uint256 unlockDuration = 3 * 365 days; // 3‑year linear vesting phase after the cliff
        unlockEnd = unlockCliff + unlockDuration;

        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        trustUnlock = new TrustUnlock(unlockParams);

        // Owner funds the TrustUnlock contract with the unlockAmount of tokens
        trustToken.transfer(address(trustUnlock), unlockAmount);

        vm.stopPrank();

        vm.startPrank(owner);

        // Smart contracts are not allowed to bond unless they are whitelisted.
        // This is done in order to prevent tokenizing the locked tokens.
        trustBonding.add_to_whitelist(address(trustUnlock));

        vm.stopPrank();
    }

    function test_verifyTrustUnlockDeploymentParams() external view {
        assertEq(address(trustUnlock.trustToken()), address(trustToken));
        assertEq(trustUnlock.recipient(), recipient);
        assertEq(address(trustUnlock.trustBonding()), address(trustBonding));
        assertEq(trustUnlock.unlockAmount(), unlockAmount);
        assertEq(trustUnlock.unlockBegin(), unlockBegin);
        assertEq(trustUnlock.unlockCliff(), unlockCliff);
        assertEq(trustUnlock.unlockEnd(), unlockEnd);
        assertEq(trustUnlock.cliffPercentage(), cliffPercentage);
        assertEq(trustUnlock.lastUpdate(), unlockBegin);
        assertEq(trustToken.balanceOf(address(trustUnlock)), unlockAmount);
    }

    function test_constructor_shouldRevertIfTrustTokenIsZeroAddress() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(0),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfRecipientIsZeroAddress() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: address(0),
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfTrustBondingIsZeroAddress() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(0),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfUnlockAmountIsZero() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: 0,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAmount.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfUnclokBeginIsInThePast() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: block.timestamp - 1,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_UnlockBeginTooEarly.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfUnlockCliffIsBeforeUnlockBegin() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockBegin - 1,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_CliffIsTooEarly.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfCliffPercentageIsHigherThanMax() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: 10001 // 100.01%
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_InvalidCliffPercentage.selector));
        new TrustUnlock(unlockParams);
    }

    function test_constructor_shouldRevertIfUnlockEndIsBeforeOrAtUnlockCliffPlusOneWeek() external {
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            trustToken: address(trustToken),
            recipient: recipient,
            trustBonding: address(trustBonding),
            unlockAmount: unlockAmount,
            unlockBegin: unlockBegin,
            unlockCliff: unlockCliff,
            unlockEnd: unlockCliff + 1 weeks - 1, // 1 week is the minimum unlock period
            cliffPercentage: cliffPercentage
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_EndIsTooEarly.selector));
        new TrustUnlock(unlockParams);
    }

    function test_setRecipient_shouldRevertIfCallerIsNotRecipient() external {
        vm.startPrank(someAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_OnlyRecipient.selector));
        trustUnlock.setRecipient(someAddress);
        vm.stopPrank();
    }

    function test_setReceipient_shouldRevertIfRecipientIsZeroAddress() external {
        vm.startPrank(recipient);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        trustUnlock.setRecipient(address(0));
        vm.stopPrank();
    }

    function test_setRecipient() external {
        vm.startPrank(recipient);
        trustUnlock.setRecipient(someAddress);
        assertEq(trustUnlock.recipient(), someAddress);
        vm.stopPrank();
    }

    function test_claim_shouldRevertIfCalledByNonRecipient() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_OnlyRecipient.selector));
        trustUnlock.claim();
    }

    function test_claim_shouldRevertIfCalledBeforeUnlockCliff() external {
        vm.startPrank(recipient);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_NotTimeYet.selector));
        trustUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldClaimAllTokensIfCalledAfterUnlockEnd() external {
        vm.startPrank(recipient);
        vm.warp(unlockEnd + 1);
        trustUnlock.claim();
        assertEq(trustToken.balanceOf(recipient), unlockAmount);
        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldFailToClaimZeroTokensIfCalledMultipleTimesInASingleBlock() external {
        vm.startPrank(recipient);
        vm.warp(unlockCliff);
        trustUnlock.claim();
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAmount.selector));
        trustUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldFailToClaimZeroTokensAfterAllTokensAreClaimed() external {
        vm.startPrank(recipient);
        vm.warp(unlockEnd);
        trustUnlock.claim();
        vm.warp(unlockEnd + 1 minutes);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAmount.selector));
        trustUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldClaimTokensUnlockedAtCliffIfCalledAtUnlockCliff() external {
        vm.startPrank(recipient);
        vm.warp(unlockCliff);
        trustUnlock.claim();
        uint256 expectedClaimableAmount = (unlockAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldClaimProportionalAmountOfTokensAfterUnlockCliffButBeforeUnlockEnd() external {
        vm.startPrank(recipient);
        vm.warp(unlockCliff + 365 days); // 1 year after cliff (50% of the unlocking period)
        trustUnlock.claim();
        uint256 expectedClaimableAmount = unlockAmount / 2;
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldClaimAppropriateAmountsWithMultipleClaimsBeforeUnlockEnd() external {
        vm.startPrank(recipient);
        vm.warp(unlockCliff + 365 days); // 1 year after cliff (50% of the unlocking period)
        trustUnlock.claim();
        uint256 expectedClaimableAmount = unlockAmount / 2;
        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);

        vm.warp(unlockCliff + 2 * 365 days); // 2 years after cliff (75% of the unlocking period)
        trustUnlock.claim();
        uint256 additionalClaimableAmount = unlockAmount / 4;
        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount + additionalClaimableAmount);
        vm.stopPrank();
    }

    function test_claim_shouldClaimOnlyOneWeeksWorthOfTokensAfterUnlockCliffIfCalledInBetweenTwoWeeks() external {
        vm.startPrank(recipient);
        vm.warp(unlockCliff + 1 weeks + 3.5 days); // ~ 1.5 weeks after cliff
        trustUnlock.claim();
        uint256 cliffAmount = (unlockAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;

        uint256 totalWeeks = (unlockEnd - unlockCliff) / 1 weeks;
        uint256 remainingAmount = unlockAmount - cliffAmount;
        uint256 weeksElapsed = (block.timestamp - unlockCliff) / 1 weeks;

        uint256 weeklyUnlocked = (remainingAmount * weeksElapsed) / totalWeeks;
        uint256 expectedClaimableAmount = cliffAmount + weeklyUnlocked;

        assertEq(trustUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        vm.stopPrank();
    }

    function test_unlockedAmount_shouldReturnZeroBeforeUnlockCliff() external view {
        assertEq(trustUnlock.unlockedAmount(unlockCliff - 1), 0);
    }

    function test_unlockedAmount_shouldReturnFullUnlockAmountAfterUnlockEnd() external view {
        assertEq(trustUnlock.unlockedAmount(unlockEnd + 1), unlockAmount);
    }

    function test_approveTrustBonding() external {
        vm.startPrank(recipient);
        trustUnlock.approveTrustBonding(unlockAmount);
        uint256 allowance = IERC20(trustToken).allowance(address(trustUnlock), address(trustBonding));
        assertEq(allowance, unlockAmount);
        vm.stopPrank();
    }

    function test_revokeTtrustBondingApproval_doesNothingIfNotApproved() external {
        vm.startPrank(recipient);
        uint256 allowanceBefore = IERC20(trustToken).allowance(address(trustUnlock), address(trustBonding));
        assertEq(allowanceBefore, 0);
        trustUnlock.revokeTrustBondingApproval();
        uint256 allowanceAfter = IERC20(trustToken).allowance(address(trustUnlock), address(trustBonding));
        assertEq(allowanceAfter, 0);
        vm.stopPrank();
    }

    function test_revokeTrustBondingApproval() external {
        vm.startPrank(recipient);
        trustUnlock.approveTrustBonding(unlockAmount);
        uint256 allowance = IERC20(trustToken).allowance(address(trustUnlock), address(trustBonding));
        assertEq(allowance, unlockAmount);
        trustUnlock.revokeTrustBondingApproval();
        allowance = IERC20(trustToken).allowance(address(trustUnlock), address(trustBonding));
        assertEq(allowance, 0);
        vm.stopPrank();
    }

    function test_completeBondingFlowIntegration() external {
        vm.startPrank(recipient);
        vm.warp(block.timestamp + 365 days);

        // Step 1: Approve TrustBonding
        trustUnlock.approveTrustBonding(unlockAmount);

        // Step 2: Create bond
        uint256 amount = (unlockAmount * cliffPercentage) / BASIS_POINTS_DIVISOR; // 250,000 (25% of the unlock amount)
        uint256 rawExpectedLockEndTimestamp = block.timestamp + defaultUnlockDuration;
        /// Locktime is rounded down to weeks
        uint256 expectedLockEndTimestamp = (rawExpectedLockEndTimestamp / oneWeek) * oneWeek;

        trustUnlock.createBond(amount, defaultUnlockDuration);

        assertEq(IERC20(trustToken).balanceOf(address(trustBonding)), amount);

        uint256 bondedBalance = trustUnlock.bondingLockedAmount();
        uint256 lockEndTimestamp = trustUnlock.bondingLockEndTimestamp();
        uint256 bondedAmount = trustUnlock.bondedAmount();

        assertEq(bondedBalance, amount);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);
        assertEq(bondedBalance, bondedAmount);
        assertEq(unlockAmount, bondedAmount + IERC20(trustToken).balanceOf(address(trustUnlock)));

        // Step 3: Increase bonded amount
        vm.warp(block.timestamp + oneWeek);

        // Subtract the cliff amount
        uint256 remainingAmount = trustUnlock.unlockAmount() - amount;
        uint256 unlockCliffTimestamp = trustUnlock.unlockCliff();
        uint256 totalWeeks = (trustUnlock.unlockEnd() - unlockCliffTimestamp) / oneWeek;
        uint256 elapsedWeeks = (block.timestamp - unlockCliffTimestamp) / oneWeek;
        uint256 newAmount = (remainingAmount * elapsedWeeks) / totalWeeks;

        trustUnlock.increaseBondedAmount(newAmount);

        bondedBalance = trustUnlock.bondingLockedAmount();
        lockEndTimestamp = trustUnlock.bondingLockEndTimestamp();
        bondedAmount = trustUnlock.bondedAmount();

        assertEq(bondedBalance, amount + newAmount);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);
        assertEq(bondedBalance, bondedAmount);
        assertEq(unlockAmount, bondedAmount + IERC20(trustToken).balanceOf(address(trustUnlock)));

        // Step 4: Increase bonding unlock time
        vm.warp(block.timestamp + oneWeek);

        // Calculate the new unlock time (based on the number of whole weeks elapsed since the last lock end timestamp)
        uint256 newUnlockTime = trustUnlock.bondingLockEndTimestamp() + ((oneWeek * 2) / oneWeek) * oneWeek;

        trustUnlock.increaseBondingUnlockTime(newUnlockTime);

        assertEq(trustUnlock.bondingLockEndTimestamp(), newUnlockTime);

        // Step 4: Claim accrued rewards
        vm.warp(block.timestamp + trustBonding.epochLength());

        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        uint256 eligibleRewardsAmount = trustBonding.userEligibleRewardsForEpoch(address(trustUnlock), previousEpoch);
        // adjust the eligibleRewardsAmount to account for the fact that vesting contracts cannot have
        // utilization, so only the lower bound of the utilization ratio is used
        uint256 adjustedRewardsAmount =
            (eligibleRewardsAmount * systemUtilizationLowerBound) / trustBonding.BASIS_POINTS_DIVISOR();
        // someAddress is the intended rewardsRecipient in this case
        uint256 someAddressBalanceBefore = IERC20(trustToken).balanceOf(someAddress);

        trustUnlock.claimRewards(someAddress);

        uint256 someAddressBalanceAfter = IERC20(trustToken).balanceOf(someAddress);

        assertEq(someAddressBalanceAfter, someAddressBalanceBefore + adjustedRewardsAmount);

        // Step 5: Withdraw bonded tokens
        vm.warp(newUnlockTime);

        trustUnlock.withdrawFromBonding();

        bondedBalance = trustUnlock.bondingLockedAmount();
        lockEndTimestamp = trustUnlock.bondingLockEndTimestamp();
        bondedAmount = trustUnlock.bondedAmount();

        assertEq(IERC20(trustToken).balanceOf(address(trustBonding)), 0);
        assertEq(lockEndTimestamp, 0);
        assertEq(bondedBalance, 0);
        assertEq(unlockAmount, IERC20(trustToken).balanceOf(address(trustUnlock)));

        vm.stopPrank();
    }
}
