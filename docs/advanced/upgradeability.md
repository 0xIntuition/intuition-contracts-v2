# Upgradeability

Comprehensive guide to proxy patterns, upgrade mechanisms, and procedures used in Intuition Protocol V2.

## Overview

Intuition Protocol V2 uses OpenZeppelin's upgradeable contract patterns to allow protocol improvements while preserving state and deployed addresses. Different contracts use different proxy patterns based on their specific requirements.

## Proxy Patterns

### 1. Transparent Proxy Pattern

The Transparent Proxy pattern is used for contracts where upgrade logic is managed by a separate ProxyAdmin contract.

**Contracts Using Transparent Proxies:**
- Trust (TRUST token)
- BaseEmissionsController
- SatelliteEmissionsController
- TrustBonding
- AtomWarden
- AtomWalletFactory
- BondingCurveRegistry
- All bonding curve implementations (LinearCurve, OffsetProgressiveCurve)

**Key Characteristics:**
- ProxyAdmin contract owns upgrade rights
- Upgrade logic is separate from implementation
- Admin calls are routed to ProxyAdmin, user calls to implementation
- Maximum separation of concerns

**Architecture:**
```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ call
       ▼
┌─────────────────┐     ┌──────────────┐
│ Transparent     │────▶│ ProxyAdmin   │
│ Proxy           │     └──────┬───────┘
└────────┬────────┘            │ upgrade
         │ delegatecall        │
         ▼                     ▼
┌─────────────────┐     ┌──────────────┐
│ Implementation  │     │ New Impl     │
│ V1              │     │ V2           │
└─────────────────┘     └──────────────┘
```

### 2. UUPS Proxy Pattern

UUPS (Universal Upgradeable Proxy Standard) places upgrade logic in the implementation contract itself.

**Contracts Using UUPS:**
- MultiVault / MultiVaultMigrationMode

**Key Characteristics:**
- Upgrade function lives in implementation
- Smaller proxy contract (less gas for deployment)
- Implementation must include authorization for upgrades
- More gas-efficient for ongoing operations

**Architecture:**
```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ call
       ▼
┌─────────────────┐
│ UUPS Proxy      │
└────────┬────────┘
         │ delegatecall
         ▼
┌─────────────────────────┐
│ Implementation          │
│ - Business logic        │
│ - _authorizeUpgrade()   │
└─────────────────────────┘
```

### 3. Beacon Proxy Pattern

The Beacon Proxy pattern allows multiple proxies to point to a single beacon, enabling simultaneous upgrades of many contracts.

**Contracts Using Beacon Proxies:**
- AtomWallet (via AtomWalletBeacon)

**Key Characteristics:**
- Multiple proxies share one beacon
- Upgrade all instances simultaneously
- Single point of upgrade for many wallets
- Efficient for factory-deployed contracts

**Architecture:**
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Wallet 1 │  │ Wallet 2 │  │ Wallet N │
│ Proxy    │  │ Proxy    │  │ Proxy    │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └─────────────┼─────────────┘
                   │ getImplementation()
                   ▼
          ┌────────────────┐
          │  AtomWallet    │
          │  Beacon        │
          └────────┬───────┘
                   │ points to
                   ▼
          ┌────────────────┐
          │  AtomWallet    │
          │  Implementation│
          └────────────────┘
```

## Governance and Access Control

### TimelockController

Critical upgrades are protected by OpenZeppelin's TimelockController, which enforces a delay between proposal and execution.

**Timelock Instances:**

1. **Upgrades TimelockController** (Base Chain)
   - Controls BaseEmissionsController upgrades
   - Mainnet: `0x1E442BbB08c98100b18fa830a88E8A57b5dF9157`
   - Testnet: `0x9099BC9fd63B01F94528B60CEEB336C679eb6d52`

2. **Upgrades TimelockController** (Satellite Chain)
   - Controls MultiVault and emissions upgrades
   - Mainnet: `0x321e5d4b20158648dFd1f360A79CAFc97190bAd1`
   - Testnet: `0x59B7EaB1cFA47F8E61606aDf79a6b7B5bBF1aF26`

3. **Parameters TimelockController** (Satellite Chain)
   - Controls protocol parameter changes
   - Mainnet: `0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA`
   - Testnet: `0xcCB113bfFf493d80F32Fb799Dca23686a04302A7`

**Timelock Properties:**
- Minimum delay (configurable, typically 48-72 hours)
- Multiple proposers and executors
- Cancellation capability
- Transparent operation scheduling

## Upgrade Procedures

### Standard Upgrade Process

#### 1. Prepare New Implementation

```solidity
// Deploy new implementation
NewImplementation impl = new NewImplementation();
```

#### 2. Test Upgrade (Local/Testnet)

```bash
# Fork mainnet for testing
forge test --fork-url $RPC_URL --match-contract UpgradeTest

