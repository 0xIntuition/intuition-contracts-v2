// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { IFeeProxy, FeeGuard } from "src/interfaces/IFeeProxy.sol";

contract PauseAffiliateTest is FeeProxyBaseTest {
    function test_pauseAffiliate_Success_emitsEventAndSetsFlag() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        vm.expectEmit(true, false, false, true, address(feeProxy));
        emit IFeeProxy.AffiliatePaused(affiliate);
        feeProxy.pauseAffiliate(affiliate);

        assertTrue(feeProxy.isAffiliateRegistered(affiliate), "row still registered");
        assertFalse(feeProxy.isAffiliateActive(affiliate), "row no longer active");
        assertTrue(feeProxy.affiliateConfig(affiliate).paused, "paused flag set");
    }

    function test_pauseAffiliate_RevertWhen_NotAdmin() external {
        _registerSampleAffiliate();

        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, feeProxy.PAUSER_ROLE()
            )
        );
        feeProxy.pauseAffiliate(affiliate);
        vm.stopPrank();
    }

    function test_pauseAffiliate_RevertWhen_NotRegistered() external {
        vm.prank(feeProxyAdmin);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateNotRegistered.selector, affiliate));
        feeProxy.pauseAffiliate(affiliate);
    }

    function test_pauseAffiliate_RevertWhen_AlreadyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        vm.prank(feeProxyAdmin);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliateAlreadyPaused.selector, affiliate));
        feeProxy.pauseAffiliate(affiliate);
    }

    function test_pauseAffiliate_BlocksDepositVia() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("paused-affiliate-deposit", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        vm.deal(users.alice, 10 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomId, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_pauseAffiliate_BlocksDepositBatchVia() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("paused-affiliate-deposit-batch", users.alice);

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(1 ether);
        uint256[] memory minShares = _toUintArray(0);

        vm.deal(users.alice, 10 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.depositBatchVia{ value: 1 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_pauseAffiliate_BlocksCreateAtomsVia() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        bytes[] memory atomDatas = _toBytesArray("paused-affiliate-create");
        uint256[] memory assets = _toUintArray(ATOM_COST[0]);

        vm.deal(users.alice, 10 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.createAtomsVia{ value: ATOM_COST[0] }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_pauseAffiliate_BlocksCreateTriplesVia() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        bytes32[] memory subjectIds = _toBytes32Array(bytes32(uint256(1)));
        bytes32[] memory predicateIds = _toBytes32Array(bytes32(uint256(2)));
        bytes32[] memory objectIds = _toBytes32Array(bytes32(uint256(3)));
        uint256[] memory assets = _toUintArray(TRIPLE_COST[0]);

        vm.deal(users.alice, 10 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.createTriplesVia{ value: TRIPLE_COST[0] }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_pauseAffiliate_DoesNotBlockRedeemDirectly() external {
        _registerSampleAffiliate();

        // Alice creates an atom + deposit directly, gets shares.
        bytes32 atomId = _createAtomDirect("paused-affiliate-redeem", users.alice);
        uint256 shares = _makeDepositDirect(users.alice, users.alice, atomId, CURVE_ID, 1 ether);
        assertTrue(shares > 0);

        // Admin pauses the affiliate.
        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        // Alice redeems directly against MultiVault - unaffected by the proxy.
        vm.startPrank(users.alice);
        uint256 received = protocol.multiVault.redeem(users.alice, atomId, CURVE_ID, shares, 0);
        vm.stopPrank();

        assertTrue(received > 0, "redemption must still succeed");
    }
}
