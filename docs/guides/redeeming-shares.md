# Redeeming Shares

## Overview

Redeeming shares allows you to exit your position in a vault by burning your vault shares and receiving the underlying WTRUST assets. The redemption process follows an ERC-4626-style pattern with bonding curve pricing and multiple fee deductions.

This guide shows you how to redeem shares from atom, triple, and counter-triple vaults programmatically.

**When to use this operation**:
- Exiting a position in an atom or triple vault
- Taking profits or cutting losses
- Rebalancing your portfolio
- Withdrawing liquidity from the protocol

## Prerequisites

### Required Knowledge
- Understanding of vault shares and bonding curves
- Familiarity with ERC-4626 redemption patterns
- Knowledge of [fee structure](./fee-structure.md)
- Understanding of [multi-vault architecture](../concepts/multi-vault-pattern.md)

### Contracts Needed
- **MultiVault**: Main contract for redeeming shares
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`

### Tokens Required
- Vault shares in the specific vault you want to redeem from
- Native ETH for gas fees

### Key Parameters
- `receiver`: Address to receive the redeemed WTRUST assets
- `termId`: Atom or triple ID to redeem from
- `curveId`: Bonding curve ID (typically 1 for default linear curve)
- `shares`: Amount of shares to burn
- `minAssets`: Minimum WTRUST to receive (slippage protection)

## Step-by-Step Guide

### Step 1: Check Your Share Balance

Query your share balance in the specific vault to determine how many shares you can redeem.

```typescript
const shares = await multiVault.getShares(
  userAddress,
  termId,
  curveId
);
```

### Step 2: Preview the Redemption

Simulate the redemption to see how many assets you'll receive after fees.

```typescript
const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
  termId,
  curveId,
  sharesToRedeem
);
```

### Step 3: Check Fee Thresholds

Understand which fees will apply based on the vault state.

```typescript
const generalConfig = await multiVault.getGeneralConfig();
const vaultFees = await multiVault.getVaultFees();
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Exit fees only apply if totalShares > feeThreshold after redemption
const willChargeExitFee = (totalShares - sharesToRedeem) >= generalConfig.feeThreshold;
```

### Step 4: Calculate Minimum Assets

Set a slippage tolerance to protect against unfavorable price movements.

```typescript
const slippageBps = 50; // 0.5% slippage tolerance
const minAssets = (assetsAfterFees * BigInt(10000 - slippageBps)) / 10000n;
```

### Step 5: Verify Maximum Redeemable

Ensure you're not trying to redeem more shares than you have.

```typescript
const maxRedeemable = await multiVault.maxRedeem(
  userAddress,
  termId,
  curveId
);

if (sharesToRedeem > maxRedeemable) {
  throw new Error('Exceeds maximum redeemable shares');
}
```

### Step 6: Execute the Redemption

Call `redeem` to burn shares and receive assets.

```typescript
const tx = await multiVault.redeem(
  receiverAddress,
  termId,
  curveId,
  sharesToRedeem,
  minAssets
);
const receipt = await tx.wait();
```

### Step 7: Parse Redemption Events

Extract redemption details from the transaction receipt.

```typescript
const redeemedEvent = receipt.logs
  .map(log => multiVault.interface.parseLog(log))
  .find(event => event.name === 'Redeemed');

const assetsReceived = redeemedEvent.args.assets;
const feesCharged = redeemedEvent.args.fees;
```

### Step 8: Update Utilization Tracking (Optional)

If you're tracking utilization for rewards, note that redemptions reduce your personal utilization.

```typescript
const currentEpoch = await multiVault.currentEpoch();
const newUtilization = await multiVault.getUserUtilizationForEpoch(
  userAddress,
  currentEpoch
);
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
 * Redeems shares from a vault and returns assets
 */
