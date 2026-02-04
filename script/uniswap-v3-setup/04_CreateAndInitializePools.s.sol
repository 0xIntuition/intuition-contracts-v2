// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { IUniswapV3Pool } from "src/interfaces/external/uniswapv3/IUniswapV3Pool.sol";

/**
 * @title CreateAndInitializePools
 * @notice Script 4 - Create and initialize the three canonical pools
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/04_CreateAndInitializePools.s.sol:CreateAndInitializePools \
 *   --rpc-url intuition_sepolia \
 *   --broadcast
 *
 * Required env vars:
 *   WTRUST_TOKEN, USDC_TOKEN, WETH_TOKEN
 *   WTRUST_USDC_SQRT_PRICE, WTRUST_WETH_SQRT_PRICE, WETH_USDC_SQRT_PRICE
 *
 * OUTPUT: Pool addresses for subsequent scripts
 */
contract CreateAndInitializePools is UniswapV3SetupBase {
    address public deployedWtrustUsdcPool;
    address public deployedWtrustWethPool;
    address public deployedWethUsdcPool;

    function run() external broadcast {
        setUp();
        console2.log("");
        console2.log("=== Script 4: Create and Initialize Canonical Pools ===");
        console2.log("");
        console2.log("NOTE: TRUST is the native token. Using WTRUST (wrapped) for pools.");
        console2.log("NFPM:", NFPM);
        console2.log("Fee tier:", FEE_TIER_MEDIUM, "(0.3%)");
        infoLine();

        _validateInputs();

        uint160 wtrustUsdcSqrtPrice = uint160(vm.envUint("WTRUST_USDC_SQRT_PRICE"));
        uint160 wtrustWethSqrtPrice = uint160(vm.envUint("WTRUST_WETH_SQRT_PRICE"));
        uint160 wethUsdcSqrtPrice = uint160(vm.envUint("WETH_USDC_SQRT_PRICE"));

        console2.log("sqrtPriceX96 values:");
        console2.log("  WTRUST/USDC:", wtrustUsdcSqrtPrice);
        console2.log("  WTRUST/WETH:", wtrustWethSqrtPrice);
        console2.log("  WETH/USDC:", wethUsdcSqrtPrice);
        infoLine();

        console2.log("");
        console2.log("Creating WTRUST/USDC pool...");
        deployedWtrustUsdcPool = _createAndInitializePool(wtrustToken, usdcToken, wtrustUsdcSqrtPrice, "WTRUST/USDC");

        console2.log("");
        console2.log("Creating WTRUST/WETH pool...");
        deployedWtrustWethPool = _createAndInitializePool(wtrustToken, wethToken, wtrustWethSqrtPrice, "WTRUST/WETH");

        console2.log("");
        console2.log("Creating WETH/USDC pool...");
        deployedWethUsdcPool = _createAndInitializePool(wethToken, usdcToken, wethUsdcSqrtPrice, "WETH/USDC");

        _printSummary();
    }

    function _validateInputs() internal view {
        require(wtrustToken != address(0), "WTRUST_TOKEN not set");
        require(usdcToken != address(0), "USDC_TOKEN not set");
        require(wethToken != address(0), "WETH_TOKEN not set");

        console2.log("Token addresses:");
        console2.log("  WTRUST:", wtrustToken);
        console2.log("  USDC:", usdcToken);
        console2.log("  WETH:", wethToken);
    }

    function _createAndInitializePool(
        address tokenA,
        address tokenB,
        uint160 sqrtPriceX96,
        string memory pairName
    )
        internal
        returns (address poolAddress)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);

        console2.log(string.concat("  ", pairName, " pool:"));
        console2.log("    token0:", token0);
        console2.log("    token1:", token1);
        console2.log("    sqrtPriceX96:", sqrtPriceX96);

        address existingPool = factory.getPool(token0, token1, FEE_TIER_MEDIUM);
        if (existingPool != address(0)) {
            console2.log("    Pool already exists:", existingPool);

            IUniswapV3Pool existingPoolContract = IUniswapV3Pool(existingPool);
            (uint160 currentSqrtPrice,,,,,, bool isUnlocked) = existingPoolContract.slot0();

            if (currentSqrtPrice == 0) {
                console2.log("    Pool exists but not initialized. Initializing...");
                existingPoolContract.initialize(sqrtPriceX96);
                console2.log("    Pool initialized!");
            } else {
                console2.log("    Pool already initialized with sqrtPriceX96:", currentSqrtPrice);
                if (!isUnlocked) {
                    console2.log("    WARNING: Pool is currently locked!");
                }
            }
            return existingPool;
        }

        poolAddress = nfpm.createAndInitializePoolIfNecessary(token0, token1, FEE_TIER_MEDIUM, sqrtPriceX96);

        console2.log("    Pool created and initialized:", poolAddress);

        IUniswapV3Pool newPool = IUniswapV3Pool(poolAddress);
        (uint160 actualSqrtPrice, int24 tick,,,,, bool unlocked) = newPool.slot0();
        console2.log("    Actual sqrtPriceX96:", actualSqrtPrice);
        console2.log("    Current tick:", tick);
        console2.log("    Unlocked:", unlocked);
    }

    function _printSummary() internal view {
        console2.log("");
        console2.log("=== Pool Creation Complete ===");
        infoLine();
        console2.log("");
        console2.log("Deployed pool addresses:");
        console2.log("  WTRUST/USDC:", deployedWtrustUsdcPool);
        console2.log("  WTRUST/WETH:", deployedWtrustWethPool);
        console2.log("  WETH/USDC:", deployedWethUsdcPool);
        console2.log("");
        infoLine();
        console2.log("");
        console2.log("Environment variables for subsequent scripts:");
        console2.log(string.concat("export WTRUST_USDC_POOL=", vm.toString(deployedWtrustUsdcPool)));
        console2.log(string.concat("export WTRUST_WETH_POOL=", vm.toString(deployedWtrustWethPool)));
        console2.log(string.concat("export WETH_USDC_POOL=", vm.toString(deployedWethUsdcPool)));
    }
}
