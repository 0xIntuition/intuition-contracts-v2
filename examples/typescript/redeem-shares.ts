/**
 * @title Redeem Shares Example
 * @notice Demonstrates how to redeem vault shares for underlying assets
 * @dev This example uses viem to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Checks user's share balance in a vault
 * 2. Previews redemption to estimate assets received
 * 3. Redeems shares with slippage protection
 * 4. Shows how fees are deducted from redemption
 *
 * Prerequisites:
 * - Node.js v18+
 * - viem installed: `npm install viem`
 * - Shares in an atom or triple vault
 */

import { createPublicClient, createWalletClient, http, parseEther, formatEther, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0;

const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;

const PRIVATE_KEY = (process.env.PRIVATE_KEY || '') as `0x${string}`;

// Redemption configuration
const TERM_ID = '0x0000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`;
const CURVE_ID = 1;
const SHARES_TO_REDEEM = parseEther('5'); // 5 shares
const SLIPPAGE_TOLERANCE = 1; // 1% slippage tolerance

// Set to true to redeem ALL shares
const REDEEM_ALL = false;

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  {
    name: 'redeem',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'receiver', type: 'address' },
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' },
      { name: 'shares', type: 'uint256' },
      { name: 'minAssets', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'previewRedeem',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' },
      { name: 'shares', type: 'uint256' }
    ],
    outputs: [
      { name: 'assetsAfterFees', type: 'uint256' },
      { name: 'sharesUsed', type: 'uint256' }
    ]
  },
  {
    name: 'getShares',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'maxRedeem',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'sender', type: 'address' },
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'convertToAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' },
      { name: 'shares', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'currentSharePrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'exitFeeAmount',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'protocolFeeAmount',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'Redeemed',
    type: 'event',
    inputs: [
      { name: 'sender', type: 'address', indexed: true },
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'termId', type: 'bytes32', indexed: true },
      { name: 'curveId', type: 'uint256', indexed: false },
      { name: 'shares', type: 'uint256', indexed: false },
      { name: 'totalShares', type: 'uint256', indexed: false },
      { name: 'assets', type: 'uint256', indexed: false },
      { name: 'fees', type: 'uint256', indexed: false },
      { name: 'vaultType', type: 'uint8', indexed: false }
    ]
  }
] as const;

// ============================================================================
// Main Function
// ============================================================================

