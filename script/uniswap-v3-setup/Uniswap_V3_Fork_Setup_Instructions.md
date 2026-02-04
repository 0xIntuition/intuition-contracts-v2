# Uniswap V3 Fork Setup Instructions

This directory contains 7 scripts to take a deployed Uniswap V3 fork from "contracts deployed" to a "usable testnet sandbox with pools, liquidity, swaps, and price sanity checks".

## Important: TRUST is the Native Token

**TRUST is the native gas token on this chain** (like ETH on Ethereum). For Uniswap V3 pool operations, we use **WTRUST (Wrapped TRUST)** - a standard WETH-style wrapper contract.

When working with these scripts:
- Users hold native TRUST for gas
- Users wrap TRUST → WTRUST to interact with pools
- Users unwrap WTRUST → TRUST to get native tokens back

---

## Deployed Contract Addresses (adjust as needed)

These addresses are hardcoded in `UniswapV3SetupBase.s.sol`:

| Contract | Address |
|----------|---------|
| V3 Factory | `0x3C1a5B48C1422D2260DC07b87Edb5a187a95bFe8` |
| NonfungiblePositionManager | `0xc6Ec0Ee7795b46A58D78Df323672c3d70bd9C524` |
| SwapRouter02 | `0x0334BBdE746c9f938ba903f22af5B02A58310C4A` |
| QuoterV2 | `0x77548B0521e71Aafb2E3FCb62b2066bF999c7345` |

---

## Script Overview

| # | Script | Purpose | Requires Broadcast |
|---|--------|---------|-------------------|
| 1 | `01_EnableFeeTiers.s.sol` | Enable fee tiers on factory | Yes |
| 2 | `02_DeployMockTokens.s.sol` | Deploy WTRUST + mock USDC/WETH | Yes |
| 3 | `03_ComputeSqrtPriceX96.s.sol` | Compute pool init prices | No (view) |
| 4 | `04_CreateAndInitializePools.s.sol` | Create and init pools | Yes |
| 5 | `05_SeedLiquidity.s.sol` | Add initial liquidity | Yes |
| 6 | `06_ExecuteSampleSwaps.s.sol` | Test swap functionality | Yes |
| 7 | `07_PriceSanityCheck.s.sol` | Validate pool prices | No (view) |

---

## Execution Order

Run scripts in order. Each script outputs environment variables needed for subsequent scripts.

### Prerequisites

Set your deployer key:
```bash
export DEPLOYER_KEY=<your_private_key>
# OR
export DEPLOYER_ADDRESS=<your_address>  # for view-only scripts
```

---

## Script 1: Enable Fee Tiers and Tick Spacings

### Purpose
Ensures the Uniswap V3 Factory supports the required fee tiers before pool creation.

### Fee Tiers Enabled
| Fee | Tick Spacing | Use Case |
|-----|--------------|----------|
| 500 (0.05%) | 10 | Stable pairs |
| 3000 (0.3%) | 60 | Standard pairs |
| 10000 (1%) | 200 | Exotic pairs |

### Why Run This
- Pool creation will revert if the fee tier isn't enabled
- Script is idempotent - safe to re-run

### Command
```bash
forge script script/uniswap-v3-setup/01_EnableFeeTiers.s.sol:EnableFeeTiers \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Validation
Script automatically verifies `feeAmountTickSpacing(fee)` returns expected values.

---

## Script 2: Deploy Mock Tokens

### Purpose
Deploy test tokens for the testnet environment:
- **WTRUST**: Wrapped TRUST (wrapper for native token) - already deployed, address output for reference (18 decimals)
- **Mock USDC**: 6 decimals
- **Mock WETH**: 18 decimals

### Why Run This
- Provides ERC20 tokens for pool creation
- Real bridged assets may not be available on testnet
- Controlled supply for testing

### Amounts Minted
| Token | Amount | Recipient |
|-------|--------|-----------|
| WTRUST | 10,000,000 | Deployer |
| USDC | 10,000,000 | Deployer |
| WETH | 10,000 | Deployer |

### Command
```bash
forge script script/uniswap-v3-setup/02_DeployMockTokens.s.sol:DeployMockTokens \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Output Variables
```bash
export WTRUST_TOKEN=<address>
export USDC_TOKEN=<address>
export WETH_TOKEN=<address>
```

### Getting More WTRUST
To wrap native TRUST:
```solidity
// Send native TRUST to WTRUST contract
WTRUST.deposit{value: amount}();
// OR simply transfer native TRUST to the WTRUST address
```

---

## Script 3: Compute sqrtPriceX96 for Pool Initialization

### Purpose
Calculate the correct `sqrtPriceX96` initialization values for each pool, accounting for:
- Token address ordering (token0 < token1)
- Decimal differences (USDC = 6, others = 18)
- Reference USD prices

### Why Run This
- `sqrtPriceX96` must be calculated correctly or pools will have inverted/wrong prices
- This is the most common source of Uniswap V3 setup errors
- Script shows you the math and validates before pool creation

