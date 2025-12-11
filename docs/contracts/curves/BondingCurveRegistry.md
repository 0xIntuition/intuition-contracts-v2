# BondingCurveRegistry

## Overview

The **BondingCurveRegistry** contract serves as the central registry and router for all bonding curves in the Intuition Protocol V2. It acts as a concierge between the MultiVault and various bonding curve implementations, managing curve registration, assignment of unique IDs, and routing of pricing calculations. The registry enables the protocol to support multiple pricing mechanisms while maintaining a clean, consistent interface for vault operations.

### Purpose and Role in Protocol

- **Curve Management Hub**: Centralized registry of all approved bonding curves
- **Routing Layer**: Routes pricing calculations to appropriate curve implementations
- **ID Assignment**: Assigns unique sequential IDs to registered curves
- **Name Enforcement**: Ensures unique curve names across the protocol
- **Access Control**: Manages which curves can be added to the registry
- **Stateless Calculator**: Performs computations without maintaining economic state

### Key Responsibilities

1. **Curve Registration**: Add new bonding curves to the protocol
2. **ID Management**: Assign and track unique curve IDs
3. **Name Validation**: Enforce curve name uniqueness
4. **Calculation Routing**: Route MultiVault requests to appropriate curves
5. **Metadata Access**: Provide curve information (name, limits, etc.)
6. **State Validation**: Ensure curve IDs are valid before operations

## Contract Information

- **Location**: `src/protocol/curves/BondingCurveRegistry.sol`
- **Inherits**:
  - `IBondingCurveRegistry` (interface)
  - `Ownable2StepUpgradeable` (access control)
