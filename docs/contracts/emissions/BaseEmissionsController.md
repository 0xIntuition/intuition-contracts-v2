# BaseEmissionsController

## Overview

The **BaseEmissionsController** is the central emissions authority for the Intuition Protocol V2, deployed on the Base L2 blockchain. It serves as the exclusive minter of TRUST tokens and orchestrates the cross-chain distribution of inflationary rewards through an epoch-based emissions schedule. The contract implements a sophisticated emissions model with periodic reduction cliffs and cross-chain bridging capabilities via MetaLayer infrastructure.

### Purpose and Role in Protocol

- **Emissions Authority**: Sole authorized contract to mint new TRUST tokens via Trust contract integration
- **Cross-Chain Orchestrator**: Bridges minted TRUST tokens to satellite chains (Intuition Mainnet) for reward distribution
- **Emissions Scheduler**: Implements time-based epoch system with periodic reduction cliffs
- **Gas Management**: Handles native token (ETH) payments for cross-chain messaging fees
- **Supply Controller**: Enforces minting limits per epoch and tracks total minted supply

### Key Responsibilities

1. **Token Minting**: Mints TRUST tokens according to emissions schedule
2. **Cross-Chain Bridging**: Transfers minted tokens to SatelliteEmissionsController via MetaLayer
3. **Epoch Management**: Calculates emissions amounts based on current epoch and reduction schedule
4. **Burn Management**: Burns unclaimed emissions that are bridged back from satellite chains
5. **Access Control**: Enforces role-based permissions for minting and administrative operations

## Contract Information

- **Location**: `src/protocol/emissions/BaseEmissionsController.sol`
- **Inherits**:
  - `IBaseEmissionsController` (interface)
  - `AccessControlUpgradeable` (role-based access control)
  - `ReentrancyGuardUpgradeable` (reentrancy protection)
  - `CoreEmissionsController` (emissions calculation logic)
  - `MetaERC20Dispatcher` (cross-chain bridging functionality)
