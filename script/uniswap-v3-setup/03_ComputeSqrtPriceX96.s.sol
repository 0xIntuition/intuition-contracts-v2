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
        uint8 decimals0;
        uint8 decimals1;
        uint160 sqrtPriceX96;
        uint256 expectedPriceHumanX18; // token1 per token0 in human units, 1e18 precision
        uint256 derivedPriceHumanX18; // token1 per token0 in human units, 1e18 precision
        uint256 derivedPriceHumanInverseX18; // token0 per token1 in human units, 1e18 precision
        bool aIsToken0;
    }

    function run() external {
        super.setUp();
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
        result.aIsToken0 = tokenA < tokenB;
        (result.token0, result.token1) = result.aIsToken0 ? (tokenA, tokenB) : (tokenB, tokenA);
        result.decimals0 = result.aIsToken0 ? decimalsA : decimalsB;
        result.decimals1 = result.aIsToken0 ? decimalsB : decimalsA;

        uint256 priceToken0Usd = result.aIsToken0 ? priceAUsd : priceBUsd;
        uint256 priceToken1Usd = result.aIsToken0 ? priceBUsd : priceAUsd;
        result.expectedPriceHumanX18 = (priceToken0Usd * PRICE_PRECISION) / priceToken1Usd;

        uint256 rawPriceX18 = _toRawPriceX18(result.expectedPriceHumanX18, result.decimals0, result.decimals1);

        uint256 sqrtPriceRaw = Math.sqrt(rawPriceX18);
        result.sqrtPriceX96 = uint160((sqrtPriceRaw * Q96) / Math.sqrt(PRICE_PRECISION));

        // Derive the price back from sqrtPriceX96, then convert back into human units for display.
        uint256 derivedRawPriceX18 =
            Math.mulDiv(uint256(result.sqrtPriceX96), uint256(result.sqrtPriceX96) * PRICE_PRECISION, Q192);
        result.derivedPriceHumanX18 = _toHumanPriceX18(derivedRawPriceX18, result.decimals0, result.decimals1);
        if (result.derivedPriceHumanX18 > 0) {
            result.derivedPriceHumanInverseX18 = (PRICE_PRECISION * PRICE_PRECISION) / result.derivedPriceHumanX18;
        }
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
        console2.log("Expected / derived prices (human units, 1e18 precision):");
        console2.log(string.concat("  Expected (", token1Name, " per ", token0Name, "):"), price.expectedPriceHumanX18);
        console2.log(string.concat("  Derived  (", token1Name, " per ", token0Name, "):"), price.derivedPriceHumanX18);
        console2.log(
            string.concat("  Derived  (", token0Name, " per ", token1Name, "):"), price.derivedPriceHumanInverseX18
        );
    }

    function _toRawPriceX18(uint256 humanPriceX18, uint8 decimals0, uint8 decimals1) internal pure returns (uint256) {
        int256 dec1MinusDec0 = int256(uint256(decimals1)) - int256(uint256(decimals0));
        if (dec1MinusDec0 > 0) return humanPriceX18 * (10 ** uint256(dec1MinusDec0));
        if (dec1MinusDec0 < 0) return humanPriceX18 / (10 ** uint256(-dec1MinusDec0));
        return humanPriceX18;
    }

    function _toHumanPriceX18(uint256 rawPriceX18, uint8 decimals0, uint8 decimals1) internal pure returns (uint256) {
        int256 dec1MinusDec0 = int256(uint256(decimals1)) - int256(uint256(decimals0));
        if (dec1MinusDec0 > 0) return rawPriceX18 / (10 ** uint256(dec1MinusDec0));
        if (dec1MinusDec0 < 0) return rawPriceX18 * (10 ** uint256(-dec1MinusDec0));
        return rawPriceX18;
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
