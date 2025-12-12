# Claiming Rewards

## Overview

The Intuition Protocol distributes TRUST token emissions to users based on their utilization of the protocol. Rewards are calculated per epoch and can be claimed in the following epoch. The reward system uses a voting escrow pattern where users can lock TRUST tokens to boost their reward multiplier.

This guide shows you how to claim emission rewards programmatically using TypeScript and Python.

**When to use this operation**:
- Claiming TRUST token rewards after an epoch ends
- Harvesting accumulated rewards from protocol usage
- Maximizing returns from your utilization score
- Converting protocol activity into token rewards

## Prerequisites

### Required Knowledge
- Understanding of [epoch-based emissions system](../concepts/emissions-system.md)
- Familiarity with [utilization tracking](../concepts/utilization-tracking.md)
- Knowledge of voting escrow mechanics
- Understanding of personal vs system utilization ratios

### Contracts Needed
- **TrustBonding**: Rewards distribution contract
  - Mainnet: `0x...` (check deployment-addresses.md)
  - Testnet: `0x...`
- **MultiVault**: For utilization tracking
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`

### Tokens Required
- None (rewards are minted when claimed)
- Native ETH for gas fees only

### Key Parameters
- `recipient`: Address to receive the TRUST rewards
- Rewards are always claimed for the **previous epoch** (currentEpoch - 1)

## Step-by-Step Guide

### Step 1: Check Current Epoch

Determine the current epoch to understand which epoch's rewards you can claim.

```typescript
const currentEpoch = await trustBonding.currentEpoch();
const previousEpoch = await trustBonding.previousEpoch();

// You can claim rewards for previousEpoch
console.log('Current epoch:', currentEpoch);
console.log('Claimable epoch:', previousEpoch);
```

### Step 2: Check if Already Claimed

Verify you haven't already claimed rewards for the previous epoch.

```typescript
const alreadyClaimed = await trustBonding.hasClaimedRewardsForEpoch(
  userAddress,
  previousEpoch
);

if (alreadyClaimed) {
  throw new Error('Rewards already claimed for this epoch');
}
```

### Step 3: Get User Information

Retrieve comprehensive user information including eligible rewards.

```typescript
const userInfo = await trustBonding.getUserInfo(userAddress);

console.log('Personal utilization:', userInfo.personalUtilization);
console.log('Eligible rewards:', formatEther(userInfo.eligibleRewards));
console.log('Max rewards:', formatEther(userInfo.maxRewards));
console.log('Locked amount:', formatEther(userInfo.lockedAmount));
console.log('Lock end:', new Date(Number(userInfo.lockEnd) * 1000));
console.log('Bonded balance:', formatEther(userInfo.bondedBalance));
```

### Step 4: Calculate Claimable Rewards

Get the exact amount of rewards you can claim for the previous epoch.

```typescript
const claimableRewards = await trustBonding.getUserCurrentClaimableRewards(
  userAddress
);

if (claimableRewards === 0n) {
  throw new Error('No rewards to claim');
}

console.log('Claimable rewards:', formatEther(claimableRewards), 'TRUST');
```

### Step 5: Check Utilization Ratios

Understand how your rewards were calculated.

```typescript
const previousEpoch = await trustBonding.previousEpoch();

const personalRatio = await trustBonding.getPersonalUtilizationRatio(
  userAddress,
  previousEpoch
);

const systemRatio = await trustBonding.getSystemUtilizationRatio(
  previousEpoch
);

console.log('Your utilization ratio:', Number(personalRatio) / 1e18);
console.log('System utilization ratio:', Number(systemRatio) / 1e18);
```

### Step 6: Review APY

Check your current and potential APY.

```typescript
const [currentApy, maxApy] = await trustBonding.getUserApy(userAddress);

console.log('Current APY:', Number(currentApy) / 100, '%');
console.log('Max possible APY:', Number(maxApy) / 100, '%');
```

### Step 7: Claim Rewards

Execute the claim transaction, specifying where to send the rewards.

```typescript
const tx = await trustBonding.claimRewards(
  recipientAddress // Can be your address or any other address
);

const receipt = await tx.wait();
```

### Step 8: Verify Rewards Received

Parse events to confirm the exact amount claimed.

```typescript
const rewardsClaimedEvent = receipt.logs
  .map(log => trustBonding.interface.parseLog(log))
  .find(event => event.name === 'RewardsClaimed');

const amountClaimed = rewardsClaimedEvent.args.amount;
console.log('TRUST claimed:', formatEther(amountClaimed));
```

### Step 9: Check Updated Claim Status

Verify the claim was recorded for this epoch.

```typescript
const nowClaimed = await trustBonding.hasClaimedRewardsForEpoch(
  userAddress,
  previousEpoch
);

