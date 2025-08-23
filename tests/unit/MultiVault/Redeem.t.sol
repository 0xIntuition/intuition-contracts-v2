// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVaultErrors } from "src/libraries/MultiVaultErrors.sol";

contract RedeemTest is BaseTest {
    uint256 constant CURVE_ID = 1; // Default linear curve ID
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeem_BasicFunctionality_Success() public {
        bytes32 atomId = createSimpleAtom("Redeem test atom", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 10e18, 1e4);
        uint256 sharesToRedeem = shares / 2;

        uint256 assets = redeemShares(users.alice, users.alice, atomId, CURVE_ID, sharesToRedeem, 1e4);

        assertTrue(assets > 0, "Should receive some assets");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        uint256 expectedRemainingShares = shares - sharesToRedeem;
        assertApproxEqRel(remainingShares, expectedRemainingShares, 1e16, "Should have remaining shares");
    }

    function test_redeem_FullRedemption_Success() public {
        bytes32 atomId = createSimpleAtom("Full redeem atom", ATOM_COST[0], users.alice);

        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 20e18, 0);

        uint256 maxRedeemableShares = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        uint256 assets = redeemShares(users.alice, users.alice, atomId, CURVE_ID, maxRedeemableShares, 0);

        assertTrue(assets > 0, "Should receive assets for full redemption");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(remainingShares, 0, "Should have no redeemable shares remaining");
    }

    function test_redeem_DifferentReceiver_Success() public {
        bytes32 atomId = createSimpleAtom("Different receiver atom", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1500e18, 0);
        uint256 redeemSharesAmount = shares / 2;

        setupApproval(users.alice, users.bob, IMultiVault.ApprovalTypes.REDEMPTION);

        uint256 assets = redeemShares(users.bob, users.alice, atomId, CURVE_ID, redeemSharesAmount, 0);

        assertTrue(assets > 0, "Should receive assets");

        uint256 aliceShares = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        uint256 expectedShares = shares - redeemSharesAmount;
        assertApproxEqRel(aliceShares, expectedShares, 1e16, "Alice shares should be reduced");
    }

    function test_redeem_FromTriple_Success() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("Subject", "Predicate", "Object", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, tripleId, CURVE_ID, 3000e18, 0);
        uint256 redeemSharesAmount = shares / 3;

        uint256 redemptionAssets = redeemShares(users.alice, users.alice, tripleId, CURVE_ID, redeemSharesAmount, 0);

        assertTrue(redemptionAssets > 0, "Should receive assets from triple redemption");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, tripleId, CURVE_ID);
        uint256 expectedRemainingShares = shares - redeemSharesAmount;
        assertApproxEqRel(remainingShares, expectedRemainingShares, 1e16, "Should have correct remaining triple shares");
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_redeem_ZeroShares_Revert() public {
        bytes32 atomId = createSimpleAtom("Zero shares atom", ATOM_COST[0], users.alice);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositOrRedeemZeroShares.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, 0, 0);
    }

    function test_redeem_InsufficientShares_Revert() public {
        bytes32 atomId = createSimpleAtom("Insufficient shares atom", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 100e18, 0);
        uint256 excessiveShares = shares + 1000e18;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientSharesInVault.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, excessiveShares, 0);
    }

    function test_redeem_NonExistentTerm_Revert() public {
        bytes32 nonExistentId = keccak256("non-existent");

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_TermDoesNotExist.selector);
        protocol.multiVault.redeem(users.alice, nonExistentId, CURVE_ID, 1000e18, 0);
    }

    function test_redeem_MinAssetsToReceive_Revert() public {
        bytes32 atomId = createSimpleAtom("Min assets atom", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 100e18, 0);
        uint256 unreasonableMinAssets = 10_000e18;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, shares, unreasonableMinAssets);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeem_DepositRedeemCycle_Success() public {
        bytes32 atomId = createSimpleAtom("Cycle test atom", ATOM_COST[0], users.alice);

        for (uint256 i = 0; i < 3; i++) {
            uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 10e18, 1e4);
            uint256 redeemSharesAmount = shares / 2;
            uint256 assets = redeemShares(users.alice, users.alice, atomId, CURVE_ID, redeemSharesAmount, 1e4);

            assertTrue(shares > 0, "Deposit should always succeed");
            assertTrue(assets > 0, "Redeem should always succeed");
        }
    }
}
