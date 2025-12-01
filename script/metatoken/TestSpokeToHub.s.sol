// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MetaERC20Spoke } from "src/external/caldera/MetaERC20Spoke.sol";

/*
LOCAL
forge script script/metatoken/TestSpokeToHub.s.sol:TestSpokeToHub \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url anvil \
  --broadcast \
  --slow

TESTNET
forge script script/metatoken/TestSpokeToHub.s.sol:TestSpokeToHub \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url intuition_sepolia \
  --broadcast \
  --slow \
  --verify \
  --chain 13579 \
  --verifier blockscout \
  --verifier-url "https://intuition-testnet.explorer.caldera.xyz/api/"

MAINNET
forge script script/metatoken/TestSpokeToHub.s.sol:TestSpokeToHub \
  --via-ir \
  --optimizer-runs 10000 \
  --rpc-url intuition \
  --broadcast \
  --slow \
  --verify \
  --chain 1155 \
  --verifier blockscout \
  --verifier-url "https://intuition.calderaexplorer.xyz/api/"
*/

contract TestSpokeToHub is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    /// @notice Metalayer domain ID of Base hub
    uint32 public constant HUB_DOMAIN = 8453;

    /// @notice Deployed spoke proxy address on Intuition L3
    address public constant SPOKE_PROXY = 0xf773031Ac1b5F6041d823704E1338b69b56E6D23;

    /// @notice Recipient on Base (will receive unlocked canonical USDC)
    address public constant HUB_RECIPIENT = 0xB8e3452E62B45e654a300a296061597E3Cf3e039;

    /// @notice Test amount to send back: 0.1 USDC
    uint256 public constant TEST_AMOUNT = 1e5;

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 1155 && block.chainid != 13_579 && block.chainid != 31_337) {
            revert("This script must be run on Intuition, Intuition Sepolia or Anvil");
        }

        if (SPOKE_PROXY == address(0) || HUB_RECIPIENT == address(0)) {
            revert("SPOKE_PROXY and HUB_RECIPIENT must be set");
        }

        MetaERC20Spoke spoke = MetaERC20Spoke(SPOKE_PROXY);

        uint256 gasFee = spoke.quoteTransferRemote(
            HUB_DOMAIN,
            bytes32(uint256(uint160(HUB_RECIPIENT))), // addressToBytes32
            TEST_AMOUNT
        );

        console2.log("Calling spoke.transferRemote to send back to Base hub...");
        spoke.transferRemote{ value: gasFee }(
            HUB_DOMAIN,
            bytes32(uint256(uint160(HUB_RECIPIENT))), // addressToBytes32
            TEST_AMOUNT
        );

        console2.log("Spoke -> Hub transfer initiated:");
        console2.log("Spoke proxy:", SPOKE_PROXY);
        console2.log("Hub domain:", HUB_DOMAIN);
        console2.log("Hub recipient:", HUB_RECIPIENT);
        console2.log("Amount (USDC):", TEST_AMOUNT);
        console2.log("Gas fee (TRUST):", gasFee);

        vm.stopBroadcast();
    }
}
