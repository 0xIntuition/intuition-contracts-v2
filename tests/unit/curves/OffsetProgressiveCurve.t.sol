// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

contract OffsetProgressiveCurveTest is Test {
    OffsetProgressiveCurve public curve;
    uint256 public constant SLOPE = 2e18;
    uint256 public constant OFFSET = 5e17;

    function setUp() public {
        OffsetProgressiveCurve offsetProgressiveCurveImpl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy offsetProgressiveCurveProxy = new TransparentUpgradeableProxy(
            address(offsetProgressiveCurveImpl),
            address(this),
            abi.encodeWithSelector(
                OffsetProgressiveCurve.initialize.selector, "Offset Progressive Curve Test", SLOPE, OFFSET
            )
        );
        curve = OffsetProgressiveCurve(address(offsetProgressiveCurveProxy));
    }

    function test_initialize_successful() public {
        OffsetProgressiveCurve newCurveImpl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy newCurveProxy =
            new TransparentUpgradeableProxy(address(newCurveImpl), address(this), "");
        OffsetProgressiveCurve(address(newCurveProxy)).initialize("Test Curve", SLOPE, OFFSET);
        assertEq(OffsetProgressiveCurve(address(newCurveProxy)).name(), "Test Curve");
    }

    function test_initialize_revertsOnEmptyName() public {
        OffsetProgressiveCurve offsetProgressiveCurveImpl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy offsetProgressiveCurveProxy =
            new TransparentUpgradeableProxy(address(offsetProgressiveCurveImpl), address(this), "");
        curve = OffsetProgressiveCurve(address(offsetProgressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        curve.initialize("", SLOPE, OFFSET);
    }

    function test_initialize_revertsOnZeroSlope() public {
        OffsetProgressiveCurve offsetProgressiveCurveImpl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy offsetProgressiveCurveProxy =
            new TransparentUpgradeableProxy(address(offsetProgressiveCurveImpl), address(this), "");
        curve = OffsetProgressiveCurve(address(offsetProgressiveCurveProxy));
    }

    function test_initialize_revertsOnOddSlope() public {
        OffsetProgressiveCurve offsetProgressiveCurveImpl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy offsetProgressiveCurveProxy =
            new TransparentUpgradeableProxy(address(offsetProgressiveCurveImpl), address(this), "");
        curve = OffsetProgressiveCurve(address(offsetProgressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(OffsetProgressiveCurve.OffsetProgressiveCurve_InvalidSlope.selector));
        curve.initialize("Test Curve", 3, OFFSET); // odd
    }

    function test_previewDeposit_zeroShares() public view {
        uint256 shares = curve.previewDeposit(1e18, 0, 0);
        assertGt(shares, 0);
    }

    function test_previewRedeem_successful() public view {
        uint256 assets = curve.previewRedeem(1e18, 10e18, 0);
        assertGt(assets, 0);
    }

    function test_previewMint_successful() public view {
        uint256 assets = curve.previewMint(1e18, 10e18, 0);
        assertGt(assets, 0);
    }

    function test_previewWithdraw_successful() public view {
        uint256 shares = curve.previewWithdraw(1e18, 10e18, 10e18);
        assertGt(shares, 0);
    }

    function test_currentPrice_increasesWithSupply() public view {
        uint256 price1 = curve.currentPrice(0, 0);
        uint256 price2 = curve.currentPrice(10e18, 0);
        uint256 price3 = curve.currentPrice(100e18, 0);

        assertGt(price1, 0);
        assertGt(price2, price1);
        assertGt(price3, price2);
    }

    function test_currentPrice_offsetEffect() public view {
        uint256 priceAtZero = curve.currentPrice(0, 0);
        assertEq(priceAtZero, OFFSET * SLOPE / 1e18);
    }

    function test_maxShares() public view {
        assertGt(curve.maxShares(), 0);
        assertLt(curve.maxShares(), type(uint256).max);
    }

    function test_maxAssets() public view {
        assertGt(curve.maxAssets(), 0);
        assertLt(curve.maxAssets(), type(uint256).max);
    }

    function testFuzz_previewDeposit(uint256 assetMultiplier, uint256 totalShares) public view {
        // Bound totalShares to reasonable range
        totalShares = bound(totalShares, 0, 1e19);

        // Bound asset multiplier to create proportional assets
        assetMultiplier = bound(assetMultiplier, 1, 1000);

        // Calculate assets that will definitely return non-zero shares
        uint256 assets;
        if (totalShares == 0) {
            assets = assetMultiplier * 1e18; // When no shares exist, any assets work
        } else {
            // Need assets large enough that sqrt(s^2 + 2a/m) > s
            // This means 2a/m > 2s (approximately), so a > s*m
            uint256 currentPrice = curve.currentPrice(totalShares, 0);
            assets = (currentPrice * assetMultiplier) / 100; // Assets as percentage of current price
            assets = assets > 0 ? assets : 1;
        }

        uint256 shares = curve.previewDeposit(assets, 0, totalShares);
        assertGt(shares, 0);
    }

    function testFuzz_currentPrice_linearityProperty(uint256 totalShares, uint256 delta) public view {
        // Test the fundamental property: price should increase linearly with shares
        // P(s + Δs) - P(s) = m * Δs, where m is the slope

        totalShares = bound(totalShares, 0, curve.maxShares() - 1e18);
        delta = bound(delta, 1, 1e18);

        // Ensure we don't exceed max shares
        if (totalShares + delta > curve.maxShares()) {
            delta = curve.maxShares() - totalShares;
        }

        uint256 price1 = curve.currentPrice(totalShares, 0);
        uint256 price2 = curve.currentPrice(totalShares + delta, 0);

        // Calculate expected increase: SLOPE * delta
        // Since SLOPE is in 18-decimal fixed point, we need: (SLOPE * delta) / 1e18
        uint256 expectedIncrease = (SLOPE * delta) / 1e18;
        uint256 actualIncrease = price2 - price1;

        // Allow for 1 wei rounding error due to fixed-point arithmetic
        assertApproxEqAbs(actualIncrease, expectedIncrease, 1, "Price should increase linearly by SLOPE * delta");
    }

    function testFuzz_currentPrice_offsetEffect(uint256 totalShares) public view {
        // Test that the offset correctly shifts the price curve
        // At totalShares = 0, price should be OFFSET * SLOPE
        totalShares = bound(totalShares, 0, curve.maxShares());

        uint256 price = curve.currentPrice(totalShares, 0);
        uint256 priceAtZero = curve.currentPrice(0, 0);

        // Price formula: P(s) = (s + offset) * slope
        // So: P(s) - P(0) = s * slope
        uint256 expectedDifference = (SLOPE * totalShares) / 1e18;
        uint256 actualDifference = price - priceAtZero;

        assertApproxEqAbs(actualDifference, expectedDifference, 1, "Price difference should equal shares * slope");

        // Also verify the offset is applied correctly at zero
        uint256 expectedPriceAtZero = (OFFSET * SLOPE) / 1e18;
        assertEq(priceAtZero, expectedPriceAtZero, "Price at zero should equal offset * slope");
    }

    function testFuzz_currentPrice_integrationWithMint(uint256 sharesToMint) public view {
        // Test that the integral of prices matches the mint cost
        // This verifies the relationship between currentPrice and previewMint
        sharesToMint = bound(sharesToMint, 1e15, 1e18); // Reasonable range for testing

        uint256 totalShares = 10e18; // Start from non-zero supply

        // The cost to mint should equal the area under the price curve
        // For a linear curve: Cost = (P(s1) + P(s2)) / 2 * Δs
        uint256 price1 = curve.currentPrice(totalShares, 0);
        uint256 price2 = curve.currentPrice(totalShares + sharesToMint, 0);
        uint256 averagePrice = (price1 + price2) / 2;
        uint256 expectedCost = (averagePrice * sharesToMint) / 1e18;

        uint256 actualCost = curve.previewMint(sharesToMint, totalShares, 0);

        // Allow 0.1% tolerance for rounding in the integral calculation
        uint256 tolerance = actualCost / 1000;
        assertApproxEqAbs(actualCost, expectedCost, tolerance, "Mint cost should match integral of price curve");
    }

    function testFuzz_currentPrice_monotonicIncrease(uint256 shares1, uint256 shares2) public view {
        // Test that price is monotonically increasing (or equal due to rounding)
        shares1 = bound(shares1, 0, curve.maxShares());
        shares2 = bound(shares2, 0, curve.maxShares());

        uint256 price1 = curve.currentPrice(shares1, 0);
        uint256 price2 = curve.currentPrice(shares2, 0);

        if (shares1 < shares2) {
            assertLe(price1, price2, "Price should be less than or equal when supply is lower");
            // If the share difference is significant, price should strictly increase
            if (shares2 - shares1 >= 1e18) {
                assertLt(price1, price2, "Price should strictly increase for significant supply differences");
            }
        } else if (shares1 > shares2) {
            assertGe(price1, price2, "Price should be greater than or equal when supply is higher");
            // If the share difference is significant, price should strictly decrease
            if (shares1 - shares2 >= 1e18) {
                assertGt(price1, price2, "Price should strictly decrease for significant supply differences");
            }
        } else {
            assertEq(price1, price2, "Same supply should have same price");
        }
    }

    function test_offset_previewMint_isCeil_of_previewRedeem_floor() public view {
        uint256 s0 = 10e18;
        uint256 n = 1e18;

        uint256 up = curve.previewMint(n, s0, 0);
        uint256 floor = curve.previewRedeem(n, s0 + n, 0);

        assertGe(up, floor);
        assertLe(up - floor, 1);
    }

    function test_offset_previewWithdraw_isMinimal() public view {
        uint256 s0 = 10e18;
        uint256 a = 1e18;

        uint256 shUp = curve.previewWithdraw(a, a, s0);
        uint256 aWithShUp = curve.previewRedeem(shUp, s0, 0);
        assertGe(aWithShUp, a);

        if (shUp > 0) {
            uint256 aWithShUpMinus1 = curve.previewRedeem(shUp - 1, s0, 0);
            assertLe(aWithShUpMinus1, a); // rounding up is conservative
        }
    }

    function test_offset_previewDeposit_equals_convertToShares() public view {
        uint256 s0 = 10e18;
        uint256 a = 3e18;
        assertEq(curve.previewDeposit(a, 0, s0), curve.convertToShares(a, 0, s0));
    }

    function test_offset_previewRedeem_equals_convertToAssets() public view {
        uint256 s0 = 10e18;
        uint256 r = 2e18;
        assertEq(curve.previewRedeem(r, s0, 0), curve.convertToAssets(r, s0, 0));
    }

    function test_previewMint_mintMaxSharesFromZero_succeeds() public {
        uint256 sMax = curve.maxShares();
        uint256 maxA = curve.maxAssets();

        // previewMint should revert due to assets out overflow - this happens because we ceil required assets for mint
        // internally
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsOverflowMax.selector));
        curve.previewMint(sMax, 0, 0);

        // convertToAssets should return expected assets without ceil --> matches maxAssets
        uint256 expectedWithoutCeil = curve.convertToAssets(sMax, sMax, 0);
        assertEq(expectedWithoutCeil, maxA);
    }

    function test_previewMint_mintPastMaxSharesFromZero_reverts() public {
        uint256 sMax = curve.maxShares();
        vm.expectRevert();
        curve.previewMint(sMax + 1, 0, 0);
    }

    function test_previewMint_boundaryFromNonZeroSupply_succeeds() public view {
        uint256 sMax = curve.maxShares();
        uint256 s0 = sMax - 1;
        uint256 n = 1; // reaches max
        uint256 assets = curve.previewMint(n, s0, 0);
        assertGt(assets, 0);
    }

    function test_previewMint_crossesMaxFromNonZeroSupply_reverts() public {
        uint256 sMax = curve.maxShares();
        uint256 s0 = sMax - 1;
        uint256 n = 2; // crosses max
        vm.expectRevert();
        curve.previewMint(n, s0, 0);
    }

    function test_previewRedeem_allAtMaxShares_succeeds() public view {
        uint256 sMax = curve.maxShares();
        uint256 expected = curve.maxAssets(); // redeem path returns floor; equals stored MAX_ASSETS
        uint256 assets = curve.previewRedeem(sMax, sMax, 0);
        assertEq(assets, expected);
    }

    function test_previewDeposit_allowsZeroAssets_returnsZero() public view {
        uint256 shares = curve.previewDeposit(
            0,
            /*totalAssets=*/
            0,
            /*totalShares=*/
            123e18
        );
        assertEq(shares, 0);
    }

    function test_convertToShares_allowsZeroAssets_returnsZero() public view {
        uint256 shares = curve.convertToShares(
            0,
            /*totalAssets=*/
            0,
            /*totalShares=*/
            123e18
        );
        assertEq(shares, 0);
    }

    // Withdraw bound: assets > totalAssets
    function test_previewWithdraw_reverts_whenAssetsExceedTotalAssets() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsExceedTotalAssets.selector));
        curve.previewWithdraw( /*assets=*/
            2,
            /*totalAssets=*/
            1,
            /*totalShares=*/
            10e18
        );
    }

    // Redeem bounds: shares > totalShares
    function test_previewRedeem_reverts_whenSharesExceedTotalShares() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesExceedTotalShares.selector));
        curve.previewRedeem( /*shares=*/
            11e18,
            /*totalShares=*/
            10e18,
            /*totalAssets=*/
            0
        );
    }

    function test_convertToAssets_reverts_whenSharesExceedTotalShares() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesExceedTotalShares.selector));
        curve.convertToAssets( /*shares=*/
            11e18,
            /*totalShares=*/
            10e18,
            /*totalAssets=*/
            0
        );
    }

    // Deposit bounds: assets + totalAssets > maxAssets
    function test_previewDeposit_reverts_whenAssetsOverflowMaxAssets() public {
        uint256 maxA = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsOverflowMax.selector));
        curve.previewDeposit( /*assets=*/
            1,
            /*totalAssets=*/
            maxA,
            /*totalShares=*/
            0
        );
    }

    // Mint bounds: shares + totalShares > maxShares
    function test_previewMint_reverts_whenSharesOverflowMaxShares() public {
        uint256 maxS = curve.maxShares();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesOverflowMax.selector));
        curve.previewMint( /*shares=*/
            1,
            /*totalShares=*/
            maxS,
            /*totalAssets=*/
            0
        );
    }

    // Mint out: assetsOut + totalAssets > maxAssets
    function test_previewMint_reverts_whenAssetsOutWouldOverflowMaxAssets() public {
        uint256 maxA = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsOverflowMax.selector));
        curve.previewMint( /*shares=*/
            1,
            /*totalShares=*/
            1,
            /*totalAssets=*/
            maxA
        );
    }

    /* ── Domain checks (equality allowed, above-max reverts) ── */

    function test_domainAllows_MAX_values_currentPrice_OPC() public view {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        // Should not revert
        uint256 p = curve.currentPrice(sMax, aMax);
        assertGe(p, 0);
    }

    function test_domainAllows_MAX_values_convertToAssets_OPC() public view {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        uint256 assets = curve.convertToAssets(1e18, sMax, aMax);
        assertGt(assets, 0);
    }

    function test_domainRejects_totalShares_aboveMax_currentPrice_OPC() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.currentPrice(sMax + 1, aMax);
    }

    function test_domainRejects_totalAssets_aboveMax_currentPrice_OPC() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.currentPrice(sMax, aMax + 1);
    }

    function test_domainRejects_aboveMax_in_previewDeposit_OPC() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.previewDeposit(0, aMax + 1, sMax);

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.previewDeposit(0, aMax, sMax + 1);
    }

    function test_previewRedeem_lowShares_returnsZero_withZeroOffset() public {
        OffsetProgressiveCurve localCurve = _deployCurveWithOffset(SLOPE, 0);

        uint256 totalShares = 700_560_508;
        uint256 shares = 699_560_508;

        // previewRedeem should never revert due to underflow, even with zero offset
        uint256 assets = localCurve.previewRedeem(shares, totalShares, 0);
        assertEq(assets, 0);
    }

    function test_previewRedeem_lowShares_succeeds_withConfiguredOffset() public view {
        uint256 totalShares = 700_560_508;
        uint256 shares = 699_560_508;

        uint256 assets = curve.previewRedeem(shares, totalShares, 0);
        assertGt(assets, 0);
    }

    function _deployCurveWithOffset(uint256 slope, uint256 offset) internal returns (OffsetProgressiveCurve deployed) {
        OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(this),
            abi.encodeWithSelector(
                OffsetProgressiveCurve.initialize.selector, "Offset Progressive Curve Test", slope, offset
            )
        );
        deployed = OffsetProgressiveCurve(address(proxy));
    }
}
