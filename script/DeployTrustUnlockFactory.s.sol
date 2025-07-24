// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {TrustUnlock} from "src/v2/TrustUnlock.sol";
import {TrustUnlockFactory} from "src/v2/TrustUnlockFactory.sol";

contract DeployTrustUnlockFactory is Script {
    /// @notice Deployed TRUST token address on Base
    address public trustTokenAddress = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    /// @notice Address of the contract owner
    address public admin = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;

    /// @notice Address of the deployed TrustBonding contract on Base
    address public trustBondingAddress = address(0); // NOTE: Replace with actual address before deploying

    /// @notice TrustUnlockFactory contract to be deployed
    TrustUnlockFactory public trustUnlockFactory;

    function run() external {
        vm.startBroadcast();

        trustUnlockFactory = new TrustUnlockFactory(trustTokenAddress, admin, trustBondingAddress);

        console.log("TrustUnlock deployed at: ", address(trustUnlockFactory));

        vm.stopBroadcast();
    }
}
