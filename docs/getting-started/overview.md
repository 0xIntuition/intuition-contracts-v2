# Protocol Overview

Intuition Protocol V2 is an on-chain knowledge graph and claims protocol that enables permissionless creation of data (Atoms), relationships (Triples), and economic markets around them through multi-vault architecture and bonding curves.

## What is Intuition Protocol V2?

Intuition Protocol V2 transforms subjective knowledge and claims into tradable on-chain assets. Users can:

1. **Create Atoms** - Store any data up to 256 bytes on-chain
2. **Create Triples** - Express relationships between atoms (subject-predicate-object)
3. **Stake on Claims** - Deposit assets into vaults backing atoms or triples
4. **Earn Rewards** - Receive TRUST token emissions based on engagement

The protocol combines knowledge graphs, prediction markets, and token economics to create a decentralized truth layer.

## Core Value Propositions

### For Users
- **Express Knowledge**: Create and link data on-chain
- **Signal Conviction**: Stake assets on claims you believe in
- **Earn Rewards**: Get paid for protocol engagement
- **Own Your Data**: Atoms can have associated smart wallets

### For Developers
- **Composable Primitives**: Build on standardized atoms and triples
- **Economic Incentives**: Leverage bonding curves for dynamic pricing
- **Cross-Chain**: Deploy on multiple networks
- **Extensible**: Custom bonding curves and integrations

### For SDK Builders
- **Clean Abstractions**: ERC4626-style vaults with predictable interfaces
- **Rich Events**: Comprehensive event emissions for indexing
- **Modular Design**: Separate concerns (vaults, curves, emissions, wallets)
- **Battle-Tested Patterns**: Based on proven DeFi primitives

## Key Use Cases

### 1. Decentralized Knowledge Graphs
Build interconnected graphs of facts, entities, and relationships.

**Example**:
```
Atom: "Ethereum"
Atom: "is a"
Atom: "blockchain"

Triple: (Ethereum, is a, blockchain)
```

### 2. Reputation Systems
Create verifiable claims about addresses, projects, or entities.

**Example**:
```
Atom: "0x1234..."
Atom: "verified by"
Atom: "Coinbase"

Triple: (0x1234..., verified by, Coinbase)
```

### 3. Prediction Markets
Stake on future outcomes or contentious claims.

**Example**:
```
Atom: "ETH"
Atom: "will reach"
Atom: "$10,000 by 2026"

Triple: (ETH, will reach, $10,000 by 2026)
Counter Triple: (ETH, will NOT reach, $10,000 by 2026)
```

### 4. Content Attribution
Link content to creators and establish provenance.

**Example**:
```
Atom: "ipfs://Qm..."
Atom: "created by"
Atom: "0xAlice..."

Triple: (ipfs://Qm..., created by, 0xAlice...)
```

### 5. Social Graphs
Model relationships between users, groups, or organizations.

**Example**:
```
Atom: "Alice"
Atom: "follows"
Atom: "Bob"

Triple: (Alice, follows, Bob)
```

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Base Chain (Base)                        │
│  ┌──────────────────┐         ┌──────────────────────────────┐  │
│  │ Trust Token      │◄────────┤ BaseEmissionsController      │  │
│  │ (ERC20)          │         │ - Mints TRUST                │  │
│  └──────────────────┘         │ - Bridges to satellites      │  │
│                                └──────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ MetaERC20 Bridge
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Satellite Chain (Intuition)                   │
│  ┌──────────────────┐         ┌──────────────────────────────┐  │
│  │ MultiVault       │◄────────┤ SatelliteEmissionsController │  │
│  │ - Atoms          │         │ - Distributes TRUST          │  │
│  │ - Triples        │         └──────────┬───────────────────┘  │
│  │ - Vaults         │                    │                       │
│  │ - Bonding Curves │                    ▼                       │
│  └────────┬─────────┘         ┌──────────────────────────────┐  │
│           │                   │ TrustBonding                 │  │
│           │                   │ - Voting escrow              │  │
│           │                   │ - Rewards                    │  │
│           │                   │ - Utilization tracking       │  │
│           │                   └──────────────────────────────┘  │
│           │                                                      │
│           ▼                                                      │
│  ┌──────────────────┐                                           │
│  │ AtomWalletFactory│                                           │
│  │ - ERC-4337       │                                           │
│  │ - Atom wallets   │                                           │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Component Overview

### MultiVault
The central hub managing all vaults, atoms, and triples. Handles:
- Creating atoms and triples
- Depositing and redeeming from vaults
- Fee collection and distribution
- Utilization tracking

**See**: [MultiVault](../contracts/core/MultiVault.md)

### Bonding Curves
Mathematical functions determining share prices. Multiple curves available:
- **LinearCurve**: Constant price
- **ProgressiveCurve**: Quadratic pricing
- **OffsetProgressiveCurve**: Progressive with offset

**See**: [Bonding Curves](../concepts/bonding-curves.md)

### Emissions System
Manages TRUST token distribution across epochs:
- **BaseEmissionsController**: Mints on base chain
- **SatelliteEmissionsController**: Distributes on satellite
- **TrustBonding**: Locks TRUST, distributes rewards
- **CoreEmissionsController**: Core epoch logic

**See**: [Emissions System](../concepts/emissions-system.md)

