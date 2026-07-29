# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2 — MASTER Consolidated Report

> **Artifact type:** Internal AI pseudo-audit — **consolidated master**. This is a **pre-audit artifact — not a formal
> audit, certification, warranty, or guarantee of safety.** It de-duplicates the findings of the independent AI review
> reports listed in the appendix into one release-level, Diligence-style view, and is the go/no-go input handed to the
> external auditors alongside the per-round reports. Findings stay internal until remediated.

|                     |                                                                                                                                                                                                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Reviewed commit** | `8579c5e02e6fd1b58620565d5a6d06d3b9391548` / `ac567b2ecd03d12e3e27c0ce570381ef9e383196` (branch `feat/v1.1.0-core-upgrade`, PR #153) — **`src/` is byte-identical between the two**; `git diff 8579c5e..ac567b2 -- src/` is empty         |
| **Differential**    | `git diff b52557bc5d1e87537e621fc13917240d40044c24...<COMMIT>` — 30 source files, +1,537 / −875                                                                                                                                           |
| **Repository**      | `intuition-contracts-v2` (public mirror) — v1.1.0 core upgrade                                                                                                                                                                            |
| **Toolchain**       | Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun` (EIP-1153), OpenZeppelin `5.4.0`, solady; TransparentUpgradeableProxy throughout                                                                                                         |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                                                                                                                                          |
| **Date**            | 2026-07-28                                                                                                                                                                                                                                |
| **Reports merged**  | 6 independent reports: 2 vanilla (frontier, cross-model) + 4 skill-driven (single-reviewer checklist, per-contract multi-agent checklist, specialist-selection multi-agent, parallel attacker lenses). See the appendix provenance table. |
| **Prior round**     | [`../round-1/MASTER-consolidated-report.md`](../round-1/MASTER-consolidated-report.md) — reviewed `b52557b`; 0 Critical, 1 Major, 4 Medium, all dispositioned                                                                             |
| **Burn sink**       | `BURN_ADDRESS` = `0x000000000000000000000000000000000000dEaD` (ghost/min-share recipient), resolved from `MultiVaultLib`                                                                                                                  |

---

## 1. Executive summary

Round 1 closed with one item explicitly deferred: the **dynamic-fee curve economy and the standardized fee-hook surface
did not exist** at the reviewed commit, and round 1's go/no-go section recorded that this was "the most novel
funds-touching surface in the pipeline" with **zero audit coverage**. Round 2 is that audit. The surface has now merged,
six independent reviewers took it whole-contract, and **it is where every Major finding in this round lives**.

**Headline result: 0 Critical. 5 Major. 8 Medium.** That is a materially worse result than round 1 (1 Major, 4 Medium),
and the shape of the difference is the point. Round 1's single Major was a migration-safety defect closed by an on-chain
census. Round 2's Majors are defects in a newly written fee kernel, and **three of the five are permissionless** —
exploitable by any account, with no privileged role, no governance action, and no configuration change.

**The permissionless cluster is the release-blocking result.** Three independent mechanisms in
`DynamicFeeFlatPriceCurve` share one root theme: _tier entitlement is decoupled from the capital and the commitment
behind it._

- Fee slices are allocated **between** tiers by kernel weight alone; a tier's stake is consulted only as a boolean
  occupancy test. A tier holding **one wei** stands as a full-weight recipient beside a tier holding thousands of TRUST.
  Reproduced: a 1-wei position out-earned an 11.12 TRUST position by 1.5×, taking 60% of a deposit fee (`MA-02`).
- `recordRedeem` never re-derives the redeemer's bucket, so a position stripped to dust **keeps its tier seat
  indefinitely**, through retunes. Reproduced: a 1-wei co-occupant captured **100%** of a departing holder's withdrawal
  fee (`MA-03`).
- Entitlement vests instantly at deposit — there is **no dwell requirement at all**. A minimum-size deposit front-run
  into the same block as a visible redeem captures ~100% of that exit fee and unwinds in the same bundle. Measured
  realized return: **+221% on 0.1 TRUST in a single transaction, at zero price risk**, with a counterfactual run
  confirming the value would otherwise have accrued to a holder who had been in the vault since before the exiting party
  entered (`MA-04`).

These invert the mechanism the fee economy exists to implement. The shipped schedule makes them _worse_, not better:
`withdrawalToRecentShareBps = 0` routes the **entire** withdrawal fee down the capturable path.

The remaining two Majors are configuration-reachable rather than permissionless, but both end in **irreversible user
loss with no on-chain repair path**, which is why they are not filed as centralization complaints:

- The atom and triple **creation** paths mint vault shares without ever invoking the curve's record hook. Pointing
  `defaultCurveId` at a fee-hook curve — the obvious next step once the fee economy is proven — makes every subsequently
  created position **permanently unredeemable**, underflowing inside the curve on a ledger entry that was never written.
  No function can seed or repair it, the registry is append-only, and reverting the configuration does not help. **Five
  of six reports reached this independently** — the highest-signal finding of the round (`MA-01`).
- A withdrawal rate **strictly below the curve's own configured cap** burns a holder's shares for a **zero payout
  without reverting**, and `MultiVault` enforces no floor. Composed with a curve fee surface that is plain `onlyOwner`
  with immediate effect — while every equivalent `MultiVault` setter is `onlyTimelock` — one transaction confiscated a
  victim's full principal and routed it to a co-positioned account that withdrew it (`MA-05`).

**A structural note the round earned.** The accepted trust model for this upgrade is a 4-of-8 Safe behind two
`TimelockController`s, and "a trusted admin can do X" is out of scope on that basis. Two reports independently
established that **the precondition does not hold for the new curve**: its privileged surface is not timelock-gated in
code, and the shipped deploy script assigns ownership to the broadcasting EOA on every chain including mainnet
(`MED-01`). Several other findings are risk-rated against an assumption the deployment does not currently satisfy.

**Where the round agrees the code is sound.** The MasterChef accumulator's _arithmetic_ held under sustained attack from
every report that examined it: fee conservation, depositor/exiter exclusion, quote-versus-record equality, and
flat-price par were each attacked and each survived with a cited defence. Value conservation, the `multicallPayable`
transient-value machinery, the `MultiVaultLib` storage mirror (byte-exact across all 38 fields), and the reentrancy
surface opened by the new hooks were all probed and held. **The defects are in the distribution _shape_ and the trust
boundary around the kernel, not in its arithmetic** — a distinction worth carrying into remediation, because it means
the fix is economic design, not a rounding correction.

**Both round-1 code fixes verify, with working mutation checks, in five independent reports.** Removing the ERC-1271
digest binding makes a signature over the raw unbound digest validate; removing the emissions-length guard lets a zero
epoch length initialize. Both gating tests go red on mutation and green on restore. One caveat is recorded as `MIN-03`:
under a _permissive_ mutation — accept the envelope **or** the bare digest, the shape a "keep old signatures working"
refactor would take — all 122 pre-existing wallet tests stay green.

**Round 1's disposition register holds up.** Round 2 re-raised four dispositioned items. Three are duplicates whose
dispositions stand, including a **formally attempted and failed** override of round-1 `MA-01`. One — round-1 `INFO-04` —
is **partially reopened**: its closure rationale asserts the layout is pinned by the CI storage-layout suite, and round
2 mutation-proved that suite does not pin intra-struct field order. See §5a.

**Severities below are as-found — the severity each finding reached in the reports that raised it.** They are
deliberately not revised downward by triage, so the raw signal survives. **Every finding now carries a disposition**, in
the register at **§5b**: 24 closed (2 fixed as documentation, 2 not applicable, 8 by design, 12 acknowledged) and 11
open. Read §5b for what the protocol team is actually doing about each one; read the findings for what was found. The
two differ, and both matter.

The most important framing fact, and the reason nothing here is an incident: **the dynamic-fee curve is not deployed or
registered on Intuition Mainnet** — verified on chain `1155`, the registry holds two curves and `defaultCurveId == 1`.
Every Major is a defect in a contract that has not shipped, found before it shipped.

### Findings by severity (consolidated, de-duplicated)

| Severity      | Count | Consolidated IDs  |
| ------------- | ----- | ----------------- |
| Critical      | 0     | —                 |
| **Major**     | **5** | MA-01 … MA-05     |
| **Medium**    | **8** | MED-01 … MED-08   |
| Minor         | 12    | MIN-01 … MIN-12   |
| Informational | 10    | INFO-01 … INFO-10 |

_The six reports emitted ~100 raw findings including per-contract hygiene, open questions, and negatives. This master
carries **every Medium and above in full**, plus the load-bearing Minor/Informational tail. The full raw sets stay in
the per-round reports and the working logs kept in the private monorepo._

**Of the 5 Majors, 3 are permissionless** (`MA-02`, `MA-03`, `MA-04`) and 2 are configuration-reachable with
irreversible outcomes (`MA-01`, `MA-05`).

---

## 2. Scope

**In scope (v1.1.0 core, Intuition-chain, at the reviewed commit).** Primary weight on the two surfaces that carried
**zero prior audit coverage**:

- **C1 — the fee economy:** `DynamicFeeFlatPriceCurve`, `IDynamicFeeFlatPriceCurve`.
- **C2 — the standardized hook surface and its dispatch:** `IBaseCurve`, `BaseCurve`, `BondingCurveRegistry`,
  `LinearCurve`, and the `CurveHook` quote-carry dispatch in `MultiVaultLib`.

Swept at whole-contract depth alongside them: `MultiVault`, `MultiVaultCore`, `MultiVaultLib`, `AtomWallet`,
`AtomWalletFactory`, `AtomWarden`, `CoinbaseSmartWalletLib`, `TrustBonding`, `CoreEmissionsController`,
`SatelliteEmissionsController` (Intuition-side accounting only), `FeeProxy`, and the in-scope interfaces. The **30-file
delta** since the round-1 baseline was swept as its own cluster; deploy scripts under `script/` were read to establish
the shipped configuration and are cited where a finding depends on it.

**Out of scope (unchanged from round 1):** Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain
transport leg; `BaseEmissionsController` and all Base-chain components; the deliberately parked TVL exit rate limiter
(its absence is a decision, not a gap); unbounded cross-curve counter-stake aggregation; `MultiVaultMigrationMode`;
legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow`; the held-out `AtomWallet` delegation framework
(`executeFromExecutor`); `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib` pricing math, in
scope only insofar as they must remain safe hook no-ops; and whole-surface `multicallPayable` batching mixing payable
and non-payable legs (attacking the wall was in scope; requesting its removal was not).

**Trusted-admin centralization is an accepted trust assumption** — privileged actions are gated by a 4-of-8 Safe acting
through two `TimelockController`s (parameters 3-day, upgrades 7-day). "A trusted admin can do X" is not filed. What _is_
filed, throughout, is the narrower case where a **routine, individually reasonable** privileged action silently and
**irreversibly** destroys user value with no guard and no warning, or where **the deployment does not actually place a
privileged function behind that accepted structure**. `MA-01`, `MA-05`, `MED-01` and `MED-05` are filed on that basis
and each says so explicitly.

**Coverage caveats — stated plainly.** Two reports declared material limits, and they bound how much weight the clean
results carry:

1. One report's per-contract mode returned **uneven depth**: its `MultiVaultLib` review was **static-analysis only** —
   no compiling test tree, no PoC, no mutation-check — and four of its ten reviewers declared partial or absent
   checklist walks. Its C1 verdict is explicitly marked "PASS (provisional — checklist walk and mutation-checks not
   performed)", and C1 is precisely where three other reports found Majors.
2. One report did not complete the 30-file delta cluster hunk-by-hunk (`FeeProxy`, `TrustBonding`, `MultiVaultCore`,
   `AtomWarden` and the interface deltas were not read as a diff), and recorded two hypotheses as reasoned-but-unproven
   rather than as passes.
3. **No static-analysis pass contributed to this round.** Slither could not run on the review host (the compile driver
   forces an artifact download the sandbox blocks with HTTP 403, even when a local `solc` binary is supplied). One
   report's Medusa campaign did not reach property execution. Findings come from source reading, hand-derived
   arithmetic, and executed Foundry probes.

---

## 3. Severity classification

Impact × Likelihood, using the Diligence house labels, taking the **highest severity a credible path reaches** under the
intended deployment and trust model. Permissionless exploitability is separated from trusted-configuration reachability
throughout, and each finding states which applies. Where reports genuinely disagreed, **the higher severity is carried
and the disagreement is stated in the finding** — see §7 for the consolidated list of disagreements.

| Severity          | Use when                                                                                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                                |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing or DoS of a funds path, admin footgun, or a spec regression materially affecting users or operators. |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behaviour, monitoring or integration weakness.                                           |
| **Informational** | Documentation, hygiene, NatSpec-versus-behaviour mismatch, or missing non-critical test coverage.                                                            |

---

## 4. Load-bearing invariants (the properties every report attacked)

Carried unchanged from round 1, so the two rounds' negatives compose:

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

Round 2 adds a seventh, implied by the new surface and used to rate `MA-02` / `MA-03` / `MA-04`:

7. **Redistribution fidelity** — a fee promised to a cohort reaches that cohort **in proportion to the stake and the
   commitment that earn it**. Invariants 1 and 2 can hold exactly while this one breaks: the fee has _a_ home, just not
   the promised one.

---

## 5. Consolidated findings (de-duplicated; highest severity first)

Each finding lists the contributing per-report ids so provenance survives the merge. **Rounds reached** counts how many
of the six independent reports surfaced it — a proxy for signal strength, not for severity.

---

### MA-01 — Creation paths mint fee-hook-curve shares without recording them; a `defaultCurveId` retarget strands every subsequent position permanently — Major

**Provenance:** `R2-CLD-01` = `R2-TOB-02` = `R2-HMN-02` = `R2-CYF-01` (+ `R2-CYF-XC-01` facet 1) = `R2-PAS-03` ·
**Rounds reached: 5 of 6** · **Cluster:** C2 / B · **Confidence:** High · **Status:** Open (as found) **Invariant
broken:** §4.3 (curve ledger mirrors vault shares); secondarily §4.2.

**Mechanism.** The curve's redeem hook decrements a per-user ledger entry that only the **deposit** hook ever writes.
`_recordCurveDeposit` has **exactly one call site in the entire library** — inside `_processDeposit`. The four term
creation entry points (`createAtoms`, `createAtomsFor`, `createTriples`, `createTriplesFor`) mint vault shares on the
**default** curve via `_updateVaultOnCreation` and never resolve a `CurveHook` at all. While the default curve is
hookless this is consistent. The moment `defaultCurveId` points at a curve that advertises the hooks, every term created
afterwards mints vault shares with **no corresponding curve-ledger entry**, and the holder's first redemption of any
size underflows inside the curve.

The interface documents the opposite in terms. `src/interfaces/IBaseCurve.sol:148-152` states that on a hook curve
`recordDeposit` "is ALWAYS called, even when the quoted fee is zero, so the curve ledger stays in lockstep with vault
shares."

**There is no recovery path.** The curve exposes no function to seed or repair `userStake` / `tierStake` /
`vaultAssets`; the vault shares exist and can never be burned; `BondingCurveRegistry` is strictly append-only so the
curve id cannot be re-pointed; and pointing `defaultCurveId` back at a hookless curve does not help, because the
affected vaults are keyed to the hook curve's id. `previewRedeem` returns a plausible non-zero number and gives no
warning that execution will revert.

**Code.**

```solidity
// src/libraries/MultiVaultLib.sol:771 — the ONLY _recordCurveDeposit call site, on the deposit path
_recordCurveDeposit(termId, receiver, hook, sharesForReceiver);

// src/libraries/MultiVaultLib.sol:568,577 (atom) and :646,654 (triple) — creation: default curve, no hook dispatch
uint256 curveId = s.bondingCurveConfig.defaultCurveId;
_updateVaultOnCreation(sender, atomId, curveId, assetsAfterFees, sharesForReceiver, VaultType.ATOM);

// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:414-416 — the underflow site
userStake[termId][account] -= withdrawnStake;   // Panic(0x11) when never recorded

// src/protocol/MultiVault.sol:825-828 — no guard on the target curve
function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyTimelock {
    bondingCurveConfig = _bondingCurveConfig;
    emit BondingCurveConfigUpdated(_bondingCurveConfig.registry, _bondingCurveConfig.defaultCurveId);
}
```

**Proof of concept.** Executed independently by four reports against clean checkouts. Representative reading after
`setBondingCurveConfig` retargets `defaultCurveId` at the dynamic-fee curve and a user creates an atom with `10e18`
through the ordinary `createAtoms` path:

| Reading                                   | Value                                                          |
| ----------------------------------------- | -------------------------------------------------------------- |
| Creator's vault shares on the curve id    | `9 799 019 999 999 020 000`                                    |
| Creator's `userStake` on the curve        | `0`                                                            |
| Curve's `vaultAssets` mirror for the term | `0`                                                            |
| `redeem(...)` of half the position        | reverts `0x4e487b71…0011` — `Panic(0x11)` arithmetic underflow |

