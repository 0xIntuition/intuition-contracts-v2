/**
 * @title Event Listener Example
 * @notice Demonstrates how to listen for and parse MultiVault events in real-time
 * @dev Uses viem event listeners and WebSocket connection
 *
 * Events monitored:
 * - AtomCreated: New atom vaults created
 * - TripleCreated: New triple vaults created
 * - Deposited: Deposits into any vault
 * - Redeemed: Redemptions from any vault
 * - SharePriceChanged: Share price updates
 */

import { createPublicClient, http, webSocket, formatEther, hexToString, parseAbiItem } from 'viem';
import { base } from 'viem/chains';

const WS_RPC_URL = 'YOUR_INTUITION_WS_RPC_URL'; // WebSocket endpoint
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;

// Full event ABI
const MULTIVAULT_ABI = [
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
  },
  {
    name: 'SharePriceChanged',
    type: 'event',
    inputs: [
      { name: 'termId', type: 'bytes32', indexed: true },
      { name: 'curveId', type: 'uint256', indexed: true },
      { name: 'sharePrice', type: 'uint256', indexed: false },
      { name: 'totalAssets', type: 'uint256', indexed: false },
      { name: 'totalShares', type: 'uint256', indexed: false },
      { name: 'vaultType', type: 'uint8', indexed: false }
    ]
  },
  {
    name: 'ProtocolFeeAccrued',
    type: 'event',
    inputs: [
      { name: 'epoch', type: 'uint256', indexed: true },
      { name: 'sender', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false }
    ]
  }
] as const;

// Helper to format vault type
function formatVaultType(vaultType: number): string {
  const types = ['ATOM', 'TRIPLE', 'COUNTER_TRIPLE'];
  return types[vaultType] || 'UNKNOWN';
}

async function main() {
  console.log('='.repeat(80));
  console.log('Intuition Protocol Event Listener');
  console.log('='.repeat(80));
  console.log();

  // Create WebSocket public client for real-time events
  const publicClient = createPublicClient({
    chain: base,
    transport: webSocket(WS_RPC_URL)
  });

  console.log('✓ Connected to Intuition network via WebSocket');
  console.log(`Monitoring contract: ${MULTIVAULT_ADDRESS}`);
  console.log();
  console.log('Listening for events... (Press Ctrl+C to stop)');
  console.log('='.repeat(80));
  console.log();

  // ============================================================================
  // AtomCreated Event
  // ============================================================================

  const unsubscribeAtomCreated = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { creator, termId, atomData, atomWallet } = log.args;

        console.log('🔵 AtomCreated');
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Tx: ${log.transactionHash}`);
        console.log(`  Creator: ${creator}`);
        console.log(`  Atom ID: ${termId}`);

        // Try to decode atom data as UTF-8 string
        try {
          const dataStr = hexToString(atomData as `0x${string}`);
          console.log(`  Atom Data: "${dataStr}"`);
        } catch {
          console.log(`  Atom Data: ${atomData} (binary)`);
        }

        console.log(`  Atom Wallet: ${atomWallet}`);
        console.log();
      });
    }
  });

  // ============================================================================
  // TripleCreated Event
  // ============================================================================

  const unsubscribeTripleCreated = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { creator, termId, subjectId, predicateId, objectId } = log.args;

        console.log('🟢 TripleCreated');
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Tx: ${log.transactionHash}`);
        console.log(`  Creator: ${creator}`);
        console.log(`  Triple ID: ${termId}`);
        console.log(`  Subject: ${subjectId}`);
        console.log(`  Predicate: ${predicateId}`);
        console.log(`  Object: ${objectId}`);
        console.log();
      });
    }
  });

  // ============================================================================
  // Deposited Event
  // ============================================================================

  const unsubscribeDeposited = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { sender, receiver, termId, curveId, assets, assetsAfterFees, shares, totalShares, vaultType } = log.args;
        const vaultTypeName = formatVaultType(vaultType);

        console.log(`🟡 Deposited (${vaultTypeName})`);
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Tx: ${log.transactionHash}`);
        console.log(`  Sender: ${sender}`);
        console.log(`  Receiver: ${receiver}`);
        console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
        console.log(`  Curve ID: ${curveId}`);
        console.log(`  Assets: ${formatEther(assets)} WTRUST`);
        console.log(`  Assets After Fees: ${formatEther(assetsAfterFees)} WTRUST`);
        console.log(`  Shares Minted: ${formatEther(shares)}`);
        console.log(`  User Total Shares: ${formatEther(totalShares)}`);

        const feePercentage = assets > 0n
          ? ((Number(assets - assetsAfterFees) / Number(assets)) * 100).toFixed(2)
          : '0.00';
        console.log(`  Fees: ${feePercentage}%`);
        console.log();
      });
    }
  });

  // ============================================================================
  // Redeemed Event
  // ============================================================================

  const unsubscribeRedeemed = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event Redeemed(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 shares, uint256 totalShares, uint256 assets, uint256 fees, uint8 vaultType)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { sender, receiver, termId, curveId, shares, totalShares, assets, fees, vaultType } = log.args;
        const vaultTypeName = formatVaultType(vaultType);

        console.log(`🔴 Redeemed (${vaultTypeName})`);
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Tx: ${log.transactionHash}`);
        console.log(`  Sender: ${sender}`);
        console.log(`  Receiver: ${receiver}`);
        console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
        console.log(`  Curve ID: ${curveId}`);
        console.log(`  Shares Burned: ${formatEther(shares)}`);
        console.log(`  User Remaining Shares: ${formatEther(totalShares)}`);
        console.log(`  Assets Received: ${formatEther(assets)} WTRUST`);
        console.log(`  Fees Paid: ${formatEther(fees)} WTRUST`);
        console.log();
      });
    }
  });

  // ============================================================================
  // SharePriceChanged Event
  // ============================================================================

  const unsubscribeSharePriceChanged = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event SharePriceChanged(bytes32 indexed termId, uint256 indexed curveId, uint256 sharePrice, uint256 totalAssets, uint256 totalShares, uint8 vaultType)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { termId, curveId, sharePrice, totalAssets, totalShares, vaultType } = log.args;
        const vaultTypeName = formatVaultType(vaultType);

        console.log(`📊 SharePriceChanged (${vaultTypeName})`);
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
        console.log(`  Curve ID: ${curveId}`);
        console.log(`  Share Price: ${formatEther(sharePrice)} WTRUST`);
        console.log(`  Total Assets: ${formatEther(totalAssets)} WTRUST`);
        console.log(`  Total Shares: ${formatEther(totalShares)}`);
        console.log();
      });
    }
  });

  // ============================================================================
  // ProtocolFeeAccrued Event
  // ============================================================================

  const unsubscribeProtocolFeeAccrued = publicClient.watchEvent({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event ProtocolFeeAccrued(uint256 indexed epoch, address indexed sender, uint256 amount)'),
    onLogs: logs => {
      logs.forEach(log => {
        const { epoch, sender, amount } = log.args;

        console.log('💰 ProtocolFeeAccrued');
        console.log(`  Block: ${log.blockNumber}`);
        console.log(`  Epoch: ${epoch}`);
        console.log(`  Sender: ${sender}`);
        console.log(`  Amount: ${formatEther(amount)} WTRUST`);
        console.log();
      });
    }
  });

  // Keep the process running
  process.on('SIGINT', () => {
    console.log('\n\nStopping event listener...');
    unsubscribeAtomCreated();
    unsubscribeTripleCreated();
    unsubscribeDeposited();
    unsubscribeRedeemed();
    unsubscribeSharePriceChanged();
    unsubscribeProtocolFeeAccrued();
    process.exit(0);
  });
}

