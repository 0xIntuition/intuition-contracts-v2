# OffsetProgressiveCurve

## Overview

The **OffsetProgressiveCurve** is an enhanced bonding curve implementation that extends the ProgressiveCurve model with an offset parameter. This offset shifts the price curve along the share axis, establishing a higher minimum price floor and creating smoother, more controlled price progression. By adding a fixed offset to the share count in price calculations, this curve enables price discovery benefits of progressive pricing while preventing the near-zero initial prices of standard progressive curves.

### Purpose and Role in Protocol

- **Offset-Adjusted Pricing**: Price calculated as `slope × (shares + offset)` instead of `slope × shares`
- **Higher Price Floor**: Establishes minimum price of `slope × offset` even at zero shares
- **Smoother Progression**: More gradual price increases compared to standard progressive curves
- **Controlled Initial Pricing**: Prevents exploitation of near-zero early prices
- **Configurable Parameters**: Both slope and offset adjustable at deployment
- **Production Deployment**: Currently deployed as Curve ID 2 on mainnet and testnet

### Key Responsibilities

1. **Offset-Based Calculation**: Apply offset parameter to all share-based price calculations
2. **Price Floor Enforcement**: Maintain minimum price through offset mechanism
3. **Progressive Scaling**: Combine offset with slope for controlled price growth
4. **Overflow Prevention**: Calculate maximum limits accounting for offset
5. **Precise Mathematics**: Use PRB-Math for accurate fixed-point calculations
6. **Backwards Compatibility**: Maintain BaseCurve interface compatibility

## Contract Information

- **Location**: `src/protocol/curves/OffsetProgressiveCurve.sol`
- **Inherits**:
  - `BaseCurve` (abstract bonding curve interface)
  - `Initializable` (OpenZeppelin upgradeable base)
- **Interface**: `IBaseCurve` (`src/interfaces/IBaseCurve.sol`)
- **Libraries**: `ProgressiveCurveMathLib`, `PRB-Math UD60x18`
- **Upgradeable**: Yes (UUPS proxy pattern)
- **Curve ID**: 2 (in BondingCurveRegistry)

### Network Deployments

