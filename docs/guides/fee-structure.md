# Fee Structure

## Overview

The Intuition Protocol employs multiple fee mechanisms to sustain protocol development, reward participants, and align incentives. Understanding the fee structure is crucial for accurate cost estimation and maximizing returns.

This guide provides a comprehensive breakdown of all fee types, when they apply, and how to calculate them.

**Fee Categories**:
- Protocol fees (on deposits and redemptions)
- Entry fees (dynamic, on deposits above threshold)
- Exit fees (dynamic, on redemptions above threshold)
- Atom creation fees (one-time, fixed)
- Triple creation fees (one-time, fixed)
- Atom wallet deposit fees (continuous, on atom deposits)

## Prerequisites

### Required Knowledge
- Understanding of vault operations
- Familiarity with [multi-vault architecture](../concepts/multi-vault-pattern.md)
- Basic knowledge of bonding curves

### Contracts Needed
- **MultiVault**: Main protocol contract
  - Mainnet: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
  - Testnet: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`

## Fee Types

### 1. Protocol Fee

**Applied to**: All deposits and redemptions
**Purpose**: Protocol revenue and TRUST token rewards
**Destination**: Split between protocol multisig and TrustBonding
**Calculation**: `amount * (protocolFee / feeDenominator)`

**Key characteristics**:
- Always charged unless protocol is paused
- Accrued per epoch and swept to destinations
- Does not depend on vault state

**Query protocol fee**:
```typescript
const vaultFees = await multiVault.getVaultFees();
const generalConfig = await multiVault.getGeneralConfig();

const protocolFeeNumerator = vaultFees.protocolFee;
const feeDenominator = generalConfig.feeDenominator;

// Calculate fee on 100 WTRUST deposit
const depositAmount = ethers.parseEther('100');
const protocolFeeAmount = await multiVault.protocolFeeAmount(depositAmount);

console.log('Protocol fee:', ethers.formatEther(protocolFeeAmount), 'WTRUST');
console.log('Fee percentage:', Number(protocolFeeNumerator) / Number(feeDenominator) * 100, '%');
```

**Typical values**:
- Fee: ~1-2% of transaction amount
- Denominator: 10,000 (basis points)

### 2. Entry Fee

**Applied to**: Deposits into vaults above fee threshold
**Purpose**: Rewards existing vault shareholders
**Destination**: Remains in vault, benefits existing shareholders
**Calculation**: `amount * (entryFee / feeDenominator)`

**Key characteristics**:
- Only charged if vault has totalShares >= feeThreshold
- First depositors (below threshold) pay no entry fee
- Fee stays in vault, dilution protection for early participants

**Check if entry fee applies**:
```typescript
const termId = '0x...'; // Atom or triple ID
const curveId = 1n;

const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
const generalConfig = await multiVault.getGeneralConfig();
const vaultFees = await multiVault.getVaultFees();

const feeThreshold = generalConfig.feeThreshold;
const willChargeEntryFee = totalShares >= feeThreshold;

if (willChargeEntryFee) {
  const depositAmount = ethers.parseEther('100');
  const entryFeeAmount = await multiVault.entryFeeAmount(depositAmount);

  console.log('Entry fee will be charged');
  console.log('Entry fee amount:', ethers.formatEther(entryFeeAmount), 'WTRUST');
  console.log('Fee percentage:', Number(vaultFees.entryFee) / Number(generalConfig.feeDenominator) * 100, '%');
} else {
  console.log('Vault below threshold, no entry fee');
}
```

**Typical values**:
- Fee: ~0.5-1% of deposit amount
- Threshold: Varies per deployment (e.g., 100 shares)

### 3. Exit Fee

**Applied to**: Redemptions that leave vault above fee threshold
**Purpose**: Discourages rapid entry/exit, rewards remaining shareholders
**Destination**: Remains in vault, benefits remaining shareholders
**Calculation**: `assets * (exitFee / feeDenominator)`

**Key characteristics**:
- Only charged if remaining totalShares >= feeThreshold after redemption
- If redemption would leave vault below threshold, no fee
- Encourages long-term positions

**Check if exit fee applies**:
```typescript
const sharesToRedeem = ethers.parseEther('50');

const [totalAssets, totalShares] = await multiVault.getVault(termId, curveId);
const generalConfig = await multiVault.getGeneralConfig();
const vaultFees = await multiVault.getVaultFees();

const sharesAfterRedemption = totalShares - sharesToRedeem;
const feeThreshold = generalConfig.feeThreshold;
const willChargeExitFee = sharesAfterRedemption >= feeThreshold;

