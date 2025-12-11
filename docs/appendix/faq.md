# Frequently Asked Questions (FAQ)

Common questions and answers for developers integrating with Intuition Protocol V2.

## General Protocol Questions

### What is Intuition Protocol V2?

Intuition Protocol V2 is an on-chain knowledge graph protocol that enables users to create Atoms (singular units of data) and Triples (subject-predicate-object relationships) with associated economic vaults. The protocol implements dynamic pricing through bonding curves, epoch-based token emissions, and utilization-driven rewards.

### What blockchain networks does the protocol support?

**Base Chain (Mainnet):**
- Base Mainnet - TRUST token minting and emissions control

**Satellite Chains:**
- Intuition Mainnet - Main protocol operations (MultiVault, TrustBonding, etc.)

**Testnets:**
- Base Sepolia - Testing emissions
- Intuition Testnet - Testing protocol operations

### What is the native token?

TRUST is the protocol's native ERC20 token with a capped supply of 1 billion tokens. It's minted on Base chain and bridged to satellite chains for protocol operations.

### Is the protocol upgradeable?

Yes, most contracts use proxy patterns (Transparent or UUPS) to allow upgrades while preserving state. Upgrades are controlled by TimelockController contracts with 48-72 hour delays.

## Atoms and Triples

### What is an Atom?

An Atom is a singular unit of data (≤256 bytes) stored on-chain. Each atom has:
- Unique identifier (atomId)
- Associated data (bytes)
- Optional vault(s) for deposits
- Optional atom wallet (ERC-4337)

**Example:**
```typescript
const atomData = ethers.toUtf8Bytes("0x1234...5678"); // An Ethereum address
const atomId = keccak256(SALT + keccak256(atomData));
```

### What is a Triple?

A Triple is a subject-predicate-object relationship composed of three atom IDs. Triples express claims like "Alice knows Bob" or "Contract implements Interface".

**Structure:**
```typescript
{
  subjectId: atomId1,
  predicateId: atomId2,
  objectId: atomId3
}
```

### What is a Counter Triple?

For every triple created, a counter triple is automatically generated representing the opposite claim. This allows users to express disagreement.

**Example:**
- Triple: "X is verified"
- Counter Triple: "X is not verified"

### How much does it cost to create an Atom or Triple?

Costs are protocol parameters (adjustable by governance):
- **atomCost**: Base fee for creating atoms (e.g., 0.01 TRUST)
- **tripleCost**: Base fee for creating triples (e.g., 0.001 TRUST)
- Plus gas fees and any initial deposit

## Vaults and Shares

### What is a Vault?

A vault is an ERC4626-style pool managing assets and shares for a specific term (atom or triple) and bonding curve combination. Multiple vaults can exist for the same term using different curves.

### How do Bonding Curves work?

Bonding curves determine the price relationship between assets deposited and shares minted. Different curves offer different economics:

- **LinearCurve**: Constant 1:1 ratio (plus fees)
- **ProgressiveCurve**: Quadratic pricing - price increases as supply increases
- **OffsetProgressiveCurve**: Progressive with offset parameter

### Can I deposit into multiple vaults for the same atom?

Yes! Each (termId, curveId) combination is a separate vault. You can deposit into an atom's vault with curveId 1, curveId 2, etc., each with different pricing dynamics.

### What happens to my shares value over time?

Share value changes based on:
1. Bonding curve mechanics (supply/demand)
2. Other users' deposits/redemptions
3. Fees collected
4. For triples: Deposits into underlying atoms (due to atomDepositFraction)

### Can I redeem my shares at any time?

Yes, you can redeem shares anytime (unless the contract is paused). You'll receive assets based on:
- Current bonding curve price
- Minus exit fees
- Minus protocol fees

## Fees

### What fees does the protocol charge?

**On Deposits:**
1. **Protocol Fee**: Goes to protocol multisig or TrustBonding
2. **Entry Fee**: Only if vault already has shares (configurable basis points)
3. **Atom Wallet Deposit Fee**: Only for atom vaults (goes to atom wallet owner)
4. **Atom Cost**: If creating new atom
5. **Triple Cost**: If creating new triple

**On Redemptions:**
1. **Protocol Fee**: Goes to protocol multisig or TrustBonding
2. **Exit Fee**: Only if not draining vault entirely (configurable basis points)

### What is the atomDepositFraction?

When depositing into a triple vault, a fraction (e.g., 10%) also deposits into each of the triple's three underlying atom vaults. This is configurable basis points.

**Example:**
```
Deposit 100 TRUST to triple vault
├─ 100 TRUST to triple vault
└─ 10 TRUST each to subject, predicate, object atom vaults
```

### Where do protocol fees go?

Protocol fees accumulate per epoch and can be swept to either:
- Protocol multisig (for operations funding)
- TrustBonding contract (for bonded users distribution)

