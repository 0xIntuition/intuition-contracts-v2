# Migration Guides

Step-by-step guides for upgrading between versions of Intuition Protocol.

## Overview

This document provides detailed migration instructions for upgrading integrations, contracts, and applications between different versions of the Intuition Protocol.

## V1 to V2 Migration

### Overview

**Timeline:** October-November 2025

**Scope:** Complete protocol redesign

**Impact:** Breaking changes require code updates

### Key Differences

| Feature | V1 | V2 |
|---------|----|----|
| Vault Model | Single vault per term | Multiple vaults per term (per curve) |
| Token | Custom mechanics | Standard ERC20 (TRUST) |
| Rewards | Direct distribution | Epoch-based with utilization |
| Deposit API | `deposit(termId, amount)` | `deposit(termId, curveId, assets, receiver)` |
| Curves | Hardcoded | Pluggable bonding curves |
| Wallets | None | ERC-4337 atom wallets |

### Step 1: Update Dependencies

```bash
# Update to V2 contracts
npm install @intuition/contracts-v2@latest

# Or update git submodule
git submodule update --init --recursive
```

### Step 2: Update Contract Addresses

Replace V1 contract addresses with V2 addresses.

**Mainnet:**
```typescript
// OLD V1
const MULTIVAULT_V1 = '0x...'; // Deprecated

// NEW V2
const MULTIVAULT_V2 = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const TRUST_TOKEN = '0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3';
const TRUSTBONDING = '0x635bBD1367B66E7B16a21D6E5A63C812fFC00617';
```

See [Deployment Addresses](../getting-started/deployment-addresses.md) for complete list.

### Step 3: Update Deposit Code

**V1 Code:**
```typescript
// OLD - V1
async function depositV1(termId: string, amount: bigint) {
  const tx = await multiVault.deposit(termId, amount);
  await tx.wait();
}
```

**V2 Code:**
```typescript
// NEW - V2
async function depositV2(
  termId: string,
  curveId: number,
  assets: bigint,
  receiver: string
) {
  // 1. Approve TRUST
  const trust = new ethers.Contract(TRUST_ADDRESS, TRUST_ABI, signer);
  await trust.approve(MULTIVAULT_ADDRESS, assets);

  // 2. Deposit with curve selection
  const tx = await multiVault.deposit(termId, curveId, assets, receiver);
  const receipt = await tx.wait();

  // 3. Parse deposit event for shares received
  const depositEvent = receipt.logs
    .map(log => {
      try {
        return multiVault.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find(event => event && event.name === 'Deposited');

  return {
    shares: depositEvent.args.shares,
    txHash: receipt.hash
  };
}
```

**Migration Notes:**
- Add `curveId` parameter (use 1 for LinearCurve, equivalent to V1)
- Add `receiver` parameter (can be same as sender)
- Approve TRUST tokens before deposit
- Handle return value for shares minted

### Step 4: Update Redemption Code

**V1 Code:**
```typescript
// OLD - V1
async function redeemV1(termId: string, shares: bigint) {
  const tx = await multiVault.redeem(termId, shares);
  await tx.wait();
}
```

**V2 Code:**
```typescript
// NEW - V2
async function redeemV2(
  termId: string,
  curveId: number,
  shares: bigint,
  receiver: string
) {
  const tx = await multiVault.redeem(termId, curveId, shares, receiver);
  const receipt = await tx.wait();

  // Parse redemption event for assets received
  const redeemEvent = receipt.logs
    .map(log => {
      try {
        return multiVault.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find(event => event && event.name === 'Redeemed');

  return {
    assets: redeemEvent.args.assets,
    fees: redeemEvent.args.fees,
    txHash: receipt.hash
  };
}
```

### Step 5: Update Balance Queries

**V1 Code:**
```typescript
// OLD - V1
const balance = await multiVault.balanceOf(user, termId);
```

**V2 Code:**
```typescript
// NEW - V2
const balance = await multiVault.balanceOf(user, termId, curveId);

// Query across all curves
async function getTotalBalanceAllCurves(user: string, termId: string) {
  const curveIds = [1, 2, 3]; // Known curve IDs
  let total = 0n;

  for (const curveId of curveIds) {
    const balance = await multiVault.balanceOf(user, termId, curveId);
    total += balance;
  }

  return total;
}
```

### Step 6: Update Reward Claims

**V1 Code:**
```typescript
// OLD - V1
const tx = await rewardContract.claim();
await tx.wait();
```

