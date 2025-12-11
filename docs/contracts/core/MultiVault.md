# MultiVault

## Overview

The **MultiVault** contract is the central hub of the Intuition Protocol V2, serving as the primary interface for all vault operations. It manages the creation and operation of ERC4626-style vaults for atoms and triples, utilizing TRUST tokens as the base asset. The contract implements a sophisticated multi-vault architecture where each term (atom or triple) can have multiple independent vaults, each using different bonding curves for price discovery.

### Purpose and Role in Protocol

- **Vault Management Hub**: Orchestrates all vault operations including deposits, redemptions, and share management
- **Data Registry**: Maintains the canonical registry of all atoms and triples created in the protocol
- **Fee Controller**: Manages protocol fees, atom wallet deposit fees, entry/exit fees, and their distribution
- **Utilization Tracker**: Records personal and system-wide utilization metrics used for emissions rewards
- **Approval System**: Implements a granular approval mechanism for delegated deposits and redemptions

### Key Responsibilities

1. **Atom & Triple Creation**: Enables creation of new atoms and triples with initial deposits
2. **Vault Operations**: Handles deposits and redemptions across multiple vaults simultaneously
3. **Fee Management**: Collects and distributes various fee types to appropriate destinations
4. **Utilization Tracking**: Maintains epoch-based utilization data for rewards calculations
5. **Access Control**: Enforces permissions through approval types and admin roles
6. **Pausability**: Provides emergency pause functionality for system safety

## Contract Information

- **Location**: `src/protocol/MultiVault.sol`
- **Inherits**:
  - `IMultiVault` (interface)
  - `MultiVaultCore` (core state and logic)
  - `AccessControlUpgradeable` (role-based access control)
  - `ReentrancyGuardUpgradeable` (reentrancy protection)
  - `PausableUpgradeable` (pause functionality)
- **Interface**: `IMultiVault` (`src/interfaces/IMultiVault.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Intuition Mainnet
- **Address**: [`0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`](https://explorer.intuit.network/address/0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e)
- **ProxyAdmin**: `0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8`

#### Intuition Testnet
- **Address**: [`0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`](https://explorer.testnet.intuit.network/address/0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91)
- **ProxyAdmin**: `0x840d79645824C43227573305BBFCd162504BBB6e`

## Key Concepts

### Multi-Vault Architecture

The protocol uses a multi-vault pattern where each term (atom or triple) can have multiple independent vaults:
- **Term ID**: Unique identifier for an atom or triple (`bytes32`)
- **Curve ID**: Identifier for the bonding curve used (`uint256`)
- **Vault**: Combination of `(termId, curveId)` creates a unique vault

This architecture allows:
- Different pricing mechanisms for the same underlying data
- Economic experimentation without affecting existing vaults
- User choice in selecting preferred pricing models

### Approval Types

The contract implements a granular approval system using bit flags:

```solidity
enum ApprovalTypes {
    NONE = 0b00,        // No permissions
    DEPOSIT = 0b01,     // Can deposit on behalf of receiver
    REDEMPTION = 0b10,  // Can redeem receiver's shares
    BOTH = 0b11        // Both deposit and redemption permissions
}
```

### Utilization Tracking

The protocol tracks both personal and system-wide utilization:
- **Personal Utilization**: Net TRUST deposited minus redeemed per user per epoch
- **Total Utilization**: Aggregate net TRUST across all users per epoch
- **Purpose**: Used by TrustBonding contract to calculate emission rewards
- **History**: Maintains last 3 active epochs per user for efficient lookups

### Fee Structure

Multiple fee types are collected during operations:
1. **Protocol Fee**: Collected on deposits/redemptions, transferred to protocol multisig
2. **Entry Fee**: Applied to deposits above fee threshold, remains in vault
3. **Exit Fee**: Applied to redemptions above fee threshold, remains in vault
4. **Atom Wallet Deposit Fee**: Portion of atom deposits accumulated for atom wallet owners

## State Variables

### Constants

```solidity
uint256 public constant MAX_BATCH_SIZE = 150;
address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);
```

- **MAX_BATCH_SIZE**: Maximum number of operations allowed in batch transactions
- **BURN_ADDRESS**: Destination for initial "ghost shares" minted to prevent inflation attacks

### Core Mappings

```solidity
// Vault state storage
mapping(bytes32 termId => mapping(uint256 curveId => VaultState vaultState)) internal _vaults;

// Approval system
mapping(address receiver => mapping(address sender => uint8 approvalType)) internal approvals;

// Fee tracking
mapping(uint256 epoch => uint256 accumulatedFees) public accumulatedProtocolFees;
mapping(address atomWallet => uint256 accumulatedFees) public accumulatedAtomWalletDepositFees;

// Utilization tracking
mapping(uint256 epoch => int256 utilizationAmount) public totalUtilization;
mapping(address user => mapping(uint256 epoch => int256 utilizationAmount)) public personalUtilization;
mapping(address user => uint256[3] epoch) public userEpochHistory;
```

### VaultState Structure

```solidity
struct VaultState {
    uint256 totalAssets;    // Total TRUST deposited in vault
    uint256 totalShares;    // Total shares issued by vault
    mapping(address account => uint256 balance) balanceOf;  // User share balances
}
```

## Functions

### Read Functions

#### `getShares`
```solidity
function getShares(address account, bytes32 termId, uint256 curveId)
    external view returns (uint256)
```
Returns the number of shares held by an account in a specific vault.

**Parameters**:
- `account`: Address to query
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID

**Returns**: Share balance for the account

---

#### `getVault`
```solidity
function getVault(bytes32 termId, uint256 curveId)
    external view returns (uint256 totalAssets, uint256 totalShares)
```
Returns the total assets and total shares in a vault.

**Parameters**:
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID

**Returns**:
- `totalAssets`: Total TRUST in vault
- `totalShares`: Total shares issued

---

#### `convertToAssets`
```solidity
function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares)
    external view returns (uint256)
