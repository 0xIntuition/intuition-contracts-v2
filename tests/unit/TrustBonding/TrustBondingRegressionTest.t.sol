// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TrustBondingUpgradeRegressionTest is Test {
    // --- Chain & contract constants ---
    uint256 internal constant FORK_BLOCK = 115_285;
    uint256 internal constant BASE_POST_UPGRADE_BLOCK = 38_389_704;

    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant PROXY_ADMIN = 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62;
    address internal constant WRAPPED_TRUST = 0x81cFb09cb44f7184Ad934C09F82000701A4bF672;

    // Sample users you gave
    address internal constant USER1 = 0xeD76B9f22780F9aA8Cf1a096c71bF8A5fE16290d;
    address internal constant USER2 = 0xEe34cEd4608C238be371D8c519d56F8D7190A445;

    function setUp() public {
        // Fork Intuition L3 at the block where the bug still existed
        vm.createSelectFork("intuition", FORK_BLOCK);

        // Make sure sample users have gas & ETH for WrappedTrust.deposit
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
    }

    function testUpgradeFixesVotingEscrowPanic() public {
        TrustBonding trustBonding = TrustBonding(TRUST_BONDING_PROXY);

        // ----------------------------------------------------------
        // 1. PRE-UPGRADE: reproduce the failing behavior
        // ----------------------------------------------------------

        // (a) "supply" path used to revert with a Panic
        // Replace this with the exact function that blew up before the fix.
        // If you know it's division-by-zero, you can use:
        // vm.expectRevert(stdError.divisionError);
        vm.expectRevert(); // generic expect; tighten once you know the exact panic
        trustBonding.totalBondedBalanceAtEpochEnd(0);

        // (b) "balanceOf for user" path used to revert with a Panic
        // Again, replace with your real read function (if different).
        // vm.expectRevert();
        // Example for a per-user endpoint:
        // trustBonding.userBondedBalanceAtEpochEnd(USER1, 0);

        // (c) claimRewards used to revert via the same underlying bug
        vm.startPrank(USER1);
        vm.expectRevert(); // or stdError.divisionError if it is indeed a Panic
        trustBonding.claimRewards(USER1);
        vm.stopPrank();

        // ----------------------------------------------------------
        // 2. UPGRADE: deploy new implementation & upgrade proxy
        // ----------------------------------------------------------

        // Deploy the new TrustBonding implementation that includes your
        // fixed VotingEscrow logic (this uses the local code under test).
        TrustBonding newImpl = new TrustBonding();

        vm.startPrank(TIMELOCK);
        ProxyAdmin(PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(TRUST_BONDING_PROXY)),
                address(newImpl),
                bytes("") // no initializer call
            );
        vm.stopPrank();

        // Re-bind after upgrade (same address, new code)
        trustBonding = TrustBonding(TRUST_BONDING_PROXY);

        // ----------------------------------------------------------
        // 3. POST-UPGRADE: the same calls must no longer revert
        // ----------------------------------------------------------

        // (a) Global supply at epoch end should now be readable
        uint256 totalAtEpoch0 = trustBonding.totalBondedBalanceAtEpochEnd(0);
        // You can assert basic sanity if you want:
        // assertGt(totalAtEpoch0, 0, "expected some bonded supply at epoch 0");

        // (b) User balance at epoch end must no longer revert either
        uint256 user1AtEpoch0 = trustBonding.userBondedBalanceAtEpochEnd(USER1, 0);
        // It can be zero, but must not revert
        // assertGe(user1AtEpoch0, 0); // implicit by type

        // (c) Claim rewards for USER1 should now succeed (even if rewards are 0)
        vm.startPrank(USER1);
        trustBonding.claimRewards(USER1);
        vm.stopPrank();

        // ----------------------------------------------------------
        // 4. EXTRA: drive a new checkpoint and let USER2 interact
        // ----------------------------------------------------------

        // Have USER2 mint some WTRUST via WrappedTrust and deposit into TrustBonding
        vm.startPrank(USER2);
        WrappedTrust wtrust = WrappedTrust(payable(WRAPPED_TRUST));

        // Deposit 1 ETH → receive 1 WTRUST equivalent (assuming 1:1)
        wtrust.deposit{ value: 1 ether }();

        // Approve TrustBonding to pull WTRUST
        wtrust.approve(TRUST_BONDING_PROXY, type(uint256).max);

        vm.roll(BASE_POST_UPGRADE_BLOCK); // make sure we are using Base L2 block - not Intuition L3 block

        // Deposit into bonding (this should internally update VotingEscrow checkpoints)
        trustBonding.deposit_for(USER2, 1 ether);

        // Optionally fast-forward some time / blocks if your epoch logic depends on it
        // vm.warp(block.timestamp + 7 days);

        // USER2 should also be able to claim without hitting the old panic
        trustBonding.claimRewards(USER2);
        vm.stopPrank();

        // Optional: assert voting power / supply queries for USER2 don't revert
        uint256 user2Epoch0 = trustBonding.userBondedBalanceAtEpochEnd(USER2, 0);
        // It's fine if this is 0 (depending on how epoch 0 is defined),
        // but the important part is that the call succeeded.
        user2Epoch0; // silence unused warning
    }
}