**V2 Code:**
```typescript
// NEW - V2
const trustBonding = new ethers.Contract(
  TRUSTBONDING_ADDRESS,
  TRUSTBONDING_ABI,
  signer
);

// Claim rewards for specific epochs
const epochIds = [1, 2, 3]; // Epochs to claim
const tx = await trustBonding.batchClaimRewards(epochIds);
await tx.wait();

// Or claim all available epochs
async function claimAllRewards(user: string) {
  const currentEpoch = await trustBonding.currentEpoch();
  const epochsToClaim = [];

  // Check each epoch for unclaimed rewards
  for (let epoch = 1; epoch < currentEpoch; epoch++) {
    const userInfo = await trustBonding.getUserInfo(user, epoch);
    if (userInfo.eligibleRewards > 0n) {
      epochsToClaim.push(epoch);
    }
  }

  if (epochsToClaim.length > 0) {
    const tx = await trustBonding.batchClaimRewards(epochsToClaim);
    await tx.wait();
  }
}
```

### Step 7: Update Event Listeners

**V1 Events:**
```typescript
// OLD - V1
multiVault.on('Deposit', (user, termId, amount) => {
  console.log('Deposit:', user, termId, amount);
});
```

**V2 Events:**
```typescript
// NEW - V2
multiVault.on('Deposited', (
  sender,
  receiver,
  termId,
  curveId,
  assets,
  assetsAfterFees,
  shares,
  totalShares,
  vaultType
) => {
  console.log('Deposit:', {
    sender,
    receiver,
    termId,
    curveId,
    assets: ethers.formatEther(assets),
    shares: ethers.formatEther(shares),
    vaultType: ['ATOM', 'TRIPLE', 'COUNTER_TRIPLE'][vaultType]
  });
});
```

### Step 8: Test Migration

```typescript
// Migration testing checklist
async function testMigration() {
  const tests = [];

  // 1. Test deposit
  try {
    await depositV2(TEST_TERM_ID, 1, ethers.parseEther('1'), user);
    tests.push({ name: 'Deposit', passed: true });
  } catch (error) {
    tests.push({ name: 'Deposit', passed: false, error });
  }

  // 2. Test balance query
  try {
    const balance = await multiVault.balanceOf(user, TEST_TERM_ID, 1);
    tests.push({ name: 'Balance Query', passed: balance > 0n });
  } catch (error) {
    tests.push({ name: 'Balance Query', passed: false, error });
  }

  // 3. Test redemption
  try {
    const balance = await multiVault.balanceOf(user, TEST_TERM_ID, 1);
    await redeemV2(TEST_TERM_ID, 1, balance / 2n, user);
    tests.push({ name: 'Redemption', passed: true });
  } catch (error) {
    tests.push({ name: 'Redemption', passed: false, error });
  }

  // 4. Test reward claim
  try {
    await claimAllRewards(user);
    tests.push({ name: 'Reward Claim', passed: true });
  } catch (error) {
    tests.push({ name: 'Reward Claim', passed: false, error });
  }

  // Report
  console.log('Migration Test Results:');
  tests.forEach(test => {
    console.log(`${test.passed ? '✅' : '❌'} ${test.name}`);
    if (!test.passed && test.error) {
      console.error('  Error:', test.error.message);
    }
  });

  const allPassed = tests.every(t => t.passed);
  return allPassed;
}
```

## Trust V2 Upgrade

### Overview

**Date:** November 2025

**Type:** Contract upgrade (proxy upgrade)

**Impact:** No user action required, but SDK updates recommended

### What Changed

1. **AccessControl Added**
   - Trust token now uses role-based access control
   - `DEFAULT_ADMIN_ROLE` for admin operations

2. **Minting Restriction**
   - Only `baseEmissionsController` can mint
   - Public minting disabled

3. **New State Variable**
   - `address public baseEmissionsController`

### For Users

**No action required.** Your TRUST balances are preserved.

### For Integrators

Update to latest ABI:

```typescript
// Old ABI
const oldAbi = [
  'function mint(address to, uint256 amount) public',
  // ...
];

// New ABI
const newAbi = [
  'function mint(address to, uint256 amount) public', // Now restricted
  'function burn(uint256 amount) external',
  'function setBaseEmissionsController(address) external',
  'function baseEmissionsController() view returns (address)',
  // ... plus AccessControl functions
];
```

### For Contract Developers

If your contract integrated with Trust token:

```solidity
// OLD - Direct minting (no longer works)
Trust(trustAddress).mint(recipient, amount); // REVERTS

// NEW - Only BaseEmissionsController can mint
// For testing, use a different approach:
vm.prank(baseEmissionsController);
Trust(trustAddress).mint(recipient, amount); // Works in tests
```

## BaseEmissionsController Deployment

