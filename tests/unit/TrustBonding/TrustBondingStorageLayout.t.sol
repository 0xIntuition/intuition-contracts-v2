// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

/// @title  TrustBondingStorageLayoutTest
/// @notice Storage layout regression for {TrustBonding} and its inherited {VotingEscrow} fork.
/// @dev    TrustBonding is a live TUP-upgradeable contract holding users' locked TRUST, so its
///         slot layout must never shift across upgrades. All OpenZeppelin bases use ERC-7201
///         namespaced storage, so linear slots are exactly: VotingEscrow fields at slots 0-11,
///         its `uint256[50]` gap at 12-61, TrustBonding fields at 62-68, and its `uint256[50]`
///         gap at 69-118. Each anchor below triangulates field, slot, and getter through the
///         natural write path (initialize, create_lock, unlock) or a raw store read back
///         through the public getter, so a reordered or shifted field fails loudly.
/// @dev    forge test --match-path 'tests/unit/TrustBonding/TrustBondingStorageLayout.t.sol'
contract TrustBondingStorageLayoutTest is TrustBondingBase {
    /* ============ VotingEscrow region ============ */
    uint256 internal constant MINTIME_SLOT = 0;
    uint256 internal constant TOKEN_SLOT = 1;
    uint256 internal constant SUPPLY_SLOT = 2;
    uint256 internal constant UNLOCKED_SLOT = 3;
    uint256 internal constant LOCKED_MAPPING_SLOT = 4;
    uint256 internal constant VOTING_ESCROW_GAP_FIRST_SLOT = 12;
    uint256 internal constant VOTING_ESCROW_GAP_LAST_SLOT = 61;

    /* ============ TrustBonding region ============ */
    uint256 internal constant TOTAL_CLAIMED_REWARDS_MAPPING_SLOT = 62;
    uint256 internal constant USER_CLAIMED_REWARDS_MAPPING_SLOT = 63;
    uint256 internal constant MULTI_VAULT_SLOT = 64;
    uint256 internal constant SATELLITE_EMISSIONS_CONTROLLER_SLOT = 65;
    uint256 internal constant SYSTEM_UTILIZATION_LOWER_BOUND_SLOT = 66;
    uint256 internal constant PERSONAL_UTILIZATION_LOWER_BOUND_SLOT = 67;
    uint256 internal constant TIMELOCK_SLOT = 68;
    uint256 internal constant TRUST_BONDING_GAP_FIRST_SLOT = 69;
    uint256 internal constant TRUST_BONDING_GAP_LAST_SLOT = 118;

    uint256 internal constant TEST_EPOCH = 5;
    uint256 internal constant TEST_CLAIMED_REWARDS = 123 ether;

    function _load(uint256 slot) internal view returns (uint256) {
        return uint256(vm.load(address(protocol.trustBonding), bytes32(slot)));
    }

    function test_storageLayout_votingEscrowScalarFields() external view {
        assertEq(_load(MINTIME_SLOT), protocol.trustBonding.MINTIME(), "slot 0 must hold MINTIME");
        assertEq(_load(MINTIME_SLOT), TRUST_BONDING_EPOCH_LENGTH, "MINTIME must equal the initialized epoch length");

        assertEq(_load(TOKEN_SLOT), uint256(uint160(protocol.trustBonding.token())), "slot 1 must hold token");
        assertEq(
            protocol.trustBonding.token(), address(protocol.wrappedTrust), "token must be the initialized TRUST token"
        );
    }

    function test_storageLayout_supply_atSlot2() external {
        assertEq(_load(SUPPLY_SLOT), 0, "supply must start at zero");

        // Natural write path: locking tokens is the only way supply increases
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        assertEq(_load(SUPPLY_SLOT), DEFAULT_DEPOSIT_AMOUNT, "slot 2 must hold supply");
        assertEq(protocol.trustBonding.supply(), DEFAULT_DEPOSIT_AMOUNT, "auto-getter must resolve to the same slot");
    }

    function test_storageLayout_unlocked_atSlot3() external {
        assertEq(_load(UNLOCKED_SLOT), 0, "unlocked must start false");

        // Natural write path: admin-only global unlock
        vm.startPrank(users.admin);
        protocol.trustBonding.unlock();
        vm.stopPrank();

        assertEq(_load(UNLOCKED_SLOT), 1, "slot 3 must hold unlocked");
        assertTrue(protocol.trustBonding.unlocked(), "auto-getter must resolve to the same slot");
    }

    function test_storageLayout_lockedMapping_atSlot4() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        // LockedBalance occupies two slots: { int128 amount; uint256 end }
        bytes32 baseSlot = keccak256(abi.encode(users.alice, LOCKED_MAPPING_SLOT));
        uint256 rawAmount = uint256(vm.load(address(protocol.trustBonding), baseSlot));
        uint256 rawEnd = uint256(vm.load(address(protocol.trustBonding), bytes32(uint256(baseSlot) + 1)));

        (int128 amount, uint256 end) = protocol.trustBonding.locked(users.alice);
        assertEq(rawAmount, uint256(int256(amount)), "locked[user].amount must live at keccak(user, slot 4)");
        assertEq(rawAmount, DEFAULT_DEPOSIT_AMOUNT, "locked amount must match the natural write");
        assertEq(rawEnd, end, "locked[user].end must live one slot after the amount");
        assertGt(rawEnd, block.timestamp, "lock end must be in the future");
    }

    function test_storageLayout_trustBondingFields_atSlots64Through68() external view {
        // All five fields are written during initialize — the natural write path
        assertEq(
            _load(MULTI_VAULT_SLOT),
            uint256(uint160(protocol.trustBonding.multiVault())),
            "slot 64 must hold multiVault"
        );
        assertEq(
            _load(SATELLITE_EMISSIONS_CONTROLLER_SLOT),
            uint256(uint160(protocol.trustBonding.satelliteEmissionsController())),
            "slot 65 must hold satelliteEmissionsController"
        );
        assertEq(
            _load(SYSTEM_UTILIZATION_LOWER_BOUND_SLOT),
            protocol.trustBonding.systemUtilizationLowerBound(),
            "slot 66 must hold systemUtilizationLowerBound"
        );
        assertEq(
            _load(PERSONAL_UTILIZATION_LOWER_BOUND_SLOT),
            protocol.trustBonding.personalUtilizationLowerBound(),
            "slot 67 must hold personalUtilizationLowerBound"
        );
        assertEq(_load(TIMELOCK_SLOT), uint256(uint160(address(users.timelock))), "slot 68 must hold timelock");
        assertEq(protocol.trustBonding.timelock(), users.timelock, "auto-getter must resolve to the same slot");
    }

    function test_storageLayout_claimedRewardsMappings_atSlots62And63() external {
        // Raw store into the claimed slot, read back through the public getter — triangulates
        // mapping base slot and getter without the heavy claimRewards setup
        bytes32 totalSlot = keccak256(abi.encode(TEST_EPOCH, TOTAL_CLAIMED_REWARDS_MAPPING_SLOT));
        vm.store(address(protocol.trustBonding), totalSlot, bytes32(TEST_CLAIMED_REWARDS));
        assertEq(
            protocol.trustBonding.totalClaimedRewardsForEpoch(TEST_EPOCH),
            TEST_CLAIMED_REWARDS,
            "totalClaimedRewardsForEpoch must resolve to mapping base slot 62"
        );

        bytes32 userSlot =
            keccak256(abi.encode(TEST_EPOCH, keccak256(abi.encode(users.alice, USER_CLAIMED_REWARDS_MAPPING_SLOT))));
        vm.store(address(protocol.trustBonding), userSlot, bytes32(TEST_CLAIMED_REWARDS));
        assertEq(
            protocol.trustBonding.userClaimedRewardsForEpoch(users.alice, TEST_EPOCH),
            TEST_CLAIMED_REWARDS,
            "userClaimedRewardsForEpoch must resolve to mapping base slot 63"
        );
    }

    function test_storageLayout_gapRegions_remainZero() external {
        // Exercise storage through natural activity first — gap slots must stay zero regardless
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _createLock(users.bob, LARGE_DEPOSIT_AMOUNT);
        protocol.trustBonding.checkpoint();

        for (uint256 slot = VOTING_ESCROW_GAP_FIRST_SLOT; slot <= VOTING_ESCROW_GAP_LAST_SLOT; slot++) {
            assertEq(_load(slot), 0, "VotingEscrow upgrade-safety gap slot must remain zero");
        }

        for (uint256 slot = TRUST_BONDING_GAP_FIRST_SLOT; slot <= TRUST_BONDING_GAP_LAST_SLOT; slot++) {
            assertEq(_load(slot), 0, "TrustBonding upgrade-safety gap slot must remain zero");
        }

        // One slot past the final gap must also be zero — catches an accidental spill if a
        // future field is appended without shrinking the gap
        assertEq(_load(TRUST_BONDING_GAP_LAST_SLOT + 1), 0, "slot past the final gap must be zero");
    }
}
