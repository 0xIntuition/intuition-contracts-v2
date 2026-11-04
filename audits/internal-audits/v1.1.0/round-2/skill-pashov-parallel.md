# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 7 of 7 — Parallel attacker lenses (12 concurrent specialist lenses + dedup + four judging gates)

> **How this report was produced:** a parallel specialist-lens round. Twelve concurrent adversarial lenses — math /
> precision, access control, economic security, execution trace, invariants, periphery, first principles, asymmetry,
> boundary enumeration, and three cross-lens "gap hunter" agents (numerical, trust, control-flow) — each received the
> full in-scope source plus a shared engagement overlay carrying the mandate, the load-bearing invariants, the
> out-of-scope denylist, and the prior round's disposition register. Their output was then deduplicated by (contract,
> function, bug class) and put through four sequential judging gates (attack execution → reachability → unprivileged
> trigger → material impact). Every promoted finding was independently re-verified by the orchestrator against the
> reviewed commit; the two Major findings were reproduced by executing a Foundry proof of concept against a pristine
> checkout of that commit, and both landed fixes were confirmed by mutation-checking their guards. Provenance ID prefix:
> `R2-PAS-`. One of 7 independent round reports; consolidated view:
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

## 1. Report metadata

| Field                           | Value                                                                                                                                    |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **Artifact type**               | Internal AI pseudo-audit — pre-audit artifact. **Not** a formal audit, certification, warranty, or guarantee of safety.                  |
| **Target**                      | Intuition v1.1.0 core upgrade, public mirror (`intuition-contracts-v2`), extending PR #153                                               |
| **Reviewed commit**             | `8579c5e02e6fd1b58620565d5a6d06d3b9391548` (branch `feat/v1.1.0-core-upgrade`)                                                           |
| **Working HEAD at review time** | `ac567b2ecd03d12e3e27c0ce570381ef9e383196` — `git diff 8579c5e..HEAD -- src/` is **empty**; the audited source is byte-identical at both |
| **Source root**                 | `src/`                                                                                                                                   |
| **Diff basis**                  | `git diff main...HEAD`; delta-since-last-audited-commit basis `git diff b52557b..HEAD -- src/` (30 files, +1537 / −875)                  |
| **Toolchain**                   | Solidity `0.8.29`, Foundry `1.5.1`, TransparentUpgradeableProxy throughout                                                               |
| **Target networks**             | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                                                |
| **Review depth**                | Whole-contract, not diff-only                                                                                                            |
| **Date**                        | 2026-07-28                                                                                                                               |

---

## 2. Executive summary

This round ran twelve concurrent adversarial lenses over the full v1.1.0 in-scope set, weighted toward the two clusters
with **zero prior audit coverage**: the `DynamicFeeFlatPriceCurve` fee economy (C1) and the standardized `IBaseCurve`
fee-hook surface with its `MultiVaultLib` dispatch (C2).

The headline result is **three Major findings in the fee-redistribution kernel**, all permissionless. They share a
single root theme: **tier entitlement is decoupled from the capital and the commitment behind it.** Fee slices are
allocated _between_ tiers by kernel weight alone, with stake used only as a boolean occupancy test; a redeem never
re-derives the exiting holder's bucket; and a position becomes fully entitled the instant it is opened, with no dwell
requirement.

The consequences compound. A position reduced to **one wei** remains a full-weight recipient — in a reproduced case a
1-wei position out-earned an 11.12 TRUST position by 1.5×, capturing 60% of a deposit fee, and separately captured
**100%** of a departing holder's withdrawal fee. Worse, no long-term positioning is even required: a minimum-size
deposit front-run into the same block as a victim's redeem captures ~100% of that exit fee and exits in the same bundle,
for a measured realized return of **+221% on 0.1 TRUST in a single transaction**, at zero price risk. A counterfactual
run confirms the captured value would otherwise have accrued to an honest holder who had been in the vault since before
the exiting party entered.

This inverts the mechanism the fee economy exists to implement — rewarding committed prior-tier capital — and it is
cheap, repeatable, and requires no privileged role.

Beyond those, the round found two Medium issues where a guard's stated envelope does not hold (a per-tier fee override
survives a cap _tightening_ and is read back unclamped; the atom/triple creation paths never invoke the curve hook and
nothing asserts the default curve is hookless), four Minor issues, and seven Informational items.

Both fixes that landed since the prior round were verified **and mutation-checked**: neutering each guard turns its
gating tests red, so the coverage is real rather than incidental.

The most significant coverage observation is that the **quote-then-record fee-parity guarantee — the load-bearing
property of the entire C2 hook surface — has no gating test.** Removing it leaves the full dynamic-fee suite green: 28
of 28 tests pass, including three invariant suites and two 10,000-run fuzz solvency tests.

### Severity counts

| Severity          | Count  |
| ----------------- | ------ |
| **Critical**      | 0      |
| **Major**         | 3      |
| **Medium**        | 2      |
| **Minor**         | 4      |
| **Informational** | 8      |
| **Total**         | **17** |

### Cluster verdicts

| Cluster                                         | Scope     | Verdict                               |
| ----------------------------------------------- | --------- | ------------------------------------- |
| **C1** — `DynamicFeeFlatPriceCurve` fee economy | Primary   | **VERDICT: FAIL** (3 Major, 2 Medium) |
| **C2** — `IBaseCurve` hook surface + dispatch   | Primary   | **VERDICT: FAIL** (1 Medium, 1 Minor) |
| **Δ** — delta since last audited commit         | Secondary | **VERDICT: PASS**                     |
| **A** — `multicallPayable` value accounting     | Sweep     | **VERDICT: PASS**                     |
| **B** — `MultiVaultLib` storage mirror          | Sweep     | **VERDICT: PASS**                     |
| **D** — `AtomWarden` quorum + window cap        | Sweep     | **VERDICT: PASS**                     |
| **E** — `AtomWallet` ERC-4337 / P-256 auth      | Sweep     | **VERDICT: PASS**                     |
| **F** — `TrustBonding` emissions + pause        | Sweep     | **VERDICT: PASS**                     |
| **G** — `FeeProxy` refund ledger                | Sweep     | **VERDICT: PASS** (1 Informational)   |
| **H** — Emissions controllers (Intuition side)  | Sweep     | **VERDICT: PASS**                     |

---

## 3. Scope

### 3.1 In scope

All paths relative to `src/` at commit `8579c5e02e6fd1b58620565d5a6d06d3b9391548`.

| Contract                         | Path                                                                                                                                               |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MultiVault`                     | `protocol/MultiVault.sol`                                                                                                                          |
| `MultiVaultCore`                 | `protocol/MultiVaultCore.sol`                                                                                                                      |
| `MultiVaultLib` (linked library) | `libraries/MultiVaultLib.sol`                                                                                                                      |
| `BondingCurveRegistry`           | `protocol/curves/BondingCurveRegistry.sol`                                                                                                         |
| `BaseCurve`                      | `protocol/curves/BaseCurve.sol`                                                                                                                    |
| `LinearCurve`                    | `protocol/curves/LinearCurve.sol`                                                                                                                  |
| `DynamicFeeFlatPriceCurve`       | `protocol/curves/DynamicFeeFlatPriceCurve.sol`                                                                                                     |
| `AtomWallet`                     | `protocol/wallet/AtomWallet.sol`                                                                                                                   |
| `AtomWalletFactory`              | `protocol/wallet/AtomWalletFactory.sol`                                                                                                            |
| `AtomWarden`                     | `protocol/wallet/AtomWarden.sol`                                                                                                                   |
| `TrustBonding`                   | `protocol/emissions/TrustBonding.sol`                                                                                                              |
| `CoreEmissionsController`        | `protocol/emissions/CoreEmissionsController.sol`                                                                                                   |
| `SatelliteEmissionsController`   | `protocol/emissions/SatelliteEmissionsController.sol`                                                                                              |
| `FeeProxy`                       | `periphery/FeeProxy.sol`                                                                                                                           |
| `CoinbaseSmartWalletLib`         | `libraries/CoinbaseSmartWalletLib.sol`                                                                                                             |
| Interfaces                       | `interfaces/IBaseCurve.sol`, `IDynamicFeeFlatPriceCurve.sol`, `IMultiVault.sol`, `IBondingCurveRegistry.sol`, `IAtomWallet.sol`, `IAtomWarden.sol` |

`ProgressiveCurve` and `OffsetProgressiveCurve` were included **only** to confirm they remain safe no-ops under the new
`IBaseCurve` hook defaults; their pricing math was not reviewed.

Every cluster was symbol-searched to confirm it exists at the reviewed commit before being attacked. All were present;
nothing was marked "not present at this commit".

### 3.2 Out of scope

Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain transport leg; `BaseEmissionsController` and
all Base-chain components; the deliberately parked TVL exit circuit breaker / rate limiter; unbounded cross-curve
counter-stake aggregation; `MultiVaultMigrationMode`; the `ProgressiveCurve` / `OffsetProgressiveCurve` /
`ProgressiveCurveMathLib` pricing math; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow`; the
`AtomWallet` delegation framework (`executeFromExecutor`), held out of merge; and whole-surface `multicallPayable`
batching that mixes payable and non-payable legs.

**Trusted-admin centralization is an accepted trust assumption.** Privileged actions are gated by a 4-of-8 Safe acting
through two `TimelockController`s (parameters 3-day, upgrades 7-day). "A trusted admin can do X" is not reported as a
finding. Where a finding below involves a privileged setter, it is because the guard **fails open on an action whose
intent is to tighten**, or because a missing assertion converts a routine configuration change into **irreversible**
user loss — the access mechanism itself is the defect, not the privilege.

---

## 4. Severity classification

Severity is assigned as **Impact × Likelihood**, taking the highest severity a _credible_ path reaches under the
intended deployment and trust model, and separating permissionless exploitability from trusted-admin misuse.

|                    | **Likelihood: High** | **Likelihood: Medium** | **Likelihood: Low** |
| ------------------ | -------------------- | ---------------------- | ------------------- |
| **Impact: High**   | Critical             | Major                  | Medium              |
| **Impact: Medium** | Major                | Medium                 | Minor               |
| **Impact: Low**    | Medium               | Minor                  | Informational       |

| Severity          | Meaning                                                                                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                                |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, admin footgun, or a spec regression materially affecting users or operators.    |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behavior, monitoring or integration weakness.                                            |
| **Informational** | Documentation, hygiene, NatSpec-vs-behavior mismatch, or a missing non-critical test.                                                                        |

