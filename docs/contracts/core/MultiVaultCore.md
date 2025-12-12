# MultiVaultCore

## Overview

The **MultiVaultCore** contract is the foundational base contract for the Intuition Protocol V2, providing core state management, configuration handling, and data registry functionality. It serves as the abstract parent contract for MultiVault, managing the storage and validation logic for atoms, triples, and protocol-wide configuration parameters.

### Purpose and Role in Protocol

- **Data Registry**: Maintains the canonical storage of all atoms and triples created in the protocol
- **Configuration Manager**: Stores and manages all protocol configuration structs (general, atom, triple, wallet, fees, bonding curves)
- **ID Calculation**: Provides deterministic calculation functions for atom and triple IDs using salt-based hashing
- **Term Validation**: Offers verification methods to check if terms exist and determine their types
- **State Foundation**: Provides the base state layer that MultiVault builds upon for vault operations

### Key Responsibilities

1. **Atom Management**: Stores atom data and provides methods to calculate, retrieve, and validate atom IDs
2. **Triple Management**: Stores triple relationships (subject-predicate-object) and manages counter triples
3. **Configuration Storage**: Maintains all protocol configuration structs in a single, upgradeable location
4. **ID Generation**: Implements deterministic ID calculation using keccak256 hashing with protocol salts
5. **Type Determination**: Provides functions to identify whether a term is an atom, triple, or counter triple

## Contract Information

- **Location**: `src/protocol/MultiVaultCore.sol`
- **Inherits**:
  - `IMultiVaultCore` (interface)
  - `Initializable` (OpenZeppelin upgradeable initialization)
- **Interface**: `IMultiVaultCore` (`src/interfaces/IMultiVaultCore.sol`)
- **Upgradeable**: Yes (used as base for UUPS proxy pattern)
- **Abstract**: Yes (must be inherited by MultiVault)

### Network Deployments

MultiVaultCore is an abstract contract and is deployed as part of the MultiVault contract. See the MultiVault documentation for deployment addresses.

## Key Concepts

### Salted ID Generation

The protocol uses three distinct salts for generating deterministic IDs:

```solidity
bytes32 public constant ATOM_SALT = keccak256("ATOM_SALT");
bytes32 public constant TRIPLE_SALT = keccak256("TRIPLE_SALT");
bytes32 public constant COUNTER_SALT = keccak256("COUNTER_SALT");
```

This ensures that:
- Atom IDs are unique and deterministic based on their data
- Triple IDs are unique based on their subject-predicate-object composition
- Counter triples (representing disagreement) have distinct IDs from positive triples

### Configuration Structs

MultiVaultCore manages six configuration structs that control all protocol behavior:

#### 1. GeneralConfig
Core protocol parameters including admin addresses, fee denominators, and system limits.

```solidity
struct GeneralConfig {
    address admin;                  // Protocol admin address
    address protocolMultisig;       // Protocol fee recipient
    uint256 feeDenominator;         // Denominator for fee calculations
    address trustBonding;           // TrustBonding contract address
    uint256 minDeposit;            // Minimum deposit amount
    uint256 minShare;              // Minimum shares minted at vault creation
    uint256 atomDataMaxLength;     // Maximum length of atom data (bytes)
    uint256 feeThreshold;          // Total shares threshold for entry/exit fees
}
```

#### 2. AtomConfig
Configuration specific to atom vault creation and fees.

```solidity
struct AtomConfig {
    uint256 atomCreationProtocolFee;  // Fee paid to protocol for atom creation
    uint256 atomWalletDepositFee;     // Portion of deposits for atom wallet owners
}
```

#### 3. TripleConfig
Configuration for triple vault creation and underlying atom deposits.

```solidity
struct TripleConfig {
    uint256 tripleCreationProtocolFee;    // Fee paid to protocol for triple creation
    uint256 atomDepositFractionForTriple; // Percentage of triple deposits to underlying atoms
}
```

#### 4. WalletConfig
ERC-4337 smart wallet infrastructure addresses.

```solidity
struct WalletConfig {
    address entryPoint;           // ERC-4337 EntryPoint contract
    address atomWarden;           // Atom wallet registry and ownership manager
    address atomWalletBeacon;     // UpgradeableBeacon for AtomWallet implementation
    address atomWalletFactory;    // Factory for deploying atom wallets
}
```

#### 5. VaultFees
Fee rates applied to vault operations.

```solidity
struct VaultFees {
    uint256 entryFee;     // Fee on deposits (remains in vault)
    uint256 exitFee;      // Fee on redemptions (remains in vault)
    uint256 protocolFee;  // Fee sent to protocol multisig
}
```

#### 6. BondingCurveConfig
Bonding curve registry and default settings.

