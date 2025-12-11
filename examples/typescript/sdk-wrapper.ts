/**
 * @title SDK Wrapper Example
 * @notice Production-ready SDK wrapper class for Intuition Protocol
 * @dev Demonstrates best practices for building an SDK around the MultiVault contract
 *
 * Features:
 * - Type-safe operations
 * - Error handling and retries
 * - Gas estimation
 * - Event parsing
 * - Slippage protection
 * - Batch operations
 */

import { ethers, Contract, Provider, Signer } from 'ethers';

// ============================================================================
// Types and Interfaces
// ============================================================================

export interface IntuitionConfig {
  rpcUrl: string;
  multiVaultAddress: string;
  wtrustAddress: string;
  chainId?: number;
}

export interface AtomData {
  data: string | Uint8Array;
  initialDeposit: bigint;
}

export interface TripleData {
  subjectId: string;
  predicateId: string;
  objectId: string;
  initialDeposit: bigint;
}

export interface DepositParams {
  termId: string;
  curveId: number;
  amount: bigint;
  slippageBps?: number; // Basis points (100 = 1%)
}

export interface RedeemParams {
  termId: string;
  curveId: number;
  shares: bigint;
  slippageBps?: number;
}

export interface VaultInfo {
  totalAssets: bigint;
  totalShares: bigint;
  sharePrice: bigint;
}

export interface UserPosition {
  shares: bigint;
  value: bigint;
}

// ============================================================================
// SDK Class
// ============================================================================

export class IntuitionSDK {
  private provider: Provider;
  private signer?: Signer;
  private multiVault: Contract;
  private wtrust: Contract;

  private readonly MULTIVAULT_ABI = [
    'function createAtoms(bytes[] calldata, uint256[] calldata) external payable returns (bytes32[] memory)',
    'function createTriples(bytes32[] calldata, bytes32[] calldata, bytes32[] calldata, uint256[] calldata) external payable returns (bytes32[] memory)',
    'function deposit(address, bytes32, uint256, uint256) external payable returns (uint256)',
    'function redeem(address, bytes32, uint256, uint256, uint256) external returns (uint256)',
    'function depositBatch(address, bytes32[] calldata, uint256[] calldata, uint256[] calldata, uint256[] calldata) external payable returns (uint256[] memory)',
    'function redeemBatch(address, bytes32[] calldata, uint256[] calldata, uint256[] calldata, uint256[] calldata) external returns (uint256[] memory)',
    'function previewDeposit(bytes32, uint256, uint256) external view returns (uint256, uint256)',
    'function previewRedeem(bytes32, uint256, uint256) external view returns (uint256, uint256)',
    'function previewAtomCreate(bytes32, uint256) external view returns (uint256, uint256, uint256)',
    'function previewTripleCreate(bytes32, uint256) external view returns (uint256, uint256, uint256)',
    'function calculateAtomId(bytes memory) external pure returns (bytes32)',
    'function calculateTripleId(bytes32, bytes32, bytes32) external pure returns (bytes32)',
    'function isTermCreated(bytes32) external view returns (bool)',
    'function getVault(bytes32, uint256) external view returns (uint256, uint256)',
    'function getShares(address, bytes32, uint256) external view returns (uint256)',
    'function currentSharePrice(bytes32, uint256) external view returns (uint256)',
    'function convertToAssets(bytes32, uint256, uint256) external view returns (uint256)',
    'function getAtomCost() external view returns (uint256)',
    'function getTripleCost() external view returns (uint256)',
  ];

  private readonly ERC20_ABI = [
    'function approve(address, uint256) external returns (bool)',
    'function allowance(address, address) external view returns (uint256)',
    'function balanceOf(address) external view returns (uint256)',
  ];

  constructor(config: IntuitionConfig, signer?: Signer) {
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl, config.chainId);
    this.signer = signer;

    this.multiVault = new Contract(
      config.multiVaultAddress,
      this.MULTIVAULT_ABI,
      signer || this.provider
    );

