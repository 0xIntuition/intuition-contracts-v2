/**
 * @title Batch Operations Example
 * @notice Demonstrates batch deposits and redemptions for gas efficiency
 * @dev Uses viem with MultiVault batch functions
 *
 * Batch operations allow you to:
 * - Deposit into multiple vaults in a single transaction
 * - Redeem from multiple vaults in a single transaction
 * - Save on gas compared to individual transactions
 * - Atomic execution (all succeed or all fail)
 */

import { createPublicClient, createWalletClient, http, parseEther, formatEther, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as `0x${string}`;
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672' as `0x${string}`;
const PRIVATE_KEY = (process.env.PRIVATE_KEY || '') as `0x${string}`;

const MULTIVAULT_ABI = [
  {
    name: 'depositBatch',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'receiver', type: 'address' },
      { name: 'termIds', type: 'bytes32[]' },
      { name: 'curveIds', type: 'uint256[]' },
      { name: 'assets', type: 'uint256[]' },
      { name: 'minShares', type: 'uint256[]' }
    ],
    outputs: [{ name: '', type: 'uint256[]' }]
  },
  {
    name: 'redeemBatch',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'receiver', type: 'address' },
      { name: 'termIds', type: 'bytes32[]' },
      { name: 'curveIds', type: 'uint256[]' },
      { name: 'shares', type: 'uint256[]' },
      { name: 'minAssets', type: 'uint256[]' }
    ],
    outputs: [{ name: '', type: 'uint256[]' }]
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
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
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
  }
] as const;

