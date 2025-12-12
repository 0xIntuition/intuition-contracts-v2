# LinearCurve

## Overview

The **LinearCurve** is a bonding curve implementation that provides constant 1:1 pricing between assets and shares, similar to traditional share-based systems. Unlike progressive curves where each share becomes more expensive, the LinearCurve maintains a constant proportional relationship where share value increases through fee accumulation rather than supply-based pricing changes. This makes it ideal for stable, predictable pricing scenarios with minimal price volatility.

### Purpose and Role in Protocol

- **Constant Pricing**: Maintains 1:1 asset-to-share ratio at any given moment
- **Fee-Based Growth**: Share value increases through pro-rata fee distribution, not price curves
- **Predictable Valuation**: Enables straightforward calculation of share values
- **Low Volatility**: Minimizes price impact from large deposits or redemptions
- **Simple Mathematics**: Uses basic proportional calculations without complex formulas
- **Gas Efficient**: Minimal computational overhead for pricing operations

### Key Responsibilities

1. **1:1 Conversion**: Convert assets to shares proportionally based on current ratio
2. **Pro-Rata Calculation**: Distribute accumulated fees proportionally to share holders
3. **Constant Price**: Maintain predictable share pricing without progressive scaling
4. **Bounds Validation**: Ensure operations stay within maximum limits (though effectively unlimited)
5. **Rounding Protection**: Apply protocol-favorable rounding to prevent value extraction

## Contract Information

- **Location**: `src/protocol/curves/LinearCurve.sol`
- **Inherits**:
  - `BaseCurve` (abstract bonding curve interface)
  - `Initializable` (OpenZeppelin upgradeable base)
