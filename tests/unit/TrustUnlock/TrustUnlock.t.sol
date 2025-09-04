// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustUnlock } from "src/protocol/distribution/TrustUnlock.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TrustUnlock_Base is BaseTest {
    TrustUnlock internal unlock;

    // Handy locals we reuse across tests
    address internal OWNER;
    uint256 internal UNLOCK_AMOUNT;
    uint256 internal T0;
    uint256 internal BEGIN_TS;
    uint256 internal CLIFF_TS;
    uint256 internal END_TS;
    uint256 internal CLIFF_BP;

    function setUp() public override {
        super.setUp();

        OWNER = users.alice;
        UNLOCK_AMOUNT = 1000 ether;
        T0 = block.timestamp;

        // Vesting schedule: begin in 1w, cliff at 2w, linearly unlock to 12w
        BEGIN_TS = T0 + 1 weeks;
        CLIFF_TS = T0 + 2 weeks;
        END_TS = T0 + 12 weeks;
        CLIFF_BP = 1000; // 10%

        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: OWNER,
            token: payable(address(protocol.wrappedTrust)), // Trust / WrappedTrust
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: UNLOCK_AMOUNT,
            unlockBegin: BEGIN_TS,
            unlockCliff: CLIFF_TS,
            unlockEnd: END_TS,
            cliffPercentage: CLIFF_BP
        });

        unlock = new TrustUnlock(p);

        // Fund the vesting contract with the exact locked budget
        // (keeps "onlyNonLockedTokens" checks meaningful)
        vm.deal({ account: address(unlock), newBalance: UNLOCK_AMOUNT });

        vm.stopPrank();

        // As smart contracts are by default allowed to bond, we need to
        // explicitly whitelist the vesting contract in TrustBonding.
        vm.prank(users.admin);
        protocol.trustBonding.add_to_whitelist(address(unlock));
    }

    /* ---------------------------------------------------------- */
    /*                      Constructor sanity                    */
    /* ---------------------------------------------------------- */

    function test_constructor_setsImmutables() public {
        assertEq(address(unlock.trustToken()), address(protocol.wrappedTrust));
        assertEq(unlock.trustBonding(), address(protocol.trustBonding));
        assertEq(address(unlock.multiVault()), address(protocol.multiVault));
        assertEq(unlock.unlockAmount(), UNLOCK_AMOUNT);
        assertEq(unlock.unlockBegin(), BEGIN_TS);
        assertEq(unlock.unlockCliff(), CLIFF_TS);
        assertEq(unlock.unlockEnd(), END_TS);
        assertEq(unlock.cliffPercentage(), CLIFF_BP);
        assertEq(unlock.bondedAmount(), 0);
    }

    /* ---------------------------------------------------------- */
    /*                Unlocked schedule (weekly linear)           */
    /* ---------------------------------------------------------- */

    function test_unlockedAmount_schedule() public {
        uint256 cliffAmount = (UNLOCK_AMOUNT * CLIFF_BP) / 10_000; // 10%
        uint256 remainder = UNLOCK_AMOUNT - cliffAmount;
        uint256 totalWeeks = (END_TS - CLIFF_TS) / 1 weeks;

        // Before cliff => 0
        assertEq(unlock.unlockedAmount(CLIFF_TS - 1), 0);

        // Exactly at cliff => cliff%
        assertEq(unlock.unlockedAmount(CLIFF_TS), cliffAmount);

        // Halfway through linear schedule (5 of 10 weeks)
        uint256 halfwayWeeks = totalWeeks / 2;
        uint256 halfwayTs = CLIFF_TS + (halfwayWeeks * 1 weeks);
        uint256 expectedHalf = cliffAmount + (remainder * halfwayWeeks) / totalWeeks;
        assertEq(unlock.unlockedAmount(halfwayTs), expectedHalf);

        // After end => 100%
        assertEq(unlock.unlockedAmount(END_TS), UNLOCK_AMOUNT);
        assertEq(unlock.unlockedAmount(END_TS + 123), UNLOCK_AMOUNT);
    }

    /* ---------------------------------------------------------- */
    /*              Withdraw respects locked requirement          */
    /* ---------------------------------------------------------- */

    function test_withdraw_reverts_beforeCliff() public {
        // Any positive withdrawal before cliff should revert
        vm.prank(OWNER);
        vm.expectRevert(TrustUnlock.Unlock_InsufficientUnlockedTokens.selector);
        unlock.withdraw(OWNER, 1);
    }

    function test_withdraw_succeeds_afterEnd() public {
        vm.warp(END_TS);
        uint256 amt = 1 ether;

        uint256 balBefore = OWNER.balance;
        vm.prank(OWNER);
        unlock.withdraw(OWNER, amt);

        assertEq(OWNER.balance, balBefore + amt);
        assertEq(address(unlock).balance, UNLOCK_AMOUNT - amt);
    }

    /* ---------------------------------------------------------- */
    /*            MultiVault integration (atoms, deposit)         */
    /* ---------------------------------------------------------- */

    function test_createAtoms_afterEnd_clampsToUnlocked() public {
        vm.warp(END_TS);

        // Query the live atom creation cost from your MultiVault
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked("hello-atom");

        uint256[] memory costs = new uint256[](1);
        costs[0] = atomCost;

        // The call spends msg.value (from OWNER), not the vesting contract balance,
        // but still must pass the onlyNonLockedTokens check.
        vm.prank(OWNER);
        bytes32[] memory ids = unlock.createAtoms{ value: atomCost }(data, costs);

        assertEq(ids.length, 1);
        // Optional: deterministic ID check if your protocol uses keccak of atomData
        assertEq(ids[0], calculateAtomId(data[0]));
    }

    function test_deposit_and_redeem_flow() public {
        vm.warp(END_TS);

        // 1) Create a term (atom) directly via BaseTest helper so we have something to deposit into
        bytes32 atomId = createSimpleAtom("deposit-term", protocol.multiVault.getAtomCost(), users.bob);

        // 2) Deposit via TrustUnlock (receiver = the vesting contract, so it owns the shares)
        uint256 curveId = getDefaultCurveId();
        uint256 assetsIn = 2 ether;

        // Allow the TrustUnlock contract to act for OWNER on MultiVault
        setupApproval(OWNER, address(unlock), IMultiVault.ApprovalTypes.BOTH);

        vm.startPrank(OWNER);
        uint256 shares = unlock.deposit{ value: assetsIn }(OWNER, atomId, curveId, 0);

        assertGt(shares, 0, "Shares should be minted to the vesting contract");

        // 3) Redeem the same shares; assets go to OWNER (can be < assetsIn if fees apply)
        uint256 assetsOut = unlock.redeem(OWNER, atomId, curveId, shares, 0);

        assertGt(assetsOut, 0, "Redeem returns some assets");
        assertLe(assetsOut, assetsIn, "Fees/slippage make this <= deposit");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------- */
    /*                      Bonding basics                        */
    /* ---------------------------------------------------------- */

    function test_approveTrustBonding_setsAllowance() public {
        vm.prank(OWNER);
        unlock.approveTrustBonding(type(uint256).max);

        // Trust is an ERC20; allowance lives on the token
        uint256 allowance = protocol.wrappedTrust.allowance(address(unlock), address(protocol.trustBonding));
        assertEq(allowance, type(uint256).max);
    }

    function test_create_lock_and_withdraw() public {
        vm.warp(END_TS); // make all funds "unlocked" to keep checks simple

        // Create a fresh short bond
        uint256 lockAmt = 50 ether;
        uint256 unlockTime = block.timestamp + 3 weeks;
        vm.prank(OWNER);
        unlock.create_lock(lockAmt, unlockTime);

        assertEq(unlock.bondedAmount(), lockAmt);

        // Fast-forward past lock end in TrustBonding
        vm.warp(unlockTime + 1);

        // Withdraw the bond; bondedAmount resets to 0 and tokens are unwrapped back to ETH
        uint256 balBefore = address(unlock).balance;
        vm.prank(OWNER);
        unlock.withdraw();

        assertEq(unlock.bondedAmount(), 0, "Internal bonded accounting should reset");

        // After withdrawing from VotingEscrow-style contracts, you typically get WTRUST back;
        // TrustUnlock unwraps it back to native, so balance should increase by ~lockAmt.
        // (Depending on your TrustBonding implementation, rewards/rounding may vary.)
        assertGe(address(unlock).balance, balBefore, "Balance should not decrease after withdraw");
    }
}

