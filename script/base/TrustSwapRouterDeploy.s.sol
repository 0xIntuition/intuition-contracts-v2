// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { TrustSwapRouter } from "src/utils/TrustSwapRouter.sol";

/*
TESTNET (Base Sepolia)
forge script script/base/TrustSwapRouterDeploy.s.sol:TrustSwapRouterDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow

MAINNET (Base)
forge script script/base/TrustSwapRouterDeploy.s.sol:TrustSwapRouterDeploy \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow
*/

contract TrustSwapRouterDeploy is Script {
    /* =================================================== */
    /*                   Config Constants                  */
    /* =================================================== */

    uint256 public constant NETWORK_BASE = 8453;
    uint256 public constant NETWORK_BASE_SEPOLIA = 84_532;
    uint256 public constant NETWORK_ANVIL = 31_337;

    // ===== Base Mainnet Token Addresses =====
    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    // ===== Base Mainnet Aerodrome V2 Router / Factory =====
    address public constant BASE_MAINNET_AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant BASE_MAINNET_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // ===== Base Sepolia Token Addresses (placeholders - update as needed) =====
    address public constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address public constant BASE_SEPOLIA_TRUST = 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210;

    // ===== Base Sepolia Aerodrome (placeholders - update as needed) =====
    address public constant BASE_SEPOLIA_AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant BASE_SEPOLIA_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // ===== Default Swap Deadline =====
    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;

    // ===== Timelock Config =====
    uint256 public constant TIMELOCK_MIN_DELAY = 5 minutes;

    /* =================================================== */
    /*                   State Variables                   */
    /* =================================================== */

    /// @dev The address of the transaction broadcaster
    address internal broadcaster;

    /// @dev Admin address
    address internal admin;

    /// @dev Network-specific configuration
    address internal usdc;
    address internal trust;
    address internal aerodromeRouter;
    address internal poolFactory;

    /// @dev Deployed contracts
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;
    TrustSwapRouter public trustSwapRouter;
    TimelockController public timelockController;

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error UnsupportedChainId();

    /* =================================================== */
    /*                   CONSTRUCTOR                       */
    /* =================================================== */

    constructor() {
        if (block.chainid == NETWORK_BASE) {
            uint256 deployerKey = vm.envUint("DEPLOYER_MAINNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_BASE_SEPOLIA) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_ANVIL) {
            uint256 deployerKey = vm.envUint("DEPLOYER_LOCAL");
            broadcaster = vm.rememberKey(deployerKey);
        } else {
            revert UnsupportedChainId();
        }
    }

    /* =================================================== */
    /*                      MODIFIERS                      */
    /* =================================================== */

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        console2.log("Broadcasting from:", broadcaster);
        _;
        vm.stopBroadcast();
    }

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual {
        console2.log("NETWORK: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("ChainID:", block.chainid);
        info("Broadcasting:", broadcaster);

        if (block.chainid == NETWORK_BASE) {
            admin = vm.envAddress("BASE_MAINNET_ADMIN_ADDRESS");
            usdc = BASE_MAINNET_USDC;
            trust = BASE_MAINNET_TRUST;
            aerodromeRouter = BASE_MAINNET_AERODROME_ROUTER;
            poolFactory = BASE_MAINNET_POOL_FACTORY;
        } else if (block.chainid == NETWORK_BASE_SEPOLIA) {
            admin = vm.envAddress("BASE_SEPOLIA_ADMIN_ADDRESS");
            usdc = BASE_SEPOLIA_USDC;
            trust = BASE_SEPOLIA_TRUST;
            aerodromeRouter = BASE_SEPOLIA_AERODROME_ROUTER;
            poolFactory = BASE_SEPOLIA_POOL_FACTORY;
        } else if (block.chainid == NETWORK_ANVIL) {
            admin = vm.envAddress("ANVIL_ADMIN_ADDRESS");
            usdc = vm.envOr("ANVIL_USDC", address(0));
            trust = vm.envOr("ANVIL_TRUST", address(0));
            aerodromeRouter = vm.envOr("ANVIL_AERODROME_ROUTER", address(0));
            poolFactory = vm.envOr("ANVIL_POOL_FACTORY", address(0));
        } else {
            revert UnsupportedChainId();
        }

        console2.log("");
        console2.log("CONFIGURATION: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("Admin Address", admin);
        info("USDC Address", usdc);
        info("TRUST Address", trust);
        info("Aerodrome Router", aerodromeRouter);
        info("Pool Factory", poolFactory);
        info("Default Swap Deadline", DEFAULT_SWAP_DEADLINE);
    }

    /* =================================================== */
    /*                        RUN                          */
    /* =================================================== */

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        _deploy();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("Timelock Controller", address(timelockController));
        contractInfo("TrustSwapRouter Implementation", address(trustSwapRouterImplementation));
        contractInfo("TrustSwapRouter Proxy", address(trustSwapRouterProxy));
    }

    /* =================================================== */
    /*                   INTERNAL DEPLOY                   */
    /* =================================================== */

    function _deploy() internal {
        // Deploy TimelockController
        timelockController = _deployTimelockController("TrustSwapRouter TimelockController");

        // Deploy TrustSwapRouter implementation
        trustSwapRouterImplementation = new TrustSwapRouter();
        info("TrustSwapRouter Implementation", address(trustSwapRouterImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector, admin, usdc, trust, aerodromeRouter, poolFactory, DEFAULT_SWAP_DEADLINE
        );

        // Deploy TrustSwapRouter proxy
        trustSwapRouterProxy = new TransparentUpgradeableProxy(
            address(trustSwapRouterImplementation), address(timelockController), initData
        );
        info("TrustSwapRouter Proxy", address(trustSwapRouterProxy));

        // Cast proxy to contract interface
        trustSwapRouter = TrustSwapRouter(address(trustSwapRouterProxy));
        console2.log("TrustSwapRouter initialized successfully");
    }

    function _deployTimelockController(string memory label) internal returns (TimelockController) {
        address[] memory proposers = new address[](1);
        proposers[0] = admin;

        address[] memory executors = new address[](1);
        executors[0] = admin;

        TimelockController timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));
        info(label, address(timelock));
        return timelock;
    }

    /* =================================================== */
    /*                   HELPER FUNCTIONS                  */
    /* =================================================== */

    function info(string memory label, address addr) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(addr);
        console2.log("-------------------------------------------------------------------");
    }

    function info(string memory label, uint256 data) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(data);
        console2.log("-------------------------------------------------------------------");
    }

    function contractInfo(string memory label, address data) internal pure {
        console2.log(label, ":", data);
    }
}
