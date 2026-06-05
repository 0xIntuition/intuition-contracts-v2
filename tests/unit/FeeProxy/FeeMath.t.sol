// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, FeeConfig, FeeGuard } from "src/interfaces/IFeeProxy.sol";

contract FeeMathTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_previewDepositFee_returnsZeroForUnregistered() external view {
        (uint256 fee, uint256 forwarded) = feeProxy.previewDepositFee(affiliate, 1 ether);
        assertEq(fee, 0, "no row -> zero bps + zero fixed");
        assertEq(forwarded, 1 ether, "forwarded == gross");
    }

    function test_previewDepositFee_matchesFormula() external {
        _registerSampleAffiliate();

        uint256 gross = 10 ether;
        uint256 expectedFee = (gross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;

        (uint256 fee, uint256 forwarded) = feeProxy.previewDepositFee(affiliate, gross);
        assertEq(fee, expectedFee, "deposit fee math");
        assertEq(forwarded, gross - expectedFee, "deposit forwarded math");
    }

    function test_previewCreationFee_matchesFormula() external {
        _registerSampleAffiliate();

        uint256 gross = 7 ether;
        uint256 expectedFee = (gross * SAMPLE_CREATION_BPS) / BPS_DIVISOR + SAMPLE_CREATION_FIXED_FEE;

        (uint256 fee, uint256 forwarded) = feeProxy.previewCreationFee(affiliate, gross);
        assertEq(fee, expectedFee, "creation fee math");
        assertEq(forwarded, gross - expectedFee, "creation forwarded math");
    }

    function test_previewDepositFee_returnsZeroForwardedWhenFeeExceedsGross() external {
        // Register a row with a fixed fee large enough to exceed small gross amounts.
        FeeConfig memory fees = _zeroFeeConfig();
        fees.depositFixedFee = INITIAL_MAX_FIXED_FEE;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();

        (uint256 fee, uint256 forwarded) = feeProxy.previewDepositFee(affiliate, 1 wei);
        assertEq(fee, INITIAL_MAX_FIXED_FEE);
        assertEq(forwarded, 0, "forwarded clamped to zero in the view");
    }

    function testFuzz_previewDepositFee_parityWithRoutingAccrual(
        uint256 depositBps,
        uint256 depositFixed,
        uint256 gross
    )
        external
    {
        depositBps = bound(depositBps, 0, INITIAL_MAX_BPS);
        depositFixed = bound(depositFixed, 0, INITIAL_MAX_FIXED_FEE);
        // Keep gross within a band that exercises real arithmetic without
        // pushing past the user-funded ceiling configured in BaseTest.
        gross = bound(gross, 1 ether, 100 ether);

        FeeConfig memory fees =
            FeeConfig({ depositBps: depositBps, creationBps: 0, depositFixedFee: depositFixed, creationFixedFee: 0 });

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();

        uint256 expectedFee = (gross * depositBps) / BPS_DIVISOR + depositFixed;
        vm.assume(expectedFee < gross); // Equivalent to the implementation's revert guard.

        (uint256 previewFee, uint256 previewForwarded) = feeProxy.previewDepositFee(affiliate, gross);
        assertEq(previewFee, expectedFee, "preview fee matches formula");
        assertEq(previewForwarded, gross - expectedFee, "preview forwarded matches formula");
    }

    function test_depositVia_RevertWhen_FeeGuardBpsExceeded() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("fee-guard-bps", users.alice);

        FeeGuard memory tightGuard = FeeGuard({ maxFeeBps: SAMPLE_DEPOSIT_BPS - 1, maxFixedFee: type(uint256).max });

        vm.deal(users.alice, 5 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCallerGuard.selector, SAMPLE_DEPOSIT_BPS, SAMPLE_DEPOSIT_BPS - 1
            )
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, tightGuard);
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_FeeGuardFixedFeeExceeded() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("fee-guard-fixed", users.alice);

        FeeGuard memory tightGuard =
            FeeGuard({ maxFeeBps: type(uint256).max, maxFixedFee: SAMPLE_DEPOSIT_FIXED_FEE - 1 });

        vm.deal(users.alice, 5 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCallerGuard.selector,
                SAMPLE_DEPOSIT_FIXED_FEE,
                SAMPLE_DEPOSIT_FIXED_FEE - 1
            )
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, tightGuard);
        vm.stopPrank();
    }
}
