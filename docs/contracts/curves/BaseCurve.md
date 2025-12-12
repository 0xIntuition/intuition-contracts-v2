# BaseCurve

## Overview

The **BaseCurve** contract is the abstract foundation for all bonding curves in the Intuition Protocol V2. It defines the standard interface and common functionality that all bonding curve implementations must follow, ensuring consistent behavior across different pricing models. The contract provides pure mathematical relationships for converting between assets and shares, while the MultiVault handles pool ratio adjustments for fees, supply burns, and other economic factors.

### Purpose and Role in Protocol

- **Abstract Interface**: Defines the common interface that all bonding curves must implement
- **Mathematical Foundation**: Provides the pure mathematical relationship between assets and shares
- **Validation Layer**: Implements safety checks for bounds and domain validation
- **Extensibility**: Enables the protocol to support multiple pricing mechanisms through inheritance
- **Curve Registry Integration**: Works with BondingCurveRegistry for curve management and routing

### Key Responsibilities

1. **Conversion Functions**: Convert between assets and shares in both directions
2. **Preview Functions**: Simulate operations without executing them
3. **Price Calculation**: Calculate current share prices based on vault state
4. **Bounds Checking**: Validate that operations stay within curve limits
5. **Name Management**: Store and expose unique curve identifiers

## Contract Information

- **Location**: `src/protocol/curves/BaseCurve.sol`
- **Type**: Abstract Contract
- **Inherits**:
  - `IBaseCurve` (interface)
  - `Initializable` (OpenZeppelin upgradeable base)
- **Interface**: `IBaseCurve` (`src/interfaces/IBaseCurve.sol`)
- **Upgradeable**: Yes (for derived contracts)
- **Implementations**: LinearCurve, ProgressiveCurve, OffsetProgressiveCurve

### Network Deployments

BaseCurve itself is not deployed as it's an abstract contract. See individual curve implementations:
- [LinearCurve](./LinearCurve.md)
- [ProgressiveCurve](./ProgressiveCurve.md)
- [OffsetProgressiveCurve](./OffsetProgressiveCurve.md)

## Key Concepts

### Pure Mathematical Relationship

The BaseCurve focuses solely on the mathematical pricing relationship:
- **Assets to Shares**: Given a deposit amount, calculate shares to mint
- **Shares to Assets**: Given shares to redeem, calculate assets to return
- **Current Price**: Calculate the marginal price of one share

The curve does NOT handle:
- Fee calculations (handled by MultiVault)
- Vault state management (handled by MultiVault)
- Pool ratio adjustments (handled by MultiVault)
- Utilization tracking (handled by MultiVault)

### Rounding Behavior

Functions implement specific rounding behavior to protect the protocol:
- **Rounding DOWN** (favors protocol):
  - `previewDeposit`: Shares minted for assets deposited
  - `previewRedeem`: Assets returned for shares redeemed
  - `convertToShares`: Share equivalents for assets
  - `convertToAssets`: Asset equivalents for shares

- **Rounding UP** (favors protocol):
  - `previewMint`: Assets required to mint specific shares
  - `previewWithdraw`: Shares needed to withdraw specific assets

### Maximum Limits

Each curve implementation defines maximum values to prevent overflow:
- **MAX_SHARES**: Maximum total shares the curve can handle
- **MAX_ASSETS**: Maximum total assets the curve can handle

These limits are calculated during initialization based on the curve's mathematical properties and prevent arithmetic overflow in calculations.

### Domain Validation

All curve operations validate that:
1. Current vault state (totalAssets, totalShares) is within curve limits
2. Requested operation doesn't exceed maximum bounds
3. Output values after operation remain within limits

## State Variables

### Immutable Storage

```solidity
/// @notice The name of the curve
string public name;
```

- **name**: Unique identifier for the curve
- **Set during**: Initialization via `__BaseCurve_init`
- **Immutable**: Cannot be changed after initialization
- **Purpose**: Used by BondingCurveRegistry for curve identification

## Functions

### Abstract Functions (Must Be Implemented)

#### `maxShares`
```solidity
function maxShares() external view virtual returns (uint256)
```
Returns the maximum number of shares the curve can handle.

**Returns**: Maximum shares limit

**Implementation Required**: Each curve must calculate this based on its mathematical properties.

---

#### `maxAssets`
```solidity
function maxAssets() external view virtual returns (uint256)
```
Returns the maximum number of assets the curve can handle.

