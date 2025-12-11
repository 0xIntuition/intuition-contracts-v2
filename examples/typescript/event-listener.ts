/**
 * @title Event Listener Example
 * @notice Demonstrates how to listen for and parse MultiVault events in real-time
 * @dev Uses ethers.js v6 event listeners and WebSocket connection
 *
 * Events monitored:
 * - AtomCreated: New atom vaults created
 * - TripleCreated: New triple vaults created
 * - Deposited: Deposits into any vault
 * - Redeemed: Redemptions from any vault
 * - SharePriceChanged: Share price updates
 */

import { ethers } from 'ethers';

const WS_RPC_URL = 'YOUR_INTUITION_WS_RPC_URL'; // WebSocket endpoint
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';

// Full event ABI
const MULTIVAULT_ABI = [
  'event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)',
  'event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)',
  'event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)',
  'event Redeemed(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 shares, uint256 totalShares, uint256 assets, uint256 fees, uint8 vaultType)',
  'event SharePriceChanged(bytes32 indexed termId, uint256 indexed curveId, uint256 sharePrice, uint256 totalAssets, uint256 totalShares, uint8 vaultType)',
  'event ProtocolFeeAccrued(uint256 indexed epoch, address indexed sender, uint256 amount)',
];

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

  // Create WebSocket provider for real-time events
  const provider = new ethers.WebSocketProvider(WS_RPC_URL);

  // Create contract instance
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    provider
  );

  console.log('✓ Connected to Intuition network via WebSocket');
  console.log(`Monitoring contract: ${MULTIVAULT_ADDRESS}`);
  console.log();
  console.log('Listening for events... (Press Ctrl+C to stop)');
  console.log('='.repeat(80));
  console.log();

  // ============================================================================
  // AtomCreated Event
  // ============================================================================

  multiVault.on('AtomCreated', (creator, termId, atomData, atomWallet, event) =&gt; {
    console.log('🔵 AtomCreated');
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Tx: ${event.log.transactionHash}`);
    console.log(`  Creator: ${creator}`);
    console.log(`  Atom ID: ${termId}`);

    // Try to decode atom data as UTF-8 string
    try {
      const dataStr = ethers.toUtf8String(atomData);
      console.log(`  Atom Data: "${dataStr}"`);
    } catch {
      console.log(`  Atom Data: ${atomData} (binary)`);
    }

    console.log(`  Atom Wallet: ${atomWallet}`);
    console.log();
  });

  // ============================================================================
  // TripleCreated Event
  // ============================================================================

  multiVault.on('TripleCreated', (creator, termId, subjectId, predicateId, objectId, event) =&gt; {
    console.log('🟢 TripleCreated');
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Tx: ${event.log.transactionHash}`);
    console.log(`  Creator: ${creator}`);
    console.log(`  Triple ID: ${termId}`);
    console.log(`  Subject: ${subjectId}`);
    console.log(`  Predicate: ${predicateId}`);
    console.log(`  Object: ${objectId}`);
    console.log();
  });

  // ============================================================================
  // Deposited Event
  // ============================================================================

  multiVault.on('Deposited', (
    sender,
    receiver,
    termId,
    curveId,
    assets,
    assetsAfterFees,
    shares,
    totalShares,
    vaultType,
    event
  ) =&gt; {
    const vaultTypeName = formatVaultType(vaultType);

    console.log(`🟡 Deposited (${vaultTypeName})`);
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Tx: ${event.log.transactionHash}`);
    console.log(`  Sender: ${sender}`);
    console.log(`  Receiver: ${receiver}`);
    console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
    console.log(`  Curve ID: ${curveId}`);
    console.log(`  Assets: ${ethers.formatEther(assets)} WTRUST`);
    console.log(`  Assets After Fees: ${ethers.formatEther(assetsAfterFees)} WTRUST`);
    console.log(`  Shares Minted: ${ethers.formatEther(shares)}`);
    console.log(`  User Total Shares: ${ethers.formatEther(totalShares)}`);

    const feePercentage = assets &gt; 0n
      ? ((Number(assets - assetsAfterFees) / Number(assets)) * 100).toFixed(2)
      : '0.00';
    console.log(`  Fees: ${feePercentage}%`);
    console.log();
  });

  // ============================================================================
  // Redeemed Event
  // ============================================================================

  multiVault.on('Redeemed', (
    sender,
    receiver,
    termId,
    curveId,
    shares,
    totalShares,
    assets,
    fees,
    vaultType,
    event
  ) =&gt; {
    const vaultTypeName = formatVaultType(vaultType);

    console.log(`🔴 Redeemed (${vaultTypeName})`);
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Tx: ${event.log.transactionHash}`);
    console.log(`  Sender: ${sender}`);
    console.log(`  Receiver: ${receiver}`);
    console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
    console.log(`  Curve ID: ${curveId}`);
    console.log(`  Shares Burned: ${ethers.formatEther(shares)}`);
    console.log(`  User Remaining Shares: ${ethers.formatEther(totalShares)}`);
    console.log(`  Assets Received: ${ethers.formatEther(assets)} WTRUST`);
    console.log(`  Fees Paid: ${ethers.formatEther(fees)} WTRUST`);
    console.log();
  });

  // ============================================================================
  // SharePriceChanged Event
  // ============================================================================

  multiVault.on('SharePriceChanged', (
    termId,
    curveId,
    sharePrice,
    totalAssets,
    totalShares,
    vaultType,
    event
  ) =&gt; {
    const vaultTypeName = formatVaultType(vaultType);

    console.log(`📊 SharePriceChanged (${vaultTypeName})`);
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Term ID: ${termId.slice(0, 10)}...${termId.slice(-8)}`);
    console.log(`  Curve ID: ${curveId}`);
    console.log(`  Share Price: ${ethers.formatEther(sharePrice)} WTRUST`);
    console.log(`  Total Assets: ${ethers.formatEther(totalAssets)} WTRUST`);
    console.log(`  Total Shares: ${ethers.formatEther(totalShares)}`);
    console.log();
  });

  // ============================================================================
  // ProtocolFeeAccrued Event
  // ============================================================================

  multiVault.on('ProtocolFeeAccrued', (epoch, sender, amount, event) =&gt; {
    console.log('💰 ProtocolFeeAccrued');
    console.log(`  Block: ${event.log.blockNumber}`);
    console.log(`  Epoch: ${epoch}`);
    console.log(`  Sender: ${sender}`);
    console.log(`  Amount: ${ethers.formatEther(amount)} WTRUST`);
    console.log();
  });

  // ============================================================================
  // Error Handling
  // ============================================================================

  provider.on('error', (error) =&gt; {
    console.error('❌ WebSocket Error:', error);
    console.log('Attempting to reconnect...');
  });

  // Keep the process running
  process.on('SIGINT', () =&gt; {
    console.log('\n\nStopping event listener...');
    provider.destroy();
    process.exit(0);
  });
}

// ============================================================================
// Historical Event Query Example
// ============================================================================

async function queryHistoricalEvents() {
  console.log('Querying Historical Events\n');

  const provider = new ethers.JsonRpcProvider('YOUR_INTUITION_RPC_URL');
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    provider
  );

  // Get current block
  const currentBlock = await provider.getBlockNumber();
  console.log(`Current block: ${currentBlock}`);

  // Query last 1000 blocks
  const fromBlock = currentBlock - 1000;
  console.log(`Querying blocks ${fromBlock} to ${currentBlock}\n`);

  // Query AtomCreated events
  const atomFilter = multiVault.filters.AtomCreated();
  const atomEvents = await multiVault.queryFilter(atomFilter, fromBlock, currentBlock);
  console.log(`Found ${atomEvents.length} AtomCreated events`);

  // Query TripleCreated events
  const tripleFilter = multiVault.filters.TripleCreated();
  const tripleEvents = await multiVault.queryFilter(tripleFilter, fromBlock, currentBlock);
  console.log(`Found ${tripleEvents.length} TripleCreated events`);

  // Query Deposited events for a specific user
  const userAddress = '0x1234567890123456789012345678901234567890';
  const depositFilter = multiVault.filters.Deposited(userAddress);
  const depositEvents = await multiVault.queryFilter(depositFilter, fromBlock, currentBlock);
  console.log(`Found ${depositEvents.length} Deposited events for ${userAddress}`);

  // Display first event if any
  if (atomEvents.length &gt; 0) {
    console.log('\nFirst AtomCreated event:');
    const event = atomEvents[0];
    console.log(`  Block: ${event.blockNumber}`);
    console.log(`  Creator: ${event.args?.[0]}`);
    console.log(`  Atom ID: ${event.args?.[1]}`);
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
