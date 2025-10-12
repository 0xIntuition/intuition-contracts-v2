// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "../SetupScript.s.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { ProgressiveCurve } from "src/protocol/curves/ProgressiveCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";

/*
LOCAL
forge script script/intuition/CurvesRegisterSetup.s.sol:CurvesRegisterSetup \
--optimizer-runs 10000 \
--rpc-url anvil \
--broadcast

TESTNET
forge script script/intuition/CurvesRegisterSetup.s.sol:CurvesRegisterSetup \
--optimizer-runs 10000 \
--rpc-url intuition_sepolia \
--broadcast
*/
contract CurvesRegisterSetup is SetupScript {
    address public BONDING_CURVE_REGISTRY;

    TransparentUpgradeableProxy public linearCurveProxy;
    TransparentUpgradeableProxy public progressiveCurveProxy;
    TransparentUpgradeableProxy public offsetProgressiveCurveProxy;

    function setUp() public override {
        super.setUp();
        if (block.chainid == vm.envUint("ANVIL_CHAIN_ID")) {
            BONDING_CURVE_REGISTRY = vm.envAddress("ANVIL_BONDING_CURVE_REGISTRY");
        } else if (block.chainid == vm.envUint("INTUITION_SEPOLIA_CHAIN_ID")) {
            BONDING_CURVE_REGISTRY = vm.envAddress("INTUITION_SEPOLIA_BONDING_CURVE_REGISTRY");
        } else {
            revert("Unsupported chain for broadcasting");
        }
    }

    function run() public broadcast {
        _setup();
    }

    function _setup() internal {
        // Deploy BondingCurveRegistry
        bondingCurveRegistry = BondingCurveRegistry(BONDING_CURVE_REGISTRY);

        // Deploy bonding curve implementations
        LinearCurve linearCurve = new LinearCurve();
        ProgressiveCurve progressiveCurve = new ProgressiveCurve();
        OffsetProgressiveCurve offsetProgressiveCurve = new OffsetProgressiveCurve();

        // Deploy proxies for bonding curves
        linearCurveProxy = new TransparentUpgradeableProxy(
            address(linearCurve), ADMIN, abi.encodeWithSelector(LinearCurve.initialize.selector, "Linear Curve")
        );
        progressiveCurveProxy = new TransparentUpgradeableProxy(
            address(progressiveCurve),
            ADMIN,
            abi.encodeWithSelector(ProgressiveCurve.initialize.selector, "Progressive Curve", PROGRESSIVE_CURVE_SLOPE)
        );
        offsetProgressiveCurveProxy = new TransparentUpgradeableProxy(
            address(offsetProgressiveCurve),
            ADMIN,
            abi.encodeWithSelector(
                OffsetProgressiveCurve.initialize.selector,
                "Offset Progressive Curve",
                PROGRESSIVE_CURVE_SLOPE,
                OFFSET_PROGRESSIVE_CURVE_OFFSET
            )
        );

        info("LinearCurve", address(linearCurveProxy));
        info("ProgressiveCurve", address(progressiveCurveProxy));
        info("OffsetProgressiveCurve", address(offsetProgressiveCurveProxy));

        // Add curves to registry
        bondingCurveRegistry.addBondingCurve(address(linearCurveProxy));
        bondingCurveRegistry.addBondingCurve(address(progressiveCurveProxy));
        bondingCurveRegistry.addBondingCurve(address(offsetProgressiveCurveProxy));
    }
}
