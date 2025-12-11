# Emergency Procedures

Comprehensive guide to pause mechanisms, emergency responses, and incident management in Intuition Protocol V2.

## Overview

Intuition Protocol V2 implements emergency pause mechanisms to protect users and protocol assets during security incidents or unexpected behavior. This guide covers the pause system, emergency response procedures, and recovery processes.

## Pause Mechanism

### Architecture

The protocol uses OpenZeppelin's Pausable pattern to halt critical operations during emergencies.

**Contracts with Pause Functionality:**
- **MultiVault**: Pauses deposits and redemptions
- **TrustBonding**: Pauses locking, extending, and reward claims

**Non-Pausable Contracts:**
- **Trust token**: Token transfers always enabled
- **BaseEmissionsController**: Emissions continue (but distributions may pause)
- **AtomWallet**: Individual wallet operations continue

### Pause States

```
┌─────────────┐
│   Normal    │
│  Operation  │
└──────┬──────┘
       │ pause()
       ▼
┌─────────────┐
│   Paused    │
│   State     │
└──────┬──────┘
       │ unpause()
       ▼
┌─────────────┐
│   Normal    │
│  Operation  │
└─────────────┘
```

## Pause Authority

### PAUSER_ROLE

Authority to pause and unpause contracts in emergencies.

**Role Identifier:**
```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

**Recommended Holders:**
- Security multisig (fast response capability)
- Emergency response team leads
- Automated monitoring systems (with strict conditions)

**Current Assignments:**
- MultiVault: Security multisig
- TrustBonding: Security multisig

## Emergency Scenarios

### 1. Security Vulnerability Discovered

**Indicators:**
- Security researcher report
- Unusual contract behavior detected
- Audit finding requiring immediate action

**Response Procedure:**

```typescript
// STEP 1: Immediate Pause
import { ethers } from 'ethers';

async function emergencyPause(reason: string) {
  console.log(`EMERGENCY PAUSE: ${reason}`);

  const contracts = [
    { name: 'MultiVault', address: MULTIVAULT_ADDRESS, abi: MULTIVAULT_ABI },
    { name: 'TrustBonding', address: TRUSTBONDING_ADDRESS, abi: TRUSTBONDING_ABI }
  ];

  for (const contract of contracts) {
    try {
      const instance = new ethers.Contract(
        contract.address,
        contract.abi,
        pauserSigner
      );

      const tx = await instance.pause();
      await tx.wait();

      console.log(`${contract.name} paused: ${tx.hash}`);

      // Send alert
      await sendCriticalAlert({
        type: 'CONTRACT_PAUSED',
        contract: contract.name,
        reason,
        txHash: tx.hash
      });
    } catch (error) {
      console.error(`Failed to pause ${contract.name}:`, error);
    }
  }
}

// STEP 2: Assess Situation
async function assessSituation() {
  // 1. Document the issue
  const report = {
    timestamp: Date.now(),
    severity: 'CRITICAL',
    affectedContracts: ['MultiVault', 'TrustBonding'],
    description: '...',
    potentialExposure: '...'
  };

  // 2. Gather data
  const state = await gatherProtocolState();

  // 3. Notify stakeholders
  await notifyStakeholders(report);

  return { report, state };
}

// STEP 3: Develop Fix
// - Create patch or upgrade
// - Test thoroughly on fork
// - Prepare deployment

// STEP 4: Deploy Fix
// - Deploy new implementation
// - Schedule upgrade via Timelock
// - Or use emergency upgrade path if available

// STEP 5: Unpause
async function unpauseAfterFix(contractAddress: string, contractABI: any) {
  const contract = new ethers.Contract(contractAddress, contractABI, pauserSigner);

  const tx = await contract.unpause();
  await tx.wait();

  console.log('Contract unpaused:', tx.hash);

  await sendNotification({
    type: 'CONTRACT_UNPAUSED',
    contract: contractAddress,
    txHash: tx.hash
  });
}
```

### 2. Oracle Manipulation Detected

**Indicators:**
- Abnormal price movements
- MEV attack detected
- External dependency compromised

**Response:**
```typescript
// Quick pause while investigating
await emergencyPause('Potential oracle manipulation detected');

// Investigate price data
async function investigatePrices() {
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    provider
  );

  // Check recent deposits/redemptions
  const filter = multiVault.filters.Deposited();
  const events = await multiVault.queryFilter(filter, -1000); // Last 1000 blocks

  // Analyze for suspicious patterns
  for (const event of events) {
    const { assets, shares, termId } = event.args;
    // Check if ratio is anomalous
  }
}
```

### 3. Smart Contract Exploit Attempt

**Indicators:**
- Failed transactions from attacker
- Unusual gas usage patterns
- Multiple failed calls to sensitive functions

**Response:**
```typescript
// Immediate pause
await emergencyPause('Exploit attempt detected');