```
Calculates the amount of assets that would be exchanged for a given amount of shares.

**Parameters**:
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID
- `shares`: Number of shares to convert

**Returns**: Equivalent asset amount

---

#### `convertToShares`
```solidity
function convertToShares(bytes32 termId, uint256 curveId, uint256 assets)
    external view returns (uint256)
```
Calculates the amount of shares that would be exchanged for a given amount of assets.

**Parameters**:
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID
- `assets`: Amount of assets to convert

**Returns**: Equivalent share amount

---

#### `currentSharePrice`
```solidity
function currentSharePrice(bytes32 termId, uint256 curveId)
    external view returns (uint256)
```
Returns the current share price for a vault (assets per share, scaled by 1e18).

**Parameters**:
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID

**Returns**: Current share price

---

#### `maxRedeem`
```solidity
function maxRedeem(address sender, bytes32 termId, uint256 curveId)
    external view returns (uint256)
```
Returns the maximum number of shares a user can redeem from a vault.

**Parameters**:
- `sender`: Address to query
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID

**Returns**: Maximum redeemable shares

---

#### Preview Functions

These functions simulate operations without executing them:

**`previewAtomCreate`**: Simulates atom creation with initial deposit
```solidity
function previewAtomCreate(bytes32 termId, uint256 assets)
    external view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
```

**`previewTripleCreate`**: Simulates triple creation with initial deposit
```solidity
function previewTripleCreate(bytes32 termId, uint256 assets)
    external view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
```

**`previewDeposit`**: Simulates asset deposit into existing vault
```solidity
function previewDeposit(bytes32 termId, uint256 curveId, uint256 assets)
    external view returns (uint256 shares, uint256 assetsAfterFees)
```

**`previewRedeem`**: Simulates share redemption from vault
```solidity
function previewRedeem(bytes32 termId, uint256 curveId, uint256 shares)
    external view returns (uint256 assetsAfterFees, uint256 sharesUsed)
```

---

#### Utilization Functions

**`currentEpoch`**: Returns the current epoch number
```solidity
function currentEpoch() external view returns (uint256)
```

**`getTotalUtilizationForEpoch`**: Returns system-wide utilization for an epoch
```solidity
function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256)
```

**`getUserUtilizationForEpoch`**: Returns user's utilization for an epoch
```solidity
function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256)
```

**`getUserUtilizationInEpoch`**: Returns user's most recent utilization before a given epoch
```solidity
function getUserUtilizationInEpoch(address user, uint256 epoch) external view returns (int256)
```

**`getUserLastActiveEpoch`**: Returns the last epoch in which a user was active
```solidity
function getUserLastActiveEpoch(address user) external view returns (uint256)
```

---

#### Fee Functions

**`protocolFeeAmount`**: Calculates protocol fee for a given amount
```solidity
function protocolFeeAmount(uint256 assets) external view returns (uint256)
```

**`entryFeeAmount`**: Calculates entry fee for a deposit
```solidity
function entryFeeAmount(uint256 assets) external view returns (uint256)
```

**`exitFeeAmount`**: Calculates exit fee for a redemption
```solidity
function exitFeeAmount(uint256 assets) external view returns (uint256)
```

**`atomDepositFractionAmount`**: Returns amount deposited into underlying atoms during triple deposit
```solidity
function atomDepositFractionAmount(uint256 assets) external view returns (uint256)
```

**`accumulatedProtocolFees`**: Returns accumulated protocol fees for an epoch
```solidity
function accumulatedProtocolFees(uint256 epoch) external view returns (uint256)
```

---

#### Atom Wallet Functions

**`computeAtomWalletAddr`**: Computes deterministic address for an atom's wallet
```solidity
function computeAtomWalletAddr(bytes32 atomId) external view returns (address)
```

**`getAtomWarden`**: Returns the AtomWarden contract address
```solidity
function getAtomWarden() external view returns (address)
```

---

#### Term Verification

**`isTermCreated`**: Checks if a term (atom or triple) has been created
```solidity
function isTermCreated(bytes32 id) external view returns (bool)
```

### Write Functions

#### `createAtoms`
```solidity
function createAtoms(bytes[] calldata atomDatas, uint256[] calldata assets)
    external payable returns (bytes32[] memory)