# Test on testnet first
forge script script/upgrades/TestnetUpgrade.s.sol \
  --rpc-url testnet \
  --broadcast
```

#### 3. Schedule Upgrade via Timelock

```typescript
import { ethers } from 'ethers';

// Prepare upgrade call
const proxyAdmin = new ethers.Contract(PROXY_ADMIN_ADDRESS, PROXY_ADMIN_ABI, signer);
const upgradeCalldata = proxyAdmin.interface.encodeFunctionData('upgradeAndCall', [
  PROXY_ADDRESS,
  NEW_IMPLEMENTATION,
  '0x' // empty if no initialization needed
]);

// Schedule via TimelockController
const timelock = new ethers.Contract(TIMELOCK_ADDRESS, TIMELOCK_ABI, signer);
const tx = await timelock.schedule(
  PROXY_ADMIN_ADDRESS,      // target
  0,                        // value
  upgradeCalldata,          // data
  ethers.ZeroHash,          // predecessor
  ethers.id('salt-string'), // salt
  MINIMUM_DELAY             // delay (e.g., 2 days)
);

console.log('Upgrade scheduled:', tx.hash);
```

#### 4. Wait for Timelock Delay

```typescript
// Check if ready to execute
const timestamp = await timelock.getTimestamp(operationId);
const isReady = await timelock.isOperationReady(operationId);
const timeRemaining = timestamp - Math.floor(Date.now() / 1000);

console.log(`Upgrade ready: ${isReady}`);
console.log(`Time remaining: ${timeRemaining} seconds`);
```

#### 5. Execute Upgrade

```typescript
// After delay has passed
const executeTx = await timelock.execute(
  PROXY_ADMIN_ADDRESS,
  0,
  upgradeCalldata,
  ethers.ZeroHash,
  ethers.id('salt-string')
);

await executeTx.wait();
console.log('Upgrade executed:', executeTx.hash);
```

#### 6. Verify Upgrade

```typescript
// Verify implementation changed
const proxy = new ethers.Contract(PROXY_ADDRESS, PROXY_ABI, provider);
const currentImpl = await proxyAdmin.getProxyImplementation(PROXY_ADDRESS);

console.log('Current implementation:', currentImpl);
console.log('Expected:', NEW_IMPLEMENTATION);
console.log('Upgrade successful:', currentImpl === NEW_IMPLEMENTATION);
```

### MultiVault Migration Upgrade

The MultiVault uses a special migration pattern to upgrade from MultiVaultMigrationMode to MultiVault after data migration is complete.

**Migration Steps:**

1. **Deploy MultiVaultMigrationMode**
   - Initial deployment with MIGRATOR_ROLE
   - Allows data migration from V1

2. **Migrate Data**
   - Use MIGRATOR_ROLE to set atom data
   - Set triple data
   - Set vault states
   - Set user balances

3. **Upgrade to MultiVault**
   - Deploy MultiVault implementation
   - Upgrade proxy via ProxyAdmin
   - Revoke MIGRATOR_ROLE permanently

**Script Example:**

```bash
# Deploy migration mode
forge script script/intuition/MultiVaultMigrationModeDeploy.s.sol \
  --rpc-url intuition_sepolia \
  --broadcast

# After migration complete, upgrade
forge script script/intuition/MultiVaultMigrationUpgrade.s.sol \
  --rpc-url intuition_sepolia \
  --broadcast
```

**Code Implementation:**

```solidity
// From MultiVaultMigrationUpgrade.s.sol
function run() public broadcast {
    // Deploy new implementation
    MultiVault multiVaultImpl = new MultiVault();

    // Upgrade proxy
    proxyAdmin.upgradeAndCall(
        ITransparentUpgradeableProxy(MULTIVAULT_PROXY),
        address(multiVaultImpl),
        "" // empty calldata
    );

    // Revoke migrator role permanently
    MultiVault(MULTIVAULT_PROXY).revokeRole(MIGRATOR_ROLE, ADMIN);

    // Verify revocation
    require(
        !MultiVault(MULTIVAULT_PROXY).hasRole(MIGRATOR_ROLE, ADMIN),
        "MIGRATOR_ROLE revoke failed"
    );
}
```

### Trust Token Upgrade

The Trust token requires special reinitialization when upgrading to add new features.

**Upgrade with Reinitialization:**

```typescript
// Generate reinitialize calldata
const trust = new ethers.Contract(TRUST_ADDRESS, TRUST_ABI, signer);
const reinitializeData = trust.interface.encodeFunctionData('reinitialize', [
  ADMIN_ADDRESS,
  BASE_EMISSIONS_CONTROLLER_ADDRESS
]);