if (willChargeExitFee) {
  // Convert shares to assets first
  const grossAssets = await multiVault.convertToAssets(termId, curveId, sharesToRedeem);
  const exitFeeAmount = await multiVault.exitFeeAmount(grossAssets);

  console.log('Exit fee will be charged');
  console.log('Exit fee amount:', ethers.formatEther(exitFeeAmount), 'WTRUST');
} else {
  console.log('Redemption leaves vault below threshold, no exit fee');
}
```

**Typical values**:
- Fee: ~0.5-1% of redemption amount
- Same threshold as entry fee

### 4. Atom Creation Fee

**Applied to**: Creating new atoms
**Purpose**: Spam prevention and protocol revenue
**Destination**: Protocol multisig
**Calculation**: Fixed amount per atom

**Key characteristics**:
- One-time fee paid when creating atom
- Added to minimum deposit requirement
- Independent of deposit amount

**Calculate atom creation cost**:
```typescript
const atomConfig = await multiVault.getAtomConfig();
const generalConfig = await multiVault.getGeneralConfig();

const atomCreationFee = atomConfig.atomCreationProtocolFee;
const minDeposit = generalConfig.minDeposit;

const totalMinimum = atomCreationFee + minDeposit;

console.log('Atom creation fee:', ethers.formatEther(atomCreationFee), 'WTRUST');
console.log('Minimum deposit:', ethers.formatEther(minDeposit), 'WTRUST');
console.log('Total minimum:', ethers.formatEther(totalMinimum), 'WTRUST');

// Convenience function
const atomCost = await multiVault.getAtomCost();
console.log('Atom cost (same as creation fee):', ethers.formatEther(atomCost), 'WTRUST');
```

**Typical values**:
- Creation fee: ~1-10 WTRUST
- Minimum deposit: ~1-10 WTRUST
- Total: ~2-20 WTRUST

### 5. Triple Creation Fee

**Applied to**: Creating new triples
**Purpose**: Spam prevention and protocol revenue
**Destination**: Protocol multisig
**Calculation**: Fixed amount per triple

**Key characteristics**:
- One-time fee paid when creating triple
- Added to minimum deposit requirement
- Independent of deposit amount

**Calculate triple creation cost**:
```typescript
const tripleConfig = await multiVault.getTripleConfig();
const generalConfig = await multiVault.getGeneralConfig();

const tripleCreationFee = tripleConfig.tripleCreationProtocolFee;
const minDeposit = generalConfig.minDeposit;

const totalMinimum = tripleCreationFee + minDeposit;

console.log('Triple creation fee:', ethers.formatEther(tripleCreationFee), 'WTRUST');
console.log('Minimum deposit:', ethers.formatEther(minDeposit), 'WTRUST');
console.log('Total minimum:', ethers.formatEther(totalMinimum), 'WTRUST');

// Convenience function
const tripleCost = await multiVault.getTripleCost();
console.log('Triple cost (same as creation fee):', ethers.formatEther(tripleCost), 'WTRUST');
```

**Typical values**:
- Creation fee: ~1-10 WTRUST
- Minimum deposit: ~1-10 WTRUST
- Total: ~2-20 WTRUST

### 6. Atom Wallet Deposit Fee

**Applied to**: Deposits into atom vaults
**Purpose**: Rewards atom wallet owner (creator)
**Destination**: Claimable by atom wallet owner
**Calculation**: `depositAmount * (atomWalletDepositFee / feeDenominator)`

**Key characteristics**:
- Charged on every atom vault deposit
- Accumulates as claimable fees for atom wallet owner
- Does not apply to triple vault deposits
- Provides revenue stream for atom creators

**Calculate atom wallet deposit fee**:
```typescript
const atomConfig = await multiVault.getAtomConfig();
const generalConfig = await multiVault.getGeneralConfig();

const atomWalletFeeNumerator = atomConfig.atomWalletDepositFee;
const feeDenominator = generalConfig.feeDenominator;

const depositAmount = ethers.parseEther('100');
const atomWalletFee = (depositAmount * atomWalletFeeNumerator) / feeDenominator;

console.log('Atom wallet deposit fee:', ethers.formatEther(atomWalletFee), 'WTRUST');
console.log('Fee percentage:', Number(atomWalletFeeNumerator) / Number(feeDenominator) * 100, '%');

