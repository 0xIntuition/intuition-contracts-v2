// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes, IMultiVault } from "src/interfaces/IMultiVault.sol";
import { AffiliateStats, IFeeProxy } from "src/interfaces/IFeeProxy.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract CreateAtomsWithUrisViaTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_createAtomsWithUrisVia_Success_PreservesUserAttributionAndFeeAccounting() external {
        _registerSampleAffiliate();

        bytes memory atomData = "int:isrc:GBDUW0000059";
        bytes32 expectedAtomId = calculateAtomId(atomData);
        bytes[] memory atomDatas = _toBytesArray(string(atomData));
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = _sampleUris();
        uint256 totalGross = 2 ether;
        uint256 expectedFee = (totalGross * SAMPLE_CREATION_BPS) / BPS_DIVISOR + SAMPLE_CREATION_FIXED_FEE;
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.expectEmit(true, true, false, true, address(protocol.multiVault));
        emit IMultiVault.AtomContextRegistered(expectedAtomId, users.alice, uris[0]);
        vm.expectEmit(true, true, false, true, address(feeProxy));
        emit IFeeProxy.CreatedAtomsVia(
            users.alice, affiliate, totalGross, expectedFee, totalGross - expectedFee, atomDatas.length
        );

        vm.deal(users.alice, totalGross);
        vm.prank(users.alice);
        bytes32[] memory ids =
            feeProxy.createAtomsWithUrisVia{ value: totalGross }(affiliate, atomDatas, assets, uris, _looseFeeGuard());

        assertEq(ids[0], expectedAtomId, "context must not affect identity");
        assertEq(protocol.multiVault.getAtomCreator(ids[0]), users.alice, "caller must be credited as creator");
        assertNotEq(protocol.multiVault.getAtomCreator(ids[0]), address(feeProxy), "proxy must not own attribution");
        assertEq(
            affiliateFeeRecipient.balance - recipientBalanceBefore, expectedFee, "affiliate fee must be unchanged"
        );
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.creationCount, 1, "URI-aware creation must update affiliate creation count");
        assertEq(stats.creationGrossAssets, totalGross, "URI-aware creation must record gross assets");
        assertEq(stats.creationFees, expectedFee, "URI-aware creation must record fees");
        assertEq(
            stats.creationForwardedAssets, totalGross - expectedFee, "URI-aware creation must record forwarded assets"
        );
    }

    function test_createAtomsWithUrisVia_Success_RefundsExcessMsgValue() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("uri-via-refund");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = _sampleUris();
        uint256 totalGross = 2 ether;
        uint256 excess = 0.4 ether;

        vm.deal(users.alice, totalGross + excess);
        uint256 aliceBalanceBefore = users.alice.balance;
        vm.prank(users.alice);
        feeProxy.createAtomsWithUrisVia{ value: totalGross + excess }(
            affiliate, atomDatas, assets, uris, _looseFeeGuard()
        );

        assertEq(aliceBalanceBefore - users.alice.balance, totalGross, "excess must be refunded to caller");
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
        assertEq(feeProxy.pendingRefund(users.alice), 0, "EOA push refund must not create pull credit");
    }

    function test_createAtomsWithUrisVia_RevertWhen_CreatorHasNotApprovedProxy() external {
        _registerSampleAffiliate();

        vm.prank(users.alice);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);

        bytes[] memory atomDatas = _toBytesArray("uri-via-no-approval");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = _sampleUris();

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_ProxyNotApprovedForCreation.selector, users.alice, address(feeProxy)
            )
        );
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());
    }

    function test_createAtomsWithUrisVia_RevertWhen_UrisLengthMismatch() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("uri-via-length-mismatch");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = new bytes[][](0);

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());
    }

    function test_createAtomsWithUrisVia_RevertWhen_UriCountExceedsConfiguredMaximum() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("uri-via-too-many");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = new bytes[][](1);
        uris[0] = new bytes[](6);
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;
        bytes32 atomId = calculateAtomId(atomDatas[0]);

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_AtomUriCountExceeded.selector);
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());

        assertEq(affiliateFeeRecipient.balance, recipientBalanceBefore, "revert must roll back affiliate payment");
        assertEq(feeProxy.affiliateStats(affiliate).creationCount, 0, "revert must roll back affiliate stats");
        assertFalse(protocol.multiVault.isTermCreated(atomId), "rejected URI payload must not create an atom");
        assertEq(address(feeProxy).balance, 0, "proxy must not retain rejected payment");
    }

    function test_createAtomsWithUrisVia_RevertWhen_UriLengthExceedsConfiguredMaximum() external {
        _registerSampleAffiliate();

        bytes[] memory atomDatas = _toBytesArray("uri-via-too-long");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = new bytes[][](1);
        uris[0] = new bytes[](1);
        uris[0][0] = new bytes(701);

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_AtomUriLengthExceeded.selector);
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());
    }

    function test_createAtomsWithUrisVia_RevertWhen_GloballyPaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pause();

        bytes[] memory atomDatas = _toBytesArray("uri-via-paused");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = _sampleUris();

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());
    }

    function test_createAtomsWithUrisVia_RevertWhen_AffiliatePaused() external {
        _registerSampleAffiliate();

        vm.prank(feeProxyAdmin);
        feeProxy.pauseAffiliate(affiliate);

        bytes[] memory atomDatas = _toBytesArray("uri-via-affiliate-paused");
        uint256[] memory assets = _toUintArray(2 ether);
        bytes[][] memory uris = _sampleUris();

        vm.deal(users.alice, 2 ether);
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_AffiliatePaused.selector, affiliate));
        feeProxy.createAtomsWithUrisVia{ value: 2 ether }(affiliate, atomDatas, assets, uris, _looseFeeGuard());
    }

    function _sampleUris() private pure returns (bytes[][] memory uris) {
        uris = new bytes[][](1);
        uris[0] = new bytes[](2);
        uris[0][0] = "ipfs://bafy-context";
        uris[0][1] = "https://musicbrainz.org/recording/example";
    }
}