### Default Reference Prices (adjust as needed)
| Token | Price (USD) |
|-------|-------------|
| TRUST | $0.083 |
| WETH | $2,200 |
| USDC | $1.00 |

### Command
```bash
# Set token addresses from Script 2 first
export WTRUST_TOKEN=<address>
export USDC_TOKEN=<address>
export WETH_TOKEN=<address>

# Optionally override prices
export TRUST_PRICE_USD=25000000000000000  # 0.025e18
export WETH_PRICE_USD=2500000000000000000000  # 2500e18

forge script script/uniswap-v3-setup/03_ComputeSqrtPriceX96.s.sol:ComputeSqrtPriceX96 \
  --rpc-url <RPC_URL>
```

### Output Variables
```bash
export WTRUST_USDC_SQRT_PRICE=<value>
export WTRUST_WETH_SQRT_PRICE=<value>
export WETH_USDC_SQRT_PRICE=<value>
```

### Understanding sqrtPriceX96
- Uniswap V3 stores price as `sqrt(token1/token0) * 2^96`
- token0 is always the address that sorts lower (i.e. address that resolves to a lower `uint160` value)
- The script handles all the math for you

---

## Script 4: Create and Initialize Canonical Pools

### Purpose
Create the three canonical pools using the NFPM's `createAndInitializePoolIfNecessary`:
- WTRUST/USDC @ 0.3% fee
- WTRUST/WETH @ 0.3% fee
- WETH/USDC @ 0.3% fee

### Why Run This
- Pools must be created before liquidity can be added
- Initialization sets the starting price
- Script is idempotent - won't break if pools exist

### Command
```bash
# Requires tokens + sqrt prices from previous scripts
forge script script/uniswap-v3-setup/04_CreateAndInitializePools.s.sol:CreateAndInitializePools \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Output Variables
```bash
export WTRUST_USDC_POOL=<address>
export WTRUST_WETH_POOL=<address>
export WETH_USDC_POOL=<address>
```

---

## Script 5: Seed Liquidity with Wide Ranges

### Purpose
Make pools usable by adding initial liquidity:
- Prevents swap reverts from missing liquidity
- Ensures reasonable price impact for test trades
- Provides baseline liquidity for UI testing

### Liquidity Strategy
- Uses **wide tick ranges** (±100 tick spacings from current price)
- Wide ranges = less out-of-range risk, simpler management
- Mints LP NFT positions to the deployer

### Default Deposit Amounts
| Pool | Token A | Token B |
|------|---------|---------|
| WTRUST/USDC | 265,060 WTRUST | 22,000 USDC |
| WTRUST/WETH | 265,060 WTRUST | 10 WETH |
| WETH/USDC | 10 WETH | 22,000 USDC |

### Command
```bash
# Requires tokens + pools from previous scripts
# Optionally override amounts
export WTRUST_DEPOSIT_AMOUNT=265060000000000000000000  # 265,060 * 1e18
export USDC_DEPOSIT_AMOUNT=22000000000  # 22,000 * 1e6
export WETH_DEPOSIT_AMOUNT=10000000000000000000  # 10 * 1e18

forge script script/uniswap-v3-setup/05_SeedLiquidity.s.sol:SeedLiquidity \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Output
- LP position tokenIds for each pool
- Actual amounts deposited
- Tick ranges used

---

## Script 6: Execute Sample Swaps End-to-End

### Purpose
Prove the entire stack works by executing real swaps:
- Tests all 6 swap directions (bidirectional for each pair)
- Compares quoted amounts vs executed amounts
- Validates swap router configuration

### Swaps Executed
1. WTRUST → USDC
2. USDC → WTRUST
3. WTRUST → WETH
4. WETH → WTRUST
5. WETH → USDC
6. USDC → WETH

### Default Swap Amounts
| Token | Amount |
|-------|--------|
| WTRUST | 1,000 |
| USDC | 22 |
| WETH | 0.01 |

### Command
```bash
# Optionally override swap amounts
export WTRUST_SWAP_AMOUNT=1000000000000000000000  # 1000 * 1e18
export USDC_SWAP_AMOUNT=22000000  # 22 * 1e6
export WETH_SWAP_AMOUNT=10000000000000000  # 0.01 * 1e18

forge script script/uniswap-v3-setup/06_ExecuteSampleSwaps.s.sol:ExecuteSampleSwaps \
  --rpc-url <RPC_URL> \
  --broadcast
```

### Output
- Pass/fail status for each swap
- Quoted vs actual amounts
- Effective prices

---

## Script 7: Minimal Price Sanity Check

### Purpose
Catch the two most common V3 setup failures early:
1. **Inverted token order** / inverted initialization price
2. **Decimals mismatch** (often off by 1e12 with USDC)

### Why Run This
- Run immediately after pool initialization
- Run before seeding liquidity (easier to fix empty pools)
- Catches errors that would otherwise cause bad trades

