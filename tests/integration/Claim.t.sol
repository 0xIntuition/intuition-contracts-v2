// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CoreEmissionsControllerMock } from "tests/mocks/CoreEmissionsControllerMock.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

contract ClaimTest is BaseTest {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    bytes32 TERM_ID;

    uint256 internal constant DEFAULT_CURVE_ID = 1;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual override {
        super.setUp();
        deal({ to: address(protocol.satelliteEmissionsController), give: 1_000_000_000_000e18 });
        TERM_ID = createSimpleAtom("Deposit test atom", ATOM_COST[0], users.admin);
    }

    function test_createStakeRewards_FullyBonded_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliff(users.alice, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH);
        _nextCliff(users.alice, 2, (900_000 * 1e18));
        _nextCliff(users.alice, 3, (121_500 * 1e18)); // Dramatic reduction after 2nd epoch without full utilization.
        _nextCliff(users.alice, 4, (109_350 * 1e18));
        _nextCliff(users.alice, 5, (98_415 * 1e18));
    }

    function test_twoUsers_createStakeRewards_FullyBonded_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](2);
        _users[0] = users.alice;
        _users[1] = users.bob;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliff(users.alice, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH / _users.length);
        _nextCliff(users.alice, 2, (900_000 * 1e18) / _users.length);
        _nextCliff(users.alice, 3, (121_500 * 1e18) / _users.length); // Dramatic reduction after 2nd epoch without full
            // utilization.
        _nextCliff(users.alice, 4, (109_350 * 1e18) / _users.length);
        _nextCliff(users.alice, 5, (98_415 * 1e18) / _users.length);
    }

    function test_threeUsers_createStakeRewards_FullyBonded_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](3);
        _users[0] = users.alice;
        _users[1] = users.bob;
        _users[2] = users.charlie;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliff(users.alice, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH / _users.length);
        _nextCliff(users.alice, 2, (900_000 * 1e18) / _users.length);
        _nextCliff(users.alice, 3, (121_500 * 1e18) / _users.length); // Dramatic reduction after 2nd epoch without
            // full// utilization.
        _nextCliff(users.alice, 4, (109_350 * 1e18) / _users.length);
        _nextCliff(users.alice, 5, (98_415 * 1e18) / _users.length);
    }

    function test_createStakeRewards_FullyBonded_MaxUtilization_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliffWithRewardsDeposit(_users, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH);
        _nextCliffWithRewardsDeposit(_users, 2, (900_000 * 1e18));
        _nextCliffWithRewardsDeposit(_users, 3, (810_000 * 1e18));
        _nextCliffWithRewardsDeposit(_users, 4, (729_000 * 1e18));
        _nextCliffWithRewardsDeposit(_users, 5, (656_100 * 1e18));
    }

    function test_twoUsers_createStakeRewards_FullyBonded_MaxUtilization_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](2);
        _users[0] = users.alice;
        _users[1] = users.bob;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliffWithRewardsDeposit(_users, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH / _users.length);
        _nextCliffWithRewardsDeposit(_users, 2, (900_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 3, (810_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 4, (729_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 5, (656_100 * 1e18) / _users.length);
    }

    function test_threeUsers_createStakeRewards_FullyBonded_MaxUtilization_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users = new address[](3);
        _users[0] = users.alice;
        _users[1] = users.bob;
        _users[2] = users.charlie;

        _addToWhiteList(_users);
        _createLocksForUsers(_users, stakeAmount, THREE_YEARS);
        _nextCliffWithRewardsDeposit(_users, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH / _users.length);
        _nextCliffWithRewardsDeposit(_users, 2, (900_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 3, (810_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 4, (729_000 * 1e18) / _users.length);
        _nextCliffWithRewardsDeposit(_users, 5, (656_100 * 1e18) / _users.length);
    }

    function test_mixedUsers_createStakeRewards_FullyBonded_MaxUtilization_Success() public {
        uint256 stakeAmount = 1000 * 1e18;
        address[] memory _users1 = new address[](2);
        _users1[0] = users.alice;
        _users1[1] = users.bob;

        address[] memory _users2 = new address[](1);
        _users2[0] = users.charlie;

        _addToWhiteList(_users1);
        _addToWhiteList(_users2);
        _createLocksForUsers(_users1, stakeAmount, THREE_YEARS);
        _createLocksForUsers(_users2, stakeAmount, THREE_YEARS);
        _nextCliffWithRewardsDeposit(_users1, 1, EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH / 3);
        resetPrank({ msgSender: users.charlie });
        protocol.trustBonding.claimRewards(users.charlie);
        _nextCliffWithRewardsDeposit(_users1, 2, (900_000 * 1e18) / 3);
        resetPrank({ msgSender: users.charlie });
        protocol.trustBonding.claimRewards(users.charlie);
        _nextCliffWithRewardsDeposit(_users1, 3, (224_991 * 1e18));
    }

    function _addToWhiteList(address[] memory _users) internal {
        resetPrank({ msgSender: users.admin });
        for (uint256 i = 0; i < _users.length; i++) {
            protocol.trustBonding.add_to_whitelist(_users[i]);
        }
    }

    function _createLocksForUsers(address[] memory _users, uint256 stakeAmount, uint256 duration) internal {
        for (uint256 i = 0; i < _users.length; i++) {
            _createLockForUser(_users[i], stakeAmount, duration);
        }
    }

    function _createLockForUser(address user, uint256 stakeAmount, uint256 duration) internal {
        resetPrank({ msgSender: user });
        protocol.trust.approve(address(protocol.trustBonding), stakeAmount);
        protocol.trustBonding.create_lock(stakeAmount, block.timestamp + duration);
    }

    function _nextCliff(address user, uint256 epoch, uint256 rewardAmount) internal {
        uint256 curr = protocol.trustBonding.currentEpoch();
        uint256 end = protocol.trustBonding.epochTimestampEnd(curr);
        vm.warp(end + 1); // step into the next epoch
        assertEq(protocol.trustBonding.currentEpoch(), epoch);
        assertEq(protocol.trustBonding.eligibleRewards(user), rewardAmount);
        uint256 balanceBefore = address(user).balance;
        protocol.trustBonding.claimRewards(user);
        uint256 balanceAfter = address(user).balance;
        assertEq(balanceBefore + rewardAmount, balanceAfter);
    }

    function _nextCliffForUsers(address[] memory users, uint256 epoch, uint256 rewardAmount) internal {
        uint256 curr = protocol.trustBonding.currentEpoch();
        uint256 end = protocol.trustBonding.epochTimestampEnd(curr);
        vm.warp(end + 1); // step into the next epoch
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            assertEq(protocol.trustBonding.currentEpoch(), epoch);
            assertEq(protocol.trustBonding.eligibleRewards(user), rewardAmount);
            uint256 balanceBefore = address(user).balance;
            protocol.trustBonding.claimRewards(user);
            uint256 balanceAfter = address(user).balance;
            assertEq(balanceBefore + rewardAmount, balanceAfter);
        }
    }

    function _nextCliffWithRewardsDeposit(address user, uint256 epoch, uint256 rewardAmount) internal {
        uint256 curr = protocol.trustBonding.currentEpoch();
        uint256 end = protocol.trustBonding.epochTimestampEnd(curr);
        vm.warp(end + 1); // step into the next epoch
        resetPrank({ msgSender: user });
        assertEq(protocol.trustBonding.currentEpoch(), epoch);
        assertEq(protocol.trustBonding.eligibleRewards(user), rewardAmount);
        uint256 balanceBefore = address(user).balance;
        protocol.trustBonding.claimRewards(user);
        uint256 balanceAfter = address(user).balance;
        assertEq(balanceBefore + rewardAmount, balanceAfter);
        makeDeposit(user, user, TERM_ID, DEFAULT_CURVE_ID, rewardAmount, 1e4);
    }

    function _nextCliffWithRewardsDeposit(address[] memory users, uint256 epoch, uint256 rewardAmount) internal {
        uint256 curr = protocol.trustBonding.currentEpoch();
        uint256 end = protocol.trustBonding.epochTimestampEnd(curr);
        vm.warp(end + 1); // step into the next epoch
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            resetPrank({ msgSender: user });
            assertEq(protocol.trustBonding.currentEpoch(), epoch);
            assertEq(protocol.trustBonding.eligibleRewards(user), rewardAmount);
            uint256 balanceBefore = address(user).balance;
            protocol.trustBonding.claimRewards(user);
            uint256 balanceAfter = address(user).balance;
            assertEq(balanceBefore + rewardAmount, balanceAfter);
            makeDeposit(user, user, TERM_ID, DEFAULT_CURVE_ID, rewardAmount, 1e4);
        }
    }
}
