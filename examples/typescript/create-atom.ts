/**
 * @title Create Atom Example
 * @notice Demonstrates how to create an atom vault with an initial deposit
 * @dev This example uses ethers.js v6 to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Connects to the Intuition network
 * 2. Approves WTRUST tokens for the MultiVault contract
 * 3. Creates a new atom vault with metadata
 * 4. Monitors the creation event
 *
 * Prerequisites:
 * - Node.js v18+
 * - ethers.js v6 installed: `npm install ethers@6`
 * - Private key with ETH for gas and WTRUST tokens for deposit
 * - Access to Intuition RPC endpoint
 */

import { ethers } from 'ethers';

// ============================================================================
// Configuration
// ============================================================================

// Network configuration
const RPC_URL = 'YOUR_INTUITION_RPC_URL'; // Replace with actual Intuition RPC
const CHAIN_ID = 0; // Replace with actual Intuition chain ID

// Contract addresses (Intuition Mainnet)
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

// Your wallet private key (NEVER commit this to git!)
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

// Atom configuration
const ATOM_DATA = ethers.toUtf8Bytes('My First Atom'); // Atom metadata
const DEPOSIT_AMOUNT = ethers.parseEther('10'); // 10 WTRUST tokens

// ============================================================================
// Contract ABIs (minimal required functions)
// ============================================================================

const MULTIVAULT_ABI = [
  // Create atoms function
  'function createAtoms(bytes[] calldata atomDatas, uint256[] calldata assets) external payable returns (bytes32[] memory)',

  // Preview atom creation to estimate shares
  'function previewAtomCreate(bytes32 termId, uint256 assets) external view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)',

  // Calculate atom ID from data
  'function calculateAtomId(bytes memory data) external pure returns (bytes32 id)',

  // Check if term exists
  'function isTermCreated(bytes32 id) external view returns (bool)',

  // Get atom cost (creation fees)
  'function getAtomCost() external view returns (uint256)',

  // Events
  'event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)',
  'event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)',
];

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
  'function decimals() external view returns (uint8)',
];

// ============================================================================
// Main Function
// ============================================================================

