// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveFeeRedistributionBoundsTest
/// @notice Executed economic regressions on the WITHDRAWAL side of the fee redistribution.
///
///         The existing adversarial-economics suite covers the deposit-side sandwich and asserts that
///         earnings stay bounded by the victim's fee. The redeem side had no equivalent, and it is
///         the sharper surface: the shipped schedule sets `redeemToFulcrumTiersBps = 0`, which
///         routes the ENTIRE exit fee to the exiting holder's tier rather than diluting it across the
///         fulcrum spread.
///
///         These tests pin what the design guarantees — conservation, self-exclusion, and no
///         inflation — rather than asserting a particular split. Earning from a later exit is the
///         intended activity-driven mechanic and is deliberately NOT constrained by a dwell
///         requirement; the invariant is that distribution never exceeds fees actually collected.
contract CurveFeeRedistributionBoundsTest is BaseTest {
    uint256 internal constant DYN = DYNAMIC_FEE_CURVE_ID;

    function _atom(string memory label) internal returns (bytes32) {
        return createSimpleAtom(label, ATOM_COST[0], users.alice);
    }

    /// @dev Total obligations the curve owes: every party's claimable plus the protocol bucket.
    function _obligations(bytes32 termId, address[3] memory parties) internal view returns (uint256 total) {
        for (uint256 i = 0; i < parties.length; ++i) {
            total += dynamicFeeCurve.claimable(parties[i], termId);
        }
        total += dynamicFeeCurve.protocolAccrued();
    }

    /* =================================================== */
    /*        WITHDRAWAL-SIDE FRONT-RUN (MIRROR)           */
    /* =================================================== */

    /// @dev The redeem-side mirror of the deposit sandwich test. An account that opens a position
    ///      immediately before a visible exit earns from that exit — intended — but must never earn
    ///      MORE than the redeem fee the exiting holder actually paid. That is the conservation
    ///      bound, and it is what distinguishes redistribution from inflation.
    function test_frontRun_redeemEarningsBoundedByExitFee() external {
        bytes32 atomId = _atom("wd-frontrun");

        // A long-standing holder establishes the tier.
        makeDeposit(users.charlie, users.charlie, atomId, DYN, 6e18, 0);

        // The victim takes a position in the same band.
        uint256 victimShares = makeDeposit(users.bob, users.bob, atomId, DYN, 8e18, 0);

        // The attacker front-runs the visible exit with a minimum-size deposit.
        makeDeposit(users.alice, users.alice, atomId, DYN, protocol.multiVault.getGeneralConfig().minDeposit, 0);

        uint256 curveBalanceBefore = address(dynamicFeeCurve).balance;

        vm.startPrank(users.bob);
        protocol.multiVault.redeem(users.bob, atomId, DYN, victimShares, 0);
        vm.stopPrank();

        uint256 exitFee = address(dynamicFeeCurve).balance - curveBalanceBefore;
        uint256 attackerEarned = dynamicFeeCurve.claimable(users.alice, atomId);

        assertLe(attackerEarned, exitFee, "front-runner cannot earn more than the exit fee actually collected");
    }

    /// @dev The exiting holder must never earn from the fee they themselves just paid. This is the
    ///      self-exclusion property the redistribution rests on, asserted on the redeem path.
    function test_exitingHolderEarnsNothingFromTheirOwnRedeemFee() external {
        bytes32 atomId = _atom("wd-self-exclusion");

        makeDeposit(users.charlie, users.charlie, atomId, DYN, 5e18, 0);
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, DYN, 10e18, 0);

        // Settle any prior accrual so the delta below is attributable to this exit alone.
        uint256 beforeExit = dynamicFeeCurve.claimable(users.bob, atomId);

        vm.startPrank(users.bob);
        protocol.multiVault.redeem(users.bob, atomId, DYN, shares / 2, 0);
        vm.stopPrank();

        uint256 afterExit = dynamicFeeCurve.claimable(users.bob, atomId);

        assertLe(afterExit, beforeExit, "the exiting holder must not gain from their own redeem fee");
    }

    /// @dev Conservation across a full redeem cycle: everything the curve owes, plus the protocol
    ///      bucket, never exceeds what the curve actually custodies. This is the property that makes
    ///      the redistribution safe regardless of how the split lands.
    function test_redeemRedistribution_neverOwesMoreThanItHolds() external {
        bytes32 atomId = _atom("wd-conservation");
        address[3] memory parties = [address(users.alice), address(users.bob), address(users.charlie)];

        makeDeposit(users.charlie, users.charlie, atomId, DYN, 4e18, 0);
        uint256 bobShares = makeDeposit(users.bob, users.bob, atomId, DYN, 12e18, 0);
        uint256 aliceShares = makeDeposit(users.alice, users.alice, atomId, DYN, 7e18, 0);

        vm.startPrank(users.bob);
        protocol.multiVault.redeem(users.bob, atomId, DYN, bobShares / 2, 0);
        vm.stopPrank();

        assertLe(
            _obligations(atomId, parties), address(dynamicFeeCurve).balance, "obligations exceed custody after one exit"
        );

        vm.startPrank(users.alice);
        protocol.multiVault.redeem(users.alice, atomId, DYN, aliceShares, 0);
        vm.stopPrank();

        assertLe(
            _obligations(atomId, parties),
            address(dynamicFeeCurve).balance,
            "obligations exceed custody after two exits"
        );
    }

    /// @dev The shipped schedule routes the whole exit fee to the exiting tier. Pin that, because it
    ///      is the configuration every other redeem-side property is measured against, and a
    ///      silent change to it would alter the economics without failing anything else.
    function test_shippedSchedule_routesEntireExitFeeToTheExitingTier() external view {
        DynamicFeeConfig memory cfg = dynamicFeeCurve.getConfig();
        assertEq(cfg.redeemToFulcrumTiersBps, 0, "shipped schedule sends the whole exit fee to the exiting tier");
    }
}
