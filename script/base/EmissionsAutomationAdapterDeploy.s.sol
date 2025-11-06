// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script, console2 } from "forge-std/src/Script.sol";

import { EmissionsAutomationAdapter } from "src/utils/EmissionsAutomationAdapter.sol";
import { SetupScript } from "../SetupScript.s.sol";

/*
LOCAL
forge script script/base/EmissionsAutomationAdapterDeploy.s.sol:EmissionsAutomationAdapterDeploy \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/base/EmissionsAutomationAdapterDeploy.s.sol:EmissionsAutomationAdapterDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow \
--verify \
--verifier etherscan \
--verifier-url "https://api.etherscan.io/v2/api?chainid=84532" \
--chain 84532 \
--etherscan-api-key $ETHERSCAN_API_KEY

MAINNET
forge script script/base/EmissionsAutomationAdapterDeploy.s.sol:EmissionsAutomationAdapterDeploy \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow \
--verify \
--verifier etherscan \
--verifier-url "https://api.etherscan.io/v2/api?chainid=8453" \
--chain 8453 \
--etherscan-api-key $ETHERSCAN_API_KEY
*/

contract EmissionsAutomationAdapterDeploy is SetupScript {
    EmissionsAutomationAdapter public emissionsAutomationAdapterImpl;

    /// @notice Address of the BaseEmissionsController contract
    address public BASE_EMISSIONS_CONTROLLER;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_MAINNET_BASE_EMISSIONS_CONTROLLER");
        } else {
            revert("Unsupported chain for EmissionsAutomationAdapter deployment");
        }
    }

    function run() public broadcast {
        _deploy();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("EmissionsAutomationAdapter:", address(emissionsAutomationAdapterImpl));
    }

    function _deploy() internal {
        // 1. Deploy EmissionsAutomationAdapter contract
        emissionsAutomationAdapterImpl = new EmissionsAutomationAdapter(ADMIN, BASE_EMISSIONS_CONTROLLER);
    }
}
