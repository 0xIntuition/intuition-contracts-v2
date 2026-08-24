# Findings and decisions

Severity meanings in this review:

- **Medium:** reachable loss of availability or materially unsafe behavior requiring a code/configuration change.
- **Low:** no direct on-chain accounting failure, but a realistic integration, monitoring, or specification hazard.
- **Economic decision:** current behavior is deliberate and conserved, but product/security intent must explicitly
  accept its incentive consequences.

## Summary

| ID      | Rating                                | Title                                                               | Recommended disposition                            |
| ------- | ------------------------------------- | ------------------------------------------------------------------- | -------------------------------------------------- |
| DF-01   | Medium                                | Unbounded fee growth can make an accepted config panic on fee reads | Fix before deployment                              |
| DF-02   | Low                                   | Published lifecycle document describes superseded deposit economics | Fix before economic sign-off                       |
| ED-01   | Economic decision — High importance   | Dynamic fees can be recovered by a coordinated multi-address actor  | Explicit product/security acceptance               |
| ED-02   | Economic decision — High importance   | Eligibility floor ships disabled                                    | Set launch value deliberately                      |
| ED-03   | Economic decision — Medium importance | Quote bands and distribution bands diverge after MultiVault fees    | Accept and document, or redesign hook input        |
| ED-04   | Economic decision — Medium importance | Sticky buckets create drawdown/retune earning blackouts             | Explicitly accept path dependence                  |
| GOV-01  | Low                                   | `ConfigUpdated` omits most fee-economy fields                       | Improve event or mandate calldata/state monitoring |
| NOTE-01 | Clarification                         | Thirteen configured tiers are indexes 0–12, not 0–13                | Confirm product terminology                        |

The average-atom extension adds UX-01 through QA-01. Their full evidence and dispositions are in
[`05-average-atom-model.md`](./05-average-atom-model.md) and
[`06-pre-audit-product-decisions.md`](./06-pre-audit-product-decisions.md):

| ID     | Rating                                | Title                                                            | Recommended disposition                              |
| ------ | ------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------- |
| UX-01  | Economic decision — High importance   | Current-tier bucket earns no same-tier deposit fees              | Redesign before audit if stable-atom users must earn |
| UX-02  | Economic decision — High importance   | Tier-3/4 stacked fee burden is about 10%–11% per flat round trip | Establish user fee budget and retune                 |
| UX-03  | Medium integration/UX                 | Public generic redeem preview is not holder-accurate             | Add full-stack account-aware preview                 |
| GOV-02 | Economic/governance — High importance | Live geometry changes redefine sticky cohort indexes             | Freeze geometry or deploy a new curve ID             |
| ADV-01 | Economic decision — High importance   | Zero floor is weak for ordinary-user-sized adversarial flow      | Model floor and reroute jointly                      |
| UX-04  | Medium integration                    | Default-vault state changes dynamic-vault total fees             | Expose complete executable quote/breakdown           |
| QA-01  | Medium assurance gap                  | No production-scale ordinary-user lifecycle suite                | Add before external audit                            |

---

## DF-01 — Unbounded fee growth can make an accepted config panic on fee reads — Medium

### Impact

The owner can store a config that passes every `_setConfig` check but causes arithmetic panic in
`depositFeeBps`/`quoteDepositFee` or `withdrawalFeeBps`/`quoteRedeemFee` for tier 1 or above. Because `MultiVault`
consults these quotes inside deposits and redeems, affected operations halt until a second timelocked configuration
transaction repairs the schedule.

Principal is not confiscated and the config is governance-controlled, but the contract explicitly claims to validate its
fee schedule and to clamp growth at read time. The accepted configuration violates both expectations.

### Root cause

`_setConfig` bounds the bases and caps, but neither growth field:

```solidity
// accepted
config.depositGrowthBps = type(uint256).max;
config.withdrawalGrowthBps = type(uint256).max;
```

The getters compute before clamping:

```solidity
uint256 fee = config.depositBaseBps + tier * config.depositGrowthBps;
return fee < cap ? fee : cap;
```

The multiplication or addition can overflow before `cap` is consulted. The same pattern exists on withdrawal.

Relevant implementation: `DynamicFeeFlatPriceCurve.sol` `_depositFeeBps` and `_withdrawalFeeBps`; relevant validation:
`_setConfig`.

### Proof

A temporary Foundry regression test performed both sequences:

1. deploy a valid three-tier curve;
2. call `setConfig` with the respective growth field set to `type(uint256).max`;
3. confirm the value was stored; and
4. query a tier-1 deposit or withdrawal fee.

Both cases reverted with `Panic(0x11)`. The temporary proof was removed after execution; the result is recorded in
`04-verification.md`.

### Recommendation

Use saturating arithmetic rather than imposing an arbitrary economic ceiling:

```solidity
function _cappedLinearFee(uint256 base, uint256 growth, uint256 tier, uint256 cap)
    private
    pure
    returns (uint256)
{
    if (base >= cap || tier == 0 || growth == 0) return base < cap ? base : cap;
    uint256 room = cap - base;
    if (growth > room / tier) return cap;
    return base + tier * growth;
}
```

Use it for deposit and withdrawal schedules. Add tests with maximum growth at tier 0, tier 1, and the top tier, plus a
config-retune integration test proving deposits and redeems still execute at the cap.

An alternative is to reject growth above `(type(uint256).max - base) / (tierCount - 1)` and explicitly probe both top
rates in `_setConfig`, but saturation better matches the documented “unbounded growth, clamped to cap” semantics.

---

## DF-02 — Published lifecycle document describes superseded deposit economics — Low

### Impact

The hand-authored call-flow document is positioned as a prerequisite for reviewing the value paths, but several
load-bearing claims disagree with current code. An economist, integrator, or auditor using it can model the wrong fee,
the wrong cohorts, and the wrong self-recovery behavior.

### Confirmed mismatches

| Topic                      | Existing call-flow claim                                              | Current implementation                                                                                            |
| -------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| quote traversal            | gross deposit fills each band                                         | each band's gross amount is increased so **curve-fee-net** stake fills it                                         |
| 6k + 20k reference example | fee `679.53125`, cursor ends at 26k                                   | fee `675.771115735927978865`, curve-fee-net cursor ends at `25,324.228884...`                                     |
| distribution source        | all fee targets tiers below the pre-deposit tier                      | fee is apportioned across **actual net bands**, each distributed from its own band                                |
| depositor exclusion        | depositor is removed from every denominator and earns none of own fee | depositor's existing lower-tier stake participates normally; only the newly landing band is structurally excluded |
| precision example          | one three-tier split of the old total                                 | replay can create one distribution per actual band, changing split and dust                                       |

The current contract NatSpec and tests describe the new behavior; the drift is concentrated in
`docs/call-flows/dynamic-fee-curve.md`.

### Recommendation

Replace sections 2–4 of that document with the lifecycle in `01-mechanics-and-lifecycle.md`, regenerate the record
graphs, and add a committed exact assertion for the corrected 6,000/20,000 worked example. A documentation example
should call the public quote in a test rather than duplicate arithmetic in prose.

---

## ED-01 — Dynamic fees can be recovered by a coordinated multi-address actor — Economic decision, high importance

### What holds

- No value is minted.
- The curve remains solvent.
- A single exiting account never earns from its own withdrawal fee.
- End-to-end round trips under the current production `MultiVault` fees remain net negative in the tested ranges.

### What does not hold

The dynamic fee itself is not reliable wash friction at the actor level.

The committed test `test_washRoundTrip_twoAddressActorReachesBreakEven_andNothingIsMinted` demonstrates a curve-only
sequence where:

1. actor address A occupies one bucket;
2. actor address B occupies an adjacent bucket;
3. A makes the washed deposit and recovers deposit fees through its earlier tier stake;
4. A fully exits its bucket;
5. the empty-cohort withdrawal slice reroutes to B; and
6. the actor's combined position returns essentially the full wash gross, within truncation dust.

Wallet splitting can also change bucket placement and transfer a bounded amount away from unrelated holders. The
deterministic measurement suite treats a sampled edge below 100 bps of deposited amount as acceptable and explicitly
states that the edge is a transfer from a bystander, not creation.

### Why this needs sign-off

If the product purpose is “redistribute activity fees and conserve value,” the implementation matches it. If the purpose
includes “make self-dealing expensive” or “reward economically independent early cohorts,” per-account exclusion is
insufficient because accounts are free.

Current system-level losses come from independent protocol/entry/exit/wallet/fraction fees. A future change that lowers
those fees, redirects them to an actor-capturable destination, or exempts a path can move a coordinated wash closer to
break-even or profit even though the dynamic-curve tests stay green.

### Options

1. **Accept:** document that exclusions are per account, not per beneficial actor, and test the minimum combined system
   fee needed to keep a coordinated round trip negative.
2. **Reduce reroute capture:** send an empty exiting-bucket slice to `protocolAccrued` or the fulcrum spread rather than
   winner-takes-all nearest-tier rerouting.
3. **Add commitment:** time-weight or delay withdrawal-fee eligibility. This is a mechanism change and contradicts the
   current no-dwell design.
4. **Rely on system leakage:** codify a cross-contract invariant that protocol-controlled, non-recoverable round-trip
   fees remain above a governed minimum. Today that invariant is an operational fact, not enforced by the dynamic curve.

---

## ED-02 — Eligibility floor ships disabled — Economic decision, high importance

`minEligibleTierStake = 0` reduces eligibility to “any nonzero tier stake.” Between-tier allocation uses kernel weight,
not capital weight. A tiny tier can therefore receive the same whole tier slice as a deeply funded tier and then divide
that slice among very little stake.

