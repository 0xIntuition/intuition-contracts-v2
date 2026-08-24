// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  DynamicFeeThirteenTierExampleTest
/// @notice The 13-tier default schedule as an EXECUTABLE worked example, for demos and modeling
///         hand-off. Everything here is deliberately written to be read: literal tier edges, the
///         full fee table, one manual override, and a narrated deposit -> earn -> claim walkthrough
///         with exact numbers. The mechanism itself is specified on {DynamicFeeFlatPriceCurve};
///         these numbers are one illustrative schedule, not a normative reference.
///
/// @dev    Shape: 13 tiers, geometric width growth (`growthG = 0.5`, i.e. each band is 1.5x the one
///         below it), tiers 0-5 deliberately small (they cover the first ~20.8k TRUST of a ~257k
///         ladder) and a MASSIVE top tier — tier 12 is terminal and absorbs everything past ~257k
///         TRUST, unbounded.
///
///         Compounding is what produces that shape: widths run 1,000 -> 1,500 -> 2,250 -> ... ->
///         86,498, so the early bands stay dense while the ladder stretches asymptotically. The tier
///         count (13) and the fee-schedule form (formula + sparse override) are locked; the width
///         numbers here remain a reference fixture rather than the final production calibration.
///
///         Driven in isolation: the test contract stands in as the authorized MultiVault and calls the
///         record hooks directly, forwarding the fee as native value.
contract DynamicFeeThirteenTierExampleTest is Test {
    DynamicFeeFlatPriceCurve internal dynamicFeeCurve;

    address internal proxyAdmin = address(0xAD);
    address internal owner = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";
    uint256 internal constant TIER_COUNT = 13;
    uint256 internal constant TOP_TIER = TIER_COUNT - 1;

    /// @dev The one manual override in the worked example: the massive top tier charges a flat 10% in
    ///      and out rather than the formula's 7% / 8%, so parking in the terminal band is deliberately
    ///      expensive on both sides.
    uint256 internal constant OVERRIDDEN_TIER = TOP_TIER;
    uint16 internal constant OVERRIDDEN_DEPOSIT_BPS = 1000;
    uint16 internal constant OVERRIDDEN_WITHDRAWAL_BPS = 1000;

    bytes32 internal constant TERM = keccak256("thirteen-tier-example");

    function setUp() public {
        dynamicFeeCurve = _deploy(_thirteenTierDefaultConfig());
        vm.deal(address(this), 1_000_000e18);
    }

    /* =================================================== */
    /*                      FIXTURE                        */
    /* =================================================== */

    /// @notice The 13-tier default schedule.
    /// @dev    `width0 = 1000 TRUST`, `growthG = 0.5` (tierWidthGrowthBps = 5000) compounds each band to 1.5x
    ///         the one below it — widths 1000, 1500, 2250, 3375, ... — giving the cumulative edges
    ///         asserted in {test_thirteenTierConfig_tierEdges}. Deposit fee 1% + 0.5%/tier, redeem fee
    ///         2% + 0.5%/tier, both capped at 10% (the cap never binds inside 13 tiers — the
    ///         schedule is fully expressed by the formula). Fee distribution: triangular fulcrum kernel,
    ///         alpha = BPS, sigma = 4e18 (the nearest-first window, ~50/33/17);
    ///         redeem fees route entirely to the leaver's own tier (pure diamond-hands).
    function _thirteenTierDefaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeConfig({
            width0: 1000e18,
            tierCount: TIER_COUNT,
            tierWidthGrowthBps: 5000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            fulcrumAlphaBps: 10_000,
            kernelSpread: 4e18,
            redeemBaseBps: 200,
            redeemGrowthBps: 50,
            redeemCapBps: 1000,
            redeemToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStake: 0
        });
    }

    /// @notice The worked example's manual overrides, applied on top of the formulaic schedule.
    function _applyThirteenTierOverrides(DynamicFeeFlatPriceCurve curve) internal {
        curve.setTierFeeOverride(OVERRIDDEN_TIER, OVERRIDDEN_DEPOSIT_BPS, OVERRIDDEN_WITHDRAWAL_BPS);
    }

    function _deploy(DynamicFeeConfig memory config) internal returns (DynamicFeeFlatPriceCurve) {
        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdmin,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector, CURVE_NAME, owner, address(this), config
            )
        );
        return DynamicFeeFlatPriceCurve(address(proxy));
    }

    /* =================================================== */
    /*                    TIER EDGES                       */
    /* =================================================== */

    /// @dev The full 13-tier ladder in TRUST. Tiers 0-5 are the "small" early bands (0 -> ~20.8k);
    ///      the ladder tops out at ~257.5k, past which the terminal tier 12 absorbs everything.
    ///      Each edge is the geometric series `1000 * (1.5^(k+1) - 1) / 0.5`.
    function test_thirteenTierConfig_tierEdges() external view {
        uint256[13] memory expectedEdges = [
            uint256(1000e18), // tier  0:       0 ->   1,000      (width  1,000)
            2500e18, // tier  1:   1,000 ->   2,500      (width  1,500)
            4750e18, // tier  2:   2,500 ->   4,750      (width  2,250)
            8125e18, // tier  3:   4,750 ->   8,125      (width  3,375)
            13_187.5e18, // tier  4:   8,125 ->  13,187.5    (width  5,062.5)
            20_781.25e18, // tier  5:  13,187.5 ->  20,781.25  (width  7,593.75)
            32_171.875e18, // tier  6:  20,781.25 ->  32,171.875 (width 11,390.625)
            49_257.8125e18, // tier  7:  32,171.875 ->  49,257.81  (width 17,085.94)
            74_886.71875e18, // tier  8:  49,257.81 ->  74,886.72  (width 25,628.91)
            113_330.078125e18, // tier  9:  74,886.72 -> 113,330.08  (width 38,443.36)
            170_995.1171875e18, // tier 10: 113,330.08 -> 170,995.12  (width 57,665.04)
            257_492.67578125e18, // tier 11: 170,995.12 -> 257,492.68  (width 86,497.56)
            387_239.013671875e18 // tier 12: 257,492.68 -> infinity (closed-form edge is inert; see below)
        ];

        for (uint256 tier = 0; tier < TIER_COUNT; ++tier) {
            assertEq(dynamicFeeCurve.tierUpperEdge(tier), expectedEdges[tier], "tier edge");
        }
    }

    function test_thirteenTierConfig_earlyTiersStaySmall() external view {
        // Tiers 0-5 cover only the first ~20.8k of the ~257k ladder: the early bands are where the
        // schedule is dense, so ordinary depositors move through several tiers before the fee bites.
        // Compounding is what keeps them dense — each band is only 1.5x the one below it, so the
        // ladder stays fine-grained exactly where most positions sit.
        assertEq(dynamicFeeCurve.tierUpperEdge(5), 20_781.25e18, "tiers 0-5 span the first ~20.8k TRUST");
        assertEq(dynamicFeeCurve.tierWidthAt(0), 1000e18, "width 0");
        assertEq(dynamicFeeCurve.tierWidthAt(5), 7593.75e18, "width 5 = 1000 * 1.5^5");
    }

    /// @dev The top tier is terminal and unbounded: `tierOf` caps at `tierCount - 1`, so every
    ///      position past the tier-11 edge (~257.5k) lands in tier 12 no matter how large. Geometric
    ///      growth is what makes that terminal band genuinely massive — tier 12's own width is
    ///      ~129.7k, more than the entire first eight tiers combined.
    function test_thirteenTierConfig_topTierIsMassiveAndTerminal() external view {
        assertEq(dynamicFeeCurve.tierOf(257_492e18), 11, "just below the ladder top");
        assertEq(dynamicFeeCurve.tierOf(257_492.67578125e18), TOP_TIER, "at the tier-11 edge -> terminal tier");
        assertEq(dynamicFeeCurve.tierOf(1_000_000e18), TOP_TIER, "1M TRUST -> still the terminal tier");
        assertEq(dynamicFeeCurve.tierOf(type(uint128).max), TOP_TIER, "the top tier absorbs everything");
        assertEq(dynamicFeeCurve.tierWidthAt(TOP_TIER), 129_746.337890625e18, "terminal band width");
    }

    /* =================================================== */
    /*                   FEE SCHEDULE                      */
    /* =================================================== */

    /// @dev The formulaic table across all 13 tiers, before any override. The 10% cap never binds
    ///      inside the ladder, so every tier's rate is exactly `base + tier*growth`.
    function test_thirteenTierConfig_formulaicFeeSchedule() external view {
        for (uint256 tier = 0; tier < TIER_COUNT; ++tier) {
            assertEq(dynamicFeeCurve.depositFeeBps(tier), 100 + tier * 50, "deposit fee = 1% + 0.5%/tier");
            assertEq(dynamicFeeCurve.redeemFeeBps(tier), 200 + tier * 50, "redeem fee = 2% + 0.5%/tier");
        }
        // Endpoints, spelled out: 1% -> 7% in, 2% -> 8% out.
        assertEq(dynamicFeeCurve.depositFeeBps(0), 100, "tier 0 deposit = 1%");
        assertEq(dynamicFeeCurve.depositFeeBps(TOP_TIER), 700, "tier 12 deposit = 7% (formula)");
        assertEq(dynamicFeeCurve.redeemFeeBps(TOP_TIER), 800, "tier 12 redeem = 8% (formula)");
    }

    /// @dev The worked example's single override: the terminal tier is re-priced to a flat 10%/10%.
    function test_thirteenTierConfig_scheduleWithOverride() external {
        _applyThirteenTierOverrides(dynamicFeeCurve);

        assertEq(dynamicFeeCurve.depositFeeBps(TOP_TIER), OVERRIDDEN_DEPOSIT_BPS, "top tier deposit overridden to 10%");
        assertEq(dynamicFeeCurve.redeemFeeBps(TOP_TIER), OVERRIDDEN_WITHDRAWAL_BPS, "top tier redeem overridden to 10%");
    }

    /// @dev The sparsity guarantee at full 13-tier width: the override touches tier 12 and NOTHING
    ///      else — all twelve other tiers stay exactly on the formula.
    function test_thirteenTierConfig_overrideLeavesAllOtherTwelveTiersOnFormula() external {
        _applyThirteenTierOverrides(dynamicFeeCurve);

        for (uint256 tier = 0; tier < TIER_COUNT; ++tier) {
            if (tier == OVERRIDDEN_TIER) continue;
            assertEq(dynamicFeeCurve.depositFeeBps(tier), 100 + tier * 50, "other tier keeps formulaic deposit");
            assertEq(dynamicFeeCurve.redeemFeeBps(tier), 200 + tier * 50, "other tier keeps formulaic redeem");
            (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(tier);
            assertFalse(isSet, "other tier carries no override");
        }
    }

    /* =================================================== */
    /*              DEPOSIT -> EARN -> CLAIM               */
    /* =================================================== */

    /// @notice The end-to-end economy on the 13-tier schedule, with exact numbers at every step.
    /// @dev    Narrated walkthrough:
    ///          1. alice deposits 1,500 TRUST into an empty vault. The vault's tier BEFORE her deposit
    ///             is 0, so she books entry tier 0 and pays nothing (no prior tier to pay).
    ///          2. Her deposit lifts the vault to 1,500 TRUST, which sits in tier 1 (past the 1,000
    ///             edge).
    ///          3. bob then deposits 900 TRUST from tier 1. It stays inside tier 1 (1,500 + 900 <
    ///             2,500), so the piecewise walk charges one band at tier 1's 1.5% = 13.5 TRUST.
    ///          4. That fee is distributed by the triangular fulcrum kernel over the occupied prior
    ///             tiers. The weights are normalized over the tiers that actually HOLD STAKE, not
    ///             over the whole window, so an absent tier's share is absorbed by the tiers that
    ///             qualified rather than leaking. Tier 0 (alice) is the only prior tier below tier 1,
    ///             so it takes the entire 13.5 TRUST and nothing reaches the protocol.
    ///          5. alice pulls her 13.5 TRUST. Nothing is lost: the contract's balance is exactly
    ///             what was claimed plus what the protocol accrued.
    function test_thirteenTierWalkthrough_depositEarnClaim() external {
        // 1. alice enters an empty vault at tier 0 and pays no fee.
        assertEq(dynamicFeeCurve.tierOf(0), 0, "empty vault sits in tier 0");
        dynamicFeeCurve.recordDeposit{ value: 0 }(TERM, alice, 1500e18);

        assertEq(dynamicFeeCurve.userTier(TERM, alice), 0, "alice books entry tier 0");
        assertEq(dynamicFeeCurve.userStake(TERM, alice), 1500e18, "alice's stake");

        // 2. Her deposit lifted the vault into tier 1.
        assertEq(dynamicFeeCurve.vaultStake(TERM), 1500e18, "vault holds alice's stake");
        assertEq(dynamicFeeCurve.tierOf(1500e18), 1, "vault is now in tier 1");

        // 3. bob's 900 TRUST stays inside tier 1 -> one band at 1.5%.
        uint256 bobFee = dynamicFeeCurve.quoteDepositFee(TERM, 900e18);
        assertEq(bobFee, 13.5e18, "900 TRUST at tier 1's 1.5%");

        // 4. The fee is distributed by the triangular kernel over the occupied prior tiers. Only tier 0
        //    (alice) holds stake, so it earns the whole fee — nothing leaks to protocol.
        dynamicFeeCurve.recordDeposit{ value: bobFee }(TERM, bob, 900e18);

        assertEq(dynamicFeeCurve.userTier(TERM, bob), 1, "bob books entry tier 1");
        assertEq(
            dynamicFeeCurve.claimable(alice, TERM), 13.5e18, "alice (sole occupied prior tier) earns the whole fee"
        );
        assertEq(dynamicFeeCurve.claimable(bob, TERM), 0, "bob earns nothing from his own fee");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "no leak: fee normalizes over occupied tiers");

        // 5. alice pulls her earnings; the contract's books balance exactly.
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = TERM;

        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        uint256 claimed = dynamicFeeCurve.claim(terms);

        assertEq(claimed, 13.5e18, "alice claims her full earnings");
        assertEq(alice.balance - aliceBalanceBefore, claimed, "paid out in native TRUST");
        assertEq(dynamicFeeCurve.claimable(alice, TERM), 0, "nothing left to claim");
        assertEq(address(dynamicFeeCurve).balance, bobFee - claimed, "residual balance == protocol accrual (0)");
        assertEq(address(dynamicFeeCurve).balance, dynamicFeeCurve.protocolAccrued(), "conservation: no TRUST lost");
    }

    /// @dev The same walkthrough's entry, but against the overridden terminal tier: a whale landing in
    ///      tier 12 pays the flat 10% override instead of the formula's 7%.
    function test_thirteenTierWalkthrough_overriddenTopTierRepricesWhaleEntry() external {
        _applyThirteenTierOverrides(dynamicFeeCurve);

        // Park the vault deep inside the terminal tier so the walk charges one (overridden) band.
        // The terminal band opens at ~257.5k under the compounding ladder.
        dynamicFeeCurve.recordDeposit{ value: 0 }(TERM, alice, 300_000e18);
        assertEq(dynamicFeeCurve.tierOf(300_000e18), TOP_TIER, "vault sits in the terminal tier");

        // 1,000 TRUST at the overridden 10% rather than the formulaic 7%.
        assertEq(dynamicFeeCurve.quoteDepositFee(TERM, 1000e18), 100e18, "whale entry pays the top-tier override");
        assertEq(dynamicFeeCurve.quoteRedeemFee(TERM, bob, 1000e18), 100e18, "whale exit pays the top-tier override");
    }

    /* =================================================== */
    /*                    GAS: FULL SWEEP                  */
    /* =================================================== */

    /// @notice Worst-case cost of the per-band deposit replay on the SHIPPED 13-tier ladder.
    /// @dev    A single deposit that sweeps the whole ladder runs one fee distribution and one
    ///         position move per band, so the work is O(bands x span) — the dominant term is the
    ///         accumulator writes, `sum(k) for k in 1..bands`. Recorded here because the 5-tier test
    ///         ladder understates it and this is the schedule that ships. The depositor pays it in
    ///         full; there is no path by which another account can be made to bear it.
    function test_thirteenTier_fullLadderSweepGas() external {
        // Populate the low bands so every distribution the sweep triggers has a cohort to credit,
        // which is the expensive path rather than the short-circuit to `protocolAccrued`.
        dynamicFeeCurve.recordDeposit{ value: 0 }(TERM, alice, 900e18);
        dynamicFeeCurve.recordDeposit{ value: 0 }(TERM, bob, 4000e18);

        uint256 sweep = 400_000e18; // past the ~257k terminal edge: every band is crossed
        uint256 fee = dynamicFeeCurve.quoteDepositFee(TERM, sweep);

        uint256 gasBefore = gasleft();
        dynamicFeeCurve.recordDeposit{ value: fee }(TERM, alice, sweep - fee);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("13-tier full-sweep recordDeposit gas", gasUsed);
        emit log_named_uint("depositor booked tier", dynamicFeeCurve.userTier(TERM, alice));

        // Loose ceiling: the point is to pin the ORDER of the cost so a regression that turns the
        // replay quadratic in something other than the tier count fails loudly.
        assertLt(gasUsed, 2_000_000, "a full 13-band sweep stays well inside a block");
    }
}