## Emissions and Rewards

### How do emissions work?

TRUST tokens are minted each epoch on the Base chain by BaseEmissionsController, then bridged to satellite chains. The emission schedule features:
- Fixed emissions per epoch initially
- Reduction every N epochs (cliff)
- Percentage reduction each cliff

### What is an epoch?

An epoch is a fixed time period (typically 1 week) used for:
- Emissions distribution
- Utilization tracking
- Reward calculations

### How are rewards calculated?

Rewards are based on:
1. **Your bonded balance (veTRUST)**: Time-weighted voting power from locking TRUST
2. **System utilization ratio**: Protocol-wide deposits vs redemptions
3. **Personal utilization ratio**: Your deposits vs redemptions

**Formula:**
```
eligibleRewards = baseRewards × systemRatio × personalRatio
```

### What is utilization?

Utilization measures net engagement:
```
utilization = deposits - redemptions
```

Higher utilization (more deposits than redemptions) increases reward eligibility.

### What is veTRUST?

Vote-escrowed TRUST - voting power gained by locking TRUST tokens for a period. veTRUST:
- Decays linearly over time
- Determines your share of emissions
- Lock duration: MINTIME to MAXTIME (2 weeks to 2 years)

**Formula:**
```
veTRUST = lockedAmount × (timeRemaining / MAXTIME)
```

### Can I increase my lock?

Yes, you can:
- **Increase amount**: Add more TRUST to existing lock
- **Extend time**: Extend unlock time (up to MAXTIME)
- Both require TrustBonding not to be paused

## Atom Wallets

### What is an Atom Wallet?

An ERC-4337 compatible smart contract wallet associated with each atom. Atom wallets can:
- Execute arbitrary transactions
- Hold assets (ETH, ERC20, NFTs)
- Accumulate fees from atom vault deposits
- Be owned/controlled by users

### How do I get an Atom Wallet?

Atom wallets are created deterministically when atoms are created. The address is computed as:
```typescript
const walletAddress = await atomWalletFactory.getWalletAddress(atomId);
```

### Who owns Atom Wallets?

Initially, AtomWarden contract owns all atom wallets. Ownership can be claimed if:
- The atom data is an Ethereum address
- That address matches the claimer
- The wallet hasn't been claimed yet

### Can I claim fees from an Atom Wallet?

Yes, if you're the atom wallet owner, you can claim accumulated atomWalletDepositFees:

```typescript
await multiVault.claimAtomWalletDepositFees(atomId);
```

## Integration Questions

### How do I integrate with the protocol?

**Option 1: Direct ABI Integration**
```typescript
import { ethers } from 'ethers';

const multiVault = new ethers.Contract(
  MULTIVAULT_ADDRESS,
  MULTIVAULT_ABI,
  signer
);

await multiVault.deposit(termId, curveId, assets, receiver);
```

**Option 2: Build/Use SDK**
- See [SDK Design Patterns](../integration/sdk-design-patterns.md)

### Do I need to approve TRUST before depositing?

Yes, you must approve MultiVault to spend your TRUST:

```typescript
const trust = new ethers.Contract(TRUST_ADDRESS, TRUST_ABI, signer);
await trust.approve(MULTIVAULT_ADDRESS, assets);
```

Or use permit (EIP-2612) if available.

### Can I batch operations?

Yes! MultiVault supports batching:

```typescript
await multiVault.batchDeposit([
  { termId: id1, curveId: 1, assets: amount1, receiver: user },
  { termId: id2, curveId: 1, assets: amount2, receiver: user },
]);
```

### How do I listen for events?

```typescript
multiVault.on('Deposited', (sender, receiver, termId, curveId, assets, shares, event) => {
  console.log(`Deposit: ${assets} assets for ${shares} shares`);
});
```

### What if the contract is paused?

When paused:
- ❌ Deposits blocked
- ❌ Redemptions blocked
- ❌ Atom/triple creation blocked
- ✅ View functions still work
- ✅ Fee claims still work

Wait for unpause or check protocol status page.

## Technical Questions

### What Solidity version is used?

Version 0.8.29 with built-in overflow/underflow protection.

### Are the contracts audited?

Yes, regular audits by reputable firms. Check GitHub for audit reports.

### Is there a testnet?

Yes:
- Base Sepolia (for emissions testing)
- Intuition Testnet (for protocol testing)

See [Deployment Addresses](../getting-started/deployment-addresses.md).

### How can I test locally?

```bash
# Start local node
anvil

# Fork mainnet
anvil --fork-url $RPC_URL

# Deploy contracts
forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast
```

### What's the gas cost for common operations?

Approximate costs (varies by network congestion):

