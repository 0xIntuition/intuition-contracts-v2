// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";

/**
 * @title EnableFeeTiers
 * @notice Script 1 - Enable fee tiers and tick spacings on the Uniswap V3 Factory
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/01_EnableFeeTiers.s.sol:EnableFeeTiers \
 *   --rpc-url intuition_sepolia \
 *   --broadcast \
 *   --slow
 */
contract EnableFeeTiers is UniswapV3SetupBase {
    struct FeeTierConfig {
        uint24 fee;
        int24 tickSpacing;
        string name;
    }

    function run() external broadcast {
        console2.log("");
        console2.log("=== Script 1: Enable Fee Tiers and Tick Spacings ===");
        console2.log("Factory:", V3_FACTORY);
        infoLine();

        FeeTierConfig[3] memory configs = [
            FeeTierConfig(FEE_TIER_LOW, TICK_SPACING_LOW, "Low (0.05%)"),
            FeeTierConfig(FEE_TIER_MEDIUM, TICK_SPACING_MEDIUM, "Medium (0.3%)"),
            FeeTierConfig(FEE_TIER_HIGH, TICK_SPACING_HIGH, "High (1%)")
        ];

        for (uint256 i = 0; i < configs.length; i++) {
            _enableFeeTierIfNeeded(configs[i]);
        }

        console2.log("");
        console2.log("=== Validation ===");
        _validateAllFeeTiers(configs);

        console2.log("");
        console2.log("=== Fee Tier Setup Complete ===");
    }

    function _enableFeeTierIfNeeded(FeeTierConfig memory config) internal {
        int24 currentSpacing = factory.feeAmountTickSpacing(config.fee);

        if (currentSpacing != 0) {
            console2.log("");
            console2.log(string.concat("Fee tier ", config.name, " already enabled"));
            console2.log("  Fee:", config.fee);
            console2.log("  Current tick spacing:", currentSpacing);

            if (currentSpacing != config.tickSpacing) {
                console2.log("  WARNING: Tick spacing differs from desired!");
                console2.log("  Desired tick spacing:", config.tickSpacing);
            }
            return;
        }

        console2.log("");
        console2.log(string.concat("Enabling fee tier: ", config.name));
        console2.log("  Fee:", config.fee);
        console2.log("  Tick spacing:", config.tickSpacing);

        factory.enableFeeAmount(config.fee, config.tickSpacing);

        console2.log("  Status: ENABLED");
    }

    function _validateAllFeeTiers(FeeTierConfig[3] memory configs) internal view {
        bool allValid = true;

        for (uint256 i = 0; i < configs.length; i++) {
            int24 actualSpacing = factory.feeAmountTickSpacing(configs[i].fee);
            bool isValid = actualSpacing == configs[i].tickSpacing;

            console2.log("");
            console2.log(configs[i].name);
            console2.log("  Fee:", configs[i].fee);
            console2.log("  Expected tick spacing:", configs[i].tickSpacing);
            console2.log("  Actual tick spacing:", actualSpacing);
            console2.log(isValid ? "  Status: OK" : "  Status: MISMATCH");

            if (!isValid) allValid = false;
        }

        console2.log("");
        if (allValid) {
            console2.log("All fee tiers validated successfully!");
        } else {
            console2.log("WARNING: Some fee tiers have mismatched tick spacings!");
        }
    }
}
