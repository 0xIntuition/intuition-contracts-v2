# Ethers.js to Viem Migration Summary

## Overview

All ethers.js code in the advanced documentation directory has been replaced with viem equivalents. This document summarizes the key migration patterns applied across all files.

## Files Updated

1. `/docs/advanced/emergency-procedures.md` - COMPLETED
2. `/docs/advanced/upgradeability.md` - COMPLETED
3. `/docs/advanced/access-control.md` - COMPLETED
4. `/docs/advanced/timelock-governance.md` - IN PROGRESS (requires completion)
5. `/docs/advanced/migration-mode.md` - PENDING
6. `/docs/advanced/security-considerations.md` - PENDING

## Key Migration Patterns Applied

### 1. Import Statements

**Before (ethers.js):**
```typescript
import { ethers } from 'ethers';
```

**After (viem):**
```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { encodeFunctionData, keccak256, toHex } from 'viem';
```

### 2. Provider/Client Creation

**Before (ethers.js):**
```typescript
const provider = new ethers.JsonRpcProvider(RPC_URL);
```

**After (viem):**
```typescript
const publicClient = createPublicClient({
  chain,
  transport: http(RPC_URL)
});
```

### 3. Signer/Account Setup

**Before (ethers.js):**
```typescript
const signer = new ethers.Wallet(PRIVATE_KEY, provider);
```

**After (viem):**
```typescript
const account = privateKeyToAccount(PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain,
  transport: http()
});
```

### 4. Contract Read Operations

**Before (ethers.js):**
```typescript
const contract = new ethers.Contract(ADDRESS, ABI, provider);
const result = await contract.functionName(args);
```

**After (viem):**
```typescript
const result = await publicClient.readContract({
  address: ADDRESS,
  abi: ABI,
  functionName: 'functionName',
  args: [args]
});
```

### 5. Contract Write Operations

**Before (ethers.js):**
```typescript
const contract = new ethers.Contract(ADDRESS, ABI, signer);
const tx = await contract.functionName(args);
await tx.wait();
```

**After (viem):**
```typescript
const hash = await walletClient.writeContract({
  address: ADDRESS,
  abi: ABI,
  functionName: 'functionName',
  args: [args]
});

await publicClient.waitForTransactionReceipt({ hash });
```

### 6. Encoding Function Data

**Before (ethers.js):**
```typescript
const data = contract.interface.encodeFunctionData('functionName', [args]);
```

**After (viem):**
```typescript
const data = encodeFunctionData({
  abi: ABI,
  functionName: 'functionName',
  args: [args]
});
```

### 7. Event Listening (Real-time)

**Before (ethers.js):**
```typescript
contract.on('EventName', (arg1, arg2, event) => {
  console.log('Event:', arg1, arg2);
  console.log('TxHash:', event.transactionHash);
});
```

**After (viem):**
```typescript
const unwatch = publicClient.watchContractEvent({
  address: ADDRESS,
  abi: ABI,
  eventName: 'EventName',
  onLogs: (logs) => {
    for (const log of logs) {
      console.log('Event:', log.args.arg1, log.args.arg2);
      console.log('TxHash:', log.transactionHash);
    }
  }
});
```

### 8. Event Querying (Historical)

**Before (ethers.js):**
```typescript
const filter = contract.filters.EventName();
const events = await contract.queryFilter(filter, fromBlock, toBlock);
```

**After (viem):**
```typescript
const events = await publicClient.getContractEvents({
  address: ADDRESS,
  abi: ABI,
  eventName: 'EventName',
  fromBlock: fromBlock,
  toBlock: toBlock
});
```

### 9. Block Number Watching

**Before (ethers.js):**
```typescript
provider.on('block', async (blockNumber) => {
  await checkBlock(blockNumber);
});
```

**After (viem):**
```typescript
const unwatch = publicClient.watchBlockNumber({
  onBlockNumber: async (blockNumber) => {
    await checkBlock(blockNumber);
  }
});
```

### 10. Transaction Receipt Retrieval

**Before (ethers.js):**
```typescript
const tx = await contract.method();
const receipt = await tx.wait();
console.log('Block:', receipt.blockNumber);
```

**After (viem):**
```typescript
const hash = await walletClient.writeContract({...});
const receipt = await publicClient.waitForTransactionReceipt({ hash });
console.log('Block:', receipt.blockNumber);
```

### 11. Hashing

**Before (ethers.js):**
```typescript
import { keccak256 } from 'ethers';
const hash = keccak256('string');
```

**After (viem):**
```typescript
import { keccak256, toHex } from 'viem';
const hash = keccak256(toHex('string'));
```

### 12. BigInt Handling

**Before (ethers.js):**
```typescript
const value = 0; // number
const bigValue = ethers.parseEther('1.0');
```

**After (viem):**
```typescript
const value = 0n; // BigInt literal
const bigValue = parseEther('1.0'); // from viem
```

## Completed Files

### emergency-procedures.md
- ✅ All ethers.js imports replaced with viem
- ✅ EmergencyMonitor class updated to use watchContractEvent
- ✅ Health check functions updated to use readContract
- ✅ Pause/unpause operations converted to writeContract pattern
- ✅ Event querying updated to getContractEvents

### upgradeability.md
- ✅ Timelock scheduling operations updated
- ✅ Proxy admin interactions converted
- ✅ Beacon upgrade patterns updated
- ✅ Event monitoring converted to watchContractEvent
- ✅ Post-upgrade verification updated

### access-control.md
- ✅ Role checking converted to readContract
- ✅ Role granting/revoking updated to writeContract
- ✅ Event monitoring for role changes converted
- ✅ Batch operations updated
- ✅ Role member queries converted to getContractEvents

## Remaining Work

### timelock-governance.md
**Status:** Partially complete (need to finish remaining sections)

Sections to update:
- [ ] Basic schedule operations
- [ ] Batch scheduling
- [ ] Execute operations
- [ ] Cancel operations
- [ ] Event monitoring
- [ ] Query pending operations

### migration-mode.md
**Status:** Not started

Sections to update:
- [ ] Data extraction from V1
- [ ] Migration batch operations
- [ ] Funding migration mode
- [ ] Event monitoring during migration
- [ ] Validation functions

### security-considerations.md
**Status:** Minimal updates needed (mostly conceptual content)

Sections to update:
- [ ] Integration security examples
- [ ] Monitoring examples
- [ ] Error handling patterns

## Testing

After completing the migration, ensure:
- [ ] All code examples use consistent viem patterns
- [ ] BigInt literals (0n) used for value parameters
- [ ] Proper error handling for all async operations
- [ ] Event watching patterns include unwatch cleanup
- [ ] All imports are from viem, not ethers

## Notes

1. **Chain Configuration**: All examples assume a `chain` constant is defined (e.g., from 'viem/chains')
2. **Type Safety**: Viem provides better TypeScript support - ensure ABIs are properly typed
3. **Performance**: Viem is generally more lightweight than ethers.js
4. **Breaking Changes**: This is a major migration - all documentation users must update their code

## Next Steps

1. Complete timelock-governance.md updates
2. Complete migration-mode.md updates
3. Complete security-considerations.md updates
4. Review all files for consistency
5. Test all code examples
6. Update any related documentation that references these files
