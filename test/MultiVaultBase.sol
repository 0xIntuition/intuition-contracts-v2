// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {AtomWalletFactory} from "src/v2/AtomWalletFactory.sol";
import {AtomWarden} from "src/utils/AtomWarden.sol";
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

contract MultiVaultBase is Test {
    /// @notice Constants
    uint256 public constant initialEth = 1000 ether;
    uint256 public constant oneToken = 1e18;
    uint256 public constant depositAmount = 1e17; // 0.1 TRUST
    uint256 public constant maxAnnualEmission = 100_000_000 * oneToken; // 100 million TRUST
    uint256 public constant initialTrust = 1000 * oneToken; // 1000 TRUST
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public rich = makeAddr("rich");
    address public admin = makeAddr("admin");
    address public protocolMultisig = makeAddr("protocolMultisig");
    address public migrator = makeAddr("migrator");
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2 address
    address public constant entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789; // EntryPoint on Base
    uint256 public constant epochLength = 2 weeks;
    uint256 public constant systemUtilizationLowerBound = 2_500; // 25% utilization
    uint256 public constant personalUtilizationLowerBound = 2_500; // 25% utilization
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000; // 100% in basis points
    uint256 public constant defaultSlippage = 1000; // 10% slippage
    uint256 public constant maxDelta = 0.01 ether; // 0.01 ETH

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
    AtomWarden public atomWarden;

    /// @notice Set up test environment
    function setUp() public virtual {
        // deploy AtomWallet implementation contract
        atomWallet = new AtomWallet();

        // deploy AtomWalletBeacon pointing to the AtomWallet implementation contract
        atomWalletBeacon = new UpgradeableBeacon(address(atomWallet), admin);

        // deloy the AtomWalletFactory contract
        atomWalletFactory = new AtomWalletFactory();
        TransparentUpgradeableProxy atomWalletFactoryProxy =
            new TransparentUpgradeableProxy(address(atomWalletFactory), admin, "");
        atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));

        // deploy WrappedERC20 implementation contract
        wrappedERC20 = new WrappedERC20();

        // deploy WrappedERC20Beacon pointing to the WrappedERC20 implementation contract
        wrappedERC20Beacon = new UpgradeableBeacon(address(wrappedERC20), admin);

        // deploy the WrappedERC20Factory contract
        wrappedERC20Factory = new WrappedERC20Factory();
        TransparentUpgradeableProxy wrappedERC20FactoryProxy =
            new TransparentUpgradeableProxy(address(wrappedERC20Factory), admin, "");
        wrappedERC20Factory = WrappedERC20Factory(address(wrappedERC20FactoryProxy));

        // deploy BondingCurveRegistry and register a basic linear curve and one alternative curve
        bondingCurveRegistry = new BondingCurveRegistry(admin);
        LinearCurve linearCurve = new LinearCurve("Linear Curve");
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve("Offset Progressive Curve", 2, 5e35);

        vm.startPrank(admin);
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        vm.stopPrank();

        // deploy the Trust token and mint some tokens for testing
        trustToken = new MockTrust("Intuition", "TRUST", maxAnnualEmission);
        trustToken.mint(address(this), initialTrust);
        trustToken.mint(alice, initialTrust);
        trustToken.mint(bob, initialTrust);
        trustToken.mint(rich, maxAnnualEmission);

        // deal ether for use in tests that call with value
        vm.deal(address(this), initialEth);
        vm.deal(bob, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(rich, 20000 ether);

        // deploy the TrustBonding contract
        trustBonding = new TrustBonding();
        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), admin, "");
        trustBonding = TrustBonding(address(trustBondingProxy));

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
            atomWarden: admin,
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
        TransparentUpgradeableProxy multiVaultConfigProxy =
            new TransparentUpgradeableProxy(address(multiVaultConfig), admin, "");
        multiVaultConfig = MultiVaultConfig(address(multiVaultConfigProxy));

        // deploy the MultiVault contract
        multiVault = new MultiVault();
        TransparentUpgradeableProxy multiVaultProxy = new TransparentUpgradeableProxy(address(multiVault), admin, "");
        multiVault = MultiVault(address(multiVaultProxy));

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

        // initialize the MultiVault contract
        multiVault.initialize(address(multiVaultConfig));

        // sync the configuration to the MultiVault contract
        multiVault.syncConfig();

        // initialize the AtomWalletFactory contract
        atomWalletFactory.initialize(address(multiVault));

        // initialize the WrappedERC20Factory contract
        wrappedERC20Factory.initialize(address(multiVault));

        // initialize the TrustBonding contract
        trustBonding.initialize(
            admin,
            address(trustToken),
            epochLength,
            block.timestamp + 1,
            address(multiVault),
            systemUtilizationLowerBound,
            personalUtilizationLowerBound
        );

        // deploy the AtomWarden contract
        atomWarden = new AtomWarden();
        TransparentUpgradeableProxy atomWardenProxy = new TransparentUpgradeableProxy(address(atomWarden), admin, "");
        atomWarden = AtomWarden(address(atomWardenProxy));

        // initialize the AtomWarden contract
        atomWarden.initialize(admin, address(multiVault));

        // set the AtomWarden contract as the walletConfig.atomWarden in the MultiVaultConfig
        vm.prank(admin);
        multiVaultConfig.setAtomWarden(address(atomWarden));

        // max approve TRUST token for MultiVault for alice, bob and admin
        vm.prank(alice);
        trustToken.approve(address(multiVault), type(uint256).max);
        vm.prank(bob);
        trustToken.approve(address(multiVault), type(uint256).max);
        vm.prank(admin);
        trustToken.approve(address(multiVault), type(uint256).max);

        // warp time just a bit to make sure first epoch in TrustBonding has started
        vm.warp(block.timestamp + 1);
    }

    /* =================================================== */
    /*                    HELPER FUNCTIONS                 */
    /* =================================================== */

    /// @notice returns the general configuration struct
    function getGeneralConfig() public view returns (GeneralConfig memory) {
        (
            address admin_,
            address protocolMultisig_,
            uint256 feeDenominator_,
            address trust_,
            address trustBonding_,
            uint256 minDeposit_,
            uint256 minShare_,
            uint256 atomDataMaxLength_,
            uint256 decimalPrecision_,
            string memory baseURI_,
            bool protocolFeeDistributionEnabled_
        ) = multiVault.generalConfig();

        return GeneralConfig({
            admin: admin_,
            protocolMultisig: protocolMultisig_,
            feeDenominator: feeDenominator_,
            trust: trust_,
            trustBonding: trustBonding_,
            minDeposit: minDeposit_,
            minShare: minShare_,
            atomDataMaxLength: atomDataMaxLength_,
            decimalPrecision: decimalPrecision_,
            baseURI: baseURI_,
            protocolFeeDistributionEnabled: protocolFeeDistributionEnabled_
        });
    }

    /// @notice returns the atom configuration struct
    function getAtomConfig() public view returns (AtomConfig memory) {
        (uint256 atomCreationProtocolFee_, uint256 atomWalletDepositFee_) = multiVault.atomConfig();

        return
            AtomConfig({atomCreationProtocolFee: atomCreationProtocolFee_, atomWalletDepositFee: atomWalletDepositFee_});
    }

    /// @notice returns the triple configuration struct
    function getTripleConfig() public view returns (TripleConfig memory) {
        (
            uint256 tripleCreationProtocolFee_,
            uint256 totalAtomDepositsOnTripleCreation_,
            uint256 atomDepositFractionForTriple_
        ) = multiVault.tripleConfig();

        return TripleConfig({
            tripleCreationProtocolFee: tripleCreationProtocolFee_,
            totalAtomDepositsOnTripleCreation: totalAtomDepositsOnTripleCreation_,
            atomDepositFractionForTriple: atomDepositFractionForTriple_
        });
    }

    /// @notice returns the wallet configuration struct
    function getWalletConfig() public view returns (WalletConfig memory) {
        (
            IPermit2 permit2_,
            address entryPoint_,
            address atomWarden_,
            address atomWalletBeacon_,
            address atomWalletFactory_
        ) = multiVault.walletConfig();

        return WalletConfig({
            permit2: permit2_,
            entryPoint: entryPoint_,
            atomWarden: atomWarden_,
            atomWalletBeacon: atomWalletBeacon_,
            atomWalletFactory: atomWalletFactory_
        });
    }

    /// @notice returns the vault fees struct
    function getVaultFees() public view returns (VaultFees memory) {
        (uint256 entryFee_, uint256 exitFee_, uint256 protocolFee_) = multiVault.vaultFees();

        return VaultFees({entryFee: entryFee_, exitFee: exitFee_, protocolFee: protocolFee_});
    }

    /// @notice returns the bonding curve configuration struct
    function getBondingCurveConfig() public view returns (BondingCurveConfig memory) {
        (address registry_, uint256 defaultCurveId_) = multiVault.bondingCurveConfig();

        return BondingCurveConfig({registry: registry_, defaultCurveId: defaultCurveId_});
    }

    /// @notice returns the wrapper configuration struct
    function getWrapperConfig() public view returns (WrapperConfig memory) {
        (address wrappedERC20Beacon_, address wrappedERC20Factory_) = multiVault.wrapperConfig();

        return WrapperConfig({wrappedERC20Beacon: wrappedERC20Beacon_, wrappedERC20Factory: wrappedERC20Factory_});
    }

    /// @notice Helper function to calculate the minimum amount after applying slippage
    /// @param amount The original amount
    /// @param slippageBps The slippage percentage (in basis points, e.g., 100 = 1%)
    function _minAmount(uint256 amount, uint256 slippageBps) internal pure returns (uint256) {
        if (slippageBps == 0 || amount == 0) {
            return amount;
        }
        if (slippageBps >= BASIS_POINTS_DIVISOR) {
            return 0; // If slippage is 100% or more, no amount should be returned
        }
        return amount - (amount * slippageBps) / BASIS_POINTS_DIVISOR;
    }

    /// @notice Helper function to calculate the minimum shares after applying slippage
    /// @param previewShares The preview shares amount
    function _minShares(uint256 previewShares, uint256 slippageBps) internal pure returns (uint256) {
        if (slippageBps == 0 || previewShares == 0) {
            return previewShares;
        }
        if (slippageBps >= BASIS_POINTS_DIVISOR) {
            return 0; // If slippage is 100% or more, no shares should be returned
        }
        return previewShares * (BASIS_POINTS_DIVISOR - slippageBps) / BASIS_POINTS_DIVISOR;
    }
}
