/**
 * @title Deposit into Vault Example
 * @notice Demonstrates how to deposit assets into an existing atom or triple vault
 * @dev This example uses ethers.js v6 to interact with the MultiVault contract
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
 * - ethers.js v6 installed: `npm install ethers@6`
 * - An existing atom or triple vault
 * - WTRUST tokens for deposit
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

// Deposit configuration
const TERM_ID = '0x0000000000000000000000000000000000000000000000000000000000000001'; // Atom or Triple ID
const CURVE_ID = 1; // Default curve ID (1 = LinearCurve)
const DEPOSIT_AMOUNT = ethers.parseEther('5'); // 5 WTRUST tokens
const SLIPPAGE_TOLERANCE = 1; // 1% slippage tolerance

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  'function deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares) external payable returns (uint256)',
  'function previewDeposit(bytes32 termId, uint256 curveId, uint256 assets) external view returns (uint256 shares, uint256 assetsAfterFees)',
  'function isTermCreated(bytes32 id) external view returns (bool)',
  'function getVault(bytes32 termId, uint256 curveId) external view returns (uint256 totalAssets, uint256 totalShares)',
  'function getShares(address account, bytes32 termId, uint256 curveId) external view returns (uint256)',
  'function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256)',
  'function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256)',
  'event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)',
];

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
];

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
    // Step 3: Verify Vault Exists
    // ------------------------------------------------------------------------
    console.log('Step 3: Verifying vault exists...');
    console.log(`Term ID: ${TERM_ID}`);
    console.log(`Curve ID: ${CURVE_ID}`);

    const termExists = await multiVault.isTermCreated(TERM_ID);
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

    const [totalAssets, totalShares] = await multiVault.getVault(TERM_ID, CURVE_ID);
    console.log(`Total Assets in Vault: ${ethers.formatEther(totalAssets)} WTRUST`);
    console.log(`Total Shares in Vault: ${ethers.formatEther(totalShares)}`);

    // Get current share price
    const sharePrice = await multiVault.currentSharePrice(TERM_ID, CURVE_ID);
    console.log(`Current Share Price: ${ethers.formatEther(sharePrice)} WTRUST per share`);

    // Get user's current shares
    const currentUserShares = await multiVault.getShares(signer.address, TERM_ID, CURVE_ID);
    console.log(`Your Current Shares: ${ethers.formatEther(currentUserShares)}`);

    if (currentUserShares &gt; 0n) {
      const currentUserAssetValue = await multiVault.convertToAssets(
        TERM_ID,
        CURVE_ID,
        currentUserShares
      );
      console.log(`Your Current Position Value: ${ethers.formatEther(currentUserAssetValue)} WTRUST`);
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Check Balance
    // ------------------------------------------------------------------------
    console.log('Step 5: Checking WTRUST balance...');

    const wtrustBalance = await wTrust.balanceOf(signer.address);
    console.log(`WTRUST Balance: ${ethers.formatEther(wtrustBalance)} WTRUST`);
    console.log(`Deposit Amount: ${ethers.formatEther(DEPOSIT_AMOUNT)} WTRUST`);

    if (wtrustBalance &lt; DEPOSIT_AMOUNT) {
      throw new Error(
        `Insufficient WTRUST balance. Need ${ethers.formatEther(DEPOSIT_AMOUNT)} but have ${ethers.formatEther(wtrustBalance)}`
      );
    }
    console.log('✓ Sufficient balance confirmed');
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Preview Deposit
    // ------------------------------------------------------------------------
    console.log('Step 6: Previewing deposit...');

    const [expectedShares, assetsAfterFees] = await multiVault.previewDeposit(
      TERM_ID,
      CURVE_ID,
      DEPOSIT_AMOUNT
    );

    console.log(`Expected Shares to Receive: ${ethers.formatEther(expectedShares)}`);
    console.log(`Assets After Fees: ${ethers.formatEther(assetsAfterFees)} WTRUST`);

    const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
    const feePercentage = (Number(totalFees) / Number(DEPOSIT_AMOUNT)) * 100;
    console.log(`Total Fees: ${ethers.formatEther(totalFees)} WTRUST (${feePercentage.toFixed(2)}%)`);

    // Calculate effective price per share
    const effectivePrice = DEPOSIT_AMOUNT * ethers.WeiPerEther / expectedShares;
    console.log(`Effective Price per Share: ${ethers.formatEther(effectivePrice)} WTRUST`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Calculate Slippage Protection
    // ------------------------------------------------------------------------
    console.log('Step 7: Calculating slippage protection...');

    // Calculate minimum shares with slippage tolerance
    const minShares = expectedShares * BigInt(100 - SLIPPAGE_TOLERANCE) / 100n;
    console.log(`Slippage Tolerance: ${SLIPPAGE_TOLERANCE}%`);
    console.log(`Minimum Shares (with slippage): ${ethers.formatEther(minShares)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Approve WTRUST
    // ------------------------------------------------------------------------
    console.log('Step 8: Approving WTRUST spending...');

    const currentAllowance = await wTrust.allowance(signer.address, MULTIVAULT_ADDRESS);
    console.log(`Current allowance: ${ethers.formatEther(currentAllowance)} WTRUST`);

    if (currentAllowance &lt; DEPOSIT_AMOUNT) {
      console.log('Approving WTRUST tokens...');

      const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, DEPOSIT_AMOUNT);
      console.log(`Approval tx submitted: ${approveTx.hash}`);

      const approveReceipt = await approveTx.wait();
      console.log(`✓ Approval confirmed in block ${approveReceipt?.blockNumber}`);
    } else {
      console.log('✓ Sufficient allowance already exists');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Execute Deposit
    // ------------------------------------------------------------------------
    console.log('Step 9: Executing deposit...');
    console.log(`Depositing ${ethers.formatEther(DEPOSIT_AMOUNT)} WTRUST`);
    console.log(`Receiver: ${signer.address}`);
    console.log(`Min shares: ${ethers.formatEther(minShares)}`);
    console.log();

    // Estimate gas
    const gasEstimate = await multiVault.deposit.estimateGas(
      signer.address, // receiver
      TERM_ID,
      CURVE_ID,
      minShares,
      { value: 0 } // No ETH value for WTRUST deposits
    );
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Execute deposit
    const depositTx = await multiVault.deposit(
      signer.address, // receiver
      TERM_ID,
      CURVE_ID,
      minShares,
      {
        gasLimit: gasEstimate * 120n / 100n, // Add 20% buffer
      }
    );

    console.log(`Transaction submitted: ${depositTx.hash}`);
    console.log('Waiting for confirmation...');

    const receipt = await depositTx.wait();
    console.log(`✓ Transaction confirmed in block ${receipt?.blockNumber}`);
    console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Parse Events and Display Results
    // ------------------------------------------------------------------------
    console.log('Step 10: Parsing transaction events...');

    if (receipt) {
      const depositedEvent = receipt.logs
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
        .find(event =&gt; event?.name === 'Deposited');

      if (depositedEvent) {
        console.log('Deposited Event:');
        console.log(`  Sender: ${depositedEvent.args[0]}`);
        console.log(`  Receiver: ${depositedEvent.args[1]}`);
        console.log(`  Term ID: ${depositedEvent.args[2]}`);
        console.log(`  Curve ID: ${depositedEvent.args[3]}`);
        console.log(`  Assets Deposited: ${ethers.formatEther(depositedEvent.args[4])} WTRUST`);
        console.log(`  Assets After Fees: ${ethers.formatEther(depositedEvent.args[5])} WTRUST`);
        console.log(`  Shares Minted: ${ethers.formatEther(depositedEvent.args[6])}`);
        console.log(`  Total User Shares: ${ethers.formatEther(depositedEvent.args[7])}`);
        console.log();

        // Verify we got at least the minimum shares
        const actualShares = depositedEvent.args[6];
        if (actualShares &gt;= minShares) {
          console.log('✓ Slippage protection satisfied');
        } else {
          console.log('⚠ Warning: Received fewer shares than minimum (should not happen)');
        }
      }
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 11: Display Updated Position
    // ------------------------------------------------------------------------
    console.log('Step 11: Fetching updated position...');

    const newUserShares = await multiVault.getShares(signer.address, TERM_ID, CURVE_ID);
    const newUserAssetValue = await multiVault.convertToAssets(
      TERM_ID,
      CURVE_ID,
      newUserShares
    );

    console.log('Your Updated Position:');
    console.log(`  Total Shares: ${ethers.formatEther(newUserShares)}`);
    console.log(`  Current Value: ${ethers.formatEther(newUserAssetValue)} WTRUST`);

    const sharesAdded = newUserShares - currentUserShares;
    console.log(`  Shares Added: ${ethers.formatEther(sharesAdded)}`);
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Deposit successful!');
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt?.hash}`);
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
Depositing into Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

Step 3: Verifying vault exists...
Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
Curve ID: 1
✓ Term exists

Step 4: Fetching current vault state...
Total Assets in Vault: 100.5 WTRUST
Total Shares in Vault: 98.49
Current Share Price: 1.02035 WTRUST per share
Your Current Shares: 9.8
Your Current Position Value: 10.0 WTRUST

Step 5: Checking WTRUST balance...
WTRUST Balance: 50.0 WTRUST
Deposit Amount: 5.0 WTRUST
✓ Sufficient balance confirmed

Step 6: Previewing deposit...
Expected Shares to Receive: 4.9
Assets After Fees: 4.9 WTRUST
Total Fees: 0.1 WTRUST (2.00%)
Effective Price per Share: 1.02041 WTRUST

Step 7: Calculating slippage protection...
Slippage Tolerance: 1%
Minimum Shares (with slippage): 4.851

Step 8: Approving WTRUST spending...
Current allowance: 100.0 WTRUST
✓ Sufficient allowance already exists

Step 9: Executing deposit...
Depositing 5.0 WTRUST
Receiver: 0x1234567890123456789012345678901234567890
Min shares: 4.851

Estimated gas: 180000
Transaction submitted: 0xabc123...
Waiting for confirmation...
✓ Transaction confirmed in block 12360
Gas used: 165234

Step 10: Parsing transaction events...
Deposited Event:
  Sender: 0x1234567890123456789012345678901234567890
  Receiver: 0x1234567890123456789012345678901234567890
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
  Curve ID: 1
  Assets Deposited: 5.0 WTRUST
  Assets After Fees: 4.9 WTRUST
  Shares Minted: 4.9
  Total User Shares: 14.7

✓ Slippage protection satisfied

Step 11: Fetching updated position...
Your Updated Position:
  Total Shares: 14.7
  Current Value: 15.0 WTRUST
  Shares Added: 4.9

================================================================================
✓ Deposit successful!
View on explorer: https://explorer.intuit.network/tx/0xabc123...
================================================================================
*/
