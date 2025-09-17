// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Script, console2 } from "forge-std/src/Script.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
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
    /// @notice Chain ID for the Intuition Testnet
    uint32 internal SATELLITE_METALAYER_RECIPIENT_DOMAIN = 13_579;

    address public BASE_EMISSIONS_CONTROLLER;
    address public SATELLITE_EMISSIONS_CONTROLLER;

    function setUp() public override {
        super.setUp();

        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
            SATELLITE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_SATELLITE_EMISSIONS_CONTROLLER");
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
        // Initialize SatelliteEmissionsController with proper struct parameters
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            recipientAddress: BASE_EMISSIONS_CONTROLLER,
            hubOrSpoke: METALAYER_HUB_OR_SPOKE,
            recipientDomain: SATELLITE_METALAYER_RECIPIENT_DOMAIN,
            gasLimit: METALAYER_GAS_LIMIT,
            finalityState: FinalityState.FINALIZED
        });

        CoreEmissionsControllerInit memory coreEmissionsInit = CoreEmissionsControllerInit({
            startTimestamp: EMISSIONS_START_TIMESTAMP,
            emissionsLength: EMISSIONS_LENGTH,
            emissionsPerEpoch: EMISSIONS_PER_EPOCH,
            emissionsReductionCliff: EMISSIONS_REDUCTION_CLIFF,
            emissionsReductionBasisPoints: EMISSIONS_REDUCTION_BASIS_POINTS
        });

        BaseEmissionsController(BASE_EMISSIONS_CONTROLLER).initialize(
            ADMIN, ADMIN, address(trust), SATELLITE_EMISSIONS_CONTROLLER, metaERC20DispatchInit, coreEmissionsInit
        );
    }
}
