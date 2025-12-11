# Subgraph Integration

Guide to integrating with The Graph protocol for indexing and querying Intuition Protocol V2 data.

## Table of Contents

- [Overview](#overview)
- [Subgraph Schema](#subgraph-schema)
- [Event Handlers](#event-handlers)
- [GraphQL Queries](#graphql-queries)
- [Client Integration](#client-integration)
- [Performance Optimization](#performance-optimization)
- [Deployment](#deployment)

## Overview

The Graph protocol provides efficient indexing and querying of blockchain data. This guide covers building and integrating a subgraph for Intuition Protocol.

**Benefits of Subgraph Integration**:
- Fast, indexed queries of historical data
- Complex filtering and aggregations
- Real-time data updates
- Reduced RPC load
- GraphQL query interface

**Prerequisites**:
- Familiarity with GraphQL
- Understanding of The Graph protocol
- Node.js development environment
- Graph CLI installed (`npm install -g @graphprotocol/graph-cli`)

## Subgraph Schema

### Complete Schema Definition

Create `schema.graphql`:

```graphql
# Core entities
type Atom @entity {
  id: ID! # atomId (bytes32)
  creator: Bytes! # address
  data: Bytes! # atom data
  wallet: Bytes! # atom wallet address
  createdAt: BigInt!
  createdAtBlock: BigInt!
  createdTxHash: Bytes!

  # Relationships
  vaults: [Vault!]! @derivedFrom(field: "term")
  asSubject: [Triple!]! @derivedFrom(field: "subject")
  asPredicate: [Triple!]! @derivedFrom(field: "predicate")
  asObject: [Triple!]! @derivedFrom(field: "object")

  # Aggregations
  totalDeposits: BigInt!
  totalRedemptions: BigInt!
  totalVolume: BigInt!
}

type Triple @entity {
  id: ID! # tripleId (bytes32)
  creator: Bytes! # address
  subject: Atom!
  predicate: Atom!
  object: Atom!
  counterTriple: Bytes! # counterTripleId
  createdAt: BigInt!
  createdAtBlock: BigInt!
  createdTxHash: Bytes!

  # Relationships
  vaults: [Vault!]! @derivedFrom(field: "term")

  # Aggregations
  totalDeposits: BigInt!
  totalRedemptions: BigInt!
  totalVolume: BigInt!
}

type Vault @entity {
  id: ID! # termId-curveId
  term: Bytes! # termId (either atomId or tripleId)
  termType: VaultType!
  curveId: BigInt!
  totalAssets: BigInt!
  totalShares: BigInt!
  sharePrice: BigInt!
  createdAt: BigInt!
  updatedAt: BigInt!

  # Relationships
  deposits: [Deposit!]! @derivedFrom(field: "vault")
  redemptions: [Redemption!]! @derivedFrom(field: "vault")
  positions: [Position!]! @derivedFrom(field: "vault")

  # Aggregations
  depositCount: BigInt!
  redemptionCount: BigInt!
  uniqueDepositors: BigInt!
}

enum VaultType {
  ATOM
  TRIPLE
  COUNTER_TRIPLE
}

type Position @entity {
  id: ID! # user-termId-curveId
  user: User!
  vault: Vault!
  shares: BigInt!
  averageEntryPrice: BigInt!
  createdAt: BigInt!
  updatedAt: BigInt!
}

type User @entity {
  id: ID! # address
  positions: [Position!]! @derivedFrom(field: "user")
  deposits: [Deposit!]! @derivedFrom(field: "sender")
  redemptions: [Redemption!]! @derivedFrom(field: "sender")
  rewardsClaimed: [RewardClaim!]! @derivedFrom(field: "user")

  # Aggregations
  totalDeposited: BigInt!
  totalRedeemed: BigInt!
  totalRewardsClaimed: BigInt!
  bondedBalance: BigInt!
  depositCount: BigInt!
  redemptionCount: BigInt!
}

type Deposit @entity {
  id: ID! # txHash-logIndex
  sender: User!
  receiver: Bytes!
  vault: Vault!
  assets: BigInt!
  assetsAfterFees: BigInt!
  shares: BigInt!
  totalShares: BigInt!
  sharePrice: BigInt!
  timestamp: BigInt!
  blockNumber: BigInt!
  txHash: Bytes!
}

type Redemption @entity {
  id: ID! # txHash-logIndex
  sender: User!
  receiver: Bytes!
  vault: Vault!
  shares: BigInt!
  totalShares: BigInt!
  assets: BigInt!
  fees: BigInt!
  sharePrice: BigInt!
  timestamp: BigInt!
  blockNumber: BigInt!
  txHash: Bytes!
}

type RewardClaim @entity {
  id: ID! # txHash-logIndex
  user: User!
  recipient: Bytes!
  amount: BigInt!
  epoch: BigInt!
  timestamp: BigInt!
  blockNumber: BigInt!
  txHash: Bytes!
}

type Epoch @entity {
  id: ID! # epoch number
  epochNumber: BigInt!
  startTime: BigInt!
  endTime: BigInt!
  emissions: BigInt!
  totalUtilization: BigInt!
  totalBondedBalance: BigInt!
  rewardsClaimed: BigInt!
  rewardsUnclaimed: BigInt!
}

type ProtocolStats @entity {
  id: ID! # "protocol-stats"
  totalAtoms: BigInt!
  totalTriples: BigInt!
  totalVaults: BigInt!
  totalUsers: BigInt!
  totalValueLocked: BigInt!
  totalVolume: BigInt!
  totalFees: BigInt!
  totalRewardsDistributed: BigInt!
  updatedAt: BigInt!
}

# Daily aggregations for analytics
type DailyVaultStats @entity {
  id: ID! # vaultId-dayId
  vault: Vault!
  day: BigInt! # Unix timestamp (start of day)
  deposits: BigInt!
  redemptions: BigInt!
  volume: BigInt!
  netFlow: BigInt!
  uniqueUsers: BigInt!
  avgSharePrice: BigInt!
}

type DailyProtocolStats @entity {
  id: ID! # dayId
  day: BigInt!
  deposits: BigInt!
  redemptions: BigInt!
  volume: BigInt!
  tvl: BigInt!
  uniqueUsers: BigInt!
  newAtoms: BigInt!
  newTriples: BigInt!
  rewardsClaimed: BigInt!
}
```

## Event Handlers

### Manifest Configuration

Create `subgraph.yaml`:

```yaml
specVersion: 0.0.5
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: MultiVault
    network: mainnet
    source:
      address: "0x..." # MultiVault address
      abi: MultiVault
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Atom
        - Triple
        - Vault
        - Deposit
        - Redemption
        - User
        - Position
      abis:
        - name: MultiVault
          file: ./abis/MultiVault.json
      eventHandlers:
        - event: AtomCreated(indexed address,indexed bytes32,bytes,address)
          handler: handleAtomCreated
        - event: TripleCreated(indexed address,indexed bytes32,bytes32,bytes32,bytes32)
          handler: handleTripleCreated
        - event: Deposited(indexed address,indexed address,indexed bytes32,uint256,uint256,uint256,uint256,uint256,uint8)
          handler: handleDeposited
        - event: Redeemed(indexed address,indexed address,indexed bytes32,uint256,uint256,uint256,uint256,uint256,uint8)
          handler: handleRedeemed
        - event: SharePriceChanged(indexed bytes32,indexed uint256,uint256,uint256,uint256,uint8)
          handler: handleSharePriceChanged
      file: ./src/multi-vault.ts

  - kind: ethereum
    name: TrustBonding
    network: mainnet
    source:
      address: "0x..." # TrustBonding address
      abi: TrustBonding
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - RewardClaim
        - User
        - Epoch
      abis:
        - name: TrustBonding
          file: ./abis/TrustBonding.json
      eventHandlers:
        - event: RewardsClaimed(indexed address,indexed address,uint256)
          handler: handleRewardsClaimed
      file: ./src/trust-bonding.ts
```

### Event Handler Implementation

Create `src/multi-vault.ts`:

```typescript
import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  AtomCreated,
  TripleCreated,
  Deposited,
  Redeemed,
  SharePriceChanged,
} from '../generated/MultiVault/MultiVault';
import {
  Atom,
  Triple,
  Vault,
  Deposit,
  Redemption,
  User,
  Position,
  ProtocolStats,
  DailyVaultStats,
} from '../generated/schema';

export function handleAtomCreated(event: AtomCreated): void {
  // Create Atom entity
  let atom = new Atom(event.params.termId.toHexString());
  atom.creator = event.params.creator;
  atom.data = event.params.atomData;
  atom.wallet = event.params.atomWallet;
  atom.createdAt = event.block.timestamp;
  atom.createdAtBlock = event.block.number;
  atom.createdTxHash = event.transaction.hash;
  atom.totalDeposits = BigInt.zero();
  atom.totalRedemptions = BigInt.zero();
  atom.totalVolume = BigInt.zero();
  atom.save();

  // Update protocol stats
  let stats = getOrCreateProtocolStats();
  stats.totalAtoms = stats.totalAtoms.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyProtocolStats(event.block.timestamp);
  dailyStats.newAtoms = dailyStats.newAtoms.plus(BigInt.fromI32(1));
  dailyStats.save();
}

export function handleTripleCreated(event: TripleCreated): void {
  // Create Triple entity
  let triple = new Triple(event.params.termId.toHexString());
  triple.creator = event.params.creator;
  triple.subject = event.params.subjectId.toHexString();
  triple.predicate = event.params.predicateId.toHexString();
  triple.object = event.params.objectId.toHexString();
  triple.createdAt = event.block.timestamp;
  triple.createdAtBlock = event.block.number;
  triple.createdTxHash = event.transaction.hash;
  triple.totalDeposits = BigInt.zero();
  triple.totalRedemptions = BigInt.zero();
  triple.totalVolume = BigInt.zero();
  triple.save();

  // Update protocol stats
  let stats = getOrCreateProtocolStats();
  stats.totalTriples = stats.totalTriples.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyProtocolStats(event.block.timestamp);
  dailyStats.newTriples = dailyStats.newTriples.plus(BigInt.fromI32(1));
  dailyStats.save();
}

export function handleDeposited(event: Deposited): void {
  let vaultId = event.params.termId.toHexString() + '-' + event.params.curveId.toString();

  // Get or create Vault
  let vault = Vault.load(vaultId);
  if (!vault) {
    vault = new Vault(vaultId);
    vault.term = event.params.termId;
    vault.termType = getVaultType(event.params.vaultType);
    vault.curveId = event.params.curveId;
    vault.totalAssets = BigInt.zero();
    vault.totalShares = BigInt.zero();
    vault.sharePrice = BigInt.zero();
    vault.createdAt = event.block.timestamp;
    vault.depositCount = BigInt.zero();
    vault.redemptionCount = BigInt.zero();
    vault.uniqueDepositors = BigInt.zero();
  }

  vault.totalShares = event.params.totalShares; // Updated from event
  vault.updatedAt = event.block.timestamp;
  vault.depositCount = vault.depositCount.plus(BigInt.fromI32(1));
  vault.save();

  // Create Deposit entity
  let depositId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString();
  let deposit = new Deposit(depositId);
  deposit.sender = event.params.sender.toHexString();
  deposit.receiver = event.params.receiver;
  deposit.vault = vaultId;
  deposit.assets = event.params.assets;
  deposit.assetsAfterFees = event.params.assetsAfterFees;
  deposit.shares = event.params.shares;
  deposit.totalShares = event.params.totalShares;
  deposit.sharePrice = calculateSharePrice(event.params.assetsAfterFees, event.params.shares);
  deposit.timestamp = event.block.timestamp;
  deposit.blockNumber = event.block.number;
  deposit.txHash = event.transaction.hash;
  deposit.save();

  // Update or create User
  let user = getOrCreateUser(event.params.sender);
  user.totalDeposited = user.totalDeposited.plus(event.params.assets);
  user.depositCount = user.depositCount.plus(BigInt.fromI32(1));
  user.save();

  // Update or create Position
  let positionId = event.params.sender.toHexString() + '-' + vaultId;
  let position = Position.load(positionId);
  if (!position) {
    position = new Position(positionId);
    position.user = event.params.sender.toHexString();
    position.vault = vaultId;
    position.shares = BigInt.zero();
    position.averageEntryPrice = BigInt.zero();
    position.createdAt = event.block.timestamp;
  }

  // Update position shares and average entry price
  let previousValue = position.shares.times(position.averageEntryPrice);
  let newValue = event.params.shares.times(deposit.sharePrice);
  let totalValue = previousValue.plus(newValue);
  let totalShares = position.shares.plus(event.params.shares);

  position.shares = totalShares;
  position.averageEntryPrice = totalShares.gt(BigInt.zero())
    ? totalValue.div(totalShares)
    : BigInt.zero();
  position.updatedAt = event.block.timestamp;
  position.save();

  // Update protocol stats
  let stats = getOrCreateProtocolStats();
  stats.totalVolume = stats.totalVolume.plus(event.params.assets);
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleRedeemed(event: Redeemed): void {
  let vaultId = event.params.termId.toHexString() + '-' + event.params.curveId.toString();

  // Update Vault
  let vault = Vault.load(vaultId);
  if (vault) {
    vault.totalShares = event.params.totalShares;
    vault.updatedAt = event.block.timestamp;
    vault.redemptionCount = vault.redemptionCount.plus(BigInt.fromI32(1));
    vault.save();
  }

  // Create Redemption entity
  let redemptionId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString();
  let redemption = new Redemption(redemptionId);
  redemption.sender = event.params.sender.toHexString();
  redemption.receiver = event.params.receiver;
  redemption.vault = vaultId;
  redemption.shares = event.params.shares;
  redemption.totalShares = event.params.totalShares;
  redemption.assets = event.params.assets;
  redemption.fees = event.params.fees;
  redemption.sharePrice = calculateSharePrice(event.params.assets, event.params.shares);
  redemption.timestamp = event.block.timestamp;
  redemption.blockNumber = event.block.number;
  redemption.txHash = event.transaction.hash;
  redemption.save();

  // Update User
  let user = getOrCreateUser(event.params.sender);
  user.totalRedeemed = user.totalRedeemed.plus(event.params.assets);
  user.redemptionCount = user.redemptionCount.plus(BigInt.fromI32(1));
  user.save();

  // Update Position
  let positionId = event.params.sender.toHexString() + '-' + vaultId;
  let position = Position.load(positionId);
  if (position) {
    position.shares = position.shares.minus(event.params.shares);
    position.updatedAt = event.block.timestamp;
    position.save();
  }

  // Update protocol stats
  let stats = getOrCreateProtocolStats();
  stats.totalVolume = stats.totalVolume.plus(event.params.assets);
  stats.totalFees = stats.totalFees.plus(event.params.fees);
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleSharePriceChanged(event: SharePriceChanged): void {
  let vaultId = event.params.termId.toHexString() + '-' + event.params.curveId.toString();

  let vault = Vault.load(vaultId);
  if (vault) {
    vault.totalAssets = event.params.totalAssets;
    vault.totalShares = event.params.totalShares;
    vault.sharePrice = event.params.sharePrice;
    vault.updatedAt = event.block.timestamp;
    vault.save();
  }
}

// Helper functions
function getOrCreateUser(address: Bytes): User {
  let user = User.load(address.toHexString());
  if (!user) {
    user = new User(address.toHexString());
    user.totalDeposited = BigInt.zero();
    user.totalRedeemed = BigInt.zero();
    user.totalRewardsClaimed = BigInt.zero();
    user.bondedBalance = BigInt.zero();
    user.depositCount = BigInt.zero();
    user.redemptionCount = BigInt.zero();
    user.save();

    // Update unique users count
    let stats = getOrCreateProtocolStats();
    stats.totalUsers = stats.totalUsers.plus(BigInt.fromI32(1));
    stats.save();
  }
  return user;
}

function getOrCreateProtocolStats(): ProtocolStats {
  let stats = ProtocolStats.load('protocol-stats');
  if (!stats) {
    stats = new ProtocolStats('protocol-stats');
    stats.totalAtoms = BigInt.zero();
    stats.totalTriples = BigInt.zero();
    stats.totalVaults = BigInt.zero();
    stats.totalUsers = BigInt.zero();
    stats.totalValueLocked = BigInt.zero();
    stats.totalVolume = BigInt.zero();
    stats.totalFees = BigInt.zero();
    stats.totalRewardsDistributed = BigInt.zero();
    stats.updatedAt = BigInt.zero();
  }
  return stats;
}

function getOrCreateDailyProtocolStats(timestamp: BigInt): DailyProtocolStats {
  let dayId = timestamp.toI32() / 86400;
  let id = dayId.toString();

  let stats = DailyProtocolStats.load(id);
  if (!stats) {
    stats = new DailyProtocolStats(id);
    stats.day = BigInt.fromI32(dayId * 86400);
    stats.deposits = BigInt.zero();
    stats.redemptions = BigInt.zero();
    stats.volume = BigInt.zero();
    stats.tvl = BigInt.zero();
    stats.uniqueUsers = BigInt.zero();
    stats.newAtoms = BigInt.zero();
    stats.newTriples = BigInt.zero();
    stats.rewardsClaimed = BigInt.zero();
  }
  return stats;
}

function calculateSharePrice(assets: BigInt, shares: BigInt): BigInt {
  if (shares.equals(BigInt.zero())) {
    return BigInt.zero();
  }
  return assets.times(BigInt.fromI32(10).pow(18)).div(shares);
}

function getVaultType(typeValue: i32): string {
  if (typeValue == 0) return 'ATOM';
  if (typeValue == 1) return 'TRIPLE';
  if (typeValue == 2) return 'COUNTER_TRIPLE';
  return 'ATOM';
}
```

## GraphQL Queries

### Common Query Patterns

```graphql
# Get all atoms with their vaults
query GetAtoms($first: Int = 100, $skip: Int = 0) {
  atoms(first: $first, skip: $skip, orderBy: createdAt, orderDirection: desc) {
    id
    creator
    data
    wallet
    createdAt
    vaults {
      id
      totalAssets
      totalShares
      sharePrice
    }
    totalDeposits
    totalVolume
  }
}

# Get specific atom with relationships
query GetAtom($id: ID!) {
  atom(id: $id) {
    id
    creator
    data
    wallet
    createdAt
    vaults {
      id
      curveId
      totalAssets
      totalShares
      sharePrice
      depositCount
      redemptionCount
    }
    asSubject {
      id
      predicate { id data }
      object { id data }
    }
    asPredicate {
      id
      subject { id data }
      object { id data }
    }
    asObject {
      id
      subject { id data }
      predicate { id data }
    }
  }
}

# Get user portfolio
query GetUserPortfolio($user: ID!) {
  user(id: $user) {
    id
    bondedBalance
    totalDeposited
    totalRedeemed
    totalRewardsClaimed
    positions(where: { shares_gt: "0" }) {
      vault {
        id
        term
        termType
        curveId
        sharePrice
      }
      shares
      averageEntryPrice
    }
    rewardsClaimed(orderBy: timestamp, orderDirection: desc, first: 10) {
      amount
      epoch
      timestamp
    }
  }
}

# Get top vaults by TVL
query GetTopVaults($first: Int = 10) {
  vaults(first: $first, orderBy: totalAssets, orderDirection: desc) {
    id
    term
    termType
    curveId
    totalAssets
    totalShares
    sharePrice
    depositCount
    redemptionCount
    uniqueDepositors
  }
}

# Get recent deposits
query GetRecentDeposits($first: Int = 100) {
  deposits(first: $first, orderBy: timestamp, orderDirection: desc) {
    id
    sender { id }
    vault {
      id
      term
      termType
    }
    assets
    shares
    sharePrice
    timestamp
    txHash
  }
}

# Get protocol statistics
query GetProtocolStats {
  protocolStats(id: "protocol-stats") {
    totalAtoms
    totalTriples
    totalVaults
    totalUsers
    totalValueLocked
    totalVolume
    totalFees
    totalRewardsDistributed
    updatedAt
  }
}

# Get daily analytics
query GetDailyAnalytics($days: Int = 30) {
  dailyProtocolStats(first: $days, orderBy: day, orderDirection: desc) {
    day
    deposits
    redemptions
    volume
    tvl
    uniqueUsers
    newAtoms
    newTriples
    rewardsClaimed
  }
}

# Search atoms by creator
query SearchAtomsByCreator($creator: Bytes!) {
  atoms(where: { creator: $creator }, orderBy: createdAt, orderDirection: desc) {
    id
    data
    wallet
    createdAt
    totalVolume
  }
}

# Get vault history
query GetVaultHistory($vaultId: ID!, $first: Int = 100) {
  vault(id: $vaultId) {
    id
    term
    termType
    deposits(first: $first, orderBy: timestamp, orderDirection: desc) {
      sender { id }
      assets
      shares
      sharePrice
      timestamp
    }
    redemptions(first: $first, orderBy: timestamp, orderDirection: desc) {
      sender { id }
      shares
      assets
      sharePrice
      timestamp
    }
  }
}
```

## Client Integration

### TypeScript Client

```typescript
import { GraphQLClient, gql } from 'graphql-request';

const SUBGRAPH_URL = 'https://api.thegraph.com/subgraphs/name/intuition/v2';

const client = new GraphQLClient(SUBGRAPH_URL);

// Query functions
export async function getAtoms(first: number = 100, skip: number = 0) {
  const query = gql`
    query GetAtoms($first: Int!, $skip: Int!) {
      atoms(first: $first, skip: $skip, orderBy: createdAt, orderDirection: desc) {
        id
        creator
        data
        wallet
        createdAt
        totalVolume
        vaults {
          id
          totalAssets
          totalShares
          sharePrice
        }
      }
    }
  `;

  const data = await client.request(query, { first, skip });
  return data.atoms;
}

export async function getUserPortfolio(userAddress: string) {
  const query = gql`
    query GetUserPortfolio($user: ID!) {
      user(id: $user) {
        id
        bondedBalance
        totalDeposited
        totalRedeemed
        positions(where: { shares_gt: "0" }) {
          vault {
            id
            term
            termType
            curveId
            sharePrice
          }
          shares
          averageEntryPrice
        }
      }
    }
  `;

  const data = await client.request(query, { user: userAddress.toLowerCase() });
  return data.user;
}

export async function getProtocolStats() {
  const query = gql`
    query GetProtocolStats {
      protocolStats(id: "protocol-stats") {
        totalAtoms
        totalTriples
        totalVaults
        totalUsers
        totalValueLocked
        totalVolume
        totalFees
        totalRewardsDistributed
      }
    }
  `;

  const data = await client.request(query);
  return data.protocolStats;
}
```

## Performance Optimization

### Pagination

```typescript
async function getAllAtoms() {
  const pageSize = 1000;
  let allAtoms: any[] = [];
  let skip = 0;
  let hasMore = true;

  while (hasMore) {
    const atoms = await getAtoms(pageSize, skip);

    allAtoms = allAtoms.concat(atoms);

    hasMore = atoms.length === pageSize;
    skip += pageSize;
  }

  return allAtoms;
}
```

### Caching

```typescript
class SubgraphCache {
  private cache = new Map<string, { data: any; expiry: number }>();
  private ttl = 30000; // 30 seconds

  async query<T>(
    key: string,
    queryFn: () => Promise<T>
  ): Promise<T> {
    const cached = this.cache.get(key);

    if (cached && Date.now() < cached.expiry) {
      return cached.data as T;
    }

    const data = await queryFn();

    this.cache.set(key, {
      data,
      expiry: Date.now() + this.ttl,
    });

    return data;
  }
}

const cache = new SubgraphCache();

// Use cached queries
const atoms = await cache.query('atoms:100:0', () => getAtoms(100, 0));
```

## Deployment

### Build and Deploy

```bash
# Install dependencies
npm install

# Generate types from schema
graph codegen

# Build the subgraph
graph build

# Authenticate with The Graph
graph auth --product hosted-service <ACCESS_TOKEN>

# Deploy to hosted service
graph deploy --product hosted-service <GITHUB_USER>/<SUBGRAPH_NAME>

# Or deploy to decentralized network
graph deploy --product subgraph-studio <SUBGRAPH_NAME>
```

### Monitoring

Check subgraph health and sync status:

```typescript
async function checkSubgraphHealth() {
  const healthQuery = gql`
    query {
      _meta {
        block {
          number
          hash
        }
        deployment
        hasIndexingErrors
      }
    }
  `;

  const data = await client.request(healthQuery);
  console.log('Subgraph status:', data._meta);

  if (data._meta.hasIndexingErrors) {
    console.error('Subgraph has indexing errors!');
  }
}
```

## Best Practices

1. **Efficient Queries**: Request only needed fields
2. **Pagination**: Use first/skip for large datasets
3. **Caching**: Cache frequently accessed data
4. **Error Handling**: Handle subgraph sync delays
5. **Indexing**: Create appropriate indexes in schema
6. **Testing**: Test queries against local graph node
7. **Monitoring**: Monitor subgraph health and errors

## See Also

- [Event Monitoring](./event-monitoring.md) - Direct event subscription
- [SDK Design Patterns](./sdk-design-patterns.md) - SDK architecture
- [The Graph Documentation](https://thegraph.com/docs/) - Official Graph docs