- **Interface**: `IBondingCurveRegistry` (`src/interfaces/IBondingCurveRegistry.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Intuition Mainnet
- **Address**: [`0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930`](https://explorer.intuit.network/address/0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930)
- **ProxyAdmin**: `0x678c7D3d759611b554A1293295007f2b202C2302`

#### Intuition Testnet
- **Address**: [`0x2AFC4949Dd3664219AA2c20133771658E93892A1`](https://explorer.testnet.intuit.network/address/0x2AFC4949Dd3664219AA2c20133771658E93892A1)
- **ProxyAdmin**: `0x0C5AeAba37b1E92064f0af684D65476d24F52a9A`

#### Registered Curves

| Curve ID | Name | Type | Mainnet Address | Testnet Address |
|----------|------|------|-----------------|-----------------|
| 1 | LinearCurve | Constant pricing | [`0xc3eFD5471dc63d74639725f381f9686e3F264366`](https://explorer.intuit.network/address/0xc3eFD5471dc63d74639725f381f9686e3F264366) | [`0x6df5eecd9B14E31C98A027b8634876E4805F71B0`](https://explorer.testnet.intuit.network/address/0x6df5eecd9B14E31C98A027b8634876E4805F71B0) |
| 2 | OffsetProgressiveCurve | Progressive pricing | [`0x23afF95153aa88D28B9B97Ba97629E05D5fD335d`](https://explorer.intuit.network/address/0x23afF95153aa88D28B9B97Ba97629E05D5fD335d) | [`0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB`](https://explorer.testnet.intuit.network/address/0xE65EcaAF5964aC0d94459A66A59A8B9eBCE42CbB) |

## Key Concepts

### Registry Pattern

The BondingCurveRegistry implements a registry pattern that separates concerns:
- **Registry**: Manages curve addresses and IDs
- **Router**: Forwards calculations to appropriate curves
- **Validator**: Ensures valid curve IDs before operations

This pattern enables:
- Adding new curves without modifying MultiVault
- Economic experimentation with different pricing models
- User choice in selecting pricing mechanisms

### Stateless Design

The registry does NOT maintain any economic state:
- No vault balances
- No share totals
- No fee tracking

Instead, it:
- Receives state as parameters
- Routes to appropriate curve
- Returns calculated results

All state management is handled by MultiVault.

### Curve ID System

Curve IDs are assigned sequentially:
- **ID 0**: Reserved (indicates uninitialized/invalid)
- **ID 1+**: Valid curve IDs assigned in registration order

IDs are permanent and cannot be reassigned or reused.

### Name Uniqueness

Each curve must have a unique name:
- Names are case-sensitive
- Enforced during registration
- Prevents confusion between curves
- Enables human-readable curve identification

## State Variables

### Core State

```solidity
/// @notice Quantity of known curves, used to assign IDs
uint256 public count;

/// @notice Mapping of curve IDs to curve addresses
mapping(uint256 curveId => address curveAddress) public curveAddresses;

/// @notice Mapping of curve addresses to curve IDs (reverse lookup)
mapping(address curveAddress => uint256 curveId) public curveIds;

/// @notice Mapping of registered curve names for uniqueness enforcement
mapping(string curveName => bool registered) public registeredCurveNames;
```

**count**: Total number of registered curves, also serves as the next ID to assign

**curveAddresses**: Forward lookup from ID to address

**curveIds**: Reverse lookup from address to ID

**registeredCurveNames**: Tracks which names are taken

## Functions

### Admin Functions

#### `addBondingCurve`
```solidity
function addBondingCurve(address bondingCurve) external onlyOwner
```
Adds a new bonding curve to the registry.

**Parameters**:
- `bondingCurve`: Address of the curve contract to add

**Emits**: `BondingCurveAdded`

**Access**: `onlyOwner`

**Requirements**:
- Curve address must not be zero
- Curve must not already be registered
- Curve name must not be empty
- Curve name must be unique

**Effect**:
- Increments count
- Assigns new curve ID
- Stores address mappings
- Marks name as registered

**Gas**: ~100,000

---

### Read Functions (Curve Calculations)

#### `previewDeposit`
```solidity
function previewDeposit(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares,
    uint256 id
) external view returns (uint256 shares)
```
Previews shares to be minted for a deposit.

**Parameters**:
- `assets`: Amount of assets to deposit
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault
- `id`: Curve ID to use

**Returns**: Number of shares that would be minted

**Requirements**: Valid curve ID

**Use Case**: Calculate expected shares before deposit

---

#### `previewRedeem`
```solidity
function previewRedeem(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets,
    uint256 id
) external view returns (uint256 assets)
```
Previews assets to be returned for redemption.

**Parameters**:
- `shares`: Number of shares to redeem
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault
- `id`: Curve ID to use

**Returns**: Amount of assets that would be returned

**Requirements**: Valid curve ID

**Use Case**: Calculate expected assets before redemption

---

#### `previewMint`
```solidity
function previewMint(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets,
    uint256 id
) external view returns (uint256 assets)
```
Previews assets required to mint specific shares.

**Parameters**:
- `shares`: Number of shares to mint
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault
- `id`: Curve ID to use

**Returns**: Amount of assets required

**Requirements**: Valid curve ID

**Use Case**: Calculate cost for desired share amount

---

#### `previewWithdraw`
```solidity
function previewWithdraw(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares,
    uint256 id
) external view returns (uint256 shares)
```
Previews shares needed to withdraw specific assets.

**Parameters**:
- `assets`: Amount of assets to withdraw
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault
- `id`: Curve ID to use

**Returns**: Number of shares required

**Requirements**: Valid curve ID

**Use Case**: Calculate shares needed for desired withdrawal

---

#### `convertToShares`
```solidity
function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares,
    uint256 id
) external view returns (uint256 shares)
```
Converts assets to shares at current rate.

**Parameters**:
- `assets`: Amount of assets to convert
- `totalAssets`: Current total assets in vault
- `totalShares`: Current total shares in vault
- `id`: Curve ID to use

**Returns**: Equivalent shares

**Requirements**: Valid curve ID

---

#### `convertToAssets`
```solidity
function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets,
    uint256 id
) external view returns (uint256 assets)
```
Converts shares to assets at current rate.

**Parameters**:
- `shares`: Number of shares to convert
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault
- `id`: Curve ID to use

**Returns**: Equivalent assets

**Requirements**: Valid curve ID

---

#### `currentPrice`
```solidity
function currentPrice(
    uint256 id,
    uint256 totalShares,
    uint256 totalAssets
) external view returns (uint256 sharePrice)
```
Returns current share price for a curve.

**Parameters**:
- `id`: Curve ID to query
- `totalShares`: Current total shares in vault
- `totalAssets`: Current total assets in vault

**Returns**: Current share price (scaled by 1e18)

**Requirements**: Valid curve ID

---

### Read Functions (Curve Metadata)

#### `getCurveName`
```solidity
function getCurveName(uint256 id) external view returns (string memory name)
```
Returns the name of a curve.

**Parameters**:
- `id`: Curve ID to query

**Returns**: Curve name

**Requirements**: Valid curve ID

---

#### `getCurveMaxShares`
```solidity
function getCurveMaxShares(uint256 id) external view returns (uint256 maxShares)
```
Returns maximum shares a curve can handle.

**Parameters**:
- `id`: Curve ID to query

**Returns**: Maximum shares limit

**Requirements**: Valid curve ID

---

#### `getCurveMaxAssets`
```solidity
function getCurveMaxAssets(uint256 id) external view returns (uint256 maxAssets)
```
Returns maximum assets a curve can handle.

**Parameters**:
- `id`: Curve ID to query

**Returns**: Maximum assets limit

**Requirements**: Valid curve ID

---

#### `isCurveIdValid`
```solidity
function isCurveIdValid(uint256 id) external view returns (bool valid)
```
Checks if a curve ID is valid.

**Parameters**:
- `id`: Curve ID to check

**Returns**: True if valid, false otherwise

**Logic**: `id > 0 && id <= count`

---

## Events

### `BondingCurveAdded`
```solidity
event BondingCurveAdded(
    uint256 indexed curveId,
    address indexed curveAddress,
    string indexed curveName
)
```
Emitted when a new curve is added to the registry.

**Parameters**:
- `curveId`: ID assigned to the curve
- `curveAddress`: Address of the curve contract
- `curveName`: Unique name of the curve

**Use Cases**:
- Track curve additions
- Index available curves
- Monitor registry updates
- Audit curve deployments

---

## Errors

### `BondingCurveRegistry_ZeroAddress`
Thrown when attempting to add a curve with zero address.

**Recovery**: Provide valid curve contract address

---

### `BondingCurveRegistry_CurveAlreadyExists`
Thrown when attempting to add a curve that's already registered.

**Recovery**: Use existing curve ID or deploy new curve contract

---

### `BondingCurveRegistry_EmptyCurveName`
Thrown when curve returns empty name.

**Recovery**: Ensure curve contract implements name() correctly

---

### `BondingCurveRegistry_CurveNameNotUnique`
Thrown when curve name is already registered.

**Recovery**: Deploy curve with unique name

---

### `BondingCurveRegistry_InvalidCurveId`
Thrown when using invalid curve ID (0 or > count).

**Recovery**: Use valid curve ID (1 to count)

---

## Access Control

### Owner Role

The contract uses OpenZeppelin's `Ownable2StepUpgradeable`:

**Owner Capabilities**:
- Add new bonding curves
- Transfer ownership (2-step process)

**Initial Owner**: Set during initialization

**Transfer Process**:
1. Current owner calls `transferOwnership(newOwner)`
2. New owner calls `acceptOwnership()`

### Permission Structure

```
Owner
  └─ addBondingCurve()
     ├─ Validate curve address
     ├─ Check name uniqueness
     ├─ Assign ID
     └─ Register curve
