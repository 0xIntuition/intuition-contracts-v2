// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

/// @title  MultiVaultStorageLayoutTest
/// @notice Append-only storage layout regression for {MultiVault}.
/// @dev    The contract's slot layout is mirrored field-for-field by the `Storage` struct in
///         {MultiVaultLib}; the library's `_s()` resolver assumes slot 0. Reordering or
///         shifting fields silently corrupts every library call. This test anchors the
///         post-`atomCreatedAt` region — the only part this PR touches — by:
///           1. driving `lastSystemUtilizationEpoch` to a known value via natural protocol
///              activity (the same write path real users take), then asserting the raw slot
///              read matches; this triangulates field, slot, and auto-getter.
///           2. asserting the upgrade-safety gap immediately after the new field is zero
///              across its declared length and just past it (no spill).
///         Future PRs that append fields should extend this test by writing the new field at
///         slot 38 and shrinking the asserted-zero range accordingly.
contract MultiVaultStorageLayoutTest is BaseTest {
    /// @dev Slot of the new `lastSystemUtilizationEpoch` field; load-bearing for the gap
    ///      defense added in this PR. See [`MultiVaultLib.Storage`].
    uint256 internal constant LAST_SYSTEM_UTILIZATION_EPOCH_SLOT = 37;

    /// @dev First slot of the post-`lastSystemUtilizationEpoch` upgrade-safety gap. The
    ///      gap is `uint256[47]`, occupying slots 38 through 84 inclusive.
    uint256 internal constant GAP_FIRST_SLOT = 38;
    uint256 internal constant GAP_LAST_SLOT = 84;

    uint256 internal CURVE_ID;

    function setUp() public override {
        super.setUp();
        CURVE_ID = getDefaultCurveId();
    }

    function test_storageLayout_lastSystemUtilizationEpoch_atSlot37() external {
        // Step out of epoch 0 so the `_rollover` system branch fires (the existing
        // `currentEpochLocal > 0` guard otherwise skips the write).
        vm.warp(block.timestamp + 14 days + 1);

        // Trigger a first-of-epoch `_addUtilization` via real protocol entry points.
        // This is the only write path for `lastSystemUtilizationEpoch`, so anchoring
        // here proves the natural code path writes to the slot we claim.
        createSimpleAtom("storage-layout-anchor", ATOM_COST[0], users.alice);

        uint256 currentEpoch = protocol.multiVault.currentEpoch();
        assertGt(currentEpoch, 0, "must be past epoch 0 for rollover branch to fire");

        // Triangulate (a) raw slot, (b) auto-getter, (c) natural write path.
        assertEq(
            uint256(vm.load(address(protocol.multiVault), bytes32(LAST_SYSTEM_UTILIZATION_EPOCH_SLOT))),
            currentEpoch,
            "slot 37 must hold lastSystemUtilizationEpoch"
        );
        assertEq(
            protocol.multiVault.lastSystemUtilizationEpoch(), currentEpoch, "auto-getter must resolve to the same slot"
        );
    }

    function test_storageLayout_gapShiftedTo47Slots_remainsZero() external {
        // Drive some natural activity so storage is fully exercised (atom creation,
        // utilization, fees, vault state) — gap slots must stay zero regardless.
        vm.warp(block.timestamp + 14 days + 1);
        bytes32 atomId = createSimpleAtom("storage-layout-gap", ATOM_COST[0], users.alice);
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1 ether, 0);

        for (uint256 slot = GAP_FIRST_SLOT; slot <= GAP_LAST_SLOT; slot++) {
            assertEq(
                uint256(vm.load(address(protocol.multiVault), bytes32(slot))),
                0,
                "upgrade-safety gap slot must remain zero"
            );
        }

        // One slot past the gap end must also be zero — catches an accidental spill if a
        // future field is appended without shrinking the gap, or if the gap itself was
        // accidentally enlarged into a colliding region.
        assertEq(
            uint256(vm.load(address(protocol.multiVault), bytes32(GAP_LAST_SLOT + 1))),
            0,
            "slot immediately past the gap must remain zero (no spill)"
        );
    }

    /// @dev The previous tail field (`atomCreatedAt`, slot 36) is a mapping; its base slot
    ///      must stay zero — entries live at `keccak256(abi.encode(key, slot))`. If a future
    ///      PR replaces this with a scalar, this assertion will trip and force a layout
    ///      review.
    function test_storageLayout_atomCreatedAtMappingBaseUnchanged() external {
        assertEq(
            uint256(vm.load(address(protocol.multiVault), bytes32(uint256(36)))),
            0,
            "slot 36 (atomCreatedAt mapping base) must remain zero"
        );
    }

    /* ============================================================ */
    /*   Storage-mirror coverage for the delegated write paths      */
    /*   (addresses the #603 review thread: prove every slot the    */
    /*   {MultiVaultLib} `Storage` mirror reads/writes via          */
    /*   DELEGATECALL is the same slot MultiVault's getters use)    */
    /* ============================================================ */

    uint256 internal constant SLOT_TOTAL_TERMS_CREATED = 0;
    uint256 internal constant SLOT_GENERAL_CONFIG = 1; // GeneralConfig.admin is the first field
    uint256 internal constant SLOT_APPROVALS = 26;
    uint256 internal constant SLOT_VAULTS = 27;
    uint256 internal constant SLOT_ACCUMULATED_PROTOCOL_FEES = 28;
    uint256 internal constant SLOT_TOTAL_UTILIZATION = 30;
    uint256 internal constant SLOT_PERSONAL_UTILIZATION = 31;
    uint256 internal constant SLOT_TIMELOCK = 34;
    uint256 internal constant SLOT_ATOM_CREATORS = 35;
    uint256 internal constant SLOT_ATOM_CREATED_AT = 36;

    function _raw(uint256 slot) private view returns (uint256) {
        return uint256(vm.load(address(protocol.multiVault), bytes32(slot)));
    }

    function _raw(bytes32 slot) private view returns (uint256) {
        return uint256(vm.load(address(protocol.multiVault), slot));
    }

    function _elem(bytes32 key, uint256 base) private pure returns (bytes32) {
        return keccak256(abi.encode(key, base));
    }

    function _elem(uint256 key, uint256 base) private pure returns (bytes32) {
        return keccak256(abi.encode(key, base));
    }

    function _elem(address key, uint256 base) private pure returns (bytes32) {
        return keccak256(abi.encode(key, base));
    }

    /// @notice Anchors the scalar + attribution slots written through the mirror by the createAtoms
    ///         library path, triangulating each against MultiVault's public getter so a mirror/contract
    ///         slot desync (library writes slot X, getter reads slot Y) fails here.
    function test_storageLayout_mirror_scalarAndAttribution() external {
        vm.warp(block.timestamp + 14 days + 1);
        bytes32 atomId = createSimpleAtom("mirror-attribution", ATOM_COST[0], users.alice);

        assertEq(_raw(SLOT_TOTAL_TERMS_CREATED), protocol.multiVault.totalTermsCreated(), "totalTermsCreated slot 0");

        (address admin,,,,,,,) = protocol.multiVault.generalConfig();
        assertEq(address(uint160(_raw(SLOT_GENERAL_CONFIG))), admin, "generalConfig.admin slot 1");

        assertEq(address(uint160(_raw(SLOT_TIMELOCK))), protocol.multiVault.timelock(), "timelock slot 34");

        assertEq(
            address(uint160(_raw(_elem(atomId, SLOT_ATOM_CREATORS)))),
            protocol.multiVault.getAtomCreator(atomId),
            "atomCreators slot 35"
        );
        assertEq(
            uint48(_raw(_elem(atomId, SLOT_ATOM_CREATED_AT))),
            protocol.multiVault.getAtomCreatedAt(atomId),
            "atomCreatedAt slot 36"
        );
    }

    /// @notice Anchors the system/personal utilization + protocol-fee accounting slots written by the
    ///         createAtoms library path.
    function test_storageLayout_mirror_utilizationAndFees() external {
        vm.warp(block.timestamp + 14 days + 1);
        uint256 epoch = protocol.multiVault.currentEpoch();
        createSimpleAtom("mirror-utilization", ATOM_COST[0], users.alice);

        int256 totalUtil = protocol.multiVault.getTotalUtilizationForEpoch(epoch);
        assertGt(totalUtil, 0, "precondition: total utilization credited");
        assertEq(_raw(_elem(epoch, SLOT_TOTAL_UTILIZATION)), uint256(totalUtil), "totalUtilization slot 30");

        int256 userUtil = protocol.multiVault.getUserUtilizationForEpoch(users.alice, epoch);
        assertGt(userUtil, 0, "precondition: personal utilization credited");
        bytes32 inner = _elem(users.alice, SLOT_PERSONAL_UTILIZATION);
        assertEq(_raw(_elem(epoch, uint256(inner))), uint256(userUtil), "personalUtilization slot 31");

        assertEq(
            _raw(_elem(epoch, SLOT_ACCUMULATED_PROTOCOL_FEES)),
            protocol.multiVault.accumulatedProtocolFees(epoch),
            "accumulatedProtocolFees slot 28"
        );
    }

    /// @notice Anchors the nested approvals slot (approvals[receiver][sender]) read by the on-behalf
    ///         creation/deposit library paths. Alice (receiver = msg.sender) approves Bob (sender).
    function test_storageLayout_mirror_approvals() external {
        resetPrank({ msgSender: users.alice });
        protocol.multiVault.approve(users.bob, ApprovalTypes.DEPOSIT);

        bytes32 inner = _elem(users.alice, SLOT_APPROVALS);
        assertEq(_raw(_elem(users.bob, uint256(inner))), uint256(uint8(ApprovalTypes.DEPOSIT)), "approvals slot 26");
    }

    /// @notice Anchors the nested vaults slot (VaultState.totalAssets @ +0, totalShares @ +1) written
    ///         by the deposit/create library path.
    function test_storageLayout_mirror_vaults() external {
        vm.warp(block.timestamp + 14 days + 1);
        bytes32 atomId = createSimpleAtom("mirror-vaults", ATOM_COST[0], users.alice);
        makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 1 ether, 0);

        (uint256 totalAssets, uint256 totalShares) = protocol.multiVault.getVault(atomId, CURVE_ID);
        assertGt(totalShares, 0, "precondition: vault has shares");

        bytes32 base = _elem(CURVE_ID, uint256(_elem(atomId, SLOT_VAULTS)));
        assertEq(_raw(base), totalAssets, "vaults VaultState.totalAssets slot 27+0");
        assertEq(_raw(bytes32(uint256(base) + 1)), totalShares, "vaults VaultState.totalShares slot 27+1");
    }
}
