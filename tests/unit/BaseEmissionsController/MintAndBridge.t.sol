// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MetalayerRouterMock, IIGPMock, MetaERC20HubOrSpokeMock } from "tests/mocks/MetalayerRouterMock.sol";

/// @dev forge test --match-path 'tests/unit/BaseEmissionsController/MintAndBridge.t.sol'
contract MintAndBridgeTest is BaseTest {
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
    uint256 internal constant GAS_QUOTE = 0.025 ether;

    // Test addresses
    address public unauthorizedUser = address(0x999);
    address public satelliteController = address(0x888);

    // Role constants
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Events to test
    event TrustMintedAndBridged(address indexed to, uint256 amount, uint256 epoch);

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        _deployBaseEmissionsController();
        vm.deal(unauthorizedUser, 1 ether);
        vm.deal(users.controller, 10 ether);
    }

    function _deployBaseEmissionsController() internal {
        // Deploy BaseEmissionsController implementation
        BaseEmissionsController baseEmissionsControllerImpl = new BaseEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy baseEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(baseEmissionsControllerImpl), users.admin, "");

        baseEmissionsController = BaseEmissionsController(address(baseEmissionsControllerProxy));

        IIGPMock IIGP = new IIGPMock();
        MetalayerRouterMock metaERC20Router = new MetalayerRouterMock(address(IIGP));
        MetaERC20HubOrSpokeMock metaERC20HubOrSpoke = new MetaERC20HubOrSpokeMock(address(metaERC20Router));

        // Initialize the contract
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: address(metaERC20HubOrSpoke), // Mock meta spoke
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

        protocol.trust.grantRole(protocol.trust.CONTROLLER_ROLE(), address(baseEmissionsController));

        vm.label(address(baseEmissionsController), "BaseEmissionsController");
    }

    /* =================================================== */
    /*              SUCCESSFUL MINT AND BRIDGE            */
    /* =================================================== */

    function test_mintAndBridge_successfulMinting_epoch0() external {
        // Set time to epoch 0
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(0);
        assertEq(expectedEmissions, TEST_EMISSIONS_PER_EPOCH, "Should have base emissions for epoch 0");

        uint256 trustBalanceBefore = protocol.trust.balanceOf(address(baseEmissionsController));
        uint256 totalMintedBefore = baseEmissionsController.getTotalMinted();
        uint256 epochMintedBefore = baseEmissionsController.getEpochMintedAmount(0);

        assertEq(trustBalanceBefore, 0, "Should start with no trust tokens");
        assertEq(totalMintedBefore, 0, "Should start with no minted total");
        assertEq(epochMintedBefore, 0, "Should start with no minted for epoch");

        vm.expectEmit(true, false, false, true);
        emit TrustMintedAndBridged(address(satelliteController), expectedEmissions, 0);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        // Verify state changes
        uint256 totalMintedAfter = baseEmissionsController.getTotalMinted();
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(0);

        assertEq(totalMintedAfter, expectedEmissions, "Total minted should equal expected emissions");
        assertEq(epochMintedAfter, expectedEmissions, "Epoch minted should equal expected emissions");
    }

    function test_mintAndBridge_successfulMinting_laterEpoch() external {
        // Set time to epoch 2
        vm.warp(TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(2);
        assertEq(expectedEmissions, TEST_EMISSIONS_PER_EPOCH, "Should have base emissions for epoch 2");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(2);

        // Verify state changes
        uint256 totalMintedAfter = baseEmissionsController.getTotalMinted();
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(2);

        assertEq(totalMintedAfter, expectedEmissions, "Total minted should equal expected emissions");
        assertEq(epochMintedAfter, expectedEmissions, "Epoch minted should equal expected emissions");

        // Verify other epochs remain 0
        assertEq(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should remain unminted");
        assertEq(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should remain unminted");
    }

    function test_mintAndBridge_successfulMinting_afterCliff() external {
        // Set time to epoch at first reduction cliff
        vm.warp(TEST_START_TIMESTAMP + (TEST_REDUCTION_CLIFF * TEST_EPOCH_LENGTH) + 1 days);

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF);
        assertEq(expectedEmissions, 900_000 * 1e18, "Should have reduced emissions after cliff");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(TEST_REDUCTION_CLIFF);

        // Verify reduced emissions were minted
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(TEST_REDUCTION_CLIFF);
        assertEq(epochMintedAfter, expectedEmissions, "Should mint reduced emissions amount");
    }

    function test_mintAndBridge_successfulMinting_multipleEpochs() external {
        // Set time to epoch 3
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 runningTotal = 0;

        // Mint for epochs 0, 1, 2 sequentially
        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(i);
            runningTotal += expectedEmissions;

            resetPrank(users.controller);
            baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(i);

            assertEq(
                baseEmissionsController.getEpochMintedAmount(i),
                expectedEmissions,
                "Each epoch should have correct minted amount"
            );
            assertEq(baseEmissionsController.getTotalMinted(), runningTotal, "Total should accumulate correctly");
        }
    }

    function test_mintAndBridge_gasRefund() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 excessGas = GAS_QUOTE * 2; // Send double the required gas
        uint256 controllerBalanceBefore = users.controller.balance;

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: excessGas }(0);

        uint256 controllerBalanceAfter = users.controller.balance;
        uint256 gasUsed = controllerBalanceBefore - controllerBalanceAfter;

        assertLt(gasUsed, excessGas, "Should refund excess gas");
        assertGe(gasUsed, GAS_QUOTE, "Should use at least the minimum required gas");
    }

    /* =================================================== */
    /*              FAILED MINT AND BRIDGE TESTS          */
    /* =================================================== */

    function test_mintAndBridge_revertWhen_unauthorized() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, CONTROLLER_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);
    }

    function test_mintAndBridge_revertWhen_adminRole() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Even admin cannot call this function, only controller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.admin, CONTROLLER_ROLE
            )
        );

        resetPrank(users.admin);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);
    }

    function test_mintAndBridge_revertWhen_futureEpoch() external {
        // Set time to epoch 2
        vm.warp(TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH) + 1 days);

        // Try to mint for epoch 3 (future)
        vm.expectRevert(abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidEpoch.selector));

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(3);

        // Try to mint for epoch 10 (far future)
        vm.expectRevert(abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InvalidEpoch.selector));

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(10);
    }

    function test_mintAndBridge_revertWhen_epochAlreadyMinted() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // First mint should succeed
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        // Second mint for same epoch should fail
        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_EpochMintingLimitExceeded.selector)
        );

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);
    }

    function test_mintAndBridge_revertWhen_insufficientGasPayment() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InsufficientGasPayment.selector)
        );

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE / 2 }(0); // Insufficient gas
    }

    function test_mintAndBridge_revertWhen_zeroGasPayment() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_InsufficientGasPayment.selector)
        );

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: 0 }(0);
    }

    /* =================================================== */
    /*              EDGE CASE TESTS                       */
    /* =================================================== */

    function test_mintAndBridge_currentEpoch() external {
        // Set time exactly at epoch 3 start
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH));

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 3, "Should be in epoch 3");

        // Should be able to mint for current epoch
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(3);

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(3);
        assertGt(epochMinted, 0, "Should have minted for current epoch");
    }

    function test_mintAndBridge_exactGasPayment() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Calculate exact gas needed (this is approximate, actual implementation may differ)
        uint256 exactGas = GAS_QUOTE;

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: exactGas }(0);

        // Should succeed with exact gas payment
        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Should have minted with exact gas");
    }

    function test_mintAndBridge_oldEpoch() external {
        // Set time to epoch 5
        vm.warp(TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH) + 1 days);

        // Should be able to mint for old epoch 1
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(1);

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(1);
        assertEq(epochMinted, TEST_EMISSIONS_PER_EPOCH, "Should mint old epoch emissions");
    }

    function test_mintAndBridge_veryLargeEpoch() external {
        // Set time to far future - year 2030
        uint256 futureTime = TEST_START_TIMESTAMP + (365 * 8 * 24 * 60 * 60); // ~8 years
        vm.warp(futureTime);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertGt(currentEpoch, 100, "Should be in a high epoch number");

        // Try to mint for very high epoch - should have very reduced emissions
        uint256 highEpoch = currentEpoch - 1; // Just to be safe it's not future
        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(highEpoch);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(highEpoch);

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(highEpoch);
        assertEq(epochMinted, expectedEmissions, "Should mint reduced emissions for high epoch");
        assertLt(epochMinted, TEST_EMISSIONS_PER_EPOCH, "High epoch emissions should be reduced");
    }

    function test_mintAndBridge_multipleEpochsNonSequential() external {
        // Set time to epoch 5
        vm.warp(TEST_START_TIMESTAMP + (5 * TEST_EPOCH_LENGTH) + 1 days);

        // Mint for epochs 0, 3, 1, 4, 2 in non-sequential order
        uint256[] memory epochs = new uint256[](5);
        epochs[0] = 0;
        epochs[1] = 3;
        epochs[2] = 1;
        epochs[3] = 4;
        epochs[4] = 2;

        uint256 expectedTotal = 0;

        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 epoch = epochs[i];
            uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(epoch);
            expectedTotal += expectedEmissions;

            resetPrank(users.controller);
            baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(epoch);

            assertEq(
                baseEmissionsController.getEpochMintedAmount(epoch),
                expectedEmissions,
                "Each epoch should have correct amount minted"
            );
        }

        assertEq(baseEmissionsController.getTotalMinted(), expectedTotal, "Total minted should equal sum of all epochs");
    }

    /* =================================================== */
    /*              STATE VERIFICATION TESTS              */
    /* =================================================== */

    function test_mintAndBridge_stateConsistency() external {
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days);

        // Mint for epoch 2
        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(2);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(2);

        // Verify all state variables are consistent
        assertEq(baseEmissionsController.getTotalMinted(), expectedEmissions, "Total minted should match");
        assertEq(baseEmissionsController.getEpochMintedAmount(2), expectedEmissions, "Epoch amount should match");

        // Other epochs should remain 0
        assertEq(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should be 0");
        assertEq(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should be 0");
        assertEq(baseEmissionsController.getEpochMintedAmount(3), 0, "Epoch 3 should be 0");
    }

    function test_mintAndBridge_emissionsCalculationAccuracy() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Get expected emissions from view function
        uint256 expectedFromView = baseEmissionsController.getEmissionsAtEpoch(0);
        uint256 expectedFromCurrent = baseEmissionsController.getCurrentEpochEmissions();

        assertEq(expectedFromView, expectedFromCurrent, "View functions should agree");
        assertEq(expectedFromView, TEST_EMISSIONS_PER_EPOCH, "Should equal base emissions");

        // Mint and verify actual minted amount matches expectation
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        uint256 actualMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertEq(actualMinted, expectedFromView, "Actual minted should match expected");
    }

    function test_mintAndBridge_tokenApprovalAndBalance() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 trustSupplyBefore = protocol.trust.totalSupply();
        uint256 controllerBalanceBefore = protocol.trust.balanceOf(address(baseEmissionsController));

        assertEq(controllerBalanceBefore, 0, "Controller should start with 0 tokens");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        uint256 trustSupplyAfter = protocol.trust.totalSupply();
        uint256 expectedEmissions = TEST_EMISSIONS_PER_EPOCH;

        // Total supply should have increased
        assertEq(
            trustSupplyAfter, trustSupplyBefore + expectedEmissions, "Total supply should increase by minted amount"
        );
    }

    /* =================================================== */
    /*              BOUNDARY VALUE TESTS                  */
    /* =================================================== */

    function test_mintAndBridge_boundaryValues_zeroEpoch() external {
        vm.warp(TEST_START_TIMESTAMP);

        // At exactly start timestamp, should be epoch 0
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0, "Should be epoch 0 at start");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Should mint for epoch 0");
    }

    function test_mintAndBridge_boundaryValues_epochTransition() external {
        // Set time to exactly epoch boundary (start of epoch 1)
        vm.warp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 1, "Should be epoch 1 at boundary");

        // Should be able to mint for both epoch 0 and 1
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(1);

        assertGt(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should be minted");
        assertGt(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should be minted");
    }

    function test_mintAndBridge_rolePermissions() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Test that only CONTROLLER_ROLE can call
        address[] memory testUsers = new address[](3);
        testUsers[0] = users.admin;
        testUsers[1] = unauthorizedUser;
        testUsers[2] = users.alice;

        for (uint256 i = 0; i < testUsers.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, testUsers[i], CONTROLLER_ROLE
                )
            );

            resetPrank(testUsers[i]);
            baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);
        }

        // But controller should succeed
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(0);

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Controller should successfully mint");
    }
}
