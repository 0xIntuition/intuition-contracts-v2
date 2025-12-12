# Epoch Management

## Overview

Epochs are fixed-duration time periods that form the foundation of Intuition's emissions and rewards system. Understanding epoch mechanics is essential for optimizing reward claims, tracking utilization, and timing protocol interactions.

This guide covers how to work with epochs, calculate boundaries, and build epoch-aware applications.

**Key Concepts**:
- Epochs are sequential time periods (e.g., 7 days each)
- Rewards accrue per epoch based on utilization
- Rewards claimable in epoch n+1 for epoch n activity
- Utilization tracked separately per epoch
- Missing a claim window means forfeiting rewards

## Prerequisites

### Required Knowledge
- Understanding of Unix timestamps
- Familiarity with [utilization mechanics](./utilization-mechanics.md)
- Knowledge of [reward claiming](./claiming-rewards.md)

### Contracts Needed
- **TrustBonding**: Epoch management contract
  - Mainnet: Check deployment addresses
- **MultiVault**: Utilization tracking per epoch
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`

## Epoch Mechanics

### Epoch Structure

**Definition**: An epoch is a fixed-duration time period defined at contract deployment.

**Key Properties**:
- **Epoch 0**: Genesis epoch, starts at deployment timestamp
- **Epoch length**: Fixed duration in seconds (e.g., 604800 = 7 days)
- **Sequential**: Epochs increment by 1 (0, 1, 2, 3, ...)
- **Non-overlapping**: Each timestamp belongs to exactly one epoch

**Formula**:
```
epochNumber = floor((currentTimestamp - startTimestamp) / epochLength)
```

### Important Timestamps

1. **Start timestamp**: When epoch 0 began (contract deployment)
2. **Current timestamp**: `block.timestamp`
3. **Epoch end**: When current epoch ends
4. **Next epoch start**: Same as current epoch end

### Epochs Per Year

```
epochsPerYear = SECONDS_PER_YEAR / epochLength
              = 31,536,000 / epochLength
```

For 7-day epochs: 31,536,000 / 604,800 = 52.14 epochs/year

## Step-by-Step Guide

### Step 1: Get Current Epoch

```typescript
const currentEpoch = await trustBonding.currentEpoch();
console.log('Current epoch:', currentEpoch);

// Alternative: Query from MultiVault
const currentEpochFromMV = await multiVault.currentEpoch();
console.log('Current epoch (from MultiVault):', currentEpochFromMV);
```

### Step 2: Get Previous Epoch

```typescript
const previousEpoch = await trustBonding.previousEpoch();
console.log('Previous epoch:', previousEpoch);

// Manual calculation
const current = await trustBonding.currentEpoch();
const previous = current > 0n ? current - 1n : 0n;
console.log('Previous epoch (calculated):', previous);
```

### Step 3: Get Epoch Length

```typescript
const epochLength = await trustBonding.epochLength();
console.log('Epoch length:', Number(epochLength), 'seconds');
console.log('Epoch length:', Number(epochLength) / 86400, 'days');
```

### Step 4: Get Epoch End Time

```typescript
const currentEpoch = await trustBonding.currentEpoch();
const epochEndTime = await trustBonding.epochTimestampEnd(currentEpoch);

console.log('Current epoch ends at:', new Date(Number(epochEndTime) * 1000).toISOString());

// Time until epoch ends
const now = Math.floor(Date.now() / 1000);
const secondsRemaining = Number(epochEndTime) - now;
const hoursRemaining = secondsRemaining / 3600;

console.log('Time remaining:', hoursRemaining.toFixed(2), 'hours');
```

### Step 5: Calculate Epoch for Timestamp

```typescript
// What epoch was January 1, 2025 in?
const timestamp = Math.floor(new Date('2025-01-01T00:00:00Z').getTime() / 1000);
const epoch = await trustBonding.epochAtTimestamp(timestamp);

console.log('Epoch for timestamp', timestamp, ':', epoch);
```

### Step 6: Get Epochs Per Year

```typescript
const epochsPerYear = await trustBonding.epochsPerYear();
console.log('Epochs per year:', epochsPerYear);

