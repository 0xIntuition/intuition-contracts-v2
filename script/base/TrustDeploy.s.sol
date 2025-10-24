// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { Trust } from "src/Trust.sol";

/*
TESTNET
forge script script/base/TrustDeploy.s.sol:TrustDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow

forge script script/base/TrustDeploy.s.sol:TrustDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow \
--verify --verifier etherscan --verifier-url "https://api.etherscan.io/v2/api?chainid=84532"
*/

contract TrustDeploy is SetupScript {
    Trust public trustImpl;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deploy();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Trust Implementation:", address(trustImpl));
    }

    function _deploy() internal {
        trustImpl = new Trust();
        info("Trust Implementation", address(trustImpl));
    }
}
