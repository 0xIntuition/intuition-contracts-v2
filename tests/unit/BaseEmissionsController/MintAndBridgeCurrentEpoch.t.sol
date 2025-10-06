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

/// @dev forge test --match-path 'tests/unit/BaseEmissionsController/MintAndBridgeCurrentEpoch.t.sol'
contract MintAndBridgeCurrentEpochTest is BaseTest {
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
        vm.deal(address(baseEmissionsController), 100 ether);
        // Set BaseEmissionsController directly in Trust storage slot
        vm.store(
            address(protocol.trust), bytes32(uint256(203)), bytes32(uint256(uint160(address(baseEmissionsController))))
        );
    }

    function _deployBaseEmissionsController() internal {
        // Deploy BaseEmissionsController implementation
        BaseEmissionsController baseEmissionsControllerImpl = new BaseEmissionsController();

        // Deploy proxy
        TransparentUpgradeableProxy baseEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(baseEmissionsControllerImpl), users.admin, "");

        baseEmissionsController = BaseEmissionsController(payable(baseEmissionsControllerProxy));

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

        vm.label(address(baseEmissionsController), "BaseEmissionsController");

        vm.stopPrank();

        // Set the satellite controller address
        vm.prank(users.admin);
        baseEmissionsController.setSatelliteEmissionsController(satelliteController);
    }

    /* =================================================== */
    /*        SUCCESSFUL MINT AND BRIDGE CURRENT EPOCH    */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_successfulMinting_epoch0() external {
        // Set time to epoch 0
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0, "Should be in epoch 0");

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
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        // Verify state changes
        uint256 totalMintedAfter = baseEmissionsController.getTotalMinted();
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(0);

        assertEq(totalMintedAfter, expectedEmissions, "Total minted should equal expected emissions");
        assertEq(epochMintedAfter, expectedEmissions, "Epoch minted should equal expected emissions");
    }

    function test_mintAndBridgeCurrentEpoch_successfulMinting_laterEpoch() external {
        // Set time to epoch 2
        vm.warp(TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 2, "Should be in epoch 2");

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(2);
        assertEq(expectedEmissions, TEST_EMISSIONS_PER_EPOCH, "Should have base emissions for epoch 2");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        // Verify state changes
        uint256 totalMintedAfter = baseEmissionsController.getTotalMinted();
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(2);

        assertEq(totalMintedAfter, expectedEmissions, "Total minted should equal expected emissions");
        assertEq(epochMintedAfter, expectedEmissions, "Epoch minted should equal expected emissions");

        // Verify other epochs remain 0
        assertEq(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should remain unminted");
        assertEq(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should remain unminted");
    }

    function test_mintAndBridgeCurrentEpoch_successfulMinting_afterCliff() external {
        // Set time to epoch at first reduction cliff
        vm.warp(TEST_START_TIMESTAMP + (TEST_REDUCTION_CLIFF * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, TEST_REDUCTION_CLIFF, "Should be at reduction cliff epoch");

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(TEST_REDUCTION_CLIFF);
        assertEq(expectedEmissions, 900_000 * 1e18, "Should have reduced emissions after cliff");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        // Verify reduced emissions were minted
        uint256 epochMintedAfter = baseEmissionsController.getEpochMintedAmount(TEST_REDUCTION_CLIFF);
        assertEq(epochMintedAfter, expectedEmissions, "Should mint reduced emissions amount");
    }

    function test_mintAndBridgeCurrentEpoch_successfulMinting_multipleEpochsSequential() external {
        // Start at epoch 0
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 runningTotal = 0;

        // Mint for epochs 0, 1, 2 sequentially by advancing time
        for (uint256 i = 0; i < 3; i++) {
            uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
            assertEq(currentEpoch, i, "Should be in correct epoch");

            uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(i);
            runningTotal += expectedEmissions;

            resetPrank(users.controller);
            baseEmissionsController.mintAndBridgeCurrentEpoch();

            assertEq(
                baseEmissionsController.getEpochMintedAmount(i),
                expectedEmissions,
                "Each epoch should have correct minted amount"
            );
            assertEq(baseEmissionsController.getTotalMinted(), runningTotal, "Total should accumulate correctly");

            // Move to next epoch
            if (i < 2) {
                vm.warp(TEST_START_TIMESTAMP + ((i + 1) * TEST_EPOCH_LENGTH) + 1 days);
            }
        }
    }

    function test_mintAndBridgeCurrentEpoch_usesContractBalance() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 contractBalanceBefore = address(baseEmissionsController).balance;
        assertGt(contractBalanceBefore, 0, "Contract should have ETH balance from setup");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 contractBalanceAfter = address(baseEmissionsController).balance;
        assertLt(contractBalanceAfter, contractBalanceBefore, "Contract balance should decrease after bridging");

        // Verify state changes
        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Should have minted for current epoch");
    }

    /* =================================================== */
    /*        FAILED MINT AND BRIDGE CURRENT EPOCH TESTS  */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_revertWhen_satelliteEmissionsControllerNotSet() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Set satellite emissions controller to zero address by directly manipulating storage
        vm.store(address(baseEmissionsController), bytes32(uint256(108)), bytes32(0));

        resetPrank(users.controller);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseEmissionsController.BaseEmissionsController_SatelliteEmissionsControllerNotSet.selector
            )
        );
        baseEmissionsController.mintAndBridgeCurrentEpoch();
    }

    function test_mintAndBridgeCurrentEpoch_revertWhen_unauthorized() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedUser, CONTROLLER_ROLE
            )
        );

        resetPrank(unauthorizedUser);
        baseEmissionsController.mintAndBridgeCurrentEpoch();
    }

    function test_mintAndBridgeCurrentEpoch_revertWhen_adminRole() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Even admin cannot call this function, only controller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.admin, CONTROLLER_ROLE
            )
        );

        resetPrank(users.admin);
        baseEmissionsController.mintAndBridgeCurrentEpoch();
    }

    function test_mintAndBridgeCurrentEpoch_revertWhen_epochAlreadyMinted() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // First mint should succeed
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        // Second mint for same epoch should fail
        vm.expectRevert(
            abi.encodeWithSelector(IBaseEmissionsController.BaseEmissionsController_EpochMintingLimitExceeded.selector)
        );

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();
    }

    function test_mintAndBridgeCurrentEpoch_revertWhen_insufficientContractBalance() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        // Drain the contract balance
        vm.prank(users.admin);
        baseEmissionsController.withdraw(address(baseEmissionsController).balance);

        assertEq(address(baseEmissionsController).balance, 0, "Contract should have no ETH balance");

        resetPrank(users.controller);
        vm.expectRevert();
        baseEmissionsController.mintAndBridgeCurrentEpoch();
    }

    /* =================================================== */
    /*              EDGE CASE TESTS                       */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_exactlyAtEpochStart() external {
        // Set time exactly at epoch 3 start
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH));

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 3, "Should be in epoch 3");

        // Should be able to mint for current epoch
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(3);
        assertGt(epochMinted, 0, "Should have minted for current epoch");
    }

    function test_mintAndBridgeCurrentEpoch_veryLateEpoch() external {
        // Set time to far future - year 2030
        uint256 futureTime = TEST_START_TIMESTAMP + (365 * 8 * 24 * 60 * 60); // ~8 years
        vm.warp(futureTime);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertGt(currentEpoch, 100, "Should be in a high epoch number");

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(currentEpoch);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(currentEpoch);
        assertEq(epochMinted, expectedEmissions, "Should mint reduced emissions for high epoch");
        assertLt(epochMinted, TEST_EMISSIONS_PER_EPOCH, "High epoch emissions should be reduced");
    }

    function test_mintAndBridgeCurrentEpoch_epochBoundary() external {
        // Set time to exactly epoch boundary (start of epoch 1)
        vm.warp(TEST_START_TIMESTAMP + TEST_EPOCH_LENGTH);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 1, "Should be epoch 1 at boundary");

        // Should mint for epoch 1 (current epoch)
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        assertGt(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should be minted");
        assertEq(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should not be minted");
    }

    /* =================================================== */
    /*              STATE VERIFICATION TESTS              */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_stateConsistency() external {
        vm.warp(TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 2, "Should be in epoch 2");

        // Mint for current epoch
        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(2);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        // Verify all state variables are consistent
        assertEq(baseEmissionsController.getTotalMinted(), expectedEmissions, "Total minted should match");
        assertEq(baseEmissionsController.getEpochMintedAmount(2), expectedEmissions, "Epoch amount should match");

        // Other epochs should remain 0
        assertEq(baseEmissionsController.getEpochMintedAmount(0), 0, "Epoch 0 should be 0");
        assertEq(baseEmissionsController.getEpochMintedAmount(1), 0, "Epoch 1 should be 0");
        assertEq(baseEmissionsController.getEpochMintedAmount(3), 0, "Epoch 3 should be 0");
    }

    function test_mintAndBridgeCurrentEpoch_emissionsCalculationAccuracy() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0, "Should be in epoch 0");

        // Get expected emissions from view function
        uint256 expectedFromView = baseEmissionsController.getEmissionsAtEpoch(0);
        uint256 expectedFromCurrent = baseEmissionsController.getCurrentEpochEmissions();

        assertEq(expectedFromView, expectedFromCurrent, "View functions should agree");
        assertEq(expectedFromView, TEST_EMISSIONS_PER_EPOCH, "Should equal base emissions");

        // Mint and verify actual minted amount matches expectation
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 actualMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertEq(actualMinted, expectedFromView, "Actual minted should match expected");
    }

    function test_mintAndBridgeCurrentEpoch_tokenSupplyIncrease() external {
        vm.warp(TEST_START_TIMESTAMP + 1 days);

        uint256 trustSupplyBefore = protocol.trust.totalSupply();
        uint256 expectedEmissions = TEST_EMISSIONS_PER_EPOCH;

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 trustSupplyAfter = protocol.trust.totalSupply();

        // Total supply should have increased
        assertEq(
            trustSupplyAfter, trustSupplyBefore + expectedEmissions, "Total supply should increase by minted amount"
        );
    }

    /* =================================================== */
    /*              BOUNDARY VALUE TESTS                  */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_boundaryValues_zeroEpoch() external {
        vm.warp(TEST_START_TIMESTAMP);

        // At exactly start timestamp, should be epoch 0
        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 0, "Should be epoch 0 at start");

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Should mint for epoch 0");
    }

    function test_mintAndBridgeCurrentEpoch_rolePermissions() external {
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
            baseEmissionsController.mintAndBridgeCurrentEpoch();
        }

        // But controller should succeed
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(0);
        assertGt(epochMinted, 0, "Controller should successfully mint");
    }

    /* =================================================== */
    /*        COMPARISON WITH MINTANDBRIDGE TESTS         */
    /* =================================================== */

    function test_mintAndBridgeCurrentEpoch_vs_mintAndBridge_sameResult() external {
        vm.warp(TEST_START_TIMESTAMP + (2 * TEST_EPOCH_LENGTH) + 1 days);

        uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
        assertEq(currentEpoch, 2, "Should be in epoch 2");

        uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(2);

        // Use mintAndBridgeCurrentEpoch
        resetPrank(users.controller);
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 epoch2Minted = baseEmissionsController.getEpochMintedAmount(2);
        assertEq(epoch2Minted, expectedEmissions, "Should mint expected amount");

        // Move to next epoch and use mintAndBridge with explicit epoch
        vm.warp(TEST_START_TIMESTAMP + (3 * TEST_EPOCH_LENGTH) + 1 days);

        resetPrank(users.controller);
        baseEmissionsController.mintAndBridge{ value: GAS_QUOTE }(3);

        uint256 epoch3Minted = baseEmissionsController.getEpochMintedAmount(3);
        assertEq(epoch3Minted, expectedEmissions, "Both methods should mint same amount per epoch");

        // Total should be sum of both
        assertEq(
            baseEmissionsController.getTotalMinted(),
            epoch2Minted + epoch3Minted,
            "Total should be sum of both mints"
        );
    }

    function test_mintAndBridgeCurrentEpoch_multipleReductionCliffs() external {
        // Test emissions at multiple reduction cliffs
        uint256[] memory cliffEpochs = new uint256[](3);
        cliffEpochs[0] = TEST_REDUCTION_CLIFF; // First cliff
        cliffEpochs[1] = TEST_REDUCTION_CLIFF * 2; // Second cliff
        cliffEpochs[2] = TEST_REDUCTION_CLIFF * 3; // Third cliff

        uint256 totalMinted = 0;

        for (uint256 i = 0; i < cliffEpochs.length; i++) {
            uint256 epoch = cliffEpochs[i];
            vm.warp(TEST_START_TIMESTAMP + (epoch * TEST_EPOCH_LENGTH) + 1 days);

            uint256 currentEpoch = baseEmissionsController.getCurrentEpoch();
            assertEq(currentEpoch, epoch, "Should be at correct cliff epoch");

            uint256 expectedEmissions = baseEmissionsController.getEmissionsAtEpoch(epoch);

            resetPrank(users.controller);
            baseEmissionsController.mintAndBridgeCurrentEpoch();

            totalMinted += expectedEmissions;

            uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(epoch);
            assertEq(epochMinted, expectedEmissions, "Should mint correct reduced amount at cliff");
            assertLt(expectedEmissions, TEST_EMISSIONS_PER_EPOCH, "Should be reduced emissions");
        }

        assertEq(baseEmissionsController.getTotalMinted(), totalMinted, "Total should match accumulated mints");
    }
}
