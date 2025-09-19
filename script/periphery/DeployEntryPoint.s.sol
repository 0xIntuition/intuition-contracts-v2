// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { EntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { console2 } from "forge-std/src/Script.sol";
import { SetupScript } from "../SetupScript.s.sol";

contract DeployEntryPoint is SetupScript {
    function run() external broadcast {
        EntryPoint entryPoint = new EntryPoint();
        console2.log("EntryPoint: ", address(entryPoint));
    }
}
