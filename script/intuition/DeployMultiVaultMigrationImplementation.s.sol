// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Script, console } from "forge-std/src/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";

contract DeployMultiVaultMigrationModeImplementation is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the MultiVaultMigrationMode implementation contract for later upgrade via ProxyAdmin
        MultiVaultMigrationMode multiVaultMigrationMode = new MultiVaultMigrationMode();

        console.log("MultiVaultMigrationMode implementation deployed at:", address(multiVaultMigrationMode));

        vm.stopBroadcast();
    }
}
