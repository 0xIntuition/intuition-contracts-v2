// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/// @title  `multicall` value-accounting hunt
/// @notice Adversarial PoCs that *attempt* to credit more ETH across a batch than
///         `msg.value` covers, and to smuggle nested calls or value into guarded
///         zero-value legs. The tests assert the guard fires or state is conserved.
///
///         Complements the equivalence/value-borrow coverage already in
///         tests/unit/MultiVault/MulticallAdversarial.t.sol; this file adds
///         the nesting-rejection, ETH-out-leg rejection, double-credit, and
///         end-to-end native-value-conservation angles.
contract MulticallValueTest is BaseTest {
    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /// @dev H1: two deposit legs each declaring the FULL outer value while only the
    ///      outer value is sent. `sum(values) != msg.value` ⇒ hard revert; no shares
    ///      are minted from phantom wei.
    function test_doubleCreditViaInflatedValuesArray_reverts() public {
        bytes32 atomA = createSimpleAtom("t1-double-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("t1-double-B", ATOM_COST[0], users.alice);

        uint256 outer = 4 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomB, CURVE_ID, 0));

        // Each leg claims the entire outer value: sum = 2 * outer, but only `outer` is paid.
        uint256[] memory values = new uint256[](2);
        values[0] = outer;
        values[1] = outer;

        uint256 sharesABefore = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);
        uint256 sharesBBefore = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_MulticallValueMismatch.selector);
        protocol.multiVault.multicall{ value: outer }(data, values);

        assertEq(protocol.multiVault.getShares(users.alice, atomA, CURVE_ID), sharesABefore, "atom A untouched");
        assertEq(protocol.multiVault.getShares(users.alice, atomB, CURVE_ID), sharesBBefore, "atom B untouched");
    }

    /// @dev H2: a leg whose calldata re-enters `multicall`. The transient guard
    ///      rejects the nested value-bearing batch during sub-call execution.
    function test_nestedMulticallLeg_reverts() public {
        bytes32 atomA = createSimpleAtom("t1-nest-A", ATOM_COST[0], users.alice);

        bytes[] memory inner = new bytes[](1);
        inner[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        uint256[] memory innerValues = new uint256[](1);
        innerValues[0] = 1 ether;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.multicall, (inner, innerValues));
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NestedMulticall.selector);
        protocol.multiVault.multicall{ value: 1 ether }(data, values);
    }

    /// @dev H3: a zero-valued redeem leg can safely share a value-bearing batch
    ///      with a deposit. The exit cannot observe or consume the deposit leg's
    ///      allocation, and its proceeds are paid directly to the receiver.
    function test_redeemLegInValueBatch_succeedsWithZeroAllocation() public {
        bytes32 atomId = createSimpleAtom("t1-mixed-redeem", ATOM_COST[0] + 4 ether, users.alice);
        uint256 sharesBefore = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        uint256 sharesToRedeem = sharesBefore / 4;
        uint256 depositValue = 2 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomId, CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.redeem, (users.alice, atomId, CURVE_ID, sharesToRedeem, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = depositValue;

        uint256 balanceBefore = address(protocol.multiVault).balance;
        resetPrank(users.alice);
        bytes[] memory results = protocol.multiVault.multicall{ value: depositValue }(data, values);

        uint256 redeemedAssets = abi.decode(results[1], (uint256));
        assertGt(redeemedAssets, 0, "redeem leg returns assets");
        assertEq(
            address(protocol.multiVault).balance,
            balanceBefore + depositValue - redeemedAssets,
            "mixed batch conserves native value"
        );
    }

    /// @dev Invariant: a mixed legal batch increases the vault's native balance by
    ///      EXACTLY `msg.value` — no wei is conjured or destroyed across the
    ///      delegatecall legs. Pairs the per-vault equivalence tests with a
    ///      contract-level conservation check.
    function test_nativeValueConservation_mixedBatch() public {
        bytes[] memory atomData = new bytes[](2);
        atomData[0] = abi.encodePacked("t1-cons-A");
        atomData[1] = abi.encodePacked("t1-cons-B");
        uint256[] memory atomAssets = new uint256[](2);
        atomAssets[0] = ATOM_COST[0] + 1 ether;
        atomAssets[1] = ATOM_COST[0];

        bytes32 existing = createSimpleAtom("t1-cons-existing", ATOM_COST[0], users.alice);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomData, atomAssets));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, existing, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = atomAssets[0] + atomAssets[1];
        values[1] = 3 ether;

        uint256 outer = values[0] + values[1];
        uint256 balanceBefore = address(protocol.multiVault).balance;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: outer }(data, values);

        assertEq(
            address(protocol.multiVault).balance - balanceBefore,
            outer,
            "vault native balance grew by exactly msg.value"
        );
    }

    /// @dev Arrays-length mismatch is rejected before any value is moved.
    function test_lengthMismatch_reverts() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IMultiVault.deposit.selector);
        uint256[] memory values = new uint256[](2);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.multicall{ value: 0 }(data, values);
    }
}
