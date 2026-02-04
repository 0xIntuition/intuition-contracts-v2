// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { IUniswapV3Pool } from "src/interfaces/external/uniswapv3/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "src/interfaces/external/uniswapv3/INonfungiblePositionManager.sol";

/**
 * @title SeedLiquidity
 * @notice Script 5 - Seed liquidity with wide ranges for initial pool usability
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/05_SeedLiquidity.s.sol:SeedLiquidity \
 *   --rpc-url intuition_sepolia \
 *   --broadcast
 *
 * Required env vars:
 *   WTRUST_TOKEN, USDC_TOKEN, WETH_TOKEN
 *   WTRUST_USDC_POOL, WTRUST_WETH_POOL, WETH_USDC_POOL
 *
 * Optional env vars (deposit amounts):
 *   WTRUST_DEPOSIT_AMOUNT (default: 265,060 WTRUST)
 *   USDC_DEPOSIT_AMOUNT (default: 22,000 USDC)
 *   WETH_DEPOSIT_AMOUNT (default: 10 WETH)
 *
 * OUTPUT: LP position tokenIds
 */
contract SeedLiquidity is UniswapV3SetupBase {
    uint256 public constant DEFAULT_WTRUST_DEPOSIT = 265_060 * 1e18;
    uint256 public constant DEFAULT_USDC_DEPOSIT = 22_000 * 1e6;
    uint256 public constant DEFAULT_WETH_DEPOSIT = 10 * 1e18;

    struct LiquidityResult {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
    }

    struct PoolState {
        address token0;
        address token1;
        int24 currentTick;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
    }

    LiquidityResult public wtrustUsdcPosition;
    LiquidityResult public wtrustWethPosition;
    LiquidityResult public wethUsdcPosition;

    function run() external broadcast {
        console2.log("");
        console2.log("=== Script 5: Seed Liquidity with Wide Ranges ===");
        console2.log("");
        console2.log("NOTE: TRUST is the native token. Using WTRUST (wrapped) for pools.");
        console2.log("NFPM:", NFPM);
        infoLine();

        _validateInputs();

        uint256 wtrustDeposit = vm.envOr("WTRUST_DEPOSIT_AMOUNT", DEFAULT_WTRUST_DEPOSIT);
        uint256 usdcDeposit = vm.envOr("USDC_DEPOSIT_AMOUNT", DEFAULT_USDC_DEPOSIT);
        uint256 wethDeposit = vm.envOr("WETH_DEPOSIT_AMOUNT", DEFAULT_WETH_DEPOSIT);

        console2.log("Deposit amounts:");
        console2.log("  WTRUST:", wtrustDeposit);
        console2.log("  USDC:", usdcDeposit);
        console2.log("  WETH:", wethDeposit);
        infoLine();

        _approveTokens(wtrustDeposit, usdcDeposit, wethDeposit);

        console2.log("");
        console2.log("Adding liquidity to WTRUST/USDC pool...");
        wtrustUsdcPosition = _addLiquidity(wtrustUsdcPool, wtrustToken, usdcToken, wtrustDeposit, usdcDeposit);

        console2.log("");
        console2.log("Adding liquidity to WTRUST/WETH pool...");
        wtrustWethPosition = _addLiquidity(wtrustWethPool, wtrustToken, wethToken, wtrustDeposit, wethDeposit);

        console2.log("");
        console2.log("Adding liquidity to WETH/USDC pool...");
        wethUsdcPosition = _addLiquidity(wethUsdcPool, wethToken, usdcToken, wethDeposit, usdcDeposit);

        _printSummary();
    }

    function _validateInputs() internal view {
        require(wtrustToken != address(0), "WTRUST_TOKEN not set");
        require(usdcToken != address(0), "USDC_TOKEN not set");
        require(wethToken != address(0), "WETH_TOKEN not set");
        require(wtrustUsdcPool != address(0), "WTRUST_USDC_POOL not set");
        require(wtrustWethPool != address(0), "WTRUST_WETH_POOL not set");
        require(wethUsdcPool != address(0), "WETH_USDC_POOL not set");

        console2.log("Pool addresses:");
        console2.log("  WTRUST/USDC:", wtrustUsdcPool);
        console2.log("  WTRUST/WETH:", wtrustWethPool);
        console2.log("  WETH/USDC:", wethUsdcPool);
    }

    function _approveTokens(uint256 wtrustAmount, uint256 usdcAmount, uint256 wethAmount) internal {
        console2.log("");
        console2.log("Approving tokens for NFPM...");

        IERC20(wtrustToken).approve(NFPM, wtrustAmount * 2);
        console2.log("  WTRUST approved:", wtrustAmount * 2);

        IERC20(usdcToken).approve(NFPM, usdcAmount * 2);
        console2.log("  USDC approved:", usdcAmount * 2);

        IERC20(wethToken).approve(NFPM, wethAmount * 2);
        console2.log("  WETH approved:", wethAmount * 2);
    }

    function _getPoolState(
        address poolAddress,
        address tokenA,
        address tokenB
    )
        internal
        view
        returns (PoolState memory state)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (state.token0, state.token1) = _sortTokens(tokenA, tokenB);

        (uint160 sqrtPriceX96, int24 currentTick,,,,, bool unlocked) = pool.slot0();
        require(unlocked, "Pool is locked");
        require(sqrtPriceX96 > 0, "Pool not initialized");

        state.currentTick = currentTick;
        state.tickSpacing = pool.tickSpacing();

        (state.tickLower, state.tickUpper) = _computeWideRange(currentTick, state.tickSpacing);

        console2.log("  Current pool state:");
        console2.log("    sqrtPriceX96:", sqrtPriceX96);
        console2.log("    Current tick:", currentTick);
        console2.log("  Tick range (wide):");
        console2.log("    tickLower:", state.tickLower);
        console2.log("    tickUpper:", state.tickUpper);
        console2.log("    tickSpacing:", state.tickSpacing);
    }

    function _addLiquidity(
        address poolAddress,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        internal
        returns (LiquidityResult memory result)
    {
        PoolState memory state = _getPoolState(poolAddress, tokenA, tokenB);

        uint256 amount0Desired;
        uint256 amount1Desired;
        if (tokenA == state.token0) {
            amount0Desired = amountA;
            amount1Desired = amountB;
        } else {
            amount0Desired = amountB;
            amount1Desired = amountA;
        }

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: state.token0,
            token1: state.token1,
            fee: FEE_TIER_MEDIUM,
            tickLower: state.tickLower,
            tickUpper: state.tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: broadcaster,
            deadline: block.timestamp + 3600
        });

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = nfpm.mint(params);

        console2.log("  Position minted:");
        console2.log("    tokenId:", tokenId);
        console2.log("    liquidity:", liquidity);
        console2.log("    amount0 deposited:", amount0);
        console2.log("    amount1 deposited:", amount1);

        result.tokenId = tokenId;
        result.liquidity = liquidity;
        result.amount0 = amount0;
        result.amount1 = amount1;
        result.tickLower = state.tickLower;
        result.tickUpper = state.tickUpper;
    }

    function _computeWideRange(int24 currentTick, int24 tickSpacing) internal pure returns (int24 lower, int24 upper) {
        int24 minUsableTick = ((MIN_TICK / tickSpacing) + 1) * tickSpacing;
        int24 maxUsableTick = ((MAX_TICK / tickSpacing) - 1) * tickSpacing;

        int24 rangeWidth = 100 * tickSpacing;
        lower = _nearestUsableTick(currentTick - rangeWidth, tickSpacing);
        upper = _nearestUsableTick(currentTick + rangeWidth, tickSpacing);

        if (lower < minUsableTick) lower = minUsableTick;
        if (upper > maxUsableTick) upper = maxUsableTick;

        require(lower < upper, "Invalid tick range");
    }

    function _printSummary() internal view {
        console2.log("");
        console2.log("=== Liquidity Seeding Complete ===");
        infoLine();
        console2.log("");
        console2.log("LP Position Summary:");
        console2.log("");
        console2.log("WTRUST/USDC:");
        console2.log("  tokenId:", wtrustUsdcPosition.tokenId);
        console2.log("  liquidity:", wtrustUsdcPosition.liquidity);
        console2.log("  amount0:", wtrustUsdcPosition.amount0);
        console2.log("  amount1:", wtrustUsdcPosition.amount1);
        console2.log("  tickLower:", wtrustUsdcPosition.tickLower);
        console2.log("  tickUpper:", wtrustUsdcPosition.tickUpper);
        console2.log("");
        console2.log("WTRUST/WETH:");
        console2.log("  tokenId:", wtrustWethPosition.tokenId);
        console2.log("  liquidity:", wtrustWethPosition.liquidity);
        console2.log("  amount0:", wtrustWethPosition.amount0);
        console2.log("  amount1:", wtrustWethPosition.amount1);
        console2.log("  tickLower:", wtrustWethPosition.tickLower);
        console2.log("  tickUpper:", wtrustWethPosition.tickUpper);
        console2.log("");
        console2.log("WETH/USDC:");
        console2.log("  tokenId:", wethUsdcPosition.tokenId);
        console2.log("  liquidity:", wethUsdcPosition.liquidity);
        console2.log("  amount0:", wethUsdcPosition.amount0);
        console2.log("  amount1:", wethUsdcPosition.amount1);
        console2.log("  tickLower:", wethUsdcPosition.tickLower);
        console2.log("  tickUpper:", wethUsdcPosition.tickUpper);
        console2.log("");
        infoLine();
        console2.log("");
        console2.log("LP Position Token IDs:");
        console2.log(string.concat("  WTRUST_USDC_LP_TOKEN_ID=", vm.toString(wtrustUsdcPosition.tokenId)));
        console2.log(string.concat("  WTRUST_WETH_LP_TOKEN_ID=", vm.toString(wtrustWethPosition.tokenId)));
        console2.log(string.concat("  WETH_USDC_LP_TOKEN_ID=", vm.toString(wethUsdcPosition.tokenId)));
    }
}