console.log('Claim recorded for epoch', previousEpoch, ':', nowClaimed);
```

## Code Examples

### TypeScript (viem)

Complete example with error handling and comprehensive reward information:

```typescript
import { createPublicClient, createWalletClient, http, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// Contract ABIs (import from your ABI files)
import TrustBondingABI from './abis/ITrustBonding.json';
import MultiVaultABI from './abis/IMultiVault.json';
import ERC20ABI from './abis/ERC20.json';

// Configuration
const TRUST_BONDING_ADDRESS = '0x...' as `0x${string}`; // Check deployment addresses
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;
const TRUST_ADDRESS = '0x...' as `0x${string}`; // TRUST token address
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

/**
 * Claims emission rewards for the previous epoch
 */
async function claimRewards(
  recipient: `0x${string}`,
  privateKey: `0x${string}`
): Promise<{
  amountClaimed: bigint;
  epoch: bigint;
  txHash: string;
  apy: {
    current: number;
    max: number;
  };
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
    // Step 1: Get current and previous epoch
    const currentEpoch = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'currentEpoch'
    }) as bigint;

    const previousEpoch = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'previousEpoch'
    }) as bigint;

    console.log('Current epoch:', currentEpoch);
    console.log('Claimable epoch:', previousEpoch);

    // Cannot claim in epoch 0
    if (currentEpoch === 0n) {
      throw new Error('Cannot claim rewards in epoch 0 (genesis epoch)');
    }

    // Step 2: Check if already claimed
    const alreadyClaimed = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'hasClaimedRewardsForEpoch',
      args: [account.address, previousEpoch]
    }) as boolean;

    if (alreadyClaimed) {
      throw new Error(`Rewards already claimed for epoch ${previousEpoch}`);
    }

    // Step 3: Get comprehensive user information
    const userInfo = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getUserInfo',
      args: [account.address]
    }) as [bigint, bigint, bigint, bigint, bigint, bigint];

    console.log('\nUser Information:');
    console.log('  Personal utilization:', userInfo[0].toString());
    console.log('  Eligible rewards:', formatEther(userInfo[1]), 'TRUST');
    console.log('  Max rewards:', formatEther(userInfo[2]), 'TRUST');
    console.log('  Locked amount:', formatEther(userInfo[3]), 'TRUST');
    console.log('  Lock end:', userInfo[4] > 0n
      ? new Date(Number(userInfo[4]) * 1000).toISOString()
      : 'Not locked');
    console.log('  Bonded balance:', formatEther(userInfo[5]), 'TRUST');

    // Step 4: Get claimable rewards
    const claimableRewards = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getUserCurrentClaimableRewards',
      args: [account.address]
    }) as bigint;

    if (claimableRewards === 0n) {
      throw new Error('No rewards available to claim');
    }

    console.log('\nClaimable rewards:', formatEther(claimableRewards), 'TRUST');

    // Step 5: Get detailed rewards for previous epoch
    const [eligibleRewards, maxRewards] = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getUserRewardsForEpoch',
      args: [account.address, previousEpoch]
    }) as [bigint, bigint];

    console.log('\nEpoch', previousEpoch, 'Rewards:');
    console.log('  Eligible rewards:', formatEther(eligibleRewards), 'TRUST');
    console.log('  Max possible:', formatEther(maxRewards), 'TRUST');

    if (eligibleRewards < maxRewards) {
      const efficiency = Number(eligibleRewards) / Number(maxRewards) * 100;
      console.log('  Efficiency:', efficiency.toFixed(2), '%');
      console.log('  Tip: Lock TRUST tokens to increase your multiplier');
    }

    // Step 6: Get utilization ratios
    const personalRatio = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getPersonalUtilizationRatio',
      args: [account.address, previousEpoch]
    }) as bigint;

    const systemRatio = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getSystemUtilizationRatio',
      args: [previousEpoch]
    }) as bigint;

    console.log('\nUtilization Ratios for Epoch', previousEpoch, ':');
    console.log('  Personal:', (Number(personalRatio) / 1e18).toFixed(4));
    console.log('  System:', (Number(systemRatio) / 1e18).toFixed(4));

    // Step 7: Get APY information
    const [currentApy, maxApy] = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'getUserApy',
      args: [account.address]
    }) as [bigint, bigint];

    console.log('\nAPY Information:');
    console.log('  Current APY:', (Number(currentApy) / 100).toFixed(2), '%');
    console.log('  Max possible APY:', (Number(maxApy) / 100).toFixed(2), '%');

    // Step 8: Get epoch information
    const epochLength = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'epochLength'
    }) as bigint;

    const epochsPerYear = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'epochsPerYear'
    }) as bigint;

    const epochEndTime = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'epochTimestampEnd',
      args: [currentEpoch]
    }) as bigint;

    console.log('\nEpoch Information:');
    console.log('  Epoch length:', Number(epochLength) / 86400, 'days');
    console.log('  Epochs per year:', epochsPerYear);
    console.log('  Current epoch ends:', new Date(Number(epochEndTime) * 1000).toISOString());

    // Step 9: Get bonded balance history
    const bondedBalanceAtEpochEnd = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'userBondedBalanceAtEpochEnd',
      args: [account.address, previousEpoch]
    }) as bigint;

    console.log('  Bonded balance at epoch', previousEpoch, 'end:',
      formatEther(bondedBalanceAtEpochEnd), 'TRUST');

    // Step 10: Check TRUST balance before claiming
    const balanceBefore = await publicClient.readContract({
      address: TRUST_ADDRESS,
      abi: ERC20ABI,
      functionName: 'balanceOf',
      args: [recipient]
    }) as bigint;
    console.log('\nTRUST balance before claim:', formatEther(balanceBefore));

    // Step 11: Execute claim
    console.log('\nClaiming rewards...');
    const claimHash = await walletClient.writeContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'claimRewards',
      args: [recipient],
      gas: 300000n
    });

    console.log('Transaction sent:', claimHash);
    const receipt = await publicClient.waitForTransactionReceipt({ hash: claimHash });
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 12: Parse events
    const rewardsClaimedEvents = publicClient.parseEventLogs({
      abi: TrustBondingABI,
      logs: receipt.logs,
      eventName: 'RewardsClaimed'
    });

    if (rewardsClaimedEvents.length === 0) {
      throw new Error('RewardsClaimed event not found in receipt');
    }

    const amountClaimed = rewardsClaimedEvents[0].args.amount as bigint;

    console.log('\nRewards Claimed:');
    console.log('  User:', rewardsClaimedEvents[0].args.user);
    console.log('  Recipient:', rewardsClaimedEvents[0].args.recipient);
    console.log('  Amount:', formatEther(amountClaimed), 'TRUST');

    // Step 13: Verify TRUST balance increased
    const balanceAfter = await publicClient.readContract({
      address: TRUST_ADDRESS,
      abi: ERC20ABI,
      functionName: 'balanceOf',
      args: [recipient]
    }) as bigint;
    const balanceIncrease = balanceAfter - balanceBefore;

    console.log('\nTRUST balance after:', formatEther(balanceAfter));
    console.log('Balance increase:', formatEther(balanceIncrease), 'TRUST');

    if (balanceIncrease !== amountClaimed) {
      console.warn('Warning: Balance increase does not match claimed amount');
    }

    // Step 14: Verify claim is now recorded
    const nowClaimed = await publicClient.readContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TrustBondingABI,
      functionName: 'hasClaimedRewardsForEpoch',
      args: [account.address, previousEpoch]
    }) as boolean;

    console.log('Claim recorded for epoch', previousEpoch, ':', nowClaimed);

    return {
      amountClaimed: amountClaimed,
      epoch: previousEpoch,
      txHash: claimHash,
      apy: {
        current: Number(currentApy) / 100,
        max: Number(maxApy) / 100
      }
    };

  } catch (error) {
    // Handle specific errors
    if (error.message?.includes('insufficient funds')) {
      throw new Error('Insufficient ETH for gas fees');
    } else if (error.message?.includes('NoRewardsToClaim')) {
      throw new Error('No rewards available to claim');
    } else if (error.message?.includes('RewardsAlreadyClaimedForEpoch')) {
      throw new Error(`Rewards already claimed for epoch ${previousEpoch}`);
    } else if (error.message?.includes('NoClaimingDuringFirstEpoch')) {
      throw new Error('Cannot claim rewards during the first epoch');
    }

    throw error;
  }
}

