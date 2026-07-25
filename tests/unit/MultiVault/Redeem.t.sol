// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

/// @dev Minimal registry mock so _validateRedeem() can run inside a harness.
contract BondingCurveRegistryMock {
    function previewDeposit(
        uint256 assets,
        uint256,
        /*totalAssets*/
        uint256,
        /*totalShares*/
        uint256 /*curveId*/
    )
        external
        pure
        returns (uint256)
    {
        return assets; // 1:1 for tests
    }

    function previewRedeem(
        uint256 shares,
        uint256,
        /*totalShares*/
        uint256,
        /*totalAssets*/
        uint256 /*curveId*/
    )
        external
        pure
        returns (uint256)
    {
        return shares; // 1:1 for tests
    }

    function currentPrice(
        uint256,
        /*supply*/
        uint256 /*curveId*/
    )
        external
        pure
        returns (uint256)
    {
        return 1;
    }

    function getCurveMaxAssets(
        uint256 /*curveId*/
    )
        external
        pure
        returns (uint256)
    {
        return type(uint256).max;
    }
}

/// @dev Test-only harness exposing internal methods and internal storage.
contract MultiVaultHarness is MultiVault {
    // Directly poke balances & totals for a (termId, curveId)
    function setBalanceForTest(bytes32 termId, uint256 curveId, address who, uint256 bal) external {
        _vaults[termId][curveId].balanceOf[who] = bal;
    }

    function setTotalSharesForTest(bytes32 termId, uint256 curveId, uint256 totalShares) external {
        _vaults[termId][curveId].totalShares = totalShares;
    }

    function setMinShareForTest(uint256 minShare) external {
        generalConfig.minShare = minShare;
    }

    function setBondingCurveRegistryForTest(address reg) external {
        bondingCurveConfig.registry = reg;
    }

    function setFeeDenominatorForTest(uint256 den) external {
        generalConfig.feeDenominator = den;
    }

    // Expose the internal functions we want to hit
    function burnForTest(address from, bytes32 termId, uint256 curveId, uint256 amount) external returns (uint256) {
        return _burn(from, termId, curveId, amount);
    }

    function validateRedeemForTest(bytes32 termId, uint256 curveId, address account, uint256 shares, uint256 minAssets)
        external
        view
    {
        _validateRedeem(termId, curveId, account, shares, minAssets);
    }
}

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

        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION);

        uint256 assets = redeemShares(users.bob, users.alice, atomId, CURVE_ID, redeemSharesAmount, 0);

        assertTrue(assets > 0, "Should receive assets");

        uint256 aliceShares = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        uint256 expectedShares = shares - redeemSharesAmount;
        assertApproxEqRel(aliceShares, expectedShares, 1e16, "Alice shares should be reduced");
    }

    /*//////////////////////////////////////////////////////////////
                  NEW ApprovalTypes VALUE COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_redeem_AllowedWith_RedemptionAndCreationApproval() public {
        // REDEMPTION_AND_CREATION = 0b110 must satisfy the REDEMPTION bit.
        bytes32 atomId = createSimpleAtom("rc-allows-redeem", ATOM_COST[0], users.alice);
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1000e18, 0);

        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION_AND_CREATION);

        uint256 assets = redeemShares(users.bob, users.alice, atomId, CURVE_ID, shares / 2, 0);
        assertGt(assets, 0, "REDEMPTION_AND_CREATION must grant redeem");
    }

    function test_redeem_AllowedWith_AllApproval() public {
        // ALL = 0b111 must satisfy REDEMPTION.
        bytes32 atomId = createSimpleAtom("all-allows-redeem", ATOM_COST[0], users.alice);
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1000e18, 0);

        setupApproval(users.alice, users.bob, ApprovalTypes.ALL);

        uint256 assets = redeemShares(users.bob, users.alice, atomId, CURVE_ID, shares / 2, 0);
        assertGt(assets, 0, "ALL must grant redeem");
    }

    function test_redeem_RevertWhen_OnlyCreationApproval() public {
        // CREATION = 0b100 must NOT satisfy REDEMPTION.
        bytes32 atomId = createSimpleAtom("creation-only-blocks-redeem", ATOM_COST[0], users.alice);
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1000e18, 0);

        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_RedeemerNotApproved.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, shares / 2, 0);
    }

    function test_redeem_RevertWhen_OnlyDepositAndCreationApproval() public {
        // DEPOSIT_AND_CREATION = 0b101 has no REDEMPTION bit.
        bytes32 atomId = createSimpleAtom("dc-blocks-redeem", ATOM_COST[0], users.alice);
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1000e18, 0);

        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT_AND_CREATION);

        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_RedeemerNotApproved.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, shares / 2, 0);
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
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, nonExistentId));
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

    function test_redeem_RevertWhen_RedeemerNotApproved() public {
        // Alice creates atom she will receive into
        bytes32 atomId = createSimpleAtom("redeemer-not-approved-atom", ATOM_COST[0], users.alice);

        // Alice deposits into her atom
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);

        uint256 aliceShareBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);

        // Bob tries to redeem from Alice's shares without approval
        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_RedeemerNotApproved.selector);
        protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, aliceShareBalance, 0);
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
        uint256 assets = protocol.multiVault
            .redeem(
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

        uint256 depositAmount = bound(uint256(amt), 10e18, 5000e18);
        uint256 bps = bound(uint256(redeemBps), 1, 10_000);

        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, PROGRESSIVE_CURVE_ID, 0);

        uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        vm.assume(userShares > 1);

        uint256 toRedeem = (userShares * bps) / 10_000;
        if (toRedeem == 0) toRedeem = 1;

        // Leave headroom near full redemption to avoid rounding-up preview > totalAssets.
        uint256 leave = userShares / 1000; // ~0.1%
        if (leave < 2) leave = 2;
        if (toRedeem >= userShares - leave) {
            toRedeem = userShares - leave;
        }

        resetPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, PROGRESSIVE_CURVE_ID, toRedeem, 0);

        assertTrue(received > 0, "Redeem should return assets");
        uint256 remaining = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        assertApproxEqRel(remaining, userShares - toRedeem, 1e16, "Remaining shares should reflect redemption");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE / MIN-SHARE INVARIANT
    //////////////////////////////////////////////////////////////*/

    function test_redeem_Progressive_RedeemAlmostAll_Succeeds_AndLeavesGhostShares() public {
        bytes32 atomId = createSimpleAtom("Progressive redeem-almost-all atom", ATOM_COST[0], users.alice);

        // Deposit on Progressive curve (non-default)
        uint256 depositAmount = 250e18;
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, PROGRESSIVE_CURVE_ID, 0);

        uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        assertTrue(userShares > 2, "need at least 3 shares to test");

        // Non-default curves mint ghost minShares to the burn address.
        uint256 burnSharesBefore = protocol.multiVault.getShares(BURN, atomId, PROGRESSIVE_CURVE_ID);
        assertGt(burnSharesBefore, 0, "ghost shares should exist on non-default curves");

        // Leave headroom so previewRedeem < totalAssets (avoid rounding overflow near total redemption).
        uint256 leave = userShares / 1000; // leave 0.1%
        if (leave < 2) leave = 2;
        uint256 toRedeem = userShares - leave;

        resetPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, PROGRESSIVE_CURVE_ID, toRedeem, 0);
        assertTrue(received > 0, "redeem almost all should succeed");

        uint256 userRemaining = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        assertApproxEqRel(userRemaining, leave, 1e16, "remaining user shares should match leave amount (~1% tol)");

        uint256 burnSharesAfter = protocol.multiVault.getShares(BURN, atomId, PROGRESSIVE_CURVE_ID);
        assertEq(burnSharesAfter, burnSharesBefore, "ghost shares should be unchanged");
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

        // Leave headroom near full redemption to avoid previewRedeem > totalAssets
        uint256 leave = userShares / 1000; // ~0.1%
        if (leave < 2) leave = 2;
        if (toRedeem >= userShares - leave) {
            toRedeem = userShares - leave;
        }

        // Ensure we actually redeem something and stay < userShares
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

    function test_redeem_OffsetProgressive_RedeemAlmostAll_Succeeds_AndLeavesGhostShares() public {
        bytes32 atomId = createSimpleAtom("OffsetProgressive redeem-almost-all atom", ATOM_COST[0], users.alice);

        // Deposit on OffsetProgressive curve (non-default)
        uint256 depositAmount = 350e18;
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, 0);

        uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertTrue(userShares > 2, "need at least 3 shares to test");

        // Ghost minShares exist on non-default curves.
        uint256 burnSharesBefore = protocol.multiVault.getShares(BURN, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertGt(burnSharesBefore, 0, "ghost shares should exist on non-default curves");

        // Leave headroom so previewRedeem < totalAssets (avoid rounding overflow near total redemption).
        uint256 leave = userShares / 1000; // leave 0.1%
        if (leave < 2) leave = 2;
        uint256 toRedeem = userShares - leave;

        resetPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID, toRedeem, 0);
        assertTrue(received > 0, "redeem almost all should succeed");

        uint256 userRemaining = protocol.multiVault.getShares(users.alice, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertApproxEqRel(userRemaining, leave, 1e16, "remaining user shares should match leave amount (~1% tol)");

        uint256 burnSharesAfter = protocol.multiVault.getShares(BURN, atomId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertEq(burnSharesAfter, burnSharesBefore, "ghost shares should be unchanged");
    }

    /*//////////////////////////////////////////////////////////////
        Test unreachable branches in _burn() and _validateRedeem()
    //////////////////////////////////////////////////////////////*/

    function test_redeem_InternalBurn_RevertWhen_InsufficientBalance() public {
        MultiVaultHarness h = new MultiVaultHarness();

        // Craft a fake vault key
        bytes32 termId = keccak256("burn-harness-term");
        uint256 curveId = 123;

        // Give Alice 1e18 shares in that vault, then try burning 2e18.
        h.setBalanceForTest(termId, curveId, users.alice, 1e18);

        vm.expectRevert(MultiVault.MultiVault_BurnInsufficientBalance.selector);
        h.burnForTest(users.alice, termId, curveId, 2e18);
    }

    /*//////////////////////////////////////////////////////////////
                COUNTER-FIRST BOOTSTRAP: 4-COMBINATION REDEEM MATRIX
    //////////////////////////////////////////////////////////////*/

    struct MatrixShares {
        address dan;
        uint256 bobCounterNonDef;
        uint256 charliePosNonDef;
        uint256 danCounterDef;
        uint256 alicePosDef;
    }

    /// @notice After a counter-first bootstrap on a non-default curve, all four
    ///         (positive/counter × default/non-default) vaults must be redeemable by their
    ///         respective depositors. The min-share burn-to-zero seed on both bootstrap-seeded
    ///         vaults must remain unredeemable by anyone other than `BURN`.
    function test_redeem_AfterCounterFirstBootstrap_AllFourCombinationsRedeemable() public {
        (bytes32 tripleId,) = createTripleWithAtoms(
            "S-redeem-matrix", "P-redeem-matrix", "O-redeem-matrix", ATOM_COST[0], TRIPLE_COST[0], users.alice
        );
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        MatrixShares memory s = _seedRedeemMatrix(tripleId, counterId, 3 ether);
        _redeemRedeemMatrix(tripleId, counterId, s);
        _assertSeedsPreservedAfterMatrix(tripleId, counterId);
    }

    /// @dev Seeds the four positive/counter × default/non-default vaults. Returns the share amounts
    ///      and the fresh `dan` address used for the counter-default deposit.
    function _seedRedeemMatrix(bytes32 tripleId, bytes32 counterId, uint256 dep)
        internal
        returns (MatrixShares memory s)
    {
        // 1) Bob: counter-first on non-default curve — previously blocked, now allowed.
        vm.deal(users.bob, dep);
        s.bobCounterNonDef = makeDeposit(users.bob, users.bob, counterId, OFFSET_PROGRESSIVE_CURVE_ID, dep, 0);

        // 2) Charlie: positive-side on the same non-default curve (uses Bob's symmetric seed).
        vm.deal(users.charlie, dep);
        s.charliePosNonDef = makeDeposit(users.charlie, users.charlie, tripleId, OFFSET_PROGRESSIVE_CURVE_ID, dep, 0);

        // 3) Dan (fresh address): counter-side on the default curve (auto-seeded at creation).
        s.dan = makeAddr("dan-redeem-matrix");
        vm.deal(s.dan, dep);
        s.danCounterDef = makeDeposit(s.dan, s.dan, counterId, CURVE_ID, dep, 0);

        // 4) Alice: deposit on positive-default to seed her own redeemable position. {createTripleWithAtoms}
        //    pays exactly `tripleCost`, leaving no post-fee assets for share minting at creation time,
        //    so the redeemable balance is established with an explicit deposit.
        vm.deal(users.alice, dep);
        s.alicePosDef = makeDeposit(users.alice, users.alice, tripleId, CURVE_ID, dep, 0);
        assertGt(s.alicePosDef, 0, "alice positive-default deposit must mint shares");
    }

    function _redeemRedeemMatrix(bytes32 tripleId, bytes32 counterId, MatrixShares memory s) internal {
        assertGt(
            redeemShares(users.alice, users.alice, tripleId, CURVE_ID, s.alicePosDef, 0),
            0,
            "alice positive-default redeem must return assets"
        );
        assertGt(
            redeemShares(s.dan, s.dan, counterId, CURVE_ID, s.danCounterDef, 0),
            0,
            "dan counter-default redeem must return assets"
        );
        assertGt(
            redeemShares(users.charlie, users.charlie, tripleId, OFFSET_PROGRESSIVE_CURVE_ID, s.charliePosNonDef, 0),
            0,
            "charlie positive non-default redeem must return assets"
        );
        assertGt(
            redeemShares(users.bob, users.bob, counterId, OFFSET_PROGRESSIVE_CURVE_ID, s.bobCounterNonDef, 0),
            0,
            "bob counter non-default redeem must return assets"
        );
    }

    function _assertSeedsPreservedAfterMatrix(bytes32 tripleId, bytes32 counterId) internal view {
        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;

        assertEq(protocol.multiVault.getShares(BURN, counterId, CURVE_ID), minShare, "counter-default BURN seed");
        assertEq(
            protocol.multiVault.getShares(BURN, counterId, OFFSET_PROGRESSIVE_CURVE_ID),
            minShare,
            "counter non-default BURN seed"
        );
        assertEq(
            protocol.multiVault.getShares(BURN, tripleId, OFFSET_PROGRESSIVE_CURVE_ID),
            minShare,
            "positive non-default BURN seed (from counter-first bootstrap)"
        );

        assertEq(
            protocol.multiVault.getShares(users.bob, tripleId, OFFSET_PROGRESSIVE_CURVE_ID),
            0,
            "bob holds none of the positive non-default seed"
        );
        assertEq(
            protocol.multiVault.getShares(users.charlie, counterId, OFFSET_PROGRESSIVE_CURVE_ID),
            0,
            "charlie holds none of the counter non-default seed"
        );
    }

    function test_redeem_ValidateRedeem_RevertWhen_InsufficientRemainingShares() public {
        MultiVaultHarness h = new MultiVaultHarness();
        BondingCurveRegistryMock reg = new BondingCurveRegistryMock();
        h.setBondingCurveRegistryForTest(address(reg));

        // Parameters for the crafted case
        bytes32 termId = keccak256("remaining-shares-harness-term");
        uint256 curveId = 77;

        // Choose minShare=100, totalShares=150
        // Ask to redeem shares = 150 - 100 + 1 = 51
        // -> remainingShares = 150 - 51 = 99 < minShare(100) => revert
        uint256 minShare = 100;
        uint256 totalShares = 150;
        uint256 sharesToRedeem = totalShares - minShare + 1; // 51

        // Ensure the account passes the "has enough shares" check
        h.setMinShareForTest(minShare);
        h.setTotalSharesForTest(termId, curveId, totalShares);
        h.setBalanceForTest(termId, curveId, users.alice, sharesToRedeem);
        h.setFeeDenominatorForTest(1e18);

        // Expect the precise custom error with the computed remainingShares = 99
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVault.MultiVault_InsufficientRemainingSharesInVault.selector,
                totalShares - sharesToRedeem // 99
            )
        );
        h.validateRedeemForTest(termId, curveId, users.alice, sharesToRedeem, 0);
    }
}
