# Wallet Integration

## Overview

Every atom in the Intuition Protocol has an associated ERC-4337 smart contract wallet (AtomWallet). These wallets can hold assets, execute transactions, and their ownership can be claimed by the address encoded in the atom data. Additionally, atom wallet owners earn fees from all deposits into their atom's vault.

This guide covers how to work with atom wallets, claim ownership, and collect accumulated fees.

**Key Features**:
- ERC-4337 compliant smart accounts
- Ownership claimable if atom data is an address
- Earn fees on all atom vault deposits
- Can hold and manage assets
- Deployed deterministically per atom

## Prerequisites

### Required Knowledge
- Understanding of [atoms](../concepts/atoms-and-triples.md)
- Familiarity with ERC-4337 account abstraction
- Knowledge of [fee structure](./fee-structure.md)

### Contracts Needed
- **AtomWarden**: Manages wallet ownership claims
  - Mainnet: Check deployment addresses
- **MultiVault**: For fee claiming and atom wallet address lookup
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
- **AtomWallet**: Individual atom wallet instances
  - Addresses computed deterministically

### Key Parameters
- `atomId`: The atom whose wallet you want to interact with
- `newOwner`: Address to transfer ownership to

## Atom Wallet Mechanics

### Wallet Creation

**When**: AtomWallets are deployed automatically when an atom is created

**How**: Deployed via CREATE2 for deterministic addresses

**Initial Owner**: AtomWarden contract (temporary custodian)

**Address Calculation**:
```typescript
const atomWalletAddress = await multiVault.computeAtomWalletAddr(atomId);
```

### Fee Accumulation

**Source**: Atom wallet deposit fees charged on every atom vault deposit

**Rate**: Configured in `AtomConfig.atomWalletDepositFee` (~0.1-0.5%)

**Calculation**: `depositAmount * atomWalletDepositFee / feeDenominator`

**Accrual**: Fees accumulate per atom, claimable by wallet owner

### Ownership Model

**Initial State**: Owned by AtomWarden contract

**Claiming**: If atom data is an Ethereum address, that address can claim ownership

**Two-Step Transfer**: Uses Ownable2Step pattern for security

**Verification**: AtomWarden verifies atom data matches claimant address

## Step-by-Step Guide

### Step 1: Compute Atom Wallet Address

```typescript
const atomId = await multiVault.calculateAtomId(atomData);
const atomWalletAddress = await multiVault.computeAtomWalletAddr(atomId);

console.log('Atom ID:', atomId);
console.log('Atom Wallet:', atomWalletAddress);
```

### Step 2: Check Current Owner

```typescript
const atomWallet = new ethers.Contract(
  atomWalletAddress,
  AtomWalletABI,
  provider
);

const currentOwner = await atomWallet.owner();

console.log('Current owner:', currentOwner);
console.log('Is AtomWarden?:', currentOwner === ATOM_WARDEN_ADDRESS);
```

### Step 3: Check if You Can Claim Ownership

For ownership claiming to work, the atom data must be your Ethereum address:

```typescript
// Check if atom data is an address
const atomData = await multiVault.getAtom(atomId);

// Try to parse as address
let isAddress = false;
let atomAddress = '';

try {
  // If atom data is 20 bytes, it might be an address
  if (atomData.length === 42 && atomData.startsWith('0x')) {
    atomAddress = ethers.getAddress(atomData);
    isAddress = true;
  }
} catch {
  // Not a valid address
  isAddress = false;
}

if (isAddress && atomAddress === myAddress) {
  console.log('You can claim ownership of this atom wallet!');
} else {
  console.log('Cannot claim - atom data is not your address');
}
```

### Step 4: Claim Atom Wallet Ownership

If atom data is your address, claim ownership via AtomWarden:

```typescript
const atomWarden = new ethers.Contract(
  ATOM_WARDEN_ADDRESS,
  AtomWardenABI,
  signer
);

// Claim ownership (only works if atom data is your address)
const claimTx = await atomWarden.claimOwnershipOverAddressAtom(atomId);
const receipt = await claimTx.wait();

console.log('Ownership claimed!');
console.log('Transaction:', receipt.hash);

// Verify new owner
const newOwner = await atomWallet.owner();
console.log('New owner:', newOwner);
```

### Step 5: Check Accumulated Fees

Fees are tracked internally in MultiVault, not visible on-chain until claimed:

```typescript
// There's no direct getter for accumulated fees
// You need to track AtomWalletDepositFeeCollected events

const filter = multiVault.filters.AtomWalletDepositFeeCollected(atomId);
const events = await multiVault.queryFilter(filter);

let totalFeesAccumulated = 0n;

for (const event of events) {
  totalFeesAccumulated += event.args.amount;
}

console.log('Total fees accumulated:', ethers.formatEther(totalFeesAccumulated), 'WTRUST');

// Check if any fees have been claimed
const claimedFilter = multiVault.filters.AtomWalletDepositFeesClaimed(atomId);
const claimedEvents = await multiVault.queryFilter(claimedFilter);

let totalFeesClaimed = 0n;

for (const event of claimedEvents) {
  totalFeesClaimed += event.args.feesClaimed;
}

const unclaimedFees = totalFeesAccumulated - totalFeesClaimed;

console.log('Total fees claimed:', ethers.formatEther(totalFeesClaimed), 'WTRUST');
console.log('Unclaimed fees:', ethers.formatEther(unclaimedFees), 'WTRUST');
```

### Step 6: Claim Accumulated Fees

Only the atom wallet owner can claim fees:

```typescript
const currentOwner = await atomWallet.owner();

if (currentOwner !== myAddress) {
  throw new Error('You are not the atom wallet owner');
}

// Claim fees
const claimFeesTx = await multiVault.claimAtomWalletDepositFees(atomId);
const receipt = await claimFeesTx.wait();

console.log('Fees claimed!');

// Parse event to see amount
const claimedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event && event.name === 'AtomWalletDepositFeesClaimed');

if (claimedEvent) {
  console.log('Amount claimed:', ethers.formatEther(claimedEvent.args.feesClaimed), 'WTRUST');
}
```

### Step 7: Transfer Ownership

If you own an atom wallet, you can transfer ownership:

```typescript
// Two-step process for safety
// Step 1: Initiate transfer
const transferTx = await atomWallet.transferOwnership(newOwnerAddress);
await transferTx.wait();

console.log('Ownership transfer initiated to:', newOwnerAddress);

// Step 2: New owner must accept
// (New owner calls acceptOwnership on AtomWallet)
```

### Step 8: Monitor Fee Collections

Track when fees are collected for your atom:

```typescript
// Listen for fee collection events
multiVault.on('AtomWalletDepositFeeCollected', (termId, sender, amount, event) => {
  if (termId === myAtomId) {
    console.log('Fee collected!');
    console.log('From:', sender);
    console.log('Amount:', ethers.formatEther(amount), 'WTRUST');
    console.log('Block:', event.log.blockNumber);
  }
});
```

## Code Examples

### TypeScript (ethers.js v6)

Complete atom wallet management utility:

```typescript
import { ethers } from 'ethers';

interface AtomWalletInfo {
  atomId: string;
  walletAddress: string;
  currentOwner: string;
  isOwnedByWarden: boolean;
  canClaim: boolean;
  accumulatedFees: bigint;
  claimedFees: bigint;
  unclaimedFees: bigint;
}

class AtomWalletManager {
  private multiVault: ethers.Contract;
  private atomWarden: ethers.Contract;

  constructor(
    multiVaultAddress: string,
    atomWardenAddress: string,
    provider: ethers.Provider
  ) {
    this.multiVault = new ethers.Contract(
      multiVaultAddress,
      MultiVaultABI,
      provider
    );
    this.atomWarden = new ethers.Contract(
      atomWardenAddress,
      AtomWardenABI,
      provider
    );
  }

  /**
   * Get comprehensive atom wallet information
   */
  async getWalletInfo(
    atomId: string,
    userAddress: string
  ): Promise<AtomWalletInfo> {
    // Get wallet address
    const walletAddress = await this.multiVault.computeAtomWalletAddr(atomId);

    // Get wallet contract
    const atomWallet = new ethers.Contract(
      walletAddress,
      AtomWalletABI,
      this.multiVault.runner
    );

    // Get current owner
    const currentOwner = await atomWallet.owner();

    // Get atom data to check if address
    const atomData = await this.multiVault.getAtom(atomId);

    // Check if user can claim
    let canClaim = false;
    try {
      if (atomData.length === 42 && atomData.startsWith('0x')) {
        const atomAddress = ethers.getAddress(atomData);
        const wardenAddress = await this.multiVault.getAtomWarden();
        canClaim = atomAddress === userAddress && currentOwner === wardenAddress;
      }
    } catch {
      canClaim = false;
    }

    // Calculate accumulated fees
    const [accumulatedFees, claimedFees] = await this.calculateFees(atomId);

    return {
      atomId,
      walletAddress,
      currentOwner,
      isOwnedByWarden: currentOwner === await this.multiVault.getAtomWarden(),
      canClaim,
      accumulatedFees,
      claimedFees,
      unclaimedFees: accumulatedFees - claimedFees
    };
  }

  /**
   * Calculate accumulated and claimed fees
   */
  async calculateFees(atomId: string): Promise<[bigint, bigint]> {
    // Get accumulated fees
    const collectedFilter = this.multiVault.filters.AtomWalletDepositFeeCollected(atomId);
    const collectedEvents = await this.multiVault.queryFilter(collectedFilter);

    let accumulated = 0n;
    for (const event of collectedEvents) {
      accumulated += event.args.amount;
    }

    // Get claimed fees
    const claimedFilter = this.multiVault.filters.AtomWalletDepositFeesClaimed(atomId);
    const claimedEvents = await this.multiVault.queryFilter(claimedFilter);

    let claimed = 0n;
    for (const event of claimedEvents) {
      claimed += event.args.feesClaimed;
    }

    return [accumulated, claimed];
  }

  /**
   * Claim ownership if eligible
   */
  async claimOwnership(
    atomId: string,
    signer: ethers.Signer
  ): Promise<string> {
    const userAddress = await signer.getAddress();
    const info = await this.getWalletInfo(atomId, userAddress);

    if (!info.canClaim) {
      throw new Error('Not eligible to claim ownership');
    }

    const atomWardenWithSigner = this.atomWarden.connect(signer);

    const tx = await atomWardenWithSigner.claimOwnershipOverAddressAtom(atomId);
    const receipt = await tx.wait();

    console.log('Ownership claimed successfully');

    return receipt.hash;
  }

  /**
   * Claim accumulated fees
   */
  async claimFees(
    atomId: string,
    signer: ethers.Signer
  ): Promise<{
    amountClaimed: bigint;
    txHash: string;
  }> {
    const userAddress = await signer.getAddress();
    const info = await this.getWalletInfo(atomId, userAddress);

    if (info.currentOwner !== userAddress) {
      throw new Error('Not the atom wallet owner');
    }

    if (info.unclaimedFees === 0n) {
      throw new Error('No fees to claim');
    }

    const multiVaultWithSigner = this.multiVault.connect(signer);

    const tx = await multiVaultWithSigner.claimAtomWalletDepositFees(atomId);
    const receipt = await tx.wait();

    // Parse event
    const claimedEvent = receipt.logs
      .map(log => {
        try {
          return this.multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find(event => event && event.name === 'AtomWalletDepositFeesClaimed');

    const amountClaimed = claimedEvent?.args.feesClaimed || 0n;

    console.log('Fees claimed:', ethers.formatEther(amountClaimed), 'WTRUST');

    return {
      amountClaimed,
      txHash: receipt.hash
    };
  }

  /**
   * Monitor fee collections
   */
  async monitorFees(
    atomId: string,
    callback: (event: any) => void
  ) {
    this.multiVault.on(
      'AtomWalletDepositFeeCollected',
      (termId, sender, amount, event) => {
        if (termId === atomId) {
          callback({
            termId,
            sender,
            amount,
            block: event.log.blockNumber,
            tx: event.log.transactionHash
          });
        }
      }
    );
  }

  /**
   * Format wallet info for display
   */
  formatWalletInfo(info: AtomWalletInfo): string {
    return `