```
Creates multiple atom vaults with initial deposits in a single transaction.

**Parameters**:
- `atomDatas`: Array of atom data (≤256 bytes each)
- `assets`: Array of deposit amounts (must include atom creation costs)

**Returns**: Array of created atom IDs

**Emits**:
- `AtomCreated` for each atom
- `Deposited` for each initial deposit

**Requirements**:
- Arrays must be same length
- Each atom data must be unique and not exceed max length
- Sufficient TRUST balance and allowance
- Not paused

---

#### `createTriples`
```solidity
function createTriples(
    bytes32[] calldata subjectIds,
    bytes32[] calldata predicateIds,
    bytes32[] calldata objectIds,
    uint256[] calldata assets
) external payable returns (bytes32[] memory)
```
Creates multiple triple vaults with initial deposits in a single transaction.

**Parameters**:
- `subjectIds`: Array of subject atom IDs
- `predicateIds`: Array of predicate atom IDs
- `objectIds`: Array of object atom IDs
- `assets`: Array of deposit amounts (must include triple creation costs)

**Returns**: Array of created triple IDs

**Emits**:
- `TripleCreated` for each triple
- `Deposited` for each initial deposit
- `Deposited` for underlying atom deposits (atom deposit fraction)

**Requirements**:
- All arrays must be same length
- All referenced atoms must exist
- Triple must not already exist
- Sufficient TRUST balance and allowance
- Not paused

---

#### `deposit`
```solidity
function deposit(
    address receiver,
    bytes32 termId,
    uint256 curveId,
    uint256 minShares
) external payable returns (uint256)
```
Deposits assets into a vault and mints shares to the receiver.

**Parameters**:
- `receiver`: Address to receive minted shares
- `termId`: Atom or triple ID to deposit into
- `curveId`: Bonding curve ID to use
- `minShares`: Minimum shares expected (slippage protection)

**Returns**: Number of shares minted

**Emits**:
- `Deposited`
- `SharePriceChanged`
- `ProtocolFeeAccrued`
- `AtomWalletDepositFeeCollected` (for atom deposits)
- `PersonalUtilizationAdded`
- `TotalUtilizationAdded`

**Requirements**:
- Term must exist
- Curve ID must be valid
- Sender must be approved by receiver (if different)
- Assets must meet minimum deposit
- Actual shares ≥ minShares
- Not paused

---

#### `depositBatch`
```solidity
function depositBatch(
    address receiver,
    bytes32[] calldata termIds,
    uint256[] calldata curveIds,
    uint256[] calldata assets,
    uint256[] calldata minShares
) external payable returns (uint256[] memory)
```
Deposits into multiple vaults in a single transaction.

**Parameters**:
- `receiver`: Address to receive all minted shares
- `termIds`: Array of term IDs
- `curveIds`: Array of curve IDs
- `assets`: Array of deposit amounts
- `minShares`: Array of minimum shares expected

**Returns**: Array of shares minted for each deposit

**Requirements**:
- All arrays must be same length
- Length must not exceed MAX_BATCH_SIZE
- Each individual deposit must meet requirements
- Not paused

---

#### `redeem`
```solidity
function redeem(
    address receiver,
    bytes32 termId,
    uint256 curveId,
    uint256 shares,
    uint256 minAssets
) external returns (uint256)
```
Redeems shares from a vault and returns assets to the receiver.

**Parameters**:
- `receiver`: Address to receive redeemed assets
- `termId`: Atom or triple ID to redeem from
- `curveId`: Bonding curve ID
- `shares`: Number of shares to redeem
- `minAssets`: Minimum assets expected (slippage protection)

**Returns**: Number of assets returned

**Emits**:
- `Redeemed`
- `SharePriceChanged`
- `ProtocolFeeAccrued`
- `PersonalUtilizationRemoved`
- `TotalUtilizationRemoved`

**Requirements**:
- Sender must have sufficient shares
- Receiver must approve sender (if different)
- Actual assets ≥ minAssets
- Not paused

---

#### `redeemBatch`
```solidity
function redeemBatch(
    address receiver,
    bytes32[] calldata termIds,
    uint256[] calldata curveIds,
    uint256[] calldata shares,
    uint256[] calldata minAssets
) external returns (uint256[] memory)
```
Redeems shares from multiple vaults in a single transaction.

**Parameters**:
- `receiver`: Address to receive all redeemed assets
- `termIds`: Array of term IDs
- `curveIds`: Array of curve IDs
- `shares`: Array of share amounts to redeem
- `minAssets`: Array of minimum assets expected

**Returns**: Array of assets returned for each redemption

**Requirements**:
- All arrays must be same length
- Length must not exceed MAX_BATCH_SIZE
- Each individual redemption must meet requirements
- Not paused

---

#### `approve`
```solidity
function approve(address sender, ApprovalTypes approvalType) external
```
Sets the approval type for a sender to act on behalf of the caller (receiver).

**Parameters**:
- `sender`: Address to grant or revoke permissions
- `approvalType`: Type of approval (NONE, DEPOSIT, REDEMPTION, or BOTH)

**Emits**: `ApprovalTypeUpdated`

**Requirements**:
- Cannot approve/revoke self

---

#### `claimAtomWalletDepositFees`
```solidity
function claimAtomWalletDepositFees(bytes32 atomId) external
```
Claims accumulated deposit fees for an atom wallet owner.

**Parameters**:
- `atomId`: Atom ID to claim fees for

**Emits**: `AtomWalletDepositFeesClaimed`

**Requirements**:
- Atom must exist
- Caller must be the atom wallet owner

### Admin Functions

#### `pause`
```solidity
function pause() external
```
Pauses the contract, preventing deposits and redemptions.

**Access**: `PAUSER_ROLE`

**Effect**: Sets contract to paused state

---

#### `unpause`
```solidity
function unpause() external
```
Unpauses the contract, allowing normal operations.

**Access**: `DEFAULT_ADMIN_ROLE`

**Effect**: Removes paused state

---

#### `sweepAccumulatedProtocolFees`
```solidity
function sweepAccumulatedProtocolFees(uint256 epoch) external
```
Transfers accumulated protocol fees for a specific epoch to the protocol multisig or TrustBonding contract.

**Parameters**:
- `epoch`: Epoch to sweep fees for

**Emits**: `ProtocolFeeTransferred`

**Access**: `CONTROLLER_ROLE`

**Requirements**:
- Epoch must be in the past

---

#### Configuration Setters

These functions update protocol configuration parameters:

**`setGeneralConfig`**: Updates general configuration
```solidity
function setGeneralConfig(GeneralConfig memory _generalConfig) external
```

**`setAtomConfig`**: Updates atom-specific configuration
```solidity
function setAtomConfig(AtomConfig memory _atomConfig) external
```

**`setTripleConfig`**: Updates triple-specific configuration
```solidity
function setTripleConfig(TripleConfig memory _tripleConfig) external
```

**`setVaultFees`**: Updates fee configuration
```solidity
function setVaultFees(VaultFees memory _vaultFees) external
```

**`setWalletConfig`**: Updates wallet configuration
```solidity
function setWalletConfig(WalletConfig memory _walletConfig) external
```

**`setBondingCurveConfig`**: Updates bonding curve configuration
```solidity
function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external
```

**Access**: `PARAMETERS_TIMELOCK_ROLE`

## Events

### `Deposited`
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
)
```
Emitted when assets are deposited into a vault.

