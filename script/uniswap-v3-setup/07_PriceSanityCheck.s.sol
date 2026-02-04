// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { IUniswapV3Pool } from "src/interfaces/external/uniswapv3/IUniswapV3Pool.sol";

/**
 * @title PriceSanityCheck
 * @notice Script 7 - Minimal price sanity check to detect common setup failures
 *
 * IMPORTANT: TRUST is the native token. We use WTRUST (Wrapped TRUST) for pools.
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/07_PriceSanityCheck.s.sol:PriceSanityCheck \
 *   --rpc-url intuition_sepolia
 *
 * Required env vars:
 *   WTRUST_TOKEN, USDC_TOKEN, WETH_TOKEN
 *   WTRUST_USDC_POOL, WTRUST_WETH_POOL, WETH_USDC_POOL
 *
 * Optional env vars (expected prices in USD with 18 decimals):
 *   EXPECTED_TRUST_PRICE_USD (default: 0.083e18)
 *   EXPECTED_WETH_PRICE_USD (default: 2200e18)
 *
 * Price tolerance: 50% by default (can be adjusted via PRICE_TOLERANCE_BPS)
 */
contract PriceSanityCheck is UniswapV3SetupBase {
    uint256 internal constant PRICE_PRECISION = 1e18;
    uint256 internal constant DEFAULT_TOLERANCE_BPS = 5000; // 50% tolerance by default

    struct PoolCheck {
        address pool;
        address token0;
        address token1;
        string token0Symbol;
        string token1Symbol;
        uint8 decimals0;
        uint8 decimals1;
        uint160 sqrtPriceX96;
        uint256 derivedPrice;
        uint256 expectedPrice;
        bool isOk;
        string diagnosis;
    }

    function run() external {
        super.setUp();
        console2.log("");
        console2.log("=== Script 7: Minimal Price Sanity Check ===");
        console2.log("");
        console2.log("NOTE: TRUST is the native token. Checking WTRUST (wrapped) pools.");
        infoLine();

        _validateInputs();

        uint256 trustPriceUsd = vm.envOr("EXPECTED_TRUST_PRICE_USD", uint256(0.083e18));
        uint256 wethPriceUsd = vm.envOr("EXPECTED_WETH_PRICE_USD", uint256(2200e18));
        uint256 toleranceBps = vm.envOr("PRICE_TOLERANCE_BPS", DEFAULT_TOLERANCE_BPS);

        console2.log("Expected reference prices:");
        console2.log("  WTRUST (USD):", trustPriceUsd);
        console2.log("  WETH (USD):", wethPriceUsd);
        console2.log("  USDC (USD): 1e18 (stable)");
        console2.log(
            string.concat("  Tolerance: ", vm.toString(toleranceBps), " bps (", vm.toString(toleranceBps / 100), "%)")
        );
        infoLine();

        console2.log("");
        console2.log("=== WTRUST/USDC Pool Check ===");
        PoolCheck memory wtrustUsdc =
            _checkPool(wtrustUsdcPool, wtrustToken, usdcToken, trustPriceUsd, PRICE_PRECISION, toleranceBps);
        _printPoolCheck(wtrustUsdc);

        console2.log("");
        console2.log("=== WTRUST/WETH Pool Check ===");
        PoolCheck memory wtrustWeth =
            _checkPool(wtrustWethPool, wtrustToken, wethToken, trustPriceUsd, wethPriceUsd, toleranceBps);
        _printPoolCheck(wtrustWeth);

        console2.log("");
        console2.log("=== WETH/USDC Pool Check ===");
        PoolCheck memory wethUsdc =
            _checkPool(wethUsdcPool, wethToken, usdcToken, wethPriceUsd, PRICE_PRECISION, toleranceBps);
        _printPoolCheck(wethUsdc);

        _printFinalSummary(wtrustUsdc, wtrustWeth, wethUsdc);
    }

    function _validateInputs() internal view {
        require(wtrustToken != address(0), "WTRUST_TOKEN not set");
        require(usdcToken != address(0), "USDC_TOKEN not set");
        require(wethToken != address(0), "WETH_TOKEN not set");
        require(wtrustUsdcPool != address(0), "WTRUST_USDC_POOL not set");
        require(wtrustWethPool != address(0), "WTRUST_WETH_POOL not set");
        require(wethUsdcPool != address(0), "WETH_USDC_POOL not set");

        console2.log("Pools to check:");
        console2.log("  WTRUST/USDC:", wtrustUsdcPool);
        console2.log("  WTRUST/WETH:", wtrustWethPool);
        console2.log("  WETH/USDC:", wethUsdcPool);
    }

    function _checkPool(
        address poolAddress,
        address tokenA,
        address, /* tokenB */
        uint256 priceAUsd,
        uint256 priceBUsd,
        uint256 toleranceBps
    )
        internal
        view
        returns (PoolCheck memory check)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        check.pool = poolAddress;
        check.token0 = pool.token0();
        check.token1 = pool.token1();
        check.token0Symbol = IERC20Metadata(check.token0).symbol();
        check.token1Symbol = IERC20Metadata(check.token1).symbol();
        check.decimals0 = IERC20Metadata(check.token0).decimals();
        check.decimals1 = IERC20Metadata(check.token1).decimals();

        (uint160 sqrtPriceX96,,,,,, bool unlocked) = pool.slot0();
        check.sqrtPriceX96 = sqrtPriceX96;

        if (sqrtPriceX96 == 0 || !unlocked) {
            check.isOk = false;
            check.diagnosis = "Pool not initialized or locked";
            return check;
        }

        check.derivedPrice = _derivePriceFromSqrt(sqrtPriceX96, check.decimals0, check.decimals1);

        bool aIsToken0 = tokenA == check.token0;
        uint256 price0Usd = aIsToken0 ? priceAUsd : priceBUsd;
        uint256 price1Usd = aIsToken0 ? priceBUsd : priceAUsd;

        if (price0Usd > 0) {
            check.expectedPrice = (price1Usd * PRICE_PRECISION) / price0Usd;
        }

        (check.isOk, check.diagnosis) =
            _evaluatePrice(check.derivedPrice, check.expectedPrice, toleranceBps, check.decimals0, check.decimals1);
    }

    function _derivePriceFromSqrt(
        uint160 sqrtPriceX96,
        uint8 decimals0,
        uint8 decimals1
    )
        internal
        pure
        returns (uint256 price)
    {
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        uint256 priceRaw = Math.mulDiv(sqrtPrice * sqrtPrice, PRICE_PRECISION, Q192);

        int256 decimalDiff = int256(uint256(decimals0)) - int256(uint256(decimals1));
        if (decimalDiff > 0) {
            price = priceRaw * (10 ** uint256(decimalDiff));
        } else if (decimalDiff < 0) {
            price = priceRaw / (10 ** uint256(-decimalDiff));
        } else {
            price = priceRaw;
        }
    }

    function _evaluatePrice(
        uint256 derivedPrice,
        uint256 expectedPrice,
        uint256 toleranceBps,
        uint8 decimals0,
        uint8 decimals1
    )
        internal
        pure
        returns (bool isOk, string memory diagnosis)
    {
        if (expectedPrice == 0) {
            return (false, "Could not compute expected price");
        }

        uint256 lowerBound = (expectedPrice * (10_000 - toleranceBps)) / 10_000;
        uint256 upperBound = (expectedPrice * (10_000 + toleranceBps)) / 10_000;

        if (derivedPrice >= lowerBound && derivedPrice <= upperBound) {
            return (true, "Price within expected range");
        }

        uint256 inversePrice = 0;
        if (derivedPrice > 0) {
            inversePrice = (PRICE_PRECISION * PRICE_PRECISION) / derivedPrice;
        }
        if (inversePrice >= lowerBound && inversePrice <= upperBound) {
            return (false, "LIKELY INVERSION: token0/token1 order may be swapped");
        }

        if (decimals0 != decimals1) {
            uint256 factor = 10 ** 12;
            uint256 scaledUp = derivedPrice * factor;
            uint256 scaledDown = derivedPrice / factor;

            if (scaledUp >= lowerBound && scaledUp <= upperBound) {
                return (false, "LIKELY DECIMALS MISMATCH: price off by ~1e12");
            }
            if (scaledDown >= lowerBound && scaledDown <= upperBound) {
                return (false, "LIKELY DECIMALS MISMATCH: price off by ~1e12");
            }
        }

        if (derivedPrice > upperBound) {
            return (false, "Price TOO HIGH - check initialization");
        }
        return (false, "Price TOO LOW - check initialization");
    }

    function _printPoolCheck(PoolCheck memory check) internal pure {
        console2.log("Pool:", check.pool);
        console2.log("Token ordering:");
        console2.log(string.concat("  token0 (", check.token0Symbol, "):"), check.token0);
        console2.log("  decimals0:", check.decimals0);
        console2.log(string.concat("  token1 (", check.token1Symbol, "):"), check.token1);
        console2.log("  decimals1:", check.decimals1);
        console2.log("");
        console2.log("Price data:");
        console2.log("  sqrtPriceX96:", check.sqrtPriceX96);
        console2.log(
            string.concat("  Derived price (", check.token1Symbol, " per ", check.token0Symbol, "):"),
            check.derivedPrice
        );
        console2.log("  Expected price:", check.expectedPrice);
        console2.log("");
        console2.log(check.isOk ? "Status: OK" : "Status: SUSPICIOUS");
        console2.log("Diagnosis:", check.diagnosis);
    }

    function _printFinalSummary(
        PoolCheck memory wtrustUsdc,
        PoolCheck memory wtrustWeth,
        PoolCheck memory wethUsdc
    )
        internal
        pure
    {
        console2.log("");
        console2.log("=== Final Summary ===");
        console2.log("-------------------------------------------------------------------");
        console2.log("");

        uint256 okCount = 0;
        if (wtrustUsdc.isOk) okCount++;
        if (wtrustWeth.isOk) okCount++;
        if (wethUsdc.isOk) okCount++;

        console2.log("WTRUST/USDC:", wtrustUsdc.isOk ? "OK" : "SUSPICIOUS");
        if (!wtrustUsdc.isOk) console2.log("  ->", wtrustUsdc.diagnosis);

        console2.log("WTRUST/WETH:", wtrustWeth.isOk ? "OK" : "SUSPICIOUS");
        if (!wtrustWeth.isOk) console2.log("  ->", wtrustWeth.diagnosis);

        console2.log("WETH/USDC:", wethUsdc.isOk ? "OK" : "SUSPICIOUS");
        if (!wethUsdc.isOk) console2.log("  ->", wethUsdc.diagnosis);

        console2.log("");
        console2.log("Summary:", okCount, "/ 3 pools OK");

        if (okCount == 3) {
            console2.log("");
            console2.log("All pools passed sanity check!");
        } else {
            console2.log("");
            console2.log("WARNING: Some pools have suspicious prices!");
            console2.log("Common causes:");
            console2.log("  1. Token order inversion during initialization");
            console2.log("  2. Decimals mismatch (especially with USDC at 6 decimals)");
            console2.log("  3. Incorrect reference price assumptions");
            console2.log("");
            console2.log("Recommended actions:");
            console2.log("  - Review sqrtPriceX96 computation in Script 3");
            console2.log("  - Verify token0/token1 ordering matches price direction");
            console2.log("  - Check decimal adjustments for USDC (6) vs others (18)");
        }
    }
}
