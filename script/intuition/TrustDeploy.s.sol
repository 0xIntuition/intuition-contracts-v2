// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { Trust } from "src/Trust.sol";
import { TrustToken } from "src/legacy/TrustToken.sol";

/*
TESTNET
forge script script/intuition/TrustDeploy.s.sol:TrustDeploy \
--rpc-url intuition_sepolia \
--broadcast
*/

contract TrustDeploy is SetupScript {
    Trust public trustImpl;
    TransparentUpgradeableProxy public trustProxy;

    address public BASE_EMISSIONS_CONTROLLER;

    function setUp() public override {
        super.setUp();

        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    function run() public broadcast {
        _deployTrustToken();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Trust Implementation:", address(trustImpl));
        console2.log("Trust Proxy:", address(trustProxy));
    }

    function _deployTrustToken() internal {
        // 1. Deploy the Trust token implementation contract
        trustImpl = new Trust();
        info("Trust Implementation", address(trustImpl));

        // 2. Deploy and initialize the Trust token proxy contract
        trustProxy =
            new TransparentUpgradeableProxy(address(trustImpl), ADMIN, abi.encodeWithSelector(TrustToken.init.selector));
        info("Trust Proxy", address(trustProxy));

        Trust trustToken = Trust(address(trustProxy));

        // 3. Renitialize Trust token contract
        trustToken.reinitialize(
            ADMIN, // admin address
            BASE_EMISSIONS_CONTROLLER // Base emissions controller address
        );
    }
}
