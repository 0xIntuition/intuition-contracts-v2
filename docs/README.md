# Intuition Protocol V2 Documentation

Welcome to the comprehensive documentation for Intuition Protocol V2 smart contracts. This documentation serves both SDK developers building higher-level abstractions and application developers integrating directly using the contract ABIs.

## What is Intuition Protocol V2?

Intuition Protocol V2 is an on-chain knowledge graph protocol that enables users to create **Atoms** (singular units of data) and **Triples** (subject-predicate-object relationships) with associated economic vaults. The protocol implements dynamic pricing through bonding curves, epoch-based token emissions, and utilization-driven rewards.

## Quick Links

- **[Getting Started](#getting-started)** - New to Intuition? Start here
- **[Core Concepts](#core-concepts)** - Understand the protocol architecture
- **[Contract Reference](#contract-reference)** - Detailed contract documentation
- **[Integration Guides](#integration-guides)** - Step-by-step implementation guides
- **[Code Examples](#code-examples)** - Runnable code in TypeScript, Python, and Solidity
- **[Glossary](./GLOSSARY.md)** - Protocol terminology reference

## Getting Started

Choose your path based on your goals:

### For SDK Developers
Building a higher-level abstraction or library on top of Intuition?

1. [Protocol Overview](./getting-started/overview.md) - Understand the system
2. [Architecture](./getting-started/architecture.md) - Component relationships
3. [SDK Quick Start](./getting-started/quickstart-sdk.md) - Get started with TypeScript
4. [SDK Design Patterns](./integration/sdk-design-patterns.md) - Best practices

### For Application Developers
Integrating directly with contract ABIs?

1. [Protocol Overview](./getting-started/overview.md) - Understand the system
2. [ABI Quick Start](./getting-started/quickstart-abi.md) - Get started with web3
3. [Deployment Addresses](./getting-started/deployment-addresses.md) - Contract addresses
4. [Integration Guides](#integration-guides) - Step-by-step tutorials

## Core Concepts

Understand the fundamental concepts powering Intuition Protocol V2:

- **[Atoms and Triples](./concepts/atoms-and-triples.md)** - Core data model
- **[Multi-Vault Pattern](./concepts/multi-vault-pattern.md)** - Vault architecture
- **[Bonding Curves](./concepts/bonding-curves.md)** - Dynamic pricing mechanisms
- **[Emissions System](./concepts/emissions-system.md)** - Epoch-based rewards
- **[Utilization Tracking](./concepts/utilization-tracking.md)** - Reward eligibility
- **[Smart Wallets](./concepts/smart-wallets.md)** - ERC-4337 atom wallets
- **[Cross-Chain Architecture](./concepts/cross-chain-architecture.md)** - Multi-chain design

## Contract Reference

Comprehensive documentation for all protocol contracts:

### Core Contracts
- **[MultiVault](./contracts/core/MultiVault.md)** - Central vault management hub
- **[MultiVaultCore](./contracts/core/MultiVaultCore.md)** - Core vault logic
- **[Trust](./contracts/core/Trust.md)** - TRUST ERC20 token

### Bonding Curves
- **[BondingCurveRegistry](./contracts/curves/BondingCurveRegistry.md)** - Curve registry
- **[BaseCurve](./contracts/curves/BaseCurve.md)** - Curve interface
- **[LinearCurve](./contracts/curves/LinearCurve.md)** - Linear pricing
- **[ProgressiveCurve](./contracts/curves/ProgressiveCurve.md)** - Progressive pricing
- **[OffsetProgressiveCurve](./contracts/curves/OffsetProgressiveCurve.md)** - Offset progressive

### Emissions System
- **[BaseEmissionsController](./contracts/emissions/BaseEmissionsController.md)** - Base chain emissions
- **[SatelliteEmissionsController](./contracts/emissions/SatelliteEmissionsController.md)** - Satellite emissions
- **[CoreEmissionsController](./contracts/emissions/CoreEmissionsController.md)** - Core emission logic
- **[TrustBonding](./contracts/emissions/TrustBonding.md)** - Voting escrow & rewards

### Wallet System
- **[AtomWallet](./contracts/wallet/AtomWallet.md)** - ERC-4337 smart wallet
- **[AtomWalletFactory](./contracts/wallet/AtomWalletFactory.md)** - Wallet deployment
- **[AtomWarden](./contracts/wallet/AtomWarden.md)** - Wallet registry

### Other
- **[WrappedTrust](./contracts/WrappedTrust.md)** - Wrapped native token

## Integration Guides

Step-by-step guides for common operations:

- **[Creating Atoms](./guides/creating-atoms.md)** - Create singular data units
- **[Creating Triples](./guides/creating-triples.md)** - Create relationships
- **[Depositing Assets](./guides/depositing-assets.md)** - Deposit into vaults
- **[Redeeming Shares](./guides/redeeming-shares.md)** - Withdraw from vaults
- **[Claiming Rewards](./guides/claiming-rewards.md)** - Claim emission rewards
- **[Batch Operations](./guides/batch-operations.md)** - Optimize with batching
- **[Fee Structure](./guides/fee-structure.md)** - Understand all fees
- **[Utilization Mechanics](./guides/utilization-mechanics.md)** - Calculate utilization
- **[Epoch Management](./guides/epoch-management.md)** - Work with epochs
- **[Wallet Integration](./guides/wallet-integration.md)** - Use atom wallets

## SDK Integration Patterns

Advanced patterns for SDK developers:

- **[SDK Design Patterns](./integration/sdk-design-patterns.md)** - Architecture patterns
- **[Event Monitoring](./integration/event-monitoring.md)** - Event subscriptions
- **[Transaction Flows](./integration/transaction-flows.md)** - Complete flows
- **[Error Handling](./integration/error-handling.md)** - Error management
- **[Gas Optimization](./integration/gas-optimization.md)** - Reduce gas costs
- **[Subgraph Integration](./integration/subgraph-integration.md)** - The Graph patterns
- **[Cross-Chain Integration](./integration/cross-chain-integration.md)** - Multi-chain SDKs

## Code Examples

Runnable code examples in multiple languages:

### TypeScript/JavaScript
- [Create Atom](./examples/typescript/create-atom.ts)
- [Create Triple](./examples/typescript/create-triple.ts)
- [Deposit to Vault](./examples/typescript/deposit-vault.ts)
- [Redeem Shares](./examples/typescript/redeem-shares.ts)
- [Claim Rewards](./examples/typescript/claim-rewards.ts)
- [Batch Operations](./examples/typescript/batch-operations.ts)
- [Event Listener](./examples/typescript/event-listener.ts)
- [SDK Wrapper](./examples/typescript/sdk-wrapper.ts)

### Python
- [Create Atom](./examples/python/create-atom.py)
- [Create Triple](./examples/python/create-triple.py)
- [Deposit to Vault](./examples/python/deposit-vault.py)
- [Redeem Shares](./examples/python/redeem-shares.py)
- [Claim Rewards](./examples/python/claim-rewards.py)
- [Event Indexer](./examples/python/event-indexer.py)

### Solidity
- [Integration Contract](./examples/solidity/IntegrationContract.sol)
- [Custom Curve](./examples/solidity/CustomCurve.sol)
- [Utilization Tracker](./examples/solidity/UtilizationTracker.sol)

## Reference Documentation

Complete technical reference:

- **[Events](./reference/events.md)** - All protocol events
- **[Errors](./reference/errors.md)** - Custom errors
- **[Data Structures](./reference/data-structures.md)** - Structs and enums
- **[Mathematical Formulas](./reference/mathematical-formulas.md)** - Curve calculations
- **[Gas Benchmarks](./reference/gas-benchmarks.md)** - Gas cost reference
- **[ABI Files](./reference/abi/)** - Contract ABIs

## Advanced Topics

Deep dives into protocol internals:

- **[Upgradeability](./advanced/upgradeability.md)** - Proxy patterns
- **[Access Control](./advanced/access-control.md)** - Role-based permissions
- **[Timelock Governance](./advanced/timelock-governance.md)** - Governance mechanisms
- **[Emergency Procedures](./advanced/emergency-procedures.md)** - Pause mechanisms
- **[Migration Mode](./advanced/migration-mode.md)** - Migration patterns
- **[Security Considerations](./advanced/security-considerations.md)** - Security best practices

## Deployed Contracts

### Mainnet

#### Base Mainnet
| Contract | Address | Explorer |
|----------|---------|----------|
| Trust | `0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3` | [View](https://basescan.org/address/0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3) |
| BaseEmissionsController | `0x7745bDEe668501E5eeF7e9605C746f9cDfb60667` | [View](https://basescan.org/address/0x7745bDEe668501E5eeF7e9605C746f9cDfb60667) |
| EmissionsAutomationAdapter | `0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d` | [View](https://basescan.org/address/0xb1ce9Ac324B5C3928736Ec33b5Fd741cb04a2F2d) |

[See all deployment addresses →](./getting-started/deployment-addresses.md)

#### Intuition Mainnet
| Contract | Address | Explorer |
|----------|---------|----------|
| MultiVault | `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` | [View](https://explorer.intuit.network/address/0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e) |
| TrustBonding | `0x635bBD1367B66E7B16a21D6E5A63C812fFC00617` | [View](https://explorer.intuit.network/address/0x635bBD1367B66E7B16a21D6E5A63C812fFC00617) |
| AtomWalletFactory | `0x33827373a7D1c7C78a01094071C2f6CE74253B9B` | [View](https://explorer.intuit.network/address/0x33827373a7D1c7C78a01094071C2f6CE74253B9B) |

[See all deployment addresses →](./getting-started/deployment-addresses.md)

### Testnet

See [Deployment Addresses](./getting-started/deployment-addresses.md) for complete testnet addresses.

## Additional Resources

- **[FAQ](./appendix/faq.md)** - Frequently asked questions
- **[Troubleshooting](./appendix/troubleshooting.md)** - Common issues
- **[Changelog](./appendix/changelog.md)** - Version history
- **[Migration Guides](./appendix/migration-guides.md)** - Upgrade guides
- **[Contributing](./appendix/contributing.md)** - Contribute to docs

## Support

- **GitHub**: [0xIntuition/intuition-contracts-v2](https://github.com/0xIntuition/intuition-contracts-v2)
- **Discord**: [Join our community](https://discord.gg/intuition)
- **Documentation Issues**: [Report here](https://github.com/0xIntuition/intuition-contracts-v2/issues)

## License

This project is licensed under BUSL-1.1. See the LICENSE file for details.

---

**Last Updated**: December 2025 | **Protocol Version**: V2