**Use Cases**:
- Track deposit history
- Monitor vault growth
- Calculate user position changes
- Analyze fee impact

---

### `Redeemed`
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
)
```
Emitted when shares are redeemed from a vault.

**Use Cases**:
- Track redemption history
- Monitor vault contraction
- Calculate realized returns
- Analyze fee impact

---

### `AtomCreated`
```solidity
event AtomCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes atomData,
    address atomWallet
)
```
Emitted when an atom vault is created.

**Use Cases**:
- Index all atoms
- Track atom creators
- Monitor atom wallet deployments
- Build atom registry

---

### `TripleCreated`
```solidity
event TripleCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
)
```
Emitted when a triple vault is created.

**Use Cases**:
- Index all triples
- Build knowledge graph
- Track triple creators
- Monitor relationship creation

---

### `SharePriceChanged`
```solidity
event SharePriceChanged(
    bytes32 indexed termId,
    uint256 indexed curveId,
    uint256 sharePrice,
    uint256 totalAssets,
    uint256 totalShares,
    VaultType vaultType
)
```
Emitted when the share price changes in a vault.

**Use Cases**:
- Track price history
- Calculate APY
- Monitor vault performance
- Trigger price alerts

---

### `ProtocolFeeAccrued`
```solidity
event ProtocolFeeAccrued(
    uint256 indexed epoch,
    address indexed sender,
    uint256 amount
)
```
Emitted when protocol fees are accrued internally.

**Use Cases**:
- Track fee generation
- Monitor protocol revenue
- Calculate epoch rewards

---

### `ProtocolFeeTransferred`
```solidity
event ProtocolFeeTransferred(
    uint256 indexed epoch,
    address indexed destination,
    uint256 amount
)
```
Emitted when protocol fees are transferred to destination.

**Use Cases**:
- Track fee distribution
- Verify protocol income
- Monitor treasury growth

---

### `AtomWalletDepositFeeCollected`
```solidity
event AtomWalletDepositFeeCollected(
    bytes32 indexed termId,
    address indexed sender,
    uint256 amount
)
```
Emitted when atom wallet deposit fees are collected.

**Use Cases**:
- Track atom wallet fee accumulation
- Monitor fee generation per atom
- Calculate claimable fees

---

### `AtomWalletDepositFeesClaimed`
```solidity
event AtomWalletDepositFeesClaimed(
    bytes32 indexed termId,
    address indexed atomWalletOwner,
    uint256 indexed feesClaimed
)
```
Emitted when atom wallet deposit fees are claimed.

**Use Cases**:
- Track fee claims
- Monitor atom wallet owner income
- Verify fee distribution

---

### Utilization Events

**`PersonalUtilizationAdded`**: Emitted when a user's utilization increases
```solidity
event PersonalUtilizationAdded(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 personalUtilization
)
```

**`PersonalUtilizationRemoved`**: Emitted when a user's utilization decreases
```solidity
event PersonalUtilizationRemoved(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 personalUtilization
)
```

**`TotalUtilizationAdded`**: Emitted when system utilization increases
```solidity
event TotalUtilizationAdded(
    uint256 indexed epoch,
    int256 indexed valueAdded,
    int256 indexed totalUtilization
)
```

**`TotalUtilizationRemoved`**: Emitted when system utilization decreases
```solidity
event TotalUtilizationRemoved(
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 indexed totalUtilization
)
```

**Use Cases**:
- Track utilization changes
- Calculate rewards eligibility
- Monitor protocol usage
- Analyze user behavior

---

### `ApprovalTypeUpdated`
```solidity
event ApprovalTypeUpdated(
    address indexed sender,
    address indexed receiver,
    ApprovalTypes approvalType
)
```
Emitted when approval types are updated.

**Use Cases**:
- Track permission changes
- Monitor delegated operations
- Audit access control

## Errors

### `MultiVault_ArraysNotSameLength`
Thrown when array parameters have mismatched lengths in batch operations.

**Recovery**: Ensure all arrays have the same length.

---

### `MultiVault_AtomExists`
Thrown when attempting to create an atom that already exists.

**Recovery**: Use existing atom ID or modify atom data.

---

### `MultiVault_AtomDoesNotExist`
Thrown when referencing a non-existent atom.

**Recovery**: Verify atom ID is correct and atom has been created.

---

### `MultiVault_TripleExists`
Thrown when attempting to create a triple that already exists.

**Recovery**: Use existing triple ID or modify triple components.

---

### `MultiVault_TermDoesNotExist`
Thrown when referencing a non-existent term (atom or triple).

**Recovery**: Verify term ID and ensure term has been created.

---

### `MultiVault_SlippageExceeded`
Thrown when actual output is less than minimum expected (minShares or minAssets).

**Recovery**: Increase slippage tolerance or retry transaction.

---

### `MultiVault_DepositBelowMinimumDeposit`
Thrown when deposit amount is below the minimum required.

**Recovery**: Increase deposit amount to meet minimum.

---

### `MultiVault_InsufficientBalance`
Thrown when sender has insufficient TRUST balance.

**Recovery**: Acquire more TRUST tokens or reduce deposit amount.

---

### `MultiVault_InsufficientSharesInVault`
Thrown when attempting to redeem more shares than held.

**Recovery**: Reduce redemption amount to available balance.

---

### `MultiVault_SenderNotApproved`
Thrown when sender lacks deposit approval from receiver.

**Recovery**: Receiver must call `approve()` to grant DEPOSIT permission.

---

### `MultiVault_RedeemerNotApproved`
Thrown when sender lacks redemption approval from receiver.

**Recovery**: Receiver must call `approve()` to grant REDEMPTION permission.

---

### `MultiVault_OnlyAssociatedAtomWallet`
Thrown when non-owner attempts to claim atom wallet fees.

**Recovery**: Only atom wallet owner can claim fees.

---

### `MultiVault_ActionExceedsMaxAssets` / `MultiVault_ActionExceedsMaxShares`
Thrown when operation exceeds bonding curve limits.

**Recovery**: Reduce operation size or use different bonding curve.

---

### `MultiVault_InvalidArrayLength`
Thrown when batch operation exceeds MAX_BATCH_SIZE (150).

**Recovery**: Split batch into smaller operations.

---

### `MultiVault_EpochNotTracked` / `MultiVault_InvalidEpoch`
Thrown when querying utilization for invalid epoch.

**Recovery**: Verify epoch number and ensure user had activity in that epoch.

## Access Control

### Roles

The contract uses OpenZeppelin's AccessControl for role-based permissions:

**`DEFAULT_ADMIN_ROLE`** (`bytes32(0)`)
- Grant/revoke all roles
- Unpause contract
- Ultimate control over protocol

**`PAUSER_ROLE`**
- Pause contract in emergencies
- Temporary halt of deposits/redemptions

**`PARAMETERS_TIMELOCK_ROLE`**
- Update configuration parameters
- Modify fees, minimums, and settings
- Typically assigned to a timelock contract

**`CONTROLLER_ROLE`**
- Sweep protocol fees
- Operational functions

### Permission Structure

```
DEFAULT_ADMIN_ROLE (Root)
    ├─ Can grant/revoke any role
    ├─ Can unpause
    └─ Can perform any admin function

