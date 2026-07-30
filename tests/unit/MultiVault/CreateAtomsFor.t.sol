// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

contract CreateAtomsForTest is BaseTest {
    uint256 internal CURVE_ID;

    /// @dev Mirrors {ApprovalTypes.CREATION} = 0b100. Tests use the raw bit so
    ///      the assertion logic doesn't drift if enum members are appended.
    uint8 internal constant CREATION_BIT = 4;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    /* =================================================== */
    /*                APPROVAL GATE — SUCCESS              */
    /* =================================================== */

    function test_createAtomsFor_singleAtom_Success_withCreationApproval() public {
        // Alice (creator) approves Bob (sender) for creation only.
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes32 atomId = _createOneFor(users.alice, users.bob, "creation-only-approval");

        assertTrue(protocol.multiVault.isTermCreated(atomId), "atom should exist");
        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice, "creator must be alice, not the sender");
    }

    function test_createAtomsFor_singleAtom_Success_withDepositAndCreationApproval() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT_AND_CREATION);

        bytes32 atomId = _createOneFor(users.alice, users.bob, "deposit-and-creation-approval");

        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice);
    }

    function test_createAtomsFor_singleAtom_Success_withRedemptionAndCreationApproval() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION_AND_CREATION);

        bytes32 atomId = _createOneFor(users.alice, users.bob, "redemption-and-creation-approval");

        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice);
    }

    function test_createAtomsFor_singleAtom_Success_withAllApproval() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.ALL);

        bytes32 atomId = _createOneFor(users.alice, users.bob, "all-approval");

        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice);
    }

    function test_createAtomsFor_creatorEqualsMsgSender_Success_withoutAnyApproval() public {
        // Self-creation short-circuit: no approval needed when creator == msg.sender.
        bytes32 atomId = _createOneFor(users.alice, users.alice, "self-creation-no-approval");

        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice);
    }

    function test_createAtomsFor_multipleAtoms_Success() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);
        vm.warp(block.timestamp + 1 days);
        uint48 expectedTimestamp = uint48(block.timestamp);

        bytes[] memory data = new bytes[](3);
        data[0] = "createFor-multi-1";
        data[1] = "createFor-multi-2";
        data[2] = "createFor-multi-3";

        uint256[] memory assets = new uint256[](3);
        assets[0] = ATOM_COST[0];
        assets[1] = ATOM_COST[0];
        assets[2] = ATOM_COST[0];

        uint256 total = ATOM_COST[0] * 3;

        resetPrank(users.bob);
        bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: total }(users.alice, data, assets);

        assertEq(ids.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(protocol.multiVault.isTermCreated(ids[i]), "each atom must exist");
            assertEq(protocol.multiVault.getAtomCreator(ids[i]), users.alice, "each atom must credit alice");
            assertEq(
                protocol.multiVault.getAtomCreatedAt(ids[i]), expectedTimestamp, "each atom must record creation time"
            );
        }
    }

    /* =================================================== */
    /*                APPROVAL GATE — REVERTS              */
    /* =================================================== */

    function test_createAtomsFor_RevertWhen_NoApproval() public {
        // No setupApproval call.
        bytes[] memory data = _singleByteArr("no-approval");
        uint256[] memory assets = _singleUintArr(ATOM_COST[0]);

        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_CreatorNotApproved.selector);
        protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(users.alice, data, assets);
    }

    function test_createAtomsFor_RevertWhen_OnlyDepositApproval() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, "only-deposit-approval");
    }

    function test_createAtomsFor_RevertWhen_OnlyRedemptionApproval() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, "only-redemption-approval");
    }

    function test_createAtomsFor_RevertWhen_OnlyBothApproval() public {
        // BOTH = DEPOSIT | REDEMPTION, no CREATION bit.
        setupApproval(users.alice, users.bob, ApprovalTypes.BOTH);
        _expectCreatorNotApprovedRevert(users.alice, users.bob, "only-both-approval");
    }

    function test_createAtomsFor_RevertWhen_ApprovedSenderIsDifferent() public {
        // Alice approves Bob for creation; Charlie tries to act for Alice.
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);
        _expectCreatorNotApprovedRevert(users.alice, users.charlie, "different-sender-not-approved");
    }

    /* =================================================== */
    /*                  STATE ATTRIBUTION                  */
    /* =================================================== */

    function test_createAtomsFor_creditsUtilizationToCreator_NotSender() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        uint256 epoch = protocol.multiVault.currentEpoch();
        int256 aliceBefore = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        int256 bobBefore = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        uint256 payment = ATOM_COST[0] + 2 ether;
        bytes[] memory data = _singleByteArr("utilization-attribution");
        uint256[] memory assets = _singleUintArr(payment);

        resetPrank(users.bob);
        protocol.multiVault.createAtomsFor{ value: payment }(users.alice, data, assets);

        int256 aliceAfter = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        int256 bobAfter = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        assertGt(aliceAfter, aliceBefore, "alice's utilization must increase");
        assertEq(bobAfter, bobBefore, "bob's utilization must NOT change");
        assertEq(aliceAfter - aliceBefore, int256(payment), "alice's utilization delta must equal payment");
    }

    function test_createAtomsFor_recordsCreatorAndCreatedAt() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);
        vm.warp(block.timestamp + 1 days);
        uint48 expectedTimestamp = uint48(block.timestamp);
        bytes32 atomId = _createOneFor(users.alice, users.bob, "creator-attribution");

        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice, "atomCreators must point to creator");
        assertNotEq(protocol.multiVault.getAtomCreator(atomId), users.bob, "sender must not receive attribution");
        assertEq(protocol.multiVault.getAtomCreatedAt(atomId), expectedTimestamp, "creation time must be exact");
    }

    function test_createAtomsFor_emitsAtomCreatedWithCreator() public {
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes memory atomData = "event-attribution";
        bytes32 expectedAtomId = calculateAtomId(atomData);

        expectAtomCreated(users.alice, expectedAtomId, atomData);

        bytes[] memory data = new bytes[](1);
        data[0] = atomData;
        uint256[] memory assets = _singleUintArr(ATOM_COST[0]);

        resetPrank(users.bob);
        protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(users.alice, data, assets);
    }

    /* =================================================== */
    /*               DIFFERENTIAL: createAtoms             */
    /* =================================================== */

    /// @dev Snapshot of observable on-chain state after a create call.
    ///      Bundled to keep parity assertions out of the local-variable budget.
    struct AtomCreateProbe {
        address atomCreator;
        uint256 vaultTotalAssets;
        uint256 vaultTotalShares;
        uint256 holderShares;
        uint256 totalTermsCreated;
        int256 personalUtilization;
    }

    function test_createAtomsFor_creatorEqualsMsgSender_ParityWithCreateAtoms() public {
        // When creator == msg.sender, createAtomsFor must produce state
        // identical to createAtoms.
        bytes memory atomBytes = "parity-payload";
        bytes32 expectedAtomId = calculateAtomId(atomBytes);

        bytes[] memory data = new bytes[](1);
        data[0] = atomBytes;
        uint256[] memory assets = _singleUintArr(ATOM_COST[0] + 1 ether);
        uint256 payment = assets[0];

        uint256 snap = vm.snapshotState();

        // Path A: createAtoms (existing entry point).
        resetPrank(users.alice);
        protocol.multiVault.createAtoms{ value: payment }(data, assets);
        AtomCreateProbe memory direct = _probeAtom(expectedAtomId, users.alice);

        require(vm.revertToState(snap), "revertToState failed");

        // Path B: createAtomsFor with creator == msg.sender.
        resetPrank(users.alice);
        protocol.multiVault.createAtomsFor{ value: payment }(users.alice, data, assets);
        AtomCreateProbe memory viaFor = _probeAtom(expectedAtomId, users.alice);

        _assertAtomProbesEqual(direct, viaFor);
    }

    function _probeAtom(bytes32 atomId, address holder) internal view returns (AtomCreateProbe memory probe) {
        probe.atomCreator = protocol.multiVault.getAtomCreator(atomId);
        (probe.vaultTotalAssets, probe.vaultTotalShares) = protocol.multiVault.getVault(atomId, CURVE_ID);
        probe.holderShares = protocol.multiVault.getShares(holder, atomId, CURVE_ID);
        probe.totalTermsCreated = protocol.multiVault.totalTermsCreated();
        probe.personalUtilization =
            protocol.multiVault.getUserUtilizationForEpoch(holder, protocol.multiVault.currentEpoch());
    }

    function _assertAtomProbesEqual(AtomCreateProbe memory a, AtomCreateProbe memory b) internal pure {
        assertEq(b.atomCreator, a.atomCreator, "creator parity");
        assertEq(b.vaultTotalAssets, a.vaultTotalAssets, "vault totalAssets parity");
        assertEq(b.vaultTotalShares, a.vaultTotalShares, "vault totalShares parity");
        assertEq(b.holderShares, a.holderShares, "holder shares parity");
        assertEq(b.totalTermsCreated, a.totalTermsCreated, "totalTermsCreated parity");
        assertEq(b.personalUtilization, a.personalUtilization, "personal utilization parity");
    }

    /* =================================================== */
    /*                        FUZZ                         */
    /* =================================================== */

    /// @dev Fuzz over the full 0..7 enum range. Any value with the CREATION
    ///      bit (4) set must succeed; the rest must revert.
    function testFuzz_createAtomsFor_approvalBitParity(uint8 raw) public {
        uint8 bits = uint8(bound(raw, 0, 7));
        ApprovalTypes approval = ApprovalTypes(bits);

        // setupApproval calls the approve function; ApprovalTypes.NONE is
        // a delete, not a grant — handle it by skipping the call instead.
        if (approval != ApprovalTypes.NONE) {
            setupApproval(users.alice, users.bob, approval);
        }

        bytes[] memory data = _singleByteArr(string.concat("fuzz-approval-", vm.toString(bits)));
        uint256[] memory assets = _singleUintArr(ATOM_COST[0]);

        resetPrank(users.bob);
        if ((bits & CREATION_BIT) != 0) {
            bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(users.alice, data, assets);
            assertEq(protocol.multiVault.getAtomCreator(ids[0]), users.alice);
        } else {
            vm.expectRevert(MultiVault.MultiVault_CreatorNotApproved.selector);
            protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(users.alice, data, assets);
        }
    }

    /// @dev Fuzz over arbitrary creator address + atom count + asset amount.
    ///      Asserts: (i) each created atom credits the fuzz-chosen creator,
    ///      (ii) creator's utilization receives the full payment, (iii) the
    ///      bob (sender) account's utilization is untouched.
    function testFuzz_createAtomsFor_arbitraryCreator_AtomCount_Assets(
        address rawCreator,
        uint8 rawCount,
        uint96 rawPerAtom,
        bytes32 salt
    ) public {
        vm.assume(rawCreator != address(0));
        vm.assume(rawCreator != users.bob);
        // Skip any code-bearing address so deposit-to-account semantics stay
        // clean (no SCW receive() interactions, no MultiVault proxy itself).
        vm.assume(rawCreator.code.length == 0);

        uint256 count = bound(uint256(rawCount), 1, 5);
        uint256 perAtomAssets = bound(uint256(rawPerAtom), ATOM_COST[0] + 1 ether, 50 ether);
        uint256 total = perAtomAssets * count;

        setupApproval(rawCreator, users.bob, ApprovalTypes.CREATION);

        _runArbitraryCreatorFuzz(rawCreator, salt, count, perAtomAssets, total);
    }

    function _runArbitraryCreatorFuzz(
        address creator,
        bytes32 salt,
        uint256 count,
        uint256 perAtomAssets,
        uint256 total
    ) internal {
        uint256 epoch = protocol.multiVault.currentEpoch();
        int256 creatorUtilBefore = protocol.multiVault.getUserUtilizationForEpoch(creator, epoch);
        int256 senderUtilBefore = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        bytes[] memory data = new bytes[](count);
        uint256[] memory assets = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            data[i] = abi.encodePacked("fuzz-arbitrary-", salt, i);
            assets[i] = perAtomAssets;
        }

        vm.deal(users.bob, total);
        resetPrank(users.bob);
        bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: total }(creator, data, assets);

        assertEq(ids.length, count, "id count must match input length");
        for (uint256 i = 0; i < count; i++) {
            assertTrue(protocol.multiVault.isTermCreated(ids[i]), "each atom must exist");
            assertEq(protocol.multiVault.getAtomCreator(ids[i]), creator, "each atom must credit the fuzz creator");
        }

        assertEq(
            protocol.multiVault.getUserUtilizationForEpoch(creator, epoch) - creatorUtilBefore,
            int256(total),
            "creator utilization delta == total payment"
        );
        assertEq(
            protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch),
            senderUtilBefore,
            "sender utilization unchanged"
        );
    }

    function testFuzz_createAtomsFor_payment_AttributesUtilizationToCreator(uint256 rawAmount, bytes32 salt) public {
        uint256 atomCost = ATOM_COST[0];
        // Stay comfortably above the atomCost floor so the fuzz exercises
        // attribution behavior, not the pre-existing MultiVault dust-math
        // edge that fires when assets ≈ atomCost after fixed-fee subtraction.
        uint256 payment = bound(rawAmount, atomCost + 1 ether, 1000 ether);

        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        uint256 epoch = protocol.multiVault.currentEpoch();
        int256 aliceBefore = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        int256 bobBefore = protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked("fuzz-payment-", salt);
        uint256[] memory assets = _singleUintArr(payment);

        resetPrank(users.bob);
        bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: payment }(users.alice, data, assets);

        assertEq(protocol.multiVault.getAtomCreator(ids[0]), users.alice);
        assertEq(
            protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch) - aliceBefore,
            int256(payment),
            "creator utilization delta == payment"
        );
        assertEq(
            protocol.multiVault.getUserUtilizationForEpoch(users.bob, epoch), bobBefore, "sender utilization unchanged"
        );
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    function _createOneFor(address creator, address sender, string memory atomString) internal returns (bytes32) {
        bytes[] memory data = _singleByteArr(atomString);
        uint256[] memory assets = _singleUintArr(ATOM_COST[0]);

        resetPrank(sender);
        bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(creator, data, assets);
        return ids[0];
    }

    function _expectCreatorNotApprovedRevert(address creator, address sender, string memory atomString) internal {
        bytes[] memory data = _singleByteArr(atomString);
        uint256[] memory assets = _singleUintArr(ATOM_COST[0]);

        resetPrank(sender);
        vm.expectRevert(MultiVault.MultiVault_CreatorNotApproved.selector);
        protocol.multiVault.createAtomsFor{ value: ATOM_COST[0] }(creator, data, assets);
    }

    function _singleByteArr(string memory s) internal pure returns (bytes[] memory arr) {
        arr = new bytes[](1);
        arr[0] = abi.encodePacked(s);
    }

    function _singleUintArr(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }
}
