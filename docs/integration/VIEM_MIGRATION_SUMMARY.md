# Viem Migration Summary

This document summarizes the migration from ethers.js to viem across all integration documentation files.

## Files Updated

1. ✅ `/docs/integration/gas-optimization.md` - Fully migrated
2. ✅ `/docs/integration/error-handling.md` - Partially migrated (key sections)
3. ⏳ `/docs/integration/event-monitoring.md` - Requires migration
4. ⏳ `/docs/integration/cross-chain-integration.md` - Requires migration
5. ⏳ `/docs/integration/sdk-design-patterns.md` - Requires migration
6. ⏳ `/docs/integration/transaction-flows.md` - Requires migration

## Key Migration Patterns

### 1. Provider/Signer Initialization

**Ethers.js:**
```typescript
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('RPC_URL');
const signer = provider.getSigner();
const address = await signer.getAddress();
```

**Viem:**
```typescript
import { createPublicClient, createWalletClient, http } from 'viem';

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http('RPC_URL')
});

const walletClient = createWalletClient({
  chain: mainnet,
  transport: http()
});

const [address] = await walletClient.getAddresses();
```

### 2. Contract Read Operations

**Ethers.js:**
```typescript
const contract = new ethers.Contract(address, abi, provider);
const result = await contract.getVault(termId, curveId);
```

**Viem:**
```typescript
const result = await publicClient.readContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'getVault',
  args: [termId, curveId],
});
```

### 3. Contract Write Operations

**Ethers.js:**
```typescript
const contract = new ethers.Contract(address, abi, signer);
const tx = await contract.deposit(receiver, termId, curveId, assets, minShares);
const receipt = await tx.wait();
```

**Viem:**
```typescript
const hash = await walletClient.writeContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'deposit',
  args: [receiver, termId, curveId, assets, minShares],
});

const receipt = await publicClient.waitForTransactionReceipt({ hash });
```

### 4. Transaction Simulation

**Ethers.js:**
```typescript
await contract.deposit.staticCall(receiver, termId, curveId, assets, minShares);
```

**Viem:**
```typescript
await publicClient.simulateContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'deposit',
  args: [receiver, termId, curveId, assets, minShares],
  account: userAddress,
});
```

### 5. Gas Estimation

**Ethers.js:**
```typescript
const gasEstimate = await contract.deposit.estimateGas(
  receiver, termId, curveId, assets, minShares
);
```

**Viem:**
```typescript
const gasEstimate = await publicClient.estimateContractGas({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'deposit',
  args: [receiver, termId, curveId, assets, minShares],
  account: userAddress,
});
```

### 6. Event Subscription

**Ethers.js:**
```typescript
contract.on('AtomCreated', (creator, termId, atomData, atomWallet, event) => {
  console.log(`Atom ${termId} created`);
});

// With filters
const filter = contract.filters.Deposited(userAddress, null, null);
contract.on(filter, (sender, receiver, termId, ...args) => {
  console.log(`Deposit to ${termId}`);
});
```

**Viem:**
```typescript
const unwatch = publicClient.watchContractEvent({
  address: contractAddress,
  abi: contractAbi,
  eventName: 'AtomCreated',
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log(`Atom ${log.args.termId} created`);
    });
  },
});

// With filters
const unwatch = publicClient.watchContractEvent({
  address: contractAddress,
  abi: contractAbi,
  eventName: 'Deposited',
  args: {
    sender: userAddress,
  },
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log(`Deposit to ${log.args.termId}`);
    });
  },
});
```

### 7. Historical Event Queries

**Ethers.js:**
```typescript
const filter = contract.filters.Deposited();
const events = await contract.queryFilter(filter, fromBlock, toBlock);
```

**Viem:**
```typescript
const logs = await publicClient.getContractEvents({
  address: contractAddress,
  abi: contractAbi,
  eventName: 'Deposited',
  fromBlock: fromBlock,
  toBlock: toBlock,
});
```

