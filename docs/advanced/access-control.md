# Access Control

Comprehensive guide to role-based access control (RBAC) and permission management in Intuition Protocol V2.

## Overview

Intuition Protocol V2 uses OpenZeppelin's AccessControl pattern to manage permissions across all contracts. This enables fine-grained control over who can perform critical operations while maintaining security and decentralization.

## Core Concepts

### Role-Based Access Control (RBAC)

Instead of using a simple owner pattern, the protocol implements roles that can be granted to multiple addresses. This allows:

- **Separation of concerns**: Different roles for different operations
- **Multi-signature safety**: Roles can be held by multisig wallets
- **Granular permissions**: Specific roles for specific actions
- **Auditability**: Clear role hierarchy and assignments

### Role Hierarchy

```
DEFAULT_ADMIN_ROLE (Master Admin)
    ├── Can grant/revoke all other roles
    ├── Typically held by: Multisig or Timelock
    └── Controls critical protocol parameters
        │
        ├── PAUSER_ROLE
        │   └── Emergency pause authority
        │
        ├── CONTROLLER_ROLE
        │   └── Emissions and minting control
        │
        ├── OPERATOR_ROLE
        │   └── Operational functions
        │
        ├── MIGRATOR_ROLE (Temporary)
        │   └── Data migration authority
        │
        └── UPKEEP_ROLE
            └── Automation and maintenance
```

## Role Definitions

### DEFAULT_ADMIN_ROLE

The master admin role that can manage all other roles.

**Responsibilities:**
- Grant and revoke roles
- Update critical protocol parameters
- Set contract addresses and configurations
- Initiate upgrades (via Timelock)

**Current Holders:**
- Base Mainnet: Upgrades TimelockController (`0x1E442BbB08c98100b18fa830a88E8A57b5dF9157`)
- Intuition Mainnet: Upgrades TimelockController (`0x321e5d4b20158648dFd1f360A79CAFc97190bAd1`)

**Contracts Using This Role:**
- Trust
- MultiVault
- BaseEmissionsController
- SatelliteEmissionsController
- TrustBonding
- All supporting contracts

**Example Operations:**
```solidity
// Grant a role
function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE);

// Revoke a role
function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE);

// Set critical parameters
function setBaseEmissionsController(address controller) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### PAUSER_ROLE

Authority to pause and unpause protocol operations in emergency situations.

**Role Identifier:**
```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

**Responsibilities:**
- Pause protocol operations during emergencies
- Unpause after issues are resolved
- Quick response to security threats

**Contracts with Pause Functionality:**
- MultiVault
- TrustBonding

**Usage Example:**
```typescript
import { ethers } from 'ethers';

// Pause MultiVault in emergency
const multiVault = new ethers.Contract(MULTIVAULT_ADDRESS, ABI, pauser);
const tx = await multiVault.pause();
await tx.wait();
console.log('MultiVault paused');

// Later, unpause after issue resolved
const unpauseTx = await multiVault.unpause();
await unpauseTx.wait();
console.log('MultiVault unpaused');
```

**Security Considerations:**
- Should be held by security multisig with fast response time
- Consider using multiple signers with lower threshold
- Monitor for unauthorized pause attempts
- Document pause/unpause procedures

### CONTROLLER_ROLE

Authority to control emissions, minting, and cross-chain operations.

**Role Identifier:**
```solidity
bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
```

**Responsibilities:**
- Trigger epoch rollovers
- Bridge emissions between chains
- Control minting schedules
- Manage emission parameters

**Contracts Using This Role:**
- BaseEmissionsController
- SatelliteEmissionsController

**Current Assignments:**
- BaseEmissionsController: Held by authorized automation
- SatelliteEmissionsController: Held by BaseEmissionsController bridge

**Example Operations:**
```solidity
// BaseEmissionsController - advance epoch and distribute
function advanceEpochAndDistribute(
    uint256 epochId,
    uint256 amount
) external onlyRole(CONTROLLER_ROLE);

// SatelliteEmissionsController - receive bridged emissions
function receiveEmissions(
    uint256 epochId,
    uint256 amount
) external onlyRole(CONTROLLER_ROLE);
```

### OPERATOR_ROLE

Authority to perform operational functions without full admin privileges.

**Role Identifier:**
```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```

**Responsibilities:**
- Sweep protocol fees
- Perform routine maintenance
- Execute non-critical operations

