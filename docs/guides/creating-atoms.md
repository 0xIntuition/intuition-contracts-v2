# Creating Atoms

## Overview

Atoms are the fundamental units of data in the Intuition Protocol. Creating an atom involves encoding data (up to 256 bytes) on-chain and establishing a vault with an initial deposit. Each atom gets a unique deterministic ID and an associated ERC-4337 smart wallet.

This guide shows you how to create atoms programmatically using TypeScript and Python.

**When to use this operation**:
- Registering new entities or concepts on-chain
- Creating identity claims or attestations
- Establishing new data primitives for triples
- Building a knowledge graph node

## Prerequisites

### Required Knowledge
- Basic understanding of Ethereum transactions
- Familiarity with ERC20 token approvals
- Understanding of [atoms and their role in the protocol](../concepts/atoms-and-triples.md)

### Contracts Needed
- **MultiVault**: Main contract for creating atoms
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`
- **WrappedTrust (WTRUST)**: Asset token for deposits
  - Mainnet: `0x81cFb09cb44f7184Ad934C09F82000701A4bF672`
  - Testnet: `0xDE80b6EE63f7D809427CA350e30093F436A0fe35`

### Tokens Required
- WTRUST tokens for the initial deposit
- Native ETH for gas fees
- Sufficient approval for MultiVault to spend WTRUST

### Key Parameters
- `atomData`: Bytes array (max 256 bytes) containing the atom's data
- `assets`: Amount of WTRUST to deposit (must meet minimum deposit requirement)

## Step-by-Step Guide

### Step 1: Prepare Atom Data

Encode your data as bytes. The atom ID will be computed as `keccak256(SALT + keccak256(atomData))`, ensuring uniqueness.

**Data Format Options**:
- UTF-8 encoded string
- Ethereum address (0x-prefixed)
- Structured JSON (encoded as bytes)
- IPFS CID
- Any arbitrary bytes (≤256 bytes)

**Example data types**:
```typescript
// String data
const atomData = ethers.toUtf8Bytes("verified-developer");

// Address data
const atomData = ethers.getBytes("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb");

// JSON data
const atomData = ethers.toUtf8Bytes(JSON.stringify({
  type: "person",
  name: "Alice"
}));
```

### Step 2: Check Atom Cost

Query the protocol's atom creation cost to determine the minimum deposit required.

```typescript
const atomCost = await multiVault.getAtomCost();
const minDeposit = await multiVault.getGeneralConfig().then(c => c.minDeposit);
const requiredDeposit = atomCost + minDeposit;
```

### Step 3: Approve WTRUST Spending

The MultiVault contract needs approval to spend your WTRUST tokens.

```typescript
const tx = await wtrustContract.approve(
  multiVaultAddress,
  assetsToDeposit
);
await tx.wait();
```

### Step 4: Preview Atom Creation

Simulate the creation to see expected shares and fees before executing.

```typescript
const [shares, assetsAfterFixedFees, assetsAfterFees] =
  await multiVault.previewAtomCreate(atomId, assetsToDeposit);
```

### Step 5: Create the Atom

Call `createAtoms` with your atom data and deposit amount. This function accepts arrays for batch creation.

```typescript
const tx = await multiVault.createAtoms(
  [atomData],      // Array of atom data
  [assetsToDeposit] // Array of deposit amounts
);
const receipt = await tx.wait();
```

### Step 6: Extract Atom ID from Events

Parse the `AtomCreated` event to get the atom ID and wallet address.

```typescript
const atomCreatedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event.name === 'AtomCreated');

const atomId = atomCreatedEvent.args.termId;
const atomWallet = atomCreatedEvent.args.atomWallet;
```

## Code Examples

### TypeScript (ethers.js v6)

Complete example with error handling and event monitoring:

```typescript
import { ethers } from 'ethers';

// Contract ABIs (import from your ABI files)
import MultiVaultABI from './abis/IMultiVault.json';
import ERC20ABI from './abis/ERC20.json';

