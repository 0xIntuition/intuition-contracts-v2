/**
 * @title Create Triple Example
 * @notice Demonstrates how to create a triple vault (Subject-Predicate-Object) with an initial deposit
 * @dev This example uses ethers.js v6 to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Connects to the Intuition network
 * 2. Validates that all three atoms (subject, predicate, object) exist
 * 3. Creates a new triple vault linking the three atoms
 * 4. Shows how a portion of the deposit goes to underlying atoms
 * 5. Monitors the creation event
 *
 * Prerequisites:
 * - Node.js v18+
 * - ethers.js v6 installed: `npm install ethers@6`
 * - Three existing atoms (or use the create-atom.ts example first)
 * - Private key with ETH for gas and WTRUST tokens for deposit
 */

import { ethers } from 'ethers';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0; // Replace with actual Intuition chain ID

// Contract addresses (Intuition Mainnet)
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';

const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

// Triple configuration
// Replace these with actual atom IDs from your created atoms
const SUBJECT_ID = '0x0000000000000000000000000000000000000000000000000000000000000001';
const PREDICATE_ID = '0x0000000000000000000000000000000000000000000000000000000000000002';
const OBJECT_ID = '0x0000000000000000000000000000000000000000000000000000000000000003';

const DEPOSIT_AMOUNT = ethers.parseEther('20'); // 20 WTRUST tokens

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  'function createTriples(bytes32[] calldata subjectIds, bytes32[] calldata predicateIds, bytes32[] calldata objectIds, uint256[] calldata assets) external payable returns (bytes32[] memory)',
  'function calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId) external pure returns (bytes32)',
  'function isTermCreated(bytes32 id) external view returns (bool)',
  'function getTripleCost() external view returns (uint256)',
  'function atomDepositFractionAmount(uint256 assets) external view returns (uint256)',
  'function previewTripleCreate(bytes32 termId, uint256 assets) external view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)',
  'function getTriple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32)',
  'event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)',
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
    console.log('Creating Triple Vault on Intuition Protocol');
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
    // Step 3: Validate Atoms Exist
    // ------------------------------------------------------------------------
    console.log('Step 3: Validating that all atoms exist...');
    console.log(`Subject ID: ${SUBJECT_ID}`);
    console.log(`Predicate ID: ${PREDICATE_ID}`);
    console.log(`Object ID: ${OBJECT_ID}`);
    console.log();

    // Check if subject exists
    const subjectExists = await multiVault.isTermCreated(SUBJECT_ID);
    if (!subjectExists) {
      throw new Error(`Subject atom ${SUBJECT_ID} does not exist. Create it first.`);
    }
    console.log('✓ Subject atom exists');

    // Check if predicate exists
    const predicateExists = await multiVault.isTermCreated(PREDICATE_ID);
    if (!predicateExists) {
      throw new Error(`Predicate atom ${PREDICATE_ID} does not exist. Create it first.`);
    }
    console.log('✓ Predicate atom exists');

    // Check if object exists
    const objectExists = await multiVault.isTermCreated(OBJECT_ID);
    if (!objectExists) {
      throw new Error(`Object atom ${OBJECT_ID} does not exist. Create it first.`);
    }
    console.log('✓ Object atom exists');
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Calculate Triple ID and Check Existence
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating triple ID...');

    const tripleId = await multiVault.calculateTripleId(
      SUBJECT_ID,
      PREDICATE_ID,
      OBJECT_ID
    );
    console.log(`Triple ID: ${tripleId}`);

    // Check if this triple already exists
    const tripleExists = await multiVault.isTermCreated(tripleId);
    if (tripleExists) {
      console.log('⚠ Warning: This triple already exists!');
      console.log('You can deposit into the existing vault, but creation will fail.');
      return;
    }
    console.log('✓ Triple does not exist yet, safe to create');
    console.log();

    // ------------------------------------------------------------------------
    // Step 5: Check Costs and Balance
    // ------------------------------------------------------------------------
    console.log('Step 5: Checking costs and balance...');

    const wtrustBalance = await wTrust.balanceOf(signer.address);
    console.log(`WTRUST Balance: ${ethers.formatEther(wtrustBalance)} WTRUST`);

    // Get triple creation cost
    const tripleCost = await multiVault.getTripleCost();
    console.log(`Triple Creation Cost: ${ethers.formatEther(tripleCost)} WTRUST`);

    // Get atom deposit fraction (portion that goes to underlying atoms)
    const atomDepositFraction = await multiVault.atomDepositFractionAmount(DEPOSIT_AMOUNT);
    console.log(`Atom Deposit Fraction: ${ethers.formatEther(atomDepositFraction)} WTRUST`);
    console.log(`  (This will be split among the 3 underlying atoms)`);

    const totalRequired = DEPOSIT_AMOUNT + tripleCost;
    console.log(`Total Required: ${ethers.formatEther(totalRequired)} WTRUST`);

    if (wtrustBalance &lt; totalRequired) {
      throw new Error(
        `Insufficient WTRUST balance. Need ${ethers.formatEther(totalRequired)} but have ${ethers.formatEther(wtrustBalance)}`
      );
    }
    console.log('✓ Sufficient balance confirmed');
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Preview Triple Creation
    // ------------------------------------------------------------------------
    console.log('Step 6: Previewing triple creation...');

    try {
      const [shares, assetsAfterFixedFees, assetsAfterFees] =
        await multiVault.previewTripleCreate(tripleId, DEPOSIT_AMOUNT);

      console.log(`Expected shares to receive: ${ethers.formatEther(shares)}`);
      console.log(`Assets after fixed fees: ${ethers.formatEther(assetsAfterFixedFees)} WTRUST`);
      console.log(`Assets after all fees: ${ethers.formatEther(assetsAfterFees)} WTRUST`);

      const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
      console.log(`Total fees: ${ethers.formatEther(totalFees)} WTRUST`);

      // Note: The atomDepositFraction is taken from the deposit amount
      // before it enters the triple vault
      const tripleVaultDeposit = DEPOSIT_AMOUNT - atomDepositFraction;
      console.log();
      console.log('Deposit breakdown:');
      console.log(`  To underlying atoms: ${ethers.formatEther(atomDepositFraction)} WTRUST`);
      console.log(`  To triple vault: ${ethers.formatEther(tripleVaultDeposit)} WTRUST`);
    } catch (error) {
      console.log('⚠ Preview unavailable (normal for new triples)');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Approve WTRUST
    // ------------------------------------------------------------------------
    console.log('Step 7: Approving WTRUST spending...');

    const currentAllowance = await wTrust.allowance(signer.address, MULTIVAULT_ADDRESS);
    console.log(`Current allowance: ${ethers.formatEther(currentAllowance)} WTRUST`);

    if (currentAllowance &lt; totalRequired) {
      console.log('Approving WTRUST tokens...');

      const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, totalRequired);
      console.log(`Approval tx submitted: ${approveTx.hash}`);

      const approveReceipt = await approveTx.wait();
      console.log(`✓ Approval confirmed in block ${approveReceipt?.blockNumber}`);
    } else {
      console.log('✓ Sufficient allowance already exists');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Create Triple
    // ------------------------------------------------------------------------
    console.log('Step 8: Creating triple vault...');
    console.log('Triple structure:');
    console.log(`  Subject: ${SUBJECT_ID}`);
    console.log(`  Predicate: ${PREDICATE_ID}`);
    console.log(`  Object: ${OBJECT_ID}`);
    console.log(`Initial deposit: ${ethers.formatEther(DEPOSIT_AMOUNT)} WTRUST`);
    console.log();

    // Prepare arrays for batch creation (even though creating just one)
    const subjectIds = [SUBJECT_ID];
    const predicateIds = [PREDICATE_ID];
    const objectIds = [OBJECT_ID];
    const assets = [DEPOSIT_AMOUNT];

    // Estimate gas
    const gasEstimate = await multiVault.createTriples.estimateGas(
      subjectIds,
      predicateIds,
      objectIds,
      assets
    );
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the triple
    const createTx = await multiVault.createTriples(
      subjectIds,
      predicateIds,
      objectIds,
      assets,
      {
        gasLimit: gasEstimate * 120n / 100n, // Add 20% buffer
      }
    );

    console.log(`Transaction submitted: ${createTx.hash}`);
    console.log('Waiting for confirmation...');

    const receipt = await createTx.wait();
    console.log(`✓ Transaction confirmed in block ${receipt?.blockNumber}`);
    console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 9: Parsing transaction events...');

    if (receipt) {
      // Find TripleCreated event
      const tripleCreatedEvent = receipt.logs
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
        .find(event =&gt; event?.name === 'TripleCreated');

      if (tripleCreatedEvent) {
        console.log('TripleCreated Event:');
        console.log(`  Creator: ${tripleCreatedEvent.args[0]}`);
        console.log(`  Triple ID: ${tripleCreatedEvent.args[1]}`);
        console.log(`  Subject ID: ${tripleCreatedEvent.args[2]}`);
        console.log(`  Predicate ID: ${tripleCreatedEvent.args[3]}`);
        console.log(`  Object ID: ${tripleCreatedEvent.args[4]}`);
        console.log();
      }

      // Find all Deposited events (there will be multiple - one for triple + three for atoms)
      const depositedEvents = receipt.logs
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
        .filter(event =&gt; event?.name === 'Deposited');

      console.log(`Found ${depositedEvents.length} Deposited events:`);
      depositedEvents.forEach((event, index) =&gt; {
        if (event) {
          const vaultType = event.args[8];
          const vaultTypeName = vaultType === 0 ? 'ATOM' : vaultType === 1 ? 'TRIPLE' : 'COUNTER_TRIPLE';

          console.log(`\nDeposit ${index + 1} (${vaultTypeName}):`);
          console.log(`  Term ID: ${event.args[2]}`);
          console.log(`  Curve ID: ${event.args[3]}`);
          console.log(`  Assets: ${ethers.formatEther(event.args[4])} WTRUST`);
          console.log(`  Shares Minted: ${ethers.formatEther(event.args[6])}`);
        }
      });
      console.log();
    }

    // ------------------------------------------------------------------------
    // Step 10: Verify Triple Structure
    // ------------------------------------------------------------------------
    console.log('Step 10: Verifying triple structure...');

    const [subject, predicate, object] = await multiVault.getTriple(tripleId);
    console.log('Triple structure from contract:');
    console.log(`  Subject: ${subject}`);
    console.log(`  Predicate: ${predicate}`);
    console.log(`  Object: ${object}`);
    console.log();

    // Verify it matches what we created
    if (subject === SUBJECT_ID && predicate === PREDICATE_ID && object === OBJECT_ID) {
      console.log('✓ Triple structure verified!');
    } else {
      console.log('⚠ Warning: Triple structure mismatch');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Triple creation successful!');
    console.log(`Triple ID: ${tripleId}`);
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt?.hash}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ Error creating triple:');
    console.error('='.repeat(80));

    if (error instanceof Error) {
      console.error(`Message: ${error.message}`);

      // Parse common errors
      if (error.message.includes('AtomDoesNotExist')) {
        console.error('\nCause: One or more atoms do not exist');
        console.error('Solution: Create the required atoms first using create-atom.ts');
      } else if (error.message.includes('TripleExists')) {
        console.error('\nCause: This triple already exists');
        console.error('Solution: Use deposit-vault.ts to add to the existing triple');
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
Creating Triple Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

Step 3: Validating that all atoms exist...
Subject ID: 0x0000000000000000000000000000000000000000000000000000000000000001
Predicate ID: 0x0000000000000000000000000000000000000000000000000000000000000002
Object ID: 0x0000000000000000000000000000000000000000000000000000000000000003

✓ Subject atom exists
✓ Predicate atom exists
✓ Object atom exists

Step 4: Calculating triple ID...
Triple ID: 0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b
✓ Triple does not exist yet, safe to create

Step 5: Checking costs and balance...
WTRUST Balance: 100.0 WTRUST
Triple Creation Cost: 0.1 WTRUST
Atom Deposit Fraction: 2.0 WTRUST
  (This will be split among the 3 underlying atoms)
Total Required: 20.1 WTRUST
✓ Sufficient balance confirmed

Step 6: Previewing triple creation...
Expected shares to receive: 17.64
Assets after fixed fees: 17.9 WTRUST
Assets after all fees: 17.64 WTRUST
Total fees: 2.36 WTRUST

Deposit breakdown:
  To underlying atoms: 2.0 WTRUST
  To triple vault: 18.0 WTRUST

Step 7: Approving WTRUST spending...
Current allowance: 100.0 WTRUST
✓ Sufficient allowance already exists

Step 8: Creating triple vault...
Triple structure:
  Subject: 0x0000000000000000000000000000000000000000000000000000000000000001
  Predicate: 0x0000000000000000000000000000000000000000000000000000000000000002
  Object: 0x0000000000000000000000000000000000000000000000000000000000000003
Initial deposit: 20.0 WTRUST

Estimated gas: 450000
Transaction submitted: 0xabc123...
Waiting for confirmation...
✓ Transaction confirmed in block 12350
Gas used: 425678

Step 9: Parsing transaction events...
TripleCreated Event:
  Creator: 0x1234567890123456789012345678901234567890
  Triple ID: 0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b
  Subject ID: 0x0000000000000000000000000000000000000000000000000000000000000001
  Predicate ID: 0x0000000000000000000000000000000000000000000000000000000000000002
  Object ID: 0x0000000000000000000000000000000000000000000000000000000000000003

Found 4 Deposited events:

Deposit 1 (ATOM):
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000001
  Curve ID: 1
  Assets: 0.666666666666666666 WTRUST
  Shares Minted: 0.653333333333333333

Deposit 2 (ATOM):
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000002
  Curve ID: 1
  Assets: 0.666666666666666666 WTRUST
  Shares Minted: 0.653333333333333333

Deposit 3 (ATOM):
  Term ID: 0x0000000000000000000000000000000000000000000000000000000000000003
  Curve ID: 1
  Assets: 0.666666666666666668 WTRUST
  Shares Minted: 0.653333333333333334

Deposit 4 (TRIPLE):
  Term ID: 0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b
  Curve ID: 1
  Assets: 18.0 WTRUST
  Shares Minted: 17.64

Step 10: Verifying triple structure...
Triple structure from contract:
  Subject: 0x0000000000000000000000000000000000000000000000000000000000000001
  Predicate: 0x0000000000000000000000000000000000000000000000000000000000000002
  Object: 0x0000000000000000000000000000000000000000000000000000000000000003

✓ Triple structure verified!

================================================================================
✓ Triple creation successful!
Triple ID: 0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b
View on explorer: https://explorer.intuit.network/tx/0xabc123...
================================================================================
*/
