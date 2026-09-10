// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { VotingEscrowHarness } from "tests/mocks/VotingEscrowHarness.sol";
import { LockedBalance } from "src/external/curve/VotingEscrow.sol";

/// @dev Directly constructs the negative-bias/slope decay states that VotingEscrow's own
///      "This can happen" clamps exist to catch. These require rounding artifacts from the
///      discrete weekly-step decay walk across overlapping locks (a well-known veCRV-family
///      quirk) that are impractical to reproduce via realistic lock scenarios, so the harness's
///      direct point-history setters are used to construct the exact pre-decay state instead.
contract VotingEscrowDecayClampsTest is Test {
    VotingEscrowHarness internal votingEscrow;

    uint256 internal constant WEEK = 1 weeks;

    function setUp() public {
        vm.warp(1000);
        vm.roll(100);
        votingEscrow = new VotingEscrowHarness();
    }

    /// @dev checkpoint()'s weekly-step loop (line ~249): a point with a disproportionately large
    ///      slope relative to its bias decays past zero on the very first step.
    function test_checkpoint_globalBiasClampsToZero_whenDecayOvershoots() external {
        votingEscrow.h_setPointHistory(1, 1e15, 1e18, 500, 50);
        votingEscrow.h_setEpoch(1);

        vm.warp(500 + 10 * WEEK);
        vm.roll(1000);

        votingEscrow.checkpoint();

        // The clamp floors bias at zero rather than letting it go negative; with no slope_changes
        // scheduled, slope itself stays positive (a separate, author-flagged "cannot happen" clamp).
        assertEq(votingEscrow.exposed_totalSupplyAtT(block.timestamp), 0);
    }

    /// @dev _supply_at (line ~725), reached via totalSupplyAtT: same overshoot, single-step decay
    ///      walk to a target far past the point's timestamp.
    function test_totalSupplyAtT_clampsToZero_whenDecayOvershoots() external {
        votingEscrow.h_setPointHistory(0, 1e15, 1e18, 500, 50);
        votingEscrow.h_setEpoch(0);

        uint256 result = votingEscrow.exposed_totalSupplyAtT(1000);

        assertEq(result, 0);
    }

    /// @dev balanceOfAt's per-user interpolation (line ~695): a user point with a huge slope
    ///      relative to bias, interpolated forward, goes negative and must return 0 rather than
    ///      underflow.
    function test_balanceOfAt_returnsZero_whenInterpolatedBiasNegative() external {
        address alice = makeAddr("alice");

        votingEscrow.h_setUserPoint(alice, 0, 1e15, 1e18, 500, 50);
        votingEscrow.h_setUserEpoch(alice, 0);

        // Global point_history[0] matches the query block exactly so the block->time
        // interpolation contributes zero extra elapsed time beyond upoint's own timestamp.
        votingEscrow.h_setPointHistory(0, 0, 0, 1000, 100);
        votingEscrow.h_setEpoch(0);

        uint256 balance = votingEscrow.balanceOfAt(alice, 100);

        assertEq(balance, 0);
    }

    /// @dev _checkpoint's per-user delta application (lines ~278/281) only runs when `_addr` is
    ///      nonzero, which only happens via a real lock-modifying call (create_lock, withdraw,
    ///      etc.) — never via the bare external checkpoint(). Reachable in principle when a user's
    ///      old position vastly outweighs the aggregate global point (e.g. every other lock has
    ///      already fully decayed) and their new position is empty (a withdrawal), so the negative
    ///      delta pushes the global slope/bias below zero. Exercised directly via the harness with
    ///      a contrived old/new pair rather than chaining the exact multi-lock sequence that would
    ///      reproduce it organically.
    function test_checkpoint_perUserDelta_clampsSlopeAndBiasToZero() external {
        LockedBalance memory oldLocked = LockedBalance({ amount: 1e27, end: block.timestamp + 2 * 365 days });
        LockedBalance memory newLocked = LockedBalance({ amount: 0, end: 0 });

        votingEscrow.exposed_checkpoint(makeAddr("alice"), oldLocked, newLocked);

        // Global point_history has no other active locks, so the negative per-user delta must
        // clamp the aggregate slope and bias at zero rather than go negative.
        assertEq(votingEscrow.exposed_totalSupplyAtT(block.timestamp), 0);
    }
}
