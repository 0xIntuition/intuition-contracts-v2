// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { IMultiVaultPeriphery } from "src/interfaces/IMultiVaultPeriphery.sol";
import { MultiVaultPeriphery } from "src/utils/MultiVaultPeriphery.sol";
import { SetupScript } from "script/SetupScript.s.sol";

/*
LOCAL
forge script script/intuition/DeployMultiVaultPeriphery.s.sol:DeployMultiVaultPeriphery \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/DeployMultiVaultPeriphery.s.sol:DeployMultiVaultPeriphery \
--optimizer-runs 4500 \
--rpc-url intuition_sepolia \
--broadcast

MAINNET
forge script script/intuition/DeployMultiVaultPeriphery.s.sol:DeployMultiVaultPeriphery \
--optimizer-runs 4500 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployMultiVaultPeriphery is SetupScript {
    address public MULTI_VAULT;
    address public UPGRADES_TIMELOCK_CONTROLLER;

    MultiVaultPeriphery public multiVaultPeriphery;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            MULTI_VAULT = vm.envAddress("ANVIL_MULTI_VAULT");
            UPGRADES_TIMELOCK_CONTROLLER = vm.envAddress("ANVIL_UPGRADES_TIMELOCK_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            MULTI_VAULT = vm.envAddress("INTUITION_SEPOLIA_MULTI_VAULT");
            UPGRADES_TIMELOCK_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_UPGRADES_TIMELOCK_CONTROLLER");
        } else if (block.chainid == NETWORK_INTUITION) {
            MULTI_VAULT = vm.envAddress("INTUITION_MAINNET_MULTI_VAULT");
            UPGRADES_TIMELOCK_CONTROLLER = vm.envAddress("INTUITION_MAINNET_UPGRADES_TIMELOCK_CONTROLLER");
        } else {
            revert("Unsupported chain for DeployMultiVaultPeriphery script");
        }
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVaultPeriphery deployed at:", address(multiVaultPeriphery));
    }

    function _deployContracts() internal {
        // 1. Deploy the MultiVaultPeriphery implementation contract
        multiVaultPeriphery = new MultiVaultPeriphery();

        // 2. Prepare init data for the MultiVaultPeriphery
        bytes memory initData = abi.encodeWithSelector(IMultiVaultPeriphery.initialize.selector, ADMIN, MULTI_VAULT);

        // 3. Deploy the MultiVaultPeriphery proxy contract
        TransparentUpgradeableProxy multiVaultPeripheryProxy =
            new TransparentUpgradeableProxy(address(multiVaultPeriphery), UPGRADES_TIMELOCK_CONTROLLER, initData);
        multiVaultPeriphery = MultiVaultPeriphery(address(multiVaultPeripheryProxy));
    }
}