- **Interface**: `IBaseEmissionsController` (`src/interfaces/IBaseEmissionsController.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Base Mainnet
- **Address**: `[To be deployed]`
- **Network**: Base (Chain ID: 8453)
- **Trust Token**: [`0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3`](https://basescan.org/address/0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3)

#### Base Sepolia (Testnet)
- **Address**: `[To be deployed]`
- **Network**: Base Sepolia (Chain ID: 84532)
- **Trust Token**: [`0xA54b4E6e356b963Ee00d1C947f478d9194a1a210`](https://sepolia.basescan.org/address/0xA54b4E6e356b963Ee00d1C947f478d9194a1a210)

## Key Concepts

### Emissions Schedule

The BaseEmissionsController implements a declining emissions schedule with periodic "cliffs":

```solidity
struct CoreEmissionsControllerInit {
    uint256 startTimestamp;                    // When emissions begin
    uint256 emissionsLength;                   // Epoch duration (e.g., 7 days)
    uint256 emissionsPerEpoch;                 // Initial emissions per epoch
    uint256 emissionsReductionCliff;           // Epochs between reductions (e.g., 52)
    uint256 emissionsReductionBasisPoints;     // Reduction percentage (e.g., 500 = 5%)
}
```

**Emission Reduction Formula**:
- Every `emissionsReductionCliff` epochs, emissions are reduced by `emissionsReductionBasisPoints`
- Reduction is compound: `newEmissions = previousEmissions * (10000 - reductionBasisPoints) / 10000`
- Maximum reduction per cliff: 10% (1000 basis points)

**Example**:
- Initial emissions: 1,000,000 TRUST per epoch
- Reduction cliff: 52 epochs (1 year if epochs are weekly)
- Reduction: 5% (500 basis points)
- After 1 year: 950,000 TRUST per epoch
- After 2 years: 902,500 TRUST per epoch

### Cross-Chain Architecture

The emissions system uses a two-chain architecture:

**Base Chain (L2)**:
- BaseEmissionsController mints TRUST tokens
- Bridges tokens to satellite chain via MetaLayer

**Intuition Mainnet (L3)**:
- SatelliteEmissionsController receives bridged TRUST
- TrustBonding distributes rewards to users
- Unclaimed rewards are bridged back to Base for burning

### MetaLayer Integration

The contract uses MetaLayer's ERC20 bridging infrastructure:

```solidity
struct MetaERC20DispatchInit {
    address hubOrSpoke;        // MetaLayer hub/spoke address
    uint32 recipientDomain;    // Destination chain domain ID
    uint256 gasLimit;          // Gas limit for cross-chain message
    FinalityState finalityState; // Finality requirement (FINALIZED/INSTANT)
}
```

### Epoch System

**Epoch Calculation**:
```solidity
currentEpoch = (block.timestamp - startTimestamp) / epochLength
```

**Properties**:
- Epochs are sequential integers starting from 0
- Epoch length is immutable after initialization
- Each epoch can only be minted once
- Emissions amount is deterministic based on epoch number

## State Variables

### Constants

```solidity
bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
```
Role identifier for addresses authorized to mint and bridge tokens.

### Internal State

```solidity
address internal _TRUST_TOKEN;
```
Address of the Trust ERC20 token contract that receives mint calls.

```solidity
address internal _SATELLITE_EMISSIONS_CONTROLLER;
```
Address on the satellite chain that receives bridged TRUST tokens.

```solidity
uint256 internal _totalMintedAmount;
```
Cumulative total of all TRUST tokens minted by this controller across all epochs.

```solidity
mapping(uint256 epoch => uint256 amount) internal _epochToMintedAmount;
```
Tracks the amount minted for each epoch. Once an epoch has a non-zero value, it cannot be minted again.

### Inherited State

From `CoreEmissionsController`:
```solidity
uint256 internal _START_TIMESTAMP;              // Emissions start time
uint256 internal _EPOCH_LENGTH;                 // Seconds per epoch
uint256 internal _EMISSIONS_PER_EPOCH;          // Base emissions amount
uint256 internal _EMISSIONS_REDUCTION_CLIFF;    // Epochs between reductions
uint256 internal _EMISSIONS_RETENTION_FACTOR;   // (10000 - reductionBasisPoints)
```

From `MetaERC20Dispatcher`:
```solidity
address internal _metaERC20SpokeOrHub;          // MetaLayer contract
uint32 internal _recipientDomain;               // Destination chain ID
uint256 internal _messageGasCost;               // Gas cost for messages
FinalityState internal _finalityState;          // Finality requirement
```

## Functions

### Read Functions

#### `getTrustToken`
```solidity
function getTrustToken() external view returns (address)
```
Returns the address of the TRUST token contract.

**Returns**: Address of the Trust ERC20 token

**Use Cases**:
- Verify token contract integration
- Check token balance for burning
- Frontend integration

---

#### `getSatelliteEmissionsController`
```solidity
function getSatelliteEmissionsController() external view returns (address)
```
Returns the address of the satellite emissions controller on the destination chain.

**Returns**: Address of SatelliteEmissionsController

**Use Cases**:
- Verify bridging destination
- Monitor cross-chain configuration
- Debugging bridge transfers

---

#### `getTotalMinted`
```solidity
function getTotalMinted() external view returns (uint256)
```
Returns the cumulative total of all TRUST tokens minted across all epochs.

**Returns**: Total minted amount in wei (18 decimals)

**Use Cases**:
- Track inflation rate
- Monitor total emissions
- Calculate remaining supply (MAX_SUPPLY - totalMinted)

---

#### `getEpochMintedAmount`
```solidity
function getEpochMintedAmount(uint256 epoch) external view returns (uint256)
```
Returns the amount of TRUST tokens minted for a specific epoch.

**Parameters**:
- `epoch`: Epoch number to query

**Returns**: Amount minted for the epoch (0 if not yet minted)

**Use Cases**:
- Verify epoch has been minted
- Check historical emissions
- Prevent duplicate minting

---

#### `getCurrentEpoch`
```solidity
function getCurrentEpoch() external view returns (uint256)
```
Returns the current epoch number based on `block.timestamp`.

**Returns**: Current epoch number

**Inherited from**: `CoreEmissionsController`

---

#### `getEmissionsAtEpoch`
```solidity
function getEmissionsAtEpoch(uint256 epochNumber) external view returns (uint256)
```
Calculates the emissions amount for a given epoch, including all cliff reductions.

**Parameters**:
- `epochNumber`: Epoch to calculate emissions for

**Returns**: Emissions amount in wei

**Inherited from**: `CoreEmissionsController`

**Example**:
```solidity
// Epoch 0-51: 1,000,000 TRUST
// Epoch 52-103: 950,000 TRUST (5% reduction)
// Epoch 104-155: 902,500 TRUST (another 5% reduction)
```

---

#### `getBalance`
```solidity
function getBalance() external view returns (uint256)
```
Returns the native token (ETH) balance held by the contract for gas payments.

**Returns**: ETH balance in wei

**Use Cases**:
- Monitor gas reserves
- Determine if refill needed
- Calculate withdrawal amounts

---

### Write Functions

#### `mintAndBridgeCurrentEpoch`
```solidity
function mintAndBridgeCurrentEpoch() external nonReentrant onlyRole(CONTROLLER_ROLE)
```
Mints TRUST tokens for the current epoch and bridges them to the satellite chain. Automatically calculates and uses gas from contract balance.

**Access**: Requires `CONTROLLER_ROLE`

**Emits**: `TrustMintedAndBridged(to, amount, epoch)`

**Reverts**:
- `BaseEmissionsController_SatelliteEmissionsControllerNotSet` - Satellite address not configured
- `BaseEmissionsController_EpochMintingLimitExceeded` - Epoch already minted
- `BaseEmissionsController_InsufficientGasPayment` - Insufficient ETH balance

**Gas Considerations**: Uses contract's ETH balance, requires sufficient funds

**Example Flow**:
1. Calculates current epoch
2. Determines emissions amount
3. Mints TRUST to self
4. Approves MetaLayer contract
5. Bridges tokens to SatelliteEmissionsController

---

#### `mintAndBridge`
```solidity
function mintAndBridge(uint256 epoch) external payable nonReentrant onlyRole(CONTROLLER_ROLE)
```
Mints TRUST tokens for a specific epoch and bridges them, using provided ETH for gas.

**Parameters**:
- `epoch`: Epoch number to mint (must be ≤ current epoch)

**Access**: Requires `CONTROLLER_ROLE`

**Payable**: Accepts ETH for gas costs (refunds excess)

**Emits**: `TrustMintedAndBridged(to, amount, epoch)`

**Reverts**:
- `BaseEmissionsController_InvalidEpoch` - Epoch is in the future
- `BaseEmissionsController_EpochMintingLimitExceeded` - Epoch already minted
- `BaseEmissionsController_InsufficientGasPayment` - Insufficient ETH provided
- `BaseEmissionsController_SatelliteEmissionsControllerNotSet` - Satellite not set

**Use Cases**:
- Mint historical epochs that were missed
- Provide explicit gas payment
- Recover from temporary failures

---

### Admin Functions

#### `setTrustToken`
```solidity
function setTrustToken(address newToken) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the TRUST token contract address.

**Parameters**:
- `newToken`: New Trust token address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `TrustTokenUpdated(newToken)`

**Reverts**: `BaseEmissionsController_InvalidAddress` if `newToken` is zero address

**Security Note**: Should only be used during initial deployment or emergency upgrades

---

#### `setSatelliteEmissionsController`
```solidity
function setSatelliteEmissionsController(address newSatellite) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the satellite emissions controller address on the destination chain.

**Parameters**:
- `newSatellite`: New satellite controller address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `SatelliteEmissionsControllerUpdated(newSatellite)`

**Reverts**: `BaseEmissionsController_InvalidAddress` if address is zero

---

#### `setMessageGasCost`
```solidity
function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the gas cost used for cross-chain message estimation.

**Parameters**:
- `newGasCost`: New gas cost in wei

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Inherited from**: `MetaERC20Dispatcher`

---

#### `setFinalityState`
```solidity
function setFinalityState(FinalityState newFinalityState) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the finality requirement for cross-chain messages.

**Parameters**:
- `newFinalityState`: Either `FINALIZED` or `INSTANT`

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Options**:
- `FINALIZED`: Wait for block finality (safer, slower)
- `INSTANT`: Immediate execution (faster, less secure)

---

#### `setMetaERC20SpokeOrHub`
```solidity
function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the MetaLayer hub/spoke contract address for cross-chain bridging.

**Parameters**:
- `newMetaERC20SpokeOrHub`: New MetaLayer contract address

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `setRecipientDomain`
```solidity
function setRecipientDomain(uint32 newRecipientDomain) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Updates the destination chain domain ID for cross-chain messages.

**Parameters**:
- `newRecipientDomain`: New domain ID (chain identifier)

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `burn`
```solidity
function burn(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Burns TRUST tokens held by the contract (typically unclaimed emissions bridged back).

**Parameters**:
- `amount`: Amount of TRUST to burn (in wei)

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `TrustBurned(address(this), amount)`

**Reverts**: `BaseEmissionsController_InsufficientBurnableBalance` if amount exceeds balance

**Use Cases**:
- Burn unclaimed emissions from satellite chain
- Remove excess supply
- Implement deflationary mechanisms

---

#### `withdraw`
```solidity
function withdraw(uint256 amount) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE)
```
Withdraws native tokens (ETH) from the contract to the caller.

**Parameters**:
- `amount`: Amount of ETH to withdraw (in wei)

**Access**: Requires `DEFAULT_ADMIN_ROLE`

**Emits**: `Transfer(address(this), msg.sender, amount)`

**Use Cases**:
- Recover excess gas funds
- Rebalance treasury
- Emergency fund recovery

---

## Events

### `TrustTokenUpdated`
```solidity
event TrustTokenUpdated(address indexed newTrustToken)
```
Emitted when the Trust token contract address is updated.

**Parameters**:
- `newTrustToken`: New Trust token address

**Use Cases**:
- Monitor configuration changes
- Verify contract setup
- Audit administrative actions

---

### `SatelliteEmissionsControllerUpdated`
```solidity
event SatelliteEmissionsControllerUpdated(address indexed newSatelliteEmissionsController)
```
Emitted when the satellite emissions controller address is updated.

**Parameters**:
- `newSatelliteEmissionsController`: New satellite controller address

**Use Cases**:
- Track cross-chain configuration
- Monitor bridging destination changes
- Verify deployment parameters

---

### `TrustMintedAndBridged`
```solidity
event TrustMintedAndBridged(address indexed to, uint256 amount, uint256 epoch)
```
Emitted when TRUST tokens are minted and successfully bridged to the satellite chain.

**Parameters**:
- `to`: Destination address (SatelliteEmissionsController)
- `amount`: Amount of TRUST minted and bridged
- `epoch`: Epoch number for which tokens were minted

**Use Cases**:
- Track emissions distribution
- Monitor cross-chain transfers
- Calculate inflation rate
- Verify epoch minting

---

### `TrustBurned`
```solidity
event TrustBurned(address indexed from, uint256 amount)
```
Emitted when TRUST tokens are burned by the contract.

**Parameters**:
- `from`: Address burning the tokens (always this contract)
- `amount`: Amount of TRUST burned

**Use Cases**:
- Track deflationary events
- Monitor unclaimed emissions
- Calculate net inflation

---

### `Transfer`
```solidity
event Transfer(address indexed from, address indexed to, uint256 amount)
```
Emitted when native tokens (ETH) are transferred to or from the contract.

**Parameters**:
- `from`: Source address
- `to`: Destination address
- `amount`: Amount transferred in wei

**Use Cases**:
- Track gas fund deposits
- Monitor ETH withdrawals
- Audit treasury movements

---

## Errors

### `BaseEmissionsController_InvalidAddress`
Thrown when a zero address is provided where a valid address is required.

**Triggers**:
- Setting Trust token to zero address
- Setting satellite controller to zero address
- Invalid initialization parameters

**Recovery**: Provide a valid non-zero address

---

### `BaseEmissionsController_InvalidEpoch`
Thrown when attempting to mint for an epoch that hasn't occurred yet.

**Triggers**:
- Calling `mintAndBridge` with epoch > current epoch

**Recovery**: Wait for the epoch to begin or use current epoch

---

### `BaseEmissionsController_InsufficientGasPayment`
Thrown when insufficient ETH is provided for cross-chain gas costs.

**Triggers**:
- Contract balance too low for `mintAndBridgeCurrentEpoch`
- `msg.value` too low for `mintAndBridge`

**Recovery**:
- Send more ETH to contract via `receive()`
- Provide more ETH in `msg.value`

**Gas Calculation**:
```solidity
requiredGas = GAS_CONSTANT + messageGasCost
```

---

### `BaseEmissionsController_EpochMintingLimitExceeded`
Thrown when attempting to mint an epoch that has already been minted.

**Triggers**:
- Calling mint functions for an epoch where `_epochToMintedAmount[epoch] > 0`

**Recovery**: Cannot recover - each epoch can only be minted once

**Prevention**: Check `getEpochMintedAmount(epoch)` before minting

---

### `BaseEmissionsController_InsufficientBurnableBalance`
Thrown when attempting to burn more TRUST than the contract holds.

**Triggers**:
- Calling `burn(amount)` where `amount > TRUST.balanceOf(this)`

**Recovery**: Reduce burn amount to available balance

---

### `BaseEmissionsController_SatelliteEmissionsControllerNotSet`
Thrown when attempting to bridge tokens before satellite controller is configured.

**Triggers**:
- Calling mint functions when `_SATELLITE_EMISSIONS_CONTROLLER == address(0)`

**Recovery**: Admin must call `setSatelliteEmissionsController` first

---

## Access Control

### Roles

The contract uses OpenZeppelin's `AccessControlUpgradeable` with two key roles:

#### `DEFAULT_ADMIN_ROLE` (`bytes32(0)`)

**Permissions**:
- Set Trust token address
- Set satellite controller address
- Configure MetaLayer parameters
- Burn TRUST tokens
- Withdraw ETH
- Grant/revoke all roles

**Intended Holder**: Protocol multisig or governance timelock

**Security**: Ultimate control over emissions system

---

#### `CONTROLLER_ROLE` (`keccak256("CONTROLLER_ROLE")`)

**Permissions**:
- Mint and bridge current epoch
- Mint and bridge specific epochs

**Intended Holder**: Automated operator bot or trusted EOA

**Security**: Can mint but only according to schedule, cannot modify parameters

---

### Permission Matrix

| Function | DEFAULT_ADMIN_ROLE | CONTROLLER_ROLE | Public |
|----------|-------------------|----------------|--------|
| `mintAndBridgeCurrentEpoch` | ❌ | ✅ | ❌ |
| `mintAndBridge` | ❌ | ✅ | ❌ |
| `setTrustToken` | ✅ | ❌ | ❌ |
| `setSatelliteEmissionsController` | ✅ | ❌ | ❌ |
| `setMessageGasCost` | ✅ | ❌ | ❌ |
| `burn` | ✅ | ❌ | ❌ |
| `withdraw` | ✅ | ❌ | ❌ |
| Read functions | ✅ | ✅ | ✅ |

---

## Usage Examples

### TypeScript (VIEM)

```typescript
import { createPublicClient, createWalletClient, http, parseEther } from 'viem';
import { base } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

// Contract ABI (partial)
const BASE_EMISSIONS_CONTROLLER_ABI = [
  {
    name: 'getCurrentEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getEmissionsAtEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epochNumber', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getEpochMintedAmount',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'mintAndBridgeCurrentEpoch',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'mintAndBridge',
    type: 'function',
    stateMutability: 'payable',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [],
  },
] as const;

const BASE_EMISSIONS_CONTROLLER_ADDRESS = '0x...'; // Replace with actual address

// Setup clients
const publicClient = createPublicClient({
  chain: base,
  transport: http(),
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http(),
});

// Example 1: Query current epoch and emissions
async function getCurrentEmissionsInfo() {
  const currentEpoch = await publicClient.readContract({
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    functionName: 'getCurrentEpoch',
  });

  const emissionsAmount = await publicClient.readContract({
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    functionName: 'getEmissionsAtEpoch',
    args: [currentEpoch],
  });

  const alreadyMinted = await publicClient.readContract({
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    functionName: 'getEpochMintedAmount',
    args: [currentEpoch],
  });

  console.log(`Current Epoch: ${currentEpoch}`);
  console.log(`Emissions for Epoch: ${emissionsAmount} wei`);
  console.log(`Already Minted: ${alreadyMinted > 0n}`);
}

// Example 2: Mint and bridge current epoch (requires CONTROLLER_ROLE)
async function mintCurrentEpoch() {
  const { request } = await publicClient.simulateContract({
    account,
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    functionName: 'mintAndBridgeCurrentEpoch',
  });

  const hash = await walletClient.writeContract(request);
  console.log(`Transaction hash: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Minted and bridged in block ${receipt.blockNumber}`);
}

// Example 3: Mint specific epoch with gas payment
async function mintSpecificEpoch(epochNumber: bigint, gasPayment: bigint) {
  const { request } = await publicClient.simulateContract({
    account,
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    functionName: 'mintAndBridge',
    args: [epochNumber],
    value: gasPayment,
  });

  const hash = await walletClient.writeContract(request);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  console.log(`Minted epoch ${epochNumber} in tx ${hash}`);
}

// Example 4: Monitor emissions events
async function monitorEmissions() {
  const unwatch = publicClient.watchContractEvent({
    address: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi: BASE_EMISSIONS_CONTROLLER_ABI,
    eventName: 'TrustMintedAndBridged',
    onLogs: (logs) => {
      logs.forEach((log) => {
        console.log(`Minted: ${log.args.amount} TRUST for epoch ${log.args.epoch}`);
        console.log(`Bridged to: ${log.args.to}`);
      });
    },
  });

  // Unwatch after 1 hour
  setTimeout(() => unwatch(), 3600000);
}

// Run examples
getCurrentEmissionsInfo();
```

---

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
import json
import time

# Connect to Base
w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))

