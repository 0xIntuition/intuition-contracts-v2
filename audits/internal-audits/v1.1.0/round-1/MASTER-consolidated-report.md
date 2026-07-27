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

**Remediation is complete; every finding is dispositioned.** Exactly **one** finding required a code fix — `MED-01`
(ERC-1271 wallet/chain binding), landed with regression coverage. `MED-02` was added as defense-in-depth for future
deployments only (live controllers are already initialized to a 14-day epoch). `MA-01` is not applicable against the
deployed system (on-chain census: one AtomWallet, unclaimed). `MED-03` and the remaining Minor/Informational items are
by design, acknowledged, or not applicable. `INFO-03` (the dynamic-fee curve surface absent at this commit) is carried
into **round 2** as scope rather than treated as a defect. Per-finding responses are in the **disposition register** at
the end of §5; the go/no-go gate in §8 reflects the closed state.

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
- **Mechanism:** `_rollover` carries utilization forward with a **snap-forward** (not walk-fill) strategy: it writes
  only the current epoch's slot from `lastSystemUtilizationEpoch`, so a fully-quiescent epoch's `totalUtilization` slot
  stays `0`. `_getSystemUtilizationRatio` reads that slot as its baseline, so the epoch following a quiescent one can
  compute a delta against `0` and round up to the maximum ratio.
- **Impact — measured, bounded.** Holding real activity constant and varying only whether the prior epoch was quiescent,
  the ratio is **100.00% (quiescent baseline) vs 91.66% (carried baseline)**. Worst case is bounded by the configured
  lower bound → 100% (i.e. ≤ ~2× for a **single** epoch), and hard-capped by `maxEpochEmissions` — no unbounded mint, no
  solvency impact. Requires **protocol-wide quiescence** (zero create/deposit/redeem for a full epoch), which is not
  attacker-inducible.
- **Disposition — by design (closed).** The carry-forward defense (`lastSystemUtilizationEpoch` +
  `hasRolledOverSystemUtilization`) is **already implemented in this release** and fixes the substantive bug: pre-fix,
  `_rollover` carried from `currentEpoch - 1`, which is `0` inside a gap, so the carry died across quiescence.
  `MultiVault.reinitialize` pre-seeds `lastSystemUtilizationEpoch` so the first post-upgrade rollover reads a meaningful
  slot. Leaving intermediate epochs at zero is the **deliberate, documented** choice — snap-forward was selected over
  the evaluated-and-rejected walk-back/walk-fill variant — and is asserted as intended behavior in
  `tests/unit/MultiVault/NoActivityEpochDefense.t.sol`. The earlier "make the carry symmetric" recommendation is
  therefore superseded: it describes the rejected design.
- **Regression test:** `tests/unit/MultiVault/NoActivityEpochDefense.t.sol` (multi-epoch quiescence carry-forward,
  including the intermediate-epoch-zero assertions) and `tests/unit/MultiVault/RolloverSystemUtilization.t.sol`.

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

### Disposition register (every finding, with response)

Status vocabulary: **Closed — Fixed** (code change landed + gating test) · **Closed — Acknowledged** (accepted as-is;
rationale recorded) · **Closed — By design** (behavior is the intended design decision) · **Closed — Not applicable**
(precondition does not exist in the deployed system) · **Open** (action still required).

