// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest, RevertingReceiverMock } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";
import { AffiliateStats, AffiliateUserStats } from "src/interfaces/IFeeProxy.sol";

contract AffiliateStatsTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_affiliateStats_DepositVia_recordsAggregateAndUserCounters() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("stats-deposit-via", users.alice);

        uint256 gross = 2 ether;
        uint256 fee = _depositFee(gross);
        uint256 forwarded = gross - fee;

        vm.deal(users.alice, gross);
        vm.startPrank(users.alice);
        feeProxy.depositVia{ value: gross }(affiliate, users.alice, atomId, CURVE_ID, gross, 0, _looseFeeGuard());
        vm.stopPrank();

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.txCount, 1, "tx count");
        assertEq(stats.uniqueUsers, 1, "unique users");
        assertEq(stats.totalGrossAssets, gross, "total gross");
        assertEq(stats.totalFees, fee, "total fees");
        assertEq(stats.totalForwardedAssets, forwarded, "total forwarded");
        assertEq(stats.depositCount, 1, "deposit count");
        assertEq(stats.depositGrossAssets, gross, "deposit gross");
        assertEq(stats.depositFees, fee, "deposit fees");
        assertEq(stats.depositForwardedAssets, forwarded, "deposit forwarded");
        assertEq(stats.creationCount, 0, "creation count");

        AffiliateUserStats memory userStats = feeProxy.affiliateUserStats(affiliate, users.alice);
        assertEq(userStats.txCount, 1, "user tx count");
        assertEq(userStats.totalGrossAssets, gross, "user gross");
        assertEq(userStats.totalFees, fee, "user fees");
        assertEq(userStats.totalForwardedAssets, forwarded, "user forwarded");
        assertEq(userStats.depositCount, 1, "user deposit count");
        assertEq(userStats.depositGrossAssets, gross, "user deposit gross");
        assertEq(userStats.depositFees, fee, "user deposit fees");
        assertEq(userStats.depositForwardedAssets, forwarded, "user deposit forwarded");
        assertEq(userStats.creationCount, 0, "user creation count");
    }

    function test_affiliateStats_DepositBatch_countsAsOneTransaction() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("stats-batch-a", users.alice);
        bytes32 atomB = _createAtomDirect("stats-batch-b", users.alice);

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

        uint256 gross = 5 ether;
        uint256 fee = _depositFee(gross);
        uint256 forwarded = gross - fee;

        vm.deal(users.alice, gross);
        vm.startPrank(users.alice);
        feeProxy.depositBatchVia{ value: gross }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.txCount, 1, "batch counts as one tx");
        assertEq(stats.uniqueUsers, 1, "unique users");
        assertEq(stats.totalGrossAssets, gross, "total gross");
        assertEq(stats.totalFees, fee, "total fees");
        assertEq(stats.totalForwardedAssets, forwarded, "total forwarded");
        assertEq(stats.depositCount, 1, "deposit count");
        assertEq(stats.depositGrossAssets, gross, "deposit gross");
        assertEq(stats.depositFees, fee, "deposit fees");
        assertEq(stats.depositForwardedAssets, forwarded, "deposit forwarded");
    }

    function test_affiliateStats_CreationRoutes_recordCreationSplit() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms(users.alice);

        bytes[] memory atomDatas = _toBytesArray("stats-create-atom");
        uint256[] memory atomAssets = _toUintArray(2 ether);
        uint256 atomGross = 2 ether;
        uint256 atomFee = _creationFee(atomGross);

        vm.deal(users.alice, atomGross);
        vm.startPrank(users.alice);
        feeProxy.createAtomsVia{ value: atomGross }(affiliate, atomDatas, atomAssets, _looseFeeGuard());
        vm.stopPrank();

        bytes32[] memory subjectIds = _toBytes32Array(subjectId);
        bytes32[] memory predicateIds = _toBytes32Array(predicateId);
        bytes32[] memory objectIds = _toBytes32Array(objectId);
        uint256[] memory tripleAssets = _toUintArray(3 ether);
        uint256 tripleGross = 3 ether;
        uint256 tripleFee = _creationFee(tripleGross);

        vm.deal(users.alice, tripleGross);
        vm.startPrank(users.alice);
        feeProxy.createTriplesVia{ value: tripleGross }(
            affiliate, subjectIds, predicateIds, objectIds, tripleAssets, _looseFeeGuard()
        );
        vm.stopPrank();

        uint256 totalGross = atomGross + tripleGross;
        uint256 totalFee = atomFee + tripleFee;

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.txCount, 2, "tx count");
        assertEq(stats.uniqueUsers, 1, "same user counted once");
        assertEq(stats.totalGrossAssets, totalGross, "total gross");
        assertEq(stats.totalFees, totalFee, "total fees");
        assertEq(stats.totalForwardedAssets, totalGross - totalFee, "total forwarded");
        assertEq(stats.depositCount, 0, "deposit count");
        assertEq(stats.creationCount, 2, "creation tx count");
        assertEq(stats.creationGrossAssets, totalGross, "creation gross");
        assertEq(stats.creationFees, totalFee, "creation fees");
        assertEq(stats.creationForwardedAssets, totalGross - totalFee, "creation forwarded");

        AffiliateUserStats memory userStats = feeProxy.affiliateUserStats(affiliate, users.alice);
        assertEq(userStats.txCount, 2, "user tx count");
        assertEq(userStats.totalGrossAssets, totalGross, "user gross");
        assertEq(userStats.totalFees, totalFee, "user fees");
        assertEq(userStats.totalForwardedAssets, totalGross - totalFee, "user forwarded");
        assertEq(userStats.creationCount, 2, "user creation count");
        assertEq(userStats.creationGrossAssets, totalGross, "user creation gross");
        assertEq(userStats.creationFees, totalFee, "user creation fees");
        assertEq(userStats.creationForwardedAssets, totalGross - totalFee, "user creation forwarded");
    }

    function test_affiliateStats_UniqueUsers_incrementOnlyOnFirstUse() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("stats-unique-a", users.alice);
        bytes32 atomB = _createAtomDirect("stats-unique-b", users.bob);

        vm.deal(users.alice, 3 ether);
        vm.startPrank(users.alice);
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomA, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.alice, atomA, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();

        vm.deal(users.bob, 1 ether);
        vm.startPrank(users.bob);
        feeProxy.depositVia{ value: 1 ether }(affiliate, users.bob, atomB, CURVE_ID, 1 ether, 0, _looseFeeGuard());
        vm.stopPrank();

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.txCount, 3, "three routed txs");
        assertEq(stats.uniqueUsers, 2, "two unique callers");

        assertEq(feeProxy.affiliateUserStats(affiliate, users.alice).txCount, 2, "alice txs");
        assertEq(feeProxy.affiliateUserStats(affiliate, users.bob).txCount, 1, "bob txs");
        assertEq(feeProxy.affiliateUserStats(affiliate, users.charlie).txCount, 0, "unknown user");
    }

    function test_affiliateStats_RefundPushFailureStillRecordsSuccessfulRoute() external {
        _registerSampleAffiliate();
        RevertingReceiverMock revertingSCW = new RevertingReceiverMock(address(feeProxy), address(protocol.multiVault));
        vm.deal(address(revertingSCW), 2 ether);
        revertingSCW.grantCreationApproval();

        bytes[] memory atomDatas = _toBytesArray("stats-refund-push-fail");
        uint256[] memory assets = _toUintArray(1 ether);

        uint256 gross = 1 ether;
        uint256 excess = 0.25 ether;
        uint256 fee = _creationFee(gross);
        uint256 forwarded = gross - fee;

        vm.startPrank(address(revertingSCW));
        feeProxy.createAtomsVia{ value: gross + excess }(affiliate, atomDatas, assets, _looseFeeGuard());
        vm.stopPrank();

        assertEq(feeProxy.pendingRefund(address(revertingSCW)), excess, "excess credited to pull fallback");

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.txCount, 1, "tx count");
        assertEq(stats.uniqueUsers, 1, "unique caller");
        assertEq(stats.totalGrossAssets, gross, "total gross");
        assertEq(stats.totalFees, fee, "total fees");
        assertEq(stats.totalForwardedAssets, forwarded, "total forwarded");
        assertEq(stats.creationCount, 1, "creation count");
        assertEq(stats.creationGrossAssets, gross, "creation gross");
        assertEq(stats.creationFees, fee, "creation fees");
        assertEq(stats.creationForwardedAssets, forwarded, "creation forwarded");

        AffiliateUserStats memory userStats = feeProxy.affiliateUserStats(affiliate, address(revertingSCW));
        assertEq(userStats.txCount, 1, "user tx count");
        assertEq(userStats.totalGrossAssets, gross, "user gross");
        assertEq(userStats.totalFees, fee, "user fees");
        assertEq(userStats.totalForwardedAssets, forwarded, "user forwarded");
        assertEq(userStats.creationCount, 1, "user creation count");
        assertEq(userStats.creationGrossAssets, gross, "user creation gross");
    }

    function _bootstrapTripleAtoms(address creator)
        internal
        returns (bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
    {
        subjectId = _createAtomDirect("stats-triple-subject", creator);
        predicateId = _createAtomDirect("stats-triple-predicate", creator);
        objectId = _createAtomDirect("stats-triple-object", creator);
    }

    function _depositFee(uint256 gross) internal pure returns (uint256) {
        return (gross * SAMPLE_DEPOSIT_BPS) / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
    }

    function _creationFee(uint256 gross) internal pure returns (uint256) {
        return (gross * SAMPLE_CREATION_BPS) / BPS_DIVISOR + SAMPLE_CREATION_FIXED_FEE;
    }
}
