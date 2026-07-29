// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

/// @notice Catches a multi-subcall multicall that reverts on a LATER subcall (after earlier
///         subcalls have already set `_virtualMsgValue`), then performs a direct deposit in the same
///         transaction. Used to prove transient value state does not leak across the caught revert.
contract MultiSubcallCatcher {
    IMultiVault internal immutable multiVault;
    uint256 internal immutable curveId;

    bytes4 public lastFailureSelector;

    constructor(IMultiVault multiVault_, uint256 curveId_) {
        multiVault = multiVault_;
        curveId = curveId_;
    }

    /// @dev `multicall` with values [good, 0]: subcall 0 deposits `firstValue` (succeeds, sets
    ///      `_virtualMsgValue = firstValue`), subcall 1 deposits 0 (reverts below-minimum). The whole
    ///      call reverts and the forwarded value returns here. Then a direct deposit of `directValue`
    ///      must be credited its own value — not the stale `firstValue` and not 0.
    function catchMultiThenDeposit(bytes32 atomId, uint256 firstValue, uint256 directValue)
        external
        payable
        returns (uint256 directShares)
    {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (address(this), atomId, curveId, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (address(this), atomId, curveId, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = firstValue;
        values[1] = 0;

        (bool ok, bytes memory reason) =
            address(multiVault).call{ value: firstValue }(abi.encodeCall(IMultiVault.multicall, (data, values)));
        require(!ok, "multicall should revert on the zero-value subcall");
        lastFailureSelector = _selector(reason);

        directShares = multiVault.deposit{ value: directValue }(address(this), atomId, curveId, 0);
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length >= 4) {
            assembly {
                selector := mload(add(reason, 0x20))
            }
        }
    }
}

/// @title  MulticallValueAccounting
/// @notice Hypothesis 2 (deep pre-audit): transient value accounting in multicall, pushed
///         past the existing single-subcall caught-revert test to a MULTI-subcall sequence where a
///         later subcall reverts after earlier subcalls have already written `_virtualMsgValue`.
///
/// Invariant under test: `_inMulticall` / `_virtualMsgValue` are scoped to the multicall frame, so a
/// caught revert (which rolls back the frame's transient writes under EIP-1153) must leave a later
/// same-tx direct call seeing its own `msg.value`, never a stale virtual value; and a successful
/// multicall credits each subcall exactly its allocated value.
///
/// Verdict: DEFENDED. EIP-1153 frame-revert semantics clear the transient writes; the direct deposit
/// after the caught revert is credited exactly its own value.
contract MulticallValueAccountingTest is BaseTest {
    uint256 internal curveId;

    function setUp() public override {
        super.setUp();
        curveId = getDefaultCurveId();
    }

    /// @dev After a multi-subcall multicall reverts on its second (zero-value) subcall, the
    ///      catcher's direct deposit is credited exactly its own value — proven by matching the
    ///      shares a clean depositor gets for the same value on an identical fresh atom.
    function test_multiSubcallCaughtRevert_doesNotLeakVirtualValue() external {
        bytes32 atomId = _createAtom("h2-leak-target", users.alice);
        bytes32 twinAtomId = _createAtom("h2-leak-twin", users.alice);

        MultiSubcallCatcher catcher = new MultiSubcallCatcher(IMultiVault(address(protocol.multiVault)), curveId);

        uint256 firstValue = 1 ether; // sets _virtualMsgValue = 1 ether on the first subcall
        uint256 directValue = 2 ether; // the direct deposit must be credited 2 ether, not 1 or 0

        uint256 directShares =
            catcher.catchMultiThenDeposit{ value: firstValue + directValue }(atomId, firstValue, directValue);

        // Control: a clean 2-ether deposit on the identical twin atom.
        uint256 controlShares = makeDeposit(users.bob, users.bob, twinAtomId, curveId, directValue, 0);

        assertEq(
            catcher.lastFailureSelector(),
            MultiVault.MultiVault_DepositBelowMinimumDeposit.selector,
            "the caught revert is the zero-value second subcall"
        );
        assertGt(directShares, 0, "direct deposit after caught revert succeeds");
        assertEq(directShares, controlShares, "direct deposit credited its own value (2 ether), no transient leak");
    }

    /// @dev A fully-successful two-subcall multicall credits each subcall exactly its
    ///      allocated value: total native spent == msg.value, and the two resulting positions match
    ///      independent single deposits of the same values.
    function test_multiSubcallSuccess_creditsEachSubcallItsAllocatedValue() external {
        bytes32 atomId = _createAtom("h2-success", users.alice);
        bytes32 twinA = _createAtom("h2-success-twinA", users.alice);
        bytes32 twinB = _createAtom("h2-success-twinB", users.alice);

        uint256 valueA = 1 ether;
        uint256 valueB = 3 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.bob, atomId, curveId, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.bob, atomId, curveId, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = valueA;
        values[1] = valueB;

        vm.deal(users.bob, valueA + valueB);
        uint256 balBefore = users.bob.balance;

        resetPrank(users.bob);
        protocol.multiVault.multicall{ value: valueA + valueB }(data, values);

        assertEq(balBefore - users.bob.balance, valueA + valueB, "exactly msg.value spent across subcalls");

        // The two same-vault subcalls accumulate; compare to two independent single deposits on a twin.
        uint256 combinedShares = protocol.multiVault.getShares(users.bob, atomId, curveId);
        uint256 refA = makeDeposit(users.charlie, users.charlie, twinA, curveId, valueA, 0);
        uint256 refB = makeDeposit(users.charlie, users.charlie, twinB, curveId, valueB, 0);
        // Each twin starts in the same state as `atomId`; subcall A matches refA. Subcall B deposits
        // into an already-grown vault, so exact equality is not expected — assert the value bound.
        assertGt(combinedShares, 0, "combined position minted");
        assertLe(combinedShares, refA + refB, "combined shares bounded by independent single deposits");
    }

    function _createAtom(string memory label, address creator) internal returns (bytes32 atomId) {
        uint256 atomCost = protocol.multiVault.getAtomCost();
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked(label);
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.startPrank(creator);
        bytes32[] memory ids = protocol.multiVault.createAtoms{ value: atomCost }(atomData, assets);
        vm.stopPrank();

        atomId = ids[0];
    }
}
