// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { SpokeBridge } from "tests/testnet/SpokeBridge.sol";
import { FinalityState, IMetaERC20HubOrSpoke, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

/**
 * @notice Fork test for SpokeBridge with vm.prank support
 *
 * Run with:
 * forge test --match-contract SpokeBridgeTraceTest --fork-url https://rpc.intuition.systems -vvvv
 *
 * Or test specific function:
 * forge test --match-test test_bridge_withPrank --fork-url https://rpc.intuition.systems -vvvv
 */
contract SpokeBridgeTraceTest is Test {
    // Network constants
    uint32 public constant INTUITION_CHAIN_ID = 1155;
    uint32 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant GAS_CONSTANT = 100_000;
    uint256 public constant GAS_LIMIT = GAS_CONSTANT + 125_000;

    // Contract addresses
    address public spokeBridge = 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667; // Set this to deployed SpokeBridge address
    address public testRecipient = 0x395867a085228940cA50a26166FDAD3f382aeB09;
    uint256 public bridgeAmount = 1e18;

    // Test sender - set to an address with ADMIN role on SpokeBridge
    address public testAdmin = 0x4905e138b507F5Da41e894aF80672b1ecB167C3E; // Must be set to actual admin

    function setUp() public {
        // Validate fork
        require(block.chainid == INTUITION_CHAIN_ID, "Must run on Intuition fork");

        // Give test admin some ETH if needed
        if (testAdmin != address(0)) {
            vm.deal(testAdmin, 10 ether);
        }
    }

    /**
     * @notice Test bridge operation with vm.prank
     */
    function test_bridge_withPrank() public {
        require(spokeBridge != address(0), "SpokeBridge address not set");
        require(testAdmin != address(0), "Test admin address not set");

        console2.log("=== SpokeBridge Fork Test with vm.prank ===");
        console2.log("Test Admin:", testAdmin);
        console2.log("SpokeBridge:", spokeBridge);
        console2.log("Recipient:", testRecipient);

        SpokeBridge bridge = SpokeBridge(payable(spokeBridge));

        // Check admin balance
        uint256 adminBalance = testAdmin.balance;
        console2.log("Admin Balance:", adminBalance);

        // Get gas quote from underlying MetaERC20Spoke
        uint256 gasQuote = _getGasQuote(bridge);
        console2.log("Gas Quote:", gasQuote);

        // Calculate total value
        uint256 totalValue = bridgeAmount + gasQuote;
        console2.log("Total Value (bridge + gas):", totalValue);
        require(adminBalance >= totalValue, "Insufficient ETH for bridge + gas");

        // Prank as test admin and bridge
        vm.startPrank(testAdmin);

        console2.log("Executing bridge...");
        bridge.bridge{ value: totalValue }(testRecipient);

        vm.stopPrank();

        console2.log("Bridge successful!");
        console2.log("Final admin balance:", testAdmin.balance);
    }

    /**
     * @notice Test bridge with custom admin address
     */
    function test_bridge_customAdmin(address admin, uint256 amount) public {
        require(spokeBridge != address(0), "SpokeBridge address not set");

        // Bound inputs
        vm.assume(admin != address(0));
        amount = bound(amount, 1e15, 10e18); // 0.001 to 10 ETH

        console2.log("Testing with custom admin:", admin);

        SpokeBridge bridge = SpokeBridge(payable(spokeBridge));

        // Check if admin has role - if not, grant it for testing
        bytes32 adminRole = bridge.DEFAULT_ADMIN_ROLE();
        bool hasAdminRole = bridge.hasRole(adminRole, admin);

        if (!hasAdminRole) {
            console2.log("Admin doesn't have role, skipping");
            vm.skip(true);
            return;
        }

        // Deal admin ETH
        uint256 gasQuote = _getGasQuote(bridge);
        uint256 totalValue = amount + gasQuote;
        vm.deal(admin, totalValue + 1 ether);

        vm.startPrank(admin);
        bridge.bridge{ value: totalValue }(testRecipient);
        vm.stopPrank();

        console2.log("Bridge successful with amount:", amount);
    }

    /**
     * @notice Test that non-admin cannot bridge
     */
    function test_bridge_revertsForNonAdmin() public {
        require(spokeBridge != address(0), "SpokeBridge address not set");

        address nonAdmin = address(0xdead);
        SpokeBridge bridge = SpokeBridge(payable(spokeBridge));

        uint256 gasQuote = _getGasQuote(bridge);
        uint256 totalValue = bridgeAmount + gasQuote;

        vm.deal(nonAdmin, totalValue + 1 ether);

        vm.startPrank(nonAdmin);
        vm.expectRevert(); // Should revert due to access control
        bridge.bridge{ value: totalValue }(testRecipient);
        vm.stopPrank();

        console2.log("Correctly reverted for non-admin");
    }

    /**
     * @notice Test that insufficient value reverts
     */
    function test_bridge_revertsForInsufficientValue() public {
        require(spokeBridge != address(0), "SpokeBridge address not set");
        require(testAdmin != address(0), "Test admin address not set");

        SpokeBridge bridge = SpokeBridge(payable(spokeBridge));

        uint256 gasQuote = _getGasQuote(bridge);
        uint256 insufficientValue = gasQuote; // Only gas, no bridge amount

        vm.deal(testAdmin, insufficientValue + 1 ether);

        vm.startPrank(testAdmin);
        vm.expectRevert(SpokeBridge.NotEnoughValueSent.selector);
        bridge.bridge{ value: insufficientValue }(testRecipient);
        vm.stopPrank();

        console2.log("Correctly reverted for insufficient value");
    }

    /**
     * @notice Helper to get gas quote from underlying MetaERC20Spoke
     * @param bridge The SpokeBridge contract
     * @return Gas quote in wei
     */
    function _getGasQuote(SpokeBridge bridge) internal view returns (uint256) {
        address metaERC20Spoke = bridge.getMetaERC20SpokeOrHub();
        IMetaERC20HubOrSpoke spoke = IMetaERC20HubOrSpoke(metaERC20Spoke);
        address metalayerRouter = spoke.metalayerRouter();
        IMetalayerRouter router = IMetalayerRouter(metalayerRouter);
        IIGP igp = IIGP(router.igp());

        uint256 messageGasCost = bridge.getMessageGasCost();
        return igp.quoteGasPayment(BASE_CHAIN_ID, GAS_CONSTANT + messageGasCost);
    }
}
