# Migration Mode

Guide to the MultiVaultMigrationMode contract, data migration patterns, and upgrade procedures from V1 to V2.

## Overview

The MultiVaultMigrationMode contract is a temporary deployment pattern used to migrate existing protocol data from V1 to V2 while maintaining user balances and vault states. After migration completes, it upgrades to the standard MultiVault contract.

## Architecture

### Migration Flow

```
┌──────────────────┐
│  MultiVault V1   │
│  (Old System)    │
└────────┬─────────┘
         │
         │ Extract Data
         ▼
┌──────────────────┐
│  Migration       │
│  Scripts         │
└────────┬─────────┘
         │
         │ Batch Migrate
         ▼
┌──────────────────┐
│ MultiVault       │
│ MigrationMode    │ (Proxy)
└────────┬─────────┘
         │
         │ Upgrade & Revoke
         ▼
┌──────────────────┐
│  MultiVault V2   │
│  (Final System)  │
└──────────────────┘
```

## MIGRATOR_ROLE

### Purpose

Temporary role that allows data migration operations not available in standard MultiVault.

**Role Identifier:**
```solidity
bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
```

**Critical Requirements:**
- MUST be revoked after migration complete
- Cannot be regranted once revoked
- Held by secure migration script runner
- Should use time-limited access

### Protected Operations

```solidity
// Set term count
function setTermCount(uint256 _termCount) external onlyRole(MIGRATOR_ROLE);

// Batch set atom data
function batchSetAtomData(
    address[] calldata creators,
    bytes[] calldata atomDataArray
) external onlyRole(MIGRATOR_ROLE);

// Batch set triple data
function batchSetTripleData(
    address[] calldata creators,
    bytes32[][] calldata atomIds
) external onlyRole(MIGRATOR_ROLE);

// Set vault totals
function setVaultTotals(
    bytes32[] calldata termIds,
    uint256 curveId,
    VaultTotals[] calldata totals
) external onlyRole(MIGRATOR_ROLE);

// Batch set user balances
function batchSetUserBalances(
    BatchSetUserBalancesParams calldata params
) external onlyRole(MIGRATOR_ROLE);
```

## Migration Process

### Phase 1: Deploy MigrationMode

```bash
# Deploy MultiVaultMigrationMode implementation and proxy
forge script script/intuition/MultiVaultMigrationModeDeploy.s.sol \
  --rpc-url intuition_sepolia \
  --broadcast
```

### Phase 2: Extract V1 Data

```typescript
import { createPublicClient, http, parseAbiItem } from 'viem';
import { base } from 'viem/chains';

async function extractV1Data() {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Extract atoms
  const atomEvents = await publicClient.getLogs({
    address: OLD_MULTIVAULT_ADDRESS,
    event: parseAbiItem('event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)'),
    fromBlock: 0n,
    toBlock: 'latest'
  });

  const atoms = atomEvents.map(log => ({
    creator: log.args.creator,
    atomId: log.args.termId,
    atomData: log.args.atomData
  }));

  // Extract triples
  const tripleEvents = await publicClient.getLogs({
    address: OLD_MULTIVAULT_ADDRESS,
    event: parseAbiItem('event TripleCreated(address indexed creator, bytes32 indexed id, bytes32 subjectId, bytes32 predicateId, bytes32 objectId, address tripleWallet, address counterWallet)'),
    fromBlock: 0n,
    toBlock: 'latest'
  });

  const triples = tripleEvents.map(log => ({
    creator: log.args.creator,
    tripleId: log.args.id,
    subjectId: log.args.subjectId,
    predicateId: log.args.predicateId,
    objectId: log.args.objectId
  }));

  // Extract vault states
  const vaultStates = await extractVaultStates(publicClient);

  // Extract user balances
  const userBalances = await extractUserBalances(publicClient, vaultStates);

  return {
    termCount: atoms.length + triples.length * 2, // includes counter triples
    atoms,
    triples,
    vaultStates,
    userBalances
  };
}
```

### Phase 3: Migrate Data