// Useful for APY calculations
const annualEmissions = epochsPerYear * emissionsPerEpoch;
```

### Step 7: Track Epoch Boundaries

```typescript
async function waitForNextEpoch() {
  const currentEpoch = await trustBonding.currentEpoch();
  const epochEnd = await trustBonding.epochTimestampEnd(currentEpoch);

  const now = Math.floor(Date.now() / 1000);
  const waitTime = Number(epochEnd) - now;

  console.log(`Waiting ${waitTime} seconds for epoch ${currentEpoch + 1n}...`);

  // Wait for next epoch
  await new Promise(resolve => setTimeout(resolve, waitTime * 1000));

  const newEpoch = await trustBonding.currentEpoch();
  console.log('New epoch:', newEpoch);

  return newEpoch;
}
```

### Step 8: Get Emissions for Epoch

```typescript
const epoch = await trustBonding.currentEpoch();
const emissions = await trustBonding.emissionsForEpoch(epoch);

console.log('Emissions for epoch', epoch, ':', formatEther(emissions), 'TRUST');
```

### Step 9: Calculate Epoch Range

```typescript
// Get last N epochs
function getEpochRange(currentEpoch: bigint, count: number): bigint[] {
  const epochs: bigint[] = [];
  const start = currentEpoch >= BigInt(count)
    ? currentEpoch - BigInt(count) + 1n
    : 0n;

  for (let epoch = start; epoch <= currentEpoch; epoch++) {
    epochs.push(epoch);
  }

  return epochs;
}

const current = await trustBonding.currentEpoch();
const last10Epochs = getEpochRange(current, 10);
console.log('Last 10 epochs:', last10Epochs);
```

## Code Examples

### TypeScript (viem)

Comprehensive epoch management utility:

```typescript
import {
  createPublicClient,
  http,
  formatEther,
  type Address,
  type PublicClient
} from 'viem';
import { base } from 'viem/chains';

// ABIs
import { trustBondingAbi } from './abis/ITrustBonding';
import { multiVaultAbi } from './abis/IMultiVault';

interface EpochInfo {
  epochNumber: bigint;
  startTime: bigint;
  endTime: bigint;
  secondsRemaining: number;
  emissions: bigint;
  isCurrent: boolean;
  isPrevious: boolean;
  claimableForRewards: boolean;
}

class EpochManager {
  private publicClient: PublicClient;
  private trustBondingAddress: Address;
  private multiVaultAddress: Address;
  private epochLength: bigint | null = null;
  private startTimestamp: bigint | null = null;

  constructor(
    trustBondingAddress: Address,
    multiVaultAddress: Address,
    rpcUrl: string
  ) {
    this.trustBondingAddress = trustBondingAddress;
    this.multiVaultAddress = multiVaultAddress;
    this.publicClient = createPublicClient({
      chain: base,
      transport: http(rpcUrl)
    });
  }