// Block attacker address if possible
// (Note: Most contracts don't have blacklist functionality)

// Review transaction patterns
async function analyzeSuspiciousActivity(suspiciousAddress: string) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Get transaction history
  const txs = await provider.getHistory(suspiciousAddress);

  console.log(`Analyzing ${txs.length} transactions from ${suspiciousAddress}`);

  for (const tx of txs) {
    // Analyze transaction data
    const receipt = await tx.wait();
    console.log(`Tx: ${tx.hash}, Status: ${receipt.status}`);
  }
}
```

### 4. Bridge/Cross-Chain Issue

**Indicators:**
- Failed bridge messages
- Emissions not arriving on satellite chain
- MetaERC20 sync issues

**Response:**
```typescript
// Pause satellite chain operations
const satelliteEmissions = new ethers.Contract(
  SATELLITE_EMISSIONS_ADDRESS,
  SATELLITE_EMISSIONS_ABI,
  pauserSigner
);

// Note: SatelliteEmissionsController may not have pause
// Check with admin functions instead

// Investigate bridge status
async function checkBridgeHealth() {
  // Check pending bridge messages
  // Verify state consistency
  // Contact bridge operator if needed
}
```

## Pause Operations

### Pausing MultiVault

```typescript
import { ethers } from 'ethers';

async function pauseMultiVault() {
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    pauserSigner
  );

  // Check if already paused
  const isPaused = await multiVault.paused();
  if (isPaused) {
    console.log('MultiVault already paused');
    return;
  }

  // Pause
  const tx = await multiVault.pause();
  console.log('Pause transaction sent:', tx.hash);

  const receipt = await tx.wait();
  console.log('MultiVault paused at block:', receipt.blockNumber);

  // Verify pause state
  const nowPaused = await multiVault.paused();
  console.log('Pause confirmed:', nowPaused);

  return receipt;
}
```

**Effects of MultiVault Pause:**
- ❌ `deposit()` - Blocked
- ❌ `depositTriple()` - Blocked
- ❌ `batchDeposit()` - Blocked
- ❌ `redeem()` - Blocked
- ❌ `batchRedeem()` - Blocked
- ❌ `createAtom()` - Blocked
- ❌ `createTriple()` - Blocked
- ✅ View functions - Still work
- ✅ Fee claims - Still work
- ✅ Utilization queries - Still work

### Pausing TrustBonding

```typescript
async function pauseTrustBonding() {
  const trustBonding = new ethers.Contract(
    TRUSTBONDING_ADDRESS,
    TRUSTBONDING_ABI,
    pauserSigner
  );

  const tx = await trustBonding.pause();
  await tx.wait();

  console.log('TrustBonding paused');
}
```

**Effects of TrustBonding Pause:**
- ❌ `createLock()` - Blocked
- ❌ `increaseAmount()` - Blocked
- ❌ `increaseUnlockTime()` - Blocked
- ❌ `claimRewards()` - Blocked
- ✅ `withdraw()` - Still works (users can exit)
- ✅ View functions - Still work
- ✅ Reward calculations - Still work

### Unpausing Contracts

```typescript
async function unpauseMultiVault() {
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    pauserSigner
  );

  // Verify fix is deployed
  const currentImpl = await proxyAdmin.getProxyImplementation(MULTIVAULT_ADDRESS);
  console.log('Current implementation:', currentImpl);

  // Confirm ready to unpause
  const confirmation = await confirmUnpause();
  if (!confirmation) {
    console.log('Unpause cancelled');
    return;
  }

  // Unpause
  const tx = await multiVault.unpause();
  await tx.wait();

  console.log('MultiVault unpaused');

  // Send all-clear notification
  await sendNotification({
    type: 'PROTOCOL_RESUMED',
    message: 'MultiVault operations resumed',
    timestamp: Date.now()
  });
}
```

## Monitoring and Detection

### Automated Monitoring

```typescript
// Monitor for suspicious activity
class EmergencyMonitor {
  private provider: ethers.Provider;
  private contracts: Map<string, ethers.Contract>;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(RPC_URL);
    this.contracts = new Map();

