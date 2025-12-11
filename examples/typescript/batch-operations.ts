/**
 * @title Batch Operations Example
 * @notice Demonstrates batch deposits and redemptions for gas efficiency
 * @dev Uses ethers.js v6 with MultiVault batch functions
 *
 * Batch operations allow you to:
 * - Deposit into multiple vaults in a single transaction
 * - Redeem from multiple vaults in a single transaction
 * - Save on gas compared to individual transactions
 * - Atomic execution (all succeed or all fail)
 */

import { ethers } from 'ethers';

const RPC_URL = 'YOUR_INTUITION_RPC_URL';
const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const WTRUST_ADDRESS = '0x81cFb09cb44f7184Ad934C09F82000701A4bF672';
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

const MULTIVAULT_ABI = [
  'function depositBatch(address receiver, bytes32[] calldata termIds, uint256[] calldata curveIds, uint256[] calldata assets, uint256[] calldata minShares) external payable returns (uint256[] memory)',
  'function redeemBatch(address receiver, bytes32[] calldata termIds, uint256[] calldata curveIds, uint256[] calldata shares, uint256[] calldata minAssets) external returns (uint256[] memory)',
  'function previewDeposit(bytes32 termId, uint256 curveId, uint256 assets) external view returns (uint256 shares, uint256 assetsAfterFees)',
  'function previewRedeem(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256 assetsAfterFees, uint256 sharesUsed)',
];

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function balanceOf(address account) external view returns (uint256)',
];

async function main() {
  console.log('Batch Operations Example\n');

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(PRIVATE_KEY, provider);
  const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, MULTIVAULT_ABI, signer);
  const wTrust = new ethers.Contract(WTRUST_ADDRESS, ERC20_ABI, signer);

  // ============================================================================
  // Batch Deposit Example
  // ============================================================================

  console.log('='.repeat(60));
  console.log('BATCH DEPOSIT');
  console.log('='.repeat(60));

  // Define multiple deposits
  const deposits = [
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000001',
      curveId: 1,
      amount: ethers.parseEther('5'),
    },
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000002',
      curveId: 1,
      amount: ethers.parseEther('10'),
    },
    {
      termId: '0x0000000000000000000000000000000000000000000000000000000000000003',
      curveId: 1,
      amount: ethers.parseEther('15'),
    },
  ];

  // Calculate total amount needed
  const totalAmount = deposits.reduce((sum, d) =&gt; sum + d.amount, 0n);
  console.log(`Total deposit amount: ${ethers.formatEther(totalAmount)} WTRUST`);
  console.log(`Number of deposits: ${deposits.length}\n`);

  // Check balance
  const balance = await wTrust.balanceOf(signer.address);
  if (balance &lt; totalAmount) {
    throw new Error('Insufficient WTRUST balance');
  }

  // Preview each deposit and calculate min shares
  const termIds: string[] = [];
  const curveIds: bigint[] = [];
  const assets: bigint[] = [];
  const minShares: bigint[] = [];

  console.log('Previewing deposits:');
  for (const deposit of deposits) {
    const [expectedShares] = await multiVault.previewDeposit(
      deposit.termId,
      deposit.curveId,
      deposit.amount
    );

    // Apply 1% slippage tolerance
    const minShare = expectedShares * 99n / 100n;

    termIds.push(deposit.termId);
    curveIds.push(BigInt(deposit.curveId));
    assets.push(deposit.amount);
    minShares.push(minShare);

    console.log(`  ${deposit.termId.slice(0, 10)}...`);
    console.log(`    Amount: ${ethers.formatEther(deposit.amount)} WTRUST`);
    console.log(`    Expected shares: ${ethers.formatEther(expectedShares)}`);
    console.log(`    Min shares: ${ethers.formatEther(minShare)}`);
  }
  console.log();

  // Approve WTRUST
  const allowance = await wTrust.allowance(signer.address, MULTIVAULT_ADDRESS);
  if (allowance &lt; totalAmount) {
    console.log('Approving WTRUST...');
    const approveTx = await wTrust.approve(MULTIVAULT_ADDRESS, totalAmount);
    await approveTx.wait();
    console.log('✓ Approved\n');
  }

  // Execute batch deposit
  console.log('Executing batch deposit...');
  const depositTx = await multiVault.depositBatch(
    signer.address,
    termIds,
    curveIds,
    assets,
    minShares
  );

  console.log(`Tx submitted: ${depositTx.hash}`);
  const depositReceipt = await depositTx.wait();
  console.log(`✓ Confirmed in block ${depositReceipt?.blockNumber}`);
  console.log(`Gas used: ${depositReceipt?.gasUsed.toString()}\n`);

  // ============================================================================
  // Batch Redeem Example
  // ============================================================================

  console.log('='.repeat(60));
  console.log('BATCH REDEEM');
  console.log('='.repeat(60));

  // Define multiple redemptions (redeem 50% of each position)
  const redemptions = deposits.map(d =&gt; ({
    termId: d.termId,
    curveId: d.curveId,
    shares: minShares[deposits.indexOf(d)] / 2n, // Redeem 50%
  }));

  console.log(`Number of redemptions: ${redemptions.length}\n`);

  // Preview each redemption
  const redeemTermIds: string[] = [];
  const redeemCurveIds: bigint[] = [];
  const redeemShares: bigint[] = [];
  const minAssets: bigint[] = [];

  console.log('Previewing redemptions:');
  for (const redemption of redemptions) {
    const [expectedAssets] = await multiVault.previewRedeem(
      redemption.termId,
      redemption.curveId,
      redemption.shares
    );

    // Apply 1% slippage tolerance
    const minAsset = expectedAssets * 99n / 100n;

    redeemTermIds.push(redemption.termId);
    redeemCurveIds.push(BigInt(redemption.curveId));
    redeemShares.push(redemption.shares);
    minAssets.push(minAsset);

    console.log(`  ${redemption.termId.slice(0, 10)}...`);
    console.log(`    Shares: ${ethers.formatEther(redemption.shares)}`);
    console.log(`    Expected assets: ${ethers.formatEther(expectedAssets)} WTRUST`);
    console.log(`    Min assets: ${ethers.formatEther(minAsset)} WTRUST`);
  }
  console.log();

  // Execute batch redemption
  console.log('Executing batch redemption...');
  const redeemTx = await multiVault.redeemBatch(
    signer.address,
    redeemTermIds,
    redeemCurveIds,
    redeemShares,
    minAssets
  );

  console.log(`Tx submitted: ${redeemTx.hash}`);
  const redeemReceipt = await redeemTx.wait();
  console.log(`✓ Confirmed in block ${redeemReceipt?.blockNumber}`);
  console.log(`Gas used: ${redeemReceipt?.gasUsed.toString()}\n`);

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
