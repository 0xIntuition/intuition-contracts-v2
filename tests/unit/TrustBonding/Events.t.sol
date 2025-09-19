// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

contract TrustBondingEventsTest is TrustBondingBase {
    /// @notice Constants
    uint256 public dealAmount = 100 * 1e18;
    uint256 public lockAmount = 1000 * 1e18;
    address public timelock = address(4);

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.deal(users.alice, 10_000 * 1e18);
        vm.deal(users.bob, 10_000 * 1e18);

        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);

        // Grant timelock role for admin functions and whitelist users
        vm.startPrank(users.admin);
        protocol.trustBonding.grantRole(protocol.trustBonding.TIMELOCK_ROLE(), timelock);
        protocol.trustBonding.add_to_whitelist(users.alice);
        protocol.trustBonding.add_to_whitelist(users.bob);
        vm.stopPrank();
    }

    /* =================================================== */
    /*                    EVENT TESTS                      */
    /* =================================================== */

    function test_RewardsClaimed_Event() public {
        // Setup: Give alice tokens and approve spending
        deal(address(protocol.wrappedTrust), users.alice, lockAmount);

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, block.timestamp + lockDuration);
        vm.stopPrank();

        // Advance to epoch 2 so rewards for epoch 1 can be claimed
        vm.warp(protocol.trustBonding.epochTimestampEnd(1) + 1);

        uint256 expectedRewards = protocol.trustBonding.eligibleRewards(users.alice);

        // Test event emission
        vm.expectEmit(true, true, false, true);
        emit ITrustBonding.RewardsClaimed(users.alice, users.bob, expectedRewards);

        vm.prank(users.alice);
        protocol.trustBonding.claimRewards(users.bob);
    }

    function test_MultiVaultSet_Event() public {
        address newMultiVault = address(0x123);

        vm.expectEmit(true, false, false, false);
        emit ITrustBonding.MultiVaultSet(newMultiVault);

        vm.prank(timelock);
        protocol.trustBonding.setMultiVault(newMultiVault);
    }

    function test_SatelliteEmissionsControllerSet_Event() public {
        address newSatelliteEmissionsController = address(0x456);

        vm.expectEmit(true, false, false, false);
        emit ITrustBonding.SatelliteEmissionsControllerSet(newSatelliteEmissionsController);

        vm.prank(timelock);
        protocol.trustBonding.updateSatelliteEmissionsController(newSatelliteEmissionsController);
    }

    function test_SystemUtilizationLowerBoundUpdated_Event() public {
        uint256 newLowerBound = 6000; // 60%

        vm.expectEmit(false, false, false, true);
        emit ITrustBonding.SystemUtilizationLowerBoundUpdated(newLowerBound);

        vm.prank(timelock);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newLowerBound);
    }

    function test_PersonalUtilizationLowerBoundUpdated_Event() public {
        uint256 newLowerBound = 3500; // 35%

        vm.expectEmit(false, false, false, true);
        emit ITrustBonding.PersonalUtilizationLowerBoundUpdated(newLowerBound);

        vm.prank(timelock);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newLowerBound);
    }

    function test_RewardsClaimed_Event_WithActualRewards() public {
        // Setup: Give alice tokens and approve spending
        deal(address(protocol.wrappedTrust), users.alice, lockAmount);

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, block.timestamp + lockDuration);
        vm.stopPrank();

        // Advance to epoch 1 end
        vm.warp(protocol.trustBonding.epochTimestampEnd(0) + 1);

        // Advance to epoch 2 so rewards for epoch 1 can be claimed
        vm.warp(protocol.trustBonding.epochTimestampEnd(1) + 1);

        uint256 expectedRewards = protocol.trustBonding.eligibleRewards(users.alice);

        if (expectedRewards > 0) {
            vm.expectEmit(true, true, false, true);
            emit ITrustBonding.RewardsClaimed(users.alice, users.bob, expectedRewards);

            vm.prank(users.alice);
            protocol.trustBonding.claimRewards(users.bob);
        }
    }

    function test_MultipleEvents_InSequence() public {
        // Test multiple events in a single transaction context
        address newMultiVault = address(0x789);
        uint256 newSystemBound = 5500; // 55%
        uint256 newPersonalBound = 2800; // 28%

        // Test MultiVaultSet event
        vm.expectEmit(true, false, false, false);
        emit ITrustBonding.MultiVaultSet(newMultiVault);

        vm.prank(timelock);
        protocol.trustBonding.setMultiVault(newMultiVault);

        // Test SystemUtilizationLowerBoundUpdated event
        vm.expectEmit(false, false, false, true);
        emit ITrustBonding.SystemUtilizationLowerBoundUpdated(newSystemBound);

        vm.prank(timelock);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newSystemBound);

        // Test PersonalUtilizationLowerBoundUpdated event
        vm.expectEmit(false, false, false, true);
        emit ITrustBonding.PersonalUtilizationLowerBoundUpdated(newPersonalBound);

        vm.prank(timelock);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newPersonalBound);
    }

    function test_EventParameters_Correctness() public {
        // Test that event parameters are correctly emitted
        uint256 newBound = 4500;

        // Capture the exact event data
        vm.recordLogs();

        vm.prank(timelock);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newBound);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);

        // Verify the event signature matches SystemUtilizationLowerBoundUpdated
        assertEq(logs[0].topics[0], keccak256("SystemUtilizationLowerBoundUpdated(uint256)"));

        // Verify the data contains the correct value
        uint256 decodedValue = abi.decode(logs[0].data, (uint256));
        assertEq(decodedValue, newBound);
    }
}
