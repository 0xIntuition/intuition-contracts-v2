# Batch Operations

## Overview

Batch operations allow you to deposit into or redeem from multiple vaults in a single transaction, significantly reducing gas costs and improving efficiency. The MultiVault contract provides `depositBatch` and `redeemBatch` functions for atomic multi-vault operations.

This guide shows you how to perform batch deposits and redemptions programmatically.

**When to use this operation**:
- Depositing into multiple vaults simultaneously
- Rebalancing portfolio across multiple positions
- Exiting multiple positions at once
- Creating complex atomic operations
- Saving gas compared to multiple separate transactions

## Prerequisites

### Required Knowledge
- Understanding of single deposit/redemption operations
- Familiarity with [multi-vault architecture](../concepts/multi-vault-pattern.md)
- Knowledge of [bonding curves](../concepts/bonding-curves.md)
- Understanding of atomic transactions

### Contracts Needed
- **MultiVault**: Main contract for batch operations
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`
- **WrappedTrust (WTRUST)**: Asset token
  - Mainnet: `0x81cFb09cb44f7184Ad934C09F82000701A4bF672`
  - Testnet: `0xDE80b6EE63f7D809427CA350e30093F436A0fe35`

### Tokens Required
- WTRUST tokens (sum of all deposits)
- Vault shares (for batch redemptions)
- Native ETH for gas fees
- Approval for total deposit amount

### Key Parameters
- `receiver`: Address to receive shares/assets
- `termIds[]`: Array of term IDs (atoms/triples)
- `curveIds[]`: Array of curve IDs (typically all 1)
- `assets[]` or `shares[]`: Amounts for each vault
- `minShares[]` or `minAssets[]`: Slippage protection per vault

## Step-by-Step Guide

### Step 1: Prepare Batch Parameters

Collect all vault identifiers and amounts for your batch operation.

```typescript
const termIds = [atomId1, tripleId1, atomId2]; // 3 vaults
const curveIds = [1n, 1n, 1n]; // All using linear curve
const depositAmounts = [
  ethers.parseEther('10'),  // 10 WTRUST to vault 1
  ethers.parseEther('20'),  // 20 WTRUST to vault 2
  ethers.parseEther('15')   // 15 WTRUST to vault 3
];
```

### Step 2: Validate All Vaults Exist

Ensure all target vaults have been created:

```typescript
for (const termId of termIds) {
  const exists = await multiVault.isTermCreated(termId);
  if (!exists) {
    throw new Error(`Vault ${termId} does not exist`);
  }
}
```

### Step 3: Preview Each Operation

Simulate each deposit/redemption to calculate slippage protection:

```typescript
const previews = await Promise.all(
  termIds.map(async (termId, i) => {
    const [shares, assetsAfterFees] = await multiVault.previewDeposit(
      termId,
      curveIds[i],
      depositAmounts[i]
    );
    return { shares, assetsAfterFees };
  })
);

console.log('Expected shares:', previews.map(p => ethers.formatEther(p.shares)));
```

### Step 4: Calculate Minimum Amounts

Set slippage tolerance for each operation:

```typescript
const slippageBps = 50; // 0.5%
const minShares = previews.map(p =>
  (p.shares * BigInt(10000 - slippageBps)) / 10000n
);
```

### Step 5: Calculate Total Approval Needed

For deposits, sum all amounts:

```typescript
const totalDeposit = depositAmounts.reduce((sum, amt) => sum + amt, 0n);

// Approve total amount
await wtrust.approve(MULTIVAULT_ADDRESS, totalDeposit);
```

### Step 6: Execute Batch Deposit

Call `depositBatch` with all parameters:

```typescript
const tx = await multiVault.depositBatch(
  receiverAddress,
  termIds,
  curveIds,
  depositAmounts,
  minShares
);

const receipt = await tx.wait();
```

### Step 7: Parse Batch Results

Extract shares minted for each vault from events:

```typescript
const depositEvents = receipt.logs
  .map(log => {
    try {
      return multiVault.interface.parseLog(log);
    } catch {
      return null;
    }
  })
  .filter(event => event && event.name === 'Deposited');

console.log(`Minted shares across ${depositEvents.length} vaults`);
```

## Code Examples

### TypeScript (ethers.js v6)

Complete batch deposit and redemption examples:

```typescript
import { ethers } from 'ethers';

// Contract ABIs
import MultiVaultABI from './abis/IMultiVault.json';
import ERC20ABI from './abis/ERC20.json';

