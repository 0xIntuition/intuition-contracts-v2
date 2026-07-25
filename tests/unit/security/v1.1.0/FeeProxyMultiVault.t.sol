// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IMultiVault, ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IFeeProxy, AffiliateStats, AffiliateUserStats, FeeConfig, FeeGuard } from "src/interfaces/IFeeProxy.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";

contract MaliciousAffiliateFeeRecipient {
    enum AttackMode {
        None,
        ReenterFeeProxy,
        MultiVaultOnBehalfDeposit
    }

    IFeeProxy internal immutable feeProxy;
    IMultiVault internal immutable multiVault;
    uint256 internal immutable curveId;

    AttackMode public attackMode;
    bytes32 public targetTermId;
    address public victimReceiver;
    bool public attackAttempted;
    bool public feeProxyReentered;
    bool public multiVaultOnBehalfSucceeded;
    bytes4 public lastRevertSelector;

    bool internal entered;

    constructor(IFeeProxy feeProxy_, IMultiVault multiVault_, uint256 curveId_) {
        feeProxy = feeProxy_;
        multiVault = multiVault_;
        curveId = curveId_;
    }

    receive() external payable {
        if (entered || attackMode == AttackMode.None) return;

        entered = true;
        attackAttempted = true;

        if (attackMode == AttackMode.ReenterFeeProxy) {
            FeeGuard memory guard = FeeGuard({ maxFeeBps: type(uint256).max, maxFixedFee: type(uint256).max });
            try feeProxy.depositVia{ value: msg.value }(
                address(this), address(this), targetTermId, curveId, msg.value, 0, guard
            ) returns (
                uint256
            ) {
                feeProxyReentered = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        } else if (attackMode == AttackMode.MultiVaultOnBehalfDeposit) {
            try multiVault.deposit{ value: msg.value }(victimReceiver, targetTermId, curveId, 0) returns (uint256) {
                multiVaultOnBehalfSucceeded = true;
            } catch (bytes memory reason) {
                lastRevertSelector = _selector(reason);
            }
        }

        entered = false;
    }

    function register(FeeConfig calldata fees) external payable {
        feeProxy.registerAffiliate{ value: msg.value }(fees, address(this));
    }

    function approveFeeProxy() external {
        multiVault.approve(address(feeProxy), ApprovalTypes.ALL);
    }

    function configure(AttackMode mode, bytes32 termId, address receiver) external {
        attackMode = mode;
        targetTermId = termId;
        victimReceiver = receiver;
        attackAttempted = false;
        feeProxyReentered = false;
        multiVaultOnBehalfSucceeded = false;
        lastRevertSelector = bytes4(0);
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length >= 4) {
            assembly {
                selector := mload(add(reason, 0x20))
            }
        }
    }
}

