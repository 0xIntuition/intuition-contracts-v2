// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";

/*
LOCAL
forge script script/intuition/MultiVaultMigrationDeploy.s.sol:MultiVaultMigrationDeploy \
--optimizer-runs 200 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/intuition/MultiVaultMigrationDeploy.s.sol:MultiVaultMigrationDeploy \
--optimizer-runs 200 \
--rpc-url intuition_sepolia \
--broadcast \
--slow
*/

contract MultiVaultMigrationDeploy is SetupScript {
    MultiVaultMigrationMode public multiVaultMigrationModeImpl;
    TransparentUpgradeableProxy public multiVaultMigrationModeProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVaultMigrationMode Implementation:", address(multiVaultMigrationModeImpl));
        console2.log("MultiVaultMigrationMode Proxy:", address(multiVaultMigrationModeProxy));
    }

    function _deployContracts() internal {
        // 1. Deploy the MultiVaultMigrationMode implementation contract
        multiVaultMigrationModeImpl = new MultiVaultMigrationMode();

        // 2. Deploy the TransparentUpgradeableProxy with the MultiVaultMigrationMode implementation
        multiVaultMigrationModeProxy = new TransparentUpgradeableProxy(address(multiVaultMigrationModeImpl), ADMIN, "");
    }
}
