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
import {TrustVestingAndUnlock} from "src/v2/TrustVestingAndUnlock.sol";

import {MockMultiVault} from "test/mocks/MockMultiVault.sol";
import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract TrustVestingAndUnlockTest is Test {
    /// @notice Core contracts to be deployed
    TrustVestingAndUnlock public trustVestingAndUnlock;
    TrustBonding public trustBonding;
    MockTrust public trustToken;
    MockMultiVault public multiVault;

    /// @notice Constants
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = 1e8 * 1e18; // 10% of the initial supply
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    address public constant recipient = address(1);
    address public constant admin = address(2);
    address public constant someAddress = address(3);
    uint256 public constant systemUtilizationLowerBound = 2_500;
    uint256 public constant personalUtilizationLowerBound = 2_500;

    /// @notice TrustVestingAndUnlock config
    uint256 public constant oneWeek = 1 weeks;
    uint256 public constant oneMonth = 30 days;
    uint256 public constant vestingAmount = 1_000_000 * 1e18;
    uint256 public vestingBegin;
    uint256 public vestingCliff;
    uint256 public constant cliffPercentage = 2500;
    uint256 public vestingEnd;
    uint256 public constant unlockCliff = 365 days;
    uint256 public constant unlockDuration = 2 * 365 days;
    uint256 public constant unlockCliffPercentage = 2500;
    TrustVestingAndUnlock.VestingParams public vestingParams;

    /// @notice TrustBonding config
    uint256 public epochLength_ = 14 days;
    uint256 public startTimestamp = block.timestamp + 10 minutes;
    uint256 public defaultUnlockDuration = 2 * 365 days; // 2 years

    function setUp() external {
        vm.startPrank(admin);

        // Deploy MockTrust contract
        trustToken = new MockTrust("Intuition", "TRUST", MAX_POSSIBLE_ANNUAL_EMISSION);

        // Deploy TrustBonding contract
        trustBonding = new TrustBonding();

        // Deploy MultiVault contract
        multiVault = new MockMultiVault();

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), admin, "");

        trustBonding = TrustBonding(address(trustBondingProxy));

        // Initialize TrustBonding contract
        trustBonding.initialize(admin, address(trustToken), epochLength_, startTimestamp);

        // Reinitialize TrustBonding contract with MultiVault and utilization bounds
        trustBonding.reinitialize(address(multiVault), systemUtilizationLowerBound, personalUtilizationLowerBound);

        // Deploy TrustVestingAndUnlock contract
        vestingBegin = block.timestamp;
        vestingCliff = vestingBegin + 365 days;
        vestingEnd = vestingBegin + 2 * 365 days;

        vestingParams = TrustVestingAndUnlock.VestingParams({
            trustToken: address(trustToken),
            recipient: recipient,
            admin: admin,
            trustBonding: address(trustBonding),
            multiVault: address(multiVault),
            vestingAmount: vestingAmount,
            vestingBegin: vestingBegin,
            vestingCliff: vestingCliff,
            cliffPercentage: cliffPercentage,
            vestingEnd: vestingEnd,
            unlockCliff: unlockCliff,
            unlockDuration: unlockDuration,
            unlockCliffPercentage: unlockCliffPercentage
        });

        trustVestingAndUnlock = new TrustVestingAndUnlock(vestingParams);

        trustVestingAndUnlock.setTGETimestamp(block.timestamp);

        trustToken.mint(address(admin), vestingAmount * 2);

        // Transfer half of the vesting amount to the TrustVestingAndUnlock contract
        trustToken.transfer(address(trustVestingAndUnlock), vestingAmount);

        // Smart contracts are not allowed to bond unless they are whitelisted.
        // This is done in order to prevent tokenizing the locked tokens.
        trustBonding.add_to_whitelist(address(trustVestingAndUnlock));

        vm.stopPrank();
    }

    function test_constructor_shouldRevertIfTrustTokenIsAddressZero() external {
        vestingParams.trustToken = address(0);

        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfRecipientIsAddressZero() external {
        vestingParams.recipient = address(0);

        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfTrustBondingIsAddressZero() external {
        vestingParams.trustBonding = address(0);

        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfVestingAmountIsZero() external {
        vestingParams.vestingAmount = 0;

        vm.expectRevert(Errors.Unlock_ZeroAmount.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfVestingBeginIsInThePast() external {
        vestingParams.vestingBegin = block.timestamp - 1;

        vm.expectRevert(Errors.Unlock_VestingBeginTooEarly.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfVestingCliffIsBeforeVestingBegin() external {
        vestingParams.vestingCliff = vestingBegin - 1;

        vm.expectRevert(Errors.Unlock_CliffIsTooEarly.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfVestingEndIsBeforeOrAtVestingCliffPlusOneMonth() external {
        // + 1 month is added since that is the minimum time between the vesting cliff and the vesting end
        vestingParams.vestingEnd = vestingCliff + oneMonth - 1;

        vm.expectRevert(Errors.Unlock_EndIsTooEarly.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfUnlockCliffDurationIsInvalid() external {
        vestingParams.unlockCliff = 0;

        vm.expectRevert(Errors.Unlock_InvalidUnlockCliff.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfUnlockDurationIsInvalid() external {
        // Unlock duration must be at least one week
        vestingParams.unlockDuration = oneWeek - 1;

        vm.expectRevert(Errors.Unlock_InvalidUnlockDuration.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfCliffPercentageIsHigherThanMax() external {
        vestingParams.cliffPercentage = BASIS_POINTS_DIVISOR + 1;

        vm.expectRevert(Errors.Unlock_InvalidCliffPercentage.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_constructor_shouldRevertIfUnlockCliffPercentageIsHigherThanMax() external {
        vestingParams.unlockCliffPercentage = BASIS_POINTS_DIVISOR + 1;

        vm.expectRevert(Errors.Unlock_InvalidCliffPercentage.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_setTGETimestamp() external {
        TrustVestingAndUnlock trustVestingAndUnlock2 = new TrustVestingAndUnlock(vestingParams);

        uint256 tgeTimestamp = block.timestamp;
        vm.startPrank(admin);
        trustVestingAndUnlock2.setTGETimestamp(tgeTimestamp);
        assertEq(trustVestingAndUnlock2.tgeTimestamp(), tgeTimestamp);
        vm.stopPrank();
    }

    function test_setTGETimestamp_shouldRevertIfTGEAlreadySet() external {
        uint256 tgeTimestamp = block.timestamp;
        vm.startPrank(admin);
        vm.expectRevert(Errors.Unlock_TGETimestampAlreadySet.selector);
        trustVestingAndUnlock.setTGETimestamp(tgeTimestamp);
        vm.stopPrank();
    }

    function test_suspendVesting_shouldRevertIfTryingToSuspendVestingWhenItAlreadedEnded() external {
        vm.warp(vestingEnd + 1);

        vm.startPrank(admin);
        vm.expectRevert(Errors.Unlock_VestingAlreadyEnded.selector);
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        vm.stopPrank();
    }

    function test_suspendVesting_shouldRevertIfVestingAlreadySuspended() external {
        vm.startPrank(admin);
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        assertEq(trustVestingAndUnlock.isVestingSuspended(), true);

        vm.expectRevert(Errors.Unlock_VestingAlreadySuspended.selector);
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        vm.stopPrank();
    }

    function test_suspendVesting_shouldRevertIfSuspensionTimestampIsBeforeVestingBegin() external {
        vm.startPrank(admin);
        vm.expectRevert(Errors.Unlock_SuspensionBeforeVestingBegin.selector);
        trustVestingAndUnlock.suspendVesting(vestingBegin - 1);
        vm.stopPrank();
    }

    function test_suspendVesting_shouldRevertIfVestingSuspensionTimestampIsInTheFuture() external {
        vm.startPrank(admin);
        vm.expectRevert(Errors.Unlock_SuspensionTimestampInFuture.selector);
        trustVestingAndUnlock.suspendVesting(block.timestamp + 1);
        vm.stopPrank();
    }

    function test_suspendVesting_shouldRevertIfCallerIsNotAdmin() external {
        vm.startPrank(someAddress);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        vm.stopPrank();
    }

    function test_suspendVesting() external {
        vm.startPrank(admin);

        uint256 adminBalanceBefore = IERC20(trustToken).balanceOf(admin);
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        uint256 adminBalanceAfter = IERC20(trustToken).balanceOf(admin);

        assertEq(trustVestingAndUnlock.isVestingSuspended(), true);
        assertEq(trustVestingAndUnlock.vestingSuspendedAt(), block.timestamp);
        assertEq(adminBalanceAfter, adminBalanceBefore + vestingAmount);

        vm.stopPrank();
    }

    function test_setRecipient_shouldRevertIfCallerIsNotRecipient() external {
        vm.startPrank(admin);
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.setRecipient(someAddress);
        vm.stopPrank();
    }

    function test_setRecipient_shouldRevertIfRecipientIsZeroAddress() external {
        vm.startPrank(recipient);
        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        trustVestingAndUnlock.setRecipient(address(0));
        vm.stopPrank();
    }

    function test_trustVestingAndUnlockTest_setRecipient() external {
        vm.startPrank(recipient);
        trustVestingAndUnlock.setRecipient(someAddress);
        assertEq(trustVestingAndUnlock.recipient(), someAddress);
        vm.stopPrank();
    }

    function test_claim_shouldRevertIfCalledByNonRecipient() external {
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.claim();
    }

    function test_claim_shouldRevertIfCalledBeforeUnlockCliff() external {
        vm.startPrank(recipient);
        vm.expectRevert(Errors.Unlock_NotTimeYet.selector);
        trustVestingAndUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldClaimAllTokensIfCalledAfterUnlockEnd() external {
        vm.startPrank(recipient);
        uint256 unlockEnd = trustVestingAndUnlock.unlockEnd();
        vm.warp(unlockEnd);
        trustVestingAndUnlock.claim();
        assertEq(trustToken.balanceOf(recipient), vestingAmount);
        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldFailToClaimZeroTokensIfCalledMultipleTimesInASingleBlock() external {
        vm.startPrank(recipient);
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        trustVestingAndUnlock.claim();
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_NotTimeYet.selector));
        trustVestingAndUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldFailToClaimZeroTokensAfterAllTokensAreClaimed() external {
        vm.startPrank(recipient);
        uint256 unlockEnd = trustVestingAndUnlock.unlockEnd();
        vm.warp(unlockEnd);
        trustVestingAndUnlock.claim();
        vm.warp(unlockEnd + 1 minutes);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_NotTimeYet.selector));
        trustVestingAndUnlock.claim();
        vm.stopPrank();
    }

    function test_claim_shouldClaimTokensUnlockedAtCliffIfCalledAtUnlockCliff() external {
        vm.startPrank(recipient);
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        trustVestingAndUnlock.claim();

        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp);
        uint256 expectedClaimableAmount = (vestedTokens * cliffPercentage) / BASIS_POINTS_DIVISOR;
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldClaimProportionalAmountOfTokensAfterUnlockCliffButBeforeUnlockEnd() external {
        vm.startPrank(recipient);
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp + 365 days); // 1 year after cliff (50% of the unlocking period)
        trustVestingAndUnlock.claim();
        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp + 365 days);
        uint256 expectedClaimableAmount =
            trustVestingAndUnlock.unlockedAmount(unlockCliffTimestamp + 365 days, vestedTokens);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function test_claim_shouldClaimAppropriateAmountsWithMultipleClaimsBeforeUnlockEnd() external {
        vm.startPrank(recipient);
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp + 365 days); // 1 year after cliff (50% of the unlocking period)
        trustVestingAndUnlock.claim();

        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp + 365 days);
        uint256 expectedClaimableAmount =
            trustVestingAndUnlock.unlockedAmount(unlockCliffTimestamp + 365 days, vestedTokens);
        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);

        vm.warp(unlockCliffTimestamp + 2 * 365 days); // 2 years after cliff (75% of the unlocking period)
        trustVestingAndUnlock.claim();

        vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp + 2 * 365 days);
        expectedClaimableAmount =
            trustVestingAndUnlock.unlockedAmount(unlockCliffTimestamp + 2 * 365 days, vestedTokens);
        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        vm.stopPrank();
    }

    function test_claim_shouldClaimOnlyOneWeeksWorthOfTokensAfterUnlockCliffIfCalledInBetweenTwoWeeks() external {
        vm.startPrank(recipient);
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;

        vm.warp(unlockCliffTimestamp + oneWeek + 3.5 days); // ~ 1.5 weeks after cliff
        trustVestingAndUnlock.claim();

        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp + oneWeek + 3.5 days);
        uint256 cliffAmount = (vestedTokens * unlockCliffPercentage) / BASIS_POINTS_DIVISOR;
        uint256 remainingAmount = vestedTokens - cliffAmount;

        uint256 totalWeeks = unlockDuration / oneWeek;
        uint256 weeksElapsed = (block.timestamp - unlockCliffTimestamp) / oneWeek;

        uint256 weeklyUnlocked = (remainingAmount * weeksElapsed) / totalWeeks;
        uint256 expectedClaimableAmount = cliffAmount + weeklyUnlocked;

        assertEq(trustVestingAndUnlock.lastUpdate(), block.timestamp);
        assertEq(trustToken.balanceOf(recipient), expectedClaimableAmount);
        vm.stopPrank();
    }

    function test_approveTrustBonding() external {
        vm.startPrank(recipient);
        trustVestingAndUnlock.approveTrustBonding(vestingAmount);
        uint256 allowance = IERC20(trustToken).allowance(address(trustVestingAndUnlock), address(trustBonding));
        assertEq(allowance, vestingAmount);
        vm.stopPrank();
    }

    function test_createBond_shouldRevertIfTryingToBondBeforeVestingCliff() external {
        vm.startPrank(recipient);
        uint256 amount = 1e18; // user shouldn't be able to bond any amount before the vesting cliff

        vm.expectRevert(Errors.Unlock_NotEnoughVested.selector);
        trustVestingAndUnlock.createBond(amount, defaultUnlockDuration);
        vm.stopPrank();
    }

    function test_createBond_useVestingSuspendedAtAsEffectiveTimestampIfVestingIsSuspended() external {
        vm.warp(block.timestamp + 365 days);

        // Step 1: Approve TrustBonding
        vm.prank(recipient);
        trustVestingAndUnlock.approveTrustBonding(vestingAmount);

        // Step 2: Suspend vesting
        uint256 adminBalanceBefore = IERC20(trustToken).balanceOf(admin);

        vm.prank(admin);
        trustVestingAndUnlock.suspendVesting(block.timestamp);

        uint256 adminBalanceAfter = IERC20(trustToken).balanceOf(admin);
        uint256 adminWithdrawnTokens = adminBalanceAfter - adminBalanceBefore;

        uint256 expectedVestedTokens = trustVestingAndUnlock.vestedAmount(block.timestamp);
        uint256 expectedAdminWithdrawnTokens = trustVestingAndUnlock.vestingAmount() - expectedVestedTokens;

        assertEq(trustVestingAndUnlock.isVestingSuspended(), true);
        assertEq(trustVestingAndUnlock.vestingSuspendedAt(), block.timestamp);
        assertEq(adminWithdrawnTokens, expectedAdminWithdrawnTokens);

        // Step 3: Create bond
        vm.warp(block.timestamp + oneMonth);

        // vestingSuspendedAt becomes the effectiveTimestamp used in the checkMaxVested modifier, despite some time passing since the suspension.
        // If the vesting was not suspended, user will be able to bond more tokens than the cliff amount.
        vm.startPrank(recipient);
        uint256 amount = (vestingAmount * cliffPercentage) / BASIS_POINTS_DIVISOR; // 250,000 (25% of the vesting amount)
        uint256 rawExpectedLockEndTimestamp = block.timestamp + defaultUnlockDuration;
        /// Locktime is rounded down to weeks
        uint256 expectedLockEndTimestamp = (rawExpectedLockEndTimestamp / oneWeek) * oneWeek;

        // vestingSuspendedAt becomes the effectiveTimestamp used in the checkMaxVested modifier, despite some time passing since the suspension.
        // If the vesting was not suspended, user will be able to bond more tokens than the cliff amount.
        vm.expectRevert(Errors.Unlock_NotEnoughVested.selector);
        trustVestingAndUnlock.createBond(amount + 1, defaultUnlockDuration);

        // It should succeed if the amount is equal to the cliff amount, which was vested at the time of suspension
        trustVestingAndUnlock.createBond(amount, defaultUnlockDuration);

        assertEq(IERC20(trustToken).balanceOf(address(trustBonding)), amount);

        uint256 bondedBalance = trustVestingAndUnlock.bondingLockedAmount();
        uint256 lockEndTimestamp = trustVestingAndUnlock.bondingLockEndTimestamp();
        uint256 bondedAmount = trustVestingAndUnlock.bondedAmount();

        assertEq(bondedBalance, amount);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);
        assertEq(bondedBalance, bondedAmount);

        vm.stopPrank();
    }

    function test_completeBondingFlowIntegration() external {
        vm.startPrank(recipient);
        vm.warp(block.timestamp + 365 days);

        // Step 1: Approve TrustBonding
        trustVestingAndUnlock.approveTrustBonding(vestingAmount);

        // Step 2: Create bond
        uint256 amount = (vestingAmount * cliffPercentage) / BASIS_POINTS_DIVISOR; // 250,000 (25% of the vesting amount)
        uint256 rawExpectedLockEndTimestamp = block.timestamp + defaultUnlockDuration;
        /// Locktime is rounded down to weeks
        uint256 expectedLockEndTimestamp = (rawExpectedLockEndTimestamp / oneWeek) * oneWeek;

        trustVestingAndUnlock.createBond(amount, defaultUnlockDuration);

        assertEq(IERC20(trustToken).balanceOf(address(trustBonding)), amount);

        uint256 bondedBalance = trustVestingAndUnlock.bondingLockedAmount();
        uint256 lockEndTimestamp = trustVestingAndUnlock.bondingLockEndTimestamp();
        uint256 bondedAmount = trustVestingAndUnlock.bondedAmount();

        assertEq(bondedBalance, amount);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);
        assertEq(bondedBalance, bondedAmount);
        assertEq(vestingAmount, bondedAmount + IERC20(trustToken).balanceOf(address(trustVestingAndUnlock)));

        // Step 3: Increase bonded amount
        vm.warp(block.timestamp + oneMonth);

        // Subtract the cliff amount
        uint256 remainingAmount = trustVestingAndUnlock.vestingAmount() - amount;
        uint256 vestingCliffTimestamp = trustVestingAndUnlock.vestingCliff();
        uint256 totalMonths = (trustVestingAndUnlock.vestingEnd() - vestingCliffTimestamp) / oneMonth;
        uint256 elapsedMonths = (block.timestamp - vestingCliffTimestamp) / oneMonth;
        uint256 newAmount = (remainingAmount * elapsedMonths) / totalMonths;

        trustVestingAndUnlock.increaseBondedAmount(newAmount);

        bondedBalance = trustVestingAndUnlock.bondingLockedAmount();
        lockEndTimestamp = trustVestingAndUnlock.bondingLockEndTimestamp();
        bondedAmount = trustVestingAndUnlock.bondedAmount();

        assertEq(bondedBalance, amount + newAmount);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);
        assertEq(bondedBalance, bondedAmount);
        assertEq(vestingAmount, bondedAmount + IERC20(trustToken).balanceOf(address(trustVestingAndUnlock)));

        // Step 4: Increase bonding unlock time
        vm.warp(block.timestamp + oneMonth);

        // Calculate the new unlock time (based on the number of whole weeks elapsed since the last lock end timestamp)
        uint256 newUnlockTime = trustVestingAndUnlock.bondingLockEndTimestamp() + ((oneMonth * 2) / oneWeek) * oneWeek;

        trustVestingAndUnlock.increaseBondingUnlockTime(newUnlockTime);

        assertEq(trustVestingAndUnlock.bondingLockEndTimestamp(), newUnlockTime);

        // Step 4: Claim accrued rewards
        vm.warp(block.timestamp + trustBonding.epochLength());

        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        uint256 eligibleRewardsAmount =
            trustBonding.userEligibleRewardsForEpoch(address(trustVestingAndUnlock), previousEpoch);
        // adjust the eligibleRewardsAmount to account for the fact that vesting contracts cannot have
        // utilization, so only the lower bound of the utilization ratio is used
        uint256 adjustedRewardsAmount =
            (eligibleRewardsAmount * systemUtilizationLowerBound) / trustBonding.BASIS_POINTS_DIVISOR();
        // someAddress is the intended rewardsRecipient in this case
        uint256 someAddressBalanceBefore = IERC20(trustToken).balanceOf(someAddress);

        trustVestingAndUnlock.claimRewards(someAddress);

        uint256 someAddressBalanceAfter = IERC20(trustToken).balanceOf(someAddress);

        assertEq(someAddressBalanceAfter, someAddressBalanceBefore + adjustedRewardsAmount);

        // Step 5: Withdraw bonded tokens
        vm.warp(newUnlockTime);

        trustVestingAndUnlock.withdrawFromBonding();

        bondedBalance = trustVestingAndUnlock.bondingLockedAmount();
        lockEndTimestamp = trustVestingAndUnlock.bondingLockEndTimestamp();
        bondedAmount = trustVestingAndUnlock.bondedAmount();

        assertEq(IERC20(trustToken).balanceOf(address(trustBonding)), 0);
        assertEq(lockEndTimestamp, 0);
        assertEq(bondedBalance, 0);
        assertEq(vestingAmount, IERC20(trustToken).balanceOf(address(trustVestingAndUnlock)));

        vm.stopPrank();
    }

    function test_unlockEnd_shouldReturnZeroIfTGETimestampIsNotSet() external {
        // Slot 5 as can be seen when running the `forge inspect TrustVestingAndUnlock storage-layout` command
        bytes32 slot = bytes32(uint256(5));

        // Set tgeTimestamp to zero for the need of this test
        vm.store(address(trustVestingAndUnlock), slot, bytes32(uint256(0)));

        assertEq(trustVestingAndUnlock.unlockEnd(), 0);
    }

    function test_unlockEnd_shouldReturnZeroIfVestingIsSuspended() external {
        vm.startPrank(admin);
        trustVestingAndUnlock.suspendVesting(block.timestamp);
        assertEq(trustVestingAndUnlock.unlockEnd(), 0);
        vm.stopPrank();
    }

    function test_unlockEnd_shouldReturnCorrectUnlockEndTimestamp() external {
        vm.startPrank(admin);
        uint256 expectedUnlockEnd = trustVestingAndUnlock.tgeTimestamp() + unlockCliff + unlockDuration;
        assertEq(trustVestingAndUnlock.unlockEnd(), expectedUnlockEnd);
        vm.stopPrank();
    }

    function test_vestedAmount_shouldReturnZeroIfTimestampIsBeforeVestingCliif() external view {
        uint256 vestedAmount = trustVestingAndUnlock.vestedAmount(vestingCliff - 1);
        assertEq(vestedAmount, 0);
    }

    function test_vestedAmount_shouldReturnEntireVestingAmountIfCalledAfterVestingEnd() external view {
        uint256 vestedAmount = trustVestingAndUnlock.vestedAmount(vestingEnd + 1);
        assertEq(vestedAmount, trustVestingAndUnlock.vestingAmount());
    }

    function test_vestedAmount_shouldReturnCorrectVestingAmount() external view {
        uint256 expectedVestedAmount = (vestingAmount * cliffPercentage) / BASIS_POINTS_DIVISOR;
        uint256 vestedAmount = trustVestingAndUnlock.vestedAmount(vestingCliff + 1);
        assertEq(expectedVestedAmount, vestedAmount);
    }

    function test_unlockedAmount_shouldReturnZeroIfTGETimestampIsNotSet() external {
        // Slot 5 as can be seen when running the `forge inspect TrustVestingAndUnlock storage-layout` command
        bytes32 slot = bytes32(uint256(5));

        // Set tgeTimestamp to zero for the need of this test
        vm.store(address(trustVestingAndUnlock), slot, bytes32(uint256(0)));
        assertEq(trustVestingAndUnlock.tgeTimestamp(), 0);

        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(block.timestamp);
        assertEq(trustVestingAndUnlock.unlockedAmount(block.timestamp, vestedTokens), 0);
    }

    function test_unlockedAmount_shouldReturnZeroIfTimestampIsBeforeUnlockCliff() external view {
        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(block.timestamp);
        uint256 unlockedAmount = trustVestingAndUnlock.unlockedAmount(block.timestamp, vestedTokens);
        assertEq(unlockedAmount, 0);
    }

    function test_unlockedAmount_shouldReturnEntireVestingAmountIfTimestampIsAfterUnlockEnd() external view {
        uint256 unlockEndTimestamp = trustVestingAndUnlock.unlockEnd() + 1;
        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockEndTimestamp);
        uint256 unlockedAmount = trustVestingAndUnlock.unlockedAmount(unlockEndTimestamp, vestedTokens);

        assertEq(unlockedAmount, vestedTokens);
        assertEq(unlockedAmount, trustVestingAndUnlock.vestingAmount());
    }

    function test_unlockedAmount_shouldReturnCorrectUnlockedAmount() external view {
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp + 1);
        uint256 unlockedAmount = trustVestingAndUnlock.unlockedAmount(unlockCliffTimestamp + 1, vestedTokens);

        uint256 expectedUnlockedAmount = (vestedTokens * unlockCliffPercentage) / BASIS_POINTS_DIVISOR;
        assertEq(unlockedAmount, expectedUnlockedAmount);

        // Should unlock weekly unlocked amount more if the timestamp is 1 week after the unlock cliff
        uint256 oneWeekAfterUnlockCliff = unlockCliffTimestamp + oneWeek;

        vestedTokens = trustVestingAndUnlock.vestedAmount(oneWeekAfterUnlockCliff);
        unlockedAmount = trustVestingAndUnlock.unlockedAmount(oneWeekAfterUnlockCliff, vestedTokens);

        uint256 remainingAmount = vestedTokens - expectedUnlockedAmount; // subtract tokens unlocked at cliff
        uint256 totalWeeks = unlockDuration / oneWeek;
        uint256 weeksElapsed = (oneWeekAfterUnlockCliff - unlockCliffTimestamp) / oneWeek;
        uint256 weeklyUnlocked = (remainingAmount * weeksElapsed) / totalWeeks;

        expectedUnlockedAmount += weeklyUnlocked; // amount unlocked at cliff + new, weekly (linear) unlocked amount

        assertEq(unlockedAmount, expectedUnlockedAmount);
    }

    function test_constructor_shouldRevertIfMultiVaultIsZeroAddress() external {
        vestingParams.multiVault = address(0);

        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        new TrustVestingAndUnlock(vestingParams);
    }

    function test_approveMultiVault_shouldRevertIfCallerIsNotRecipient() external {
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);
    }

    function test_approveMultiVault() external {
        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);
        uint256 allowance = IERC20(trustToken).allowance(address(trustVestingAndUnlock), address(multiVault));
        assertEq(allowance, vestingAmount);
        vm.stopPrank();
    }

    function test_createAtoms_shouldRevertIfCallerIsNotRecipient() external {
        bytes[] memory atomDataArray = new bytes[](2);
        atomDataArray[0] = "atom1";
        atomDataArray[1] = "atom2";

        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.createAtoms(atomDataArray, 1000);
    }

    function test_createAtoms_shouldRevertIfAmountExceedsUnlockedAmount() external {
        vm.warp(vestingCliff + oneMonth);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes[] memory atomDataArray = new bytes[](2);
        atomDataArray[0] = "atom1";
        atomDataArray[1] = "atom2";

        vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
        trustVestingAndUnlock.createAtoms(atomDataArray, vestingAmount);
        vm.stopPrank();
    }

    function test_createAtoms() external {
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes[] memory atomDataArray = new bytes[](2);
        atomDataArray[0] = "atom1";
        atomDataArray[1] = "atom2";

        bytes32[] memory atomIds = trustVestingAndUnlock.createAtoms(atomDataArray, 1000);

        assertEq(atomIds.length, 2);
        assertTrue(atomIds[0] != bytes32(0));
        assertTrue(atomIds[1] != bytes32(0));
        vm.stopPrank();
    }

    function test_createTriples_shouldRevertIfCallerIsNotRecipient() external {
        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);

        TrustVestingAndUnlock.CreateTriplesData memory tripleData = TrustVestingAndUnlock.CreateTriplesData({
            subjectIds: subjectIds,
            predicateIds: predicateIds,
            objectIds: objectIds,
            value: 1000
        });

        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.createTriples(tripleData);
    }

    function test_createTriples_shouldRevertIfAmountExceedsUnlockedAmount() external {
        vm.warp(vestingCliff + oneMonth);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);

        TrustVestingAndUnlock.CreateTriplesData memory tripleData = TrustVestingAndUnlock.CreateTriplesData({
            subjectIds: subjectIds,
            predicateIds: predicateIds,
            objectIds: objectIds,
            value: vestingAmount
        });

        vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
        trustVestingAndUnlock.createTriples(tripleData);
        vm.stopPrank();
    }

    function test_createTriples() external {
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);
        subjectIds[0] = keccak256("subject1");
        subjectIds[1] = keccak256("subject2");
        predicateIds[0] = keccak256("predicate1");
        predicateIds[1] = keccak256("predicate2");
        objectIds[0] = keccak256("object1");
        objectIds[1] = keccak256("object2");

        TrustVestingAndUnlock.CreateTriplesData memory tripleData = TrustVestingAndUnlock.CreateTriplesData({
            subjectIds: subjectIds,
            predicateIds: predicateIds,
            objectIds: objectIds,
            value: 1000
        });

        bytes32[] memory tripleIds = trustVestingAndUnlock.createTriples(tripleData);

        assertEq(tripleIds.length, 2);
        assertTrue(tripleIds[0] != bytes32(0));
        assertTrue(tripleIds[1] != bytes32(0));
        vm.stopPrank();
    }

    function test_depositIntoMultiVault_shouldRevertIfCallerIsNotRecipient() external {
        address receiver = makeAddr("receiver");
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.depositIntoMultiVault(receiver, keccak256("term"), 1, 1000, 900);
    }

    function test_depositIntoMultiVault_shouldRevertIfAmountExceedsUnlockedAmount() external {
        address receiver = makeAddr("receiver");
        vm.warp(vestingCliff + oneMonth);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
        trustVestingAndUnlock.depositIntoMultiVault(receiver, keccak256("term"), 1, vestingAmount, 900);
        vm.stopPrank();
    }

    function test_depositIntoMultiVault() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32 termId = keccak256("term");
        uint256 bondingCurveId = 1;
        uint256 value = 1000;
        uint256 minSharesToReceive = 900;

        uint256 shares =
            trustVestingAndUnlock.depositIntoMultiVault(receiver, termId, bondingCurveId, value, minSharesToReceive);

        assertEq(shares, value);
        vm.stopPrank();
    }

    function test_batchDepositIntoMultiVault_shouldRevertIfCallerIsNotRecipient() external {
        address receiver = makeAddr("receiver");
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory minSharesToReceive = new uint256[](2);

        TrustVestingAndUnlock.BatchDepositData memory batchDepositData = TrustVestingAndUnlock.BatchDepositData({
            receiver: receiver,
            termIds: termIds,
            bondingCurveIds: bondingCurveIds,
            amounts: amounts,
            minSharesToReceive: minSharesToReceive
        });

        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.batchDepositIntoMultiVault(batchDepositData);
    }

    function test_batchDepositIntoMultiVault_shouldRevertIfTotalAmountExceedsUnlockedAmount() external {
        address receiver = makeAddr("receiver");
        vm.warp(vestingCliff + oneMonth);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory minSharesToReceive = new uint256[](2);

        termIds[0] = keccak256("term1");
        termIds[1] = keccak256("term2");
        bondingCurveIds[0] = 1;
        bondingCurveIds[1] = 2;
        amounts[0] = vestingAmount / 2;
        amounts[1] = vestingAmount / 2 + 1;
        minSharesToReceive[0] = 900;
        minSharesToReceive[1] = 1800;

        TrustVestingAndUnlock.BatchDepositData memory batchDepositData = TrustVestingAndUnlock.BatchDepositData({
            receiver: receiver,
            termIds: termIds,
            bondingCurveIds: bondingCurveIds,
            amounts: amounts,
            minSharesToReceive: minSharesToReceive
        });

        vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
        trustVestingAndUnlock.batchDepositIntoMultiVault(batchDepositData);
        vm.stopPrank();
    }

    function test_batchDepositIntoMultiVault() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory minSharesToReceive = new uint256[](2);

        termIds[0] = keccak256("term1");
        termIds[1] = keccak256("term2");
        bondingCurveIds[0] = 1;
        bondingCurveIds[1] = 2;
        amounts[0] = 1000;
        amounts[1] = 2000;
        minSharesToReceive[0] = 900;
        minSharesToReceive[1] = 1800;

        TrustVestingAndUnlock.BatchDepositData memory batchDepositData = TrustVestingAndUnlock.BatchDepositData({
            receiver: receiver,
            termIds: termIds,
            bondingCurveIds: bondingCurveIds,
            amounts: amounts,
            minSharesToReceive: minSharesToReceive
        });

        uint256[] memory shares = trustVestingAndUnlock.batchDepositIntoMultiVault(batchDepositData);

        assertEq(shares.length, 2);
        assertEq(shares[0], amounts[0]);
        assertEq(shares[1], amounts[1]);
        vm.stopPrank();
    }

    function test_redeemFromMultiVault_shouldRevertIfCallerIsNotRecipient() external {
        address receiver = makeAddr("receiver");
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.redeemFromMultiVault(1000, receiver, keccak256("term"), 1, 900);
    }

    function test_redeemFromMultiVault() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        uint256 shares = 1000;
        bytes32 termId = keccak256("term");
        uint256 bondingCurveId = 1;
        uint256 minAssetsToReceive = 900;

        uint256 assets =
            trustVestingAndUnlock.redeemFromMultiVault(shares, receiver, termId, bondingCurveId, minAssetsToReceive);

        assertEq(assets, shares);
        vm.stopPrank();
    }

    function test_batchRedeemFromMultiVault_shouldRevertIfCallerIsNotRecipient() external {
        address receiver = makeAddr("receiver");
        uint256[] memory shares = new uint256[](2);
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory minAssetsToReceive = new uint256[](2);

        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.batchRedeemFromMultiVault(shares, receiver, termIds, bondingCurveIds, minAssetsToReceive);
    }

    function test_batchRedeemFromMultiVault() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        uint256[] memory shares = new uint256[](2);
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory minAssetsToReceive = new uint256[](2);

        shares[0] = 1000;
        shares[1] = 2000;
        termIds[0] = keccak256("term1");
        termIds[1] = keccak256("term2");
        bondingCurveIds[0] = 1;
        bondingCurveIds[1] = 2;
        minAssetsToReceive[0] = 900;
        minAssetsToReceive[1] = 1800;

        uint256[] memory assets = trustVestingAndUnlock.batchRedeemFromMultiVault(
            shares, receiver, termIds, bondingCurveIds, minAssetsToReceive
        );

        assertEq(assets.length, 2);
        assertEq(assets[0], shares[0]);
        assertEq(assets[1], shares[1]);
        vm.stopPrank();
    }

    function test_withdrawNonLockedTokens_shouldRevertIfCallerIsNotRecipient() external {
        address receiver = makeAddr("receiver");
        vm.expectRevert(Errors.Unlock_OnlyRecipient.selector);
        trustVestingAndUnlock.withdrawNonLockedTokens(1000, receiver);
    }

    function test_withdrawNonLockedTokens_shouldRevertIfReceiverIsZeroAddress() external {
        vm.startPrank(recipient);
        vm.expectRevert(Errors.Unlock_ZeroAddress.selector);
        trustVestingAndUnlock.withdrawNonLockedTokens(1000, address(0));
        vm.stopPrank();
    }

    function test_withdrawNonLockedTokens_shouldRevertIfAmountIsZero() external {
        address receiver = makeAddr("receiver");
        vm.startPrank(recipient);
        vm.expectRevert(Errors.Unlock_ZeroAmount.selector);
        trustVestingAndUnlock.withdrawNonLockedTokens(0, receiver);
        vm.stopPrank();
    }

    function test_withdrawNonLockedTokens_shouldRevertIfAmountExceedsUnlockedAmount() external {
        address receiver = makeAddr("receiver");
        vm.warp(vestingCliff + oneMonth);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
        trustVestingAndUnlock.withdrawNonLockedTokens(vestingAmount, receiver);
        vm.stopPrank();
    }

    function test_withdrawNonLockedTokens() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        uint256 extraTokens = 1e18;
        _sendTokensToTrustVestingAndUnlock(extraTokens);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();

        uint256 receiverBalanceBefore = trustToken.balanceOf(receiver);
        uint256 withdrawAmount = extraTokens;

        trustVestingAndUnlock.withdrawNonLockedTokens(withdrawAmount, receiver);

        uint256 receiverBalanceAfter = trustToken.balanceOf(receiver);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + withdrawAmount);
        vm.stopPrank();
    }

    function testFuzz_approveMultiVault(uint256 amount) external {
        amount = bound(amount, 0, type(uint128).max);

        vm.startPrank(recipient);
        trustVestingAndUnlock.approveMultiVault(amount);
        uint256 allowance = IERC20(trustToken).allowance(address(trustVestingAndUnlock), address(multiVault));
        assertEq(allowance, amount);
        vm.stopPrank();
    }

    function testFuzz_depositIntoMultiVault(uint256 value, uint256 minSharesToReceive) external {
        value = bound(value, 1, vestingAmount / 4);
        minSharesToReceive = bound(minSharesToReceive, 0, value);

        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(value);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();
        trustVestingAndUnlock.approveMultiVault(vestingAmount);

        bytes32 termId = keccak256("term");
        uint256 bondingCurveId = 1;

        uint256 shares =
            trustVestingAndUnlock.depositIntoMultiVault(receiver, termId, bondingCurveId, value, minSharesToReceive);

        assertEq(shares, value);
        assertGe(shares, minSharesToReceive);
        vm.stopPrank();
    }

    function testFuzz_redeemFromMultiVault(uint256 shares, uint256 minAssetsToReceive) external {
        shares = bound(shares, 1, type(uint128).max);
        minAssetsToReceive = bound(minAssetsToReceive, 0, shares);

        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();

        bytes32 termId = keccak256("term");
        uint256 bondingCurveId = 1;

        uint256 assets =
            trustVestingAndUnlock.redeemFromMultiVault(shares, receiver, termId, bondingCurveId, minAssetsToReceive);

        assertEq(assets, shares);
        assertGe(assets, minAssetsToReceive);
        vm.stopPrank();
    }

    function testFuzz_withdrawNonLockedTokens(uint256 amount) external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);

        amount = bound(amount, 1, 1e18);
        _sendTokensToTrustVestingAndUnlock(amount);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();

        uint256 receiverBalanceBefore = trustToken.balanceOf(receiver);

        trustVestingAndUnlock.withdrawNonLockedTokens(amount, receiver);

        uint256 receiverBalanceAfter = trustToken.balanceOf(receiver);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amount);
        vm.stopPrank();
    }

    function test_multiVaultIntegration_fullFlow() external {
        address receiver = makeAddr("receiver");
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);

        // Step 1: Claim and approve
        _claimAndApprove(unlockCliffTimestamp);

        // Step 2: Create atoms
        bytes32[] memory atomIds = _createTestAtoms();

        // Step 3: Create triples
        bytes32[] memory tripleIds = _createTestTriples(atomIds);

        // Step 4: Batch deposit
        uint256[] memory shares = _performBatchDeposit(receiver, atomIds, tripleIds);

        // Step 5: Batch redeem
        _performBatchRedeem(receiver, shares, atomIds, tripleIds);

        // Step 6: Withdraw extra tokens
        uint256 extraTokens = 50000;
        trustVestingAndUnlock.withdrawNonLockedTokens(extraTokens, receiver);

        vm.stopPrank();
    }

    function test_requireNonLockedTokens_shouldEnforceUnlockingRules() external {
        uint256 unlockCliffTimestamp = trustVestingAndUnlock.tgeTimestamp() + unlockCliff;
        vm.warp(unlockCliffTimestamp + oneWeek);
        _sendTokensToTrustVestingAndUnlock(1e18);

        vm.startPrank(recipient);
        trustVestingAndUnlock.claim();

        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(block.timestamp);
        uint256 unlockedTokens = trustVestingAndUnlock.unlockedAmount(block.timestamp, vestedTokens);
        uint256 lockedTokens = vestedTokens - unlockedTokens;

        uint256 contractBalance = trustToken.balanceOf(address(trustVestingAndUnlock));
        uint256 maxWithdrawable = contractBalance > lockedTokens ? contractBalance - lockedTokens : 0;

        if (maxWithdrawable > 0) {
            trustVestingAndUnlock.withdrawNonLockedTokens(maxWithdrawable, recipient);
        }

        if (contractBalance > maxWithdrawable) {
            vm.expectRevert(Errors.Unlock_InsufficientUnlockedTokens.selector);
            trustVestingAndUnlock.withdrawNonLockedTokens(maxWithdrawable + 1, recipient);
        }

        vm.stopPrank();
    }

    // Internal helper functions

    function _claimAndApprove(uint256 unlockCliffTimestamp) internal {
        trustVestingAndUnlock.claim();
        uint256 vestedTokens = trustVestingAndUnlock.vestedAmount(unlockCliffTimestamp);
        uint256 claimedAmount = (vestedTokens * unlockCliffPercentage) / BASIS_POINTS_DIVISOR;
        assertEq(trustToken.balanceOf(recipient), claimedAmount);

        trustVestingAndUnlock.approveMultiVault(vestingAmount);
    }

    function _createTestAtoms() internal returns (bytes32[] memory) {
        bytes[] memory atomDataArray = new bytes[](2);
        atomDataArray[0] = "atom1";
        atomDataArray[1] = "atom2";

        bytes32[] memory atomIds = trustVestingAndUnlock.createAtoms(atomDataArray, 1000);
        assertEq(atomIds.length, 2);
        return atomIds;
    }

    function _createTestTriples(bytes32[] memory atomIds) internal returns (bytes32[] memory) {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = atomIds[0];
        predicateIds[0] = keccak256("predicate");
        objectIds[0] = atomIds[1];

        TrustVestingAndUnlock.CreateTriplesData memory tripleData = TrustVestingAndUnlock.CreateTriplesData({
            subjectIds: subjectIds,
            predicateIds: predicateIds,
            objectIds: objectIds,
            value: 2000
        });

        bytes32[] memory tripleIds = trustVestingAndUnlock.createTriples(tripleData);
        assertEq(tripleIds.length, 1);
        return tripleIds;
    }

    function _performBatchDeposit(address receiver, bytes32[] memory atomIds, bytes32[] memory tripleIds)
        internal
        returns (uint256[] memory)
    {
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory minSharesToReceive = new uint256[](2);

        termIds[0] = atomIds[0];
        termIds[1] = tripleIds[0];
        bondingCurveIds[0] = 1;
        bondingCurveIds[1] = 1;
        amounts[0] = 5000;
        amounts[1] = 10000;
        minSharesToReceive[0] = 4500;
        minSharesToReceive[1] = 9000;

        TrustVestingAndUnlock.BatchDepositData memory batchDepositData = TrustVestingAndUnlock.BatchDepositData({
            receiver: receiver,
            termIds: termIds,
            bondingCurveIds: bondingCurveIds,
            amounts: amounts,
            minSharesToReceive: minSharesToReceive
        });

        uint256[] memory shares = trustVestingAndUnlock.batchDepositIntoMultiVault(batchDepositData);
        assertEq(shares.length, 2);
        assertEq(shares[0], amounts[0]);
        assertEq(shares[1], amounts[1]);
        return shares;
    }

    function _performBatchRedeem(
        address receiver,
        uint256[] memory shares,
        bytes32[] memory atomIds,
        bytes32[] memory tripleIds
    ) internal {
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory bondingCurveIds = new uint256[](2);
        uint256[] memory minAssetsToReceive = new uint256[](2);

        termIds[0] = atomIds[0];
        termIds[1] = tripleIds[0];
        bondingCurveIds[0] = 1;
        bondingCurveIds[1] = 1;
        minAssetsToReceive[0] = 4000;
        minAssetsToReceive[1] = 8000;

        uint256[] memory assets = trustVestingAndUnlock.batchRedeemFromMultiVault(
            shares, receiver, termIds, bondingCurveIds, minAssetsToReceive
        );

        assertEq(assets.length, 2);
        assertEq(assets[0], shares[0]);
        assertEq(assets[1], shares[1]);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _sendTokensToTrustVestingAndUnlock(uint256 amount) internal {
        vm.prank(admin);
        trustToken.transfer(address(trustVestingAndUnlock), amount);
    }
}
