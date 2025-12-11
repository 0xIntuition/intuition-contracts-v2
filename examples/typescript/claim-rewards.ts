/**
 * @title Claim Rewards Example
 * @notice Demonstrates how to claim TRUST token rewards from the TrustBonding contract
 * @dev Uses ethers.js v6 to interact with TrustBonding (voting escrow + rewards)
 *
 * What this example does:
 * 1. Checks user's current epoch and reward eligibility
 * 2. Calculates claimable rewards based on utilization and bonded balance
 * 3. Claims rewards to a specified recipient
 * 4. Shows APY calculations
 *
 * Prerequisites:
 * - Node.js v18+
 * - ethers.js v6
 * - Bonded TRUST tokens (veWTRUST)
 * - Active utilization in the previous epoch
 */

import { ethers } from 'ethers';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0;

const TRUST_BONDING_ADDRESS = '0x635bBD1367B66E7B16a21D6E5A63C812fFC00617'; // Intuition Mainnet
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

// Reward recipient (defaults to sender if not specified)
const REWARD_RECIPIENT = ''; // Leave empty to claim to yourself

// ============================================================================
// Contract ABIs
// ============================================================================

const TRUST_BONDING_ABI = [
  // Epoch functions
  'function currentEpoch() external view returns (uint256)',
  'function previousEpoch() external view returns (uint256)',
  'function epochLength() external view returns (uint256)',
  'function epochsPerYear() external view returns (uint256)',
  'function epochTimestampEnd(uint256 epoch) external view returns (uint256)',

  // Reward functions
  'function claimRewards(address recipient) external',
  'function getUserCurrentClaimableRewards(address account) external view returns (uint256)',
  'function getUserRewardsForEpoch(address account, uint256 epoch) external view returns (uint256 eligibleRewards, uint256 maxRewards)',
  'function hasClaimedRewardsForEpoch(address account, uint256 epoch) external view returns (bool)',
  'function getUserInfo(address account) external view returns (tuple(uint256 personalUtilization, uint256 eligibleRewards, uint256 maxRewards, uint256 lockedAmount, uint256 lockEnd, uint256 bondedBalance))',

  // APY functions
  'function getUserApy(address account) external view returns (uint256 currentApy, uint256 maxApy)',
  'function getSystemApy() external view returns (uint256 currentApy, uint256 maxApy)',

  // Utilization functions
  'function getPersonalUtilizationRatio(address account, uint256 epoch) external view returns (uint256)',
  'function getSystemUtilizationRatio(uint256 epoch) external view returns (uint256)',

  // Events
  'event RewardsClaimed(address indexed user, address indexed recipient, uint256 amount)',
];