PAUSER_ROLE
    └─ Can pause only

PARAMETERS_TIMELOCK_ROLE
    ├─ setGeneralConfig
    ├─ setAtomConfig
    ├─ setTripleConfig
    ├─ setVaultFees
    ├─ setWalletConfig
    └─ setBondingCurveConfig

CONTROLLER_ROLE
    └─ sweepAccumulatedProtocolFees
```

### Approval System

Users can grant other addresses permission to deposit or redeem on their behalf:

```solidity
// Grant deposit-only permission
multiVault.approve(operatorAddress, ApprovalTypes.DEPOSIT);

// Grant both deposit and redemption permission
multiVault.approve(operatorAddress, ApprovalTypes.BOTH);

// Revoke all permissions
multiVault.approve(operatorAddress, ApprovalTypes.NONE);
```

## Usage Examples

### TypeScript (ethers.js v6)

#### Creating an Atom with Initial Deposit

```typescript
import { ethers } from 'ethers';

// Setup
const provider = new ethers.JsonRpcProvider('YOUR_INTUITION_RPC');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Contract addresses
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

// ABIs (simplified for example)
const multiVaultABI = [
  'function createAtoms(bytes[] calldata atomDatas, uint256[] calldata assets) external payable returns (bytes32[])',
  'function getAtomCost() external view returns (uint256)',
  'function previewAtomCreate(bytes32 termId, uint256 assets) external view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)'
];

const wrappedTrustABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function balanceOf(address account) external view returns (uint256)'
];

const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, multiVaultABI, signer);
const wTrust = new ethers.Contract(WTRUST_ADDRESS, wrappedTrustABI, signer);

async function createAtom() {
  try {
    // Prepare atom data (example: storing an address)
    const atomData = ethers.AbiCoder.defaultAbiCoder().encode(
      ['address'],
      [signer.address]
    );

    // Calculate atom ID
    const ATOM_SALT = ethers.keccak256(ethers.toUtf8Bytes('ATOM_SALT'));
    const atomId = ethers.keccak256(
      ethers.concat([ATOM_SALT, ethers.keccak256(atomData)])
    );

    console.log('Atom ID:', atomId);

    // Get atom creation cost
    const atomCost = await multiVault.getAtomCost();
    const depositAmount = ethers.parseEther('10'); // 10 TRUST tokens
    const totalAmount = atomCost + depositAmount;

    console.log('Atom cost:', ethers.formatEther(atomCost), 'TRUST');
    console.log('Deposit amount:', ethers.formatEther(depositAmount), 'TRUST');
    console.log('Total amount:', ethers.formatEther(totalAmount), 'TRUST');

    // Preview the creation to see expected shares
    const [shares, assetsAfterFixedFees, assetsAfterFees] =
      await multiVault.previewAtomCreate(atomId, totalAmount);

    console.log('Expected shares:', ethers.formatEther(shares));
    console.log('Assets after fees:', ethers.formatEther(assetsAfterFees), 'TRUST');

    // Check and approve TRUST tokens
    const balance = await wTrust.balanceOf(signer.address);
    console.log('TRUST balance:', ethers.formatEther(balance));

    if (balance < totalAmount) {
      throw new Error('Insufficient TRUST balance');
    }

    // Approve MultiVault to spend TRUST
    console.log('Approving TRUST...');
    const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, totalAmount);
    await approveTx.wait();
    console.log('Approved');

    // Create atom
    console.log('Creating atom...');
    const tx = await multiVault.createAtoms([atomData], [totalAmount]);
    console.log('Transaction hash:', tx.hash);

    const receipt = await tx.wait();
    console.log('Atom created successfully!');
    console.log('Gas used:', receipt.gasUsed.toString());

    // Parse events
    const atomCreatedEvent = receipt.logs.find(
      (log) => log.topics[0] === ethers.id('AtomCreated(address,bytes32,bytes,address)')
    );

    if (atomCreatedEvent) {
      console.log('AtomCreated event found');
      // Decode event data for atomWallet address
    }

    return atomId;

  } catch (error) {
    console.error('Error creating atom:', error);
    throw error;
  }
}

// Run the function
createAtom()
  .then((atomId) => console.log('Final atom ID:', atomId))
  .catch((error) => console.error('Failed:', error));
