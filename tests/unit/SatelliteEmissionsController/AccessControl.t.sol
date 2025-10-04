// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev forge test --match-path 'tests/unit/SatelliteEmissionsController/AccessControl.t.sol'
contract AccessControlTest is TrustBondingBase {
    /// @notice Test addresses
    address public unauthorizedUser = address(0x999);
    address public baseEmissionsController = address(0xABC);

    /// @notice Role constants for testing
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Events to test
    event TrustBondingUpdated(address indexed newTrustBonding);
    event BaseEmissionsControllerUpdated(address indexed newBaseEmissionsController);
    event MessageGasCostUpdated(uint256 newMessageGasCost);
    event FinalityStateUpdated(FinalityState newFinalityState);
    event RecipientDomainUpdated(uint32 newRecipientDomain);
    event MetaERC20SpokeOrHubUpdated(address newMetaERC20SpokeOrHub);

    function setUp() public override {
        super.setUp();
        vm.deal(unauthorizedUser, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_shouldRevertIfAdminIsZeroAddress() external {
        SatelliteEmissionsController satelliteEmissionsController = _deploySatelliteEmissionsController();

        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );

        satelliteEmissionsController.initialize(
            address(0), address(baseEmissionsController), metaERC20DispatchInit, coreEmissionsInit
        );
    }

    function test_initialize_shouldRevertIfBaseEmissionsControllerIsZeroAddress() external {
        SatelliteEmissionsController satelliteEmissionsController = _deploySatelliteEmissionsController();

        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );

        satelliteEmissionsController.initialize(users.admin, address(0), metaERC20DispatchInit, coreEmissionsInit);
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setTrustBonding)
    //////////////////////////////////////////////////////////////*/

    function test_setTrustBonding_shouldSucceedWithAdminRole() external {
        address newTrustBonding = address(0x123456);

        vm.expectEmit(true, true, true, true);
        emit TrustBondingUpdated(newTrustBonding);
        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setTrustBonding(newTrustBonding);

        assertEq(
            protocol.satelliteEmissionsController.getTrustBonding(), newTrustBonding, "TrustBonding should be updated"
        );
    }

    function test_setTrustBonding_shouldRevertWithUnauthorizedUser() external {
        address newTrustBonding = address(0x123456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        protocol.satelliteEmissionsController.setTrustBonding(newTrustBonding);
    }

    function test_setTrustBonding_shouldRevertWithZeroAddress() external {
        address zeroAddress = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setTrustBonding(zeroAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setBaseEmissionsController)
    //////////////////////////////////////////////////////////////*/

    function test_setBaseEmissionsController_shouldSucceedWithAdminRole() external {
        address newBaseEmissionsController = address(0x654321);

        vm.expectEmit(true, true, true, true);
        emit BaseEmissionsControllerUpdated(newBaseEmissionsController);
        vm.startPrank(users.admin);
        protocol.satelliteEmissionsController.setBaseEmissionsController(newBaseEmissionsController);

        assertEq(
            protocol.satelliteEmissionsController.getBaseEmissionsController(),
            newBaseEmissionsController,
            "BaseEmissionsController should be updated"
        );

        vm.stopPrank();
    }

    function test_setBaseEmissionsController_shouldRevertWithUnauthorizedUser() external {
        address newBaseEmissionsController = address(0x654321);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        protocol.satelliteEmissionsController.setBaseEmissionsController(newBaseEmissionsController);
    }

    function test_setBaseEmissionsController_shouldRevertWithZeroAddress() external {
        address zeroAddress = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setBaseEmissionsController(zeroAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (setMessageGasCost)
    //////////////////////////////////////////////////////////////*/

    function test_setMessageGasCost_shouldSucceedWithAdminRole() external {
        uint256 newGasCost = 50_000;
        uint256 originalGasCost = protocol.satelliteEmissionsController.getMessageGasCost();

        vm.expectEmit(true, false, false, true);
        emit MessageGasCostUpdated(newGasCost);

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);

        assertEq(
            protocol.satelliteEmissionsController.getMessageGasCost(), newGasCost, "Message gas cost should be updated"
        );
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
        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);
    }

    function test_setMessageGasCost_shouldAllowZeroValue() external {
        uint256 zeroGasCost = 0;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setMessageGasCost(zeroGasCost);

        assertEq(
            protocol.satelliteEmissionsController.getMessageGasCost(),
            zeroGasCost,
            "Message gas cost should accept zero value"
        );
    }

    function test_setMessageGasCost_shouldAllowLargeValue() external {
        uint256 largeGasCost = type(uint256).max;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setMessageGasCost(largeGasCost);

        assertEq(
            protocol.satelliteEmissionsController.getMessageGasCost(),
            largeGasCost,
            "Message gas cost should accept large values"
        );
    }

    /*//////////////////////////////////////////////////////////////
                DEFAULT_ADMIN_ROLE TESTS (setFinalityState)
    //////////////////////////////////////////////////////////////*/

    function test_setFinalityState_shouldSucceedWithAdminRole_INSTANT() external {
        FinalityState newState = FinalityState.INSTANT;
        FinalityState originalState = protocol.satelliteEmissionsController.getFinalityState();

        vm.expectEmit(true, false, false, true);
        emit FinalityStateUpdated(newState);

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(protocol.satelliteEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated to INSTANT"
        );
    }

    function test_setFinalityState_shouldSucceedWithAdminRole_FINALIZED() external {
        FinalityState newState = FinalityState.FINALIZED;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(protocol.satelliteEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated to FINALIZED"
        );
    }

    function test_setFinalityState_shouldSucceedWithAdminRole_ESPRESSO() external {
        FinalityState newState = FinalityState.ESPRESSO;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setFinalityState(newState);

        assertEq(
            uint8(protocol.satelliteEmissionsController.getFinalityState()),
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
        protocol.satelliteEmissionsController.setFinalityState(newState);
    }

    /*//////////////////////////////////////////////////////////////
            DEFAULT_ADMIN_ROLE TESTS (setMetaERC20SpokeOrHub)
    //////////////////////////////////////////////////////////////*/

    function test_setMetaERC20SpokeOrHub_shouldRevertWithZeroAddress() external {
        address zeroAddress = address(0);

        vm.expectRevert(abi.encodeWithSelector(MetaERC20Dispatcher.MetaERC20Dispatcher_InvalidAddress.selector));

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(zeroAddress);
    }

    function test_setMetaERC20SpokeOrHub_shouldSucceedWithAdminRole() external {
        address newSpokeOrHub = address(0x123456);
        address originalSpokeOrHub = protocol.satelliteEmissionsController.getMetaERC20SpokeOrHub();

        vm.expectEmit(true, false, false, true);
        emit MetaERC20SpokeOrHubUpdated(newSpokeOrHub);

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        assertEq(
            protocol.satelliteEmissionsController.getMetaERC20SpokeOrHub(),
            newSpokeOrHub,
            "MetaERC20SpokeOrHub should be updated"
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
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
    }

    /*//////////////////////////////////////////////////////////////
                DEFAULT_ADMIN_ROLE TESTS (setRecipientDomain)
    //////////////////////////////////////////////////////////////*/

    function test_setRecipientDomain_shouldSucceedWithAdminRole() external {
        uint32 newDomain = 12_345;
        uint32 originalDomain = protocol.satelliteEmissionsController.getRecipientDomain();

        vm.expectEmit(true, false, false, true);
        emit RecipientDomainUpdated(newDomain);

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);

        assertEq(
            protocol.satelliteEmissionsController.getRecipientDomain(), newDomain, "Recipient domain should be updated"
        );
        assertNotEq(originalDomain, newDomain, "Should be different from original");
    }

    function test_setRecipientDomain_shouldAllowZeroValue() external {
        uint32 zeroDomain = 0;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setRecipientDomain(zeroDomain);

        assertEq(
            protocol.satelliteEmissionsController.getRecipientDomain(),
            zeroDomain,
            "Recipient domain should accept zero value"
        );
    }

    function test_setRecipientDomain_shouldAllowMaxUint32() external {
        uint32 maxDomain = type(uint32).max;

        resetPrank(users.admin);
        protocol.satelliteEmissionsController.setRecipientDomain(maxDomain);

        assertEq(
            protocol.satelliteEmissionsController.getRecipientDomain(),
            maxDomain,
            "Recipient domain should accept max uint32 value"
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
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_adminCanPerformAllOperations() external {
        uint256 newGasCost = 75_000;
        FinalityState newState = FinalityState.ESPRESSO;
        address newSpokeOrHub = address(0x987654);
        uint32 newDomain = 54_321;

        resetPrank(users.admin);

        // Admin should be able to set message gas cost
        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);
        assertEq(
            protocol.satelliteEmissionsController.getMessageGasCost(),
            newGasCost,
            "Admin should be able to set message gas cost"
        );

        // Admin should be able to set finality state
        protocol.satelliteEmissionsController.setFinalityState(newState);
        assertEq(
            uint8(protocol.satelliteEmissionsController.getFinalityState()),
            uint8(newState),
            "Admin should be able to set finality state"
        );

        // Admin should be able to set MetaERC20SpokeOrHub
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
        assertEq(
            protocol.satelliteEmissionsController.getMetaERC20SpokeOrHub(),
            newSpokeOrHub,
            "Admin should be able to set MetaERC20SpokeOrHub"
        );

        // Admin should be able to set recipient domain
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);
        assertEq(
            protocol.satelliteEmissionsController.getRecipientDomain(),
            newDomain,
            "Admin should be able to set recipient domain"
        );

        vm.stopPrank();
    }

    function test_multipleUpdatesInSequence() external {
        // Perform multiple updates and verify each one takes effect
        uint256[] memory gasCosts = new uint256[](3);
        gasCosts[0] = 10_000;
        gasCosts[1] = 50_000;
        gasCosts[2] = 100_000;

        resetPrank(users.admin);

        for (uint256 i = 0; i < gasCosts.length; i++) {
            protocol.satelliteEmissionsController.setMessageGasCost(gasCosts[i]);
            assertEq(
                protocol.satelliteEmissionsController.getMessageGasCost(),
                gasCosts[i],
                "Each gas cost update should take effect"
            );
        }

        // Test finality state updates
        FinalityState[] memory states = new FinalityState[](3);
        states[0] = FinalityState.INSTANT;
        states[1] = FinalityState.FINALIZED;
        states[2] = FinalityState.ESPRESSO;

        for (uint256 i = 0; i < states.length; i++) {
            protocol.satelliteEmissionsController.setFinalityState(states[i]);
            assertEq(
                uint8(protocol.satelliteEmissionsController.getFinalityState()),
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

        resetPrank(users.admin);

        // Test MessageGasCostUpdated event
        vm.expectEmit(true, false, false, true);
        emit MessageGasCostUpdated(newGasCost);
        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);

        // Test FinalityStateUpdated event
        vm.expectEmit(true, false, false, true);
        emit FinalityStateUpdated(newState);
        protocol.satelliteEmissionsController.setFinalityState(newState);

        // Test MetaERC20SpokeOrHubUpdated event
        vm.expectEmit(true, false, false, true);
        emit MetaERC20SpokeOrHubUpdated(newSpokeOrHub);
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        // Test RecipientDomainUpdated event
        vm.expectEmit(true, false, false, true);
        emit RecipientDomainUpdated(newDomain);
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);

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

        resetPrank(users.admin);

        for (uint256 i = 0; i < testValues.length; i++) {
            protocol.satelliteEmissionsController.setMessageGasCost(testValues[i]);
            assertEq(
                protocol.satelliteEmissionsController.getMessageGasCost(),
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

        resetPrank(users.admin);

        for (uint256 i = 0; i < testValues.length; i++) {
            protocol.satelliteEmissionsController.setRecipientDomain(testValues[i]);
            assertEq(
                protocol.satelliteEmissionsController.getRecipientDomain(),
                testValues[i],
                "Recipient domain should accept boundary values"
            );
        }

        vm.stopPrank();
    }

    function test_stateConsistency_afterMultipleUpdates() external {
        // Store original values
        uint256 originalGasCost = protocol.satelliteEmissionsController.getMessageGasCost();
        FinalityState originalState = protocol.satelliteEmissionsController.getFinalityState();
        address originalSpokeOrHub = protocol.satelliteEmissionsController.getMetaERC20SpokeOrHub();
        uint32 originalDomain = protocol.satelliteEmissionsController.getRecipientDomain();

        // Set new values
        uint256 newGasCost = 80_000;
        FinalityState newState = FinalityState.FINALIZED;
        address newSpokeOrHub = address(0x111111);
        uint32 newDomain = 11_111;

        resetPrank(users.admin);

        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);
        protocol.satelliteEmissionsController.setFinalityState(newState);
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();

        // Verify all updates took effect and are consistent
        assertEq(
            protocol.satelliteEmissionsController.getMessageGasCost(), newGasCost, "Message gas cost should be updated"
        );
        assertEq(
            uint8(protocol.satelliteEmissionsController.getFinalityState()),
            uint8(newState),
            "Finality state should be updated"
        );
        assertEq(
            protocol.satelliteEmissionsController.getMetaERC20SpokeOrHub(),
            newSpokeOrHub,
            "MetaERC20SpokeOrHub should be updated"
        );
        assertEq(
            protocol.satelliteEmissionsController.getRecipientDomain(), newDomain, "Recipient domain should be updated"
        );

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
        resetPrank(unauthorizedUser);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        protocol.satelliteEmissionsController.setMessageGasCost(newGasCost);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        protocol.satelliteEmissionsController.setFinalityState(newState);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        protocol.satelliteEmissionsController.setMetaERC20SpokeOrHub(newSpokeOrHub);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );
        protocol.satelliteEmissionsController.setRecipientDomain(newDomain);

        vm.stopPrank();
    }
}
