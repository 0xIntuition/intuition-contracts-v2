# Depositing Assets

## Overview

Depositing assets into existing vaults is the primary way to take positions in atoms and triples. Unlike creating new terms, depositing into existing vaults doesn't require minimum deposits and works with any vault that has already been created.

This guide covers how to deposit native TRUST into atom, triple, and counter-triple vaults using TypeScript and Python.

**When to use this operation**:
- Taking a position in an existing atom or triple
- Supporting or opposing a claim (triple vs counter-triple)
- Increasing your vault share balance
- Participating in protocol rewards through utilization

## Prerequisites

### Required Knowledge
- Understanding of [vaults and shares](../concepts/multi-vault-pattern.md)
- Basic knowledge of [bonding curves](../concepts/bonding-curves.md)
- Familiarity with sending native tokens via payable functions

### Contracts Needed
- **MultiVault**: Main contract for deposits
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`

### Tokens Required
- Native TRUST for deposit (sent as msg.value)
- Native ETH for gas fees

### Key Parameters
- `receiver`: Address to receive the minted shares
- `termId`: bytes32 ID of the atom or triple
- `curveId`: Bonding curve ID (typically 1 for linear curve)
- `minShares`: Minimum shares expected (slippage protection)

## Step-by-Step Guide

### Step 1: Identify the Vault

Determine the term ID and curve ID for the vault you want to deposit into.

```typescript
// For atoms: calculate from data
const atomId = await multiVault.calculateAtomId(atomData);

// For triples: calculate from atom IDs
const tripleId = await multiVault.calculateTripleId(subjectId, predicateId, objectId);

// For counter triples: get inverse of triple ID
const counterTripleId = await multiVault.getCounterIdFromTripleId(tripleId);

// Curve ID is typically 1 for the default linear curve
const curveId = 1;
```

### Step 2: Check Vault Exists

Verify the term has been created:

```typescript
const exists = await multiVault.isTermCreated(termId);
if (!exists) {
  throw new Error('Vault does not exist');
}
```

### Step 3: Preview the Deposit

Simulate the deposit to see expected shares:

```typescript
const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
  termId,
  curveId,
  depositAmount
);

console.log('Expected shares:', ethers.formatEther(expectedShares));
console.log('Assets after fees:', ethers.formatEther(assetsAfterFees));
```

### Step 4: Set Minimum Shares (Slippage Protection)

Calculate acceptable slippage:

```typescript
const slippageBps = 50; // 0.5% slippage tolerance
const minShares = expectedShares * (10000n - BigInt(slippageBps)) / 10000n;
```

### Step 5: Execute Deposit

Call the `deposit` function:

```typescript
const tx = await multiVault.deposit(
  receiverAddress,
  termId,
  curveId,
  minShares,
  { value: depositAmount } // Send native TRUST with transaction
);
const receipt = await tx.wait();
```

### Step 6: Verify Shares Received

Parse the `Deposited` event to confirm:

```typescript
const depositedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event.name === 'Deposited');

const sharesMinted = depositedEvent.args.shares;
console.log('Shares minted:', ethers.formatEther(sharesMinted));
```

## Code Examples

### TypeScript (ethers.js v6)

Complete deposit example with error handling:

```typescript
import { ethers } from 'ethers';

// ABIs
import MultiVaultABI from './abis/IMultiVault.json';
import ERC20ABI from './abis/ERC20.json';

// Configuration
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

/**
 * Deposits assets into a vault
 */