- **Interface**: `IBaseCurve` (`src/interfaces/IBaseCurve.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)
- **Curve ID**: 1 (in BondingCurveRegistry)

### Network Deployments

#### Intuition Mainnet
- **Proxy Address**: [`0xc3eFD5471dc63d74639725f381f9686e3F264366`](https://explorer.intuit.network/address/0xc3eFD5471dc63d74639725f381f9686e3F264366)
- **Implementation**: `0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c`
- **Curve ID**: 1
- **Name**: "LinearCurve"

#### Intuition Testnet
- **Proxy Address**: [`0x6df5eecd9B14E31C98A027b8634876E4805F71B0`](https://explorer.testnet.intuit.network/address/0x6df5eecd9B14E31C98A027b8634876E4805F71B0)
- **Implementation**: `0x34D65193EE2e1449FE6CB8eca1EE046FcC21669e`
- **Curve ID**: 1
- **Name**: "LinearCurve"

## Key Concepts

### Linear Pricing Model

The LinearCurve implements a constant product model where:

**Price = totalAssets / totalShares**

This means:
- All shares are equal in value at any given moment
- Price changes only when the ratio of assets to shares changes
- Fees collected increase totalAssets without changing totalShares, raising price
- No progressive scaling - first and millionth share have same marginal price

### Mathematical Model

The curve follows the **proportional share model**:

```
shares = (assets * totalShares) / totalAssets
assets = (shares * totalAssets) / totalShares
```

#### For Deposits:
```
shares_received = deposit_amount * (totalShares / totalAssets)
```

If the vault is empty (totalShares = 0):
```
shares_received = deposit_amount (1:1 ratio)
```

#### For Redemptions:
```
assets_received = shares_redeemed * (totalAssets / totalShares)
```

### Fee Accumulation vs Price Increases

Unlike progressive curves, LinearCurve value growth comes from fees:

**Progressive Curve**: Price increases because supply increases
- Each new share costs more than the last
- Large deposits cause significant price impact
- Early buyers pay less, late buyers pay more

**Linear Curve**: Price increases because fees accumulate
- Each share always costs the same marginal price
- Fees are distributed pro-rata to all holders
- All holders benefit equally from fee accumulation
- Price impact is minimal

### Comparison to ERC-4626

The LinearCurve behaves similarly to the ERC-4626 vault standard:
- Constant share price at any moment
- Pro-rata distribution of value
- Simple share-to-asset conversion

**Key Difference**: MultiVault handles state management, while LinearCurve only provides the mathematical relationship.

### Unlimited Capacity

The LinearCurve defines maximum values as `type(uint256).max`:
- **MAX_SHARES**: 2^256 - 1
- **MAX_ASSETS**: 2^256 - 1

In practice, these limits are never reached due to:
- Total TRUST supply constraints
- MultiVault-level limitations
- Economic incentive structures

## State Variables

### Constants

```solidity
/// @dev Maximum number of shares (effectively unlimited)
uint256 public constant MAX_SHARES = type(uint256).max;

/// @dev Maximum number of assets (effectively unlimited)
uint256 public constant MAX_ASSETS = type(uint256).max;

/// @dev One share in 18 decimal format
uint256 public constant ONE_SHARE = 1e18;
```

**MAX_SHARES**: The theoretical maximum shares the curve can handle (2^256 - 1)

**MAX_ASSETS**: The theoretical maximum assets the curve can handle (2^256 - 1)

**ONE_SHARE**: Used in `currentPrice()` to calculate the price of a single share (1e18)

### Inherited State

From BaseCurve:

```solidity
/// @notice The name of the curve
string public name;
```

**name**: Set to "LinearCurve" during initialization

## Functions

### Initialization

#### `initialize`
```solidity
function initialize(string calldata _name) external initializer
```
Initializes the LinearCurve contract.

**Parameters**:
- `_name`: Name of the curve (typically "LinearCurve")

**Access**: Can only be called once during proxy deployment

**Emits**: `CurveNameSet` (from BaseCurve)

**Use Case**: Called by deployment script to set up the curve

---

### Core Curve Functions

#### `previewDeposit`
```solidity
function previewDeposit(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external pure returns (uint256 shares)
```
Calculates shares to be minted for a deposit.

**Parameters**:
- `assets`: Amount of assets to deposit
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Number of shares that would be minted

**Formula**:
```solidity
shares = totalShares == 0
    ? assets
    : (assets * totalShares) / totalAssets
```

**Rounding**: Rounds DOWN (favors protocol)

**Gas**: ~3,000 (pure function)

**Example**:
```typescript
// Vault has 1000 TRUST and 800 shares
// Depositing 100 TRUST
shares = 100 * 800 / 1000 = 80 shares
```

---

#### `previewRedeem`
```solidity
function previewRedeem(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external pure returns (uint256 assets)
```
Calculates assets to be returned for redemption.

**Parameters**:
- `shares`: Number of shares to redeem
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Amount of assets that would be returned

**Formula**:
```solidity
assets = totalShares == 0
    ? shares
    : (shares * totalAssets) / totalShares
```

**Rounding**: Rounds DOWN (favors protocol)

**Gas**: ~3,000 (pure function)

**Example**:
```typescript
// Vault has 1000 TRUST and 800 shares
// Redeeming 80 shares
assets = 80 * 1000 / 800 = 100 TRUST
```

---

#### `previewMint`
```solidity
function previewMint(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external pure returns (uint256 assets)
```
Calculates assets required to mint specific shares.

**Parameters**:
- `shares`: Number of shares to mint
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Amount of assets required

**Formula**:
```solidity
assets = totalShares == 0
    ? shares
    : fullMulDivUp(shares, totalAssets, totalShares)
```

**Rounding**: Rounds UP (favors protocol)

**Note**: Uses `fullMulDivUp` for precision

**Gas**: ~4,000 (pure function)

---

#### `previewWithdraw`
```solidity
function previewWithdraw(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external pure returns (uint256 shares)
```
Calculates shares needed to withdraw specific assets.

**Parameters**:
- `assets`: Amount of assets to withdraw
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Number of shares required

**Formula**:
```solidity
shares = totalShares == 0
    ? assets
    : fullMulDivUp(assets, totalShares, totalAssets)
```

**Rounding**: Rounds UP (favors protocol)

**Note**: Uses `fullMulDivUp` for precision

**Gas**: ~4,000 (pure function)

---

#### `convertToShares`
```solidity
function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external pure returns (uint256 shares)
```
Converts assets to equivalent shares at current rate.

**Parameters**:
- `assets`: Amount of assets to convert
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Equivalent number of shares

**Formula**: Same as `previewDeposit`

**Rounding**: Rounds DOWN

**Use Case**: Calculate share equivalents without executing deposit

---

#### `convertToAssets`
```solidity
function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external pure returns (uint256 assets)
```
Converts shares to equivalent assets at current rate.

**Parameters**:
- `shares`: Number of shares to convert
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Equivalent amount of assets

**Formula**: Same as `previewRedeem`

**Rounding**: Rounds DOWN

**Use Case**: Calculate asset equivalents without executing redemption

---

#### `currentPrice`
```solidity
function currentPrice(
    uint256 totalShares,
    uint256 totalAssets
) external pure returns (uint256 sharePrice)
```
Returns the current price of one share.

**Parameters**:
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Current share price (scaled by 1e18)

**Formula**:
```solidity
sharePrice = (ONE_SHARE * totalAssets) / totalShares
```

**Units**: TRUST per share (18 decimals)

**Example**:
```typescript
// Vault has 1250 TRUST and 1000 shares
price = 1e18 * 1250 / 1000 = 1.25e18
// = 1.25 TRUST per share
```

**Special Case**: Returns 1e18 (1 TRUST) if totalShares == 0

---

### Maximum Limit Functions

#### `maxShares`
```solidity
function maxShares() external pure returns (uint256)
```
Returns maximum shares the curve can handle.

**Returns**: `type(uint256).max` (effectively unlimited)

---

#### `maxAssets`
```solidity
function maxAssets() external pure returns (uint256)
```
Returns maximum assets the curve can handle.

**Returns**: `type(uint256).max` (effectively unlimited)

---

## Internal Functions

### `_convertToShares`
```solidity
function _convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) internal pure returns (uint256 shares)
```
Internal helper for asset-to-share conversion.

**Formula**:
```solidity
shares = totalShares == 0
    ? assets
    : fullMulDiv(assets, totalShares, totalAssets)
```

**Rounding**: Rounds DOWN using `fullMulDiv`

**Used By**: `previewDeposit`, `convertToShares`

---

### `_convertToAssets`
```solidity
function _convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) internal pure returns (uint256 assets)
```
Internal helper for share-to-asset conversion.

**Formula**:
```solidity
assets = totalShares == 0
    ? shares
    : fullMulDiv(shares, totalAssets, totalShares)
```

**Rounding**: Rounds DOWN using `fullMulDiv`

**Used By**: `previewRedeem`, `convertToAssets`, `currentPrice`

---

## Events

The LinearCurve contract emits events inherited from BaseCurve:

### `CurveNameSet`
```solidity
event CurveNameSet(string name)
```
Emitted when the curve name is set during initialization.

**Parameters**:
- `name`: The curve name ("LinearCurve")

**Use Cases**:
- Verify correct initialization
- Audit curve deployment
- Index curve creation

---

## Errors

The LinearCurve inherits error handling from BaseCurve. All errors are checked in the validation layer:

### Inherited Errors

#### `BaseCurve_AssetsExceedTotalAssets`
Thrown when withdrawal amount exceeds vault's total assets.

**Trigger**: `previewWithdraw` with assets > totalAssets

**Recovery**: Reduce withdrawal amount

---

#### `BaseCurve_SharesExceedTotalShares`
Thrown when redemption exceeds total shares.

**Trigger**: `previewRedeem` or `convertToAssets` with shares > totalShares

**Recovery**: Reduce redemption amount

---

#### `BaseCurve_AssetsOverflowMax`
Thrown when operation would exceed MAX_ASSETS.

**Trigger**: Theoretically possible with MAX_ASSETS limit

**Reality**: Never occurs in practice (limit is type(uint256).max)

---

#### `BaseCurve_SharesOverflowMax`
Thrown when operation would exceed MAX_SHARES.

**Trigger**: Theoretically possible with MAX_SHARES limit

**Reality**: Never occurs in practice (limit is type(uint256).max)

---

#### `BaseCurve_DomainExceeded`
Thrown when current vault state exceeds curve limits.

**Trigger**: totalAssets or totalShares > MAX limits

**Reality**: Never occurs in practice

---

## Usage Examples

### TypeScript (VIEM)

#### Querying Linear Curve Pricing

```typescript
import { createPublicClient, http, parseEther, formatEther } from 'viem';
import { intuitionMainnet } from './chains';

// Setup
const client = createPublicClient({
  chain: intuitionMainnet,
  transport: http()
});

const LINEAR_CURVE_ID = 1n;
const REGISTRY_ADDRESS = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930';
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';

// Contract ABIs
const registryABI = [
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
  },
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
 * Calculate share price and deposit preview for LinearCurve
 */
async function analyzeLinearCurvePricing(
  termId: `0x${string}`,
  depositAmount: bigint
) {
  try {
    // Get current vault state
    const [totalAssets, totalShares] = await client.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: vaultABI,
      functionName: 'getVault',
      args: [termId, LINEAR_CURVE_ID]
    });

    console.log('Current Vault State:');
    console.log(`  Total Assets: ${formatEther(totalAssets)} TRUST`);
    console.log(`  Total Shares: ${formatEther(totalShares)}`);

    // Get current share price
    const price = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'currentPrice',
      args: [LINEAR_CURVE_ID, totalShares, totalAssets]
    });

    console.log(`\nCurrent Share Price: ${formatEther(price)} TRUST/share`);

    // Preview deposit
    const sharesReceived = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'previewDeposit',
      args: [depositAmount, totalAssets, totalShares, LINEAR_CURVE_ID]
    });

    console.log(`\nDeposit Preview:`);
    console.log(`  Deposit Amount: ${formatEther(depositAmount)} TRUST`);
    console.log(`  Shares Received: ${formatEther(sharesReceived)}`);

    // Calculate average price paid
    const avgPrice = (depositAmount * parseEther('1')) / sharesReceived;
    console.log(`  Average Price: ${formatEther(avgPrice)} TRUST/share`);

    // Calculate price impact
    const priceImpact = ((avgPrice - price) * 100n) / price;
    console.log(`  Price Impact: ${priceImpact / 100n}.${priceImpact % 100n}%`);

    // Calculate new price after deposit
    const newTotalAssets = totalAssets + depositAmount;
    const newTotalShares = totalShares + sharesReceived;
    const newPrice = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'currentPrice',
      args: [LINEAR_CURVE_ID, newTotalShares, newTotalAssets]
    });

    console.log(`\nNew Share Price: ${formatEther(newPrice)} TRUST/share`);

    return {
      currentPrice: price,
      sharesReceived,
      averagePrice: avgPrice,
      priceImpact,
      newPrice
    };
  } catch (error) {
    console.error('Error analyzing LinearCurve:', error);
    throw error;
  }
}

