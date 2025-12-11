# Gas Benchmarks Reference

Detailed gas cost measurements for Intuition Protocol V2 operations.

## Table of Contents

- [Core Operations](#core-operations)
- [Batch Operations](#batch-operations)
- [Reward Operations](#reward-operations)
- [Configuration Operations](#configuration-operations)
- [Gas Optimization Tips](#gas-optimization-tips)

## Core Operations

### Atom Creation

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Create first atom (with wallet deployment) | ~450,000 - 500,000 | Includes AtomWallet deployment |
| Create atom (wallet exists) | ~250,000 - 300,000 | Wallet already deployed |
| Create atom + initial deposit | ~500,000 - 550,000 | Includes first vault deposit |

**Factors Affecting Gas**:
- Atom data size (larger data = more gas)
- Whether atom wallet needs deployment
- Initial deposit amount (bonding curve calculation)

**Example Measurement**:
```
Atom Data: 32 bytes
Initial Deposit: 10 TRUST
Curve: Linear (ID: 1)

Gas Used: 487,234
At 20 gwei: ~0.0097 ETH
At 50 gwei: ~0.0244 ETH
```

---

### Triple Creation

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Create triple (atoms exist) | ~600,000 - 700,000 | Includes deposits to 3 underlying atoms |
| Create triple + deposit | ~650,000 - 750,000 | With initial deposit to triple vault |
| Create counter-triple vault | ~150,000 - 200,000 | Counter vault initialization |

**Gas Breakdown**:
```
Triple Creation (650,000 total):
- Validation: ~10,000
- Triple vault init: ~100,000
- Counter-triple vault init: ~100,000
- Deposits to 3 atoms: ~300,000 (3 × 100,000)
- Utilization tracking: ~50,000
- Events emission: ~90,000
```

---

### Deposit Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| First deposit to vault | ~180,000 - 220,000 | Initializes vault state |
| Subsequent deposit | ~120,000 - 150,000 | Vault already exists |
| Deposit to atom vault | ~150,000 - 180,000 | Includes atom wallet fee tracking |
| Deposit to triple vault | ~200,000 - 250,000 | Includes atom fraction deposits |

**Gas by Curve Type**:
```
Linear Curve:     ~120,000 (simple calculation)
Progressive:      ~140,000 (quadratic math)
Offset Progressive: ~150,000 (additional parameters)
```

---

### Redemption Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Redeem shares | ~100,000 - 130,000 | Standard redemption |
| Last redemption (no exit fee) | ~90,000 - 110,000 | Slightly less gas |
| Redeem all shares | ~100,000 - 120,000 | Complete exit |

---

### Vault Queries (View Functions)

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| getVault() | ~5,000 | Read vault state |
| getShares() | ~3,000 | Read user shares |
| previewDeposit() | ~8,000 - 15,000 | Includes curve calculation |
| previewRedeem() | ~8,000 - 15,000 | Includes curve calculation |
| currentSharePrice() | ~6,000 | Calculate share price |

**Note**: View functions don't cost gas when called externally, but these estimates apply when called from other contracts.

## Batch Operations

### Batch Deposits

| Batch Size | Total Gas | Gas Per Deposit | Savings |
|------------|-----------|-----------------|---------|
| 1 deposit | ~150,000 | 150,000 | 0% |
| 2 deposits | ~240,000 | 120,000 | 20% |
| 5 deposits | ~500,000 | 100,000 | 33% |
| 10 deposits | ~900,000 | 90,000 | 40% |
| 20 deposits | ~1,700,000 | 85,000 | 43% |

**Savings Breakdown**:
```
Single Transaction Overhead: ~21,000 gas
Per-Operation Overhead: ~30,000 gas
Core Operation: ~90,000 gas

Single: 21,000 + 30,000 + 90,000 = 141,000
Batch (10): 21,000 + (10 × 30,000) + (10 × 90,000) = 1,221,000
Average: 122,100 per operation (13% savings)
```

---

### Batch Redemptions

| Batch Size | Total Gas | Gas Per Redemption | Savings |
|------------|-----------|-------------------|---------|
| 1 redemption | ~120,000 | 120,000 | 0% |
| 2 redemptions | ~200,000 | 100,000 | 17% |
| 5 redemptions | ~450,000 | 90,000 | 25% |
| 10 redemptions | ~850,000 | 85,000 | 29% |

---

### Batch Atom Creation

| Batch Size | Total Gas | Gas Per Atom | Savings |
|------------|-----------|--------------|---------|
| 1 atom | ~500,000 | 500,000 | 0% |
| 2 atoms | ~900,000 | 450,000 | 10% |
| 5 atoms | ~2,100,000 | 420,000 | 16% |
| 10 atoms | ~4,000,000 | 400,000 | 20% |

**Note**: Block gas limit may restrict batch size (typically 30M gas per block).

## Reward Operations

### Claim Rewards

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Claim rewards (single epoch) | ~100,000 - 120,000 | Standard claim |
| Claim rewards (no rewards) | ~50,000 - 60,000 | Reverts, but costs gas |
| First claim (checkpoint creation) | ~130,000 - 150,000 | Creates user checkpoint |

**Gas Breakdown**:
```
Claim Rewards (120,000 total):
- Epoch validation: ~5,000
- Utilization queries: ~30,000
- Reward calculation: ~20,000
- Balance updates: ~40,000
- TRUST minting: ~20,000
- Event emission: ~5,000
```

---

### Bond/Lock TRUST

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Create lock (first time) | ~150,000 - 180,000 | Initial lock creation |
| Increase lock amount | ~80,000 - 100,000 | Add to existing lock |
| Extend lock time | ~70,000 - 90,000 | Extend duration |
| Withdraw (after expiry) | ~80,000 - 100,000 | Unlock and withdraw |

## Configuration Operations

### Admin Functions

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Update GeneralConfig | ~50,000 - 70,000 | Update protocol parameters |
| Update VaultFees | ~40,000 - 50,000 | Update fee configuration |
| Add BondingCurve | ~100,000 - 120,000 | Register new curve |
| Sweep protocol fees | ~80,000 - 100,000 | Transfer accumulated fees |
| Pause/Unpause | ~30,000 - 40,000 | Toggle pause state |

---

### Atom Wallet Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Deploy atom wallet | ~200,000 - 250,000 | CREATE2 deployment |
| Claim wallet ownership | ~80,000 - 100,000 | Transfer ownership |
| Claim wallet deposit fees | ~60,000 - 80,000 | Withdraw accumulated fees |

## Gas Optimization Tips

### 1. Use Batch Operations

**Bad** (5 separate transactions):
```typescript
for (let i = 0; i < 5; i++) {
  await multiVault.deposit(receiver, termIds[i], 1, amounts[i], 0n);
  // Total gas: 5 × 150,000 = 750,000
}
```

**Good** (1 batch transaction):
```typescript
await multiVault.depositBatch(receiver, termIds, [1,1,1,1,1], amounts, [0n,0n,0n,0n,0n]);
// Total gas: ~500,000 (33% savings)
```

---

### 2. Avoid Unnecessary State Reads

**Bad** (multiple reads):
```typescript
const vault1 = await multiVault.getVault(termId1, 1);
const vault2 = await multiVault.getVault(termId2, 1);
const vault3 = await multiVault.getVault(termId3, 1);
// 3 separate RPC calls
```

**Good** (parallel reads):
```typescript
const [vault1, vault2, vault3] = await Promise.all([
  multiVault.getVault(termId1, 1),
  multiVault.getVault(termId2, 1),
  multiVault.getVault(termId3, 1),
]);
// 1 RPC round trip
```

---

### 3. Use Preview Functions

Always preview operations to estimate gas and validate inputs:

```typescript
// Preview before executing
const [expectedShares] = await multiVault.previewDeposit(termId, curveId, assets);

if (expectedShares < minAcceptableShares) {
  console.log('Insufficient shares, skipping');
  return; // Avoid wasting gas on failed transaction
}

// Execute with confidence
await multiVault.deposit(receiver, termId, curveId, assets, expectedShares * 99n / 100n);
```

---

### 4. Optimize Calldata

**Bad** (large calldata):
```typescript
const atomData = ethers.toUtf8Bytes('Very long atom data string that wastes calldata space...');
// Calldata: ~100 bytes × 16 gas = 1,600 gas
```

**Good** (compact calldata):
```typescript
const atomData = ethers.randomBytes(32); // Compact representation
// Calldata: 32 bytes × 16 gas = 512 gas (savings: ~1,088 gas)
```

---

### 5. Time Transactions for Low Gas

```typescript
async function waitForLowGas(maxGwei: number): Promise<void> {
  while (true) {
    const feeData = await provider.getFeeData();
    const currentGwei = Number(formatUnits(feeData.gasPrice || 0n, 'gwei'));

    if (currentGwei <= maxGwei) {
      console.log(`Gas price acceptable: ${currentGwei} gwei`);
      return;
    }

    console.log(`Waiting for gas to drop below ${maxGwei} gwei (current: ${currentGwei})`);
    await new Promise(resolve => setTimeout(resolve, 60000)); // Check every minute
  }
}

// Use it
await waitForLowGas(20); // Wait for < 20 gwei
await multiVault.deposit(...);
```

---

### 6. Set Appropriate Gas Limits

```typescript
// Estimate gas
const gasEstimate = await multiVault.deposit.estimateGas(...params);

// Add 20% buffer
const gasLimit = (gasEstimate * 120n) / 100n;

// Execute with proper limit
await multiVault.deposit(...params, { gasLimit });
```

## Gas Cost Calculator

Estimate costs at different gas prices:

```typescript
function estimateCost(gasUsed: number, gweiPrice: number): {
  eth: string;
  usd: string;
} {
  const weiCost = BigInt(gasUsed) * BigInt(gweiPrice) * 1_000_000_000n;
  const ethCost = Number(weiCost) / 1e18;
  const usdCost = ethCost * 2000; // Assume $2000 ETH

  return {
    eth: ethCost.toFixed(6),
    usd: usdCost.toFixed(2),
  };
}

// Example usage
const cost = estimateCost(500_000, 20); // 500k gas at 20 gwei
console.log(`Cost: ${cost.eth} ETH ($${cost.usd})`);
// Output: Cost: 0.010000 ETH ($20.00)
```

## Benchmark Methodology

Gas costs measured on Ethereum mainnet using:
- Solidity 0.8.29
- Optimization enabled (200 runs)
- Block gas limit: 30,000,000
- Test conditions: Various vault states and user positions

**Variation Factors**:
- Storage slots accessed (SLOAD: 2,100 gas, SSTORE: 20,000 gas)
- Contract state (cold vs warm access)
- Calldata size (16 gas per non-zero byte)
- Event log data size

## See Also

- [Gas Optimization Guide](../integration/gas-optimization.md) - Optimization strategies
- [Batch Operations Guide](../guides/batch-operations.md) - Using batch functions
- [Transaction Flows](../integration/transaction-flows.md) - Transaction patterns
