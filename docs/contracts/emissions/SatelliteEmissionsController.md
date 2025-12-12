# SatelliteEmissionsController

## Overview

The **SatelliteEmissionsController** is deployed on Intuition Mainnet (L3) and serves as the bridge between cross-chain emissions and user reward distribution. It receives TRUST tokens minted on Base L2, manages transfers to the TrustBonding contract for user claims, and handles the return of unclaimed emissions back to Base for burning. This contract is a critical component in the emissions lifecycle, ensuring efficient distribution while preventing inflation from unclaimed rewards.

### Purpose and Role in Protocol

- **Emission Receiver**: Receives TRUST tokens bridged from BaseEmissionsController on Base L2
- **Distribution Coordinator**: Transfers TRUST to TrustBonding contract when users claim rewards
- **Reclamation Manager**: Bridges unclaimed emissions back to Base for burning
- **Epoch Synchronization**: Maintains identical epoch schedule with Base chain for consistency
- **Access Gateway**: Controls who can trigger transfer and bridge operations

### Key Responsibilities

1. **Receive Bridged Emissions**: Accept TRUST tokens from BaseEmissionsController via MetaLayer
2. **Distribute Rewards**: Transfer TRUST to TrustBonding for user claims
3. **Track Unclaimed Emissions**: Monitor which epochs have unclaimed rewards
4. **Bridge Back Unclaimed**: Return unclaimed TRUST to Base for burning
5. **Prevent Double-Claiming**: Ensure each epoch's unclaimed emissions are only reclaimed once

## Contract Information

- **Location**: `src/protocol/emissions/SatelliteEmissionsController.sol`
- **Inherits**:
  - `ISatelliteEmissionsController` (interface)
  - `AccessControlUpgradeable` (role-based access control)
  - `ReentrancyGuardUpgradeable` (reentrancy protection)
  - `CoreEmissionsController` (emissions calculation logic)
  - `MetaERC20Dispatcher` (cross-chain bridging functionality)
