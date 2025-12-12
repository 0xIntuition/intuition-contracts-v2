# Security Considerations

Comprehensive security best practices, common vulnerabilities, and audit findings for Intuition Protocol V2.

## Overview

This document outlines security considerations for developers integrating with Intuition Protocol V2, covering smart contract security, access control, upgrade safety, and operational security.

## Smart Contract Security

### 1. Reentrancy Protection

All state-changing functions in MultiVault use OpenZeppelin's ReentrancyGuard.

**Protected Functions:**
- `deposit()`, `depositTriple()`
- `redeem()`
- `batchDeposit()`, `batchRedeem()`
- `createAtom()`, `createTriple()`

**Best Practice:**
```solidity
// Checks-Effects-Interactions pattern is enforced
function deposit(/*...*/) external nonReentrant {
    // 1. Checks
    require(assets > 0, "Invalid amount");

    // 2. Effects (state changes)
    vaultState.totalAssets += assetsAfterFees;
    vaultState.totalShares += shares;

    // 3. Interactions (external calls)
    IERC20(asset).transferFrom(sender, address(this), assets);
}
```

### 2. Integer Overflow/Underflow

Solidity 0.8.29 has built-in overflow/underflow protection.

**Additional Protections:**
```solidity
// Use SafeMath-like operations via FixedPointMathLib
using FixedPointMathLib for uint256;

uint256 result = a.mulDiv(b, c); // Safe multiplication and division
```

### 3. Access Control

All admin functions protected by role-based access control.

**Security Checklist:**
- [ ] All sensitive functions have role checks
- [ ] DEFAULT_ADMIN_ROLE held by timelock or multisig
- [ ] PAUSER_ROLE held by security team
- [ ] Roles documented and audited

### 4. Initialization Security

Upgradeable contracts use initializers instead of constructors.

**Best Practice:**
```solidity
function initialize(/*...*/) external initializer {
    __AccessControl_init();
    __ReentrancyGuard_init();
    __Pausable_init();

    // Set initial state
}

// Prevent reinitialization
function reinitialize(/*...*/) external reinitializer(2) {
    // Version 2 initialization
}
```

### 5. Storage Layout

**Critical Rules:**
- Never reorder state variables in upgrades
- Never remove state variables in upgrades
- Always append new variables at end
- Use storage gaps for future expansion

```solidity
contract UpgradeableContract {
    // Existing state
    uint256 public var1;
    uint256 public var2;

    // New state (append only)
    uint256 public var3; // OK

    // Reserve gap
    uint256[47] private __gap; // Reduced from 50
}
```

## Common Vulnerabilities

### 1. Front-Running

**Risk:** Attackers see pending transactions and submit higher gas price transactions.

**Mitigations:**
```solidity
// Use receiver parameter to prevent front-running benefit theft
function deposit(
    bytes32 termId,
    uint256 curveId,
    uint256 assets,
    address receiver // Shares go to receiver, not msg.sender
) external;
```

**User Best Practice:**
```typescript
// Use private mempools or flashbots
// Set maximum slippage tolerance
// Use receiver address different from sender if needed
```

### 2. MEV (Maximal Extractable Value)

**Risk:** Block proposers can reorder transactions for profit.

**Mitigations:**
- Bonding curves reduce arbitrage opportunities
- Entry/exit fees discourage rapid trading
- Batching reduces transaction count

### 3. Flash Loan Attacks

**Risk:** Attackers borrow large amounts to manipulate prices.

**Mitigations:**
- Bonding curves are resistant to single-block manipulation
- No reliance on spot prices from external sources
- Utilization tracking happens over epochs, not blocks

### 4. Approval Front-Running

**Risk:** Approval transactions can be front-run.

**Best Practice:**
```typescript
// Use permit where available (EIP-2612)
// Or set approval to 0 before changing
await token.approve(spender, 0);
await token.approve(spender, newAmount);

// Better: Use increaseAllowance/decreaseAllowance
await token.increaseAllowance(spender, additionalAmount);
```

## Access Control Security

### Role Management

**Best Practices:**

1. **Use Multi-Signature Wallets**
   ```typescript
   const MULTISIG = '0x...'; // Gnosis Safe
   await contract.grantRole(DEFAULT_ADMIN_ROLE, MULTISIG);
   ```