**Returns**: Maximum assets limit

**Implementation Required**: Each curve must calculate this based on its mathematical properties.

---

### Preview Functions

#### `previewDeposit`
```solidity
function previewDeposit(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view virtual returns (uint256 shares)
```
Previews how many shares would be minted for depositing assets.

**Parameters**:
- `assets`: Amount of assets to deposit
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Number of shares that would be minted

**Rounding**: Always rounds DOWN (favors protocol)

**Use Case**: Calculate expected shares before deposit

---

#### `previewMint`
```solidity
function previewMint(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view virtual returns (uint256 assets)
```
Previews how many assets are required to mint specific shares.

**Parameters**:
- `shares`: Number of shares to mint
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Amount of assets required

**Rounding**: Always rounds UP (favors protocol)

**Use Case**: Calculate assets needed for desired share amount

---

#### `previewWithdraw`
```solidity
function previewWithdraw(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view virtual returns (uint256 shares)
```
Previews how many shares would be redeemed to withdraw assets.

**Parameters**:
- `assets`: Amount of assets to withdraw
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Number of shares that would need to be redeemed

**Rounding**: Always rounds UP (favors protocol)

**Use Case**: Calculate shares needed for desired asset withdrawal

---

#### `previewRedeem`
```solidity
function previewRedeem(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view virtual returns (uint256 assets)
```
Previews how many assets would be returned for redeeming shares.

**Parameters**:
- `shares`: Number of shares to redeem
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Amount of assets that would be returned

**Rounding**: Always rounds DOWN (favors protocol)

**Use Case**: Calculate expected assets before redemption

---

### Conversion Functions

#### `convertToShares`
```solidity
function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) external view virtual returns (uint256 shares)
```
Converts assets to equivalent shares at current vault state.

**Parameters**:
- `assets`: Amount of assets to convert
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault

**Returns**: Equivalent number of shares

**Rounding**: Always rounds DOWN

**Difference from previewDeposit**: Represents exchange rate without considering deposit flow

---

#### `convertToAssets`
```solidity
function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets
) external view virtual returns (uint256 assets)
```
Converts shares to equivalent assets at current vault state.

**Parameters**:
- `shares`: Number of shares to convert
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Equivalent amount of assets

**Rounding**: Always rounds DOWN

**Difference from previewRedeem**: Represents exchange rate without considering redemption flow

---

### Price Functions

#### `currentPrice`
```solidity
function currentPrice(
    uint256 totalShares,
    uint256 totalAssets
) external view virtual returns (uint256 sharePrice)
```
Returns the current price of one share.

**Parameters**:
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Current share price (scaled by 1e18)

**Use Case**: Monitor share price changes over time

---

### Initialization

#### `__BaseCurve_init`
```solidity
function __BaseCurve_init(string memory _name) internal onlyInitializing
```
Internal initializer called by derived contracts.

**Parameters**:
- `_name`: Unique name for the curve

**Emits**: `CurveNameSet`

**Requirements**:
- Name must not be empty
- Called only during initialization

---

## Events

### `CurveNameSet`
```solidity
event CurveNameSet(string name)
```
Emitted when the curve name is set during initialization.

**Parameters**:
- `name`: The unique name of the curve

**Use Cases**:
- Track curve deployment
- Verify correct initialization
- Audit curve registry additions

---

## Errors

### `BaseCurve_EmptyStringNotAllowed`
Thrown when attempting to initialize with an empty curve name.

**Recovery**: Provide a non-empty curve name

---

### `BaseCurve_AssetsExceedTotalAssets`
Thrown in `previewWithdraw` when requested assets exceed total assets in vault.

**Recovery**: Reduce withdrawal amount to available total assets

---

### `BaseCurve_SharesExceedTotalShares`
Thrown in redemption operations when shares exceed total shares in vault.

**Recovery**: Reduce share amount to available balance

---

### `BaseCurve_AssetsOverflowMax`
Thrown when an operation would cause total assets to exceed the curve's maximum limit.

**Recovery**:
- Reduce operation size
- Use a different bonding curve with higher limits

---

### `BaseCurve_SharesOverflowMax`
Thrown when an operation would cause total shares to exceed the curve's maximum limit.

**Recovery**:
- Reduce operation size
- Use a different bonding curve with higher limits

---

### `BaseCurve_DomainExceeded`
Thrown when current vault state (totalAssets or totalShares) exceeds curve limits.

