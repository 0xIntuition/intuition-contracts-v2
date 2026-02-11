// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/*
LOCAL
forge script script/intuition/MultiVaultDeploy.s.sol:MultiVaultDeploy \
--optimizer-runs 4500 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/MultiVaultDeploy.s.sol:MultiVaultDeploy \
--optimizer-runs 4500 \
--rpc-url intuition_sepolia \
--broadcast

MAINNET
forge script script/intuition/MultiVaultDeploy.s.sol:MultiVaultDeploy \
--optimizer-runs 4500 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract MultiVaultDeploy is SetupScript {
    MultiVault public multiVaultImpl;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        _deployContracts();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVault Implementation:", address(multiVaultImpl));
    }

    function _deployContracts() internal {
        // Deploy the MultiVault implementation contract
        multiVaultImpl = new MultiVault();
    }
}