// Configuration
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

/**
 * Creates a single atom with initial deposit
 */
async function createAtom(
  atomDataString: string,
  depositAmount: bigint,
  privateKey: string
): Promise<{
  atomId: string;
  atomWallet: string;
  sharesMinted: bigint;
  txHash: string;
}> {
  // Setup provider and signer
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);

  // Contract instances
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MultiVaultABI,
    wallet
  );
  const wtrust = new ethers.Contract(
    WTRUST_ADDRESS,
    ERC20ABI,
    wallet
  );

  try {
    // Step 1: Encode atom data
    const atomData = ethers.toUtf8Bytes(atomDataString);

    // Validate data length
    if (atomData.length > 256) {
      throw new Error(`Atom data exceeds 256 bytes (got ${atomData.length})`);
    }

    // Step 2: Calculate atom ID (deterministic)
    const atomId = await multiVault.calculateAtomId(atomData);
    console.log('Computed Atom ID:', atomId);

    // Step 3: Check if atom already exists
    const isCreated = await multiVault.isTermCreated(atomId);
    if (isCreated) {
      throw new Error(`Atom already exists with ID: ${atomId}`);
    }

    // Step 4: Get atom creation costs
    const atomConfig = await multiVault.getAtomConfig();
    const generalConfig = await multiVault.getGeneralConfig();

    const atomCost = await multiVault.getAtomCost();
    const minDeposit = generalConfig.minDeposit;
    const minimumRequired = atomCost + minDeposit;

    console.log('Atom creation cost:', ethers.formatEther(atomCost), 'WTRUST');
    console.log('Minimum deposit:', ethers.formatEther(minDeposit), 'WTRUST');
    console.log('Total minimum:', ethers.formatEther(minimumRequired), 'WTRUST');

    // Validate deposit amount
    if (depositAmount < minimumRequired) {
      throw new Error(
        `Deposit amount ${ethers.formatEther(depositAmount)} is below minimum ` +
        `${ethers.formatEther(minimumRequired)} WTRUST`
      );
    }

    // Step 5: Check WTRUST balance
    const balance = await wtrust.balanceOf(wallet.address);
    if (balance < depositAmount) {
      throw new Error(
        `Insufficient WTRUST balance. Have: ${ethers.formatEther(balance)}, ` +
        `Need: ${ethers.formatEther(depositAmount)}`
      );
    }

    // Step 6: Preview the creation
    const [expectedShares, assetsAfterFixedFees, assetsAfterAllFees] =
      await multiVault.previewAtomCreate(atomId, depositAmount);

    console.log('Expected shares:', ethers.formatEther(expectedShares));
    console.log('Assets after fixed fees:', ethers.formatEther(assetsAfterFixedFees));
    console.log('Assets after all fees:', ethers.formatEther(assetsAfterAllFees));

    // Step 7: Approve WTRUST spending
    console.log('Approving WTRUST spending...');
    const approveTx = await wtrust.approve(MULTIVAULT_ADDRESS, depositAmount);
    await approveTx.wait();
    console.log('Approval confirmed');

    // Step 8: Create the atom
    console.log('Creating atom...');
    const createTx = await multiVault.createAtoms(
      [atomData],
      [depositAmount],
      {
        gasLimit: 500000n // Explicit gas limit for safety
      }
    );

    console.log('Transaction sent:', createTx.hash);
    const receipt = await createTx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 9: Parse events
    let atomCreatedEvent = null;
    let depositedEvent = null;
    let sharesMinted = 0n;
    let atomWalletAddress = '';

    for (const log of receipt.logs) {
      try {
        const parsed = multiVault.interface.parseLog({
          topics: log.topics,
          data: log.data
        });

        if (parsed.name === 'AtomCreated') {
          atomCreatedEvent = parsed;
          atomWalletAddress = parsed.args.atomWallet;
          console.log('Atom created:', parsed.args.termId);
          console.log('Atom wallet:', atomWalletAddress);
        } else if (parsed.name === 'Deposited') {
          depositedEvent = parsed;
          sharesMinted = parsed.args.shares;
          console.log('Shares minted:', ethers.formatEther(sharesMinted));
        }
      } catch (e) {
        // Not a MultiVault event, skip
      }
    }

    if (!atomCreatedEvent) {
      throw new Error('AtomCreated event not found in receipt');
    }

    return {
      atomId: atomId,
      atomWallet: atomWalletAddress,
      sharesMinted: sharesMinted,
      txHash: receipt.hash
    };

  } catch (error) {
    // Handle specific errors
    if (error.code === 'INSUFFICIENT_FUNDS') {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.code === 'CALL_EXCEPTION') {
      throw new Error(`Contract call failed: ${error.reason || error.message}`);
    } else if (error.code === 'NETWORK_ERROR') {
      throw new Error('Network connection error. Please check RPC endpoint.');
    }

    throw error;
  }
}

