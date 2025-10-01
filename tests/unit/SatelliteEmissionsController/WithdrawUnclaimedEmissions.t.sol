// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { console, Vm } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/SatelliteEmissionsController/WithdrawUnclaimedEmissions.t.sol'
contract WithdrawUnclaimedEmissionsTest is TrustBondingBase {
    /// @notice Events to test
    event UnclaimedRewardsWithdrawn(uint256 indexed epoch, address indexed recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
        _addToTrustBondingWhiteList(users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                        SUCCESSFUL WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawUnclaimedEmissions_successfulWithdrawal_epoch4ToEpoch2() external {
        // Create lock and generate rewards for epoch 2
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(3);

        // Alice claims rewards from epoch 2, leaving some unclaimed
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 4 so epoch 2 rewards are withdrawable (2 epochs old)
        _advanceToEpoch(4);

        uint256 unclaimedRewardsBefore = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewardsBefore, 0, "Should have unclaimed rewards to withdraw");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceBefore = users.bob.balance;

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(2, users.bob, unclaimedRewardsBefore);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceAfter = users.bob.balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;
        uint256 recipientBalanceDiff = recipientBalanceAfter - recipientBalanceBefore;

        assertLt(satelliteBalanceAfter, satelliteBalanceBefore, "Satellite balance should decrease");
        assertEq(satelliteBalanceDiff, unclaimedRewardsBefore, "Withdrawn amount should match unclaimed rewards");
        assertEq(recipientBalanceDiff, unclaimedRewardsBefore, "Recipient should receive exact amount");
    }

    function test_withdrawUnclaimedEmissions_successfulWithdrawal_epoch5ToEpoch3() external {
        // Create locks for multiple users to generate different reward scenarios
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens / 2);

        // Advance to epoch 4
        _advanceToEpoch(4);

        // Only Alice claims rewards from epoch 3, Bob doesn't
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 5 so epoch 3 rewards are withdrawable
        _advanceToEpoch(5);

        uint256 unclaimedRewardsBefore = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertGt(unclaimedRewardsBefore, 0, "Should have unclaimed rewards from Bob");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceBefore = users.charlie.balance;

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(3, users.charlie, unclaimedRewardsBefore);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(3, users.charlie);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceAfter = users.charlie.balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;
        uint256 recipientBalanceDiff = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(satelliteBalanceDiff, unclaimedRewardsBefore, "Should withdraw Bob's unclaimed rewards");
        assertEq(recipientBalanceDiff, unclaimedRewardsBefore, "Recipient should receive exact amount");
    }

    function test_withdrawUnclaimedEmissions_successfulWithdrawal_allRewardsUnclaimed() external {
        // Create lock but never claim any rewards
        _createLock(users.alice, initialTokens);

        // Advance to epoch 4 so epoch 2 rewards are withdrawable
        _advanceToEpoch(4);

        uint256 totalEpochRewards = protocol.trustBonding.emissionsForEpoch(2);
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);

        assertEq(unclaimedRewards, totalEpochRewards, "All rewards should be unclaimed");

        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceBefore = users.bob.balance;

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(2, users.bob, totalEpochRewards);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceAfter = users.bob.balance;
        uint256 satelliteBalanceDiff = satelliteBalanceBefore - satelliteBalanceAfter;
        uint256 recipientBalanceDiff = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(satelliteBalanceDiff, totalEpochRewards, "Should withdraw all epoch rewards");
        assertEq(recipientBalanceDiff, totalEpochRewards, "Recipient should receive all epoch rewards");
    }

    function test_withdrawUnclaimedEmissions_successfulWithdrawal_toContractRecipient() external {
        // Deploy a contract to receive funds
        MockRecipient mockRecipient = new MockRecipient();

        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        uint256 recipientBalanceBefore = address(mockRecipient).balance;

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(2, address(mockRecipient), unclaimedRewards);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, address(mockRecipient));

        uint256 recipientBalanceAfter = address(mockRecipient).balance;
        uint256 recipientBalanceDiff = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(recipientBalanceDiff, unclaimedRewards, "Contract recipient should receive funds");
    }

    /*//////////////////////////////////////////////////////////////
                        FAILED WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawUnclaimedEmissions_revertWhen_notCalledByAdmin() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards to withdraw
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.alice); // Alice does not have DEFAULT_ADMIN_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.alice,
                protocol.satelliteEmissionsController.DEFAULT_ADMIN_ROLE()
            )
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);
    }

    function test_withdrawUnclaimedEmissions_revertWhen_previouslyWithdrawn() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards to withdraw
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions.selector
            )
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);
    }

    function test_withdrawUnclaimedEmissions_revertWhen_previouslyBridged() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        // First bridge the emissions
        resetPrank(users.admin);
        protocol.satelliteEmissionsController.grantRole(
            protocol.satelliteEmissionsController.OPERATOR_ROLE(), users.admin
        );
        protocol.satelliteEmissionsController.bridgeUnclaimedEmissions{ value: 0.025 ether }(2);

        // Now try to withdraw the same epoch
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions.selector
            )
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);
    }

    function test_withdrawUnclaimedEmissions_revertWhen_zeroAddress() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Ensure there are unclaimed rewards to withdraw
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, address(0));
    }

    function test_withdrawUnclaimedEmissions_revertWhen_noUnclaimedRewards() external {
        // Create lock and claim all rewards
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Alice claims all rewards from epoch 2
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Verify no unclaimed rewards remain
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);

        // Handle case where all rewards are claimed
        if (unclaimedRewards == 0) {
            resetPrank(users.admin);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISatelliteEmissionsController.SatelliteEmissionsController_InvalidWithdrawAmount.selector
                )
            );
            protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EPOCH-SPECIFIC WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawUnclaimedEmissions_revertWhen_withdrawingTooRecentEpoch() external {
        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        // Try to withdraw epoch 3 rewards (only 1 epoch old, should fail)
        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertEq(unclaimedRewards, 0, "Should have no withdrawable rewards for epoch 3 (too recent)");

        resetPrank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InvalidWithdrawAmount.selector
            )
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(3, users.bob);

        // Try to withdraw current epoch (epoch 4)
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InvalidWithdrawAmount.selector
            )
        );
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(4, users.bob);
    }

    function test_withdrawUnclaimedEmissions_validWithdrawal_epoch5ToEpoch2And3() external {
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

        // Advance to epoch 5, now both epoch 2 and 3 rewards are withdrawable
        _advanceToEpoch(5);

        // Withdraw epoch 2 rewards (should have Bob's unclaimed rewards)
        uint256 unclaimedEpoch2 = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedEpoch2, 0, "Should have Bob's unclaimed epoch 2 rewards");

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(2, users.charlie, unclaimedEpoch2);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.charlie);

        // Withdraw epoch 3 rewards (should have Bob's unclaimed rewards)
        uint256 unclaimedEpoch3 = protocol.trustBonding.getUnclaimedRewardsForEpoch(3);
        assertGt(unclaimedEpoch3, 0, "Should have Bob's unclaimed epoch 3 rewards");

        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(3, users.charlie, unclaimedEpoch3);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(3, users.charlie);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawUnclaimedEmissions_earlyEpochs_noRewardsToWithdraw() external {
        // Test withdrawing in very early epochs when no withdrawal should be possible
        _createLock(users.alice, initialTokens);

        // In epoch 0: no rewards can be withdrawn
        uint256 unclaimedEpoch0 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0, 0, "Epoch 0 should have no withdrawable rewards");

        // Advance to epoch 1: still no rewards can be withdrawn
        _advanceToEpoch(1);
        uint256 unclaimedEpoch0InEpoch1 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0InEpoch1, 0, "Epoch 0 should have no withdrawable rewards in epoch 1");

        // Advance to epoch 2: the full emissions for epoch 0 are now withdrawable
        _advanceToEpoch(2);
        uint256 unclaimedEpoch0InEpoch2 = protocol.trustBonding.getUnclaimedRewardsForEpoch(0);
        assertEq(unclaimedEpoch0InEpoch2, 1_000_000 * 1e18, "Epoch 0 should now release the full 1,000,000 emissions");

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(0, users.bob, 1_000_000 * 1e18);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(0, users.bob);
    }

    function test_withdrawUnclaimedEmissions_multipleUsers_partialClaims() external {
        // Setup multiple users with different behaviors
        _createLock(users.alice, initialTokens);
        _createLock(users.bob, initialTokens / 2);
        _createLock(users.charlie, initialTokens * 2);

        // Advance to epoch 3
        _advanceToEpoch(3);

        // Only Alice claims epoch 2 rewards
        resetPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice);

        // Advance to epoch 4 so epoch 2 is withdrawable
        _advanceToEpoch(4);

        // Calculate expected unclaimed rewards (Bob + Charlie's rewards)
        uint256 totalEpoch2Rewards = protocol.trustBonding.emissionsForEpoch(2);
        uint256 aliceClaimedRewards = protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, 2);
        uint256 expectedUnclaimed = totalEpoch2Rewards - aliceClaimedRewards;

        uint256 actualUnclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertEq(actualUnclaimed, expectedUnclaimed, "Unclaimed should equal total minus Alice's claim");

        // Withdraw the unclaimed rewards
        uint256 satelliteBalanceBefore = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceBefore = users.bob.balance;

        resetPrank(users.admin);
        vm.expectEmit(true, true, false, true);
        emit UnclaimedRewardsWithdrawn(2, users.bob, expectedUnclaimed);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);

        uint256 satelliteBalanceAfter = address(protocol.satelliteEmissionsController).balance;
        uint256 recipientBalanceAfter = users.bob.balance;
        uint256 withdrawnAmount = satelliteBalanceBefore - satelliteBalanceAfter;
        uint256 receivedAmount = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(withdrawnAmount, expectedUnclaimed, "Should withdraw exactly the unclaimed amount");
        assertEq(receivedAmount, expectedUnclaimed, "Recipient should receive exactly the unclaimed amount");
    }

    function test_withdrawUnclaimedEmissions_reentrancyProtection() external {
        // Deploy a malicious recipient that attempts reentrancy
        MaliciousRecipient maliciousRecipient = new MaliciousRecipient(address(protocol.satelliteEmissionsController));

        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        assertGt(unclaimedRewards, 0, "Should have unclaimed rewards");

        resetPrank(users.admin);
        // The reentrancy guard should prevent the attack
        vm.expectRevert(); // ReentrancyGuard will revert
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, address(maliciousRecipient));
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_withdrawUnclaimedEmissions_differentRecipients(address recipient) external {
        _excludeReservedAddresses(recipient);

        _createLock(users.alice, initialTokens);
        _advanceToEpoch(4);

        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);
        vm.assume(unclaimedRewards > 0);

        uint256 recipientBalanceBefore = recipient.balance;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, recipient);

        uint256 recipientBalanceAfter = recipient.balance;
        uint256 receivedAmount = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(receivedAmount, unclaimedRewards, "Recipient should receive exact unclaimed amount");
    }

    function testFuzz_withdrawUnclaimedEmissions_differentEpochs(uint256 epochToWithdraw) external {
        epochToWithdraw = bound(epochToWithdraw, 0, 100);

        _createLock(users.alice, initialTokens);

        // Advance enough epochs to make epochToWithdraw potentially withdrawable
        if (epochToWithdraw < 100) {
            _advanceToEpoch(epochToWithdraw + 2);
        }

        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(epochToWithdraw);

        resetPrank(users.admin);
        if (unclaimedRewards == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISatelliteEmissionsController.SatelliteEmissionsController_InvalidWithdrawAmount.selector
                )
            );
            protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(epochToWithdraw, users.bob);
        } else {
            uint256 recipientBalanceBefore = users.bob.balance;

            protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(epochToWithdraw, users.bob);

            uint256 recipientBalanceAfter = users.bob.balance;
            uint256 receivedAmount = recipientBalanceAfter - recipientBalanceBefore;

            assertEq(receivedAmount, unclaimedRewards, "Should withdraw exact unclaimed amount");
        }
    }

    function testFuzz_withdrawUnclaimedEmissions_differentLockAmounts(uint256 lockAmount) external {
        lockAmount = bound(lockAmount, 1 ether, 1_000_000 ether);

        _createLock(users.alice, lockAmount);
        _advanceToEpoch(4);

        uint256 unclaimedRewards = protocol.trustBonding.getUnclaimedRewardsForEpoch(2);

        // All rewards should be unclaimed since no one claimed
        uint256 expectedRewards = protocol.trustBonding.emissionsForEpoch(2);
        assertEq(unclaimedRewards, expectedRewards, "All rewards should be unclaimed");

        resetPrank(users.admin);
        uint256 recipientBalanceBefore = users.bob.balance;

        protocol.satelliteEmissionsController.withdrawUnclaimedEmissions(2, users.bob);

        uint256 recipientBalanceAfter = users.bob.balance;
        uint256 receivedAmount = recipientBalanceAfter - recipientBalanceBefore;

        assertEq(receivedAmount, expectedRewards, "Should withdraw all epoch rewards");
    }
}

/*//////////////////////////////////////////////////////////////
                        HELPER CONTRACTS
//////////////////////////////////////////////////////////////*/

contract MockRecipient {
    receive() external payable { }
}

contract MaliciousRecipient {
    address public target;
    uint256 public attackCount;

    constructor(address _target) {
        target = _target;
    }

    receive() external payable {
        attackCount++;
        if (attackCount < 2) {
            // Attempt reentrancy
            ISatelliteEmissionsController(target).withdrawUnclaimedEmissions(2, address(this));
        }
    }
}
