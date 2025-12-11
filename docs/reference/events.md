# Protocol Events Reference

Complete catalog of all events emitted by Intuition Protocol V2 contracts.

## Table of Contents

- [MultiVault Events](#multivault-events)
- [TrustBonding Events](#trustbonding-events)
- [Emissions Controller Events](#emissions-controller-events)
- [Bonding Curve Events](#bonding-curve-events)
- [Wallet System Events](#wallet-system-events)
- [Configuration Events](#configuration-events)

## MultiVault Events

### AtomCreated

Emitted when a new atom is created.

```solidity
event AtomCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes atomData,
    address atomWallet
);
```

**Parameters**:
- `creator` (indexed): Address of the atom creator
- `termId` (indexed): Unique identifier for the atom (bytes32)
- `atomData`: The data stored in the atom (max 256 bytes)
- `atomWallet`: Address of the deployed atom wallet

**When Emitted**: Called by `createAtoms()` when creating new atoms

**Use Cases**:
- Index new atoms for search and discovery
- Track atom creation rate and volume
- Monitor specific creators' activity
- Build atom-to-wallet mapping

**Example Listener**:
```typescript
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet) => {
  console.log(`Atom ${termId} created by ${creator}`);
  console.log(`Atom wallet: ${atomWallet}`);
  // Index atom data...
});
```

---

### TripleCreated

Emitted when a new triple (relationship) is created.

```solidity
event TripleCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
);
```

**Parameters**:
- `creator` (indexed): Address of the triple creator
- `termId` (indexed): Unique identifier for the triple
- `subjectId`: ID of the subject atom
- `predicateId`: ID of the predicate atom
- `objectId`: ID of the object atom

**When Emitted**: Called by `createTriples()` when creating new triples

**Use Cases**:
- Build knowledge graph from relationships
- Track triple creation patterns
- Analyze relationship density
- Monitor specific relationship types

**Example Listener**:
```typescript
multiVault.on('TripleCreated', (creator, termId, subjectId, predicateId, objectId) => {
  console.log(`Triple: ${subjectId} --[${predicateId}]--> ${objectId}`);
  // Build graph edge...
});
```

---

### Deposited

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

**Parameters**:
- `sender` (indexed): Address making the deposit
- `receiver` (indexed): Address receiving the shares
- `termId` (indexed): ID of the term (atom or triple)
- `curveId`: Bonding curve ID used for this vault
- `assets`: Gross assets deposited (before fees)
- `assetsAfterFees`: Net assets added to vault (after fees)
- `shares`: Shares minted to receiver
- `totalShares`: Receiver's total shares after deposit
- `vaultType`: Type of vault (ATOM=0, TRIPLE=1, COUNTER_TRIPLE=2)

**When Emitted**: Called by `deposit()`, `depositBatch()`, `createAtoms()`, `createTriples()`

**Fee Calculation**:
```
fees = assets - assetsAfterFees
```

**Use Cases**:
- Track deposit volume and TVL
- Calculate user positions
- Monitor fee collection
- Analyze deposit patterns

**Example Listener**:
```typescript
multiVault.on('Deposited', (sender, receiver, termId, curveId, assets, assetsAfterFees, shares, totalShares, vaultType) => {
  const fees = assets - assetsAfterFees;
  const sharePrice = assetsAfterFees / shares;
  console.log(`${sender} deposited ${formatEther(assets)} (${formatEther(fees)} fees)`);
  console.log(`Minted ${formatEther(shares)} shares at ${formatEther(sharePrice)} each`);
});
```

---

### Redeemed

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

**Parameters**:
- `sender` (indexed): Address redeeming shares
- `receiver` (indexed): Address receiving assets
- `termId` (indexed): ID of the term (atom or triple)
- `curveId`: Bonding curve ID
- `shares`: Shares redeemed
- `totalShares`: Sender's remaining shares after redemption
- `assets`: Assets received (after fees)
- `fees`: Total fees charged (protocol + exit fees)
- `vaultType`: Type of vault

**When Emitted**: Called by `redeem()`, `redeemBatch()`

**Use Cases**:
- Track redemption volume
- Calculate net flows (deposits - redemptions)
- Monitor vault exits
- Analyze fee impact

---

### SharePriceChanged

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

**Parameters**:
- `termId` (indexed): ID of the term
- `curveId` (indexed): Bonding curve ID
- `sharePrice`: New share price (in wei per share)
- `totalAssets`: Total assets in vault
- `totalShares`: Total shares in vault
- `vaultType`: Type of vault

**When Emitted**: Called after deposits and redemptions

**Use Cases**:
- Build price charts
- Calculate APY
- Monitor price movements
- Track bonding curve dynamics

---

### PersonalUtilizationAdded / PersonalUtilizationRemoved

Emitted when a user's utilization changes.

```solidity
event PersonalUtilizationAdded(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 personalUtilization
);

event PersonalUtilizationRemoved(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 personalUtilization
);
```

**Parameters**:
- `user` (indexed): User address
- `epoch` (indexed): Current epoch number
- `valueAdded/valueRemoved` (indexed): Change in utilization
- `personalUtilization`: User's total utilization for the epoch

**When Emitted**: On deposits (Added) and redemptions (Removed)

**Use Cases**:
- Track user engagement per epoch
- Calculate utilization ratios
- Predict reward eligibility
- Analyze user behavior

---

### TotalUtilizationAdded / TotalUtilizationRemoved

Emitted when system-wide utilization changes.

```solidity
event TotalUtilizationAdded(
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 indexed totalUtilization
);

event TotalUtilizationRemoved(
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 indexed totalUtilization
);
```

**Parameters**:
- `epoch` (indexed): Current epoch number
- `valueAdded/valueRemoved` (indexed): Change in total utilization
- `totalUtilization`: Aggregate utilization for the epoch

**When Emitted**: On deposits (Added) and redemptions (Removed)

**Use Cases**:
- Monitor protocol health
- Calculate system utilization ratio
- Track epoch-level trends
- Analyze protocol growth

---

### ProtocolFeeAccrued

Emitted when protocol fees are collected.

```solidity
event ProtocolFeeAccrued(
    uint256 indexed epoch,
    address indexed sender,
    uint256 amount
);
```

**Parameters**:
- `epoch` (indexed): Current epoch
- `sender` (indexed): User who paid the fee
- `amount`: Fee amount collected

**When Emitted**: On deposits and redemptions

---

### ProtocolFeeTransferred

Emitted when accumulated protocol fees are swept.

```solidity
event ProtocolFeeTransferred(
    uint256 indexed epoch,
    address indexed destination,
    uint256 amount
);
```

**Parameters**:
- `epoch` (indexed): Epoch being swept
- `destination` (indexed): Recipient (protocol multisig or TrustBonding)
- `amount`: Amount transferred

**When Emitted**: Called by `sweepProtocolFees()`

---

### AtomWalletDepositFeeCollected

Emitted when atom wallet deposit fees are collected.

```solidity
event AtomWalletDepositFeeCollected(
    bytes32 indexed termId,
    address indexed sender,
    uint256 amount
);
```

**Parameters**:
- `termId` (indexed): Atom ID
- `sender` (indexed): Depositor
- `amount`: Fee collected

**When Emitted**: On deposits to atom vaults

---

### AtomWalletDepositFeesClaimed

Emitted when atom wallet owner claims deposit fees.

```solidity
event AtomWalletDepositFeesClaimed(
    bytes32 indexed termId,
    address indexed atomWalletOwner,
    uint256 indexed feesClaimed
);
```

**Parameters**:
- `termId` (indexed): Atom ID
- `atomWalletOwner` (indexed): Owner claiming fees
- `feesClaimed` (indexed): Amount claimed

**When Emitted**: Called by `claimAtomWalletDepositFees()`

---

### ApprovalTypeUpdated

Emitted when approval types are updated.

```solidity
event ApprovalTypeUpdated(
    address indexed sender,
    address indexed receiver,
    ApprovalTypes approvalType
);
```

**Parameters**:
- `sender` (indexed): Address being approved
- `receiver` (indexed): Address granting approval
- `approvalType`: Type of approval (NONE=0, DEPOSIT=1, REDEMPTION=2, BOTH=3)

**When Emitted**: Called by `updateApprovalType()`

## TrustBonding Events

### RewardsClaimed

Emitted when a user claims TRUST rewards.

```solidity
event RewardsClaimed(
    address indexed user,
    address indexed recipient,
    uint256 amount
);
```

**Parameters**:
- `user` (indexed): User claiming rewards
- `recipient` (indexed): Address receiving rewards
- `amount`: TRUST tokens minted as rewards

**When Emitted**: Called by `claimRewards()`

**Use Cases**:
- Track reward distributions
- Monitor claiming patterns
- Calculate total rewards distributed
- Analyze user engagement

**Example Listener**:
```typescript
trustBonding.on('RewardsClaimed', (user, recipient, amount) => {
  console.log(`${user} claimed ${formatEther(amount)} TRUST`);
  // Update rewards dashboard...
});
```

---

### MultiVaultSet

Emitted when MultiVault address is set.

```solidity
event MultiVaultSet(address indexed multiVault);
```

---

### SatelliteEmissionsControllerSet

Emitted when SatelliteEmissionsController address is set.

```solidity
event SatelliteEmissionsControllerSet(address indexed satelliteEmissionsController);
```

---

### TimelockSet

Emitted when Timelock address is set.

```solidity
event TimelockSet(address indexed timelock);
```

---

### SystemUtilizationLowerBoundUpdated

Emitted when system utilization lower bound is updated.

```solidity
event SystemUtilizationLowerBoundUpdated(uint256 newLowerBound);
```

---

### PersonalUtilizationLowerBoundUpdated

Emitted when personal utilization lower bound is updated.

```solidity
event PersonalUtilizationLowerBoundUpdated(uint256 newLowerBound);
```

## Emissions Controller Events

### TrustMintedAndBridged

Emitted when TRUST is minted on base chain and bridged.

```solidity
event TrustMintedAndBridged(
    address indexed to,
    uint256 amount,
    uint256 epoch
);
```

**Parameters**:
- `to` (indexed): Recipient on satellite chain
- `amount`: TRUST minted
- `epoch`: Epoch number

**When Emitted**: Called by BaseEmissionsController during epoch sweep

---

### TrustBurned

Emitted when TRUST is burned on base chain.

```solidity
event TrustBurned(
    address indexed from,
    uint256 amount
);
```

**Parameters**:
- `from` (indexed): Address tokens burned from
- `amount`: Amount burned

**When Emitted**: Called when burning unclaimed emissions

---

### UnclaimedEmissionsBridged

Emitted when unclaimed emissions are bridged back to base chain.

```solidity
event UnclaimedEmissionsBridged(
    uint256 indexed epoch,
    uint256 amount
);
```

**Parameters**:
- `epoch` (indexed): Epoch number
- `amount`: Unclaimed amount bridged

---

### TrustBondingUpdated

Emitted when TrustBonding address is updated.

```solidity
event TrustBondingUpdated(address indexed newTrustBonding);
```

---

### BaseEmissionsControllerUpdated

Emitted when BaseEmissionsController address is updated.

```solidity
event BaseEmissionsControllerUpdated(address indexed newBaseEmissionsController);
```

## Bonding Curve Events

### BondingCurveAdded

Emitted when a new bonding curve is registered.

```solidity
event BondingCurveAdded(
    uint256 indexed curveId,
    address indexed curveAddress,
    string indexed curveName
);
```

**Parameters**:
- `curveId` (indexed): Unique curve identifier
- `curveAddress` (indexed): Curve contract address
- `curveName` (indexed): Human-readable curve name

**When Emitted**: Called by `addBondingCurve()`

---

### CurveNameSet

Emitted when a bonding curve name is set.

```solidity
event CurveNameSet(string name);
```

## Wallet System Events

### AtomWalletDeployed

Emitted when an atom wallet is deployed.

```solidity
event AtomWalletDeployed(
    bytes32 indexed atomId,
    address atomWallet
);
```

**Parameters**:
- `atomId` (indexed): Atom ID
- `atomWallet`: Deployed wallet address

**When Emitted**: Called by AtomWalletFactory during wallet deployment

---

### AtomWalletOwnershipClaimed

Emitted when atom wallet ownership is claimed.

```solidity
event AtomWalletOwnershipClaimed(
    bytes32 atomId,
    address pendingOwner
);
```

**Parameters**:
- `atomId`: Atom ID
- `pendingOwner`: New owner address

**When Emitted**: Called by `claimOwnership()` in AtomWarden

## Configuration Events

### GeneralConfigUpdated

Emitted when general configuration is updated.

```solidity
event GeneralConfigUpdated(
    uint256 atomCost,
    uint256 tripleCost,
    uint256 minShare,
    uint256 minDeposit,
    uint256 minSenderBalance,
    bool pauseDeposits,
    bool pauseRedemptions
);
```

---

### AtomConfigUpdated

Emitted when atom configuration is updated.

```solidity
event AtomConfigUpdated(
    uint256 atomCreationProtocolFee,
    uint256 atomWalletDepositFee
);
```

---

### TripleConfigUpdated

Emitted when triple configuration is updated.

```solidity
event TripleConfigUpdated(
    uint256 tripleCreationProtocolFee,
    uint256 atomDepositFractionForTriple
);
```

---

### WalletConfigUpdated

Emitted when wallet configuration is updated.

```solidity
event WalletConfigUpdated(
    address atomWarden,
    address atomWalletInitialDepositToken,
    uint256 atomWalletInitialDepositAmount
);
```

---

### VaultFeesUpdated

Emitted when vault fees are updated.

```solidity
event VaultFeesUpdated(
    uint256 entryFee,
    uint256 exitFee,
    uint256 protocolFee
);
```

---

### BondingCurveConfigUpdated

Emitted when bonding curve configuration is updated.

```solidity
event BondingCurveConfigUpdated(
    address indexed registry,
    uint256 defaultCurveId
);
```

## Event Monitoring Best Practices

1. **Index by Topic**: Use indexed parameters for efficient filtering
2. **Block Confirmations**: Wait for confirmations before processing
3. **Error Handling**: Handle reorgs and missing events
4. **Batch Processing**: Process events in batches for efficiency
5. **State Reconstruction**: Use events to rebuild state
6. **Analytics**: Aggregate events for metrics and dashboards

## See Also

- [Event Monitoring](../integration/event-monitoring.md) - Event subscription patterns
- [Errors Reference](./errors.md) - Protocol errors
- [Data Structures](./data-structures.md) - Structs and enums
