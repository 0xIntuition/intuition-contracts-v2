# Utilization Mechanics

## Overview

Utilization tracking is the core mechanism that determines reward eligibility in the Intuition Protocol. Your utilization score represents your net contribution to the protocol - deposits increase it, redemptions decrease it. Rewards are distributed based on both personal and system-wide utilization ratios.

This guide explains how utilization is calculated, tracked, and used for rewards.

**Key Concepts**:
- Personal utilization: Your individual net position per epoch
- System utilization: Protocol-wide net position per epoch
- Utilization ratio: Comparison against bonded balance
- Last active epochs: Tracking for historical queries

## Prerequisites

### Required Knowledge
- Understanding of [epochs](./epoch-management.md)
- Familiarity with [emissions system](../concepts/emissions-system.md)
- Knowledge of vault deposits and redemptions

### Contracts Needed
- **MultiVault**: Tracks utilization
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
- **TrustBonding**: Calculates utilization ratios
  - Mainnet: Check deployment addresses

## How Utilization Works

### Personal Utilization

**Definition**: Net value of your deposits minus redemptions in an epoch

**Formula**: `personalUtilization = Σ(deposits) - Σ(redemptions)`

**Characteristics**:
- Signed integer (can be positive or negative)
- Tracked per epoch
- Positive = net depositor → eligible for rewards
- Negative = net redeemer → not eligible for rewards
- Zero = no net activity → no rewards

**Example**:
```
Epoch 5 activity:
- Deposit 100 WTRUST → utilization = +100
- Deposit 50 WTRUST → utilization = +150
- Redeem 30 WTRUST → utilization = +120 (net depositor)

Epoch 6 activity:
- Redeem 200 WTRUST → utilization = -200 (net redeemer, no rewards)
```

### System Utilization

**Definition**: Protocol-wide net deposits minus redemptions in an epoch

**Formula**: `systemUtilization = Σ(all deposits) - Σ(all redemptions)`

**Characteristics**:
- Aggregate of all users' personal utilization
- Tracked per epoch
- Used to calculate system-wide reward multiplier
- Affects all users' reward calculations

### Utilization Ratios

**Personal Utilization Ratio**:
```
personalRatio = min(
  personalUtilization / bondedBalance,
  systemUtilizationLowerBound
)
```

**System Utilization Ratio**:
```
systemRatio = min(
  systemUtilization / totalBondedBalance,
  systemUtilizationLowerBound
)
```

**Reward Multiplier**:
```
rewardMultiplier = min(personalRatio, systemRatio)
```

Your rewards are capped by the smaller of your personal ratio or the system ratio. This prevents gaming by ensuring individual rewards scale with overall protocol usage.

## Step-by-Step Guide

### Step 1: Query Your Current Epoch Utilization

```typescript
const currentEpoch = await multiVault.currentEpoch();
const myUtilization = await multiVault.getUserUtilizationForEpoch(
  myAddress,
  currentEpoch
);

console.log('Current epoch:', currentEpoch);
console.log('My utilization:', myUtilization);

if (myUtilization > 0) {
  console.log('Net depositor - eligible for rewards');
} else if (myUtilization < 0) {
  console.log('Net redeemer - not eligible for rewards');
} else {
  console.log('No net activity this epoch');
}
```

### Step 2: Query Historical Utilization

```typescript
const previousEpoch = await multiVault.currentEpoch() - 1n;
const lastEpochUtilization = await multiVault.getUserUtilizationForEpoch(
  myAddress,
  previousEpoch
);

console.log('Previous epoch utilization:', lastEpochUtilization);
```

### Step 3: Check System Utilization

```typescript
const systemUtilization = await multiVault.getTotalUtilizationForEpoch(
  currentEpoch
);

console.log('System utilization:', systemUtilization);
console.log('Protocol is', systemUtilization > 0 ? 'growing' : 'shrinking');
```

### Step 4: Get Your Last Active Epoch

```typescript
const lastActiveEpoch = await multiVault.getUserLastActiveEpoch(myAddress);

console.log('Last active epoch:', lastActiveEpoch);
console.log('Epochs since last activity:', currentEpoch - lastActiveEpoch);
```

### Step 5: Calculate Utilization Ratio