2. **Time-Lock Critical Operations**
   ```typescript
   const TIMELOCK = '0x...';
   await contract.grantRole(DEFAULT_ADMIN_ROLE, TIMELOCK);
   ```

3. **Separate Operational Roles**
   ```typescript
   // Different roles for different responsibilities
   await contract.grantRole(PAUSER_ROLE, SECURITY_MULTISIG);
   await contract.grantRole(OPERATOR_ROLE, OPERATIONS_MULTISIG);
   ```

4. **Regular Audits**
   ```typescript
   // Quarterly role audits
   async function auditRoles() {
     const adminRole = await contract.DEFAULT_ADMIN_ROLE();
     const admins = await getRoleMembers(contract, adminRole);
     console.log('Current admins:', admins);
     // Verify against expected list
   }
   ```

### Private Key Security

**Best Practices:**
- Use hardware wallets for admin keys
- Store keys in secure key management systems
- Implement key rotation procedures
- Use MPC (Multi-Party Computation) wallets
- Never commit private keys to version control

## Upgrade Security

### Pre-Upgrade Checklist

- [ ] Storage layout verified compatible
- [ ] All tests passing on mainnet fork
- [ ] Upgrade tested on testnet
- [ ] Timelock delay appropriate (48-72 hours)
- [ ] Emergency pause available
- [ ] Rollback plan documented
- [ ] Community notified

### Storage Collision Prevention

```bash
# Generate and compare storage layouts
forge inspect MultiVaultV1 storageLayout > v1-storage.json
forge inspect MultiVaultV2 storageLayout > v2-storage.json

# Manually compare or use diff tool
diff v1-storage.json v2-storage.json
```

### Initialize Function Security

```solidity
// DON'T: Allow reinitialization
function initialize(address _admin) external initializer {
    admin = _admin;
}

// DO: Use versioned reinitializer
function initialize(address _admin) external initializer {
    admin = _admin;
}

function reinitialize_v2(address _newParam) external reinitializer(2) {
    newParam = _newParam;
}
```

## Operational Security

### 1. Monitoring

**Set Up Alerts:**
```typescript
// Monitor critical events
contract.on('Paused', (account) => {
  sendAlert({
    severity: 'CRITICAL',
    message: `Contract paused by ${account}`
  });
});

contract.on('RoleGranted', (role, account, sender) => {
  if (role === DEFAULT_ADMIN_ROLE) {
    sendAlert({
      severity: 'HIGH',
      message: `Admin role granted to ${account}`
    });
  }
});
```

### 2. Rate Limiting

Consider implementing off-chain rate limiting for API access to prevent DoS.

### 3. Incident Response

**Preparation:**
- Document emergency procedures
- Maintain emergency contact list
- Practice incident response drills
- Keep pause/unpause scripts ready

**Response:**
1. Detect anomaly
2. Pause affected contracts
3. Assess impact
4. Develop fix
5. Deploy fix via timelock
6. Unpause after validation
7. Post-mortem report

## Integration Security

### For SDK Developers

**Validation:**
```typescript
// Always validate inputs
function deposit(termId: string, curveId: number, assets: bigint) {
  if (!termId || termId.length !== 66) {
    throw new Error('Invalid termId');
  }

  if (curveId < 0) {
    throw new Error('Invalid curveId');
  }

  if (assets <= 0n) {
    throw new Error('Invalid assets amount');
  }

  // Proceed with deposit
}
```

**Error Handling:**
```typescript
try {
  const tx = await multiVault.deposit(termId, curveId, assets, receiver);
  await tx.wait();
} catch (error) {
  if (error.message.includes('MultiVault_InsufficientAllowance')) {
    // Handle approval needed
  } else if (error.message.includes('Pausable: paused')) {
    // Handle paused state
  } else {
    // Handle unknown error
    throw error;
  }
}
```

### For Application Developers

**User Input Sanitization:**
```typescript
// Sanitize atom data
function sanitizeAtomData(input: string): Uint8Array {
  // Validate length
  const bytes = toBytes(input);
  if (bytes.length > 256) {
    throw new Error('Atom data too long');
  }

  // Check for malicious content
  if (containsMaliciousPatterns(input)) {
    throw new Error('Invalid atom data');
  }

  return bytes;
}
```

