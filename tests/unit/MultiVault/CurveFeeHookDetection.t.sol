// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { MockFeeHookCurve, MockStateDependentFeeCurve } from "tests/mocks/MockFeeHookCurve.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";

/// @title  CurveFeeHookDetectionTest
/// @notice Branch coverage for MultiVault's generic fee-hook dispatch: the vault resolves the
///         curve from the registry by curveId on every deposit/redeem and gates each path on the
///         curve's own {IBaseCurve} hook getters. Uses the instrumented {MockFeeHookCurve} (no
///         caller gate) to isolate the MultiVault-side branches from any real curve's economics:
///         hookless curves get zero hook calls, hook curves get exactly one record per operation
///         (even at zero fee), the two paths gate independently, the forwarded value always equals
///         the pre-state quote, and a curve whose caller gate rejects this MultiVault fails loud.
contract CurveFeeHookDetectionTest is BaseTest {
    uint256 internal constant DEFAULT_CURVE_ID = 1;
    uint256 internal constant MOCK_FEE_BPS = 250;
    uint256 internal constant BPS = 10_000;

    MockFeeHookCurve internal mockHookCurve;
    uint256 internal mockCurveId;

    function setUp() public override {
        super.setUp();
        mockHookCurve = _deployMockCurve("Mock Fee Hook Curve");
        mockCurveId = _register(address(mockHookCurve));
        mockHookCurve.setHooks(true, true);
        mockHookCurve.setFees(MOCK_FEE_BPS, MOCK_FEE_BPS);
    }

    function _deployMockCurve(string memory name) internal returns (MockFeeHookCurve) {
        MockFeeHookCurve impl = new MockFeeHookCurve();
        // The mock deliberately reuses {LinearCurve.initialize} unchanged (it adds no state that
        // needs initializing), and Solidity cannot reference an inherited EXTERNAL function's
        // selector through the derived type — so the parent selector is the precise spelling here.
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl), users.admin, abi.encodeWithSelector(LinearCurve.initialize.selector, name)
        );
        return MockFeeHookCurve(address(proxy));
    }

    function _register(address curve) internal returns (uint256 curveId) {
        resetPrank(users.admin);
        protocol.curveRegistry.addBondingCurve(curve);
        return protocol.curveRegistry.curveIds(curve);
    }

    /// @dev Creates an atom and primes an existing vault on `curveId`, so subsequent measured
    ///      deposits take the steady-state path (no new-vault min-share cost skewing the fee base).
    function _primedAtom(string memory label, uint256 curveId) internal returns (bytes32 atomId) {
        atomId = createSimpleAtom(label, ATOM_COST[0], users.alice);
        makeDeposit(users.alice, users.alice, atomId, curveId, 2e18, 0);
    }

    /* =================================================== */
    /*                  HOOKLESS CURVES                    */
    /* =================================================== */

    function test_defaultCurve_neverTouchesHooks() external {
        bytes32 atomId = _primedAtom("hookless-default", DEFAULT_CURVE_ID);

        uint256 shares = makeDeposit(users.bob, users.bob, atomId, DEFAULT_CURVE_ID, 5e18, 0);
        redeemShares(users.bob, users.bob, atomId, DEFAULT_CURVE_ID, shares / 2, 0);

        assertEq(mockHookCurve.recordDepositCalls(), 0, "hookless path must not record deposits");
        assertEq(mockHookCurve.recordRedeemCalls(), 0, "hookless path must not record redeems");
        assertEq(address(mockHookCurve).balance, 0, "no value forwarded anywhere");
    }

    function test_creationFlows_neverTouchHooks() external {
        createSimpleAtom("hookless-create-atom", ATOM_COST[0], users.alice);
        createTripleWithAtoms("hook-s", "hook-p", "hook-o", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        assertEq(mockHookCurve.recordDepositCalls(), 0, "creation flows must not touch hooks");
        assertEq(address(mockHookCurve).balance, 0, "creation flows must not forward value");
    }

    /* =================================================== */
    /*                    HOOK CURVES                      */
    /* =================================================== */

    function test_hookCurve_deposit_quotesNetsAndRecordsOnce() external {
        bytes32 atomId = _primedAtom("hook-deposit", mockCurveId);
        uint256 callsBefore = mockHookCurve.recordDepositCalls();
        uint256 amount = 8e18;

        // Steady-state deposit: the fee base is the full amount, quoted against pre-deposit state.
        uint256 expectedFee = mockHookCurve.quoteDepositFee(atomId, amount);
        assertEq(expectedFee, (amount * MOCK_FEE_BPS) / BPS, "mock quote sanity");

        (uint256 previewShares,) = protocol.multiVault.previewDeposit(atomId, mockCurveId, amount);
        uint256 curveBalanceBefore = address(mockHookCurve).balance;
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, amount, 0);

        assertEq(shares, previewShares, "preview must reflect the curve fee exactly");
        assertEq(mockHookCurve.recordDepositCalls(), callsBefore + 1, "exactly one record per deposit");
        assertEq(mockHookCurve.lastDepositValue(), expectedFee, "forwarded value == pre-state quote");
        assertEq(address(mockHookCurve).balance - curveBalanceBefore, expectedFee, "curve received the fee");
        assertEq(mockHookCurve.lastTermId(), atomId, "record carries the term");
        assertEq(mockHookCurve.lastAccount(), users.bob, "record carries the receiver");
        assertEq(mockHookCurve.lastShares(), shares, "record carries the minted shares");
    }

    function test_hookCurve_redeem_quotesNetsAndRecordsOnce() external {
        bytes32 atomId = _primedAtom("hook-redeem", mockCurveId);
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, 8e18, 0);

        uint256 toRedeem = shares / 2;
        uint256 grossAssets = protocol.multiVault.convertToAssets(atomId, mockCurveId, toRedeem);
        uint256 expectedFee = mockHookCurve.quoteRedeemFee(atomId, users.bob, grossAssets);
        assertGt(expectedFee, 0, "precondition: non-zero redeem fee");

        (uint256 previewAssets,) = protocol.multiVault.previewRedeem(atomId, mockCurveId, toRedeem);
        uint256 curveBalanceBefore = address(mockHookCurve).balance;
        uint256 receiverBefore = users.bob.balance;
        uint256 assets = redeemShares(users.bob, users.bob, atomId, mockCurveId, toRedeem, 0);

        assertEq(assets, previewAssets, "preview must reflect the curve fee exactly");
        assertEq(users.bob.balance - receiverBefore, assets, "receiver paid the net");
        assertEq(mockHookCurve.recordRedeemCalls(), 1, "exactly one record per redeem");
        assertEq(mockHookCurve.lastRedeemValue(), expectedFee, "forwarded value == pre-state quote");
        assertEq(address(mockHookCurve).balance - curveBalanceBefore, expectedFee, "curve received the fee");
        assertEq(mockHookCurve.lastShares(), toRedeem, "record carries the burned shares");
    }

    function test_hookCurve_zeroFee_recordStillCalledWithZeroValue() external {
        mockHookCurve.setFees(0, 0);
        bytes32 atomId = _primedAtom("hook-zero-fee", mockCurveId);
        uint256 depositCallsBefore = mockHookCurve.recordDepositCalls();

        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, 5e18, 0);
        assertEq(mockHookCurve.recordDepositCalls(), depositCallsBefore + 1, "zero-fee deposit must still record");
        assertEq(mockHookCurve.lastDepositValue(), 0, "zero fee forwards zero value");

        redeemShares(users.bob, users.bob, atomId, mockCurveId, shares / 2, 0);
        assertEq(mockHookCurve.recordRedeemCalls(), 1, "zero-fee redeem must still record");
        assertEq(mockHookCurve.lastRedeemValue(), 0, "zero fee forwards zero value");
        assertEq(address(mockHookCurve).balance, 0, "no value custodied at zero fees");
    }

    /* =================================================== */
    /*                 PER-PATH GATING                     */
    /* =================================================== */

    function test_depositHookOnly_redeemPathStaysCold() external {
        mockHookCurve.setHooks(true, false);
        bytes32 atomId = _primedAtom("hook-deposit-only", mockCurveId);

        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, 5e18, 0);
        assertGt(mockHookCurve.recordDepositCalls(), 0, "deposit hook active");

        redeemShares(users.bob, users.bob, atomId, mockCurveId, shares / 2, 0);
        assertEq(mockHookCurve.recordRedeemCalls(), 0, "redeem path must stay cold");
        assertEq(mockHookCurve.lastRedeemValue(), 0, "no redeem value forwarded");
    }

    function test_redeemHookOnly_depositPathStaysCold() external {
        mockHookCurve.setHooks(false, true);
        bytes32 atomId = _primedAtom("hook-redeem-only", mockCurveId);

        uint256 curveBalanceAfterPriming = address(mockHookCurve).balance;
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, 5e18, 0);
        assertEq(mockHookCurve.recordDepositCalls(), 0, "deposit path must stay cold");
        assertEq(address(mockHookCurve).balance, curveBalanceAfterPriming, "no deposit value forwarded");

        redeemShares(users.bob, users.bob, atomId, mockCurveId, shares / 2, 0);
        assertEq(mockHookCurve.recordRedeemCalls(), 1, "redeem hook active");
        assertGt(mockHookCurve.lastRedeemValue(), 0, "redeem fee forwarded");
    }

    /* =================================================== */
    /*                MULTIPLE HOOK CURVES                 */
    /* =================================================== */

    function test_twoHookCurves_dispatchIndependently() external {
        MockFeeHookCurve secondCurve = _deployMockCurve("Second Mock Fee Hook Curve");
        uint256 secondCurveId = _register(address(secondCurve));
        secondCurve.setHooks(true, true);
        secondCurve.setFees(2 * MOCK_FEE_BPS, 2 * MOCK_FEE_BPS);

        bytes32 atomId = _primedAtom("hook-two-curves", mockCurveId);
        makeDeposit(users.alice, users.alice, atomId, secondCurveId, 2e18, 0);

        uint256 firstCallsBefore = mockHookCurve.recordDepositCalls();
        makeDeposit(users.bob, users.bob, atomId, mockCurveId, 4e18, 0);
        makeDeposit(users.bob, users.bob, atomId, secondCurveId, 4e18, 0);

        assertEq(mockHookCurve.recordDepositCalls(), firstCallsBefore + 1, "first curve records only its own");
        assertEq(mockHookCurve.lastDepositValue(), (4e18 * MOCK_FEE_BPS) / BPS, "first curve fee rate");
        assertEq(secondCurve.lastDepositValue(), (4e18 * 2 * MOCK_FEE_BPS) / BPS, "second curve fee rate");
    }

    /* =================================================== */
    /*                  FAILURE MODES                      */
    /* =================================================== */

    /// @dev A hook curve whose caller gate points at a different MultiVault: previews (view-only
    ///      quotes) succeed, but any deposit fails loud at the record hook. Fail-loud is the
    ///      accepted design for a miswired registration — the registry is append-only and
    ///      admin-vetted, and no funds move on the reverting path.
    function test_miswiredHookCurve_previewSucceedsDepositRevertsLoud() external {
        DynamicFeeFlatPriceCurve miswiredImpl = new DynamicFeeFlatPriceCurve();
        TransparentUpgradeableProxy miswiredProxy = new TransparentUpgradeableProxy(
            address(miswiredImpl),
            users.admin,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector,
                "Miswired Dynamic Fee Curve",
                users.admin,
                makeAddr("wrongMultiVault"),
                _getDefaultDynamicFeeConfig()
            )
        );
        uint256 miswiredCurveId = _register(address(miswiredProxy));

        bytes32 atomId = createSimpleAtom("hook-miswired", ATOM_COST[0], users.alice);

        (uint256 previewShares,) = protocol.multiVault.previewDeposit(atomId, miswiredCurveId, 5e18);
        assertGt(previewShares, 0, "previews (view quotes) succeed on a miswired curve");

        resetPrank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_OnlyMultiVault.selector)
        );
        protocol.multiVault.deposit{ value: 5e18 }(users.bob, atomId, miswiredCurveId, 0);
    }

    /// @dev An unregistered curveId must surface the canonical registry error from the pricing
    ///      call — pinning the resolver's explicit address(0) guard (without it, the hook resolver
    ///      would bare-revert calling a codeless account before the registry check is reached).
    function test_invalidCurveId_revertsWithCanonicalRegistryError() external {
        bytes32 atomId = createSimpleAtom("hook-invalid-id", ATOM_COST[0], users.alice);
        uint256 invalidCurveId = protocol.curveRegistry.count() + 1;

        resetPrank(users.bob);
        vm.expectRevert(abi.encodeWithSignature("BondingCurveRegistry_InvalidCurveId()"));
        protocol.multiVault.deposit{ value: 5e18 }(users.bob, atomId, invalidCurveId, 0);
    }

    /* =================================================== */
    /*                       FUZZ                          */
    /* =================================================== */

    /// @notice What the calc path nets from the depositor must equal what the record path forwards
    ///         to the curve, for any amount and fee rate. Netting is measured against the
    ///         zero-fee counterfactual on identical state (flat 1:1 pricing), forwarding by the
    ///         curve's balance delta.
    function testFuzz_deposit_nettedEqualsForwarded(uint256 amount, uint256 feeBps) external {
        amount = bound(amount, MIN_DEPOSIT, 1000e18);
        feeBps = bound(feeBps, 0, 3000);
        mockHookCurve.setFees(feeBps, 0);

        bytes32 atomId = _primedAtom("hook-fuzz-netted", mockCurveId);

        // Zero-fee counterfactual on identical vault state: shares the same deposit would mint if
        // the curve charged nothing.
        mockHookCurve.setFees(0, 0);
        (uint256 sharesWithoutFee,) = protocol.multiVault.previewDeposit(atomId, mockCurveId, amount);
        mockHookCurve.setFees(feeBps, 0);

        uint256 expectedFee = mockHookCurve.quoteDepositFee(atomId, amount);
        uint256 curveBalanceBefore = address(mockHookCurve).balance;
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, amount, 0);

        uint256 forwarded = address(mockHookCurve).balance - curveBalanceBefore;
        assertEq(forwarded, expectedFee, "forwarded == quote at pre-deposit state");
        assertEq(sharesWithoutFee - shares, forwarded, "netted (1:1 shares delta) == forwarded");
    }

    /// @notice Redeem mirror: the payout shortfall vs the zero-fee counterfactual equals the value
    ///         forwarded to the curve.
    function testFuzz_redeem_nettedEqualsForwarded(uint256 amount, uint256 feeBps) external {
        amount = bound(amount, MIN_DEPOSIT * 2, 1000e18);
        feeBps = bound(feeBps, 0, 3000);
        mockHookCurve.setFees(0, feeBps);

        bytes32 atomId = _primedAtom("hook-fuzz-redeem", mockCurveId);
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, mockCurveId, amount, 0);
        uint256 toRedeem = shares / 2;
        vm.assume(toRedeem > 0);

        mockHookCurve.setFees(0, 0);
        (uint256 assetsWithoutFee,) = protocol.multiVault.previewRedeem(atomId, mockCurveId, toRedeem);
        mockHookCurve.setFees(0, feeBps);

        uint256 curveBalanceBefore = address(mockHookCurve).balance;
        uint256 assets = redeemShares(users.bob, users.bob, atomId, mockCurveId, toRedeem, 0);

        uint256 forwarded = address(mockHookCurve).balance - curveBalanceBefore;
        assertEq(mockHookCurve.lastRedeemValue(), forwarded, "record saw the forwarded value");
        assertEq(assetsWithoutFee - assets, forwarded, "netted payout shortfall == forwarded");
    }

    /* =================================================== */
    /*             STATE-DEPENDENT QUOTES                  */
    /* =================================================== */

    /// @dev A hook curve whose quotes read MULTIVAULT vault totals — state that mutates between the
    ///      calculation and record phases. Because the dispatcher quotes exactly once during
    ///      calculation and carries {curve, fee} to the record call, the forwarded value still
    ///      equals the fee netted from the user; a dispatcher that re-quoted after the vault-state
    ///      writes would forward the post-update (larger) quote here and fail this test.
    function test_stateDependentQuote_deposit_forwardedEqualsCalcQuote() external {
        MockStateDependentFeeCurve stateCurve = _deployStateDependentCurve("State Dependent Fee Curve");
        uint256 stateCurveId = _register(address(stateCurve));
        stateCurve.setProbe(address(protocol.multiVault), stateCurveId);

        bytes32 atomId = createSimpleAtom("hook-state-dep-deposit", ATOM_COST[0], users.alice);
        makeDeposit(users.alice, users.alice, atomId, stateCurveId, 10e18, 0);

        uint256 amount = 8e18;
        uint256 calcQuote = stateCurve.quoteDepositFee(atomId, amount);
        assertGt(calcQuote, 0, "precondition: non-zero state-dependent fee");

        uint256 curveBalanceBefore = address(stateCurve).balance;
        makeDeposit(users.bob, users.bob, atomId, stateCurveId, amount, 0);

        // The vault totals grew during the deposit, so a post-update re-quote would exceed
        // `calcQuote`; the carried quote must be forwarded verbatim.
        assertGt(stateCurve.quoteDepositFee(atomId, amount), calcQuote, "post-state quote must differ (grew)");
        assertEq(address(stateCurve).balance - curveBalanceBefore, calcQuote, "forwarded == calc-time quote");
        assertEq(stateCurve.lastDepositValue(), calcQuote, "record saw the calc-time quote");
    }

    /// @dev Redeem mirror: totals SHRINK between calculation and record, so a re-quoting dispatcher
    ///      would forward less than what was withheld from the redeemer (retaining the difference
    ///      unaccounted in the vault). The carried quote must be forwarded verbatim.
    function test_stateDependentQuote_redeem_forwardedEqualsCalcQuote() external {
        MockStateDependentFeeCurve stateCurve = _deployStateDependentCurve("State Dependent Fee Curve R");
        uint256 stateCurveId = _register(address(stateCurve));
        stateCurve.setProbe(address(protocol.multiVault), stateCurveId);

        bytes32 atomId = createSimpleAtom("hook-state-dep-redeem", ATOM_COST[0], users.alice);
        makeDeposit(users.alice, users.alice, atomId, stateCurveId, 10e18, 0);
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, stateCurveId, 8e18, 0);

        uint256 toRedeem = shares / 2;
        uint256 grossAssets = protocol.multiVault.convertToAssets(atomId, stateCurveId, toRedeem);
        uint256 calcQuote = stateCurve.quoteRedeemFee(atomId, users.bob, grossAssets);
        assertGt(calcQuote, 0, "precondition: non-zero state-dependent fee");

        uint256 curveBalanceBefore = address(stateCurve).balance;
        redeemShares(users.bob, users.bob, atomId, stateCurveId, toRedeem, 0);

        assertLt(
            stateCurve.quoteRedeemFee(atomId, users.bob, grossAssets),
            calcQuote,
            "post-state quote must differ (shrank)"
        );
        assertEq(address(stateCurve).balance - curveBalanceBefore, calcQuote, "forwarded == calc-time quote");
        assertEq(stateCurve.lastRedeemValue(), calcQuote, "record saw the calc-time quote");
    }

    function _deployStateDependentCurve(string memory name) internal returns (MockStateDependentFeeCurve) {
        MockStateDependentFeeCurve impl = new MockStateDependentFeeCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl), users.admin, abi.encodeWithSelector(LinearCurve.initialize.selector, name)
        );
        return MockStateDependentFeeCurve(address(proxy));
    }
}
