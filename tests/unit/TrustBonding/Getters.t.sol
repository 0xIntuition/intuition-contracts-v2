// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/Getters.t.sol'
contract TrustBondingGettersTest is TrustBondingBase {
    /// @notice Constants for testing
    uint256 public constant DEAL_AMOUNT = 100 * 1e18;
    uint256 public constant STAKE_AMOUNT = 10 * 1e18;
    uint256 public constant LARGE_STAKE_AMOUNT = 10_000 * 1e18;
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
    /*            getUserCurrentClaimableRewards          */
    /* =================================================== */

    function test_getUserCurrentClaimableRewards_noStakingHistory() external view {
        // User with no staking history should have 0 claimable rewards
        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(claimableRewards, 0, "User with no staking history should have 0 claimable rewards");
    }

    function test_getUserCurrentClaimableRewards_firstEpoch() external {
        _createLock(users.alice, STAKE_AMOUNT);

        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(claimableRewards, 0, "No rewards should be claimable in first epoch");
    }

    function test_getUserCurrentClaimableRewards_singleStakePeriod() external {
        _createLock(users.alice, STAKE_AMOUNT);
        _advanceToEpoch(1);

        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(
            claimableRewards,
            EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH,
            "User should have claimable rewards after staking period"
        );
    }

    function test_getUserCurrentClaimableRewards_alreadyClaimed() external {
        // Setup: Alice stakes in epoch 0
        _createLock(users.alice, STAKE_AMOUNT);
        _advanceToEpoch(2);

        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(110 * 1e18));

        // Simulate Alice claiming rewards for epoch 1
        uint256 expectedRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        _setUserClaimedRewardsForEpoch(users.alice, 1, expectedRewards);

        uint256 claimableRewardsAfterClaim = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(claimableRewardsAfterClaim, 0, "No rewards should be claimable after already claiming");
    }

    function test_getUserCurrentClaimableRewards_multipleStakePeriods() external {
        _createLock(users.alice, STAKE_AMOUNT);
        _advanceToEpoch(2);

        // Mock utilization data across multiple epochs
        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1200 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(200 * 1e18));

        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertGt(claimableRewards, 0, "User should have rewards from stake periods");
    }

    /* =================================================== */
    /*                    getUserApy                       */
    /* =================================================== */

    function test_getUserApy_noStakingHistory() external view {
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);
        assertEq(currentApy, 0, "Current APY should be 0 for user with no staking history");
        assertEq(maxApy, 0, "Max APY should be 0 for user with no staking history");
    }

    function test_getUserApy_firstEpoch() external {
        _createLock(users.alice, STAKE_AMOUNT);

        (uint256 estimatedCurrentApy, uint256 estimatedMaxApy) = _estimatedApy(0);
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);
        assertEq(currentApy, estimatedCurrentApy, "Current APY should be positive");
        assertEq(maxApy, estimatedMaxApy, "Max APY should be positive");
        assertEq(currentApy, maxApy, "Current APY should equal Max APY");
    }

    function test_getUserApy_lowerBoundUtilization() external {
        _createLock(users.alice, STAKE_AMOUNT);

        // Advance to epoch 3 to skip past maximum personal/system utilization calculation
        uint256 EPOCHS_TO_ADVANCE = 3;
        _advanceToEpoch(EPOCHS_TO_ADVANCE);

        (uint256 estimatedCurrentApy, uint256 estimatedMaxApy) = _estimatedApy(EPOCHS_TO_ADVANCE);
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);
        assertEq(currentApy, estimatedCurrentApy, "Current APY should be positive");
        assertEq(maxApy, estimatedMaxApy, "Max APY should be positive");
        assertLt(currentApy, maxApy, "Current APY should equal Max APY");
    }

    function test_getUserApy_perfectUtilization() external {
        _createLock(users.alice, STAKE_AMOUNT);

        // Advance to epoch 3 to skip past maximum personal/system utilization calculation
        uint256 EPOCHS_TO_ADVANCE = 3;
        _advanceToEpoch(EPOCHS_TO_ADVANCE);
        // Mock perfect utilization (100% personal utilization)
        uint256 targetUtilization = 100 * 1e18;
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE - 1, int256(1000 * 1e18));
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE, int256(1000 * 1e18 + int256(targetUtilization)));

        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, int256(100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE, int256(100 * 1e18 + int256(targetUtilization)));

        _setTotalClaimedRewardsForEpoch(EPOCHS_TO_ADVANCE - 1, targetUtilization);
        _setTotalClaimedRewardsForEpoch(EPOCHS_TO_ADVANCE, targetUtilization);

        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, targetUtilization);
        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE, targetUtilization);

        (uint256 estimatedCurrentApy, uint256 estimatedMaxApy) = _estimatedApy(EPOCHS_TO_ADVANCE);
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertEq(currentApy, estimatedCurrentApy, "Current APY should be positive");
        assertEq(maxApy, estimatedMaxApy, "Max APY should be positive");
        assertEq(currentApy, maxApy, "Current APY should equal Max APY");
    }

    function _estimatedApy(uint256 epoch)
        internal
        view
        returns (uint256 estimatedCurrentApy, uint256 estimatedMaxApy)
    {
        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 userRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, epoch);
        uint256 personalUtilization = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, epoch);

        // Calculate the expected APY values manually
        estimatedCurrentApy = (epochsPerYear * userRewards * personalUtilization) / STAKE_AMOUNT;
        estimatedMaxApy = (epochsPerYear * userRewards * BASIS_POINTS_DIVISOR) / STAKE_AMOUNT;
    }

    /* =================================================== */
    /*                   getSystemApy                      */
    /* =================================================== */

    function test_getSystemApy_noLocked() external view {
        (uint256 systemApy, uint256 maximumApy) = protocol.trustBonding.getSystemApy();
        assertEq(systemApy, 0, "System APY should be 0 when no tokens are locked");
    }

    function test_getSystemApy_withLocked() external {
        // Setup: Alice stakes tokens
        _createLock(users.alice, STAKE_AMOUNT);

        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 emissions = protocol.trustBonding.emissionsForEpoch(0);
        uint256 emissionsPerYear = emissions * epochsPerYear;
        uint256 estimatedSystemApy = (emissionsPerYear * BASIS_POINTS_DIVISOR) / STAKE_AMOUNT;
        console.log("Estimated System APY:", estimatedSystemApy);

        (uint256 systemApy, uint256 maximumApy) = protocol.trustBonding.getSystemApy();
        assertEq(systemApy, estimatedSystemApy, "System APY should be greater than 0 when tokens are locked");
    }

    function test_getSystemApy_multipleUsers() external {
        // Setup: Multiple users stake
        _createLock(users.alice, STAKE_AMOUNT);
        _createLock(users.bob, STAKE_AMOUNT);
        _createLock(users.charlie, STAKE_AMOUNT);

        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 emissions = protocol.trustBonding.emissionsForEpoch(0);
        uint256 emissionsPerYear = emissions * epochsPerYear;
        uint256 estimatedSystemApy = (emissionsPerYear * BASIS_POINTS_DIVISOR) / (STAKE_AMOUNT * 3);
        (uint256 systemApy, uint256 maximumApy) = protocol.trustBonding.getSystemApy();
        console.log("Estimated System APY:", estimatedSystemApy);
        console.log("System APY:", systemApy);

        assertEq(systemApy, estimatedSystemApy, "System APY should be positive with multiple users");

        // System APY should decrease as more tokens are locked (same emissions, more locked)
        uint256 totalLocked = protocol.trustBonding.totalLocked();
        assertEq(totalLocked, STAKE_AMOUNT * 3, "Total locked should equal sum of all stakes");
    }

    function test_getSystemApy_increaseStake() external {
        // Setup: Alice stakes initial amount
        _createLock(users.alice, STAKE_AMOUNT);
        (uint256 initialSystemApy, uint256 maximumApy) = protocol.trustBonding.getSystemApy();

        // Bob also stakes, effectively increasing total locked
        _createLock(users.bob, STAKE_AMOUNT);

        (uint256 newSystemApy, uint256 newMaximumApy) = protocol.trustBonding.getSystemApy();

        // System APY should decrease as more tokens are locked
        assertLt(newSystemApy, initialSystemApy, "System APY should decrease when more tokens are locked");
    }

    /* =================================================== */
    /*                    getUserInfo                      */
    /* =================================================== */

    function test_getUserInfo_noStakingHistory() external view {
        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertEq(userInfo.personalUtilization, 0, "Personal utilization should be 0 for new user");
        assertEq(userInfo.eligibleRewards, 0, "Eligible rewards should be 0 for new user");
        assertEq(userInfo.maxRewards, 0, "Max rewards should be 0 for new user");
        assertEq(userInfo.lockedAmount, 0, "Locked amount should be 0 for new user");
        assertEq(userInfo.lockEnd, 0, "Lock end should be 0 for new user");
        assertEq(userInfo.bondedBalance, 0, "Bonded balance should be 0 for new user");
    }

    function test_getUserInfo_firstEpoch() external {
        _createLock(users.alice, STAKE_AMOUNT);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertEq(userInfo.personalUtilization, 0, "Personal utilization should be 0 in first epoch");
        assertEq(userInfo.eligibleRewards, 0, "Eligible rewards should be 0 in first epoch");
        assertEq(userInfo.maxRewards, 0, "Max rewards should be 0 in first epoch");
        assertEq(userInfo.lockedAmount, STAKE_AMOUNT, "Locked amount should equal staked amount");
        assertGt(userInfo.lockEnd, block.timestamp, "Lock end should be in the future");
        assertGt(userInfo.bondedBalance, 0, "Bonded balance should be greater than 0");
    }

    function test_getUserInfo_withStaking() external {
        // Setup: Alice stakes
        _createLock(users.alice, STAKE_AMOUNT);
        _advanceToEpoch(3);
        _setTotalUtilizationForEpoch(1, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, 1000 * 1e18);
        _setTotalUtilizationForEpoch(2, int256(1100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 2, 0);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);
        assertEq(
            userInfo.personalUtilization,
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND,
            "Personal utilization should hit MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND"
        );
        assertEq(
            userInfo.eligibleRewards,
            (EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH * userInfo.personalUtilization / BASIS_POINTS_DIVISOR),
            "Eligible rewards should be <= max rewards"
        );
        assertEq(
            userInfo.maxRewards,
            EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH,
            "Users max rewards should equal emissions per epoch with full utilization"
        );
        assertEq(userInfo.lockedAmount, STAKE_AMOUNT, "Locked amount should equal staked amount");
    }

    function test_getUserInfo_perfectUtilization() external {
        _createLock(users.alice, STAKE_AMOUNT);

        uint256 EPOCHS_TO_ADVANCE = 3;
        _advanceToEpoch(EPOCHS_TO_ADVANCE);

        uint256 targetUtilization = 100 * 1e18;
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE - 2, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE - 1, int256(100 * 1e18 + int256(targetUtilization)));

        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE - 2, int256(100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, int256(100 * 1e18 + int256(targetUtilization)));

        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE - 2, targetUtilization);
        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, targetUtilization);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);
        assertEq(userInfo.personalUtilization, BASIS_POINTS_DIVISOR, "Personal utilization should be 100%");
        assertEq(
            userInfo.eligibleRewards, userInfo.maxRewards, "Eligible should equal max rewards with perfect utilization"
        );
    }

    function test_getUserInfo_multipleLocks() external {
        // Setup: Alice creates initial lock
        _createLock(users.alice, STAKE_AMOUNT);

        // Advance to epoch 1
        _advanceToEpoch(1);

        // Advance to epoch 2
        _advanceToEpoch(2);

        // Mock utilization data
        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1200 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(200 * 1e18));

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertEq(userInfo.lockedAmount, STAKE_AMOUNT, "Locked amount should reflect stake");
        assertGt(userInfo.maxRewards, 0, "Max rewards should be positive with locks");
        assertGt(userInfo.bondedBalance, 0, "Bonded balance should be positive");
    }

    /* =================================================== */
    /*              getUserRewardsForEpoch                 */
    /* =================================================== */

    function test_getUserRewardsForEpoch_firstEpoch() external {
        _createLock(users.alice, STAKE_AMOUNT);

        (uint256 eligible, uint256 available) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 0);
        assertEq(eligible, 0, "No eligible rewards in first epoch");
        assertEq(available, 0, "No available rewards in first epoch");
    }

    function test_getUserRewardsForEpoch_futureEpoch() external {
        _createLock(users.alice, STAKE_AMOUNT);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        (uint256 eligible, uint256 available) =
            protocol.trustBonding.getUserRewardsForEpoch(users.alice, currentEpoch + 1);

        assertEq(eligible, 0, "No rewards for future epochs");
        assertEq(available, 0, "No available rewards for future epochs");
    }

    function test_getUserRewardsForEpoch_validEpoch() external {
        // Setup: Alice stakes
        _createLock(users.alice, STAKE_AMOUNT);

        // Advance to epoch 2
        _advanceToEpoch(2);

        // Mock utilization data for epoch 1
        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(110 * 1e18));

        (uint256 eligible, uint256 available) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 1);

        assertGt(eligible, 0, "Should have eligible rewards for past epoch");
        assertLe(available, eligible, "Available rewards should be <= eligible rewards");
        assertGt(available, 0, "Should have some available rewards");
    }

    function test_getUserRewardsForEpoch_noStaking() external {
        // Don't stake anything
        _advanceToEpoch(2);

        (uint256 eligible, uint256 available) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 1);

        assertEq(eligible, 0, "No eligible rewards without staking");
        assertEq(available, 0, "No available rewards without staking");
    }

    function test_getUserRewardsForEpoch_multipleEpochs() external {
        // Setup: Alice stakes
        _createLock(users.alice, STAKE_AMOUNT);

        // Advance through multiple epochs
        _advanceToEpoch(3);

        // Mock utilization data for multiple epochs
        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(110 * 1e18));
        _setTotalUtilizationForEpoch(2, int256(1200 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 2, int256(120 * 1e18));

        // Check rewards for different epochs
        (uint256 eligible1, uint256 available1) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 1);
        (uint256 eligible2, uint256 available2) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 2);

        assertGt(eligible1, 0, "Should have eligible rewards for epoch 1");
        assertGt(eligible2, 0, "Should have eligible rewards for epoch 2");
        assertGt(available1, 0, "Should have available rewards for epoch 1");
        assertGt(available2, 0, "Should have available rewards for epoch 2");
    }

    function test_getUserRewardsForEpoch_zeroAddress() external {
        // Advance to at least epoch 1 so that the function can check for zero address
        _advanceToEpoch(1);

        vm.expectRevert();
        protocol.trustBonding.getUserRewardsForEpoch(address(0), 0);
    }

    /* =================================================== */
    /*                   EDGE CASES                        */
    /* =================================================== */

    function test_getters_zeroAddress() external {
        // Advance to at least epoch 1 so functions can reach the zero address checks
        _advanceToEpoch(1);

        // Test functions that should revert with zero address
        // getUserCurrentClaimableRewards calls _userEligibleRewardsForEpoch which checks for zero address
        vm.expectRevert();
        protocol.trustBonding.getUserCurrentClaimableRewards(address(0));

        // getUserInfo calls _getPersonalUtilizationRatio which checks for zero address
        vm.expectRevert();
        protocol.trustBonding.getUserInfo(address(0));
    }

    function test_getters_timeDecay() external {
        // Setup: Alice stakes
        _createLock(users.alice, STAKE_AMOUNT);
        uint256 initialBondedBalance = protocol.trustBonding.getUserInfo(users.alice).bondedBalance;

        // Fast forward significant time (but not past lock end)
        vm.warp(block.timestamp + 365 days);

        uint256 decayedBondedBalance = protocol.trustBonding.getUserInfo(users.alice).bondedBalance;

        // Bonded balance should decay over time
        assertLt(decayedBondedBalance, initialBondedBalance, "Bonded balance should decay over time");
        assertGt(decayedBondedBalance, 0, "Bonded balance should still be positive");
    }
}
