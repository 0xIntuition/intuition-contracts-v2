// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  DynamicFeeAdversarialEconomicsTest
/// @notice Adversarial economic tests for the flat-price / dynamic-fee curve, driven end-to-end through
///         MultiVault (curve id 4). These actively try to break the economics: Sybil / wallet-splitting,
///         front-running the recent-N earning window, fee-helper solvency (never pays out more than it
///         collected), wash / round-trip must be net-negative, principal always returns at par, and live
///         fee-change abuse (governance bounds, no re-pricing of already-accrued balances). Every modeled
///         attack must revert or stay within documented bounds.
contract DynamicFeeAdversarialEconomicsTest is BaseTest {
    uint256 internal constant DYN = DYNAMIC_FEE_CURVE_ID;

    function _atom(string memory label) internal returns (bytes32) {
        return createSimpleAtom(label, ATOM_COST[0], users.alice);
    }

    /// @dev The dynamic vault must always price exactly 1:1 (flat par).
    function _assertPar(bytes32 atomId) internal view {
        (uint256 totalAssets, uint256 totalShares) = protocol.multiVault.getVault(atomId, DYN);
        assertEq(totalAssets, totalShares, "dynamic vault must stay 1:1 (flat par)");
    }

    /// @dev Claim if there is anything to claim (claim reverts on a zero balance).
    function _claim(address who, bytes32 atomId) internal {
        if (dynamicFeeCurve.claimable(who, atomId) == 0) return;
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = atomId;
        resetPrank(who);
        dynamicFeeCurve.claim(terms);
    }

    /* =================================================== */
    /*                    WASH / ROUND-TRIP               */
    /* =================================================== */

    /// @dev A deposit-then-redeem round trip must always lose money (the fees), never print it.
    function test_wash_roundTripIsNetNegative() external {
        bytes32 atomId = _atom("wash");
        makeDeposit(users.bob, users.bob, atomId, DYN, 20e18, 0); // co-holder so alice isn't the last out

        uint256 balanceBefore = users.alice.balance;
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, DYN, 20e18, 0);
        redeemShares(users.alice, users.alice, atomId, DYN, shares, 0);

        assertLt(users.alice.balance, balanceBefore, "round trip must be net-negative (fees paid)");
        _assertPar(atomId);
    }

    /// @dev Fuzzed: no round trip, at any size, ever returns more than was deposited, and par holds.
    function testFuzz_wash_neverReturnsMoreThanDeposited(uint256 amount, uint256 seed) external {
        amount = bound(amount, 1e18, 500e18);
        seed = bound(seed, 1e18, 50e18);
        bytes32 atomId = _atom("wash-fuzz");
        makeDeposit(users.charlie, users.charlie, atomId, DYN, seed, 0);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, DYN, amount, 0);
        uint256 got = redeemShares(users.alice, users.alice, atomId, DYN, shares, 0);

        assertLe(got, amount, "cannot redeem more than deposited (no principal creation)");
        _assertPar(atomId);
    }

    /* =================================================== */
    /*                  SYBIL / WALLET-SPLIT              */
    /* =================================================== */

    /// @dev A Sybil cluster cannot profit by washing among its own wallets: split the actor across three
    ///      addresses that deposit into different tiers, let fees flow between them, then all exit and
    ///      claim. Their combined balance must strictly decrease — the redistribution among themselves
    ///      nets to zero, and they still bleed MultiVault fees + protocol leakage.
    function test_sybil_washingAmongOwnWalletsIsNetNegative() external {
        bytes32 atomId = _atom("sybil");
        address[3] memory wallets = [address(users.alice), address(users.bob), address(users.charlie)];

        uint256 totalBefore = wallets[0].balance + wallets[1].balance + wallets[2].balance;

        uint256 s0 = makeDeposit(wallets[0], wallets[0], atomId, DYN, 15e18, 0);
        uint256 s1 = makeDeposit(wallets[1], wallets[1], atomId, DYN, 12e18, 0);
        uint256 s2 = makeDeposit(wallets[2], wallets[2], atomId, DYN, 12e18, 0);

        _claim(wallets[0], atomId);
        _claim(wallets[1], atomId);
        _claim(wallets[2], atomId);

        redeemShares(wallets[0], wallets[0], atomId, DYN, s0, 0);
        redeemShares(wallets[1], wallets[1], atomId, DYN, s1, 0);
        redeemShares(wallets[2], wallets[2], atomId, DYN, s2, 0);

        _claim(wallets[0], atomId);
        _claim(wallets[1], atomId);
        _claim(wallets[2], atomId);

        uint256 totalAfter = wallets[0].balance + wallets[1].balance + wallets[2].balance;
        assertLt(totalAfter, totalBefore, "a Sybil cluster cannot profit by washing among its own wallets");
    }

    /// @dev Splitting a deposit across wallets is economically neutral: the same total spread across two
    ///      independent wallets mints essentially the same shares as one depositor (fees are piecewise on
    ///      the vault trajectory, not on the actor's wallet count). Any residual gap is tier-boundary
    ///      rounding well under 0.1% — far below the gas cost of operating extra wallets, so there is no
    ///      exploitable Sybil edge.
    function test_sybil_splitReceiversAreEconomicallyNeutral() external {
        bytes32 single = _atom("split-single");
        bytes32 split = _atom("split-multi");

        uint256 sharesSingle = makeDeposit(users.alice, users.alice, single, DYN, 24e18, 0);

        uint256 sharesA = makeDeposit(users.bob, users.bob, split, DYN, 12e18, 0);
        uint256 sharesB = makeDeposit(users.charlie, users.charlie, split, DYN, 12e18, 0);

        assertApproxEqRel(sharesA + sharesB, sharesSingle, 0.001e18, "wallet-splitting confers no material advantage");
    }

    /* =================================================== */
    /*              FRONT-RUN / SANDWICH WINDOW          */
    /* =================================================== */

    /// @dev An attacker who sandwiches a victim's deposit cannot earn more than the fee the victim
    ///      actually paid — no inflation, no theft, only a bounded share of real fees. (Earning from
    ///      later depositors is the intended mechanic; the invariant is that it stays within collections.)
    function test_frontRun_sandwichEarningsBoundedByVictimFee() external {
        bytes32 atomId = _atom("sandwich");
        makeDeposit(users.charlie, users.charlie, atomId, DYN, 5e18, 0); // establishes lower tiers

        makeDeposit(users.alice, users.alice, atomId, DYN, 5e18, 0); // attacker positions
        uint256 curveBalanceBefore = address(dynamicFeeCurve).balance;

        makeDeposit(users.bob, users.bob, atomId, DYN, 50e18, 0); // victim's big deposit
        uint256 victimFee = address(dynamicFeeCurve).balance - curveBalanceBefore;

        uint256 attackerEarned = dynamicFeeCurve.claimable(users.alice, atomId);
        assertLe(attackerEarned, victimFee, "attacker cannot earn more than the victim's fee (no theft/inflation)");
    }

    /* =================================================== */
    /*                     SOLVENCY                       */
    /* =================================================== */

    /// @dev The core solvency invariant: after any deposit/redeem sequence, the curve's native balance
    ///      covers every obligation it owes (all users' claimable + protocol accrual). It can never be
    ///      made to owe more than it holds.
    function testFuzz_solvency_contractCoversAllObligations(uint256 a, uint256 b, uint256 c, uint256 redeemPct)
        external
    {
        a = bound(a, 1e18, 100e18);
        b = bound(b, 1e18, 100e18);
        c = bound(c, 1e18, 100e18);
        redeemPct = bound(redeemPct, 0, 100);

        bytes32 atomId = _atom("solvency");
        makeDeposit(users.alice, users.alice, atomId, DYN, a, 0);
        makeDeposit(users.bob, users.bob, atomId, DYN, b, 0);
        makeDeposit(users.charlie, users.charlie, atomId, DYN, c, 0);

        uint256 bobShares = protocol.multiVault.getShares(users.bob, atomId, DYN);
        uint256 toRedeem = (bobShares * redeemPct) / 100;
        if (toRedeem > 0 && bobShares - toRedeem >= MIN_SHARES) {
            redeemShares(users.bob, users.bob, atomId, DYN, toRedeem, 0);
        }

        uint256 obligations = dynamicFeeCurve.claimable(users.alice, atomId)
            + dynamicFeeCurve.claimable(users.bob, atomId) + dynamicFeeCurve.claimable(users.charlie, atomId)
            + dynamicFeeCurve.protocolAccrued();

        assertGe(address(dynamicFeeCurve).balance, obligations, "curve must cover every fee obligation it owes");
        _assertPar(atomId);
    }

    /// @dev Claiming can never pay a user more than the curve's whole balance, and draining everyone plus
    ///      the protocol sweep leaves no negative residue.
    function test_solvency_fullDrainLeavesNoDeficit() external {
        bytes32 atomId = _atom("drain");
        makeDeposit(users.alice, users.alice, atomId, DYN, 20e18, 0);
        makeDeposit(users.bob, users.bob, atomId, DYN, 15e18, 0);
        makeDeposit(users.charlie, users.charlie, atomId, DYN, 10e18, 0);
        redeemShares(users.charlie, users.charlie, atomId, DYN, 5e18, 0);

        _claim(users.alice, atomId);
        _claim(users.bob, atomId);
        _claim(users.charlie, atomId);

        resetPrank(users.admin);
        if (dynamicFeeCurve.protocolAccrued() > 0) {
            dynamicFeeCurve.sweepProtocol(users.admin);
        }

        // Whatever remains is unattributable accumulator dust — strictly less than one wei per share unit.
        assertLe(address(dynamicFeeCurve).balance, 1e6, "no material funds stranded after full drain + sweep");
    }

    /* =================================================== */
    /*                 LIVE FEE-CHANGE ABUSE             */
    /* =================================================== */

    /// @dev Retuning the schedule must not re-price balances that were already accrued under the old one.
    function test_liveFeeChange_doesNotRepriceAccruedBalances() external {
        bytes32 atomId = _atom("retune");
        makeDeposit(users.alice, users.alice, atomId, DYN, 8e18, 0);
        makeDeposit(users.bob, users.bob, atomId, DYN, 8e18, 0); // alice's tier earns bob's deposit fee

        uint256 accruedBefore = dynamicFeeCurve.claimable(users.alice, atomId);
        assertGt(accruedBefore, 0, "alice has accrued earnings");

        DynamicFeeConfig memory cfg = dynamicFeeCurve.getConfig();
        cfg.depositBaseBps = 500;
        cfg.withdrawalBaseBps = 500;
        resetPrank(users.admin);
        dynamicFeeCurve.setConfig(cfg);

        assertEq(
            dynamicFeeCurve.claimable(users.alice, atomId),
            accruedBefore,
            "a retune must never re-price already-accrued balances"
        );
    }

    /// @dev Governance bounds hold under abuse: cap above BPS, a tier-count shrink, and a non-owner call
    ///      are all rejected.
    function test_liveFeeChange_governanceBoundsEnforced() external {
        DynamicFeeConfig memory cfg = dynamicFeeCurve.getConfig();

        resetPrank(users.admin);
        cfg.depositCapBps = BASIS_POINTS_DIVISOR + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(cfg);

        cfg = dynamicFeeCurve.getConfig();
        cfg.tierCount = cfg.tierCount - 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_TierCountCannotShrink.selector);
        dynamicFeeCurve.setConfig(cfg);

        // Pre-evaluate the config read so `expectRevert` binds to `setConfig`, not the view call.
        DynamicFeeConfig memory validCfg = dynamicFeeCurve.getConfig();
        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", users.alice));
        dynamicFeeCurve.setConfig(validCfg);
    }
}
