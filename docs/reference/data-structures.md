# Data Structures Reference

Complete catalog of structs and enums used in Intuition Protocol V2.

## Table of Contents

- [Enums](#enums)
- [Core Structs](#core-structs)
- [Configuration Structs](#configuration-structs)
- [Emissions Structs](#emissions-structs)

## Enums

### VaultType

Defines the type of vault.

```solidity
enum VaultType {
    ATOM,           // Vault for an atom
    TRIPLE,         // Vault for a triple (positive assertion)
    COUNTER_TRIPLE  // Vault for a counter triple (negative assertion)
}
```

**Usage**: Emitted in events, used to differentiate vault types

---

### ApprovalTypes

Defines permission types for sender-receiver relationships.

```solidity
enum ApprovalTypes {
    NONE,       // No approval (0b00)
    DEPOSIT,    // Approve deposits only (0b01)
    REDEMPTION, // Approve redemptions only (0b10)
    BOTH        // Approve both deposits and redemptions (0b11)
}
```

**Usage**: `updateApprovalType()` function

**Example**:
```typescript
// Approve address to deposit on your behalf
await multiVault.updateApprovalType(sender, ApprovalTypes.DEPOSIT);
```

---

### FinalityState

Defines cross-chain message finality states.

```solidity
enum FinalityState {
    PENDING,
    FINALIZED,
    REVERTED
}
```

**Usage**: Cross-chain messaging and bridge operations

## Core Structs

### VaultState

Tracks the state of a single vault.

```solidity
struct VaultState {
    uint256 totalAssets;  // Total assets held in vault
    uint256 totalShares;  // Total shares issued by vault
    mapping(address => uint256) balanceOf; // User share balances
}
```

**Storage Location**: `MultiVault` contract

**Access**:
```typescript
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
const userShares = await multiVault.getShares(userAddress, termId, curveId);
```

---

### UserInfo

Comprehensive user information for reward calculations.

```solidity
struct UserInfo {
    uint256 personalUtilization;  // User's utilization for epoch
    uint256 eligibleRewards;      // Rewards eligible to claim
    uint256 maxRewards;           // Maximum possible rewards
    uint256 lockedAmount;         // Amount of TRUST locked
    uint256 lockEnd;              // Timestamp when lock expires
    uint256 bondedBalance;        // Current bonded balance (veTRUST)
}
```

**Access**:
```typescript
const userInfo = await trustBonding.getUserInfo(userAddress, epoch);

console.log('Bonded Balance:', formatEther(userInfo.bondedBalance));
console.log('Eligible Rewards:', formatEther(userInfo.eligibleRewards));
console.log('Lock Expires:', new Date(Number(userInfo.lockEnd) * 1000));
```

## Configuration Structs

### GeneralConfig

General protocol configuration parameters.

```solidity
struct GeneralConfig {
    uint256 atomCost;         // Base cost to create an atom (in TRUST)
    uint256 tripleCost;       // Base cost to create a triple (in TRUST)
    uint256 minShare;         // Minimum shares to mint on creation
    uint256 minDeposit;       // Minimum deposit amount
    uint256 minSenderBalance; // Minimum sender balance required
    bool pauseDeposits;       // Deposits paused flag
    bool pauseRedemptions;    // Redemptions paused flag
}
```

**Default Values** (approximate):
- `atomCost`: 0.001 TRUST
- `tripleCost`: 0.003 TRUST
- `minShare`: 1e15 (0.001 shares)
- `minDeposit`: 1e15 (0.001 TRUST)

---

### AtomConfig

Atom-specific configuration.

```solidity
struct AtomConfig {
    uint256 atomCreationProtocolFee; // Fee for creating atom (basis points)
    uint256 atomWalletDepositFee;    // Fee on atom vault deposits (basis points)
}
```

**Fee Format**: Basis points (10000 = 100%)

**Example**: `atomWalletDepositFee = 100` = 1% fee

---

### TripleConfig

Triple-specific configuration.

```solidity
struct TripleConfig {
    uint256 tripleCreationProtocolFee;    // Fee for creating triple (basis points)
    uint256 atomDepositFractionForTriple; // Fraction deposited to underlying atoms (basis points)
}
```

**Example**: `atomDepositFractionForTriple = 1000` = 10% of triple deposit goes to each underlying atom

---

### WalletConfig

Atom wallet system configuration.

```solidity
struct WalletConfig {
    address atomWarden;                    // AtomWarden contract address
    address atomWalletInitialDepositToken; // Token for initial wallet deposit
    uint256 atomWalletInitialDepositAmount; // Amount for initial deposit
}
```

---

### VaultFees

Vault fee configuration.

```solidity
struct VaultFees {
    uint256 entryFee;   // Fee on deposits (basis points)
    uint256 exitFee;    // Fee on redemptions (basis points)
    uint256 protocolFee; // Protocol fee on all operations (basis points)
}
```

**Fee Application**:
- `entryFee`: Applied on deposits (except first deposit to vault)
- `exitFee`: Applied on redemptions (except last redemption)
- `protocolFee`: Applied on both deposits and redemptions

---

### BondingCurveConfig

Bonding curve system configuration.

```solidity
struct BondingCurveConfig {
    address registry;      // BondingCurveRegistry address
    uint256 defaultCurveId; // Default curve ID for new vaults
}
```

## Emissions Structs

### CoreEmissionsControllerInit

Initialization parameters for emissions controller.

```solidity
struct CoreEmissionsControllerInit {
    uint256 emissionsPerEpoch;      // TRUST emitted per epoch
    uint256 reductionBasisPoints;   // Reduction rate (basis points)
    uint256 cliff;                  // Epochs before reduction starts
    uint256 timestampStart;         // Start timestamp for epoch 0
    uint256 epochLength;            // Length of each epoch (seconds)
}
```

**Example**:
- `emissionsPerEpoch`: 1,000,000 TRUST
- `reductionBasisPoints`: 200 (2% reduction per period)
- `cliff`: 52 (52 epochs before reduction)
- `epochLength`: 604800 (1 week)

---

### EmissionsCheckpoint

Checkpoint for emissions tracking.

```solidity
struct EmissionsCheckpoint {
    uint256 epoch;                // Epoch number
    uint256 emissionsPerEpoch;    // Emissions at this checkpoint
    uint256 cumulativeEmissions;  // Total emissions up to this point
}
```

**Usage**: Track emission schedule changes over time

---

### MetaERC20DispatchInit

Cross-chain messaging initialization (for MetaLayer).

```solidity
struct MetaERC20DispatchInit {
    address interchainSecurityModule; // Security module address
    address mailbox;                  // Mailbox address for messages
    uint32 remoteDomain;              // Remote chain domain ID
    bytes32 remoteRouter;             // Remote router address
}
```

**Usage**: Cross-chain TRUST token bridging

## Usage Examples

### Reading Vault State

```typescript
// Get vault state
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Calculate share price
const sharePrice = totalShares > 0n
  ? (totalAssets * 1e18n) / totalShares
  : 1e18n;

console.log('Share Price:', formatEther(sharePrice));
console.log('TVL:', formatEther(totalAssets));
```

### Checking User Rewards

```typescript
const previousEpoch = await trustBonding.previousEpoch();
const userInfo = await trustBonding.getUserInfo(userAddress, previousEpoch);

if (userInfo.eligibleRewards > 0n) {
  console.log(`You can claim ${formatEther(userInfo.eligibleRewards)} TRUST`);
  console.log(`Max possible: ${formatEther(userInfo.maxRewards)} TRUST`);
} else {
  console.log('No rewards available');
}
```

### Interpreting Approval Types

```typescript
function describeApproval(approvalType: number): string {
  const types = ['None', 'Deposit Only', 'Redemption Only', 'Both'];
  return types[approvalType] || 'Unknown';
}

const approval = await multiVault.getApprovalType(sender, receiver);
console.log(`Approval: ${describeApproval(approval)}`);
```

## Best Practices

1. **Type Safety**: Use proper TypeScript types for structs
2. **Validation**: Validate struct fields before use
3. **Defaults**: Understand default values for optional fields
4. **Gas Costs**: Larger structs cost more gas to store/retrieve
5. **Versioning**: Be aware of struct changes across versions

## See Also

- [Events Reference](./events.md) - Protocol events
- [Errors Reference](./errors.md) - Protocol errors
- [MultiVault Documentation](../contracts/core/MultiVault.md) - Core contract
- [TrustBonding Documentation](../contracts/emissions/TrustBonding.md) - Rewards contract
