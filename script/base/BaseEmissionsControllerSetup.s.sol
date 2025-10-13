// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script, console2 } from "forge-std/src/Script.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";

/*
LOCAL
forge script script/base/BaseEmissionsControllerSetup.s.sol:BaseEmissionsControllerSetup \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/base/BaseEmissionsControllerSetup.s.sol:BaseEmissionsControllerSetup \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow

MAINNET
forge script script/base/BaseEmissionsControllerSetup.s.sol:BaseEmissionsControllerSetup \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow
*/
contract BaseEmissionsControllerSetup is SetupScript {
    address public BASE_EMISSIONS_CONTROLLER;
    address public SATELLITE_EMISSIONS_CONTROLLER;

    function setUp() public override {
        super.setUp();

        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
            SATELLITE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_SATELLITE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
            SATELLITE_EMISSIONS_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_SATELLITE_EMISSIONS_CONTROLLER");
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    function run() public broadcast {
        _setup();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Base Emissions Controller:", address(BASE_EMISSIONS_CONTROLLER));
        console2.log("Satellite Emissions Controller:", address(SATELLITE_EMISSIONS_CONTROLLER));
        console2.log("");
        console2.log("SETUP COMPLETE");
    }

    function _setupContracts() internal {
        BaseEmissionsController(payable(BASE_EMISSIONS_CONTROLLER)).setSatelliteEmissionsController(
            SATELLITE_EMISSIONS_CONTROLLER
        );
    }
}