```

#### Depositing into an Existing Vault

```typescript
async function depositIntoVault(
  termId: string,
  curveId: number,
  depositAmount: bigint
) {
  try {
    const receiver = signer.address;

    // Preview deposit to see expected shares
    const [shares, assetsAfterFees] = await multiVault.previewDeposit(
      termId,
      curveId,
      depositAmount
    );

    console.log('Expected shares:', ethers.formatEther(shares));
    console.log('Assets after fees:', ethers.formatEther(assetsAfterFees));

    // Set slippage tolerance (e.g., 1%)
    const minShares = shares * 99n / 100n;

    // Approve TRUST
    const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, depositAmount);
    await approveTx.wait();

    // Deposit
    console.log('Depositing...');
    const tx = await multiVault.deposit(
      receiver,
      termId,
      curveId,
      minShares
    );

    const receipt = await tx.wait();
    console.log('Deposit successful!');
    console.log('Gas used:', receipt.gasUsed.toString());

    // Get updated share balance
    const shareBalance = await multiVault.getShares(receiver, termId, curveId);
    console.log('New share balance:', ethers.formatEther(shareBalance));

  } catch (error) {
    console.error('Error depositing:', error);
    throw error;
  }
}
```

#### Redeeming Shares from a Vault

```typescript
async function redeemShares(
  termId: string,
  curveId: number,
  sharesToRedeem: bigint
) {
  try {
    const receiver = signer.address;

    // Check share balance
    const shareBalance = await multiVault.getShares(signer.address, termId, curveId);
    console.log('Share balance:', ethers.formatEther(shareBalance));

    if (shareBalance < sharesToRedeem) {
      throw new Error('Insufficient shares');
    }

    // Preview redemption
    const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
      termId,
      curveId,
      sharesToRedeem
    );

    console.log('Expected assets:', ethers.formatEther(assetsAfterFees));

    // Set slippage tolerance (e.g., 1%)
    const minAssets = assetsAfterFees * 99n / 100n;

    // Redeem
    console.log('Redeeming...');
    const tx = await multiVault.redeem(
      receiver,
      termId,
      curveId,
      sharesToRedeem,
      minAssets
    );

    const receipt = await tx.wait();
    console.log('Redemption successful!');
    console.log('Gas used:', receipt.gasUsed.toString());

    // Get updated balances
    const newShareBalance = await multiVault.getShares(receiver, termId, curveId);
    const trustBalance = await wTrust.balanceOf(receiver);

    console.log('New share balance:', ethers.formatEther(newShareBalance));
    console.log('TRUST balance:', ethers.formatEther(trustBalance));

  } catch (error) {
    console.error('Error redeeming:', error);
    throw error;
  }
}
```

### Python (web3.py)

```python
from web3 import Web3
from typing import List, Tuple
import json

# Setup
w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
account = w3.eth.account.from_key('YOUR_PRIVATE_KEY')

# Contract addresses
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672'

# Load ABIs
with open('MultiVault.json') as f:
    multivault_abi = json.load(f)['abi']

with open('WrappedTrust.json') as f:
    wtrust_abi = json.load(f)['abi']

multivault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=multivault_abi)
wtrust = w3.eth.contract(address=WTRUST_ADDRESS, abi=wtrust_abi)