# Contract setup
BASE_EMISSIONS_CONTROLLER_ADDRESS = '0x...'  # Replace with actual address

# Minimal ABI
BASE_EMISSIONS_CONTROLLER_ABI = json.loads('''[
  {
    "name": "getCurrentEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "getEmissionsAtEpoch",
    "type": "function",
    "stateMutability": "view",
    "inputs": [{"name": "epochNumber", "type": "uint256"}],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "getTotalMinted",
    "type": "function",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [{"type": "uint256"}]
  },
  {
    "name": "mintAndBridgeCurrentEpoch",
    "type": "function",
    "stateMutability": "nonpayable",
    "inputs": [],
    "outputs": []
  },
  {
    "name": "mintAndBridge",
    "type": "function",
    "stateMutability": "payable",
    "inputs": [{"name": "epoch", "type": "uint256"}],
    "outputs": []
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "name": "to", "type": "address"},
      {"indexed": false, "name": "amount", "type": "uint256"},
      {"indexed": false, "name": "epoch", "type": "uint256"}
    ],
    "name": "TrustMintedAndBridged",
    "type": "event"
  }
]''')

# Create contract instance
controller = w3.eth.contract(
    address=BASE_EMISSIONS_CONTROLLER_ADDRESS,
    abi=BASE_EMISSIONS_CONTROLLER_ABI
)

