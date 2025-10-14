// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

contract UtilizationTest is BaseTest {
    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /*//////////////////////////////////////////////////////////////
                    ADD: first action in epoch (oldEpoch == 0)
    //////////////////////////////////////////////////////////////*/

    function test_utilization_Add_FirstAction_SetsTotalsAndLastActive() public {
        bytes32 atomId = createSimpleAtom("util-add-first", ATOM_COST[0], users.alice);

        uint256 epoch = protocol.multiVault.currentEpoch();

        // Baselines (atom creation may have already added some utilization)
        int256 baseSystem = protocol.multiVault.totalUtilization(epoch);
        int256 basePersonal = protocol.multiVault.personalUtilization(users.alice, epoch);

        uint256 amount = 3 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amount, 0);

        // Check deltas (add uses GROSS deposit amount, not net-of-fees)
        assertEq(
            protocol.multiVault.totalUtilization(epoch) - baseSystem,
            int256(amount),
            "System utilization delta should equal gross deposit"
        );
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epoch) - basePersonal,
            int256(amount),
            "Personal utilization delta should equal gross deposit"
        );
        assertEq(protocol.multiVault.lastActiveEpoch(users.alice), epoch, "lastActiveEpoch set to current epoch");
    }

    /*//////////////////////////////////////////////////////////////
                   ADD on behalf: receiver gets utilization
    //////////////////////////////////////////////////////////////*/

    function test_utilization_Add_OnBehalf_ReceiverGetsCredit() public {
        bytes32 atomId = createSimpleAtom("util-onbehalf", ATOM_COST[0], users.bob);

        // Allow Alice to deposit for Bob
        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT);

        uint256 epoch = protocol.multiVault.currentEpoch();

        // Baselines (bob already has creation baseline)
        int256 baseSys = protocol.multiVault.totalUtilization(epoch);
        int256 baseBob = protocol.multiVault.personalUtilization(users.bob, epoch);
        int256 baseAlice = protocol.multiVault.personalUtilization(users.alice, epoch);

        uint256 amount = 5 ether;
        makeDeposit(users.alice, users.bob, atomId, CURVE_ID, amount, 0);

        // Deltas
        assertEq(protocol.multiVault.totalUtilization(epoch) - baseSys, int256(amount));
        assertEq(protocol.multiVault.personalUtilization(users.bob, epoch) - baseBob, int256(amount));
        assertEq(protocol.multiVault.personalUtilization(users.alice, epoch) - baseAlice, int256(0));
        assertEq(protocol.multiVault.lastActiveEpoch(users.bob), epoch);
    }

    /*//////////////////////////////////////////////////////////////
                       ROLLOVER on next epoch (ADD)
    //////////////////////////////////////////////////////////////*/

    function test_utilization_Rollover_Deposit_CarriesForwardThenAdds() public {
        bytes32 atomId = createSimpleAtom("util-roll-add", ATOM_COST[0], users.alice);

        uint256 epochN = protocol.multiVault.currentEpoch();
        // Snapshot totals at end of epoch N before new deposit
        int256 sysN_before = protocol.multiVault.totalUtilization(epochN);
        int256 meN_before = protocol.multiVault.personalUtilization(users.alice, epochN);

        uint256 amountN = 7 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN, 0);

        // Deltas in epoch N (just the new deposit)
        assertEq(protocol.multiVault.totalUtilization(epochN) - sysN_before, int256(amountN));
        assertEq(protocol.multiVault.personalUtilization(users.alice, epochN) - meN_before, int256(amountN));

        // Warp to next epoch
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochN1 = protocol.multiVault.currentEpoch();
        assertTrue(epochN1 > epochN, "moved to next epoch");

        // Carry source is the FULL totals from N
        int256 sysN_total = protocol.multiVault.totalUtilization(epochN);
        int256 meN_total = protocol.multiVault.personalUtilization(users.alice, epochN);

        uint256 amountN1 = 2 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN1, 0);

        // First action in N+1 rolls over N totals, then adds new amount
        assertEq(protocol.multiVault.totalUtilization(epochN1), sysN_total + int256(amountN1), "system carry + add");
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epochN1),
            meN_total + int256(amountN1),
            "me carry + add"
        );

        assertEq(protocol.multiVault.lastActiveEpoch(users.alice), epochN1);
    }

    // /*//////////////////////////////////////////////////////////////
    //                    ROLLOVER on next epoch (REMOVE)
    // //////////////////////////////////////////////////////////////*/

    function test_utilization_Rollover_Redeem_CarriesForwardThenSubtracts() public {
        bytes32 atomId = createSimpleAtom("util-roll-rem", ATOM_COST[0], users.alice);

        uint256 epochN = protocol.multiVault.currentEpoch();
        uint256 amountN = 8 ether;
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN, 0);

        // Warp to next epoch
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochN1 = protocol.multiVault.currentEpoch();

        // Carry source is the FULL total from N (including creation baseline + deposit)
        int256 sysN_total = protocol.multiVault.totalUtilization(epochN);
        int256 meN_total = protocol.multiVault.personalUtilization(users.alice, epochN);

        // First action in N+1: redeem half
        uint256 toRedeem = shares / 2;

        // Raw assets (pre-fee) that utilization uses for removal; compute BEFORE redeem
        uint256 rawAssets = protocol.multiVault.convertToAssets(atomId, CURVE_ID, toRedeem);

        redeemShares(users.alice, users.alice, atomId, CURVE_ID, toRedeem, 0);

        // Expect carry – rawAssets
        assertEq(protocol.multiVault.totalUtilization(epochN1), sysN_total - int256(rawAssets), "system carry - raw");
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epochN1),
            meN_total - int256(rawAssets),
            "me carry - raw"
        );
        assertEq(protocol.multiVault.lastActiveEpoch(users.alice), epochN1);
    }

    /*//////////////////////////////////////////////////////////////
             Second action in the same new epoch: no double-carry
    //////////////////////////////////////////////////////////////*/
    function test_utilization_Rollover_NoDoubleCarryOnSecondAction() public {
        bytes32 atomId = createSimpleAtom("util-double-carry-guard", ATOM_COST[0], users.alice);

        uint256 epochN = protocol.multiVault.currentEpoch();
        uint256 amountN = 6 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountN, 0);

        // Move to epoch N+1
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochN1 = protocol.multiVault.currentEpoch();

        // First action in N+1: this triggers carry
        uint256 amountA = 1 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountA, 0);

        // Snapshot after first action in N+1
        int256 sysAfterFirst = protocol.multiVault.totalUtilization(epochN1);
        int256 meAfterFirst = protocol.multiVault.personalUtilization(users.alice, epochN1);

        // Second action in same epoch: should only add amountB (no carry again)
        uint256 amountB = 2 ether;
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, amountB, 0);

        assertEq(
            protocol.multiVault.totalUtilization(epochN1) - sysAfterFirst,
            int256(amountB),
            "second action should not recarry totals"
        );
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epochN1) - meAfterFirst,
            int256(amountB),
            "second action personal delta only"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  ROLLOVER (on behalf): copy then add
    //////////////////////////////////////////////////////////////*/
    function test_utilization_Rollover_OnBehalf_Deposit_CopiesPrevPersonalThenAdds() public {
        // Bob creates an atom and gets baseline utilization in epoch N
        bytes32 atomId = createSimpleAtom("util-roll-onbehalf", ATOM_COST[0], users.bob);

        uint256 epochN = protocol.multiVault.currentEpoch();

        // Snapshot Bob's total personal utilization in epoch N (includes creation baseline)
        int256 meN_total = protocol.multiVault.personalUtilization(users.bob, epochN);

        // Allow Alice to deposit on behalf of Bob for next epoch
        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT);

        // Move to epoch N+1 (no actions yet for Bob in N+1 -> personalUtilization[bob][N+1] == 0)
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epochN1 = protocol.multiVault.currentEpoch();
        assertTrue(epochN1 > epochN, "moved to next epoch");

        // Precondition: No carry yet for Bob in N+1 (branch guard hits: == 0)
        assertEq(
            protocol.multiVault.personalUtilization(users.bob, epochN1),
            int256(0),
            "Bob has no personal utilization yet in N+1"
        );

        // First action in N+1 is a deposit by Alice on behalf of Bob (triggers rollover for Bob)
        uint256 amountN1 = 1 ether;
        makeDeposit(users.alice, users.bob, atomId, CURVE_ID, amountN1, 0);

        // After rollover: Bob's N utilization is copied into N+1, then amountN1 is added
        assertEq(
            protocol.multiVault.personalUtilization(users.bob, epochN1),
            meN_total + int256(amountN1),
            "on-behalf deposit should copy prior epoch personal utilization, then add"
        );

        // Sanity: Alice shouldn't get personal credit for Bob's action
        assertEq(
            protocol.multiVault.personalUtilization(users.alice, epochN1),
            int256(0),
            "sender (Alice) gets no personal utilization for on-behalf deposit"
        );

        // And Bob's lastActiveEpoch is now the new epoch
        assertEq(protocol.multiVault.lastActiveEpoch(users.bob), epochN1, "lastActiveEpoch rolled to N+1");
    }
}
