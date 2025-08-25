// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Script, console } from "forge-std/src/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

contract DeployMultiVaultMigrationMode is Script {
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 13_579) {
            revert UnsupportedChainId(); // restrict deployment to only the Intuition testnet
        }

        // Deploy the MultiVault implementation contract for later upgrade via ProxyAdmin
        MultiVault multiVault = new MultiVault();

        console.log("MultiVault implementation deployed at:", address(multiVault));

        vm.stopBroadcast();
    }
}
