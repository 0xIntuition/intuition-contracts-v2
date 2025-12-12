# Timelock Governance

Comprehensive guide to timelock mechanisms, governance procedures, and delayed execution patterns in Intuition Protocol V2.

## Overview

Intuition Protocol V2 uses OpenZeppelin's TimelockController to enforce delays between proposal and execution of critical operations. This provides transparency, allows community review, and enables emergency response before changes take effect.

## Architecture

### Timelock Instances

The protocol deploys multiple TimelockController instances for different purposes:

#### 1. Upgrades TimelockController (Base Chain)

Controls upgrades to the BaseEmissionsController.

**Mainnet:**
- Address: `0x1E442BbB08c98100b18fa830a88E8A57b5dF9157`
- Purpose: BaseEmissionsController upgrades
- Minimum Delay: 48-72 hours (configurable)

**Testnet:**
- Address: `0x9099BC9fd63B01F94528B60CEEB336C679eb6d52`

**Controlled Contracts:**
- BaseEmissionsController (ProxyAdmin owner)
- Trust token upgrades

#### 2. Upgrades TimelockController (Satellite Chain)

Controls upgrades to MultiVault and emissions contracts.

**Mainnet:**
- Address: `0x321e5d4b20158648dFd1f360A79CAFc97190bAd1`
- Purpose: Protocol contract upgrades
- Minimum Delay: 48-72 hours (configurable)

**Testnet:**
- Address: `0x59B7EaB1cFA47F8E61606aDf79a6b7B5bBF1aF26`

**Controlled Contracts:**
- MultiVault (ProxyAdmin owner)
- SatelliteEmissionsController (ProxyAdmin owner)
- TrustBonding (ProxyAdmin owner)
- AtomWarden (ProxyAdmin owner)
- AtomWalletFactory (ProxyAdmin owner)
- BondingCurveRegistry (ProxyAdmin owner)
- All curve implementations

#### 3. Parameters TimelockController (Satellite Chain)

Controls protocol parameter changes without upgrade requirements.

**Mainnet:**
- Address: `0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA`
- Purpose: Parameter adjustments
- Minimum Delay: 24-48 hours (shorter than upgrades)

**Testnet:**
- Address: `0xcCB113bfFf493d80F32Fb799Dca23686a04302A7`

**Controlled Operations:**
- Fee adjustments
- Economic parameter changes
- Non-critical configurations

### Role Structure

```
TimelockController
    ├── TIMELOCK_ADMIN_ROLE (address(this))
    │   └── Can manage roles within timelock
    │
    ├── PROPOSER_ROLE
    │   └── Can schedule operations
    │
    ├── EXECUTOR_ROLE
    │   └── Can execute after delay
    │
    └── CANCELLER_ROLE
        └── Can cancel pending operations
```

## Core Concepts

### Operation Lifecycle

```mermaid
graph LR
    A[Proposal] -->|schedule| B[Pending]
    B -->|wait delay| C[Ready]
    C -->|execute| D[Done]
    B -->|cancel| E[Cancelled]
```

### Operation Structure

Each operation is identified by a unique ID computed from its parameters:

```solidity
struct Operation {
    address target;        // Contract to call
    uint256 value;         // ETH value to send
    bytes data;            // Encoded function call
    bytes32 predecessor;   // Required prior operation
    bytes32 salt;          // Unique identifier
    uint256 delay;         // Minimum wait time
}
```

### Operation ID

```solidity
operationId = keccak256(
    abi.encode(target, value, data, predecessor, salt)
);
```

## Scheduling Operations

### Basic Schedule

```typescript
import { createPublicClient, createWalletClient, http, encodeFunctionData, parseEther, keccak256, zeroHash } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

const account = privateKeyToAccount(PROPOSER_PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http()
});

const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

// Prepare operation
const target = MULTIVAULT_ADDRESS;
const value = 0n;
const data = encodeFunctionData({
  abi: MULTIVAULT_ABI,
  functionName: 'setAtomCost',
  args: [parseEther('1')]
});
const predecessor = zeroHash; // No dependency
const salt = keccak256('0x7365742d61746f6d2d636f73742d7631'); // 'set-atom-cost-v1'
const delay = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'getMinDelay'
});

// Schedule operation
const hash = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'schedule',
  args: [target, value, data, predecessor, salt, delay]
});

await publicClient.waitForTransactionReceipt({ hash });
console.log('Operation scheduled:', hash);

// Compute operation ID for tracking
const operationId = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'hashOperation',
  args: [target, value, data, predecessor, salt]
});
console.log('Operation ID:', operationId);
```

