/**
 * @title Create Atom Example
 * @notice Demonstrates how to create an atom vault with an initial deposit
 * @dev This example uses viem to interact with the MultiVault contract
 *
 * What this example does:
 * 1. Connects to the Intuition network
 * 2. Approves WTRUST tokens for the MultiVault contract
 * 3. Creates a new atom vault with metadata
 * 4. Monitors the creation event
 *
 * Prerequisites:
 * - Node.js v18+
 * - viem installed: `npm install viem`
 * - Private key with ETH for gas and WTRUST tokens for deposit
 * - Access to Intuition RPC endpoint
 */

import { createPublicClient, createWalletClient, http, parseEther, formatEther, toHex, getContract, parseAbiItem, hexToString, stringToHex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// ============================================================================
// Configuration
// ============================================================================

// Network configuration
const RPC_URL = 'YOUR_INTUITION_RPC_URL'; // Replace with actual Intuition RPC
const CHAIN_ID = 0; // Replace with actual Intuition chain ID

// Contract addresses (Intuition Mainnet)
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672' as `0x${string}`;

// Your wallet private key (NEVER commit this to git!)
const PRIVATE_KEY = (process.env.PRIVATE_KEY || '') as `0x${string}`;

// Atom configuration
const ATOM_DATA = stringToHex('My First Atom'); // Atom metadata
const DEPOSIT_AMOUNT = parseEther('10'); // 10 WTRUST tokens

// ============================================================================
// Contract ABIs (minimal required functions)
// ============================================================================

const MULTIVAULT_ABI = [
  // Create atoms function
  {
    name: 'createAtoms',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'atomDatas', type: 'bytes[]' },
      { name: 'assets', type: 'uint256[]' }
    ],
    outputs: [{ name: '', type: 'bytes32[]' }]
  },
  // Preview atom creation to estimate shares
  {
    name: 'previewAtomCreate',
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
  // Calculate atom ID from data
  {
    name: 'calculateAtomId',
    type: 'function',
    stateMutability: 'pure',
    inputs: [{ name: 'data', type: 'bytes' }],
    outputs: [{ name: 'id', type: 'bytes32' }]
  },
  // Check if term exists
  {
    name: 'isTermCreated',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  // Get atom cost (creation fees)
  {
    name: 'getAtomCost',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  // Events
  {
    name: 'AtomCreated',
    type: 'event',
    inputs: [
      { name: 'creator', type: 'address', indexed: true },
      { name: 'termId', type: 'bytes32', indexed: true },
      { name: 'atomData', type: 'bytes', indexed: false },
      { name: 'atomWallet', type: 'address', indexed: false }
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
  },
  {
    name: 'decimals',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }]
  }
] as const;

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

    // Check ETH balance for gas
    const ethBalance = await publicClient.getBalance({ address: account.address });
    console.log(`ETH Balance: ${formatEther(ethBalance)} ETH`);

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
    // Step 3: Check WTRUST Balance and Get Atom Cost
    // ------------------------------------------------------------------------
    console.log('Step 3: Checking WTRUST balance and atom creation cost...');

    const wtrustBalance = await wTrust.read.balanceOf([account.address]);
    console.log(`WTRUST Balance: ${formatEther(wtrustBalance)} WTRUST`);

    // Get atom creation cost (includes protocol fee + atom wallet deposit fee)
    const atomCost = await multiVault.read.getAtomCost();
    console.log(`Atom Creation Cost: ${formatEther(atomCost)} WTRUST`);

    // Total amount needed = deposit + atom cost
    const totalRequired = DEPOSIT_AMOUNT + atomCost;
    console.log(`Total Required: ${formatEther(totalRequired)} WTRUST`);

    // Verify sufficient balance
    if (wtrustBalance < totalRequired) {
      throw new Error(
        `Insufficient WTRUST balance. Need ${formatEther(totalRequired)} but have ${formatEther(wtrustBalance)}`
      );
    }
    console.log('✓ Sufficient balance confirmed');
    console.log();

    // ------------------------------------------------------------------------
    // Step 4: Calculate Atom ID and Check Existence
    // ------------------------------------------------------------------------
    console.log('Step 4: Calculating atom ID and checking if it exists...');

    // Calculate what the atom ID will be
    const atomId = await multiVault.read.calculateAtomId([ATOM_DATA]);
    console.log(`Atom ID: ${atomId}`);

    // Check if this atom already exists
    const atomExists = await multiVault.read.isTermCreated([atomId]);
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
        await multiVault.read.previewAtomCreate([atomId, DEPOSIT_AMOUNT]);

      console.log(`Expected shares to receive: ${formatEther(shares)}`);
      console.log(`Assets after fixed fees: ${formatEther(assetsAfterFixedFees)} WTRUST`);
      console.log(`Assets after all fees: ${formatEther(assetsAfterFees)} WTRUST`);

      const totalFees = DEPOSIT_AMOUNT - assetsAfterFees;
      console.log(`Total fees: ${formatEther(totalFees)} WTRUST`);
    } catch (error) {
      console.log('⚠ Preview unavailable (normal for new atoms)');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 6: Approve WTRUST Spending
    // ------------------------------------------------------------------------
    console.log('Step 6: Approving WTRUST spending...');

    // Check current allowance
    const currentAllowance = await wTrust.read.allowance([account.address, MULTIVAULT_ADDRESS]);
    console.log(`Current allowance: ${formatEther(currentAllowance)} WTRUST`);

    if (currentAllowance < totalRequired) {
      console.log('Approving WTRUST tokens...');

      // Approve exact amount needed (or use maxUint256 for unlimited)
      const approveTx = await wTrust.write.approve([MULTIVAULT_ADDRESS, totalRequired]);
      console.log(`Approval tx submitted: ${approveTx}`);

      // Wait for approval confirmation
      const approveReceipt = await publicClient.waitForTransactionReceipt({ hash: approveTx });
      console.log(`✓ Approval confirmed in block ${approveReceipt.blockNumber}`);
    } else {
      console.log('✓ Sufficient allowance already exists');
    }
    console.log();

    // ------------------------------------------------------------------------
    // Step 7: Create Atom
    // ------------------------------------------------------------------------
    console.log('Step 7: Creating atom vault...');
    console.log(`Atom data: "${hexToString(ATOM_DATA)}"`);
    console.log(`Initial deposit: ${formatEther(DEPOSIT_AMOUNT)} WTRUST`);

    // Prepare arrays for batch creation (even though we're creating just one)
    const atomDatas = [ATOM_DATA];
    const assets = [DEPOSIT_AMOUNT];

    // Estimate gas before sending
    const gasEstimate = await multiVault.estimateGas.createAtoms([atomDatas, assets]);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the atom
    const createTx = await multiVault.write.createAtoms([atomDatas, assets], {
      gas: gasEstimate * 120n / 100n, // Add 20% buffer
    });

    console.log(`Transaction submitted: ${createTx}`);
    console.log('Waiting for confirmation...');

    // Wait for transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash: createTx });
    console.log(`✓ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    console.log();

    // ------------------------------------------------------------------------
    // Step 8: Parse Events
    // ------------------------------------------------------------------------
    console.log('Step 8: Parsing transaction events...');

    // Find AtomCreated event
    const atomCreatedLog = receipt.logs.find(log => {
      try {
        const event = publicClient.parseEventLogs({
          abi: MULTIVAULT_ABI,
          logs: [log],
          eventName: 'AtomCreated'
        });
        return event.length > 0;
      } catch {
        return false;
      }
    });

    if (atomCreatedLog) {
      const atomCreatedEvent = publicClient.parseEventLogs({
        abi: MULTIVAULT_ABI,
        logs: [atomCreatedLog],
        eventName: 'AtomCreated'
      })[0];

      if (atomCreatedEvent && atomCreatedEvent.args) {
        console.log('AtomCreated Event:');
        console.log(`  Creator: ${atomCreatedEvent.args.creator}`);
        console.log(`  Atom ID: ${atomCreatedEvent.args.termId}`);
        console.log(`  Atom Data: "${hexToString(atomCreatedEvent.args.atomData as `0x${string}`)}"`);
        console.log(`  Atom Wallet: ${atomCreatedEvent.args.atomWallet}`);
        console.log();
      }
    }

    // Find Deposited event
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
        console.log(`  Assets: ${formatEther(depositedEvent.args.assets)} WTRUST`);
        console.log(`  Assets After Fees: ${formatEther(depositedEvent.args.assetsAfterFees)} WTRUST`);
        console.log(`  Shares Minted: ${formatEther(depositedEvent.args.shares)}`);
        console.log(`  Total Shares: ${formatEther(depositedEvent.args.totalShares)}`);
        console.log(`  Vault Type: ${depositedEvent.args.vaultType}`); // 0 = ATOM
        console.log();
      }
    }

    // ------------------------------------------------------------------------
    // Success!
    // ------------------------------------------------------------------------
    console.log('='.repeat(80));
    console.log('✓ Atom creation successful!');
    console.log(`Atom ID: ${atomId}`);
    console.log(`View on explorer: https://explorer.intuit.network/tx/${receipt.transactionHash}`);
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
