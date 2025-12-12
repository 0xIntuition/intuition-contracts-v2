# Creating Triples

## Overview

Triples are the relationships in the Intuition Protocol, expressing subject-predicate-object claims between atoms. Creating a triple establishes both a positive vault (the claim) and a counter vault (the negation) with an initial deposit. A fraction of the deposit also flows to the underlying atoms.

This guide shows you how to create triples programmatically using TypeScript and Python.

**When to use this operation**:
- Creating claims or assertions between entities
- Building knowledge graphs on-chain
- Expressing relationships or properties
- Creating verifiable statements

## Prerequisites

### Required Knowledge
- Understanding of [atoms and triples](../concepts/atoms-and-triples.md)
- Basic knowledge of the [multi-vault pattern](../concepts/multi-vault-pattern.md)
- Familiarity with Ethereum transactions

### Contracts Needed
- **MultiVault**: Main contract for creating triples
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`
- **WrappedTrust (WTRUST)**: Asset token for deposits
  - Mainnet: `0x81cFb09cb44f7184Ad934C09F82000701A4bF672`
  - Testnet: `0xDE80b6EE63f7D809427CA350e30093F436A0fe35`

### Tokens Required
- WTRUST tokens for initial deposit
- Native ETH for gas fees
- Sufficient approval for MultiVault

### Key Parameters
- `subjectId`: bytes32 atom ID for the subject
- `predicateId`: bytes32 atom ID for the predicate
- `objectId`: bytes32 atom ID for the object
- `assets`: Amount of WTRUST to deposit

## Step-by-Step Guide

### Step 1: Ensure Atoms Exist

All three atoms (subject, predicate, object) must exist before creating a triple.

```typescript
const atomsExist = await Promise.all([
  multiVault.isTermCreated(subjectId),
  multiVault.isTermCreated(predicateId),
  multiVault.isTermCreated(objectId)
]);

if (!atomsExist.every(exists => exists)) {
  throw new Error('One or more atoms do not exist');
}
```

### Step 2: Calculate Triple ID

Compute the deterministic triple ID from the three atom IDs:

```typescript
const tripleId = await multiVault.calculateTripleId(
  subjectId,
  predicateId,
  objectId
);
```

### Step 3: Check Triple Doesn't Exist

Verify the triple hasn't already been created:

```typescript
const exists = await multiVault.isTermCreated(tripleId);
if (exists) {
  throw new Error('Triple already exists');
}
```

### Step 4: Check Triple Cost

Query the protocol's triple creation cost:

```typescript
const tripleCost = await multiVault.getTripleCost();
const minDeposit = await multiVault.getGeneralConfig().then(c => c.minDeposit);
const requiredDeposit = tripleCost + minDeposit;
```

### Step 5: Understand Atom Deposit Fraction

A portion of your deposit also goes to the three underlying atoms:

```typescript
const tripleConfig = await multiVault.getTripleConfig();
const atomFraction = tripleConfig.atomDepositFractionForTriple;

// Example: If atomFraction is 10% and depositing 100 WTRUST:
// - 10 WTRUST goes to subject atom
// - 10 WTRUST goes to predicate atom
// - 10 WTRUST goes to object atom
// - Remaining ~70 WTRUST (after fees) goes to triple vault
```

### Step 6: Approve WTRUST Spending

Approve the MultiVault to spend your WTRUST:

```typescript
const tx = await wtrustContract.approve(
  multiVaultAddress,
  assetsToDeposit
);
await tx.wait();
```

### Step 7: Preview Triple Creation

Simulate the creation to see expected shares and fees:

```typescript
const [shares, assetsAfterFixedFees, assetsAfterFees] =
  await multiVault.previewTripleCreate(tripleId, assetsToDeposit);
```

### Step 8: Create the Triple

Call `createTriples` with your atom IDs and deposit amount:

```typescript
const tx = await multiVault.createTriples(
  [subjectId],    // Array of subject IDs
  [predicateId],  // Array of predicate IDs
  [objectId],     // Array of object IDs
  [assetsToDeposit] // Array of deposit amounts
);
const receipt = await tx.wait();
```

### Step 9: Extract Triple ID from Events

Parse the `TripleCreated` event:

```typescript
const tripleCreatedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event.name === 'TripleCreated');

