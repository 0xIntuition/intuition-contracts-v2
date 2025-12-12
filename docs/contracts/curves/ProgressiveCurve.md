# ProgressiveCurve

## Overview

The **ProgressiveCurve** is a bonding curve implementation that uses a quadratic pricing model where each new share costs progressively more than the last. Unlike LinearCurve's constant pricing, ProgressiveCurve implements true price discovery through supply mechanics - as more shares are minted, the marginal price increases according to a configurable slope parameter. This creates economic incentives favoring early adopters and establishes natural scarcity.

### Purpose and Role in Protocol

- **Progressive Pricing**: Each share costs more than the previous one based on total supply
- **Price Discovery**: Market-driven valuation through supply-demand mechanics
- **Early Adopter Rewards**: Earlier depositors pay lower prices and benefit more from growth
- **Natural Scarcity**: Increasing prices create economic barriers to unlimited growth
- **Configurable Slope**: Adjustable price progression rate via initialization parameter
- **Mathematical Precision**: Uses PRB-Math for accurate fixed-point calculations

### Key Responsibilities

1. **Quadratic Pricing**: Calculate share prices using quadratic bonding curve formula
2. **Supply-Based Valuation**: Price increases proportionally to total shares squared
3. **Area Calculation**: Compute asset amounts as area under the curve
4. **Slope Management**: Apply configurable slope parameter to all calculations
5. **Overflow Prevention**: Enforce maximum shares/assets to prevent arithmetic overflow
6. **Precise Mathematics**: Use 60.18 fixed-point arithmetic for accuracy

## Contract Information

- **Location**: `src/protocol/curves/ProgressiveCurve.sol`
- **Inherits**:
  - `BaseCurve` (abstract bonding curve interface)
  - `Initializable` (OpenZeppelin upgradeable base)
- **Interface**: `IBaseCurve` (`src/interfaces/IBaseCurve.sol`)
- **Libraries**: `ProgressiveCurveMathLib`, `PRB-Math UD60x18`
- **Upgradeable**: Yes (UUPS proxy pattern)
- **Curve ID**: Not currently deployed (LinearCurve ID 1, OffsetProgressiveCurve ID 2)

### Network Deployments

The base ProgressiveCurve is not currently deployed to mainnet or testnet. The protocol uses **OffsetProgressiveCurve** (ID 2) instead, which adds an offset parameter to the progressive pricing model. See [OffsetProgressiveCurve](./OffsetProgressiveCurve.md) for deployment addresses.

**Note**: This contract serves as the foundation for OffsetProgressiveCurve and can be deployed with custom slope parameters for specialized use cases.

## Key Concepts

### Progressive Bonding Curve Model

The ProgressiveCurve implements a quadratic bonding curve where:

**Price(s) = slope × s**

Where:
- `s` = current total shares
- `slope` = configurable price progression rate (18 decimal fixed-point)

This means:
- Price is **linear** in total shares (not constant like LinearCurve)
- The first share costs `slope × 0 ≈ 0` (very low initial price)
- Each additional share costs `slope` more than the previous
- Price grows linearly, but total cost grows quadratically

### Mathematical Model

The curve calculates assets as the **area under the price curve**:

```
Assets = ∫[0 to s] price(x) dx
Assets = ∫[0 to s] (slope × x) dx
Assets = (slope / 2) × s²
Assets = HALF_SLOPE × s²
```

#### For Deposits (buying shares):
Given assets to deposit, find shares to mint:
```
assets = HALF_SLOPE × (s_new² - s_current²)
assets = HALF_SLOPE × (s_current + Δs)² - HALF_SLOPE × s_current²
```

Solving for Δs:
```
Δs = √(s_current² + assets/HALF_SLOPE) - s_current
```

#### For Redemptions (selling shares):
Given shares to redeem, find assets to return:
```
assets = HALF_SLOPE × (s_current² - s_new²)
assets = HALF_SLOPE × (s_current² - (s_current - Δs)²)
```

### Slope Parameter

The slope controls how aggressively price increases:

**High Slope** (e.g., 1e18):
- Steep price increases
- Stronger early adopter advantage
- Higher barrier to entry for late adopters
- Smaller maximum capacity

**Low Slope** (e.g., 1e14):
- Gentle price increases
- More accessible for late adopters
- Larger maximum capacity
- Less pronounced early advantage