```typescript
const trustBonding = new ethers.Contract(TRUST_BONDING_ADDRESS, TrustBondingABI, provider);

const personalRatio = await trustBonding.getPersonalUtilizationRatio(
  myAddress,
  currentEpoch
);

const systemRatio = await trustBonding.getSystemUtilizationRatio(currentEpoch);

console.log('Personal ratio:', Number(personalRatio) / 1e18);
console.log('System ratio:', Number(systemRatio) / 1e18);
console.log('Your reward multiplier:', Math.min(
  Number(personalRatio) / 1e18,
  Number(systemRatio) / 1e18
));
```

### Step 6: Track Utilization Changes

```typescript
// Listen for utilization events
multiVault.on('PersonalUtilizationAdded', (user, epoch, valueAdded, newUtilization) => {
  if (user === myAddress) {
    console.log(`Utilization increased by ${valueAdded} in epoch ${epoch}`);
    console.log(`New utilization: ${newUtilization}`);
  }
});

multiVault.on('PersonalUtilizationRemoved', (user, epoch, valueRemoved, newUtilization) => {
  if (user === myAddress) {
    console.log(`Utilization decreased by ${valueRemoved} in epoch ${epoch}`);
    console.log(`New utilization: ${newUtilization}`);
  }
});
```

### Step 7: Optimize for Maximum Rewards

```typescript
async function optimizeUtilization() {
  const currentEpoch = await multiVault.currentEpoch();
  const myUtilization = await multiVault.getUserUtilizationForEpoch(
    myAddress,
    currentEpoch
  );

  const userInfo = await trustBonding.getUserInfo(myAddress);
  const bondedBalance = userInfo.bondedBalance;

  if (bondedBalance > 0n) {
    // Calculate optimal utilization
    const personalRatio = Number(myUtilization) / Number(bondedBalance);

    console.log('Current personal ratio:', personalRatio);

    if (personalRatio < 1.0) {
      const additionalDeposit = bondedBalance - myUtilization;
      console.log('Consider depositing:', ethers.formatEther(additionalDeposit), 'WTRUST');
      console.log('This would maximize your utilization ratio to 1.0');
    }
  } else {
    console.log('Lock TRUST tokens to establish bonded balance');
  }
}
```

## Code Examples

### TypeScript (ethers.js v6)

Comprehensive utilization tracking utility:

```typescript
import { ethers } from 'ethers';

interface UtilizationSnapshot {
  epoch: bigint;
  personalUtilization: bigint;
  systemUtilization: bigint;
  personalRatio: number;
  systemRatio: number;
  rewardMultiplier: number;
  bondedBalance: bigint;
}

class UtilizationTracker {
  private multiVault: ethers.Contract;
  private trustBonding: ethers.Contract;

  constructor(
    multiVaultAddress: string,
    trustBondingAddress: string,
    provider: ethers.Provider
  ) {
    this.multiVault = new ethers.Contract(
      multiVaultAddress,
      MultiVaultABI,
      provider
    );
    this.trustBonding = new ethers.Contract(
      trustBondingAddress,
      TrustBondingABI,
      provider
    );
  }

  async getSnapshot(
    userAddress: string,
    epoch?: bigint
  ): Promise<UtilizationSnapshot> {
    if (!epoch) {
      epoch = await this.multiVault.currentEpoch();
    }

    const [
      personalUtilization,
      systemUtilization,
      personalRatio,
      systemRatio,
      userInfo
    ] = await Promise.all([
      this.multiVault.getUserUtilizationForEpoch(userAddress, epoch),
      this.multiVault.getTotalUtilizationForEpoch(epoch),
      this.trustBonding.getPersonalUtilizationRatio(userAddress, epoch),
      this.trustBonding.getSystemUtilizationRatio(epoch),
      this.trustBonding.getUserInfo(userAddress)
    ]);

    const rewardMultiplier = Math.min(
      Number(personalRatio) / 1e18,
      Number(systemRatio) / 1e18
    );

    return {
      epoch,
      personalUtilization,
      systemUtilization,
      personalRatio: Number(personalRatio) / 1e18,
      systemRatio: Number(systemRatio) / 1e18,
      rewardMultiplier,
      bondedBalance: userInfo.bondedBalance
    };
  }

  async getUtilizationHistory(
    userAddress: string,
    epochCount: number
  ): Promise<UtilizationSnapshot[]> {
    const currentEpoch = await this.multiVault.currentEpoch();
    const startEpoch = currentEpoch >= BigInt(epochCount)
      ? currentEpoch - BigInt(epochCount) + 1n
      : 0n;

    const snapshots: UtilizationSnapshot[] = [];

    for (let epoch = startEpoch; epoch <= currentEpoch; epoch++) {
      try {
        const snapshot = await this.getSnapshot(userAddress, epoch);
        snapshots.push(snapshot);
      } catch (error) {
        // Epoch might not have data, skip
        console.log(`No data for epoch ${epoch}`);
      }
    }

    return snapshots;
  }

  formatSnapshot(snapshot: UtilizationSnapshot): string {
    return `