const createdTripleId = tripleCreatedEvent.args.termId;
```

## Code Examples

### TypeScript (viem)

Complete example with error handling:

```typescript
import {
  createPublicClient,
  createWalletClient,
  http,
  formatEther,
  parseEther,
  isHex,
  type Hash,
  type Address
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// Contract ABIs
import { multiVaultAbi } from './abis/IMultiVault';
import { erc20Abi } from './abis/ERC20';

// Configuration
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as Address;
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672' as Address;
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

/**
 * Creates a single triple with initial deposit
 */
async function createTriple(
  subjectId: `0x${string}`,
  predicateId: `0x${string}`,
  objectId: `0x${string}`,
  depositAmount: bigint,
  privateKey: `0x${string}`
): Promise<{
  tripleId: `0x${string}`;
  counterTripleId: `0x${string}`;
  sharesMinted: bigint;
  txHash: Hash;
}> {
  // Setup clients
  const publicClient = createPublicClient({
    chain: base,
    transport: http(RPC_URL)
  });

  const account = privateKeyToAccount(privateKey);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(RPC_URL)
  });

  try {
    // Step 1: Validate atom IDs format
    if (!isHex(subjectId, { strict: true }) ||
        !isHex(predicateId, { strict: true }) ||
        !isHex(objectId, { strict: true })) {
      throw new Error('Invalid atom ID format (must be 32-byte hex strings)');
    }

    // Step 2: Check all atoms exist
    console.log('Checking atoms exist...');
    const [subjectExists, predicateExists, objectExists] = await Promise.all([
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'isTermCreated',
        args: [subjectId]
      }),
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'isTermCreated',
        args: [predicateId]
      }),
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'isTermCreated',
        args: [objectId]
      })
    ]);

    if (!subjectExists) {
      throw new Error(`Subject atom ${subjectId} does not exist`);
    }
    if (!predicateExists) {
      throw new Error(`Predicate atom ${predicateId} does not exist`);
    }
    if (!objectExists) {
      throw new Error(`Object atom ${objectId} does not exist`);
    }

    // Step 3: Calculate triple ID
    const tripleId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultAbi,
      functionName: 'calculateTripleId',
      args: [subjectId, predicateId, objectId]
    });
    console.log('Computed Triple ID:', tripleId);

    // Step 4: Calculate counter triple ID
    const counterTripleId = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultAbi,
      functionName: 'getCounterIdFromTripleId',
      args: [tripleId]
    });
    console.log('Counter Triple ID:', counterTripleId);

    // Step 5: Check triple doesn't exist
    const tripleExists = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultAbi,
      functionName: 'isTermCreated',
      args: [tripleId]
    });
    if (tripleExists) {
      throw new Error(`Triple already exists with ID: ${tripleId}`);
    }

    // Step 6: Get triple creation costs
    const [tripleCost, generalConfig, tripleConfig] = await Promise.all([
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'getTripleCost'
      }),
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'getGeneralConfig'
      }),
      publicClient.readContract({
        address: MULTIVAULT_ADDRESS,
        abi: multiVaultAbi,
        functionName: 'getTripleConfig'
      })
    ]);

    const minDeposit = generalConfig.minDeposit;
    const minimumRequired = tripleCost + minDeposit;

    console.log('Triple creation cost:', formatEther(tripleCost), 'WTRUST');
    console.log('Minimum deposit:', formatEther(minDeposit), 'WTRUST');
    console.log('Total minimum:', formatEther(minimumRequired), 'WTRUST');

    // Calculate atom deposit fraction
    const atomFraction = tripleConfig.atomDepositFractionForTriple;
    const feeDenominator = generalConfig.feeDenominator;
    const atomDepositPerAtom = (depositAmount * atomFraction) / feeDenominator;

    console.log('Atom deposit fraction:', atomFraction, '/', feeDenominator);
    console.log('Deposit to each atom:', formatEther(atomDepositPerAtom), 'WTRUST');

    // Validate deposit amount
    if (depositAmount < minimumRequired) {
      throw new Error(
        `Deposit amount ${formatEther(depositAmount)} is below minimum ` +
        `${formatEther(minimumRequired)} WTRUST`
      );
    }

    // Step 7: Check WTRUST balance
    const balance = await publicClient.readContract({
      address: WTRUST_ADDRESS,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [account.address]
    });
    if (balance < depositAmount) {
      throw new Error(
        `Insufficient WTRUST balance. Have: ${formatEther(balance)}, ` +
        `Need: ${formatEther(depositAmount)}`
      );
    }

    // Step 8: Preview the creation
    const previewResult = await publicClient.readContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultAbi,
      functionName: 'previewTripleCreate',
      args: [tripleId, depositAmount]
    });
    const [expectedShares, assetsAfterFixedFees, assetsAfterAllFees] = previewResult;

    console.log('Expected shares:', formatEther(expectedShares));
    console.log('Assets after fixed fees:', formatEther(assetsAfterFixedFees));
    console.log('Assets after all fees:', formatEther(assetsAfterAllFees));

    // Step 9: Approve WTRUST spending
    console.log('Approving WTRUST spending...');
    const approveHash = await walletClient.writeContract({
      address: WTRUST_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve',
      args: [MULTIVAULT_ADDRESS, depositAmount]
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log('Approval confirmed');

    // Step 10: Create the triple
    console.log('Creating triple...');
    const createHash = await walletClient.writeContract({
      address: MULTIVAULT_ADDRESS,
      abi: multiVaultAbi,
      functionName: 'createTriples',
      args: [
        [subjectId],
        [predicateId],
        [objectId],
        [depositAmount]
      ],
      gas: 800000n // Higher gas limit for triple creation
    });

    console.log('Transaction sent:', createHash);
    const receipt = await publicClient.waitForTransactionReceipt({ hash: createHash });
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 11: Parse events
    let sharesMinted = 0n;

    // Parse TripleCreated events
    const tripleCreatedLogs = receipt.logs.filter(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: multiVaultAbi,
          logs: [log],
          eventName: 'TripleCreated'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (tripleCreatedLogs.length > 0) {
      const tripleCreatedEvent = publicClient.parseEventLogs({
        abi: multiVaultAbi,
        logs: tripleCreatedLogs,
        eventName: 'TripleCreated'
      })[0];

      console.log('Triple created:', tripleCreatedEvent.args.termId);
      console.log('Subject:', tripleCreatedEvent.args.subjectId);
      console.log('Predicate:', tripleCreatedEvent.args.predicateId);
      console.log('Object:', tripleCreatedEvent.args.objectId);
    }

    // Parse Deposited events
    const depositedLogs = publicClient.parseEventLogs({
      abi: multiVaultAbi,
      logs: receipt.logs,
      eventName: 'Deposited'
    });

    for (const log of depositedLogs) {
      if (log.args.vaultType === 1) { // VaultType.TRIPLE = 1
        sharesMinted = log.args.shares;
        console.log('Shares minted:', formatEther(sharesMinted));
        break;
      }
    }

    if (tripleCreatedLogs.length === 0) {
      throw new Error('TripleCreated event not found in receipt');
    }

    return {
      tripleId,
      counterTripleId,
      sharesMinted,
      txHash: receipt.transactionHash
    };

  } catch (error) {
    // Handle specific errors
    if (error instanceof Error) {
      if (error.message.includes('insufficient funds')) {
        throw new Error('Insufficient ETH for gas fees');
      } else if (error.message.includes('execution reverted')) {
        throw new Error(`Contract call failed: ${error.message}`);
      }
    }

    throw error;
  }
}

/**
 * Helper: Create atoms and triple in sequence
 */
async function createAtomsAndTriple(
  subjectData: string,
  predicateData: string,
  objectData: string,
  atomDeposit: bigint,
  tripleDeposit: bigint,
  privateKey: `0x${string}`
) {
  const publicClient = createPublicClient({
    chain: base,
    transport: http(RPC_URL)
  });

  const account = privateKeyToAccount(privateKey);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(RPC_URL)
  });

  // Create atoms
  console.log('Creating atoms...');
  const atomDatas = [
    stringToHex(subjectData, { size: 32 }),
    stringToHex(predicateData, { size: 32 }),
    stringToHex(objectData, { size: 32 })
  ];

  const createAtomsHash = await walletClient.writeContract({
    address: MULTIVAULT_ADDRESS,
    abi: multiVaultAbi,
    functionName: 'createAtoms',
    args: [atomDatas, [atomDeposit, atomDeposit, atomDeposit]]
  });

  const atomsReceipt = await publicClient.waitForTransactionReceipt({ hash: createAtomsHash });

  // Extract atom IDs from events
  const atomCreatedLogs = publicClient.parseEventLogs({
    abi: multiVaultAbi,
    logs: atomsReceipt.logs,
    eventName: 'AtomCreated'
  });

  const atomIds = atomCreatedLogs.map(log => log.args.termId);

  if (atomIds.length !== 3) {
    throw new Error('Failed to create all atoms');
  }

  console.log('Atoms created:', atomIds);

  // Create triple
  console.log('Creating triple...');
  const result = await createTriple(
    atomIds[0],
    atomIds[1],
    atomIds[2],
    tripleDeposit,
    privateKey
  );

  return {
    subjectId: atomIds[0],
    predicateId: atomIds[1],
    objectId: atomIds[2],
    ...result
  };
}

