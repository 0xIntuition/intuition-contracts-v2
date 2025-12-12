# CoreEmissionsController

## Overview

The **CoreEmissionsController** is an abstract contract that provides the core mathematical logic for calculating time-based token emissions with periodic reductions. It implements a sophisticated emissions schedule using epochs, reduction cliffs, and compound decay formulas. This contract is inherited by both BaseEmissionsController and SatelliteEmissionsController to ensure identical emissions calculations across chains.

### Purpose and Role in Protocol

- **Emissions Calculator**: Provides deterministic calculation of emissions amounts for any epoch
- **Epoch Manager**: Converts between timestamps and epoch numbers
- **Reduction Scheduler**: Implements compound reduction schedule with configurable cliffs
- **Cross-Chain Consistency**: Ensures Base and Satellite chains calculate identical emissions
- **Gas Optimization**: Uses efficient fixed-point math for compound calculations

### Key Responsibilities

1. **Epoch Calculation**: Convert timestamps to epoch numbers and vice versa
2. **Emissions Calculation**: Determine emission amount for any given epoch
3. **Reduction Application**: Apply compound reductions at cliff intervals
4. **Parameter Validation**: Ensure emissions parameters are valid during initialization
5. **View Functions**: Provide read-only access to emissions schedule

## Contract Information

- **Location**: `src/protocol/emissions/CoreEmissionsController.sol`
- **Type**: Abstract contract (cannot be deployed directly)
- **Inherits**: `ICoreEmissionsController` (interface)
- **Inherited By**:
  - `BaseEmissionsController` (Base L2)
  - `SatelliteEmissionsController` (Intuition L3)

### Design Pattern

The CoreEmissionsController uses the **Template Method** pattern:
- Defines core emissions algorithm in abstract contract
- Child contracts (Base/Satellite) add chain-specific functionality
- Ensures mathematical consistency across all implementations

## Key Concepts

### Epoch System

An **epoch** is a fixed time period during which a constant amount of emissions occurs.

```solidity
epoch = (timestamp - startTimestamp) / epochLength
```

**Properties**:
- Sequential integers starting from 0
- Fixed duration (e.g., 7 days for weekly epochs)
- Deterministic: same timestamp always yields same epoch
- Immutable: cannot change after initialization

**Example**:
```
Start: Jan 1, 2024 00:00:00 UTC
Length: 7 days (604,800 seconds)

Epoch 0: Jan 1-7
Epoch 1: Jan 8-14
Epoch 2: Jan 15-21
...
```

### Emissions Reduction Schedule

Emissions decrease over time using a **cliff-based reduction schedule**:

```solidity
// Every N epochs (cliff), emissions reduce by X%
cliffsPassed = currentEpoch / emissionsReductionCliff
emissions = baseEmissions * (retentionFactor ^ cliffsPassed)
```

**Parameters**:
- `emissionsPerEpoch`: Initial emissions amount
- `emissionsReductionCliff`: Epochs between reductions (e.g., 52 for yearly with weekly epochs)
- `emissionsReductionBasisPoints`: Reduction percentage (e.g., 500 = 5%)
- `retentionFactor`: `10000 - reductionBasisPoints` (e.g., 9500 = 95%)

**Example**:
```
Initial emissions: 1,000,000 TRUST
Cliff: Every 52 epochs (1 year)
Reduction: 5% (500 basis points)
Retention: 95% (9500)

Epochs 0-51:   1,000,000 TRUST
Epochs 52-103:   950,000 TRUST (1M × 0.95^1)
Epochs 104-155:  902,500 TRUST (1M × 0.95^2)
Epochs 156-207:  857,375 TRUST (1M × 0.95^3)
```

### Compound Reduction Formula

The contract uses **compound exponential decay** for reductions:

```solidity
finalEmissions = baseEmissions × (retentionFactor / 10000) ^ cliffsApplied
```

**Mathematical Implementation**:
```solidity
// Convert retentionFactor to WAD (1e18 scale)
rWad = (retentionFactor * 1e18) / 10000

// Compute retentionFactor^cliffs using fixed-point exponentiation
factorWad = rpow(rWad, cliffs, 1e18)

// Apply to base emissions
emissions = (baseEmissions * factorWad) / 1e18
```