- **Interface**: `ISatelliteEmissionsController` (`src/interfaces/ISatelliteEmissionsController.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Intuition Mainnet (L3)
- **Address**: `[To be deployed]`
- **Network**: Intuition Mainnet
- **TrustBonding**: Address of rewards distribution contract
- **Receives From**: BaseEmissionsController on Base L2

#### Intuition Testnet
- **Address**: `[To be deployed]`
- **Network**: Intuition Testnet
- **Testing**: Full emissions lifecycle testing

## Key Concepts

### Emissions Flow

```
Base L2:
  BaseEmissionsController
       ↓ [Mint & Bridge]
Intuition L3:
  SatelliteEmissionsController (receives)
       ↓ [Transfer on claim]
  TrustBonding (users claim)
       ↓ [Unclaimed after epoch+2]
  SatelliteEmissionsController
       ↓ [Bridge back]
Base L2:
  BaseEmissionsController (burns)
```

### Unclaimed Emissions Timeline

**Epoch N**:
- Emissions minted and bridged from Base
- Available in SatelliteEmissionsController

**Epoch N+1**:
- Users can claim epoch N rewards via TrustBonding
- Claims transfer TRUST from Satellite to claimer

**Epoch N+2**:
- Claiming window for epoch N closes
- Unclaimed emissions become reclaimable
- Can be bridged back to Base for burning

### Native Token vs ERC20

The SatelliteEmissionsController handles TRUST as **native tokens** on Intuition L3:
- Received as native tokens via MetaLayer bridge
- Stored in contract as native balance
- Transferred to users as native tokens
- Bridged back to Base as native tokens (converted to ERC20 on Base)

This differs from Base L2 where TRUST is an ERC20 token.

### Reclamation Protection

To prevent double-spending of unclaimed emissions:

```solidity
mapping(uint256 epoch => uint256 amount) internal _reclaimedEmissions;
```

Once an epoch's unclaimed emissions are withdrawn or bridged:
- Entry is set to non-zero value
- Future attempts to reclaim same epoch revert
- Ensures one-time-only reclamation

## State Variables

### Constants

```solidity
bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
```
Role for TrustBonding contract to transfer TRUST to users.

```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```
Role for operators who can bridge unclaimed emissions back to Base.

### Internal State

```solidity
address internal _TRUST_BONDING;
```
Address of the TrustBonding contract that distributes rewards to users.

```solidity
address internal _BASE_EMISSIONS_CONTROLLER;
```
Address of the BaseEmissionsController on Base L2 (receives bridged unclaimed emissions).

```solidity
mapping(uint256 epoch => uint256 amount) internal _reclaimedEmissions;
```
Tracks which epochs have had unclaimed emissions reclaimed. Non-zero value indicates epoch has been processed.

### Inherited State

From `CoreEmissionsController`:
```solidity
uint256 internal _START_TIMESTAMP;              // Emissions start time (matches Base)
uint256 internal _EPOCH_LENGTH;                 // Seconds per epoch (matches Base)
uint256 internal _EMISSIONS_PER_EPOCH;          // Base emissions (matches Base)
uint256 internal _EMISSIONS_REDUCTION_CLIFF;    // Epochs between reductions (matches Base)
uint256 internal _EMISSIONS_RETENTION_FACTOR;   // Reduction factor (matches Base)
```

**Critical**: All emission parameters must exactly match BaseEmissionsController for consistency.

From `MetaERC20Dispatcher`:
```solidity
address internal _metaERC20SpokeOrHub;          // MetaLayer contract
uint32 internal _recipientDomain;               // Base chain domain ID
uint256 internal _messageGasCost;               // Gas cost for messages
FinalityState internal _finalityState;          // Finality requirement
```

## Functions

### Read Functions

#### `getTrustBonding`
```solidity
function getTrustBonding() external view returns (address)
```
Returns the address of the TrustBonding contract.

**Returns**: TrustBonding contract address

**Use Cases**:
- Verify distribution configuration
- Check CONTROLLER_ROLE holder
- Frontend integration

---

#### `getBaseEmissionsController`
```solidity
function getBaseEmissionsController() external view returns (address)
```
Returns the address of the BaseEmissionsController on Base L2.

**Returns**: BaseEmissionsController address (on Base)

**Use Cases**:
- Verify bridging destination
- Monitor cross-chain configuration
- Debugging bridge transfers

---

#### `getReclaimedEmissions`
```solidity
function getReclaimedEmissions(uint256 epoch) external view returns (uint256)
```
Returns the amount of unclaimed emissions reclaimed for a specific epoch.

**Parameters**:
- `epoch`: Epoch number to query

**Returns**: Amount reclaimed (0 if not yet reclaimed)

**Use Cases**:
- Check if epoch already reclaimed
- Prevent duplicate reclamation attempts
- Audit reclamation history

---

#### Inherited Read Functions

From `CoreEmissionsController`:
- `getCurrentEpoch()`: Current epoch number
- `getEpochLength()`: Epoch duration in seconds
- `getEmissionsAtEpoch(epoch)`: Emissions amount for epoch
- `getEpochTimestampStart(epoch)`: Epoch start timestamp
- `getEpochTimestampEnd(epoch)`: Epoch end timestamp

**Note**: These must return identical values to BaseEmissionsController on Base.

---

### Controller Functions

#### `transfer`
```solidity
function transfer(address recipient, uint256 amount) external nonReentrant onlyRole(CONTROLLER_ROLE)
```
Transfers native TRUST tokens to a recipient. Called by TrustBonding when users claim rewards.

**Parameters**:
- `recipient`: Address to receive TRUST (typically the claimer)
- `amount`: Amount of TRUST to transfer (in wei)

**Access**: Requires `CONTROLLER_ROLE` (granted to TrustBonding)

**Emits**: `NativeTokenTransferred(recipient, amount)`

**Reverts**:
- `SatelliteEmissionsController_InvalidAddress` - Recipient is zero address
- `SatelliteEmissionsController_InvalidAmount` - Amount is zero
- `SatelliteEmissionsController_InsufficientBalance` - Contract balance too low

**Flow**:
1. User calls `TrustBonding.claimRewards(recipient)`
2. TrustBonding validates claim eligibility
3. TrustBonding calls `SatelliteEmissionsController.transfer(recipient, amount)`
4. Native TRUST transferred to recipient

**Example**:
```solidity
// In TrustBonding contract
function claimRewards(address recipient) external {
    uint256 claimable = calculateClaimable(msg.sender);
    ISatelliteEmissionsController(satelliteController).transfer(recipient, claimable);
}
```

---

### Admin Functions

#### `setTrustBonding`
```solidity
function setTrustBonding(address newTrustBonding) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the TrustBonding contract address.

**Parameters**:
- `newTrustBonding`: New TrustBonding contract address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `TrustBondingUpdated(newTrustBonding)`

**Reverts**: `SatelliteEmissionsController_InvalidAddress` if address is zero

**Security Note**: TrustBonding receives CONTROLLER_ROLE to call `transfer()`

---

#### `setBaseEmissionsController`
```solidity
function setBaseEmissionsController(address newBaseEmissionsController) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the BaseEmissionsController address on Base L2.

**Parameters**:
- `newBaseEmissionsController`: New base controller address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `BaseEmissionsControllerUpdated(newBaseEmissionsController)`

**Reverts**: `SatelliteEmissionsController_InvalidAddress` if address is zero

---

#### `setMessageGasCost`
```solidity
function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the gas cost for cross-chain messages.

**Parameters**:
- `newGasCost`: New gas cost in wei

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Inherited from**: `MetaERC20Dispatcher`

---

#### `setFinalityState`
```solidity
function setFinalityState(FinalityState newFinalityState) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates finality requirement for bridging back to Base.

**Parameters**:
- `newFinalityState`: `FINALIZED` or `INSTANT`

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `setMetaERC20SpokeOrHub`
```solidity
function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the MetaLayer contract address for bridging.

**Parameters**:
- `newMetaERC20SpokeOrHub`: New MetaLayer address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `setRecipientDomain`
```solidity
function setRecipientDomain(uint32 newRecipientDomain) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the Base chain domain ID for bridging.

**Parameters**:
- `newRecipientDomain`: New domain ID

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `withdrawUnclaimedEmissions`
```solidity
function withdrawUnclaimedEmissions(uint256 epoch, address recipient) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE)
```
Withdraws unclaimed emissions for a specific epoch directly to a recipient (instead of bridging).

**Parameters**:
- `epoch`: Epoch to withdraw unclaimed emissions for
- `recipient`: Address to receive unclaimed TRUST

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `UnclaimedEmissionsWithdrawn(epoch, recipient, amount)`

**Reverts**:
- `SatelliteEmissionsController_TrustBondingNotSet` - TrustBonding not configured
- `SatelliteEmissionsController_InvalidWithdrawAmount` - No unclaimed emissions for epoch
- `SatelliteEmissionsController_InvalidAddress` - Recipient is zero address
- `SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions` - Epoch already reclaimed

**Use Cases**:
- Emergency recovery of unclaimed emissions
- Direct distribution instead of burning
- Testing and debugging

**Timeline**:
- Only callable for epochs ≥ 2 epochs old
- Marks epoch as reclaimed (cannot bridge later)

---

#### `bridgeUnclaimedEmissions`
```solidity
function bridgeUnclaimedEmissions(uint256 epoch) external payable onlyRole(OPERATOR_ROLE)
```
Bridges unclaimed emissions for a specific epoch back to BaseEmissionsController for burning.

**Parameters**:
- `epoch`: Epoch to bridge unclaimed emissions for

**Access**: Requires `OPERATOR_ROLE`

**Payable**: Requires ETH for cross-chain gas fees

**Emits**: `UnclaimedEmissionsBridged(epoch, amount)`

**Reverts**:
- `SatelliteEmissionsController_TrustBondingNotSet` - TrustBonding not configured
- `SatelliteEmissionsController_InvalidBridgeAmount` - No unclaimed emissions
- `SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions` - Already bridged
- `SatelliteEmissionsController_InsufficientGasPayment` - Insufficient ETH for gas

**Flow**:
1. Operator calls function with ETH for gas
2. Queries TrustBonding for unclaimed amount
3. Validates epoch is old enough (≥ 2 epochs old)
4. Marks epoch as reclaimed
5. Bridges native TRUST to BaseEmissionsController
6. Refunds excess ETH to caller

**Example**:
```typescript
// Bridge epoch 100 unclaimed emissions
await satelliteController.write.bridgeUnclaimedEmissions([100n], {
  value: parseEther('0.01'), // Gas payment
});
```

---

## Events

### `TrustBondingUpdated`
```solidity
event TrustBondingUpdated(address indexed newTrustBonding)
```
Emitted when TrustBonding contract address is updated.

**Parameters**:
- `newTrustBonding`: New TrustBonding address

---

### `BaseEmissionsControllerUpdated`
```solidity
event BaseEmissionsControllerUpdated(address indexed newBaseEmissionsController)
```
Emitted when BaseEmissionsController address is updated.

**Parameters**:
- `newBaseEmissionsController`: New base controller address

---

### `NativeTokenTransferred`
```solidity
event NativeTokenTransferred(address indexed recipient, uint256 amount)
```
Emitted when native TRUST is transferred to a user.

**Parameters**:
- `recipient`: Address receiving TRUST
- `amount`: Amount transferred

**Use Cases**:
- Track reward claims
- Monitor distribution activity
- Verify user received rewards

---

### `UnclaimedEmissionsBridged`
```solidity
event UnclaimedEmissionsBridged(uint256 indexed epoch, uint256 amount)
```
Emitted when unclaimed emissions are bridged back to Base.

**Parameters**:
- `epoch`: Epoch for which emissions were bridged
- `amount`: Amount bridged

**Use Cases**:
- Track deflationary burns
- Monitor unclaimed rate
- Calculate net inflation

---

### `UnclaimedEmissionsWithdrawn`
```solidity
event UnclaimedEmissionsWithdrawn(uint256 indexed epoch, address indexed recipient, uint256 amount)
```
Emitted when unclaimed emissions are withdrawn directly instead of bridged.

**Parameters**:
- `epoch`: Epoch for which emissions were withdrawn
- `recipient`: Address receiving unclaimed emissions
- `amount`: Amount withdrawn

**Use Cases**:
- Track emergency withdrawals
- Monitor admin actions
- Audit reclamation events

---

## Errors

### `SatelliteEmissionsController_InvalidAddress`
Thrown when a zero address is provided where valid address required.

**Recovery**: Provide non-zero address

---

### `SatelliteEmissionsController_InvalidAmount`
Thrown when transfer amount is zero.

**Recovery**: Provide non-zero transfer amount

---

### `SatelliteEmissionsController_InvalidBridgeAmount`
Thrown when attempting to bridge zero unclaimed emissions.

**Triggers**: Calling `bridgeUnclaimedEmissions` for epoch with no unclaimed rewards

**Recovery**: Check `TrustBonding.getUnclaimedRewardsForEpoch()` first

---

### `SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions`
Thrown when attempting to reclaim an epoch that's already been reclaimed.

**Triggers**:
- Calling `bridgeUnclaimedEmissions` twice for same epoch
- Calling `withdrawUnclaimedEmissions` after `bridgeUnclaimedEmissions`

**Recovery**: Check `getReclaimedEmissions(epoch)` before operations

---

### `SatelliteEmissionsController_InsufficientBalance`
Thrown when contract doesn't have enough native TRUST for transfer.

**Triggers**: Emissions not yet received from Base, or already distributed

**Recovery**: Wait for bridge from Base, or check emissions schedule

---

### `SatelliteEmissionsController_InsufficientGasPayment`
Thrown when insufficient ETH provided for bridge operation.

**Triggers**: `msg.value` < calculated gas requirement

**Recovery**: Increase ETH sent with transaction

---

### `SatelliteEmissionsController_InvalidWithdrawAmount`
Thrown when no unclaimed emissions available for withdrawal.

**Triggers**: Epoch has no unclaimed rewards or not old enough

**Recovery**: Verify epoch has unclaimed emissions via TrustBonding

---

### `SatelliteEmissionsController_TrustBondingNotSet`
Thrown when TrustBonding address not configured.

**Triggers**: Operations requiring TrustBonding before `setTrustBonding` called

**Recovery**: Admin must call `setTrustBonding` first

---

## Access Control

### Roles

#### `DEFAULT_ADMIN_ROLE` (`bytes32(0)`)

**Permissions**:
- Set TrustBonding address
- Set BaseEmissionsController address
- Configure MetaLayer parameters
- Withdraw unclaimed emissions
- Grant/revoke roles

**Intended Holder**: Protocol multisig or governance

---

#### `CONTROLLER_ROLE` (`keccak256("CONTROLLER_ROLE")`)

**Permissions**:
- Transfer native TRUST to users

**Intended Holder**: TrustBonding contract

**Security**: Should only be granted to TrustBonding

---

#### `OPERATOR_ROLE` (`keccak256("OPERATOR_ROLE")`)

**Permissions**:
- Bridge unclaimed emissions back to Base

**Intended Holder**: Automated operator bot or trusted EOA

**Security**: Can only reclaim unclaimed emissions, cannot steal user funds

---

### Permission Matrix

| Function | DEFAULT_ADMIN | CONTROLLER | OPERATOR | Public |
|----------|--------------|------------|----------|--------|
| `transfer` | ❌ | ✅ | ❌ | ❌ |
| `bridgeUnclaimedEmissions` | ❌ | ❌ | ✅ | ❌ |
| `withdrawUnclaimedEmissions` | ✅ | ❌ | ❌ | ❌ |
| `setTrustBonding` | ✅ | ❌ | ❌ | ❌ |
| `setBaseEmissionsController` | ✅ | ❌ | ❌ | ❌ |
| Read functions | ✅ | ✅ | ✅ | ✅ |

---

## Usage Examples

### TypeScript (VIEM)

```typescript
import { createPublicClient, createWalletClient, http, parseEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { intuitionMainnet } from './chains'; // Custom chain config

const SATELLITE_CONTROLLER_ADDRESS = '0x...';
const TRUST_BONDING_ADDRESS = '0x...';

const SATELLITE_ABI = [
  {
    name: 'getReclaimedEmissions',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'bridgeUnclaimedEmissions',
    type: 'function',
    stateMutability: 'payable',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'transfer',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'recipient', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [],
  },
] as const;

const TRUST_BONDING_ABI = [
  {
    name: 'getUnclaimedRewardsForEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'currentEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const;

const publicClient = createPublicClient({
  chain: intuitionMainnet,
  transport: http(),
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: intuitionMainnet,
  transport: http(),
});

// Example 1: Check unclaimed emissions for epoch
async function checkUnclaimedEmissions(epoch: bigint) {
  const unclaimed = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'getUnclaimedRewardsForEpoch',
    args: [epoch],
  });

  const alreadyReclaimed = await publicClient.readContract({
    address: SATELLITE_CONTROLLER_ADDRESS,
    abi: SATELLITE_ABI,
    functionName: 'getReclaimedEmissions',
    args: [epoch],
  });

  console.log(`Epoch ${epoch}:`);
  console.log(`  Unclaimed: ${unclaimed} wei`);
  console.log(`  Already Reclaimed: ${alreadyReclaimed > 0n}`);

  return { unclaimed, alreadyReclaimed: alreadyReclaimed > 0n };
}

// Example 2: Bridge unclaimed emissions (requires OPERATOR_ROLE)
async function bridgeUnclaimedForEpoch(epoch: bigint, gasPayment: bigint) {
  // First check if eligible
  const currentEpoch = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'currentEpoch',
  });

  if (epoch > currentEpoch - 2n) {
    console.log('Epoch not old enough to reclaim (must be ≥ 2 epochs old)');
    return;
  }

  const { unclaimed, alreadyReclaimed } = await checkUnclaimedEmissions(epoch);

  if (alreadyReclaimed) {
    console.log('Epoch already reclaimed');
    return;
  }

  if (unclaimed === 0n) {
    console.log('No unclaimed emissions for this epoch');
    return;
  }

  // Bridge the unclaimed emissions
  const { request } = await publicClient.simulateContract({
    account,
    address: SATELLITE_CONTROLLER_ADDRESS,
    abi: SATELLITE_ABI,
    functionName: 'bridgeUnclaimedEmissions',
    args: [epoch],
    value: gasPayment,
  });

  const hash = await walletClient.writeContract(request);
  console.log(`Bridging unclaimed emissions: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Bridged ${unclaimed} wei from epoch ${epoch}`);
}