#### Intuition Mainnet
- **Proxy Address**: [`0x23afF95153aa88D28B9B97Ba97629E05D5fD335d`](https://explorer.intuit.network/address/0x23afF95153aa88D28B9B97Ba97629E05D5fD335d)
- **Implementation**: `0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7`
- **Curve ID**: 2
- **Name**: "OffsetProgressiveCurve"
- **Slope**: 2e18 (2.0)
- **Offset**: 1e18 (1.0)

#### Intuition Testnet
- **Proxy Address**: [`0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB`](https://explorer.testnet.intuit.network/address/0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB)
- **Implementation**: `0x6A65336598d4783d0673DD238418248909C71F26`
- **Curve ID**: 2
- **Name**: "OffsetProgressiveCurve"
- **Slope**: 2e18 (2.0)
- **Offset**: 1e18 (1.0)

## Key Concepts

### Offset Progressive Pricing Model

The OffsetProgressiveCurve modifies the standard progressive formula:

**Standard ProgressiveCurve**:
```
Price(s) = slope × s
```

**OffsetProgressiveCurve**:
```
Price(s) = slope × (s + offset)
```

Where:
- `s` = actual total shares in vault
- `offset` = fixed offset parameter (shifts curve right)
- `slope` = price progression rate

This means:
- At s = 0 (empty vault), price = `slope × offset` (not zero!)
- Price increases linearly with shares, starting from the offset-adjusted baseline
- The offset creates a "virtual" share count that establishes price floor

### Mathematical Model

The curve calculates assets as the **area under the offset-adjusted price curve**:

```
Assets = ∫[offset to s+offset] price(x) dx
Assets = ∫[offset to s+offset] (slope × x) dx
Assets = (slope/2) × [(s+offset)² - offset²]
Assets = HALF_SLOPE × [(s+offset)² - offset²]
```

#### Simplified Area Calculation:
```
Assets = HALF_SLOPE × [(s+offset)² - offset²]
Assets = HALF_SLOPE × [s² + 2×s×offset + offset² - offset²]
Assets = HALF_SLOPE × [s² + 2×s×offset]
Assets = HALF_SLOPE × s × (s + 2×offset)
```

#### For Deposits (buying shares):
Given assets to deposit, find shares to mint:
```
assets = HALF_SLOPE × [(s+Δs+offset)² - (s+offset)²]
```

Solving for Δs:
```
Δs = √[(s+offset)² + assets/HALF_SLOPE] - (s+offset)
```

#### For Redemptions (selling shares):
Given shares to redeem, find assets to return:
```
assets = HALF_SLOPE × [(s+offset)² - (s-Δs+offset)²]
```

### The Offset Parameter

The offset shifts the entire price curve, creating important effects:

**With offset = 0** (Standard ProgressiveCurve):
- s = 0: price = 0 (free shares!)
- s = 100: price = 100 × slope
- Early shares nearly free

**With offset = 100**:
- s = 0: price = 100 × slope (expensive even when empty)
- s = 100: price = 200 × slope
- Early shares expensive, but less early advantage

**Effects of Higher Offset**:
- Higher minimum price floor
- Reduced early adopter advantage
- Smoother price progression
- Lower maximum capacity
- More balanced distribution

### Slope Parameter

Combined with offset, slope controls overall price scale:

**Current Deployment** (slope = 2e18, offset = 1e18):
- Minimum price: 2 TRUST/share
- At 100 shares: ~202 TRUST/share
- Balanced growth rate

**High Slope** (e.g., 10e18):
- Steeper price increases
- Lower maximum capacity
- Stronger scarcity

**Low Slope** (e.g., 0.1e18):
- Gentler price increases
- Higher maximum capacity
- More accessible

**Constraint**: Like ProgressiveCurve, slope must be even (divisible by 2).

### Maximum Limits

The offset reduces maximum capacity compared to standard ProgressiveCurve:

```solidity
MAX_SHARES = √(type(uint256).max / 1e18) - OFFSET
MAX_ASSETS = HALF_SLOPE × [(MAX_SHARES + OFFSET)² - OFFSET²]
```

The offset is subtracted from the theoretical maximum to ensure:
- Adding offset to MAX_SHARES won't overflow
- Squaring (MAX_SHARES + OFFSET) won't overflow
- All calculations remain within uint256 bounds

### Comparison to Standard ProgressiveCurve

| Aspect | ProgressiveCurve | OffsetProgressiveCurve |
|--------|------------------|------------------------|
| **Price at s=0** | ~0 | offset × slope |
| **Price Formula** | slope × s | slope × (s + offset) |
| **Min Price** | Near zero | offset × slope |
| **Early Advantage** | Extreme | Moderate |
| **Capacity** | Higher | Lower (due to offset) |
| **Deployment** | Not deployed | Curve ID 2 |

## State Variables

### Configuration

```solidity
/// @notice The slope of the curve (18 decimal fixed-point)
/// Rate at which price increases
UD60x18 public SLOPE;

/// @notice Half of the slope, used for area calculations
UD60x18 public HALF_SLOPE;

/// @notice The offset of the curve
/// Shifts curve along shares axis
UD60x18 public OFFSET;
```

**SLOPE**: Price progression rate (mainnet: 2e18)

**HALF_SLOPE**: `slope / 2`, optimization for area calculations (mainnet: 1e18)

**OFFSET**: Share count offset for price floor (mainnet: 1e18)

### Limits

```solidity
/// @dev Maximum shares accounting for offset
uint256 public MAX_SHARES;

/// @dev Maximum assets derived from MAX_SHARES and OFFSET
uint256 public MAX_ASSETS;
```

**MAX_SHARES**: `√(type(uint256).max / 1e18) - OFFSET`

**MAX_ASSETS**: `HALF_SLOPE × [(MAX_SHARES + OFFSET)² - OFFSET²]`

### Inherited State

From BaseCurve:

```solidity
/// @notice The name of the curve
string public name;
```

**name**: Set to "OffsetProgressiveCurve" during initialization

## Functions

### Initialization

#### `initialize`
```solidity
function initialize(
    string calldata _name,
    uint256 slope18,
    uint256 offset18
) external initializer
```
Initializes the OffsetProgressiveCurve with name, slope, and offset.

**Parameters**:
- `_name`: Name of the curve (e.g., "OffsetProgressiveCurve")
- `slope18`: Slope parameter in 18 decimal format (e.g., 2e18)
- `offset18`: Offset parameter in 18 decimal format (e.g., 1e18)

**Requirements**:
- `slope18 != 0`: Slope must be non-zero
- `slope18 % 2 == 0`: Slope must be even

**Emits**: `CurveNameSet` (from BaseCurve)

**Reverts**: `OffsetProgressiveCurve_InvalidSlope` if slope is zero or odd

**Effect**:
- Sets `SLOPE = slope18`
- Sets `HALF_SLOPE = slope18 / 2`
- Sets `OFFSET = offset18`
- Calculates `MAX_SHARES = √(type(uint256).max / 1e18) - OFFSET`
- Calculates `MAX_ASSETS = HALF_SLOPE × [(MAX_SHARES + OFFSET)² - OFFSET²]`

**Example**:
```solidity
// Mainnet deployment parameters
initialize("OffsetProgressiveCurve", 2e18, 1e18);
// SLOPE = 2e18 (2.0)
// HALF_SLOPE = 1e18 (1.0)
// OFFSET = 1e18 (1.0)
// Minimum price = 2e18 TRUST/share
```

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
Calculates shares to be minted for a deposit using offset-progressive formula.

**Parameters**:
- `assets`: Amount of assets to deposit
- `totalAssets`: Current total assets in vault (for validation)
- `totalShares`: Current total shares in vault

**Returns**: Number of shares that would be minted

**Formula**:
```solidity
s_offset = totalShares + OFFSET
shares = √(s_offset² + assets/HALF_SLOPE) - s_offset
```

**Validation**:
- Checks curve domain
- Checks deposit bounds
- Checks output doesn't exceed MAX_SHARES

**Gas**: ~20,000 (includes sqrt and offset operations)

**Example**:
```typescript
// Mainnet: SLOPE = 2, HALF_SLOPE = 1, OFFSET = 1
// totalShares = 100
// Deposit 402 TRUST

// s_offset = 100 + 1 = 101
// shares = √(101² + 402/1) - 101
// shares = √(10,201 + 402) - 101
// shares = √10,603 - 101
// shares ≈ 103 - 101 = 2 shares

// Current price = 2 × (100 + 1) = 202 TRUST/share
// New price = 2 × (102 + 1) = 206 TRUST/share
// Average paid ≈ 201 TRUST/share
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
s_offset = totalShares + OFFSET
s_new_offset = s_offset - shares
assets = HALF_SLOPE × (s_offset² - s_new_offset²)
```

**Validation**:
- Checks curve domain
- Checks shares don't exceed totalShares

**Rounding**: Rounds DOWN (favors protocol)

**Gas**: ~12,000

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
s_offset = totalShares + OFFSET
s_new_offset = s_offset + shares
assets = HALF_SLOPE × (s_new_offset² - s_offset²)
```

**Rounding**: Rounds UP (favors protocol) using `squareUp` and `mulUp`

**Validation**:
- Checks curve domain
- Checks mint bounds
- Checks output doesn't exceed MAX_ASSETS

**Gas**: ~13,000

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
s_offset = totalShares + OFFSET
shares = s_offset - √(s_offset² - assets/HALF_SLOPE)
```

**Rounding**: Rounds UP (favors protocol) using `divUp`

**Validation**:
- Checks curve domain
- Checks assets don't exceed totalAssets

**Gas**: ~21,000

---

#### `convertToShares`
```solidity
function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view returns (uint256 shares)
```
Converts assets to equivalent shares at current rate.

**Formula**: Same as `previewDeposit`

**Use Case**: Calculate share equivalents without executing

---

#### `convertToAssets`
```solidity
function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 assets)
```
Converts shares to equivalent assets at current rate.

**Formula**: Same as `previewRedeem`

**Use Case**: Calculate asset equivalents without executing

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
sharePrice = (totalShares + OFFSET) × SLOPE
```

**Units**: TRUST per share (18 decimals)

**Example**:
```typescript
// Mainnet: SLOPE = 2e18, OFFSET = 1e18
// totalShares = 0 (empty vault)
price = (0 + 1) × 2 = 2e18 TRUST/share

// totalShares = 100
price = (100 + 1) × 2 = 202e18 TRUST/share
```

**Note**: This is the **marginal price** - the cost of the next infinitesimal share.

---

### Maximum Limit Functions

#### `maxShares`
```solidity
function maxShares() external view returns (uint256)
```
Returns maximum shares the curve can handle.

**Returns**: `MAX_SHARES` (calculated during initialization)

---

#### `maxAssets`
```solidity
function maxAssets() external view returns (uint256)
```
Returns maximum assets the curve can handle.

**Returns**: `MAX_ASSETS` (calculated during initialization)

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
Internal helper for asset-to-share conversion with offset.

**Formula**:
```solidity
s_offset = totalShares + OFFSET
inner = s_offset² + assets/HALF_SLOPE
shares = √inner - s_offset
```

**Validation**: Full domain and bounds checks

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
Internal helper for share-to-asset conversion with offset.

**Formula**:
```solidity
s_offset = totalShares + OFFSET
s_new_offset = s_offset - shares
area = s_offset² - s_new_offset²
assets = HALF_SLOPE × area
```

**Rounding**: Strategic use of `square` and `squareUp`

**Used By**: `previewRedeem`, `convertToAssets`

---

## Events

### `CurveNameSet`
```solidity
event CurveNameSet(string name)
```
Emitted when the curve name is set during initialization.

**Parameters**:
- `name`: The curve name ("OffsetProgressiveCurve")

---

## Errors

### `OffsetProgressiveCurve_InvalidSlope`
```solidity
error OffsetProgressiveCurve_InvalidSlope()
```
Thrown when slope is zero or not divisible by 2.

**Triggers**:
- `slope18 == 0`
- `slope18 % 2 != 0`

**Recovery**: Provide valid even slope (e.g., 2e18, 4e18, 1e17)

**Reason**: Slope must be even to ensure precise HALF_SLOPE calculation

---

### Inherited Errors

All BaseCurve errors apply (see [BaseCurve Documentation](./BaseCurve.md#errors)).

---

## Usage Examples

### TypeScript (VIEM)

#### Querying OffsetProgressiveCurve Pricing

```typescript
import { createPublicClient, http, parseEther, formatEther } from 'viem';
import { intuitionMainnet } from './chains';

const client = createPublicClient({
  chain: intuitionMainnet,
  transport: http()
});

const OFFSET_CURVE_ID = 2n;
const REGISTRY_ADDRESS = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930';
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const OFFSET_CURVE_ADDRESS = '0x23afF95153aa88D28B9B97Ba97629E05D5fD335d';

const curveABI = [
  {
    name: 'SLOPE',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'OFFSET',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  }
] as const;

const registryABI = [
  {
    name: 'currentPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'id', type: 'uint256' },
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
      { name: 'totalShares', type: 'uint256' },
      { name: 'id', type: 'uint256' }
    ],
    outputs: [{ name: 'shares', type: 'uint256' }]
  }
] as const;

const vaultABI = [
  {
    name: 'getVault',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' }
    ],
    outputs: [
      { name: 'totalAssets', type: 'uint256' },
      { name: 'totalShares', type: 'uint256' }
    ]
  }
] as const;