**Efficiency**: Uses Solady's `FixedPointMathLib.rpow()` for O(log n) computation

### Initialization Structure

```solidity
struct CoreEmissionsControllerInit {
    uint256 startTimestamp;                    // Emissions begin timestamp
    uint256 emissionsLength;                   // Epoch duration in seconds
    uint256 emissionsPerEpoch;                 // Base emissions per epoch
    uint256 emissionsReductionCliff;           // Epochs between reductions
    uint256 emissionsReductionBasisPoints;     // Reduction % (100 = 1%)
}
```

### Emissions Checkpoint Structure

```solidity
struct EmissionsCheckpoint {
    uint256 startTimestamp;
    uint256 emissionsLength;
    uint256 emissionsPerEpoch;
    uint256 emissionsReductionCliff;
    uint256 emissionsReductionBasisPoints;
    uint256 retentionFactor;                   // Computed: 10000 - reductionBP
}
```

## State Variables

### Constants

```solidity
uint256 internal constant BASIS_POINTS_DIVISOR = 10_000;
```
Divisor for basis point calculations. 10,000 basis points = 100%.

```solidity
uint256 internal constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000;
```
Maximum allowed reduction per cliff: 10% (1000 basis points). Prevents excessive reductions.

### Storage Variables

```solidity
uint256 internal _START_TIMESTAMP;
```
Unix timestamp when emissions schedule begins. All epoch calculations reference this.

```solidity
uint256 internal _EPOCH_LENGTH;
```
Duration of each epoch in seconds (e.g., 604800 for weekly epochs).

```solidity
uint256 internal _EMISSIONS_PER_EPOCH;
```
Base amount of tokens emitted per epoch before any reductions.

```solidity
uint256 internal _EMISSIONS_REDUCTION_CLIFF;
```
Number of epochs between each reduction event (e.g., 52 for yearly reductions with weekly epochs).

```solidity
uint256 internal _EMISSIONS_RETENTION_FACTOR;
```
Pre-computed retention factor: `10000 - emissionsReductionBasisPoints`. Used in compound calculations.

### Storage Gap

```solidity
uint256[50] private __gap;
```
Reserved storage slots for future upgrades (upgradeable pattern safety).

## Functions

### Initialization

#### `__CoreEmissionsController_init`
```solidity
function __CoreEmissionsController_init(
    uint256 startTimestamp,
    uint256 emissionsLength,
    uint256 emissionsPerEpoch,
    uint256 emissionsReductionCliff,
    uint256 emissionsReductionBasisPoints
) internal
```
Initializes the emissions schedule parameters. Called by child contract initializers.

**Parameters**:
- `startTimestamp`: When emissions begin (must be ≥ `block.timestamp`)
- `emissionsLength`: Epoch duration in seconds (e.g., 604800 for 7 days)
- `emissionsPerEpoch`: Initial emissions per epoch (e.g., 1000000e18)
- `emissionsReductionCliff`: Epochs between reductions (must be 1-365)
- `emissionsReductionBasisPoints`: Reduction % in BP (must be ≤ 1000)

**Emits**: `Initialized(startTimestamp, emissionsLength, emissionsPerEpoch, emissionsReductionCliff, emissionsReductionBasisPoints)`

**Reverts**:
- `CoreEmissionsController_InvalidTimestampStart` - Start time in past
- `CoreEmissionsController_InvalidEmissionsPerEpoch` - Zero emissions
- `CoreEmissionsController_InvalidCliff` - Cliff not in range [1, 365]
- `CoreEmissionsController_InvalidReductionBasisPoints` - Reduction > 10%

**Access**: Internal (called during contract initialization)

---

### Read Functions

#### `getStartTimestamp`
```solidity
function getStartTimestamp() external view returns (uint256)
```
Returns the timestamp when emissions schedule begins.

**Returns**: Unix timestamp of emissions start