// Configuration
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

interface BatchDepositParams {
  termIds: string[];
  curveIds: bigint[];
  amounts: bigint[];
  slippageBps: number;
}

/**
 * Deposits into multiple vaults in a single transaction
 */
async function batchDeposit(
  params: BatchDepositParams,
  receiver: string,
  privateKey: string
): Promise<{
  sharesMinted: bigint[];
  totalAssets: bigint;
  totalShares: bigint;
  txHash: string;
}> {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);

  const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MultiVaultABI, wallet);
  const wtrust = new ethers.Contract(WTRUST_ADDRESS, ERC20ABI, wallet);

  try {
    // Validate arrays have same length
    if (params.termIds.length !== params.curveIds.length ||
        params.termIds.length !== params.amounts.length) {
      throw new Error('Array lengths must match');
    }

    const vaultCount = params.termIds.length;
    console.log(`Batch depositing into ${vaultCount} vaults`);

    // Step 1: Validate all vaults exist
    console.log('Validating vaults...');
    for (let i = 0; i < vaultCount; i++) {
      const exists = await multiVault.isTermCreated(params.termIds[i]);
      if (!exists) {
        throw new Error(`Vault ${i} (${params.termIds[i]}) does not exist`);
      }
    }

    // Step 2: Preview all deposits
    console.log('Previewing deposits...');
    const previews = await Promise.all(
      params.termIds.map(async (termId, i) => {
        const [shares, assetsAfterFees] = await multiVault.previewDeposit(
          termId,
          params.curveIds[i],
          params.amounts[i]
        );

        console.log(`Vault ${i}:`);
        console.log(`  Assets: ${ethers.formatEther(params.amounts[i])} WTRUST`);
        console.log(`  Expected shares: ${ethers.formatEther(shares)}`);
        console.log(`  After fees: ${ethers.formatEther(assetsAfterFees)}`);

        return { shares, assetsAfterFees };
      })
    );

    // Step 3: Calculate minimum shares with slippage protection
    const minShares = previews.map(p =>
      (p.shares * BigInt(10000 - params.slippageBps)) / 10000n
    );

    // Step 4: Calculate total deposit amount
    const totalDeposit = params.amounts.reduce((sum, amt) => sum + amt, 0n);
    console.log(`\nTotal deposit: ${ethers.formatEther(totalDeposit)} WTRUST`);

    // Step 5: Check WTRUST balance
    const balance = await wtrust.balanceOf(wallet.address);
    if (balance < totalDeposit) {
      throw new Error(
        `Insufficient WTRUST. Have: ${ethers.formatEther(balance)}, ` +
        `Need: ${ethers.formatEther(totalDeposit)}`
      );
    }

    // Step 6: Approve total amount
    console.log('Approving WTRUST...');
    const approveTx = await wtrust.approve(MULTIVAULT_ADDRESS, totalDeposit);
    await approveTx.wait();
    console.log('Approval confirmed');

    // Step 7: Execute batch deposit
    console.log('\nExecuting batch deposit...');
    const depositTx = await multiVault.depositBatch(
      receiver,
      params.termIds,
      params.curveIds,
      params.amounts,
      minShares,
      {
        gasLimit: 500000n + (BigInt(vaultCount) * 150000n) // Scale with vault count
      }
    );

    console.log('Transaction sent:', depositTx.hash);
    const receipt = await depositTx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 8: Parse events to get shares minted per vault
    const depositEvents = receipt.logs
      .map(log => {
        try {
          return multiVault.interface.parseLog({
            topics: log.topics,
            data: log.data
          });
        } catch {
          return null;
        }
      })
      .filter(event => event && event.name === 'Deposited');

    const sharesMinted: bigint[] = [];
    let totalShares = 0n;

    console.log('\nDeposit Results:');
    for (let i = 0; i < depositEvents.length; i++) {
      const event = depositEvents[i];
      sharesMinted.push(event.args.shares);
      totalShares += event.args.shares;

      console.log(`Vault ${i}:`);
      console.log(`  Term ID: ${event.args.termId}`);
      console.log(`  Shares minted: ${ethers.formatEther(event.args.shares)}`);
      console.log(`  Total shares: ${ethers.formatEther(event.args.totalShares)}`);
    }

    console.log(`\nTotal shares minted: ${ethers.formatEther(totalShares)}`);

    return {
      sharesMinted,
      totalAssets: totalDeposit,
      totalShares,
      txHash: receipt.hash
    };

  } catch (error) {
    if (error.code === 'INSUFFICIENT_FUNDS') {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.message?.includes('MinSharesNotReached')) {
      throw new Error('Slippage exceeded on one or more deposits');
    }
    throw error;
  }
}

