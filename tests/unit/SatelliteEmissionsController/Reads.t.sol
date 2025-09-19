// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SatelliteEmissionsControllerGettersTest is BaseTest {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    SatelliteEmissionsController internal satelliteEmissionsController;

    // Test constants
    uint256 internal constant TEST_START_TIMESTAMP = 1_640_995_200; // Jan 1, 2022
    uint256 internal constant TEST_EPOCH_LENGTH = 14 days;
    uint256 internal constant TEST_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18;
    uint256 internal constant TEST_REDUCTION_CLIFF = 26;
    uint256 internal constant TEST_REDUCTION_BASIS_POINTS = 1000; // 10%
    uint32 internal constant TEST_RECIPIENT_DOMAIN = 1;
    uint256 internal constant TEST_GAS_LIMIT = 125_000;
    address internal constant TEST_HUB_ADDRESS = address(0x123);
    address internal constant TEST_BASE_EMISSIONS_CONTROLLER = address(0x456);

    // Role constants
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        _deploySatelliteEmissionsController();
    }

    function _deploySatelliteEmissionsController() internal {
        // Deploy SatelliteEmissionsController implementation
        SatelliteEmissionsController satelliteEmissionsControllerImpl = new SatelliteEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy satelliteEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(satelliteEmissionsControllerImpl), users.admin, "");

        satelliteEmissionsController = SatelliteEmissionsController(payable(satelliteEmissionsControllerProxy));

        // Initialize the contract
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: TEST_HUB_ADDRESS,
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

        satelliteEmissionsController.initialize(
            users.admin,
            address(protocol.trustBonding),
            TEST_BASE_EMISSIONS_CONTROLLER,
            metaERC20DispatchInit,
            coreEmissionsInit
        );

        vm.label(address(satelliteEmissionsController), "SatelliteEmissionsController");
    }

    /* =================================================== */
    /*           CORE EMISSIONS GETTERS TESTS             */
    /* =================================================== */

    function test_getTrustBonding_Success() public {
        address trustBonding = satelliteEmissionsController.getTrustBonding();
        assertEq(trustBonding, address(protocol.trustBonding));
    }

    function test_getBaseEmissionsController_Success() public {
        address baseEmissionsController = satelliteEmissionsController.getBaseEmissionsController();
        assertEq(baseEmissionsController, TEST_BASE_EMISSIONS_CONTROLLER);
    }

    function test_getBridgedEmissions_InitiallyReturnsZero() public {
        uint256 bridgedEmissions = satelliteEmissionsController.getBridgedEmissions(0);
        assertEq(bridgedEmissions, 0);
    }

    function test_getStartTimestamp_Success() public {
        uint256 startTimestamp = satelliteEmissionsController.getStartTimestamp();
        assertEq(startTimestamp, TEST_START_TIMESTAMP);
    }

    function test_getEpochLength_Success() public {
        uint256 epochLength = satelliteEmissionsController.getEpochLength();
        assertEq(epochLength, TEST_EPOCH_LENGTH);
    }

    function test_epochLength_Success() public {
        uint256 epochLength = satelliteEmissionsController.getEpochLength();
        assertEq(epochLength, TEST_EPOCH_LENGTH);
    }

    function test_getCurrentEpoch_BeforeStart_ReturnsZero() public {
        vm.warp(TEST_START_TIMESTAMP - 1);
        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AtStart_ReturnsZero() public {
        vm.warp(TEST_START_TIMESTAMP);
        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0);
    }

    function test_getCurrentEpoch_AfterOneEpoch_ReturnsOne() public {
        vm.warp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 1);
    }

    function test_getCurrentEpoch_MultipleEpochs_ReturnsCorrectValue() public {
        vm.warp(TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH));
        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 5);
    }

    function test_getEpochAtTimestamp_BeforeStart_ReturnsZero() public {
        uint256 epoch = satelliteEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP - 1);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtStart_ReturnsZero() public {
        uint256 epoch = satelliteEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_DuringFirstEpoch_ReturnsZero() public {
        uint256 epoch = satelliteEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP + 1 days);
        assertEq(epoch, 0);
    }

    function test_getEpochAtTimestamp_AtSecondEpochStart_ReturnsOne() public {
        uint256 epoch = satelliteEmissionsController.getEpochAtTimestamp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
        assertEq(epoch, 1);
    }

    function test_getEpochTimestampStart_EpochZero_Success() public {
        uint256 startTimestamp = satelliteEmissionsController.getEpochTimestampStart(0);
        assertEq(startTimestamp, TEST_START_TIMESTAMP);
    }

    function test_getEpochTimestampStart_EpochOne_Success() public {
        uint256 startTimestamp = satelliteEmissionsController.getEpochTimestampStart(1);
        assertEq(startTimestamp, TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
    }

    function test_getEpochTimestampEnd_EpochZero_Success() public {
        uint256 endTimestamp = satelliteEmissionsController.getEpochTimestampEnd(0);
        assertEq(endTimestamp, TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
    }

    function test_getCurrentEpochTimestampStart_Success() public {
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentStartTimestamp = satelliteEmissionsController.getCurrentEpochTimestampStart();
        uint256 expectedStartTimestamp = TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH);
        assertEq(currentStartTimestamp, expectedStartTimestamp);
    }

    function test_getEmissionsAtEpoch_EpochZero_ReturnsBaseEmissions() public {
        uint256 emissions = satelliteEmissionsController.getEmissionsAtEpoch(0);
        assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_getEmissionsAtEpoch_BeforeFirstCliff_ReturnsBaseEmissions() public {
        for (uint256 i = 0; i < TEST_REDUCTION_CLIFF; i++) {
            uint256 emissions = satelliteEmissionsController.getEmissionsAtEpoch(i);
            assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
        }
    }

    function test_getEmissionsAtEpoch_AtFirstCliff_ReturnsReducedEmissions() public {
        uint256 emissions = satelliteEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF);
        // Expected: 1M * 0.9 = 900,000
        assertEq(emissions, 900_000 * 1e18);
    }

    function test_getEmissionsAtTimestamp_BeforeStart_ReturnsZero() public {
        uint256 emissions = satelliteEmissionsController.getEmissionsAtTimestamp(TEST_START_TIMESTAMP - 1);
        assertEq(emissions, 0);
    }

    function test_getEmissionsAtTimestamp_DuringFirstEpoch_ReturnsBaseEmissions() public {
        uint256 emissions = satelliteEmissionsController.getEmissionsAtTimestamp(TEST_START_TIMESTAMP + 1 days);
        assertEq(emissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_getCurrentEpochEmissions_DuringFirstEpoch_ReturnsBaseEmissions() public {
        vm.warp(TEST_START_TIMESTAMP + 1 days);
        uint256 currentEmissions = satelliteEmissionsController.getCurrentEpochEmissions();
        assertEq(currentEmissions, TEST_EMISSIONS_PER_EPOCH);
    }

    /* =================================================== */
    /*           META ERC20 DISPATCHER GETTERS            */
    /* =================================================== */

    function test_getRecipientDomain_Success() public {
        uint32 recipientDomain = satelliteEmissionsController.getRecipientDomain();
        assertEq(recipientDomain, TEST_RECIPIENT_DOMAIN);
    }

    function test_getMetaERC20SpokeOrHub_Success() public {
        address hubOrSpoke = satelliteEmissionsController.getMetaERC20SpokeOrHub();
        assertEq(hubOrSpoke, TEST_HUB_ADDRESS);
    }

    function test_getFinalityState_Success() public {
        FinalityState finalityState = satelliteEmissionsController.getFinalityState();
        assertEq(uint8(finalityState), uint8(FinalityState.INSTANT));
    }

    function test_getMessageGasCost_Success() public {
        uint256 messageGasCost = satelliteEmissionsController.getMessageGasCost();
        assertEq(messageGasCost, TEST_GAS_LIMIT);
    }

    /* =================================================== */
    /*           ACCESS CONTROL GETTERS TESTS             */
    /* =================================================== */

    function test_hasRole_DefaultAdminRole_Success() public {
        bool hasRole = satelliteEmissionsController.hasRole(DEFAULT_ADMIN_ROLE, users.admin);
        assertTrue(hasRole);

        hasRole = satelliteEmissionsController.hasRole(DEFAULT_ADMIN_ROLE, users.alice);
        assertFalse(hasRole);
    }

    function test_hasRole_ControllerRole_Success() public {
        bool hasRole = satelliteEmissionsController.hasRole(CONTROLLER_ROLE, address(protocol.trustBonding));
        assertTrue(hasRole);

        hasRole = satelliteEmissionsController.hasRole(CONTROLLER_ROLE, users.alice);
        assertFalse(hasRole);
    }

    function test_getRoleAdmin_DefaultAdminRole_Success() public {
        bytes32 adminRole = satelliteEmissionsController.getRoleAdmin(DEFAULT_ADMIN_ROLE);
        assertEq(adminRole, DEFAULT_ADMIN_ROLE);
    }

    function test_getRoleAdmin_ControllerRole_Success() public {
        bytes32 adminRole = satelliteEmissionsController.getRoleAdmin(CONTROLLER_ROLE);
        assertEq(adminRole, DEFAULT_ADMIN_ROLE);
    }

    function test_supportsInterface_AccessControl_Success() public {
        // IAccessControl interface ID: 0x7965db0b
        bool supportsAccessControl = satelliteEmissionsController.supportsInterface(0x7965db0b);
        assertTrue(supportsAccessControl);

        // AccessControlEnumerable interface ID: 0x5a05180f
        bool supportsAccessControlEnumerable = satelliteEmissionsController.supportsInterface(0x5a05180f);
        assertFalse(supportsAccessControlEnumerable); // Not inherited

        // ERC165 interface ID: 0x01ffc9a7
        bool supportsERC165 = satelliteEmissionsController.supportsInterface(0x01ffc9a7);
        assertTrue(supportsERC165);
    }

    /* =================================================== */
    /*           EDGE CASES AND BOUNDARY TESTS            */
    /* =================================================== */

    function test_getters_AtEpochBoundaries() public {
        uint256 epochBoundary = TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH);
        vm.warp(epochBoundary);

        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 5);

        uint256 epochAtTimestamp = satelliteEmissionsController.getEpochAtTimestamp(epochBoundary);
        assertEq(epochAtTimestamp, 5);

        uint256 startTimestamp = satelliteEmissionsController.getCurrentEpochTimestampStart();
        assertEq(startTimestamp, epochBoundary);
    }

    function test_getEmissionsAtEpoch_MultipleCliffs_ReturnsCorrectReduction() public {
        // Test emissions after 2 cliffs
        uint256 emissions = satelliteEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF * 2);
        assertEq(emissions, 810_000 * 1e18); // 1M * 0.9^2

        // Test emissions after 3 cliffs
        emissions = satelliteEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF * 3);
        assertEq(emissions, 729_000 * 1e18); // 1M * 0.9^3
    }

    function test_hasRole_NonExistentRole_ReturnsFalse() public {
        bytes32 nonExistentRole = keccak256("NON_EXISTENT_ROLE");
        bool hasRole = satelliteEmissionsController.hasRole(nonExistentRole, users.admin);
        assertFalse(hasRole);
    }

    function test_consistency_EpochLengthGetters() public {
        uint256 epochLength1 = satelliteEmissionsController.getEpochLength();
        uint256 epochLength2 = satelliteEmissionsController.getEpochLength();

        assertEq(epochLength1, epochLength2);
        assertEq(epochLength1, TEST_EPOCH_LENGTH);
    }

    function test_consistency_EmissionsGetters() public {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 currentEmissions = satelliteEmissionsController.getCurrentEpochEmissions();
        uint256 epochZeroEmissions = satelliteEmissionsController.getEmissionsAtEpoch(0);
        uint256 timestampEmissions = satelliteEmissionsController.getEmissionsAtTimestamp(block.timestamp);

        assertEq(currentEmissions, epochZeroEmissions);
        assertEq(currentEmissions, timestampEmissions);
        assertEq(currentEmissions, TEST_EMISSIONS_PER_EPOCH);
    }

    function test_consistency_EpochGetters() public {
        uint256 testTimestamp = TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days;
        vm.warp(testTimestamp);

        uint256 currentEpoch = satelliteEmissionsController.getCurrentEpoch();
        uint256 epochAtTimestamp = satelliteEmissionsController.getEpochAtTimestamp(testTimestamp);

        assertEq(currentEpoch, epochAtTimestamp);
        assertEq(currentEpoch, 3);
    }

    /* =================================================== */
    /*              CONFIGURATION GETTERS                 */
    /* =================================================== */

    function test_configuration_AllGettersReturnCorrectValues() public {
        // Core emissions configuration
        assertEq(satelliteEmissionsController.getStartTimestamp(), TEST_START_TIMESTAMP);
        assertEq(satelliteEmissionsController.getEpochLength(), TEST_EPOCH_LENGTH);
        assertEq(satelliteEmissionsController.getEpochLength(), TEST_EPOCH_LENGTH);

        // MetaERC20Dispatcher configuration
        assertEq(satelliteEmissionsController.getRecipientDomain(), TEST_RECIPIENT_DOMAIN);
        assertEq(satelliteEmissionsController.getMetaERC20SpokeOrHub(), TEST_HUB_ADDRESS);
        assertEq(uint8(satelliteEmissionsController.getFinalityState()), uint8(FinalityState.INSTANT));
        assertEq(satelliteEmissionsController.getMessageGasCost(), TEST_GAS_LIMIT);

        // Access control configuration
        assertTrue(satelliteEmissionsController.hasRole(DEFAULT_ADMIN_ROLE, users.admin));
        assertTrue(satelliteEmissionsController.hasRole(CONTROLLER_ROLE, address(protocol.trustBonding)));
    }

    /* =================================================== */
    /*                CONSTANT GETTERS                    */
    /* =================================================== */

    function test_constantGetters_Success() public {
        // Test the public constant
        bytes32 controllerRole = satelliteEmissionsController.CONTROLLER_ROLE();
        assertEq(controllerRole, keccak256("CONTROLLER_ROLE"));

        // Test inherited constant from MetaERC20Dispatcher
        uint256 gasConstant = satelliteEmissionsController.GAS_CONSTANT();
        assertEq(gasConstant, 100_000);
    }

    /* =================================================== */
    /*              TIME-BASED GETTER TESTS               */
    /* =================================================== */

    function test_timeBasedGetters_ProgressionOverTime() public {
        // Test at start
        vm.warp(TEST_START_TIMESTAMP);
        assertEq(satelliteEmissionsController.getCurrentEpoch(), 0);
        assertEq(satelliteEmissionsController.getCurrentEpochEmissions(), TEST_EMISSIONS_PER_EPOCH);

        // Test after 1 week
        vm.warp(TEST_START_TIMESTAMP + 1 weeks);
        assertEq(satelliteEmissionsController.getCurrentEpoch(), 0);
        assertEq(satelliteEmissionsController.getCurrentEpochEmissions(), TEST_EMISSIONS_PER_EPOCH);

        // Test after 1 epoch (2 weeks)
        vm.warp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);
        assertEq(satelliteEmissionsController.getCurrentEpoch(), 1);
        assertEq(satelliteEmissionsController.getCurrentEpochEmissions(), TEST_EMISSIONS_PER_EPOCH);

        // Test after multiple epochs (1 year = 26 epochs)
        vm.warp(TEST_START_TIMESTAMP + (TEST_REDUCTION_CLIFF * TEST_EPOCH_LENGTH));
        assertEq(satelliteEmissionsController.getCurrentEpoch(), TEST_REDUCTION_CLIFF);
        assertEq(satelliteEmissionsController.getCurrentEpochEmissions(), 900_000 * 1e18);
    }
}
