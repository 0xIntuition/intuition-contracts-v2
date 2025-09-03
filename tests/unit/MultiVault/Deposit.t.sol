// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

contract DepositTest is BaseTest {
    uint256 internal CURVE_ID; // Default linear curve ID
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        // Ensure the bonding curve registry is set up
        CURVE_ID = getDefaultCurveId();
    }

    function test_deposit_SingleAtom_Success() public {
        bytes32 atomId = createSimpleAtom("Deposit test atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 10e18;
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, depositAmount, 1e4);

        assertTrue(shares > 0, "Should receive some shares");

        uint256 vaultBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(vaultBalance, shares, "Vault balance should match shares received");
    }

    function test_deposit_MultipleDeposits_Success() public {
        bytes32 atomId = createSimpleAtom("Multi deposit atom", ATOM_COST[0], users.alice);

        uint256 firstShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 50e18, 1e4);
        uint256 secondShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 30e18, 1e4);

        assertTrue(firstShares > 0, "First deposit should receive shares");
        assertTrue(secondShares > 0, "Second deposit should receive shares");

        uint256 totalVaultBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(totalVaultBalance, firstShares + secondShares, "Total balance should equal sum of deposits");
    }

    function test_deposit_DifferentReceivers_Success() public {
        bytes32 atomId = createSimpleAtom("Different receivers atom", ATOM_COST[0], users.alice);

        setupApproval(users.bob, users.alice, IMultiVault.ApprovalTypes.BOTH);

        uint256 shares = makeDeposit(users.alice, users.bob, atomId, CURVE_ID, 10e18, 1e4);

        uint256 bobBalance = protocol.multiVault.getShares(users.bob, atomId, CURVE_ID);
        assertEq(bobBalance, shares, "Bob should receive the shares");

        uint256 aliceBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(aliceBalance, 0, "Alice should not receive shares");
    }

    function test_deposit_ToTriple_Success() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("Subject", "Predicate", "Object", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, tripleId, CURVE_ID, 2000e18, 1e4);

        assertTrue(shares > 0, "Should receive shares for triple deposit");

        uint256 vaultBalance = protocol.multiVault.getShares(users.alice, tripleId, CURVE_ID);
        assertEq(vaultBalance, shares, "Triple vault balance should match shares");
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_deposit_InsufficientAssets_Revert() public {
        bytes32 atomId = createSimpleAtom("Insufficient deposit atom", ATOM_COST[0], users.alice);

        resetPrank(users.alice);
        vm.expectRevert();
        protocol.multiVault.deposit{ value: 0 }(users.alice, atomId, CURVE_ID, 0);
    }

    function test_deposit_NonExistentTerm_Revert() public {
        bytes32 nonExistentId = keccak256("non-existent");
        uint256 depositAmount = 1000e18;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_TermDoesNotExist.selector);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, nonExistentId, CURVE_ID, 0);
    }

    function test_deposit_MinSharesToReceive_Revert() public {
        bytes32 atomId = createSimpleAtom("Min shares atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 100e18;
        uint256 unreasonableMinShares = 10_000_000e18; // Way too high

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, CURVE_ID, unreasonableMinShares);
    }
}