| ID          | Status                        | Response / rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MA-01**   | Closed — Not applicable       | On-chain verification found a single protocol AtomWallet deployment, **unclaimed**, with no Warden-claim or ownership-grant events, so no legacy `Ownable2Step`-claimed wallet exists to brick. Legacy-owner migration logic was deliberately **not** added. Re-verify the census immediately before executing the beacon upgrade.                                                                                                                                                                                          |
| **MED-01**  | **Closed — Fixed**            | ERC-1271 now validates `replaySafeHash(hash, "AtomWallet", "1")`, binding the digest to the wallet **and** chain id. EOA and P-256/WebAuthn vectors updated; covered by the AtomWallet auth/adversarial suites and the v1.0.2 mainnet upgrade regression.                                                                                                                                                                                                                                                                   |
| **MED-02**  | **Closed — Fixed** (n/a live) | The shared emissions initializer now rejects `emissionsLength == 0` with an explicit error. Defense-in-depth only: both deployed controllers are already initialized to a 14-day epoch and the value has no setter, so live proxies are unaffected. Do **not** upgrade a live controller solely to acquire this guard.                                                                                                                                                                                                      |
| **MED-03**  | Closed — By design            | Snap-forward carry-forward is the deliberate, documented design (walk-fill was evaluated and rejected); the substantive carry-loss bug is already fixed in this release and reinitialization pre-seeds the tracking slot. Residual effect measured at 100% vs 91.66%, ≤ ~2× for one epoch, capped by `maxEpochEmissions`, and requires protocol-wide quiescence.                                                                                                                                                            |
| **MED-04**  | Closed — Acknowledged         | Intended consequence of the pause design: pausing is an emergency lever and a pause spanning an epoch boundary forfeits that epoch's rewards. Accepted as a conservative posture. **Ops runbook note:** prefer short pauses; a >1-epoch pause forfeits that epoch's rewards.                                                                                                                                                                                                                                                |
| **MIN-01**  | Closed — By design            | Follows from the wallet claim flow — `transferOwnership` intentionally hands the wallet to the claimant as the single owner.                                                                                                                                                                                                                                                                                                                                                                                                |
| **MIN-02**  | Closed — By design            | `feeDenominator` is a designated governance parameter set through the 4-of-8 Safe + `TimelockController`; validating trusted-governance inputs on-chain is out of the accepted trust model.                                                                                                                                                                                                                                                                                                                                 |
| **MIN-03**  | Closed — Acknowledged         | The per-window claim cap is an intentionally conservative throttle: over-throttling degrades liveness but never authorizes a claim. Arguably the desired posture for a compromised-signer scenario.                                                                                                                                                                                                                                                                                                                         |
| **MIN-04**  | Closed — Acknowledged         | Misconfiguring `feeRecipient` to a non-forwarding address is a trusted-admin configuration error, not an attacker path.                                                                                                                                                                                                                                                                                                                                                                                                     |
| **MIN-05**  | Closed — Not applicable       | Not reachable: `minDeposit` is configured **greater than zero** in MultiVault, so a batch leg cannot round to zero and revert the batch.                                                                                                                                                                                                                                                                                                                                                                                    |
| **MIN-06**  | Closed — Acknowledged         | `setMaxFixedFee` is timelock-gated governance; an absolute on-chain ceiling is not required under the accepted trust model.                                                                                                                                                                                                                                                                                                                                                                                                 |
| **MIN-07**  | Closed — Not applicable       | Epoch length is not changeable after initialization, and the current deployment already satisfies `MINTIME ≥ EPOCH_LENGTH`. No on-chain enforcement needed for the deployed configuration.                                                                                                                                                                                                                                                                                                                                  |
| **MIN-08**  | Closed — By design            | The P-256/WebAuthn path fails **closed** where the RIP-7212 precompile/verifier is unavailable — a capability gate, not a vulnerability.                                                                                                                                                                                                                                                                                                                                                                                    |
| **MIN-09**  | Closed — Acknowledged         | Accepted risks: `initialize` is executed **atomically** in the deploy scripts (no front-run window); `reinitialize` is access-controlled; `redeem` being pause-gated is the intended risk-management posture.                                                                                                                                                                                                                                                                                                               |
| **INFO-01** | Closed — Acknowledged         | High-`s` acceptance remains (the underlying signature-checker library documents that it does not enforce non-malleability), but it is **not exploitable here**: ERC-1271 validation is stateless and no nonce or uniqueness store is keyed on signature bytes, so a malleated variant grants nothing the original does not. UserOp replay is prevented by EntryPoint nonces. The `replaySafeHash` fix additionally closed the cross-wallet dimension.                                                                       |
| **INFO-02** | Closed — By design            | The fixed-window limiter's ≤ `2 × cap` boundary straddle is the documented, intended behavior of a fixed (non-sliding) window.                                                                                                                                                                                                                                                                                                                                                                                              |
| **INFO-03** | Open — deferred to round 2    | Correct scope observation: the dynamic-fee curve surface is absent at the reviewed commit. It is the subject of the **next round**, not a defect in this one.                                                                                                                                                                                                                                                                                                                                                               |
| **INFO-04** | **Closed — Fixed** (docs)     | NatSpec reworded to describe the mechanism that actually exists: the layout is pinned by the storage-layout regression suite executed in CI, plus review during development and the upgrade process — not a separate bespoke "diff gate" job.                                                                                                                                                                                                                                                                               |
| **INFO-05** | Closed — Acknowledged         | Calling `reinitialize` is an explicit step of the upgrade process. **Verified on-chain (chain id `1155`):** the Initializable slot reads `_initialized == 1` on both the MultiVault and TrustBonding proxies, confirming `reinitializer(2)` has not executed — which also validates the §5 storage-reshape assumption. Re-confirm this read immediately before the upgrade.                                                                                                                                                 |
| **INFO-06** | Closed — By design            | `sweepAccumulatedProtocolFees` is intentionally permissionless: it can only route funds to the configured `protocolMultisig`, so an unprivileged caller gains nothing.                                                                                                                                                                                                                                                                                                                                                      |
| **INFO-07** | Closed — By design (+ docs)   | `BaseCurve` deliberately declares exactly one state variable, so inheriting curves own every slot from 1 onward and no gap is required. A gap would only ever have helped if reserved **before** deployment: for curves already live behind proxies the layout is frozen, so inserting base state would shift every child's slots regardless — adding base state is therefore not an option for deployed curves, and any such change means a fresh deployment. NatSpec updated to record the deliberate single-slot layout. |

