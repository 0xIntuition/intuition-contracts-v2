# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 3 (Remediation) — MASTER Consolidated Report

> **Artifact type:** Internal AI pseudo-audit — **consolidated master, remediation round**. This is a **pre-audit
> artifact — not a formal audit, certification, warranty, or guarantee of safety.** Rounds 1 and 2 reviewed the upgrade
> surface before external audit. Round 3 is different in kind: the external review has landed, and what is under review
> here is **the remediation code itself** — the fixes written in response to the Consensys Diligence report, plus the
> findings the internal lanes raised against those fixes. Findings stay internal until remediated.

|                          |                                                                                                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **External input**       | Consensys Diligence report on the v1.1.0 core upgrade, delivered 2026-09-15. Six findings (5.1–5.6) plus three mid-audit notes.                                        |
| **Reviewed commits**     | `mihailo/diligence-v110-remediation` (PR #1775): `87fc2965b`, `d9008020b`, `e0c519433`, `ab22597aa`, `d06611b17`, `f101e9fac`, `2a1e29a69`, `fc741c6f3`. Stacked branch `mihailo/diligence-5-3-per-lot-lifo` (PR #1796): `cfa128f51`, `b544f5e90`, then the occupancy-weighting pair `47da073e4`, `28adaa4bb`. |
| **Base**                 | `feat/eng-15020-15021-mirror-naming-backport` — the branch the audited public revision matches, **not** `main`.                                                        |
| **Differential**         | `git diff 2a1e29a69..b159cf6c0 -- contracts/core` for the two curve findings, then `git diff b159cf6c0..28adaa4bb -- contracts/core` for the occupancy-weighting pair; the earlier five commits are each isolated and reviewed on their own diff. |
| **Primary surface**      | `DynamicFeeFlatPriceCurve` (position model and fee routing), `FeeProxy` (call ordering), `MultiVault` (default-curve guard, preview signature).                        |
| **Toolchain**            | Solidity `0.8.29`, Foundry, EVM `cancun`, OpenZeppelin `5.4.0`, solady (`LibBit` newly used); TransparentUpgradeableProxy throughout.                                  |
| **Date**                 | 2026-09-18 (first issue 2026-09-17; extended for the occupancy-weighting pair)                                                                                          |
| **Lanes merged**         | 13 independent review passes across 4 models: 4 isolated rubric lanes (Opus), 6 cold cross-model lanes (GPT-5.6 terra, GPT-5.6 sol ×2, GPT-6 astra ×3), 2 hosted PR reviews (Copilot), 1 pre-existing pass carried from the first five commits. See §8. |
| **Prior round**          | [`../round-2/MASTER-consolidated-report.md`](../round-2/MASTER-consolidated-report.md) — 0 Critical, 5 Major, 8 Medium, 34 of 35 closed.                               |
| **Verification state**   | Full core suite **2146 passed, 0 failed, 9 skipped** (capped fuzz) at the reviewed head. The 21 curve-related suites 422/422. TypeScript mirror of the occupancy pair in progress at the time of writing; the lots mirror was curves 198, protocol 67, CLI 104, SDK 70, playground 164, typecheck green in all seven touched packages. |

---

## 1. Executive summary

Diligence returned **six findings, none Critical**: two Major on the dynamic-fee curve's position model and fee
allocation (5.1, 5.3), one Major on routing call order (5.2), two Medium (5.4, 5.5) and one Minor (5.6). Four are closed
by code, two by reasoned acknowledgement. The two Majors on the curve are the substance of this round, and both were
fixed rather than acknowledged, which was not the starting position: the team's first pass proposed acknowledging 5.1
and 5.3 on the strength of the earlier position-hopping analysis, and the contract stand of 15 September reversed that.

**The remediation is where this round's own findings live.** Thirteen review passes ran against the fixes. They
produced **3 Major, 7 Medium, 20 Minor and 9 Informational** internal findings — every one of them against remediation
code, not against the surface rounds 1 and 2 had already cleared. Three results are worth stating plainly because they
shaped the final design:

- **One real defect was introduced by the 5.1 fix and caught before merge.** Capping each tier's credit at the schedule
  rate leaves a remainder, and the first implementation folded that remainder back into the weighted kernel spread —
  where the very tier that had just been capped was still an eligible recipient, taking a **second** capped credit from
  the same fee and ending above the schedule rate the cap exists to enforce. A thin tier could earn `fF[1+s(1−f)]`
  against a stated ceiling of `fF`. Found by the cold GPT-5.6-sol lane, fixed first by routing every unplaced remainder
  through a dedicated cascade that bypassed the spread (`MA-01`), and made impossible by construction once the cascade
  itself was replaced (below).
- **The cascade was accepted, then replaced.** It paid the nearest prior tier holding its full width, whole, ignoring
  the kernel; in a growing vault that tier is the band a multi-band deposit just filled, so a sweep recovered part of
  its own later bands' fees (`MA-02`, measured at 54% of a band's fee at 60% lower-ladder fill), and the sole holder of
  the nearest full band became the exclusive recipient of every remainder (`MED-02`). Both were accepted on 16
  September. The contract stand of 17 September asked for the two things the cascade could not give — a spread that
  starts from whatever the highest occupied tier is, and shares that scale with the stake each tier holds — and the
  cap-and-cascade was replaced by **occupancy weighting**: each prior tier's kernel weight is multiplied by its fill,
  uncapped, and the pool is divided by the larger of the effective sum and the schedule's plain kernel sum. Per-share
  income at every tier is then one common rate times `w / width`, never above the schedule; a thin tier earns its fill,
  an over-full tier earns proportionally more at the same rate per share (which also closes `MED-04`), and only what no
  stake is there to earn at the schedule rate accrues. `MA-02` and `MED-02` close by code as a consequence.
- **The replacement had a defect of its own, caught by both lanes in the same round.** Single-target credits (the
  deposit spike, an exiting-tier slice) now walk their candidate tiers to exhaustion, and the first occupancy commit
  sent a walk's residue into the spread — whose recipients are a subset of the walk's candidates, every one of which had
  already taken its fill. The same thin tier earned a second helping and sat 5% above schedule at the launch spike, 50%
  at a full spike (`MA-03`). The cold GPT-6-astra lane and the isolated Opus lane found it independently; the residue now
  accrues, pinned by regressions that fail against the previous source and by a fuzz that asserts the per-tier ceiling
  and conservation together. The same Astra pass found an intermediate rounding that could switch the spread into the
  wrong fallback at a permitted configuration (`MED-05`), fixed in the same commit.