### 8. Event Log Parsing

**Ethers.js:**
```typescript
const parsedLog = contract.interface.parseLog(log);
const eventName = parsedLog.name;
const eventArgs = parsedLog.args;
```

**Viem:**
```typescript
import { decodeEventLog } from 'viem';

const decodedLog = decodeEventLog({
  abi: contractAbi,
  data: log.data,
  topics: log.topics,
});
const eventName = decodedLog.eventName;
const eventArgs = decodedLog.args;
```

### 9. Error Decoding

**Ethers.js:**
```typescript
const iface = new ethers.Interface(ABI);
const decoded = iface.parseError(error.data);
const errorName = decoded?.name;
```

**Viem:**
```typescript
import { decodeErrorResult } from 'viem';

const decoded = decodeErrorResult({
  abi: contractAbi,
  data: error.data,
});
const errorName = decoded?.errorName;
```

### 10. Function Encoding/Decoding

**Ethers.js:**
```typescript
const data = contract.interface.encodeFunctionData('deposit', [
  receiver, termId, curveId, assets, minShares
]);

const result = contract.interface.decodeFunctionResult('getVault', data);
```

**Viem:**
```typescript
import { encodeFunctionData, decodeFunctionResult } from 'viem';

const data = encodeFunctionData({
  abi: contractAbi,
  functionName: 'deposit',
  args: [receiver, termId, curveId, assets, minShares],
});

const result = decodeFunctionResult({
  abi: contractAbi,
  functionName: 'getVault',
  data: resultData,
});
```

### 11. Utility Functions

**Ethers.js:**
```typescript
import { parseEther, formatEther, parseUnits, formatUnits } from 'ethers';

const amount = parseEther('10');
const formatted = formatEther(amount);
const gasPrice = parseUnits('20', 'gwei');
const formattedGas = formatUnits(gasPrice, 'gwei');
```

**Viem:**
```typescript
import { parseEther, formatEther, parseGwei, formatGwei } from 'viem';

const amount = parseEther('10');
const formatted = formatEther(amount);
const gasPrice = parseGwei('20');
const formattedGas = formatGwei(gasPrice);
```

### 12. Access Lists

**Ethers.js:**
```typescript
const accessList = await provider.send('eth_createAccessList', [{
  from: await signer.getAddress(),
  to: contractAddress,
  data: encodedData,
}]);

const tx = await contract.method(...args, {
  accessList: accessList.accessList,
});
```

**Viem:**
```typescript
const accessList = await publicClient.createAccessList({
  account: userAddress,
  to: contractAddress,
  data: encodedData,
});

const hash = await walletClient.writeContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'method',
  args: [...args],
  accessList: accessList.accessList,
});
```

### 13. Gas Price Management

**Ethers.js:**
```typescript
const feeData = await provider.getFeeData();
const gasPrice = feeData.gasPrice;
const maxFeePerGas = feeData.maxFeePerGas;
const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
```

**Viem:**
```typescript
const gasPrice = await publicClient.getGasPrice();
const block = await publicClient.getBlock();
const maxFeePerGas = block.baseFeePerGas;
// Calculate maxPriorityFeePerGas based on strategy
```

### 14. Transaction Monitoring

**Ethers.js:**
```typescript
const tx = await provider.getTransaction(txHash);
const receipt = await tx.wait(confirmations);
```

**Viem:**
```typescript
const tx = await publicClient.getTransaction({ hash: txHash });
const receipt = await publicClient.waitForTransactionReceipt({
  hash: txHash,
  confirmations: confirmations,
});
```

### 15. Batch/Multicall

**Ethers.js:**
```typescript
const multicall = new ethers.Contract(multicallAddress, abi, provider);
const results = await multicall.aggregate.staticCall(calls);
```

