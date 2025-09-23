// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { TrustBondingMock } from "tests/mocks/TrustBondingMock.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// forge test --match-path 'tests/unit/TrustBonding/NormalizedUtilizationRatio.t.sol'
contract NormalizedUtilizationRatioTest is TrustBondingBase {
    TrustBondingMock public trustBondingMock;

    uint256 public constant MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND = 4000;
    uint256 public constant MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND = 2500;

    function setUp() public override {
        super.setUp();
        _deployTrustBondingMock();
    }

    function _deployTrustBondingMock() internal {
        TrustBondingMock trustBondingMockImpl = new TrustBondingMock();

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(trustBondingMockImpl), users.admin, "");

        trustBondingMock = TrustBondingMock(address(proxy));

        trustBondingMock.initialize(
            users.admin,
            address(protocol.wrappedTrust),
            TRUST_BONDING_EPOCH_LENGTH,
            address(protocol.multiVault),
            address(protocol.satelliteEmissionsController),
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND,
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND
        );
    }

    /* =================================================== */
    /*                   BASIC TESTS                       */
    /* =================================================== */

    function test_getNormalizedUtilizationRatio_withZeroUtilization() external view {
        uint256 delta = 0;
        uint256 target = 1000;
        uint256 lowerBound = 5000; // 50%

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // When delta is 0, result should equal lowerBound
        assertEq(result, lowerBound, "Zero utilization should return lowerBound");
    }

    function test_getNormalizedUtilizationRatio_with100PercentUtilization() external view {
        uint256 delta = 1000;
        uint256 target = 1000;
        uint256 lowerBound = 5000; // 50%

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // When delta equals target, result should be BASIS_POINTS_DIVISOR (100%)
        assertEq(result, BASIS_POINTS_DIVISOR, "100% utilization should return BASIS_POINTS_DIVISOR");
    }

    function test_getNormalizedUtilizationRatio_belowMinimumBound() external view {
        uint256 delta = 250;
        uint256 target = 1000;
        uint256 lowerBound = 5000; // 50%

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: lowerBound + (delta * (BASIS_POINTS_DIVISOR - lowerBound)) / target
        // Expected: 5000 + (250 * 5000) / 1000 = 5000 + 1250 = 6250
        uint256 expected = 6250;
        assertEq(result, expected, "Utilization below minimum bound should be calculated correctly");

        // Result should be greater than lowerBound but less than BASIS_POINTS_DIVISOR
        assertGt(result, lowerBound, "Result should be greater than lowerBound");
        assertLt(result, BASIS_POINTS_DIVISOR, "Result should be less than BASIS_POINTS_DIVISOR");
    }

    function test_getNormalizedUtilizationRatio_aboveMaximumBound() external view {
        uint256 delta = 2000; // Higher than target
        uint256 target = 1000;
        uint256 lowerBound = 5000; // 50%

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // When delta > target, the formula still applies but result will exceed 100%
        // Expected: 5000 + (2000 * 5000) / 1000 = 5000 + 10000 = 15000
        uint256 expected = 15_000;
        assertEq(result, expected, "Utilization above maximum bound should be calculated correctly");

        // Result should exceed BASIS_POINTS_DIVISOR when delta > target
        assertGt(result, BASIS_POINTS_DIVISOR, "Result should exceed BASIS_POINTS_DIVISOR when delta > target");
    }

    function test_getNormalizedUtilizationRatio_atPersonalUtilizationLowerBound() external view {
        uint256 delta = 250;
        uint256 target = 1000;
        uint256 lowerBound = MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND; // 2500 (25%)

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: 2500 + (250 * (10000 - 2500)) / 1000 = 2500 + (250 * 7500) / 1000 = 2500 + 1875 = 4375
        uint256 expected = 4375;
        assertEq(result, expected, "Utilization at personal utilization lower bound should be calculated correctly");
    }

    function test_getNormalizedUtilizationRatio_atSystemUtilizationLowerBound() external view {
        uint256 delta = 250;
        uint256 target = 1000;
        uint256 lowerBound = MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND; // 4000 (40%)

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: 4000 + (250 * (10000 - 4000)) / 1000 = 4000 + (250 * 6000) / 1000 = 4000 + 1500 = 5500
        uint256 expected = 5500;
        assertEq(result, expected, "Utilization at system utilization lower bound should be calculated correctly");
    }

    /* =================================================== */
    /*                  EDGE CASES                         */
    /* =================================================== */

    function test_getNormalizedUtilizationRatio_withMinimalValues() external view {
        uint256 delta = 1;
        uint256 target = 1;
        uint256 lowerBound = 1;

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: 1 + (1 * (10000 - 1)) / 1 = 1 + 9999 = 10000
        assertEq(result, BASIS_POINTS_DIVISOR, "Minimal values should result in maximum utilization");
    }

    function test_getNormalizedUtilizationRatio_withMaximalLowerBound() external view {
        uint256 delta = 500;
        uint256 target = 1000;
        uint256 lowerBound = BASIS_POINTS_DIVISOR - 5000; // 5000 (50%)

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: 5000 + (500 * (10000 - 5000)) / 1000 = 5000 + (500 * 5000) / 1000 = 5000 + 2500 = 7500
        uint256 expected = 7500;
        assertEq(result, expected, "Maximal lower bound should result in minimal increase");
    }

    function test_getNormalizedUtilizationRatio_withLargeNumbers() external view {
        uint256 delta = 1e18;
        uint256 target = 2e18;
        uint256 lowerBound = 5000; // 50%

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Expected: 5000 + (1e18 * 5000) / 2e18 = 5000 + 2500 = 7500
        uint256 expected = 7500;
        assertEq(result, expected, "Large numbers should be handled correctly");
    }

    /* =================================================== */
    /*                    FUZZ TESTS                       */
    /* =================================================== */

    function testFuzz_getNormalizedUtilizationRatio_validInputs(
        uint256 delta,
        uint256 target,
        uint256 lowerBound
    )
        external
        view
    {
        // Bound inputs to reasonable ranges
        target = bound(target, 1, type(uint128).max); // Prevent division by zero
        delta = bound(delta, 0, target); // Delta can never exceed target
        lowerBound = bound(lowerBound, 0, BASIS_POINTS_DIVISOR);

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Basic invariants
        if (delta == 0) {
            assertEq(result, lowerBound, "Zero delta should return lowerBound");
        } else if (delta == target) {
            assertEq(result, BASIS_POINTS_DIVISOR, "Delta equal to target should return 100%");
        } else {
            assertGe(result, lowerBound, "Result should be greater than lowerBound when delta > 0");
            assertLe(result, BASIS_POINTS_DIVISOR, "Result should be less than 100% when delta < target");
        }

        // Mathematical property: result should be monotonically increasing with delta
        if (delta > 0 && delta < target) {
            uint256 smallerResult =
                trustBondingMock.exposed_getNormalizedUtilizationRatio(delta - 1, target, lowerBound);
            assertGe(result, smallerResult, "Result should increase with delta");
        }
    }

    /* =================================================== */
    /*               MATHEMATICAL PROPERTIES               */
    /* =================================================== */

    function test_getNormalizedUtilizationRatio_mathematicalFormula() external view {
        uint256 delta = 300;
        uint256 target = 1000;
        uint256 lowerBound = 4000;

        uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

        // Manual calculation: lowerBound + (delta * (BASIS_POINTS_DIVISOR - lowerBound)) / target
        uint256 ratioRange = BASIS_POINTS_DIVISOR - lowerBound; // 10000 - 4000 = 6000
        uint256 expectedResult = lowerBound + (delta * ratioRange) / target;
        // 4000 + (300 * 6000) / 1000 = 4000 + 1800 = 5800

        assertEq(result, expectedResult, "Result should match manual calculation");
    }

    function test_getNormalizedUtilizationRatio_rangeValidation() external view {
        uint256 target = 1000;
        uint256 lowerBound = 3000; // 30%

        // Test multiple delta values within valid range
        for (uint256 i = 0; i <= 10; i++) {
            uint256 delta = (target * i) / 10; // 0%, 10%, 20%, ..., 100% of target
            uint256 result = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);

            if (delta == 0) {
                assertEq(result, lowerBound, "Zero delta should return lowerBound");
            } else if (delta == target) {
                assertEq(result, BASIS_POINTS_DIVISOR, "Full target delta should return BASIS_POINTS_DIVISOR");
            } else {
                assertGt(result, lowerBound, "Result should be greater than lowerBound");
                assertLt(result, BASIS_POINTS_DIVISOR, "Result should be less than 100% for delta < target");
            }
        }
    }

    function test_getNormalizedUtilizationRatio_monotonicity() external view {
        uint256 target = 1000;
        uint256 lowerBound = 5000;
        uint256 previousResult = lowerBound;

        // Test that function is monotonically increasing
        for (uint256 delta = 0; delta <= target; delta += 100) {
            uint256 currentResult = trustBondingMock.exposed_getNormalizedUtilizationRatio(delta, target, lowerBound);
            assertGe(currentResult, previousResult, "Function should be monotonically increasing");
            previousResult = currentResult;
        }
    }

    /* =================================================== */
    /*                INTEGRATION TESTS                    */
    /* =================================================== */

    function test_getNormalizedUtilizationRatio_withExposedSystemUtilizationRatio() external {
        // Skip to epoch 2 to test system utilization ratio
        vm.warp(block.timestamp + TRUST_BONDING_EPOCH_LENGTH * 2);

        // Set up some claimed rewards for testing
        trustBondingMock.setTotalClaimedRewardsForEpoch(1, 1000);

        // This test verifies that the exposed system utilization ratio function works
        // The actual system utilization ratio calculation involves complex MultiVault interactions
        uint256 systemRatio = trustBondingMock.exposed_getSystemUtilizationRatio(2);

        // System ratio should be within valid bounds
        assertGe(
            systemRatio, TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, "System ratio should be at least lower bound"
        );
        assertLe(systemRatio, BASIS_POINTS_DIVISOR, "System ratio should not exceed 100%");
    }
}
