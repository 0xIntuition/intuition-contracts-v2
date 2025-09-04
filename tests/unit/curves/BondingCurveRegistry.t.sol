// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

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