**The 5.3 fix is the larger change and returned the cleaner result.** Replacing the stake-weighted average entry tier
with per-tier lots unwound last-in-first-out closes the one-way ratchet Diligence reported, and closes three further
properties as side effects: the position-hop alpha (a top-up can no longer drag existing stake into a higher-earning
band), the delegated-deposit tier move behind 5.4, and — measurably — the split-deposit residual. On the deposit leg one
wallet depositing in N legs is now **exactly** indistinguishable from N wallets, to the wei, across every sampled wallet
count and kernel setting; under the averaged model this was a non-zero plateau of up to roughly 0.7%. That is a partial
answer to 5.5, which remains acknowledged for the redeem leg.

**Three findings are accepted rather than fixed, by explicit owner decision**, each recorded with the alternatives:
the curve's storage layout is not upgrade-compatible with the averaged model (`MED-01`, closed by a fresh-deployment
policy); the redeem-leg cohort fallback pays the exiter's co-holders in a tier-0 vault, which a second wallet can
recapture (`MED-06`, the round-2 Opus lane's HIGH, recorded as a decision the owners should reconfirm knowing that
number); and the upward reroute walk widens the same two-wallet recapture by one tier (`MED-07`). None can cause loss
of principal or insolvency; the exposure in all three is protocol-bucket revenue or a runbook item.

**Gate: clear for external re-review, with one item for the owners.** No open Major or Medium without a recorded
disposition; the round-2 lanes on the occupancy pair are in (§8, lanes 12 and 13), and `MED-06` is the one
disposition that should be reconfirmed by the owners before the reply to Diligence (reconfirmed by the owners on
2026-09-19; the behaviour stands). That reply should also carry
the request for the additional reviewer days the 5.3 exit-path change warrants.

### Findings by severity (internal, against the remediation)

| Severity          | Count  | Open | Closed by code | Accepted / acknowledged |
| ----------------- | ------ | ---- | -------------- | ----------------------- |
| **Critical**      | 0      | 0    | —              | —                       |
| **Major**         | 3      | 0    | 3              | 0                       |
| **Medium**        | 7      | 0    | 4              | 3 (1 for owner reconfirmation) |
| **Minor**         | 20     | 0    | 13             | 7                       |
| **Informational** | 9      | 0    | 3              | 6 (incl. 1 refuted)     |

---

## 2. Scope

**In scope.** The twelve commits listed above, taken as three review units: the first five (FeeProxy ordering,
default-curve guard, three NatSpec items, the preview-signature carry-over) reviewed on their own isolated diffs; the two
curve commits (5.1 cap plus relative floor, 5.3 per-lot LIFO) reviewed together, because the second builds on the first
and the lanes could not rate either in isolation; and the occupancy-weighting pair, reviewed on its own cumulative diff
in two rounds. The TypeScript packages that mirror the curve (`curves` replica,
`protocol` readers and event parsers, `cli` encoders, `sdk` action, `lab` demos and simulator harness) are in scope for
correctness of the mirror, not as a funds path.

**Out of scope.** The Rust indexer realignment, deliberately held until v1.1.0 deploys. The application layer, which
does not read the curve. The protocol package's compiled bytecode artifact, deliberately not regenerated in this round.
Everything rounds 1 and 2 covered and closed.

**What the lanes were given.** The raw diff and the PR description, nothing else — no design rationale, no prior
findings, and in the two later lanes an explicit instruction that a `PASS` without an attempted refutation counts as a
`FAIL`. The Astra lane was additionally told to spend its attention on the curve and to treat the rest as
non-priority. Two lanes were told that a specific earlier disposition had been taken, to stop them re-litigating it and
free them to look for what the previous round had missed; that instruction is recorded per-lane in §8.

---

## 3. Severity classification

Unchanged from round 2: impact × likelihood, Diligence house labels, highest severity a credible path reaches under the
intended deployment and trust model, with permissionless exploitability separated from trusted-configuration
reachability. See [`../round-2/MASTER-consolidated-report.md#3-severity-classification`](../round-2/MASTER-consolidated-report.md).

One classification note specific to a remediation round: a finding that a **fix** introduces is rated on the fixed
code's behaviour, not on the severity of the original finding it addresses. `MA-01` is Major because a thin tier could
exceed the schedule rate, not because 5.1 was Major.

---

## 4. Load-bearing invariants

Invariants 1 to 7 carry unchanged from round 2 (conservation, solvency, curve-ledger mirror, flat-price par,
storage-layout upgrade-safety, no `msg.value` replay, redistribution fidelity). The per-lot model replaces one ledger
with another, so round 3 restates the mirror invariant in its new shape and adds two the lanes were asked to attack:

8. **Lot-ledger consistency** — `userStake[term][account]` is always the sum of that account's lots;
   `tierStake[term][tier]` is always the sum of every account's lot at that tier; and `lotMask` has bit `t` set exactly
   when the lot at `t` is non-empty. The mask is load-bearing beyond bookkeeping: the unwind sizes its scratch arrays
   from its population count, so a mask that disagreed with the lots would fail as an index panic rather than silently.
9. **Schedule-rate ceiling** — no tier's per-share income from a single fee exceeds what a full band would earn from
   the spike plus its kernel share of the pool, `spike / width + pool × w / (width × Σw)`, through **any** combination
   of the prior-tier spike, the exiting-tier slice, the whale-exit reroute, the weighted kernel spread and the redeem-leg
   cohort fallback. This is the invariant `MA-01` and `MA-03` broke, and the one the lanes were pointed at hardest.
10. **Quote-execution agreement** — the fee quoted by the account-aware view for `n` shares equals the fee the record
    hook charges for the same `n` shares, for every lot arrangement. Under a single averaged tier this was one
    multiplication; under lots it is two independent walks that must agree in order and amount.
11. **Common rate within a spread** — within one fulcrum spread, per-share income at tier `t` equals one rate common to
    the whole spread times `w_t / width_t`; occupancy decides how much of the pool a tier takes, never what its holders
    earn per share. Equivalently: a thin tier earns its fill of a full tier's slice, an over-full tier proportionally
    more, and the rate is capped at the schedule's, with the shortfall accruing rather than being redistributed.
12. **Terminal home for every wei** — each wei of a fee ends in exactly one of a tier accumulator, `protocolAccrued`,
    or the documented sub-wei-per-share accumulator dust, and no amount is offered to the same tier twice from one fee.

---

## 5. Part A — external findings and their disposition

Diligence closes each item against an isolated commit or a written acknowledgement. This is the register handed back.

### 5.1 — A minimum-stake position keeps a tier's whole share — Major — **Fixed** (`fc741c6f3`, final form `47da073e4` + `28adaa4bb`)

Fee slices were allocated between tiers by kernel weight alone, with a tier's stake consulted only as a boolean
occupancy test, so a dust position alone in a band could take that band's entire slice. The absolute eligibility floor
was capped by a constant at 1,000 TRUST, which is half of tier 0's width and a negligible fraction of tier 15's.

