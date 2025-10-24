// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { TrustToken } from "src/legacy/TrustToken.sol";

/*
TESTNET
forge script script/base/LegacyTrustTokenDeploy.s.sol:LegacyTrustTokenDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow

forge script script/base/LegacyTrustTokenDeploy.s.sol:LegacyTrustTokenDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow
*/

contract LegacyTrustTokenDeploy is SetupScript {
    TrustToken public legacyTrustTokenImpl;
    TransparentUpgradeableProxy public legacyTrustTokenProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deploy();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Trust Implementation:", address(legacyTrustTokenImpl));
        console2.log("Trust Proxy:", address(legacyTrustTokenProxy));
    }

    function _deploy() internal {
        legacyTrustTokenImpl = new TrustToken();
        info("Trust Implementation", address(legacyTrustTokenImpl));

        legacyTrustTokenProxy = new TransparentUpgradeableProxy(
            address(legacyTrustTokenImpl), ADMIN, abi.encodeWithSelector(TrustToken.init.selector)
        );
        info("Trust Proxy", address(legacyTrustTokenProxy));
    }
}
