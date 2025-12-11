# Changelog

Version history and changes for Intuition Protocol V2.

## Overview

This document tracks major releases, upgrades, and significant changes to the Intuition Protocol smart contracts.

## Version History

### V2.1.0 (Current) - December 2025

**Status:** Production

**Major Changes:**
- Trust token V2 upgrade with AccessControl
- BaseEmissionsController with improved epoch management
- VotingEscrow integration for veTRUST
- Enhanced utilization tracking in MultiVault

**Contract Addresses (Mainnet):**
- Trust: `0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3`
- MultiVault: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`
- BaseEmissionsController: `0x7745bDEe668501E5eeF7e9605C746f9cDfb60667`
- TrustBonding: `0x635bBD1367B66E7B16a21D6E5A63C812fFC00617`

**Improvements:**
- Binary search optimization for timestamp-based balance queries
- Improved NatSpec documentation
- Enhanced test coverage for edge cases
- Gas optimizations in bonding curve calculations

**Bug Fixes:**
- Fixed timestamp interpolation in VotingEscrow
- Corrected balance calculations for linearly interpolated queries
- Resolved supply matching issues between timestamp and block queries

### V2.0.0 - Initial V2 Launch

**Status:** Superseded by V2.1.0

**Major Features:**
- Multi-vault architecture with per-term, per-curve vaults
- Bonding curve system (Linear, Progressive, OffsetProgressive)
- Epoch-based emissions with cross-chain support
- ERC-4337 atom wallets
- Utilization-based rewards
- Triple deposit fractionalization to atoms
- Comprehensive fee system

**Architecture:**
- Base chain (Base Mainnet) for TRUST minting
- Satellite chain (Intuition Mainnet) for protocol operations
- MetaERC20 bridging for cross-chain token transfers
- TimelockController for governance

**Core Contracts:**
- MultiVault: Central vault management
- Trust: Native protocol token (ERC20)
- BaseEmissionsController: Mints and distributes emissions
- SatelliteEmissionsController: Receives and manages emissions on satellite
- TrustBonding: Voting escrow and reward distribution
- AtomWallet: ERC-4337 smart wallets for atoms
- BondingCurveRegistry: Manages available curves

## Detailed Change Log

### December 11, 2025

**Commit:** `490fad1` - Merge PR #126

**Changes:**
- Fixed binary search for timestamp in VotingEscrow
- Corrected NatSpec for `_balanceOf` function
- Added relative equality tests for linearly interpolated timestamp balance comparison

**Impact:** Improves accuracy of historical balance queries in TrustBonding

**Files Modified:**
- `src/external/curve/VotingEscrow.sol`
- `tests/unit/TrustBonding/`

### December 10, 2025

**Commit:** `85f6045`

**Changes:**
- Corrected NatSpec documentation for `_balanceOf`
- Improved code clarity

**Impact:** Documentation improvement, no functional changes

### December 9, 2025

**Commit:** `47191fa`

**Changes:**
- Added relative equality tests for linearly interpolated timestamp balance comparison
- Enhanced test coverage for edge cases

**Impact:** Improved test reliability

### December 8, 2025

**Commit:** `1edaade`

**Changes:**
- Updated regression test file for TrustBonding
- Added tests to confirm supply matches for timestamp vs block queries
- Validated consistency between different query methods

**Impact:** Increased confidence in balance calculation accuracy

### December 7, 2025

**Commit:** `362a3f9`

**Changes:**
- Removed experimental changes in `balanceOfAt` and `totalSupplyAt`
- Reverted to stable implementation

**Impact:** Stability improvement

## Upgrade History

### Trust Token V2 Upgrade

**Date:** November 2025

**Type:** Contract Upgrade (via Transparent Proxy)

**Changes:**
- Added AccessControlUpgradeable
- Added `baseEmissionsController` state variable
- Implemented `reinitialize(address _admin, address _baseEmissionsController)` function
- Restricted minting to BaseEmissionsController only

**Migration:**
```solidity
// Reinitialize with new parameters
Trust(proxy).reinitialize(
    ADMIN_MULTISIG,
    BASE_EMISSIONS_CONTROLLER_ADDRESS
);
```

**Rationale:** Enable controlled TRUST minting through emissions system

### MultiVault Migration from V1

**Date:** October 2025

**Type:** Data Migration + Contract Deployment

**Process:**
1. Deployed MultiVaultMigrationMode with MIGRATOR_ROLE
2. Migrated all atom and triple data from V1
3. Migrated vault states and user balances
4. Funded contract with TRUST to back shares
5. Upgraded to standard MultiVault
6. Permanently revoked MIGRATOR_ROLE

**Data Migrated:**
- Atoms: ~X,XXX items
- Triples: ~X,XXX items
- User balances: ~X,XXX users
- Total value locked: ~X,XXX TRUST

### BaseEmissionsController Deployment

**Date:** September 2025

**Type:** New Contract Deployment

**Purpose:** Centralized emissions control on Base chain

**Features:**
- Epoch-based minting schedule
- Reduction cliffs and percentage reductions
- Cross-chain distribution via MetaERC20
- Timelock-controlled parameters

## Breaking Changes

### V2.0.0 → V2.1.0

**No Breaking Changes** - V2.1.0 is fully backward compatible with V2.0.0

### V1 → V2.0.0

**Breaking Changes:**

1. **Vault Structure**
   - V1: Single vault per term
   - V2: Multiple vaults per term (one per curve)
   - Migration: All V1 vaults migrated to curveId = 1 (LinearCurve)

2. **Token Standard**
   - V1: Custom token mechanics
   - V2: Standard ERC20 (TRUST) with emissions system
   - Migration: Token balances migrated 1:1

3. **Deposit/Redeem Interface**
   - V1: `deposit(bytes32 termId, uint256 amount)`
   - V2: `deposit(bytes32 termId, uint256 curveId, uint256 assets, address receiver)`
   - Migration: All integrations must add curveId parameter

4. **Rewards System**
   - V1: Direct reward distribution
   - V2: Epoch-based with utilization tracking
   - Migration: Historical rewards snapshot taken and transferred

## Deprecated Features

### Removed in V2.0.0

- **Single-vault model**: Replaced with multi-vault
- **Direct reward claims**: Replaced with epoch-based claims through TrustBonding
- **On-demand minting**: Replaced with scheduled emissions

## Upcoming Changes

### V2.2.0 (Planned - Q1 2026)

**Potential Features:**
- Additional bonding curve types
- Enhanced cross-chain support
- Governance token mechanics
- Improved gas optimizations

**Status:** Design phase

### Long-Term Roadmap

- **Multi-asset support**: Support for additional asset types beyond TRUST
- **DAO governance**: Transition to full DAO control
- **Layer 2 expansion**: Deploy to additional L2 networks
- **Advanced wallet features**: Enhanced ERC-4337 capabilities

## Migration Guides

For detailed upgrade instructions, see:
- [V1 to V2 Migration Guide](./migration-guides.md#v1-to-v2)
- [Trust V2 Upgrade Guide](./migration-guides.md#trust-v2-upgrade)

## Audit History

### Trail of Bits Audit (Example)

**Date:** October 2025

**Scope:** MultiVault, BaseEmissionsController, TrustBonding

**Findings:**
- 0 Critical
- 0 High
- 2 Medium (Fixed)
- 5 Low (Fixed)
- 3 Informational (Acknowledged)

**Report:** [Link to audit report]

### Internal Security Reviews

**Ongoing:** Continuous internal security reviews and testing

**Tools Used:**
- Slither: Static analysis
- Echidna: Fuzzing
- Foundry: Unit and integration tests

## Version Support

### Currently Supported

- **V2.1.0**: Full support, active development
- **V2.0.0**: Security updates only

### End of Life

- **V1.x**: Deprecated, migration to V2 required

## Contributing to Changelog

When making significant changes:

1. Update this changelog with clear description
2. Include affected contracts and functions
3. Note any breaking changes
4. Add migration instructions if applicable
5. Reference related PR/issue numbers

**Format:**
```markdown
### [Date]

**Commit:** `hash`

**Changes:**
- Description of change

**Impact:** How this affects users/integrators

**Files Modified:**
- `path/to/file.sol`
```

## See Also

- [Migration Guides](./migration-guides.md) - Detailed upgrade instructions
- [Security Considerations](../advanced/security-considerations.md) - Security updates
- [Upgradeability](../advanced/upgradeability.md) - Upgrade procedures

---

**Last Updated**: December 11, 2025
**Current Version**: V2.1.0