# Example 1: Get current emissions info
def get_emissions_info():
    current_epoch = controller.functions.getCurrentEpoch().call()
    emissions = controller.functions.getEmissionsAtEpoch(current_epoch).call()
    total_minted = controller.functions.getTotalMinted().call()

    print(f"Current Epoch: {current_epoch}")
    print(f"Current Epoch Emissions: {w3.from_wei(emissions, 'ether')} TRUST")
    print(f"Total Minted: {w3.from_wei(total_minted, 'ether')} TRUST")

    return current_epoch, emissions, total_minted

# Example 2: Mint current epoch (requires CONTROLLER_ROLE)
def mint_current_epoch(private_key):
    account = Account.from_key(private_key)

    # Build transaction
    txn = controller.functions.mintAndBridgeCurrentEpoch().build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
    })

    # Sign and send
    signed_txn = account.sign_transaction(txn)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)

    print(f"Transaction sent: {tx_hash.hex()}")

    # Wait for receipt
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"Transaction mined in block {receipt['blockNumber']}")

    return receipt

# Example 3: Mint specific epoch with gas payment
def mint_epoch_with_gas(epoch_number, gas_payment_wei, private_key):
    account = Account.from_key(private_key)

    txn = controller.functions.mintAndBridge(epoch_number).build_transaction({
        'from': account.address,
        'value': gas_payment_wei,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
    })

    signed_txn = account.sign_transaction(txn)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    print(f"Minted epoch {epoch_number}: {tx_hash.hex()}")
    return receipt

