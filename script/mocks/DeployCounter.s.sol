// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { Counter } from "tests/mocks/Counter.sol";

/*
LOCAL
forge script script/mocks/DeployCounter.s.sol:DeployCounter \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

ETH SEPOLIA TESTNET
forge script script/mocks/DeployCounter.s.sol:DeployCounter \
--optimizer-runs 10000 \
--rpc-url sepolia \
--broadcast \
--slow \
--verify \
--chain 11155111 \
--verifier etherscan \
--verifier-url "https://api.etherscan.io/v2/api?chainid=11155111"

INTUITION MAINNET
forge script script/mocks/DeployCounter.s.sol:DeployCounter \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployCounter is SetupScript {
    function run() public broadcast returns (Counter) {
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        Counter counter = new Counter(broadcaster);
        info("Counter", address(counter));
        return counter;
    }
}
