// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";

/// @title  CurveClaimViewsTest
/// @notice Gating coverage for the split claim views.
///
///         `claimable(account, termId)` returns a per-term pending PLUS an account-wide banked
///         balance, so summing it across a user's terms over-reports by the banked amount once per
///         extra term. The split views exist so a consumer can compose correctly:
///         `bankedEarnings` once, `pendingFor` per term, or `claimableAcross` for the total.
///
///         `claimableAcross` claims to equal what `claim` would pay, so it rejects repeated term ids:
///         a repeat would be counted once per occurrence here while `claim` settles it only once,
///         silently breaking that equality. Order is irrelevant — the ids may be supplied in any
///         sequence.
contract CurveClaimViewsTest is BaseTest {
    uint256 internal constant DYN = DYNAMIC_FEE_CURVE_ID;

    function _atom(string memory label) internal returns (bytes32) {
        return createSimpleAtom(label, ATOM_COST[0], users.alice);
    }

    /// @dev Builds two terms in which `users.bob` holds stake and has accrued fees, with the banked
    ///      component made non-zero by re-depositing into the first term (which settles it).
    function _twoTermsWithBankedEarnings() internal returns (bytes32 first, bytes32 second) {
        first = _atom("claim-views-1");
        second = _atom("claim-views-2");

        // Bob enters low so he sits in a PRIOR tier once the vault climbs.
        makeDeposit(users.bob, users.bob, first, DYN, 3e18, 0);
        makeDeposit(users.bob, users.bob, second, DYN, 3e18, 0);

        // Grow both vaults above tier 0. This deposit's own fee routes to the protocol bucket,
        // because a tier-0 vault has no prior tier to redistribute to.
        makeDeposit(users.charlie, users.charlie, first, DYN, 40e18, 0);
        makeDeposit(users.charlie, users.charlie, second, DYN, 40e18, 0);

        // Now the vault is above tier 0, so this deposit's fee spreads across prior tiers and bob earns.
        makeDeposit(users.alice, users.alice, first, DYN, 40e18, 0);
        makeDeposit(users.alice, users.alice, second, DYN, 40e18, 0);

        // Re-depositing into `first` settles bob's pending there into the account-wide banked balance.
        makeDeposit(users.bob, users.bob, first, DYN, 1e18, 0);
    }

    /// @dev The composition rule: banked once, pending per term. This must equal `claimableAcross`,
    ///      and naive summation of `claimable` must be strictly larger.
    function test_claimableAcross_matchesComposedViewsAndBeatsNaiveSummation() external {
        (bytes32 first, bytes32 second) = _twoTermsWithBankedEarnings();

        uint256 banked = dynamicFeeCurve.bankedEarnings(users.bob);
        assertGt(banked, 0, "fixture must produce a non-zero banked balance");

        uint256 composed =
            banked + dynamicFeeCurve.pendingFor(users.bob, first) + dynamicFeeCurve.pendingFor(users.bob, second);

        bytes32[] memory terms = new bytes32[](2);
        (terms[0], terms[1]) = first < second ? (first, second) : (second, first);

        assertEq(
            dynamicFeeCurve.claimableAcross(users.bob, terms), composed, "claimableAcross must equal the composition"
        );

        uint256 naive = dynamicFeeCurve.claimable(users.bob, first) + dynamicFeeCurve.claimable(users.bob, second);
        assertEq(
            naive, composed + banked, "naive summation double-counts the banked balance exactly once per extra term"
        );
    }

    /// @dev The stated equality with the payout, executed. `claimableAcross` must equal what `claim`
    ///      actually transfers for the same set of terms.
    function test_claimableAcross_equalsWhatClaimPays() external {
        (bytes32 first, bytes32 second) = _twoTermsWithBankedEarnings();

        bytes32[] memory terms = new bytes32[](2);
        terms[0] = first;
        terms[1] = second;

        uint256 quoted = dynamicFeeCurve.claimableAcross(users.bob, terms);

        vm.startPrank(users.bob);
        uint256 paid = dynamicFeeCurve.claim(terms);
        vm.stopPrank();

        assertEq(paid, quoted, "claimableAcross must equal the executed payout");
    }

    /// @dev The guard. Removing the ascending check lets a repeated term be counted twice, breaking
    ///      the equality the function documents, and turns this test red.
    function test_claimableAcross_revertsOnDuplicateTermIds() external {
        (bytes32 first,) = _twoTermsWithBankedEarnings();

        bytes32[] memory terms = new bytes32[](2);
        terms[0] = first;
        terms[1] = first;

        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_DuplicateTermIds.selector)
        );
        dynamicFeeCurve.claimableAcross(users.bob, terms);
    }

    /// @dev Order is irrelevant — the same set in either order must produce the same total. This is
    ///      the ergonomic property the uniqueness check buys over an ordering requirement.
    function test_claimableAcross_isOrderIndependent() external {
        (bytes32 first, bytes32 second) = _twoTermsWithBankedEarnings();

        bytes32[] memory ascending = new bytes32[](2);
        (ascending[0], ascending[1]) = first < second ? (first, second) : (second, first);

        bytes32[] memory descending = new bytes32[](2);
        (descending[0], descending[1]) = (ascending[1], ascending[0]);

        assertEq(
            dynamicFeeCurve.claimableAcross(users.bob, descending),
            dynamicFeeCurve.claimableAcross(users.bob, ascending),
            "the total must not depend on the order the terms are supplied in"
        );
    }

    /// @dev A repeat that is NOT adjacent in the supplied order must still be caught. This is what
    ///      makes the sort load-bearing: with the sort removed, a two-element duplicate is still
    ///      trivially adjacent and would be caught by luck, but `[A, B, A]` would slip through.
    function test_claimableAcross_revertsOnNonAdjacentDuplicate() external {
        (bytes32 first, bytes32 second) = _twoTermsWithBankedEarnings();

        bytes32[] memory terms = new bytes32[](3);
        terms[0] = first;
        terms[1] = second;
        terms[2] = first;

        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_DuplicateTermIds.selector)
        );
        dynamicFeeCurve.claimableAcross(users.bob, terms);
    }

    /// @dev An empty set is rejected as a deliberate API choice, not because the value would be
    ///      meaningless: `claim([])` is itself valid and withdraws any banked balance, so the
    ///      consistent answer for an empty set would be exactly `bankedEarnings`. The rejection exists
    ///      to surface caller error — an empty array reaching this function almost always means the
    ///      caller assembled the wrong set — and `bankedEarnings` already exposes that number
    ///      directly, so nothing is unreachable.
    function test_claimableAcross_revertsOnEmptyTermIds() external {
        _twoTermsWithBankedEarnings();

        bytes32[] memory terms = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_EmptyTermIds.selector));
        dynamicFeeCurve.claimableAcross(users.bob, terms);
    }

    /// @dev `pendingFor` is term-scoped and excludes the banked balance; `bankedEarnings` is
    ///      account-wide. Together they reconstruct `claimable` exactly.
    function test_pendingForPlusBanked_reconstructsClaimable() external {
        (bytes32 first,) = _twoTermsWithBankedEarnings();

        assertEq(
            dynamicFeeCurve.bankedEarnings(users.bob) + dynamicFeeCurve.pendingFor(users.bob, first),
            dynamicFeeCurve.claimable(users.bob, first),
            "banked + pending must reconstruct claimable"
        );
    }
}
