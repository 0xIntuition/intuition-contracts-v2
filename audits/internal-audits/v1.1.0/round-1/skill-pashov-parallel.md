# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 6 of 6 — Pashov Solidity Auditor skill (`solidity-auditor`, parallel specialist agents)

> **How this report was produced:** the Pashov `solidity-auditor` skill ran twelve parallel attacker lenses
> (math-precision, access-control, economic-security, execution-trace, invariant, periphery, first-principles,
> asymmetry, boundary, numerical-gap, trust-gap, flow-gap) whole-contract across the in-scope set, with four-gate
> judging and PoC validation. Provenance ID prefix: `PAS-`. This is one of six independent round reports; the
> consolidated, de-duplicated view is [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

|                     |                                                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Artifact type**   | Internal AI pseudo-audit — pre-external-audit. **Not** a formal audit, certification, warranty, or guarantee of safety.                                  |
| **Project**         | `intuition-contracts-v2` public mirror — v1.1.0 core upgrade                                                                                             |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)                                                                           |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                                                         |
| **Toolchain**       | Solidity `0.8.29` · Foundry `1.5.1` · OpenZeppelin upgradeable `5.4.0` (ERC-7201 namespaced) · TransparentUpgradeableProxy                               |
| **Method**          | Parallel specialist-agent round — twelve adversarial attacker lenses applied whole-contract, with four-gate judging, PoC validation, and mutation checks |
| **Round**           | Parallel specialist-agent round (independent of the frontier and cross-model rounds)                                                                     |
| **Date**            | 2026-07-25                                                                                                                                               |

> **Disclaimer.** This document is a pre-audit artifact produced by an automated adversarial review process. Automated
> analysis cannot verify the complete absence of vulnerabilities and no guarantee of security is given. It is intended
> to feed the external audit and the internal found→fixed log, not to replace either. Team security reviews, the
> scheduled external audit, and on-chain monitoring remain required.

---

## 1. Executive summary

This round performed a whole-contract adversarial review of the v1.1.0 in-scope set — every function of every in-scope
contract, not just the delta — under the posture that at least one fund-loss, mint/burn-imbalance, or trust-boundary bug
exists, requiring either a concrete exploit path or an evidenced refutation for each property.

The core value-accounting surface (the extracted `MultiVaultLib` write-path library, the payable multicall value
virtualization, the on-behalf-of creation paths, the `AtomWarden` quorum and new per-window claim cap, the `AtomWallet`
claim transition, and the `FeeProxy` refund ledger) was found to be robust: share/asset conservation holds, the
delegatecall library's storage view is byte-exact with the vault by construction, native-value accounting in
`multicallPayable` admits no wei double-spend, and ETH conservation in `FeeProxy` balances on every route. These are
documented as refutation-backed PASS results in §5.

One **Medium** issue was confirmed with a validated proof of concept: in `TrustBonding`, the **system-level**
utilization ratio that throttles per-epoch emissions is derived from raw per-epoch reads of the MultiVault utilization
slot, which is zero for a fully-quiescent epoch that never triggered the utilization rollover. As a result, the epoch
**following** any quiescent epoch computes an inflated utilization delta and pins the system emission ratio to 100%,
emitting that epoch's rewards at the full un-throttled maximum. The **personal**-side ratio does not share this defect
because it reads a gap-tolerant lookback; the asymmetry is the bug. One related **Minor** robustness observation
(bounded personal-side lookback) is also recorded.

**Cluster C (curve fee-hook dispatch + `DynamicFeeFlatPriceCurve` economy) is not merged at the reviewed commit** and
was therefore not audited; its absence was verified empirically (see §3).

### Headline result — findings by severity

| Critical | Major | Medium | Minor | Informational |
| :------: | :---: | :----: | :---: | :-----------: |
|    0     |   0   |   1    |   1   |       0       |

---

## 2. Scope

### 2.1 In-scope contracts (reviewed at commit `b52557bc5d1e87537e621fc13917240d40044c24`)

