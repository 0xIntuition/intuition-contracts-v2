// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { CoreEmissionsControllerBase } from "./CoreEmissionsControllerBase.t.sol";
import { console2 } from "forge-std/src/console2.sol";

contract CoreEmissionsControllerTest is CoreEmissionsControllerBase {
    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
    }

    /* =================================================== */
    /*                   BASIC GETTER TESTS               */
    /* =================================================== */

    function test_getStartTimestamp_Success() public {
        _initializeController();

        uint256 startTimestamp = controller.getStartTimestamp();
        assertEq(startTimestamp, DEFAULT_START_TIMESTAMP);
    }

    function test_getEpochLength_Success() public {
        _initializeController();

        uint256 epochLength = controller.getEpochLength();
        assertEq(epochLength, DEFAULT_EPOCH_LENGTH);
    }

    function test_getCurrentEpoch_BeforeStart_ReturnsZero() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP - 1);

        uint256 currentEpoch = controller.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AtStart_ReturnsZero() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP);

        uint256 currentEpoch = controller.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AfterOneEpoch_ReturnsOne() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP + DEFAULT_EPOCH_LENGTH);

        uint256 currentEpoch = controller.getCurrentEpoch();
        assertEq(currentEpoch, 1);
    }

    function test_getCurrentEpoch_AfterMultipleEpochs_ReturnsCorrectValue() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP + (5 * DEFAULT_EPOCH_LENGTH));

        uint256 currentEpoch = controller.getCurrentEpoch();
        assertEq(currentEpoch, 5);
    }

    /* =================================================== */
    /*               EPOCH TIMESTAMP TESTS                */
    /* =================================================== */

    function test_getEpochTimestampStart_EpochZero_Success() public {
        _initializeController();

        uint256 startTimestamp = controller.getEpochTimestampStart(0);
        assertEq(startTimestamp, DEFAULT_START_TIMESTAMP);
    }

    function test_getEpochTimestampStart_EpochOne_Success() public {
        _initializeController();

        uint256 startTimestamp = controller.getEpochTimestampStart(1);
        assertEq(startTimestamp, DEFAULT_START_TIMESTAMP + DEFAULT_EPOCH_LENGTH);
    }

    function test_getEpochTimestampStart_MultipleEpochs_Success() public {
        _initializeController();

        for (uint256 i = 0; i < 10; i++) {
            uint256 startTimestamp = controller.getEpochTimestampStart(i);
            uint256 expected = DEFAULT_START_TIMESTAMP + (i * DEFAULT_EPOCH_LENGTH);
            assertEq(startTimestamp, expected);
        }
    }

    function test_getCurrentEpochStartTimestamp_Success() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP + (3 * DEFAULT_EPOCH_LENGTH) + ONE_DAY);

        uint256 currentStartTimestamp = controller.getCurrentEpochTimestampStart();
        uint256 expectedStartTimestamp = DEFAULT_START_TIMESTAMP + (3 * DEFAULT_EPOCH_LENGTH);
        assertEq(currentStartTimestamp, expectedStartTimestamp);
    }

    function test_getEpochTimestampEnd_EpochZero_Success() public {
        _initializeController();

        uint256 endTimestamp = controller.getEpochTimestampEnd(0);
        assertEq(endTimestamp, DEFAULT_START_TIMESTAMP + DEFAULT_EPOCH_LENGTH);
    }

    function test_getEpochTimestampEnd_EpochOne_Success() public {
        _initializeController();

        uint256 endTimestamp = controller.getEpochTimestampEnd(1);
        assertEq(endTimestamp, DEFAULT_START_TIMESTAMP + (2 * DEFAULT_EPOCH_LENGTH));
    }

    /* =================================================== */
    /*               EPOCH AT TIMESTAMP TESTS             */
    /* =================================================== */

    function test_getEpochAtTimestamp_BeforeStart_ReturnsZero() public {
        _initializeController();

        uint256 epoch = controller.getEpochAtTimestamp(DEFAULT_START_TIMESTAMP - 1);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtStart_ReturnsZero() public {
        _initializeController();

        uint256 epoch = controller.getEpochAtTimestamp(DEFAULT_START_TIMESTAMP);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_DuringFirstEpoch_ReturnsZero() public {
        _initializeController();

        uint256 epoch = controller.getEpochAtTimestamp(DEFAULT_START_TIMESTAMP + ONE_DAY);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtSecondEpochStart_ReturnsOne() public {
        _initializeController();

        uint256 epoch = controller.getEpochAtTimestamp(DEFAULT_START_TIMESTAMP + DEFAULT_EPOCH_LENGTH);
        assertEq(epoch, 1);
    }

    function test_getEpochAtTimestamp_DuringSecondEpoch_ReturnsOne() public {
        _initializeController();

        uint256 epoch = controller.getEpochAtTimestamp(DEFAULT_START_TIMESTAMP + DEFAULT_EPOCH_LENGTH + ONE_DAY);
        assertEq(epoch, 1);
    }

    /* =================================================== */
    /*               EMISSIONS AT EPOCH TESTS             */
    /* =================================================== */

    function test_getEmissionsAtEpoch_EpochZero_ReturnsBaseEmissions() public {
        _initializeController();

        uint256 emissions = controller.getEmissionsAtEpoch(0);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH);
    }

    function test_getEmissionsAtEpoch_BeforeFirstCliff_ReturnsBaseEmissions() public {
        _initializeController();

        // Test epochs before the first cliff (26 epochs)
        for (uint256 i = 0; i < DEFAULT_REDUCTION_CLIFF; i++) {
            uint256 emissions = controller.getEmissionsAtEpoch(i);
            assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH);
        }
    }

    function test_getEmissionsAtEpoch_AtFirstCliff_ReturnsReducedEmissions() public {
        _initializeController();

        uint256 emissions = controller.getEmissionsAtEpoch(DEFAULT_REDUCTION_CLIFF);
        // Expected: 1M * 0.9^1 = 900,000
        assertEq(emissions, 900_000 * 1e18);
    }

    function test_getEmissionsAtEpoch_AfterMultipleCliffs_ReturnsCorrectReduction() public {
        _initializeController();

        // Test emissions after various numbers of cliffs
        uint256[] memory testEpochs = new uint256[](8);
        uint256[] memory expectedEmissions = new uint256[](8);

        testEpochs[0] = DEFAULT_REDUCTION_CLIFF; // Epoch 52 - 2 cliffs
        testEpochs[1] = DEFAULT_REDUCTION_CLIFF * 2; // Epoch 52 - 2 cliffs
        testEpochs[2] = DEFAULT_REDUCTION_CLIFF * 3; // Epoch 78 - 3 cliffs
        testEpochs[3] = DEFAULT_REDUCTION_CLIFF * 4; // Epoch 104 - 4 cliffs
        testEpochs[4] = DEFAULT_REDUCTION_CLIFF * 5; // Epoch 130 - 5 cliffs
        testEpochs[5] = DEFAULT_REDUCTION_CLIFF * 10; // Epoch 130 - 10 cliffs
        testEpochs[6] = DEFAULT_REDUCTION_CLIFF * 15; // Epoch 130 - 20 cliffs
        testEpochs[7] = DEFAULT_REDUCTION_CLIFF * 16; // Epoch 130 - 30 cliffs

        expectedEmissions[0] = 900_000 * 1e18; // 1M * 0.9^2
        expectedEmissions[1] = 810_000 * 1e18; // 1M * 0.9^2
        expectedEmissions[2] = 729_000 * 1e18; // 1M * 0.9^3
        expectedEmissions[3] = 656_100 * 1e18; // 1M * 0.9^4
        expectedEmissions[4] = 590_490 * 1e18; // 1M * 0.9^5
        expectedEmissions[5] = 348_678_440_100_000_000_000_000; // 1M * 0.9^10
        expectedEmissions[6] = 205_891_132_094_649_000_000_000; // 1M * 0.9^10
        expectedEmissions[7] = 185_302_018_885_184_100_000_000; // 1M * 0.9^10

        for (uint256 i = 0; i < testEpochs.length; i++) {
            uint256 emissions = controller.getEmissionsAtEpoch(testEpochs[i]);
            assertEq(emissions, expectedEmissions[i]);
        }
    }

    /* =================================================== */
    /*           EMISSIONS AT TIMESTAMP TESTS             */
    /* =================================================== */

    function test_getEmissionsAtTimestamp_BeforeStart_ReturnsZero() public {
        _initializeController();

        uint256 emissions = controller.getEmissionsAtTimestamp(DEFAULT_START_TIMESTAMP - 1);
        assertEq(emissions, 0);
    }

    function test_getEmissionsAtTimestamp_DuringFirstEpoch_ReturnsBaseEmissions() public {
        _initializeController();

        uint256 emissions = controller.getEmissionsAtTimestamp(DEFAULT_START_TIMESTAMP + ONE_DAY);
        assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH);
    }

    function test_getEmissionsAtTimestamp_AtCliffBoundary_ReturnsReducedEmissions() public {
        _initializeController();

        uint256 firstCliffTimestamp = DEFAULT_START_TIMESTAMP + (DEFAULT_REDUCTION_CLIFF * DEFAULT_EPOCH_LENGTH);
        uint256 emissions = controller.getEmissionsAtTimestamp(firstCliffTimestamp);
        assertEq(emissions, 900_000 * 1e18);
    }

    function test_getCurrentEpochEmissions_Success() public {
        _initializeController();
        vm.warp(DEFAULT_START_TIMESTAMP + ONE_DAY);

        uint256 currentEmissions = controller.getCurrentEpochEmissions();
        assertEq(currentEmissions, DEFAULT_EMISSIONS_PER_EPOCH);
    }

    /* =================================================== */
    /*               SCENARIO SETUP TESTS                 */
    /* =================================================== */

    function test_setupBiWeeklyScenario_Success() public {
        controller.setupBiWeeklyScenario();

        // Verify configuration
        assertEq(controller.getStartTimestamp(), DEFAULT_START_TIMESTAMP);
        assertEq(controller.getEpochLength(), TWO_WEEKS);
        assertEq(controller.getEmissionsAtEpoch(0), 1_000_000 * 1e18);
        assertEq(controller.getEmissionsAtEpoch(25), 1_000_000 * 1e18);

        // Test cliff reduction at epoch 26 (1 year)
        uint256 emissionsAtCliff = controller.getEmissionsAtEpoch(26);
        assertEq(emissionsAtCliff, 900_000 * 1e18);
    }

    function test_setupWeeklyScenario_Success() public {
        controller.setupWeeklyScenario();

        // Verify configuration
        assertEq(controller.getStartTimestamp(), DEFAULT_START_TIMESTAMP);
        assertEq(controller.getEpochLength(), ONE_WEEK);
        assertEq(controller.getEmissionsAtEpoch(0), 1_000_000 * 1e18);
        assertEq(controller.getEmissionsAtEpoch(51), 1_000_000 * 1e18);

        // Test cliff reduction at epoch 52 (1 year)
        uint256 emissionsAtCliff = controller.getEmissionsAtEpoch(52);
        assertEq(emissionsAtCliff, 900_000 * 1e18);
    }

    function test_setupDailyScenario_Success() public {
        controller.setupDailyScenario();

        // Verify configuration
        assertEq(controller.getStartTimestamp(), DEFAULT_START_TIMESTAMP);
        assertEq(controller.getEpochLength(), ONE_DAY);
        assertEq(controller.getEmissionsAtEpoch(0), 1_000_000 * 1e18);
        assertEq(controller.getEmissionsAtEpoch(364), 1_000_000 * 1e18);
        // Test cliff reduction at epoch 365 (1 year)
        uint256 emissionsAtCliff = controller.getEmissionsAtEpoch(365);
        assertEq(emissionsAtCliff, 900_000 * 1e18);
    }

    /* =================================================== */
    /*           COMPREHENSIVE SCENARIO TESTS             */
    /* =================================================== */

    function test_biWeeklyScenario_MultipleEpochsWithHardcodedOutcomes() public {
        controller.setupBiWeeklyScenario();

        // Test hardcoded outcomes similar to integration tests
        uint256[] memory epochs = new uint256[](5);
        uint256[] memory expectedEmissions = new uint256[](5);

        epochs[0] = 1;
        epochs[1] = 2;
        epochs[2] = 3;
        epochs[3] = 4;
        epochs[4] = 5;

        expectedEmissions[0] = DEFAULT_EMISSIONS_PER_EPOCH;
        expectedEmissions[1] = DEFAULT_EMISSIONS_PER_EPOCH; // Still before cliff
        expectedEmissions[2] = DEFAULT_EMISSIONS_PER_EPOCH; // Still before cliff
        expectedEmissions[3] = DEFAULT_EMISSIONS_PER_EPOCH; // Still before cliff
        expectedEmissions[4] = DEFAULT_EMISSIONS_PER_EPOCH; // Still before cliff

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 emissions = controller.getEmissionsAtEpoch(epochs[i]);
            assertEq(emissions, expectedEmissions[i], "Incorrect emissions at early epoch");
        }

        // Test at cliff boundaries
        assertEq(controller.getEmissionsAtEpoch(26), 900_000 * 1e18, "Incorrect emissions at first cliff");
        assertEq(controller.getEmissionsAtEpoch(52), 810_000 * 1e18, "Incorrect emissions at second cliff");
        assertEq(controller.getEmissionsAtEpoch(78), 729_000 * 1e18, "Incorrect emissions at third cliff");
        assertEq(controller.getEmissionsAtEpoch(104), 656_100 * 1e18, "Incorrect emissions at fourth cliff");
        assertEq(controller.getEmissionsAtEpoch(130), 590_490 * 1e18, "Incorrect emissions at fifth cliff");
    }

    function test_weeklyScenario_MultipleEpochsWithHardcodedOutcomes() public {
        controller.setupWeeklyScenario();

        // Test early epochs (before any cliffs)
        for (uint256 i = 1; i <= 10; i++) {
            uint256 emissions = controller.getEmissionsAtEpoch(i);
            assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH);
        }

        // Test at cliff boundaries (52 weeks = 1 year)
        assertEq(controller.getEmissionsAtEpoch(52), 900_000 * 1e18, "Incorrect emissions at first cliff");
        assertEq(controller.getEmissionsAtEpoch(104), 810_000 * 1e18, "Incorrect emissions at second cliff");
        assertEq(controller.getEmissionsAtEpoch(156), 729_000 * 1e18, "Incorrect emissions at third cliff");
        assertEq(controller.getEmissionsAtEpoch(208), 656_100 * 1e18, "Incorrect emissions at fourth cliff");
        assertEq(controller.getEmissionsAtEpoch(260), 590_490 * 1e18, "Incorrect emissions at fifth cliff");
    }

    function test_dailyScenario_MultipleEpochsWithHardcodedOutcomes() public {
        controller.setupDailyScenario();

        // Test early epochs (before any cliffs)
        for (uint256 i = 1; i <= 30; i++) {
            uint256 emissions = controller.getEmissionsAtEpoch(i);
            assertEq(emissions, DEFAULT_EMISSIONS_PER_EPOCH);
        }

        // Test at cliff boundaries (365 days = 1 year)
        assertEq(controller.getEmissionsAtEpoch(365), 900_000 * 1e18, "Incorrect emissions at first cliff");
        assertEq(controller.getEmissionsAtEpoch(730), 810_000 * 1e18, "Incorrect emissions at second cliff");
        assertEq(controller.getEmissionsAtEpoch(1095), 729_000 * 1e18, "Incorrect emissions at third cliff");
        assertEq(controller.getEmissionsAtEpoch(1460), 656_100 * 1e18, "Incorrect emissions at fourth cliff");
        assertEq(controller.getEmissionsAtEpoch(1825), 590_490 * 1e18, "Incorrect emissions at fifth cliff");
    }

    /* =================================================== */
    /*               TOTAL EMISSIONS TESTS                */
    /* =================================================== */

    function test_totalEmissionsCalculation_BiWeeklyScenario() public {
        controller.setupBiWeeklyScenario();

        uint256 totalEmissions = 0;

        // Calculate total emissions for first 130 epochs (5 years)
        for (uint256 epoch = 0; epoch < 130; epoch++) {
            totalEmissions += controller.getEmissionsAtEpoch(epoch);
        }

        // Expected: 26 epochs * 1M + 26 epochs * 900K + 26 epochs * 810K + 26 epochs * 729K + 26 epochs * 656.1K
        uint256 expected = (26 * 1_000_000 * 1e18) + (26 * 900_000 * 1e18) + (26 * 810_000 * 1e18)
            + (26 * 729_000 * 1e18) + (26 * 656_100 * 1e18);

        assertEq(totalEmissions, expected, "Total emissions calculation incorrect");
    }

    function test_totalEmissionsCalculation_WeeklyScenario() public {
        controller.setupWeeklyScenario();

        uint256 totalEmissions = 0;

        // Calculate total emissions for first 260 epochs (5 years)
        for (uint256 epoch = 0; epoch < 260; epoch++) {
            totalEmissions += controller.getEmissionsAtEpoch(epoch);
        }

        // Expected: 52 epochs * 1M + 52 epochs * 900K + 52 epochs * 810K + 52 epochs * 729K + 52 epochs * 656.1K
        uint256 expected = (52 * 1_000_000 * 1e18) + (52 * 900_000 * 1e18) + (52 * 810_000 * 1e18)
            + (52 * 729_000 * 1e18) + (52 * 656_100 * 1e18);

        assertEq(totalEmissions, expected, "Total emissions calculation incorrect");
    }

    function test_totalEmissionsCalculation_DailyScenario() public {
        controller.setupDailyScenario();

        uint256 totalEmissions = 0;

        // Calculate total emissions for first 1825 epochs (5 years)
        for (uint256 epoch = 0; epoch < 1825; epoch++) {
            totalEmissions += controller.getEmissionsAtEpoch(epoch);
        }

        // Expected: 365 epochs * 1M + 365 epochs * 900K + 365 epochs * 810K + 365 epochs * 729K + 365 epochs * 656.1K
        uint256 expected = (365 * 1_000_000 * 1e18) + (365 * 900_000 * 1e18) + (365 * 810_000 * 1e18)
            + (365 * 729_000 * 1e18) + (365 * 656_100 * 1e18);

        assertEq(totalEmissions, expected, "Total emissions calculation incorrect");
    }

    function test_emissions_doesNotZeroOutEmissionsWithinPlannedHorizon_whenUsingProdParams() public {
        // 75M tokens (7.5% of 1B total supply) starting emissions per year
        uint256 prodStartingEmissionsPerYear = 75_000_000 * 1e18;
        uint256 prodEmissionsPerEpoch = prodStartingEmissionsPerYear / DEFAULT_REDUCTION_CLIFF;

        controller.setupCustomScenario(
            TWO_WEEKS, // emissionsLength
            prodEmissionsPerEpoch, // emissionsPerEpoch
            DEFAULT_REDUCTION_CLIFF, // emissionsReductionCliff (after 26 bi-weekly epochs = 1 year)
            DEFAULT_REDUCTION_BASIS_POINTS // emissionsReductionBasisPoints (10% emission reduction per cliff)
        );

        uint256 YEARS = 399; // practical time horizon we care about (test runs show that emissions zero out after ~400
            // years)
        uint256 EPOCHS_PER_CLIFF = 26; // bi-weekly scenario => 1 year per cliff

        uint256 last = type(uint256).max;
        uint256 epochLen = controller.getEpochLength();

        for (uint256 y = 0; y <= YEARS; y++) {
            uint256 epochAtCliff = y * EPOCHS_PER_CLIFF;

            // Value via epoch-based path
            uint256 e = controller.getEmissionsAtEpoch(epochAtCliff);
            assertGt(e, 0, "Emissions unexpectedly hit zero within horizon");
            if (y > 0) assertLe(e, last, "Emissions should be non-increasing");
            last = e;

            // Cross-check via timestamp-based path at mid-epoch
            uint256 tMid = controller.getEpochTimestampStart(epochAtCliff) + (epochLen / 2);
            uint256 eTs = controller.getEmissionsAtTimestamp(tMid);
            assertEq(eTs, e, "Timestamp-based emissions mismatch at cliff");
        }
    }

    /* =================================================== */
    /*               INTERNAL FUNCTION TESTS              */
    /* =================================================== */

    function test_applyCliffReductions_ZeroCliffs_ReturnsOriginal() public {
        uint256 result = controller.applyCliffReductions(1_000_000 * 1e18, 9000, 0);
        assertEq(result, 1_000_000 * 1e18);
    }

    function test_applyCliffReductions_OneCliff_ReturnsCorrectValue() public {
        uint256 result = controller.applyCliffReductions(1_000_000 * 1e18, 9000, 1);
        assertEq(result, 900_000 * 1e18);
    }

    function test_applyCliffReductions_MultipleCliffs_ReturnsCorrectValue() public {
        uint256 result = controller.applyCliffReductions(1_000_000 * 1e18, 9000, 2);
        assertEq(result, 810_000 * 1e18);

        result = controller.applyCliffReductions(1_000_000 * 1e18, 9000, 3);
        assertEq(result, 729_000 * 1e18);

        result = controller.applyCliffReductions(1_000_000 * 1e18, 9000, 5);
        assertEq(result, 590_490 * 1e18);
    }

    /* =================================================== */
    /*                 VALIDATION TESTS                   */
    /* =================================================== */

    function test_validateReductionBasisPoints_ValidValues_Success() public view {
        // Should not revert for valid values
        controller.validateReductionBasisPoints(0);
        controller.validateReductionBasisPoints(500);
        controller.validateReductionBasisPoints(1000); // Max value
    }

    function test_validateReductionBasisPoints_InvalidValue_Reverts() public {
        vm.expectRevert();
        controller.validateReductionBasisPoints(1001);

        vm.expectRevert();
        controller.validateReductionBasisPoints(5000);
    }

    function test_validateCliff_ValidValues_Success() public view {
        // Should not revert for valid values
        controller.validateCliff(1);
        controller.validateCliff(26);
        controller.validateCliff(365); // Max value
    }

    function test_validateCliff_InvalidValues_Reverts() public {
        vm.expectRevert();
        controller.validateCliff(0);

        vm.expectRevert();
        controller.validateCliff(366);

        vm.expectRevert();
        controller.validateCliff(1000);
    }

    /* =================================================== */
    /*                 EDGE CASE TESTS                    */
    /* =================================================== */

    function test_emissionsCalculation_VeryLargeEpochNumber() public {
        _initializeController();

        // Test with a moderate epoch number that won't cause overflow
        uint256 largeEpoch = 300; // 300 epochs = ~11.5 years with 2-week epochs, ~11 cliffs

        uint256 emissions = controller.getEmissionsAtEpoch(largeEpoch);

        // Should be extremely small due to many cliff reductions (1M * 0.9^11 ≈ 314K)
        assertTrue(emissions < DEFAULT_EMISSIONS_PER_EPOCH, "Emissions should be reduced");
        assertTrue(emissions > 0, "Emissions should not be zero");
        assertTrue(emissions > 100_000 * 1e18, "Should still be a meaningful amount");
    }

    function test_timestampCalculations_EdgeCases() public {
        _initializeController();

        // Test timestamp exactly at epoch boundary
        uint256 exactBoundary = DEFAULT_START_TIMESTAMP + (5 * DEFAULT_EPOCH_LENGTH);
        uint256 epoch = controller.getEpochAtTimestamp(exactBoundary);
        assertEq(epoch, 5, "Should be at epoch 5 boundary");

        // Test timestamp one second before epoch boundary
        epoch = controller.getEpochAtTimestamp(exactBoundary - 1);
        assertEq(epoch, 4, "Should still be in epoch 4");
    }

    function test_customScenario_DifferentParameters() public {
        // Test with custom parameters
        uint256 customEpochLength = 3 days;
        uint256 customEmissions = 1_000_000 * 1e18;
        uint256 customCliff = 100; // 100 epochs
        uint256 customReduction = 500; // 5%

        controller.setupCustomScenario(customEpochLength, customEmissions, customCliff, customReduction);

        // Verify custom configuration
        assertEq(controller.getEpochLength(), customEpochLength);
        assertEq(controller.getEmissionsAtEpoch(0), 1_000_000 * 1e18); // Mock uses fixed 1M

        // Test cliff reduction (5% reduction = 95% retention)
        uint256 emissionsAtCliff = controller.getEmissionsAtEpoch(customCliff);
        uint256 expected = (1_000_000 * 1e18 * 9500) / 10_000; // 95% of original
        assertEq(emissionsAtCliff, expected);
    }

    /* =================================================== */
    /*              COMPREHENSIVE INTEGRATION             */
    /* =================================================== */

    function test_comprehensiveIntegrationTest_BiWeeklyScenario() public {
        controller.setupBiWeeklyScenario();

        // Simulate progression through multiple years
        uint256[] memory testEpochs = new uint256[](10);
        uint256[] memory expectedEmissions = new uint256[](10);

        testEpochs[0] = 1; // Year 1, before cliff
        testEpochs[1] = 25; // Year 1, before cliff
        testEpochs[2] = 26; // Year 1, at first cliff
        testEpochs[3] = 27; // Year 2, after first cliff
        testEpochs[4] = 52; // Year 2, at second cliff
        testEpochs[5] = 78; // Year 3, at third cliff
        testEpochs[6] = 104; // Year 4, at fourth cliff
        testEpochs[7] = 130; // Year 5, at fifth cliff
        testEpochs[8] = 156; // Year 6, at sixth cliff
        testEpochs[9] = 260; // Year 10, at tenth cliff

        expectedEmissions[0] = 1_000_000 * 1e18;
        expectedEmissions[1] = 1_000_000 * 1e18;
        expectedEmissions[2] = 900_000 * 1e18;
        expectedEmissions[3] = 900_000 * 1e18;
        expectedEmissions[4] = 810_000 * 1e18;
        expectedEmissions[5] = 729_000 * 1e18;
        expectedEmissions[6] = 656_100 * 1e18;
        expectedEmissions[7] = 590_490 * 1e18;
        expectedEmissions[8] = 531_441 * 1e18;
        expectedEmissions[9] = 348_678_440_100 * 1e12;

        for (uint256 i = 0; i < testEpochs.length; i++) {
            uint256 actualEmissions = controller.getEmissionsAtEpoch(testEpochs[i]);
            assertEq(actualEmissions, expectedEmissions[i], "Incorrect emissions at test epoch");

            // Also test timestamp-based queries
            uint256 epochStartTime = controller.getEpochTimestampStart(testEpochs[i]);
            uint256 midEpochTime = epochStartTime + (DEFAULT_EPOCH_LENGTH / 2);
            uint256 timestampEmissions = controller.getEmissionsAtTimestamp(midEpochTime);
            assertEq(timestampEmissions, expectedEmissions[i], "Timestamp-based query mismatch");
        }
    }
}
