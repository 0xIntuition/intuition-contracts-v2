// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {Errors} from "src/libraries/Errors.sol";

contract CreateTripleTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                                   Helpers
    ──────────────────────────────────────────────────────────────────────────*/

    function _tripleCost() internal view returns (uint256) {
        return multiVault.getTripleCost();
    }

    function _defaultCurve() internal view returns (uint256) {
        return getBondingCurveConfig().defaultCurveId;
    }

    function _approveTrust(uint256 amount) internal {
        trustToken.approve(address(multiVault), amount);
    }

    /// @dev creates three simple atoms and returns their ids (subject, predicate, object)
    function _createBasicAtoms() internal returns (bytes32, bytes32, bytes32) {
        uint256 val = _atomCost() + 1 ether;
        _approveTrust(val * 3);

        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "S";
        atomDataArray[1] = "P";
        atomDataArray[2] = "O";
        bytes32[] memory atomIds = multiVault.createAtoms(atomDataArray, val * 3);
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @dev creates another three simple atoms and returns their ids (subject, predicate, object)
    function _createAnotherBasicAtoms() internal returns (bytes32, bytes32, bytes32) {
        uint256 val = _atomCost() + 1 ether;
        _approveTrust(val * 3);

        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "S2";
        atomDataArray[1] = "P2";
        atomDataArray[2] = "O2";
        bytes32[] memory atomIds = multiVault.createAtoms(atomDataArray, val * 3);
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    function _atomCost() internal view returns (uint256) {
        return multiVault.getAtomCost();
    }

    /// @dev creates a basic triple with the given subject, predicate, object and value and returns the triple id
    function _createBasicTriple(bytes32 s, bytes32 p, bytes32 o, uint256 value) internal returns (bytes32) {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);

        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;

        bytes32 tripleId = multiVault.createTriples(subjectIds, predicateIds, objectIds, value)[0];
        return tripleId;
    }

    /*──────────────────────────────────────────────────────────────────────────
                         1. Happy-path (single createTriple)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createTriple_happyPath() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createBasicAtoms();

        uint256 value = _tripleCost() + 5 ether;
        _approveTrust(value);

        (, uint256 subjectAtomAssetsBefore) = multiVault.getVaultTotals(s, _defaultCurve());

        // create the triple
        bytes32 tid = _createBasicTriple(s, p, o, value);

        // basic state
        assertEq(tid, multiVault.tripleIdFromAtomIds(s, p, o));
        assertTrue(multiVault.isTripleId(tid));

        // vault totals & user shares
        (uint256 totShares, uint256 totAssets) = multiVault.getVaultTotals(tid, _defaultCurve());
        uint256 userShares = multiVault.balanceOf(address(this), tid, _defaultCurve());
        assertGt(userShares, 0);
        assertEq(totAssets, totShares); // share-price == 1 on creation
        assertEq(totShares, userShares + getGeneralConfig().minShare);

        // underlying atoms bumped by atom deposit fraction on triple creation
        uint256 staticAtomAssetsIncrease = getTripleConfig().totalAtomDepositsOnTripleCreation / 3;
        uint256 atomDepositFraction = multiVault.atomDepositFractionAmount(5 ether, tid) / 3;

        (, uint256 subjectAtomAssetsAfter) = multiVault.getVaultTotals(s, _defaultCurve());

        assertEq(subjectAtomAssetsAfter, subjectAtomAssetsBefore + staticAtomAssetsIncrease + atomDepositFraction);

        // protocol fees: static triple fee
        uint256 epoch = multiVault.currentEpoch();
        assertEq(
            multiVault.accumulatedProtocolFees(epoch),
            getAtomConfig().atomCreationProtocolFee * 3 // from atoms
                + getTripleConfig().tripleCreationProtocolFee // from triple
                + multiVault.protocolFeeAmount(8 ether) // from combined triple value and atom values (5 + 1 * 3 ether)
        );
    }

    /*──────────────────────────────────────────────────────────────────────────
                     2. Revert paths (single createTriple)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createTriple_revertIfAtomMissing() external {
        (bytes32 s,,) = _createBasicAtoms();
        bytes32 fakeId = bytes32("fake");

        uint256 val = _tripleCost();
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomDoesNotExist.selector, fakeId));
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = fakeId;
        objectIds[0] = fakeId;
        multiVault.createTriples(subjectIds, predicateIds, objectIds, val);
    }

    function test_createTriple_revertIfDuplicate() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createBasicAtoms();

        uint256 val = _tripleCost() + 1 ether;
        _approveTrust(val * 2);

        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;
        multiVault.createTriples(subjectIds, predicateIds, objectIds, val);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TripleExists.selector, s, p, o));
        multiVault.createTriples(subjectIds, predicateIds, objectIds, val);
    }

    function test_createTriple_revertIfPaused() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createBasicAtoms();

        vm.prank(admin);
        multiVaultConfig.pause();
        multiVault.syncConfig();

        uint256 val = _tripleCost();
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ContractPaused.selector));
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;
        multiVault.createTriples(subjectIds, predicateIds, objectIds, val);
    }

    function test_createTriple_revertIfInsufficientBalance() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createBasicAtoms();

        uint256 shortVal = _tripleCost() - 1;
        _approveTrust(shortVal);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;
        multiVault.createTriples(subjectIds, predicateIds, objectIds, shortVal);
    }

    /*──────────────────────────────────────────────────────────────────────────
                           3. Happy-path (batch)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createTriples_happyPath() external {
        (bytes32 s1, bytes32 p1, bytes32 o1) = _createBasicAtoms();
        (bytes32 s2, bytes32 p2, bytes32 o2) = _createAnotherBasicAtoms(); // new atoms (ids 5-7)

        bytes32[] memory subs = new bytes32[](2);
        bytes32[] memory preds = new bytes32[](2);
        bytes32[] memory objs = new bytes32[](2);

        subs[0] = s1;
        preds[0] = p1;
        objs[0] = o1;
        subs[1] = s2;
        preds[1] = p2;
        objs[1] = o2;

        uint256 totalVal = (_tripleCost() + 4 ether) * 2;
        _approveTrust(totalVal);

        bytes32[] memory tids = multiVault.createTriples(subs, preds, objs, totalVal);
        assertEq(tids.length, 2);
        assertTrue(multiVault.isTripleId(tids[0]) && multiVault.isTripleId(tids[1]));
    }

    /*──────────────────────────────────────────────────────────────────────────
                            4. Batch-revert branches
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createTriples_revertIfEmpty() external {
        bytes32[] memory emptyIds;
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_NoTriplesProvided.selector));
        multiVault.createTriples(emptyIds, emptyIds, emptyIds, 0);
    }

    function test_createTriples_revertIfLengthMismatch() external {
        (bytes32 s,,) = _createBasicAtoms();
        bytes32[] memory subs = new bytes32[](1);
        bytes32[] memory preds = new bytes32[](2);
        bytes32[] memory objs = new bytes32[](1);
        subs[0] = s;
        preds[0] = s;
        preds[1] = s; // mismatch here
        objs[0] = s;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        multiVault.createTriples(subs, preds, objs, 0);
    }

    function test_createTriples_revertIfInsufficientBalance() external {
        (bytes32 s1, bytes32 p1, bytes32 o1) = _createBasicAtoms();
        bytes32[] memory subs = new bytes32[](1);
        bytes32[] memory preds = new bytes32[](1);
        bytes32[] memory objs = new bytes32[](1);
        subs[0] = s1;
        preds[0] = p1;
        objs[0] = o1;

        uint256 shortVal = _tripleCost() - 1;
        _approveTrust(shortVal);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        multiVault.createTriples(subs, preds, objs, shortVal);
    }
}
