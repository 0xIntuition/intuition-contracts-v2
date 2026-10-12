# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 4 (Final Revision) — MASTER Consolidated Report

> **Artifact type:** Internal AI pseudo-audit — **consolidated master, final-revision round**. This is a **pre-audit
> artifact — not a formal audit, certification, warranty, or guarantee of safety.** Rounds 1 and 2 reviewed the upgrade
> surface before external audit; round 3 reviewed the remediation written against the Consensys Diligence report.
> Round 4 reviews **the revision that ships**: the external auditor delivered its final report on 2026-10-08 with every
> finding closed and nothing new, no further external review is scheduled, and this pass is the last adversarial look
> the code gets before the mainnet upgrade on 2026-10-26.

|                          |                                                                                                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **External input**       | Consensys Diligence final report on the v1.1.0 core upgrade, 2026-10-08: 5.1, 5.2, 5.3, 5.4 and 5.6 **Fixed**, 5.5 **Acknowledged**, no new findings. Round 2 of the remediation is therefore empty: there is no round-2 diff. |
| **Reviewed revision**    | Public `intuition-contracts-v2`, PR #158 head `ea6c239` ("Consensys Diligence v1.1.0 remediation", base `feat/v1.1.0-core-upgrade`). This is the revision the auditor reviewed and the revision the mainnet batches are built from. The monorepo sources match it except one curve NatSpec paragraph. |
| **Scope**                | The eleven contracts of the auditor's Appendix 1, read in full, plus everything they call: `DynamicFeeFlatPriceCurve`, `BaseCurve`, `MultiVaultLib`, `MultiVault`, `MultiVaultCore`, `FeeProxy`, `AtomWarden`, `AtomWallet`, `CoinbaseSmartWalletLib`, `TrustBonding`, `VotingEscrow`; `LinearCurve`, `BondingCurveRegistry`, `AtomWalletFactory` and the interfaces. |
| **Priorities**           | (1) the curve's lot model and occupancy-weighted spread (`6c83910`), (2) the redeem-path gas refactor `a7f6d9f` that landed after it, (3) multicall value accounting, (4) FeeProxy ordering after 5.2, (5) upgrade-time effects on v1.0.2 positions and unclaimed wallets. |
| **Toolchain**            | Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun`, OpenZeppelin `5.4.0`, solady; TransparentUpgradeableProxy and one UpgradeableBeacon.                                 |
| **Date**                 | 2026-10-08                                                                                                                                                             |
| **Lanes merged**         | 4 passes across 3 model families: 2 isolated adversarial lanes with proofs of concept (Claude Fable 5.1, Claude Opus 5.5), 1 cold cross-model review (GPT-6 Astra), 1 orchestrator verification pass. See §8. |
| **Prior round**          | [`../round-3/MASTER-consolidated-report.md`](../round-3/MASTER-consolidated-report.md) — the remediation round: 3 Major, 7 Medium, 20 Minor, 9 Informational against the fixes, none open. |
| **Verification state**   | At `ea6c239`, capped fuzz: curve unit suites 119/119; MultiVault-level dynamic-fee, security and upgrade-regression suites 157 passed, 7 skipped; stateful invariants 4/4; storage layouts of the four upgraded contracts diffed against `v1.0.2`; five guard-removal mutation checks; mainnet reads of the live proxies. See §7. |

---

## 1. Executive summary

The final report asked for no code change, so this round reviewed the shipped revision whole rather than a diff. Three
lanes reported: two isolated Claude lanes on different model families, each in its own worktree and unaware of the
other (Fable 5.1 with 21 proof-of-concept tests, Opus 5.5 with 14, including random-sequence runs of up to 1,500
steps at the launch schedule and a differential fuzz of the gas refactor against its parent commit), and a cold GPT-6
Astra lane that reviewed the sources read-only. The orchestrator independently reran all 35 lane tests, ran the curve,
MultiVault, security, upgrade-regression and invariant suites at the shipped revision, diffed the upgradeable storage
layouts against the live implementations, read the live proxies, and mutation-checked the seven load-bearing guards.

**No Critical and no High finding. One Medium, one Low, one known item re-raised.**

- **`R4-01` (Medium).** A wallet claimed under the live v1.0.2 code becomes ownerless after the AtomWallet beacon
  swap: the new implementation reads ownership from a multi-owner registry that only `completeClaim` seeds, and
  `completeClaim` refuses a wallet whose `isClaimed` flag is already set, so nothing in v1.1.0 can repair it. This is
  round-1's `MA-01`, closed then as not applicable on a census of zero claimed wallets. The census is still zero, and
  the owner reconfirmed it from the protocol's own statistics on 2026-10-08. The lane's new point is that the
  precondition is not fixed: the v1.0.2 claim path is permissionless and cannot be paused, so any user, or anyone who
  wants to force the dilemma, can claim an address-atom wallet before the batch executes. Reproduced independently by
  both isolated lanes: on a mainnet fork against the live code, and with the verbatim v1.0.2 wallet behind a real
  beacon. The loss is bounded to wallets claimed in that window and is recoverable by a later beacon
  upgrade that reads the orphaned slot, which is why it is Medium rather than High. Disposition by the owners on 2026-10-09:
  acknowledged, no code change. The census was repeated the same day and is still zero; no permissioned ownership
  transfer is planned before the upgrade; users are advised not to use the permissionless address-atom claim until
  v1.1.0 is live; and the pre-flight repeats the scan at the execution block.
- **`R4-02` (Low).** `MultiVault.reinitialize` pins the system-utilization carry to the upgrade epoch without carrying
  a balance. If the upgrade epoch has seen no deposit or redeem before execution, or if step 03 lands in a later epoch
  than step 02, one epoch's system utilization starts from the wrong baseline and TrustBonding scales that epoch's
  emissions to the floor. Bounded to one epoch's emissions, no principal, acknowledged, and closed by two runbook
  reads. Found independently by all three lanes.
- **`R4-K-01` (known).** Permissionless `deposit_for` pulling from the holder's standing allowance, rated blocking by
  the cold lane. It is the canonical Curve semantic, documented in the source, closed by design seven times on the bug
  bounty, and reconfirmed by the owner. It was outside the accepted-behaviour list the lanes received and is now on it.

**Everything else held under concrete attack at the launch schedule:** lot-ledger consistency under over-full tiers
and random sequences, the exiter's exclusion at every tier, the fill-capped single-target credits and the
occupancy-weighted spread's per-share ceiling, solvency after claims and sweeps, quote-versus-execution agreement for
multi-lot positions, deposit split-neutrality, the floor applied identically by every gate, hunk-by-hunk equivalence of
the `a7f6d9f` refactor, multicall value accounting across mixed batches with re-entry from a payout, FeeProxy ordering
and refunds after the 5.2 fix, and the storage, reinitializer and unclaimed-wallet surface of the upgrade. Each
remediation closes the class of its finding, not only the reported instance, in both lanes' judgement.

**Gate: go for the 2026-10-26 schedule, with the `R4-01` scan and advisory and the `R4-02` reads carried in the
runbook.**

### Findings by severity (round 4, against the shipped revision)

| Severity          | Count | Open | Closed by code | Accepted / dispositioned |
| ----------------- | ----- | ---- | -------------- | ------------------------ |
| **Critical**      | 0     | 0    | —              | —                        |
| **High / Major**  | 0     | 0    | —              | —                        |
| **Medium**        | 1     | 0    | 0              | 1 (`R4-01`, acknowledged with an operational advisory) |
| **Low / Minor**   | 1     | 0    | 0              | 1 (`R4-02`, acknowledged, runbook gate) |
| **Known, re-raised** | 1  | 0    | —              | 1 (`R4-K-01`, by design) |
| **Below threshold** | 10  | —    | —              | recorded in §6           |

---

## 2. Scope and method

**In scope.** The whole v1.1.0 contract set at the final revision, read as an auditor reads it: contract code only,
whole files, never the diff stat and never the tests as scope. The remediation delta `105fbe0..ea6c239` (the twelve
commits since the revision the auditor originally reviewed) is read on top of that, each fix judged on whether it closes
the class of its finding or only the reported instance and whether it regressed surrounding code. Deployment context is
taken from the mainnet execution-order runbook and the launch schedule the curve deploys with.

**Out of scope.** The TypeScript packages that mirror the curve (a separate audit). The Rust indexer
realignment, held until deploy. The application layer. The Base-side emissions contracts, unchanged in this release.

**Why this pass has no net.** Passes 1 to 3 were followed by an expert review. The engagement included one remediation
review, which produced the final report; nothing checks the code after this pass. The lanes were therefore told to work
as adversaries: assume at least one above-threshold defect exists and either reproduce it with a Foundry test or state
the evidenced reason it does not.

**What the lanes were given.** An identical brief: the scope list, the five priorities, the deployment and trust model,
the launch schedule, the risk threshold and stop condition, the auditor's final report as text, the PR description, the
funds-touching rubric, and a list of behaviours already accepted by the owners so the budget would not be spent
re-reporting them. No lane saw another lane's output, any prior internal report, or the orchestrator's own reading. Each
Claude lane worked in its own detached worktree at `ea6c239` with its own build, and could write proof-of-concept tests
only under a gitignored scratch directory; the cold cross-model lane was read-only.

**RISK-THRESHOLD.** Loss or lock of user principal; fees diverted from other holders beyond the accepted behaviour;
a broken upgrade or initialization; privilege escalation; permanent denial of service of deposit, redeem or claim.
Below threshold: gas, style, documentation, and the accepted behaviour.

**STOP-CONDITION.** Every lane read the scope in full; every above-threshold candidate was reproduced with a capped
Foundry test or refuted; the master and the disposition register are written. **REVIEW-ROUND:** 1 (a second round on
this unchanged diff is permitted; a third is not).

---

## 3. Severity classification

Unchanged from rounds 2 and 3: impact × likelihood, Diligence house labels, the highest severity a credible path
reaches under the intended deployment and trust model, with permissionless exploitability separated from
trusted-configuration reachability. A finding that a fix introduced is rated on the fixed code's behaviour.

---

## 4. Load-bearing invariants

Invariants 1 to 12 carry from rounds 2 and 3 (conservation, solvency, curve-ledger mirror, flat-price par,
storage-layout upgrade-safety, no `msg.value` replay, redistribution fidelity, lot-ledger consistency, schedule-rate
ceiling, quote-execution agreement, common rate within a spread, terminal home for every wei). Round 4 adds the two the
final revision depends on at upgrade time:

13. **Pre-upgrade state is inert under post-upgrade code.** Every position opened under v1.0.2 sits on a hookless
    curve, so the new hook probe returns `false` and the deposit and redeem paths reduce to the v1.0.2 arithmetic. Every
    wallet deployed under v1.0.2 is unclaimed, so after the beacon swap `owner()` resolves to the warden and
    `completeClaim` seeds the multi-owner registry from an empty state. The appended storage of the upgraded contracts
    starts at slots the live implementations never wrote.
14. **The reinitializers run exactly once, by the Admin Safe, after the atomic implementation swap.** Both are version-2
    reinitializers gated on the admin, and the live proxies sit at initializer version 1.

---

## 5. Part A — the disposition register, reconciled against the shipped revision

This is the last point at which the register can be reconciled against what ships, so every finding of every round is
accounted for here: either closed in its own round and unchanged by anything since, or named below with its shipped
state.

### 5a. External findings (Consensys Diligence, final report 2026-10-08)

| Finding | Severity | Final-report status | Shipped-state check at `ea6c239` |
| ------- | -------- | ------------------- | -------------------------------- |
| 5.1 A minimum-stake position keeps a tier's whole fee share | Major | Fixed (`6c83910`) | Confirmed. The kernel spread weights every prior tier by its fill (`_weighPriorTiers`), normalizes over `max(Σe, Σw)` (`_payFulcrumTiers`), and every single-target credit is capped at the recipient's fill (`_creditEligibleCapped`). The per-tier ceiling is fuzzed in the curve suite and mutation-checked in §7. |
| 5.2 Affiliate paid before the routed MultiVault call | Major | Fixed (`0dc6c1e`) | Confirmed on all five routes: `depositVia`, `depositBatchVia`, `createAtomsVia`, `createAtomsWithUrisVia`, `createTriplesVia` pay the affiliate after the routed call and refund last. Mutation-checked in §7. |
| 5.3 Sentinel accounts and repositioning | Major | Fixed (`6c83910`) | Confirmed. Stake is held as one lot per tier (`lotStake`, `lotRewardDebt`, `lotMask`); a redeem unwinds highest tier first (`_unwindLots`) and the account-aware quote walks the same lots (`_lotRedeemFee`). One account can hold a dust seat only at its top lot, because lower lots cannot be touched until the top drains. |
| 5.4 A deposit approval moves the receiver's tier | Medium | Fixed (`2d0e6ed` docs, `6c83910` structurally) | Confirmed. A delegated deposit opens or tops up one lot per band and never moves the receiver's existing lots; the `ApprovalTypes` NatSpec says so. `FeeProxy` additionally requires a delegated receiver to have approved the caller, not only the proxy. |
| 5.5 Fee recovery depends on how a position is split | Medium | Acknowledged | Unchanged. The deposit leg is exactly split-neutral by construction (no per-account exclusion, fee paid before the stake lands); the redeem leg's two-wallet recapture is bounded per share by the schedule rate. Accepted by the owners. |
| 5.6 A hook-bearing curve can be set as the default curve | Minor | Fixed (`73a8dcd`) | Confirmed on both write paths, `initialize` and `setBondingCurveConfig` (`_assertDefaultCurveIsHookless`). Mutation-checked in §7. |
| Note: counter-triple init guard near-unreachable | Info | Documented (`9b50016`) | Confirmed in `_isDirectCounterTripleTermInit`'s NatSpec. |
| Note: `previewRedeem` is account-agnostic | Info | Already documented | Confirmed on `IMultiVault.previewRedeem`, updated for lots. |
| Carry-over: `previewTripleCreate` omitted the atom-deposit fraction | Info | Fixed (`69e0df4`) | Confirmed: the preview is keyed on the three atom ids and evaluates chargeability against them. |

The final report's §4.1 still describes the Parameters Timelock as the curve's owner; the deploy configuration makes
the Admin Safe the owner at launch. That is a documentation correction requested from the auditor, not a code change,
and it widens no privilege: the owner's powers are `setConfig`, per-tier overrides and `sweepProtocol`, the fee
ceilings are immutable, and the proxy admin stays behind the Upgrades Timelock.

### 5b. Round 3 (remediation round) — 39 internal findings

All 39 carry their round-3 disposition; the ones whose shipped state is worth re-stating:

| ID | Round-3 disposition | Shipped state at `ea6c239` |
| -- | ------------------- | -------------------------- |
| MA-01 capped remainder re-spread | Fixed before merge, superseded | The cap-and-cascade no longer exists; a tier receives exactly one credit from a pool. Confirmed in `_payFulcrumTiers` and `_creditByWeight`. |
| MA-02 sweep recovers its own fee through the band it filled | Closed by code | A sweep's earlier band earns its schedule share of the next band's fee and no more. Accepted behaviour; the lanes were told so. |
| MA-03 walk residue re-entered the spread | Fixed | The spike's residue and the exiting-tier slice's leftover accrue (`_payDepositFee`, `recordRedeem`). The regression and the ceiling fuzz go red when the residue is routed back into the pool (§7, M4). |
| MED-01 lot mappings reuse the averaged-model slots | Accepted by deployment policy | Still a runbook rule, not code: the curve ships as a fresh proxy and no proxy running the averaged model may ever be pointed at this implementation. The testnet instance is redeployed, not upgraded. |
| MED-03 per-lot quote nonlinear if the curve were the default | Closed by the 5.6 guard | Guard present on both write paths; §7 M1. |
| MED-05 effective weights rounding to zero | Fixed | Weights carried at `WEIGHT_PRECISION = 1e36`; the fallback keys on the window admitting an eligible tier, not on the sum. |
| MED-06 redeem-leg cohort fallback pays the exiter's co-holders | Accepted, for owner reconfirmation | Reconfirmed by the owners on 2026-09-19 ("if people are left, give it to them, else protocol"). Shipped as `_creditLotCohorts`; the lanes were told it is accepted. |
| MED-07 upward reroute widens two-wallet recapture | Accepted as 5.5 | Shipped as `_rerouteExitSlice` (above first, then below). |
| MIN-12, MIN-18 `RedeemFeeRerouted` semantics changed with an unchanged signature | Acknowledged | Still true at `ea6c239`; absorbed by the held indexer realignment, which must land with the deploy. |
| MIN-19 worst-case redeem gas with a thin ladder | Measured | Unchanged; within ceiling at the launch ladder; a redeemer can split an exit. Confirm before any ladder extension. |
| INF-03 stale compiled artifact | Fixed | The public artifacts are regenerated at `52b206f` and `ea6c239`. |
| INF-09 nothing gated the shipped schedule | Acknowledged, pre-existing | Closed since: the schedule lives in a library the deploy script delegates to, and the bounds suite pins it. |

Everything else in round 3 (MIN-01 to MIN-11, MIN-13 to MIN-17, MIN-20, INF-01, INF-02, INF-04 to INF-08) is a
documentation, mirror, test-hygiene or by-design item that was closed in that round and that nothing since reopens.

### 5c. Rounds 1 and 2 — pre-audit rounds

- **Round 2** (the dynamic-fee curve surface, 35 findings): 34 were closed in that round. The one left open, **R2
  MA-02** (fee allocation between tiers was stake-independent, so a dust seat captured a whole tier's slice), is the same
  mechanism the auditor reported as 5.1 and is **closed by the 5.1 remediation**: occupancy weighting in the spread and
  the fill cap on every single-target credit. Nothing in this pass reopens a round-2 item.
- **Round 1** (the whole upgrade surface, pre-audit): every finding was closed in that round except INFO-03, a scope
  deferral that round 2 closed. **R1 MA-01** (a wallet claimed under the v1.0.2 `Ownable2Step` model would be bricked by
  the beacon swap, because the new implementation reads ownership from an empty multi-owner registry) was closed as **not
  applicable** on a census: no wallet has been claimed on mainnet. That census was re-confirmed on 2026-10-08 by the
  protocol's own statistics lab (zero confirmed claimed atom wallets under v1.0.2) and by the mainnet pre-flight of
  2026-10-07. The mechanism is real; the state it needs does not exist. The runbook keeps the gate: re-verify the census
  immediately before executing the upgrade batch.

---

## 6. Part B — round-4 findings against the shipped revision

### R4-01 — A wallet claimed under v1.0.2 is ownerless after the AtomWallet beacon swap, and the claim path stays open until execution — Medium — **Acknowledged by the owners on 2026-10-09, with an operational advisory**

**Lanes:** isolated Claude Fable 5.1 and isolated Claude Opus 5.5, independently. Fable reproduced it on a mainnet
fork against the live v1.0.2 code and by storage emulation in the unit harness; Opus reproduced it with the verbatim
v1.0.2 wallet source behind a real beacon and the real v1.1.0 warden, with a control showing that a wallet whose
claim was only pending at the swap stays claimable (the legacy `acceptOwnership` selector is gone, so such a user
claims again through the v1.1.0 paths). All reruns confirmed by the orchestrator. **Prior history:** round-1 `MA-01` (Major at
the time, on the assumption that claimed, value-holding wallets existed), closed as not applicable on a census of zero
claimed wallets with the instruction to re-verify the census before executing.

**Mechanism.** The v1.0.2 wallet records ownership in OpenZeppelin's namespaced `Ownable` slot and sets `isClaimed`
when the claimant accepts. The v1.1.0 wallet keeps `isClaimed` at the same slot but resolves `owner()` from a new
`_primaryOwner` slot, which every pre-upgrade wallet holds at zero, and gates every operation on the Coinbase
multi-owner registry, which only `completeClaim` seeds. `completeClaim` refuses a wallet whose `isClaimed` is set, and
the warden's four claim and grant paths refuse it too. After the beacon swap such a wallet has `owner() == 0`, an
empty owner registry, and no caller that can operate it: its TRUST balance and the atom's accumulated and future
wallet fees (claimable only by the wallet itself) are locked until a later beacon implementation reads the orphaned
slot.

**Precondition, and why it is not closed by the census alone.** No wallet on mainnet is claimed: the factory has
deployed one wallet, it is unclaimed, and the warden has emitted no claim event. The owner reconfirmed the zero from
the protocol's statistics lab on 2026-10-08. But the v1.0.2 `claimOwnershipOverAddressAtom` is permissionless and the
v1.0.2 warden has no pause: any user who creates the atom of their own address, deploys its wallet and claims it
before step 02 lands in the bricked state, and so does anyone who wants to create the dilemma deliberately at the cost
of gas. The census can therefore change between the pre-flight and the execution block, including during the 7-day
timelock.

**Impact and bounds.** Permanent for v1.1.0, temporary for the protocol: the state is recoverable by a further
7-day-timelocked beacon upgrade that reads the orphaned slot, because nothing in v1.1.0 overwrites it. The value at
risk is whatever the claimant put in the wallet plus the fee stream of an address atom they created themselves, so
the realistic loss is small and self-selected; the reputational cost of bricking a user who followed a permissionless
path is the larger exposure. No third party can lose funds. Medium.

**Closures considered.**
1. **Code.** A permissionless one-shot `migrateLegacyOwner()` on the new `AtomWallet` that requires `isClaimed` and a
   zero `_primaryOwner`, reads the legacy `Ownable` slot, requires it non-zero and not the warden, sets
   `_primaryOwner`, seeds the owner registry with that address and emits `ClaimCompleted`. About fifteen lines, pure
   restoration of what the orphaned slot says. It changes the beacon implementation's bytecode after the audit, so it
   is a round-2 item with its own regression (the lane's fork test, which fails against `ea6c239` and passes with the
   function) and a courtesy note to the auditor.
2. **Runbook.** Add to the step-02 pre-flight, at the execution block: enumerate deployed wallets (one today; the
   factory's deployment event is the index) and read `isClaimed()` on each; if any is claimed, stop and decide.
   Write the recovery path down: a later beacon upgrade carrying closure 1. This needs no bytecode change and is
   enough for the 2026-10-26 schedule.

**Disposition (owners, 2026-10-09).** Acknowledged without a code change. The census was repeated at block
8,908,249: one wallet deployed, unclaimed, no claim event ever emitted by the warden, and the wallet's only ownership
event is its initialization to the warden. No permissioned ownership transfer through the operator path will be made
before the upgrade, users are advised not to use the permissionless address-atom claim until v1.1.0 is live, and the
pre-flight repeats the scan at the execution block. The migration function is not planned: the orphaned slot
persists, so a wallet that nonetheless reaches the state is recoverable by a later beacon upgrade. Repointing the
live warden off MultiVault to close the window early was considered and rejected: the v1.1.0 `reinitialize` resolves
its own admin through that pointer, so it would add two more Safe transactions to the critical path for a
precondition that is false today.

**Regression.** `LegacyClaimFork.t.sol` and `LegacyClaimedWalletBrick.t.sol` from the Fable lane and
`Lane2LegacyClaimedWallet.t.sol` (with the verbatim v1.0.2 wallet source) from the Opus lane, preserved in the round's
working logs; the fork test is the regression for the migration function should it ever be needed.

### Items raised by the cold lane and dispositioned

#### R4-K-01 — Permissionless `deposit_for` pulls from the lock holder's standing allowance — rated blocking by the cold lane — **Known, by design (bug-bounty canonical #84653)**

**Lane:** cold GPT-6 Astra. **Status:** not a round-4 finding. The lane's sequence is correct: anyone can call
`deposit_for(holder, amount)` and the transfer source is `holder`, so a holder who keeps a standing WrappedTrust
allowance to TrustBonding can have liquid tokens pushed into their own lock until that lock's existing end. The
behaviour is the canonical Curve `VotingEscrow` semantic, inherited unchanged from the Stargate port: it is identical
in the live v1.0.2 implementation, the v1.1.0 delta adds only the NatSpec that documents it (`VotingEscrow.sol:369`),
the funds enter the victim's own lock, no end date moves, and the caller gains nothing. It was reported to the bug
bounty seven times (Immunefi #84653 canonical, Code4rena #103 closed invalid) and closed by design each time; the
protocol's answer is the one in the known-issues registry: size approvals to the lock, never grant an unbounded
allowance. The owner reconfirmed the intent on 2026-10-08. Recorded here because it was outside the accepted-behaviour
list the lanes were given, which is why the lane could not disposition it itself; it is added to that list for any
later round.

#### R4-02 — `reinitialize` pins the utilization carry to the upgrade epoch without carrying a balance — rated non-blocking by the cold lane, below threshold by the isolated lanes — **Low, acknowledged, runbook gate**

**Lanes:** all three, independently, from three angles (an upgrade epoch with no activity; step 03 landing in a later
epoch than step 02; the first action of an epoch landing between steps 02 and 03). **Status:** real mechanism,
unrealistic precondition, closed by two pre-flight reads. The Opus lane also suggested a single Safe MultiSend
for steps 02 and 03; the owners keep them as separate transactions executed back to back, which closes the same
windows in practice. `MultiVault.reinitialize` sets `lastSystemUtilizationEpoch` to the current epoch and writes nothing else. The
live launch implementation carries the previous epoch's system utilization into the current epoch on the first
deposit or redeem of that epoch, with no flag (`bd1c064`); the new implementation carries from the pinned epoch and
sets a flag that the live code never wrote. If the upgrade executes in an epoch that has seen **no** activity, the
pinned epoch holds zero and the first post-upgrade action either carries nothing (after step 03) or carries epoch
zero's value (before step 03); either way the upgrade epoch's system utilization starts from the wrong baseline, the
delta against the previous epoch goes negative, and TrustBonding scales that one epoch's emissions to the
`systemUtilizationLowerBound` floor (4,000 bps live). The remainder is reclaimed by the protocol; no principal and no
curve fee is touched, and the next epoch carries correctly. The precondition is zero deposits and redeems on mainnet
between the epoch boundary (2026-10-20 15:00 UTC for epoch 25) and the execution on 2026-10-26; the current epoch's
utilization was populated within hours of its boundary. The same mis-seed occurs if step 03 runs in a later epoch
than step 02 and a deposit lands between them (the carry then reads epoch zero's value). **Disposition (owners, 2026-10-09): acknowledged, runbook
gate.** Before executing step 02, check whether the epoch's carry has already happened
(`totalUtilization(currentEpoch())` is non-zero) and, if it has not, trigger it with any action, for example a small
deposit on any atom; execute steps 02 and 03 back to back in the same epoch (the next boundary after the planned
execution is 2026-11-03 15:00 UTC). Disagreement with the cold lane is one of weight, not mechanism.

### Below threshold (recorded, not findings)

From the isolated lanes, each verified against the source by the orchestrator:

- Between steps 02 and 03 nobody holds MultiVault's `PAUSER_ROLE` (v1.1.0 moves `pause` behind that role and only
  `reinitialize` grants it), so a pause in that window would need a `grantRole` from the admin first. The runbook
  executes the two steps back to back and plans no pause between them.
- The first deposit into one side of a triple on a non-default curve seeds the opposite side's vault with `minShare`
  ghost shares priced at the empty-curve price. On a supply-priced curve, the live offset progressive curve included,
  a seed landing in an opposite vault that already holds shares, which only terms migrated from v1 without that seed
  can present, under-collateralises it by about 1e11 wei at the current `minShare`. Pre-existing in v1.0.2, dust, and
  unrelated to the default curve, which stays the linear curve by deployment rule.
- The curve's custody NatSpec at the reviewed revision still describes a timelock owner while the launch owner is
  the Admin Safe; corrected in the public repository by the deploy-script sync commit `c13ffde`, which carries the
  owner change.
- Positions of about one to three wei cannot be exited, because each fee rounds up to a wei and the payout floor
  rejects a zero payout; v1.0.2 paid zero instead.

- The deposit quote walks the gross base and is blind to MultiVault's own fees, so a lump pays the next band's rate
  about 2.25% early; about 0.3% of the curve fee on a 100k deposit, protocol-favouring, documented in the source.
- MasterChef floor rounding can over-credit up to 1 wei per lot re-base while each credit leaves up to `stake / 1e18`
  wei unattributed; sub-wei per event, solvency held in every run.
- Sweep self-recovery at launch: a lone 10,000 TRUST depositor from empty pays 170.35 TRUST of curve fee and holds
  149.99 claimable at once; accepted by the owners, now quantified.
- A FeeProxy affiliate that sets its own fee recipient to the proxy strands its fees there; self-inflicted.
- Between steps 02 and 04 nobody holds the warden's admin role, so the warden cannot be paused in that window;
  address claims remain possible, which is their intended function.
- `claimAtomWalletDepositFees` on an unclaimed wallet would pay the warden, which has no `receive`; unreachable,
  since only the wallet can call it and an unclaimed wallet cannot be operated.
- The spread's exact-mode remainder (under `span` wei) is booked to the last credited tier; documented.
- Testnet wallets claimed under v1.0.2 will show `R4-01` during the rehearsal; treat that as the signal.
- The cold lane's reading of `R4-02` and the isolated lane's note on the same mechanism are merged above.

---

## 7. Properties checked — coverage evidence

Orchestrator verification at `ea6c239`, every Foundry run capped (`FOUNDRY_FUZZ_RUNS=32`, `FOUNDRY_INVARIANT_RUNS=8`,
`FOUNDRY_INVARIANT_DEPTH=128`, file-pinned invariant settings where present; no coverage run):

| Check | Result |
| ----- | ------ |
| Curve unit suites (`DynamicFeeFlatPriceCurve`, thirteen-tier example) | 119 passed, 0 failed |
| MultiVault-level dynamic-fee routing, hook detection, adversarial economics, gas profile, curve invariant; security suites (guardrails, redistribution bounds, split-edge, deposit neutrality); upgrade regressions (MultiVault, AtomWarden) | 157 passed, 0 failed, 7 skipped (the Safe-batch calldata parity suite skips while the batch files carry placeholder implementation addresses, which they do until the deploy script runs) |
| Stateful invariants against MultiVault (ghost shares preserved, holder shares never exceed total, native value conservation, no simultaneous counter-stake) | 4 passed at 32 runs × 50 calls, 0 reverts |
| Storage layout, `forge inspect` on the public `v1.0.2` tag and on `ea6c239`, read against the mainnet pre-flight's diff of the live verified builds | MultiVault: the live implementation is the Nov 2025 launch commit `bd1c064`, not the `v1.0.2` tag; its slots 0–32 are unchanged and v1.1.0 appends 33 (`hasRolledOverSystemUtilization`, present in the `v1.0.2` source but never deployed to mainnet), 34 `timelock`, 35 `atomCreators`, 36 `atomCreatedAt`, 37 `lastSystemUtilizationEpoch`, 38 `_atomUriConfig`, then a 46-slot gap. AtomWarden (live = `v1.0.2`): slot 0 identical, eleven slots appended, 50-slot gap after. AtomWallet (live = `v1.0.2`): `multiVault`, `_entryPoint` with the packed `isClaimed`, and `termId` identical at slots 0–2; `_primaryOwner` takes the first slot of the old gap, which the only deployed wallet holds at zero. TrustBonding and VotingEscrow (live = `v1.0.2` logic): identical. |
| Mainnet reads, chain 1155, public RPC, 2026-10-08 | Initializable version is 1 on the MultiVault, AtomWarden and TrustBonding proxies, so both version-2 reinitializers are admissible; the registry holds exactly the two curves the batch upgrades; `MultiVault.timelock` (slot 34) is zero, to be bootstrapped by `reinitialize`; `generalConfig.admin` is the Admin Safe; the wallet beacon points at the v1.0.2 implementation; the live MultiVault exposes no `hasRolledOverSystemUtilization`, `timelock` or `atomCreators` selector (selector probe of its runtime code), consistent with the `bd1c064` baseline; the current epoch is 24 and its system utilization is populated mid-epoch, so the live carry runs on the first action of an epoch. |
| Mutation M1: `_assertDefaultCurveIsHookless` removed from `setBondingCurveConfig` | 5 tests red in the MultiVault admin suite (unregistered default, deposit-hook-only, redeem-hook-only, both hooks, fresh registry); 25 green |
| Mutation M1b: `_assertDefaultCurveIsHookless` removed from `initialize` | 2 tests red (`testInitialize_RevertWhen_DefaultCurveHasFeeHook`, `…DefaultCurveNotRegistered`); 28 green |
| Mutation M2: affiliate paid before the routed call in `depositVia` (the 5.2 ordering reverted) | 1 test red (`test_affiliatePayment_runsAfterUserDeposit_recipientCannotRepriceProgressiveCurve`, the slippage-detected case); 10 green |
| Mutation M3: `_rebaseLots` removed from `recordRedeem` (exiter paid out of own fee) | 3 tests red (`exiterWithLotsAtSeveralTiersEarnsNothingAnywhere`, both cohort-fallback cases); 107 green |
| Mutation M4: the deposit spike's residue routed back into the kernel pool (the MA-03 shape) | 2 tests red (`spikeResidueAccruesInsteadOfRejoiningTheSpread`, `testFuzz_recordDeposit_perShareIncomeNeverExceedsTheScheduleRate` on its first run); 108 green |
| Mutation M5: the exiting-tier cohort no longer excludes the exiter's residual lot | 6 tests red (exclusion, both cohort-fallback cases, three reroute cases); 104 green |
| Control after every mutation (source restored) | 110 passed |

**Lane proofs of concept, rerun by the orchestrator in each lane's worktree under the same cap: Fable 21 of 21,
Opus 14 of 14.**

| File | Tests | Meaning |
| ---- | ----- | ------- |
| Opus: `Lane2LegacyClaimedWallet.t.sol` (verbatim v1.0.2 wallet behind a real beacon, real v1.1.0 warden) | 2 | `R4-01` reproduced: 4 TRUST in the wallet and 3 TRUST of accrued fees unreachable, every repair path reverts; control: a pending-only claim stays claimable |
| Opus: `Lane2CurveSequences.t.sol` | 2 (one fuzz, 32 runs × 160 steps; one 1,500-step run with 8 accounts) | lot ledger, per-operation conservation, exiter non-self-payment and solvency asserted after every step; maximum over-credit 0 wei over 1,188 fee-bearing operations; final drain solvent |
| Opus: `Lane2GasPassDifferential.t.sol` (curve at `52b206f` compiled alongside) | 1 (fuzz, 32 runs × 4 configurations) | `a7f6d9f` behaviour-preserving: every accumulator, lot, debt, mask, bucket and balance identical after every step, with the floor at 0, 500, 5,000 and 10,000 bps and both routing levers at their extremes |
| Opus: `Lane2CurveReplays.t.sol` | 3 | the auditor's 5.1 and 5.3 sequences replayed at the launch schedule: a 1-wei seat earns 0 from 643.6 TRUST of later fees; the 5.3 round trip leaves the stack at tiers 0–2 and its 288.1 TRUST redeem fee goes to the bucket; ten dust seats across the ladder earn 0 while full bands earn 3,149.8 TRUST |
| Opus: `Lane2Integration.t.sol` (real MultiVault and FeeProxy) | 6 | mixed multicall legs conserve value exactly and mirror the curve ledger; a redeem leg carrying value reverts; a re-entrant holder cannot spend the batch's value; a hostile affiliate recipient runs after the routed call; a third party cannot route into another user's position; create-then-first-hook-deposit in one batch |
| `LegacyClaimFork.t.sol` (mainnet fork at the regression block, live v1.0.2 code) | 1 | `R4-01` reproduced end to end: the v1.0.2 claim succeeds and `execute` works, the beacon swap leaves `owner() == 0` and an empty registry, `execute` and `addOwnerAddress` revert, 0.9 TRUST stays in the wallet |
| `LegacyClaimedWalletBrick.t.sol` (storage emulation) | 2 | `R4-01` reproduced; the control shows an unclaimed pre-upgrade wallet claims normally |
| `CurveAdversarial.t.sol` | 8 (one fuzz, 32 runs) | over-full tier ledger and ceilings, dust seat in a vacant band, tier-0 exit cohort cap, multi-lot quote agreement, deposit split-neutrality, sweep self-recovery quantified, floor applied by every gate, random-sequence ledger, solvency and ceiling: all refutations hold |
| `MulticallValue.t.sol` | 6 | mixed create, deposit, approve and redeem batch fully accounted; zero, over- and mis-allocation, value-bearing redeem legs, nesting and payout re-entry all rejected |
| `FeeProxyAdversarial.t.sol` | 4 | recipient runs after the routed call and cannot reprice, re-enter or touch the refund; refund fallback and `claimRefundTo`; delegated receiver needs both approvals; batch allocation rejects zero legs and gives dust to the last leg |

The lane also reran the stateful invariant suite (4/4) and the AtomWarden reinitialize regression on the fork.

**Not performed.** No fresh static-analysis sweep (the surface is a subset of round 2's, and round 3 did not change the
tool verdicts); no formal verification; no fork rehearsal of the batches in this pass (the mainnet pre-flight of
2026-10-07 did that and reported go).

---

## 8. Lane provenance

| #   | Lane                                     | Model / effort                                   | Unit reviewed                                        | Result |
| --- | ---------------------------------------- | ------------------------------------------------ | ---------------------------------------------------- | ------ |
| 1   | Isolated adversarial lane, own worktree  | Claude Fable 5.1, session effort inherited         | Whole scope at `ea6c239`, 21 PoC tests under scratch   | **FAIL** — `R4-01` (Medium, reproduced on a mainnet fork); 10 below-threshold notes; every other priority refuted with a running test. Interrupted once by an external pause and resumed with context intact. |
| 2   | Isolated adversarial lane, own worktree  | Claude Opus 5.5, session effort inherited          | Whole scope at `ea6c239`, 14 PoC tests under scratch   | **FAIL** — `R4-01` (Medium, reproduced with the verbatim v1.0.2 wallet behind a real beacon); 9 below-threshold notes; random-sequence runs with zero over-credit, a differential fuzz of `a7f6d9f` against its parent, replays of the auditor's 5.1 and 5.3 sequences, 6 integration tests. Started twice earlier and stopped during the scope read by external pauses; the reported run is a fresh start in a clean worktree. |
| 3   | Cold cross-model review, read-only       | GPT-6 Astra, xhigh (codex-cli 0.161.0)              | Whole scope at `ea6c239` plus the remediation delta    | Approve: no — 1 "blocking" (`R4-K-01`, known by design), 1 non-blocking (`R4-02`); 19 refuted hypotheses with line references; every remediation judged to close its class. |
| 4   | Orchestrator verification                | Claude Fable 5.1                                   | Suites, invariants, layouts, mainnet reads, mutations  | §7 |

**Lane construction.** Lanes 1 and 2 received the identical brief described in §2 and nothing else, except that lane
2's copy carried one more line on the accepted-behaviour list (`deposit_for`, added after the cold lane re-raised it;
see `R4-K-01`); the Agent tool pins the model but not the reasoning effort, which is inherited from the orchestrating
session. Lane 3 received the project's
cold PR-review prompt extended with the same scope, priorities, trust model, threshold and accepted-behaviour list; its
first attempt exhausted the account's usage window after reading the sources once and was rerun after the reset with a
stated reading order.

**Lanes carried from pass 3 and lanes dropped.** Pass 3 ran isolated Claude rubric lanes, cold GPT-family lanes and two
hosted GitHub Copilot PR reviews. The isolated Claude lane is carried, now run on two model families. The cold lane is
carried on GPT-6 Astra, the strongest model the CLI offers; the GPT-5.6 Sol and Terra lanes it replaced produced their
value in pass 3 and add no diversity next to Astra. Copilot is dropped: it needs an outward write on the public pull
request, and in pass 3 its nine comments were all TypeScript and documentation items with two refuted, so it carries no
signal for a contract-only scope.

**Disagreements carried.** The cold lane rated `deposit_for` blocking; this report records it as known and by design
on the strength of the bug-bounty adjudication and the owner's confirmation, and notes that the lane could not know
that because the accepted list omitted it. The cold lane rated the reinitialize carry non-blocking and both isolated
lanes rated it below threshold; this report rates it Low with a runbook gate, which is the strictest of the three.
Both isolated lanes rated `R4-01` Medium independently; round 1 had rated the same mechanism Major on a different
assumption about the state; this report keeps Medium because the state is recoverable by governance and
self-selected.

---

## 9. Residual risk

1. **`R4-01` until step 02 executes.** The window stays open until then; the advisory and the pre-flight scan bound
   it, and a later beacon upgrade can repair a wallet that slips through. The testnet rehearsal will show the same mechanism on any testnet wallet claimed under v1.0.2.
2. **One epoch of emissions at the floor** if the two `R4-02` reads are skipped and the precondition happens to hold.
3. **What four passes on three families missed.** The two isolated lanes agree on every priority and on the one
   Medium, the cold lane's two items are dispositioned, and the orchestrator's evidence covers the same surface; the
   residual is whatever none of them reached, which is the irreducible risk this pass exists to shrink, not to remove.
4. Carried from round 3: protocol accrual is bounded but not zero; worst-case redeem gas grows with a thin ladder;
   two event semantics changed with unchanged signatures and the indexer realignment must absorb them; the curve's
   fresh-deployment constraint is a runbook rule; two TypeScript shapes changed.
5. `deposit_for` remains the canonical Curve semantic: holders should size allowances to the lock.

## 10. Gate

**Go for the 2026-10-26 schedule, with three runbook additions.** No Critical or High. The one Medium, `R4-01`, has
a precondition that is false on mainnet today, re-verified the day of this report, and is acknowledged by the owners
with an operational advisory and a repeat of the scan at the execution block. The one Low, `R4-02`, is acknowledged
and closed by two reads in the pre-flight. Every remediation of the final report is present at the shipped revision
and mutation-checked. The two-round cap on an unchanged diff applies: this is round 1, and a second round is permitted
only on a fix that changes the diff.

**Runbook additions, for the sign-and-schedule owner.**
1. Before step 02: enumerate the deployed wallets from the factory's deployment event and assert `isClaimed()` is
   false on each; stop and decide if one is claimed.
2. Before step 02: check that the current epoch's utilization carry has happened (`totalUtilization(currentEpoch())`
   non-zero) and, if not, trigger it with any action, for example a small deposit on any atom.
3. Execute steps 02 and 03 back to back in the same epoch; no pause is planned between them, and any pause there
   needs a `grantRole(PAUSER_ROLE)` first. Write the recovery path for a claimed v1.0.2 wallet (a later beacon
   upgrade reading the orphaned owner slot) into the rollback section.

No follow-up contracts change is planned from this round.