async function main() {
  console.log('Batch Operations Example\n');

  // Create public client for reading blockchain data
  const publicClient = createPublicClient({
    chain: base,
    transport: http(RPC_URL)
  });

  // Create account from private key
  const account = privateKeyToAccount(PRIVATE_KEY);

  // Create wallet client for transactions
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http(RPC_URL)
  });

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

  // ============================================================================
  // Batch Deposit Example
  // ============================================================================

  console.log('='.repeat(60));
  console.log('BATCH DEPOSIT');
  console.log('='.repeat(60));

  // Define multiple deposits
  const deposits = [
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`,
      curveId: 1,
      amount: parseEther('5'),
    },
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000002' as `0x${string}`,
      curveId: 1,
      amount: parseEther('10'),
    },
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000003' as `0x${string}`,
      curveId: 1,
      amount: parseEther('15'),
    },
  ];

  // Calculate total amount needed
  const totalAmount = deposits.reduce((sum, d) => sum + d.amount, 0n);
  console.log(`Total deposit amount: ${formatEther(totalAmount)} WTRUST`);
  console.log(`Number of deposits: ${deposits.length}\n`);

  // Check balance
  const balance = await wTrust.read.balanceOf([account.address]);
  if (balance < totalAmount) {
    throw new Error('Insufficient WTRUST balance');
  }

  // Preview each deposit and calculate min shares
  const termIds: `0x${string}`[] = [];
  const curveIds: bigint[] = [];
  const assets: bigint[] = [];
  const minShares: bigint[] = [];

  console.log('Previewing deposits:');
  for (const deposit of deposits) {
    const [expectedShares] = await multiVault.read.previewDeposit([
      deposit.termId,
      BigInt(deposit.curveId),
      deposit.amount
    ]);

    // Apply 1% slippage tolerance
    const minShare = expectedShares * 99n / 100n;

    termIds.push(deposit.termId);
    curveIds.push(BigInt(deposit.curveId));
    assets.push(deposit.amount);
    minShares.push(minShare);

    console.log(`  ${deposit.termId.slice(0, 10)}...`);
    console.log(`    Amount: ${formatEther(deposit.amount)} WTRUST`);
    console.log(`    Expected shares: ${formatEther(expectedShares)}`);
    console.log(`    Min shares: ${formatEther(minShare)}`);
  }
  console.log();

  // Approve WTRUST
  const allowance = await wTrust.read.allowance([account.address, MULTIVAULT_ADDRESS]);
  if (allowance < totalAmount) {
    console.log('Approving WTRUST...');
    const approveTx = await wTrust.write.approve([MULTIVAULT_ADDRESS, totalAmount]);
    await publicClient.waitForTransactionReceipt({ hash: approveTx });
    console.log('✓ Approved\n');
  }

  // Execute batch deposit
  console.log('Executing batch deposit...');
  const depositTx = await multiVault.write.depositBatch([
    account.address,
    termIds,
    curveIds,
    assets,
    minShares
  ]);

  console.log(`Tx submitted: ${depositTx}`);
  const depositReceipt = await publicClient.waitForTransactionReceipt({ hash: depositTx });
  console.log(`✓ Confirmed in block ${depositReceipt.blockNumber}`);
  console.log(`Gas used: ${depositReceipt.gasUsed.toString()}\n`);

  // ============================================================================
  // Batch Redeem Example
  // ============================================================================

  console.log('='.repeat(60));
  console.log('BATCH REDEEM');
  console.log('='.repeat(60));

  // Define multiple redemptions (redeem 50% of each position)
  const redemptions = deposits.map(d => ({
    termId: d.termId,
    curveId: d.curveId,
    shares: minShares[deposits.indexOf(d)] / 2n, // Redeem 50%
  }));

  console.log(`Number of redemptions: ${redemptions.length}\n`);

  // Preview each redemption
  const redeemTermIds: `0x${string}`[] = [];
  const redeemCurveIds: bigint[] = [];
  const redeemShares: bigint[] = [];
  const minAssets: bigint[] = [];

  console.log('Previewing redemptions:');
  for (const redemption of redemptions) {
    const [expectedAssets] = await multiVault.read.previewRedeem([
      redemption.termId,
      BigInt(redemption.curveId),
      redemption.shares
    ]);

    // Apply 1% slippage tolerance
    const minAsset = expectedAssets * 99n / 100n;

    redeemTermIds.push(redemption.termId);
    redeemCurveIds.push(BigInt(redemption.curveId));
    redeemShares.push(redemption.shares);
    minAssets.push(minAsset);

    console.log(`  ${redemption.termId.slice(0, 10)}...`);
    console.log(`    Shares: ${formatEther(redemption.shares)}`);
    console.log(`    Expected assets: ${formatEther(expectedAssets)} WTRUST`);
    console.log(`    Min assets: ${formatEther(minAsset)} WTRUST`);
  }
  console.log();

  // Execute batch redemption
  console.log('Executing batch redemption...');
  const redeemTx = await multiVault.write.redeemBatch([
    account.address,
    redeemTermIds,
    redeemCurveIds,
    redeemShares,
    minAssets
  ]);

  console.log(`Tx submitted: ${redeemTx}`);
  const redeemReceipt = await publicClient.waitForTransactionReceipt({ hash: redeemTx });
  console.log(`✓ Confirmed in block ${redeemReceipt.blockNumber}`);
  console.log(`Gas used: ${redeemReceipt.gasUsed.toString()}\n`);

  console.log('='.repeat(60));
  console.log('✓ Batch operations completed successfully!');
  console.log('='.repeat(60));
}

main().catch(console.error);

/*
Example Output:
================================================================
BATCH DEPOSIT
================================================================
Total deposit amount: 30.0 WTRUST
Number of deposits: 3

Previewing deposits:
  0x00000000...
    Amount: 5.0 WTRUST
    Expected shares: 4.9
    Min shares: 4.851
  0x00000000...
    Amount: 10.0 WTRUST
    Expected shares: 9.8
    Min shares: 9.702
  0x00000000...
    Amount: 15.0 WTRUST
    Expected shares: 14.7
    Min shares: 14.553

Executing batch deposit...
Tx submitted: 0xabc123...
✓ Confirmed in block 12400
Gas used: 450000

================================================================
BATCH REDEEM
================================================================
Number of redemptions: 3

Previewing redemptions:
  0x00000000...
    Shares: 2.4255
    Expected assets: 2.45 WTRUST
    Min assets: 2.4255 WTRUST
  0x00000000...
    Shares: 4.851
    Expected assets: 4.9 WTRUST
    Min assets: 4.851 WTRUST
  0x00000000...
    Shares: 7.2765
    Expected assets: 7.35 WTRUST
    Min assets: 7.2765 WTRUST

Executing batch redemption...
Tx submitted: 0xdef456...
✓ Confirmed in block 12401
Gas used: 380000

================================================================
✓ Batch operations completed successfully!
================================================================
*/
