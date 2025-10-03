// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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

    // Nested triple creation test
    function test_createTriples_UsingNewTriplesAsItsAtoms() public {
        (bytes32 tripleId1,) = createTripleWithAtoms("S1", "P1", "O1", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        (bytes32 tripleId2,) = createTripleWithAtoms("S2", "P2", "O2", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        (bytes32 tripleId3,) = createTripleWithAtoms("S3", "P3", "O3", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        // Attempt to create a new triple using the above triples as atoms
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);
        subjectIds[0] = tripleId1;
        predicateIds[0] = tripleId2;
        objectIds[0] = tripleId3;
        assets[0] = TRIPLE_COST[0];
        uint256 total = assets[0];

        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: total }(subjectIds, predicateIds, objectIds, assets);

        assertEq(tripleIds.length, 1, "Should return one triple ID");
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[0]), "New triple should exist");
    }

    /*//////////////////////////////////////////////////////////////
                       EXTRA ERROR BRANCHES (TRIPLES)
    //////////////////////////////////////////////////////////////*/

    function test_createTriples_PerTriple_InsufficientAssets_Revert() public {
        // Create 6 atoms for two distinct triples
        bytes[] memory atomDataArray = new bytes[](6);
        atomDataArray[0] = "S1";
        atomDataArray[1] = "P1";
        atomDataArray[2] = "O1";
        atomDataArray[3] = "S2";
        atomDataArray[4] = "P2";
        atomDataArray[5] = "O2";

        bytes32[] memory atomIds = createAtomsWithUniformCost(atomDataArray, ATOM_COST[0], users.alice);

        // Build two triples
        bytes32[] memory subjectIds = new bytes32[](2);
        bytes32[] memory predicateIds = new bytes32[](2);
        bytes32[] memory objectIds = new bytes32[](2);
        uint256[] memory assets = new uint256[](2);

        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];

        subjectIds[1] = atomIds[3];
        predicateIds[1] = atomIds[4];
        objectIds[1] = atomIds[5];

        // Per-triple funding: first is short by 1 wei, second overfunded by 1 wei.
        // Sum == 2 * TRIPLE_COST => aggregate check passes, loop hits i=0 and reverts with InsufficientAssets.
        assets[0] = TRIPLE_COST[0] - 1;
        assets[1] = TRIPLE_COST[0] + 1;
        uint256 total = assets[0] + assets[1];

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientAssets.selector);
        protocol.multiVault.createTriples{ value: total }(subjectIds, predicateIds, objectIds, assets);
    }

    function test_createTriples_TripleAlreadyExists_Revert() public {
        // First creation
        (bytes32 tripleId, bytes32[] memory ids) =
            createTripleWithAtoms("Sdup", "Pdup", "Odup", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        // Attempt to create the same triple again
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjectIds[0] = ids[0];
        predicateIds[0] = ids[1];
        objectIds[0] = ids[2];
        assets[0] = TRIPLE_COST[0];

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVault.MultiVault_TripleExists.selector, tripleId, subjectIds[0], predicateIds[0], objectIds[0]
            )
        );
        protocol.multiVault.createTriples{ value: assets[0] }(subjectIds, predicateIds, objectIds, assets);
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

    function test_createTriples_NonExistentTerm_Revert() public {
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
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_TermDoesNotExist.selector, subjectIds[0]));
        protocol.multiVault.createTriples{ value: requiredPayment }(subjectIds, predicateIds, objectIds, assets);
    }

    function test_createTriples_RevertsWhen_ArrayLengthIsZero() public {
        bytes32[] memory subjectIds = new bytes32[](0);
        bytes32[] memory predicateIds = new bytes32[](1);
        predicateIds[0] = keccak256("predicate");
        bytes32[] memory objectIds = new bytes32[](1);
        objectIds[0] = keccak256("object");
        uint256[] memory assets = new uint256[](1);
        assets[0] = TRIPLE_COST[0];

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.createTriples{ value: TRIPLE_COST[0] }(subjectIds, predicateIds, objectIds, assets);
    }
}
