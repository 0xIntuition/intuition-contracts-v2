# Glossary

Comprehensive reference of terms, concepts, and acronyms used in the Intuition Protocol V2 documentation.

## Core Concepts

### Atom
A singular unit of data stored on-chain. Atoms represent individual concepts, entities, or pieces of information encoded as bytes (≤256 bytes). Each atom has a unique identifier (atom ID) computed as `keccak256(SALT + keccak256(atomData))`. Atoms can have associated vaults and atom wallets.

**Example**: An atom could represent a person's address, a concept like "verified", or any arbitrary data.

**See**: [Atoms and Triples](./concepts/atoms-and-triples.md)

### Triple
A subject-predicate-object relationship composed of three atom IDs. Triples express claims or relationships between atoms (e.g., "Alice" "knows" "Bob"). Each triple has a unique identifier (triple ID) computed from the hash of its three component atom IDs.

**Structure**: `(subjectId, predicateId, objectId)`

**See**: [Atoms and Triples](./concepts/atoms-and-triples.md)

### Counter Triple
The inverse or negation of a positive triple. For every triple created, a corresponding counter triple is automatically generated. Counter triples allow users to express disagreement or the opposite of a claim.

**Example**: If triple T claims "X is Y", counter triple ~T represents "X is not Y".

**See**: [Atoms and Triples](./concepts/atoms-and-triples.md)

### Term
A general reference to either an atom or a triple. Used interchangeably when the distinction doesn't matter.

### Term ID
The unique identifier for a term (either an atom ID or triple ID). Used as a key for vault lookups and operations.

## Vault System

### Vault
An ERC4626-style pool that manages assets and shares for a specific term and bonding curve combination. Each vault tracks total assets, total shares, and individual user share balances. Multiple vaults can exist for the same term using different bonding curves.

**Identifier**: `(termId, curveId)`

**See**: [Multi-Vault Pattern](./concepts/multi-vault-pattern.md)

### Share
A token representing ownership in a vault. Shares are minted when users deposit assets and burned when users redeem. The value of shares changes over time based on the bonding curve pricing.

### Multi-Vault Pattern
The architectural pattern where each term can have multiple independent vaults, each using a different bonding curve. This allows for diverse economic models on the same underlying data.

**See**: [Multi-Vault Pattern](./concepts/multi-vault-pattern.md)

### Vault Type
An enumeration indicating whether a vault is for an ATOM, TRIPLE, or COUNTER_TRIPLE.

```solidity
enum VaultType {
    ATOM,
    TRIPLE,
    COUNTER_TRIPLE
}
```

## Bonding Curves

### Bonding Curve
A mathematical function that determines the relationship between assets deposited and shares minted (or shares redeemed and assets returned). Bonding curves enable dynamic pricing based on supply.

**See**: [Bonding Curves](./concepts/bonding-curves.md)

### Linear Curve
A bonding curve implementation with a constant price per share. The simplest curve where 1 asset always equals 1 share (minus fees).

**Formula**: `shares = assets * MULTIPLIER`

**See**: [LinearCurve](./contracts/curves/LinearCurve.md)

### Progressive Curve
A bonding curve with quadratic pricing that increases as more assets are deposited. Higher supply means higher prices, creating progressive resistance to large deposits.

**Formula**: Uses fixed-point quadratic calculations based on total supply.

**See**: [ProgressiveCurve](./contracts/curves/ProgressiveCurve.md)

### Offset Progressive Curve
A progressive curve variant that applies an offset to the pricing calculation, allowing for more granular control over the pricing curve shape.

**See**: [OffsetProgressiveCurve](./contracts/curves/OffsetProgressiveCurve.md)

### Curve ID
A unique identifier for a registered bonding curve in the BondingCurveRegistry. Used to select which pricing mechanism to use for a vault.

## Token Economics

### TRUST
The native ERC20 token of the Intuition Protocol. TRUST is minted through emissions and used as the base asset for all vault operations. Total supply is capped at 1 billion tokens.

**Contract**: Trust.sol

**See**: [Trust](./contracts/core/Trust.md)

### WrappedTrust (WTRUST)
A wrapped version of the native chain gas token (e.g., ETH on Ethereum). Users can deposit native tokens to receive WTRUST, which can then be used in the protocol.

**See**: [WrappedTrust](./contracts/WrappedTrust.md)

### veTRUST
Vote-escrowed TRUST tokens. When users lock TRUST in the TrustBonding contract, they receive veTRUST, which represents time-weighted voting power. veTRUST decays linearly over time until the lock expires.

**Calculation**: `veTRUST = lockedAmount × (timeRemaining / MAXTIME)`

**See**: [TrustBonding](./contracts/emissions/TrustBonding.md)

## Emissions & Rewards

### Epoch
A fixed time period used for reward distribution and utilization tracking. Epochs are sequential and non-overlapping. The protocol tracks emissions, utilization, and bonding data per epoch.

**Length**: Configurable (e.g., 1 week)

