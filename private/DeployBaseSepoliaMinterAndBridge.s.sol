// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { Script, console2 } from "forge-std/src/Script.sol";
import { BaseSepoliaMinterAndBridge } from "tests/testnet/BaseSepoliaMinterAndBridge.sol";

contract DeployBaseSepoliaMinterAndBridge is Script {
    address public owner = 0xB8e3452E62B45e654a300a296061597E3Cf3e039;
    address public token = 0xA54b4E6e356b963Ee00d1C947f478d9194a1a210; // tTRUST token on Base Sepolia
    address public metaERC20Hub = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5; // MetaERC20Hub on Base Sepolia

    BaseSepoliaMinterAndBridge public baseSepoliaMinterAndBridge;

    function run() external {
        vm.startBroadcast();
        baseSepoliaMinterAndBridge = new BaseSepoliaMinterAndBridge(owner, token, metaERC20Hub);
        console2.log("BaseSepoliaMinterAndBridge deployed at:", address(baseSepoliaMinterAndBridge));
        vm.stopBroadcast();
    }
}

// forge script private/DeployBaseSepoliaMinterAndBridge.s.sol \
//   --rpc-url base_sepolia \
//   --account account4 \
//   --broadcast --verify --verifier etherscan \
//   --verifier-url https://api.etherscan.io/v2/api \
//   --chain 84532 \
//   -vvvv --slow
