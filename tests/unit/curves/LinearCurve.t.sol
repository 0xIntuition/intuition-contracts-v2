// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

contract LinearCurveTest is Test {
    LinearCurve public curve;

    function setUp() public {
        curve = new LinearCurve("Linear Curve Test");
    }

    function test_constructor_successful() public {
        LinearCurve newCurve = new LinearCurve("Test Curve");
        assertEq(newCurve.name(), "Test Curve");
    }

    function test_constructor_revertsOnEmptyName() public {
        vm.expectRevert(abi.encodeWithSelector(BaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        new LinearCurve("");
    }

    function test_previewDeposit_zeroSupply() public view {
        uint256 shares = curve.previewDeposit(1e18, 0, 0);
        assertEq(shares, 1e18);
    }

    function test_previewDeposit_withExistingSupply() public view {
        uint256 shares = curve.previewDeposit(1e18, 10e18, 10e18);
        assertEq(shares, 1e18);
    }

    function test_previewMint_successful() public view {
        uint256 assets = curve.previewMint(1e18, 10e18, 10e18);
        assertEq(assets, 1e18);
    }

    function test_previewWithdraw_successful() public view {
        uint256 shares = curve.previewWithdraw(1e18, 10e18, 10e18);
        assertEq(shares, 1e18);
    }

    function test_previewRedeem_successful() public view {
        uint256 assets = curve.previewRedeem(1e18, 10e18, 10e18);
        assertEq(assets, 1e18);
    }

    function test_convertToShares_zeroSupply() public view {
        uint256 shares = curve.convertToShares(1e18, 0, 0);
        assertEq(shares, 1e18);
    }

    function test_convertToShares_withExistingSupply() public view {
        uint256 shares = curve.convertToShares(2e18, 10e18, 10e18);
        assertEq(shares, 2e18);
    }

    function test_convertToAssets_zeroSupply() public view {
        uint256 assets = curve.convertToAssets(1e18, 0, 0);
        assertEq(assets, 1e18);
    }

    function test_convertToAssets_withExistingSupply() public view {
        uint256 assets = curve.convertToAssets(2e18, 10e18, 10e18);
        assertEq(assets, 2e18);
    }

    function test_currentPrice_alwaysReturnsOne() public view {
        assertEq(curve.currentPrice(0), 1e18);
        assertEq(curve.currentPrice(100e18), 1e18);
        assertEq(curve.currentPrice(type(uint128).max), 1e18);
    }

    function test_currentPriceWithAssets_zeroSupply() public view {
        uint256 price = curve.currentPrice(0, 0);
        assertEq(price, 1e18);
    }

    function test_currentPriceWithAssets_withExistingSupply() public view {
        uint256 price = curve.currentPrice(10e18, 20e18);
        assertEq(price, 2e18);
    }

    function test_maxShares() public view {
        assertEq(curve.maxShares(), type(uint256).max);
    }

    function test_maxAssets() public view {
        assertEq(curve.maxAssets(), type(uint256).max);
    }

    function testFuzz_convertToShares(uint256 assets, uint256 totalAssets, uint256 totalShares) public view {
        vm.assume(totalAssets > 0 && totalShares > 0);
        assets = bound(assets, 1, type(uint128).max);
        totalAssets = bound(totalAssets, 1, type(uint128).max);
        totalShares = bound(totalShares, 1, type(uint128).max);

        uint256 shares = curve.convertToShares(assets, totalAssets, totalShares);
        assertEq(shares, assets * totalShares / totalAssets);
    }

    function testFuzz_convertToAssets(uint256 shares, uint256 totalShares, uint256 totalAssets) public view {
        vm.assume(totalShares > 0 && totalAssets > 0);
        shares = bound(shares, 1, type(uint128).max);
        totalShares = bound(totalShares, shares, type(uint128).max);
        totalAssets = bound(totalAssets, 1, type(uint128).max);

        uint256 assets = curve.convertToAssets(shares, totalShares, totalAssets);
        assertEq(assets, shares * totalAssets / totalShares);
    }
}