    // Initialize contracts
    this.contracts.set('MultiVault', new ethers.Contract(
      MULTIVAULT_ADDRESS,
      MULTIVAULT_ABI,
      this.provider
    ));
  }

  async startMonitoring() {
    console.log('Starting emergency monitoring...');

    // Monitor pause events
    const multiVault = this.contracts.get('MultiVault');

    multiVault.on('Paused', (account, event) => {
      this.handlePauseEvent('MultiVault', account, event);
    });

    multiVault.on('Unpaused', (account, event) => {
      this.handleUnpauseEvent('MultiVault', account, event);
    });

    // Monitor for failed transactions
    this.provider.on('block', async (blockNumber) => {
      await this.checkBlockForAnomalies(blockNumber);
    });
  }

  private async handlePauseEvent(
    contract: string,
    account: string,
    event: any
  ) {
    console.log(`🚨 ${contract} PAUSED by ${account}`);

    await sendCriticalAlert({
      type: 'CONTRACT_PAUSED',
      contract,
      pausedBy: account,
      txHash: event.transactionHash,
      blockNumber: event.blockNumber
    });
  }

  private async checkBlockForAnomalies(blockNumber: number) {
    // Check for unusual patterns
    // High number of reverts, unusual gas usage, etc.
  }
}

// Start monitoring
const monitor = new EmergencyMonitor();
monitor.startMonitoring();
```

### Health Checks

```typescript
// Periodic health checks
async function performHealthCheck() {
  const results = {
    timestamp: Date.now(),
    checks: []
  };

  // 1. Check contract pause states
  const multiVault = new ethers.Contract(
    MULTIVAULT_ADDRESS,
    MULTIVAULT_ABI,
    provider
  );

  results.checks.push({
    name: 'MultiVault Pause State',
    status: await multiVault.paused() ? 'PAUSED' : 'ACTIVE',
    critical: true
  });

  // 2. Check access control
  const hasRole = await multiVault.hasRole(
    await multiVault.DEFAULT_ADMIN_ROLE(),
    EXPECTED_ADMIN
  );

  results.checks.push({
    name: 'Admin Role Assignment',
    status: hasRole ? 'OK' : 'ALERT',
    critical: true
  });

  // 3. Check contract balances
  const trustBalance = await trustToken.balanceOf(MULTIVAULT_ADDRESS);

  results.checks.push({
    name: 'MultiVault TRUST Balance',
    value: ethers.formatEther(trustBalance),
    status: 'INFO'
  });

  // 4. Check for pending timelock operations
  const timelock = new ethers.Contract(
    TIMELOCK_ADDRESS,
    TIMELOCK_ABI,
    provider
  );

  // Query pending operations
  const pending = await queryPendingOperations(timelock);

  results.checks.push({
    name: 'Pending Timelock Operations',
    count: pending.length,
    status: pending.length > 0 ? 'INFO' : 'OK'
  });

  return results;
}

// Run health checks every 5 minutes
setInterval(async () => {
  const health = await performHealthCheck();
  console.log('Health check:', health);

  // Alert if any critical checks fail
  const failures = health.checks.filter(c => c.critical && c.status !== 'OK');
  if (failures.length > 0) {
    await sendAlert({
      type: 'HEALTH_CHECK_FAILED',
      failures
    });
  }
}, 5 * 60 * 1000);
```

## Communication Procedures

### Stakeholder Notification

```typescript
// Multi-channel notification system
async function notifyStakeholders(incident: any) {
  // 1. Discord announcement
  await sendDiscordNotification({
    channel: 'emergencies',
    message: `🚨 EMERGENCY: ${incident.description}`,
    severity: incident.severity,
    details: incident
  });

  // 2. Twitter/X announcement
  await sendTwitterNotification({
    message: `Protocol paused due to ${incident.description}. Team investigating. Updates to follow.`
  });

  // 3. Email to key stakeholders
  await sendEmails({
    recipients: STAKEHOLDER_EMAILS,
    subject: `URGENT: ${incident.description}`,
    body: formatIncidentEmail(incident)
  });

  // 4. Update status page
  await updateStatusPage({
    status: 'INCIDENT',
    message: incident.description,
    timestamp: incident.timestamp
  });
}
```

### Post-Incident Report

```typescript
interface IncidentReport {
  incidentId: string;
  timestamp: number;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  description: string;
  affectedContracts: string[];
  timeline: TimelineEvent[];
  rootCause: string;
  resolution: string;
  preventionMeasures: string[];
  financialImpact?: string;
}