**See**: [Emissions System](./concepts/emissions-system.md), [Epoch Management](./guides/epoch-management.md)

### Emissions
The process of minting new TRUST tokens according to a predetermined schedule. Emissions occur each epoch and are distributed to users based on their bonded balance and utilization.

**See**: [Emissions System](./concepts/emissions-system.md)

### Utilization
A measure of a user's or the system's net engagement with the protocol during an epoch. Calculated as deposits minus redemptions.

**Types**:
- **Personal Utilization**: Individual user's net deposits/redemptions
- **System Utilization**: Aggregate utilization across all users

**Impact**: Higher utilization increases reward eligibility.

**See**: [Utilization Tracking](./concepts/utilization-tracking.md)

### Utilization Ratio
A normalized value (0 to 1e18) representing utilization relative to total bonded balance. Used to adjust rewards based on protocol engagement.

**Formula**: `ratio = max(lowerBound, min(1e18, utilization / bondedBalance))`

**See**: [Utilization Mechanics](./guides/utilization-mechanics.md)

### Bonded Balance
The time-weighted voting power (veTRUST) a user has at a specific epoch. Determines the user's share of emissions for that epoch.

**See**: [TrustBonding](./contracts/emissions/TrustBonding.md)

### Eligible Rewards
The amount of TRUST tokens a user can claim for a specific epoch, adjusted by both personal and system utilization ratios.

**Formula**: `eligibleRewards = baseRewards × systemUtilizationRatio × personalUtilizationRatio`

### Unclaimed Rewards
Rewards that were allocated for an epoch but not claimed by users. Unclaimed rewards are bridged back to the base chain and burned.

**See**: [Claiming Rewards](./guides/claiming-rewards.md)

## Fees

### Protocol Fee
A fee charged on both deposits and redemptions, collected in the MultiVault contract. Protocol fees accumulate per epoch and can be swept to the protocol multisig or TrustBonding contract.

**See**: [Fee Structure](./guides/fee-structure.md)

### Entry Fee
An additional fee charged when depositing into a vault that already has shares. Not applied on the first deposit to a vault.

**See**: [Fee Structure](./guides/fee-structure.md)

### Exit Fee
An additional fee charged when redeeming shares from a vault. Not applied if the redemption would leave the vault with zero shares.

**See**: [Fee Structure](./guides/fee-structure.md)

### Atom Wallet Deposit Fee
A special fee charged when depositing assets into an atom vault. This fee accumulates as claimable fees for the atom wallet owner.

**See**: [Smart Wallets](./concepts/smart-wallets.md), [Fee Structure](./guides/fee-structure.md)

### Atom Cost
The base cost (in assets) required to create a new atom. This is a protocol parameter that can be adjusted by governance.

### Triple Cost
The base cost (in assets) required to create a new triple. This is a protocol parameter that can be adjusted by governance.

### Min Share
The minimum number of shares that must be minted when creating a new term (atom or triple). Prevents dust attacks and ensures meaningful initial deposits.

### Atom Deposit Fraction
The fraction of assets deposited into a triple vault that are also deposited into each of the triple's underlying atom vaults.

**Example**: If set to 10% and depositing 100 TRUST into a triple, 10 TRUST also goes to each of the 3 underlying atoms (subject, predicate, object).

## Smart Wallets

### Atom Wallet
An ERC-4337 compatible smart contract wallet associated with each atom. Atom wallets can execute transactions, hold assets, and accumulate fees from atom wallet deposits.

**Standard**: ERC-4337 (Account Abstraction)

**See**: [Smart Wallets](./concepts/smart-wallets.md)

### Atom Wallet Factory
A contract responsible for deploying atom wallets using the Beacon Proxy pattern. Computes deterministic wallet addresses based on atom IDs.

**See**: [AtomWalletFactory](./contracts/wallet/AtomWalletFactory.md)

### Atom Warden
A registry contract that manages atom wallet ownership. Initially owns all newly created atom wallets and allows users to claim ownership if the atom data matches their address.

**See**: [AtomWarden](./contracts/wallet/AtomWarden.md)

### Atom Wallet Beacon
A beacon contract used in the Beacon Proxy pattern for atom wallets. Allows for efficient upgrades of all atom wallet implementations.

**Pattern**: BeaconProxy (OpenZeppelin)

## Cross-Chain

### Base Chain
The blockchain where the BaseEmissionsController resides and where TRUST tokens are initially minted. Typically a high-security, well-established chain.

**Current**: Base Mainnet

**See**: [Cross-Chain Architecture](./concepts/cross-chain-architecture.md)

### Satellite Chain
A blockchain where protocol operations (MultiVault, TrustBonding) occur. Satellite chains receive emissions from the base chain via bridging.

**Current**: Intuition Mainnet

**See**: [Cross-Chain Architecture](./concepts/cross-chain-architecture.md)

### MetaERC20
A cross-chain token standard used for bridging TRUST tokens between the base chain and satellite chains. Handles finality states and burn/mint mechanics.

