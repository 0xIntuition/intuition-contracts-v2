// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy, FeeConfig } from "src/interfaces/IFeeProxy.sol";

contract CreateAtomsViaTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_createAtomsVia_Success_creditsCallerAsAtomCreator() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("create-atoms-via-happy");
        uint256[] memory assets = _toUintArray(2 ether);
        uint256 totalGross = 2 ether;
        uint256 expectedFee = (totalGross * SAMPLE_CREATION_BPS) / BPS_DIVISOR + SAMPLE_CREATION_FIXED_FEE;
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        bytes32[] memory ids =
            feeProxy.createAtomsVia{ value: totalGross }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(ids.length, 1);
        assertEq(protocol.multiVault.getAtomCreator(ids[0]), users.alice, "credited creator is the proxy caller");
        assertTrue(
            protocol.multiVault.getAtomCreator(ids[0]) != address(feeProxy), "creator must never be the proxy itself"
        );
        assertEq(
            affiliateFeeRecipient.balance - recipientBalanceBefore, expectedFee, "affiliate received aggregate fee"
        );
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
    }

    function test_createAtomsVia_Success_refundsExcessMsgValue() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("create-atoms-via-refund");
        uint256[] memory assets = _toUintArray(2 ether);
        uint256 totalGross = 2 ether;
        uint256 excess = 0.4 ether;

        vm.deal(users.alice, totalGross + excess);
        uint256 aliceBalanceBefore = users.alice.balance;
        vm.startPrank(users.alice);
        feeProxy.createAtomsVia{ value: totalGross + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(aliceBalanceBefore - users.alice.balance, totalGross, "excess refunded to caller");
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
        assertEq(feeProxy.pendingRefund(users.alice), 0, "EOA push refund succeeded - no pull-fallback credit");
    }

    function test_createAtomsVia_RevertWhen_CreatorHasNotApprovedProxy() external {
        _registerSampleAffiliate();

        // Revoke approval first so the proxy is no longer authorized to create on behalf of alice.
        vm.startPrank(users.alice);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.stopPrank();

        bytes[] memory atomDatas = _toBytesArray("create-atoms-via-no-approval");
        uint256[] memory assets = _toUintArray(2 ether);

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_ProxyNotApprovedForCreation.selector, users.alice, address(feeProxy)
            )
        );
        feeProxy.createAtomsVia{ value: 2 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createAtomsVia_RevertWhen_LengthMismatch() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = new bytes[](1);
        atomDatas[0] = "len-mismatch";
        uint256[] memory assets = new uint256[](2);
        assets[0] = 1 ether;
        assets[1] = 1 ether;

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.createAtomsVia{ value: 2 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createAtomsVia_RevertWhen_EmptyArrays() external {
        _registerSampleAffiliate();
        bytes[] memory atomDatas = new bytes[](0);
        uint256[] memory assets = new uint256[](0);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.createAtomsVia{ value: 0 }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createAtomsVia_RevertWhen_AnyLegHasZeroAssets() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = new bytes[](2);
        atomDatas[0] = "create-atoms-via-zero-leg-a";
        atomDatas[1] = "create-atoms-via-zero-leg-b";
        uint256[] memory assets = new uint256[](2);
        assets[0] = 2 ether;
        assets[1] = 0;

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAssets.selector);
        feeProxy.createAtomsVia{ value: 2 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createAtomsVia_RevertWhen_InsufficientValue() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("create-atoms-via-low-value");
        uint256[] memory assets = _toUintArray(2 ether);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_InsufficientValue.selector, 1 ether, 2 ether));
        feeProxy.createAtomsVia{ value: 1 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createAtomsVia_zeroFeeAffiliate_NoFeePushed() external {
        _registerZeroFeeAffiliate();

        bytes[] memory atomDatas = _toBytesArray("create-atoms-via-zero-fee");
        uint256[] memory assets = _toUintArray(2 ether);
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        feeProxy.createAtomsVia{ value: 2 ether }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(affiliateFeeRecipient.balance, recipientBalanceBefore, "no fee push when fee == 0");
    }
}
