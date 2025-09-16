// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.27;

// import { Script, console2 } from "forge-std/src/Script.sol";
// import { IntuitionSepoliaBridge } from "tests/testnet/IntuitionSepoliaBridge.sol";

// contract DeployIntuitionSepoliaBridge is Script {
//     address public owner = 0xB8e3452E62B45e654a300a296061597E3Cf3e039;
//     address public metaERC20Hub = 0x007700aa28A331B91219Ffa4A444711F0D9E57B5; // MetaERC20Hub on Intuition Sepolia

//     IntuitionSepoliaBridge public intuitionSepoliaBridge;

//     function run() external {
//         vm.startBroadcast();
//         intuitionSepoliaBridge = new IntuitionSepoliaBridge(owner, metaERC20Hub);
//         console2.log("IntuitionSepoliaBridge deployed at:", address(intuitionSepoliaBridge));
//         vm.stopBroadcast();
//     }
// }

// // forge script private/DeployIntuitionSepoliaBridge.s.sol \
// //   --rpc-url intuition_sepolia \
// //   --account account4 \
// //   --broadcast \
// //   -vvvv --slow \
// //   --verify --verifier blockscout \
// //   --verifier-url https://testnet.explorer.intuition.systems/api\?