### What It Checks
For each pool:
- Reads `slot0.sqrtPriceX96`
- Converts to human-readable price
- Compares against expected reference price
- Reports "OK" or "SUSPICIOUS" with likely cause

### Default Tolerance
- 50% tolerance (5000 bps) - pools are considered OK if within ±50%
- Adjustable via `PRICE_TOLERANCE_BPS`

### Command
```bash
# Optionally override expected prices
export EXPECTED_TRUST_PRICE_USD=25000000000000000  # 0.025e18
export EXPECTED_WETH_PRICE_USD=2500000000000000000000  # 2500e18
export PRICE_TOLERANCE_BPS=5000  # 50%

forge script script/uniswap-v3-setup/07_PriceSanityCheck.s.sol:PriceSanityCheck \
  --rpc-url <RPC_URL>
```

### Diagnosis Messages
| Message | Likely Cause |
|---------|--------------|
| "Price within expected range" | All good! |
| "LIKELY INVERSION" | token0/token1 order swapped in sqrtPrice calculation |
| "LIKELY DECIMALS MISMATCH" | Didn't account for USDC's 6 decimals |
| "Price TOO HIGH/LOW" | Check sqrtPriceX96 calculation |

---

## Complete Setup Example

```bash
# Set deployer
export DEPLOYER_KEY=<private_key>
export RPC_URL=<your_rpc_url>

# 1. Enable fee tiers
forge script script/uniswap-v3-setup/01_EnableFeeTiers.s.sol:EnableFeeTiers \
  --rpc-url $RPC_URL --broadcast

# 2. Deploy tokens (copy output vars)
forge script script/uniswap-v3-setup/02_DeployMockTokens.s.sol:DeployMockTokens \
  --rpc-url $RPC_URL --broadcast
# --> export WTRUST_TOKEN=... USDC_TOKEN=... WETH_TOKEN=...

# 3. Compute prices (copy output vars)
forge script script/uniswap-v3-setup/03_ComputeSqrtPriceX96.s.sol:ComputeSqrtPriceX96 \
  --rpc-url $RPC_URL
# --> export WTRUST_USDC_SQRT_PRICE=... WTRUST_WETH_SQRT_PRICE=... WETH_USDC_SQRT_PRICE=...

# 4. Create pools (copy output vars)
forge script script/uniswap-v3-setup/04_CreateAndInitializePools.s.sol:CreateAndInitializePools \
  --rpc-url $RPC_URL --broadcast
# --> export WTRUST_USDC_POOL=... WTRUST_WETH_POOL=... WETH_USDC_POOL=...

# 5. Quick sanity check (optional but recommended)
forge script script/uniswap-v3-setup/07_PriceSanityCheck.s.sol:PriceSanityCheck \
  --rpc-url $RPC_URL

# 6. Seed liquidity
forge script script/uniswap-v3-setup/05_SeedLiquidity.s.sol:SeedLiquidity \
  --rpc-url $RPC_URL --broadcast

# 7. Test swaps
forge script script/uniswap-v3-setup/06_ExecuteSampleSwaps.s.sol:ExecuteSampleSwaps \
  --rpc-url $RPC_URL --broadcast

# 8. Final sanity check
forge script script/uniswap-v3-setup/07_PriceSanityCheck.s.sol:PriceSanityCheck \
  --rpc-url $RPC_URL
```

---

## Troubleshooting

### "Pool creation reverted"
- Run Script 1 to enable fee tiers first
- Check that factory owner is the broadcaster

### "Swap failed"
- Ensure pools have liquidity (Script 5)
- Check token approvals
- Verify pool addresses are correct

### "Price sanity check failed"
- Review sqrtPriceX96 calculation
- Check token ordering (token0 < token1)
- Verify decimal handling for USDC (6 vs 18)

### "Insufficient WTRUST balance"
- Ensure deployer has native TRUST
- Call `WTRUST.deposit{value: amount}()` to wrap

---

## Environment Variables Reference

| Variable | Description | Set By |
|----------|-------------|--------|
| `DEPLOYER_KEY` | Private key for transactions | User |
| `WTRUST_TOKEN` | Wrapped TRUST address | Script 2 |
| `USDC_TOKEN` | Mock USDC address | Script 2 |
| `WETH_TOKEN` | Mock WETH address | Script 2 |
| `WTRUST_USDC_SQRT_PRICE` | Init price for WTRUST/USDC | Script 3 |
| `WTRUST_WETH_SQRT_PRICE` | Init price for WTRUST/WETH | Script 3 |
| `WETH_USDC_SQRT_PRICE` | Init price for WETH/USDC | Script 3 |
| `WTRUST_USDC_POOL` | Pool address | Script 4 |
| `WTRUST_WETH_POOL` | Pool address | Script 4 |
| `WETH_USDC_POOL` | Pool address | Script 4 |
| `TRUST_PRICE_USD` | Reference price (optional) | User |
| `WETH_PRICE_USD` | Reference price (optional) | User |
| `PRICE_TOLERANCE_BPS` | Sanity check tolerance (optional) | User |
