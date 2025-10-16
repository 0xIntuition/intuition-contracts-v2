// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18, convert } from "@prb/math/src/UD60x18.sol";
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

    function test_previewMint_mintMaxSharesFromZero_succeeds() public view {
        uint256 sMax = curve.maxShares();
        uint256 assets = curve.previewMint(sMax, 0, 0);
        assertGt(assets, 0);

        // Optional: exact equality against the closed-form cost
        uint256 expected = _expectedMintCostFromZero(sMax);
        assertEq(assets, expected);
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

        // Mint cost from 0 -> sMax == redeem proceeds from sMax -> 0 (ignoring fees; pure curve math)
        uint256 expected = _expectedMintCostFromZero(sMax);
        uint256 assets = curve.previewRedeem(sMax, sMax, 0);
        assertEq(assets, expected);
    }

    /// @dev Helper to compute expected mint cost from zero supply
    function _expectedMintCostFromZero(uint256 shares) internal view returns (uint256) {
        // Cost = (s^2) * (m/2)
        UD60x18 s = convert(shares);
        return convert(s.powu(2).mul(curve.HALF_SLOPE()));
    }
}