**Use Cases**:
- Verify emissions schedule start
- Calculate time until emissions begin
- Debug epoch calculations

---

#### `getEpochLength`
```solidity
function getEpochLength() external view returns (uint256)
```
Returns the duration of each epoch in seconds.

**Returns**: Epoch duration in seconds

**Example Return**: `604800` (7 days)

**Use Cases**:
- Calculate epoch boundaries
- Verify epoch configuration
- Frontend time displays

---

#### `getCurrentEpoch`
```solidity
function getCurrentEpoch() external view returns (uint256)
```
Returns the current epoch number based on `block.timestamp`.

**Returns**: Current epoch number (0-indexed)

**Calculation**: `(block.timestamp - startTimestamp) / epochLength`

**Special Case**: Returns `0` if `block.timestamp < startTimestamp`

**Use Cases**:
- Determine which epoch to mint
- Check if emissions have started
- Calculate claimable rewards

---

#### `getCurrentEpochTimestampStart`
```solidity
function getCurrentEpochTimestampStart() external view returns (uint256)
```
Returns the timestamp when the current epoch started.

**Returns**: Unix timestamp of current epoch start

**Calculation**: `startTimestamp + (currentEpoch * epochLength)`

**Use Cases**:
- Display epoch progress
- Calculate time remaining in epoch
- Synchronize off-chain systems

---

#### `getCurrentEpochEmissions`
```solidity
function getCurrentEpochEmissions() external view returns (uint256)
```
Returns the emissions amount for the current epoch, including all reductions.

**Returns**: Emission amount for current epoch

**Use Cases**:
- Display current emissions rate
- Estimate rewards
- Monitor inflation

---

#### `getEpochAtTimestamp`
```solidity
function getEpochAtTimestamp(uint256 timestamp) external view returns (uint256)
```
Returns the epoch number for a given timestamp.

**Parameters**:
- `timestamp`: Unix timestamp to query

**Returns**: Epoch number containing the timestamp

**Calculation**: `(timestamp - startTimestamp) / epochLength`

**Use Cases**:
- Historical epoch lookup
- Timestamp to epoch conversion
- Validation of past epochs

---

#### `getEpochTimestampStart`
```solidity
function getEpochTimestampStart(uint256 epochNumber) external view returns (uint256)
```
Returns the timestamp when a specific epoch starts.

**Parameters**:
- `epochNumber`: Epoch to query

**Returns**: Unix timestamp of epoch start

**Calculation**: `startTimestamp + (epochNumber * epochLength)`

**Use Cases**:
- Calculate epoch boundaries
- Validate if timestamp is in epoch
- Display epoch schedule

---

#### `getEpochTimestampEnd`
```solidity
function getEpochTimestampEnd(uint256 epochNumber) external view returns (uint256)
```
Returns the timestamp when a specific epoch ends.

**Parameters**:
- `epochNumber`: Epoch to query

**Returns**: Unix timestamp of epoch end (start of next epoch)

**Calculation**: `startTimestamp + ((epochNumber + 1) * epochLength)`

**Use Cases**:
- Determine claim deadlines
- Calculate remaining time
- Epoch boundary validation

---

#### `getEmissionsAtEpoch`
```solidity
function getEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256)
```
Returns the emission amount for a specific epoch, including all cliff reductions.

**Parameters**:
- `epochNumber`: Epoch to calculate emissions for

**Returns**: Emissions amount for the epoch

**Algorithm**:
1. Calculate cliffs passed: `epochNumber / emissionsReductionCliff`
2. Apply compound reduction: `baseEmissions * (retentionFactor ^ cliffs)`

**Use Cases**:
- Calculate historical emissions
- Predict future emissions
- Verify minting amounts

**Example**:
```solidity
// Epoch 0-51: Full emissions
getEmissionsAtEpoch(25) → 1,000,000 TRUST

// Epoch 52-103: First reduction (95%)
getEmissionsAtEpoch(75) → 950,000 TRUST

// Epoch 104-155: Second reduction (95% again)
getEmissionsAtEpoch(120) → 902,500 TRUST
```

