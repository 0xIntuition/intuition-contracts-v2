// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MultiVaultBase} from "test/MultiVaultBase.sol";
import {MultiVaultMigrationMode} from "src/v2/MultiVaultMigrationMode.sol";
import {Errors} from "src/libraries/Errors.sol";

contract MultiVaultMigrationModeTest is MultiVaultBase {
    MultiVaultMigrationMode public migrationVault;

    function setUp() public override {
        super.setUp();

        MultiVaultMigrationMode logic = new MultiVaultMigrationMode();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), admin, "");
        migrationVault = MultiVaultMigrationMode(address(proxy));
        migrationVault.initialize(address(multiVaultConfig));
    }

    function test_setTermCount_successful() external {
        vm.prank(migrator);
        vm.expectEmit(true, true, true, true);
        emit MultiVaultMigrationMode.TermCountSet(42);
        migrationVault.setTermCount(42);

        assertEq(migrationVault.termCount(), 42);
    }

    function test_setTermCount_revertsOnZeroValue() external {
        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroValue.selector));
        migrationVault.setTermCount(0);
    }

    function test_setTermCount_revertsOnUnauthorizedUser() external {
        vm.prank(bob);
        vm.expectRevert();
        migrationVault.setTermCount(1);
    }

    function test_setTermCount_revertsOnZeroAddress() external {
        vm.prank(address(0));
        vm.expectRevert();
        migrationVault.setTermCount(1);
    }

    function test_batchSetVaultTotals_successful() external {
        bytes32[] memory termIds = new bytes32[](2);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);

        termIds[0] = bytes32(uint256(1));
        termIds[1] = bytes32(uint256(2));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals({totalAssets: 100, totalShares: 90});
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals({totalAssets: 200, totalShares: 180});

        vm.prank(migrator);
        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);

        (uint256 totalShares00, uint256 totalAssets00) = migrationVault.getVaultTotals(bytes32(uint256(1)), 1);
        (uint256 totalShares1, uint256 totalAssets1) = migrationVault.getVaultTotals(bytes32(uint256(2)), 1);

        assertEq(totalShares00, 90);
        assertEq(totalAssets00, 100);
        assertEq(totalShares1, 180);
        assertEq(totalAssets1, 200);
    }

    function test_batchSetVaultTotals_revertsOnZeroBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = bytes32(uint256(1));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals({totalAssets: 1, totalShares: 1});

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        migrationVault.batchSetVaultTotals(termIds, 0, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnEmptyArray() external {
        bytes32[] memory emptyTermIds = new bytes32[](0);
        MultiVaultMigrationMode.VaultTotals[] memory emptyVaultTotals = new MultiVaultMigrationMode.VaultTotals[](0);

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        migrationVault.batchSetVaultTotals(emptyTermIds, 1, emptyVaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnLengthMismatch() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](2);

        termIds[0] = bytes32(uint256(1));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals({totalAssets: 1, totalShares: 1});
        vaultTotals[1] = MultiVaultMigrationMode.VaultTotals({totalAssets: 2, totalShares: 2});

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetVaultTotals_revertsOnUnauthorizedUser() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = bytes32(uint256(1));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals({totalAssets: 1, totalShares: 1});

        vm.prank(bob);
        vm.expectRevert();
        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetVaultTotals_emitsEvents() external {
        bytes32[] memory termIds = new bytes32[](1);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](1);

        termIds[0] = bytes32(uint256(5));
        vaultTotals[0] = MultiVaultMigrationMode.VaultTotals({totalAssets: 150, totalShares: 140});

        vm.prank(migrator);
        vm.expectEmit(true, true, true, true);
        emit MultiVaultMigrationMode.VaultTotalsSet(bytes32(uint256(5)), 1, 150, 140);
        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);
    }

    function test_batchSetUserBalances_successful() external {
        bytes32[] memory termIds = new bytes32[](2);
        uint256[] memory userBalances = new uint256[](2);

        termIds[0] = bytes32(uint256(1));
        termIds[1] = bytes32(uint256(2));
        userBalances[0] = 123;
        userBalances[1] = 456;

        vm.prank(migrator);
        migrationVault.batchSetUserBalances(termIds, 1, alice, userBalances);

        assertEq(migrationVault.balanceOf(alice, bytes32(uint256(1)), 1), 123);
        assertEq(migrationVault.balanceOf(alice, bytes32(uint256(2)), 1), 456);
    }

    function test_batchSetUserBalances_revertsOnZeroBondingCurveId() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = bytes32(uint256(1));
        userBalances[0] = 1;

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        migrationVault.batchSetUserBalances(termIds, 0, alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnZeroAddress() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = bytes32(uint256(1));
        userBalances[0] = 1;

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        migrationVault.batchSetUserBalances(termIds, 1, address(0), userBalances);
    }

    function test_batchSetUserBalances_revertsOnEmptyArray() external {
        bytes32[] memory emptyTermIds = new bytes32[](0);
        uint256[] memory emptyUserBalances = new uint256[](0);

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        migrationVault.batchSetUserBalances(emptyTermIds, 1, alice, emptyUserBalances);
    }

    function test_batchSetUserBalances_revertsOnLengthMismatch() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](2);

        termIds[0] = bytes32(uint256(1));
        userBalances[0] = 1;
        userBalances[1] = 2;

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        migrationVault.batchSetUserBalances(termIds, 1, alice, userBalances);
    }

    function test_batchSetUserBalances_revertsOnUnauthorizedUser() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = bytes32(uint256(1));
        userBalances[0] = 1;

        vm.prank(bob);
        vm.expectRevert();
        migrationVault.batchSetUserBalances(termIds, 1, alice, userBalances);
    }

    function test_batchSetUserBalances_emitsEvents() external {
        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory userBalances = new uint256[](1);

        termIds[0] = bytes32(uint256(3));
        userBalances[0] = 789;

        vm.prank(migrator);
        vm.expectEmit(true, true, true, true);
        emit MultiVaultMigrationMode.UserBalanceSet(bytes32(uint256(3)), 1, alice, 789);
        migrationVault.batchSetUserBalances(termIds, 1, alice, userBalances);
    }

    function test_batchSetAtomData_successful() external {
        bytes[] memory atomDataArray = new bytes[](2);

        atomDataArray[0] = "atom-A";
        atomDataArray[1] = "atom-B";

        vm.prank(migrator);
        migrationVault.batchSetAtomData(atomDataArray);

        bytes32 atomId0 = migrationVault.getAtomIdFromData(atomDataArray[0]);
        bytes32 atomId1 = migrationVault.getAtomIdFromData(atomDataArray[1]);

        assertEq(migrationVault.atomData(atomId0), atomDataArray[0]);
        assertEq(migrationVault.atomData(atomId1), atomDataArray[1]);
    }

    function test_batchSetAtomData_revertsOnEmptyArray() external {
        bytes[] memory emptyAtomDataArray = new bytes[](0);

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        migrationVault.batchSetAtomData(emptyAtomDataArray);
    }

    function test_batchSetAtomData_revertsOnUnauthorizedUser() external {
        bytes[] memory atomDataArray = new bytes[](1);

        atomDataArray[0] = "atom-A";

        vm.prank(bob);
        vm.expectRevert();
        migrationVault.batchSetAtomData(atomDataArray);
    }

    function test_batchSetAtomData_emitsEvents() external {
        bytes[] memory atomDataArray = new bytes[](1);

        atomDataArray[0] = "test-atom";

        bytes32 expectedAtomId = migrationVault.getAtomIdFromData(atomDataArray[0]);

        vm.prank(migrator);
        vm.expectEmit(true, true, true, true);
        emit MultiVaultMigrationMode.AtomDataSet(expectedAtomId, atomDataArray[0]);
        migrationVault.batchSetAtomData(atomDataArray);
    }

    function test_batchSetAtomData_handlesEmptyData() external {
        bytes[] memory atomDataArray = new bytes[](1);

        atomDataArray[0] = "";

        vm.prank(migrator);
        migrationVault.batchSetAtomData(atomDataArray);

        bytes32 atomId = migrationVault.getAtomIdFromData(atomDataArray[0]);
        assertEq(migrationVault.atomData(atomId), atomDataArray[0]);
    }

    function test_batchSetTripleData_successful() external {
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        tripleAtomIds[0] = [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];

        vm.prank(migrator);
        migrationVault.batchSetTripleData(tripleAtomIds);

        bytes32 tripleId = migrationVault.tripleIdFromAtomIds(bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3)));
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = migrationVault.getTripleAtoms(tripleId);

        assertEq(subjectId, bytes32(uint256(1)));
        assertEq(predicateId, bytes32(uint256(2)));
        assertEq(objectId, bytes32(uint256(3)));
        assertTrue(migrationVault.isTripleId(tripleId));
    }

    function test_batchSetTripleData_revertsOnEmptyArray() external {
        bytes32[3][] memory emptyTripleAtomIds = new bytes32[3][](0);

        vm.prank(migrator);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        migrationVault.batchSetTripleData(emptyTripleAtomIds);
    }

    function test_batchSetTripleData_revertsOnUnauthorizedUser() external {
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        tripleAtomIds[0] = [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];

        vm.prank(bob);
        vm.expectRevert();
        migrationVault.batchSetTripleData(tripleAtomIds);
    }

    function test_batchSetTripleData_emitsEvents() external {
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        tripleAtomIds[0] = [bytes32(uint256(10)), bytes32(uint256(20)), bytes32(uint256(30))];

        bytes32 expectedTripleId = migrationVault.tripleIdFromAtomIds(bytes32(uint256(10)), bytes32(uint256(20)), bytes32(uint256(30)));

        vm.prank(migrator);
        vm.expectEmit(true, true, true, true);
        emit MultiVaultMigrationMode.TripleDataSet(expectedTripleId, bytes32(uint256(10)), bytes32(uint256(20)), bytes32(uint256(30)));
        migrationVault.batchSetTripleData(tripleAtomIds);
    }

    function test_batchSetTripleData_multipleTriples() external {
        bytes32[3][] memory tripleAtomIds = new bytes32[3][](3);

        tripleAtomIds[0] = [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];
        tripleAtomIds[1] = [bytes32(uint256(4)), bytes32(uint256(5)), bytes32(uint256(6))];
        tripleAtomIds[2] = [bytes32(uint256(7)), bytes32(uint256(8)), bytes32(uint256(9))];

        vm.prank(migrator);
        migrationVault.batchSetTripleData(tripleAtomIds);

        for (uint256 i = 0; i < 3; i++) {
            bytes32 tripleId = migrationVault.tripleIdFromAtomIds(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            (bytes32 s, bytes32 p, bytes32 o) = migrationVault.getTripleAtoms(tripleId);
            assertEq(s, tripleAtomIds[i][0]);
            assertEq(p, tripleAtomIds[i][1]);
            assertEq(o, tripleAtomIds[i][2]);
            assertTrue(migrationVault.isTripleId(tripleId));
        }
    }

    function testFuzz_setTermCount(uint256 termCount) external {
        vm.assume(termCount > 0);

        vm.prank(migrator);
        migrationVault.setTermCount(termCount);

        assertEq(migrationVault.termCount(), termCount);
    }

    function testFuzz_batchSetVaultTotals(
        uint256 numberOfTerms,
        uint256 bondingCurveId,
        uint256 totalAssets,
        uint256 totalShares
    ) external {
        numberOfTerms = bound(numberOfTerms, 1, 100);
        bondingCurveId = bound(bondingCurveId, 1, 10);
        totalAssets = bound(totalAssets, 0, type(uint128).max);
        totalShares = bound(totalShares, 0, type(uint128).max);

        bytes32[] memory termIds = new bytes32[](numberOfTerms);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals =
            new MultiVaultMigrationMode.VaultTotals[](numberOfTerms);

        for (uint256 i = 0; i < numberOfTerms; i++) {
            termIds[i] = bytes32(i + 1);
            vaultTotals[i] =
                MultiVaultMigrationMode.VaultTotals({totalAssets: totalAssets + i, totalShares: totalShares + i});
        }

        vm.prank(migrator);
        migrationVault.batchSetVaultTotals(termIds, bondingCurveId, vaultTotals);

        for (uint256 i = 0; i < numberOfTerms; i++) {
            (uint256 shares, uint256 assets) = migrationVault.getVaultTotals(termIds[i], bondingCurveId);
            assertEq(shares, totalShares + i);
            assertEq(assets, totalAssets + i);
        }
    }

    function testFuzz_batchSetUserBalances(
        uint256 numberOfTerms,
        uint256 bondingCurveId,
        address user,
        uint256 baseBalance
    ) external {
        numberOfTerms = bound(numberOfTerms, 1, 100);
        bondingCurveId = bound(bondingCurveId, 1, 10);
        vm.assume(user != address(0));
        baseBalance = bound(baseBalance, 0, type(uint128).max);

        bytes32[] memory termIds = new bytes32[](numberOfTerms);
        uint256[] memory userBalances = new uint256[](numberOfTerms);

        for (uint256 i = 0; i < numberOfTerms; i++) {
            termIds[i] = bytes32(i + 1);
            userBalances[i] = baseBalance + i;
        }

        vm.prank(migrator);
        migrationVault.batchSetUserBalances(termIds, bondingCurveId, user, userBalances);

        for (uint256 i = 0; i < numberOfTerms; i++) {
            assertEq(migrationVault.balanceOf(user, termIds[i], bondingCurveId), baseBalance + i);
        }
    }

    function testFuzz_batchSetAtomData(uint256 numberOfAtoms, bytes calldata atomData) external {
        numberOfAtoms = bound(numberOfAtoms, 1, 100);

        bytes[] memory atomDataArray = new bytes[](numberOfAtoms);

        for (uint256 i = 0; i < numberOfAtoms; i++) {
            atomDataArray[i] = abi.encodePacked(atomData, i);
        }

        vm.prank(migrator);
        migrationVault.batchSetAtomData(atomDataArray);

        for (uint256 i = 0; i < numberOfAtoms; i++) {
            bytes32 atomId = migrationVault.getAtomIdFromData(atomDataArray[i]);
            assertEq(migrationVault.atomData(atomId), atomDataArray[i]);
        }
    }

    function testFuzz_batchSetTripleData(
        uint256 numberOfTriples,
        uint256 subjectId,
        uint256 predicateId,
        uint256 objectId
    ) external {
        numberOfTriples = bound(numberOfTriples, 1, 100);
        subjectId = bound(subjectId, 1, type(uint32).max);
        predicateId = bound(predicateId, 1, type(uint32).max);
        objectId = bound(objectId, 1, type(uint32).max);

        bytes32[3][] memory tripleAtomIds = new bytes32[3][](numberOfTriples);

        for (uint256 i = 0; i < numberOfTriples; i++) {
            tripleAtomIds[i] = [bytes32(subjectId + i), bytes32(predicateId + i), bytes32(objectId + i)];
        }

        vm.prank(migrator);
        migrationVault.batchSetTripleData(tripleAtomIds);

        for (uint256 i = 0; i < numberOfTriples; i++) {
            bytes32 tripleId = migrationVault.tripleIdFromAtomIds(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            (bytes32 s, bytes32 p, bytes32 o) = migrationVault.getTripleAtoms(tripleId);
            assertEq(s, bytes32(subjectId + i));
            assertEq(p, bytes32(predicateId + i));
            assertEq(o, bytes32(objectId + i));
            assertTrue(migrationVault.isTripleId(tripleId));
        }
    }

    function testFuzz_migrationWorkflow(
        uint256 termCount,
        uint256 numberOfTerms,
        uint256 numberOfAtoms,
        uint256 numberOfTriples
    ) external {
        termCount = bound(termCount, 1, 1000);
        numberOfTerms = bound(numberOfTerms, 1, 50);
        numberOfAtoms = bound(numberOfAtoms, 1, 50);
        numberOfTriples = bound(numberOfTriples, 1, 50);

        vm.startPrank(migrator);

        migrationVault.setTermCount(termCount);
        assertEq(migrationVault.termCount(), termCount);

        bytes32[] memory termIds = new bytes32[](numberOfTerms);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals =
            new MultiVaultMigrationMode.VaultTotals[](numberOfTerms);

        for (uint256 i = 0; i < numberOfTerms; i++) {
            termIds[i] = bytes32(i + 1);
            vaultTotals[i] = MultiVaultMigrationMode.VaultTotals({totalAssets: 100 + i, totalShares: 90 + i});
        }

        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);

        uint256[] memory userBalances = new uint256[](numberOfTerms);
        for (uint256 i = 0; i < numberOfTerms; i++) {
            userBalances[i] = 10 + i;
        }

        migrationVault.batchSetUserBalances(termIds, 1, alice, userBalances);

        bytes[] memory atomDataArray = new bytes[](numberOfAtoms);

        for (uint256 i = 0; i < numberOfAtoms; i++) {
            atomDataArray[i] = abi.encodePacked("atom-", i);
        }

        migrationVault.batchSetAtomData(atomDataArray);

        bytes32[3][] memory tripleAtomIds = new bytes32[3][](numberOfTriples);

        for (uint256 i = 0; i < numberOfTriples; i++) {
            tripleAtomIds[i] = [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];
        }

        migrationVault.batchSetTripleData(tripleAtomIds);

        vm.stopPrank();

        for (uint256 i = 0; i < numberOfTerms; i++) {
            (uint256 shares, uint256 assets) = migrationVault.getVaultTotals(termIds[i], 1);
            assertEq(shares, 90 + i);
            assertEq(assets, 100 + i);
            assertEq(migrationVault.balanceOf(alice, termIds[i], 1), 10 + i);
        }

        for (uint256 i = 0; i < numberOfAtoms; i++) {
            bytes32 atomId = migrationVault.getAtomIdFromData(atomDataArray[i]);
            assertEq(migrationVault.atomData(atomId), atomDataArray[i]);
        }

        for (uint256 i = 0; i < numberOfTriples; i++) {
            bytes32 tripleId = migrationVault.tripleIdFromAtomIds(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            assertTrue(migrationVault.isTripleId(tripleId));
        }
    }

    function test_complexMigrationScenario() external {
        vm.startPrank(migrator);

        migrationVault.setTermCount(5);

        bytes32[] memory termIds = new bytes32[](5);
        MultiVaultMigrationMode.VaultTotals[] memory vaultTotals = new MultiVaultMigrationMode.VaultTotals[](5);

        for (uint256 i = 0; i < 5; i++) {
            termIds[i] = bytes32(i + 1);
            vaultTotals[i] =
                MultiVaultMigrationMode.VaultTotals({totalAssets: (i + 1) * 1000, totalShares: (i + 1) * 900});
        }

        migrationVault.batchSetVaultTotals(termIds, 1, vaultTotals);

        uint256[] memory aliceBalances = new uint256[](5);
        uint256[] memory bobBalances = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            aliceBalances[i] = (i + 1) * 100;
            bobBalances[i] = (i + 1) * 50;
        }

        migrationVault.batchSetUserBalances(termIds, 1, alice, aliceBalances);
        migrationVault.batchSetUserBalances(termIds, 1, bob, bobBalances);

        bytes[] memory atomDataArray = new bytes[](3);

        atomDataArray[0] = "subject-atom";
        atomDataArray[1] = "predicate-atom";
        atomDataArray[2] = "object-atom";

        migrationVault.batchSetAtomData(atomDataArray);

        bytes32[3][] memory tripleAtomIds = new bytes32[3][](1);

        bytes32 subjectId = migrationVault.getAtomIdFromData(atomDataArray[0]);
        bytes32 predicateId = migrationVault.getAtomIdFromData(atomDataArray[1]);
        bytes32 objectId = migrationVault.getAtomIdFromData(atomDataArray[2]);

        tripleAtomIds[0] = [subjectId, predicateId, objectId];

        migrationVault.batchSetTripleData(tripleAtomIds);

        vm.stopPrank();

        assertEq(migrationVault.termCount(), 5);

        for (uint256 i = 0; i < 5; i++) {
            (uint256 shares, uint256 assets) = migrationVault.getVaultTotals(bytes32(i + 1), 1);
            assertEq(shares, (i + 1) * 900);
            assertEq(assets, (i + 1) * 1000);
            assertEq(migrationVault.balanceOf(alice, bytes32(i + 1), 1), (i + 1) * 100);
            assertEq(migrationVault.balanceOf(bob, bytes32(i + 1), 1), (i + 1) * 50);
        }

        for (uint256 i = 0; i < 3; i++) {
            bytes32 atomId = migrationVault.getAtomIdFromData(atomDataArray[i]);
            assertEq(migrationVault.atomData(atomId), atomDataArray[i]);
        }

        bytes32 tripleId = migrationVault.tripleIdFromAtomIds(subjectId, predicateId, objectId);
        (bytes32 s, bytes32 p, bytes32 o) = migrationVault.getTripleAtoms(tripleId);
        assertEq(s, subjectId);
        assertEq(p, predicateId);
        assertEq(o, objectId);
        assertTrue(migrationVault.isTripleId(tripleId));
    }
}
