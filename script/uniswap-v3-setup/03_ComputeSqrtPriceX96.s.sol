// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title ComputeSqrtPriceX96
 * @notice Script 3 - Compute sqrtPriceX96 values for pool initialization
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/03_ComputeSqrtPriceX96.s.sol:ComputeSqrtPriceX96 \
 *   --rpc-url intuition_sepolia
 *
 * Required env vars:
 *   WTRUST_TOKEN, USDC_TOKEN, WETH_TOKEN
 *
 * Optional env vars (reference prices in USD, defaults provided):
 *   TRUST_PRICE_USD (default: 0.083 = $0.083 per TRUST)
 *   WETH_PRICE_USD (default: 2200 = $2,200 per WETH)
 *   USDC_PRICE_USD (default: 1 = $1 per USDC)
 *
 * OUTPUT: sqrtPriceX96 values for each pool
 */
contract ComputeSqrtPriceX96 is UniswapV3SetupBase {
    uint256 internal constant PRICE_PRECISION = 1e18;

    struct ComputedPrice {
        address token0;
        address token1;
        uint160 sqrtPriceX96;
        uint256 humanPrice;
        uint256 humanPriceInverse;
        bool aIsToken0;
    }

    function run() external {
        setUp();
        console2.log("");
        console2.log("=== Script 3: Compute sqrtPriceX96 for Pool Initialization ===");
        console2.log("");
        console2.log("NOTE: TRUST is the native token. Using WTRUST (wrapped) for pools.");
        infoLine();

        _validateTokenAddresses();

        uint256 trustPriceUsd = vm.envOr("TRUST_PRICE_USD", uint256(0.083e18)); // default $0.083 per TRUST
        uint256 wethPriceUsd = vm.envOr("WETH_PRICE_USD", uint256(2200e18)); // default $2,200 per WETH
        uint256 usdcPriceUsd = vm.envOr("USDC_PRICE_USD", uint256(1e18)); // default $1 per USDC

        console2.log("Reference prices (in USD with 18 decimals):");
        console2.log("  WTRUST:", trustPriceUsd);
        console2.log("  WETH:", wethPriceUsd);
        console2.log("  USDC:", usdcPriceUsd);
        infoLine();

        uint8 wtrustDecimals = IERC20Metadata(wtrustToken).decimals();
        uint8 usdcDecimals = IERC20Metadata(usdcToken).decimals();
        uint8 wethDecimals = IERC20Metadata(wethToken).decimals();

        console2.log("Token decimals:");
        console2.log("  WTRUST:", wtrustDecimals);
        console2.log("  USDC:", usdcDecimals);
        console2.log("  WETH:", wethDecimals);
        infoLine();

        console2.log("");
        console2.log("=== WTRUST/USDC Pool ===");
        ComputedPrice memory wtrustUsdc =
            _computePriceForPair(wtrustToken, usdcToken, wtrustDecimals, usdcDecimals, trustPriceUsd, usdcPriceUsd);
        _printComputedPrice(wtrustUsdc, "WTRUST", "USDC");

        console2.log("");
        console2.log("=== WTRUST/WETH Pool ===");
        ComputedPrice memory wtrustWeth =
            _computePriceForPair(wtrustToken, wethToken, wtrustDecimals, wethDecimals, trustPriceUsd, wethPriceUsd);
        _printComputedPrice(wtrustWeth, "WTRUST", "WETH");

        console2.log("");
        console2.log("=== WETH/USDC Pool ===");
        ComputedPrice memory wethUsdc =
            _computePriceForPair(wethToken, usdcToken, wethDecimals, usdcDecimals, wethPriceUsd, usdcPriceUsd);
        _printComputedPrice(wethUsdc, "WETH", "USDC");

        _printSummary(wtrustUsdc, wtrustWeth, wethUsdc);
    }

    function _validateTokenAddresses() internal view {
        require(wtrustToken != address(0), "WTRUST_TOKEN not set");
        require(usdcToken != address(0), "USDC_TOKEN not set");
        require(wethToken != address(0), "WETH_TOKEN not set");

        console2.log("Token addresses:");
        console2.log("  WTRUST:", wtrustToken);
        console2.log("  USDC:", usdcToken);
        console2.log("  WETH:", wethToken);
    }

    function _computePriceForPair(
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB,
        uint256 priceAUsd,
        uint256 priceBUsd
    )
        internal
        pure
        returns (ComputedPrice memory result)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bool aIsToken0 = tokenA < tokenB;

        uint256 priceToken0Usd = aIsToken0 ? priceAUsd : priceBUsd;
        uint256 priceToken1Usd = aIsToken0 ? priceBUsd : priceAUsd;

        uint256 priceToken1PerToken0 = (priceToken0Usd * PRICE_PRECISION) / priceToken1Usd;

        int256 decimalDiff;
        if (aIsToken0) {
            decimalDiff = int256(uint256(decimalsB)) - int256(uint256(decimalsA));
        } else {
            decimalDiff = int256(uint256(decimalsA)) - int256(uint256(decimalsB));
        }

        uint256 adjustedPrice;
        if (decimalDiff >= 0) {
            adjustedPrice = priceToken1PerToken0 * (10 ** uint256(decimalDiff));
        } else {
            adjustedPrice = priceToken1PerToken0 / (10 ** uint256(-decimalDiff));
        }

        uint256 sqrtPriceRaw = Math.sqrt(adjustedPrice);
        uint160 sqrtPriceX96 = uint160((sqrtPriceRaw * Q96) / Math.sqrt(PRICE_PRECISION));

        result.token0 = token0;
        result.token1 = token1;
        result.sqrtPriceX96 = sqrtPriceX96;
        result.humanPrice = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * PRICE_PRECISION) / Q192;
        if (result.humanPrice > 0) {
            result.humanPriceInverse = (PRICE_PRECISION * PRICE_PRECISION) / result.humanPrice;
        }
        result.aIsToken0 = aIsToken0;
    }

    function _printComputedPrice(ComputedPrice memory price, string memory nameA, string memory nameB) internal pure {
        string memory token0Name = price.aIsToken0 ? nameA : nameB;
        string memory token1Name = price.aIsToken0 ? nameB : nameA;

        console2.log("Token ordering:");
        console2.log(string.concat("  token0 (", token0Name, "):"), price.token0);
        console2.log(string.concat("  token1 (", token1Name, "):"), price.token1);
        console2.log("");
        console2.log("sqrtPriceX96:", price.sqrtPriceX96);
        console2.log("");
        console2.log("Derived human-readable prices (with 18 decimal precision):");
        console2.log(string.concat("  Price (", token1Name, " per ", token0Name, "):"), price.humanPrice);
        console2.log(string.concat("  Price (", token0Name, " per ", token1Name, "):"), price.humanPriceInverse);
    }

    function _printSummary(
        ComputedPrice memory wtrustUsdc,
        ComputedPrice memory wtrustWeth,
        ComputedPrice memory wethUsdc
    )
        internal
        view
    {
        console2.log("");
        console2.log("=== SUMMARY: sqrtPriceX96 Values for Pool Initialization ===");
        infoLine();
        console2.log("");
        console2.log("WTRUST/USDC Pool:");
        console2.log("  token0:", wtrustUsdc.token0);
        console2.log("  token1:", wtrustUsdc.token1);
        console2.log("  sqrtPriceX96:", wtrustUsdc.sqrtPriceX96);
        console2.log("");
        console2.log("WTRUST/WETH Pool:");
        console2.log("  token0:", wtrustWeth.token0);
        console2.log("  token1:", wtrustWeth.token1);
        console2.log("  sqrtPriceX96:", wtrustWeth.sqrtPriceX96);
        console2.log("");
        console2.log("WETH/USDC Pool:");
        console2.log("  token0:", wethUsdc.token0);
        console2.log("  token1:", wethUsdc.token1);
        console2.log("  sqrtPriceX96:", wethUsdc.sqrtPriceX96);
        console2.log("");
        infoLine();
        console2.log("");
        console2.log("Environment variables for Script 4:");
        console2.log(string.concat("export WTRUST_USDC_SQRT_PRICE=", vm.toString(wtrustUsdc.sqrtPriceX96)));
        console2.log(string.concat("export WTRUST_WETH_SQRT_PRICE=", vm.toString(wtrustWeth.sqrtPriceX96)));
        console2.log(string.concat("export WETH_USDC_SQRT_PRICE=", vm.toString(wethUsdc.sqrtPriceX96)));
    }
}
