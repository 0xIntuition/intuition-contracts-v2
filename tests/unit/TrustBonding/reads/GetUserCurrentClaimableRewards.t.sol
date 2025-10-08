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
    /*            getUserCurrentClaimableRewards          */
    /* =================================================== */

    function test_getUserCurrentClaimableRewards_noStakingHistory() external view {
        // User with no staking history should have 0 claimable rewards
        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(claimableRewards, 0, "User with no staking history should have 0 claimable rewards");
    }

    function test_getUserCurrentClaimableRewards_firstEpoch() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertEq(claimableRewards, 0, "No rewards should be claimable in first epoch");
    }

    function test_getUserCurrentClaimableRewards_singleStakePeriod() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
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
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
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
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _advanceToEpoch(2);

        // Mock utilization data across multiple epochs
        _setTotalUtilizationForEpoch(0, int256(1000 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 0, int256(100 * 1e18));
        _setTotalUtilizationForEpoch(1, int256(1200 * 1e18));
        _setUserUtilizationForEpoch(users.alice, 1, int256(200 * 1e18));

        uint256 claimableRewards = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        assertGt(claimableRewards, 0, "User should have rewards from stake periods");
    }
}