const ERC20_ABI = [
  'function balanceOf(address account) external view returns (uint256)',
];

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

    const provider = new ethers.JsonRpcProvider(RPC_URL, {
      chainId: CHAIN_ID,
      name: 'intuition',
    });

    const signer = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log(`✓ Connected with address: ${signer.address}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 2: Initialize Contracts
    // ------------------------------------------------------------------------
    console.log('Step 2: Initializing contract instances...');

    const trustBonding = new ethers.Contract(
      TRUST_BONDING_ADDRESS,
      TRUST_BONDING_ABI,
      signer
    );

    const wTrust = new ethers.Contract(
      WTRUST_ADDRESS,
      ERC20_ABI,
      signer
    );

    console.log(`✓ TrustBonding: ${TRUST_BONDING_ADDRESS}`);
    console.log(`✓ WTRUST: ${WTRUST_ADDRESS}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 3: Check Epoch Information
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking epoch information...');

    const currentEpoch = await trustBonding.currentEpoch();
    const previousEpoch = await trustBonding.previousEpoch();
    const epochLength = await trustBonding.epochLength();
    const epochsPerYear = await trustBonding.epochsPerYear();

    console.log(`Current Epoch: ${currentEpoch}`);
    console.log(`Previous Epoch: ${previousEpoch} (claimable)`);
    console.log(`Epoch Length: ${epochLength} seconds (${Number(epochLength) / 3600} hours)`);
    console.log(`Epochs Per Year: ${epochsPerYear}`);

    // Get previous epoch end time
    const prevEpochEnd = await trustBonding.epochTimestampEnd(previousEpoch);
    console.log(`Previous Epoch Ended: ${formatTimestamp(prevEpochEnd)}`);

    // Get current epoch end time
    const currEpochEnd = await trustBonding.epochTimestampEnd(currentEpoch);
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

    const userInfo = await trustBonding.getUserInfo(signer.address);

    console.log('Your User Info:');
    console.log(`  Bonded Balance: ${ethers.formatEther(userInfo.bondedBalance)} veWTRUST`);
    console.log(`  Locked Amount: ${ethers.formatEther(userInfo.lockedAmount)} WTRUST`);

    if (userInfo.lockEnd &gt; 0n) {
      console.log(`  Lock Ends: ${formatTimestamp(userInfo.lockEnd)}`);
    } else {
      console.log(`  Lock Ends: Not locked`);
    }

    console.log(`  Personal Utilization: ${userInfo.personalUtilization}`);
    console.log(`  Eligible Rewards: ${ethers.formatEther(userInfo.eligibleRewards)} WTRUST`);
    console.log(`  Max Rewards: ${ethers.formatEther(userInfo.maxRewards)} WTRUST`);
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

    const claimableRewards = await trustBonding.getUserCurrentClaimableRewards(signer.address);
    console.log(`Current Claimable Rewards: ${ethers.formatEther(claimableRewards)} WTRUST`);

    if (claimableRewards === 0n) {
      console.log();
      console.log('⚠ No rewards to claim at this time');

      // Check if already claimed for previous epoch
      const alreadyClaimed = await trustBonding.hasClaimedRewardsForEpoch(
        signer.address,
        previousEpoch
      );

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

    const [eligibleRewards, maxRewards] = await trustBonding.getUserRewardsForEpoch(
      signer.address,
      previousEpoch
    );

    console.log(`Epoch ${previousEpoch} Rewards:`);
    console.log(`  Eligible Rewards: ${ethers.formatEther(eligibleRewards)} WTRUST`);
    console.log(`  Max Possible Rewards: ${ethers.formatEther(maxRewards)} WTRUST`);

    const utilizationEfficiency = maxRewards &gt; 0n
      ? (Number(eligibleRewards) / Number(maxRewards) * 100).toFixed(2)
      : '0.00';
    console.log(`  Utilization Efficiency: ${utilizationEfficiency}%`);
    console.log();

    // Get utilization ratios for context
    try {
      const personalRatio = await trustBonding.getPersonalUtilizationRatio(
        signer.address,
        previousEpoch
      );
      const systemRatio = await trustBonding.getSystemUtilizationRatio(previousEpoch);

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

    const [userCurrentApy, userMaxApy] = await trustBonding.getUserApy(signer.address);
    const [systemCurrentApy, systemMaxApy] = await trustBonding.getSystemApy();

    console.log('Your APY:');
    console.log(`  Current APY: ${formatApy(userCurrentApy)}`);
    console.log(`  Max Possible APY: ${formatApy(userMaxApy)}`);
    console.log();

    console.log('System APY:');
    console.log(`  Current APY: ${formatApy(systemCurrentApy)}`);
    console.log(`  Max Possible APY: ${formatApy(systemMaxApy)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Check Current WTRUST Balance
    // ------------------------------------------------------------------------
    console.log('Step 8: Checking current WTRUST balance...');

    const currentBalance = await wTrust.balanceOf(signer.address);
    console.log(`Current WTRUST Balance: ${ethers.formatEther(currentBalance)} WTRUST`);
    console.log(`Expected After Claim: ${ethers.formatEther(currentBalance + claimableRewards)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Claim Rewards
    // ------------------------------------------------------------------------
    console.log('Step 9: Claiming rewards...');

    // Determine recipient
    const recipient = REWARD_RECIPIENT || signer.address;
    console.log(`Claiming ${ethers.formatEther(claimableRewards)} WTRUST`);
    console.log(`Recipient: ${recipient}`);
    console.log();

    // Estimate gas
    const gasEstimate = await trustBonding.claimRewards.estimateGas(recipient);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute claim
    const claimTx = await trustBonding.claimRewards(recipient, {
      gasLimit: gasEstimate * 120n / 100n, // Add 20% buffer
    });

    console.log(`Transaction submitted: ${claimTx.hash}`);
    console.log('Waiting for confirmation...');

    const receipt = await claimTx.wait();
    console.log(`✓ Transaction confirmed in block ${receipt?.blockNumber}`);
    console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 10: Parsing transaction events...');

    if (receipt) {
      const rewardsClaimedEvent = receipt.logs
        .map(log =&gt; {
          try {
            return trustBonding.interface.parseLog({
              topics: log.topics as string[],
              data: log.data,
            });
          } catch {
            return null;
          }
        })
        .find(event =&gt; event?.name === 'RewardsClaimed');

      if (rewardsClaimedEvent) {
        console.log('RewardsClaimed Event:');
        console.log(`  User: ${rewardsClaimedEvent.args[0]}`);
        console.log(`  Recipient: ${rewardsClaimedEvent.args[1]}`);
        console.log(`  Amount: ${ethers.formatEther(rewardsClaimedEvent.args[2])} WTRUST`);
        console.log();
      }
    }

    // ------------------------------------------------------------------------
    // Step 11: Verify Updated Balance
    // ------------------------------------------------------------------------
    console.log('Step 11: Verifying updated WTRUST balance...');

    const recipientBalance = await wTrust.balanceOf(recipient);
    console.log(`Recipient WTRUST Balance: ${ethers.formatEther(recipientBalance)} WTRUST`);
    console.log();

    // Verify claim worked
    const newClaimable = await trustBonding.getUserCurrentClaimableRewards(signer.address);
    if (newClaimable === 0n) {
      console.log('✓ All available rewards have been claimed');
    } else {
      console.log(`Remaining Claimable: ${ethers.formatEther(newClaimable)} WTRUST`);
    }
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Rewards claimed successfully!');
    console.log(`Claimed: ${ethers.formatEther(claimableRewards)} WTRUST`);
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt?.hash}`);
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
  .then(() =&gt; process.exit(0))
  .catch((error) =&gt; {
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
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

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
  Locked Amount: 1000.0 WTRUST
  Lock Ends: 6/10/2026, 12:00:00 PM
  Personal Utilization: 500000000000000000000
  Eligible Rewards: 5.5 WTRUST
  Max Rewards: 10.0 WTRUST

Step 5: Checking claimable rewards...
Current Claimable Rewards: 5.5 WTRUST

Step 6: Getting detailed reward info for previous epoch...
Epoch 41 Rewards:
  Eligible Rewards: 5.5 WTRUST
  Max Possible Rewards: 10.0 WTRUST
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

Step 8: Checking current WTRUST balance...
Current WTRUST Balance: 50.0 WTRUST
Expected After Claim: 55.5 WTRUST

Step 9: Claiming rewards...
Claiming 5.5 WTRUST
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
  Amount: 5.5 WTRUST

Step 11: Verifying updated WTRUST balance...
Recipient WTRUST Balance: 55.5 WTRUST

✓ All available rewards have been claimed

================================================================================
✓ Rewards claimed successfully!
Claimed: 5.5 WTRUST
View on explorer: https://explorer.intuit.network/tx/0xabc123...
================================================================================
*/
