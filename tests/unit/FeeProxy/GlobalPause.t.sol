// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, FeeConfig } from "src/interfaces/IFeeProxy.sol";

contract GlobalPauseTest is FeeProxyBaseTest {
    function test_pause_Success_setsPausedFlagAndEmits() external {
        vm.prank(feeProxyAdmin);
        vm.expectEmit(false, false, false, true, address(feeProxy));
        emit PausableUpgradeable.Paused(feeProxyAdmin);
        feeProxy.pause();

        assertTrue(feeProxy.paused(), "contract reports paused");
    }

    function test_unpause_Success_clearsPausedFlagAndEmits() external {
        vm.startPrank(feeProxyAdmin);
        feeProxy.pause();
        vm.expectEmit(false, false, false, true, address(feeProxy));
        emit PausableUpgradeable.Unpaused(feeProxyAdmin);
        feeProxy.unpause();
        vm.stopPrank();

        assertFalse(feeProxy.paused(), "contract reports unpaused");
    }

    function test_registerAffiliate_RevertWhen_GloballyPaused() external {
        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        vm.deal(affiliate, INITIAL_REGISTRATION_FEE);
        vm.startPrank(affiliate);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.registerAffiliate{ value: INITIAL_REGISTRATION_FEE }(_sampleFeeConfig(), affiliateFeeRecipient);
        vm.stopPrank();
    }

    function test_depositVia_RevertWhen_GloballyPaused() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("global-pause-deposit-via", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_depositBatchVia_RevertWhen_GloballyPaused() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("global-pause-deposit-batch-via", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_createAtomsVia_RevertWhen_GloballyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        bytes[] memory atomDatas = _toBytesArray("global-pause-create-atoms");
        uint256[] memory assets = _toUintArray(ATOM_COST[0]);

        vm.deal(users.alice, ATOM_COST[0]);
        vm.startPrank(users.alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.createAtomsVia{ value: ATOM_COST[0] }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createTriplesVia_RevertWhen_GloballyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        bytes32[] memory subjectIds = _toBytes32Array(bytes32(uint256(1)));
        bytes32[] memory predicateIds = _toBytes32Array(bytes32(uint256(2)));
        bytes32[] memory objectIds = _toBytes32Array(bytes32(uint256(3)));
        uint256[] memory assets = _toUintArray(TRIPLE_COST[0]);

        vm.deal(users.alice, TRIPLE_COST[0]);
        vm.startPrank(users.alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.createTriplesVia{ value: TRIPLE_COST[0] }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_claimRefund_AllowedWhileGloballyPaused() external {
        // Seed a pending refund directly to keep the test independent of routing.
        bytes32 slot = keccak256(abi.encode(users.alice, PENDING_REFUND_SLOT)); // pendingRefund mapping
        vm.store(address(feeProxy), slot, bytes32(uint256(0.5 ether)));
        vm.deal(address(feeProxy), 0.5 ether);

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        uint256 aliceBalanceBefore = users.alice.balance;
        vm.startPrank(users.alice);
        feeProxy.claimRefund();
        vm.stopPrank();

        assertEq(users.alice.balance - aliceBalanceBefore, 0.5 ether, "claim works while paused");
    }

    function test_adminCapSetters_AllowedWhileGloballyPaused() external {
        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        vm.startPrank(feeProxyAdmin);
        feeProxy.setMaxFeeBps(1000);
        feeProxy.setMaxFixedFee(2 ether);
        feeProxy.setRegistrationFee(0.5 ether);
        vm.stopPrank();

        assertEq(feeProxy.maxFeeBps(), 1000);
        assertEq(feeProxy.maxFixedFee(), 2 ether);
        assertEq(feeProxy.registrationFee(), 0.5 ether);
    }

    function test_pauseAffiliate_AllowedWhileGloballyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        assertTrue(feeProxy.affiliateConfig(affiliate).paused, "per-affiliate pause still callable");
    }

    function test_unpauseAffiliate_AllowedWhileGloballyPaused() external {
        _registerSampleAffiliate();

        vm.startPrank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);
        feeProxy.pause();
        feeProxy.unpauseAffiliate(affiliate);
        vm.stopPrank();

        assertFalse(feeProxy.affiliateConfig(affiliate).paused, "per-affiliate unpause still callable");
    }

    function test_routingResumesAfterUnpause() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("global-pause-resume", users.alice);

        vm.startPrank(feeProxyAdmin);
        feeProxy.pause();
        feeProxy.unpause();
        vm.stopPrank();

        vm.deal(users.alice, 1 ether);
        vm.startPrank(users.alice);
        uint256 shares = feeProxy.depositVia{ value: 1 ether }(
            affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        assertTrue(shares > 0, "routing resumes after unpause");
    }
}
