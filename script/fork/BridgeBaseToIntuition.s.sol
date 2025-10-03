// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import { Script, console2 } from "forge-std/src/Script.sol";
import { SetupScript } from "../SetupScript.s.sol";
import { Test } from "forge-std/src/Test.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
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
forge script script/fork/BridgeBaseToIntuition.s.sol:BridgeBaseToIntuition \
--fork-url https://sepolia.base.org \
-vvvv

forge script script/fork/BridgeBaseToIntuition.s.sol:BridgeBaseToIntuition \
--fork-url https://sepolia.base.org \
--sig "runForkTest()" \
-vvvv
 */
contract BridgeBaseToIntuition is SetupScript, Test {
    // Network constants
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint32 public constant INTUITION_SEPOLIA_CHAIN_ID = 13_579;

    uint256 public constant GAS_CONSTANT = 100_000;
    uint256 public constant GAS_LIMIT = GAS_CONSTANT + 125_000;

    // Contract addresses (to be set via environment variables or constructor)
    address public metaERC20Hub = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5;
    address public testToken = 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210;
    address public testRecipient = 0x395867a085228940cA50a26166FDAD3f382aeB09;
    uint256 public bridgeAmount = 1e18; // Default to 1 token (assuming 18 decimals)

    /**
     * @notice Main script function for standard execution
     */
    function run() public broadcast {
        _validateSetup();
        _executeBridge();
    }

    /**
     * @notice Fork test function that can be called with detailed logging
     */
    function runForkTest() public broadcast {
        console2.log("=== BridgeBaseToIntuition Fork Test ===");
        console2.log("Base Sepolia Chain ID:", BASE_SEPOLIA_CHAIN_ID);
        console2.log("Intuition Sepolia Domain:", INTUITION_SEPOLIA_CHAIN_ID);
        console2.log("Current Chain ID:", block.chainid);

        // Validate we're on the correct network
        require(block.chainid == BASE_SEPOLIA_CHAIN_ID, "Must run on Base Sepolia fork");
        _validateSetup();
        _logContractInfo();
        _executeBridge();

        console2.log("=== Fork Test Complete ===");
    }

    /**
     * @notice Executes the bridge operation
     */
    function _executeBridge() internal {
        IERC20 token = IERC20(testToken);
        IMetaERC20HubOrSpoke hub = IMetaERC20HubOrSpoke(metaERC20Hub);

        // Check sender has sufficient balance
        uint256 senderBalance = token.balanceOf(broadcaster);
        require(senderBalance >= bridgeAmount, "Insufficient token balance");

        // Get gas quote
        IIGP igp = IIGP(IMetalayerRouter(hub.metalayerRouter()).igp());
        uint256 gasQuote = igp.quoteGasPayment(INTUITION_SEPOLIA_CHAIN_ID, GAS_LIMIT);
        console2.log("Gas quote (wei):", gasQuote);

        // Ensure sender has enough ETH for gas
        require(broadcaster.balance >= gasQuote, "Insufficient ETH for gas payment");

        // Approve tokens for the hub
        console2.log("Approving tokens...");
        bool approved = token.approve(metaERC20Hub, bridgeAmount);
        require(approved, "Token approval failed");

        // Convert recipient address to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(testRecipient)));

        console2.log("Initiating bridge transfer...");
        // Execute the bridge transfer
        hub.transferRemote{ value: gasQuote }(
            INTUITION_SEPOLIA_CHAIN_ID, recipientBytes32, bridgeAmount, GAS_CONSTANT, FinalityState.INSTANT
        );

        console2.log("Bridge transfer initiated successfully!");
        console2.log("Tokens sent:", bridgeAmount);
        console2.log("Gas paid:", gasQuote);
        console2.log("Recipient (bytes32):", vm.toString(recipientBytes32));
    }

    /**
     * @notice Validates that all required parameters are set
     */
    function _validateSetup() internal view {
        require(metaERC20Hub != address(0), "MetaERC20 Hub address not set");
        require(testToken != address(0), "Test token address not set");
        require(testRecipient != address(0), "Test recipient address not set");
        require(bridgeAmount > 0, "Bridge amount must be greater than 0");
    }

    /**
     * @notice Logs contract information for debugging
     */
    function _logContractInfo() internal view {
        console2.log("MetaERC20 Hub:", metaERC20Hub);
        console2.log("Test Token:", testToken);
        console2.log("Test Recipient:", testRecipient);
        console2.log("Bridge Amount:", bridgeAmount);

        // Log token info
        IERC20 token = IERC20(testToken);
        try token.symbol() returns (string memory symbol) {
            console2.log("Token Symbol:", symbol);
        } catch {
            console2.log("Could not get token symbol");
        }

        try token.decimals() returns (uint8 decimals) {
            console2.log("Token Decimals:", decimals);
        } catch {
            console2.log("Could not get token decimals");
        }

        // Log current balance
        uint256 balance = token.balanceOf(broadcaster);
        console2.log("Sender Balance:", balance);

        // Log MetaERC20Hub info
        IMetaERC20HubOrSpoke hub = IMetaERC20HubOrSpoke(metaERC20Hub);
        address metalayerRouter = hub.metalayerRouter();
        console2.log("Metalayer Router:", metalayerRouter);

        IMetalayerRouter router = IMetalayerRouter(metalayerRouter);
        address igp = router.igp();
        console2.log("IGP:", igp);
    }
}