The first fix capped every credit at `slice × min(1, stake / width)` and cascaded the remainder to the nearest prior
tier holding its full width. The final form, after the stand of 17 September, is **occupancy weighting**: in the kernel
spread each prior tier carries the effective weight `e = w × stake / width`, the kernel weight times its fill with the
fill uncapped, and takes `pool × e / D` with `D = max(Σe, Σw)`, where `Σw` is the plain kernel sum over every prior
tier. Per-share income at any tier is therefore `pool × w / (width × D)`: one common rate times the kernel weight per
unit of width, never above the schedule's, with occupancy deciding only how much of the pool a tier takes. When the
prior ladder as a whole holds at least its widths the pool spreads whole; when it holds less, every tier is paid at the
schedule rate for the stake it has and the shortfall accrues. Empty and excluded prior tiers stay in `Σw`, so their
schedule share accrues rather than being renormalized onto the occupied tiers — renormalizing would let a dust seat in
a gap divert the gap's share. A window that admits no eligible tier falls back to the same rule with unit weights. The
single-target credits — the deposit spike, an exiting-tier slice, its reroute — keep the per-recipient fill cap and
walk their candidate tiers to exhaustion (the spike down the prior tiers; a slice to the tiers above, nearest first,
then below), and what no candidate can take accrues; it never enters the spread. The floor becomes
`minEligibleTierStakeBps`, a fraction of each tier's own width bounded by one full band, and the absolute ceiling
constant is removed. Launch value stays 0, because the weighting does the work the floor was added for.

Net **+148 nSLOC** in the curve against the audited base, interface unchanged. Diligence's own recommendation — weight
a tier's share by the stake it holds — is implemented in the bounded form: the reference is the band width, not the
vault, so the early-cohort premium the ladder exists for is preserved rather than flattened into pro-rata.

### 5.2 — Affiliate paid before the routed MultiVault call — Major — **Fixed** (`87fc2965b`)

All five routing entry points paid the affiliate by `Address.sendValue` **before** calling MultiVault. The recipient is
affiliate-controlled and may be a contract; `FeeProxy`'s `nonReentrant` does not cover MultiVault, so the recipient
could deposit or redeem on MultiVault directly and reprice or re-gate the user's operation before it executed — on a
chain with no public mempool, a guaranteed front-run rather than a race. Affiliate payment now runs after the MultiVault
call on every route, with the excess refund last. Five ordering tests, one per route; the offset-progressive case passes
the pre-call quote as `minShares`, so the previous ordering fails it with a slippage revert rather than merely
differing.

### 5.3 — Sentinel accounts and repositioning — Major — **Fixed** (`cfa128f51`, stacked)

A holder's recorded tier was the stake-weighted average of the bands their deposits landed in, and redemptions never
moved it. The tier ratcheted one way: a small deposit at a high tier dragged the whole position up, and nothing brought
it down. Diligence reported it as sentinel accounts; the CEO and CTO independently asked for the tier to fall on
withdrawal, which under a single average is undefined — removing stake pro-rata from a weighted average leaves the
average unchanged, so the tier can only move if the mechanism decides which band's stake leaves first.

Stake is now held as **lots**, one per holder and tier, in `lotStake`, `lotRewardDebt` and a `lotMask` bitmap whose
highest set bit is the holder's top lot. Deposits land one lot per band traversed, exactly where the stake fell, and
never move earlier lots; a deposit settles only the lot in the band it lands in. Redemptions settle every lot, then draw
from the lots **highest tier first**, charging each portion at its own lot's rate, apportioning the forwarded fee across
the drawn lots by notional fee, paying each lot's exiting-tier slice with the exiter's residual lot there excluded,
running one kernel spread from the vault's current tier with every residual lot of the exiter excluded from every
prior-tier denominator, and finally re-basing every residual lot. The account-aware quote walks the same lots in the
same order.

What it closes beyond the reported finding: the hop reverses itself, because withdrawing a top-up removes the top-up's
lot and leaves the old stake where it was; slicing a withdrawal buys no discount, because every slice pays the top lot's
rate; the tier visibly falls on withdrawal; and a band can no longer hold recorded stake that nobody deposited into
directly. Order is by tier rather than by time deliberately — tiers are monotone with vault growth, so highest-first is
the most recent lot in every case except after a drawdown and refill, and is the fee-relevant order in all of them.

**+109 nSLOC** in the curve, interface unchanged. Runtime 17,997 → 20,658 bytes (20,905 after the occupancy pair,
margin 3,671). Deposits unchanged in gas; curve-level redeems +9% (one lot) to +24% (two lots); settling costs roughly
2.4k gas per lot in steady state, with a one-time 20k first-write per lot that the averaged model paid inside the
deposit instead. The MultiVault-level redeem profile rises again with the occupancy pair (230,656 → 267,733) because a
thin exiting tier's slice now walks every other tier rather than stopping at the first eligible one. Fresh curve
deployment; see `MED-01`.

### 5.4 — A deposit approval moves the receiver's tier — Medium — **Acknowledged with NatSpec** (`e0c519433`)

An approval is a statement of trust; the exposure exists only on explicitly chosen non-default curves and only for
accounts the receiver approved. Documented on the `ApprovalTypes` enum. **The 5.3 fix materially reduces it**: a
delegated deposit now opens or tops up one lot per band traversed rather than moving the receiver's whole position, so
the blast radius is the wei actually deposited, not the position. The NatSpec was updated in the 5.3 commit to describe
the band-by-band landing and the highest-lot-first unwind (`MIN-02`).

### 5.5 — Fee recovery depends on how a position is split — Medium — **Acknowledged**

Redistribution is pro-rata by stake in each receiving tier, so a holder who splits stake across addresses recovers their
own share of a fee one of their addresses paid. No on-chain rule distinguishes two addresses of one holder from two
holders, and MultiVault's own default-curve exit fee has had this property since v1 without even excluding the
redeemer's residual — the curve is strictter. **Partially closed as a side effect of 5.3**: on the deposit leg the
residual is now exactly zero, measured across wallet counts 2 to 10 and under both kernel levers, because one wallet's
lots are precisely the lots N wallets would hold and the deposit leg applies no per-account exclusion. What remains is
the redeem leg, where a second wallet the exiter controls is an ordinary cohort member — now bounded per share by the
5.1 cap.

### 5.6 — A hook-bearing curve can be set as the default curve — Minor — **Fixed** (`d9008020b`)

A private view helper resolves `defaultCurveId` through the supplied registry and reverts on an unregistered id or on a
curve reporting either fee hook. Applied on **both** write paths: `setBondingCurveConfig`, which Diligence recommended,
and `initialize`, which it did not — a fresh deployment with a hook-bearing default would create positions that can
never redeem, so the initializer applies the same check. Placed after core validation so the existing errors keep
precedence. This guard also closes `MED-03` below.