```

## Usage Examples

### TypeScript (ethers.js v6)

#### Querying Available Curves

```typescript
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('YOUR_INTUITION_RPC');
const registryAddress = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930';

const registryABI = [
  'function count() external view returns (uint256)',
  'function getCurveName(uint256 id) external view returns (string memory)',
  'function getCurveMaxShares(uint256 id) external view returns (uint256)',
  'function getCurveMaxAssets(uint256 id) external view returns (uint256)',
  'function curveAddresses(uint256 id) external view returns (address)'
];

const registry = new ethers.Contract(registryAddress, registryABI, provider);

async function listAllCurves() {
  try {
    const curveCount = await registry.count();
    console.log(`Total registered curves: ${curveCount}\n`);

    for (let id = 1; id <= curveCount; id++) {
      const name = await registry.getCurveName(id);
      const address = await registry.curveAddresses(id);
      const maxShares = await registry.getCurveMaxShares(id);
      const maxAssets = await registry.getCurveMaxAssets(id);

      console.log(`Curve ID ${id}: ${name}`);
      console.log(`  Address: ${address}`);
      console.log(`  Max Shares: ${ethers.formatEther(maxShares)}`);
      console.log(`  Max Assets: ${ethers.formatEther(maxAssets)}\n`);
    }
  } catch (error) {
    console.error('Error listing curves:', error);
    throw error;
  }
}

