// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MetaERC20Spoke } from "src/external/caldera/MetaERC20Spoke.sol";

/*
LOCAL
forge script script/metatoken/DeployMetaTokenSpoke.s.sol:DeployMetaTokenSpoke \
--via-ir \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/metatoken/DeployMetaTokenSpoke.s.sol:DeployMetaTokenSpoke \
--via-ir \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET
forge script script/metatoken/DeployMetaTokenSpoke.s.sol:DeployMetaTokenSpoke \
--via-ir \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployMetaTokenSpoke is Script {
    // ========= PLACEHOLDERS – FILL THESE BEFORE RUNNING =========

    // Metalayer domain ID for Intuition L3
    uint32 public constant METALAYER_DOMAIN_SPOKE = 1155;

    // Hub domain (Base) – must match hub's localDomain
    uint32 public constant HUB_DOMAIN = 8453;

    // Must match hub's metaERC20Version
    uint8 public constant METATOKEN_VERSION = 1;

    // MetalayerRouter on Intuition L3
    address public constant METALAYER_ROUTER_SPOKE = 0x09cE71C24EE2098e351C0cF2dC6431B414d247f3;

    // Display metadata (change if needed)
    string public constant TOKEN_NAME = "USD Coin";
    string public constant TOKEN_SYMBOL = "USDC";

    // Must match hub's tokenDecimals
    uint8 public constant TOKEN_DECIMALS = 6;

    // Above this amount, transfers go via hub (0 = everything via hub)
    uint256 public constant SECURITY_THRESHOLD = 0; // NOTE: Adjust if needed

    // TTL window in seconds (keep in sync with spokes)
    uint256 public constant TTL_WINDOW = 10 minutes; // NOTE: It's recommended for this value to be 1-7 days in
    // production

    // Admin / owner (use multisig for production)
    address public constant SPOKE_OWNER = 0xB8e3452E62B45e654a300a296061597E3Cf3e039; // NOTE: Replace with multisig in
    // production

    function run() external {
        vm.startBroadcast();

        if (block.chainid != 1155 && block.chainid != 13_579 && block.chainid != 31_337) {
            revert("This script must be run on Intuition, Intuition Sepolia or Anvil");
        }

        // 1. Deploy spoke implementation
        MetaERC20Spoke spokeImplementation = new MetaERC20Spoke();
        console2.log("MetaERC20Spoke implementation deployed at:", address(spokeImplementation));

        // 2. Encode initializer for MetaERC20Spoke
        //
        // Assumed initializer:
        // function initialize(
        //     uint32 _localDomain,
        //     address _metalayerRouter,
        //     uint256 _ttlWindow,
        //     uint8 _metaERC20Version,
        //     uint32 _hubDomain,
        //     string memory name_,
        //     string memory symbol_,
        //     uint8 _tokenDecimals,
        //     uint256 _securityThreshold,
        //     address _initialAdmin
        // )
        bytes memory initializationData = abi.encodeWithSelector(
            MetaERC20Spoke.initialize.selector,
            METALAYER_DOMAIN_SPOKE,
            METALAYER_ROUTER_SPOKE,
            TTL_WINDOW,
            METATOKEN_VERSION,
            HUB_DOMAIN,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            SECURITY_THRESHOLD,
            SPOKE_OWNER
        );

        // 3. Deploy spoke proxy
        TransparentUpgradeableProxy spokeProxy = new TransparentUpgradeableProxy(
            address(spokeImplementation), // Implementation address
            address(SPOKE_OWNER), // ProxyAdmin owner
            initializationData // Encoded initializer call
        );
        console2.log("Spoke proxy deployed at:", address(spokeProxy));

        vm.stopBroadcast();
    }
}
