// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { IMultiVault, ApprovalTypes } from "src/interfaces/IMultiVault.sol";

contract DepositBatchTest is BaseTest {
    uint256 internal CURVE_ID;
    uint256 internal constant MAX_BATCH_SIZE = 150;

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_depositBatch_SingleTerm_Success() public {
        bytes32 atomId = createSimpleAtom("Single term batch", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        uint256[] memory shares = makeDepositBatch(users.alice, users.alice, termIds, curveIds, amounts, minShares);

        assertEq(shares.length, 1, "Should return one share amount");
        assertTrue(shares[0] > 0, "Should receive some shares");

        uint256 vaultBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(vaultBalance, shares[0], "Vault balance should match shares received");
    }

    function test_depositBatch_MultipleTerms_Success() public {
        string[] memory atomStrings = new string[](3);
        atomStrings[0] = "Batch atom 1";
        atomStrings[1] = "Batch atom 2";
        atomStrings[2] = "Batch atom 3";

        uint256[] memory atomCosts = createUniformArray(ATOM_COST[0], 3);
        bytes32[] memory atomIds = createMultipleAtoms(atomStrings, atomCosts, users.alice);

        uint256[] memory curveIds = createDefaultCurveIdArray(3);
        uint256[] memory amounts = createUniformArray(15e18, 3);
        uint256[] memory minShares = createUniformArray(1e4, 3);

        uint256[] memory shares = makeDepositBatch(users.alice, users.alice, atomIds, curveIds, amounts, minShares);

        assertEq(shares.length, 3, "Should return three share amounts");
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(shares[i] > 0, "Each deposit should receive shares");
            uint256 vaultBalance = protocol.multiVault.getShares(users.alice, atomIds[i], CURVE_ID);
            assertEq(vaultBalance, shares[i], "Vault balance should match shares for each atom");
        }
    }

    function test_depositBatch_DifferentAmounts_Success() public {
        string[] memory atomStrings = new string[](3);
        atomStrings[0] = "Variable batch 1";
        atomStrings[1] = "Variable batch 2";
        atomStrings[2] = "Variable batch 3";

        uint256[] memory atomCosts = createUniformArray(ATOM_COST[0], 3);
        bytes32[] memory atomIds = createMultipleAtoms(atomStrings, atomCosts, users.alice);

        uint256[] memory curveIds = createDefaultCurveIdArray(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5e18;
        amounts[1] = 10e18;
        amounts[2] = 20e18;
        uint256[] memory minShares = createUniformArray(1e4, 3);

        uint256[] memory shares = makeDepositBatch(users.alice, users.alice, atomIds, curveIds, amounts, minShares);

        assertEq(shares.length, 3, "Should return three share amounts");
        // Larger deposits should generally result in more shares (bonding curve dependent)
        assertTrue(shares[0] > 0 && shares[1] > 0 && shares[2] > 0, "All deposits should receive shares");
    }

    function test_depositBatch_DifferentReceiver_Success() public {
        bytes32 atomId = createSimpleAtom("Different receiver batch", ATOM_COST[0], users.alice);

        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        uint256[] memory shares = makeDepositBatch(users.alice, users.bob, termIds, curveIds, amounts, minShares);

        uint256 bobBalance = protocol.multiVault.getShares(users.bob, atomId, CURVE_ID);
        assertEq(bobBalance, shares[0], "Bob should receive the shares");

        uint256 aliceBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(aliceBalance, 0, "Alice should not receive shares");
    }

    function test_depositBatch_MixedAtomsAndTriples_Success() public {
        // Create atoms
        bytes32 atomId = createSimpleAtom("Mixed batch atom", ATOM_COST[0], users.alice);

        // Create triple
        (bytes32 tripleId,) = createTripleWithAtoms(
            "Mixed Subject", "Mixed Predicate", "Mixed Object", ATOM_COST[0], TRIPLE_COST[0], users.alice
        );

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomId;
        termIds[1] = tripleId;

        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory amounts = createUniformArray(12e18, 2);
        uint256[] memory minShares = createUniformArray(1e4, 2);

        uint256[] memory shares = makeDepositBatch(users.alice, users.alice, termIds, curveIds, amounts, minShares);

        assertEq(shares.length, 2, "Should return two share amounts");
        assertTrue(shares[0] > 0 && shares[1] > 0, "Both deposits should succeed");
    }

    function test_depositBatch_MaxBatchSize_Success() public {
        uint256 batchSize = 5; // Using smaller size for test efficiency

        string[] memory atomStrings = new string[](batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            atomStrings[i] = string(abi.encodePacked("Max batch atom ", i));
        }

        uint256[] memory atomCosts = createUniformArray(ATOM_COST[0], batchSize);
        bytes32[] memory atomIds = createMultipleAtoms(atomStrings, atomCosts, users.alice);

        uint256[] memory curveIds = createDefaultCurveIdArray(batchSize);
        uint256[] memory amounts = createUniformArray(8e18, batchSize);
        uint256[] memory minShares = createUniformArray(1e4, batchSize);

        uint256[] memory shares = makeDepositBatch(users.alice, users.alice, atomIds, curveIds, amounts, minShares);

        assertEq(shares.length, batchSize, "Should handle batch size correctly");
        for (uint256 i = 0; i < batchSize; i++) {
            assertTrue(shares[i] > 0, "Each deposit should succeed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_depositBatch_EmptyArrays_Revert() public {
        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory curveIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory minShares = new uint256[](0);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.depositBatch{ value: 0 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    function test_depositBatch_ExceedsMaxBatchSize_Revert() public {
        uint256 oversizedBatch = MAX_BATCH_SIZE + 1;

        bytes32[] memory termIds = new bytes32[](oversizedBatch);
        uint256[] memory curveIds = new uint256[](oversizedBatch);
        uint256[] memory amounts = new uint256[](oversizedBatch);
        uint256[] memory minShares = new uint256[](oversizedBatch);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.depositBatch{ value: 0 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    function test_depositBatch_MismatchedArrayLengths_Revert() public {
        bytes32 atomId = createSimpleAtom("Mismatched arrays", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomId;
        termIds[1] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(3); // Different length
        uint256[] memory amounts = createUniformArray(10e18, 2);
        uint256[] memory minShares = createUniformArray(1e4, 2);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.depositBatch{ value: 20e18 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    function test_depositBatch_InsufficientMsgValue_Revert() public {
        bytes32 atomId = createSimpleAtom("Insufficient value", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        resetPrank(users.alice);
        vm.expectRevert(); // Will revert due to insufficient payment
        protocol.multiVault.depositBatch{ value: 5e18 }(users.alice, termIds, curveIds, amounts, minShares); // Less
            // than required
    }

    function test_depositBatch_NonExistentTerm_Revert() public {
        bytes32 nonExistentId = keccak256("non-existent");

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = nonExistentId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, nonExistentId));
        protocol.multiVault.depositBatch{ value: 10e18 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    function test_depositBatch_SlippageExceeded_Revert() public {
        bytes32 atomId = createSimpleAtom("Slippage test", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(100e18, 1);
        uint256[] memory minShares = createUniformArray(10_000e18, 1); // Unreasonably high

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        protocol.multiVault.depositBatch{ value: 100e18 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    function test_depositBatch_UnauthorizedSender_Revert() public {
        bytes32 atomId = createSimpleAtom("Unauthorized test", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SenderNotApproved.selector);
        protocol.multiVault.depositBatch{ value: 10e18 }(users.bob, termIds, curveIds, amounts, minShares); // Alice
            // trying to deposit for Bob without approval
    }

    function test_depositBatch_ZeroAssets_Revert() public {
        bytes32 atomId = createSimpleAtom("Zero assets", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(0, 1); // Zero assets
        uint256[] memory minShares = createUniformArray(0, 1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositBelowMinimumDeposit.selector);
        protocol.multiVault.depositBatch{ value: 0 }(users.alice, termIds, curveIds, amounts, minShares);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_depositBatch_MultipleUsersSequential_Success() public {
        string[] memory atomStrings = new string[](2);
        atomStrings[0] = "Multi user 1";
        atomStrings[1] = "Multi user 2";

        uint256[] memory atomCosts = createUniformArray(ATOM_COST[0], 2);
        bytes32[] memory atomIds = createMultipleAtoms(atomStrings, atomCosts, users.alice);

        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory amounts = createUniformArray(8e18, 2);
        uint256[] memory minShares = createUniformArray(1e4, 2);

        // Alice deposits
        uint256[] memory aliceShares = makeDepositBatch(users.alice, users.alice, atomIds, curveIds, amounts, minShares);

        // Bob deposits to same terms
        uint256[] memory bobShares = makeDepositBatch(users.bob, users.bob, atomIds, curveIds, amounts, minShares);

        // Charlie deposits to same terms
        uint256[] memory charlieShares =
            makeDepositBatch(users.charlie, users.charlie, atomIds, curveIds, amounts, minShares);

        // Verify all users received shares
        for (uint256 i = 0; i < 2; i++) {
            assertTrue(aliceShares[i] > 0, "Alice should receive shares");
            assertTrue(bobShares[i] > 0, "Bob should receive shares");
            assertTrue(charlieShares[i] > 0, "Charlie should receive shares");
        }
    }

    function test_depositBatch_DepositAfterBatch_Success() public {
        bytes32 atomId = createSimpleAtom("Batch then single", ATOM_COST[0], users.alice);

        // First do a batch deposit
        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(10e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        uint256[] memory batchShares = makeDepositBatch(users.alice, users.alice, termIds, curveIds, amounts, minShares);

        // Then do a single deposit
        uint256 singleShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 10e18, 1e4);

        uint256 totalBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(totalBalance, batchShares[0] + singleShares, "Total balance should equal sum of all deposits");
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_depositBatch_VerifyBalanceChanges() public {
        bytes32 atomId = createSimpleAtom("Balance verification", ATOM_COST[0], users.alice);

        uint256 balanceBefore = users.alice.balance;

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = atomId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory amounts = createUniformArray(15e18, 1);
        uint256[] memory minShares = createUniformArray(1e4, 1);

        makeDepositBatch(users.alice, users.alice, termIds, curveIds, amounts, minShares);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceBefore - balanceAfter, 15e18, "ETH balance should decrease by deposit amount");
    }
}