| Contract                       | Path (`src/…`)                                        | v1.1.0 surface reviewed                                                                                                                                                                                                               |
| ------------------------------ | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MultiVault`                   | `protocol/MultiVault.sol`                             | Payable multicall + per-leg value virtualization + selector allowlist; on-behalf-of creates; creation attribution; system-utilization rollover; `PAUSER_ROLE` + timelock-gated setters; counter-triple deposit fix; `reinitialize(2)` |
| `MultiVaultCore`               | `protocol/MultiVaultCore.sol`                         | Core storage/config + term/vault primitives                                                                                                                                                                                           |
| `MultiVaultLib`                | `libraries/MultiVaultLib.sol`                         | Extracted delegatecall write-path library; slot-0 storage mirror; create/deposit/redeem/preview bodies; utilization rollover                                                                                                          |
| `BondingCurveRegistry`         | `protocol/curves/BondingCurveRegistry.sol`            | Curve-by-id dispatch                                                                                                                                                                                                                  |
| `BaseCurve`                    | `protocol/curves/BaseCurve.sol`                       | Abstract pricing base + domain/bound checks                                                                                                                                                                                           |
| `LinearCurve`                  | `protocol/curves/LinearCurve.sol`                     | Pro-rata (fee-accretion) pricing                                                                                                                                                                                                      |
| `AtomWallet`                   | `protocol/wallet/AtomWallet.sol`                      | ERC-4337 + P-256/WebAuthn MultiOwnable; `completeClaim`; pre→post-claim `owner()` transition; legacy-owner migration                                                                                                                  |
| `AtomWalletFactory`            | `protocol/wallet/AtomWalletFactory.sol`               | Deterministic CREATE2/beacon deploy                                                                                                                                                                                                   |
| `AtomWarden`                   | `protocol/wallet/AtomWarden.sol`                      | EIP-712 quorum claims; new governable per-window claim cap                                                                                                                                                                            |
| `TrustBonding`                 | `protocol/emissions/TrustBonding.sol`                 | Extended pause gating; epoch reward + utilization accounting                                                                                                                                                                          |
| `CoreEmissionsController`      | `protocol/emissions/CoreEmissionsController.sol`      | Emission-schedule math (cliffs, retention, epoch boundaries)                                                                                                                                                                          |
| `SatelliteEmissionsController` | `protocol/emissions/SatelliteEmissionsController.sol` | Intuition-side TRUST-transfer accounting only                                                                                                                                                                                         |
| `FeeProxy`                     | `periphery/FeeProxy.sol`                              | Fee math, approval gating, push+pull refund ledger, global + per-affiliate pause                                                                                                                                                      |

Also in the reachable surface and reviewed where relevant: `CoinbaseSmartWalletLib` (P-256/WebAuthn primitives folded
into `AtomWallet`) and the `IMultiVault` / `IBaseCurve` / `IAtomWallet` / `IAtomWarden` interfaces. Burn sink /
ghost-share recipient: `BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD`.

### 2.2 Out of scope

Per the round mandate: **Cluster C — `DynamicFeeFlatPriceCurve` and the standardized `IBaseCurve` fee-hook economy — is
not merged at this commit and was not audited** (verified empirically: zero source hits for `DynamicFeeFlatPriceCurve`
and for the `quoteDepositFee`/`quoteRedeemFee`/`recordDeposit`/`recordRedeem`/`onlyMultiVault` hook surface).
Additionally out of scope: the MetaLayer bridge transport leg (`MetaERC20Dispatcher`, `IMetaLayer`),
`BaseEmissionsController` and all Base-chain components, `MultiVaultMigrationMode` (migrator-role, permanently revoked),
the `ProgressiveCurve`/`OffsetProgressiveCurve`/`ProgressiveCurveMathLib` pricing math, the legacy
`Trust`/`TrustToken`/`WrappedTrust`/`VotingEscrow` vendored contracts, the deliberately-parked TVL exit rate-limiter,
cross-curve counter-stake aggregation (rejected on principle), and `AtomWallet.executeFromExecutor` (not merged).
Trusted-admin centralization (4-of-8 Safe through two `TimelockController`s, 3-day parameter / 7-day upgrade delays) is
an accepted trust assumption; only unprivileged-attacker paths are treated as findings.

---

## 3. Severity classification

Severity is assigned as **Impact × Likelihood** under the intended deployment and trust model, using the ConsenSys
Diligence labels. The round's working severities map onto the report labels as: Critical→**Critical**, High→**Major**,
Medium→**Medium**, Low→**Minor**, Informational→**Informational**.

| Label             | Meaning                                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Critical**      | Permissionless/realistically-reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                             |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, or a spec regression that materially affects users/operators.                |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behavior, or a monitoring/integration weakness.                                       |
| **Informational** | Documentation, hygiene, or NatSpec-vs-behavior mismatch.                                                                                                  |

---

## 4. Findings

### 4.1 — [Medium] System utilization ratio inflates to 100% for the epoch following a quiescent epoch

**Provenance:** PAS-01 · Cluster F · Invariant §5.1 (emissions-budget / utilization-throttle integrity)

**Description.** `TrustBonding` throttles each epoch's system emissions by a _system utilization ratio_ that measures
how much the cumulative system utilization changed from one epoch to the next. The ratio is computed from two **raw**
per-epoch reads of the MultiVault utilization slot (`getTotalUtilizationForEpoch`). That slot is populated only when the
utilization rollover runs, and the rollover runs only on the first MultiVault create/deposit/redeem of an epoch. A
fully-quiescent epoch — one with no such activity — therefore leaves its utilization slot at zero. The epoch
**immediately after** a quiescent epoch then computes its "before" baseline from that zero slot, producing a delta equal
to the entire carried cumulative utilization rather than just the epoch's genuine change. That delta almost always
clears the target, so the system ratio is pinned to 100% and the epoch's emissions are released at the full un-throttled
maximum. The personal-side ratio is not affected because it reads a gap-tolerant lookback (`getUserUtilizationInEpoch`);
the system side has no equivalent getter, and this asymmetry is the defect.

**Code.**

`src/protocol/emissions/TrustBonding.sol:648-685` — the system ratio uses raw reads:

```solidity
// _getSystemUtilizationRatio(_epoch)
int256 utilizationBefore = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch - 1); // 0 if _epoch-1 was quiescent
int256 utilizationAfter  = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch);
int256 rawUtilizationDelta = utilizationAfter - utilizationBefore; // inflated by the full cumulative
...
if (utilizationDelta >= utilizationTarget) { return BASIS_POINTS_DIVISOR; } // pinned to 100%
```

Contrast the personal side, `src/protocol/emissions/TrustBonding.sol:610-611`, which is gap-tolerant:

```solidity
int256 userUtilizationBefore = IMultiVault(multiVault).getUserUtilizationInEpoch(_account, _epoch - 1); // lookback
int256 userUtilizationAfter  = IMultiVault(multiVault).getUserUtilizationInEpoch(_account, _epoch);
```

The rollover only writes the _current_ epoch's slot and skips intermediate quiescent epochs —
`src/libraries/MultiVaultLib.sol:1125-1143`:

```solidity
uint256 sourceEpoch = s.lastSystemUtilizationEpoch;                 // jumps over the quiescent gap
int256 sourceUtilization = s.totalUtilization[sourceEpoch];
if (sourceUtilization != 0 && s.totalUtilization[currentEpochLocal] == 0) {
    s.totalUtilization[currentEpochLocal] = sourceUtilization;      // fills currentEpoch only
}
s.lastSystemUtilizationEpoch = currentEpochLocal;
```

**Proof of concept.** With steady-state cumulative utilization `totalUtilization[E-1] = 1000e18`, a quiescent epoch `E`
(`totalUtilization[E] = 0`), resumed activity `totalUtilization[E+1] = 1050e18`, and target
`totalClaimedRewardsForEpoch[E] = 100e18`, `systemUtilizationLowerBound = 5000`:

- Intended (design) ratio for `E+1`: `5000 + (50e18 × 5000) / 100e18 = 7500` (75%).
- Actual ratio returned: `10000` (100%), because `before = totalUtilization[E] = 0` makes `delta = 1050e18 ≥ target`.
- `emissionsForEpoch(E+1)` is consequently emitted at the full `maxEmissions` instead of `0.75 × maxEmissions` — a 33%
  over-emission for that epoch. Both the per-user eligible amount and the `epochBudget` cap in `claimRewards` scale with
  the inflated ratio, so the cap does not contain it.

The proof is codified and passing (against the vulnerable code) at
`tests/unit/security/v1.1.0/ParallelRound_SystemUtilizationRollover.t.sol`:

- `test_PAS01_quiescentEpochInflatesSystemUtilizationRatio` asserts the ratio is 100% and
  `emissionsForEpoch(E+1) == getEmissionsAtEpoch(E+1)` (full max), and that the quiescent epoch itself is floored to the
  lower bound.
- `test_PAS01_carryForwardRemovesInflation` is the fix oracle / mutation guard: backfilling the quiescent epoch's
  cumulative throttles the ratio to the correct 75%, proving the inflation is caused specifically by the missing
  carry-forward.

**Impact.** The utilization-based emission throttle — the headline economic mechanism of v1.1.0 `TrustBonding` — is
bypassed for the epoch following every quiescent epoch, whether the gap arises naturally (low activity) or is
deliberately induced by a party that dominates system utilization to spike its own pro-rata rewards. Excess TRUST is
emitted (up to roughly `(BASIS_POINTS_DIVISOR − systemUtilizationLowerBound)/BASIS_POINTS_DIVISOR` of `maxEmissions` in
the worst case), diluting all TRUST holders. It is bounded by the absolute per-epoch `maxEmissions` schedule cap — there
is no unbounded mint or insolvency — which is why it is rated Medium; triage may reasonably elevate it to Major if the
throttle is treated as load-bearing tokenomics, since the break is systematic, repeatable, and gameable.

**Recommendation.** Give the system side the same gap-tolerance the personal side already has. Options, in rough order
of preference: (a) add a system-side lookback getter analogous to `getUserUtilizationInEpoch` —
`lastSystemUtilizationEpoch` already records the last-active system epoch — and have `_getSystemUtilizationRatio` read
the carried baseline through it; (b) have `_rollover` backfill `totalUtilization` for the skipped quiescent epochs up to
`currentEpoch`; or (c) derive the system `before` baseline from `lastSystemUtilizationEpoch` directly inside the ratio
function. Keep the system and personal paths symmetric so both tolerate multi-epoch quiescence identically.

**Resolution / Status.** Open. Gating regression test:
`tests/unit/security/v1.1.0/ParallelRound_SystemUtilizationRollover.t.sol` (both cases described above).

---

### 4.2 — [Minor] Personal utilization lookback bounded to three tracked epochs

**Provenance:** PAS-02 · Cluster F · Invariant §5.1

**Description.** `getUserUtilizationInEpoch` walks only the three most-recent active epochs recorded in
`userEpochHistory[user]` and reverts `MultiVault_EpochNotTracked` if all three are strictly greater than the requested
epoch. This is the personal-side counterpart to the mechanism behind Finding 4.1, and it is what makes the personal
ratio gap-tolerant; the three-epoch bound is a robustness limit rather than an exploit.

**Code.** `src/libraries/MultiVaultLib.sol:519-541` (`getUserUtilizationInEpoch`), consumed by
`src/protocol/emissions/TrustBonding.sol:610-611`.

**Proof of concept / reachability.** On the live funds path this is not reachable: `claimRewards` only ever queries
`prevEpoch = currentEpoch − 1` (`TrustBonding.sol:396`), and no user can hold three active epochs all greater than
`currentEpoch − 1`. The revert / misattribution therefore does not fire during a real claim, and any harmful state is
self-harm (a user reducing or reverting their own claim), not a profit vector.

**Impact.** No fund loss on the current claim path. Recorded so the constraint is tracked alongside Finding 4.1 in case
a future feature reads utilization for older epochs.

**Recommendation.** Document the three-epoch horizon as an explicit design constraint; if any future getter reads
utilization beyond the tracked window, pair it with the Finding 4.1 system-side fix.

**Resolution / Status.** Open (Minor). No dedicated gating test required at this severity.

---

## 5. Properties checked (what held, and how we tried to break it)

Each line is a property the round attempted to violate and could not; the guard that defended it is cited. These
evidence coverage, not just failures.

**Cluster A — MultiVault payable multicall + value accounting (§5.6): PASS.** `sum(values) == msg.value` and
`data.length == values.length` enforced up front (`MultiVault.sol:580-599`); each leg reads its per-leg
`_effectiveMsgValue()` and every allowlisted forward passes it (never raw `msg.value`); the library reads no `msg.value`
in value paths; reverts re-throw so transient EIP-1153 state is discarded on failure and cleared on success; nested
multicalls rejected and canonical `multicall` forces `_virtualMsgValue = 0`; the six allowlisted legs are `nonReentrant`
and make only staticcall external calls, so no re-entrant leg can claim phantom value.

**Cluster B — MultiVaultLib storage-mirror integrity (§5.5): PASS.** The delegatecall library's `Storage` struct imports
the identical config types and declares fields in the identical order to `MultiVaultCore` + `MultiVault`, anchored at
slot 0; OZ `5.4.0` base contracts are ERC-7201 namespaced (zero sequential slots), so the mirror is byte-exact _by
construction_. v1.1.0 storage additions are append-only at the tail with `__gap[47]`; `reinitialize(2)` pre-seeds
`lastSystemUtilizationEpoch`. Independently cross-confirmed by the existing harness's hardcoded slot numbers
(`totalUtilization` = 30, `userEpochHistory` = 32) matching the struct exactly.

**Cluster C — curve fee-hook dispatch + `DynamicFeeFlatPriceCurve` economy: N/A — not present at `b52557b`, not
audited.** The reviewed curve _pricing_ dispatch held: `BondingCurveRegistry` gates every call on `onlyValidCurveId`;
`LinearCurve` rounds shares/assets down and mint/withdraw up (protocol-favoring); first-depositor inflation is defended
by the `BURN_ADDRESS` min-share seed plus fee-threshold gating of fee socialization.

**Cluster D — AtomWarden quorum + per-window cap: PASS.** Quorum requires ≥ threshold strictly-ascending, distinct,
currently-authorized ECDSA signers over an EIP-712 digest bound to claimant/atom/nonce/domain; per-claimant nonce is
checked before and burned before the external call (CEI); signer revocation and threshold changes take effect at
execution; `signerCount` is kept in sync by role-hook overrides and bounds `setSignatureThreshold`; the per-window cap
uses fixed-window accounting, preserves `claimsInWindow` across a window-length retune (no fresh budget), and disables
cleanly at `0`.

**Cluster E — AtomWallet ERC-4337 / P-256 auth: PASS.** Pre-claim the MultiOwnable registry is empty so signature
validation fails and execution is locked; `completeClaim` is a one-shot `onlyAtomWarden` that rejects the zero address
and the warden itself; the pre→post `owner()` transition is immune to warden rotation post-claim; the permissionless
factory deploy initializes with fixed parameters and a warden-default owner, so front-running the deploy grants no
control.

**Cluster F — TrustBonding emissions + pause: FAIL (see Findings 4.1 / 4.2).** The per-epoch budget cap and double-claim
guard hold, and the pause asymmetry is safe (`withdraw`/`checkpoint` remain callable so a pause never traps locked
TRUST); the failure is the system-utilization-ratio inflation of Finding 4.1.

**Cluster G — FeeProxy refund ledger + approval gating: PASS.** ETH conservation balances on every route
(`in = fee + forwarded + refund = msg.value`); the pull-refund ledger is per-`msg.sender`, CEI-clean, and claimable
while paused; fees are pushed synchronously (no pending value to rug); deposit/creation approval gating prevents routing
value onto a non-approving receiver; `receive()` restricts native inflows to MultiVault/self.

**Cluster H — Emissions controllers (Intuition side): PASS.** The cliff-reduction schedule is monotone-decreasing with
bounded parameters and closed-interval epochs; `SatelliteEmissionsController.transfer` is controller-role +
reentrancy-guarded + balance-checked; unclaimed-emission reclaim only touches epochs past their claim window and is
single-shot per epoch, so it never overlaps live claims.

**Accepted non-findings.** Sub-wei pro-rata distribution dust (`amount % 3`, 0–2 wei per triple op) accretes as
unattributed contract balance without compounding — a known, accepted trade-off. The MINIMUM_LIQUIDITY-style
`BURN_ADDRESS` min-share seed is a safe pattern.

---

## 6. Appendix — methodology, tooling, and disclaimer

**Methodology.** The round applied twelve adversarial specialist lenses — math-precision, access-control,
economic-security, execution-trace, invariant, periphery, first-principles, asymmetry, boundary, numerical-gap,
trust-gap, and flow-gap — whole-contract across the in-scope set, each framed as an attacker seeking a concrete exploit
path or an evidenced refutation. Candidate findings were run through four sequential judging gates (attack-execution,
reachability, trigger, impact); a PASS without an attempted refutation was treated as a failure of the review, not a
pass of the code. The confirmed finding carries a Foundry proof of concept under `tests/unit/security/v1.1.0/`, and each
guard claim was mutation-checked (the PoC's fix-oracle test flips the assertion when the missing carry-forward is
supplied). Scope was pinned by `git rev-parse` and reconciled empirically: the Cluster-C curve fee-hook economy was
confirmed absent at the reviewed commit and excluded.

**Operational note.** This round's twelve specialist lenses were executed sequentially by a single frontier reasoner
after the parallel background fan-out was interrupted by an infrastructure session limit; the coverage, judging gates,
PoC validation, and mutation checks described above were carried out in full. Round and finding provenance (`PAS-…`) is
preserved for the cross-round triage merge.

**Tooling.** Foundry `1.5.1` (`forge test`) for the proof of concept and mutation check; `forge`/source inspection and
storage-layout reasoning against OpenZeppelin upgradeable `5.4.0` (ERC-7201) for the storage-mirror verification;
targeted `grep`/`find` for scope reconciliation and cross-file variant sweeps.

**Pre-audit-artifact disclaimer.** This report is an internal AI pseudo-audit produced before the external audit. It is
not a formal audit, certification, or guarantee of security, and automated analysis cannot prove the absence of
vulnerabilities. Findings remain internal until remediated and are intended to feed the external audit and the internal
found→fixed log alongside the machine-mergeable findings log.