**Usage in SatelliteEmissionsController:**
```solidity
// Sweep accumulated protocol fees
function sweepAccumulatedFees(
    uint256 epochId,
    address recipient
) external onlyRole(OPERATOR_ROLE);
```

### MIGRATOR_ROLE

Temporary role for data migration from V1 to V2 (should be revoked after migration).

**Role Identifier:**
```solidity
bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
```

**Responsibilities:**
- Migrate atom and triple data
- Set vault states
- Set user balances
- Transfer assets to back migrated shares

**Contract:**
- MultiVaultMigrationMode (only)

**Critical Security Requirements:**
- MUST be revoked after migration complete
- Cannot be regranted after revocation
- Held by secure migration script runner

**Migration Operations:**
```solidity
// Set term count
function setTermCount(uint256 _termCount) external onlyRole(MIGRATOR_ROLE);

// Batch set atom data
function batchSetAtomData(
    address[] calldata creators,
    bytes[] calldata atomDataArray
) external onlyRole(MIGRATOR_ROLE);

// Set vault totals
function setVaultTotals(
    bytes32[] calldata termIds,
    uint256 curveId,
    VaultTotals[] calldata totals
) external onlyRole(MIGRATOR_ROLE);
```

**Revocation Process:**
```solidity
// After migration complete, permanently revoke
function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE);

// Verify revocation
bool hasRole = contract.hasRole(MIGRATOR_ROLE, account);
require(!hasRole, "MIGRATOR_ROLE still active");
```

### UPKEEP_ROLE

Authority to trigger automated maintenance and upkeep functions.

**Role Identifier:**
```solidity
bytes32 public constant UPKEEP_ROLE = keccak256("UPKEEP_ROLE");
```

**Responsibilities:**
- Trigger epoch advancements via automation
- Execute scheduled maintenance
- Perform health checks

**Contract:**
- EmissionsAutomationAdapter

**Integration with Chainlink Automation:**
```solidity
// Called by Chainlink Keeper
function performUpkeep(bytes calldata performData) external onlyRole(UPKEEP_ROLE) {
    // Decode and execute upkeep
    (uint256 epochId, uint256 amount) = abi.decode(performData, (uint256, uint256));
    baseEmissionsController.advanceEpochAndDistribute(epochId, amount);
}
```

## Permission Patterns

### Checking Permissions

```solidity
// Check if address has role
bool hasRole = contract.hasRole(PAUSER_ROLE, address);

// Get role admin (who can grant/revoke this role)
bytes32 adminRole = contract.getRoleAdmin(PAUSER_ROLE);
```

**TypeScript Example:**
```typescript
import { ethers } from 'ethers';

const contract = new ethers.Contract(ADDRESS, ABI, provider);

// Check if address is admin
const isAdmin = await contract.hasRole(
  await contract.DEFAULT_ADMIN_ROLE(),
  checkAddress
);

console.log(`${checkAddress} is admin: ${isAdmin}`);
```

### Granting Roles

```typescript
// Grant role (must be called by role admin)
const contract = new ethers.Contract(ADDRESS, ABI, adminSigner);

const PAUSER_ROLE = ethers.id('PAUSER_ROLE');
const tx = await contract.grantRole(PAUSER_ROLE, newPauserAddress);
await tx.wait();

console.log(`PAUSER_ROLE granted to ${newPauserAddress}`);
```

### Revoking Roles

```typescript
// Revoke role
const tx = await contract.revokeRole(PAUSER_ROLE, oldPauserAddress);
await tx.wait();

// Verify revocation
const stillHasRole = await contract.hasRole(PAUSER_ROLE, oldPauserAddress);
console.log(`Role revoked: ${!stillHasRole}`);
```

### Renouncing Roles

```typescript
// Address can renounce its own role
const tx = await contract.renounceRole(OPERATOR_ROLE, myAddress);
await tx.wait();

console.log('Role renounced');
```

## Multi-Contract Role Management

### Trust Token

**Roles:**
- `DEFAULT_ADMIN_ROLE`: Protocol multisig/timelock
  - Can update baseEmissionsController address
  - Manage contract parameters

**Access Pattern:**
```solidity
// Only BaseEmissionsController can mint
modifier onlyBaseEmissionsController() {
    if (msg.sender != baseEmissionsController) {
        revert Trust_OnlyBaseEmissionsController();
    }
    _;
}

function mint(address to, uint256 amount) public onlyBaseEmissionsController {
    _mint(to, amount);
}
```