### Schedule with Batch

```typescript
// Schedule multiple operations atomically
const targets = [CONTRACT_A, CONTRACT_B, CONTRACT_C];
const values = [0n, 0n, 0n];
const datas = [
  encodeFunctionData({
    abi: CONTRACT_A_ABI,
    functionName: 'functionA',
    args: [param1]
  }),
  encodeFunctionData({
    abi: CONTRACT_B_ABI,
    functionName: 'functionB',
    args: [param2]
  }),
  encodeFunctionData({
    abi: CONTRACT_C_ABI,
    functionName: 'functionC',
    args: [param3]
  })
];

const hash = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'scheduleBatch',
  args: [targets, values, datas, predecessor, salt, delay]
});

await publicClient.waitForTransactionReceipt({ hash });
console.log('Batch scheduled');
```

### Schedule with Predecessor

Create dependencies between operations:

```typescript
// Operation 1: Deploy new implementation
const operation1Salt = keccak256('0x6465706c6f792d696d706c2d7632'); // 'deploy-impl-v2'
const deployData = /* ... */;

const hash1 = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'schedule',
  args: [DEPLOYER_ADDRESS, 0n, deployData, zeroHash, operation1Salt, delay]
});
await publicClient.waitForTransactionReceipt({ hash: hash1 });

const operation1Id = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'hashOperation',
  args: [DEPLOYER_ADDRESS, 0n, deployData, zeroHash, operation1Salt]
});

// Operation 2: Upgrade to new implementation (depends on operation 1)
const upgradeData = encodeFunctionData({
  abi: PROXY_ADMIN_ABI,
  functionName: 'upgrade',
  args: [PROXY_ADDRESS, NEW_IMPL_ADDRESS]
});

const hash2 = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'schedule',
  args: [
    PROXY_ADMIN_ADDRESS,
    0n,
    upgradeData,
    operation1Id, // Must execute after operation 1
    keccak256('0x757067726164652d746f2d7632'), // 'upgrade-to-v2'
    delay
  ]
});
await publicClient.waitForTransactionReceipt({ hash: hash2 });
```

## Executing Operations

### Check Readiness

```typescript
const operationId = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'hashOperation',
  args: [target, value, data, predecessor, salt]
});

// Check operation state
const isScheduled = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperation',
  args: [operationId]
});

const isReady = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperationReady',
  args: [operationId]
});

const isPending = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperationPending',
  args: [operationId]
});

const isDone = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperationDone',
  args: [operationId]
});

console.log('Scheduled:', isScheduled);
console.log('Ready to execute:', isReady);
console.log('Pending:', isPending);
console.log('Already executed:', isDone);

// Get timestamp when ready
const timestamp = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'getTimestamp',
  args: [operationId]
});

const now = Math.floor(Date.now() / 1000);
const secondsRemaining = Number(timestamp) - now;

if (secondsRemaining > 0) {
  console.log(`Operation ready in ${secondsRemaining} seconds`);
} else {
  console.log('Operation ready for execution');
}
```

### Execute Operation

```typescript
// Must wait for delay to pass
const account = privateKeyToAccount(EXECUTOR_PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http()
});

const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

const hash = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'execute',
  args: [target, value, data, predecessor, salt]
});

const receipt = await publicClient.waitForTransactionReceipt({ hash });
console.log('Operation executed:', receipt.transactionHash);

// Verify execution
const isDone = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperationDone',
  args: [operationId]
});
console.log('Operation completed:', isDone);
```

### Execute Batch

```typescript
const hash = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'executeBatch',
  args: [targets, values, datas, predecessor, salt]
});

await publicClient.waitForTransactionReceipt({ hash });
console.log('Batch executed');
```

## Cancelling Operations

### Cancel Single Operation