// Usage example
async function main() {
  try {
    const result = await createAtom(
      "verified-developer",
      ethers.parseEther("10"), // 10 WTRUST
      "YOUR_PRIVATE_KEY"
    );

    console.log('\nAtom creation successful!');
    console.log('Atom ID:', result.atomId);
    console.log('Atom Wallet:', result.atomWallet);
    console.log('Shares Minted:', ethers.formatEther(result.sharesMinted));
    console.log('Transaction:', result.txHash);
  } catch (error) {
    console.error('Error creating atom:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}
```

### Python (web3.py)

Complete example with error handling:

```python
from web3 import Web3
from eth_account import Account
from typing import Dict, Tuple
import json

# Configuration
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672'
RPC_URL = 'YOUR_INTUITION_RPC_URL'

# Load ABIs (from your ABI files)
with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)

with open('abis/ERC20.json') as f:
    ERC20_ABI = json.load(f)


def create_atom(
    atom_data_string: str,
    deposit_amount: int,
    private_key: str
) -> Dict[str, any]:
    """
    Creates a single atom with initial deposit

    Args:
        atom_data_string: String data to encode in the atom
        deposit_amount: Amount of WTRUST to deposit (in wei)
        private_key: Private key for signing transactions

    Returns:
        Dictionary containing atom_id, atom_wallet, shares_minted, and tx_hash

    Raises:
        ValueError: If parameters are invalid
        Exception: If transaction fails
    """
    # Setup Web3
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    if not w3.is_connected():
        raise Exception('Failed to connect to RPC endpoint')

    # Setup account
    account = Account.from_key(private_key)

    # Contract instances
    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )
    wtrust = w3.eth.contract(
        address=Web3.to_checksum_address(WTRUST_ADDRESS),
        abi=ERC20_ABI
    )

    try:
        # Step 1: Encode atom data
        atom_data = atom_data_string.encode('utf-8')

        # Validate data length
        if len(atom_data) > 256:
            raise ValueError(f'Atom data exceeds 256 bytes (got {len(atom_data)})')

        # Step 2: Calculate atom ID (deterministic)
        atom_id = multivault.functions.calculateAtomId(atom_data).call()
        print(f'Computed Atom ID: {atom_id.hex()}')

        # Step 3: Check if atom already exists
        is_created = multivault.functions.isTermCreated(atom_id).call()
        if is_created:
            raise ValueError(f'Atom already exists with ID: {atom_id.hex()}')

        # Step 4: Get atom creation costs
        atom_cost = multivault.functions.getAtomCost().call()
        general_config = multivault.functions.getGeneralConfig().call()
        min_deposit = general_config[4]  # minDeposit field
        minimum_required = atom_cost + min_deposit

        print(f'Atom creation cost: {Web3.from_wei(atom_cost, "ether")} WTRUST')
        print(f'Minimum deposit: {Web3.from_wei(min_deposit, "ether")} WTRUST')
        print(f'Total minimum: {Web3.from_wei(minimum_required, "ether")} WTRUST')

        # Validate deposit amount
        if deposit_amount < minimum_required:
            raise ValueError(
                f'Deposit amount {Web3.from_wei(deposit_amount, "ether")} is below '
                f'minimum {Web3.from_wei(minimum_required, "ether")} WTRUST'
            )

        # Step 5: Check WTRUST balance
        balance = wtrust.functions.balanceOf(account.address).call()
        if balance < deposit_amount:
            raise ValueError(
                f'Insufficient WTRUST balance. Have: {Web3.from_wei(balance, "ether")}, '
                f'Need: {Web3.from_wei(deposit_amount, "ether")}'
            )

        # Step 6: Preview the creation
        preview = multivault.functions.previewAtomCreate(
            atom_id,
            deposit_amount
        ).call()
        expected_shares, assets_after_fixed_fees, assets_after_all_fees = preview

        print(f'Expected shares: {Web3.from_wei(expected_shares, "ether")}')
        print(f'Assets after fixed fees: {Web3.from_wei(assets_after_fixed_fees, "ether")}')
        print(f'Assets after all fees: {Web3.from_wei(assets_after_all_fees, "ether")}')

        # Step 7: Approve WTRUST spending
        print('Approving WTRUST spending...')
        approve_tx = wtrust.functions.approve(
            MULTIVAULT_ADDRESS,
            deposit_amount
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })

        signed_approve = account.sign_transaction(approve_tx)
        approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
        approve_receipt = w3.eth.wait_for_transaction_receipt(approve_hash)

        if approve_receipt['status'] != 1:
            raise Exception('Approval transaction failed')
        print('Approval confirmed')

        # Step 8: Create the atom
        print('Creating atom...')

        # Build transaction
        create_tx = multivault.functions.createAtoms(
            [atom_data],
            [deposit_amount]
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })

        # Sign and send
        signed_create = account.sign_transaction(create_tx)
        create_hash = w3.eth.send_raw_transaction(signed_create.raw_transaction)
        print(f'Transaction sent: {create_hash.hex()}')

        # Wait for confirmation
        receipt = w3.eth.wait_for_transaction_receipt(create_hash)
        print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

        if receipt['status'] != 1:
            raise Exception('Atom creation transaction failed')

        # Step 9: Parse events
        atom_wallet_address = ''
        shares_minted = 0

        # Parse AtomCreated event
        atom_created_events = multivault.events.AtomCreated().process_receipt(receipt)
        if atom_created_events:
            atom_wallet_address = atom_created_events[0]['args']['atomWallet']
            print(f'Atom created: {atom_created_events[0]["args"]["termId"].hex()}')
            print(f'Atom wallet: {atom_wallet_address}')

        # Parse Deposited event
        deposited_events = multivault.events.Deposited().process_receipt(receipt)
        if deposited_events:
            shares_minted = deposited_events[0]['args']['shares']
            print(f'Shares minted: {Web3.from_wei(shares_minted, "ether")}')

        if not atom_created_events:
            raise Exception('AtomCreated event not found in receipt')

        return {
            'atom_id': atom_id.hex(),
            'atom_wallet': atom_wallet_address,
            'shares_minted': shares_minted,
            'tx_hash': receipt['transactionHash'].hex()
        }

    except ValueError as e:
        raise ValueError(f'Validation error: {str(e)}')
    except Exception as e:
        if 'insufficient funds' in str(e).lower():
            raise Exception('Insufficient ETH for gas fees')
        elif 'revert' in str(e).lower():
            raise Exception(f'Contract call reverted: {str(e)}')
        raise