# Example 4: Listen for minting events
def listen_for_minting_events():
    # Create event filter
    event_filter = controller.events.TrustMintedAndBridged.create_filter(
        fromBlock='latest'
    )

    print("Listening for TrustMintedAndBridged events...")

    while True:
        for event in event_filter.get_new_entries():
            print(f"\nNew Minting Event:")
            print(f"  Recipient: {event['args']['to']}")
            print(f"  Amount: {w3.from_wei(event['args']['amount'], 'ether')} TRUST")
            print(f"  Epoch: {event['args']['epoch']}")
            print(f"  Block: {event['blockNumber']}")
            print(f"  Tx: {event['transactionHash'].hex()}")

        time.sleep(10)  # Check every 10 seconds

# Example 5: Calculate future emissions
def calculate_emissions_schedule(num_epochs):
    current_epoch = controller.functions.getCurrentEpoch().call()

    print(f"\nEmissions Schedule (next {num_epochs} epochs):")
    print("-" * 60)

    for i in range(num_epochs):
        epoch = current_epoch + i
        emissions = controller.functions.getEmissionsAtEpoch(epoch).call()
        print(f"Epoch {epoch}: {w3.from_wei(emissions, 'ether'):,.2f} TRUST")

# Run examples
if __name__ == "__main__":
    get_emissions_info()
    calculate_emissions_schedule(10)