async function depositToVault(
  termId: string,
  curveId: number,
  depositAmount: bigint,
  slippageBps: number,
  privateKey: string,
  receiverAddress?: string
): Promise<{
  sharesMinted: bigint;
  assetsDeposited: bigint;
  txHash: string;
}> {
  // Setup
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);

  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MultiVaultABI,
    wallet
  );

  // Default receiver is the sender
  const receiver = receiverAddress || wallet.address;

  try {
    // Step 1: Validate inputs
    if (!ethers.isHexString(termId, 32)) {
      throw new Error('Invalid term ID format (must be 32-byte hex string)');
    }

    if (depositAmount <= 0n) {
      throw new Error('Deposit amount must be greater than zero');
    }

    if (slippageBps < 0 || slippageBps > 10000) {
      throw new Error('Slippage must be between 0 and 10000 basis points');
    }

    // Step 2: Check vault exists
    const exists = await multiVault.isTermCreated(termId);
    if (!exists) {
      throw new Error(`Vault does not exist for term ID: ${termId}`);
    }

    // Step 3: Get vault info
    const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
    console.log('Vault state:');
    console.log('  Total assets:', ethers.formatEther(totalAssets));
    console.log('  Total shares:', ethers.formatEther(totalShares));

    // Step 4: Preview the deposit
    const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
      termId,
      curveId,
      depositAmount
    );

    console.log('Deposit preview:');
    console.log('  Depositing:', ethers.formatEther(depositAmount), 'TRUST');
    console.log('  Expected shares:', ethers.formatEther(expectedShares));
    console.log('  Assets after fees:', ethers.formatEther(assetsAfterFees));

    // Calculate fees
    const totalFees = depositAmount - assetsAfterFees;
    console.log('  Total fees:', ethers.formatEther(totalFees), 'TRUST');

    // Step 5: Calculate minimum shares with slippage protection
    const minShares = expectedShares * (10000n - BigInt(slippageBps)) / 10000n;
    console.log('  Minimum shares:', ethers.formatEther(minShares));
    console.log('  Slippage tolerance:', slippageBps / 100, '%');

    // Step 6: Execute deposit
    console.log('Executing deposit...');

    const depositTx = await multiVault.deposit(
      receiver,
      termId,
      curveId,
      minShares,
      {
        value: depositAmount,
        gasLimit: 400000n
      }
    );

    console.log('Transaction sent:', depositTx.hash);
    const receipt = await depositTx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 7: Parse events
    let sharesMinted = 0n;
    let actualAssetsDeposited = 0n;

    for (const log of receipt.logs) {
      try {
        const parsed = multiVault.interface.parseLog({
          topics: log.topics,
          data: log.data
        });

        if (parsed.name === 'Deposited') {
          sharesMinted = parsed.args.shares;
          actualAssetsDeposited = parsed.args.assets;

          console.log('Deposit successful!');
          console.log('  Shares minted:', ethers.formatEther(sharesMinted));
          console.log('  Total shares now:', ethers.formatEther(parsed.args.totalShares));
          console.log('  Vault type:', ['ATOM', 'TRIPLE', 'COUNTER_TRIPLE'][parsed.args.vaultType]);
        }
      } catch (e) {
        // Not a MultiVault event, skip
      }
    }

    if (sharesMinted === 0n) {
      throw new Error('Deposited event not found in receipt');
    }

    // Verify slippage protection worked
    if (sharesMinted < minShares) {
      throw new Error(
        `Slippage too high! Expected >= ${ethers.formatEther(minShares)}, ` +
        `got ${ethers.formatEther(sharesMinted)}`
      );
    }

    return {
      sharesMinted,
      assetsDeposited: actualAssetsDeposited,
      txHash: receipt.hash
    };

  } catch (error) {
    if (error.code === 'INSUFFICIENT_FUNDS') {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.code === 'CALL_EXCEPTION') {
      throw new Error(`Contract call failed: ${error.reason || error.message}`);
    } else if (error.message?.includes('slippage')) {
      throw new Error('Transaction would result in excessive slippage');
    }

    throw error;
  }
}

/**
 * Helper: Deposit into multiple vaults at once
 */
async function depositBatch(
  deposits: Array<{
    termId: string;
    curveId: number;
    amount: bigint;
    minShares: bigint;
  }>,
  privateKey: string,
  receiverAddress?: string
) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MultiVaultABI, wallet);

  const receiver = receiverAddress || wallet.address;

  // Extract arrays for batch call
  const termIds = deposits.map(d => d.termId);
  const curveIds = deposits.map(d => d.curveId);
  const amounts = deposits.map(d => d.amount);
  const minSharesArray = deposits.map(d => d.minShares);

  // Calculate total amount needed
  const totalAmount = amounts.reduce((sum, amt) => sum + amt, 0n);

  // Execute batch deposit
  const tx = await multiVault.depositBatch(
    receiver,
    termIds,
    curveIds,
    amounts,
    minSharesArray,
    {
      value: totalAmount,
      gasLimit: 1000000n // Higher limit for batch
    }
  );

  const receipt = await tx.wait();

  // Parse all Deposited events
  const results = [];
  for (const log of receipt.logs) {
    try {
      const parsed = multiVault.interface.parseLog({
        topics: log.topics,
        data: log.data
      });

      if (parsed.name === 'Deposited') {
        results.push({
          termId: parsed.args.termId,
          shares: parsed.args.shares,
          assets: parsed.args.assets
        });
      }
    } catch (e) {}
  }

  return results;
}

