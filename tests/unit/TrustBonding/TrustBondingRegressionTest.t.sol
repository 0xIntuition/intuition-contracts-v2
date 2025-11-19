// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TrustBondingUpgradeRegressionTest is Test {
    // --- Chain & contract constants ---
    uint256 internal constant PRE_BUG_FORK_BLOCK = 115_255;
    uint256 internal constant POST_BUG_FORK_BLOCK = 115_285;
    uint256 internal constant BASE_POST_UPGRADE_BLOCK = 38_389_704;

    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant PROXY_ADMIN = 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62;
    address internal constant WRAPPED_TRUST = 0x81cFb09cb44f7184Ad934C09F82000701A4bF672;

    // Sample users
    address internal constant USER0 = 0x58791B7d2CFC8310f7D2032B99B3e9DfFAAe4f17;
    address internal constant USER1 = 0xeD76B9f22780F9aA8Cf1a096c71bF8A5fE16290d;
    address internal constant USER2 = 0xEe34cEd4608C238be371D8c519d56F8D7190A445;

    function setUp() external {
        // Fork Intuition L3 at the block which is just before the moment at which the bug appeared
        vm.createSelectFork("intuition", PRE_BUG_FORK_BLOCK);

        // Make sure sample users have TRUST to wrap into WTRUST
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
    }

    function test_upgradeFixesVotingEscrowUnderflowError() external {
        TrustBonding trustBonding = TrustBonding(TRUST_BONDING_PROXY);

        // ----------------------------------------------------------
        // 0. PRE-BUG: get initial values
        // ----------------------------------------------------------

        // (a) get total bonded balance at epoch end + individual users' bonded balances
        uint256 totalAtEpoch0PreBug = trustBonding.totalBondedBalanceAtEpochEnd(0);
        uint256 user0AtEpoch0PreBug = trustBonding.userBondedBalanceAtEpochEnd(USER0, 0);
        uint256 user1AtEpoch0PreBug = trustBonding.userBondedBalanceAtEpochEnd(USER1, 0);
        uint256 user2AtEpoch0PreBug = trustBonding.userBondedBalanceAtEpochEnd(USER2, 0);

        // Assert basic sanity checks
        assertGt(totalAtEpoch0PreBug, 0, "Total bonded at epoch 0 end must be positive number");
        assertGt(user0AtEpoch0PreBug, 0, "User 0 bonded at epoch 0 end must be positive number");
        assertGt(user1AtEpoch0PreBug, 0, "User 1 bonded at epoch 0 end must be positive number");
        assertGt(user2AtEpoch0PreBug, 0, "User 2 bonded at epoch 0 end must be positive number");

        // (b) confirm that claiming rewards works pre-bug
        uint256 user0EligibleRewardsPreUpgrade = trustBonding.userEligibleRewardsForEpoch(USER0, 0);

        vm.startPrank(USER0);
        uint256 user0BalanceBefore = address(USER0).balance;
        trustBonding.claimRewards(USER0);
        assertEq(
            address(USER0).balance,
            user0BalanceBefore + trustBonding.userEligibleRewardsForEpoch(USER0, 0),
            "User 0 balance must increase by eligible rewards amount"
        );
        assertEq(
            trustBonding.userEligibleRewardsForEpoch(USER0, 0),
            trustBonding.userClaimedRewardsForEpoch(USER0, 0),
            "User 0 claimed rewards must match eligible rewards"
        );

        // ----------------------------------------------------------
        // 1. PRE-UPGRADE: reproduce the failing behavior
        // ----------------------------------------------------------

        // Advance the same L3 chain fork to the block height at which the bug started appearing
        vm.createSelectFork("intuition", POST_BUG_FORK_BLOCK);

        // (a) "supply" path used to revert with a Panic
        vm.expectRevert(stdError.arithmeticError);
        trustBonding.totalBondedBalanceAtEpochEnd(0);

        // (b) claimRewards used to revert via the same underlying bug
        vm.startPrank(USER1);
        vm.expectRevert(stdError.arithmeticError);
        trustBonding.claimRewards(USER1);
        vm.stopPrank();

        // ----------------------------------------------------------
        // 2. UPGRADE: deploy new implementation & upgrade proxy
        // ----------------------------------------------------------

        // Deploy the new TrustBonding implementation that includes the fixed VotingEscrow logic (this uses the local
        // code under test).
        TrustBonding newImpl = new TrustBonding();

        vm.startPrank(TIMELOCK);
        ProxyAdmin(PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(TRUST_BONDING_PROXY)),
                address(newImpl),
                bytes("") // no initializer call necessary
            );
        vm.stopPrank();

        // Re-bind after upgrade (same address, new code)
        trustBonding = TrustBonding(TRUST_BONDING_PROXY);

        // ----------------------------------------------------------
        // 3. POST-UPGRADE: the same calls must no longer revert
        // ----------------------------------------------------------

        // (a) Global supply at epoch end should now be readable
        uint256 totalAtEpoch0 = trustBonding.totalBondedBalanceAtEpochEnd(0);
        assertEq(totalAtEpoch0, totalAtEpoch0PreBug, "total bonded balance must match pre and post-fix");

        // (b) User balance at epoch end must no longer revert either
        assertEq(
            trustBonding.userBondedBalanceAtEpochEnd(USER0, 0),
            user0AtEpoch0PreBug,
            "user 0 bonded balance must match pre and post-fix"
        );
        assertEq(
            trustBonding.userBondedBalanceAtEpochEnd(USER1, 0),
            user1AtEpoch0PreBug,
            "user 1 bonded balance must match pre and post-fix"
        );
        assertEq(
            trustBonding.userBondedBalanceAtEpochEnd(USER2, 0),
            user2AtEpoch0PreBug,
            "user 2 bonded balance must match pre and post-fix"
        );

        // Make sure eligible rewards match pre-upgrade values
        assertEq(
            user0EligibleRewardsPreUpgrade,
            trustBonding.userEligibleRewardsForEpoch(USER0, 0),
            "user 0 eligible rewards view must match pre and post-fix"
        );

        // (c) Claim rewards for USER1 should now succeed
        vm.startPrank(USER1);
        uint256 user1BalanceBefore = address(USER1).balance;
        trustBonding.claimRewards(USER1);
        assertEq(
            address(USER1).balance,
            user1BalanceBefore + trustBonding.userEligibleRewardsForEpoch(USER1, 0),
            "User 1 balance must increase by eligible rewards amount"
        );
        assertEq(
            trustBonding.userEligibleRewardsForEpoch(USER1, 0),
            trustBonding.userClaimedRewardsForEpoch(USER1, 0),
            "User 1 claimed rewards must match eligible rewards"
        );
        vm.stopPrank();

        // (d) Make sure no double claims are possible
        vm.startPrank(USER1);
        vm.expectRevert(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector);
        trustBonding.claimRewards(USER1);
        vm.stopPrank();

        // ----------------------------------------------------------
        // 4. EXTRA: drive a new checkpoint and let USER2 interact
        // ----------------------------------------------------------

        // Have USER2 mint some WTRUST via WrappedTrust and deposit into TrustBonding
        vm.startPrank(USER2);
        WrappedTrust wtrust = WrappedTrust(payable(WRAPPED_TRUST));

        // Deposit 1 TRUST --> receive 1 WTRUST
        wtrust.deposit{ value: 1 ether }();

        // Approve TrustBonding to pull WTRUST
        wtrust.approve(TRUST_BONDING_PROXY, type(uint256).max);

        vm.roll(BASE_POST_UPGRADE_BLOCK); // make sure we are using Base L2 block - not Intuition L3 block

        // Deposit into bonding (this should internally update VotingEscrow checkpoints)
        trustBonding.deposit_for(USER2, 1 ether);

        // USER2 should also be able to claim without hitting the old panic error
        uint256 user2BalanceBefore = address(USER2).balance;
        trustBonding.claimRewards(USER2);
        assertEq(
            address(USER2).balance,
            user2BalanceBefore + trustBonding.userEligibleRewardsForEpoch(USER2, 0),
            "User 2 balance must increase by eligible rewards amount"
        );
        assertEq(
            trustBonding.userEligibleRewardsForEpoch(USER2, 0),
            trustBonding.userClaimedRewardsForEpoch(USER2, 0),
            "User 2 claimed rewards must match eligible rewards"
        );
        vm.stopPrank();
    }
}
