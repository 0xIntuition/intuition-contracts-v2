// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { TrustSwapRouter } from "src/utils/TrustSwapRouter.sol";
import { SetupScript } from "script/SetupScript.s.sol";

/*
MAINNET (Base)
forge script script/base/DeployTrustSwapRouter.s.sol:DeployTrustSwapRouter \
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

contract DeployTrustSwapRouter is SetupScript {
    /* =================================================== */
    /*                   Config Constants                  */
    /* =================================================== */

    // ===== Upgrades TimelockController Address =====
    address public constant UPGRADES_TIMELOCK_CONTROLLER = 0x1E442BbB08c98100b18fa830a88E8A57b5dF9157;

    // ===== Base Mainnet Token Addresses =====
    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // ===== Base Mainnet Aerodrome V2 Router / Factory =====
    address public constant BASE_MAINNET_AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant BASE_MAINNET_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // ===== Default Swap Deadline =====
    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;

    /// @dev Deployed contracts
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        _deploy();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("TrustSwapRouter Implementation", address(trustSwapRouterImplementation));
        contractInfo("TrustSwapRouter Proxy", address(trustSwapRouterProxy));
    }

    /* =================================================== */
    /*                   INTERNAL DEPLOY                   */
    /* =================================================== */

    function _deploy() internal {
        // Deploy TrustSwapRouter implementation
        trustSwapRouterImplementation = new TrustSwapRouter();
        info("TrustSwapRouter Implementation", address(trustSwapRouterImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector,
            ADMIN,
            BASE_MAINNET_USDC,
            TRUST_TOKEN,
            BASE_MAINNET_AERODROME_ROUTER,
            BASE_MAINNET_POOL_FACTORY,
            DEFAULT_SWAP_DEADLINE
        );

        // Deploy TrustSwapRouter proxy
        trustSwapRouterProxy = new TransparentUpgradeableProxy(
            address(trustSwapRouterImplementation), UPGRADES_TIMELOCK_CONTROLLER, initData
        );
        info("TrustSwapRouter Proxy", address(trustSwapRouterProxy));
    }
}