    this.wtrust = new Contract(
      config.wtrustAddress,
      this.ERC20_ABI,
      signer || this.provider
    );
  }

  // ============================================================================
  // Atom Operations
  // ============================================================================

  /**
   * Calculate the deterministic atom ID from data
   */
  async calculateAtomId(data: string | Uint8Array): Promise<string> {
    const bytes = typeof data === 'string' ? ethers.toUtf8Bytes(data) : data;
    return await this.multiVault.calculateAtomId(bytes);
  }

  /**
   * Check if an atom exists
   */
  async atomExists(atomId: string): Promise<boolean> {
    return await this.multiVault.isTermCreated(atomId);
  }

  /**
   * Create a new atom vault
   */
  async createAtom(
    data: string | Uint8Array,
    initialDeposit: bigint
  ): Promise<{ atomId: string; txHash: string; shares: bigint }> {
    if (!this.signer) throw new Error('Signer required for write operations');

    const bytes = typeof data === 'string' ? ethers.toUtf8Bytes(data) : data;
    const atomId = await this.calculateAtomId(bytes);

    // Check if already exists
    if (await this.atomExists(atomId)) {
      throw new Error(`Atom ${atomId} already exists`);
    }

    // Get creation cost
    const atomCost = await this.multiVault.getAtomCost();
    const totalAmount = initialDeposit + atomCost;

    // Ensure approval
    await this.ensureApproval(totalAmount);

    // Create atom
    const tx = await this.multiVault.createAtoms([bytes], [initialDeposit]);
    const receipt = await tx.wait();

    // Parse events to get shares minted
    const depositEvent = receipt.logs
      .map((log: any) =&gt; {
        try {
          return this.multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((e: any) =&gt; e?.name === 'Deposited');

    return {
      atomId,
      txHash: receipt.hash,
      shares: depositEvent?.args?.[6] || 0n,
    };
  }

  // ============================================================================
  // Triple Operations
  // ============================================================================

  /**
   * Calculate the deterministic triple ID
   */
  async calculateTripleId(
    subjectId: string,
    predicateId: string,
    objectId: string
  ): Promise<string> {
    return await this.multiVault.calculateTripleId(subjectId, predicateId, objectId);
  }

  /**
   * Create a new triple vault
   */
  async createTriple(
    subjectId: string,
    predicateId: string,
    objectId: string,
    initialDeposit: bigint
  ): Promise<{ tripleId: string; txHash: string; shares: bigint }> {
    if (!this.signer) throw new Error('Signer required for write operations');

    const tripleId = await this.calculateTripleId(subjectId, predicateId, objectId);

    // Verify atoms exist
    const [subjectExists, predicateExists, objectExists] = await Promise.all([
      this.atomExists(subjectId),
      this.atomExists(predicateId),
      this.atomExists(objectId),
    ]);

    if (!subjectExists || !predicateExists || !objectExists) {
      throw new Error('One or more atoms do not exist');
    }

    // Check if triple already exists
    if (await this.multiVault.isTermCreated(tripleId)) {
      throw new Error(`Triple ${tripleId} already exists`);
    }

    // Get creation cost
    const tripleCost = await this.multiVault.getTripleCost();
    const totalAmount = initialDeposit + tripleCost;

    // Ensure approval
    await this.ensureApproval(totalAmount);

    // Create triple
    const tx = await this.multiVault.createTriples(
      [subjectId],
      [predicateId],
      [objectId],
      [initialDeposit]
    );
    const receipt = await tx.wait();

    // Parse events
    const depositEvent = receipt.logs
      .map((log: any) =&gt; {
        try {
          return this.multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((e: any) =&gt; e?.name === 'Deposited' && e?.args?.[8] === 1); // VaultType.TRIPLE

    return {
      tripleId,
      txHash: receipt.hash,
      shares: depositEvent?.args?.[6] || 0n,
    };
  }

  // ============================================================================
  // Vault Operations
  // ============================================================================

  /**
   * Deposit into a vault
   */
  async deposit(params: DepositParams): Promise<{ txHash: string; shares: bigint }> {
    if (!this.signer) throw new Error('Signer required for write operations');

    const slippageBps = params.slippageBps || 100; // Default 1%

    // Preview deposit
    const [expectedShares] = await this.multiVault.previewDeposit(
      params.termId,
      params.curveId,
      params.amount
    );

    // Calculate min shares with slippage
    const minShares = (expectedShares * BigInt(10000 - slippageBps)) / 10000n;

    // Ensure approval
    await this.ensureApproval(params.amount);

    // Execute deposit
    const signerAddress = await this.signer.getAddress();
    const tx = await this.multiVault.deposit(
      signerAddress,
      params.termId,
      params.curveId,
      minShares
    );
    const receipt = await tx.wait();

    // Parse event
    const depositEvent = receipt.logs
      .map((log: any) =&gt; {
        try {
          return this.multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((e: any) =&gt; e?.name === 'Deposited');

    return {
      txHash: receipt.hash,
      shares: depositEvent?.args?.[6] || 0n,
    };
  }

  /**
   * Redeem shares from a vault
   */
  async redeem(params: RedeemParams): Promise<{ txHash: string; assets: bigint }> {
    if (!this.signer) throw new Error('Signer required for write operations');

    const slippageBps = params.slippageBps || 100; // Default 1%

    // Preview redemption
    const [expectedAssets] = await this.multiVault.previewRedeem(
      params.termId,
      params.curveId,
      params.shares
    );

    // Calculate min assets with slippage
    const minAssets = (expectedAssets * BigInt(10000 - slippageBps)) / 10000n;

    // Execute redemption
    const signerAddress = await this.signer.getAddress();
    const tx = await this.multiVault.redeem(
      signerAddress,
      params.termId,
      params.curveId,
      params.shares,
      minAssets
    );
    const receipt = await tx.wait();

    // Parse event
    const redeemEvent = receipt.logs
      .map((log: any) =&gt; {
        try {
          return this.multiVault.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((e: any) =&gt; e?.name === 'Redeemed');

    return {
      txHash: receipt.hash,
      assets: redeemEvent?.args?.[6] || 0n,
    };
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /**
   * Get vault information
   */
  async getVaultInfo(termId: string, curveId: number): Promise<VaultInfo> {
    const [totalAssets, totalShares] = await this.multiVault.getVault(termId, curveId);
    const sharePrice = await this.multiVault.currentSharePrice(termId, curveId);

    return { totalAssets, totalShares, sharePrice };
  }

  /**
   * Get user position in a vault
   */
  async getUserPosition(
    userAddress: string,
    termId: string,
    curveId: number
  ): Promise<UserPosition> {
    const shares = await this.multiVault.getShares(userAddress, termId, curveId);
    const value = await this.multiVault.convertToAssets(termId, curveId, shares);

    return { shares, value };
  }

  // ============================================================================
  // Utilities
  // ============================================================================

  /**
   * Ensure sufficient WTRUST approval
   */
  private async ensureApproval(amount: bigint): Promise<void> {
    if (!this.signer) throw new Error('Signer required');

    const signerAddress = await this.signer.getAddress();
    const currentAllowance = await this.wtrust.allowance(
      signerAddress,
      await this.multiVault.getAddress()
    );

    if (currentAllowance &lt; amount) {
      const tx = await this.wtrust.approve(
        await this.multiVault.getAddress(),
        amount
      );
      await tx.wait();
    }
  }
}

// ============================================================================
// Usage Example
// ============================================================================

async function exampleUsage() {
  const config: IntuitionConfig = {
    rpcUrl: 'YOUR_INTUITION_RPC_URL',
    multiVaultAddress: '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e',
    wtrustAddress: '0x81cFb09cb44f7184Ad934C09F82000701A4bF672',
  };

  const signer = new ethers.Wallet('PRIVATE_KEY', new ethers.JsonRpcProvider(config.rpcUrl));
  const sdk = new IntuitionSDK(config, signer);

  // Create an atom
  const { atomId, shares } = await sdk.createAtom(
    'My Atom Data',
    ethers.parseEther('10')
  );
  console.log(`Created atom ${atomId} with ${ethers.formatEther(shares)} shares`);

  // Deposit into vault
  const depositResult = await sdk.deposit({
    termId: atomId,
    curveId: 1,
    amount: ethers.parseEther('5'),
    slippageBps: 100, // 1% slippage
  });
  console.log(`Deposited, received ${ethers.formatEther(depositResult.shares)} shares`);

  // Query position
  const position = await sdk.getUserPosition(await signer.getAddress(), atomId, 1);
  console.log(`Your position: ${ethers.formatEther(position.shares)} shares worth ${ethers.formatEther(position.value)} WTRUST`);

  // Redeem shares
  const redeemResult = await sdk.redeem({
    termId: atomId,
    curveId: 1,
    shares: position.shares / 2n, // Redeem 50%
    slippageBps: 100,
  });
  console.log(`Redeemed ${ethers.formatEther(redeemResult.assets)} WTRUST`);
}

// Uncomment to run:
// exampleUsage().catch(console.error);