contract FeeProxyMultiVaultTest is FeeProxyBaseTest {
    uint256 internal constant BPS_DIVISOR = 10_000;

    function test_depositBatchVia_revertsAtomicallyWhenDownstreamMinSharesFails() external {
        _registerSampleAffiliate();
        bytes32 atomId = _createAtomDirect("batch-min-shares", users.alice);

        bytes32[] memory termIds = _toBytes32Array(atomId);
        uint256[] memory curveIds = _toUintArray(CURVE_ID);
        uint256[] memory assets = _toUintArray(2 ether);
        uint256[] memory minShares = _toUintArray(type(uint256).max);

        uint256 affiliateBalanceBefore = affiliateFeeRecipient.balance;
        uint256 proxyBalanceBefore = address(feeProxy).balance;
        uint256 aliceSharesBefore = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        (uint256 vaultAssetsBefore, uint256 vaultSharesBefore) = protocol.multiVault.getVault(atomId, CURVE_ID);

        vm.deal(users.alice, 2 ether);
        vm.startPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        feeProxy.depositBatchVia{ value: 2 ether }(
            affiliate, users.alice, termIds, curveIds, assets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        _assertAffiliateStatsEmpty(affiliate, users.alice);
        assertEq(affiliateFeeRecipient.balance, affiliateBalanceBefore, "affiliate fee must roll back");
        assertEq(feeProxy.pendingRefund(users.alice), 0, "no refund ledger on reverted route");
        assertEq(address(feeProxy).balance, proxyBalanceBefore, "proxy balance unchanged");
        assertEq(protocol.multiVault.getShares(users.alice, atomId, CURVE_ID), aliceSharesBefore, "shares unchanged");
        (uint256 vaultAssetsAfter, uint256 vaultSharesAfter) = protocol.multiVault.getVault(atomId, CURVE_ID);
        assertEq(vaultAssetsAfter, vaultAssetsBefore, "vault assets unchanged");
        assertEq(vaultSharesAfter, vaultSharesBefore, "vault shares unchanged");
    }

    function test_depositBatchVia_revertsAtomicallyWhenAllocatedLegFallsBelowMultiVaultMinimum() external {
        _registerSampleAffiliate();
        bytes32 atomA = _createAtomDirect("below-min-a", users.alice);
        bytes32 atomB = _createAtomDirect("below-min-b", users.alice);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomA;
        termIds[1] = atomB;

        uint256[] memory curveIds = new uint256[](2);
        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;

        uint256[] memory grossAssets = new uint256[](2);
        grossAssets[0] = MIN_DEPOSIT;
        grossAssets[1] = 10 ether;

        uint256[] memory minShares = new uint256[](2);
        uint256 totalGross = _sum(grossAssets);

        uint256 affiliateBalanceBefore = affiliateFeeRecipient.balance;
        uint256 aliceSharesBefore = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositBelowMinimumDeposit.selector);
        feeProxy.depositBatchVia{ value: totalGross }(
            affiliate, users.alice, termIds, curveIds, grossAssets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        _assertAffiliateStatsEmpty(affiliate, users.alice);
        assertEq(affiliateFeeRecipient.balance, affiliateBalanceBefore, "prepaid fee must roll back");
        assertEq(protocol.multiVault.getShares(users.alice, atomA, CURVE_ID), aliceSharesBefore, "no partial mint");
        assertEq(address(feeProxy).balance, 0, "proxy does not retain reverted value");
    }

    function test_createTriplesVia_revertsAtomicallyWhenSecondLegDuplicatesFirstLeg() external {
        _registerSampleAffiliate();
        (bytes32 subjectId, bytes32 predicateId, bytes32 objectId) = _bootstrapTripleAtoms("duplicate");
        bytes32 tripleId = protocol.multiVault.calculateTripleId(subjectId, predicateId, objectId);

        bytes32[] memory subjectIds = new bytes32[](2);
        subjectIds[0] = subjectId;
        subjectIds[1] = subjectId;

        bytes32[] memory predicateIds = new bytes32[](2);
        predicateIds[0] = predicateId;
        predicateIds[1] = predicateId;

        bytes32[] memory objectIds = new bytes32[](2);
        objectIds[0] = objectId;
        objectIds[1] = objectId;

        uint256[] memory grossAssets = new uint256[](2);
        grossAssets[0] = 4 ether;
        grossAssets[1] = 4 ether;
        uint256 totalGross = _sum(grossAssets);

        uint256 affiliateBalanceBefore = affiliateFeeRecipient.balance;

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVault.MultiVault_TripleExists.selector, tripleId, subjectId, predicateId, objectId
            )
        );
        feeProxy.createTriplesVia{ value: totalGross }(
            affiliate, subjectIds, predicateIds, objectIds, grossAssets, _looseFeeGuard()
        );
        vm.stopPrank();

        _assertAffiliateStatsEmpty(affiliate, users.alice);
        assertFalse(protocol.multiVault.isTermCreated(tripleId), "first triple leg must roll back");
        assertEq(affiliateFeeRecipient.balance, affiliateBalanceBefore, "affiliate fee must roll back");
        assertEq(address(feeProxy).balance, 0, "proxy does not retain reverted value");
    }

    function test_depositBatchVia_roundingDustMatchesDirectMultiVaultForwardedAssets() external {
        _registerSampleAffiliate();
        bytes32[] memory termIds = new bytes32[](3);
        termIds[0] = _createAtomDirect("round-a", users.alice);
        termIds[1] = _createAtomDirect("round-b", users.alice);
        termIds[2] = _createAtomDirect("round-c", users.alice);

        uint256[] memory curveIds = new uint256[](3);
        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;
        curveIds[2] = CURVE_ID;

        uint256[] memory grossAssets = new uint256[](3);
        grossAssets[0] = 1 ether + 1;
        grossAssets[1] = 2 ether + 2;
        grossAssets[2] = 3 ether + 3;
        uint256 totalGross = _sum(grossAssets);

        uint256 fee = totalGross * SAMPLE_DEPOSIT_BPS / BPS_DIVISOR + SAMPLE_DEPOSIT_FIXED_FEE;
        uint256[] memory forwardedAssets = _allocate(grossAssets, totalGross - fee, totalGross);
        uint256[] memory minShares = new uint256[](3);

        uint256 snapshot = vm.snapshotState();

        vm.deal(users.alice, totalGross - fee);
        vm.startPrank(users.alice);
        uint256[] memory directShares = protocol.multiVault.depositBatch{ value: totalGross - fee }(
            users.alice, termIds, curveIds, forwardedAssets, minShares
        );
        vm.stopPrank();
        VaultProbe[] memory directProbes = _vaultProbes(termIds, users.alice);

        require(vm.revertToState(snapshot), "revertToState failed");

        vm.deal(users.alice, totalGross);
        vm.startPrank(users.alice);
        uint256[] memory viaProxyShares = feeProxy.depositBatchVia{ value: totalGross }(
            affiliate, users.alice, termIds, curveIds, grossAssets, minShares, _looseFeeGuard()
        );
        vm.stopPrank();

        assertEq(viaProxyShares, directShares, "proxy shares match direct forwarded-assets path");
        _assertVaultProbesEq(_vaultProbes(termIds, users.alice), directProbes);
        assertEq(address(feeProxy).balance, 0, "proxy holds no rounding dust");
    }

    function test_maliciousFeeRecipient_cannotReenterFeeProxyDuringAffiliatePayment() external {
        bytes32 atomId = _createAtomDirect("malicious-reenter-proxy", users.alice);
        MaliciousAffiliateFeeRecipient malicious = new MaliciousAffiliateFeeRecipient(
            IFeeProxy(address(feeProxy)), IMultiVault(address(protocol.multiVault)), CURVE_ID
        );

        vm.deal(address(malicious), INITIAL_REGISTRATION_FEE);
        malicious.register{ value: INITIAL_REGISTRATION_FEE }(_sampleFeeConfig());
        malicious.approveFeeProxy();
        malicious.configure(MaliciousAffiliateFeeRecipient.AttackMode.ReenterFeeProxy, atomId, address(malicious));

        vm.deal(users.alice, 20 ether);
        vm.startPrank(users.alice);
        feeProxy.depositVia{ value: 20 ether }(
            address(malicious), users.alice, atomId, CURVE_ID, 20 ether, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        assertTrue(malicious.attackAttempted(), "fee recipient should attempt reentry");
        assertFalse(malicious.feeProxyReentered(), "FeeProxy reentry must fail");
        assertEq(
            malicious.lastRevertSelector(),
            ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector,
            "nonReentrant blocks nested route"
        );
        assertEq(address(feeProxy).balance, 0, "proxy balance conserved");
    }

    function test_maliciousFeeRecipient_cannotDepositIntoVictimReceiverWithoutVictimApproval() external {
        bytes32 atomId = _createAtomDirect("malicious-multivault", users.alice);
        MaliciousAffiliateFeeRecipient malicious = new MaliciousAffiliateFeeRecipient(
            IFeeProxy(address(feeProxy)), IMultiVault(address(protocol.multiVault)), CURVE_ID
        );

        vm.deal(address(malicious), INITIAL_REGISTRATION_FEE);
        malicious.register{ value: INITIAL_REGISTRATION_FEE }(_sampleFeeConfig());
        malicious.configure(MaliciousAffiliateFeeRecipient.AttackMode.MultiVaultOnBehalfDeposit, atomId, users.alice);

        uint256 aliceSharesBefore = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);

        vm.deal(users.alice, 20 ether);
        vm.startPrank(users.alice);
        uint256 routedShares = feeProxy.depositVia{ value: 20 ether }(
            address(malicious), users.alice, atomId, CURVE_ID, 20 ether, 0, _looseFeeGuard()
        );
        vm.stopPrank();

        assertTrue(malicious.attackAttempted(), "fee recipient should attempt MultiVault deposit");
        assertFalse(malicious.multiVaultOnBehalfSucceeded(), "unapproved victim deposit must fail");
        assertEq(
            malicious.lastRevertSelector(),
            MultiVault.MultiVault_SenderNotApproved.selector,
            "approval gate blocks on-behalf mutation"
        );
        assertEq(
            protocol.multiVault.getShares(users.alice, atomId, CURVE_ID),
            aliceSharesBefore + routedShares,
            "victim receives only the intended routed shares"
        );
        assertEq(address(feeProxy).balance, 0, "proxy balance conserved");
    }

    struct VaultProbe {
        uint256 totalAssets;
        uint256 totalShares;
        uint256 holderShares;
        uint256 accumulatedWalletFees;
    }

    function _bootstrapTripleAtoms(string memory salt)
        internal
        returns (bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
    {
        subjectId = _createAtomDirect(string.concat("triple-subject-", salt), users.alice);
        predicateId = _createAtomDirect(string.concat("triple-predicate-", salt), users.alice);
        objectId = _createAtomDirect(string.concat("triple-object-", salt), users.alice);
    }

    function _vaultProbe(bytes32 atomId, address holder) internal view returns (VaultProbe memory probe) {
        (probe.totalAssets, probe.totalShares) = protocol.multiVault.getVault(atomId, CURVE_ID);
        probe.holderShares = protocol.multiVault.getShares(holder, atomId, CURVE_ID);
        address atomWallet = protocol.multiVault.computeAtomWalletAddr(atomId);
        probe.accumulatedWalletFees = protocol.multiVault.accumulatedAtomWalletDepositFees(atomWallet);
    }

    function _assertVaultProbeEq(VaultProbe memory actual, VaultProbe memory expected, string memory label) internal {
        assertEq(actual.totalAssets, expected.totalAssets, string.concat(label, ": total assets"));
        assertEq(actual.totalShares, expected.totalShares, string.concat(label, ": total shares"));
        assertEq(actual.holderShares, expected.holderShares, string.concat(label, ": holder shares"));
        assertEq(actual.accumulatedWalletFees, expected.accumulatedWalletFees, string.concat(label, ": wallet fees"));
    }

    function _vaultProbes(bytes32[] memory termIds, address holder) internal view returns (VaultProbe[] memory probes) {
        probes = new VaultProbe[](termIds.length);
        for (uint256 i; i < termIds.length; ++i) {
            probes[i] = _vaultProbe(termIds[i], holder);
        }
    }

    function _assertVaultProbesEq(VaultProbe[] memory actual, VaultProbe[] memory expected) internal {
        assertEq(actual.length, expected.length, "probe length");
        for (uint256 i; i < actual.length; ++i) {
            _assertVaultProbeEq(actual[i], expected[i], "term");
        }
    }

    function _assertAffiliateStatsEmpty(address affiliate_, address user) internal view {
        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate_);
        assertEq(stats.txCount, 0, "affiliate txCount unchanged");
        assertEq(stats.totalGrossAssets, 0, "affiliate gross unchanged");
        assertEq(stats.totalFees, 0, "affiliate fees unchanged");
        assertEq(stats.totalForwardedAssets, 0, "affiliate forwarded unchanged");

        AffiliateUserStats memory userStats = feeProxy.affiliateUserStats(affiliate_, user);
        assertEq(userStats.txCount, 0, "affiliate user txCount unchanged");
        assertEq(userStats.totalGrossAssets, 0, "affiliate user gross unchanged");
        assertEq(userStats.totalFees, 0, "affiliate user fees unchanged");
        assertEq(userStats.totalForwardedAssets, 0, "affiliate user forwarded unchanged");
    }

    function _allocate(uint256[] memory assets, uint256 totalForwarded, uint256 totalGross)
        internal
        pure
        returns (uint256[] memory forwardedAssets)
    {
        uint256 length = assets.length;
        forwardedAssets = new uint256[](length);
        uint256 last = length - 1;
        uint256 accumulated;
        for (uint256 i; i < last; ++i) {
            uint256 piece = assets[i] * totalForwarded / totalGross;
            forwardedAssets[i] = piece;
            accumulated += piece;
        }
        forwardedAssets[last] = totalForwarded - accumulated;
    }

    function _sum(uint256[] memory values) internal pure returns (uint256 total) {
        for (uint256 i; i < values.length; ++i) {
            total += values[i];
        }
    }
}