### MultiVault

**Roles:**
- `DEFAULT_ADMIN_ROLE`: Upgrades timelock
  - Configure protocol parameters
  - Set fee structures
  - Update contract addresses

**Key Protected Functions:**
```solidity
// Update atom cost
function setAtomCost(uint256 _atomCost) external onlyRole(DEFAULT_ADMIN_ROLE);

// Update fees
function setProtocolFee(uint256 _protocolFee) external onlyRole(DEFAULT_ADMIN_ROLE);

// Set TrustBonding address
function setTrustBonding(address _trustBonding) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### BaseEmissionsController

**Roles:**
- `DEFAULT_ADMIN_ROLE`: Upgrades timelock
- `CONTROLLER_ROLE`: Automation adapter

**Protected Operations:**
```solidity
// Advance epoch (automation)
function advanceEpochAndDistribute(
    uint256 epochId,
    uint256 amount
) external onlyRole(CONTROLLER_ROLE);

// Update emissions parameters (admin)
function setEmissionsPerEpoch(
    uint256 _emissionsPerEpoch
) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### TrustBonding

**Roles:**
- `DEFAULT_ADMIN_ROLE`: Upgrades timelock
- `PAUSER_ROLE`: Security multisig

**Protected Operations:**
```solidity
// Emergency pause
function pause() external onlyRole(PAUSER_ROLE);
function unpause() external onlyRole(PAUSER_ROLE);

// Admin functions
function setUtilizationLowerBound(
    uint256 _lowerBound
) external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Security Best Practices

### 1. Use Multi-Signature Wallets

```typescript
// Example: Gnosis Safe as DEFAULT_ADMIN_ROLE holder
const GNOSIS_SAFE = '0x...';
await contract.grantRole(DEFAULT_ADMIN_ROLE, GNOSIS_SAFE);
```

**Recommended Thresholds:**
- DEFAULT_ADMIN_ROLE: 3-of-5 or 4-of-7
- PAUSER_ROLE: 2-of-3 (faster response)
- OPERATOR_ROLE: 2-of-3

### 2. Time-Lock Critical Operations

```typescript
// Use TimelockController for admin role
const TIMELOCK = '0x...';
await contract.grantRole(DEFAULT_ADMIN_ROLE, TIMELOCK);

// Now all admin actions require timelock delay
```

### 3. Minimal Privilege Principle

```solidity
// DON'T: Give DEFAULT_ADMIN_ROLE to everything
contract.grantRole(DEFAULT_ADMIN_ROLE, operator); // TOO POWERFUL

// DO: Give minimal necessary role
contract.grantRole(OPERATOR_ROLE, operator); // APPROPRIATE
```

### 4. Regular Role Audits

```typescript
// Audit script to check all role assignments
async function auditRoles() {
  const contracts = [MULTIVAULT, TRUST, BASE_EMISSIONS];

  for (const addr of contracts) {
    const contract = new ethers.Contract(addr, ABI, provider);

    console.log(`\nContract: ${addr}`);

    // Check DEFAULT_ADMIN_ROLE
    const adminRole = await contract.DEFAULT_ADMIN_ROLE();
    const admins = await getRoleMembers(contract, adminRole);
    console.log('Admins:', admins);

    // Check PAUSER_ROLE if exists
    try {
      const pauserRole = await contract.PAUSER_ROLE();
      const pausers = await getRoleMembers(contract, pauserRole);
      console.log('Pausers:', pausers);
    } catch {}
  }
}
```

### 5. Event Monitoring

```typescript
// Monitor role changes
const contract = new ethers.Contract(ADDRESS, ABI, provider);

contract.on('RoleGranted', (role, account, sender, event) => {
  console.log(`Role ${role} granted to ${account} by ${sender}`);

  // Send alert for critical role changes
  if (role === DEFAULT_ADMIN_ROLE) {
    sendSecurityAlert({
      type: 'ROLE_GRANTED',
      role: 'DEFAULT_ADMIN_ROLE',
      account,
      sender,
      txHash: event.transactionHash
    });
  }
});

contract.on('RoleRevoked', (role, account, sender, event) => {
  console.log(`Role ${role} revoked from ${account} by ${sender}`);
});
```

## Common Operations

### Check All Role Members

```typescript
import { ethers } from 'ethers';