  async initialize() {
    this.epochLength = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'epochLength'
    });

    // Calculate start timestamp by working backwards from current epoch
    const currentEpoch = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });

    const currentEpochEnd = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'epochTimestampEnd',
      args: [currentEpoch]
    });

    // startTimestamp = epochEnd - (epochNumber + 1) * epochLength
    this.startTimestamp = currentEpochEnd - (currentEpoch + 1n) * this.epochLength;
  }

  async getEpochInfo(epoch: bigint): Promise<EpochInfo> {
    if (!this.epochLength) {
      throw new Error('EpochManager not initialized. Call initialize() first.');
    }

    const [currentEpoch, epochEnd, emissions] = await Promise.all([
      this.publicClient.readContract({
        address: this.trustBondingAddress,
        abi: trustBondingAbi,
        functionName: 'currentEpoch'
      }),
      this.publicClient.readContract({
        address: this.trustBondingAddress,
        abi: trustBondingAbi,
        functionName: 'epochTimestampEnd',
        args: [epoch]
      }),
      this.publicClient.readContract({
        address: this.trustBondingAddress,
        abi: trustBondingAbi,
        functionName: 'emissionsForEpoch',
        args: [epoch]
      })
    ]);

    const startTime = epochEnd - this.epochLength;
    const now = BigInt(Math.floor(Date.now() / 1000));
    const secondsRemaining = Number(epochEnd - now);

    return {
      epochNumber: epoch,
      startTime,
      endTime: epochEnd,
      secondsRemaining,
      emissions,
      isCurrent: epoch === currentEpoch,
      isPrevious: epoch === currentEpoch - 1n,
      claimableForRewards: epoch === currentEpoch - 1n
    };
  }

  async getCurrentEpochInfo(): Promise<EpochInfo> {
    const currentEpoch = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });
    return this.getEpochInfo(currentEpoch);
  }

  async getPreviousEpochInfo(): Promise<EpochInfo> {
    const previousEpoch = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'previousEpoch'
    });
    return this.getEpochInfo(previousEpoch);
  }

  async getEpochHistory(count: number): Promise<EpochInfo[]> {
    const currentEpoch = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });

    const startEpoch = currentEpoch >= BigInt(count)
      ? currentEpoch - BigInt(count) + 1n
      : 0n;

    const epochs: EpochInfo[] = [];

    for (let epoch = startEpoch; epoch <= currentEpoch; epoch++) {
      const info = await this.getEpochInfo(epoch);
      epochs.push(info);
    }

    return epochs;
  }

  formatEpochInfo(info: EpochInfo): string {
    return `
=== Epoch ${info.epochNumber} ===
Start time: ${new Date(Number(info.startTime) * 1000).toISOString()}
End time: ${new Date(Number(info.endTime) * 1000).toISOString()}
Emissions: ${formatEther(info.emissions)} TRUST
Status: ${info.isCurrent ? 'Current' : info.isPrevious ? 'Previous' : 'Historical'}
${info.isCurrent ? `Time remaining: ${(info.secondsRemaining / 3600).toFixed(2)} hours` : ''}
${info.claimableForRewards ? '✓ Claimable for rewards' : ''}
    `.trim();
  }

  async waitForNextEpoch(callback?: (epoch: bigint) => void): Promise<bigint> {
    const currentInfo = await this.getCurrentEpochInfo();

    console.log(`Waiting ${currentInfo.secondsRemaining} seconds for next epoch...`);

    await new Promise(resolve =>
      setTimeout(resolve, currentInfo.secondsRemaining * 1000)
    );

    const newEpoch = await this.publicClient.readContract({
      address: this.trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });

    if (callback) {
      callback(newEpoch);
    }

    return newEpoch;
  }

  async scheduleEpochCallback(callback: (epoch: bigint) => void) {
    while (true) {
      const newEpoch = await this.waitForNextEpoch();
      callback(newEpoch);
    }
  }

  async getEpochStats(): Promise<{
    currentEpoch: bigint;
    epochLength: bigint;
    epochsPerYear: bigint;
    nextEpochIn: number;
    totalEmissions: bigint;
  }> {
    const [currentEpoch, epochLength, epochsPerYear, currentInfo] =
      await Promise.all([
        this.publicClient.readContract({
          address: this.trustBondingAddress,
          abi: trustBondingAbi,
          functionName: 'currentEpoch'
        }),
        this.publicClient.readContract({
          address: this.trustBondingAddress,
          abi: trustBondingAbi,
          functionName: 'epochLength'
        }),
        this.publicClient.readContract({
          address: this.trustBondingAddress,
          abi: trustBondingAbi,
          functionName: 'epochsPerYear'
        }),
        this.getCurrentEpochInfo()
      ]);

    // Calculate total emissions to date
    let totalEmissions = 0n;
    for (let epoch = 0n; epoch <= currentEpoch; epoch++) {
      const emissions = await this.publicClient.readContract({
        address: this.trustBondingAddress,
        abi: trustBondingAbi,
        functionName: 'emissionsForEpoch',
        args: [epoch]
      });
      totalEmissions += emissions;
    }

    return {
      currentEpoch,
      epochLength,
      epochsPerYear,
      nextEpochIn: currentInfo.secondsRemaining,
      totalEmissions
    };
  }
}

