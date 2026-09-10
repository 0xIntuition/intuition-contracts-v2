// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";

/// @title  CrossCurveRedeemBound
/// @notice Redeem-never-exceeds-deposit across curves, pushed past
///         the existing round-trip suite (which fuzzes to 1000 ether on a single deposit).
///
/// Invariant under test: for every curve (linear=1, offset-progressive=2, progressive=3), the
/// native value a user can pull back out via redeem is <= the value they put in, with no
/// rounding-drift profit at large magnitudes, across many accumulated small deposits, or when two
/// users share a vault.
///
/// Net-new angles: (a) large / near-domain magnitudes where the sqrt-based progressive rounding
/// (`squareUp`/`mulUp` round up on mint, down on deposit/redeem) is most likely to drift; (b)
/// accumulation drift over many sequential small deposits; (c) two-user shared-vault conservation
/// (no extraction of a co-depositor's assets); (d) triple-vault round trips.
///
/// Verdict: DEFENDED. Rounding consistently favors the vault. All assertions are `out <= in`.
contract CrossCurveRedeemBoundTest is BaseTest {
    uint256 internal constant LINEAR = 1;
    uint256 internal constant OFFSET_PROGRESSIVE = 2;
    uint256 internal constant PROGRESSIVE = 3;

    /// @dev Large-magnitude round trip: 100x beyond the existing 1000-ether bound, across all three
    ///      curves. A profit (out > in) would fail; a curve-domain revert is impossible at these
    ///      magnitudes (well under each curve's MAX_ASSETS).
    function testFuzz_largeRoundTripNeverProfits(uint256 depositSeed, uint256 curveSeed) external {
        uint256 curveId = bound(curveSeed, LINEAR, PROGRESSIVE);
        uint256 deposit = bound(depositSeed, MIN_DEPOSIT * 2, 100_000 ether);

        bytes32 atomId = createSimpleAtom(
            string.concat("h3-large-", vm.toString(curveId), "-", vm.toString(deposit)), ATOM_COST[0], users.alice
        );

        vm.deal(users.bob, deposit + 1 ether);
        uint256 balBefore = users.bob.balance;
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, curveId, deposit, 0);
        assertGt(shares, 0, "deposit minted shares");

        redeemShares(users.bob, users.bob, atomId, curveId, shares, 0);
        assertLe(users.bob.balance, balBefore, "large round-trip is not net-positive");
    }

    /// @dev Accumulation drift: many sequential small deposits then a single full redeem must not
    ///      net positive, per curve. Targets per-deposit rounding that could accumulate in the
    ///      depositor's favor.
    function test_manySmallDepositsThenBulkRedeem_noProfit_linear() external {
        _assertAccumulationNoProfit(LINEAR);
    }

    function test_manySmallDepositsThenBulkRedeem_noProfit_offsetProgressive() external {
        _assertAccumulationNoProfit(OFFSET_PROGRESSIVE);
    }

    function test_manySmallDepositsThenBulkRedeem_noProfit_progressive() external {
        _assertAccumulationNoProfit(PROGRESSIVE);
    }

    /// @dev Two users deposit into the same progressive-curve vault, then both redeem fully. Neither
    ///      can extract more than they put in, and the pair's combined out <= combined in (no mutual
    ///      drain via share-price movement).
    function test_twoUserSharedVault_neitherExtractsExcess() external {
        uint256 curveId = PROGRESSIVE;
        bytes32 atomId = createSimpleAtom("h3-shared", ATOM_COST[0], users.alice);

        uint256 bobIn = 40 ether;
        uint256 carolIn = 60 ether;
        vm.deal(users.bob, bobIn + 1 ether);
        vm.deal(users.charlie, carolIn + 1 ether);

        uint256 bobBalBefore = users.bob.balance;
        uint256 carolBalBefore = users.charlie.balance;

        uint256 bobShares = makeDeposit(users.bob, users.bob, atomId, curveId, bobIn, 0);
        uint256 carolShares = makeDeposit(users.charlie, users.charlie, atomId, curveId, carolIn, 0);

        // Redeem in the opposite order to exercise price movement between the two positions.
        redeemShares(users.charlie, users.charlie, atomId, curveId, carolShares, 0);
        redeemShares(users.bob, users.bob, atomId, curveId, bobShares, 0);

        assertLe(users.bob.balance, bobBalBefore, "bob cannot extract excess");
        assertLe(users.charlie.balance, carolBalBefore, "charlie cannot extract excess");

        uint256 combinedIn = bobIn + carolIn;
        uint256 combinedOut =
            (users.bob.balance - (bobBalBefore - bobIn)) + (users.charlie.balance - (carolBalBefore - carolIn));
        assertLe(combinedOut, combinedIn, "combined out <= combined in");
    }

    /// @dev A deposit→full-redeem round trip on a triple's positive vault is not net-positive across
    ///      curves (triples route a fraction of the deposit into the underlying atom vaults).
    function test_tripleRoundTrip_noProfit() external {
        (bytes32 tripleId,) =
            createTripleWithAtoms("h3-subj", "h3-pred", "h3-obj", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        uint256 curveId = getDefaultCurveId();
        uint256 deposit = 25 ether;
        vm.deal(users.bob, deposit + 1 ether);
        uint256 balBefore = users.bob.balance;

        uint256 shares = makeDeposit(users.bob, users.bob, tripleId, curveId, deposit, 0);
        redeemShares(users.bob, users.bob, tripleId, curveId, shares, 0);

        assertLe(users.bob.balance, balBefore, "triple round-trip is not net-positive");
    }

    function _assertAccumulationNoProfit(uint256 curveId) internal {
        bytes32 atomId = createSimpleAtom(string.concat("h3-accum-", vm.toString(curveId)), ATOM_COST[0], users.alice);

        uint256 perDeposit = MIN_DEPOSIT * 3;
        uint256 rounds = 30;
        uint256 totalIn = perDeposit * rounds;
        vm.deal(users.bob, totalIn + 1 ether);

        for (uint256 i = 0; i < rounds; ++i) {
            makeDeposit(users.bob, users.bob, atomId, curveId, perDeposit, 0);
        }

        uint256 bobShares = protocol.multiVault.getShares(users.bob, atomId, curveId);
        uint256 balBeforeRedeem = users.bob.balance;
        redeemShares(users.bob, users.bob, atomId, curveId, bobShares, 0);
        uint256 received = users.bob.balance - balBeforeRedeem;

        assertLe(received, totalIn, "accumulated small deposits do not redeem for more than deposited");
    }
}
