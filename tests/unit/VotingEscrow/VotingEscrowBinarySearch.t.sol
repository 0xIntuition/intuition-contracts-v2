// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { VotingEscrowHarness } from "tests/mocks/VotingEscrowHarness.sol";

contract VotingEscrowBinarySearchTest is Test {
    VotingEscrowHarness internal votingEscrow;

    address internal admin;
    address internal alice;
    address internal bob;

    uint256 internal constant WEEK = 1 weeks;
    uint256 internal constant DEFAULT_MINTIME = 2 weeks;

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Keep timestamps well above 0 to make "before first checkpoint" cases easy
        vm.warp(1000);
        vm.roll(100);

        votingEscrow = new VotingEscrowHarness();
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
}