---

#### `getEmissionsAtTimestamp`
```solidity
function getEmissionsAtTimestamp(uint256 timestamp) external view returns (uint256)
```
Returns the emission amount for the epoch containing the given timestamp.

**Parameters**:
- `timestamp`: Unix timestamp to query

**Returns**: Emissions amount for epoch at timestamp

**Use Cases**:
- Historical emissions lookup
- Timestamp-based queries
- Frontend displays

---

## Events

### `Initialized`
```solidity
event Initialized(
    uint256 startTimestamp,
    uint256 emissionsLength,
    uint256 emissionsPerEpoch,
    uint256 emissionsReductionCliff,
    uint256 emissionsReductionBasisPoints
)
```
Emitted when the CoreEmissionsController is initialized with emissions parameters.

**Parameters**:
- `startTimestamp`: When emissions begin
- `emissionsLength`: Epoch duration in seconds
- `emissionsPerEpoch`: Base emissions per epoch
- `emissionsReductionCliff`: Epochs between reductions
- `emissionsReductionBasisPoints`: Reduction percentage in BP

**Use Cases**:
- Verify initialization parameters
- Audit emissions schedule
- Cross-chain validation (ensure Base and Satellite match)

---

## Errors

### `CoreEmissionsController_InvalidReductionBasisPoints`
Thrown when reduction basis points exceed the maximum allowed (1000 BP = 10%).

**Triggers**: Initialization with `emissionsReductionBasisPoints > 1000`

**Recovery**: Reduce the reduction percentage to ≤ 10%

**Rationale**: Prevents excessive emissions reductions that could destabilize tokenomics

---

### `CoreEmissionsController_InvalidCliff`
Thrown when cliff value is zero or exceeds 365 epochs.

**Triggers**:
- Initialization with `emissionsReductionCliff == 0`
- Initialization with `emissionsReductionCliff > 365`

**Recovery**: Set cliff to a value between 1 and 365

**Rationale**:
- Zero cliff would cause division by zero
- > 365 epochs is unreasonably long (e.g., > 7 years for weekly epochs)

---

### `CoreEmissionsController_InvalidTimestampStart`
Thrown when the start timestamp is in the past.

**Triggers**: Initialization with `startTimestamp < block.timestamp`

**Recovery**: Set start timestamp to present or future

**Rationale**: Cannot start emissions schedule in the past

---

### `CoreEmissionsController_InvalidEmissionsPerEpoch`
Thrown when emissions per epoch is zero.

**Triggers**: Initialization with `emissionsPerEpoch == 0`

**Recovery**: Set non-zero emissions amount

**Rationale**: Zero emissions makes the contract non-functional

---

## Internal Functions

These are implementation details inherited by child contracts:

### `_currentEpoch`
```solidity
function _currentEpoch() internal view returns (uint256)
```
Internal version of `getCurrentEpoch()`.

---

### `_emissionsAtEpoch`
```solidity
function _emissionsAtEpoch(uint256 epoch) internal view returns (uint256)
```
Internal function to calculate emissions for a specific epoch.

**Algorithm**:
1. Calculate cliffs: `epoch / _EMISSIONS_REDUCTION_CLIFF`
2. Call `_applyCliffReductions(baseEmissions, retentionFactor, cliffs)`

---

### `_calculateEpochTimestampStart`
```solidity
function _calculateEpochTimestampStart(uint256 epoch) internal view returns (uint256)
```
Internal calculation of epoch start timestamp.

---

### `_calculateEpochTimestampEnd`
```solidity
function _calculateEpochTimestampEnd(uint256 epoch) internal view returns (uint256)
```
Internal calculation of epoch end timestamp.

---

### `_calculateTotalEpochsToTimestamp`
```solidity
function _calculateTotalEpochsToTimestamp(uint256 timestamp) internal view returns (uint256)
```
Internal conversion from timestamp to epoch number.

---

### `_calculateEpochEmissionsAt`
```solidity
function _calculateEpochEmissionsAt(uint256 timestamp) internal view returns (uint256)
```
Internal calculation of emissions for epoch at given timestamp.

