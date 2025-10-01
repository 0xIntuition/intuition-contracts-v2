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
--rpc-url intuition_sepolia \
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
            SATELLITE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_SEPOLIA_SATELLITE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
            SATELLITE_EMISSIONS_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_SATELLITE_EMISSIONS_CONTROLLER");
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    function run() public broadcast {
        _setupContracts();
    }

    function _setupContracts() internal {
        BaseEmissionsController(BASE_EMISSIONS_CONTROLLER).setSatelliteEmissionsController(
            SATELLITE_EMISSIONS_CONTROLLER
        );
    }
}
