// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/Reads.t.sol'

/**
 * @title TrustBonding Reads Test
 * @notice Test suite for all read/view functions in the TrustBonding contract
 * @dev Tests successful cases and error handling edge cases for read-only functions
 */
contract TrustBondingReadsTest is TrustBondingBase {
    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, DEAL_AMOUNT);
        vm.deal(users.bob, DEAL_AMOUNT);
        vm.deal(users.charlie, DEAL_AMOUNT);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

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

    function test_totalLocked_initialState() external view {
        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, 0);
    }

    function test_totalLocked_afterBonding() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, MEDIUM_DEPOSIT_AMOUNT);
    }

    function test_totalLocked_multipleBonds() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        _createLock(users.bob, MEDIUM_DEPOSIT_AMOUNT * 2);

        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, MEDIUM_DEPOSIT_AMOUNT * 3);
    }

    function test_totalBondedBalance_initialState() external view {
        uint256 totalBonded = protocol.trustBonding.totalBondedBalance();
        assertEq(totalBonded, 0);
    }

    function test_totalBondedBalance_afterBonding() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        _createLock(users.bob, MEDIUM_DEPOSIT_AMOUNT);

        uint256 totalBonded = protocol.trustBonding.totalBondedBalance();
        uint256 aliceBalance = protocol.trustBonding.balanceOf(users.alice);
        uint256 bobBalance = protocol.trustBonding.balanceOf(users.bob);

        assertEq(totalBonded, aliceBalance + bobBalance);
        assertGt(totalBonded, 0);
    }

    function test_totalBondedBalanceAtEpochEnd_validEpoch() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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

    function test_userEligibleRewardsForEpoch_validUser() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 prevEpoch = currentEpoch - 1;

        // Claim rewards for previous epoch
        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        bool claimed = protocol.trustBonding.hasClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertEq(claimed, true);
    }

    function test_emissionsForEpoch_shouldRevertForFutureEpoch() external {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 1;

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidEpoch.selector));
        protocol.trustBonding.emissionsForEpoch(futureEpoch);
    }

    function test_emissionsForEpoch_epoch0() external view {
        uint256 emissionsForEpoch = protocol.trustBonding.emissionsForEpoch(0);
        assertGt(emissionsForEpoch, 0);
    }

    function test_emissionsForEpoch_multipleEpochs() external {
        uint256 epoch0Trust = protocol.trustBonding.emissionsForEpoch(0);

        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);
        uint256 epoch1Trust = protocol.trustBonding.emissionsForEpoch(1);

        // Both should be positive
        assertGt(epoch0Trust, 0);
        assertGt(epoch1Trust, 0);
    }

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
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

        // Advance multiple epochs without claiming
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH * 3);

        uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(1);
        // Should have unclaimed rewards from epoch 1 (epoch 2 is still claimable)
        assertGt(unclaimed, 0);
    }

    function test_getUnclaimedRewards_afterPartialClaiming() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        _createLock(users.bob, MEDIUM_DEPOSIT_AMOUNT);

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

    function test_userClaimedRewardsForEpoch_noClaims() external view {
        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0);
        assertEq(claimed, 0);
    }

    function test_userClaimedRewardsForEpoch_afterClaim() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 prevEpoch = protocol.trustBonding.currentEpoch() - 1;

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertGt(claimed, 0);
    }

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
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 prevEpoch = protocol.trustBonding.currentEpoch() - 1;

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimed = protocol.trustBonding.totalClaimedRewardsForEpoch(prevEpoch);
        assertGt(claimed, 0);
    }

    function test_constants() external view {
        assertEq(protocol.trustBonding.YEAR(), 365 days);
        assertEq(protocol.trustBonding.BASIS_POINTS_DIVISOR(), 10_000);
        assertEq(protocol.trustBonding.MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND(), 4000);
        assertEq(protocol.trustBonding.MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND(), 2500);
        assertEq(protocol.trustBonding.PAUSER_ROLE(), keccak256("PAUSER_ROLE"));
    }
}
