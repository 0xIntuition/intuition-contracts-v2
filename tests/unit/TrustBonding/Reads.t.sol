// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/Reads.t.sol'

/**
 * @title TrustBonding Reads Test
 * @notice Test suite for all read/view functions in the TrustBonding contract
 * @dev Tests successful cases and error handling edge cases for read-only functions
 */
contract TrustBondingReadsTest is TrustBondingBase {
    /// @notice Constants for testing
    uint256 public constant DEAL_AMOUNT = 100 * 1e18;
    uint256 public constant INITIAL_TOKENS = 10 * 1e18;
    uint256 public constant DEFAULT_UNLOCK_DURATION = 2 * 365 days;
    uint256 public constant ADDITIONAL_TOKENS = 10_000 * 1e18;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.deal(users.alice, ADDITIONAL_TOKENS * 10);
        vm.deal(users.bob, ADDITIONAL_TOKENS * 10);
        vm.deal(users.charlie, ADDITIONAL_TOKENS * 10);

        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);

        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /* =================================================== */
    /*                   EPOCH FUNCTIONS                   */
    /* =================================================== */

    function test_epochLength() external view {
        uint256 epochLen = protocol.trustBonding.epochLength();
        assertEq(epochLen, TRUST_BONDING_EPOCH_LENGTH);
    }

    function test_epochsPerYear() external view {
        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 expected = 365 days / TRUST_BONDING_EPOCH_LENGTH;
        assertEq(epochsPerYear, expected);
    }

    function test_epochTimestampEnd_currentEpoch() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 endTimestamp = protocol.trustBonding.epochTimestampEnd(currentEpoch);

        uint256 expected = TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH - 20;
        assertEq(endTimestamp, expected);
    }

    function test_epochTimestampEnd_futureEpoch() external {
        // Advance to epoch 1
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH + 1);

        uint256 epoch1 = protocol.trustBonding.currentEpoch();
        assertEq(epoch1, 1);

        uint256 endTimestamp = protocol.trustBonding.epochTimestampEnd(epoch1);
        uint256 expected = TRUST_BONDING_START_TIMESTAMP + (TRUST_BONDING_EPOCH_LENGTH * 2) - 20;
        assertEq(endTimestamp, expected);
    }

    function test_epochAtTimestamp_currentTime() external view {
        uint256 currentTimestamp = block.timestamp;
        uint256 epoch = protocol.trustBonding.epochAtTimestamp(currentTimestamp);
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        assertEq(epoch, currentEpoch);
    }

    function test_epochAtTimestamp_futureTime() external {
        uint256 futureTime = TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH + 1;
        uint256 epoch = protocol.trustBonding.epochAtTimestamp(futureTime);
        assertEq(epoch, 1);
    }

    function test_epochAtTimestamp_pastTime() external {
        uint256 pastTime = TRUST_BONDING_START_TIMESTAMP - 1;
        uint256 epoch = protocol.trustBonding.epochAtTimestamp(pastTime);
        assertEq(epoch, 0); // Should be epoch 0 before start
    }

    function test_currentEpoch_initialState() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_currentEpoch_afterTimeAdvance() external {
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        assertEq(currentEpoch, 1);
    }

    function test_previousEpoch_epoch0() external view {
        uint256 prevEpoch = protocol.trustBonding.previousEpoch();
        assertEq(prevEpoch, 0); // Previous epoch is 0 when current is 0
    }

    function test_previousEpoch_epoch1() external {
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);
        uint256 prevEpoch = protocol.trustBonding.previousEpoch();
        assertEq(prevEpoch, 0); // Previous epoch is 0 when current is 1
    }

    function test_previousEpoch_epoch2() external {
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 2);
        uint256 prevEpoch = protocol.trustBonding.previousEpoch();
        assertEq(prevEpoch, 1); // Previous epoch is 1 when current is 2
    }

    /* =================================================== */
    /*                  BALANCE FUNCTIONS                  */
    /* =================================================== */

    function test_totalLocked_initialState() external view {
        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, 0);
    }

    function test_totalLocked_afterBonding() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, INITIAL_TOKENS);
    }

    function test_totalLocked_multipleBonds() external {
        _createLock(users.alice, INITIAL_TOKENS);
        _createLock(users.bob, INITIAL_TOKENS * 2);

        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, INITIAL_TOKENS * 3);
    }

    function test_totalBondedBalance_initialState() external view {
        uint256 totalBonded = protocol.trustBonding.totalBondedBalance();
        assertEq(totalBonded, 0);
    }

    function test_totalBondedBalance_afterBonding() external {
        _createLock(users.alice, INITIAL_TOKENS);
        _createLock(users.bob, INITIAL_TOKENS);

        uint256 totalBonded = protocol.trustBonding.totalBondedBalance();
        uint256 aliceBalance = protocol.trustBonding.balanceOf(users.alice);
        uint256 bobBalance = protocol.trustBonding.balanceOf(users.bob);

        assertEq(totalBonded, aliceBalance + bobBalance);
        assertGt(totalBonded, 0);
    }

    function test_totalBondedBalanceAtEpochEnd_validEpoch() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 totalBondedAtEnd = protocol.trustBonding.totalBondedBalanceAtEpochEnd(currentEpoch);

        assertGt(totalBondedAtEnd, 0);
    }

    function test_totalBondedBalanceAtEpochEnd_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.totalBondedBalanceAtEpochEnd(futureEpoch);
    }

    function test_userBondedBalanceAtEpochEnd_validUser() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 userBalance = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, currentEpoch);

        assertGt(userBalance, 0);
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertForZeroAddress() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.userBondedBalanceAtEpochEnd(address(0), currentEpoch);
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, futureEpoch);
    }

    function test_userBondedBalanceAtEpochEnd_noBond() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 userBalance = protocol.trustBonding.userBondedBalanceAtEpochEnd(users.alice, currentEpoch);

        assertEq(userBalance, 0);
    }

    /* =================================================== */
    /*                  REWARDS FUNCTIONS                  */
    /* =================================================== */

    function test_eligibleRewards_noBond() external view {
        uint256 rewards = protocol.trustBonding.eligibleRewards(users.alice);
        assertEq(rewards, 0);
    }

    function test_eligibleRewards_withBond() external {
        _createLock(users.alice, INITIAL_TOKENS);

        // Move to next epoch so previous epoch rewards become eligible
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 rewards = protocol.trustBonding.eligibleRewards(users.alice);
        // Should have some rewards from epoch 0
        assertGt(rewards, 0);
    }

    function test_eligibleRewards_epoch0() external {
        _createLock(users.alice, INITIAL_TOKENS);

        // Stay in epoch 0
        uint256 rewards = protocol.trustBonding.eligibleRewards(users.alice);
        // No rewards in epoch 0 (previous epoch would be -1 or 0)
        assertEq(rewards, 0);
    }

    function test_userEligibleRewardsForEpoch_validUser() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 rewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currentEpoch);

        assertGt(rewards, 0);
    }

    function test_userEligibleRewardsForEpoch_shouldRevertForZeroAddress() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.userEligibleRewardsForEpoch(address(0), currentEpoch);
    }

    function test_userEligibleRewardsForEpoch_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, futureEpoch);
    }

    function test_userEligibleRewardsForEpoch_noBalance() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 rewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currentEpoch);

        assertEq(rewards, 0);
    }

    function test_hasClaimedRewardsForEpoch_notClaimed() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        bool claimed = protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, currentEpoch);

        assertEq(claimed, false);
    }

    function test_hasClaimedRewardsForEpoch_afterClaim() external {
        _createLock(users.alice, INITIAL_TOKENS);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 prevEpoch = currentEpoch - 1;

        // Claim rewards for previous epoch
        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        bool claimed = protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertEq(claimed, true);
    }

    function test_trustPerEpoch_epoch0() external view {
        uint256 trustPerEpoch = protocol.trustBonding.trustPerEpoch(0);
        assertGt(trustPerEpoch, 0);
    }

    function test_trustPerEpoch_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.trustPerEpoch(futureEpoch);
    }

    function test_trustPerEpoch_multipleEpochs() external {
        uint256 epoch0Trust = protocol.trustBonding.trustPerEpoch(0);

        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);
        uint256 epoch1Trust = protocol.trustBonding.trustPerEpoch(1);

        // Both should be positive
        assertGt(epoch0Trust, 0);
        assertGt(epoch1Trust, 0);
    }

    /* =================================================== */
    /*                 UTILIZATION FUNCTIONS               */
    /* =================================================== */

    function test_getSystemUtilizationRatio_epoch0and1() external {
        uint256 ratio0 = protocol.trustBonding.getSystemUtilizationRatio(0);
        _advanceToEpoch(1);
        uint256 ratio1 = protocol.trustBonding.getSystemUtilizationRatio(1);

        // Epochs 0 and 1 should return maximum (BASIS_POINTS_DIVISOR)
        assertEq(ratio0, protocol.trustBonding.BASIS_POINTS_DIVISOR());
        assertEq(ratio1, protocol.trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getSystemUtilizationRatio_epoch2() external {
        _advanceToEpoch(2);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        // Should be at least the lower bound
        assertGe(ratio, protocol.trustBonding.systemUtilizationLowerBound());
        assertLe(ratio, protocol.trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getSystemUtilizationRatio_futureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(futureEpoch);
        assertEq(ratio, 0); // Future epochs return 0
    }

    function test_getPersonalUtilizationRatio_epoch0and1() external {
        uint256 ratio0 = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 0);
        _advanceToEpoch(1);
        uint256 ratio1 = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 1);

        // Epochs 0 and 1 should return maximum (BASIS_POINTS_DIVISOR)
        assertEq(ratio0, protocol.trustBonding.BASIS_POINTS_DIVISOR());
        assertEq(ratio1, protocol.trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getPersonalUtilizationRatio_shouldRevertForZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));
        protocol.trustBonding.getPersonalUtilizationRatio(address(0), 2);
    }

    function test_getPersonalUtilizationRatio_epoch2() external {
        // Advance to epoch 2
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 2);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        // Should be at least the lower bound
        assertGe(ratio, protocol.trustBonding.personalUtilizationLowerBound());
        assertLe(ratio, protocol.trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getPersonalUtilizationRatio_futureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, futureEpoch);
        assertEq(ratio, 0); // Future epochs return 0
    }

    /* =================================================== */
    /*                    APR FUNCTIONS                    */
    /* =================================================== */

    function test_getAprAtEpoch_noLocked() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 apr = protocol.trustBonding.getAprAtEpoch(currentEpoch);

        assertEq(apr, 0); // No APR when no tokens locked
    }

    function test_getAprAtEpoch_withLocked() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 apr = protocol.trustBonding.getAprAtEpoch(currentEpoch);

        assertGt(apr, 0); // Should have positive APR
    }

    function test_getAprAtEpoch_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.getAprAtEpoch(futureEpoch);
    }

    function test_getAprAtEpoch_calculation() external {
        _createLock(users.alice, INITIAL_TOKENS);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 apr = protocol.trustBonding.getAprAtEpoch(currentEpoch);

        // Calculate expected APR
        uint256 trustPerEpoch = protocol.trustBonding.trustPerEpoch(currentEpoch);
        uint256 trustPerYear = trustPerEpoch * protocol.trustBonding.epochsPerYear();
        uint256 totalLocked = protocol.trustBonding.totalLocked();
        uint256 expectedApr = trustPerYear * protocol.trustBonding.BASIS_POINTS_DIVISOR() / totalLocked;

        assertEq(apr, expectedApr);
    }

    /* =================================================== */
    /*                 UNCLAIMED REWARDS                   */
    /* =================================================== */

    function test_getUnclaimedRewards_epoch0() external view {
        uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimed, 0); // No unclaimed rewards in epoch 0
    }

    function test_getUnclaimedRewards_epoch1() external {
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(1);
        assertEq(unclaimed, 0); // No unclaimed rewards in epoch 1
    }

    function test_getUnclaimedRewards_withUnclaimedFromPastEpochs() external {
        _createLock(users.alice, INITIAL_TOKENS);

        // Advance multiple epochs without claiming
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 3);

        uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(1);
        // Should have unclaimed rewards from epoch 1 (epoch 2 is still claimable)
        assertGt(unclaimed, 0);
    }

    function test_getUnclaimedRewards_afterPartialClaiming() external {
        _createLock(users.alice, INITIAL_TOKENS);
        _createLock(users.bob, INITIAL_TOKENS);

        // Move to epoch 2
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 2);

        // Alice claims rewards from epoch 1
        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Move to epoch 3
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 3);

        uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(1);
        // Should have Bob's unclaimed rewards from epoch 1
        assertGt(unclaimed, 0);
    }

    /* =================================================== */
    /*                 STORAGE ACCESSORS                   */
    /* =================================================== */

    function test_multiVault() external view {
        address multiVault = protocol.trustBonding.multiVault();
        assertEq(multiVault, address(protocol.multiVault));
    }

    function test_satelliteEmissionsController() external view {
        address controller = protocol.trustBonding.satelliteEmissionsController();
        assertEq(controller, address(protocol.satelliteEmissionsController));
    }

    function test_systemUtilizationLowerBound() external view {
        uint256 bound = protocol.trustBonding.systemUtilizationLowerBound();
        assertEq(bound, TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND);
    }

    function test_personalUtilizationLowerBound() external view {
        uint256 bound = protocol.trustBonding.personalUtilizationLowerBound();
        assertEq(bound, TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND);
    }

    function test_totalClaimedRewardsForEpoch_noClaims() external view {
        uint256 claimed = protocol.trustBonding.totalClaimedRewardsForEpoch(0);
        assertEq(claimed, 0);
    }

    function test_totalClaimedRewardsForEpoch_afterClaim() external {
        _createLock(users.alice, INITIAL_TOKENS);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 prevEpoch = protocol.trustBonding.currentEpoch() - 1;

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimed = protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch);
        assertGt(claimed, 0);
    }

    function test_userClaimedRewardsForEpoch_noClaims() external view {
        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0);
        assertEq(claimed, 0);
    }

    function test_userClaimedRewardsForEpoch_afterClaim() external {
        _createLock(users.alice, INITIAL_TOKENS);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 prevEpoch = protocol.trustBonding.currentEpoch() - 1;

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertGt(claimed, 0);
    }

    function test_maxClaimableProtocolFeesForEpoch() external view {
        uint256 fees = protocol.trustBonding.maxClaimableProtocolFeesForEpoch(0);
        assertEq(fees, 0); // Should be 0 by default
    }

    /* =================================================== */
    /*                   CONSTANTS                         */
    /* =================================================== */

    function test_constants() external view {
        assertEq(protocol.trustBonding.YEAR(), 365 days);
        assertEq(protocol.trustBonding.BASIS_POINTS_DIVISOR(), 10_000);
        assertEq(protocol.trustBonding.MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND(), 4000);
        assertEq(protocol.trustBonding.MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND(), 2500);
        assertEq(protocol.trustBonding.PAUSER_ROLE(), keccak256("PAUSER_ROLE"));
        assertEq(protocol.trustBonding.TIMELOCK_ROLE(), keccak256("TIMELOCK_ROLE"));
    }
}
