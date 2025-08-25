// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract CreateTriplesTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createTriples_SingleTriple_Success() public {
        (bytes32 tripleId,) = createTripleWithAtoms(
            "Subject atom", "Predicate atom", "Object atom", ATOM_COST[0], TRIPLE_COST[0], users.alice
        );

        assertTrue(protocol.multiVault.isTermCreated(tripleId), "Triple should exist");
    }

    function test_createTriples_MultipleTriples_Success() public {
        (bytes32 tripleId1,) =
            createTripleWithAtoms("Subject1", "Predicate1", "Object1", ATOM_COST[0], TRIPLE_COST[0] + 1e18, users.alice);

        (bytes32 tripleId2,) =
            createTripleWithAtoms("Subject2", "Predicate2", "Object2", ATOM_COST[0], TRIPLE_COST[0] + 1e18, users.alice);

        assertTrue(protocol.multiVault.isTermCreated(tripleId1), "First triple should exist");
        assertTrue(protocol.multiVault.isTermCreated(tripleId2), "Second triple should exist");
    }

    function test_createTriples_SharedAtoms_Success() public {
        // Create atoms first
        bytes[] memory atomDataArray = new bytes[](4);
        atomDataArray[0] = "Shared subject";
        atomDataArray[1] = "Predicate1";
        atomDataArray[2] = "Object1";
        atomDataArray[3] = "Predicate2";

        bytes32[] memory atomIds = createAtomsWithUniformCost(atomDataArray, ATOM_COST[0], users.alice);

        // Create triples sharing atoms
        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);
        uint256[] memory assets = new uint256[](2);

        subjectIds[0] = atomIds[0]; // Shared subject
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];
        assets[0] = TRIPLE_COST[0];

        subjectIds[1] = atomIds[0]; // Same shared subject
        predicateIds[1] = atomIds[3];
        objectIds[1] = atomIds[2]; // Shared object
        assets[1] = TRIPLE_COST[0];

        uint256 totalTripleCost = calculateTotalCost(assets);
        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: totalTripleCost }(subjectIds, predicateIds, objectIds, assets);

        assertEq(tripleIds.length, 2, "Should return two triple IDs");
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[0]), "First triple should exist");
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[1]), "Second triple should exist");
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_createTriples_EmptyArrays_Revert() public {
        bytes32[] memory subjectIds = new bytes32[](0);
        bytes32[] memory predicateIds = new bytes32[](0);
        bytes32[] memory objectIds = new bytes32[](0);
        uint256[] memory assets = new uint256[](0);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.createTriples{ value: 0 }(subjectIds, predicateIds, objectIds, assets);
    }

    function test_createTriples_MismatchedArrayLengths_Revert() public {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](2); // Different length
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.createTriples{ value: 0 }(subjectIds, predicateIds, objectIds, assets);
    }

    function test_createTriples_InsufficientAssets_Revert() public {
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "Subject";
        atomDataArray[1] = "Predicate";
        atomDataArray[2] = "Object";

        bytes32[] memory atomIds = createAtomsWithUniformCost(atomDataArray, ATOM_COST[0], users.alice);

        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];
        assets[0] = TRIPLE_COST[0] - 1; // Insufficient

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientBalance.selector);
        protocol.multiVault.createTriples{ value: assets[0] }(subjectIds, predicateIds, objectIds, assets);
    }

    function test_createTriples_NonExistentAtom_Revert() public {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjectIds[0] = keccak256("non-existent");
        predicateIds[0] = keccak256("non-existent");
        objectIds[0] = keccak256("non-existent");
        assets[0] = TRIPLE_COST[0];
        uint256 requiredPayment = TRIPLE_COST[0];

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_AtomDoesNotExist.selector, subjectIds[0]));
        protocol.multiVault.createTriples{ value: requiredPayment }(subjectIds, predicateIds, objectIds, assets);
    }
}