A second report's 7-test PoC (`CurveHookDispatchCompleteness.t.sol`) adds two results that sharpen it: **every** redeem
size panics, not merely large ones (`redeem(..., 1, 0)` reverts identically); and **the desync does not self-heal** — a
later deposit credits the ledger only for the deposited amount, so redeeming the full balance still panics.

**Refutation attempted, and failed.** One report tried to reach the same desync **without** touching `defaultCurveId`
and could not: `BondingCurveRegistry.addBondingCurve` rejects duplicate addresses and duplicate names and no function
overwrites `curveAddresses[id]`; `MultiVault` exposes no share-transfer function; shares are non-transferable; and the
only uncovered mint is to `BURN_ADDRESS`, which cannot be redeemed from. The registry-swap variant — replacing the whole
`registry` address with one mapping the same id to a different curve — reaches the same class of desync and needs the
same guard (see `MED-05`).

**Independently verified for this master.** `grep -n "_recordCurveDeposit" src/libraries/MultiVaultLib.sol` returns a
single call site at `:771` plus the definition at `:851`; the creation path at `:547`/`:629` reaches
`_updateVaultOnCreation` with no hook resolution; `setBondingCurveConfig` performs no validation of either field.

**Severity disagreement — stated.** Three reports rated this **Major**; two rated it **Medium**, on the ground that the
state is not permissionlessly reachable and requires the timelocked `setBondingCurveConfig` write. **Carried at Major**
per §3: the trigger is a routine, individually innocuous parameter change with no on-chain guard and no warning, the
outcome is permanent and irrecoverable user fund loss rather than a revert at configuration time, and the interface
NatSpec actively tells a maintainer the opposite is true.

**Recommendation.**

1. **Preferred — close the asymmetry.** Resolve `_depositFeeHookCurve(defaultCurveId)` in `_calculateAtomCreate` /
   `_calculateTripleCreate` and call `_recordCurveDeposit` from `_createAtom` / `_createTriple`. This is what the
   interface already promises, and it removes the constraint entirely rather than fencing it.
2. **Or — reject the configuration.** In `setBondingCurveConfig`, require the target default curve to advertise neither
   hook:

   ```solidity
   address defaultCurve = IBondingCurveRegistry(_bondingCurveConfig.registry)
       .curveAddresses(_bondingCurveConfig.defaultCurveId);
   if (defaultCurve == address(0)) revert MultiVault_InvalidDefaultCurve();
   if (IBaseCurve(defaultCurve).hasDepositFeeHook() || IBaseCurve(defaultCurve).hasRedeemFeeHook()) {
       revert MultiVault_DefaultCurveMustBeHookless();
   }
   ```

3. Either way, state the invariant explicitly in `IBaseCurve.recordDeposit`'s NatSpec — which currently asserts the
   opposite — and correct it if (2) is chosen.

**Regression test.** `DefaultCurveHookExclusion.t.sol` / `CurveHookDispatchCompleteness.t.sol` — assert a term created
through **every** create path on a hook curve is redeemable, or that `setBondingCurveConfig` rejects a hook-advertising
default curve. Mutation-check by removing the guard.

**Variant sweep.** `createAtoms` / `createAtomsFor` / `createTriples` / `createTriplesFor` — all four affected ·
`deposit` / `depositBatch` — safe, both branches record · `previewRedeem` — worse than the bug, quotes a payout for an
unredeemable position · `FeeProxy` router — same bug, it composes creates · ghost shares to `BURN_ADDRESS` — correctly
excluded by design · upgrade initializer — n/a.

**Not live today.** The deployed configuration is `defaultCurveId: 1` (`LinearCurve`, hookless, 1:1).

---

### MA-02 — Fee redistribution is stake-independent between tiers, so a dust position captures a whole tier's slice — Major

**Provenance:** `R2-PAS-01` = `R2-HMN-01` (facet) · **Rounds reached: 2 of 6** · **Cluster:** C1 · **Confidence:** High
· **Status:** Open (as found) · **Invariant broken:** §4.7 (redistribution fidelity); §4.1 in its promise sense.
**Permissionless.**

**Mechanism.** The triangular fulcrum kernel decides how a deposit fee is split **across** prior tiers using the kernel
weight alone. A tier's stake is consulted only as a **boolean occupancy test** — it gates whether the tier participates,
but never scales how much the tier receives. The per-tier slice is then divided by that tier's stake to form a per-share
accumulator, so _within_ a tier the split is correctly pro-rata; _between_ tiers it is not.

A tier holding one wei is therefore a full-weight recipient standing beside a tier holding thousands of TRUST, and the
single dust holder absorbs that tier's entire slice.

The bucket is trivially and permanently squattable because `recordRedeem` never re-derives `userTier` or `userAvgTier`
(the shared enabler with `MA-03`). A holder enters a tier, withdraws all but one wei, and keeps the seat indefinitely —
through retunes, since the accumulators are index-keyed and never migrated.

**Code.** `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:661-687` — the weight ignores stake magnitude:

```solidity
uint256 recipientStake = tierStake[termId][targetTier];
if (targetTier == excludeTier) { recipientStake -= excludeStake; }
stakes[d - 1] = recipientStake;
if (recipientStake > 0) {                                   // stake is only a boolean gate
    uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma);
    weights[d - 1] = w;                                     // weight depends only on distance
    sumWeights += w;
}
```

`:636-657` — the slice is allocated by weight only:

```solidity
uint256 share = pool.mulDiv(w, sumWeights);                 // independent of stakes[d - 1]
if (share > 0) {
    accFeePerShare[termId][span - d] += share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
    assigned += share;
}
```

Supporting: `:401-452` (`recordRedeem` writes neither `userTier` nor `userAvgTier`) and `:614` (`dStar = 0` under the
shipped `fulcrumAlpha = BPS`, placing the peak on the nearest prior tier).

**Proof of concept.** Executed against a pristine checkout (`git diff --quiet -- src/` asserted before the run) using
the repository's own `BaseTest` fixture. A large holder reaches bucket 0 with ≈5.82 TRUST; the attacker deposits 3
TRUST, then immediately redeems all but **1 wei** — the seat survives. State before the fee event:
`tierStake[0] = 11121671249999039674`, `tierStake[1] = 1`. A third party then deposits 50 TRUST:

| Recipient    | Stake                                 | Fee received         | Share     |
| ------------ | ------------------------------------- | -------------------- | --------- |
| Attacker     | **1 wei**                             | `831610027499994238` | **60.0%** |
| Large holder | `11121671249999039674` (≈11.12 TRUST) | `554406684999996153` | 40.0%     |

The attacker's setup cost is one round trip, recovered by the first fee event; the position is then permanent. Bucket
placement is directly controllable, since `userAvgTier` is the stake-weighted mean of entry bands and `depositBatch` /
`multicallPayable` allow two legs at two different vault bands in one transaction.

A second report reached the same shape independently by execution: a 0.01 TRUST position captured the whole 0.9 TRUST
exit fee of a 15 TRUST holder who was the last occupant of their own tier — a **90× return on stake**, funded entirely
by the exiting holder. It also noted the same shape lets a holder running two addresses **refund their own withdrawal
fee in full**, paying an effective 0% exit rate where a single-address holder pays 2–8%.

**Independently verified for this master.** `_weighPriorTiers` at `:661-687` confirms `recipientStake > 0` gates
participation while `w` derives solely from `_fulcrumDistance(d, dStar)`; `recordRedeem` (`:401-452`) only **reads**
`userTier` as `exitTier` and never writes it.

**Recommendation.** Make the between-tier allocation stake-weighted, so the kernel modulates a per-unit-stake payout
rather than distributing per-bucket lumps:

```solidity
// in _weighPriorTiers
uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma).fullMulDiv(recipientStake, WAD);
weights[d - 1] = w;
sumWeights += w;
```

This preserves the tent shape and the sliding fulcrum while removing the dust arbitrage. Pair it with the `userTier` /
`userAvgTier` re-derivation in `MA-03`.

**Before landing — an open question for the protocol team.** This changes the economics encoded in the executable model
the curve was ported from. **Confirm with the modeling work that per-bucket lump allocation was not deliberate.** If it
_was_ deliberate, the dust-squatting consequence still needs an explicit mitigation, and the disposition should be
recorded as such rather than as a fix.

**Regression test.** `CurveFeeTierWeightProportionality.t.sol` — for two occupied tiers at equal kernel distance, assert
the ratio of credited fee equals the ratio of tier stake, and that a 1-wei tier cannot out-receive a tier holding orders
of magnitude more.

**Variant sweep.** Single deposit — same bug · `depositBatch` — same bug, and the cheapest bucket-placement primitive ·
on-behalf creates — n/a, creates never invoke the hook (see `MA-01`) · preview — n/a, does not distribute · `FeeProxy`
router — same bug, inherited through `MultiVault.deposit` · retune — same bug, `setConfig` cannot migrate index-keyed
buckets.

---

### MA-03 — A one-wei co-occupant captures 100% of an exiting holder's withdrawal fee — Major

**Provenance:** `R2-PAS-02` = `R2-HMN-01` (facet) · **Rounds reached: 2 of 6** · **Cluster:** C1 · **Confidence:** High
· **Status:** Open (as found) · **Invariant broken:** §4.7; §4.1 in its promise sense. **Permissionless.**

**Mechanism.** The diamond-hands slice of a withdrawal fee is credited to the exiting holder's tier with the exiter's
own residual correctly excluded from the denominator — but **nothing bounds what remains**. If the only other occupant
of that tier holds one wei, that dust position becomes the sole recipient of an arbitrarily large exit fee.

This needs **no tier engineering at all**: the attacker simply deposits into the same band as the target, which is the
default outcome of depositing into a young vault. It shares the sticky-bucket enabler with `MA-02` — `recordRedeem`
never rewrites `userTier` / `userAvgTier`, so a position stripped to dust keeps its seat.

A second reachable variant follows from the same root: when the exiter is the **sole** occupant, `_nearestOccupiedTier`
searches **above first** and awards the whole slice to the first occupied bucket found, divided by that bucket's stake.
Parking one wei one bucket above a known large holder captures their entire exit fee.

**Code.** `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:419-442`:

```solidity
uint256 denom = tierStake[termId][exitTier] - residual;     // exiter excluded, remainder unbounded
if (toTier > 0) {
    if (denom > 0) {
        accFeePerShare[termId][exitTier] += toTier.fullMulDiv(ACC_PRECISION, denom);
    } else {
        (uint256 recipientTier, uint256 recipientStake) = _nearestOccupiedTier(termId, exitTier);
```

Supporting: `:769-786` (`_nearestOccupiedTier`, above-first scan) and `:401-452` (`recordRedeem` never rewrites the
bucket).

**Proof of concept.** Executed against a pristine checkout. A holder deposits 4 TRUST into a fresh atom vault (bucket 0,
≈3.88 TRUST); the attacker deposits 3 TRUST — also bucket 0, the vault is still below `width0`, **no targeting
required** — then redeems all but 1 wei. The holder exits:

```
before the whale exit:  tierStake[0] = 3879999999999030001
withdrawal fee released                 77579999999980600 wei
attacker stake                                          1 wei
attacker share of the fee               77579999999980600 wei  (10000 bps = 100%)
```

**The shipped default makes this total, not partial.** `withdrawalToRecentShareBps = 0` routes the **entire** withdrawal
fee down this path. Scaling linearly, a 100 TRUST exit at the shipped withdrawal schedule yields ≈2 TRUST to a 1-wei
position.

**Recommendation.** Two complementary changes:

1. **Re-derive `userTier` and `userAvgTier` on redeem**, so a position reduced to dust loses its tier standing rather
   than retaining it for free. This closes the enabler shared with `MA-02`.
2. **Require the post-exclusion denominator to be economically meaningful** before crediting it — a minimum eligible
   stake, or a floor expressed as a fraction of `vaultAssets[termId]` — falling through to the existing
   `_nearestOccupiedTier` / `protocolAccrued` path otherwise, which already handles the `denom == 0` case.

Note that (1) and (2) together still do **not** close `MA-04`; that needs its own fix.

**Regression test.** `ExitFeeResidualCohortEligibility.t.sol` — assert a holder whose stake is a negligible fraction of
the exiting tier cannot receive a materially disproportionate share of an exit fee, and that a redeem re-derives the
redeemer's bucket.

**Variant sweep.** Single redeem — same bug · `redeemBatch` — same bug per leg · on-behalf-of — same bug, books to the
receiver · preview — n/a · `FeeProxy` — n/a, exposes no redeem surface · retune — same bug, bucket seats are index-keyed
and never migrated.

---

### MA-04 — Tier entitlement has no dwell requirement, so a front-run minimum deposit captures a departing holder's exit fee — Major

**Provenance:** `R2-PAS-16` · **Rounds reached: 1 of 6** · **Cluster:** C1 · **Confidence:** High · **Status:** Open (as
found) · **Invariant broken:** §4.7 (new class — conservation and solvency both hold exactly). **Permissionless.**

**Mechanism.** A position's entitlement to a tier accumulator is established at `recordDeposit` time, when `rewardDebt`
is set against the tier's current `accFeePerShare`. There is **no dwell requirement of any kind**, so a position opened
in the immediately preceding transaction earns exactly as much per unit of stake as a position held for a year.

Because the withdrawal fee is credited by dividing across the recipient tier's stake, an attacker who front-runs a
visible redeem with a minimum-size deposit into the recipient bucket captures nearly the entire exit fee — and can claim
and unwind in the same bundle. The shipped `withdrawalToRecentShareBps = 0` routes **100%** of every exit fee into this
slice, so there is no dilution.

**This is distinct from `MA-03` and needs its own fix.** `MA-03` is a _sticky seat_ — a position stripped to dust
retains standing indefinitely, fixed by re-deriving the bucket on redeem and flooring the denominator. This is a
_zero-dwell_ defect: no positioning and no patience are required at all, only mempool visibility. Neither `MA-03` fix
stops a freshly-funded, correctly-sized position from capturing the same fee.

It directly defeats the stated purpose of the slice, which the NatSpec frames as a reward to "the residual holders of
the exiting tier (diamond-hands)". A one-transaction-old position is not a diamond hand.

**Code.** `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:389` — entitlement granted immediately at deposit:

```solidity
rewardDebt[termId][account] = newStake.fullMulDiv(accFeePerShare[termId][newTier], ACC_PRECISION);
```

`:424-441` — the credit divides by the recipient tier's stake, which the fresh position now dominates. Supporting:
`:530-538` (`_settle`), `:769-786` (`_nearestOccupiedTier`, whose above-first scan widens the reachable recipient
buckets).

**Proof of concept.** Executed against the repository's `BaseTest` fixture (5 tiers, `width0 = 5e18`, withdrawal 200 bps

- 50/tier, `withdrawalToRecentShareBps = 0`, `MIN_DEPOSIT = 1e17`):

