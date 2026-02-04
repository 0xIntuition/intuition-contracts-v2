// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { FinalityState } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { TrustSwapAndBridgeRouter } from "src/utils/TrustSwapAndBridgeRouter.sol";
import { SetupScript } from "script/SetupScript.s.sol";

/*
MAINNET (Base)
forge script script/base/DeployTrustSwapAndBridgeRouter.s.sol:DeployTrustSwapAndBridgeRouter \
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

contract DeployTrustSwapAndBridgeRouter is SetupScript {
    /* =================================================== */
    /*                   Config Constants                  */
    /* =================================================== */

    // ===== Upgrades TimelockController Address =====
    address public constant UPGRADES_TIMELOCK_CONTROLLER = 0x1E442BbB08c98100b18fa830a88E8A57b5dF9157;

    // ===== Base Mainnet MetaERC20Hub for Bridging =====
    address public constant BASE_MAINNET_META_ERC20_HUB = 0xE12aaF1529Ae21899029a9b51cca2F2Bc2cfC421;

    // ===== Bridging Configuration =====
    uint32 public constant INTUITION_MAINNET_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant BRIDGE_FINALITY_STATE = FinalityState.INSTANT;

    // ===== Default Swap Deadline =====
    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;

    // ===== Route Viability / Slippage Defaults =====
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;

    /// @dev Deployed contracts
    TrustSwapAndBridgeRouter public trustSwapAndBridgeRouterImplementation;
    TransparentUpgradeableProxy public trustSwapAndBridgeRouterProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        _deploy();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("TrustSwapAndBridgeRouter Implementation", address(trustSwapAndBridgeRouterImplementation));
        contractInfo("TrustSwapAndBridgeRouter Proxy", address(trustSwapAndBridgeRouterProxy));
    }

    /* =================================================== */
    /*                   INTERNAL DEPLOY                   */
    /* =================================================== */

    function _deploy() internal {
        // Deploy TrustSwapAndBridgeRouter implementation
        trustSwapAndBridgeRouterImplementation = new TrustSwapAndBridgeRouter();
        info("TrustSwapAndBridgeRouter Implementation", address(trustSwapAndBridgeRouterImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            TrustSwapAndBridgeRouter.initialize.selector,
            ADMIN,
            BASE_MAINNET_META_ERC20_HUB,
            INTUITION_MAINNET_DOMAIN,
            BRIDGE_GAS_LIMIT,
            BRIDGE_FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        // Deploy TrustSwapAndBridgeRouter proxy
        trustSwapAndBridgeRouterProxy = new TransparentUpgradeableProxy(
            address(trustSwapAndBridgeRouterImplementation), UPGRADES_TIMELOCK_CONTROLLER, initData
        );
        info("TrustSwapAndBridgeRouter Proxy", address(trustSwapAndBridgeRouterProxy));
    }
}