**Recovery**: This indicates a protocol state issue; contact support

---

## Internal Helper Functions

### Validation Functions

#### `_checkWithdraw`
```solidity
function _checkWithdraw(uint256 assets, uint256 totalAssets) internal pure
```
Validates that withdrawal amount doesn't exceed total assets.

**Reverts**: `BaseCurve_AssetsExceedTotalAssets` if assets > totalAssets

---

#### `_checkRedeem`
```solidity
function _checkRedeem(uint256 shares, uint256 totalShares) internal pure
```
Validates that redemption amount doesn't exceed total shares.

**Reverts**: `BaseCurve_SharesExceedTotalShares` if shares > totalShares

---

#### `_checkDepositBounds`
```solidity
function _checkDepositBounds(uint256 assets, uint256 totalAssets, uint256 maxAssetsCap) internal pure
```
Validates that deposit won't cause assets to exceed maximum.

**Reverts**: `BaseCurve_AssetsOverflowMax` if assets + totalAssets > maxAssetsCap

---

#### `_checkDepositOut`
```solidity
function _checkDepositOut(uint256 sharesOut, uint256 totalShares, uint256 maxSharesCap) internal pure
```
Validates that deposit output won't cause shares to exceed maximum.

**Reverts**: `BaseCurve_SharesOverflowMax` if sharesOut + totalShares > maxSharesCap

---

#### `_checkMintBounds`
```solidity
function _checkMintBounds(uint256 shares, uint256 totalShares, uint256 maxSharesCap) internal pure
```
Validates that mint operation won't exceed share maximum.

**Reverts**: `BaseCurve_SharesOverflowMax` if shares + totalShares > maxSharesCap

---

#### `_checkMintOut`
```solidity
function _checkMintOut(uint256 assetsOut, uint256 totalAssets, uint256 maxAssetsCap) internal pure
```
Validates that mint operation won't exceed asset maximum.

**Reverts**: `BaseCurve_AssetsOverflowMax` if assetsOut + totalAssets > maxAssetsCap

---

#### `_checkCurveDomains`
```solidity
function _checkCurveDomains(
    uint256 totalAssets,
    uint256 totalShares,
    uint256 maxAssetsCap,
    uint256 maxSharesCap
) internal pure
```
Validates that current vault state is within curve limits.

**Reverts**: `BaseCurve_DomainExceeded` if totalAssets > maxAssetsCap OR totalShares > maxSharesCap

---

## Integration Notes

### For Curve Implementers

When creating a new bonding curve:

1. **Inherit from BaseCurve**: Your contract should extend BaseCurve
2. **Implement Abstract Functions**: Must implement all virtual functions
3. **Calculate MAX values**: Determine safe maximum shares and assets based on your math
4. **Use Helper Functions**: Utilize provided validation helpers for safety
5. **Follow Rounding**: Maintain consistent rounding behavior (see Rounding Behavior section)

Example:
```solidity
contract MyCustomCurve is BaseCurve {
    uint256 public constant MAX_SHARES = /* calculated value */;
    uint256 public constant MAX_ASSETS = /* calculated value */;

    function initialize(string calldata _name) external initializer {
        __BaseCurve_init(_name);
        // additional initialization
    }

    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    // ... implement other required functions
}
```

### For MultiVault Integration

The MultiVault interacts with curves through the BondingCurveRegistry:

1. **Curve Selection**: Each vault is associated with a specific curve ID
2. **State Passing**: MultiVault passes current totalAssets and totalShares
3. **Result Usage**: MultiVault uses curve results for share minting/burning
4. **Fee Application**: MultiVault applies fees AFTER getting curve results

### Common Patterns

#### Querying Share Price
```typescript
// Get vault state
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Get current price from curve
const price = await bondingCurveRegistry.currentPrice(
    curveId,
    totalShares,
    totalAssets
);

console.log(`Share price: ${formatEther(price)} TRUST per share`);
```

#### Simulating Deposit
```typescript
// Get current vault state
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Preview shares from curve
const shares = await bondingCurveRegistry.previewDeposit(
    depositAmount,
    totalAssets,
    totalShares,
    curveId
);

console.log(`Expected shares: ${formatEther(shares)}`);
```

### Edge Cases

1. **Empty Vault**: When totalShares = 0, curves typically return 1:1 conversion
2. **First Deposit**: MultiVault burns minimum shares to prevent inflation attacks
3. **Maximum Limits**: Operations near MAX_SHARES or MAX_ASSETS may fail
4. **Precision**: All calculations use 18 decimal precision