# Usage example
if __name__ == '__main__':
    try:
        result = create_atom(
            atom_data_string='verified-developer',
            deposit_amount=Web3.to_wei(10, 'ether'),  # 10 WTRUST
            private_key='YOUR_PRIVATE_KEY'
        )

        print('\nAtom creation successful!')
        print(f'Atom ID: {result["atom_id"]}')
        print(f'Atom Wallet: {result["atom_wallet"]}')
        print(f'Shares Minted: {Web3.from_wei(result["shares_minted"], "ether")}')
        print(f'Transaction: {result["tx_hash"]}')

    except Exception as e:
        print(f'Error creating atom: {str(e)}')
        exit(1)
```

## Event Monitoring

### Events Emitted

When creating an atom, the following events are emitted:

#### 1. AtomCreated

```solidity
event AtomCreated(
    address indexed creator,
    bytes32 indexed termId,
    bytes atomData,
    address atomWallet
);
```

**Parameters**:
- `creator`: Address that created the atom
- `termId`: Unique atom ID
- `atomData`: Raw bytes data stored in the atom
- `atomWallet`: Address of the created atom wallet

#### 2. Deposited

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
- `sender`: Address that sent the assets
- `receiver`: Address receiving the shares
- `termId`: Atom ID
- `curveId`: Bonding curve ID used (typically 1 for linear)
- `assets`: Gross assets deposited
- `assetsAfterFees`: Net assets after fee deductions
- `shares`: Shares minted to receiver
- `totalShares`: Receiver's total share balance
- `vaultType`: Will be `VaultType.ATOM` (0)

#### 3. AtomWalletDepositFeeCollected

```solidity
event AtomWalletDepositFeeCollected(
    bytes32 indexed termId,
    address indexed sender,
    uint256 amount
);
```

**Parameters**:
- `termId`: Atom ID
- `sender`: Address that paid the fee
- `amount`: Fee amount collected for atom wallet owner

### Listening for Events

**TypeScript**:
```typescript
// Listen for AtomCreated events
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet, event) => {
  console.log('New atom created:');
  console.log('  Creator:', creator);
  console.log('  Atom ID:', termId);
  console.log('  Atom Wallet:', atomWallet);
  console.log('  Block:', event.log.blockNumber);
});

