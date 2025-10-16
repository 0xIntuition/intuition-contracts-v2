// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18 } from "@prb/math/src/UD60x18.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

contract OffsetProgressiveCurveTest is Test {
    OffsetProgressiveCurve public curve;
    uint256 public constant SLOPE = 2;
    uint256 public constant OFFSET = 5e35;

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

    function testFuzz_currentPrice(uint256 totalShares) public view {
        totalShares = bound(totalShares, 0, curve.maxShares());

        uint256 price = curve.currentPrice(totalShares, 0);
        // Looking at the contract: convert(totalShares).add(OFFSET).mul(SLOPE).unwrap()
        // This means: (totalShares * 1e18 + OFFSET) * SLOPE / 1e18
        // Since OFFSET is 0.0001e18 = 1e14, and SLOPE is 0.001e18 = 1e15
        // The formula becomes: (totalShares * 1e18 + 1e14) * 1e15 / 1e18
        // Which simplifies to: totalShares * 1e15 + 1e14 * 1e15 / 1e18
        // Which is: totalShares * SLOPE + OFFSET * SLOPE / 1e18
        uint256 expectedPrice = totalShares * SLOPE + (OFFSET * SLOPE / 1e18);
        assertEq(price, expectedPrice);
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
            assertLt(aWithShUpMinus1, a);
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

    function test_previewDeposit_allowsZeroAssets_returnsZero() public view {
        uint256 shares = curve.previewDeposit(0, /*totalAssets=*/ 0, /*totalShares=*/ 123e18);
        assertEq(shares, 0);
    }

    function test_convertToShares_allowsZeroAssets_returnsZero() public view {
        uint256 shares = curve.convertToShares(0, /*totalAssets=*/ 0, /*totalShares=*/ 123e18);
        assertEq(shares, 0);
    }

    // Withdraw bound: assets > totalAssets
    function test_previewWithdraw_reverts_whenAssetsExceedTotalAssets() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsExceedTotalAssets.selector));
        curve.previewWithdraw( /*assets=*/ 2, /*totalAssets=*/ 1, /*totalShares=*/ 10e18);
    }

    // Redeem bounds: shares > totalShares
    function test_previewRedeem_reverts_whenSharesExceedTotalShares() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesExceedTotalShares.selector));
        curve.previewRedeem( /*shares=*/ 11e18, /*totalShares=*/ 10e18, /*totalAssets=*/ 0);
    }

    function test_convertToAssets_reverts_whenSharesExceedTotalShares() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesExceedTotalShares.selector));
        curve.convertToAssets( /*shares=*/ 11e18, /*totalShares=*/ 10e18, /*totalAssets=*/ 0);
    }

    // Deposit bounds: assets + totalAssets > maxAssets
    function test_previewDeposit_reverts_whenAssetsOverflowMaxAssets() public {
        uint256 maxA = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsOverflowMax.selector));
        curve.previewDeposit( /*assets=*/ 1, /*totalAssets=*/ maxA, /*totalShares=*/ 0);
    }

    // Mint bounds: shares + totalShares > maxShares
    function test_previewMint_reverts_whenSharesOverflowMaxShares() public {
        uint256 maxS = curve.maxShares();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_SharesOverflowMax.selector));
        curve.previewMint( /*shares=*/ 1, /*totalShares=*/ maxS, /*totalAssets=*/ 0);
    }

    // Mint out: assetsOut + totalAssets > maxAssets
    function test_previewMint_reverts_whenAssetsOutWouldOverflowMaxAssets() public {
        uint256 maxA = curve.maxAssets();
        vm.expectRevert(abi.encodeWithSelector(IBaseCurve.BaseCurve_AssetsOverflowMax.selector));
        curve.previewMint( /*shares=*/ 1, /*totalShares=*/ 1, /*totalAssets=*/ maxA);
    }
}
