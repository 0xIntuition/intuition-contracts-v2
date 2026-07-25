# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1 — MASTER Consolidated Report

> **Artifact type:** Internal AI pseudo-audit — **consolidated master**. This is a **pre-audit artifact — not a formal
> audit, certification, warranty, or guarantee of safety.** It de-duplicates the findings of six independent AI review
> rounds into one release-level, Diligence-style view, and is the go/no-go input handed to the external auditors
> alongside the per-round reports and working found→fixed logs. Findings stay internal until remediated.

|                     |                                                                                                                                                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`, PR #153)                                                                                                                                                                        |
| **Repository**      | `intuition-contracts-v2` (public mirror) — v1.1.0 core upgrade                                                                                                                                                                                                 |
| **Toolchain**       | Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun` (EIP-1153), OpenZeppelin `5.4.0`, solady; TransparentUpgradeableProxy throughout                                                                                                                              |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                                                                                                                                                               |
| **Date**            | 2026-07-25                                                                                                                                                                                                                                                     |
| **Rounds merged**   | 6 independent rounds: 2 vanilla (frontier, cross-model) + 4 skill-driven (ToB single-checklist, Cyfrin 10-agent checklist, HumanPages specialist-selection, Pashov parallel-lens). Breadth (low-cost vanilla) folded as supporting; One Dollar Audit deferred. |
| **Burn sink**       | `BURN_ADDRESS` = `0x000000000000000000000000000000000000dEaD` (ghost/min-share recipient), resolved from `MultiVaultLib`                                                                                                                                       |

---

## 1. Executive summary

The v1.1.0 core upgrade was reviewed **whole-contract** (not diff-scoped) by six independent AI rounds — two vanilla
frontier reasoners of different model families and four audit-skill-driven rounds — each re-deriving from the pre-audit
handoff and the source and scoring against the six load-bearing invariants (§4) with PoC-backed refutation. This master
report merges their findings by content (not by id), so a finding reached by several rounds is called out as
high-signal, and a finding reached by only one round is still triaged.

**Headline result: 0 Critical. 1 Major. 4 Medium.** The single **Major** (`MA-01`) is a migration-safety defect — an
AtomWallet already **claimed under the legacy `Ownable2Step` model** is permanently bricked by the ordinary v1.1.0
beacon upgrade, locking its funds — surfaced only by the Cyfrin 10-agent per-contract round, whose cross-implementation
(legacy-vs-new storage) depth is what the whole-suite rounds missed. Its live reachability is gated on an on-chain
census (Open Question **OQ-E-1**): does any legacy-claimed wallet hold value at upgrade time? The four **Mediums** are
the ERC-1271 cross-wallet/cross-chain signature replay (3 rounds), the zero-epoch-length permanent emissions DoS (4
rounds), the system-utilization carry-forward emission inflation (both skill rounds), and the claim-pause-across-epoch
reward forfeiture (severity-disputed between rounds).

**The six load-bearing invariants held** under adversarial pressure — value conservation, solvency, curve-ledger mirror,
flat-price par, storage-layout upgrade-safety, and the `multicallPayable` no-msg.value-replay property were each probed
with cited refutation attempts across rounds and are recorded as negatives in §6.

**Remediation is in progress on this branch (unverified by this consolidation).** As of the reviewed working tree, there
are uncommitted changes to `AtomWallet.sol`, `CoreEmissionsController.sol`, and the TrustBonding utilization test suite
— consistent with fixes for `MA-01` / `MED-01`, `MED-02`, and `MED-03` respectively. This master does **not** verify
those fixes; every finding below is reported at its as-found status. See §7.

### Findings by severity (consolidated, de-duplicated)

| Severity      | Count | Consolidated IDs               |
| ------------- | ----- | ------------------------------ |
| Critical      | 0     | —                              |
| Major         | 1     | MA-01                          |
| Medium        | 4     | MED-01, MED-02, MED-03, MED-04 |
| Minor         | 9     | MIN-01 … MIN-09                |
| Informational | 7     | INFO-01 … INFO-07              |

