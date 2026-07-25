# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 4 of 6 — Cyfrin skill (`smart-contract-audit`, 10-agent per-contract checklist)

> **How this report was produced:** the local `smart-contract-audit` skill — the 370-item Cyfrin/Solodit checklist
> across 13 categories — run as **ten independent per-contract reviewers**, one per in-scope diffed contract, each
> loading only the scope-relevant checklist categories, anchoring every finding to a checklist id, and recording a
> refutation attempt for every PASS. In this batch it is labeled the **"Cyfrin skill"** round: the checklist skill in
> multi-agent per-contract mode. Its single-reviewer sibling is the **"Trail of Bits skill"** report
> ([`skill-trail-of-bits-checklist.md`](skill-trail-of-bits-checklist.md)). Provenance ID prefix: `CYF-`. This is one of
> six independent round reports; the consolidated, de-duplicated view is
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

|                     |                                                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Artifact type**   | Internal AI pseudo-audit — pre-external-audit. **Not** a formal audit, certification, warranty, or guarantee of safety. |
| **Project**         | `intuition-contracts-v2` public mirror — v1.1.0 core upgrade (PR #153)                                                  |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)                                          |
| **Toolchain**       | Solidity `0.8.29`, Foundry, EVM `cancun` (EIP-1153), OpenZeppelin `5.4.0`; TransparentUpgradeableProxy throughout       |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                        |
| **Date**            | 2026-07-25                                                                                                              |
| **Method**          | Checklist-driven, 10 independent per-contract reviewers; each finding anchored to a checklist id, PoC for the Major     |
| **Burn sink**       | `BURN_ADDRESS` = `0x000000000000000000000000000000000000dEaD`, resolved from `MultiVaultLib`                            |

---

## 1. Executive summary

This round ran the checklist skill as ten independent per-contract reviewers over the 13 in-scope diffed contracts of PR
#153. Its distinguishing result is **one net-new Major** that neither the vanilla frontier round nor the single-reviewer
checklist round reached: a **beacon-upgrade migration defect that permanently bricks any AtomWallet already claimed
under the legacy `Ownable2Step` model** (`CYF-E-01`). The multi-agent, per-contract depth is what surfaced it — a
whole-suite reviewer tends to miss the cross-implementation (legacy-vs-new storage) seam that a single-contract
reviewer, forced to reconcile `main` against the branch, does not.

**Headline result: 0 Critical · 1 Major · 1 Medium · ~14 Minor · ~25 Informational.** The Medium is a confirmed
duplicate of the ERC-1271 raw-digest replay found by the frontier (`CLD-E-01`) and single-reviewer checklist (`TOB-01`)
rounds — independent re-derivation, which raises confidence it is real. The Minor/Informational tail is dominated by
initialization-safety (un-gated `initialize`, unset `multiVault`), one-step admin/timelock rotations
(governance-mitigated), and configuration footguns (`feeDenominator == 0`, `emissionsLength == 0`).

### Findings by severity

| Severity      | Count | Notable IDs                                                              |
| ------------- | ----- | ------------------------------------------------------------------------ |
| Critical      | 0     | —                                                                        |
| Major         | 1     | CYF-E-01 (net-new)                                                       |
| Medium        | 1     | CYF-E-02 / CYF-E-F-01 (dup of CLD-E-01 / TOB-01)                         |
| Minor         | ~14   | CYF-Core-01, CYF-A-05, CYF-E-03, CYF-E-F-03, CYF-C-01/02/03, CYF-H-01, … |
| Informational | ~25   | CYF-G-02, plus per-contract hygiene / open questions                     |

---

## 2. Scope

Basis: the 22 source files changed by PR #153 (`git diff main...HEAD`), filtered to the handoff §2 in-scope set minus §3
exclusions → **13 in-scope diffed contracts**, one per-contract reviewer each. Per-contract working reports are retained
under the private monorepo
(`contracts/core/private/internal-audits/v1.1.0-round-1/working-logs/cyfrin-per-contract-checklists/`).

| Cluster | Contract(s)                                                                 |
| ------- | --------------------------------------------------------------------------- |
| A       | `protocol/MultiVault.sol`                                                   |
| B       | `libraries/MultiVaultLib.sol`                                               |
| A/B     | `protocol/MultiVaultCore.sol`                                               |
| C       | `curves/BaseCurve.sol`, `LinearCurve.sol`, `BondingCurveRegistry.sol`       |
| D       | `wallet/AtomWarden.sol`                                                     |
| E       | `wallet/AtomWallet.sol`                                                     |
| E       | `wallet/AtomWalletFactory.sol`, `libraries/CoinbaseSmartWalletLib.sol`      |
| F       | `emissions/TrustBonding.sol`                                                |
| G       | `periphery/FeeProxy.sol`                                                    |
| H       | `emissions/CoreEmissionsController.sol`, `SatelliteEmissionsController.sol` |

**Excluded (diffed but out of scope, handoff §3):** `Trust.sol`, `external/curve/VotingEscrow.sol`, the
progressive-curve family, `BaseEmissionsController.sol`, `MetaERC20Dispatcher.sol`, `MultiVaultMigrationMode.sol`.
**Cluster C fee economy absent:** `DynamicFeeFlatPriceCurve.sol` does not exist at `b52557b` and `IBaseCurve` has no
quote/record hooks (matches both other rounds); re-run Cluster C once it lands.

---

## 3. Severity classification

Impact × Likelihood, Diligence house labels (Critical / Major / Medium / Minor / Informational). Handoff severities map
Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→Informational.

---

## 4. Findings

### CYF-E-01 — Beacon upgrade permanently bricks a legacy `Ownable2Step`-claimed AtomWallet — Major (net-new)

- **Status:** Open — **net-new** (neither the frontier `CLD-*` round nor the single-reviewer `TOB-*` checklist round
  reached this). Remediation appears in progress on-branch (see master report); not verified fixed in this round.
- **Confidence:** mechanism High / reachability Medium (gated on an on-chain census — Open Question OQ-E-1 below).
- **Affected code:** `src/protocol/wallet/AtomWallet.sol` — new `isClaimed` @ slot 1 (offset 20, persists), `_claimant`
  @ slot 3, `completeClaim` `isClaimed` gate at `:299-301`, MultiOwnable-rooted `owner()` / execution gates — versus the
  legacy implementation on `main` (`Ownable2StepUpgradeable`; owner in the OZ `Ownable` namespaced slot;
  `owner() == isClaimed ? $._owner : atomWarden`). Delivery vehicle: the shared `UpgradeableBeacon` — a single
  `upgradeTo` swaps every wallet's implementation simultaneously.
- **Invariant broken:** authorization + fund-custody continuity across an upgrade (handoff §5 / §6.E) — a wallet validly
  owned before the upgrade must remain operable and its funds withdrawable after.
- **Attacker capability:** none — a migration-safety defect triggered by the ordinary v1.1.0 beacon upgrade.
  Precondition: ≥1 AtomWallet was **claimed** under the legacy `Ownable2Step` model (`isClaimed == true`, owner in the
  OZ `Ownable` slot) **and holds value** at the moment of the upgrade.
- **Proof of concept** (`tests/unit/security/v1.1.0/FrontierRound_WalletUpgrade.t.sol`, run against the real new
  `AtomWallet`):
  1. A legacy wallet behind the beacon is claimed (`transferOwnership` → `acceptOwnership` ⇒ `isClaimed`,
     `owner() == claimant`); fund it with 5 ETH.
  2. `beacon.upgradeTo(newAtomWalletImpl)` — the proxy now runs the MultiOwnable v1.1.0 implementation.
  3. Post-upgrade at `b52557b`: `isClaimed` **persists** true; the MultiOwnable registry is **empty**; `_claimant == 0`,
     so `owner() == 0`, `ownerCount() == 0`, `isOwnerAddress(claimant) == false`.
  4. Assertion that fails: `claimant.execute(...)` reverts `AtomWallet_OnlyOwnerOrEntryPoint`;
     `AtomWarden.completeClaim(claimant)` reverts `AtomWallet_AlreadyClaimed` (isClaimed is already true). No path
     re-seeds the registry. **The 5 ETH + any accrued fees are permanently locked.**
- **Impact:** permanent, irrecoverable loss of custody for every legacy-claimed, value-holding AtomWallet at upgrade
  time — direct user fund lockout.
- **Independent verification (not taken on the sub-agent's word):** `forge inspect` confirms the new `isClaimed` @ slot
  1 offset 20 and `_claimant` @ slot 3; `main` confirms the legacy `Ownable2Step` owner in the OZ `Ownable` namespaced
  slot; the new `completeClaim` reverts on `isClaimed` and seeds the MultiOwnable registry only inside itself; the
  bricked end-state was reproduced against the real implementation.
- **Reachability caveat:** requires ≥1 legacy wallet claimed under `Ownable2Step` holding value at the swap — a
  live-chain census question (the beacon's proxy population and each wallet's claim/balance) that cannot be answered
  from the repo. Fresh / unclaimed wallets migrate cleanly.
- **Recommendation:** add a legacy-owner migration path so a wallet already claimed under `Ownable2Step` can seed the
  MultiOwnable registry post-upgrade — lazily on first `execute`/`transferOwnership` (resolve `owner()` from the legacy
  `Ownable` slot when the registry is empty but `isClaimed` is true), and/or an explicit `migrateLegacyOwner()`, and/or
  a one-shot census + re-seed in the upgrade script. Gate the upgrade on an on-chain count of claimed legacy wallets.
- **Regression test:** `FrontierRound_WalletUpgrade.t.sol` must assert a claimed legacy wallet retains `owner()` and
  `execute` after the upgrade, and go red if the migration path is removed.
- **Variant sweep:** unclaimed / fresh wallets — safe; EOA vs passkey legacy owner — same mechanism (the owner slot, not
  the key type, is the pivot); UserOp path — same lockout.
- **Open Question OQ-E-1:** were any AtomWallets claimed under `Ownable2Step` on the live chain before this upgrade, and
  do they hold value? This is the gate on whether `CYF-E-01` is live-reachable or defused-by-population.

### CYF-E-02 / CYF-E-F-01 — ERC-1271 verifies the raw digest, no `address(this)` binding → cross-wallet / cross-chain replay — Medium (duplicate)

- **Status:** Open. **Confirmed duplicate** of `CLD-E-01` and `TOB-01` (independently re-derived here). Full PoC in
  those logs and in the two cluster-E per-contract reports.
- **Affected code:** `src/protocol/wallet/AtomWallet.sol` — `isValidSignature` verifies the raw digest without wrapping
  it in a wallet-bound `replaySafeHash` (no `address(this)` / domain binding).
- **Mechanism:** because the digest is not bound to the wallet, a signature produced for one AtomWallet validates on
  every other AtomWallet that shares the signer's key, and across chains. Exploitable under owner-unbound EIP-712
  integrations (e.g. Permit2 `SignatureTransfer`), which the wallet's own NatSpec advertises support for.
- **Recommendation:** restore an EIP-712 `replaySafeHash` wrapper binding the digest to `address(this)` and the chain id
  before ECDSA / P-256 verification on the ERC-1271 path.

### 4.1 Minor / Informational tail (condensed)

Full Location / Impact / PoC / Recommendation / refutation for each item are in the per-contract reports under the
private monorepo (`contracts/core/private/internal-audits/v1.1.0-round-1/working-logs/cyfrin-per-contract-checklists/`).
The load-bearing tail:

| ID                             | Sev   | Cluster | Title                                                                                            | Also found as            |
| ------------------------------ | ----- | ------- | ------------------------------------------------------------------------------------------------ | ------------------------ |
| CYF-Core-01                    | Minor | A/B     | `feeDenominator == 0` (timelock retune) bricks all create/deposit/redeem (div-by-zero)           | — (net-new)              |
| CYF-A-05                       | Minor | A       | `redeem`/`redeemBatch` are `whenNotPaused` — a pause freezes user exits                          | — (likely risk-acc.)     |
| CYF-E-03                       | Minor | E       | `transferOwnership` evicts the primary owner, bypassing the removal guard                        | CLD-E-02, TOB-09         |
| CYF-E-F-03                     | Minor | E       | P-256/WebAuthn path is inert unless the RIP-7212 precompile / verifier is on the Intuition chain | — (net-new, config)      |
| CYF-E-F-04                     | Minor | E       | Mutating `walletConfig.entryPoint` / `atomWalletBeacon` orphans deployed wallets                 | — (trusted-admin)        |
| CYF-C-01                       | Minor | C       | `supply == 0` mints 1:1 ignoring `totalAssets`; par rests on the vault ghost-share seed          | —                        |
| CYF-C-02                       | Minor | C       | Curve `initialize` is not access-gated — front-runnable on a non-atomic deploy                   | —                        |
| CYF-C-03                       | Minor | C       | No curve deregister / disable path — a bad curve is permanent                                    | —                        |
| CYF-D-L2                       | Minor | D       | `initialize` front-runnable on a fresh deploy                                                    | —                        |
| CYF-Core-06                    | Minor | A/B     | `bondingCurveConfig.registry` mutable despite "immutable after init" NatSpec                     | —                        |
| CYF-F-01                       | Minor | F       | `MINTIME ≥ EPOCH_LENGTH` snapshot-safety invariant unenforced                                    | TOB-04                   |
| CYF-F-02                       | Minor | F       | `multiVault` unset in `initialize` — epoch ≥ 2 reverts until the timelock setter runs            | —                        |
| CYF-H-01                       | Minor | H       | `emissionsLength` unvalidated → div-by-zero → protocol-wide DoS on misconfig                     | CLD-H-01, TOB-08, GPT-02 |
| CYF-D-L1 / CYF-F-03 / CYF-G-04 | Minor | D/F/G   | One-step admin / timelock / privilege transfers                                                  | — (gov-mitigated)        |
| CYF-G-02                       | Info  | G       | `feeRecipient == self / multiVault` silently strands affiliate fees                              | TOB-06                   |
| CYF-Core-02                    | Info  | A/B     | Abstract base missing `__gap` (future-upgrade slot-shift risk)                                   | — (net-new)              |

---

## 5. Cluster verdicts (properties checked)

| Cluster                             | Verdict  | Notes                                                                                                                                                    |
| ----------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A — MultiVault                      | PASS     | §5.6 no-value-replay + §5.1 conservation hold; transient state cleared on every exit incl. caught reverts; cross-checked vs the existing security suite. |
| B — MultiVaultLib                   | PASS     | `forge inspect` proves the byte-exact mirror (slots 0–37, `__gap[47]`); rounding uniformly `mulDivUp`.                                                   |
| A/B — MultiVaultCore                | PASS     | No core↔library drift; id derivation collision-safe. 1 Minor (`feeDenominator`).                                                                        |
| C — Curves                          | PASS     | Flat-price par proved algebraically; no argument-order swap; injection blocked. Fee economy absent.                                                      |
| D — AtomWarden                      | PASS     | Quorum / replay / malleability / window-cap defended.                                                                                                    |
| **E — AtomWallet**                  | **FAIL** | **`CYF-E-01` Major (net-new)** + `CYF-E-02` Medium (dup) on funds / auth paths.                                                                          |
| E — AtomWalletFactory + CoinbaseLib | PASS     | CREATE2 determinism defeats reorg / front-run / squat; P-256 fails **closed**.                                                                           |
| F — TrustBonding                    | PASS     | Per-epoch solvency doubly enforced; pause asymmetry safe.                                                                                                |
| G — FeeProxy                        | PASS     | Per-tx + cumulative ETH conservation exact; ledger `msg.sender`-keyed, CEI, `nonReentrant`.                                                              |
| H — Emissions controllers           | PASS     | Schedule math boundary-correct; reclaim replay defended. 1 Minor (`emissionsLength`, dup).                                                               |

**Overall cluster verdict: FAIL** (cluster E: `CYF-E-01` Major + `CYF-E-02` Medium on a funds / auth path). PASS for A,
B, A/B-core, C, D, E-factory/lib, F, G, H.

---

## 6. Cross-round corroboration

Independently re-derived here and in the other rounds (converging methods → strongest signal these are real): ERC-1271
replay (`CYF-E-02` = `CLD-E-01` = `TOB-01`), `emissionsLength` DoS (`CYF-H-01` = `CLD-H-01` = `TOB-08` = `GPT-02`),
primary-owner eviction (`CYF-E-03` = `CLD-E-02` = `TOB-09`), ERC-1271 high-s (= `CLD-E-03` = `TOB-10`), `feeRecipient`
self-reference (`CYF-G-02` = `TOB-06`), `MINTIME` deploy assumption (`CYF-F-01` = `TOB-04`).

**Net-new this round (multi-agent per-contract depth):** `CYF-E-01` (Major, the headline), `CYF-E-F-03` (P-256 /
RIP-7212 availability gate), `CYF-Core-01` (`feeDenominator == 0` write-path brick), the un-gated-`initialize` /
unset-`multiVault` init-safety family (`CYF-C-02` / `CYF-D-L2` / `CYF-F-02`), and `CYF-Core-02` (missing `__gap`).

---

## 7. Appendix — method, constraints, disclaimer

- **Method:** project `smart-contract-audit` skill (Cyfrin `audit-checklist`, 370 items / 13 categories, pinned upstream
  `89906fd`), one independent reviewer per contract / cluster, each loading only scope-relevant category files,
  anchoring every finding to a checklist id and recording a refutation attempt for every PASS (handoff §4).
- **Verification:** each reviewer ran `forge build` / `forge inspect storage-layout` and cross-read `tests/unit/**` and
  `tests/unit/security/v1.1.0/**`; `CYF-E-01` was additionally re-verified by the triage owner against the real new
  `AtomWallet` and the `main` legacy contract, with the PoC executed.
- **Constraints honored:** local only; `src/` not modified; CI / `.github` untouched; reviewed commit `b52557b`;
  mechanism-only descriptions; full-length addresses; **pre-audit artifact — not a formal audit.**
- **Provenance:** ID prefix `CYF-`. Companion working record: the `skill-cyfrin-checklist-multiagent.found-fixed-log.md`
  log and the 10 per-contract reports — all kept in the private monorepo under
  `contracts/core/private/internal-audits/v1.1.0-round-1/working-logs/`.
- **The item to resolve before the upgrade:** `CYF-E-01` — fix the legacy-owner migration path, or prove
  non-reachability via OQ-E-1 (on-chain census of legacy-claimed, value-holding wallets).
