// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Script, console } from "forge-std/src/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { EntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    IPermit2
} from "src/interfaces/IMultiVaultCore.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

contract DeployMultiVaultMigrationMode is Script {
    error UnsupportedChainId();
    error InvalidAddress();

    // Deployment configuration addresses
    address public proxyAdminOwner;
    address public multiVaultAdmin;
    address public protocolMultisig;
    address public migrator;
    address permit2; // should be deployed separately
    address public atomWarden;
    address public wrappedTrustTokenAddress;

    // Deployed contract addresses
    address public trustBonding;
    address public atomWalletFactory;
    address public bondingCurveRegistry;
    address public atomWalletBeacon;

    // Constants matching your test setup
    uint256 internal constant MIN_SHARES = 1e6;
    uint256 internal constant MIN_DEPOSIT = 0.1 * 1e18;
    uint256 internal constant ATOM_CREATION_PROTOCOL_FEE = 0.01 * 1e18;
    uint256 internal constant ATOM_WALLET_DEPOSIT_FEE = 100;
    uint256 internal constant TRIPLE_CREATION_PROTOCOL_FEE = 0.01 * 1e18;
    uint256 internal constant TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION = 0.009 * 1e18;
    uint256 internal constant ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 300; // 3%

    // TrustBonding configuration
    uint256 internal constant EPOCH_LENGTH = 2 weeks;
    uint256 internal constant SYSTEM_UTILIZATION_LOWER_BOUND = 4000; // 40%
    uint256 internal constant PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 25%

    // Role constants
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    function run() external {
        // Load configuration from environment variables or set defaults
        _loadConfiguration();

        // Validate configuration
        _validateConfiguration();

        vm.startBroadcast();

        // Only deploy on Intuition testnet (chain ID 13579)
        if (block.chainid != 13_579) {
            revert UnsupportedChainId();
        }

        console.log("=== Starting Deployment on Intuition Testnet ===");
        console.log("Deployer:", msg.sender);

        // 1. Deploy AtomWallet implementation and beacon
        AtomWallet atomWalletImpl = new AtomWallet();
        console.log("AtomWallet implementation deployed at:", address(atomWalletImpl));

        atomWalletBeacon = address(new UpgradeableBeacon(address(atomWalletImpl), multiVaultAdmin));
        console.log("AtomWalletBeacon deployed at:", atomWalletBeacon);

        // 2. Deploy AtomWalletFactory
        AtomWalletFactory atomWalletFactoryImpl = new AtomWalletFactory();
        console.log("AtomWalletFactory implementation deployed at:", address(atomWalletFactoryImpl));

        TransparentUpgradeableProxy atomWalletFactoryProxy =
            new TransparentUpgradeableProxy(address(atomWalletFactoryImpl), proxyAdminOwner, "");
        atomWalletFactory = address(atomWalletFactoryProxy);
        console.log("AtomWalletFactory proxy deployed at:", atomWalletFactory);

        // 3. Deploy BondingCurveRegistry and curves
        bondingCurveRegistry = address(new BondingCurveRegistry(multiVaultAdmin));
        console.log("BondingCurveRegistry deployed at:", bondingCurveRegistry);

        // Deploy Linear Curve
        LinearCurve linearCurve = new LinearCurve("Linear Bonding Curve");
        console.log("LinearCurve deployed at:", address(linearCurve));

        // Deploy Progressive Curve with 0.001 slope
        ProgressiveCurve progressiveCurve = new ProgressiveCurve("Progressive Bonding Curve", 1e15);
        console.log("ProgressiveCurve deployed at:", address(progressiveCurve));

        // Register curves in the registry
        BondingCurveRegistry(bondingCurveRegistry).addBondingCurve(address(linearCurve));
        console.log("LinearCurve registered with ID: 1");

        BondingCurveRegistry(bondingCurveRegistry).addBondingCurve(address(progressiveCurve));
        console.log("ProgressiveCurve registered with ID: 2");

        // 4. Deploy TrustBonding
        TrustBonding trustBondingImpl = new TrustBonding();
        console.log("TrustBonding implementation deployed at:", address(trustBondingImpl));

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBondingImpl), proxyAdminOwner, "");
        trustBonding = address(trustBondingProxy);
        console.log("TrustBonding proxy deployed at:", trustBonding);

        // 5. Deploy the MultiVaultMigrationMode implementation contract
        MultiVaultMigrationMode multiVaultMigrationModeImpl = new MultiVaultMigrationMode();
        console.log("MultiVaultMigrationMode implementation deployed at:", address(multiVaultMigrationModeImpl));

        // 6. Deploy the TransparentUpgradeableProxy with the MultiVaultMigrationMode implementation
        TransparentUpgradeableProxy multiVaultProxy =
            new TransparentUpgradeableProxy(address(multiVaultMigrationModeImpl), proxyAdminOwner, "");
        console.log("MultiVault proxy deployed at:", address(multiVaultProxy));

        // 7. Cast proxy to MultiVaultMigrationMode for initialization
        MultiVaultMigrationMode multiVaultMigrationMode = MultiVaultMigrationMode(address(multiVaultProxy));

        // 8. Prepare configuration structs with deployed addresses
        GeneralConfig memory generalConfig = _getGeneralConfig();
        AtomConfig memory atomConfig = _getAtomConfig();
        TripleConfig memory tripleConfig = _getTripleConfig();
        WalletConfig memory walletConfig = _getWalletConfig();
        VaultFees memory vaultFees = _getVaultFees();
        BondingCurveConfig memory bondingCurveConfig = _getBondingCurveConfig();

        // 9. Initialize the MultiVaultMigrationMode through the proxy
        multiVaultMigrationMode.initialize(
            generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees, bondingCurveConfig
        );
        console.log("MultiVaultMigrationMode initialized");

        // 10. Initialize AtomWalletFactory with MultiVault address
        AtomWalletFactory(atomWalletFactory).initialize(address(multiVaultProxy));
        console.log("AtomWalletFactory initialized with MultiVault:", address(multiVaultProxy));

        // 11. Initialize TrustBonding
        TrustBonding(trustBonding).initialize(
            multiVaultAdmin, // owner
            wrappedTrustTokenAddress, // WTRUST token
            EPOCH_LENGTH, // epochLength
            block.timestamp + 10 minutes, // startTimestamp (future)
            address(multiVaultProxy), // multiVault
            address(0), // satelliteEmissionsController (can be set later)
            SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound
            PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound
        );
        console.log("TrustBonding initialized");

        // 12. Grant MIGRATOR_ROLE to the migrator address
        IAccessControl(address(multiVaultMigrationMode)).grantRole(MIGRATOR_ROLE, migrator);
        console.log("MIGRATOR_ROLE granted to:", migrator);

        // 13. Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("MultiVault Proxy:", address(multiVaultProxy));
        console.log("MultiVault Implementation:", address(multiVaultMigrationModeImpl));
        console.log("ProxyAdmin Owner:", proxyAdminOwner);
        console.log("MultiVault Admin:", multiVaultAdmin);
        console.log("Protocol Multisig:", protocolMultisig);
        console.log("Migrator:", migrator);
        console.log("\n=== Supporting Contracts ===");
        console.log("TrustBonding:", trustBonding);
        console.log("AtomWalletFactory:", atomWalletFactory);
        console.log("AtomWalletBeacon:", atomWalletBeacon);
        console.log("BondingCurveRegistry:", bondingCurveRegistry);
        console.log("LinearCurve (ID 1):", address(linearCurve));
        console.log("ProgressiveCurve (ID 2):", address(progressiveCurve));
        console.log("Default Curve ID:", bondingCurveConfig.defaultCurveId);
        console.log("\n=== Configuration ===");
        console.log("Wrapped Trust Token Address:", wrappedTrustTokenAddress);
        console.log("Epoch Length:", EPOCH_LENGTH);
        console.log("Min Deposit:", MIN_DEPOSIT);
        console.log("Min Shares:", MIN_SHARES);

        vm.stopBroadcast();
    }

    function _loadConfiguration() internal {
        // Load from environment variables or use defaults for testnet or local development
        proxyAdminOwner = vm.envOr("PROXY_ADMIN_OWNER", address(0));
        multiVaultAdmin = vm.envOr("MULTIVAULT_ADMIN", address(0));
        protocolMultisig = vm.envOr("PROTOCOL_MULTISIG", address(0));
        migrator = vm.envOr("MIGRATOR", address(0));
        atomWarden = vm.envOr("ATOM_WARDEN", address(0));
        wrappedTrustTokenAddress = vm.envOr("WTRUST_TOKEN", address(0));

        // If critical addresses not set, use msg.sender (only advisable for testnet or local development)
        if (proxyAdminOwner == address(0)) {
            proxyAdminOwner = msg.sender;
            console.log("Warning: Using msg.sender as proxyAdminOwner");
        }
        if (multiVaultAdmin == address(0)) {
            multiVaultAdmin = msg.sender;
            console.log("Warning: Using msg.sender as multiVaultAdmin");
        }
        if (protocolMultisig == address(0)) {
            protocolMultisig = msg.sender;
            console.log("Warning: Using msg.sender as protocolMultisig");
        }
        if (migrator == address(0)) {
            migrator = msg.sender;
            console.log("Warning: Using msg.sender as migrator");
        }
        if (atomWarden == address(0)) {
            atomWarden = msg.sender;
            console.log("Warning: Using msg.sender as atomWarden");
        }
        if (wrappedTrustTokenAddress == address(0)) {
            // You'll need to deploy or specify the Trust token address
            console.log("Warning: Trust token address not set - using placeholder");
            wrappedTrustTokenAddress = address(new WrappedTrust());
            console.log("WrappedTrust token deployed at:", wrappedTrustTokenAddress);
        }
    }

    function _validateConfiguration() internal view {
        // Validate critical addresses are not zero
        if (proxyAdminOwner == address(0)) revert InvalidAddress();
        if (multiVaultAdmin == address(0)) revert InvalidAddress();
        if (protocolMultisig == address(0)) revert InvalidAddress();
        if (migrator == address(0)) revert InvalidAddress();
        if (atomWarden == address(0)) revert InvalidAddress();
        if (wrappedTrustTokenAddress == address(0)) revert InvalidAddress();
    }

    function _getGeneralConfig() internal view returns (GeneralConfig memory) {
        return GeneralConfig({
            admin: multiVaultAdmin,
            protocolMultisig: protocolMultisig,
            feeDenominator: 10_000,
            trustBonding: trustBonding,
            minDeposit: MIN_DEPOSIT,
            minShare: MIN_SHARES,
            atomDataMaxLength: 250,
            decimalPrecision: 1e18
        });
    }

    function _getAtomConfig() internal pure returns (AtomConfig memory) {
        return AtomConfig({
            atomCreationProtocolFee: ATOM_CREATION_PROTOCOL_FEE,
            atomWalletDepositFee: ATOM_WALLET_DEPOSIT_FEE
        });
    }

    function _getTripleConfig() internal pure returns (TripleConfig memory) {
        return TripleConfig({
            tripleCreationProtocolFee: TRIPLE_CREATION_PROTOCOL_FEE,
            totalAtomDepositsOnTripleCreation: TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            atomDepositFractionForTriple: ATOM_DEPOSIT_FRACTION_FOR_TRIPLE
        });
    }

    function _getWalletConfig() internal returns (WalletConfig memory) {
        address entryPoint = address(new EntryPoint());
        console.log("EntryPoint deployed at:", entryPoint);

        if (permit2 == address(0)) {
            console.log("Warning: Permit2 address not set - please deploy it separately before using the script");
            revert InvalidAddress();
        }

        return WalletConfig({
            permit2: IPermit2(permit2), // Can be deployed separately and set later using Uniswap's script from the
                // permit2 lib. We didn't include it here because it requires strictly 0.8.17 Solidity version.
            entryPoint: entryPoint,
            atomWarden: atomWarden,
            atomWalletBeacon: atomWalletBeacon,
            atomWalletFactory: atomWalletFactory
        });
    }

    function _getVaultFees() internal pure returns (VaultFees memory) {
        return VaultFees({
            entryFee: 100, // 1%
            exitFee: 100, // 1%
            protocolFee: 100 // 1%
         });
    }

    function _getBondingCurveConfig() internal view returns (BondingCurveConfig memory) {
        return BondingCurveConfig({
            registry: bondingCurveRegistry,
            defaultCurveId: 1 // Linear curve
         });
    }
}
