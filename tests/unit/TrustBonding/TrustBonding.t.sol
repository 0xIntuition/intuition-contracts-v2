// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { console, Vm } from "forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

contract TrustBondingTest is BaseTest {
    /// @notice Constants
    uint256 public dealAmount = 100 * 1e18;
    uint256 public initialTokens = 10_000 * 1e18;
    uint256 public defaultUnlockDuration = 2 * 365 days; // 2 years
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = 0.75e8 * 1e18; // 7.5% of the initial supply
    address public timelock = address(4);
    uint256 public constant systemUtilizationLowerBound = 5000; // 50%
    uint256 public constant personalUtilizationLowerBound = 3000; // 30%
    uint256 public additionalTokens = 10_000 * 1e18;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.deal(users.alice, additionalTokens * 10);
        vm.deal(users.bob, additionalTokens * 10);
        vm.deal(users.charlie, additionalTokens * 10);

        _setupUserForTrustBonding(users.alice);
        _setupUserForTrustBonding(users.bob);
        _setupUserForTrustBonding(users.charlie);

        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    function _deployNewTrustBondingContract() internal returns (TrustBonding) {
        TrustBonding newTrustBondingImpl = new TrustBonding();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(newTrustBondingImpl), users.admin, "");

        return TrustBonding(address(proxy));
    }

    function test_initialize_verifyInitParams() external {
        assertEq(address(protocol.trustBonding.token()), address(protocol.wrappedTrust));
        assertEq(protocol.trustBonding.epochLength(), TRUST_BONDING_EPOCH_LENGTH);
    }

    function test_initialize_shouldRevertIfAdminIsAddressZero() external {
        resetPrank(users.admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        newTrustBonding.initialize(
            address(0), // admin
            users.timelock, // timelock
            address(protocol.wrappedTrust), // protocol.wrappedTrust
            TRUST_BONDING_EPOCH_LENGTH, // epochLength (minimum 2 weeks required)
            address(protocol.multiVault), // multiVault
            address(protocol.satelliteEmissionsController), // satelliteEmissionsController
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound (50%)
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound (30%)
        );

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfTimelockIsAddressZero() external {
        resetPrank(users.admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        newTrustBonding.initialize(
            users.admin, // admin
            address(0), // timelock
            address(protocol.wrappedTrust), // protocol.wrappedTrust
            TRUST_BONDING_EPOCH_LENGTH, // epochLength (minimum 2 weeks required)
            address(protocol.multiVault), // multiVault
            address(protocol.satelliteEmissionsController), // satelliteEmissionsController
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound (50%)
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound (30%)
        );

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfTrustTokenIsAddressZero() external {
        resetPrank(users.admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        vm.expectRevert("Token address cannot be 0");
        newTrustBonding.initialize(
            users.admin, // admin
            users.timelock, // timelock
            address(0), // protocol.wrappedTrust
            TRUST_BONDING_EPOCH_LENGTH, // epochLength (minimum 2 weeks required)
            address(protocol.multiVault), // multiVault
            address(protocol.satelliteEmissionsController), // satelliteEmissionsController
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound (50%)
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound (30%)
        );

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfEpochLengthIsBelowTwoWeeks() external {
        resetPrank(users.admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        uint256 invalidEpochLength = 2 weeks - 1;

        vm.expectRevert("Min lock time must be at least 2 weeks");
        newTrustBonding.initialize(
            users.admin, // admin
            users.timelock, // timelock
            address(protocol.wrappedTrust), // protocol.wrappedTrust
            invalidEpochLength, // epochLength (minimum 2 weeks required)
            address(protocol.multiVault), // multiVault
            address(protocol.satelliteEmissionsController), // satelliteEmissionsController
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound (50%)
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound (30%)
        );

        vm.stopPrank();
    }

    function test_epochLength() external view {
        assertEq(protocol.trustBonding.epochLength(), TRUST_BONDING_EPOCH_LENGTH);
    }

    function test_epochsPerYear() external view {
        uint256 expectedEpochsPerYear = 365 days / TRUST_BONDING_EPOCH_LENGTH;

        assertEq(protocol.trustBonding.epochsPerYear(), expectedEpochsPerYear);
    }

    function test_epochTimestampEnd() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentEpochEndTimestamp = protocol.trustBonding.epochTimestampEnd(currentEpoch);

        assertEq(currentEpochEndTimestamp, TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH - 20);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH + (TRUST_BONDING_EPOCH_LENGTH / 2));

        // currentEpoch = protocol.trustBonding.currentEpoch();
        // currentEpochEndTimestamp = protocol.trustBonding.epochTimestampEnd(currentEpoch);

        // assertEq(currentEpochEndTimestamp, TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 2);
    }

    function test_epochAtTimestamp() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentTimestamp = block.timestamp;

        assertEq(protocol.trustBonding.epochAtTimestamp(currentTimestamp), currentEpoch);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(TRUST_BONDING_START_TIMESTAMP + 20 days);

        currentEpoch = protocol.trustBonding.currentEpoch();
        currentTimestamp = block.timestamp;

        assertEq(protocol.trustBonding.epochAtTimestamp(currentTimestamp), currentEpoch);
    }

    function test_currentEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        assertEq(currentEpoch, 0);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(TRUST_BONDING_START_TIMESTAMP + 20 days);

        currentEpoch = protocol.trustBonding.currentEpoch();

        assertEq(currentEpoch, 1);
    }

    function test_totalLocked() external {
        uint256 totalLocked = protocol.trustBonding.totalLocked();

        assertEq(totalLocked, 0);

        _bondSomeTokens(users.alice);

        totalLocked = protocol.trustBonding.totalLocked();

        assertEq(totalLocked, initialTokens);
    }

    function test_totalBondedBalance() external {
        _bondSomeTokens(users.alice);
        _bondSomeTokens(users.bob);

        uint256 totalBondedBalance = protocol.trustBonding.totalBondedBalance();

        uint256 aliceVeTrust = protocol.trustBonding.balanceOf(users.alice);
        uint256 bobVeTrust = protocol.trustBonding.balanceOf(users.bob);
        uint256 expectedTotalBondedBalance = aliceVeTrust + bobVeTrust;

        assertEq(totalBondedBalance, expectedTotalBondedBalance);
    }

    function test_totalBondedBalanceAtEpochEnd_shouldRevertIfEpochIsInTheFuture() external {
        resetPrank(users.admin);

        uint256 futureEpoch = protocol.trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.totalBondedBalanceAtEpochEnd(futureEpoch);

        vm.stopPrank();
    }

    function test_totalBondedBalanceAtEpochEnd() external {
        _bondSomeTokens(users.alice);
        _bondSomeTokens(users.bob);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 totalBondedBalanceAtEpochEnd = protocol.trustBonding.totalBondedBalanceAtEpochEnd(currentEpoch);

        uint256 aliceVeTrust = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, currentEpoch);
        uint256 bobVeTrust = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.bob, currentEpoch);
        uint256 expectedTotalBondedBalanceAtEpochEnd = aliceVeTrust + bobVeTrust;

        assertEq(totalBondedBalanceAtEpochEnd, expectedTotalBondedBalanceAtEpochEnd);
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertIfAccountIsZero() external {
        resetPrank(users.admin);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.userBondedBalanceAtEpochEnd(address(0), currentEpoch);

        vm.stopPrank();
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertIfEpochIsInTheFuture() external {
        resetPrank(users.admin);

        uint256 futureEpoch = protocol.trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, futureEpoch);

        vm.stopPrank();
    }

    function test_userBondedBalanceAtEpochEnd() external {
        _bondSomeTokens(users.alice);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 aliceInitialVeTrust = protocol.trustBonding.balanceOf(users.alice);
        uint256 aliceVeTrustAtEpochEnd = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, currentEpoch);

        // veTRUST balances decay linearly over time
        assertLt(aliceVeTrustAtEpochEnd, aliceInitialVeTrust);
    }

    function test_userEligibleRewardsForEpoch_shouldRevertIfAccountIsZero() external {
        resetPrank(users.admin);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.userEligibleRewardsForEpoch(address(0), currentEpoch);

        vm.stopPrank();
    }

    function test_userEligibleRewardsForEpoch_shouldRevertIfEpochIsInTheFuture() external {
        resetPrank(users.admin);

        uint256 futureEpoch = protocol.trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, futureEpoch);

        vm.stopPrank();
    }

    function test_userEligibleRewardsForEpoch_shouldReturnZeroIfTotalLockedIsZero() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 eligibleRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currentEpoch);

        assertEq(eligibleRewards, 0);
    }

    function test_userEligibleRewardsForEpoch() external {
        _bondSomeTokens(users.alice);
        _bondSomeTokens(users.bob);
        _bondSomeTokens(users.charlie);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 trustPerEpoch = protocol.trustBonding.trustPerEpoch(currentEpoch);
        uint256 expectedRewards = trustPerEpoch / 3; // 1/3 of the total rewards for each user

        uint256 eligibleRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currentEpoch);

        assertEq(eligibleRewards, expectedRewards);
    }

    function test_hasClaimedRewardsForEpoch() external {
        _bondSomeTokens(users.alice);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + protocol.trustBonding.epochLength());

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        // Current epoch is still not claimable while it's ongoing
        assertEq(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, currentEpoch), false);

        uint256 previousEpoch = currentEpoch - 1;

        // Alice claims rewards for the previous epoch (`n - 1`)
        assertEq(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, previousEpoch), false);

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, previousEpoch), true);
    }

    function test_getAprAtEpoch_whenTotalLockedIsZero() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentApy = protocol.trustBonding.getSystemApy();

        assertEq(currentApy, 0);
    }

    function test_getAprAtEpoch_whenTotalLockedIsAboveZero() external {
        _bondSomeTokens(users.alice);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentApy = protocol.trustBonding.getSystemApy();

        uint256 trustPerYear = protocol.trustBonding.trustPerEpoch(currentEpoch) * protocol.trustBonding.epochsPerYear();
        uint256 expectedAPR =
            (trustPerYear * protocol.trustBonding.BASIS_POINTS_DIVISOR()) / protocol.trustBonding.totalLocked();

        assertEq(currentApy, expectedAPR);
    }

    function test_claimRewards_shouldRevertIfContractIsPaused() external {
        _bondSomeTokens(users.alice);
        _advanceEpochs(1);

        vm.prank(users.admin);
        protocol.trustBonding.pause();

        resetPrank(users.alice);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.claimRewards(users.alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfRecipientIsAddressZero() external {
        _bondSomeTokens(users.alice);
        _advanceEpochs(1);

        resetPrank(users.alice);

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.claimRewards(address(0));

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfClaimingRewardsDuringFirstEpoch() external {
        _bondSomeTokens(users.alice);

        resetPrank(users.alice);

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_NoClaimingDuringFirstEpoch.selector));
        protocol.trustBonding.claimRewards(users.alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfThereAreNoRewardsToClaim() external {
        _advanceEpochs(1);

        resetPrank(users.alice);

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_NoRewardsToClaim.selector));
        protocol.trustBonding.claimRewards(users.alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfAlreadyClaimedRewardsForEpoch() external {
        _bondSomeTokens(users.alice);
        _advanceEpochs(1);

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        resetPrank(users.alice);

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector));
        protocol.trustBonding.claimRewards(users.alice);

        vm.stopPrank();
    }

    function test_claimRewards_differentScenarios() external {
        _bondSomeTokens(users.alice);
        _advanceEpochs(1);

        // Case 1: Regular rewards claim
        resetPrank(users.alice);

        uint256 aliceInitialBalance = users.alice.balance;
        uint256 expectedRewards =
            protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);

        protocol.trustBonding.claimRewards(users.alice);
        uint256 aliceFinalBalance = users.alice.balance;

        uint256 totalClaimedRewardsForEpoch =
            protocol.trustBonding.totalClaimedRewardsForEpoch(protocol.trustBonding.currentEpoch() - 1);
        uint256 aliceClaimedRewardsForEpoch =
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards);
        assertEq(totalClaimedRewardsForEpoch, expectedRewards);
        assertEq(aliceClaimedRewardsForEpoch, expectedRewards);

        vm.stopPrank();

        // Case 2: Claimed amount for alice goes down if more people bonded in the meantime
        _bondSomeTokens(users.bob);
        _advanceEpochs(1);

        vm.startPrank(users.alice, users.alice);

        aliceInitialBalance = users.alice.balance;
        uint256 rawRewards =
            protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);
        uint256 expectedRewards2 = rawRewards;

        protocol.trustBonding.claimRewards(users.alice);
        aliceFinalBalance = users.alice.balance;

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards2);
        assertLt(expectedRewards2, expectedRewards);

        // Case 3: Claimed amount calculation with utilization ratio
        protocol.trustBonding.increase_amount(additionalTokens);
        _advanceEpochs(1);

        aliceInitialBalance = users.alice.balance;

        // Get raw rewards for epoch 2
        uint256 rawRewards3 =
            protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);

        // Get personal utilization ratio for epoch 2
        uint256 personalUtilizationRatio =
            protocol.trustBonding.getPersonalUtilizationRatio(users.alice, protocol.trustBonding.currentEpoch() - 1);

        // Calculate expected rewards after applying personal utilization ratio
        uint256 expectedRewards3 = rawRewards3 * personalUtilizationRatio / protocol.trustBonding.BASIS_POINTS_DIVISOR();

        // Calculate Alice's share of the total bonded balance for epoch 2
        uint256 aliceBondedBalance =
            protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, protocol.trustBonding.currentEpoch() - 1);
        uint256 totalBondedBalance =
            protocol.trustBonding.totalBondedBalanceAtEpochEnd(protocol.trustBonding.currentEpoch() - 1);
        uint256 aliceShareBasisPoints =
            (aliceBondedBalance * protocol.trustBonding.BASIS_POINTS_DIVISOR()) / totalBondedBalance;

        // Alice's share should have increased (from ~50% to ~66.7%)
        assertGt(aliceShareBasisPoints, 5000); // Alice has more than 50% share

        protocol.trustBonding.claimRewards(users.alice);
        aliceFinalBalance = users.alice.balance;

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards3);

        // The actual rewards will be less than raw rewards due to utilization ratio
        assertLt(expectedRewards3, rawRewards3);

        vm.stopPrank();

        // Case 4: Claimed amount goes down if no more tokens are added to the existing bond
        _testCase4();

        // Case 5: Verify that the claimed rewards tracking is accurate with multiple claims from different users
        _testCase5();
    }

    // Helper function for Case 4
    function _testCase4() internal {
        _advanceEpochs(1);

        vm.startPrank(users.alice, users.alice);

        uint256 aliceInitialBalance = users.alice.balance;
        uint256 rawRewards =
            protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);
        uint256 expectedRewards4 =
            rawRewards * personalUtilizationLowerBound / protocol.trustBonding.BASIS_POINTS_DIVISOR();

        protocol.trustBonding.claimRewards(users.alice);
        uint256 aliceFinalBalance = users.alice.balance;

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards4);

        // Store for comparison in case 5
        _setUserClaimedRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1, expectedRewards4);

        vm.stopPrank();
    }

    // Helper function for Case 5
    function _testCase5() internal {
        vm.startPrank(users.bob, users.bob);

        uint256 bobInitialBalance = users.bob.balance;
        uint256 bobRawRewards =
            protocol.trustBonding.userEligibleRewardsForEpoch(users.bob, protocol.trustBonding.currentEpoch() - 1);
        uint256 bobExpectedRewards =
            bobRawRewards * personalUtilizationLowerBound / protocol.trustBonding.BASIS_POINTS_DIVISOR();

        protocol.trustBonding.claimRewards(users.bob);

        uint256 totalClaimedRewardsForEpoch =
            protocol.trustBonding.totalClaimedRewardsForEpoch(protocol.trustBonding.currentEpoch() - 1);
        uint256 bobClaimedRewardsForEpoch =
            protocol.trustBonding.userClaimedRewardsForEpoch(users.bob, protocol.trustBonding.currentEpoch() - 1);
        uint256 aliceClaimedRewardsForEpoch =
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, protocol.trustBonding.currentEpoch() - 1);

        assertEq(users.bob.balance, bobInitialBalance + bobExpectedRewards);

        // For epoch 3 (currentEpoch() - 1), only Alice and Bob claimed
        assertEq(totalClaimedRewardsForEpoch, aliceClaimedRewardsForEpoch + bobExpectedRewards);
        assertEq(bobClaimedRewardsForEpoch, bobExpectedRewards);

        vm.stopPrank();
    }

    function test_increase_unlock_time_and_withdraw() external {
        // 1. Lock some tokens
        vm.startPrank(users.alice, users.alice);
        uint256 aliceBalanceBefore = protocol.wrappedTrust.balanceOf(users.alice);
        protocol.trustBonding.create_lock(initialTokens, block.timestamp + defaultUnlockDuration);

        (int128 rawLockedAmount, uint256 lockEndTimestamp) = protocol.trustBonding.locked(users.alice);
        uint256 lockedAmount = uint256(uint128(rawLockedAmount));
        // unlock time is rounded down to the number of whole weeks
        uint256 expectedLockEndTimestamp = ((block.timestamp + defaultUnlockDuration) / 1 weeks) * 1 weeks;

        assertEq(lockedAmount, initialTokens);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);

        // 2. Increase the unlock time after some time passes
        vm.warp(block.timestamp + 30 days);
        protocol.trustBonding.increase_unlock_time(expectedLockEndTimestamp + 30 days);

        (rawLockedAmount, lockEndTimestamp) = protocol.trustBonding.locked(users.alice);
        expectedLockEndTimestamp = ((expectedLockEndTimestamp + 30 days) / 1 weeks) * 1 weeks;

        assertEq(lockEndTimestamp, expectedLockEndTimestamp);

        // 3. Once the lock fully expires, withdraw the bonded tokens
        vm.warp(expectedLockEndTimestamp + 1);
        protocol.trustBonding.withdraw();

        (rawLockedAmount, lockEndTimestamp) = protocol.trustBonding.locked(users.alice);
        lockedAmount = uint256(uint128(rawLockedAmount));

        assertEq(lockedAmount, 0);
        assertEq(lockEndTimestamp, 0);

        // Now alice has all of her tokens back
        assertEq(protocol.wrappedTrust.balanceOf(users.alice), aliceBalanceBefore);
        vm.stopPrank();
    }

    function test_pause_shouldRevertIfCalledByNonOwner() external {
        resetPrank(users.alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.alice,
                protocol.trustBonding.PAUSER_ROLE()
            )
        );
        protocol.trustBonding.pause();

        vm.stopPrank();
    }

    function test_pause_shouldRevertIfAlreadyPaused() external {
        resetPrank(users.admin);

        protocol.trustBonding.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.pause();

        vm.stopPrank();
    }

    function test_pause() external {
        resetPrank(users.admin);

        protocol.trustBonding.pause();

        assertEq(protocol.trustBonding.paused(), true);

        vm.stopPrank();
    }

    function test_unpause_shouldRevertIfCalledByNonOwner() external {
        resetPrank(users.admin);

        protocol.trustBonding.pause();

        vm.stopPrank();

        resetPrank(users.alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.alice,
                protocol.trustBonding.DEFAULT_ADMIN_ROLE()
            )
        );
        protocol.trustBonding.unpause();

        vm.stopPrank();
    }

    function test_unpause_shouldRevertIfAlreadyUnpaused() external {
        resetPrank(users.admin);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector));
        protocol.trustBonding.unpause();

        vm.stopPrank();
    }

    function test_unpause() external {
        resetPrank(users.admin);

        protocol.trustBonding.pause();
        protocol.trustBonding.unpause();

        assertEq(protocol.trustBonding.paused(), false);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to bond some tokens for a given user
    function _bondSomeTokens(address user) internal {
        vm.startPrank(user, user);
        uint256 unlockTime = block.timestamp + defaultUnlockDuration;
        protocol.trustBonding.create_lock(initialTokens, unlockTime);
        vm.stopPrank();
    }

    /// @dev Internal function to advance the epoch by a given number of epochs
    function _advanceEpochs(uint256 epochs) internal {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentEpochEndTimestamp = protocol.trustBonding.epochTimestampEnd(currentEpoch);
        uint256 targetTimestamp = currentEpochEndTimestamp + epochs * protocol.trustBonding.epochLength();
        vm.warp(targetTimestamp - 1);
    }

    function _setTotalClaimedRewardsForEpoch(uint256 epoch, uint256 claimedRewards) internal {
        // Compute the slot
        bytes32 slot = keccak256(abi.encode(epoch, uint256(13))); // 13 = storage slot of totalClaimedRewardsForEpoch
            // mapping

        vm.store(address(protocol.trustBonding), slot, bytes32(uint256(claimedRewards)));
    }

    function _setUserClaimedRewardsForEpoch(address user, uint256 epoch, uint256 claimedRewards) internal {
        // Compute the outer slot
        bytes32 outerSlot = keccak256(abi.encode(user, uint256(14))); // 14 = storage slot ofuserClaimedRewardsForEpoch
            // mapping

        // Compute the final slot
        bytes32 finalSlot = keccak256(abi.encode(epoch, outerSlot));

        vm.store(address(protocol.trustBonding), finalSlot, bytes32(uint256(claimedRewards)));
    }

    function _setupUserForTrustBonding(address user) internal {
        resetPrank({ msgSender: user });

        // Give plenty of balance so initial + additional locks always succeed
        protocol.wrappedTrust.deposit{ value: additionalTokens * 10 }();

        // Approve once for all TrustBonding tests
        protocol.wrappedTrust.approve(address(protocol.trustBonding), type(uint256).max);
    }
}