## Usage Examples

### TypeScript (viem)

#### Querying Curve Information

```typescript
import { createPublicClient, http, formatEther } from 'viem';
import { intuition } from 'viem/chains';

// Setup
const publicClient = createPublicClient({
  chain: intuition,
  transport: http()
});

const registryAddress = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930';
const multiVaultAddress = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';

const registryAbi = [
  {
    name: 'getCurveName',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'uint256' }],
    outputs: [{ name: '', type: 'string' }]
  },
  {
    name: 'getCurveMaxShares',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'getCurveMaxAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
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
    outputs: [{ name: '', type: 'uint256' }]
  }
] as const;

const multiVaultAbi = [
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

async function getCurveInfo(curveId: number) {
  try {
    // Get curve metadata
    const name = await publicClient.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: 'getCurveName',
      args: [BigInt(curveId)]
    });

    const maxShares = await publicClient.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: 'getCurveMaxShares',
      args: [BigInt(curveId)]
    });

    const maxAssets = await publicClient.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: 'getCurveMaxAssets',
      args: [BigInt(curveId)]
    });

    console.log(`Curve ${curveId}: ${name}`);
    console.log(`Max Shares: ${formatEther(maxShares)}`);
    console.log(`Max Assets: ${formatEther(maxAssets)}`);

    return { name, maxShares, maxAssets };
  } catch (error) {
    console.error('Error fetching curve info:', error);
    throw error;
  }
}

// Query curve 1 (Linear)
getCurveInfo(1);
```

#### Simulating Operations

```typescript
async function simulateDeposit(
  termId: `0x${string}`,
  curveId: number,
  depositAmount: bigint
) {
  try {
    // Get current vault state
    const vault = await publicClient.readContract({
      address: multiVaultAddress,
      abi: multiVaultAbi,
      functionName: 'getVault',
      args: [termId, BigInt(curveId)]
    });

    const [totalAssets, totalShares] = vault;

    console.log(`Current State:`);
    console.log(`  Total Assets: ${formatEther(totalAssets)}`);
    console.log(`  Total Shares: ${formatEther(totalShares)}`);

    // Preview deposit through registry
    const expectedShares = await publicClient.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: 'previewDeposit',
      args: [depositAmount, totalAssets, totalShares, BigInt(curveId)]
    });

    console.log(`\nDeposit Simulation:`);
    console.log(`  Deposit Amount: ${formatEther(depositAmount)}`);
    console.log(`  Expected Shares: ${formatEther(expectedShares)}`);

    // Calculate implied price
    const impliedPrice = (depositAmount * parseEther('1')) / expectedShares;
    console.log(`  Implied Price: ${formatEther(impliedPrice)} TRUST/share`);

    // Get current marginal price
    const currentPrice = await publicClient.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: 'currentPrice',
      args: [BigInt(curveId), totalShares, totalAssets]
    });
    console.log(`  Current Price: ${formatEther(currentPrice)} TRUST/share`);

    return expectedShares;
  } catch (error) {
    console.error('Error simulating deposit:', error);
    throw error;
  }
}
```

### Python (web3.py)

