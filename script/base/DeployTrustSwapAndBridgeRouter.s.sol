// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { FinalityState } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { RouterConfig } from "src/interfaces/ITrustSwapAndBridgeRouter.sol";
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

    // ===== Aerodrome Slipstream (CL) Addresses on Base =====
    address public constant SLIPSTREAM_SWAP_ROUTER = 0xcbBb8035cAc7D4B3Ca7aBb74cF7BdF900215Ce0D;
    address public constant SLIPSTREAM_FACTORY = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;
    address public constant SLIPSTREAM_QUOTER = 0x3d4C22254F86f64B7eC90ab8F7aeC1FBFD271c6C;

    // ===== Bridging Configuration =====
    uint32 public constant INTUITION_MAINNET_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant BRIDGE_FINALITY_STATE = FinalityState.INSTANT;

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

        // Prepare router configuration
        RouterConfig memory config = RouterConfig({
            slipstreamSwapRouter: SLIPSTREAM_SWAP_ROUTER,
            slipstreamFactory: SLIPSTREAM_FACTORY,
            slipstreamQuoter: SLIPSTREAM_QUOTER,
            metaERC20Hub: BASE_MAINNET_META_ERC20_HUB,
            recipientDomain: INTUITION_MAINNET_DOMAIN,
            bridgeGasLimit: BRIDGE_GAS_LIMIT,
            finalityState: BRIDGE_FINALITY_STATE
        });

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(TrustSwapAndBridgeRouter.initialize.selector, ADMIN, config);

        // Deploy TrustSwapAndBridgeRouter proxy
        trustSwapAndBridgeRouterProxy = new TransparentUpgradeableProxy(
            address(trustSwapAndBridgeRouterImplementation), UPGRADES_TIMELOCK_CONTROLLER, initData
        );
        info("TrustSwapAndBridgeRouter Proxy", address(trustSwapAndBridgeRouterProxy));
    }
}
