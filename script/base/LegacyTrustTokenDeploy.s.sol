// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelinV4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelinV4/contracts/proxy/transparent/ProxyAdmin.sol";

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
--slow \
--verify --verifier etherscan --verifier-url "https://api.etherscan.io/v2/api?chainid=84532"
*/

contract LegacyTrustTokenDeploy is SetupScript {
    ProxyAdmin public proxyAdmin;
    TrustToken public legacyTrustTokenImpl;
    TransparentUpgradeableProxy public legacyTrustTokenProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deploy();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Proxy Admin OZ V4:", address(proxyAdmin));
        console2.log("Trust Implementation:", address(legacyTrustTokenImpl));
        console2.log("Trust Proxy:", address(legacyTrustTokenProxy));
    }

    function _deploy() internal {
        proxyAdmin = new ProxyAdmin();
        info("Proxy Admin OZ V4", address(proxyAdmin));

        legacyTrustTokenImpl = new TrustToken();
        info("Trust Implementation", address(legacyTrustTokenImpl));

        legacyTrustTokenProxy = new TransparentUpgradeableProxy(
            address(legacyTrustTokenImpl), address(proxyAdmin), abi.encodeWithSelector(TrustToken.init.selector)
        );
        info("Trust Proxy", address(legacyTrustTokenProxy));
    }
}
