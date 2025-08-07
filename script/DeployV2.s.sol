// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";
import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
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
    uint256 public chainId;
    address public admin = vm.envAddress("ADMIN");
    address public protocolMultisig = vm.envAddress("PROTOCOL_MULTISIG");
    address public atomWarden = vm.envAddress("ATOM_WARDEN");
    address public migrator = vm.envAddress("MIGRATOR");
    address public trustTokenAddress = vm.envAddress("TRUST_TOKEN_ADDRESS");
    uint256 public constant initialTrust = 1_000_000 * 1e18; // 1 million TRUST tokens to mint for testing (testnet-only)
    uint256 public constant maxAnnualEmission = 75_000_000 * 1e18; // 100 million TRUST
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2 address on Base
    address public constant entryPointAddress = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base
    uint256 public constant epochLength = 2 weeks; // 2 weeks in seconds
    uint256 public startTimestamp; // timestamp when the bonding starts (set the exact timestamp when deploying to mainnet)
    uint256 public constant systemUtilizationLowerBound = 2_500; // 25% utilization
    uint256 public constant personalUtilizationLowerBound = 2_500; // 25% utilization

    /// @notice Config structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;
    VaultFees public vaultFees;
    BondingCurveConfig public bondingCurveConfig;
    WrapperConfig public wrapperConfig;

    /// @notice Core contracts
    TimelockController public parametersTimelock;
    TimelockController public upgradesTimelock;
    EntryPoint public entryPoint;
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

        // Get the chain ID
        chainId = block.chainid;

        // Allow the script to run only on Base mainnet and Base Sepolia to prevent accidental deployments on other chains
        if (chainId != 8453 && chainId != 84532) {
            revert UnsupportedChainId();
        }

        address[] memory proposers = new address[](1);
        proposers[0] = admin;

        address[] memory executors = new address[](1);
        executors[0] = address(0); // allow anyone to execute the transactions (open role)

        // deploy the parameters timelock contract
        parametersTimelock = new TimelockController(
            chainId == 8453 ? 3 days : 1 minutes, // shorter timelock for testnet
            proposers,
            executors,
            address(0)
        );
        console.log("Parameters Timelock address: ", address(parametersTimelock));

        // deploy the upgrades timelock contract
        upgradesTimelock = new TimelockController(
            chainId == 8453 ? 7 days : 1 minutes, // shorter timelock for testnet
            proposers,
            executors,
            address(0)
        );
        console.log("Upgrades Timelock address: ", address(upgradesTimelock));

        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();
        console.log("AtomWallet implementation address: ", address(atomWallet));

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), address(upgradesTimelock));
        console.log("AtomWalletBeacon address: ", address(atomWalletBeacon));

        // deloy the AtomWalletFactory contract
        atomWalletFactory = new AtomWalletFactory();
        TransparentUpgradeableProxy atomWalletFactoryProxy =
            new TransparentUpgradeableProxy(address(atomWalletFactory), address(upgradesTimelock), "");
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));
        console.log("AtomWalletFactory proxy address: ", address(atomWalletFactoryProxy));

        // deploy WrappedERC20 implementation contract
        wrappedERC20 = new WrappedERC20();
        console.log("WrappedERC20 implementation address: ", address(wrappedERC20));

        // deploy WrappedERC20Beacon pointing to the WrappedERC20 implementation contract
        wrappedERC20Beacon = new UpgradeableBeacon(address(wrappedERC20), address(upgradesTimelock));
        console.log("WrappedERC20Beacon address: ", address(wrappedERC20Beacon));

        // deploy the WrappedERC20Factory contract
        wrappedERC20Factory = new WrappedERC20Factory();
        TransparentUpgradeableProxy wrappedERC20FactoryProxy =
            new TransparentUpgradeableProxy(address(wrappedERC20Factory), address(upgradesTimelock), "");
        wrappedERC20Factory = WrappedERC20Factory(address(wrappedERC20FactoryProxy));
        console.log("WrappedERC20Factory proxy address: ", address(wrappedERC20FactoryProxy));

        // deploy BondingCurveRegistry and register a basic linear curve and one alternative curve
        bondingCurveRegistry = new BondingCurveRegistry(msg.sender); // set deployer as the initial owner
        LinearCurve linearCurve = new LinearCurve("Linear Curve");
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2, 5e35);
        console.log("LinearCurve address: ", address(linearCurve));
        console.log("OffsetProgressiveCurve address: ", address(offsetProgressiveCurve));

        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        console.log("BondingCurveRegistry address: ", address(bondingCurveRegistry));

        // transfer ownership of the BondingCurveRegistry to the admin
        bondingCurveRegistry.transferOwnership(admin);
        console.log("BondingCurveRegistry ownership transferred to admin: ", admin);

        // deploy the mock Trust token if on Base Sepolia (chainId == 84532); otherwise, use the existing Trust token address
        if (chainId == 84_532) {
            // deploy the Trust token and mint some tokens for testing to the admin
            trustToken = new MockTrust("Intuition", "TRUST", maxAnnualEmission);
            trustToken.mint(admin, initialTrust);
            console.log("Mock Trust token address: ", address(trustToken));

            trustTokenAddress = address(trustToken);
        }

        // deploy the TrustBonding contract
        trustBonding = new TrustBonding();
        console.log("TrustBonding implementation address: ", address(trustBonding));
        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), address(upgradesTimelock), "");
        trustBonding = TrustBonding(address(trustBondingProxy));
        console.log("TrustBonding proxy address: ", address(trustBondingProxy));

        // define the config structs
        generalConfig = GeneralConfig({
            admin: admin,
            protocolMultisig: protocolMultisig,
            feeDenominator: 10_000,
            trust: trustTokenAddress,
            trustBonding: address(trustBonding),
            minDeposit: 0.1 * 1e18,
            minShare: 1e7,
            atomDataMaxLength: 250,
            decimalPrecision: 1e18,
            baseURI: "https://api.intuition.systems/", // TODO: Remove this
            protocolFeeDistributionEnabled: false
        });

        atomConfig = AtomConfig({atomCreationProtocolFee: 0.1 * 1e18, atomWalletDepositFee: 100});

        tripleConfig = TripleConfig({
            tripleCreationProtocolFee: 0.1 * 1e18,
            totalAtomDepositsOnTripleCreation: 0,
            atomDepositFractionForTriple: 300
        });

        if (chainId == 84_532) {
            entryPoint = new EntryPoint(); // deploy a new EntryPoint for testnet, otherwise use the existing one on Base mainnet
            console.log("EntryPoint deployed at: ", address(entryPoint));
        }

        walletConfig = WalletConfig({
            permit2: IPermit2(address(permit2)), // TODO: Remove this for L3 deployment (or deploy Permit2 on L3)
            entryPoint: chainId == 8453 ? entryPointAddress : address(entryPoint), // use the existing EntryPoint on Base mainnet
            atomWarden: atomWarden,
            atomWalletBeacon: address(atomWalletBeacon),
            atomWalletFactory: address(atomWalletFactory)
        });

        vaultFees = VaultFees({entryFee: 100, exitFee: 100, protocolFee: 100});

        bondingCurveConfig = BondingCurveConfig({registry: address(bondingCurveRegistry), defaultCurveId: 1});

        wrapperConfig = WrapperConfig({
            wrappedERC20Beacon: address(wrappedERC20Beacon),
            wrappedERC20Factory: address(wrappedERC20Factory)
        });

        // deploy the MultiVaultConfig contract
        multiVaultConfig = new MultiVaultConfig();
        console.log("MultiVaultConfig implementation address: ", address(multiVaultConfig));
        TransparentUpgradeableProxy multiVaultConfigProxy =
            new TransparentUpgradeableProxy(address(multiVaultConfig), address(upgradesTimelock), "");
        multiVaultConfig = MultiVaultConfig(address(multiVaultConfigProxy));
        console.log("MultiVaultConfig proxy address: ", address(multiVaultConfigProxy));

        // deploy the MultiVault contract
        multiVault = new MultiVault();
        console.log("MultiVault implementation address: ", address(multiVault));
        TransparentUpgradeableProxy multiVaultProxy =
            new TransparentUpgradeableProxy(address(multiVault), address(upgradesTimelock), "");
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

        // grant the TIMELOCK_ROLE to the parameters timelock contract
        multiVaultConfig.grantRole(multiVaultConfig.TIMELOCK_ROLE(), address(parametersTimelock));

        // initialize the MultiVault contract
        multiVault.initialize(address(multiVaultConfig));

        // sync the configuration to the MultiVault contract
        multiVault.syncConfig();

        // initialize the AtomWalletFactory contract
        atomWalletFactory.initialize(address(multiVault));

        // initialize the WrappedERC20Factory contract
        wrappedERC20Factory.initialize(address(multiVault));

        // initialize the TrustBonding contract
        startTimestamp = chainId == 8453 ? startTimestamp : block.timestamp + 10 minutes; // start in 10 minutes if not deploying to mainnet
        trustBonding.initialize(admin, trustTokenAddress, epochLength, startTimestamp);

        // NOTE: Once you're ready to enable utilization-based rewards, reinitialize the TrustBonding contract with the following params from the admin Safe:
        // trustBonding.reinitialize(address(multiVault), systemUtilizationLowerBound, personalUtilizationLowerBound);

        vm.stopBroadcast();
    }
}