def create_triple(
    subject_id: bytes,
    predicate_id: bytes,
    object_id: bytes,
    deposit_amount: int
) -> bytes:
    """Create a triple with initial deposit"""
    try:
        # Calculate triple cost
        triple_cost = multivault.functions.getTripleCost().call()
        total_amount = triple_cost + deposit_amount

        print(f'Triple cost: {w3.from_wei(triple_cost, "ether")} TRUST')
        print(f'Deposit amount: {w3.from_wei(deposit_amount, "ether")} TRUST')
        print(f'Total amount: {w3.from_wei(total_amount, "ether")} TRUST')

        # Check balance
        balance = wtrust.functions.balanceOf(account.address).call()
        if balance < total_amount:
            raise ValueError('Insufficient TRUST balance')

        # Approve TRUST
        print('Approving TRUST...')
        approve_tx = wtrust.functions.approve(
            MULTIVAULT_ADDRESS,
            total_amount
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })

        signed_approve = account.sign_transaction(approve_tx)
        approve_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
        w3.eth.wait_for_transaction_receipt(approve_hash)
        print('Approved')

        # Create triple
        print('Creating triple...')
        create_tx = multivault.functions.createTriples(
            [subject_id],
            [predicate_id],
            [object_id],
            [total_amount]
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })

        signed_create = account.sign_transaction(create_tx)
        create_hash = w3.eth.send_raw_transaction(signed_create.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(create_hash)

        print(f'Triple created successfully!')
        print(f'Transaction hash: {create_hash.hex()}')
        print(f'Gas used: {receipt["gasUsed"]}')

        # Calculate triple ID
        TRIPLE_SALT = w3.keccak(text='TRIPLE_SALT')
        triple_id = w3.keccak(
            TRIPLE_SALT +
            subject_id +
            predicate_id +
            object_id
        )

        return triple_id

    except Exception as e:
        print(f'Error creating triple: {e}')
        raise

def batch_deposit(
    term_ids: List[bytes],
    curve_ids: List[int],
    assets: List[int],
    min_shares: List[int]
) -> List[int]:
    """Deposit into multiple vaults in a single transaction"""
    try:
        receiver = account.address

        # Calculate total amount needed
        total_amount = sum(assets)

        # Check balance
        balance = wtrust.functions.balanceOf(account.address).call()
        if balance < total_amount:
            raise ValueError('Insufficient TRUST balance')

        # Approve TRUST
        print('Approving TRUST...')
        approve_tx = wtrust.functions.approve(
            MULTIVAULT_ADDRESS,
            total_amount
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })

        signed_approve = account.sign_transaction(approve_tx)
        approve_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
        w3.eth.wait_for_transaction_receipt(approve_hash)

        # Batch deposit
        print(f'Depositing into {len(term_ids)} vaults...')
        deposit_tx = multivault.functions.depositBatch(
            receiver,
            term_ids,
            curve_ids,
            assets,
            min_shares
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 1000000 + (len(term_ids) * 200000),  # Scale gas with batch size
            'gasPrice': w3.eth.gas_price
        })

        signed_deposit = account.sign_transaction(deposit_tx)
        deposit_hash = w3.eth.send_raw_transaction(signed_deposit.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(deposit_hash)

        print(f'Batch deposit successful!')
        print(f'Gas used: {receipt["gasUsed"]}')

        # Note: In production, decode receipt logs to get actual shares minted
        return min_shares  # Placeholder

    except Exception as e:
        print(f'Error in batch deposit: {e}')
        raise

# Example usage
if __name__ == '__main__':
    # Example atom IDs (replace with real IDs)
    subject_id = bytes.fromhex('1234...')
    predicate_id = bytes.fromhex('5678...')
    object_id = bytes.fromhex('9abc...')

    # Create triple with 10 TRUST deposit
    triple_id = create_triple(
        subject_id,
        predicate_id,
        object_id,
        w3.to_wei(10, 'ether')
    )

    print(f'Triple ID: {triple_id.hex()}')
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMultiVault.sol";
import "./interfaces/IERC20.sol";

/**
 * @title IntuitionIntegration
 * @notice Example contract showing how to integrate with MultiVault
 */
contract IntuitionIntegration {
    IMultiVault public immutable multiVault;
    IERC20 public immutable wrappedTrust;

    constructor(address _multiVault, address _wrappedTrust) {
        multiVault = IMultiVault(_multiVault);
        wrappedTrust = IERC20(_wrappedTrust);
    }

    /**
     * @notice Creates an atom and deposits into it
     * @param atomData The data to store in the atom
     * @param depositAmount Amount of TRUST to deposit
     * @return atomId The ID of the created atom
     */
    function createAndDepositAtom(
        bytes calldata atomData,
        uint256 depositAmount
    ) external returns (bytes32 atomId) {
        // Get atom cost
        uint256 atomCost = multiVault.getAtomCost();
        uint256 totalAmount = atomCost + depositAmount;

        // Transfer TRUST from sender
        require(
            wrappedTrust.transferFrom(msg.sender, address(this), totalAmount),
            "Transfer failed"
        );

        // Approve MultiVault
        wrappedTrust.approve(address(multiVault), totalAmount);

        // Create atom
        bytes[] memory atomDatas = new bytes[](1);
        atomDatas[0] = atomData;

        uint256[] memory assets = new uint256[](1);
        assets[0] = totalAmount;

        bytes32[] memory atomIds = multiVault.createAtoms(atomDatas, assets);
        atomId = atomIds[0];

        emit AtomCreatedAndDeposited(msg.sender, atomId, depositAmount);
    }

    /**
     * @notice Deposits into multiple vaults atomically
     * @param termIds Array of term IDs to deposit into
     * @param curveIds Array of curve IDs to use
     * @param amounts Array of deposit amounts
     */
    function multiDeposit(
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata amounts
    ) external {
        require(
            termIds.length == curveIds.length &&
            termIds.length == amounts.length,
            "Array length mismatch"
        );

        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        // Transfer TRUST from sender
        require(
            wrappedTrust.transferFrom(msg.sender, address(this), totalAmount),
            "Transfer failed"
        );

        // Approve MultiVault
        wrappedTrust.approve(address(multiVault), totalAmount);

        // Preview deposits to calculate minShares with 1% slippage
        uint256[] memory minShares = new uint256[](termIds.length);
        for (uint256 i = 0; i < termIds.length; i++) {
            (uint256 shares, ) = multiVault.previewDeposit(
                termIds[i],
                curveIds[i],
                amounts[i]
            );
            minShares[i] = (shares * 99) / 100;  // 1% slippage
        }

        // Deposit batch
        multiVault.depositBatch(
            msg.sender,
            termIds,
            curveIds,
            amounts,
            minShares
        );

        emit MultiDepositCompleted(msg.sender, termIds.length, totalAmount);
    }

    /**
     * @notice Redeems shares and sends assets to sender
     * @param termId Term ID to redeem from
     * @param curveId Curve ID to use
     * @param shares Amount of shares to redeem
     */
    function redeemShares(
        bytes32 termId,
        uint256 curveId,
        uint256 shares
    ) external {
        // Note: This requires the sender to have granted this contract
        // REDEMPTION approval via multiVault.approve()

        // Preview redemption for slippage protection
        (uint256 assetsAfterFees, ) = multiVault.previewRedeem(
            termId,
            curveId,
            shares
        );

        uint256 minAssets = (assetsAfterFees * 99) / 100;  // 1% slippage

        // Redeem
        uint256 assetsReturned = multiVault.redeem(
            msg.sender,
            termId,
            curveId,
            shares,
            minAssets
        );

        emit SharesRedeemed(msg.sender, termId, shares, assetsReturned);
    }

    /**
     * @notice Gets vault information
     * @param termId Term ID to query
     * @param curveId Curve ID to query
     * @return totalAssets Total assets in vault
     * @return totalShares Total shares in vault
     * @return sharePrice Current share price
     */
    function getVaultInfo(
        bytes32 termId,
        uint256 curveId
    ) external view returns (
        uint256 totalAssets,
        uint256 totalShares,
        uint256 sharePrice
    ) {
        (totalAssets, totalShares) = multiVault.getVault(termId, curveId);
        sharePrice = multiVault.currentSharePrice(termId, curveId);
    }

    event AtomCreatedAndDeposited(
        address indexed creator,
        bytes32 indexed atomId,
        uint256 depositAmount
    );

    event MultiDepositCompleted(
        address indexed depositor,
        uint256 vaultCount,
        uint256 totalAmount
    );

    event SharesRedeemed(
        address indexed redeemer,
        bytes32 indexed termId,
        uint256 shares,
        uint256 assetsReturned
    );
}
```

## Integration Notes

### For SDK Builders

1. **Approval Pattern**: Always approve TRUST before calling deposit/create functions
2. **Slippage Protection**: Use preview functions to calculate minShares/minAssets
3. **Event Monitoring**: Monitor `Deposited`, `Redeemed`, and creation events for state changes
4. **Batch Operations**: Use batch functions for multiple operations to save gas
5. **Error Handling**: Implement retry logic for slippage failures

### Common Patterns

#### Creating Multiple Terms Efficiently

```typescript
// Batch create atoms
const atomDatas = [data1, data2, data3];
const assets = [amount1, amount2, amount3];
const atomIds = await multiVault.createAtoms(atomDatas, assets);

// Batch create triples
const subjectIds = [sub1, sub2, sub3];
const predicateIds = [pred1, pred2, pred3];
const objectIds = [obj1, obj2, obj3];
const assets = [amount1, amount2, amount3];
const tripleIds = await multiVault.createTriples(
  subjectIds,
  predicateIds,
  objectIds,
  assets
);
```

#### Handling Approvals for Delegation

```typescript
// User grants deposit permission to operator
await multiVault.connect(user).approve(
  operatorAddress,
  ApprovalTypes.DEPOSIT
);

// Operator deposits on behalf of user
await multiVault.connect(operator).deposit(
  userAddress,      // receiver
  termId,
  curveId,
  minShares
);
```

### Edge Cases

1. **First Deposit**: First depositor into a vault receives slightly fewer shares due to minimum share burn (protection against inflation attacks)
2. **Fee Thresholds**: Entry/exit fees only apply when vault exceeds fee threshold in default curve
3. **Counter Triples**: Created automatically with positive triples, cannot be created directly
4. **Utilization History**: Only last 3 active epochs tracked per user; older epochs may not be queryable
5. **Epoch Boundaries**: Utilization tracking changes at epoch boundaries (defined by TrustBonding)

## Gas Considerations

### Approximate Gas Costs

| Operation | Estimated Gas | Notes |
|-----------|--------------|-------|
| `createAtoms` (single) | ~450,000 | Includes atom wallet deployment |
| `createTriples` (single) | ~350,000 | Deposits into 3 underlying atoms |
| `deposit` (first time) | ~180,000 | First deposit into vault |
| `deposit` (subsequent) | ~120,000 | Additional deposits |
| `redeem` | ~100,000 | Standard redemption |
| `depositBatch` (10 vaults) | ~1,200,000 | Scales with batch size |
| `redeemBatch` (10 vaults) | ~1,000,000 | Scales with batch size |

### Optimization Tips

1. **Use Batch Operations**: Batch functions are more gas-efficient than multiple individual calls
2. **Avoid Small Deposits**: Gas cost is relatively fixed, so larger deposits are more efficient
3. **Reuse Curve IDs**: Creating vaults with existing curves is cheaper than deploying new curves
4. **Monitor Gas Prices**: Submit transactions during low-congestion periods
5. **Aggregate Operations**: Combine create + deposit operations when possible

### Gas-Intensive Operations

- **Atom Creation**: Deploys new atom wallet (ERC-4337 account)
- **Triple Creation**: Makes deposits into 3 underlying atom vaults
- **First Vault Deposit**: Initializes vault state and mints minimum shares
- **Utilization Updates**: Writes to storage on every deposit/redemption

## Related Contracts

### Core Dependencies

- **[MultiVaultCore](./MultiVaultCore.md)**: Base contract providing core state and configuration management
- **[Trust](./Trust.md)**: ERC20 token used as base asset for all vaults
- **[WrappedTrust](../WrappedTrust.md)**: Wrapped native token for user interactions

### Supporting Contracts

- **[BondingCurveRegistry](../curves/BondingCurveRegistry.md)**: Registry of available bonding curves
- **[TrustBonding](../emissions/TrustBonding.md)**: Emissions and rewards distribution based on utilization
- **[AtomWalletFactory](../wallet/AtomWalletFactory.md)**: Factory for deploying atom wallets
- **[AtomWarden](../wallet/AtomWarden.md)**: Registry and ownership manager for atom wallets

### Integration Flow

```
User
  ↓ (deposits TRUST)
MultiVault
  ↓ (queries pricing)
BondingCurveRegistry → Bonding Curve (Linear, Progressive, etc.)
  ↓ (records utilization)
TrustBonding → Calculates rewards eligibility
  ↓ (for atom deposits)
AtomWalletFactory → Creates AtomWallet
  ↓ (ownership management)
AtomWarden
```

## See Also

### Concept Documentation
- [Atoms and Triples](../../concepts/atoms-and-triples.md) - Understanding the core data model
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - Architecture deep dive
- [Bonding Curves](../../concepts/bonding-curves.md) - Price discovery mechanisms
- [Utilization Tracking](../../concepts/utilization-tracking.md) - How rewards eligibility is calculated

### Integration Guides
- [Creating Atoms](../../guides/creating-atoms.md) - Step-by-step atom creation
- [Creating Triples](../../guides/creating-triples.md) - Step-by-step triple creation
- [Depositing Assets](../../guides/depositing-assets.md) - Vault deposit flows
- [Redeeming Shares](../../guides/redeeming-shares.md) - Vault redemption flows
- [Batch Operations](../../guides/batch-operations.md) - Efficient multi-vault operations
- [Fee Structure](../../guides/fee-structure.md) - Understanding all fee types

### API Reference
- [Events Reference](../../reference/events.md) - Complete events documentation
- [Errors Reference](../../reference/errors.md) - Error codes and recovery
- [Data Structures](../../reference/data-structures.md) - Struct definitions

---

**Last Updated**: December 2025
**Version**: V2.0
