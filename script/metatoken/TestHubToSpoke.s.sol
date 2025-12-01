// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MetaERC20Hub } from "src/external/caldera/MetaERC20Hub.sol";

/*
LOCAL
forge script script/metatoken/TestHubToSpoke.s.sol:TestHubToSpoke \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url anvil \
  --broadcast \
  --slow

TESTNET
forge script script/metatoken/TestHubToSpoke.s.sol:TestHubToSpoke \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url base_sepolia \
  --broadcast \
  --slow \
  --verify \
  --chain 84532 \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=84532" \
  --etherscan-api-key $ETHERSCAN_API_KEY

MAINNET
forge script script/metatoken/TestHubToSpoke.s.sol:TestHubToSpoke \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url base \
  --broadcast \
  --slow \
  --verify \
  --chain 8453 \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=8453" \
  --etherscan-api-key $ETHERSCAN_API_KEY
*/

contract TestHubToSpoke is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    /// @notice Metalayer domain ID of Intuition L3 spoke
    uint32 public constant SPOKE_DOMAIN = 1155;

    /// @notice Deployed hub proxy address on Base
    address public constant HUB_PROXY = 0x41e7c242e22D6166D7e19C24eBBE5ACEe5E6c862;

    /// @notice Canonical USDC on Base
    address public constant CANONICAL_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @notice Recipient on Intuition L3 (will receive bridged USDC)
    address public constant SPOKE_RECIPIENT = 0xB8e3452E62B45e654a300a296061597E3Cf3e039;

    /// @notice Test amount: 1 USDC (USDC has 6 decimals)
    uint256 public constant TEST_AMOUNT = 1e6;

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 8453 && block.chainid != 84_532 && block.chainid != 31_337) {
            revert("This script must be run on Base, Base Sepolia or Anvil");
        }

        if (HUB_PROXY == address(0) || CANONICAL_USDC == address(0) || SPOKE_RECIPIENT == address(0)) {
            revert("HUB_PROXY, CANONICAL_USDC and SPOKE_RECIPIENT must be set");
        }

        MetaERC20Hub hub = MetaERC20Hub(HUB_PROXY);
        IERC20 usdc = IERC20(CANONICAL_USDC);

        console2.log("Approving hub to spend USDC...");
        usdc.approve(HUB_PROXY, type(uint256).max);

        uint256 gasFee = hub.quoteTransferRemote(
            SPOKE_DOMAIN,
            bytes32(uint256(uint160(SPOKE_RECIPIENT))), // addressToBytes32
            TEST_AMOUNT
        );

        console2.log("Calling hub.transferRemote...");
        hub.transferRemote{ value: gasFee }(
            SPOKE_DOMAIN,
            bytes32(uint256(uint160(SPOKE_RECIPIENT))), // addressToBytes32
            TEST_AMOUNT
        );

        console2.log("Hub -> Spoke transfer initiated:");
        console2.log("Hub proxy:", HUB_PROXY);
        console2.log("Spoke domain:", SPOKE_DOMAIN);
        console2.log("Spoke recipient:", SPOKE_RECIPIENT);
        console2.log("Amount (USDC):", TEST_AMOUNT);
        console2.log("Gas fee (ETH):", gasFee);

        vm.stopBroadcast();
    }
}