```typescript
import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base } from 'viem/chains';

async function migrateData(data: ExtractedData) {
  const account = privateKeyToAccount(MIGRATOR_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Step 1: Set term count
  console.log('Setting term count...');
  const setCountHash = await walletClient.writeContract({
    address: MIGRATION_MODE_ADDRESS,
    abi: MIGRATION_MODE_ABI,
    functionName: 'setTermCount',
    args: [data.termCount]
  });
  await publicClient.waitForTransactionReceipt({ hash: setCountHash });

  // Step 2: Migrate atoms in batches
  console.log('Migrating atoms...');
  const BATCH_SIZE = 100;

  for (let i = 0; i < data.atoms.length; i += BATCH_SIZE) {
    const batch = data.atoms.slice(i, i + BATCH_SIZE);

    const creators = batch.map(a => a.creator);
    const atomDataArray = batch.map(a => a.atomData);

    const hash = await walletClient.writeContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'batchSetAtomData',
      args: [creators, atomDataArray]
    });
    await publicClient.waitForTransactionReceipt({ hash });

    console.log(`Migrated atoms ${i} to ${i + batch.length}`);
  }

  // Step 3: Migrate triples in batches
  console.log('Migrating triples...');

  for (let i = 0; i < data.triples.length; i += BATCH_SIZE) {
    const batch = data.triples.slice(i, i + BATCH_SIZE);

    const creators = batch.map(t => t.creator);
    const atomIds = batch.map(t => [t.subjectId, t.predicateId, t.objectId]);

    const hash = await walletClient.writeContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'batchSetTripleData',
      args: [creators, atomIds]
    });
    await publicClient.waitForTransactionReceipt({ hash });

    console.log(`Migrated triples ${i} to ${i + batch.length}`);
  }

  // Step 4: Migrate vault totals
  console.log('Migrating vault states...');

  for (const curveId of Object.keys(data.vaultStates)) {
    const vaults = data.vaultStates[curveId];

    const termIds = vaults.map(v => v.termId);
    const totals = vaults.map(v => ({
      totalAssets: v.totalAssets,
      totalShares: v.totalShares
    }));

    const hash = await walletClient.writeContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'setVaultTotals',
      args: [termIds, curveId, totals]
    });
    await publicClient.waitForTransactionReceipt({ hash });

    console.log(`Migrated vault totals for curve ${curveId}`);
  }

  // Step 5: Migrate user balances
  console.log('Migrating user balances...');

  // Group by curve and user for efficient batching
  const grouped = groupUserBalances(data.userBalances);

  for (const params of grouped) {
    const hash = await walletClient.writeContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'batchSetUserBalances',
      args: [params]
    });
    await publicClient.waitForTransactionReceipt({ hash });

    console.log(`Migrated balances for ${params.users.length} users`);
  }

  console.log('Data migration complete');
}
```

### Phase 4: Fund Migration Mode

```typescript
import { formatEther } from 'viem';

// Transfer TRUST to back the migrated shares
async function fundMigrationMode(totalAssetsNeeded: bigint) {
  const account = privateKeyToAccount(FUNDER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Calculate total assets needed across all vaults
  console.log(`Total TRUST needed: ${formatEther(totalAssetsNeeded)}`);

  // Transfer TRUST to MigrationMode contract
  const hash = await walletClient.writeContract({
    address: TRUST_ADDRESS,
    abi: TRUST_ABI,
    functionName: 'transfer',
    args: [MIGRATION_MODE_ADDRESS, totalAssetsNeeded]
  });
  await publicClient.waitForTransactionReceipt({ hash });

  // Verify balance
  const balance = await publicClient.readContract({
    address: TRUST_ADDRESS,
    abi: TRUST_ABI,
    functionName: 'balanceOf',
    args: [MIGRATION_MODE_ADDRESS]
  });
  console.log(`MigrationMode TRUST balance: ${formatEther(balance)}`);

  if (balance < totalAssetsNeeded) {
    throw new Error('Insufficient funds transferred');
  }

  console.log('Migration mode funded successfully');
}
```

### Phase 5: Upgrade to MultiVault

```bash
# Deploy MultiVault implementation
# Upgrade proxy
# Revoke MIGRATOR_ROLE

forge script script/intuition/MultiVaultMigrationUpgrade.s.sol \
  --rpc-url intuition_sepolia \
  --broadcast
```

**Upgrade Script:**
```solidity
// From MultiVaultMigrationUpgrade.s.sol
function run() public broadcast {
    // 1. Deploy MultiVault implementation
    MultiVault multiVaultImpl = new MultiVault();

    // 2. Upgrade proxy
    proxyAdmin.upgradeAndCall(
        ITransparentUpgradeableProxy(MULTIVAULT_PROXY),
        address(multiVaultImpl),
        "" // empty calldata
    );

    // 3. Revoke MIGRATOR_ROLE permanently
    MultiVault(MULTIVAULT_PROXY).revokeRole(MIGRATOR_ROLE, ADMIN);

    // 4. Verify revocation
    bool revoked = !MultiVault(MULTIVAULT_PROXY).hasRole(MIGRATOR_ROLE, ADMIN);
    require(revoked, "MIGRATOR_ROLE revoke failed");

    console.log("Migration complete, MIGRATOR_ROLE revoked");
}
```

## Validation