async function redeemShares(
  termId: string,
  curveId: bigint,
  sharesToRedeem: bigint,
  slippageBps: number,
  privateKey: string
): Promise<{
  assetsReceived: bigint;
  feesCharged: bigint;
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
    // Step 1: Check share balance
    const currentShares = await multiVault.getShares(
      wallet.address,
      termId,
      curveId
    );

    console.log('Current shares:', ethers.formatEther(currentShares));

    if (currentShares === 0n) {
      throw new Error('No shares to redeem');
    }

    if (sharesToRedeem > currentShares) {
      throw new Error(
        `Insufficient shares. Have: ${ethers.formatEther(currentShares)}, ` +
        `Need: ${ethers.formatEther(sharesToRedeem)}`
      );
    }

    // Step 2: Verify maximum redeemable
    const maxRedeemable = await multiVault.maxRedeem(
      wallet.address,
      termId,
      curveId
    );

    if (sharesToRedeem > maxRedeemable) {
      throw new Error(
        `Exceeds maximum redeemable shares. Max: ${ethers.formatEther(maxRedeemable)}`
      );
    }

    // Step 3: Preview the redemption
    const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
      termId,
      curveId,
      sharesToRedeem
    );

    console.log('Expected assets after fees:', ethers.formatEther(assetsAfterFees));
    console.log('Shares to be burned:', ethers.formatEther(sharesUsed));

    // Step 4: Calculate minimum assets with slippage protection
    const minAssets = (assetsAfterFees * BigInt(10000 - slippageBps)) / 10000n;
    console.log('Minimum assets (with slippage):', ethers.formatEther(minAssets));

    // Step 5: Get vault info for fee estimation
    const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
    const generalConfig = await multiVault.getGeneralConfig();
    const vaultFees = await multiVault.getVaultFees();

    const sharesAfterRedemption = totalShares - sharesToRedeem;
    const willChargeExitFee = sharesAfterRedemption >= generalConfig.feeThreshold;

    console.log('Exit fee will be charged:', willChargeExitFee);
    console.log('Protocol fee:', Number(vaultFees.protocolFee) / Number(generalConfig.feeDenominator) * 100, '%');

    if (willChargeExitFee) {
      console.log('Exit fee:', Number(vaultFees.exitFee) / Number(generalConfig.feeDenominator) * 100, '%');
    }

    // Step 6: Check WTRUST balance before redemption
    const balanceBefore = await wtrust.balanceOf(wallet.address);
    console.log('WTRUST balance before:', ethers.formatEther(balanceBefore));

    // Step 7: Execute the redemption
    console.log('Redeeming shares...');
    const redeemTx = await multiVault.redeem(
      wallet.address, // receiver
      termId,
      curveId,
      sharesToRedeem,
      minAssets,
      {
        gasLimit: 400000n // Explicit gas limit
      }
    );

    console.log('Transaction sent:', redeemTx.hash);
    const receipt = await redeemTx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 8: Parse events
    let redeemedEvent = null;
    let assetsReceived = 0n;
    let feesCharged = 0n;
    let sharePriceChangeEvent = null;

    for (const log of receipt.logs) {
      try {
        const parsed = multiVault.interface.parseLog({
          topics: log.topics,
          data: log.data
        });

        if (parsed.name === 'Redeemed') {
          redeemedEvent = parsed;
          assetsReceived = parsed.args.assets;
          feesCharged = parsed.args.fees;

          console.log('\nRedemption Details:');
          console.log('  Sender:', parsed.args.sender);
          console.log('  Receiver:', parsed.args.receiver);
          console.log('  Shares burned:', ethers.formatEther(parsed.args.shares));
          console.log('  Total shares now:', ethers.formatEther(parsed.args.totalShares));
          console.log('  Assets received:', ethers.formatEther(assetsReceived));
          console.log('  Fees charged:', ethers.formatEther(feesCharged));
          console.log('  Vault type:', parsed.args.vaultType);
        } else if (parsed.name === 'SharePriceChanged') {
          sharePriceChangeEvent = parsed;
          console.log('\nShare Price Updated:');
          console.log('  New price:', ethers.formatEther(parsed.args.sharePrice));
          console.log('  Total assets:', ethers.formatEther(parsed.args.totalAssets));
          console.log('  Total shares:', ethers.formatEther(parsed.args.totalShares));
        } else if (parsed.name === 'PersonalUtilizationRemoved') {
          console.log('\nUtilization Updated:');
          console.log('  User:', parsed.args.user);
          console.log('  Epoch:', parsed.args.epoch);
          console.log('  Value removed:', ethers.formatEther(parsed.args.valueRemoved));
          console.log('  New utilization:', parsed.args.personalUtilization);
        }
      } catch (e) {
        // Not a MultiVault event, skip
      }
    }

    if (!redeemedEvent) {
      throw new Error('Redeemed event not found in receipt');
    }

    // Step 9: Verify WTRUST balance increased
    const balanceAfter = await wtrust.balanceOf(wallet.address);
    const balanceIncrease = balanceAfter - balanceBefore;

    console.log('\nWTRUST balance after:', ethers.formatEther(balanceAfter));
    console.log('Balance increase:', ethers.formatEther(balanceIncrease));

    if (balanceIncrease !== assetsReceived) {
      console.warn('Warning: Balance increase does not match assets received');
    }

    return {
      assetsReceived: assetsReceived,
      feesCharged: feesCharged,
      txHash: receipt.hash
    };

  } catch (error) {
    // Handle specific errors
    if (error.code === 'INSUFFICIENT_FUNDS') {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.code === 'CALL_EXCEPTION') {
      // Parse revert reason
      if (error.message.includes('MinAssetsNotReached')) {
        throw new Error('Slippage exceeded: received less than minimum assets');
      } else if (error.message.includes('InsufficientShares')) {
        throw new Error('Insufficient shares to redeem');
      }
      throw new Error(`Contract call failed: ${error.reason || error.message}`);
    } else if (error.code === 'NETWORK_ERROR') {
      throw new Error('Network connection error. Please check RPC endpoint.');
    }

    throw error;
  }
}

