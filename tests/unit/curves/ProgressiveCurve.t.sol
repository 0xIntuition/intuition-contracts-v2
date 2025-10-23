// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

contract ProgressiveCurveTest is Test {
    ProgressiveCurve public curve;
    uint256 public constant SLOPE = 2e18;

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

    function test_initialize_revertsOnEmptyName() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        curve.initialize("", SLOPE);
    }

    function test_initialize_revertsOnZeroSlope() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(ProgressiveCurve.ProgressiveCurve_InvalidSlope.selector));
        curve.initialize("Test Curve", 0);
    }

    function test_initialize_revertsOnOddSlope() public {
        ProgressiveCurve progressiveCurveImpl = new ProgressiveCurve();
        TransparentUpgradeableProxy progressiveCurveProxy =
            new TransparentUpgradeableProxy(address(progressiveCurveImpl), address(this), "");
        curve = ProgressiveCurve(address(progressiveCurveProxy));

        vm.expectRevert(abi.encodeWithSelector(ProgressiveCurve.ProgressiveCurve_InvalidSlope.selector));
        curve.initialize("Test Curve", 3); // odd
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
        // wad-mul: (SLOPE * totalShares) / 1e18
        uint256 expectedPrice = (SLOPE * totalShares) / 1e18;
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

        uint256 shUp = curve.previewWithdraw(a, a, s0);
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
        vm.expectRevert(); // rely on PRB-math overflow revert
        curve.previewMint(sMax + 1, 0, 0);
    }

    function test_previewMint_boundaryFromNonZeroSupply_succeeds() public view {
        uint256 sMax = curve.maxShares();
        uint256 s0 = sMax - 1;
        uint256 n = 1; // s0 + n == sMax
        uint256 assets = curve.previewMint(n, s0, 0);
        assertGt(assets, 0);
    }

    function test_previewMint_crossesMaxFromNonZeroSupply_reverts() public {
        uint256 sMax = curve.maxShares();
        uint256 s0 = sMax - 1;
        uint256 n = 2; // s0 + n == sMax + 1 -> should overflow
        vm.expectRevert();
        curve.previewMint(n, s0, 0);
    }

    function test_previewRedeem_allAtMaxShares_succeeds() public view {
        uint256 sMax = curve.maxShares();
        uint256 expected = curve.maxAssets(); // redeem path returns floor; equals stored MAX_ASSETS
        uint256 assets = curve.previewRedeem(sMax, sMax, 0);
        assertEq(assets, expected);
    }

    /* ── Domain checks (equality allowed, above-max reverts) ── */

    function test_domainAllows_MAX_values_currentPrice_ProgressiveCurve() public view {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        // Should not revert
        uint256 p = curve.currentPrice(sMax, aMax);
        assertGe(p, 0);
    }

    function test_domainAllows_MAX_values_convertToAssets_ProgressiveCurve() public view {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        uint256 assets = curve.convertToAssets(1e18, sMax, aMax);
        assertGt(assets, 0);
    }

    function test_domainRejects_totalShares_aboveMax_currentPrice_ProgressiveCurve() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.currentPrice(sMax + 1, aMax);
    }

    function test_domainRejects_totalAssets_aboveMax_currentPrice_ProgressiveCurve() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.currentPrice(sMax, aMax + 1);
    }

    function test_domainRejects_aboveMax_in_previewDeposit_ProgressiveCurve() public {
        uint256 sMax = curve.maxShares();
        uint256 aMax = curve.maxAssets();

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.previewDeposit(0, aMax + 1, sMax);

        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_DomainExceeded.selector));
        curve.previewDeposit(0, aMax, sMax + 1);
    }
}