=== Epoch ${snapshot.epoch} Utilization ===
Personal utilization: ${snapshot.personalUtilization}
System utilization: ${snapshot.systemUtilization}
Personal ratio: ${snapshot.personalRatio.toFixed(4)}
System ratio: ${snapshot.systemRatio.toFixed(4)}
Reward multiplier: ${snapshot.rewardMultiplier.toFixed(4)}
Bonded balance: ${ethers.formatEther(snapshot.bondedBalance)} TRUST
Status: ${snapshot.personalUtilization > 0 ? 'Eligible for rewards' : 'Not eligible'}
    `.trim();
  }

  async trackRealtime(userAddress: string, callback: (event: any) => void) {
    // Listen for utilization changes
    this.multiVault.on('PersonalUtilizationAdded', async (user, epoch, valueAdded, utilization, event) => {
      if (user.toLowerCase() === userAddress.toLowerCase()) {
        callback({
          type: 'added',
          user,
          epoch,
          valueAdded,
          utilization,
          block: event.log.blockNumber
        });
      }
    });

    this.multiVault.on('PersonalUtilizationRemoved', async (user, epoch, valueRemoved, utilization, event) => {
      if (user.toLowerCase() === userAddress.toLowerCase()) {
        callback({
          type: 'removed',
          user,
          epoch,
          valueRemoved,
          utilization,
          block: event.log.blockNumber
        });
      }
    });
  }
}

// Usage example
async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const tracker = new UtilizationTracker(
    MULTIVAULT_ADDRESS,
    TRUST_BONDING_ADDRESS,
    provider
  );

  // Get current snapshot
  const snapshot = await tracker.getSnapshot('0xYourAddress');
  console.log(tracker.formatSnapshot(snapshot));

  // Get history
  const history = await tracker.getUtilizationHistory('0xYourAddress', 10);
  console.log(`\nUtilization over last ${history.length} epochs:`);
  history.forEach(s => console.log(`Epoch ${s.epoch}: ${s.personalUtilization}`));

  // Track real-time
  await tracker.trackRealtime('0xYourAddress', (event) => {
    console.log(`Utilization ${event.type}:`, event.valueAdded || event.valueRemoved);
    console.log('New utilization:', event.utilization);
  });
}
```

### Python (web3.py)

