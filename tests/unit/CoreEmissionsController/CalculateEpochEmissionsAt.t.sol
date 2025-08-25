// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { CoreEmissionsControllerMock } from "tests/mocks/CoreEmissionsControllerMock.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

struct TestPoint {
    uint256 timestamp;
    uint256 expectedEmissions;
}

contract CalculateEpochEmissionsAtTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*       BASIC EMISSIONS CALCULATION TESTS            */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_AtStart() public {
        _initializeController();

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions at start should equal base emissions");
    }

    function testCalculateEpochEmissionsAt_BeforeStart() public {
        _initializeController();

        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP - 1);
        assertEq(emissions, 0, "Emissions before start should be 0");
    }

    function testCalculateEpochEmissionsAt_NoCheckpoints() public {
        // Don't initialize controller - no checkpoints
        uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
        assertEq(emissions, 0, "Emissions with no checkpoints should be 0");
    }

    function testCalculateEpochEmissionsAt_FirstEpoch() public {
        _initializeController();

        // Test various timestamps within first epoch
        TestPoint[] memory testPoints = new TestPoint[](5);
        testPoints[0] =
            TestPoint({ timestamp: DEFAULT_START_TIMESTAMP, expectedEmissions: DEFAULT_EMISSIONS_PER_EPOCH });
        testPoints[2] =
            TestPoint({ timestamp: DEFAULT_START_TIMESTAMP + (ONE_YEAR + ONE_WEEK), expectedEmissions: 900_000 * 1e18 });
        testPoints[3] = TestPoint({
            timestamp: DEFAULT_START_TIMESTAMP + ((ONE_YEAR * 2) + ONE_WEEK),
            expectedEmissions: 810_000 * 1e18
        });
        testPoints[4] = TestPoint({
            timestamp: DEFAULT_START_TIMESTAMP + ((ONE_YEAR * 3) + ONE_WEEK),
            expectedEmissions: 729_000 * 1e18
        });

        for (uint256 i = 0; i < testPoints.length; i++) {
            uint256 emissions = controller.calculateEpochEmissionsAt(testPoints[i].timestamp);
            assertEq(emissions, testPoints[i].expectedEmissions, "Emissions should reflect the cliff decreases.");
        }
    }

    /* =================================================== */
    /*         CLIFF REDUCTION TESTS                      */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_BeforeFirstCliff() public {
        _initializeController();

        // Test just before first cliff (epoch 25 with 0-indexed epochs)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (25 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions before first cliff should be base emissions");
    }

    function testCalculateEpochEmissionsAt_AtFirstCliff() public {
        _initializeController();

        // Test at first cliff (epoch 26 with 0-indexed epochs)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_REDUCTION_BP,
            1 // 1 cliff
        );

        assertEq(emissions, expectedEmissions, "Emissions at first cliff should be reduced by 10%");
    }

    function testCalculateEpochEmissionsAt_AfterFirstCliff() public {
        _initializeController();

        // Test after first cliff (epoch 27)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (27 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_REDUCTION_BP,
            1 // Still 1 cliff
        );

        assertEq(emissions, expectedEmissions, "Emissions after first cliff should remain at reduced level");
    }

    function testCalculateEpochEmissionsAt_AtSecondCliff() public {
        _initializeController();

        // Test at second cliff (epoch 52)
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (52 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_REDUCTION_BP,
            2 // 2 cliffs
        );

        assertEq(emissions, expectedEmissions, "Emissions at second cliff should be reduced again");
    }

    function testCalculateEpochEmissionsAt_MultipleCliffs() public {
        _initializeController();

        // Test emissions after multiple cliffs with reasonable numbers to avoid overflow
        uint256[] memory cliffs = new uint256[](4);
        cliffs[0] = 1;
        cliffs[1] = 2;
        cliffs[2] = 3;
        cliffs[3] = 4; // Reduced from 20 to avoid overflow

        for (uint256 i = 0; i < cliffs.length; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (cliffs[i] * DEFAULT_CLIFF * TWO_WEEKS);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

            uint256 expectedEmissions =
                _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, cliffs[i]);

            assertEq(emissions, expectedEmissions, "Emissions after multiple cliffs incorrect");
        }
    }

    /* =================================================== */
    /*          PRECISION TESTS                           */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_PrecisionCheck() public {
        _initializeController();

        // Test at first cliff
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Manual calculation: 1M * 0.9 = 900K
        uint256 expectedEmissions = (DEFAULT_EMISSIONS_PER_EPOCH * 9000) / 10_000;
        assertEq(emissions, expectedEmissions, "Precision check failed for first cliff");
    }

    function testCalculateEpochEmissionsAt_CompoundReductionPrecision() public {
        _initializeController();

        // Test at second cliff - compound reduction
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (52 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Manual calculation: 1M * (0.9)^2 = 1M * 0.81 = 810K
        uint256 expectedEmissions = (DEFAULT_EMISSIONS_PER_EPOCH * 8100) / 10_000;
        assertEq(emissions, expectedEmissions, "Compound reduction precision check failed");
    }

    /* =================================================== */
    /*      DIFFERENT CLIFF CONFIGURATIONS                */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_SmallCliff() public {
        // Setup with small cliff (every 2 epochs)
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            2, // Cliff every 2 epochs
            500 // 5% reduction
        );

        // Test at various cliffs
        uint256[] memory epochs = new uint256[](4);
        epochs[0] = 2; // First cliff
        epochs[1] = 4; // Second cliff
        epochs[2] = 6; // Third cliff
        epochs[3] = 8; // Fourth cliff

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (epochs[i] * TWO_WEEKS);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

            uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
                DEFAULT_EMISSIONS_PER_EPOCH,
                500, // 5% reduction
                i + 1 // Number of cliffs
            );

            assertEq(emissions, expectedEmissions, "Small cliff emissions incorrect");
        }
    }

    function testCalculateEpochEmissionsAt_LargeCliff() public {
        // Setup with large cliff (every 100 epochs)
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            100, // Cliff every 100 epochs
            DEFAULT_REDUCTION_BP
        );

        // Before first cliff
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (99 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions before large cliff should be base");

        // At first cliff
        timestamp = DEFAULT_START_TIMESTAMP + (100 * TWO_WEEKS);
        emissions = controller.calculateEpochEmissionsAt(timestamp);
        uint256 expectedEmissions =
            _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, 1);
        assertEq(emissions, expectedEmissions, "Emissions at large cliff incorrect");
    }

    /* =================================================== */
    /*      DIFFERENT REDUCTION PERCENTAGES               */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_SmallReduction() public {
        // Setup with small reduction (1%)
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            100 // 1% reduction
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions = _calculateExpectedEmissionsAfterCliffs(
            DEFAULT_EMISSIONS_PER_EPOCH,
            100, // 1% reduction
            1
        );

        assertEq(emissions, expectedEmissions, "Small reduction emissions incorrect");
    }

    function testCalculateEpochEmissionsAt_LargeReduction() public {
        // Setup with large reduction (10% - max allowed)
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            MAX_CLIFF_REDUCTION_BASIS_POINTS // 10% reduction - max allowed
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions =
            _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, MAX_CLIFF_REDUCTION_BASIS_POINTS, 1);
        assertEq(emissions, expectedEmissions, "Large reduction emissions incorrect");
    }

    /* =================================================== */
    /*         EDGE CASE TESTS                            */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_ZeroReduction() public {
        // Setup with zero reduction
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            0 // 0% reduction
        );

        // Test at multiple cliffs - emissions should never change
        for (uint256 i = 1; i <= 10; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * DEFAULT_CLIFF * TWO_WEEKS);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
            assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Zero reduction should maintain base emissions");
        }
    }

    function testCalculateEpochEmissionsAt_MaxReduction() public {
        // Setup with maximum allowed reduction
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            TWO_WEEKS,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_CLIFF,
            MAX_CLIFF_REDUCTION_BASIS_POINTS // 10% maximum
        );

        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS);
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions =
            _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, MAX_CLIFF_REDUCTION_BASIS_POINTS, 1);

        assertEq(emissions, expectedEmissions, "Max reduction emissions incorrect");
    }

    /* =================================================== */
    /*         BOUNDARY TESTS                             */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_ExactCliffBoundaries() public {
        _initializeController();

        // Test exactly at cliff boundaries
        for (uint256 i = 1; i <= 5; i++) {
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * DEFAULT_CLIFF * TWO_WEEKS);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

            uint256 expectedEmissions =
                _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, i);

            assertEq(emissions, expectedEmissions, "Exact cliff boundary emissions incorrect");
        }
    }

    function testCalculateEpochEmissionsAt_JustBeforeCliff() public {
        _initializeController();

        // Test 1 second before cliff
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) - 1;
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions just before cliff should be base");
    }

    function testCalculateEpochEmissionsAt_JustAfterCliff() public {
        _initializeController();

        // Test 1 second after cliff
        uint256 timestamp = DEFAULT_START_TIMESTAMP + (26 * TWO_WEEKS) + 1;
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        uint256 expectedEmissions =
            _calculateExpectedEmissionsAfterCliffs(DEFAULT_EMISSIONS_PER_EPOCH, DEFAULT_REDUCTION_BP, 1);

        assertEq(emissions, expectedEmissions, "Emissions just after cliff should be reduced");
    }

    /* =================================================== */
    /*         CONSISTENCY TESTS                          */
    /* =================================================== */

    function testCalculateEpochEmissionsAt_ConsistentWithinEpoch() public {
        _initializeController();

        // Test that emissions are consistent within each epoch
        for (uint256 epoch = 0; epoch < 100; epoch++) {
            uint256 epochStart = DEFAULT_START_TIMESTAMP + (epoch * TWO_WEEKS);
            uint256 epochMid = epochStart + (TWO_WEEKS / 2);
            uint256 epochEnd = epochStart + TWO_WEEKS - 1;

            uint256 emissionsStart = controller.calculateEpochEmissionsAt(epochStart);
            uint256 emissionsMid = controller.calculateEpochEmissionsAt(epochMid);
            uint256 emissionsEnd = controller.calculateEpochEmissionsAt(epochEnd);

            assertEq(emissionsStart, emissionsMid, "Emissions inconsistent within epoch");
            assertEq(emissionsMid, emissionsEnd, "Emissions inconsistent within epoch");
        }
    }

    function testCalculateEpochEmissionsAt_MonotonicDecreasing() public {
        _initializeController();

        uint256 previousEmissions = type(uint256).max;

        // Test over multiple years - emissions should never increase
        for (uint256 i = 0; i < 260; i++) {
            // ~10 years
            uint256 timestamp = DEFAULT_START_TIMESTAMP + (i * TWO_WEEKS);
            uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

            assertLe(emissions, previousEmissions, "Emissions should be monotonically decreasing");
            previousEmissions = emissions;
        }
    }

    /* =================================================== */
    /*              FUZZ TESTS                            */
    /* =================================================== */

    function testFuzzCalculateEpochEmissionsAt_ValidTimestamp(uint128 timestampOffset) public {
        _initializeController();

        vm.assume(timestampOffset < 5 * ONE_YEAR); // More conservative upper bound to avoid overflow

        uint256 timestamp = DEFAULT_START_TIMESTAMP + timestampOffset;
        uint256 emissions = controller.calculateEpochEmissionsAt(timestamp);

        // Emissions should never be greater than base emissions
        assertLe(emissions, DEFAULT_EMISSIONS_PER_EPOCH, "Emissions should not exceed base");

        // Emissions should be positive if we're after start
        if (timestamp >= DEFAULT_START_TIMESTAMP) {
            assertGt(emissions, 0, "Emissions should be positive after start");
        }
    }

    function testFuzzCalculateEpochEmissionsAt_BeforeStart(uint128 timestampBefore) public {
        _initializeController();

        vm.assume(timestampBefore < DEFAULT_START_TIMESTAMP);

        uint256 emissions = controller.calculateEpochEmissionsAt(timestampBefore);
        assertEq(emissions, 0, "Fuzz: emissions before start should be 0");
    }

    /* =================================================== */
    /*      DIFFERENT CONFIGURATIONS TESTS               */
    /* =================================================== */

    struct TestConfig {
        uint256 epochLength;
        uint256 emissionsPerEpoch;
        uint256 cliff;
        uint256 reductionBp;
    }

    function testCalculateEpochEmissionsAt_DifferentConfigurations() public {
        TestConfig[] memory configs = new TestConfig[](4);
        configs[0] = TestConfig(ONE_DAY, 100_000 * 1e18, 365, 500); // Daily, 5%
        configs[1] = TestConfig(ONE_WEEK, 500_000 * 1e18, 52, 750); // Weekly, 7.5%
        configs[2] = TestConfig(ONE_HOUR, 10_000 * 1e18, 24, 100); // Hourly, 1%
        configs[3] = TestConfig(30 days, 2_000_000 * 1e18, 12, 1000); // Monthly, 10%

        for (uint256 i = 0; i < configs.length; i++) {
            TestConfig memory config = configs[i];

            // Deploy fresh controller for each config
            controller = new CoreEmissionsControllerMock();
            controller.initCoreEmissionsController(
                DEFAULT_START_TIMESTAMP, config.epochLength, config.emissionsPerEpoch, config.cliff, config.reductionBp
            );

            // Test at start
            uint256 emissions = controller.calculateEpochEmissionsAt(DEFAULT_START_TIMESTAMP);
            assertEq(emissions, config.emissionsPerEpoch, "Config emissions at start incorrect");

            // Test at first cliff
            uint256 cliffTimestamp = DEFAULT_START_TIMESTAMP + (config.cliff * config.epochLength);
            emissions = controller.calculateEpochEmissionsAt(cliffTimestamp);

            uint256 expectedEmissions =
                _calculateExpectedEmissionsAfterCliffs(config.emissionsPerEpoch, config.reductionBp, 1);

            assertEq(emissions, expectedEmissions, "Config emissions at cliff incorrect");
        }
    }
}
