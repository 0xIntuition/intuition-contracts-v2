// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";

/// @notice Re-enters `MultiVault.multicall` from `receive()`. Used to prove the
///         `_inMulticall` guard fires when an outer multicall sub-call sends
///         native TRUST to a malicious receiver.
contract MulticallReentrantReceiver {
    IMultiVault public immutable mv;
    bool public armed;

    constructor(IMultiVault _mv) {
        mv = _mv;
    }

    function arm() external {
        armed = true;
    }

    receive() external payable {
        if (!armed) return;
        bytes[] memory inner = new bytes[](0);
        mv.multicall(inner, new uint256[](0));
    }
}

/// @notice Re-enters an arbitrary MultiVault call from `receive()`, bubbling the
///         original revert. Used to prove direct native-asset redeem paths are
///         still protected by `nonReentrant` after the library extraction.
contract MultiVaultReceiveHookReenterer {
    IMultiVault public immutable mv;
    bytes public attackData;
    bool public armed;

    constructor(IMultiVault _mv) {
        mv = _mv;
    }

    function arm(bytes calldata data) external {
        attackData = data;
        armed = true;
    }

    receive() external payable {
        if (!armed) return;

        (bool ok, bytes memory ret) = address(mv).call(attackData);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

contract MulticallTest is BaseTest {
    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /* ============================================================ */
    /*                Canonical multicall (overridden)              */
    /* ============================================================ */

    function test_multicall_emptyBatchWithValue_revertsOn_ValueMismatch() public {
        bytes[] memory data = new bytes[](0);
        uint256[] memory values = new uint256[](0);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_MulticallValueMismatch.selector);
        protocol.multiVault.multicall{ value: 1 wei }(data, values);
    }

    function test_multicall_legacySelectorsAreUnavailable() public {
        bytes[] memory data = new bytes[](0);
        uint256[] memory values = new uint256[](0);

        resetPrank(users.alice);
        (bool oldMulticallOk, bytes memory oldMulticallRet) =
            address(protocol.multiVault).call(abi.encodeWithSelector(bytes4(keccak256("multicall(bytes[])")), data));
        assertFalse(oldMulticallOk, "legacy multicall selector must be removed");
        assertEq(oldMulticallRet.length, 0, "legacy multicall dispatcher revert");

        (bool payableMulticallOk, bytes memory payableMulticallRet) = address(protocol.multiVault)
            .call(abi.encodeWithSelector(bytes4(keccak256("multicallPayable(bytes[],uint256[])")), data, values));
        assertFalse(payableMulticallOk, "multicallPayable selector must be removed");
        assertEq(payableMulticallRet.length, 0, "multicallPayable dispatcher revert");
    }

    function test_multicall_redeemTwoVaults_succeeds() public {
        // Two separate atoms, alice owns shares in both
        bytes32 atomA = createSimpleAtom("multicall-redeem-A", ATOM_COST[0] + 1 ether, users.alice);
        bytes32 atomB = createSimpleAtom("multicall-redeem-B", ATOM_COST[0] + 1 ether, users.alice);

        uint256 sharesA = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);
        uint256 sharesB = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);
        assertGt(sharesA, 0);
        assertGt(sharesB, 0);

        // Leave a small share buffer (minShare floor) — redeem 90% of each.
        uint256 redeemA = (sharesA * 9) / 10;
        uint256 redeemB = (sharesB * 9) / 10;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.redeem, (users.alice, atomA, CURVE_ID, redeemA, 0));
        data[1] = abi.encodeCall(IMultiVault.redeem, (users.alice, atomB, CURVE_ID, redeemB, 0));

        uint256 balBefore = users.alice.balance;
        resetPrank(users.alice);
        bytes[] memory results = protocol.multiVault.multicall(data, new uint256[](data.length));
        uint256 balAfter = users.alice.balance;

        assertEq(results.length, 2);
        assertGt(balAfter, balBefore, "alice should have received TRUST from both redeems");

        uint256 sharesAAfter = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);
        uint256 sharesBAfter = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);
        assertEq(sharesAAfter, sharesA - redeemA);
        assertEq(sharesBAfter, sharesB - redeemB);
    }

    function test_multicall_bubblesSubcallRevert() public {
        // alice has no shares in this atom => redeem reverts with InsufficientSharesInVault
        bytes32 atomId = createSimpleAtom("multicall-bubble", ATOM_COST[0], users.bob);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.redeem, (users.alice, atomId, CURVE_ID, 1, 0));

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientSharesInVault.selector);
        protocol.multiVault.multicall(data, new uint256[](data.length));
    }

    function test_multicall_reEvaluates_whenNotPaused() public {
        // Pause the contract via admin (admin has PAUSER_ROLE post-reinitialize)
        resetPrank(users.admin);
        protocol.multiVault.pause();

        // Inside a paused contract, any whenNotPaused sub-call must revert
        // even when wrapped in multicall.
        bytes32 atomId = bytes32(0);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.redeem, (users.alice, atomId, CURVE_ID, 1, 0));

        resetPrank(users.alice);
        // OZ Pausable v5 reverts with EnforcedPause()
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        protocol.multiVault.multicall(data, new uint256[](data.length));
    }

    function test_multicall_reEvaluates_roleCheck() public {
        // Non-admin tries to invoke pause via multicall — should revert with
        // OZ AccessControl unauthorized error per sub-call (msg.sender preserved).
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.pause, ());

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, protocol.multiVault.PAUSER_ROLE()
            )
        );
        protocol.multiVault.multicall(data, new uint256[](data.length));
    }

    function test_multicall_payableSubcall_revertsViaValueCheck() public {
        // createAtoms requires msg.value == sum(assets). Inside non-payable
        // multicall, _virtualMsgValue is forced to 0, so _validatePayment
        // reads _effectiveMsgValue() == 0 and reverts.
        bytes[] memory atomData = new bytes[](1);
        atomData[0] = abi.encodePacked("inside-multicall");
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ATOM_COST[0];

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomData, amounts));

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_InsufficientBalance.selector);
        protocol.multiVault.multicall(data, new uint256[](data.length));
    }

    function test_multicall_nestedCanonical_revertsWith_NestedMulticall() public {
        bytes[] memory inner = new bytes[](0);
        uint256[] memory innerValues = new uint256[](0);
        bytes[] memory outer = new bytes[](1);
        outer[0] = abi.encodeCall(IMultiVault.multicall, (inner, innerValues));

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NestedMulticall.selector);
        protocol.multiVault.multicall(outer, new uint256[](outer.length));
    }

    function test_multicall_nestedPayable_revertsWith_NestedMulticall() public {
        bytes[] memory innerData = new bytes[](0);
        uint256[] memory innerValues = new uint256[](0);

        bytes[] memory outer = new bytes[](1);
        outer[0] = abi.encodeCall(IMultiVault.multicall, (innerData, innerValues));
        uint256[] memory outerValues = new uint256[](1);
        outerValues[0] = 1 wei;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NestedMulticall.selector);
        protocol.multiVault.multicall{ value: 1 wei }(outer, outerValues);
    }

    /* ============================================================ */
    /*                    Value-bearing multicall                  */
    /* ============================================================ */

    function test_multicall_atomCreate_then_deposit_inOneTx() public {
        // Compose: createAtoms([X bytes], [V_create]) + deposit(alice, atomId, curve, 0)
        // with values = [V_create, V_deposit] and msg.value = V_create + V_deposit.
        bytes memory atomBytes = abi.encodePacked("payable-multicall-atom");
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        uint256 vCreate = ATOM_COST[0] + 5 ether;
        uint256 vDeposit = 7 ether;

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = vCreate;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDataArr, createAssets));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, expectedAtomId, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = vCreate;
        values[1] = vDeposit;

        resetPrank(users.alice);
        bytes[] memory results = protocol.multiVault.multicall{ value: vCreate + vDeposit }(data, values);

        assertEq(results.length, 2);
        assertTrue(protocol.multiVault.isTermCreated(expectedAtomId), "atom should be created");
        assertEq(protocol.multiVault.getAtomCreator(expectedAtomId), users.alice);

        uint256 totalShares = protocol.multiVault.getShares(users.alice, expectedAtomId, CURVE_ID);
        assertGt(totalShares, 0, "alice should hold shares from create + deposit");
    }

    /// @notice The v1.1.0 fix that unlocks first-deposit on a counter-triple's non-default-curve
    ///         vault must also work when invoked through the value-bearing {multicall} entry point.
    function test_multicall_DepositCounterTripleNonDefault_Succeeds() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("mc-ctr-s", "mc-ctr-p", "mc-ctr-o", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;
        uint256 vDeposit = 5 ether;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.bob, counterId, nonDefaultCurve, 0));
        uint256[] memory values = new uint256[](1);
        values[0] = vDeposit;

        vm.deal(users.bob, vDeposit);
        resetPrank(users.bob);
        bytes[] memory results = protocol.multiVault.multicall{ value: vDeposit }(data, values);
        assertEq(results.length, 1, "one sub-call expected");

        uint256 bobShares = protocol.multiVault.getShares(users.bob, counterId, nonDefaultCurve);
        assertGt(bobShares, 0, "counter-non-default deposit through multicall must mint shares");

        // The symmetric bootstrap path still seeds the opposite-side vault with min-shares to BURN.
        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        assertEq(
            protocol.multiVault.getShares(protocol.multiVault.BURN_ADDRESS(), tripleId, nonDefaultCurve),
            minShare,
            "positive non-default seed via multicall path"
        );
    }

    function test_multicall_batchDeposits_acrossMultipleAtoms() public {
        bytes32 atomA = createSimpleAtom("payable-batch-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("payable-batch-B", ATOM_COST[0], users.alice);

        uint256 va = 3 ether;
        uint256 vb = 5 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomA, CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomB, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = va;
        values[1] = vb;

        uint256 sharesABefore = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);
        uint256 sharesBBefore = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: va + vb }(data, values);

        uint256 sharesAAfter = protocol.multiVault.getShares(users.alice, atomA, CURVE_ID);
        uint256 sharesBAfter = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);
        assertGt(sharesAAfter, sharesABefore, "vault A shares should increase");
        assertGt(sharesBAfter, sharesBBefore, "vault B shares should increase");
    }

    function test_multicall_emptyData_isNoop() public {
        bytes[] memory data = new bytes[](0);
        uint256[] memory values = new uint256[](0);

        resetPrank(users.alice);
        bytes[] memory results = protocol.multiVault.multicall{ value: 0 }(data, values);
        assertEq(results.length, 0);
    }

    function test_multicall_revertsOn_ValueMismatch() public {
        bytes32 atomId = createSimpleAtom("vmismatch", ATOM_COST[0], users.alice);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomId, CURVE_ID, 0));
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        resetPrank(users.alice);
        // sum(values) = 1, msg.value = 2 -> revert
        vm.expectRevert(MultiVault.MultiVault_MulticallValueMismatch.selector);
        protocol.multiVault.multicall{ value: 2 ether }(data, values);
    }

    function test_multicall_revertsOn_LengthMismatch() public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, bytes32(0), CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, bytes32(0), CURVE_ID, 0));
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_ArraysNotSameLength.selector);
        protocol.multiVault.multicall{ value: 1 ether }(data, values);
    }

    function test_multicall_redeemWithValueAllocation_revertsOn_UnexpectedValue() public {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.redeem, (users.alice, bytes32(0), CURVE_ID, 1, 0));
        uint256[] memory values = new uint256[](1);
        values[0] = 1 wei;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_UnexpectedValue.selector);
        protocol.multiVault.multicall{ value: 1 wei }(data, values);
    }

    function test_multicall_revertsOn_ShortCalldata() public {
        bytes[] memory data = new bytes[](1);
        data[0] = hex"112233"; // 3 bytes < 4
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        resetPrank(users.alice);
        (bool ok, bytes memory ret) =
            address(protocol.multiVault).call(abi.encodeCall(IMultiVault.multicall, (data, values)));
        assertFalse(ok, "short calldata sub-call must revert");
        assertEq(ret.length, 0, "raw dispatcher revert must bubble unchanged");
    }

    function test_multicall_innerMulticall_revertsWith_NestedMulticall() public {
        bytes[] memory innerData = new bytes[](0);
        uint256[] memory innerValues = new uint256[](0);

        bytes[] memory outerData = new bytes[](1);
        outerData[0] = abi.encodeCall(IMultiVault.multicall, (innerData, innerValues));
        uint256[] memory outerValues = new uint256[](1);
        outerValues[0] = 0;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_NestedMulticall.selector);
        protocol.multiVault.multicall(outerData, outerValues);
    }

    function test_multicall_valueBearingViewSubcall_revertsAtDispatcher() public {
        bytes32 atomId = createSimpleAtom("value-bearing-view", ATOM_COST[0], users.alice);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.currentEpoch, ());
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomId, CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[1] = 1 ether;

        resetPrank(users.alice);
        (bool ok, bytes memory ret) =
            address(protocol.multiVault).call{ value: 1 ether }(abi.encodeCall(IMultiVault.multicall, (data, values)));
        assertFalse(ok, "non-payable view must reject physical batch value");
        assertEq(ret.length, 0, "expected empty dispatcher revert");
    }

    function test_multicall_msgSender_preservation() public {
        // createAtoms records `atomCreators[atomId] = msg.sender`. If the
        // delegatecall didn't preserve msg.sender, the creator would be
        // address(this) (the test contract), not alice.
        bytes memory atomBytes = abi.encodePacked("msgsender-preservation");
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0];

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDataArr, createAssets));
        uint256[] memory values = new uint256[](1);
        values[0] = ATOM_COST[0];

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: ATOM_COST[0] }(data, values);

        assertEq(protocol.multiVault.getAtomCreator(expectedAtomId), users.alice, "msg.sender must propagate as alice");
    }

    function test_multicall_revertBubbling() public {
        // First sub-call succeeds (createAtoms); second sub-call deposits to a
        // non-existent termId and should revert with the original custom
        // error, bubbled from the sub-call.
        bytes memory atomBytes = abi.encodePacked("bubble-create");
        bytes32 nonexistentTerm = bytes32(uint256(0xdeadbeef));

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0];

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDataArr, createAssets));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, nonexistentTerm, CURVE_ID, 0));

        uint256[] memory values = new uint256[](2);
        values[0] = ATOM_COST[0];
        values[1] = 1 ether;

        resetPrank(users.alice);
        // _processDeposit -> _getVaultType reverts with TermDoesNotExist for
        // an unknown termId. We bubble the original revert verbatim. The
        // error lives on `MultiVaultCore` (the parent), not `MultiVault`.
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, nonexistentTerm)
        );
        protocol.multiVault.multicall{ value: ATOM_COST[0] + 1 ether }(data, values);
    }

    function test_multicall_directCallFallback_reads_msgValue() public {
        // Sanity check: outside multicall, _effectiveMsgValue() must equal
        // msg.value (i.e., direct calls are unchanged). createAtoms with
        // matching value succeeds without going through multicall.
        bytes memory atomBytes = abi.encodePacked("direct-call-sanity");
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0];

        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: ATOM_COST[0] }(atomDataArr, createAssets);

        assertTrue(protocol.multiVault.isTermCreated(expectedAtomId));
    }

    /* ============================================================ */
    /*                Native-asset receive-hook reentry             */
    /* ============================================================ */

    function test_redeem_receiveHookCannotReenterRedeem() public {
        MultiVaultReceiveHookReenterer malicious =
            new MultiVaultReceiveHookReenterer(IMultiVault(address(protocol.multiVault)));
        vm.deal(address(malicious), 1000 ether);

        bytes32 atomId = createSimpleAtom("direct-redeem-reentry-target", ATOM_COST[0], users.alice);
        resetPrank(address(malicious));
        protocol.multiVault.deposit{ value: 50 ether }(address(malicious), atomId, CURVE_ID, 0);

        uint256 shares = protocol.multiVault.getShares(address(malicious), atomId, CURVE_ID);
        uint256 redeemAmt = shares / 4;
        assertGt(redeemAmt, 0, "redeem amount must be non-zero");

        malicious.arm(abi.encodeCall(IMultiVault.redeem, (address(malicious), atomId, CURVE_ID, 1, 0)));

        resetPrank(address(malicious));
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        protocol.multiVault.redeem(address(malicious), atomId, CURVE_ID, redeemAmt, 0);
    }

    function test_redeemBatch_receiveHookCannotReenterRedeemBatch() public {
        MultiVaultReceiveHookReenterer malicious =
            new MultiVaultReceiveHookReenterer(IMultiVault(address(protocol.multiVault)));
        vm.deal(address(malicious), 1000 ether);

        bytes32 atomId = createSimpleAtom("batch-redeem-reentry-target", ATOM_COST[0], users.alice);
        resetPrank(address(malicious));
        protocol.multiVault.deposit{ value: 50 ether }(address(malicious), atomId, CURVE_ID, 0);

        uint256 redeemAmt = protocol.multiVault.getShares(address(malicious), atomId, CURVE_ID) / 4;
        assertGt(redeemAmt, 0, "redeem amount must be non-zero");

        bytes32[] memory termIds = new bytes32[](1);
        uint256[] memory curveIds = new uint256[](1);
        uint256[] memory shares = new uint256[](1);
        uint256[] memory minAssets = new uint256[](1);
        termIds[0] = atomId;
        curveIds[0] = CURVE_ID;
        shares[0] = redeemAmt;

        uint256[] memory reentrantShares = new uint256[](1);
        reentrantShares[0] = 1;
        malicious.arm(
            abi.encodeCall(IMultiVault.redeemBatch, (address(malicious), termIds, curveIds, reentrantShares, minAssets))
        );

        resetPrank(address(malicious));
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        protocol.multiVault.redeemBatch(address(malicious), termIds, curveIds, shares, minAssets);
    }

    function test_multicall_subcallRedeem_maliciousReceive_revertsOuterCall() public {
        // Build: malicious contract holds shares in an atom; outer canonical
        // multicall sub-calls redeem(receiver=malicious, ...). During
        // Address.sendValue, malicious.receive() attempts to reenter
        // MultiVault.multicall. The shared `_inMulticall` guard rejects the
        // reentry. OZ v5.4 Address.sendValue bubbles raw revert data, so the
        // outer revert is exactly the inner cause.
        MulticallReentrantReceiver malicious = new MulticallReentrantReceiver(IMultiVault(address(protocol.multiVault)));
        vm.deal(address(malicious), 1000 ether);

        // Malicious deposits into an atom (creates shares it can redeem).
        bytes32 atomId = createSimpleAtom("redeem-target", ATOM_COST[0], users.alice);
        resetPrank(address(malicious));
        protocol.multiVault.deposit{ value: 50 ether }(address(malicious), atomId, CURVE_ID, 0);

        uint256 shares = protocol.multiVault.getShares(address(malicious), atomId, CURVE_ID);
        // Redeem 90% so the vault retains its minShare floor.
        uint256 redeemAmt = (shares * 9) / 10;

        // Arm the malicious receive hook so it reenters on TRUST receipt.
        malicious.arm();

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.redeem, (address(malicious), atomId, CURVE_ID, redeemAmt, 0));

        resetPrank(address(malicious));
        // OZ v5.4 `Address.sendValue` bubbles raw revert data from the
        // recipient on call failure, so the outer revert is exactly the
        // inner cause: `MultiVault_NestedMulticall`. The shared transient
        // guard catches the receive-hook reentry.
        vm.expectRevert(MultiVault.MultiVault_NestedMulticall.selector);
        protocol.multiVault.multicall(data, new uint256[](data.length));
    }

    /* ============================================================ */
    /*                              Fuzz                            */
    /* ============================================================ */

    function testFuzz_multicall_mismatchAlwaysReverts(uint256 v0, uint256 v1, uint256 outerValue) public {
        // Constrain the fuzz so we explicitly want a mismatch and avoid
        // overflow on sum.
        v0 = bound(v0, 0, type(uint128).max);
        v1 = bound(v1, 0, type(uint128).max);
        outerValue = bound(outerValue, 0, type(uint128).max);
        vm.assume(outerValue != v0 + v1);

        // Use valid deposit calldata because the mismatch is checked before
        // execution; the only failure mode is the value-conservation check.
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, bytes32(0), CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (users.alice, bytes32(0), CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = v0;
        values[1] = v1;

        vm.deal(users.alice, outerValue);
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_MulticallValueMismatch.selector);
        protocol.multiVault.multicall{ value: outerValue }(data, values);
    }

    /* ============================================================ */
    /*           Direct-call vs multicall differential equiv       */
    /* ============================================================ */

    /// @dev Snapshot of every observable on-chain state that the four payable
    ///      entry points touch. Compared after a direct call vs the same call
    ///      routed through `multicall` to prove bit-identical effects.
    struct StateProbe {
        uint256 totalTermsCreated;
        uint256 currentEpochProtocolFees;
        uint256 vaultTotalAssets;
        uint256 vaultTotalShares;
        uint256 holderShares;
        int256 totalUtilization;
        int256 personalUtilization;
        bool termCreated;
        address atomCreator;
    }

    function _probe(bytes32 termId, address holder) internal view returns (StateProbe memory s) {
        uint256 epoch = protocol.multiVault.currentEpoch();
        s.totalTermsCreated = protocol.multiVault.totalTermsCreated();
        s.currentEpochProtocolFees = protocol.multiVault.accumulatedProtocolFees(epoch);
        (s.vaultTotalAssets, s.vaultTotalShares) = protocol.multiVault.getVault(termId, CURVE_ID);
        s.holderShares = protocol.multiVault.getShares(holder, termId, CURVE_ID);
        s.totalUtilization = protocol.multiVault.getTotalUtilizationForEpoch(epoch);
        s.personalUtilization = protocol.multiVault.getUserUtilizationForEpoch(holder, epoch);
        s.termCreated = protocol.multiVault.isTermCreated(termId);
        s.atomCreator = protocol.multiVault.getAtomCreator(termId);
    }

    function _assertProbesEqual(StateProbe memory direct, StateProbe memory viaMulticall) internal pure {
        assertEq(direct.totalTermsCreated, viaMulticall.totalTermsCreated, "totalTermsCreated diverged");
        assertEq(direct.currentEpochProtocolFees, viaMulticall.currentEpochProtocolFees, "protocol fees diverged");
        assertEq(direct.vaultTotalAssets, viaMulticall.vaultTotalAssets, "vault totalAssets diverged");
        assertEq(direct.vaultTotalShares, viaMulticall.vaultTotalShares, "vault totalShares diverged");
        assertEq(direct.holderShares, viaMulticall.holderShares, "holder shares diverged");
        assertEq(direct.totalUtilization, viaMulticall.totalUtilization, "total utilization diverged");
        assertEq(direct.personalUtilization, viaMulticall.personalUtilization, "personal utilization diverged");
        assertEq(direct.termCreated, viaMulticall.termCreated, "term created flag diverged");
        assertEq(direct.atomCreator, viaMulticall.atomCreator, "atom creator diverged");
    }

    function test_diff_createAtoms_directVsMulticall() public {
        bytes memory atomBytes = abi.encodePacked("diff-createAtoms-payload");
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0] + 2 ether;
        uint256 totalValue = createAssets[0];

        uint256 snap = vm.snapshotState();

        // Path A: direct call
        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: totalValue }(atomDataArr, createAssets);
        StateProbe memory direct = _probe(expectedAtomId, users.alice);

        // Path B: same call routed through multicall
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDataArr, createAssets));
        uint256[] memory values = new uint256[](1);
        values[0] = totalValue;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: totalValue }(data, values);
        StateProbe memory viaMulticall = _probe(expectedAtomId, users.alice);

        _assertProbesEqual(direct, viaMulticall);
    }

    function test_diff_createTriples_directVsMulticall() public {
        // Triples require pre-existing subject/predicate/object atoms — share
        // those across both paths so the differential is only the triple
        // creation itself.
        bytes32[] memory atomIds =
            createAtomsWithUniformCost(_toBytesArray3("diff-subj", "diff-pred", "diff-obj"), ATOM_COST[0], users.alice);

        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];

        uint256[] memory tripleAssets = new uint256[](1);
        tripleAssets[0] = TRIPLE_COST[0] + 3 ether;
        uint256 totalValue = tripleAssets[0];

        // We don't know the triple ID until createTriples returns; snapshot
        // before path A, capture the ID after path A, then re-derive after
        // path B from the same atom ids (deterministic via _calculateTripleId).
        uint256 snap = vm.snapshotState();

        // Path A: direct call
        resetPrank(users.alice);
        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: totalValue }(subjectIds, predicateIds, objectIds, tripleAssets);
        bytes32 tripleId = tripleIds[0];
        StateProbe memory direct = _probe(tripleId, users.alice);

        // Path B: same call via multicall
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createTriples, (subjectIds, predicateIds, objectIds, tripleAssets));
        uint256[] memory values = new uint256[](1);
        values[0] = totalValue;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: totalValue }(data, values);
        StateProbe memory viaMulticall = _probe(tripleId, users.alice);

        _assertProbesEqual(direct, viaMulticall);
    }

    function test_diff_deposit_directVsMulticall() public {
        bytes32 atomId = createSimpleAtom("diff-deposit-vault", ATOM_COST[0], users.alice);

        uint256 depositAmount = 4 ether;

        uint256 snap = vm.snapshotState();

        // Path A: direct call
        resetPrank(users.alice);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, CURVE_ID, 0);
        StateProbe memory direct = _probe(atomId, users.alice);

        // Path B: same call via multicall
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.deposit, (users.alice, atomId, CURVE_ID, 0));
        uint256[] memory values = new uint256[](1);
        values[0] = depositAmount;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: depositAmount }(data, values);
        StateProbe memory viaMulticall = _probe(atomId, users.alice);

        _assertProbesEqual(direct, viaMulticall);
    }

    function test_diff_depositBatch_directVsMulticall() public {
        // Two vaults; depositBatch into both. Probe the first; spot-check the
        // second's shares directly so divergence in either is caught.
        bytes32 atomA = createSimpleAtom("diff-depositBatch-A", ATOM_COST[0], users.alice);
        bytes32 atomB = createSimpleAtom("diff-depositBatch-B", ATOM_COST[0], users.alice);

        bytes32[] memory termIds = new bytes32[](2);
        termIds[0] = atomA;
        termIds[1] = atomB;

        uint256[] memory curveIds = new uint256[](2);
        curveIds[0] = CURVE_ID;
        curveIds[1] = CURVE_ID;

        uint256[] memory depositAssets = new uint256[](2);
        depositAssets[0] = 3 ether;
        depositAssets[1] = 5 ether;
        uint256 totalValue = depositAssets[0] + depositAssets[1];

        uint256[] memory minShares = new uint256[](2);

        uint256 snap = vm.snapshotState();

        // Path A: direct call
        resetPrank(users.alice);
        protocol.multiVault.depositBatch{ value: totalValue }(users.alice, termIds, curveIds, depositAssets, minShares);
        StateProbe memory directA = _probe(atomA, users.alice);
        uint256 sharesBDirect = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);

        // Path B: same call via multicall
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.depositBatch, (users.alice, termIds, curveIds, depositAssets, minShares));
        uint256[] memory values = new uint256[](1);
        values[0] = totalValue;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: totalValue }(data, values);
        StateProbe memory viaMulticallA = _probe(atomA, users.alice);
        uint256 sharesBViaMulticall = protocol.multiVault.getShares(users.alice, atomB, CURVE_ID);

        _assertProbesEqual(directA, viaMulticallA);
        assertEq(sharesBDirect, sharesBViaMulticall, "vault B shares diverged across paths");
    }

    function test_diff_createAtomsFor_directVsMulticall() public {
        // createAtomsFor with creator == msg.sender must match createAtomsFor
        // routed through multicall bit-for-bit, exercising per-sub-call value
        // accounting for the new entry point.
        bytes memory atomBytes = abi.encodePacked("diff-createAtomsFor-payload");
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = atomBytes;
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0] + 2 ether;
        uint256 totalValue = createAssets[0];

        uint256 snap = vm.snapshotState();

        // Path A: direct createAtomsFor (self-creation: no approval needed).
        resetPrank(users.alice);
        protocol.multiVault.createAtomsFor{ value: totalValue }(users.alice, atomDataArr, createAssets);
        StateProbe memory direct = _probe(expectedAtomId, users.alice);

        // Path B: same call routed through multicall.
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createAtomsFor, (users.alice, atomDataArr, createAssets));
        uint256[] memory values = new uint256[](1);
        values[0] = totalValue;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: totalValue }(data, values);
        StateProbe memory viaMulticall = _probe(expectedAtomId, users.alice);

        _assertProbesEqual(direct, viaMulticall);
    }

    function test_diff_createTriplesFor_directVsMulticall() public {
        // Pre-create the subject/predicate/object atoms once; both paths
        // share them so the differential is only the triple creation.
        bytes32[] memory atomIds = createAtomsWithUniformCost(
            _toBytesArray3("diff-cTFor-subj", "diff-cTFor-pred", "diff-cTFor-obj"), ATOM_COST[0], users.alice
        );

        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];

        uint256[] memory tripleAssets = new uint256[](1);
        tripleAssets[0] = TRIPLE_COST[0] + 3 ether;
        uint256 totalValue = tripleAssets[0];

        uint256 snap = vm.snapshotState();

        // Path A: direct createTriplesFor (self-creation).
        resetPrank(users.alice);
        bytes32[] memory tripleIds = protocol.multiVault.createTriplesFor{ value: totalValue }(
            users.alice, subjectIds, predicateIds, objectIds, tripleAssets
        );
        bytes32 tripleId = tripleIds[0];
        StateProbe memory direct = _probe(tripleId, users.alice);

        // Path B: same call via multicall.
        require(vm.revertToState(snap), "revertToState failed");

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            IMultiVault.createTriplesFor, (users.alice, subjectIds, predicateIds, objectIds, tripleAssets)
        );
        uint256[] memory values = new uint256[](1);
        values[0] = totalValue;

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: totalValue }(data, values);
        StateProbe memory viaMulticall = _probe(tripleId, users.alice);

        _assertProbesEqual(direct, viaMulticall);
    }

    function test_multicall_allowsCreateAtomsForSelector() public {
        // Smoke test for a single createAtomsFor sub-call.
        bytes[] memory atomDataArr = new bytes[](1);
        atomDataArr[0] = abi.encodePacked("multicall-allow-cAFor");
        uint256[] memory createAssets = new uint256[](1);
        createAssets[0] = ATOM_COST[0];

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(IMultiVault.createAtomsFor, (users.alice, atomDataArr, createAssets));
        uint256[] memory values = new uint256[](1);
        values[0] = createAssets[0];

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: createAssets[0] }(data, values);

        bytes32 atomId = calculateAtomId(atomDataArr[0]);
        assertTrue(protocol.multiVault.isTermCreated(atomId), "atom must exist after multicall createAtomsFor");
        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice, "creator must be alice");
    }

    function test_multicall_allowsCreateTriplesForSelector() public {
        bytes32[] memory atomIds = createAtomsWithUniformCost(
            _toBytesArray3("mcp-cTFor-S", "mcp-cTFor-P", "mcp-cTFor-O"), ATOM_COST[0], users.alice
        );

        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];

        uint256[] memory tripleAssets = new uint256[](1);
        tripleAssets[0] = TRIPLE_COST[0];

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            IMultiVault.createTriplesFor, (users.alice, subjectIds, predicateIds, objectIds, tripleAssets)
        );
        uint256[] memory values = new uint256[](1);
        values[0] = tripleAssets[0];

        resetPrank(users.alice);
        protocol.multiVault.multicall{ value: tripleAssets[0] }(data, values);

        bytes32 tripleId = protocol.multiVault.calculateTripleId(atomIds[0], atomIds[1], atomIds[2]);
        assertTrue(protocol.multiVault.isTermCreated(tripleId), "triple must exist after multicall createTriplesFor");
    }

    function _toBytesArray3(string memory a, string memory b, string memory c)
        private
        pure
        returns (bytes[] memory arr)
    {
        arr = new bytes[](3);
        arr[0] = abi.encodePacked(a);
        arr[1] = abi.encodePacked(b);
        arr[2] = abi.encodePacked(c);
    }
}
