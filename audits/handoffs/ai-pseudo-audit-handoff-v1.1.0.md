# AI / Agentic Pseudo-Audit Handoff — Intuition v1.1.0 Core Upgrade

**Artifact type:** pre-audit handoff, auditor-facing. This is **not** a formal audit, certification, warranty, or guarantee of safety. It is the brief handed to each AI reviewer in an internal, multi-model pseudo-audit run **before** the external audit.

**Scope basis:** the v1.1.0 core upgrade **as it exists / will exist in the public mirror repo** (`intuition-contracts-v2`, extending PR #153). Public-repo, Intuition-chain contracts only. Anything not in the public mirror is out of scope.

**Target networks:** Intuition Mainnet (chain id `1155`) and Intuition Testnet (chain id `13579`). Intuition-chain only — no Base-chain components.

**Toolchain:** Solidity `0.8.29`, Foundry pinned to `1.5.1`, TransparentUpgradeableProxy (TUP) everywhere (never ERC-1967 directly).

---

## 0. What this is and how to run it

Before the external auditors arrive, we run the whole v1.1.0 in-scope set through several **independent** AI reviewers and archive the results. The point is breadth and adversarial pressure from different reasoners, then a single triage into a **found -> fixed** log we hand to the real auditors.

**Rounds (run each independently — do not seed one round with another round's findings until triage):**

1. **Frontier round — Fable / Opus.** The strongest available reasoner on the full surface. Deepest hypotheses, PoC-backed.
2. **Cross-model round — GPT-5.6.** A different model family over the same scope and the same invariants, to catch what round 1's blind spots miss.
3. **Low-cost breadth round.** A cheaper model doing wide, shallow sweeps (entry-point enumeration, access-control matrix, event/emit gaps, obvious rounding-direction checks) to backstop the expensive rounds cheaply.

Each round re-derives from this document and the source. Independence is the value: a finding that three models reach separately is high-signal; a finding only one reaches is still worth triaging. **Every round assumes at least one real bug exists (see §1).**

**Before you start:** read this whole document, then the source for your assigned cluster (§6), then follow the per-agent protocol in §4. Produce findings in the exact format in §8 so triage is mechanical.

---

## 1. Objective and framing

**This is a WHOLE-contract review of the v1.1.0 in-scope set — every function of every in-scope contract, end to end, not just the delta.** The v1.0.x core was covered by the **April 2026 external audit**, so that history is context — but do **not** scope yourself to the diff. Review each in-scope contract in full: the new v1.1.0 surface (payable-multicall machinery, the write-path library extraction, the standardized curve fee-hook interface plus the fee curve, on-behalf-of creation, governable throttles, extended pause gating) AND the pre-existing functions it sits alongside — the upgrade can silently break a baseline invariant, and a whole-contract read is the cheap AI pass's advantage over the (differential) paid audit. Stay within the in-scope contract set (§2) — this is not "review the whole monorepo" — but within that set, review **everything**.

**Mandate — adopt this posture explicitly:** assume the in-scope set contains **at least one fund-loss, mint/burn-imbalance, or trust-boundary bug**. Your job is to produce a **concrete exploit path** or an **explicit, evidenced reason none exists** on the surface you were assigned. A clean pass is only credible if it shows the refutation attempt.

This is **not** "find any bug." It is directed, hypothesis-driven review: name the exact **invariant**, the exact **function**, and the exact **attacker capability**, then try hard to violate it with a Foundry PoC. A passing "attack reverts / value conserved" test is a useful **negative** worth recording; a failing invariant is a **finding**.

**Rules of engagement.** Authorized, first-party, defensive review of our own contracts. Local only — Foundry harnesses and local forks of our own deployments; nothing against production, no third-party systems. Findings stay internal until remediated, then feed the external audit.

---

## 2. In-scope inventory (public mirror, v1.1.0)

Per the internal audit-readiness summary: **12 implementation contracts + 1 linked library**, ~**5,860 nSLOC** of implementation (plus ~**890 nSLOC** of interfaces); the largest single unit is **`MultiVaultLib`** (~1,080 nSLOC), the extracted write-path library. Cross-checked against `contracts/core/src`. One line each on what changed in v1.1.0 — the baseline behavior is audited, the **change** is what you attack.

| Contract | Path (`contracts/core/src/…`) | v1.1.0 change to attack |
| --- | --- | --- |
| `MultiVault` | `protocol/MultiVault.sol` | Payable multicall (`multicallPayable`) with per-sub-call value virtualization in transient storage + selector allowlist; on-behalf-of creates (`createAtomsFor`/`createTriplesFor`); atom creation attribution (creator + timestamp); system-utilization epoch rollover; `PAUSER_ROLE` + timelock-gated setters; counter-triple deposit fix; `reinitialize(2)`. |
| `MultiVaultCore` | `protocol/MultiVaultCore.sol` | Core storage/config + term/vault primitives the library and vault build on; verify no accounting drift vs the library extraction. |
| `MultiVaultLib` | `libraries/MultiVaultLib.sol` | **Linked library** holding the extracted create/deposit/redeem write-path bodies, invoked by `delegatecall`; storage-slot mirror of `MultiVault`'s layout; curve fee-hook dispatch (quote for netting, record for forwarding). |
| `BondingCurveRegistry` | `protocol/curves/BondingCurveRegistry.sol` | Registry that resolves each vault's curve by id/address; the vault dispatches the standardized hook interface through it. |
| `BaseCurve` | `protocol/curves/BaseCurve.sol` | Abstract base gaining the **standardized `IBaseCurve` fee-hook getters + quote/record hooks with safe reverting/no-op defaults** — a curve without hooks must behave byte-identically to pre-upgrade. |
| `LinearCurve` | `protocol/curves/LinearCurve.sol` | Flat 1:1 pricing; unchanged math, but now the pricing parent of the dynamic-fee curve — confirm the 1:1-at-par surface is untouched. |
| `DynamicFeeFlatPriceCurve` | `protocol/curves/DynamicFeeFlatPriceCurve.sol` | **New.** Flat 1:1 price (inherited verbatim from `LinearCurve`) + the entire per-vault tiered fee economy: piecewise deposit fees, per-tier redistribution via a MasterChef-style accumulator, pull-based `claim`. **Read §7 before auditing it.** |
| `AtomWallet` | `protocol/wallet/AtomWallet.sol` | ERC-4337 + P-256/WebAuthn smart-wallet integration, MultiOwnable, `completeClaim` (`onlyAtomWarden`), `validateUserOp` / `isValidSignature`; the pre-claim -> post-claim `owner()` transition. |
| `AtomWalletFactory` | `protocol/wallet/AtomWalletFactory.sol` | Deterministic (CREATE2/beacon) wallet deployment; deploy-vs-`completeClaim` ordering. |
| `AtomWarden` | `protocol/wallet/AtomWarden.sol` | EIP-712 quorum claims (`claimWithAuthorization`, `ClaimAuthorization` typehash, per-claimant `claimNonces`, `validAfter`/`validUntil`); **new governable per-window claim cap** (`maxClaimsPerWindow`/`claimCapWindow`, fixed-window accounting preserved across retune). |
| `TrustBonding` | `protocol/emissions/TrustBonding.sol` | Emergency **pause gating extended** across every lock-taking entry point (`deposit_for`, `create_lock`, `increase_amount`, `increase_unlock_time`, `increase_amount_and_time`, `withdraw_and_create_lock`, `claimRewards`); `withdraw` and `checkpoint` deliberately **un-gated**; epoch reward + utilization accounting. |
| `CoreEmissionsController` | `protocol/emissions/CoreEmissionsController.sol` | Emission-schedule math (epoch length, per-epoch amount, reduction cliffs/retention) shared by the Intuition-side controllers. |
| `SatelliteEmissionsController` | `protocol/emissions/SatelliteEmissionsController.sol` | Intuition-chain controller of TRUST transfers out of `TrustBonding`. Its cross-chain **dispatch leg** (MetaLayer router / bridge) is a **trust boundary — out of scope** (§3); audit the Intuition-side accounting, not the bridge. |
| `FeeProxy` | `periphery/FeeProxy.sol` | Fee math (`bps + fixed`, bounded by caps), approval gating, push+pull refund ledger (`pendingRefund` / `claimRefund`), global + per-affiliate pause. Recommended scope addition; funds-touching periphery still in-mirror. |

Also in the compiled surface and therefore fair game where reachable: `CoinbaseSmartWalletLib` (`libraries/CoinbaseSmartWalletLib.sol`, the P-256/WebAuthn primitives folded into `AtomWallet`) and the `IMultiVault` / `IBaseCurve` / `IDynamicFeeFlatPriceCurve` / `IAtomWallet` / `IAtomWarden` interfaces.

**Pinned artifacts.** Deploy scripts, the upgrade calldata batch, and the concrete deployed addresses live in the committed deploy manifests / upgrade scripts in the public mirror; reference contracts and roles **by name** and resolve any address from those manifests rather than hardcoding. Where the burn sink appears in reasoning, refer to it as `BURN_ADDRESS` (the ghost-share recipient) and resolve its literal from `MultiVault`.

---

## 3. Explicitly out of scope

Do not file these as findings; if you touch them, note the boundary and move on.

| Out of scope | Why |
| --- | --- |
| **Trust Swap** and any swap periphery | Not in the public core mirror; separate periphery scope. |
| **Bridge router / MetaLayer cross-chain messaging** (`MetaERC20Dispatcher` transport leg, `IMetaLayer` router) | The cross-chain transport is a trust boundary; only the Intuition-side emissions accounting is in scope. |
| **`BaseEmissionsController` and all Base-chain components** | v1.1.0 is Intuition-chain only. The Base-side controller and its mint path deploy elsewhere. |
| **TVL exit circuit breaker / rate limiter** (token-bucket, per-curve + global) | Fully designed and **deliberately parked** — at current TVL the protective value does not justify the added surface. Its absence is a decision, not a gap; do not file "missing rate limit" as a finding. |
| **Unbounded cross-curve counter-stake checks** | **Rejected on principle** — would require an unbounded loop over curves on a hot path. Counter-stake is scoped per curve by design; do not file "counter-stake not aggregated across curves." |
| `MultiVaultMigrationMode` (`protocol/MultiVaultMigrationMode.sol`) | Migration-only, gated by `MIGRATOR_ROLE` which is permanently revoked after migration; trusted one-shot, not part of the steady-state permissionless surface. |
| `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib` | Not part of the v1.1.0 delta. In scope **only** insofar as they must conform to the new `IBaseCurve` hook defaults (safe no-op). Their `UD60x18` pricing math is unchanged and pre-existing — see §7 for why this matters for the *new* curve. |
| Legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow` (`external/`, `legacy/`) | Legacy / vendored (OZ v4–v5 duality); not the v1.1.0 delta. |
| **Trusted-admin centralization** (privileged setters, upgrades) | Privileged actions are gated by a 4-of-8 Safe acting through two `TimelockController`s (parameters 3-day, upgrades 7-day). Centralization here is an **accepted trust assumption**. Note "trusted admin can do X" separately from "an attacker can do X" — the latter is the target. |
| `AtomWallet` delegation framework (`executeFromExecutor`) | Drafted but **held out of merge** and deliberately deferred to the wallet/passkey workstream; not in the v1.1.0 window. |
| Whole-surface `multicallPayable` batching (mixing payable + non-payable legs) | Deliberately deferred; the current wall (value-bearing batches are create/deposit-only) is the intended boundary, documented in NatSpec. Attacking the wall itself is in scope; "please add mixed batching" is not a finding. |

---

## 4. Per-agent independent-verification protocol

Operate **adversarially** and score against invariants, not code quality. This mirrors the funds-touching review discipline and the internal PR-review rigor.

**For every claim you make:**

1. **`file:line`** — cite the exact path and line(s) for every non-`N/A` verdict. A verdict without a citation is not a verdict.
2. **Concrete attacker sequence** — the ordered calls, actors, and values. Prefer a **Foundry PoC outline** (setup -> the exact `vm.prank`/`call{value:}` sequence -> the assertion that fails). For any **High/Critical** surface, attempt the PoC (or fully specify the attacker sequence) *before* accepting a PASS.
3. **Severity** — assign per the model below, using the highest severity a **credible** path reaches under the intended deployment and trust model. Separate permissionless exploitability from trusted-admin misuse.
4. **`PASS` / `FAIL` per checked property** — and the hard rule: **a `PASS` with no attempted refutation is itself a `FAIL`.** If you did not try to break it, you did not check it. Record the refutation attempt even when it fails ("tried X via Y; defended by Z at `file:line`").
5. **Variant sweep** — for any confirmed break, re-check the same bug shape across **single / batch / on-behalf-of / preview / router (FeeProxy) / upgrade-initializer** paths. Bugs rarely live on one path only.

**Severity model** (realistic impact first, then likelihood/constraints):

| Severity | Use when |
| --- | --- |
| **Critical** | Permissionless or realistically reachable path -> direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **High** | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state (e.g. unsafe storage-layout change, exploitable reentrancy, serious accounting break). |
| **Medium** | Bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, admin footgun, or a spec regression that materially affects users/operators. |
| **Low** | Limited impact, weak validation blocked by another guard, confusing behavior, monitoring/integration weakness. |
| **Informational** | Docs, hygiene, NatSpec-vs-behavior mismatch, or a missing non-critical test. |

**End your report with a single line:** `VERDICT: PASS` or `VERDICT: FAIL` for your assigned cluster (FAIL if any High/Critical property fails, or any unresolved Medium on a funds path).

---

## 5. Invariants and properties that must hold

These are the load-bearing properties. For each, the phrasing is deliberately "here is what must hold — now break it." Every one has a corresponding test layer (unit / fuzz / invariant / Medusa stateful / Halmos symbolic / fork / storage-layout); a model that reaches a counterexample the suite misses is the whole point of this exercise.

1. **Conservation of value.** Every credit has a matching debit. No path mints internal shares without receiving assets, or pays out native value it never took in. In the fee curve specifically: a distributed fee **always has a defined home** — an occupied recipient tier, the nearest-occupied fallback, or `protocolAccrued` — and is **never lost or double-counted**. *Break it:* find a sequence where `sum(claimable) + protocolAccrued + dust > sum(fees received)`, or where a fee is credited to two accumulators.
2. **Solvency.** `MultiVault` always holds enough backing (TRUST at par) to satisfy every share's redemption; the `DynamicFeeFlatPriceCurve` custodies **only redistributed fee TRUST** — principal never sits in the curve. *Break it:* make total redeemable exceed custody, or make principal land in the curve.
3. **Curve ledger mirrors vault shares.** For the dynamic-fee curve, a user's tracked `userStake[termId][user]` equals their dynamic-curve share balance in the vault, and `sum(tierStake[termId][*]) == sum over users of userStake == vaultAssets[termId]` (net of the min-share seed). *Break it:* find a deposit/redeem/retune interleaving that desyncs the curve ledger from the vault's shares.
4. **Flat-price par.** On the flat-price curve, share price is 1:1 and never moves; principal always returns at par, so a holder's **maximum loss is the fees they paid** — no rounding path lets a user redeem more than deposited, and no path prices below par. *Break it:* extract net-positive across deposit/redeem cycles, or drive effective price off 1:1.
5. **Storage-layout upgrade-safety.** Upgradeable storage is **append-only** with correct `__gap` accounting; the `MultiVaultLib` delegatecall library's storage view is **byte-exact** with `MultiVault`'s layout (a slot the library writes is the slot the vault reads). Note the one deliberate exception: the never-released tail slots that previously held the special-cased dynamic-fee wiring were reshaped **because `reinitializer(2)` had not executed on-chain** — verify that assumption holds and that the storage-layout regression suite pins every field. *Break it:* find a reordered/retyped/overlapping slot, or a library/vault slot disagreement, that corrupts or mis-attributes funds.
6. **No `msg.value`-replay hazard in `multicallPayable`.** Total native value **credited** across all sub-calls is `<= msg.value`, with no wei double-spent. `_virtualMsgValue` / `_inMulticall` (transient, EIP-1153) are correctly scoped and **cleared on every exit path**, including caught reverts and external calls (atom-wallet factory, curve record hooks) that could re-enter; nested multicalls are rejected; canonical `multicall` forces `_virtualMsgValue = 0` so a payable leg composed inside it cannot claim phantom value. *Break it:* find a nested / revert-recovery / re-entrant sequence that credits the same wei to two deposits, or leaks transient value into a later same-tx call.

---

## 6. Attack surface and directed hypotheses (by cluster)

Assign clusters across rounds; a round may take all of them. For each, the invariant is in §5 — here are the concrete places to push.

**A. `MultiVault` payable multicall + value accounting.** `multicallPayable(bytes[] data, uint256[] values)` requires `sum(values) == msg.value`, dispatches each leg by `delegatecall` (preserving `msg.sender`), and virtualizes per-leg value via `_virtualMsgValue`; `_effectiveMsgValue()` returns `_inMulticall ? _virtualMsgValue : msg.value`. The payable selector allowlist is `{createAtoms, createTriples, createAtomsFor, createTriplesFor, deposit, depositBatch}`. Push on: a leg that re-enters via the curve record hook or factory while `_virtualMsgValue` is set; a caught-revert path that fails to clear transient state; an allowlisted leg that reads `msg.value` directly instead of `_effectiveMsgValue()`; off-by-one between `data` and `values`.

**B. `MultiVaultLib` storage-mirror integrity.** Every slot the delegatecalled library writes/reads must map byte-exactly to `MultiVault`'s `Storage`, including the newer fields (creation attribution, rollover guard, timelock). Target any create/deposit/redeem/preview path where the library writes a slot the vault interprets differently -> silent corruption or mis-attributed funds. Deliver the path + a before/after slot diff.

**C. Curve hook dispatch + `DynamicFeeFlatPriceCurve` economy.** MultiVault resolves the vault's curve from the registry and calls the standardized `IBaseCurve` hooks **generically**: quote hooks (`quoteDepositFee` / `quoteRedeemFee`) net the fee off the user's assets, then record hooks (`recordDeposit` / `recordRedeem`, `onlyMultiVault`, `payable`) forward the fee as native TRUST. **Quote-then-record must be equal-by-construction** (same pure quote) so what is netted equals what is forwarded. A curve without hooks must be byte-identical to pre-upgrade (zero fee, no record call). Push on: quote/record divergence; the piecewise deposit-fee walk across tier bands vs the flat pre-deposit-tier assumption; the sliding-fulcrum distribution kernel (empty tiers, window landing in a gap, tight `sigma` zeroing every weight, the whale-exit nearest-occupied fallback); `setConfig` retune with live positions (index-keyed accumulators must preserve booked/pending earnings); a per-tier override that drives the withdrawal fee toward BPS and underflows `assets - fees`. **Read §7 first.**

**D. `AtomWarden` quorum + per-window cap.** A successful `claimWithAuthorization` must require a genuine >= threshold set of **distinct, currently-authorized** signer keys, with no replay across atoms / chainids / nonces / domain version, and the strictly-ascending-signer-order rule must actually enforce distinctness. The **new** per-window cap (`maxClaimsPerWindow` over `claimCapWindow`, `currentClaimWindowId = block.timestamp / claimCapWindow`) must throttle a compromised signer key and **not** grant fresh budget on a window-length retune (`setClaimCapWindow` preserves the in-window count). Push on: signer-set/threshold change between sign and execute; ERC-1271 contract signers inside the quorum; window-boundary timing; cap disabled (`0`) semantics.

**E. `AtomWallet` ERC-4337 / P-256 auth.** Only a current MultiOwnable owner (or the EntryPoint with a valid owner signature) can `execute` / `executeBatch`; `validateUserOp` / `isValidSignature` must reject non-owners, including malformed/edge WebAuthn-P256 inputs; the pre-claim -> post-claim `owner()` transition and the `completeClaim`-vs-factory-deploy ordering must not be hijackable. Push on: owner-index edge cases, a signature/deploy race granting execution or owner control without a key, permanent DoS that wedges `completeClaim` or locks out legitimate owners.

**F. `TrustBonding` emissions + pause.** `sum` of rewards claimed across users and epochs must be `<= per-epoch emissions budget`; rollover / self-healing utilization carry across no-activity gaps must not inflate claimable or enable double-claim; veTRUST balance-at-block must respect lock decay. Confirm the pause asymmetry is intentional and safe: every lock-taking path is `whenNotPaused`, but `withdraw` and `checkpoint` remain callable while paused (no funds trapped, accounting not stale). Push on: adversarial lock / `deposit_for` / withdraw / claim interleaving across an epoch boundary.

**G. `FeeProxy` refund ledger + approval gating.** ETH conservation: never pay out more than taken in. Push on: double-claim / claim-after-push / cross-user `pendingRefund` attribution; routing a value-moving deposit/create onto a receiver who never approved it; global vs per-affiliate pause interaction; partial-batch reverts when composed with MultiVault.

**H. Emissions controllers (Intuition side).** `CoreEmissionsController` schedule math (cliffs, retention factor, epoch boundaries) and `SatelliteEmissionsController` TRUST-transfer accounting out of `TrustBonding`. Audit the **Intuition-side** state transitions only — the cross-chain dispatch leg is out of scope (§3). Push on: schedule arithmetic at epoch 0 / cliff boundaries / max supply, and access control on the controller/operator roles.

---

## 7. `DynamicFeeFlatPriceCurve` — read before auditing the curve

**Frame it correctly or you will waste the round.** This curve is **reused, already-audited primitives plus simple integer bookkeeping**. It is **not** a stepwise curve, not a novel pricing surface, and it uses **no `UD60x18` / prb-math** anywhere.

- **Pricing is `LinearCurve`, inherited verbatim.** `previewDeposit` / `previewRedeem` / `currentPrice` all come from `LinearCurve` — flat 1:1, never moves. Nothing about the price math is new. The `UD60x18` fixed-point math in this repo lives **only** in `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib`, which are **not** in the v1.1.0 delta (§3). If your analysis is reaching for transcendental/overflow-in-exponentiation arguments, you are auditing the wrong curve.
- **The fee economy is a MasterChef accumulator.** The redistribution is the textbook `accFeePerShare` + `rewardDebt` pattern: a holder's pending is `stake * accFeePerShare[tier] - rewardDebt`, fees are added to a tier's accumulator, and holders **pull** their earnings via `claim`. Depositor/exiter exclusion is exact (the recipient denominator omits the excluded party's stake and their `rewardDebt` is re-based to the post-distribution accumulator). This is O(1) pull-based accounting, not an O(cohort) push.
- **The math is integer arithmetic with fixed-point scaling**, via solady `FixedPointMathLib` (`mulDiv`, `fullMulDiv`, `rpow`) at `1e18` scale (`ACC_PRECISION` / `TIER_PRECISION` / `WAD`). Tier edges are a closed-form geometric series (`edge(k) = width0 * ((1+g)^(k+1) - 1) / g`); the distribution kernel is a **triangular** tent (`max(0, 1 - dist/sigma)`) — pure integer, no transcendental. `setConfig` probes the top edge to reject any schedule that could overflow `rpow`/`fullMulDiv` and brick `tierOf` before any position exists.

So the **real** risk surface here is ordinary accounting-integrity, not exotic math: MasterChef dust/rounding direction, exclusion correctness, the quote-vs-record equality, the retune-with-live-positions path, empty-tier/whale-exit fallbacks routing to the right sink, and native-value custody (`Address.sendValue`, `nonReentrant`, `onlyMultiVault`). Audit **those**. Standard MasterChef sub-wei-per-share dust that accretes as an unattributed contract balance is a **known, accepted** trade-off, not a finding — unless you can show it compounds into a solvency or conservation break.

---

## 8. Structured findings output format

Emit findings in exactly this shape so triage into the found -> fixed log is mechanical. One summary table, then one block per finding, then the verdict line.

**Summary table:**

```
| ID    | Severity | Confidence | Cluster | Title                          | Invariant broken | Status |
| ----- | -------- | ---------- | ------- | ------------------------------ | ---------------- | ------ |
| M1-01 | High     | High       | A       | <short title>                  | §5.6             | Open   |
```

- **ID:** `<round>-<n>` (e.g. `Fable-01`, `GPT-03`, `LC-02`) so provenance survives the merge.
- **Status:** `Open` / `Fixed` / `Mitigated` / `Risk-accepted` / `False-positive` / `Duplicate`. Reviewers open findings as `Open`; the triage owner moves them to `Fixed` (with regression-test evidence) when building the found -> fixed log.
- **Confidence:** `High` (path + impact + repro clear) / `Medium` (one assumption unconfirmed) / `Low` (suspicious pattern; keep out of go/no-go counts until confirmed).

**Per-finding block:**

```
### <ID>: <title>
- Severity / Confidence / Status:
- Cluster + affected code:   <file:line(s)>
- Invariant broken:          <one of §5, or "n/a — new class">
- Attacker capability:       <who, what access, what preconditions — permissionless vs trusted>
- Attacker sequence (PoC outline):
    1. setup: <state, actors, balances>
    2. <ordered calls with vm.prank / call{value:} and values>
    3. assertion that fails: <the invariant violation, with before/after numbers>
- Impact:                    <concrete value at risk / who loses what>
- Refutation attempted:      <what you tried that did NOT work, and why — required even on a PASS>
- Recommendation:            <fix direction>
- Regression test:           <the named test that would gate the fix>
- Variant sweep:             <single / batch / on-behalf / preview / router / upgrade — each: same bug / safe / n/a>
```

**Negatives are deliverables too.** For each assigned property you could not break, record one line: `PASS — <property> — tried <attack> via <path>; defended by <guard> at <file:line>.` These become the "we looked here and it held" evidence the external auditors see.

**Close with:** `VERDICT: PASS` or `VERDICT: FAIL` for the cluster.

### 8a. Final report — package in the Diligence house style

The per-finding blocks above are the **working format** each reviewer emits during the run. The **triaged deliverable** handed to the external auditors is then packaged to read like a peer artifact, not a chat log — mirror the structure of our existing professional reports in `contracts/core/audits/` (`Diligence-Audit-Report-1.pdf`, `Diligence-Audit-Report-2.pdf`, and `CodeArena-audit-report-April-2026.pdf`). Open them and match their layout:

- **Cover / metadata** — title, an explicit "internal AI pseudo-audit" label, date, the exact reviewed **commit hash**, and the models/rounds run.
- **Executive summary** — a few sentences on scope, what was reviewed, and the headline result (counts by severity), for a reader who will not go line by line.
- **Scope** — the in-scope file table with the commit hash (from §2) and the explicit out-of-scope list (from §3).
- **Severity classification** — state the model up front as an Impact × Likelihood matrix, using the **same severity labels the Diligence reports use** (read them to confirm — ConsenSys Diligence typically uses Critical / Major / Medium / Minor, plus Informational). Map the §4 severities onto those labels (Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→Informational).
- **Findings** — one section per finding in the report layout: a numbered title with a severity chip, then **Description**, **Code / examples** (`file:line` + snippet), **Proof of concept** (the attacker sequence), **Recommendation**, and a **Resolution / Status** line (Fixed with the gating test / Acknowledged / Risk-accepted / False-positive). Highest severity first.
- **Properties checked (negatives)** — a short "what held and how we tried to break it" section (from the §8 negatives), so the report evidences coverage, not just failures.
- **Appendix** — methodology (rounds, models, mutation-checks), tooling, and the pre-audit-artifact disclaimer.

Preserve round/model provenance on each finding id even in the packaged report. Same constraints as §10 (no AI attribution, mechanism-only descriptions, full addresses, pre-audit-artifact disclaimer).

---

## 9. Method and workflow

1. **Plan first.** For each assigned property, restate the invariant + the attacker capability + the exact PoC you would write. This keeps the pass hypothesis-driven rather than a scattershot read.
2. **Attempt the PoC.** Add tests under the security suite (`tests/unit/security/v1.1.0/` or the cluster's existing base), matching repo conventions: extend the relevant `BaseTest`; explicit revert selectors (`vm.expectRevert(abi.encodeWithSelector(...))`); before/after conservation assertions; `vm.startPrank`/`stopPrank` blocks; descriptive, non-alarming names. A passing "attack reverts / value conserved" test is a recorded negative.
3. **Mutation-check any fix hypothesis.** If you claim a guard defends a property, confirm the test goes **red** when that guard is removed — a test green in both states proves nothing.
4. **Variant sweep** every confirmed break across the paths in §4.5.
5. **Triage inputs, not conclusions.** Reuse the existing invariant / Medusa / Halmos harnesses for short local smoke campaigns where useful; do not treat their prior green as proof — your job is what they missed.

---

## 10. Constraints and definition of done

**Constraints.**

- Local only. Never touch CI / `.github/**`. Do not move the v1.0.2 baseline fork blocks. Foundry `1.5.1`.
- This document and the pseudo-audit outputs are auditor-facing: **no AI attribution anywhere**, and describe issues **by mechanism** — no internal ticket ids, call references, or person names in anything that ships with the mirror.
- Full 40-hex `0x…` addresses in backticks wherever a literal address is actually needed; never a shortened form. Prefer resolving addresses from the deploy manifests by name over inlining them.
- Treat every output as a **pre-audit artifact** — not a formal audit, certification, or guarantee.

**Definition of done (per round).**

- Every property in §5 and every cluster in §6 assigned to the round has a recorded `PASS`/`FAIL` with a cited refutation attempt (a bare `PASS` is incomplete).
- Every confirmed break has: `file:line`, an attacker sequence / PoC outline, a severity, a variant sweep, and a proposed regression test — in the §8 format.
- Findings are emitted in the §8 structure so they merge into one found -> fixed log without rework.
- Cluster `VERDICT` lines present. Model/round provenance preserved on every finding id.

**After all rounds:** a single triage pass de-duplicates across rounds (dedupe by **content**, not by id), assigns each finding a status, and drives every `Open` High/Critical to `Fixed` with a gating regression test. Package the result **both** as the machine-mergeable **found -> fixed log** and as a **Diligence-style audit report** (§8a) — the two together are what the external auditors receive alongside the go/no-go gate.