async function main() {
  try {
    console.log('='.repeat(80));
    console.log('Creating Atom Vault on Intuition Protocol');
    console.log('='.repeat(80));
    console.log();

    // ------------------------------------------------------------------------
    // Step 1: Setup Provider and Signer
    // ------------------------------------------------------------------------
    console.log('Step 1: Connecting to Intuition network...');

    const provider = new ethers.JsonRpcProvider(RPC_URL, {
      chainId: CHAIN_ID,
      name: 'intuition',
    });

    // Create signer from private key
    const signer = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log(`✓ Connected with address: ${signer.address}`);
    console.log();

    // Check ETH balance for gas
    const ethBalance = await provider.getBalance(signer.address);
    console.log(`ETH Balance: ${ethers.formatEther(ethBalance)} ETH`);

    // ------------------------------------------------------------------------
    // Step 2: Initialize Contract Instances
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
    // Step 3: Check WTRUST Balance and Get Atom Cost
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking WTRUST balance and atom creation cost...');

    const wtrustBalance = await wTrust.balanceOf(signer.address);
    console.log(`WTRUST Balance: ${ethers.formatEther(wtrustBalance)} WTRUST`);

    // Get atom creation cost (includes protocol fee + atom wallet deposit fee)
    const atomCost = await multiVault.getAtomCost();
    console.log(`Atom Creation Cost: ${ethers.formatEther(atomCost)} WTRUST`);

    // Total amount needed = deposit + atom cost
    const totalRequired = DEPOSIT_AMOUNT + atomCost;
    console.log(`Total Required: ${ethers.formatEther(totalRequired)} WTRUST`);

    // Verify sufficient balance
    if (wtrustBalance &lt; totalRequired) {
      throw new Error(
        `Insufficient WTRUST balance. Need ${ethers.formatEther(totalRequired)} but have ${ethers.formatEther(wtrustBalance)}`
      );
    }
    console.log('✓ Sufficient balance confirmed');
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Calculate Atom ID and Check Existence
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating atom ID and checking if it exists...');

    // Calculate what the atom ID will be
    const atomId = await multiVault.calculateAtomId(ATOM_DATA);
    console.log(`Atom ID: ${atomId}`);

    // Check if this atom already exists
    const atomExists = await multiVault.isTermCreated(atomId);
    if (atomExists) {
      console.log('⚠ Warning: This atom already exists!');
      console.log('You can still deposit into the existing vault, but creation will fail.');
      return;
    }
    console.log('✓ Atom does not exist yet, safe to create');
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Preview Atom Creation
    // ------------------------------------------------------------------------
    console.log('Step 5: Previewing atom creation...');

    try {
      const [shares, assetsAfterFixedFees, assetsAfterFees] =
        await multiVault.previewAtomCreate(atomId, DEPOSIT_AMOUNT);

      console.log(`Expected shares to receive: ${ethers.formatEther(shares)}`);
      console.log(`Assets after fixed fees: ${ethers.formatEther(assetsAfterFixedFees)} WTRUST`);
      console.log(`Assets after all fees: ${ethers.formatEther(assetsAfterFees)} WTRUST`);

      const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
      console.log(`Total fees: ${ethers.formatEther(totalFees)} WTRUST`);
    } catch (error) {
      console.log('⚠ Preview unavailable (normal for new atoms)');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Approve WTRUST Spending
    // ------------------------------------------------------------------------
    console.log('Step 6: Approving WTRUST spending...');

    // Check current allowance
    const currentAllowance = await wTrust.allowance(signer.address, MULTIVAULT_ADDRESS);
    console.log(`Current allowance: ${ethers.formatEther(currentAllowance)} WTRUST`);

    if (currentAllowance &lt; totalRequired) {
      console.log('Approving WTRUST tokens...');

      // Approve exact amount needed (or use ethers.MaxUint256 for unlimited)
      const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, totalRequired);
      console.log(`Approval tx submitted: ${approveTx.hash}`);

      // Wait for approval confirmation
      const approveReceipt = await approveTx.wait();
      console.log(`✓ Approval confirmed in block ${approveReceipt?.blockNumber}`);
    } else {
      console.log('✓ Sufficient allowance already exists');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Create Atom
    // ------------------------------------------------------------------------
    console.log('Step 7: Creating atom vault...');
    console.log(`Atom data: "${ethers.toUtf8String(ATOM_DATA)}"`);
    console.log(`Initial deposit: ${ethers.formatEther(DEPOSIT_AMOUNT)} WTRUST`);

    // Prepare arrays for batch creation (even though we're creating just one)
    const atomDatas = [ATOM_DATA];
    const assets = [DEPOSIT_AMOUNT];

    // Estimate gas before sending
    const gasEstimate = await multiVault.createAtoms.estimateGas(atomDatas, assets);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the atom
    const createTx = await multiVault.createAtoms(atomDatas, assets, {
      gasLimit: gasEstimate * 120n / 100n, // Add 20% buffer
    });

    console.log(`Transaction submitted: ${createTx.hash}`);
    console.log('Waiting for confirmation...');

    // Wait for transaction to be mined
    const receipt = await createTx.wait();
    console.log(`✓ Transaction confirmed in block ${receipt?.blockNumber}`);
    console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 8: Parsing transaction events...');

    if (receipt) {
      // Find AtomCreated event
      const atomCreatedEvent = receipt.logs
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
        .find(event =&gt; event?.name === 'AtomCreated');

      if (atomCreatedEvent) {
        console.log('AtomCreated Event:');
        console.log(`  Creator: ${atomCreatedEvent.args[0]}`);
        console.log(`  Atom ID: ${atomCreatedEvent.args[1]}`);
        console.log(`  Atom Data: "${ethers.toUtf8String(atomCreatedEvent.args[2])}"`);
        console.log(`  Atom Wallet: ${atomCreatedEvent.args[3]}`);
        console.log();
      }

      // Find Deposited event
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
        console.log(`  Assets: ${ethers.formatEther(depositedEvent.args[4])} WTRUST`);
        console.log(`  Assets After Fees: ${ethers.formatEther(depositedEvent.args[5])} WTRUST`);
        console.log(`  Shares Minted: ${ethers.formatEther(depositedEvent.args[6])}`);
        console.log(`  Total Shares: ${ethers.formatEther(depositedEvent.args[7])}`);
        console.log(`  Vault Type: ${depositedEvent.args[8]}`); // 0 = ATOM
        console.log();
      }
    }

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Atom creation successful!');
    console.log(`Atom ID: ${atomId}`);
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt?.hash}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ Error creating atom:');
    console.error('='.repeat(80));

    if (error instanceof Error) {
      console.error(`Message: ${error.message}`);

      // Parse common errors
      if (error.message.includes('insufficient funds')) {
        console.error('\nCause: Insufficient ETH for gas fees');
        console.error('Solution: Add more ETH to your wallet');
      } else if (error.message.includes('AtomDataMaxLengthExceeded')) {
        console.error('\nCause: Atom data is too long');
        console.error('Solution: Reduce the size of your atom data');
      } else if (error.message.includes('MinDepositRequired')) {
        console.error('\nCause: Deposit amount is below minimum');
        console.error('Solution: Increase your deposit amount');
      } else if (error.message.includes('user rejected')) {
        console.error('\nCause: Transaction was rejected');
        console.error('Solution: Approve the transaction in your wallet');
      }
    }

    console.error();
    process.exit(1);
  }
}

// ============================================================================
// Execute
// ============================================================================

// Run the main function
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
Creating Atom Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890
ETH Balance: 0.5 ETH

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

Step 3: Checking WTRUST balance and atom creation cost...
WTRUST Balance: 100.0 WTRUST
Atom Creation Cost: 0.1 WTRUST
Total Required: 10.1 WTRUST
✓ Sufficient balance confirmed

Step 4: Calculating atom ID and checking if it exists...
Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
✓ Atom does not exist yet, safe to create

Step 5: Previewing atom creation...
⚠ Preview unavailable (normal for new atoms)

Step 6: Approving WTRUST spending...
Current allowance: 0.0 WTRUST
Approving WTRUST tokens...
Approval tx submitted: 0xabc123...
✓ Approval confirmed in block 12345

Step 7: Creating atom vault...
Atom data: "My First Atom"
Initial deposit: 10.0 WTRUST
Estimated gas: 350000
Transaction submitted: 0xdef456...
Waiting for confirmation...
✓ Transaction confirmed in block 12346
Gas used: 325432

Step 8: Parsing transaction events...
AtomCreated Event:
  Creator: 0x1234567890123456789012345678901234567890
  Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
  Atom Data: "My First Atom"
  Atom Wallet: 0x9876543210987654321098765432109876543210

Deposited Event:
  Sender: 0x1234567890123456789012345678901234567890
  Receiver: 0x1234567890123456789012345678901234567890
  Term ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
  Curve ID: 1
  Assets: 10.0 WTRUST
  Assets After Fees: 9.8 WTRUST
  Shares Minted: 9.8
  Total Shares: 9.8
  Vault Type: 0

================================================================================
✓ Atom creation successful!
Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
View on explorer: https://explorer.intuit.network/tx/0xdef456...
================================================================================
*/