// Usage example
async function main() {
  try {
    // Single deposit
    const result = await depositToVault(
      '0x...', // term ID
      1,       // curve ID (linear)
      ethers.parseEther("25"), // 25 TRUST
      50,      // 0.5% slippage tolerance
      'YOUR_PRIVATE_KEY'
    );

    console.log('\nDeposit successful!');
    console.log('Shares minted:', ethers.formatEther(result.sharesMinted));
    console.log('Transaction:', result.txHash);

    // Batch deposit
    const batchResults = await depositBatch(
      [
        { termId: '0x...', curveId: 1, amount: ethers.parseEther("10"), minShares: 0n },
        { termId: '0x...', curveId: 1, amount: ethers.parseEther("20"), minShares: 0n },
        { termId: '0x...', curveId: 1, amount: ethers.parseEther("15"), minShares: 0n }
      ],
      'YOUR_PRIVATE_KEY'
    );

    console.log('\nBatch deposit successful!');
    console.log('Deposits completed:', batchResults.length);

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

Complete deposit example:

```python
from web3 import Web3
from eth_account import Account
from typing import Dict, List
import json

# Configuration
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
RPC_URL = 'YOUR_INTUITION_RPC_URL'

# Load ABIs
with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)


def deposit_to_vault(
    term_id: str,
    curve_id: int,
    deposit_amount: int,
    slippage_bps: int,
    private_key: str,
    receiver_address: str = None
) -> Dict[str, any]:
    """
    Deposits assets into a vault

    Args:
        term_id: Hex string of term ID (32 bytes)
        curve_id: Bonding curve ID (typically 1)
        deposit_amount: Amount of WTRUST to deposit (in wei)
        slippage_bps: Slippage tolerance in basis points (e.g., 50 = 0.5%)
        private_key: Private key for signing
        receiver_address: Optional address to receive shares (defaults to sender)

    Returns:
        Dictionary with shares_minted, assets_deposited, tx_hash

    Raises:
        ValueError: If parameters are invalid
        Exception: If transaction fails
    """
    # Setup
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    if not w3.is_connected():
        raise Exception('Failed to connect to RPC endpoint')

    account = Account.from_key(private_key)
    receiver = receiver_address or account.address

    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )

    try:
        # Step 1: Validate inputs
        try:
            term_bytes = bytes.fromhex(term_id.replace('0x', ''))
            if len(term_bytes) != 32:
                raise ValueError('Term ID must be 32 bytes')
        except:
            raise ValueError('Invalid term ID format')

        if deposit_amount <= 0:
            raise ValueError('Deposit amount must be greater than zero')

        if slippage_bps < 0 or slippage_bps > 10000:
            raise ValueError('Slippage must be between 0 and 10000 basis points')

        # Step 2: Check vault exists
        exists = multivault.functions.isTermCreated(term_bytes).call()
        if not exists:
            raise ValueError(f'Vault does not exist for term ID: {term_id}')

        # Step 3: Get vault info
        total_assets, total_shares = multivault.functions.getVault(
            term_bytes,
            curve_id
        ).call()

        print('Vault state:')
        print(f'  Total assets: {Web3.from_wei(total_assets, "ether")}')
        print(f'  Total shares: {Web3.from_wei(total_shares, "ether")}')

        # Step 4: Preview the deposit
        expected_shares, assets_after_fees = multivault.functions.previewDeposit(
            term_bytes,
            curve_id,
            deposit_amount
        ).call()

        print('Deposit preview:')
        print(f'  Depositing: {Web3.from_wei(deposit_amount, "ether")} TRUST')
        print(f'  Expected shares: {Web3.from_wei(expected_shares, "ether")}')
        print(f'  Assets after fees: {Web3.from_wei(assets_after_fees, "ether")}')

        total_fees = deposit_amount - assets_after_fees
        print(f'  Total fees: {Web3.from_wei(total_fees, "ether")} TRUST')

        # Step 5: Calculate minimum shares
        min_shares = (expected_shares * (10000 - slippage_bps)) // 10000

        print(f'  Minimum shares: {Web3.from_wei(min_shares, "ether")}')
        print(f'  Slippage tolerance: {slippage_bps / 100}%')

        # Step 6: Execute deposit
        print('Executing deposit...')

        deposit_tx = multivault.functions.deposit(
            Web3.to_checksum_address(receiver),
            term_bytes,
            curve_id,
            min_shares
        ).build_transaction({
            'from': account.address,
            'value': deposit_amount,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 400000,
            'gasPrice': w3.eth.gas_price
        })

        signed_deposit = account.sign_transaction(deposit_tx)
        deposit_hash = w3.eth.send_raw_transaction(signed_deposit.raw_transaction)
        print(f'Transaction sent: {deposit_hash.hex()}')

        receipt = w3.eth.wait_for_transaction_receipt(deposit_hash)
        print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

        if receipt['status'] != 1:
            raise Exception('Deposit transaction failed')

        # Step 7: Parse events
        shares_minted = 0
        actual_assets_deposited = 0

        deposited_events = multivault.events.Deposited().process_receipt(receipt)
        if deposited_events:
            event_args = deposited_events[0]['args']
            shares_minted = event_args['shares']
            actual_assets_deposited = event_args['assets']

            print('Deposit successful!')
            print(f'  Shares minted: {Web3.from_wei(shares_minted, "ether")}')
            print(f'  Total shares now: {Web3.from_wei(event_args["totalShares"], "ether")}')

            vault_types = ['ATOM', 'TRIPLE', 'COUNTER_TRIPLE']
            print(f'  Vault type: {vault_types[event_args["vaultType"]]}')

        if shares_minted == 0:
            raise Exception('Deposited event not found in receipt')

        # Verify slippage protection
        if shares_minted < min_shares:
            raise Exception(
                f'Slippage too high! Expected >= {Web3.from_wei(min_shares, "ether")}, '
                f'got {Web3.from_wei(shares_minted, "ether")}'
            )

        return {
            'shares_minted': shares_minted,
            'assets_deposited': actual_assets_deposited,
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
        result = deposit_to_vault(
            term_id='0x...',
            curve_id=1,
            deposit_amount=Web3.to_wei(25, 'ether'),  # 25 TRUST
            slippage_bps=50,  # 0.5% slippage
            private_key='YOUR_PRIVATE_KEY'
        )

        print('\nDeposit successful!')
        print(f'Shares minted: {Web3.from_wei(result["shares_minted"], "ether")}')
        print(f'Transaction: {result["tx_hash"]}')

    except Exception as e:
        print(f'Error: {str(e)}')
        exit(1)
```

## Event Monitoring

### Events Emitted

#### Deposited

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

#### ProtocolFeeAccrued

```solidity
event ProtocolFeeAccrued(
    uint256 indexed epoch,
    address indexed sender,
    uint256 amount
);
```

#### TotalUtilizationAdded / PersonalUtilizationAdded

Emitted when deposits affect utilization tracking for rewards.

### Listening for Deposits

**TypeScript**:
```typescript
multiVault.on('Deposited', (sender, receiver, termId, curveId, assets, assetsAfterFees, shares, totalShares, vaultType, event) => {
  console.log('New deposit:');
  console.log('  Sender:', sender);
  console.log('  Receiver:', receiver);
  console.log('  Term ID:', termId);
  console.log('  Shares:', ethers.formatEther(shares));
});
```

## Error Handling

### Common Errors

1. **Term Does Not Exist**: `MultiVaultCore_TermDoesNotExist()`
2. **Insufficient Allowance**: `ERC20: insufficient allowance`
3. **Slippage Too High**: `MultiVaultCore_MinSharesNotMet()`
4. **Paused Contract**: `Pausable: paused`

### Recovery Strategies

```typescript
try {
  await depositToVault(termId, curveId, amount, slippage, key);
} catch (error) {
  if (error.message.includes('TermDoesNotExist')) {
    // Create the term first
    await createAtom(atomData, amount, key);
  } else if (error.message.includes('MinSharesNotMet')) {
    // Increase slippage tolerance
    await depositToVault(termId, curveId, amount, 100, key);
  }
}
```

## Gas Estimation

| Operation | Gas Used |
|-----------|----------|
| First deposit to vault | ~250,000 |
| Subsequent deposits | ~150,000 |
| Batch (5 deposits) | ~500,000 |

## Best Practices

1. **Always use preview functions** before depositing
2. **Set appropriate slippage** based on vault volatility
3. **Check vault state** to understand price impact
4. **Use batch operations** for multiple deposits
5. **Monitor utilization** for reward eligibility

## Common Pitfalls

1. Not checking if vault exists before depositing
2. Not sending correct msg.value with deposit transaction
3. Not accounting for fees in expected shares
4. Using zero for minShares (no slippage protection)
5. Depositing to wrong curve ID

## Related Operations

- [Creating Atoms](./creating-atoms.md)
- [Creating Triples](./creating-triples.md)
- [Redeeming Shares](./redeeming-shares.md)
- [Batch Operations](./batch-operations.md)

## See Also

- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [Bonding Curves](../concepts/bonding-curves.md)
- [Fee Structure](./fee-structure.md)
- [Utilization Mechanics](./utilization-mechanics.md)

---

**Last Updated**: December 2025
