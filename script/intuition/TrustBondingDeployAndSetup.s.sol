// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { Trust } from "src/Trust.sol";
import { TestTrust } from "tests/mocks/TestTrust.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
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
TESTNET
forge script script/intuition/TrustBondingDeployAndSetup.s.sol:TrustBondingDeployAndSetup \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow

MAINNET
forge script script/intuition/TrustBondingDeployAndSetup.s.sol:TrustBondingDeployAndSetup \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow
*/

contract TrustBondingDeployAndSetup is SetupScript {
    address public BASE_EMISSIONS_CONTROLLER;
    TimelockController public timelockControllerUpgrades;
    TimelockController public timelockControllerParameters;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("ANVIL_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_SEPOLIA_BASE_EMISSIONS_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION) {
            BASE_EMISSIONS_CONTROLLER = vm.envAddress("BASE_MAINNET_BASE_EMISSIONS_CONTROLLER");
        } else {
            revert("Unsupported chain for Intuition Deploy and Setup");
        }
    }

    function run() public broadcast {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");

        // Deploy the complete MultiVault system
        _deploy();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        contractInfo("Timelock Controller: Upgrades", address(timelockControllerUpgrades));
        contractInfo("Timelock Controller: Parameters", address(timelockControllerParameters));
        contractInfo("SatelliteEmissionsController", address(satelliteEmissionsController));
        contractInfo("TrustBonding", address(trustBonding));
    }

    function _deploy() internal {
        // Deploy TimelockController contract for upgrades (it should become the ProxyAdmin owner for all proxies)
        timelockControllerUpgrades = _deployTimelockController("Upgrades TimelockController");
        timelockControllerParameters = _deployTimelockController("Parameters TimelockController");

        // Initialize SatelliteEmissionsController with proper struct parameters
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
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

        // Deploy SatelliteEmissionsController implementation and proxy
        SatelliteEmissionsController satelliteEmissionsControllerImpl = new SatelliteEmissionsController();
        TransparentUpgradeableProxy satelliteEmissionsControllerProxy = new TransparentUpgradeableProxy(
            address(satelliteEmissionsControllerImpl), address(timelockControllerUpgrades), satelliteInitData
        );
        satelliteEmissionsController = SatelliteEmissionsController(payable(satelliteEmissionsControllerProxy));
        info("SatelliteEmissionsController Implementation", address(satelliteEmissionsControllerImpl));
        info("SatelliteEmissionsController Proxy", address(satelliteEmissionsControllerProxy));

        // Deploy TrustBonding implementation and proxy
        TrustBonding trustBondingImpl = new TrustBonding();
        info("TrustBonding Implementation", address(trustBondingImpl));

        bytes memory trustBondingInitData = abi.encodeWithSelector(
            TrustBonding.initialize.selector,
            ADMIN,
            address(ADMIN), // temporary assignment of ADMIN to the Timelock role
            address(TRUST_TOKEN), // WTRUST token if deploying on Intuition network
            BONDING_EPOCH_LENGTH,
            address(satelliteEmissionsController),
            BONDING_SYSTEM_UTILIZATION_LOWER_BOUND,
            BONDING_PERSONAL_UTILIZATION_LOWER_BOUND
        );

        TransparentUpgradeableProxy trustBondingProxy = new TransparentUpgradeableProxy(
            address(trustBondingImpl), address(timelockControllerUpgrades), trustBondingInitData
        );

        trustBonding = TrustBonding(address(trustBondingProxy));
        info("TrustBonding Proxy", address(trustBondingProxy));

        if (block.chainid != NETWORK_INTUITION) {
            satelliteEmissionsController.setTrustBonding(address(trustBonding));
            IAccessControl(address(satelliteEmissionsController)).grantRole(
                satelliteEmissionsController.CONTROLLER_ROLE(), address(trustBonding)
            );
            console2.log("CONTROLLER_ROLE in SatelliteEmissionsController granted to TrustBonding");
            trustBonding.setMultiVault(0x000000000000000000000000000000000000dEaD);
            trustBonding.setTimelock(address(timelockControllerParameters));
        }
    }
}
