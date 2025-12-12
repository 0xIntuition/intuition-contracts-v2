# Troubleshooting

Common issues, error messages, and solutions for integrating with Intuition Protocol V2.

## Transaction Errors

### Error: `MultiVault_InsufficientAllowance`

**Cause:** Contract doesn't have approval to spend your TRUST tokens.

**Solution:**
```typescript
import { maxUint256 } from 'viem';

// Approve sufficient amount
await walletClient.writeContract({
  address: TRUST_ADDRESS,
  abi: TRUST_ABI,
  functionName: 'approve',
  args: [MULTIVAULT_ADDRESS, assets]
});

// Or approve unlimited (use with caution)
await walletClient.writeContract({
  address: TRUST_ADDRESS,
  abi: TRUST_ABI,
  functionName: 'approve',
  args: [MULTIVAULT_ADDRESS, maxUint256]
});

// Then retry deposit
await walletClient.writeContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'deposit',
  args: [termId, curveId, assets, receiver]
});
```

### Error: `Pausable: paused`

**Cause:** Contract is paused due to maintenance or emergency.

**Solution:**
```typescript
// Check pause status
const isPaused = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'paused'
});

if (isPaused) {
  console.log('Contract is paused. Wait for unpause announcement.');
  // Check protocol status page or Discord for updates
}
```

### Error: `MultiVault_AtomExists`

**Cause:** Trying to create an atom that already exists.

**Solution:**
```typescript
// Check if atom exists before creating
const atomId = calculateAtomId(atomData);
const exists = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'atomExists',
  args: [atomId]
});

if (exists) {
  console.log('Atom already exists, use existing atomId');
  // Just deposit into existing vault instead
  await walletClient.writeContract({
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'deposit',
    args: [atomId, curveId, assets, receiver]
  });
} else {
  // Create new atom
  await walletClient.writeContract({
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'createAtom',
    args: [atomData, curveId, initialDeposit]
  });
}
```

### Error: `MultiVault_AtomDoesNotExist`

**Cause:** Trying to operate on an atom that hasn't been created yet.

**Solution:**
```typescript
// Verify atom exists
const exists = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'atomExists',
  args: [atomId]
});

if (!exists) {
  console.log('Atom does not exist. Create it first.');
  await walletClient.writeContract({
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'createAtom',
    args: [atomData, curveId, initialDeposit]
  });
}
```

### Error: `MultiVault_InvalidCurveId`

**Cause:** Using a curveId that hasn't been registered.

**Solution:**
```typescript
import { zeroAddress } from 'viem';

// Get valid curve IDs
const curveAddress = await publicClient.readContract({
  address: BONDING_CURVE_REGISTRY_ADDRESS,
  abi: REGISTRY_ABI,
  functionName: 'getCurve',
  args: [curveId]
});

if (curveAddress === zeroAddress) {
  console.error('Invalid curveId');
  // Use valid curveId (typically 1 for LinearCurve)
  curveId = 1;
}
```

### Error: `MultiVault_InsufficientAssets` / `MultiVault_InsufficientShares`

**Cause:** Amount too small after fees, or insufficient shares to redeem.

**Solution:**
```typescript
// For deposits: Increase amount to cover fees
const minAssets = await calculateMinDeposit(termId, curveId);
if (assets < minAssets) {
  assets = minAssets;
}

// For redemptions: Check available balance
const balance = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'balanceOf',
  args: [user, termId, curveId]
});
if (shares > balance) {
  shares = balance; // Redeem all available
}
```

### Error: `MultiVault_ZeroAmount`

**Cause:** Passing zero for assets or shares parameter.

**Solution:**
```typescript
// Validate amounts before sending transaction
if (assets <= 0n) {
  throw new Error('Amount must be greater than zero');
}
```

### Error: `ReentrancyGuard: reentrant call`

**Cause:** Attempting reentrancy attack or calling from malicious contract.

**Solution:**
This should not happen in normal usage. If you encounter this:
- Review your contract code for reentrancy
- Ensure you're not calling protocol functions in receive/fallback
- Contact support if issue persists

## Query Errors

### Cannot read properties of undefined

**Cause:** Contract not initialized or incorrect address.

**Solution:**
```typescript
// Verify contract address
console.log('MultiVault address:', MULTIVAULT_ADDRESS);

// Ensure provider is connected
const code = await publicClient.getCode({
  address: MULTIVAULT_ADDRESS
});
if (code === '0x') {
  console.error('No contract at address');
  // Verify network and address
}

// Verify contract using readContract
const isPaused = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'paused'
});
```