---

### `_applyCliffReductions`
```solidity
function _applyCliffReductions(
    uint256 baseEmissions,
    uint256 retentionFactor,
    uint256 cliffsToApply
) internal pure returns (uint256)
```
Applies compound cliff reductions to base emissions.

**Algorithm**:
```solidity
if (cliffsToApply == 0) return baseEmissions;

// Convert retentionFactor to WAD (1e18 scale)
uint256 rWad = (retentionFactor * 1e18) / BASIS_POINTS_DIVISOR;

// Compute retention^cliffs using O(log n) exponentiation
uint256 factorWad = FixedPointMathLib.rpow(rWad, cliffsToApply, 1e18);

// Apply to base emissions
return (baseEmissions * factorWad) / 1e18;
```

**Efficiency**: O(log n) time complexity via binary exponentiation

**Precision**: Uses 18-decimal fixed-point math to avoid rounding errors

---

### Validation Functions

#### `_validateEmissionsPerEpoch`
```solidity
function _validateEmissionsPerEpoch(uint256 emissionsPerEpoch) internal pure
```
Ensures emissions per epoch is non-zero.

---

#### `_validateTimestampStart`
```solidity
function _validateTimestampStart(uint256 timestampStart) internal view
```
Ensures start timestamp is not in the past.

---

#### `_validateReductionBasisPoints`
```solidity
function _validateReductionBasisPoints(uint256 emissionsReductionBasisPoints) internal pure
```
Ensures reduction is ≤ 10% (1000 basis points).

---

#### `_validateCliff`
```solidity
function _validateCliff(uint256 emissionsReductionCliff) internal pure
```
Ensures cliff is in range [1, 365].

---

## Usage Examples

### Solidity Integration

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { CoreEmissionsController } from "src/protocol/emissions/CoreEmissionsController.sol";

/**
 * @title EmissionsCalculator
 * @notice Example contract using CoreEmissionsController for emissions calculations
 */
contract EmissionsCalculator is CoreEmissionsController {
    constructor(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionCliff,
        uint256 emissionsReductionBasisPoints
    ) {
        __CoreEmissionsController_init(
            startTimestamp,
            emissionsLength,
            emissionsPerEpoch,
            emissionsReductionCliff,
            emissionsReductionBasisPoints
        );
    }

    /**
     * @notice Calculate total emissions over a range of epochs
     */
    function getTotalEmissionsForRange(
        uint256 startEpoch,
        uint256 endEpoch
    )
        external
        view
        returns (uint256 totalEmissions)
    {
        require(endEpoch >= startEpoch, "Invalid range");

        for (uint256 epoch = startEpoch; epoch <= endEpoch; epoch++) {
            totalEmissions += _emissionsAtEpoch(epoch);
        }

        return totalEmissions;
    }

    /**
     * @notice Calculate emissions for next N epochs
     */
    function getNextNEpochsEmissions(uint256 n)
        external
        view
        returns (uint256[] memory emissions)
    {
        uint256 currentEpoch = _currentEpoch();
        emissions = new uint256[](n);

        for (uint256 i = 0; i < n; i++) {
            emissions[i] = _emissionsAtEpoch(currentEpoch + i);
        }

        return emissions;
    }

    /**
     * @notice Get comprehensive epoch info
     */
    function getEpochInfo(uint256 epoch)
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 emissions,
            uint256 cliffsPassed
        )
    {
        startTime = _calculateEpochTimestampStart(epoch);
        endTime = _calculateEpochTimestampEnd(epoch);
        emissions = _emissionsAtEpoch(epoch);
        cliffsPassed = epoch / _EMISSIONS_REDUCTION_CLIFF;

        return (startTime, endTime, emissions, cliffsPassed);
    }

    /**
     * @notice Calculate average emissions per day over next N epochs
     */
    function getAverageDailyEmissions(uint256 numEpochs)
        external
        view
        returns (uint256)
    {
        uint256 totalEmissions = this.getTotalEmissionsForRange(
            _currentEpoch(),
            _currentEpoch() + numEpochs - 1
        );

        uint256 totalDays = (numEpochs * _EPOCH_LENGTH) / 1 days;
        return totalEmissions / totalDays;
    }
}
```

### TypeScript Examples

```typescript
import { createPublicClient, http } from 'viem';
import { base } from 'viem/chains';