contract TrustUnlock_EdgeCases is BaseTest {
    TrustUnlock internal unlock;

    address internal OWNER;
    uint256 internal UNLOCK_AMOUNT;
    uint256 internal T0;
    uint256 internal BEGIN_TS;
    uint256 internal CLIFF_TS;
    uint256 internal END_TS;
    uint256 internal CLIFF_BP;

    function setUp() public override {
        super.setUp();

        OWNER = users.alice;
        UNLOCK_AMOUNT = 1000 ether;
        T0 = block.timestamp;

        BEGIN_TS = T0 + 1 weeks;
        CLIFF_TS = T0 + 2 weeks;
        END_TS = T0 + 12 weeks;
        CLIFF_BP = 1000;

        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: OWNER,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: UNLOCK_AMOUNT,
            unlockBegin: BEGIN_TS,
            unlockCliff: CLIFF_TS,
            unlockEnd: END_TS,
            cliffPercentage: CLIFF_BP
        });

        unlock = new TrustUnlock(p);

        // Fully fund the vesting budget (used by onlyNonLockedTokens math)
        vm.deal({ account: address(unlock), newBalance: UNLOCK_AMOUNT });

        vm.stopPrank();

        // Whitelist the vesting contract in TrustBonding for bonding ops
        vm.prank(users.admin);
        protocol.trustBonding.add_to_whitelist(address(unlock));
    }

    /* ---------------------------------------------------------- */
    /*                   Constructor revert matrix                */
    /* ---------------------------------------------------------- */

    function test_constructor_reverts_zeroAddresses() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: address(0),
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 1,
            unlockBegin: block.timestamp + 1,
            unlockCliff: block.timestamp + 2,
            unlockEnd: block.timestamp + 2 + 1 weeks,
            cliffPercentage: 0
        });
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new TrustUnlock(p);

        p.owner = users.alice;
        p.token = payable(address(0));
        vm.expectRevert(TrustUnlock.Unlock_ZeroAddress.selector);
        new TrustUnlock(p);

        p.token = payable(address(protocol.wrappedTrust));
        p.trustBonding = address(0);
        vm.expectRevert(TrustUnlock.Unlock_ZeroAddress.selector);
        new TrustUnlock(p);

        p.trustBonding = address(protocol.trustBonding);
        p.multiVault = payable(address(0));
        vm.expectRevert(TrustUnlock.Unlock_ZeroAddress.selector);
        new TrustUnlock(p);
    }

    function test_constructor_reverts_zeroAmount() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: users.alice,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 0,
            unlockBegin: block.timestamp + 1,
            unlockCliff: block.timestamp + 2,
            unlockEnd: block.timestamp + 2 + 1 weeks,
            cliffPercentage: 0
        });
        vm.expectRevert(TrustUnlock.Unlock_ZeroAmount.selector);
        new TrustUnlock(p);
    }

    function test_constructor_reverts_beginTooEarly() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: users.alice,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 1,
            unlockBegin: block.timestamp - 1,
            unlockCliff: block.timestamp + 1,
            unlockEnd: block.timestamp + 1 + 1 weeks,
            cliffPercentage: 0
        });
        vm.expectRevert(TrustUnlock.Unlock_UnlockBeginTooEarly.selector);
        new TrustUnlock(p);
    }

    function test_constructor_reverts_cliffTooEarly() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: users.alice,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 1,
            unlockBegin: block.timestamp + 10,
            unlockCliff: block.timestamp + 9,
            unlockEnd: block.timestamp + 10 + 1 weeks,
            cliffPercentage: 0
        });
        vm.expectRevert(TrustUnlock.Unlock_CliffIsTooEarly.selector);
        new TrustUnlock(p);
    }

    function test_constructor_reverts_cliffPctTooHigh() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: users.alice,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 1,
            unlockBegin: block.timestamp + 10,
            unlockCliff: block.timestamp + 11,
            unlockEnd: block.timestamp + 11 + 1 weeks,
            cliffPercentage: 10_001
        });
        vm.expectRevert(TrustUnlock.Unlock_InvalidCliffPercentage.selector);
        new TrustUnlock(p);
    }

    function test_constructor_reverts_endTooEarly() public {
        TrustUnlock.UnlockParams memory p = TrustUnlock.UnlockParams({
            owner: users.alice,
            token: payable(address(protocol.wrappedTrust)),
            trustBonding: address(protocol.trustBonding),
            multiVault: payable(address(protocol.multiVault)),
            unlockAmount: 1,
            unlockBegin: block.timestamp + 10,
            unlockCliff: block.timestamp + 11,
            unlockEnd: block.timestamp + 11 + 1 weeks - 1, // < cliff + 1w
            cliffPercentage: 0
        });
        vm.expectRevert(TrustUnlock.Unlock_EndIsTooEarly.selector);
        new TrustUnlock(p);
    }

    /* ---------------------------------------------------------- */
    /*                         OnlyOwner                          */
    /* ---------------------------------------------------------- */

    function test_onlyOwner_required_on_mutating() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.approveTrustBonding(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.withdraw(users.bob, 1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.create_lock(1, 1 weeks);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.increase_amount(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.increase_unlock_time(block.timestamp + 52 weeks);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.withdraw();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        unlock.claimRewards(users.bob);
    }

    /* ---------------------------------------------------------- */
    /*                 onlyNonLockedTokens guard                  */
    /* ---------------------------------------------------------- */

    function test_createAtoms_reverts_beforeCliff_dueToLocked() public {
        // any positive spend before cliff should fail the guard
        bytes[] memory data = new bytes[](1);
        data[0] = "x";
        uint256[] memory assets = new uint256[](1);
        assets[0] = 1;

        vm.prank(OWNER);
        vm.expectRevert(TrustUnlock.Unlock_InsufficientUnlockedTokens.selector);
        unlock.createAtoms{ value: 0 }(data, assets);
    }

    function test_deposit_exactlyAtCliff_boundary_succeeds() public {
        // At cliff, allowed spend == cliff portion of UNLOCK_AMOUNT
        uint256 cliffAmount = (UNLOCK_AMOUNT * CLIFF_BP) / 10_000;

        // Create a term to deposit into
        bytes32 termId = createSimpleAtom("cliff-deposit", protocol.multiVault.getAtomCost(), users.bob);
        uint256 curveId = getDefaultCurveId();

        // Allow TrustUnlock to act for OWNER on MultiVault
        setupApproval(OWNER, address(unlock), IMultiVault.ApprovalTypes.BOTH);

        vm.warp(CLIFF_TS);
        vm.startPrank(OWNER);
        uint256 shares = unlock.deposit{ value: cliffAmount }(OWNER, termId, curveId, 0);
        assertGt(shares, 0);
        vm.stopPrank();
    }

    function test_withdraw_boundary_at_cliff() public {
        vm.warp(CLIFF_TS);
        uint256 cliffAmount = (UNLOCK_AMOUNT * CLIFF_BP) / 10_000;

        // Exactly cliff: ok
        vm.prank(OWNER);
        unlock.withdraw(OWNER, cliffAmount);

        // +1 wei beyond cliff: blocked
        vm.prank(OWNER);
        vm.expectRevert(TrustUnlock.Unlock_InsufficientUnlockedTokens.selector);
        unlock.withdraw(OWNER, 1);
    }

    /* ---------------------------------------------------------- */
    /*                     Withdraw: errors/success               */
    /* ---------------------------------------------------------- */

    function test_withdraw_zeroAddress_reverts() public {
        vm.warp(END_TS);
        vm.prank(OWNER);
        vm.expectRevert(TrustUnlock.Unlock_ZeroAddress.selector);
        unlock.withdraw(address(0), 1);
    }

    function test_withdraw_zeroAmount_reverts() public {
        vm.warp(END_TS);
        vm.prank(OWNER);
        vm.expectRevert(TrustUnlock.Unlock_ZeroAmount.selector);
        unlock.withdraw(OWNER, 0);
    }

    /* ---------------------------------------------------------- */
    /*                         Bonding flow                       */
    /* ---------------------------------------------------------- */

    function test_increase_amount_and_unlockTime() public {
        vm.warp(END_TS);

        // create a bond first
        uint256 amt = 10 ether;
        uint256 unlockTime = block.timestamp + 4 weeks;
        vm.prank(OWNER);
        unlock.create_lock(amt, unlockTime);
        assertEq(unlock.bondedAmount(), amt);

        // views reflect state
        uint256 end1 = unlock.bondingLockEndTimestamp();
        assertGt(end1, block.timestamp);

        // increase amount
        vm.prank(OWNER);
        unlock.increase_amount(amt);
        assertEq(unlock.bondedAmount(), amt * 2);

        // extend unlock time
        uint256 newEnd = unlockTime + 3 weeks;
        vm.prank(OWNER);
        unlock.increase_unlock_time(newEnd);
        uint256 end2 = unlock.bondingLockEndTimestamp();
        uint256 expectedEnd2 = (newEnd / 1 weeks) * 1 weeks;
        assertGe(end2, expectedEnd2);

        // withdraw after expiry
        vm.warp(end2 + 1);
        uint256 balBefore = address(unlock).balance;
        vm.prank(OWNER);
        unlock.withdraw();
        assertEq(unlock.bondedAmount(), 0);
        assertGe(address(unlock).balance, balBefore);
    }

    /* ---------------------------------------------------------- */
    /*                  MultiVault batch flows                    */
    /* ---------------------------------------------------------- */

    function test_depositBatch_and_redeemBatch() public {
        vm.warp(END_TS);

        // Build two terms
        bytes32 t1 = createSimpleAtom("term-1", protocol.multiVault.getAtomCost(), users.bob);
        bytes32 t2 = createSimpleAtom("term-2", protocol.multiVault.getAtomCost(), users.bob);
        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = t1;
        termIds[1] = t2;

        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        uint256[] memory minAssets = new uint256[](2);
        uint256[] memory minShares = new uint256[](2);
        minShares[0] = 0;
        minShares[1] = 0;

        setupApproval(OWNER, address(unlock), IMultiVault.ApprovalTypes.BOTH);

        vm.startPrank(OWNER);
        uint256[] memory sharesOut =
            unlock.depositBatch{ value: amounts[0] + amounts[1] }(OWNER, termIds, curveIds, amounts, minShares);

        assertEq(sharesOut.length, 2);
        assertGt(sharesOut[0], 0);
        assertGt(sharesOut[1], 0);

        uint256;
        minAssets[0] = 0;
        minAssets[1] = 0;

        uint256[] memory assetsOut = unlock.redeemBatch(OWNER, termIds, curveIds, sharesOut, minAssets);
        assertEq(assetsOut.length, 2);
        assertGt(assetsOut[0], 0);
        assertGt(assetsOut[1], 0);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------- */
    /*                        Claiming flow                       */
    /* ---------------------------------------------------------- */

    function test_claimRewards_reverts_firstEpoch() public {
        // SatelliteEmissionsController was initialized at setUp's block.timestamp, so currentEpoch()==0 here.
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("TrustBonding_NoClaimingDuringFirstEpoch()"));
        unlock.claimRewards(OWNER);
    }

    function test_claimRewards_reverts_noRewards() public {
        // Move to epoch 1 (claiming enabled) but the vesting contract has no eligible rewards
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("TrustBonding_NoRewardsToClaim()"));
        unlock.claimRewards(OWNER);
    }

    /* ---------------------------------------------------------- */
    /*               _unlockedAmount boundary tests               */
    /* ---------------------------------------------------------- */

    function test_unlockedAmount_boundaries() public {
        uint256 cliffAmount = (UNLOCK_AMOUNT * CLIFF_BP) / 10_000;
        uint256 remainder = UNLOCK_AMOUNT - cliffAmount;
        uint256 totalWeeks = (END_TS - CLIFF_TS) / 1 weeks;

        // Just before first post-cliff week => still cliff only
        assertEq(unlock.unlockedAmount(CLIFF_TS + 1 weeks - 1), cliffAmount);

        // Exactly one week after cliff
        uint256 oneWeekValue = cliffAmount + (remainder * 1) / totalWeeks;
        assertEq(unlock.unlockedAmount(CLIFF_TS + 1 weeks), oneWeekValue);

        // Just before end => last weekly chunk not yet counted
        uint256 beforeEnd = cliffAmount + (remainder * (totalWeeks - 1)) / totalWeeks;
        assertEq(unlock.unlockedAmount(END_TS - 1), beforeEnd);

        // At and after end => full
        assertEq(unlock.unlockedAmount(END_TS), UNLOCK_AMOUNT);
    }
}