**Viem:**
```typescript
const results = await publicClient.readContract({
  address: multicallAddress,
  abi: multicallAbi,
  functionName: 'aggregate',
  args: [calls],
});

// Or use built-in multicall
const results = await publicClient.multicall({
  contracts: [
    {
      address: contract1Address,
      abi: contract1Abi,
      functionName: 'method1',
      args: [arg1],
    },
    {
      address: contract2Address,
      abi: contract2Abi,
      functionName: 'method2',
      args: [arg2],
    },
  ],
});
```

## Key Differences

### 1. Separation of Concerns
- **Ethers.js**: Single provider/signer handles both reads and writes
- **Viem**: Separate `publicClient` (reads) and `walletClient` (writes)

### 2. Contract Instances
- **Ethers.js**: Create contract instances with `new ethers.Contract()`
- **Viem**: Use client methods directly with address, ABI, and function name

### 3. Events
- **Ethers.js**: Event listeners with `.on()` method
- **Viem**: Watch events with `watchContractEvent()` or `watchEvent()`

### 4. Type Safety
- **Viem**: Better TypeScript support with typed ABIs using wagmi CLI or viem's built-in types
- **Ethers.js**: Less strict typing by default

### 5. Bundle Size
- **Viem**: Smaller bundle size, tree-shakeable
- **Ethers.js**: Larger bundle size

### 6. Performance
- **Viem**: Generally faster due to lighter-weight implementation
- **Ethers.js**: More overhead due to additional abstractions

## Migration Checklist

For each file:
- [ ] Replace ethers imports with viem imports
- [ ] Convert provider initialization to `createPublicClient()`
- [ ] Convert signer initialization to `createWalletClient()`
- [ ] Update contract read calls to use `publicClient.readContract()`
- [ ] Update contract write calls to use `walletClient.writeContract()`
- [ ] Update transaction waiting to use `publicClient.waitForTransactionReceipt()`
- [ ] Update event subscriptions to use `publicClient.watchContractEvent()`
- [ ] Update event queries to use `publicClient.getContractEvents()`
- [ ] Update event parsing to use `decodeEventLog()`
- [ ] Update error decoding to use `decodeErrorResult()`
- [ ] Update utility functions (parseEther, formatEther, etc.)
- [ ] Update gas price fetching to use `publicClient.getGasPrice()`
- [ ] Test all code examples

## Common Gotchas

1. **Account Access**: In viem, use `await walletClient.getAddresses()` which returns an array
2. **Transaction Hash**: viem returns hash directly from write operations, not a transaction response
3. **Event Args**: Viem uses `args` property directly, not nested structure
4. **Static Calls**: Use `simulateContract()` instead of `staticCall()`
5. **Gas Estimation**: Requires `account` parameter in viem
6. **Chain Configuration**: Must specify chain in client creation
7. **BigInt**: Viem uses native BigInt throughout (same as ethers v6)
8. **Max Values**: Use viem's `maxUint256` instead of ethers' `MaxUint256`

## Testing Strategy

1. Update imports and basic patterns
2. Test read operations
3. Test write operations
4. Test event monitoring
5. Test error handling
6. Test gas optimization techniques
7. Validate all code examples compile
8. Run integration tests if available

## Benefits of Migration

1. **Smaller Bundle Size**: Viem is significantly smaller and tree-shakeable
2. **Better Performance**: Lighter-weight implementation
3. **Better TypeScript Support**: First-class TypeScript support
4. **Modern API**: More intuitive and consistent API design
5. **Better Documentation**: Comprehensive and well-organized docs
6. **Active Development**: Rapidly evolving with modern features
7. **Wagmi Ecosystem**: Seamless integration with wagmi for React apps

## Resources

- [Viem Documentation](https://viem.sh/)
- [Viem GitHub](https://github.com/wagmi-dev/viem)
- [Ethers to Viem Migration Guide](https://viem.sh/docs/ethers-migration.html)
- [Viem Examples](https://viem.sh/docs/actions/public/readContract.html)