```typescript
const account = privateKeyToAccount(CANCELLER_PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http()
});

const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

const hash = await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'cancel',
  args: [operationId]
});
await publicClient.waitForTransactionReceipt({ hash });

console.log('Operation cancelled');

// Verify cancellation
const isScheduled = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'isOperation',
  args: [operationId]
});
console.log('Still scheduled:', isScheduled); // Should be false
```

### Emergency Cancellation

```typescript
// Quick cancellation in emergency
async function emergencyCancel(operationId: string, reason: string) {
  console.log(`EMERGENCY CANCEL: ${reason}`);

  const account = privateKeyToAccount(EMERGENCY_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'cancel',
    args: [operationId]
  });
  await publicClient.waitForTransactionReceipt({ hash });

  // Send alerts
  await sendAlert({
    type: 'OPERATION_CANCELLED',
    operationId,
    reason,
    timestamp: Date.now()
  });

  console.log('Operation cancelled, alerts sent');
}
```

## Common Patterns

### Contract Upgrade via Timelock

Complete workflow for upgrading a contract:

```typescript
import { createPublicClient, createWalletClient, http, encodeFunctionData, keccak256, toHex, zeroHash } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

async function scheduleContractUpgrade(
  proxyAddress: `0x${string}`,
  newImplementation: `0x${string}`,
  initData: `0x${string}` = '0x'
) {
  const account = privateKeyToAccount(PROPOSER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // 1. Prepare upgrade calldata
  const upgradeCalldata = encodeFunctionData({
    abi: PROXY_ADMIN_ABI,
    functionName: 'upgradeAndCall',
    args: [proxyAddress, newImplementation, initData]
  });

  // 2. Generate unique salt
  const salt = keccak256(toHex(`upgrade-${proxyAddress}-${Date.now()}`));

  // 3. Schedule operation
  const delay = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getMinDelay'
  });

  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [PROXY_ADMIN_ADDRESS, 0n, upgradeCalldata, zeroHash, salt, delay]
  });

  await publicClient.waitForTransactionReceipt({ hash });

  // 4. Compute operation ID
  const operationId = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'hashOperation',
    args: [PROXY_ADMIN_ADDRESS, 0n, upgradeCalldata, zeroHash, salt]
  });

  // 5. Get execution timestamp
  const timestamp = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getTimestamp',
    args: [operationId]
  });
  const readyDate = new Date(Number(timestamp) * 1000);

  console.log('Upgrade scheduled');
  console.log('Operation ID:', operationId);
  console.log('Ready for execution:', readyDate.toISOString());
  console.log('Proxy:', proxyAddress);
  console.log('New Implementation:', newImplementation);

  return {
    operationId,
    timestamp,
    salt,
    proxyAddress,
    newImplementation
  };
}

async function executeContractUpgrade(operationInfo: any) {
  const account = privateKeyToAccount(EXECUTOR_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // 1. Verify ready
  const isReady = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'isOperationReady',
    args: [operationInfo.operationId]
  });

  if (!isReady) {
    throw new Error('Operation not ready yet');
  }

  // 2. Reconstruct upgrade calldata
  const upgradeCalldata = encodeFunctionData({
    abi: PROXY_ADMIN_ABI,
    functionName: 'upgradeAndCall',
    args: [operationInfo.proxyAddress, operationInfo.newImplementation, '0x']
  });

  // 3. Execute
  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'execute',
    args: [PROXY_ADMIN_ADDRESS, 0n, upgradeCalldata, zeroHash, operationInfo.salt]
  });

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log('Upgrade executed:', receipt.transactionHash);

  // 4. Verify
  const currentImpl = await publicClient.readContract({
    address: PROXY_ADMIN_ADDRESS,
    abi: PROXY_ADMIN_ABI,
    functionName: 'getProxyImplementation',
    args: [operationInfo.proxyAddress]
  });
  console.log('Current implementation:', currentImpl);
  console.log('Upgrade successful:', currentImpl === operationInfo.newImplementation);

  return receipt;
}
```

### Parameter Update via Timelock