**Constraint**: Slope must be even (divisible by 2) for mathematical precision.

### HALF_SLOPE Optimization

The contract stores `HALF_SLOPE = slope / 2` to optimize calculations:
- Area formula uses `HALF_SLOPE × s²`
- Avoids repeated division by 2
- Reduces gas costs
- Maintains precision

### Maximum Limits

Unlike LinearCurve's unlimited capacity, ProgressiveCurve has finite limits:

```solidity
MAX_SHARES = √(type(uint256).max / 1e18)
MAX_ASSETS = HALF_SLOPE × MAX_SHARES²
```

These limits prevent overflow in quadratic calculations:
- Squaring shares could overflow uint256
- MAX_SHARES is set to prevent s² overflow
- MAX_ASSETS derived from MAX_SHARES and slope

### Price Discovery Dynamics

**Early Stage** (low totalShares):
- Very low share prices
- High percentage returns for early depositors
- Rapid relative price growth

**Growth Stage** (medium totalShares):
- Moderate prices
- Steady price progression
- Balanced risk/reward

**Maturity Stage** (high totalShares):
- High share prices
- Slower relative growth
- Price may discourage new deposits

## State Variables

### Configuration

```solidity
/// @notice The slope of the curve (18 decimal fixed-point)
/// This is the rate at which the price of shares increases
UD60x18 public SLOPE;

/// @notice Half of the slope, used for calculations
UD60x18 public HALF_SLOPE;
```

**SLOPE**: Price progression rate (e.g., 1e18 means price increases by 1 TRUST per share)

**HALF_SLOPE**: `slope / 2`, used in area calculations for efficiency

### Limits

```solidity
/// @dev Maximum shares to prevent overflow
uint256 public MAX_SHARES;

/// @dev Maximum assets derived from MAX_SHARES
uint256 public MAX_ASSETS;
```

**MAX_SHARES**: Calculated as `√(type(uint256).max / 1e18)` during initialization

**MAX_ASSETS**: Calculated as `HALF_SLOPE × MAX_SHARES²` during initialization

### Inherited State

From BaseCurve:

```solidity
/// @notice The name of the curve
string public name;
```

**name**: Set during initialization (e.g., "ProgressiveCurve")

## Functions

### Initialization

#### `initialize`
```solidity
function initialize(string calldata _name, uint256 slope18) external initializer
```
Initializes the ProgressiveCurve contract with a name and slope.

**Parameters**:
- `_name`: Name of the curve (e.g., "ProgressiveCurve")
- `slope18`: The slope parameter in 18 decimal format

**Requirements**:
- `slope18 != 0`: Slope must be non-zero
- `slope18 % 2 == 0`: Slope must be even (divisible by 2)

**Emits**: `CurveNameSet` (from BaseCurve)

**Reverts**: `ProgressiveCurve_InvalidSlope` if slope is zero or odd

**Effect**:
- Sets `SLOPE = slope18`
- Sets `HALF_SLOPE = slope18 / 2`
- Calculates `MAX_SHARES = √(type(uint256).max / 1e18)`
- Calculates `MAX_ASSETS = HALF_SLOPE × MAX_SHARES²`

**Use Case**: Called once during proxy deployment to configure curve parameters

---

### Core Curve Functions

#### `previewDeposit`
```solidity
function previewDeposit(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view returns (uint256 shares)
```
Calculates shares to be minted for a deposit using the progressive formula.

**Parameters**:
- `assets`: Amount of assets to deposit
- `totalAssets`: Current total assets in vault (for validation)
- `totalShares`: Current total shares in vault

**Returns**: Number of shares that would be minted

**Formula**:
```solidity
shares = √(totalShares² + assets/HALF_SLOPE) - totalShares
```