### Mid-audit notes

| Note                                                     | Disposition                                                                                                                     |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Counter-triple init guard is near-unreachable             | **Documented** (`ab22597aa`). NatSpec explains why condition (c) cannot hold under a fixed default curve and when the guard is live. |
| `previewRedeem` is account-agnostic                       | **Already documented.** The interface NatSpec states the address-zero quote and points at the account-aware view; updated for lots. |
| `previewTripleCreate` omits the atom-deposit fraction     | **Fixed** (`f101e9fac`). Code4rena carry-over. Signature now takes the three atom ids, so chargeability is evaluated against the atoms and the quote matches what creation charges. The old selector is replaced rather than overloaded. |

---

## 6. Part B — internal findings against the remediation

Each finding lists the lane that raised it; §8 maps lanes to models and prompts.

### MA-01 — A capped remainder folded back into the weighted spread lets the same thin tier take a second credit from one fee — Major — **Fixed before merge**

**Lane:** cold GPT-5.6-sol, round 1. **Status:** fixed in `cfa128f51`; confirmed closed by the same lane in round 2 and
by two subsequent lanes. Superseded by `47da073e4`: the cap and the cascade are gone, and under occupancy weighting the
spread is the only credit a tier receives from the pool, so a second credit from the same pool has no path.

The 5.1 cap leaves a remainder whenever a recipient tier holds less than its width. The first implementation folded that
remainder — from the deposit spike, from an exiting-tier slice, from a reroute, and from any slice with no eligible
cohort — back into the fulcrum pool. The pool is then spread by kernel weight over the eligible prior tiers, **which
still include the tier that was just capped**. That tier therefore received its fill of the slice and then a share of
its own unpaid remainder. For a sole eligible thin tier with fill `f`, fee `F` and spike share `s`, it collects
`fF[1 + s(1 − f)]` against the documented ceiling of `fF`. The TypeScript replica reproduced the same behaviour, so the
mirror was faithful to a wrong rule.

**Fix.** `_payFulcrumTiers` takes an explicit `overflowIn` argument. Every unplaced amount now bypasses the weighted
spread and goes to the cascade step, which pays only a prior tier holding at least its **full** width — a tier that
cannot be pushed above the schedule rate by construction — and otherwise accrues to the protocol. No path returns a
remainder to the spread. Two regression tests pin it: a half-filled tier earns exactly half of a full tier's
entitlement from a spiked deposit, and a reroute's remainder passes over a thin tier to reach the nearest full one.

### MA-02 — A multi-band deposit recovers part of its own fee through the band it filled — Major — **Closed by code** (`47da073e4`; accepted on 16 September, superseded)

