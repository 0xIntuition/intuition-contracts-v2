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
- Familiarity with sending native tokens via payable functions
- Understanding of [atoms and their role in the protocol](../concepts/atoms-and-triples.md)

### Contracts Needed
- **MultiVault**: Main contract for creating atoms
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`

### Tokens Required
- Native TRUST for the initial deposit (sent as msg.value)
- Native ETH for gas fees

### Key Parameters
- `atomData`: Bytes array (max 256 bytes) containing the atom's data
- `assets`: Amount of TRUST to deposit (must meet minimum deposit requirement)

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
const atomData = toBytes("verified-developer");

// Address data
const atomData = getBytes("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb");

// JSON data
const atomData = toBytes(JSON.stringify({
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

### Step 3: Preview Atom Creation

Simulate the creation to see expected shares and fees before executing.

```typescript
const [shares, assetsAfterFixedFees, assetsAfterFees] =
  await multiVault.previewAtomCreate(atomId, assetsToDeposit);
```

### Step 4: Create the Atom

Call `createAtoms` with your atom data and deposit amount, sending native TRUST via the value parameter. This function accepts arrays for batch creation.

```typescript
const tx = await multiVault.createAtoms(
  [atomData],      // Array of atom data
  [assetsToDeposit], // Array of deposit amounts
  {
    value: assetsToDeposit // Send native TRUST with transaction
  }
);
const receipt = await tx.wait();
```

### Step 5: Extract Atom ID from Events

Parse the `AtomCreated` event to get the atom ID and wallet address.

```typescript
const atomCreatedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event.name === 'AtomCreated');

const atomId = atomCreatedEvent.args.termId;
const atomWallet = atomCreatedEvent.args.atomWallet;
```

## Code Examples

### TypeScript (viem)

Complete example with error handling and event monitoring:

```typescript
import { createPublicClient, createWalletClient, http, parseEther, formatEther, toBytes } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// Contract ABIs (import from your ABI files)
import MultiVaultABI from './abis/IMultiVault.json';
import ERC20ABI from './abis/ERC20.json';

// Configuration
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

/**
 * Creates a single atom with initial deposit
 */
async function createAtom(
  atomDataString: string,
  depositAmount: bigint,
  privateKey: `0x${string}`
): Promise<{
  atomId: string;
  atomWallet: string;
  sharesMinted: bigint;
  txHash: string;
}> {
  // Setup account and clients
  const account = privateKeyToAccount(privateKey);

  const publicClient = createPublicClient({
    chain: base,
    transport: http(RPC_URL)
  });

  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(RPC_URL)
  });

  try {
    // Step 1: Encode atom data
    const atomData = toBytes(atomDataString);

    // Validate data length
    if (atomData.length > 256) {
      throw new Error(`Atom data exceeds 256 bytes (got ${atomData.length})`);
    }

    // Step 2: Calculate atom ID (deterministic)
    const atomId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: MultiVaultABI,
      functionName: 'calculateAtomId',
      args: [atomData]
    }) as `0x${string}`;
    console.log('Computed Atom ID:', atomId);

    // Step 3: Check if atom already exists
    const isCreated = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: MultiVaultABI,
      functionName: 'isTermCreated',
      args: [atomId]
    }) as boolean;

    if (isCreated) {
      throw new Error(`Atom already exists with ID: ${atomId}`);
    }

    // Step 4: Get atom creation costs
    const atomCost = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: MultiVaultABI,
      functionName: 'getAtomCost'
    }) as bigint;

    const generalConfig = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: MultiVaultABI,
      functionName: 'getGeneralConfig'
    }) as any;

    const minDeposit = generalConfig.minDeposit || generalConfig[4];
    const minimumRequired = atomCost + minDeposit;

    console.log('Atom creation cost:', formatEther(atomCost), 'TRUST');
    console.log('Minimum deposit:', formatEther(minDeposit), 'TRUST');
    console.log('Total minimum:', formatEther(minimumRequired), 'TRUST');

    // Validate deposit amount
    if (depositAmount < minimumRequired) {
      throw new Error(
        `Deposit amount ${formatEther(depositAmount)} is below minimum ` +
        `${formatEther(minimumRequired)} TRUST`
      );
    }

    // Step 5: Preview the creation
    const [expectedShares, assetsAfterFixedFees, assetsAfterAllFees] =
      await publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: MultiVaultABI,
        functionName: 'previewAtomCreate',
        args: [atomId, depositAmount]
      }) as [bigint, bigint, bigint];

    console.log('Expected shares:', formatEther(expectedShares));
    console.log('Assets after fixed fees:', formatEther(assetsAfterFixedFees));
    console.log('Assets after all fees:', formatEther(assetsAfterAllFees));

    // Step 6: Create the atom
    console.log('Creating atom...');
    const createHash = await walletClient.writeContract({
      address: MULTIVAULT_ADDRESS,
      abi: MultiVaultABI,
      functionName: 'createAtoms',
      args: [[atomData], [depositAmount]],
      value: depositAmount,
      gas: 500000n
    });

    console.log('Transaction sent:', createHash);
    const receipt = await publicClient.waitForTransactionReceipt({ hash: createHash });
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 7: Parse events
    const atomCreatedEvents = publicClient.parseEventLogs({
      abi: MultiVaultABI,
      logs: receipt.logs,
      eventName: 'AtomCreated'
    });

    const depositedEvents = publicClient.parseEventLogs({
      abi: MultiVaultABI,
      logs: receipt.logs,
      eventName: 'Deposited'
    });

    if (atomCreatedEvents.length === 0) {
      throw new Error('AtomCreated event not found in receipt');
    }

    const atomWalletAddress = atomCreatedEvents[0].args.atomWallet as string;
    const sharesMinted = depositedEvents.length > 0 ? depositedEvents[0].args.shares as bigint : 0n;

    console.log('Atom created:', atomCreatedEvents[0].args.termId);
    console.log('Atom wallet:', atomWalletAddress);
    console.log('Shares minted:', formatEther(sharesMinted));

    return {
      atomId: atomId,
      atomWallet: atomWalletAddress,
      sharesMinted: sharesMinted,
      txHash: createHash
    };

  } catch (error) {
    // Handle specific errors
    if (error.message?.includes('insufficient funds')) {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.message?.includes('execution reverted')) {
      throw new Error(`Contract call failed: ${error.message}`);
    }

    throw error;
  }
}

