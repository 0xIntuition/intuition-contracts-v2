// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/*
LOCAL
forge script script/intuition/MultiVaultDeploy.s.sol:MultiVaultDeploy \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/MultiVaultDeploy.s.sol:MultiVaultDeploy \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast
*/
contract MultiVaultDeploy is SetupScript {
    MultiVault public multiVaultImpl;
    TransparentUpgradeableProxy public multiVaultProxy;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVault Implementation:", address(multiVaultImpl));
        console2.log("MultiVault Proxy:", address(multiVaultProxy));
    }

    function _deployContracts() internal {
        // 1. Deploy the MultiVault implementation contract
        multiVaultImpl = new MultiVault();

        // 2. Deploy the TransparentUpgradeableProxy with the MultiVault implementation
        multiVaultProxy = new TransparentUpgradeableProxy(address(multiVaultImpl), ADMIN, "");
    }
}
