// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { VotingEscrowHarness } from "tests/mocks/VotingEscrowHarness.sol";
import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";

contract VotingEscrowViewHelpersIntegrationTest is Test {
    VotingEscrowHarness internal votingEscrow;
    ERC20Mock internal token;

    address internal admin;
    address internal alice;
    address internal bob;

    uint256 internal constant WEEK = 1 weeks;
    uint256 internal constant DEFAULT_MINTIME = 2 weeks;
    uint256 internal constant INITIAL_BALANCE = 1_000_000e18;

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Keep timestamps well above 0 to make "before first checkpoint" cases easy
        vm.warp(1000);
        vm.roll(100);

        token = new ERC20Mock("Test Token", "TEST", 18);
        votingEscrow = new VotingEscrowHarness();
        votingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);

        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);

        vm.prank(alice);
        token.approve(address(votingEscrow), type(uint256).max);
        vm.prank(bob);
        token.approve(address(votingEscrow), type(uint256).max);
    }

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------

    function _createLock(
        address user,
        uint256 amount,
        uint256 lockDuration
    )
        internal
        returns (uint256 lockStart, uint256 lockEnd)
    {
        // Ensure we satisfy MINTIME
        require(lockDuration >= DEFAULT_MINTIME, "lockDuration too short for helper");

        vm.prank(user, user);
        votingEscrow.create_lock(amount, block.timestamp + lockDuration);

        lockStart = block.timestamp;

        (, lockEnd) = votingEscrow.locked(user);
    }

    // ------------------------------------------------------------
    // _balanceOf / balanceOfAtT tests
    // ------------------------------------------------------------

    function test_balanceOf_returnsZeroForUserWithNoHistory() external view {
        uint256 nowTs = block.timestamp;
        assertEq(votingEscrow.exposed_balanceOf(alice, nowTs), 0);
        assertEq(votingEscrow.balanceOf(alice), 0);
        assertEq(votingEscrow.balanceOfAtT(alice, nowTs + 1000), 0);
    }

    function test_balanceOf_returnsZeroForTimeBeforeFirstUserCheckpoint() external {
        // Move a bit so "time before" is easy
        vm.warp(60_000);
        vm.roll(1000);

        (uint256 lockStart,) = _createLock(alice, 100e18, 8 weeks);

        // Ask for voting power before the lock was created
        uint256 queryTime = lockStart - 1;
        uint256 bal = votingEscrow.exposed_balanceOf(alice, queryTime);
        assertEq(bal, 0);
    }

    function test_balanceOf_decaysToZeroAtLockEnd() external {
        vm.warp(70_000);
        vm.roll(1100);

        (uint256 lockStart, uint256 lockEnd) = _createLock(alice, 1000e18, 8 weeks);

        // At creation / immediately -> positive
        uint256 atStart = votingEscrow.exposed_balanceOf(alice, lockStart);
        assertGt(atStart, 0);
        assertEq(atStart, votingEscrow.balanceOf(alice));

        // Halfway
        uint256 midTime = lockStart + (lockEnd - lockStart) / 2;
        uint256 midBal = votingEscrow.exposed_balanceOf(alice, midTime);
        assertGt(midBal, 0);
        assertLt(midBal, atStart);

        // At end or later -> zero
        uint256 endBal = votingEscrow.exposed_balanceOf(alice, lockEnd);
        uint256 afterEndBal = votingEscrow.exposed_balanceOf(alice, lockEnd + 1 weeks);
        assertEq(endBal, 0);
        assertEq(afterEndBal, 0);
    }

    function test_balanceOfAtT_matches_balanceOfForCurrentTime() external {
        vm.warp(80_000);
        vm.roll(1200);

        _createLock(alice, 500e18, 12 weeks);

        // Query at "now" through both paths
        uint256 nowTs = block.timestamp;
        uint256 bal = votingEscrow.balanceOf(alice);
        uint256 balAtT = votingEscrow.balanceOfAtT(alice, nowTs);

        assertEq(balAtT, bal);
    }

    function testFuzz_balanceOf_monotonicOverTime(uint256 tRaw1, uint256 tRaw2) external {
        vm.warp(90_000);
        vm.roll(1300);

        (uint256 lockStart, uint256 lockEnd) = _createLock(alice, 2000e18, 12 weeks);
        uint256 duration = lockEnd - lockStart;

        // Pick two times in [lockStart, lockStart + 2 * duration]
        uint256 t1 = lockStart + bound(tRaw1, 0, 2 * duration);
        uint256 t2 = lockStart + bound(tRaw2, 0, 2 * duration);

        uint256 tLow = t1 < t2 ? t1 : t2;
        uint256 tHigh = t1 < t2 ? t2 : t1;

        uint256 balLow = votingEscrow.exposed_balanceOf(alice, tLow);
        uint256 balHigh = votingEscrow.exposed_balanceOf(alice, tHigh);

        // Voting power should never increase as time moves forward
        assertGe(balLow, balHigh, "Voting power must be non-increasing over time");

        // After lock end, it must be zero
        if (tHigh >= lockEnd) {
            assertEq(balHigh, 0);
        }
    }

    // ------------------------------------------------------------
    // balanceOfAt tests
    // ------------------------------------------------------------

    function test_balanceOfAt_revertsForFutureBlock() external {
        uint256 futureBlock = block.number + 10;
        vm.expectRevert("block in the future");
        votingEscrow.balanceOfAt(alice, futureBlock);
    }

    function test_balanceOfAt_returnsZeroWhenNoCheckpoints() external view {
        // epoch == 0, no locks at all
        assertEq(votingEscrow.balanceOfAt(alice, block.number), 0);
    }

    function test_balanceOfAt_returnsZeroForBlockBeforeFirstCheckpoint() external {
        // Manually seed a first global checkpoint at some later block
        uint256 firstBlk = block.number + 100;
        uint256 firstTs = block.timestamp + 1000;

        votingEscrow.h_setPointHistory(0, int128(int256(0)), int128(int256(0)), firstTs, firstBlk);
        votingEscrow.h_setEpoch(0);

        // Make sure our query block is not "in the future" relative to chain
        vm.roll(firstBlk + 10);

        // Any block < firstBlk must return 0
        uint256 queryBlock = firstBlk - 1;
        assertEq(votingEscrow.balanceOfAt(alice, queryBlock), 0);
    }

    function test_balanceOfAt_matchesBalanceOfForCurrentBlock() external {
        vm.warp(100_000);
        vm.roll(1400);

        _createLock(alice, 777e18, 16 weeks);

        uint256 currentBlock = block.number;
        uint256 balNow = votingEscrow.balanceOf(alice);
        uint256 balAt = votingEscrow.balanceOfAt(alice, currentBlock);

        assertEq(balAt, balNow);

        vm.warp(200_000);
        vm.roll(2400);

        balNow = votingEscrow.balanceOfAtT(alice, 200_000);
        balAt = votingEscrow.balanceOfAt(alice, 2400);

        assertEq(balAt, balNow, "balanceOfAt must reflect balance at the queried block");
    }

    function test_balanceOfAt_roughlyMatchesBalanceOfAtNearbyTimestamp() external {
        vm.warp(200_000);
        vm.roll(2000);

        _createLock(alice, 1000e18, 20 weeks);

        vm.warp(201_000);
        vm.roll(2010);
        vm.prank(alice, alice);
        votingEscrow.increase_amount(500e18);

        uint256 queryBlock = 2005;

        uint256 balanceByBlock = votingEscrow.balanceOfAt(alice, queryBlock);
        uint256 balanceByTs = votingEscrow.balanceOfAtT(alice, 200_500); // example timestamp between ts of blocks 2000
        // and
        // 2005

        // Allow small relative drift due to interpolation + integer division
        assertApproxEqRel(balanceByBlock, balanceByTs, 2e13); // 2e13 => 0.002% tolerance
    }

    function test_balanceOfAt_matchesBalanceOfAtInterpolatedTimestamp() external {
        vm.warp(200_000);
        vm.roll(2000);

        _createLock(alice, 1000e18, 20 weeks);

        vm.warp(201_000);
        vm.roll(2010);
        vm.prank(alice, alice);
        votingEscrow.increase_amount(500e18);

        uint256 queryBlock = 2005;

        uint256 interpolatedTs = votingEscrow.exposed_blockTimeForBlock(queryBlock);

        uint256 balanceByBlock = votingEscrow.balanceOfAt(alice, queryBlock);
        uint256 balanceByTime = votingEscrow.balanceOfAtT(alice, interpolatedTs);

        assertEq(balanceByBlock, balanceByTime);
    }

    function testFuzz_balanceOfAt_consistentWithInterpolatedTimestamp(uint256 blockOffset) external {
        vm.warp(300_000);
        vm.roll(3000);
        _createLock(alice, 1500e18, 24 weeks);

        vm.warp(301_000);
        vm.roll(3010);
        vm.prank(alice, alice);
        votingEscrow.increase_amount(500e18);

        // Pick a block in [3000, 3010]
        uint256 queryBlock = 3000 + bound(blockOffset, 0, 10);

        uint256 interpolatedTs = votingEscrow.exposed_blockTimeForBlock(queryBlock);

        uint256 balanceByBlock = votingEscrow.balanceOfAt(alice, queryBlock);
        uint256 balanceByTime = votingEscrow.balanceOfAtT(alice, interpolatedTs);

        assertEq(balanceByBlock, balanceByTime, "balanceOfAt must match balanceOfAtT at interpolated timestamp");
    }

    // ------------------------------------------------------------
    // _totalSupply / totalSupplyAtT tests
    // ------------------------------------------------------------

    function test_totalSupply_zeroWhenNoLocks() external view {
        assertEq(votingEscrow.totalSupply(), 0);
        assertEq(votingEscrow.totalSupplyAtT(block.timestamp + 1 days), 0);
    }

    function test_totalSupply_equalsUserBalanceForSingleLock() external {
        vm.warp(110_000);
        vm.roll(1500);

        _createLock(alice, 1000e18, 20 weeks);

        uint256 supplyNow = votingEscrow.totalSupply();
        uint256 aliceBal = votingEscrow.balanceOf(alice);

        assertEq(supplyNow, aliceBal);
    }

    function test_totalSupplyAtT_equalsSumOfBalancesAtT_twoUsers() external {
        vm.warp(120_000);
        vm.roll(1600);

        _createLock(alice, 1000e18, 24 weeks);
        _createLock(bob, 500e18, 24 weeks);

        // move forward a bit to have some decay
        vm.warp(block.timestamp + 3 weeks);
        uint256 queryTime = block.timestamp;

        uint256 supplyAtT = votingEscrow.totalSupplyAtT(queryTime);
        uint256 aliceBalAtT = votingEscrow.balanceOfAtT(alice, queryTime);
        uint256 bobBalAtT = votingEscrow.balanceOfAtT(bob, queryTime);

        assertEq(supplyAtT, aliceBalAtT + bobBalAtT);
    }

    function testFuzz_totalSupplyAtT_equalsSumOfBalances(uint256 tRaw) external {
        vm.warp(130_000);
        vm.roll(1700);

        (uint256 startA, uint256 endA) = _createLock(alice, 2000e18, 20 weeks);
        (uint256 startB, uint256 endB) = _createLock(bob, 1000e18, 30 weeks);

        uint256 start = startA < startB ? startA : startB;
        uint256 end = endA > endB ? endA : endB;

        uint256 t = bound(tRaw, start, end + 4 weeks);

        uint256 supplyAtT = votingEscrow.totalSupplyAtT(t);
        uint256 aliceBalAtT = votingEscrow.balanceOfAtT(alice, t);
        uint256 bobBalAtT = votingEscrow.balanceOfAtT(bob, t);

        assertEq(supplyAtT, aliceBalAtT + bobBalAtT, "totalSupplyAtT must equal sum of individual balances");
    }

    function test_totalSupplyAt_matchesTotalSupplyForCurrentBlock() external {
        vm.warp(140_000);
        vm.roll(1800);

        _createLock(alice, 800e18, 16 weeks);
        _createLock(bob, 200e18, 16 weeks);

        uint256 supplyNow = votingEscrow.totalSupply();
        uint256 supplyAt = votingEscrow.totalSupplyAt(block.number);

        assertEq(supplyAt, supplyNow);
    }

    function test_totalSupplyAt_roughlyMatchesTotalSupplyAtNearbyTimestamp() external {
        vm.warp(140_000);
        vm.roll(1400);
        _createLock(alice, 800e18, 16 weeks);

        vm.warp(141_000);
        vm.roll(1410);
        _createLock(bob, 200e18, 16 weeks);

        vm.warp(142_000);
        vm.roll(1420);
        vm.prank(alice, alice);
        votingEscrow.increase_amount(200e18);

        uint256 queryBlock = 1411;

        uint256 supplyByBlock = votingEscrow.totalSupplyAt(queryBlock);
        uint256 supplyByTs = votingEscrow.totalSupplyAtT(141_003); // example timestamp between ts of blocks 1410 and
        // 1411

        // Allow small relative drift due to interpolation + integer division
        assertApproxEqRel(supplyByBlock, supplyByTs, 2e13); // 2e13 => 0.002% tolerance
    }

    function test_totalSupplyAt_matchesTotalSupplyAtInterpolatedTimestamp() external {
        vm.warp(140_000);
        vm.roll(1400);
        _createLock(alice, 800e18, 16 weeks);

        vm.warp(141_000);
        vm.roll(1410);
        _createLock(bob, 200e18, 16 weeks);

        vm.warp(142_000);
        vm.roll(1420);
        vm.prank(alice, alice);
        votingEscrow.increase_amount(200e18);

        uint256 queryBlock = 1411;

        // This is the exact t that totalSupplyAt(queryBlock) will use internally
        uint256 interpolatedTs = votingEscrow.exposed_blockTimeForBlock(queryBlock);

        uint256 supplyByBlock = votingEscrow.totalSupplyAt(queryBlock);
        uint256 supplyByTs = votingEscrow.totalSupplyAtT(interpolatedTs);

        // Now both paths are using the same (point, t) pair, so equality is expected.
        assertEq(supplyByBlock, supplyByTs);
    }

    function testFuzz_totalSupplyAt_consistentWithInterpolatedTimestamp(uint256 blockOffset) external {
        vm.warp(300_000);
        vm.roll(3000);
        _createLock(alice, 1500e18, 24 weeks);

        vm.warp(301_000);
        vm.roll(3010);
        _createLock(bob, 500e18, 24 weeks);

        // Pick a block in [3000, 3010]
        uint256 queryBlock = 3000 + bound(blockOffset, 0, 10);

        uint256 interpolatedTs = votingEscrow.exposed_blockTimeForBlock(queryBlock);

        uint256 supplyByBlock = votingEscrow.totalSupplyAt(queryBlock);
        uint256 supplyByTime = votingEscrow.totalSupplyAtT(interpolatedTs);

        assertEq(supplyByBlock, supplyByTime, "totalSupplyAt must match totalSupplyAtT at interpolated timestamp");
    }

    function test_totalSupplyAt_returnsZeroForBlockBeforeFirstCheckpoint() external {
        uint256 firstBlk = block.number + 50;
        uint256 firstTs = block.timestamp + 500;

        votingEscrow.h_setPointHistory(0, int128(int256(0)), int128(int256(0)), firstTs, firstBlk);
        votingEscrow.h_setEpoch(0);

        // Ensure query block is <= current block, to avoid "block in the future" reverts
        vm.roll(firstBlk + 10);

        uint256 queryBlock = firstBlk - 1;
        assertEq(votingEscrow.totalSupplyAt(queryBlock), 0);
    }

    function test_totalSupplyAt_revertsForFutureBlock() external {
        uint256 futureBlock = block.number + 1;
        vm.expectRevert("block in the future");
        votingEscrow.totalSupplyAt(futureBlock);
    }
}
