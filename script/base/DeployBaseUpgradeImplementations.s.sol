// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { SetupScript } from "script/SetupScript.s.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";

/*
MAINNET (Base)
forge script script/base/DeployBaseUpgradeImplementations.s.sol:DeployBaseUpgradeImplementations \
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

contract DeployBaseUpgradeImplementations is SetupScript {
    error UnsupportedChain();

    /// @dev Mainnet proxy addresses (Base, chain 8453)
    address internal constant BASE_EC_PROXY = 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667;
    address internal constant BASE_EC_PROXY_ADMIN = 0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a;

    BaseEmissionsController public baseEmissionsControllerImplementation;

    function setUp() public override {
        super.setUp();

        if (block.chainid != NETWORK_BASE) {
            revert UnsupportedChain();
        }
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        _deployImplementations();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("BaseEmissionsController Implementation", address(baseEmissionsControllerImplementation));

        _logUpgradeCalldata();
    }

    function _deployImplementations() internal {
        baseEmissionsControllerImplementation = new BaseEmissionsController();
        info("BaseEmissionsController Implementation", address(baseEmissionsControllerImplementation));
    }

    /// @dev Logs the encoded calldata for the timelock-scheduled upgrade operation.
    ///      Use this as the `data` parameter when calling TimelockController.schedule().
    function _logUpgradeCalldata() internal view {
        console2.log("");
        console2.log("UPGRADE CALLDATA: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        console2.log("");
        console2.log("BaseEmissionsController upgrade (target: ProxyAdmin %s):", BASE_EC_PROXY_ADMIN);
        console2.logBytes(
            abi.encodeCall(
                ProxyAdmin.upgradeAndCall,
                (ITransparentUpgradeableProxy(BASE_EC_PROXY), address(baseEmissionsControllerImplementation), "")
            )
        );
    }
}
