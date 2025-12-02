// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { SetupScript } from "script/SetupScript.s.sol";

/*
LOCAL
forge script script/fixes/ExecuteTestnetFix.s.sol:ExecuteTestnetFix \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/fixes/ExecuteTestnetFix.s.sol:ExecuteTestnetFix \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'
*/

contract ExecuteTestnetFix is SetupScript {
    address public constant TESTNET_TRUST_BONDING_PROXY_ADMIN_ADDRESS = 0x31FAa9033e98F1e4313864e3b92a7EE08C2350bC;
    address public constant TESTNET_UPGRADES_TIMELOCK_ADDRESS = 0xEE0a3C76dB52037C3007C330fca9ed8e2fD9d56F;

    function run() public broadcast {
        if (block.chainid != NETWORK_INTUITION_SEPOLIA) {
            revert("This script can only be run on the Intuition Sepolia Testnet");
        }

        TimelockController upgradesTimelock = TimelockController(payable(TESTNET_UPGRADES_TIMELOCK_ADDRESS));
        ProxyAdmin proxyAdmin = ProxyAdmin(TESTNET_TRUST_BONDING_PROXY_ADMIN_ADDRESS);

        /// @notice Copy this from the logs from running the main script (FixTestnetTrustBondingDeployment)
        bytes memory upgradeAndCallData = hex""; // Replace with actual data (without 0x)

        if (upgradeAndCallData.length == 0) {
            revert("Please set the upgradeAndCallData variable with the correct data from the main deployment script");
        }

        upgradesTimelock.execute(address(proxyAdmin), 0, upgradeAndCallData, bytes32(0), bytes32(0));

        console2.log("Executed TrustBonding upgrade on Intuition Testnet via TimelockController");
    }
}
