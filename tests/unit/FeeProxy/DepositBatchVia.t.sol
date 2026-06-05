// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy, FeeConfig } from "src/interfaces/IFeeProxy.sol";

contract DepositBatchViaTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_depositBatchVia_Success_accruesAggregateFee() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("deposit-batch-via-a", users.alice);
        bytes32 atomB = _createAtomDirect("deposit-batch-via-b", users.alice);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomA;
        termIds[1] = atomB;
        uint256[] memory curveIds = new uint256[](2);
        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;
        uint256[] memory assets = new uint256[](2);
        assets[0] = 3 ether;
        assets[1] = 2 ether;
        uint256[] memory minShares = new uint256[](2);

        uint256 totalGross = 5 ether;
        uint256 expectedFee = (totalGross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        uint256[] memory shares = feeProxy.depositBatchVia{ value: totalGross }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(shares.length, 2);
        assertEq(
            affiliateFeeRecipient.balance - recipientBalanceBefore, expectedFee, "affiliate received aggregate fee"
        );
        assertEq(address(feeProxy).balance, 0, "proxy must hold no residual ETH");
    }

    function test_depositBatchVia_Success_refundsExcessMsgValue() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("deposit-batch-refund", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomA);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(2 ether);
        uint256[] memory minShares = _toUintArray(0);

        uint256 totalGross = 2 ether;
        uint256 excess = 0.5 ether;

        vm.deal(users.alice, totalGross + excess);
        uint256 aliceBalanceBefore = users.alice.balance;
        vm.startPrank(users.alice);
        feeProxy.depositBatchVia{ value: totalGross + excess }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        // Alice received the excess back via push.
        uint256 expectedFee = (totalGross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
        uint256 netSpend = totalGross; // excess refunded; gross spent.
        assertEq(aliceBalanceBefore - users.alice.balance, netSpend, "spend equals gross net of refund");
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
        assertEq(feeProxy.pendingRefund(users.alice), 0, "no pull-fallback credit needed for EOA");
        assertEq(expectedFee, (totalGross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE);
    }

    function test_depositBatchVia_Success_ApprovedDelegatedReceiver() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-approved-receiver", users.alice);

        vm.startPrank(users.bob);
        protocol.multiVault.approve(users.alice, ApprovalTypes.DEPOSIT);
        vm.stopPrank();

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        uint256[] memory shares = feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.bob, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(shares.length, 1);
        assertGt(shares[0], 0, "shares minted");
        assertEq(protocol.multiVault.getShares(users.bob, atomId, CURVE_ID), shares[0], "bob receives shares");
        assertEq(protocol.multiVault.getShares(users.alice, atomId, CURVE_ID), 0, "alice receives no shares");
    }

    function test_depositBatchVia_RevertWhen_LengthMismatch_TermIdsVsAssets() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-len-mismatch", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = new uint256[](2); // mismatch
        assets[0] = 1 ether;
        assets[1] = 1 ether;
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.depositBatchVia{ value: 2 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_EmptyArrays() external {
        _registerSampleAffiliate();

        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory curveIds = new uint256[](0);
        uint256[] memory assets = new uint256[](0);
        uint256[] memory minShares = new uint256[](0);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.depositBatchVia{ value: 0 }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_InsufficientValue() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-insufficient", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(2 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_InsufficientValue.selector, 1 ether, 2 ether));
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_AnyLegHasZeroAssets() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("deposit-batch-zero-leg-a", users.alice);
        bytes32 atomB = _createAtomDirect("deposit-batch-zero-leg-b", users.alice);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomA;
        termIds[1] = atomB;
        uint256[] memory curveIds = new uint256[](2);
        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;
        uint256[] memory assets = new uint256[](2);
        assets[0] = 1 ether;
        assets[1] = 0; // zero leg — rejected at validation
        uint256[] memory minShares = new uint256[](2);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroValue.selector);
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_TotalGrossIsZero() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-zero-total", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(0);
        uint256[] memory minShares = _toUintArray(0);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroValue.selector);
        feeProxy.depositBatchVia{ value: 0 }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_FeeExceedsTotalGross() external {
        // Lift the fixed-fee cap, register an affiliate whose fixed fee swamps a small batch gross.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFixedFee(100 ether);
        vm.stopPrank();

        FeeConfig memory fees =
            FeeConfig({ depositBps: 0, creationBps: 0, depositFixedFee: 5 ether, creationFixedFee: 0 });

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(fees, affiliateFeeRecipient);
        vm.stopPrank();

        bytes32 atomId = _createAtomDirect("deposit-batch-fee-exceeds", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_FeeExceedsGross.selector, 5 ether, 1 ether));
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_ZeroReceiver() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-zero-receiver", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, address(0), termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_DelegatedReceiverHasNotApprovedProxy() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-proxy-not-approved", users.alice);

        vm.startPrank(users.bob);
        protocol.multiVault.approve(users.alice, ApprovalTypes.DEPOSIT);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.stopPrank();

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_ProxyNotApprovedForDeposit.selector, users.bob, address(feeProxy))
        );
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.bob, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_SelfReceiverHasNotApprovedProxy() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-self-proxy-not-approved", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_ProxyNotApprovedForDeposit.selector, users.alice, address(feeProxy)
            )
        );
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_ReceiverHasNotApprovedCaller() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("deposit-batch-foreign-receiver", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_ReceiverNotApproved.selector, users.bob, users.alice));
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.bob, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }
}
