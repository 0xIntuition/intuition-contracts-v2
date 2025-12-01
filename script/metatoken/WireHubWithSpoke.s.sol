// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MetaERC20Hub } from "src/external/caldera/MetaERC20Hub.sol";

/*
LOCAL
forge script script/metatoken/WireHubWithSpoke.s.sol:WireHubWithSpoke \
--via-ir \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/metatoken/WireHubWithSpoke.s.sol:WireHubWithSpoke \
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
forge script script/metatoken/WireHubWithSpoke.s.sol:WireHubWithSpoke \
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

contract WireHubWithSpoke is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    // Domain ID of Intuition L3 spoke
    uint32 public constant SPOKE_DOMAIN = 1155;

    // Deployed hub proxy address on Base
    address public constant HUB_PROXY = 0x41e7c242e22D6166D7e19C24eBBE5ACEe5E6c862; // TODO: Address of deployed hub
    // proxy

    // Deployed spoke proxy address on Intuition L3
    address public constant SPOKE_PROXY = 0xf773031Ac1b5F6041d823704E1338b69b56E6D23; // TODO: Address of deployed spoke
    // proxy

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 8453 && block.chainid != 84_532 && block.chainid != 31_337) {
            revert("This script must be run on Base, Base Sepolia or Anvil");
        }

        if (HUB_PROXY == address(0) || SPOKE_PROXY == address(0)) {
            revert("HUB_PROXY and SPOKE_PROXY must be set");
        }

        MetaERC20Hub hub = MetaERC20Hub(HUB_PROXY);

        uint32[] memory domains = new uint32[](1);
        domains[0] = SPOKE_DOMAIN;

        bytes32[] memory addresses = new bytes32[](1);
        // Same as AddressHelper.addressToBytes32(spokeAddress)
        addresses[0] = bytes32(uint256(uint160(SPOKE_PROXY)));

        hub.setDomainAddressBatch(domains, addresses);

        console2.log("Registered spoke on hub:");
        console2.log("Domain:", SPOKE_DOMAIN);
        console2.log("Address:", SPOKE_PROXY);

        vm.stopBroadcast();
    }
}