---

## 5. Findings

### R2-PAS-01 — Fee redistribution is stake-independent between tiers, so a dust position captures a whole tier's slice — **Major**

**Invariant broken:** §5.1 (conservation of value — a distributed fee must reach the cohort it is promised to, in
proportion to the stake that earns it). **Cluster:** C1. **Confidence:** High. **Status:** Open.

#### Description

The triangular fulcrum kernel decides how a deposit fee is split **across** prior tiers using the kernel weight alone. A
tier's stake is consulted only as a boolean occupancy test — it gates whether the tier participates, but it never scales
how much the tier receives. The per-tier slice is then divided by that tier's stake to form a per-share accumulator, so
_within_ a tier the split is correctly pro-rata; _between_ tiers it is not.

The result is that a tier holding one wei is a full-weight recipient standing alongside a tier holding thousands of
TRUST, and the single dust holder absorbs that tier's entire slice.

The bucket is trivially and permanently squattable because `recordRedeem` never re-derives `userTier` or `userAvgTier`.
A holder can enter a tier, withdraw all but one wei, and keep the tier seat indefinitely — through retunes, since the
accumulators are index-keyed and never migrated.

#### Code

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:661-687` — the weight ignores stake magnitude:

```solidity
uint256 recipientStake = tierStake[termId][targetTier];
if (targetTier == excludeTier) {
    recipientStake -= excludeStake;
}
stakes[d - 1] = recipientStake;
if (recipientStake > 0) {                                   // stake is only a boolean gate
    uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma);
    weights[d - 1] = w;                                     // weight depends only on distance
    sumWeights += w;
}
```

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:636-657` — the slice is allocated by weight only:

```solidity
uint256 share = pool.mulDiv(w, sumWeights);                 // independent of stakes[d - 1]
if (share > 0) {
    accFeePerShare[termId][span - d] += share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
    assigned += share;
}
```

Supporting: `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:401-452` (`recordRedeem` writes neither `userTier` nor
`userAvgTier`), and `:614` (`dStar = 0` under the shipped `fulcrumAlpha = BPS`, which places the peak on the nearest
prior tier).

#### Proof of concept

Reproduced by execution against a pristine checkout of `8579c5e` (`git diff --quiet -- src/` asserted before the run),
using the repository's own `BaseTest` fixture and the dynamic-fee curve at registry id 4.

1. A large holder deposits 5 TRUST then 1 TRUST into a fresh atom vault, landing in bucket 0 with ≈5.82 TRUST.
2. The attacker deposits 3 TRUST — also landing in a weighted bucket — then immediately redeems all but **1 wei**. The
   bucket seat survives the exit.
3. The large holder deposits a further 5.5 TRUST, moving the vault up a band without moving their own bucket. State
   before the fee event: `vaultAssets = 11121671249999039675`, `tierOf = 2`, `tierStake[0] = 11121671249999039674`,
   `tierStake[1] = 1`.
4. A third party deposits 50 TRUST. With `dStar = 0` and `sigma = 4e18`, bucket 1 weighs 0.75 and bucket 0 weighs 0.50,
   so `sumWeights = 1.25`.

Observed distribution of the `1386016712499990398` wei deposit fee:

| Recipient    | Stake                                     | Fee received         | Share     |
| ------------ | ----------------------------------------- | -------------------- | --------- |
| Attacker     | **1 wei**                                 | `831610027499994238` | **60.0%** |
| Large holder | `11121671249999039674` wei (≈11.12 TRUST) | `554406684999996153` | 40.0%     |

Failing assertion: `dust bucket out-earns the funded bucket: 831610027499994238 >= 554406684999996153`.

The attacker's setup cost is one round trip (entry and exit fees on 3 TRUST), recovered by the first fee event, and the
position is then permanent. Bucket placement is directly controllable, since `userAvgTier` is the stake-weighted mean of
entry bands and `depositBatch` / `multicallPayable` allow two legs at two different vault bands in a single transaction.

#### Recommendation

Make the between-tier allocation stake-weighted so the kernel modulates a per-unit-stake payout rather than distributing
per-bucket lumps. In `_weighPriorTiers`, accumulate the stake-scaled weight:

```solidity
uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma).fullMulDiv(recipientStake, WAD);
weights[d - 1] = w;
sumWeights += w;
```

This preserves the tent shape and the sliding fulcrum while removing the dust arbitrage. Pair it with the `userTier` /
`userAvgTier` re-derivation in R2-PAS-02 so a stripped position also loses its seat.

**Note before landing:** this changes the economics encoded in the executable model the curve was ported from. Confirm
with the modeling work that per-bucket lump allocation was not deliberate before changing it. If it _was_ deliberate,
the dust-squatting consequence still needs an explicit mitigation.

#### Regression test

`CurveFeeTierWeightProportionality.t.sol` — assert that for two occupied tiers at equal kernel distance, the ratio of
credited fee equals the ratio of tier stake; and that a 1-wei tier cannot receive more than a tier holding orders of
magnitude more stake.

#### Variant sweep

| Path                                                 | Result                                                                          |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- |
| Single deposit                                       | Same bug                                                                        |
| `depositBatch`                                       | Same bug — and the cheapest bucket-placement primitive                          |
| On-behalf-of (`createAtomsFor` / `createTriplesFor`) | n/a — create paths never invoke the hook (see R2-PAS-03)                        |
| Preview                                              | n/a — view path does not distribute                                             |
| Router (`FeeProxy`)                                  | Same bug, inherited through `MultiVault.deposit`                                |
| Upgrade / retune                                     | Same bug — `setConfig` cannot migrate index-keyed buckets, so the seat survives |

---

### R2-PAS-02 — A one-wei co-occupant captures 100% of an exiting holder's withdrawal fee — **Major**

**Invariant broken:** §5.1 (conservation of value — the fee reaches a "home", but one not proportional to the stake the
redistribution promise was made to). **Cluster:** C1. **Confidence:** High. **Status:** Open.

#### Description

The diamond-hands slice of a withdrawal fee is credited to the exiting holder's tier with the exiter's own residual
correctly excluded from the denominator — but nothing bounds what remains. If the only other occupant of that tier holds
one wei, that dust position becomes the sole recipient of an arbitrarily large exit fee.

This is reachable with **no tier engineering at all**: the attacker simply deposits into the same band as the target,
which is the default outcome of depositing into a young vault. It shares the sticky-bucket enabler with R2-PAS-01 —
`recordRedeem` never rewrites `userTier` / `userAvgTier`, so a position stripped to dust keeps its seat.

A second reachable variant follows from the same root cause: when the exiter is the _sole_ occupant,
`_nearestOccupiedTier` searches **above first** and awards the whole slice to the first occupied bucket found, divided
by that bucket's stake. Parking one wei one bucket above a known large holder captures their entire exit fee.