```typescript
async function scheduleParameterUpdate(
  contractAddress: `0x${string}`,
  functionName: string,
  params: any[]
) {
  const account = privateKeyToAccount(PROPOSER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Encode function call
  const data = encodeFunctionData({
    abi: CONTRACT_ABI,
    functionName,
    args: params
  });

  // Schedule with shorter delay (parameters timelock)
  const salt = keccak256(toHex(`param-${functionName}-${Date.now()}`));
  const delay = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getMinDelay'
  });

  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [contractAddress, 0n, data, zeroHash, salt, delay]
  });

  await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Parameter update scheduled: ${functionName}`);

  return await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'hashOperation',
    args: [contractAddress, 0n, data, zeroHash, salt]
  });
}
```

### Multi-Step Upgrade with Dependencies

```typescript
async function scheduleComplexUpgrade() {
  const account = privateKeyToAccount(PROPOSER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  const delay = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getMinDelay'
  });

  // Step 1: Pause contracts
  const pauseData = encodeFunctionData({
    abi: MULTIVAULT_ABI,
    functionName: 'pause'
  });
  const pauseSalt = keccak256('0x757067726164652d7061757365'); // 'upgrade-pause'

  const pauseHash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [MULTIVAULT_ADDRESS, 0n, pauseData, zeroHash, pauseSalt, delay]
  });
  await publicClient.waitForTransactionReceipt({ hash: pauseHash });

  const pauseId = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'hashOperation',
    args: [MULTIVAULT_ADDRESS, 0n, pauseData, zeroHash, pauseSalt]
  });

  // Step 2: Upgrade (depends on pause)
  const upgradeData = encodeFunctionData({
    abi: PROXY_ADMIN_ABI,
    functionName: 'upgrade',
    args: [MULTIVAULT_ADDRESS, NEW_IMPLEMENTATION]
  });
  const upgradeSalt = keccak256('0x757067726164652d696d706c'); // 'upgrade-impl'

  const upgradeHash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [PROXY_ADMIN_ADDRESS, 0n, upgradeData, pauseId, upgradeSalt, delay]
  });
  await publicClient.waitForTransactionReceipt({ hash: upgradeHash });

  const upgradeId = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'hashOperation',
    args: [PROXY_ADMIN_ADDRESS, 0n, upgradeData, pauseId, upgradeSalt]
  });

  // Step 3: Unpause (depends on upgrade)
  const unpauseData = encodeFunctionData({
    abi: MULTIVAULT_ABI,
    functionName: 'unpause'
  });
  const unpauseSalt = keccak256('0x757067726164652d756e7061757365'); // 'upgrade-unpause'

  const unpauseHash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [MULTIVAULT_ADDRESS, 0n, unpauseData, upgradeId, unpauseSalt, delay]
  });
  await publicClient.waitForTransactionReceipt({ hash: unpauseHash });

  console.log('Multi-step upgrade scheduled');
  console.log('Steps: pause -> upgrade -> unpause');
}
```

## Timelock Administration

### Update Minimum Delay

```typescript
// Generate calldata for updating delay
async function scheduleDelayUpdate(newDelay: bigint) {
  const account = privateKeyToAccount(PROPOSER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Timelock calls itself to update delay
  const data = encodeFunctionData({
    abi: TIMELOCK_ABI,
    functionName: 'updateDelay',
    args: [newDelay]
  });

  const salt = keccak256(toHex(`update-delay-${newDelay}`));
  const currentDelay = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getMinDelay'
  });

  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [TIMELOCK_ADDRESS, 0n, data, zeroHash, salt, currentDelay]
  });

  await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Delay update scheduled: ${currentDelay}s -> ${newDelay}s`);
}
```

**Utility Script:**
```bash
# Generate timelock delay update calldata
npx tsx script/upgrades/generate-timelock-update-delay-calldata.ts \
  "https://mainnet.base.org" \
  259200 # 3 days in seconds
```

### Grant/Revoke Roles

