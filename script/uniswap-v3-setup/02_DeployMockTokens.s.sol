// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { UniswapV3SetupBase } from "./UniswapV3SetupBase.s.sol";
import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

/**
 * @title DeployMockTokens
 * @notice Script 2 - Deploy WrappedTrust (WTRUST) and mock ERC20 tokens (USDC, WETH)
 *
 * This script deploys:
 *   - WrappedTrust (WTRUST): Wrapper for native TRUST, used in Uniswap pools
 *   - Mock USDC (6 decimals): For testing TRUST/USDC pool
 *   - Mock WETH (18 decimals): For testing TRUST/WETH and WETH/USDC pools
 *
 * USAGE:
 * forge script script/uniswap-v3-setup/02_DeployMockTokens.s.sol:DeployMockTokens \
 *   --rpc-url intuition_sepolia \
 *      --broadcast \
 *      --slow \
 *      --verify \
 *      --chain 13579 \
 *      --verifier blockscout \
 *      --verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'
 *
 * OUTPUT: Set these env vars for subsequent scripts:
 *   WTRUST_TOKEN=<deployed_address>  (Wrapped native TRUST)
 *   USDC_TOKEN=<deployed_address>
 *   WETH_TOKEN=<deployed_address>
 */
contract DeployMockTokens is UniswapV3SetupBase {
    uint8 public constant USDC_DECIMALS = 6;
    uint8 public constant WETH_DECIMALS = 18;

    uint256 public constant USDC_MINT_AMOUNT = 10_000_000 * 1e6;
    uint256 public constant WETH_MINT_AMOUNT = 10_000 * 1e18;
    uint256 public constant WTRUST_DEPOSIT_AMOUNT = 10_000_000 * 1e18;

    WrappedTrust public wrappedTrust = WrappedTrust(payable(0xDE80b6EE63f7D809427CA350e30093F436A0fe35));
    ERC20Mock public mockUsdc;
    ERC20Mock public mockWeth;

    function run() external broadcast {
        console2.log("");
        console2.log("=== Script 2: Deploy Mock Tokens ===");
        console2.log("Deployer:", broadcaster);
        console2.log("");
        infoLine();

        _deployTokens();
        _mintAndDepositInitialBalances();
        _printOutputConfig();
    }

    function _deployTokens() internal {
        console2.log("");
        console2.log("Deploying tokens...");

        console2.log("  WTRUST (WrappedTrust) already deployed:", address(wrappedTrust));
        console2.log("    Name:", wrappedTrust.name());
        console2.log("    Symbol:", wrappedTrust.symbol());
        console2.log("    Decimals:", wrappedTrust.decimals());

        mockUsdc = new ERC20Mock("Mock USDC", "mUSDC", USDC_DECIMALS);
        console2.log("  USDC deployed:", address(mockUsdc));
        console2.log("    Name:", mockUsdc.name());
        console2.log("    Symbol:", mockUsdc.symbol());
        console2.log("    Decimals:", mockUsdc.decimals());

        mockWeth = new ERC20Mock("Mock WETH", "mWETH", WETH_DECIMALS);
        console2.log("  WETH deployed:", address(mockWeth));
        console2.log("    Name:", mockWeth.name());
        console2.log("    Symbol:", mockWeth.symbol());
        console2.log("    Decimals:", mockWeth.decimals());
    }

    function _mintAndDepositInitialBalances() internal {
        console2.log("");
        console2.log("Minting/depositing initial balances to deployer...");

        uint256 deployerNativeBalance = broadcaster.balance;
        console2.log("  Deployer native TRUST balance:", deployerNativeBalance);

        if (deployerNativeBalance >= WTRUST_DEPOSIT_AMOUNT) {
            wrappedTrust.deposit{ value: WTRUST_DEPOSIT_AMOUNT }();
            console2.log("  WTRUST deposited:", WTRUST_DEPOSIT_AMOUNT / 1e18, "tokens");
        } else {
            console2.log("  WARNING: Insufficient native TRUST for full deposit");
            console2.log("  Depositing available amount:", deployerNativeBalance / 2);
            if (deployerNativeBalance > 1 ether) {
                wrappedTrust.deposit{ value: deployerNativeBalance / 2 }();
            }
        }

        mockUsdc.mint(broadcaster, USDC_MINT_AMOUNT);
        console2.log("  USDC minted:", USDC_MINT_AMOUNT / 1e6, "tokens");

        mockWeth.mint(broadcaster, WETH_MINT_AMOUNT);
        console2.log("  WETH minted:", WETH_MINT_AMOUNT / 1e18, "tokens");

        address additionalWallet = vm.envOr("ADDITIONAL_TEST_WALLET", address(0));
        if (additionalWallet != address(0)) {
            console2.log("");
            console2.log("Minting to additional test wallet:", additionalWallet);

            mockUsdc.mint(additionalWallet, USDC_MINT_AMOUNT / 10);
            mockWeth.mint(additionalWallet, WETH_MINT_AMOUNT / 10);

            console2.log("  Minted 10% of initial amounts to additional wallet");
            console2.log("  NOTE: Additional wallet must deposit native TRUST to get WTRUST");
        }
    }

    function _printOutputConfig() internal view {
        console2.log("");
        console2.log("=== Deployment Complete ===");
        infoLine();
        console2.log("");
        console2.log("Set these environment variables for subsequent scripts:");
        console2.log("");
        console2.log(string.concat("export WTRUST_TOKEN=", vm.toString(address(wrappedTrust))));
        console2.log(string.concat("export USDC_TOKEN=", vm.toString(address(mockUsdc))));
        console2.log(string.concat("export WETH_TOKEN=", vm.toString(address(mockWeth))));
        console2.log("");
        infoLine();
        console2.log("");
        console2.log("Token Summary:");
        console2.log("  WTRUST (Wrapped Native):", address(wrappedTrust), "(18 decimals)");
        console2.log("  USDC (Mock):", address(mockUsdc), "(6 decimals)");
        console2.log("  WETH (Mock):", address(mockWeth), "(18 decimals)");
        console2.log("");
        console2.log("Balances (deployer):");
        console2.log("  Native TRUST:", broadcaster.balance);
        console2.log("  WTRUST:", wrappedTrust.balanceOf(broadcaster));
        console2.log("  USDC:", mockUsdc.balanceOf(broadcaster));
        console2.log("  WETH:", mockWeth.balanceOf(broadcaster));
        console2.log("");
        console2.log("IMPORTANT: To get more WTRUST, send native TRUST to the WTRUST contract");
        console2.log("           or call wrappedTrust.deposit{value: amount}()");
    }
}