listAllCurves();
```

#### Comparing Curve Pricing

```typescript
async function compareCurvePricing(
  totalAssets: bigint,
  totalShares: bigint,
  depositAmount: bigint
) {
  try {
    const curveCount = await registry.count();

    console.log('Comparing curves for deposit:\n');
    console.log(`Deposit Amount: ${ethers.formatEther(depositAmount)} TRUST`);
    console.log(`Vault State: ${ethers.formatEther(totalAssets)} assets, ${ethers.formatEther(totalShares)} shares\n`);

    for (let id = 1; id <= curveCount; id++) {
      const name = await registry.getCurveName(id);

      // Preview deposit
      const shares = await registry.previewDeposit(
        depositAmount,
        totalAssets,
        totalShares,
        id
      );

      // Get current price
      const price = await registry.currentPrice(
        id,
        totalShares,
        totalAssets
      );

      // Calculate average price
      const avgPrice = depositAmount * ethers.parseEther('1') / shares;

      console.log(`${name}:`);
      console.log(`  Shares received: ${ethers.formatEther(shares)}`);
      console.log(`  Current price: ${ethers.formatEther(price)} TRUST/share`);
      console.log(`  Average price: ${ethers.formatEther(avgPrice)} TRUST/share`);
      console.log(`  Price difference: ${((avgPrice - price) * 100n / price)}%\n`);
    }
  } catch (error) {
    console.error('Error comparing curves:', error);
    throw error;
  }
}