```typescript
// Grant proposer role
async function grantProposerRole(targetAccount: `0x${string}`) {
  const account = privateKeyToAccount(ADMIN_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  const PROPOSER_ROLE = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'PROPOSER_ROLE'
  });

  // Schedule role grant (timelock grants to itself)
  const data = encodeFunctionData({
    abi: TIMELOCK_ABI,
    functionName: 'grantRole',
    args: [PROPOSER_ROLE, targetAccount]
  });

  const salt = keccak256(toHex(`grant-proposer-${targetAccount}`));
  const delay = await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'getMinDelay'
  });

  const hash = await walletClient.writeContract({
    address: TIMELOCK_ADDRESS,
    abi: TIMELOCK_ABI,
    functionName: 'schedule',
    args: [TIMELOCK_ADDRESS, 0n, data, zeroHash, salt, delay]
  });

  await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Proposer role grant scheduled for ${targetAccount}`);
}
```

## Monitoring and Events

### Listen for Scheduled Operations

```typescript
const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

// Monitor CallScheduled events
const unwatchScheduled = publicClient.watchEvent({
  address: TIMELOCK_ADDRESS,
  event: parseAbiItem('event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)'),
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('Operation scheduled:');
      console.log('  ID:', log.args.id);
      console.log('  Target:', log.args.target);
      console.log('  Delay:', log.args.delay.toString(), 'seconds');
      console.log('  Ready at:', new Date((Date.now() + Number(log.args.delay) * 1000)).toISOString());

      // Send notification
      sendNotification({
        type: 'OPERATION_SCHEDULED',
        operationId: log.args.id,
        target: log.args.target,
        delay: log.args.delay.toString()
      });
    });
  }
});

// Monitor CallExecuted events
const unwatchExecuted = publicClient.watchEvent({
  address: TIMELOCK_ADDRESS,
  event: parseAbiItem('event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)'),
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('Operation executed:');
      console.log('  ID:', log.args.id);
      console.log('  Target:', log.args.target);
      console.log('  Tx:', log.transactionHash);
    });
  }
});

// Monitor Cancelled events
const unwatchCancelled = publicClient.watchEvent({
  address: TIMELOCK_ADDRESS,
  event: parseAbiItem('event Cancelled(bytes32 indexed id)'),
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('Operation cancelled:', log.args.id);

      sendAlert({
        type: 'OPERATION_CANCELLED',
        operationId: log.args.id,
        txHash: log.transactionHash
      });
    });
  }
});
```

### Query Pending Operations

```typescript
async function listPendingOperations() {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Get all CallScheduled events
  const events = await publicClient.getLogs({
    address: TIMELOCK_ADDRESS,
    event: parseAbiItem('event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)'),
    fromBlock: 0n,
    toBlock: 'latest'
  });

  const pending = [];

  for (const event of events) {
    const operationId = event.args.id;

    // Check if still pending
    const isPending = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: TIMELOCK_ABI,
      functionName: 'isOperationPending',
      args: [operationId]
    });

    if (!isPending) continue;

    const timestamp = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: TIMELOCK_ABI,
      functionName: 'getTimestamp',
      args: [operationId]
    });

    const isReady = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: TIMELOCK_ABI,
      functionName: 'isOperationReady',
      args: [operationId]
    });

    pending.push({
      id: operationId,
      target: event.args.target,
      timestamp: new Date(Number(timestamp) * 1000),
      isReady,
      blockNumber: event.blockNumber
    });
  }

  return pending;
}
```

## Security Considerations

### 1. Delay Configuration

```typescript
// Recommended delays
const UPGRADE_DELAY = 72 * 3600; // 72 hours for upgrades
const PARAMETER_DELAY = 48 * 3600; // 48 hours for parameters
const EMERGENCY_DELAY = 24 * 3600; // 24 hours minimum

// Set appropriate delay based on criticality
function getAppropriateDelay(operationType: string): number {
  switch (operationType) {
    case 'UPGRADE':
      return UPGRADE_DELAY;
    case 'PARAMETER':
      return PARAMETER_DELAY;
    case 'EMERGENCY':
      return EMERGENCY_DELAY;
    default:
      return PARAMETER_DELAY;
  }
}
```

### 2. Role Separation

```typescript
// Different roles for different operations
const SECURITY_MULTISIG = '0x...'; // Can cancel
const GOVERNANCE_MULTISIG = '0x...'; // Can propose
const EXECUTOR_BOT = '0x...'; // Can execute

const account = privateKeyToAccount(ADMIN_PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: base,
  transport: http()
});

const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

const PROPOSER_ROLE = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'PROPOSER_ROLE'
});

const EXECUTOR_ROLE = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'EXECUTOR_ROLE'
});