=== Atom Wallet Info ===
Atom ID: ${info.atomId}
Wallet Address: ${info.walletAddress}
Current Owner: ${info.currentOwner}
Owned by Warden: ${info.isOwnedByWarden}
Can Claim Ownership: ${info.canClaim}

=== Fee Information ===
Accumulated Fees: ${ethers.formatEther(info.accumulatedFees)} WTRUST
Claimed Fees: ${ethers.formatEther(info.claimedFees)} WTRUST
Unclaimed Fees: ${ethers.formatEther(info.unclaimedFees)} WTRUST
    `.trim();
  }
}

// Usage example
async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(PRIVATE_KEY, provider);

  const manager = new AtomWalletManager(
    MULTIVAULT_ADDRESS,
    ATOM_WARDEN_ADDRESS,
    provider
  );

  // Get wallet info
  const atomId = '0x...'; // Your atom ID
  const info = await manager.getWalletInfo(atomId, await signer.getAddress());

  console.log(manager.formatWalletInfo(info));

  // Claim ownership if eligible
  if (info.canClaim) {
    console.log('\nClaiming ownership...');
    const txHash = await manager.claimOwnership(atomId, signer);
    console.log('Claimed! Transaction:', txHash);
  }

  // Claim fees if available
  if (info.unclaimedFees > 0n) {
    console.log('\nClaiming fees...');
    const result = await manager.claimFees(atomId, signer);
    console.log('Claimed:', ethers.formatEther(result.amountClaimed), 'WTRUST');
  }

  // Monitor fee collections
  await manager.monitorFees(atomId, (event) => {
    console.log('\nNew fee collected!');
    console.log('Amount:', ethers.formatEther(event.amount), 'WTRUST');
    console.log('From:', event.sender);
  });
}

if (require.main === module) {
  main();
}
```

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
import json

class AtomWalletManager:
    def __init__(self, multivault_address: str, atom_warden_address: str, rpc_url: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))

        with open('abis/IMultiVault.json') as f:
            multivault_abi = json.load(f)
        with open('abis/IAtomWarden.json') as f:
            atom_warden_abi = json.load(f)

        self.multivault = self.w3.eth.contract(
            address=Web3.to_checksum_address(multivault_address),
            abi=multivault_abi
        )
        self.atom_warden = self.w3.eth.contract(
            address=Web3.to_checksum_address(atom_warden_address),
            abi=atom_warden_abi
        )

    def get_wallet_info(self, atom_id: bytes, user_address: str) -> dict:
        """Get comprehensive atom wallet information"""
        # Get wallet address
        wallet_address = self.multivault.functions.computeAtomWalletAddr(
            atom_id
        ).call()

        # Get current owner (would need AtomWallet ABI)
        # For now, return basic info
        return {
            'atom_id': atom_id.hex(),
            'wallet_address': wallet_address
        }

    def calculate_fees(self, atom_id: bytes) -> tuple:
        """Calculate accumulated and claimed fees"""
        # Get accumulated fees
        collected_events = self.multivault.events.AtomWalletDepositFeeCollected.create_filter(
            fromBlock=0,
            argument_filters={'termId': atom_id}
        ).get_all_entries()

        accumulated = sum(event['args']['amount'] for event in collected_events)

        # Get claimed fees
        claimed_events = self.multivault.events.AtomWalletDepositFeesClaimed.create_filter(
            fromBlock=0,
            argument_filters={'termId': atom_id}
        ).get_all_entries()

        claimed = sum(event['args']['feesClaimed'] for event in claimed_events)

        return accumulated, claimed

    def claim_fees(self, atom_id: bytes, private_key: str) -> str:
        """Claim accumulated fees"""
        account = Account.from_key(private_key)

        # Check unclaimed fees
        accumulated, claimed = self.calculate_fees(atom_id)
        unclaimed = accumulated - claimed

        if unclaimed == 0:
            raise ValueError('No fees to claim')

        # Build and send transaction
        tx = self.multivault.functions.claimAtomWalletDepositFees(
            atom_id
        ).build_transaction({
            'from': account.address,
            'nonce': self.w3.eth.get_transaction_count(account.address),
            'gas': 200000,
            'gasPrice': self.w3.eth.gas_price
        })

        signed_tx = account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        return receipt['transactionHash'].hex()

