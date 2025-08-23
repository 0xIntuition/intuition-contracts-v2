// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";

import { BaseScript } from "./Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "src/interfaces/IPermit2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Trust } from "src/Trust.sol";
import { TestTrust } from "tests/mocks/TestTrust.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { SateliteEmissionsController } from "src/protocol/emissions/SateliteEmissionsController.sol";
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
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

/*
LOCAL
forge script script/IntuitionDeploy.s.sol:IntuitionDeploy \
--rpc-url geth \
--broadcast

TESTNET
forge script script/IntuitionDeploy.s.sol:IntuitionDeploy \
--rpc-url intuition_sepolia \
--broadcast
*/

contract IntuitionDeploy is BaseScript {
    // Configuration variables with defaults

    // General Config
    address internal ADMIN;
    address internal PROTOCOL_MULTISIG;
    address internal TRUST_TOKEN;
    uint8 internal DECIMAL_PRECISION = 18;
    uint256 internal FEE_DENOMINATOR = 10_000;
    uint256 internal MIN_DEPOSIT = 1e17; // 0.1 Trust
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

    // TrustBonding configuration
    uint256 internal EPOCH_LENGTH = 2 weeks;
    uint256 internal SYSTEM_UTILIZATION_LOWER_BOUND = 2500; // 50%
    uint256 internal PERSONAL_UTILIZATION_LOWER_BOUND = 2500; // 30%

    // Curve Configurations
    uint256 internal PROGRESSIVE_CURVE_SLOPE = 1e15; // 0.001 slope

    // Emissions Configurations
    uint256 internal MAX_ANNUAL_EMISSION = 10e18; // 10 Trust
    uint256 internal INITIAL_SUPPLY = 1000e18; // 1k Trust

    // Deployed contracts
    Trust public trust;
    MultiVault public multiVault;
    AtomWalletFactory public atomWalletFactory;
    SateliteEmissionsController public sateliteEmissionsController;
    TrustBonding public trustBonding;
    BondingCurveRegistry public bondingCurveRegistry;
    LinearCurve public linearCurve;
    ProgressiveCurve public progressiveCurve;

    function setUp() public {
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
            TRUST_TOKEN = vm.envOr("INTUITION_SEPOLIA_TRUST_TOKEN", address(0));
            PROTOCOL_MULTISIG = vm.envOr("INTUITION_SEPOLIA_PROTOCOL_MULTISIG", ADMIN);
        } else {
            revert("Unsupported chain for broadcasting");
        }

        // Load optional configuration from environment
        MIN_SHARES = vm.envOr("MIN_SHARES", MIN_SHARES);
        MIN_DEPOSIT = vm.envOr("MIN_DEPOSIT", MIN_DEPOSIT);
        ATOM_CREATION_PROTOCOL_FEE = vm.envOr("ATOM_CREATION_PROTOCOL_FEE", ATOM_CREATION_PROTOCOL_FEE);
        ATOM_WALLET_DEPOSIT_FEE = vm.envOr("ATOM_WALLET_DEPOSIT_FEE", ATOM_WALLET_DEPOSIT_FEE);
        TRIPLE_CREATION_PROTOCOL_FEE = vm.envOr("TRIPLE_CREATION_PROTOCOL_FEE", TRIPLE_CREATION_PROTOCOL_FEE);
        ENTRY_FEE = vm.envOr("ENTRY_FEE", ENTRY_FEE);
        EXIT_FEE = vm.envOr("EXIT_FEE", EXIT_FEE);
        PROTOCOL_FEE = vm.envOr("PROTOCOL_FEE", PROTOCOL_FEE);

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

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        // Deploy Trust token if not provided
        if (TRUST_TOKEN == address(0)) {
            trust = _deployTrustToken();
        } else {
            trust = Trust(TRUST_TOKEN);
        }

        // Deploy the complete MultiVault system
        _deployMultiVaultSystem();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("Trust", address(trust));
        contractInfo("MultiVault", address(multiVault));
        contractInfo("AtomWalletFactory", address(atomWalletFactory));
        contractInfo("SateliteEmissionsController", address(sateliteEmissionsController));
        contractInfo("TrustBonding", address(trustBonding));
        contractInfo("BondingCurveRegistry", address(bondingCurveRegistry));
        contractInfo("LinearCurve", address(linearCurve));
        contractInfo("ProgressiveCurve", address(progressiveCurve));
        _exportContractAddresses();
    }

    function _exportContractAddresses() internal view {
        console2.log("");
        console2.log("EXPORT JSON: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=");
        console2.log("{");
        console2.log(string.concat("  Trust: { [", "intuitionSepolia.id", "]: '", vm.toString(address(trust)), "' },"));
        console2.log(
            string.concat("  MultiVault: { [", "intuitionSepolia.id", "]: '", vm.toString(address(multiVault)), "' },")
        );
        console2.log(
            string.concat(
                "  AtomWalletFactory: { [",
                "intuitionSepolia.id",
                "]: '",
                vm.toString(address(atomWalletFactory)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  SateliteEmissionsController: { [",
                "intuitionSepolia.id",
                "]: '",
                vm.toString(address(sateliteEmissionsController)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  TrustBonding: { [", "intuitionSepolia.id", "]: '", vm.toString(address(trustBonding)), "' },"
            )
        );
        console2.log(
            string.concat(
                "  BondingCurveRegistry: { [",
                "intuitionSepolia.id",
                "]: '",
                vm.toString(address(bondingCurveRegistry)),
                "' },"
            )
        );
        console2.log(
            string.concat(
                "  LinearCurve: { [", "intuitionSepolia.id", "]: '", vm.toString(address(linearCurve)), "' },"
            )
        );
        console2.log(
            string.concat(
                "  ProgressiveCurve: { [", "intuitionSepolia.id", "]: '", vm.toString(address(progressiveCurve)), "' }"
            )
        );
        console2.log("}");
    }

    function _deployTrustToken() internal returns (Trust) {
        // Deploy Trust implementation
        Trust trustImpl = new Trust();
        info("Trust Implementation", address(trustImpl));

        // Deploy Trust proxy
        TransparentUpgradeableProxy trustProxy = new TransparentUpgradeableProxy(address(trustImpl), ADMIN, "");
        Trust trustToken = Trust(address(trustProxy));
        info("Trust Proxy", address(trustProxy));

        // Initialize Trust contract
        trustToken.reinitialize(
            ADMIN, // admin
            ADMIN, // initial minter
            block.timestamp + 100 // startTimestamp
        );
        return trustToken;
    }

    function _deployMultiVaultSystem() internal {
        // Deploy MultiVault implementation and proxy
        MultiVault multiVaultImpl = new MultiVault();
        info("MultiVault Implementation", address(multiVaultImpl));

        TransparentUpgradeableProxy multiVaultProxy =
            new TransparentUpgradeableProxy(address(multiVaultImpl), ADMIN, "");
        multiVault = MultiVault(address(multiVaultProxy));
        info("MultiVault Proxy", address(multiVaultProxy));

        // Deploy AtomWalletFactory implementation and proxy
        AtomWalletFactory atomWalletFactoryImpl = new AtomWalletFactory();
        info("AtomWalletFactory Implementation", address(atomWalletFactoryImpl));

        TransparentUpgradeableProxy atomWalletFactoryProxy =
            new TransparentUpgradeableProxy(address(atomWalletFactoryImpl), ADMIN, "");
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));
        info("AtomWalletFactory Proxy", address(atomWalletFactoryProxy));

        // Deploy SateliteEmissionsController implementation and proxy
        SateliteEmissionsController sateliteEmissionsControllerImpl = new SateliteEmissionsController();
        info("SateliteEmissionsController Implementation", address(sateliteEmissionsControllerImpl));

        TransparentUpgradeableProxy sateliteEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(sateliteEmissionsControllerImpl), ADMIN, "");
        sateliteEmissionsController = SateliteEmissionsController(address(sateliteEmissionsControllerProxy));
        info("SateliteEmissionsController Proxy", address(sateliteEmissionsControllerProxy));

        // Deploy TrustBonding implementation and proxy
        TrustBonding trustBondingImpl = new TrustBonding();
        info("TrustBonding Implementation", address(trustBondingImpl));

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBondingImpl), ADMIN, "");
        trustBonding = TrustBonding(address(trustBondingProxy));
        info("TrustBonding Proxy", address(trustBondingProxy));

        // Deploy BondingCurveRegistry
        bondingCurveRegistry = new BondingCurveRegistry(ADMIN);
        info("BondingCurveRegistry", address(bondingCurveRegistry));

        // Deploy bonding curves
        linearCurve = new LinearCurve("Linear Bonding Curve");
        progressiveCurve = new ProgressiveCurve("Progressive Bonding Curve", PROGRESSIVE_CURVE_SLOPE);
        info("LinearCurve", address(linearCurve));
        info("ProgressiveCurve", address(progressiveCurve));

        // Add curves to registry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));

        // Initialize contracts
        _initializeContracts();
    }

    function _initializeContracts() internal {
        // Initialize AtomWalletFactory
        atomWalletFactory.initialize(address(multiVault));

        sateliteEmissionsController.initialize(
            ADMIN, address(trustBonding)
        );

        // Initialize TrustBonding
        trustBonding.initialize(
            ADMIN, // owner
            address(trust), // trustToken
            EPOCH_LENGTH, // epochLength
            block.timestamp + 20, // startTimestamp
            address(multiVault), // multiVault
            address(sateliteEmissionsController),
            SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound
            PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound
        );

        // Prepare configuration structs
        GeneralConfig memory generalConfig = GeneralConfig({
            admin: ADMIN,
            protocolMultisig: PROTOCOL_MULTISIG,
            feeDenominator: FEE_DENOMINATOR,
            trustBonding: address(trustBonding),
            minDeposit: MIN_DEPOSIT,
            minShare: MIN_SHARES,
            atomDataMaxLength: ATOM_DATA_MAX_LENGTH,
            decimalPrecision: DECIMAL_PRECISION,
            protocolFeeDistributionEnabled: true
        });

        AtomConfig memory atomConfig = AtomConfig({
            atomCreationProtocolFee: ATOM_CREATION_PROTOCOL_FEE,
            atomWalletDepositFee: ATOM_WALLET_DEPOSIT_FEE
        });

        TripleConfig memory tripleConfig = TripleConfig({
            tripleCreationProtocolFee: TRIPLE_CREATION_PROTOCOL_FEE,
            totalAtomDepositsOnTripleCreation: TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            atomDepositFractionForTriple: ATOM_DEPOSIT_FRACTION_FOR_TRIPLE
        });

        WalletConfig memory walletConfig = WalletConfig({
            permit2: IPermit2(address(0)),
            entryPoint: address(0),
            atomWarden: address(0),
            atomWalletBeacon: address(0),
            atomWalletFactory: address(atomWalletFactory)
        });

        VaultFees memory vaultFees = VaultFees({ entryFee: ENTRY_FEE, exitFee: EXIT_FEE, protocolFee: PROTOCOL_FEE });

        BondingCurveConfig memory bondingCurveConfig =
            BondingCurveConfig({ registry: address(bondingCurveRegistry), defaultCurveId: 1 });

        // Initialize MultiVault
        multiVault.initialize(generalConfig, atomConfig, tripleConfig, walletConfig, vaultFees, bondingCurveConfig);
    }
}