// Example: Analyze depositing 100 TRUST
const termId = '0x742d35cc6634c0532925a3b844bc9e7595f0b2cf2c9526b1c1a9b8d0f0e5d8a4' as const;
analyzeLinearCurvePricing(termId, parseEther('100'));
```

#### Demonstrating Constant Pricing

```typescript
/**
 * Demonstrate that LinearCurve maintains constant marginal price
 */
async function demonstrateConstantPricing(
  termId: `0x${string}`,
  deposits: bigint[]
) {
  console.log('LinearCurve Constant Pricing Demonstration\n');

  // Get initial state
  let [totalAssets, totalShares] = await client.readContract({
    address: MULTIVAULT_ADDRESS,
    abi: vaultABI,
    functionName: 'getVault',
    args: [termId, LINEAR_CURVE_ID]
  });

  console.log(`Initial State: ${formatEther(totalAssets)} assets, ${formatEther(totalShares)} shares\n`);

  for (const depositAmount of deposits) {
    // Get current price
    const priceBefore = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'currentPrice',
      args: [LINEAR_CURVE_ID, totalShares, totalAssets]
    });

    // Calculate shares
    const shares = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'previewDeposit',
      args: [depositAmount, totalAssets, totalShares, LINEAR_CURVE_ID]
    });

    // Update state
    totalAssets += depositAmount;
    totalShares += shares;

    // Get new price
    const priceAfter = await client.readContract({
      address: REGISTRY_ADDRESS,
      abi: registryABI,
      functionName: 'currentPrice',
      args: [LINEAR_CURVE_ID, totalShares, totalAssets]
    });

    console.log(`Deposit: ${formatEther(depositAmount)} TRUST`);
    console.log(`  Shares: ${formatEther(shares)}`);
    console.log(`  Price Before: ${formatEther(priceBefore)} TRUST/share`);
    console.log(`  Price After: ${formatEther(priceAfter)} TRUST/share`);
    console.log(`  Price Change: ${formatEther(priceAfter - priceBefore)} TRUST/share`);
    console.log();
  }

  console.log('Note: Price remains constant because LinearCurve uses pro-rata distribution');
}

