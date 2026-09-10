// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, AffiliateConfig, FeeConfig } from "src/interfaces/IFeeProxy.sol";
import { FeeProxy } from "src/periphery/FeeProxy.sol";

contract RegisterAffiliateTest is FeeProxyBaseTest {
    function test_registerAffiliate_Success_recordsRowAndForwardsFee() external {
        FeeConfig memory fees = _sampleFeeConfig();
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.RegistrationFeeForwarded(treasury, INITIAL_REGISTRATION_FEE);
        vm.expectEmit(true, true, false, true, address(feeProxy));
        emit IFeeProxy.AffiliateRegistered(affiliate, affiliateFeeRecipient, fees, INITIAL_REGISTRATION_FEE);
        address returned = feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();

        assertEq(returned, affiliate, "returned affiliate must equal msg.sender");
        assertEq(treasury.balance - treasuryBalanceBefore, INITIAL_REGISTRATION_FEE, "treasury must receive the fee");
        assertTrue(feeProxy.isAffiliateRegistered(affiliate), "row should be registered");
        assertTrue(feeProxy.isAffiliateActive(affiliate), "row should be active");

        AffiliateConfig memory row = feeProxy.affiliateConfig(affiliate);
        assertEq(row.feeRecipient, affiliateFeeRecipient, "feeRecipient");
        assertEq(row.fees.depositBps, SAMPLE_DEPOSIT_BPS, "depositBps");
        assertEq(row.fees.creationBps, SAMPLE_CREATION_BPS, "creationBps");
        assertEq(row.fees.depositFixedFee, SAMPLE_DEPOSIT_FIXED_FEE, "depositFixedFee");
        assertEq(row.fees.creationFixedFee, SAMPLE_CREATION_FIXED_FEE, "creationFixedFee");
        assertEq(row.registeredAt, uint64(block.timestamp), "registeredAt");
        assertFalse(row.paused, "row must not be paused on registration");
    }

    function test_registerAffiliate_RevertWhen_AlreadyRegistered() external {
        _registerSampleAffiliate();

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateAlreadyRegistered.selector, affiliate));
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(_sampleFeeConfig(), affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_ZeroFeeRecipient() external {
        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(_sampleFeeConfig(), address(0));
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_DepositBpsExceedsCap() external {
        FeeConfig memory fees = _sampleFeeConfig();
        fees.depositBps = INITIAL_MAX_FEE_BPS + 1;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_BpsExceedsCap.selector, fees.depositBps, INITIAL_MAX_FEE_BPS)
        );
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_CreationBpsExceedsCap() external {
        FeeConfig memory fees = _sampleFeeConfig();
        fees.creationBps = INITIAL_MAX_FEE_BPS + 1;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_BpsExceedsCap.selector, fees.creationBps, INITIAL_MAX_FEE_BPS)
        );
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_DepositFixedFeeExceedsCap() external {
        FeeConfig memory fees = _sampleFeeConfig();
        fees.depositFixedFee = INITIAL_MAX_FIXED_FEE + 1;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, fees.depositFixedFee, INITIAL_MAX_FIXED_FEE
            )
        );
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_CreationFixedFeeExceedsCap() external {
        FeeConfig memory fees = _sampleFeeConfig();
        fees.creationFixedFee = INITIAL_MAX_FIXED_FEE + 1;

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, fees.creationFixedFee, INITIAL_MAX_FIXED_FEE
            )
        );
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_RegistrationFeeUnderpaid() external {
        uint256 sent = INITIAL_REGISTRATION_FEE - 1;
        vm.deal(affiliate, sent);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_RegistrationFeeMismatch.selector, sent, INITIAL_REGISTRATION_FEE)
        );
        feeProxy.registerAffiliate{ value: sent }(_sampleFeeConfig(), affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_RevertWhen_RegistrationFeeOverpaid() external {
        uint256 sent = INITIAL_REGISTRATION_FEE + 1;
        vm.deal(affiliate, sent);
        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_RegistrationFeeMismatch.selector, sent, INITIAL_REGISTRATION_FEE)
        );
        feeProxy.registerAffiliate{ value: sent }(_sampleFeeConfig(), affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_registerAffiliate_zeroRegistrationFee_SkipsTreasuryForward() external {
        // Drop the registration fee to zero via admin.
        vm.prank(feeProxyAdmin);
        feeProxy.setRegistrationFee(0);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: 0 }(_sampleFeeConfig(), affiliateFeeRecipient);
        vm.stopPrank();

        assertEq(treasury.balance, treasuryBalanceBefore, "treasury must not receive anything");
        assertTrue(feeProxy.isAffiliateActive(affiliate));
    }
}