// Query historical events
const filter = multiVault.filters.AtomCreated(myAddress);
const events = await multiVault.queryFilter(filter, -10000); // Last 10k blocks
```

**Python**:
```python
# Create event filter
event_filter = multivault.events.AtomCreated.create_filter(
    from_block='latest'
)

# Poll for new events
while True:
    for event in event_filter.get_new_entries():
        print(f'New atom created:')
        print(f'  Creator: {event["args"]["creator"]}')
        print(f'  Atom ID: {event["args"]["termId"].hex()}')
        print(f'  Atom Wallet: {event["args"]["atomWallet"]}')

    time.sleep(12)  # Poll every 12 seconds
```

## Error Handling

### Common Errors

#### 1. Atom Already Exists

**Error**: `MultiVaultCore_AtomExists()`

**Cause**: Attempting to create an atom with data that already exists on-chain.

**Recovery**:
- Check if atom exists before creating: `isTermCreated(atomId)`
- If it exists, deposit into the existing vault instead
- Use different atom data if you need a new atom

#### 2. Insufficient Deposit

**Error**: `MultiVaultCore_DepositBelowMinimum()`

**Cause**: Deposit amount is below the minimum required (atomCost + minDeposit).

**Recovery**:
- Query `getAtomCost()` and `getGeneralConfig().minDeposit`
- Ensure deposit amount ≥ sum of both values
- Increase deposit amount

#### 3. Atom Data Too Long

**Error**: `MultiVaultCore_AtomDataTooLong()`

**Cause**: Atom data exceeds 256 bytes.

**Recovery**:
- Check data length before encoding
- Use hash or IPFS CID if data is large
- Compress or truncate data

#### 4. Insufficient Allowance

**Error**: `ERC20: insufficient allowance`

**Cause**: MultiVault not approved to spend enough WTRUST.

**Recovery**:
- Call `approve()` on WTRUST contract
- Approve at least the deposit amount
- Check current allowance: `allowance(owner, spender)`

#### 5. Insufficient Balance

**Error**: `ERC20: transfer amount exceeds balance`

**Cause**: Not enough WTRUST tokens in wallet.

**Recovery**:
- Check balance: `balanceOf(address)`
- Acquire more WTRUST tokens
- Reduce deposit amount

#### 6. Paused Contract

**Error**: `Pausable: paused`

**Cause**: Protocol is paused for emergency maintenance.

**Recovery**:
- Wait for protocol to be unpaused
- Monitor protocol announcements
- Check pause status before transactions

### Error Handling Pattern

```typescript
try {
  const result = await createAtom(data, amount, privateKey);
} catch (error) {
  if (error.message.includes('AtomExists')) {
    // Atom already created, deposit instead
    const atomId = await calculateAtomId(data);
    await depositToAtom(atomId, amount);
  } else if (error.message.includes('DepositBelowMinimum')) {
    // Increase deposit amount
    const minRequired = await getMinimumDeposit();
    await createAtom(data, minRequired, privateKey);
  } else if (error.message.includes('insufficient allowance')) {
    // Approve and retry
    await approveWTRUST(amount);
    await createAtom(data, amount, privateKey);
  } else {
    // Unknown error, log and alert
    console.error('Atom creation failed:', error);
    throw error;
  }
}
```

## Gas Estimation

### Typical Gas Costs

Operation costs on Intuition Mainnet (approximate):

| Operation | Gas Used | Notes |
|-----------|----------|-------|
| Single atom creation | ~400,000 | Includes wallet deployment |
| Batch (2 atoms) | ~650,000 | Saves ~150k vs 2 separate txs |
| Batch (5 atoms) | ~1,400,000 | Scales sub-linearly |
| WTRUST approval | ~50,000 | One-time per contract |

### Factors Affecting Cost

1. **First-time wallet deployment**: Higher gas if atom wallet doesn't exist
2. **Batch size**: Larger batches are more gas-efficient per atom
3. **Network congestion**: Gas price fluctuates with demand
4. **Data size**: Larger atom data = slightly higher gas

### Gas Optimization Tips

```typescript
// 1. Use batch creation for multiple atoms
const atomIds = await multiVault.createAtoms(
  [data1, data2, data3],
  [amount1, amount2, amount3]
); // More efficient than 3 separate calls

