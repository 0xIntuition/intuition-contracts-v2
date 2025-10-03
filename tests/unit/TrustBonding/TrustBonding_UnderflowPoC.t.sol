// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { console } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "./TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

contract TrustBonding_UnderflowPoC is TrustBondingBase {
    uint256 constant lockAmount = 1000 * 1e18;

    function setUp() public override {
        super.setUp();
    }

    function test_PoC_GetUserInfo_Underflow() public {
        _bondTokens(users.alice, lockAmount);

        _advanceToEpoch(2);

        uint256 epoch1End = protocol.satelliteEmissionsController.getEpochTimestampEnd(1);

        assertEq(protocol.trustBonding.currentEpoch(), 2);

        vm.warp(block.timestamp + 2 hours);
        uint256 checkpointTimestamp = block.timestamp;

        vm.startPrank(users.alice);
        protocol.trustBonding.increase_amount(100 * 1e18);
        vm.stopPrank();

        assertGt(checkpointTimestamp, epoch1End, "Checkpoint must be after epoch 1 end");

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertGt(userInfo.lockedAmount, 0, "Should have locked amount");
        assertGt(userInfo.bondedBalance, 0, "Should have bonded balance");
    }

    function test_PoC_TotalBondedSupply_Underflow() public {
        _bondTokens(users.alice, lockAmount);

        _advanceToEpoch(2);
        uint256 epoch1End = protocol.satelliteEmissionsController.getEpochTimestampEnd(1);

        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(users.alice);
        protocol.trustBonding.increase_amount(100 * 1e18);
        vm.stopPrank();

        uint256 totalBalance = protocol.trustBonding.totalBondedBalanceAtEpochEnd(1);

        assertGt(totalBalance, 0, "Should have total balance");
    }

    function test_EdgeCase_MultipleCheckpoints_Underflow() public {
        _bondTokens(users.alice, lockAmount);

        _advanceToEpoch(2);
        uint256 epoch1End = protocol.satelliteEmissionsController.getEpochTimestampEnd(1);

        for (uint256 i = 1; i <= 3; i++) {
            vm.warp(block.timestamp + i * 1 hours);
            vm.startPrank(users.alice);
            protocol.trustBonding.increase_amount(10 * 1e18);
            vm.stopPrank();
        }

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertGt(userInfo.lockedAmount, 0, "Should have locked amount");
        assertGt(userInfo.bondedBalance, 0, "Should have bonded balance");
    }

    function test_Fixed_GetUserInfo_NoUnderflow() public {
        _bondTokens(users.alice, lockAmount);

        _advanceToEpoch(2);

        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(users.alice);
        protocol.trustBonding.increase_amount(100 * 1e18);
        vm.stopPrank();

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertGt(userInfo.lockedAmount, 0, "Should have locked amount");
        assertGt(userInfo.bondedBalance, 0, "Should have bonded balance");
    }

    function test_Regression_GetUserInfo_NormalFlow() public {
        _bondTokens(users.alice, lockAmount);

        _advanceToEpoch(2);

        UserInfo memory userInfo = protocol.trustBonding.getUserInfo(users.alice);

        assertGt(userInfo.lockedAmount, 0, "Should have locked amount");
        assertGt(userInfo.bondedBalance, 0, "Should have bonded balance");
    }
}
