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
    /*              getUserRewardsForEpoch                 */
    /* =================================================== */

    function test_getUserRewardsForEpoch_firstEpoch() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

        (uint256 eligible, uint256 available) = protocol.trustBonding.getUserRewardsForEpoch(users.alice, 0);
        assertEq(eligible, 0, "No eligible rewards in first epoch");
        assertEq(available, 0, "No available rewards in first epoch");
    }

    function test_getUserRewardsForEpoch_futureEpoch() external {
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        (uint256 eligible, uint256 available) =
            protocol.trustBonding.getUserRewardsForEpoch(users.alice, currentEpoch + 1);

        assertEq(eligible, 0, "No rewards for future epochs");
        assertEq(available, 0, "No available rewards for future epochs");
    }

    function test_getUserRewardsForEpoch_validEpoch() external {
        // Setup: Alice stakes
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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
        _createLock(users.alice, MEDIUM_DEPOSIT_AMOUNT);

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
}
