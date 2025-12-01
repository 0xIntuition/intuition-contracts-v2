// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MetaERC20Spoke } from "src/external/caldera/MetaERC20Spoke.sol";

/*
LOCAL
forge script script/metatoken/WireSpokeWithHub.s.sol:WireSpokeWithHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/metatoken/WireSpokeWithHub.s.sol:WireSpokeWithHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET
forge script script/metatoken/WireSpokeWithHub.s.sol:WireSpokeWithHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract WireSpokeWithHub is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    // Domain ID of Base hub
    uint32 public constant HUB_DOMAIN = 8453;

    // Deployed spoke proxy address on Intuition L3
    address public constant SPOKE_PROXY = 0xf773031Ac1b5F6041d823704E1338b69b56E6D23; // TODO: Address of deployed spoke
    // proxy

    // Deployed hub proxy address on Base
    address public constant HUB_PROXY = 0x41e7c242e22D6166D7e19C24eBBE5ACEe5E6c862; // TODO: Address of deployed hub
    // proxy

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 1155 && block.chainid != 13_579 && block.chainid != 31_337) {
            revert("This script must be run on Intuition, Intuition Sepolia or Anvil");
        }

        if (HUB_PROXY == address(0) || SPOKE_PROXY == address(0)) {
            revert("HUB_PROXY and SPOKE_PROXY must be set");
        }

        MetaERC20Spoke spoke = MetaERC20Spoke(SPOKE_PROXY);

        uint32[] memory domains = new uint32[](1);
        domains[0] = HUB_DOMAIN;

        bytes32[] memory addresses = new bytes32[](1);
        addresses[0] = bytes32(uint256(uint160(HUB_PROXY)));

        spoke.setDomainAddressBatch(domains, addresses);

        console2.log("Registered hub on spoke:");
        console2.log("Domain:", HUB_DOMAIN);
        console2.log("Address:", HUB_PROXY);

        vm.stopBroadcast();
    }
}