/**
 * Analyze OffsetProgressiveCurve parameters and pricing
 */
async function analyzeOffsetCurve(termId: `0x${string}`) {
  try {
    // Get curve parameters
    const [slope, offset] = await Promise.all([
      client.readContract({
        address: OFFSET_CURVE_ADDRESS,
        abi: curveABI,
        functionName: 'SLOPE'
      }),
      client.readContract({
        address: OFFSET_CURVE_ADDRESS,
        abi: curveABI,
        functionName: 'OFFSET'
      })
    ]);

    console.log('OffsetProgressiveCurve Parameters:');
    console.log(`  Slope: ${formatEther(slope)}`);
    console.log(`  Offset: ${formatEther(offset)}`);

    // Get vault state
    const [totalAssets, totalShares] = await client.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: vaultABI,
      functionName: 'getVault',
      args: [termId, OFFSET_CURVE_ID]
    });

    console.log(`\nVault State:`);
    console.log(`  Total Assets: ${formatEther(totalAssets)} TRUST`);
    console.log(`  Total Shares: ${formatEther(totalShares)}`);

    // Calculate prices at different points
    const prices = [];
    const shareCounts = [0n, totalShares / 2n, totalShares, totalShares * 2n];

    for (const shares of shareCounts) {
      const price = await client.readContract({
        address: REGISTRY_ADDRESS,
        abi: registryABI,
        functionName: 'currentPrice',
        args: [OFFSET_CURVE_ID, shares, totalAssets]
      });

      prices.push({ shares, price });
    }

    console.log(`\nPrice Progression:`);
    prices.forEach(({ shares, price }) => {
      console.log(`  At ${formatEther(shares)} shares: ${formatEther(price)} TRUST/share`);
    });

    // Calculate minimum price (at 0 shares)
    const minPrice = slope * offset / parseEther('1');
    console.log(`\nMinimum Price (price floor): ${formatEther(minPrice)} TRUST/share`);

    return { slope, offset, totalAssets, totalShares, prices };
  } catch (error) {
    console.error('Error analyzing offset curve:', error);
    throw error;
  }
}

