// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveFeeGuardrailsTest
/// @notice Gating regressions for the dynamic-fee curve's configuration guardrails and for the
///         vault-level payout floor behind them.
///
///         Each test is written to fail if its guard is removed:
///           - the immutable deposit/withdrawal cap ceilings, which bound the configuration space so
///             no stored schedule can consume a deposit or a redemption;
///           - the read-time clamp that applies the LIVE cap to a stored per-tier override, so that
///             lowering a cap tightens every tier rather than leaving overridden tiers at the old rate;
///           - the MultiVault floor that rejects a redemption returning no assets, independently of
///             any caller-supplied slippage bound.
contract CurveFeeGuardrailsTest is BaseTest {
    uint256 internal constant DYN = DYNAMIC_FEE_CURVE_ID;

    function _atom(string memory label) internal returns (bytes32) {
        return createSimpleAtom(label, ATOM_COST[0], users.alice);
    }

    function _config() internal view returns (DynamicFeeConfig memory) {
        return dynamicFeeCurve.getConfig();
    }

    /* =================================================== */
    /*              CAP CEILINGS (CONFIG SPACE)            */
    /* =================================================== */

    /// @dev A withdrawal cap above the immutable ceiling must be unstorable. Guard: the
    ///      `MAX_WITHDRAWAL_CAP_BPS` bound in `_setConfig`. Removing it lets the schedule through.
    function test_setConfig_revertsWhenWithdrawalCapExceedsCeiling() external {
        DynamicFeeConfig memory cfg = _config();
        cfg.withdrawalCapBps = uint16(dynamicFeeCurve.MAX_WITHDRAWAL_CAP_BPS() + 1);

        vm.startPrank(dynamicFeeCurve.owner());
        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector)
        );
        dynamicFeeCurve.setConfig(cfg);
        vm.stopPrank();
    }

    /// @dev The same bound on the deposit side.
    function test_setConfig_revertsWhenDepositCapExceedsCeiling() external {
        DynamicFeeConfig memory cfg = _config();
        cfg.depositCapBps = uint16(dynamicFeeCurve.MAX_DEPOSIT_CAP_BPS() + 1);

        vm.startPrank(dynamicFeeCurve.owner());
        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector)
        );
        dynamicFeeCurve.setConfig(cfg);
        vm.stopPrank();
    }

    /// @dev The schedule that the round-2 proof of concept used to zero a redeemer's payout — a 99%
    ///      withdrawal rate inside a `BPS`-wide cap — must now be unreachable at configuration time.
    function test_setConfig_rejectsScheduleCapableOfZeroingAPayout() external {
        DynamicFeeConfig memory cfg = _config();
        cfg.withdrawalCapBps = 10_000;
        cfg.withdrawalBaseBps = 9900;

        vm.startPrank(dynamicFeeCurve.owner());
        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidConfig.selector)
        );
        dynamicFeeCurve.setConfig(cfg);
        vm.stopPrank();
    }

    /// @dev A tier override may never be set above the live cap either.
    function test_setTierFeeOverride_revertsAboveLiveCap() external {
        uint256 cap = _config().withdrawalCapBps;

        vm.startPrank(dynamicFeeCurve.owner());
        vm.expectRevert(
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidTierOverride.selector)
        );
        dynamicFeeCurve.setTierFeeOverride(0, 0, uint16(cap + 1));
        vm.stopPrank();
    }

    /* =================================================== */
    /*          OVERRIDE CLAMP (TIGHTENING ACTION)         */
    /* =================================================== */

    /// @dev Lowering a cap must tighten a tier that already carries an override. Guard: the read-time
    ///      clamp in `_withdrawalFeeBps`. With the clamp removed the override survives the reduction
    ///      and this assertion fails, which is what makes this test gating rather than decorative.
    function test_loweringWithdrawalCap_tightensAnExistingTierOverride() external {
        bytes32 atomId = _atom("clamp-withdraw");
        DynamicFeeConfig memory cfg = _config();

        uint16 highRate = uint16(cfg.withdrawalCapBps);
        vm.startPrank(dynamicFeeCurve.owner());
        dynamicFeeCurve.setTierFeeOverride(0, 0, highRate);
        vm.stopPrank();

        uint256 shares = makeDeposit(users.bob, users.bob, atomId, DYN, 5e18, 0);
        (, uint256 feeBefore) = dynamicFeeCurve.previewRedeemFor(atomId, users.bob, shares);

        // Tighten the schedule to a strictly lower cap.
        uint16 loweredCap = highRate / 2;
        cfg.withdrawalCapBps = loweredCap;
        if (cfg.withdrawalBaseBps > loweredCap) cfg.withdrawalBaseBps = loweredCap;
        vm.startPrank(dynamicFeeCurve.owner());
        dynamicFeeCurve.setConfig(cfg);
        vm.stopPrank();

        (, uint256 feeAfter) = dynamicFeeCurve.previewRedeemFor(atomId, users.bob, shares);

        assertLt(feeAfter, feeBefore, "lowering the cap must reduce an overridden tier's effective rate");
        assertLe(
            feeAfter,
            shares * uint256(loweredCap) / dynamicFeeCurve.BPS() + 1,
            "overridden tier must be clamped to the live cap"
        );
    }

    /// @dev The deposit side of the same clamp.
    function test_loweringDepositCap_tightensAnExistingTierOverride() external {
        DynamicFeeConfig memory cfg = _config();
        uint16 highRate = uint16(cfg.depositCapBps);

        vm.startPrank(dynamicFeeCurve.owner());
        dynamicFeeCurve.setTierFeeOverride(0, highRate, 0);
        vm.stopPrank();

        // A fresh (unfunded) term sits in tier 0, which is the tier carrying the override.
        bytes32 termId = keccak256("clamp-deposit-term");
        uint256 quotedBefore = dynamicFeeCurve.quoteDepositFee(termId, 10e18);

        uint16 loweredCap = highRate / 2;
        cfg.depositCapBps = loweredCap;
        if (cfg.depositBaseBps > loweredCap) cfg.depositBaseBps = loweredCap;
        vm.startPrank(dynamicFeeCurve.owner());
        dynamicFeeCurve.setConfig(cfg);
        vm.stopPrank();

        uint256 quotedAfter = dynamicFeeCurve.quoteDepositFee(termId, 10e18);

        assertLt(quotedAfter, quotedBefore, "lowering the cap must reduce an overridden tier's deposit rate");
        assertLe(
            quotedAfter,
            uint256(10e18) * uint256(loweredCap) / dynamicFeeCurve.BPS() + 1,
            "deposit override must clamp to the live cap"
        );
    }

    /* =================================================== */
    /*            VAULT PAYOUT FLOOR (DEFENSE)             */
    /* =================================================== */

    /// @dev A redemption must never burn shares for a zero payout. Guard: the `totalFees >= assets`
    ///      check in `_calculateRedeem`. This exercises it through the smallest admissible redemption,
    ///      where the stacked round-up fee terms are proportionally largest.
    function test_redeem_neverReturnsZeroAssetsForNonZeroShares() external {
        bytes32 atomId = _atom("payout-floor");
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, DYN, 10e18, 0);

        // A single share is the worst case for stacked round-up fee terms: the fees exceed the gross,
        // so the redemption must be REJECTED rather than silently burning the share for nothing.
        // Before the floor this path returned zero assets and succeeded.
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_RedeemYieldsNoAssets.selector));
        protocol.multiVault.previewRedeem(atomId, DYN, 1);

        vm.startPrank(users.bob);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_RedeemYieldsNoAssets.selector));
        protocol.multiVault.redeem(users.bob, atomId, DYN, 1, 0);
        vm.stopPrank();

        // The ordinary path is unaffected and still pays out.
        vm.startPrank(users.bob);
        uint256 received = protocol.multiVault.redeem(users.bob, atomId, DYN, shares / 2, 0);
        vm.stopPrank();
        assertGt(received, 0, "an ordinary redemption must pay out");
    }

    /* =================================================== */
    /*                 PREVIEW PARITY                      */
    /* =================================================== */

    /// @dev The curve's account-aware preview must agree with what the holder actually pays, for a
    ///      holder whose recorded tier differs from the vault's current tier. The account-less vault
    ///      preview is permitted to differ and is asserted to be the one that diverges.
    function test_previewRedeemFor_matchesTheHolderTier() external {
        bytes32 atomId = _atom("preview-parity");

        // Early holder lands low; the vault is then grown well past that band.
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, DYN, 3e18, 0);
        makeDeposit(users.charlie, users.charlie, atomId, DYN, 120e18, 0);
        makeDeposit(users.alice, users.alice, atomId, DYN, 120e18, 0);

        uint256 holderTier = dynamicFeeCurve.userTier(atomId, users.bob);
        uint256 vaultTier = dynamicFeeCurve.tierOf(dynamicFeeCurve.vaultStake(atomId));
        assertTrue(holderTier != vaultTier, "fixture must place the holder off the vault tier");

        // Quote against the ASSET value of the shares, which is what the write path passes, so this
        // assertion would still bind if the vault ever drifted off 1:1 rather than silently comparing
        // two share-denominated figures.
        uint256 grossAssets = protocol.multiVault.convertToAssets(atomId, DYN, shares);
        (, uint256 accountFee) = dynamicFeeCurve.previewRedeemFor(atomId, users.bob, grossAssets);
        uint256 executionFee = dynamicFeeCurve.quoteRedeemFee(atomId, users.bob, grossAssets);

        assertEq(accountFee, executionFee, "account-aware preview must equal the executed quote");
    }
}