// Example 3: Monitor bridging events
async function monitorBridging() {
  const unwatch = publicClient.watchContractEvent({
    address: SATELLITE_CONTROLLER_ADDRESS,
    abi: SATELLITE_ABI,
    eventName: 'UnclaimedEmissionsBridged',
    onLogs: (logs) => {
      logs.forEach((log) => {
        console.log(`\nUnclaimed Emissions Bridged:`);
        console.log(`  Epoch: ${log.args.epoch}`);
        console.log(`  Amount: ${log.args.amount} wei`);
        console.log(`  Block: ${log.blockNumber}`);
      });
    },
  });

  return unwatch;
}

// Example 4: Automated bridging operator
async function runBridgingOperator() {
  console.log('Starting unclaimed emissions bridging operator...');

  while (true) {
    try {
      const currentEpoch = await publicClient.readContract({
        address: TRUST_BONDING_ADDRESS,
        abi: TRUST_BONDING_ABI,
        functionName: 'currentEpoch',
      });

      // Check epochs that are old enough (current - 2)
      if (currentEpoch >= 2n) {
        const epochToCheck = currentEpoch - 2n;

        const { unclaimed, alreadyReclaimed } =
          await checkUnclaimedEmissions(epochToCheck);

        if (!alreadyReclaimed && unclaimed > 0n) {
          console.log(`\nFound unclaimed: ${unclaimed} wei in epoch ${epochToCheck}`);
          await bridgeUnclaimedForEpoch(epochToCheck, parseEther('0.01'));
        }
      }

      // Wait 1 hour before next check
      await new Promise(resolve => setTimeout(resolve, 3600000));
    } catch (error) {
      console.error('Operator error:', error);
      // Wait 5 minutes before retry
      await new Promise(resolve => setTimeout(resolve, 300000));
    }
  }
}
```

---

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
import json
import time

# Connect to Intuition Mainnet
w3 = Web3(Web3.HTTPProvider('https://rpc.intuit.network'))

SATELLITE_CONTROLLER_ADDRESS = '0x...'
TRUST_BONDING_ADDRESS = '0x...'

SATELLITE_ABI = json.loads('''[
  {
    "name": "getReclaimedEmissions",
    "type": "function",
    "stateMutability": "view",
    "inputs": [{"name": "epoch", "type": "uint256"}],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "bridgeUnclaimedEmissions",
    "type": "function",
    "stateMutability": "payable",
    "inputs": [{"name": "epoch", "type": "uint256"}],
    "outputs": []
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "name": "epoch", "type": "uint256"},
      {"indexed": false, "name": "amount", "type": "uint256"}
    ],
    "name": "UnclaimedEmissionsBridged",
    "type": "event"
  }
]''')

TRUST_BONDING_ABI = json.loads('''[
  {
    "name": "getUnclaimedRewardsForEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [{"name": "epoch", "type": "uint256"}],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "currentEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [{"type": "uint256"}]
  }
]''')

satellite = w3.eth.contract(address=SATELLITE_CONTROLLER_ADDRESS, abi=SATELLITE_ABI)
trust_bonding = w3.eth.contract(address=TRUST_BONDING_ADDRESS, abi=TRUST_BONDING_ABI)

# Example 1: Check unclaimed emissions
def check_unclaimed(epoch):
    unclaimed = trust_bonding.functions.getUnclaimedRewardsForEpoch(epoch).call()
    reclaimed = satellite.functions.getReclaimedEmissions(epoch).call()

    print(f"\nEpoch {epoch}:")
    print(f"  Unclaimed: {w3.from_wei(unclaimed, 'ether')} TRUST")
    print(f"  Already Reclaimed: {reclaimed > 0}")

    return unclaimed, reclaimed > 0

# Example 2: Bridge unclaimed emissions
def bridge_unclaimed(epoch, private_key):
    account = Account.from_key(private_key)
    current_epoch = trust_bonding.functions.currentEpoch().call()

    # Validate epoch is old enough
    if epoch > current_epoch - 2:
        print(f"Epoch {epoch} not old enough (current: {current_epoch})")
        return None

    unclaimed, already_reclaimed = check_unclaimed(epoch)

    if already_reclaimed:
        print("Already reclaimed")
        return None

    if unclaimed == 0:
        print("No unclaimed emissions")
        return None

    # Build transaction
    gas_payment = w3.to_wei(0.01, 'ether')
    txn = satellite.functions.bridgeUnclaimedEmissions(epoch).build_transaction({
        'from': account.address,
        'value': gas_payment,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
    })

    # Sign and send
    signed = account.sign_transaction(txn)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

    print(f"\nBridging transaction: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"Bridged {w3.from_wei(unclaimed, 'ether')} TRUST from epoch {epoch}")

    return receipt

# Example 3: Monitor bridging events
def listen_for_bridging():
    event_filter = satellite.events.UnclaimedEmissionsBridged.create_filter(
        fromBlock='latest'
    )

    print("Listening for unclaimed emissions bridging...")

    while True:
        for event in event_filter.get_new_entries():
            print(f"\n{'='*60}")
            print(f"Unclaimed Emissions Bridged!")
            print(f"  Epoch: {event['args']['epoch']}")
            print(f"  Amount: {w3.from_wei(event['args']['amount'], 'ether')} TRUST")
            print(f"  Block: {event['blockNumber']}")
            print(f"  Tx: {event['transactionHash'].hex()}")
            print(f"{'='*60}")

        time.sleep(10)

# Example 4: Automated operator
def run_bridging_operator(private_key, check_interval=3600):
    print("Starting automated bridging operator...")
    print(f"Check interval: {check_interval} seconds")

    while True:
        try:
            current_epoch = trust_bonding.functions.currentEpoch().call()
            print(f"\nCurrent epoch: {current_epoch}")

            if current_epoch >= 2:
                # Check epoch that's 2 behind current
                epoch_to_check = current_epoch - 2

                unclaimed, already_reclaimed = check_unclaimed(epoch_to_check)

                if not already_reclaimed and unclaimed > 0:
                    print(f"\n🔔 Found unclaimed emissions in epoch {epoch_to_check}")
                    bridge_unclaimed(epoch_to_check, private_key)
                else:
                    print(f"Epoch {epoch_to_check}: No action needed")

            print(f"\nWaiting {check_interval} seconds...")
            time.sleep(check_interval)

        except Exception as e:
            print(f"Error in operator: {e}")
            print("Retrying in 5 minutes...")
            time.sleep(300)

# Run examples
if __name__ == "__main__":
    # Check current epoch's unclaimed
    current = trust_bonding.functions.currentEpoch().call()
    if current >= 2:
        check_unclaimed(current - 2)
```

