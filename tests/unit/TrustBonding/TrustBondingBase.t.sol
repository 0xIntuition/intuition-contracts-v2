// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";

contract TrustBondingBase is BaseTest {
    // Initializer structs
    MetaERC20DispatchInit public metaERC20DispatchInit;
    CoreEmissionsControllerInit public coreEmissionsInit;

    uint256 public constant SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
    uint256 public constant PERSONAL_UTILIZATION_LOWER_BOUND = 3000; // 30%

    uint256 public initialTokens = 10_000 ether;
    uint256 public lockDuration = 2 * 365 days; // 2 years
    uint256 public DEFAULT_LOCK_DURATION = 2 * 365 days; // 2 years
    uint256 public additionalTokens = 1000 ether;

    /// @notice Test constants for SatelliteEmissionsController
    uint256 internal constant TEST_START_TIMESTAMP = 1_640_995_200; // Jan 1, 2022
    uint256 internal constant TEST_EPOCH_LENGTH = 14 days;
    uint256 internal constant TEST_EMISSIONS_PER_EPOCH = 1_000_000 ether;
    uint256 internal constant TEST_REDUCTION_CLIFF = 26;
    uint256 internal constant TEST_REDUCTION_BASIS_POINTS = 1000; // 10%
    uint32 internal constant TEST_RECIPIENT_DOMAIN = 1;
    uint256 internal constant TEST_GAS_LIMIT = 125_000;

    uint256 public constant DEAL_AMOUNT = 1_000_000 ether;
    uint256 public constant SMALL_DEPOSIT_AMOUNT = 10 ether;
    uint256 public constant DEFAULT_DEPOSIT_AMOUNT = 100 ether;
    uint256 public constant LARGE_DEPOSIT_AMOUNT = 5000 ether;
    uint256 public constant XLARGE_DEPOSIT_AMOUNT = 10_000 ether;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual override {
        super.setUp();
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
    }

    function _deploySatelliteEmissionsController() internal returns (SatelliteEmissionsController) {
        // Deploy SatelliteEmissionsController implementation
        SatelliteEmissionsController satelliteEmissionsControllerImpl = new SatelliteEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy satelliteEmissionsControllerProxyContract =
            new TransparentUpgradeableProxy(address(satelliteEmissionsControllerImpl), users.admin, "");

        SatelliteEmissionsController satelliteEmissionsController =
            SatelliteEmissionsController(payable(address(satelliteEmissionsControllerProxyContract)));

        // Initialize the contract
        metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: address(0x123), // Mock meta spoke
            recipientDomain: TEST_RECIPIENT_DOMAIN,
            gasLimit: TEST_GAS_LIMIT,
            finalityState: FinalityState.INSTANT
        });

        coreEmissionsInit = CoreEmissionsControllerInit({
            startTimestamp: TEST_START_TIMESTAMP,
            emissionsLength: TEST_EPOCH_LENGTH,
            emissionsPerEpoch: TEST_EMISSIONS_PER_EPOCH,
            emissionsReductionCliff: TEST_REDUCTION_CLIFF,
            emissionsReductionBasisPoints: TEST_REDUCTION_BASIS_POINTS
        });

        vm.label(address(satelliteEmissionsController), "SatelliteEmissionsController");

        return satelliteEmissionsController;
    }

    function _deployNewTrustBondingContract() internal returns (TrustBonding) {
        TrustBonding newTrustBondingImpl = new TrustBonding();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(newTrustBondingImpl), users.admin, "");

        return TrustBonding(address(proxy));
    }

    /// @dev Internal function to advance the epoch by a given number of epochs
    function _advanceEpochs(uint256 epochs) internal {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 currentEpochEndTimestamp = protocol.trustBonding.epochTimestampEnd(currentEpoch);
        uint256 targetTimestamp = currentEpochEndTimestamp + epochs * protocol.trustBonding.epochLength();
        vm.warp(targetTimestamp - 1);
    }

    function _advanceToEpoch(uint256 targetEpoch) internal {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        if (targetEpoch <= currentEpoch) return;

        uint256 epochsToAdvance = targetEpoch - currentEpoch;
        uint256 timeToAdvance = epochsToAdvance * protocol.trustBonding.epochLength();
        vm.warp(block.timestamp + timeToAdvance);
    }

    function _createLock(address user) internal {
        _createLock(user, initialTokens);
    }

    function _createLock(address user, uint256 amount) internal {
        vm.startPrank(user);
        uint256 unlockTime = block.timestamp + DEFAULT_LOCK_DURATION;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), amount);
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _createLockWithDuration(address user, uint256 amount, uint256 unlockTime) internal {
        vm.startPrank(user);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), amount);
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _createLockWithDurationWithBlockTimestamp(address user, uint256 amount, uint256 unlockTime) internal {
        vm.startPrank(user);
        unlockTime = block.timestamp + unlockTime;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), amount);
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _calculateExpectedRewards(address user, uint256 epoch) internal view returns (uint256) {
        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(user, epoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(user, epoch);
        return rawRewards * utilizationRatio / BASIS_POINTS_DIVISOR;
    }

    function _setupUserForTrustBonding(address user) internal {
        resetPrank({ msgSender: user });

        // Give plenty of balance so initial + additional locks always succeed
        protocol.wrappedTrust.deposit{ value: additionalTokens * 10 }();

        // Approve once for all TrustBonding tests
        protocol.wrappedTrust.approve(address(protocol.trustBonding), type(uint256).max);
    }

    function _calculateUnlockTime(uint256 duration) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        // Calculate the raw unlock time
        uint256 rawUnlockTime = currentTime + duration;

        // Round down to nearest week
        uint256 roundedUnlockTime = (rawUnlockTime / ONE_WEEK) * ONE_WEEK;

        // Check if rounding reduced the duration below MINTIME
        if (roundedUnlockTime - currentTime < TRUST_BONDING_EPOCH_LENGTH) {
            // Add one week to ensure we're above MINTIME after rounding
            roundedUnlockTime += ONE_WEEK;
        }

        return roundedUnlockTime;
    }

    /// @dev Set total utilization for a specific epoch using vm.store
    /// @dev Set total utilization for a specific epoch using vm.store
    function _setTotalUtilizationForEpoch(uint256 epoch, int256 utilization) internal {
        // The MultiVault contract stores totalUtilization in a mapping
        // mapping(uint256 epoch => int256 totalUtilization) public totalUtilization;
        // We need to calculate the storage slot for this mapping

        // For MultiVault totalUtilization mapping, we need the actual storage slot number
        // This would typically be found by examining the contract's storage layout
        // For now, we'll use a placeholder approach that works with vm.store

        bytes32 slot = keccak256(abi.encode(epoch, uint256(31))); // MultiVault totalUtilization storage slot
        vm.store(address(protocol.multiVault), slot, bytes32(uint256(utilization)));
    }

    /// @dev Set user utilization for a specific epoch using vm.store
    function _setUserUtilizationForEpoch(address user, uint256 epoch, int256 utilization) internal {
        // The MultiVault contract stores personalUtilization in a nested mapping
        // mapping(address user => mapping(uint256 epoch => int256 utilization)) public personalUtilization;

        // Calculate the storage slot for the nested mapping
        bytes32 userSlot = keccak256(abi.encode(user, uint256(32))); // MultiVault personalUtilization storage slot
        bytes32 finalSlot = keccak256(abi.encode(epoch, userSlot));
        vm.store(address(protocol.multiVault), finalSlot, bytes32(uint256(utilization)));
    }

    /// @dev Set last active epoch for the system using vm.store
    function _setLastActiveEpochFoSystem(uint256 epoch) internal {
        // uint256 public lastSystemActiveEpoch;
        bytes32 slot = bytes32(uint256(34)); // MultiVault lastSystemActiveEpoch storage slot
        vm.store(address(protocol.multiVault), slot, bytes32(epoch));
    }

    /// @dev Set total claimed rewards for a specific epoch using vm.store
    function _setTotalClaimedRewardsForEpoch(uint256 epoch, uint256 claimedRewards) internal {
        // mapping(uint256 epoch => uint256 totalClaimedRewards) public totalClaimedRewardsForEpoch;
        // Assuming this is at storage slot 62 based on the TrustBonding contract
        bytes32 slot = keccak256(abi.encode(epoch, uint256(62)));
        vm.store(address(protocol.trustBonding), slot, bytes32(claimedRewards));
    }

    /// @dev Set user claimed rewards for a specific epoch using vm.store
    function _setUserClaimedRewardsForEpoch(address user, uint256 epoch, uint256 claimedRewards) internal {
        // mapping(address user => mapping(uint256 epoch => uint256 claimedRewards)) public userClaimedRewardsForEpoch;
        // Assuming this is at storage slot 63 based on the TrustBonding contract
        bytes32 userSlot = keccak256(abi.encode(user, uint256(63)));
        bytes32 finalSlot = keccak256(abi.encode(epoch, userSlot));
        vm.store(address(protocol.trustBonding), finalSlot, bytes32(claimedRewards));
    }
}