const CANCELLER_ROLE = await publicClient.readContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'CANCELLER_ROLE'
});

// Grant roles appropriately
await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'grantRole',
  args: [PROPOSER_ROLE, GOVERNANCE_MULTISIG]
});

await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'grantRole',
  args: [EXECUTOR_ROLE, EXECUTOR_BOT]
});

await walletClient.writeContract({
  address: TIMELOCK_ADDRESS,
  abi: TIMELOCK_ABI,
  functionName: 'grantRole',
  args: [CANCELLER_ROLE, SECURITY_MULTISIG]
});
```

### 3. Operation Verification

```typescript
import { decodeFunctionData } from 'viem';

// Always verify operation parameters before execution
async function verifyOperation(operationId: `0x${string}`) {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Get operation details from events
  const events = await publicClient.getLogs({
    address: TIMELOCK_ADDRESS,
    event: parseAbiItem('event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)'),
    args: {
      id: operationId
    },
    fromBlock: 0n,
    toBlock: 'latest'
  });

  if (events.length === 0) {
    throw new Error('Operation not found');
  }

  const event = events[0];

  // Display for review
  console.log('Operation Details:');
  console.log('  Target:', event.args.target);
  console.log('  Value:', event.args.value.toString());
  console.log('  Data:', event.args.data);
  console.log('  Predecessor:', event.args.predecessor);
  console.log('  Delay:', event.args.delay.toString());

  // Decode function call
  const decoded = decodeFunctionData({
    abi: TARGET_ABI,
    data: event.args.data
  });
  console.log('  Function:', decoded.functionName);
  console.log('  Params:', decoded.args);

  return {
    verified: true,
    details: event.args,
    decoded
  };
}
```

## Testing

### Foundry Tests

```solidity
function testTimelockUpgrade() public {
    // Schedule upgrade
    bytes memory data = abi.encodeWithSelector(
        ProxyAdmin.upgrade.selector,
        proxy,
        newImpl
    );

    vm.prank(proposer);
    timelock.schedule(
        address(proxyAdmin),
        0,
        data,
        bytes32(0),
        salt,
        delay
    );

    // Fast forward time
    vm.warp(block.timestamp + delay);

    // Execute
    vm.prank(executor);
    timelock.execute(
        address(proxyAdmin),
        0,
        data,
        bytes32(0),
        salt
    );

    // Verify upgrade
    assertEq(proxyAdmin.getProxyImplementation(proxy), newImpl);
}

function testCannotExecuteBeforeDelay() public {
    // Schedule operation
    vm.prank(proposer);
    timelock.schedule(target, 0, data, bytes32(0), salt, delay);

    // Try to execute immediately
    vm.prank(executor);
    vm.expectRevert("TimelockController: operation is not ready");
    timelock.execute(target, 0, data, bytes32(0), salt);
}

function testCancellerCanCancel() public {
    // Schedule operation
    vm.prank(proposer);
    timelock.schedule(target, 0, data, bytes32(0), salt, delay);

    bytes32 id = timelock.hashOperation(target, 0, data, bytes32(0), salt);

    // Cancel
    vm.prank(canceller);
    timelock.cancel(id);

    // Verify cancelled
    assertFalse(timelock.isOperationPending(id));
}
```

## Utility Scripts

### Generate Timelock Parameters

```bash
# Generate schedule parameters for upgrade
npx tsx script/upgrades/generate-timelock-upgrade-and-call-calldata.ts \
  "https://mainnet.base.org" \
  "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e" \
  "0x..." \
  "0x"
```

## Resources

### Documentation

- [OpenZeppelin TimelockController](https://docs.openzeppelin.com/contracts/4.x/api/governance#TimelockController)
- [Timelock Governance Patterns](https://docs.openzeppelin.com/contracts/4.x/governance)

### Related Topics

- [Upgradeability](./upgradeability.md) - Using timelock for upgrades
- [Access Control](./access-control.md) - Timelock role management
- [Security Considerations](./security-considerations.md) - Timelock security

## See Also

- [Emergency Procedures](./emergency-procedures.md) - Emergency cancellation
- [Migration Mode](./migration-mode.md) - Migration governance

---

**Last Updated**: December 2025