// Usage example
async function main() {
  try {
    // Option 1: Create triple from existing atoms
    const result = await createTriple(
      '0x...' as `0x${string}`, // existing subject atom ID
      '0x...' as `0x${string}`, // existing predicate atom ID
      '0x...' as `0x${string}`, // existing object atom ID
      parseEther("50"), // 50 WTRUST
      '0x...' as `0x${string}` // YOUR_PRIVATE_KEY
    );

    console.log('\nTriple creation successful!');
    console.log('Triple ID:', result.tripleId);
    console.log('Counter Triple ID:', result.counterTripleId);
    console.log('Shares Minted:', formatEther(result.sharesMinted));
    console.log('Transaction:', result.txHash);

    // Option 2: Create atoms and triple together
    const fullResult = await createAtomsAndTriple(
      'Alice',           // subject
      'knows',           // predicate
      'Bob',             // object
      parseEther("10"),  // 10 WTRUST per atom
      parseEther("50"),  // 50 WTRUST for triple
      '0x...' as `0x${string}` // YOUR_PRIVATE_KEY
    );

    console.log('\nFull creation successful!');
    console.log('Subject ID:', fullResult.subjectId);
    console.log('Predicate ID:', fullResult.predicateId);
    console.log('Object ID:', fullResult.objectId);
    console.log('Triple ID:', fullResult.tripleId);

  } catch (error) {
    console.error('Error:', error instanceof Error ? error.message : 'Unknown error');
    process.exit(1);
  }
}

