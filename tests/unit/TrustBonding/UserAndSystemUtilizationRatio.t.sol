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

    function test_getUserUtilizationInEpoch_revertsOnFutureEpoch() external {
        uint256 futureEpoch = protocol.trustBonding.currentEpoch() + 1;
        vm.expectRevert(MultiVault.MultiVault_InvalidEpoch.selector);
        IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, futureEpoch);
    }

    function test_getUserUtilizationInEpoch__returnsPreviousActiveEpochsUtilization_priorToEpochBeingCalledWith()
        external
    {
        _advanceToEpoch(3);

        _setUserUtilizationForEpoch(users.alice, 1, 222);
        _setUserUtilizationForEpoch(users.alice, 2, 333);
        _setActiveEpoch(users.alice, 0, 2);
        _setActiveEpoch(users.alice, 1, 1);

        int256 atPrev =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 2);
        assertEq(
            atPrev,
            int256(333),
            "At prevEpoch should return the utilization from epoch prior to it in which user had activity"
        );
    }

    function test_getUserUtilizationInEpoch_lastBeforePrevEpoch_usesLastActive() external {
        _advanceToEpoch(5);
        _setUserUtilizationForEpoch(users.alice, 2, 111);
        _setActiveEpoch(users.alice, 0, 2); // last (2) < prevEpoch (4)

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 5);
        assertEq(checkpoint, int256(111), "Should use lastActiveEpoch when last < prevEpoch");
    }

    function test_getUserUtilizationInEpoch_lastEqualsPrevEpoch_usesPreviousActive() external {
        _advanceToEpoch(5);
        _setUserUtilizationForEpoch(users.alice, 3, 333);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setActiveEpoch(users.alice, 0, 4);
        _setActiveEpoch(users.alice, 1, 3);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 5);
        assertEq(checkpoint, int256(444), "When last == prevEpoch, must use previousActiveEpoch");
    }

    function test_getUserUtilizationInEpoch_sparseActivityFarBehind_usesThatSparseLast() external {
        _advanceToEpoch(8);
        _setUserUtilizationForEpoch(users.alice, 0, 555);
        _setUserUtilizationForEpoch(users.alice, 1, 777);
        _setActiveEpoch(users.alice, 0, 1);
        _setActiveEpoch(users.alice, 1, 0);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 8);
        assertEq(checkpoint, int256(777), "Should use sparse lastActiveEpoch when far behind");
    }

    function test_getUserUtilizationInEpoch_neverActive_returnsZero() external {
        _advanceToEpoch(3);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 3);
        assertEq(checkpoint, int256(0), "Never active -> before is 0");
    }

    function test_getUserUtilizationInEpoch_lastAfterTargetEpoch_usesPreviousActive() external {
        _advanceToEpoch(4);
        _setUserUtilizationForEpoch(users.alice, 2, 222);
        _setActiveEpoch(users.alice, 0, 2);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 4);
        assertEq(checkpoint, int256(222), "Future lastActiveEpoch -> use previousActiveEpoch");
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

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 2);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "No eligibility last epoch -> 100% personal utilization");
    }

    function test_personalUtilRatio_targetZero_hadEligibilityButDidNotClaim_returnsFloor() external {
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
        getUserUtilizationInEpoch() — explicit path coverage
    //////////////////////////////////////////////////////////////*/

    function test_getUserUtilizationInEpoch_caseA() external {
        _advanceToEpoch(7);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 5);
        _setActiveEpoch(users.alice, 2, 4);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 7);
        assertEq(checkpoint, int256(666), "Case A: lastActive < epoch, so use lastActive");
    }

    function test_getUserUtilizationInEpoch_caseB() external {
        _advanceToEpoch(7);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 5);
        _setActiveEpoch(users.alice, 2, 4);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 6);
        assertEq(checkpoint, int256(666), "Case B: previousActive < epoch, so use previousActive");
    }

    function test_getUserUtilizationInEpoch_caseC() external {
        _advanceToEpoch(7);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 5);
        _setActiveEpoch(users.alice, 2, 4);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 5);
        assertEq(checkpoint, int256(555), "Case C: use previousPreviousActiveEpoch's utilization");
    }
    
    function test_getUserUtilizationInEpoch_caseD() external {
        _advanceToEpoch(7);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 4);

        int256 checkpointA = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 5);
        int256 checkpointB = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 6);
        assertEq(checkpointA, int256(444), "Case D Checkpoint A: should get 444 utilization ");
        assertEq(checkpointB, int256(666), "Case D Checkpoint B: should get 666 utilization ");
    }

    function test_getUserUtilizationInEpoch_caseE() external {
        _advanceToEpoch(10);
        _setUserUtilizationForEpoch(users.alice, 4, 444);
        _setUserUtilizationForEpoch(users.alice, 5, 555);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);
        _setActiveEpoch(users.alice, 1, 5);
        _setActiveEpoch(users.alice, 2, 4);

        int256 checkpointA = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 8);
        int256 checkpointB = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 9);
        assertEq(checkpointA, int256(666), "Case E Checkpoint A: should get 666 utilization ");
        assertEq(checkpointB, int256(666), "Case E Checkpoint B: should get 666 utilization ");
    }
    
    function test_getUserUtilizationInEpoch_caseF() external {
        _advanceToEpoch(7);
        _setUserUtilizationForEpoch(users.alice, 6, 666);
        _setActiveEpoch(users.alice, 0, 6);

        int256 checkpointA = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 5);
        int256 checkpointB = IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 6);
        assertEq(checkpointA, int256(0), "Case F Checkpoint A: should get 0 utilization ");
        assertEq(checkpointB, int256(666), "Case F Checkpoint B: should get 666 utilization ");
    }

    // Final fallback: no tracked epoch strictly earlier than target -> return 0
    function test_getUserUtilizationInEpoch_fallbackNoneTrackedEarlier_returnsZero() external {
        _advanceToEpoch(100);
        _setUserUtilizationForEpoch(users.alice, 0, 999);
        _setUserUtilizationForEpoch(users.alice, 30, 999);
        _setUserUtilizationForEpoch(users.alice, 50, 999);
        _setUserUtilizationForEpoch(users.alice, 70, 999);
        _setActiveEpoch(users.alice, 0, 70);
        _setActiveEpoch(users.alice, 1, 50);
        _setActiveEpoch(users.alice, 2, 30);

        vm.expectRevert(MultiVault.MultiVault_EpochNotTracked.selector);
        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 20);
    }

    // Sanity: if lastActive == 0 (<epoch) and epoch 0 had activity, Case A returns util[0]
    function test_getUserUtilizationInEpoch_epoch0Activity_returnsEpoch0ViaCaseA() external {
        _advanceToEpoch(3);
        _setUserUtilizationForEpoch(users.alice, 0, 123);
        _setActiveEpoch(users.alice, 0, 0);

        int256 checkpoint =
            IMultiVault(address(protocol.multiVault)).getUserUtilizationInEpoch(users.alice, 3);
        assertEq(checkpoint, int256(123), "Case A should return util[0] when last == 0 < epoch");
    }
}