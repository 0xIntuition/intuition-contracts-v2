# Emissions System

Epoch-based distribution of TRUST tokens to users who lock tokens and engage with the protocol. The emissions system incentivizes long-term participation through vote-escrowed balances and utilization-based rewards.

## Table of Contents

- [Overview](#overview)
- [Epochs](#epochs)
- [Vote-Escrowed TRUST (veTRUST)](#vote-escrowed-trust-vetrust)
- [Emissions Schedule](#emissions-schedule)
- [Reward Calculation](#reward-calculation)
- [Utilization Ratios](#utilization-ratios)
- [Claiming Rewards](#claiming-rewards)
- [Cross-Chain Flow](#cross-chain-flow)
- [Best Practices](#best-practices)

## Overview

The Intuition Protocol V2 emissions system distributes new TRUST tokens to users based on three key factors:

1. **Bonded Balance (veTRUST)**: Time-weighted voting power from locked TRUST
2. **System Utilization**: Overall protocol engagement
3. **Personal Utilization**: Individual user engagement

```mermaid
graph TB
    Lock[Lock TRUST] --> veTRUST[Receive veTRUST<br/>Time-Weighted Balance]
    veTRUST --> Bonded[Bonded Balance]

    Engage[Engage with Protocol] --> PU[Personal Utilization]
    System[System Activity] --> SU[System Utilization]

    Bonded --> Rewards[Epoch Rewards]
    PU --> Rewards
    SU --> Rewards

    Rewards --> Claim[Claim TRUST]
```

**Key Characteristics**:
- **Epoch-Based**: Rewards calculated and distributed per epoch (e.g., weekly)
- **Time-Weighted**: Longer locks receive higher voting power
- **Utilization-Adjusted**: Rewards scaled by engagement
- **Cross-Chain**: Minted on base chain, distributed on satellite chains

## Epochs

### What Are Epochs?

An **epoch** is a fixed time period used for reward distribution and accounting.

**Standard Configuration**:
- **Length**: 1 week (604,800 seconds)
- **Sequential**: Epoch N followed by epoch N+1
- **Non-Overlapping**: Clear boundaries between epochs

### Epoch Lifecycle

```mermaid
stateDiagram-v2
    [*] --> EpochN: Start of epoch
    EpochN --> Active: Users deposit/redeem
    Active --> EndOfEpoch: Epoch ends
    EndOfEpoch --> Calculate: Calculate rewards
    Calculate --> EpochN1: Epoch N+1 starts
    EpochN1 --> Claimable: Previous epoch rewards claimable
    Claimable --> [*]: Claim window closes
```

### Epoch Queries

```javascript
const TRUST_BONDING_ADDRESS = '0x2B0c2700BB0E9Ea294c7c6Ea5C5c42cC0dba3583';
const trustBonding = new ethers.Contract(TRUST_BONDING_ADDRESS, TRUST_BONDING_ABI, provider);

// Get current epoch
const currentEpoch = await trustBonding.currentEpoch();
console.log(`Current epoch: ${currentEpoch}`);

// Get epoch length
const epochLength = await trustBonding.epochLength();
console.log(`Epoch length: ${epochLength} seconds`);

// Get epoch end time
const epochEnd = await trustBonding.epochTimestampEnd(currentEpoch);
const timeRemaining = epochEnd - Math.floor(Date.now() / 1000);
console.log(`Time until epoch end: ${timeRemaining} seconds`);

// Get epoch from timestamp
const timestamp = Math.floor(Date.now() / 1000);
const epochAtTime = await trustBonding.epochAtTimestamp(timestamp);
```

## Vote-Escrowed TRUST (veTRUST)

### Concept

**veTRUST** is a time-weighted representation of locked TRUST tokens. The longer you lock, the more voting power (veTRUST) you receive.

**Based on Curve Finance's ve-model**:
- Lock TRUST for up to 2 years
- Receive veTRUST (voting power)
- veTRUST decays linearly over time
- Cannot transfer veTRUST

### Calculation

```
veTRUST = lockedAmount × (timeRemaining / MAXTIME)

where:
- lockedAmount = TRUST tokens locked
- timeRemaining = seconds until unlock
- MAXTIME = 2 years (63,072,000 seconds)
```

### Visual Representation

```
veTRUST Balance
    |
100 |●
    | \
 75 |  \
    |   \
 50 |    \
    |     \
 25 |      \
    |       \
  0 |________●_______
    0      1y      2y
         Time Remaining
```

### Lock Mechanics

**Creating a Lock**:

```javascript
// Approve TRUST spending
await trustToken.approve(TRUST_BONDING_ADDRESS, lockAmount);

// Lock for 2 years (maximum veTRUST)
const twoYears = 2 * 365 * 24 * 60 * 60;
const unlockTime = Math.floor(Date.now() / 1000) + twoYears;

await trustBonding.create_lock(lockAmount, unlockTime);

// Query veTRUST balance
const veTrustBalance = await trustBonding.balanceOf(userAddress);
console.log(`veTRUST balance: ${ethers.formatEther(veTrustBalance)}`);
```

**Increasing Lock Amount**:

```javascript
// Add more TRUST to existing lock
await trustToken.approve(TRUST_BONDING_ADDRESS, additionalAmount);
await trustBonding.increase_amount(additionalAmount);
```

**Extending Lock Time**:

```javascript
// Extend unlock time (up to MAXTIME from now)
const newUnlockTime = Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60);
await trustBonding.increase_unlock_time(newUnlockTime);
```

**Withdrawing After Expiry**:

```javascript
// Check if lock has expired
const lockEnd = await trustBonding.locked__end(userAddress);
const now = Math.floor(Date.now() / 1000);

if (now >= lockEnd) {
  await trustBonding.withdraw();
  console.log('TRUST withdrawn successfully');
}
```

## Emissions Schedule

### Total Supply Cap

```
Maximum TRUST Supply: 1,000,000,000 (1 billion)
```

### Emission Calculation

Emissions per epoch are determined by:

```javascript
// Get emissions for specific epoch
const emissions = await trustBonding.emissionsForEpoch(epochNumber);
console.log(`Epoch ${epochNumber} emissions: ${ethers.formatEther(emissions)} TRUST`);

// Emissions are calculated by BaseEmissionsController
// Formula varies based on:
// - Total TRUST supply
// - Locked percentage
// - Emission schedule
```

### Distribution Formula

For each user in an epoch:

```
userRewards = (userBondedBalance / totalBondedBalance) × epochEmissions
            × systemUtilizationRatio × personalUtilizationRatio
```

**Components**:
1. **Base Share**: Proportional to user's veTRUST vs total veTRUST
2. **System Adjustment**: Scaled by overall protocol utilization
3. **Personal Adjustment**: Scaled by individual user utilization

## Reward Calculation

### Base Rewards

```javascript
// Get user's bonded balance at epoch end
const userBonded = await trustBonding.userBondedBalanceAtEpochEnd(
  userAddress,
  previousEpoch
);

// Get total bonded balance
const totalBonded = await trustBonding.totalBondedBalanceAtEpochEnd(previousEpoch);

// Get epoch emissions
const emissions = await trustBonding.emissionsForEpoch(previousEpoch);

// Calculate base rewards
const baseRewards = (userBonded * emissions) / totalBonded;
console.log(`Base rewards: ${ethers.formatEther(baseRewards)} TRUST`);
```

### Adjusted Rewards

```javascript
// Get utilization ratios
const systemRatio = await trustBonding.getSystemUtilizationRatio(previousEpoch);
const personalRatio = await trustBonding.getPersonalUtilizationRatio(
  userAddress,
  previousEpoch
);

// Calculate final rewards
const finalRewards = baseRewards
  * systemRatio / 10000n    // System adjustment
  * personalRatio / 10000n; // Personal adjustment

console.log(`Final eligible rewards: ${ethers.formatEther(finalRewards)} TRUST`);
```

### User Info Query

```javascript
// Get comprehensive user information
const userInfo = await trustBonding.getUserInfo(userAddress, previousEpoch);

console.log('User Info:');
console.log(`  Personal Utilization: ${userInfo.personalUtilization}`);
console.log(`  Eligible Rewards: ${ethers.formatEther(userInfo.eligibleRewards)}`);
console.log(`  Max Rewards: ${ethers.formatEther(userInfo.maxRewards)}`);
console.log(`  Locked Amount: ${ethers.formatEther(userInfo.lockedAmount)}`);
console.log(`  Lock End: ${new Date(Number(userInfo.lockEnd) * 1000)}`);
console.log(`  Bonded Balance: ${ethers.formatEther(userInfo.bondedBalance)}`);
```

## Utilization Ratios

### System Utilization Ratio

Measures overall protocol engagement:

```
systemUtilization = totalDeposits - totalRedemptions (for epoch)

systemUtilizationRatio = max(
  lowerBound,
  min(1.0, systemUtilization / totalBondedBalance)
)
```

**Bounds**:
- **Lower Bound**: 40% (0.4) - Minimum ratio
- **Upper Bound**: 100% (1.0) - Maximum ratio

**Meaning**:
- 100%: System highly utilized, full rewards
- 40-100%: Moderate usage, scaled rewards
- <40%: Floored at 40%

### Personal Utilization Ratio

Measures individual user engagement:

```
personalUtilization = userDeposits - userRedemptions (for epoch)

personalUtilizationRatio = max(
  lowerBound,
  min(1.0, personalUtilization / userBondedBalance)
)
```

**Bounds**:
- **Lower Bound**: 25% (0.25) - Minimum ratio
- **Upper Bound**: 100% (1.0) - Maximum ratio

**Meaning**:
- 100%: User highly engaged, full rewards
- 25-100%: Moderate engagement, scaled rewards
- <25%: Floored at 25%

See [Utilization Tracking](./utilization-tracking.md) for detailed mechanics.

## Claiming Rewards

### Claim Window

```
Rewards for epoch N are claimable during epoch N+1
```

**Timeline**:
1. **Epoch N**: User participates (deposits/redemptions)
2. **Epoch N ends**: Rewards calculated
3. **Epoch N+1**: Rewards become claimable
4. **Epoch N+2 starts**: Unclaimed rewards from epoch N are forfeited

### Claiming Process

```javascript
async function claimRewards() {
  const currentEpoch = await trustBonding.currentEpoch();
  const previousEpoch = currentEpoch - 1n;

  // Check if rewards available
  const hasClaimedRewardsForEpoch(userAddress, previousEpoch);

  if (alreadyClaimed) {
    console.log('Rewards already claimed for this epoch');
    return;
  }

  // Query eligible rewards
  const eligibleRewards = await trustBonding.userEligibleRewardsForEpoch(
    userAddress,
    previousEpoch
  );

  if (eligibleRewards === 0n) {
    console.log('No rewards to claim');
    return;
  }

  console.log(`Eligible rewards: ${ethers.formatEther(eligibleRewards)} TRUST`);

  // Claim rewards
  const tx = await trustBonding.claimRewards(userAddress); // recipient
  const receipt = await tx.wait();

  // Parse RewardsClaimed event
  const claimedEvent = receipt.logs.find(log => {
    try {
      const parsed = trustBonding.interface.parseLog(log);
      return parsed.name === 'RewardsClaimed';
    } catch {
      return false;
    }
  });

  if (claimedEvent) {
    const { amount } = trustBonding.interface.parseLog(claimedEvent).args;
    console.log(`Claimed ${ethers.formatEther(amount)} TRUST!`);
  }
}
```

### Auto-Claim Strategies

```javascript
class RewardsClaimer {
  async autoClaim() {
    // Check rewards every hour
    setInterval(async () => {
      const currentEpoch = await trustBonding.currentEpoch();
      const previousEpoch = currentEpoch - 1n;

      const alreadyClaimed = await trustBonding.hasClaimedRewardsForEpoch(
        userAddress,
        previousEpoch
      );

      if (!alreadyClaimed) {
        const rewards = await trustBonding.userEligibleRewardsForEpoch(
          userAddress,
          previousEpoch
        );

        if (rewards > 0n) {
          console.log('Auto-claiming rewards...');
          await claimRewards();
        }
      }
    }, 3600000); // 1 hour
  }

  async claimBeforeEpochEnd() {
    const currentEpoch = await trustBonding.currentEpoch();
    const epochEnd = await trustBonding.epochTimestampEnd(currentEpoch);
    const now = Math.floor(Date.now() / 1000);
    const timeUntilEnd = epochEnd - now;

    // Claim 1 hour before epoch ends
    if (timeUntilEnd <= 3600) {
      await claimRewards();
    }
  }
}
```

## Cross-Chain Flow

The emissions system operates across two chains:

```mermaid
sequenceDiagram
    participant Base as Base Chain<br/>(BaseEmissionsController)
    participant Satellite as Satellite Chain<br/>(SatelliteEmissionsController)
    participant TB as TrustBonding
    participant User

    Note over Base: Epoch N ends
    Base->>Base: Calculate emissions for epoch N
    Base->>Base: Mint TRUST tokens
    Base->>Satellite: Bridge TRUST via MetaERC20
    Satellite->>TB: Transfer bridged TRUST
    TB->>TB: Rewards now claimable
    User->>TB: claimRewards()
    TB->>User: Transfer TRUST

    Note over TB: Epoch N+1 ends
    TB->>TB: Calculate unclaimed from epoch N
    TB->>Satellite: Report unclaimed amount
    Satellite->>Base: Bridge unclaimed back
    Base->>Base: Burn unclaimed TRUST
```

**Key Points**:
- **Minting**: Only on base chain (Base Mainnet)
- **Distribution**: On satellite chains (Intuition Mainnet)
- **Burning**: Unclaimed rewards sent back to base chain and burned

See [Cross-Chain Architecture](./cross-chain-architecture.md) for details.

## Best Practices

### 1. Lock for Maximum Duration

```javascript
// Maximum veTRUST: Lock for 2 years
const twoYears = 2 * 365 * 24 * 60 * 60;
const unlockTime = Math.floor(Date.now() / 1000) + twoYears;

await trustBonding.create_lock(lockAmount, unlockTime);

// This gives you 1:1 veTRUST to TRUST ratio
```

### 2. Maintain High Utilization

```javascript
// Track your utilization ratio
async function checkUtilization() {
  const currentEpoch = await trustBonding.currentEpoch();
  const ratio = await trustBonding.getPersonalUtilizationRatio(
    userAddress,
    currentEpoch
  );

  console.log(`Your utilization ratio: ${ratio / 100}%`);

  if (ratio < 5000) { // Less than 50%
    console.log('Consider increasing protocol engagement for higher rewards');
  }
}
```

### 3. Claim Rewards Early

```javascript
// Claim as soon as eligible to avoid forfeit
async function claimEarly() {
  const currentEpoch = await trustBonding.currentEpoch();

  // Wait a few blocks into new epoch to ensure rewards are calculated
  const blockNumber = await provider.getBlockNumber();

  // Then claim immediately
  await claimRewards();
}
```

### 4. Monitor Lock Expiry

```javascript
async function monitorLock() {
  const lockEnd = await trustBonding.locked__end(userAddress);
  const now = Math.floor(Date.now() / 1000);
  const daysUntilExpiry = (lockEnd - now) / 86400;

  if (daysUntilExpiry < 30) {
    console.log(`Lock expires in ${daysUntilExpiry.toFixed(1)} days`);
    console.log('Consider extending your lock to maintain veTRUST');

    // Auto-extend if desired
    const newUnlockTime = Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60);
    await trustBonding.increase_unlock_time(newUnlockTime);
  }
}
```

### 5. Calculate Expected APY

```javascript
async function estimateAPY() {
  const currentEpoch = await trustBonding.currentEpoch();

  // Get emissions per epoch
  const emissions = await trustBonding.emissionsForEpoch(currentEpoch);

  // Get total bonded balance
  const totalBonded = await trustBonding.totalBondedBalanceAtEpochEnd(currentEpoch);

  // Get user bonded balance
  const userBonded = await trustBonding.userBondedBalanceAtEpochEnd(
    userAddress,
    currentEpoch
  );

  // Get epochs per year
  const epochsPerYear = await trustBonding.epochsPerYear();

  // Calculate APY (assuming 100% utilization)
  const userRewardsPerEpoch = (userBonded * emissions) / totalBonded;
  const annualRewards = userRewardsPerEpoch * BigInt(epochsPerYear);
  const apy = (annualRewards * 10000n) / userBonded; // Basis points

  console.log(`Estimated APY: ${Number(apy) / 100}%`);
  console.log(`(Assumes 100% system and personal utilization)`);
}
```

## See Also

- [Utilization Tracking](./utilization-tracking.md) - How utilization affects rewards
- [Cross-Chain Architecture](./cross-chain-architecture.md) - Multi-chain emissions flow
- [Claiming Rewards Guide](../guides/claiming-rewards.md) - Step-by-step claiming
- [TrustBonding Contract](../contracts/emissions/TrustBonding.md) - Contract reference

---

**Last Updated**: December 2025
