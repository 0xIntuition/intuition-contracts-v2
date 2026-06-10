// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy, FeeConfig, FeeGuard } from "src/interfaces/IFeeProxy.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract DepositViaTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_depositVia_Success_routesAndAccruesFee() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-happy", users.alice);

        uint256 gross = 5 ether;
        uint256 expectedFee = (gross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, gross);
        vm.startPrank(users.alice);
        vm.expectEmit(true, true, true, false, address(feeProxy));
        emit IFeeProxy.AffiliateFeeAccrued(affiliate, users.alice, expectedFee);
        uint256 shares =
            feeProxy.depositVia{ value: gross }(affiliate, users.alice, atomId, CURVE_ID, gross, 0, _looseFeeGuard());
        vm.stopPrank();

        assertTrue(shares > 0, "shares minted");
        assertEq(
            affiliateFeeRecipient.balance - recipientBalanceBefore,
            expectedFee,
            "affiliate fee recipient received the fee"
        );
        // The proxy holds no residual ETH after the call.
        assertEq(address(feeProxy).balance, 0, "proxy must hold no residual ETH");
    }

    function test_depositVia_Success_refundsExcessMsgValue() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-refund-excess", users.alice);

        uint256 gross = 2 ether;
        uint256 excess = 0.5 ether;

        vm.deal(users.alice, gross + excess);
        uint256 aliceBalanceBefore = users.alice.balance;
        vm.startPrank(users.alice);
        feeProxy.depositVia{ value: gross + excess }(
            affiliate, users.alice, atomId, CURVE_ID, gross, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(aliceBalanceBefore - users.alice.balance, gross, "excess refunded to caller");
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
        assertEq(feeProxy.pendingRefund(users.alice), 0, "EOA push refund succeeded - no pull-fallback credit");
    }

    function test_depositVia_Success_ApprovedDelegatedReceiver() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-approved-receiver", users.alice);

        vm.startPrank(users.bob);
        protocol.multiVault.approve(users.alice, ApprovalTypes.DEPOSIT);
        vm.stopPrank();

        uint256 gross = 1 ether;
        vm.deal(users.alice, gross);
        vm.startPrank(users.alice);
        uint256 shares =
            feeProxy.depositVia{ value: gross }(affiliate, users.bob, atomId, CURVE_ID, gross, 0, _looseFeeGuard());
        vm.stopPrank();

        assertGt(shares, 0, "shares minted");
        assertEq(protocol.multiVault.getShares(users.bob, atomId, CURVE_ID), shares, "bob receives shares");
        assertEq(protocol.multiVault.getShares(users.alice, atomId, CURVE_ID), 0, "alice receives no shares");
    }

    function test_depositVia_minSharesAppliedPostFee_RevertOnSlippage() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-slippage", users.alice);

        uint256 gross = 1 ether;
        // Demand many more shares than any post-fee deposit could possibly mint;
        // MultiVault must revert with its native slippage error.
        uint256 minShares = type(uint128).max;

        vm.deal(users.alice, gross);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_SlippageExceeded.selector));
        feeProxy.depositVia{ value: gross }(
            affiliate, users.alice, atomId, CURVE_ID, gross, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_AffiliateNotRegistered() external {
        bytes32 atomId = _createAtomDirect("deposit-via-no-row", users.alice);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotRegistered.selector, affiliate));
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_ZeroReceiver() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-zero-receiver", users.alice);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        feeProxy.depositVia{ value: 1 ether }(affiliate, address(0), atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_DelegatedReceiverHasNotApprovedProxy() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-proxy-not-approved", users.alice);

        vm.startPrank(users.bob);
        protocol.multiVault.approve(users.alice, ApprovalTypes.DEPOSIT);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.stopPrank();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_ProxyNotApprovedForDeposit.selector, users.bob, address(feeProxy))
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.bob, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_SelfReceiverHasNotApprovedProxy() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-self-proxy-not-approved", users.alice);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_ProxyNotApprovedForDeposit.selector, users.alice, address(feeProxy)
            )
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_ReceiverHasNotApprovedCaller() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-foreign-receiver", users.alice);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_ReceiverNotApproved.selector, users.bob, users.alice));
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.bob, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_ZeroGrossAssets() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-zero-gross", users.alice);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroValue.selector);
        feeProxy.depositVia{ value: 0 }(affiliate, users.alice, atomId, CURVE_ID, 0, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_MsgValueBelowGrossAssets() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-via-underpaid", users.alice);

        vm.deal(users.alice, 0.5 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_InsufficientValue.selector, 0.5 ether, 1 ether));
        feeProxy.depositVia{ value: 0.5 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_FeeMeetsOrExceedsGross() external {
        // Affiliate with a fixed fee large enough to swallow small `grossAssets`.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFixedFee(100 ether);
        vm.stopPrank();

        bytes32 atomId = _createAtomDirect("deposit-via-fee-too-large", users.alice);

        // Register a row with a fixed fee that swamps the gross.
        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(
            _largeFixedFeeConfig(2 ether), affiliateFeeRecipient
        );
        vm.stopPrank();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_FeeExceedsGross.selector, 2 ether, 1 ether));
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function _largeFixedFeeConfig(uint256 fixedFee) internal pure returns (FeeConfig memory) {
        return FeeConfig({ depositBps: 0, creationBps: 0, depositFixedFee: fixedFee, creationFixedFee: fixedFee });
    }
}