/**
 * Redeems all shares from a vault
 */
async function redeemAllShares(
  termId: string,
  curveId: bigint,
  slippageBps: number,
  privateKey: string
): Promise<{
  assetsReceived: bigint;
  feesCharged: bigint;
  txHash: string;
}> {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MultiVaultABI, wallet);

  // Get all shares
  const allShares = await multiVault.getShares(wallet.address, termId, curveId);

  if (allShares === 0n) {
    throw new Error('No shares to redeem');
  }

  // Redeem all shares
  return await redeemShares(termId, curveId, allShares, slippageBps, privateKey);
}

// Usage example
async function main() {
  try {
    const result = await redeemShares(
      '0x1234...', // termId (atom or triple ID)
      1n, // curveId (1 = linear curve)
      ethers.parseEther('100'), // 100 shares
      50, // 0.5% slippage tolerance
      'YOUR_PRIVATE_KEY'
    );

    console.log('\n=== Redemption Successful ===');
    console.log('Assets Received:', ethers.formatEther(result.assetsReceived), 'WTRUST');
    console.log('Fees Charged:', ethers.formatEther(result.feesCharged), 'WTRUST');
    console.log('Transaction:', result.txHash);
  } catch (error) {
    console.error('Error redeeming shares:', error.message);
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

# Load ABIs
with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)

with open('abis/ERC20.json') as f:
    ERC20_ABI = json.load(f)


def redeem_shares(
    term_id: bytes,
    curve_id: int,
    shares_to_redeem: int,
    slippage_bps: int,
    private_key: str
) -> Dict[str, any]:
    """
    Redeems shares from a vault and returns assets

    Args:
        term_id: Atom or triple ID to redeem from
        curve_id: Bonding curve ID (typically 1)
        shares_to_redeem: Amount of shares to burn (in wei)
        slippage_bps: Slippage tolerance in basis points (e.g., 50 = 0.5%)
        private_key: Private key for signing transactions

    Returns:
        Dictionary containing assets_received, fees_charged, and tx_hash

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
        # Step 1: Check share balance
        current_shares = multivault.functions.getShares(
            account.address,
            term_id,
            curve_id
        ).call()

        print(f'Current shares: {Web3.from_wei(current_shares, "ether")}')

        if current_shares == 0:
            raise ValueError('No shares to redeem')

        if shares_to_redeem > current_shares:
            raise ValueError(
                f'Insufficient shares. Have: {Web3.from_wei(current_shares, "ether")}, '
                f'Need: {Web3.from_wei(shares_to_redeem, "ether")}'
            )

        # Step 2: Verify maximum redeemable
        max_redeemable = multivault.functions.maxRedeem(
            account.address,
            term_id,
            curve_id
        ).call()

        if shares_to_redeem > max_redeemable:
            raise ValueError(
                f'Exceeds maximum redeemable shares. '
                f'Max: {Web3.from_wei(max_redeemable, "ether")}'
            )

        # Step 3: Preview the redemption
        preview = multivault.functions.previewRedeem(
            term_id,
            curve_id,
            shares_to_redeem
        ).call()
        assets_after_fees, shares_used = preview

        print(f'Expected assets after fees: {Web3.from_wei(assets_after_fees, "ether")}')
        print(f'Shares to be burned: {Web3.from_wei(shares_used, "ether")}')

        # Step 4: Calculate minimum assets with slippage protection
        min_assets = (assets_after_fees * (10000 - slippage_bps)) // 10000
        print(f'Minimum assets (with slippage): {Web3.from_wei(min_assets, "ether")}')

        # Step 5: Get vault info for fee estimation
        vault_info = multivault.functions.getVault(term_id, curve_id).call()
        total_assets, total_shares = vault_info

        general_config = multivault.functions.getGeneralConfig().call()
        vault_fees = multivault.functions.getVaultFees().call()

        shares_after_redemption = total_shares - shares_to_redeem
        will_charge_exit_fee = shares_after_redemption >= general_config[7]  # feeThreshold

        print(f'Exit fee will be charged: {will_charge_exit_fee}')
        print(f'Protocol fee: {vault_fees[2] / general_config[2] * 100}%')  # protocolFee / feeDenominator

        if will_charge_exit_fee:
            print(f'Exit fee: {vault_fees[1] / general_config[2] * 100}%')  # exitFee / feeDenominator

        # Step 6: Check WTRUST balance before redemption
        balance_before = wtrust.functions.balanceOf(account.address).call()
        print(f'WTRUST balance before: {Web3.from_wei(balance_before, "ether")}')

        # Step 7: Execute the redemption
        print('Redeeming shares...')

        # Build transaction
        redeem_tx = multivault.functions.redeem(
            account.address,  # receiver
            term_id,
            curve_id,
            shares_to_redeem,
            min_assets
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 400000,
            'gasPrice': w3.eth.gas_price
        })

        # Sign and send
        signed_redeem = account.sign_transaction(redeem_tx)
        redeem_hash = w3.eth.send_raw_transaction(signed_redeem.raw_transaction)
        print(f'Transaction sent: {redeem_hash.hex()}')

        # Wait for confirmation
        receipt = w3.eth.wait_for_transaction_receipt(redeem_hash)
        print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

        if receipt['status'] != 1:
            raise Exception('Redemption transaction failed')

        # Step 8: Parse events
        assets_received = 0
        fees_charged = 0

        # Parse Redeemed event
        redeemed_events = multivault.events.Redeemed().process_receipt(receipt)
        if redeemed_events:
            event_args = redeemed_events[0]['args']
            assets_received = event_args['assets']
            fees_charged = event_args['fees']

            print('\nRedemption Details:')
            print(f'  Sender: {event_args["sender"]}')
            print(f'  Receiver: {event_args["receiver"]}')
            print(f'  Shares burned: {Web3.from_wei(event_args["shares"], "ether")}')
            print(f'  Total shares now: {Web3.from_wei(event_args["totalShares"], "ether")}')
            print(f'  Assets received: {Web3.from_wei(assets_received, "ether")}')
            print(f'  Fees charged: {Web3.from_wei(fees_charged, "ether")}')
            print(f'  Vault type: {event_args["vaultType"]}')

        # Parse SharePriceChanged event
        price_events = multivault.events.SharePriceChanged().process_receipt(receipt)
        if price_events:
            price_args = price_events[0]['args']
            print('\nShare Price Updated:')
            print(f'  New price: {Web3.from_wei(price_args["sharePrice"], "ether")}')
            print(f'  Total assets: {Web3.from_wei(price_args["totalAssets"], "ether")}')
            print(f'  Total shares: {Web3.from_wei(price_args["totalShares"], "ether")}')

        if not redeemed_events:
            raise Exception('Redeemed event not found in receipt')

        # Step 9: Verify WTRUST balance increased
        balance_after = wtrust.functions.balanceOf(account.address).call()
        balance_increase = balance_after - balance_before

        print(f'\nWTRUST balance after: {Web3.from_wei(balance_after, "ether")}')
        print(f'Balance increase: {Web3.from_wei(balance_increase, "ether")}')

        if balance_increase != assets_received:
            print('Warning: Balance increase does not match assets received')

        return {
            'assets_received': assets_received,
            'fees_charged': fees_charged,
            'tx_hash': receipt['transactionHash'].hex()
        }

    except ValueError as e:
        raise ValueError(f'Validation error: {str(e)}')
    except Exception as e:
        if 'insufficient funds' in str(e).lower():
            raise Exception('Insufficient ETH for gas fees')
        elif 'minassetsnotreached' in str(e).lower():
            raise Exception('Slippage exceeded: received less than minimum assets')
        elif 'revert' in str(e).lower():
            raise Exception(f'Contract call reverted: {str(e)}')
        raise


def redeem_all_shares(
    term_id: bytes,
    curve_id: int,
    slippage_bps: int,
    private_key: str
) -> Dict[str, any]:
    """
    Redeems all shares from a vault

    Args:
        term_id: Atom or triple ID to redeem from
        curve_id: Bonding curve ID (typically 1)
        slippage_bps: Slippage tolerance in basis points
        private_key: Private key for signing transactions

    Returns:
        Dictionary containing redemption details
    """
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(private_key)
    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )

    # Get all shares
    all_shares = multivault.functions.getShares(
        account.address,
        term_id,
        curve_id
    ).call()

    if all_shares == 0:
        raise ValueError('No shares to redeem')

    # Redeem all shares
    return redeem_shares(term_id, curve_id, all_shares, slippage_bps, private_key)


# Usage example
if __name__ == '__main__':
    try:
        result = redeem_shares(
            term_id=bytes.fromhex('1234...'),  # termId (remove 0x prefix)
            curve_id=1,  # Linear curve
            shares_to_redeem=Web3.to_wei(100, 'ether'),  # 100 shares
            slippage_bps=50,  # 0.5% slippage tolerance
            private_key='YOUR_PRIVATE_KEY'
        )

        print('\n=== Redemption Successful ===')
        print(f'Assets Received: {Web3.from_wei(result["assets_received"], "ether")} WTRUST')
        print(f'Fees Charged: {Web3.from_wei(result["fees_charged"], "ether")} WTRUST')
        print(f'Transaction: {result["tx_hash"]}')

    except Exception as e:
        print(f'Error redeeming shares: {str(e)}')
        exit(1)
```

## Event Monitoring

### Events Emitted

When redeeming shares, the following events are emitted:

#### 1. Redeemed

```solidity
event Redeemed(
    address indexed sender,
    address indexed receiver,
    bytes32 indexed termId,
    uint256 curveId,
    uint256 shares,
    uint256 totalShares,
    uint256 assets,
    uint256 fees,
    VaultType vaultType
);
```

**Parameters**:
- `sender`: Address that initiated the redemption
- `receiver`: Address receiving the assets
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID used
- `shares`: Shares burned
- `totalShares`: User's remaining share balance
- `assets`: Net assets sent to receiver (after all fees)
- `fees`: Total fees charged (protocol + exit fees)
- `vaultType`: Type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)

#### 2. SharePriceChanged

```solidity
event SharePriceChanged(
    bytes32 indexed termId,
    uint256 indexed curveId,
    uint256 sharePrice,
    uint256 totalAssets,
    uint256 totalShares,
    VaultType vaultType
);
```

**Parameters**:
- `termId`: Atom or triple ID
- `curveId`: Bonding curve ID
- `sharePrice`: New share price after redemption
- `totalAssets`: Total assets remaining in vault
- `totalShares`: Total shares remaining in vault
- `vaultType`: Type of vault

#### 3. PersonalUtilizationRemoved

```solidity
event PersonalUtilizationRemoved(
    address indexed user,
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 personalUtilization
);
```

**Parameters**:
- `user`: Address of the user
- `epoch`: Current epoch
- `valueRemoved`: Utilization value removed (positive integer)
- `personalUtilization`: User's new utilization after removal

#### 4. TotalUtilizationRemoved

```solidity
event TotalUtilizationRemoved(
    uint256 indexed epoch,
    int256 indexed valueRemoved,
    int256 indexed totalUtilization
);
```

**Parameters**:
- `epoch`: Current epoch
- `valueRemoved`: System utilization removed
- `totalUtilization`: New system-wide utilization

#### 5. ProtocolFeeAccrued

```solidity
event ProtocolFeeAccrued(
    uint256 indexed epoch,
    address indexed sender,
    uint256 amount
);
```

**Parameters**:
- `epoch`: Current epoch
- `sender`: Address that paid the fee
- `amount`: Protocol fee amount accrued

### Listening for Events

**TypeScript**:
```typescript
// Listen for Redeemed events
multiVault.on('Redeemed', (sender, receiver, termId, curveId, shares, totalShares, assets, fees, vaultType, event) => {
  console.log('Shares redeemed:');
  console.log('  Sender:', sender);
  console.log('  Receiver:', receiver);
  console.log('  Shares burned:', ethers.formatEther(shares));
  console.log('  Assets received:', ethers.formatEther(assets));
  console.log('  Fees:', ethers.formatEther(fees));
});

// Query historical redemptions
const filter = multiVault.filters.Redeemed(myAddress);
const events = await multiVault.queryFilter(filter, -10000);
```

**Python**:
```python
# Create event filter
event_filter = multivault.events.Redeemed.create_filter(
    from_block='latest',
    argument_filters={'sender': account.address}
)

# Poll for new events
while True:
    for event in event_filter.get_new_entries():
        print(f'Shares redeemed:')
        print(f'  Shares burned: {Web3.from_wei(event["args"]["shares"], "ether")}')
        print(f'  Assets received: {Web3.from_wei(event["args"]["assets"], "ether")}')
        print(f'  Fees: {Web3.from_wei(event["args"]["fees"], "ether")}')

    time.sleep(12)
```

## Error Handling

### Common Errors

#### 1. Insufficient Shares

**Error**: `MultiVaultCore_InsufficientShares()`

**Cause**: Attempting to redeem more shares than you own.

**Recovery**:
- Check share balance: `getShares(account, termId, curveId)`
- Reduce redemption amount
- Verify you're using the correct termId and curveId

#### 2. Minimum Assets Not Reached

**Error**: `MultiVaultCore_MinAssetsNotReached()`

**Cause**: Slippage protection triggered - would receive less than minAssets.

**Recovery**:
- Increase slippage tolerance
- Preview redemption again: `previewRedeem()`
- Wait for better market conditions
- Reduce shares to redeem

#### 3. Invalid Receiver Address

**Error**: `MultiVaultCore_InvalidReceiver()`

**Cause**: Receiver address is zero address.

**Recovery**:
- Provide valid receiver address
- Cannot send to address(0)

#### 4. Paused Contract

**Error**: `Pausable: paused`

**Cause**: Protocol is paused for emergency maintenance.

**Recovery**:
- Wait for protocol to be unpaused
- Monitor protocol announcements
- Cannot redeem while paused

#### 5. No Shares to Redeem

**Error**: Shares balance is zero

**Cause**: User has no shares in this vault.

**Recovery**:
- Verify termId and curveId are correct
- Check if you deposited to a different vault
- Deposit first before attempting to redeem

#### 6. Redemption Would Leave Dust

**Error**: Internal validation failure

**Cause**: Redemption would leave very small amount of shares.

**Recovery**:
- Redeem all shares instead of partial redemption
- Use `maxRedeem()` to get exact redeemable amount

### Error Handling Pattern

```typescript
try {
  const result = await redeemShares(termId, curveId, shares, slippage, privateKey);
} catch (error) {
  if (error.message.includes('InsufficientShares')) {
    // Get actual balance and use that
    const actualShares = await multiVault.getShares(address, termId, curveId);
    await redeemShares(termId, curveId, actualShares, slippage, privateKey);
  } else if (error.message.includes('MinAssetsNotReached')) {
    // Increase slippage tolerance
    await redeemShares(termId, curveId, shares, slippage * 2, privateKey);
  } else if (error.message.includes('paused')) {
    // Wait and retry
    console.log('Protocol paused, waiting...');
    await new Promise(resolve => setTimeout(resolve, 60000));
    await redeemShares(termId, curveId, shares, slippage, privateKey);
  } else {
    console.error('Redemption failed:', error);
    throw error;
  }
}
```

## Gas Estimation

### Typical Gas Costs

Operation costs on Intuition Mainnet (approximate):

| Operation | Gas Used | Notes |
|-----------|----------|-------|
| Single redemption | ~250,000 | From atom vault |
| Triple redemption | ~350,000 | Higher due to underlying atom interactions |
| Batch (2 redemptions) | ~450,000 | More efficient than 2 separate txs |
| Batch (5 redemptions) | ~1,000,000 | Scales sub-linearly |

### Factors Affecting Cost

1. **Vault type**: Triple vaults cost more than atom vaults
2. **Fee calculations**: More fees = more gas
3. **Utilization tracking**: Updates cost gas
4. **Batch size**: Larger batches more efficient per redemption
5. **First redemption after deposit**: May cost slightly more

### Gas Optimization Tips

```typescript
// 1. Use batch redemption for multiple vaults
const assetsReceived = await multiVault.redeemBatch(
  receiver,
  [termId1, termId2, termId3],
  [curveId1, curveId2, curveId3],
  [shares1, shares2, shares3],
  [minAssets1, minAssets2, minAssets3]
); // More efficient than 3 separate calls

// 2. Estimate gas before sending
const gasEstimate = await multiVault.redeem.estimateGas(
  receiver,
  termId,
  curveId,
  shares,
  minAssets
);
const gasLimit = gasEstimate * 120n / 100n; // Add 20% buffer

// 3. Redeem all shares at once to avoid dust
const maxShares = await multiVault.maxRedeem(address, termId, curveId);
await multiVault.redeem(receiver, termId, curveId, maxShares, minAssets);
```

## Best Practices

### 1. Always Preview Before Redeeming

```typescript
// Preview to see exact assets you'll receive
const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
  termId,
  curveId,
  shares
);

// Verify it meets your expectations
if (assetsAfterFees < expectedMinimum) {
  throw new Error('Would receive less than expected');
}

// Set appropriate slippage
const minAssets = (assetsAfterFees * 9950n) / 10000n; // 0.5% slippage
```

### 2. Use Slippage Protection

Always set `minAssets` to protect against unfavorable price movements:

```typescript
// Bad: No slippage protection
await multiVault.redeem(receiver, termId, curveId, shares, 0);

// Good: Reasonable slippage tolerance
const [expectedAssets] = await multiVault.previewRedeem(termId, curveId, shares);
const minAssets = (expectedAssets * 9900n) / 10000n; // 1% slippage
await multiVault.redeem(receiver, termId, curveId, shares, minAssets);
```

### 3. Monitor Share Price Changes

Track share price to optimize redemption timing:

```typescript
const sharePrice = await multiVault.currentSharePrice(termId, curveId);
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Calculate price per share
const pricePerShare = totalShares > 0n
  ? (totalAssets * ethers.parseEther('1')) / totalShares
  : 0n;

console.log('Current price per share:', ethers.formatEther(pricePerShare));
```

### 4. Consider Fee Thresholds

Understand when fees apply:

```typescript
const generalConfig = await multiVault.getGeneralConfig();
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);

// Exit fee only applies if remaining shares >= feeThreshold
const sharesAfterRedemption = totalShares - sharesToRedeem;
const willPayExitFee = sharesAfterRedemption >= generalConfig.feeThreshold;

if (willPayExitFee) {
  console.log('Exit fee will be charged');
  // Consider waiting or redeeming more to avoid fee
}
```

### 5. Track Your Positions

Maintain off-chain records of your positions:

```typescript
interface Position {
  termId: string;
  curveId: bigint;
  shares: bigint;
  averagePrice: bigint;
  depositsCount: number;
}

async function trackRedemption(position: Position, sharesRedeemed: bigint) {
  const [assetsReceived] = await multiVault.previewRedeem(
    position.termId,
    position.curveId,
    sharesRedeemed
  );

  // Calculate P&L
  const costBasis = (position.averagePrice * sharesRedeemed) / ethers.parseEther('1');
  const profitLoss = assetsReceived - costBasis;

  console.log('Profit/Loss:', ethers.formatEther(profitLoss), 'WTRUST');

  // Update position
  position.shares -= sharesRedeemed;
}
```

### 6. Batch When Possible

Redeem from multiple vaults in one transaction:

```typescript
// Efficient: Single transaction
const results = await multiVault.redeemBatch(
  receiver,
  [termId1, termId2, termId3],
  [1n, 1n, 1n], // All using linear curve
  [shares1, shares2, shares3],
  [minAssets1, minAssets2, minAssets3]
);

// Less efficient: Three separate transactions
// await multiVault.redeem(receiver, termId1, 1n, shares1, minAssets1);
// await multiVault.redeem(receiver, termId2, 1n, shares2, minAssets2);
// await multiVault.redeem(receiver, termId3, 1n, shares3, minAssets3);
```

## Common Pitfalls

### 1. Not Using maxRedeem

Always verify you're not exceeding maximum redeemable:

```typescript
// WRONG: Assumes all shares are redeemable
const shares = await multiVault.getShares(address, termId, curveId);
await multiVault.redeem(receiver, termId, curveId, shares, minAssets);

// CORRECT: Use maxRedeem to get actual redeemable amount
const maxShares = await multiVault.maxRedeem(address, termId, curveId);
await multiVault.redeem(receiver, termId, curveId, maxShares, minAssets);
```

### 2. Ignoring Slippage

Not setting appropriate slippage protection:

```typescript
// WRONG: No slippage protection
await multiVault.redeem(receiver, termId, curveId, shares, 0n);

// CORRECT: Set reasonable minimum
const [expectedAssets] = await multiVault.previewRedeem(termId, curveId, shares);
const minAssets = (expectedAssets * 9950n) / 10000n;
await multiVault.redeem(receiver, termId, curveId, shares, minAssets);
```

### 3. Wrong termId or curveId

Using incorrect vault identifiers:

```typescript
// WRONG: Might use wrong curveId
await multiVault.redeem(receiver, termId, 0n, shares, minAssets);

// CORRECT: Verify vault exists and has shares
const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
if (totalShares === 0n) {
  throw new Error('Vault does not exist or has no shares');
}
```

### 4. Not Accounting for Fees

Expecting gross assets instead of net:

```typescript
// WRONG: Using convertToAssets (doesn't include fees)
const grossAssets = await multiVault.convertToAssets(termId, curveId, shares);
// Will be disappointed when actual assets < grossAssets

// CORRECT: Use previewRedeem (includes all fees)
const [netAssets] = await multiVault.previewRedeem(termId, curveId, shares);
// netAssets is what you'll actually receive
```

### 5. Redeeming During High Volatility

Redeeming when share price is unfavorable:

```typescript
// WRONG: Immediate redemption without checking price
await multiVault.redeem(receiver, termId, curveId, shares, minAssets);

// CORRECT: Check price and consider waiting
const [assets] = await multiVault.previewRedeem(termId, curveId, shares);
const pricePerShare = (assets * ethers.parseEther('1')) / shares;

if (pricePerShare < myPurchasePrice) {
  console.log('Warning: Redeeming at a loss');
  // Consider waiting for better price
}
```

### 6. Not Parsing Events

Failing to confirm redemption success:

```typescript
// WRONG: Not verifying redemption
const tx = await multiVault.redeem(receiver, termId, curveId, shares, minAssets);
await tx.wait();
// Assumes success without checking

// CORRECT: Parse events to verify
const receipt = await tx.wait();
const event = receipt.logs.find(log => {
  try {
    const parsed = multiVault.interface.parseLog(log);
    return parsed.name === 'Redeemed';
  } catch {
    return false;
  }
});

if (!event) {
  throw new Error('Redemption failed - no Redeemed event');
}
```

## Related Operations

### Before Redeeming Shares

1. **Check rewards**: [Claim pending rewards](./claiming-rewards.md) before redeeming
2. **Review utilization**: Understand impact on your utilization score
3. **Calculate P&L**: Determine if redemption is profitable

### After Redeeming Shares

1. **Claim atom wallet fees**: If you own atom wallet - [Wallet Integration](./wallet-integration.md)
2. **Redeploy assets**: Deposit into other vaults if desired
3. **Track performance**: Record redemption for tax/accounting purposes

### Alternative Approaches

- **Partial redemption**: Redeem portion of shares to take profits
- **Full exit**: Redeem all shares using `maxRedeem()`
- **Batch redemption**: Exit multiple positions simultaneously

## See Also

- [Depositing Assets Guide](./depositing-assets.md)
- [Batch Operations Guide](./batch-operations.md)
- [Fee Structure](./fee-structure.md)
- [Utilization Mechanics](./utilization-mechanics.md)
- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [MultiVault Contract Reference](../contracts/core/MultiVault.md)

---

**Last Updated**: December 2025
