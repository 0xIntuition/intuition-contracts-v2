// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

contract TrustBondingEpochTest is TrustBondingBase {
    function setUp() public override {
        super.setUp();
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    function test_claimRewards_atExactNextEpochStart_claimsPreviousEpochOnly() external {
        _createLock(users.alice, initialTokens);

        uint256 previousEpoch = 0;
        vm.warp(protocol.trustBonding.epochTimestampEnd(previousEpoch) + 1);
        assertEq(protocol.trustBonding.currentEpoch(), previousEpoch + 1, "must be first second of next epoch");

        uint256 claimable = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        uint256 expected = _calculateExpectedRewards(users.alice, previousEpoch);
        assertEq(claimable, expected, "preview must match previous-epoch reward");
        assertGt(claimable, 0, "precondition: rewards are claimable");

        uint256 aliceBalanceBefore = users.alice.balance;
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(users.alice.balance - aliceBalanceBefore, claimable, "recipient receives previewed amount");
        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, previousEpoch),
            claimable,
            "claimed amount recorded for previous epoch"
        );
        assertLe(
            protocol.trustBonding.totalClaimedRewardsForEpoch(previousEpoch),
            protocol.trustBonding.emissionsForEpoch(previousEpoch),
            "budget invariant"
        );
    }

    function test_claimRewards_afterSkippingEpoch_claimsOnlyImmediatePreviousEpoch() external {
        _createLock(users.alice, initialTokens);

        vm.warp(protocol.trustBonding.epochTimestampEnd(1) + 1);
        assertEq(protocol.trustBonding.currentEpoch(), 2, "precondition: skipped epoch 1 claim window start");

        uint256 claimable = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        uint256 expectedPreviousEpoch = _calculateExpectedRewards(users.alice, 1);
        assertEq(claimable, expectedPreviousEpoch, "only epoch 1 is claimable at epoch 2");
        assertGt(claimable, 0, "precondition: epoch 1 rewards are claimable");

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0),
            0,
            "stale epoch 0 reward cannot be claimed through claimRewards"
        );
        assertEq(protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 1), claimable, "epoch 1 reward claimed");

        vm.expectRevert(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector);
        protocol.trustBonding.claimRewards(users.alice);
    }

    function test_getUserCurrentClaimableRewards_matchesActualClaimToAlternateRecipient() external {
        _createLock(users.alice, 100 ether);
        _createLock(users.bob, 50 ether);

        vm.warp(protocol.trustBonding.epochTimestampEnd(0) + 1);

        uint256 claimable = protocol.trustBonding.getUserCurrentClaimableRewards(users.alice);
        uint256 recipientBalanceBefore = users.charlie.balance;

        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.charlie);

        assertEq(users.charlie.balance - recipientBalanceBefore, claimable, "recipient receives previewed amount");
        assertEq(protocol.trustBonding.getUserCurrentClaimableRewards(users.alice), 0, "claimable clears after claim");
        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 0), claimable, "claimed ledger equals preview"
        );
    }

    function test_multiVaultRolloverAfterQuietEpochs_carriesUtilizationOnFirstAction() external {
        assertEq(protocol.multiVault.currentEpoch(), 0, "precondition: starts in epoch 0");

        uint256 firstCost = protocol.multiVault.getAtomCost();
        _createAtomForUtilization("rollover-source", users.alice);
        int256 epochZeroUtilization = protocol.multiVault.getTotalUtilizationForEpoch(0);
        assertEq(epochZeroUtilization, int256(firstCost), "epoch 0 utilization staged");

        vm.warp(protocol.trustBonding.epochTimestampEnd(2) + 1);
        uint256 currentEpoch = protocol.multiVault.currentEpoch();
        assertEq(currentEpoch, 3, "precondition: multi-epoch quiet gap");

        uint256 secondCost = protocol.multiVault.getAtomCost();
        _createAtomForUtilization("rollover-after-gap", users.bob);

        assertEq(
            protocol.multiVault.getTotalUtilizationForEpoch(currentEpoch),
            epochZeroUtilization + int256(secondCost),
            "first post-gap action carries prior utilization then applies delta"
        );
        assertEq(protocol.multiVault.lastSystemUtilizationEpoch(), currentEpoch, "rollover source advances");
    }

    function _createAtomForUtilization(string memory label, address creator) internal returns (bytes32 atomId) {
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked(label);
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.startPrank(creator);
        bytes32[] memory ids = protocol.multiVault.createAtoms{ value: atomCost }(atomData, assets);
        vm.stopPrank();

        atomId = ids[0];
    }
}