// Test with various deposit sizes
demonstrateConstantPricing(
  termId,
  [parseEther('10'), parseEther('100'), parseEther('1000')]
);
```

### Python (web3.py)

```python
from web3 import Web3
from decimal import Decimal
import json

# Setup
w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC_URL'))
LINEAR_CURVE_ID = 1
REGISTRY_ADDRESS = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930'
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

# Load ABIs
with open('BondingCurveRegistry.json') as f:
    registry_abi = json.load(f)['abi']

with open('MultiVault.json') as f:
    vault_abi = json.load(f)['abi']

registry = w3.eth.contract(address=REGISTRY_ADDRESS, abi=registry_abi)
vault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=vault_abi)

def analyze_fee_impact_on_linear_curve(
    term_id: bytes,
    fee_amounts: list[int]
) -> None:
    """
    Demonstrate how fees increase share value in LinearCurve

    Args:
        term_id: The vault term ID
        fee_amounts: List of fee amounts to simulate
    """
    # Get initial state
    total_assets, total_shares = vault.functions.getVault(
        term_id,
        LINEAR_CURVE_ID
    ).call()

    initial_price = registry.functions.currentPrice(
        LINEAR_CURVE_ID,
        total_shares,
        total_assets
    ).call()

    print(f'LinearCurve Fee Impact Analysis\n')
    print(f'Initial State:')
    print(f'  Assets: {w3.from_wei(total_assets, "ether")} TRUST')
    print(f'  Shares: {w3.from_wei(total_shares, "ether")}')
    print(f'  Price: {w3.from_wei(initial_price, "ether")} TRUST/share\n')

    cumulative_fees = 0

    for fee in fee_amounts:
        # Simulate fee accumulation (increases assets, not shares)
        cumulative_fees += fee
        new_total_assets = total_assets + cumulative_fees

        # Calculate new price
        new_price = registry.functions.currentPrice(
            LINEAR_CURVE_ID,
            total_shares,  # shares unchanged
            new_total_assets
        ).call()

        price_increase = new_price - initial_price
        price_increase_pct = (price_increase * 100) / initial_price

        print(f'After {w3.from_wei(cumulative_fees, "ether")} TRUST in fees:')
        print(f'  New Price: {w3.from_wei(new_price, "ether")} TRUST/share')
        print(f'  Increase: {w3.from_wei(price_increase, "ether")} (+{price_increase_pct}%)')
        print()