// Generate upgrade and call data
const proxyAdmin = new ethers.Contract(PROXY_ADMIN_ADDRESS, PROXY_ADMIN_ABI, signer);
const upgradeData = proxyAdmin.interface.encodeFunctionData('upgradeAndCall', [
  TRUST_PROXY_ADDRESS,
  NEW_TRUST_IMPLEMENTATION,
  reinitializeData
]);

// Schedule via timelock
const timelock = new ethers.Contract(TIMELOCK_ADDRESS, TIMELOCK_ABI, signer);
await timelock.schedule(
  PROXY_ADMIN_ADDRESS,
  0,
  upgradeData,
  ethers.ZeroHash,
  ethers.id('trust-upgrade-v2'),
  MINIMUM_DELAY
);
```

**Utility Script:**

```bash
# Generate Trust V2 reinitialize calldata
npx tsx script/upgrades/generate-trust-v2-upgrade-calldata.ts \
  $ADMIN_ADDRESS \
  $BASE_EMISSIONS_CONTROLLER_ADDRESS

# Generate full upgrade calldata
npx tsx script/upgrades/generate-trust-proxy-upgrade-and-call-calldata.ts \
  $PROXY_ADMIN_ADDRESS \
  $NEW_IMPLEMENTATION \
  $REINITIALIZE_CALLDATA
```

## Storage Layouts

### Storage Gap Pattern

Upgradeable contracts use storage gaps to reserve space for future variables.

```solidity
contract Trust is ITrust, TrustToken, AccessControlUpgradeable {
    // V2 State
    address public baseEmissionsController;

    // Reserve 50 storage slots for future upgrades
    uint256[50] private __gap;
}
```

**Best Practices:**
- Always include storage gaps in upgradeable contracts
- Never remove or reorder existing state variables
- Only append new state variables at the end
- Reduce gap size when adding new variables
- Document storage layout changes

### Checking Storage Layout

```bash
# Generate storage layout
forge inspect MultiVault storageLayout > storage-layout.json

# Compare with previous version
diff storage-layout-v1.json storage-layout-v2.json
```

## Upgrade Safety Checks

### Pre-Upgrade Checklist

- [ ] Storage layout is compatible (no reordering/removal)
- [ ] All tests pass on forked mainnet
- [ ] Upgrade tested on testnet
- [ ] Implementation verified on block explorer
- [ ] ProxyAdmin has correct owner
- [ ] Timelock delay is appropriate
- [ ] Emergency pause mechanism available
- [ ] Rollback plan documented

### Using OpenZeppelin Upgrade Plugins

```bash
# Install plugin
npm install @openzeppelin/hardhat-upgrades

# Validate upgrade
npx hardhat run scripts/validate-upgrade.js
```

**Validation Script:**

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
  const MultiVaultV2 = await ethers.getContractFactory("MultiVaultV2");

  // Validate upgrade is safe
  await upgrades.validateUpgrade(PROXY_ADDRESS, MultiVaultV2, {
    kind: 'transparent'
  });

  console.log("Upgrade validation passed!");
}
```

## Emergency Procedures

### Upgrade Cancellation

If an issue is discovered during the timelock delay:

```typescript
// Cancel scheduled operation
const timelock = new ethers.Contract(TIMELOCK_ADDRESS, TIMELOCK_ABI, signer);
await timelock.cancel(operationId);

console.log('Upgrade cancelled');
```

### Rollback

If issues are discovered after upgrade:

```typescript
// Schedule rollback to previous implementation
const rollbackData = proxyAdmin.interface.encodeFunctionData('upgrade', [
  PROXY_ADDRESS,
  PREVIOUS_IMPLEMENTATION
]);

await timelock.schedule(
  PROXY_ADMIN_ADDRESS,
  0,
  rollbackData,
  ethers.ZeroHash,
  ethers.id('rollback-salt'),
  MINIMUM_DELAY
);
```

## Beacon Upgrades

### Upgrading All AtomWallets

```typescript
// Upgrade all atom wallets simultaneously
const beacon = new ethers.Contract(ATOM_WALLET_BEACON, BEACON_ABI, signer);
const newWalletImpl = '0x...'; // new AtomWallet implementation

// This immediately affects ALL wallet proxies
const tx = await beacon.upgradeTo(newWalletImpl);
await tx.wait();

console.log('All atom wallets upgraded to:', newWalletImpl);
```

