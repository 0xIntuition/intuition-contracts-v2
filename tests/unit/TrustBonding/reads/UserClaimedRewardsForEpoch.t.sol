// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/reads/UserClaimedRewardsForEpoch.t.sol'
contract TrustBondingUserClaimedRewardsForEpochTest is TrustBondingBase {
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

    function test_userClaimedRewardsForEpoch_noClaims() external view {
        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0);
        assertEq(claimed, 0);
    }

    function test_userClaimedRewardsForEpoch_afterClaim() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        vm.warp(TRUST_BONDING_START_TIMESTAMP + TRUST_BONDING_EPOCH_LENGTH);

        uint256 prevEpoch = protocol.trustBonding.currentEpoch() - 1;

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, prevEpoch);
        assertGt(claimed, 0);
    }
}