// Example: Compare with 10 TRUST deposit
compareCurvePricing(
  ethers.parseEther('1000'),  // 1000 TRUST in vault
  ethers.parseEther('500'),   // 500 shares outstanding
  ethers.parseEther('10')     // 10 TRUST deposit
);
```

#### Adding a New Curve (Owner Only)

```typescript
async function addNewCurve(curveAddress: string) {
  const signer = new ethers.Wallet('OWNER_PRIVATE_KEY', provider);
  const registryWithSigner = registry.connect(signer);

  try {
    console.log(`Adding curve at ${curveAddress}...`);

    // Add the curve
    const tx = await registryWithSigner.addBondingCurve(curveAddress);
    console.log(`Transaction hash: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`Curve added in block ${receipt.blockNumber}`);

    // Parse event to get curve ID
    const event = receipt.logs.find(
      log => log.topics[0] === ethers.id('BondingCurveAdded(uint256,address,string)')
    );

    if (event) {
      const decoded = registry.interface.parseLog(event);
      console.log(`Curve ID: ${decoded.args.curveId}`);
      console.log(`Curve Name: ${decoded.args.curveName}`);
    }

    return receipt;
  } catch (error) {
    console.error('Error adding curve:', error);
    throw error;
  }
}
```

### Python (web3.py)

```python
from web3 import Web3
import json

w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
registry_address = '0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930'

with open('BondingCurveRegistry.json') as f:
    registry_abi = json.load(f)['abi']

registry = w3.eth.contract(address=registry_address, abi=registry_abi)

def analyze_curve_sensitivity(
    curve_id: int,
    base_assets: int,
    base_shares: int,
    deposit_range: list
):
    """Analyze how a curve responds to different deposit sizes"""

    curve_name = registry.functions.getCurveName(curve_id).call()

    print(f'Sensitivity Analysis for {curve_name}\n')
    print(f'Base state: {w3.from_wei(base_assets, "ether")} assets, {w3.from_wei(base_shares, "ether")} shares\n')

    results = []

    for deposit in deposit_range:
        # Calculate shares
        shares = registry.functions.previewDeposit(
            deposit,
            base_assets,
            base_shares,
            curve_id
        ).call()

        # Calculate price
        price = registry.functions.currentPrice(
            curve_id,
            base_shares,
            base_assets
        ).call()

        # Calculate new price after deposit
        new_price = registry.functions.currentPrice(
            curve_id,
            base_shares + shares,
            base_assets + deposit
        ).call()

        results.append({
            'deposit': w3.from_wei(deposit, 'ether'),
            'shares': w3.from_wei(shares, 'ether'),
            'price_before': w3.from_wei(price, 'ether'),
            'price_after': w3.from_wei(new_price, 'ether'),
            'price_impact': ((new_price - price) * 100 / price) if price > 0 else 0
        })

    # Print results
    for r in results:
        print(f"Deposit: {r['deposit']} TRUST")
        print(f"  Shares: {r['shares']}")
        print(f"  Price: {r['price_before']} -> {r['price_after']}")
        print(f"  Impact: {r['price_impact']:.2f}%\n")

    return results

# Example usage
analyze_curve_sensitivity(
    curve_id=1,
    base_assets=w3.to_wei(1000, 'ether'),
    base_shares=w3.to_wei(500, 'ether'),
    deposit_range=[
        w3.to_wei(10, 'ether'),
        w3.to_wei(50, 'ether'),
        w3.to_wei(100, 'ether'),
        w3.to_wei(500, 'ether')
    ]
)
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBondingCurveRegistry.sol";

/**
 * @title CurveAnalyzer
 * @notice Utilities for analyzing bonding curve behavior
 */
contract CurveAnalyzer {
    IBondingCurveRegistry public immutable registry;

    constructor(address _registry) {
        registry = IBondingCurveRegistry(_registry);
    }

    /**
     * @notice Calculate slippage for a deposit across all curves
     * @param depositAmount Amount to deposit
     * @param totalAssets Current vault assets
     * @param totalShares Current vault shares
     * @return curveIds Array of curve IDs
     * @return slippages Array of slippage percentages (1e18 = 100%)
     */
    function calculateSlippageAllCurves(
        uint256 depositAmount,
        uint256 totalAssets,
        uint256 totalShares
    ) external view returns (
        uint256[] memory curveIds,
        uint256[] memory slippages
    ) {
        uint256 count = registry.count();
        curveIds = new uint256[](count);
        slippages = new uint256[](count);

        for (uint256 i = 1; i <= count; i++) {
            curveIds[i - 1] = i;

            // Get current price
            uint256 priceBefore = registry.currentPrice(
                i,
                totalShares,
                totalAssets
            );

            // Calculate shares
            uint256 shares = registry.previewDeposit(
                depositAmount,
                totalAssets,
                totalShares,
                i
            );

            // Average price paid
            uint256 avgPrice = (depositAmount * 1e18) / shares;

            // Slippage
            if (priceBefore > 0) {
                slippages[i - 1] = ((avgPrice - priceBefore) * 1e18) / priceBefore;
            }
        }
    }

    /**
     * @notice Find curve with best pricing for a deposit
     * @param depositAmount Amount to deposit
     * @param totalAssets Current vault assets
     * @param totalShares Current vault shares
     * @return bestCurveId Curve ID with most shares
     * @return bestShares Number of shares from best curve
     */
    function findBestCurveForDeposit(
        uint256 depositAmount,
        uint256 totalAssets,
        uint256 totalShares
    ) external view returns (
        uint256 bestCurveId,
        uint256 bestShares
    ) {
        uint256 count = registry.count();
        bestShares = 0;

        for (uint256 i = 1; i <= count; i++) {
            uint256 shares = registry.previewDeposit(
                depositAmount,
                totalAssets,
                totalShares,
                i
            );

            if (shares > bestShares) {
                bestShares = shares;
                bestCurveId = i;
            }
        }
    }
}
```

## Integration Notes

### For SDK Builders

1. **Cache Curve List**: Query `count()` and cache curve metadata
2. **Validate IDs**: Always check `isCurveIdValid()` before operations
3. **Handle New Curves**: Listen for `BondingCurveAdded` events
4. **Parallel Queries**: Use multicall for batch curve queries
5. **Error Handling**: Catch invalid curve ID errors gracefully

### Common Patterns

#### Finding Optimal Curve
```typescript
// Compare all curves for a deposit
const optimalCurve = await findBestCurve(
  depositAmount,
  totalAssets,
  totalShares
);
```

#### Monitoring Curve Additions
```typescript
// Listen for new curves
registry.on('BondingCurveAdded', (curveId, address, name) => {
  console.log(`New curve added: ${name} (ID: ${curveId})`);
  // Update cache
});
```

### Edge Cases

1. **Curve ID 0**: Reserved, always invalid
2. **New Curves**: IDs are assigned sequentially, never reused
3. **Name Changes**: Curve names are immutable after registration
4. **Concurrent Additions**: Multiple curves can be added in same block

## Gas Considerations

### Read Operations

All read operations are view functions (no gas cost):

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| `isCurveIdValid` | O(1) | Simple comparison |
| `getCurveName` | O(1) | Single external call |
| `getCurveMaxShares/Assets` | O(1) | Single external call |
| `previewDeposit/Redeem` | O(1) | Routes to curve |
| `currentPrice` | O(1) | Routes to curve |

### Write Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `addBondingCurve` | ~100,000 | Includes storage writes |

### Optimization Tips

1. **Batch Queries**: Use multicall for multiple curve queries
2. **Cache Metadata**: Curve names and limits don't change
3. **Event Indexing**: Index `BondingCurveAdded` for curve discovery
4. **Direct Calls**: For known curve IDs, can call curves directly

## Related Contracts

### Curve Implementations
- **[BaseCurve](./BaseCurve.md)**: Abstract curve interface
- **[LinearCurve](./LinearCurve.md)**: Constant price curve (ID: 1)
- **[OffsetProgressiveCurve](./OffsetProgressiveCurve.md)**: Progressive curve (ID: 2)

### Core Integration
- **[MultiVault](../core/MultiVault.md)**: Primary consumer of registry
- **[MultiVaultCore](../core/MultiVaultCore.md)**: Stores bonding curve config

## See Also

### Concept Documentation
- [Bonding Curves](../../concepts/bonding-curves.md) - Pricing mechanisms explained
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - How curves enable multiple vaults

### Integration Guides
- [Creating Atoms](../../guides/creating-atoms.md) - Using curves for atoms
- [Creating Triples](../../guides/creating-triples.md) - Using curves for triples
- [Depositing Assets](../../guides/depositing-assets.md) - Curve selection

### Reference
- [Mathematical Formulas](../../reference/mathematical-formulas.md) - Curve mathematics
- [Events Reference](../../reference/events.md) - Complete events documentation

---

**Last Updated**: December 2025
**Version**: V2.0
