// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest, RevertingReceiverMock } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";

/// @title  Track 3 — FeeProxy ETH-conservation & refund-ledger drain hunt (ENG-12460)
/// @notice Attempts to make the proxy pay out more than it took in, to over-credit
///         the pull-fallback ledger, and to drain one user's pending refund from
///         another account. All NEGATIVE results: ETH is conserved end-to-end and
///         the ledger is strictly per-`msg.sender`.
///
///         Complements tests/unit/FeeProxy/Refund.t.sol (push/pull mechanics) and
///         DepositVia.t.sol (approval gating) with explicit zero-sum conservation
///         and cross-user-drain assertions.
contract FeeProxyConservationTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    /// @dev Invariant: a routed deposit neither creates nor destroys native value.
    ///      Σ balance deltas over {caller, affiliate recipient, multiVault, proxy}
    ///      must be exactly zero, and the proxy must retain nothing.
    function testFuzz_depositVia_conservesEth(uint256 grossSeed, uint256 excessSeed) public {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("t3-cons", users.alice);

        uint256 gross = bound(grossSeed, 0.5 ether, 100 ether);
        uint256 excess = bound(excessSeed, 0, 50 ether);
        // Ensure the fee never swallows the whole gross (proxy enforces fee < gross).
        uint256 fee = (gross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
        vm.assume(fee < gross);

        vm.deal(users.alice, gross + excess);

        int256 callerBefore = int256(users.alice.balance);
        int256 recipientBefore = int256(affiliateFeeRecipient.balance);
        int256 vaultBefore = int256(address(protocol.multiVault).balance);
        int256 proxyBefore = int256(address(feeProxy).balance);

        vm.startPrank(users.alice);
        feeProxy.depositVia{ value: gross + excess }(
            affiliate, users.alice, atomId, CURVE_ID, gross, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        int256 callerDelta = int256(users.alice.balance) - callerBefore;
        int256 recipientDelta = int256(affiliateFeeRecipient.balance) - recipientBefore;
        int256 vaultDelta = int256(address(protocol.multiVault).balance) - vaultBefore;
        int256 proxyDelta = int256(address(feeProxy).balance) - proxyBefore;

        assertEq(callerDelta + recipientDelta + vaultDelta + proxyDelta, int256(0), "native value conserved (zero-sum)");
        assertEq(address(feeProxy).balance, 0, "proxy retains no residual ETH");
        assertEq(recipientDelta, int256(fee), "affiliate recipient got exactly the fee");
    }

    /// @dev The pull-fallback ledger credits EXACTLY the overpayment, never more.
    function test_pendingRefundEqualsOverpayment_notMore() public {
        _registerSampleAffiliate();

        RevertingReceiverMock scw = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(scw), 100 ether);
        scw.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("t3-overpay");
        uint256[] memory assets = _toUintArray(1 ether);
        uint256 excess = 0.75 ether;

        uint256 proxyBefore = address(feeProxy).balance;

        vm.startPrank(address(scw));
        feeProxy.createAtomsVia{ value: 1 ether + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(scw)), excess, "ledger credited exactly the overpayment");
        assertEq(address(feeProxy).balance - proxyBefore, excess, "proxy holds exactly the credited refund");
    }

    /// @dev A different account cannot claim a refund it is not owed — the ledger is
    ///      keyed strictly by `msg.sender`. No cross-user drain.
    function test_crossUserCannotDrainPendingRefund() public {
        _registerSampleAffiliate();

        RevertingReceiverMock scw = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(scw), 100 ether);
        scw.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("t3-cross-user");
        uint256[] memory assets = _toUintArray(1 ether);
        uint256 excess = 0.6 ether;

        vm.startPrank(address(scw));
        feeProxy.createAtomsVia{ value: 1 ether + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(scw)), excess, "credit landed on SCW key");

        // Attacker (bob) tries to claim — has no balance of his own.
        vm.startPrank(users.bob);
        vm.expectRevert(IFeeProxy.FeeProxy_NoRefundOwed.selector);
        feeProxy.claimRefund();
        vm.stopPrank();

        // Attacker tries to redirect via claimRefundTo — still keyed to bob, nothing owed.
        vm.startPrank(users.bob);
        vm.expectRevert(IFeeProxy.FeeProxy_NoRefundOwed.selector);
        feeProxy.claimRefundTo(payable(users.bob));
        vm.stopPrank();

        // The victim's credit is untouched.
        assertEq(feeProxy.pendingRefund(address(scw)), excess, "victim ledger entry preserved");
    }

    /// @dev Claiming twice is impossible: the ledger zeroes before the transfer.
    function test_doubleClaim_reverts() public {
        bytes32 slot = keccak256(abi.encode(users.alice, PENDING_REFUND_SLOT));
        vm.store(address(feeProxy), slot, bytes32(uint256(1 ether)));
        vm.deal(address(feeProxy), 1 ether);

        vm.startPrank(users.alice);
        uint256 claimed = feeProxy.claimRefund();
        assertEq(claimed, 1 ether, "first claim returns the credit");

        vm.expectRevert(IFeeProxy.FeeProxy_NoRefundOwed.selector);
        feeProxy.claimRefund();
        vm.stopPrank();

        assertEq(address(feeProxy).balance, 0, "proxy fully drained, no double payout");
    }
}
