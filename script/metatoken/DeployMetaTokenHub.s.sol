// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MetaERC20Hub } from "src/external/caldera/MetaERC20Hub.sol";

/*
LOCAL
forge script script/metatoken/DeployMetaTokenHub.s.sol:DeployMetaTokenHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/metatoken/DeployMetaTokenHub.s.sol:DeployMetaTokenHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow \
--verify \
--chain 84532 \
--verifier-url "https://api.etherscan.io/v2/api?chainid=84532" \
--etherscan-api-key $ETHERSCAN_API_KEY

MAINNET
forge script script/metatoken/DeployMetaTokenHub.s.sol:DeployMetaTokenHub \
--via-ir \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow \
--verify \
--chain 8453 \
--verifier-url "https://api.etherscan.io/v2/api?chainid=8453" \
--etherscan-api-key $ETHERSCAN_API_KEY
*/

contract DeployMetaTokenHub is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    // Metalayer domain ID for Base
    uint32 public constant METALAYER_DOMAIN = 8453;

    // MetaToken protocol version (per docs: currently 1)
    uint8 public constant METATOKEN_VERSION = 1;

    // MetalayerRouter on Base
    address public constant METALAYER_ROUTER = 0x09cE71C24EE2098e351C0cF2dC6431B414d247f3;

    // Canonical USDC on Base
    address public constant CANONICAL_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // USDC has 6 decimals
    uint8 public constant TOKEN_DECIMALS = 6;

    // TTL window in seconds (keep in sync with spokes)
    uint256 public constant TTL_WINDOW = 10 minutes; // NOTE: It's recommended for this value to be 1-7 days in
    // production

    // Admin / owner (use multisig for production)
    address public constant HUB_OWNER = 0xB8e3452E62B45e654a300a296061597E3Cf3e039; // NOTE: Replace with multisig in
    // production

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 8453 && block.chainid != 84_532 && block.chainid != 31_337) {
            revert("This script must be run on Base, Base Sepolia or Anvil");
        }

        // 1. Deploy hub implementation
        MetaERC20Hub hubImplementation = new MetaERC20Hub();
        console2.log("MetaERC20Hub implementation deployed at:", address(hubImplementation));

        // 2. Encode initializer for MetaERC20Hub
        //
        // function initialize(
        //     uint32 _localDomain,
        //     address _metalayerRouter,
        //     uint256 _ttlWindow,
        //     uint8 _metaERC20Version,
        //     address _wrappedToken,
        //     uint8 _tokenDecimals,
        //     address _initialAdmin
        // )
        bytes memory initializationData = abi.encodeWithSelector(
            MetaERC20Hub.initialize.selector,
            METALAYER_DOMAIN,
            METALAYER_ROUTER,
            TTL_WINDOW,
            METATOKEN_VERSION,
            CANONICAL_USDC,
            TOKEN_DECIMALS,
            HUB_OWNER
        );

        // 3. Deploy hub proxy
        TransparentUpgradeableProxy hubProxy = new TransparentUpgradeableProxy(
            address(hubImplementation), // Implementation address
            address(HUB_OWNER), // ProxyAdmin owner
            initializationData // Encoded initializer call
        );
        console2.log("Hub proxy deployed at:", address(hubProxy));

        vm.stopBroadcast();
    }
}
