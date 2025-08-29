// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test } from "forge-std/src/Test.sol";
import { UD60x18, ud60x18 } from "@prb/math/src/UD60x18.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

contract BondingCurveRegistryTest is Test {
    BondingCurveRegistry public registry;
    LinearCurve public linearCurve;
    ProgressiveCurve public progressiveCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");

    uint256 constant SLOPE = 2;
    uint256 constant OFFSET = 5e35;

    event BondingCurveAdded(uint256 indexed curveId, address indexed curveAddress, string indexed curveName);

    function setUp() public {
        registry = new BondingCurveRegistry(admin);
        linearCurve = new LinearCurve("Linear Curve Test");
        progressiveCurve = new ProgressiveCurve("Progressive Curve Test", SLOPE);
        offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve Test", SLOPE, OFFSET);
    }

    function test_constructor_successful() public {
        BondingCurveRegistry newRegistry = new BondingCurveRegistry(admin);
        assertEq(newRegistry.owner(), admin);
        assertEq(newRegistry.count(), 0);
    }

    function test_addBondingCurve_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        assertEq(registry.count(), 1);
        assertEq(registry.curveAddresses(1), address(linearCurve));
        assertEq(registry.curveIds(address(linearCurve)), 1);
        assertTrue(registry.registeredCurveNames("Linear Curve Test"));
    }

    function test_addBondingCurve_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(BondingCurveRegistry.BondingCurveRegistry_ZeroAddress.selector));
        registry.addBondingCurve(address(0));
    }

    function test_addBondingCurve_revertsOnCurveAlreadyExists() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(BondingCurveRegistry.BondingCurveRegistry_CurveAlreadyExists.selector));
        registry.addBondingCurve(address(linearCurve));
    }

    function test_addBondingCurve_revertsOnNonUniqueNames() public {
        LinearCurve duplicateNameCurve = new LinearCurve("Linear Curve Test");

        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(BondingCurveRegistry.BondingCurveRegistry_CurveNameNotUnique.selector));
        registry.addBondingCurve(address(duplicateNameCurve));
    }

    function test_addBondingCurve_revertsOnNonAdmin() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        registry.addBondingCurve(address(linearCurve));
    }

    function test_addBondingCurve_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit BondingCurveAdded(1, address(linearCurve), "Linear Curve Test");
        registry.addBondingCurve(address(linearCurve));
    }

    function test_previewDeposit_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 shares = registry.previewDeposit(1e18, 10e18, 10e18, 1);
        assertEq(shares, 1e18);
    }

    function test_previewRedeem_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 assets = registry.previewRedeem(1e18, 10e18, 10e18, 1);
        assertEq(assets, 1e18);
    }

    function test_previewWithdraw_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 shares = registry.previewWithdraw(1e18, 10e18, 10e18, 1);
        assertEq(shares, 1e18);
    }

    function test_previewMint_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 assets = registry.previewMint(1e18, 10e18, 10e18, 1);
        assertEq(assets, 1e18);
    }

    function test_convertToShares_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 shares = registry.convertToShares(1e18, 10e18, 10e18, 1);
        assertEq(shares, 1e18);
    }

    function test_convertToAssets_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 assets = registry.convertToAssets(1e18, 10e18, 10e18, 1);
        assertEq(assets, 1e18);
    }

    function test_currentPrice_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 price = registry.currentPrice(10e18, 1);
        assertEq(price, 1e18);
    }

    function test_getCurveName_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        string memory name = registry.getCurveName(1);
        assertEq(name, "Linear Curve Test");
    }

    function test_getCurveMaxShares_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 maxShares = registry.getCurveMaxShares(1);
        assertEq(maxShares, type(uint256).max);
    }

    function test_getCurveMaxAssets_successful() public {
        vm.prank(admin);
        registry.addBondingCurve(address(linearCurve));

        uint256 maxAssets = registry.getCurveMaxAssets(1);
        assertEq(maxAssets, type(uint256).max);
    }

    function testFuzz_addMultipleCurves(uint256 slope1, uint256 slope2) public {
        slope1 = bound(slope1, 1, 1e18);
        slope2 = bound(slope2, 1, 1e18);

        ProgressiveCurve curve1 = new ProgressiveCurve("Curve 1", slope1);
        ProgressiveCurve curve2 = new ProgressiveCurve("Curve 2", slope2);

        vm.startPrank(admin);
        registry.addBondingCurve(address(curve1));
        registry.addBondingCurve(address(curve2));
        vm.stopPrank();

        assertEq(registry.count(), 2);
        assertEq(registry.curveAddresses(1), address(curve1));
        assertEq(registry.curveAddresses(2), address(curve2));
    }
}

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

contract ProgressiveCurveTest is Test {
    ProgressiveCurve public curve;
    uint256 constant SLOPE = 0.001e18;

    function setUp() public {
        curve = new ProgressiveCurve("Progressive Curve Test", SLOPE);
    }

    function test_constructor_successful() public {
        ProgressiveCurve newCurve = new ProgressiveCurve("Test Curve", SLOPE);
        assertEq(newCurve.name(), "Test Curve");
    }

    function test_constructor_revertsOnZeroSlope() public {
        vm.expectRevert("PC: Slope must be > 0");
        new ProgressiveCurve("Test Curve", 0);
    }

    function test_constructor_revertsOnEmptyName() public {
        vm.expectRevert(abi.encodeWithSelector(BaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        new ProgressiveCurve("", SLOPE);
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

        assertEq(price1, 0);
        assertGt(price2, price1);
        assertGt(price3, price2);
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
        // The contract multiplies totalShares * SLOPE directly
        // Since SLOPE is already in 18 decimal format (0.001e18 = 1e15)
        uint256 expectedPrice = totalShares * SLOPE;
        assertEq(price, expectedPrice);
    }
}

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