if __name__ == '__main__':
    manager = AtomWalletManager(
        '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e',
        '0x...',  # AtomWarden address
        'YOUR_RPC_URL'
    )

    atom_id = bytes.fromhex('1234...')

    # Calculate fees
    accumulated, claimed = manager.calculate_fees(atom_id)
    unclaimed = accumulated - claimed

    print(f'Accumulated: {Web3.from_wei(accumulated, "ether")} WTRUST')
    print(f'Claimed: {Web3.from_wei(claimed, "ether")} WTRUST')
    print(f'Unclaimed: {Web3.from_wei(unclaimed, "ether")} WTRUST')

    # Claim if available
    if unclaimed > 0:
        tx_hash = manager.claim_fees(atom_id, 'YOUR_PRIVATE_KEY')
        print(f'Fees claimed! Transaction: {tx_hash}')
```

## Event Monitoring

### Events Emitted

#### AtomWalletDepositFeeCollected
```solidity
event AtomWalletDepositFeeCollected(
    bytes32 indexed termId,
    address indexed sender,
    uint256 amount
);
```

#### AtomWalletDepositFeesClaimed
```solidity
event AtomWalletDepositFeesClaimed(
    bytes32 indexed termId,
    address indexed atomWalletOwner,
    uint256 indexed feesClaimed
);
```

#### AtomWalletOwnershipClaimed
```solidity
event AtomWalletOwnershipClaimed(
    bytes32 atomId,
    address pendingOwner
);
```

## Common Errors

1. **AtomWarden_AtomIdDoesNotExist**: Atom hasn't been created
2. **AtomWarden_InvalidAddress**: Atom data is not a valid address
3. **AtomWarden_ClaimOwnershipFailed**: Not eligible to claim
4. **No fees to claim**: Unclaimed fees are zero

## Best Practices

1. **Claim fees regularly**: Don't let fees accumulate indefinitely
2. **Monitor fee events**: Track when fees are collected
3. **Verify ownership**: Always check current owner before operations
4. **Use address atoms**: Create atoms with your address as data to claim wallet
5. **Secure wallets**: Atom wallets can hold valuable assets

## Common Pitfalls

1. **Not claiming fees**: Forgetting accumulated fees exist
2. **Wrong atom data**: Creating atoms without address data
3. **Missing ownership transfer**: Not accepting ownership transfers
4. **Ignoring wallet assets**: Atom wallets can hold tokens/NFTs
5. **Not tracking events**: Missing fee collection notifications

## Related Operations

- [Creating Atoms](./creating-atoms.md) - Creates associated wallet
- [Depositing Assets](./depositing-assets.md) - Generates wallet fees
- [Fee Structure](./fee-structure.md) - Understanding wallet fees

## See Also

- [Smart Wallets Concept](../concepts/smart-wallets.md)
- [AtomWallet Contract](../contracts/wallet/AtomWallet.md)
- [AtomWarden Contract](../contracts/wallet/AtomWarden.md)

---

**Last Updated**: December 2025
