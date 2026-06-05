// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";

contract UnpauseAffiliateTest is FeeProxyBaseTest {
    function test_unpauseAffiliate_Success_clearsFlagAndEmits() external {
        _registerSampleAffiliate();
        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        vm.prank(feeProxyAdmin);
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.AffiliateUnpaused(affiliate);
        feeProxy.unpauseAffiliate(affiliate);

        assertTrue(feeProxy.isAffiliateActive(affiliate), "row active after unpause");
        assertFalse(feeProxy.affiliateConfig(affiliate).paused, "paused flag cleared");
    }

    function test_unpauseAffiliate_RevertWhen_NotRegistered() external {
        vm.prank(feeProxyAdmin);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotRegistered.selector, affiliate));
        feeProxy.unpauseAffiliate(affiliate);
    }

    function test_unpauseAffiliate_RevertWhen_NotPaused() external {
        _registerSampleAffiliate();
        vm.prank(feeProxyAdmin);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotPaused.selector, affiliate));
        feeProxy.unpauseAffiliate(affiliate);
    }

    function test_unpauseAffiliate_RoutingRecoversAfterUnpause() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("unpause-affiliate-resume", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        vm.prank(feeProxyAdmin);
        feeProxy.unpauseAffiliate(affiliate);

        // After unpause, routing through this affiliate works again.
        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        uint256 shares = feeProxy.depositVia{ value: 1 ether }(
            affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard()
        );
        vm.stopPrank();
        assertTrue(shares > 0, "deposit succeeds after unpause");
    }

    function test_unpauseAffiliate_DoesNotValidateAgainstCurrentCaps() external {
        // Affiliate registers under loose caps, gets paused, admin tightens
        // caps below the row, then unpauses. Unpause itself succeeds (we
        // intentionally do not re-validate caps on unpause). Routing remains
        // blocked until the affiliate updates fees.
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Drop the bps cap below the registered depositBps.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxBps(SAMPLE_DEPOSIT_BPS - 1);
        vm.stopPrank();

        // Unpause still succeeds.
        vm.prank(feeProxyAdmin);
        feeProxy.unpauseAffiliate(affiliate);
        assertTrue(feeProxy.isAffiliateActive(affiliate), "active after unpause despite over-cap row");

        // Routing through the now-over-cap row reverts with the cap error.
        bytes32 atomId = _createAtomDirect("unpause-over-cap", users.alice);
        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCap.selector, SAMPLE_DEPOSIT_BPS, SAMPLE_DEPOSIT_BPS - 1
            )
        );
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }
}