// ============================================================================
// Historical Event Query Example
// ============================================================================

async function queryHistoricalEvents() {
  console.log('Querying Historical Events\n');

  const publicClient = createPublicClient({
    chain: base,
    transport: http('YOUR_INTUITION_RPC_URL')
  });

  // Get current block
  const currentBlock = await publicClient.getBlockNumber();
  console.log(`Current block: ${currentBlock}`);

  // Query last 1000 blocks
  const fromBlock = currentBlock - 1000n;
  console.log(`Querying blocks ${fromBlock} to ${currentBlock}\n`);

  // Query AtomCreated events
  const atomLogs = await publicClient.getLogs({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)'),
    fromBlock,
    toBlock: currentBlock
  });
  console.log(`Found ${atomLogs.length} AtomCreated events`);

  // Query TripleCreated events
  const tripleLogs = await publicClient.getLogs({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)'),
    fromBlock,
    toBlock: currentBlock
  });
  console.log(`Found ${tripleLogs.length} TripleCreated events`);

  // Query Deposited events for a specific user
  const userAddress = '0x1234567890123456789012345678901234567890' as `0x${string}`;
  const depositLogs = await publicClient.getLogs({
    address: MULTIVAULT_ADDRESS,
    event: parseAbiItem('event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)'),
    args: {
      sender: userAddress
    },
    fromBlock,
    toBlock: currentBlock
  });
  console.log(`Found ${depositLogs.length} Deposited events for ${userAddress}`);

  // Display first event if any
  if (atomLogs.length > 0) {
    console.log('\nFirst AtomCreated event:');
    const event = atomLogs[0];
    console.log(`  Block: ${event.blockNumber}`);
    console.log(`  Creator: ${event.args.creator}`);
    console.log(`  Atom ID: ${event.args.termId}`);
  }
}

// Run the listener
main().catch(console.error);

// Uncomment to run historical query instead:
// queryHistoricalEvents().catch(console.error);

/*
Example Output (Real-time):
================================================================================
Intuition Protocol Event Listener
================================================================================

✓ Connected to Intuition network via WebSocket
Monitoring contract: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e

Listening for events... (Press Ctrl+C to stop)
================================================================================

🔵 AtomCreated
  Block: 12450
  Tx: 0xabc123def456...
  Creator: 0x1234567890123456789012345678901234567890
  Atom Data: "New Protocol Feature"
  Atom Wallet: 0x9876543210987654321098765432109876543210

🟡 Deposited (ATOM)
  Block: 12451
  Tx: 0xdef456abc123...
  Sender: 0x1234567890123456789012345678901234567890
  Receiver: 0x1234567890123456789012345678901234567890
  Term ID: 0x00000000...12345678
  Curve ID: 1
  Assets: 10.0 WTRUST
  Assets After Fees: 9.8 WTRUST
  Shares Minted: 9.8
  User Total Shares: 9.8
  Fees: 2.00%

📊 SharePriceChanged (ATOM)
  Block: 12451
  Term ID: 0x00000000...12345678
  Curve ID: 1
  Share Price: 1.0 WTRUST
  Total Assets: 9.8 WTRUST
  Total Shares: 9.8
*/
