// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18 } from "@prb/math/src/UD60x18.sol";
import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";

contract OffsetProgressiveCurveTest is Test {
    OffsetProgressiveCurve public curve;
    uint256 constant SLOPE = 0.001e18;
    uint256 constant OFFSET = 0.0001e18;

    function setUp() public {
        curve = new OffsetProgressiveCurve("Offset Progressive Curve Test", SLOPE, OFFSET);
    }

    function test_constructor_successful() public {
        OffsetProgressiveCurve newCurve = new OffsetProgressiveCurve("Test Curve", SLOPE, OFFSET);
        assertEq(newCurve.name(), "Test Curve");
    }

    function test_constructor_revertsOnZeroSlope() public {
        vm.expectRevert("PC: Slope must be > 0");
        new OffsetProgressiveCurve("Test Curve", 0, OFFSET);
    }

    function test_constructor_revertsOnEmptyName() public {
        vm.expectRevert(abi.encodeWithSelector(BaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        new OffsetProgressiveCurve("", SLOPE, OFFSET);
    }

    function test_previewDeposit_zeroShares() public view {
        uint256 shares = curve.previewDeposit(1e18, 0, 0);
        assertGt(shares, 0);
    }

    function test_previewDeposit_revertsOnZeroAssets() public {
        vm.expectRevert("Asset amount must be greater than zero");
        curve.previewDeposit(0, 0, 0);
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
        uint256 shares = curve.previewWithdraw(1e18, 0, 10e18);
        assertGt(shares, 0);
    }

    function test_currentPrice_increasesWithSupply() public view {
        uint256 price1 = curve.currentPrice(0);
        uint256 price2 = curve.currentPrice(10e18);
        uint256 price3 = curve.currentPrice(100e18);

        assertGt(price1, 0);
        assertGt(price2, price1);
        assertGt(price3, price2);
    }

    function test_currentPrice_offsetEffect() public view {
        uint256 priceAtZero = curve.currentPrice(0);
        assertEq(priceAtZero, OFFSET * SLOPE / 1e18);
    }

    function test_convertToShares_revertsOnZeroAssets() public {
        vm.expectRevert("Asset amount must be greater than zero");
        curve.convertToShares(0, 0, 0);
    }

    function test_convertToAssets_revertsOnUnderSupply() public {
        vm.expectRevert("PC: Under supply of shares");
        curve.convertToAssets(11e18, 10e18, 0);
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
            uint256 currentPrice = curve.currentPrice(totalShares);
            assets = (currentPrice * assetMultiplier) / 100; // Assets as percentage of current price
            assets = assets > 0 ? assets : 1;
        }

        uint256 shares = curve.previewDeposit(assets, 0, totalShares);
        assertGt(shares, 0);
    }

    function testFuzz_currentPrice(uint256 totalShares) public view {
        totalShares = bound(totalShares, 0, curve.maxShares());

        uint256 price = curve.currentPrice(totalShares);
        // Looking at the contract: convert(totalShares).add(OFFSET).mul(SLOPE).unwrap()
        // This means: (totalShares * 1e18 + OFFSET) * SLOPE / 1e18
        // Since OFFSET is 0.0001e18 = 1e14, and SLOPE is 0.001e18 = 1e15
        // The formula becomes: (totalShares * 1e18 + 1e14) * 1e15 / 1e18
        // Which simplifies to: totalShares * 1e15 + 1e14 * 1e15 / 1e18
        // Which is: totalShares * SLOPE + OFFSET * SLOPE / 1e18
        uint256 expectedPrice = totalShares * SLOPE + (OFFSET * SLOPE / 1e18);
        assertEq(price, expectedPrice);
    }
}