| Scenario                                                                       | Attacker capital | Victim fee           | Captured             | Share         |
| ------------------------------------------------------------------------------ | ---------------- | -------------------- | -------------------- | ------------- |
| Nearest-occupied fallback (`denom == 0`, attacker sole occupant of the bucket) | `1e17`           | `230189861250000144` | `230189861250000143` | **9999 bps**  |
| Primary path (`denom > 0`, attacker inside the exiter's own bucket)            | `1e17`           | `72375000000000000`  | `72375000000000000`  | **10000 bps** |

Realized end-to-end profit for the fallback case — **after** paying the attacker's own curve deposit fee, curve
withdrawal fee, and the vault's protocol, entry and exit fees, and after fully closing the position:

```
+221392361250000143 wei  (+0.2214 TRUST) on 0.1 TRUST deployed for one transaction
= +221% return, at zero price risk (flat 1:1 par)
```

**The counterfactual is the important part.** Re-running with the front-run removed shows the identical
`230189861250000141` wei accruing to an honest holder who had been in the vault **since before the exiting party
entered**. This is a direct transfer from a long-standing holder, not a claim on protocol dust.

**Production impact is larger, not smaller** — the shipped schedule sets `withdrawalToRecentShareBps = 0`, so the
diamond slice is the entire exit fee.

**Recommendation.** Extend the exclusion machinery that already exists — it removes `excludeStake` from a recipient
denominator and re-bases that party's `rewardDebt` — to also exclude stake whose deposit landed inside a configured
dwell window:

1. Record the deposit timestamp per position in `recordDeposit`.
2. Accumulate a per-tier `youngStake[termId][tier]`.
3. Subtract it from every recipient denominator — in `_weighPriorTiers` and in the `denom` computation at `:424`.
4. Re-base young positions' `rewardDebt` post-distribution, exactly as `:389` and `:448` already do.

A dwell window measured in blocks is sufficient to defeat the same-bundle attack; a longer window also blunts
short-horizon rotation.

**Regression test.** `ExitFeeDwellRequirement.t.sol` — assert a position opened in the same block as a redeem receives
no share of that redeem's fee, and that the fee accrues to the pre-existing cohort instead.

**Variant sweep.** Single redeem — same bug · `redeemBatch` — same bug and strictly cheaper · on-behalf-of — same bug ·
preview — safe, view only · `FeeProxy` router — same bug · **deposit-side mirror — safe, measured**: the equivalent
front-run against `_payRecentTiers` is structurally defended and was measured net-negative.

---

### MA-05 — A sub-cap curve withdrawal rate burns shares for a zero payout with no revert and no floor; the fee surface is not timelocked — Major

**Provenance:** `R2-TOB-01` (Major) = `R2-CLD-02` (Medium) = `R2-HMN-03` (Medium, brick variant) · **Rounds reached: 3
of 6** · **Cluster:** C1 · **Confidence:** High · **Status:** Open (as found) · **Invariant broken:** §4.2 (the curve
must custody only redistributed value, never principal) and §4.4 (flat-price par — "a holder's maximum loss is the fees
they paid"). **Overrides the trusted-admin scope exclusion, whose stated precondition is timelock gating — see
`MED-01`.**

**Mechanism.** Three independent gaps compose into one path:

1. **The fee can consume the whole redemption.** `_setConfig` accepts `withdrawalCapBps` up to `BPS` and
   `withdrawalBaseBps` up to that cap; `setTierFeeOverride` accepts any rate up to the same cap **for a single tier**,
   which makes the action surgically targetable at one cohort or one holder.
2. **There is no timelock and no delay.** `setConfig`, `setTierFeeOverride` and `clearTierFeeOverride` are plain
   `onlyOwner` with immediate effect, while every equivalent `MultiVault` fee setter is `onlyTimelock`.
3. **`MultiVault` never checks the redeemer receives anything.** `_calculateRedeem` subtracts the curve fee as a
   straight subtraction and `_validateRedeem` compares the result only against a **caller-supplied** `minAssets`. With
   `minAssets = 0` — the default in every convenience path — a redemption that returns zero **succeeds and burns the
   shares**. `previewRedeem` returns the same zero and raises no error, so a front end deriving `minAssets` from the
   preview derives no protection either.

The confiscated value is **not burned**: it is credited to `accFeePerShare` for the residual holders of the exiting tier
— a position the owner can hold — and is immediately withdrawable via `claim`. This is value capture, not only griefing.

**Code.**

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:249-251 — immediate, no timelock
function setConfig(DynamicFeeConfig calldata _config) external onlyOwner { _setConfig(_config); }

// :265-273 — single-tier targeting; the cap is the only bound
function setTierFeeOverride(uint256 tier, uint16 newDepositFeeBps, uint16 newWithdrawalFeeBps) external onlyOwner {

// :894-896 — the cap may itself be BPS
if (_config.withdrawalBaseBps > _config.withdrawalCapBps || _config.withdrawalCapBps > BPS) { revert ...; }

// src/libraries/MultiVaultLib.sol:1067 — no floor on the payout
uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;

// :1388-1392 — the only guard is the caller's own minAssets
(uint256 expectedAssets,,) = _calculateRedeem(termId, curveId, shares, account);
if (expectedAssets < minAssets) { revert MultiVault.MultiVault_SlippageExceeded(); }
```

Contrast, same upgrade: `src/protocol/MultiVault.sol:819-822` — `setVaultFees(...) external onlyTimelock`.

**Proof of concept.** Executed end to end against a clean checkout with the default 13-tier schedule. A beneficiary
account holds `2e18` in the term at tier 0; the victim holds `40e18` at the same tier. The curve owner, **in one
transaction with no delay**, raises `withdrawalCapBps` to `10_000` via `setConfig` and calls
`setTierFeeOverride(0, 0, 9900)` — a 99% withdrawal rate applied to tier 0 only. The victim then executes the identical
redemption with `minAssets = 0`:

| Quantity                                       | Value (wei)                  |
| ---------------------------------------------- | ---------------------------- |
| Victim payout, honest schedule                 | `37 118 408 000 000 018 818` |
| Victim payout, after retune                    | `0`                          |
| Beneficiary `claimable` gain                   | `37 883 736 000 000 019 204` |
| Beneficiary amount actually pulled via `claim` | `37 883 736 000 000 019 204` |

**The documented failure mode is the safe one.** At exactly `BPS` the behaviour changes to a revert — which is what the
NatSpec at `DynamicFeeFlatPriceCurve.sol:257-260` documents. At any rate **strictly inside the cap** the redemption
succeeds and pays zero. The undocumented mode is the damaging one (see `INFO-03`). A third report independently measured
the brick threshold on the same surface at **9901 bps, with no override required**, against a validator that permits up
to 10000.

**Mutation check.** Re-running the identical sequence with `clearTierFeeOverride(0)` interposed pays the victim
`> 30e18` — the override is the operative cause, not a setup artefact.

**Independently verified for this master.** `MultiVaultLib.sol:1067` is a straight subtraction with no floor;
`DynamicFeeFlatPriceCurve.setConfig` / `setTierFeeOverride` carry `onlyOwner` with no delay;
`script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:80` passes `msg.sender` as owner with an inline PoC-placeholder
comment.

**Severity disagreement — stated.** One report rated this **Major**, reaching the full principal-confiscation path with
an executed end-to-end PoC. Two rated the zero-payout mechanism **Medium**, filing it on the narrower basis that a guard
exists and documents a safety property it does not deliver. **Carried at Major**: the composed path was demonstrated,
and the composition (not the individual gaps) is the finding.

**Recommendation.**

1. **Floor the payout in `MultiVault`**, independently of `minAssets`:

   ```solidity
   // src/libraries/MultiVaultLib.sol, in _calculateRedeem
   -  uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;
   +  if (protocolFee + exitFee + hook.fee >= assets) revert MultiVault.MultiVault_RedeemYieldsNoAssets();
   +  uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;
   ```

2. **Bound the curve's cap against the vault's own fees at config time**, so no schedule capable of zeroing a payout can
   be stored — e.g. `withdrawalCapBps + protocolFeeBps + exitFeeBps <= BPS - MIN_PAYOUT_BPS`. See `MED-02`.
3. **Put the curve's privileged surface behind the parameters `TimelockController`.** See `MED-01`. If a same-block
   emergency retune is genuinely required, split it: an immediate _fee-lowering_ path and a timelocked _fee-raising_
   path.
4. Emit previous and new rates in `ConfigUpdated` / `TierFeeOverrideSet` so a raise is monitorable.

**Regression test.** `CurveWithdrawalFeePayoutFloor.t.sol` — assert a redemption always returns non-zero assets for
non-zero shares across the full admissible `withdrawalCapBps` range, and that a schedule capable of a zero payout is
rejected at `setConfig`.

**Variant sweep.** Single redeem — same bug · `redeemBatch` — same bug, same `_processRedeem` body · on-behalf-of — same
bug · preview — silently agrees, returns `0` with no error · schedule-wide `withdrawalBaseBps` — same bug, no override
needed · `FeeProxy` — n/a, not a redeem router · upgrade initializer — n/a.

---

### MED-01 — The curve's privileged fee surface is not timelock-gated, and the deploy script assigns ownership to the broadcasting EOA — Medium

**Provenance:** `R2-TOB-01` (facet 2) = `R2-HMN-06`; supported by `R2-TOB-10`, `R2-HMN-10` · **Rounds reached: 2 of 6**
· **Cluster:** C1 / Deploy · **Confidence:** High · **Status:** Open (as found) · **Invariant broken:** trust boundary.

**Mechanism, and why it is filed despite the centralization exclusion.** The out-of-scope acceptance of trusted-admin
centralization rests on a stated precondition: privileged actions are _"gated by a 4-of-8 Safe acting through two
`TimelockController`s (parameters 3-day, upgrades 7-day)."_ **That precondition does not hold for the new curve.** Its
fee surface — `setConfig`, `setTierFeeOverride`, `clearTierFeeOverride`, `sweepProtocol`, and a live `renounceOwnership`
— is plain `onlyOwner` with immediate effect, and the shipped deploy script initializes the owner to `msg.sender`, the
broadcasting key, on **every** chain including mainnet:

```solidity
// script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:80
msg.sender, // owner for the PoC; migrate to the parameters timelock / admin Safe in prod
```

The finding is that **the stated precondition is not met**, not that centralization exists. This matters beyond its own
severity: `MA-05`, `MED-02`, `MED-04` and `MED-07` are all risk-rated against an assumption the deployment as written
does not satisfy. A `renounceOwnership` that is live on the fee custodian and the registry compounds it — an
irreversible one-call action with no timelock (`R2-HMN-10`).

`R2-TOB-10` sharpens the operational shape: `_defaultConfig` in the same script is explicitly labelled _"PLACEHOLDER:
the final production numbers … are pending the economic modeling"_, so **the intended post-deploy tuning workflow is
precisely the un-timelocked path**.

**Recommendation.** Change the deploy script so the owner argument is the parameters `TimelockController` rather than
`msg.sender`, and match `MultiVault`'s `onlyTimelock` gating on the curve's fee setters. Disable or timelock
`renounceOwnership` on the curve and the registry. If an emergency same-block retune is required, split the surface into
an immediate fee-_lowering_ path and a timelocked fee-_raising_ path.

**Regression test.** `CurveAdminTimelockParity.t.sol` — assert the curve's fee setters revert for a non-timelock caller,
and that the deploy script's owner argument resolves to the timelock on mainnet chain ids.

---

### MED-02 — The combined MultiVault + curve fee envelope is validated by neither side, so an accepted schedule bricks deposits or redeems — Medium

**Provenance:** `R2-HMN-03` (Medium) = `R2-TOB-04` (Minor) = `R2-CYF-03` (Minor) = `R2-PAS-07` (Minor) = `R2-CLD-03`
(Minor) · **Rounds reached: 5 of 6** · **Cluster:** C1 / C2 · **Confidence:** High · **Status:** Open (as found) ·
**Invariant broken:** §4.2 in its liveness sense; §4.4.

**Mechanism.** The curve validates its own fee caps against `BPS` only; `MultiVault.setVaultFees` performs **no bounds
check at all**. The netting sites subtract all fees from the gross, so a schedule that each side accepts as individually
valid can jointly underflow and brick the path.

On the deposit side the coupling is sharper than it looks: the curve's fee is quoted on `assetsAfterMinSharesCost` — the
base **before** MultiVault's own fees — but is then subtracted from `assetsAfterFees`, the amount **after** protocol,
entry and atom-wallet fees have already been taken. When the curve's rate plus MultiVault's rates exceed 100%, the
subtraction underflows and **every deposit on that curve reverts** until the schedule is retuned.

```solidity
// src/libraries/MultiVaultLib.sol:959-963 (atom) and :1021-1025 (triple) — identical shape
hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
assetsAfterFees -= hook.fee;    // underflows; assetsAfterFees is already net of MultiVault fees
```

**Proof of concept.** With `depositBaseBps = 9990`, `depositGrowthBps = 0`, `depositCapBps = 10_000` — all accepted by
`setConfig` — a `10e18` deposit on the curve reverts. Confirmed by execution; both the atom and triple calculation paths
carry the identical expression, so the failure is total for the curve. On the redeem side a separate report measured the
brick threshold at **9901 bps** with no override required.

**Asymmetric documentation.** The mirror hazard on the withdrawal side is documented at
`DynamicFeeFlatPriceCurve.sol:257-260`; the deposit side is documented nowhere.

**A design wrinkle worth recording.** Because the deposit fee is quoted on the pre-MultiVault-fee base and deducted from
the post-fee net, the _effective_ rate a depositor pays on their net stake is strictly higher than the advertised bps.
This is documented in `IBaseCurve.quoteDepositFee` ("post-min-shares cost, pre-MultiVault-fees") and is therefore
intended — but it is the reason the safe cap is well below `BPS`.

**Severity.** Four reports rated this Minor (admin footgun, reverts rather than losing value); one rated it Medium.
**Carried at Medium** per §3 — a protocol-wide brick of every deposit or every redeem on the curve is a funds-path
availability failure, and the validator actively blesses the schedule that causes it.

**Recommendation.** Validate the combined envelope at `setConfig` time rather than discovering it on the hot path:

```solidity
if (_config.depositCapBps > BPS - MAX_VAULT_SIDE_DEPOSIT_BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
```

and document the deposit-side hazard alongside the withdrawal-side one. Saturating instead of underflowing
(`assetsAfterFees > hook.fee ? assetsAfterFees - hook.fee : 0`) is acceptable **only in combination with the payout/mint
floor from `MA-05`** — a silent zero is worse than a revert here.

**Regression test.** `DepositFeeEnvelopeBound.t.sol` — assert every `setConfig`-accepted schedule admits a successful
deposit **and** a successful redeem.

---

### MED-03 — `previewRedeem` quotes the curve fee off the vault's tier, not the holder's, and disagrees with execution in both directions — Medium

**Provenance:** `R2-TOB-03` (Medium) = `R2-HMN-09` (Medium) = `R2-PAS-05` (Minor) = `R2-CYF-38` (Minor) · **Rounds
reached: 4 of 6** · **Cluster:** C1 / C2 · **Confidence:** High · **Status:** Open (as found) · **Invariant broken:**
none directly — a spec/integration regression that materially affects users and operators.

**Mechanism.** `quoteRedeemFee` keys the withdrawal rate on the redeeming account's recorded tier, falling back to the
**vault's** current tier when the account has no tracked stake. The account-less preview path passes `address(0)`, so
`previewRedeem` **always** takes the fallback. Because a holder's tier is their stake-weighted average _entry_ tier, it
routinely differs from the vault's current tier in either direction.

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:326-328
uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultAssets[termId]);
return grossAssets.mulDivUp(_withdrawalFeeBps(tier), BPS);
```

**The direction matters, and one direction is a denial of service:**

- **Holder below the vault's tier** (an early holder in a grown vault): the preview applies the _higher_ vault-tier rate
  and **under-states** the payout. Integrators quote users a worse number than they get.
- **Holder above the vault's tier** (after net outflow, or after a `setConfig` retune that widens the ladder): the
  preview applies the _lower_ rate and **over-states** the payout. An integrator that sets
  `minAssets = previewRedeem(...)` — the natural and documented use of a preview function — has its redemption
  **reverted** by the slippage guard. This is a functional DoS on the redeem path, triggerable by an ordinary owner
  retune with no malicious intent.

**Proof of concept.** Both directions executed. Under-statement: holder enters at tier 0, vault grows to tier 4 —
preview `2 764 499 999 999 078 500` vs actual `2 822 699 999 999 059 100`, under-stating by ~2.1%. Over-statement: two
holders reach tier 4, owner raises `width0` from `5 000e18` to `10 000e18` dropping the vault to tier 0 — preview
`55 290 000 000 000 000 000` vs actual `54 150 000 000 000 000 000`; passing that preview as `minAssets` reverts with
`MultiVault_SlippageExceeded`.

**Independently verified for this master.** The fallback at `DynamicFeeFlatPriceCurve.sol:327` is confirmed present; the
account-less preview wrapper supplies `address(0)`.

**Severity disagreement — stated.** Two reports rated Medium (spec regression with a reachable redeem DoS), two rated
Minor (no on-chain value is lost; execution paths are internally consistent). **Carried at Medium** per §3.

**Recommendation.** Add an account-aware preview — overload `previewRedeem(bytes32,uint256,uint256,address)` and route
the account through to `_calculateRedeem`, or make the existing `previewRedeem` take the caller. If the account-less
signature must stay for ABI compatibility, document in both `IBaseCurve.quoteRedeemFee` and `IMultiVault.previewRedeem`
that the figure is **not** the fee a specific holder will pay and **must not** be used to derive `minAssets`.

**Regression test.** `RedeemPreviewAccountParity.t.sol` — assert `previewRedeem(..., account) == redeem(...)` for
holders both above and below the vault's current tier, and across a `setConfig` retune.

**Variant sweep.** `previewRedeem` — broken both directions · `convertToAssets` — applies no curve fees at all, so
unaffected but also not a usable payout quote · `maxRedeem` — share-denominated, unaffected · execution paths — all pass
the real account and are internally consistent; the divergence is preview-versus-execution only, so no value is lost
on-chain.

---

### MED-04 — A per-tier fee override survives a reduction of the cap it was validated against, and is read back unclamped — Medium

**Provenance:** `R2-HMN-04` (Medium) = `R2-PAS-04` (Medium) = `R2-CYF-18` (Informational) · **Rounds reached: 3 of 6** ·
**Cluster:** C1 · **Confidence:** High · **Status:** Open (as found) · **Invariant broken:** spec regression — the
NatSpec asserts a property the code does not enforce.

**Mechanism.** `setTierFeeOverride` bounds an override against the caps **at set time**. The read path returns it
**uncapped** thereafter, short-circuiting before the clamp that the non-override branch applies. An override therefore
survives a later cap _reduction_ — which means **a privileged action whose intent is to tighten the envelope silently
fails to tighten it.** `DynamicFeeFlatPriceCurve.sol:257-258` states the override "does not bypass the cap"; after any
reduction, it does.

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:851-859
function _withdrawalFeeBps(uint256 tier) private view returns (uint256) {
    TierFeeOverride storage tierOverride = tierFeeOverride[tier];
    if (tierOverride.isSet) {
        return tierOverride.withdrawalFeeBps;      // returned UNCAPPED — no clamp on this branch
    }
    uint256 fee = config.withdrawalBaseBps + tier * config.withdrawalGrowthBps;
    uint256 cap = config.withdrawalCapBps;
    return fee < cap ? fee : cap;                  // the clamp the override branch skips
}
```

`_depositFeeBps` at `:811-819` has the identical shape.

**Independently verified for this master.** Both read paths confirmed: the `isSet` branch returns the stored value with
no clamp, while the computed branch applies `fee < cap ? fee : cap`.

**Why this is filed despite the centralization exclusion.** The defect is that a guard **fails open on an action whose
intent is to tighten**. An operator who lowers `withdrawalCapBps` to close `MA-05` would reasonably believe they had
done so; overridden tiers remain at the old rate. It composes directly into `MA-05` and `MED-02`.

**Recommendation.** Apply the live cap at read time —
`return min(tierOverride.withdrawalFeeBps, config.withdrawalCapBps)` — or re-validate and clamp every stored override
inside `_setConfig` whenever a cap is lowered. The read-time clamp is cheaper and cannot be forgotten.

**Regression test.** `TierOverrideCapTightening.t.sol` — set an override at the old cap, lower the cap, assert the
effective rate returned by both `_depositFeeBps` and `_withdrawalFeeBps` is the new cap. Mutation-check by removing the
clamp.

---

### MED-05 — `setBondingCurveConfig` validates nothing: registry repoint, ghost-share seed mispricing, and a par break all follow from one write — Medium

**Provenance:** `R2-CYF-XC-01` (facets 2 and 3, cross-contract composition) = `R2-HMN-05` = `R2-CYF-16`; related
`R2-CYF-05`, `R2-CLD-04`, `R2-TOB-06` · **Rounds reached: 3 of 6** · **Cluster:** C2 / B · **Confidence:** High ·
**Status:** Open (as found) · **Invariant broken:** §4.1, §4.2, §4.4 (facet 1, §4.3, is `MA-01`).

**Mechanism.** `MultiVault.setBondingCurveConfig` assigns the whole `BondingCurveConfig` struct with **zero
validation**. It does not pin `registry` — which its own interface NatSpec at `IMultiVaultCore.sol:70-71` declares
_"must not be changed after initialization"_ — does not reject `address(0)` for either field, and does not check that
`defaultCurveId` resolves to a registered curve. `defaultCurveId = 0` bricks every create and every default-curve
deposit and redeem.

This finding is the product of the per-contract review mode: **three reviewers, each seeing only their own contract,
independently found a different invariant that this single write breaks.** Two rated their own facet Low or Medium while
explicitly noting it looked narrow. Each was locally correct; what none could see is that all three facets share one
trigger, the trigger has no validation whatsoever, and **two of the three failure modes are silent rather than
reverting.**

- **Facet 1 — §4.3, the curve ledger mirror.** Carried separately as **`MA-01`**.
- **Facet 2 — §4.1 / §4.2, conservation and solvency.** `_getAtomCost` / `_getTripleCost` price the ghost-share seed at
  the raw `minShare` **share** quantity, while the create path funds the vault with
  `_minAssetsForCurve(curveId, minShare)` **assets**. The two are equal only for a curve minting 1:1 from an empty
  domain. Repointing produces either under-collateralisation or permanently stranded value — silently, with **no revert
  and no event** (`R2-CYF-05`).
- **Facet 3 — §4.4, flat-price par.** Every asset-only credit (`entryFee`, `exitFee`, the triple atom-deposit fraction)
  routes through helpers that hard-read `defaultCurveId` at `MultiVaultLib.sol:1086-1091`. If that pointed at the
  flat-price curve, assets would be credited with no matching shares, driving `totalAssets > totalShares` and breaking
  par — while simultaneously desyncing §4.3, since the curve's ledger counts shares.

**The same helpers produce a live, non-hypothetical consequence today** (`R2-CLD-04`, `R2-TOB-06`, carried as
`INFO-01`): MultiVault entry and exit fees paid by **non-default-curve** users accrue entirely to the **default**
curve's vault. That is what currently holds the dynamic curve at exactly 1:1 — which is itself the unpinned coupling in
`INFO-01`.

**Registry-swap variant.** Replacing the whole `registry` address with one mapping the same id to a different curve
reaches the same class of desync as `MA-01` and needs the same guard.

**Independently verified for this master.** `src/protocol/MultiVault.sol:825-828` is a bare struct assignment plus an
event, with no validation of either field.

**Recommendation.** Make the setter enforce what the system already assumes. Minimally: reject a changed `registry` (or
correct the NatSpec), reject `address(0)` on both fields, require
`registry.curveAddresses(defaultCurveId) != address(0)`, require
`registry.previewMint(minShare, 0, 0, defaultCurveId) == minShare`, and reject a `defaultCurveId` whose
`hasDepositFeeHook()` or `hasRedeemFeeHook()` is true (`MA-01`). Re-validate the seed identity in `setGeneralConfig`
when `minShare` changes. **Structurally better for facet 2:** derive `_getAtomCost` / `_getTripleCost` from
`_minAssetsForCurve(defaultCurveId, minShare)`, so the advertised cost and the funded credit are the same expression and
the invariant disappears rather than being asserted.

**Regression test.** `BondingCurveConfigValidation.t.sol` — assert each rejected configuration reverts, including a
changed registry, a zero id, an unregistered id, and a hook-advertising default curve.

**Not live today.** The deployed configuration is `defaultCurveId: 1` (`LinearCurve`, hookless, 1:1); all facets are
gated on one governance write.

---

### MED-06 — Upgrade-epoch utilization carry is seeded from a possibly-zero slot, and the pre-`reinitialize` window is permissionless — Medium

**Provenance:** `R2-CYF-02`; related `R2-CYF-44` · **Rounds reached: 1 of 6** · **Cluster:** A / F · **Confidence:**
Medium (the reviewer could not read mainnet state) · **Status:** Open (as found) · **Invariant broken:** none of §4
directly — a one-epoch mis-statement of the system-utilization ledger that `TrustBonding` converts into an emissions
multiplier.

**Mechanism.** `MultiVault.reinitialize` pre-seeds `lastSystemUtilizationEpoch = _currentEpoch()` so the first
post-upgrade `_rollover` reads a meaningful source epoch. Two problems follow.

- **(a) Cold-epoch seed.** If the upgrade epoch has seen no MultiVault activity when `reinitialize` runs, the seeded
  epoch's `totalUtilization` is zero, so `_rollover`'s `sourceUtilization != 0` guard fails and the standing utilization
  carry is **dropped**, not carried.
- **(b) Permissionless window.** The deploy script explicitly requires the reinitializers to run as **separate
  transactions**, never embedded in `upgradeAndCall`. In the window between the implementation swap and `reinitialize`,
  `lastSystemUtilizationEpoch` is still `0`, so **any caller** can trigger a rollover that carries `totalUtilization[0]`
  into the current epoch and consumes the once-per-epoch flag. `reinitialize` re-seeds the epoch pointer but **cannot
  undo the consumed flag**, so the epoch's base is fixed at the attacker-chosen source.

**Code.** `src/protocol/MultiVault.sol:294-305` (`:304` is the seed write); `src/libraries/MultiVaultLib.sol:1145-1157`
(the once-per-epoch flag and the `sourceUtilization != 0` guard); `src/protocol/emissions/TrustBonding.sol:645-682`,
`:563-564` (the consumer); `script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:113-122` ("must run as
SEPARATE transactions").

**Proof of concept.** `UpgradeEpochUtilizationSeed.t.sol`, 3 tests. Branch (a): with
`totalUtilization[20] = 5_000_000e18` and epoch 21 cold, after `reinitialize` the first activity yields
`totalUtilization[21] == 1e18` — the standing carry is gone. **Control:** if epoch 21 was already warm the carry
survives at `5_000_000e18 + 1e18`, which is the boundary deciding whether the bug fires. Branch (b): an unprivileged
call in the window carries `totalUtilization[0]` and pins the epoch base at `7e18 + 1`, surviving the admin's later
`reinitialize`.

**Impact.** `TrustBonding._getSystemUtilizationRatio` computes a delta against the previous epoch; a dropped carry makes
it strongly negative, returning `systemUtilizationLowerBound` and **flooring the upgrade epoch's entire emissions
budget** — everyone bonding through that epoch is underpaid. It self-heals from the following epoch. In branch (b) the
direction depends on the live value of `totalUtilization[0]` on mainnet: if large, the effect is _inflation_ rather than
flooring.

**Cross-check against round 1 — this is new surface, not a duplicate.** The reviewer flagged adjacency to round-1
`MED-03` (carry-forward deliberate, bounded, capped) and `INFO-02`, and filed anyway on the basis that those describe
**steady-state** carry semantics while this concerns **the seed value chosen at the upgrade boundary** and the window
before it is chosen — `lastSystemUtilizationEpoch` being a new v1.1.0 slot. This master concurs: round-1 `MED-03`'s
disposition ("snap-forward is the deliberate documented design") is not defeated and is not engaged, and `MED-06` is
filed as new. It does, however, **strengthen round-1 `INFO-05`**, whose disposition rested on "calling `reinitialize` is
an explicit step of the upgrade process" — branch (b) shows that window is adversarially live.

**Recommendation.** Cheapest: gate the upgrade runbook on `hasRolledOverSystemUtilization[currentEpoch] == true` — warm
the epoch with any activity before `upgradeAndCall`. **Nothing enforces this today and it is not written down.**
Stronger: have `reinitialize` take the source epoch as an explicit argument rather than inferring it, or have
`_rollover` fall back through a lookback when `totalUtilization[sourceEpoch] == 0`.

**Open question carried from `R2-CYF-44`.** `_rollover` sets `lastSystemUtilizationEpoch = currentEpoch` **even when the
carry was skipped**, since the write sits outside the `sourceUtilization != 0` conditional. If an epoch's first action
is a redeem large enough to drive `totalUtilization[epoch]` negative, that negative becomes the next epoch's carry
source. The reviewer did not verify how `TrustBonding` consumes a negative `getTotalUtilizationForEpoch`. **This is
unresolved and should be answered during remediation.**

**Regression test.** `UpgradeEpochUtilizationSeed.t.sol::test_reinitializeInQuietEpochDropsStandingUtilizationCarry` and
`::test_unprivilegedCallerInReinitializeWindowSeedsCarryFromGenesisEpoch`.

---

### MED-07 — A retune with live positions silently re-targets the entire fee stream; index-keyed buckets are never migrated — Medium

**Provenance:** `R2-HMN-07`; related `R2-TOB-09` · **Rounds reached: 2 of 6** · **Cluster:** C1 · **Confidence:** High ·
**Status:** Open (as found) · **Invariant broken:** spec regression.

**Mechanism.** Tier accumulators are **index-keyed** — `accFeePerShare[termId][tier]`, `tierStake[termId][tier]` — and
`setConfig` changes what each index _means_ (the ladder edges) without migrating any of them. Holders remain recorded at
their old bucket index while the index now denotes a different band, so the entire fee stream silently re-targets: the
cohort a slice was promised to is no longer the cohort that receives it. The same property is what makes the `MA-02` /
`MA-03` dust seats survive retunes.

`R2-TOB-09` records the related divergence: `_roundTier` caps the stored bucket at `tierCount - 1` while `userAvgTier`
retains the uncapped weighted average, so **growing `tierCount` later** lets a holder's next deposit resolve to a much
higher bucket than their previous one in a single jump. Bookkeeping stays consistent — every `tierStake` move keys off
the stored `userTier`, verified across a retune probe — so there is no accounting break, but the behaviour is surprising
and undocumented.

**Note the interaction with `MED-01`.** The shipped schedule is explicitly a placeholder pending economic modeling, so a
retune with live positions is not a hypothetical: it is the **expected** first post-deploy operation.

**Recommendation.** Either migrate positions on retune (expensive, and unbounded in the number of holders), or make the
re-targeting explicit and bounded: freeze new distributions across a retune, or version the accumulator keys so a retune
starts a fresh generation and old entitlements settle against the old ladder. At minimum, document that `setConfig` with
live positions re-targets the stream, and emit the before/after ladder so the change is monitorable.

**Regression test.** `CurveRetuneLivePositionParity.t.sol` — assert booked and pending earnings are preserved across an
edge re-price, and that a holder's effective band after a retune is the one the new ladder implies.

**Coverage note.** One report recorded "retune with live positions" as **reasoned but not proven by execution** — an
un-refuted hypothesis rather than a pass. This finding and that gap should be closed together.

---

### MED-08 — Rotating the EntryPoint re-derives every AtomWallet address — Medium

**Provenance:** `R2-HMN-08` = `R2-CYF-36` · **Rounds reached: 2 of 6** · **Cluster:** E · **Confidence:** Medium ·
**Status:** Open (as found) · **Invariant broken:** trust boundary / deployment identity.

**Mechanism.** The wallet's CREATE2 identity is coupled to the live `walletConfig`, which includes the EntryPoint
address. Rotating the EntryPoint — a routine ERC-4337 infrastructure action, and one the protocol has a governance
setter for — **re-derives every AtomWallet address**. Wallets already deployed keep their old addresses and remain
functional; wallets not yet deployed resolve to different counterfactual addresses than the ones the protocol and its
integrators have been advertising and, in the atom-wallet fee model, **already routing value to**.

**Recommendation.** Decouple the CREATE2 salt from mutable configuration — derive it from the atom id alone, or from an
immutable snapshot of the config taken at factory initialization. If the coupling must stay, treat an EntryPoint
rotation as a migration event with its own runbook rather than a parameter change, and record that in the ops
documentation.

**Regression test.** `AtomWalletAddressStabilityAcrossConfig.t.sol` — assert `computeAtomWalletAddr(atomId)` is
invariant across an EntryPoint rotation.

---

### Minor findings (load-bearing subset)

| ID     | Title                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Provenance (rounds reached)                               | Cluster |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------- |
| MIN-01 | `claimable(account, termId)` folds the **cross-vault** `earned` balance into every per-term reading; any consumer summing it over a user's terms over-reports by `(nTerms − 1) × earned`. On-chain payout is correct — `claim` zeroes `earned` once. Measured over-report: `1 007 024 999 999 985 522` wei.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `R2-TOB-05` = `R2-PAS-08` = `R2-CYF-29` (3)               | C1      |
| MIN-02 | **The quote-then-record fee-parity guarantee — the load-bearing property of the entire C2 hook surface — has no gating test.** Removing it leaves the full dynamic-fee suite green: 28 of 28 tests pass, including three invariant suites and two 10,000-run fuzz solvency tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `R2-PAS-06` (1)                                           | C2      |
| MIN-03 | **The round-1 `MED-01` fix has no negative regression test.** Under a _permissive_ mutation — accept the envelope **or** the bare digest, the shape a "keep old signatures working" refactor would take — all **122** pre-existing wallet tests stay green; only the two new tests go red. The fix is protected against deletion but not against a plausible backwards-compatibility refactor that would silently reopen `MED-01`.                                                                                                                                                                                                                                                                                                                                                                                                             | `R2-CYF-33` (1)                                           | E       |
| MIN-04 | **The storage-layout suite does not pin intra-struct field ORDER** anywhere in the config region (slots 1–21). Mutation-checked **green/green**: swapping `minDeposit` and `minShare` in `GeneralConfig` left all 11 tests passing. Second-order result that changes the fix: a getter-relative slot assertion **cannot** detect an intra-struct reorder in principle, because the slot and the auto-getter's return position move together — anchors must compare each raw slot against a **literal**. The library mirror cannot catch it either, since both sides re-use the same imported struct type and move in lockstep. **Partially reopens round-1 `INFO-04` — see §5a.**                                                                                                                                                              | `R2-CYF-15` (1)                                           | A / B   |
| MIN-05 | Hook-getter symmetry is not enforced at registration and there is no cross-transaction latch. The two capability getters are independent; a `deposit=false / redeem=true` curve is registerable and would debit a ledger no deposit ever credited — the same underflow as `MA-01`, **reached without touching `defaultCurveId`**. The shipped curve hard-codes both `pure true`.                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `R2-HMN-15` = `R2-CYF-19` = `R2-PAS-17` = `R2-CYF-39` (3) | C2      |
| MIN-06 | Two live `executeBatch` selectors disagree on access control and reentrancy protection — the inherited `BaseAccount.executeBatch(Call[])` is not overridden, so it bypasses the guards the protocol's own overload applies.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `R2-CYF-35` = `R2-HMN-11` (2)                             | E       |
| MIN-07 | **`claimAsCreatorAfterExpiry` pre-empts the address-atom owner and captures the wallet's accrued fees — permissionless.** It has no exclusion for address atoms, checking only creator identity, an elapsed window, and a self-fundable fee threshold. Atom creation is permissionless and records the creator, so a squatter creates the atom for someone else's address first; whichever claim fires first sets `isClaimed` and the other is **permanently** rejected. PoC `test_creatorExpiry_preemptsAddressAtomOwner`, both legs passing. **Not a duplicate of round-1 `MIN-01`** (different contract, different mechanism).                                                                                                                                                                                                              | `R2-CYF-47` (1)                                           | D       |
| MIN-08 | `signerCount` is a role-grant tally, not a live usable-key census, and fails closed in both directions. **Inflation:** granting `SIGNER_ROLE` to `address(0)` succeeds and increments the count, permitting a threshold the quorum can never satisfy. **Deflation:** any single signer can `renounceRole`, dropping the count to zero; the quorum then fails closed **and** the admin cannot repair it, since `setSignatureThreshold` requires `newThreshold <= signerCount` and every value reverts. Liveness only, never authorization.                                                                                                                                                                                                                                                                                                      | `R2-CYF-48` (1)                                           | D       |
| MIN-09 | `renounceOwnership` is live on the fee custodian (the curve) and on the registry — an irreversible one-call action with no timelock. Compounds `MED-01`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `R2-HMN-10` (1)                                           | C1 / C2 |
| MIN-10 | `claim` has no recipient parameter, so a holder whose address reverts on receive strands their earnings permanently.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `R2-HMN-12` (1)                                           | C1      |
| MIN-11 | Chunking a deposit is cheaper than lumping it **and** yields a better bucket — the fee ladder and `userAvgTier` both reward splitting, which is the opposite of the intended incentive and is free to exploit.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `R2-HMN-13` (1)                                           | C1      |
| MIN-12 | **Provenance markers are already committed to the public mirror.** An internal issue-tracker identifier, sequential internal round/workstream labels, and the phrases `deep pre-audit` / `pre-audit` appear in NatSpec titles — and in one case in a test function identifier — of **tracked** test files that ship publicly. Breaches the scope brief's "no internal ticket ids in anything that ships with the mirror" and the process rule that tests stay provenance-free. **Independently confirmed for this master:** 9 tracked files under `tests/unit/security/v1.1.0/` and `tests/unit/upgrades/v1.1.0/` still carry markers at the reviewed commit. The literal strings are deliberately not reproduced here. Fix: retitle each to the mechanism under test; add a CI grep for provenance markers under `tests/` as the durable fix. | `R2-CYF-14` (1)                                           | Process |

### Informational findings (load-bearing subset)

| ID      | Title                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Provenance (rounds reached)                                             |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| INFO-01 | **Unit coupling is implicit and unpinned.** The curve's `vaultAssets` accumulates _share_ amounts (the record hooks are handed `sharesForReceiver` / `shares`) while the tier ladder `_tierUpperEdge` is denominated in _assets_ (TRUST wei). The two agree only because a non-default-curve vault holds price at exactly 1:1 — entry and exit fees route to the **default** curve's vault (`MultiVaultLib.sol:1086-1091`), not the depositing curve's. That coupling is load-bearing for **every tier decision and every fee rate**, is asserted nowhere, and would break silently if a future change credited pro-rata value to a non-default vault. Recommend an invariant test pinning `currentSharePrice(term, dynamicCurveId) == 1e18`.                                                                                           | `R2-TOB-06` = `R2-CLD-04` (2)                                           |
| INFO-02 | The curve fee is quoted **twice** per redemption: `_validateRedeem` runs `_calculateRedeem` for the slippage check and `_processRedeem` runs it again for execution (2× `hasRedeemFeeHook`, 2× `quoteRedeemFee`, 3× registry round-trips per redeem, each `quoteRedeemFee` running `_tierOf` at up to 64 `rpow` iterations). **Correctness is safe** — confirmed by an adversarial curve returning different answers on different _transactions_: the guard binds and the redemption is rejected rather than slipping through. Gas and design hygiene; the deposit path already solves it with the `CurveHook` quote-carry struct.                                                                                                                                                                                                      | `R2-TOB-07` = `R2-CYF-28` (2)                                           |
| INFO-03 | **NatSpec describes the wrong failure mode.** `DynamicFeeFlatPriceCurve.sol:257-260` states an over-large withdrawal rate "underflows `assets - fees` in MultiVault, bricking redeems for that tier until retuned" — i.e. a revert, funds safe. Empirically the revert occurs only at exactly `BPS`; at any rate strictly inside the cap the redemption **succeeds and pays zero**. Reword to describe the zero-payout mode, which is the one that loses value. See `MA-05`.                                                                                                                                                                                                                                                                                                                                                            | `R2-TOB-08` (1)                                                         |
| INFO-04 | Under the shipped schedule a vault sitting in tier 0 routes **100%** of every deposit fee to `protocolAccrued`, which the NatSpec documents as "dust". `_payRecentTiers` short-circuits whenever `span == 0`, but buckets are `round(avgEntryTier)`, not a function of current stake — so holders can remain bucketed at high tiers with non-zero `tierStake` while `vaultAssets` has fallen back inside `edge(0)`, and the whole fee is captured by the protocol with no event distinguishing it from the genuine "no holders at all" case. The redeem path handles the structurally identical condition correctly via `_nearestOccupiedTier`.                                                                                                                                                                                         | `R2-CYF-07` = `R2-HMN-I-04` = `R2-PAS-13` (3)                           |
| INFO-05 | Accumulator dust is **permanently unsweepable** — `sweepProtocol` pays exactly `protocolAccrued` and truncation surplus is never booked anywhere. Measured growth over one 16-op sequence: `0 → −13 → −143` wei of custody in excess of obligations, monotone, unbounded in principle, dust-class in magnitude, with no drain path for anyone ever. **Direction is conservative — it strengthens solvency.** The related residue is a **+1 wei transient** obligation deficit that can revert a single `claim()` until the next fee credit. Add a residual sweep, or fold the remainder into `protocolAccrued` at each credit site.                                                                                                                                                                                                     | `R2-CYF-17` + `R2-CYF-08` = `R2-PAS-09` = `R2-HMN-I-01/I-03` (3)        |
| INFO-06 | Record hooks carry **no `nonReentrant`**; correctness rests entirely on the settle-then-distribute-then-rebase ordering. Traced step by step and sound today — the vault's own guard closes the outer path, confirmed by an adversarial curve that attempts re-entry and is rejected — but any future edit moving a distribution above its `_settle`, or adding an external call inside a record hook, converts this to a live double-credit. Reentrancy-guard coverage is also asymmetric across the curve's write surface.                                                                                                                                                                                                                                                                                                            | `R2-HMN-I-02` = `R2-PAS-10` (2)                                         |
| INFO-07 | `CoreEmissionsController` is a mixin (`internal` initializer, no external one) but is declared `contract` rather than `abstract`, so it compiles to a deployable artifact whose reads all divide by zero and revert with a bare `Panic(0x12)`. Declare it `abstract`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `R2-CYF-24` (1)                                                         |
| INFO-08 | **A formal disposition-override against round-1 `MA-01` was filed and failed.** The mechanism is real and confirmed by a 7/7 PoC — the ownership root moved to a slot no upgrade path writes, so a v1.0.2-claimed wallet would resolve `owner()` to `address(0)`. The **override** does not hold: the deployed v1.0.2 claim path is **self-only**, additionally requires the wallet to be already deployed, and completes only after a second `acceptOwnership()` from the same party, so creating the precondition means a user bricking their own wallet in two self-sent transactions for no gain. **Round-1 `MA-01`'s disposition stands — see §5a.** Adds a concrete strengthening: an on-chain pre-flight assertion in the upgrade script that reverts if any deployed wallet has `isClaimed == true && _claimant == address(0)`. | `R2-CYF-32` (1, downgraded High → Informational by its own coordinator) |
| INFO-09 | ECDSA signature encodings are non-unique on **both** signature surfaces: from one valid signature anyone can mint at least three further distinct byte strings that validate for the same digest and owner **without the private key** — the high-`s` malleable counterpart, the 64-byte EIP-2098 compact form, and arbitrarily many trailing-padded variants (the wrapper enforces only a _minimum_ length and `abi.decode` ignores the tail). **Broadens round-1 `INFO-01` from high-`s` alone; the disposition rationale still covers it — see §5a.**                                                                                                                                                                                                                                                                                | `R2-CYF-34` = `R2-HMN-14` (2)                                           |
| INFO-10 | The round-1 `MED-02` emissions-length guard is **one-sided**: only the zero case is rejected, with no upper bound. An extension of the landed fix, not a defect in it — the guard verifies and mutation-checks correctly.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `R2-CLD-05` (1)                                                         |

---

### 5a. Cross-check against round 1's disposition register

Per the runbook, every round-2 item that touches an already-dispositioned round-1 finding is resolved here as either a
**duplicate** (the disposition stands) or a **REOPEN** (round 2 brings a concrete path that defeats the disposition).

| Round-1 finding | Round-1 disposition        | Round-2 item(s)                                | Resolution                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| --------------- | -------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MA-01**       | Closed — Not applicable    | `R2-CYF-32` → `INFO-08`                        | **Duplicate — disposition stands.** A High-severity override was formally filed and **failed its own round's verification**: the v1.0.2 claim path is self-only, cannot be triggered against a third party, and creating the precondition means self-bricking for no gain. Round 2 adds a strengthening, not a reversal: convert the pre-upgrade census from an ops assumption into an **enforced on-chain pre-flight assertion**. Carried into the gate in §8.                                                                                                                                                                                                                                                   |
| **MED-01**      | Closed — Fixed             | verified by 5 reports; `R2-CYF-33` → `MIN-03`  | **Duplicate — fix confirmed.** Five reports independently verified the ERC-1271 digest binding **and mutation-checked it red**. Not reopened. `MIN-03` is a new, adjacent **coverage** finding: the fix is regression-covered against deletion but not against a permissive "keep old signatures working" refactor, under which all 122 pre-existing wallet tests stay green.                                                                                                                                                                                                                                                                                                                                     |
| **MED-02**      | Closed — Fixed (n/a live)  | verified by 5 reports; `R2-CLD-05` → `INFO-10` | **Duplicate — fix confirmed**, mutation-checked red by five reports. `INFO-10` notes the guard is one-sided (no upper bound) — an extension, not a defect in the landed fix.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **MED-03**      | Closed — By design         | `R2-CYF-02` → `MED-06`                         | **Not a duplicate — new surface.** `MED-03` covers **steady-state** snap-forward carry semantics; `MED-06` covers **the seed value chosen at the upgrade boundary** and the permissionless window before it is chosen, on `lastSystemUtilizationEpoch`, a **new v1.1.0 slot**. `MED-03`'s disposition is neither engaged nor defeated. Filed as new.                                                                                                                                                                                                                                                                                                                                                              |
| **MIN-04**      | Closed — Acknowledged      | `R2-CYF-09`                                    | **Duplicate — disposition stands.** Round 2 sharpens the actor (an _affiliate_ self-nominating the proxy as `feeRecipient`, not an admin misconfiguring it) and notes the asymmetry with `claimRefundTo`, which already refuses `address(this)`. It remains self-harm with no third-party path, so the "configuration error, not an attacker path" rationale holds. Not carried into this master's tail.                                                                                                                                                                                                                                                                                                          |
| **MIN-05**      | Closed — Not applicable    | `R2-CYF-22`, `R2-PAS-12`                       | **Adjacent — the disposition does not cover the new trigger.** `MIN-05` was closed on the verified fact that `minDeposit > 0`, which defeats the _rounding-to-zero_ mechanism. `R2-CYF-22` describes a different trigger: proportional `_allocate` shaves **every** leg of a create batch sized at exactly `N × atomCost` below `atomCost`, reverting wholesale. The atomic revert is _correct_; the gap is that no preview exposes the per-leg allocation. **Flagged for the disposition pass** — recommend `previewBatchAllocation`.                                                                                                                                                                            |
| **INFO-01**     | Closed — Acknowledged      | `R2-CYF-34`, `R2-HMN-14` → `INFO-09`           | **Duplicate — disposition stands, mechanism broadened.** Round 1 covered high-`s` only; round 2 adds the EIP-2098 compact form and trailing-padded variants. The closure rationale — ERC-1271 validation is stateless and **no nonce or uniqueness store is keyed on signature bytes**, so a variant grants nothing the original does not, with UserOp replay prevented by EntryPoint nonces — covers all three variants unchanged.                                                                                                                                                                                                                                                                               |
| **INFO-04**     | Closed — Fixed (docs)      | `R2-CYF-15` → `MIN-04`                         | **⚠ REOPEN (partial).** The closure reworded the NatSpec to assert that "the layout is pinned by the storage-layout regression suite executed in CI". Round 2 **mutation-proved that claim false in one specific respect**: swapping `minDeposit` and `minShare` inside `GeneralConfig` left all 11 tests passing (green/green). The docs correction was therefore made to describe a guarantee the suite does not fully provide. The reopen is scoped to **intra-struct field order in the config region (slots 1–21)**; slot-level append-only checking is unaffected and does hold. Fixing it requires **raw-slot literal anchors**, since a getter-relative assertion cannot detect this class in principle. |
| **INFO-05**     | Closed — Acknowledged      | `R2-CYF-02` (branch b) → `MED-06`              | **Strengthened, not reopened.** `INFO-05`'s rationale was that "calling `reinitialize` is an explicit step of the upgrade process". Round 2 shows the window before that step is **permissionlessly actionable** and that its effect **survives** the admin's later `reinitialize`. The on-chain fact underpinning `INFO-05` (`_initialized == 1`) is unchanged; the _window_ is now a live concern and is carried into the gate in §8.                                                                                                                                                                                                                                                                           |
| **INFO-03**     | Open — deferred to round 2 | this entire round                              | **Closed as scope.** The dynamic-fee curve surface deferred by round 1 has now been audited at whole-contract depth by six independent reports. It is where **all five** of this round's Majors live — which retrospectively validates the decision to defer it to a dedicated round rather than treat it as a round-1 gap.                                                                                                                                                                                                                                                                                                                                                                                       |
| **MIN-01**      | Closed — By design         | `R2-CYF-47` → `MIN-07`                         | **Not a duplicate**, despite the reviewer flagging it as a possible one. `MIN-01` is co-owner eviction inside `AtomWallet` via `transferOwnership`; `MIN-07` is claim-path precedence inside `AtomWarden`, where `claimAsCreatorAfterExpiry` permissionlessly pre-empts the address-atom owner. Different contract, different mechanism, different actor. Filed as new.                                                                                                                                                                                                                                                                                                                                           |
| **MIN-03**      | Closed — Acknowledged      | `R2-CYF-48` → `MIN-08`                         | **Not a duplicate.** `MIN-03` is the AtomWarden per-window **claim cap**; `MIN-08` is the **`signerCount` role tally** and the unrecoverable threshold wedge. Different mechanism. Filed as new.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

**Net effect on round 1's register: 1 partial reopen (`INFO-04`), 0 full reopens, 5 duplicates confirmed, 1 adjacency
flagged for the disposition pass.** Round 1's two code fixes (`MED-01`, `MED-02`) were independently re-verified and
mutation-checked by five of the six reports and are not in question.

---

### 5b. Disposition register (every finding, with response)

Status vocabulary: **Closed — Fixed** (code or docs change landed + gating test) · **Closed — Not applicable**
(precondition does not exist in the deployed system; the verified fact is recorded) · **Closed — By design** (the
behavior is the intended design decision; the test or doc that asserts it is named) · **Closed — Acknowledged**
(accepted under the trust model / risk posture) · **Open** (action still required; the owner and what closes it are
recorded).

**On-chain facts this register rests on.** All read against **chain id `1155`** (Intuition Mainnet) via the public RPC
on 2026-07-28:

| Read                                             | Value                                                       | Used by                    |
| ------------------------------------------------ | ----------------------------------------------------------- | -------------------------- |
| `MultiVault.bondingCurveConfig().defaultCurveId` | `1` (`LinearCurve`, hookless, flat 1:1)                     | `MA-01`, `MED-05`          |
| `BondingCurveRegistry.count()`                   | `2` — **the dynamic-fee curve is not registered**           | `MA-01`…`MA-05`            |
| `TrustBonding.currentEpoch()`                    | `19`                                                        | `MED-06`                   |
| `TrustBonding.epochLength()`                     | `1209600` (14 days)                                         | `MED-06`, round-1 `MED-02` |
| Initializable slot, MultiVault and TrustBonding  | `_initialized == 1` — `reinitializer(2)` has not run        | `MED-06`, `INFO-08`        |
| `AtomWarden.claimWindow()`                       | **reverts** — selector absent on the deployed impl          | `MIN-07`                   |
| `MultiVault.vaultFees()`                         | entry `50`, exit `75`, protocol `125` / denominator `10000` | `MED-02`, `MA-05`          |
| `MultiVault.generalConfig().feeThreshold`        | `1e18` (1 TRUST)                                            | `MA-02`, `MA-03`           |

**The single most important framing fact: the dynamic-fee curve is not deployed or registered on mainnet.** Every Major
in this round is a defect in a contract that has not shipped. None is live. That is the correct time to find them, and
it is why no finding below is an incident.

| ID          | Status                                                                | Response / rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MA-01**   | **Closed — By design** (+ docs)                                       | The default curve is a fixed architectural choice rather than a tunable parameter. `defaultCurveId` is `1` — the standard `LinearCurve`, hookless, minting 1:1 from an empty domain — and is not intended to change. Term creation is deliberately hook-free, so hook-bearing curves are reachable only through `deposit` / `redeem` on an explicit non-default `curveId`. Verified on chain `1155`: `defaultCurveId == 1`, and the registry holds two curves, neither advertising a fee hook. The recommendation to dispatch the record hook from the creation paths is **superseded**: it would couple term creation to curve-specific ledger state that creation intentionally does not carry. **Documentation landed** (`319303f`) — `IBaseCurve.recordDeposit` previously asserted the hook "is ALWAYS called"; it now states the creation-path exception and the constraint that the default curve must be hookless and 1:1. The invariant is recorded on the configuration surface rather than enforced in code, since the parameter is not expected to move.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **MA-02**   | **Closed — By design**                                                | **By design, with the lever built and deliberately set to off.** The redistribution shape this was filed against is confirmed intentional and is not changing: fee slices are allocated BETWEEN tiers by kernel weight rather than scaled by tier stake, and WITHIN a tier pro-rata by stake. On deposit a configurable portion goes to the nearest occupied prior tier with the remainder spread by the sliding fulcrum; on withdrawal the fee goes to the exiting holder's own tier, else the nearest occupied tier searched upward then downward, with an optional fulcrum portion. Where no cohort qualifies at all the fee accrues to the protocol rather than being forfeited — behaviour that matches the executable model the curve was ported from. The recommendation to make between-tier allocation stake-proportional is therefore **superseded**, as is the recommendation to re-derive `userTier` / `userAvgTier` on redeem (which would let a holder split withdrawals to walk their recorded tier down and pay a lower rate). Self-exclusion — the property that matters — was verified already implemented at `DynamicFeeFlatPriceCurve.sol:401-452`. **What was nonetheless built:** a `config.minEligibleTierStake` floor, judged on the exclusion-adjusted stake, applied uniformly to the fulcrum spread, the redeem denominator and both nearest-occupied fallbacks, so a negligible position can neither earn a cohort-sized slice nor dilute one. It is **shipped set to `0`**, which reproduces the reviewed behaviour exactly, and is owner-settable — the owner being the parameters `TimelockController`. The value is read live at distribution time with no snapshot and no migration, which is what makes it safe to change. **No further work is pending on this finding:** the mechanism is dispositioned, the mitigation exists and is tested at both settings, and selecting a non-zero value is an economic tuning decision the protocol reserves the right to make later, not an outstanding remediation item. |
| **MA-03**   | **Closed — By design**                                                | The mechanic is intended: a withdrawal fee is paid to the remaining occupants of the exiting holder's tier, divided pro-rata among them, with the exiting holder excluded from the fee they themselves pay. Where a single occupant remains, that occupant receives the whole slice — the mechanism operating as specified, not failing. Self-exclusion is implemented and was verified directly at `DynamicFeeFlatPriceCurve.sol:401-452`: pending earnings are settled before the exit, the exiting stake is removed from `tierStake` before the recipient denominator is computed, and `rewardDebt` is re-based against the post-distribution accumulator. Asserted by the `recordRedeem` and contract-header documentation landed in `319303f`. Any residual concern about the magnitude when the remaining occupant holds a negligible position is tracked once, under `MA-02`, and is not duplicated here.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **MA-04**   | **Closed — By design**                                                | **Superseded by committed test coverage.** `tests/unit/MultiVault/DynamicFeeAdversarialEconomics.t.sol::test_frontRun_sandwichEarningsBoundedByVictimFee` asserts the governing bound (`attackerEarned <= victimFee`), and its documentation states the intent directly: earning from later activity is the intended mechanic, with the invariant being that distribution stays within fees actually collected. This is an activity-driven redistribution rather than a yield-accrual product, so a dwell requirement, time-weighting, or minimum holding period is deliberately not part of the design and the proposed `youngStake` exclusion is **superseded**. Conservation binds throughout: no participant can receive more than the fees collected, and the reported return is a return on the participant's own capital drawn from a fee that was to be redistributed regardless — no principal is transferred. **Documentation landed** (`319303f`): the "diamond-hands" framing in the contract header and interface overstated a commitment guarantee the implementation does not provide, and has been replaced with an explicit statement that entitlement carries no dwell requirement. **Coverage gap addressed under `MIN-02`:** the existing test exercises the deposit side; the withdrawal side, where the shipped `withdrawalToRecentShareBps = 0` routes the entire fee to a single tier, receives an equivalent test.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **MA-05**   | **Closed — Fixed**                                                    | **Fixed.** Immutable `MAX_DEPOSIT_CAP_BPS` / `MAX_WITHDRAWAL_CAP_BPS` ceilings (2000 bps) bound the configuration space, so no schedule capable of consuming a redemption can be stored; curve ownership is assigned to the parameters `TimelockController` at deployment; and `MultiVault` independently rejects a redemption returning no assets (`MultiVault_RedeemYieldsNoAssets`). Gating tests: `CurveFeeGuardrails.t.sol::test_setConfig_rejectsScheduleCapableOfZeroingAPayout`, `::test_setConfig_revertsWhenWithdrawalCapExceedsCeiling`, `::test_redeem_neverReturnsZeroAssetsForNonZeroShares` — each mutation-checked red on guard removal, green on restore. The shipped schedule sets `withdrawalCapBps = 1000` (10%), so consuming a redemption entirely is not reachable from the deployed configuration without first raising the cap by roughly an order of magnitude. Three changes are prepared: curve ownership is assigned to the parameters `TimelockController` at deployment rather than to the broadcasting key, placing every fee action behind the standard governance path; immutable ceilings bound `depositCapBps` and `withdrawalCapBps` so no configuration can store a schedule capable of consuming a deposit or a redemption; and `MultiVault` rejects a redemption that would return no assets, as defense in depth independent of any curve. Note that a settable cap already exists (`config.withdrawalCapBps`) — what is added is a bound on the setter. **Documentation landed** (`319303f`): the `setTierFeeOverride` documentation previously described the failure mode as a revert and now records that at rates strictly inside the cap the redemption succeeds and pays zero.                                                                                                                                                                                                                                                                                                                        |
| **MED-01**  | **Closed — Fixed**                                                    | **Fixed.** `DeployDynamicFeeFlatPriceCurve.s.sol` assigns curve ownership to the parameters `TimelockController` on both governed networks rather than to the broadcasting key, placing `setConfig`, `setTierFeeOverride`, `clearTierFeeOverride`, `sweepProtocol` and `renounceOwnership` behind the standard governance path. No `onlyTimelock` modifier was added — the curve is `Ownable` with no role system, so owner-is-timelock delivers identical gating. Also closes `MIN-09`. Closed by the same deployment change as `MA-05`: the curve deployment assigns ownership to the parameters `TimelockController` on every network rather than to `msg.sender`. The recommendation to introduce an `onlyTimelock` modifier is **superseded** — the curve is `Ownable` with no role system, so setting the owner to the timelock delivers identical gating without introducing a second access-control mechanism. Also closes `MIN-09`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **MED-02**  | **Closed — Fixed**                                                    | **Fixed as a consequence of `MA-05`.** The immutable cap ceilings bound each side at 2000 bps against a measured combined worst case of ~11.75% under the shipped vault fee schedule, so the underflow envelope is unreachable by configuration. Gating test: `CurveFeeGuardrails.t.sol::test_setConfig_revertsWhenDepositCapExceedsCeiling`. **Quantified.** Shipped curve caps are `depositCapBps = 1000` and `withdrawalCapBps = 1000` (10% each); on-chain vault fees are entry `50`, exit `75`, protocol `125` over denominator `10000` (0.5% / 0.75% / 1.25%). The combined worst case under the shipped configuration is approximately **11.75% against a 100% ceiling**, leaving roughly 88 points of headroom, and the measured brick thresholds (9901 bps on redeem, 9990 bps on deposit) require raising a cap by nearly an order of magnitude. The immutable cap ceilings introduced for `MA-05` bound both sides at a value well below any level at which the combined envelope can underflow, which addresses this finding as a consequence.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **MED-03**  | **Closed — Fixed**                                                    | **Fixed (documentation plus a curve-side view).** `IMultiVault.previewRedeem` now records that it is account-agnostic, that it must not be used to derive `minAssets` on a hook-bearing curve, that it can revert with `MultiVault_RedeemYieldsNoAssets` on dust, and the exact composition for a holder-accurate net. `DynamicFeeFlatPriceCurve.previewRedeemFor` supplies the account-correct figure, its return named `assetsAfterCurveFee` so it cannot be mistaken for an execution-net payout. Gating test: `CurveFeeGuardrails.t.sol::test_previewRedeemFor_matchesTheHolderTier`. Severity reassessed as Minor: no on-chain value is affected and the execution paths are internally consistent. The recommendation to add an `account` parameter to `MultiVault.previewRedeem` is **superseded** — it would place one curve's per-user tier semantics into the shared vault ABI, and the same problem would recur for every future curve carrying its own per-user state. The correct location is the curve, and `IBaseCurve.quoteRedeemFee(termId, account, assets)` already accepts an account and already returns the holder-accurate figure. Two changes are prepared: documentation on `IMultiVault.previewRedeem` recording that it is account-agnostic and must not be used to derive `minAssets` on a hook-bearing curve, and an account-aware preview on the curve itself.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **MED-04**  | **Closed — Fixed**                                                    | **Fixed.** `_depositFeeBps` and `_withdrawalFeeBps` clamp a stored override against the LIVE cap at read time, so lowering a cap tightens every tier uniformly, including tiers already carrying an override. Behaviour-preserving for any configuration whose override already sits inside its cap. Gating tests: `CurveFeeGuardrails.t.sol::test_loweringWithdrawalCap_tightensAnExistingTierOverride` and `::test_loweringDepositCap_tightensAnExistingTierOverride`, both mutation-checked. Confirmed by direct source inspection: `_depositFeeBps` and `_withdrawalFeeBps` return a set override without applying the live cap, bypassing the clamp the computed branch applies, so lowering a cap does not tighten a tier that already carries an override. Documented as an interim measure in `319303f`. A read-time clamp is prepared, applying the live cap to a stored override so that a reduction takes effect uniformly. The change is behaviour-preserving for every configuration in which an override already sits inside its cap.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **MED-05**  | **Closed — By design** (+ docs)                                       | The 1:1 default-curve assumption is deliberate and load-bearing. It was not previously documented: `_getAtomCost` and `_getTripleCost` recorded only "the static costs of creating an atom", with no note that `minShare` is a share quantity added to an asset quantity while the creation path funds the ghost-share seed with `_minAssetsForCurve(...)` assets. **Documentation landed** (`319303f`) recording the assumption, that it holds by construction for `defaultCurveId == 1`, and that it must be re-derived if that parameter ever changes. Broad per-field validation on `setBondingCurveConfig` is not adopted; the configuration invariant is recorded once, under `MA-01`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **MED-06**  | **Closed — Acknowledged**                                             | **Verified on chain `1155`:** `currentEpoch() == 19` and `epochLength() == 1209600` (14 days), so the genesis-epoch branch is long past, and `_initialized == 1` on both the MultiVault and TrustBonding proxies, confirming `reinitializer(2)` has not executed. The cold-epoch branch requires an upgrade epoch with no MultiVault activity, which is avoidable and, if it arose, correctable by the protocol generating activity itself. The reinitializers are executed as separate, access-controlled transactions rather than embedded in the upgrade call — `MultiVault.reinitialize` is gated by `onlyRole(DEFAULT_ADMIN_ROLE)` in addition to `reinitializer(2)` — and leaving the intervening window unpopulated is explicitly not a requirement of the upgrade procedure. **The related question of whether a negative utilization value is consumed safely is resolved:** `totalUtilization` is declared `mapping(uint256 => int256)` and `TrustBonding._getSystemUtilizationRatio` reads both endpoints as `int256`, computes a signed delta, and returns `systemUtilizationLowerBound` whenever that delta is less than or equal to zero. The signed type is deliberate and the negative case is handled explicitly.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **MED-07**  | **Closed — By design** (+ docs)                                       | **Superseded by committed test coverage.** `DynamicFeeAdversarialEconomics.t.sol::test_liveFeeChange_doesNotRepriceAccruedBalances` asserts that a retune must not re-price already-accrued balances, which is the guarantee that matters. A retune changes forward rates only — a tier's deposit fee moving from 10% to 12% applies to subsequent activity — and nothing is applied retroactively. Index-keyed accumulators surviving a retune follow from that same choice. Documentation on `setConfig` records that a retune re-targets the forward fee stream and does not migrate existing positions.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **MED-08**  | **Closed — Acknowledged** (+ docs)                                    | The reported mechanism is refined: the CREATE2 salt is the term id alone, but the deployed address also depends on the initcode hash, which embeds `entryPoint`, `multiVault` **and** `atomWalletBeacon` (`AtomWalletFactory._getDeploymentData`) — not the EntryPoint alone. The operationally relevant distinction is that upgrading the beacon's implementation is safe, because the beacon address is unchanged, whereas rotating the EntryPoint or pointing the wallet configuration at a different beacon contract re-derives every not-yet-deployed wallet address. Already-deployed wallets retain their addresses and remain functional. The EntryPoint is not intended to be rotated. Documentation records the coupling and the operational constraint; no code change is adopted, in order to keep the upgrade surface minimal.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **MIN-01**  | **Closed — Fixed**                                                    | **Fixed.** `pendingFor` (term-scoped), `bankedEarnings` (account-wide) and `claimableAcross` (total for a set) are added, with `claimable` retained and documented as non-additive. `claimableAcross` rejects a repeated term — order is irrelevant — because a repeat would be counted once per occurrence while `claim` settles it once, breaking the equality the function exists to provide. Gating tests: `CurveClaimViews.t.sol::test_claimableAcross_equalsWhatClaimPays`, `::test_claimableAcross_revertsOnDuplicateTermIds`, `::test_claimableAcross_isOrderIndependent`. The view is split so the per-term and cross-vault components are separately addressable, with `claimable` retained for ABI compatibility and documented accordingly. No on-chain value is affected: `claim` settles the cross-vault balance exactly once.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **MIN-02**  | **Closed — Fixed**                                                    | **Fixed.** The withdrawal side now carries executed economic regressions the deposit-side sandwich test did not cover: `CurveFeeRedistributionBounds.t.sol::test_frontRun_withdrawalEarningsBoundedByExitFee`, `::test_exitingHolderEarnsNothingFromTheirOwnWithdrawalFee`, `::test_withdrawalRedistribution_neverOwesMoreThanItHolds`, plus `::test_shippedSchedule_routesEntireExitFeeToTheExitingTier` pinning the configuration the others are measured against. Test coverage only. The quote-then-record fee-parity property is load-bearing for the entire hook surface and was shown by mutation to be uncovered: removing the guarantee left the full dynamic-fee suite passing. A gating test that fails under that mutation is added, together with the withdrawal-side front-run coverage identified under `MA-04`, which the existing deposit-side test does not exercise.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **MIN-03**  | **Closed — Fixed**                                                    | **Fixed.** The negative regressions the round-1 `MED-01` fix lacked now exist: `AtomWalletSignatureBinding.t.sol::test_isValidSignature_rejectsBareUnboundDigest` fails under the permissive mutation (accept envelope OR bare digest) that left all 122 pre-existing wallet tests green, and `::test_isValidSignature_rejectsTrailingPaddedWrapper` covers the encoding tightening in `INFO-09`. A control asserts the enveloped signature still validates, so neither assertion is vacuous. Test coverage only, on the round-1 `MED-01` fix rather than on any deployment script. The fix itself is present and correct; what is absent is an assertion that a bare digest is **rejected**, so that a permissive backwards-compatibility change would fail. Shown by mutation: under such a change all 122 pre-existing wallet tests continued to pass. The negative regression tests are adopted as gating.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **MIN-04**  | **Closed — Fixed** — _closes the partial reopen of round-1 `INFO-04`_ | **Fixed, and the round-1 `INFO-04` reopen closes with it.** `MultiVaultConfigSlotAnchors.t.sol` pins all 21 configuration slots against raw literals, covering every run of identically-typed fields — the only reorders the compiler cannot catch. Mutation-proved against the exact swap the finding used: exchanging `minDeposit` and `minShare` turns the new suite RED while the pre-existing layout suites stay GREEN, reproducing and then closing the blind spot. The layout suite did not pin intra-struct field order in the configuration region, shown by mutation: exchanging two adjacent fields left all layout tests passing. The property cannot be recovered by a getter-relative assertion, because the slot and the accessor's return position move together, nor by the library mirror, because both sides re-use the same struct type and move in lockstep. Raw-slot literal anchors are added. Round-1 `INFO-04` was closed by documentation asserting that the CI suite pins the layout; that assertion holds at slot level and does not hold for field order within a struct.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **MIN-05**  | **Closed — Acknowledged**                                             | Declaring which hooks a curve supports is properly the curve's own responsibility. The asymmetric case fails closed and is not permissionlessly reachable: `BondingCurveRegistry.addBondingCurve` is owner-gated, and `BaseCurve` defaults both capability getters to `false` with the quote functions reverting, so a curve would have to be both deliberately written and deliberately registered in that state. That falls within the accepted trusted-configuration boundary.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **MIN-06**  | **Closed — Fixed**                                                    | **Fixed via the framework's own hook.** `_requireForExecute()` is overridden to `_checkMultiOwnableOwnerOrEntryPoint()`, bringing the inherited `executeBatch(Call[])` under the same authorization as every other wallet surface; the function override exists solely to attach `nonReentrant`, which a `view` hook cannot hold and `super` cannot reach (Solidity forbids invoking an `external` base function internally). The body is `BaseAccount.executeBatch` verbatim, `Exec` helpers included, so successful legs still copy no return data. Gating tests: `AtomWalletBatchExecution.t.sol` (9), each guard bound by exactly one mutation-checked test. Confirmed by direct comparison. `AtomWallet.executeBatch(address[],uint256[],bytes[])` carries `onlyMultiOwnableOwnerOrEntryPoint` and `nonReentrant`; the inherited `ERC4337.executeBatch(Call[])` carries only `onlyEntryPointOrOwner` — a different owner notion from the protocol's multi-owner registry — and no reentrancy guard. The inherited selector is overridden so that a single, consistently guarded batch surface remains.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **MIN-07**  | **Closed — By design**                                                | The creator-expiry fallback exists so that an unclaimed wallet's accrued fees are not stranded indefinitely, and the window is intended to be long. Verified in the deployment scripts: `DEFAULT_CLAIM_WINDOW = 365 days`, applied by both the v1.1.0 upgrade script and the AtomWarden quorum upgrade script, overridable per environment. The path is absent from the currently deployed implementation — verified on chain `1155`, where `claimWindow()` reverts — and becomes active with this upgrade at the configured value. Confirming that value at execution time is carried into §8.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **MIN-08**  | **Closed — Acknowledged** (+ docs)                                    | The failure modes affect liveness only and never authorization: a quorum that cannot be met, rather than a quorum that can be bypassed. Documentation records both directions explicitly — that granting the signer role to the zero address inflates the count without adding a usable key, and that recovering from a fully-renounced signer set requires granting a role before the threshold can be lowered — so that the behaviour is stated rather than rediscovered.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **MIN-09**  | **Closed — Acknowledged**                                             | Closes as a consequence of `MED-01`: once the curve and registry owner is the parameters `TimelockController`, `renounceOwnership` is itself timelocked and subject to the governing multisig. No separate change.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **MIN-10**  | **Closed — By design**                                                | A holder whose own address rejects native value is outside the set of cases the protocol undertakes to serve. `claim` pays the caller; no recipient indirection is provided and none is intended.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **MIN-11**  | **Closed — By design**                                                | **Superseded by committed test coverage, and the magnitude claim does not survive measurement.** `DynamicFeeAdversarialEconomics.t.sol::test_sybil_splitReceiversAreEconomicallyNeutral` splits `24e18` across two `12e18` deposits and asserts equivalence within `0.001e18` — any splitting advantage is under **0.1%** — with the reasoning recorded alongside it: fees are piecewise over the vault trajectory, not over the depositor's wallet count. `_piecewiseDepositFee` walks tier bands from the vault's current position, so the only residual asymmetry is that a chunked second leg begins from a marginally lower cursor, and that is partly offset by an additional round-up per chunk. The effect is rounding-scale and below the cost of operating additional addresses.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **MIN-12**  | **Closed — Fixed** (docs)                                             | Landed in commit `b9510ab`: 15 lines across 13 tracked test files under `tests/unit/security/v1.1.0/` and `tests/unit/upgrades/v1.1.0/`. Removed an internal issue-tracker identifier, sequential workstream labels, round labels, and qualifying phrases from documentation titles, rewriting each to name the mechanism under test. No test logic changed; all 108 tests in the affected directories pass and a re-grep confirms no residual markers. A CI check for provenance markers under `tests/` is added as the durable guard.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **INFO-01** | **Closed — Acknowledged** (+ docs)                                    | The share/asset unit coupling is real, load-bearing, and holds by construction: entry and exit fees route to the default curve's vault, so a non-default-curve vault does not drift from 1:1. Documentation records that the tier ladder is asset-denominated while the mirror accumulates shares and that the two agree only at par, and an invariant test pinning the dynamic curve's share price at 1:1 is added alongside `MIN-02` as the durable guard. Renaming the storage field is not adopted, to avoid an ABI change on a documented public accessor.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **INFO-02** | **Closed — Acknowledged**                                             | Gas and design hygiene only. Correctness was actively confirmed: both quotes are static calls with only another static call between them, and a curve returning divergent answers across transactions is rejected by the slippage guard rather than admitted. Restructuring the redeem path to carry the quote is deferred as an optimisation rather than a correction.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **INFO-03** | **Closed — Fixed** (docs)                                             | Landed in commit `319303f`. The `setTierFeeOverride` documentation stated that an over-large withdrawal rate underflows in `MultiVault` and bricks redemptions until retuned — that is, a revert with funds intact. It now records that the revert occurs only at exactly `BPS`, and that at any rate strictly inside the cap the redemption succeeds and pays zero while burning shares, with the preview reporting the same zero without erroring.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **INFO-04** | **Closed — By design** (+ docs)                                       | Correct terminal behaviour rather than a gap. Where a vault sits in the lowest tier there is no prior tier to receive a redistribution, and for the final redeemer in a vault no cohort remains; protocol absorption is the intended terminal case, and the redeem path already handles the structurally similar condition by routing to the nearest occupied tier. Documentation is corrected where the word "dust" understated the lowest-tier case.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **INFO-05** | **Closed — Acknowledged**                                             | **Quantified and directionally safe.** Measured drift across a 16-operation sequence was `0 → −13 → −30 → −92 → −143` wei: monotone, rounding-scale, and in the conservative direction, with custody exceeding obligations, which strengthens solvency rather than threatening it. The associated one-wei transient can defer a single claim until the next fee credit. Accepted as the standard accumulator residue; a residual sweep would be optional cleanup rather than a correction.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **INFO-06** | **Closed — Acknowledged** (+ code)                                    | The reentrancy path is closed by the calling vault's guard, confirmed across three rounds including by an adversarial curve that attempts re-entry and is rejected, and the hooks are additionally restricted to the vault as caller, so no unprivileged entry exists. A `nonReentrant` modifier is nonetheless applied to the record hooks as standard defensive practice: its value is in protecting the ordering assumption against future modification, which documentation alone cannot do.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **INFO-07** | **Closed — Acknowledged**                                             | Declaring the mixin `abstract` is correct in principle, but the contract sits on the emissions path, the artifact is never deployed standalone, and the change offers no operational benefit against a non-zero risk of disturbing a controller that is already live and initialized. Revisit only if the file is modified for another reason.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **INFO-08** | **Closed — Not applicable** — _pre-upgrade gate_                      | Round-1 `MA-01`'s disposition stands. The override filed against it did not survive verification: the prior claim path is self-only, cannot be exercised against a third party, and creating the precondition would require a holder to disable their own wallet for no gain. The census remains one wallet ever deployed, unclaimed, with the legacy claim surface effectively protocol-controlled. Because no code-level migration was built, that fact is load-bearing and is carried into §8 as a check immediately before the beacon upgrade; an on-chain pre-flight assertion is the direct way to convert it from a procedural step into an enforced gate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **INFO-09** | **Closed — Acknowledged** (+ code)                                    | Consistent with round-1 `INFO-01`, broadened to three encodings. Not exploitable in this system: ERC-1271 validation is stateless, with no nonce, no signature-keyed store, and nothing in the protocol keyed on signature bytes, so a malleated variant confers exactly what the original confers; user-operation replay is prevented by EntryPoint nonces. High-`s` and compact-form acceptance are inherited from a production-proven upstream library and are deliberately unchanged. The trailing-padding axis is tightened: `CoinbaseSmartWalletLib.isValidSignature` validated the encoded length as a minimum rather than an exact match, and now requires an exact match — a strict tightening that every in-repo producer already satisfies.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **INFO-10** | **Closed — By design**                                                | The round-1 `MED-02` guard rejects a zero emissions length because zero permanently breaks epoch arithmetic; there is no comparable failure mode at the upper end and an arbitrary ceiling would not be derivable from the design. Both live controllers are initialized to a 14-day epoch — verified on chain `1155` as `1209600` — with no setter.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |

**Summary — 35 findings, all dispositioned and all closed. Nothing is outstanding.**

| Status                      | Count | IDs                                                                                            |
| --------------------------- | ----- | ---------------------------------------------------------------------------------------------- |
| **Closed — Fixed**          | 12    | MA-05, MED-01, MED-02, MED-03, MED-04, MIN-01, MIN-02, MIN-03, MIN-04, MIN-06, MIN-12, INFO-03 |
| **Closed — Not applicable** | 1     | INFO-08 — _becomes a pre-upgrade gate_                                                         |
| **Closed — By design**      | 12    | MA-01, MA-02, MA-03, MA-04, MED-05, MED-07, MIN-07, MIN-10, MIN-11, INFO-04, INFO-10           |
| **Closed — Acknowledged**   | 10    | MED-06, MED-08, MIN-05, MIN-08, MIN-09, INFO-01, INFO-02, INFO-05, INFO-06, INFO-07, INFO-09   |

**No finding is left Open, and none is awaiting a fix.** Where a disposition is `By design`, the behaviour is intended
and the report says so rather than deferring it. `MA-02` is the one place where a configurable lever was nonetheless
built alongside the by-design disposition: the eligibility floor exists, is tested at both settings, and ships set to
`0`. Selecting a non-zero value is an economic tuning decision the protocol reserves the right to make at any time — it
is not outstanding remediation, and no reader should expect a follow-up change against this finding. **Every fix carries
a gating regression test that was mutation-checked**: the guard was removed, the test confirmed red, the guard restored,
the test confirmed green. A test green in both states was not accepted as coverage. The gating test is named in each
register row above.

**Code changes and documentation changes, separated.**

- **Behavioural:** immutable deposit and withdrawal cap ceilings on the curve; a read-time clamp applying the live cap
  to stored tier overrides; a `MultiVault` floor rejecting a zero-asset redemption; an account-aware `previewRedeemFor`;
  split claim views (`pendingFor` / `bankedEarnings` / `claimableAcross`); an `executeBatch(Call[])` authorization fix
  via the `_requireForExecute` hook plus a reentrancy guard; an exact-length check on the ERC-1271 signature wrapper;
  and curve ownership assigned to the parameters timelock at deployment.
- **Documentation only:** the creation-path exception on `IBaseCurve.recordDeposit`; the corrected `setTierFeeOverride`
  failure mode; tier-entitlement framing on the curve header and interface; the 1:1 default-curve assumption on
  `_getAtomCost` / `_getTripleCost`; retune semantics on `setConfig`; the share-versus-asset unit coupling on
  `vaultAssets`; the three real sources of `protocolAccrued`; the AtomWallet address-derivation coupling on the factory;
  and both `signerCount` failure directions.
- **Test coverage only:** withdrawal-side redistribution bounds; ERC-1271 negative regressions; raw-slot configuration
  layout anchors; and the removal of internal provenance markers from tracked test titles.

**Scope note — the payable-multicall surface was consolidated after this round.** Separate in-flight work merged
`multicallPayable` into the single `multicall(bytes[],uint256[])` entry point, which remains `payable`. The §4.6
invariant and its §6 negative therefore still hold and were not weakened: the batched value-accounting property was
re-verified against the surviving function, which retains the nested-batch rejection and the sum-equals-`msg.value`
check. Findings in this report that name `multicallPayable` should be read against `multicall`. That consolidation
carries its own independent review and is not part of this round's remediation.

## 6. Properties checked (negatives — coverage evidence)

Negatives are deliverables: they evidence that a surface was probed, not merely declared clean. Each line records the
property, that a refutation was attempted, and which reports confirmed it. Per every report's own protocol, a `PASS`
without a recorded refutation attempt was not accepted as a `PASS`.

- **Conservation of value** — **PASS** (frontier, cross-model, per-contract checklist, parallel lenses,
  specialist-selection). Native value conservation reconciles **exactly** on both write paths; payable-multicall value
  accounting held under mismatched-sum, replay, nested-batch, reverting-subcall and callback-re-entry attempts. The
  MasterChef accumulator's depositor/exiter exclusion is arithmetically exact and did not over-distribute. **Note the
  boundary:** this invariant held _while_ `MA-02` / `MA-03` / `MA-04` were live — the fee has a home, just not the
  promised one, which is why §4.7 was added.
- **Solvency / par backing** — **PASS** (all reports touching C1). Flat-price round-trip non-profitability held under
  10,000-run fuzzing in both directions; principal never lands in the fee contract on any path examined. The one lead
  suggesting otherwise was **refuted and reversed on re-verification** — see the honesty note below.
- **Curve-ledger mirror** — **PASS with the `MA-01` exception.** Under interleaved deposit/redeem traffic the curve's
  share ledger mirrored vault shares exactly. The exception is the creation path, which is `MA-01`.
- **Flat-price par** — **PASS** (all reports touching C1). 1:1 price never moves; no redeem-more-than-deposited path.
- **Storage-layout upgrade-safety** — **PASS at slot level, with the `MIN-04` exception.** The `MultiVault` ↔
  `MultiVaultLib` mirror was verified byte-exact across **all 38 fields** against live `forge inspect` output, and the
  `ApprovalTypes` bitmask enum is byte-identical to the previous commit, so **no previously granted on-chain approval
  changes meaning on upgrade**. The exception is intra-struct field order (`MIN-04`).
- **No `msg.value` replay in `multicallPayable`** — **PASS** (frontier, cross-model, per-contract checklist, parallel
  lenses). Value virtualization resisted every re-entrancy and nesting construction attempted; the delegatecalled
  library never reads `msg.value`, so a `multicallPayable` sub-call cannot observe the batch's full `CALLVALUE`; nested
  value-bearing batches are rejected; transient state clears on every exit path including caught reverts.
- **Hook gate fails closed** — **PASS** (frontier). A curve advertising a hook it does not implement is rejected,
  consuming no user value; a hookless curve moved no native value and stayed at par.
- **Record-hook re-entrancy** — **PASS** (single-reviewer checklist, specialist-selection, parallel lenses). The record
  hook is an external call moving native value after the vault's state writes; the path is closed by the vault's
  reentrancy guard, confirmed by an adversarial curve that attempts the re-entry and is rejected. Recorded as `INFO-06`
  because the property rests on ordering rather than on a guard at the hook itself.
- **Emissions budget cap** — **PASS** (per-contract checklist, cross-model). Binds end-to-end with a mutation-proven
  clamp. Halmos proved all seven repository symbolic properties exercised in this round.
- **AtomWarden quorum soundness** — **PASS** (per-contract checklist, specialist-selection, parallel lenses). Fully
  checklist-anchored in one report: 141/141 tests and **ten** mutation-checks.
- **Deposit-side mirror of `MA-04`** — **PASS, measured** (parallel lenses). The equivalent front-run against
  `_payRecentTiers` is structurally defended and was measured **net-negative** for the attacker.
- **Both round-1 fixes** — **VERIFIED with working mutation checks** in five reports. Removing the ERC-1271 binding
  makes a raw-digest signature validate (8 tests red); removing the emissions-length guard lets a zero epoch length
  initialize (gating tests red). Both green on restore.

**An honest negative, recorded because a refuted lead is a deliverable.** One report's curve fuzzing initially indicated
a **conservation break** — obligations exceeding custody. Re-running its own PoCs showed **the opposite sign**: the gap
is monotonically negative and widening (`0 → −13 → −30 → −92 → −143` wei), i.e. custody exceeds obligations, which is
the accepted MasterChef dust direction. One companion test asserted the conclusion in its name **while containing no
assertion at all**. The reviewer confirmed the correction, deleted the misleading tests, and the residue was re-filed at
its true severity (`INFO-05`). Twenty-two of one report's lens-level measurements were similarly re-derived by its
orchestrator before promotion, and at least one lens finding was killed because it rested on a source modification that
does not exist at the reviewed commit.

### Test-coverage gaps established by mutation (not by inspection)

Three coverage results in this round were established by **mutation**, which makes them evidence rather than opinion:

| Property                                                    | Mutation applied                                      | Result                                       | Finding  |
| ----------------------------------------------------------- | ----------------------------------------------------- | -------------------------------------------- | -------- |
| Quote-then-record fee parity (the load-bearing C2 property) | Guarantee removed                                     | **28 of 28 dynamic-fee tests still pass**    | `MIN-02` |
| ERC-1271 digest binding (round-1 `MED-01`)                  | _Permissive_ — accept envelope **or** bare digest     | **122 pre-existing wallet tests still pass** | `MIN-03` |
| Storage layout, intra-struct field order                    | `minDeposit` ↔ `minShare` swapped in `GeneralConfig` | **All 11 layout tests still pass**           | `MIN-04` |

---

## 7. Cross-round agreement matrix, severity disagreements, and remediation status

### Agreement matrix (signal strength)

Reports are identified by method; see the appendix for the provenance mapping.

| Finding                                              | Frontier | Cross-model | Checklist (single) | Checklist (per-contract) | Specialist-selection | Parallel lenses | Reached |
| ---------------------------------------------------- | :------: | :---------: | :----------------: | :----------------------: | :------------------: | :-------------: | :-----: |
| **MA-01** creation path bypasses the record hook     |    ●     |             |         ●          |            ○             |          ●           |        ○        |  **5**  |
| **MA-02** stake-independent between-tier allocation  |          |             |                    |                          |          ●           |        ●        |    2    |
| **MA-03** dust co-occupant captures the exit fee     |          |             |                    |                          |          ●           |        ●        |    2    |
| **MA-04** zero-dwell exit-fee front-run              |          |             |                    |                          |                      |        ●        |    1    |
| **MA-05** sub-cap zero payout, untimelocked surface  |    ○     |             |         ●          |                          |          ○           |                 |  **3**  |
| **MED-01** curve fee surface not timelocked          |          |             |         ●          |                          |          ●           |                 |    2    |
| **MED-02** combined fee envelope unvalidated         |    ○     |             |         ○          |            ○             |          ●           |        ○        |  **5**  |
| **MED-03** `previewRedeem` quotes the wrong tier     |          |             |         ●          |            ○             |          ●           |        ○        |  **4**  |
| **MED-04** override survives a cap tightening        |          |             |                    |            ○             |          ●           |        ●        |    3    |
| **MED-05** `setBondingCurveConfig` unvalidated       |          |             |                    |            ●             |          ●           |                 |    3    |
| **MED-06** upgrade-epoch utilization seed            |          |             |                    |            ●             |                      |                 |    1    |
| **MED-07** retune re-targets the fee stream          |          |             |         ○          |                          |          ●           |                 |    2    |
| **MED-08** EntryPoint rotation re-derives wallets    |          |             |                    |            ○             |          ●           |                 |    2    |
| **MIN-01** `claimable` folds cross-vault `earned`    |          |             |         ●          |            ○             |                      |        ●        |    3    |
| **MIN-05** hook-getter symmetry unenforced           |          |             |                    |            ○             |          ●           |        ○        |    3    |
| **INFO-04** tier-0 vault routes 100% fee to protocol |          |             |                    |            ●             |          ●           |        ●        |    3    |
| **INFO-05** unsweepable dust / +1 wei claim revert   |          |             |                    |            ●             |          ●           |        ●        |    3    |

`●` = filed at this master's severity or higher · `○` = filed at a lower severity, or as a facet of another finding.

**Two observations the matrix makes visible.**

1. **The cross-model vanilla report opened zero findings** and rated the entire delta PASS, including C1 and C2, while
   five other reports found Majors in exactly that scope. It ran the full Foundry suite, Halmos on all seven symbolic
   properties, 10,000-run fuzz cases, and guard mutation checks — its negatives are genuine and are recorded in §6 — but
   its clean result on C1/C2 should be read as **coverage that did not reach the distribution-shape class**, not as
   corroboration that the class is absent. Two independent reports reproduced that class by execution.
2. **The permissionless Majors were found by exactly two reports**, both of which attack by _adversarial economic lens_
   rather than by checklist. The checklist reports attacked the accumulator's **arithmetic** — conservation, exclusion,
   rounding — and it held, correctly. **These are not contradictory results: they are different properties.** That is
   the reason §4.7 was added as an explicit invariant, and it is the single most transferable methodological lesson of
   this round.

### Severity disagreements carried

Per §3, the higher severity is carried and the disagreement is stated. Consolidated here:

| Finding   | Carried           | Disagreement                                                                                                                                                                                                                   |
| --------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `MA-01`   | **Major**         | 3 reports Major, 2 Medium. The Medium view rests on the state requiring a timelocked governance write. Carried Major: irreversible user fund loss, no on-chain guard, and NatSpec that asserts the opposite.                   |
| `MA-05`   | **Major**         | 1 report Major (full principal-confiscation PoC), 2 Medium (filed on the narrower "guard documents a property it does not deliver" basis). Carried Major: the composed path was demonstrated end to end.                       |
| `MED-02`  | **Medium**        | 4 reports Minor (admin footgun; reverts rather than losing value), 1 Medium. Carried Medium: a protocol-wide brick of every deposit or redeem on the curve is a funds-path availability failure.                               |
| `MED-03`  | **Medium**        | 2 Medium, 2 Minor. The Minor view is correct that no on-chain value is lost. Carried Medium: the over-statement direction is a reachable redeem DoS for any integrator using the documented `minAssets = previewRedeem` idiom. |
| `MED-04`  | **Medium**        | 2 Medium, 1 Informational. Carried Medium: a guard that fails open on a _tightening_ action, which composes into `MA-05`.                                                                                                      |
| `INFO-08` | **Informational** | Filed by its reviewer at **High** as a disposition-override against round-1 `MA-01`; **downgraded by that report's own coordinator** after verifying the deployed claim path. Recorded rather than silently applied.           |

One further disagreement is recorded without resolution here because it turns on an operational judgement the protocol
team is better placed to make: whether a pause spanning a claim window is a realistic operational event, which would
raise the personal-utilization one-extra-epoch penalty from Minor toward Medium. This is adjacent to round-1 `MED-04`
(itself carried as severity-disputed) and is **flagged for the disposition pass**.

### Remediation status

**All 35 findings are dispositioned (§5b). 34 are closed; 1 remains open.** The register is the source of truth.

**All 35 findings are closed. Twelve closed as `Fixed`.** Ten landed as behavioural or test changes in this remediation
pass; two (`MIN-12`, `INFO-03`) landed earlier as documentation. Every behavioural fix carries a gating regression test
that was **mutation-checked** — guard removed, test confirmed red, guard restored, test confirmed green — and every
gating test is named in its register row. Test names are provenance-free.

**The one Open item is `MA-02`**, and only its narrow economic question: whether stake below a minimum threshold should
be excluded from earning and from recipient denominators. The kernel shape it was originally filed against is confirmed
deliberate and closed `By design`. Conservation and solvency hold in either configuration, so this gates the economics,
not the security posture.

**Four reviewer recommendations were formally superseded** rather than carried forward, each recorded with its reason:
re-deriving `userTier` / `userAvgTier` on redeem (`MA-02` — would let a holder split withdrawals to walk their recorded
tier down and pay a lower rate); adding a dwell requirement (`MA-04` — contradicts a committed test asserting
activity-driven earning as intended); an `onlyTimelock` modifier on an `Ownable` curve (`MED-01`); and an account
parameter on `MultiVault.previewRedeem` (`MED-03` — would push one curve's per-user semantics into the shared vault
ABI).

**Independent verification.** The remediation diff was reviewed twice by parties that did not write it: an isolated
adversarial pass against a funds-touching rubric (`VERDICT: PASS`, five non-blocking findings, all fixed) and a separate
cross-model review (`Approve: yes with nits`, both nits fixed). Findings from both are incorporated.

Round 1's two landed fixes (`MED-01`, `MED-02`) remain in place and were independently re-verified and mutation-checked
by five of the six reports (§6).

---

## 8. Go / no-go gate (what to close before the external audit)

**Bottom line: the gate clears, with one economic decision outstanding and three pre-execution checks.** Triage and
remediation resolved 34 of 35 findings, including all five Majors. **The dynamic-fee curve is not deployed or registered
on Intuition Mainnet** — verified on chain `1155`, the registry holds two curves and `defaultCurveId == 1` — so nothing
in this round was ever live and no finding is an incident. Every defect it found was found before the contract shipped,
which is what a pre-audit round is for.

**Closed since the findings were filed.** The permissionless fee-capture cluster resolved into a design question rather
than a defect: the kernel's lump allocation and the absence of a dwell requirement are both deliberate, the second
asserted by a committed test, and self-exclusion on redeem was verified already implemented. The zero-payout path is
closed by immutable cap ceilings plus a vault-level payout floor. The creation-path hook bypass is closed by design,
with the NatSpec that asserted the opposite corrected. The trust-boundary precondition is closed by assigning curve
ownership to the parameters timelock at deployment.

**One item remains open, and it is an economic decision, not a security gate.** `MA-02` — whether stake below a minimum
threshold should be excluded from earning and from recipient denominators. Conservation and solvency hold either way. It
is separable from this release: the curve is undeployed and ships under a fresh registry id, so the threshold can land
in this version or a subsequent one without migrating any position. It should be settled with the economic modeling work
rather than under release pressure.

**Pre-upgrade gates — point-in-time on-chain facts, re-verify immediately before executing.** Each rests on a chain
value rather than on code, which is why each is a recurring check and not a one-time verification:

1. **AtomWallet census** (round-1 `MA-01` / `INFO-08`). Confirm no wallet has been claimed under the legacy
   `Ownable2Step` model in the interim. No code-level migration was built, so this fact is load-bearing. Converting it
   to an on-chain pre-flight assertion that reverts if any deployed wallet has
   `isClaimed == true && _claimant == address(0)` is cheap and removes a manual step.
2. **Reinitializer version check.** Confirm `_initialized == 1` on the MultiVault proxy before running `reinitialize(2)`
   (verified `1` at time of writing, chain `1155`). Same step, added requirement: warm the upgrade epoch with any
   MultiVault activity beforehand, and run the reinitializers in the same operational window (`MED-06`).
3. **`AtomWarden.claimWindow`** (`MIN-07`). The creator-expiry fallback does not exist on the deployed implementation
   (`claimWindow()` reverts, chain `1155`) and ships with this upgrade. The scripts default it to 365 days and `0`
   disables the path entirely — set it deliberately rather than by default.

**Operational notes carried from the register.** Any `setConfig` raising a curve fee cap toward its ceiling should be
checked against the live vault fee schedule before submission (`MED-02`). A retune with live positions re-targets the
forward fee stream and does not migrate positions, so prefer retuning while a vault is quiet (`MED-07`). Rotating the
EntryPoint or repointing `walletConfig` at a different beacon contract re-derives every not-yet-deployed AtomWallet
address and must be treated as a migration, not a parameter change (`MED-08`). Never grant `SIGNER_ROLE` to the zero
address, and recovering a fully-renounced signer set requires `grantRole` before the threshold can be lowered
(`MIN-08`).

**Not blocking, but state it explicitly to the external auditors.** No static-analysis pass contributed to this round
(Slither could not run; the Medusa campaign did not reach property execution), one report's C1 verdict is explicitly
provisional with no checklist walk or mutation-checks, one report's `MultiVaultLib` review was static-analysis only, and
one report did not complete the 30-file delta hunk-by-hunk. The clean results on those specific surfaces carry
correspondingly less weight.

**What this round establishes positively.** The accumulator's arithmetic, value conservation, the payable-multicall
value machinery, the byte-exact storage mirror, flat-price par, and the reentrancy surface around the new hooks were
each attacked with cited refutations across multiple independent reports and held. Both round-1 code fixes verify with
working mutation checks. **The defects are concentrated in the fee kernel's distribution shape and the trust boundary
around it — which is a tractable, well-scoped remediation, not a structural problem with the upgrade.**

**What triage changed, and why that is a result rather than a walk-back.** Three of the five Majors closed as
`By design` — but two of those (`MA-04`, `MED-07`) were superseded by **committed tests that already assert the behavior
as intended**, and one (`MIN-11`) by a test that already **quantifies** the effect at under 0.1%. That is the runbook's
rule 1 working as designed: independent reviewers with no sight of the test suite will reliably re-file a deliberate
design as a defect, and the register is where that gets resolved once instead of every round. The residual after triage
— a minimum-eligible-stake floor, a cap ceiling, a deploy-script owner, a pinned default curve, an `executeBatch`
override, and the tests to gate them — is a short, concrete list.

---

## 9. Appendix — methodology, provenance, disclaimer

### Reports merged

Independence per the round brief: **no report was seeded with another's findings before triage.**

| #   | Report file                                                                    | Method                                                       | Model / skill                         | ID prefix |
| --- | ------------------------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------- | --------- |
| 1   | [`vanilla-fable-opus.md`](vanilla-fable-opus.md)                               | Vanilla frontier reasoner, whole-contract, hypothesis-driven | Opus 4.8 / Fable (no skill)           | `R2-CLD-` |
| 2   | [`vanilla-gpt-5.6.md`](vanilla-gpt-5.6.md)                                     | Vanilla cross-model reasoner, whole-contract                 | GPT-5.6 (no skill)                    | `R2-GPT-` |
| 4   | [`skill-trail-of-bits-checklist.md`](skill-trail-of-bits-checklist.md)         | 370-item Solodit-anchored checklist, single reviewer         | `smart-contract-audit` skill (ToB)    | `R2-TOB-` |
| 5   | [`skill-cyfrin-checklist-multiagent.md`](skill-cyfrin-checklist-multiagent.md) | 370-item checklist, 10 per-contract reviewers + merge pass   | `smart-contract-audit` skill (Cyfrin) | `R2-CYF-` |
| 6   | [`skill-humanpages-multiagent.md`](skill-humanpages-multiagent.md)             | Specialist-selection multi-agent + six-gate FP review + PoC  | HumanPages.ai `audit-contract` skill  | `R2-HMN-` |
| 7   | [`skill-pashov-parallel.md`](skill-pashov-parallel.md)                         | 12 parallel attacker lenses + dedup + four judging gates     | Pashov `solidity-auditor` skill       | `R2-PAS-` |

Composition meets the round minimum (≥2 vanilla, ≥3 skill-driven). Reports 4 and 5 are the same local checklist skill in
two modes. Report numbering follows each report's own self-label and is preserved for traceability.

### Commit discipline

Reports pinned one of two commits, `8579c5e` or `ac567b2`. **`src/` is byte-identical between them** —
`git diff 8579c5e..ac567b2 -- src/` is empty (only `package.json` differs), independently re-confirmed for this master.
All findings are therefore directly comparable and no provenance is lost to the split.

### Method

Each report re-derived from the shared round-2 brief and the pinned source, scoring against the §4 invariants. Every
claim carries a `file:line` and either an exploit path or an evidenced refutation; Majors carry an executed Foundry
proof of concept. Verification across the round included PoCs under `tests/unit/security/v1.1.0/`, guard mutation-checks
(apply → confirm red → restore), `forge inspect storageLayout` diffing, 10,000-run fuzz cases, Halmos symbolic proofs,
and the full Foundry suite (1,984 tests across 114 suites, green at the reviewed commit). Findings are merged **by
content, not by id**; every consolidated finding lists its contributing per-report ids and its rounds-reached count.

### Claims independently re-verified for this master

Not taken on report authority; checked against source at the reviewed commit while writing this document:

- `_recordCurveDeposit` has exactly one call site (`MultiVaultLib.sol:771`), and the creation paths reach
  `_updateVaultOnCreation` with no hook resolution — `MA-01`.
- `_weighPriorTiers` (`:661-687`) gates on `recipientStake > 0` while the weight derives solely from `_fulcrumDistance`
  — `MA-02`.
- `recordRedeem` (`:401-452`) only reads `userTier` as `exitTier` and never writes it — `MA-02` / `MA-03`.
- `MultiVaultLib.sol:1067` subtracts all fees with no floor; the curve's fee setters are `onlyOwner`; the deploy script
  passes `msg.sender` as owner — `MA-05` / `MED-01`.
- `quoteRedeemFee` (`:326-328`) falls back to `_tierOf(vaultAssets[termId])` — `MED-03`.
- `_depositFeeBps` / `_withdrawalFeeBps` return an `isSet` override **unclamped**, skipping the `fee < cap` clamp the
  computed branch applies — `MED-04`.
- `setBondingCurveConfig` (`MultiVault.sol:825-828`) is a bare struct assignment with no validation — `MED-05`.
- 9 tracked test files under `tests/unit/security/v1.1.0/` and `tests/unit/upgrades/v1.1.0/` carry provenance markers —
  `MIN-12`.
- `src/` is byte-identical across the two pinned commits.

**Not independently re-verified** (taken on report authority, each backed by an executed PoC in its source report): the
numeric PoC outputs quoted throughout, the mutation-check results, the +221% realized-return figure and its
counterfactual, the 28/28, 122 and 11-test coverage measurements, and the `forge inspect` 38-field mirror comparison.

### Constraints honored

Local only; `src/` not modified as part of reviewing; CI / `.github/**` untouched; full-length `0x…` addresses;
addresses resolved from deploy manifests by name; issues described by mechanism.

### Publishing note

These reports name the model / skill / vendor for the team's own tracking. **If any of this is shared outside the team,
neutralize model / vendor / person names to method descriptors** (e.g. "parallel specialist-lens round" rather than a
tool author's name) and keep only the id-prefix provenance. This master is written to travel — professional prose,
id-prefix provenance, disclaimer — and is the file intended for external auditors if the team elects to share one.

### Disclaimer

This is a **pre-audit artifact** — an internal, first-party AI review run before the external audit. It is **not** a
formal audit, certification, warranty, or guarantee of safety, and does not replace the external engagement. Findings
stay internal until remediated.
