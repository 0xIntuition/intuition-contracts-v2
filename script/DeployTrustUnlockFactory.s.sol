// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {TrustUnlock} from "src/v2/TrustUnlock.sol";
import {TrustUnlockFactory} from "src/v2/TrustUnlockFactory.sol";

contract DeployTrustUnlockFactory is Script {
    /// @notice Constants
    address public trustTokenAddress = vm.envAddress("TRUST_TOKEN_ADDRESS");
    address public admin = vm.envAddress("ADMIN");
    address public trustBondingAddress = vm.envAddress("TRUST_BONDING_ADDRESS");
    address public multiVaultAddress = vm.envAddress("MULTI_VAULT_ADDRESS");

    /// @notice TrustUnlockFactory contract to be deployed
    TrustUnlockFactory public trustUnlockFactory;

    function run() external {
        vm.startBroadcast();

        trustUnlockFactory = new TrustUnlockFactory(trustTokenAddress, admin, trustBondingAddress, multiVaultAddress);

        console.log("TrustUnlockFactory deployed at: ", address(trustUnlockFactory));

        vm.stopBroadcast();
    }
}
