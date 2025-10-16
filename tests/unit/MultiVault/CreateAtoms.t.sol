// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract CreateAtomsTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_SingleAtom_Success() public {
        uint256 totalTermsCreatedBefore = protocol.multiVault.totalTermsCreated();
        bytes32 atomId = createSimpleAtom("Simple atom data", ATOM_COST[0], users.alice);

        assertTrue(protocol.multiVault.isTermCreated(atomId), "Atom should exist");
        assertEq(protocol.multiVault.totalTermsCreated(), totalTermsCreatedBefore + 1, "Total terms should increment");
    }

    function test_createAtoms_MultipleAtoms_Success() public {
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "First atom";
        atomDataArray[1] = "Second atom";
        atomDataArray[2] = "Third atom";

        bytes32[] memory atomIds = createAtomsWithUniformCost(atomDataArray, ATOM_COST[0], users.alice);

        assertEq(atomIds.length, 3, "Should return three atom IDs");
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(protocol.multiVault.isTermCreated(atomIds[i]), "Atom should exist");
        }
    }

    function test_createAtoms_MaxDataLength_Success() public {
        bytes memory maxLengthData = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            maxLengthData[i] = bytes1(uint8(65 + (i % 26))); // A-Z pattern
        }

        bytes32 atomId = createAtomWithDeposit(maxLengthData, ATOM_COST[0], users.alice);
        assertTrue(protocol.multiVault.isTermCreated(atomId), "Max length atom should be created");
    }

    function test_createAtoms_MinimalDeposit_Success() public {
        bytes32 atomId = createSimpleAtom("Minimal deposit test", ATOM_COST[0], users.alice);
        assertTrue(protocol.multiVault.isTermCreated(atomId), "Atom should be created with minimal deposit");
    }

    function test_createAtoms_ExcessDeposit_Success() public {
        bytes32 atomId = createSimpleAtom("Excess deposit test", ATOM_COST[0] * 2, users.alice);
        assertTrue(protocol.multiVault.isTermCreated(atomId), "Atom should be created with excess deposit");
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_RevertWhen_EmptyDataArray() public {
        bytes[] memory emptyArray = new bytes[](0);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NoAtomDataProvided.selector);
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(emptyArray, ATOM_COST);
    }

    function test_createAtoms_SingleByte_Success() public {
        bytes32 atomId = createSimpleAtom("x", ATOM_COST[0], users.alice);
        assertTrue(protocol.multiVault.isTermCreated(atomId), "Single byte atom should be created");
    }

    /*//////////////////////////////////////////////////////////////
                              ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_RevertWhen_InsufficientAssets() public {
        bytes memory atomData = "Insufficient balance test";
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;

        uint256[] memory insufficientAmount = new uint256[](1);
        insufficientAmount[0] = 1e4;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientAssets.selector);
        protocol.multiVault.createAtoms{ value: insufficientAmount[0] }(atomDataArray, insufficientAmount);
    }

    function test_createAtoms_RevertsWhen_ArraysLengthMismatch() public {
        bytes[] memory atomDataArray = new bytes[](2);
        atomDataArray[0] = "First atom";
        atomDataArray[1] = "Second atom";

        uint256[] memory costArray = new uint256[](1);
        costArray[0] = ATOM_COST[0];

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(atomDataArray, costArray);
    }

    function test_createAtoms_RevertWhen_AtomExists() public {
        string memory atomString = "Duplicate atom test";
        bytes memory atomData = abi.encodePacked(atomString);

        createSimpleAtom(atomString, ATOM_COST[0], users.alice);

        // Try to create same atom again
        resetPrank(users.bob);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_AtomExists.selector, atomData));
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(atomDataArray, ATOM_COST);
    }

    function test_createAtoms_RevertWhen_AtomDataTooLong() public {
        // Create data longer than maximum allowed
        bytes memory tooLongData = new bytes(1001); // Assuming 1000 is max
        for (uint256 i = 0; i < 1001; i++) {
            tooLongData[i] = bytes1(uint8(65));
        }

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = tooLongData;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_AtomDataTooLong.selector);
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(atomDataArray, ATOM_COST);
    }

    function test_createAtoms_RevertWhen_NoAtomDataProvided() public {
        bytes[] memory atomDataArray = new bytes[](1);
        // Leave atomDataArray[0] empty (default empty bytes)

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NoAtomDataProvided.selector);
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(atomDataArray, ATOM_COST);
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_VerifyTokenBalanceChanges() public {
        uint256 balanceBefore = users.alice.balance;
        createSimpleAtom("Token balance test", ATOM_COST[0], users.alice);
        uint256 balanceAfter = users.alice.balance;

        assertEq(balanceBefore - balanceAfter, ATOM_COST[0], "ETH balance should decrease by deposit amount");
    }

    function test_createAtoms_VerifyVaultSharesMinted() public {
        bytes32 atomId = createSimpleAtom("Vault shares test", ATOM_COST[0], users.alice);
        uint256 bondingCurveId = getDefaultCurveId();

        (, uint256 totalShares) = protocol.multiVault.getVault(atomId, bondingCurveId);
        assertTrue(totalShares > 0, "Shares should be minted");
    }

    /*//////////////////////////////////////////////////////////////
                          INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_MultipleUsersSequential() public {
        bytes32 aliceAtom = createSimpleAtom("Alice atom", ATOM_COST[0], users.alice);
        bytes32 bobAtom = createSimpleAtom("Bob atom", ATOM_COST[0], users.bob);
        bytes32 charlieAtom = createSimpleAtom("Charlie atom", ATOM_COST[0], users.charlie);

        assertTrue(protocol.multiVault.isTermCreated(aliceAtom), "Alice's atom should exist");
        assertTrue(protocol.multiVault.isTermCreated(bobAtom), "Bob's atom should exist");
        assertTrue(protocol.multiVault.isTermCreated(charlieAtom), "Charlie's atom should exist");

        assertTrue(aliceAtom != bobAtom, "Alice and Bob atoms should be different");
        assertTrue(bobAtom != charlieAtom, "Bob and Charlie atoms should be different");
        assertTrue(aliceAtom != charlieAtom, "Alice and Charlie atoms should be different");
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT TESTING
    //////////////////////////////////////////////////////////////*/

    function test_createAtoms_EmitsAtomCreatedEvent() public {
        bytes memory atomData = "Event test";
        bytes32 expectedAtomId = calculateAtomId(atomData);

        expectAtomCreated(users.alice, expectedAtomId, atomData);
        createAtomWithDeposit(atomData, ATOM_COST[0], users.alice);
    }
}