_(The four skill/vanilla rounds emitted ~70 raw findings including per-contract hygiene and open questions; this master
carries every Medium-and-above plus the load-bearing Minor/Informational tail. The full raw sets are in the per-round
reports and the working logs kept in the private monorepo.)_

---

## 2. Scope

**In scope (v1.1.0 core, Intuition-chain, at `b52557b`):** `MultiVault`, `MultiVaultCore`, `MultiVaultLib`,
`BondingCurveRegistry`, `BaseCurve`, `LinearCurve`, `AtomWallet`, `AtomWalletFactory`, `AtomWarden`, `TrustBonding`,
`CoreEmissionsController`, `SatelliteEmissionsController` (Intuition-side accounting only), `FeeProxy`, plus
`CoinbaseSmartWalletLib` and the in-scope interfaces where reachable.

**Out of scope (handoff §3):** Trust Swap and swap periphery; the cross-chain bridge / MetaLayer transport leg
(`MetaERC20Dispatcher`, `IMetaLayer`); all Base-chain components (`BaseEmissionsController`); the TVL exit rate-limiter
(deliberately parked); cross-curve counter-stake aggregation (rejected by design); `MultiVaultMigrationMode` (role
revoked post-migration); the progressive-curve family; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow`;
trusted-admin centralization (4-of-8 Safe via two TimelockControllers — an accepted trust assumption); the held-out
`AtomWallet` delegation framework; mixed payable+non-payable multicall batching.

**Material scope caveat — Cluster C absent.** The documented dynamic-fee curve economy (`DynamicFeeFlatPriceCurve` + the
standardized `IBaseCurve` quote/record fee hooks) **does not exist at `b52557b`** — confirmed by all rounds via symbol
search. Cluster C (handoff §5.3, §5.4, §7) was therefore not auditable and must be re-run once that surface merges. See
`INFO-06`.

---

## 3. Severity classification

Impact × Likelihood, using the Diligence house labels. The handoff (§4) severities map onto them: Critical→**Critical**,
High→**Major**, Medium→**Medium**, Low→**Minor**, Informational→**Informational**. Severity is the highest a
**credible** path reaches under the intended deployment and trust model; permissionless exploitability is separated from
trusted-admin misuse. Where rounds disagreed on severity, the disagreement is stated in the finding.

---

## 4. Load-bearing invariants (the properties every round attacked)

1. **Conservation of value** — every credit has a matching debit; no path mints shares without assets or pays out native
   value it never took in; a distributed fee/reward has exactly one home and is never lost or double-counted.
2. **Solvency** — the vault always holds enough backing (TRUST at par) to satisfy every share's redemption; a fee/reward
   contract custodies only redistributed value, never principal.
3. **Curve-ledger mirror** — any secondary (curve/per-tier) ledger stays exactly equal to the vault's share balances
   across every deposit/redeem/retune interleaving.
4. **Flat-price par** — where pricing is 1:1, price never moves; no rounding path lets a user redeem more than
   deposited; no path prices below par.
5. **Storage-layout upgrade-safety** — upgradeable storage is append-only with correct `__gap`; a delegatecalled
   library's storage view is byte-exact with its caller's layout.
6. **No `msg.value` replay** — in any batched/payable multicall, total native value credited across sub-calls is
   `≤ msg.value`, no wei double-spent, transient (EIP-1153) state cleared on **every** exit path including caught
   reverts and re-entrant external calls; nested value-bearing batches rejected.

---

## 5. Consolidated findings (de-duplicated; highest severity first)

Each finding lists the contributing per-round ids so round/model provenance survives the merge. **Rounds reached**
counts how many of the six independent rounds surfaced it — a proxy for signal strength.

---

### MA-01 — Beacon upgrade permanently bricks a legacy `Ownable2Step`-claimed AtomWallet — Major

- **Provenance:** `CYF-E-01` (Cyfrin 10-agent round — net-new). **Rounds reached: 1 of 6.** Not reached by the vanilla
  frontier or single-reviewer checklist rounds.
- **Confidence:** mechanism High / reachability Medium (gated on OQ-E-1).
- **Affected code:** `src/protocol/wallet/AtomWallet.sol` (new `isClaimed` @ slot 1 off 20 — persists; `_claimant` @
  slot 3; `completeClaim` `isClaimed` gate `:299-301`; MultiOwnable-rooted `owner()`/execution) vs. the legacy
  `Ownable2StepUpgradeable` implementation on `main` (owner in the OZ `Ownable` namespaced slot). Delivery vehicle: the
  shared `UpgradeableBeacon` — one `upgradeTo` swaps every wallet at once.
- **Invariant broken:** authorization + fund-custody continuity across an upgrade (§5-analog; handoff §6.E).
- **Mechanism / PoC** (`tests/unit/security/v1.1.0/FrontierRound_WalletUpgrade.t.sol`, against the real new impl): a
  beacon-fronted wallet claimed under the legacy model (`isClaimed == true`, `owner() == claimant`), funded with 5 ETH;
  `beacon.upgradeTo(newAtomWalletImpl)`; post-upgrade `isClaimed` persists true but the MultiOwnable registry is empty
  and `_claimant == 0`, so `owner() == 0` and `isOwnerAddress(claimant) == false`. `claimant.execute(...)` reverts
  `AtomWallet_OnlyOwnerOrEntryPoint`; `completeClaim(claimant)` reverts `AtomWallet_AlreadyClaimed`. No path re-seeds
  the registry — the ETH and any accrued fees are **permanently locked**.
- **Impact:** permanent, irrecoverable custody loss for every legacy-claimed, value-holding AtomWallet at upgrade time.
- **Reachability caveat:** requires ≥1 wallet claimed under `Ownable2Step` holding value at the swap — a live-chain
  census (**OQ-E-1**) the repo cannot answer. Fresh/unclaimed wallets migrate cleanly.
- **Recommendation:** add a legacy-owner migration path — lazily seed the MultiOwnable registry from the legacy
  `Ownable` slot on first `execute`/`transferOwnership` when the registry is empty but `isClaimed` is true, and/or an
  explicit `migrateLegacyOwner()`, and/or a one-shot census + re-seed in the upgrade script; gate the upgrade on the
  on-chain count of claimed legacy wallets.
- **Gate:** resolve before the upgrade — **fix, or prove non-reachable via OQ-E-1.** (Working-tree changes to
  `AtomWallet.sol` + `FrontierRound_WalletUpgrade.t.sol` suggest a fix is underway; unverified here.)

---

### MED-01 — ERC-1271 `isValidSignature` verifies the raw digest — no wallet binding (cross-wallet / cross-chain replay) — Medium

- **Provenance:** `CLD-E-01` (frontier) = `TOB-01` (ToB checklist) = `CYF-E-02`/`CYF-E-F-01` (Cyfrin). **Rounds reached:
  3 of 6** — highest-corroborated finding in the set.
- **Affected code:** `src/protocol/wallet/AtomWallet.sol` — `isValidSignature` verifies the digest without wrapping it
  in a wallet-bound `replaySafeHash` (no `address(this)` / chain-id / domain binding).
- **Mechanism:** the port drops the upstream `replaySafeHash` wrapper and verifies the raw digest, so a signature
  produced for one AtomWallet validates on **every** AtomWallet that shares the signer's key, and across chains.
  Exploitable under owner-unbound EIP-712 integrations (e.g. Permit2 `SignatureTransfer`), which the wallet's own
  NatSpec advertises support for.
- **Impact:** a signature captured for one wallet is replayable against sibling wallets / other chains under an
  owner-unbound integration — cross-account authorization boundary break.
- **Recommendation:** restore an EIP-712 `replaySafeHash` wrapper binding the digest to `address(this)` and the chain id
  before ECDSA / P-256 verification on the ERC-1271 path. Reject high-s while there (see `INFO-01`).
- **Note:** working-tree changes to `AtomWallet.sol` suggest this is being remediated; unverified here.

---

### MED-02 — Zero epoch length is accepted and permanently disables emissions epoch math — Medium

- **Provenance:** `GPT-02` (cross-model, rated Medium) = `CLD-H-01` (frontier, Low) = `TOB-08` (ToB, Minor) = `CYF-H-01`
  (Cyfrin, Low). **Rounds reached: 4 of 6** — most-corroborated; severity taken as the highest credible (Medium) per the
  model in §3.
- **Affected code:** `src/protocol/emissions/CoreEmissionsController.sol:46-69`, `:166-172`, `:192-218`;
  `src/protocol/emissions/SatelliteEmissionsController.sol:60-97`.
- **Mechanism:** `__CoreEmissionsController_init` assigns `emissionsLength` with no non-zero check (`:55-64`); a stored
  zero becomes `_EPOCH_LENGTH`, and once the start time is reached `_calculateTotalEpochsToTimestamp` divides by it
  (`:212-218`) → panic `0x12`. The unvalidated field flows through Satellite init (`:77-83`). No setter exists, so the
  state is unrepairable without an upgrade/redeploy.
- **Impact:** `getCurrentEpoch`, `getEpochAtTimestamp`, and timestamp-emissions all revert at/after start; a satellite
  configured this way cannot run its TrustBonding reward schedule. Irreversible operator-configuration footgun (not
  permissionless).
- **Recommendation:** add `CoreEmissionsController_InvalidEpochLength()` and reject `emissionsLength == 0` in the shared
  core initializer (so satellite init inherits it).
- **Note:** working-tree changes to `CoreEmissionsController.sol` suggest this is being remediated; unverified here.

---

### MED-03 — System-utilization carry-forward asymmetry inflates post-quiescence emissions — Medium

- **Provenance:** `HMN-01` (HumanPages specialist-selection) = `PAS-01` (Pashov parallel-lens). **Rounds reached: 2 of
  6** — both skill rounds, independently.
- **Affected code:** `src/protocol/emissions/TrustBonding.sol` — the system-utilization ratio / carry-forward accounting
  used to throttle per-epoch emissions.
- **Mechanism:** after a quiescent (no-activity) epoch, the self-healing utilization carry-forward resolves the system
  utilization ratio to ~100% for the following epoch, so the utilization-based emission throttle — the headline economic
  mechanism of v1.1.0 TrustBonding — does not damp emissions the way the design intends for the epoch after quiescence.
- **Impact:** post-quiescence emission over-issuance relative to the intended utilization throttle. Bounded per epoch,
  but it is a direct distortion of the emissions economics; both skill rounds rated it Medium.
- **Recommendation:** make the utilization carry symmetric across no-activity gaps so a quiescent epoch does not reset
  the ratio to its maximum; add invariant coverage that a quiescent epoch cannot raise the next epoch's throttled
  emissions above the active-state bound.
- **Regression test:** `tests/unit/security/v1.1.0/MultiAgentRound_SystemUtilizationCarryAsymmetry.t.sol` and
  `ParallelRound_SystemUtilizationRollover.t.sol` (present as new, uncommitted tests on the working tree).

---

### MED-04 — `claimRewards` pause across a full epoch permanently forfeits prior-epoch rewards — Medium (severity-disputed)

- **Provenance:** `TOB-02` (ToB checklist, Medium) vs. `CLD-F-01` (frontier, Informational — "by design"). **Rounds
  reached: 2 of 6, in disagreement.**
- **Affected code:** `src/protocol/emissions/TrustBonding.sol` — `claimRewards` is `whenNotPaused`, and rewards are
  claimable only for the immediately previous epoch.
- **Mechanism:** because a claim is restricted to the previous epoch and `claimRewards` is pause-gated, a pause that
  spans a full epoch boundary makes the prior epoch's rewards permanently unclaimable once the claim window passes — the
  frontier round judged this an intended consequence of the pause design; the checklist round judged the permanent
  forfeiture a Medium user-loss.
- **Impact:** users lose one epoch of accrued rewards if a pause covers their claim window. Whether this is acceptable
  is a design decision the team must ratify or fix.
- **Recommendation:** either document and accept the forfeiture explicitly (and surface it to users), or allow a
  post-pause grace window to claim the epoch(s) that elapsed under pause.

---

### Minor findings (load-bearing subset)

| ID     | Title                                                                                                                                                                                                                                                            | Provenance (rounds)                                   | Cluster |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------- |
| MIN-01 | `transferOwnership` evicts the primary owner, bypassing the `removeOwnerAtIndex` guard                                                                                                                                                                           | `CLD-E-02` = `TOB-09` = `CYF-E-03` (3)                | E       |
| MIN-02 | `feeDenominator == 0` (timelock retune) bricks all create/deposit/redeem (div-by-zero)                                                                                                                                                                           | `CYF-Core-01` (1, net-new)                            | A/B     |
| MIN-03 | AtomWarden per-window claim cap can starve honest claimants at `signatureThreshold == 1`; idle-window `setClaimCapWindow` retune carries a stale count into a fresh window (over-throttle); no `threshold == 0` floor (fail-open under a half-completed upgrade) | `TOB-03` + `CLD-D-01` + `HMN-02` (3)                  | D       |
| MIN-04 | `feeRecipient` settable to the proxy / MultiVault silently strands affiliate fees; no admin rescue path for stranded native                                                                                                                                      | `TOB-06` = `CYF-G-02`; `TOB-12` (2)                   | G       |
| MIN-05 | FeeProxy batch leg proportional-rounding-to-zero reverts the whole batch                                                                                                                                                                                         | `TOB-07` (1)                                          | G       |
| MIN-06 | `setMaxFixedFee` has no absolute ceiling                                                                                                                                                                                                                         | `HMN-04` (1)                                          | G       |
| MIN-07 | `MINTIME ≥ EPOCH_LENGTH` snapshot-safety assumption unenforced on-chain                                                                                                                                                                                          | `TOB-04` = `CYF-F-01` (2)                             | F       |
| MIN-08 | P-256 / WebAuthn (passkey) path is inert unless the RIP-7212 precompile / verifier is on the Intuition chain                                                                                                                                                     | `CYF-E-F-03` + `HMN-11` (2)                           | E       |
| MIN-09 | Initialization-safety family: un-gated / front-runnable `initialize`, unset `multiVault` at init, `redeem` frozen under pause                                                                                                                                    | `CYF-C-02` + `CYF-D-L2` + `CYF-F-02` + `CYF-A-05` (1) | A/C/D/F |

_One-step admin/timelock/privilege rotations (`CYF-D-L1` / `CYF-F-03` / `CYF-G-04`) are noted and treated as
governance-mitigated (4-of-8 Safe via TimelockControllers), consistent with the accepted trust model — not ranked as
separate Minors._

### Informational findings (load-bearing subset)

| ID      | Title                                                                                                                                                                   | Provenance (rounds)                       |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| INFO-01 | ERC-1271 ECDSA path accepts high-s (malleable) signatures                                                                                                               | `CLD-E-03` = `TOB-10` = `HMN-10` (3)      |
| INFO-02 | Fixed-window claim cap admits up to `2 × maxClaimsPerWindow` across a boundary straddle (documented / by design)                                                        | `CLD-D-02` = `TOB-13` = `HMN-09` (3)      |
| INFO-03 | Documented dynamic-fee curve + hook surface (Cluster C) absent from the reviewed commit (scope reconciliation)                                                          | `GPT-01` = `BR-01` (2, +all rounds noted) |
| INFO-04 | NatSpec claims a storage-layout diff gate that does not exist in CI                                                                                                     | `CLD-B-01` (1)                            |
| INFO-05 | `reinitialize(2)` correctness is coupled to the never-executed-on-chain assumption; fresh (non-upgrade) deploy leaves the protocol un-bootstrapped until `reinitialize` | `HMN-07` + `HMN-08` (1)                   |
| INFO-06 | `sweepAccumulatedProtocolFees` is permissionless (benign — routes only to `protocolMultisig`)                                                                           | `HMN-06` (1)                              |
| INFO-07 | Abstract base contract missing `__gap` (future-upgrade slot-shift risk); `bondingCurveConfig.registry` mutable despite "immutable after init" NatSpec                   | `CYF-Core-02` + `CYF-Core-06` (1)         |

---

## 6. Properties checked (negatives — coverage evidence)

Each invariant was attacked and held; the rounds that confirmed it are noted. Negatives are deliverables — they evidence
that the surface was probed, not merely declared clean.

- **Conservation of value** — PASS (frontier, cross-model, Cyfrin, Pashov). Payable-multicall value accounting, deposit/
  redeem ledger updates, and the native-balance conservation invariant held under mismatched-sum, replay, nested-batch,
  reverting-subcall, and callback-re-entry attempts.
- **Solvency / par backing** — PASS (frontier, cross-model, Cyfrin). Flat-price par proved algebraically; no
  redeem-more- than-deposited path; principal never lands in a fee/reward contract.
- **Curve-ledger mirror** — PASS (Cyfrin, frontier). `forge inspect` proves the `MultiVaultLib` mirror byte-exact (slots
  0–37, `__gap[47]`); rounding uniformly `mulDivUp`.
- **Flat-price par** — PASS (all rounds touching Cluster C). 1:1 price never moves; `supply == 0` par rests on the vault
  ghost-share seed (noted as `CYF-C-01`, defended by the seed).
- **Storage-layout upgrade-safety** — PASS for the MultiVault family (byte-exact mirror + upgrade regression), **with
  the AtomWallet exception `MA-01`** — the one place a cross-implementation storage seam is not migration-safe.
- **No `msg.value` replay in `multicallPayable`** — PASS (frontier, cross-model, Cyfrin, Pashov). Batch sum checked
  before dispatch; each sub-call gets only its virtual value; nested batches rejected; transient state cleared on every
  exit including caught reverts.
- **AtomWarden quorum soundness** — PASS (cross-model, frontier, Cyfrin). Replay, duplicate signatures, insufficient
  quorum, malformed segments, expired windows, and cap-retune variants all defended; nonce consumed before the external
  completion call.

---

## 7. Cross-round agreement matrix & remediation status

**Agreement matrix (signal strength):**

| Finding                                     | Frontier | Cross-model | ToB | Cyfrin | HumanPages | Pashov |  Rounds   |
| ------------------------------------------- | :------: | :---------: | :-: | :----: | :--------: | :----: | :-------: |
| MA-01 legacy-wallet beacon brick            |          |             |     |   ●    |            |        |     1     |
| MED-01 ERC-1271 raw-digest replay           |    ●     |             |  ●  |   ●    |            |        |     3     |
| MED-02 zero epoch-length emissions DoS      |    ●     |      ●      |  ●  |   ●    |            |        |     4     |
| MED-03 utilization carry-forward inflation  |          |             |     |        |     ●      |   ●    |     2     |
| MED-04 pause-across-epoch reward forfeiture |   ○\*    |             |  ●  |        |            |        | 2 (disp.) |
| MIN-01 primary-owner eviction               |    ●     |             |  ●  |   ●    |            |        |     3     |
| INFO-01 ERC-1271 high-s malleability        |    ●     |             |  ●  |        |     ●      |        |     3     |
| INFO-02 2×cap boundary straddle (by design) |    ●     |             |  ●  |        |     ●      |        |     3     |

_`○_` = frontier rated MED-04 Informational ("by design"); ToB rated it Medium.

**Remediation status (unverified by this consolidation).** The reviewed working tree carries uncommitted changes to
`src/protocol/wallet/AtomWallet.sol`, `src/interfaces/IAtomWallet.sol`,
`src/protocol/emissions/CoreEmissionsController.sol`, `src/interfaces/ICoreEmissionsController.sol`, and the AtomWallet
/ emissions / TrustBonding-utilization test suites, plus new security tests
`MultiAgentRound_SystemUtilizationCarryAsymmetry.t.sol` and `ParallelRound_SystemUtilizationRollover.t.sol`. This is
consistent with active remediation of `MA-01`/`MED-01` (AtomWallet), `MED-02` (emissions), and `MED-03` (utilization).
**None of these fixes is verified here** — each finding above is reported at its as-found status, and the next step (§8)
is to confirm each fix goes red-when-reverted against its gating test.

---

## 8. Go / no-go gate (what to close before the external audit)

1. **MA-01 (Major)** — land the legacy-owner migration path **or** prove non-reachability via **OQ-E-1** (on-chain
   census of `Ownable2Step`-claimed, value-holding wallets). Do not ship the beacon upgrade until one of these is true.
2. **MED-01** — restore the wallet-bound `replaySafeHash` on the ERC-1271 path (and reject high-s, `INFO-01`).
3. **MED-02** — reject `emissionsLength == 0` in the shared emissions initializer.
4. **MED-03** — make the utilization carry symmetric; gate with the two new invariant tests.
5. **MED-04** — ratify the pause-forfeiture as accepted (documented + surfaced), or add a post-pause claim grace window.
6. Confirm each fix is **mutation-checked** (its gating test goes red when the guard is removed), then move the finding
   to `Fixed` with the test named — this is the found→fixed log the external auditors receive alongside this report.

**Bottom line:** no permissionless Critical/Major theft path was found across six independent rounds; the six core
invariants held. The gating item is the migration-safety Major (`MA-01`), whose live impact hinges on OQ-E-1, followed
by four Mediums that are already being addressed on-branch. Resolve §8.1–§8.5 and re-verify before external hand-off.

---

## 9. Appendix — methodology, provenance, disclaimer

**Rounds merged (independence per handoff §0 — no round seeded another before triage):**

| #   | Report file                                                                    | Method                                             | Model / skill                         | ID prefix |
| --- | ------------------------------------------------------------------------------ | -------------------------------------------------- | ------------------------------------- | --------- |
| 1   | [`vanilla-fable-opus.md`](vanilla-fable-opus.md)                               | Vanilla frontier reasoner, 7 per-cluster reviewers | Opus 4.8 / Fable (no skill)           | `CLD-`    |
| 2   | [`vanilla-gpt-5.6.md`](vanilla-gpt-5.6.md)                                     | Vanilla cross-model reasoner, whole-contract       | GPT-5.6 (no skill)                    | `GPT-`    |
| 3   | [`skill-trail-of-bits-checklist.md`](skill-trail-of-bits-checklist.md)         | 370-item checklist, single reviewer                | `smart-contract-audit` skill (ToB)    | `TOB-`    |
| 4   | [`skill-cyfrin-checklist-multiagent.md`](skill-cyfrin-checklist-multiagent.md) | 370-item checklist, 10 per-contract reviewers      | `smart-contract-audit` skill (Cyfrin) | `CYF-`    |
| 5   | [`skill-humanpages-multiagent.md`](skill-humanpages-multiagent.md)             | Specialist-selection multi-agent + FP-gate + PoC   | HumanPages.ai `audit-contract` skill  | `HMN-`    |
| 6   | [`skill-pashov-parallel.md`](skill-pashov-parallel.md)                         | 12 parallel attacker lenses + four-gate judging    | Pashov `solidity-auditor` skill       | `PAS-`    |

Supporting (not a numbered round): the low-cost **breadth** vanilla pass (`vanilla-breadth-low-cost.findings.md`, in the
private-monorepo working-logs, `BR-*`, one Minor — the Cluster C absence, on an earlier checkout `b768364`). Deferred:
**One Dollar Audit** ($1 autonomous pass) — scaffolding in the private monorepo
(`contracts/core/private/docs/handoffs/oda/`), not yet run live.

- **Method:** each round re-derived from the pre-audit handoff brief (`ai-pseudo-audit-handoff-v1.1.0.md`, kept in the
  private monorepo under `contracts/core/private/docs/handoffs/`) and the source, scoring against the §4 invariants;
  every claim carries a `file:line` and either an exploit path or an evidenced refutation; Highs/Majors carry a Foundry
  PoC. Findings merged here by content, not id.
- **Constraints honored:** local only; `src/` not modified by the review; CI / `.github` untouched; reviewed commit
  `b52557b`; full-length `0x…` addresses; mechanism-only descriptions.
- **Publishing note:** these internal round reports name the model/skill/vendor for the team's own tracking. **If any of
  this is shared outside the team, neutralize model/vendor/person names to the method descriptors** (e.g. "parallel
  specialist-agent round" rather than a tool author's name) and keep only the id-prefix provenance, per the handoff §10.
- **Disclaimer:** this is a **pre-audit artifact** — an internal, first-party AI review run before the external audit.
  It is **not** a formal audit, certification, warranty, or guarantee of safety, and does not replace the external
  engagement.
