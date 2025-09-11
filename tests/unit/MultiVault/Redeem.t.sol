// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

contract RedeemTest is BaseTest {
    uint256 constant CURVE_ID = 1; // Default linear curve ID
    uint256 constant OFFSET_PROGRESSIVE_CURVE_ID = 2;
    uint256 constant PROGRESSIVE_CURVE_ID = 3;
    address constant BURN = address(0x000000000000000000000000000000000000dEaD);

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

    /*//////////////////////////////////////////////////////////////
                            PROGRESSIVE CURVE TESTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeem_Progressive_BasicFunctionality_Success() public {
        // Create atom on default curve (creation enforces default)
        bytes32 atomId = createSimpleAtom("Progressive redeem atom", ATOM_COST[0], users.alice);

        // Deposit on Progressive curve directly using protocol method
        uint256 depositAmount = 500e18;
        resetPrank(users.alice);
        uint256 preShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);

        protocol.multiVault.deposit{ value: depositAmount }(
            users.alice, // receiver
            atomId,
            PROGRESSIVE_CURVE_ID,
            0 // minShares
        );

        uint256 shares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        assertTrue(shares > preShares, "Deposit should mint shares on progressive curve");

        // Redeem half
        uint256 sharesToRedeem = shares / 2;
        resetPrank(users.alice);
        uint256 assets = protocol.multiVault.redeem(
            users.alice, // receiver
            atomId,
            PROGRESSIVE_CURVE_ID,
            sharesToRedeem,
            0 // minAssets
        );

        assertTrue(assets > 0, "Should receive some assets");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        uint256 expectedRemainingShares = shares - sharesToRedeem;
        assertApproxEqRel(remainingShares, expectedRemainingShares, 1e16, "Should have remaining shares");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_redeem_Progressive_DepositThenRedeem(uint96 amt, uint16 redeemBps) public {
        bytes32 atomId = createSimpleAtom("Progressive fuzz atom", ATOM_COST[0], users.alice);

        // Bound deposit and redeem inputs
        uint256 depositAmount = bound(uint256(amt), 10e18, 5000e18); // keep well above minDeposit and within sane range
        uint256 bps = bound(uint256(redeemBps), 1, 10_000);

        // Deposit
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, PROGRESSIVE_CURVE_ID, 0);

        uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        // Ensure we have redeemable shares
        vm.assume(userShares > 1);

        uint256 toRedeem = (userShares * bps) / 10_000;
        // Make sure at least 1 share to exercise the path
        if (toRedeem == 0) toRedeem = 1;
        if (toRedeem >= userShares) toRedeem = userShares - 1; // avoid hitting the minShare floor revert here

        // Redeem
        resetPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, PROGRESSIVE_CURVE_ID, toRedeem, 0);

        assertTrue(received > 0, "Redeem should return assets");
        uint256 remaining = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        assertApproxEqRel(remaining, userShares - toRedeem, 1e16, "Remaining shares should reflect redemption");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE / MIN-SHARE INVARIANT
    //////////////////////////////////////////////////////////////*/

    function test_redeem_Progressive_RedeemAll_Reverts_InsufficientRemainingShares() public {
        bytes32 atomId = createSimpleAtom("Progressive redeem-all atom", ATOM_COST[0], users.alice);

        // Deposit on Progressive curve
        uint256 depositAmount = 250e18;
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, PROGRESSIVE_CURVE_ID, 0);

        uint256 maxRedeemable = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);

        // On non-default curves, ghost shares are NOT minted. Redeeming all drops below minShare -> revert.
        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InsufficientRemainingSharesInVault.selector, 0));
        protocol.multiVault.redeem(users.alice, atomId, PROGRESSIVE_CURVE_ID, maxRedeemable, 0);

        // Sanity: burn address should have 0 shares on this non-default curve
        uint256 burnShares = protocol.multiVault.getShares(BURN, atomId, PROGRESSIVE_CURVE_ID);
        assertEq(burnShares, 0, "No ghost shares are minted for non-default curves");
    }

    /*//////////////////////////////////////////////////////////////
                            OFFSET PROGRESSIVE CURVE TESTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeem_OffsetProgressive_BasicFunctionality_Success() public {
        bytes32 atomId = createSimpleAtom("OffsetProgressive redeem atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 600e18;
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, 0);

        uint256 shares = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertTrue(shares > 0, "Deposit should mint shares on offset progressive curve");

        uint256 sharesToRedeem = shares / 3;
        resetPrank(users.alice);
        uint256 assets = protocol.multiVault.redeem(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, sharesToRedeem, 0);

        assertTrue(assets > 0, "Should receive some assets");

        uint256 remainingShares = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        uint256 expectedRemainingShares = shares - sharesToRedeem;
        assertApproxEqRel(remainingShares, expectedRemainingShares, 1e16, "Should have remaining shares");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_redeem_OffsetProgressive_DepositThenRedeem(uint96 amt, uint16 redeemBps) public {
        bytes32 atomId = createSimpleAtom("OffsetProgressive fuzz atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = bound(uint256(amt), 10e18, 5000e18);
        uint256 bps = bound(uint256(redeemBps), 1, 10_000);

        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, 0);

        uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        vm.assume(userShares > 1);

        uint256 toRedeem = (userShares * bps) / 10_000;
        if (toRedeem == 0) toRedeem = 1;
        if (toRedeem >= userShares) toRedeem = userShares - 1;

        resetPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, toRedeem, 0);

        assertTrue(received > 0, "Redeem should return assets");
        uint256 remaining = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertApproxEqRel(remaining, userShares - toRedeem, 1e16, "Remaining shares should reflect redemption");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE / MIN-SHARE INVARIANT
    //////////////////////////////////////////////////////////////*/

    function test_redeem_OffsetProgressive_RedeemAll_Reverts_InsufficientRemainingShares() public {
        bytes32 atomId = createSimpleAtom("OffsetProgressive redeem-all atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 350e18;
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, 0);

        uint256 maxRedeemable = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_InsufficientRemainingSharesInVault.selector, 0));
        protocol.multiVault.redeem(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, maxRedeemable, 0);

        uint256 burnShares = protocol.multiVault.getShares(BURN, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertEq(burnShares, 0, "No ghost shares are minted for non-default curves");
    }
}
