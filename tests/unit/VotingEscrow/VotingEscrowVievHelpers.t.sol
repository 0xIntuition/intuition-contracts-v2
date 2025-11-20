// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { VotingEscrow, Point, LockedBalance } from "src/external/curve/VotingEscrow.sol";
import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";

/// @dev Harness exposing internal functions + some test-only setters.
contract VotingEscrowViewHarness is VotingEscrow {
    function initialize(address admin, address tokenAddress, uint256 minTime) external initializer {
        __VotingEscrow_init(admin, tokenAddress, minTime);
    }

    // --------- Exposed internal helpers ---------

    function exposed_find_timestamp_epoch(uint256 ts, uint256 maxEpoch) external view returns (uint256) {
        return _find_timestamp_epoch(ts, maxEpoch);
    }

    function exposed_find_user_timestamp_epoch(address addr, uint256 ts) external view returns (uint256) {
        return _find_user_timestamp_epoch(addr, ts);
    }

    function exposed_balanceOf(address addr, uint256 t) external view returns (uint256) {
        return _balanceOf(addr, t);
    }

    function exposed_totalSupplyAtT(uint256 t) external view returns (uint256) {
        return _totalSupply(t);
    }

    // --------- Test-only mutation helpers (not used in prod) ---------

    function h_setPointHistory(uint256 idx, int128 bias, int128 slope, uint256 ts, uint256 blk) external {
        point_history[idx] = Point({ bias: bias, slope: slope, ts: ts, blk: blk });
    }

    function h_setUserPoint(address addr, uint256 idx, int128 bias, int128 slope, uint256 ts, uint256 blk) external {
        user_point_history[addr][idx] = Point({ bias: bias, slope: slope, ts: ts, blk: blk });
    }

    function h_setEpoch(uint256 e) external {
        epoch = e;
    }

    function h_setUserEpoch(address addr, uint256 e) external {
        user_point_epoch[addr] = e;
    }

    function h_getEpoch() external view returns (uint256) {
        return epoch;
    }
}

contract VotingEscrowViewHelpersTest is Test {
    VotingEscrowViewHarness internal votingEscrow;
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
        votingEscrow = new VotingEscrowViewHarness();
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
    // _find_timestamp_epoch tests
    // ------------------------------------------------------------

    function test_find_timestamp_epoch_basic_cases() external {
        uint256 baseTs = 10_000;
        uint256 baseBlk = 500;

        // 5 global checkpoints at 10s intervals
        for (uint256 i = 0; i < 5; ++i) {
            votingEscrow.h_setPointHistory(
                i, int128(int256(i + 1)), int128(int256(0)), baseTs + i * 10, baseBlk + i * 5
            );
        }
        // epochs indexed [0..4]
        votingEscrow.h_setEpoch(4);

        // Before first checkpoint -> 0
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs - 1, 4), 0);

        // Exactly at first
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs, 4), 0);

        // Between first and second
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 5, 4), 0);

        // Exactly at second
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 10, 4), 1);

        // In middle (between 3rd and 4th)
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 25, 4), 2);

        // Exactly at last
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 40, 4), 4);

        // After last
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 100, 4), 4);
    }

    function test_find_timestamp_epoch_single_epoch() external {
        uint256 baseTs = 20_000;
        uint256 baseBlk = 1000;

        votingEscrow.h_setPointHistory(0, int128(int256(1)), int128(int256(0)), baseTs, baseBlk);
        votingEscrow.h_setEpoch(0);

        // Any ts < baseTs -> 0 (no earlier checkpoint than index 0)
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs - 1, 0), 0);

        // Exactly at baseTs -> 0
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs, 0), 0);

        // After baseTs -> 0 (only checkpoint)
        assertEq(votingEscrow.exposed_find_timestamp_epoch(baseTs + 1000, 0), 0);
    }

    function testFuzz_find_timestamp_epoch_matches_linear_scan(uint256 tRaw) external {
        uint256 baseTs = 30_000;
        uint256 baseBlk = 2000;
        uint256 numEpochs = 6; // indices [0..5]

        for (uint256 i = 0; i < numEpochs; ++i) {
            votingEscrow.h_setPointHistory(
                i,
                int128(int256(i + 1)),
                int128(int256(0)),
                baseTs + i * 123, // non-uniform spacing is fine
                baseBlk + i * 13
            );
        }
        votingEscrow.h_setEpoch(numEpochs - 1);

        // Search over a range that covers before first and after last
        uint256 minT = baseTs - 500;
        uint256 maxT = baseTs + numEpochs * 123 + 500;
        uint256 t = bound(tRaw, minT, maxT);

        uint256 expected = 0;
        for (uint256 i = 0; i < numEpochs; ++i) {
            (,, uint256 ts,) = votingEscrow.point_history(i);
            if (ts <= t) {
                expected = i;
            }
        }

        uint256 actual = votingEscrow.exposed_find_timestamp_epoch(t, numEpochs - 1);
        assertEq(actual, expected, "find_timestamp_epoch must match linear scan");
    }

    // ------------------------------------------------------------
    // _find_user_timestamp_epoch tests
    // ------------------------------------------------------------

    function test_find_user_timestamp_epoch_returnsZeroWhenNoHistory() external view {
        // No checkpoints for alice
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, 12_345), 0);
    }

    function test_find_user_timestamp_epoch_basic_cases() external {
        uint256 baseTs = 40_000;
        uint256 baseBlk = 3000;

        // Mimic real pattern: user epochs start at 1, index 0 is "empty"
        for (uint256 i = 1; i <= 4; ++i) {
            votingEscrow.h_setUserPoint(
                alice, i, int128(int256(i)), int128(int256(0)), baseTs + (i - 1) * 10, baseBlk + (i - 1) * 7
            );
        }
        votingEscrow.h_setUserEpoch(alice, 4);

        // Before first checkpoint -> 0
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, baseTs - 1), 0);

        // Exactly at first real checkpoint
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, baseTs), 1);

        // Between first and second
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, baseTs + 5), 1);

        // Exactly at third
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, baseTs + 20), 3);

        // After last
        assertEq(votingEscrow.exposed_find_user_timestamp_epoch(alice, baseTs + 100), 4);
    }

    function testFuzz_find_user_timestamp_epoch_matches_linear_scan(uint256 tRaw) external {
        uint256 baseTs = 50_000;
        uint256 baseBlk = 4000;
        uint256 numUserEpochs = 5; // real epochs at indices [1..5]

        for (uint256 i = 1; i <= numUserEpochs; ++i) {
            votingEscrow.h_setUserPoint(
                alice, i, int128(int256(i)), int128(int256(0)), baseTs + (i - 1) * 111, baseBlk + (i - 1) * 9
            );
        }
        votingEscrow.h_setUserEpoch(alice, numUserEpochs);

        // Range covering before first and after last
        uint256 minT = baseTs - 300;
        uint256 maxT = baseTs + numUserEpochs * 111 + 300;
        uint256 t = bound(tRaw, minT, maxT);

        uint256 expected = 0;
        for (uint256 i = 1; i <= numUserEpochs; ++i) {
            (,, uint256 ts,) = votingEscrow.user_point_history(alice, i);
            if (ts <= t) {
                expected = i;
            }
        }

        uint256 actual = votingEscrow.exposed_find_user_timestamp_epoch(alice, t);
        assertEq(actual, expected, "find_user_timestamp_epoch must match linear scan");
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