### Invalid address format

**Cause:** Using incorrect address format or checksum.

**Solution:**
```typescript
import { getAddress, isAddress } from 'viem';

// Validate and format address
if (!isAddress(addressString)) {
  throw new Error('Invalid address format');
}
const validAddress = getAddress(addressString); // Validates checksum

// Or use lowercase
const lowercaseAddress = addressString.toLowerCase();
```

### Network mismatch

**Cause:** Signer connected to different network than contract.

**Solution:**
```typescript
// Check network
const chainId = await publicClient.getChainId();
console.log('Connected to:', chainId);

// Verify expected network
const EXPECTED_CHAIN_ID = 8453; // Base Mainnet
if (chainId !== EXPECTED_CHAIN_ID) {
  throw new Error(`Wrong network. Expected ${EXPECTED_CHAIN_ID}, got ${chainId}`);
}
```

## Calculation Issues

### Share amount is less than expected

**Cause:** Fees, entry fees, or bonding curve pricing.

**Solution:**
```typescript
import { formatEther } from 'viem';

// Preview deposit to see exact shares
const previewedShares = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'previewDeposit',
  args: [termId, curveId, assets]
});
console.log('Expected shares:', formatEther(previewedShares));

// Account for fees in calculation
const fees = await calculateTotalFees(assets, termId, curveId);
const assetsAfterFees = assets - fees;
const shares = await calculateShares(assetsAfterFees, termId, curveId);
```

### Assets received less than expected on redemption

**Cause:** Exit fees, protocol fees, or price movement.

**Solution:**
```typescript
import { formatEther } from 'viem';

// Preview redemption
const previewedAssets = await publicClient.readContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'previewRedeem',
  args: [termId, curveId, shares]
});
console.log('Expected assets:', formatEther(previewedAssets));

// Set minimum acceptable (slippage tolerance)
const minAssets = previewedAssets * 95n / 100n; // 5% slippage

// Validate after redemption
if (receivedAssets < minAssets) {
  console.warn('High slippage detected');
}
```

### Reward calculation seems wrong

**Cause:** Utilization ratios, bonded balance, or epoch timing.

**Solution:**
```typescript
import { formatEther } from 'viem';

// Check all reward factors
const userInfo = await publicClient.readContract({
  address: TRUSTBONDING_ADDRESS,
  abi: TRUSTBONDING_ABI,
  functionName: 'getUserInfo',
  args: [userAddress, epochId]
});

console.log('User Info:');
console.log('  Personal Utilization:', userInfo.personalUtilization);
console.log('  Eligible Rewards:', formatEther(userInfo.eligibleRewards));
console.log('  Max Rewards:', formatEther(userInfo.maxRewards));
console.log('  Bonded Balance:', formatEther(userInfo.bondedBalance));

// Check epoch info
const epochInfo = await publicClient.readContract({
  address: TRUSTBONDING_ADDRESS,
  abi: TRUSTBONDING_ABI,
  functionName: 'epochInfo',
  args: [epochId]
});
console.log('Epoch Info:');
console.log('  Total Bonded:', formatEther(epochInfo.totalBonded));
console.log('  Total Utilization:', epochInfo.totalUtilization);
```

## Event Listening Issues

### Events not being received

**Cause:** Filter not set up correctly or connection issues.

**Solution:**
```typescript
```typescript
import { parseAbiItem, formatEther } from 'viem';

// Set up event watching
const unwatch = publicClient.watchEvent({
  address: MULTIVAULT_ADDRESS,
  event: parseAbiItem('event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 shares)'),
  args: {
    receiver: userAddress // Filter by specific receiver
  },
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('Deposit event:', {
        sender: log.args.sender,
        receiver: log.args.receiver,
        termId: log.args.termId,
        curveId: log.args.curveId,
        assets: formatEther(log.args.assets),
        shares: formatEther(log.args.shares),
        txHash: log.transactionHash
      });
    });
  }
});

// Or query historical events
const logs = await publicClient.getLogs({
  address: MULTIVAULT_ADDRESS,
  event: parseAbiItem('event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 shares)'),
  fromBlock: 'earliest',
  toBlock: 'latest'
});
console.log('Found', logs.length, 'events');
```


### Missing recent events

**Cause:** Provider not synced or block delay.

**Solution:**
```typescript
import { decodeEventLog } from 'viem';

