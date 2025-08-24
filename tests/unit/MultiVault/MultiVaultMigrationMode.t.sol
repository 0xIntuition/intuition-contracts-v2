// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

/**
 * @title MultiVaultMigrationModeTest
 * @notice Test contract for MultiVaultMigrationMode
 *
 * ⚠️ CRITICAL MIGRATION ORDER ⚠️
 * Migration MUST be performed in the following order:
 * 1. Set term count (setTermCount)
 * 2. Set atom data (batchSetAtomData)
 * 3. Set triple data (batchSetTripleData)
 * 4. Set vault totals (batchSetVaultTotals)
 * 5. Set user positions (batchSetUserBalances)
 *
 * This order is critical because:
 * - Vault operations emit events that call getVaultType()
 * - getVaultType() checks if terms exist (as atoms or triples)
 * - If vault data is set before term data, getVaultType() will revert
 * - Terms must exist before their vault data can be properly categorized
 */
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

    /* =================================================== */
    /*                      EVENTS                      */
    /* =================================================== */

    event TermCountSet(uint256 termCount);

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

        TransparentUpgradeableProxy multiVaultProxy =
            new TransparentUpgradeableProxy(address(multiVaultMigrationMode), users.admin, "");

        // Cast the proxy to MultiVaultMigrationMode
        multiVaultMigrationMode = MultiVaultMigrationMode(address(multiVaultProxy));

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

    /**
     * @notice Helper to create atom data before vault operations
     * @dev This ensures atoms exist before we try to set vault data for them
     */
    function _createTestAtoms() internal returns (bytes32[] memory atomIds) {
        address[] memory creators = new address[](2);
        bytes[] memory atomDataArray = new bytes[](2);

        creators[0] = users.alice;
        creators[1] = users.bob;
        atomDataArray[0] = abi.encodePacked("atom1");
        atomDataArray[1] = abi.encodePacked("atom2");

        atomIds = new bytes32[](2);
        atomIds[0] = multiVaultMigrationMode.calculateAtomId(atomDataArray[0]);
        atomIds[1] = multiVaultMigrationMode.calculateAtomId(atomDataArray[1]);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);

        return atomIds;
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
        // CRITICAL: Create atoms FIRST before setting vault totals
        bytes32[] memory atomIds = _createTestAtoms();

        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);

        vm.expectEmit(true, true, true, true);
        emit SharePriceChanged(
            atomIds[0],
            1,
            multiVaultMigrationMode.currentSharePrice(1, vaultTotals[0].totalShares, vaultTotals[0].totalAssets),
            vaultTotals[0].totalAssets,
            vaultTotals[0].totalShares,
            IMultiVault.VaultType.ATOM // We know these are atoms because we created them
        );

        vm.expectEmit(true, true, true, true);
        emit SharePriceChanged(
            atomIds[1],
            1,
            multiVaultMigrationMode.currentSharePrice(1, vaultTotals[1].totalShares, vaultTotals[1].totalAssets),
            vaultTotals[1].totalAssets,
            vaultTotals[1].totalShares,
            IMultiVault.VaultType.ATOM
        );

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        // Verify vault states
        (uint256 totalAssets, uint256 totalShares) = multiVaultMigrationMode.getVault(atomIds[0], 1);
        assertEq(totalAssets, vaultTotals[0].totalAssets);
        assertEq(totalShares, vaultTotals[0].totalShares);

        (totalAssets, totalShares) = multiVaultMigrationMode.getVault(atomIds[1], 1);
        assertEq(totalAssets, vaultTotals[1].totalAssets);
        assertEq(totalShares, vaultTotals[1].totalShares);
    }

    function test_batchSetVaultTotals_revertsOnInvalidBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = keccak256("test");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 0, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnEmptyArray() external {
        bytes32[] memory termIds = new bytes32[](0);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnArraysNotSameLength() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = keccak256("test1");
        termIds[1] = keccak256("test2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);

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

        // CRITICAL: Create atoms with unique IDs based on fuzzed values
        address[] memory creators = new address[](2);
        bytes[] memory atomDataArray = new bytes[](2);

        creators[0] = users.alice;
        creators[1] = users.bob;
        atomDataArray[0] = abi.encodePacked("atom1", totalAssets1);
        atomDataArray[1] = abi.encodePacked("atom2", totalAssets2);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = multiVaultMigrationMode.calculateAtomId(atomDataArray[0]);
        termIds[1] = multiVaultMigrationMode.calculateAtomId(atomDataArray[1]);

        // Create the atoms first
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);

        // Now set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(totalAssets1, totalShares1);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(totalAssets2, totalShares2);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        (uint256 totalAssets, uint256 totalShares) = multiVaultMigrationMode.getVault(termIds[0], 1);
        assertEq(totalAssets, totalAssets1);
        assertEq(totalShares, totalShares1);

        (totalAssets, totalShares) = multiVaultMigrationMode.getVault(termIds[1], 1);
        assertEq(totalAssets, totalAssets2);
        assertEq(totalShares, totalShares2);
    }

    /* =================================================== */
    /*               BATCH SET USER BALANCES               */
    /* =================================================== */

    function test_batchSetUserBalances_successful() external {
        // CRITICAL: Create atoms FIRST
        bytes32[] memory atomIds = _createTestAtoms();

        // Then set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        // Finally set user balances
        uint256[] memory userBalances = new uint256[](2);
        userBalances[0] = 1e18;
        userBalances[1] = 15e17; // 1.5e18

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            users.alice,
            users.alice,
            atomIds[0],
            1,
            multiVaultMigrationMode.convertToAssets(1, 2e18, 2e18, userBalances[0]),
            0, // assetsAfterFees
            userBalances[0],
            vaultTotals[0].totalShares,
            IMultiVault.VaultType.ATOM
        );

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            users.alice,
            users.alice,
            atomIds[1],
            1,
            multiVaultMigrationMode.convertToAssets(1, 3e18, 3e18, userBalances[1]),
            0, // assetsAfterFees
            userBalances[1],
            vaultTotals[1].totalShares,
            IMultiVault.VaultType.ATOM
        );

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(atomIds, 1, users.alice, userBalances);

        // Verify user balances
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[0], 1), userBalances[0]);
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[1], 1), userBalances[1]);
    }

    function test_batchSetUserBalances_revertsOnInvalidBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = keccak256("test");
        userBalances[0] = 1e18;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 0, users.alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnZeroAddress() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = keccak256("test");
        userBalances[0] = 1e18;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, address(0), userBalances);
    }

    function test_batchSetUserBalances_revertsOnEmptyArray() external {
        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory userBalances = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(termIds, 1, users.alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnArraysNotSameLength() external {
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = keccak256("test1");
        termIds[1] = keccak256("test2");
        userBalances[0] = 1e18;

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
        assertEq(multiVaultMigrationMode.atom(atomId1), atomDataArray[0]);
        assertEq(multiVaultMigrationMode.atom(atomId2), atomDataArray[1]);
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
        (bytes32 retrievedTriple1, bytes32 retrievedTriple2, bytes32 retrievedTriple3) =
            multiVaultMigrationMode.triple(tripleId);
        assertEq(retrievedTriple1, atomId1);
        assertEq(retrievedTriple2, atomId2);
        assertEq(retrievedTriple3, atomId3);
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

    function test_currentSharePrice_successful() external view {
        uint256 sharePrice = multiVaultMigrationMode.currentSharePrice(1, 1e18, 2e18);
        assertGt(sharePrice, 0);
    }

    function test_currentSharePrice_revertsOnInvalidBondingCurveId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVaultMigrationMode.currentSharePrice(0, 1e18, 2e18);
    }

    function test_convertToAssets_successful() external view {
        uint256 assets = multiVaultMigrationMode.convertToAssets(1, 1e18, 2e18, 5e17);
        assertGt(assets, 0);
    }

    function test_convertToAssets_revertsOnInvalidBondingCurveId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVaultMigrationMode.convertToAssets(0, 1e18, 2e18, 5e17);
    }

    function testFuzz_currentSharePrice(uint256 totalShares, uint256 totalAssets) external view {
        totalShares = bound(totalShares, 1e6, type(uint64).max);
        totalAssets = bound(totalAssets, 1e6, type(uint64).max);

        uint256 sharePrice = multiVaultMigrationMode.currentSharePrice(1, totalShares, totalAssets);
        assertGt(sharePrice, 0);
    }

    function testFuzz_convertToAssets_linear(uint256 totalShares, uint256 totalAssets, uint256 shares) public view {
        totalShares = bound(totalShares, 1, type(uint64).max);
        totalAssets = bound(totalAssets, totalShares, type(uint64).max); // ensure assets/share >= 1
        shares = bound(shares, 1, totalShares);

        uint256 assets = multiVaultMigrationMode.convertToAssets(1, totalShares, totalAssets, shares);
        uint256 expected = shares * totalAssets / totalShares;
        assertEq(assets, expected);
        assertLe(assets, totalAssets);
    }

    /* =================================================== */
    /*                    EDGE CASES                       */
    /* =================================================== */

    function test_batchSetVaultTotals_withBothCurves() external {
        // CRITICAL: Create atoms FIRST
        bytes32[] memory atomIds = _createTestAtoms();

        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);

        // Test with first curve (Linear)
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        (uint256 totalAssets, uint256 totalShares) = multiVaultMigrationMode.getVault(atomIds[0], 1);
        assertEq(totalAssets, vaultTotals[0].totalAssets);
        assertEq(totalShares, vaultTotals[0].totalShares);

        // Test with second curve (OffsetProgressive)
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 2, vaultTotals);

        (totalAssets, totalShares) = multiVaultMigrationMode.getVault(atomIds[0], 2);
        assertEq(totalAssets, vaultTotals[0].totalAssets);
        assertEq(totalShares, vaultTotals[0].totalShares);
    }

    function test_largeArrayOperations() external {
        uint256 arraySize = 50; // Test with moderately large arrays (50 is a realistic batch size in production)

        // CRITICAL: Create atoms FIRST
        address[] memory creators = new address[](arraySize);
        bytes[] memory atomDataArray = new bytes[](arraySize);
        bytes32[] memory termIds = new bytes32[](arraySize);

        for (uint256 i = 0; i < arraySize; i++) {
            creators[i] = users.alice;
            atomDataArray[i] = abi.encodePacked("atom", i);
            termIds[i] = multiVaultMigrationMode.calculateAtomId(atomDataArray[i]);
        }

        // Create all atoms
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);

        // Now set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](arraySize);
        for (uint256 i = 0; i < arraySize; i++) {
            vaultTotals[i] = MultiVaultMigrationMode.VaultTotals((i + 1) * 1e18, (i + 1) * 1e18);
        }

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 1, vaultTotals);

        // Verify a few random entries
        (uint256 totalAssets1,) = multiVaultMigrationMode.getVault(termIds[0], 1);
        (uint256 totalAssets25,) = multiVaultMigrationMode.getVault(termIds[24], 1);
        (uint256 totalAssets49,) = multiVaultMigrationMode.getVault(termIds[48], 1);
        assertEq(totalAssets1, 1e18);
        assertEq(totalAssets25, 25e18);
        assertEq(totalAssets49, 49e18);
    }

    /**
     * @notice Test the complete migration flow in the correct order
     * @dev This test demonstrates the critical importance of migration order
     */
    function test_completeMigrationFlow() external {
        // Step 1: Set term count
        vm.prank(users.admin);
        multiVaultMigrationMode.setTermCount(100);

        // Step 2: Create atoms
        address[] memory atomCreators = new address[](3);
        bytes[] memory atomDataArray = new bytes[](3);

        atomCreators[0] = users.alice;
        atomCreators[1] = users.bob;
        atomCreators[2] = users.charlie;
        atomDataArray[0] = abi.encodePacked("subject");
        atomDataArray[1] = abi.encodePacked("predicate");
        atomDataArray[2] = abi.encodePacked("object");

        bytes32 subjectId = multiVaultMigrationMode.calculateAtomId(atomDataArray[0]);
        bytes32 predicateId = multiVaultMigrationMode.calculateAtomId(atomDataArray[1]);
        bytes32 objectId = multiVaultMigrationMode.calculateAtomId(atomDataArray[2]);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(atomCreators, atomDataArray);

        // Step 3: Create triple
        address[] memory tripleCreators = new address[](1);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        tripleCreators[0] = users.alice;
        tripleAtomIds[0] = [subjectId, predicateId, objectId];

        bytes32 tripleId = multiVaultMigrationMode.calculateTripleId(subjectId, predicateId, objectId);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetTripleData(tripleCreators, tripleAtomIds);

        // Step 4: Set vault totals for atoms and triple
        bytes32[] memory allTermIds = new bytes32[](4);
        allTermIds[0] = subjectId;
        allTermIds[1] = predicateId;
        allTermIds[2] = objectId;
        allTermIds[3] = tripleId;

        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](4);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(10e18, 10e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(20e18, 20e18);
        vaultTotals[2] = MultiVaultMigrationMode.VaultTotals(30e18, 30e18);
        vaultTotals[3] = MultiVaultMigrationMode.VaultTotals(100e18, 100e18);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(allTermIds, 1, vaultTotals);

        // Step 5: Set user balances
        uint256[] memory userBalances = new uint256[](4);
        userBalances[0] = 5e18;
        userBalances[1] = 10e18;
        userBalances[2] = 15e18;
        userBalances[3] = 50e18;

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(allTermIds, 1, users.alice, userBalances);

        // Verify everything was set correctly
        assertEq(multiVaultMigrationMode.totalTermsCreated(), 100);
        assertTrue(multiVaultMigrationMode.isAtom(subjectId));
        assertTrue(multiVaultMigrationMode.isAtom(predicateId));
        assertTrue(multiVaultMigrationMode.isAtom(objectId));
        assertTrue(multiVaultMigrationMode.isTriple(tripleId));

        (uint256 totalAssets, uint256 totalShares) = multiVaultMigrationMode.getVault(tripleId, 1);
        assertEq(totalAssets, 100e18);
        assertEq(totalShares, 100e18);

        assertEq(multiVaultMigrationMode.getShares(users.alice, tripleId, 1), 50e18);
    }
}