```python
from web3 import Web3
import json

# Setup
w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
registry_address = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930'
multivault_address = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

# Load ABIs
with open('BondingCurveRegistry.json') as f:
    registry_abi = json.load(f)['abi']

with open('MultiVault.json') as f:
    multivault_abi = json.load(f)['abi']

registry = w3.eth.contract(address=registry_address, abi=registry_abi)
multivault = w3.eth.contract(address=multivault_address, abi=multivault_abi)

def compare_curves(term_id: bytes, curve_ids: list, deposit_amount: int):
    """Compare how different curves price the same deposit"""

    print(f'Comparing curves for {w3.from_wei(deposit_amount, "ether")} TRUST deposit\n')

    for curve_id in curve_ids:
        # Get curve name
        curve_name = registry.functions.getCurveName(curve_id).call()

        # Get vault state
        total_assets, total_shares = multivault.functions.getVault(
            term_id,
            curve_id
        ).call()

        # Preview deposit
        shares = registry.functions.previewDeposit(
            deposit_amount,
            total_assets,
            total_shares,
            curve_id
        ).call()

        # Get current price
        price = registry.functions.currentPrice(
            curve_id,
            total_shares,
            total_assets
        ).call()

        print(f'{curve_name} (ID: {curve_id}):')
        print(f'  Shares: {w3.from_wei(shares, "ether")}')
        print(f'  Price: {w3.from_wei(price, "ether")} TRUST/share')
        print(f'  Vault: {w3.from_wei(total_assets, "ether")} assets, {w3.from_wei(total_shares, "ether")} shares\n')

# Example: Compare Linear vs Offset Progressive
compare_curves(
    bytes.fromhex('1234...'),  # term ID
    [1, 2],  # curve IDs
    w3.to_wei(100, 'ether')
)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBondingCurveRegistry.sol";
import "./interfaces/IMultiVault.sol";

/**
 * @title CurvePriceOracle
 * @notice Example contract that uses curve pricing for external logic
 */
contract CurvePriceOracle {
    IBondingCurveRegistry public immutable curveRegistry;
    IMultiVault public immutable multiVault;

    constructor(address _registry, address _multiVault) {
        curveRegistry = IBondingCurveRegistry(_registry);
        multiVault = IMultiVault(_multiVault);
    }

    /**
     * @notice Get the current share price for a vault
     * @param termId The term (atom/triple) ID
     * @param curveId The curve ID
     * @return price Current share price (18 decimals)
     */
    function getSharePrice(
        bytes32 termId,
        uint256 curveId
    ) external view returns (uint256 price) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, curveId);

        price = curveRegistry.currentPrice(
            curveId,
            totalShares,
            totalAssets
        );
    }

    /**
     * @notice Calculate deposit impact on price
     * @param termId The term ID
     * @param curveId The curve ID
     * @param depositAmount Amount to deposit
     * @return priceBefore Price before deposit
     * @return priceAfter Price after deposit
     * @return priceImpact Percentage impact (18 decimals, 1e18 = 100%)
     */
    function calculatePriceImpact(
        bytes32 termId,
        uint256 curveId,
        uint256 depositAmount
    ) external view returns (
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 priceImpact
    ) {
        (uint256 totalAssets, uint256 totalShares) =
            multiVault.getVault(termId, curveId);

        // Price before
        priceBefore = curveRegistry.currentPrice(
            curveId,
            totalShares,
            totalAssets
        );

        // Simulate deposit
        uint256 sharesMinted = curveRegistry.previewDeposit(
            depositAmount,
            totalAssets,
            totalShares,
            curveId
        );

        // Price after
        priceAfter = curveRegistry.currentPrice(
            curveId,
            totalShares + sharesMinted,
            totalAssets + depositAmount
        );

        // Calculate impact (percentage)
        if (priceBefore > 0) {
            priceImpact = ((priceAfter - priceBefore) * 1e18) / priceBefore;
        }
    }
}
```

## Gas Considerations

### Read Operations (View Functions)

All BaseCurve functions are view functions that don't modify state:

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| `maxShares` / `maxAssets` | O(1) | Returns constant values |
| `currentPrice` | O(1) | Simple calculation |
| `convertToShares` / `convertToAssets` | O(1) | Proportional math |
| Preview functions | O(1) | Curve-specific math |

### Optimization Tips

1. **Batch Queries**: Use multicall to fetch multiple curve parameters
2. **Cache Results**: Cache curve limits and names (they don't change)
3. **Off-Chain Preview**: Perform previews off-chain when possible
4. **Curve Selection**: Choose simpler curves (Linear) for lower gas operations

## Related Contracts

### Curve Implementations
- **[LinearCurve](./LinearCurve.md)**: Constant price curve (1:1 ratio)
- **[ProgressiveCurve](./ProgressiveCurve.md)**: Increasing price curve
- **[OffsetProgressiveCurve](./OffsetProgressiveCurve.md)**: Progressive with offset

### Supporting Contracts
- **[BondingCurveRegistry](./BondingCurveRegistry.md)**: Manages curve registration and routing
- **[MultiVault](../core/MultiVault.md)**: Uses curves for vault pricing
- **[ProgressiveCurveMathLib](../../reference/mathematical-formulas.md)**: Math library for progressive curves

## See Also

### Concept Documentation
- [Bonding Curves](../../concepts/bonding-curves.md) - Understanding pricing mechanisms
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - How curves integrate with vaults

### Reference
- [Mathematical Formulas](../../reference/mathematical-formulas.md) - Curve math explained
- [Data Structures](../../reference/data-structures.md) - Curve-related structs

---

**Last Updated**: December 2025
**Version**: V2.0
