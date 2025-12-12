/**
 * @title Claim Rewards Example
 * @notice Demonstrates how to claim TRUST token rewards from the TrustBonding contract
 * @dev Uses viem to interact with TrustBonding (voting escrow + rewards)
 *
 * What this example does:
 * 1. Checks user's current epoch and reward eligibility
 * 2. Calculates claimable rewards based on utilization and bonded balance
 * 3. Claims rewards to a specified recipient
 * 4. Shows APY calculations
 *
 * Prerequisites:
 * - Node.js v18+
 * - viem installed: `npm install viem`
 * - Bonded TRUST tokens (veWTRUST)
 * - Active utilization in the previous epoch
 */

import { createPublicClient, createWalletClient, http, formatEther, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0;

const TRUST_BONDING_ADDRESS = '0x635bBD1367B66E7B16a21D6E5A63C812fFC00617' as `0x${string}`; // Intuition Mainnet

const PRIVATE_KEY = (process.env.PRIVATE_KEY || '') as `0x${string}`;

// Reward recipient (defaults to sender if not specified)
const REWARD_RECIPIENT = ''; // Leave empty to claim to yourself

// ============================================================================
// Contract ABIs
// ============================================================================

const TRUST_BONDING_ABI = [
  // Epoch functions
  {
    name: 'currentEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'previousEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'epochLength',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'epochsPerYear',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'epochTimestampEnd',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  // Reward functions
  {
    name: 'claimRewards',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'recipient', type: 'address' }],
    outputs: []
  },
  {
    name: 'getUserCurrentClaimableRewards',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'getUserRewardsForEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'epoch', type: 'uint256' }
    ],
    outputs: [
      { name: 'eligibleRewards', type: 'uint256' },
      { name: 'maxRewards', type: 'uint256' }
    ]
  },
  {
    name: 'hasClaimedRewardsForEpoch',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'epoch', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'getUserInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'personalUtilization', type: 'uint256' },
          { name: 'eligibleRewards', type: 'uint256' },
          { name: 'maxRewards', type: 'uint256' },
          { name: 'lockedAmount', type: 'uint256' },
          { name: 'lockEnd', type: 'uint256' },
          { name: 'bondedBalance', type: 'uint256' }
        ]
      }
    ]
  },
  // APY functions
  {
    name: 'getUserApy',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [
      { name: 'currentApy', type: 'uint256' },
      { name: 'maxApy', type: 'uint256' }
    ]
  },
  {
    name: 'getSystemApy',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'currentApy', type: 'uint256' },
      { name: 'maxApy', type: 'uint256' }
    ]
  },
  // Utilization functions
  {
    name: 'getPersonalUtilizationRatio',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'epoch', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'getSystemUtilizationRatio',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'epoch', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  // Events
  {
    name: 'RewardsClaimed',
    type: 'event',
    inputs: [
      { name: 'user', type: 'address', indexed: true },
      { name: 'recipient', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false }
    ]
  }
] as const;

// ============================================================================
// Helper Functions
// ============================================================================

function formatApy(apy: bigint): string {
  // APY is in basis points (10000 = 100%)
  return (Number(apy) / 100).toFixed(2) + '%';
}

function formatUtilization(ratio: bigint): string {
  // Ratio is scaled by 1e18
  return (Number(ratio) / 1e16).toFixed(2) + '%';
}

function formatTimestamp(timestamp: bigint): string {
  return new Date(Number(timestamp) * 1000).toLocaleString();
}

// ============================================================================
// Main Function
// ============================================================================

