// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";

/// @title  DynamicFeeCurveRoutingTest
/// @notice Integration tests for the flat-price / dynamic-fee curve reached through MultiVault's
///         generic fee-hook dispatch: a single {DynamicFeeFlatPriceCurve} (curveId 4) that both
///         prices the vault and owns the fee economy. There is no MultiVault-side wiring — the vault
///         resolves the curve from the registry on every deposit/redeem and discovers the hooks via
///         the standardized {IBaseCurve} getters. Verifies hook discovery, the flat 1:1 par
///         invariant, the curve's share-ledger mirror, preview honesty, fee custody, claim, and the
///         reinitializer gate.
contract DynamicFeeCurveRoutingTest is BaseTest {
    uint256 internal constant DYNAMIC_CURVE_ID = DYNAMIC_FEE_CURVE_ID;
    uint256 internal constant DEFAULT_CURVE_ID = 1;

    function setUp() public override {
        super.setUp();
        assertEq(protocol.curveRegistry.curveIds(address(dynamicFeeCurve)), DYNAMIC_CURVE_ID, "curveId 4");
    }

    function _atom(string memory label) internal returns (bytes32) {
        return createSimpleAtom(label, ATOM_COST[0], users.alice);
    }

    /* =================================================== */
    /*                   HOOK DISCOVERY                    */
    /* =================================================== */

    function test_hookDiscovery_registryResolvesHookCurve() external view {
        // Registration is the only wiring: the registry resolves the id to the curve, and the curve
        // itself advertises both fee hooks.
        assertEq(
            protocol.curveRegistry.curveAddresses(DYNAMIC_CURVE_ID),
            address(dynamicFeeCurve),
            "registry resolves the hook curve"
        );
        assertTrue(dynamicFeeCurve.hasDepositFeeHook(), "deposit hook advertised");
        assertTrue(dynamicFeeCurve.hasRedeemFeeHook(), "redeem hook advertised");
        assertEq(dynamicFeeCurve.multiVault(), address(protocol.multiVault), "curve knows the MultiVault");
    }

    function test_reinitialize_revertsForNonAdmin() external {
        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", users.alice, bytes32(0))
        );
        protocol.multiVault.reinitialize(users.timelock);
    }

    function test_reinitialize_cannotRunTwice() external {
        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        protocol.multiVault.reinitialize(users.timelock);
    }

    /* =================================================== */
    /*                      DEPOSIT                        */
    /* =================================================== */

    function test_deposit_dynamicCurve_forwardsFeeAndBooksPosition() external {
        bytes32 atomId = _atom("routing-deposit");

        uint256 curveBalanceBefore = address(dynamicFeeCurve).balance;
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, 10e18, 0);

        assertGt(shares, 0, "shares minted on the net");
        assertEq(protocol.multiVault.getShares(users.alice, atomId, DYNAMIC_CURVE_ID), shares, "vault credited");
        // The curve booked the position and received the deposit fee (native).
        assertEq(dynamicFeeCurve.userStake(atomId, users.alice), shares, "curve ledger mirrors the vault shares");
        assertGt(address(dynamicFeeCurve).balance, curveBalanceBefore, "curve received the deposit fee");
        assertGt(dynamicFeeCurve.vaultStake(atomId), 0, "curve tracks cumulative net stake");
    }

    function test_deposit_defaultCurve_leavesDynamicFeeCurveUntouched() external {
        bytes32 atomId = _atom("routing-default");

        uint256 curveBalanceBefore = address(dynamicFeeCurve).balance;
        makeDeposit(users.alice, users.alice, atomId, DEFAULT_CURVE_ID, 10e18, 0);

        assertEq(dynamicFeeCurve.userStake(atomId, users.alice), 0, "default-curve deposit does not touch the curve");
        assertEq(dynamicFeeCurve.vaultStake(atomId), 0, "no dynamic-fee accounting for the default curve");
        assertEq(address(dynamicFeeCurve).balance, curveBalanceBefore, "no fee forwarded for the default curve");
    }

    function test_previewDeposit_matchesActual_dynamicCurve() external {
        bytes32 atomId = _atom("routing-preview");

        (uint256 previewShares,) = protocol.multiVault.previewDeposit(atomId, DYNAMIC_CURVE_ID, 7e18);
        uint256 actualShares = makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, 7e18, 0);

        assertEq(actualShares, previewShares, "preview reflects the dynamic fee exactly");
    }

    /* =================================================== */
    /*                    PAR INVARIANT                    */
    /* =================================================== */

    function test_parInvariant_dynamicVaultStaysOneToOne() external {
        bytes32 atomId = _atom("routing-par");

        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, 8e18, 0);
        _assertPar(atomId);

        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, 6e18, 0);
        _assertPar(atomId);

        uint256 aliceShares = protocol.multiVault.getShares(users.alice, atomId, DYNAMIC_CURVE_ID);
        redeemShares(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, aliceShares / 2, 0);
        _assertPar(atomId);
    }

    function testFuzz_parInvariant_afterDepositRedeemSequence(uint256 aliceAmt, uint256 bobAmt, uint256 redeemPct)
        external
    {
        aliceAmt = bound(aliceAmt, 1e18, 5000e18);
        bobAmt = bound(bobAmt, 1e18, 5000e18);
        redeemPct = bound(redeemPct, 1, 100);

        bytes32 atomId = _atom("routing-par-fuzz");

        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, aliceAmt, 0);
        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, bobAmt, 0);
        _assertPar(atomId);

        // Mirror invariant: the curve's per-user stake equals the vault share balance.
        assertEq(
            dynamicFeeCurve.userStake(atomId, users.alice),
            protocol.multiVault.getShares(users.alice, atomId, DYNAMIC_CURVE_ID),
            "alice ledger mirror"
        );

        uint256 bobShares = protocol.multiVault.getShares(users.bob, atomId, DYNAMIC_CURVE_ID);
        uint256 toRedeem = (bobShares * redeemPct) / 100;
        if (toRedeem > 0 && bobShares - toRedeem >= MIN_SHARES) {
            redeemShares(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, toRedeem, 0);
            _assertPar(atomId);
            assertEq(
                dynamicFeeCurve.userStake(atomId, users.bob),
                protocol.multiVault.getShares(users.bob, atomId, DYNAMIC_CURVE_ID),
                "bob ledger mirror after redeem"
            );
        }
    }

    function _assertPar(bytes32 atomId) internal view {
        (uint256 totalAssets, uint256 totalShares) = protocol.multiVault.getVault(atomId, DYNAMIC_CURVE_ID);
        assertEq(totalAssets, totalShares, "dynamic vault must stay exactly 1:1 (flat par)");
    }

    /* =================================================== */
    /*                      REDEEM                         */
    /* =================================================== */

    function test_redeem_dynamicCurve_forwardsRedeemFee() external {
        bytes32 atomId = _atom("routing-redeem");

        // Two holders so the exiting tier has a residual recipient for the redeem fee.
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, 8e18, 0);
        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, 8e18, 0);

        uint256 curveBalanceBefore = address(dynamicFeeCurve).balance;
        uint256 receiverBefore = users.bob.balance;

        uint256 bobShares = protocol.multiVault.getShares(users.bob, atomId, DYNAMIC_CURVE_ID);
        uint256 assets = redeemShares(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, bobShares / 2, 0);

        assertGt(assets, 0, "receiver got net proceeds");
        assertEq(users.bob.balance - receiverBefore, assets, "receiver paid the net");
        assertGt(address(dynamicFeeCurve).balance, curveBalanceBefore, "curve received the redeem fee");
    }

    /* =================================================== */
    /*                       CLAIM                         */
    /* =================================================== */

    function test_claim_afterRealDeposits_paysEarlierTier() external {
        bytes32 atomId = _atom("routing-claim");

        // alice enters at tier 0 and pushes the vault into a higher tier; bob then deposits from that
        // tier, so alice's tier receives part of bob's deposit fee.
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_CURVE_ID, 8e18, 0);
        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_CURVE_ID, 4e18, 0);

        uint256 earned = dynamicFeeCurve.claimable(users.alice, atomId);
        assertGt(earned, 0, "alice earned from bob's deposit fee");

        bytes32[] memory terms = new bytes32[](1);
        terms[0] = atomId;

        uint256 balBefore = users.alice.balance;
        resetPrank(users.alice);
        uint256 claimed = dynamicFeeCurve.claim(terms);

        assertEq(claimed, earned, "claim pays the earned amount");
        assertEq(users.alice.balance - balBefore, claimed, "alice received native TRUST");
        assertEq(dynamicFeeCurve.claimable(users.alice, atomId), 0, "claimable cleared");
    }
}
