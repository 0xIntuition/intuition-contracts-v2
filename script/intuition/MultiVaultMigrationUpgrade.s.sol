// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/*
LOCAL
forge script script/intuition/MultiVaultMigrationUpgrade.s.sol:MultiVaultMigrationUpgrade \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/MultiVaultMigrationUpgrade.s.sol:MultiVaultMigrationUpgrade \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast
*/
contract MultiVaultMigrationUpgrade is SetupScript {
    // Existing proxy that currently points to MultiVaultMigrationMode
    address public MULTIVAULT_PROXY;

    // ProxyAdmin contract that has the upgrade rights for the MultiVaultMigrationMode proxy
    address public PROXY_ADMIN;

    MultiVault public multiVaultImpl;
    ITransparentUpgradeableProxy public multiVaultProxy;
    ProxyAdmin public proxyAdmin;

    // Matches MultiVaultMigrationMode's role constant
    bytes32 internal constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    function setUp() public override {
        super.setUp();

        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            MULTIVAULT_PROXY = vm.envAddress("ANVIL_MULTI_VAULT_MIGRATION_MODE");
            PROXY_ADMIN = vm.envAddress("ANVIL_PROXY_ADMIN");
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            MULTIVAULT_PROXY = vm.envAddress("INTUITION_SEPOLIA_MULTI_VAULT_MIGRATION_MODE_PROXY");
            PROXY_ADMIN = vm.envAddress("INTUITION_SEPOLIA_PROXY_ADMIN");
        } else {
            revert("Unsupported chain for broadcasting");
        }

        multiVaultProxy = ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY));
        proxyAdmin = ProxyAdmin(PROXY_ADMIN);
    }

    function run() public broadcast {
        // 1) Deploy target MultiVault implementation
        multiVaultImpl = new MultiVault();

        // 2) Upgrade proxy -> MultiVault (we pass the empty data arg since we don't need to init anything)
        proxyAdmin.upgradeAndCall(multiVaultProxy, address(multiVaultImpl), "");

        // 3) Revoke MIGRATOR_ROLE from the admin EOA
        MultiVault(address(multiVaultProxy)).revokeRole(MIGRATOR_ROLE, ADMIN);

        // 4) Sanity check
        bool revoked = !MultiVault(address(multiVaultProxy)).hasRole(MIGRATOR_ROLE, ADMIN);
        require(revoked, "MIGRATOR_ROLE revoke failed");

        console2.log("");
        console2.log("UPGRADE COMPLETE: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Proxy:", address(multiVaultProxy));
        console2.log("New MultiVault impl:", address(multiVaultImpl));
        console2.log("Migrator revoked from:", ADMIN);
    }
}