```

---

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";

/**
 * @title EmissionsOperator
 * @notice Automated operator contract for managing epoch-based emissions minting
 */
contract EmissionsOperator {
    IBaseEmissionsController public immutable baseEmissionsController;
    address public owner;
    uint256 public lastMintedEpoch;

    event EpochMinted(uint256 indexed epoch, uint256 amount, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OnlyOwner();
    error EpochAlreadyMinted();
    error InsufficientGasBalance();

    constructor(address _baseEmissionsController) {
        baseEmissionsController = IBaseEmissionsController(_baseEmissionsController);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Automatically mint current epoch if not already minted
     */
    function mintCurrentEpochIfNeeded() external onlyOwner {
        uint256 currentEpoch = ICoreEmissionsController(address(baseEmissionsController))
            .getCurrentEpoch();

        // Check if epoch already minted
        uint256 alreadyMinted = baseEmissionsController.getEpochMintedAmount(currentEpoch);
        if (alreadyMinted > 0) {
            revert EpochAlreadyMinted();
        }

        // Check contract has enough gas balance
        if (address(baseEmissionsController).balance < 0.01 ether) {
            revert InsufficientGasBalance();
        }

        // Mint and bridge
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        lastMintedEpoch = currentEpoch;

        uint256 emissions = ICoreEmissionsController(address(baseEmissionsController))
            .getEmissionsAtEpoch(currentEpoch);

        emit EpochMinted(currentEpoch, emissions, block.timestamp);
    }

    /**
     * @notice Mint specific epoch with gas payment
     */
    function mintEpoch(uint256 epoch) external payable onlyOwner {
        baseEmissionsController.mintAndBridge{value: msg.value}(epoch);

        uint256 emissions = ICoreEmissionsController(address(baseEmissionsController))
            .getEmissionsAtEpoch(epoch);

        emit EpochMinted(epoch, emissions, block.timestamp);
    }

    /**
     * @notice Get emissions info for current epoch
     */
    function getCurrentEmissionsInfo()
        external
        view
        returns (
            uint256 currentEpoch,
            uint256 emissionsAmount,
            bool alreadyMinted,
            uint256 totalMinted
        )
    {
        currentEpoch = ICoreEmissionsController(address(baseEmissionsController))
            .getCurrentEpoch();
        emissionsAmount = ICoreEmissionsController(address(baseEmissionsController))
            .getEmissionsAtEpoch(currentEpoch);
        uint256 epochMinted = baseEmissionsController.getEpochMintedAmount(currentEpoch);
        alreadyMinted = epochMinted > 0;
        totalMinted = baseEmissionsController.getTotalMinted();
    }

    /**
     * @notice Fund the base emissions controller with ETH for gas
     */
    function fundGasReserve() external payable {
        (bool success, ) = address(baseEmissionsController).call{value: msg.value}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Withdraw ETH from this contract
     */
    function withdraw(uint256 amount) external onlyOwner {
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}

/**
 * @title EmissionsMonitor
 * @notice View contract for monitoring emissions system state
 */
contract EmissionsMonitor {
    IBaseEmissionsController public immutable baseEmissionsController;
    ICoreEmissionsController public immutable coreEmissionsController;

    struct EmissionsSnapshot {
        uint256 currentEpoch;
        uint256 currentEmissions;
        uint256 totalMinted;
        uint256 gasBalance;
        bool currentEpochMinted;
        uint256 epochStartTime;
        uint256 epochEndTime;
    }

    constructor(address _baseEmissionsController) {
        baseEmissionsController = IBaseEmissionsController(_baseEmissionsController);
        coreEmissionsController = ICoreEmissionsController(_baseEmissionsController);
    }

    /**
     * @notice Get comprehensive emissions snapshot
     */
    function getEmissionsSnapshot() external view returns (EmissionsSnapshot memory) {
        uint256 currentEpoch = coreEmissionsController.getCurrentEpoch();

        return EmissionsSnapshot({
            currentEpoch: currentEpoch,
            currentEmissions: coreEmissionsController.getEmissionsAtEpoch(currentEpoch),
            totalMinted: baseEmissionsController.getTotalMinted(),
            gasBalance: address(baseEmissionsController).balance,
            currentEpochMinted: baseEmissionsController.getEpochMintedAmount(currentEpoch) > 0,
            epochStartTime: coreEmissionsController.getEpochTimestampStart(currentEpoch),
            epochEndTime: coreEmissionsController.getEpochTimestampEnd(currentEpoch)
        });
    }

    /**
     * @notice Get emissions schedule for next N epochs
     */
    function getEmissionsSchedule(uint256 numEpochs)
        external
        view
        returns (uint256[] memory epochs, uint256[] memory emissions)
    {
        uint256 currentEpoch = coreEmissionsController.getCurrentEpoch();

        epochs = new uint256[](numEpochs);
        emissions = new uint256[](numEpochs);

        for (uint256 i = 0; i < numEpochs; i++) {
            uint256 epoch = currentEpoch + i;
            epochs[i] = epoch;
            emissions[i] = coreEmissionsController.getEmissionsAtEpoch(epoch);
        }

        return (epochs, emissions);
    }
}
```