const CORE_EMISSIONS_ABI = [
  {
    name: 'getCurrentEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getEmissionsAtEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epochNumber', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getEpochTimestampStart',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epochNumber', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getEpochTimestampEnd',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epochNumber', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

const publicClient = createPublicClient({
  chain: base,
  transport: http(),
});

// Example 1: Calculate emissions schedule
async function calculateEmissionsSchedule(
  contractAddress: `0x${string}`,
  numEpochs: number
) {
  const currentEpoch = await publicClient.readContract({
    address: contractAddress,
    abi: CORE_EMISSIONS_ABI,
    functionName: 'getCurrentEpoch',
  });

  const schedule = [];
  for (let i = 0; i < numEpochs; i++) {
    const epoch = currentEpoch + BigInt(i);
    const emissions = await publicClient.readContract({
      address: contractAddress,
      abi: CORE_EMISSIONS_ABI,
      functionName: 'getEmissionsAtEpoch',
      args: [epoch],
    });

    schedule.push({
      epoch: Number(epoch),
      emissions: emissions.toString(),
    });
  }

  return schedule;
}

// Example 2: Calculate time until next epoch
async function getTimeUntilNextEpoch(contractAddress: `0x${string}`) {
  const currentEpoch = await publicClient.readContract({
    address: contractAddress,
    abi: CORE_EMISSIONS_ABI,
    functionName: 'getCurrentEpoch',
  });

  const currentEpochEnd = await publicClient.readContract({
    address: contractAddress,
    abi: CORE_EMISSIONS_ABI,
    functionName: 'getEpochTimestampEnd',
    args: [currentEpoch],
  });

  const now = Math.floor(Date.now() / 1000);
  const secondsRemaining = Number(currentEpochEnd) - now;

  return {
    secondsRemaining,
    hoursRemaining: secondsRemaining / 3600,
    daysRemaining: secondsRemaining / 86400,
  };
}

// Example 3: Calculate total emissions over range
async function getTotalEmissionsForRange(
  contractAddress: `0x${string}`,
  startEpoch: bigint,
  endEpoch: bigint
) {
  let total = 0n;

  for (let epoch = startEpoch; epoch <= endEpoch; epoch++) {
    const emissions = await publicClient.readContract({
      address: contractAddress,
      abi: CORE_EMISSIONS_ABI,
      functionName: 'getEmissionsAtEpoch',
      args: [epoch],
    });
    total += emissions;
  }

  return total;
}
```

### Python Examples

```python
from web3 import Web3
import json

CORE_EMISSIONS_ABI = json.loads('''[
  {
    "name": "getCurrentEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "getEmissionsAtEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [{"name": "epochNumber", "type": "uint256"}],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "getEpochLength",
    "type": "function",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [{"type": "uint256"}]
  }
]''')

w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))