// Example usage
const termId = '0x742d35cc6634c0532925a3b844bc9e7595f0b2cf2c9526b1c1a9b8d0f0e5d8a4' as const;
analyzeOffsetCurve(termId);
```

#### Demonstrating Offset Effect

```typescript
/**
 * Compare standard progressive vs offset progressive pricing
 */
async function compareOffsetEffect(depositAmount: bigint) {
  console.log(`\nComparing Curve Behavior for ${formatEther(depositAmount)} TRUST deposit\n`);

  // Simulate both curves starting from empty vault
  const slope = parseEther('2');
  const offset = parseEther('1');
  const halfSlope = slope / 2n;

  // Standard ProgressiveCurve (offset = 0)
  console.log('Standard ProgressiveCurve (offset = 0):');
  let totalShares = 0n;
  const standardShares = sqrt(depositAmount * parseEther('2') / slope);
  const standardPrice = totalShares * slope / parseEther('1'); // ~0
  const standardNewPrice = standardShares * slope / parseEther('1');

  console.log(`  Initial Price: ${formatEther(standardPrice)} TRUST/share`);
  console.log(`  Shares Received: ${formatEther(standardShares)}`);
  console.log(`  New Price: ${formatEther(standardNewPrice)} TRUST/share`);
  console.log(`  Avg Price Paid: ${formatEther(depositAmount * parseEther('1') / standardShares)} TRUST/share`);

  // OffsetProgressiveCurve (offset = 1)
  console.log(`\nOffsetProgressiveCurve (offset = ${formatEther(offset)}):`);
  const sOffset = offset; // totalShares = 0, so s + offset = offset
  const inner = sOffset * sOffset + depositAmount * parseEther('2') / slope;
  const offsetShares = sqrt(inner) - sOffset;
  const offsetPrice = sOffset * slope / parseEther('1');
  const offsetNewPrice = (sOffset + offsetShares) * slope / parseEther('1');

  console.log(`  Initial Price: ${formatEther(offsetPrice)} TRUST/share`);
  console.log(`  Shares Received: ${formatEther(offsetShares)}`);
  console.log(`  New Price: ${formatEther(offsetNewPrice)} TRUST/share`);
  console.log(`  Avg Price Paid: ${formatEther(depositAmount * parseEther('1') / offsetShares)} TRUST/share`);

  // Compare
  console.log(`\nComparison:`);
  console.log(`  Share Difference: ${formatEther(standardShares - offsetShares)} (standard gives more)`);
  console.log(`  Price Floor Difference: ${formatEther(offsetPrice - standardPrice)} TRUST/share`);
}

