# Event Monitoring

Comprehensive guide to monitoring and indexing Intuition Protocol V2 events for real-time applications and analytics.

## Table of Contents

- [Overview](#overview)
- [Event Catalog](#event-catalog)
- [Subscription Patterns](#subscription-patterns)
- [Indexing Strategies](#indexing-strategies)
- [Event Processing](#event-processing)
- [Real-Time Updates](#real-time-updates)
- [Historical Queries](#historical-queries)
- [Performance Optimization](#performance-optimization)

## Overview

Intuition Protocol emits structured events for all significant state changes. Applications should monitor these events to:

- Provide real-time UI updates
- Build searchable indexes
- Track analytics and metrics
- Trigger automated workflows
- Maintain off-chain state synchronization

**Key Contracts to Monitor**:
- **MultiVault**: Atom/triple creation, deposits, redemptions, utilization tracking
- **TrustBonding**: Reward claims, emissions, bonded balance changes
- **AtomWarden**: Atom wallet ownership changes

## Event Catalog

### MultiVault Events

#### AtomCreated

Emitted when a new atom is created.

```solidity
event AtomCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes atomData,
    address atomWallet
);
```

**Use Cases**:
- Index new atoms for search
- Track atom creation rate
- Build atom explorer
- Monitor specific creators

**Example Subscription**:
```typescript
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet, event) => {
  console.log(`New atom ${termId} created by ${creator}`);
  // Index atom data...
});
```

#### TripleCreated

Emitted when a new triple is created.

```solidity
event TripleCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
);
```

**Use Cases**:
- Build knowledge graph
- Track relationship creation
- Analyze triple patterns
- Monitor subject/predicate/object usage

**Example Subscription**:
```typescript
multiVault.on('TripleCreated', (creator, termId, subjectId, predicateId, objectId, event) => {
  console.log(`Triple: ${subjectId} → ${predicateId} → ${objectId}`);
  // Build graph edge...
});
```

#### Deposited

Emitted when assets are deposited into a vault.

```solidity
event Deposited(
    address indexed sender,
    address indexed receiver,
    bytes32 indexed termId,
    uint256 curveId,
    uint256 assets,
    uint256 assetsAfterFees,
    uint256 shares,
    uint256 totalShares,
    VaultType vaultType
);
```

**Use Cases**:
- Track deposit volume
- Calculate TVL (Total Value Locked)
- Monitor user activity
- Analyze fee impact

**Example Subscription**:
```typescript
multiVault.on('Deposited', (
  sender,
  receiver,
  termId,
  curveId,
  assets,
  assetsAfterFees,
  shares,
  totalShares,
  vaultType,
  event
) => {
  const fees = assets - assetsAfterFees;
  console.log(`Deposit: ${formatEther(assets)} TRUST (${formatEther(fees)} fees)`);
  // Update TVL...
});
```

#### Redeemed

Emitted when shares are redeemed from a vault.

```solidity
event Redeemed(
    address indexed sender,
    address indexed receiver,
    bytes32 indexed termId,
    uint256 curveId,
    uint256 shares,
    uint256 totalShares,
    uint256 assets,
    uint256 fees,
    VaultType vaultType
);
```

**Use Cases**:
- Track redemption volume
- Calculate net flows
- Monitor vault exits
- Analyze redemption patterns

#### SharePriceChanged

Emitted when a vault's share price changes.

```solidity
event SharePriceChanged(
    bytes32 indexed termId,
    uint256 indexed curveId,
    uint256 sharePrice,
    uint256 totalAssets,
    uint256 totalShares,
    VaultType vaultType
);
```

**Use Cases**:
- Build price charts
- Track price movements
- Calculate APY
- Monitor bonding curve dynamics

#### PersonalUtilizationAdded / PersonalUtilizationRemoved

Emitted when a user's utilization changes.

```solidity
event PersonalUtilizationAdded(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 personalUtilization
);
```

**Use Cases**:
- Track user engagement
- Calculate utilization ratios
- Predict rewards eligibility
- Monitor user activity patterns

#### TotalUtilizationAdded / TotalUtilizationRemoved

Emitted when system-wide utilization changes.

```solidity
event TotalUtilizationAdded(
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 indexed totalUtilization
);
```

**Use Cases**:
- Monitor protocol health
- Track system-wide engagement
- Calculate system utilization ratio
- Analyze epoch trends

#### ProtocolFeeAccrued / ProtocolFeeTransferred

Track protocol fee collection and distribution.

```solidity
event ProtocolFeeAccrued(
    uint256 indexed epoch,
    address indexed sender,
    uint256 amount
);

event ProtocolFeeTransferred(
    uint256 indexed epoch,
    address indexed destination,
    uint256 amount
);
```

**Use Cases**:
- Track protocol revenue
- Monitor fee accumulation
- Analyze fee distribution
- Calculate protocol metrics

#### AtomWalletDepositFeeCollected / AtomWalletDepositFeesClaimed

Track atom wallet deposit fees.

```solidity
event AtomWalletDepositFeeCollected(
    bytes32 indexed termId,
    address indexed sender,
    uint256 amount
);

event AtomWalletDepositFeesClaimed(
    bytes32 indexed termId,
    address indexed atomWalletOwner,
    uint256 indexed feesClaimed
);
```

**Use Cases**:
- Track atom wallet earnings
- Monitor claimable fees
- Calculate atom wallet ROI

### TrustBonding Events

#### RewardsClaimed

Emitted when a user claims TRUST rewards.

```solidity
event RewardsClaimed(
    address indexed user,
    address indexed recipient,
    uint256 amount
);
```

**Use Cases**:
- Track reward distributions
- Monitor claim patterns
- Calculate total rewards distributed
- Analyze user claiming behavior

**Example Subscription**:
```typescript
trustBonding.on('RewardsClaimed', (user, recipient, amount, event) => {
  console.log(`${user} claimed ${formatEther(amount)} TRUST`);
  // Update user rewards dashboard...
});
```

## Subscription Patterns

### Basic Event Subscription

Simple event listener using ethers.js:

```typescript
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('RPC_URL');
const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, ABI, provider);

// Listen for atom creation
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet) => {
  console.log(`Atom ${termId} created`);
});

// Listen for deposits
multiVault.on('Deposited', (sender, receiver, termId, ...args) => {
  console.log(`Deposit to ${termId}`);
});

// Cleanup when done
process.on('SIGINT', () => {
  multiVault.removeAllListeners();
  process.exit(0);
});
```

### Filtered Event Subscription

Subscribe to events for specific users or terms:

```typescript
// Monitor deposits for a specific user
const userFilter = multiVault.filters.Deposited(USER_ADDRESS, null, null);
multiVault.on(userFilter, (sender, receiver, termId, ...args) => {
  console.log(`${sender} deposited to ${termId}`);
});

// Monitor all events for a specific atom
const atomFilter = multiVault.filters.Deposited(null, null, ATOM_ID);
multiVault.on(atomFilter, (sender, receiver, termId, ...args) => {
  console.log(`Deposit to atom ${ATOM_ID}`);
});

// Monitor triple creation by a specific creator
const creatorFilter = multiVault.filters.TripleCreated(CREATOR_ADDRESS);
multiVault.on(creatorFilter, (creator, termId, ...args) => {
  console.log(`${creator} created triple ${termId}`);
});
```

### Event Batching

Batch events to reduce processing overhead:

```typescript
class EventBatcher {
  private queue: any[] = [];
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private batchSize: number = 100,
    private batchDelay: number = 1000,
    private processor: (events: any[]) => Promise<void>
  ) {}

  add(event: any) {
    this.queue.push(event);

    if (this.queue.length >= this.batchSize) {
      this.flush();
    } else if (!this.timer) {
      this.timer = setTimeout(() => this.flush(), this.batchDelay);
    }
  }

  private async flush() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.queue.length === 0) return;

    const batch = this.queue.splice(0);
    await this.processor(batch);
  }
}

// Usage
const batcher = new EventBatcher(100, 1000, async (events) => {
  console.log(`Processing ${events.length} events`);
  await database.insertMany(events);
});

multiVault.on('Deposited', (sender, receiver, termId, ...args) => {
  batcher.add({ type: 'deposit', sender, receiver, termId, args });
});
```

## Indexing Strategies

### Database Schema

Recommended schema for indexing events:

```sql
-- Atoms table
CREATE TABLE atoms (
    id BYTEA PRIMARY KEY,
    creator VARCHAR(42) NOT NULL,
    data BYTEA NOT NULL,
    wallet VARCHAR(42) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash VARCHAR(66) NOT NULL
);

-- Triples table
CREATE TABLE triples (
    id BYTEA PRIMARY KEY,
    creator VARCHAR(42) NOT NULL,
    subject_id BYTEA NOT NULL,
    predicate_id BYTEA NOT NULL,
    object_id BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash VARCHAR(66) NOT NULL,
    FOREIGN KEY (subject_id) REFERENCES atoms(id),
    FOREIGN KEY (predicate_id) REFERENCES atoms(id),
    FOREIGN KEY (object_id) REFERENCES atoms(id)
);

-- Deposits table
CREATE TABLE deposits (
    id SERIAL PRIMARY KEY,
    sender VARCHAR(42) NOT NULL,
    receiver VARCHAR(42) NOT NULL,
    term_id BYTEA NOT NULL,
    curve_id INTEGER NOT NULL,
    assets NUMERIC(78, 0) NOT NULL,
    assets_after_fees NUMERIC(78, 0) NOT NULL,
    shares NUMERIC(78, 0) NOT NULL,
    total_shares NUMERIC(78, 0) NOT NULL,
    vault_type SMALLINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash VARCHAR(66) NOT NULL,
    INDEX idx_sender (sender),
    INDEX idx_term_id (term_id),
    INDEX idx_block_number (block_number)
);

-- Redemptions table
CREATE TABLE redemptions (
    id SERIAL PRIMARY KEY,
    sender VARCHAR(42) NOT NULL,
    receiver VARCHAR(42) NOT NULL,
    term_id BYTEA NOT NULL,
    curve_id INTEGER NOT NULL,
    shares NUMERIC(78, 0) NOT NULL,
    total_shares NUMERIC(78, 0) NOT NULL,
    assets NUMERIC(78, 0) NOT NULL,
    fees NUMERIC(78, 0) NOT NULL,
    vault_type SMALLINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash VARCHAR(66) NOT NULL,
    INDEX idx_sender (sender),
    INDEX idx_term_id (term_id)
);

-- Rewards table
CREATE TABLE rewards (
    id SERIAL PRIMARY KEY,
    user VARCHAR(42) NOT NULL,
    recipient VARCHAR(42) NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    epoch INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash VARCHAR(66) NOT NULL,
    INDEX idx_user (user),
    INDEX idx_epoch (epoch)
);

-- Vault states table (aggregated view)
CREATE TABLE vault_states (
    term_id BYTEA NOT NULL,
    curve_id INTEGER NOT NULL,
    total_assets NUMERIC(78, 0) NOT NULL,
    total_shares NUMERIC(78, 0) NOT NULL,
    share_price NUMERIC(78, 0) NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    block_number BIGINT NOT NULL,
    PRIMARY KEY (term_id, curve_id)
);
```

### Event Indexer Implementation

Complete event indexer with database persistence:

```typescript
import { ethers } from 'ethers';
import { Pool } from 'pg';

class EventIndexer {
  private provider: ethers.Provider;
  private contracts: {
    multiVault: ethers.Contract;
    trustBonding: ethers.Contract;
  };
  private db: Pool;
  private lastProcessedBlock: number = 0;

  constructor(rpcUrl: string, dbConfig: any) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.db = new Pool(dbConfig);
    this.initializeContracts();
  }

  async start() {
    // Load last processed block from database
    this.lastProcessedBlock = await this.getLastProcessedBlock();

    // Catch up on historical events
    await this.syncHistoricalEvents();

    // Start listening for new events
    this.subscribeToEvents();
  }

  private async syncHistoricalEvents() {
    const currentBlock = await this.provider.getBlockNumber();
    const fromBlock = this.lastProcessedBlock + 1;

    console.log(`Syncing events from block ${fromBlock} to ${currentBlock}`);

    // Fetch events in chunks to avoid RPC limits
    const chunkSize = 10000;
    for (let i = fromBlock; i <= currentBlock; i += chunkSize) {
      const toBlock = Math.min(i + chunkSize - 1, currentBlock);
      await this.processBlockRange(i, toBlock);
    }
  }

  private async processBlockRange(fromBlock: number, toBlock: number) {
    console.log(`Processing blocks ${fromBlock} to ${toBlock}`);

    // Query all events in parallel
    const [
      atomCreatedEvents,
      tripleCreatedEvents,
      depositedEvents,
      redeemedEvents,
      rewardsClaimedEvents,
    ] = await Promise.all([
      this.contracts.multiVault.queryFilter(
        this.contracts.multiVault.filters.AtomCreated(),
        fromBlock,
        toBlock
      ),
      this.contracts.multiVault.queryFilter(
        this.contracts.multiVault.filters.TripleCreated(),
        fromBlock,
        toBlock
      ),
      this.contracts.multiVault.queryFilter(
        this.contracts.multiVault.filters.Deposited(),
        fromBlock,
        toBlock
      ),
      this.contracts.multiVault.queryFilter(
        this.contracts.multiVault.filters.Redeemed(),
        fromBlock,
        toBlock
      ),
      this.contracts.trustBonding.queryFilter(
        this.contracts.trustBonding.filters.RewardsClaimed(),
        fromBlock,
        toBlock
      ),
    ]);

    // Process events
    await this.processAtomCreatedEvents(atomCreatedEvents);
    await this.processTripleCreatedEvents(tripleCreatedEvents);
    await this.processDepositedEvents(depositedEvents);
    await this.processRedeemedEvents(redeemedEvents);
    await this.processRewardsClaimedEvents(rewardsClaimedEvents);

    // Update last processed block
    await this.updateLastProcessedBlock(toBlock);
  }

  private async processAtomCreatedEvents(events: ethers.Log[]) {
    for (const event of events) {
      const parsed = this.contracts.multiVault.interface.parseLog(event);
      const block = await event.getBlock();

      await this.db.query(
        `INSERT INTO atoms (id, creator, data, wallet, created_at, block_number, tx_hash)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO NOTHING`,
        [
          parsed.args.termId,
          parsed.args.creator,
          parsed.args.atomData,
          parsed.args.atomWallet,
          new Date(block.timestamp * 1000),
          event.blockNumber,
          event.transactionHash,
        ]
      );
    }
  }

  private async processDepositedEvents(events: ethers.Log[]) {
    for (const event of events) {
      const parsed = this.contracts.multiVault.interface.parseLog(event);
      const block = await event.getBlock();

      await this.db.query(
        `INSERT INTO deposits (
          sender, receiver, term_id, curve_id, assets, assets_after_fees,
          shares, total_shares, vault_type, created_at, block_number, tx_hash
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [
          parsed.args.sender,
          parsed.args.receiver,
          parsed.args.termId,
          parsed.args.curveId,
          parsed.args.assets.toString(),
          parsed.args.assetsAfterFees.toString(),
          parsed.args.shares.toString(),
          parsed.args.totalShares.toString(),
          parsed.args.vaultType,
          new Date(block.timestamp * 1000),
          event.blockNumber,
          event.transactionHash,
        ]
      );

      // Update vault state
      await this.updateVaultState(
        parsed.args.termId,
        parsed.args.curveId,
        event.blockNumber
      );
    }
  }

  private subscribeToEvents() {
    // Subscribe to all events
    this.contracts.multiVault.on('AtomCreated', async (...args) => {
      await this.processAtomCreatedEvents([args[args.length - 1]]);
    });

    this.contracts.multiVault.on('Deposited', async (...args) => {
      await this.processDepositedEvents([args[args.length - 1]]);
    });

    // Add other event subscriptions...
  }

  private async getLastProcessedBlock(): Promise<number> {
    const result = await this.db.query(
      'SELECT value FROM indexer_state WHERE key = $1',
      ['last_processed_block']
    );
    return result.rows[0]?.value || 0;
  }

  private async updateLastProcessedBlock(blockNumber: number) {
    await this.db.query(
      `INSERT INTO indexer_state (key, value)
       VALUES ($1, $2)
       ON CONFLICT (key) DO UPDATE SET value = $2`,
      ['last_processed_block', blockNumber]
    );
    this.lastProcessedBlock = blockNumber;
  }
}
```

## Event Processing

### Handling Reorgs

Protect against blockchain reorganizations:

```typescript
class ReorgSafeIndexer {
  private confirmationBlocks = 12; // Wait for 12 confirmations

  async processEvent(event: ethers.Log) {
    const currentBlock = await this.provider.getBlockNumber();
    const confirmations = currentBlock - event.blockNumber;

    if (confirmations < this.confirmationBlocks) {
      // Queue for later processing
      await this.queuePendingEvent(event);
      return;
    }

    // Process confirmed event
    await this.processConfirmedEvent(event);
  }

  async handleReorg(reorgedBlock: number) {
    console.log(`Handling reorg at block ${reorgedBlock}`);

    // Delete events from reorged blocks
    await this.db.query(
      'DELETE FROM deposits WHERE block_number >= $1',
      [reorgedBlock]
    );
    await this.db.query(
      'DELETE FROM redemptions WHERE block_number >= $1',
      [reorgedBlock]
    );

    // Re-sync from reorg point
    await this.processBlockRange(reorgedBlock, await this.provider.getBlockNumber());
  }
}
```

### Event Transformation

Transform raw events into application-specific data:

```typescript
interface ProcessedDeposit {
  user: string;
  termId: string;
  termType: 'atom' | 'triple' | 'counter-triple';
  curveId: number;
  grossAssets: bigint;
  netAssets: bigint;
  fees: bigint;
  feePercentage: number;
  shares: bigint;
  sharePrice: bigint;
  timestamp: Date;
  txHash: string;
}

function transformDepositEvent(event: DepositedEvent): ProcessedDeposit {
  const fees = event.args.assets - event.args.assetsAfterFees;
  const feePercentage = Number(fees * 10000n / event.args.assets) / 100;
  const sharePrice = event.args.assetsAfterFees * 1000000n / event.args.shares;

  return {
    user: event.args.sender,
    termId: event.args.termId,
    termType: ['atom', 'triple', 'counter-triple'][event.args.vaultType],
    curveId: event.args.curveId,
    grossAssets: event.args.assets,
    netAssets: event.args.assetsAfterFees,
    fees,
    feePercentage,
    shares: event.args.shares,
    sharePrice,
    timestamp: new Date(event.block.timestamp * 1000),
    txHash: event.transactionHash,
  };
}
```

## Real-Time Updates

### WebSocket Event Streaming

Stream events to clients via WebSocket:

```typescript
import WebSocket from 'ws';

class EventStreamer {
  private wss: WebSocket.Server;
  private clients = new Set<WebSocket>();

  constructor(port: number) {
    this.wss = new WebSocket.Server({ port });

    this.wss.on('connection', (ws) => {
      this.clients.add(ws);

      ws.on('close', () => {
        this.clients.delete(ws);
      });
    });
  }

  broadcast(event: any) {
    const message = JSON.stringify(event);

    this.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }
}

// Usage
const streamer = new EventStreamer(8080);

multiVault.on('Deposited', (sender, receiver, termId, ...args) => {
  streamer.broadcast({
    type: 'deposit',
    sender,
    receiver,
    termId,
    // Additional data...
  });
});
```

### Server-Sent Events (SSE)

Alternative to WebSocket using HTTP streaming:

```typescript
import express from 'express';

const app = express();
const clients = new Set<express.Response>();

app.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  clients.add(res);

  req.on('close', () => {
    clients.delete(res);
  });
});

function broadcastEvent(event: any) {
  const data = `data: ${JSON.stringify(event)}\n\n`;

  clients.forEach((client) => {
    client.write(data);
  });
}

multiVault.on('AtomCreated', (creator, termId, ...args) => {
  broadcastEvent({ type: 'atom_created', creator, termId });
});

app.listen(3000);
```

## Historical Queries

### Query Recent Deposits

```typescript
async function getRecentDeposits(limit: number = 100) {
  const filter = multiVault.filters.Deposited();
  const events = await multiVault.queryFilter(filter, -10000, 'latest');

  return events
    .slice(-limit)
    .map(event => ({
      sender: event.args.sender,
      termId: event.args.termId,
      assets: event.args.assets,
      shares: event.args.shares,
      blockNumber: event.blockNumber,
    }));
}
```

### Query User Activity

```typescript
async function getUserActivity(userAddress: string, fromBlock: number) {
  const [deposits, redemptions, rewards] = await Promise.all([
    multiVault.queryFilter(
      multiVault.filters.Deposited(userAddress),
      fromBlock
    ),
    multiVault.queryFilter(
      multiVault.filters.Redeemed(userAddress),
      fromBlock
    ),
    trustBonding.queryFilter(
      trustBonding.filters.RewardsClaimed(userAddress),
      fromBlock
    ),
  ]);

  return {
    deposits: deposits.length,
    redemptions: redemptions.length,
    rewardsClaimed: rewards.length,
    totalDeposited: deposits.reduce((sum, e) => sum + e.args.assets, 0n),
    totalRedeemed: redemptions.reduce((sum, e) => sum + e.args.assets, 0n),
    totalRewards: rewards.reduce((sum, e) => sum + e.args.amount, 0n),
  };
}
```

## Performance Optimization

### Event Caching

Cache recent events to reduce RPC calls:

```typescript
class EventCache {
  private cache = new Map<string, any[]>();
  private ttl = 60000; // 1 minute

  async getEvents(
    contract: ethers.Contract,
    eventName: string,
    filter: any,
    fromBlock: number,
    toBlock: number
  ): Promise<any[]> {
    const cacheKey = `${eventName}:${fromBlock}:${toBlock}`;
    const cached = this.cache.get(cacheKey);

    if (cached) {
      return cached;
    }

    const events = await contract.queryFilter(filter, fromBlock, toBlock);
    this.cache.set(cacheKey, events);

    setTimeout(() => this.cache.delete(cacheKey), this.ttl);

    return events;
  }
}
```

## Best Practices

1. **Use Indexed Parameters**: Filter events using indexed parameters for efficiency
2. **Handle Reorgs**: Wait for block confirmations before processing events
3. **Batch Processing**: Process events in batches to improve throughput
4. **Error Handling**: Implement retry logic for failed event processing
5. **Monitoring**: Track indexer health and lag metrics
6. **Backups**: Regularly backup indexed data
7. **Rate Limiting**: Respect RPC provider rate limits

## See Also

- [SDK Design Patterns](./sdk-design-patterns.md) - SDK architecture patterns
- [Transaction Flows](./transaction-flows.md) - Transaction execution patterns
- [Subgraph Integration](./subgraph-integration.md) - The Graph indexing
- [Reference: Events](../reference/events.md) - Complete event catalog
