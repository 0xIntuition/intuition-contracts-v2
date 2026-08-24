// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy } from "src/interfaces/IFeeProxy.sol";

contract CreateTriplesViaTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function _bootstrapTripleAtoms(address creator)
        internal
        returns (bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
    {
        subjectId = _createAtomDirect("triple-via-subject", creator);
        predicateId = _createAtomDirect("triple-via-predicate", creator);
        objectId = _createAtomDirect("triple-via-object", creator);
    }

    function test_createTriplesVia_Success_creditsCallerAndAccruesFee() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms(users.alice);

        bytes32[] memory subjectIds = _toBytes32Array(subjectId);
        bytes32[] memory predicateIds = _toBytes32Array(predicateId);
        bytes32[] memory objectIds = _toBytes32Array(objectId);
        uint256[] memory assets = _toUintArray(3 ether);

        uint256 totalGross = 3 ether;
        uint256 expectedFee = (totalGross * SAMPLE_CREATION_BPS) / BPS_DIVISOR + SAMPLE_CREATION_FIXED_FEE;
        uint256 recipientBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        bytes32[] memory tripleIds = feeProxy.createTriplesVia{ value: totalGross }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(tripleIds.length, 1);
        assertTrue(protocol.multiVault.isTermCreated(tripleIds[0]), "triple exists");
        assertEq(
            affiliateFeeRecipient.balance - recipientBalanceBefore,
            expectedFee,
            "affiliate fee recipient received aggregate fee"
        );
        assertEq(address(feeProxy).balance, 0, "proxy holds no residual ETH");
    }

    function test_createTriplesVia_RevertWhen_CreatorHasNotApprovedProxy() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms(users.alice);

        // Revoke proxy approval on MultiVault.
        vm.startPrank(users.alice);
        protocol.multiVault.approve(address(feeProxy), ApprovalTypes.NONE);
        vm.stopPrank();

        bytes32[] memory subjectIds = _toBytes32Array(subjectId);
        bytes32[] memory predicateIds = _toBytes32Array(predicateId);
        bytes32[] memory objectIds = _toBytes32Array(objectId);
        uint256[] memory assets = _toUintArray(3 ether);

        vm.deal(users.alice, 3 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_ProxyNotApprovedForCreation.selector, users.alice, address(feeProxy)
            )
        );
        feeProxy.createTriplesVia{ value: 3 ether }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_createTriplesVia_RevertWhen_LengthMismatch_SubjectVsObject() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId,) = _bootstrapTripleAtoms(users.alice);

        bytes32[] memory subjectIds = _toBytes32Array(subjectId);
        bytes32[] memory predicateIds = _toBytes32Array(predicateId);
        bytes32[] memory objectIds = new bytes32[](0); // length mismatch
        uint256[] memory assets = _toUintArray(3 ether);

        vm.deal(users.alice, 3 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.createTriplesVia{ value: 3 ether }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_createTriplesVia_RevertWhen_AnyLegHasZeroAssets() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms(users.alice);
        // Second triple reuses the same atoms; assets[1] = 0 should be rejected.
        bytes32 subjectId2 = _createAtomDirect("triple-via-extra-subject", users.alice);
        bytes32 predicateId2 = _createAtomDirect("triple-via-extra-predicate", users.alice);
        bytes32 objectId2 = _createAtomDirect("triple-via-extra-object", users.alice);

        bytes32[] memory subjectIds = new bytes32[](2);
        subjectIds[0] = subjectId;
        subjectIds[1] = subjectId2;
        bytes32[] memory predicateIds = new bytes32[](2);
        predicateIds[0] = predicateId;
        predicateIds[1] = predicateId2;
        bytes32[] memory objectIds = new bytes32[](2);
        objectIds[0] = objectId;
        objectIds[1] = objectId2;
        uint256[] memory assets = new uint256[](2);
        assets[0] = 3 ether;
        assets[1] = 0;

        vm.deal(users.alice, 3 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_ZeroAssets.selector);
        feeProxy.createTriplesVia{ value: 3 ether }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();
    }

    function test_createTriplesVia_RevertWhen_EmptyArrays() external {
        _registerSampleAffiliate();

        bytes32[] memory subjectIds = new bytes32[](0);
        bytes32[] memory predicateIds = new bytes32[](0);
        bytes32[] memory objectIds = new bytes32[](0);
        uint256[] memory assets = new uint256[](0);

        vm.startPrank(users.alice);
        vm.expectRevert(IFeeProxy.FeeProxy_LengthMismatch.selector);
        feeProxy.createTriplesVia{ value: 0 }(affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard());
        vm.stopPrank();
    }

    function test_createTriplesVia_Success_refundsExcessMsgValue() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms(users.alice);

        bytes32[] memory subjectIds = _toBytes32Array(subjectId);
        bytes32[] memory predicateIds = _toBytes32Array(predicateId);
        bytes32[] memory objectIds = _toBytes32Array(objectId);
        uint256[] memory assets = _toUintArray(2 ether);

        uint256 totalGross = 2 ether;
        uint256 excess = 0.25 ether;

        vm.deal(users.alice, totalGross + excess);
        uint256 aliceBalanceBefore = users.alice.balance;
        vm.startPrank(users.alice);
        feeProxy.createTriplesVia{ value: totalGross + excess }(
            affiliate, subjectIds, predicateIds, objectIds, assets, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(aliceBalanceBefore - users.alice.balance, totalGross, "excess refunded");
        assertEq(address(feeProxy).balance, 0);
    }
}
