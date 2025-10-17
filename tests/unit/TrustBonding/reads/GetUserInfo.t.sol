// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/reads/GetUserInfo.t.sol'
contract TrustBondingGetUserInfoTest is TrustBondingBase {
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

    /* =================================================== */
    /*                    getUserInfo                      */
    /* =================================================== */

    function test_getUserInfo_noStakingHistory() external view {
        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertEq(userInfo.personalUtilization, BASIS_POINTS_DIVISOR, "Personal utilization should be 0 for new user");
        assertEq(userInfo.eligibleRewards, 0, "Eligible rewards should be 0 for new user");
        assertEq(userInfo.maxRewards, 0, "Max rewards should be 0 for new user");
        assertEq(userInfo.lockedAmount, 0, "Locked amount should be 0 for new user");
        assertEq(userInfo.lockEnd, 0, "Lock end should be 0 for new user");
        assertEq(userInfo.bondedBalance, 0, "Bonded balance should be 0 for new user");
    }

    function test_getUserInfo_firstEpoch() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        uint256 eligibleRewards = protocol.trustBonding.emissionsForEpoch(0);
        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertEq(userInfo.personalUtilization, BASIS_POINTS_DIVISOR, "Personal utilization should be 0 in first epoch");
        assertEq(userInfo.eligibleRewards, eligibleRewards, "Eligible rewards should be 0 in first epoch");
        assertEq(userInfo.maxRewards, eligibleRewards, "Max rewards should be 0 in first epoch");
        assertEq(userInfo.lockedAmount, MEDIUM_DEPOSIT_AMOUNT, "Locked amount should equal staked amount");
        assertGt(userInfo.lockEnd, block.timestamp, "Lock end should be in the future");
        assertGt(userInfo.bondedBalance, 0, "Bonded balance should be greater than 0");
    }

    function test_getUserInfo_withStaking() external {
        // Setup: Alice stakes
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);
        _advanceToEpoch(3);
        _setTotalUtilizationForEpoch(1, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, 1000 * 1e18);
        _setTotalUtilizationForEpoch(2, int256(1100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 2, 0);

        uint256 emissionsForEpoch = protocol.trustBonding.emissionsForEpoch(3);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);
        assertEq(
            userInfo.personalUtilization,
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND,
            "Personal utilization should hit MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND"
        );
        assertEq(
            userInfo.eligibleRewards,
            (emissionsForEpoch * userInfo.personalUtilization) / BASIS_POINTS_DIVISOR,
            "Eligible rewards should be <= max rewards"
        );
        assertEq(
            userInfo.maxRewards,
            emissionsForEpoch,
            "Users max rewards should equal emissions per epoch with full utilization"
        );
        assertEq(userInfo.lockedAmount, MEDIUM_DEPOSIT_AMOUNT, "Locked amount should equal staked amount");
    }

    function test_getUserInfo_perfectUtilization() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

        uint256 EPOCHS_TO_ADVANCE = 3;
        _advanceToEpoch(EPOCHS_TO_ADVANCE);

        uint256 targetUtilization = 100 * 1e18;
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE - 1, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(EPOCHS_TO_ADVANCE, int256(100 * 1e18 + int256(targetUtilization)));

        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, int256(100 * 1e18));
        _setUserUtilizationForEpoch(users.alice, EPOCHS_TO_ADVANCE, int256(100 * 1e18 + int256(targetUtilization)));

        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE - 1, targetUtilization);
        _setUserClaimedRewardsForEpoch(users.alice, EPOCHS_TO_ADVANCE, targetUtilization);

        _setActiveEpoch(users.alice, 1, EPOCHS_TO_ADVANCE - 1);
        _setActiveEpoch(users.alice, 0, EPOCHS_TO_ADVANCE);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);
        assertEq(userInfo.personalUtilization, BASIS_POINTS_DIVISOR, "Personal utilization should be 100%");
        assertEq(
            userInfo.eligibleRewards, userInfo.maxRewards, "Eligible should equal max rewards with perfect utilization"
        );
    }

    function test_getUserInfo_multipleLocks() external {
        // Setup: Alice creates initial lock
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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

        assertEq(userInfo.lockedAmount, MEDIUM_DEPOSIT_AMOUNT, "Locked amount should reflect stake");
        assertGt(userInfo.maxRewards, 0, "Max rewards should be positive with locks");
        assertGt(userInfo.bondedBalance, 0, "Bonded balance should be positive");
    }
}