| Operation | Gas Cost |
|-----------|----------|
| Create Atom | ~150,000 - 200,000 |
| Create Triple | ~200,000 - 250,000 |
| Deposit | ~100,000 - 150,000 |
| Redeem | ~80,000 - 120,000 |
| Batch Deposit (10) | ~800,000 - 1,000,000 |
| Claim Rewards | ~50,000 - 80,000 |

See [Gas Benchmarks](../reference/gas-benchmarks.md) for details.

## Troubleshooting

### Why is my transaction reverting?

Common causes:
1. **Insufficient allowance**: Approve TRUST spending
2. **Contract paused**: Wait for unpause
3. **Insufficient balance**: Check TRUST balance
4. **Invalid parameters**: Validate termId, curveId, amounts
5. **Slippage**: Price changed between estimate and execution

### How do I check if a contract is paused?

```typescript
const isPaused = await multiVault.paused();
console.log('Paused:', isPaused);
```

### Why don't I see my shares?

Check:
1. **Correct receiver**: Shares go to `receiver` parameter
2. **Correct vault**: Verify `(termId, curveId)` combination
3. **Transaction succeeded**: Check transaction status

```typescript
const balance = await multiVault.balanceOf(user, termId, curveId);
console.log('Shares:', balance);
```

### Where can I get TRUST tokens?

**Mainnet:**
- Earn through emissions (lock TRUST for veTRUST)
- Trade on DEXs (if listed)

**Testnet:**
- Request from faucet
- Use test token contract

### How do I compute atomId or tripleId?

**AtomId:**
```typescript
const atomId = ethers.keccak256(
  ethers.concat([
    SALT,
    ethers.keccak256(atomData)
  ])
);
```

**TripleId:**
```typescript
const tripleId = ethers.keccak256(
  ethers.AbiCoder.defaultAbiCoder().encode(
    ['bytes32', 'bytes32', 'bytes32'],
    [subjectId, predicateId, objectId]
  )
);
```

## Economic Questions

### What determines share price?

Share price is determined by:
1. **Bonding curve formula**: Linear, progressive, etc.
2. **Current vault state**: Total assets and shares
3. **Supply**: More deposits generally increase price (on progressive curves)

### Is there any slippage?

Yes, price can change between:
- Your transaction submission
- Block inclusion
- Other transactions executing first

Use `previewDeposit()` / `previewRedeem()` to estimate, then validate actual amounts.

### Can I lose money?

Risks include:
1. **Price volatility**: Share value can decrease
2. **Fees**: Entry, exit, and protocol fees reduce returns
3. **Smart contract risk**: Despite audits, bugs are possible
4. **Impermanent loss**: Similar to liquidity provision

### What's the APY for locking TRUST?

APY varies based on:
- Total TRUST locked in protocol
- Your lock duration
- Your utilization (deposits vs redemptions)
- Protocol-wide utilization

Calculate current APY:
```typescript
const apy = await calculateAPY(
  totalEmissionsPerYear,
  totalBondedTrust,
  avgUtilizationRatio
);
```

## Advanced Questions

### Can I create custom bonding curves?

Curves must be registered in BondingCurveRegistry. New curves require:
1. Implement IBaseCurve interface
2. Deploy curve contract
3. Register via governance

### How does cross-chain bridging work?

TRUST uses MetaERC20 standard for cross-chain:
1. BaseEmissionsController mints on Base
2. Bridge locks tokens and sends message
3. Satellite chain mints equivalent amount
4. Uses finality states for security

### Can I integrate with subgraphs?

Yes! The protocol emits comprehensive events. See [Subgraph Integration](../integration/subgraph-integration.md).

### Are there any rate limits?

On-chain operations have no rate limits (only gas costs). Off-chain APIs may have rate limits - check API documentation.

### How do I report a security issue?

**DO NOT** open public GitHub issues. Contact:
- Email: security@intuition.systems
- See [Security Considerations](../advanced/security-considerations.md)

## Community and Support

### Where can I get help?

- **Documentation**: [docs.intuition.systems](https://docs.intuition.systems)
- **Discord**: [discord.gg/intuition](https://discord.gg/intuition)
- **GitHub**: [github.com/0xIntuition/intuition-contracts-v2](https://github.com/0xIntuition/intuition-contracts-v2)
- **Twitter**: [@0xIntuition](https://twitter.com/0xIntuition)

### How can I contribute?

See [Contributing Guide](./contributing.md) for:
- Code contributions
- Documentation improvements
- Bug reports
- Feature requests

### Is there a bug bounty program?

Check [Security Considerations](../advanced/security-considerations.md) for bug bounty details.

## See Also

- [Troubleshooting](./troubleshooting.md) - Common issues and solutions
- [Glossary](../GLOSSARY.md) - Protocol terminology
- [Getting Started](../getting-started/overview.md) - Protocol overview

---

**Last Updated**: December 2025
