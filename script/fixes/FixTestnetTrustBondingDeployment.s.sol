// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

/*
LOCAL
forge script script/fixes/FixTestnetTrustBondingDeployment.s.sol:FixTestnetTrustBondingDeployment \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/fixes/FixTestnetTrustBondingDeployment.s.sol:FixTestnetTrustBondingDeployment \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'
*/

contract FixTestnetTrustBondingDeployment is SetupScript {
    address public constant TESTNET_TRUST_BONDING_ADDRESS = 0x17945384609BDA6537D7B588ef1746f35a6d0E0F;
    address public constant TESTNET_TRUST_BONDING_PROXY_ADMIN_ADDRESS = 0x31FAa9033e98F1e4313864e3b92a7EE08C2350bC;
    address public constant TESTNET_UPGRADES_TIMELOCK_ADDRESS = 0xEE0a3C76dB52037C3007C330fca9ed8e2fD9d56F;

    address public constant TESTNET_MULTI_VAULT_ADDRESS = 0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91;
    address public constant TESTNET_PARAMETERS_TIMELOCK_ADDRESS = 0x06000C13821c198Ce5162e9f61f5b67FEccB9187;

    function run() public broadcast {
        if (block.chainid != NETWORK_INTUITION_SEPOLIA) {
            revert("This script can only be run on the Intuition Sepolia Testnet");
        }

        TimelockController upgradesTimelock = TimelockController(payable(TESTNET_UPGRADES_TIMELOCK_ADDRESS));
        ProxyAdmin proxyAdmin = ProxyAdmin(TESTNET_TRUST_BONDING_PROXY_ADMIN_ADDRESS);
        TrustBonding trustBondingProxy = TrustBonding(TESTNET_TRUST_BONDING_ADDRESS);

        console2.log("Fixing TrustBonding deployment on Intuition Testnet...");

        TrustBonding trustBondingImpl = new TrustBonding();
        console2.log("Deployed new TrustBonding implementation at:", address(trustBondingImpl));

        bytes memory upgradeAndCallData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector, address(trustBondingProxy), address(trustBondingImpl), bytes("")
        );

        console2.log("Preparing to queue upgrade transaction in Timelock...");

        upgradesTimelock.schedule(address(proxyAdmin), 0, upgradeAndCallData, bytes32(0), bytes32(0), 300);

        console2.log("Upgrade transaction queued. Please wait 5 minutes before executing the upgrade.");
        console2.log("After the wait, execute the following transaction in the Timelock:");
        console2.log("Target:", address(proxyAdmin));
        console2.log("Value: 0");
        console2.log("Data:");
        console2.logBytes(upgradeAndCallData);
        console2.log("Predecessor:");
        console2.logBytes32(bytes32(0));
        console2.log("Salt:");
        console2.logBytes32(bytes32(0));
    }
}
