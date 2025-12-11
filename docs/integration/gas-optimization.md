# Gas Optimization

Strategies and techniques for minimizing gas costs when interacting with Intuition Protocol V2.

## Table of Contents

- [Overview](#overview)
- [Gas Cost Analysis](#gas-cost-analysis)
- [Batch Operations](#batch-operations)
- [Calldata Optimization](#calldata-optimization)
- [Storage Access Patterns](#storage-access-patterns)
- [Transaction Timing](#transaction-timing)
- [Advanced Techniques](#advanced-techniques)

## Overview

Gas optimization is crucial for cost-effective protocol interactions. This guide covers:

- Understanding gas costs for common operations
- Using batch operations to reduce overhead
- Optimizing calldata and storage access
- Timing transactions for lower gas prices

**Key Optimization Strategies**:
1. Use batch operations when possible
2. Minimize calldata size
3. Reduce storage reads/writes
4. Time transactions during low-demand periods
5. Use appropriate gas limits

## Gas Cost Analysis

### Typical Operation Costs

Estimated gas costs for common operations (approximate):

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `deposit()` | ~150,000 - 200,000 | First deposit to vault costs more |
| `redeem()` | ~100,000 - 150,000 | Depends on vault state |
| `createAtoms()` (single) | ~400,000 - 500,000 | Includes wallet deployment |
| `createTriples()` (single) | ~600,000 - 800,000 | Includes deposits to underlying atoms |
| `depositBatch()` (5 vaults) | ~600,000 - 800,000 | ~120k per vault |
| `redeemBatch()` (5 vaults) | ~400,000 - 600,000 | ~80k per vault |
| `claimRewards()` | ~100,000 - 150,000 | Depends on epochs claimed |

**Gas Savings with Batching**:
- Single operations have ~21,000 base cost per transaction
- Batch operations amortize this cost across multiple operations
- Batching 5 deposits saves ~84,000 gas (4 × 21,000)

### Gas Cost Profiling

Profile gas costs for your specific use case:

```typescript
async function profileGasCosts() {
  const operations = [
    {
      name: 'Single Deposit',
      fn: async () => multiVault.deposit(
        await signer.getAddress(),
        atomId,
        1,
        parseEther('10'),
        0n
      ),
    },
    {
      name: 'Batch Deposit (5)',
      fn: async () => multiVault.depositBatch(
        await signer.getAddress(),
        [atomId, atomId2, atomId3, atomId4, atomId5],
        [1, 1, 1, 1, 1],
        [parseEther('10'), parseEther('10'), parseEther('10'), parseEther('10'), parseEther('10')],
        [0n, 0n, 0n, 0n, 0n]
      ),
    },
  ];

  for (const op of operations) {
    const gasEstimate = await op.fn.estimateGas();
    const gasPrice = (await signer.provider!.getFeeData()).gasPrice!;
    const cost = gasEstimate * gasPrice;

    console.log(`${op.name}:`);
    console.log(`  Gas: ${gasEstimate.toLocaleString()}`);
    console.log(`  Cost: ${formatEther(cost)} ETH`);
  }
}
```

## Batch Operations

### Batch Deposits

Deposit to multiple vaults in a single transaction:

```typescript
async function batchDeposit(
  deposits: Array<{
    termId: string;
    curveId: number;
    assets: bigint;
    minShares: bigint;
  }>
): Promise<TransactionResult> {
  const receiver = await signer.getAddress();

  // Prepare arrays for batch call
  const termIds = deposits.map(d => d.termId);
  const curveIds = deposits.map(d => d.curveId);
  const assets = deposits.map(d => d.assets);
  const minShares = deposits.map(d => d.minShares);

  // Execute batch deposit
  const tx = await multiVault.depositBatch(
    receiver,
    termIds,
    curveIds,
    assets,
    minShares
  );

  return await tx.wait();
}

// Usage
const result = await batchDeposit([
  { termId: atom1, curveId: 1, assets: parseEther('10'), minShares: 0n },
  { termId: atom2, curveId: 1, assets: parseEther('20'), minShares: 0n },
  { termId: triple1, curveId: 2, assets: parseEther('15'), minShares: 0n },
]);

// Gas savings: ~63,000 gas (3 × 21,000 base cost)
```

### Batch Redemptions

Redeem from multiple vaults in a single transaction:

```typescript
async function batchRedeem(
  redemptions: Array<{
    termId: string;
    curveId: number;
    shares: bigint;
    minAssets: bigint;
  }>
): Promise<TransactionResult> {
  const receiver = await signer.getAddress();

  const termIds = redemptions.map(r => r.termId);
  const curveIds = redemptions.map(r => r.curveId);
  const shares = redemptions.map(r => r.shares);
  const minAssets = redemptions.map(r => r.minAssets);

  const tx = await multiVault.redeemBatch(
    receiver,
    termIds,
    curveIds,
    shares,
    minAssets
  );

  return await tx.wait();
}
```

### Batch Atom Creation

Create multiple atoms in a single transaction:

```typescript
async function createAtomsBatch(
  atoms: Array<{
    data: string;
    assets: bigint;
  }>,
  curveId: number = 1
): Promise<{ atomIds: string[]; result: TransactionResult }> {
  const atomDatas = atoms.map(a => a.data);
  const assets = atoms.map(a => a.assets);

  // Preview to get minimum shares
  const totalAssets = assets.reduce((sum, a) => sum + a, 0n);
  const minShares = totalAssets / 100n; // 1% slippage

  const tx = await multiVault.createAtoms(
    atomDatas,
    assets,
    curveId,
    await signer.getAddress(),
    minShares
  );

  const receipt = await tx.wait();

  // Extract atom IDs from events
  const atomIds = receipt.logs
    .filter(log => log.topics[0] === ATOM_CREATED_TOPIC)
    .map(log => log.topics[1]);

  return { atomIds, result: receipt };
}

// Usage - create 3 atoms at once
const { atomIds } = await createAtomsBatch([
  { data: '0x...', assets: parseEther('10') },
  { data: '0x...', assets: parseEther('20') },
  { data: '0x...', assets: parseEther('30') },
]);

// Gas savings: ~42,000 gas (2 × 21,000 base cost)
```

## Calldata Optimization

### Minimize Calldata Size

Calldata costs 16 gas per non-zero byte and 4 gas per zero byte:

```typescript
// LESS EFFICIENT: Using strings
const atomData = ethers.toUtf8Bytes('my-atom-data-string');

// MORE EFFICIENT: Using compact bytes
const atomData = ethers.hexlify(ethers.randomBytes(32)); // 32 bytes max

// LESS EFFICIENT: Redundant data
await multiVault.deposit(
  '0x1234567890123456789012345678901234567890', // Full address
  termId,
  curveId,
  parseEther('10.123456789123456789'), // Full precision
  0n
);

// MORE EFFICIENT: Simplified where possible
await multiVault.deposit(
  await signer.getAddress(), // Let SDK handle
  termId,
  curveId,
  parseEther('10.12'), // Round to needed precision
  0n
);
```

### Use Multicall Pattern

Combine multiple calls efficiently:

```typescript
// Multicall interface
interface Call {
  target: string;
  data: string;
}

async function multicall(calls: Call[]): Promise<string[]> {
  // Use a multicall contract or library
  const multicallContract = new ethers.Contract(
    MULTICALL_ADDRESS,
    MULTICALL_ABI,
    provider
  );

  const results = await multicallContract.aggregate.staticCall(calls);
  return results.returnData;
}

// Batch multiple read calls
const calls: Call[] = [
  {
    target: multiVault.address,
    data: multiVault.interface.encodeFunctionData('getVault', [termId1, 1]),
  },
  {
    target: multiVault.address,
    data: multiVault.interface.encodeFunctionData('getVault', [termId2, 1]),
  },
  {
    target: multiVault.address,
    data: multiVault.interface.encodeFunctionData('getShares', [user, termId1, 1]),
  },
];

const results = await multicall(calls);

// Decode results
const vault1 = multiVault.interface.decodeFunctionResult('getVault', results[0]);
const vault2 = multiVault.interface.decodeFunctionResult('getVault', results[1]);
const shares = multiVault.interface.decodeFunctionResult('getShares', results[2]);
```

## Storage Access Patterns

### Cache Frequently Accessed Data

Reduce on-chain reads by caching locally:

```typescript
class VaultStateCache {
  private cache = new Map<string, {
    vault: { totalAssets: bigint; totalShares: bigint };
    timestamp: number;
  }>();

  private ttl = 30000; // 30 seconds

  async getVault(
    termId: string,
    curveId: number
  ): Promise<{ totalAssets: bigint; totalShares: bigint }> {
    const key = `${termId}:${curveId}`;
    const cached = this.cache.get(key);

    if (cached && Date.now() - cached.timestamp < this.ttl) {
      return cached.vault;
    }

    // Fetch from chain
    const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
    const vault = { totalAssets, totalShares };

    this.cache.set(key, { vault, timestamp: Date.now() });

    return vault;
  }
}

// Usage
const cache = new VaultStateCache();

// First call: reads from chain
const vault1 = await cache.getVault(termId, 1);

// Second call within 30s: uses cache (saves gas estimation costs)
const vault2 = await cache.getVault(termId, 1);
```

### Batch State Queries

Query multiple state variables in parallel:

```typescript
async function getUserPortfolio(user: string): Promise<Portfolio> {
  // Instead of sequential calls, query in parallel
  const [
    atom1Shares,
    atom2Shares,
    atom3Shares,
    bondedBalance,
    pendingRewards,
  ] = await Promise.all([
    multiVault.getShares(user, atom1, 1),
    multiVault.getShares(user, atom2, 1),
    multiVault.getShares(user, atom3, 1),
    trustBonding.balanceOf(user),
    trustBonding.getUserRewardsForEpoch(user, await trustBonding.previousEpoch()),
  ]);

  return {
    shares: [atom1Shares, atom2Shares, atom3Shares],
    bondedBalance,
    pendingRewards,
  };
}
```

## Transaction Timing

### Gas Price Monitoring

Wait for favorable gas prices:

```typescript
async function waitForLowGas(
  maxGasPrice: bigint,
  checkInterval: number = 10000, // 10 seconds
  timeout: number = 300000 // 5 minutes
): Promise<void> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    const feeData = await provider.getFeeData();
    const currentGasPrice = feeData.gasPrice || 0n;

    console.log(`Current gas price: ${formatUnits(currentGasPrice, 'gwei')} gwei`);

    if (currentGasPrice <= maxGasPrice) {
      console.log('Gas price acceptable, proceeding...');
      return;
    }

    console.log(`Waiting for gas price to drop below ${formatUnits(maxGasPrice, 'gwei')} gwei...`);
    await sleep(checkInterval);
  }

  throw new Error('Timeout waiting for low gas price');
}

// Usage
await waitForLowGas(parseUnits('20', 'gwei')); // Wait for < 20 gwei
await deposit(termId, curveId, assets, minShares);
```

### Off-Peak Timing

Execute transactions during off-peak hours:

```typescript
function isOffPeakHour(): boolean {
  const hour = new Date().getUTCHours();

  // Ethereum typically has lower gas prices:
  // - Weekend mornings (UTC)
  // - Late night US time (4-10 UTC)
  const offPeakHours = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  return offPeakHours.includes(hour);
}

async function executeWhenCheap(
  fn: () => Promise<any>,
  maxGasPrice?: bigint
): Promise<any> {
  if (!isOffPeakHour() && maxGasPrice) {
    console.log('Peak hour detected, waiting for acceptable gas price...');
    await waitForLowGas(maxGasPrice);
  }

  return await fn();
}
```

## Advanced Techniques

### Flash Accounting

For read-only operations, use static calls instead of transactions:

```typescript
// INEFFICIENT: Sending transaction for read operation
const tx = await multiVault.getVault(termId, curveId);
await tx.wait(); // Wastes gas

// EFFICIENT: Use view function
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
// No gas cost!
```

### Proxy Pattern for Frequent Users

Deploy a proxy contract for frequent operations:

```solidity
// ProxyDepositor.sol
contract ProxyDepositor {
    IMultiVault public immutable multiVault;
    IERC20 public immutable trust;

    constructor(address _multiVault, address _trust) {
        multiVault = IMultiVault(_multiVault);
        trust = IERC20(_trust);

        // Approve once during deployment
        trust.approve(_multiVault, type(uint256).max);
    }

    function depositMany(
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    ) external {
        // Transfer TRUST from user
        uint256 total = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            total += assets[i];
        }

        trust.transferFrom(msg.sender, address(this), total);

        // Execute batch deposit (saves approval gas for each deposit)
        multiVault.depositBatch(
            msg.sender,
            termIds,
            curveIds,
            assets,
            minShares
        );
    }
}
```

### EIP-2930 Access Lists

Use access lists for predictable storage access:

```typescript
async function depositWithAccessList(
  termId: string,
  curveId: number,
  assets: bigint,
  minShares: bigint
): Promise<TransactionResult> {
  // Create access list
  const accessList = await provider.send('eth_createAccessList', [
    {
      from: await signer.getAddress(),
      to: multiVault.address,
      data: multiVault.interface.encodeFunctionData('deposit', [
        await signer.getAddress(),
        termId,
        curveId,
        assets,
        minShares,
      ]),
    },
  ]);

  // Send transaction with access list
  const tx = await multiVault.deposit(
    await signer.getAddress(),
    termId,
    curveId,
    assets,
    minShares,
    {
      accessList: accessList.accessList,
    }
  );

  return await tx.wait();
}
```

### Signature-Based Approvals (EIP-2612)

Use permit() instead of approve() to save a transaction:

```typescript
// If TRUST token supports EIP-2612 permit
async function depositWithPermit(
  termId: string,
  curveId: number,
  assets: bigint,
  minShares: bigint
): Promise<TransactionResult> {
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour

  // Sign permit
  const signature = await signPermit(
    trustToken,
    await signer.getAddress(),
    multiVault.address,
    assets,
    deadline
  );

  // Execute permit + deposit in MultiVault
  // (This would require MultiVault to support depositWithPermit)
  const tx = await multiVault.depositWithPermit(
    await signer.getAddress(),
    termId,
    curveId,
    assets,
    minShares,
    deadline,
    signature.v,
    signature.r,
    signature.s
  );

  return await tx.wait();
}
```

## Gas Optimization Checklist

- [ ] Use batch operations for multiple actions
- [ ] Minimize calldata size (compact encodings)
- [ ] Cache frequently accessed data
- [ ] Query state in parallel
- [ ] Monitor gas prices before submitting
- [ ] Consider off-peak timing for non-urgent transactions
- [ ] Use static calls for read operations
- [ ] Implement retry logic with gas price adjustments
- [ ] Add 10-20% buffer to gas estimates
- [ ] Use multicall for multiple read operations
- [ ] Consider access lists for complex transactions
- [ ] Profile gas costs for your specific use case

## Gas Cost Comparison

| Scenario | Single Transactions | Batch Transaction | Savings |
|----------|---------------------|-------------------|---------|
| 5 Deposits | ~1,000,000 gas | ~700,000 gas | 30% |
| 3 Atom Creations | ~1,500,000 gas | ~1,200,000 gas | 20% |
| 10 Redemptions | ~1,500,000 gas | ~1,000,000 gas | 33% |

## Best Practices

1. **Batch Operations**: Always prefer batch operations for multiple actions
2. **Gas Price Awareness**: Monitor gas prices and time transactions accordingly
3. **Estimate Gas**: Always estimate gas before submitting transactions
4. **Cache Data**: Cache on-chain data to reduce read operations
5. **Optimize Calldata**: Use compact data encodings
6. **Test Gas Costs**: Profile gas costs in your development environment
7. **User Configuration**: Allow users to set gas price limits

## See Also

- [Transaction Flows](./transaction-flows.md) - Transaction execution patterns
- [Batch Operations Guide](../guides/batch-operations.md) - Detailed batch operation guide
- [Reference: Gas Benchmarks](../reference/gas-benchmarks.md) - Detailed gas cost data
