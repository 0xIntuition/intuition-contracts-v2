// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { EntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { Trust } from "src/Trust.sol";
import { MockTrust } from "src/protocol/mock/MockTrust.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    IPermit2
} from "src/interfaces/IMultiVaultCore.sol";

abstract contract SetupScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    // General Config
    address internal ADMIN;
    address internal PROTOCOL_MULTISIG;
    address internal TRUST_TOKEN;

    uint8 internal DECIMAL_PRECISION = 18;
    uint256 internal FEE_DENOMINATOR = 10_000;
    uint256 internal MIN_DEPOSIT = 1e15; // 0.001 Trust
    uint256 internal MIN_SHARES = 1e6; // Ghost Shares
    uint256 internal ATOM_DATA_MAX_LENGTH = 1000;

    // Atom Config
    uint256 internal ATOM_CREATION_PROTOCOL_FEE = 1e15; // 0.001 Trust (Fixed Cost)
    uint256 internal ATOM_WALLET_DEPOSIT_FEE = 100; // 1% of assets after fixed costs (Percentage Cost)

    // Triple Config
    uint256 internal TRIPLE_CREATION_PROTOCOL_FEE = 1e15; // 0.001 Trust (Fixed Cost)
    uint256 internal TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION = 1e15; // 0.001 Trust (Fixed Cost)
    uint256 internal ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 300; // 3% (Percentage Cost)

    // Vault Config
    uint256 internal ENTRY_FEE = 500; // 5% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal EXIT_FEE = 500; // 5% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal PROTOCOL_FEE = 1000; // 10% of assets deposited after fixed costs (Percentage Cost)

    // TrustBonding Config
    uint256 internal BONDING_START_TIMESTAMP = block.timestamp + 100;
    uint256 internal BONDING_EPOCH_LENGTH = 2 weeks;
    uint256 internal BONDING_SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
    uint256 internal BONDING_PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 25%

    // CoreEmissionsController Config
    uint256 internal EMISSIONS_START_TIMESTAMP = BONDING_START_TIMESTAMP;
    uint256 internal EMISSIONS_LENGTH = 1 days;
    uint256 internal EMISSIONS_PER_EPOCH = 1000e18; // 1000 TRUST per epoch
    uint256 internal EMISSIONS_REDUCTION_CLIFF = 1; // 1 epoch
    uint256 internal EMISSIONS_REDUCTION_BASIS_POINTS = 1000; // 10%

    // Curve Configurations
    uint256 internal PROGRESSIVE_CURVE_SLOPE = 2;
    uint256 internal OFFSET_PROGRESSIVE_CURVE_SLOPE = 2;
    uint256 internal OFFSET_PROGRESSIVE_CURVE_OFFSET = 5e35;

    // MetaLayer Configurations
    address internal METALAYER_HUB_OR_SPOKE = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5;
    uint256 internal METALAYER_GAS_LIMIT = 200_000; // Gas limit for cross-chain operations

    // Deployed contracts
    Trust public trust;
    MultiVault public multiVault;
    AtomWalletFactory public atomWalletFactory;
    SatelliteEmissionsController public satelliteEmissionsController;
    TrustBonding public trustBonding;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    ProgressiveCurve public progressiveCurve;
    OffsetProgressiveCurve public offsetProgressiveCurve;

    address public proxyAdminOwner;
    address public multiVaultAdmin;
    address public protocolMultisig;
    address public migrator;
    address public permit2; // should be deployed separately
    address public atomWarden;
    address public atomWalletBeacon;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        if (block.chainid == vm.envUint("BASE_CHAIN_ID")) {
            uint256 deployerKey = vm.envUint("DEPLOYER_MAINNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            uint256 deployerKey = vm.envUint("DEPLOYER_LOCAL");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
            broadcaster = vm.rememberKey(deployerKey);
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        console2.log("NETWORK: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("ChainID:", block.chainid);
        info("Broadcasting:", broadcaster);

        // Load environment variables
        if (block.chainid == vm.envUint("BASE_CHAIN_ID")) {
            ADMIN = vm.envAddress("BASE_ADMIN_ADDRESS");
            TRUST_TOKEN = vm.envOr("BASE_TRUST_TOKEN", address(0));
            PROTOCOL_MULTISIG = vm.envOr("BASE_PROTOCOL_MULTISIG", ADMIN);
        } else if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            ADMIN = vm.envAddress("ANVIL_ADMIN_ADDRESS");
            TRUST_TOKEN = vm.envOr("ANVIL_TRUST_TOKEN", address(0));
            PROTOCOL_MULTISIG = vm.envOr("ANVIL_PROTOCOL_MULTISIG", ADMIN);
        } else if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) {
            ADMIN = vm.envAddress("BASE_SEPOLIA_ADMIN_ADDRESS");
            TRUST_TOKEN = vm.envOr("BASE_SEPOLIA_TRUST_TOKEN", address(0));
            PROTOCOL_MULTISIG = vm.envOr("BASE_SEPOLIA_PROTOCOL_MULTISIG", ADMIN);
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            ADMIN = vm.envAddress("INTUITION_SEPOLIA_ADMIN_ADDRESS");
            TRUST_TOKEN = vm.envOr("INTUITION_SEPOLIA_WRAPPED_TRUST_TOKEN", address(0)); // WTRUST token
            PROTOCOL_MULTISIG = vm.envOr("INTUITION_SEPOLIA_PROTOCOL_MULTISIG", ADMIN);
        } else {
            revert("Unsupported chain for broadcasting");
        }

        // Load optional configuration from environment
        MIN_SHARES = vm.envOr("MIN_SHARES", MIN_SHARES);
        MIN_DEPOSIT = vm.envOr("MIN_DEPOSIT", MIN_DEPOSIT);

        // Atom Config
        ATOM_CREATION_PROTOCOL_FEE = vm.envOr("ATOM_CREATION_PROTOCOL_FEE", ATOM_CREATION_PROTOCOL_FEE);
        ATOM_WALLET_DEPOSIT_FEE = vm.envOr("ATOM_WALLET_DEPOSIT_FEE", ATOM_WALLET_DEPOSIT_FEE);

        // Triple Config
        TRIPLE_CREATION_PROTOCOL_FEE = vm.envOr("TRIPLE_CREATION_PROTOCOL_FEE", TRIPLE_CREATION_PROTOCOL_FEE);
        TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION =
            vm.envOr("TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION", TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION);
        ATOM_DEPOSIT_FRACTION_FOR_TRIPLE =
            vm.envOr("ATOM_DEPOSIT_FRACTION_FOR_TRIPLE", ATOM_DEPOSIT_FRACTION_FOR_TRIPLE);

        // Vault Config
        ENTRY_FEE = vm.envOr("ENTRY_FEE", ENTRY_FEE);
        EXIT_FEE = vm.envOr("EXIT_FEE", EXIT_FEE);
        PROTOCOL_FEE = vm.envOr("PROTOCOL_FEE", PROTOCOL_FEE);

        // TrustBonding Config
        BONDING_EPOCH_LENGTH = vm.envOr("BONDING_EPOCH_LENGTH", BONDING_EPOCH_LENGTH);
        BONDING_SYSTEM_UTILIZATION_LOWER_BOUND =
            vm.envOr("BONDING_SYSTEM_UTILIZATION_LOWER_BOUND", BONDING_SYSTEM_UTILIZATION_LOWER_BOUND);
        BONDING_PERSONAL_UTILIZATION_LOWER_BOUND =
            vm.envOr("BONDING_PERSONAL_UTILIZATION_LOWER_BOUND", BONDING_PERSONAL_UTILIZATION_LOWER_BOUND);

        // CoreEmissionsController Config
        EMISSIONS_LENGTH = vm.envOr("EMISSIONS_LENGTH", EMISSIONS_LENGTH);
        EMISSIONS_PER_EPOCH = vm.envOr("EMISSIONS_PER_EPOCH", EMISSIONS_PER_EPOCH);
        EMISSIONS_REDUCTION_CLIFF = vm.envOr("EMISSIONS_REDUCTION_CLIFF", EMISSIONS_REDUCTION_CLIFF);
        EMISSIONS_REDUCTION_BASIS_POINTS =
            vm.envOr("EMISSIONS_REDUCTION_BASIS_POINTS", EMISSIONS_REDUCTION_BASIS_POINTS);

        // Curve Configurations
        OFFSET_PROGRESSIVE_CURVE_SLOPE = vm.envOr("OFFSET_PROGRESSIVE_CURVE_SLOPE", OFFSET_PROGRESSIVE_CURVE_SLOPE);
        OFFSET_PROGRESSIVE_CURVE_OFFSET = vm.envOr("OFFSET_PROGRESSIVE_CURVE_OFFSET", OFFSET_PROGRESSIVE_CURVE_OFFSET);
        PROGRESSIVE_CURVE_SLOPE = vm.envOr("PROGRESSIVE_CURVE_SLOPE", PROGRESSIVE_CURVE_SLOPE);

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

    function _deployTrustToken() internal returns (address) {
        // Deploy Trust implementation
        MockTrust trustImpl = new MockTrust();
        info("Trust Implementation", address(trustImpl));

        // Deploy Trust proxy
        TransparentUpgradeableProxy trustProxy = new TransparentUpgradeableProxy(address(trustImpl), ADMIN, "");
        Trust trustToken = Trust(address(trustProxy));
        info("Trust Proxy", address(trustProxy));

        // Initialize Trust token contract
        trustToken.init();

        // Reinitialize Trust token contract
        trustToken.reinitialize(
            ADMIN, // admin
            ADMIN // initial controller
        );
        return address(trustToken);
    }

    function _getGeneralConfig() internal view returns (GeneralConfig memory) {
        return GeneralConfig({
            admin: ADMIN,
            protocolMultisig: protocolMultisig,
            feeDenominator: FEE_DENOMINATOR,
            trustBonding: address(trustBonding),
            minDeposit: MIN_DEPOSIT,
            minShare: MIN_SHARES,
            atomDataMaxLength: ATOM_DATA_MAX_LENGTH,
            decimalPrecision: DECIMAL_PRECISION
        });
    }

    function _getAtomConfig() internal view returns (AtomConfig memory) {
        return AtomConfig({
            atomCreationProtocolFee: ATOM_CREATION_PROTOCOL_FEE,
            atomWalletDepositFee: ATOM_WALLET_DEPOSIT_FEE
        });
    }

    function _getTripleConfig() internal view returns (TripleConfig memory) {
        return TripleConfig({
            tripleCreationProtocolFee: TRIPLE_CREATION_PROTOCOL_FEE,
            totalAtomDepositsOnTripleCreation: TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            atomDepositFractionForTriple: ATOM_DEPOSIT_FRACTION_FOR_TRIPLE
        });
    }

    function _getWalletConfig() internal returns (WalletConfig memory) {
        address entryPoint = address(new EntryPoint());
        console2.log("EntryPoint deployed at:", entryPoint);

        return WalletConfig({
            permit2: IPermit2(permit2), // Can be deployed separately and set later. We didn't include it here because
                // it requires strictly 0.8.17 Solidity version.
            entryPoint: entryPoint,
            atomWarden: atomWarden,
            atomWalletBeacon: atomWalletBeacon,
            atomWalletFactory: address(atomWalletFactory)
        });
    }

    function _getVaultFees() internal view returns (VaultFees memory) {
        return VaultFees({
            entryFee: ENTRY_FEE, // 1%
            exitFee: EXIT_FEE, // 1%
            protocolFee: PROTOCOL_FEE // 1%
         });
    }

    function _getBondingCurveConfig() internal view returns (BondingCurveConfig memory) {
        return BondingCurveConfig({
            registry: address(bondingCurveRegistry),
            defaultCurveId: 1 // Linear curve
         });
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
        console2.log(
            string.concat(
                "  ProgressiveCurve: { [",
                vm.toString(block.chainid),
                "]: '",
                vm.toString(address(progressiveCurve)),
                "' }"
            )
        );
        console2.log("}");
    }
}
