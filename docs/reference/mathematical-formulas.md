# Mathematical Formulas Reference

Mathematical formulas and calculations used in Intuition Protocol V2 bonding curves and reward systems.

## Table of Contents

- [Bonding Curve Mathematics](#bonding-curve-mathematics)
- [Reward Calculations](#reward-calculations)
- [Utilization Ratios](#utilization-ratios)
- [Voting Escrow Decay](#voting-escrow-decay)
- [Fee Calculations](#fee-calculations)

## Bonding Curve Mathematics

### Linear Curve

The simplest bonding curve with constant 1:1 pricing.

**Assets to Shares**:
```
shares = assets × MULTIPLIER
where MULTIPLIER = 1e18
```

**Shares to Assets**:
```
assets = shares × MULTIPLIER
```

**Implementation**:
```solidity
function assetsToShares(uint256 assets, uint256, uint256) public pure returns (uint256) {
    return assets;
}

function sharesToAssets(uint256 shares, uint256, uint256) public pure returns (uint256) {
    return shares;
}
```

**Characteristics**:
- Price per share: Always 1.0
- No slippage
- Ideal for stable deposits

---

### Progressive Curve

Quadratic bonding curve where price increases with supply.

**Share Price Formula**:
```
price(supply) = a × supply² + b × supply + c
```

**Assets to Shares** (Integral):
```
Given:
  - currentSupply: Current total shares
  - depositAssets: Assets to deposit

Calculate shares such that:
  ∫[currentSupply to currentSupply+shares] price(s) ds = depositAssets
```

**Implementation** (Simplified):
```solidity
function assetsToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
) public pure returns (uint256 shares) {
    if (totalShares == 0) {
        return assets; // Initial deposit
    }

    // Quadratic formula application
    uint256 a = CURVE_PARAMETER_A;
    uint256 b = CURVE_PARAMETER_B;

    // Calculate shares using inverse of integral
    shares = calculateQuadraticShares(assets, totalShares, a, b);
}
```

**Characteristics**:
- Price increases quadratically
- Higher deposits face higher prices
- Discourages large single deposits

---

### Offset Progressive Curve

Progressive curve with configurable offset parameter.

**Formula**:
```
price(supply) = a × (supply + offset)² + b × (supply + offset) + c
```

**Purpose**: The offset shifts the curve, allowing different starting points.

**Use Cases**:
- Start at higher base price
- Adjust curve sensitivity
- Fine-tune price discovery

---

### Curve Math Library

**Fixed-Point Arithmetic**:
```
All calculations use 18 decimal precision (1e18)

Example:
  100.5 TRUST = 100.5 × 10^18 = 100500000000000000000
```

**Overflow Protection**:
```solidity
// Always check for overflows
if (a > type(uint256).max / b) {
    revert Overflow();
}

uint256 result = a * b / MULTIPLIER;
```

## Reward Calculations

### Eligible Rewards Formula

```
eligibleRewards = epochEmissions × systemUtilizationRatio × personalUtilizationRatio
```

**Where**:
- `epochEmissions`: Total TRUST emitted for the epoch
- `systemUtilizationRatio`: Bounded system utilization ratio
- `personalUtilizationRatio`: Bounded personal utilization ratio

---

### Maximum Rewards Formula

```
maxRewards = eligibleRewards × userBondedShare
```

**Where**:
```
userBondedShare = userBondedBalance / totalBondedBalance
```

---

### Actual Claimable Rewards

```
claimableRewards = min(eligibleRewards, maxRewards)
```

**TypeScript Implementation**:
```typescript
function calculateRewards(
  epochEmissions: bigint,
  personalUtilization: bigint,
  systemUtilization: bigint,
  userBondedBalance: bigint,
  totalBondedBalance: bigint,
  personalLowerBound: bigint,
  systemLowerBound: bigint
): bigint {
  // Calculate ratios
  const personalRatio = calculateUtilizationRatio(
    personalUtilization,
    totalBondedBalance,
    personalLowerBound
  );

  const systemRatio = calculateUtilizationRatio(
    systemUtilization,
    totalBondedBalance,
    systemLowerBound
  );

  // Calculate eligible rewards
  const eligibleRewards =
    (epochEmissions * systemRatio * personalRatio) / (1e18n * 1e18n);

  // Calculate user share
  const userShare = totalBondedBalance > 0n
    ? (userBondedBalance * 1e18n) / totalBondedBalance
    : 0n;

  // Calculate max rewards
  const maxRewards = (eligibleRewards * userShare) / 1e18n;

  return maxRewards; // Returns the lesser of eligible and max
}
```

## Utilization Ratios

### Formula

```
utilizationRatio = max(lowerBound, min(1e18, utilization / totalBondedBalance))
```

**Where**:
- `utilization`: Net deposits minus redemptions for the epoch
- `totalBondedBalance`: Total veTRUST at epoch end
- `lowerBound`: Minimum ratio (e.g., 0.1 = 10%)

**Bounds**:
- Minimum: `lowerBound`
- Maximum: `1e18` (100%)

**TypeScript Implementation**:
```typescript
function calculateUtilizationRatio(
  utilization: bigint,
  totalBondedBalance: bigint,
  lowerBound: bigint
): bigint {
  if (totalBondedBalance === 0n) {
    return lowerBound;
  }

  const ratio = (utilization * 1e18n) / totalBondedBalance;

  // Apply bounds
  if (ratio < lowerBound) {
    return lowerBound;
  }

  if (ratio > 1e18n) {
    return 1e18n;
  }

  return ratio;
}
```

### Negative Utilization

When redemptions exceed deposits, utilization can be negative:

```
If utilization < 0:
  ratio = lowerBound (minimum penalty)
```

## Voting Escrow Decay

### Linear Decay Formula

```
veTRUST(t) = lockedAmount × (lockEnd - t) / MAXTIME
```

**Where**:
- `lockedAmount`: Amount of TRUST locked
- `lockEnd`: Timestamp when lock expires
- `t`: Current timestamp
- `MAXTIME`: Maximum lock duration (2 years)

**Example**:
```
User locks 1000 TRUST for 2 years

At t=0 (lock start):
  veTRUST = 1000 × (2 years) / (2 years) = 1000

At t=1 year:
  veTRUST = 1000 × (1 year) / (2 years) = 500

At t=2 years (lock end):
  veTRUST = 1000 × (0) / (2 years) = 0
```

**TypeScript Implementation**:
```typescript
function calculateVeTrust(
  lockedAmount: bigint,
  lockEnd: bigint,
  currentTime: bigint,
  maxTime: bigint
): bigint {
  if (currentTime >= lockEnd) {
    return 0n;
  }

  const timeRemaining = lockEnd - currentTime;
  return (lockedAmount * timeRemaining) / maxTime;
}
```

### Bonded Balance at Epoch

```
bondedBalance(epoch) = veTRUST(epochEndTime)
```

The bonded balance is snapshots at the end of each epoch.

## Fee Calculations

### Protocol Fee

Applied on both deposits and redemptions:

```
protocolFee = assets × protocolFeeBasisPoints / BASIS_POINTS
netAssets = assets - protocolFee

where BASIS_POINTS = 10000
```

**Example**:
- `protocolFeeBasisPoints = 50` (0.5%)
- `assets = 1000 TRUST`
- `protocolFee = 1000 × 50 / 10000 = 5 TRUST`
- `netAssets = 1000 - 5 = 995 TRUST`

---

### Entry Fee

Applied on deposits (except first deposit to vault):

```
if (vault.totalShares > 0) {
    entryFee = assetsAfterProtocolFee × entryFeeBasisPoints / BASIS_POINTS
    netAssets = assetsAfterProtocolFee - entryFee
} else {
    entryFee = 0
    netAssets = assetsAfterProtocolFee
}
```

**Purpose**: Entry fee stays in vault, benefiting existing shareholders.

---

### Exit Fee

Applied on redemptions (except last redemption):

```
if (vault.totalShares - sharesRedeemed > 0) {
    exitFee = assetsBeforeExitFee × exitFeeBasisPoints / BASIS_POINTS
    netAssets = assetsBeforeExitFee - exitFee
} else {
    exitFee = 0
    netAssets = assetsBeforeExitFee
}
```

**Purpose**: Exit fee discourages quick exits, stays in vault.

---

### Atom Wallet Deposit Fee

Applied on deposits to atom vaults:

```
atomWalletFee = assets × atomWalletDepositFeeBasisPoints / BASIS_POINTS
```

**Purpose**: Accumulated fees claimable by atom wallet owner.

---

### Complete Deposit Fee Calculation

```
1. Protocol Fee:
   protocolFee = assets × protocolFeeBasisPoints / BASIS_POINTS
   afterProtocol = assets - protocolFee

2. Atom Wallet Fee (atom vaults only):
   atomWalletFee = afterProtocol × atomWalletFeeBasisPoints / BASIS_POINTS
   afterAtomWallet = afterProtocol - atomWalletFee

3. Entry Fee (if not first deposit):
   if (totalShares > 0) {
       entryFee = afterAtomWallet × entryFeeBasisPoints / BASIS_POINTS
       finalAssets = afterAtomWallet - entryFee
   } else {
       finalAssets = afterAtomWallet
   }

4. Convert to shares via bonding curve:
   shares = bondingCurve.assetsToShares(finalAssets, totalAssets, totalShares)
```

## Emission Schedule

### Emissions Per Epoch

```
emissions(epoch) = initialEmissions × (1 - reductionRate)^periods

where:
  periods = max(0, (epoch - cliff) / reductionInterval)
```

**Example**:
- `initialEmissions = 1,000,000 TRUST`
- `reductionRate = 0.02` (2%)
- `cliff = 52 epochs`
- `reductionInterval = 13 epochs` (quarterly)

```
Epoch 0-51:   1,000,000 TRUST per epoch
Epoch 52-64:  1,000,000 × 0.98 = 980,000 TRUST
Epoch 65-77:  980,000 × 0.98 = 960,400 TRUST
...
```

## APY Calculations

### User APY Estimate

```
APY = (annualRewards / bondedBalance) × 100%

where:
  annualRewards = rewardsPerEpoch × epochsPerYear
  epochsPerYear = 365 days / epochLength
```

**Example**:
```
User has 1000 veTRUST bonded
Earning 10 TRUST per epoch
Epoch length = 7 days
Epochs per year = 52

APY = (10 × 52 / 1000) × 100% = 52%
```

## Best Practices

1. **Fixed-Point Math**: Always use 1e18 precision for calculations
2. **Overflow Checks**: Verify calculations won't overflow uint256
3. **Rounding**: Be aware of rounding errors in division
4. **Bounds**: Apply appropriate bounds to prevent edge cases
5. **Gas Optimization**: Pre-calculate constants where possible

## See Also

- [Bonding Curves Concept](../concepts/bonding-curves.md) - Curve mechanics
- [Emissions System](../concepts/emissions-system.md) - Reward distribution
- [Utilization Tracking](../concepts/utilization-tracking.md) - Utilization mechanics