**Validation**:
- Checks curve domain (totalAssets/totalShares within limits)
- Checks deposit bounds (assets won't exceed MAX_ASSETS)
- Checks output (shares won't exceed MAX_SHARES)

**Gas**: ~15,000 (includes sqrt operation)

**Example**:
```typescript
// With SLOPE = 1e18, HALF_SLOPE = 0.5e18
// totalShares = 100e18
// Depositing 5,250e18 TRUST

// Current price = 100e18 × 1e18 = 100e18 TRUST/share
// shares = √(100² + 5,250/0.5) - 100
// shares = √(10,000 + 10,500) - 100
// shares = √20,500 - 100
// shares ≈ 143.18 - 100 = 43.18 shares

// Average price = 5,250 / 43.18 ≈ 121.59 TRUST/share
```

---

#### `previewRedeem`
```solidity
function previewRedeem(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 assets)
```
Calculates assets to be returned for redeeming shares.

**Parameters**:
- `shares`: Number of shares to redeem
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault (for validation)

**Returns**: Amount of assets that would be returned

**Formula**:
```solidity
assets = HALF_SLOPE × (totalShares² - (totalShares - shares)²)
```

**Validation**:
- Checks curve domain
- Checks shares don't exceed totalShares

**Rounding**: Rounds DOWN (favors protocol)

**Gas**: ~8,000

**Example**:
```typescript
// With HALF_SLOPE = 0.5e18
// totalShares = 143.18
// Redeeming 43.18 shares

// assets = 0.5 × (143.18² - 100²)
// assets = 0.5 × (20,500 - 10,000)
// assets = 0.5 × 10,500 = 5,250 TRUST
```

---

#### `previewMint`
```solidity
function previewMint(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 assets)
```
Calculates assets required to mint specific number of shares.

**Parameters**:
- `shares`: Number of shares to mint
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault (for validation)

**Returns**: Amount of assets required

**Formula**:
```solidity
assets = HALF_SLOPE × ((totalShares + shares)² - totalShares²)
```

**Rounding**: Rounds UP (favors protocol) using `squareUp` and `mulUp`

**Validation**:
- Checks curve domain
- Checks mint bounds (shares won't overflow)
- Checks output (assets won't overflow)

**Gas**: ~10,000

---

#### `previewWithdraw`
```solidity
function previewWithdraw(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view returns (uint256 shares)
```
Calculates shares needed to withdraw specific amount of assets.

**Parameters**:
- `assets`: Amount of assets to withdraw
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Number of shares required

**Formula**:
```solidity
shares = totalShares - √(totalShares² - assets/HALF_SLOPE)
```

**Rounding**: Rounds UP (favors protocol) using `divUp`

**Validation**:
- Checks curve domain
- Checks assets don't exceed totalAssets

**Gas**: ~16,000 (includes sqrt operation)

---

#### `convertToShares`
```solidity
function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view returns (uint256 shares)
```
Converts assets to equivalent shares at current vault state.

**Parameters**:
- `assets`: Amount of assets to convert
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Equivalent number of shares

**Formula**: Same as `previewDeposit`

**Use Case**: Calculate share equivalents without executing deposit

---

#### `convertToAssets`
```solidity
function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 assets)
```
Converts shares to equivalent assets at current vault state.

**Parameters**:
- `shares`: Number of shares to convert
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Equivalent amount of assets

**Formula**: Same as `previewRedeem`

**Use Case**: Calculate asset equivalents without executing redemption

---

#### `currentPrice`
```solidity
function currentPrice(
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 sharePrice)
```
Returns the current marginal price of one share.

**Parameters**:
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault (for validation)

**Returns**: Current share price (scaled by 1e18)

**Formula**:
```solidity
sharePrice = totalShares × SLOPE
```

**Units**: TRUST per share (18 decimals)

**Example**:
```typescript
// With SLOPE = 1e18, totalShares = 100e18
price = 100e18 × 1e18 = 100e18 TRUST/share
```

**Note**: This is the **marginal price** - the cost of the next infinitesimal share, not the average price paid for a bulk deposit.

---

### Maximum Limit Functions

#### `maxShares`
```solidity
function maxShares() external view returns (uint256)
```
Returns maximum shares the curve can handle.

**Returns**: `MAX_SHARES` calculated during initialization

**Typical Value**: ~340,282,366,920,938,463,463 (≈3.4e29) for most slopes

---

#### `maxAssets`
```solidity
function maxAssets() external view returns (uint256)
```
Returns maximum assets the curve can handle.

**Returns**: `MAX_ASSETS = HALF_SLOPE × MAX_SHARES²`

**Note**: Varies based on slope parameter

---

## Internal Functions

### `_convertToShares`
```solidity
function _convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) internal view returns (uint256 shares)
```
Internal helper for asset-to-share conversion.

**Formula**:
```solidity
inner = totalShares² + assets/HALF_SLOPE
shares = √inner - totalShares
```

**Validation**: Includes all domain and bounds checks

**Used By**: `previewDeposit`, `convertToShares`

---

### `_convertToAssets`
```solidity
function _convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) internal view returns (uint256 assets)
```
Internal helper for share-to-asset conversion.

**Formula**:
```solidity
area = totalShares² - (totalShares - shares)²
assets = HALF_SLOPE × area
```

**Validation**: Includes domain and redemption checks

**Rounding**: Uses `square` (rounds down) and `squareUp` (rounds up) strategically

**Used By**: `previewRedeem`, `convertToAssets`

---

## Events

### `CurveNameSet`
```solidity
event CurveNameSet(string name)
```
Emitted when the curve name is set during initialization.

**Parameters**:
- `name`: The curve name

**Use Cases**:
- Verify correct initialization
- Audit curve deployment

---

## Errors

### `ProgressiveCurve_InvalidSlope`
```solidity
error ProgressiveCurve_InvalidSlope()
```
Thrown when slope is zero or not divisible by 2.

**Triggers**:
- `slope18 == 0`
- `slope18 % 2 != 0`

**Recovery**: Provide valid even slope value (e.g., 1e18, 2e18, 1e14)

**Reason**: Slope must be even to ensure `HALF_SLOPE = slope / 2` is precise

---

### Inherited Errors

#### `BaseCurve_AssetsExceedTotalAssets`
Thrown when withdrawal exceeds vault's total assets.

---

#### `BaseCurve_SharesExceedTotalShares`
Thrown when redemption exceeds total shares.

---

#### `BaseCurve_AssetsOverflowMax`
Thrown when operation would exceed MAX_ASSETS.

**Note**: Can occur with large deposits on high-slope curves

---

#### `BaseCurve_SharesOverflowMax`
Thrown when operation would exceed MAX_SHARES.

**Note**: Rare but possible with many small deposits

---

#### `BaseCurve_DomainExceeded`
Thrown when current vault state exceeds curve limits.

---

## Usage Examples

### TypeScript (VIEM)

#### Analyzing Progressive Pricing

```typescript
import { createPublicClient, http, parseEther, formatEther } from 'viem';
import { intuitionMainnet } from './chains';

const client = createPublicClient({
  chain: intuitionMainnet,
  transport: http()
});

// For this example, assume a ProgressiveCurve deployed with slope = 1e18
const PROGRESSIVE_CURVE_ADDRESS = '0x...'; // Example address
const CURVE_ID = 3n; // Example ID

const curveABI = [
  {
    name: 'SLOPE',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'currentPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'totalShares', type: 'uint256' },
      { name: 'totalAssets', type: 'uint256' }
    ],
    outputs: [{ name: 'sharePrice', type: 'uint256' }]
  },
  {
    name: 'previewDeposit',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'totalAssets', type: 'uint256' },
      { name: 'totalShares', type: 'uint256' }
    ],
    outputs: [{ name: 'shares', type: 'uint256' }]
  }
] as const;

/**
 * Demonstrate progressive price increases
 */
async function demonstrateProgressivePricing() {
  const curve = {
    address: PROGRESSIVE_CURVE_ADDRESS,
    abi: curveABI
  } as const;

  // Get slope parameter
  const slope = await client.readContract({
    ...curve,
    functionName: 'SLOPE'
  });

  console.log(`Progressive Curve Analysis`);
  console.log(`Slope: ${formatEther(slope)}\n`);

  // Simulate progressive deposits
  let totalShares = 0n;
  let totalAssets = 0n;

  const deposits = [
    parseEther('10'),
    parseEther('10'),
    parseEther('10'),
    parseEther('10'),
    parseEther('10')
  ];

  for (let i = 0; i < deposits.length; i++) {
    const depositAmount = deposits[i];

    // Get current price
    const priceBefore = totalShares > 0n
      ? await client.readContract({
          ...curve,
          functionName: 'currentPrice',
          args: [totalShares, totalAssets]
        })
      : 0n;

    // Calculate shares
    const shares = await client.readContract({
      ...curve,
      functionName: 'previewDeposit',
      args: [depositAmount, totalAssets, totalShares]
    });

    // Update state
    totalShares += shares;
    totalAssets += depositAmount;

    // Get new price
    const priceAfter = await client.readContract({
      ...curve,
      functionName: 'currentPrice',
      args: [totalShares, totalAssets]
    });

    // Calculate average price paid
    const avgPrice = (depositAmount * parseEther('1')) / shares;

    console.log(`Deposit ${i + 1}: ${formatEther(depositAmount)} TRUST`);
    console.log(`  Shares: ${formatEther(shares)}`);
    console.log(`  Price Before: ${formatEther(priceBefore)} TRUST/share`);
    console.log(`  Price After: ${formatEther(priceAfter)} TRUST/share`);
    console.log(`  Avg Price Paid: ${formatEther(avgPrice)} TRUST/share`);
    console.log(`  Total Shares: ${formatEther(totalShares)}`);
    console.log();
  }

  console.log('Note: Each deposit of equal size yields fewer shares');
  console.log('This demonstrates the progressive pricing mechanism');
}

demonstrateProgressivePricing();
```

#### Calculating Early Adopter Advantage

```typescript
/**
 * Calculate ROI advantage for early vs late depositors
 */
async function calculateEarlyAdopterAdvantage(
  slope: bigint,
  totalDeposits: number
) {
  console.log('Early Adopter Advantage Analysis\n');

  const depositAmount = parseEther('100');
  let totalShares = 0n;
  let totalAssets = 0n;

  const depositors: Array<{
    position: number;
    shares: bigint;
    paid: bigint;
    avgPrice: bigint;
  }> = [];

  // Simulate multiple depositors
  for (let i = 0; i < totalDeposits; i++) {
    // Calculate shares for this deposit (simulated)
    const inner = totalShares * totalShares +
                  (depositAmount * parseEther('2')) / slope;
    const sqrtInner = sqrt(inner); // Simplified sqrt
    const shares = sqrtInner - totalShares;

    depositors.push({
      position: i + 1,
      shares,
      paid: depositAmount,
      avgPrice: (depositAmount * parseEther('1')) / shares
    });

    totalShares += shares;
    totalAssets += depositAmount;
  }

  // Calculate final price
  const finalPrice = totalShares * slope / parseEther('1');

  console.log('Depositor Analysis (each deposited 100 TRUST):\n');

  depositors.forEach((dep, idx) => {
    const currentValue = (dep.shares * finalPrice) / parseEther('1');
    const profit = currentValue - dep.paid;
    const roi = ((profit * 100n) / dep.paid);

    console.log(`Depositor ${dep.position}:`);
    console.log(`  Shares: ${formatEther(dep.shares)}`);
    console.log(`  Avg Price: ${formatEther(dep.avgPrice)} TRUST/share`);
    console.log(`  Current Value: ${formatEther(currentValue)} TRUST`);
    console.log(`  ROI: ${roi}%`);
    console.log();
  });

  console.log(`Final Share Price: ${formatEther(finalPrice)} TRUST/share`);
}

// Simplified sqrt helper (use proper library in production)
function sqrt(value: bigint): bigint {
  if (value < 0n) throw new Error('Cannot sqrt negative');
  if (value < 2n) return value;
  let x = value;
  let y = (x + 1n) / 2n;
  while (y < x) {
    x = y;
    y = (x + value / x) / 2n;
  }
  return x;
}

calculateEarlyAdopterAdvantage(parseEther('1'), 10);
```

### Python (web3.py)

```python
from web3 import Web3
import json
import math

w3 = Web3(Web3.HTTPProvider('YOUR_RPC_URL'))

# Example ProgressiveCurve deployment
CURVE_ADDRESS = '0x...'  # Example address

with open('ProgressiveCurve.json') as f:
    curve_abi = json.load(f)['abi']

curve = w3.eth.contract(address=CURVE_ADDRESS, abi=curve_abi)

def analyze_price_progression(
    initial_shares: int,
    deposit_range: list[int],
    slope: int
) -> None:
    """
    Analyze how price increases with deposits on ProgressiveCurve

    Args:
        initial_shares: Starting share count
        deposit_range: List of deposit amounts to simulate
        slope: The curve's slope parameter
    """
    print('Progressive Curve Price Analysis\n')
    print(f'Slope: {w3.from_wei(slope, "ether")}\n')

    total_shares = initial_shares
    total_assets = (slope // 2) * (total_shares ** 2) // 10**18

    for deposit in deposit_range:
        # Calculate current price
        price_before = (total_shares * slope) // 10**18

        # Calculate shares (simplified formula)
        half_slope = slope // 2
        inner = (total_shares ** 2) + ((deposit * 10**18) // half_slope)
        shares = int(math.sqrt(inner)) - total_shares

        # Update state
        total_shares += shares
        total_assets += deposit

        # New price
        price_after = (total_shares * slope) // 10**18

        # Average price paid
        avg_price = (deposit * 10**18) // shares if shares > 0 else 0

        print(f'Deposit: {w3.from_wei(deposit, "ether")} TRUST')
        print(f'  Shares: {w3.from_wei(shares, "ether")}')
        print(f'  Price: {w3.from_wei(price_before, "ether")} -> {w3.from_wei(price_after, "ether")}')
        print(f'  Avg Price: {w3.from_wei(avg_price, "ether")} TRUST/share')
        print(f'  Total Shares: {w3.from_wei(total_shares, "ether")}')
        print()

# Example usage
analyze_price_progression(
    initial_shares=w3.to_wei(100, 'ether'),
    deposit_range=[
        w3.to_wei(50, 'ether'),
        w3.to_wei(100, 'ether'),
        w3.to_wei(500, 'ether')
    ],
    slope=w3.to_wei(1, 'ether')
)

def compare_slopes(
    deposit_amount: int,
    slopes: list[int]
) -> None:
    """
    Compare how different slopes affect pricing

    Args:
        deposit_amount: Amount to deposit
        slopes: List of slope values to compare
    """
    print(f'\nSlope Comparison for {w3.from_wei(deposit_amount, "ether")} TRUST deposit\n')

    # Start from same state
    total_shares = w3.to_wei(100, 'ether')

    for slope in slopes:
        half_slope = slope // 2
        total_assets = (half_slope * (total_shares ** 2)) // 10**18

        # Current price
        price = (total_shares * slope) // 10**18

        # Calculate shares
        inner = (total_shares ** 2) + ((deposit_amount * 10**18) // half_slope)
        shares = int(math.sqrt(inner)) - total_shares

        print(f'Slope {w3.from_wei(slope, "ether")}:')
        print(f'  Current Price: {w3.from_wei(price, "ether")} TRUST/share')
        print(f'  Shares Received: {w3.from_wei(shares, "ether")}')
        print()

compare_slopes(
    w3.to_wei(100, 'ether'),
    [w3.to_wei(0.1, 'ether'), w3.to_wei(1, 'ether'), w3.to_wei(10, 'ether')]
)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/curves/IBaseCurve.sol";

/**
 * @title ProgressiveCurveAnalyzer
 * @notice Utilities for analyzing ProgressiveCurve behavior
 */
contract ProgressiveCurveAnalyzer {
    IBaseCurve public immutable progressiveCurve;

    constructor(address _curve) {
        progressiveCurve = IBaseCurve(_curve);
    }

    /**
     * @notice Calculate early adopter advantage
     * @param totalShares Current total shares
     * @param totalAssets Current total assets
     * @param depositAmount Amount to deposit
     * @return advantageBasisPoints Advantage in basis points (10000 = 100%)
     */
    function calculateEarlyAdopterAdvantage(
        uint256 totalShares,
        uint256 totalAssets,
        uint256 depositAmount
    ) external view returns (uint256 advantageBasisPoints) {
        // Get shares for deposit at current state
        uint256 sharesNow = progressiveCurve.previewDeposit(
            depositAmount,
            totalAssets,
            totalShares
        );

        // Simulate vault at 2x current size
        uint256 futureShares = totalShares * 2;
        uint256 futureAssets = totalAssets * 2;

        // Get shares for same deposit in future
        uint256 sharesFuture = progressiveCurve.previewDeposit(
            depositAmount,
            futureAssets,
            futureShares
        );

        // Calculate advantage
        if (sharesFuture > 0) {
            advantageBasisPoints = ((sharesNow - sharesFuture) * 10000) / sharesFuture;
        }
    }

    /**
     * @notice Find deposit size that doubles share price
     * @param totalShares Current total shares
     * @param totalAssets Current total assets
     * @return depositAmount Approximate deposit needed
     */
    function findPriceDoublingDeposit(
        uint256 totalShares,
        uint256 totalAssets
    ) external view returns (uint256 depositAmount) {
        uint256 currentPrice = progressiveCurve.currentPrice(
            totalShares,
            totalAssets
        );

        uint256 targetPrice = currentPrice * 2;

        // For ProgressiveCurve: price = slope × shares
        // To double price, need to double shares
        uint256 targetShares = totalShares * 2;
        uint256 additionalShares = targetShares - totalShares;

        // Calculate deposit needed for additional shares
        depositAmount = progressiveCurve.previewMint(
            additionalShares,
            totalShares,
            totalAssets
        );
    }

    /**
     * @notice Calculate total value if all shares are redeemed
     * @param totalShares Current total shares
     * @param totalAssets Current total assets
     * @return totalValue Total value of all shares
     */
    function calculateTotalValue(
        uint256 totalShares,
        uint256 totalAssets
    ) external view returns (uint256 totalValue) {
        // For ProgressiveCurve, total value equals total assets
        // (area under curve from 0 to totalShares)
        totalValue = progressiveCurve.convertToAssets(
            totalShares,
            totalShares,
            totalAssets
        );
    }
}

/**
 * @title CustomProgressiveCurveDeployer
 * @notice Example of deploying ProgressiveCurve with custom slope
 */
contract CustomProgressiveCurveDeployer {
    event CurveDeployed(address indexed curve, uint256 slope);

    /**
     * @notice Deploy a ProgressiveCurve with custom parameters
     * @param implementation The ProgressiveCurve implementation address
     * @param name Curve name
     * @param slope Slope parameter (must be even, 18 decimals)
     * @return proxy The deployed proxy address
     */
    function deployCustomCurve(
        address implementation,
        string memory name,
        uint256 slope
    ) external returns (address proxy) {
        // Validate slope
        require(slope > 0 && slope % 2 == 0, "Invalid slope");

        // Deploy proxy and initialize
        // (Simplified - use proper proxy deployment in production)
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,uint256)",
            name,
            slope
        );

        // Deploy logic (pseudo-code)
        // proxy = deployProxy(implementation, initData);

        emit CurveDeployed(proxy, slope);
    }
}
```

## Integration Notes

### Choosing Slope Parameter

When deploying ProgressiveCurve, slope selection is critical:

**For High Volatility / Speculation**:
- High slope (e.g., 1e18 - 10e18)
- Steep price increases
- Strong early adopter rewards

**For Moderate Growth**:
- Medium slope (e.g., 1e14 - 1e17)
- Balanced price progression
- Reasonable capacity

**For Large Capacity**:
- Low slope (e.g., 1e10 - 1e13)
- Gentle price increases
- Higher maximum shares/assets

**Remember**: Slope must be even (divisible by 2)

### Gas Considerations

ProgressiveCurve is more expensive than LinearCurve:

**Why**:
- Square root calculations
- PRB-Math fixed-point operations
- Multiple multiplication/division steps

**Optimization**:
- Cache results when possible
- Batch calculations off-chain
- Consider LinearCurve for gas-sensitive applications

### Price Impact

Large deposits have significant price impact:

```typescript
// Example: 1000 TRUST deposit
// Current price: 100 TRUST/share
// Shares received: ~40 (not 10 as in LinearCurve)
// Average price paid: 25 TRUST/share (not 100)
// New price: ~140 TRUST/share
```

Early depositors pay much less than late depositors.

### Maximum Capacity

Monitor vault size relative to MAX_SHARES/MAX_ASSETS:

```typescript
const maxShares = await curve.maxShares();
const utilizationPercent = (totalShares * 100n) / maxShares;

if (utilizationPercent > 80n) {
  console.warn('Vault approaching maximum capacity');
}
```

## Mathematical Formulas

### Core Formulas

#### Price Function
```
P(s) = slope × s
```
Where `s` = total shares

#### Asset Calculation (Area Under Curve)
```
A(s) = ∫[0 to s] P(x) dx
A(s) = ∫[0 to s] (slope × x) dx
A(s) = (slope/2) × s²
A(s) = HALF_SLOPE × s²
```

#### Shares from Assets (Deposit)
```
Given: assets, totalShares
Find: additional shares (Δs)

assets = HALF_SLOPE × ((totalShares + Δs)² - totalShares²)
assets = HALF_SLOPE × (2 × totalShares × Δs + Δs²)

Solving quadratic:
Δs = √(totalShares² + assets/HALF_SLOPE) - totalShares
```

#### Assets from Shares (Redemption)
```
Given: shares, totalShares
Find: assets returned

assets = HALF_SLOPE × (totalShares² - (totalShares - shares)²)
```

### Example Walkthrough

**Setup**:
- SLOPE = 1e18 (1 TRUST per share increase)
- HALF_SLOPE = 0.5e18
- totalShares = 100e18
- totalAssets = 5,000e18

**Step 1**: Calculate current price
```
price = totalShares × SLOPE
price = 100e18 × 1e18 / 1e18
price = 100e18 TRUST/share
```

**Step 2**: Deposit 5,250e18 TRUST
```
Δs = √(100² + 5,250/0.5) - 100
Δs = √(10,000 + 10,500) - 100
Δs = √20,500 - 100
Δs ≈ 143.178 - 100
Δs ≈ 43.178 shares
```

**Step 3**: Verify assets calculation
```
assets = 0.5 × ((100 + 43.178)² - 100²)
assets = 0.5 × (143.178² - 100²)
assets = 0.5 × (20,499.9 - 10,000)
assets = 0.5 × 10,499.9
assets ≈ 5,250 ✓
```

**Step 4**: New price
```
newPrice = 143.178 × 1
newPrice ≈ 143.178 TRUST/share
```

**Step 5**: Average price paid
```
avgPrice = 5,250 / 43.178
avgPrice ≈ 121.59 TRUST/share
```

## Comparison to Other Curve Types

### ProgressiveCurve vs LinearCurve

| Feature | ProgressiveCurve | LinearCurve |
|---------|------------------|-------------|
| **Pricing** | s × slope | assets / shares |
| **Price Growth** | Linear with supply | Constant ratio |
| **Early Advantage** | High | None |
| **Price Impact** | Significant | Minimal |
| **Gas Cost** | ~15,000 | ~3,000 |
| **Complexity** | High (sqrt, square) | Low (division) |
| **Max Capacity** | Limited | Unlimited |
| **Use Case** | Price discovery | Stable pricing |

### ProgressiveCurve vs OffsetProgressiveCurve

| Feature | ProgressiveCurve | OffsetProgressiveCurve |
|---------|------------------|------------------------|
| **Initial Price** | ~0 (very low) | offset × slope |
| **Formula** | slope × s | slope × (s + offset) |
| **Min Price** | Near zero | offset × slope |
| **Gas Cost** | ~15,000 | ~20,000 |
| **Flexibility** | Lower | Higher |
| **Use Case** | Base progressive | Controlled initial price |

### When to Use ProgressiveCurve

**Use ProgressiveCurve When**:
- Early adopter rewards are desired
- Price discovery is important
- Natural scarcity is beneficial
- Speculation is acceptable
- You want simple progressive pricing

**Use OffsetProgressiveCurve When**:
- You need higher minimum price
- Initial price should not be near zero
- More controlled price progression desired

**Use LinearCurve When**:
- Equal treatment of all depositors
- Predictable, stable pricing
- Minimal gas costs
- Large capacity needed

## Related Contracts

### Curve System
- **[BaseCurve](./BaseCurve.md)**: Abstract interface implemented by ProgressiveCurve
- **[BondingCurveRegistry](./BondingCurveRegistry.md)**: Manages curve registration
- **[LinearCurve](./LinearCurve.md)**: Constant pricing alternative
- **[OffsetProgressiveCurve](./OffsetProgressiveCurve.md)**: Enhanced version with offset parameter

### Libraries
- **[ProgressiveCurveMathLib](../../reference/mathematical-formulas.md#progressive-curve-math-library)**: Math helpers for progressive calculations
- **PRB-Math UD60x18**: Fixed-point arithmetic library

### Core Integration
- **[MultiVault](../core/MultiVault.md)**: Uses curves for vault pricing
- **[MultiVaultCore](../core/MultiVaultCore.md)**: Stores curve configuration

## See Also

### Concept Documentation
- [Bonding Curves](../../concepts/bonding-curves.md) - Complete explanation of bonding curve mechanics
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - How curves enable economic diversity

### Reference
- [Mathematical Formulas](../../reference/mathematical-formulas.md) - Detailed curve mathematics
- [Gas Benchmarks](../../reference/gas-benchmarks.md) - Performance comparisons

---

**Last Updated**: December 2025
**Version**: V2.0
**Status**: Base Implementation (see OffsetProgressiveCurve for deployed version)