# Example: Simulate fee accumulation
term_id = bytes.fromhex('742d35cc6634c0532925a3b844bc9e7595f0b2cf2c9526b1c1a9b8d0f0e5d8a4')
analyze_fee_impact_on_linear_curve(
    term_id,
    [
        w3.to_wei(10, 'ether'),
        w3.to_wei(50, 'ether'),
        w3.to_wei(100, 'ether')
    ]
)

def compare_linear_to_progressive(
    term_id: bytes,
    deposit_amount: int
) -> dict:
    """
    Compare LinearCurve (ID 1) to OffsetProgressiveCurve (ID 2)

    Args:
        term_id: The vault term ID
        deposit_amount: Amount to deposit

    Returns:
        Comparison data
    """
    curves = [
        {'id': 1, 'name': 'LinearCurve'},
        {'id': 2, 'name': 'OffsetProgressiveCurve'}
    ]

    print(f'\nCurve Comparison for {w3.from_wei(deposit_amount, "ether")} TRUST deposit:\n')

    results = []

    for curve in curves:
        # Get vault state for this curve
        total_assets, total_shares = vault.functions.getVault(
            term_id,
            curve['id']
        ).call()

        # Preview deposit
        shares = registry.functions.previewDeposit(
            deposit_amount,
            total_assets,
            total_shares,
            curve['id']
        ).call()

        # Get prices
        price_before = registry.functions.currentPrice(
            curve['id'],
            total_shares,
            total_assets
        ).call()

        price_after = registry.functions.currentPrice(
            curve['id'],
            total_shares + shares,
            total_assets + deposit_amount
        ).call()

        avg_price = (deposit_amount * 10**18) // shares if shares > 0 else 0

        result = {
            'name': curve['name'],
            'shares': shares,
            'price_before': price_before,
            'price_after': price_after,
            'avg_price': avg_price,
            'price_impact': ((price_after - price_before) * 100) // price_before if price_before > 0 else 0
        }

        results.append(result)

        print(f"{curve['name']}:")
        print(f"  Shares: {w3.from_wei(shares, 'ether')}")
        print(f"  Price: {w3.from_wei(price_before, 'ether')} -> {w3.from_wei(price_after, 'ether')}")
        print(f"  Avg Price: {w3.from_wei(avg_price, 'ether')} TRUST/share")
        print(f"  Price Impact: {result['price_impact']}%")
        print()

    return results

