// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "tests/BaseTest.t.sol";
import { EmissionsAutomationAdapter } from "src/utils/EmissionsAutomationAdapter.sol";
import { BaseEmissionsControllerMock } from "tests/mocks/BaseEmissionsControllerMock.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract EmissionsAutomationAdapterTest is BaseTest {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    EmissionsAutomationAdapter public adapter;
    BaseEmissionsControllerMock public baseEmissionsControllerMock;

    address public admin;
    address public upkeeper;
    address public unauthorized;

    bytes32 public constant UPKEEP_ROLE = keccak256("UPKEEP_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error EmissionsAutomationAdapter_InvalidAddress();

    /* =================================================== */
    /*                   SETUP FUNCTION                    */
    /* =================================================== */

    function setUp() public override {
        super.setUp();

        vm.stopPrank();

        admin = createUser("admin");
        upkeeper = createUser("upkeeper");
        unauthorized = createUser("unauthorized");

        baseEmissionsControllerMock = new BaseEmissionsControllerMock();
        baseEmissionsControllerMock.setCurrentEpoch(1);

        adapter = new EmissionsAutomationAdapter(admin, address(baseEmissionsControllerMock));

        vm.prank(admin);
        adapter.grantRole(UPKEEP_ROLE, upkeeper);
    }

    /* =================================================== */
    /*              CONSTRUCTOR TESTS                      */
    /* =================================================== */

    function test_constructor_successful() external {
        EmissionsAutomationAdapter newAdapter =
            new EmissionsAutomationAdapter(admin, address(baseEmissionsControllerMock));

        assertEq(address(newAdapter.baseEmissionsController()), address(baseEmissionsControllerMock));
        assertTrue(newAdapter.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_constructor_revertsOnInvalidAdminAddress() external {
        vm.expectRevert(abi.encodeWithSelector(EmissionsAutomationAdapter_InvalidAddress.selector));
        new EmissionsAutomationAdapter(address(0), address(baseEmissionsControllerMock));
    }

    function test_constructor_revertsOnInvalidBaseEmissionsControllerAddress() external {
        vm.expectRevert(abi.encodeWithSelector(EmissionsAutomationAdapter_InvalidAddress.selector));
        new EmissionsAutomationAdapter(admin, address(0));
    }

    function testFuzz_constructor_successful(address _admin, address _baseEmissionsController) external {
        vm.assume(_admin != address(0));
        vm.assume(_baseEmissionsController != address(0));
        vm.assume(_admin.code.length == 0);
        vm.assume(_baseEmissionsController.code.length == 0);

        EmissionsAutomationAdapter newAdapter = new EmissionsAutomationAdapter(_admin, _baseEmissionsController);

        assertEq(address(newAdapter.baseEmissionsController()), _baseEmissionsController);
        assertTrue(newAdapter.hasRole(DEFAULT_ADMIN_ROLE, _admin));
    }

    /* =================================================== */
    /*              ACCESS CONTROL TESTS                   */
    /* =================================================== */

    function test_grantRole_adminCanGrantUpkeepRole() external {
        address newUpkeeper = createUser("newUpkeeper");

        vm.prank(admin);
        adapter.grantRole(UPKEEP_ROLE, newUpkeeper);

        assertTrue(adapter.hasRole(UPKEEP_ROLE, newUpkeeper));
    }

    function test_grantRole_upkeeperCanCallFunctionsAfterRoleGrant() external {
        address newUpkeeper = createUser("newUpkeeper");

        vm.prank(admin);
        adapter.grantRole(UPKEEP_ROLE, newUpkeeper);

        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);
        baseEmissionsControllerMock.resetMintAndBridgeCalled();

        vm.prank(newUpkeeper);
        adapter.performUpkeep("");

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    function test_revokeRole_adminCanRevokeUpkeepRole() external {
        vm.prank(admin);
        adapter.revokeRole(UPKEEP_ROLE, upkeeper);

        assertFalse(adapter.hasRole(UPKEEP_ROLE, upkeeper));
    }

    function test_revokeRole_upkeeperCannotCallFunctionsAfterRoleRevoke() external {
        vm.prank(admin);
        adapter.revokeRole(UPKEEP_ROLE, upkeeper);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, upkeeper, UPKEEP_ROLE)
        );

        vm.prank(upkeeper);
        adapter.performUpkeep("");
    }

    function test_hasRole_returnsCorrectRoleStatus() external {
        assertTrue(adapter.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(adapter.hasRole(UPKEEP_ROLE, upkeeper));
        assertFalse(adapter.hasRole(UPKEEP_ROLE, unauthorized));
        assertFalse(adapter.hasRole(DEFAULT_ADMIN_ROLE, unauthorized));
    }

    function test_getRoleAdmin_upkeepRoleHasDefaultAdminAsAdmin() external {
        assertEq(adapter.getRoleAdmin(UPKEEP_ROLE), DEFAULT_ADMIN_ROLE);
    }

    function testFuzz_grantRole_adminCanGrantUpkeepRoleToAnyAddress(address newUpkeeper) external {
        vm.assume(newUpkeeper != address(0));
        _excludeReservedAddresses(newUpkeeper);

        vm.prank(admin);
        adapter.grantRole(UPKEEP_ROLE, newUpkeeper);

        assertTrue(adapter.hasRole(UPKEEP_ROLE, newUpkeeper));
    }

    /* =================================================== */
    /*              EDGE CASE TESTS                        */
    /* =================================================== */

    function test_edgeCase_epochZeroHandling() external {
        baseEmissionsControllerMock.setCurrentEpoch(0);
        baseEmissionsControllerMock.setEpochMintedAmount(0, 0);

        (bool shouldMint,) = adapter.checkUpkeep("");
        assertTrue(shouldMint);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    function test_edgeCase_maxEpochValue() external {
        uint256 maxEpoch = type(uint256).max;
        baseEmissionsControllerMock.setCurrentEpoch(maxEpoch);
        baseEmissionsControllerMock.setEpochMintedAmount(maxEpoch, 0);

        (bool shouldMint,) = adapter.checkUpkeep("");
        assertTrue(shouldMint);
    }

    function test_edgeCase_maxMintedAmount() external {
        uint256 maxAmount = type(uint256).max;
        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, maxAmount);

        (bool shouldMint,) = adapter.checkUpkeep("");
        assertFalse(shouldMint);
    }

    function test_edgeCase_multipleUpkeepersCanCallFunction() external {
        address upkeeper1 = createUser("upkeeper1");
        address upkeeper2 = createUser("upkeeper2");

        vm.startPrank(admin);
        adapter.grantRole(UPKEEP_ROLE, upkeeper1);
        adapter.grantRole(UPKEEP_ROLE, upkeeper2);
        vm.stopPrank();

        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, 0);

        vm.prank(upkeeper1);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);

        baseEmissionsControllerMock.setCurrentEpoch(2);
        baseEmissionsControllerMock.setEpochMintedAmount(2, 0);
        baseEmissionsControllerMock.resetMintAndBridgeCalled();

        vm.prank(upkeeper2);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 2);
    }

    function test_edgeCase_adminIsNotUpkeeper() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, UPKEEP_ROLE)
        );

        vm.prank(admin);
        adapter.performUpkeep("");
    }

    function test_edgeCase_adminCanGrantSelfUpkeepRole() external {
        vm.prank(admin);
        adapter.grantRole(UPKEEP_ROLE, admin);

        assertTrue(adapter.hasRole(UPKEEP_ROLE, admin));

        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, 0);

        vm.prank(admin);
        adapter.performUpkeep("");

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    /* =================================================== */
    /*              IMMUTABLE VARIABLE TESTS               */
    /* =================================================== */

    function test_baseEmissionsController_isImmutable() external {
        address initialController = address(adapter.baseEmissionsController());
        assertEq(initialController, address(baseEmissionsControllerMock));

        baseEmissionsControllerMock.setCurrentEpoch(100);

        assertEq(address(adapter.baseEmissionsController()), initialController);
    }

    /* =================================================== */
    /*              REENTRANCY TESTS                       */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpochIfNeeded_protectedAgainstReentrancy() external {
        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);
    }

    /* =================================================== */
    /*              CONSTANT TESTS                         */
    /* =================================================== */

    function test_constant_upkeepRoleValue() external {
        assertEq(adapter.UPKEEP_ROLE(), keccak256("UPKEEP_ROLE"));
    }

    /* =================================================== */
    /*              STATE CONSISTENCY TESTS                */
    /* =================================================== */

    function test_stateConsistency_shouldMintMatchesMintBehavior() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        (bool shouldMintBefore,) = adapter.checkUpkeep("");
        assertTrue(shouldMintBefore);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        (bool shouldMintAfter,) = adapter.checkUpkeep("");
        assertFalse(shouldMintAfter);
    }

    function test_stateConsistency_multipleEpochTransitions() external {
        for (uint256 i = 1; i <= 10; i++) {
            baseEmissionsControllerMock.setCurrentEpoch(i);
            baseEmissionsControllerMock.setEpochMintedAmount(i, 0);
            baseEmissionsControllerMock.resetMintAndBridgeCalled();

            (bool shouldMintBefore,) = adapter.checkUpkeep("");
            assertTrue(shouldMintBefore);

            vm.prank(upkeeper);
            adapter.performUpkeep("");

            (bool shouldMintAfter,) = adapter.checkUpkeep("");
            assertFalse(shouldMintAfter);
        }
    }

    /* =================================================== */
    /*                 checkUpkeep TESTS                   */
    /* =================================================== */

    function test_checkUpkeep_returnsTrueWhenMintingIsNeeded() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");

        assertTrue(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function test_checkUpkeep_returnsFalseWhenMintingIsNotNeeded() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 1000 ether);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function test_checkUpkeep_returnsFalseWhenEpochPartiallyMinted() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 1);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function test_checkUpkeep_withArbitraryCheckData() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        bytes memory checkData = abi.encode(uint256(123), address(0x123));
        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep(checkData);

        assertTrue(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testFuzz_checkUpkeep_returnsTrueWhenMintingIsNeeded(uint256 epoch) external {
        epoch = bound(epoch, 1, type(uint128).max);

        baseEmissionsControllerMock.setCurrentEpoch(epoch);
        baseEmissionsControllerMock.setEpochMintedAmount(epoch, 0);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");

        assertTrue(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testFuzz_checkUpkeep_returnsFalseWhenMintingIsNotNeeded(uint256 epoch, uint256 mintedAmount) external {
        epoch = bound(epoch, 1, type(uint128).max);
        mintedAmount = bound(mintedAmount, 1, type(uint128).max);

        baseEmissionsControllerMock.setCurrentEpoch(epoch);
        baseEmissionsControllerMock.setEpochMintedAmount(epoch, mintedAmount);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testFuzz_checkUpkeep_withVariousCheckData(bytes calldata checkData) external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep(checkData);

        assertTrue(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    /* =================================================== */
    /*                 performUpkeep TESTS                 */
    /* =================================================== */

    function test_performUpkeep_successful() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);
    }

    function test_performUpkeep_noOpWhenAlreadyMinted() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 1000 ether);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertFalse(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 0);
    }

    function test_performUpkeep_revertsOnUnauthorizedCaller() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, UPKEEP_ROLE)
        );

        vm.prank(unauthorized);
        adapter.performUpkeep("");
    }

    function test_performUpkeep_emitsEventWithCorrectParameters() external {
        baseEmissionsControllerMock.setCurrentEpoch(10);
        baseEmissionsControllerMock.setEpochMintedAmount(10, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");
    }

    function test_performUpkeep_withArbitraryPerformData() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        bytes memory performData = abi.encode(uint256(123), address(0x123));

        vm.prank(upkeeper);
        adapter.performUpkeep(performData);

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    function test_performUpkeep_multipleCallsInSameEpoch() external {
        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);
    }

    function test_performUpkeep_protectedAgainstReentrancy() external {
        baseEmissionsControllerMock.setCurrentEpoch(1);
        baseEmissionsControllerMock.setEpochMintedAmount(1, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertEq(baseEmissionsControllerMock.mintAndBridgeCallCount(), 1);
    }

    function testFuzz_performUpkeep_successful(uint256 epoch) external {
        epoch = bound(epoch, 1, type(uint128).max);

        baseEmissionsControllerMock.setCurrentEpoch(epoch);
        baseEmissionsControllerMock.setEpochMintedAmount(epoch, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    function testFuzz_performUpkeep_noOpWhenAlreadyMinted(uint256 epoch, uint256 mintedAmount) external {
        epoch = bound(epoch, 1, type(uint128).max);
        mintedAmount = bound(mintedAmount, 1, type(uint128).max);

        baseEmissionsControllerMock.setCurrentEpoch(epoch);
        baseEmissionsControllerMock.setEpochMintedAmount(epoch, mintedAmount);

        vm.prank(upkeeper);
        adapter.performUpkeep("");

        assertFalse(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    function testFuzz_performUpkeep_withVariousPerformData(bytes calldata performData) external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        vm.prank(upkeeper);
        adapter.performUpkeep(performData);

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());
    }

    /* =================================================== */
    /*      INTEGRATION TESTS (checkUpkeep + performUpkeep) */
    /* =================================================== */

    function test_integration_checkUpkeepThenPerformUpkeep() external {
        baseEmissionsControllerMock.setCurrentEpoch(5);
        baseEmissionsControllerMock.setEpochMintedAmount(5, 0);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");
        assertTrue(upkeepNeeded);

        vm.prank(upkeeper);
        adapter.performUpkeep(performData);

        assertTrue(baseEmissionsControllerMock.mintAndBridgeCurrentEpochCalled());

        (bool upkeepNeededAfter,) = adapter.checkUpkeep("");
        assertFalse(upkeepNeededAfter);
    }

    function testFuzz_integration_checkUpkeepThenPerformUpkeep(uint256 epoch) external {
        epoch = bound(epoch, 1, type(uint128).max);

        baseEmissionsControllerMock.setCurrentEpoch(epoch);
        baseEmissionsControllerMock.setEpochMintedAmount(epoch, 0);

        (bool upkeepNeeded, bytes memory performData) = adapter.checkUpkeep("");
        assertTrue(upkeepNeeded);

        vm.prank(upkeeper);
        adapter.performUpkeep(performData);

        (bool upkeepNeededAfter,) = adapter.checkUpkeep("");
        assertFalse(upkeepNeededAfter);
    }
}