**See**: [Cross-Chain Architecture](./concepts/cross-chain-architecture.md)

## Technical Terms

### ERC4626
A standard for tokenized vaults that extends ERC20. Defines a consistent interface for deposits, withdrawals, and share calculations. Intuition vaults follow this pattern.

**Standard**: [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626)

### ERC-4337
A standard for account abstraction that enables smart contract wallets with advanced features like gasless transactions, batching, and programmable execution.

**Standard**: [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337)

**See**: [Smart Wallets](./concepts/smart-wallets.md)

### Voting Escrow
A token-locking mechanism where users lock tokens for a period of time and receive time-weighted voting power in return. Power decays linearly until unlock.

**Origin**: Curve Finance

**Implementation**: VotingEscrow.sol

**See**: [TrustBonding](./contracts/emissions/TrustBonding.md)

### UUPS
Universal Upgradeable Proxy Standard. An upgrade pattern where the upgrade logic resides in the implementation contract rather than the proxy.

**Standard**: [EIP-1822](https://eips.ethereum.org/EIPS/eip-1822)

**See**: [Upgradeability](./advanced/upgradeability.md)

### Transparent Proxy
A proxy pattern where the proxy contract handles upgrade logic. Used for some protocol contracts like the Trust token.

**Library**: OpenZeppelin

**See**: [Upgradeability](./advanced/upgradeability.md)

### Beacon Proxy
A proxy pattern where multiple proxies point to a single beacon contract that stores the implementation address. Allows upgrading many contracts simultaneously.

**Use Case**: Atom wallets

**See**: [AtomWalletFactory](./contracts/wallet/AtomWalletFactory.md)

### TimelockController
A governance mechanism that enforces a delay between proposal and execution of admin actions. Provides transparency and safety for protocol upgrades.

**Library**: OpenZeppelin

**See**: [Timelock Governance](./advanced/timelock-governance.md)

### Multicall
A pattern for batching multiple contract calls into a single transaction. Reduces gas costs and improves user experience.

**See**: [Batch Operations](./guides/batch-operations.md), [Gas Optimization](./integration/gas-optimization.md)

### EntryPoint
The singleton contract defined in ERC-4337 that handles user operations for account abstraction. All atom wallets interact with this contract.

**Address**: `0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108` (Same across all chains)

## Access Control

### Role-Based Access Control (RBAC)
A security pattern where permissions are managed through roles rather than individual addresses. Uses OpenZeppelin's AccessControl library.

**See**: [Access Control](./advanced/access-control.md)

### DEFAULT_ADMIN_ROLE
The master admin role that can grant and revoke other roles. Typically held by a multisig or governance contract.

### PAUSER_ROLE
A role that can pause protocol operations in case of emergency. Typically held by a security multisig.

### MANAGER_ROLE
A role with permission to manage protocol parameters and configurations. More limited than admin role.

### CONTROLLER_ROLE
A role with permission to control specific subsystems (e.g., emissions controller can mint tokens).

## Data Structures

### VaultState
A struct tracking the state of a single vault.

```solidity
struct VaultState {
    uint256 totalAssets;
    uint256 totalShares;
    mapping(address => uint256) balanceOf;
}
```

### UserInfo
A struct containing comprehensive user information for reward calculations.

```solidity
struct UserInfo {
    uint256 personalUtilization;
    uint256 eligibleRewards;
    uint256 maxRewards;
    uint256 lockedAmount;
    uint256 lockEnd;
    uint256 bondedBalance;
}
```

### ApprovalTypes
An enum for the types of approvals a receiver can grant to a sender.

```solidity
enum ApprovalTypes {
    NONE,        // No approval (0b00)
    DEPOSIT,     // Approve deposits only (0b01)
    REDEMPTION,  // Approve redemptions only (0b10)
    BOTH         // Approve both (0b11)
}
```

**See**: [Data Structures](./reference/data-structures.md)

## Mathematical Constants

### BASIS_POINTS
10,000 - Used for fee calculations where 100 basis points = 1%.

**Example**: A 5% fee = 500 basis points

### MULTIPLIER
1e18 - Used for fixed-point arithmetic in bonding curve calculations.

### MAXTIME
2 years (in seconds) - The maximum lock duration for voting escrow.

### MINTIME
Configurable minimum lock duration (≥ 2 weeks) for voting escrow.

### WEEK
604,800 seconds (7 days) - Standard epoch length for checkpointing.

## Acronyms

- **ABI**: Application Binary Interface
- **APY**: Annual Percentage Yield
- **DAO**: Decentralized Autonomous Organization
- **SDK**: Software Development Kit
- **TVL**: Total Value Locked
- **UUPS**: Universal Upgradeable Proxy Standard
- **veTRUST**: Vote-Escrowed TRUST

## See Also

- [Protocol Overview](./getting-started/overview.md)
- [Architecture Diagram](./getting-started/architecture.md)
- [FAQ](./appendix/faq.md)

---

**Last Updated**: December 2025
