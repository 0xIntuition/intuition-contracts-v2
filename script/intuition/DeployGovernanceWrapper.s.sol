// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { GovernanceWrapper } from "src/protocol/governance/GovernanceWrapper.sol";
import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { SetupScript } from "script/SetupScript.s.sol";

/*
LOCAL
script/intuition/DeployGovernanceWrapper.s.sol:DeployGovernanceWrapper \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/intuition/DeployGovernanceWrapper.s.sol:DeployGovernanceWrapper \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET
forge script script/intuition/DeployGovernanceWrapper.s.sol:DeployGovernanceWrapper \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployGovernanceWrapper is SetupScript {
    GovernanceWrapper public governanceWrapperImpl;
    TransparentUpgradeableProxy public governanceWrapperProxy;

    address public UPGRADES_TIMELOCK_CONTROLLER;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            UPGRADES_TIMELOCK_CONTROLLER = ADMIN;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            UPGRADES_TIMELOCK_CONTROLLER = ADMIN;
        } else if (block.chainid == NETWORK_INTUITION) {
            UPGRADES_TIMELOCK_CONTROLLER = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
        } else {
            revert("Unsupported chain for DeployGovernanceWrapper script");
        }
    }

    function run() public broadcast {
        _deployGovernanceWrapper();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("GovernanceWrapper Implementation:", address(governanceWrapperImpl));
        console2.log("GovernanceWrapper Proxy:", address(governanceWrapperProxy));
    }

    function _deployGovernanceWrapper() internal {
        // 1. Deploy the GovernanceWrapper implementation contract
        governanceWrapperImpl = new GovernanceWrapper();

        // 2. Prepare init data for the GovernanceWrapper
        bytes memory initData =
            abi.encodeWithSelector(IGovernanceWrapper.initialize.selector, UPGRADES_TIMELOCK_CONTROLLER);

        governanceWrapperProxy = new TransparentUpgradeableProxy(
            address(governanceWrapperImpl), address(UPGRADES_TIMELOCK_CONTROLLER), initData
        );
        info("GovernanceWrapper Proxy", address(governanceWrapperProxy));
    }
}