// Helper: Simplified sqrt for demo (use proper library in production)
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

compareOffsetEffect(parseEther('100'));
```

### Python (web3.py)

```python
from web3 import Web3
import json
import math

w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))

# Mainnet addresses
OFFSET_CURVE_ADDRESS = '0x23afF95153aa88D28B9B97Ba97629E05D5fD335d'
REGISTRY_ADDRESS = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930'
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

with open('OffsetProgressiveCurve.json') as f:
    curve_abi = json.load(f)['abi']

with open('BondingCurveRegistry.json') as f:
    registry_abi = json.load(f)['abi']

with open('MultiVault.json') as f:
    vault_abi = json.load(f)['abi']

curve = w3.eth.contract(address=OFFSET_CURVE_ADDRESS, abi=curve_abi)
registry = w3.eth.contract(address=REGISTRY_ADDRESS, abi=registry_abi)
vault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=vault_abi)

def analyze_offset_pricing_dynamics(
    term_id: bytes,
    deposit_range: list[int]
) -> None:
    """
    Analyze how offset affects pricing dynamics

    Args:
        term_id: Vault term ID
        deposit_range: List of deposit amounts to test
    """
    # Get curve parameters
    slope = curve.functions.SLOPE().call()
    offset = curve.functions.OFFSET().call()
    half_slope = slope // 2

    print(f'OffsetProgressiveCurve Pricing Analysis')
    print(f'Slope: {w3.from_wei(slope, "ether")}')
    print(f'Offset: {w3.from_wei(offset, "ether")}')
    print(f'Minimum Price: {w3.from_wei(slope * offset // 10**18, "ether")} TRUST/share\n')

    # Get current state
    total_assets, total_shares = vault.functions.getVault(
        term_id,
        2  # Curve ID for OffsetProgressiveCurve
    ).call()

    print(f'Current State:')
    print(f'  Assets: {w3.from_wei(total_assets, "ether")} TRUST')
    print(f'  Shares: {w3.from_wei(total_shares, "ether")}\n')

    for deposit in deposit_range:
        # Preview deposit
        shares = registry.functions.previewDeposit(
            deposit,
            total_assets,
            total_shares,
            2  # Curve ID
        ).call()

        # Calculate prices
        price_before = registry.functions.currentPrice(
            2,
            total_shares,
            total_assets
        ).call()

        price_after = registry.functions.currentPrice(
            2,
            total_shares + shares,
            total_assets + deposit
        ).call()

        avg_price = (deposit * 10**18) // shares if shares > 0 else 0

        print(f'Deposit: {w3.from_wei(deposit, "ether")} TRUST')
        print(f'  Shares: {w3.from_wei(shares, "ether")}')
        print(f'  Price: {w3.from_wei(price_before, "ether")} -> {w3.from_wei(price_after, "ether")}')
        print(f'  Avg Price: {w3.from_wei(avg_price, "ether")} TRUST/share')
        print()

        # Update state for next iteration
        total_shares += shares
        total_assets += deposit

# Example usage
term_id = bytes.fromhex('742d35cc6634c0532925a3b844bc9e7595f0b2cf2c9526b1c1a9b8d0f0e5d8a4')
analyze_offset_pricing_dynamics(
    term_id,
    [
        w3.to_wei(10, 'ether'),
        w3.to_wei(50, 'ether'),
        w3.to_wei(100, 'ether'),
        w3.to_wei(500, 'ether')
    ]
)