# Compare curves
compare_linear_to_progressive(term_id, w3.to_wei(100, 'ether'))
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBondingCurveRegistry.sol";
import "./interfaces/IMultiVault.sol";

/**
 * @title LinearCurveStrategy
 * @notice Example contract demonstrating LinearCurve integration patterns
 */
contract LinearCurveStrategy {
    IBondingCurveRegistry public immutable registry;
    IMultiVault public immutable multiVault;
    uint256 public constant LINEAR_CURVE_ID = 1;

    constructor(address _registry, address _multiVault) {
        registry = IBondingCurveRegistry(_registry);
        multiVault = IMultiVault(_multiVault);
    }

    /**
     * @notice Calculate the exact 1:1 nature of LinearCurve
     * @param termId The vault term ID
     * @param depositAmount Amount to analyze
     * @return isOneToOne Whether conversion is exactly 1:1
     * @return ratio The actual ratio (1e18 = 1:1)
     */
    function verifyOneToOneRatio(
        bytes32 termId,
        uint256 depositAmount
    ) external view returns (bool isOneToOne, uint256 ratio) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, LINEAR_CURVE_ID);

        // Get shares for deposit
        uint256 shares = registry.previewDeposit(
            depositAmount,
            totalAssets,
            totalShares,
            LINEAR_CURVE_ID
        );

        // Calculate ratio
        if (shares > 0) {
            ratio = (depositAmount * 1e18) / shares;
        }

        // Check if ratio matches current price
        uint256 currentSharePrice = registry.currentPrice(
            LINEAR_CURVE_ID,
            totalShares,
            totalAssets
        );

        isOneToOne = (ratio == currentSharePrice);
    }

    /**
     * @notice Demonstrate fee accumulation effect on LinearCurve
     * @param termId The vault term ID
     * @param feeAmount Simulated fee to add
     * @return priceIncrease How much price increases per share
     */
    function calculateFeeImpact(
        bytes32 termId,
        uint256 feeAmount
    ) external view returns (uint256 priceIncrease) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, LINEAR_CURVE_ID);

        // Price before fee
        uint256 priceBefore = registry.currentPrice(
            LINEAR_CURVE_ID,
            totalShares,
            totalAssets
        );

        // Price after fee (assets increase, shares don't)
        uint256 priceAfter = registry.currentPrice(
            LINEAR_CURVE_ID,
            totalShares,
            totalAssets + feeAmount
        );

        priceIncrease = priceAfter - priceBefore;
    }

    /**
     * @notice Calculate optimal deposit size to reach target share count
     * @param termId The vault term ID
     * @param targetShares Desired number of shares
     * @return depositAmount Exact deposit needed
     */
    function calculateDepositForTargetShares(
        bytes32 termId,
        uint256 targetShares
    ) external view returns (uint256 depositAmount) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, LINEAR_CURVE_ID);

        // For LinearCurve: depositAmount = targetShares * (totalAssets / totalShares)
        // Using previewMint for exact calculation with proper rounding
        depositAmount = registry.previewMint(
            targetShares,
            totalShares,
            totalAssets,
            LINEAR_CURVE_ID
        );
    }

    /**
     * @notice Verify that price impact is minimal for LinearCurve
     * @param termId The vault term ID
     * @param depositAmount Amount to deposit
     * @return impactBasisPoints Price impact in basis points (100 = 1%)
     */
    function measurePriceImpact(
        bytes32 termId,
        uint256 depositAmount
    ) external view returns (uint256 impactBasisPoints) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, LINEAR_CURVE_ID);

        uint256 priceBefore = registry.currentPrice(
            LINEAR_CURVE_ID,
            totalShares,
            totalAssets
        );

        uint256 shares = registry.previewDeposit(
            depositAmount,
            totalAssets,
            totalShares,
            LINEAR_CURVE_ID
        );

        uint256 priceAfter = registry.currentPrice(
            LINEAR_CURVE_ID,
            totalShares + shares,
            totalAssets + depositAmount
        );

        if (priceBefore > 0) {
            // Calculate impact in basis points
            impactBasisPoints = ((priceAfter - priceBefore) * 10000) / priceBefore;
        }
    }
}
```

## Integration Notes

### For Vault Creators

When creating a vault with LinearCurve:

**Best Use Cases**:
- Stable, predictable pricing scenarios
- Low-volatility assets or claims
- Fee-based value accrual models
- Simple share distribution systems

**Avoid When**:
- You want early adopter advantages (use ProgressiveCurve)
- Price discovery through supply is important
- You need price increases to discourage late entries

### For Depositors

**Advantages of LinearCurve**:
- Predictable share pricing
- No disadvantage for being early or late
- Proportional benefit from all fee accumulation
- Minimal price impact from large deposits

**Considerations**:
- No price appreciation from supply growth
- Value growth depends entirely on fees
- All depositors get equal treatment

### Common Patterns

#### Calculating Fee Impact
```typescript
// How much does X TRUST in fees increase share price?
const feeImpact = (feeAmount * 1e18) / totalShares;
```

#### Checking if Vault is Empty
```typescript
const [totalAssets, totalShares] = await getVault(termId, curveId);
const isEmpty = totalShares === 0n;

