# Quick Start with ABI Integration

Direct integration with Intuition Protocol V2 using contract ABIs and web3 libraries. This guide shows you how to interact with the protocol without relying on SDKs.

## Overview

This guide is for developers who want to:
- Build custom integrations directly with contract ABIs
- Use any web3 library (ethers.js, web3.js, viem, web3.py, etc.)
- Have full control over transaction construction
- Integrate with existing codebases

If you're building a TypeScript SDK, see [Quick Start for SDK Builders](./quickstart-sdk.md).

## Prerequisites

- Understanding of Ethereum transactions and contract interactions
- A web3 library of your choice
- RPC access to Base Mainnet and Intuition Mainnet
- Contract ABIs (see [Getting ABIs](#getting-abis))

## Network Information

Intuition Protocol V2 operates across two networks:

### Base Mainnet (Chain ID: 8453)
**Purpose**: TRUST token minting and base emissions

**RPC URL**: `https://mainnet.base.org`

**Key Contracts**:
- TRUST Token: `0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3`
- BaseEmissionsController: `0x5F1A83bDf177ff04b4bdDb92c66d3C8e64D1FFaF`

### Intuition Mainnet
**Purpose**: Core protocol operations (vaults, bonding, rewards)

**RPC URL**: Contact Intuition team for access

**Key Contracts**:
- MultiVault: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
- TrustBonding: `0x2B0c2700BB0E9Ea294c7c6Ea5C5c42cC0dba3583`
- SatelliteEmissionsController: `0x8fA1aA35c4e2E4Be3Df1d57c0c14EB8D2B65B8BA`

See [Deployment Addresses](./deployment-addresses.md) for complete contract list.

## Getting ABIs

### Option 1: Block Explorers

Download verified contract ABIs directly:

**Base Mainnet**: [BaseScan](https://basescan.org)
- Navigate to contract address
- Click "Contract" tab
- Scroll to "Contract ABI" section
- Copy JSON

**Intuition Mainnet**: [Intuition Explorer](https://explorer.intuit.network)
- Follow same process as BaseScan

### Option 2: From Repository

Clone the contracts repository and build:

```bash
git clone https://github.com/0xIntuition/intuition-contracts-v2.git
cd intuition-contracts-v2
forge build
```

ABIs are generated in `out/[ContractName].sol/[ContractName].json`

Key ABI files:
- `out/MultiVault.sol/MultiVault.json`
- `out/Trust.sol/Trust.json`
- `out/TrustBonding.sol/TrustBonding.json`

### Option 3: Documentation

Pre-extracted ABIs are available in the [reference/abi](../reference/abi/) directory.

## Core Operations

### 1. Creating an Atom

Atoms are the fundamental data units. Each atom gets a unique ID and an associated smart wallet.

#### Calculate Atom ID (Off-Chain)

Before creating an atom, you can compute its expected ID:

```javascript
// Using ethers.js v6
import { ethers } from 'ethers';

function calculateAtomId(atomData) {
  const SALT = ethers.keccak256(ethers.toUtf8Bytes('SALT'));
  const dataHash = ethers.keccak256(atomData);
  return ethers.keccak256(ethers.concat([SALT, dataHash]));
}

// Example
const atomData = ethers.toUtf8Bytes('example-atom');
const expectedAtomId = calculateAtomId(atomData);
console.log('Expected Atom ID:', expectedAtomId);
```

```python
# Using web3.py
from web3 import Web3

def calculate_atom_id(atom_data: bytes) -> str:
    SALT = Web3.keccak(text='SALT')
    data_hash = Web3.keccak(atom_data)
    return Web3.keccak(SALT + data_hash).hex()

# Example
atom_data = b'example-atom'
expected_atom_id = calculate_atom_id(atom_data)
print(f'Expected Atom ID: {expected_atom_id}')
```

#### Create Atom Transaction

**Function Signature**:
```solidity
function createAtoms(
    bytes[] calldata atomDatas,
    uint256[] calldata assets
) external payable returns (bytes32[] memory)
```

**Parameters**:
- `atomDatas`: Array of byte data (≤256 bytes each) representing atoms
- `assets`: Array of asset amounts to deposit into each atom vault

**Returns**: Array of created atom IDs

**Events Emitted**:
- `AtomCreated(address creator, bytes32 termId, bytes atomData, address atomWallet)`
- `Deposited(address sender, address receiver, bytes32 termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, VaultType vaultType)`

**Example (ethers.js)**:

```javascript
import { ethers } from 'ethers';
import MULTIVAULT_ABI from './abis/MultiVault.json';

const provider = new ethers.JsonRpcProvider('YOUR_INTUITION_RPC');
const signer = new ethers.Wallet('PRIVATE_KEY', provider);

const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MULTIVAULT_ABI, signer);

async function createAtom(atomDataString, depositAmount) {
  // Encode atom data as bytes
  const atomData = ethers.toUtf8Bytes(atomDataString);

  // Prepare arrays (can create multiple atoms at once)
  const atomDatas = [atomData];
  const assets = [depositAmount];

  // Send transaction with ETH value
  const tx = await multiVault.createAtoms(atomDatas, assets, {
    value: depositAmount,
    gasLimit: 500000 // Estimate appropriately
  });

  console.log('Transaction hash:', tx.hash);
  const receipt = await tx.wait();

  // Parse AtomCreated event
  const atomCreatedLog = receipt.logs.find(log => {
    try {
      const parsed = multiVault.interface.parseLog(log);
      return parsed.name === 'AtomCreated';
    } catch {
      return false;
    }
  });

  if (atomCreatedLog) {
    const parsed = multiVault.interface.parseLog(atomCreatedLog);
    const atomId = parsed.args.termId;
    const atomWallet = parsed.args.atomWallet;

    console.log('Atom created!');
    console.log('  Atom ID:', atomId);
    console.log('  Atom Wallet:', atomWallet);

    return { atomId, atomWallet };
  }

  throw new Error('AtomCreated event not found');
}

// Usage
const depositAmount = ethers.parseEther('0.1');
const result = await createAtom('My First Atom', depositAmount);
```

**Example (Python/web3.py)**:

```python
from web3 import Web3
import json

# Connect to Intuition Mainnet
w3 = Web3(Web3.HTTPProvider('YOUR_INTUITION_RPC'))
account = w3.eth.account.from_key('PRIVATE_KEY')

# Load ABI
with open('MultiVault.json') as f:
    abi = json.load(f)['abi']

MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
multivault = w3.eth.contract(address=MULTIVAULT_ADDRESS, abi=abi)

def create_atom(atom_data_string: str, deposit_amount: int):
    # Encode atom data as bytes
    atom_data = atom_data_string.encode('utf-8')

    # Build transaction
    tx = multivault.functions.createAtoms(
        [atom_data],  # atomDatas
        [deposit_amount]  # assets
    ).build_transaction({
        'from': account.address,
        'value': deposit_amount,
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
        'nonce': w3.eth.get_transaction_count(account.address)
    })

    # Sign and send
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)

    print(f'Transaction hash: {tx_hash.hex()}')

    # Wait for receipt
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    # Parse events
    atom_created_event = multivault.events.AtomCreated().process_receipt(receipt)

    if atom_created_event:
        event_data = atom_created_event[0]['args']
        atom_id = event_data['termId'].hex()
        atom_wallet = event_data['atomWallet']

        print(f'Atom created!')
        print(f'  Atom ID: {atom_id}')
        print(f'  Atom Wallet: {atom_wallet}')

        return {'atom_id': atom_id, 'atom_wallet': atom_wallet}

    raise Exception('AtomCreated event not found')

# Usage
deposit_amount = w3.to_wei(0.1, 'ether')
result = create_atom('My First Atom', deposit_amount)
```

### 2. Creating a Triple

Triples express relationships between three atoms (subject-predicate-object).

#### Calculate Triple ID (Off-Chain)

```javascript
// Using ethers.js v6
function calculateTripleId(subjectId, predicateId, objectId) {
  const encoded = ethers.solidityPacked(
    ['bytes32', 'bytes32', 'bytes32'],
    [subjectId, predicateId, objectId]
  );
  return ethers.keccak256(encoded);
}

// Example
const tripleId = calculateTripleId(
  '0x1234...', // subject atom ID
  '0x5678...', // predicate atom ID
  '0x9abc...'  // object atom ID
);
```

```python
# Using web3.py
from eth_abi import encode

def calculate_triple_id(subject_id: str, predicate_id: str, object_id: str) -> str:
    encoded = encode(
        ['bytes32', 'bytes32', 'bytes32'],
        [bytes.fromhex(subject_id[2:]), bytes.fromhex(predicate_id[2:]), bytes.fromhex(object_id[2:])]
    )
    return Web3.keccak(encoded).hex()
```

#### Create Triple Transaction

**Function Signature**:
```solidity
function createTriples(
    bytes32[] calldata subjectIds,
    bytes32[] calldata predicateIds,
    bytes32[] calldata objectIds,
    uint256[] calldata assets
) external payable returns (bytes32[] memory)
```

**Parameters**:
- `subjectIds`: Array of subject atom IDs
- `predicateIds`: Array of predicate atom IDs
- `objectIds`: Array of object atom IDs
- `assets`: Array of asset amounts to deposit

**Returns**: Array of created triple IDs

**Events Emitted**:
- `TripleCreated(address creator, bytes32 termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId, bytes32 counterTripleId)`
- `Deposited(...)` - For triple vault and each underlying atom vault

**Example (ethers.js)**:

```javascript
async function createTriple(subjectId, predicateId, objectId, depositAmount) {
  // Verify all atoms exist
  const subjectExists = await multiVault.isTermCreated(subjectId);
  const predicateExists = await multiVault.isTermCreated(predicateId);
  const objectExists = await multiVault.isTermCreated(objectId);

  if (!subjectExists || !predicateExists || !objectExists) {
    throw new Error('One or more atoms do not exist');
  }

  // Prepare arrays
  const subjectIds = [subjectId];
  const predicateIds = [predicateId];
  const objectIds = [objectId];
  const assets = [depositAmount];

  // Send transaction
  const tx = await multiVault.createTriples(
    subjectIds,
    predicateIds,
    objectIds,
    assets,
    { value: depositAmount, gasLimit: 800000 }
  );

  const receipt = await tx.wait();

  // Parse TripleCreated event
  const tripleCreatedLog = receipt.logs.find(log => {
    try {
      const parsed = multiVault.interface.parseLog(log);
      return parsed.name === 'TripleCreated';
    } catch {
      return false;
    }
  });

  if (tripleCreatedLog) {
    const parsed = multiVault.interface.parseLog(tripleCreatedLog);
    console.log('Triple created!');
    console.log('  Triple ID:', parsed.args.termId);
    console.log('  Counter Triple ID:', parsed.args.counterTripleId);
    return parsed.args.termId;
  }

  throw new Error('TripleCreated event not found');
}
```

### 3. Depositing to a Vault

Add assets to an existing atom or triple vault to receive shares.

**Function Signature**:
```solidity
function deposit(
    address receiver,
    bytes32 termId,
    uint256 curveId,
    uint256 minShares
) external payable returns (uint256 shares)
```

**Parameters**:
- `receiver`: Address to receive the vault shares
- `termId`: ID of the atom or triple
- `curveId`: Bonding curve ID (0 for default curve)
- `minShares`: Minimum shares to receive (for slippage protection)

**Returns**: Actual shares minted

**Example with Slippage Protection**:

```javascript
async function depositToVault(termId, curveId, assets, slippageBps = 100) {
  // 1. Preview the deposit to get expected shares
  const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
    termId,
    curveId,
    assets
  );

  console.log(`Expected shares: ${ethers.formatEther(expectedShares)}`);
  console.log(`Assets after fees: ${ethers.formatEther(assetsAfterFees)}`);

  // 2. Calculate minimum shares (allow 1% slippage by default)
  const minShares = expectedShares * (10000n - BigInt(slippageBps)) / 10000n;

  // 3. Execute deposit
  const receiver = await signer.getAddress();
  const tx = await multiVault.deposit(
    receiver,
    termId,
    curveId,
    minShares,
    { value: assets }
  );

  const receipt = await tx.wait();
  console.log('Deposit successful!');

  // 4. Extract actual shares from event
  const depositedLog = receipt.logs.find(log => {
    try {
      const parsed = multiVault.interface.parseLog(log);
      return parsed.name === 'Deposited';
    } catch {
      return false;
    }
  });

  if (depositedLog) {
    const parsed = multiVault.interface.parseLog(depositedLog);
    console.log(`Actual shares received: ${ethers.formatEther(parsed.args.shares)}`);
    return parsed.args.shares;
  }

  return expectedShares;
}
```

### 4. Redeeming Shares

Convert vault shares back to assets.

**Function Signature**:
```solidity
function redeem(
    address receiver,
    bytes32 termId,
    uint256 curveId,
    uint256 shares,
    uint256 minAssets
) external returns (uint256 assets)
```

**Parameters**:
- `receiver`: Address to receive the assets
- `termId`: ID of the atom or triple
- `curveId`: Bonding curve ID
- `shares`: Amount of shares to redeem
- `minAssets`: Minimum assets to receive (slippage protection)

**Returns**: Actual assets returned

**Example**:

```javascript
async function redeemShares(termId, curveId, shares, slippageBps = 100) {
  // 1. Check user's share balance
  const userAddress = await signer.getAddress();
  const userShares = await multiVault.getShares(userAddress, termId, curveId);

  if (shares > userShares) {
    throw new Error(`Insufficient shares. Have: ${userShares}, want: ${shares}`);
  }

  // 2. Preview redemption
  const [expectedAssets, sharesUsed] = await multiVault.previewRedeem(
    termId,
    curveId,
    shares
  );

  console.log(`Expected assets: ${ethers.formatEther(expectedAssets)}`);

  // 3. Calculate minimum assets
  const minAssets = expectedAssets * (10000n - BigInt(slippageBps)) / 10000n;

  // 4. Execute redemption
  const tx = await multiVault.redeem(
    userAddress,
    termId,
    curveId,
    shares,
    minAssets
  );

  const receipt = await tx.wait();
  console.log('Redemption successful!');

  // 5. Extract actual assets from event
  const redeemedLog = receipt.logs.find(log => {
    try {
      const parsed = multiVault.interface.parseLog(log);
      return parsed.name === 'Redeemed';
    } catch {
      return false;
    }
  });

  if (redeemedLog) {
    const parsed = multiVault.interface.parseLog(redeemedLog);
    console.log(`Actual assets received: ${ethers.formatEther(parsed.args.assets)}`);
    return parsed.args.assets;
  }

  return expectedAssets;
}
```

### 5. Querying Vault State

Read vault information without sending transactions.

**Key Read Functions**:

```javascript
// Get vault totals
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Get user's share balance
const userShares = await multiVault.getShares(userAddress, termId, curveId);

// Get current share price (scaled by 1e18)
const sharePrice = await multiVault.currentSharePrice(termId, curveId);

// Check if term exists
const exists = await multiVault.isTermCreated(termId);

// Preview operations (no gas cost)
const [shares, assetsAfterFees] = await multiVault.previewDeposit(termId, curveId, assets);
const [assets, sharesUsed] = await multiVault.previewRedeem(termId, curveId, shares);
```

**Complete Query Example**:

```javascript
async function getVaultInfo(termId, curveId) {
  const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
  const sharePrice = await multiVault.currentSharePrice(termId, curveId);

  const userAddress = await signer.getAddress();
  const userShares = await multiVault.getShares(userAddress, termId, curveId);

  // Calculate user's assets value
  const userAssetsValue = userShares * sharePrice / ethers.parseEther('1');

  console.log('Vault Information:');
  console.log(`  Total Assets: ${ethers.formatEther(totalAssets)} ETH`);
  console.log(`  Total Shares: ${ethers.formatEther(totalShares)}`);
  console.log(`  Share Price: ${ethers.formatEther(sharePrice)} ETH`);
  console.log(`  Your Shares: ${ethers.formatEther(userShares)}`);
  console.log(`  Your Assets Value: ${ethers.formatEther(userAssetsValue)} ETH`);

  return {
    totalAssets,
    totalShares,
    sharePrice,
    userShares,
    userAssetsValue
  };
}
```

## Batch Operations

Execute multiple operations in a single transaction to save gas.

### Batch Deposits

**Function Signature**:
```solidity
function depositBatch(
    address receiver,
    bytes32[] calldata termIds,
    uint256[] calldata curveIds,
    uint256[] calldata assets,
    uint256[] calldata minShares
) external payable returns (uint256[] memory shares)
```

**Example**:

```javascript
async function batchDeposit(deposits) {
  // deposits = [
  //   { termId: '0x...', curveId: 0n, assets: parseEther('1') },
  //   { termId: '0x...', curveId: 0n, assets: parseEther('2') },
  //   ...
  // ]

  const receiver = await signer.getAddress();
  const termIds = deposits.map(d => d.termId);
  const curveIds = deposits.map(d => d.curveId);
  const assets = deposits.map(d => d.assets);
  const minShares = deposits.map(() => 0n); // Set appropriately in production

  // Calculate total value
  const totalValue = assets.reduce((sum, amt) => sum + amt, 0n);

  const tx = await multiVault.depositBatch(
    receiver,
    termIds,
    curveIds,
    assets,
    minShares,
    { value: totalValue }
  );

  const receipt = await tx.wait();
  console.log('Batch deposit successful!');
  return receipt;
}
```

### Batch Redemptions

**Function Signature**:
```solidity
function redeemBatch(
    address receiver,
    bytes32[] calldata termIds,
    uint256[] calldata curveIds,
    uint256[] calldata shares,
    uint256[] calldata minAssets
) external returns (uint256[] memory assets)
```

## Event Monitoring

Listen for protocol events to track activity.

### Subscribe to Events (ethers.js)

```javascript
// Listen for atom creation
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet, event) => {
  console.log('New Atom Created:');
  console.log(`  Creator: ${creator}`);
  console.log(`  Atom ID: ${termId}`);
  console.log(`  Atom Wallet: ${atomWallet}`);
  console.log(`  Data: ${ethers.toUtf8String(atomData)}`);
});

// Listen for deposits
multiVault.on('Deposited', (sender, receiver, termId, curveId, assets, assetsAfterFees, shares, totalShares, vaultType) => {
  console.log('Deposit Event:');
  console.log(`  Term ID: ${termId}`);
  console.log(`  Assets: ${ethers.formatEther(assets)}`);
  console.log(`  Shares: ${ethers.formatEther(shares)}`);
  console.log(`  Vault Type: ${vaultType}`); // 0=ATOM, 1=TRIPLE, 2=COUNTER_TRIPLE
});

// Listen for redemptions
multiVault.on('Redeemed', (sender, receiver, termId, curveId, shares, totalShares, assets, fees, vaultType) => {
  console.log('Redemption Event:');
  console.log(`  Term ID: ${termId}`);
  console.log(`  Shares Redeemed: ${ethers.formatEther(shares)}`);
  console.log(`  Assets Returned: ${ethers.formatEther(assets)}`);
  console.log(`  Fees: ${ethers.formatEther(fees)}`);
});
```

### Query Historical Events

```javascript
async function getAtomCreationHistory(fromBlock, toBlock) {
  const filter = multiVault.filters.AtomCreated();
  const events = await multiVault.queryFilter(filter, fromBlock, toBlock);

  return events.map(event => ({
    creator: event.args.creator,
    termId: event.args.termId,
    atomData: event.args.atomData,
    atomWallet: event.args.atomWallet,
    blockNumber: event.blockNumber,
    transactionHash: event.transactionHash
  }));
}

// Usage
const recentAtoms = await getAtomCreationHistory(-1000, 'latest');
console.log(`Found ${recentAtoms.length} atoms in last ~1000 blocks`);
```

### Event Filtering (Python)

```python
# Get recent deposits for a specific term
def get_deposits_for_term(term_id: str, from_block: int, to_block: str = 'latest'):
    event_filter = multivault.events.Deposited.create_filter(
        fromBlock=from_block,
        toBlock=to_block,
        argument_filters={'termId': term_id}
    )

    events = event_filter.get_all_entries()

    for event in events:
        print(f"Deposit: {w3.from_wei(event['args']['assets'], 'ether')} ETH")
        print(f"  Shares: {w3.from_wei(event['args']['shares'], 'ether')}")
        print(f"  Block: {event['blockNumber']}")

    return events
```

## Error Handling

### Common Errors and Solutions

**Error**: `MinSharesRequired()`
- **Cause**: Minimum share requirement not met
- **Solution**: Increase deposit amount or check vault's `minShare` configuration

**Error**: `MinAssetsRequired()`
- **Cause**: Slippage protection triggered (actual assets < minAssets)
- **Solution**: Increase slippage tolerance or wait for better pricing

**Error**: `InvalidAtomData()`
- **Cause**: Atom data exceeds 256 bytes
- **Solution**: Reduce atom data size

**Error**: `TermAlreadyExists()`
- **Cause**: Attempting to create an atom/triple that already exists
- **Solution**: Query existing term with `isTermCreated()` first

**Error**: `InsufficientShares()`
- **Cause**: Trying to redeem more shares than owned
- **Solution**: Check balance with `getShares()` first

### Error Handling Pattern (JavaScript)

```javascript
async function safeDeposit(termId, curveId, assets) {
  try {
    // 1. Validate term exists
    const exists = await multiVault.isTermCreated(termId);
    if (!exists) {
      throw new Error(`Term ${termId} does not exist`);
    }

    // 2. Check balance
    const balance = await provider.getBalance(await signer.getAddress());
    if (balance < assets) {
      throw new Error(`Insufficient balance`);
    }

    // 3. Preview deposit
    const [expectedShares] = await multiVault.previewDeposit(termId, curveId, assets);
    if (expectedShares === 0n) {
      throw new Error('Deposit would result in zero shares');
    }

    // 4. Execute deposit
    return await depositToVault(termId, curveId, assets);

  } catch (error) {
    // Handle specific error types
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error('Not enough ETH for gas + deposit');
    } else if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
      console.error('Transaction will likely fail - check parameters');
    } else if (error.message?.includes('MinSharesRequired')) {
      console.error('Deposit amount too small');
    } else {
      console.error('Unexpected error:', error.message);
    }
    throw error;
  }
}
```

## Gas Optimization

### Estimate Gas Before Sending

```javascript
// Estimate gas for a transaction
const estimatedGas = await multiVault.deposit.estimateGas(
  receiver,
  termId,
  curveId,
  minShares,
  { value: assets }
);

console.log(`Estimated gas: ${estimatedGas.toString()}`);

// Add 10% buffer for safety
const gasLimit = estimatedGas * 110n / 100n;

// Send with explicit gas limit
const tx = await multiVault.deposit(
  receiver,
  termId,
  curveId,
  minShares,
  { value: assets, gasLimit }
);
```

### Use Batch Operations

Batch operations save gas compared to individual transactions:

```javascript
// Instead of 3 separate deposits (3 transactions)
await deposit(termId1, curveId, assets1);
await deposit(termId2, curveId, assets2);
await deposit(termId3, curveId, assets3);

// Use batch deposit (1 transaction)
await depositBatch(
  receiver,
  [termId1, termId2, termId3],
  [curveId, curveId, curveId],
  [assets1, assets2, assets3],
  [minShares1, minShares2, minShares3]
);
```

### Simulate Without Gas

Use `staticCall` to test transactions without spending gas:

```javascript
// Simulate deposit to check for errors
try {
  const shares = await multiVault.deposit.staticCall(
    receiver,
    termId,
    curveId,
    minShares,
    { value: assets }
  );
  console.log(`Simulation successful, would receive ${shares} shares`);
} catch (error) {
  console.error('Simulation failed:', error.message);
  // Don't send the real transaction
}
```

## Advanced Topics

### Working with Atom Wallets

Each atom has an associated ERC-4337 smart wallet. Query the wallet address:

```javascript
// Get atom wallet address
const atomWallet = await multiVault.getAtomWallet(atomId);

// Check atom wallet owner
const ATOM_WARDEN_ADDRESS = '0x...'; // From deployment addresses
const atomWarden = new ethers.Contract(ATOM_WARDEN_ADDRESS, ATOM_WARDEN_ABI, provider);
const owner = await atomWarden.getAtomWalletOwner(atomId);

console.log(`Atom Wallet: ${atomWallet}`);
console.log(`Owner: ${owner}`);
```

### Claim Atom Wallet Deposit Fees

If you own an atom wallet, you can claim accumulated fees:

```javascript
// Query claimable fees
const claimableFees = await multiVault.getAtomWalletDepositFees(atomId);
console.log(`Claimable fees: ${ethers.formatEther(claimableFees)} ETH`);

// Claim fees
if (claimableFees > 0n) {
  const tx = await multiVault.claimAtomWalletDepositFees(atomId);
  await tx.wait();
  console.log('Fees claimed!');
}
```

### Query Utilization Metrics

For rewards calculations, query utilization:

```javascript
const TRUST_BONDING_ADDRESS = '0x2B0c2700BB0E9Ea294c7c6Ea5C5c42cC0dba3583';
const trustBonding = new ethers.Contract(TRUST_BONDING_ADDRESS, TRUST_BONDING_ABI, provider);

// Get current epoch
const currentEpoch = await trustBonding.currentEpoch();

// Get personal utilization
const personalUtil = await multiVault.getUserUtilizationForEpoch(userAddress, currentEpoch);

// Get system utilization
const systemUtil = await multiVault.getTotalUtilizationForEpoch(currentEpoch);

console.log(`Personal Utilization: ${personalUtil}`);
console.log(`System Utilization: ${systemUtil}`);
```

## Testing

### Local Testing with Anvil

```bash
# Start local fork
anvil --fork-url YOUR_INTUITION_RPC

# In another terminal, run your script
node your-script.js
```

### Testnet Testing

Use Intuition's testnet for development:
- Testnet RPC: Contact Intuition team
- Faucet: Available through Intuition team

## Next Steps

Now that you understand ABI-level integration:

1. **Learn Core Concepts**: Read [Atoms and Triples](../concepts/atoms-and-triples.md) for deeper understanding
2. **Explore Advanced Features**: See [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
3. **Understand Rewards**: Check [Emissions System](../concepts/emissions-system.md)
4. **Review Integration Patterns**: See [SDK Design Patterns](../integration/sdk-design-patterns.md)
5. **Study Complete Examples**: Browse [Code Examples](../examples/)

## Reference

### Key Contract Addresses

See [Deployment Addresses](./deployment-addresses.md) for the complete list.

### Important Function Signatures

**MultiVault Core**:
- `createAtoms(bytes[], uint256[]) payable returns (bytes32[])`
- `createTriples(bytes32[], bytes32[], bytes32[], uint256[]) payable returns (bytes32[])`
- `deposit(address, bytes32, uint256, uint256) payable returns (uint256)`
- `redeem(address, bytes32, uint256, uint256, uint256) returns (uint256)`
- `depositBatch(address, bytes32[], uint256[], uint256[], uint256[]) payable returns (uint256[])`
- `redeemBatch(address, bytes32[], uint256[], uint256[], uint256[]) returns (uint256[])`

**MultiVault Queries**:
- `getVault(bytes32, uint256) view returns (uint256, uint256)`
- `getShares(address, bytes32, uint256) view returns (uint256)`
- `isTermCreated(bytes32) view returns (bool)`
- `currentSharePrice(bytes32, uint256) view returns (uint256)`
- `previewDeposit(bytes32, uint256, uint256) view returns (uint256, uint256)`
- `previewRedeem(bytes32, uint256, uint256) view returns (uint256, uint256)`

### Event Reference

See [Events Reference](../reference/events.md) for complete event documentation.

## Troubleshooting

### Transaction Reverts Without Clear Error

1. Check contract is not paused: `await multiVault.paused()`
2. Verify term exists: `await multiVault.isTermCreated(termId)`
3. Check sufficient balance and allowances
4. Use `staticCall` to get revert reason

### Events Not Appearing

1. Ensure transaction succeeded: `receipt.status === 1`
2. Check correct contract emitted the event
3. Verify event name spelling
4. Use indexed parameters for filtering

### Gas Estimation Fails

1. Validate all parameters
2. Check transaction would succeed with `staticCall`
3. Ensure sufficient balance for value + gas
4. Try with explicit gas limit

## See Also

- [Quick Start for SDK Builders](./quickstart-sdk.md) - TypeScript SDK integration
- [Architecture Overview](./architecture.md) - System design
- [Contract Reference](../contracts/) - Detailed contract documentation
- [Integration Guides](../guides/) - Step-by-step tutorials
- [GLOSSARY](../GLOSSARY.md) - Term definitions

---

**Last Updated**: December 2025
