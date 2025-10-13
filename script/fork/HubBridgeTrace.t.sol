// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { HubBridge } from "tests/testnet/HubBridge.sol";
import { FinalityState, IMetaERC20HubOrSpoke, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

/**
@notice Fork test for HubBridge with vm.prank support

Run with:
forge test --match-contract HubBridgeTraceTest --fork-url https://mainnet.base.org -vvvv

Or test specific function:
forge test --match-test test_bridge_withPrank --fork-url https://mainnet.base.org -vvvv
*/
contract HubBridgeTraceTest is Test {
    // Network constants
    uint32 public constant BASE_CHAIN_ID = 8453;
    uint32 public constant INTUITION_CHAIN_ID = 1155;
    uint256 public constant GAS_CONSTANT = 100_000;
    uint256 public constant GAS_LIMIT = GAS_CONSTANT + 125_000;

    // Contract addresses
    uint256 public bridgeAmount = 1e18;
    address public hubBridge = 0xfdAe6ae4Ca946746CB7470570BbC95c71e1952A1; // Set this to deployed HubBridge address
    address public testToken = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address public testSender = 0x4905e138b507F5Da41e894aF80672b1ecB167C3E;
    address public testRecipient = 0x4905e138b507F5Da41e894aF80672b1ecB167C3E;

    function setUp() public {
        // Validate fork
        require(block.chainid == BASE_CHAIN_ID, "Must run on Base fork");

        // Give test sender some ETH for gas if needed
        vm.deal(testSender, 10 ether);
    }

    /**
     * @notice Test bridge operation with vm.prank
     */
    function test_bridge_withPrank() public {
        require(hubBridge != address(0), "HubBridge address not set");

        console2.log("=== HubBridge Fork Test with vm.prank ===");
        console2.log("Test Sender:", testSender);
        console2.log("HubBridge:", hubBridge);
        console2.log("Test Token:", testToken);
        console2.log("Recipient:", testRecipient);

        IERC20 token = IERC20(testToken);
        HubBridge bridge = HubBridge(payable(hubBridge));

        // Check sender balance
        uint256 senderBalance = token.balanceOf(testSender);
        console2.log("Sender Balance:", senderBalance);
        require(senderBalance >= bridgeAmount, "Insufficient token balance");

        // Get gas quote
        uint256 gasQuote = bridge.quoteGasPayment(INTUITION_CHAIN_ID, GAS_LIMIT);
        console2.log("Gas Quote:", gasQuote);

        // Prank as test sender and approve tokens
        vm.startPrank(testSender);

        bool approved = token.approve(hubBridge, bridgeAmount);
        require(approved, "Token approval failed");
        console2.log("Tokens approved");

        // Execute bridge
        console2.log("Executing bridge...");
        bridge.bridge{ value: gasQuote }(testRecipient, bridgeAmount);

        vm.stopPrank();

        console2.log("Bridge successful!");
        console2.log("Final sender balance:", token.balanceOf(testSender));
    }

    /**
     * @notice Test bridge with custom sender address
     */
    function test_bridge_customSender(address sender, uint256 amount) public {
        require(hubBridge != address(0), "HubBridge address not set");

        // Bound inputs
        vm.assume(sender != address(0));
        amount = bound(amount, 1e15, 100e18); // 0.001 to 100 tokens

        console2.log("Testing with custom sender:", sender);

        IERC20 token = IERC20(testToken);
        HubBridge bridge = HubBridge(payable(hubBridge));

        // Deal sender some tokens for testing (if token supports it)
        vm.deal(sender, 10 ether);

        // Get required balance
        uint256 senderBalance = token.balanceOf(sender);
        if (senderBalance < amount) {
            console2.log("Sender has insufficient balance, skipping");
            vm.skip(true);
            return;
        }

        uint256 gasQuote = bridge.quoteGasPayment(INTUITION_CHAIN_ID, GAS_LIMIT);

        vm.startPrank(sender);
        token.approve(hubBridge, amount);
        bridge.bridge{ value: gasQuote }(testRecipient, amount);
        vm.stopPrank();

        console2.log("Bridge successful with amount:", amount);
    }
}
