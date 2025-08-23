// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

contract MultiVaultMigrationModeTest is BaseTest {
    /* =================================================== */
    /*                    TEST CONTRACTS                   */
    /* =================================================== */

    MultiVaultMigrationMode public multiVaultMigrationMode;
    BondingCurveRegistry public testBondingCurveRegistry;
    LinearCurve public linearCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;

    /* =================================================== */
    /*                      CONSTANTS                      */
    /* =================================================== */

    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
    address public constant BONDING_CURVE_REGISTRY = 0x1234567890123456789012345678901234567890;

    /* =================================================== */
    /*                        SETUP                        */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        // Deploy test bonding curve registry and curves
        testBondingCurveRegistry = new BondingCurveRegistry(users.admin);
        linearCurve = new LinearCurve("Test Linear Curve");
        offsetProgressiveCurve = new OffsetProgressiveCurve("Test Offset Progressive Curve", 1e15, 1e15);

        // Add curves to registry
        vm.startPrank(users.admin);
        testBondingCurveRegistry.addBondingCurve(address(linearCurve));
        testBondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        vm.stopPrank();

        // Deploy MultiVaultMigrationMode
        multiVaultMigrationMode = new MultiVaultMigrationMode();

        // Use vm.etch to override the BONDING_CURVE_REGISTRY constant
        vm.etch(BONDING_CURVE_REGISTRY, address(testBondingCurveRegistry).code);

        // Initialize the migration mode contract
        vm.prank(users.admin);
        multiVaultMigrationMode.initialize(
            _getDefaultGeneralConfig(),
            _getDefaultAtomConfig(),
            _getDefaultTripleConfig(),
            _getDefaultWalletConfig(),
            _getDefaultVaultFees(),
            _getTestBondingCurveConfig()
        );

        // Grant MIGRATOR_ROLE to admin for testing
        vm.prank(users.admin);
        multiVaultMigrationMode.grantRole(MIGRATOR_ROLE, users.admin);

        // Label for debugging
        vm.label(address(multiVaultMigrationMode), "MultiVaultMigrationMode");
        vm.label(address(testBondingCurveRegistry), "TestBondingCurveRegistry");
        vm.label(address(linearCurve), "LinearCurve");
        vm.label(address(offsetProgressiveCurve), "OffsetProgressiveCurve");
    }

    function _getTestBondingCurveConfig() internal view returns (BondingCurveConfig memory) {
        return BondingCurveConfig({ registry: address(testBondingCurveRegistry), defaultCurveId: 1 });
    }

    /* =================================================== */
    /*                    ACCESS CONTROL                   */
    /* =================================================== */

    function test_setTermCount_onlyMigratorRole() external {
        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.setTermCount(100);
    }

    function test_batchSetVaultTotals_onlyMigratorRole() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = keccak256("test");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);

        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetUserBalances_onlyMigratorRole() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = keccak256("test");
        userBalances[0] = 1e18;

        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, users.alice, userBalances);
    }

    function test_batchSetAtomData_onlyMigratorRole() external {
        address[] memory creators = new address[](1);
        bytes[] memory atomDataArray = new bytes[](1);

        creators[0] = users.alice;
        atomDataArray[0] = abi.encodePacked("test atom");

        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);
    }

    function test_batchSetTripleData_onlyMigratorRole() external {
        address[] memory creators = new address[](1);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        creators[0] = users.alice;
        tripleAtomIds[0] = [bytes32("atom1"), bytes32("atom2"), bytes32("atom3")];

        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.batchSetTripleData(creators, tripleAtomIds);
    }

    /* =================================================== */
    /*                   SET TERM COUNT                    */
    /* =================================================== */

    function test_setTermCount_successful() external {
        uint256 termCount = 150;

        vm.expectEmit(true, true, true, true);
        emit TermCountSet(termCount);

        vm.prank(users.admin);
        multiVaultMigrationMode.setTermCount(termCount);

        assertEq(multiVaultMigrationMode.totalTermsCreated(), termCount);
    }

    function test_setTermCount_revertsOnZeroValue() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroValue.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.setTermCount(0);
    }

    function testFuzz_setTermCount(uint256 termCount) external {
        termCount = bound(termCount, 1, type(uint128).max);

        vm.prank(users.admin);
        multiVaultMigrationMode.setTermCount(termCount);

        assertEq(multiVaultMigrationMode.totalTermsCreated(), termCount);
    }

    /* =================================================== */
    /*                BATCH SET VAULT TOTALS               */
    /* =================================================== */

    function test_batchSetVaultTotals_successful() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);

        termIds[0] = keccak256("atom1");
        termIds[1] = keccak256("atom2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);

        vm.expectEmit(true, true, true, true);
        emit SharePriceChanged(
            termIds[0],
            1,
            multiVaultMigrationMode.currentSharePrice(1, vaultTotals[0].totalShares, vaultTotals[0].totalAssets),
            vaultTotals[0].totalAssets,
            vaultTotals[0].totalShares,
            multiVaultMigrationMode.getVaultType(termIds[0])
        );

        vm.expectEmit(true, true, true, true);
        emit SharePriceChanged(
            termIds[1],
            1,
            multiVaultMigrationMode.currentSharePrice(1, vaultTotals[1].totalShares, vaultTotals[1].totalAssets),
            vaultTotals[1].totalAssets,
            vaultTotals[1].totalShares,
            multiVaultMigrationMode.getVaultType(termIds[1])
        );

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        (uint256 totalAssets0, uint256 totalShares0) = multiVaultMigrationMode.getVault(termIds[0], 1);
        (uint256 totalAssets1, uint256 totalShares1) = multiVaultMigrationMode.getVault(termIds[1], 1);

        // Verify vault states
        assertEq(totalAssets0, vaultTotals[0].totalAssets);
        assertEq(totalShares0, vaultTotals[0].totalShares);
        assertEq(totalAssets1, vaultTotals[1].totalAssets);
        assertEq(totalShares1, vaultTotals[1].totalShares);
    }

    function test_batchSetVaultTotals_revertsOnInvalidBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](1);

        termIds[0] = keccak256("test");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);
        vaultTypes[0] = IMultiVault.VaultType.ATOM;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 0, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnEmptyArray() external {
        bytes32[] memory termIds = new bytes32[](0);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](0);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnArraysNotSameLength() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](1);

        termIds[0] = keccak256("test1");
        termIds[1] = keccak256("test2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);
        vaultTypes[0] = IMultiVault.VaultType.ATOM;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function testFuzz_batchSetVaultTotals(
        uint256 totalAssets1,
        uint256 totalShares1,
        uint256 totalAssets2,
        uint256 totalShares2
    )
        external
    {
        totalAssets1 = bound(totalAssets1, 1e6, type(uint128).max);
        totalShares1 = bound(totalShares1, 1e6, type(uint128).max);
        totalAssets2 = bound(totalAssets2, 1e6, type(uint128).max);
        totalShares2 = bound(totalShares2, 1e6, type(uint128).max);

        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](2);

        termIds[0] = keccak256(abi.encodePacked("atom1", totalAssets1));
        termIds[1] = keccak256(abi.encodePacked("atom2", totalAssets2));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(totalAssets1, totalShares1);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(totalAssets2, totalShares2);
        vaultTypes[0] = IMultiVault.VaultType.ATOM;
        vaultTypes[1] = IMultiVault.VaultType.TRIPLE;

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        // Verify vault states
        (uint256 totalAssets0, uint256 totalShares0) = multiVaultMigrationMode.getVault(termIds[0], 1);
        (uint256 totalAssets1, uint256 totalShares1) = multiVaultMigrationMode.getVault(termIds[1], 1);

        assertEq(totalAssets0, vaultTotals[0].totalAssets);
        assertEq(totalShares0, vaultTotals[0].totalShares);
        assertEq(totalAssets1, vaultTotals[1].totalAssets);
        assertEq(totalShares1, vaultTotals[1].totalShares);
    }

    /* =================================================== */
    /*               BATCH SET USER BALANCES               */
    /* =================================================== */

    function test_batchSetUserBalances_successful() external {
        // First set up vault totals
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](2);

        termIds[0] = keccak256("atom1");
        termIds[1] = keccak256("atom2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);
        vaultTypes[0] = IMultiVault.VaultType.ATOM;
        vaultTypes[1] = IMultiVault.VaultType.ATOM;

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        // Now set user balances
        uint256[] memory userBalances = new uint256[](2);
        userBalances[0] = 1e18;
        userBalances[1] = 15e17; // 1.5e18

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            users.alice,
            users.alice,
            termIds[0],
            1,
            multiVaultMigrationMode.convertToAssets(1, 2e18, 2e18, userBalances[0]),
            0, // assetsAfterFees
            userBalances[0],
            vaultTypes[0]
        );

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            users.alice,
            users.alice,
            termIds[1],
            1,
            multiVaultMigrationMode.convertToAssets(1, 3e18, 3e18, userBalances[1]),
            0, // assetsAfterFees
            userBalances[1],
            vaultTypes[1]
        );

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, users.alice, userBalances);

        // Verify user balances
        assertEq(multiVaultMigrationMode.getShares(users.alice, termIds[0], 1), userBalances[0]);
        assertEq(multiVaultMigrationMode.getShares(users.alice, termIds[1], 1), userBalances[1]);
    }

    function test_batchSetUserBalances_revertsOnInvalidBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](1);

        termIds[0] = keccak256("test");
        userBalances[0] = 1e18;
        vaultTypes[0] = IMultiVault.VaultType.ATOM;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 0, users.alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnZeroAddress() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](1);

        termIds[0] = keccak256("test");
        userBalances[0] = 1e18;
        vaultTypes[0] = IMultiVault.VaultType.ATOM;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, address(0), userBalances);
    }

    function test_batchSetUserBalances_revertsOnEmptyArray() external {
        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory userBalances = new uint256[](0);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, users.alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnArraysNotSameLength() external {
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory userBalances = new uint256[](1);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](1);

        termIds[0] = keccak256("test1");
        termIds[1] = keccak256("test2");
        userBalances[0] = 1e18;
        vaultTypes[0] = IMultiVault.VaultType.ATOM;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, users.alice, userBalances);
    }

    /* =================================================== */
    /*                BATCH SET ATOM DATA                  */
    /* =================================================== */

    function test_batchSetAtomData_successful() external {
        address[] memory creators = new address[](2);
        bytes[] memory atomDataArray = new bytes[](2);

        creators[0] = users.alice;
        creators[1] = users.bob;
        atomDataArray[0] = abi.encodePacked("atom1 data");
        atomDataArray[1] = abi.encodePacked("atom2 data");

        bytes32 atomId1 = multiVaultMigrationMode.calculateAtomId(atomDataArray[0]);
        bytes32 atomId2 = multiVaultMigrationMode.calculateAtomId(atomDataArray[1]);

        vm.expectEmit(true, true, true, true);
        emit AtomCreated(creators[0], atomId1, atomDataArray[0], address(0));

        vm.expectEmit(true, true, true, true);
        emit AtomCreated(creators[1], atomId2, atomDataArray[1], address(0));

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);

        // Verify atom data was set
        assertEq(multiVaultMigrationMode.getAtom(atomId1), atomDataArray[0]);
        assertEq(multiVaultMigrationMode.getAtom(atomId2), atomDataArray[1]);
    }

    function test_batchSetAtomData_revertsOnEmptyArray() external {
        address[] memory creators = new address[](0);
        bytes[] memory atomDataArray = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);
    }

    function test_batchSetAtomData_revertsOnArraysNotSameLength() external {
        address[] memory creators = new address[](2);
        bytes[] memory atomDataArray = new bytes[](1);

        creators[0] = users.alice;
        creators[1] = users.bob;
        atomDataArray[0] = abi.encodePacked("atom data");

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);
    }

    /* =================================================== */
    /*               BATCH SET TRIPLE DATA                 */
    /* =================================================== */

    function test_batchSetTripleData_successful() external {
        address[] memory creators = new address[](1);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        creators[0] = users.alice;
        bytes32 atomId1 = keccak256("atom1");
        bytes32 atomId2 = keccak256("atom2");
        bytes32 atomId3 = keccak256("atom3");
        tripleAtomIds[0] = [atomId1, atomId2, atomId3];

        bytes32 tripleId = multiVaultMigrationMode.calculateTripleId(atomId1, atomId2, atomId3);

        vm.expectEmit(true, true, true, true);
        emit TripleCreated(creators[0], tripleId, atomId1, atomId2, atomId3);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetTripleData(creators, tripleAtomIds);

        // Verify triple data was set
        (bytes32 retrievedAtomId1, bytes32 retrievedAtomId2, bytes32 retrievedAtomId3) = multiVaultMigrationMode.getTriple(tripleId);
        assertEq(retrievedAtomId1, atomId1);
        assertEq(retrievedAtomId2, atomId2);
        assertEq(retrievedAtomId3, atomId3);
        assertTrue(multiVaultMigrationMode.isTriple(tripleId));

        // Check counter triple is also set
        bytes32 counterTripleId = multiVaultMigrationMode.getCounterIdFromTripleId(tripleId);
        assertTrue(multiVaultMigrationMode.isTriple(counterTripleId));
        assertEq(multiVaultMigrationMode.getTripleIdFromCounterId(counterTripleId), tripleId);
    }

    function test_batchSetTripleData_revertsOnEmptyArray() external {
        address[] memory creators = new address[](0);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetTripleData(creators, tripleAtomIds);
    }

    function test_batchSetTripleData_revertsOnArraysNotSameLength() external {
        address[] memory creators = new address[](2);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        creators[0] = users.alice;
        creators[1] = users.bob;
        tripleAtomIds[0] = [bytes32("atom1"), bytes32("atom2"), bytes32("atom3")];

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetTripleData(creators, tripleAtomIds);
    }

    /* =================================================== */
    /*                   HELPER FUNCTIONS                  */
    /* =================================================== */

    function test_currentSharePrice_successful() external {
        uint256 sharePrice = multiVaultMigrationMode.currentSharePrice(1, 1e18, 2e18);
        assertGt(sharePrice, 0);
    }

    function test_currentSharePrice_revertsOnInvalidBondingCurveId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVaultMigrationMode.currentSharePrice(0, 1e18, 2e18);
    }

    function test_convertToAssets_successful() external {
        uint256 assets = multiVaultMigrationMode.convertToAssets(1, 1e18, 2e18, 5e17);
        assertGt(assets, 0);
    }

    function test_convertToAssets_revertsOnInvalidBondingCurveId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVaultMigrationMode.convertToAssets(0, 1e18, 2e18, 5e17);
    }

    function testFuzz_currentSharePrice(uint256 totalShares, uint256 totalAssets) external {
        totalShares = bound(totalShares, 1e6, type(uint64).max);
        totalAssets = bound(totalAssets, 1e6, type(uint64).max);

        uint256 sharePrice = multiVaultMigrationMode.currentSharePrice(1, totalShares, totalAssets);
        assertGt(sharePrice, 0);
    }

    function testFuzz_convertToAssets(uint256 totalShares, uint256 totalAssets, uint256 shares) external {
        totalShares = bound(totalShares, 1e6, type(uint64).max);
        totalAssets = bound(totalAssets, 1e6, type(uint64).max);
        shares = bound(shares, 1, totalShares);

        uint256 assets = multiVaultMigrationMode.convertToAssets(1, totalShares, totalAssets, shares);
        assertGt(assets, 0);
        assertLe(assets, totalAssets);
    }

    /* =================================================== */
    /*                    EDGE CASES                       */
    /* =================================================== */

    function test_batchSetVaultTotals_withBothCurves() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](2);

        termIds[0] = keccak256("atom1");
        termIds[1] = keccak256("atom2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);
        vaultTypes[0] = IMultiVault.VaultType.ATOM;
        vaultTypes[1] = IMultiVault.VaultType.ATOM;

        // Test with first curve (Linear)
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);
        (uint256 totalAssets0, uint256 totalShares0) = multiVaultMigrationMode.getVault(termIds[0], 1);

        assertEq(totalAssets0, vaultTotals[0].totalAssets);
        assertEq(totalShares0, vaultTotals[0].totalShares);

        // Test with second curve (OffsetProgressive)
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 2, vaultTotals);
        (uint256 totalAssets1, uint256 totalShares1) = multiVaultMigrationMode.getVault(termIds[0], 2);
        assertEq(totalAssets1, vaultTotals[0].totalAssets);
        assertEq(totalShares1, vaultTotals[0].totalShares);
    }

    function test_largeArrayOperations() external {
        uint256 arraySize = 50; // Test with moderately large arrays

        bytes32[] memory termIds = new bytes32[](arraySize);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](arraySize);
        IMultiVault.VaultType[] memory vaultTypes = new IMultiVault.VaultType[](arraySize);

        for (uint256 i = 0; i < arraySize; i++) {
            termIds[i] = keccak256(abi.encodePacked("atom", i));
            vaultTotals[i] = MultiVaultMigrationMode.VaultTotals((i + 1) * 1e18, (i + 1) * 1e18);
            vaultTypes[i] =
                i % 2 == 0 ? IMultiVault.VaultType.ATOM : IMultiVault.VaultType.TRIPLE;
        }

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        (uint256 totalAssets0, uint256 totalShares0) = multiVaultMigrationMode.getVault(termIds[0], 1);
        (uint256 totalAssets1, uint256 totalShares1) = multiVaultMigrationMode.getVault(termIds[25], 1);
        (uint256 totalAssets2, uint256 totalShares2) = multiVaultMigrationMode.getVault(termIds[49], 1);

        assertEq(totalAssets0, 1e18);
        assertEq(totalAssets1, 26e18);
        assertEq(totalAssets2, 50e18);
    }

    /* =================================================== */
    /*                      EVENTS                         */
    /* =================================================== */

    event TermCountSet(uint256 termCount);
    event SharePriceChanged(
        bytes32 indexed termId,
        uint256 indexed bondingCurveId,
        uint256 sharePrice,
        uint256 totalAssets,
        uint256 totalShares,
        IMultiVault.VaultType vaultType
    );
    event Deposited(
        address indexed sender,
        address indexed receiver,
        bytes32 indexed termId,
        uint256 bondingCurveId,
        uint256 assets,
        uint256 assetsAfterFees,
        uint256 shares,
        IMultiVault.VaultType vaultType
    );
    event TripleCreated(
        address indexed creator, bytes32 indexed tripleId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );
}
