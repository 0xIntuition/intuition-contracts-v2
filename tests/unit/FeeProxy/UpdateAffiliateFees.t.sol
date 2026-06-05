// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, AffiliateConfig, FeeConfig } from "src/interfaces/IFeeProxy.sol";

contract UpdateAffiliateFeesTest is FeeProxyBaseTest {
    function test_updateAffiliateFees_Success_rewritesRowAndEmits() external {
        FeeConfig memory previous = _registerSampleAffiliate();

        FeeConfig memory next = FeeConfig({
            depositBps: SAMPLE_DEPOSIT_BPS + 1,
            creationBps: SAMPLE_CREATION_BPS + 1,
            depositFixedFee: SAMPLE_DEPOSIT_FIXED_FEE + 1,
            creationFixedFee: SAMPLE_CREATION_FIXED_FEE + 1
        });

        vm.startPrank(affiliate);
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.AffiliateFeesUpdated(affiliate, previous, next);
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();

        AffiliateConfig memory row = feeProxy.affiliateConfig(affiliate);
        assertEq(row.fees.depositBps, next.depositBps, "depositBps");
        assertEq(row.fees.creationBps, next.creationBps, "creationBps");
        assertEq(row.fees.depositFixedFee, next.depositFixedFee, "depositFixedFee");
        assertEq(row.fees.creationFixedFee, next.creationFixedFee, "creationFixedFee");
    }

    function test_updateAffiliateFees_RevertWhen_NotRegistered() external {
        FeeConfig memory next = _zeroFeeConfig();
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotRegistered.selector, users.alice));
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();
    }

    function test_updateAffiliateFees_AllowedWhilePerAffiliatePaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Paused affiliates can still rehabilitate their row — row-paused
        // means "cannot route user value", not "row frozen until admin".
        FeeConfig memory tighter = _zeroFeeConfig();
        vm.startPrank(affiliate);
        feeProxy.updateAffiliateFees(tighter);
        vm.stopPrank();

        AffiliateConfig memory row = feeProxy.affiliateConfig(affiliate);
        assertEq(row.fees.depositBps, 0, "row mutated even while per-affiliate paused");
        assertTrue(row.paused, "row remains paused");
    }

    function test_updateAffiliateFees_PausedAffiliateStillBlockedFromRouting() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("paused-update-no-route", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Even after the affiliate brings fees to zero, they cannot route
        // user value until admin unpauses the row.
        vm.startPrank(affiliate);
        feeProxy.updateAffiliateFees(_zeroFeeConfig());
        vm.stopPrank();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_updateAffiliateFees_RoutingResumesAfterUpdatePlusUnpause() external {
        // Lifecycle: admin lowers cap below row → routing blocks → affiliate
        // (still paused or not, doesn't matter) updates row down under cap →
        // admin unpauses → routing resumes.
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("paused-update-then-resume", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Admin drops the bps cap below the original deposit bps.
        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxBps(SAMPLE_DEPOSIT_BPS - 1);
        vm.stopPrank();

        // Affiliate brings the row under the new cap while still paused.
        FeeConfig memory tighter = _sampleFeeConfig();
        tighter.depositBps = SAMPLE_DEPOSIT_BPS - 1;
        tighter.creationBps = SAMPLE_DEPOSIT_BPS - 1;
        vm.startPrank(affiliate);
        feeProxy.updateAffiliateFees(tighter);
        vm.stopPrank();

        // Admin unpauses the row.
        vm.prank(feeProxyAdmin);
        feeProxy.unpauseAffiliate(affiliate);

        // Routing through the affiliate now succeeds.
        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        uint256 shares = feeProxy.depositVia{ value: 1 ether }(
            affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        assertTrue(shares > 0, "routing resumes after row update + unpause");
    }

    function test_updateAffiliateFees_RevertWhen_DepositBpsExceedsCap() external {
        _registerSampleAffiliate();
        FeeConfig memory next = _sampleFeeConfig();
        next.depositBps = INITIAL_MAX_BPS + 1;

        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_BpsExceedsCap.selector, next.depositBps, INITIAL_MAX_BPS)
        );
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();
    }

    function test_updateAffiliateFees_RevertWhen_CreationBpsExceedsCap() external {
        _registerSampleAffiliate();
        FeeConfig memory next = _sampleFeeConfig();
        next.creationBps = INITIAL_MAX_BPS + 1;

        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_BpsExceedsCap.selector, next.creationBps, INITIAL_MAX_BPS)
        );
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();
    }

    function test_updateAffiliateFees_RevertWhen_DepositFixedFeeExceedsCap() external {
        _registerSampleAffiliate();
        FeeConfig memory next = _sampleFeeConfig();
        next.depositFixedFee = INITIAL_MAX_FIXED_FEE + 1;

        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, next.depositFixedFee, INITIAL_MAX_FIXED_FEE
            )
        );
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();
    }

    function test_updateAffiliateFees_RevertWhen_CreationFixedFeeExceedsCap() external {
        _registerSampleAffiliate();
        FeeConfig memory next = _sampleFeeConfig();
        next.creationFixedFee = INITIAL_MAX_FIXED_FEE + 1;

        vm.startPrank(affiliate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, next.creationFixedFee, INITIAL_MAX_FIXED_FEE
            )
        );
        feeProxy.updateAffiliateFees(next);
        vm.stopPrank();
    }

    function test_updateAffiliateFees_AllowedWhileGloballyPaused() external {
        _registerSampleAffiliate();

        // Admin globally pauses the contract.
        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        // Affiliate can still bring its row down to a fresh post-cap-drop config.
        FeeConfig memory tighter = _zeroFeeConfig();
        vm.startPrank(affiliate);
        feeProxy.updateAffiliateFees(tighter);
        vm.stopPrank();

        AffiliateConfig memory row = feeProxy.affiliateConfig(affiliate);
        assertEq(row.fees.depositBps, 0, "row mutated even while contract paused");
    }
}