/**
 * Redeems shares from multiple vaults in a single transaction
 */
async function batchRedeem(
  params: {
    termIds: string[];
    curveIds: bigint[];
    shares: bigint[];
    slippageBps: number;
  },
  receiver: string,
  privateKey: string
): Promise<{
  assetsReceived: bigint[];
  totalAssets: bigint;
  totalFees: bigint;
  txHash: string;
}> {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MultiVaultABI, wallet);

  try {
    const vaultCount = params.termIds.length;
    console.log(`Batch redeeming from ${vaultCount} vaults`);

    // Step 1: Verify user has sufficient shares in each vault
    console.log('Checking share balances...');
    for (let i = 0; i < vaultCount; i++) {
      const balance = await multiVault.getShares(
        wallet.address,
        params.termIds[i],
        params.curveIds[i]
      );

      if (balance < params.shares[i]) {
        throw new Error(
          `Insufficient shares in vault ${i}. ` +
          `Have: ${ethers.formatEther(balance)}, ` +
          `Need: ${ethers.formatEther(params.shares[i])}`
        );
      }
    }

    // Step 2: Preview all redemptions
    console.log('Previewing redemptions...');
    const previews = await Promise.all(
      params.termIds.map(async (termId, i) => {
        const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
          termId,
          params.curveIds[i],
          params.shares[i]
        );

        console.log(`Vault ${i}:`);
        console.log(`  Shares: ${ethers.formatEther(params.shares[i])}`);
        console.log(`  Expected assets: ${ethers.formatEther(assetsAfterFees)}`);

        return { assetsAfterFees, sharesUsed };
      })
    );

    // Step 3: Calculate minimum assets with slippage protection
    const minAssets = previews.map(p =>
      (p.assetsAfterFees * BigInt(10000 - params.slippageBps)) / 10000n
    );

    // Step 4: Execute batch redemption
    console.log('\nExecuting batch redemption...');
    const redeemTx = await multiVault.redeemBatch(
      receiver,
      params.termIds,
      params.curveIds,
      params.shares,
      minAssets,
      {
        gasLimit: 400000n + (BigInt(vaultCount) * 120000n)
      }
    );

    console.log('Transaction sent:', redeemTx.hash);
    const receipt = await redeemTx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 5: Parse events
    const redeemEvents = receipt.logs
      .map(log => {
        try {
          return multiVault.interface.parseLog({ topics: log.topics, data: log.data });
        } catch {
          return null;
        }
      })
      .filter(event => event && event.name === 'Redeemed');

    const assetsReceived: bigint[] = [];
    let totalAssets = 0n;
    let totalFees = 0n;

    console.log('\nRedemption Results:');
    for (let i = 0; i < redeemEvents.length; i++) {
      const event = redeemEvents[i];
      assetsReceived.push(event.args.assets);
      totalAssets += event.args.assets;
      totalFees += event.args.fees;

      console.log(`Vault ${i}:`);
      console.log(`  Assets received: ${ethers.formatEther(event.args.assets)}`);
      console.log(`  Fees: ${ethers.formatEther(event.args.fees)}`);
    }

    console.log(`\nTotal assets received: ${ethers.formatEther(totalAssets)}`);
    console.log(`Total fees: ${ethers.formatEther(totalFees)}`);

    return {
      assetsReceived,
      totalAssets,
      totalFees,
      txHash: receipt.hash
    };

  } catch (error) {
    if (error.message?.includes('MinAssetsNotReached')) {
      throw new Error('Slippage exceeded on one or more redemptions');
    }
    throw error;
  }
}