async function main() {
  try {
    console.log('='.repeat(80));
    console.log('Redeeming Shares from Vault on Intuition Protocol');
    console.log('='.repeat(80));
    console.log();

    // ------------------------------------------------------------------------
    // Step 1: Setup Clients
    // ------------------------------------------------------------------------
    console.log('Step 1: Connecting to Intuition network...');

    const publicClient = createPublicClient({
      chain: base,
      transport: http(RPC_URL)
    });

    const account = privateKeyToAccount(PRIVATE_KEY);

    const walletClient = createWalletClient({
      account,
      chain: base,
      transport: http(RPC_URL)
    });

    console.log(`✓ Connected with address: ${account.address}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 2: Initialize Contract Instances
    // ------------------------------------------------------------------------
    console.log('Step 2: Initializing contract instances...');

    const multiVault = getContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      client: { public: publicClient, wallet: walletClient }
    });

    console.log(`✓ MultiVault: ${MULTIVAULT_ADDRESS}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 3: Check Share Balance
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking your share balance...');
    console.log(`Term ID: ${TERM_ID}`);
    console.log(`Curve ID: ${CURVE_ID}`);

    const userShares = await multiVault.read.getShares([account.address, TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Your Current Shares: ${formatEther(userShares)}`);

    if (userShares === 0n) {
      throw new Error('You have no shares in this vault to redeem');
    }

    // Get maximum redeemable shares
    const maxRedeemable = await multiVault.read.maxRedeem([account.address, TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Maximum Redeemable Shares: ${formatEther(maxRedeemable)}`);

    // Determine actual shares to redeem
    let sharesToRedeem: bigint;
    if (REDEEM_ALL) {
      sharesToRedeem = maxRedeemable;
      console.log('✓ Redeeming ALL shares');
    } else {
      sharesToRedeem = SHARES_TO_REDEEM;
      if (sharesToRedeem > maxRedeemable) {
        console.log(`⚠ Warning: Requested ${formatEther(sharesToRedeem)} shares but max is ${formatEther(maxRedeemable)}`);
        sharesToRedeem = maxRedeemable;
        console.log(`Adjusting to redeem: ${formatEther(sharesToRedeem)} shares`);
      } else {
        console.log(`Shares to redeem: ${formatEther(sharesToRedeem)}`);
      }
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Get Current Position Value
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating current position value...');

    const currentValue = await multiVault.read.convertToAssets([
      TERM_ID,
      BigInt(CURVE_ID),
      userShares
    ]);
    console.log(`Total Position Value: ${formatEther(currentValue)} TRUST`);

    const sharePrice = await multiVault.read.currentSharePrice([TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Current Share Price: ${formatEther(sharePrice)} TRUST per share`);

    // Calculate value of shares being redeemed
    const redeemValue = await multiVault.read.convertToAssets([
      TERM_ID,
      BigInt(CURVE_ID),
      sharesToRedeem
    ]);
    console.log(`Value of Shares Being Redeemed: ${formatEther(redeemValue)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Preview Redemption
    // ------------------------------------------------------------------------
    console.log('Step 5: Previewing redemption...');

    const [assetsAfterFees, sharesUsed] = await multiVault.read.previewRedeem([
      TERM_ID,
      BigInt(CURVE_ID),
      sharesToRedeem
    ]);

    console.log(`Shares to Burn: ${formatEther(sharesUsed)}`);
    console.log(`Assets to Receive (after fees): ${formatEther(assetsAfterFees)} TRUST`);

    // Estimate fees
    const assetsBeforeFees = await multiVault.read.convertToAssets([
      TERM_ID,
      BigInt(CURVE_ID),
      sharesUsed
    ]);

    const totalFees = assetsBeforeFees - assetsAfterFees;
    const feePercentage = (Number(totalFees) / Number(assetsBeforeFees)) * 100;

    console.log(`\nFee Breakdown:`);
    console.log(`  Assets Before Fees: ${formatEther(assetsBeforeFees)} TRUST`);
    console.log(`  Total Fees: ${formatEther(totalFees)} TRUST (${feePercentage.toFixed(2)}%)`);

    // Try to break down fees (may not work for all vaults)
    try {
      const exitFee = await multiVault.read.exitFeeAmount([assetsBeforeFees]);
      const protocolFee = await multiVault.read.protocolFeeAmount([assetsBeforeFees]);
      console.log(`  Exit Fee: ${formatEther(exitFee)} TRUST`);
      console.log(`  Protocol Fee: ${formatEther(protocolFee)} TRUST`);
    } catch {
      console.log(`  (Fee breakdown unavailable)`);
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Calculate Slippage Protection
    // ------------------------------------------------------------------------
    console.log('Step 6: Calculating slippage protection...');

    const minAssets = assetsAfterFees * BigInt(100 - SLIPPAGE_TOLERANCE) / 100n;
    console.log(`Slippage Tolerance: ${SLIPPAGE_TOLERANCE}%`);
    console.log(`Minimum Assets (with slippage): ${formatEther(minAssets)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Check Current Native Balance
    // ------------------------------------------------------------------------
    console.log('Step 7: Checking current native TRUST balance...');

    const currentBalance = await publicClient.getBalance({ address: account.address });
    console.log(`Current TRUST Balance: ${formatEther(currentBalance)} TRUST`);
    console.log(`Expected After Redemption: ${formatEther(currentBalance + assetsAfterFees)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Execute Redemption
    // ------------------------------------------------------------------------
    console.log('Step 8: Executing redemption...');
    console.log(`Redeeming ${formatEther(sharesToRedeem)} shares`);
    console.log(`Receiver: ${account.address}`);
    console.log(`Min assets: ${formatEther(minAssets)} TRUST`);
    console.log();

    // Estimate gas
    const gasEstimate = await multiVault.estimateGas.redeem([
      account.address,
      TERM_ID,
      BigInt(CURVE_ID),
      sharesToRedeem,
      minAssets
    ]);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute redemption
    const redeemTx = await multiVault.write.redeem([
      account.address,
      TERM_ID,
      BigInt(CURVE_ID),
      sharesToRedeem,
      minAssets
    ], {
      gas: gasEstimate * 120n / 100n,
    });

    console.log(`Transaction submitted: ${redeemTx}`);
    console.log('Waiting for confirmation...');

    const receipt = await publicClient.waitForTransactionReceipt({ hash: redeemTx });
    console.log(`✓ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 9: Parsing transaction events...');

    const redeemedLog = receipt.logs.find(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: MULTIVAULT_ABI,
          logs: [log],
          eventName: 'Redeemed'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (redeemedLog) {
      const redeemedEvent = publicClient.parseEventLogs({
        abi: MULTIVAULT_ABI,
        logs: [redeemedLog],
        eventName: 'Redeemed'
      })[0];

      if (redeemedEvent && redeemedEvent.args) {
        console.log('Redeemed Event:');
        console.log(`  Sender: ${redeemedEvent.args.sender}`);
        console.log(`  Receiver: ${redeemedEvent.args.receiver}`);
        console.log(`  Term ID: ${redeemedEvent.args.termId}`);
        console.log(`  Curve ID: ${redeemedEvent.args.curveId}`);
        console.log(`  Shares Burned: ${formatEther(redeemedEvent.args.shares)}`);
        console.log(`  Remaining User Shares: ${formatEther(redeemedEvent.args.totalShares)}`);
        console.log(`  Assets Received: ${formatEther(redeemedEvent.args.assets)} TRUST`);
        console.log(`  Fees Paid: ${formatEther(redeemedEvent.args.fees)} TRUST`);
        console.log();

        // Verify we got at least the minimum assets
        const actualAssets = redeemedEvent.args.assets;
        if (actualAssets >= minAssets) {
          console.log('✓ Slippage protection satisfied');
        } else {
          console.log('⚠ Warning: Received fewer assets than minimum (should not happen)');
        }
      }
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Display Updated Position
    // ------------------------------------------------------------------------
    console.log('Step 10: Fetching updated position...');

    const newUserShares = await multiVault.read.getShares([account.address, TERM_ID, BigInt(CURVE_ID)]);
    const newBalance = await publicClient.getBalance({ address: account.address });

    console.log('Your Updated Position:');
    console.log(`  Remaining Shares: ${formatEther(newUserShares)}`);

    if (newUserShares > 0n) {
      const newValue = await multiVault.read.convertToAssets([
        TERM_ID,
        BigInt(CURVE_ID),
        newUserShares
      ]);
      console.log(`  Remaining Value: ${formatEther(newValue)} TRUST`);
    } else {
      console.log(`  Remaining Value: 0 TRUST (position fully exited)`);
    }

    console.log(`\nTRUST Balance:`);
    console.log(`  Before: ${formatEther(currentBalance)} TRUST`);
    console.log(`  After: ${formatEther(newBalance)} TRUST`);
    console.log(`  Received: ${formatEther(newBalance - currentBalance)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Redemption successful!');
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt.transactionHash}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ Error redeeming shares:');
    console.error('='.repeat(80));

    if (error instanceof Error) {
      console.error(`Message: ${error.message}`);

      if (error.message.includes('InsufficientAssets')) {
        console.error('\nCause: Slippage exceeded tolerance');
        console.error('Solution: Increase slippage tolerance or try redeeming fewer shares');
      } else if (error.message.includes('InsufficientShares')) {
        console.error('\nCause: You don\'t have enough shares');
        console.error('Solution: Check your share balance and reduce redemption amount');
      } else if (error.message.includes('ZeroShares')) {
        console.error('\nCause: Cannot redeem zero shares');
        console.error('Solution: Specify a positive number of shares to redeem');
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
Redeeming Shares from Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e

Step 3: Checking your share balance...
Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
Curve ID: 1
Your Current Shares: 14.7
Maximum Redeemable Shares: 14.7
Shares to redeem: 5.0

Step 4: Calculating current position value...
Total Position Value: 15.0 TRUST
Current Share Price: 1.02041 TRUST per share
Value of Shares Being Redeemed: 5.1 TRUST

Step 5: Previewing redemption...
Shares to Burn: 5.0
Assets to Receive (after fees): 4.95 TRUST

Fee Breakdown:
  Assets Before Fees: 5.1 TRUST
  Total Fees: 0.15 TRUST (2.94%)
  Exit Fee: 0.051 TRUST
  Protocol Fee: 0.099 TRUST

Step 6: Calculating slippage protection...
Slippage Tolerance: 1%
Minimum Assets (with slippage): 4.9005 TRUST

Step 7: Checking current native TRUST balance...
Current TRUST Balance: 40.0 TRUST
Expected After Redemption: 44.95 TRUST

Step 8: Executing redemption...
Redeeming 5.0 shares
Receiver: 0x1234567890123456789012345678901234567890
Min assets: 4.9005 TRUST

Estimated gas: 150000
Transaction submitted: 0xdef789...
Waiting for confirmation...
✓ Transaction confirmed in block 12365
Gas used: 138456

Step 9: Parsing transaction events...
Redeemed Event:
  Sender: 0x1234567890123456789012345678901234567890
  Receiver: 0x1234567890123456789012345678901234567890
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
  Curve ID: 1
  Shares Burned: 5.0
  Remaining User Shares: 9.7
  Assets Received: 4.95 TRUST
  Fees Paid: 0.15 TRUST

✓ Slippage protection satisfied

Step 10: Fetching updated position...
Your Updated Position:
  Remaining Shares: 9.7
  Remaining Value: 9.9 TRUST

TRUST Balance:
  Before: 40.0 TRUST
  After: 44.95 TRUST
  Received: 4.95 TRUST

================================================================================
✓ Redemption successful!
View on explorer: https://explorer.intuit.network/tx/0xdef789...
================================================================================
*/