**Lane:** isolated Opus rubric lane, round 2 (new relative to its round 1). **Status:** accepted by owner decision on
16 September; closed by code on 17 September when the cascade was replaced. Under occupancy weighting a sweep's earlier
band is a prior tier like any other: it earns exactly its schedule share of the next band's fee and no more, pinned by
the re-derived sweep test (alice, carol and bob each earn their kernel share of the over-full tier's spread; the thin
tier's shortfall accrues). The record below is kept as the history of the decision.

The band walk sets an intermediate band's chunk to exactly the room remaining to that band's edge, so after
`_applyDepositBand` that tier provably holds at least its full width. The next band's fee is distributed with the
tier below it as the nearest candidate, and `_cascadeOverflow` tests that candidate first — so the remainder thin lower
tiers could not absorb flows back to the depositor's own just-filled band. The deposit leg applies no per-account
exclusion, so nothing subtracts the depositor. Quantified at the launch schedule with tiers 0–4 at 60% fill, recovery of
a band's fee rises from 23% (pre-cap) to 54%, and approaches 100% as the lower ladder thins. The credit is claimable in
the same transaction.

**Why accepted rather than fixed.** Three alternatives were evaluated and each is worse or equivalent. Excluding the
depositor on the deposit leg reintroduces the split-wallet edge that 5.3 had just driven to exactly zero, since the same
recovery is then available through a second address. Spreading the remainder across full tiers by kernel weight changes
nothing for a sweep, because in a sweep the depositor's own bands are the only full prior tiers. Sending the remainder
to the protocol restores pre-cap sweep economics but introduces a protocol sink in exactly the thin-ladder states where
holders most need the fee stream. The accepted reading is that the cascade is a floating extension of the prior-tier
spike, which the market simulation had already sized as a good at 10%, and that it rewards the most recent full cohort —
the cohort closest to breaking even, whose continued deposits the mechanism wants. It is wallet-neutral, bounded by the
fee, and identical to what N separate depositors landing the same bands would collect.

**Residual.** The magnitude is configuration-dependent and grows as the lower ladder thins. A simulation cell after
deployment sizes it under real flows; if it proves material, the protocol destination is a one-line change.

### MED-01 — The lot mappings reuse the retired averaged-model storage slots — Medium — **Accepted by deployment policy**

**Lane:** isolated Opus rubric lane, round 1. **Status:** accepted; re-audited and confirmed sound in round 2 of the
same lane.

`lotStake`, `lotRewardDebt` and `lotMask` take the slots that held `userTier`, `userAvgTier` and `rewardDebt`. The first
two gain a hash level, so old data is orphaned and reads as zero — harmless. `lotMask` has **identical key and value
types** to the old `rewardDebt` and resolves to precisely its slot. Meanwhile `userStake` and `tierStake` are preserved
verbatim. An in-place upgrade would therefore leave every existing position with `userStake > 0` and no lots, and every
redemption would revert — permanently, with principal stranded.

**Why accepted.** The curve ships as a **fresh proxy** and is never installed over a proxy running the averaged model.
Lots cannot be reconstructed from an average, so no migration exists even in principle; the testnet instance is
redeployed rather than upgraded. Placeholder slots and reinitializer scaffolding were considered and explicitly
rejected: that ceremony is correct for contracts upgraded in place and is misleading clutter on one that is not. The
review lane confirmed in round 2 that no code path makes the fresh-deploy assumption itself unsafe — the initializer is
gated, the constructor disables initializers, and every lot mapping is written before it is read.

**Operational consequence, and the one action item:** whoever holds the curve's ProxyAdmin must not point an existing
averaged-model proxy at this implementation. This is a deployment-runbook item, not a code item.

### MED-02 — The cascade is winner-takes-all and ignores the kernel weights — Medium — **Closed by code** (`47da073e4`; accepted on 16 September, superseded)

**Lane:** isolated Opus rubric lane, round 1. **Status:** the cascade no longer exists. Every remainder of the spread
is now either absorbed by over-full tiers at the schedule rate, through the same weights the kernel configures, or
accrues. The record below is kept as the history of the decision.

`_cascadeOverflow` scans prior tiers from the frontier downward and hands the remainder **whole** to the first eligible
tier holding its full width, reading the stake array and ignoring the weight array. Under the cap this is not a
degenerate fallback — it is the main path whenever the vault has shrunk below its holders' lots, and the round's own
tests show it carrying the majority of a fee in those states. An actor who is the sole holder of a full band nearest the
frontier becomes the exclusive recipient of every overflow, regardless of the kernel configuration whose purpose is to
slide the earning window up the ladder.

**Why accepted.** A kernel-weighted split over full tiers was designed and then dropped: it does not change the
sweep case (`MA-02`), and the concentration it removes is the same concentration the prior-tier spike deliberately
creates. The per-share ceiling is not violated — a full tier receiving `remaining` earns at most `remaining / width` —
so this is allocation policy rather than a rate breach, and the policy chosen is "pay the most recent full cohort".

### MED-03 — The per-lot quote is nonlinear in an asset-denominated input walked against a share-denominated ledger — Medium — **Closed by the 5.6 guard**

**Lane:** isolated Opus rubric lane, round 2.

`_lotRedeemFee` consumes lot balances (shares) against `assetsBeforeFees`, while the record hook unwinds shares. At par
these are the same number. Were this curve ever made the **default** curve, par could break, the quote would exhaust
high-rate lots early and price the tail at the vault's tier, and the fee charged would disagree with the lots actually
drawn — in both direction and composition. The old single-rate quote degraded gracefully under the same drift; this one
does not.

**Why closed rather than accepted.** The premise is unreachable: the 5.6 fix in this same remediation makes MultiVault
reject a hook-bearing curve as the default on both `initialize` and `setBondingCurveConfig`, and this curve reports both
hooks. The lane rated it Medium because it rests on a comment; it now rests on a guard with tests. The stateful
invariant asserting exact 1:1 for the wired configuration remains.

### MED-04 — A refilled tier can hold more than its width and dilute its holders — Medium — **Fixed** (`47da073e4`; acknowledged on 16 September, superseded)

**Source:** raised by the CEO at the contract sync of 16 September, confirmed by analysis rather than by a lane.
**Status:** fixed by the occupancy weighting. An over-full tier's effective weight scales up with its fill, uncapped, so
its holders earn per share exactly the common rate a full band's holders earn; the dilution existed only because the
kernel gave a tier its slice by distance alone. The rank-ordered and gross-ladder redesigns below are no longer needed
for this finding and are carried as research only. The record below is kept as the history of the analysis.

Tier widths are defined on the vault's total, but occupancy is history. When the vault falls below a tier that still
holds lots and later refills it, that tier gains up to one more width of new lots on top of the old ones. The kernel
gives a tier its slice by distance, not by how much stake sits there, so the holders of an over-full tier earn per share
below the schedule. It is the mirror of 5.1 — which the cap addresses on the thin side and nothing addresses on the
full side.

**Bounds.** It cannot cause loss or insolvency. It cannot be forced on a cohort cheaply: pulling the vault below a tier
and refilling it costs real entry and exit fees, part of which flow to the tier being diluted. In an organically growing
vault it does not occur. Each drain-and-refill cycle adds at most one width, but the effect compounds across repeated
cycles, and the levers are the kernel spread and the cascade rather than a structural rule.

**Why lots make it smaller.** Under the averaged model over-fill could be manufactured from above, because a top-up
moved a whole position into a band it never entered. Under lots only stake that actually lands in a band counts, and the
position-hop alpha that exploited the averaging is gone. What remains is the honest case of a fallen vault refilling.

**Alternatives considered, all fundamental redesigns**, recorded so they are not re-raised without new information:
deposits landing in the emptiest tier (retracted by its author at the sync — it parks new money outside the earning
window, so the depositor can earn nothing); rank-ordered positions with tiers that stretch and squeeze as others exit
(the only design that closes over-fill, thin tiers, sentinels, hops and splits with one rule, but it needs order-statistic
structures over positions, raises per-deposit cost from `O(tiers)` to `O(window × log n)`, makes a holder's tier move on
strangers' actions, and is a contract written from scratch with a fresh audit); and a ladder keyed to gross cumulative
deposits that never falls (never over-fills, but newcomers after a drawdown pay a high tier's entry rate into a small
vault). None fits a launch before the end of October. The rank-ordered design is carried as post-launch research for a
new curve id.

### MA-03 — A single-target walk's residue re-entered the spread and paid the same thin tiers a second time — Major — **Fixed before merge** (`28adaa4bb`)

**Lanes:** cold GPT-6-astra (high) and isolated Opus rubric lane, both round 1 on `47da073e4`, independently.
**Status:** fixed; regressions mutation-checked.

Under occupancy weighting the single-target credits walk their candidates to exhaustion: the deposit spike down the
prior tiers, an exiting-tier slice to the tiers above then below, each taking up to its fill. The first commit added
whatever the walk could not place to the fulcrum pool. The spread's recipients are the prior tiers, a subset of the
walk's candidates, and every one of them had just taken its fill of the same amount — so the spread offered it to them
again. With a half-filled tier 0 as the only prior tier, a 100% spike paid it `0.5F` by the walk and another `0.25F`
through the spread against a ceiling of `0.5F`; at the launch spike of 10% the same tier earned about `0.525F` against
`0.5F`. The redeem leg had the same shape through the reroute's leftover. The existing regression named for the
property was vacuous, because its prior tier was full and the residue branch never ran.

**Fix.** A walk's residue accrues to the protocol and never enters the spread, on both legs; the redeem leg's
`leftover` is kept apart from the fulcrum sum for that reason. Four tests pin it: the deposit-side residue case with
exact numbers (`0.40 / 0.225 / 0.375` of the fee to tier 1, tier 0 and the protocol), the redeem-side leftover case,
the edge-of-window case below, and a fuzz over random fills of three prior tiers and a random spike that asserts, for
every prior tier, per-share income at most a full band's spike plus kernel share, and conservation to within floor
dust. All four fail against `47da073e4`'s curve source and pass against `28adaa4bb`.

### MED-05 — Effective weights rounded to zero switched the spread into the fill-only fallback — Medium — **Fixed before merge** (`28adaa4bb`)

**Lane:** cold GPT-6-astra (high), round 1 on `47da073e4`.

The effective weight was computed at the kernel's precision, `w × stake / width` with `w` in 1e18. A tier at the very
edge of the window carries a kernel weight of a single unit (`sigma = 1e18 + 1` with the peak on the nearest tier is a
permitted configuration), and at any fill below one its effective weight floored to zero. The fallback was keyed on the
effective sum being zero, so the spread switched to the fill-only split, which pays tiers **outside** the window: with a
full tier 0 outside and a half-full tier 1 inside, tier 0 took half the pool and tier 1 a quarter, where the schedule
gives tier 1 half and tier 0 nothing.

**Fix.** Weights are carried at 1e36 (kernel weight times a 1e18 fill scale), so an in-window tier keeps a non-zero
weight down to a fill of one part in 1e18, and the fallback keys on the window admitting no eligible tier rather than on
the sum. A window that holds an eligible tier is never replaced, even when every effective weight in it is zero; such
dust then accrues rather than pulling outside tiers in. Regression with the boundary configuration.

### MED-06 — The redeem-leg cohort fallback pays the exiter's own lot tier at the full-band rate, and a second wallet can recapture it — Medium by decision (rated HIGH by the lane) — **Accepted, for owner reconfirmation**

**Lane:** isolated Opus rubric lane, round 2 on the occupancy pair. **Status:** the rule was an explicit owner
decision on 17 September ("cases 2 and 4" of the accrual map); recorded here at the lane's severity with the
defence, and flagged to the owners for a conscious yes.

When the fulcrum spread of a redeem can place nothing, because the vault sits in tier 0 or every prior tier is
empty, the fulcrum share goes to the cohorts of the tiers the redeem drew from, capped at their fill, and only then
to the protocol. Before the occupancy pair that share accrued. The lane's objection: the kernel schedule for those
tiers is zero (there is no prior tier), so any payment breaches the schedule ceiling; and the cohort of the exiter's
own tier is excluded only by address, so a second wallet the exiter controls collects it. In a vault below the first
edge (2,000 TRUST at launch), the recapturable fraction of a redeem fee through a second wallet rises from the 25%
exiting-tier slice to 100%. No user principal is at risk and the second wallet cannot profit: the fee was paid in
full and part of it comes back, less MultiVault's own fees. The loss is protocol-bucket revenue in small vaults.

**Defence, and why it is recorded as a decision rather than a defect.** The exiting-tier slice already pays the
same cohort by the same rule, and `redeemToFulcrumTiersBps = 0` is a permitted configuration under which 100% of
every redeem fee goes to that cohort everywhere, not only in tier-0 vaults; the fallback makes a tier-0 vault behave
as that configuration does, on the reasoning that the co-holders beside the exiter are the only cohort there is. The
two-wallet recapture is finding 5.5, acknowledged, in the form it has always had. Per-share income at the cohort's
tier from the whole fee is at most the full-band rate `fee / width` (both halves capped at fill), which is the bound
the new redeem-leg fuzz asserts. **Alternatives if the owners prefer the protocol to keep it:** restore accrual for
the fulcrum share when the spread places nothing (a two-line change), or cap the fallback at the exiting-tier
slice's own rate. Pinned by two regressions (vault in tier 0; every prior tier empty) with exact numbers.

### MED-07 — The reroute walk sends thin-cohort and sub-floor remainders upward first, widening adjacent-tier recapture across two wallets — Medium — **Accepted as finding 5.5; guide corrected**

**Lane:** isolated Opus rubric lane, round 2 on the occupancy pair.

Before the pair, a partly capped exiting-tier remainder and a sub-floor cohort's slice went to the cascade, which
paid prior full tiers only; the tiers above were reached only when the cohort was empty. Now every such remainder
walks the tiers above first, then below, each capped. A second wallet parked one tier above the exiter collects its
pro-rata share of it. The guide claimed the redirection was "never a recapture"; with a second address it is the
split-position recovery of 5.5, bounded by the exiter's own fee, and the guide now says so. The walk order itself is
the stand's request (the stayer who sat above the whale earns it) and stays.

### Minor findings

| ID     | Finding                                                                                                        | Lane                 | Disposition |
| ------ | -------------------------------------------------------------------------------------------------------------- | -------------------- | ----------- |
| MIN-01 | The market-simulation harness still read the removed `userTier` getter, so it could not encode against the new curve | GPT-5.6-sol R1       | **Fixed** — reads `userLots` |
| MIN-02 | `ApprovalTypes` NatSpec described a delegated deposit as moving one tier, not as landing a lot per band          | GPT-5.6-sol R1/R2    | **Fixed** |
| MIN-03 | The call-flow guide and the generated call graphs still described the averaged model and removed helpers        | GPT-5.6-sol R1/R2    | **Fixed** — guide rewritten, graphs regenerated |
| MIN-04 | The deploy script's schedule prose described the old 13-tier ladder while the config ships 16 tiers             | GPT-5.6-sol R2       | **Fixed** |
| MIN-05 | The pre-audit design overview still described one stake-weighted average entry tier and the removed floor ceiling | GPT-5.6-sol R2       | **Fixed** |
| MIN-06 | Interface NatSpec still said capped remainders rejoin the kernel pool after `MA-01` changed the route           | GPT-5.6-sol R2       | **Fixed** |
| MIN-07 | The guide's worked redemption example priced 5,000 shares at one tier; under lots it spans two, ≈247.7 TRUST not 175 | GPT-6-astra          | **Fixed** (`b544f5e90`) |
| MIN-08 | Both vendored ABI fragments still advertised the removed `MAX_MIN_ELIGIBLE_TIER_STAKE` getter                   | Copilot (PR #1775)   | **Fixed** — both regenerated from the compiler output and byte-identical to each other |
| MIN-09 | The demo's published gap-list doc named the removed `minEligibleTierStake` config field                          | Copilot (PR #1775)   | **Fixed** — renamed with units stated |
| MIN-10 | The simulator's report templates named the removed lever                                                        | Copilot (PR #1775)   | **Fixed** — templates only; dated report directories left as historical record |
| MIN-11 | The demo rendered an empty string instead of a placeholder for a holder with zero lots                          | Copilot (PR #1796)   | **Fixed** — explicit length check |
| MIN-12 | `RedeemFeeRerouted` now emits the **placed** amount rather than the full slice, with an unchanged signature      | Opus R1              | **Acknowledged** — silent semantic change no ABI check catches; the held indexer realignment must pick it up |
| MIN-13 | `_creditCapped` books a slice as placed even when its per-share increment floors to zero                        | Opus R2              | **Acknowledged** — wei-scale, same class as the documented accumulator dust; now stated in NatSpec |
| MIN-14 | The per-lot fee remainder lands on the **lowest** drawn lot, where the deposit replay puts its remainder on the highest | Opus R2              | **Acknowledged** — bounded by the drawn-lot count in wei except when total weight is zero |
| MIN-15 | The tests named for the schedule ceiling were vacuous: their prior tiers were full, so the residue branch never ran, and the neutrality fuzz seeds every tier exactly to its edge | Opus R1 (occupancy) | **Fixed** — residue regressions on both legs plus a per-tier ceiling and conservation fuzz over random fills; mutation-checked |
| MIN-16 | The call-flow guide's fallbacks table and the `setConfig` commentary still described the deleted nearest-tier whole-pool award; the generated call graphs still listed the deleted cascade helpers | GPT-6-astra R1 (occupancy) | **Fixed** — table row, commentary and graphs regenerated |
| MIN-17 | The exact-mode dust of a spread is booked whole to the last tier credited, uncapped, and per-distribution accumulator dust rises with the number of capped credits a walk makes | Opus R1 (occupancy) | **Acknowledged** — bounded by one wei per credited tier; the walk's dust is the same class as `MIN-13` |
| MIN-18 | `RedeemFeeRerouted` now fires once per tier the walk pays, and can fire with a zero amount on a dust tier, with an unchanged signature | Opus R1 (occupancy) | **Acknowledged** — same class as `MIN-12`; the held indexer realignment absorbs it |
| MIN-19 | Worst-case redeem gas grows with the tier count per lot drawn when the ladder is thin everywhere, where the earlier search stopped at the first eligible tier | Opus R1 (occupancy) | **Measured** — profile redeem 230,656 → 267,733 at the launch ladder, within ceiling; a redeemer can split the exit; confirm before any ladder extension |
| MIN-20 | A window that holds an eligible tier whose effective weight floors to zero (a seat below one part in 1e18 of its width) suppresses the fill-only fallback, so the whole pool accrues although full tiers exist outside the window | Opus R2 (occupancy) | **By design** — the alternative pulls tiers outside the window into the split; reachable only with wei-scale seats, no gain to anyone; stated in NatSpec |

### Informational findings

| ID     | Finding                                                                                                     | Lane               | Disposition |
| ------ | ------------------------------------------------------------------------------------------------------------ | ------------------ | ----------- |
| INF-01 | Within one multi-band deposit, a later band's fee can reach a tier an earlier band of the same deposit filled | Opus R1            | Pre-existing under the averaged model; now the mechanism behind `MA-02` and documented there |
| INF-02 | The playground's float model still simulates averaged positions and does not model per-lot LIFO              | GPT-5.6-sol R1/R2  | **Accepted gap**, stated explicitly in the parity suite rather than silently tolerated |
| INF-03 | The protocol package's compiled bytecode artifact was not regenerated, so the demo's fresh-deploy path runs old bytecode | Copilot (PR #1775) | **Fixed** on 18 September, after a curve deployed from the demo was confirmed on-chain to be the pre-remediation implementation: the curve and MultiVault artifacts are regenerated from the remediation build and match `forge` output byte for byte. The deferral had been meant for the public mirror only, whose artifacts regenerate with the replay |
| INF-04 | An untracked scratch gas-measurement test sat in the working tree                                            | GPT-5.6-sol R2, Opus R2 | **Fixed** — deleted before the commit |
| INF-05 | The protocol and CLI barrels export lot modules that appear to be repurposed files, which would fail to resolve | Copilot (PR #1796) | **Refuted.** All five protocol readers, all five CLI encoders and the redeem-lot event parser exist in the commit; both packages typecheck clean. The diff's rename detection produced the appearance |
| INF-06 | The lot quote prices shares beyond the recorded lots at the vault tier instead of rejecting them              | Copilot (PR #1796) | **By design** — mirrors the contract exactly; an oversized redeem reverts at execution, and diverging would break wei-exact parity. Rationale added to the function's documentation |
| INF-07 | Per-credit tier-width lookups scale with the square of the tier count across a full-ladder deposit            | Opus R2            | **Measured within ceiling** at the launch ladder; the eligibility check short-circuits before the lookup at floor 0. Confirm before any ladder extension |
| INF-08 | An over-full tier absorbs what thinner tiers leave, so stuffing one prior tier far past its width ahead of a large fee captures shortfall that would otherwise accrue | Opus R1 (occupancy) | **By design** — per share stays at or below the schedule rate in every branch; the surface is against the protocol bucket only, and round-trip fees on the stuffed amount exceed a realistic single fee at the launch schedule |
| INF-09 | The redistribution-bounds suite asserts a zero fulcrum share against the test harness config, while the deploy script ships 7500, so nothing gates the shipped schedule against that suite | Opus R2 (occupancy) | **Acknowledged, pre-existing** — the suite documents the harness schedule, not the deployment; a deploy-config bounds test is a follow-up |

---

## 7. Properties checked — coverage evidence

The tests added in this round are negatives, not demonstrations. Each of the following is asserted in the suite, and
each corresponds to an invariant in §4 or a finding in §6.

| Property                                                                                               | Where |
| -------------------------------------------------------------------------------------------------------- | ----- |
| No account is paid out of its own redeem fee at **any** tier, including tiers where it holds residual lots | Curve unit suite — multi-tier exclusion test |
| A half-filled prior tier earns exactly half of a full tier's entitlement from a spiked deposit           | Curve unit suite — the `MA-01` regression, re-derived under occupancy weighting |
| A walk's residue accrues and is never re-offered to a tier that took its fill, on both legs             | Curve unit suite — the `MA-03` regressions, exact numbers |
| For every prior tier, per-share income from one fee is at most a full band's spike plus kernel share, and the fee is conserved | Curve unit suite — fuzz over random fills and spike sizes |
| A tier at the edge of the window keeps its schedule share instead of triggering the fill-only fallback | Curve unit suite — the `MED-05` regression |
| A lone thin tier takes only its fill of an equal share; an over-full tier absorbs a thin one's shortfall at the same rate per share | Curve unit suite — degenerate guard and sweep tests, re-derived |
| A reroute walks above then below until placed; a dust seat above an exiting whale cannot divert the slice | Curve unit suite |
| A seat at the floor in a zero-weight tier earns nothing of an orphaned slice; an excluded tier's share accrues | Eligibility suite — seven tests re-derived |
| A multi-band deposit's earlier band earns exactly its schedule share of the next band's fee (`MA-02` closed) | Curve unit suite — pinned with exact numbers |
| Lots unwind highest tier first; the top lot falls as the high lot drains                                | Curve unit suite — two tests |
| A redeem split into chunks never undercuts the lump fee and leaves the same lots                        | Neutrality suite — fuzzed |
| One wallet in N legs is **exactly** N wallets on the deposit leg (ledger, bystanders, protocol bucket)  | Neutrality suite — fuzzed, exact equality |
| The deposit-side wallet-split residual is zero at the shipped kernel and under both kernel levers       | Split-edge measurement suite — sweep, was a non-zero plateau |
| The lot ledger stays consistent after every step of a random action sequence                            | Neutrality suite — fuzzed |
| The lot ledger stays consistent under stateful fuzzing against MultiVault                               | Invariant suite — new invariant |
| The curve always holds enough to cover protocol accrual plus every account's claimable                  | Invariant suite — carried |
| The side-pocket ledger mirrors MultiVault share balances                                                | Invariant suite — carried |
| Per-lot events reconstruct the redeem and the forwarded fee exactly                                     | Curve unit suite |

**Mutation evidence.** The first five commits were confirmed in rounds of the earlier lane by mutation: reverting either
the FeeProxy reorder or the default-curve guard turns exactly its new tests red and nothing else. The two curve commits
were not mutation-tested as a whole; `MA-01`'s regressions were written against the broken behaviour and observed to
fail before the fix, which is the same evidence for that finding specifically. The four tests added with `28adaa4bb`
were run against `47da073e4`'s curve source: all four fail there (the fuzz with a counterexample on its first run) and
pass on the fixed source.

**Not performed in this round:** no lane executed the full suite (each was given a static-review budget); no fresh
static-analysis sweep, the surface being a subset of round 2's; no formal verification.

---

## 8. Lane provenance

| #   | Lane                                | Model / effort                  | Unit reviewed                    | Result |
| --- | ----------------------------------- | ------------------------------- | -------------------------------- | ------ |
| 1   | Isolated rubric lane, 2 rounds      | Opus, isolated context          | First five commits               | PASS, with mutation confirmation |
| 2   | Cold cross-model review             | GPT-5.6-terra, xhigh            | First five commits               | Approve with nits |
| 3   | Cold cross-model review, round 1    | GPT-5.6-sol, xhigh              | 5.1 + 5.3 together               | **Not approved** — 2 blocking, 4 non-blocking |
| 4   | Cold cross-model review, round 2    | GPT-5.6-sol, xhigh              | 5.1 + 5.3, after `MA-01` fix     | Approve with nits — 0 blocking |
| 5   | Isolated rubric lane, round 1       | Opus, isolated context          | 5.1 + 5.3 together               | **FAIL** — `MED-01`, `MED-02`, 3 Minor |
| 6   | Isolated rubric lane, round 2       | Opus, isolated context          | 5.1 + 5.3, frozen diff           | **FAIL** — `MA-02` (new), `MED-03`, 2 Minor |
| 7   | Independent cold review             | GPT-6-astra, medium             | Both curve commits, curve-focused | Approve with nits — 1 non-blocking |
| 8   | Hosted PR review                    | GitHub Copilot                  | PR #1775                         | 5 comments, all actioned |
| 9   | Hosted PR review                    | GitHub Copilot                  | PR #1796                         | 4 comments — 2 actioned, 2 refuted |
| 10  | Independent cold review, round 1    | GPT-6-astra, high               | Occupancy commit `47da073e4`     | **Not approved** — 2 blocking (`MA-03`, `MED-05`), 1 non-blocking (`MIN-16`) |
| 11  | Isolated rubric lane, round 1       | Opus, isolated context          | Occupancy commit `47da073e4`     | **FAIL** — `MA-03`, `MIN-15`, 4 Low (`MIN-17`–`MIN-19`, `INF-08`) |
| 12  | Independent cold review, round 2    | GPT-6-astra, high               | Cumulative `b159cf6c0..28adaa4bb` | Approve with nits — 0 blocking, 3 non-blocking (coverage of the cohort fallback, guide contradictions, a dropped graph edge), all actioned |
| 13  | Isolated rubric lane, round 2       | Opus, isolated context          | Cumulative `b159cf6c0..28adaa4bb` | **FAIL** — `MED-06` (rated HIGH by the lane; a policy the owners chose, recorded for reconfirmation), `MED-07`, `MIN-20`, `INF-09`, plus coverage of the cohort fallback (closed by the tests added after the reviewed range) |

**Lane construction.** Lanes 1, 5 and 6 ran in a context that had not written the code, were given the raw diff and a
funds-touching rubric, and were told that a `PASS` without an attempted refutation counts as a `FAIL`. Lanes 2, 3, 4 and
7 were given a cold prompt containing only the PR description and the diff. Lanes 5 and 6 were additionally told which
earlier dispositions had been taken, to stop them re-litigating settled items and free them to find what the previous
round missed — which is how `MA-02` surfaced. Lane 7 was told to concentrate on the curve and to treat the remaining
Solidity and the TypeScript as non-priority.

**Disagreements carried.** Lane 6 rated `INF-01` as a Major consequence of `MA-02` rather than as pre-existing
behaviour; this report records the mechanism as `MA-02` and the pre-existing property as `INF-01`, which preserves both
readings. Lane 6 rated `MED-03` Medium on a premise that lane 4 and the 5.6 fix make unreachable; the finding is
recorded at the lane's severity with the closure stated.

---

## 9. Residual risk

1. **Sweep recovery** (`MA-02`) and **over-capacity dilution** (`MED-04`) are closed by the occupancy weighting; what
   remains of both is the ordinary schedule share, and a simulation cell after deployment should confirm the fee
   stream under real flows.
2. **Protocol accrual has a defined map, and is bounded but not zero.** A fee reaches the bucket only when the source
   tier is 0; when the redeem spread places nothing and the drawn lots' cohorts cannot take it either; when the prior
   ladder as a whole holds less than its widths and the shortfall has no stake to earn it at the schedule rate; when a
   single-target walk exhausted every candidate; or when a floor above zero excludes a tier. Historical simulations
   measured the bucket at 0.08% to 0.32% of curve fees across the anvil sweeps and about 2.2% in the smaller testnet
   session, all of it first-band deposits into fresh vaults; the thin-ladder routes are zero in a growing vault and
   proportional to churn below the frontier otherwise. To be re-measured on the new curve.
3. **Worst-case redeem gas** (`MIN-19`) grows with the tier count per lot drawn when the ladder is thin everywhere.
   Within ceiling at the launch ladder; to be confirmed before any ladder extension.
4. **Event semantics changed** (`MIN-12`, plus the deposit summary's field change and the new per-lot redeem event).
   The indexer realignment is deliberately held until deploy and must absorb all three.
5. **The fresh-deployment constraint** (`MED-01`) is a runbook item with no on-chain enforcement.
6. **Two consumer-facing TypeScript shapes changed** — the redeem quote plan and the holder-earning projection — which
   is breaking for any consumer outside this repository.

## 10. Gate

**Clear for external re-review, with `MED-06` to reconfirm.** No open Major or Medium. Every finding in §6 is closed
by code or carries a recorded owner disposition with its alternatives; `MED-06` is a disposition taken on 17
September whose two-wallet consequence the owners should see before it stands. The full core suite is green at the
reviewed head, the curve commits are isolated and replayable, and the artefacts Diligence closes against — one commit
per issue plus the acknowledgement notes — exist. The two doc-and-test commits after `28adaa4bb` change no logic; the
two-round cap on an unchanged diff applies, and no third round was dispatched.

**Accompanying the reply to Diligence:** 5.3 changes the exit path and warrants additional reviewer days; the ask should
go out with the reply rather than after it.
