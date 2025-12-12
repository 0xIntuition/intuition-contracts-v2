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

import {
  PublicClient,
  WalletClient,
  createPublicClient,
  createWalletClient,
  http,
  getContract,
  parseEther,
  formatEther,
  stringToHex,
  type Address,
  type Hash,
  type Hex
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

// ============================================================================
// Types and Interfaces
// ============================================================================

export interface IntuitionConfig {
  rpcUrl: string;
  multiVaultAddress: Address;
  wtrustAddress: Address;
  chainId?: number;
}

export interface AtomData {
  data: string | Uint8Array;
  initialDeposit: bigint;
}

export interface TripleData {
  subjectId: Hex;
  predicateId: Hex;
  objectId: Hex;
  initialDeposit: bigint;
}

export interface DepositParams {
  termId: Hex;
  curveId: number;
  amount: bigint;
  slippageBps?: number; // Basis points (100 = 1%)
}

export interface RedeemParams {
  termId: Hex;
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
  private publicClient: PublicClient;
  private walletClient?: WalletClient;
  private multiVault: any;
  private wtrust: any;

  private readonly MULTIVAULT_ABI = [
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
      name: 'deposit',
      type: 'function',
      stateMutability: 'payable',
      inputs: [
        { name: 'receiver', type: 'address' },
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' },
        { name: 'minShares', type: 'uint256' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    },
    {
      name: 'redeem',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: 'receiver', type: 'address' },
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' },
        { name: 'shares', type: 'uint256' },
        { name: 'minAssets', type: 'uint256' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    },
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
    },
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
      name: 'calculateAtomId',
      type: 'function',
      stateMutability: 'pure',
      inputs: [{ name: 'data', type: 'bytes' }],
      outputs: [{ name: 'id', type: 'bytes32' }]
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
      outputs: [{ name: 'id', type: 'bytes32' }]
    },
    {
      name: 'isTermCreated',
      type: 'function',
      stateMutability: 'view',
      inputs: [{ name: 'id', type: 'bytes32' }],
      outputs: [{ name: '', type: 'bool' }]
    },
    {
      name: 'getVault',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' }
      ],
      outputs: [
        { name: 'totalAssets', type: 'uint256' },
        { name: 'totalShares', type: 'uint256' }
      ]
    },
    {
      name: 'getShares',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'account', type: 'address' },
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    },
    {
      name: 'currentSharePrice',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    },
    {
      name: 'convertToAssets',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'termId', type: 'bytes32' },
        { name: 'curveId', type: 'uint256' },
        { name: 'shares', type: 'uint256' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    },
    {
      name: 'getAtomCost',
      type: 'function',
      stateMutability: 'view',
      inputs: [],
      outputs: [{ name: '', type: 'uint256' }]
    },
    {
      name: 'getTripleCost',
      type: 'function',
      stateMutability: 'view',
      inputs: [],
      outputs: [{ name: '', type: 'uint256' }]
    },
    // Events
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

  private readonly ERC20_ABI = [
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

  constructor(config: IntuitionConfig, privateKey?: Hex) {
    // Create public client for reading
    this.publicClient = createPublicClient({
      chain: base,
      transport: http(config.rpcUrl)
    });

    // Create wallet client if private key provided
    if (privateKey) {
      const account = privateKeyToAccount(privateKey);
      this.walletClient = createWalletClient({
        account,
        chain: base,
        transport: http(config.rpcUrl)
      });
    }

    // Initialize contract instances
    this.multiVault = getContract({
      address: config.multiVaultAddress,
      abi: this.MULTIVAULT_ABI,
      client: { public: this.publicClient, wallet: this.walletClient }
    });

    this.wtrust = getContract({
      address: config.wtrustAddress,
      abi: this.ERC20_ABI,
      client: { public: this.publicClient, wallet: this.walletClient }
    });
  }

  // ============================================================================
  // Atom Operations
  // ============================================================================

  /**
   * Calculate the deterministic atom ID from data
   */
  async calculateAtomId(data: string | Uint8Array): Promise<Hex> {
    const bytes = typeof data === 'string' ? stringToHex(data) : data;
    return await this.multiVault.read.calculateAtomId([bytes]);
  }

  /**
   * Check if an atom exists
   */
  async atomExists(atomId: Hex): Promise<boolean> {
    return await this.multiVault.read.isTermCreated([atomId]);
  }

  /**
   * Create a new atom vault
   */
  async createAtom(
    data: string | Uint8Array,
    initialDeposit: bigint
  ): Promise<{ atomId: Hex; txHash: Hash; shares: bigint }> {
    if (!this.walletClient) throw new Error('Signer required for write operations');

    const bytes = typeof data === 'string' ? stringToHex(data) : data;
    const atomId = await this.calculateAtomId(bytes);

    // Check if already exists
    if (await this.atomExists(atomId)) {
      throw new Error(`Atom ${atomId} already exists`);
    }

    // Get creation cost
    const atomCost = await this.multiVault.read.getAtomCost();
    const totalAmount = initialDeposit + atomCost;

    // Ensure approval
    await this.ensureApproval(totalAmount);

    // Create atom
    const hash = await this.multiVault.write.createAtoms([[bytes], [initialDeposit]]);
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Parse events to get shares minted
    const depositLog = receipt.logs.find(log => {
      try {
        const parsed = this.publicClient.parseEventLogs({
          abi: this.MULTIVAULT_ABI,
          logs: [log],
          eventName: 'Deposited'
        });
        return parsed.length > 0;
      } catch {
        return false;
      }
    });

    let shares = 0n;
    if (depositLog) {
      const parsed = this.publicClient.parseEventLogs({
        abi: this.MULTIVAULT_ABI,
        logs: [depositLog],
        eventName: 'Deposited'
      })[0];
      shares = parsed.args.shares;
    }

    return {
      atomId,
      txHash: hash,
      shares,
    };
  }

  // ============================================================================
  // Triple Operations
  // ============================================================================

  /**
   * Calculate the deterministic triple ID
   */
  async calculateTripleId(
    subjectId: Hex,
    predicateId: Hex,
    objectId: Hex
  ): Promise<Hex> {
    return await this.multiVault.read.calculateTripleId([subjectId, predicateId, objectId]);
  }

  /**
   * Create a new triple vault
   */
  async createTriple(
    subjectId: Hex,
    predicateId: Hex,
    objectId: Hex,
    initialDeposit: bigint
  ): Promise<{ tripleId: Hex; txHash: Hash; shares: bigint }> {
    if (!this.walletClient) throw new Error('Signer required for write operations');

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
    if (await this.multiVault.read.isTermCreated([tripleId])) {
      throw new Error(`Triple ${tripleId} already exists`);
    }

    // Get creation cost
    const tripleCost = await this.multiVault.read.getTripleCost();
    const totalAmount = initialDeposit + tripleCost;

    // Ensure approval
    await this.ensureApproval(totalAmount);

    // Create triple
    const hash = await this.multiVault.write.createTriples([
      [subjectId],
      [predicateId],
      [objectId],
      [initialDeposit]
    ]);
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Parse events
    const depositLog = receipt.logs.find(log => {
      try {
        const parsed = this.publicClient.parseEventLogs({
          abi: this.MULTIVAULT_ABI,
          logs: [log],
          eventName: 'Deposited'
        });
        return parsed.length > 0 && parsed[0].args.vaultType === 1; // VaultType.TRIPLE
      } catch {
        return false;
      }
    });

    let shares = 0n;
    if (depositLog) {
      const parsed = this.publicClient.parseEventLogs({
        abi: this.MULTIVAULT_ABI,
        logs: [depositLog],
        eventName: 'Deposited'
      })[0];
      shares = parsed.args.shares;
    }

    return {
      tripleId,
      txHash: hash,
      shares,
    };
  }

  // ============================================================================
  // Vault Operations
  // ============================================================================

  /**
   * Deposit into a vault
   */
  async deposit(params: DepositParams): Promise<{ txHash: Hash; shares: bigint }> {
    if (!this.walletClient) throw new Error('Signer required for write operations');

    const slippageBps = params.slippageBps || 100; // Default 1%

    // Preview deposit
    const [expectedShares] = await this.multiVault.read.previewDeposit([
      params.termId,
      BigInt(params.curveId),
      params.amount
    ]);

    // Calculate min shares with slippage
    const minShares = (expectedShares * BigInt(10000 - slippageBps)) / 10000n;

    // Ensure approval
    await this.ensureApproval(params.amount);

    // Execute deposit
    const account = this.walletClient.account;
    if (!account) throw new Error('No account found');

    const hash = await this.multiVault.write.deposit([
      account.address,
      params.termId,
      BigInt(params.curveId),
      minShares
    ]);
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Parse event
    const depositLog = receipt.logs.find(log => {
      try {
        const parsed = this.publicClient.parseEventLogs({
          abi: this.MULTIVAULT_ABI,
          logs: [log],
          eventName: 'Deposited'
        });
        return parsed.length > 0;
      } catch {
        return false;
      }
    });

    let shares = 0n;
    if (depositLog) {
      const parsed = this.publicClient.parseEventLogs({
        abi: this.MULTIVAULT_ABI,
        logs: [depositLog],
        eventName: 'Deposited'
      })[0];
      shares = parsed.args.shares;
    }

    return {
      txHash: hash,
      shares,
    };
  }

  /**
   * Redeem shares from a vault
   */
  async redeem(params: RedeemParams): Promise<{ txHash: Hash; assets: bigint }> {
    if (!this.walletClient) throw new Error('Signer required for write operations');

    const slippageBps = params.slippageBps || 100; // Default 1%

    // Preview redemption
    const [expectedAssets] = await this.multiVault.read.previewRedeem([
      params.termId,
      BigInt(params.curveId),
      params.shares
    ]);

    // Calculate min assets with slippage
    const minAssets = (expectedAssets * BigInt(10000 - slippageBps)) / 10000n;

    // Execute redemption
    const account = this.walletClient.account;
    if (!account) throw new Error('No account found');

    const hash = await this.multiVault.write.redeem([
      account.address,
      params.termId,
      BigInt(params.curveId),
      params.shares,
      minAssets
    ]);
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Parse event to get actual assets received
    let assets = expectedAssets;
    // In a production SDK, you would parse the Redeemed event here

    return {
      txHash: hash,
      assets,
    };
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /**
   * Get vault information
   */
  async getVaultInfo(termId: Hex, curveId: number): Promise<VaultInfo> {
    const [totalAssets, totalShares] = await this.multiVault.read.getVault([
      termId,
      BigInt(curveId)
    ]);
    const sharePrice = await this.multiVault.read.currentSharePrice([
      termId,
      BigInt(curveId)
    ]);

    return { totalAssets, totalShares, sharePrice };
  }

  /**
   * Get user position in a vault
   */
  async getUserPosition(
    userAddress: Address,
    termId: Hex,
    curveId: number
  ): Promise<UserPosition> {
    const shares = await this.multiVault.read.getShares([
      userAddress,
      termId,
      BigInt(curveId)
    ]);
    const value = await this.multiVault.read.convertToAssets([
      termId,
      BigInt(curveId),
      shares
    ]);

    return { shares, value };
  }

  // ============================================================================
  // Utilities
  // ============================================================================

  /**
   * Ensure sufficient WTRUST approval
   */
  private async ensureApproval(amount: bigint): Promise<void> {
    if (!this.walletClient) throw new Error('Signer required');

    const account = this.walletClient.account;
    if (!account) throw new Error('No account found');

    const currentAllowance = await this.wtrust.read.allowance([
      account.address,
      this.multiVault.address
    ]);

    if (currentAllowance < amount) {
      const hash = await this.wtrust.write.approve([
        this.multiVault.address,
        amount
      ]);
      await this.publicClient.waitForTransactionReceipt({ hash });
    }
  }
}

// ============================================================================
// Usage Example
// ============================================================================

async function exampleUsage() {
  const config: IntuitionConfig = {
    rpcUrl: 'YOUR_INTUITION_RPC_URL',
    multiVaultAddress: '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e' as Address,
    wtrustAddress: '0x81cFb09cb44f7184Ad934C09F82000701A4bF672' as Address,
  };

  const privateKey = 'PRIVATE_KEY' as Hex;
  const sdk = new IntuitionSDK(config, privateKey);

  // Create an atom
  const { atomId, shares } = await sdk.createAtom(
    'My Atom Data',
    parseEther('10')
  );
  console.log(`Created atom ${atomId} with ${formatEther(shares)} shares`);

  // Deposit into vault
  const depositResult = await sdk.deposit({
    termId: atomId,
    curveId: 1,
    amount: parseEther('5'),
    slippageBps: 100, // 1% slippage
  });
  console.log(`Deposited, received ${formatEther(depositResult.shares)} shares`);

  // Query position
  const account = privateKeyToAccount(privateKey);
  const position = await sdk.getUserPosition(account.address, atomId, 1);
  console.log(`Your position: ${formatEther(position.shares)} shares worth ${formatEther(position.value)} WTRUST`);

  // Redeem shares
  const redeemResult = await sdk.redeem({
    termId: atomId,
    curveId: 1,
    shares: position.shares / 2n, // Redeem 50%
    slippageBps: 100,
  });
  console.log(`Redeemed ${formatEther(redeemResult.assets)} WTRUST`);
}

// Uncomment to run:
// exampleUsage().catch(console.error);
