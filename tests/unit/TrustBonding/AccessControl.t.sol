// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/AccessControl.t.sol'
contract AccessControlTest is BaseTest {
    /// @notice Test constants
    uint256 public initialTokens = 10_000 * 1e18;

    /// @notice Test addresses
    address public unauthorizedUser = address(0x999);
    address public timelockUser = address(0x888);
    address public pauserUser = address(0x777);

    /// @notice Role constants for testing
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice Events to test (removed for now due to interface issues)

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, initialTokens * 10);
        _setupUserWrappedTokenAndTrustBonding(users.alice);

        // Set up additional role users
        vm.deal(timelockUser, 1 ether);
        vm.deal(pauserUser, 1 ether);
        vm.deal(unauthorizedUser, 1 ether);

        // Grant roles for testing
        vm.startPrank(users.admin);
        protocol.trustBonding.grantRole(TIMELOCK_ROLE, users.admin);
        protocol.trustBonding.grantRole(TIMELOCK_ROLE, timelockUser);
        protocol.trustBonding.grantRole(PAUSER_ROLE, pauserUser);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSER_ROLE TESTS (pause)
    //////////////////////////////////////////////////////////////*/

    function test_pause_shouldSucceedWithPauserRole() external {
        assertFalse(protocol.trustBonding.paused(), "Contract should not be paused initially");

        vm.prank(pauserUser);
        protocol.trustBonding.pause();

        assertTrue(protocol.trustBonding.paused(), "Contract should be paused after calling pause");
    }

    function test_pause_shouldSucceedWithAdminRole() external {
        assertFalse(protocol.trustBonding.paused(), "Contract should not be paused initially");

        vm.prank(users.admin);
        protocol.trustBonding.pause();

        assertTrue(protocol.trustBonding.paused(), "Contract should be paused after calling pause");
    }

    function test_pause_shouldRevertWithUnauthorizedUser() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, PAUSER_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.pause();
    }

    function test_pause_shouldRevertWithTimelockRole() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, timelockUser, PAUSER_ROLE)
        );

        vm.prank(timelockUser);
        protocol.trustBonding.pause();
    }

    function test_pause_shouldRevertIfAlreadyPaused() external {
        // First pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();

        // Try to pause again
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.prank(users.admin);
        protocol.trustBonding.pause();
    }

    /*//////////////////////////////////////////////////////////////
                    DEFAULT_ADMIN_ROLE TESTS (unpause)
    //////////////////////////////////////////////////////////////*/

    function test_unpause_shouldSucceedWithAdminRole() external {
        // First pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();
        assertTrue(protocol.trustBonding.paused(), "Contract should be paused");

        // Then unpause
        vm.prank(users.admin);
        protocol.trustBonding.unpause();
        assertFalse(protocol.trustBonding.paused(), "Contract should be unpaused after calling unpause");
    }

    function test_unpause_shouldRevertWithPauserRole() external {
        // First pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, pauserUser, DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(pauserUser);
        protocol.trustBonding.unpause();
    }

    function test_unpause_shouldRevertWithTimelockRole() external {
        // First pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, timelockUser, DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(timelockUser);
        protocol.trustBonding.unpause();
    }

    function test_unpause_shouldRevertWithUnauthorizedUser() external {
        // First pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.unpause();
    }

    function test_unpause_shouldRevertIfNotPaused() external {
        assertFalse(protocol.trustBonding.paused(), "Contract should not be paused");

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector));
        vm.prank(users.admin);
        protocol.trustBonding.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                        TIMELOCK_ROLE TESTS (setMultiVault)
    //////////////////////////////////////////////////////////////*/

    function test_setMultiVault_shouldSucceedWithTimelockRole() external {
        address newMultiVault = address(0x123456);

        vm.prank(timelockUser);
        protocol.trustBonding.setMultiVault(newMultiVault);

        assertEq(protocol.trustBonding.multiVault(), newMultiVault, "MultiVault should be updated");
    }

    function test_setMultiVault_shouldSucceedWithAdminRole() external {
        address newMultiVault = address(0x123456);

        vm.prank(users.admin);
        protocol.trustBonding.setMultiVault(newMultiVault);

        assertEq(protocol.trustBonding.multiVault(), newMultiVault, "MultiVault should be updated");
    }

    function test_setMultiVault_shouldRevertWithZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.setMultiVault(address(0));
    }

    function test_setMultiVault_shouldRevertWithUnauthorizedUser() external {
        address newMultiVault = address(0x123456);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, TIMELOCK_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.setMultiVault(newMultiVault);
    }

    function test_setMultiVault_shouldRevertWithPauserRole() external {
        address newMultiVault = address(0x123456);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauserUser, TIMELOCK_ROLE)
        );

        vm.prank(pauserUser);
        protocol.trustBonding.setMultiVault(newMultiVault);
    }

    /*//////////////////////////////////////////////////////////////
            TIMELOCK_ROLE TESTS (setSatelliteEmissionsController)
    //////////////////////////////////////////////////////////////*/

    function test_setSatelliteEmissionsController_shouldSucceedWithTimelockRole() external {
        address newController = address(0x654321);

        vm.prank(timelockUser);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);

        assertEq(
            protocol.trustBonding.satelliteEmissionsController(),
            newController,
            "SatelliteEmissionsController should be updated"
        );
    }

    function test_setSatelliteEmissionsController_shouldSucceedWithAdminRole() external {
        address newController = address(0x654321);

        vm.prank(users.admin);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);

        assertEq(
            protocol.trustBonding.satelliteEmissionsController(),
            newController,
            "SatelliteEmissionsController should be updated"
        );
    }

    function test_setSatelliteEmissionsController_shouldRevertWithZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_ZeroAddress.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.updateSatelliteEmissionsController(address(0));
    }

    function test_setSatelliteEmissionsController_shouldRevertWithUnauthorizedUser() external {
        address newController = address(0x654321);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, TIMELOCK_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);
    }

    function test_setSatelliteEmissionsController_shouldRevertWithPauserRole() external {
        address newController = address(0x654321);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauserUser, TIMELOCK_ROLE)
        );

        vm.prank(pauserUser);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);
    }

    /*//////////////////////////////////////////////////////////////
          TIMELOCK_ROLE TESTS (updateSystemUtilizationLowerBound)
    //////////////////////////////////////////////////////////////*/

    function test_updateSystemUtilizationLowerBound_shouldSucceedWithValidBound() external {
        uint256 newLowerBound = 6000; // 60%

        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newLowerBound);

        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            newLowerBound,
            "System utilization lower bound should be updated"
        );
    }

    function test_updateSystemUtilizationLowerBound_shouldSucceedWithMinimumBound() external {
        uint256 minimumBound = 4000; // 40% - minimum allowed

        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(minimumBound);

        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            minimumBound,
            "System utilization lower bound should be updated to minimum"
        );
    }

    function test_updateSystemUtilizationLowerBound_shouldSucceedWithMaximumBound() external {
        uint256 maximumBound = 10_000; // 100% - maximum allowed

        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(maximumBound);

        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            maximumBound,
            "System utilization lower bound should be updated to maximum"
        );
    }

    function test_updateSystemUtilizationLowerBound_shouldRevertWithBelowMinimum() external {
        uint256 belowMinimum = 3999; // Just below 40% minimum

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidUtilizationLowerBound.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(belowMinimum);
    }

    function test_updateSystemUtilizationLowerBound_shouldRevertWithAboveMaximum() external {
        uint256 aboveMaximum = 10_001; // Just above 100% maximum

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidUtilizationLowerBound.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(aboveMaximum);
    }

    function test_updateSystemUtilizationLowerBound_shouldRevertWithUnauthorizedUser() external {
        uint256 newLowerBound = 6000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, TIMELOCK_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newLowerBound);
    }

    function test_updateSystemUtilizationLowerBound_shouldRevertWithPauserRole() external {
        uint256 newLowerBound = 6000;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauserUser, TIMELOCK_ROLE)
        );

        vm.prank(pauserUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newLowerBound);
    }

    function test_updateSystemUtilizationLowerBound_shouldSucceedWithAdminRole() external {
        uint256 newLowerBound = 6000;

        vm.prank(users.admin);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newLowerBound);

        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            newLowerBound,
            "System utilization lower bound should be updated"
        );
    }

    /*//////////////////////////////////////////////////////////////
         TIMELOCK_ROLE TESTS (updatePersonalUtilizationLowerBound)
    //////////////////////////////////////////////////////////////*/

    function test_updatePersonalUtilizationLowerBound_shouldSucceedWithValidBound() external {
        uint256 newLowerBound = 4000; // 40%

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newLowerBound);

        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            newLowerBound,
            "Personal utilization lower bound should be updated"
        );
    }

    function test_updatePersonalUtilizationLowerBound_shouldSucceedWithMinimumBound() external {
        uint256 minimumBound = 2500; // 25% - minimum allowed

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(minimumBound);

        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            minimumBound,
            "Personal utilization lower bound should be updated to minimum"
        );
    }

    function test_updatePersonalUtilizationLowerBound_shouldSucceedWithMaximumBound() external {
        uint256 maximumBound = 10_000; // 100% - maximum allowed

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(maximumBound);

        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            maximumBound,
            "Personal utilization lower bound should be updated to maximum"
        );
    }

    function test_updatePersonalUtilizationLowerBound_shouldRevertWithBelowMinimum() external {
        uint256 belowMinimum = 2499; // Just below 25% minimum

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidUtilizationLowerBound.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(belowMinimum);
    }

    function test_updatePersonalUtilizationLowerBound_shouldRevertWithAboveMaximum() external {
        uint256 aboveMaximum = 10_001; // Just above 100% maximum

        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_InvalidUtilizationLowerBound.selector));

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(aboveMaximum);
    }

    function test_updatePersonalUtilizationLowerBound_shouldRevertWithUnauthorizedUser() external {
        uint256 newLowerBound = 4000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, TIMELOCK_ROLE
            )
        );

        vm.prank(unauthorizedUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newLowerBound);
    }

    function test_updatePersonalUtilizationLowerBound_shouldRevertWithPauserRole() external {
        uint256 newLowerBound = 4000;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauserUser, TIMELOCK_ROLE)
        );

        vm.prank(pauserUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newLowerBound);
    }

    function test_updatePersonalUtilizationLowerBound_shouldSucceedWithAdminRole() external {
        uint256 newLowerBound = 4000;

        vm.prank(users.admin);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newLowerBound);

        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            newLowerBound,
            "Personal utilization lower bound should be updated"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_roleHierarchy_adminCanPerformAllOperations() external {
        // Admin should be able to pause
        vm.prank(users.admin);
        protocol.trustBonding.pause();
        assertTrue(protocol.trustBonding.paused(), "Admin should be able to pause");

        // Admin should be able to unpause
        vm.prank(users.admin);
        protocol.trustBonding.unpause();
        assertFalse(protocol.trustBonding.paused(), "Admin should be able to unpause");

        // Admin should be able to set MultiVault
        address newMultiVault = address(0x111);
        vm.prank(users.admin);
        protocol.trustBonding.setMultiVault(newMultiVault);
        assertEq(protocol.trustBonding.multiVault(), newMultiVault, "Admin should be able to set MultiVault");

        // Admin should be able to set SatelliteEmissionsController
        address newController = address(0x222);
        vm.prank(users.admin);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);
        assertEq(
            protocol.trustBonding.satelliteEmissionsController(),
            newController,
            "Admin should be able to set SatelliteEmissionsController"
        );

        // Admin should be able to update system utilization lower bound
        uint256 newSystemBound = 6000;
        vm.prank(users.admin);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newSystemBound);
        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            newSystemBound,
            "Admin should be able to update system utilization lower bound"
        );

        // Admin should be able to update personal utilization lower bound
        uint256 newPersonalBound = 4000;
        vm.prank(users.admin);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newPersonalBound);
        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            newPersonalBound,
            "Admin should be able to update personal utilization lower bound"
        );
    }

    function test_functionsWorkAfterBoundUpdates() external {
        // Update bounds
        vm.prank(timelockUser);
        protocol.trustBonding.updateSystemUtilizationLowerBound(6000);

        vm.prank(timelockUser);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(4000);

        // Verify that utilization ratio functions still work with new bounds
        uint256 systemRatio = protocol.trustBonding.getSystemUtilizationRatio(0);
        assertEq(systemRatio, BASIS_POINTS_DIVISOR, "System utilization ratio should work after bound update");

        uint256 personalRatio = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 0);
        assertEq(personalRatio, BASIS_POINTS_DIVISOR, "Personal utilization ratio should work after bound update");
    }

    function test_multipleRoleAssignments() external {
        address multiRoleUser = address(0x555);

        // Grant multiple roles to one user
        vm.startPrank(users.admin);
        protocol.trustBonding.grantRole(PAUSER_ROLE, multiRoleUser);
        protocol.trustBonding.grantRole(TIMELOCK_ROLE, multiRoleUser);
        vm.stopPrank();

        // User should be able to perform operations from both roles
        vm.prank(multiRoleUser);
        protocol.trustBonding.pause();
        assertTrue(protocol.trustBonding.paused(), "Multi-role user should be able to pause");

        // Only admin can unpause, so this should still fail
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, multiRoleUser, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(multiRoleUser);
        protocol.trustBonding.unpause();

        // But admin can unpause
        vm.prank(users.admin);
        protocol.trustBonding.unpause();

        // Multi-role user should be able to use timelock functions
        address newMultiVault = address(0x333);
        vm.prank(multiRoleUser);
        protocol.trustBonding.setMultiVault(newMultiVault);
        assertEq(protocol.trustBonding.multiVault(), newMultiVault, "Multi-role user should be able to set MultiVault");
    }

    function test_roleRevocation() external {
        // Verify timelock user can initially perform operations
        address newMultiVault = address(0x444);
        vm.prank(timelockUser);
        protocol.trustBonding.setMultiVault(newMultiVault);

        // Revoke timelock role
        vm.prank(users.admin);
        protocol.trustBonding.revokeRole(TIMELOCK_ROLE, timelockUser);

        // Now timelock user should not be able to perform operations
        address anotherMultiVault = address(0x555);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, timelockUser, TIMELOCK_ROLE
            )
        );
        vm.prank(timelockUser);
        protocol.trustBonding.setMultiVault(anotherMultiVault);
    }

    /*//////////////////////////////////////////////////////////////
                        BOUNDARY VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_utilizationBounds_extremeValues() external {
        // Test boundary values for system utilization
        uint256[] memory systemBounds = new uint256[](3);
        systemBounds[0] = 4000; // Minimum
        systemBounds[1] = 7000; // Middle
        systemBounds[2] = 10_000; // Maximum

        for (uint256 i = 0; i < systemBounds.length; i++) {
            vm.prank(timelockUser);
            protocol.trustBonding.updateSystemUtilizationLowerBound(systemBounds[i]);
            assertEq(
                protocol.trustBonding.systemUtilizationLowerBound(), systemBounds[i], "System bound should be updated"
            );
        }

        // Test boundary values for personal utilization
        uint256[] memory personalBounds = new uint256[](3);
        personalBounds[0] = 2500; // Minimum
        personalBounds[1] = 5000; // Middle
        personalBounds[2] = 10_000; // Maximum

        for (uint256 i = 0; i < personalBounds.length; i++) {
            vm.prank(timelockUser);
            protocol.trustBonding.updatePersonalUtilizationLowerBound(personalBounds[i]);
            assertEq(
                protocol.trustBonding.personalUtilizationLowerBound(),
                personalBounds[i],
                "Personal bound should be updated"
            );
        }
    }

    function test_contractState_afterMultipleUpdates() external {
        // Perform multiple updates and verify contract state remains consistent
        address originalMultiVault = protocol.trustBonding.multiVault();
        address originalController = protocol.trustBonding.satelliteEmissionsController();
        uint256 originalSystemBound = protocol.trustBonding.systemUtilizationLowerBound();
        uint256 originalPersonalBound = protocol.trustBonding.personalUtilizationLowerBound();

        // Update all values
        address newMultiVault = address(0x999);
        address newController = address(0x888);
        uint256 newSystemBound = 7000;
        uint256 newPersonalBound = 4500;

        vm.startPrank(timelockUser);
        protocol.trustBonding.setMultiVault(newMultiVault);
        protocol.trustBonding.updateSatelliteEmissionsController(newController);
        protocol.trustBonding.updateSystemUtilizationLowerBound(newSystemBound);
        protocol.trustBonding.updatePersonalUtilizationLowerBound(newPersonalBound);
        vm.stopPrank();

        // Verify all updates took effect
        assertEq(protocol.trustBonding.multiVault(), newMultiVault, "MultiVault should be updated");
        assertEq(
            protocol.trustBonding.satelliteEmissionsController(),
            newController,
            "SatelliteEmissionsController should be updated"
        );
        assertEq(
            protocol.trustBonding.systemUtilizationLowerBound(),
            newSystemBound,
            "System utilization lower bound should be updated"
        );
        assertEq(
            protocol.trustBonding.personalUtilizationLowerBound(),
            newPersonalBound,
            "Personal utilization lower bound should be updated"
        );

        // Verify other functions still work
        assertFalse(protocol.trustBonding.paused(), "Contract should not be paused");

        // Verify contract can still be paused and unpaused
        vm.prank(users.admin);
        protocol.trustBonding.pause();
        assertTrue(protocol.trustBonding.paused(), "Contract should be paused");

        vm.prank(users.admin);
        protocol.trustBonding.unpause();
        assertFalse(protocol.trustBonding.paused(), "Contract should be unpaused");
    }
}
