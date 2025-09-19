// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { Script, console2 } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SetupScript } from "../SetupScript.s.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";

/*
LOCAL
forge script script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow

TESTNET
forge script script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow
*/
contract BaseEmissionsControllerDeploy is SetupScript {
    BaseEmissionsController public baseEmissionsControllerImpl;
    TransparentUpgradeableProxy public baseEmissionsControllerProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("BaseEmissionsController Implementation:", address(baseEmissionsControllerImpl));
        console2.log("BaseEmissionsController Proxy:", address(baseEmissionsControllerProxy));
    }

    function _deployContracts() internal {
        // 1. Deploy the BaseEmissionsController implementation contract
        baseEmissionsControllerImpl = new BaseEmissionsController();

        // 2. Deploy the TransparentUpgradeableProxy with the BaseEmissionsController implementation
        baseEmissionsControllerProxy = new TransparentUpgradeableProxy(address(baseEmissionsControllerImpl), ADMIN, "");
    }
}