```solidity
struct BondingCurveConfig {
    address registry;         // BondingCurveRegistry contract
    uint256 defaultCurveId;   // Default curve ID for new vaults
}
```

### Atom and Triple Storage

**Atoms**: Stored as arbitrary bytes data mapped by atom ID
```solidity
mapping(bytes32 atomId => bytes data) internal _atoms;
```

**Triples**: Stored as fixed-size arrays of 3 atom IDs (subject, predicate, object)
```solidity
mapping(bytes32 tripleId => bytes32[3] tripleAtomIds) internal _triples;
```

**Triple Type Flags**: Boolean mapping to distinguish triples from atoms
```solidity
mapping(bytes32 termId => bool isTriple) internal _isTriple;
```

**Counter Triple Mapping**: Links counter triple IDs to their positive triple IDs
```solidity
mapping(bytes32 counterTripleId => bytes32 tripleId) internal _tripleIdFromCounterId;
```

## State Variables

### Constants

```solidity
bytes32 public constant ATOM_SALT = keccak256("ATOM_SALT");
bytes32 public constant TRIPLE_SALT = keccak256("TRIPLE_SALT");
bytes32 public constant COUNTER_SALT = keccak256("COUNTER_SALT");
```

- **ATOM_SALT**: Salt prefix for atom ID generation (deterministic)
- **TRIPLE_SALT**: Salt prefix for positive triple ID generation
- **COUNTER_SALT**: Salt prefix for counter triple ID generation

### Configuration State

```solidity
uint256 public totalTermsCreated;
GeneralConfig public generalConfig;
AtomConfig public atomConfig;
TripleConfig public tripleConfig;
WalletConfig public walletConfig;
VaultFees public vaultFees;
BondingCurveConfig public bondingCurveConfig;
```

### Storage Mappings

**Atom Storage**:
```solidity
mapping(bytes32 atomId => bytes data) internal _atoms;
```
Stores the raw data associated with each atom ID.

**Triple Storage**:
```solidity
mapping(bytes32 tripleId => bytes32[3] tripleAtomIds) internal _triples;
```
Stores the [subject, predicate, object] atom IDs for each triple.

**Type Flags**:
```solidity
mapping(bytes32 termId => bool isTriple) internal _isTriple;
```
Flags to identify whether a term ID represents a triple (true) or atom (false).

**Counter Triple Mapping**:
```solidity
mapping(bytes32 counterTripleId => bytes32 tripleId) internal _tripleIdFromCounterId;
```
Maps counter triple IDs back to their corresponding positive triple IDs.

## Functions

### Initializer

#### `initialize`
```solidity
function initialize(
    GeneralConfig memory _generalConfig,
    AtomConfig memory _atomConfig,
    TripleConfig memory _tripleConfig,
    WalletConfig memory _walletConfig,
    VaultFees memory _vaultFees,
    BondingCurveConfig memory _bondingCurveConfig
) external
```

Initializes the MultiVaultCore contract with all configuration parameters.

**Parameters**:
- `_generalConfig`: General protocol configuration
- `_atomConfig`: Atom-specific configuration
- `_tripleConfig`: Triple-specific configuration
- `_walletConfig`: ERC-4337 wallet configuration
- `_vaultFees`: Fee configuration
- `_bondingCurveConfig`: Bonding curve settings

**Requirements**:
- Can only be called once (initializer modifier)
- Admin address must not be zero address

**Internal Call**: `__MultiVaultCore_init()` - Sets all configuration structs

---

### Configuration Getters

#### `getGeneralConfig`
```solidity
function getGeneralConfig() external view returns (GeneralConfig memory)
```
Returns the general configuration struct.

---

#### `getAtomConfig`
```solidity
function getAtomConfig() external view returns (AtomConfig memory)
```
Returns the atom configuration struct.

---

#### `getTripleConfig`
```solidity
function getTripleConfig() external view returns (TripleConfig memory)
```
Returns the triple configuration struct.

---

#### `getWalletConfig`
```solidity
function getWalletConfig() external view returns (WalletConfig memory)
```
Returns the wallet configuration struct containing ERC-4337 addresses.

---

#### `getVaultFees`
```solidity
function getVaultFees() external view returns (VaultFees memory)
```
Returns the vault fees configuration struct.

---

#### `getBondingCurveConfig`
```solidity
function getBondingCurveConfig() external view returns (BondingCurveConfig memory)
```
Returns the bonding curve configuration struct.

---

#### `walletConfig`
```solidity
function walletConfig() external view returns (
    address entryPoint,
    address atomWarden,
    address atomWalletBeacon,
    address atomWalletFactory
)
```
Returns the wallet configuration as individual return values.

