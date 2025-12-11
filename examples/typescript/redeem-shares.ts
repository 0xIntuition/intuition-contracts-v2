/**
 * @title Redeem Shares Example
 * @notice Demonstrates how to redeem vault shares for underlying assets
 * @dev This example uses ethers.js v6 to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Checks user's share balance in a vault
 * 2. Previews redemption to estimate assets received
 * 3. Redeems shares with slippage protection
 * 4. Shows how fees are deducted from redemption
 *
 * Prerequisites:
 * - Node.js v18+
 * - ethers.js v6 installed
 * - Shares in an atom or triple vault
 */

import { ethers } from 'ethers';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0;

const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

// Redemption configuration
const TERM_ID = '0x0000000000000000000000000000000000000000000000000000000000000001';
const CURVE_ID = 1;
const SHARES_TO_REDEEM = ethers.parseEther('5'); // 5 shares
const SLIPPAGE_TOLERANCE = 1; // 1% slippage tolerance

// Set to true to redeem ALL shares
const REDEEM_ALL = false;

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  'function redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets) external returns (uint256)',
  'function previewRedeem(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256 assetsAfterFees, uint256 sharesUsed)',
  'function getShares(address account, bytes32 termId, uint256 curveId) external view returns (uint256)',
  'function maxRedeem(address sender, bytes32 termId, uint256 curveId) external view returns (uint256)',
  'function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256)',
  'function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256)',
  'function exitFeeAmount(uint256 assets) external view returns (uint256)',
  'function protocolFeeAmount(uint256 assets) external view returns (uint256)',
  'event Redeemed(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 shares, uint256 totalShares, uint256 assets, uint256 fees, uint8 vaultType)',
];

