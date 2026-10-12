// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest, PayableReceiverMock, RevertingReceiverMock } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";

contract RefundTest is FeeProxyBaseTest {
    function test_refund_pushSucceeds_payableReceiver() external {
        _registerSampleAffiliate();

        PayableReceiverMock payableSCW = new PayableReceiverMock();
        vm.deal(address(payableSCW), 100 ether);

        // Grant the SCW DEPOSIT approval through itself as the receiver: the
        // SCW must approve the proxy. Use a direct `multiVault.approve` call
        // via a low-level call from the SCW's context.
        vm.startPrank(address(payableSCW));
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.ALL);
        vm.stopPrank();

        // Bootstrap an atom from a real EOA so the SCW has something to deposit into.
        bytes32 atomId = _createAtomDirect("refund-push-payable", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        uint256 excess = 0.3 ether;
        uint256 balanceBefore = address(payableSCW).balance;

        vm.startPrank(address(payableSCW));
        feeProxy.depositBatchVia{ value: 1 ether + excess }(
            affiliate, address(payableSCW), termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        // Excess refunded via push — no pull-fallback credit.
        assertEq(balanceBefore - address(payableSCW).balance, 1 ether, "only the gross was spent");
        assertEq(feeProxy.pendingRefund(address(payableSCW)), 0, "push succeeded");
    }

    function test_refund_pushFailsPullsCredit_revertingReceiver() external {
        _registerSampleAffiliate();

        // Deploy reverting receiver; have it grant the proxy ALL approval on MultiVault.
        RevertingReceiverMock revertingSCW = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(revertingSCW), 100 ether);
        revertingSCW.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("refund-push-fail");
        uint256[] memory assets = _toUintArray(1 ether);

        uint256 totalGross = 1 ether;
        uint256 excess = 0.5 ether;

        vm.startPrank(address(revertingSCW));
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.RefundCredited(address(revertingSCW), excess);
        feeProxy.createAtomsVia{ value: totalGross + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(revertingSCW)), excess, "excess credited to pull-fallback ledger");
        assertEq(address(feeProxy).balance, excess, "proxy holds the credited refund");
    }

    function test_claimRefund_Success() external {
        _registerSampleAffiliate();

        // Drive a refund into the pull-fallback ledger.
        RevertingReceiverMock revertingSCW = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(revertingSCW), 100 ether);
        revertingSCW.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("refund-claim");
        uint256[] memory assets = _toUintArray(1 ether);
        uint256 excess = 0.4 ether;

        vm.startPrank(address(revertingSCW));
        feeProxy.createAtomsVia{ value: 1 ether + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(revertingSCW)), excess);

        // The reverting receiver can't claim because its `receive` reverts; use a non-reverting EOA instead.
        // To test the happy path, simulate a clean user with a manually-seeded pending balance.
        address user = makeAddr("refundClaimant");
        // Seed via direct storage manipulation: stage a pending refund + fund the proxy.
        vm.deal(address(feeProxy), 0); // reset and reset

        // Move the pending refund balance from the SCW key onto the EOA key by claiming as the SCW first
        // would revert, so instead route a fresh refund cycle through an EOA whose `receive` will succeed.
        // The simpler approach: assert claim path against the SCW via prank — vm.prank lets us assert the
        // revert, but to assert the success path we'd need an SCW that can receive in claim but not in
        // routing. That isn't ergonomic; instead, prime the ledger directly with `vm.store` so we exercise
        // claimRefund in isolation.

        bytes32 slot = keccak256(abi.encode(user, PENDING_REFUND_SLOT)); // pendingRefund mapping slot
        vm.store(address(feeProxy), slot, bytes32(uint256(0.7 ether)));
        vm.deal(address(feeProxy), 0.7 ether);

        uint256 userBalanceBefore = user.balance;
        vm.startPrank(user);
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.RefundClaimed(user, 0.7 ether);
        uint256 claimed = feeProxy.claimRefund();
        vm.stopPrank();

        assertEq(claimed, 0.7 ether);
        assertEq(user.balance - userBalanceBefore, 0.7 ether, "user received the credited refund");
        assertEq(feeProxy.pendingRefund(user), 0, "ledger cleared");
    }

    function test_claimRefund_RevertWhen_NoBalance() external {
        vm.startPrank(users.bob);
        vm.expectRevert(IFeeProxy.FeeProxy_NoRefundOwed.selector);
        feeProxy.claimRefund();
        vm.stopPrank();
    }

    function test_claimRefundTo_Success_revertingSCW_recoversToCleanRecipient() external {
        _registerSampleAffiliate();

        // Drive a pending-refund credit through the reverting receiver mock.
        RevertingReceiverMock revertingSCW = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(revertingSCW), 100 ether);
        revertingSCW.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("refund-claim-to-recovery");
        uint256[] memory assets = _toUintArray(1 ether);
        uint256 excess = 0.6 ether;

        vm.startPrank(address(revertingSCW));
        feeProxy.createAtomsVia{ value: 1 ether + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(revertingSCW)), excess, "credit landed on SCW key");

        // The SCW recovers by claiming to a clean EOA recipient; `msg.sender`
        // is the SCW (the ledger key), `recipient` is the EOA that actually
        // receives the native tokens.
        address payable recipient = payable(makeAddr("scwRefundRecipient"));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.startPrank(address(revertingSCW));
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.RefundClaimed(address(revertingSCW), excess);
        uint256 claimed = feeProxy.claimRefundTo(recipient);
        vm.stopPrank();

        assertEq(claimed, excess, "returned amount equals the credit");
        assertEq(recipient.balance - recipientBalanceBefore, excess, "recipient received the credited refund");
        assertEq(feeProxy.pendingRefund(address(revertingSCW)), 0, "ledger entry cleared on the SCW key");
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
    }

    function test_claimRefundTo_RevertWhen_ZeroRecipient() external {
        // Seed a pending refund so the zero-recipient check fires before the
        // no-balance check.
        bytes32 slot = keccak256(abi.encode(users.alice, PENDING_REFUND_SLOT));
        vm.store(address(feeProxy), slot, bytes32(uint256(1 ether)));
        vm.deal(address(feeProxy), 1 ether);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAddress.selector);
        feeProxy.claimRefundTo(payable(address(0)));
        vm.stopPrank();
    }

    function test_claimRefundTo_RevertWhen_NoBalance() external {
        vm.startPrank(users.bob);
        vm.expectRevert(IFeeProxy.FeeProxy_NoRefundOwed.selector);
        feeProxy.claimRefundTo(payable(makeAddr("claimToRecipient")));
        vm.stopPrank();
    }

    function test_claimRefundTo_RevertWhen_ProxyRecipient() external {
        // Seed a pending refund so the self-recipient guard fires before the no-balance check. Claiming
        // to the proxy itself would otherwise clear the ledger entry while the native value lands back in
        // `receive()` as unaccounted, stuck ETH — the FP-002 refund-conservation guard.
        bytes32 slot = keccak256(abi.encode(users.alice, PENDING_REFUND_SLOT));
        vm.store(address(feeProxy), slot, bytes32(uint256(1 ether)));
        vm.deal(address(feeProxy), 1 ether);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_RefundRecipientIsProxy.selector);
        feeProxy.claimRefundTo(payable(address(feeProxy)));
        vm.stopPrank();

        // The guard reverts before the debit, so the ledger and proxy balance are untouched.
        assertEq(feeProxy.pendingRefund(users.alice), 1 ether, "ledger preserved on revert");
        assertEq(address(feeProxy).balance, 1 ether, "proxy balance preserved on revert");
    }

    function test_receive_RevertWhen_UnauthorizedSender() external {
        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        (bool ok, bytes memory err) = address(feeProxy).call{ value: 1 ether }("");
        vm.stopPrank();

        assertFalse(ok, "direct ETH send must revert");
        bytes4 expectedSelector = IFeeProxy.FeeProxy_UnauthorizedEthSender.selector;
        // err is `<selector><abi-encoded sender>`; assert at least the selector.
        bytes4 actualSelector;
        assembly {
            actualSelector := mload(add(err, 32))
        }
        assertEq(actualSelector, expectedSelector, "selector matches");
    }

    function test_receive_AcceptsFromSelf() external {
        // Self-send via a delegatecall-style trick: spoof msg.sender = address(this).
        vm.deal(address(feeProxy), 1 ether);
        vm.prank(address(feeProxy));
        (bool ok,) = address(feeProxy).call{ value: 0.1 ether }("");
        assertTrue(ok, "self-send must succeed");
    }
}