// Check accumulated fees for an atom
const atomId = '0x...';
const atomWalletAddress = await multiVault.computeAtomWalletAddr(atomId);
// Fees tracked internally, claim via claimAtomWalletDepositFees
```

**Typical values**:
- Fee: ~0.1-0.5% of deposit amount
- Only on atom deposits, not triple deposits

### 7. Atom Deposit Fraction (for Triples)

**Applied to**: Triple vault deposits
**Purpose**: Directs portion of triple deposit to underlying atoms
**Destination**: Underlying atom vaults (subject, predicate, object)
**Calculation**: `depositAmount * (atomDepositFractionForTriple / feeDenominator)`

**Key characteristics**:
- Not exactly a "fee" but reduces assets going to triple vault
- Fraction split equally among 3 underlying atoms
- Aligns incentives between triples and their atoms

**Calculate atom deposit fraction**:
```typescript
const tripleConfig = await multiVault.getTripleConfig();
const generalConfig = await multiVault.getGeneralConfig();

const fractionNumerator = tripleConfig.atomDepositFractionForTriple;
const feeDenominator = generalConfig.feeDenominator;

const tripleDepositAmount = ethers.parseEther('100');
const totalToAtoms = await multiVault.atomDepositFractionAmount(tripleDepositAmount);
const perAtom = totalToAtoms / 3n; // Split among subject, predicate, object

console.log('Total to underlying atoms:', ethers.formatEther(totalToAtoms), 'WTRUST');
console.log('Per atom (subject/predicate/object):', ethers.formatEther(perAtom), 'WTRUST');
console.log('Remaining for triple vault:', ethers.formatEther(tripleDepositAmount - totalToAtoms), 'WTRUST');
console.log('Fraction percentage:', Number(fractionNumerator) / Number(feeDenominator) * 100, '%');
```

**Typical values**:
- Fraction: ~10-30% of triple deposit
- Split: Divided equally (1/3 each) to subject, predicate, object atoms

## Code Examples

### TypeScript (ethers.js v6)

Comprehensive fee calculation utility:

```typescript
import { ethers } from 'ethers';
import MultiVaultABI from './abis/IMultiVault.json';

const MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e';
const RPC_URL = 'YOUR_INTUITION_RPC_URL';

interface FeeBreakdown {
  protocolFee: bigint;
  entryFee: bigint;
  exitFee: bigint;
  atomWalletFee: bigint;
  totalFees: bigint;
  netAmount: bigint;
}

class FeeCalculator {
  private multiVault: ethers.Contract;
  private generalConfig: any;
  private vaultFees: any;
  private atomConfig: any;
  private tripleConfig: any;

  constructor(provider: ethers.Provider) {
    this.multiVault = new ethers.Contract(
      MULTIVAULT_ADDRESS,
      MultiVaultABI,
      provider
    );
  }

  async initialize() {
    [this.generalConfig, this.vaultFees, this.atomConfig, this.tripleConfig] =
      await Promise.all([
        this.multiVault.getGeneralConfig(),
        this.multiVault.getVaultFees(),
        this.multiVault.getAtomConfig(),
        this.multiVault.getTripleConfig()
      ]);
  }

  /**
   * Calculate all fees for a deposit operation
   */
  async calculateDepositFees(
    termId: string,
    curveId: bigint,
    depositAmount: bigint,
    isAtom: boolean = true
  ): Promise<FeeBreakdown> {
    // Get vault state
    const [totalAssets, totalShares] = await this.multiVault.getVault(
      termId,
      curveId
    );

    // Protocol fee (always charged)
    const protocolFee = await this.multiVault.protocolFeeAmount(depositAmount);

    // Entry fee (only if vault above threshold)
    let entryFee = 0n;
    if (totalShares >= this.generalConfig.feeThreshold) {
      entryFee = await this.multiVault.entryFeeAmount(depositAmount);
    }

    // Atom wallet deposit fee (only for atom deposits)
    let atomWalletFee = 0n;
    if (isAtom) {
      atomWalletFee = (depositAmount * this.atomConfig.atomWalletDepositFee) /
                      this.generalConfig.feeDenominator;
    }

    const totalFees = protocolFee + entryFee + atomWalletFee;
    const netAmount = depositAmount - totalFees;

    return {
      protocolFee,
      entryFee,
      exitFee: 0n,
      atomWalletFee,
      totalFees,
      netAmount
    };
  }