/**
 * Gets detailed reward information without claiming
 */
async function getRewardInfo(
  userAddress: `0x${string}`,
  rpcUrl: string
): Promise<{
  claimableRewards: bigint;
  currentEpoch: bigint;
  claimableEpoch: bigint;
  alreadyClaimed: boolean;
  personalRatio: bigint;
  systemRatio: bigint;
  currentApy: number;
  maxApy: number;
}> {
  const publicClient = createPublicClient({
    chain: base,
    transport: http(rpcUrl)
  });

  const currentEpoch = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TrustBondingABI,
    functionName: 'currentEpoch'
  }) as bigint;

  const previousEpoch = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TrustBondingABI,
    functionName: 'previousEpoch'
  }) as bigint;

  const claimableRewards = currentEpoch > 0n
    ? await publicClient.readContract({
        address: TRUST_BONDING_ADDRESS,
        abi: TrustBondingABI,
        functionName: 'getUserCurrentClaimableRewards',
        args: [userAddress]
      }) as bigint
    : 0n;

  const alreadyClaimed = currentEpoch > 0n
    ? await publicClient.readContract({
        address: TRUST_BONDING_ADDRESS,
        abi: TrustBondingABI,
        functionName: 'hasClaimedRewardsForEpoch',
        args: [userAddress, previousEpoch]
      }) as boolean
    : false;

  const personalRatio = currentEpoch > 0n
    ? await publicClient.readContract({
        address: TRUST_BONDING_ADDRESS,
        abi: TrustBondingABI,
        functionName: 'getPersonalUtilizationRatio',
        args: [userAddress, previousEpoch]
      }) as bigint
    : 0n;

  const systemRatio = currentEpoch > 0n
    ? await publicClient.readContract({
        address: TRUST_BONDING_ADDRESS,
        abi: TrustBondingABI,
        functionName: 'getSystemUtilizationRatio',
        args: [previousEpoch]
      }) as bigint
    : 0n;

  const [currentApy, maxApy] = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TrustBondingABI,
    functionName: 'getUserApy',
    args: [userAddress]
  }) as [bigint, bigint];

  return {
    claimableRewards,
    currentEpoch,
    claimableEpoch: previousEpoch,
    alreadyClaimed,
    personalRatio,
    systemRatio,
    currentApy: Number(currentApy) / 100,
    maxApy: Number(maxApy) / 100
  };
}