**Returns**:
- `entryPoint`: ERC-4337 EntryPoint contract address
- `atomWarden`: AtomWarden contract address
- `atomWalletBeacon`: UpgradeableBeacon contract address
- `atomWalletFactory`: AtomWalletFactory contract address

---

### Atom Functions

#### `atom`
```solidity
function atom(bytes32 atomId) external view returns (bytes memory data)
```
Returns the atom data for a given atom ID. Does not revert if atom doesn't exist (returns empty bytes).

**Parameters**:
- `atomId`: The ID of the atom to query

**Returns**: Atom data (empty if atom doesn't exist)

---

#### `getAtom`
```solidity
function getAtom(bytes32 atomId) external view returns (bytes memory data)
```
Returns the atom data for a given atom ID. Reverts if atom doesn't exist.

**Parameters**:
- `atomId`: The ID of the atom to query

**Returns**: Atom data

**Reverts**: `MultiVaultCore_AtomDoesNotExist` if atom doesn't exist

---

#### `calculateAtomId`
```solidity
function calculateAtomId(bytes memory data) external pure returns (bytes32 id)
```
Calculates the atom ID from the provided atom data.

**Parameters**:
- `data`: The data to calculate the atom ID for

**Returns**: The calculated atom ID

**Calculation**: `keccak256(abi.encodePacked(ATOM_SALT, keccak256(data)))`

---

#### `getAtomCost`
```solidity
function getAtomCost() external view returns (uint256)
```
Returns the static costs required to create an atom.

**Returns**: `atomCreationProtocolFee + minShare`

**Breakdown**:
- `atomCreationProtocolFee`: Fee paid to protocol
- `minShare`: Minimum shares minted to burn address (inflation protection)

---

#### `isAtom`
```solidity
function isAtom(bytes32 atomId) external view returns (bool)
```
Checks if a term ID corresponds to an atom.

**Parameters**:
- `atomId`: The term ID to check

**Returns**: `true` if the term is an atom, `false` otherwise

**Logic**: Checks if `_atoms[atomId].length != 0`

---

### Triple Functions

#### `triple`
```solidity
function triple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32)
```
Returns the underlying atom IDs for a given triple ID. Does not revert if triple doesn't exist.

**Parameters**:
- `tripleId`: The ID of the triple to query

**Returns**: `(subjectId, predicateId, objectId)` tuple (all zero if triple doesn't exist)

---

#### `getTriple`
```solidity
function getTriple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32)
```
Returns the underlying atom IDs for a given triple ID. Reverts if triple doesn't exist.

**Parameters**:
- `tripleId`: The ID of the triple to query

**Returns**: `(subjectId, predicateId, objectId)` tuple

**Reverts**: `MultiVaultCore_TripleDoesNotExist` if triple doesn't exist

---

#### `calculateTripleId`
```solidity
function calculateTripleId(
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
) external pure returns (bytes32)
```
Calculates the triple ID from subject, predicate, and object atom IDs.

**Parameters**:
- `subjectId`: Subject atom ID
- `predicateId`: Predicate atom ID
- `objectId`: Object atom ID

**Returns**: Calculated triple ID

**Calculation**: `keccak256(abi.encodePacked(TRIPLE_SALT, subjectId, predicateId, objectId))`

---

#### `calculateCounterTripleId`
```solidity
function calculateCounterTripleId(
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
) external pure returns (bytes32)
```
Calculates the counter triple ID for a given subject-predicate-object combination.

**Parameters**:
- `subjectId`: Subject atom ID
- `predicateId`: Predicate atom ID
- `objectId`: Object atom ID

**Returns**: Calculated counter triple ID

**Logic**:
1. Calculate positive triple ID
2. Apply counter salt: `keccak256(abi.encodePacked(COUNTER_SALT, tripleId))`

---

#### `getCounterIdFromTripleId`
```solidity
function getCounterIdFromTripleId(bytes32 tripleId) external pure returns (bytes32)
```
Returns the counter triple ID for a given positive triple ID.

**Parameters**:
- `tripleId`: The positive triple ID

**Returns**: Counter triple ID

---

#### `getTripleIdFromCounterId`
```solidity
function getTripleIdFromCounterId(bytes32 counterId) external view returns (bytes32)
```
Returns the positive triple ID for a given counter triple ID.

**Parameters**:
- `counterId`: The counter triple ID

**Returns**: Positive triple ID

---

#### `getTripleCost`
```solidity
function getTripleCost() external view returns (uint256)
```
Returns the static costs required to create a triple.

**Returns**: `tripleCreationProtocolFee + (minShare * 2)`

**Breakdown**:
- `tripleCreationProtocolFee`: Fee paid to protocol
- `minShare * 2`: Minimum shares for positive and counter triple vaults

---

#### `isTriple`
```solidity
function isTriple(bytes32 id) external view returns (bool)
```
Checks if a term ID corresponds to a triple (positive or counter).

**Parameters**:
- `id`: The term ID to check

**Returns**: `true` if the term is a triple, `false` otherwise

---

#### `isCounterTriple`
```solidity
function isCounterTriple(bytes32 termId) external view returns (bool)
```
Checks if a term ID corresponds to a counter triple specifically.

**Parameters**:
- `termId`: The term ID to check

**Returns**: `true` if the term is a counter triple, `false` otherwise

**Logic**: Checks if `_tripleIdFromCounterId[termId] != bytes32(0)`

---

#### `getInverseTripleId`
```solidity
function getInverseTripleId(bytes32 tripleId) external view returns (bytes32)
```
Returns the inverse triple ID (positive ↔ counter) for a given triple ID.

**Parameters**:
- `tripleId`: Triple ID (positive or counter)

**Returns**: Inverse triple ID

**Logic**:
- If input is counter triple: returns positive triple ID
- If input is positive triple: returns counter triple ID

---

#### `getVaultType`
```solidity
function getVaultType(bytes32 termId) external view returns (VaultType)
```
Determines the vault type for a given term ID.

**Parameters**:
- `termId`: Term ID to check

**Returns**: `VaultType` enum (ATOM, TRIPLE, or COUNTER_TRIPLE)

**Reverts**: `MultiVaultCore_TermDoesNotExist` if term doesn't exist

---

## Events

### `GeneralConfigUpdated`
```solidity
event GeneralConfigUpdated(
    address indexed admin,
    address indexed protocolMultisig,
    uint256 feeDenominator,
    address indexed trustBonding,
    uint256 minDeposit,
    uint256 minShare,
    uint256 atomDataMaxLength,
    uint256 feeThreshold
)
```
Emitted when the general configuration is updated.

**Use Cases**:
- Track protocol parameter changes
- Monitor admin address changes
- Index configuration history

---

### `AtomConfigUpdated`
```solidity
event AtomConfigUpdated(
    uint256 atomCreationProtocolFee,
    uint256 atomWalletDepositFee
)
```
Emitted when the atom configuration is updated.

**Use Cases**:
- Monitor atom creation fee changes
- Track atom wallet fee adjustments

---

### `TripleConfigUpdated`
```solidity
event TripleConfigUpdated(
    uint256 tripleCreationProtocolFee,
    uint256 atomDepositFractionForTriple
)
```
Emitted when the triple configuration is updated.

**Use Cases**:
- Monitor triple creation fee changes
- Track atom deposit fraction adjustments

---

### `WalletConfigUpdated`
```solidity
event WalletConfigUpdated(
    address indexed entryPoint,
    address indexed atomWarden,
    address indexed atomWalletBeacon,
    address atomWalletFactory
)
```
Emitted when the wallet configuration is updated.

**Use Cases**:
- Track ERC-4337 infrastructure changes
- Monitor wallet implementation upgrades

---

### `VaultFeesUpdated`
```solidity
event VaultFeesUpdated(
    uint256 entryFee,
    uint256 exitFee,
    uint256 protocolFee
)
```
Emitted when the vault fees configuration is updated.

**Use Cases**:
- Monitor fee rate changes
- Track protocol revenue parameters

---

### `BondingCurveConfigUpdated`
```solidity
event BondingCurveConfigUpdated(
    address indexed registry,
    uint256 defaultCurveId
)
```
Emitted when the bonding curve configuration is updated.

**Use Cases**:
- Track bonding curve registry changes
- Monitor default curve updates

---

## Errors

### `MultiVaultCore_InvalidAdmin`
Thrown when attempting to set the zero address as admin.

**Recovery**: Provide a valid admin address (non-zero)

---

### `MultiVaultCore_AtomDoesNotExist`
Thrown when querying an atom that hasn't been created.

**Parameters**: `bytes32 termId` - The atom ID that doesn't exist

**Recovery**: Verify the atom ID is correct and the atom has been created

---

### `MultiVaultCore_TripleDoesNotExist`
Thrown when querying a triple that hasn't been created.

**Parameters**: `bytes32 termId` - The triple ID that doesn't exist

**Recovery**: Verify the triple ID is correct and the triple has been created

---

### `MultiVaultCore_TermDoesNotExist`
Thrown when querying a term (atom or triple) that doesn't exist.

**Parameters**: `bytes32 termId` - The term ID that doesn't exist

**Recovery**: Verify the term ID and ensure it has been created

---

## Internal Functions

These functions are available to inheriting contracts (like MultiVault):

### `_setGeneralConfig`
```solidity
function _setGeneralConfig(GeneralConfig memory _generalConfig) internal
```
Sets and validates the general configuration struct.

**Validation**: Reverts if admin is zero address

---

### `_isAtom`
```solidity
function _isAtom(bytes32 atomId) internal view returns (bool)
```
Internal function to check if an atom exists.

---

### `_calculateAtomId`
```solidity
function _calculateAtomId(bytes memory data) internal pure returns (bytes32 id)
```
Internal function to calculate atom ID from data.

---

### `_calculateTripleId`
```solidity
function _calculateTripleId(
    bytes32 subjectId,
    bytes32 predicateId,
    bytes32 objectId
) internal pure returns (bytes32)
```
Internal function to calculate triple ID from component atoms.

---

### `_calculateCounterTripleId`
```solidity
function _calculateCounterTripleId(bytes32 tripleId) internal pure returns (bytes32)
```
Internal function to calculate counter triple ID from positive triple ID.

---

### `_isCounterTriple`
```solidity
function _isCounterTriple(bytes32 termId) internal view returns (bool)
```
Internal function to check if a term is a counter triple.

---

### `_getAtom`
```solidity
function _getAtom(bytes32 atomId) internal view returns (bytes memory data)
```
Internal function to get atom data with existence check (reverts if not exists).

---

### `_getTriple`
```solidity
function _getTriple(bytes32 tripleId) internal view returns (bytes32, bytes32, bytes32)
```
Internal function to get triple atoms with existence check (reverts if not exists).

---

### `_getInverseTripleId`
```solidity
function _getInverseTripleId(bytes32 tripleId) internal view returns (bytes32)
```
Internal function to get the inverse triple ID (positive ↔ counter).

---

### `_getVaultType`
```solidity
function _getVaultType(bytes32 termId) internal view returns (VaultType)
```
Internal function to determine vault type with existence check.

---

### `_getAtomCost`
```solidity
function _getAtomCost() internal view returns (uint256)
```
Internal function to calculate total atom creation cost.

---

### `_getTripleCost`
```solidity
function _getTripleCost() internal view returns (uint256)
```
Internal function to calculate total triple creation cost.

---

## Usage Examples

### TypeScript (viem)

#### Calculating Atom ID Off-Chain

```typescript
import { createPublicClient, http, encodeAbiParameters } from 'viem';
import { base } from 'viem/chains';

// Setup
const publicClient = createPublicClient({
  chain: base,
  transport: http('YOUR_INTUITION_RPC')
});

const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';

const multiVaultABI = [
  {
    name: 'calculateAtomId',
    type: 'function',
    stateMutability: 'pure',
    inputs: [{ name: 'data', type: 'bytes' }],
    outputs: [{ name: 'id', type: 'bytes32' }]
  },
  {
    name: 'isAtom',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'atomId', type: 'bytes32' }],
    outputs: [{ type: 'bool' }]
  },
  {
    name: 'getAtom',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'atomId', type: 'bytes32' }],
    outputs: [{ name: 'data', type: 'bytes' }]
  }
] as const;

async function calculateAndVerifyAtom(atomData: `0x${string}`) {
  try {
    // Calculate atom ID
    const atomId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'calculateAtomId',
      args: [atomData]
    });
    console.log('Calculated Atom ID:', atomId);

    // Check if atom exists
    const exists = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'isAtom',
      args: [atomId]
    });
    console.log('Atom exists:', exists);

    if (exists) {
      // Retrieve atom data
      const data = await publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultABI,
        functionName: 'getAtom',
        args: [atomId]
      });
      console.log('Atom data:', data);
    }

    return atomId;
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

// Example: Calculate atom ID for an address
const addressData = encodeAbiParameters(
  [{ type: 'address' }],
  ['0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb']
);

calculateAndVerifyAtom(addressData);
```

#### Calculating Triple ID Off-Chain

```typescript
async function calculateTripleIds(
  subjectId: `0x${string}`,
  predicateId: `0x${string}`,
  objectId: `0x${string}`
) {
  try {
    const multiVaultABI = [
      {
        name: 'calculateTripleId',
        type: 'function',
        stateMutability: 'pure',
        inputs: [
          { name: 'subjectId', type: 'bytes32' },
          { name: 'predicateId', type: 'bytes32' },
          { name: 'objectId', type: 'bytes32' }
        ],
        outputs: [{ type: 'bytes32' }]
      },
      {
        name: 'calculateCounterTripleId',
        type: 'function',
        stateMutability: 'pure',
        inputs: [
          { name: 'subjectId', type: 'bytes32' },
          { name: 'predicateId', type: 'bytes32' },
          { name: 'objectId', type: 'bytes32' }
        ],
        outputs: [{ type: 'bytes32' }]
      },
      {
        name: 'isTriple',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'id', type: 'bytes32' }],
        outputs: [{ type: 'bool' }]
      },
      {
        name: 'isCounterTriple',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'termId', type: 'bytes32' }],
        outputs: [{ type: 'bool' }]
      }
    ] as const;

    // Calculate positive triple ID
    const tripleId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'calculateTripleId',
      args: [subjectId, predicateId, objectId]
    });
    console.log('Positive Triple ID:', tripleId);

    // Calculate counter triple ID
    const counterTripleId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'calculateCounterTripleId',
      args: [subjectId, predicateId, objectId]
    });
    console.log('Counter Triple ID:', counterTripleId);

    // Verify existence
    const tripleExists = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'isTriple',
      args: [tripleId]
    });

    const counterExists = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'isCounterTriple',
      args: [counterTripleId]
    });

    console.log('Positive triple exists:', tripleExists);
    console.log('Counter triple exists:', counterExists);

    return { tripleId, counterTripleId };
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}
```

#### Querying Configuration

```typescript
import { formatEther } from 'viem';

async function getProtocolConfiguration() {
  try {
    const multiVaultABI = [
      {
        name: 'getGeneralConfig',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{
          type: 'tuple',
          components: [
            { name: 'admin', type: 'address' },
            { name: 'protocolMultisig', type: 'address' },
            { name: 'feeDenominator', type: 'uint256' },
            { name: 'trustBonding', type: 'address' },
            { name: 'minDeposit', type: 'uint256' },
            { name: 'minShare', type: 'uint256' },
            { name: 'atomDataMaxLength', type: 'uint256' },
            { name: 'feeThreshold', type: 'uint256' }
          ]
        }]
      },
      {
        name: 'getAtomConfig',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{
          type: 'tuple',
          components: [
            { name: 'atomCreationProtocolFee', type: 'uint256' },
            { name: 'atomWalletDepositFee', type: 'uint256' }
          ]
        }]
      },
      {
        name: 'getTripleConfig',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{
          type: 'tuple',
          components: [
            { name: 'tripleCreationProtocolFee', type: 'uint256' },
            { name: 'atomDepositFractionForTriple', type: 'uint256' }
          ]
        }]
      },
      {
        name: 'getVaultFees',
        type: 'function',
        stateMutability: 'view',
        inputs: [],
        outputs: [{
          type: 'tuple',
          components: [
            { name: 'entryFee', type: 'uint256' },
            { name: 'exitFee', type: 'uint256' },
            { name: 'protocolFee', type: 'uint256' }
          ]
        }]
      }
    ] as const;

    // Get all configurations
    const generalConfig = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'getGeneralConfig'
    });

    const atomConfig = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'getAtomConfig'
    });

    const tripleConfig = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'getTripleConfig'
    });

    const vaultFees = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultABI,
      functionName: 'getVaultFees'
    });

    console.log('General Config:', {
      admin: generalConfig.admin,
      protocolMultisig: generalConfig.protocolMultisig,
      feeDenominator: generalConfig.feeDenominator.toString(),
      minDeposit: formatEther(generalConfig.minDeposit),
      minShare: formatEther(generalConfig.minShare),
      atomDataMaxLength: generalConfig.atomDataMaxLength.toString(),
      feeThreshold: generalConfig.feeThreshold.toString()
    });

    console.log('Atom Config:', {
      atomCreationProtocolFee: formatEther(atomConfig.atomCreationProtocolFee),
      atomWalletDepositFee: atomConfig.atomWalletDepositFee.toString()
    });

    console.log('Triple Config:', {
      tripleCreationProtocolFee: formatEther(tripleConfig.tripleCreationProtocolFee),
      atomDepositFractionForTriple: tripleConfig.atomDepositFractionForTriple.toString()
    });

    console.log('Vault Fees:', {
      entryFee: vaultFees.entryFee.toString(),
      exitFee: vaultFees.exitFee.toString(),
      protocolFee: vaultFees.protocolFee.toString()
    });

    return { generalConfig, atomConfig, tripleConfig, vaultFees };
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

getProtocolConfiguration();
```

### Python (web3.py)

```python
from web3 import Web3
from typing import Tuple
import json

# Setup
w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

# Load ABI
with open('MultiVault.json') as f:
    multivault_abi = json.load(f)['abi']

multivault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=multivault_abi)

def calculate_atom_id(atom_data: bytes) -> bytes:
    """Calculate atom ID from atom data"""
    try:
        atom_id = multivault.functions.calculateAtomId(atom_data).call()
        print(f'Atom ID: {atom_id.hex()}')

        # Check if atom exists
        exists = multivault.functions.isAtom(atom_id).call()
        print(f'Atom exists: {exists}')

        if exists:
            # Get atom data
            data = multivault.functions.getAtom(atom_id).call()
            print(f'Atom data: {data.hex()}')

        return atom_id
    except Exception as e:
        print(f'Error: {e}')
        raise

def get_triple_components(triple_id: bytes) -> Tuple[bytes, bytes, bytes]:
    """Get the subject, predicate, object for a triple"""
    try:
        # Check if triple exists
        is_triple = multivault.functions.isTriple(triple_id).call()
        if not is_triple:
            print('Triple does not exist')
            return (bytes(32), bytes(32), bytes(32))

        # Get triple components
        subject, predicate, obj = multivault.functions.getTriple(triple_id).call()

        print(f'Subject ID: {subject.hex()}')
        print(f'Predicate ID: {predicate.hex()}')
        print(f'Object ID: {obj.hex()}')

        return (subject, predicate, obj)
    except Exception as e:
        print(f'Error: {e}')
        raise

def get_creation_costs():
    """Get the costs to create atoms and triples"""
    try:
        atom_cost = multivault.functions.getAtomCost().call()
        triple_cost = multivault.functions.getTripleCost().call()

        print(f'Atom creation cost: {w3.from_wei(atom_cost, "ether")} TRUST')
        print(f'Triple creation cost: {w3.from_wei(triple_cost, "ether")} TRUST')

        return atom_cost, triple_cost
    except Exception as e:
        print(f'Error: {e}')
        raise

# Example usage
if __name__ == '__main__':
    # Calculate atom ID for an address
    address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'
    atom_data = w3.codec.encode(['address'], [address])
    atom_id = calculate_atom_id(atom_data)

    # Get creation costs
    get_creation_costs()
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMultiVaultCore.sol";

/**
 * @title AtomTripleQuery
 * @notice Example contract showing how to query atom and triple data
 */
contract AtomTripleQuery {
    IMultiVaultCore public immutable multiVaultCore;

    constructor(address _multiVaultCore) {
        multiVaultCore = IMultiVaultCore(_multiVaultCore);
    }

    /**
     * @notice Calculate atom ID and check if it exists
     * @param atomData The data to calculate the atom ID for
     * @return atomId The calculated atom ID
     * @return exists Whether the atom exists
     */
    function checkAtom(bytes calldata atomData)
        external
        view
        returns (bytes32 atomId, bool exists)
    {
        atomId = multiVaultCore.calculateAtomId(atomData);
        exists = multiVaultCore.isAtom(atomId);
    }

    /**
     * @notice Calculate triple IDs (positive and counter)
     * @param subjectId Subject atom ID
     * @param predicateId Predicate atom ID
     * @param objectId Object atom ID
     * @return tripleId Positive triple ID
     * @return counterTripleId Counter triple ID
     * @return tripleExists Whether the positive triple exists
     * @return counterExists Whether the counter triple exists
     */
    function checkTriple(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    )
        external
        view
        returns (
            bytes32 tripleId,
            bytes32 counterTripleId,
            bool tripleExists,
            bool counterExists
        )
    {
        tripleId = multiVaultCore.calculateTripleId(subjectId, predicateId, objectId);
        counterTripleId = multiVaultCore.calculateCounterTripleId(subjectId, predicateId, objectId);

        tripleExists = multiVaultCore.isTriple(tripleId);
        counterExists = multiVaultCore.isCounterTriple(counterTripleId);
    }

    /**
     * @notice Get the inverse triple ID
     * @param tripleId Triple ID (positive or counter)
     * @return inverse The inverse triple ID
     */
    function getInverse(bytes32 tripleId) external view returns (bytes32 inverse) {
        inverse = multiVaultCore.getInverseTripleId(tripleId);
    }

    /**
     * @notice Get creation costs
     * @return atomCost Cost to create an atom
     * @return tripleCost Cost to create a triple
     */
    function getCreationCosts()
        external
        view
        returns (uint256 atomCost, uint256 tripleCost)
    {
        atomCost = multiVaultCore.getAtomCost();
        tripleCost = multiVaultCore.getTripleCost();
    }

    /**
     * @notice Get all configuration structs
     * @return generalConfig General configuration
     * @return atomConfig Atom configuration
     * @return tripleConfig Triple configuration
     * @return walletConfig Wallet configuration
     * @return vaultFees Vault fees
     * @return bondingCurveConfig Bonding curve configuration
     */
    function getAllConfigs()
        external
        view
        returns (
            GeneralConfig memory generalConfig,
            AtomConfig memory atomConfig,
            TripleConfig memory tripleConfig,
            WalletConfig memory walletConfig,
            VaultFees memory vaultFees,
            BondingCurveConfig memory bondingCurveConfig
        )
    {
        generalConfig = multiVaultCore.getGeneralConfig();
        atomConfig = multiVaultCore.getAtomConfig();
        tripleConfig = multiVaultCore.getTripleConfig();
        walletConfig = multiVaultCore.getWalletConfig();
        vaultFees = multiVaultCore.getVaultFees();
        bondingCurveConfig = multiVaultCore.getBondingCurveConfig();
    }
}
```

## Integration Notes

### For SDK Builders

1. **Off-Chain ID Calculation**: Implement atom and triple ID calculation off-chain to avoid unnecessary RPC calls
2. **Configuration Caching**: Cache configuration values to reduce repeated queries
3. **Type Checking**: Always verify term type (atom/triple/counter) before operations
4. **Existence Validation**: Use non-reverting functions (`atom()`, `triple()`) to check existence before using reverting getters

### Common Patterns

#### Pre-Flight Checks Before Creating Terms

```typescript
// Check if atom already exists before creating
const atomId = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: multiVaultABI,
  functionName: 'calculateAtomId',
  args: [atomData]
});

const exists = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: multiVaultABI,
  functionName: 'isAtom',
  args: [atomId]
});

if (exists) {
  console.log('Atom already exists, skipping creation');
  return atomId;
}

// Proceed with creation (see MultiVault documentation for createAtoms)
```

#### Navigating Triple Relationships

```typescript
// Get triple components
const triple = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: multiVaultABI,
  functionName: 'getTriple',
  args: [tripleId]
});
const [subjectId, predicateId, objectId] = triple;

// Get the counter triple
const counterTripleId = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: multiVaultABI,
  functionName: 'getInverseTripleId',
  args: [tripleId]
});

// Or calculate it directly
const counterTripleId2 = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: multiVaultABI,
  functionName: 'getCounterIdFromTripleId',
  args: [tripleId]
});
```

### Edge Cases

1. **Empty Atom Data**: Atom data can be empty bytes, but this is not recommended as it reduces uniqueness
2. **Counter Triple Creation**: Counter triples are created automatically with positive triples - they cannot be created independently
3. **Configuration Immutability**: While configurations can be updated by admin, the bonding curve registry should not change after initialization
4. **Term ID Collisions**: Impossible due to cryptographic hashing, but always verify term existence before operations

## Gas Considerations

### Approximate Gas Costs

| Operation | Estimated Gas | Notes |
|-----------|--------------|-------|
| `calculateAtomId` | ~3,000 | Pure function (off-chain) |
| `calculateTripleId` | ~3,500 | Pure function (off-chain) |
| `isAtom` | ~3,000 | Simple storage read |
| `getAtom` | ~5,000 | Storage read + data length |
| `getTriple` | ~8,000 | Multiple storage reads |
| Configuration getters | ~3,000-5,000 | Struct packing affects cost |

### Optimization Tips

1. **Calculate IDs Off-Chain**: Use pure functions off-chain when possible to avoid gas costs
2. **Batch Queries**: Use multicall patterns to fetch multiple configurations in one transaction
3. **Cache Configuration**: Store frequently accessed config values in your application
4. **Use View Functions**: All getters are `view` functions - no gas cost when called externally

## Related Contracts

### Core Dependencies

- **[MultiVault](./MultiVault.md)**: Inherits MultiVaultCore and adds vault operation logic
- **[Trust](./Trust.md)**: ERC20 token referenced in configuration
- **[TrustBonding](../emissions/TrustBonding.md)**: Referenced in GeneralConfig

### Supporting Contracts

- **[BondingCurveRegistry](../curves/BondingCurveRegistry.md)**: Referenced in BondingCurveConfig
- **[AtomWalletFactory](../wallet/AtomWalletFactory.md)**: Referenced in WalletConfig
- **[AtomWarden](../wallet/AtomWarden.md)**: Referenced in WalletConfig

### Configuration Flow

```
MultiVaultCore (Base Layer)
    ↓ (inherited by)
MultiVault (Operation Layer)
    ↓ (uses configurations to)
├─ BondingCurveRegistry → Curve Pricing
├─ TrustBonding → Utilization & Rewards
├─ AtomWalletFactory → Wallet Deployment
└─ AtomWarden → Wallet Ownership
```

## See Also

### Concept Documentation
- [Atoms and Triples](../../concepts/atoms-and-triples.md) - Understanding the core data model
- [Multi-Vault Pattern](../../concepts/multi-vault-pattern.md) - Architecture deep dive

### Integration Guides
- [Creating Atoms](../../guides/creating-atoms.md) - Step-by-step atom creation
- [Creating Triples](../../guides/creating-triples.md) - Step-by-step triple creation

### API Reference
- [Data Structures](../../reference/data-structures.md) - All struct definitions
- [Events Reference](../../reference/events.md) - Complete events documentation

---

**Last Updated**: December 2025
**Version**: V2.0