// Usage example
async function main() {
  try {
    // Batch deposit example
    const depositResult = await batchDeposit(
      {
        termIds: ['0x1234...', '0x5678...', '0x9abc...'],
        curveIds: [1n, 1n, 1n],
        amounts: [
          ethers.parseEther('10'),
          ethers.parseEther('20'),
          ethers.parseEther('15')
        ],
        slippageBps: 50 // 0.5%
      },
      '0xYourAddress',
      'YOUR_PRIVATE_KEY'
    );

    console.log('\n=== Batch Deposit Successful ===');
    console.log('Transaction:', depositResult.txHash);
    console.log('Total deposited:', ethers.formatEther(depositResult.totalAssets));
    console.log('Total shares:', ethers.formatEther(depositResult.totalShares));

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
```

### Python (web3.py)

Complete batch operations example:

```python
from web3 import Web3
from eth_account import Account
from typing import List, Dict
import json

# Configuration
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672'
RPC_URL = 'YOUR_INTUITION_RPC_URL'

with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)

with open('abis/ERC20.json') as f:
    ERC20_ABI = json.load(f)


def batch_deposit(
    term_ids: List[bytes],
    curve_ids: List[int],
    amounts: List[int],
    slippage_bps: int,
    receiver: str,
    private_key: str
) -> Dict:
    """
    Deposits into multiple vaults in a single transaction
    """
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(private_key)

    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )
    wtrust = w3.eth.contract(
        address=Web3.to_checksum_address(WTRUST_ADDRESS),
        abi=ERC20_ABI
    )

    vault_count = len(term_ids)
    print(f'Batch depositing into {vault_count} vaults')

    # Validate all vaults exist
    for i, term_id in enumerate(term_ids):
        exists = multivault.functions.isTermCreated(term_id).call()
        if not exists:
            raise ValueError(f'Vault {i} does not exist')

    # Preview all deposits
    print('Previewing deposits...')
    previews = []
    for i in range(vault_count):
        shares, assets_after_fees = multivault.functions.previewDeposit(
            term_ids[i],
            curve_ids[i],
            amounts[i]
        ).call()

        print(f'Vault {i}:')
        print(f'  Assets: {Web3.from_wei(amounts[i], "ether")} WTRUST')
        print(f'  Expected shares: {Web3.from_wei(shares, "ether")}')

        previews.append((shares, assets_after_fees))

    # Calculate minimum shares
    min_shares = [(s * (10000 - slippage_bps)) // 10000 for s, _ in previews]

    # Calculate total deposit
    total_deposit = sum(amounts)
    print(f'\nTotal deposit: {Web3.from_wei(total_deposit, "ether")} WTRUST')

    # Approve total amount
    print('Approving WTRUST...')
    approve_tx = wtrust.functions.approve(
        MULTIVAULT_ADDRESS,
        total_deposit
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 100000,
        'gasPrice': w3.eth.gas_price
    })

    signed_approve = account.sign_transaction(approve_tx)
    approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
    w3.eth.wait_for_transaction_receipt(approve_hash)
    print('Approval confirmed')

    # Execute batch deposit
    print('\nExecuting batch deposit...')
    deposit_tx = multivault.functions.depositBatch(
        receiver,
        term_ids,
        curve_ids,
        amounts,
        min_shares
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000 + (vault_count * 150000),
        'gasPrice': w3.eth.gas_price
    })

    signed_deposit = account.sign_transaction(deposit_tx)
    deposit_hash = w3.eth.send_raw_transaction(signed_deposit.raw_transaction)
    print(f'Transaction sent: {deposit_hash.hex()}')

    receipt = w3.eth.wait_for_transaction_receipt(deposit_hash)
    print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

    # Parse events
    deposit_events = multivault.events.Deposited().process_receipt(receipt)

    shares_minted = []
    total_shares = 0

    print('\nDeposit Results:')
    for i, event in enumerate(deposit_events):
        shares = event['args']['shares']
        shares_minted.append(shares)
        total_shares += shares

        print(f'Vault {i}:')
        print(f'  Shares minted: {Web3.from_wei(shares, "ether")}')

    return {
        'shares_minted': shares_minted,
        'total_assets': total_deposit,
        'total_shares': total_shares,
        'tx_hash': receipt['transactionHash'].hex()
    }


