// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Script, console2 } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { MetaERC20DispatchInit, FinalityState } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";

/*
LOCAL
forge script script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy \
--optimizer-runs 10000 \
--rpc-url base_sepolia \
--broadcast \
--slow

MAINNET
forge script script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy \
--optimizer-runs 10000 \
--rpc-url base \
--broadcast \
--slow
*/

contract BaseEmissionsControllerDeploy is SetupScript {
    BaseEmissionsController public baseEmissionsControllerImpl;
    TransparentUpgradeableProxy public baseEmissionsControllerProxy;
    TimelockController public upgradesTimelockController;

    /// @notice Chain ID for the Intuition Testnet
    address public BASE_EMISSIONS_CONTROLLER;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deploy();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Upgrades TimelockController for BaseEmissionsController:", address(upgradesTimelockController));
        console2.log("BaseEmissionsController Implementation:", address(baseEmissionsControllerImpl));
        console2.log("BaseEmissionsController Proxy:", address(baseEmissionsControllerProxy));
    }

    function _deploy() internal {
        // 1. Deploy TimelockController contract for upgrades (it should become the ProxyAdmin owner for the
        // BaseEmissionsController proxy contract)
        upgradesTimelockController = _deployTimelockController("Upgrades TimelockController");

        // 2. Deploy the BaseEmissionsController implementation contract
        baseEmissionsControllerImpl = new BaseEmissionsController();

        // 3. Prepare initialization params for the BaseEmissionsController
        MetaERC20DispatchInit memory metaERC20DispatchInit = MetaERC20DispatchInit({
            hubOrSpoke: METALAYER_HUB_OR_SPOKE,
            recipientDomain: SATELLITE_METALAYER_RECIPIENT_DOMAIN,
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

        bytes memory initData = abi.encodeWithSelector(
            BaseEmissionsController.initialize.selector,
            ADMIN,
            ADMIN,
            TRUST_TOKEN,
            metaERC20DispatchInit,
            coreEmissionsInit
        );

        // 4. Deploy the TransparentUpgradeableProxy with the BaseEmissionsController implementation
        baseEmissionsControllerProxy = new TransparentUpgradeableProxy(
            address(baseEmissionsControllerImpl), address(upgradesTimelockController), initData
        );
    }
}
