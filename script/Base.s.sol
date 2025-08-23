// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        if (vm.envUint("BROADCASTING") != 0) {
            if (block.chainid == vm.envUint("BASE_CHAIN_ID")) {
                uint256 deployerKey = vm.envUint("DEPLOYER_MAINNET");
                broadcaster = vm.rememberKey(deployerKey);
            } else if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
                uint256 deployerKey = vm.envUint("DEPLOYER_LOCAL");
                broadcaster = vm.rememberKey(deployerKey);
            } else if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) {
                uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
                broadcaster = vm.rememberKey(deployerKey);
            } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
                uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
                broadcaster = vm.rememberKey(deployerKey);
            } else {
                revert("Unsupported chain for broadcasting");
            }
        } else {
            address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
            if (from != address(0)) {
                broadcaster = from;
            } else {
                mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
                (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
            }
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function info(string memory label, address addr) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(addr);
        console2.log("-------------------------------------------------------------------");
    }

    function info(string memory label, bytes32 data) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.logBytes32(data);
        console2.log("-------------------------------------------------------------------");
    }

    function info(string memory label, uint256 data) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(data);
        console2.log("-------------------------------------------------------------------");
    }

    function contractInfo(string memory label, address data) internal pure {
        console2.log(label, ":", data);
    }
}
