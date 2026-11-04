// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";

contract UpdateFeeRecipientTest is FeeProxyBaseTest {
    function test_updateFeeRecipient_Success_rewritesRowAndEmits() external {
        _registerSampleAffiliate();
        address payable next = payable(makeAddr("newFeeRecipient"));

        vm.startPrank(affiliate);
        vm.expectEmit(true, true, true, true, address(feeProxy));
        emit IFeeProxy.AffiliateFeeRecipientUpdated(affiliate, affiliateFeeRecipient, next);
        feeProxy.updateFeeRecipient(next);
        vm.stopPrank();

        assertEq(feeProxy.affiliateConfig(affiliate).feeRecipient, next, "feeRecipient updated");
    }

    function test_updateFeeRecipient_RevertWhen_ZeroRecipient() external {
        _registerSampleAffiliate();
        vm.startPrank(affiliate);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        feeProxy.updateFeeRecipient(address(0));
        vm.stopPrank();
    }

    function test_updateFeeRecipient_RevertWhen_NotRegistered() external {
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotRegistered.selector, users.alice));
        feeProxy.updateFeeRecipient(makeAddr("newRecipient"));
        vm.stopPrank();
    }

    function test_updateFeeRecipient_AllowedWhilePerAffiliatePaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Paused affiliates can still rotate the fee recipient (e.g. for key
        // migration). Row stays paused; only the recipient changes.
        address newRecipient = makeAddr("newRecipientPausedRow");
        vm.startPrank(affiliate);
        feeProxy.updateFeeRecipient(newRecipient);
        vm.stopPrank();

        assertEq(feeProxy.affiliateConfig(affiliate).feeRecipient, newRecipient, "recipient rotated while paused");
        assertTrue(feeProxy.affiliateConfig(affiliate).paused, "row remains paused");
    }

    function test_updateFeeRecipient_AllowedWhileGloballyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        address newRecipient = makeAddr("newRecipientPaused");
        vm.startPrank(affiliate);
        feeProxy.updateFeeRecipient(newRecipient);
        vm.stopPrank();

        assertEq(feeProxy.affiliateConfig(affiliate).feeRecipient, newRecipient, "row mutated while paused");
    }
}
