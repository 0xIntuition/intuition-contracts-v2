// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { console, Vm } from "forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

contract TrustBondingBase is BaseTest {
    /// @notice Test constants
    uint256 public constant SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
    uint256 public constant PERSONAL_UTILIZATION_LOWER_BOUND = 3000; // 30%
    uint256 public initialTokens = 10_000 * 1e18;
    uint256 public lockDuration = 2 * 365 days; // 2 years

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual override {
        super.setUp();
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
    }

    function _deployNewTrustBondingContract() internal returns (TrustBonding) {
        TrustBonding newTrustBondingImpl = new TrustBonding();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(newTrustBondingImpl), users.admin, "");

        return TrustBonding(address(proxy));
    }

    function _bondTokens(address user, uint256 amount) internal {
        vm.startPrank(user);
        uint256 unlockTime = block.timestamp + 2 * 365 days; // 2 years
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _advanceToEpoch(uint256 targetEpoch) internal {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        if (targetEpoch <= currentEpoch) return;

        uint256 epochsToAdvance = targetEpoch - currentEpoch;
        uint256 timeToAdvance = epochsToAdvance * protocol.trustBonding.epochLength();
        vm.warp(block.timestamp + timeToAdvance);
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

        bytes32 slot = keccak256(abi.encode(epoch, uint256(32))); // MultiVault totalUtilization storage slot
        vm.store(address(protocol.multiVault), slot, bytes32(uint256(utilization)));
    }

    /// @dev Set user utilization for a specific epoch using vm.store
    function _setUserUtilizationForEpoch(address user, uint256 epoch, int256 utilization) internal {
        // The MultiVault contract stores personalUtilization in a nested mapping
        // mapping(address user => mapping(uint256 epoch => int256 utilization)) public personalUtilization;

        // Calculate the storage slot for the nested mapping
        bytes32 userSlot = keccak256(abi.encode(user, uint256(33))); // MultiVault personalUtilization storage slot
        bytes32 finalSlot = keccak256(abi.encode(epoch, userSlot));
        vm.store(address(protocol.multiVault), finalSlot, bytes32(uint256(utilization)));
    }

    /// @dev Set total claimed rewards for a specific epoch using vm.store
    function _setTotalClaimedRewardsForEpoch(uint256 epoch, uint256 claimedRewards) internal {
        // mapping(uint256 epoch => uint256 totalClaimedRewards) public totalClaimedRewardsForEpoch;
        // Assuming this is at storage slot 12 based on the TrustBonding contract
        bytes32 slot = keccak256(abi.encode(epoch, uint256(12)));
        vm.store(address(protocol.trustBonding), slot, bytes32(claimedRewards));
    }

    /// @dev Set user claimed rewards for a specific epoch using vm.store
    function _setUserClaimedRewardsForEpoch(address user, uint256 epoch, uint256 claimedRewards) internal {
        // mapping(address user => mapping(uint256 epoch => uint256 claimedRewards)) public userClaimedRewardsForEpoch;
        // Assuming this is at storage slot 13 based on the TrustBonding contract
        bytes32 userSlot = keccak256(abi.encode(user, uint256(13)));
        bytes32 finalSlot = keccak256(abi.encode(epoch, userSlot));
        vm.store(address(protocol.trustBonding), finalSlot, bytes32(claimedRewards));
    }

    function _createLock(address user, uint256 amount) internal {
        vm.startPrank(user);
        uint256 unlockTime = block.timestamp + lockDuration;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), amount);
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _calculateExpectedRewards(address user, uint256 epoch) internal view returns (uint256) {
        uint256 rawRewards = protocol.trustBonding.userEligibleRewardsForEpoch(user, epoch);
        uint256 utilizationRatio = protocol.trustBonding.getPersonalUtilizationRatio(user, epoch);
        return rawRewards * utilizationRatio / BASIS_POINTS_DIVISOR;
    }
}