async function getRoleMembers(contract, role) {
  // Note: This requires indexing role events
  const filter = contract.filters.RoleGranted(role);
  const grantEvents = await contract.queryFilter(filter);

  const members = new Set();

  for (const event of grantEvents) {
    members.add(event.args.account);
  }

  // Remove any that were revoked
  const revokeFilter = contract.filters.RoleRevoked(role);
  const revokeEvents = await contract.queryFilter(revokeFilter);

  for (const event of revokeEvents) {
    members.delete(event.args.account);
  }

  return Array.from(members);
}
```

### Batch Role Operations

```typescript
// Grant multiple roles in single transaction
async function grantRoleBatch(contract, role, accounts) {
  const calls = accounts.map(account =>
    contract.interface.encodeFunctionData('grantRole', [role, account])
  );

  // Use multicall if available
  await contract.multicall(calls);
}
```

### Safe Role Transfer

```typescript
// Safely transfer admin role to new address
async function transferAdminRole(contract, newAdmin) {
  const adminRole = await contract.DEFAULT_ADMIN_ROLE();
  const currentAdmin = await getCurrentAdmin(contract, adminRole);

  // 1. Grant to new admin
  await contract.grantRole(adminRole, newAdmin);

  // 2. Verify new admin has role
  const hasRole = await contract.hasRole(adminRole, newAdmin);
  if (!hasRole) throw new Error('Role grant failed');

  // 3. Revoke from old admin
  await contract.revokeRole(adminRole, currentAdmin);

  // 4. Verify old admin doesn't have role
  const stillHasRole = await contract.hasRole(adminRole, currentAdmin);
  if (stillHasRole) throw new Error('Role revoke failed');

  console.log(`Admin role transferred from ${currentAdmin} to ${newAdmin}`);
}
```

## Testing Access Control

### Foundry Tests

```solidity
// Test role-based access
function testOnlyAdminCanSetParameters() public {
    // Should succeed with admin
    vm.prank(admin);
    multiVault.setAtomCost(1 ether);

    // Should revert with non-admin
    vm.prank(user);
    vm.expectRevert();
    multiVault.setAtomCost(1 ether);
}

function testPauserCanPause() public {
    // Grant pauser role
    vm.prank(admin);
    multiVault.grantRole(PAUSER_ROLE, pauser);

    // Pauser can pause
    vm.prank(pauser);
    multiVault.pause();

    assertTrue(multiVault.paused());
}

function testRoleTransfer() public {
    bytes32 role = OPERATOR_ROLE;

    // Grant role
    vm.prank(admin);
    contract.grantRole(role, user1);

    assertTrue(contract.hasRole(role, user1));

    // Revoke role
    vm.prank(admin);
    contract.revokeRole(role, user1);

    assertFalse(contract.hasRole(role, user1));
}
```

## Troubleshooting

### Error: AccessControl: account is missing role

**Cause:** Attempting operation without required role.

**Solution:**
```typescript
// Check if account has role
const hasRole = await contract.hasRole(requiredRole, accountAddress);
if (!hasRole) {
  console.log('Account missing role, requesting grant from admin...');
  // Request admin to grant role
}
```

### Error: Cannot renounce role

**Cause:** Trying to renounce last admin role.

**Solution:**
```solidity
// Ensure at least one admin remains
function safeRenounceRole(bytes32 role, address account) external {
    if (role == DEFAULT_ADMIN_ROLE) {
        require(getRoleMemberCount(role) > 1, "Cannot renounce last admin");
    }
    renounceRole(role, account);
}
```

## Resources

### Contract References

- [MultiVault Access Control](../contracts/core/MultiVault.md#access-control)
- [Trust Access Control](../contracts/core/Trust.md#access-control)
- [BaseEmissionsController](../contracts/emissions/BaseEmissionsController.md)
- [TrustBonding](../contracts/emissions/TrustBonding.md)

### External Documentation

- [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/access-control)
- [Role-Based Access Control Patterns](https://docs.openzeppelin.com/contracts/4.x/api/access#AccessControl)

## See Also

- [Upgradeability](./upgradeability.md) - Admin roles in upgrade procedures
- [Timelock Governance](./timelock-governance.md) - Timelock as admin role holder
- [Emergency Procedures](./emergency-procedures.md) - PAUSER_ROLE usage
- [Security Considerations](./security-considerations.md) - Role security best practices

---

**Last Updated**: December 2025