// Usage example
async function main() {
  const TRUST_BONDING_ADDRESS = '0x...' as Address;
  const MULTIVAULT_ADDRESS = '0x...' as Address;
  const RPC_URL = 'YOUR_INTUITION_RPC_URL';

  const manager = new EpochManager(
    TRUST_BONDING_ADDRESS,
    MULTIVAULT_ADDRESS,
    RPC_URL
  );

  await manager.initialize();

  // Get current epoch info
  const currentInfo = await manager.getCurrentEpochInfo();
  console.log(manager.formatEpochInfo(currentInfo));

  // Get previous epoch (claimable)
  const previousInfo = await manager.getPreviousEpochInfo();
  console.log('\n' + manager.formatEpochInfo(previousInfo));

  // Get stats
  const stats = await manager.getEpochStats();
  console.log('\n=== Epoch Statistics ===');
  console.log('Current epoch:', stats.currentEpoch);
  console.log('Epoch length:', Number(stats.epochLength) / 86400, 'days');
  console.log('Epochs per year:', stats.epochsPerYear);
  console.log('Next epoch in:', (stats.nextEpochIn / 3600).toFixed(2), 'hours');
  console.log('Total emissions to date:', formatEther(stats.totalEmissions), 'TRUST');

  // Schedule callback for next epoch
  await manager.scheduleEpochCallback((newEpoch) => {
    console.log(`\nNew epoch started: ${newEpoch}`);
    console.log('Time to claim rewards for previous epoch!');
  });
}

main().catch(console.error);
```

### Python (web3.py)

```python
from web3 import Web3
from datetime import datetime, timedelta
import json
import time
from typing import List, Dict

class EpochManager:
    def __init__(self, trust_bonding_address: str, rpc_url: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))

        with open('abis/ITrustBonding.json') as f:
            abi = json.load(f)

        self.trust_bonding = self.w3.eth.contract(
            address=Web3.to_checksum_address(trust_bonding_address),
            abi=abi
        )

        self.epoch_length = self.trust_bonding.functions.epochLength().call()

    def get_epoch_info(self, epoch: int) -> Dict:
        """Get information about a specific epoch"""
        current_epoch = self.trust_bonding.functions.currentEpoch().call()
        epoch_end = self.trust_bonding.functions.epochTimestampEnd(epoch).call()
        emissions = self.trust_bonding.functions.emissionsForEpoch(epoch).call()

        start_time = epoch_end - self.epoch_length
        now = int(time.time())
        seconds_remaining = max(0, epoch_end - now)

        return {
            'epoch_number': epoch,
            'start_time': datetime.fromtimestamp(start_time),
            'end_time': datetime.fromtimestamp(epoch_end),
            'seconds_remaining': seconds_remaining,
            'emissions': emissions,
            'is_current': epoch == current_epoch,
            'is_previous': epoch == current_epoch - 1,
            'claimable_for_rewards': epoch == current_epoch - 1
        }

    def get_current_epoch_info(self) -> Dict:
        """Get current epoch information"""
        current_epoch = self.trust_bonding.functions.currentEpoch().call()
        return self.get_epoch_info(current_epoch)

    def format_epoch_info(self, info: Dict) -> str:
        """Format epoch information for display"""
        lines = [
            f"=== Epoch {info['epoch_number']} ===",
            f"Start time: {info['start_time'].isoformat()}",
            f"End time: {info['end_time'].isoformat()}",
            f"Emissions: {Web3.from_wei(info['emissions'], 'ether')} TRUST",
            f"Status: {'Current' if info['is_current'] else 'Previous' if info['is_previous'] else 'Historical'}"
        ]

        if info['is_current']:
            hours = info['seconds_remaining'] / 3600
            lines.append(f"Time remaining: {hours:.2f} hours")

        if info['claimable_for_rewards']:
            lines.append("✓ Claimable for rewards")

        return '\n'.join(lines)

    def wait_for_next_epoch(self) -> int:
        """Wait for the next epoch to start"""
        current_info = self.get_current_epoch_info()
        wait_time = current_info['seconds_remaining']

        print(f"Waiting {wait_time} seconds for next epoch...")
        time.sleep(wait_time)

        new_epoch = self.trust_bonding.functions.currentEpoch().call()
        print(f"New epoch started: {new_epoch}")

        return new_epoch

