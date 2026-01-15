// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { Trust } from "src/Trust.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";

abstract contract SetupScript is Script {
    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /* =================================================== */
    /*                   Config Constants                  */
    /* =================================================== */
    uint256 public constant NETWORK_BASE = 8453;
    uint256 public constant NETWORK_BASE_SEPOLIA = 84_532;
    uint256 public constant NETWORK_ETHEREUM_SEPOLIA = 11_155_111;
    uint256 public constant NETWORK_INTUITION = 1155;
    uint256 public constant NETWORK_INTUITION_SEPOLIA = 13_579;
    uint256 public constant NETWORK_ANVIL = 31_337;

    uint256 internal constant ONE_DAY = 86_400;
    uint256 internal constant TWO_WEEKS = ONE_DAY * 14;

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /* =================================================== */
    /*                   Smart Contracts                   */
    /* =================================================== */

    Trust public trust;
    MultiVault public multiVault;
    AtomWarden public atomWarden;
    AtomWallet public atomWalletImplementation;
    AtomWalletFactory public atomWalletFactory;
    UpgradeableBeacon public atomWalletBeacon;
    SatelliteEmissionsController public satelliteEmissionsController;
    TrustBonding public trustBonding;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;

    /* =================================================== */
    /*                  Critical Configs                   */
    /* =================================================== */

    uint256 internal PROTOCOL_START_TIMESTAMP = 1_762_268_400; // Tues November 4, 2025 10:00:00 EST || Wed November 5,
    // 2025 00:00:00 KST

    uint256 internal TRUST_TOKEN_ONE_YEAR_EMISSIONS = 75_000_000 ether; // 75 million TRUST

    /* =================================================== */
    /*                  Network Specific                   */
    /* =================================================== */

    // MetaLayer Configurations
    address internal METALAYER_HUB_OR_SPOKE;
    uint32 internal BASE_METALAYER_RECIPIENT_DOMAIN;
    uint32 internal SATELLITE_METALAYER_RECIPIENT_DOMAIN;

    // General Config
    address internal ADMIN;
    address internal PROTOCOL_MULTISIG;
    address internal TRUST_TOKEN;

    uint256 internal FEE_THRESHOLD = 1e18; // 1 Trust
    uint256 internal MIN_DEPOSIT = 1e16; // 0.01 Trust

    // Atom Config
    uint256 internal ATOM_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
    uint256 internal ATOM_WALLET_DEPOSIT_FEE = 50; // 0.5% of assets after fixed costs (Percentage Cost)

    // Triple Config
    uint256 internal TRIPLE_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
    uint256 internal ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 90; // 0.9% (Percentage Cost)

    // TrustBonding Config
    uint256 internal BONDING_START_TIMESTAMP;
    uint256 internal BONDING_EPOCH_LENGTH;
    uint256 internal BONDING_SYSTEM_UTILIZATION_LOWER_BOUND;
    uint256 internal BONDING_PERSONAL_UTILIZATION_LOWER_BOUND;

    // CoreEmissionsController Config
    uint256 internal EMISSIONS_START_TIMESTAMP;
    uint256 internal EMISSIONS_LENGTH;
    uint256 internal EMISSIONS_PER_EPOCH;
    uint256 internal EMISSIONS_REDUCTION_CLIFF;
    uint256 internal EMISSIONS_REDUCTION_BASIS_POINTS;

    /* =================================================== */
    /*                  Network Agnostic                   */
    /* =================================================== */
    /// @dev deterministic address of the EntryPoint contract on all chains (v0.8.0)
    address internal ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

    // Timelock Config
    uint256 internal TIMELOCK_MIN_DELAY = 60 minutes;

    // MetaLayer Config
    uint256 internal METALAYER_GAS_LIMIT = 125_000; // Gas limit for cross-chain operations

    // General Config
    uint256 internal DECIMAL_PRECISION = 1e18;
    uint256 internal FEE_DENOMINATOR = 10_000;
    uint256 internal MIN_SHARES = 1e6; // Ghost Shares
    uint256 internal ATOM_DATA_MAX_LENGTH = 1000;

    // Vault Config
    uint256 internal ENTRY_FEE = 50; // 0.5% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal EXIT_FEE = 75; // 0.75% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal PROTOCOL_FEE = 125; // 1.25% of assets deposited after fixed costs (Percentage Cost)

    // Curve Configurations
    uint256 internal OFFSET_PROGRESSIVE_CURVE_SLOPE = 1e17;
    uint256 internal OFFSET_PROGRESSIVE_CURVE_OFFSET = 3e19;

    constructor() {
        if (block.chainid == NETWORK_BASE) {
            uint256 deployerKey = vm.envUint("DEPLOYER_MAINNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_INTUITION) {
            uint256 deployerKey = vm.envUint("DEPLOYER_MAINNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_BASE_SEPOLIA) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_ETHEREUM_SEPOLIA) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == NETWORK_ANVIL) {
            uint256 deployerKey = vm.envUint("DEPLOYER_LOCAL");
            broadcaster = vm.rememberKey(deployerKey);
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        console2.log("Broadcasting from:", broadcaster);
        _;
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        console2.log("NETWORK: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("ChainID:", block.chainid);
        info("Broadcasting:", broadcaster);

        if (block.chainid == NETWORK_BASE_SEPOLIA) {
            PROTOCOL_START_TIMESTAMP = 1_761_787_000;
            TRUST_TOKEN = 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210;
            ADMIN = vm.envAddress("BASE_SEPOLIA_ADMIN_ADDRESS");
            PROTOCOL_MULTISIG = vm.envOr("BASE_SEPOLIA_PROTOCOL_MULTISIG", ADMIN);

            // MetaLayer Intuition Hub
            METALAYER_HUB_OR_SPOKE = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5;
            SATELLITE_METALAYER_RECIPIENT_DOMAIN = 13_579;

            // Emissions Controller Config
            EMISSIONS_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            EMISSIONS_LENGTH = TWO_WEEKS;
            EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%
            EMISSIONS_REDUCTION_CLIFF = 26;
            EMISSIONS_PER_EPOCH = TRUST_TOKEN_ONE_YEAR_EMISSIONS / EMISSIONS_REDUCTION_CLIFF;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            PROTOCOL_START_TIMESTAMP = 1_761_787_000;
            TRUST_TOKEN = 0xDE80b6EE63f7D809427CA350e30093F436A0fe35; // Wrapped Trust
            ADMIN = vm.envAddress("INTUITION_SEPOLIA_ADMIN_ADDRESS");
            PROTOCOL_MULTISIG = vm.envOr("INTUITION_SEPOLIA_PROTOCOL_MULTISIG", ADMIN);

            // Timelock Config
            TIMELOCK_MIN_DELAY = 60 minutes;

            // MetaLayer Config
            BASE_METALAYER_RECIPIENT_DOMAIN = 84_532;
            METALAYER_HUB_OR_SPOKE = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5;

            // General Config
            MIN_DEPOSIT = 1e16; // 0.01 Trust

            // Atom Config
            ATOM_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_WALLET_DEPOSIT_FEE = 50; // 0.5% of assets after fixed costs (Percentage Cost)

            // Triple Config
            TRIPLE_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 90; // 0.9% (Percentage Cost)

            // TrustBonding Config
            BONDING_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            BONDING_EPOCH_LENGTH = TWO_WEEKS;
            BONDING_SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
            BONDING_PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 25%

            // Emissions Controller Config
            EMISSIONS_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            EMISSIONS_LENGTH = TWO_WEEKS;
            EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%
            EMISSIONS_REDUCTION_CLIFF = 26; // 1 epoch
            EMISSIONS_PER_EPOCH = TRUST_TOKEN_ONE_YEAR_EMISSIONS / EMISSIONS_REDUCTION_CLIFF;
        } else if (block.chainid == NETWORK_BASE) {
            // Global Config
            TRUST_TOKEN = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
            ADMIN = 0xBc01aB3839bE8933f6B93163d129a823684f4CDF;

            // Timelock Config
            TIMELOCK_MIN_DELAY = 5 minutes;

            // MetaLayer Config
            SATELLITE_METALAYER_RECIPIENT_DOMAIN = 1155;
            METALAYER_HUB_OR_SPOKE = 0xE12aaF1529Ae21899029a9b51cca2F2Bc2cfC421;

            // Emissions Controller Config
            EMISSIONS_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            EMISSIONS_LENGTH = TWO_WEEKS;
            EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%
            EMISSIONS_REDUCTION_CLIFF = 26;
            EMISSIONS_PER_EPOCH = TRUST_TOKEN_ONE_YEAR_EMISSIONS / EMISSIONS_REDUCTION_CLIFF;
        } else if (block.chainid == NETWORK_INTUITION) {
            TRUST_TOKEN = 0x81cFb09cb44f7184Ad934C09F82000701A4bF672;
            ADMIN = 0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb;
            PROTOCOL_MULTISIG = 0x4B44BE80739fb11544Dd835a0f55580Ad19Ce0F3;

            // Timelock Config
            TIMELOCK_MIN_DELAY = 5 minutes;

            // MetaLayer Config
            BASE_METALAYER_RECIPIENT_DOMAIN = 8453;
            METALAYER_HUB_OR_SPOKE = 0x375135fe908dD62f3C7939FA4e65bf41Da721AB9;

            // General Config
            MIN_DEPOSIT = 1e16; // 0.01 Trust

            // Atom Config
            ATOM_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_WALLET_DEPOSIT_FEE = 50; // 0.5% of assets after fixed costs (Percentage Cost)

            // Triple Config
            TRIPLE_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 90; // 0.9% (Percentage Cost)

            // TrustBonding Config
            BONDING_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            BONDING_EPOCH_LENGTH = TWO_WEEKS;
            BONDING_SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
            BONDING_PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 25%

            // Emissions Controller Config
            EMISSIONS_START_TIMESTAMP = PROTOCOL_START_TIMESTAMP;
            EMISSIONS_LENGTH = TWO_WEEKS;
            EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%
            EMISSIONS_REDUCTION_CLIFF = 26;
            EMISSIONS_PER_EPOCH = TRUST_TOKEN_ONE_YEAR_EMISSIONS / EMISSIONS_REDUCTION_CLIFF;
        } else if (block.chainid == NETWORK_ANVIL) {
            ADMIN = vm.envAddress("ANVIL_ADMIN_ADDRESS");
            TRUST_TOKEN = vm.envOr("ANVIL_TRUST_TOKEN", address(0));
            PROTOCOL_MULTISIG = vm.envOr("ANVIL_PROTOCOL_MULTISIG", ADMIN);

            // Timelock Config
            TIMELOCK_MIN_DELAY = 60 minutes;

            // MetaLayer Config
            BASE_METALAYER_RECIPIENT_DOMAIN = 11_111;
            METALAYER_HUB_OR_SPOKE = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5;

            // General Config
            MIN_DEPOSIT = 1e16; // 0.01 Trust

            // Atom Config
            ATOM_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_WALLET_DEPOSIT_FEE = 50; // 0.5% of assets after fixed costs (Percentage Cost)

            // Triple Config
            TRIPLE_CREATION_PROTOCOL_FEE = 1e17; // 0.1 Trust (Fixed Cost)
            ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 90; // 0.9% (Percentage Cost)

            // TrustBonding Config
            BONDING_START_TIMESTAMP = block.timestamp + 100;
            BONDING_EPOCH_LENGTH = TWO_WEEKS;
            BONDING_SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
            BONDING_PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 25%

            // CoreEmissionsController Config
            EMISSIONS_START_TIMESTAMP = BONDING_START_TIMESTAMP;
            EMISSIONS_LENGTH = ONE_DAY;
            EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%
            EMISSIONS_REDUCTION_CLIFF = 4; // 1 epoch
            EMISSIONS_PER_EPOCH = 1000 ether;
        } else if (block.chainid == NETWORK_ETHEREUM_SEPOLIA) {
            TRUST_TOKEN = 0x7BAd626D371Bf1de3Ac77C1FB4e9d8dC8236621C; // Mock Trust Token
            ADMIN = vm.envAddress("INTUITION_SEPOLIA_ADMIN_ADDRESS");
        } else {
            revert("Unsupported chain for broadcasting");
        }

        console2.log("");
        console2.log("CONFIGURATION: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("Admin Address", ADMIN);
        info("Trust Token", TRUST_TOKEN);
        info("Protocol Multisig", PROTOCOL_MULTISIG);
        info("MIN_SHARES", MIN_SHARES);
        info("MIN_DEPOSIT", MIN_DEPOSIT);
        info("ATOM_CREATION_PROTOCOL_FEE", ATOM_CREATION_PROTOCOL_FEE);
        info("ENTRY_FEE", ENTRY_FEE);
        info("EXIT_FEE", EXIT_FEE);
        info("PROTOCOL_FEE", PROTOCOL_FEE);
    }

    function _deployTimelockController(string memory label) internal returns (TimelockController) {
        address[] memory proposers = new address[](1);
        proposers[0] = ADMIN;

        address[] memory executors = new address[](1);
        executors[0] = ADMIN;

        // Deploy TimelockController
        TimelockController timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));
        info(label, address(timelock));
        return timelock;
    }

    function info(string memory label, address addr) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(addr);
        console2.log("-------------------------------------------------------------------");
    }

    function info(string memory label, bytes32 data) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.logBytes32(data);
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

    function _exportContractAddresses() internal view {
        console2.log("");
        console2.log("SDK JSON: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=");
        console2.log("{");
        console2.log(
            string.concat("  Trust: { [", vm.toString(block.chainid), "]: '", vm.toString(address(trust)), "' },")
        );
        console2.log(
            string.concat(
                "  MultiVault: { [", vm.toString(block.chainid), "]: '", vm.toString(address(multiVault)), "' },"
            )
        );
        console2.log(
            string.concat(
                "  AtomWalletFactory: { [",
                vm.toString(block.chainid),
                "]: '",
                vm.toString(address(atomWalletFactory)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  SatelliteEmissionsController: { [",
                vm.toString(block.chainid),
                "]: '",
                vm.toString(address(satelliteEmissionsController)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  TrustBonding: { [", vm.toString(block.chainid), "]: '", vm.toString(address(trustBonding)), "' },"
            )
        );
        console2.log(
            string.concat(
                "  BondingCurveRegistry: { [",
                vm.toString(block.chainid),
                "]: '",
                vm.toString(address(bondingCurveRegistry)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  LinearCurve: { [", vm.toString(block.chainid), "]: '", vm.toString(address(linearCurve)), "' },"
            )
        );
        console2.log(
            string.concat(
                "  OffsetProgressiveCurve: { [",
                vm.toString(block.chainid),
                "]: '",
                vm.toString(address(offsetProgressiveCurve)),
                "' }"
            )
        );
        console2.log("}");
    }
}