// Wait for transaction to be mined
const hash = await walletClient.writeContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'deposit',
  args: [termId, curveId, assets, receiver]
});
const receipt = await publicClient.waitForTransactionReceipt({ hash });

// Get events from receipt
const depositEvents = receipt.logs
  .map(log => {
    try {
      return decodeEventLog({
        abi: MULTIVAULT_ABI,
        data: log.data,
        topics: log.topics
      });
    } catch {
      return null;
    }
  })
  .filter(event => event && event.eventName === 'Deposited');

console.log('Deposit events:', depositEvents);
```

## Integration Issues

### Rate limiting from RPC provider

**Cause:** Too many requests to RPC endpoint.

**Solution:**
```typescript
import { encodeFunctionData } from 'viem';

// Use batch requests with multicall
const calls = [
  {
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'balanceOf',
    args: [user, termId1, curveId]
  },
  {
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'balanceOf',
    args: [user, termId2, curveId]
  }
];

const results = await publicClient.multicall({
  contracts: calls
});

// Add delay between requests
async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

for (const item of items) {
  await processItem(item);
  await sleep(100); // 100ms delay
}
```

### Nonce too low / transaction replacement

**Cause:** Multiple transactions sent with same nonce.

**Solution:**
```typescript
// Get correct nonce
const nonce = await publicClient.getTransactionCount({
  address: account.address
});

// Send transaction with explicit nonce
const hash = await walletClient.writeContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'deposit',
  args: [termId, curveId, assets, receiver],
  nonce: nonce
});

// For replacement, increase gas price
const replacementHash = await walletClient.sendTransaction({
  ...originalTx,
  nonce: originalTx.nonce,
  gasPrice: originalTx.gasPrice * 110n / 100n // 10% higher
});
```

### Gas estimation fails

**Cause:** Transaction will revert, or gas limit too low.

**Solution:**
```typescript
try {
  // Estimate gas
  const estimatedGas = await publicClient.estimateContractGas({
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'deposit',
    args: [termId, curveId, assets, receiver],
    account
  });

  console.log('Estimated gas:', estimatedGas.toString());

  // Add buffer (10%)
  const gasLimit = estimatedGas * 110n / 100n;

  // Send with gas limit
  const hash = await walletClient.writeContract({
    address: MULTIVAULT_ADDRESS,
    abi: MULTIVAULT_ABI,
    functionName: 'deposit',
    args: [termId, curveId, assets, receiver],
    gas: gasLimit
  });
} catch (error) {
  console.error('Gas estimation failed. Transaction would revert.');
  console.error('Error:', error.message);

  // Simulate to see revert reason
  try {
    await publicClient.simulateContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      functionName: 'deposit',
      args: [termId, curveId, assets, receiver],
      account
    });
  } catch (revertError) {
    console.error('Revert reason:', revertError.message);
  }
}
```

## Testing Issues

### Fork tests failing

**Cause:** State mismatch or outdated fork.

**Solution:**
```bash
# Update fork to latest block
anvil --fork-url $RPC_URL --fork-block-number latest

# Or specific block
anvil --fork-url $RPC_URL --fork-block-number 12345678

# Reset fork state
# Stop and restart anvil
```

### Test passes locally but fails in CI

**Cause:** Timing issues, different RPC, or environment variables.

**Solution:**
```typescript
// Use deterministic testing
beforeEach(async () => {
  // Reset to known state
  await network.provider.request({
    method: "hardhat_reset",
    params: [{
      forking: {
        jsonRpcUrl: process.env.RPC_URL,
        blockNumber: FORK_BLOCK_NUMBER
      }
    }]
  });
});

// Increase timeout for CI
it('should deposit', async function() {
  this.timeout(30000); // 30 seconds
  // test code
});
```

### Cannot impersonate account on fork

**Cause:** Insufficient balance or wrong network.

**Solution:**
```typescript
// Impersonate account
await network.provider.request({
  method: "hardhat_impersonateAccount",
  params: [accountAddress]
});

// Fund account with ETH
await network.provider.send("hardhat_setBalance", [
  accountAddress,
  numberToHex(parseEther("10"))
]);