const ERC20_ABI = [
  'function balanceOf(address account) external view returns (uint256)',
];

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

    const multiVault = new ethers.Contract(
      MULTIVAULT_ADDRESS,
      MULTIVAULT_ABI,
      signer
    );

    const wTrust = new ethers.Contract(
      WTRUST_ADDRESS,
      ERC20_ABI,
      signer
    );

    console.log(`✓ MultiVault: ${MULTIVAULT_ADDRESS}`);
    console.log(`✓ WTRUST: ${WTRUST_ADDRESS}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 3: Check Share Balance
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking your share balance...');
    console.log(`Term ID: ${TERM_ID}`);
    console.log(`Curve ID: ${CURVE_ID}`);

    const userShares = await multiVault.getShares(signer.address, TERM_ID, CURVE_ID);
    console.log(`Your Current Shares: ${ethers.formatEther(userShares)}`);

    if (userShares === 0n) {
      throw new Error('You have no shares in this vault to redeem');
    }

    // Get maximum redeemable shares
    const maxRedeemable = await multiVault.maxRedeem(signer.address, TERM_ID, CURVE_ID);
    console.log(`Maximum Redeemable Shares: ${ethers.formatEther(maxRedeemable)}`);

    // Determine actual shares to redeem
    let sharesToRedeem: bigint;
    if (REDEEM_ALL) {
      sharesToRedeem = maxRedeemable;
      console.log('✓ Redeeming ALL shares');
    } else {
      sharesToRedeem = SHARES_TO_REDEEM;
      if (sharesToRedeem &gt; maxRedeemable) {
        console.log(`⚠ Warning: Requested ${ethers.formatEther(sharesToRedeem)} shares but max is ${ethers.formatEther(maxRedeemable)}`);
        sharesToRedeem = maxRedeemable;
        console.log(`Adjusting to redeem: ${ethers.formatEther(sharesToRedeem)} shares`);
      } else {
        console.log(`Shares to redeem: ${ethers.formatEther(sharesToRedeem)}`);
      }
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Get Current Position Value
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating current position value...');

    const currentValue = await multiVault.convertToAssets(
      TERM_ID,
      CURVE_ID,
      userShares
    );
    console.log(`Total Position Value: ${ethers.formatEther(currentValue)} WTRUST`);

    const sharePrice = await multiVault.currentSharePrice(TERM_ID, CURVE_ID);
    console.log(`Current Share Price: ${ethers.formatEther(sharePrice)} WTRUST per share`);

    // Calculate value of shares being redeemed
    const redeemValue = await multiVault.convertToAssets(
      TERM_ID,
      CURVE_ID,
      sharesToRedeem
    );
    console.log(`Value of Shares Being Redeemed: ${ethers.formatEther(redeemValue)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Preview Redemption
    // ------------------------------------------------------------------------
    console.log('Step 5: Previewing redemption...');

    const [assetsAfterFees, sharesUsed] = await multiVault.previewRedeem(
      TERM_ID,
      CURVE_ID,
      sharesToRedeem
    );

    console.log(`Shares to Burn: ${ethers.formatEther(sharesUsed)}`);
    console.log(`Assets to Receive (after fees): ${ethers.formatEther(assetsAfterFees)} WTRUST`);

    // Estimate fees
    const assetsBeforeFees = await multiVault.convertToAssets(
      TERM_ID,
      CURVE_ID,
      sharesUsed
    );

    const totalFees = assetsBeforeFees - assetsAfterFees;
    const feePercentage = (Number(totalFees) / Number(assetsBeforeFees)) * 100;

    console.log(`\nFee Breakdown:`);
    console.log(`  Assets Before Fees: ${ethers.formatEther(assetsBeforeFees)} WTRUST`);
    console.log(`  Total Fees: ${ethers.formatEther(totalFees)} WTRUST (${feePercentage.toFixed(2)}%)`);

    // Try to break down fees (may not work for all vaults)
    try {
      const exitFee = await multiVault.exitFeeAmount(assetsBeforeFees);
      const protocolFee = await multiVault.protocolFeeAmount(assetsBeforeFees);
      console.log(`  Exit Fee: ${ethers.formatEther(exitFee)} WTRUST`);
      console.log(`  Protocol Fee: ${ethers.formatEther(protocolFee)} WTRUST`);
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
    console.log(`Minimum Assets (with slippage): ${ethers.formatEther(minAssets)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Check Current WTRUST Balance
    // ------------------------------------------------------------------------
    console.log('Step 7: Checking current WTRUST balance...');

    const currentWTrustBalance = await wTrust.balanceOf(signer.address);
    console.log(`Current WTRUST Balance: ${ethers.formatEther(currentWTrustBalance)} WTRUST`);
    console.log(`Expected After Redemption: ${ethers.formatEther(currentWTrustBalance + assetsAfterFees)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Execute Redemption
    // ------------------------------------------------------------------------
    console.log('Step 8: Executing redemption...');
    console.log(`Redeeming ${ethers.formatEther(sharesToRedeem)} shares`);
    console.log(`Receiver: ${signer.address}`);
    console.log(`Min assets: ${ethers.formatEther(minAssets)} WTRUST`);
    console.log();

    // Estimate gas
    const gasEstimate = await multiVault.redeem.estimateGas(
      signer.address, // receiver
      TERM_ID,
      CURVE_ID,
      sharesToRedeem,
      minAssets
    );
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute redemption
    const redeemTx = await multiVault.redeem(
      signer.address,
      TERM_ID,
      CURVE_ID,
      sharesToRedeem,
      minAssets,
      {
        gasLimit: gasEstimate * 120n / 100n, // Add 20% buffer
      }
    );

    console.log(`Transaction submitted: ${redeemTx.hash}`);
    console.log('Waiting for confirmation...');

    const receipt = await redeemTx.wait();
    console.log(`✓ Transaction confirmed in block ${receipt?.blockNumber}`);
    console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 9: Parsing transaction events...');

    if (receipt) {
      const redeemedEvent = receipt.logs
        .map(log =&gt; {
          try {
            return multiVault.interface.parseLog({
              topics: log.topics as string[],
              data: log.data,
            });
          } catch {
            return null;
          }
        })
        .find(event =&gt; event?.name === 'Redeemed');

      if (redeemedEvent) {
        console.log('Redeemed Event:');
        console.log(`  Sender: ${redeemedEvent.args[0]}`);
        console.log(`  Receiver: ${redeemedEvent.args[1]}`);
        console.log(`  Term ID: ${redeemedEvent.args[2]}`);
        console.log(`  Curve ID: ${redeemedEvent.args[3]}`);
        console.log(`  Shares Burned: ${ethers.formatEther(redeemedEvent.args[4])}`);
        console.log(`  Remaining User Shares: ${ethers.formatEther(redeemedEvent.args[5])}`);
        console.log(`  Assets Received: ${ethers.formatEther(redeemedEvent.args[6])} WTRUST`);
        console.log(`  Fees Paid: ${ethers.formatEther(redeemedEvent.args[7])} WTRUST`);
        console.log();

        // Verify we got at least the minimum assets
        const actualAssets = redeemedEvent.args[6];
        if (actualAssets &gt;= minAssets) {
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

    const newUserShares = await multiVault.getShares(signer.address, TERM_ID, CURVE_ID);
    const newWTrustBalance = await wTrust.balanceOf(signer.address);

    console.log('Your Updated Position:');
    console.log(`  Remaining Shares: ${ethers.formatEther(newUserShares)}`);

    if (newUserShares &gt; 0n) {
      const newValue = await multiVault.convertToAssets(
        TERM_ID,
        CURVE_ID,
        newUserShares
      );
      console.log(`  Remaining Value: ${ethers.formatEther(newValue)} WTRUST`);
    } else {
      console.log(`  Remaining Value: 0 WTRUST (position fully exited)`);
    }

    console.log(`\nWTRUST Balance:`);
    console.log(`  Before: ${ethers.formatEther(currentWTrustBalance)} WTRUST`);
    console.log(`  After: ${ethers.formatEther(newWTrustBalance)} WTRUST`);
    console.log(`  Received: ${ethers.formatEther(newWTrustBalance - currentWTrustBalance)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Redemption successful!');
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt?.hash}`);
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
Redeeming Shares from Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

Step 3: Checking your share balance...
Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
Curve ID: 1
Your Current Shares: 14.7
Maximum Redeemable Shares: 14.7
Shares to redeem: 5.0

Step 4: Calculating current position value...
Total Position Value: 15.0 WTRUST
Current Share Price: 1.02041 WTRUST per share
Value of Shares Being Redeemed: 5.1 WTRUST

Step 5: Previewing redemption...
Shares to Burn: 5.0
Assets to Receive (after fees): 4.95 WTRUST

Fee Breakdown:
  Assets Before Fees: 5.1 WTRUST
  Total Fees: 0.15 WTRUST (2.94%)
  Exit Fee: 0.051 WTRUST
  Protocol Fee: 0.099 WTRUST

Step 6: Calculating slippage protection...
Slippage Tolerance: 1%
Minimum Assets (with slippage): 4.9005 WTRUST

Step 7: Checking current WTRUST balance...
Current WTRUST Balance: 40.0 WTRUST
Expected After Redemption: 44.95 WTRUST

Step 8: Executing redemption...
Redeeming 5.0 shares
Receiver: 0x1234567890123456789012345678901234567890
Min assets: 4.9005 WTRUST

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
  Assets Received: 4.95 WTRUST
  Fees Paid: 0.15 WTRUST

✓ Slippage protection satisfied

Step 10: Fetching updated position...
Your Updated Position:
  Remaining Shares: 9.7
  Remaining Value: 9.9 WTRUST

WTRUST Balance:
  Before: 40.0 WTRUST
  After: 44.95 WTRUST
  Received: 4.95 WTRUST

================================================================================
✓ Redemption successful!
View on explorer: https://explorer.intuit.network/tx/0xdef789...
================================================================================
*/