  /**
   * Calculate all fees for a redemption operation
   */
  async calculateRedemptionFees(
    termId: string,
    curveId: bigint,
    shares: bigint
  ): Promise<FeeBreakdown> {
    // Convert shares to assets
    const grossAssets = await this.multiVault.convertToAssets(
      termId,
      curveId,
      shares
    );

    // Get vault state
    const [totalAssets, totalShares] = await this.multiVault.getVault(
      termId,
      curveId
    );

    // Protocol fee (always charged)
    const protocolFee = await this.multiVault.protocolFeeAmount(grossAssets);

    // Exit fee (only if remaining shares >= threshold)
    let exitFee = 0n;
    const sharesAfterRedemption = totalShares - shares;
    if (sharesAfterRedemption >= this.generalConfig.feeThreshold) {
      exitFee = await this.multiVault.exitFeeAmount(grossAssets);
    }

    const totalFees = protocolFee + exitFee;
    const netAmount = grossAssets - totalFees;

    return {
      protocolFee,
      entryFee: 0n,
      exitFee,
      atomWalletFee: 0n,
      totalFees,
      netAmount
    };
  }

  /**
   * Calculate atom creation costs
   */
  async calculateAtomCreationCosts(depositAmount: bigint): Promise<{
    creationFee: bigint;
    minDeposit: bigint;
    depositFees: FeeBreakdown;
    totalRequired: bigint;
  }> {
    const creationFee = this.atomConfig.atomCreationProtocolFee;
    const minDeposit = this.generalConfig.minDeposit;

    // For new atoms, vault starts empty so no entry fee
    const protocolFee = await this.multiVault.protocolFeeAmount(depositAmount);
    const atomWalletFee = (depositAmount * this.atomConfig.atomWalletDepositFee) /
                         this.generalConfig.feeDenominator;

    const depositFees: FeeBreakdown = {
      protocolFee,
      entryFee: 0n, // New vault, no entry fee
      exitFee: 0n,
      atomWalletFee,
      totalFees: protocolFee + atomWalletFee,
      netAmount: depositAmount - protocolFee - atomWalletFee
    };

    const totalRequired = creationFee + depositAmount;

    return {
      creationFee,
      minDeposit,
      depositFees,
      totalRequired
    };
  }

  /**
   * Calculate triple creation costs
   */
  async calculateTripleCreationCosts(depositAmount: bigint): Promise<{
    creationFee: bigint;
    minDeposit: bigint;
    atomDepositFraction: bigint;
    depositFees: FeeBreakdown;
    totalRequired: bigint;
  }> {
    const creationFee = this.tripleConfig.tripleCreationProtocolFee;
    const minDeposit = this.generalConfig.minDeposit;

    // Atom deposit fraction
    const atomDepositFraction = await this.multiVault.atomDepositFractionAmount(
      depositAmount
    );

    // For new triples, vault starts empty so no entry fee
    const protocolFee = await this.multiVault.protocolFeeAmount(depositAmount);

    const depositFees: FeeBreakdown = {
      protocolFee,
      entryFee: 0n, // New vault, no entry fee
      exitFee: 0n,
      atomWalletFee: 0n, // Triple deposits don't pay atom wallet fee
      totalFees: protocolFee,
      netAmount: depositAmount - protocolFee - atomDepositFraction
    };

    const totalRequired = creationFee + depositAmount;

    return {
      creationFee,
      minDeposit,
      atomDepositFraction,
      depositFees,
      totalRequired
    };
  }

  /**
   * Format fee breakdown for display
   */
  formatFeeBreakdown(fees: FeeBreakdown): string {
    const lines = [
      '=== Fee Breakdown ===',
      `Protocol fee: ${ethers.formatEther(fees.protocolFee)} WTRUST`,
      `Entry fee: ${ethers.formatEther(fees.entryFee)} WTRUST`,
      `Exit fee: ${ethers.formatEther(fees.exitFee)} WTRUST`,
      `Atom wallet fee: ${ethers.formatEther(fees.atomWalletFee)} WTRUST`,
      `Total fees: ${ethers.formatEther(fees.totalFees)} WTRUST`,
      `Net amount: ${ethers.formatEther(fees.netAmount)} WTRUST`
    ];
    return lines.join('\n');
  }
}

// Usage example
async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const calculator = new FeeCalculator(provider);
  await calculator.initialize();

  // Example: Calculate deposit fees
  const termId = '0x...';
  const depositAmount = ethers.parseEther('100');

  const depositFees = await calculator.calculateDepositFees(
    termId,
    1n,
    depositAmount,
    true // isAtom
  );

  console.log(calculator.formatFeeBreakdown(depositFees));

  // Example: Calculate atom creation costs
  const atomCosts = await calculator.calculateAtomCreationCosts(depositAmount);

  console.log('\n=== Atom Creation Costs ===');
  console.log('Creation fee:', ethers.formatEther(atomCosts.creationFee));
  console.log('Minimum deposit:', ethers.formatEther(atomCosts.minDeposit));
  console.log('Total required:', ethers.formatEther(atomCosts.totalRequired));
  console.log('\n' + calculator.formatFeeBreakdown(atomCosts.depositFees));
}