// Usage example
async function main() {
  try {
    // First, check reward info
    const info = await getRewardInfo(
      '0xYourAddress' as `0x${string}`,
      RPC_URL
    );

    console.log('Reward Information:');
    console.log('  Claimable:', formatEther(info.claimableRewards), 'TRUST');
    console.log('  Current epoch:', info.currentEpoch);
    console.log('  Claimable epoch:', info.claimableEpoch);
    console.log('  Already claimed:', info.alreadyClaimed);
    console.log('  Current APY:', info.currentApy.toFixed(2), '%');

    if (info.claimableRewards > 0n && !info.alreadyClaimed) {
      // Claim rewards
      const result = await claimRewards(
        '0xYourAddress' as `0x${string}`, // recipient
        '0xYourPrivateKey' as `0x${string}`
      );

      console.log('\n=== Claim Successful ===');
      console.log('Amount Claimed:', formatEther(result.amountClaimed), 'TRUST');
      console.log('Epoch:', result.epoch);
      console.log('Transaction:', result.txHash);
      console.log('Current APY:', result.apy.current.toFixed(2), '%');
      console.log('Max APY:', result.apy.max.toFixed(2), '%');
    } else {
      console.log('\nNo rewards to claim or already claimed');
    }
  } catch (error) {
    console.error('Error:', error.message);
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
from datetime import datetime
import json

# Configuration
TRUST_BONDING_ADDRESS = '0x...'  # Check deployment addresses
MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
TRUST_ADDRESS = '0x...'  # TRUST token address
RPC_URL = 'YOUR_INTUITION_RPC_URL'

# Load ABIs
with open('abis/ITrustBonding.json') as f:
    TRUST_BONDING_ABI = json.load(f)

with open('abis/ERC20.json') as f:
    ERC20_ABI = json.load(f)


def claim_rewards(
    recipient: str,
    private_key: str
) -> Dict[str, any]:
    """
    Claims emission rewards for the previous epoch

    Args:
        recipient: Address to receive TRUST rewards
        private_key: Private key for signing transactions

    Returns:
        Dictionary containing amount_claimed, epoch, tx_hash, and apy info

    Raises:
        ValueError: If parameters are invalid or no rewards available
        Exception: If transaction fails
    """
    # Setup Web3
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    if not w3.is_connected():
        raise Exception('Failed to connect to RPC endpoint')

    # Setup account
    account = Account.from_key(private_key)

    # Contract instances
    trust_bonding = w3.eth.contract(
        address=Web3.to_checksum_address(TRUST_BONDING_ADDRESS),
        abi=TRUST_BONDING_ABI
    )
    trust = w3.eth.contract(
        address=Web3.to_checksum_address(TRUST_ADDRESS),
        abi=ERC20_ABI
    )

    try:
        # Step 1: Get current and previous epoch
        current_epoch = trust_bonding.functions.currentEpoch().call()
        previous_epoch = trust_bonding.functions.previousEpoch().call()

        print(f'Current epoch: {current_epoch}')
        print(f'Claimable epoch: {previous_epoch}')

        # Cannot claim in epoch 0
        if current_epoch == 0:
            raise ValueError('Cannot claim rewards in epoch 0 (genesis epoch)')

        # Step 2: Check if already claimed
        already_claimed = trust_bonding.functions.hasClaimedRewardsForEpoch(
            account.address,
            previous_epoch
        ).call()

        if already_claimed:
            raise ValueError(f'Rewards already claimed for epoch {previous_epoch}')

        # Step 3: Get comprehensive user information
        user_info = trust_bonding.functions.getUserInfo(account.address).call()
        personal_util, eligible_rewards, max_rewards, locked_amt, lock_end, bonded_bal = user_info

        print('\nUser Information:')
        print(f'  Personal utilization: {personal_util}')
        print(f'  Eligible rewards: {Web3.from_wei(eligible_rewards, "ether")} TRUST')
        print(f'  Max rewards: {Web3.from_wei(max_rewards, "ether")} TRUST')
        print(f'  Locked amount: {Web3.from_wei(locked_amt, "ether")} TRUST')
        if lock_end > 0:
            print(f'  Lock end: {datetime.fromtimestamp(lock_end).isoformat()}')
        else:
            print(f'  Lock end: Not locked')
        print(f'  Bonded balance: {Web3.from_wei(bonded_bal, "ether")} TRUST')

        # Step 4: Get claimable rewards
        claimable_rewards = trust_bonding.functions.getUserCurrentClaimableRewards(
            account.address
        ).call()

        if claimable_rewards == 0:
            raise ValueError('No rewards available to claim')

        print(f'\nClaimable rewards: {Web3.from_wei(claimable_rewards, "ether")} TRUST')

        # Step 5: Get detailed rewards for previous epoch
        epoch_rewards = trust_bonding.functions.getUserRewardsForEpoch(
            account.address,
            previous_epoch
        ).call()
        epoch_eligible, epoch_max = epoch_rewards

        print(f'\nEpoch {previous_epoch} Rewards:')
        print(f'  Eligible rewards: {Web3.from_wei(epoch_eligible, "ether")} TRUST')
        print(f'  Max possible: {Web3.from_wei(epoch_max, "ether")} TRUST')

        if epoch_eligible < epoch_max:
            efficiency = (epoch_eligible / epoch_max) * 100 if epoch_max > 0 else 0
            print(f'  Efficiency: {efficiency:.2f}%')
            print('  Tip: Lock TRUST tokens to increase your multiplier')

        # Step 6: Get utilization ratios
        personal_ratio = trust_bonding.functions.getPersonalUtilizationRatio(
            account.address,
            previous_epoch
        ).call()

        system_ratio = trust_bonding.functions.getSystemUtilizationRatio(
            previous_epoch
        ).call()

        print(f'\nUtilization Ratios for Epoch {previous_epoch}:')
        print(f'  Personal: {personal_ratio / 1e18:.4f}')
        print(f'  System: {system_ratio / 1e18:.4f}')

        # Step 7: Get APY information
        apy_info = trust_bonding.functions.getUserApy(account.address).call()
        current_apy, max_apy = apy_info

        print('\nAPY Information:')
        print(f'  Current APY: {current_apy / 100:.2f}%')
        print(f'  Max possible APY: {max_apy / 100:.2f}%')

        # Step 8: Get epoch information
        epoch_length = trust_bonding.functions.epochLength().call()
        epochs_per_year = trust_bonding.functions.epochsPerYear().call()
        epoch_end_time = trust_bonding.functions.epochTimestampEnd(current_epoch).call()

        print('\nEpoch Information:')
        print(f'  Epoch length: {epoch_length / 86400} days')
        print(f'  Epochs per year: {epochs_per_year}')
        print(f'  Current epoch ends: {datetime.fromtimestamp(epoch_end_time).isoformat()}')

        # Step 9: Check TRUST balance before claiming
        balance_before = trust.functions.balanceOf(recipient).call()
        print(f'\nTRUST balance before claim: {Web3.from_wei(balance_before, "ether")}')

        # Step 10: Execute claim
        print('\nClaiming rewards...')

        # Build transaction
        claim_tx = trust_bonding.functions.claimRewards(
            recipient
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 300000,
            'gasPrice': w3.eth.gas_price
        })

        # Sign and send
        signed_claim = account.sign_transaction(claim_tx)
        claim_hash = w3.eth.send_raw_transaction(signed_claim.raw_transaction)
        print(f'Transaction sent: {claim_hash.hex()}')

        # Wait for confirmation
        receipt = w3.eth.wait_for_transaction_receipt(claim_hash)
        print(f'Transaction confirmed in block: {receipt["blockNumber"]}')

        if receipt['status'] != 1:
            raise Exception('Claim transaction failed')

        # Step 11: Parse events
        amount_claimed = 0

        # Parse RewardsClaimed event
        rewards_events = trust_bonding.events.RewardsClaimed().process_receipt(receipt)
        if rewards_events:
            event_args = rewards_events[0]['args']
            amount_claimed = event_args['amount']

            print('\nRewards Claimed:')
            print(f'  User: {event_args["user"]}')
            print(f'  Recipient: {event_args["recipient"]}')
            print(f'  Amount: {Web3.from_wei(amount_claimed, "ether")} TRUST')

        if not rewards_events:
            raise Exception('RewardsClaimed event not found in receipt')

        # Step 12: Verify TRUST balance increased
        balance_after = trust.functions.balanceOf(recipient).call()
        balance_increase = balance_after - balance_before

        print(f'\nTRUST balance after: {Web3.from_wei(balance_after, "ether")}')
        print(f'Balance increase: {Web3.from_wei(balance_increase, "ether")} TRUST')

        if balance_increase != amount_claimed:
            print('Warning: Balance increase does not match claimed amount')

        # Step 13: Verify claim is now recorded
        now_claimed = trust_bonding.functions.hasClaimedRewardsForEpoch(
            account.address,
            previous_epoch
        ).call()

        print(f'Claim recorded for epoch {previous_epoch}: {now_claimed}')

        return {
            'amount_claimed': amount_claimed,
            'epoch': previous_epoch,
            'tx_hash': receipt['transactionHash'].hex(),
            'apy': {
                'current': current_apy / 100,
                'max': max_apy / 100
            }
        }

    except ValueError as e:
        raise ValueError(f'Validation error: {str(e)}')
    except Exception as e:
        if 'insufficient funds' in str(e).lower():
            raise Exception('Insufficient ETH for gas fees')
        elif 'norewardstoclaim' in str(e).lower():
            raise Exception('No rewards available to claim')
        elif 'rewardsalreadyclaimedforepoch' in str(e).lower():
            raise Exception(f'Rewards already claimed for epoch {previous_epoch}')
        elif 'revert' in str(e).lower():
            raise Exception(f'Contract call reverted: {str(e)}')
        raise


def get_reward_info(user_address: str) -> Dict[str, any]:
    """
    Gets detailed reward information without claiming

    Args:
        user_address: Address to check rewards for

    Returns:
        Dictionary containing reward and APY information
    """
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    trust_bonding = w3.eth.contract(
        address=Web3.to_checksum_address(TRUST_BONDING_ADDRESS),
        abi=TRUST_BONDING_ABI
    )

    current_epoch = trust_bonding.functions.currentEpoch().call()
    previous_epoch = trust_bonding.functions.previousEpoch().call()

    claimable_rewards = 0
    already_claimed = False
    personal_ratio = 0
    system_ratio = 0

    if current_epoch > 0:
        claimable_rewards = trust_bonding.functions.getUserCurrentClaimableRewards(
            user_address
        ).call()

        already_claimed = trust_bonding.functions.hasClaimedRewardsForEpoch(
            user_address,
            previous_epoch
        ).call()

        personal_ratio = trust_bonding.functions.getPersonalUtilizationRatio(
            user_address,
            previous_epoch
        ).call()

        system_ratio = trust_bonding.functions.getSystemUtilizationRatio(
            previous_epoch
        ).call()

    current_apy, max_apy = trust_bonding.functions.getUserApy(user_address).call()

    return {
        'claimable_rewards': claimable_rewards,
        'current_epoch': current_epoch,
        'claimable_epoch': previous_epoch,
        'already_claimed': already_claimed,
        'personal_ratio': personal_ratio / 1e18 if personal_ratio > 0 else 0,
        'system_ratio': system_ratio / 1e18 if system_ratio > 0 else 0,
        'current_apy': current_apy / 100,
        'max_apy': max_apy / 100
    }


# Usage example
if __name__ == '__main__':
    try:
        # First, check reward info
        info = get_reward_info('0xYourAddress')

        print('Reward Information:')
        print(f'  Claimable: {Web3.from_wei(info["claimable_rewards"], "ether")} TRUST')
        print(f'  Current epoch: {info["current_epoch"]}')
        print(f'  Claimable epoch: {info["claimable_epoch"]}')
        print(f'  Already claimed: {info["already_claimed"]}')
        print(f'  Current APY: {info["current_apy"]:.2f}%')

        if info['claimable_rewards'] > 0 and not info['already_claimed']:
            # Claim rewards
            result = claim_rewards(
                recipient='0xYourAddress',
                private_key='YOUR_PRIVATE_KEY'
            )

            print('\n=== Claim Successful ===')
            print(f'Amount Claimed: {Web3.from_wei(result["amount_claimed"], "ether")} TRUST')
            print(f'Epoch: {result["epoch"]}')
            print(f'Transaction: {result["tx_hash"]}')
            print(f'Current APY: {result["apy"]["current"]:.2f}%')
            print(f'Max APY: {result["apy"]["max"]:.2f}%')
        else:
            print('\nNo rewards to claim or already claimed')

    except Exception as e:
        print(f'Error: {str(e)}')
        exit(1)
```

## Event Monitoring

### Events Emitted

When claiming rewards, the following event is emitted:

#### RewardsClaimed

```solidity
event RewardsClaimed(
    address indexed user,
    address indexed recipient,
    uint256 amount
);
```

**Parameters**:
- `user`: Address that claimed the rewards (msg.sender)
- `recipient`: Address that received the TRUST tokens
- `amount`: Amount of TRUST tokens minted and sent

### Listening for Events

**TypeScript**:
```typescript
// Listen for RewardsClaimed events
trustBonding.on('RewardsClaimed', (user, recipient, amount, event) => {
  console.log('Rewards claimed:');
  console.log('  User:', user);
  console.log('  Recipient:', recipient);
  console.log('  Amount:', formatEther(amount), 'TRUST');
  console.log('  Block:', event.log.blockNumber);
});

// Query historical claims
const filter = trustBonding.filters.RewardsClaimed(myAddress);
const events = await trustBonding.queryFilter(filter, -10000);

// Calculate total claimed
const totalClaimed = events.reduce((sum, event) => {
  return sum + event.args.amount;
}, 0n);

console.log('Total TRUST claimed:', formatEther(totalClaimed));
```

**Python**:
```python
# Create event filter
event_filter = trust_bonding.events.RewardsClaimed.create_filter(
    from_block='latest',
    argument_filters={'user': account.address}
)

# Poll for new claims
while True:
    for event in event_filter.get_new_entries():
        print(f'Rewards claimed:')
        print(f'  User: {event["args"]["user"]}')
        print(f'  Recipient: {event["args"]["recipient"]}')
        print(f'  Amount: {Web3.from_wei(event["args"]["amount"], "ether")} TRUST')

    time.sleep(12)
```

## Error Handling

### Common Errors

#### 1. No Rewards To Claim

**Error**: `TrustBonding_NoRewardsToClaim()`

**Cause**: User has no eligible rewards for the previous epoch.

**Recovery**:
- Check `getUserCurrentClaimableRewards()` before claiming
- Ensure you had active utilization in the previous epoch
- Deposit into vaults to generate utilization

#### 2. Rewards Already Claimed

**Error**: `TrustBonding_RewardsAlreadyClaimedForEpoch()`

**Cause**: Already claimed rewards for the previous epoch.

**Recovery**:
- Check `hasClaimedRewardsForEpoch()` before claiming
- Wait for next epoch to claim again
- Track claim history off-chain

#### 3. No Claiming During First Epoch

**Error**: `TrustBonding_NoClaimingDuringFirstEpoch()`

**Cause**: Attempting to claim in epoch 0 or 1.

**Recovery**:
- Wait until epoch 2 or later
- Rewards are claimable starting in epoch n+1
- Build utilization during epoch 0 and 1

#### 4. Invalid Epoch

**Error**: `TrustBonding_InvalidEpoch()`

**Cause**: Querying data for an invalid epoch number.

**Recovery**:
- Use `currentEpoch()` and `previousEpoch()` functions
- Don't query future epochs
- Ensure epoch number is within valid range

#### 5. Paused Contract

**Error**: `Pausable: paused`

**Cause**: TrustBonding contract is paused.

**Recovery**:
- Wait for contract to be unpaused
- Monitor protocol announcements
- Cannot claim while paused

#### 6. Zero Recipient Address

**Error**: Invalid recipient address

**Cause**: Provided zero address as recipient.

**Recovery**:
- Provide valid recipient address
- Can send to any address, including your own

### Error Handling Pattern

```typescript
try {
  const result = await claimRewards(recipient, privateKey);
} catch (error) {
  if (error.message.includes('NoRewardsToClaim')) {
    console.log('No rewards available');
    // Check utilization and deposit more
    const utilization = await multiVault.getUserUtilizationForEpoch(
      address,
      await trustBonding.currentEpoch()
    );
    console.log('Current utilization:', utilization);
  } else if (error.message.includes('RewardsAlreadyClaimedForEpoch')) {
    console.log('Already claimed for this epoch');
    // Wait for next epoch
    const epochEnd = await trustBonding.epochTimestampEnd(
      await trustBonding.currentEpoch()
    );
    console.log('Next epoch starts:', new Date(Number(epochEnd) * 1000));
  } else if (error.message.includes('NoClaimingDuringFirstEpoch')) {
    console.log('Cannot claim in first epoch, please wait');
  } else {
    console.error('Claim failed:', error);
    throw error;
  }
}
```

## Gas Estimation

### Typical Gas Costs

Operation costs on Intuition Mainnet (approximate):

| Operation | Gas Used | Notes |
|-----------|----------|-------|
| Claim rewards | ~200,000 | Mints TRUST tokens |
| First-time claim | ~250,000 | May initialize state |
| Check claimable amount | Free | View function (read-only) |
| Get user info | Free | View function (read-only) |

### Factors Affecting Cost

1. **First-time claim**: May cost more to initialize state
2. **Voting escrow updates**: If you have locked tokens
3. **Network congestion**: Gas price fluctuates
4. **Recipient address**: Minting to new address costs slightly more

### Gas Optimization Tips

```typescript
// 1. Check rewards before claiming (free view call)
const claimable = await trustBonding.getUserCurrentClaimableRewards(address);
if (claimable === 0n) {
  console.log('No rewards to claim, skipping transaction');
  return;
}

// 2. Estimate gas before sending
const gasEstimate = await trustBonding.claimRewards.estimateGas(recipient);
const gasLimit = gasEstimate * 120n / 100n; // Add 20% buffer

await trustBonding.claimRewards(recipient, { gasLimit });

// 3. Batch claims with other operations
// Cannot batch reward claims, but can combine with other transactions in same block

// 4. Claim regularly to avoid missing epochs
// Rewards expire if not claimed in epoch n+1
// Set up automated claiming if possible
```

## Best Practices

### 1. Claim Every Epoch

Rewards are only claimable in the epoch immediately after they're earned:

```typescript
// Set up periodic claiming
async function autoClaim() {
  const currentEpoch = await trustBonding.currentEpoch();
  const previousEpoch = await trustBonding.previousEpoch();

  // Check if already claimed
  const claimed = await trustBonding.hasClaimedRewardsForEpoch(
    address,
    previousEpoch
  );

  if (!claimed) {
    const claimable = await trustBonding.getUserCurrentClaimableRewards(address);

    if (claimable > 0n) {
      await claimRewards(address, privateKey);
    }
  }
}

// Run daily or when new epoch starts
setInterval(autoClaim, 86400000); // 24 hours
```

### 2. Monitor Your Utilization

Track utilization to predict rewards:

```typescript
async function checkUtilization() {
  const currentEpoch = await trustBonding.currentEpoch();

  const utilization = await multiVault.getUserUtilizationForEpoch(
    address,
    currentEpoch
  );

  const personalRatio = await trustBonding.getPersonalUtilizationRatio(
    address,
    currentEpoch
  );

  console.log('Current utilization:', utilization);
  console.log('Personal ratio:', Number(personalRatio) / 1e18);

  // Positive utilization = net depositor = eligible for rewards
  if (utilization > 0) {
    console.log('You are accumulating rewards this epoch');
  } else {
    console.log('Increase deposits to earn rewards');
  }
}
```

### 3. Maximize APY with Locking

Lock TRUST tokens to boost your reward multiplier:

```typescript
// Check your current vs max APY
const [currentApy, maxApy] = await trustBonding.getUserApy(address);

console.log('Current APY:', Number(currentApy) / 100, '%');
console.log('Max APY:', Number(maxApy) / 100, '%');

// If currentApy < maxApy, consider locking more TRUST
if (currentApy < maxApy) {
  const userInfo = await trustBonding.getUserInfo(address);

  console.log('Locked amount:', formatEther(userInfo.lockedAmount));
  console.log('Lock ends:', new Date(Number(userInfo.lockEnd) * 1000));

  // To maximize, lock more TRUST for longer duration
  // (See voting escrow documentation for lock mechanics)
}
```

### 4. Track Epoch Boundaries

Know when epochs end to claim on time:

```typescript
async function getEpochTiming() {
  const currentEpoch = await trustBonding.currentEpoch();
  const epochEnd = await trustBonding.epochTimestampEnd(currentEpoch);
  const epochLength = await trustBonding.epochLength();

  const now = Math.floor(Date.now() / 1000);
  const timeLeft = Number(epochEnd) - now;

  console.log('Current epoch:', currentEpoch);
  console.log('Epoch ends:', new Date(Number(epochEnd) * 1000));
  console.log('Time left:', Math.floor(timeLeft / 3600), 'hours');
  console.log('Epoch length:', Number(epochLength) / 86400, 'days');

  // Set reminder to claim after epoch ends
  if (timeLeft < 3600) {
    console.log('Epoch ending soon - prepare to claim next epoch!');
  }
}
```

### 5. Understand Reward Calculations

Know how your rewards are computed:

```typescript
async function explainRewards() {
  const previousEpoch = await trustBonding.previousEpoch();

  // Get base emissions for the epoch
  const emissions = await trustBonding.emissionsForEpoch(previousEpoch);

  // Get utilization ratios
  const personalRatio = await trustBonding.getPersonalUtilizationRatio(
    address,
    previousEpoch
  );

  const systemRatio = await trustBonding.getSystemUtilizationRatio(
    previousEpoch
  );

  // Get bonded balance (voting power)
  const bondedBalance = await trustBonding.userBondedBalanceAtEpochEnd(
    address,
    previousEpoch
  );

  const totalBonded = await trustBonding.totalBondedBalanceAtEpochEnd(
    previousEpoch
  );

  console.log('Reward Calculation for Epoch', previousEpoch);
  console.log('  Total emissions:', formatEther(emissions), 'TRUST');
  console.log('  Your bonded balance:', formatEther(bondedBalance), 'TRUST');
  console.log('  Total bonded:', formatEther(totalBonded), 'TRUST');
  console.log('  Your share of voting power:', Number(bondedBalance) / Number(totalBonded) * 100, '%');
  console.log('  Your utilization ratio:', Number(personalRatio) / 1e18);
  console.log('  System utilization ratio:', Number(systemRatio) / 1e18);

  // Rewards ≈ emissions * (bondedBalance / totalBonded) * min(personalRatio, systemRatio)
  // Actual calculation is more complex, see TrustBonding contract
}
```

## Common Pitfalls

### 1. Missing the Claim Window

Rewards must be claimed in epoch n+1:

```typescript
// WRONG: Forgetting to claim
// Rewards for epoch 5 expire when epoch 7 starts

// CORRECT: Claim every epoch
async function claimIfAvailable() {
  const claimable = await trustBonding.getUserCurrentClaimableRewards(address);

  if (claimable > 0n) {
    await claimRewards(address, privateKey);
  } else {
    console.log('No rewards to claim this epoch');
  }
}
```

### 2. Not Checking if Already Claimed

Attempting to claim twice:

```typescript
// WRONG: No check before claiming
await trustBonding.claimRewards(recipient);

// CORRECT: Check first
const previousEpoch = await trustBonding.previousEpoch();
const claimed = await trustBonding.hasClaimedRewardsForEpoch(address, previousEpoch);

if (!claimed) {
  await trustBonding.claimRewards(recipient);
}
```

### 3. Expecting Rewards Without Utilization

Having zero or negative utilization:

```typescript
// WRONG: Expecting rewards without deposits
const rewards = await trustBonding.getUserCurrentClaimableRewards(address);
// Will be 0 if you didn't deposit in previous epoch

// CORRECT: Check utilization
const previousEpoch = await trustBonding.previousEpoch();
const utilization = await multiVault.getUserUtilizationForEpoch(
  address,
  previousEpoch
);

if (utilization <= 0) {
  console.log('No positive utilization, no rewards');
} else {
  // Expect rewards proportional to utilization
}
```

### 4. Ignoring Voting Escrow Boost

Not locking TRUST to maximize rewards:

```typescript
// WRONG: Not utilizing voting escrow
const [currentApy, maxApy] = await trustBonding.getUserApy(address);
// currentApy much lower than maxApy

// CORRECT: Lock TRUST to boost APY
// If currentApy = 10% but maxApy = 50%, you're leaving 40% APY on the table
console.log('Potential APY boost:', Number(maxApy - currentApy) / 100, '%');
console.log('Consider locking TRUST tokens for higher rewards');
```

### 5. Claiming to Wrong Address

Sending rewards to wrong recipient:

```typescript
// WRONG: Hardcoded recipient
await trustBonding.claimRewards('0x0000...');

// CORRECT: Verify recipient before claiming
const recipient = '0xYourAddress';

// Verify it's a valid address
if (!isAddress(recipient)) {
  throw new Error('Invalid recipient address');
}

await trustBonding.claimRewards(recipient);
```

### 6. Not Monitoring Epoch Changes

Missing epoch transitions:

```typescript
// WRONG: Hardcoded epoch numbers
const rewards = await trustBonding.getUserRewardsForEpoch(address, 5);

// CORRECT: Use dynamic epoch queries
const currentEpoch = await trustBonding.currentEpoch();
const previousEpoch = await trustBonding.previousEpoch();

const rewards = await trustBonding.getUserRewardsForEpoch(
  address,
  previousEpoch
);
```

## Related Operations

### Before Claiming Rewards

1. **Build utilization**: [Deposit assets](./depositing-assets.md) to increase utilization
2. **Lock TRUST**: Increase voting power for better multiplier
3. **Track epochs**: [Understand epoch mechanics](./epoch-management.md)

### After Claiming Rewards

1. **Reinvest rewards**: Deposit claimed TRUST back into vaults
2. **Lock for boost**: Lock claimed TRUST to increase future rewards
3. **Track performance**: Record claims for analytics

### Alternative Approaches

- **Automated claiming**: Set up bot to claim every epoch
- **Batch with other operations**: Claim when doing other protocol interactions
- **Delegate claiming**: Allow another address to claim on your behalf

## See Also

- [Epoch Management Guide](./epoch-management.md)
- [Utilization Mechanics](./utilization-mechanics.md)
- [Depositing Assets](./depositing-assets.md)
- [Emissions System Concept](../concepts/emissions-system.md)
- [TrustBonding Contract Reference](../contracts/emissions/TrustBonding.md)

---

**Last Updated**: December 2025
