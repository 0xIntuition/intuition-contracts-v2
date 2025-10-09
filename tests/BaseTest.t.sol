// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { Users } from "./utils/Types.sol";
import { Trust } from "src/Trust.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MetalayerRouterMock, IIGPMock, MetaERC20HubOrSpokeMock } from "tests/mocks/MetalayerRouterMock.sol";
import { Modifiers } from "./utils/Modifiers.sol";

abstract contract BaseTest is Modifiers, Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    uint256 internal BASIS_POINTS_DIVISOR = 10_000;

    uint256[] internal ATOM_COST;
    uint256[] internal TRIPLE_COST;
    uint256 internal FEE_THRESHOLD = 1e17;
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
    uint256 internal ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 90; // 0.9% (Percentage Cost)

    // Wallet Config
    address internal ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
    address internal ATOM_WARDEN = address(1);

    // Vault Config
    uint256 internal ENTRY_FEE = 100; // 1% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal EXIT_FEE = 100; // 1% of assets deposited after fixed costs (Percentage Cost)
    uint256 internal PROTOCOL_FEE = 100; // 1% of assets deposited after fixed costs (Percentage Cost)

    // TrustBonding configuration
    uint256 internal TRUST_BONDING_START_TIMESTAMP = block.timestamp + 20;
    uint256 internal TRUST_BONDING_EPOCH_LENGTH = 1 days * 14;
    uint256 internal TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND = 5000; // 50%
    uint256 internal TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND = 3000; // 30%

    // Curve Configurations
    uint256 internal PROGRESSIVE_CURVE_SLOPE = 1e15; // 0.001 slope

    // CoreEmissions Controller
    uint256 internal constant EMISSIONS_CONTROLLER_EPOCH_LENGTH = TWO_WEEKS;
    uint256 internal constant EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18; // 1K tokens
    uint256 internal constant EMISSIONS_CONTROLLER_CLIFF = 26;
    uint256 internal constant EMISSIONS_CONTROLLER_REDUCTION_BP = 1000; // 10%

    // Time constants for easier reading
    uint256 internal constant ONE_HOUR = 1 hours;
    uint256 internal constant ONE_DAY = 86_400;
    uint256 internal constant ONE_WEEK = ONE_DAY * 7;
    uint256 internal constant TWO_WEEKS = ONE_DAY * 14;
    uint256 internal constant THREE_WEEKS = ONE_DAY * 21;
    uint256 internal constant ONE_YEAR = ONE_DAY * 365;
    uint256 internal constant TWO_YEARS = ONE_YEAR * 2;
    uint256 internal constant THREE_YEARS = ONE_YEAR * 3;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users.admin = createUser("admin");
        users.controller = createUser("controller");
        users.timelock = createUser("timelock");
        users.alice = createUser("alice");
        users.bob = createUser("bob");
        users.charlie = createUser("charlie");
        protocol.trust = createTrustToken();
        _deployMultiVaultSystem();
        _approveTokensForUsers();
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);

        // setVariables(users, protocol);
        uint256 atomCost = protocol.multiVault.getAtomCost();
        ATOM_COST.push(atomCost);
        uint256 tripleCost = protocol.multiVault.getTripleCost();
        TRIPLE_COST.push(tripleCost);
    }

    function createTrustToken() internal returns (Trust) {
        // Deploy Trust implementation
        Trust trustImpl = new Trust();
        vm.label(address(trustImpl), "TrustImpl");

        // Deploy Trust proxy
        TransparentUpgradeableProxy trustProxy = new TransparentUpgradeableProxy(address(trustImpl), users.admin, "");
        Trust trust = Trust(address(trustProxy));
        trust.init(); // Run initializer

        // Initialize Trust contract via proxy
        vm.prank(0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480); // admin address set on Base
        trust.reinitialize(
            users.admin, // admin
            users.controller // controller
        );

        vm.label(address(trustProxy), "TrustProxy");
        vm.label(address(trust), "Trust");

        return trust;
    }

    /// @dev Creates a new ERC-20 token with `name`, `symbol` and `decimals`.
    function createToken(string memory name, string memory symbol, uint8 decimals) internal returns (ERC20Mock) {
        ERC20Mock token = new ERC20Mock(name, symbol, decimals);
        vm.label(address(token), name);
        return token;
    }

    function approveContract(IERC20 token_, address from, address spender) internal {
        resetPrank({ msgSender: from });
        (bool success,) = address(token_).call(abi.encodeCall(IERC20.approve, (spender, MAX_UINT256)));
        success;
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 10_000 ether });
        return user;
    }

    // Define proxies as state variables to avoid "stack too deep" errors
    TransparentUpgradeableProxy internal multiVaultProxy;
    TransparentUpgradeableProxy internal atomWalletFactoryProxy;
    TransparentUpgradeableProxy internal trustBondingProxy;
    TransparentUpgradeableProxy internal satelliteEmissionsControllerProxy;
    UpgradeableBeacon internal atomWalletBeacon;

    function _deployMultiVaultSystem() internal {
        // Deploy MultiVault implementation
        MultiVault multiVaultImpl = new MultiVault();
        console2.log("MultiVault implementation address: ", address(multiVaultImpl));

        // Deploy MultiVault proxy
        multiVaultProxy = new TransparentUpgradeableProxy(address(multiVaultImpl), users.admin, "");
        protocol.multiVault = MultiVault(address(multiVaultProxy));
        console2.log("MultiVault proxy address: ", address(multiVaultProxy));

        // Deploy AtomWallet implementation and beacon
        AtomWallet atomWalletImpl = new AtomWallet();
        console2.log("AtomWallet implementation deployed at:", address(atomWalletImpl));

        atomWalletBeacon = new UpgradeableBeacon(address(atomWalletImpl), users.admin);
        protocol.atomWalletBeacon = atomWalletBeacon;
        console2.log("AtomWalletBeacon deployed at:", address(atomWalletBeacon));

        // Deploy AtomWalletFactory implementation
        AtomWalletFactory atomWalletFactoryImpl = new AtomWalletFactory();
        console2.log("AtomWalletFactory implementation address: ", address(atomWalletFactoryImpl));

        // Deploy AtomWalletFactory proxy
        atomWalletFactoryProxy = new TransparentUpgradeableProxy(address(atomWalletFactoryImpl), users.admin, "");
        AtomWalletFactory atomWalletFactory = AtomWalletFactory(address(atomWalletFactoryProxy));
        console2.log("AtomWalletFactory proxy address: ", address(atomWalletFactoryProxy));
        protocol.atomWalletFactory = atomWalletFactory;

        // Deploy WrappedTrust
        WrappedTrust wtrust = new WrappedTrust();
        protocol.wrappedTrust = wtrust;
        console2.log("WrappedTrust address: ", address(wtrust));

        // Deploy TrustBonding implementation
        TrustBonding trustBondingImpl = new TrustBonding();
        protocol.trustBonding = TrustBonding(address(trustBondingImpl));
        console2.log("TrustBonding implementation address: ", address(trustBondingImpl));

        // Deploy TrustBonding proxy
        trustBondingProxy = new TransparentUpgradeableProxy(address(trustBondingImpl), users.admin, "");
        protocol.trustBonding = TrustBonding(address(trustBondingProxy));
        console2.log("TrustBonding proxy address: ", address(trustBondingProxy));

        // Deploy SatelliteEmissionsController implementation and proxy
        SatelliteEmissionsController satelliteEmissionsControllerImpl = new SatelliteEmissionsController();
        console2.log("SatelliteEmissionsController Implementation", address(satelliteEmissionsControllerImpl));

        satelliteEmissionsControllerProxy =
            new TransparentUpgradeableProxy(address(satelliteEmissionsControllerImpl), users.admin, "");
        protocol.satelliteEmissionsController = SatelliteEmissionsController(payable(satelliteEmissionsControllerProxy));
        console2.log("SatelliteEmissionsController Proxy", address(satelliteEmissionsControllerProxy));

        // Deploy BondingCurveRegistry
        BondingCurveRegistry bondingCurveRegistry = new BondingCurveRegistry(users.admin);
        console2.log("BondingCurveRegistry address: ", address(bondingCurveRegistry));

        // Deploy bonding curves and add them to registry
        LinearCurve linearCurve = new LinearCurve("Linear Bonding Curve");
        OffsetProgressiveCurve offsetProgressiveCurve =
            new OffsetProgressiveCurve("Offset Progressive Bonding Curve", 2, 5e35);
        ProgressiveCurve progressiveCurve = new ProgressiveCurve("Progressive Bonding Curve", 2);

        console2.log("LinearCurve address: ", address(linearCurve));
        console2.log("ProgressiveCurve address: ", address(progressiveCurve));

        resetPrank(users.admin);
        bondingCurveRegistry.addBondingCurve(address(linearCurve));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurve));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurve));
        console2.log("Added LinearCurve to registry with ID: 1");
        console2.log("Added OffsetProgressiveCurve to registry with ID: 2");
        console2.log("Added ProgressiveCurve to registry with ID: 3");

        // Label contracts for debugging
        vm.label(address(multiVaultImpl), "MultiVaultImpl");
        vm.label(address(multiVaultProxy), "MultiVaultProxy");
        vm.label(address(protocol.multiVault), "MultiVault");
        vm.label(address(atomWalletFactoryImpl), "AtomWalletFactoryImpl");
        vm.label(address(atomWalletFactoryProxy), "AtomWalletFactoryProxy");
        vm.label(address(atomWalletBeacon), "AtomWalletBeacon");
        vm.label(address(atomWalletFactory), "AtomWalletFactory");
        vm.label(address(trustBondingImpl), "TrustBondingImpl");
        vm.label(address(trustBondingProxy), "TrustBondingProxy");
        vm.label(address(trustBondingImpl), "TrustBonding");
        vm.label(address(bondingCurveRegistry), "BondingCurveRegistry");
        vm.label(address(linearCurve), "LinearCurve");
        vm.label(address(offsetProgressiveCurve), "OffsetProgressiveCurve");
        vm.label(address(progressiveCurve), "ProgressiveCurve");
        vm.label(address(wtrust), "WrappedTrust");

        IIGPMock IIGP = new IIGPMock();
        MetalayerRouterMock metaERC20Router = new MetalayerRouterMock(address(IIGP));
        MetaERC20HubOrSpokeMock metaERC20HubOrSpoke = new MetaERC20HubOrSpokeMock(address(metaERC20Router));

        protocol.satelliteEmissionsController.initialize(
            users.admin,
            address(1), // BaseEmissionsController placeholder
            MetaERC20DispatchInit({
                hubOrSpoke: address(metaERC20HubOrSpoke),
                recipientDomain: 1,
                gasLimit: 125_000,
                finalityState: FinalityState.INSTANT
            }),
            CoreEmissionsControllerInit({
                startTimestamp: block.timestamp,
                emissionsLength: EMISSIONS_CONTROLLER_EPOCH_LENGTH,
                emissionsPerEpoch: EMISSIONS_CONTROLLER_EMISSIONS_PER_EPOCH,
                emissionsReductionCliff: EMISSIONS_CONTROLLER_CLIFF,
                emissionsReductionBasisPoints: EMISSIONS_CONTROLLER_REDUCTION_BP
            })
        );

        protocol.satelliteEmissionsController.setTrustBonding(address(protocol.trustBonding));
        protocol.satelliteEmissionsController.grantRole(
            protocol.satelliteEmissionsController.CONTROLLER_ROLE(), address((trustBondingProxy))
        );

        // Initialize AtomWalletFactory
        atomWalletFactory.initialize(address(protocol.multiVault));

        protocol.trustBonding.initialize(
            users.admin, // owner
            users.timelock, // timelock
            address(protocol.wrappedTrust), // trustToken
            TRUST_BONDING_EPOCH_LENGTH, // epochLength (minimum 2 weeks required)
            address(protocol.satelliteEmissionsController), // satelliteEmissionsController
            TRUST_BONDING_SYSTEM_UTILIZATION_LOWER_BOUND, // systemUtilizationLowerBound (50%)
            TRUST_BONDING_PERSONAL_UTILIZATION_LOWER_BOUND // personalUtilizationLowerBound (30%)
        );

        // Prepare configuration structs with deployed addresses
        GeneralConfig memory generalConfig = _getDefaultGeneralConfig();
        generalConfig.trustBonding = address(protocol.trustBonding);

        AtomConfig memory atomConfig = _getDefaultAtomConfig();
        TripleConfig memory tripleConfig = _getDefaultTripleConfig();

        WalletConfig memory walletConfig = _getDefaultWalletConfig(address(atomWalletFactory));

        walletConfig.atomWalletFactory = address(atomWalletFactory);
        walletConfig.atomWalletBeacon = address(atomWalletBeacon);

        BondingCurveConfig memory bondingCurveConfig = _getDefaultBondingCurveConfig();
        bondingCurveConfig.registry = address(bondingCurveRegistry);

        // Initialize MultiVault
        protocol.multiVault.initialize(
            generalConfig,
            _getDefaultAtomConfig(),
            _getDefaultTripleConfig(),
            walletConfig,
            _getDefaultVaultFees(),
            bondingCurveConfig
        );

        resetPrank(users.timelock);
        protocol.trustBonding.setMultiVault(address(protocol.multiVault));

        // Approve tokens for all users after deployment
        _approveTokensForUsers();
    }

    function _approveTokensForUsers() internal {
        address[] memory allUsers = new address[](5);

        allUsers[0] = users.admin;
        allUsers[1] = users.controller;
        allUsers[2] = users.alice;
        allUsers[3] = users.bob;
        allUsers[4] = users.charlie;

        for (uint256 i = 0; i < allUsers.length; i++) {
            resetPrank({ msgSender: allUsers[i] });
            protocol.trust.approve({ spender: address(protocol.multiVault), amount: MAX_UINT256 });
            deal({ token: address(protocol.trust), to: allUsers[i], give: 1_000_000e18 });
            deal({ token: address(protocol.wrappedTrust), to: allUsers[i], give: 1_000_000e18 });
        }
    }

    function _getDefaultGeneralConfig() internal view returns (GeneralConfig memory) {
        return GeneralConfig({
            admin: users.admin,
            protocolMultisig: users.admin,
            feeDenominator: 10_000,
            trustBonding: address(0),
            minDeposit: MIN_DEPOSIT,
            minShare: MIN_SHARES,
            atomDataMaxLength: 1000,
            feeThreshold: 1e17
        });
    }

    function _getDefaultAtomConfig() internal returns (AtomConfig memory) {
        return AtomConfig({
            atomCreationProtocolFee: ATOM_CREATION_PROTOCOL_FEE,
            atomWalletDepositFee: ATOM_WALLET_DEPOSIT_FEE
        });
    }

    function _getDefaultTripleConfig() internal returns (TripleConfig memory) {
        return TripleConfig({
            tripleCreationProtocolFee: TRIPLE_CREATION_PROTOCOL_FEE,
            totalAtomDepositsOnTripleCreation: TOTAL_ATOM_DEPOSITS_ON_TRIPLE_CREATION,
            atomDepositFractionForTriple: 500
        });
    }

    function _getDefaultWalletConfig(address _atomWalletFactory) internal returns (WalletConfig memory) {
        return WalletConfig({
            entryPoint: ENTRY_POINT,
            atomWarden: ATOM_WARDEN,
            atomWalletBeacon: address(0),
            atomWalletFactory: address(_atomWalletFactory)
        });
    }

    function _getDefaultVaultFees() internal pure returns (VaultFees memory) {
        return VaultFees({ entryFee: 50, exitFee: 50, protocolFee: 100 });
    }

    function _getDefaultBondingCurveConfig() internal pure returns (BondingCurveConfig memory) {
        return BondingCurveConfig({ registry: address(0), defaultCurveId: 1 });
    }

    function createAtomWithDeposit(
        bytes memory atomData,
        uint256 depositAmount,
        address creator
    )
        internal
        returns (bytes32)
    {
        resetPrank({ msgSender: creator });
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        bytes32[] memory atomIds = protocol.multiVault.createAtoms{ value: depositAmount }(dataArray, amounts);
        return atomIds[0];
    }

    function createSimpleAtom(
        string memory atomString,
        uint256 depositAmount,
        address creator
    )
        internal
        returns (bytes32)
    {
        bytes memory atomData = abi.encodePacked(atomString);
        return createAtomWithDeposit(atomData, depositAmount, creator);
    }

    function calculateAtomId(bytes memory atomData) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(keccak256("ATOM_SALT"), keccak256(atomData)));
    }

    function getAtomCreationCost() internal view returns (uint256) {
        return protocol.multiVault.getAtomCost();
    }

    function convertToShares(uint256 assets, bytes32 termId, uint256 bondingCurveId) internal view returns (uint256) {
        return protocol.multiVault.convertToShares(termId, bondingCurveId, assets);
    }

    function convertToAssets(uint256 shares, bytes32 termId, uint256 bondingCurveId) internal view returns (uint256) {
        return protocol.multiVault.convertToAssets(termId, bondingCurveId, shares);
    }

    function expectAtomCreated(address creator, bytes32 expectedAtomId, bytes memory atomData) internal {
        vm.expectEmit(true, true, false, false);
        emit AtomCreated(creator, expectedAtomId, atomData, address(0));
    }

    // Helper function to create multiple atoms with uniform costs
    function createAtomsWithUniformCost(
        bytes[] memory atomDataArray,
        uint256 costPerAtom,
        address creator
    )
        internal
        returns (bytes32[] memory)
    {
        resetPrank({ msgSender: creator });
        uint256[] memory costs = new uint256[](atomDataArray.length);
        uint256 totalCost = 0;
        for (uint256 i = 0; i < atomDataArray.length; i++) {
            costs[i] = costPerAtom;
            totalCost += costPerAtom;
        }
        return protocol.multiVault.createAtoms{ value: totalCost }(atomDataArray, costs);
    }

    // Helper function to create a triple with proper setup
    function createTripleWithAtoms(
        string memory subjectData,
        string memory predicateData,
        string memory objectData,
        uint256 atomCost,
        uint256 tripleCost,
        address creator
    )
        internal
        returns (bytes32 tripleId, bytes32[] memory atomIds)
    {
        resetPrank({ msgSender: creator });

        // Create atoms
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = abi.encodePacked(subjectData);
        atomDataArray[1] = abi.encodePacked(predicateData);
        atomDataArray[2] = abi.encodePacked(objectData);

        atomIds = createAtomsWithUniformCost(atomDataArray, atomCost, creator);

        // Create triple
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        uint256[] memory assets = new uint256[](1);

        subjectIds[0] = atomIds[0];
        predicateIds[0] = atomIds[1];
        objectIds[0] = atomIds[2];
        assets[0] = tripleCost;

        bytes32[] memory tripleIds =
            protocol.multiVault.createTriples{ value: tripleCost }(subjectIds, predicateIds, objectIds, assets);
        tripleId = tripleIds[0];
    }

    // Helper function to make a deposit to an existing term
    function makeDeposit(
        address depositor,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 amount,
        uint256 minShares
    )
        internal
        returns (uint256 shares)
    {
        resetPrank({ msgSender: depositor });
        return protocol.multiVault.deposit{ value: amount }(receiver, termId, curveId, minShares);
    }

    // Helper function to redeem shares from a term
    function redeemShares(
        address redeemer,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        internal
        returns (uint256 assets)
    {
        resetPrank({ msgSender: redeemer });
        return protocol.multiVault.redeem(receiver, termId, curveId, shares, minAssets);
    }

    // Helper function to get default curve ID
    function getDefaultCurveId() internal view returns (uint256 defaultCurveId) {
        (, defaultCurveId) = protocol.multiVault.bondingCurveConfig();
    }

    // Helper to set up approval for another user
    function setupApproval(address owner, address spender, IMultiVault.ApprovalTypes approvalType) internal {
        resetPrank({ msgSender: owner });
        protocol.multiVault.approve(spender, approvalType);
    }

    // Helper to calculate total cost for array of amounts
    function calculateTotalCost(uint256[] memory amounts) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
    }

    // Helper function to create multiple atoms and return their IDs
    function createMultipleAtoms(
        string[] memory atomStrings,
        uint256[] memory costs,
        address creator
    )
        internal
        returns (bytes32[] memory)
    {
        bytes[] memory atomDataArray = new bytes[](atomStrings.length);
        for (uint256 i = 0; i < atomStrings.length; i++) {
            atomDataArray[i] = abi.encodePacked(atomStrings[i]);
        }

        resetPrank({ msgSender: creator });
        uint256 totalCost = calculateTotalCost(costs);
        return protocol.multiVault.createAtoms{ value: totalCost }(atomDataArray, costs);
    }

    // Helper function for batch deposits
    function makeDepositBatch(
        address depositor,
        address receiver,
        bytes32[] memory termIds,
        uint256[] memory curveIds,
        uint256[] memory amounts,
        uint256[] memory minShares
    )
        internal
        returns (uint256[] memory shares)
    {
        resetPrank({ msgSender: depositor });
        uint256 totalAmount = calculateTotalCost(amounts);
        return protocol.multiVault.depositBatch{ value: totalAmount }(receiver, termIds, curveIds, amounts, minShares);
    }

    // Helper function for batch redemptions
    function redeemSharesBatch(
        address redeemer,
        address receiver,
        bytes32[] memory termIds,
        uint256[] memory curveIds,
        uint256[] memory shares,
        uint256[] memory minAssets
    )
        internal
        returns (uint256[] memory assets)
    {
        resetPrank({ msgSender: redeemer });
        return protocol.multiVault.redeemBatch(receiver, termIds, curveIds, shares, minAssets);
    }

    // Helper to create arrays of same value for batch operations
    function createUniformArray(uint256 value, uint256 length) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            array[i] = value;
        }
        return array;
    }

    // Helper to create array of default curve IDs
    function createDefaultCurveIdArray(uint256 length) internal view returns (uint256[] memory) {
        return createUniformArray(getDefaultCurveId(), length);
    }

    // Event declarations for test helpers
    event AtomCreated(address indexed creator, bytes32 indexed atomId, bytes data, address atomWallet);

    function _setupUserWrappedTokenAndTrustBonding(address user) internal {
        vm.deal({ account: user, newBalance: 10_000_000_000 ether });
        resetPrank({ msgSender: user });
        protocol.wrappedTrust.deposit{ value: 10_000 ether }();
        protocol.wrappedTrust.approve(address(protocol.trustBonding), 10_000 ether);
        _addToTrustBondingWhiteList(user);
    }

    function _addToTrustBondingWhiteList(address _user) internal {
        resetPrank({ msgSender: users.admin });
        protocol.trustBonding.add_to_whitelist(_user);
    }
}