if (require.main === module) {
  main();
}
```

### Python (web3.py)

```python
from web3 import Web3
import json

MULTIVAULT_ADDRESS = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'
RPC_URL = 'YOUR_INTUITION_RPC_URL'

with open('abis/IMultiVault.json') as f:
    MULTIVAULT_ABI = json.load(f)

class FeeCalculator:
    def __init__(self, rpc_url: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.multivault = self.w3.eth.contract(
            address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
            abi=MULTIVAULT_ABI
        )

        # Load configs
        self.general_config = self.multivault.functions.getGeneralConfig().call()
        self.vault_fees = self.multivault.functions.getVaultFees().call()
        self.atom_config = self.multivault.functions.getAtomConfig().call()
        self.triple_config = self.multivault.functions.getTripleConfig().call()

    def calculate_deposit_fees(self, term_id: bytes, curve_id: int,
                               deposit_amount: int, is_atom: bool = True) -> dict:
        """Calculate all fees for a deposit"""
        # Get vault state
        total_assets, total_shares = self.multivault.functions.getVault(
            term_id, curve_id
        ).call()

        # Protocol fee
        protocol_fee = self.multivault.functions.protocolFeeAmount(
            deposit_amount
        ).call()

        # Entry fee (if above threshold)
        entry_fee = 0
        if total_shares >= self.general_config[7]:  # feeThreshold
            entry_fee = self.multivault.functions.entryFeeAmount(
                deposit_amount
            ).call()

        # Atom wallet fee (atoms only)
        atom_wallet_fee = 0
        if is_atom:
            atom_wallet_fee = (
                deposit_amount * self.atom_config[1]  # atomWalletDepositFee
            ) // self.general_config[2]  # feeDenominator

        total_fees = protocol_fee + entry_fee + atom_wallet_fee
        net_amount = deposit_amount - total_fees

        return {
            'protocol_fee': protocol_fee,
            'entry_fee': entry_fee,
            'atom_wallet_fee': atom_wallet_fee,
            'total_fees': total_fees,
            'net_amount': net_amount
        }

    def format_fees(self, fees: dict) -> str:
        """Format fee breakdown"""
        return f"""=== Fee Breakdown ===
Protocol fee: {Web3.from_wei(fees['protocol_fee'], 'ether')} WTRUST
Entry fee: {Web3.from_wei(fees['entry_fee'], 'ether')} WTRUST
Atom wallet fee: {Web3.from_wei(fees['atom_wallet_fee'], 'ether')} WTRUST
Total fees: {Web3.from_wei(fees['total_fees'], 'ether')} WTRUST
Net amount: {Web3.from_wei(fees['net_amount'], 'ether')} WTRUST"""

if __name__ == '__main__':
    calculator = FeeCalculator(RPC_URL)

    deposit_amount = Web3.to_wei(100, 'ether')
    fees = calculator.calculate_deposit_fees(
        bytes.fromhex('1234...'),
        1,
        deposit_amount,
        True
    )

    print(calculator.format_fees(fees))
```

## Gas Estimation

Fee calculations themselves are view functions (free):
- `protocolFeeAmount()`: Free
- `entryFeeAmount()`: Free
- `exitFeeAmount()`: Free
- `getAtomCost()`: Free
- `getTripleCost()`: Free

Fees are deducted from transaction amounts, no separate gas cost.

## Best Practices

1. **Preview before transacting**: Use preview functions to see exact fees
2. **Account for all fees**: Don't forget cumulative effect
3. **Monitor fee thresholds**: Track when entry/exit fees start applying
4. **Consider timing**: Fees may change based on vault state
5. **Claim atom wallet fees**: Don't forget to claim accumulated fees

## Common Pitfalls

1. **Forgetting protocol fee**: Always applies on deposits/redemptions
2. **Ignoring fee thresholds**: Entry/exit fees only apply above threshold
3. **Not accounting for atom wallet fee**: Adds ~0.1-0.5% to atom deposits
4. **Confusing gross vs net**: Preview functions return net amounts
5. **Missing atom deposit fraction**: Reduces triple vault deposits by ~10-30%

## Related Operations

- [Depositing Assets](./depositing-assets.md)
- [Redeeming Shares](./redeeming-shares.md)
- [Creating Atoms](./creating-atoms.md)
- [Creating Triples](./creating-triples.md)
- [Wallet Integration](./wallet-integration.md)

## See Also

- [Multi-Vault Pattern](../concepts/multi-vault-pattern.md)
- [MultiVault Contract](../contracts/core/MultiVault.md)

---

**Last Updated**: December 2025
