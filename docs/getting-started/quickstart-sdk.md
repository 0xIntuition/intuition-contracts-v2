# Quick Start for SDK Builders

Get started building an SDK for Intuition Protocol V2 with TypeScript and viem. This guide covers the essential operations for integrating the protocol into your application.

## Prerequisites

- Node.js 18+ and npm/yarn/pnpm
- Basic understanding of Ethereum development
- Familiarity with TypeScript
- viem knowledge recommended

## Installation

```bash
npm install viem
# or
yarn add viem
# or
pnpm add viem
```

## Getting Contract ABIs

You'll need the ABIs for the core contracts. These can be obtained from:

1. **Block Explorers**: Download from verified contracts on [BaseScan](https://basescan.org) and [Intuition Explorer](https://explorer.intuit.network)
2. **Repository**: Found in the `out/` directory after running `forge build`
3. **Documentation**: Available in [reference/abi](../reference/abi/)

For this guide, assume you have the ABIs imported:

```typescript
import MULTIVAULT_ABI from './abis/MultiVault.json';
import TRUST_ABI from './abis/Trust.json';
```

## Basic Setup

### Connect to Networks

Intuition Protocol V2 operates on two chains:

```typescript
import { createPublicClient, createWalletClient, http, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base, intuition } from 'viem/chains';

// Create account from private key
const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);

// Base Mainnet - For TRUST token minting and base emissions
const basePublicClient = createPublicClient({
  chain: base,
  transport: http('https://mainnet.base.org'),
});

const baseWalletClient = createWalletClient({
  account,
  chain: base,
  transport: http('https://mainnet.base.org'),
});

// Intuition Mainnet - For vault operations and protocol interactions
const intuitionPublicClient = createPublicClient({
  chain: intuition,
  transport: http('YOUR_INTUITION_RPC'),
});

const intuitionWalletClient = createWalletClient({
  account,
  chain: intuition,
  transport: http('YOUR_INTUITION_RPC'),
});
```

### Initialize Contract Instances

```typescript
// MultiVault - The main protocol contract on Intuition Mainnet
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const multiVault = getContract({
  address: MULTIVAULT_ADDRESS as `0x${string}`,
  abi: MULTIVAULT_ABI,
  client: { public: intuitionPublicClient, wallet: intuitionWalletClient },
});

// TRUST token on Base Mainnet
const TRUST_ADDRESS = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3';
const trustToken = getContract({
  address: TRUST_ADDRESS as `0x${string}`,
  abi: TRUST_ABI,
  client: { public: basePublicClient, wallet: baseWalletClient },
});
```

## Core Operations

### 1. Creating an Atom

Atoms are the fundamental data units in Intuition. Here's how to create one:

```typescript
async function createAtom(atomData: string, depositAmount: bigint) {
  try {
    // atomData can be any bytes data ≤256 bytes
    // Common pattern: encode an address, hash, or small JSON
    const atomDataBytes = toBytes(atomData);

    // Prepare transaction parameters
    const atomDatas = [atomDataBytes];
    const assets = [depositAmount];

    // Calculate required ETH (if using native token)
    const value = depositAmount; // Adjust based on your asset type

    // Create the atom
    const tx = await multiVault.createAtoms(atomDatas, assets, { value });
    console.log(`Transaction sent: ${tx.hash}`);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Extract atom ID from the AtomCreated event
    const atomCreatedEvent = receipt.logs
      .map((log: any) => {
        try {
          return multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((event: any) => event?.name === 'AtomCreated');

    if (atomCreatedEvent) {
      const atomId = atomCreatedEvent.args.termId;
      console.log(`Atom created with ID: ${atomId}`);
      return atomId;
    }

    throw new Error('AtomCreated event not found');
  } catch (error) {
    console.error('Error creating atom:', error);
    throw error;
  }
}

// Example usage
const depositAmount = parseEther('0.1'); // 0.1 ETH
const atomId = await createAtom('MyFirstAtom', depositAmount);
```

### 2. Creating a Triple

Triples express relationships between atoms (subject-predicate-object):

```typescript
async function createTriple(
  subjectId: string,
  predicateId: string,
  objectId: string,
  depositAmount: bigint
) {
  try {
    // Check that all atoms exist
    const subjectExists = await multiVault.isTermCreated(subjectId);
    const predicateExists = await multiVault.isTermCreated(predicateId);
    const objectExists = await multiVault.isTermCreated(objectId);

    if (!subjectExists || !predicateExists || !objectExists) {
      throw new Error('One or more atoms do not exist');
    }

    // Prepare transaction parameters
    const subjectIds = [subjectId];
    const predicateIds = [predicateId];
    const objectIds = [objectId];
    const assets = [depositAmount];

    const value = depositAmount;

    // Create the triple
    const tx = await multiVault.createTriples(
      subjectIds,
      predicateIds,
      objectIds,
      assets,
      { value }
    );
    console.log(`Transaction sent: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Extract triple ID from the TripleCreated event
    const tripleCreatedEvent = receipt.logs
      .map((log: any) => {
        try {
          return multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((event: any) => event?.name === 'TripleCreated');

    if (tripleCreatedEvent) {
      const tripleId = tripleCreatedEvent.args.termId;
      console.log(`Triple created with ID: ${tripleId}`);
      return tripleId;
    }

    throw new Error('TripleCreated event not found');
  } catch (error) {
    console.error('Error creating triple:', error);
    throw error;
  }
}

// Example usage
const tripleId = await createTriple(
  '0x...subjectId',
  '0x...predicateId',
  '0x...objectId',
  parseEther('0.1')
);
```

### 3. Depositing Assets into a Vault

Once an atom or triple exists, anyone can deposit assets to receive shares:

```typescript
async function depositToVault(
  termId: string,
  curveId: bigint,
  assets: bigint,
  slippageTolerance: number = 0.01 // 1% slippage
) {
  try {
    // Preview the deposit to get expected shares
    const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
      termId,
      curveId,
      assets
    );

    console.log(`Expected shares: ${formatEther(expectedShares)}`);
    console.log(`Assets after fees: ${formatEther(assetsAfterFees)}`);

    // Calculate minimum shares with slippage tolerance
    const minShares = expectedShares * BigInt(Math.floor((1 - slippageTolerance) * 10000)) / 10000n;

    // Execute the deposit
    const tx = await multiVault.deposit(
      await intuitionSigner.getAddress(), // receiver
      termId,
      curveId,
      minShares,
      { value: assets }
    );

    console.log(`Deposit transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Deposit confirmed in block ${receipt.blockNumber}`);

    // Extract actual shares from Deposited event
    const depositedEvent = receipt.logs
      .map((log: any) => {
        try {
          return multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((event: any) => event?.name === 'Deposited');

    if (depositedEvent) {
      const actualShares = depositedEvent.args.shares;
      console.log(`Received shares: ${formatEther(actualShares)}`);
      return actualShares;
    }

    return expectedShares;
  } catch (error) {
    console.error('Error depositing to vault:', error);
    throw error;
  }
}

// Example usage
const shares = await depositToVault(
  atomId,
  0n, // curveId 0 = default curve
  parseEther('1.0'),
  0.01 // 1% slippage tolerance
);
```

### 4. Redeeming Shares from a Vault

Convert shares back to assets:

```typescript
async function redeemFromVault(
  termId: string,
  curveId: bigint,
  shares: bigint,
  slippageTolerance: number = 0.01 // 1% slippage
) {
  try {
    // Check user's share balance
    const userAddress = await intuitionSigner.getAddress();
    const userShares = await multiVault.getShares(userAddress, termId, curveId);

    if (shares > userShares) {
      throw new Error(`Insufficient shares. Have: ${userShares}, Want: ${shares}`);
    }

    // Preview the redemption to get expected assets
    const [expectedAssets, sharesUsed] = await multiVault.previewRedeem(
      termId,
      curveId,
      shares
    );

    console.log(`Expected assets: ${formatEther(expectedAssets)}`);

    // Calculate minimum assets with slippage tolerance
    const minAssets = expectedAssets * BigInt(Math.floor((1 - slippageTolerance) * 10000)) / 10000n;

    // Execute the redemption
    const tx = await multiVault.redeem(
      userAddress, // receiver
      termId,
      curveId,
      shares,
      minAssets
    );

    console.log(`Redemption transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Redemption confirmed in block ${receipt.blockNumber}`);

    // Extract actual assets from Redeemed event
    const redeemedEvent = receipt.logs
      .map((log: any) => {
        try {
          return multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((event: any) => event?.name === 'Redeemed');

    if (redeemedEvent) {
      const actualAssets = redeemedEvent.args.assets;
      console.log(`Received assets: ${formatEther(actualAssets)}`);
      return actualAssets;
    }

    return expectedAssets;
  } catch (error) {
    console.error('Error redeeming from vault:', error);
    throw error;
  }
}

// Example usage
const assets = await redeemFromVault(
  atomId,
  0n,
  parseEther('0.5'), // Redeem 0.5 shares
  0.01
);
```

### 5. Querying Vault State

Get information about a vault:

```typescript
async function getVaultInfo(termId: string, curveId: bigint) {
  try {
    // Get vault totals
    const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

    // Get current share price
    const sharePrice = await multiVault.currentSharePrice(termId, curveId);

    // Get user's shares
    const userAddress = await intuitionSigner.getAddress();
    const userShares = await multiVault.getShares(userAddress, termId, curveId);

    console.log('Vault Info:');
    console.log(`  Total Assets: ${formatEther(totalAssets)}`);
    console.log(`  Total Shares: ${formatEther(totalShares)}`);
    console.log(`  Share Price: ${formatEther(sharePrice)}`);
    console.log(`  User Shares: ${formatEther(userShares)}`);

    return {
      totalAssets,
      totalShares,
      sharePrice,
      userShares
    };
  } catch (error) {
    console.error('Error getting vault info:', error);
    throw error;
  }
}

// Example usage
const vaultInfo = await getVaultInfo(atomId, 0n);
```

## Event Monitoring

Listen for protocol events in real-time:

```typescript
// Listen for atom creation
multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet, event) => {
  console.log('New atom created:');
  console.log(`  Creator: ${creator}`);
  console.log(`  Atom ID: ${termId}`);
  console.log(`  Atom Wallet: ${atomWallet}`);
});

// Listen for deposits
multiVault.on('Deposited', (sender, receiver, termId, curveId, assets, assetsAfterFees, shares, totalShares, vaultType, event) => {
  console.log('Deposit made:');
  console.log(`  Sender: ${sender}`);
  console.log(`  Term ID: ${termId}`);
  console.log(`  Shares Minted: ${formatEther(shares)}`);
});

// Listen for redemptions
multiVault.on('Redeemed', (sender, receiver, termId, curveId, shares, totalShares, assets, fees, vaultType, event) => {
  console.log('Redemption made:');
  console.log(`  Sender: ${sender}`);
  console.log(`  Term ID: ${termId}`);
  console.log(`  Assets Returned: ${formatEther(assets)}`);
});

// Query historical events
async function getAtomCreationHistory(fromBlock: number, toBlock: number) {
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
```

## Batch Operations

Perform multiple operations in a single transaction:

```typescript
async function batchDeposit(
  termIds: string[],
  curveIds: bigint[],
  assets: bigint[],
  minShares: bigint[]
) {
  try {
    const receiver = await intuitionSigner.getAddress();

    // Calculate total value needed
    const totalValue = assets.reduce((sum, amount) => sum + amount, 0n);

    // Execute batch deposit
    const tx = await multiVault.depositBatch(
      receiver,
      termIds,
      curveIds,
      assets,
      minShares,
      { value: totalValue }
    );

    console.log(`Batch deposit transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Batch deposit confirmed in block ${receipt.blockNumber}`);

    return receipt;
  } catch (error) {
    console.error('Error in batch deposit:', error);
    throw error;
  }
}

// Example: Deposit into 3 different vaults at once
await batchDeposit(
  ['0x...atom1', '0x...atom2', '0x...triple1'],
  [0n, 0n, 0n],
  [parseEther('1'), parseEther('2'), parseEther('0.5')],
  [0n, 0n, 0n] // minShares - set appropriately in production
);
```

## Error Handling Best Practices

```typescript
async function safeDeposit(termId: string, curveId: bigint, assets: bigint) {
  try {
    // Validate inputs
    if (assets <= 0n) {
      throw new Error('Deposit amount must be greater than zero');
    }

    // Check if term exists
    const termExists = await multiVault.isTermCreated(termId);
    if (!termExists) {
      throw new Error(`Term ${termId} does not exist`);
    }

    // Check user balance
    const balance = await intuitionProvider.getBalance(await intuitionSigner.getAddress());
    if (balance < assets) {
      throw new Error(`Insufficient balance. Have: ${formatEther(balance)}, Need: ${formatEther(assets)}`);
    }

    // Perform the deposit
    return await depositToVault(termId, curveId, assets);

  } catch (error: any) {
    // Handle specific errors
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error('Insufficient funds for transaction');
    } else if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
      console.error('Transaction will likely fail - check parameters');
    } else if (error.message?.includes('MinSharesRequired')) {
      console.error('Minimum shares requirement not met');
    } else {
      console.error('Unexpected error:', error.message);
    }
    throw error;
  }
}
```

## Gas Optimization Tips

```typescript
// 1. Use estimateGas before sending transactions
const estimatedGas = await multiVault.deposit.estimateGas(
  receiver,
  termId,
  curveId,
  minShares,
  { value: assets }
);
console.log(`Estimated gas: ${estimatedGas.toString()}`);

// 2. Batch operations when possible
// Instead of 3 separate deposit transactions, use depositBatch()

// 3. Use staticCall to simulate without spending gas
const [shares, assetsAfterFees] = await multiVault.deposit.staticCall(
  receiver,
  termId,
  curveId,
  minShares,
  { value: assets }
);
```

## Next Steps

Now that you have the basics:

1. **Learn About Concepts**: Read [Atoms and Triples](../concepts/atoms-and-triples.md) for deeper understanding
2. **Explore Advanced Features**: Check [Integration Patterns](../integration/sdk-design-patterns.md)
3. **Review Examples**: See complete code in [TypeScript Examples](../examples/typescript/)
4. **Understand Fees**: Read the [Fee Structure Guide](../guides/fee-structure.md)
5. **Add Emissions**: Learn about [Claiming Rewards](../guides/claiming-rewards.md)

## Common Patterns

### Helper: Calculate Atom ID

```typescript
function calculateAtomId(atomData: Uint8Array): string {
  const SALT = keccak256(toBytes('SALT'));
  const dataHash = keccak256(atomData);
  return keccak256(concat([SALT, dataHash]));
}

// Usage
const atomData = toBytes('MyAtom');
const expectedAtomId = calculateAtomId(atomData);
console.log(`Expected atom ID: ${expectedAtomId}`);
```

### Helper: Calculate Triple ID

```typescript
function calculateTripleId(subjectId: string, predicateId: string, objectId: string): string {
  const encoded = encodePacked(
    ['bytes32', 'bytes32', 'bytes32'],
    [subjectId, predicateId, objectId]
  );
  return keccak256(encoded);
}

// Usage
const tripleId = calculateTripleId(
  '0x...subject',
  '0x...predicate',
  '0x...object'
);
```

## Troubleshooting

### Transaction Reverts

If transactions revert without clear errors, check:
- Contract is not paused: `await multiVault.paused()`
- Term exists: `await multiVault.isTermCreated(termId)`
- Sufficient balance and allowances
- Minimum share requirements met

### Event Not Found

If events are missing from receipts:
- Ensure transaction was successful (`receipt.status === 1`)
- Check the correct contract emitted the event
- Verify you're parsing the correct event name

### Gas Estimation Fails

If `estimateGas()` fails:
- Validate all input parameters
- Check that the contract call would succeed
- Use `staticCall()` to see the revert reason

## See Also

- [Quick Start with ABI](./quickstart-abi.md) - For direct ABI integration
- [Architecture Overview](./architecture.md) - System design
- [Contract Reference](../contracts/) - Detailed contract docs
- [Integration Guides](../guides/) - Step-by-step tutorials

---

**Last Updated**: December 2025
