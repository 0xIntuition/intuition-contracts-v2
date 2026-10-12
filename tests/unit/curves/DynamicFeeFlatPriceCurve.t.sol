// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, Vm } from "forge-std/src/Test.sol";
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
///
///         "Diamond slice" and "diamond-hands slice" below both mean the exiting-tier slice: the
///         portion of a redeem fee that goes to the exiting tier's other holders.
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

    /// @dev Topic0s for the deposit events, used by the shape test below. Computed from the
    ///      signatures rather than redeclaring the events locally: a redeclared copy silently goes
    ///      stale when the contract's signature changes, which is exactly what happened to the old
    ///      five-field `DepositRecorded` that used to sit here.
    bytes32 internal constant DEPOSIT_RECORDED_TOPIC =
        keccak256("DepositRecorded(bytes32,address,uint256,uint256,uint256,uint256)");
    bytes32 internal constant DEPOSIT_BAND_RECORDED_TOPIC =
        keccak256("DepositBandRecorded(bytes32,address,uint256,uint256,uint256)");
    bytes32 internal constant REDEEM_RECORDED_TOPIC =
        keccak256("RedeemRecorded(bytes32,address,uint256,uint256,uint256)");
    bytes32 internal constant REDEEM_LOT_RECORDED_TOPIC =
        keccak256("RedeemLotRecorded(bytes32,address,uint256,uint256,uint256)");

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
    ///      redeem 2% +0.5%/tier, all → own tier. Widths compound at 1.2x: 10, 12, 14.4, 17.28,
    ///      20.736; edges: 10, 22, 36.4, 53.68, 74.416 (×1e18).
    function _defaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 5,
            tierWidthGrowthBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            depositFulcrumAlphaBps: 10_000,
            depositKernelSpread: 4e18,
            redeemFulcrumAlphaBps: 10_000,
            redeemKernelSpread: 4e18,
            redeemBaseBps: 200,
            redeemGrowthBps: 50,
            redeemCapBps: 1000,
            redeemToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStakeBps: 0
        });
    }

    function _recordDeposit(bytes32 termId, address account, uint256 shares, uint256 fee) internal {
        dynamicFeeCurve.recordDeposit{ value: fee }(termId, account, shares);
    }

    function _recordRedeem(bytes32 termId, address account, uint256 shares, uint256 fee) internal {
        dynamicFeeCurve.recordRedeem{ value: fee }(termId, account, shares);
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

    /// @dev `_setConfig` ends with a zero-top-edge guard, and that guard is UNREACHABLE behind the
    ///      validations that precede it. This records why, because an uncovered branch with no
    ///      explanation reads to a reviewer as an untested one.
    ///
    ///      Both arms of `_tierUpperEdge` are bounded below by `width0`, which is already rejected at
    ///      zero. At `g == 0` the edge is `width0 * (k + 1)`. At `g > 0` it is
    ///      `width0 * (powWad - WAD) / gWad`, and `ratioWad - WAD` is EXACTLY `gWad` by construction —
    ///      both are the same floored `g * WAD / BPS` — so at `k = 0` the quotient is exactly one, and
    ///      `rpow` is monotonic in the exponent, so it only grows from there. The edge can therefore
    ///      never fall below `width0`, let alone reach zero.
    ///
    ///      Asserting the invariant rather than the branch is the useful direction: it keeps the guard
    ///      honest if a future change ever loosens the `width0` or `tierWidthGrowthBps` bounds that make it dead.
    function testFuzz_tierUpperEdge_isNeverZeroForAnyValidSchedule(
        uint96 width0,
        uint8 tierCount,
        uint16 tierWidthGrowthBps
    ) external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = bound(width0, 1, type(uint96).max);
        config.tierCount = bound(tierCount, 1, 64);
        config.tierWidthGrowthBps = bound(tierWidthGrowthBps, 0, 5000);

        DynamicFeeFlatPriceCurve curve = _deploy(config);

        uint256 topEdge = curve.tierUpperEdge(config.tierCount - 1);
        assertGe(topEdge, config.width0, "the top edge is bounded below by the first band's width");
        assertGt(topEdge, 0, "so the degenerate-schedule guard can never fire");
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
    function testFuzz_tierLadder_invariants(uint256 width0, uint256 tierWidthGrowthBps, uint256 tierCount) external {
        width0 = bound(width0, 1, 1e30);
        tierWidthGrowthBps = bound(tierWidthGrowthBps, 0, 100 * 10_000);
        tierCount = bound(tierCount, 1, dynamicFeeCurve.MAX_TIER_COUNT());

        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = width0;
        config.tierWidthGrowthBps = tierWidthGrowthBps;
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
        config.tierWidthGrowthBps = 1; // g = 0.0001 -> (1+g)^k is irrational in WAD
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

    /// @dev The exact deployed 13-tier production schedule (`width0 = 5000 TRUST`, `tierWidthGrowthBps = 2000`):
    ///      pin the edges, the widths as edge deltas, and that the widths sum to the top edge. This is
    ///      the schedule that actually ships, so it gets an explicit fixture rather than only fuzz
    ///      coverage. Terminal tier 12 begins at the tier-11 edge (~197,903 TRUST); tier 12's own
    ///      closed-form edge (~242,483 TRUST) is inert since `tierOf` caps at the terminal tier.
    function test_deployedProductionSchedule_edgesWidthsAndSum() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 5000e18;
        config.tierWidthGrowthBps = 2000; // g = 0.2
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
    ///      bands of `grossFilling(width(k)) * rate(k)`. This ties the width/edge views to the fee the
    ///      walk actually charges — if the two ever diverged (independent rounding of width vs edge),
    ///      the equality would break.
    ///
    ///      The gross-up is the net-anchored traversal: the vault books the base less the fee, so the
    ///      GROSS portion that carries the cursor across a band of net width `w` charged at `r` is
    ///      `w * BPS / (BPS - r)`, not `w`. Charging `w * r` would be the old gross-anchored walk, and
    ///      would make a split deposit structurally cheaper than the identical lump.
    function test_piecewiseFee_matchesGrossedUpWidthTimesRatePerBand() external view {
        // Default schedule: edges 10/22/36.4/53.68/74.416. A 200e18 deposit from empty fills all four
        // finite bands and lands deep in the terminal tier 4, which absorbs the remainder.
        assertEq(
            dynamicFeeCurve.quoteDepositFee(T1, 200e18),
            _expectedPiecewiseFrom(0, 200e18),
            "piecewise fee == sum(grossedUpWidth*rate) per band"
        );
        // Golden value, so a change in the walk cannot be absorbed by an equally-changed expectation.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 200e18), 5_379_684_521_102_940_250, "golden 200e18 blend");
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) private pure returns (uint256) {
        return (x * y + d - 1) / d;
    }

    /// @dev Independent restatement of the net-anchored piecewise walk, built only from the public
    ///      ladder views (`tierOf` / `tierUpperEdge` / `depositFeeBps`). Used by the fee-blend tests so
    ///      they express the RULE rather than a hand-computed constant, and so a per-band override is
    ///      picked up automatically wherever the contract would pick it up.
    function _expectedPiecewiseFrom(uint256 startAssets, uint256 amount) private view returns (uint256 fee) {
        uint256 topTier = dynamicFeeCurve.getConfig().tierCount - 1;
        uint256 remaining = amount;
        uint256 cursor = startAssets;
        uint256 k = dynamicFeeCurve.tierOf(startAssets);
        while (remaining > 0) {
            uint256 rate = dynamicFeeCurve.depositFeeBps(k);
            uint256 chunk = remaining;
            if (k < topTier) {
                uint256 grossFillingBand = _mulDivUp(dynamicFeeCurve.tierUpperEdge(k) - cursor, BPS, BPS - rate);
                if (grossFillingBand < chunk) chunk = grossFillingBand;
            }
            uint256 chunkFee = _mulDivUp(chunk, rate, BPS);
            fee += chunkFee;
            remaining -= chunk;
            cursor += chunk - chunkFee;
            ++k;
        }
    }

    /// @dev External wrapper so the fuzz test can `try` the deployment (config may be rejected).
    function deployWithConfig(DynamicFeeConfig memory config) external returns (DynamicFeeFlatPriceCurve) {
        return _deploy(config);
    }

    /// @dev `tierWidthGrowthBps = 0` degenerates to a flat ladder: every band is exactly `width0` wide and the
    ///      edges are plain multiples. The closed form divides by `g`, so this case is handled
    ///      explicitly rather than falling into a division by zero.
    function test_tierMath_zeroGrowthGivesConstantWidths() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.tierWidthGrowthBps = 0;
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
        config.tierWidthGrowthBps = 100 * BPS; // 100x per tier, compounded 64 times

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

    function test_redeemFeeBps_growsAndCaps() external view {
        assertEq(dynamicFeeCurve.redeemFeeBps(0), 200, "tier 0 = base");
        assertEq(dynamicFeeCurve.redeemFeeBps(2), 300, "tier 2");
        assertEq(dynamicFeeCurve.redeemFeeBps(1000), 1000, "caps at 10%");
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
        // From empty, each band charged at its own rate, with the gross-up that keeps the cursor on
        // the NET the vault books.
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), _expectedPiecewiseFrom(0, 100e18), "blend from tier 0");
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2_379_684_521_102_940_250, "golden blend from tier 0");
        // Strictly below the old gross-anchored 2.3896e18: the gross-up means each band is filled by
        // slightly more gross than its net width, so the walk reaches the dearer bands slightly later.
        assertLt(dynamicFeeCurve.quoteDepositFee(T1, 100e18), 2.3896e18, "net anchoring never charges more");

        _recordDeposit(T1, alice, 15e18, 0); // vault now mid tier 1
        assertEq(
            dynamicFeeCurve.quoteDepositFee(T1, 100e18),
            _expectedPiecewiseFrom(15e18, 100e18),
            "blend from a mid-band cursor"
        );
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
        assertEq(dynamicFeeCurve.vaultStake(T1), 5e18, "vault stake tracked");
    }

    function test_recordDeposit_feeFlowsToPriorTier() external {
        // alice enters at tier 0 (10e18 keeps the tier-0 stake evenly divisible -> no rounding dust).
        _recordDeposit(T1, alice, 10e18, 0); // vaultStake 0 -> 10 (now tier 1)
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 0, "alice bucket 0");

        // bob deposits while the vault sits in tier 1: the fee is distributed by the triangular kernel
        // over the OCCUPIED prior tiers. Only tier 0 (alice) holds stake, so weights normalize over
        // that single tier and it earns the whole pool — nothing leaks to protocol.
        _recordDeposit(T1, bob, 12e18, 1e18);

        assertEq(dynamicFeeCurve.claimable(alice, T1), 1e18, "alice (sole occupied prior tier) earns the whole fee");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "no leak: the fee normalizes over occupied tiers");
        assertEq(dynamicFeeCurve.claimable(bob, T1), 0, "bob earns nothing yet");
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), 1, "bob bucket 1");
    }

    /// @dev A depositor's stake in the tiers BELOW the band being charged is a recipient of that
    ///      band's fee, exactly like any other holder's. Nothing is excluded on the deposit leg, which
    ///      is what makes one wallet and several wallets equivalent.
    ///
    ///      The guard that remains is structural: a band's fee reaches only the tiers below it, and
    ///      the band's own stake lands after its fee is distributed, so no part of a deposit is ever
    ///      paid out of the fee it itself generated.
    function test_recordDeposit_depositorEarnsFromTheirOwnPriorTierStake() external {
        // Seed: alice's lot fills tier 0, bob's lot fills tier 1.
        _recordDeposit(T1, alice, 10e18, 0); // -> vaultStake 10 (tier 1)
        _recordDeposit(T1, bob, 12e18, 1e18); // bob's lot at tier 1; vaultStake 22 (tier 2)
        uint256 aliceBefore = dynamicFeeCurve.claimable(alice, T1);
        uint256 bobBefore = dynamicFeeCurve.claimable(bob, T1);
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        // bob deposits again, inside tier 2. He holds tier 1, a prior tier of the band being charged,
        // so he collects the kernel share of tier 1 while alice collects tier 0's.
        _recordDeposit(T1, bob, 12e18, 1e18);

        uint256 bobEarned = dynamicFeeCurve.claimable(bob, T1) - bobBefore;
        uint256 aliceEarned = dynamicFeeCurve.claimable(alice, T1) - aliceBefore;

        assertGt(bobEarned, 0, "bob earns on the stake he already held in a prior tier");
        assertGt(aliceEarned, 0, "alice still earns her tier's share");
        assertGt(bobEarned, aliceEarned, "tier 1 sits nearer the source than tier 0, so it earns more");
        assertApproxEqAbs(bobEarned + aliceEarned, 1e18, 1e3, "the whole fee reaches the prior tiers");
        // Each band distributes separately, so the per-share division leaves its own truncation
        // remainder — a couple of wei across two bands, not a leak. Bounded, never a whole slice.
        assertLe(dynamicFeeCurve.protocolAccrued() - protocolBefore, 1e3, "only bounded rounding reaches protocol");
    }

    function test_recordDeposit_landsOneLotPerBandAndNeverMovesEarlierLots() external {
        // bob enters at tier 0; carol then pushes the vault up to tier 2.
        _recordDeposit(T1, bob, 5e18, 0);
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), 0, "bob's only lot sits at tier 0");

        // carol's 20e18 spans three bands from 5e18 (5 at tier 0, 12 at tier 1, 3 at tier 2): one lot
        // per band, each where the money actually landed, and her top lot is the highest of them.
        _recordDeposit(T1, carol, 20e18, 0); // vaultStake 25 -> tier 2
        assertEq(dynamicFeeCurve.userTopTier(T1, carol), 2, "carol's top lot is the last band she entered");
        (uint256[] memory tiers, uint256[] memory stakes) = dynamicFeeCurve.userLots(T1, carol);
        assertEq(tiers.length, 3, "one lot per band traversed");
        assertEq(tiers[0], 2, "lots are listed highest tier first");
        assertEq(stakes[0], 3e18, "3 landed in tier 2");
        assertEq(tiers[1], 1, "then tier 1");
        assertEq(stakes[1], 12e18, "12 landed in tier 1");
        assertEq(tiers[2], 0, "then tier 0");
        assertEq(stakes[2], 5e18, "5 landed in tier 0");
        assertEq(dynamicFeeCurve.lotMask(T1, carol), 0x7, "the mask flags exactly tiers 0, 1 and 2");

        // A follow-on deposit while the vault sits in tier 2 (edges 10 / 22 / 36.4) lands 11.4 in tier 2
        // and 8.6 in tier 3. bob's tier-0 lot is untouched: nothing averages, so his earlier stake keeps
        // its entry tier and his top lot is simply the highest band this deposit reached.
        _recordDeposit(T1, bob, 20e18, 0); // vaultStake 45 -> tier 3
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), 3, "bob's top lot is the highest band reached");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 0), 5e18, "bob's tier-0 lot is untouched");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 2), 11.4e18, "bob's tier-2 lot");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 3), 8.6e18, "bob's tier-3 lot");
        assertEq(dynamicFeeCurve.tierStake(T1, 0), 10e18, "tier 0 holds both early lots");
        assertEq(dynamicFeeCurve.tierStake(T1, 1), 12e18, "carol alone holds tier 1");
        assertEq(dynamicFeeCurve.tierStake(T1, 2), 14.4e18, "tier 2 holds carol's 3 and bob's 11.4");
        assertEq(dynamicFeeCurve.tierStake(T1, 3), 8.6e18, "tier 3 holds bob's 8.6");
        assertEq(dynamicFeeCurve.userStake(T1, bob), 25e18, "userStake is the sum of bob's lots");
    }

    /// @dev A second deposit landing in a band the holder already has a lot at tops that lot up rather
    ///      than opening another, and banks what the lot had earned before its debt is re-based.
    function test_recordDeposit_sameBandTopsUpTheExistingLot() external {
        _recordDeposit(T1, alice, 10e18, 0); // alice's lot at tier 0; vault -> 10 (tier 1)
        _recordDeposit(T1, bob, 2e18, 0); // bob's first lot at tier 1; vault -> 12
        _recordDeposit(T1, carol, 3e18, 1e18); // fee released from tier 1 -> alice (tier 0) earns it
        assertEq(dynamicFeeCurve.claimable(alice, T1), 1e18, "alice earned the fee");
        uint256 aliceBanked = dynamicFeeCurve.claimable(alice, T1);

        // alice tops up inside tier 1 (the vault sits there): a NEW lot at tier 1, tier-0 lot untouched.
        _recordDeposit(T1, alice, 2e18, 0); // vault -> 17
        assertEq(dynamicFeeCurve.lotMask(T1, alice), 0x3, "alice now holds lots at tiers 0 and 1");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 0), 10e18, "tier-0 lot untouched");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 1), 2e18, "tier-1 lot opened");
        assertEq(dynamicFeeCurve.claimable(alice, T1), aliceBanked, "topping up does not move earned credit");

        // bob tops up inside tier 1 again: the same lot grows, no new lot.
        _recordDeposit(T1, bob, 3e18, 0); // vault -> 20
        assertEq(dynamicFeeCurve.lotMask(T1, bob), 0x2, "bob still holds a single lot at tier 1");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 1), 5e18, "bob's tier-1 lot topped up");
        assertEq(dynamicFeeCurve.userStake(T1, bob), 5e18, "bob's stake is his one lot");
    }

    /// @dev The deposit event surface, pinned by shape AND by semantics. A deposit spanning two bands
    ///      emits one {DepositBandRecorded} per band in ascending order plus exactly one summary
    ///      {DepositRecorded} whose top-tier field agrees with the stored lots.
    ///
    ///      Matched on a topic0 computed from the signature rather than on a locally redeclared event.
    ///      A redeclared copy cannot fail when the contract's signature changes — which is precisely
    ///      how the old five-field `DepositRecorded` declaration in this file went stale unnoticed.
    function test_recordDeposit_emitsPerBandAndSummaryEvents() external {
        uint256 fee = dynamicFeeCurve.quoteDepositFee(T1, 15e18);
        uint256 shares = 15e18 - fee;

        vm.recordLogs();
        _recordDeposit(T1, alice, shares, fee);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 bandCount;
        uint256 bandStakeSum;
        uint256 bandFeeSum;
        uint256 summaryCount;
        uint256 lastBandTier;

        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == DEPOSIT_BAND_RECORDED_TOPIC) {
                (uint256 bandTier, uint256 bandStake, uint256 bandFee) =
                    abi.decode(logs[i].data, (uint256, uint256, uint256));
                assertEq(logs[i].topics[1], T1, "band event carries the term");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), alice, "band event carries the account");
                if (bandCount > 0) assertGt(bandTier, lastBandTier, "bands are emitted in ascending order");
                lastBandTier = bandTier;
                bandStakeSum += bandStake;
                bandFeeSum += bandFee;
                ++bandCount;
            } else if (logs[i].topics[0] == DEPOSIT_RECORDED_TOPIC) {
                (uint256 emittedStake, uint256 emittedFee, uint256 sourceTier, uint256 topTier) =
                    abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));
                assertEq(emittedStake, shares, "summary carries the net stake");
                assertEq(emittedFee, fee, "summary carries the forwarded fee");
                assertEq(sourceTier, 0, "the vault started in tier 0");
                assertEq(topTier, dynamicFeeCurve.userTopTier(T1, alice), "summary top tier matches the stored lots");
                assertEq(topTier, 1, "the deposit's highest band is the top lot");
                ++summaryCount;
            }
        }

        assertEq(bandCount, 2, "15e18 into an empty vault crosses tier 0 and tier 1");
        assertEq(summaryCount, 1, "exactly one summary event per deposit");
        assertEq(bandStakeSum, shares, "the band stakes reconstruct the deposit");
        assertEq(bandFeeSum, fee, "the band fees reconstruct the forwarded fee exactly");
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
        config.depositFulcrumAlphaBps = alpha;
        config.depositKernelSpread = sigma;
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

    /// @dev Each leg reads its own kernel pair: with the deposit pair nearest-first and the redeem
    ///      pair farthest-first, a deposit fee lands on the nearest tiers and a redeem fee on the
    ///      farthest, from the same vault state.
    function test_fulcrum_redeemLegUsesRedeemKernel() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = BPS;
        config.redeemFulcrumAlphaBps = 0;
        config.redeemToFulcrumTiersBps = BPS;
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 12e18);
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18);
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18);
        c.recordDeposit{ value: 6e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(c.claimable(dave, T1), 3e18, 1e4, "deposit leg: nearest tier earns 50%");
        assertEq(c.claimable(alice, T1), 0, "deposit leg: farthest tier earns nothing");

        c.recordRedeem{ value: 10e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(c.claimable(alice, T1), 4e18, 1e4, "redeem leg: farthest tier earns 40%");
        assertApproxEqAbs(c.claimable(dave, T1), 4e18, 1e4, "redeem leg: nearest tier earns 10% on top");
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

    /// @dev Degenerate fallback: when every OCCUPIED prior tier falls outside the kernel window, the
    ///      pool is split across the occupied prior tiers by fill alone, at the equal-share ceiling
    ///      (one share per prior tier), rather than forfeited whole or handed whole to one tier.
    ///
    ///      This reaches that state through an occupancy GAP rather than by collapsing sigma, because
    ///      the gap version is the one that survives a realistic schedule. `_setConfig` does NOT floor
    ///      sigma — it only rejects zero — so a sub-tier sigma would also work here; it is avoided
    ///      because at `sigma <= WAD` every integer distance `d >= 1` gets zero weight and the
    ///      fallback fires for a reason that has nothing to do with occupancy, which is not the
    ///      property under test.
    ///
    ///      With `sigma = WAD + 1` and dStar = 2.5 (alpha = 3750 over span 4) the window admits only
    ///      d = 2 and d = 3 — exactly the two tiers this empties. What is left is alice at d = 4 and
    ///      dave at d = 1, both full, both weight zero: each earns one share in four of the pool, and
    ///      the two empty tiers' shares accrue.
    ///
    ///      The bridges deposit to fill the middle bands and then withdraw, and a top-tier holder keeps
    ///      the vault in tier 4 afterwards — the top tier is never a prior tier, so it cannot itself
    ///      receive and does not perturb the weights.
    function test_fulcrum_degenerateGuard_splitsByFillAtTheEqualShareCeiling() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = 3750; // dStar = (1 - 0.375) * 4 = 2.5 tiers from the source
        config.depositKernelSpread = WAD + 1; // the tightest window `_setConfig` permits: ±1 tier
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-degen");
        address eve = makeAddr("eve-degen");
        address bridgeOne = makeAddr("bridge-one-degen");
        address bridgeTwo = makeAddr("bridge-two-degen");
        address whale = makeAddr("whale-degen");

        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // tier 0 (d = 4)
        c.recordDeposit{ value: 0 }(T1, bridgeOne, 12e18); // fills tier 1 (d = 3)
        c.recordDeposit{ value: 0 }(T1, bridgeTwo, 14.4e18); // fills tier 2 (d = 2)
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // tier 3 (d = 1); vault -> tier 4
        c.recordDeposit{ value: 0 }(T1, whale, 30e18); // sits in the top tier, holds the vault there

        // Empty the two in-window tiers. The whale's stake keeps the vault inside tier 4.
        c.recordRedeem{ value: 0 }(T1, bridgeOne, 12e18);
        c.recordRedeem{ value: 0 }(T1, bridgeTwo, 14.4e18);
        assertEq(c.tierStake(T1, 1), 0, "tier 1 must be empty");
        assertEq(c.tierStake(T1, 2), 0, "tier 2 must be empty");
        assertEq(c.tierOf(c.vaultStake(T1)), 4, "the source tier must still be 4");

        c.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertApproxEqAbs(c.claimable(dave, T1), 1.25e18, 1e4, "a full occupied tier earns one share in four");
        assertApproxEqAbs(c.claimable(alice, T1), 1.25e18, 1e4, "so does the other, distance no longer counting");
        assertApproxEqAbs(c.protocolAccrued(), 2.5e18, 1e4, "the two empty tiers' shares accrue");
    }

    /// @dev Conservation: the whole fee stays custodied by the curve, and the sum of what is claimable
    ///      plus what accrued to the protocol never exceeds the pool (the shortfall is bounded
    ///      accumulator dust), for any alpha / sigma / pool.
    function testFuzz_fulcrum_conservation(uint256 alpha, uint256 sigma, uint256 pool) external {
        alpha = bound(alpha, 0, BPS);
        sigma = bound(sigma, WAD + 1, 64e18);
        pool = bound(pool, 1, 1_000_000e18);

        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = alpha;
        config.depositKernelSpread = sigma;
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

    /// @dev The spike targets the nearest OCCUPIED prior tier, full stop — the depositor's own holding
    ///      in that tier is a recipient like anyone else's. When dave (bucket 3) tops up from tier 4,
    ///      the nearest occupied prior tier IS his own, so the 100% spike lands on him. Were it skipped,
    ///      dave could route the same lump to carol simply by paying from a second wallet.
    function test_depositToPriorTier_targetsNearestOccupiedPriorTierEvenWhenItIsTheDepositors() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = BPS;
        config.depositKernelSpread = 4e18;
        config.depositToPriorTierBps = BPS; // 100% spike -> unambiguous routing target
        DynamicFeeFlatPriceCurve c = _deploy(config);
        address dave = makeAddr("dave-skip");

        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // tier 0
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // tier 1
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // tier 2
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // tier 3; vault -> tier 4

        // dave tops up from tier 4. The nearest occupied prior tier is 3, which is his own bucket, so
        // the spike lands on him.
        c.recordDeposit{ value: 5e18 }(T1, dave, 1e18);

        assertApproxEqAbs(c.claimable(dave, T1), 5e18, 1e6, "the spike lands on the nearest occupied prior tier");
        assertEq(c.claimable(carol, T1), 0, "a farther prior tier is not the spike target");
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

    /// @dev The sole-occupant case, and the one the whole change exists for: when the ONLY occupied
    ///      prior tier is the depositor's own, they receive the fee rather than forfeiting it. Both
    ///      routing helpers find that tier — the spike lands its lump there and the fulcrum spread
    ///      normalizes over it — so nothing reaches `protocolAccrued`.
    ///
    ///      Owning every prior tier is precisely the case where there is nobody else with a claim on
    ///      the fee, so paying it to the protocol was taking value from the only party entitled to it.
    function test_depositToPriorTier_onlyPriorTierIsDepositorsOwn_paysTheDepositor() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = 5000; // spike enabled
        DynamicFeeFlatPriceCurve c = _deploy(config);

        // alice is the sole holder, bucketed at tier 0; this first deposit lifts the vault to tier 1.
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);

        // alice tops up with the source tier now at 1 (> 0), and her 12e18 stays inside tier 1's band
        // (10 -> 22), so the whole fee is sourced at tier 1 and tier 0 is its only recipient.
        c.recordDeposit{ value: 1e18 }(T1, alice, 12e18);

        assertApproxEqAbs(c.claimable(alice, T1), 1e18, 1e3, "the sole prior holder receives their own fee");
        assertEq(c.protocolAccrued(), 0, "nothing is forfeited to the protocol when a prior tier exists");
    }

    /// @dev Conservation with the spike enabled: the curve custodies the whole fee, and claimable +
    ///      protocol never exceeds the pool (shortfall is bounded accumulator dust), for any
    ///      alpha / sigma / prior-tier share / pool.
    function testFuzz_depositToPriorTier_conservation(uint256 alpha, uint256 sigma, uint256 shareBps, uint256 pool)
        external
    {
        alpha = bound(alpha, 0, BPS);
        sigma = bound(sigma, WAD + 1, 64e18);
        shareBps = bound(shareBps, 0, BPS);
        pool = bound(pool, 1, 1_000_000e18);

        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = alpha;
        config.depositKernelSpread = sigma;
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
        _recordDeposit(T1, carol, 15e18, 0); // vaultStake 15 (tier 1)
        _recordDeposit(T1, alice, 3e18, 0); // tier 1
        _recordDeposit(T1, bob, 3e18, 0); // tier 1, vaultStake 21 (still tier 1)

        // alice fully exits from tier 1; the redeem fee goes to the residual tier-1 holder (bob),
        // capped at his fill of the band: 3 of 12 TRUST keeps a quarter of the 0.3e18 slice. The
        // unpaid three quarters rejoin the fulcrum pool, whose only prior tier is carol's full tier 0.
        // alice is excluded throughout.
        _recordRedeem(T1, alice, 3e18, 0.3e18);

        assertEq(dynamicFeeCurve.claimable(bob, T1), 0.075e18, "a quarter-filled cohort keeps a quarter of the slice");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "exiter earns nothing from their own fee");
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0.225e18, "the unpaid remainder flows to the full tier below");
        assertEq(dynamicFeeCurve.userStake(T1, alice), 0, "alice fully exited");
    }

    function test_recordRedeem_frontierPolicyRoutesToPriorTiers() external {
        // Reconfigure to 100% frontier routing (redeemToFulcrumTiersBps = BPS).
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = BPS;
        dynamicFeeCurve = _deploy(config);

        // alice at tier 0, bob at tier 1.
        _recordDeposit(T1, alice, 15e18, 0); // vaultStake 15 (tier 1)
        _recordDeposit(T1, bob, 3e18, 0); // tier 1, vaultStake 18

        // bob exits from tier 1; with full frontier routing, the fee targets prior tiers (tier 0 = alice).
        _recordRedeem(T1, bob, 3e18, 1e18);

        assertGt(dynamicFeeCurve.claimable(alice, T1), 0, "frontier routing pays the prior tier (alice)");
        assertEq(dynamicFeeCurve.claimable(bob, T1), 0, "exiter excluded");
    }

    function test_recordRedeem_partialExitKeepsResidualStake() external {
        _recordDeposit(T1, carol, 15e18, 0); // 10 at tier 0, 5 at tier 1
        _recordDeposit(T1, alice, 6e18, 0); // 15 -> 21, entirely inside tier 1's band: one lot at tier 1
        // bob's 6e18 straddles the 22e18 edge (1 at tier 1, 5 at tier 2): two lots, top lot at tier 2.
        _recordDeposit(T1, bob, 6e18, 0);
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), 2, "bob's top lot is where the last of his stake landed");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 1), 1e18, "bob's tier-1 lot");
        assertEq(dynamicFeeCurve.lotStake(T1, bob, 2), 5e18, "bob's tier-2 lot");

        _recordRedeem(T1, alice, 3e18, 0); // alice trims half, stays in tier 1

        assertEq(dynamicFeeCurve.userStake(T1, alice), 3e18, "residual stake retained");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 1), 3e18, "her one lot shrank in place");
        assertEq(
            dynamicFeeCurve.tierStake(T1, 1), 3e18 + 5e18 + 1e18, "tier 1 = alice's residual + carol's 5 + bob's 1"
        );
        assertEq(dynamicFeeCurve.tierStake(T1, 2), 5e18, "bob's tier-2 lot alone holds tier 2");
    }

    /// @dev A redeem unwinds lots highest tier first: the most recent band a holder entered is the
    ///      first to leave, its rate is charged on that portion, and only when it is exhausted does the
    ///      next lot down start to drain. The holder's top lot therefore moves DOWN on the way out,
    ///      which the averaged model never did.
    function test_recordRedeem_unwindsLotsHighestTierFirst() external {
        _recordDeposit(T1, alice, 25e18, 0); // 10 at tier 0, 12 at tier 1, 3 at tier 2; vault -> 25
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 2, "top lot at tier 2");

        // Exactly the tier-2 lot: the fee is priced at tier 2's rate and the top lot drops to tier 1.
        uint256 tierTwoFee = FixedPointMathLib.mulDivUp(3e18, dynamicFeeCurve.redeemFeeBps(2), BPS);
        assertEq(dynamicFeeCurve.quoteRedeemFee(T1, alice, 3e18), tierTwoFee, "quote walks the top lot first");
        _recordRedeem(T1, alice, 3e18, tierTwoFee);
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 1, "top lot moved down to tier 1");
        assertEq(dynamicFeeCurve.lotMask(T1, alice), 0x3, "tiers 0 and 1 remain");
        assertEq(dynamicFeeCurve.tierStake(T1, 2), 0, "tier 2 emptied");

        // A redeem straddling two lots: 4 from the tier-1 lot and the rest from below, priced per lot.
        uint256 straddleFee = FixedPointMathLib.mulDivUp(12e18, dynamicFeeCurve.redeemFeeBps(1), BPS)
            + FixedPointMathLib.mulDivUp(4e18, dynamicFeeCurve.redeemFeeBps(0), BPS);
        assertEq(dynamicFeeCurve.quoteRedeemFee(T1, alice, 16e18), straddleFee, "quote prices each lot at its rate");
        _recordRedeem(T1, alice, 16e18, straddleFee);
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 0, "only the tier-0 lot is left");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 0), 6e18, "tier-0 lot drained to 6");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 1), 0, "tier-1 lot gone");
        assertEq(dynamicFeeCurve.userStake(T1, alice), 6e18, "stake is the surviving lot");
        assertEq(dynamicFeeCurve.vaultStake(T1), 6e18, "vault follows");

        // Full exit clears the mask and the sentinel reports no lot.
        _recordRedeem(T1, alice, 6e18, 0);
        assertEq(dynamicFeeCurve.lotMask(T1, alice), 0, "no lots left");
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), dynamicFeeCurve.NO_LOT(), "sentinel when empty");
    }

    /// @dev A redeem that draws from two lots emits one {RedeemLotRecorded} per lot, highest tier
    ///      first, whose shares reconstruct the redeem and whose fees reconstruct the forwarded fee
    ///      exactly, plus one {RedeemRecorded} summary carrying the pre-unwind top tier.
    function test_recordRedeem_emitsPerLotAndSummaryEvents() external {
        _recordDeposit(T1, alice, 25e18, 0); // lots at tiers 0, 1, 2
        uint256 fee = dynamicFeeCurve.quoteRedeemFee(T1, alice, 5e18); // 3 from tier 2, 2 from tier 1

        vm.recordLogs();
        _recordRedeem(T1, alice, 5e18, fee);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 lotCount;
        uint256 lotShareSum;
        uint256 lotFeeSum;
        uint256 summaryCount;
        uint256 lastLotTier = type(uint256).max;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == REDEEM_LOT_RECORDED_TOPIC) {
                (uint256 lotTier, uint256 lotShares, uint256 lotFee) =
                    abi.decode(logs[i].data, (uint256, uint256, uint256));
                assertLt(lotTier, lastLotTier, "lots are emitted highest tier first");
                lastLotTier = lotTier;
                lotShareSum += lotShares;
                lotFeeSum += lotFee;
                ++lotCount;
            } else if (logs[i].topics[0] == REDEEM_RECORDED_TOPIC) {
                (uint256 shares, uint256 emittedFee, uint256 topTier) =
                    abi.decode(logs[i].data, (uint256, uint256, uint256));
                assertEq(shares, 5e18, "summary carries the shares");
                assertEq(emittedFee, fee, "summary carries the forwarded fee");
                assertEq(topTier, 2, "summary carries the top lot before the unwind");
                ++summaryCount;
            }
        }
        assertEq(lotCount, 2, "5e18 off a 3e18 top lot draws from two lots");
        assertEq(summaryCount, 1, "exactly one summary per redeem");
        assertEq(lotShareSum, 5e18, "the lot shares reconstruct the redeem");
        assertEq(lotFeeSum, fee, "the lot fees reconstruct the forwarded fee exactly");
    }

    /* =================================================== */
    /*          WHALE-EXIT FALLBACK (DECISION 5)          */
    /* =================================================== */

    /// @dev When the exiting tier has no residual cohort, the diamond slice reroutes to the nearest
    ///      occupied tier ABOVE (the stayer who sat above the exiting whale), not to the protocol.
    ///      Positions: alice in tiers 0 and 1, bob in tier 1 (sole above alice's sliver), carol in
    ///      tiers 2 and 3 (edges 10/22/36.4/53.68).
    function test_recordRedeem_whaleExit_reroutesToNearestTierAbove() external {
        _recordDeposit(T1, alice, 10e18, 0); // lot at tier 0; vault -> 10 (tier 1)
        _recordDeposit(T1, bob, 12e18, 0); // the whole tier-1 band; vault -> 22 (tier 2)
        _recordDeposit(T1, carol, 20e18, 0); // 14.4 at tier 2, 5.6 at tier 3; vault -> 42

        assertEq(dynamicFeeCurve.userTopTier(T1, bob), 1, "bob in tier 1");
        assertEq(dynamicFeeCurve.userTopTier(T1, carol), 3, "carol's top lot is tier 3");

        // bob, the sole holder of tier 1, exits fully -> diamond slice orphaned -> nearest above = tier 2.
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemFeeRerouted(T1, 1, 2, 1e18);
        _recordRedeem(T1, bob, 12e18, 1e18);

        assertApproxEqAbs(dynamicFeeCurve.claimable(carol, T1), 1e18, 1e3, "tier-2 stayer earns the whale exit fee");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "tier-0 holder earns nothing when a tier above exists");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "nothing forfeited to protocol");
    }

    /// @dev With no occupied tier above the exit tier, the reroute searches below.
    function test_recordRedeem_whaleExit_reroutesBelowWhenNothingAbove() external {
        _recordDeposit(T1, alice, 10e18, 0); // lot at tier 0; vault -> 10 (tier 1)
        _recordDeposit(T1, bob, 7e18, 0); // one lot at tier 1 (sole, top occupied); vault -> 17

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemFeeRerouted(T1, 1, 0, 1e18);
        _recordRedeem(T1, bob, 7e18, 1e18);

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

        // bob exits fully; carol remains in tier 1 -> diamond slice stays in tier 1, no reroute. Her
        // 2 TRUST fill a sixth of the 12 TRUST band, so she keeps a sixth of the slice and the rest
        // rejoins the fulcrum pool, where alice's full tier 0 is the only prior tier.
        _recordRedeem(T1, bob, 3e18, 1e18);

        assertApproxEqAbs(
            dynamicFeeCurve.claimable(carol, T1), uint256(1e18) / 6, 1e3, "same-tier cohort keeps its fill of the slice"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), uint256(5e18) / 6, 1e3, "the remainder reaches the full tier below"
        );
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
    /*              LOTS: TOP LOT MOVES BOTH WAYS          */
    /* =================================================== */

    /// @dev A small top-up at a high tier opens a lot there, so the next shares out are charged at
    ///      that tier; once that lot is drained the holder's top lot, and with it their exit rate,
    ///      drops back to where the rest of their stake entered. Stake already recorded never moves
    ///      in either direction, so a top-up can neither lift nor sink the rate on earlier stake.
    function test_recordRedeem_topLotDropsBackOnceTheHighLotIsDrained() external {
        _recordDeposit(T1, alice, 10e18, 0); // alice's lot at tier 0; vault -> 10 (tier 1)
        _recordDeposit(T1, bob, 30e18, 0); // 12 at tier 1, 14.4 at tier 2, 3.6 at tier 3; vault -> 40
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 3, "the vault must sit in tier 3");

        _recordDeposit(T1, alice, 1e18, 0); // a sliver at tier 3
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 3, "the top-up opens a lot at the vault's tier");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 0), 10e18, "the tier-0 lot is untouched");

        uint256 rateAtThree = dynamicFeeCurve.redeemFeeBps(3);
        uint256 rateAtZero = dynamicFeeCurve.redeemFeeBps(0);
        assertGt(rateAtThree, rateAtZero, "precondition: a higher tier carries a higher rate");
        assertEq(
            dynamicFeeCurve.quoteRedeemFee(T1, alice, 1e18),
            FixedPointMathLib.mulDivUp(1e18, rateAtThree, BPS),
            "the next share out is priced at the top lot's tier"
        );

        _recordRedeem(T1, alice, 1e18, 0);
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 0, "draining the high lot drops the top lot back to tier 0");
        assertEq(
            dynamicFeeCurve.quoteRedeemFee(T1, alice, 10e18),
            FixedPointMathLib.mulDivUp(10e18, rateAtZero, BPS),
            "the rest exits at the tier it entered through"
        );
    }

    /// @dev A partly filled prior tier keeps its fill of the spike and nothing of the spike's
    ///      remainder: the spike walks on to the next prior tier instead of entering the spread, where
    ///      the same thin tier would have collected a second helping of its own slice. With alpha = BPS
    ///      and sigma = 4 the spread from tier 2 weights tier 1 at 0.6 and tier 0 at 0.4, so a full
    ///      tier 1 would earn `0.5 + 0.6 * 0.5 = 0.8` of the fee; a half-filled tier 1 must earn exactly
    ///      half of that, 0.4: a quarter from the spike and 0.15 from the spread at the schedule
    ///      ceiling. Full tier 0 takes the spike's other quarter plus its own 0.2 of the spread, and the
    ///      0.15 the thin tier could not earn at the schedule rate accrues.
    function test_depositToPriorTier_partlyFilledSpikeTierIsNotCreditedTwice() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = 5000;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0; vault -> 10
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1; vault -> 22
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2; vault -> 36.4
        _recordDeposit(T1, dave, 2e18, 0); // tier 3; vault -> 38.4
        _recordRedeem(T1, bob, 6e18, 0); // tier 1 now half filled; vault -> 32.4 (tier 2)
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 2, "the vault must sit in tier 2");
        assertEq(dynamicFeeCurve.tierStake(T1, 1), 6e18, "tier 1 must be half filled");

        _recordDeposit(T1, eve, 1e18, 1e18); // one band at tier 2; prior tiers 1 (half) and 0 (full)

        assertApproxEqAbs(dynamicFeeCurve.claimable(bob, T1), 0.4e18, 1e3, "half-filled tier 1 earns half of 0.8");
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), 0.45e18, 1e3, "full tier 0: the spike's rest plus its 0.2"
        );
        assertApproxEqAbs(dynamicFeeCurve.protocolAccrued(), 0.15e18, 1e3, "the thin tier's shortfall accrues");
    }

    /// @dev The redeem-side reroute walks its candidates to exhaustion before anything reaches the
    ///      spread: above first, then below, each taking up to its fill. carol alone holds tier 2 and
    ///      exits a little; the slice goes above to dave's thin tier 3, which keeps its fill (2 of
    ///      17.28), then below to half-filled tier 1, which keeps half of what is left, then to full
    ///      tier 0, which takes the rest. Nothing accrues and nothing enters the spread.
    function test_recordRedeem_rerouteWalksAboveThenBelowUntilPlaced() external {
        address dave = makeAddr("dave");
        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2
        _recordDeposit(T1, dave, 2e18, 0); // thin tier 3; vault -> 38.4
        _recordRedeem(T1, bob, 6e18, 0); // tier 1 now half filled; vault -> 32.4 (tier 2)
        uint256 bobBefore = dynamicFeeCurve.claimable(bob, T1);

        vm.expectEmit(true, true, true, false);
        emit DynamicFeeFlatPriceCurve.RedeemFeeRerouted(T1, 2, 3, 0);
        _recordRedeem(T1, carol, 1e18, 1e18);

        uint256 daveFill = (uint256(1e18) * 2e18) / dynamicFeeCurve.tierWidthAt(3);
        uint256 afterDave = 1e18 - daveFill;
        assertApproxEqAbs(dynamicFeeCurve.claimable(dave, T1), daveFill, 1e3, "the thin tier above keeps its fill");
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(bob, T1) - bobBefore, afterDave / 2, 1e3, "the half-filled tier below keeps half"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), afterDave - afterDave / 2, 1e3, "the full tier takes the rest"
        );
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0, "the exiter earns nothing");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "nothing accrues to the protocol");
    }

    /// @dev A reroute step at an eligible tier still reports itself when the tier's fill floors the
    ///      credit to zero: dave's single wei at tier 3 is eligible at a zero floor, takes nothing of
    ///      carol's slice, and the event carries that zero. The walk then moves on and the full tier
    ///      below takes the slice. Pins the event's full data, not only its topics.
    function test_recordRedeem_rerouteEmitsAZeroAmountForAnEligibleTierWhoseCreditFloorsToZero() external {
        address dave = makeAddr("dave");
        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2; vault -> 36.4 (tier 3)
        _recordDeposit(T1, dave, 1, 0); // one wei at tier 3

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemFeeRerouted(T1, 2, 3, 0);
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemFeeRerouted(T1, 2, 1, 1e18);
        _recordRedeem(T1, carol, 1e18, 1e18);

        assertEq(dynamicFeeCurve.claimable(dave, T1), 0, "a one-wei seat takes nothing of the slice");
        assertApproxEqAbs(dynamicFeeCurve.claimable(bob, T1), 1e18, 1e3, "the full tier below takes it all");
    }

    /// @dev When every drawn lot's notional fee floors to zero (one-wei lots), the apportioning has
    ///      no weights to split by and the whole fee lands on the last lot drawn, so nothing is lost
    ///      and nothing is split by a zero denominator. Pinned on the per-lot events.
    function test_recordRedeem_zeroNotionalWeightsHandTheWholeFeeToTheLastLotDrawn() external {
        address eve = makeAddr("eve");
        _recordDeposit(T1, eve, 1, 0); // one wei at tier 0
        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0; vault -> tier 1
        _recordDeposit(T1, eve, 1, 0); // one wei at tier 1

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemLotRecorded(T1, eve, 1, 1, 0);
        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.RedeemLotRecorded(T1, eve, 0, 1, 1e18);
        _recordRedeem(T1, eve, 2, 1e18);

        assertEq(dynamicFeeCurve.userStake(T1, eve), 0, "both lots drained");
    }

    /// @dev What the spike's walk cannot place accrues; it does not join the spread, which would pay
    ///      the same thin tiers a second time. Tiers 1 and 0 are both half filled below a tier-2
    ///      deposit with a 50% spike. The walk pays tier 1 a quarter of the fee and tier 0 an eighth,
    ///      and the last eighth accrues. The spread's half then pays each tier at the schedule
    ///      ceiling: 0.15 to tier 1 and 0.10 to tier 0. A full tier 1 would have earned 0.8 of the
    ///      fee, so half-filled tier 1 earns exactly half of that. Had the eighth joined the spread,
    ///      both tiers would sit above the schedule rate per share.
    function test_depositToPriorTier_spikeResidueAccruesInsteadOfRejoiningTheSpread() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = 5000;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0; vault -> 10
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1; vault -> 22
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2; vault -> 36.4
        _recordDeposit(T1, dave, 2e18, 0); // tier 3; vault -> 38.4
        _recordRedeem(T1, bob, 6e18, 0); // tier 1 now half filled; vault -> 32.4 (tier 2)
        _recordRedeem(T1, alice, 5e18, 0); // tier 0 now half filled; vault -> 27.4 (tier 2)
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 2, "the vault must sit in tier 2");

        _recordDeposit(T1, eve, 1e18, 1e18); // one band at tier 2; both prior tiers half filled

        assertApproxEqAbs(dynamicFeeCurve.claimable(bob, T1), 0.4e18, 1e3, "tier 1: 0.25 of the spike + 0.15");
        assertApproxEqAbs(dynamicFeeCurve.claimable(alice, T1), 0.225e18, 1e3, "tier 0: 0.125 of the spike + 0.10");
        assertApproxEqAbs(
            dynamicFeeCurve.protocolAccrued(), 0.375e18, 1e3, "the spike's last eighth and the spread's shortfall"
        );
    }

    /// @dev The redeem-side twin: what the reroute walk cannot place accrues instead of joining the
    ///      spread. carol alone holds tier 2 and exits with a fee that is all exiting-tier slice. The
    ///      walk pays dave's thin tier 3 its fill, then half-filled tier 1 half of the rest, then
    ///      half-filled tier 0 half of that; the last part accrues, and neither thin tier sees it
    ///      again.
    function test_recordRedeem_rerouteLeftoverAccruesInsteadOfRejoiningTheSpread() external {
        address dave = makeAddr("dave");
        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2
        _recordDeposit(T1, dave, 2e18, 0); // thin tier 3; vault -> 38.4
        _recordRedeem(T1, alice, 5e18, 0); // tier 0 now half filled; vault -> 33.4
        _recordRedeem(T1, bob, 6e18, 0); // tier 1 now half filled; vault -> 27.4 (tier 2)

        _recordRedeem(T1, carol, 1e18, 1e18);

        uint256 daveFill = (uint256(1e18) * 2e18) / dynamicFeeCurve.tierWidthAt(3);
        uint256 afterDave = 1e18 - daveFill;
        uint256 afterBob = afterDave - afterDave / 2;
        assertApproxEqAbs(dynamicFeeCurve.claimable(dave, T1), daveFill, 1e3, "the thin tier above keeps its fill");
        assertApproxEqAbs(dynamicFeeCurve.claimable(bob, T1), afterDave / 2, 1e3, "tier 1 keeps half of the rest");
        assertApproxEqAbs(dynamicFeeCurve.claimable(alice, T1), afterBob / 2, 1e3, "tier 0 keeps half of that");
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0, "the exiter earns nothing");
        assertApproxEqAbs(
            dynamicFeeCurve.protocolAccrued(), afterBob - afterBob / 2, 1e3, "what no tier could take accrues"
        );
    }

    /// @dev The redeem-leg fallback with a live fulcrum share: the vault has fallen back into tier 0,
    ///      so the spread has no prior tier and places nothing, and the fulcrum half goes to the
    ///      cohort of the drawn lot's tier instead. bob's 1 of a 10-wide band takes a tenth of the
    ///      exiting slice and a tenth of the fulcrum slice, which together equal exactly what a full
    ///      band's holders earn per share from the whole fee; what he cannot take at his fill accrues,
    ///      and alice, the exiter, earns nothing of her own fee.
    function test_recordRedeem_vaultInTierZero_fulcrumShareFallsToTheDrawnLotsCohort() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = 5000;
        dynamicFeeCurve = _deploy(config);

        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0; vault -> 10
        _recordDeposit(T1, carol, 12e18, 0); // fills tier 1; vault -> 22
        _recordRedeem(T1, carol, 12e18, 0); // vault -> 10
        _recordRedeem(T1, alice, 5e18, 0); // vault -> 5 (tier 0)
        _recordDeposit(T1, bob, 1e18, 0); // thin cohort beside alice at tier 0; vault -> 6
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 0, "the vault must sit in tier 0");

        _recordRedeem(T1, alice, 1e18, 1e18);

        assertApproxEqAbs(
            dynamicFeeCurve.claimable(bob, T1), 0.1e18, 1e3, "a tenth of the exiting slice plus a tenth of the fulcrum"
        );
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "the exiter earns nothing");
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0, "a departed holder earns nothing");
        assertApproxEqAbs(dynamicFeeCurve.protocolAccrued(), 0.9e18, 1e3, "what the thin cohort cannot take accrues");
    }

    /// @dev The same fallback when the vault is above tier 0 but every prior tier has emptied: the
    ///      spread from tier 2 finds nothing below, so the fulcrum half goes to the cohort of the
    ///      drawn lot's tier (eve, 1 of a 14.4-wide band), capped at her fill, and the rest accrues.
    ///      The exiting slice pays eve her fill too and walks the rest up to dave's full tier 3. eve's
    ///      per-share income from the whole fee is exactly the full-band rate `fee / width`, and the
    ///      exiter earns nothing.
    function test_recordRedeem_everyPriorTierEmpty_fulcrumShareFallsToTheDrawnLotsCohortThenAccrues() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = 5000;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2
        _recordDeposit(T1, dave, 17.28e18, 0); // fills tier 3; vault -> 53.68
        _recordRedeem(T1, alice, 10e18, 0); // tier 0 empty
        _recordRedeem(T1, bob, 12e18, 0); // tier 1 empty; vault -> 31.68 (tier 2)
        _recordDeposit(T1, eve, 1e18, 0); // thin cohort beside carol at tier 2; vault -> 32.68
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 2, "the vault must sit in tier 2");

        _recordRedeem(T1, carol, 1e18, 1e18);

        uint256 width2 = dynamicFeeCurve.tierWidthAt(2);
        uint256 eveFillOfHalf = (uint256(0.5e18) * 1e18) / width2;
        assertApproxEqAbs(dynamicFeeCurve.claimable(eve, T1), 2 * eveFillOfHalf, 1e3, "eve: her fill of both halves");
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(dave, T1), 0.5e18 - eveFillOfHalf, 1e3, "dave: the rest of the exiting slice"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.protocolAccrued(), 0.5e18 - eveFillOfHalf, 1e3, "the rest of the fulcrum half accrues"
        );
        assertEq(dynamicFeeCurve.claimable(carol, T1), 0, "the exiter earns nothing");
        assertEq(dynamicFeeCurve.claimable(alice, T1) + dynamicFeeCurve.claimable(bob, T1), 0, "departed holders");
    }

    /// @dev Redeem-leg ceiling and conservation, over random fills of the ladder, a random exit size
    ///      and a random fulcrum share. For every tier the per-share income from one redeem fee is at
    ///      most the full-band rate `fee / width`, whichever of the exiting slice, the reroute walk,
    ///      the spread and the cohort fallback delivered it; the exiter earns nothing of it at any
    ///      tier; and the fee is accounted for in full, up to per-share floor dust.
    function testFuzz_recordRedeem_perShareIncomeNeverExceedsTheFullBandRate(
        uint256 keep0,
        uint256 keep1,
        uint256 keep2,
        uint256 exit,
        uint256 fulcrumBps
    ) external {
        keep0 = bound(keep0, 0, 10e18);
        keep1 = bound(keep1, 0, 12e18);
        keep2 = bound(keep2, 0, 14.4e18);
        fulcrumBps = bound(fulcrumBps, 0, BPS);
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = fulcrumBps;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");

        _recordDeposit(T1, alice, 10e18, 0);
        _recordDeposit(T1, bob, 12e18, 0);
        _recordDeposit(T1, carol, 14.4e18, 0);
        _recordDeposit(T1, dave, 17.28e18, 0); // vault -> 53.68 (tier 4); dave holds lots at tier 3 only
        if (keep2 < 14.4e18) _recordRedeem(T1, carol, 14.4e18 - keep2, 0);
        if (keep1 < 12e18) _recordRedeem(T1, bob, 12e18 - keep1, 0);
        if (keep0 < 10e18) _recordRedeem(T1, alice, 10e18 - keep0, 0);
        exit = bound(exit, 1, 17.28e18);

        uint256 tierCount = config.tierCount;
        uint256[] memory accBefore = new uint256[](tierCount);
        for (uint256 t; t < tierCount; ++t) {
            accBefore[t] = dynamicFeeCurve.accFeePerShare(T1, t);
        }
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        _recordRedeem(T1, dave, exit, 1e18);

        uint256 distributed = dynamicFeeCurve.protocolAccrued() - protocolBefore;
        for (uint256 t; t < tierCount; ++t) {
            uint256 delta = dynamicFeeCurve.accFeePerShare(T1, t) - accBefore[t];
            uint256 stake = dynamicFeeCurve.tierStake(T1, t);
            if (stake == 0) {
                assertEq(delta, 0, "an empty tier earns nothing");
                continue;
            }
            uint256 width = dynamicFeeCurve.tierWidthAt(t);
            assertLe(
                delta * width, uint256(1e18) * 1e18 + (4 * 1e18 * width) / stake, "per-share above the full-band rate"
            );
            distributed += (delta * stake) / 1e18;
        }
        // dave's residual lot at tier 3 sits inside `tierStake[3]` but was re-based, so its share of
        // that tier's credit is not claimable by anyone: it is what the exclusion withholds.
        assertEq(dynamicFeeCurve.claimable(dave, T1), 0, "the exiter earns nothing of their own fee");
        assertLe(1e18 - distributed, 1e3, "every wei lands in a tier or the protocol bucket");
    }

    /// @dev A tier at the very edge of the window carries a kernel weight of a single unit. With
    ///      `sigma = 1e18 + 1` and the peak on the nearest tier, tier 1 at distance one has weight 1
    ///      and tier 0 at distance two has weight 0. Half-filled tier 1 must still take its whole
    ///      schedule share (half the pool, the other half accruing) and full tier 0, outside the
    ///      window, nothing. Were the effective weight computed at kernel precision it would round to
    ///      zero and the fill-only fallback would hand tier 0 half the pool.
    function test_fulcrum_edgeOfWindowWeightKeepsTheKernelInsteadOfFallingBackToFill() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositKernelSpread = 1e18 + 1;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");

        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0
        _recordDeposit(T1, bob, 12e18, 0); // fills tier 1
        _recordDeposit(T1, carol, 14.4e18, 0); // fills tier 2; vault -> 36.4
        _recordRedeem(T1, bob, 6e18, 0); // tier 1 now half filled; vault -> 30.4 (tier 2)
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 2, "the vault must sit in tier 2");

        _recordDeposit(T1, dave, 1e18, 1e18);

        assertApproxEqAbs(dynamicFeeCurve.claimable(bob, T1), 0.5e18, 1e3, "the edge tier takes its schedule share");
        assertEq(dynamicFeeCurve.claimable(alice, T1), 0, "the tier outside the window earns nothing");
        assertApproxEqAbs(dynamicFeeCurve.protocolAccrued(), 0.5e18, 1e3, "the thin tier's shortfall accrues");
    }

    /// @dev Per-share ceiling and conservation on the deposit leg, over random fills of the three
    ///      prior tiers and a random spike. For every prior tier the per-share income from one fee
    ///      is at most what a full band would earn from the spike plus its kernel share of the pool,
    ///      whatever combination of walk and spread delivered it; and the fee is accounted for in
    ///      full between the tier accumulators and the protocol bucket, up to per-share floor dust.
    function testFuzz_recordDeposit_perShareIncomeNeverExceedsTheScheduleRate(
        uint256 keep0,
        uint256 keep1,
        uint256 keep2,
        uint256 spikeBps
    ) external {
        keep0 = bound(keep0, 0, 10e18);
        keep1 = bound(keep1, 0, 12e18);
        keep2 = bound(keep2, 0, 14.4e18);
        spikeBps = bound(spikeBps, 0, BPS);
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = spikeBps;
        dynamicFeeCurve = _deploy(config);
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        _recordDeposit(T1, alice, 10e18, 0);
        _recordDeposit(T1, bob, 12e18, 0);
        _recordDeposit(T1, carol, 14.4e18, 0);
        _recordDeposit(T1, dave, 2e18, 0); // vault -> 38.4 (tier 3)
        if (keep2 < 14.4e18) _recordRedeem(T1, carol, 14.4e18 - keep2, 0);
        if (keep1 < 12e18) _recordRedeem(T1, bob, 12e18 - keep1, 0);
        if (keep0 < 10e18) _recordRedeem(T1, alice, 10e18 - keep0, 0);

        uint256 source = dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1));
        uint256[] memory accBefore = new uint256[](source);
        for (uint256 t; t < source; ++t) {
            accBefore[t] = dynamicFeeCurve.accFeePerShare(T1, t);
        }
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        _recordDeposit(T1, eve, 1, 1e18); // one wei of stake: a single band at the vault's tier

        uint256 distributed = dynamicFeeCurve.protocolAccrued() - protocolBefore;
        for (uint256 t; t < source; ++t) {
            distributed += _assertTierWithinSchedule(t, source, accBefore[t], (uint256(1e18) * spikeBps) / BPS);
        }
        assertLe(1e18 - distributed, 1e3, "every wei lands in a tier or the protocol bucket");
    }

    /// @dev One tier's check for the ceiling fuzz: its accumulator moved by at most a full band's
    ///      income from a 1e18 fee (the whole `spike` plus its kernel share of the rest) per unit of
    ///      width, up to four wei of per-share floor dust. Returns what the tier's stake was credited.
    function _assertTierWithinSchedule(uint256 tier, uint256 source, uint256 accBefore, uint256 spike)
        internal
        view
        returns (uint256 credited)
    {
        uint256 delta = dynamicFeeCurve.accFeePerShare(T1, tier) - accBefore;
        uint256 stake = dynamicFeeCurve.tierStake(T1, tier);
        if (stake == 0) {
            assertEq(delta, 0, "an empty tier earns nothing");
            return 0;
        }
        uint256 width = dynamicFeeCurve.tierWidthAt(tier);
        uint256 fullBandIncome = spike + _kernelShare(1e18 - spike, source - tier, source);
        assertLe(delta * width, fullBandIncome * 1e18 + (4 * 1e18 * width) / stake, "per-share above schedule");
        credited = (delta * stake) / 1e18;
    }

    /// @dev The schedule share of `pool` for the prior tier at distance `d` under the suite's default
    ///      kernel (peak on the nearest tier, `sigma` of four tiers): its kernel weight over the plain
    ///      kernel sum across all `span` prior tiers.
    function _kernelShare(uint256 pool, uint256 d, uint256 span) internal pure returns (uint256) {
        uint256 sumRef;
        for (uint256 k = 1; k <= span; ++k) {
            sumRef += _kernelWeight(k, span);
        }
        return sumRef == 0 ? 0 : (pool * _kernelWeight(d, span)) / sumRef;
    }

    /// @dev The curve's triangular kernel under the suite's default pair, replicated: the weight of
    ///      the prior tier at integer distance `d` from a source with `span` prior tiers, in WAD.
    function _kernelWeight(uint256 d, uint256 span) internal pure returns (uint256) {
        uint256 dStar = ((BPS - 10_000) * span * WAD) / BPS;
        uint256 dP = d * WAD;
        uint256 dist = dP > dStar ? dP - dStar : dStar - dP;
        uint256 ratio = (dist * WAD) / 4e18;
        return ratio < WAD ? WAD - ratio : 0;
    }

    /// @dev A deposit that sweeps several bands recovers, through the band it filled itself, its
    ///      proportional share of the fee its next band pays, and no more: each band's fee reaches the
    ///      tiers below it, and the band just filled is a prior tier like any other. This is the
    ///      per-band earlier-cohort rule applied inside one transaction, identical to what N wallets
    ///      landing the same bands would collect. The occupancy weighting also shows the over-full case
    ///      absorbing a thin one: bob's 6 lands on carol's full tier 1, making it hold 18 of 12, so its
    ///      effective weight is 1.5 x 0.75 while thin tier 0 (4 of 10) carries 0.4 x 0.5; the ladder
    ///      as a whole holds more than its widths, the pool is spread whole, and tier 0's shortfall is
    ///      absorbed by the over-full tier rather than accruing.
    function test_recordDeposit_sweepRecoversOnlyItsShareOfTheBandBelow() external {
        _recordDeposit(T1, alice, 10e18, 0); // fills tier 0; vault -> 10
        _recordDeposit(T1, carol, 12e18, 0); // fills tier 1; vault -> 22
        _recordRedeem(T1, alice, 6e18, 0); // tier 0 now 4 of 10; vault -> 16 (tier 1)

        // bob's 20.4 lands 6 at tier 1 (18 of 12: over-full) and 14.4 at tier 2. The forwarded 3.78
        // splits by notional fee, 6 x 1.5% against 14.4 x 2%, into 0.9 for band 1 and 2.88 for band 2.
        _recordDeposit(T1, bob, 20.4e18, 3.78e18);

        // Band 1's 0.9: tier 0 is the only prior tier, at 40% fill; it keeps 0.36 and 0.54 accrues.
        // Band 2's 2.88: effective weights 1.125 (tier 1) and 0.2 (tier 0) sum to 1.325 > the
        // schedule's 1.25, so the pool spreads whole: tier 1 takes 2.88 x 1.125 / 1.325, tier 0 the rest.
        // bob owns a third of tier 1.
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), 794_716_981_132_075_468, 1e4, "alice: 0.36 + 2.88 x 0.2 / 1.325"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(carol, T1),
            1_630_188_679_245_283_018,
            1e4,
            "carol: two thirds of 2.88 x 1.125 / 1.325"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(bob, T1),
            815_094_339_622_641_509,
            1e4,
            "bob: a third of the same, out of his own band's fee"
        );
        assertApproxEqAbs(dynamicFeeCurve.protocolAccrued(), 0.54e18, 1e3, "only band 1's shortfall accrues");
    }

    /// @dev An exiter holding lots at several tiers is excluded from their own fee at every tier it
    ///      reaches, not only the tier being drained: their residual lots are left out of every
    ///      denominator and re-based afterwards. Here the fee has two legs. The exiting-tier slice at
    ///      tier 2 pays carol her fill and walks the rest down to bob's full tier 1. The fulcrum spread
    ///      from tier 2 sees tier 1 (bob, full) and tier 0, which alice holds alone: with her excluded
    ///      that tier has no eligible stake, so bob earns exactly his 60% schedule share of the spread
    ///      and tier 0's 40% has nobody to earn it and accrues.
    function test_recordRedeem_exiterWithLotsAtSeveralTiersEarnsNothingAnywhere() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = 5000;
        dynamicFeeCurve = _deploy(config);

        _recordDeposit(T1, alice, 10e18, 0); // alice's lot at tier 0; vault -> 10
        _recordDeposit(T1, bob, 12e18, 0); // bob fills tier 1; vault -> 22 (tier 2)
        _recordDeposit(T1, carol, 6e18, 0); // carol at tier 2; vault -> 28
        _recordDeposit(T1, alice, 4e18, 0); // alice's second lot, at tier 2; vault -> 32
        assertEq(dynamicFeeCurve.lotMask(T1, alice), 0x5, "alice holds lots at tiers 0 and 2");
        uint256 aliceBefore = dynamicFeeCurve.claimable(alice, T1);

        // alice drains half her tier-2 lot with a 1e18 fee: half to tier 2's other holder, capped at
        // carol's fill of the band, and the rest to the spread, whose only eligible prior tier once
        // alice is excluded is bob's full tier 1.
        _recordRedeem(T1, alice, 2e18, 1e18);

        assertEq(dynamicFeeCurve.claimable(alice, T1), aliceBefore, "the exiter earns nothing at any of her tiers");
        uint256 carolShare = (uint256(0.5e18) * 6e18) / dynamicFeeCurve.tierWidthAt(2);
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(carol, T1), carolShare, 1e3, "the cohort keeps its fill of the exiting-tier slice"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(bob, T1),
            (0.5e18 - carolShare) + 0.3e18,
            1e3,
            "bob: the rest of the exiting-tier slice, plus his 60% schedule share of the 0.5 spread"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.protocolAccrued(),
            0.2e18,
            1e3,
            "tier 0's 40% of the spread has no eligible stake: alice is excluded"
        );
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 2), 2e18, "the tier-2 lot halved in place");
        assertEq(dynamicFeeCurve.lotStake(T1, alice, 0), 10e18, "the tier-0 lot is untouched");
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
        // 15e18 into an empty vault spans two bands: 10 at tier 0 and 5 at tier 1. The tier-0 band has
        // no prior tier to reward, so its share of the fee is the part that accrues to the protocol.
        // The tier-1 band's share reaches tier 0 — where alice's own band-0 stake has already landed.
        _recordDeposit(T1, alice, 15e18, 1e18);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        dynamicFeeCurve.sweepProtocol(bob);

        uint256 accrued = dynamicFeeCurve.protocolAccrued();
        // Apportioned by band weight: 10e18*100bps of 1750e18 total weight.
        assertEq(accrued, 571_428_571_428_571_428, "protocol accrued only the tier-0 band's share");
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1), 1e18 - accrued, 1e3, "the tier-1 band's share reached tier 0"
        );
        uint256 balBefore = carol.balance;
        dynamicFeeCurve.sweepProtocol(carol); // owner == address(this)
        assertEq(carol.balance - balBefore, accrued, "swept to recipient");
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "protocol bucket cleared");
    }

    /// @dev The sweep's own guard, distinct from the `onlyOwner` one above: an owner who fat-fingers the
    ///      recipient would otherwise burn the whole protocol bucket to the zero address irrecoverably.
    function test_sweepProtocol_revertsOnZeroRecipient() external {
        _recordDeposit(T1, alice, 15e18, 1e18);
        assertGt(dynamicFeeCurve.protocolAccrued(), 0, "there must be something to sweep");

        vm.expectRevert(abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_ZeroAddress.selector));
        dynamicFeeCurve.sweepProtocol(address(0));
    }

    /// @dev Sweeping an empty bucket is a no-op that returns zero rather than reverting or emitting.
    ///      A monitor that sweeps on a schedule must not have to pre-check the balance, and an empty
    ///      {ProtocolSwept} would be a misleading signal for anything watching the bucket.
    function test_sweepProtocol_returnsZeroWhenNothingHasAccrued() external {
        assertEq(dynamicFeeCurve.protocolAccrued(), 0, "the bucket starts empty");

        uint256 balanceBefore = carol.balance;
        vm.recordLogs();
        uint256 swept = dynamicFeeCurve.sweepProtocol(carol);

        assertEq(swept, 0, "an empty sweep returns zero");
        assertEq(carol.balance, balanceBefore, "and moves nothing");
        assertEq(vm.getRecordedLogs().length, 0, "and emits nothing a monitor could misread");
    }

    function test_initialize_revertsOnSecondCall() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        dynamicFeeCurve.initialize(CURVE_NAME, owner, address(this), _defaultConfig());
    }

    /// @dev Both halves of the initializer's zero-address guard. They are one `||` expression, so a test
    ///      that only ever passes a zero OWNER leaves the MultiVault operand unexercised — and a curve
    ///      initialized against the zero MultiVault would be permanently inert: every record hook is
    ///      `onlyMultiVault`, and `multiVault` has no setter.
    function test_initialize_revertsOnZeroOwner() external {
        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        bytes memory initCall = abi.encodeWithSelector(
            DynamicFeeFlatPriceCurve.initialize.selector, CURVE_NAME, address(0), address(this), _defaultConfig()
        );

        vm.expectRevert(abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_ZeroAddress.selector));
        new TransparentUpgradeableProxy(address(impl), proxyAdmin, initCall);
    }

    function test_initialize_revertsOnZeroMultiVault() external {
        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        bytes memory initCall = abi.encodeWithSelector(
            DynamicFeeFlatPriceCurve.initialize.selector, CURVE_NAME, owner, address(0), _defaultConfig()
        );

        vm.expectRevert(abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_ZeroAddress.selector));
        new TransparentUpgradeableProxy(address(impl), proxyAdmin, initCall);
    }

    /// @dev A deposit that mints nothing still forwards a fee. MultiVault invokes the hook on every
    ///      deposit into a hook curve, including ones whose net stake rounds to zero, so this is a live
    ///      path rather than a defensive one. There is no band to walk, so the fee is distributed once
    ///      from the vault's CURRENT tier — the branch the band replay never reaches.
    function test_recordDeposit_zeroNetStake_stillDistributesTheFeeFromTheCurrentTier() external {
        // Seat alice in tier 0 and leave the vault in tier 1, so a fee released now has a prior tier.
        _recordDeposit(T1, alice, 10e18, 0);
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 1, "the vault must be out of tier 0");
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), 0, "alice must hold the tier below");

        uint256 aliceBefore = dynamicFeeCurve.claimable(alice, T1);
        uint256 vaultBefore = dynamicFeeCurve.vaultStake(T1);
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        _recordDeposit(T1, bob, 0, 1e18);

        assertEq(dynamicFeeCurve.vaultStake(T1), vaultBefore, "a zero-stake deposit moves no stake");
        assertEq(dynamicFeeCurve.userStake(T1, bob), 0, "and mints the depositor nothing");
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(alice, T1) - aliceBefore, 1e18, 1e3, "the whole fee still reaches the prior tier"
        );
        assertEq(dynamicFeeCurve.protocolAccrued(), protocolBefore, "and none of it is orphaned");
    }

    /// @dev The same path with no prior tier to reach: released from tier 0, a zero-stake deposit's fee
    ///      has nowhere to go but the protocol bucket. Pins that it is never silently forfeited.
    function test_recordDeposit_zeroNetStake_inTierZero_accruesTheFeeToTheProtocol() external {
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        _recordDeposit(T1, bob, 0, 1e18);

        assertEq(dynamicFeeCurve.vaultStake(T1), 0, "nothing landed");
        assertEq(dynamicFeeCurve.protocolAccrued() - protocolBefore, 1e18, "the undistributable fee is retained");
    }

    /// @dev The name-only initializer inherited from {LinearCurve} stays on the ABI but is inert: the
    ///      proxy's atomic 4-arg init already consumed the one-shot `initializer` slot.
    function test_initialize_inheritedLinearCurveInitializer_isInert() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        LinearCurve(address(dynamicFeeCurve)).initialize("Some Other Name");
    }

    /* =================================================== */
    /*        A VAULT THAT FALLS BELOW ITS HOLDERS         */
    /* =================================================== */

    /// @dev The drawdown case, pinned because it is the one most likely to be reported as a bug.
    ///
    ///      Lots stay at their entry tier and are deliberately NOT re-priced when the vault shrinks,
    ///      so after a large exit by someone else the surviving holders can all sit ABOVE the vault's
    ///      current tier. A deposit fee reaches only the tiers strictly below its band, so in that
    ///      state a new deposit pays nobody and its fee accrues to {protocolAccrued}. That is the
    ///      tier-0 rule generalized — the mechanism pays "whoever was here before you climbed", and
    ///      when everyone is above you there is no such party. A holder cannot put themselves in this
    ///      state: their own exit unwinds their highest lots first, so it takes another holder's exit
    ///      to leave them stranded.
    ///
    ///      Three bounding claims come with it in the contract NatSpec, and a defence is only as good
    ///      as its test, so all three are asserted here: already-earned credit does not move, the fee
    ///      is retained rather than destroyed, and the behaviour reverses on the way back up with no
    ///      intervention.
    function test_vaultFallsBelowItsHolders_feeGoesToProtocolAndRecoversOnTheWayBackUp() external {
        // A whale carries the vault into tier 2 and alice enters inside that band, so her one lot sits
        // at tier 2.
        address whale = makeAddr("whale");
        _recordDeposit(T1, whale, 30e18, 0); // 10 / 12 / 8 across tiers 0, 1, 2; vault -> 30 (tier 2)
        _recordDeposit(T1, alice, 1e18, 0); // one lot at tier 2; vault -> 31
        uint256 aliceBucket = dynamicFeeCurve.userTopTier(T1, alice);
        assertEq(aliceBucket, 2, "alice must hold a lot above tier 0 for this scenario to exist");

        // The drawdown: the whale exits entirely and the vault falls back down the ladder, leaving
        // tier 0 genuinely empty below her.
        _recordRedeem(T1, whale, 30e18, 0);
        uint256 vaultTier = dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1));
        assertLt(vaultTier, aliceBucket, "the vault must end BELOW its surviving holder");
        assertEq(dynamicFeeCurve.tierStake(T1, 0), 0, "tier 0 must be empty, or someone is below her");
        assertEq(dynamicFeeCurve.userTopTier(T1, alice), aliceBucket, "another holder's exit must not re-price her lot");

        uint256 aliceEarnedBeforeDrawdownDeposit = dynamicFeeCurve.claimable(alice, T1);
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();
        uint256 balanceBefore = address(dynamicFeeCurve).balance;

        // A deposit while the vault sits below every holder. Contained in the vault's current band.
        uint256 strandedFee = 1e18;
        _recordDeposit(T1, bob, 2e18, strandedFee);

        assertEq(
            dynamicFeeCurve.claimable(alice, T1),
            aliceEarnedBeforeDrawdownDeposit,
            "a holder above the vault earns nothing from a deposit below her"
        );
        assertEq(
            dynamicFeeCurve.protocolAccrued() - protocolBefore,
            strandedFee,
            "the whole fee is retained by the protocol rather than forfeited"
        );
        assertEq(
            address(dynamicFeeCurve).balance, balanceBefore + strandedFee, "and it is actually held, not destroyed"
        );

        // RECOVERY, with no intervention: climb back past her lot and she earns again. The band
        // that crosses ABOVE her lot is the one that can reach her.
        uint256 aliceBeforeRecovery = dynamicFeeCurve.claimable(alice, T1);
        _recordDeposit(T1, carol, 40e18, 1e18);

        assertGt(
            dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)),
            aliceBucket,
            "the recovery deposit must carry the vault back above her"
        );
        assertGt(
            dynamicFeeCurve.claimable(alice, T1), aliceBeforeRecovery, "she earns again once the vault climbs past her"
        );
        // Monotonicity: the drawdown never clawed anything back, it only paused new credit.
        assertGe(
            dynamicFeeCurve.claimable(alice, T1),
            aliceEarnedBeforeDrawdownDeposit,
            "already-earned credit is never reduced by a drawdown"
        );
    }

    /// @dev The redeem leg is explicitly NOT affected by a drawdown, and that asymmetry is load-bearing:
    ///      exits are exactly the activity a drawdown produces, so if redeem fees also stranded
    ///      themselves the mechanism would go dark precisely when it is busiest. Redeem fees key on
    ///      the exiter's own lots, not on where the vault happens to sit, so they keep paying each
    ///      lot tier's remaining occupants all the way down — at the schedule rate per share. The
    ///      cohort here holds a fourteenth of its band, so it keeps that fraction of the slice; the rest
    ///      has no prior tier to reach with the vault back in tier 0 and is undistributable.
    function test_vaultFallsBelowItsHolders_redeemFeesStillReachTheExitersCohort() external {
        // A whale carries the vault up to tier 2, then two small holders enter INSIDE that band so both
        // hold one lot at tier 2.
        address whale = makeAddr("whale");
        _recordDeposit(T1, whale, 30e18, 0);
        assertEq(dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)), 2, "the whale must leave the vault in tier 2");

        _recordDeposit(T1, alice, 1e18, 0);
        _recordDeposit(T1, bob, 1e18, 0);
        uint256 sharedBucket = dynamicFeeCurve.userTopTier(T1, alice);
        assertEq(sharedBucket, 2, "alice's lot must sit in the band she entered in");
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), sharedBucket, "both holders must share a lot tier");

        // The drawdown: the whale leaves (its own lots unwind top-down) and the vault falls far below
        // the tier those two still hold.
        _recordRedeem(T1, whale, 28e18, 0);
        assertLt(
            dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(T1)),
            sharedBucket,
            "the vault must end below the shared lot tier"
        );

        uint256 bobBefore = dynamicFeeCurve.claimable(bob, T1);
        uint256 protocolBefore = dynamicFeeCurve.protocolAccrued();

        // Alice exits a little more. Her redeem fee must still find bob, who shares her lot tier.
        uint256 exitFee = 1e18;
        _recordRedeem(T1, alice, 1e18, exitFee);

        uint256 bobFillShare = (exitFee * 1e18) / dynamicFeeCurve.tierWidthAt(sharedBucket);
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(bob, T1) - bobBefore,
            bobFillShare,
            1e3,
            "the exit fee still reaches the cohort even with the vault below them, at the schedule rate"
        );
        // What bob cannot take walks on: nothing above, then below to the whale's residual tier-0 lot
        // (2 of 10), which keeps a fifth of it; the rest has nowhere left and accrues.
        assertApproxEqAbs(
            dynamicFeeCurve.claimable(whale, T1),
            (exitFee - bobFillShare) / 5,
            1e3,
            "the thin tier below keeps its fill"
        );
        assertApproxEqAbs(
            dynamicFeeCurve.protocolAccrued() - protocolBefore,
            (exitFee - bobFillShare) - (exitFee - bobFillShare) / 5,
            1e3,
            "what no holder can take at the schedule rate accrues, with the vault in tier 0"
        );
    }

    /* =================================================== */
    /*                 TIER FEE OVERRIDE                   */
    /* =================================================== */

    function test_setTierFeeOverride_replacesBothRatesForThatTier() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);

        assertEq(dynamicFeeCurve.depositFeeBps(2), 750, "tier 2 deposit uses the override");
        assertEq(dynamicFeeCurve.redeemFeeBps(2), 900, "tier 2 redeem uses the override");
    }

    function test_setTierFeeOverride_getterExposesStoredOverride() external {
        dynamicFeeCurve.setTierFeeOverride(3, 111, 222);

        (bool isSet, uint16 depositBps, uint16 redeemBps) = dynamicFeeCurve.tierFeeOverride(3);
        assertTrue(isSet, "override marked set");
        assertEq(depositBps, 111, "stored deposit bps");
        assertEq(redeemBps, 222, "stored redeem bps");
    }

    /// @dev The core sparsity guarantee: overriding one tier leaves every other tier on the formula.
    function test_setTierFeeOverride_leavesEveryOtherTierOnFormula() external {
        dynamicFeeCurve.setTierFeeOverride(2, 750, 900);

        uint256 tierCount = dynamicFeeCurve.getConfig().tierCount;
        for (uint256 tier = 0; tier < tierCount; ++tier) {
            if (tier == 2) continue;
            assertEq(dynamicFeeCurve.depositFeeBps(tier), 100 + tier * 50, "untouched tier keeps formulaic deposit");
            assertEq(dynamicFeeCurve.redeemFeeBps(tier), 200 + tier * 50, "untouched tier keeps formulaic redeem");
            (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(tier);
            assertFalse(isSet, "untouched tier carries no override");
        }
    }

    /// @dev A bare 0-sentinel would be ambiguous; `isSet` makes an explicit 0-bps tier expressible.
    function test_setTierFeeOverride_explicitZeroBpsIsExpressible() external {
        dynamicFeeCurve.setTierFeeOverride(1, 0, 0);

        assertEq(dynamicFeeCurve.depositFeeBps(1), 0, "explicit 0-bps deposit override");
        assertEq(dynamicFeeCurve.redeemFeeBps(1), 0, "explicit 0-bps redeem override");
        (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(1);
        assertTrue(isSet, "0-bps is a real override, not 'unset'");
    }

    /// @dev The override replaces the formula rate but stays within the schedule's declared caps: it
    ///      may set any rate up to `depositCapBps` / `redeemCapBps` (both 1000 here), not beyond.
    function test_setTierFeeOverride_maySetRateUpToTheCap() external {
        dynamicFeeCurve.setTierFeeOverride(0, 1000, 1000);

        assertEq(dynamicFeeCurve.depositFeeBps(0), 1000, "override may sit exactly at the deposit cap");
        assertEq(dynamicFeeCurve.redeemFeeBps(0), 1000, "override may sit exactly at the redeem cap");
    }

    function test_setTierFeeOverride_revertsOnDepositBpsAboveCap() external {
        // depositCapBps = 1000, so 1001 is out of range.
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector);
        dynamicFeeCurve.setTierFeeOverride(0, 1001, 0);
    }

    function test_setTierFeeOverride_revertsOnRedeemBpsAboveCap() external {
        // redeemCapBps = 1000, so 1001 is out of range.
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector);
        dynamicFeeCurve.setTierFeeOverride(0, 0, 1001);
    }

    function test_setTierFeeOverride_appliesToQuoteDepositFee_singleBand() external {
        // Empty vault, 5e18 fits inside tier 0. Formula would charge 1% = 0.05e18.
        dynamicFeeCurve.setTierFeeOverride(0, 400, 0);
        assertEq(dynamicFeeCurve.quoteDepositFee(T1, 5e18), 0.2e18, "single band charged at the override rate");
    }

    /// @dev The piecewise walk must consult EACH traversed band's own override, not just the entry
    ///      band's. Overriding only the middle band (tier 2) upward must raise the blend, and by
    ///      exactly what the independent per-band restatement says.
    function test_quoteDepositFee_piecewiseConsultsOverriddenMiddleBand() external {
        uint256 baseline = dynamicFeeCurve.quoteDepositFee(T1, 100e18);
        assertEq(baseline, _expectedPiecewiseFrom(0, 100e18), "baseline piecewise blend");

        dynamicFeeCurve.setTierFeeOverride(2, 500, 0);

        uint256 overridden = dynamicFeeCurve.quoteDepositFee(T1, 100e18);
        assertEq(overridden, _expectedPiecewiseFrom(0, 100e18), "middle band charged at its override");
        assertGt(overridden, baseline, "raising a traversed band's rate raises the blend");
    }

    /// @dev Zeroing a middle band removes exactly that band's contribution and nothing else.
    function test_quoteDepositFee_piecewiseWithZeroedMiddleBand() external {
        uint256 baseline = dynamicFeeCurve.quoteDepositFee(T1, 100e18);

        dynamicFeeCurve.setTierFeeOverride(2, 0, 0);

        uint256 zeroed = dynamicFeeCurve.quoteDepositFee(T1, 100e18);
        assertEq(zeroed, _expectedPiecewiseFrom(0, 100e18), "zeroed band drops only its own slice");
        assertLt(zeroed, baseline, "zeroing a traversed band lowers the blend");
        assertEq(zeroed, 2_094_623_296_613_144_331, "golden blend with tier 2 zeroed");
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
        assertEq(dynamicFeeCurve.redeemFeeBps(2), 300, "redeem back on the formula");
        (bool isSet,,) = dynamicFeeCurve.tierFeeOverride(2);
        assertFalse(isSet, "override cleared");
        assertEq(
            dynamicFeeCurve.quoteDepositFee(T1, 100e18),
            _expectedPiecewiseFrom(0, 100e18),
            "piecewise blend back to baseline"
        );
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
        config.depositFulcrumAlphaBps = BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    /// @dev `depositKernelSpread` (σ) divides the triangular weight, so a zero spread is rejected, and it is
    ///      bounded above so the weight math stays clear of overflow.
    function test_setConfig_revertsOnInvalidKernelSpread() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositKernelSpread = 0;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);

        config.depositKernelSpread = dynamicFeeCurve.MAX_KERNEL_SPREAD() + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnRedeemFulcrumAlphaAboveBps() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemFulcrumAlphaBps = BPS + 1;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);
    }

    function test_setConfig_revertsOnInvalidRedeemKernelSpread() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemKernelSpread = 0;
        vm.expectRevert(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector);
        dynamicFeeCurve.setConfig(config);

        config.redeemKernelSpread = dynamicFeeCurve.MAX_KERNEL_SPREAD() + 1;
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
        config.tierWidthGrowthBps = 100 * BPS + 1;
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
        uint256 bobTierBefore = dynamicFeeCurve.userTopTier(T1, bob);
        assertGt(aliceClaimableBefore, 0, "precondition: alice earned");

        // Owner doubles the tier widths mid-flight.
        DynamicFeeConfig memory config = _defaultConfig();
        config.width0 = 20e18;
        dynamicFeeCurve.setConfig(config);

        // Sticky buckets: recorded ids and booked earnings are untouched...
        assertEq(dynamicFeeCurve.userTopTier(T1, bob), bobTierBefore, "bucket ids are sticky across retunes");
        assertEq(dynamicFeeCurve.claimable(alice, T1), aliceClaimableBefore, "earnings unaffected by retune");
        // ...while future tier decisions use the new schedule immediately.
        assertEq(dynamicFeeCurve.tierOf(15e18), 0, "tierOf follows the new schedule (15 < new width0 20)");
    }

    function test_setConfig_revertsOnRedeemShareAboveBps() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.redeemToFulcrumTiersBps = BPS + 1;
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
        _recordDeposit(T1, alice, 15e18, 0); // vaultStake 15 -> tier 1
        _recordDeposit(T1, address(attacker), 12e18, 0); // enters tier 1; vaultStake 27 -> tier 2
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