**Slippage Protection:**
```typescript
// Calculate minimum shares expected
const expectedShares = await multiVault.previewDeposit(termId, curveId, assets);
const minShares = expectedShares * 95n / 100n; // 5% slippage

// Revert if slippage too high
const actualShares = await multiVault.deposit(termId, curveId, assets, receiver);
if (actualShares < minShares) {
  throw new Error('Slippage too high');
}
```

## Audit Findings

### Historical Issues (Hypothetical)

**Finding 1: Reentrancy in deposit function**
- **Severity:** High
- **Status:** Fixed
- **Fix:** Added ReentrancyGuard to all state-changing functions

**Finding 2: Missing zero address checks**
- **Severity:** Medium
- **Status:** Fixed
- **Fix:** Added require statements for all address parameters

**Finding 3: Lack of pause mechanism**
- **Severity:** Medium
- **Status:** Fixed
- **Fix:** Implemented Pausable pattern with PAUSER_ROLE

### Ongoing Security

**Regular Audits:**
- Annual comprehensive audits by reputable firms
- Continuous automated security monitoring
- Bug bounty program

**Bug Bounty:**
- Contact security team before public disclosure
- Rewards based on severity
- Responsible disclosure policy

## Testing Security

### Foundry Security Tests

```solidity
// Test reentrancy protection
function testReentrancyProtection() public {
    ReentrancyAttacker attacker = new ReentrancyAttacker(multiVault);

    vm.expectRevert("ReentrancyGuard: reentrant call");
    attacker.attack();
}

// Test access control
function testOnlyAdminCanSetParameters() public {
    vm.prank(user);
    vm.expectRevert();
    multiVault.setAtomCost(1 ether);

    vm.prank(admin);
    multiVault.setAtomCost(1 ether); // Should succeed
}

// Test pause functionality
function testCannotDepositWhenPaused() public {
    vm.prank(pauser);
    multiVault.pause();

    vm.prank(user);
    vm.expectRevert("Pausable: paused");
    multiVault.deposit(termId, curveId, assets, user);
}
```

## Best Practices Summary

### Smart Contract Development

1. ✅ Use latest audited OpenZeppelin contracts
2. ✅ Implement comprehensive test coverage (>90%)
3. ✅ Use reentrancy guards on all state-changing functions
4. ✅ Follow checks-effects-interactions pattern
5. ✅ Use role-based access control
6. ✅ Implement pausable pattern for emergencies
7. ✅ Add storage gaps for upgradeability
8. ✅ Validate all inputs
9. ✅ Use safe math operations
10. ✅ Document all functions with NatSpec

### Integration Development

1. ✅ Validate all user inputs
2. ✅ Handle all error cases
3. ✅ Implement retry logic for network failures
4. ✅ Use slippage protection
5. ✅ Monitor for unusual activity
6. ✅ Implement rate limiting
7. ✅ Use secure key management
8. ✅ Regular security updates
9. ✅ Log security-relevant events
10. ✅ Have incident response plan

### Operations

1. ✅ Use multi-signature wallets
2. ✅ Implement timelock for upgrades
3. ✅ Regular role audits
4. ✅ Monitor critical events
5. ✅ Practice emergency procedures
6. ✅ Maintain documentation
7. ✅ Communicate with community
8. ✅ Regular security training
9. ✅ Incident response drills
10. ✅ Post-mortem after incidents

## Resources

### Security Tools

- **Slither**: Static analysis tool
  ```bash
  pip3 install slither-analyzer
  slither src/protocol/MultiVault.sol
  ```

- **Echidna**: Fuzzing tool
  ```bash
  echidna-test . --contract MultiVault --config echidna.yaml
  ```

- **Mythril**: Symbolic execution
  ```bash
  myth analyze src/protocol/MultiVault.sol
  ```

### Documentation

- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/4.x/api/security)
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)

## Reporting Security Issues

**Contact:**
- Email: security@intuition.systems
- Discord: #security channel
- Bug Bounty: TBA

**Please DO NOT:**
- Open public GitHub issues for security vulnerabilities
- Discuss vulnerabilities in public channels
- Exploit vulnerabilities on mainnet

**Please DO:**
- Contact security team privately
- Provide detailed reproduction steps
- Allow time for fix before disclosure

## See Also

- [Access Control](./access-control.md) - Role-based security
- [Emergency Procedures](./emergency-procedures.md) - Incident response
- [Upgradeability](./upgradeability.md) - Secure upgrades
- [Timelock Governance](./timelock-governance.md) - Governance security

---

**Last Updated**: December 2025