if (isEmpty) {
  // First deposit gets 1:1 ratio minus minimum shares burned
  console.log('First depositor - will receive shares 1:1');
}
```

### Edge Cases

1. **Empty Vault**: First deposit gets 1:1 ratio (minus MINIMUM_SHARES burned by MultiVault)
2. **Large Deposits**: Price impact is minimal due to proportional distribution
3. **Precision Loss**: Uses `fullMulDiv` to maintain precision in calculations
4. **Zero Division**: Explicitly handles totalShares == 0 case

## Gas Considerations

### Read Operations (View Functions)

All LinearCurve functions are pure/view with minimal gas:

| Operation | Gas Cost | Complexity |
|-----------|----------|-----------|
| `maxShares` | ~300 | O(1) constant |
| `maxAssets` | ~300 | O(1) constant |
| `currentPrice` | ~3,000 | O(1) division |
| `previewDeposit` | ~3,000 | O(1) multiplication/division |
| `previewRedeem` | ~3,000 | O(1) multiplication/division |
| `previewMint` | ~4,000 | O(1) with fullMulDivUp |
| `previewWithdraw` | ~4,000 | O(1) with fullMulDivUp |
| `convertToShares` | ~3,000 | O(1) multiplication/division |
| `convertToAssets` | ~3,000 | O(1) multiplication/division |

### Optimization Tips

1. **Cache Vault State**: If making multiple calculations, cache totalAssets/totalShares
2. **Batch Queries**: Use multicall for multiple preview operations
3. **Off-Chain Calculation**: LinearCurve math is simple enough to calculate off-chain
4. **Direct Calculation**: For known ratios, calculate directly without contract calls

### Comparison to Progressive Curves

LinearCurve is significantly cheaper than ProgressiveCurve:

| Curve Type | Typical Gas | Reason |
|------------|-------------|---------|
| LinearCurve | ~3,000 | Simple division |
| ProgressiveCurve | ~15,000 | Square root, PRBMath operations |
| OffsetProgressiveCurve | ~20,000 | Additional offset calculations |

## Mathematical Formulas

### Core Formulas

#### Share Calculation (Deposit)
```
shares = assets × (totalShares / totalAssets)
```

Special case (empty vault):
```
shares = assets
```

#### Asset Calculation (Redemption)
```
assets = shares × (totalAssets / totalShares)
```

#### Current Price
```
price = totalAssets / totalShares
```

### Fee Impact Formula

When fees are added to vault:
```
newPrice = (totalAssets + fees) / totalShares
priceIncrease = fees / totalShares
percentageIncrease = (fees / totalAssets) × 100%
```

### Example Calculation

**Initial State**:
- totalAssets = 1,000 TRUST
- totalShares = 800 shares
- price = 1,000 / 800 = 1.25 TRUST/share

**Deposit 100 TRUST**:
```
shares = 100 × (800 / 1,000)
shares = 100 × 0.8
shares = 80 shares
```

**New State**:
- totalAssets = 1,100 TRUST
- totalShares = 880 shares
- price = 1,100 / 880 = 1.25 TRUST/share (unchanged!)
```

