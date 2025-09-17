// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { WrappedTrust } from "src/WrappedTrust.sol";

contract WrappedTrustTest is Test {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    WrappedTrust internal wtr;

    struct Users {
        address admin;
        address alice;
        address bob;
        address charlie;
    }

    Users internal users;

    uint256 internal constant STARTING_ETH = 100 ether;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public {
        // zero gas price so balance math is exact on withdraw assertions
        vm.txGasPrice(0);

        users.admin = makeAddr("admin");
        users.alice = makeAddr("alice");
        users.bob = makeAddr("bob");
        users.charlie = makeAddr("charlie");

        vm.deal(users.admin, STARTING_ETH);
        vm.deal(users.alice, STARTING_ETH);
        vm.deal(users.bob, STARTING_ETH);
        vm.deal(users.charlie, STARTING_ETH);

        wtr = new WrappedTrust();
    }

    /* =================================================== */
    /*                     METADATA                        */
    /* =================================================== */

    function test_metadata_Getters() public {
        assertEq(wtr.name(), "Wrapped Trust");
        assertEq(wtr.symbol(), "WTRUST");
        assertEq(wtr.decimals(), 18);
    }

    /* =================================================== */
    /*                      DEPOSIT                         */
    /* =================================================== */

    function test_deposit_viaFunction_Success() public {
        uint256 amt = 5 ether;

        uint256 supplyBefore = wtr.totalSupply();
        uint256 balBefore = wtr.balanceOf(users.alice);

        vm.prank(users.alice);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Deposit(users.alice, amt);
        wtr.deposit{ value: amt }();

        assertEq(wtr.totalSupply(), supplyBefore + amt);
        assertEq(wtr.balanceOf(users.alice), balBefore + amt);
        assertEq(address(wtr).balance, supplyBefore + amt);
    }

    function test_deposit_viaReceive_Success() public {
        uint256 amt = 1.25 ether;

        uint256 supplyBefore = wtr.totalSupply();
        uint256 balBefore = wtr.balanceOf(users.bob);

        vm.prank(users.bob);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Deposit(users.bob, amt);
        (bool ok,) = address(wtr).call{ value: amt }("");
        require(ok, "send failed");

        assertEq(wtr.totalSupply(), supplyBefore + amt);
        assertEq(wtr.balanceOf(users.bob), balBefore + amt);
    }

    /* =================================================== */
    /*                      WITHDRAW                        */
    /* =================================================== */

    function test_withdraw_Success() public {
        uint256 amt = 3 ether;

        // deposit first
        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        uint256 userBefore = users.alice.balance;
        uint256 supplyBefore = wtr.totalSupply();

        vm.prank(users.alice);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Withdrawal(users.alice, amt);
        wtr.withdraw(amt);

        // exact equality since gas price is 0
        assertEq(users.alice.balance, userBefore + amt);
        assertEq(wtr.totalSupply(), supplyBefore - amt);
        assertEq(wtr.balanceOf(users.alice), 0);
        assertEq(address(wtr).balance, supplyBefore - amt);
    }

    function test_withdraw_Revert_Insufficient() public {
        // alice has 0 wrapped, tries to withdraw
        vm.prank(users.alice);
        vm.expectRevert(); // no reason string in contract
        wtr.withdraw(1);
    }

    /* =================================================== */
    /*                      APPROVE                         */
    /* =================================================== */

    function test_approve_SetsAllowanceAndEmits() public {
        uint256 amt = 7 ether;

        vm.prank(users.alice);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Approval(users.alice, users.bob, amt);
        bool ok = wtr.approve(users.bob, amt);

        assertTrue(ok);
        assertEq(wtr.allowance(users.alice, users.bob), amt);

        // overwrite allowance
        vm.prank(users.alice);
        ok = wtr.approve(users.bob, amt + 1);
        assertTrue(ok);
        assertEq(wtr.allowance(users.alice, users.bob), amt + 1);
    }

    /* =================================================== */
    /*                      TRANSFER                        */
    /* =================================================== */

    function test_transfer_SelfToOther_Success() public {
        uint256 amt = 4 ether;

        // fund alice's wrapped
        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        uint256 aliceBefore = wtr.balanceOf(users.alice);
        uint256 bobBefore = wtr.balanceOf(users.bob);

        vm.prank(users.alice);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Transfer(users.alice, users.bob, amt);
        bool ok = wtr.transfer(users.bob, amt);

        assertTrue(ok);
        assertEq(wtr.balanceOf(users.alice), aliceBefore - amt);
        assertEq(wtr.balanceOf(users.bob), bobBefore + amt);
    }

    function test_transfer_Revert_InsufficientBalance() public {
        // alice has 0
        vm.prank(users.alice);
        vm.expectRevert();
        wtr.transfer(users.bob, 1);
    }

    function test_transfer_SelfTransfer_NoopButEmits() public {
        uint256 amt = 2 ether;

        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        uint256 before = wtr.balanceOf(users.alice);

        vm.prank(users.alice);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Transfer(users.alice, users.alice, amt);
        wtr.transfer(users.alice, amt);

        assertEq(wtr.balanceOf(users.alice), before); // net zero
    }

    /* =================================================== */
    /*                   TRANSFER FROM                      */
    /* =================================================== */

    function test_transferFrom_BySpender_ConsumesAllowance() public {
        uint256 amt = 6 ether;

        // alice deposits, approves bob
        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        vm.prank(users.alice);
        wtr.approve(users.bob, amt);

        // bob spends most of it
        vm.prank(users.bob);
        vm.expectEmit(address(wtr));
        emit WrappedTrust.Transfer(users.alice, users.charlie, amt - 1);
        wtr.transferFrom(users.alice, users.charlie, amt - 1);

        assertEq(wtr.allowance(users.alice, users.bob), 1);
        assertEq(wtr.balanceOf(users.charlie), amt - 1);

        // bob spends the rest; allowance hits 0
        vm.prank(users.bob);
        wtr.transferFrom(users.alice, users.charlie, 1);
        assertEq(wtr.allowance(users.alice, users.bob), 0);
        assertEq(wtr.balanceOf(users.charlie), amt);
        assertEq(wtr.balanceOf(users.alice), 0);
    }

    function test_transferFrom_WithMaxAllowance_DoesNotDecrement() public {
        uint256 amt = 3.3 ether;

        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        vm.prank(users.alice);
        wtr.approve(users.bob, type(uint256).max);

        vm.prank(users.bob);
        wtr.transferFrom(users.alice, users.charlie, amt);

        assertEq(wtr.allowance(users.alice, users.bob), type(uint256).max); // unchanged
        assertEq(wtr.balanceOf(users.charlie), amt);
    }

    function test_transferFrom_Revert_InsufficientAllowance() public {
        uint256 amt = 5 ether;

        vm.prank(users.alice);
        wtr.deposit{ value: amt }();

        vm.prank(users.alice);
        wtr.approve(users.bob, 1 ether);

        vm.prank(users.bob);
        vm.expectRevert();
        wtr.transferFrom(users.alice, users.charlie, 2 ether);
    }

    function test_transferFrom_Revert_InsufficientFromBalance() public {
        // alice approves bob without depositing
        vm.prank(users.alice);
        wtr.approve(users.bob, 10 ether);

        vm.prank(users.bob);
        vm.expectRevert(); // balanceOf[from] >= amount check
        wtr.transferFrom(users.alice, users.charlie, 1 ether);
    }

    /* =================================================== */
    /*                   TOTAL SUPPLY                       */
    /* =================================================== */

    function test_totalSupply_TracksContractEthBalance() public {
        uint256 a = 0.7 ether;
        uint256 b = 1.4 ether;

        vm.prank(users.alice);
        wtr.deposit{ value: a }();

        vm.prank(users.bob);
        wtr.deposit{ value: b }();

        assertEq(wtr.totalSupply(), a + b);
        assertEq(address(wtr).balance, a + b);

        vm.prank(users.bob);
        wtr.withdraw(b);

        assertEq(wtr.totalSupply(), a);
        assertEq(address(wtr).balance, a);
    }
}