### Overview

**Date:** September 2025

**Type:** New contract deployment

**Impact:** New emissions system

### Integration Steps

#### Step 1: Get Current Epoch

```typescript
const baseEmissions = new ethers.Contract(
  BASE_EMISSIONS_CONTROLLER_ADDRESS,
  BASE_EMISSIONS_ABI,
  provider
);

const currentEpoch = await baseEmissions.currentEpoch();
const epochInfo = await baseEmissions.epochInfo(currentEpoch);

console.log('Current Epoch:', currentEpoch);
console.log('Emissions:', ethers.formatEther(epochInfo.emissions));
```

#### Step 2: Monitor Epoch Changes

```typescript
baseEmissions.on('EpochAdvanced', (epochId, emissions, event) => {
  console.log('New Epoch:', epochId);
  console.log('Emissions:', ethers.formatEther(emissions));
});
```

#### Step 3: Query Emission Schedule

```typescript
async function getEmissionSchedule(numEpochs: number) {
  const schedule = [];

  for (let i = 0; i < numEpochs; i++) {
    const epochId = currentEpoch + i;
    const emissions = await baseEmissions.calculateEpochEmissions(epochId);

    schedule.push({
      epoch: epochId,
      emissions: ethers.formatEther(emissions)
    });
  }

  return schedule;
}
```

## Solidity Contract Migration

### V1 to V2 Contract Integration

If you have a Solidity contract integrating with Intuition:

**V1 Integration:**
```solidity
// OLD - V1
import {IMultiVaultV1} from "./interfaces/IMultiVaultV1.sol";

contract MyContract {
    IMultiVaultV1 public multiVault;

    function deposit(bytes32 termId, uint256 amount) external {
        // Approve and deposit
        IERC20(asset).approve(address(multiVault), amount);
        multiVault.deposit(termId, amount);
    }
}
```

**V2 Integration:**
```solidity
// NEW - V2
import {IMultiVault} from "@intuition/contracts-v2/src/interfaces/IMultiVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyContract {
    IMultiVault public multiVault;
    address public trustToken;

    function deposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        // Approve TRUST
        IERC20(trustToken).approve(address(multiVault), assets);

        // Deposit
        uint256 sharesBefore = multiVault.balanceOf(receiver, termId, curveId);
        multiVault.deposit(termId, curveId, assets, receiver);
        uint256 sharesAfter = multiVault.balanceOf(receiver, termId, curveId);

        shares = sharesAfter - sharesBefore;
    }
}
```

## Testing Migrations

### Fork Testing

```bash
# Fork mainnet at specific block (before migration)
anvil --fork-url $MAINNET_RPC --fork-block-number $BLOCK_BEFORE_MIGRATION

# Run migration tests
forge test --match-contract MigrationTest --fork-url http://localhost:8545
```

### Migration Test Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

contract MigrationTest is Test {
    // V1 contracts
    address constant MULTIVAULT_V1 = 0x...;

    // V2 contracts
    address constant MULTIVAULT_V2 = 0x...;
    address constant TRUST = 0x...;

    function setUp() public {
        // Fork at migration block
        vm.createSelectFork(vm.envString("MAINNET_RPC"), MIGRATION_BLOCK);
    }

    function testBalancesMigrated() public {
        // Test user balances match before/after
    }

    function testDepositsWorkV2() public {
        // Test deposits work on V2
    }
}
```

## Rollback Procedures

If issues are discovered post-migration:

### Emergency Rollback

```typescript
// Only if critical issue discovered
// Requires ProxyAdmin or Timelock control

const proxyAdmin = new ethers.Contract(
  PROXY_ADMIN_ADDRESS,
  PROXY_ADMIN_ABI,
  adminSigner
);

// Rollback to previous implementation
await proxyAdmin.upgrade(
  MULTIVAULT_PROXY_ADDRESS,
  PREVIOUS_IMPLEMENTATION_ADDRESS
);
```

**Note:** Rollbacks should only be performed by protocol governance and may require timelock delay.

## Support

Need help with migration?

- **Discord**: [discord.gg/intuition](https://discord.gg/intuition) #dev-support
- **GitHub Discussions**: [github.com/0xIntuition/intuition-contracts-v2/discussions](https://github.com/0xIntuition/intuition-contracts-v2/discussions)
- **Documentation**: [docs.intuition.systems](https://docs.intuition.systems)

## See Also

- [Changelog](./changelog.md) - Version history
- [Upgradeability](../advanced/upgradeability.md) - Upgrade patterns
- [FAQ](./faq.md) - Common questions

---

**Last Updated**: December 2025