---

## Integration Notes

### SDK Considerations

When integrating BaseEmissionsController into SDKs:

1. **Epoch Timing**: Always check current epoch before minting operations
2. **Gas Management**: Monitor contract ETH balance and refill proactively
3. **Error Handling**: Implement retry logic for cross-chain bridge failures
4. **Event Monitoring**: Subscribe to `TrustMintedAndBridged` for real-time tracking
5. **Access Control**: Verify caller has `CONTROLLER_ROLE` before write operations

### Common Patterns

**Automated Epoch Minting**:
```typescript
// Check every hour if new epoch needs minting
setInterval(async () => {
  const currentEpoch = await controller.read.getCurrentEpoch();
  const minted = await controller.read.getEpochMintedAmount([currentEpoch]);

  if (minted === 0n) {
    await controller.write.mintAndBridgeCurrentEpoch();
  }
}, 3600000); // 1 hour
```

**Gas Reserve Management**:
```typescript
// Maintain minimum 0.1 ETH balance
const balance = await publicClient.getBalance({
  address: BASE_EMISSIONS_CONTROLLER_ADDRESS
});

if (balance < parseEther('0.1')) {
  await walletClient.sendTransaction({
    to: BASE_EMISSIONS_CONTROLLER_ADDRESS,
    value: parseEther('0.5'), // Refill to 0.5 ETH
  });
}
```

