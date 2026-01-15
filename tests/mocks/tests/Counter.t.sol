// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { Counter } from "../Counter.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract CounterTest is Test {
    Counter public counter;

    address public owner;
    address public nonOwner;

    event CountIncremented(uint256 newCount);
    event CountDecremented(uint256 newCount);
    event CountReset();

    error Counter_Underflow();
    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        owner = makeAddr("owner");
        nonOwner = makeAddr("nonOwner");

        counter = new Counter(owner);
    }

    function test_constructor_setsOwner() external view {
        assertEq(counter.owner(), owner);
    }

    function test_constructor_initialCountIsZero() external view {
        assertEq(counter.getCount(), 0);
    }

    function test_incrementCount_successful() external {
        vm.prank(owner);
        counter.incrementCount();

        assertEq(counter.getCount(), 1);
    }

    function test_incrementCount_emitsEvent() external {
        vm.expectEmit(true, true, true, true);
        emit CountIncremented(1);

        vm.prank(owner);
        counter.incrementCount();
    }

    function test_incrementCount_revertsOnNonOwner() external {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));

        vm.prank(nonOwner);
        counter.incrementCount();
    }

    function testFuzz_incrementCount_multipleIncrements(uint256 numberOfIncrements) external {
        numberOfIncrements = bound(numberOfIncrements, 1, 10_000);

        vm.startPrank(owner);
        for (uint256 i = 0; i < numberOfIncrements; i++) {
            counter.incrementCount();
        }
        vm.stopPrank();

        assertEq(counter.getCount(), numberOfIncrements);
    }

    function test_decrementCount_successful() external {
        vm.startPrank(owner);
        counter.incrementCount();
        counter.decrementCount();
        vm.stopPrank();

        assertEq(counter.getCount(), 0);
    }

    function test_decrementCount_emitsEvent() external {
        vm.startPrank(owner);
        counter.incrementCount();
        counter.incrementCount();

        vm.expectEmit(true, true, true, true);
        emit CountDecremented(1);

        counter.decrementCount();
        vm.stopPrank();
    }

    function test_decrementCount_revertsOnNonOwner() external {
        vm.prank(owner);
        counter.incrementCount();

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));

        vm.prank(nonOwner);
        counter.decrementCount();
    }

    function test_decrementCount_revertsOnUnderflow() external {
        vm.expectRevert(abi.encodeWithSelector(Counter_Underflow.selector));

        vm.prank(owner);
        counter.decrementCount();
    }

    function testFuzz_decrementCount_multipleDecrements(uint256 initialCount) external {
        initialCount = bound(initialCount, 1, 10_000);

        vm.startPrank(owner);
        for (uint256 i = 0; i < initialCount; i++) {
            counter.incrementCount();
        }

        for (uint256 i = 0; i < initialCount; i++) {
            counter.decrementCount();
        }
        vm.stopPrank();

        assertEq(counter.getCount(), 0);
    }

    function test_resetCount_successful() external {
        vm.startPrank(owner);
        counter.incrementCount();
        counter.incrementCount();
        counter.incrementCount();

        counter.resetCount();
        vm.stopPrank();

        assertEq(counter.getCount(), 0);
    }

    function test_resetCount_emitsEvent() external {
        vm.startPrank(owner);
        counter.incrementCount();

        vm.expectEmit(true, true, true, true);
        emit CountReset();

        counter.resetCount();
        vm.stopPrank();
    }

    function test_resetCount_revertsOnNonOwner() external {
        vm.prank(owner);
        counter.incrementCount();

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));

        vm.prank(nonOwner);
        counter.resetCount();
    }

    function test_resetCount_fromNonZeroValue() external {
        vm.startPrank(owner);
        for (uint256 i = 0; i < 100; i++) {
            counter.incrementCount();
        }

        counter.resetCount();
        vm.stopPrank();

        assertEq(counter.getCount(), 0);
    }

    function test_resetCount_whenAlreadyZero() external {
        vm.prank(owner);
        counter.resetCount();

        assertEq(counter.getCount(), 0);
    }

    function test_getCount_returnsCorrectValue() external view {
        assertEq(counter.getCount(), 0);
    }

    function testFuzz_getCount_afterOperations(uint256 incrementOperations, uint256 decrementOperations) external {
        incrementOperations = bound(incrementOperations, 0, 10_000);
        decrementOperations = bound(decrementOperations, 0, incrementOperations);

        vm.startPrank(owner);
        for (uint256 i = 0; i < incrementOperations; i++) {
            counter.incrementCount();
        }

        for (uint256 i = 0; i < decrementOperations; i++) {
            counter.decrementCount();
        }
        vm.stopPrank();

        assertEq(counter.getCount(), incrementOperations - decrementOperations);
    }

    function test_multipleOperations_sequence() external {
        vm.startPrank(owner);

        counter.incrementCount();
        assertEq(counter.getCount(), 1);

        counter.incrementCount();
        assertEq(counter.getCount(), 2);

        counter.decrementCount();
        assertEq(counter.getCount(), 1);

        counter.resetCount();
        assertEq(counter.getCount(), 0);

        counter.incrementCount();
        assertEq(counter.getCount(), 1);

        vm.stopPrank();
    }

    function testFuzz_ownershipTransfer(address newOwner) external {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != owner);

        vm.prank(owner);
        counter.transferOwnership(newOwner);

        assertEq(counter.owner(), newOwner);

        vm.prank(newOwner);
        counter.incrementCount();

        assertEq(counter.getCount(), 1);
    }

    function test_nonOwnerCannotModifyAfterOwnershipTransfer() external {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        counter.transferOwnership(newOwner);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, owner));

        vm.prank(owner);
        counter.incrementCount();
    }
}