#### Code

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:419-442`:

```solidity
uint256 denom = tierStake[termId][exitTier] - residual;     // exiter excluded, remainder unbounded
if (toTier > 0) {
    if (denom > 0) {
        accFeePerShare[termId][exitTier] += toTier.fullMulDiv(ACC_PRECISION, denom);
    } else {
        (uint256 recipientTier, uint256 recipientStake) = _nearestOccupiedTier(termId, exitTier);
        ...
```

Supporting: `:769-786` (`_nearestOccupiedTier`, above-first scan) and `:401-452` (`recordRedeem` never rewrites
`userTier` / `userAvgTier`).

#### Proof of concept

Reproduced by execution against a pristine checkout of `8579c5e`.

1. A holder deposits 4 TRUST into a fresh atom vault → bucket 0, ≈3.88 TRUST.
2. The attacker deposits 3 TRUST → also bucket 0 (the vault is still below `width0`). No tier targeting required.
3. The attacker redeems all but **1 wei**. The bucket seat is sticky.
4. The holder exits.

Observed:

```
before the whale exit:  tierStake[0] = 3879999999999030001
withdrawal fee released                 77579999999980600 wei
attacker stake                                          1 wei
attacker share of the fee               77579999999980600 wei  (10000 bps = 100%)
```

Failing assertion: `dust bucket captured the exit fee: 77579999999980600 != 0`.

The shipped default `withdrawalToRecentShareBps = 0` routes the **entire** withdrawal fee down this path, so the capture
is total. Scaling linearly, a 100 TRUST exit at the shipped withdrawal schedule yields ≈2 TRUST to a 1-wei position.

#### Recommendation

Two complementary changes:

1. Re-derive `userTier` and `userAvgTier` on redeem so a position reduced to dust loses its tier standing rather than
   retaining it for free. This closes the enabler shared with R2-PAS-01.
2. Require the post-exclusion denominator to be economically meaningful before crediting it — a minimum eligible stake,
   or a floor expressed as a fraction of `vaultAssets[termId]` — falling through to the existing `_nearestOccupiedTier`
   / `protocolAccrued` path otherwise, which already handles the `denom == 0` case.

#### Regression test

`ExitFeeResidualCohortEligibility.t.sol` — assert that a holder whose stake is a negligible fraction of the exiting tier
cannot receive a materially disproportionate share of an exit fee, and that a redeem re-derives the redeemer's bucket.

#### Variant sweep

| Path                | Result                                                     |
| ------------------- | ---------------------------------------------------------- |
| Single redeem       | Same bug                                                   |
| `redeemBatch`       | Same bug, per leg                                          |
| On-behalf-of        | Same bug — redeem-for-receiver books to the receiver       |
| Preview             | n/a                                                        |
| Router (`FeeProxy`) | n/a — `FeeProxy` exposes no redeem surface                 |
| Retune              | Same bug — bucket seats are index-keyed and never migrated |

---

### R2-PAS-16 — Tier entitlement has no dwell requirement, so a front-run minimum deposit captures a departing holder's exit fee — **Major**

**Invariant broken:** n/a — new class (mechanism failure; conservation and solvency both hold). **Cluster:** C1.
**Confidence:** High. **Status:** Open.

#### Description

A position's entitlement to a tier accumulator is established at `recordDeposit` time, when `rewardDebt` is set against
the tier's current `accFeePerShare`. There is no dwell requirement of any kind, so a position opened in the immediately
preceding transaction earns exactly as much per unit of stake as a position held for a year.

Because the withdrawal fee is credited by dividing across the _recipient tier's_ stake, an attacker who front-runs a
visible redeem with a minimum-size deposit into the recipient bucket captures nearly the entire exit fee — and can claim
and unwind in the same bundle. The shipped `withdrawalToRecentShareBps = 0` routes **100%** of every exit fee into this
slice, so there is no dilution.

This is distinct from R2-PAS-02 and needs its own fix. R2-PAS-02 is a _sticky seat_ — a position stripped to dust
retains standing indefinitely. This is a _zero-dwell_ defect: no positioning or patience is required at all, only
mempool visibility. R2-PAS-02 is fixed by re-deriving the bucket on redeem and flooring the denominator; that does
nothing to stop a freshly-funded, correctly-sized position from capturing the same fee.

It directly defeats the stated purpose of the slice, which the NatSpec frames as a reward to "the residual holders of
the exiting tier (diamond-hands)". A one-transaction-old position is not a diamond hand.

#### Code

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:389` — entitlement granted immediately at deposit:

```solidity
rewardDebt[termId][account] = newStake.fullMulDiv(accFeePerShare[termId][newTier], ACC_PRECISION);
```

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:424-441` — the credit divides by the recipient tier's stake, which the
fresh position now dominates:

```solidity
uint256 denom = tierStake[termId][exitTier] - residual;
if (toTier > 0) {
    if (denom > 0) {
        accFeePerShare[termId][exitTier] += toTier.fullMulDiv(ACC_PRECISION, denom);
    } else {
        (uint256 recipientTier, uint256 recipientStake) = _nearestOccupiedTier(termId, exitTier);
```

Supporting: `:530-538` (`_settle`), `:769-786` (`_nearestOccupiedTier`, above-first scan widens the reachable recipient
buckets).

#### Proof of concept

Executed against the repository's `BaseTest` fixture (5 tiers, `width0 = 5e18`, withdrawal 200 bps + 50/tier,
`withdrawalToRecentShareBps = 0`, `MIN_DEPOSIT = 1e17`).

1. The attacker observes a redeem in the mempool.
2. The attacker front-runs with a `MIN_DEPOSIT` (0.1 TRUST) deposit sized to land in the recipient bucket.
   `recordDeposit` sets `rewardDebt` against the current accumulator, making the position immediately and fully
   eligible.
3. The victim's `recordRedeem` credits `accFeePerShare[recipientTier] += toTier × ACC_PRECISION / recipientStake`, where
   `recipientStake` is now dominated by the one-transaction-old position.
4. The attacker claims and closes in the same bundle.

| Scenario                                                                                 | Attacker capital | Victim fee           | Captured             | Share         |
| ---------------------------------------------------------------------------------------- | ---------------- | -------------------- | -------------------- | ------------- |
| Nearest-occupied fallback (`denom == 0`; attacker sole occupant of the recipient bucket) | `1e17`           | `230189861250000144` | `230189861250000143` | **9999 bps**  |
| Primary path (`denom > 0`; attacker inside the exiter's own bucket)                      | `1e17`           | `72375000000000000`  | `72375000000000000`  | **10000 bps** |

Realized end-to-end profit for the fallback case — **after** paying the attacker's own curve deposit fee, curve
withdrawal fee, and the vault's protocol, entry and exit fees, and after fully closing the position:

```
+221392361250000143 wei  (+0.2214 TRUST) on 0.1 TRUST deployed for one transaction
= +221% return, at zero price risk (flat 1:1 par)
```

The counterfactual run with the front-run removed shows the identical `230189861250000141` wei accruing to an honest
holder who had been in the vault since before the exiting party entered. This is a direct transfer from a long-standing
holder, not a claim on protocol dust.

Production impact is **larger**, not smaller: the shipped schedule sets `withdrawalToRecentShareBps = 0`, so the diamond
slice is the entire exit fee.

#### Recommendation

Extend the exclusion machinery that already exists — it removes `excludeStake` from a recipient denominator and re-bases
that party's `rewardDebt` — to also exclude stake whose deposit landed inside a configured dwell window:

1. Record the deposit timestamp per position in `recordDeposit`.
2. Accumulate a per-tier `youngStake[termId][tier]`.
3. Subtract it from every recipient denominator — in `_weighPriorTiers` and in the `denom` computation at `:424`.
4. Re-base young positions' `rewardDebt` post-distribution, exactly as `:389` and `:448` already do.

A dwell window measured in blocks is sufficient to defeat the same-bundle attack; a longer window also blunts
short-horizon rotation.

#### Regression test

`ExitFeeDwellRequirement.t.sol` — assert that a position opened in the same block as a redeem receives no share of that
redeem's fee, and that the fee accrues to the pre-existing cohort instead.

#### Variant sweep

| Path                    | Result                                                                                                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Single redeem           | Same bug                                                                                                                                  |
| `redeemBatch`           | Same bug, and strictly cheaper — one transaction for the entry                                                                            |
| On-behalf-of            | Same bug                                                                                                                                  |
| Preview                 | Safe — view only                                                                                                                          |
| Router (`FeeProxy`)     | Same bug                                                                                                                                  |
| Upgrade-initializer     | n/a                                                                                                                                       |
| **Deposit-side mirror** | **Safe — measured.** See §6.2; the equivalent front-run against `_payRecentTiers` is structurally defended and was measured net-negative. |

---

### R2-PAS-03 — Creation paths never invoke the curve fee hook, and nothing asserts the default curve is hookless — **Medium**

**Invariant broken:** §5.3 (curve ledger mirrors vault shares). **Cluster:** C2 / B. **Confidence:** High. **Status:**
Open.

#### Description

`_processDeposit` invokes `_recordCurveDeposit` on every path and `_processRedeem` invokes `_recordCurveRedeem`
unconditionally on any hook curve — deliberately, "even at a zero fee, so the curve's per-user share ledger stays in
lockstep with the vault". The atom and triple **creation** paths do neither. `_calculateAtomCreate` and
`_calculateTripleCreate` do not even resolve a `CurveHook`, yet `_updateVaultOnCreation` mints shares to the creator.

The mint-side and burn-side coverage of the ledger-mirror invariant are therefore structurally asymmetric. This is safe
today only because creation is hard-coded to `bondingCurveConfig.defaultCurveId`, which is the hookless `LinearCurve`.
**No code asserts that.** `setBondingCurveConfig` writes the whole struct and validates neither `hasDepositFeeHook()`
nor `hasRedeemFeeHook()`.

If the default curve were ever pointed at a fee-hook curve, every created term would mint vault shares with no
corresponding `userStake` on the curve. The creator's first redeem would then reach
`userStake[termId][account] -= withdrawnStake` with a zero left-hand side and revert with `Panic(0x11)` — **after**
every vault-state write, and with no repair path, because the missing ledger entries are never backfilled. Re-pointing
`defaultCurveId` back does not undo it. The affected principal is permanently unredeemable.

This is filed despite the trusted-admin trigger because the defect is the **absent invariant assertion**, and the
failure mode is irreversible loss rather than a recoverable outage.

#### Code

`src/libraries/MultiVaultLib.sol:571` and `:649` — creation calculates without a hook:

```solidity
(uint256 sharesForReceiver, uint256 assetsAfterFixedFees, uint256 assetsAfterFees) =
    _calculateAtomCreate(atomId, assets);
```

`src/libraries/MultiVaultLib.sol:911-933` and `:969-989` — neither create calculator resolves `_depositFeeHookCurve`.
Contrast `src/libraries/MultiVaultLib.sol:771` (deposit path always records) and `:808` (redeem path always records).

`src/protocol/MultiVault.sol:825-828` — the setter with no hookless assertion:

```solidity
function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyTimelock {
    bondingCurveConfig = _bondingCurveConfig;
    emit BondingCurveConfigUpdated(_bondingCurveConfig.registry, _bondingCurveConfig.defaultCurveId);
}
```

Detonation site: `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:415-416`.

#### Proof of concept

Not executed — the precondition requires a timelocked governance action, so this is filed as a fail-dangerous
configuration gap rather than a demonstrated exploit. The sequence is fully determined by the code:

1. Governance calls `setBondingCurveConfig` with `defaultCurveId` = the dynamic-fee curve's registry id. Accepted; no
   guard rejects it.
2. Any user calls `createAtoms`. `_createAtom` mints `sharesForReceiver` on that curve id via `_updateVaultOnCreation`.
   No `recordDeposit` fires, so `userStake[atomId][creator] == 0` on the curve.
3. The creator calls `redeem` for those shares. `_validateRedeem` passes — `balanceOf` is correct — and `quoteRedeemFee`
   returns a number via its no-stake fallback.
4. `_processRedeem` completes every vault-state write, then calls `_recordCurveRedeem`, which reverts at
   `userStake[termId][account] -= withdrawnStake` with `Panic(0x11)`.

Result: the creation-minted portion of every term created under that configuration is permanently unredeemable.

#### Recommendation

Assert the invariant on the setter — the cheapest fix and the one that matches the failure mode:

```solidity
address defaultCurve =
    IBondingCurveRegistry(_bondingCurveConfig.registry).curveAddresses(_bondingCurveConfig.defaultCurveId);
if (IBaseCurve(defaultCurve).hasDepositFeeHook() || IBaseCurve(defaultCurve).hasRedeemFeeHook()) {
    revert MultiVault_DefaultCurveMustBeHookless();
}
```

Alternatively, route the creation paths through the hook exactly as `_processDeposit` does, which removes the coupling
entirely and is the more durable fix if a hook curve is ever intended to become the default.

#### Regression test

`DefaultCurveHooklessInvariant.t.sol` — assert `setBondingCurveConfig` reverts when the nominated default curve
advertises either hook, and that a create-then-redeem round trip on the default curve completes.

#### Variant sweep

| Path                                  | Result                                   |
| ------------------------------------- | ---------------------------------------- |
| `createAtoms` / `createTriples`       | Same gap                                 |
| `createAtomsFor` / `createTriplesFor` | Same gap                                 |
| `deposit` / `depositBatch`            | Safe — hook always invoked at `:771`     |
| Redeem                                | Where the gap detonates                  |
| Router (`FeeProxy` create routes)     | Same gap, inherited                      |
| Upgrade-initializer                   | n/a — the hazard is a post-deploy setter |

---

### R2-PAS-04 — A per-tier fee override survives a cap tightening and is read back unclamped — **Medium**

**Invariant broken:** §5.4 (flat-price par — a holder's maximum loss is the fee they paid). **Cluster:** C1.
**Confidence:** High. **Status:** Open.

#### Description

`setTierFeeOverride` enforces the schedule's caps **once, at write time**. The read path applies no bound at all: the
`isSet` branch returns the stored rate verbatim and returns _before_ the cap clamp, which is applied only on the
formulaic branch. `_setConfig` validates the incoming struct against itself and never revisits the sparse
`tierFeeOverride` rows.

So an override written under a permissive cap survives a later `setConfig` that **lowers** that cap — an operator action
whose entire purpose is to tighten the envelope. The override then exceeds the live cap, directly contradicting the
contract's own NatSpec, which states that an override "retunes a tier's rate inside the same envelope the formula
respects, it does not bypass the cap", and which explicitly names bricked redeems as the reason the bound matters.

This is a privileged trigger, but it is reported because the guard **fails open on a tightening action** — the
operator's intent and the code's effect are opposite — and the resulting state is not recoverable by affected users.

#### Code

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:265-273` — bounded once, at write time:

```solidity
if (newDepositFeeBps > config.depositCapBps || newWithdrawalFeeBps > config.withdrawalCapBps) {
    revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
}
```

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:851-859` — read back unclamped:

```solidity
if (tierOverride.isSet) {
    return tierOverride.withdrawalFeeBps;                   // no cap applied on this branch
}
uint256 fee = config.withdrawalBaseBps + tier * config.withdrawalGrowthBps;
uint256 cap = config.withdrawalCapBps;
return fee < cap ? fee : cap;                               // cap applies only to the formula
```

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:875-911` (`_setConfig` never iterates `tierFeeOverride`);
`src/libraries/MultiVaultLib.sol:1067` (the unguarded subtraction that panics).

#### Proof of concept

Not executed; hand-traced integer arithmetic with `protocolFee = 100` bps and `exitFee = 500` bps.

1. With `config.withdrawalCapBps = 10_000`, call `setTierFeeOverride(3, 0, 10_000)` — accepted, since
   `10_000 <= 10_000`.
2. Call `setConfig` with `withdrawalBaseBps = 100`, `withdrawalCapBps = 300` — accepted, since `100 <= 300 <= BPS`.
   Overrides are untouched.
3. `_withdrawalFeeBps(3)` now returns `10_000`, not `min(300, 100) == 100`.
4. A holder bucketed at tier 3 redeems 100 TRUST at par:
   - `hook.fee = mulDivUp(100e18, 10_000, 10_000) = 100e18`
   - `protocolFee = 1e18`, `exitFee = 5e18`
   - `assetsAfterFees = 100e18 - 1e18 - 5e18 - 100e18` → **underflow, `Panic(0x11)`**

The result is scale-invariant: `hook.fee == assets` for any share count, so there is no partial-exit escape. The revert
fires inside `_validateRedeem` as a bare panic rather than a named error, and it blocks `redeemBatch` wholesale.

#### Recommendation

Apply the cap on the override branch so the envelope holds by construction under any retune:

```solidity
if (tierOverride.isSet) {
    uint256 overrideFee = tierOverride.withdrawalFeeBps;
    uint256 cap = config.withdrawalCapBps;
    return overrideFee < cap ? overrideFee : cap;
}
```

Mirror the change in `_depositFeeBps`. Optionally emit an event when a retune clamps a live override, so operators can
see it.

#### Regression test

`TierOverrideCapEnvelope.t.sol` — set an override at a permissive cap, lower the cap via `setConfig`, and assert the
effective rate is clamped to the new cap and that redeems still succeed.

#### Variant sweep

| Path                | Result                                                                                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single redeem       | Same bug                                                                                                                                                   |
| `redeemBatch`       | Same bug — whole batch panics                                                                                                                              |
| On-behalf-of        | Same bug                                                                                                                                                   |
| Preview             | **Diverges** — the preview path takes the no-account tier fallback, so it returns a healthy number while the real redeem panics (compounds with R2-PAS-05) |
| Router (`FeeProxy`) | n/a — no redeem surface                                                                                                                                    |
| Upgrade-initializer | Same bug — `initialize` routes through the same `_setConfig`                                                                                               |

---

### R2-PAS-05 — `previewRedeem` prices the curve withdrawal fee at the vault's tier, not the holder's — **Minor**

**Invariant broken:** §5.4 (the quoted fee must be the charged fee). **Cluster:** C1 / C2. **Confidence:** High.
**Status:** Open.

#### Description

The account-less preview mirror passes `address(0)` as the account. `quoteRedeemFee` branches on the account's tracked
stake, so `address(0)` — which never has stake — falls back to pricing at `_tierOf(vaultAssets[termId])`, the
**vault's** current tier. The real redeem path passes the actual receiver and prices at that holder's own `userTier`.

These diverge for any holder whose bucket differs from the vault's current tier — which is the normal state of any vault
that has moved a tier since the holder entered, i.e. precisely the cohort the tier system exists to price differently.
The divergence is not dust: it is the full spread of the withdrawal schedule.

The practical consequence is that a user who does the documented thing — read `previewRedeem`, pass it as `minAssets` —
can be rejected by the slippage check, because `_validateRedeem` re-computes with the real account and the real, higher
fee. The redeem reverts until the user hand-computes the correct rate or passes `minAssets = 0`, giving up slippage
protection.

#### Code

`src/libraries/MultiVaultLib.sol:443`:

```solidity
(assetsAfterFees, sharesUsed,) = _calculateRedeem(termId, curveId, shares, address(0));
```

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:327`:

```solidity
uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultAssets[termId]);
```

Contrast `src/libraries/MultiVaultLib.sol:794` and `:1389`, which both pass the real `receiver`.

#### Proof of concept

Hand-traced with `withdrawalBaseBps = 100`, `withdrawalGrowthBps = 100`, `withdrawalCapBps = 2000`.

Under-report case: the vault has grown to tier 10; an early holder is bucketed at tier 1 and redeems 100 TRUST at par.
Preview prices at tier 10 → 1100 bps → fee 11 TRUST. The actual redeem prices at tier 1 → 200 bps → fee 2 TRUST. Preview
under-reports the payout by 9 TRUST.

Blocking case: the vault shrinks to tier 1 while a late holder sits at tier 10. Preview says fee 2 TRUST; the real fee
is 11 TRUST. A `minAssets` derived from the preview exceeds the real `expectedAssets` by 9 TRUST, so `_validateRedeem`
reverts with `MultiVault_SlippageExceeded` on every attempt.

#### Recommendation

Add an account-taking preview — `previewRedeemFor(termId, curveId, shares, account)` — and have
`MultiVault.previewRedeem` default the account to `msg.sender`, so the preview and the execution key on the same tier.
If the account-less form must be retained for integrators, document plainly that its curve fee component is a vault-tier
approximation, not a quote.

#### Regression test

`RedeemPreviewTierParity.t.sol` — for a holder whose bucket differs from the vault tier, assert the preview payout
equals the executed payout.

#### Variant sweep

| Path                 | Result                                                   |
| -------------------- | -------------------------------------------------------- |
| Single redeem        | Same bug                                                 |
| `redeemBatch`        | Same bug                                                 |
| On-behalf-of         | Worse — neither preview form reports the receiver's rate |
| Deposit-side preview | Safe — both quote sites use the same base                |
| Router (`FeeProxy`)  | n/a — no redeem surface                                  |

---

### R2-PAS-06 — The quote-then-record fee-parity guarantee has no gating test — **Minor**

**Invariant broken:** §5.1 (conservation of value) — as a coverage gap, not a live defect. **Cluster:** C2.
**Confidence:** High. **Status:** Open.

#### Description

Quote-then-record equality is the load-bearing property of the entire standardized hook surface: the fee netted from the
depositor during calculation must equal the native value forwarded to the curve after the vault's state writes. At the
reviewed commit this holds **by dataflow** — the `CurveHook` struct carries the decision and the quote from the
calculation site to the record site, and the record helper forwards `hook.fee` verbatim without re-resolving or
re-quoting. That construction is correct, and the NatSpec describing it is accurate.

The problem is that **nothing tests it.** This round measured the blast radius directly: with the parity guarantee
removed — the record helper re-quoting on the post-fee share amount instead of forwarding the carried value — the entire
dynamic-fee suite still passes. Twenty-eight of twenty-eight tests green, including `invariant_curveIsAlwaysSolvent`,
`invariant_ledgerMirrorsVaultShares`, `invariant_flatPriceStays1to1`, and two 10,000-run fuzz solvency tests.

The suite is blind because the failure mode is a _surplus_ stranded in `MultiVault`: the curve stays solvent, the share
ledger is unaffected, and par is unaffected. No existing assertion compares the withheld fee against the forwarded fee.
Under a representative configuration the removed guarantee costs roughly **4–6% of every dynamic-curve deposit fee**,
permanently stranded in `MultiVault` and reachable by no code path.

A property this load-bearing on a brand-new funds-touching surface should not depend on nobody editing one line.

#### Code

`src/libraries/MultiVaultLib.sol:851-856` — correct at the reviewed commit:

```solidity
function _recordCurveDeposit(bytes32 termId, address receiver, CurveHook memory hook, uint256 sharesForReceiver)
    private
{
    if (hook.curve == address(0)) return;
    IBaseCurve(hook.curve).recordDeposit{ value: hook.fee }(termId, receiver, sharesForReceiver);
}
```

Withholding sites: `src/libraries/MultiVaultLib.sol:961` and `:1023`. Redeem mirror: `:864`.

#### Proof of concept

Not applicable — no defect at the reviewed commit. The coverage gap was established by mutation: replacing the carried
forward with a re-quote on `sharesForReceiver` and re-running
`tests/unit/MultiVault/DynamicFee{CurveRouting,Invariant,AdversarialEconomics,GasProfile}.t.sol` produced 28 passes and
0 failures.

#### Recommendation

Add an explicit parity assertion. The cheapest form is a test that captures the fee withheld during calculation and
asserts it equals the curve's native balance delta across one dynamic-curve deposit, plus a full conservation sum over
`MultiVault`'s native balance versus its booked ledgers (`accumulatedProtocolFees`, `accumulatedAtomWalletDepositFees`,
and both vaults' `totalAssets`). Extend the existing invariant suite with the conservation form so it is enforced
continuously rather than at a single point.

#### Regression test

`DynamicFeeQuoteRecordParity.t.sol` — assert `curve.balance` delta equals the fee netted from the depositor on deposit,
and that `MultiVault`'s native balance delta is fully attributable to booked ledgers.

#### Variant sweep

Applies to the deposit path (single, batch, on-behalf-of, router). The redeem path forwards the carried quote
identically and is equally untested.

---

### R2-PAS-07 — Curve fee caps are validated in isolation, never against MultiVault's own fee schedule — **Minor**

**Invariant broken:** §5.4. **Cluster:** C1 / C2. **Confidence:** High. **Status:** Open.

#### Description

`_setConfig` bounds `depositCapBps` and `withdrawalCapBps` each independently at `BPS`, and `setTierFeeOverride`
re-checks against the same caps. Nothing on either side bounds the **sum** of the curve fee and MultiVault's own
`protocolFee` + `entryFee` / `exitFee` + `atomWalletDepositFee`. The vault then performs bare checked subtractions.

The curve cannot see MultiVault's fees and the vault does not check the curve's, so the real ceiling is not `BPS` — it
is `BPS - (protocolFee + exitFee)`, a number neither contract validates. A configuration well inside its declared
envelope can therefore brick deposits or redeems for an entire tier, with a bare `Panic(0x11)` rather than a named
error. The curve's own NatSpec flags the `BPS`-level case as known; what is unflagged is that the true threshold is
materially lower.

Shipped defaults (curve cap 1000 bps) are safe with margin.

#### Code

`src/libraries/MultiVaultLib.sol:1067`, `:962`, `:1024`; `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:891-896`.

#### Recommendation

Introduce an explicit aggregate bound. Either have `MultiVault` expose its total fee load so the curve can validate
against it in `_setConfig`, or add a named error to the vault's subtraction sites so an over-configured schedule fails
with a diagnosable revert instead of a panic.

#### Regression test

`FeeScheduleAggregateBound.t.sol` — assert that a curve cap plus the live vault fees cannot exceed 100%, and that
exceeding it produces a named error.

---

### R2-PAS-08 — `claimable(account, termId)` folds a cross-vault balance into a per-term view — **Minor**

**Invariant broken:** n/a — view/integration correctness. **Cluster:** C1. **Confidence:** High. **Status:** Open.

#### Description

`earned` is a **cross-vault** accumulator, documented as such. `claimable(account, termId)` returns
`earned[account] + pending`, so any caller that iterates a user's terms and sums the result — the natural reading of a
`(account, termId)` signature, and what a dashboard or router computing "total claimable" will do — over-reports by
`(N - 1) × earned`. `claim` itself pays `earned` exactly once regardless of how many `termIds` are passed, so no
on-chain value is at risk.

With `earned = 10 TRUST`, `pending(T1) = 1`, `pending(T2) = 2`: summing the view yields 23 TRUST while `claim` pays 13
TRUST — a 77% over-report that grows linearly in the number of terms queried.

#### Code

`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:483-492`, `:148`, `:470-473`.

#### Recommendation

Split the surface: return only the per-term `pending` from the per-term view, and expose the booked cross-vault balance
through the existing `earned(address)` getter — or add an explicit `totalClaimable(address, bytes32[])` that sums
correctly. Either way, no caller should be able to sum an already-global term.

#### Regression test

`CurveClaimableAggregation.t.sol` — assert that summing the per-term view across a user's terms equals what `claim`
actually pays.

---

### R2-PAS-09 — `_creditByWeight` books slices as assigned when the accumulator increment floors to zero — **Informational**

**Cluster:** C1. **Confidence:** High. **Status:** Open.

`assigned += share` executes whenever `share > 0`, including when `share.fullMulDiv(ACC_PRECISION, stakes[d - 1])`
floors to zero (i.e. `stakes > share × 1e18`). Those wei are counted as distributed, so they are excluded from
`unassigned` and never reach `protocolAccrued` — they accrete as unattributed contract balance instead.

This is the accepted MasterChef sub-wei dust class and is bounded absolutely: the per-credit loss is `stakes / 1e18`, at
most ~1 gwei per credit for the entire plausible TRUST supply in a single tier, with at most 63 credits per record hook.
Multiple lenses attempted to compound it into a solvency or conservation break and could not.

It is reported only because the code has an explicit "never silently forfeit" remainder path that this branch bypasses,
so the leak is not where the NatSpec says it is. `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:644-656`, `:627-631`.

**Recommendation:** only count `share` toward `assigned` when the accumulator actually moved, so the shortfall flows to
`protocolAccrued` as documented.

---

### R2-PAS-10 — Reentrancy-guard asymmetry across the curve's write surface — **Informational**

**Cluster:** C1 / C2. **Confidence:** Medium. **Status:** Open.

`claim` and `sweepProtocol` carry `nonReentrant`; `recordDeposit` and `recordRedeem` carry only `onlyMultiVault`.
`Address.sendValue` in `claim` forwards all gas, so a claiming contract regains control while the curve's guard is held,
and can re-enter `MultiVault.deposit` — a separate guard — reaching `recordDeposit` from inside an in-flight `claim`.

Multiple lenses traced this and none converted it into a loss: `claim` is strict CEI (`earned` is zeroed before the
send, only an event follows), `sweepProtocol` likewise, and every curve state write completes before the send. A
re-entrant `_settle` therefore books a genuinely new credit rather than replaying an old one.

Reported as a guard asymmetry rather than a live defect: the safety currently rests on statement ordering inside
`claim`, and a future reordering or a third value-moving site would make the window load-bearing.
`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:339`, `:401-406`, `:459`, `:285`.

**Recommendation:** add `nonReentrant` to both record hooks so the curve's whole write surface shares one guard.

---

### R2-PAS-11 — `_setConfig` does not validate the fee growth parameters — **Informational**

**Cluster:** C1. **Confidence:** High. **Status:** Open.

`_setConfig` validates `width0`, `tierCount`, `growthGBps`, `fulcrumAlpha`, `kernelSpread`, both base/cap pairs, and
both share-bps fields — but never `depositGrowthBps` or `withdrawalGrowthBps`, the only config members reaching an
unbounded-magnitude multiplication in `config.depositBaseBps + tier * config.depositGrowthBps`.

A growth value above roughly `type(uint256).max / 63` makes that multiplication revert for every `tier >= 1`, bricking
deposits and redeems the moment the vault leaves tier 0. The top-edge probe does not exercise the fee formula, so
`_setConfig` accepts it. Checked arithmetic means denial of service rather than a wrapped-small fee. Trigger is
admin-only. `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:816`, `:856`, `:875-899`.

**Recommendation:** bound both growth parameters such that `base + (tierCount - 1) * growth` cannot overflow, and extend
the config-time probe to evaluate the fee formula at the top tier.

---

### R2-PAS-12 — `FeeProxy._allocate` floors a small leg to zero and self-DoSes the batch — **Informational**

**Cluster:** G. **Confidence:** High. **Status:** Open.

`_sum` rejects zero legs specifically so that "the proportional `_allocate` step cannot starve nonzero legs by shipping
the rounding dust to a zero-gross slot" — but the proportional computation still floors a small leg beside a large one
to zero. With `assets = [1, 1e18]` and a 1% fee, the first leg's piece computes to 0, and `MultiVault`'s minimum-deposit
validation then reverts the whole batch.

ETH conservation is intact — the last leg absorbs the dust and the per-leg sum equals the total forwarded exactly. The
impact is liveness on a caller's own batch, so it is self-inflicted; it is reported because the stated purpose of the
zero-leg guard is not achieved. `src/periphery/FeeProxy.sol:741-759`, `:723-735`.

**Recommendation:** either floor each allocated piece at the minimum deposit and reject the batch early with a named
error, or document that lopsided batches are unsupported.

---

### R2-PAS-13 — Under the shipped schedule, small vaults route all deposit fees to the protocol bucket — **Informational**

**Cluster:** C1. **Confidence:** High. **Status:** Open.

`_payRecentTiers` short-circuits to `protocolAccrued` when `span == 0`, i.e. whenever the vault sits in tier 0 and there
are no prior tiers to reward. With the shipped `width0`, every vault below the first tier edge therefore routes **100%
of its deposit fees to the protocol bucket** rather than redistributing them. By count, that is likely the overwhelming
majority of terms.

This is not a code defect — the branch is correct and the fee has a defined home — but it is an economic property of the
shipped configuration that the redistribution narrative does not describe. Flagged for the mechanics lock.
`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:605-610`.

**Recommendation:** confirm this is intended, and if so document it; if not, consider a smaller first-tier width or
crediting tier 0 holders when no prior tier exists.

---

### R2-PAS-14 — `tierWidthAt` reports a finite width for the unbounded top band — **Informational**

**Cluster:** C1. **Confidence:** High. **Status:** Open.

The NatSpec asserts the width view "equal[s] the fee-charged band by construction". That holds for every tier below the
top, but `_tierOf` caps at `tierCount - 1`, so the top tier's charged band is `[edge(top-1), ∞)` while
`tierWidthAt(top)` reports the finite `edge(top) - edge(top-1)`.

The fee math itself is correct — top-tier absorption is the intended design and the piecewise walk never consults the
top edge — so this is a view/spec inconsistency only. `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:725-739`,
`:752-763`, `:504-507`.

**Recommendation:** document the top-tier exception in the NatSpec, or return a sentinel for the top band.

---

### R2-PAS-15 — Stacked round-up fee terms newly brick dust redeems with an unnamed panic — **Informational**

**Cluster:** C2 / Δ. **Confidence:** High. **Status:** Open.

Four fee terms now stack on the redeem path, all rounding up: `protocolFee`, `exitFee`, and — new in v1.1.0 — the
curve's `hook.fee`. The subtraction is checked, so the ceilings can push it negative. At `assets = 2` wei with
`protocolFee = 100` bps, `exitFee = 500` bps and a 100 bps curve fee, each term ceils to 1 and `2 - 1 - 1 - 1` panics;
pre-upgrade the same redeem computed `2 - 1 - 1 = 0` and succeeded.

The magnitude is a handful of wei at sane rates and the harm is self-inflicted, so this does not escalate past griefing
one's own dust. It is reported because the v1.1.0 hook shifts the minimum-redeemable threshold upward and turns the
failure into a bare `Panic(0x11)` inside `_validateRedeem` rather than a named error.
`src/libraries/MultiVaultLib.sol:1056-1068`.

**Recommendation:** add a named error for the over-subtracted case so the condition is diagnosable.

---

### R2-PAS-17 — Hook advertisement is read per-path with no cross-path consistency check — **Informational**

**Cluster:** C2. **Confidence:** Medium. **Status:** Open.

The deposit and redeem hook resolvers each consult the curve's _own_ getter independently and live, once per path. A
registered curve that answers `true` on the deposit getter but `false` on the redeem getter — statically, or by changing
its answer after registration — would accumulate `userStake` on every deposit that is never decremented on redeem,
permanently overstating its ledger and eventually underflowing every distribution denominator.

The shipped curve is immune: both getters are `pure` and return `true`, so they cannot diverge or flip. Registration is
`onlyOwner` and `curveAddresses` is write-once, so reaching the state requires registering a curve that advertises
asymmetrically. This is therefore a vetting-process dependency rather than a live defect, and it is recorded because the
dispatch places unchecked trust in a per-path boolean from a registry-resolved address.
`src/libraries/MultiVaultLib.sol:832-843`, `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:299-306`.

**Recommendation:** assert deposit/redeem hook symmetry once at registration in `BondingCurveRegistry`, so a curve
cannot be registered advertising one hook without the other, and the vault's per-path reads can never disagree.

---

## 6. Properties checked (negatives)

Every line below is a property that was attacked and held. Per the engagement mandate, a `PASS` without a recorded
refutation attempt is not a `PASS`; each entry names what was tried and the guard that defeated it.

### 6.1 Landed fixes — verified and mutation-checked

Both fixes that landed since the prior round were confirmed present at the reviewed commit, attacked in their new form,
and then **mutation-checked** by neutering the guard and re-running its gating tests.

**ERC-1271 digest binding.** `PASS`. The validated digest is wrapped through
`CoinbaseSmartWalletLib.replaySafeHash(hash, "AtomWallet", "1")` at `src/protocol/wallet/AtomWallet.sol:335-342`, whose
EIP-712 domain commits to both `block.chainid` and `address(this)` (`src/libraries/CoinbaseSmartWalletLib.sol:311-321`).
Attacks attempted against the _new_ construction:

- Cross-wallet and cross-chain replay of a signature valid on a sibling wallet — defeated by the domain binding; the
  domain name and version are `private constant`, so there is no setter to grind.
- Crossing the ERC-4337 and ERC-1271 paths in both directions — defeated by disjoint prefixes: `_validateSignature`
  hashes `"\x19Ethereum Signed Message:\n32" || userOpHash`, the 1271 path hashes
  `"\x19\x01" || domainSeparator || hashStruct`, and `userOpHash` independently commits to the account, chain id, and
  EntryPoint.
- The P-256/WebAuthn branch weakening the binding relative to ECDSA — defeated because both branches receive the same
  already-enveloped digest and the WebAuthn branch passes it through unmodified as the challenge, with no second hashing
  or truncation.
- Malformed signature wrappers (truncated buffer, `dataLen = type(uint256).max`, out-of-range ABI offset,
  `ownerIndex >= 1`) — defeated by four pre-decode length and offset checks in `CoinbaseSmartWalletLib`.

**Mutation check:** replacing the wrapping with the raw digest turns **11 tests red across three suites**, including the
dedicated `test_isValidSignature_rejectsCrossWalletReplay`, `test_isValidSignature_returnsSuccessAfterClaim`, and the
P-256 co-owner validation tests. The guard carries real coverage.

**Zero epoch length rejected.** `PASS`. `_validateEmissionsLength` at
`src/protocol/emissions/CoreEmissionsController.sol:129-131` is called unconditionally from the shared initializer at
`:54`. `_EPOCH_LENGTH` has exactly one write site, and there is no post-init setter anywhere in `src/`, so every
in-scope initialization path is covered. The analogous degenerate values are separately rejected:
`emissionsPerEpoch == 0`, `cliff == 0` or `> 365`, `reductionBps > 1000`, and a past start timestamp.

**Mutation check:** neutering the guard turns `test_initialize_revertsWhenEmissionsLengthIsZero` red on **both**
controllers (`tests/unit/CoreEmissionsController/Reads.t.sol` and
`tests/unit/SatelliteEmissionsController/AccessControl.t.sol`). The guard carries real coverage.

### 6.2 C1 — `DynamicFeeFlatPriceCurve` fee economy

- `PASS` — **Depositor exclusion from their own deposit fee.** Tried landing the post-deposit bucket on a prior tier
  receiving the spread, being the sole occupant of the nearest occupied prior tier, and splitting across tiers. Defended
  by the three-part construction: pre-distribution `_settle` at `:348-350`, `recipientStake -= excludeStake` in the
  recipient denominator at `:674-676` and `:802-804`, and the `rewardDebt` re-base against the post-distribution
  accumulator of the new tier at `:389`. Summing over the other holders recovers exactly the distributed share —
  exclusion is exact, not approximate. Verified for both `newTier == oldTier` and `newTier != oldTier`.
- `PASS` — **Exiter exclusion from their own withdrawal fee.** Tried a partial exit leaving a residual in a tier that is
  simultaneously the diamond recipient and a fulcrum recipient, hoping only one credit would be excluded. Defended by
  `denom = tierStake[exitTier] - residual` at `:424`, the same residual passed as `excludeStake` into `_payRecentTiers`
  at `:445`, and a single re-base at `:448` taken after both credits.
- `PASS` — **The whale-exit fallback cannot route back to the exiter.** Tried being the sole occupant of the exiting
  tier so `denom == 0`. Defended at `:769-786`, where the upward scan starts at `fromTier + 1` and the downward scan
  pre-decrements from `fromTier`, making the exiter's own bucket unreachable in both directions.
- `PASS` — **No fee slice is lost or double-booked.** Tried empty prior tiers, a window landing entirely in a gap, a
  `sigma` tight enough to zero every occupied weight, `span == 0`, and a rounding remainder. Every branch has exactly
  one sink: `:606-610` (protocol), `:621-624` → `_awardNearestOrProtocol` (itself falling through at `:716`), `:627-631`
  (remainder), and the unspikable recent-tier lump folding into the fulcrum pool at `:565` rather than being forfeited.
- `PASS` — **Curve solvency.** 30,000 randomized fuzz runs over deposit/redeem walks with six actors, tier counts from
  12 to 64, and both lump-slice parameters non-zero so every fallback fires, asserting
  `Σ claimable + protocolAccrued <= feesReceived` and `<= address(curve).balance` at every step. Never broke. Defended
  by uniformly floor-rounded accumulator writes at `:427`, `:436`, `:649`, `:714`.
- `PASS` — **Ledger mirror.** The same 30,000 runs asserted `Σ tierStake == Σ userStake == vaultAssets`. Never broke.
  Defended by the paired tier moves at `:376-390` and `:415-416`; all four `tierStake` mutation branches net to
  `+netStake`, matching the `vaultAssets` move exactly.
- `PASS` — **Retune with live positions cannot strand or reprice booked earnings.** Fuzzed `setConfig` mid-flight across
  a grown `tierCount`, re-priced `width0` / `growthGBps`, and moved `fulcrumAlpha` / `kernelSpread`, then kept
  transacting; total owed was bit-identical across the retune. Defended by `TierCountCannotShrink` at `:882-884`, the
  `_roundTier` cap at `:864`, and index-keyed accumulators that are never migrated.
- `PASS` — **`tierStake` exclusion cannot underflow.** Tried making `excludeStake` exceed the bucket it is subtracted
  from at `:675` and `:803`. Defended because `recordDeposit` passes the caller's own `oldStake` (a subset of
  `tierStake[oldTier]` by construction) and `recordRedeem` passes the residual only after `tierStake[exitTier]` has
  already been decremented at `:416`.
- `PASS` — **Accumulator inflation via a dust-stake tier cannot over-pay a later joiner.** Tried crediting a fee against
  a denominator of 1 to drive `accFeePerShare` to extreme values, then moving a large stake into that bucket. Defended
  because the mover's `rewardDebt` is re-based in the same call that adds them to `tierStake` at `:389`, so their first
  settle yields zero. Reaching a `fullMulDiv` overflow would require roughly 26 orders of magnitude more fee volume than
  exists.
- `PASS` — **A fat-fingered schedule cannot brick `tierOf` on the hot path.** Tried an over-steep ladder
  (`growthGBps = 100 × BPS`, `tierCount = 64`) that overflows `rpow`. Defended by the config-time top-edge probe at
  `:906`, which executes the same checked math and reverts before any position exists; the probe is _sufficient_ because
  `_tierUpperEdge` is monotone in `k` and `edge(0) == width0` exactly. The `g == 0` branch is bounded by
  `width0 <= type(uint128).max` and `k + 1 <= 64`.
- `PASS` — **`_piecewiseDepositFee` cannot loop unboundedly or spin on a zero-width band.** Tried `startAssets` exactly
  on a tier edge, above the top edge, and `tierCount == 1`. Defended because `_tierOf` returns the first tier whose
  upper edge strictly exceeds the cursor, so room is positive on entry, edges are strictly increasing, and the
  `tier < topTier` guard makes the top band absorb the remainder — bounding the walk at `tierCount <= 64`.
- `PASS` — **`claim` cannot double-spend via duplicate term ids.** Tried `claim([X, X])`. Defended because the first
  `_settle` writes `rewardDebt = accumulated` at `:537`, so the second pass computes a zero delta.
- `PASS` — **Reentrancy through the claim payout cannot steal or strand earnings.** Tried re-entering `claim` and
  `sweepProtocol` (both `nonReentrant`), and re-entering `MultiVault.deposit` from the payee's receive hook to reach the
  unguarded `recordDeposit`. Defended because `earned[msg.sender] = 0` precedes `Address.sendValue` at `:473-474`, so a
  re-entrant settle books a genuinely new credit rather than replaying the old one. (Recorded as a guard asymmetry in
  R2-PAS-10.)
- `PASS` — **Principal never sits in the curve.** Every `msg.value` the curve can receive arrives through the two
  `onlyMultiVault` record hooks, both funded exclusively by the vault's quoted fee. There is no `receive()` or
  `fallback()`, and the only outflows are `claim` (bounded by `earned`) and `sweepProtocol` (bounded by
  `protocolAccrued`).
- `PASS` — **Flat-price par: max loss is the fees paid.** Tried extracting net-positive across deposit/redeem cycles.
  Defended by floor rounding on both sides of `LinearCurve` and by the fact that the dynamic vault is pinned at exactly
  1:1 — all pro-rata fee donations are routed to the default curve's vault, never to a non-default curve, so nothing
  adds assets without minting shares.
- `PASS` — **The deposit-side mirror of the exit-fee front-run is not profitable.** This is the bound on R2-PAS-16.
  Tried the equivalent attack against the deposit distribution: front-run a large deposit to become the kernel's nearest
  prior tier and capture its weighted slice. Structurally defended, because a new depositor's bucket is
  `_tierOf(vaultAssets)` evaluated _before_ their own deposit and deposit fees go only to strictly prior tiers — so the
  fresh position is outside its own distribution by construction. Becoming the nearest prior tier requires sizing the
  front-run to cross a band edge, which costs real capital rather than dust. Measured: 2307 bps captured, net profit
  **−54004883178673808 wei (a loss)**, with the honest tier-0 cohort retaining 5770 bps. The withdrawal side has no
  equivalent structural defense, which is why R2-PAS-16 is scoped to it.
- `PASS` — **A whale cannot round-trip deposit → redeem for a net gain against honest holders.** Flat price returns
  principal at par, and both distribution paths exclude the paying party from every recipient denominator, so a
  single-identity sequence is strictly loss-making by the fees paid. The profitable construction requires a _second_
  identity positioned in the recipient bucket — filed as R2-PAS-02 and R2-PAS-16.
- `PASS` — **No division by zero in any distribution branch.** Enumerated all five credit sites; each is gated on a
  positive stake or a positive weight that is only set when the stake is positive.
- `PASS` — **The counter-triple vault initialization does not desync the curve ledger.** This was the strongest
  candidate for a _permissionless_ ledger break — a share mint on a non-default curve outside the deposit path. It mints
  only to the burn address, which never redeems. Defended.
- `PASS` — **`userAvgTier` rounding cannot drift a holder across a bucket boundary.** Tried compounding the documented
  sub-wei-tier under-rounding at `:371-372`. The error is re-scaled by a factor below 1 on each subsequent deposit, so
  it decays rather than accumulating; shifting a half-up boundary would require on the order of 2.5×10¹⁷ deposits. The
  zero-`netStake` case is exactly idempotent.

### 6.3 C2 — hook surface and dispatch

- `PASS` — **Quote-then-record equality holds by construction on both paths.** Tried to force netted ≠ forwarded by
  making the quote state-dependent, mutating vault state between calculation and record, and hitting the same term twice
  in a batch. Defended by the `CurveHook` struct carrying the decision and the quote from `:961` / `:1023` / `:1064` to
  `:855` / `:864`, with no re-resolution or re-quote after the vault-state writes. (Untested — see R2-PAS-06.)
- `PASS` — **The two distinct deposit quote sites agree.** Compared the atom and triple calculators
  statement-by-statement. Their MultiVault fee stacks differ and their min-share deductions differ (1× vs 2×), but both
  apply those _before_ quoting, both quote on the same variable `assetsAfterMinSharesCost`, and both subtract the result
  identically. No atom-vs-triple asymmetry.
- `PASS` — **A curve that lies about or flips its hook getters cannot desync quote from record.** Tried returning `true`
  at calculation time and `false` at record time, and a reverting quote. Defended because the decision is resolved once
  into `hook.curve` at `:960` / `:1022` and the record path branches only on the carried address; a reverting quote
  fails the whole deposit before any state write — fails closed. Both getters are `view`, so they compile to
  `STATICCALL` and cannot mutate state mid-transaction.
- `PASS` — **Hookless curves are exact no-ops, byte-identical to pre-upgrade.** `LinearCurve`, `ProgressiveCurve` and
  `OffsetProgressiveCurve` override none of the six hook members, so `BaseCurve`'s `false` defaults at `:153-160` make
  the resolvers return `address(0)`, `hook.fee` stays zero, no subtraction runs, and both record helpers early-return.
  The four reverting `BaseCurve` bodies are unreachable from the vault.
- `PASS` — **An unregistered or out-of-range curve id fails closed with the canonical error.** Tried `curveId = 0` and
  beyond the registered count. Defended by the explicit `curve == address(0)` short-circuit ordered _before_ the hook
  getter at `:834` / `:841`, so `BondingCurveRegistry_InvalidCurveId` still surfaces from the pricing call rather than a
  bare call-to-codeless-account revert.
- `PASS` — **A registered curve cannot be swapped or re-pointed under live positions.** Searched the registry for any
  write to `curveAddresses` outside registration, any removal/replacement path, and any non-owner registration route.
  The only writer is `addBondingCurve`, which is `onlyOwner`, rejects an already-registered address, and only ever
  assigns a fresh incrementing index. `curveAddresses[id]` is write-once.
- `PASS` — **The redeem-path curve account is the share owner, not a substitutable payee.** Tried getting `recordRedeem`
  to decrement a different account than the one whose shares were burned. Validation, burn, record, and payout all use
  the same receiver; the third-party caller is gated separately by the redeem approval check.
- `PASS` — **The min-share seed does not desynchronize the ledger.** The seed is minted to the burn address without a
  hook call, so the curve correctly never sees it, and the remaining-shares floor makes it permanently unwithdrawable —
  exactly the "net of the min-share seed" carve-out the invariant allows.

### 6.4 Cluster A — `multicallPayable` value accounting

- `PASS` — **No wei is double-spent across legs.** Tried `sum(values) != msg.value` in both directions; rejected
  pre-loop before any dispatch. Each create/batch leg additionally re-checks that its payment equals the sum of its
  assets.
- `PASS` — **A re-entrant leg cannot claim virtualized value it never sent.** Tried re-entering an allowlisted payable
  entry point from inside a leg — via the curve record hook and via a payout callback — while the virtual value was
  still set, which would credit the reentrant call another leg's allocation. Defended because all six allowlisted
  selectors are `nonReentrant` and the outer leg still holds the guard.
- `PASS` — **Nested multicalls are rejected.** Tried both multicall selectors as a leg, in both directions. Rejected
  twice over: by the selector allowlist pre-loop and by the in-multicall guard.
- `PASS` — **Transient state is cleared on every exit path.** Tried leaving the in-multicall flag set via a caught
  revert. There is no `try`/`catch` on either path — a failing leg bubbles raw revert data and unwinds the frame, so
  EIP-1153 transient storage rolls back with the transaction.
- `PASS` — **No allowlisted leg reads raw `msg.value`.** Verified all six forward `_effectiveMsgValue()` individually.
  Canonical `multicall` forces the virtual value to zero, so a payable leg composed there fails the minimum-deposit
  check rather than claiming phantom value.
- `PASS` — **Length skew and short calldata.** Rejected at the length equality check and the four-byte selector check
  respectively.
- `PASS` — **The wallet factory is not a post-write re-entry point.** Traced whether the deposit/create path ever calls
  the factory's deploy function; it does not — only the `view` address computation is reached, so there is no deployment
  callback in the write path at all.

### 6.5 Cluster B — storage-mirror integrity

- `PASS` — **The delegatecalled library's storage view is byte-exact with the vault's layout.** Verified by executing
  `forge inspect MultiVault storage-layout` and comparing slot-by-slot against the library's `Storage` struct: exact
  match across all entries, from slot 0 through the newer tail fields (creation attribution, rollover guard, timelock),
  including the packing-derived struct spans and the trailing gap. Field _names_ differ between the two; slot positions
  do not.

### 6.6 Cluster D — `AtomWarden` quorum and window cap

- `PASS` — **Signature duplication cannot fake a quorum.** Tried repeating one valid signature to meet the threshold;
  defeated by the strictly-ascending recovered-address check, which enforces distinctness in O(1).
- `PASS` — **Authorization replay.** The nonce is burned before the external call and the caller is bound to the
  authorization's claimant, so re-entry via a malicious wallet cannot replay.
- `PASS` — **A window-length retune does not grant fresh budget mid-window.** Tried resetting the counter via the window
  setter; the retune re-anchors the window id but deliberately preserves the in-window count.
- `PASS` — **Invalid claims cannot burn window budget.** Budget consumption is ordered after quorum verification.
- `PASS` — **A threshold above the live signer set cannot be installed post-bootstrap.**
- `PASS` — **ERC-1271 contract signers in the quorum.** The quorum path recovers ECDSA only, so a contract signer
  holding the signer role can never satisfy it. This is a capability gate that fails closed, matching a known accepted
  disposition — recorded as a negative, not filed.

### 6.7 Cluster E — `AtomWallet` authorization

- `PASS` — **Pre-claim wallets accept no signature and expose no signer-management surface.** The owner registry is
  empty until the claim completes, so every ownership check fails for every external caller and the library returns
  false on an empty owner record — no user operation can validate to reach execution either.
- `PASS` — **The claim cannot be re-run or collapse the pre/post-claim distinction.** Gated by the warden-only modifier,
  an already-claimed guard, and an explicit rejection of the warden as claimant.
- `PASS` — **The primary owner cannot be orphaned.** Index-based removal refuses to remove the current owner, renouncing
  reverts, and the ownership transfer keeps the owner count constant while tolerating an already-registered incoming
  owner.
- `PASS` — **Owner rotation under warden replacement.** Post-claim ownership reads an immutable claimant slot, so a
  vault-side warden swap cannot re-take a claimed wallet.

### 6.8 Cluster F — `TrustBonding`

- `PASS` — **Claims stay within the per-epoch emissions budget.** Tried over-claiming via a large voting-escrow share;
  capped by the remaining-budget computation with the per-epoch claimed total as the ledger.
- `PASS` — **A past epoch's budget cannot be moved after the fact.** The epoch's emissions depend only on utilization
  recorded for prior epochs, and both the utilization add and the rollover write only the current epoch.
- `PASS` — **Double-claim for the same epoch.** Blocked by the per-epoch claim flag; the budget cap cannot drive a
  recorded claim to zero because an already-claimed amount at or above the budget reverts first.
- `PASS` — **The pause asymmetry does not trap funds.** Every lock-taking entry point is pause-gated while `withdraw`
  and `checkpoint` deliberately are not — matching a known accepted disposition.

### 6.9 Cluster G — `FeeProxy`

- `PASS` — **ETH conservation across every routing entry point.** Tried making fee + forwarded + refund diverge from
  `msg.value` on the single, batch, and both creation paths. Defended by the uniform construction and by the allocation
  step assigning all rounding dust to the last leg, so the per-leg sum equals the total forwarded exactly — which is
  what the vault's payment equality demands.
- `PASS` — **The refund ledger resists double-claim, claim-after-push, and cross-user attribution.** Tried claiming
  twice, claiming after a successful push, and routing another user's balance out. Defended by crediting the ledger only
  when the push actually failed, zeroing before the transfer under the reentrancy guard, keying every credit and debit
  on the caller, and rejecting the proxy itself as a refund recipient so a claim cannot round-trip into its own receive
  hook.
- `PASS` — **Value cannot be routed onto a receiver who never approved it.** Deposit receivers require both a
  proxy-to-receiver and, for delegation, a caller-to-receiver approval; creation creators are bound to the caller at the
  call site.
- `PASS` — **A pause cannot trap a refund.** The claim entry points carry only the reentrancy guard, not the pause
  modifier, so the pull escape hatch stays open under both pause surfaces.
- `PASS` — **Partial-batch reverts cannot desync the ledger from the vault.** The affiliate payment, the vault call, and
  the refund are in the same frame, so a leg revert unwinds all of it.

### 6.10 Cluster H — emissions controllers

- `PASS` — **No degenerate schedule value other than a zero epoch length reaches the same failure mode.** Enumerated the
  validation surface: zero emissions per epoch, a zero or over-long cliff, an over-large reduction, and a past start
  timestamp are each rejected.
- `PASS` — **Unclaimed-emissions double reclaim.** Blocked by a per-epoch guard before the payout; both entry points are
  role-gated.

### 6.11 Leads killed at the judging gates

Recorded here rather than filed, per the mandate that a suppressed refutation still be reported.

- **Sub-wei MasterChef accumulator dust as a conservation break.** Attacked by maximizing the per-credit loss and
  attempting to compound it across 30,000 fuzz runs. The loss is bounded absolutely by the tier stake divided by the
  accumulator precision — at most ~1 gwei per credit for the entire plausible token supply — and cannot compound.
  Matches the explicitly accepted trade-off. The one non-obvious aspect (the assigned-versus-credited discrepancy) is
  filed separately as R2-PAS-09.
- **The inherited name-only curve initializer as a front-running surface.** The parent's single-argument initializer
  remains on the ABI and shares the one-shot initializer slot; a non-atomically deployed proxy could be front-run into
  an ownerless, zero-config state that bricks the tier math with no recovery. Killed at the reachability gate: the
  repository's deploy scripts initialize atomically, so the precondition does not exist. Matches a known accepted
  disposition.
- **Peer-owner seizure of wallet ownership.** Ownership transfer is gated on any registered peer owner and routes
  through the one removal helper without a last-owner guard, so a co-signer can evict the claimant. Matches a known
  accepted disposition following from the flat multi-owner model — recorded, not filed.
- **Tier ladder unit coupling.** The curve's running total is credited in share units while the tier edges are
  denominated in asset units. These coincide only while the vault sits at exactly 1:1, which holds because all pro-rata
  donations are routed to the default curve's vault. Verified to hold at the reviewed commit; killed as a present-tense
  finding, but it is the same coupling that makes R2-PAS-03 unrecoverable and is noted there.
- **Gas exhaustion via the tier walk.** The tier resolution and piecewise fee walk are each linear in the tier count
  with an exponentiation per iteration, and the deposit path evaluates them several times. At the shipped tier count
  this is tolerable; no lens measured a block-limit denial of service, so the concern is recorded as unmeasured rather
  than filed.

---

## 7. Cluster verdicts

```
C1  — DynamicFeeFlatPriceCurve fee economy ......... VERDICT: FAIL
C2  — IBaseCurve hook surface and dispatch ......... VERDICT: FAIL
Δ   — Delta since last audited commit .............. VERDICT: PASS
A   — MultiVault payable multicall ................. VERDICT: PASS
B   — MultiVaultLib storage mirror ................. VERDICT: PASS
D   — AtomWarden quorum + window cap ............... VERDICT: PASS
E   — AtomWallet ERC-4337 / P-256 auth ............. VERDICT: PASS
F   — TrustBonding emissions + pause ............... VERDICT: PASS
G   — FeeProxy refund ledger ....................... VERDICT: PASS
H   — Emissions controllers (Intuition side) ....... VERDICT: PASS
```

**Headline severity count: 0 Critical, 3 Major, 2 Medium, 4 Minor, 8 Informational.**

C1 fails on three Major findings in the fee-redistribution kernel, all permissionless and all reproduced by execution.
C2 fails on the unasserted hookless-default-curve invariant, whose violation is irreversible.

---

## 8. Appendix

### 8.1 Methodology

Twelve concurrent adversarial lenses were run over the full in-scope set, each receiving an identical bundle of the
in-scope source (line-numbered for citation) plus a shared engagement overlay carrying the mandate, the six load-bearing
invariants, the out-of-scope denylist, the prior round's disposition register, and the framing note for the fee curve.
The lens specialties were: math and precision; access control; economic security; execution trace; invariants;
periphery; first principles; asymmetry; boundary enumeration; and three cross-lens "gap hunter" agents targeting seams
that no single specialty can articulate (numerical, trust, and control-flow).

Budget was weighted toward the two clusters with zero prior audit coverage. Each lens was required to attack every
property it reported as passing and to record the refutation attempt, on the standing rule that a `PASS` without an
attempted refutation is a `FAIL`.

Lens output was then deduplicated by (contract, function, bug class), with a second pass at the (contract, function)
level to prevent distinct coexisting mechanisms from collapsing into one entry, and put through four sequential judging
gates:

1. **Attack execution** — does any guard on the claimed path interrupt the exploit before harm?
2. **Reachability** — can the vulnerable state exist in a live deployment?
3. **Trigger** — can an unprivileged actor execute it? Admin-only findings are rejected unless a concrete unprivileged
   amplifier is named (a race, a retroactive sweep, an asymmetric formula, or an access gap where the access mechanism
   itself is the defect).
4. **Impact** — is there material harm to an identifiable victim?

Every promoted finding was then independently re-verified by the orchestrator against the reviewed commit rather than
accepted on a lens's word. Findings that did not survive are recorded in §6.11 rather than discarded.

### 8.2 Verification performed

- **Executed proofs of concept.** Both Major findings were reproduced by running Foundry tests against a **pristine,
  isolated checkout** of commit `8579c5e`, created as a separate git worktree specifically so that no source mutation
  could touch the shared working tree. `git diff --quiet -- src/` was asserted immediately before each run. The numbers
  quoted in R2-PAS-01 and R2-PAS-02 are copied from those runs.
- **Mutation checks.** Both landed fixes were mutation-checked in the same isolated worktree: neutering the ERC-1271
  digest binding turns 11 tests red across three suites; neutering the zero-epoch-length guard turns the gating test red
  on both controllers. Baselines were green before each mutation and the worktree was restored after.
- **Storage layout.** Verified by executing `forge inspect MultiVault storage-layout` and comparing slot-by-slot against
  the library's storage view, rather than by reading both declarations.
- **Fuzz campaigns.** 30,000 randomized runs over deposit/redeem walks asserting curve solvency and the ledger mirror,
  with tier counts from 12 to 64 and both lump-slice parameters non-zero so every distribution fallback fires.
- **Coverage measurement.** The quote-then-record parity gap in R2-PAS-06 was established by removing the guarantee and
  re-running the existing dynamic-fee suite: 28 of 28 tests pass, including three invariant suites and two 10,000-run
  fuzz solvency tests.

### 8.3 Scope integrity note

The shared working tree was being modified concurrently by processes outside this review for the duration of the round.
`src/libraries/MultiVaultLib.sol` was observed transiently modified and restored on four separate occasions, and
`src/protocol/wallet/AtomWallet.sol` was independently observed in a transiently modified state.

One consequence is recorded here for completeness because it materially affected this round's raw output: the source
bundle handed to the lenses was generated from the working tree during one such window and consequently carried a
one-line modification to `_recordCurveDeposit` that **does not exist at the reviewed commit**. Twenty-two of the
twenty-three bundled files were byte-identical to the commit; one was not. Eight lenses independently reported a
High-severity conservation break against that line — and, to their credit, every one of them independently diffed the
bundle against the commit, identified the divergence, and flagged that the committed code was clean rather than filing
blind.

That finding is **void as a defect** and is recorded instead as a verified negative in §6.3 (quote-then-record equality
holds by construction at the reviewed commit) and as a coverage finding in R2-PAS-06, since the lenses' measurements of
what the removed guarantee would cost — and the demonstration that the existing suite does not catch it — are themselves
valid and useful.

Every other finding in this report was verified against `git show 8579c5e:<path>` or against the isolated worktree, not
against the shared working tree. No finding in this report depends on the modified file's transient state.

**Recommendation for future rounds:** give each reviewer an isolated checkout. Mutation testing and source-level review
cannot safely share a working tree, and a review whose source can change underneath it cannot make reliable claims. This
round's own mutation checks were run in a separate worktree for exactly this reason.

### 8.4 Coverage limitations

- Two of the twelve lenses (invariants and trust-gap) terminated early on a platform usage limit and did not produce a
  report. Their assigned surfaces were covered by other lenses — the invariant surface substantially so, by the
  math-precision, first-principles, asymmetry and boundary lenses — but this round is a **ten-of-twelve sweep**, not a
  complete one. The trust-gap seam (privileged action composing into an unprivileged profit) is the least redundantly
  covered as a result.
- Findings R2-PAS-03, R2-PAS-04, R2-PAS-07, R2-PAS-11 and R2-PAS-17 have privileged triggers and were not reproduced by
  execution; their proofs are hand-traced from the quoted code.
- R2-PAS-16 was reproduced by execution, including a counterfactual and realized profit-and-loss, but against the
  repository's 5-tier test fixture rather than the 13-tier production ladder. The mechanism is scale-free — it depends
  on bucket occupancy, not tier count — and the production schedule routes a **larger** share of the exit fee down the
  exploited path, so the production impact is expected to be greater, not smaller. Re-running against the production
  ladder is recommended before sizing the fix.
- No fork testing against live deployments was performed; all work was local.

### 8.5 Disclaimer

This is a **pre-audit artifact** produced by an internal, first-party adversarial review run before the external audit.
It is **not** a formal audit, a certification, a warranty, or a guarantee of safety. Automated and model-driven analysis
cannot establish the absence of vulnerabilities. A clean verdict on a cluster means the properties listed in §6 were
attacked and held under the attacks described — not that the cluster is free of defects. Independent external review, a
bug bounty, and on-chain monitoring remain necessary.