### Edge Cases

1. **Missed Epochs**: If epochs are skipped, use `mintAndBridge(epoch)` to mint historical epochs
2. **Bridge Failures**: Monitor for stuck transfers and implement retry mechanism
3. **Clock Skew**: Account for block timestamp variations when calculating epochs
4. **Upgrade Scenarios**: Verify new implementation maintains emissions schedule continuity

---

## Gas Considerations

### Approximate Costs

| Operation | Estimated Gas | Cost @ 5 gwei | Notes |
|-----------|--------------|---------------|--------|
| `mintAndBridgeCurrentEpoch` | ~400,000 | ~0.002 ETH | Includes bridge tx |
| `mintAndBridge` | ~400,000 | ~0.002 ETH | Similar to above |
| `setTrustToken` | ~50,000 | ~0.00025 ETH | Simple storage update |
| `burn` | ~100,000 | ~0.0005 ETH | Includes ERC20 burn |
| `withdraw` | ~35,000 | ~0.000175 ETH | ETH transfer |
| Read functions | ~30,000 | Free (view) | No state changes |

### Optimization Tips

1. **Batch Historical Mints**: If multiple epochs missed, prioritize recent ones first
2. **Gas Price Monitoring**: Wait for lower gas prices for non-urgent admin operations
3. **Event Indexing**: Use events instead of repeatedly querying state
4. **Multicall**: Batch read operations using multicall for efficiency

### Cross-Chain Gas

The contract requires ETH for MetaLayer bridge messages:
- **Estimated per bridge**: 0.001-0.005 ETH depending on L3 gas prices
- **Buffer recommendation**: Maintain 0.1 ETH balance minimum
- **Refund mechanism**: Excess gas automatically refunded in `mintAndBridge`

---

## Related Contracts

### Core Dependencies

- **[Trust](/docs/contracts/core/Trust.md)**: ERC20 token minted by this controller
- **[CoreEmissionsController](/docs/contracts/emissions/CoreEmissionsController.md)**: Inherited emissions calculation logic
- **[SatelliteEmissionsController](/docs/contracts/emissions/SatelliteEmissionsController.md)**: Receives bridged TRUST on Intuition Mainnet

### System Architecture

```
Base L2:
  BaseEmissionsController (mints TRUST)
       ↓ (bridges via MetaLayer)
Intuition L3:
  SatelliteEmissionsController (receives TRUST)
       ↓ (transfers to)
  TrustBonding (distributes to users)
       ↓ (unclaimed bridged back)
  BaseEmissionsController (burns unclaimed)
```

### Integration Points

- **Trust Token**: Calls `mint()` and `burn()` functions
- **MetaLayer Hub/Spoke**: Uses for cross-chain ERC20 transfers
- **SatelliteEmissionsController**: Destination for all minted tokens
- **Governance/Timelock**: Holds `DEFAULT_ADMIN_ROLE` for parameter updates

---

## See Also

### Documentation

- [Emissions System Overview](/docs/concepts/emissions-system.md)
- [Epoch Management](/docs/concepts/epochs.md)
- [Cross-Chain Architecture](/docs/concepts/cross-chain.md)
- [Token Economics](/docs/concepts/tokenomics.md)

### Guides

- [Operating the Emissions System](/docs/guides/emissions-operator.md)
- [Monitoring Emissions](/docs/guides/emissions-monitoring.md)
- [Emergency Procedures](/docs/guides/emissions-emergency.md)
- [Gas Management](/docs/guides/gas-management.md)

### Related Contracts

- [SatelliteEmissionsController.md](./SatelliteEmissionsController.md)
- [CoreEmissionsController.md](./CoreEmissionsController.md)
- [TrustBonding.md](./TrustBonding.md)
- [Trust.md](/docs/contracts/core/Trust.md)
