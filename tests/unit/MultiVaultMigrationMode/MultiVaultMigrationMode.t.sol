// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { VaultType } from "src/interfaces/IMultiVault.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { WalletConfig } from "src/interfaces/IMultiVaultCore.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

/**
 * @title MultiVaultMigrationModeTest
 * @notice Test contract for MultiVaultMigrationMode
 *
 * ‼ CRITICAL MIGRATION ORDER ‼
 * Migration MUST be performed in the following order:
 * 1. Set term count (setTermCount)
 * 2. Set atom data (batchSetAtomData)
 * 3. Set triple data (batchSetTripleData)
 * 4. Set vault totals (batchSetVaultTotals)
 * 5. Set user positions (batchSetUserBalances)
 *
 * This order is critical because:
 * - Vault operations emit events getVaultType()
 *  getVaultType() checks if terms exist (as atoms or triples)
 * - If vault data is set before term getVaultType() will revert
 * - Terms must exist before their vault data can be properly categorized
 */
contract MultiVaultMigrationModeTest is BaseTest {
    /* =================================================== */
    /*                    TEST CONTRACTS                   */
    /* =================================================== */

    MultiVaultMigrationMode public multiVaultMigrationMode;
    BondingCurveRegistry public testBondingCurveRegistry;
    AtomWalletFactory public atomWalletFactory;

    /* =================================================== */
    /*                      CONSTANTS                      */
    /* =================================================== */

    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    /* =================================================== */
    /*                      EVENTS                      */
    /* =================================================== */

    // Import events from IMultiVault
    event SharePriceChanged(
        bytes32 indexed termId,
        uint256 indexed curveId,
        uint256 sharePrice,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    );

    event Deposited(
        address indexed sender,
        address indexed receiver,
        bytes32 indexed termId,
        uint256 curveId,
        uint256 assets,
        uint256 assetsAfterFees,
        uint256 shares,
        uint256 totalShares,
        VaultType vaultType
    );

    event TripleCreated(
        address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );

    /* =================================================== */
    /*                        SETUP                        */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        // Deploy AtomWallet implementation and beacon
        AtomWallet atomWalletImpl = new AtomWallet();
        atomWalletBeacon = new UpgradeableBeacon(address(atomWalletImpl), users.admin);

        // Deploy AtomWalletFactory
        atomWalletFactory = new AtomWalletFactory();
        atomWalletFactoryProxy = new TransparentUpgradeableProxy(address(atomWalletFactory), users.admin, "");

        // Cast the proxy to AtomWalletFactory
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));

        // Deploy BondingCurveRegistry implementation and proxy
        bondingCurveRegistryImpl = new BondingCurveRegistry();
        bondingCurveRegistryProxy = new TransparentUpgradeableProxy(
            address(bondingCurveRegistryImpl),
            users.admin,
            abi.encodeWithSelector(BondingCurveRegistry.initialize.selector, users.admin)
        );
        testBondingCurveRegistry = BondingCurveRegistry(address(bondingCurveRegistryProxy));

        // Deploy bonding curve implementations
        LinearCurve linearCurveImpl = new LinearCurve();
        OffsetProgressiveCurve offsetProgressiveCurveImpl = new OffsetProgressiveCurve();

        // Deploy proxies for bonding curves
        linearCurveProxy = new TransparentUpgradeableProxy(
            address(linearCurveImpl),
            users.admin,
            abi.encodeWithSelector(LinearCurve.initialize.selector, "Linear Curve")
        );
        linearCurve = LinearCurve(address(linearCurveProxy));

        offsetProgressiveCurveProxy = new TransparentUpgradeableProxy(
            address(offsetProgressiveCurveImpl),
            users.admin,
            abi.encodeWithSelector(
                OffsetProgressiveCurve.initialize.selector,
                "Offset Progressive Curve",
                OFFSET_PROGRESSIVE_CURVE_SLOPE,
                OFFSET_PROGRESSIVE_CURVE_OFFSET
            )
        );
        offsetProgressiveCurve = OffsetProgressiveCurve(address(offsetProgressiveCurveProxy));

        // Add curves to registry
        vm.startPrank(users.admin);
        testBondingCurveRegistry.addBondingCurve(address(linearCurve));
        testBondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        vm.stopPrank();

        // Deploy MultiVaultMigrationMode
        multiVaultMigrationMode = new MultiVaultMigrationMode();

        multiVaultProxy = new TransparentUpgradeableProxy(address(multiVaultMigrationMode), users.admin, "");

        // Cast the proxy to MultiVaultMigrationMode
        multiVaultMigrationMode = MultiVaultMigrationMode(payable(multiVaultProxy));

        // Prepare wallet config
        WalletConfig memory walletConfig = _getDefaultWalletConfig(address(atomWalletFactory));
        walletConfig.atomWalletFactory = address(atomWalletFactory);
        walletConfig.atomWalletBeacon = address(atomWalletBeacon);

        // Initialize the migration mode contract
        vm.prank(users.admin);
        multiVaultMigrationMode.initialize(
            _getDefaultGeneralConfig(),
            _getDefaultAtomConfig(),
            _getDefaultTripleConfig(),
            walletConfig,
            _getDefaultVaultFees(),
            _getTestBondingCurveConfig()
        );

        // Initialize the atom wallet factory with the MultiVault address
        vm.prank(users.admin);
        atomWalletFactory.initialize(address(multiVaultMigrationMode));

        // Grant MIGRATOR_ROLE to admin for testing
        vm.prank(users.admin);
        multiVaultMigrationMode.grantRole(MIGRATOR_ROLE, users.admin);

        // Label for debugging
        vm.label(address(multiVaultMigrationMode), "MultiVaultMigrationMode");
        vm.label(address(testBondingCurveRegistry), "TestBondingCurveRegistry");
        vm.label(address(linearCurve), "LinearCurve");
        vm.label(address(offsetProgressiveCurve), "OffsetProgressiveCurve");
        vm.label(address(atomWalletFactory), "AtomWalletFactory");
        vm.label(address(atomWalletBeacon), "AtomWalletBeacon");
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
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = keccak256("test");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert();
        vm.prank(users.alice);
        multiVaultMigrationMode.batchSetUserBalances(params);
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

        // No event is emitted by setTermCount function
        vm.prank(users.admin);
        multiVaultMigrationMode.setTermCount(termCount);

        assertEq(multiVaultMigrationMode.totalTermsCreated(), termCount);
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
            multiVaultMigrationMode.currentSharePrice(atomIds[0], 1),
            vaultTotals[0].totalAssets,
            vaultTotals[0].totalShares,
            VaultType.ATOM // We know these are atoms because we created them
        );

        vm.expectEmit(true, true, true, true);
        emit SharePriceChanged(
            atomIds[1],
            1,
            multiVaultMigrationMode.currentSharePrice(atomIds[1], 1),
            vaultTotals[1].totalAssets,
            vaultTotals[1].totalShares,
            VaultType.ATOM
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

        vm.expectRevert(abi.encodeWithSelector(MultiVaultMigrationMode.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(termIds, 0, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnArraysNotSameLength() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = keccak256("test1");
        termIds[1] = keccak256("test2");
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(1e18, 1e18);

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ArraysNotSameLength.selector));
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
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](2);
        termIds[0][0] = atomIds[0];
        termIds[0][1] = atomIds[1];

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](2);
        userBalances[0][0] = 1e18;
        userBalances[0][1] = 15e17; // 1.5e18

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            address(multiVaultMigrationMode),
            users.alice,
            atomIds[0],
            1,
            multiVaultMigrationMode.convertToAssets(atomIds[0], 1, userBalances[0][0]),
            multiVaultMigrationMode.convertToAssets(atomIds[0], 1, userBalances[0][0]),
            userBalances[0][0],
            userBalances[0][0],
            VaultType.ATOM
        );

        vm.expectEmit(true, true, true, true);
        emit Deposited(
            address(multiVaultMigrationMode),
            users.alice,
            atomIds[1],
            1,
            multiVaultMigrationMode.convertToAssets(atomIds[1], 1, userBalances[0][1]),
            multiVaultMigrationMode.convertToAssets(atomIds[1], 1, userBalances[0][1]),
            userBalances[0][1],
            userBalances[0][1],
            VaultType.ATOM
        );

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);

        // Verify user balances
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[0], 1), userBalances[0][0]);
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[1], 1), userBalances[0][1]);
    }

    function test_batchSetUserBalances_revertsOnInvalidBondingCurveId() external {
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = keccak256("test");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 0,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVaultMigrationMode.MultiVault_InvalidBondingCurveId.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_revertsOnZeroAddress() external {
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = keccak256("test");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](1);
        users_array[0] = address(0);

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVaultMigrationMode.MultiVault_ZeroAddress.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_revertsOnInvalidArrayLength_outerArrays() external {
        bytes32[][] memory termIds = new bytes32[][](2);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = keccak256("test1");
        termIds[1] = new bytes32[](1);
        termIds[1][0] = keccak256("test2");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InvalidArrayLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_revertsOnInvalidArrayLength_innerArrays() external {
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](2);
        termIds[0][0] = keccak256("test1");
        termIds[0][1] = keccak256("test2");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InvalidArrayLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_revertsOnInvalidArrayLength_emptyUsers() external {
        bytes32[][] memory termIds = new bytes32[][](0);
        uint256[][] memory userBalances = new uint256[][](0);
        address[] memory users_array = new address[](0);

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InvalidArrayLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_revertsOnInvalidArrayLength_usersMismatch() external {
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = keccak256("test1");

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = 1e18;

        address[] memory users_array = new address[](2);
        users_array[0] = users.alice;
        users_array[1] = users.bob;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InvalidArrayLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);
    }

    function test_batchSetUserBalances_multipleUsersWithDifferentVaults() external {
        // CRITICAL: Create atoms FIRST
        bytes32[] memory atomIds = _createTestAtoms();

        // Set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(2e18, 2e18);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(3e18, 3e18);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        // Set balances for multiple users with different vault sets
        bytes32[][] memory termIds = new bytes32[][](2);
        termIds[0] = new bytes32[](2);
        termIds[0][0] = atomIds[0];
        termIds[0][1] = atomIds[1];
        termIds[1] = new bytes32[](1);
        termIds[1][0] = atomIds[0];

        uint256[][] memory userBalances = new uint256[][](2);
        userBalances[0] = new uint256[](2);
        userBalances[0][0] = 1e18;
        userBalances[0][1] = 15e17;
        userBalances[1] = new uint256[](1);
        userBalances[1][0] = 5e17;

        address[] memory users_array = new address[](2);
        users_array[0] = users.alice;
        users_array[1] = users.bob;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);

        // Verify alice balances
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[0], 1), userBalances[0][0]);
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[1], 1), userBalances[0][1]);

        // Verify bob balances
        assertEq(multiVaultMigrationMode.getShares(users.bob, atomIds[0], 1), userBalances[1][0]);
        assertEq(multiVaultMigrationMode.getShares(users.bob, atomIds[1], 1), 0);
    }

    function testFuzz_batchSetUserBalances_singleUser(uint256 balance1, uint256 balance2) external {
        balance1 = bound(balance1, 1e6, type(uint96).max);
        balance2 = bound(balance2, 1e6, type(uint96).max);
        uint256 total = balance1 + balance2;

        // Create atoms
        bytes32[] memory atomIds = _createTestAtoms();

        // Set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(total, total);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(total, total);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        // Set user balances
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](2);
        termIds[0][0] = atomIds[0];
        termIds[0][1] = atomIds[1];

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](2);
        userBalances[0][0] = balance1;
        userBalances[0][1] = balance2;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);

        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[0], 1), balance1);
        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[1], 1), balance2);
    }

    function testFuzz_batchSetUserBalances_multipleUsers(uint256 aliceBalance, uint256 bobBalance) external {
        aliceBalance = bound(aliceBalance, 1e6, type(uint96).max);
        bobBalance = bound(bobBalance, 1e6, type(uint96).max);
        uint256 total = aliceBalance + bobBalance;

        // Create atoms
        bytes32[] memory atomIds = _createTestAtoms();

        // Set vault totals
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals(total, total);
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals(total, total);

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetVaultTotals(atomIds, 1, vaultTotals);

        // Set balances for multiple users
        bytes32[][] memory termIds = new bytes32[][](2);
        termIds[0] = new bytes32[](1);
        termIds[0][0] = atomIds[0];
        termIds[1] = new bytes32[](1);
        termIds[1][0] = atomIds[1];

        uint256[][] memory userBalances = new uint256[][](2);
        userBalances[0] = new uint256[](1);
        userBalances[0][0] = aliceBalance;
        userBalances[1] = new uint256[](1);
        userBalances[1][0] = bobBalance;

        address[] memory users_array = new address[](2);
        users_array[0] = users.alice;
        users_array[1] = users.bob;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);

        assertEq(multiVaultMigrationMode.getShares(users.alice, atomIds[0], 1), aliceBalance);
        assertEq(multiVaultMigrationMode.getShares(users.bob, atomIds[1], 1), bobBalance);
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
        emit AtomCreated(creators[0], atomId1, atomDataArray[0], multiVaultMigrationMode.computeAtomWalletAddr(atomId1));

        vm.expectEmit(true, true, true, true);
        emit AtomCreated(creators[1], atomId2, atomDataArray[1], multiVaultMigrationMode.computeAtomWalletAddr(atomId2));

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetAtomData(creators, atomDataArray);

        // Verify atom data was set
        assertEq(multiVaultMigrationMode.atom(atomId1), atomDataArray[0]);
        assertEq(multiVaultMigrationMode.atom(atomId2), atomDataArray[1]);
    }

    function test_batchSetAtomData_revertsOnArraysNotSameLength() external {
        address[] memory creators = new address[](2);
        bytes[] memory atomDataArray = new bytes[](1);

        creators[0] = users.alice;
        creators[1] = users.bob;
        atomDataArray[0] = abi.encodePacked("atom data");

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ArraysNotSameLength.selector));
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

    function test_batchSetTripleData_revertsOnArraysNotSameLength() external {
        address[] memory creators = new address[](2);
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        creators[0] = users.alice;
        creators[1] = users.bob;
        tripleAtomIds[0] = [bytes32("atom1"), bytes32("atom2"), bytes32("atom3")];

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ArraysNotSameLength.selector));
        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetTripleData(creators, tripleAtomIds);
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
        bytes32[][] memory termIds = new bytes32[][](1);
        termIds[0] = new bytes32[](4);
        termIds[0][0] = allTermIds[0];
        termIds[0][1] = allTermIds[1];
        termIds[0][2] = allTermIds[2];
        termIds[0][3] = allTermIds[3];

        uint256[][] memory userBalances = new uint256[][](1);
        userBalances[0] = new uint256[](4);
        userBalances[0][0] = 5e18;
        userBalances[0][1] = 10e18;
        userBalances[0][2] = 15e18;
        userBalances[0][3] = 50e18;

        address[] memory users_array = new address[](1);
        users_array[0] = users.alice;

        MultiVaultMigrationMode.BatchSetUserBalancesParams memory params = MultiVaultMigrationMode
            .BatchSetUserBalancesParams({
            termIds: termIds,
            bondingCurveId: 1,
            users: users_array,
            userBalances: userBalances
        });

        vm.prank(users.admin);
        multiVaultMigrationMode.batchSetUserBalances(params);

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

    /* =================================================== */
    /*           NATIVE TRUST RECEIVE TEST                 */
    /* =================================================== */

    function test_receive_acceptsNativeTRUST() external {
        // Fund a sender with native TRUST
        uint256 amount = 1 ether;
        vm.deal(users.alice, amount);

        // Send native TRUST to the proxy (must succeed if receive() is present in implementation)
        vm.prank(users.alice);
        (bool success,) = address(multiVaultMigrationMode).call{ value: amount }("");
        assertTrue(success, "native TRUST transfer should succeed");

        // The proxy holds the native balance
        assertEq(address(multiVaultMigrationMode).balance, amount, "contract native balance must increase");
    }
}
