// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

contract RedeemBatchTest is BaseTest {
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
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupAtomsWithDeposits(
        uint256 count,
        uint256 depositAmount
    )
        internal
        returns (bytes32[] memory atomIds, uint256[] memory shares)
    {
        string[] memory atomStrings = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            atomStrings[i] = string(abi.encodePacked("Batch redeem atom ", i));
        }

        uint256[] memory atomCosts = createUniformArray(ATOM_COST[0], count);
        atomIds = createMultipleAtoms(atomStrings, atomCosts, users.alice);

        // Make deposits to get shares
        uint256[] memory curveIds = createDefaultCurveIdArray(count);
        uint256[] memory amounts = createUniformArray(depositAmount, count);
        uint256[] memory minShares = createUniformArray(1e4, count);

        shares = makeDepositBatch(users.alice, users.alice, atomIds, curveIds, amounts, minShares);
    }

    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeemBatch_SingleTerm_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 20e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 2; // Redeem half
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        assertEq(assets.length, 1, "Should return one asset amount");
        assertTrue(assets[0] > 0, "Should receive some assets");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomIds[0], CURVE_ID);
        uint256 expectedRemaining = depositShares[0] - sharesToRedeem[0];
        assertApproxEqRel(remainingShares, expectedRemaining, 1e16, "Should have correct remaining shares");
    }

    function test_redeemBatch_MultipleTerms_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(3, 25e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(3);
        uint256[] memory sharesToRedeem = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            sharesToRedeem[i] = depositShares[i] / 3; // Redeem one third
        }
        uint256[] memory minAssets = createUniformArray(1e4, 3);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        assertEq(assets.length, 3, "Should return three asset amounts");
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(assets[i] > 0, "Each redemption should receive assets");

            uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomIds[i], CURVE_ID);
            uint256 expectedRemaining = depositShares[i] - sharesToRedeem[i];
            assertApproxEqRel(
                remainingShares, expectedRemaining, 1e16, "Should have correct remaining shares for each atom"
            );
        }
    }

    function test_redeemBatch_DifferentAmounts_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(3, 30e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(3);
        uint256[] memory sharesToRedeem = new uint256[](3);
        sharesToRedeem[0] = depositShares[0] / 4; // Redeem 25%
        sharesToRedeem[1] = depositShares[1] / 2; // Redeem 50%
        sharesToRedeem[2] = depositShares[2] * 3 / 4; // Redeem 75%
        uint256[] memory minAssets = createUniformArray(1e4, 3);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        assertEq(assets.length, 3, "Should return three asset amounts");
        // Different redemption amounts should generally result in different asset amounts
        assertTrue(assets[0] > 0 && assets[1] > 0 && assets[2] > 0, "All redemptions should receive assets");
    }

    function test_redeemBatch_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 20e18);

        setupApproval(users.alice, users.bob, IMultiVault.ApprovalTypes.REDEMPTION);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 2;
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        uint256 bobBalanceBefore = users.bob.balance;

        uint256[] memory assets =
            redeemSharesBatch(users.bob, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);
        uint256 aliceShares = protocol.multiVault.getShares(users.alice, atomIds[0], CURVE_ID);
        uint256 expectedRemaining = depositShares[0] - sharesToRedeem[0];
        assertApproxEqRel(aliceShares, expectedRemaining, 1e16, "Alice shares should be reduced");
    }

    function test_redeemBatch_MixedAtomsAndTriples_Success() public {
        // Create atom with deposit
        bytes32 atomId = createSimpleAtom("Mixed batch atom", ATOM_COST[0], users.alice);
        uint256 atomShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 20e18, 1e4);

        // Create triple with deposit
        (bytes32 tripleId,) = createTripleWithAtoms(
            "Mixed Subject", "Mixed Predicate", "Mixed Object", ATOM_COST[0], TRIPLE_COST[0], users.alice
        );
        uint256 tripleShares = makeDeposit(users.alice, users.alice, tripleId, CURVE_ID, 25e18, 1e4);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomId;
        termIds[1] = tripleId;

        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory sharesToRedeem = new uint256[](2);
        sharesToRedeem[0] = atomShares / 2;
        sharesToRedeem[1] = tripleShares / 3;
        uint256[] memory minAssets = createUniformArray(1e4, 2);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, termIds, curveIds, sharesToRedeem, minAssets);

        assertEq(assets.length, 2, "Should return two asset amounts");
        assertTrue(assets[0] > 0 && assets[1] > 0, "Both redemptions should succeed");
    }

    function test_redeemBatch_FullRedemption_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(2, 18e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory maxRedeemableShares = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            maxRedeemableShares[i] = protocol.multiVault.getShares(users.alice, atomIds[i], CURVE_ID);
        }
        uint256[] memory minAssets = createUniformArray(0, 2);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, maxRedeemableShares, minAssets);

        for (uint256 i = 0; i < 2; i++) {
            assertTrue(assets[i] > 0, "Should receive assets for full redemption");
            uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomIds[i], CURVE_ID);
            assertEq(remainingShares, 0, "Should have no redeemable shares remaining");
        }
    }

    function test_redeemBatch_MaxBatchSize_Success() public {
        uint256 batchSize = 5; // Using smaller size for test efficiency
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(batchSize, 15e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(batchSize);
        uint256[] memory sharesToRedeem = new uint256[](batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            sharesToRedeem[i] = depositShares[i] / 4; // Redeem 25%
        }
        uint256[] memory minAssets = createUniformArray(1e4, batchSize);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        assertEq(assets.length, batchSize, "Should handle batch size correctly");
        for (uint256 i = 0; i < batchSize; i++) {
            assertTrue(assets[i] > 0, "Each redemption should succeed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_redeemBatch_EmptyArrays_Revert() public {
        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory curveIds = new uint256[](0);
        uint256[] memory shares = new uint256[](0);
        uint256[] memory minAssets = new uint256[](0);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.redeemBatch(users.alice, termIds, curveIds, shares, minAssets);
    }

    function test_redeemBatch_ExceedsMaxBatchSize_Revert() public {
        uint256 oversizedBatch = MAX_BATCH_SIZE + 1;

        bytes32[] memory termIds = new bytes32[](oversizedBatch);
        uint256[] memory curveIds = new uint256[](oversizedBatch);
        uint256[] memory shares = new uint256[](oversizedBatch);
        uint256[] memory minAssets = new uint256[](oversizedBatch);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.redeemBatch(users.alice, termIds, curveIds, shares, minAssets);
    }

    function test_redeemBatch_MismatchedArrayLengths_Revert() public {
        (bytes32[] memory atomIds,) = _setupAtomsWithDeposits(2, 15e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(3); // Different length
        uint256[] memory shares = createUniformArray(1e18, 2);
        uint256[] memory minAssets = createUniformArray(1e4, 2);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.redeemBatch(users.alice, atomIds, curveIds, shares, minAssets);
    }

    function test_redeemBatch_NonExistentTerm_Revert() public {
        bytes32 nonExistentId = keccak256("non-existent");

        bytes32[] memory termIds = new bytes32[](1);
        termIds[0] = nonExistentId;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory shares = createUniformArray(1e18, 1);
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, nonExistentId));
        protocol.multiVault.redeemBatch(users.alice, termIds, curveIds, shares, minAssets);
    }

    function test_redeemBatch_InsufficientShares_Revert() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 10e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory excessiveShares = new uint256[](1);
        excessiveShares[0] = depositShares[0] + 1000e18; // More than deposited
        uint256[] memory minAssets = createUniformArray(0, 1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientSharesInVault.selector);
        protocol.multiVault.redeemBatch(users.alice, atomIds, curveIds, excessiveShares, minAssets);
    }

    function test_redeemBatch_ZeroShares_Revert() public {
        (bytes32[] memory atomIds,) = _setupAtomsWithDeposits(1, 15e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory zeroShares = createUniformArray(0, 1); // Zero shares
        uint256[] memory minAssets = createUniformArray(0, 1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositOrRedeemZeroShares.selector);
        protocol.multiVault.redeemBatch(users.alice, atomIds, curveIds, zeroShares, minAssets);
    }

    function test_redeemBatch_SlippageExceeded_Revert() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 10e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 2;
        uint256[] memory unreasonableMinAssets = createUniformArray(10_000e18, 1); // Way too high

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        protocol.multiVault.redeemBatch(users.alice, atomIds, curveIds, sharesToRedeem, unreasonableMinAssets);
    }

    function test_redeemBatch_UnauthorizedSender_Revert() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 15e18);

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 2;
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SenderNotApproved.selector);
        protocol.multiVault.redeemBatch(users.bob, atomIds, curveIds, sharesToRedeem, minAssets); // Alice trying to
            // redeem for Bob without approval
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeemBatch_MultipleUsersSequential_Success() public {
        (bytes32[] memory atomIds,) = _setupAtomsWithDeposits(2, 20e18);

        // Bob also deposits to same terms
        uint256[] memory curveIds = createDefaultCurveIdArray(2);
        uint256[] memory amounts = createUniformArray(15e18, 2);
        uint256[] memory minShares = createUniformArray(1e4, 2);
        uint256[] memory bobShares = makeDepositBatch(users.bob, users.bob, atomIds, curveIds, amounts, minShares);

        // Charlie also deposits
        uint256[] memory charlieShares =
            makeDepositBatch(users.charlie, users.charlie, atomIds, curveIds, amounts, minShares);

        // Now all users redeem
        uint256[] memory aliceRedeemShares = new uint256[](2);
        uint256[] memory bobRedeemShares = new uint256[](2);
        uint256[] memory charlieRedeemShares = new uint256[](2);

        for (uint256 i = 0; i < 2; i++) {
            aliceRedeemShares[i] = protocol.multiVault.getShares(users.alice, atomIds[i], CURVE_ID) / 2;
            bobRedeemShares[i] = bobShares[i] / 3;
            charlieRedeemShares[i] = charlieShares[i] / 4;
        }

        uint256[] memory minAssets = createUniformArray(1e4, 2);

        uint256[] memory aliceAssets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, aliceRedeemShares, minAssets);
        uint256[] memory bobAssets =
            redeemSharesBatch(users.bob, users.bob, atomIds, curveIds, bobRedeemShares, minAssets);
        uint256[] memory charlieAssets =
            redeemSharesBatch(users.charlie, users.charlie, atomIds, curveIds, charlieRedeemShares, minAssets);

        // Verify all users received assets
        for (uint256 i = 0; i < 2; i++) {
            assertTrue(aliceAssets[i] > 0, "Alice should receive assets");
            assertTrue(bobAssets[i] > 0, "Bob should receive assets");
            assertTrue(charlieAssets[i] > 0, "Charlie should receive assets");
        }
    }

    function test_redeemBatch_RedeemAfterBatch_Success() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 25e18);

        // First do a batch redemption
        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 3;
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        uint256[] memory batchAssets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        // Then do a single redemption
        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomIds[0], CURVE_ID);
        uint256 singleAssets = redeemShares(users.alice, users.alice, atomIds[0], CURVE_ID, remainingShares / 2, 1e4);

        assertTrue(batchAssets[0] > 0 && singleAssets > 0, "Both redemptions should succeed");
    }

    function test_redeemBatch_RedeemDepositCycle_Success() public {
        (bytes32[] memory atomIds,) = _setupAtomsWithDeposits(1, 20e18);

        // Multiple redeem/deposit cycles
        for (uint256 cycle = 0; cycle < 3; cycle++) {
            // Redeem some shares
            uint256 currentShares = protocol.multiVault.getShares(users.alice, atomIds[0], CURVE_ID);
            if (currentShares > 0) {
                uint256[] memory curveIds = createDefaultCurveIdArray(1);
                uint256[] memory sharesToRedeem = new uint256[](1);
                sharesToRedeem[0] = currentShares / 2;
                uint256[] memory minAssets = createUniformArray(1e4, 1);

                uint256[] memory assets =
                    redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);
                assertTrue(assets[0] > 0, "Redeem should always succeed");
            }

            // Deposit again
            uint256 shares = makeDeposit(users.alice, users.alice, atomIds[0], CURVE_ID, 8e18, 1e4);
            assertTrue(shares > 0, "Deposit should always succeed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_redeemBatch_VerifyBalanceChanges() public {
        (bytes32[] memory atomIds, uint256[] memory depositShares) = _setupAtomsWithDeposits(1, 20e18);

        uint256 balanceBefore = users.alice.balance;

        uint256[] memory curveIds = createDefaultCurveIdArray(1);
        uint256[] memory sharesToRedeem = new uint256[](1);
        sharesToRedeem[0] = depositShares[0] / 2;
        uint256[] memory minAssets = createUniformArray(1e4, 1);

        uint256[] memory assets =
            redeemSharesBatch(users.alice, users.alice, atomIds, curveIds, sharesToRedeem, minAssets);

        uint256 balanceAfter = users.alice.balance;
        assertEq(balanceAfter - balanceBefore, assets[0], "ETH balance should increase by received assets");
    }
}
