// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { SetupScript } from "../SetupScript.s.sol";
import { IntuitionSepoliaBridge } from "tests/testnet/IntuitionSepoliaBridge.sol";

/*
forge script script/e2e/IntuitionSepoliaBridgeDeploy.s.sol:IntuitionSepoliaBridgeDeploy \
--rpc-url intuition_sepolia \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/' \
--broadcast \
--slow \ 
-vvvv

forge verify-contract \
--rpc-url https://intuition-testnet.rpc.caldera.xyz/http \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/' \
[address] \
tests/testnet/IntuitionSepoliaBridge.sol:IntuitionSepoliaBridge

*/
contract IntuitionSepoliaBridgeDeploy is SetupScript {
    IntuitionSepoliaBridge public intuitionSepoliaBridge;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("IntuitionSepoliaBridge:", address(intuitionSepoliaBridge));
    }

    function _deployContracts() internal {
        intuitionSepoliaBridge = new IntuitionSepoliaBridge(ADMIN, METALAYER_HUB_OR_SPOKE);
    }
}
