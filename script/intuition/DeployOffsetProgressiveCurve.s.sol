// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";

/*
LOCAL
forge script script/intuition/DeployOffsetProgressiveCurve.s.sol:DeployOffsetProgressiveCurve \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast \
--slow

TESTNET
forge script script/intuition/DeployOffsetProgressiveCurve.s.sol:DeployOffsetProgressiveCurve \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast \
--slow \
--verify \
--chain 13579 \
--verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'

MAINNET
forge script script/intuition/DeployOffsetProgressiveCurve.s.sol:DeployOffsetProgressiveCurve \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract DeployOffsetProgressiveCurve is SetupScript {
    OffsetProgressiveCurve public offsetProgressiveCurveImpl;
    TransparentUpgradeableProxy public offsetProgressiveCurveProxy;

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
            revert("Unsupported chain for DeployOffsetProgressiveCurve script");
        }
    }

    function run() public broadcast {
        _deployOPC();
        console2.log("");
        console2.log("DEPLOYMENTS: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("OffsetProgressiveCurve Implementation:", address(offsetProgressiveCurveImpl));
        console2.log("OffsetProgressiveCurve Proxy:", address(offsetProgressiveCurveProxy));
    }

    function _deployOPC() internal {
        // 1. Deploy the OffsetProgressiveCurve implementation contract
        offsetProgressiveCurveImpl = new OffsetProgressiveCurve();

        // 2. Prepare init data for the OffsetProgressiveCurve
        bytes memory initData = abi.encodeWithSelector(
            OffsetProgressiveCurve.initialize.selector,
            "Offset Progressive Curve",
            OFFSET_PROGRESSIVE_CURVE_SLOPE,
            OFFSET_PROGRESSIVE_CURVE_OFFSET
        );

        offsetProgressiveCurveProxy = new TransparentUpgradeableProxy(
            address(offsetProgressiveCurveImpl), address(UPGRADES_TIMELOCK_CONTROLLER), initData
        );
        info("OffsetProgressiveCurve Proxy", address(offsetProgressiveCurveProxy));
    }
}