// Use impersonated signer
const impersonatedSigner = await ethers.getSigner(accountAddress);
```

## Deployment Issues

### Contract verification fails

**Cause:** Constructor arguments mismatch or compiler settings.

**Solution:**
```bash
# Verify with exact compiler settings
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/protocol/MultiVault.sol:MultiVault \
  --chain-id 8453 \
  --num-of-optimizations 10000 \
  --compiler-version 0.8.29 \
  --etherscan-api-key $ETHERSCAN_API_KEY

# For constructors with arguments
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/Contract.sol:Contract \
  --constructor-args $(cast abi-encode "constructor(address,uint256)" $ARG1 $ARG2) \
  --chain-id 8453 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Proxy upgrade fails

**Cause:** Storage layout incompatibility or wrong ProxyAdmin owner.

**Solution:**
```bash
# Check storage layout
forge inspect MultiVaultV1 storageLayout > v1.json
forge inspect MultiVaultV2 storageLayout > v2.json
diff v1.json v2.json

# Verify ProxyAdmin owner
cast call $PROXY_ADMIN_ADDRESS "owner()(address)" --rpc-url $RPC_URL

# If owner is Timelock, use Timelock schedule/execute
```

## Performance Issues

### Transaction taking too long

**Cause:** Low gas price or network congestion.

**Solution:**
```typescript
import { formatGwei } from 'viem';

// Check current gas price
const gasPrice = await publicClient.getGasPrice();
console.log('Current gas price:', formatGwei(gasPrice), 'gwei');

// Increase gas price
const hash = await walletClient.writeContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'deposit',
  args: [termId, curveId, assets, receiver],
  gasPrice: gasPrice * 120n / 100n // 20% higher
});

// Or use EIP-1559
const block = await publicClient.getBlock();
const baseFee = block.baseFeePerGas || 0n;
const maxPriorityFee = parseGwei('2'); // 2 gwei priority

const hash = await walletClient.writeContract({
  address: MULTIVAULT_ADDRESS,
  abi: MULTIVAULT_ABI,
  functionName: 'deposit',
  args: [termId, curveId, assets, receiver],
  maxFeePerGas: baseFee * 120n / 100n + maxPriorityFee,
  maxPriorityFeePerGas: maxPriorityFee
});
```

### Subgraph indexing slow

**Cause:** Too many events or slow graph node.

**Solution:**
```graphql
# Query with pagination
query {
  deposits(first: 100, skip: 0, orderBy: timestamp, orderDirection: desc) {
    id
    termId
    assets
    shares
  }
}

# Use specific block range
query {
  deposits(
    where: {
      blockNumber_gte: 12345678
      blockNumber_lte: 12346678
    }
  ) {
    id
    termId
  }
}
```

## Debugging Tools

### View transaction trace

```bash
# Using cast
cast run $TX_HASH --rpc-url $RPC_URL --verbose

# Using tenderly
tenderly tx $CHAIN_NAME $TX_HASH
```

### Decode transaction input

```bash
# Decode calldata
cast 4byte-decode $CALLDATA

# Or use etherscan's "Decode Input Data" feature
```

### Check contract storage

```bash
# Read storage slot
cast storage $CONTRACT_ADDRESS $SLOT --rpc-url $RPC_URL

# Get storage layout
forge inspect MultiVault storageLayout
```

### Simulate transaction

```bash
# Using cast
cast call $CONTRACT_ADDRESS "deposit(bytes32,uint256,uint256,address)" \
  $TERM_ID $CURVE_ID $ASSETS $RECEIVER \
  --from $USER_ADDRESS \
  --rpc-url $RPC_URL

# Using Tenderly
# Use Tenderly dashboard to simulate
```

## Getting Help

If you're still stuck after trying these solutions:

1. **Check Documentation**: Review relevant sections
2. **Search GitHub Issues**: Someone may have encountered the same issue
3. **Ask in Discord**: [discord.gg/intuition](https://discord.gg/intuition)
4. **Open GitHub Issue**: [github.com/0xIntuition/intuition-contracts-v2/issues](https://github.com/0xIntuition/intuition-contracts-v2/issues)

When asking for help, include:
- Error message (full text)
- Transaction hash (if applicable)
- Code snippet
- Network (mainnet/testnet)
- What you've already tried

## See Also

- [FAQ](./faq.md) - Frequently asked questions
- [Error Reference](../reference/errors.md) - All custom errors
- [Security Considerations](../advanced/security-considerations.md) - Security best practices

---

**Last Updated**: December 2025
