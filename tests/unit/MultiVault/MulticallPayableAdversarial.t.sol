// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract MulticallPayableAdversarialTest is BaseTest {
    uint256 internal CURVE_ID;

    struct Probe {
        uint256 multiVaultBalance;
        uint256 totalTermsCreated;
        uint256 currentEpochProtocolFees;
        int256 totalUtilization;
        int256 personalUtilization;
        uint256 vaultTotalAssets;
        uint256 vaultTotalShares;
        uint256 holderShares;
        bool termCreated;
        address atomCreator;
    }

    struct AllAllowedScenario {
        bytes[] atomData;
        uint256[] atomAssets;
        bytes32 subjectId;
        bytes32 predicateId;
        bytes32 objectId;
        bytes32 batchAtomId;
        bytes32 tripleId;
        bytes32[] subjectIds;
        bytes32[] predicateIds;
        bytes32[] objectIds;
        uint256[] tripleAssets;
        uint256 singleDepositValue;
        bytes32[] batchTermIds;
        uint256[] batchCurveIds;
        uint256[] batchAssets;
        uint256[] minShares;
    }

    struct AllAllowedProbes {
        Probe subject;
        Probe triple;
        Probe batchAtom;
    }

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    function test_multicallPayable_twoDepositsMatchesSeparateCallsExactly() public {
        bytes32 atomA = createSimpleAtom("adv-two-deposit-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("adv-two-deposit-B", ATOM_COST[0], users.alice);
        uint256 valueA = 2 ether;
        uint256 valueB = 5 ether;

        uint256 snap = vm.snapshotState();

        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: valueA }(users.alice, atomA, CURVE_ID, 0);
        protocol.multiVault.deposit{ value: valueB }(users.alice, atomB, CURVE_ID, 0);
        Probe memory directA = _probe(atomA, users.alice);
        Probe memory directB = _probe(atomB, users.alice);

        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomB, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = valueA;
        values[1] = valueB;

        resetPrank(users.alice);
        protocol.multiVault.multicallPayable{ value: valueA + valueB }(data, values);
        Probe memory viaMulticallA = _probe(atomA, users.alice);
        Probe memory viaMulticallB = _probe(atomB, users.alice);

        _assertProbeEq(directA, viaMulticallA, "atom A");
        _assertProbeEq(directB, viaMulticallB, "atom B");
    }

    function test_multicallPayable_zeroValueDepositCannotReplayOuterValue() public {
        bytes32 atomA = createSimpleAtom("adv-zero-replay-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("adv-zero-replay-B", ATOM_COST[0], users.alice);
        Probe memory beforeA = _probe(atomA, users.alice);
        Probe memory beforeB = _probe(atomB, users.alice);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomB, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = 3 ether;
        values[1] = 0;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositBelowMinimumDeposit.selector);
        protocol.multiVault.multicallPayable{ value: values[0] + values[1] }(data, values);

        _assertProbeEq(beforeA, _probe(atomA, users.alice), "first deposit rolled back");
        _assertProbeEq(beforeB, _probe(atomB, users.alice), "zero-value deposit unchanged");
    }

    function test_multicallPayable_depositBatchCannotBorrowValueFromSiblingSubcall() public {
        bytes32 atomA = createSimpleAtom("adv-borrow-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("adv-borrow-B", ATOM_COST[0], users.alice);
        bytes32 atomC = createSimpleAtom("adv-borrow-C", ATOM_COST[0], users.alice);
        Probe memory beforeA = _probe(atomA, users.alice);
        Probe memory beforeB = _probe(atomB, users.alice);
        Probe memory beforeC = _probe(atomC, users.alice);

        bytes32[] memory batchTermIds = new bytes32[](2);
        batchTermIds[0] = atomB;
        batchTermIds[1] = atomC;

        uint256[] memory batchCurveIds = new uint256[](2);
        batchCurveIds[0] = CURVE_ID;
        batchCurveIds[1] = CURVE_ID;

        uint256[] memory batchAssets = new uint256[](2);
        batchAssets[0] = 2 ether;
        batchAssets[1] = 3 ether;

        uint256[] memory minShares = new uint256[](2);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        data[1] = abi.encodeCall(
            IMultiVault.depositBatch, (users.alice, batchTermIds, batchCurveIds, batchAssets, minShares)
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 4 ether;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientBalance.selector);
        protocol.multiVault.multicallPayable{ value: values[0] + values[1] }(data, values);

        _assertProbeEq(beforeA, _probe(atomA, users.alice), "sibling deposit rolled back");
        _assertProbeEq(beforeB, _probe(atomB, users.alice), "batch atom B unchanged");
        _assertProbeEq(beforeC, _probe(atomC, users.alice), "batch atom C unchanged");
    }

    function test_multicallPayable_allAllowedSelectorsMatchSeparateCallsExactly() public {
        AllAllowedScenario memory scenario = _allAllowedScenario();

        uint256 snap = vm.snapshotState();

        _runAllAllowedDirect(scenario);
        AllAllowedProbes memory direct = _allAllowedProbes(scenario);

        require(vm.revertToState(snap), "revertToState failed");

        _runAllAllowedMulticall(scenario);
        AllAllowedProbes memory viaMulticall = _allAllowedProbes(scenario);

        _assertProbeEq(direct.subject, viaMulticall.subject, "subject atom");
        _assertProbeEq(direct.triple, viaMulticall.triple, "triple");
        _assertProbeEq(direct.batchAtom, viaMulticall.batchAtom, "batch atom");
    }

    function test_multicallPayable_failedBatchDoesNotLeaveTransientGuardStuck() public {
        bytes32 atomId = createSimpleAtom("adv-transient-cleanup", ATOM_COST[0], users.alice);
        uint256 sharesBefore = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);

        bytes[] memory badData = new bytes[](1);
        badData[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomId, CURVE_ID, 0));

        uint256[] memory badValues = new uint256[](1);
        badValues[0] = 0;

        resetPrank(users.alice);
        (bool ok, bytes memory ret) =
            address(protocol.multiVault).call(abi.encodeCall(IMultiVault.multicallPayable, (badData, badValues)));
        assertFalse(ok, "bad multicallPayable should revert");
        assertEq(_revertSelector(ret), MultiVault.MultiVault_DepositBelowMinimumDeposit.selector);

        protocol.multiVault.deposit{ value: 2 ether }(users.alice, atomId, CURVE_ID, 0);

        assertGt(protocol.multiVault.getShares(users.alice, atomId, CURVE_ID), sharesBefore);
    }

    function _allAllowedScenario() internal view returns (AllAllowedScenario memory scenario) {
        scenario.atomData = new bytes[](4);
        scenario.atomData[0] = abi.encodePacked("adv-all-subject");
        scenario.atomData[1] = abi.encodePacked("adv-all-predicate");
        scenario.atomData[2] = abi.encodePacked("adv-all-object");
        scenario.atomData[3] = abi.encodePacked("adv-all-batch-atom");

        scenario.subjectId = calculateAtomId(scenario.atomData[0]);
        scenario.predicateId = calculateAtomId(scenario.atomData[1]);
        scenario.objectId = calculateAtomId(scenario.atomData[2]);
        scenario.batchAtomId = calculateAtomId(scenario.atomData[3]);
        scenario.tripleId =
            protocol.multiVault.calculateTripleId(scenario.subjectId, scenario.predicateId, scenario.objectId);

        scenario.atomAssets = _uintArray4(ATOM_COST[0] + 1 ether, ATOM_COST[0], ATOM_COST[0], ATOM_COST[0]);

        scenario.subjectIds = new bytes32[](1);
        scenario.predicateIds = new bytes32[](1);
        scenario.objectIds = new bytes32[](1);
        scenario.subjectIds[0] = scenario.subjectId;
        scenario.predicateIds[0] = scenario.predicateId;
        scenario.objectIds[0] = scenario.objectId;

        scenario.tripleAssets = new uint256[](1);
        scenario.tripleAssets[0] = TRIPLE_COST[0] + 2 ether;

        scenario.singleDepositValue = 3 ether;
        scenario.batchTermIds = new bytes32[](2);
        scenario.batchTermIds[0] = scenario.tripleId;
        scenario.batchTermIds[1] = scenario.batchAtomId;

        scenario.batchCurveIds = new uint256[](2);
        scenario.batchCurveIds[0] = CURVE_ID;
        scenario.batchCurveIds[1] = CURVE_ID;

        scenario.batchAssets = new uint256[](2);
        scenario.batchAssets[0] = 4 ether;
        scenario.batchAssets[1] = 5 ether;

        scenario.minShares = new uint256[](2);
    }

    function _runAllAllowedDirect(AllAllowedScenario memory scenario) internal {
        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: _sum(scenario.atomAssets) }(scenario.atomData, scenario.atomAssets);
        protocol.multiVault.createTriples{ value: scenario.tripleAssets[0] }(
            scenario.subjectIds, scenario.predicateIds, scenario.objectIds, scenario.tripleAssets
        );
        protocol.multiVault.deposit{ value: scenario.singleDepositValue }(users.alice, scenario.subjectId, CURVE_ID, 0);
        protocol.multiVault.depositBatch{ value: _sum(scenario.batchAssets) }(
            users.alice, scenario.batchTermIds, scenario.batchCurveIds, scenario.batchAssets, scenario.minShares
        );
    }

    function _runAllAllowedMulticall(AllAllowedScenario memory scenario) internal {
        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (scenario.atomData, scenario.atomAssets));
        data[1] = abi.encodeCall(
            IMultiVault.createTriples,
            (scenario.subjectIds, scenario.predicateIds, scenario.objectIds, scenario.tripleAssets)
        );
        data[2] = abi.encodeCall(IMultiVault.deposit, (users.alice, scenario.subjectId, CURVE_ID, 0));
        data[3] = abi.encodeCall(
            IMultiVault.depositBatch,
            (users.alice, scenario.batchTermIds, scenario.batchCurveIds, scenario.batchAssets, scenario.minShares)
        );

        uint256[] memory values = new uint256[](4);
        values[0] = _sum(scenario.atomAssets);
        values[1] = scenario.tripleAssets[0];
        values[2] = scenario.singleDepositValue;
        values[3] = _sum(scenario.batchAssets);

        resetPrank(users.alice);
        protocol.multiVault.multicallPayable{ value: _sum(values) }(data, values);
    }

    function _allAllowedProbes(AllAllowedScenario memory scenario)
        internal
        view
        returns (AllAllowedProbes memory probes)
    {
        probes.subject = _probe(scenario.subjectId, users.alice);
        probes.triple = _probe(scenario.tripleId, users.alice);
        probes.batchAtom = _probe(scenario.batchAtomId, users.alice);
    }

    function _probe(bytes32 termId, address holder) internal view returns (Probe memory p) {
        uint256 epoch = protocol.multiVault.currentEpoch();
        (p.vaultTotalAssets, p.vaultTotalShares) = protocol.multiVault.getVault(termId, CURVE_ID);
        p.multiVaultBalance = address(protocol.multiVault).balance;
        p.totalTermsCreated = protocol.multiVault.totalTermsCreated();
        p.currentEpochProtocolFees = protocol.multiVault.accumulatedProtocolFees(epoch);
        p.totalUtilization = protocol.multiVault.getTotalUtilizationForEpoch(epoch);
        p.personalUtilization = protocol.multiVault.getUserUtilizationForEpoch(holder, epoch);
        p.holderShares = protocol.multiVault.getShares(holder, termId, CURVE_ID);
        p.termCreated = protocol.multiVault.isTermCreated(termId);
        p.atomCreator = protocol.multiVault.getAtomCreator(termId);
    }

    function _assertProbeEq(Probe memory expected, Probe memory actual, string memory label) internal pure {
        assertEq(actual.multiVaultBalance, expected.multiVaultBalance, string.concat(label, ": balance"));
        assertEq(actual.totalTermsCreated, expected.totalTermsCreated, string.concat(label, ": terms"));
        assertEq(
            actual.currentEpochProtocolFees, expected.currentEpochProtocolFees, string.concat(label, ": protocol fees")
        );
        assertEq(actual.totalUtilization, expected.totalUtilization, string.concat(label, ": total utilization"));
        assertEq(
            actual.personalUtilization, expected.personalUtilization, string.concat(label, ": personal utilization")
        );
        assertEq(actual.vaultTotalAssets, expected.vaultTotalAssets, string.concat(label, ": vault assets"));
        assertEq(actual.vaultTotalShares, expected.vaultTotalShares, string.concat(label, ": vault shares"));
        assertEq(actual.holderShares, expected.holderShares, string.concat(label, ": holder shares"));
        assertEq(actual.termCreated, expected.termCreated, string.concat(label, ": term created"));
        assertEq(actual.atomCreator, expected.atomCreator, string.concat(label, ": atom creator"));
    }

    function _uintArray4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[] memory values) {
        values = new uint256[](4);
        values[0] = a;
        values[1] = b;
        values[2] = c;
        values[3] = d;
    }

    function _sum(uint256[] memory values) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < values.length;) {
            total += values[i];
            unchecked {
                ++i;
            }
        }
    }

    function _revertSelector(bytes memory ret) internal pure returns (bytes4 selector) {
        require(ret.length >= 4, "missing revert selector");
        assembly {
            selector := mload(add(ret, 0x20))
        }
    }
}
