// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { SetupScript } from "script/SetupScript.s.sol";
import { HubBridge } from "tests/testnet/HubBridge.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";

/*
TESTNET
forge script script/e2e/HubBridgeDeploy.s.sol:HubBridgeDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow

MAINNET
forge script script/e2e/HubBridgeDeploy.s.sol:HubBridgeDeploy \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow

*/
contract HubBridgeDeploy is SetupScript {
    HubBridge public intuitionSepoliaBridge;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("HubBridge:", address(intuitionSepoliaBridge));
    }

    function _deployContracts() internal {
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: METALAYER_HUB_OR_SPOKE,
            recipientDomain: SATELLITE_METALAYER_RECIPIENT_DOMAIN,
            gasLimit: METALAYER_GAS_LIMIT,
            finalityState: FinalityState.INSTANT
        });

        intuitionSepoliaBridge = new HubBridge(ADMIN, TRUST_TOKEN, metaERC20DispatchInit);
    }
}
