// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

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
        _bondTokens(users.alice, initialTokens);

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
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupUserForTrustBonding(address user) internal {
        vm.startPrank(user);
        protocol.wrappedTrust.deposit{ value: initialTokens * 10 }();
        protocol.wrappedTrust.approve(address(protocol.trustBonding), type(uint256).max);
        vm.stopPrank();
    }
}
