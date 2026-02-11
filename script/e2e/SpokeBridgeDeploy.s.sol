// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { SetupScript } from "script/SetupScript.s.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { SpokeBridge } from "tests/testnet/SpokeBridge.sol";

/*
TESTNET
forge script script/e2e/SpokeBridgeDeploy.s.sol:SpokeBridgeDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow

MAINNET
forge script script/e2e/SpokeBridgeDeploy.s.sol:SpokeBridgeDeploy \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow

*/
contract SpokeBridgeDeploy is SetupScript {
    SpokeBridge public spokeBridge;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("SpokeBridge:", address(spokeBridge));
    }

    function _deployContracts() internal {
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: METALAYER_HUB_OR_SPOKE,
            recipientDomain: BASE_METALAYER_RECIPIENT_DOMAIN,
            gasLimit: METALAYER_GAS_LIMIT,
            finalityState: FinalityState.INSTANT
        });

        spokeBridge = new SpokeBridge(ADMIN, metaERC20DispatchInit);
    }
}