**Summary:** 0 Open on the deployed system. One code fix was strictly required (**MED-01**); **MED-02** was added as
defense-in-depth for future deployments; **INFO-04 / INFO-07** are documentation corrections; everything else is
acknowledged, by design, or not applicable. **INFO-03** is carried into round 2 as scope, not as a defect.

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

**Remediation status — complete.** `MED-01` landed in `src/protocol/wallet/AtomWallet.sol` /
`src/interfaces/IAtomWallet.sol` (ERC-1271 now binds the digest to the wallet and chain via `replaySafeHash`), with the
EOA and P-256/WebAuthn vectors updated across the AtomWallet auth/adversarial suites and the v1.0.2 mainnet upgrade
regression. `MED-02` landed in `src/protocol/emissions/CoreEmissionsController.sol` /
`src/interfaces/ICoreEmissionsController.sol` as an initialization-time guard (no effect on live proxies). `MA-01` was
closed by on-chain census rather than code — legacy-owner migration logic was deliberately **not** added. `MED-03` is
the pre-existing, deliberate snap-forward design and needed no change. Per-finding responses are in the disposition
register at the end of §5.

---

## 8. Go / no-go gate (what to close before the external audit)

All findings are dispositioned (see the register at the end of §5); **nothing is open against the deployed system.** Two
operational checks remain, both to be run immediately **before executing the upgrade**:

1. **MA-01 re-census (pre-upgrade gate).** `MA-01` is closed by an on-chain fact — one AtomWallet, unclaimed — and the
   legacy-owner migration path was deliberately not built, so that fact is load-bearing rather than backstopped by code.
   **Re-run the census immediately before the beacon upgrade** and confirm no wallet has been claimed under the legacy
   `Ownable2Step` model in the interim.
2. **Reinitializer version check (pre-upgrade gate).** Confirm the Initializable slot still reads `_initialized == 1` on
   the MultiVault proxy before running `reinitialize(2)` (verified at time of writing on chain id `1155`; see
   `INFO-05`).

**Carried into round 2 (not a gate for this one):** the dynamic-fee curve surface (`INFO-03`) does not exist at the
reviewed commit and therefore has **zero audit coverage**. It is the most novel funds-touching surface in the pipeline
and must be the subject of the next round before it ships publicly.

**Bottom line:** no permissionless Critical/Major theft path was found across six independent rounds, and the six core
invariants held. Exactly one finding required a code fix (`MED-01`), which landed with regression coverage; one more
(`MED-02`) was added as forward-looking defense-in-depth. The remaining items are by design, acknowledged, or not
applicable to the deployed system. The residual risk is operational, not code: run the two pre-upgrade checks above.

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
