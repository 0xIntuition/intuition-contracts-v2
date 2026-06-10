// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

/// @title  StorageMirrorIntegrity
/// @notice Hypothesis 1 (deep pre-audit): MultiVaultLib storage-mirror integrity for the new
///         v1.1.0 slots.
///
/// Invariant under test: every slot the delegatecall library (`MultiVaultLib`, executing in
/// MultiVault's storage context via DELEGATECALL with `_s().slot == 0`) writes maps byte-exactly to
/// the slot MultiVault's own getters read. The net-new v1.1.0 slots are `timelock`(34),
/// `atomCreators`(35), `atomCreatedAt`(36) and `lastSystemUtilizationEpoch`(37). A mismatch would
/// silently mis-attribute creators or corrupt the rollover source. These tests pin the raw slots
/// with `vm.load` and cross-check them against the public getters so any future layout drift
/// between the `MultiVaultLib.Storage` struct and MultiVault's declared variables fails loudly.
///
/// Verdict: DEFENDED. Library writes and contract reads agree on every probed slot. Recorded as a
/// regression pin over the new slots (complements the existing storage-layout suite).
contract StorageMirrorIntegrityTest is BaseTest {
    // Slot indices from `forge inspect MultiVault storage-layout` (mirrored by MultiVaultLib.Storage).
    uint256 internal constant SLOT_TOTAL_TERMS_CREATED = 0;
    uint256 internal constant SLOT_ATOM_CREATORS = 35;
    uint256 internal constant SLOT_ATOM_CREATED_AT = 36;
    uint256 internal constant SLOT_LAST_SYSTEM_UTILIZATION_EPOCH = 37;

    uint256 internal curveId;

    function setUp() public override {
        super.setUp();
        curveId = getDefaultCurveId();
    }

    /// @dev The creator and creation timestamp written by the library land in the exact mapping
    ///      slots MultiVault's getters resolve, and the getters echo the raw storage.
    function test_atomCreatorAndCreatedAt_writtenToMirroredSlots() external {
        uint256 createdAtExpected = block.timestamp;
        bytes32 atomId = _createAtom("mirror-creator", users.alice);

        bytes32 rawCreator = vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATORS)));
        bytes32 rawCreatedAt =
            vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATED_AT)));

        assertEq(address(uint160(uint256(rawCreator))), users.alice, "slot 35 holds the creator address");
        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice, "getter mirrors slot 35");
        assertEq(
            address(uint160(uint256(rawCreator))),
            protocol.multiVault.getAtomCreator(atomId),
            "raw slot and getter agree (creator)"
        );

        assertEq(uint256(rawCreatedAt), createdAtExpected, "slot 36 holds the creation timestamp");
        assertEq(uint256(protocol.multiVault.getAtomCreatedAt(atomId)), createdAtExpected, "getter mirrors slot 36");
        // uint48 field must not carry dirty high bits.
        assertEq(uint256(rawCreatedAt) >> 48, 0, "slot 36 high bits are clean (uint48 packing)");
    }

    /// @dev The running term counter at slot 0 stays in lockstep with the public getter across
    ///      multiple creates.
    function test_totalTermsCreated_slotZeroMatchesGetter() external {
        _createAtom("mirror-count-a", users.alice);
        _createAtom("mirror-count-b", users.bob);

        bytes32 rawCount = vm.load(address(protocol.multiVault), bytes32(SLOT_TOTAL_TERMS_CREATED));
        assertEq(uint256(rawCount), protocol.multiVault.totalTermsCreated(), "slot 0 mirrors totalTermsCreated()");
        assertEq(uint256(rawCount), 2, "two atoms created");
    }

    /// @dev After an epoch advance, the first MultiVault action triggers the system rollover, which
    ///      writes `lastSystemUtilizationEpoch` (slot 37). Raw slot and getter must agree, and the
    ///      value must equal the current epoch.
    function test_lastSystemUtilizationEpoch_slot37MatchesGetterAfterRollover() external {
        // Fresh deploy path: slot 37 is unseeded (reinitialize is not run by the harness).
        bytes32 rawBefore = vm.load(address(protocol.multiVault), bytes32(SLOT_LAST_SYSTEM_UTILIZATION_EPOCH));
        assertEq(uint256(rawBefore), 0, "fresh deploy leaves slot 37 zero before any epoch>=1 action");

        // Advance into epoch 1 so the system-rollover branch (`currentEpoch > 0`) runs.
        uint256 epochLength = protocol.trustBonding.epochLength();
        vm.warp(block.timestamp + epochLength);
        uint256 currentEpoch = protocol.multiVault.currentEpoch();
        assertEq(currentEpoch, 1, "precondition: advanced to epoch 1");

        _createAtom("mirror-rollover", users.alice);

        bytes32 rawAfter = vm.load(address(protocol.multiVault), bytes32(SLOT_LAST_SYSTEM_UTILIZATION_EPOCH));
        assertEq(
            uint256(rawAfter), protocol.multiVault.lastSystemUtilizationEpoch(), "slot 37 mirrors the public getter"
        );
        assertEq(uint256(rawAfter), currentEpoch, "rollover sets slot 37 to the current epoch");
    }

    /// @dev A later deposit by a different account must not rewrite the atom's creator/createdAt
    ///      slots — those are create-only.
    function test_depositDoesNotMutateCreatorOrCreatedAtSlots() external {
        bytes32 atomId = _createAtom("mirror-immutable", users.alice);

        bytes32 creatorBefore = vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATORS)));
        bytes32 createdAtBefore =
            vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATED_AT)));

        // Different user deposits into the same atom in a later block.
        vm.warp(block.timestamp + 1);
        vm.startPrank(users.bob);
        protocol.multiVault.deposit{ value: 1 ether }(users.bob, atomId, curveId, 0);
        vm.stopPrank();

        bytes32 creatorAfter = vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATORS)));
        bytes32 createdAtAfter =
            vm.load(address(protocol.multiVault), keccak256(abi.encode(atomId, SLOT_ATOM_CREATED_AT)));

        assertEq(creatorAfter, creatorBefore, "deposit does not touch atomCreators slot");
        assertEq(createdAtAfter, createdAtBefore, "deposit does not touch atomCreatedAt slot");
        assertEq(protocol.multiVault.getAtomCreator(atomId), users.alice, "creator unchanged after foreign deposit");
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
