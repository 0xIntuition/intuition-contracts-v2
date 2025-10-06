// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseEmissionsControllerGettersTest is BaseTest {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    BaseEmissionsController internal baseEmissionsController;

    // Test constants
    uint256 internal constant TEST_START_TIMESTAMP = 1_640_995_200; // Jan 1, 2022
    uint256 internal constant TEST_EPOCH_LENGTH = 14 days;
    uint256 internal constant TEST_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18;
    uint256 internal constant TEST_REDUCTION_CLIFF = 26;
    uint256 internal constant TEST_REDUCTION_BASIS_POINTS = 1000; // 10%
    uint32 internal constant TEST_RECIPIENT_DOMAIN = 1;
    uint256 internal constant TEST_GAS_LIMIT = 125_000;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        _deployBaseEmissionsController();
    }

    function _deployBaseEmissionsController() internal {
        // Deploy BaseEmissionsController implementation
        BaseEmissionsController baseEmissionsControllerImpl = new BaseEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy baseEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(baseEmissionsControllerImpl), users.admin, "");

        baseEmissionsController = BaseEmissionsController(payable(baseEmissionsControllerProxy));

        // Initialize the contract
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: address(1),
            recipientDomain: TEST_RECIPIENT_DOMAIN,
            gasLimit: TEST_GAS_LIMIT,
            finalityState: FinalityState.INSTANT
        });

        CoreEmissionsControllerInit memory coreEmissionsInit = CoreEmissionsControllerInit({
            startTimestamp: TEST_START_TIMESTAMP,
            emissionsLength: TEST_EPOCH_LENGTH,
            emissionsPerEpoch: TEST_EMISSIONS_PER_EPOCH,
            emissionsReductionCliff: TEST_REDUCTION_CLIFF,
            emissionsReductionBasisPoints: TEST_REDUCTION_BASIS_POINTS
        });

        baseEmissionsController.initialize(
            users.admin, users.controller, address(protocol.trust), metaERC20DispatchInit, coreEmissionsInit
        );

        vm.label(address(baseEmissionsController), "BaseEmissionsController");

        resetPrank(users.admin);

        // Set SatelliteEmissionsController contract address to address(1) for testing
        baseEmissionsController.setSatelliteEmissionsController(address(1));
    }

    /* =================================================== */
    /*               BASE GETTERS TESTS                    */
    /* =================================================== */

    function test_getTrustToken_Success() public {
        address trustToken = baseEmissionsController.getTrustToken();
        assertEq(trustToken, address(protocol.trust));
    }

    function test_getSatelliteEmissionsController_Success() public {
        address satellite = baseEmissionsController.getSatelliteEmissionsController();
        assertEq(satellite, address(1));
    }

    function test_getTotalMinted_InitiallyZero() public {
        uint256 totalMinted = baseEmissionsController.getTotalMinted();
        assertEq(totalMinted, 0);
    }

    function test_getEpochMintedAmount_InitiallyZero() public {
        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertEq(epochMinted, 0);

        epochMinted = baseEmissionsController.getEpochMintedAmount(1);
        assertEq(epochMinted, 0);

        epochMinted = baseEmissionsController.getEpochMintedAmount(100);
        assertEq(epochMinted, 0);
    }

    /* =================================================== */
    /*           CORE EMISSIONS GETTERS TESTS             */
    /* =================================================== */

    function test_getStartTimestamp_Success() public {
        uint256 startTimestamp = baseEmissionsController.getStartTimestamp();
        assertEq(startTimestamp, TEST_START_TIMESTAMP);
    }

    function test_getEpochLength_Success() public {
        uint256 epochLength = baseEmissionsController.getEpochLength();
        assertEq(epochLength, TEST_EPOCH_LENGTH);
    }

    function test_epochLength_Success() public {
        uint256 epochLength = baseEmissionsController.getEpochLength();
        assertEq(epochLength, TEST_EPOCH_LENGTH);
    }

    function test_getCurrentEpoch_BeforeStart_ReturnsZero() public {
        vm.warp(TEST_START_TIMESTAMP - 1);
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AtStart_ReturnsZero() public {
        vm.warp(TEST_START_TIMESTAMP);
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AfterOneEpoch_ReturnsOne() public {
        vm.warp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 1);
    }

    function test_getCurrentEpoch_MultipleEpochs_ReturnsCorrectValue() public {
        vm.warp(TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH));
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 5);
    }

    function test_getEpochAtTimestamp_BeforeStart_ReturnsZero() public {
        uint256 epoch = baseEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP - 1);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtStart_ReturnsZero() public {
        uint256 epoch = baseEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_DuringFirstEpoch_ReturnsZero() public {
        uint256 epoch = baseEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP + 1 days);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtSecondEpochStart_ReturnsOne() public {
        uint256 epoch = baseEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
        assertEq(epoch, 1);
    }

    function test_getEpochAtTimestamp_DuringSecondEpoch_ReturnsOne() public {
        uint256 epoch = baseEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH + 1 days);
        assertEq(epoch, 1);
    }

    function test_getEpochTimestampStart_EpochZero_Success() public {
        uint256 startTimestamp = baseEmissionsController.getEpochTimestampStart(0);
        assertEq(startTimestamp, TEST_START_TIMESTAMP);
    }

    function test_getEpochTimestampStart_EpochOne_Success() public {
        uint256 startTimestamp = baseEmissionsController.getEpochTimestampStart(1);
        assertEq(startTimestamp, TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
    }

    function test_getEpochTimestampStart_MultipleEpochs_Success() public {
        for (uint256 i = 0; i < 10; i++) {
            uint256 startTimestamp = baseEmissionsController.getEpochTimestampStart(i);
            uint256 expected = TEST_START_TIMESTAMP + (i * TEST_EPOCH_LENGTH);
            assertEq(startTimestamp, expected);
        }
    }

    function test_getEpochTimestampEnd_EpochZero_Success() public {
        uint256 endTimestamp = baseEmissionsController.getEpochTimestampEnd(0);
        assertEq(endTimestamp, TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
    }

    function test_getEpochTimestampEnd_EpochOne_Success() public {
        uint256 endTimestamp = baseEmissionsController.getEpochTimestampEnd(1);
        assertEq(endTimestamp, TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH));
    }

    function test_getCurrentEpochTimestampStart_Success() public {
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentStartTimestamp = baseEmissionsController.getCurrentEpochTimestampStart();
        uint256 expectedStartTimestamp = TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH);
        assertEq(currentStartTimestamp, expectedStartTimestamp);
    }

    function test_getEmissionsAtEpoch_EpochZero_ReturnsBaseEmissions() public {
        uint256 emissions = baseEmissionsController.getEmissionsAtEpoch(0);
        assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_getEmissionsAtEpoch_BeforeFirstCliff_ReturnsBaseEmissions() public {
        for (uint256 i = 0; i < TEST_REDUCTION_CLIFF; i++) {
            uint256 emissions = baseEmissionsController.getEmissionsAtEpoch(i);
            assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
        }
    }

    function test_getEmissionsAtEpoch_AtFirstCliff_ReturnsReducedEmissions() public {
        uint256 emissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF);
        // Expected: 1M * 0.9 = 900,000
        assertEq(emissions, 900_000 * 1e18);
    }

    function test_getEmissionsAtEpoch_AfterMultipleCliffs_ReturnsCorrectReduction() public {
        // Test emissions after 2 cliffs
        uint256 emissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF * 2);
        assertEq(emissions, 810_000 * 1e18); // 1M * 0.9^2

        // Test emissions after 3 cliffs
        emissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF * 3);
        assertEq(emissions, 729_000 * 1e18); // 1M * 0.9^3

        // Test emissions after 5 cliffs
        emissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF * 5);
        assertEq(emissions, 590_490 * 1e18); // 1M * 0.9^5
    }

    function test_getEmissionsAtTimestamp_BeforeStart_ReturnsZero() public {
        uint256 emissions = baseEmissionsController.getEmissionsAtTimestamp(TEST_START_TIMESTAMP - 1);
        assertEq(emissions, 0);
    }

    function test_getEmissionsAtTimestamp_DuringFirstEpoch_ReturnsBaseEmissions() public {
        uint256 emissions = baseEmissionsController.getEmissionsAtTimestamp(TEST_START_TIMESTAMP + 1 days);
        assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_getEmissionsAtTimestamp_AtCliffBoundary_ReturnsReducedEmissions() public {
        uint256 firstCliffTimestamp = TEST_START_TIMESTAMP + (TEST_REDUCTION_CLIFF * TEST_EPOCH_LENGTH);
        uint256 emissions = baseEmissionsController.getEmissionsAtTimestamp(firstCliffTimestamp);
        assertEq(emissions, 900_000 * 1e18);
    }

    function test_getCurrentEpochEmissions_BeforeStart_ReturnsZero() public {
        vm.warp(TEST_START_TIMESTAMP - 1);
        uint256 currentEmissions = baseEmissionsController.getCurrentEpochEmissions();
        assertEq(currentEmissions, 0);
    }

    function test_getCurrentEpochEmissions_DuringFirstEpoch_ReturnsBaseEmissions() public {
        vm.warp(TEST_START_TIMESTAMP + 1 days);
        uint256 currentEmissions = baseEmissionsController.getCurrentEpochEmissions();
        assertEq(currentEmissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_getCurrentEpochEmissions_AfterCliff_ReturnsReducedEmissions() public {
        vm.warp(TEST_START_TIMESTAMP + (TEST_REDUCTION_CLIFF * TEST_EPOCH_LENGTH) + 1 days);
        uint256 currentEmissions = baseEmissionsController.getCurrentEpochEmissions();
        assertEq(currentEmissions, 900_000 * 1e18);
    }

    /* =================================================== */
    /*           EDGE CASES AND BOUNDARY TESTS            */
    /* =================================================== */

    function test_getters_AtEpochBoundaries() public {
        uint256 epochBoundary = TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH);
        vm.warp(epochBoundary);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 5);

        uint256 epochAtTimestamp = baseEmissionsController.getEpochAtTimestamp(epochBoundary);
        assertEq(epochAtTimestamp, 5);

        uint256 startTimestamp = baseEmissionsController.getCurrentEpochTimestampStart();
        assertEq(startTimestamp, epochBoundary);
    }

    function test_getters_OneSecondBeforeEpochBoundary() public {
        uint256 beforeBoundary = TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH) - 1;
        vm.warp(beforeBoundary);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 4);

        uint256 epochAtTimestamp = baseEmissionsController.getEpochAtTimestamp(beforeBoundary);
        assertEq(epochAtTimestamp, 4);
    }

    function test_getEmissionsAtEpoch_LargeEpochNumbers() public {
        // Test with large epoch number that would have many cliff reductions
        uint256 largeEpoch = 260; // 10 years worth with 2-week epochs
        uint256 emissions = baseEmissionsController.getEmissionsAtEpoch(largeEpoch);

        // Should be significantly reduced but still positive
        assertTrue(emissions < TEST_EMISSIONS_PER_EPOCH);
        assertTrue(emissions > 0);
    }

    function test_getEpochMintedAmount_MultipleEpochs() public {
        // Test multiple epochs return 0 initially
        uint256[] memory epochs = new uint256[](5);
        epochs[0] = 0;
        epochs[1] = 1;
        epochs[2] = 10;
        epochs[3] = 100;
        epochs[4] = 1000;

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 mintedAmount = baseEmissionsController.getEpochMintedAmount(epochs[i]);
            assertEq(mintedAmount, 0);
        }
    }

    function test_consistency_EpochLengthGetters() public {
        uint256 epochLength1 = baseEmissionsController.getEpochLength();
        uint256 epochLength2 = baseEmissionsController.getEpochLength();

        assertEq(epochLength1, epochLength2);
        assertEq(epochLength1, TEST_EPOCH_LENGTH);
    }

    function test_consistency_EmissionsGetters() public {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 currentEmissions = baseEmissionsController.getCurrentEpochEmissions();
        uint256 epochZeroEmissions = baseEmissionsController.getEmissionsAtEpoch(0);
        uint256 timestampEmissions = baseEmissionsController.getEmissionsAtTimestamp(block.timestamp);

        assertEq(currentEmissions, epochZeroEmissions);
        assertEq(currentEmissions, timestampEmissions);
        assertEq(currentEmissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_consistency_EpochGetters() public {
        uint256 testTimestamp = TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days;
        vm.warp(testTimestamp);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        uint256 epochAtTimestamp = baseEmissionsController.getEpochAtTimestamp(testTimestamp);

        assertEq(currentEpoch, epochAtTimestamp);
        assertEq(currentEpoch, 3);
    }
}