// Usage example
async function main() {
  try {
    const result = await createAtom(
      "verified-developer",
      parseEther("10"), // 10 TRUST
      "0xYourPrivateKey" as `0x${string}`
    );

    console.log('\nAtom creation successful!');
    console.log('Atom ID:', result.atomId);
    console.log('Atom Wallet:', result.atomWallet);
    console.log('Shares Minted:', formatEther(result.sharesMinted));
    console.log('Transaction:', result.txHash);
  } catch (error) {
    console.error('Error creating atom:', error.message);
    process.exit(1);
  }
}

main();
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
        deposit_amount: Amount of TRUST to deposit (in wei)
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

        print(f'Atom creation cost: {Web3.from_wei(atom_cost, "ether")} TRUST')
        print(f'Minimum deposit: {Web3.from_wei(min_deposit, "ether")} TRUST')
        print(f'Total minimum: {Web3.from_wei(minimum_required, "ether")} TRUST')

        # Validate deposit amount
        if deposit_amount < minimum_required:
            raise ValueError(
                f'Deposit amount {Web3.from_wei(deposit_amount, "ether")} is below '
                f'minimum {Web3.from_wei(minimum_required, "ether")} TRUST'
            )

        # Step 5: Preview the creation
        preview = multivault.functions.previewAtomCreate(
            atom_id,
            deposit_amount
        ).call()
        expected_shares, assets_after_fixed_fees, assets_after_all_fees = preview

        print(f'Expected shares: {Web3.from_wei(expected_shares, "ether")}')
        print(f'Assets after fixed fees: {Web3.from_wei(assets_after_fixed_fees, "ether")}')
        print(f'Assets after all fees: {Web3.from_wei(assets_after_all_fees, "ether")}')

        # Step 6: Create the atom
        print('Creating atom...')

        # Build transaction
        create_tx = multivault.functions.createAtoms(
            [atom_data],
            [deposit_amount]
        ).build_transaction({
            'from': account.address,
            'value': deposit_amount,
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
            deposit_amount=Web3.to_wei(10, 'ether'),  # 10 TRUST
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

**Error**: `Insufficient funds`

**Cause**: Not enough native TRUST sent with transaction.

**Recovery**:
- Ensure value parameter matches deposit amount
- Check wallet balance has sufficient TRUST

#### 5. Insufficient Balance

**Error**: `Value mismatch`

**Cause**: msg.value doesn't match deposit amount parameter.

**Recovery**:
- Ensure value in transaction options matches deposit amount
- For batch creates, value should equal sum of all deposits

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
  } else if (error.message.includes('insufficient funds')) {
    // Ensure correct value is being sent
    console.error('Not enough TRUST sent with transaction');
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

### 1. Forgetting to Send Value

Always include value parameter when calling `createAtoms`:

```typescript
// WRONG: Will fail with "insufficient funds"
await multiVault.createAtoms([data], [amount]);

// CORRECT: Include value parameter
await multiVault.createAtoms([data], [amount], { value: amount });
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
await createAtom(data, parseEther("1"));

// CORRECT: Query minimum and ensure compliance
const min = await multiVault.getAtomCost() +
            await multiVault.getGeneralConfig().then(c => c.minDeposit);
const deposit = min > parseEther("1") ? min : parseEther("1");
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
