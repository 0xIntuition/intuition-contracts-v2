# Audit Report: MultiVaultCore (Cluster A/B — core storage/config + term/vault primitives)

**Date:** 2026-07-24
**Auditor:** Checklist-driven, Solodit-anchored review (Cyfrin/audit-checklist, 370 items / 13 categories)
**Method:** `smart-contract-audit` skill walk, run as **round-3 breadth backstop** for the v1.1.0 internal pre-audit (handoff `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`, cluster A/B core context).
**Target:** `src/protocol/MultiVaultCore.sol` (interface `src/interfaces/IMultiVaultCore.sol`)
**Reviewed commit:** `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)
**Toolchain confirmed:** Solidity `0.8.29`, `evm_version = "cancun"`, OpenZeppelin `5.x` upgradeable (ERC-7201 namespaced base storage), TransparentUpgradeableProxy.

> **Pre-audit artifact.** This is an internal, checklist-anchored review — **not** a formal audit, certification, or guarantee. It is directed breadth coverage that feeds the external audit. Every finding is anchored to a checklist item id so the reasoning is traceable to prior art; the checklist is a floor, not a ceiling. This round is independent of the frontier round; confirmations are marked `(dup Fable-…)`.

---

## Scope

`MultiVaultCore` is an **abstract** base contract (`is IMultiVaultCore, Initializable`) inherited by `MultiVault`. It owns the protocol's core storage — `totalTermsCreated`, the six config structs (`generalConfig`, `atomConfig`, `tripleConfig`, `walletConfig`, `vaultFees`, `bondingCurveConfig`), and the four term mappings (`_atoms`, `_triples`, `_isTriple`, `_tripleIdFromCounterId`) — plus the atom/triple/counter-triple **ID-derivation** primitives, the term/vault-type classification helpers, and the read-only getters that `MultiVaultLib`, `MultiVault`, and `AtomWarden` build on. It re-exports `ATOM_SALT` / `TRIPLE_SALT` / `COUNTER_SALT` from `MultiVaultLib` (single source of truth) to preserve the public-getter selectors.

**Attack-surface shape (decisive for this contract):** every `external`/`public` function in `MultiVaultCore` is `view` or `pure`. There is **no attacker-reachable state-mutating entry point** in this file. The only state writes are `__MultiVaultCore_init` (`onlyInitializing`) and the internal `_setGeneralConfig`, reached solely from the derived `MultiVault`'s `initialize`/`reinitialize` and the `onlyTimelock` runtime setters. Consequently the review centers on **correctness of the primitives other contracts trust** (§2 handoff row for MultiVaultCore + §6.B), not on a permissionless exploit path within this file:

1. **No accounting/ID drift vs the library extraction** — `MultiVaultLib` re-implements the same ID and cost/vault-type primitives against the same storage; they must be byte-identical (§5.1).
2. **ID derivation collision-safety** — `calculateAtomId` / `calculateTripleId` / `calculateCounterTripleId` use `abi.encodePacked` in hash generation (SOL-Basics-VI-SVI-4).
3. **Storage-layout consistency** between core / library / vault (§5.5, SOL-Basics-PU-9/PU-10).
4. **Config validation** in the one shared write chokepoint `_setGeneralConfig` (SOL-CR-7).
5. **Getter correctness** for the wiring consumers depend on (`getGeneralConfig().admin`, `getAtomCreator`/`getAtomCreatedAt`, `isAtom`, `getVaultType`, `computeAtomWalletAddr`).

No ERC20/4626, oracle, AMM, bridge, merkle, signature, inline-assembly, or low-level-call surface exists in this contract.

**Headline result:** no Critical or High issue on this surface. ID derivation is collision-safe, the core/library primitives are byte-identical (no drift), and the storage layout is byte-exact between core, library, and vault (verified by `forge inspect`). Findings are **1 Low + 4 Informational + 1 config-risk + 2 Open Questions**.

## Checklist coverage

- **Categories walked (5):** Attacker's Mindset (25), Basics (135), Heuristics (17), Centralization Risk (7), External Call (14) — **198 items**.
- **Categories not loaded (8):** DeFi, Token, Integrations, Hash/Merkle, Signature, Multi-chain, Low-Level, Timelock — **not applicable to this file**: no pricing/liquidation/oracle math (the fee/curve math lives in `MultiVaultLib` and the curves, cluster B/C), no custom token, no external integration, no merkle proofs, no signatures, no cross-chain code, no assembly, no timelock contract (the `onlyTimelock` gate lives on `MultiVault`'s setters). This is a **partial walk by design** — the eight skipped categories have no reachable surface in `MultiVaultCore`.
- **Result:** 0 Critical, 0 High, 1 Low, 4 Informational, 1 config-risk, 2 Open Questions.

---

## Findings

### [Low] `_setGeneralConfig` validates only `admin != 0` — a `feeDenominator == 0` retune silently bricks the whole write path (ref: SOL-CR-7, SOL-Basics-Function-1, SOL-Basics-Math-6)

- **Location:** `MultiVaultCore.sol:268-271` (`_setGeneralConfig`, the single validation chokepoint), reached from `MultiVault.setGeneralConfig` (`MultiVault.sol:808`, `onlyTimelock`) and `__MultiVaultCore_init` (`MultiVaultCore.sol:111`). Division site: `MultiVaultLib._feeOnRaw` (`MultiVaultLib.sol:1502-1504`, `amount.mulDivUp(fee, generalConfig.feeDenominator)`).
- **Impact:** `_setGeneralConfig` guards only `admin != address(0)`. Every other `GeneralConfig` field — `feeDenominator`, `minShare`, `minDeposit`, `feeThreshold`, `protocolMultisig`, `trustBonding`, `atomDataMaxLength` — is written unchecked. If a timelock transaction sets `feeDenominator == 0`, the transaction succeeds silently, and the **next** create/deposit/redeem reverts inside `_feeOnRaw` (`mulDivUp` with a zero denominator reverts). All create, deposit, and redeem paths route through `_feeOnRaw`, so the entire user write path is bricked until another timelock transaction restores a nonzero denominator (recoverable, but subject to the 3-day parameter-timelock delay).
- **Exploit path:** Not attacker-reachable — `setGeneralConfig` is `onlyTimelock` (4-of-8 Safe → 3-day `TimelockController`, handoff §3). This is a trusted-admin **footgun / silent-misconfig** class, filed per the handoff's "note trusted-admin actions separately" mandate and the checklist's privileged-setter-validation requirement.
- **Recommendation:** Add range validation in `_setGeneralConfig` for the load-bearing numeric fields — at minimum `if (_generalConfig.feeDenominator == 0) revert MultiVaultCore_InvalidInput();` (division-by-zero guard), and ideally sanity bounds on `minShare` / `minDeposit` / `feeThreshold` and a `protocolMultisig != 0` / `trustBonding != 0` check. Because `_setGeneralConfig` is the shared chokepoint for both init and the runtime setter, one guard here covers every path.
- **Status:** Open — parameterization/validation hardening. Low (trusted, silent, recoverable).

---

### Informational

| # | Location | Note (checklist ref) |
|---|---|---|
| I-1 | `MultiVaultCore.sol` (no `__gap`); layout below | **No storage gap in the abstract base — upgrade-discipline hazard.** `MultiVaultCore` declares slots 0–25 and has **no `__gap`**; `MultiVault` appends its own state directly at slot 26, and the delegatecall library `MultiVaultLib.Storage` hard-codes the *combined* layout (slots 0–37). Inserting any new state variable into `MultiVaultCore` in a future upgrade would shift every `MultiVault` slot (26+) and **desync the library mirror → fund corruption**. Discipline: append new base state only via `MultiVault`'s `__gap`, never into `MultiVaultCore`. Verified layout is currently correct (see table). **SOL-Basics-PU-9 / PU-10, SOL-Basics-Inheritance-4.** |
| I-2 | `MultiVaultCore.sol:100-117` (`__MultiVaultCore_init`) | **Init does not emit the `*ConfigUpdated` events.** The initializer writes `atomConfig`/`tripleConfig`/`walletConfig`/`vaultFees`/`bondingCurveConfig` directly and `_setGeneralConfig` writes `generalConfig` — none emit the `GeneralConfigUpdated` / `AtomConfigUpdated` / … events declared in `IMultiVaultCore`. Only the runtime `MultiVault` setters emit (`MultiVault.sol:810,825,831,837,848,854`). Indexers/monitors that reconstruct config from events see nothing at deploy/upgrade time. Harmless but worth an explicit note. **SOL-CR-5, SOL-Basics-Event-1.** |
| I-3 | `MultiVaultCore.sol:244-246,187-190,275-277` | **`isTriple(counterTripleId) == true` and `triple(counterId)` returns the underlying atom ids.** `_initializeTripleState` (`MultiVaultLib.sol:735-743`) sets `isTriple = true` and `triples = atomsArray` for **both** the positive and the counter id, so the `isTriple` / `triple` getters report a counter-triple as a structural triple. Only `getVaultType` / `isCounterTriple` distinguish direction — and the library's internal consumers correctly use those. The `IMultiVaultCore.isTriple` NatSpec ("True if the term ID is a triple") is imprecise for counter-triples. Consistent with pre-refactor behavior; no security impact within the reviewed code. **SOL-Basics-Function-4.** |
| I-4 | `MultiVaultCore.sol:254-256,207-209,343-349` | **`getInverseTripleId` / `getCounterIdFromTripleId` do not validate the input is a real triple.** For an atom or unknown id, `_getInverseTripleId` falls through to `_calculateCounterTripleId(id)` and returns a deterministic-but-meaningless id without reverting (`getInverseTripleId` also has no existence guard). These are view helpers; the library's state-changing consumers gate on `isTriple` / `getVaultType` (`_hasCounterStake` at `MultiVaultLib.sol:1475-1484`) before use, so no mis-routing is reachable. Surfaced so integrators do not treat the output as proof of triple existence. **SOL-Heuristics-11, SOL-Basics-Function-2.** |

**Confirmed v1.1.0 storage layout (`forge inspect … storage-layout`) — core vs. vault vs. library:**

| Slot | `MultiVaultCore` (this file) | `MultiVault` (derived) | `MultiVaultLib.Storage` mirror |
|---|---|---|---|
| 0 | `totalTermsCreated` (uint256) | same | `totalTermsCreated` |
| 1–8 | `generalConfig` (GeneralConfig, 256 B) | same | `generalConfig` |
| 9–10 | `atomConfig` | same | `atomConfig` |
| 11–12 | `tripleConfig` | same | `tripleConfig` |
| 13–16 | `walletConfig` | same | `walletConfig` |
| 17–19 | `vaultFees` | same | `vaultFees` |
| 20–21 | `bondingCurveConfig` | same | `bondingCurveConfig` |
| 22 | `_atoms` | same | `atoms` |
| 23 | `_triples` | same | `triples` |
| 24 | `_isTriple` | same | `isTriple` |
| 25 | `_tripleIdFromCounterId` | same | `tripleIdFromCounterId` |
| 26 | — | `approvals` | `approvals` |
| 27 | — | `_vaults` | `vaults` |
| 28 | — | `accumulatedProtocolFees` | `accumulatedProtocolFees` |
| 29 | — | `accumulatedAtomWalletDepositFees` | `accumulatedAtomWalletDepositFees` |
| 30 | — | `totalUtilization` | `totalUtilization` |
| 31 | — | `personalUtilization` | `personalUtilization` |
| 32 | — | `userEpochHistory` | `userEpochHistory` |
| 33 | — | `hasRolledOverSystemUtilization` | `hasRolledOverSystemUtilization` |
| 34 | — | `timelock` (address) | `timelock` |
| 35 | — | `atomCreators` | `atomCreators` |
| 36 | — | `atomCreatedAt` (mapping→uint48) | `atomCreatedAt` |
| 37 | — | `lastSystemUtilizationEpoch` (uint256) | `lastSystemUtilizationEpoch` |
| 38–84 | — | `__gap` (uint256[47]) | — |

Core owns slots 0–25; the vault appends 26–37; the delegatecalled library's `Storage` struct maps **byte-exactly** to 0–37. OZ v5 base mixins (`Initializable`, `AccessControl`, `ReentrancyGuard`, `Pausable`, `Multicall`) are ERC-7201-namespaced and consume no sequential slot, which is why `totalTermsCreated` sits at slot 0. **§5.5 layout consistency holds.** (dup Fable-B — cluster B reached the same byte-exact-mirror conclusion for slots 0–37.)

---

### Configuration risk (go-live decision)

### [Low, config-contingent] `bondingCurveConfig.registry` is mutable despite the "must not be changed after initialization" invariant (ref: SOL-CR-4, SOL-CR-7)

- **Location:** Invariant declared on the config struct at `IMultiVaultCore.sol:70-71` ("The BondingCurveRegistry contract address (**must not be changed after initialization**)"); the struct is stored in `MultiVaultCore` (`bondingCurveConfig`, slot 20–21) but the runtime setter `MultiVault.setBondingCurveConfig` (`MultiVault.sol:852-855`, `onlyTimelock`) replaces the **entire** struct, `registry` included, with no immutability guard.
- **Impact:** Re-pointing `registry` post-init would re-price **every** vault (all `previewDeposit`/`previewRedeem`/`currentPrice` reads route through the registry in `MultiVaultLib`), potentially desyncing share↔asset accounting protocol-wide. The setter is `onlyTimelock`, so this is a trusted-admin footgun, not an attacker path — but the documented invariant is not enforced in code.
- **Recommendation:** Either enforce registry-immutability in the setter (preserve the stored `registry`, allow only `defaultCurveId` to change), or update the NatSpec to drop the "must not be changed" claim and document the operational risk. Consistency over the specific choice.
- **Status:** Open — the setter lives on `MultiVault` (adjacent scope); recorded here because the invariant is declared on the core config struct this contract owns.

---

### Open questions for the developer

- **OQ-1 — `atomCreatedAt` uint48 truncation + pre-upgrade zero-default (ref: SOL-Basics-Type-1, SOL-Heuristics-11).** The library writes `s.atomCreatedAt[atomId] = uint48(block.timestamp)` (`MultiVaultLib.sol:610`) and `getAtomCreatedAt` returns it (`MultiVault.sol:351`). The cast is safe until year ~8.9M (uint48 max ≈ 2^48 s), so overflow is a non-issue. The live concern is the **zero default** for atoms created before the upgrade (`atomCreators == 0`, `atomCreatedAt == 0`): confirm no consumer treats `createdAt == 0` as "just created." `AtomWarden.claimAsCreatorAfterExpiry` (cluster D) keys off creator+createdAt — for legacy atoms `creator == address(0)` makes the fallback unclaimable (safe), but please confirm the expiry-window math handles `createdAt == 0` deliberately.
- **OQ-2 — storage-layout CI gate covering the base contract (ref: SOL-Basics-PU-9).** `MultiVaultLib.sol:93-95` NatSpec references a "storage-layout diff gate," which Fable-B-01 flagged as **absent from CI**. Because `MultiVaultCore`'s slots 0–25 are the load-bearing base of the library mirror and the base has **no `__gap`** (I-1), a golden-snapshot `forge inspect` gate should pin **both** `MultiVaultCore` and `MultiVault` layouts so an accidental base-contract insertion is caught before it desyncs the library. (dup Fable-B-01.)

---

## Acknowledged non-issues (properties checked and cleared)

Each line is a hypothesis attempted and refuted, with the defending guard cited — the "we looked here and it held" evidence.

- **PASS — ID-derivation hash collision** (SOL-Basics-VI-SVI-4). Tried crafting atom `data` (or a `(s,p,o)` tuple) whose derived id collides across the atom / triple / counter namespaces. Defended: every `abi.encodePacked` argument in `_calculateAtomId` (`MultiVaultCore.sol:281-283`), `_calculateTripleId` (`:290-300`), `_calculateCounterTripleId` (`:305-307`) is a **fixed-size `bytes32`** — `data` is pre-hashed to `keccak256(data)` before packing, so there is no dynamic-type boundary ambiguity (SVI-4 requires two adjacent dynamic operands; none exist here). The three distinct salts (`keccak256("ATOM_SALT")` / `"TRIPLE_SALT"` / `"COUNTER_SALT"`) domain-separate the namespaces, and the preimages differ in their leading 32 bytes; a cross-namespace collision requires a keccak256 collision. Held.
- **PASS — core ↔ library primitive drift (§5.1 conservation / no accounting drift).** Compared every primitive re-implemented in both contracts: `_calculateAtomId` (`MultiVaultCore.sol:281` vs `MultiVaultLib.sol:1531`), `_calculateTripleId` (`:290` vs `:1535`), `_calculateCounterTripleId` (`:305` vs `:1547`), `_getVaultType` (`:352` vs `:1575`), `_getInverseTripleId` (`:343` vs `:1567`), `_isCounterTriple` (`:312` vs `:1555`), `_getTriple` (`:332` vs `:1559`), `_getAtomCost` (`:368` vs `:1589`), `_getTripleCost` (`:374` vs `:1594`). All **byte-identical** in formula and salts (the salts are re-exported from the library so both sides inline the same literal). No drift → the off-chain `calculateAtomId`/`calculateTripleId` a user computes equals the id the library's create path writes. Held. (SOL-Heuristics-1 — duplicated logic reviewed for divergence.)
- **PASS — storage-layout consistency (§5.5).** `forge inspect MultiVaultCore` and `forge inspect MultiVault` confirm core = slots 0–25, vault appends 26–37, and `MultiVaultLib.Storage` mirrors 0–37 exactly (table above). Held. (dup Fable-B.)
- **PASS — access control / no attacker-reachable mutation** (SOL-Basics-AC-2, SOL-Basics-Function-9). Every `external`/`public` function in `MultiVaultCore` is `view`/`pure`; the only writers are `__MultiVaultCore_init` (`onlyInitializing`, `:109`) and internal `_setGeneralConfig` (`:268`), reached solely via `MultiVault`'s initializer and `onlyTimelock` setters. No permissionless state change exists in this file.
- **PASS — initializer safety for an inherited base** (SOL-Basics-Initialization-2, SOL-Basics-PU-1/PU-3). `__MultiVaultCore_init` uses `onlyInitializing` (not `initializer`) — correct for a contract meant to be composed into a derived initializer chain; no standalone public initializer here to front-run.
- **PASS — reentrancy / external calls / delegatecall** (SOL-AM-ReentrancyAttack-2, SOL-EC-3/10/11/13). `MultiVaultCore` makes **no** external calls, no `delegatecall`, no assembly, no ETH movement — nothing to reenter. N/A by construction.
- **PASS — counter-triple sentinel correctness** (SOL-Heuristics-11). `_isCounterTriple` keys on `_tripleIdFromCounterId[termId] != 0`; the stored positive `tripleId` is a keccak256 output (never 0), and the mapping is written only in `_initializeTripleState`, so the zero-as-sentinel test cannot misfire for a real counter-triple. Held.
- **PASS — atom-creation attribution** (§5.1). `getAtomCreator`/`getAtomCreatedAt` (`MultiVault.sol:346-353`) read slots 35/36, exactly where the library's `_createAtom` writes `atomCreators`/`atomCreatedAt` (`MultiVaultLib.sol:609-610`); attribution follows the `creator` argument (the on-behalf-of principal for `createAtomsFor`, else `msg.sender`). Slots confirmed by `forge inspect`. Held.

---

## Appendix — methodology & provenance

- **Skill:** `smart-contract-audit` (project-local, `.claude/skills/smart-contract-audit`; checklist adapted from `Cyfrin/audit-checklist`, MIT).
- **Round:** 3 (low-cost breadth backstop) for the v1.1.0 internal pre-audit. This checklist-driven pass is intentionally a *different* method from the hypothesis-driven frontier/cross-model rounds — its value is systematic category coverage, not novel exploit discovery. Independent walk; duplicates of the frontier round are tagged `(dup Fable-…)`.
- **Verification performed:** full source read of `MultiVaultCore.sol` + `IMultiVaultCore.sol`; cross-read of `MultiVaultLib.sol` (the re-implemented primitives + storage mirror), `MultiVault.sol` (inheritance chain, config setters, atom-creator getters, `__gap` sizing); `forge inspect` storage-layout on **both** `MultiVaultCore` and `MultiVault` (authoritative slot maps above); solc `0.8.29` / `evm cancun` confirmed; compilation confirmed via `forge inspect` build.
- **Not performed (recommended next):** no PoC test was written (no Critical/High reached); the `feeDenominator == 0` brick (LC-Core-01) and the missing base-contract layout CI gate (OQ-2) warrant a unit test each — a `test_setGeneralConfig_revertsWhenFeeDenominatorZero` (currently would *not* revert at set-time) and a golden `forge inspect` snapshot diff over `MultiVaultCore` + `MultiVault`.
- **Merge note:** map into the found→fixed log with ids `LC-Core-01 … LC-Core-06`; severities map to the Diligence house scale as Low→Minor, Informational→Informational.

**Summary table**

| ID | Severity | Confidence | Checklist ref | Title | Status |
|---|---|---|---|---|---|
| LC-Core-01 | Low | High | SOL-CR-7, SOL-Basics-Math-6, SOL-Basics-Function-1 | `_setGeneralConfig` validates only `admin` — `feeDenominator==0` bricks write path | Open |
| LC-Core-02 | Informational | High | SOL-Basics-PU-9/PU-10, SOL-Basics-Inheritance-4 | No `__gap` in abstract base — future base-slot insertion desyncs library mirror | Open |
| LC-Core-03 | Informational | High | SOL-CR-5, SOL-Basics-Event-1 | Initializer does not emit `*ConfigUpdated` events | Open |
| LC-Core-04 | Informational | Medium | SOL-Basics-Function-4 | `isTriple`/`triple` report counter-triples as triples (NatSpec imprecise) | Open |
| LC-Core-05 | Informational | Medium | SOL-Heuristics-11, SOL-Basics-Function-2 | `getInverseTripleId`/`getCounterIdFromTripleId` return junk id for non-triples (no guard) | Open |
| LC-Core-06 | Low (config) | High | SOL-CR-4, SOL-CR-7 | `bondingCurveConfig.registry` mutable despite "immutable after init" NatSpec | Open |

**Counts:** 0 Critical, 0 High, 0 Medium, 1 Low, 4 Informational, 1 config-risk (Low), 2 Open Questions.

**VERDICT: PASS** (cluster A/B core — no High/Critical property failed; no unresolved Medium on a funds path). ID derivation is collision-safe, core/library primitives are byte-identical (no drift), and the core/library/vault storage layout is byte-exact (`forge inspect`-verified). Residuals are one trusted-admin validation footgun (`feeDenominator==0`), one upgrade-discipline note (no base `__gap`), and minor getter/NatSpec informationals.