### Pre-Migration Validation

```typescript
async function validatePreMigration(data: ExtractedData) {
  const checks = [];

  // 1. Verify data completeness
  checks.push({
    name: 'All atoms extracted',
    pass: data.atoms.length > 0
  });

  checks.push({
    name: 'All triples extracted',
    pass: data.triples.length > 0
  });

  // 2. Verify data consistency
  const totalAssets = data.vaultStates.reduce(
    (sum, v) => sum + v.totalAssets,
    0n
  );

  const totalUserShares = data.userBalances.reduce(
    (sum, b) => sum + b.shares,
    0n
  );

  checks.push({
    name: 'Total assets > 0',
    pass: totalAssets > 0n
  });

  // 3. Verify no duplicate atoms
  const atomIds = new Set(data.atoms.map(a => a.atomId));
  checks.push({
    name: 'No duplicate atoms',
    pass: atomIds.size === data.atoms.length
  });

  // All checks must pass
  const allPass = checks.every(c => c.pass);

  if (!allPass) {
    console.error('Pre-migration validation failed:', checks);
    throw new Error('Validation failed');
  }

  console.log('Pre-migration validation passed');
  return true;
}
```

### Post-Migration Validation

```typescript
async function validatePostMigration(
  oldContractAddress: string,
  newContractAddress: string
) {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  const checks = [];

  // 1. Verify term count
  const oldCount = await getTermCount(publicClient, oldContractAddress);
  const newCount = await publicClient.readContract({
    address: newContractAddress,
    abi: MULTIVAULT_ABI,
    functionName: 'totalTermsCreated'
  });

  checks.push({
    name: 'Term count matches',
    pass: oldCount === newCount,
    old: oldCount,
    new: newCount
  });

  // 2. Sample vault states
  const sampleVaults = await selectSampleVaults(publicClient, oldContractAddress);

  for (const vault of sampleVaults) {
    const oldState = await getVaultState(publicClient, oldContractAddress, vault.termId, vault.curveId);
    const newState = await getVaultState(publicClient, newContractAddress, vault.termId, vault.curveId);

    checks.push({
      name: `Vault ${vault.termId} total assets`,
      pass: oldState.totalAssets === newState.totalAssets,
      old: oldState.totalAssets,
      new: newState.totalAssets
    });

    checks.push({
      name: `Vault ${vault.termId} total shares`,
      pass: oldState.totalShares === newState.totalShares,
      old: oldState.totalShares,
      new: newState.totalShares
    });
  }

  // 3. Sample user balances
  const sampleUsers = await selectSampleUsers(publicClient, oldContractAddress);

  for (const user of sampleUsers) {
    for (const vault of user.vaults) {
      const oldBalance = await publicClient.readContract({
        address: oldContractAddress,
        abi: MULTIVAULT_ABI,
        functionName: 'balanceOf',
        args: [user.address, vault.termId, vault.curveId]
      });

      const newBalance = await publicClient.readContract({
        address: newContractAddress,
        abi: MULTIVAULT_ABI,
        functionName: 'balanceOf',
        args: [user.address, vault.termId, vault.curveId]
      });

      checks.push({
        name: `User ${user.address} balance in ${vault.termId}`,
        pass: oldBalance === newBalance,
        old: oldBalance,
        new: newBalance
      });
    }
  }

  // 4. Verify MIGRATOR_ROLE revoked
  const hasRole = await publicClient.readContract({
    address: newContractAddress,
    abi: MULTIVAULT_ABI,
    functionName: 'hasRole',
    args: [MIGRATOR_ROLE, ADMIN]
  });

  checks.push({
    name: 'MIGRATOR_ROLE revoked',
    pass: !hasRole
  });

  // Report results
  const failures = checks.filter(c => !c.pass);

  if (failures.length > 0) {
    console.error('Post-migration validation failures:', failures);
    throw new Error('Migration validation failed');
  }

  console.log('Post-migration validation passed');
  console.log(`Total checks: ${checks.length}`);

  return true;
}
```

## Security Considerations

### 1. Time-Limited Migration Window

```typescript
// Set migration deadline
const MIGRATION_DEADLINE = Math.floor(Date.now() / 1000) + 7 * 24 * 3600; // 7 days

async function checkMigrationDeadline() {
  if (Date.now() / 1000 > MIGRATION_DEADLINE) {
    throw new Error('Migration window expired');
  }
}
```

### 2. Atomic Batching

