/**
 * @title Create Triple Example
 * @notice Demonstrates how to create a triple vault (Subject-Predicate-Object) with an initial deposit
 * @dev This example uses viem to interact with the MultiVault contract
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
 * - viem installed: `npm install viem`
 * - Three existing atoms (or use the create-atom.ts example first)
 * - Private key with ETH for gas and WTRUST tokens for deposit
 */

import { createPublicClient, createWalletClient, http, parseEther, formatEther, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// ============================================================================
// Configuration
// ============================================================================

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const CHAIN_ID = 0; // Replace with actual Intuition chain ID

// Contract addresses (Intuition Mainnet)
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672' as `0x${string}`;

const PRIVATE_KEY = (process.env.PRIVATE_KEY || '') as `0x${string}`;

// Triple configuration
// Replace these with actual atom IDs from your created atoms
const SUBJECT_ID = '0x0000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`;
const PREDICATE_ID = '0x0000000000000000000000000000000000000000000000000000000000000002' as `0x${string}`;
const OBJECT_ID = '0x0000000000000000000000000000000000000000000000000000000000000003' as `0x${string}`;

const DEPOSIT_AMOUNT = parseEther('20'); // 20 WTRUST tokens

// ============================================================================
// Contract ABIs
// ============================================================================

const MULTIVAULT_ABI = [
  {
    name: 'createTriples',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'subjectIds', type: 'bytes32[]' },
      { name: 'predicateIds', type: 'bytes32[]' },
      { name: 'objectIds', type: 'bytes32[]' },
      { name: 'assets', type: 'uint256[]' }
    ],
    outputs: [{ name: '', type: 'bytes32[]' }]
  },
  {
    name: 'calculateTripleId',
    type: 'function',
    stateMutability: 'pure',
    inputs: [
      { name: 'subjectId', type: 'bytes32' },
      { name: 'predicateId', type: 'bytes32' },
      { name: 'objectId', type: 'bytes32' }
    ],
    outputs: [{ name: '', type: 'bytes32' }]
  },
  {
    name: 'isTermCreated',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'getTripleCost',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'atomDepositFractionAmount',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'previewTripleCreate',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'termId', type: 'bytes32' },
      { name: 'assets', type: 'uint256' }
    ],
    outputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'assetsAfterFixedFees', type: 'uint256' },
      { name: 'assetsAfterFees', type: 'uint256' }
    ]
  },
  {
    name: 'getTriple',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tripleId', type: 'bytes32' }],
    outputs: [
      { name: '', type: 'bytes32' },
      { name: '', type: 'bytes32' },
      { name: '', type: 'bytes32' }
    ]
  },
  {
    name: 'TripleCreated',
    type: 'event',
    inputs: [
      { name: 'creator', type: 'address', indexed: true },
      { name: 'termId', type: 'bytes32', indexed: true },
      { name: 'subjectId', type: 'bytes32', indexed: false },
      { name: 'predicateId', type: 'bytes32', indexed: false },
      { name: 'objectId', type: 'bytes32', indexed: false }
    ]
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

const ERC20_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  }
] as const;

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
    // Step 1: Setup Clients
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
    // Step 2: Initialize Contract Instances
    // ------------------------------------------------------------------------
    console.log('Step 2: Initializing contract instances...');

    const multiVault = getContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      client: { public: publicClient, wallet: walletClient }
    });

    const wTrust = getContract({
      address: WTRUST_ADDRESS,
      abi: ERC20_ABI,
      client: { public: publicClient, wallet: walletClient }
    });

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
    const subjectExists = await multiVault.read.isTermCreated([SUBJECT_ID]);
    if (!subjectExists) {
      throw new Error(`Subject atom ${SUBJECT_ID} does not exist. Create it first.`);
    }
    console.log('✓ Subject atom exists');

    // Check if predicate exists
    const predicateExists = await multiVault.read.isTermCreated([PREDICATE_ID]);
    if (!predicateExists) {
      throw new Error(`Predicate atom ${PREDICATE_ID} does not exist. Create it first.`);
    }
    console.log('✓ Predicate atom exists');

    // Check if object exists
    const objectExists = await multiVault.read.isTermCreated([OBJECT_ID]);
    if (!objectExists) {
      throw new Error(`Object atom ${OBJECT_ID} does not exist. Create it first.`);
    }
    console.log('✓ Object atom exists');
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Calculate Triple ID and Check Existence
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating triple ID...');

    const tripleId = await multiVault.read.calculateTripleId([
      SUBJECT_ID,
      PREDICATE_ID,
      OBJECT_ID
    ]);
    console.log(`Triple ID: ${tripleId}`);

    // Check if this triple already exists
    const tripleExists = await multiVault.read.isTermCreated([tripleId]);
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

    const wtrustBalance = await wTrust.read.balanceOf([account.address]);
    console.log(`WTRUST Balance: ${formatEther(wtrustBalance)} WTRUST`);

    // Get triple creation cost
    const tripleCost = await multiVault.read.getTripleCost();
    console.log(`Triple Creation Cost: ${formatEther(tripleCost)} WTRUST`);

    // Get atom deposit fraction (portion that goes to underlying atoms)
    const atomDepositFraction = await multiVault.read.atomDepositFractionAmount([DEPOSIT_AMOUNT]);
    console.log(`Atom Deposit Fraction: ${formatEther(atomDepositFraction)} WTRUST`);
    console.log(`  (This will be split among the 3 underlying atoms)`);

    const totalRequired = DEPOSIT_AMOUNT + tripleCost;
    console.log(`Total Required: ${formatEther(totalRequired)} WTRUST`);

    if (wtrustBalance < totalRequired) {
      throw new Error(
        `Insufficient WTRUST balance. Need ${formatEther(totalRequired)} but have ${formatEther(wtrustBalance)}`
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
        await multiVault.read.previewTripleCreate([tripleId, DEPOSIT_AMOUNT]);

      console.log(`Expected shares to receive: ${formatEther(shares)}`);
      console.log(`Assets after fixed fees: ${formatEther(assetsAfterFixedFees)} WTRUST`);
      console.log(`Assets after all fees: ${formatEther(assetsAfterFees)} WTRUST`);

      const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
      console.log(`Total fees: ${formatEther(totalFees)} WTRUST`);

      // Note: The atomDepositFraction is taken from the deposit amount
      // before it enters the triple vault
      const tripleVaultDeposit = DEPOSIT_AMOUNT - atomDepositFraction;
      console.log();
      console.log('Deposit breakdown:');
      console.log(`  To underlying atoms: ${formatEther(atomDepositFraction)} WTRUST`);
      console.log(`  To triple vault: ${formatEther(tripleVaultDeposit)} WTRUST`);
    } catch (error) {
      console.log('⚠ Preview unavailable (normal for new triples)');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Approve WTRUST
    // ------------------------------------------------------------------------
    console.log('Step 7: Approving WTRUST spending...');

    const currentAllowance = await wTrust.read.allowance([account.address, MULTIVAULT_ADDRESS]);
    console.log(`Current allowance: ${formatEther(currentAllowance)} WTRUST`);

    if (currentAllowance < totalRequired) {
      console.log('Approving WTRUST tokens...');

      const approveTx = await wTrust.write.approve([MULTIVAULT_ADDRESS, totalRequired]);
      console.log(`Approval tx submitted: ${approveTx}`);

      const approveReceipt = await publicClient.waitForTransactionReceipt({ hash: approveTx });
      console.log(`✓ Approval confirmed in block ${approveReceipt.blockNumber}`);
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
    console.log(`Initial deposit: ${formatEther(DEPOSIT_AMOUNT)} WTRUST`);
    console.log();

    // Prepare arrays for batch creation (even though creating just one)
    const subjectIds = [SUBJECT_ID];
    const predicateIds = [PREDICATE_ID];
    const objectIds = [OBJECT_ID];
    const assets = [DEPOSIT_AMOUNT];

    // Estimate gas
    const gasEstimate = await multiVault.estimateGas.createTriples([
      subjectIds,
      predicateIds,
      objectIds,
      assets
    ]);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the triple
    const createTx = await multiVault.write.createTriples([
      subjectIds,
      predicateIds,
      objectIds,
      assets
    ], {
      gas: gasEstimate * 120n / 100n, // Add 20% buffer
    });

    console.log(`Transaction submitted: ${createTx}`);
    console.log('Waiting for confirmation...');

    const receipt = await publicClient.waitForTransactionReceipt({ hash: createTx });
    console.log(`✓ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 9: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 9: Parsing transaction events...');

    // Find TripleCreated event
    const tripleCreatedLog = receipt.logs.find(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: MULTIVAULT_ABI,
          logs: [log],
          eventName: 'TripleCreated'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (tripleCreatedLog) {
      const tripleCreatedEvent = publicClient.parseEventLogs({
        abi: MULTIVAULT_ABI,
        logs: [tripleCreatedLog],
        eventName: 'TripleCreated'
      })[0];

      if (tripleCreatedEvent && tripleCreatedEvent.args) {
        console.log('TripleCreated Event:');
        console.log(`  Creator: ${tripleCreatedEvent.args.creator}`);
        console.log(`  Triple ID: ${tripleCreatedEvent.args.termId}`);
        console.log(`  Subject ID: ${tripleCreatedEvent.args.subjectId}`);
        console.log(`  Predicate ID: ${tripleCreatedEvent.args.predicateId}`);
        console.log(`  Object ID: ${tripleCreatedEvent.args.objectId}`);
        console.log();
      }
    }

    // Find all Deposited events (there will be multiple - one for triple + three for atoms)
    const depositedLogs = receipt.logs.filter(log => {
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

    const depositedEvents = depositedLogs.map(log =>
      publicClient.parseEventLogs({
        abi: MULTIVAULT_ABI,
        logs: [log],
        eventName: 'Deposited'
      })[0]
    );

    console.log(`Found ${depositedEvents.length} Deposited events:`);
    depositedEvents.forEach((event, index) => {
      if (event && event.args) {
        const vaultType = event.args.vaultType;
        const vaultTypeName = vaultType === 0 ? 'ATOM' : vaultType === 1 ? 'TRIPLE' : 'COUNTER_TRIPLE';

        console.log(`\nDeposit ${index + 1} (${vaultTypeName}):`);
        console.log(`  Term ID: ${event.args.termId}`);
        console.log(`  Curve ID: ${event.args.curveId}`);
        console.log(`  Assets: ${formatEther(event.args.assets)} WTRUST`);
        console.log(`  Shares Minted: ${formatEther(event.args.shares)}`);
      }
    });
    console.log();

    // ------------------------------------------------------------------------
    // Step 10: Verify Triple Structure
    // ------------------------------------------------------------------------
    console.log('Step 10: Verifying triple structure...');

    const [subject, predicate, object] = await multiVault.read.getTriple([tripleId]);
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
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt.transactionHash}`);
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
