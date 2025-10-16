// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18 } from "@prb/math/src/UD60x18.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

contract ProgressiveCurveTest is Test {
    ProgressiveCurve public curve;
    uint256 public constant SLOPE = 2;

    function setUp() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy = new TransparentUpgradeableProxy(
            address(progressiveCurveImpl),
            address(this),
            abi.encodeWithSelector(ProgressiveCurve.initialize.selector, "Progressive Curve Test", SLOPE)
        );
        curve = ProgressiveCurve(address(progressiveCurveProxy));
    }

    function test_initialize_successful() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        curve.initialize("Test Curve", SLOPE);
        assertEq(curve.name(), "Test Curve");
    }

    function test_constructor_revertsOnEmptyName() public {
        vm.expectRevert(abi.encodeWithSelector(BaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        new ProgressiveCurve("", SLOPE);
    }

    function test_constructor_revertsOnZeroSlope() public {
        vm.expectRevert(abi.encodeWithSelector(ProgressiveCurve.ProgressiveCurve_InvalidSlope.selector));
        new ProgressiveCurve("Test Curve", 0);
    }

    function test_constructor_revertsOnOddSlope() public {
        vm.expectRevert(abi.encodeWithSelector(ProgressiveCurve.ProgressiveCurve_InvalidSlope.selector));
        new ProgressiveCurve("Test Curve", 3); // odd
    }

    function test_initialize_revertsOnZeroSlope() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        vm.expectRevert("PC: Slope must be > 0");
        curve.initialize("Test Curve", 0);
    }

    function test_initialize_revertsOnEmptyName() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        curve.initialize("", SLOPE);
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

        assertEq(price1, 0);
        assertGt(price2, price1);
        assertGt(price3, price2);
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

    function testFuzz_currentPrice(uint256 totalShares) public view {
        totalShares = bound(totalShares, 0, curve.maxShares());

        uint256 price = curve.currentPrice(totalShares, 0);
        // The contract multiplies totalShares * SLOPE directly
        // Since SLOPE is already in 18 decimal format (0.001e18 = 1e15)
        uint256 expectedPrice = totalShares * SLOPE;
        assertEq(price, expectedPrice);
    }

    function test_previewMint_isCeil_of_previewRedeem_floor() public view {
        uint256 s0 = 10e18;
        uint256 n = 1e18;

        uint256 assetsUp = curve.previewMint(n, s0, 0);
        uint256 assetsFloor = curve.previewRedeem(n, s0 + n, 0);

        assertGe(assetsUp, assetsFloor);
        assertLe(assetsUp - assetsFloor, 1); // at most 1 wei diff
    }

    function test_previewWithdraw_isMinimal() public view {
        uint256 s0 = 10e18;
        uint256 a = 1e18;

        uint256 shUp = curve.previewWithdraw(a, 0, s0);
        uint256 aWithShUp = curve.previewRedeem(shUp, s0, 0);
        assertGe(aWithShUp, a);

        if (shUp > 0) {
            uint256 aWithShUpMinus1 = curve.previewRedeem(shUp - 1, s0, 0);
            assertLt(aWithShUpMinus1, a); // minimality of rounding up
        }
    }

    function test_previewDeposit_equals_convertToShares() public view {
        uint256 s0 = 10e18;
        uint256 a = 3e18;
        assertEq(curve.previewDeposit(a, 0, s0), curve.convertToShares(a, 0, s0));
    }

    function test_previewRedeem_equals_convertToAssets() public view {
        uint256 s0 = 10e18;
        uint256 r = 2e18;
        assertEq(curve.previewRedeem(r, s0, 0), curve.convertToAssets(r, s0, 0));
    }
}