// 2. Estimate gas before sending
const gasEstimate = await multiVault.createAtoms.estimateGas(
  [atomData],
  [depositAmount]
);
const gasLimit = gasEstimate * 120n / 100n; // Add 20% buffer

// 3. Use legacy transactions if EIP-1559 is expensive
const tx = await multiVault.createAtoms([data], [amount], {
  gasPrice: await provider.getGasPrice(),
  gasLimit: gasLimit
});
```

## Best Practices

### 1. Validate Before Creating

```typescript
// Check atom doesn't exist
const atomId = await multiVault.calculateAtomId(atomData);
if (await multiVault.isTermCreated(atomId)) {
  throw new Error('Atom already exists');
}

// Validate data length
if (atomData.length > 256) {
  throw new Error('Atom data too long');
}

// Check minimum deposit
const minRequired = await getMinimumRequired();
if (depositAmount < minRequired) {
  throw new Error('Deposit too small');
}
```

### 2. Use Preview Functions

Always preview before executing to verify expected outcomes:

```typescript
const [shares, feesFixed, feesAll] = await multiVault.previewAtomCreate(
  atomId,
  depositAmount
);

// Verify shares meet expectations
if (shares < expectedMinShares) {
  throw new Error('Insufficient shares would be minted');
}
```

### 3. Handle Idempotency

Atom creation is idempotent at the data level - same data always produces same ID:

```typescript
async function getOrCreateAtom(data: Uint8Array, deposit: bigint) {
  const atomId = await multiVault.calculateAtomId(data);

  if (await multiVault.isTermCreated(atomId)) {
    // Atom exists, just return ID
    return { atomId, created: false };
  } else {
    // Create new atom
    const result = await createAtom(data, deposit);
    return { atomId: result.atomId, created: true };
  }
}
```

### 4. Store Atom IDs Off-Chain

Maintain a database mapping of your atoms:

```typescript
interface AtomRecord {
  atomId: string;
  atomData: string;
  atomWallet: string;
  createdAt: Date;
  creator: string;
}

