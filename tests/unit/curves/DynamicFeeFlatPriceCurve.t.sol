// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  DynamicFeeFlatPriceCurveTest
/// @notice Unit tests for {DynamicFeeFlatPriceCurve}'s tier math and pull-based fee accounting, driven in
///         isolation: the test contract stands in as the authorized MultiVault and calls the record
///         hooks directly (forwarding the fee as native value), so the accounting is exercised without
///         MultiVault's own fee noise. Integration through the real MultiVault lives in
///         `tests/unit/MultiVault/DynamicFeeCurveRouting.t.sol`.
contract DynamicFeeFlatPriceCurveTest is Test {
    DynamicFeeFlatPriceCurve internal dynamicFeeCurve;

    address internal proxyAdmin = address(0xAD);
    address internal owner = address(this);
    // The test contract is the "MultiVault": it calls the record hooks.
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";
    uint256 internal constant BPS = 10_000;
    uint256 internal constant WAD = 1e18;

    bytes32 internal constant T1 = keccak256("term-1");
    bytes32 internal constant T2 = keccak256("term-2");

    event Claimed(address indexed account, uint256 amount);
    event DepositRecorded(bytes32 indexed termId, address indexed account, uint256 netStake, uint256 fee, uint256 tier);

    function setUp() public {
        dynamicFeeCurve = _deploy(_defaultConfig());
        vm.deal(address(this), 1_000_000e18);
    }

    /* =================================================== */
    /*                      HELPERS                        */
    /* =================================================== */

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

    /// @dev width0 = 10 TRUST, 5 tiers, g = 0.2. Deposit 1% +0.5%/tier (cap 10%), triangular fulcrum
    ///      alpha = BPS, sigma = 4e18 (nearest-first window),
    ///      withdrawal 2% +0.5%/tier, all → own tier. Widths compound at 1.2x: 10, 12, 14.4, 17.28,
    ///      20.736; edges: 10, 22, 36.4, 53.68, 74.416 (×1e18).
    function _defaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 5,
            growthGBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            fulcrumAlpha: 10_000,
            kernelSpread: 4e18,
            withdrawalBaseBps: 200,
            withdrawalGrowthBps: 50,
            withdrawalCapBps: 1000,
            withdrawalToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStake: 0
        });
    }

    function _recordDeposit(bytes32 termId, address account, uint256 netStake, uint256 fee) internal {
        dynamicFeeCurve.recordDeposit{ value: fee }(termId, account, netStake);
    }

    function _recordRedeem(bytes32 termId, address account, uint256 withdrawnStake, uint256 fee) internal {
        dynamicFeeCurve.recordRedeem{ value: fee }(termId, account, withdrawnStake);
    }

    /* =================================================== */
    /*                     TIER MATH                       */
    /* =================================================== */

    /// @dev Closed-form geometric series: `edge(k) = width0 * (1.2^(k+1) - 1) / 0.2`.
    function test_tierUpperEdge_matchesClosedForm() external view {
        assertEq(dynamicFeeCurve.tierUpperEdge(0), 10e18, "edge 0");
        assertEq(dynamicFeeCurve.tierUpperEdge(1), 22e18, "edge 1");
        assertEq(dynamicFeeCurve.tierUpperEdge(2), 36.4e18, "edge 2");
        assertEq(dynamicFeeCurve.tierUpperEdge(3), 53.68e18, "edge 3");
        assertEq(dynamicFeeCurve.tierUpperEdge(4), 74.416e18, "edge 4");
    }

    /// @dev Each band compounds on the one below it: `width(k) = width0 * 1.2^k`. Tiers 0 and 1 happen
    ///      to coincide with a linear ramp; the divergence starts at tier 2 (14.4 vs a linear 14).
    function test_tierWidthAt_growsGeometrically() external view {
        assertEq(dynamicFeeCurve.tierWidthAt(0), 10e18, "width 0");
        assertEq(dynamicFeeCurve.tierWidthAt(1), 12e18, "width 1 = 10 * 1.2");
        assertEq(dynamicFeeCurve.tierWidthAt(2), 14.4e18, "width 2 = 10 * 1.2^2");
        assertEq(dynamicFeeCurve.tierWidthAt(3), 17.28e18, "width 3 = 10 * 1.2^3");
        // Each width is exactly 1.2x its predecessor — the defining property of the ladder.
        for (uint256 k = 1; k < 5; ++k) {
            assertEq(
                dynamicFeeCurve.tierWidthAt(k),
                (dynamicFeeCurve.tierWidthAt(k - 1) * 12) / 10,
                "each band compounds on the previous one"
            );
        }
    }

    /// @dev Two ladder invariants across the whole schedulable domain, INCLUDING non-exactly-
    ///      representable ratios (e.g. g = 0.0001, where `(1+g)^k` is irrational in fixed point):
    ///        1. Edges strictly increase — a wraparound or flat step would make `tierOf` ambiguous
    ///           and could strand positions.
    ///        2. The advertised width equals the fee-charged band: `tierWidthAt(k) == edge(k) -
    ///           edge(k-1)`. The piecewise fee walk charges each band by its edge span, so the public
    ///           width view must agree with it to the wei — a width computed from an independently
    ///           rounded `(1+g)^k` would drift from the real band and misreport what a depositor pays.
    function testFuzz_tierLadder_invariants(uint256 width0, uint256 growthGBps, uint256 tierCount) external {
        width0 = bound(width0, 1, 1e30);
        growthGBps = bound(growthGBps, 0, 100 * 10_000);
        tierCount = bound(tierCount, 1, dynamicFeeCurve.MAX_TIER_COUNT());

        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = width0;
        config.growthGBps = growthGBps;
        config.tierCount = tierCount;

        // An over-steep schedule is rejected at config time; that is the guarantee under test.
        try this.deployWithConfig(config) returns (DynamicFeeFlatPriceCurve curve) {
            uint256 previousEdge = curve.tierUpperEdge(0);
            assertGt(previousEdge, 0, "edge 0 is positive");
            assertEq(curve.tierWidthAt(0), previousEdge, "width 0 == edge 0");
            for (uint256 k = 1; k < tierCount; ++k) {
                uint256 edge = curve.tierUpperEdge(k);
                assertGt(edge, previousEdge, "edges strictly increase");
                assertEq(curve.tierWidthAt(k), edge - previousEdge, "width == edge delta (no rounding drift)");
                previousEdge = edge;
            }
        } catch (bytes memory reason) {
            // A rejected config is acceptable ONLY when it is an overflow of the compounding math
            // (the config-time top-edge probe firing) or the contract's own config guard. A Panic
            // (underflow / div-by-zero) or any other selector is a real regression, so assert the
            // reason rather than swallowing every revert.
            _assertExpectedConfigRejection(reason);
        }
    }

    /// @dev Allowlist of revert selectors an admissible-but-oversized config may legitimately produce:
    ///      the fixed-point overflow guards hit by the compounding edge math, plus the curve's own
    ///      `InvalidConfig`. Anything else (notably a `Panic`) fails the fuzz.
    function _assertExpectedConfigRejection(bytes memory reason) internal pure {
        bytes4 selector = bytes4(reason);
        assertTrue(
            selector == FixedPointMathLib.RPowOverflow.selector
                || selector == FixedPointMathLib.FullMulDivFailed.selector
                || selector == FixedPointMathLib.MulWadFailed.selector
                || selector == DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector,
            "unexpected revert reason on rejected config"
        );
    }

    /// @dev The width-equals-edge-delta invariant, pinned on a schedule whose `(1+g)^k` is NOT exactly
    ///      representable in fixed point (g = 0.0001, 64 tiers). This is the case the deployed g = 0.2
    ///      schedule masks: 1.2 happens to be exact, so an independently-rounded width formula would
    ///      still match there while drifting here. Deriving width from the edge makes them agree.
    function test_tierWidthAt_matchesEdgeDelta_onNonExactRatio() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 1e18;
        config.growthGBps = 1; // g = 0.0001 -> (1+g)^k is irrational in WAD
        config.tierCount = dynamicFeeCurve.MAX_TIER_COUNT();
        DynamicFeeFlatPriceCurve curve = _deploy(config);

        assertEq(curve.tierWidthAt(0), curve.tierUpperEdge(0), "width 0 == edge 0");
        for (uint256 k = 1; k < config.tierCount; ++k) {
            assertEq(
                curve.tierWidthAt(k),
                curve.tierUpperEdge(k) - curve.tierUpperEdge(k - 1),
                "width == edge delta at every tier"
            );
        }
    }

    /// @dev The exact deployed 13-tier production schedule (`width0 = 5000 TRUST`, `growthGBps = 2000`):
    ///      pin the edges, the widths as edge deltas, and that the widths sum to the top edge. This is
    ///      the schedule that actually ships, so it gets an explicit fixture rather than only fuzz
    ///      coverage. Terminal tier 12 begins at the tier-11 edge (~197,903 TRUST); tier 12's own
    ///      closed-form edge (~242,483 TRUST) is inert since `tierOf` caps at the terminal tier.
    function test_deployedProductionSchedule_edgesWidthsAndSum() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 5000e18;
        config.growthGBps = 2000; // g = 0.2
        config.tierCount = 13;
        DynamicFeeFlatPriceCurve curve = _deploy(config);

        uint256[13] memory expectedEdges = [
            uint256(5000e18),
            11_000e18,
            18_200e18,
            26_840e18,
            37_208e18,
            49_649.6e18,
            64_579.52e18,
            82_495.424e18,
            103_994.5088e18,
            129_793.41056e18,
            160_752.092672e18,
            197_902.5112064e18,
            242_483.01344768e18
        ];

        uint256 widthSum;
        uint256 previousEdge;
        for (uint256 k = 0; k < 13; ++k) {
            assertEq(curve.tierUpperEdge(k), expectedEdges[k], "production edge");
            assertEq(curve.tierWidthAt(k), expectedEdges[k] - previousEdge, "production width == edge delta");
            widthSum += curve.tierWidthAt(k);
            previousEdge = expectedEdges[k];
        }
        // The widths partition the ladder exactly: their sum is the top (inert) edge, no dust.
        assertEq(widthSum, expectedEdges[12], "widths sum to the top edge");

        // Terminal-tier boundary: everything from the tier-11 edge up lands in tier 12.
        assertEq(curve.tierOf(197_902.5112064e18), 12, "tier-11 edge -> terminal tier");
        assertEq(curve.tierOf(197_902.5112064e18 - 1), 11, "one wei below -> tier 11");
    }

    /// @dev End-to-end: the piecewise deposit fee for a ladder-spanning deposit equals the sum over
    ///      bands of `width(k) * rate(k)` (each rounded up, as the contract does per chunk). This ties
    ///      the width view to the fee the walk actually charges — if the two ever diverged (independent
    ///      rounding of width vs edge), this equality would break.
    function test_piecewiseFee_matchesWidthTimesRatePerBand() external view {
        // Default schedule: edges 10/22/36.4/53.68/74.416. A 200e18 deposit from empty fills all four
        // finite bands and lands deep in the terminal tier 4, which absorbs the remainder.
        uint256 amount = 200e18;
        uint256 topTier = 4;
        uint256 expected;
        uint256 covered;
        for (uint256 k = 0; k <= topTier; ++k) {
            uint256 band = k < topTier ? dynamicFeeCurve.tierWidthAt(k) : amount - covered;
            expected += _mulDivUp(band, dynamicFeeCurve.depositFeeBps(k), BPS);
            covered += band;
        }
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, amount), expected, "piecewise fee == sum(width*rate) per band");
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) private pure returns (uint256) {
        return (x * y + d - 1) / d;
    }

    /// @dev External wrapper so the fuzz test can `try` the deployment (config may be rejected).
    function deployWithConfig(DynamicFeeConfig memory config) external returns (DynamicFeeFlatPriceCurve) {
        return _deploy(config);
    }

    /// @dev `growthGBps = 0` degenerates to a flat ladder: every band is exactly `width0` wide and the
    ///      edges are plain multiples. The closed form divides by `g`, so this case is handled
    ///      explicitly rather than falling into a division by zero.
    function test_tierMath_zeroGrowthGivesConstantWidths() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.growthGBps = 0;
        DynamicFeeFlatPriceCurve flatCurve = _deploy(config);

        for (uint256 k = 0; k < 5; ++k) {
            assertEq(flatCurve.tierWidthAt(k), 10e18, "every band is width0 wide");
            assertEq(flatCurve.tierUpperEdge(k), 10e18 * (k + 1), "edges are plain multiples of width0");
        }
        assertEq(flatCurve.tierOf(25e18), 2, "tier lookup still partitions the ladder");
    }

    /// @dev An over-steep schedule would overflow the compounding math on the deposit/redeem hot path,
    ///      bricking `tierOf` for every position. The config-time top-edge probe forces that overflow
    ///      to happen during configuration instead — so the schedule is rejected before any position
    ///      exists, rather than after.
    function test_setConfig_revertsOnOverSteepSchedule() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = type(uint128).max;
        config.tierCount = dynamicFeeCurve.MAX_TIER_COUNT();
        config.growthGBps = 100 * BPS; // 100x per tier, compounded 64 times

        vm.expectRevert(FixedPointMathLib.RPowOverflow.selector);
        this.deployWithConfig(config);
    }

    function test_tierOf_boundaries() external view {
        assertEq(dynamicFeeCurve.tierOf(0), 0, "empty -> 0");
        assertEq(dynamicFeeCurve.tierOf(9e18), 0, "just below edge 0");
        assertEq(dynamicFeeCurve.tierOf(10e18), 1, "at edge 0 -> tier 1");
        assertEq(dynamicFeeCurve.tierOf(21e18), 1, "inside tier 1");
        assertEq(dynamicFeeCurve.tierOf(22e18), 2, "at edge 1 -> tier 2");
        assertEq(dynamicFeeCurve.tierOf(1000e18), 4, "far past top -> capped at tierCount-1");
    }

    function test_depositFeeBps_growsAndCaps() external view {
        assertEq(dynamicFeeCurve.depositFeeBps(0), 100, "tier 0 = base");
        assertEq(dynamicFeeCurve.depositFeeBps(1), 150, "tier 1 = base + growth");
        assertEq(dynamicFeeCurve.depositFeeBps(4), 300, "tier 4");
        assertEq(dynamicFeeCurve.depositFeeBps(100), 1000, "far tier caps at 10%");
    }

    function test_withdrawalFeeBps_growsAndCaps() external view {
        assertEq(dynamicFeeCurve.withdrawalFeeBps(0), 200, "tier 0 = base");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(2), 300, "tier 2");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(1000), 1000, "caps at 10%");
    }

    function test_quoteDepositFee_singleBand_usesBandRate() external {
        // Empty vault, deposit fits inside tier 0 -> flat 1%.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 5e18), 0.05e18, "tier-0 band rate");
        // Vault mid tier 1 (15 < 22), deposit fits in the remaining band room (7) -> flat 1.5%.
        _recordDeposit(T1, alice, 15e18, 0);
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 5e18), 0.075e18, "tier-1 band rate");
    }

    /// @dev Rates by tier: 100/150/200/250/300 bps; band widths compound at 1.2x — 10/12/14.4/17.28
    ///      with the top tier absorbing the rest. A lump crossing several tiers pays each band's own
    ///      rate.
    function test_quoteDepositFee_piecewiseAcrossTraversedTiers() external {
        // From empty: 10@1% + 12@1.5% + 14.4@2% + 17.28@2.5% + 46.32@3% = 2.3896e18.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.3896e18, "piecewise blend from tier 0");

        _recordDeposit(T1, alice, 15e18, 0); // vault now mid tier 1
        // From 15: 7@1.5% + 14.4@2% + 17.28@2.5% + 61.32@3% = 2.6646e18.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.6646e18, "piecewise blend from a mid-band cursor");
    }

    function test_quoteDepositFee_lumpNotCheaperThanStartTierRate() external view {
        // The blended fee is never below charging the whole amount at the entry band's rate —
        // the regressive lump-vs-chunk discount is gone.
        assertGe(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 1e18, "no lump discount vs tier-0 flat rate");
    }

    /// @dev Tiers are half-open intervals [lowerEdge, upperEdge): the upper edge of tier k IS the
    ///      lower edge of tier k+1 and belongs exclusively to tier k+1. Every asset level maps to
    ///      exactly one tier — no overlap, no gap, no ambiguous boundary.
    function test_tierOf_edgesAreHalfOpen_noOverlapNoGap() external view {
        for (uint256 k = 0; k < 4; k++) {
            uint256 upperEdge = dynamicFeeCurve.tierUpperEdge(k);
            assertEq(dynamicFeeCurve.tierOf(upperEdge - 1), k, "one wei below the upper edge belongs to tier k");
            assertEq(dynamicFeeCurve.tierOf(upperEdge), k + 1, "the upper edge itself belongs to tier k+1");
        }
        // The top tier is closed above: everything at or past the last edge stays in tierCount-1.
        assertEq(
            dynamicFeeCurve.tierOf(dynamicFeeCurve.tierUpperEdge(4)), 4, "top tier absorbs everything above its edge"
        );
    }

    function testFuzz_tierOf_isMonotonic(uint256 a, uint256 b) external view {
        a = bound(a, 0, 500e18);
        b = bound(b, a, 500e18);
        assertLe(dynamicFeeCurve.tierOf(a), dynamicFeeCurve.tierOf(b), "tierOf must be non-decreasing");
    }

    /* =================================================== */
    /*                DEPOSIT DISTRIBUTION                 */
    /* =================================================== */

    function test_recordDeposit_firstDepositorHasNoPriorTier_feeToProtocol() external {
        _recordDeposit(T1, alice, 5e18, 1e18);
        assertEq(dynamicFeeCurve.protocolAccrued(), 1e18, "no prior tier -> whole fee to protocol");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "depositor earns nothing from own fee");
        assertEq(dynamicFeeCurve.userStake(T1, alice), 5e18, "stake tracked");
        assertEq(dynamicFeeCurve.vaultAssets(T1), 5e18, "vault assets tracked");
    }

    function test_recordDeposit_feeFlowsToPriorTier() external {
        // alice enters at tier 0 (10e18 keeps the tier-0 stake evenly divisible -> no rounding dust).
        _recordDeposit(T1, alice, 10e18, 0); // vaultAssets 0 -> 10 (now tier 1)
        assertEq(dynamicFeeCurve.userTier(T1, alice), 0, "alice bucket 0");

        // bob deposits while the vault sits in tier 1: the fee is distributed by the triangular kernel
        // over the OCCUPIED prior tiers. Only tier 0 (alice) holds stake, so weights normalize over
        // that single tier and it earns the whole pool — nothing leaks to protocol.
        _recordDeposit(T1, bob, 12e18, 1e18);

        assertEq(dynamicFeeCurve.claimable(alice, T1), 1e18, "alice (sole occupied prior tier) earns the whole fee");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "no leak: the fee normalizes over occupied tiers");
        assertEq(dynamicFeeCurve.claimable(bob, T1), 0, "bob earns nothing yet");
        assertEq(dynamicFeeCurve.userTier(T1, bob), 1, "bob bucket 1");
    }

    function test_recordDeposit_depositorExcludedFromOwnFee() external {
        // Seed: alice at tier 0, bob at tier 1.
        _recordDeposit(T1, alice, 15e18, 0); // -> vaultAssets 15 (tier 1)
        _recordDeposit(T1, bob, 12e18, 1e18); // bob at tier 1; vaultAssets 27 (tier 2)
        uint256 aliceBefore = dynamicFeeCurve.claimable(alice, T1);

        // bob deposits again while the vault is in tier 2. tier 1 is bob's OWN bucket and he is its only
        // holder, so excluding him zeroes that tier's recipient stake; the kernel then normalizes over
        // the remaining occupied tier (tier 0 = alice), which earns the whole pool. bob earns nothing
        // from his own fee, and nothing leaks to protocol.
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();
        _recordDeposit(T1, bob, 12e18, 1e18);

        assertEq(dynamicFeeCurve.claimable(bob, T1), 0, "bob excluded from his own deposit fee");
        // ~1e18 to alice (a few wei short from the standard accumulator flooring, which stays as
        // in-contract dust — NOT routed to protocol).
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1) - aliceBefore,
            1e18,
            1e3,
            "the excluded slice redistributes to the other occupied tier (alice), not the protocol"
        );
        assertEq(dynamicFeeCurve.protocolAccrued(), protocolBefore, "no leak to protocol");
    }

    function test_recordDeposit_avgEntryTierMovesBucket() external {
        // bob enters at tier 0; carol then pushes the vault up to tier 2.
        _recordDeposit(T1, bob, 5e18, 0); // bob bucket 0
        assertEq(dynamicFeeCurve.userTier(T1, bob), 0, "bob starts in bucket 0");
        _recordDeposit(T1, carol, 20e18, 0); // vaultAssets 25 -> tier 2

        // A follow-on deposit while the vault sits in tier 2 lifts bob's stake-weighted average so his
        // whole position migrates from bucket 0 to bucket 2.
        _recordDeposit(T1, bob, 20e18, 0);
        assertEq(dynamicFeeCurve.userTier(T1, bob), 2, "bob migrated to bucket 2");
        assertEq(dynamicFeeCurve.tierStake(T1, 0), 20e18, "only carol remains in tier 0");
        assertEq(dynamicFeeCurve.tierStake(T1, 2), 25e18, "bob's whole stake moved to tier 2");
    }

    /* =================================================== */
    /*             FULCRUM DISTRIBUTION KERNEL            */
    /* =================================================== */

    /// @dev Seed one equal-purpose holder in each of tiers 0..3 (climbing the vault to tier 4 with the
    ///      default geometric bands), then release a `pool` fee from a fresh tier-4 depositor under the
    ///      given (alpha, sigma). One holder per tier means each holder's claimable IS that tier's
    ///      normalized kernel share (intra-tier pro-rata is a no-op), so the returned tuple is the raw
    ///      per-tier distribution. Prior-tier distances from the source (tier 4): alice(tier0)=d4,
    ///      bob(tier1)=d3, carol(tier2)=d2, dave(tier3)=d1.
    function _distributeFromTierFour(uint256 alpha, uint256 sigma, uint256 pool)
        internal
        returns (uint256 tier0, uint256 tier1, uint256 tier2, uint256 tier3)
    {
        return _distributeFromTierFourWithSpike(alpha, sigma, 0, pool);
    }

    /// @dev As {_distributeFromTierFour}, but routes a `shareBps` slice of the released fee as a
    ///      lump to the nearest occupied prior tier (the deposit "prior-tier" spike) before spreading
    ///      the remainder by the fulcrum. `shareBps = 0` is the pure-fulcrum path the base helper
    ///      uses.
    function _distributeFromTierFourWithSpike(uint256 alpha, uint256 sigma, uint256 shareBps, uint256 pool)
        internal
        returns (uint256 tier0, uint256 tier1, uint256 tier2, uint256 tier3)
    {
        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = alpha;
        config.kernelSpread = sigma;
        config.depositToPriorTierBps = shareBps;
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // enters tier 0; vault -> tier 1
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // enters tier 1; vault -> tier 2
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // enters tier 2; vault -> tier 3
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // enters tier 3; vault -> tier 4
        c.recordDeposit{ value: pool }(T1, eve, 20.736e18); // enters tier 4; releases `pool` downward

        return (c.claimable(alice, T1), c.claimable(bob, T1), c.claimable(carol, T1), c.claimable(dave, T1));
    }

    /// @dev alpha = BPS puts the fulcrum on the source (dStar = 0): weights descend with distance and,
    ///      at sigma = 4, land on the nearest three tiers at 50 / 33.3 / 16.7 — the legacy nearest-first
    ///      window. The fourth tier (d = 4 = sigma) is exactly zero.
    function test_fulcrum_alphaOne_nearestFirstWindow() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFour(BPS, 4e18, 6e18);
        assertApproxEqAbs(t3, 3e18, 1e4, "nearest tier (d=1) earns 50%");
        assertApproxEqAbs(t2, 2e18, 1e4, "d=2 earns 33.3%");
        assertApproxEqAbs(t1, 1e18, 1e4, "d=3 earns 16.7%");
        assertEq(t0, 0, "d=4 == sigma earns nothing (hard zero)");
        assertGt(t3, t2, "strictly descending: d1 > d2");
        assertGt(t2, t1, "strictly descending: d2 > d3");
    }

    /// @dev alpha = 0 puts the fulcrum at the far end (dStar = span): the FARTHEST occupied tier (the
    ///      earliest holders) earns the most, ascending with distance. At sigma = 4 the four tiers land
    ///      at 10 / 20 / 30 / 40 %.
    function test_fulcrum_alphaZero_farthestFirst() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFour(0, 4e18, 10e18);
        assertApproxEqAbs(t0, 4e18, 1e4, "farthest tier (d=4) earns 40%");
        assertApproxEqAbs(t1, 3e18, 1e4, "d=3 earns 30%");
        assertApproxEqAbs(t2, 2e18, 1e4, "d=2 earns 20%");
        assertApproxEqAbs(t3, 1e18, 1e4, "nearest (d=1) earns 10%");
        assertGt(t0, t3, "farthest earns more than nearest");
    }

    /// @dev alpha = 0.5 (BPS/2) puts the fulcrum mid-span (dStar = 2 tiers): the peak sits on the
    ///      middle tier (d = 2), symmetric falloff either side.
    function test_fulcrum_alphaHalf_peaksMid() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFour(BPS / 2, 4e18, 6e18);
        assertGt(t2, t3, "peak tier (d=2) beats its nearer neighbor (d=1)");
        assertGt(t2, t1, "peak tier (d=2) beats its farther neighbor (d=3)");
        assertApproxEqAbs(t2, 2e18, 1e4, "peak (d=2) earns 33.3%");
        // d=1 and d=3 are equidistant from the fulcrum -> equal weight.
        assertApproxEqAbs(t3, t1, 1e4, "symmetric: d=1 and d=3 earn equally");
    }

    /// @dev Anti-leak degenerate guard: a fulcrum landing strictly BETWEEN occupied tiers with a
    ///      sub-tier sigma zeroes every tier's weight (no integer distance falls inside the window).
    ///      Rather than forfeit the pool to the protocol, the whole pot must be awarded to the occupied
    ///      tier nearest the fulcrum (nearest-first on ties). Here dStar = 2.5 (alpha = 3750 over span
    ///      4) sits exactly between d = 2 (carol) and d = 3 (bob); with sigma = 0.4 every weight is 0,
    ///      and the tie breaks to the tier reached first in the nearest-first scan (d = 2, carol).
    function test_fulcrum_degenerateGuard_awardsNearestNotProtocol() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = 3750; // dStar = (1 - 0.375) * 4 = 2.5 tiers from the source
        config.kernelSpread = 0.4e18; // window ±0.4 tier -> no integer distance lands inside it
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-degen");
        address eve = makeAddr("eve-degen");
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // tier 0
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // tier 1 (d = 3)
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // tier 2 (d = 2)
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // tier 3

        c.recordDeposit{ value: 5e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(c.claimable(carol, T1), 5e18, 1e4, "guard awards the pool to the nearest occupied tier");
        assertEq(c.claimable(bob, T1), 0, "the tied-but-later tier gets nothing (nearest-first)");
        assertEq(c.claimable(alice, T1), 0, "no other tier earns");
        assertEq(c.claimable(dave, T1), 0, "no other tier earns");
        assertEq(c.protocolAccrued(), 0, "no leak to protocol");
    }

    /// @dev Conservation: the whole fee stays custodied by the curve, and the sum of what is claimable
    ///      plus what accrued to the protocol never exceeds the pool (the shortfall is bounded
    ///      accumulator dust), for any alpha / sigma / pool.
    function testFuzz_fulcrum_conservation(uint256 alpha, uint256 sigma, uint256 pool) external {
        alpha = bound(alpha, 0, BPS);
        sigma = bound(sigma, 1, 64e18);
        pool = bound(pool, 1, 1_000_000e18);

        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = alpha;
        config.kernelSpread = sigma;
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-fuzz");
        address eve = makeAddr("eve-fuzz");
        vm.deal(address(this), pool + 1e18);
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 12e18);
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18);
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18);

        c.recordDeposit{ value: pool }(T1, eve, 20.736e18);

        // The entire fee is held by the curve — nothing is lost or paid out yet.
        assertEq(address(c).balance, pool, "curve custodies the whole fee");

        uint256 distributed = c.claimable(alice, T1) + c.claimable(bob, T1) + c.claimable(carol, T1)
            + c.claimable(dave, T1) + c.protocolAccrued();
        assertLe(distributed, pool, "never distributes more than the pool");
        // Shortfall is bounded accumulator dust: < ~1 wei per occupied tier's stake/ACC ratio.
        assertGe(distributed + 100, pool, "distributes essentially all of the pool (only dust lost)");
    }

    /* =================================================== */
    /*             DEPOSIT RECENT-TIER SPIKE             */
    /* =================================================== */

    /// @dev A `depositToPriorTierBps` slice is paid as a lump to the nearest occupied prior tier
    ///      (here dave at d = 1) ON TOP OF that tier's fulcrum share, so the nearest tier earns
    ///      disproportionately while the rest of the ladder still receives the fulcrum spread. With a
    ///      50% spike over an 8e18 pool: dave earns 4e18 (spike) + 2e18 (fulcrum) = 6e18, carol
    ///      1.333e18, bob 0.667e18, alice 0.
    function test_depositToPriorTier_spikesNearestPriorTier() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFourWithSpike(BPS, 4e18, 5000, 8e18);
        assertApproxEqAbs(t3, 6e18, 1e6, "nearest tier earns the spike lump plus its fulcrum share");
        assertApproxEqAbs(t2, 1.333e18, 1e15, "d=2 earns its fulcrum share of the remainder");
        assertApproxEqAbs(t1, 0.667e18, 1e15, "d=3 earns its fulcrum share of the remainder");
        assertEq(t0, 0, "d=4 == sigma still earns nothing");
        assertGt(t3, t2 + t1, "the spike makes the nearest tier dominate");
    }

    /// @dev A full (100%) spike sends the whole fee to the single nearest occupied prior tier; the
    ///      fulcrum slice is empty, so no other tier earns and nothing leaks to the protocol.
    function test_depositToPriorTier_fullShareAllToNearest() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFourWithSpike(BPS, 4e18, BPS, 8e18);
        assertApproxEqAbs(t3, 8e18, 1e6, "the nearest occupied prior tier takes the whole fee");
        assertEq(t2, 0, "no fulcrum spread when the spike is 100%");
        assertEq(t1, 0, "no fulcrum spread when the spike is 100%");
        assertEq(t0, 0, "no fulcrum spread when the spike is 100%");
    }

    /// @dev Zero share is the default and reduces to a pure fulcrum distribution — byte-for-byte the
    ///      pre-split behavior (compare {test_fulcrum_alphaOne_nearestFirstWindow}).
    function test_depositToPriorTier_zeroReproducesPureFulcrum() external {
        (uint256 t0, uint256 t1, uint256 t2, uint256 t3) = _distributeFromTierFourWithSpike(BPS, 4e18, 0, 6e18);
        assertApproxEqAbs(t3, 3e18, 1e4, "d=1 earns 50% (pure fulcrum)");
        assertApproxEqAbs(t2, 2e18, 1e4, "d=2 earns 33.3% (pure fulcrum)");
        assertApproxEqAbs(t1, 1e18, 1e4, "d=3 earns 16.7% (pure fulcrum)");
        assertEq(t0, 0, "d=4 earns nothing (pure fulcrum)");
    }

    /// @dev The spike targets the nearest OCCUPIED prior tier and excludes the depositor's own stake:
    ///      when dave (tier 3) tops up from tier 4, his own tier is skipped and the 100% spike lands on
    ///      the next occupied prior tier (carol, tier 2). dave earns nothing from his own fee.
    function test_depositToPriorTier_excludesDepositorTierAndSkipsToNextOccupied() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = BPS;
        config.kernelSpread = 4e18;
        config.depositToPriorTierBps = BPS; // 100% spike -> unambiguous routing target
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-skip");

        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // tier 0
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // tier 1
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // tier 2
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // tier 3; vault -> tier 4

        // dave tops up from tier 4; his own tier (3) is excluded, so the spike skips it to carol (tier 2).
        c.recordDeposit{ value: 5e18 }(T1, dave, 1e18);

        assertApproxEqAbs(
            c.claimable(carol, T1), 5e18, 1e6, "spike skips the depositor's own tier to the next occupied one"
        );
        assertEq(c.claimable(dave, T1), 0, "depositor earns nothing from their own fee");
        assertEq(c.claimable(bob, T1), 0, "a farther prior tier is not the spike target");
        assertEq(c.claimable(alice, T1), 0, "a farther prior tier is not the spike target");
        assertEq(c.protocolAccrued(), 0, "no leak to protocol");
    }

    /// @dev When there is no prior tier to receive it (a first-tier deposit), the spike slice folds back
    ///      into the fulcrum pool and, with no prior tier there either, routes to the protocol bucket —
    ///      never forfeited.
    function test_depositToPriorTier_noPriorTierRoutesToProtocol() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = 5000;
        DynamicFeeFlatPriceCurve c = _deploy(config);

        c.recordDeposit{ value: 1e18 }(T1, alice, 10e18); // first depositor: vault at tier 0, no prior tier

        assertEq(c.claimable(alice, T1), 0, "the sole depositor earns nothing from their own fee");
        assertEq(c.protocolAccrued(), 1e18, "the whole fee routes to protocol when no prior tier exists");
    }

    /// @dev No-recipient with tier > 0: when the ONLY occupied prior tier is the depositor's own
    ///      pre-deposit bucket, the exclusion empties it in BOTH routing helpers — the spike finds no
    ///      recipient and folds into the fulcrum, which also finds no eligible tier — so the whole fee
    ///      folds to `protocolAccrued` and the payer earns nothing from their own fee.
    function test_depositToPriorTier_onlyPriorTierIsDepositorsOwn_foldsToProtocol() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = 5000; // spike enabled
        DynamicFeeFlatPriceCurve c = _deploy(config);

        // alice is the sole holder, bucketed at tier 0; this first deposit lifts the vault to tier 1.
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);

        // alice tops up with the source tier now at 1 (> 0). The only prior tier (0) holds nothing but
        // her own excluded stake, so neither the spike nor the fulcrum has a recipient.
        c.recordDeposit{ value: 1e18 }(T1, alice, 12e18);

        assertEq(c.claimable(alice, T1), 0, "the sole (excluded) prior holder earns nothing from their own fee");
        assertEq(
            c.protocolAccrued(), 1e18, "the whole fee folds to protocol when the only prior tier is the payer's own"
        );
    }

    /// @dev Conservation with the spike enabled: the curve custodies the whole fee, and claimable +
    ///      protocol never exceeds the pool (shortfall is bounded accumulator dust), for any
    ///      alpha / sigma / prior-tier share / pool.
    function testFuzz_depositToPriorTier_conservation(uint256 alpha, uint256 sigma, uint256 shareBps, uint256 pool)
        external
    {
        alpha = bound(alpha, 0, BPS);
        sigma = bound(sigma, 1, 64e18);
        shareBps = bound(shareBps, 0, BPS);
        pool = bound(pool, 1, 1_000_000e18);

        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = alpha;
        config.kernelSpread = sigma;
        config.depositToPriorTierBps = shareBps;
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-spike-fuzz");
        address eve = makeAddr("eve-spike-fuzz");
        vm.deal(address(this), pool + 1e18);
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 12e18);
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18);
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18);

        c.recordDeposit{ value: pool }(T1, eve, 20.736e18);

        assertEq(address(c).balance, pool, "curve custodies the whole fee");
        uint256 distributed = c.claimable(alice, T1) + c.claimable(bob, T1) + c.claimable(carol, T1)
            + c.claimable(dave, T1) + c.protocolAccrued();
        assertLe(distributed, pool, "never distributes more than the pool");
        assertGe(distributed + 1000, pool, "distributes essentially all of the pool (only dust lost)");
    }

    /* =================================================== */
    /*               WITHDRAWAL DISTRIBUTION              */
    /* =================================================== */

    function test_recordRedeem_diamondSliceToResidualHolders_exiterExcluded() external {
        // carol seeds into tier 1; alice and bob both enter at tier 1 (same bucket).
        _recordDeposit(T1, carol, 15e18, 0); // vaultAssets 15 (tier 1)
        _recordDeposit(T1, alice, 3e18, 0); // tier 1
        _recordDeposit(T1, bob, 3e18, 0); // tier 1, vaultAssets 21 (still tier 1)

        // alice fully exits from tier 1; the withdrawal fee goes to the residual tier-1 holder (bob),
        // and alice is excluded.
        _recordRedeem(T1, alice, 3e18, 0.3e18);

        assertEq(dynamicFeeCurve.claimable(bob, T1), 0.3e18, "residual tier-1 holder earns the whole fee");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "exiter earns nothing from their own fee");
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0, "tier-0 holder does not share the tier-1 exit fee");
        assertEq(dynamicFeeCurve.userStake(T1, alice), 0, "alice fully exited");
    }

    function test_recordRedeem_frontierPolicyRoutesToPriorTiers() external {
        // Reconfigure to 100% frontier routing (withdrawalToFulcrumTiersBps = BPS).
        DynamicFeeConfig memory config = _defaultConfig();
        config.withdrawalToFulcrumTiersBps = BPS;
        dynamicFeeCurve = _deploy(config);

        // alice at tier 0, bob at tier 1.
        _recordDeposit(T1, alice, 15e18, 0); // vaultAssets 15 (tier 1)
        _recordDeposit(T1, bob, 3e18, 0); // tier 1, vaultAssets 18

        // bob exits from tier 1; with full frontier routing, the fee targets prior tiers (tier 0 = alice).
        _recordRedeem(T1, bob, 3e18, 1e18);

        assertGt(dynamicFeeCurve.claimable(alice, T1), 0, "frontier routing pays the prior tier (alice)");
        assertEq(dynamicFeeCurve.claimable(bob, T1), 0, "exiter excluded");
    }

    function test_recordRedeem_partialExitKeepsResidualStake() external {
        _recordDeposit(T1, carol, 15e18, 0);
        _recordDeposit(T1, alice, 6e18, 0); // tier 1
        _recordDeposit(T1, bob, 6e18, 0); // tier 1

        _recordRedeem(T1, alice, 3e18, 0); // alice trims half, stays in tier 1

        assertEq(dynamicFeeCurve.userStake(T1, alice), 3e18, "residual stake retained");
        assertEq(dynamicFeeCurve.tierStake(T1, 1), 9e18, "tier-1 stake = alice residual + bob");
    }

    /* =================================================== */
    /*          WHALE-EXIT FALLBACK (DECISION 5)          */
    /* =================================================== */

    /// @dev When the exiting tier has no residual cohort, the diamond slice reroutes to the nearest
    ///      occupied tier ABOVE (the stayer who sat above the exiting whale), not to the protocol.
    ///      Positions: alice in tier 0, bob in tier 1 (sole), carol in tier 2 (edges 10/22/36).
    function test_recordRedeem_whaleExit_reroutesToNearestTierAbove() external {
        _recordDeposit(T1, alice, 15e18, 0); // books tier 0; vault -> 15 (tier 1)
        _recordDeposit(T1, bob, 8e18, 0); // books tier 1; vault -> 23 (tier 2)
        _recordDeposit(T1, carol, 20e18, 0); // books tier 2; vault -> 43

        assertEq(dynamicFeeCurve.userTier(T1, bob), 1, "bob in tier 1");
        assertEq(dynamicFeeCurve.userTier(T1, carol), 2, "carol in tier 2");

        // bob, the sole holder of tier 1, exits fully -> diamond slice orphaned -> nearest above = tier 2.
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.WithdrawalFeeRerouted(T1, 1, 2, 1e18);
        _recordRedeem(T1, bob, 8e18, 1e18);

        assertApproxEqAbs(dynamicFeeCurve.claimable(carol, T1), 1e18, 1e3, "tier-2 stayer earns the whale exit fee");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "tier-0 holder earns nothing when a tier above exists");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "nothing forfeited to protocol");
    }

    /// @dev With no occupied tier above the exit tier, the reroute searches below.
    function test_recordRedeem_whaleExit_reroutesBelowWhenNothingAbove() external {
        _recordDeposit(T1, alice, 15e18, 0); // books tier 0; vault -> 15 (tier 1)
        _recordDeposit(T1, bob, 10e18, 0); // books tier 1 (sole, top occupied); vault -> 25

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.WithdrawalFeeRerouted(T1, 1, 0, 1e18);
        _recordRedeem(T1, bob, 10e18, 1e18);

        assertApproxEqAbs(dynamicFeeCurve.claimable(alice, T1), 1e18, 1e3, "tier-0 holder earns when nothing above");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "not forfeited");
    }

    /// @dev Decision 6 is preserved: when NO other tier holds stake (sole holder, full exit), the fee
    ///      still forfeits to the protocol — there is genuinely no one to pay.
    function test_recordRedeem_soleHolderFullExit_forfeitsToProtocol() external {
        _recordDeposit(T1, alice, 15e18, 0);

        _recordRedeem(T1, alice, 15e18, 1e18);

        assertEq(dynamicFeeCurve.protocolAccrued(), 1e18, "sole full exit -> protocol (Decision 6 unchanged)");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "exiter earns nothing");
    }

    /// @dev The reroute only triggers on an empty exit tier; a residual cohort keeps the normal diamond
    ///      distribution to the same tier (no reroute).
    function test_recordRedeem_exitTierHasCohort_noReroute() external {
        _recordDeposit(T1, alice, 15e18, 0); // tier 0; vault -> 15
        _recordDeposit(T1, bob, 3e18, 0); // tier 1; vault -> 18
        _recordDeposit(T1, carol, 2e18, 0); // tier 1; vault -> 20

        // bob exits fully; carol remains in tier 1 -> diamond slice stays in tier 1, no reroute.
        _recordRedeem(T1, bob, 3e18, 1e18);

        assertApproxEqAbs(dynamicFeeCurve.claimable(carol, T1), 1e18, 1e3, "same-tier cohort earns the diamond slice");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "other tiers untouched");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "no forfeit");
    }

    /// @dev Conservation across a reroute: the contract holds exactly the fee, and claims + protocol
    ///      never exceed what was received (accumulator dust stays as an unattributed balance).
    function test_recordRedeem_reroute_conservation() external {
        _recordDeposit(T1, alice, 15e18, 0);
        _recordDeposit(T1, bob, 8e18, 0);
        _recordDeposit(T1, carol, 20e18, 0);

        _recordRedeem(T1, bob, 8e18, 1e18); // reroutes to carol

        uint256 booked = dynamicFeeCurve.claimable(alice, T1) + dynamicFeeCurve.claimable(carol, T1)
            + dynamicFeeCurve.protocolAccrued();
        assertEq(address(dynamicFeeCurve).balance, 1e18, "contract holds exactly the received fee");
        assertLe(booked, 1e18, "claims + protocol never exceed received (solvency)");
        assertApproxEqAbs(booked, 1e18, 1e3, "no material wei lost");
    }

    /* =================================================== */
    /*                       CLAIM                         */
    /* =================================================== */

    function test_claim_transfersEarnedAndZeroes() external {
        _recordDeposit(T1, alice, 10e18, 0);
        _recordDeposit(T1, bob, 12e18, 1e18); // alice is the sole occupied prior tier -> earns the whole 1e18

        uint256 balBefore = alice.balance;
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = T1;

        vm.expectEmit(true, false, false, true);
        emit Claimed(alice, 1e18);
        vm.prank(alice);
        uint256 claimed = dynamicFeeCurve.claim(terms);

        assertEq(claimed, 1e18, "claim returns amount");
        assertEq(alice.balance - balBefore, 1e18, "alice received native");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "claimable cleared");
    }

    function test_claim_revertsWhenNothingToClaim() external {
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = T1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_NothingToClaim.selector);
        vm.prank(alice);
        dynamicFeeCurve.claim(terms);
    }

    function test_claim_conservation_balanceEqualsClaimsPlusProtocol() external {
        _recordDeposit(T1, alice, 15e18, 0);
        _recordDeposit(T1, bob, 12e18, 1e18);
        _recordDeposit(T1, carol, 20e18, 1e18);

        uint256 sumClaimable = dynamicFeeCurve.claimable(alice, T1) + dynamicFeeCurve.claimable(bob, T1)
            + dynamicFeeCurve.claimable(carol, T1) + dynamicFeeCurve.protocolAccrued();
        // Held native == distributed claims + protocol dust, plus at most a few wei of accumulator
        // truncation that stays as an unattributed balance (never < the sum — no holder is short-changed).
        assertGe(address(dynamicFeeCurve).balance, sumClaimable, "balance never below owed");
        assertApproxEqAbs(
            address(dynamicFeeCurve).balance, sumClaimable, 1000, "only sub-wei accumulator dust unaccounted"
        );
    }

    /* =================================================== */
    /*                   ACCESS CONTROL                    */
    /* =================================================== */

    function test_recordDeposit_revertsWhenNotMultiVault() external {
        vm.deal(bob, 1e18);
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_OnlyMultiVault.selector);
        vm.prank(bob);
        dynamicFeeCurve.recordDeposit{ value: 1e18 }(T1, alice, 1e18);
    }

    function test_recordRedeem_revertsWhenNotMultiVault() external {
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_OnlyMultiVault.selector);
        vm.prank(bob);
        dynamicFeeCurve.recordRedeem(T1, alice, 1e18);
    }

    function test_setConfig_revertsWhenNotOwner() external {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        dynamicFeeCurve.setConfig(_defaultConfig());
    }

    function test_sweepProtocol_onlyOwner_transfersAccrued() external {
        // A deposit charged while the vault is still in tier 0 has no prior tier to reward, so the whole
        // fee accrues to the protocol bucket (the only clean way the fulcrum kernel routes to protocol).
        _recordDeposit(T1, alice, 15e18, 1e18);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        dynamicFeeCurve.sweepProtocol(bob);

        uint256 accrued = dynamicFeeCurve.protocolAccrued();
        assertEq(accrued, 1e18, "protocol accrued the no-prior-tier fee");
        uint256 balBefore = carol.balance;
        dynamicFeeCurve.sweepProtocol(carol); // owner == address(this)
        assertEq(carol.balance - balBefore, accrued, "swept to recipient");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "protocol bucket cleared");
    }

    function test_initialize_revertsOnSecondCall() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        dynamicFeeCurve.initialize(CURVE_NAME, owner, address(this), _defaultConfig());
    }

    /// @dev The name-only initializer inherited from {LinearCurve} stays on the ABI but is inert: the
    ///      proxy's atomic 4-arg init already consumed the one-shot `initializer` slot.
    function test_initialize_inheritedLinearCurveInitializer_isInert() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        LinearCurve(address(dynamicFeeCurve)).initialize("Some Other Name");
    }

    /* =================================================== */
    /*                 TIER FEE OVERRIDE                   */
    /* =================================================== */

    function test_setTierFeeOverride_replacesBothRatesForThatTier() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);

        assertEq(dynamicFeeCurve.depositFeeBps(2), 750, "tier 2 deposit uses the override");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(2), 900, "tier 2 withdrawal uses the override");
    }

    function test_setTierFeeOverride_getterExposesStoredOverride() external {
        dynamicFeeCurve.setTierFeeOverride(3, 111, 222);

        (bool isSet, uint16 depositBps, uint16 withdrawalBps) = dynamicFeeCurve.tierFeeOverride(3);
        assertTrue(isSet, "override marked set");
        assertEq(depositBps, 111, "stored deposit bps");
        assertEq(withdrawalBps, 222, "stored withdrawal bps");
    }

    /// @dev The core sparsity guarantee: overriding one tier leaves every other tier on the formula.
    function test_setTierFeeOverride_leavesEveryOtherTierOnFormula() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);

        uint256 tierCount = dynamicFeeCurve.getConfig().tierCount;
        for (uint256 tier = 0; tier < tierCount; ++tier) {
            if (tier == 2) continue;
            assertEq(dynamicFeeCurve.depositFeeBps(tier), 100 + tier * 50, "untouched tier keeps formulaic deposit");
            assertEq(
                dynamicFeeCurve.withdrawalFeeBps(tier), 200 + tier * 50, "untouched tier keeps formulaic withdrawal"
            );
            (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(tier);
            assertFalse(isSet, "untouched tier carries no override");
        }
    }

    /// @dev A bare 0-sentinel would be ambiguous; `isSet` makes an explicit 0-bps tier expressible.
    function test_setTierFeeOverride_explicitZeroBpsIsExpressible() external {
        dynamicFeeCurve.setTierFeeOverride(1, 0, 0);

        assertEq(dynamicFeeCurve.depositFeeBps(1), 0, "explicit 0-bps deposit override");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(1), 0, "explicit 0-bps withdrawal override");
        (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(1);
        assertTrue(isSet, "0-bps is a real override, not 'unset'");
    }

    /// @dev The override replaces the formula rate but stays within the schedule's declared caps: it
    ///      may set any rate up to `depositCapBps` / `withdrawalCapBps` (both 1000 here), not beyond.
    function test_setTierFeeOverride_maySetRateUpToTheCap() external {
        dynamicFeeCurve.setTierFeeOverride(0, 1000, 1000);

        assertEq(dynamicFeeCurve.depositFeeBps(0), 1000, "override may sit exactly at the deposit cap");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(0), 1000, "override may sit exactly at the withdrawal cap");
    }

    function test_setTierFeeOverride_revertsOnDepositBpsAboveCap() external {
        // depositCapBps = 1000, so 1001 is out of range.
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector);
        dynamicFeeCurve.setTierFeeOverride(0, 1001, 0);
    }

    function test_setTierFeeOverride_revertsOnWithdrawalBpsAboveCap() external {
        // withdrawalCapBps = 1000, so 1001 is out of range.
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector);
        dynamicFeeCurve.setTierFeeOverride(0, 0, 1001);
    }

    function test_setTierFeeOverride_appliesToQuoteDepositFee_singleBand() external {
        // Empty vault, 5e18 fits inside tier 0. Formula would charge 1% = 0.05e18.
        dynamicFeeCurve.setTierFeeOverride(0, 400, 0);
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 5e18), 0.2e18, "single band charged at the override rate");
    }

    /// @dev The piecewise walk must consult EACH traversed band's own override, not just the entry
    ///      band's. Baseline lump of 100e18 from empty is 2.3896e18 (10 at 1% + 12 at 1.5% + 14.4 at
    ///      2% + 17.28 at 2.5% + 46.32 at 3%); overriding only the middle band (tier 2, width 14.4)
    ///      to 5% moves it to 2.8216e18.
    function test_quoteDepositFee_piecewiseConsultsOverriddenMiddleBand() external {
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.3896e18, "baseline piecewise blend");

        dynamicFeeCurve.setTierFeeOverride(2, 500, 0);

        // 10 at 1% + 12 at 1.5% + 14.4 at 5% + 17.28 at 2.5% + 46.32 at 3%
        // = 0.1 + 0.18 + 0.72 + 0.432 + 1.3896
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.8216e18, "middle band charged at its override");
    }

    /// @dev Zeroing a middle band removes exactly that band's contribution and nothing else.
    function test_quoteDepositFee_piecewiseWithZeroedMiddleBand() external {
        dynamicFeeCurve.setTierFeeOverride(2, 0, 0);

        // Baseline 2.3896e18 minus the tier-2 band's 14.4 at 2% = 0.288e18.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.1016e18, "zeroed band drops only its own slice");
    }

    function test_setTierFeeOverride_appliesToQuoteRedeemFee() external {
        // Empty vault + no stake -> the rate keys on the vault's tier 0. Formula would charge 2%.
        dynamicFeeCurve.setTierFeeOverride(0, 0, 700);
        assertEq(dynamicFeeCurve.quoteRedeemFee(T1, alice, 10e18), 0.7e18, "redeem quote uses the tier override");
    }

    /// @dev Round-trip through the record path: the overridden quote is what the MultiVault forwards,
    ///      so the prior tier's earnings move with the override.
    function test_setTierFeeOverride_flowsThroughQuoteIntoRecordedDistribution() external {
        _recordDeposit(T1, alice, 15e18, 0); // alice books tier 0; vault sits at 15e18 -> tier 1

        dynamicFeeCurve.setTierFeeOverride(1, 1000, 0);

        // 5e18 stays inside tier 1 (15 + 5 < 22) -> 10% = 0.5e18 instead of the formulaic 1.5%.
        uint256 fee = dynamicFeeCurve.quoteDepositFee(T1, 5e18);
        assertEq(fee, 0.5e18, "quote reflects the override");

        _recordDeposit(T1, bob, 5e18, fee);

        // Only tier 0 exists below tier 1, so the kernel normalizes over that single occupied tier and
        // alice earns the whole overridden fee (0.5e18). Alice's claimable lands a few wei under the
        // ideal amount: the per-share accumulator floors at ACC_PRECISION (0.5e18 * 1e18 / 15e18 stake),
        // the standard MasterChef dust that stays as an unattributed contract balance rather than being
        // over-credited.
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), 0.5e18, 1e3, "prior tier earns the overridden fee slice"
        );
        assertLe(dynamicFeeCurve.claimable(alice, T1), 0.5e18, "accumulator dust never over-credits");
    }

    function test_clearTierFeeOverride_restoresFormula() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);
        assertEq(dynamicFeeCurve.depositFeeBps(2), 750, "override active");

        dynamicFeeCurve.clearTierFeeOverride(2);

        assertEq(dynamicFeeCurve.depositFeeBps(2), 200, "deposit back on the formula");
        assertEq(dynamicFeeCurve.withdrawalFeeBps(2), 300, "withdrawal back on the formula");
        (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(2);
        assertFalse(isSet, "override cleared");
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.3896e18, "piecewise blend back to baseline");
    }

    function test_setTierFeeOverride_revertsWhenNotOwner() external {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        dynamicFeeCurve.setTierFeeOverride(1, 100, 100);
    }

    function test_clearTierFeeOverride_revertsWhenNotOwner() external {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        dynamicFeeCurve.clearTierFeeOverride(1);
    }

    function test_setTierFeeOverride_revertsOnTierAtOrAboveTierCount() external {
        // tierCount = 5, so tier 5 is out of range.
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector);
        dynamicFeeCurve.setTierFeeOverride(5, 100, 100);
    }

    function test_setTierFeeOverride_emitsEvent() external {
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.TierFeeOverrideSet(2, 750, 900);
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);
    }

    function test_clearTierFeeOverride_emitsEvent() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.TierFeeOverrideCleared(2);
        dynamicFeeCurve.clearTierFeeOverride(2);
    }

    function testFuzz_setTierFeeOverride_quoteUsesOverrideRate(uint256 tier, uint16 depositBps, uint256 amount)
        external
    {
        tier = bound(tier, 0, 4);
        // Overrides are bounded by the schedule's deposit cap (1000 in `_defaultConfig`).
        depositBps = uint16(bound(depositBps, 0, dynamicFeeCurve.getConfig().depositCapBps));
        amount = bound(amount, 1, 5e18);

        dynamicFeeCurve.setTierFeeOverride(tier, depositBps, 0);

        assertEq(dynamicFeeCurve.depositFeeBps(tier), depositBps, "getter returns the override for any tier/rate");

        // Park the vault inside `tier` and quote an amount small enough to stay in that band, so the
        // piecewise walk touches exactly one (overridden) band.
        uint256 lowerEdge = tier == 0 ? 0 : dynamicFeeCurve.tierUpperEdge(tier - 1);
        if (lowerEdge > 0) {
            _recordDeposit(T2, alice, lowerEdge, 0);
        }
        vm.assume(tier == 4 || lowerEdge + amount < dynamicFeeCurve.tierUpperEdge(tier));

        uint256 expected = (amount * depositBps + BPS - 1) / BPS; // mulDivUp
        assertEq(dynamicFeeCurve.quoteDepositFee(T2, amount), expected, "single overridden band quote");
    }

    /* =================================================== */
    /*                 CONFIG VALIDATION                   */
    /* =================================================== */

    function test_setConfig_revertsOnZeroWidth() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 0;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnTierCountOutOfRange() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.tierCount = 0;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);

        config.tierCount = 65; // > MAX_TIER_COUNT
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    /// @dev The fulcrum position is a fraction of the span, so it must lie in `[0, BPS]`.
    function test_setConfig_revertsOnFulcrumAlphaAboveBps() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    /// @dev `kernelSpread` (σ) divides the triangular weight, so a zero spread is rejected, and it is
    ///      bounded above so the weight math stays clear of overflow.
    function test_setConfig_revertsOnInvalidKernelSpread() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.kernelSpread = 0;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);

        config.kernelSpread = dynamicFeeCurve.MAX_KERNEL_SPREAD() + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnBaseAboveCap() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositBaseBps = config.depositCapBps + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnTierCountShrink() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.tierCount = 4; // current schedule has 5
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_TierCountCannotShrink.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnOversizedGeometry() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = uint256(type(uint128).max) + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);

        config = _defaultConfig();
        config.growthGBps = 100 * BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    /// @dev Retuning the schedule with live positions: recorded bucket ids and booked earnings are
    ///      untouched (index-keyed, never migrated — solvency cannot be affected), while all future
    ///      tier decisions follow the new schedule immediately.
    function test_setConfig_retune_keepsBucketsStickyAndSolvent() external {
        _recordDeposit(T1, alice, 10e18, 0); // alice enters at tier 0, vault -> tier 1
        _recordDeposit(T1, bob, 12e18, 1e18); // bob enters at tier 1; alice earns the tier-0 slice
        uint256 aliceClaimableBefore = dynamicFeeCurve.claimable(alice, T1);
        uint256 bobTierBefore = dynamicFeeCurve.userTier(T1, bob);
        assertGt(aliceClaimableBefore, 0, "precondition: alice earned");

        // Owner doubles the tier widths mid-flight.
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 20e18;
        dynamicFeeCurve.setConfig(config);

        // Sticky buckets: recorded ids and booked earnings are untouched...
        assertEq(dynamicFeeCurve.userTier(T1, bob), bobTierBefore, "bucket ids are sticky across retunes");
        assertEq(dynamicFeeCurve.claimable(alice, T1), aliceClaimableBefore, "earnings unaffected by retune");
        // ...while future tier decisions use the new schedule immediately.
        assertEq(dynamicFeeCurve.tierOf(15e18), 0, "tierOf follows the new schedule (15 < new width0 20)");
    }

    function test_setConfig_revertsOnWithdrawalShareAboveBps() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.withdrawalToFulcrumTiersBps = BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnDepositToPriorTierAboveBps() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    /* =================================================== */
    /*                    REENTRANCY                       */
    /* =================================================== */

    function test_claim_reentrancyGuardBlocksReentry() external {
        ReentrantClaimer attacker = new ReentrantClaimer(dynamicFeeCurve, T1);
        // Give the attacker an earned balance: alice at tier 0, attacker at tier 1, then carol deposits
        // from tier 2 so the tier-1 slice pays the attacker.
        _recordDeposit(T1, alice, 15e18, 0); // vaultAssets 15 -> tier 1
        _recordDeposit(T1, address(attacker), 12e18, 0); // enters tier 1; vaultAssets 27 -> tier 2
        _recordDeposit(T1, carol, 12e18, 1e18); // from tier 2, pays tier 1 (attacker) + tier 0 (alice)

        assertGt(dynamicFeeCurve.claimable(address(attacker), T1), 0, "attacker has earnings");

        vm.expectRevert(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
        attacker.attack();
    }

    /* =================================================== */
    /*                 FEE HOOK SIGNALING                  */
    /* =================================================== */

    function test_feeHooks_advertisesBothHooks() public view {
        assertTrue(dynamicFeeCurve.hasDepositFeeHook(), "dynamic-fee curve must advertise the deposit hook");
        assertTrue(dynamicFeeCurve.hasRedeemFeeHook(), "dynamic-fee curve must advertise the redeem hook");
    }
}

/// @dev Reenters `claim` from its native-receive hook to probe the reentrancy guard.
contract ReentrantClaimer {
    DynamicFeeFlatPriceCurve internal immutable SIDE_POCKET;
    bytes32 internal immutable TERM_ID;

    constructor(DynamicFeeFlatPriceCurve _dynamicFeeCurve, bytes32 _termId) {
        SIDE_POCKET = _dynamicFeeCurve;
        TERM_ID = _termId;
    }

    function attack() external {
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = TERM_ID;
        SIDE_POCKET.claim(terms);
    }

    receive() external payable {
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = TERM_ID;
        SIDE_POCKET.claim(terms); // reentrant — must revert via the guard
    }
}