**Testing Beacon Upgrade:**

```solidity
// Test beacon upgrade
function testBeaconUpgrade() public {
    // Deploy new implementation
    AtomWalletV2 newImpl = new AtomWalletV2();

    // Upgrade beacon
    vm.prank(BEACON_OWNER);
    atomWalletBeacon.upgradeTo(address(newImpl));

    // Verify all proxies use new implementation
    address impl = atomWalletBeacon.implementation();
    assertEq(impl, address(newImpl));

    // Test wallet still works
    IAtomWallet wallet = IAtomWallet(walletProxy);
    wallet.execute(target, value, data);
}
```

## Monitoring and Verification

### Post-Upgrade Checks

```typescript
// Comprehensive post-upgrade verification
async function verifyUpgrade() {
  const proxy = new ethers.Contract(PROXY_ADDRESS, ABI, provider);

  // 1. Check implementation
  const impl = await proxyAdmin.getProxyImplementation(PROXY_ADDRESS);
  console.log('Implementation:', impl);

  // 2. Test core functionality
  const balance = await proxy.balanceOf(TEST_ADDRESS);
  console.log('Balance query works:', balance.toString());

  // 3. Check access control
  const hasRole = await proxy.hasRole(DEFAULT_ADMIN_ROLE, ADMIN_ADDRESS);
  console.log('Admin role preserved:', hasRole);

  // 4. Verify state preservation
  const totalSupply = await proxy.totalSupply();
  console.log('State preserved, total supply:', totalSupply.toString());

  // 5. Check events
  const filter = proxy.filters.Upgraded();
  const events = await proxy.queryFilter(filter);
  console.log('Upgrade event emitted:', events.length > 0);
}
```

### Event Monitoring

```typescript
// Listen for upgrade events
const proxyAdmin = new ethers.Contract(PROXY_ADMIN_ADDRESS, PROXY_ADMIN_ABI, provider);

proxyAdmin.on('Upgraded', (proxy, implementation, event) => {
  console.log(`Proxy ${proxy} upgraded to ${implementation}`);
  console.log('Transaction:', event.transactionHash);

  // Trigger alerts/notifications
  sendAlert({
    type: 'UPGRADE',
    proxy,
    implementation,
    txHash: event.transactionHash
  });
});
```

## Common Issues and Solutions

### Issue: Storage Collision

**Problem:** New implementation has conflicting storage layout.

**Solution:**
```solidity
// DON'T: Reorder or remove variables
contract BadUpgrade {
    uint256 public newVar; // WRONG - inserted before existing vars
    uint256 public existingVar;
}

// DO: Append new variables
contract GoodUpgrade {
    uint256 public existingVar;
    uint256 public newVar; // CORRECT - appended after existing
}
```

### Issue: Initialization Function Called Twice

**Problem:** Initialize function can be called on upgraded contract.

**Solution:**
```solidity
// Use reinitializer with version
function reinitialize(address _admin) external reinitializer(2) {
    // Version 2 initialization logic
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
}
```

### Issue: Delegate Call Vulnerability

**Problem:** Implementation has constructor that sets state.

**Solution:**
```solidity
// DON'T: Use constructor
contract BadImpl {
    constructor() {
        admin = msg.sender; // Won't work in proxy context
    }
}

// DO: Use initializer
contract GoodImpl {
    function initialize(address _admin) external initializer {
        admin = _admin; // Works correctly
    }
}
```

## Resources

### Utility Scripts

```bash
# Update timelock delay
npx tsx script/upgrades/generate-timelock-update-delay-calldata.ts \
  $RPC_URL \
  $NEW_DELAY_SECONDS

# Generate timelock schedule parameters
npx tsx script/upgrades/generate-timelock-upgrade-and-call-calldata.ts \
  $RPC_URL \
  $PROXY_ADDRESS \
  $IMPLEMENTATION_ADDRESS \
  $REINITIALIZE_CALLDATA
```

### Documentation

- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: UUPS](https://eips.ethereum.org/EIPS/eip-1822)
- [Writing Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)

## See Also

- [Access Control](./access-control.md) - Role-based upgrade permissions
- [Timelock Governance](./timelock-governance.md) - Timelock mechanisms
- [Emergency Procedures](./emergency-procedures.md) - Upgrade rollback procedures
- [Security Considerations](./security-considerations.md) - Upgrade security best practices

---

**Last Updated**: December 2025
