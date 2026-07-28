// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/// @title  `multicallPayable` value-accounting hunt
/// @notice Adversarial PoCs that *attempt* to credit more ETH across a batch than
///         `msg.value` covers, and to smuggle non-allowlisted / nested calls into
///         the value-multicall. Every test here is a NEGATIVE result: the attack
///         is defended and the test asserts the guard fires + state is conserved.
///
///         Complements the equivalence/value-borrow coverage already in
///         tests/unit/MultiVault/MulticallPayableAdversarial.t.sol; this file adds
///         the nesting-rejection, ETH-out-leg rejection, double-credit, and
///         end-to-end native-value-conservation angles.
contract MulticallPayableValueTest is BaseTest {
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
        protocol.multiVault.multicallPayable{ value: outer }(data, values);

        assertEq(protocol.multiVault.getShares(users.alice, atomA, CURVE_ID), sharesABefore, "atom A untouched");
        assertEq(protocol.multiVault.getShares(users.alice, atomB, CURVE_ID), sharesBBefore, "atom B untouched");
    }

    /// @dev H2: a leg whose calldata re-enters `multicallPayable`. The upfront
    ///      selector allowlist rejects it before any execution begins, so the
    ///      `_inMulticall` reentrancy window never opens for a nested value-batch.
    function test_nestedMulticallPayableLeg_reverts() public {
        bytes32 atomA = createSimpleAtom("t1-nest-A", ATOM_COST[0], users.alice);

        bytes[] memory inner = new bytes[](1);
        inner[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        uint256[] memory innerValues = new uint256[](1);
        innerValues[0] = 1 ether;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.multicallPayable, (inner, innerValues));
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_PayableMulticallSelectorNotAllowed.selector);
        protocol.multiVault.multicallPayable{ value: 1 ether }(data, values);
    }

    /// @dev H3: `redeem` (an ETH-OUT path) cannot be smuggled into the value-batch.
    ///      The allowlist only admits create/deposit selectors, so there is no
    ///      attacker-controlled external transfer inside the `_inMulticall` window
    ///      to re-enter from. The 4-byte selector is enough to trip the guard.
    function test_redeemLegInValueBatch_reverts() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IMultiVault.redeem.selector);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_PayableMulticallSelectorNotAllowed.selector);
        protocol.multiVault.multicallPayable{ value: 0 }(data, values);
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
        protocol.multiVault.multicallPayable{ value: outer }(data, values);

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
        protocol.multiVault.multicallPayable{ value: 0 }(data, values);
    }
}