### Atom Wallets
ERC-4337 smart wallets associated with each atom:
- **AtomWalletFactory**: Deploys wallets
- **AtomWarden**: Manages ownership
- **AtomWallet**: Executes transactions

**See**: [Smart Wallets](../concepts/smart-wallets.md)

## How It Works

### Creating an Atom

1. User calls `MultiVault.createAtoms()` with data and initial deposit
2. Protocol generates atom ID from data hash
3. Creates vault for the atom using default bonding curve
4. Deploys atom wallet via factory
5. Mints initial shares to user
6. Tracks utilization for epoch

### Creating a Triple

1. User calls `MultiVault.createTriples()` with 3 atom IDs and deposit
2. Protocol validates all atoms exist
3. Generates triple ID from hash of three atom IDs
4. Creates vault for triple and counter triple
5. Deposits fraction of assets into each underlying atom
6. Mints shares to user

### Depositing to a Vault

1. User calls `MultiVault.deposit()` with term ID and curve ID
2. Protocol calculates shares based on bonding curve
3. Deducts protocol fee and entry fee (if not first depositor)
4. Mints shares to receiver
5. Updates utilization tracking
6. Emits events

### Earning Rewards

1. Users lock TRUST in TrustBonding contract
2. Receive veTRUST (vote-escrowed, time-decaying)
3. Protocol tracks deposits/redemptions (utilization)
4. Each epoch, emissions distributed based on:
   - User's bonded balance (veTRUST)
   - System utilization ratio
   - Personal utilization ratio
5. Users claim rewards in next epoch

## Economic Model

### Token Flow

```
TRUST Tokens
    │
    ├──► Lock in TrustBonding ──► Receive veTRUST
    │                              │
    │                              ├──► Claim Rewards
    │                              └──► Unlock after period
    │
    └──► Use in MultiVault Vaults ──► Receive Shares
                                       │
                                       ├──► Earn Trading Fees
                                       └──► Redeem for TRUST
```

### Fee Structure

- **Protocol Fee**: ~2.5% on deposits/redemptions
- **Entry Fee**: Applied when vault has existing shares
- **Exit Fee**: Applied when vault won't be emptied
- **Atom Wallet Fee**: Additional fee for atom deposits

**See**: [Fee Structure](../guides/fee-structure.md)

### Reward Calculation

```
Eligible Rewards = Base Share × System Utilization Ratio × Personal Utilization Ratio

Where:
- Base Share = (User veTRUST / Total veTRUST) × Epoch Emissions
- System Ratio = max(lowerBound, systemUtilization / totalBonded)
- Personal Ratio = max(lowerBound, personalUtilization / userBonded)
```

**See**: [Utilization Mechanics](../guides/utilization-mechanics.md)

## Network Deployments

### Mainnet
- **Base Mainnet**: Trust token, BaseEmissionsController
- **Intuition Mainnet**: MultiVault, TrustBonding, all protocol operations

### Testnet
- **Base Sepolia**: Test emissions controller
- **Intuition Testnet**: Test protocol deployment

**See**: [Deployment Addresses](./deployment-addresses.md)

## Key Features

### 1. Multi-Vault Architecture
Each term (atom or triple) can have multiple vaults with different bonding curves. This enables:
- Diverse economic models
- Curve experimentation
- Risk diversification

### 2. Epoch-Based Emissions
Predictable token distribution with:
- Fixed epoch length
- Declining emission schedule
- Utilization-adjusted rewards

### 3. Utilization Tracking
Protocol measures engagement and adjusts rewards:
- Personal utilization (per user)
- System utilization (aggregate)
- Historical tracking per epoch

### 4. Cross-Chain Design
Base chain handles security-critical operations (token minting), satellite chains handle high-frequency operations (trading, claiming).

### 5. ERC-4337 Wallets
Each atom has a programmable smart wallet that can:
- Execute transactions
- Hold assets
- Accumulate fees
- Be claimed by owners

## Security Features

- **Upgradeability**: UUPS proxies for protocol evolution
- **Access Control**: Role-based permissions
- **Timelock**: Governance delays for transparency
- **Pause Mechanism**: Emergency stops
- **Audits**: Multiple security audits

**See**: [Security Considerations](../advanced/security-considerations.md)

## Next Steps

### For Developers
1. Read [Architecture](./architecture.md) for system design
2. Follow [ABI Quick Start](./quickstart-abi.md) to integrate
3. Explore [Integration Guides](../guides/) for common operations

### For SDK Builders
1. Read [Architecture](./architecture.md) for component relationships
2. Follow [SDK Quick Start](./quickstart-sdk.md) to begin
3. Study [SDK Design Patterns](../integration/sdk-design-patterns.md)

### For Users
1. Visit the Intuition app to interact with the protocol
2. Join the [Discord community](https://discord.gg/intuition)
3. Read the [FAQ](../appendix/faq.md)

## Additional Resources

- **Whitepaper**: [Coming soon]
- **GitHub**: [0xIntuition/intuition-contracts-v2](https://github.com/0xIntuition/intuition-contracts-v2)
- **Docs**: [Documentation home](../README.md)
- **Audits**: [Security reports](../advanced/security-considerations.md)

---

**Next**: [Architecture →](./architecture.md)