if __name__ == '__main__':
    manager = EpochManager(
        '0x...',  # TrustBonding address
        'YOUR_RPC_URL'
    )

    # Get current epoch
    current_info = manager.get_current_epoch_info()
    print(manager.format_epoch_info(current_info))

    # Get previous epoch
    previous_epoch = current_info['epoch_number'] - 1
    if previous_epoch >= 0:
        previous_info = manager.get_epoch_info(previous_epoch)
        print('\n' + manager.format_epoch_info(previous_info))
```

## Common Patterns

### 1. Epoch-Aware Reward Claiming

```typescript
async function autoClaimRewards(
  trustBondingAddress: Address,
  walletAddress: Address,
  publicClient: PublicClient,
  walletClient: WalletClient
) {
  while (true) {
    const currentEpoch = await publicClient.readContract({
      address: trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });

    // Wait for next epoch
    await manager.waitForNextEpoch();

    // Claim rewards for previous epoch
    const claimableEpoch = currentEpoch; // Now previous
    const claimable = await publicClient.readContract({
      address: trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'getUserCurrentClaimableRewards',
      args: [walletAddress]
    });

    if (claimable > 0n) {
      console.log(`Claiming rewards for epoch ${claimableEpoch}`);
      const hash = await walletClient.writeContract({
        address: trustBondingAddress,
        abi: trustBondingAbi,
        functionName: 'claimRewards',
        args: [walletAddress]
      });
      await publicClient.waitForTransactionReceipt({ hash });
    }
  }
}
```

### 2. Utilization Tracking Across Epochs

```typescript
async function trackUtilizationHistory(
  multiVaultAddress: Address,
  userAddress: Address,
  epochCount: number,
  publicClient: PublicClient
) {
  const currentEpoch = await publicClient.readContract({
    address: multiVaultAddress,
    abi: multiVaultAbi,
    functionName: 'currentEpoch'
  });

  const history = [];

  for (let i = 0; i < epochCount; i++) {
    const epoch = currentEpoch - BigInt(i);
    if (epoch < 0n) break;

    const utilization = await publicClient.readContract({
      address: multiVaultAddress,
      abi: multiVaultAbi,
      functionName: 'getUserUtilizationForEpoch',
      args: [userAddress, epoch]
    });

    history.push({ epoch, utilization });
  }

  return history;
}
```

### 3. Epoch Boundary Notifications

```typescript
async function notifyOnEpochChange(
  trustBondingAddress: Address,
  publicClient: PublicClient,
  callback: (epoch: bigint) => void
) {
  let lastEpoch = await publicClient.readContract({
    address: trustBondingAddress,
    abi: trustBondingAbi,
    functionName: 'currentEpoch'
  });

  setInterval(async () => {
    const currentEpoch = await publicClient.readContract({
      address: trustBondingAddress,
      abi: trustBondingAbi,
      functionName: 'currentEpoch'
    });

    if (currentEpoch !== lastEpoch) {
      callback(currentEpoch);
      lastEpoch = currentEpoch;
    }
  }, 60000); // Check every minute
}
```

## Best Practices

1. **Cache epoch length**: It's constant, fetch once
2. **Monitor epoch boundaries**: Set up notifications for epoch changes
3. **Claim promptly**: Rewards expire if not claimed in epoch n+1
4. **Track utilization per epoch**: Historical data helps optimize strategy
5. **Account for time zones**: All timestamps are UTC
6. **Handle epoch 0**: Genesis epoch, no rewards to claim

## Common Pitfalls

1. **Missing claim window**: Forgetting to claim in epoch n+1
2. **Wrong epoch for queries**: Using current instead of previous
3. **Not accounting for delays**: Network delays near epoch boundaries
4. **Hardcoding epoch numbers**: Always query dynamically
5. **Timezone confusion**: All times are UTC/Unix timestamps

## Related Operations

- [Claiming Rewards](./claiming-rewards.md) - Epoch-based rewards
- [Utilization Mechanics](./utilization-mechanics.md) - Per-epoch tracking
- [Depositing Assets](./depositing-assets.md) - Affects current epoch utilization

## See Also

- [Emissions System](../concepts/emissions-system.md)
- [TrustBonding Contract](../contracts/emissions/TrustBonding.md)

---

**Last Updated**: December 2025