async function generateIncidentReport(incident: any): Promise<IncidentReport> {
  return {
    incidentId: `INC-${Date.now()}`,
    timestamp: incident.timestamp,
    severity: incident.severity,
    description: incident.description,
    affectedContracts: incident.affectedContracts,
    timeline: [
      {
        time: incident.detectionTime,
        event: 'Issue detected'
      },
      {
        time: incident.pauseTime,
        event: 'Contracts paused'
      },
      {
        time: incident.fixDeployedTime,
        event: 'Fix deployed'
      },
      {
        time: incident.unpauseTime,
        event: 'Operations resumed'
      }
    ],
    rootCause: incident.rootCause,
    resolution: incident.resolution,
    preventionMeasures: incident.preventionMeasures
  };
}
```

## Recovery Procedures

### Post-Pause Validation

```typescript
// Validate state before unpausing
async function validateBeforeUnpause() {
  const checks = [];

  // 1. Verify fix is deployed
  const currentImpl = await proxyAdmin.getProxyImplementation(MULTIVAULT_ADDRESS);
  checks.push({
    name: 'Implementation Updated',
    pass: currentImpl === EXPECTED_NEW_IMPL
  });

  // 2. Test critical functions on fork
  const forkTests = await runForkTests();
  checks.push({
    name: 'Fork Tests',
    pass: forkTests.allPassed
  });

  // 3. Verify state consistency
  const stateValid = await verifyStateConsistency();
  checks.push({
    name: 'State Consistency',
    pass: stateValid
  });

  // 4. Check access controls
  const rolesValid = await verifyAccessControls();
  checks.push({
    name: 'Access Controls',
    pass: rolesValid
  });

  // All checks must pass
  const allPass = checks.every(c => c.pass);

  if (!allPass) {
    console.error('Pre-unpause validation failed:', checks);
    throw new Error('Cannot unpause: validation failed');
  }

  console.log('Pre-unpause validation passed');
  return true;
}
```

### Gradual Resumption

```typescript
// Resume operations gradually
async function gradualResumption() {
  // 1. Unpause with monitoring
  console.log('Step 1: Unpausing MultiVault');
  await unpauseMultiVault();

  // 2. Monitor for 10 minutes
  console.log('Step 2: Monitoring for anomalies');
  await monitorForDuration(10 * 60 * 1000);

  // 3. Check for issues
  const issues = await checkForIssues();
  if (issues.length > 0) {
    console.error('Issues detected:', issues);
    await pauseMultiVault();
    throw new Error('Issues detected after unpause');
  }

  // 4. Announce full resumption
  console.log('Step 3: Full resumption confirmed');
  await announceFullResumption();
}
```

## Testing Emergency Procedures

### Foundry Tests

```solidity
// Test pause functionality
function testEmergencyPause() public {
    // Grant pauser role
    vm.prank(admin);
    multiVault.grantRole(PAUSER_ROLE, pauser);

    // Pauser can pause
    vm.prank(pauser);
    multiVault.pause();

    assertTrue(multiVault.paused());

    // Deposits should fail when paused
    vm.prank(user);
    vm.expectRevert("Pausable: paused");
    multiVault.deposit(termId, curveId, assets, user);
}

function testOnlyPauserCanPause() public {
    // Non-pauser cannot pause
    vm.prank(user);
    vm.expectRevert();
    multiVault.pause();

    // Pauser can pause
    vm.prank(pauser);
    multiVault.pause();

    assertTrue(multiVault.paused());
}

function testUnpauseAfterEmergency() public {
    // Pause
    vm.prank(pauser);
    multiVault.pause();

    // Unpause
    vm.prank(pauser);
    multiVault.unpause();

    assertFalse(multiVault.paused());

    // Operations should work again
    vm.prank(user);
    multiVault.deposit(termId, curveId, assets, user);
}
```

## Runbooks

### Quick Reference

**Emergency Pause Command:**
```bash
# Using cast
cast send $MULTIVAULT_ADDRESS "pause()" \
  --rpc-url $RPC_URL \
  --private-key $PAUSER_KEY
```

**Emergency Unpause Command:**
```bash
cast send $MULTIVAULT_ADDRESS "unpause()" \
  --rpc-url $RPC_URL \
  --private-key $PAUSER_KEY
```

**Check Pause State:**
```bash
cast call $MULTIVAULT_ADDRESS "paused()(bool)" \
  --rpc-url $RPC_URL
```

## Best Practices

1. **Fast Response**: Keep pauser private keys in secure but accessible location
2. **Clear Authority**: Document who can authorize pause/unpause
3. **Communication Plan**: Have templates ready for notifications
4. **Regular Drills**: Practice emergency procedures quarterly
5. **Monitoring**: Automated detection of anomalies
6. **Documentation**: Keep detailed logs of all emergency actions
7. **Post-Mortems**: Always conduct thorough incident reviews

## See Also

- [Access Control](./access-control.md) - PAUSER_ROLE management
- [Security Considerations](./security-considerations.md) - Security best practices
- [Timelock Governance](./timelock-governance.md) - Post-emergency upgrades

---

**Last Updated**: December 2025