// Run if executed directly
main().catch(console.error);
```

### Python (web3.py)

Complete example with error handling:

```python
from web3 import Web3
from eth_account import Account
from typing import Dict, List, Tuple
import json

# Configuration
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672'
RPC_URL = 'YOUR_INTUITION_RPC_URL'

# Load ABIs
with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)

with open('abis/ERC20.json') as f:
    ERC20_ABI = json.load(f)


def create_triple(
    subject_id: str,
    predicate_id: str,
    object_id: str,
    deposit_amount: int,
    private_key: str
) -> Dict[str, any]:
    """
    Creates a single triple with initial deposit

    Args:
        subject_id: Hex string of subject atom ID (32 bytes)
        predicate_id: Hex string of predicate atom ID (32 bytes)
        object_id: Hex string of object atom ID (32 bytes)
        deposit_amount: Amount of WTRUST to deposit (in wei)
        private_key: Private key for signing transactions

    Returns:
        Dictionary with triple_id, counter_triple_id, shares_minted, tx_hash

    Raises:
        ValueError: If parameters are invalid
        Exception: If transaction fails
    """
    # Setup
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    if not w3.is_connected():
        raise Exception('Failed to connect to RPC endpoint')

    account = Account.from_key(private_key)

    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )
    wtrust = w3.eth.contract(
        address=Web3.to_checksum_address(WTRUST_ADDRESS),
        abi=ERC20_ABI
    )

    try:
        # Step 1: Validate atom ID format
        try:
            subject_bytes = bytes.fromhex(subject_id.replace('0x', ''))
            predicate_bytes = bytes.fromhex(predicate_id.replace('0x', ''))
            object_bytes = bytes.fromhex(object_id.replace('0x', ''))

            if len(subject_bytes) != 32 or len(predicate_bytes) != 32 or len(object_bytes) != 32:
                raise ValueError('Atom IDs must be 32 bytes')
        except:
            raise ValueError('Invalid atom ID format (must be 32-byte hex strings)')

        # Step 2: Check all atoms exist
        print('Checking atoms exist...')
        subject_exists = multivault.functions.isTermCreated(subject_bytes).call()
        predicate_exists = multivault.functions.isTermCreated(predicate_bytes).call()
        object_exists = multivault.functions.isTermCreated(object_bytes).call()

        if not subject_exists:
            raise ValueError(f'Subject atom {subject_id} does not exist')
        if not predicate_exists:
            raise ValueError(f'Predicate atom {predicate_id} does not exist')
        if not object_exists:
            raise ValueError(f'Object atom {object_id} does not exist')

        # Step 3: Calculate triple ID
        triple_id = multivault.functions.calculateTripleId(
            subject_bytes,
            predicate_bytes,
            object_bytes
        ).call()
        print(f'Computed Triple ID: {triple_id.hex()}')

        # Step 4: Calculate counter triple ID
        counter_triple_id = multivault.functions.getCounterIdFromTripleId(
            triple_id
        ).call()
        print(f'Counter Triple ID: {counter_triple_id.hex()}')

        # Step 5: Check triple doesn't exist
        triple_exists = multivault.functions.isTermCreated(triple_id).call()
        if triple_exists:
            raise ValueError(f'Triple already exists with ID: {triple_id.hex()}')

        # Step 6: Get triple creation costs
        triple_cost = multivault.functions.getTripleCost().call()
        general_config = multivault.functions.getGeneralConfig().call()
        triple_config = multivault.functions.getTripleConfig().call()

        min_deposit = general_config[4]  # minDeposit field
        minimum_required = triple_cost + min_deposit

        print(f'Triple creation cost: {Web3.from_wei(triple_cost, "ether")} WTRUST')
        print(f'Minimum deposit: {Web3.from_wei(min_deposit, "ether")} WTRUST')
        print(f'Total minimum: {Web3.from_wei(minimum_required, "ether")} WTRUST')

        # Calculate atom deposit fraction
        atom_fraction = triple_config[1]  # atomDepositFractionForTriple
        fee_denominator = general_config[2]  # feeDenominator
        atom_deposit_per_atom = (deposit_amount * atom_fraction) // fee_denominator

        print(f'Atom deposit fraction: {atom_fraction}/{fee_denominator}')
        print(f'Deposit to each atom: {Web3.from_wei(atom_deposit_per_atom, "ether")} WTRUST')

        # Validate deposit amount
        if deposit_amount < minimum_required:
            raise ValueError(
                f'Deposit amount {Web3.from_wei(deposit_amount, "ether")} is below '
                f'minimum {Web3.from_wei(minimum_required, "ether")} WTRUST'
            )

        # Step 7: Check WTRUST balance
        balance = wtrust.functions.balanceOf(account.address).call()
        if balance < deposit_amount:
            raise ValueError(
                f'Insufficient WTRUST balance. Have: {Web3.from_wei(balance, "ether")}, '
                f'Need: {Web3.from_wei(deposit_amount, "ether")}'
            )

        # Step 8: Preview the creation
        preview = multivault.functions.previewTripleCreate(
            triple_id,
            deposit_amount
        ).call()
        expected_shares, assets_after_fixed_fees, assets_after_all_fees = preview

        print(f'Expected shares: {Web3.from_wei(expected_shares, "ether")}')
        print(f'Assets after fixed fees: {Web3.from_wei(assets_after_fixed_fees, "ether")}')
        print(f'Assets after all fees: {Web3.from_wei(assets_after_all_fees, "ether")}')

        # Step 9: Approve WTRUST spending
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

        # Step 10: Create the triple
        print('Creating triple...')

        create_tx = multivault.functions.createTriples(
            [subject_bytes],
            [predicate_bytes],
            [object_bytes],
            [deposit_amount]
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 800000,
            'gasPrice': w3.eth.gas_price
        })

        signed_create = account.sign_transaction(create_tx)
        create_hash = w3.eth.send_raw_transaction(signed_create.raw_transaction)
        print(f'Transaction sent: {create_hash.hex()}')

        receipt = w3.eth.wait_for_transaction_receipt(create_hash)
        print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

        if receipt['status'] != 1:
            raise Exception('Triple creation transaction failed')

        # Step 11: Parse events
        shares_minted = 0

        triple_created_events = multivault.events.TripleCreated().process_receipt(receipt)
        if triple_created_events:
            event = triple_created_events[0]['args']
            print(f'Triple created: {event["termId"].hex()}')
            print(f'Subject: {event["subjectId"].hex()}')
            print(f'Predicate: {event["predicateId"].hex()}')
            print(f'Object: {event["objectId"].hex()}')

        deposited_events = multivault.events.Deposited().process_receipt(receipt)
        for event in deposited_events:
            if event['args']['vaultType'] == 1:  # VaultType.TRIPLE
                shares_minted = event['args']['shares']
                print(f'Shares minted: {Web3.from_wei(shares_minted, "ether")}')
                break

        if not triple_created_events:
            raise Exception('TripleCreated event not found in receipt')

        return {
            'triple_id': triple_id.hex(),
            'counter_triple_id': counter_triple_id.hex(),
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
        result = create_triple(
            subject_id='0x...',      # existing subject atom ID
            predicate_id='0x...',    # existing predicate atom ID
            object_id='0x...',       # existing object atom ID
            deposit_amount=Web3.to_wei(50, 'ether'),  # 50 WTRUST
            private_key='YOUR_PRIVATE_KEY'
        )

        print('\nTriple creation successful!')
        print(f'Triple ID: {result["triple_id"]}')
        print(f'Counter Triple ID: {result["counter_triple_id"]}')
        print(f'Shares Minted: {Web3.from_wei(result["shares_minted"], "ether")}')
        print(f'Transaction: {result["tx_hash"]}')

    except Exception as e:
        print(f'Error creating triple: {str(e)}')
        exit(1)
```

## Event Monitoring

### Events Emitted

When creating a triple, the following events are emitted:

#### 1. TripleCreated

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
- `creator`: Address that created the triple
- `termId`: Unique triple ID
- `subjectId`: Subject atom ID
- `predicateId`: Predicate atom ID
- `objectId`: Object atom ID

#### 2. Deposited (Triple Vault)

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

Emitted for the triple vault deposit (vaultType = 1 for TRIPLE).

#### 3. Deposited (Atom Vaults) x3

Three additional `Deposited` events for each underlying atom (subject, predicate, object) due to atom deposit fraction.

#### 4. SharePriceChanged

Emitted for the triple vault and potentially for atom vaults if their share prices change.

### Listening for Triple Events

**TypeScript (viem)**:
```typescript
import { parseAbiItem } from 'viem';

// Watch for triple creation events
const unwatch = publicClient.watchEvent({
  address: MULTIVAULT_ADDRESS,
  event: parseAbiItem('event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)'),
  onLogs: (logs) => {
    for (const log of logs) {
      console.log('New triple created:');
      console.log('  Creator:', log.args.creator);
      console.log('  Triple ID:', log.args.termId);
      console.log('  Subject:', log.args.subjectId);
      console.log('  Predicate:', log.args.predicateId);
      console.log('  Object:', log.args.objectId);
    }
  }
});

// Query past triples involving a specific atom
const logs = await publicClient.getLogs({
  address: MULTIVAULT_ADDRESS,
  event: parseAbiItem('event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)'),
  args: {
    subjectId: specificAtomId
  },
  fromBlock: 'earliest',
  toBlock: 'latest'
});

const events = publicClient.parseEventLogs({
  abi: multiVaultAbi,
  logs,
  eventName: 'TripleCreated'
});
```

**Python**:
```python
# Create event filter
event_filter = multivault.events.TripleCreated.create_filter(
    from_block='latest'
)

# Poll for new events
while True:
    for event in event_filter.get_new_entries():
        args = event['args']
        print(f'New triple: {args["termId"].hex()}')
        print(f'  Subject: {args["subjectId"].hex()}')
        print(f'  Predicate: {args["predicateId"].hex()}')
        print(f'  Object: {args["objectId"].hex()}')

    time.sleep(12)
```

## Error Handling

### Common Errors

#### 1. Triple Already Exists

**Error**: `MultiVaultCore_TripleExists()`

**Cause**: Attempting to create a triple that already exists.

**Recovery**:
- Check if triple exists: `isTermCreated(tripleId)`
- Deposit into existing triple vault instead
- Use different atom combination

#### 2. Atom Does Not Exist

**Error**: `MultiVaultCore_AtomDoesNotExist()`

**Cause**: One or more atoms in the triple don't exist.

**Recovery**:
- Create missing atoms first
- Verify all atom IDs: `isTermCreated(atomId)`
- Check atom ID calculation

#### 3. Insufficient Deposit

**Error**: `MultiVaultCore_DepositBelowMinimum()`

**Cause**: Deposit amount below minimum requirement.

**Recovery**:
- Query `getTripleCost()` and `minDeposit`
- Increase deposit amount
- Account for atom deposit fraction

#### 4. Invalid Atom Combination

**Error**: Transaction reverts without specific error

**Cause**: Subject, predicate, and object cannot all be the same atom.

**Recovery**:
- Ensure at least two atoms are different
- Validate atom IDs before creating triple

### Error Handling Pattern

```typescript
try {
  const result = await createTriple(subjectId, predicateId, objectId, amount, key);
} catch (error) {
  if (error.message.includes('TripleExists')) {
    // Triple exists, deposit instead
    const tripleId = await calculateTripleId(subjectId, predicateId, objectId);
    await depositToVault(tripleId, amount);
  } else if (error.message.includes('AtomDoesNotExist')) {
    // Create missing atoms first
    const atomIds = await createMissingAtoms([subjectId, predicateId, objectId]);
    await createTriple(atomIds[0], atomIds[1], atomIds[2], amount, key);
  } else if (error.message.includes('DepositBelowMinimum')) {
    // Get minimum and retry
    const min = await getMinimumTripleDeposit();
    await createTriple(subjectId, predicateId, objectId, min, key);
  } else {
    console.error('Triple creation failed:', error);
    throw error;
  }
}
```

## Gas Estimation

### Typical Gas Costs

| Operation | Gas Used | Notes |
|-----------|----------|-------|
| Single triple creation | ~600,000 | Creates triple + counter vaults |
| Triple with atom deposits | ~750,000 | Includes deposits to 3 atoms |
| Batch (2 triples) | ~1,000,000 | Saves ~200k vs 2 separate |
| Batch (5 triples) | ~2,200,000 | Scales sub-linearly |

### Factors Affecting Cost

1. **Atom deposit fraction**: Higher fraction = more gas for atom deposits
2. **Existing vaults**: First deposit to an atom vault costs more
3. **Batch size**: Larger batches more efficient per triple
4. **Network congestion**: Gas price varies

### Gas Optimization

```typescript
// 1. Use batch creation
const tripleIds = await multiVault.createTriples(
  [subject1, subject2, subject3],
  [pred1, pred2, pred3],
  [obj1, obj2, obj3],
  [amt1, amt2, amt3]
);

// 2. Estimate before sending
const gasEstimate = await multiVault.createTriples.estimateGas(
  [subjectId],
  [predicateId],
  [objectId],
  [amount]
);
const gasLimit = gasEstimate * 120n / 100n; // 20% buffer

// 3. Monitor gas prices
const gasPrice = await provider.getFeeData();
if (gasPrice.gasPrice > parseUnits('50', 'gwei')) {
  console.warn('High gas prices, consider waiting');
}
```

## Best Practices

### 1. Validate Atoms Exist

```typescript
async function validateAtoms(subjectId: string, predicateId: string, objectId: string) {
  const checks = await Promise.all([
    multiVault.isTermCreated(subjectId),
    multiVault.isTermCreated(predicateId),
    multiVault.isTermCreated(objectId)
  ]);

  if (!checks[0]) throw new Error('Subject atom missing');
  if (!checks[1]) throw new Error('Predicate atom missing');
  if (!checks[2]) throw new Error('Object atom missing');
}
```

### 2. Account for Atom Deposits

Remember that creating a triple also deposits to underlying atoms:

```typescript
const tripleConfig = await multiVault.getTripleConfig();
const generalConfig = await multiVault.getGeneralConfig();

const atomFraction = tripleConfig.atomDepositFractionForTriple;
const feeDenominator = generalConfig.feeDenominator;

// If depositing 100 WTRUST with 10% atom fraction:
// - 10 WTRUST → subject atom
// - 10 WTRUST → predicate atom
// - 10 WTRUST → object atom
// - ~70 WTRUST (after fees) → triple vault
```

### 3. Use Counter Triples

Both positive and counter vaults are created:

```typescript
const tripleId = await multiVault.calculateTripleId(sub, pred, obj);
const counterTripleId = await multiVault.getCounterIdFromTripleId(tripleId);

// Users can deposit to either vault to express agreement or disagreement
await depositToVault(tripleId, amount);        // Support the claim
await depositToVault(counterTripleId, amount); // Oppose the claim
```

### 4. Maintain Triple Index

Keep an off-chain index of your triples:

```typescript
interface TripleRecord {
  tripleId: string;
  counterTripleId: string;
  subjectId: string;
  predicateId: string;
  objectId: string;
  createdAt: Date;
  creator: string;
}

async function createAndIndex(sub, pred, obj, amount) {
  const result = await createTriple(sub, pred, obj, amount, key);

  await db.triples.insert({
    tripleId: result.tripleId,
    counterTripleId: result.counterTripleId,
    subjectId: sub,
    predicateId: pred,
    objectId: obj,
    createdAt: new Date(),
    creator: wallet.address
  });

  return result;
}
```

### 5. Design Meaningful Triples

Create triples that express clear, verifiable claims:

```typescript
// Good: Clear, verifiable relationships
// ("Alice", "owns", "NFT#123")
// ("Document", "signedBy", "PublicKey")
// ("Address", "hasReputation", "HighScore")

// Bad: Unclear or non-verifiable
// ("Thing", "relates", "Stuff")
```

## Common Pitfalls

### 1. Not Checking Atom Existence

```typescript
// WRONG: Assumes atoms exist
await createTriple(sub, pred, obj, amount);

// CORRECT: Validate first
const atomsExist = await Promise.all([
  multiVault.isTermCreated(sub),
  multiVault.isTermCreated(pred),
  multiVault.isTermCreated(obj)
]);
if (!atomsExist.every(e => e)) {
  throw new Error('One or more atoms missing');
}
await createTriple(sub, pred, obj, amount);
```

### 2. Insufficient Deposit for Atom Fraction

```typescript
// WRONG: Forgot about atom deposit fraction
const minDeposit = await multiVault.getTripleCost();
await createTriple(sub, pred, obj, minDeposit); // Might fail

// CORRECT: Account for minimums and atom deposits
const tripleCost = await multiVault.getTripleCost();
const generalConfig = await multiVault.getGeneralConfig();
const minRequired = tripleCost + generalConfig.minDeposit;
await createTriple(sub, pred, obj, minRequired);
```

### 3. Ignoring Counter Triple

```typescript
// WRONG: Only tracking positive triple
const tripleId = await calculateTripleId(sub, pred, obj);

// CORRECT: Track both
const tripleId = await calculateTripleId(sub, pred, obj);
const counterTripleId = await getCounterIdFromTripleId(tripleId);
// Both vaults now exist and can receive deposits
```

### 4. Using Same Atom for All Positions

```typescript
// WRONG: Subject, predicate, and object are the same
await createTriple(atomId, atomId, atomId, amount); // Will revert

// CORRECT: At least two must be different
await createTriple(atomId1, atomId2, atomId3, amount);
```

### 5. Not Handling Batch Arrays Properly

```typescript
// WRONG: Mismatched array lengths
await multiVault.createTriples(
  [sub1, sub2],
  [pred1],           // Wrong length!
  [obj1, obj2],
  [amt1, amt2]
);

// CORRECT: All arrays same length
await multiVault.createTriples(
  [sub1, sub2],
  [pred1, pred2],
  [obj1, obj2],
  [amt1, amt2]
);
```

## Related Operations

### After Creating a Triple

1. **Deposit to triple vault**: [Depositing Assets Guide](./depositing-assets.md)
2. **Deposit to counter triple**: Support the opposing claim
3. **Create more triples**: Build a knowledge graph
4. **Redeem shares**: Exit positions - [Redeeming Shares Guide](./redeeming-shares.md)

### Alternative Approaches

- **Batch creation**: Create multiple triples in one transaction
- **Create atoms first**: Ensure atoms exist before creating triples
- **Direct deposit**: If triple exists, deposit without recreating

## See Also

- [Atoms and Triples Concept](../concepts/atoms-and-triples.md)
- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [Creating Atoms Guide](./creating-atoms.md)
- [Depositing Assets Guide](./depositing-assets.md)
- [Fee Structure](./fee-structure.md)
- [MultiVault Contract Reference](../contracts/core/MultiVault.md)
- [Batch Operations Guide](./batch-operations.md)

---

**Last Updated**: December 2025
