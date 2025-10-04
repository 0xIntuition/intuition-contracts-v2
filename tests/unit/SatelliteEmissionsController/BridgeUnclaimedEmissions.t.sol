// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { console, Vm } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/SatelliteEmissionsController/BridgeUnclaimedEmissions.t.sol'
contract BridgeUnclaimedEmissionsTest is TrustBondingBase {
    uint256 internal constant GAS_QUOTE = 0.025 ether;

    /// @notice Events to test
    event UnclaimedRewardsBridged(uint256 indexed epoch, uint256 amount);

    function setUp() public override {
        super.setUp();
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
        _addToTrustBondingWhiteList(users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                        SUCCESSFUL BRIDGING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeUnclaimedEmissions_successfulBridging_epoch4ToEpoch2() external {
        // Create lock and generate rewards for epoch 2
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(3);

        // Alice claims rewards from epoch 2, leaving some unclaimed
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 4 so epoch 2 rewards are bridgeable (2 epochs old)
        _advanceToEpoch(4);

        uint256 unclaimedRewardsBefore = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewardsBefore, 0, "Should have unclaimed rewards to bridge");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;

        assertLt(satelliteBalanceAfter, satelliteBalanceBefore, "Satellite balance should decrease");
        assertEq(satelliteBalanceDiff, unclaimedRewardsBefore, "Bridged amount should match unclaimed rewards");
    }

    function test_bridgeUnclaimedEmissions_successfulBridging_epoch5ToEpoch3() external {
        // Create locks for multiple users to generate different reward scenarios
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens / 2);

        // Advance to epoch 4
        _advanceToEpoch(4);

        // Only Alice claims rewards from epoch 3, Bob doesn't
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 5 so epoch 3 rewards are bridgeable
        _advanceToEpoch(5);

        uint256 unclaimedRewardsBefore = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertGt(unclaimedRewardsBefore, 0, "Should have unclaimed rewards from Bob");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(3);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;

        assertEq(satelliteBalanceDiff, unclaimedRewardsBefore, "Should bridge Bob's unclaimed rewards");
    }

    function test_bridgeUnclaimedEmissions_successfulBridging_allRewardsUnclaimed() external {
        // Create lock but never claim any rewards
        _createLock(users.alice, initialTokens);

        // Advance to epoch 4 so epoch 2 rewards are bridgeable
        _advanceToEpoch(4);

        uint256 totalEpochRewards = protocol.trustBonding.emissionsForEpoch(2);
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);

        assertEq(unclaimedRewards, totalEpochRewards, "All rewards should be unclaimed");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;

        assertEq(satelliteBalanceDiff, totalEpochRewards, "Should bridge all epoch rewards");
    }

    /*//////////////////////////////////////////////////////////////
                     BRIDGING PREVIOUSLY CLAIMED REWARDS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                        FAILED BRIDGING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeUnclaimedEmissions_revertWhen_trustBondingIsNotSetYet() external {
        // Deploy a new SatelliteEmissionsController without setting TrustBonding
        SatelliteEmissionsController newSatelliteEmissionsController = _deploySatelliteEmissionsController();

        address baseEmissionsController = address(0xABC);

        // Initialize the new SatelliteEmissionsController
        newSatelliteEmissionsController.initialize(
            users.admin,
            baseEmissionsController, // placeholder address for BaseEmissionsController
            metaERC20DispatchInit,
            coreEmissionsInit
        );

        // Advance to epoch 4 to ensure there are bridgeable rewards
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        resetPrank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_TrustBondingNotSet.selector
            )
        );
        newSatelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);
    }

    function test_bridgeUnclaimedEmissions_revertWhen_previouslyClaimed() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards to bridge
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions.selector
            )
        );
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);
    }

    function test_bridgeUnclaimedEmissions_revertWhen_insufficientGasPayment() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards to bridge
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InsufficientGasPayment.selector
            )
        );
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE / 2 }(2); // Insufficient gas
    }

    function test_bridgeUnclaimedEmissions_revertWhen_unauthorized() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        resetPrank(users.alice); // Alice is not admin
        vm.expectRevert();
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);
    }

    /*//////////////////////////////////////////////////////////////
                        EPOCH-SPECIFIC BRIDGING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeUnclaimedEmissions_revertWhen_bridgingTooRecentEpoch() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Try to bridge epoch 3 rewards (only 1 epoch old, should fail)
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertEq(unclaimedRewards, 0, "Should have no bridgeable rewards for epoch 3 (too recent)");

        resetPrank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InvalidBridgeAmount.selector
            )
        );
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(3);

        // Try to bridge current epoch (epoch 4)
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InvalidBridgeAmount.selector
            )
        );
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(4);
    }

    function test_bridgeUnclaimedEmissions_validBridging_epoch5ToEpoch2And3() external {
        // Create locks for different users
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens);

        // Advance to epoch 3 and have Alice claim some rewards
        _advanceToEpoch(3);
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice); // Claims epoch 2 rewards

        // Advance to epoch 4 and have Alice claim again, Bob doesn't claim
        _advanceToEpoch(4);
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice); // Claims epoch 3 rewards

        // Advance to epoch 5, now both epoch 2 and 3 rewards are bridgeable
        _advanceToEpoch(5);

        // Bridge epoch 2 rewards (should have Bob's unclaimed rewards)
        uint256 unclaimedEpoch2 = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedEpoch2, 0, "Should have Bob's unclaimed epoch 2 rewards");

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);

        // Bridge epoch 3 rewards (should have Bob's unclaimed rewards)
        uint256 unclaimedEpoch3 = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertGt(unclaimedEpoch3, 0, "Should have Bob's unclaimed epoch 3 rewards");

        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(3);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_bridgeUnclaimedEmissions_earlyEpochs_noRewardsToBridge() external {
        // Test bridging in very early epochs when no bridging should be possible
        _createLock(users.alice, initialTokens);

        // In epoch 0: no rewards can be bridged
        uint256 unclaimedEpoch0 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0, 0, "Epoch 0 should have no bridgeable rewards");

        // Advance to epoch 1: still no rewards can be bridged
        _advanceToEpoch(1);
        uint256 unclaimedEpoch0InEpoch1 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0InEpoch1, 0, "Epoch 0 should have no bridgeable rewards in epoch 1");

        // Advance to epoch 2: the full emissions for epoch 0 are now bridgeable
        _advanceToEpoch(2);
        uint256 unclaimedEpoch0InEpoch2 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0InEpoch2, 1_000_000 * 1e18, "Epoch 0 should now release the full 1,000,000 emissions");
    }

    function test_bridgeUnclaimedEmissions_gasRefund() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        uint256 excessGas = GAS_QUOTE * 2; // Send double the required gas
        uint256 adminBalanceBefore = users.admin.balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: excessGas }(2);

        uint256 adminBalanceAfter = users.admin.balance;
        uint256 gasUsed = adminBalanceBefore - adminBalanceAfter;

        assertLt(gasUsed, excessGas, "Should refund excess gas");
        assertGe(gasUsed, GAS_QUOTE, "Should use at least the minimum required gas");
    }

    function test_bridgeUnclaimedEmissions_multipleUsers_partialClaims() external {
        // Setup multiple users with different behaviors
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens / 2);
        _createLock(users.charlie, initialTokens * 2);

        // Advance to epoch 3
        _advanceToEpoch(3);

        // Only Alice claims epoch 2 rewards
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 4 so epoch 2 is bridgeable
        _advanceToEpoch(4);

        // Calculate expected unclaimed rewards (Bob + Charlie's rewards)
        uint256 totalEpoch2Rewards = protocol.trustBonding.emissionsForEpoch(2);
        uint256 aliceClaimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 2);
        uint256 expectedUnclaimed = totalEpoch2Rewards - aliceClaimedRewards;

        uint256 actualUnclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertEq(actualUnclaimed, expectedUnclaimed, "Unclaimed should equal total minus Alice's claim");

        // Bridge the unclaimed rewards
        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: GAS_QUOTE }(2);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 bridgedAmount = satelliteBalanceBefore - satelliteBalanceAfter;

        assertEq(bridgedAmount, expectedUnclaimed, "Should bridge exactly the unclaimed amount");
    }
}
