// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/// forge test --match-path 'tests/unit/TrustBonding/UserAndSystemUtilizationRatio.t.sol'
contract UserAndSystemUtilizationRatio is TrustBondingBase {
    uint256 public dealAmount = 100 * 1e18;

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, initialTokens * 10);
        vm.deal(users.bob, initialTokens * 10);
        _setupUserForTrustBonding(users.alice);
        _setupUserForTrustBonding(users.bob);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    SYSTEM UTILIZATION RATIO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getSystemUtilizationRatio_epoch0_shouldReturnMaxRatio() external view {
        uint256 epoch = 0;
        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Epoch 0 should return 100% utilization ratio");
    }

    function test_getSystemUtilizationRatio_epoch1_shouldReturnMaxRatio() external {
        _advanceToEpoch(1);
        uint256 epoch = 1;
        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Epoch 1 should return 100% utilization ratio");
    }

    function test_getSystemUtilizationRatio_futureEpoch_shouldReturnZero() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 2;
        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(futureEpoch);
        assertEq(ratio, 0, "Future epoch should return 0% utilization ratio");
    }

    function test_getSystemUtilizationRatio_negativeUtilizationDelta_shouldReturnLowerBound() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where utilization decreases (negative delta)
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 500e18 (decrease)
        _setTotalUtilizationForEpoch(2, 500e18);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, SYSTEM_UTILIZATION_LOWER_BOUND, "Negative utilization delta should return lower bound");
    }

    function test_getSystemUtilizationRatio_zeroUtilizationDelta_shouldReturnLowerBound() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where utilization stays the same (zero delta)
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 1000e18 (no change)
        _setTotalUtilizationForEpoch(2, 1000e18);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, SYSTEM_UTILIZATION_LOWER_BOUND, "Zero utilization delta should return lower bound");
    }

    function test_getSystemUtilizationRatio_noTargetUtilization_shouldReturnMaxRatio() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where there's no target utilization (no rewards claimed in previous epoch)
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 2000e18 (positive increase)
        _setTotalUtilizationForEpoch(2, 2000e18);
        // No claimed rewards for epoch 1 (target utilization = 0)

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "No target utilization should return max ratio");
    }

    function test_getSystemUtilizationRatio_utilizationDeltaGreaterThanTarget_shouldReturnMaxRatio() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where utilization delta > target
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 3000e18 (delta = 2000e18)
        _setTotalUtilizationForEpoch(2, 3000e18);
        // Set claimed rewards for epoch 1 to 1000e18 (target < delta)
        _setTotalClaimedRewardsForEpoch(1, 1000e18);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Utilization delta greater than target should return max ratio");
    }

    function test_getSystemUtilizationRatio_normalizedRatio_halfTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 1500e18 (delta = 500e18)
        _setTotalUtilizationForEpoch(2, 1500e18);
        // Set claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setTotalClaimedRewardsForEpoch(1, 1000e18);

        // Expected calculation:
        // delta = 500e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - SYSTEM_UTILIZATION_LOWER_BOUND = 10000 - 5000 = 5000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 5000 + (500 * 5000) / 1000 = 5000 + 2500 = 7500
        uint256 expectedRatio = 7500;

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, expectedRatio, "Half target delta should return normalized ratio");
    }

    function test_getSystemUtilizationRatio_normalizedRatio_quarterTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 1250e18 (delta = 250e18)
        _setTotalUtilizationForEpoch(2, 1250e18);
        // Set claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setTotalClaimedRewardsForEpoch(1, 1000e18);

        // Expected calculation:
        // delta = 250e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - SYSTEM_UTILIZATION_LOWER_BOUND = 10000 - 5000 = 5000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 5000 + (250 * 5000) / 1000 = 5000 + 1250 = 6250
        uint256 expectedRatio = 6250;

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, expectedRatio, "Quarter target delta should return normalized ratio");
    }

    function test_getSystemUtilizationRatio_normalizedRatio_threeQuarterTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set total utilization for epoch 1 to 1000e18
        _setTotalUtilizationForEpoch(1, 1000e18);
        // Set total utilization for epoch 2 to 1750e18 (delta = 750e18)
        _setTotalUtilizationForEpoch(2, 1750e18);
        // Set claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setTotalClaimedRewardsForEpoch(1, 1000e18);

        // Expected calculation:
        // delta = 750e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - SYSTEM_UTILIZATION_LOWER_BOUND = 10000 - 5000 = 5000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 5000 + (750 * 5000) / 1000 = 5000 + 3750 = 8750
        uint256 expectedRatio = 8750;

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(ratio, expectedRatio, "Three quarter target delta should return normalized ratio");
    }

    /*//////////////////////////////////////////////////////////////
                   PERSONAL UTILIZATION RATIO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPersonalUtilizationRatio_zeroAddress_shouldRevert() external {
        vm.expectRevert(ITrustBonding.TrustBonding_ZeroAddress.selector);
        protocol.trustBonding.getPersonalUtilizationRatio(address(0), 2);
    }

    function test_getPersonalUtilizationRatio_epoch0_shouldReturnMaxRatio() external view {
        uint256 epoch = 0;
        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Epoch 0 should return 100% utilization ratio");
    }

    function test_getPersonalUtilizationRatio_epoch1_shouldReturnMaxRatio() external {
        _advanceToEpoch(1);
        uint256 epoch = 1;
        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Epoch 1 should return 100% utilization ratio");
    }

    function test_getPersonalUtilizationRatio_futureEpoch_shouldReturnZero() external view {
        uint256 currentEpoch = protocol.trustBonding.currentEpoch();
        uint256 futureEpoch = currentEpoch + 2;
        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, futureEpoch);
        assertEq(ratio, 0, "Future epoch should return 0% utilization ratio");
    }

    function test_getPersonalUtilizationRatio_negativeUtilizationDelta_shouldReturnLowerBound() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where user utilization decreases (negative delta)
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 500e18 (decrease)
        _setUserUtilizationForEpoch(users.alice, 2, 500e18);
        // Ensure last active epoch is set to 2
        _setActiveEpoch(users.alice, 0, 2);
        // Ensure previous active epoch is set to 1
        _setActiveEpoch(users.alice, 1, 1);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, PERSONAL_UTILIZATION_LOWER_BOUND, "Negative utilization delta should return lower bound");
    }

    function test_getPersonalUtilizationRatio_zeroUtilizationDelta_shouldReturnLowerBound() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where user utilization stays the same (zero delta)
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 1000e18 (no change)
        _setUserUtilizationForEpoch(users.alice, 2, 1000e18);
        // Ensure last active epoch is set to 2
        _setActiveEpoch(users.alice, 0, 2);
        // Ensure previous active epoch is set to 1
        _setActiveEpoch(users.alice, 1, 1);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, PERSONAL_UTILIZATION_LOWER_BOUND, "Zero utilization delta should return lower bound");
    }

    function test_getPersonalUtilizationRatio_noTargetUtilization_shouldReturnMaxRatio() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where there's no target utilization (no rewards claimed in previous epoch)
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 2000e18 (positive increase)
        _setUserUtilizationForEpoch(users.alice, 2, 2000e18);
        // No claimed rewards for user in epoch 1 (target utilization = 0)
        _setActiveEpoch(users.alice, 0, 2);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "No target utilization should return max ratio");
    }

    function test_getPersonalUtilizationRatio_utilizationDeltaGreaterThanTarget_shouldReturnMaxRatio() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario where utilization delta > target
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 3000e18 (delta = 2000e18)
        _setUserUtilizationForEpoch(users.alice, 2, 3000e18);
        _setActiveEpoch(users.alice, 0, 2);
        // Set user claimed rewards for epoch 1 to 1000e18 (target < delta)
        _setUserClaimedRewardsForEpoch(users.alice, 1, 1000e18);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "Utilization delta greater than target should return max ratio");
    }

    function test_getPersonalUtilizationRatio_normalizedRatio_halfTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 1500e18 (delta = 500e18)
        _setUserUtilizationForEpoch(users.alice, 2, 1500e18);
        // Set user claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setUserClaimedRewardsForEpoch(users.alice, 1, 1000e18);
        // Ensure last active epoch is set to 2
        _setActiveEpoch(users.alice, 0, 2);
        // Ensure previous active epoch is set to 1
        _setActiveEpoch(users.alice, 1, 1);

        // Expected calculation:
        // delta = 500e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - PERSONAL_UTILIZATION_LOWER_BOUND = 10000 - 3000 = 7000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 3000 + (500 * 7000) / 1000 = 3000 + 3500 = 6500
        uint256 expectedRatio = 6500;

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, expectedRatio, "Half target delta should return normalized ratio");
    }

    function test_getPersonalUtilizationRatio_normalizedRatio_quarterTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 1250e18 (delta = 250e18)
        _setUserUtilizationForEpoch(users.alice, 2, 1250e18);
        // Set user claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setUserClaimedRewardsForEpoch(users.alice, 1, 1000e18);
        // Ensure last active epoch is set to 2
        _setActiveEpoch(users.alice, 0, 2);
        // Ensure previous active epoch is set to 1
        _setActiveEpoch(users.alice, 1, 1);

        // Expected calculation:
        // delta = 250e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - PERSONAL_UTILIZATION_LOWER_BOUND = 10000 - 3000 = 7000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 3000 + (250 * 7000) / 1000 = 3000 + 1750 = 4750
        uint256 expectedRatio = 4750;

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, expectedRatio, "Quarter target delta should return normalized ratio");
    }

    function test_getPersonalUtilizationRatio_normalizedRatio_threeQuarterTarget() external {
        // Advance to epoch 2 where utilization calculations begin
        _advanceToEpoch(2);

        // Set up scenario for normalized ratio calculation
        // Set user utilization for epoch 1 to 1000e18
        _setUserUtilizationForEpoch(users.alice, 1, 1000e18);
        // Set user utilization for epoch 2 to 1750e18 (delta = 750e18)
        _setUserUtilizationForEpoch(users.alice, 2, 1750e18);
        // Set user claimed rewards for epoch 1 to 1000e18 (target = 1000e18)
        _setUserClaimedRewardsForEpoch(users.alice, 1, 1000e18);
        // Ensure last active epoch is set to 2
        _setActiveEpoch(users.alice, 0, 2);
        // Ensure previous active epoch is set to 1
        _setActiveEpoch(users.alice, 1, 1);

        // Expected calculation:
        // delta = 750e18, target = 1000e18
        // ratioRange = BASIS_POINTS_DIVISOR - PERSONAL_UTILIZATION_LOWER_BOUND = 10000 - 3000 = 7000
        // utilizationRatio = lowerBound + (delta * ratioRange) / target
        // utilizationRatio = 3000 + (750 * 7000) / 1000 = 3000 + 5250 = 8250
        uint256 expectedRatio = 8250;

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, expectedRatio, "Three quarter target delta should return normalized ratio");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_systemAndPersonalUtilizationRatio_integration() external {
        _addToTrustBondingWhiteList(users.alice);
        // Bond some tokens to create eligible rewards
        _createLock(users.alice, initialTokens);

        // Advance to epoch 2 for utilization calculations
        _advanceToEpoch(2);

        // Set up system utilization scenario
        _setTotalUtilizationForEpoch(1, 1000e18);
        _setTotalUtilizationForEpoch(2, 1500e18); // delta = 500e18
        _setTotalClaimedRewardsForEpoch(1, 1000e18); // target = 1000e18

        // Set up personal utilization scenario for Alice
        _setUserUtilizationForEpoch(users.alice, 1, 500e18);
        _setUserUtilizationForEpoch(users.alice, 2, 750e18); // delta = 250e18
        _setUserClaimedRewardsForEpoch(users.alice, 1, 500e18); // target = 500e18
        _setActiveEpoch(users.alice, 0, 2);
        _setActiveEpoch(users.alice, 1, 1);

        // Expected system ratio: 5000 + (500 * 5000) / 1000 = 7500
        uint256 expectedSystemRatio = 7500;
        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(2);
        assertEq(systemRatio, expectedSystemRatio, "System utilization ratio mismatch");

        // Expected personal ratio: 3000 + (250 * 7000) / 500 = 6500
        uint256 expectedPersonalRatio = 6500;
        uint256 personalRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(personalRatio, expectedPersonalRatio, "Personal utilization ratio mismatch");

        // Verify that emissions are affected by system utilization ratio
        uint256 maxEpochEmissions = protocol.satelliteEmissionsController.getEmissionsAtEpoch(2);
        uint256 actualEmissions = protocol.trustBonding.emissionsForEpoch(2);
        uint256 expectedEmissions = maxEpochEmissions * systemRatio / BASIS_POINTS_DIVISOR;
        assertEq(actualEmissions, expectedEmissions, "Emissions calculation mismatch");
    }

    function test_utilizationRatio_boundaryValues_maxTarget() external {
        // Advance to epoch 2
        _advanceToEpoch(2);

        // Test with maximum possible target (high claimed rewards)
        uint256 maxTarget = type(uint256).max; // Avoid overflow

        // Set system utilization with max target
        _setTotalUtilizationForEpoch(1, 1000e18);
        _setTotalUtilizationForEpoch(2, 1001e18); // tiny delta
        _setTotalClaimedRewardsForEpoch(1, maxTarget);

        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(2);
        // Should equal the lower bound due to tiny delta vs huge target
        assertEq(systemRatio, SYSTEM_UTILIZATION_LOWER_BOUND, "Max target should result in lower bound");
    }

    function test_utilizationRatio_boundaryValues_minDelta() external {
        // Advance to epoch 2
        _advanceToEpoch(2);

        // Test with minimal positive delta
        _setTotalUtilizationForEpoch(1, 1000e18);
        _setTotalUtilizationForEpoch(2, 1000e18 + 1); // delta = 1
        _setTotalClaimedRewardsForEpoch(1, 1000e18); // target = 1000e18

        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(2);
        // Expected: 5000 + (1 * 5000) / 1000e18 ≈ 5000 (rounds down)
        assertEq(
            systemRatio, SYSTEM_UTILIZATION_LOWER_BOUND, "Minimal delta should result in lower bound due to rounding"
        );
    }

    /*//////////////////////////////////////////////////////////////
        PREVIOUS-ACTIVE-EPOCH RESOLUTION TESTS (DIRECT MV CHECKS)
    //////////////////////////////////////////////////////////////*/

    // Cases covered:
    // - last < prevEpoch (A)
    // - last == prevEpoch (B)
    // - last == target (B)
    // - sparse far-behind (A)
    // - never active (returns 0 via util[0]==0)
    // - last >> target (B)

    function test_getUserUtilization_revertsOnFutureEpoch() external {
        uint256 futureEpoch = protocol.trustBonding.currentEpoch() + 1;
        vm.expectRevert(MultiVault.MultiVault_InvalidEpoch.selector);
        IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, futureEpoch);
    }

    function test_getUserUtilization_returnsPreviousGlobalEpochUtilization_whenCalledWithPreviousGlobalEpoch()
        external
    {
        // target epoch = 3  -> prevEpoch = 2
        _advanceToEpoch(3);

        _setUserUtilizationForEpoch(users.alice, 1, 222);
        _setUserUtilizationForEpoch(users.alice, 2, 333);

        int256 atPrev = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 2);
        assertEq(atPrev, int256(333), "When called with prevEpoch, must return that epoch's utilization");
    }

    function test_getUserUtilization_lastBeforePrevEpoch_usesLastActive() external {
        // target epoch = 5  -> prevEpoch = 4
        _advanceToEpoch(5);

        _setUserUtilizationForEpoch(users.alice, 2, 111);
        _setActiveEpoch(users.alice, 0, 2); // last (2) < prevEpoch (4)
        _setActiveEpoch(users.alice, 1, 1);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 5);
        assertEq(before, int256(111), "Should use lastActiveEpoch when last < prevEpoch");
    }

    function test_getUserUtilization_lastEqualsPrevEpoch_usesPreviousActive() external {
        // target epoch = 5  -> prevEpoch = 4
        _advanceToEpoch(5);

        _setUserUtilizationForEpoch(users.alice, 3, 333);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setActiveEpoch(users.alice, 0, 4); // last == prevEpoch (4)
        _setActiveEpoch(users.alice, 1, 3);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 5);
        assertEq(before, int256(444), "When last == prevEpoch, must use previousActiveEpoch");
    }

    function test_getUserUtilization_lastEqualsTargetEpoch_usesPreviousActive() external {
        // target epoch = 5  -> prevEpoch = 4
        _advanceToEpoch(6);

        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setActiveEpoch(users.alice, 0, 5); // last == target epoch
        _setActiveEpoch(users.alice, 1, 4);

        int256 utilAfter = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 5);
        assertEq(
            utilAfter,
            int256(555),
            "When calling with the epoch that is immediately before current global one, must return utilization for previous global epoch"
        );
    }

    function test_getUserUtilization_sparseActivityFarBehind_usesThatSparseLast() external {
        // target epoch = 8  -> prevEpoch = 7
        _advanceToEpoch(8);

        _setUserUtilizationForEpoch(users.alice, 1, 777);
        _setActiveEpoch(users.alice, 0, 1); // last (1) < prevEpoch (7)
        _setActiveEpoch(users.alice, 1, 0);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 8);
        assertEq(before, int256(777), "Should use sparse lastActiveEpoch when far behind");
    }

    function test_getUserUtilization_neverActive_returnsZero() external {
        // target epoch = 3  -> prevEpoch = 2
        _advanceToEpoch(3);

        _setActiveEpoch(users.alice, 0, 0);
        _setActiveEpoch(users.alice, 1, 0);
        // personal[alice][0] defaults to 0

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 3);
        assertEq(before, int256(0), "Never active -> before is 0");
    }

    function test_getUserUtilization_lastAfterTargetEpoch_usesPreviousActive() external {
        // target epoch = 4  -> prevEpoch = 3
        _advanceToEpoch(4);

        _setUserUtilizationForEpoch(users.alice, 2, 222);
        _setActiveEpoch(users.alice, 0, 7); // last >> target
        _setActiveEpoch(users.alice, 1, 2);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 4);
        assertEq(before, int256(222), "Future lastActiveEpoch -> use previousActiveEpoch");
    }

    /*//////////////////////////////////////////////////////////////
       PERSONAL RATIO: TARGET==0 BRANCHES (INTEGRATED TB CHECKS)
    //////////////////////////////////////////////////////////////*/

    function test_personalUtilRatio_targetZero_noEligibility_prevEpoch_returnsMax() external {
        // Epoch 2 is the first epoch where utilization math is applied in TB
        _advanceToEpoch(2);

        // No locks -> no eligibility in epoch 1; set a positive delta so sign is > 0
        _setUserUtilizationForEpoch(users.alice, 2, 1000);
        _setActiveEpoch(users.alice, 0, 2);
        _setActiveEpoch(users.alice, 1, 0);

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "No eligibility last epoch -> 100% personal utilization");
    }

    function test_personalUtilRatio_targetZero_hadEligibilityButDidNotClaim_returnsFloor() external {
        _addToTrustBondingWhiteList(users.alice);
        _createLock(users.alice, initialTokens); // ensures eligibility exists for epoch 1
        _advanceToEpoch(2);

        // Positive delta between 1 and 2
        _setUserUtilizationForEpoch(users.alice, 1, 100);
        _setUserUtilizationForEpoch(users.alice, 2, 200);
        _setActiveEpoch(users.alice, 0, 2);
        _setActiveEpoch(users.alice, 1, 1);

        // userClaimedRewardsForEpoch[alice][1] is 0 by default -> target==0 AND had eligibility
        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, PERSONAL_UTILIZATION_LOWER_BOUND, "Had eligibility but didn't claim -> floor ratio");
    }

    /*//////////////////////////////////////////////////////////////
        getUserUtilizationForPreviousActiveEpoch() — explicit path coverage
    //////////////////////////////////////////////////////////////*/

    function test_getUserUtilization_epochZero_returnsZero() external {
        // Querying strictly before epoch 0 is nonsensical by definition
        vm.expectRevert(MultiVault.MultiVault_InvalidEpoch.selector);
        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 0);
    }

    // Case A: lastActive < epoch -> return personal[lastActive]
    function test_getUserUtilization_caseA_lastBeforeTarget() external {
        _advanceToEpoch(10);

        // last=4, prev=2, pprev=0; util[4] = 444
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setActiveEpoch(users.alice, 0, 4);
        _setActiveEpoch(users.alice, 1, 2);
        _setActiveEpoch(users.alice, 2, 0);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 7);
        assertEq(before, int256(444), "Case A should return utilization at lastActive (4)");
    }

    // Case B: lastActive >= epoch, previousActive < epoch -> return personal[previousActive]
    function test_getUserUtilization_caseB_previousBeforeTarget() external {
        _advanceToEpoch(12);

        // last=10, prev=6; util[6] = 606
        _setUserUtilizationForEpoch(users.alice, 6, 606);
        _setActiveEpoch(users.alice, 0, 10);
        _setActiveEpoch(users.alice, 1, 6);
        _setActiveEpoch(users.alice, 2, 3);

        int256 before1 = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 9);
        assertEq(before1, int256(606), "Case B: last(10)>=9, previous(6)<9 -> util[6]");

        // Also when previous == prevEpoch (epoch-1)
        int256 before2 = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 7);
        assertEq(before2, int256(606), "Case B still applies for epoch=7");
    }

    // Case C: lastActive >= epoch, previousActive == epoch (or ≥),
    //         previousPrevious < epoch -> return personal[previousPrevious]
    function test_getUserUtilization_caseC_prevEqualsTarget_usesPrevPrev() external {
        // target epoch = 5
        _advanceToEpoch(6);

        // last=10, previous=5 (== target), previousPrevious=3; util[3]=303
        _setUserUtilizationForEpoch(users.alice, 3, 303);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 5);
        _setActiveEpoch(users.alice, 2, 3);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 4);
        assertEq(before, int256(303), "Case C: previous == epoch, so use previousPrevious");
    }

    // Final fallback: no tracked epoch strictly earlier than target -> return 0
    function test_getUserUtilization_fallbackNoneTrackedEarlier_returnsZero() external {
        _advanceToEpoch(100);

        // Make all pointers >= query epoch
        // earliest tracked = 30, query epoch = 20 => none < 20
        _setActiveEpoch(users.alice, 0, 70);
        _setActiveEpoch(users.alice, 1, 50);
        _setActiveEpoch(users.alice, 2, 30);

        // even if epoch 0 had some value, we don't want to reuse it here
        _setUserUtilizationForEpoch(users.alice, 0, 999);

        vm.expectRevert(MultiVault.MultiVault_EpochNotTracked.selector);
        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 20);
    }

    // Sanity: if lastActive == 0 (<epoch) and epoch 0 had activity, Case A returns util[0]
    function test_getUserUtilization_epoch0Activity_returnsEpoch0ViaCaseA() external {
        _advanceToEpoch(3);

        // last=0 (<3), previous=0, pprev=0; util[0]=123
        _setUserUtilizationForEpoch(users.alice, 0, 123);
        _setActiveEpoch(users.alice, 0, 0);
        _setActiveEpoch(users.alice, 1, 0);
        _setActiveEpoch(users.alice, 2, 0);

        int256 before = IMultiVault(address(protocol.multiVault)).getUserUtilizationForPreviousActiveEpoch(users.alice, 3);
        assertEq(before, int256(123), "Case A should return util[0] when last == 0 < epoch");
    }
}