---

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/**
 * @title UnclaimedBridgeOperator
 * @notice Automated operator for bridging unclaimed emissions back to Base
 */
contract UnclaimedBridgeOperator {
    ISatelliteEmissionsController public immutable satelliteController;
    ITrustBonding public immutable trustBonding;
    address public owner;
    uint256 public lastBridgedEpoch;
    uint256 public totalBridged;

    event UnclaimedBridged(uint256 indexed epoch, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OnlyOwner();
    error EpochNotOldEnough();
    error AlreadyReclaimed();
    error NoUnclaimedEmissions();

    constructor(address _satelliteController, address _trustBonding) {
        satelliteController = ISatelliteEmissionsController(_satelliteController);
        trustBonding = ITrustBonding(_trustBonding);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Bridge unclaimed emissions for a specific epoch
     */
    function bridgeEpoch(uint256 epoch) external payable onlyOwner {
        uint256 currentEpoch = trustBonding.currentEpoch();

        // Epoch must be at least 2 epochs old
        if (epoch > currentEpoch - 2) {
            revert EpochNotOldEnough();
        }

        // Check not already reclaimed
        uint256 reclaimed = satelliteController.getReclaimedEmissions(epoch);
        if (reclaimed > 0) {
            revert AlreadyReclaimed();
        }

        // Check there are unclaimed emissions
        uint256 unclaimed = trustBonding.getUnclaimedRewardsForEpoch(epoch);
        if (unclaimed == 0) {
            revert NoUnclaimedEmissions();
        }

        // Bridge with provided gas payment
        satelliteController.bridgeUnclaimedEmissions{value: msg.value}(epoch);

        lastBridgedEpoch = epoch;
        totalBridged += unclaimed;

        emit UnclaimedBridged(epoch, unclaimed);
    }

    /**
     * @notice Get info about reclaimable epoch
     */
    function getReclaimableInfo()
        external
        view
        returns (
            uint256 reclaimableEpoch,
            uint256 unclaimedAmount,
            bool alreadyReclaimed
        )
    {
        uint256 currentEpoch = trustBonding.currentEpoch();

        if (currentEpoch < 2) {
            return (0, 0, false);
        }

        reclaimableEpoch = currentEpoch - 2;
        unclaimedAmount = trustBonding.getUnclaimedRewardsForEpoch(reclaimableEpoch);
        uint256 reclaimed = satelliteController.getReclaimedEmissions(reclaimableEpoch);
        alreadyReclaimed = reclaimed > 0;
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Withdraw ETH
     */
    function withdraw(uint256 amount) external onlyOwner {
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}

/**
 * @title SatelliteMonitor
 * @notice View contract for monitoring satellite emissions state
 */
contract SatelliteMonitor {
    ISatelliteEmissionsController public immutable satelliteController;
    ITrustBonding public immutable trustBonding;

    struct SatelliteSnapshot {
        uint256 currentEpoch;
        uint256 contractBalance;
        address trustBondingAddress;
        address baseControllerAddress;
        uint256 reclaimableEpoch;
        uint256 unclaimedForReclaimable;
        bool reclaimableAlreadyBridged;
    }

    constructor(address _satelliteController, address _trustBonding) {
        satelliteController = ISatelliteEmissionsController(_satelliteController);
        trustBonding = ITrustBonding(_trustBonding);
    }

    function getSnapshot() external view returns (SatelliteSnapshot memory) {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 reclaimableEpoch = currentEpoch >= 2 ? currentEpoch - 2 : 0;

        return SatelliteSnapshot({
            currentEpoch: currentEpoch,
            contractBalance: address(satelliteController).balance,
            trustBondingAddress: satelliteController.getTrustBonding(),
            baseControllerAddress: satelliteController.getBaseEmissionsController(),
            reclaimableEpoch: reclaimableEpoch,
            unclaimedForReclaimable: reclaimableEpoch > 0
                ? trustBonding.getUnclaimedRewardsForEpoch(reclaimableEpoch)
                : 0,
            reclaimableAlreadyBridged: reclaimableEpoch > 0
                ? satelliteController.getReclaimedEmissions(reclaimableEpoch) > 0
                : false
        });
    }
}
```

---

## Integration Notes

### TrustBonding Integration

The SatelliteEmissionsController must be tightly coupled with TrustBonding:

1. **Role Grant**: TrustBonding receives `CONTROLLER_ROLE`
2. **Transfer Flow**: TrustBonding calls `transfer()` on user claims
3. **Unclaimed Query**: Satellite queries TrustBonding for unclaimed amounts
4. **Epoch Sync**: Both use identical epoch calculations

### Cross-Chain Coordination

**Epoch Alignment**:
- SatelliteEmissionsController and BaseEmissionsController must have identical:
  - Start timestamp
  - Epoch length
  - Reduction schedule
  - Emissions amounts

**Bridge Timing**:
- Base mints and bridges at epoch start
- Satellite receives within minutes (depending on bridge speed)
- Users claim during epoch N+1
- Unclaimed bridged back at epoch N+2 or later

### Common Patterns

**Safe Bridging**:
```typescript
// Always check before bridging
const unclaimed = await trustBonding.read.getUnclaimedRewardsForEpoch([epoch]);
const reclaimed = await satellite.read.getReclaimedEmissions([epoch]);

if (unclaimed > 0n && reclaimed === 0n) {
  await satellite.write.bridgeUnclaimedEmissions([epoch], {
    value: parseEther('0.01')
  });
}
```

**Monitoring Balance**:
```typescript
// Ensure satellite has enough TRUST
const balance = await publicClient.getBalance({
  address: SATELLITE_CONTROLLER_ADDRESS
});

const currentEpoch = await trustBonding.read.currentEpoch();
const expectedEmissions = await coreController.read.getEmissionsAtEpoch([currentEpoch]);

if (balance < expectedEmissions) {
  console.warn('Satellite balance lower than expected emissions!');
}
```

---

## Gas Considerations

### Approximate Costs

| Operation | Estimated Gas | Cost @ 0.1 gwei |
|-----------|--------------|-----------------|
| `transfer` | ~50,000 | ~0.000005 ETH |
| `bridgeUnclaimedEmissions` | ~300,000 | ~0.00003 ETH |
| `withdrawUnclaimedEmissions` | ~80,000 | ~0.000008 ETH |
| `setTrustBonding` | ~50,000 | ~0.000005 ETH |
| Read functions | ~30,000 | Free (view) |

### Optimization Tips

1. **Batch Operations**: Consider batching multiple epoch bridging if protocol allows
2. **Gas Price Timing**: Bridge during low activity periods on L3
3. **Event-Driven**: Use events instead of polling for state changes
4. **Multicall**: Batch read operations for efficiency

---

## Related Contracts

- **[BaseEmissionsController](./BaseEmissionsController.md)**: Mints TRUST on Base L2
- **[TrustBonding](./TrustBonding.md)**: Distributes rewards to users
- **[CoreEmissionsController](./CoreEmissionsController.md)**: Shared emissions logic

---

## See Also

- [Emissions System Overview](/docs/concepts/emissions-system.md)
- [Unclaimed Emissions](/docs/concepts/unclaimed-emissions.md)
- [Cross-Chain Bridging](/docs/concepts/cross-chain.md)
- [Operating Emissions](/docs/guides/emissions-operator.md)
