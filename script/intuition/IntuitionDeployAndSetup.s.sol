// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "src/interfaces/IPermit2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { Trust } from "src/Trust.sol";
import { TestTrust } from "tests/mocks/TestTrust.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";

/*
LOCAL
forge script script/intuition/IntuitionDeployAndSetup.s.sol:IntuitionDeployAndSetup \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/intuition/IntuitionDeployAndSetup.s.sol:IntuitionDeployAndSetup \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow
*/

contract IntuitionDeployAndSetup is SetupScript {
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    address public MIGRATOR;

    uint32 internal BASE_METALAYER_RECIPIENT_DOMAIN = 8453;

    address public BASE_EMISSIONS_CONTROLLER;

    GeneralConfig internal generalConfig;
    AtomConfig internal atomConfig;
    TripleConfig internal tripleConfig;
    WalletConfig internal walletConfig;
    VaultFees internal vaultFees;
    BondingCurveConfig internal bondingCurveConfig;

    function setUp() public override {
        super.setUp();

        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
            MIGRATOR = vm.envAddress("ANVIL_MULTI_VAULT_ROLE_MIGRATOR");
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
            MIGRATOR = vm.envAddress("INTUITION_SEPOLIA_MULTI_VAULT_ROLE_MIGRATOR");
        } else if (block.chainid == vm.envUint("INTUITION_MAINNET_CHAIN_ID")) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_MAINNET_BASE_EMISSIONS_CONTROLLER");
            MIGRATOR = vm.envAddress("INTUITION_MAINNET_MULTI_VAULT_ROLE_MIGRATOR");
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        // Deploy Trust token if not provided
        if (TRUST_TOKEN == address(0)) {
            trust = Trust(_deployTrustToken());
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
        contractInfo("SatelliteEmissionsController", address(satelliteEmissionsController));
        contractInfo("TrustBonding", address(trustBonding));
        contractInfo("BondingCurveRegistry", address(bondingCurveRegistry));
        contractInfo("LinearCurve", address(linearCurve));
        contractInfo("OffsetProgressiveCurve", address(offsetProgressiveCurve));
        contractInfo("ProgressiveCurve", address(progressiveCurve));
        _exportContractAddresses();
    }

    function _deployMultiVaultSystem() internal {
        // Prepare MultiVault init data
        _prepareMultiVaultInitData();

        bytes memory multiVaultInitData = abi.encodeWithSelector(
            MultiVault.initialize.selector,
            generalConfig,
            atomConfig,
            tripleConfig,
            walletConfig,
            vaultFees,
            bondingCurveConfig
        );

        // Deploy new MultiVault implementation and proxy
        MultiVaultMigrationMode multiVaultImpl = new MultiVaultMigrationMode();
        info("MultiVaultMigrationMode Implementation", address(multiVaultImpl));

        TransparentUpgradeableProxy multiVaultProxy =
            new TransparentUpgradeableProxy(address(multiVaultImpl), ADMIN, multiVaultInitData);
        multiVault = MultiVault(address(multiVaultProxy));

        // Grant MIGRATOR_ROLE to the migrator address
        IAccessControl(address(multiVault)).grantRole(MIGRATOR_ROLE, MIGRATOR);
        console2.log("MIGRATOR_ROLE granted to:", MIGRATOR);

        // Deploy AtomWalletFactory implementation and proxy
        AtomWalletFactory atomWalletFactoryImpl = new AtomWalletFactory();
        info("AtomWalletFactory Implementation", address(atomWalletFactoryImpl));

        TransparentUpgradeableProxy atomWalletFactoryProxy = new TransparentUpgradeableProxy(
            address(atomWalletFactoryImpl),
            ADMIN,
            abi.encodeWithSelector(AtomWalletFactory.initialize.selector, address(multiVault)) // encoded initData
        );
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));
        info("AtomWalletFactory Proxy", address(atomWalletFactoryProxy));

        // Deploy SatelliteEmissionsController implementation and proxy
        SatelliteEmissionsController satelliteEmissionsControllerImpl = new SatelliteEmissionsController();
        info("SatelliteEmissionsController Implementation", address(satelliteEmissionsControllerImpl));

        // Initialize SatelliteEmissionsController with proper struct parameters
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            recipientAddress: BASE_EMISSIONS_CONTROLLER, // this will be removed later - can stay as is for now
            hubOrSpoke: METALAYER_HUB_OR_SPOKE, // placeholder metaERC20Hub
            recipientDomain: BASE_METALAYER_RECIPIENT_DOMAIN,
            gasLimit: METALAYER_GAS_LIMIT,
            finalityState: FinalityState.FINALIZED
        });

        CoreEmissionsControllerInit memory coreEmissionsInit = CoreEmissionsControllerInit({
            startTimestamp: EMISSIONS_START_TIMESTAMP,
            emissionsLength: EMISSIONS_LENGTH,
            emissionsPerEpoch: EMISSIONS_PER_EPOCH,
            emissionsReductionCliff: EMISSIONS_REDUCTION_CLIFF,
            emissionsReductionBasisPoints: EMISSIONS_REDUCTION_BASIS_POINTS
        });

        bytes memory satelliteInitData = abi.encodeWithSelector(
            SatelliteEmissionsController.initialize.selector,
            ADMIN,
            BASE_EMISSIONS_CONTROLLER,
            metaERC20DispatchInit,
            coreEmissionsInit
        );

        TransparentUpgradeableProxy satelliteEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(satelliteEmissionsControllerImpl), ADMIN, satelliteInitData);
        satelliteEmissionsController = SatelliteEmissionsController(payable(satelliteEmissionsControllerProxy));
        info("SatelliteEmissionsController Proxy", address(satelliteEmissionsControllerProxy));

        // Deploy TrustBonding implementation and proxy
        TrustBonding trustBondingImpl = new TrustBonding();
        info("TrustBonding Implementation", address(trustBondingImpl));

        bytes memory trustBondingInitData = abi.encodeWithSelector(
            TrustBonding.initialize.selector,
            ADMIN, // owner
            address(trust), // WTRUST token if deploying on Intuition Sepolia
            BONDING_EPOCH_LENGTH, // epochLength
            address(multiVault), // multiVault
            address(satelliteEmissionsController),
            BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound
            BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound
        );

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBondingImpl), ADMIN, trustBondingInitData);
        trustBonding = TrustBonding(address(trustBondingProxy));
        info("TrustBonding Proxy", address(trustBondingProxy));

        // Set TrustBonding address in SatelliteEmissionsController only if we are not on Intuition mainnet (on mainnet,
        // this will be done through an admin Safe)
        if (block.chainid != vm.envUint("INTUITION_MAINNET_CHAIN_ID")) {
            satelliteEmissionsController.setTrustBonding(address(trustBonding));
        }

        // Deploy BondingCurveRegistry
        bondingCurveRegistry = new BondingCurveRegistry(ADMIN);
        info("BondingCurveRegistry", address(bondingCurveRegistry));

        // Deploy bonding curves
        linearCurve = new LinearCurve("Linear Bonding Curve");
        offsetProgressiveCurve = new OffsetProgressiveCurve(
            "Offset Progressive Bonding Curve", OFFSET_PROGRESSIVE_CURVE_SLOPE, OFFSET_PROGRESSIVE_CURVE_OFFSET
        );
        progressiveCurve = new ProgressiveCurve("Progressive Bonding Curve", PROGRESSIVE_CURVE_SLOPE);
        info("LinearCurve", address(linearCurve));
        info("OffsetProgressiveCurve", address(offsetProgressiveCurve));
        info("ProgressiveCurve", address(progressiveCurve));

        // Add curves to registry
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));
    }

    function _prepareMultiVaultInitData() internal {
        generalConfig = GeneralConfig({
            admin: ADMIN,
            protocolMultisig: PROTOCOL_MULTISIG,
            feeDenominator: FEE_DENOMINATOR,
            trustBonding: address(trustBonding),
            minDeposit: MIN_DEPOSIT,
            minShare: MIN_SHARES,
            atomDataMaxLength: ATOM_DATA_MAX_LENGTH,
            decimalPrecision: DECIMAL_PRECISION
        });

        atomConfig = AtomConfig({
            atomCreationProtocolFee: ATOM_CREATION_PROTOCOL_FEE,
            atomWalletDepositFee: ATOM_WALLET_DEPOSIT_FEE
        });

        tripleConfig = TripleConfig({
            tripleCreationProtocolFee: TRIPLE_CREATION_PROTOCOL_FEE,
            totalAtomDepositsOnTripleCreation: TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            atomDepositFractionForTriple: ATOM_DEPOSIT_FRACTION_FOR_TRIPLE
        });

        walletConfig = WalletConfig({
            permit2: IPermit2(address(0)),
            entryPoint: address(0),
            atomWarden: address(0),
            atomWalletBeacon: address(0),
            atomWalletFactory: address(atomWalletFactory)
        });

        vaultFees = VaultFees({ entryFee: ENTRY_FEE, exitFee: EXIT_FEE, protocolFee: PROTOCOL_FEE });

        bondingCurveConfig = BondingCurveConfig({ registry: address(bondingCurveRegistry), defaultCurveId: 1 });
    }
}