def batch_redeem(
    term_ids: List[bytes],
    curve_ids: List[int],
    shares: List[int],
    slippage_bps: int,
    receiver: str,
    private_key: str
) -> Dict:
    """
    Redeems shares from multiple vaults in a single transaction
    """
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(private_key)
    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )

    vault_count = len(term_ids)
    print(f'Batch redeeming from {vault_count} vaults')

    # Preview redemptions
    previews = []
    for i in range(vault_count):
        assets_after_fees, shares_used = multivault.functions.previewRedeem(
            term_ids[i],
            curve_ids[i],
            shares[i]
        ).call()

        previews.append((assets_after_fees, shares_used))

    # Calculate minimum assets
    min_assets = [(a * (10000 - slippage_bps)) // 10000 for a, _ in previews]

    # Execute batch redemption
    redeem_tx = multivault.functions.redeemBatch(
        receiver,
        term_ids,
        curve_ids,
        shares,
        min_assets
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 400000 + (vault_count * 120000),
        'gasPrice': w3.eth.gas_price
    })

    signed_redeem = account.sign_transaction(redeem_tx)
    redeem_hash = w3.eth.send_raw_transaction(signed_redeem.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(redeem_hash)

    # Parse events
    redeem_events = multivault.events.Redeemed().process_receipt(receipt)

    assets_received = []
    total_assets = 0

    for event in redeem_events:
        assets = event['args']['assets']
        assets_received.append(assets)
        total_assets += assets

    return {
        'assets_received': assets_received,
        'total_assets': total_assets,
        'tx_hash': receipt['transactionHash'].hex()
    }


if __name__ == '__main__':
    result = batch_deposit(
        term_ids=[bytes.fromhex('1234...'), bytes.fromhex('5678...')],
        curve_ids=[1, 1],
        amounts=[Web3.to_wei(10, 'ether'), Web3.to_wei(20, 'ether')],
        slippage_bps=50,
        receiver='0xYourAddress',
        private_key='YOUR_PRIVATE_KEY'
    )

    print(f'\nBatch deposit successful!')
    print(f'Total shares: {Web3.from_wei(result["total_shares"], "ether")}')
```

## Event Monitoring

Batch operations emit the same events as individual operations, but multiple times:

- **Deposited**: One per vault deposited into
- **Redeemed**: One per vault redeemed from
- **SharePriceChanged**: One per vault affected
- **ProtocolFeeAccrued**: Per fee charged
- **Utilization events**: Per vault affected

## Error Handling

### Common Errors

1. **Array Length Mismatch**: All parameter arrays must have the same length
2. **Vault Not Found**: One or more termIds don't exist
3. **Insufficient Balance**: Not enough WTRUST for total deposit
4. **Insufficient Shares**: Not enough shares in one or more vaults
5. **Slippage Exceeded**: One or more operations hit slippage protection
6. **Gas Limit**: Batch too large, reduce vault count

## Gas Estimation

### Typical Gas Costs

| Operation | Gas Used | Notes |
|-----------|----------|-------|
| 2-vault batch deposit | ~650,000 | Saves ~150k vs separate txs |
| 5-vault batch deposit | ~1,400,000 | Saves ~600k vs separate txs |
| 2-vault batch redeem | ~450,000 | Saves ~200k vs separate txs |
| 5-vault batch redeem | ~1,000,000 | Saves ~500k vs separate txs |

**Gas savings**: ~25-30% compared to individual transactions

## Best Practices

### 1. Validate Before Batching
```typescript
// Check all vaults exist
for (const termId of termIds) {
  if (!await multiVault.isTermCreated(termId)) {
    throw new Error(`Invalid termId: ${termId}`);
  }
}
```

### 2. Optimize Batch Size
```typescript
// Don't exceed gas limits
const MAX_BATCH_SIZE = 10; // Adjust based on gas limits
if (termIds.length > MAX_BATCH_SIZE) {
  // Split into multiple batches
}
```

### 3. Use Preview Functions
```typescript
// Preview all operations first
const previews = await Promise.all(
  termIds.map((id, i) =>
    multiVault.previewDeposit(id, curveIds[i], amounts[i])
  )
);
```

### 4. Set Appropriate Slippage
```typescript
// Higher slippage for volatile vaults
const minShares = previews.map((p, i) => {
  const slippage = isVolatile[i] ? 100 : 50; // 1% vs 0.5%
  return (p.shares * BigInt(10000 - slippage)) / 10000n;
});
```

### 5. Handle Partial Failures
```typescript
// Batch operations are atomic - all succeed or all fail
// If one vault fails slippage, entire batch reverts
// Consider splitting batches by risk level
```

## Common Pitfalls

1. **Not approving enough**: Approve sum of all deposits
2. **Mismatched array lengths**: Ensure all arrays same size
3. **Gas limit too low**: Scale gas limit with batch size
4. **Ignoring atomicity**: One failure = whole batch fails
5. **Over-batching**: Too many vaults exceeds gas limit

## Related Operations

- [Depositing Assets](./depositing-assets.md)
- [Redeeming Shares](./redeeming-shares.md)
- [Fee Structure](./fee-structure.md)

## See Also

- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [MultiVault Contract](../contracts/core/MultiVault.md)

---

**Last Updated**: December 2025
