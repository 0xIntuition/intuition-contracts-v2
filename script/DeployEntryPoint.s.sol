// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { EntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { Script, console } from "forge-std/src/Script.sol";

contract DeployEntryPoint is Script {
    error UnsupportedChainId();

    function run() external {
        uint256 chainId = block.chainid;
        if (chainId != 13_579) {
            revert UnsupportedChainId(); // restrict deployment to only the Intuition testnet
        }

        vm.startBroadcast();

        EntryPoint entryPoint = new EntryPoint();
        console.log("EntryPoint deployed at: ", address(entryPoint));

        vm.stopBroadcast();
    }
}