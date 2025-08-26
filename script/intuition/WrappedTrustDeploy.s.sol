// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

/*
TESTNET
forge script script/intuition/WrappedTrustDeploy.s.sol:WrappedTrustDeploy \
--rpc-url intuition_sepolia \
--broadcast
*/
contract WrappedTrustDeploy is SetupScript {
    function run() public broadcast returns (bool) {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        WrappedTrust wrappedTrust = new WrappedTrust();
        info("Wrapped Trust", address(wrappedTrust));
        return true;
    }
}
