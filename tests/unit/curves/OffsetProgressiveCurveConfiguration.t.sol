// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18, wrap, unwrap } from "@prb/math/src/UD60x18.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

/**
 * @title OffsetProgressiveCurveConfigurationTest
 * @notice Comprehensive configuration-based testing for OffsetProgressiveCurve
 * @dev This test suite explores different SLOPE and OFFSET parameters to understand
 *      their impact on curve behavior, pricing, and economic outcomes.
 *
 * Key Testing Dimensions:
 * 1. SLOPE variations (steepness of price increase)
 * 2. OFFSET variations (initial price point)
 * 3. SLOPE + OFFSET interactions
 * 4. Edge cases and boundary conditions
 * 5. Economic property validation across configurations
 *
 * Testing Philosophy:
 * - Each test runs against multiple configurations
 * - Logs provide visibility into parameter impacts
 * - Assertions validate economic invariants hold across all configs
 * - Fuzz testing explores the parameter space comprehensively
 */
contract OffsetProgressiveCurveConfigurationTest is Test {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @dev Configuration struct to test different curve parameters
    struct CurveConfig {
        string name;
        uint256 slope;
        uint256 offset;
        string description;
    }

    /// @dev Metrics collected during testing for analysis
    struct CurveMetrics {
        uint256 initialPrice; // Price at zero supply
        uint256 priceAt1e18Shares; // Price at 1e18 shares
        uint256 costToMint1e18Shares; // Cost to mint first 1e18 shares
        uint256 costToMint50e18Shares; // Cost to mint 50e18 shares from 0
        uint256 costToMint100e18Shares; // Cost to mint 100e18 shares from 0
        uint256 costToMint500e18Shares; // Cost to mint 500e18 shares from 0
        uint256 costToMint2500e18Shares; // Cost to mint 2500e18 shares from 0
        uint256 maxShares; // Maximum shares before overflow
        uint256 maxAssets; // Maximum assets before overflow
        uint256 priceGrowthRate; // How fast price increases per share
        uint256 averageCostPer1e18Shares; // Average cost per share in first batch
    }

    /// @dev All test configurations
    CurveConfig[] public configurations;

    /// @dev Mapping of config index to deployed curve
    mapping(uint256 => OffsetProgressiveCurve) public curves;

    /// @dev Mapping of config index to collected metrics
    mapping(uint256 => CurveMetrics) public metrics;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    function setUp() public {
        _initializeConfigurations();
        _deployCurves();
        _collectMetrics();
    }

    /* =================================================== */
    /*                 CONFIGURATION SETUP                 */
    /* =================================================== */

    function _initializeConfigurations() internal {
        // SLOPE VARIATIONS - Testing different price steepness levels

        // Ultra-low slope - Very gentle price increase
        configurations.push(
            CurveConfig({
                name: "Ultra-Low Slope",
                slope: 2, // 0.000000000000000002 per share (even number required)
                offset: 1e18,
                description: "Minimal price increase, suitable for high-volume tokens"
            })
        );

        // Low slope - Gentle price increase
        configurations.push(
            CurveConfig({
                name: "Low Slope",
                slope: 1e12, // 0.000001 per share
                offset: 1e18,
                description: "Gentle price curve, encourages early participation"
            })
        );

        // Medium slope - Moderate price increase
        configurations.push(
            CurveConfig({
                name: "Medium Slope",
                slope: 1e15, // 0.001 per share
                offset: 1e18,
                description: "Balanced price growth"
            })
        );

        // High slope - Steep price increase
        configurations.push(
            CurveConfig({
                name: "High Slope",
                slope: 1e16, // 0.01 per share
                offset: 1e18,
                description: "Aggressive price curve, penalizes late entry"
            })
        );

        // OFFSET VARIATIONS - Testing different initial price points

        // Zero offset - Price starts at zero
        configurations.push(
            CurveConfig({
                name: "Zero Offset",
                slope: 1e15,
                offset: 0,
                description: "Price starts at zero, allows for very cheap initial shares"
            })
        );

        // Low offset - Small initial price
        configurations.push(
            CurveConfig({
                name: "Low Offset",
                slope: 1e15,
                offset: 1e15, // 0.001
                description: "Small initial price floor"
            })
        );

        // Medium offset - Moderate initial price
        configurations.push(
            CurveConfig({
                name: "Medium Offset",
                slope: 1e15,
                offset: 1e18, // 1.0
                description: "Reasonable initial price, prevents extremely cheap early shares"
            })
        );

        // High offset - Large initial price
        configurations.push(
            CurveConfig({
                name: "High Offset",
                slope: 1e15,
                offset: 1e21, // 1000.0
                description: "High initial price floor, makes curve more linear in practice"
            })
        );

        // COMBINED VARIATIONS - Testing interactions

        // Steep with high offset - Aggressive on both axes
        configurations.push(
            CurveConfig({
                name: "Steep + High Offset",
                slope: 1e16,
                offset: 1e20,
                description: "Aggressive curve, high initial price and steep growth"
            })
        );

        // Gentle with low offset - Permissive on both axes
        configurations.push(
            CurveConfig({
                name: "Gentle + Low Offset",
                slope: 1e12,
                offset: 1e15,
                description: "Very permissive, allows cheap entry and slow growth"
            })
        );

        // EDGE CASES

        // Minimum valid slope
        configurations.push(
            CurveConfig({
                name: "Minimum Slope",
                slope: 2, // Smallest even number > 0
                offset: 5e35, // Large offset to prevent overflow
                description: "Tests minimum valid slope parameter"
            })
        );

        // Large offset for gentler curve
        configurations.push(
            CurveConfig({
                name: "Very Large Offset",
                slope: 1e15,
                offset: 1e30,
                description: "Tests how large offset smooths the curve"
            })
        );

        // ===================================================================
        // OPTIMIZED CONFIGURATIONS FOR "GENTLE EARLY, STEEP LATER"
        // Goal: Gentle from 1e18 to 150e18, then progressively steeper
        // ===================================================================

        // OPTIMAL #1: Slope=2, Offset=100e18
        // Theory: offset ≈ upper bound of gentle range creates near-linear behavior early
        // When n ≤ 150e18 and offset = 100e18, the n² term is dampened
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=2, offset=100e18)",
                slope: 2,
                offset: 100e18,
                description: "Ultra-minimal slope with offset at gentle range boundary. Keeps costs very low early, quadratic effect kicks in after 100e18."
            })
        );

        // OPTIMAL #2: Slope=4, Offset=100e18
        // Theory: Slightly higher slope but still minimal, same offset strategy
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=4, offset=100e18)",
                slope: 4,
                offset: 100e18,
                description: "Low slope with offset at gentle range boundary. Affordable early, steepens naturally after 100e18."
            })
        );

        // OPTIMAL #3: Slope=10, Offset=150e18
        // Theory: Offset exactly at the upper bound (150e18) makes curve linear up to that point
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=10, offset=150e18)",
                slope: 10,
                offset: 150e18,
                description: "Offset set at exact gentle range limit (150e18). Nearly linear until 150e18, then quadratic kicks in."
            })
        );

        // OPTIMAL #4: Slope=2, Offset=150e18
        // Theory: Best of both - minimal slope + offset at upper bound
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=2, offset=150e18)",
                slope: 2,
                offset: 150e18,
                description: "Ultra-low slope with offset at gentle range limit. Maximum gentleness early, natural steepness late."
            })
        );

        // OPTIMAL #5: Slope=2, Offset=200e18
        // Theory: Offset slightly above range for extra gentleness
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=2, offset=200e18)",
                slope: 2,
                offset: 200e18,
                description: "Ultra-low slope with large offset. Extends gentle range beyond 150e18, then steep growth."
            })
        );

        // OPTIMAL #6: Slope=4, Offset=150e18
        // Theory: Balance between slope and offset
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=4, offset=150e18)",
                slope: 4,
                offset: 150e18,
                description: "Balanced configuration. Linear until 150e18, then moderate quadratic growth."
            })
        );

        // OPTIMAL #7: Slope=10, Offset=100e18
        // Theory: Higher slope for more revenue, offset still provides early gentleness
        configurations.push(
            CurveConfig({
                name: "Optimal Gentle-Steep (slope=10, offset=100e18)",
                slope: 10,
                offset: 100e18,
                description: "Moderate slope with medium offset. Gentle early but generates more revenue overall."
            })
        );
    }

    function _deployCurves() internal {
        for (uint256 i = 0; i < configurations.length; i++) {
            CurveConfig memory config = configurations[i];

            OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
            TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
                address(impl),
                address(this),
                abi.encodeWithSelector(
                    OffsetProgressiveCurve.initialize.selector, config.name, config.slope, config.offset
                )
            );

            curves[i] = OffsetProgressiveCurve(address(proxy));
        }
    }

    function _collectMetrics() internal {
        for (uint256 i = 0; i < configurations.length; i++) {
            OffsetProgressiveCurve curve = curves[i];

            uint256 initialPrice = curve.currentPrice(0, 0);
            uint256 priceAt1e18 = curve.currentPrice(1e18, 0);
            uint256 costToMint1e18 = curve.previewMint(1e18, 0, 0);
            uint256 costToMint50e18 = curve.previewMint(50e18, 0, 0);
            uint256 costToMint100e18 = curve.previewMint(100e18, 0, 0);
            uint256 costToMint500e18 = curve.previewMint(500e18, 0, 0);
            uint256 costToMint2500e18 = curve.previewMint(2500e18, 0, 0);
            uint256 maxShares = curve.maxShares();
            uint256 maxAssets = curve.maxAssets();

            // Calculate growth rate: (P(1e18) - P(0)) per share
            // Don't divide to avoid precision loss - keep in 18-decimal space
            uint256 priceGrowthRate = priceAt1e18 > initialPrice ? (priceAt1e18 - initialPrice) : 0;

            // Average cost per share in first batch
            uint256 avgCost = costToMint1e18 / 1e18;

            metrics[i] = CurveMetrics({
                initialPrice: initialPrice,
                priceAt1e18Shares: priceAt1e18,
                costToMint1e18Shares: costToMint1e18,
                costToMint50e18Shares: costToMint50e18,
                costToMint100e18Shares: costToMint100e18,
                costToMint500e18Shares: costToMint500e18,
                costToMint2500e18Shares: costToMint2500e18,
                maxShares: maxShares,
                maxAssets: maxAssets,
                priceGrowthRate: priceGrowthRate,
                averageCostPer1e18Shares: avgCost
            });
        }
    }

    /* =================================================== */
    /*                   LOGGING UTILITIES                 */
    /* =================================================== */

    function _logConfiguration(uint256 configIndex) internal view {
        CurveConfig memory config = configurations[configIndex];
        CurveMetrics memory metric = metrics[configIndex];

        console.log("==========================================");
        console.log("Configuration:", config.name);
        console.log("==========================================");
        console.log("Description:", config.description);
        console.log("SLOPE:", config.slope);
        console.log("OFFSET:", config.offset);
        console.log("");
        console.log("--- Pricing Metrics ---");
        console.log("Initial Price (at 0 shares):", metric.initialPrice);
        console.log("Price at 1e18 shares:", metric.priceAt1e18Shares);
        console.log("Price growth rate:", metric.priceGrowthRate);
        console.log("");
        console.log("--- Minting Costs (from supply = 0) ---");
        console.log("Cost to mint 1e18 shares:", metric.costToMint1e18Shares);
        console.log("Cost to mint 50e18 shares:", metric.costToMint50e18Shares);
        console.log("Cost to mint 100e18 shares:", metric.costToMint100e18Shares);
        console.log("Cost to mint 500e18 shares:", metric.costToMint500e18Shares);
        console.log("Cost to mint 2500e18 shares:", metric.costToMint2500e18Shares);
        console.log("");
        console.log("--- Cost Per Share Analysis ---");
        console.log("Avg cost/share (1e18):", metric.costToMint1e18Shares / 1e18);
        console.log("Avg cost/share (50e18):", metric.costToMint50e18Shares / 50e18);
        console.log("Avg cost/share (100e18):", metric.costToMint100e18Shares / 100e18);
        console.log("Avg cost/share (500e18):", metric.costToMint500e18Shares / 500e18);
        console.log("Avg cost/share (2500e18):", metric.costToMint2500e18Shares / 2500e18);
        console.log("");
        console.log("--- Steepness Indicators ---");
        uint256 earlyGrowth = metric.costToMint100e18Shares > metric.costToMint50e18Shares
            ? (metric.costToMint100e18Shares - metric.costToMint50e18Shares) / 50e18
            : 0;
        uint256 lateGrowth = metric.costToMint500e18Shares > metric.costToMint100e18Shares
            ? (metric.costToMint500e18Shares - metric.costToMint100e18Shares) / 400e18
            : 0;
        uint256 veryLateGrowth = metric.costToMint2500e18Shares > metric.costToMint500e18Shares
            ? (metric.costToMint2500e18Shares - metric.costToMint500e18Shares) / 2000e18
            : 0;
        console.log("Marginal cost/share (50-100e18):", earlyGrowth);
        console.log("Marginal cost/share (100-500e18):", lateGrowth);
        console.log("Marginal cost/share (500-2500e18):", veryLateGrowth);
        console.log("Steepness ratio (late/early):", earlyGrowth > 0 ? lateGrowth * 100 / earlyGrowth : 0);
        console.log("");
        console.log("--- Capacity ---");
        console.log("Max shares:", metric.maxShares);
        console.log("Max assets:", metric.maxAssets);
        console.log("==========================================");
        console.log("");
    }

    function _logComparison(uint256 configIndex1, uint256 configIndex2) internal view {
        CurveConfig memory config1 = configurations[configIndex1];
        CurveConfig memory config2 = configurations[configIndex2];
        CurveMetrics memory metric1 = metrics[configIndex1];
        CurveMetrics memory metric2 = metrics[configIndex2];

        console.log("==========================================");
        console.log("COMPARISON");
        console.log("==========================================");
        console.log("Config 1:", config1.name);
        console.log("Config 2:", config2.name);
        console.log("");
        console.log("--- Initial Price ---");
        console.log("Config 1:", metric1.initialPrice);
        console.log("Config 2:", metric2.initialPrice);
        console.log(
            "Difference:",
            metric1.initialPrice > metric2.initialPrice
                ? metric1.initialPrice - metric2.initialPrice
                : metric2.initialPrice - metric1.initialPrice
        );
        console.log("");
        console.log("--- Cost to mint 1e18 shares ---");
        console.log("Config 1:", metric1.costToMint1e18Shares);
        console.log("Config 2:", metric2.costToMint1e18Shares);
        console.log("");
        console.log("--- Max Shares ---");
        console.log("Config 1:", metric1.maxShares);
        console.log("Config 2:", metric2.maxShares);
        console.log("==========================================");
        console.log("");
    }

    /* =================================================== */
    /*              SLOPE PARAMETER TESTS                  */
    /* =================================================== */

    /// @notice Test that slope directly controls price growth rate
    function test_slope_controlsPriceGrowthRate() public view {
        // Compare ultra-low, low, medium, and high slope configs
        uint256 ultraLowIdx = 0;
        uint256 lowIdx = 1;
        uint256 mediumIdx = 2;
        uint256 highIdx = 3;

        uint256 ultraLowGrowth = metrics[ultraLowIdx].priceGrowthRate;
        uint256 lowGrowth = metrics[lowIdx].priceGrowthRate;
        uint256 mediumGrowth = metrics[mediumIdx].priceGrowthRate;
        uint256 highGrowth = metrics[highIdx].priceGrowthRate;

        // Growth rate should increase with slope
        assertLt(ultraLowGrowth, lowGrowth, "Ultra-low slope should have slower growth than low slope");
        assertLt(lowGrowth, mediumGrowth, "Low slope should have slower growth than medium slope");
        assertLt(mediumGrowth, highGrowth, "Medium slope should have slower growth than high slope");

        // Log for visibility
        console.log("=== SLOPE IMPACT ON PRICE GROWTH ===");
        console.log("Ultra-low slope growth rate:", ultraLowGrowth);
        console.log("Low slope growth rate:", lowGrowth);
        console.log("Medium slope growth rate:", mediumGrowth);
        console.log("High slope growth rate:", highGrowth);
        console.log("Ratio (High/Ultra-low):", highGrowth / (ultraLowGrowth > 0 ? ultraLowGrowth : 1));
    }

    /// @notice Test that slope affects minting costs proportionally
    function test_slope_affectsMintingCostsProportionally() public view {
        uint256 lowIdx = 1; // slope: 1e12
        uint256 mediumIdx = 2; // slope: 1e15
        uint256 highIdx = 3; // slope: 1e16

        uint256 lowCost = metrics[lowIdx].costToMint1e18Shares;
        uint256 mediumCost = metrics[mediumIdx].costToMint1e18Shares;
        uint256 highCost = metrics[highIdx].costToMint1e18Shares;

        // Cost should increase with slope
        assertLt(lowCost, mediumCost, "Low slope should cost less than medium slope");
        assertLt(mediumCost, highCost, "Medium slope should cost less than high slope");

        // Check proportionality: cost ratio should approximately match slope ratio
        uint256 lowSlope = configurations[lowIdx].slope;
        uint256 mediumSlope = configurations[mediumIdx].slope;

        uint256 slopeRatio = (mediumSlope * 1e18) / lowSlope; // Scaled ratio
        uint256 costRatio = (mediumCost * 1e18) / lowCost; // Scaled ratio

        // Allow 10% variance for rounding and offset effects
        uint256 tolerance = slopeRatio / 10;
        assertApproxEqAbs(costRatio, slopeRatio, tolerance, "Cost ratio should match slope ratio");

        console.log("=== SLOPE PROPORTIONALITY ===");
        console.log("Slope ratio (medium/low):", slopeRatio);
        console.log("Cost ratio (medium/low):", costRatio);
    }

    /// @notice Test slope parameter validation during initialization
    function test_slope_validation_revertsOnZero() public {
        OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(this), "");

        vm.expectRevert(abi.encodeWithSelector(OffsetProgressiveCurve.OffsetProgressiveCurve_InvalidSlope.selector));
        OffsetProgressiveCurve(address(proxy)).initialize("Test", 0, 1e18);
    }

    /// @notice Test slope parameter validation - must be even
    function test_slope_validation_revertsOnOdd() public {
        OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(this), "");

        vm.expectRevert(abi.encodeWithSelector(OffsetProgressiveCurve.OffsetProgressiveCurve_InvalidSlope.selector));
        OffsetProgressiveCurve(address(proxy)).initialize("Test", 3, 1e18); // Odd number
    }

    /// @notice Fuzz test: Higher slope always results in higher costs for same shares
    function testFuzz_slope_higherSlopeHigherCost(uint256 shares, uint256 slopeMultiplier) public {
        // Use medium slope config as baseline
        uint256 baselineIdx = 2;
        shares = bound(shares, 1e15, 1e18);
        slopeMultiplier = bound(slopeMultiplier, 2, 100);

        // Ensure even slope
        uint256 baseSlope = configurations[baselineIdx].slope;
        uint256 higherSlope = baseSlope * slopeMultiplier;
        if (higherSlope % 2 != 0) higherSlope += 1;

        // Deploy two curves with different slopes
        OffsetProgressiveCurve curveBase = _deployCurveForTest("Base", baseSlope, 1e18);
        OffsetProgressiveCurve curveHigher = _deployCurveForTest("Higher", higherSlope, 1e18);

        uint256 costBase = curveBase.previewMint(shares, 0, 0);
        uint256 costHigher = curveHigher.previewMint(shares, 0, 0);

        assertGt(costHigher, costBase, "Higher slope should always cost more");
    }

    /* =================================================== */
    /*              OFFSET PARAMETER TESTS                 */
    /* =================================================== */

    /// @notice Test that offset sets the initial price floor
    function test_offset_setsInitialPriceFloor() public view {
        uint256 zeroOffsetIdx = 4;
        uint256 lowOffsetIdx = 5;
        uint256 mediumOffsetIdx = 6;
        uint256 highOffsetIdx = 7;

        uint256 zeroPrice = metrics[zeroOffsetIdx].initialPrice;
        uint256 lowPrice = metrics[lowOffsetIdx].initialPrice;
        uint256 mediumPrice = metrics[mediumOffsetIdx].initialPrice;
        uint256 highPrice = metrics[highOffsetIdx].initialPrice;

        // Initial price should increase with offset
        assertEq(zeroPrice, 0, "Zero offset should have zero initial price");
        assertGt(lowPrice, zeroPrice, "Low offset should have higher initial price than zero");
        assertGt(mediumPrice, lowPrice, "Medium offset should have higher initial price than low");
        assertGt(highPrice, mediumPrice, "High offset should have higher initial price than medium");

        console.log("=== OFFSET IMPACT ON INITIAL PRICE ===");
        console.log("Zero offset initial price:", zeroPrice);
        console.log("Low offset initial price:", lowPrice);
        console.log("Medium offset initial price:", mediumPrice);
        console.log("High offset initial price:", highPrice);
    }

    /// @notice Test that offset makes curve more linear (reduces relative price growth)
    function test_offset_reducesRelativePriceGrowth() public view {
        uint256 lowOffsetIdx = 5; // offset: 1e15
        uint256 highOffsetIdx = 7; // offset: 1e21

        OffsetProgressiveCurve lowOffsetCurve = curves[lowOffsetIdx];
        OffsetProgressiveCurve highOffsetCurve = curves[highOffsetIdx];

        // Calculate relative price change: (P(1e18) - P(0)) / P(0)
        uint256 lowInitial = lowOffsetCurve.currentPrice(0, 0);
        uint256 lowAt1e18 = lowOffsetCurve.currentPrice(1e18, 0);
        uint256 lowRelativeGrowth = lowInitial > 0 ? ((lowAt1e18 - lowInitial) * 1e18) / lowInitial : 0;

        uint256 highInitial = highOffsetCurve.currentPrice(0, 0);
        uint256 highAt1e18 = highOffsetCurve.currentPrice(1e18, 0);
        uint256 highRelativeGrowth = highInitial > 0 ? ((highAt1e18 - highInitial) * 1e18) / highInitial : 0;

        // Higher offset should have lower relative growth
        assertLt(highRelativeGrowth, lowRelativeGrowth, "High offset should have lower relative price growth");

        console.log("=== OFFSET IMPACT ON RELATIVE GROWTH ===");
        console.log("Low offset relative growth:", lowRelativeGrowth);
        console.log("High offset relative growth:", highRelativeGrowth);
    }

    /// @notice Test that offset calculation matches formula: P(0) = OFFSET * SLOPE
    function test_offset_initialPriceMatchesFormula() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            CurveConfig memory config = configurations[i];
            OffsetProgressiveCurve curve = curves[i];

            uint256 actualPrice = curve.currentPrice(0, 0);
            uint256 expectedPrice = unwrap(wrap(config.offset).mul(wrap(config.slope)));

            assertEq(actualPrice, expectedPrice, "Initial price should equal OFFSET * SLOPE");
        }
    }

    /// @notice Test that offset prevents extremely cheap early shares
    function test_offset_preventsExtremelyCheapEarlyShares() public view {
        uint256 zeroOffsetIdx = 4;
        uint256 mediumOffsetIdx = 6;

        OffsetProgressiveCurve zeroOffsetCurve = curves[zeroOffsetIdx];
        OffsetProgressiveCurve mediumOffsetCurve = curves[mediumOffsetIdx];

        // Cost of first 1e18 shares
        uint256 zeroCost = zeroOffsetCurve.previewMint(1e18, 0, 0);
        uint256 mediumCost = mediumOffsetCurve.previewMint(1e18, 0, 0);

        // Medium offset should cost significantly more
        assertGt(mediumCost, zeroCost, "Offset should increase cost of early shares");
        assertGt(mediumCost, zeroCost * 2, "Offset should more than double early share costs");

        console.log("=== OFFSET IMPACT ON EARLY SHARE COSTS ===");
        console.log("Zero offset cost for 1e18 shares:", zeroCost);
        console.log("Medium offset cost for 1e18 shares:", mediumCost);
        console.log("Cost multiplier:", mediumCost / (zeroCost > 0 ? zeroCost : 1));
    }

    /// @notice Fuzz test: Offset shifts entire price curve upward uniformly
    function testFuzz_offset_shiftsPriceCurveUniformly(uint256 shares, uint256 offsetAmount) public {
        shares = bound(shares, 0, 1e20);
        offsetAmount = bound(offsetAmount, 1e15, 1e25);

        uint256 baseSlope = 1e15;

        // Deploy curves with different offsets
        OffsetProgressiveCurve curveZero = _deployCurveForTest("Zero", baseSlope, 0);
        OffsetProgressiveCurve curveOffset = _deployCurveForTest("Offset", baseSlope, offsetAmount);

        uint256 priceZero = curveZero.currentPrice(shares, 0);
        uint256 priceOffset = curveOffset.currentPrice(shares, 0);

        // Price difference should equal OFFSET * SLOPE
        uint256 expectedDifference = unwrap(wrap(offsetAmount).mul(wrap(baseSlope)));
        uint256 actualDifference = priceOffset - priceZero;

        // Allow for 1 wei rounding error in fixed-point arithmetic
        assertApproxEqAbs(actualDifference, expectedDifference, 1, "Offset should shift price by OFFSET * SLOPE");
    }

    /* =================================================== */
    /*          SLOPE + OFFSET INTERACTION TESTS           */
    /* =================================================== */

    /// @notice Test combinations of steep slope with high offset
    function test_combined_steepSlopeHighOffset() public view {
        uint256 combinedIdx = 8; // Steep + High Offset config

        _logConfiguration(combinedIdx);

        OffsetProgressiveCurve curve = curves[combinedIdx];
        CurveMetrics memory metric = metrics[combinedIdx];

        // Should have high initial price (from offset)
        assertGe(metric.initialPrice, 1e18, "Should have substantial initial price");

        // Should have high growth rate (from slope)
        // Growth rate is total price change over 1e18 shares
        assertGt(metric.priceGrowthRate, 1e15, "Should have steep price growth");

        // Minting should be more expensive than gentle configs
        // Compare to gentle config (idx 9)
        uint256 gentleCost = metrics[9].costToMint1e18Shares;
        assertGt(metric.costToMint1e18Shares, gentleCost * 10, "Should be expensive to mint shares");
    }

    /// @notice Test combinations of gentle slope with low offset
    function test_combined_gentleSlopeLowOffset() public view {
        uint256 combinedIdx = 9; // Gentle + Low Offset config

        _logConfiguration(combinedIdx);

        OffsetProgressiveCurve curve = curves[combinedIdx];
        CurveMetrics memory metric = metrics[combinedIdx];

        // Should have low initial price (from offset)
        assertLt(metric.initialPrice, 1e18, "Should have low initial price");

        // Should have low growth rate (from slope)
        assertLt(metric.priceGrowthRate, 1e15, "Should have gentle price growth");

        // Minting should be cheap - compare to steep config (idx 8)
        uint256 steepCost = metrics[8].costToMint1e18Shares;
        assertLt(metric.costToMint1e18Shares, steepCost / 10, "Should be cheap to mint shares");
    }

    /// @notice Test that offset and slope independently affect different aspects
    function test_combined_independentEffects() public view {
        // Compare configs where only one parameter changes
        uint256 mediumSlope_MediumOffset = 6; // slope: 1e15, offset: 1e18
        uint256 mediumSlope_HighOffset = 7; // slope: 1e15, offset: 1e21

        // Changing offset should affect initial price but not growth rate
        uint256 mediumGrowth = metrics[mediumSlope_MediumOffset].priceGrowthRate;
        uint256 highOffsetGrowth = metrics[mediumSlope_HighOffset].priceGrowthRate;

        // Growth rate should be similar (same slope)
        assertEq(mediumGrowth, highOffsetGrowth, "Same slope should give same growth rate");

        // But initial prices should differ (different offset)
        uint256 mediumInitial = metrics[mediumSlope_MediumOffset].initialPrice;
        uint256 highInitial = metrics[mediumSlope_HighOffset].initialPrice;
        assertGt(highInitial, mediumInitial, "Higher offset should have higher initial price");

        console.log("=== INDEPENDENT PARAMETER EFFECTS ===");
        console.log("Medium offset - initial price:", mediumInitial);
        console.log("High offset - initial price:", highInitial);
        console.log("Medium offset - growth rate:", mediumGrowth);
        console.log("High offset - growth rate:", highOffsetGrowth);
    }

    /// @notice Fuzz test: Verify cost formula with various SLOPE and OFFSET combinations
    function testFuzz_combined_costFormulaCorrectness(
        uint256 slope,
        uint256 offset,
        uint256 shares,
        uint256 totalShares
    )
        public
    {
        // Bound inputs to reasonable ranges
        slope = bound(slope, 2, 1e18);
        if (slope % 2 != 0) slope += 1; // Ensure even
        offset = bound(offset, 0, 1e30);
        shares = bound(shares, 1e15, 1e18);
        totalShares = bound(totalShares, 0, 1e20);

        // Deploy curve with these parameters
        OffsetProgressiveCurve curve = _deployCurveForTest("Fuzz", slope, offset);

        // Ensure we don't exceed max shares
        if (totalShares + shares > curve.maxShares()) {
            shares = curve.maxShares() - totalShares;
            if (shares == 0) return; // Skip if at max
        }

        // Calculate cost manually using formula
        // Cost = ((s1 + o)^2 - (s0 + o)^2) * (slope / 2)
        UD60x18 s0PlusOffset = wrap(totalShares).add(wrap(offset));
        UD60x18 s1PlusOffset = wrap(totalShares + shares).add(wrap(offset));
        UD60x18 halfSlope = wrap(slope / 2);

        UD60x18 expectedCostUD = s1PlusOffset.mul(s1PlusOffset).sub(s0PlusOffset.mul(s0PlusOffset)).mul(halfSlope);
        uint256 expectedCost = unwrap(expectedCostUD);

        // Get actual cost from curve
        uint256 actualCost = curve.previewMint(shares, totalShares, 0);

        // Should match (allowing for rounding)
        assertApproxEqAbs(actualCost, expectedCost, 1, "Cost should match formula");
    }

    /* =================================================== */
    /*              ECONOMIC INVARIANT TESTS               */
    /* =================================================== */

    /// @notice Test that all configurations maintain monotonic price increase
    function test_invariant_monotonicPriceIncrease() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            OffsetProgressiveCurve curve = curves[i];

            uint256 price0 = curve.currentPrice(0, 0);
            uint256 price1 = curve.currentPrice(1e18, 0);
            uint256 price2 = curve.currentPrice(2e18, 0);

            assertLe(price0, price1, "Price should not decrease");
            assertLe(price1, price2, "Price should not decrease");

            // If slope > 0, price should strictly increase
            if (configurations[i].slope > 0) {
                assertLt(price0, price2, "Price should strictly increase for positive slope");
            }
        }
    }

    /// @notice Test that mint-redeem round-trip is approximately neutral
    function test_invariant_mintRedeemRoundTrip() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            OffsetProgressiveCurve curve = curves[i];

            uint256 sharesToMint = 1e18;
            uint256 totalShares = 10e18;

            uint256 costToMint = curve.previewMint(sharesToMint, totalShares, 0);
            uint256 returnFromRedeem = curve.previewRedeem(sharesToMint, totalShares + sharesToMint, 0);

            // Should be very close (within 1 wei due to rounding)
            assertApproxEqAbs(costToMint, returnFromRedeem, 1, "Mint-redeem round trip should be approximately neutral");
        }
    }

    /// @notice Test that deposit-withdraw round-trip burns appropriate shares
    function test_invariant_depositWithdrawRoundTrip() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            OffsetProgressiveCurve curve = curves[i];

            uint256 totalShares = 100e18;

            // Calculate a safe amount of assets to withdraw (10% of what's available at this supply)
            uint256 availableAssets = curve.previewRedeem(totalShares / 10, totalShares, 0);

            // Use that amount for both deposit and withdraw
            uint256 sharesFromDeposit = curve.previewDeposit(availableAssets, 0, totalShares);
            uint256 sharesFromWithdraw = curve.previewWithdraw(availableAssets, availableAssets * 2, totalShares);

            // Withdraw should round up (burns more shares)
            assertGe(sharesFromWithdraw, sharesFromDeposit, "Withdraw should burn at least as many shares");

            // But should be close
            // Note: deposit/withdraw are not perfect inverses due to:
            // 1. Different rounding directions (deposit rounds down, withdraw rounds up)
            // 2. The curve formula means the relationship is nonlinear
            if (sharesFromWithdraw > 0) {
                uint256 tolerance = sharesFromWithdraw / 10; // 10% tolerance
                assertApproxEqAbs(
                    sharesFromWithdraw, sharesFromDeposit, tolerance, "Deposit-withdraw should be reasonably close"
                );
            }
        }
    }

    /// @notice Test that all configurations have reasonable max values
    function test_invariant_reasonableMaxValues() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            CurveMetrics memory metric = metrics[i];

            // Max shares should be positive and less than uint256 max
            assertGt(metric.maxShares, 0, "Max shares should be positive");
            assertLt(metric.maxShares, type(uint256).max, "Max shares should be less than uint256 max");

            // Max assets should be positive and less than uint256 max
            assertGt(metric.maxAssets, 0, "Max assets should be positive");
            assertLt(metric.maxAssets, type(uint256).max, "Max assets should be less than uint256 max");

            // Should be able to mint up to max shares
            uint256 costToMax = curves[i].previewMint(metric.maxShares, 0, 0);
            assertGt(costToMax, 0, "Should have positive cost to mint max shares");
        }
    }

    /* =================================================== */
    /*              BOUNDARY & EDGE CASE TESTS             */
    /* =================================================== */

    /// @notice Test minimum valid slope configuration
    function test_edge_minimumSlope() public view {
        uint256 minSlopeIdx = 10; // Minimum Slope config

        _logConfiguration(minSlopeIdx);

        OffsetProgressiveCurve curve = curves[minSlopeIdx];

        // Should still function correctly
        uint256 price = curve.currentPrice(1e18, 0);
        assertGt(price, 0, "Minimum slope should still produce positive prices");

        uint256 cost = curve.previewMint(1e18, 0, 0);
        assertGt(cost, 0, "Minimum slope should still have positive minting costs");
    }

    /// @notice Test very large offset configuration
    function test_edge_veryLargeOffset() public view {
        uint256 largeOffsetIdx = 11; // Very Large Offset config

        _logConfiguration(largeOffsetIdx);

        OffsetProgressiveCurve curve = curves[largeOffsetIdx];

        // Curve should behave almost linearly
        uint256 price0 = curve.currentPrice(0, 0);
        uint256 price1e18 = curve.currentPrice(1e18, 0);
        uint256 price2e18 = curve.currentPrice(2e18, 0);

        // Price differences should be nearly identical
        uint256 diff1 = price1e18 - price0;
        uint256 diff2 = price2e18 - price1e18;

        // Allow 1% variance
        assertApproxEqAbs(diff1, diff2, diff1 / 100, "Large offset should make curve nearly linear");
    }

    /// @notice Test that zero offset allows for very cheap initial shares
    function test_edge_zeroOffset_cheapInitialShares() public view {
        uint256 zeroOffsetIdx = 4;

        OffsetProgressiveCurve curve = curves[zeroOffsetIdx];

        uint256 initialPrice = curve.currentPrice(0, 0);
        assertEq(initialPrice, 0, "Zero offset should have zero initial price");

        // First shares should be very cheap
        uint256 costFirstShare = curve.previewMint(1, 0, 0);
        assertLt(costFirstShare, 1e10, "First share should be very cheap with zero offset");
    }

    /// @notice Fuzz test: No configuration should overflow at max shares
    function testFuzz_edge_noOverflowAtMaxShares(uint256 configIndex) public view {
        configIndex = bound(configIndex, 0, configurations.length - 1);

        OffsetProgressiveCurve curve = curves[configIndex];
        uint256 maxShares = curve.maxShares();

        // Should not revert when operating at max shares
        uint256 price = curve.currentPrice(maxShares, 0);
        assertGt(price, 0, "Should have valid price at max shares");

        // Should be able to redeem from max shares
        uint256 returned = curve.previewRedeem(maxShares, maxShares, 0);
        assertGt(returned, 0, "Should be able to redeem from max shares");
    }

    /* =================================================== */
    /*          OPTIMAL CONFIGURATION ANALYSIS             */
    /* =================================================== */

    /// @notice Comprehensive analysis of all optimal "gentle early, steep later" configurations
    function test_optimal_analyzeAllGentleSteepConfigs() public view {
        console.log("##################################################################");
        console.log("# OPTIMAL CONFIGURATIONS: GENTLE EARLY (1-150e18), STEEP LATER  #");
        console.log("##################################################################");
        console.log("");

        // Indices 12-18 are the optimal configurations
        uint256 startIdx = 12;
        uint256 endIdx = 18;

        for (uint256 i = startIdx; i <= endIdx; i++) {
            _logConfiguration(i);
        }

        console.log("##################################################################");
        console.log("#                    COMPARATIVE ANALYSIS                        #");
        console.log("##################################################################");
        console.log("");

        // Analyze which configurations best meet the criteria
        console.log("CRITERIA: Gentle from 1-150e18 (low cost variance), steep after 150e18");
        console.log("");

        for (uint256 i = startIdx; i <= endIdx; i++) {
            CurveMetrics memory m = metrics[i];
            CurveConfig memory c = configurations[i];

            // Calculate gentleness in early range (1-100e18)
            // Compare average cost per 1e18 shares
            uint256 avgCost1 = m.costToMint1e18Shares;
            uint256 avgCost100 = m.costToMint100e18Shares * 1e18 / 100e18;
            uint256 earlyVariance = avgCost1 > 0 ? (avgCost100 * 100) / avgCost1 : 0;

            // Calculate steepness in late range (500-2500e18)
            uint256 lateGrowth = m.costToMint2500e18Shares > m.costToMint500e18Shares
                ? ((m.costToMint2500e18Shares - m.costToMint500e18Shares) * 100) / m.costToMint500e18Shares
                : 0;

            console.log("--- Config:", c.name, "---");
            console.log(
                "  Early cost/share growth (1-100e18): %",
                earlyVariance > 100 ? earlyVariance - 100 : 100 - earlyVariance
            );
            console.log("  Late cost increase (500-2500e18): %", lateGrowth);
            console.log("  Gentleness score (lower = better early):", earlyVariance);
            console.log("  Steepness score (higher = better late):", lateGrowth);
            console.log("");
        }
    }

    /// @notice Detailed comparison of top 3 optimal configurations
    function test_optimal_compareTop3Configurations() public view {
        // Based on theory, these should be the best:
        // - Slope=2, Offset=150e18 (minimal slope, offset at boundary)
        // - Slope=4, Offset=150e18 (low slope, offset at boundary)
        // - Slope=2, Offset=100e18 (minimal slope, offset below boundary)

        uint256 config1 = 15; // Slope=2, Offset=150e18
        uint256 config2 = 17; // Slope=4, Offset=150e18
        uint256 config3 = 12; // Slope=2, Offset=100e18

        console.log("##################################################################");
        console.log("#              TOP 3 OPTIMAL CONFIGURATION COMPARISON            #");
        console.log("##################################################################");
        console.log("");

        _logComparison(config1, config2);
        _logComparison(config1, config3);
        _logComparison(config2, config3);
    }

    /// @notice Test that optimal configs maintain gentleness in target range
    function test_optimal_validateGentlenessInTargetRange() public view {
        // Test each optimal config (indices 12-18)
        for (uint256 i = 12; i <= 18; i++) {
            OffsetProgressiveCurve curve = curves[i];
            CurveConfig memory config = configurations[i];

            // Calculate total costs in the gentle range (1-150e18)
            uint256 cost1 = curve.previewMint(1e18, 0, 0);
            uint256 cost150 = curve.previewMint(150e18, 0, 0);

            // Calculate average cost per share (keep in wei for precision)
            uint256 avgCost1 = cost1; // Cost for 1e18 shares
            uint256 avgCost150 = cost150 * 1e18 / 150e18; // Normalize to per-1e18-shares

            // In the gentle range, average cost per 1e18 shares should not increase dramatically
            // Allow up to 3x increase from 1e18 to 150e18 (this is still "gentle")
            assertLt(avgCost150, avgCost1 * 3, string.concat("Config should be gentle in target range: ", config.name));
        }
    }

    /// @notice Test that optimal configs show steepness after target range
    function test_optimal_validateSteepnessAfterTargetRange() public view {
        // Test each optimal config (indices 12-18)
        for (uint256 i = 12; i <= 18; i++) {
            OffsetProgressiveCurve curve = curves[i];
            CurveConfig memory config = configurations[i];

            // Calculate total costs
            uint256 cost150 = curve.previewMint(150e18, 0, 0);
            uint256 cost500 = curve.previewMint(500e18, 0, 0);

            // Calculate average cost per 1e18 shares (normalized)
            uint256 avgCost150 = cost150 * 1e18 / 150e18;
            uint256 avgCost500 = cost500 * 1e18 / 500e18;

            // After the target range, cost per share should increase significantly
            // Expect at least 20% increase in average cost per 1e18 shares
            assertGt(
                avgCost500,
                (avgCost150 * 120) / 100,
                string.concat("Config should steepen after target range: ", config.name)
            );
        }
    }

    /// @notice Find the single best configuration based on specific criteria
    function test_optimal_identifyBestConfiguration() public view {
        console.log("##################################################################");
        console.log("#              IDENTIFYING BEST CONFIGURATION                    #");
        console.log("##################################################################");
        console.log("");
        console.log("Criteria:");
        console.log("1. Minimal cost variance in 1-150e18 range (gentle)");
        console.log("2. Maximum steepness after 150e18");
        console.log("3. Reasonable total costs (not too expensive overall)");
        console.log("");

        uint256 bestIdx = 12;
        uint256 bestScore = 0;

        for (uint256 i = 12; i <= 18; i++) {
            CurveMetrics memory m = metrics[i];

            // Score = steepness bonus - gentleness penalty - cost penalty
            // Higher is better

            // Gentleness: variance in avg cost/share from 1e18 to 100e18 (lower is better)
            uint256 avgCost1 = m.costToMint1e18Shares / 1e18;
            uint256 avgCost100 = m.costToMint100e18Shares / 100e18;
            uint256 gentlenessVariance = avgCost100 > avgCost1
                ? ((avgCost100 - avgCost1) * 1e18) / avgCost1  // Percentage variance
                : 0;

            // Steepness: growth from 500e18 to 2500e18 (higher is better)
            uint256 steepness = m.costToMint2500e18Shares > m.costToMint500e18Shares
                ? ((m.costToMint2500e18Shares - m.costToMint500e18Shares) * 1e18) / m.costToMint500e18Shares
                : 0;

            // Cost penalty: total cost for 2500e18 shares (lower is better)
            // Normalize to a score (inverse)
            uint256 costScore = m.costToMint2500e18Shares > 0 ? (1e36 / m.costToMint2500e18Shares) : 0;

            // Combined score (weights: steepness=50%, gentleness=30%, cost=20%)
            uint256 score =
                (steepness * 50) / 100 + ((1e18 - gentlenessVariance) * 30) / 100 + (costScore * 20) / (1e18);

            if (score > bestScore) {
                bestScore = score;
                bestIdx = i;
            }

            console.log("Config:", configurations[i].name);
            console.log("  Gentleness variance:", gentlenessVariance);
            console.log("  Steepness:", steepness);
            console.log("  Cost score:", costScore);
            console.log("  TOTAL SCORE:", score);
            console.log("");
        }

        console.log("##################################################################");
        console.log("WINNER:", configurations[bestIdx].name);
        console.log("SLOPE:", configurations[bestIdx].slope);
        console.log("OFFSET:", configurations[bestIdx].offset);
        console.log("##################################################################");
        console.log("");

        _logConfiguration(bestIdx);
    }

    /* =================================================== */
    /*              DIAGNOSTIC & COMPARISON TESTS          */
    /* =================================================== */

    /// @notice Log all configurations for manual inspection
    function test_diagnostic_logAllConfigurations() public view {
        for (uint256 i = 0; i < configurations.length; i++) {
            _logConfiguration(i);
        }
    }

    /// @notice Compare extreme configurations
    function test_diagnostic_compareExtremes() public view {
        uint256 ultraLowIdx = 0; // Ultra-low slope
        uint256 highIdx = 3; // High slope

        _logComparison(ultraLowIdx, highIdx);

        // Document the magnitude of difference
        uint256 ultraLowCost = metrics[ultraLowIdx].costToMint1e18Shares;
        uint256 highCost = metrics[highIdx].costToMint1e18Shares;

        console.log("Cost multiplier (high/ultra-low):", highCost / (ultraLowCost > 0 ? ultraLowCost : 1));
    }

    /// @notice Analyze how offset affects curve linearity
    function test_diagnostic_offsetLinearityEffect() public view {
        console.log("=== OFFSET EFFECT ON LINEARITY ===");

        for (uint256 i = 4; i <= 7; i++) {
            // Zero to High offset configs
            OffsetProgressiveCurve curve = curves[i];
            CurveConfig memory config = configurations[i];

            // Measure price change from 0 to 1e18 and 1e18 to 2e18
            uint256 price0 = curve.currentPrice(0, 0);
            uint256 price1 = curve.currentPrice(1e18, 0);
            uint256 price2 = curve.currentPrice(2e18, 0);

            uint256 diff1 = price1 - price0;
            uint256 diff2 = price2 - price1;

            uint256 variance = diff1 > diff2 ? diff1 - diff2 : diff2 - diff1;
            uint256 variancePercent = (variance * 100) / diff1;

            console.log("Config:", config.name);
            console.log("  Offset:", config.offset);
            console.log("  Price change (0->1e18):", diff1);
            console.log("  Price change (1e18->2e18):", diff2);
            console.log("  Variance %:", variancePercent);
            console.log("");
        }
    }

    /* =================================================== */
    /*                  HELPER FUNCTIONS                   */
    /* =================================================== */

    /// @dev Helper to deploy a curve for testing with specific parameters
    function _deployCurveForTest(
        string memory name,
        uint256 slope,
        uint256 offset
    )
        internal
        returns (OffsetProgressiveCurve)
    {
        OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(this),
            abi.encodeWithSelector(OffsetProgressiveCurve.initialize.selector, name, slope, offset)
        );
        return OffsetProgressiveCurve(address(proxy));
    }
}
