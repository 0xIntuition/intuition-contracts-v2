// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {AtomWalletFactory} from "src/v2/AtomWalletFactory.sol";
import {BondingCurveRegistry} from "src/curves/BondingCurveRegistry.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {
    IMultiVaultConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    WrapperConfig
} from "src/interfaces/IMultiVaultConfig.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {LinearCurve} from "src/curves/LinearCurve.sol";
import {MultiVault} from "src/MultiVault.sol";
import {MultiVaultConfig} from "src/v2/MultiVaultConfig.sol";
import {OffsetProgressiveCurve} from "src/curves/OffsetProgressiveCurve.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {WrappedERC20} from "src/v2/WrappedERC20.sol";
import {WrappedERC20Factory} from "src/v2/WrappedERC20Factory.sol";

import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract DeployV2 is Script {
    /// @notice Constants
    address public admin = vm.envAddress("ADMIN");
    address public protocolMultisig = vm.envAddress("PROTOCOL_MULTISIG");
    address public atomWarden = vm.envAddress("ATOM_WARDEN");
    address public migrator = vm.envAddress("MIGRATOR");
    uint256 public constant initialTrust = 1_000_000 * 1e18; // 1 million TRUST tokens to mint for testing (testnet-only)
    uint256 public constant maxAnnualEmission = 100_000_000 * 1e18; // 100 million TRUST
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2 address
    address public constant entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base
    uint256 public constant epochLength = 2 weeks; // 2 weeks in seconds
    uint256 public constant systemUtilizationLowerBound = 2_500; // 25% utilization
    uint256 public constant personalUtilizationLowerBound = 2_500; // 25% utilization
    bytes32 public constant merkleRoot = 0x139108d0708628265813796f3ee047525c413d5c29953de8f2fe01c0f1cca35d; // precomputed Merkle root for testing the airdrop claim

    /// @notice Config structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;
    VaultFees public vaultFees;
    BondingCurveConfig public bondingCurveConfig;
    WrapperConfig public wrapperConfig;

    /// @notice Core contracts
    MockTrust public trustToken;
    TrustBonding public trustBonding;
    MultiVault public multiVault;
    MultiVaultConfig public multiVaultConfig;
    AtomWallet public atomWallet;
    AtomWalletFactory public atomWalletFactory;
    UpgradeableBeacon public atomWalletBeacon;
    BondingCurveRegistry public bondingCurveRegistry;
    WrappedERC20 public wrappedERC20;
    UpgradeableBeacon public wrappedERC20Beacon;
    WrappedERC20Factory public wrappedERC20Factory;

    /// @notice Custom errors
    error UnsupportedChainId();

    function run() external {
        vm.startBroadcast();

        // Allow the script to run only on Base Sepolia to prevent accidental deployments on mainnet
        if (block.chainid != 84532) {
            revert UnsupportedChainId();
        }

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.log("AtomWallet implementation address: ", address(atomWallet));

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), admin);
        console.log("AtomWalletBeacon address: ", address(atomWalletBeacon));

        // deloy the AtomWalletFactory contract
        atomWalletFactory = new AtomWalletFactory();
        TransparentUpgradeableProxy atomWalletFactoryProxy =
            new TransparentUpgradeableProxy(address(atomWalletFactory), admin, "");
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));
        console.log("AtomWalletFactory proxy address: ", address(atomWalletFactoryProxy));

        // deploy WrappedERC20 implementation contract
        wrappedERC20 = new WrappedERC20();
        console.log("WrappedERC20 implementation address: ", address(wrappedERC20));

        // deploy WrappedERC20Beacon pointing to the WrappedERC20 implementation contract
        wrappedERC20Beacon = new UpgradeableBeacon(address(wrappedERC20), admin);
        console.log("WrappedERC20Beacon address: ", address(wrappedERC20Beacon));

        // deploy the WrappedERC20Factory contract
        wrappedERC20Factory = new WrappedERC20Factory();
        TransparentUpgradeableProxy wrappedERC20FactoryProxy =
            new TransparentUpgradeableProxy(address(wrappedERC20Factory), admin, "");
        wrappedERC20Factory = WrappedERC20Factory(address(wrappedERC20FactoryProxy));
        console.log("WrappedERC20Factory proxy address: ", address(wrappedERC20FactoryProxy));

        // deploy BondingCurveRegistry and register a basic linear curve and one alternative curve
        bondingCurveRegistry = new BondingCurveRegistry(admin);
        LinearCurve linearCurve = new LinearCurve("Linear Curve");
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2, 5e35);
        console.log("LinearCurve address: ", address(linearCurve));
        console.log("OffsetProgressiveCurve address: ", address(offsetProgressiveCurve));

        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        console.log("BondingCurveRegistry address: ", address(bondingCurveRegistry));

        // deploy the Trust token and mint some tokens for testing to the admin
        trustToken = new MockTrust("Intuition", "TRUST", maxAnnualEmission);
        trustToken.mint(admin, initialTrust);
        console.log("Mock Trust token address: ", address(trustToken));

        // deploy the TrustBonding contract
        trustBonding = new TrustBonding();
        console.log("TrustBonding implementation address: ", address(trustBonding));
        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), admin, "");
        trustBonding = TrustBonding(address(trustBondingProxy));
        console.log("TrustBonding proxy address: ", address(trustBondingProxy));

        // define the config structs
        generalConfig = GeneralConfig({
            admin: admin,
            protocolMultisig: protocolMultisig,
            feeDenominator: 10_000,
            trust: address(trustToken),
            trustBonding: address(trustBonding),
            minDeposit: 0.1 * 1e18,
            minShare: 1e6,
            atomDataMaxLength: 250,
            decimalPrecision: 1e18,
            baseURI: "https://api.intuition.systems/",
            protocolFeeDistributionEnabled: false
        });

        atomConfig = AtomConfig({atomCreationProtocolFee: 0.01 * 1e18, atomWalletDepositFee: 100});

        tripleConfig = TripleConfig({
            tripleCreationProtocolFee: 0.01 * 1e18,
            totalAtomDepositsOnTripleCreation: 0.009 * 1e18,
            atomDepositFractionForTriple: 300
        });

        walletConfig = WalletConfig({
            permit2: IPermit2(address(permit2)),
            entryPoint: address(entryPoint),
            atomWarden: atomWarden,
            atomWalletBeacon: address(atomWalletBeacon),
            atomWalletFactory: address(atomWalletFactory)
        });

        vaultFees = VaultFees({entryFee: 500, exitFee: 500, protocolFee: 100});

        bondingCurveConfig = BondingCurveConfig({registry: address(bondingCurveRegistry), defaultCurveId: 1});

        wrapperConfig = WrapperConfig({
            wrappedERC20Beacon: address(wrappedERC20Beacon),
            wrappedERC20Factory: address(wrappedERC20Factory)
        });

        // deploy the MultiVaultConfig contract
        multiVaultConfig = new MultiVaultConfig();
        console.log("MultiVaultConfig implementation address: ", address(multiVaultConfig));
        TransparentUpgradeableProxy multiVaultConfigProxy =
            new TransparentUpgradeableProxy(address(multiVaultConfig), admin, "");
        multiVaultConfig = MultiVaultConfig(address(multiVaultConfigProxy));
        console.log("MultiVaultConfig proxy address: ", address(multiVaultConfigProxy));

        // deploy the MultiVault contract
        multiVault = new MultiVault();
        console.log("MultiVault implementation address: ", address(multiVault));
        TransparentUpgradeableProxy multiVaultProxy = new TransparentUpgradeableProxy(address(multiVault), admin, "");
        multiVault = MultiVault(address(multiVaultProxy));
        console.log("MultiVault proxy address: ", address(multiVaultProxy));

        // initialize the MultiVaultConfig contract
        multiVaultConfig.initialize(
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig,
            wrapperConfig,
            migrator,
            address(multiVault)
        );

        // grant the TIMELOCK_ROLE to the admin
        multiVaultConfig.grantRole(multiVaultConfig.TIMELOCK_ROLE(), admin);

        // initialize the MultiVault contract
        multiVault.initialize(address(multiVaultConfig));

        // sync the configuration to the MultiVault contract
        multiVault.syncConfig();

        // initialize the AtomWalletFactory contract
        atomWalletFactory.initialize(address(multiVault));

        // initialize the WrappedERC20Factory contract
        wrappedERC20Factory.initialize(address(multiVault));

        // initialize the TrustBonding contract
        trustBonding.initialize(admin, address(trustToken), epochLength, block.timestamp + 10 minutes);

        // reinitialize the TrustBonding contract with MultiVault and system utilization bounds
        trustBonding.reinitialize(address(multiVault), systemUtilizationLowerBound, personalUtilizationLowerBound);

        // max approve TRUST to the TrustBonding and MultiVault contracts
        trustToken.approve(address(trustBonding), type(uint256).max);
        trustToken.approve(address(multiVault), type(uint256).max);

        // mint TRUST to the merkle distributor contract for testing the airdrop claim
        // trustToken.mint(address(trustVestedMerkleDistributor), 2_000 * 1e18); // 2,000 TRUST

        vm.stopBroadcast();
    }
}
