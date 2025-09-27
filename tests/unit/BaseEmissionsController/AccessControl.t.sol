// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev forge test --match-path 'tests/unit/BaseEmissionsController/AccessControl.t.sol'
contract AccessControlTest is BaseTest {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    BaseEmissionsController internal baseEmissionsController;

    // Initializer structs
    MetaERC20DispatchInit public metaERC20DispatchInit;
    CoreEmissionsControllerInit public coreEmissionsInit;

    // Test constants
    uint256 internal constant TEST_START_TIMESTAMP = 1_640_995_200; // Jan 1, 2022
    uint256 internal constant TEST_EPOCH_LENGTH = 14 days;
    uint256 internal constant TEST_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18;
    uint256 internal constant TEST_REDUCTION_CLIFF = 26;
    uint256 internal constant TEST_REDUCTION_BASIS_POINTS = 1000; // 10%
    uint32 internal constant TEST_RECIPIENT_DOMAIN = 1;
    uint256 internal constant TEST_GAS_LIMIT = 125_000;

    /// @notice Test addresses
    address public unauthorizedUser = address(0x999);
    address public satelliteController = address(0x888);

    /// @notice Role constants for testing
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Events to test
    event TrustTokenUpdated(address indexed newTrustToken);
    event SatelliteEmissionsControllerUpdated(address indexed newSatelliteEmissionsController);
    event MessageGasCostUpdated(uint256 newMessageGasCost);
    event FinalityStateUpdated(FinalityState newFinalityState);
    event RecipientDomainUpdated(uint32 newRecipientDomain);
    event MetaERC20SpokeOrHubUpdated(address newMetaERC20SpokeOrHub);

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        vm.deal(unauthorizedUser, 1 ether);

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

        // Deploy and initialize BaseEmissionsController
        BaseEmissionsController baseEmissionsControllerInstance = _deployBaseEmissionsController();

        baseEmissionsControllerInstance.initialize(
            users.admin, users.controller, address(protocol.trust), metaERC20DispatchInit, coreEmissionsInit
        );

        baseEmissionsController = baseEmissionsControllerInstance;
    }

    function _deployBaseEmissionsController() internal returns (BaseEmissionsController) {
        // Deploy BaseEmissionsController implementation
        BaseEmissionsController baseEmissionsControllerImpl = new BaseEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy baseEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(baseEmissionsControllerImpl), users.admin, "");

        baseEmissionsController = BaseEmissionsController(address(baseEmissionsControllerProxy));

        vm.label(address(baseEmissionsController), "BaseEmissionsController");

        return baseEmissionsController;
    }

    /*//////////////////////////////////////////////////////////////
                    INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_shouldRevertIfAdminIsZero() external {
        BaseEmissionsController baseEmissionsControllerInstance = _deployBaseEmissionsController();

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidAddress.selector)
        );

        baseEmissionsControllerInstance.initialize(
            address(0), users.controller, address(protocol.trust), metaERC20DispatchInit, coreEmissionsInit
        );
    }

    function test_initialize_shouldRevertIfControllerIsZero() external {
        BaseEmissionsController baseEmissionsControllerInstance = _deployBaseEmissionsController();

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidAddress.selector)
        );

        baseEmissionsControllerInstance.initialize(
            users.admin, address(0), address(protocol.trust), metaERC20DispatchInit, coreEmissionsInit
        );
    }

    function test_initialize_shouldRevertIfTokenIsZero() external {
        BaseEmissionsController baseEmissionsControllerInstance = _deployBaseEmissionsController();

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidAddress.selector)
        );

        baseEmissionsControllerInstance.initialize(
            users.admin, users.controller, address(0), metaERC20DispatchInit, coreEmissionsInit
        );
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setTrustToken)
    //////////////////////////////////////////////////////////////*/

    function test_setTrustToken_shouldSucceedWithAdminRole() external {
        address newTrustToken = address(0x456);
        address originalTrustToken = baseEmissionsController.getTrustToken();

        vm.expectEmit(true, false, false, true);
        emit TrustTokenUpdated(newTrustToken);

        resetPrank(users.admin);
        baseEmissionsController.setTrustToken(newTrustToken);

        assertEq(baseEmissionsController.getTrustToken(), newTrustToken, "Trust token should be updated");
        assertNotEq(originalTrustToken, newTrustToken, "Should be different from original");
    }

    function test_setTrustToken_shouldRevertWithUnauthorizedUser() external {
        address newTrustToken = address(0x456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setTrustToken(newTrustToken);
    }

    function test_setTrustToken_shouldRevertWithControllerRole() external {
        address newTrustToken = address(0x456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setTrustToken(newTrustToken);
    }

    function test_setTrustToken_shouldRevertWithZeroAddress() external {
        address zeroAddress = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidAddress.selector)
        );

        resetPrank(users.admin);
        baseEmissionsController.setTrustToken(zeroAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setSatelliteEmissionsController)
    //////////////////////////////////////////////////////////////*/

    function test_setSatelliteEmissionsController_shouldSucceedWithAdminRole() external {
        address newSatellite = address(0x789);
        address originalSatellite = baseEmissionsController.getSatelliteEmissionsController();

        vm.expectEmit(true, false, false, true);
        emit SatelliteEmissionsControllerUpdated(newSatellite);

        resetPrank(users.admin);
        baseEmissionsController.setSatelliteEmissionsController(newSatellite);

        assertEq(baseEmissionsController.getSatelliteEmissionsController(), newSatellite, "Satellite should be updated");
        assertNotEq(originalSatellite, newSatellite, "Should be different from original");
    }

    function test_setSatelliteEmissionsController_shouldRevertWithUnauthorizedUser() external {
        address newSatellite = address(0x789);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setSatelliteEmissionsController(newSatellite);
    }

    function test_setSatelliteEmissionsController_shouldRevertWithControllerRole() external {
        address newSatellite = address(0x789);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setSatelliteEmissionsController(newSatellite);
    }

    function test_setSatelliteEmissionsController_shouldRevertWithZeroAddress() external {
        address zeroAddress = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidAddress.selector)
        );

        resetPrank(users.admin);
        baseEmissionsController.setSatelliteEmissionsController(zeroAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setMessageGasCost)
    //////////////////////////////////////////////////////////////*/

    function test_setMessageGasCost_shouldSucceedWithAdminRole() external {
        uint256 newGasCost = 50_000;
        uint256 originalGasCost = baseEmissionsController.getMessageGasCost();

        vm.expectEmit(true, false, false, true);
        emit MessageGasCostUpdated(newGasCost);

        resetPrank(users.admin);
        baseEmissionsController.setMessageGasCost(newGasCost);

        assertEq(baseEmissionsController.getMessageGasCost(), newGasCost, "Message gas cost should be updated");
        assertNotEq(originalGasCost, newGasCost, "Should be different from original");
    }

    function test_setMessageGasCost_shouldRevertWithUnauthorizedUser() external {
        uint256 newGasCost = 50_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setMessageGasCost(newGasCost);
    }

    function test_setMessageGasCost_shouldRevertWithControllerRole() external {
        uint256 newGasCost = 50_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setMessageGasCost(newGasCost);
    }

    function test_setMessageGasCost_shouldAllowZeroValue() external {
        uint256 zeroGasCost = 0;

        resetPrank(users.admin);
        baseEmissionsController.setMessageGasCost(zeroGasCost);

        assertEq(baseEmissionsController.getMessageGasCost(), zeroGasCost, "Message gas cost should accept zero value");
    }

    function test_setMessageGasCost_shouldAllowLargeValue() external {
        uint256 largeGasCost = type(uint256).max;

        resetPrank(users.admin);
        baseEmissionsController.setMessageGasCost(largeGasCost);

        assertEq(
            baseEmissionsController.getMessageGasCost(), largeGasCost, "Message gas cost should accept large values"
        );
    }

    /*//////////////////////////////////////////////////////////////
                DEFAULT_ADMIN_ROLE TESTS (setFinalityState)
    //////////////////////////////////////////////////////////////*/

    function test_setFinalityState_shouldSucceedWithAdminRole_INSTANT() external {
        FinalityState newState = FinalityState.INSTANT;

        vm.expectEmit(true, false, false, true);
        emit FinalityStateUpdated(newState);

        resetPrank(users.admin);
        baseEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(baseEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated to INSTANT"
        );
    }

    function test_setFinalityState_shouldSucceedWithAdminRole_FINALIZED() external {
        FinalityState newState = FinalityState.FINALIZED;

        resetPrank(users.admin);
        baseEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(baseEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated to FINALIZED"
        );
    }

    function test_setFinalityState_shouldSucceedWithAdminRole_ESPRESSO() external {
        FinalityState newState = FinalityState.ESPRESSO;

        resetPrank(users.admin);
        baseEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(baseEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated to ESPRESSO"
        );
    }

    function test_setFinalityState_shouldRevertWithUnauthorizedUser() external {
        FinalityState newState = FinalityState.FINALIZED;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setFinalityState(newState);
    }

    function test_setFinalityState_shouldRevertWithControllerRole() external {
        FinalityState newState = FinalityState.FINALIZED;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setFinalityState(newState);
    }

    /*//////////////////////////////////////////////////////////////
            DEFAULT_ADMIN_ROLE TESTS (setMetaERC20SpokeOrHub)
    //////////////////////////////////////////////////////////////*/

    function test_setMetaERC20SpokeOrHub_shouldRevertOnInvalidAddress() external {
        address invalidAddress = address(0);

        resetPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MetaERC20Dispatcher.MetaERC20Dispatcher_InvalidAddress.selector));
        baseEmissionsController.setMetaERC20SpokeOrHub(invalidAddress);
    }

    function test_setMetaERC20SpokeOrHub_shouldSucceedWithAdminRole() external {
        address newSpokeOrHub = address(0x123456);
        address originalSpokeOrHub = baseEmissionsController.getMetaERC20SpokeOrHub();

        vm.expectEmit(true, false, false, true);
        emit MetaERC20SpokeOrHubUpdated(newSpokeOrHub);

        resetPrank(users.admin);
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        assertEq(
            baseEmissionsController.getMetaERC20SpokeOrHub(), newSpokeOrHub, "MetaERC20SpokeOrHub should be updated"
        );
        assertNotEq(originalSpokeOrHub, newSpokeOrHub, "Should be different from original");
    }

    function test_setMetaERC20SpokeOrHub_shouldRevertWithUnauthorizedUser() external {
        address newSpokeOrHub = address(0x123456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
    }

    function test_setMetaERC20SpokeOrHub_shouldRevertWithControllerRole() external {
        address newSpokeOrHub = address(0x123456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
    }

    /*//////////////////////////////////////////////////////////////
                DEFAULT_ADMIN_ROLE TESTS (setRecipientDomain)
    //////////////////////////////////////////////////////////////*/

    function test_setRecipientDomain_shouldSucceedWithAdminRole() external {
        uint32 newDomain = 12_345;
        uint32 originalDomain = baseEmissionsController.getRecipientDomain();

        vm.expectEmit(true, false, false, true);
        emit RecipientDomainUpdated(newDomain);

        resetPrank(users.admin);
        baseEmissionsController.setRecipientDomain(newDomain);

        assertEq(baseEmissionsController.getRecipientDomain(), newDomain, "Recipient domain should be updated");
        assertNotEq(originalDomain, newDomain, "Should be different from original");
    }

    function test_setRecipientDomain_shouldAllowZeroValue() external {
        uint32 zeroDomain = 0;

        resetPrank(users.admin);
        baseEmissionsController.setRecipientDomain(zeroDomain);

        assertEq(baseEmissionsController.getRecipientDomain(), zeroDomain, "Recipient domain should accept zero value");
    }

    function test_setRecipientDomain_shouldAllowMaxUint32() external {
        uint32 maxDomain = type(uint32).max;

        resetPrank(users.admin);
        baseEmissionsController.setRecipientDomain(maxDomain);

        assertEq(
            baseEmissionsController.getRecipientDomain(), maxDomain, "Recipient domain should accept max uint32 value"
        );
    }

    function test_setRecipientDomain_shouldRevertWithUnauthorizedUser() external {
        uint32 newDomain = 12_345;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.setRecipientDomain(newDomain);
    }

    function test_setRecipientDomain_shouldRevertWithControllerRole() external {
        uint32 newDomain = 12_345;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(users.controller);
        baseEmissionsController.setRecipientDomain(newDomain);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_adminCanPerformAllOperations() external {
        uint256 newGasCost = 75_000;
        FinalityState newState = FinalityState.ESPRESSO;
        address newSpokeOrHub = address(0x987654);
        uint32 newDomain = 54_321;

        vm.startPrank(users.admin);

        // Admin should be able to set message gas cost
        baseEmissionsController.setMessageGasCost(newGasCost);
        assertEq(
            baseEmissionsController.getMessageGasCost(), newGasCost, "Admin should be able to set message gas cost"
        );

        // Admin should be able to set finality state
        baseEmissionsController.setFinalityState(newState);
        assertEq(
            uint8(baseEmissionsController.getFinalityState()),
            uint8(newState),
            "Admin should be able to set finality state"
        );

        // Admin should be able to set MetaERC20SpokeOrHub
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
        assertEq(
            baseEmissionsController.getMetaERC20SpokeOrHub(),
            newSpokeOrHub,
            "Admin should be able to set MetaERC20SpokeOrHub"
        );

        // Admin should be able to set recipient domain
        baseEmissionsController.setRecipientDomain(newDomain);
        assertEq(
            baseEmissionsController.getRecipientDomain(), newDomain, "Admin should be able to set recipient domain"
        );

        vm.stopPrank();
    }

    function test_controllerCannotPerformAdminOperations() external {
        uint256 newGasCost = 90_000;
        FinalityState newState = FinalityState.FINALIZED;
        address newSpokeOrHub = address(0x222222);
        uint32 newDomain = 22_222;

        // Test all functions fail with controller role
        vm.startPrank(users.controller);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setMessageGasCost(newGasCost);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setFinalityState(newState);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.controller, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();
    }

    function test_multipleUpdatesInSequence() external {
        // Perform multiple updates and verify each one takes effect
        uint256[] memory gasCosts = new uint256[](3);
        gasCosts[0] = 10_000;
        gasCosts[1] = 50_000;
        gasCosts[2] = 100_000;

        vm.startPrank(users.admin);

        for (uint256 i = 0; i < gasCosts.length; i++) {
            baseEmissionsController.setMessageGasCost(gasCosts[i]);
            assertEq(
                baseEmissionsController.getMessageGasCost(), gasCosts[i], "Each gas cost update should take effect"
            );
        }

        // Test finality state updates
        FinalityState[] memory states = new FinalityState[](3);
        states[0] = FinalityState.INSTANT;
        states[1] = FinalityState.FINALIZED;
        states[2] = FinalityState.ESPRESSO;

        for (uint256 i = 0; i < states.length; i++) {
            baseEmissionsController.setFinalityState(states[i]);
            assertEq(
                uint8(baseEmissionsController.getFinalityState()),
                uint8(states[i]),
                "Each finality state update should take effect"
            );
        }

        vm.stopPrank();
    }

    function test_eventEmissions() external {
        uint256 newGasCost = 60_000;
        FinalityState newState = FinalityState.FINALIZED;
        address newSpokeOrHub = address(0xABCDEF);
        uint32 newDomain = 99_999;

        vm.startPrank(users.admin);

        // Test MessageGasCostUpdated event
        vm.expectEmit(true, false, false, true);
        emit MessageGasCostUpdated(newGasCost);
        baseEmissionsController.setMessageGasCost(newGasCost);

        // Test FinalityStateUpdated event
        vm.expectEmit(true, false, false, true);
        emit FinalityStateUpdated(newState);
        baseEmissionsController.setFinalityState(newState);

        // Test MetaERC20SpokeOrHubUpdated event
        vm.expectEmit(true, false, false, true);
        emit MetaERC20SpokeOrHubUpdated(newSpokeOrHub);
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        // Test RecipientDomainUpdated event
        vm.expectEmit(true, false, false, true);
        emit RecipientDomainUpdated(newDomain);
        baseEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BOUNDARY VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_boundaryValues_messageGasCost() external {
        uint256[] memory testValues = new uint256[](3);
        testValues[0] = 0; // Minimum
        testValues[1] = 1e18; // Large value
        testValues[2] = type(uint256).max; // Maximum

        vm.startPrank(users.admin);

        for (uint256 i = 0; i < testValues.length; i++) {
            baseEmissionsController.setMessageGasCost(testValues[i]);
            assertEq(
                baseEmissionsController.getMessageGasCost(),
                testValues[i],
                "Message gas cost should accept boundary values"
            );
        }

        vm.stopPrank();
    }

    function test_boundaryValues_recipientDomain() external {
        uint32[] memory testValues = new uint32[](3);
        testValues[0] = 0; // Minimum
        testValues[1] = 2_147_483_647; // Large value
        testValues[2] = type(uint32).max; // Maximum

        vm.startPrank(users.admin);

        for (uint256 i = 0; i < testValues.length; i++) {
            baseEmissionsController.setRecipientDomain(testValues[i]);
            assertEq(
                baseEmissionsController.getRecipientDomain(),
                testValues[i],
                "Recipient domain should accept boundary values"
            );
        }

        vm.stopPrank();
    }

    function test_stateConsistency_afterMultipleUpdates() external {
        // Store original values
        uint256 originalGasCost = baseEmissionsController.getMessageGasCost();
        FinalityState originalState = baseEmissionsController.getFinalityState();
        address originalSpokeOrHub = baseEmissionsController.getMetaERC20SpokeOrHub();
        uint32 originalDomain = baseEmissionsController.getRecipientDomain();

        // Set new values
        uint256 newGasCost = 80_000;
        FinalityState newState = FinalityState.FINALIZED;
        address newSpokeOrHub = address(0x111111);
        uint32 newDomain = 11_111;

        vm.startPrank(users.admin);

        baseEmissionsController.setMessageGasCost(newGasCost);
        baseEmissionsController.setFinalityState(newState);
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
        baseEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();

        // Verify all updates took effect and are consistent
        assertEq(baseEmissionsController.getMessageGasCost(), newGasCost, "Message gas cost should be updated");
        assertEq(uint8(baseEmissionsController.getFinalityState()), uint8(newState), "Finality state should be updated");
        assertEq(
            baseEmissionsController.getMetaERC20SpokeOrHub(), newSpokeOrHub, "MetaERC20SpokeOrHub should be updated"
        );
        assertEq(baseEmissionsController.getRecipientDomain(), newDomain, "Recipient domain should be updated");

        // Verify changes from original values
        assertNotEq(originalGasCost, newGasCost, "Gas cost should be different from original");
        assertNotEq(uint8(originalState), uint8(newState), "Finality state should be different from original");
        assertNotEq(originalSpokeOrHub, newSpokeOrHub, "SpokeOrHub should be different from original");
        assertNotEq(originalDomain, newDomain, "Domain should be different from original");
    }

    function test_unauthorizedUserCannotAccessAnyFunction() external {
        uint256 newGasCost = 90_000;
        FinalityState newState = FinalityState.FINALIZED;
        address newSpokeOrHub = address(0x222222);
        uint32 newDomain = 22_222;

        // Test all functions fail with unauthorized user
        vm.startPrank(unauthorizedUser);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setMessageGasCost(newGasCost);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setFinalityState(newState);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        baseEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE SPECIFICITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onlyAdminCanCallSetterFunctions() external {
        // Test that even other protocol addresses cannot call these functions
        address[] memory testUsers = new address[](4);
        testUsers[0] = users.controller; // Has CONTROLLER_ROLE but not admin
        testUsers[1] = unauthorizedUser;
        testUsers[2] = users.alice;
        testUsers[3] = users.bob;

        uint256 newGasCost = 70_000;

        for (uint256 i = 0; i < testUsers.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, testUsers[i], DEFAULT_ADMIN_ROLE
                )
            );

            resetPrank(testUsers[i]);
            baseEmissionsController.setMessageGasCost(newGasCost);
        }

        // But admin should succeed
        resetPrank(users.admin);
        baseEmissionsController.setMessageGasCost(newGasCost);

        assertEq(baseEmissionsController.getMessageGasCost(), newGasCost, "Admin should successfully update gas cost");
    }

    function test_gettersRemainAccessible() external {
        // Verify that getter functions are still accessible to everyone
        address[] memory testUsers = new address[](4);
        testUsers[0] = users.admin;
        testUsers[1] = users.controller;
        testUsers[2] = unauthorizedUser;
        testUsers[3] = users.alice;

        for (uint256 i = 0; i < testUsers.length; i++) {
            resetPrank(testUsers[i]);

            // All these should succeed without reverting
            uint256 gasCost = baseEmissionsController.getMessageGasCost();
            FinalityState state = baseEmissionsController.getFinalityState();
            address spokeOrHub = baseEmissionsController.getMetaERC20SpokeOrHub();
            uint32 domain = baseEmissionsController.getRecipientDomain();

            // Basic sanity checks
            assertTrue(gasCost >= 0, "Gas cost should be readable");
            assertTrue(uint8(state) <= 2, "Finality state should be valid enum value");
            assertTrue(spokeOrHub != address(0), "SpokeOrHub should be set"); // Based on our setup
            assertTrue(domain >= 0, "Domain should be readable");
        }
    }
}