def calculate_emissions_decay(contract_address, num_years=5, epochs_per_year=52):
    """Calculate emissions decay over multiple years"""
    contract = w3.eth.contract(address=contract_address, abi=CORE_EMISSIONS_ABI)

    current_epoch = contract.functions.getCurrentEpoch().call()
    total_epochs = num_years * epochs_per_year

    yearly_totals = []

    for year in range(num_years):
        year_start = current_epoch + (year * epochs_per_year)
        year_end = year_start + epochs_per_year - 1

        year_emissions = 0
        for epoch in range(year_start, year_end + 1):
            emissions = contract.functions.getEmissionsAtEpoch(epoch).call()
            year_emissions += emissions

        yearly_totals.append({
            'year': year + 1,
            'total_emissions': w3.from_wei(year_emissions, 'ether'),
            'avg_per_epoch': w3.from_wei(year_emissions // epochs_per_year, 'ether')
        })

    return yearly_totals

def get_epoch_progress(contract_address):
    """Calculate progress through current epoch"""
    contract = w3.eth.contract(address=contract_address, abi=CORE_EMISSIONS_ABI)

    current_epoch = contract.functions.getCurrentEpoch().call()
    epoch_start = contract.functions.getEpochTimestampStart(current_epoch).call()
    epoch_end = contract.functions.getEpochTimestampEnd(current_epoch).call()

    now = int(time.time())
    elapsed = now - epoch_start
    total_duration = epoch_end - epoch_start
    progress_pct = (elapsed / total_duration) * 100

    return {
        'epoch': current_epoch,
        'progress_percent': progress_pct,
        'elapsed_seconds': elapsed,
        'remaining_seconds': epoch_end - now
    }
```

---

## Integration Notes

### Cross-Chain Consistency

**Critical Requirement**: Both BaseEmissionsController (Base L2) and SatelliteEmissionsController (Intuition L3) must be initialized with **identical** parameters:

```solidity
// ✅ CORRECT: Same parameters on both chains
Base:      __CoreEmissionsController_init(1704067200, 604800, 1000000e18, 52, 500)
Satellite: __CoreEmissionsController_init(1704067200, 604800, 1000000e18, 52, 500)

// ❌ WRONG: Different parameters will cause desynchronization
Base:      __CoreEmissionsController_init(1704067200, 604800, 1000000e18, 52, 500)
Satellite: __CoreEmissionsController_init(1704067200, 604800, 900000e18, 52, 500)  // Different base emissions!
```

**Validation**: Always verify both chains return identical values:
```typescript
const baseEpoch = await baseController.read.getCurrentEpoch();
const satEpoch = await satelliteController.read.getCurrentEpoch();
assert(baseEpoch === satEpoch, 'Epochs desynchronized!');
```

### Common Patterns

**Epoch Boundary Detection**:
```solidity
function isEpochBoundary() public view returns (bool) {
    uint256 currentEpoch = _currentEpoch();
    uint256 epochEnd = _calculateEpochTimestampEnd(currentEpoch);
    return block.timestamp >= epochEnd - 60; // Within 1 minute of boundary
}
```

**Emissions Forecasting**:
```solidity
function forecastEmissions(uint256 numEpochs) public view returns (uint256 total) {
    uint256 startEpoch = _currentEpoch();
    for (uint256 i = 0; i < numEpochs; i++) {
        total += _emissionsAtEpoch(startEpoch + i);
    }
}
```

---

## Gas Considerations

### View Function Costs

| Function | Estimated Gas | Notes |
|----------|--------------|-------|
| `getCurrentEpoch` | ~3,000 | Simple arithmetic |
| `getEmissionsAtEpoch` | ~5,000-15,000 | Depends on cliff count |
| `getEpochTimestampStart` | ~2,500 | Simple calculation |
| All view functions | Free | No state changes |

### Optimization in rpow

The `_applyCliffReductions` function uses Solady's `rpow` for O(log n) exponentiation:

```solidity
// Instead of O(n) loop:
// for (i = 0; i < cliffs; i++) result *= retention;

// Uses O(log n) binary exponentiation:
factorWad = rpow(rWad, cliffs, 1e18);
```

**Gas Savings**:
- 10 cliffs: ~70% gas reduction
- 50 cliffs: ~90% gas reduction
- 100 cliffs: ~95% gas reduction

---

## Related Contracts

- **[BaseEmissionsController](./BaseEmissionsController.md)**: Inherits CoreEmissionsController on Base L2
- **[SatelliteEmissionsController](./SatelliteEmissionsController.md)**: Inherits CoreEmissionsController on Intuition L3
- **[TrustBonding](./TrustBonding.md)**: Uses epoch calculations for rewards distribution

---

## See Also

- [Emissions System Overview](/docs/concepts/emissions-system.md)
- [Epoch Management](/docs/concepts/epochs.md)
- [Tokenomics](/docs/concepts/tokenomics.md)
- [Fixed-Point Math](/docs/concepts/fixed-point-math.md)