**Add 50 TRUST in Fees**:
```
newPrice = (1,100 + 50) / 880
newPrice = 1,150 / 880
newPrice = 1.3068 TRUST/share
increase = 1.3068 - 1.25 = 0.0568 TRUST/share (+4.55%)
```

## Comparison to Other Curve Types

### LinearCurve vs ProgressiveCurve

| Feature | LinearCurve | ProgressiveCurve |
|---------|-------------|------------------|
| **Pricing** | Constant ratio | Increasing price |
| **Formula** | `price = assets / shares` | `price = slope × shares` |
| **Price Impact** | Minimal | Significant |
| **Early Advantage** | None | High |
| **Gas Cost** | Low (~3k) | Medium (~15k) |
| **Complexity** | Simple | Complex (sqrt, square) |
| **Value Growth** | Fees only | Supply + fees |
| **Use Case** | Stable pricing | Price discovery |

### LinearCurve vs OffsetProgressiveCurve

| Feature | LinearCurve | OffsetProgressiveCurve |
|---------|-------------|------------------------|
| **Initial Price** | Dynamic (ratio) | Offset × slope |
| **Price Growth** | Fee-based | Supply-based + offset |
| **Predictability** | High | Medium |
| **Gas Cost** | Low (~3k) | High (~20k) |
| **Complexity** | Simple | Complex (sqrt, offset) |

### When to Use Each Curve

**Use LinearCurve For**:
- Stable assets or claims
- Equal treatment of all depositors
- Predictable pricing
- Low gas costs
- Simple user understanding

**Use ProgressiveCurve For**:
- Price discovery
- Rewarding early adopters
- Creating scarcity
- Discouraging late entry

**Use OffsetProgressiveCurve For**:
- Progressive pricing with higher starting price
- Controlled initial price level
- Smoother price curve transitions

## Related Contracts

### Curve System
- **[BaseCurve](./BaseCurve.md)**: Abstract curve interface that LinearCurve implements
- **[BondingCurveRegistry](./BondingCurveRegistry.md)**: Registry managing curve routing (LinearCurve is ID 1)
- **[ProgressiveCurve](./ProgressiveCurve.md)**: Alternative progressive pricing model
- **[OffsetProgressiveCurve](./OffsetProgressiveCurve.md)**: Progressive curve with offset

### Core Integration
- **[MultiVault](../core/MultiVault.md)**: Uses LinearCurve for vault pricing
- **[MultiVaultCore](../core/MultiVaultCore.md)**: Stores bonding curve configuration

### Libraries
- **FixedPointMathLib** (Solady): Used for `fullMulDiv` and `fullMulDivUp` operations

## See Also

### Concept Documentation
- [Bonding Curves](../../concepts/bonding-curves.md) - Understanding pricing mechanisms
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - How curves enable multiple vaults

### Integration Guides
- [Creating Atoms](../../guides/creating-atoms.md) - Choosing LinearCurve for atoms
- [Creating Triples](../../guides/creating-triples.md) - Choosing LinearCurve for triples
- [Depositing Assets](../../guides/depositing-assets.md) - Depositing to LinearCurve vaults
- [Fee Structure](../../guides/fee-structure.md) - How fees increase LinearCurve share value

### Reference
- [Mathematical Formulas](../../reference/mathematical-formulas.md) - Detailed curve mathematics
- [Gas Benchmarks](../../reference/gas-benchmarks.md) - Gas cost comparisons

---

**Last Updated**: December 2025
**Version**: V2.0
**Curve ID**: 1
