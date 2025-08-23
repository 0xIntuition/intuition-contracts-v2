// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { BaseScript } from "./Base.s.sol";

/*
TESTNET
forge script script/Deploy.s.sol:Deploy \
*/
contract Deploy is BaseScript {
    function run() public broadcast returns (bool) {
        // vm.startBroadcast();

        // Deploy the MultiVault contract
        // MultiVault multiVault = new MultiVault();

        console2.logBytes32(bytes32(uint256(uint160(0x395867a085228940cA50a26166FDAD3f382aeB09))));
        // Optionally, you can deploy other contracts or perform additional setup here

        // vm.stopBroadcast();

        // Return true to indicate successful deployment
        return true;
    }
}