def calculate_offset_impact_on_capacity(
    slope: int,
    offsets: list[int]
) -> None:
    """
    Show how offset affects maximum capacity

    Args:
        slope: Curve slope
        offsets: List of offset values to compare
    """
    print('\nOffset Impact on Maximum Capacity\n')

    max_base = int(math.sqrt(2**256 // 10**18))

    for offset in offsets:
        max_shares = max_base - offset
        max_assets = (slope // 2) * (
            ((max_shares + offset) ** 2 - offset ** 2)
        ) // 10**18

        print(f'Offset: {w3.from_wei(offset, "ether")}')
        print(f'  Max Shares: {w3.from_wei(max_shares, "ether")}')
        print(f'  Max Assets: {w3.from_wei(max_assets, "ether")} TRUST')
        print(f'  Capacity Reduction: {((max_base - max_shares) * 100) // max_base}%')
        print()

calculate_offset_impact_on_capacity(
    w3.to_wei(2, 'ether'),
    [0, w3.to_wei(1, 'ether'), w3.to_wei(10, 'ether'), w3.to_wei(100, 'ether')]
)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/curves/IBaseCurve.sol";

/**
 * @title OffsetProgressiveAnalyzer
 * @notice Utilities for analyzing OffsetProgressiveCurve behavior
 */
contract OffsetProgressiveAnalyzer {
    IBaseCurve public immutable offsetCurve;

    // Simulate reading SLOPE and OFFSET (in production, use proper interface)
    uint256 public immutable SLOPE;
    uint256 public immutable OFFSET;

    constructor(address _curve, uint256 _slope, uint256 _offset) {
        offsetCurve = IBaseCurve(_curve);
        SLOPE = _slope;
        OFFSET = _offset;
    }

    /**
     * @notice Calculate the price floor (minimum price at 0 shares)
     * @return minPrice Minimum possible share price
     */
    function calculatePriceFloor() external view returns (uint256 minPrice) {
        // At totalShares = 0, price = SLOPE × OFFSET
        minPrice = SLOPE * OFFSET / 1e18;
    }

    /**
     * @notice Calculate how offset reduces early adopter advantage
     * @param totalShares Current total shares
     * @param totalAssets Current total assets
     * @param depositAmount Amount to deposit
     * @return reductionBps Reduction in basis points compared to zero offset
     */
    function calculateOffsetAdvantageReduction(
        uint256 totalShares,
        uint256 totalAssets,
        uint256 depositAmount
    ) external view returns (uint256 reductionBps) {
        // Get shares with current offset
        uint256 sharesWithOffset = offsetCurve.previewDeposit(
            depositAmount,
            totalAssets,
            totalShares
        );

        // Simulate shares without offset (pure progressive)
        // This is approximate - actual calculation more complex
        uint256 halfSlope = SLOPE / 2;
        uint256 effectiveShares = totalShares + OFFSET;
        uint256 inner = (effectiveShares * effectiveShares) +
                       (depositAmount * 1e18 / halfSlope);

        // Simplified sqrt approximation
        uint256 sharesNoOffset = _sqrt(inner) - OFFSET;

        if (sharesNoOffset > sharesWithOffset && sharesNoOffset > 0) {
            reductionBps = ((sharesNoOffset - sharesWithOffset) * 10000) / sharesNoOffset;
        }
    }

    /**
     * @notice Determine if offset makes pricing more balanced
     * @param totalShares Current total shares
     * @param totalAssets Current total assets
     * @param deposits Array of deposit amounts
     * @return avgPriceStdDev Standard deviation of average prices (simplified)
     */
    function analyzeBalancedPricing(
        uint256 totalShares,
        uint256 totalAssets,
        uint256[] calldata deposits
    ) external view returns (uint256 avgPriceStdDev) {
        uint256[] memory avgPrices = new uint256[](deposits.length);
        uint256 sum = 0;

        uint256 currentShares = totalShares;
        uint256 currentAssets = totalAssets;

        // Calculate average price for each deposit
        for (uint256 i = 0; i < deposits.length; i++) {
            uint256 shares = offsetCurve.previewDeposit(
                deposits[i],
                currentAssets,
                currentShares
            );

            avgPrices[i] = (deposits[i] * 1e18) / shares;
            sum += avgPrices[i];

            currentShares += shares;
            currentAssets += deposits[i];
        }

        // Calculate mean
        uint256 mean = sum / deposits.length;

        // Calculate variance (simplified)
        uint256 varianceSum = 0;
        for (uint256 i = 0; i < avgPrices.length; i++) {
            uint256 diff = avgPrices[i] > mean
                ? avgPrices[i] - mean
                : mean - avgPrices[i];
            varianceSum += (diff * diff);
        }

        // Standard deviation (simplified)
        avgPriceStdDev = _sqrt(varianceSum / deposits.length);
    }

    /**
     * @notice Calculate optimal offset for target minimum price
     * @param slope The curve slope
     * @param targetMinPrice Desired minimum price
     * @return optimalOffset Required offset value
     */
    function calculateOptimalOffset(
        uint256 slope,
        uint256 targetMinPrice
    ) external pure returns (uint256 optimalOffset) {
        // minPrice = slope × offset
        // offset = minPrice / slope
        optimalOffset = (targetMinPrice * 1e18) / slope;
    }

    // Simplified sqrt (use proper library in production)
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

/**
 * @title OffsetCurveDeployer
 * @notice Helper for deploying OffsetProgressiveCurve instances
 */
contract OffsetCurveDeployer {
    event OffsetCurveDeployed(
        address indexed curve,
        uint256 slope,
        uint256 offset,
        uint256 minPrice
    );

    /**
     * @notice Deploy OffsetProgressiveCurve with validated parameters
     * @param implementation Implementation contract address
     * @param name Curve name
     * @param slope Slope parameter (must be even)
     * @param offset Offset parameter
     * @return proxy Deployed proxy address
     */
    function deployWithParameters(
        address implementation,
        string memory name,
        uint256 slope,
        uint256 offset
    ) external returns (address proxy) {
        // Validate slope
        require(slope > 0 && slope % 2 == 0, "Invalid slope");

        // Calculate minimum price
        uint256 minPrice = (slope * offset) / 1e18;

        // Deploy and initialize
        // (Simplified - use proper proxy deployment in production)
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,uint256,uint256)",
            name,
            slope,
            offset
        );

        // Deploy proxy (pseudo-code)
        // proxy = deployProxy(implementation, initData);

        emit OffsetCurveDeployed(proxy, slope, offset, minPrice);
    }
}
```

## Integration Notes

### Parameter Selection Guide

When deploying OffsetProgressiveCurve:

**Slope Selection**:
- **High (e.g., 10e18)**: Steep price increases, strong scarcity
- **Medium (e.g., 2e18)**: Balanced growth (mainnet default)
- **Low (e.g., 0.5e18)**: Gentle increases, high capacity

**Offset Selection**:
- **High (e.g., 100e18)**: High price floor, minimal early advantage
- **Medium (e.g., 1e18)**: Moderate floor (mainnet default)
- **Low (e.g., 0.1e18)**: Lower floor, some early advantage
- **Zero (0)**: Standard ProgressiveCurve behavior

**Current Mainnet Config**:
```typescript
slope = 2e18  // Price increases by 2 TRUST per share
offset = 1e18 // Minimum price of 2 TRUST/share
```

### Mainnet Deployment Analysis

The current mainnet deployment (slope=2, offset=1) creates:

**Price Floor**: 2 TRUST/share (minimum price)

**Price at 100 shares**: (100 + 1) × 2 = 202 TRUST/share

**First Share Cost**: ~2 TRUST

**100th Share Cost**: ~202 TRUST

**Early Advantage**: Moderate (first buyer pays 100x less than 100th)

### Common Integration Patterns

#### Checking Price Floor
```typescript
const minPrice = await curve.currentPrice(0n, 0n);
console.log(`Price floor: ${formatEther(minPrice)} TRUST/share`);
```

#### Calculating Offset Impact
```typescript
// Compare price with/without offset
const priceWithOffset = (shares + offset) * slope;
const priceWithoutOffset = shares * slope;
const offsetImpact = priceWithOffset - priceWithoutOffset;
```

### Edge Cases

1. **Empty Vault**: Price is `offset × slope`, not zero
2. **Large Offset**: Reduces maximum capacity significantly
3. **Offset > Current Shares**: Normal, offset can exceed share count
4. **Zero Offset**: Behaves exactly like ProgressiveCurve

## Gas Considerations

### Operation Costs

OffsetProgressiveCurve is the most expensive curve:

| Operation | Gas Cost | Reason |
|-----------|----------|---------|
| `previewDeposit` | ~20,000 | sqrt + offset ops |
| `previewRedeem` | ~12,000 | square + offset ops |
| `previewMint` | ~13,000 | squareUp + offset |
| `previewWithdraw` | ~21,000 | sqrt + divUp + offset |
| `currentPrice` | ~5,000 | offset addition + multiplication |

**Comparison**:
- LinearCurve: ~3,000 gas
- ProgressiveCurve: ~15,000 gas
- OffsetProgressiveCurve: ~20,000 gas

**Why More Expensive**:
- Additional offset parameter in all calculations
- Extra additions before squaring/sqrt
- More complex rounding logic

### Optimization Tips

1. **Cache Parameters**: SLOPE and OFFSET don't change
2. **Batch Operations**: Use multicall for multiple previews
3. **Off-Chain Calculation**: Calculate locally when possible
4. **Consider Alternatives**: Use LinearCurve if offset not needed

## Mathematical Formulas

### Core Formulas with Offset

#### Price Function
```
P(s) = slope × (s + offset)
```

#### Asset Calculation
```
A(s) = ∫[offset to s+offset] (slope × x) dx
A(s) = (slope/2) × [(s+offset)² - offset²]
A(s) = HALF_SLOPE × [(s+offset)² - offset²]
```

#### Simplified Asset Formula
```
A(s) = HALF_SLOPE × [s² + 2×s×offset]
A(s) = HALF_SLOPE × s × (s + 2×offset)
```

#### Shares from Assets (Deposit)
```
Given: assets, totalShares, OFFSET
Find: Δs

assets = HALF_SLOPE × [(s+Δs+OFFSET)² - (s+OFFSET)²]

Let s_off = s + OFFSET:
assets = HALF_SLOPE × [(s_off+Δs)² - s_off²]
assets/HALF_SLOPE = (s_off+Δs)² - s_off²
s_off² + assets/HALF_SLOPE = (s_off+Δs)²

Δs = √(s_off² + assets/HALF_SLOPE) - s_off
```

#### Assets from Shares (Redemption)
```
Given: shares, totalShares, OFFSET
Find: assets

s_off = totalShares + OFFSET
s_new = (totalShares - shares) + OFFSET

assets = HALF_SLOPE × (s_off² - s_new²)
```

### Example Calculation

**Setup** (Mainnet Parameters):
- SLOPE = 2e18
- HALF_SLOPE = 1e18
- OFFSET = 1e18
- totalShares = 100e18
- totalAssets = 10,100e18

**Step 1**: Calculate current price
```
price = (totalShares + OFFSET) × SLOPE
price = (100 + 1) × 2 = 202e18 TRUST/share
```

**Step 2**: Deposit 402e18 TRUST
```
s_off = 100 + 1 = 101
Δs = √(101² + 402/1) - 101
Δs = √(10,201 + 402) - 101
Δs = √10,603 - 101
Δs ≈ 103 - 101 = 2 shares
```

**Step 3**: New price
```
newPrice = (102 + 1) × 2 = 206e18 TRUST/share
```

**Step 4**: Average price paid
```
avgPrice = 402 / 2 = 201e18 TRUST/share
```

**Step 5**: Compare to no offset
```
Without offset (ProgressiveCurve):
price = 100 × 2 = 200 TRUST/share
shares = √(100² + 402/1) - 100 ≈ 2 shares
newPrice = 102 × 2 = 204 TRUST/share

Offset impact: +2 TRUST/share minimum price
```

## Comparison to Other Curve Types

| Feature | LinearCurve | ProgressiveCurve | OffsetProgressiveCurve |
|---------|-------------|------------------|------------------------|
| **Price at s=0** | Dynamic | ~0 | offset × slope |
| **Price Formula** | a/s | slope × s | slope × (s + offset) |
| **Price Floor** | None | ~0 | offset × slope |
| **Early Advantage** | None | Extreme | Moderate |
| **Capacity** | Unlimited | High | Medium (offset reduces) |
| **Gas Cost** | ~3k | ~15k | ~20k |
| **Complexity** | Low | High | Very High |
| **Deployment** | Curve ID 1 | Not deployed | Curve ID 2 |
| **Use Case** | Stable pricing | Price discovery | Balanced progressive |

### When to Use OffsetProgressiveCurve

**Best For**:
- Progressive pricing with controlled minimum
- Preventing zero-price exploitation
- Balanced early adopter rewards
- Smoother price progression
- Production environments (currently deployed)

**Avoid When**:
- Need lowest gas costs (use LinearCurve)
- Want unlimited capacity (use LinearCurve)
- Maximum early advantage desired (use ProgressiveCurve)
- Predictable 1:1 pricing needed (use LinearCurve)

## Related Contracts

### Curve System
- **[BaseCurve](./BaseCurve.md)**: Abstract interface
- **[BondingCurveRegistry](./BondingCurveRegistry.md)**: Manages curve ID 2
- **[LinearCurve](./LinearCurve.md)**: Curve ID 1, constant pricing
- **[ProgressiveCurve](./ProgressiveCurve.md)**: Base progressive model (no offset)

### Libraries
- **[ProgressiveCurveMathLib](../../reference/mathematical-formulas.md#progressive-curve-math-library)**: Provides `mulUp`, `divUp`, `square`, `squareUp`
- **PRB-Math UD60x18**: 60.18 fixed-point arithmetic

### Core Integration
- **[MultiVault](../core/MultiVault.md)**: Primary user of curve ID 2
- **[MultiVaultCore](../core/MultiVaultCore.md)**: Vault configuration

## See Also

### Concept Documentation
- [Bonding Curves](../../concepts/bonding-curves.md) - Complete bonding curve explanation
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - Economic diversity through curves

### Integration Guides
- [Creating Atoms](../../guides/creating-atoms.md) - Using OffsetProgressiveCurve
- [Creating Triples](../../guides/creating-triples.md) - Curve selection
- [Depositing Assets](../../guides/depositing-assets.md) - Working with curve ID 2

### Reference
- [Mathematical Formulas](../../reference/mathematical-formulas.md) - Detailed mathematics
- [Gas Benchmarks](../../reference/gas-benchmarks.md) - Performance data

---

**Last Updated**: December 2025
**Version**: V2.0
**Curve ID**: 2
**Deployment**: Mainnet & Testnet (slope=2e18, offset=1e18)