```typescript
import { encodeFunctionData } from 'viem';

// Ensure batch operations are atomic
async function migrateBatchAtomic(batch: MigrationBatch) {
  const account = privateKeyToAccount(MIGRATOR_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  try {
    // All operations in single transaction via multicall
    const calls = [
      encodeFunctionData({
        abi: MIGRATION_MODE_ABI,
        functionName: 'batchSetAtomData',
        args: [...]
      }),
      encodeFunctionData({
        abi: MIGRATION_MODE_ABI,
        functionName: 'setVaultTotals',
        args: [...]
      }),
      encodeFunctionData({
        abi: MIGRATION_MODE_ABI,
        functionName: 'batchSetUserBalances',
        args: [...]
      })
    ];

    const hash = await walletClient.writeContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'multicall',
      args: [calls]
    });
    await publicClient.waitForTransactionReceipt({ hash });

    console.log('Batch migrated atomically');
  } catch (error) {
    console.error('Batch migration failed, rolling back');
    throw error;
  }
}
```

### 3. Immutable After Upgrade

```typescript
// Verify MIGRATOR_ROLE cannot be regranted
async function verifyMigratorRevoked() {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  const account = privateKeyToAccount(ADMIN_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: base,
    transport: http()
  });

  // Try to grant (should fail)
  try {
    await walletClient.writeContract({
      address: MULTIVAULT_ADDRESS,
      abi: MULTIVAULT_ABI,
      functionName: 'grantRole',
      args: [MIGRATOR_ROLE, ADMIN]
    });
    throw new Error('MIGRATOR_ROLE was regranted - SECURITY ISSUE');
  } catch (error) {
    // Expected to fail - MultiVault doesn't have MIGRATOR_ROLE
    console.log('MIGRATOR_ROLE permanently disabled');
  }
}
```

## Monitoring During Migration

```typescript
// Monitor migration progress
async function monitorMigration() {
  const publicClient = createPublicClient({
    chain: base,
    transport: http()
  });

  // Listen for migration events
  const unwatch = publicClient.watchEvent({
    address: MIGRATION_MODE_ADDRESS,
    onLogs: (logs) => {
      logs.forEach((log) => {
        if (log.eventName === 'AtomCreated') {
          console.log(`Atom migrated: ${log.args.termId}`);
        } else if (log.eventName === 'TripleCreated') {
          console.log(`Triple migrated: ${log.args.id}`);
        }
      });
    }
  });

  // Track progress
  let migratedAtoms = 0;
  let migratedTriples = 0;
  let migratedVaults = 0;

  setInterval(async () => {
    const termCount = await publicClient.readContract({
      address: MIGRATION_MODE_ADDRESS,
      abi: MIGRATION_MODE_ABI,
      functionName: 'totalTermsCreated'
    });

    console.log(`Migration Progress:`);
    console.log(`  Terms: ${termCount}`);
    console.log(`  Atoms: ${migratedAtoms}`);
    console.log(`  Triples: ${migratedTriples}`);
    console.log(`  Vaults: ${migratedVaults}`);
  }, 60000); // Every minute
}
```

## Best Practices

1. **Test on Fork First**: Always test full migration on local fork
2. **Batch Appropriately**: Balance gas costs vs. number of transactions
3. **Validate Continuously**: Check data integrity at each step
4. **Monitor Closely**: Watch for errors during migration
5. **Have Rollback Plan**: Document how to rollback if needed
6. **Document Everything**: Keep detailed logs of all operations
7. **Communicate Clearly**: Keep users informed of migration progress

## Troubleshooting

### Issue: Migration transaction fails

**Cause:** Batch too large, hitting gas limit

**Solution:**
```typescript
// Reduce batch size
const SAFE_BATCH_SIZE = 50; // Reduce from 100
```

### Issue: Data mismatch after migration

**Cause:** Concurrent operations during migration

**Solution:**
```typescript
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

// Pause V1 contract before migration
const hash = await walletClient.writeContract({
  address: OLD_MULTIVAULT_ADDRESS,
  abi: OLD_MULTIVAULT_ABI,
  functionName: 'pause'
});
await publicClient.waitForTransactionReceipt({ hash });

// Perform migration
await migrateData(extractedData);

// Validate
await validatePostMigration(OLD_MULTIVAULT_ADDRESS, NEW_MULTIVAULT_ADDRESS);
```

### Issue: Insufficient TRUST balance

**Cause:** Didn't account for all vault assets

**Solution:**
```typescript
// Calculate with buffer
const totalNeeded = calculateTotalAssets(vaultStates);
const buffer = totalNeeded / 100n; // 1% buffer
await fundMigrationMode(totalNeeded + buffer);
```

## See Also

- [Upgradeability](./upgradeability.md) - Upgrade patterns
- [Access Control](./access-control.md) - MIGRATOR_ROLE management
- [Security Considerations](./security-considerations.md) - Migration security

---

**Last Updated**: December 2025
