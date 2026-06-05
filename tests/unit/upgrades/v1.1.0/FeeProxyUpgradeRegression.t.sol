// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FeeProxyBaseTest } from "tests/unit/FeeProxy/FeeProxyBase.t.sol";

/// @title  FeeProxy v1.1.0 Upgrade Regression
/// @notice Day-one storage-layout snapshot for {FeeProxy}, deployed to Intuition
///         Sepolia: this test pins the expected slot index for every top-level
///         state variable so the live layout stays stable. Any future
///         storage change that shifts these slots must update this anchor in
///         the same PR.
/// @dev    Part of the v1.1.0 pre-audit upgrade-regression set under
///         `tests/unit/upgrades/v1.1.0/` (mirrors the v1.0.2 grouping of
///         `CoreMainnetUpgradeRegression`).
/// @custom:upgrade v1.1.0
contract FeeProxyUpgradeRegressionTest is FeeProxyBaseTest {
    /* =================================================== */
    /*                    EXPECTED SLOTS                   */
    /* =================================================== */

    uint256 internal constant SLOT_MULTI_VAULT = 0;
    uint256 internal constant SLOT_TREASURY = 1;
    uint256 internal constant SLOT_MAX_BPS = 2;
    uint256 internal constant SLOT_MAX_FIXED_FEE = 3;
    uint256 internal constant SLOT_REGISTRATION_FEE = 4;
    uint256 internal constant SLOT_AFFILIATE_CONFIGS = 5;
    uint256 internal constant SLOT_PENDING_REFUND = 6;
    uint256 internal constant SLOT_AFFILIATE_STATS = 7;
    uint256 internal constant SLOT_AFFILIATE_USER_STATS = 8;
    uint256 internal constant SLOT_GAP_START = 9;
    uint256 internal constant GAP_LENGTH = 50;

    function test_storageLayout_topLevelSlots() external view {
        assertEq(
            uint256(vm.load(address(feeProxy), bytes32(SLOT_MULTI_VAULT))),
            uint256(uint160(address(protocol.multiVault))),
            "slot 0: multiVault"
        );
        assertEq(
            uint256(vm.load(address(feeProxy), bytes32(SLOT_TREASURY))),
            uint256(uint160(address(treasury))),
            "slot 1: treasury"
        );
        assertEq(uint256(vm.load(address(feeProxy), bytes32(SLOT_MAX_BPS))), INITIAL_MAX_BPS, "slot 2: maxBps");
        assertEq(
            uint256(vm.load(address(feeProxy), bytes32(SLOT_MAX_FIXED_FEE))),
            INITIAL_MAX_FIXED_FEE,
            "slot 3: maxFixedFee"
        );
        assertEq(
            uint256(vm.load(address(feeProxy), bytes32(SLOT_REGISTRATION_FEE))),
            INITIAL_REGISTRATION_FEE,
            "slot 4: registrationFee"
        );
    }

    function test_storageLayout_pendingRefundMapping() external {
        // Stage a pending refund and read it back from the expected mapping slot.
        address user = makeAddr("storageProbeUser");
        bytes32 slot = keccak256(abi.encode(user, SLOT_PENDING_REFUND));
        vm.store(address(feeProxy), slot, bytes32(uint256(123)));

        assertEq(feeProxy.pendingRefund(user), 123, "pendingRefund maps to slot 6");
    }

    function test_storageLayout_affiliateConfigsMapping() external {
        _registerSampleAffiliate();

        // The first field of AffiliateConfig is `FeeConfig fees` whose first
        // member is `depositBps`. The base slot for `_affiliateConfigs[affiliate]`
        // is keccak256(affiliate . SLOT_AFFILIATE_CONFIGS); the FeeConfig
        // members occupy that and the next three slots.
        bytes32 baseSlot = keccak256(abi.encode(affiliate, SLOT_AFFILIATE_CONFIGS));
        uint256 storedDepositBps = uint256(vm.load(address(feeProxy), baseSlot));
        assertEq(storedDepositBps, SAMPLE_DEPOSIT_BPS, "_affiliateConfigs maps to slot 5");
    }

    function test_storageLayout_affiliateStatsMapping() external {
        bytes32 slot = keccak256(abi.encode(affiliate, SLOT_AFFILIATE_STATS));
        vm.store(address(feeProxy), slot, bytes32(uint256(321)));

        assertEq(feeProxy.affiliateStats(affiliate).txCount, 321, "_affiliateStats maps to slot 7");
    }

    function test_storageLayout_affiliateUserStatsMapping() external {
        address user = makeAddr("statsProbeUser");
        bytes32 affiliateBase = keccak256(abi.encode(affiliate, SLOT_AFFILIATE_USER_STATS));
        bytes32 userBase = keccak256(abi.encode(user, affiliateBase));
        vm.store(address(feeProxy), userBase, bytes32(uint256(654)));

        assertEq(feeProxy.affiliateUserStats(affiliate, user).txCount, 654, "_affiliateUserStats maps to slot 8");
    }

    function test_storageLayout_gapDoesNotOverlapAnalytics() external view {
        // None of the gap slots should contain data after initialization.
        for (uint256 i = 0; i < GAP_LENGTH; ++i) {
            bytes32 slot = bytes32(SLOT_GAP_START + i);
            assertEq(uint256(vm.load(address(feeProxy), slot)), 0, "gap slot must remain zero");
        }
    }
}
