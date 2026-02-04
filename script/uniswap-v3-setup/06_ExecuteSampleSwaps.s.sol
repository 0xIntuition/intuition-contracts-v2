// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { ISwapRouter02 } from "src/interfaces/external/uniswapv3/ISwapRouter02.sol";
import { IQuoterV2 } from "src/interfaces/external/uniswapv3/IQuoterV2.sol";

/**
 * @title ExecuteSampleSwaps
 * @notice Script 6 - Execute sample swaps end-to-end to validate the setup
 *
 * IMPORTANT: TRUST is the native token. We use WTRUST (Wrapped TRUST) for pools.
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/06_ExecuteSampleSwaps.s.sol:ExecuteSampleSwaps \
 *   --rpc-url intuition_sepolia \
 *   --broadcast \
 *   --slow
 *
 * Required env vars:
 *   WTRUST_TOKEN, USDC_TOKEN, WETH_TOKEN
 *
 * Optional env vars (swap amounts):
 *   WTRUST_SWAP_AMOUNT (default: 1,000 WTRUST)
 *   USDC_SWAP_AMOUNT (default: 22 USDC)
 *   WETH_SWAP_AMOUNT (default: 0.01 WETH)
 */
contract ExecuteSampleSwaps is UniswapV3SetupBase {
    uint256 public constant DEFAULT_WTRUST_SWAP = 1000 * 1e18;
    uint256 public constant DEFAULT_USDC_SWAP = 22 * 1e6;
    uint256 public constant DEFAULT_WETH_SWAP = 0.01 * 1e18;

    uint256 public constant SLIPPAGE_BPS = 100;

    struct SwapResult {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 quotedAmount;
        uint256 effectivePrice;
        bool passed;
    }

    SwapResult[] public swapResults;

    function run() external broadcast {
        super.setUp();
        console2.log("");
        console2.log("=== Script 6: Execute Sample Swaps End-to-End ===");
        console2.log("");
        console2.log("NOTE: TRUST is the native token. Using WTRUST (wrapped) for swaps.");
        console2.log("SwapRouter02:", SWAP_ROUTER_02);
        console2.log("QuoterV2:", QUOTER_V2);
        infoLine();

        _validateInputs();

        uint256 wtrustSwap = vm.envOr("WTRUST_SWAP_AMOUNT", DEFAULT_WTRUST_SWAP);
        uint256 usdcSwap = vm.envOr("USDC_SWAP_AMOUNT", DEFAULT_USDC_SWAP);
        uint256 wethSwap = vm.envOr("WETH_SWAP_AMOUNT", DEFAULT_WETH_SWAP);

        console2.log("Swap amounts:");
        console2.log("  WTRUST:", wtrustSwap);
        console2.log("  USDC:", usdcSwap);
        console2.log("  WETH:", wethSwap);
        infoLine();

        _approveAllTokens(wtrustSwap, usdcSwap, wethSwap);

        console2.log("");
        console2.log("=== WTRUST <-> USDC Swaps ===");
        _executeSwap(wtrustToken, usdcToken, wtrustSwap, "WTRUST -> USDC");
        _executeSwap(usdcToken, wtrustToken, usdcSwap, "USDC -> WTRUST");

        console2.log("");
        console2.log("=== WTRUST <-> WETH Swaps ===");
        _executeSwap(wtrustToken, wethToken, wtrustSwap, "WTRUST -> WETH");
        _executeSwap(wethToken, wtrustToken, wethSwap, "WETH -> WTRUST");

        console2.log("");
        console2.log("=== WETH <-> USDC Swaps ===");
        _executeSwap(wethToken, usdcToken, wethSwap, "WETH -> USDC");
        _executeSwap(usdcToken, wethToken, usdcSwap, "USDC -> WETH");

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

    function _approveAllTokens(uint256 wtrustAmount, uint256 usdcAmount, uint256 wethAmount) internal {
        console2.log("");
        console2.log("Approving tokens for SwapRouter...");

        uint256 totalWtrust = wtrustAmount * 3;
        uint256 totalUsdc = usdcAmount * 3;
        uint256 totalWeth = wethAmount * 3;

        IERC20(wtrustToken).approve(SWAP_ROUTER_02, totalWtrust);
        IERC20(usdcToken).approve(SWAP_ROUTER_02, totalUsdc);
        IERC20(wethToken).approve(SWAP_ROUTER_02, totalWeth);

        console2.log("  Tokens approved for router");
    }

    function _executeSwap(address tokenIn, address tokenOut, uint256 amountIn, string memory swapName) internal {
        console2.log("");
        console2.log(swapName);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(broadcaster);

        uint256 quotedAmount = _getQuote(tokenIn, tokenOut, amountIn);
        console2.log("  Quoted output:", quotedAmount);

        uint256 minAmountOut = (quotedAmount * (10_000 - SLIPPAGE_BPS)) / 10_000;
        console2.log("  Min amount out (1% slippage):", minAmountOut);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: FEE_TIER_MEDIUM,
            recipient: broadcaster,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut;
        bool passed = true;

        try swapRouter.exactInputSingle(params) returns (uint256 out) {
            amountOut = out;
            console2.log("  Actual output:", amountOut);
        } catch Error(string memory reason) {
            console2.log("  SWAP FAILED:", reason);
            passed = false;
        } catch {
            console2.log("  SWAP FAILED: Unknown error");
            passed = false;
        }

        if (passed) {
            uint256 balanceAfter = IERC20(tokenOut).balanceOf(broadcaster);
            uint256 actualReceived = balanceAfter - balanceBefore;
            console2.log("  Actual received:", actualReceived);

            uint256 effectivePrice = 0;
            if (amountOut > 0) {
                effectivePrice = (amountIn * 1e18) / amountOut;
            }
            console2.log("  Effective price (tokenIn/tokenOut * 1e18):", effectivePrice);

            bool quoteDiff = quotedAmount > 0 && amountOut > 0;
            if (quoteDiff) {
                int256 diff = int256(amountOut) - int256(quotedAmount);
                console2.log("  Quote vs Actual diff:", diff);
            }

            console2.log("  Status: PASSED");
        } else {
            console2.log("  Status: FAILED");
        }

        swapResults.push(
            SwapResult({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                amountOut: amountOut,
                quotedAmount: quotedAmount,
                effectivePrice: (passed && amountOut > 0) ? (amountIn * 1e18) / amountOut : 0,
                passed: passed
            })
        );
    }

    function _getQuote(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 quotedAmount) {
        IQuoterV2.QuoteExactInputSingleParams memory quoteParams = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: tokenIn, tokenOut: tokenOut, amountIn: amountIn, fee: FEE_TIER_MEDIUM, sqrtPriceLimitX96: 0
        });

        try quoter.quoteExactInputSingle(quoteParams) returns (uint256 amountOut, uint160, uint32, uint256) {
            return amountOut;
        } catch {
            return 0;
        }
    }

    function _printSummary() internal view {
        console2.log("");
        console2.log("=== Swap Test Summary ===");
        infoLine();

        uint256 passed = 0;
        uint256 failed = 0;

        for (uint256 i = 0; i < swapResults.length; i++) {
            if (swapResults[i].passed) {
                passed++;
            } else {
                failed++;
            }
        }

        console2.log("");
        console2.log("Results:");
        console2.log("  Passed:", passed);
        console2.log("  Failed:", failed);
        console2.log("  Total:", swapResults.length);
        console2.log("");

        if (failed == 0) {
            console2.log("All swap tests PASSED!");
        } else {
            console2.log("WARNING: Some swap tests FAILED!");
            console2.log("Failed swaps:");
            for (uint256 i = 0; i < swapResults.length; i++) {
                if (!swapResults[i].passed) {
                    console2.log("  -", swapResults[i].tokenIn, "->", swapResults[i].tokenOut);
                }
            }
        }

        console2.log("");
        infoLine();
    }
}