async function createAndStore(data: string, deposit: bigint) {
  const result = await createAtom(data, deposit, privateKey);

  // Store in your database
  await db.atoms.insert({
    atomId: result.atomId,
    atomData: data,
    atomWallet: result.atomWallet,
    createdAt: new Date(),
    creator: wallet.address
  });

  return result;
}
```

### 5. Use Meaningful Data

Design atom data for discoverability and utility:

```typescript
// Good: Structured, descriptive data
const atomData = JSON.stringify({
  type: 'github-username',
  value: 'alice',
  verified: true
});

// Bad: Opaque or meaningless data
const atomData = 'a1b2c3d4';
```

## Common Pitfalls

### 1. Forgetting to Approve

Always approve WTRUST before calling `createAtoms`:

```typescript
// WRONG: Will fail with "insufficient allowance"
await multiVault.createAtoms([data], [amount]);

// CORRECT: Approve first
await wtrust.approve(MULTIVAULT_ADDRESS, amount);
await multiVault.createAtoms([data], [amount]);
```

### 2. Not Checking Existence

Attempting to recreate an existing atom will revert:

```typescript
// WRONG: No existence check
await createAtom(data, amount);

// CORRECT: Check first
const atomId = await multiVault.calculateAtomId(data);
if (!await multiVault.isTermCreated(atomId)) {
  await createAtom(data, amount);
}
```

### 3. Insufficient Gas

Atom creation with wallet deployment uses more gas than expected:

```typescript
// WRONG: Default gas limit might be too low
await multiVault.createAtoms([data], [amount]);

// CORRECT: Explicit gas limit
await multiVault.createAtoms([data], [amount], {
  gasLimit: 500000
});
```

### 4. Ignoring Minimum Deposit

Each atom needs minimum initial deposit:

```typescript
// WRONG: Hardcoded deposit might be too low
await createAtom(data, ethers.parseEther("1"));

// CORRECT: Query minimum and ensure compliance
const min = await multiVault.getAtomCost() +
            await multiVault.getGeneralConfig().then(c => c.minDeposit);
const deposit = min > ethers.parseEther("1") ? min : ethers.parseEther("1");
await createAtom(data, deposit);
```

### 5. Not Handling Events

Parse events to get the atom ID and wallet address:

```typescript
// WRONG: Assuming atom ID without checking events
const atomId = await multiVault.calculateAtomId(data);
// What if transaction failed?

// CORRECT: Parse events to confirm creation
const receipt = await tx.wait();
const event = receipt.logs.find(/* AtomCreated event */);
const atomId = event.args.termId;
```

## Related Operations

### After Creating an Atom

1. **Deposit more assets**: [Depositing Assets Guide](./depositing-assets.md)
2. **Create triples**: Use the atom as subject, predicate, or object - [Creating Triples Guide](./creating-triples.md)
3. **Claim atom wallet**: Transfer ownership if data matches your address - [Wallet Integration Guide](./wallet-integration.md)
4. **Redeem shares**: Exit the position - [Redeeming Shares Guide](./redeeming-shares.md)

### Alternative Approaches

- **Batch creation**: Create multiple atoms in one transaction
- **Create with triple**: Create atom and triple simultaneously
- **Direct vault deposit**: If atom exists, deposit without recreating

## See Also

- [Atoms and Triples Concept](../concepts/atoms-and-triples.md)
- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [Creating Triples Guide](./creating-triples.md)
- [Fee Structure](./fee-structure.md)
- [MultiVault Contract Reference](../contracts/core/MultiVault.md)
- [Batch Operations Guide](./batch-operations.md)

---

**Last Updated**: December 2025
