// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { MultiVaultMigrationMode } from "src/protocol/MultiVaultMigrationMode.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/*
LOCAL
forge script script/intuition/MultiVaultMigrationModeDeploy.s.sol:MultiVaultMigrationModeDeploy \
--optimizer-runs 200 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/MultiVaultMigrationModeDeploy.s.sol:MultiVaultMigrationModeDeploy \
--via-ir \
--optimizer-runs 200 \
--rpc-url intuition_sepolia \
--broadcast \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET
forge script script/intuition/MultiVaultMigrationModeDeploy.s.sol:MultiVaultMigrationModeDeploy \
--optimizer-runs 200 \
--rpc-url intuition \
--broadcast \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract MultiVaultMigrationModeDeploy is SetupScript {
    MultiVaultMigrationMode public multiVaultMigrationModeImpl;

    function setUp() public override {
        super.setUp();
    }

    function run() public broadcast {
        // Deploy new MultiVaultMigrationMode implementation contract
        multiVaultMigrationModeImpl = new MultiVaultMigrationMode();

        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("MultiVaultMigrationMode Implementation:", address(multiVaultMigrationModeImpl));
    }
}