```python
from web3 import Web3
import json
from typing import List, Dict

class UtilizationTracker:
    def __init__(self, multivault_address: str, trust_bonding_address: str, rpc_url: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))

        with open('abis/IMultiVault.json') as f:
            multivault_abi = json.load(f)
        with open('abis/ITrustBonding.json') as f:
            trust_bonding_abi = json.load(f)

        self.multivault = self.w3.eth.contract(
            address=Web3.to_checksum_address(multivault_address),
            abi=multivault_abi
        )
        self.trust_bonding = self.w3.eth.contract(
            address=Web3.to_checksum_address(trust_bonding_address),
            abi=trust_bonding_abi
        )

    def get_snapshot(self, user_address: str, epoch: int = None) -> Dict:
        """Get utilization snapshot for an epoch"""
        if epoch is None:
            epoch = self.multivault.functions.currentEpoch().call()

        personal_utilization = self.multivault.functions.getUserUtilizationForEpoch(
            user_address, epoch
        ).call()

        system_utilization = self.multivault.functions.getTotalUtilizationForEpoch(
            epoch
        ).call()

        personal_ratio = self.trust_bonding.functions.getPersonalUtilizationRatio(
            user_address, epoch
        ).call()

        system_ratio = self.trust_bonding.functions.getSystemUtilizationRatio(
            epoch
        ).call()

        user_info = self.trust_bonding.functions.getUserInfo(user_address).call()

        return {
            'epoch': epoch,
            'personal_utilization': personal_utilization,
            'system_utilization': system_utilization,
            'personal_ratio': personal_ratio / 1e18,
            'system_ratio': system_ratio / 1e18,
            'reward_multiplier': min(personal_ratio / 1e18, system_ratio / 1e18),
            'bonded_balance': user_info[5]  # bondedBalance field
        }

    def format_snapshot(self, snapshot: Dict) -> str:
        """Format snapshot for display"""
        return f"""
=== Epoch {snapshot['epoch']} Utilization ===
Personal utilization: {snapshot['personal_utilization']}
System utilization: {snapshot['system_utilization']}
Personal ratio: {snapshot['personal_ratio']:.4f}
System ratio: {snapshot['system_ratio']:.4f}
Reward multiplier: {snapshot['reward_multiplier']:.4f}
Bonded balance: {Web3.from_wei(snapshot['bonded_balance'], 'ether')} TRUST
Status: {'Eligible for rewards' if snapshot['personal_utilization'] > 0 else 'Not eligible'}
        """.strip()

if __name__ == '__main__':
    tracker = UtilizationTracker(
        '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e',
        '0x...',  # TrustBonding address
        'YOUR_RPC_URL'
    )

    snapshot = tracker.get_snapshot('0xYourAddress')
    print(tracker.format_snapshot(snapshot))
```

## Event Monitoring

### Events Emitted

#### PersonalUtilizationAdded
```solidity
event PersonalUtilizationAdded(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 personalUtilization
);
```

#### PersonalUtilizationRemoved
```solidity
event PersonalUtilizationRemoved(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 personalUtilization
);
```

#### TotalUtilizationAdded
```solidity
event TotalUtilizationAdded(
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 indexed totalUtilization
);
```

#### TotalUtilizationRemoved
```solidity
event TotalUtilizationRemoved(
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 indexed totalUtilization
);
```

## Common Errors

1. **Invalid Epoch**: Querying future or very old epochs
2. **No Active Epoch**: User has never deposited/redeemed
3. **Negative Utilization**: Net redeemer, not eligible for rewards

## Best Practices

### 1. Maintain Positive Utilization
```typescript
// Keep net deposits positive to earn rewards
const utilization = await multiVault.getUserUtilizationForEpoch(address, epoch);
if (utilization <= 0) {
  console.log('Deposit more to become eligible for rewards');
}
```

### 2. Track Across Epochs
```typescript
// Monitor utilization trends
const history = await getUtilizationHistory(address, 10);
const trend = history[history.length - 1].personalUtilization >
              history[0].personalUtilization ? 'increasing' : 'decreasing';
```

### 3. Optimize Ratio
```typescript
// Maximize reward multiplier
const optimalUtilization = bondedBalance; // 1:1 ratio
const currentUtilization = await getUserUtilization(address, epoch);
const additionalDeposit = optimalUtilization - currentUtilization;
```

### 4. Monitor System Utilization
```typescript
// System ratio can cap your rewards
if (systemRatio < personalRatio) {
  console.log('Your rewards capped by system utilization');
}
```

### 5. Don't Miss Epochs
```typescript
// Rewards based on previous epoch
// Ensure positive utilization each epoch to qualify
```

## Common Pitfalls

1. **Negative utilization**: Redemptions exceed deposits
2. **Zero bonded balance**: No locked TRUST = zero ratio
3. **Missing epoch boundary**: Not tracking when epoch changes
4. **Ignoring system ratio**: Personal ratio doesn't guarantee high rewards
5. **Late deposits**: Activity counted in current epoch, rewards next epoch

## Related Operations

- [Depositing Assets](./depositing-assets.md) - Increases utilization
- [Redeeming Shares](./redeeming-shares.md) - Decreases utilization
- [Claiming Rewards](./claiming-rewards.md) - Based on utilization
- [Epoch Management](./epoch-management.md) - Utilization per epoch

## See Also

- [Emissions System](../concepts/emissions-system.md)
- [Utilization Tracking Concept](../concepts/utilization-tracking.md)
- [TrustBonding Contract](../contracts/emissions/TrustBonding.md)
- [MultiVault Contract](../contracts/core/MultiVault.md)

---

**Last Updated**: December 2025