This behavior was previously audited and dispositioned by design. The code now includes a floor and a 1,000-TRUST
maximum, but the deploy seed deliberately leaves it off.

### Consequences at zero

- a dust cohort can capture a full kernel-weighted deposit slice;
- a tiny same-bucket co-holder can capture the entire default withdrawal slice;
- a tiny nearest tier can capture a whale-exit reroute; and
- no dwell period prevents positioning immediately before visible activity.

### Consequences of enabling it

- under-floor deposit recipients disappear from normalization and their shares are absorbed by qualifying tiers;
- a sub-floor residual exiting cohort loses its slice to `protocolAccrued`;
- an attacker can still qualify by posting the floor, so the floor prices the strategy rather than proving independent
  economic ownership; and
- changing the floor affects future distributions immediately without migrating accrued credit.

### Recommendation

Select the launch value from explicit capital-at-risk modeling, not the default. At minimum, simulate expected whale
exit sizes and determine the stake/fee ratio at which posting the floor for one transaction is profitable. If zero is
retained, state in launch materials that tier presence, not capital magnitude or duration, earns between-tier weight.

---

## ED-03 — Quote bands and distribution bands diverge after MultiVault fees — Economic decision, medium importance

### Mechanism

`quoteDepositFee(termId, assetsAfterMinSharesCost)` advances its cursor by base minus the curve fee. The record hook
later receives shares after protocol, entry, atom-wallet, or triple-fraction fees have also been removed. It replays
those actual shares and apportions the already-collected curve fee across the smaller set of actual bands.

Conservation is exact, but “fee charged by band” and “fee distributed from band” are not the same decomposition.

### Boundary effect

Near an edge, the quote may charge a portion at tier `t+1` while other MultiVault fees leave actual stake in tier `t`.
That higher-rate portion is then distributed from the lower actual band:

- a tier-0 actual band sends it to `protocolAccrued` rather than earlier holders;
- a tier-1 actual band can pay only tier 0, even if the quote included tier 2; and
- changing MultiVault fees changes fee recipients without changing dynamic-curve config.

At production fee levels this is a fee-on-fee-sized region around boundaries, not a solvency issue. `MultiVault` fee
setters carry no numeric ceiling, so the divergence is not bounded by the curve contract itself.

### Options

1. **Accept and document:** describe the quote as pricing and replay as allocation, not identical band walks.
2. **Quote on actual pre-curve net:** compute other fees first and pass the post-MultiVault-fee amount to the curve.
   This changes the standardized hook semantics and requires careful circularity analysis.
3. **Return a quote decomposition:** carry band fees in the hook and replay exactly that set. This increases ABI and gas
   cost and still needs a policy for stake that did not actually reach a quoted band.

---

## ED-04 — Sticky buckets create drawdown and retune earning blackouts — Economic decision, medium importance

Holder buckets encode average entry history, not current location. A redeem changes current TVL tier but does not
rebucket any holder. A ladder retune can also move current tier without touching holder buckets.

When all holder buckets sit at or above the current source band, new deposit fees have no eligible prior bucket and go
to `protocolAccrued`. Earnings resume only when the vault climbs above a holder bucket or that holder deposits lower and
moves their own weighted average.

This is explicitly tested and documented by the contract. It avoids unbounded global migration and prevents a redeem
from rewriting other holders' entitlements, but it makes protocol take and holder APY path-dependent.

### Recommendation

Accept only with monitoring that shows both `vaultStake` tier and `tierStake` occupancy. Model drawdown/retune scenarios
before governance changes geometry. A UI that displays only current TVL tier cannot explain current fee eligibility.

---

## GOV-01 — `ConfigUpdated` omits most fee-economy fields — Low

The event emits only `width0`, `tierCount`, `growthGBps`, `fulcrumAlpha`, and `kernelSpread`. It omits both bases, both
fee growth rates, both caps, the withdrawal split, and the deposit spike. The floor has its own before/after event;
overrides have dedicated events.

A transaction can therefore materially change user fees while emitting a `ConfigUpdated` event whose decoded values look
unchanged. Monitoring can recover the truth from calldata or a post-transaction `getConfig` read, but event-only
consumers cannot.

Recommendation: emit the full config, its hash plus a mandatory state read, or dedicated old/new fee schedule events.
Given the owner is a timelock, governance tooling should also render all omitted fields in proposal review.

---

## NOTE-01 — Thirteen configured tiers are indexes 0–12

`tierCount` is a count, not the highest index. The current production seed provides:

```text
13 total tiers = tier 0, 1, ..., 12
top tier        = tierCount - 1 = 12
tier 13         = nonexistent
```

If product language requires “tier 0 through tier 13,” set `tierCount = 14`. That change is not cosmetic: it introduces
a new terminal tier, turns the current terminal tier into a finite band, changes full-ladder gas, and leaves existing
tier-12 holders in bucket 12.