async function main() {
  try {
    console.log('='.repeat(80));
    console.log('Claiming TRUST Rewards from Intuition Protocol');
    console.log('='.repeat(80));
    console.log();

    // ------------------------------------------------------------------------
    // Step 1: Setup
    // ------------------------------------------------------------------------
    console.log('Step 1: Connecting to Intuition network...');

    // Create public client for reading blockchain data
    const publicClient = createPublicClient({
      chain: base, // Replace with actual Intuition chain
      transport: http(RPC_URL)
    });

    // Create account from private key
    const account = privateKeyToAccount(PRIVATE_KEY);

    // Create wallet client for transactions
    const walletClient = createWalletClient({
      account,
      chain: base, // Replace with actual Intuition chain
      transport: http(RPC_URL)
    });

    console.log(`✓ Connected with address: ${account.address}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 2: Initialize Contracts
    // ------------------------------------------------------------------------
    console.log('Step 2: Initializing contract instances...');

    const trustBonding = getContract({
      address: TRUST_BONDING_ADDRESS,
      abi: TRUST_BONDING_ABI,
      client: { public: publicClient, wallet: walletClient }
    });

    console.log(`✓ TrustBonding: ${TRUST_BONDING_ADDRESS}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 3: Check Epoch Information
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking epoch information...');

    const currentEpoch = await trustBonding.read.currentEpoch();
    const previousEpoch = await trustBonding.read.previousEpoch();
    const epochLength = await trustBonding.read.epochLength();
    const epochsPerYear = await trustBonding.read.epochsPerYear();

    console.log(`Current Epoch: ${currentEpoch}`);
    console.log(`Previous Epoch: ${previousEpoch} (claimable)`);
    console.log(`Epoch Length: ${epochLength} seconds (${Number(epochLength) / 3600} hours)`);
    console.log(`Epochs Per Year: ${epochsPerYear}`);

    // Get previous epoch end time
    const prevEpochEnd = await trustBonding.read.epochTimestampEnd([previousEpoch]);
    console.log(`Previous Epoch Ended: ${formatTimestamp(prevEpochEnd)}`);

    // Get current epoch end time
    const currEpochEnd = await trustBonding.read.epochTimestampEnd([currentEpoch]);
    console.log(`Current Epoch Ends: ${formatTimestamp(currEpochEnd)}`);
    console.log();

    // Note: Rewards for epoch N are claimable in epoch N+1
    console.log(`📝 Note: Rewards for epoch ${previousEpoch} are claimable now`);
    console.log(`         Rewards for epoch ${currentEpoch} will be claimable in epoch ${currentEpoch + 1n}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Get User Info
    // ------------------------------------------------------------------------
    console.log('Step 4: Fetching your user information...');

    const userInfo = await trustBonding.read.getUserInfo([account.address]);

    console.log('Your User Info:');
    console.log(`  Bonded Balance: ${formatEther(userInfo.bondedBalance)} veWTRUST`);
    console.log(`  Locked Amount: ${formatEther(userInfo.lockedAmount)} TRUST`);

    if (userInfo.lockEnd > 0n) {
      console.log(`  Lock Ends: ${formatTimestamp(userInfo.lockEnd)}`);
    } else {
      console.log(`  Lock Ends: Not locked`);
    }

    console.log(`  Personal Utilization: ${userInfo.personalUtilization}`);
    console.log(`  Eligible Rewards: ${formatEther(userInfo.eligibleRewards)} TRUST`);
    console.log(`  Max Rewards: ${formatEther(userInfo.maxRewards)} TRUST`);
    console.log();

    if (userInfo.bondedBalance === 0n) {
      console.log('⚠ Warning: You have no bonded balance (veWTRUST)');
      console.log('To earn rewards, you need to lock TRUST tokens first');
      return;
    }

    // ------------------------------------------------------------------------
    // Step 5: Check Claimable Rewards
    // ------------------------------------------------------------------------
    console.log('Step 5: Checking claimable rewards...');

    const claimableRewards = await trustBonding.read.getUserCurrentClaimableRewards([account.address]);
    console.log(`Current Claimable Rewards: ${formatEther(claimableRewards)} TRUST`);

    if (claimableRewards === 0n) {
      console.log();
      console.log('⚠ No rewards to claim at this time');

      // Check if already claimed for previous epoch
      const alreadyClaimed = await trustBonding.read.hasClaimedRewardsForEpoch([
        account.address,
        previousEpoch
      ]);

      if (alreadyClaimed) {
        console.log(`You already claimed rewards for epoch ${previousEpoch}`);
      } else {
        console.log('You may not have had sufficient utilization in the previous epoch');
      }

      return;
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Get Detailed Reward Info for Previous Epoch
    // ------------------------------------------------------------------------
    console.log('Step 6: Getting detailed reward info for previous epoch...');

    const [eligibleRewards, maxRewards] = await trustBonding.read.getUserRewardsForEpoch([
      account.address,
      previousEpoch
    ]);

    console.log(`Epoch ${previousEpoch} Rewards:`);
    console.log(`  Eligible Rewards: ${formatEther(eligibleRewards)} TRUST`);
    console.log(`  Max Possible Rewards: ${formatEther(maxRewards)} TRUST`);

    const utilizationEfficiency = maxRewards > 0n
      ? (Number(eligibleRewards) / Number(maxRewards) * 100).toFixed(2)
      : '0.00';
    console.log(`  Utilization Efficiency: ${utilizationEfficiency}%`);
    console.log();

    // Get utilization ratios for context
    try {
      const personalRatio = await trustBonding.read.getPersonalUtilizationRatio([
        account.address,
        previousEpoch
      ]);
      const systemRatio = await trustBonding.read.getSystemUtilizationRatio([previousEpoch]);

      console.log(`Epoch ${previousEpoch} Utilization:`);
      console.log(`  Your Personal Ratio: ${formatUtilization(personalRatio)}`);
      console.log(`  System Ratio: ${formatUtilization(systemRatio)}`);
      console.log();
    } catch {
      console.log('(Utilization ratios unavailable for this epoch)');
      console.log();
    }

    // ------------------------------------------------------------------------
    // Step 7: Check APY
    // ------------------------------------------------------------------------
    console.log('Step 7: Checking current APY...');

    const [userCurrentApy, userMaxApy] = await trustBonding.read.getUserApy([account.address]);
    const [systemCurrentApy, systemMaxApy] = await trustBonding.read.getSystemApy();

    console.log('Your APY:');
    console.log(`  Current APY: ${formatApy(userCurrentApy)}`);
    console.log(`  Max Possible APY: ${formatApy(userMaxApy)}`);
    console.log();

    console.log('System APY:');
    console.log(`  Current APY: ${formatApy(systemCurrentApy)}`);
    console.log(`  Max Possible APY: ${formatApy(systemMaxApy)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Check Current Native Balance
    // ------------------------------------------------------------------------
    console.log('Step 8: Checking current native TRUST balance...');

    const currentBalance = await publicClient.getBalance({ address: account.address });
    console.log(`Current TRUST Balance: ${formatEther(currentBalance)} TRUST`);
    console.log(`Expected After Claim: ${formatEther(currentBalance + claimableRewards)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Claim Rewards
    // ------------------------------------------------------------------------
    console.log('Step 9: Claiming rewards...');

    // Determine recipient
    const recipient = (REWARD_RECIPIENT || account.address) as `0x${string}`;
    console.log(`Claiming ${formatEther(claimableRewards)} TRUST`);
    console.log(`Recipient: ${recipient}`);
    console.log();

    // Estimate gas
    const gasEstimate = await trustBonding.estimateGas.claimRewards([recipient]);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute claim
    const claimTx = await trustBonding.write.claimRewards([recipient], {
      gas: gasEstimate * 120n / 100n, // Add 20% buffer
    });

    console.log(`Transaction submitted: ${claimTx}`);
    console.log('Waiting for confirmation...');

    const receipt = await publicClient.waitForTransactionReceipt({ hash: claimTx });
    console.log(`✓ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 10: Parsing transaction events...');

    const rewardsClaimedLog = receipt.logs.find(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: TRUST_BONDING_ABI,
          logs: [log],
          eventName: 'RewardsClaimed'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (rewardsClaimedLog) {
      const rewardsClaimedEvent = publicClient.parseEventLogs({
        abi: TRUST_BONDING_ABI,
        logs: [rewardsClaimedLog],
        eventName: 'RewardsClaimed'
      })[0];

      if (rewardsClaimedEvent && rewardsClaimedEvent.args) {
        console.log('RewardsClaimed Event:');
        console.log(`  User: ${rewardsClaimedEvent.args.user}`);
        console.log(`  Recipient: ${rewardsClaimedEvent.args.recipient}`);
        console.log(`  Amount: ${formatEther(rewardsClaimedEvent.args.amount)} TRUST`);
        console.log();
      }
    }

    // ------------------------------------------------------------------------
    // Step 11: Verify Updated Balance
    // ------------------------------------------------------------------------
    console.log('Step 11: Verifying updated native TRUST balance...');

    const recipientBalance = await publicClient.getBalance({ address: recipient });
    console.log(`Recipient TRUST Balance: ${formatEther(recipientBalance)} TRUST`);
    console.log();

    // Verify claim worked
    const newClaimable = await trustBonding.read.getUserCurrentClaimableRewards([account.address]);
    if (newClaimable === 0n) {
      console.log('✓ All available rewards have been claimed');
    } else {
      console.log(`Remaining Claimable: ${formatEther(newClaimable)} TRUST`);
    }
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Rewards claimed successfully!');
    console.log(`Claimed: ${formatEther(claimableRewards)} TRUST`);
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt.transactionHash}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ Error claiming rewards:');
    console.error('='.repeat(80));

    if (error instanceof Error) {
      console.error(`Message: ${error.message}`);

      if (error.message.includes('NoRewardsToClaim')) {
        console.error('\nCause: No rewards available to claim');
        console.error('Solution: Wait for the next epoch or increase your utilization');
      } else if (error.message.includes('NoClaimingDuringFirstEpoch')) {
        console.error('\nCause: Cannot claim during the first epoch');
        console.error('Solution: Wait for epoch 1 to claim rewards from epoch 0');
      } else if (error.message.includes('RewardsAlreadyClaimedForEpoch')) {
        console.error('\nCause: You already claimed rewards for this epoch');
        console.error('Solution: Wait for the next epoch');
      }
    }

    console.error();
    process.exit(1);
  }
}

// ============================================================================
// Execute
// ============================================================================

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// ============================================================================
// Example Output
// ============================================================================

/*
================================================================================
Claiming TRUST Rewards from Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ TrustBonding: 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617

Step 3: Checking epoch information...
Current Epoch: 42
Previous Epoch: 41 (claimable)
Epoch Length: 86400 seconds (24 hours)
Epochs Per Year: 365
Previous Epoch Ended: 12/10/2025, 12:00:00 PM
Current Epoch Ends: 12/11/2025, 12:00:00 PM

📝 Note: Rewards for epoch 41 are claimable now
         Rewards for epoch 42 will be claimable in epoch 43

Step 4: Fetching your user information...
Your User Info:
  Bonded Balance: 1000.0 veWTRUST
  Locked Amount: 1000.0 TRUST
  Lock Ends: 6/10/2026, 12:00:00 PM
  Personal Utilization: 500000000000000000000
  Eligible Rewards: 5.5 TRUST
  Max Rewards: 10.0 TRUST

Step 5: Checking claimable rewards...
Current Claimable Rewards: 5.5 TRUST

Step 6: Getting detailed reward info for previous epoch...
Epoch 41 Rewards:
  Eligible Rewards: 5.5 TRUST
  Max Possible Rewards: 10.0 TRUST
  Utilization Efficiency: 55.00%

Epoch 41 Utilization:
  Your Personal Ratio: 75.50%
  System Ratio: 68.25%

Step 7: Checking current APY...
Your APY:
  Current APY: 12.35%
  Max Possible APY: 22.45%

System APY:
  Current APY: 15.20%
  Max Possible APY: 25.00%

Step 8: Checking current native TRUST balance...
Current TRUST Balance: 50.0 TRUST
Expected After Claim: 55.5 TRUST

Step 9: Claiming rewards...
Claiming 5.5 TRUST
Recipient: 0x1234567890123456789012345678901234567890

Estimated gas: 120000
Transaction submitted: 0xabc123...
Waiting for confirmation...
✓ Transaction confirmed in block 12370
Gas used: 108456

Step 10: Parsing transaction events...
RewardsClaimed Event:
  User: 0x1234567890123456789012345678901234567890
  Recipient: 0x1234567890123456789012345678901234567890
  Amount: 5.5 TRUST

Step 11: Verifying updated native TRUST balance...
Recipient TRUST Balance: 55.5 TRUST

✓ All available rewards have been claimed

================================================================================
✓ Rewards claimed successfully!
Claimed: 5.5 TRUST
View on explorer: https://explorer.intuit.network/tx/0xabc123...
================================================================================
*/
