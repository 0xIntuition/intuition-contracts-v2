/**
 * @title Deposit into Vault Example
 * @notice Demonstrates how to deposit assets into an existing atom or triple vault
 * @dev This example uses viem to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Connects to the Intuition network
 * 2. Checks if the vault exists
 * 3. Previews the deposit to estimate shares received
 * 4. Deposits assets and receives vault shares
 * 5. Shows slippage protection with minShares parameter
 *
 * Prerequisites:
 * - Node.js v18+
 * - viem installed: `npm install viem`
 * - An existing atom or triple vault
 * - Native TRUST for deposit
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

// Deposit configuration
const TERM_ID = '0x0000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`; // Atom or Triple ID
const CURVE_ID = 1; // Default curve ID (1 = LinearCurve)
const DEPOSIT_AMOUNT = parseEther('5'); // 5 TRUST tokens
const SLIPPAGE_TOLERANCE = 1; // 1% slippage tolerance

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  {
    name: 'deposit',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'receiver', type: 'address' },
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' },
      { name: 'minShares', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'previewDeposit',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' },
      { name: 'assets', type: 'uint256' }
    ],
    outputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'assetsAfterFees', type: 'uint256' }
    ]
  },
  {
    name: 'isTermCreated',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'getVault',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'curveId', type: 'uint256' }
    ],
    outputs: [
      { name: 'totalAssets', type: 'uint256' },
      { name: 'totalShares', type: 'uint256' }
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
    name: 'Deposited',
    type: 'event',
    inputs: [
      { name: 'sender', type: 'address', indexed: true },
      { name: 'receiver', type: 'address', indexed: true },
      { name: 'termId', type: 'bytes32', indexed: true },
      { name: 'curveId', type: 'uint256', indexed: false },
      { name: 'assets', type: 'uint256', indexed: false },
      { name: 'assetsAfterFees', type: 'uint256', indexed: false },
      { name: 'shares', type: 'uint256', indexed: false },
      { name: 'totalShares', type: 'uint256', indexed: false },
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
    console.log('Depositing into Vault on Intuition Protocol');
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
    // Step 3: Verify Vault Exists
    // ------------------------------------------------------------------------
    console.log('Step 3: Verifying vault exists...');
    console.log(`Term ID: ${TERM_ID}`);
    console.log(`Curve ID: ${CURVE_ID}`);

    const termExists = await multiVault.read.isTermCreated([TERM_ID]);
    if (!termExists) {
      throw new Error(
        `Term ${TERM_ID} does not exist. Create it first using create-atom.ts or create-triple.ts`
      );
    }
    console.log('✓ Term exists');
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Get Vault State
    // ------------------------------------------------------------------------
    console.log('Step 4: Fetching current vault state...');

    const [totalAssets, totalShares] = await multiVault.read.getVault([TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Total Assets in Vault: ${formatEther(totalAssets)} TRUST`);
    console.log(`Total Shares in Vault: ${formatEther(totalShares)}`);

    // Get current share price
    const sharePrice = await multiVault.read.currentSharePrice([TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Current Share Price: ${formatEther(sharePrice)} TRUST per share`);

    // Get user's current shares
    const currentUserShares = await multiVault.read.getShares([account.address, TERM_ID, BigInt(CURVE_ID)]);
    console.log(`Your Current Shares: ${formatEther(currentUserShares)}`);

    if (currentUserShares > 0n) {
      const currentUserAssetValue = await multiVault.read.convertToAssets([
        TERM_ID,
        BigInt(CURVE_ID),
        currentUserShares
      ]);
      console.log(`Your Current Position Value: ${formatEther(currentUserAssetValue)} TRUST`);
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Preview Deposit
    // ------------------------------------------------------------------------
    console.log('Step 6: Previewing deposit...');

    const [expectedShares, assetsAfterFees] = await multiVault.read.previewDeposit([
      TERM_ID,
      BigInt(CURVE_ID),
      DEPOSIT_AMOUNT
    ]);

    console.log(`Expected Shares to Receive: ${formatEther(expectedShares)}`);
    console.log(`Assets After Fees: ${formatEther(assetsAfterFees)} TRUST`);

    const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
    const feePercentage = (Number(totalFees) / Number(DEPOSIT_AMOUNT)) * 100;
    console.log(`Total Fees: ${formatEther(totalFees)} TRUST (${feePercentage.toFixed(2)}%)`);

    // Calculate effective price per share
    const effectivePrice = DEPOSIT_AMOUNT * parseEther('1') / expectedShares;
    console.log(`Effective Price per Share: ${formatEther(effectivePrice)} TRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Calculate Slippage Protection
    // ------------------------------------------------------------------------
    console.log('Step 7: Calculating slippage protection...');

    // Calculate minimum shares with slippage tolerance
    const minShares = expectedShares * BigInt(100 - SLIPPAGE_TOLERANCE) / 100n;
    console.log(`Slippage Tolerance: ${SLIPPAGE_TOLERANCE}%`);
    console.log(`Minimum Shares (with slippage): ${formatEther(minShares)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Execute Deposit
    // ------------------------------------------------------------------------
    console.log('Step 8: Executing deposit...');
    console.log(`Depositing ${formatEther(DEPOSIT_AMOUNT)} TRUST`);
    console.log(`Receiver: ${account.address}`);
    console.log(`Min shares: ${formatEther(minShares)}`);
    console.log();

    // Estimate gas
    const gasEstimate = await multiVault.estimateGas.deposit(
      [account.address, TERM_ID, BigInt(CURVE_ID), minShares],
      { value: DEPOSIT_AMOUNT }
    );
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute deposit
    const depositTx = await multiVault.write.deposit(
      [account.address, TERM_ID, BigInt(CURVE_ID), minShares],
      {
        value: DEPOSIT_AMOUNT,
        gas: gasEstimate * 120n / 100n
      }
    );

    console.log(`Transaction submitted: ${depositTx}`);
    console.log('Waiting for confirmation...');

    const receipt = await publicClient.waitForTransactionReceipt({ hash: depositTx });
    console.log(`✓ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Parse Events and Display Results
    // ------------------------------------------------------------------------
    console.log('Step 9: Parsing transaction events...');

    const depositedLog = receipt.logs.find(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: MULTIVAULT_ABI,
          logs: [log],
          eventName: 'Deposited'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (depositedLog) {
      const depositedEvent = publicClient.parseEventLogs({
        abi: MULTIVAULT_ABI,
        logs: [depositedLog],
        eventName: 'Deposited'
      })[0];

      if (depositedEvent && depositedEvent.args) {
        console.log('Deposited Event:');
        console.log(`  Sender: ${depositedEvent.args.sender}`);
        console.log(`  Receiver: ${depositedEvent.args.receiver}`);
        console.log(`  Term ID: ${depositedEvent.args.termId}`);
        console.log(`  Curve ID: ${depositedEvent.args.curveId}`);
        console.log(`  Assets Deposited: ${formatEther(depositedEvent.args.assets)} TRUST`);
        console.log(`  Assets After Fees: ${formatEther(depositedEvent.args.assetsAfterFees)} TRUST`);
        console.log(`  Shares Minted: ${formatEther(depositedEvent.args.shares)}`);
        console.log(`  Total User Shares: ${formatEther(depositedEvent.args.totalShares)}`);
        console.log();

        // Verify we got at least the minimum shares
        const actualShares = depositedEvent.args.shares;
        if (actualShares >= minShares) {
          console.log('✓ Slippage protection satisfied');
        } else {
          console.log('⚠ Warning: Received fewer shares than minimum (should not happen)');
        }
      }
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Display Updated Position
    // ------------------------------------------------------------------------
    console.log('Step 10: Fetching updated position...');

    const newUserShares = await multiVault.read.getShares([account.address, TERM_ID, BigInt(CURVE_ID)]);
    const newUserAssetValue = await multiVault.read.convertToAssets([
      TERM_ID,
      BigInt(CURVE_ID),
      newUserShares
    ]);

    console.log('Your Updated Position:');
    console.log(`  Total Shares: ${formatEther(newUserShares)}`);
    console.log(`  Current Value: ${formatEther(newUserAssetValue)} TRUST`);

    const sharesAdded = newUserShares - currentUserShares;
    console.log(`  Shares Added: ${formatEther(sharesAdded)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Deposit successful!');
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt.transactionHash}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ Error depositing into vault:');
    console.error('='.repeat(80));

    if (error instanceof Error) {
      console.error(`Message: ${error.message}`);

      if (error.message.includes('TermDoesNotExist')) {
        console.error('\nCause: The specified term does not exist');
        console.error('Solution: Verify the term ID or create it first');
      } else if (error.message.includes('InsufficientShares')) {
        console.error('\nCause: Slippage exceeded tolerance (received fewer shares than minimum)');
        console.error('Solution: Increase slippage tolerance or try with a smaller amount');
      } else if (error.message.includes('MinDepositRequired')) {
        console.error('\nCause: Deposit amount is below minimum');
        console.error('Solution: Increase your deposit amount');
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
Depositing into Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e

Step 3: Verifying vault exists...
Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
Curve ID: 1
✓ Term exists

Step 4: Fetching current vault state...
Total Assets in Vault: 100.5 TRUST
Total Shares in Vault: 98.49
Current Share Price: 1.02035 TRUST per share
Your Current Shares: 9.8
Your Current Position Value: 10.0 TRUST

Step 5: Previewing deposit...
Expected Shares to Receive: 4.9
Assets After Fees: 4.9 TRUST
Total Fees: 0.1 TRUST (2.00%)
Effective Price per Share: 1.02041 TRUST

Step 6: Calculating slippage protection...
Slippage Tolerance: 1%
Minimum Shares (with slippage): 4.851

Step 7: Executing deposit...
Depositing 5.0 TRUST
Receiver: 0x1234567890123456789012345678901234567890
Min shares: 4.851

Estimated gas: 180000
Transaction submitted: 0xabc123...
Waiting for confirmation...
✓ Transaction confirmed in block 12360
Gas used: 165234

Step 8: Parsing transaction events...
Deposited Event:
  Sender: 0x1234567890123456789012345678901234567890
  Receiver: 0x1234567890123456789012345678901234567890
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
  Curve ID: 1
  Assets Deposited: 5.0 TRUST
  Assets After Fees: 4.9 TRUST
  Shares Minted: 4.9
  Total User Shares: 14.7

✓ Slippage protection satisfied

Step 9: Fetching updated position...
Your Updated Position:
  Total Shares: 14.7
  Current Value: 15.0 TRUST
  Shares Added: 4.9

================================================================================
✓ Deposit successful!
View on explorer: https://explorer.intuit.network/tx/0xabc123...
================================================================================
*/
