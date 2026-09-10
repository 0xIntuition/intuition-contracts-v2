# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 5 of 7 — 370-item checklist, per-contract multi-agent (one dedicated reviewer per contract)

> **How this report was produced:** checklist-driven skill review in per-contract multi-agent mode — ten independent
> reviewers, one per contract, each re-deriving from the shared scope brief with no sight of any other reviewer's output
> or of any prior round's findings; followed by a coordinator merge pass that de-duplicated by content, resolved
> severity disagreements, independently re-ran and in several cases refuted reviewer claims, and searched for
> cross-contract compositions no single reviewer could see. Verification performed: Foundry PoCs under
> `tests/unit/security/v1.1.0/`, guard mutation-checks (apply → confirm red → restore), `forge inspect storageLayout`
> diffing, and direct source verification of every finding reproduced below. Provenance ID prefix: `R2-CYF-`. One of 7
> independent round reports; consolidated view: [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

## Metadata

| Field                       | Value                                                                                                                                                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Artifact type**           | Internal AI pseudo-audit — **not** a formal audit, certification, warranty, or guarantee of safety                                                                                                                                    |
| **Target**                  | Intuition v1.1.0 core upgrade, public mirror `intuition-contracts-v2` (extending PR #153)                                                                                                                                             |
| **Reviewed commit**         | `ac567b2ecd03d12e3e27c0ce570381ef9e383196` (branch `feat/v1.1.0-core-upgrade`)                                                                                                                                                        |
| **Source-equivalence note** | The scope brief pinned `8579c5e02e6fd1b58620565d5a6d06d3b9391548`. `git diff 8579c5e..HEAD -- src/` is **empty** — the intervening commit touched only `package.json` — so the audited source is byte-identical to the pinned commit. |
| **Delta basis**             | `git diff b52557b..HEAD -- src/` = 30 files, +1537 / −875, none previously reviewed in its current form                                                                                                                               |
| **Target networks**         | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                                                                                                                                             |
| **Toolchain**               | Solidity `0.8.29`, Foundry `1.5.1`, TransparentUpgradeableProxy throughout                                                                                                                                                            |
| **Method**                  | 370-item checklist across 13 categories; ten per-contract reviewers + coordinator merge pass                                                                                                                                          |
| **Date**                    | 2026-07-27                                                                                                                                                                                                                            |

---

## 1. Executive summary

Ten independent per-contract reviewers walked the v1.1.0 in-scope set whole-contract — not diff-only — against six
load-bearing invariants, under a standing mandate to assume at least one fund-loss, mint/burn-imbalance, or
trust-boundary bug exists and to produce either a concrete exploit path or an evidenced reason none does.

**Headline result: no Critical and no Major finding. Two Mediums, both latent rather than live.** The core
value-movement properties held under sustained attack: quote-then-record fee equality is a dataflow guarantee rather
than a convention; `multicallPayable` value virtualization resisted every re-entrancy and nesting construction
attempted; flat-price par holds in both directions under 10,000-run fuzzing; and the emissions budget cap binds
end-to-end with a mutation-proven clamp.

**The single most important structural result is a cross-contract composition no individual reviewer could see.**
`MultiVault.setBondingCurveConfig` is one unvalidated, timelock-gated write that independently breaks **three** distinct
§5 invariants — the curve ledger mirror, value conservation on the create path, and flat-price par. Three different
reviewers each found one facet while explicitly reasoning that their facet was narrow; the setter itself performs no
validation of either field. This is documented as **R2-CYF-XC-01** and is the finding this review mode earned its cost
on.

**The round's largest single lead did not survive verification.** The curve reviewer's fuzzing initially indicated a
conservation break — obligations exceeding custody. Re-running its own proofs-of-concept showed the opposite sign: the
gap is monotonically negative and widening (`0 → −13 → −30 → −92 → −143` wei), i.e. custody exceeds obligations, which
is the accepted MasterChef dust direction. One companion test asserted the conclusion in its name while containing no
assertion at all. The reviewer confirmed the correction, deleted the misleading tests, and the residue was re-filed at
its true severity: a **1-wei transient** deficit that can revert a single `claim()` until the next fee credit
(R2-CYF-08). Recorded here because a refuted lead, honestly resolved, is a deliverable.

**One disposition-override attempt was made and it failed.** The `AtomWallet` reviewer filed a High-severity override
against round-1 **MA-01**, arguing that wallets claimed under v1.0.2 become permanently ownerless after the beacon
upgrade. The _mechanism_ is real and confirmed by a 7/7 PoC — the ownership root moved from the OZ `Ownable` namespace
to a new slot that no upgrade path writes, so `owner()` resolves to `address(0)` and every authority surface closes. The
_override_ does not hold. It rested on the precondition being creatable during the upgrade window; coordinator
verification of the deployed v1.0.2 claim path shows it is **self-only** — the atom's stored data must equal the
caller's own lowercased address (`v1.0.2:src/protocol/wallet/AtomWarden.sol:62-67`) — additionally requires the wallet
to be already deployed, and completes only after a second `acceptOwnership()` from the same party. Creating the
precondition therefore means a user bricking their own wallet, in two self-sent transactions, for no gain. There is no
third-party griefing path. Combined with the protocol team's on-chain census (no wallet has been claimed under the
current implementation; exactly one was ever deployed), **MA-01's disposition stands** and the finding is re-filed as
Informational (R2-CYF-32) with the mechanism preserved and a pre-flight assertion recommended.

**Both landed round-1 fixes verified with mutation-checks.** The ERC-1271 replay-safe digest binding and the zero
epoch-length rejection are each present, correctly placed, and non-vacuously tested. A notable secondary result on the
first: under a _permissive_ mutation — accept the envelope **or** the bare digest, the shape a "keep old signatures
working" refactor would take — **all 122 pre-existing wallet tests stay green**. Every existing test asserts that an
enveloped signature is accepted; none asserts that a bare digest is rejected. The fix is regression-covered against
deletion but not against permissive drift (R2-CYF-33).

### Findings by severity

| Severity          | Count                                  |
| ----------------- | -------------------------------------- |
| **Critical**      | 0                                      |
| **Major**         | 0                                      |
| **Medium**        | 2                                      |
| **Minor**         | 20                                     |
| **Informational** | 26                                     |
| **Total**         | **48** (+1 cross-contract composition) |

### Coverage caveat, stated up front

All ten reviewers returned a narrative subreport. Depth is uneven and the differences matter: the `MultiVaultLib` review
is **static-analysis only** — that reviewer never obtained a compiling test tree and ran no PoC and no mutation-check —
and four reviewers declared partial or absent checklist walks, so their findings carry no checklist item ids. At the
other end, the `AtomWarden`, `AtomWallet` and `FeeProxy` reviews were fully checklist-anchored with ten, two and five
mutation-checks respectively. §7 states exactly what was and was not covered. **This report should not be read as
complete coverage of the in-scope set.**

---

## 2. Scope

### In scope — reviewed at commit `ac567b2`

| Contract                                                            | Path                                                                                                                                                               | Reviewer | Subreport returned                                       |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------- |
| `DynamicFeeFlatPriceCurve` + interface                              | `src/protocol/curves/DynamicFeeFlatPriceCurve.sol`, `src/interfaces/IDynamicFeeFlatPriceCurve.sol`                                                                 | A1       | Yes                                                      |
| `IBaseCurve` / `BaseCurve` / `BondingCurveRegistry` / hook dispatch | `src/interfaces/IBaseCurve.sol`, `src/protocol/curves/BaseCurve.sol`, `src/protocol/curves/BondingCurveRegistry.sol`, `src/libraries/MultiVaultLib.sol` (dispatch) | A2       | Yes                                                      |
| `MultiVault`                                                        | `src/protocol/MultiVault.sol`                                                                                                                                      | A3       | Yes                                                      |
| `MultiVaultLib`                                                     | `src/libraries/MultiVaultLib.sol`                                                                                                                                  | A4       | Yes — **static analysis only, no PoC or mutation-check** |
| `MultiVaultCore` + `LinearCurve`                                    | `src/protocol/MultiVaultCore.sol`, `src/protocol/curves/LinearCurve.sol`                                                                                           | A5       | Yes                                                      |
| `AtomWarden`                                                        | `src/protocol/wallet/AtomWarden.sol`                                                                                                                               | A6       | **No — tests only**                                      |
| `AtomWallet` + factory + P-256 lib                                  | `src/protocol/wallet/AtomWallet.sol`, `src/protocol/wallet/AtomWalletFactory.sol`, `src/libraries/CoinbaseSmartWalletLib.sol`                                      | A7       | Yes                                                      |
| `TrustBonding`                                                      | `src/protocol/emissions/TrustBonding.sol`                                                                                                                          | A8       | Yes                                                      |
| `CoreEmissionsController` + `SatelliteEmissionsController`          | `src/protocol/emissions/CoreEmissionsController.sol`, `src/protocol/emissions/SatelliteEmissionsController.sol`                                                    | A9       | Yes                                                      |
| `FeeProxy`                                                          | `src/periphery/FeeProxy.sol`                                                                                                                                       | A10      | Yes                                                      |

### Explicitly out of scope

Not reviewed, and not filed as findings: the bridge router / MetaLayer cross-chain transport leg;
`BaseEmissionsController` and all Base-chain components; the deliberately parked TVL exit circuit-breaker / rate limiter
(its absence is a decision, not a gap); unbounded cross-curve counter-stake aggregation (rejected on principle);
`MultiVaultMigrationMode`; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow`; the `AtomWallet` delegation
framework (`executeFromExecutor`, held out of merge); whole-surface `multicallPayable` batching mixing payable and
non-payable legs (the current wall is the intended boundary — attacking the wall was in scope, requesting its removal
was not); Trust Swap and swap periphery; and `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib`
pricing math, in scope only insofar as they must conform to the new `IBaseCurve` hook defaults as safe no-ops.

**Trusted-admin centralization is an accepted trust assumption** — privileged actions are gated by a 4-of-8 Safe acting
through two `TimelockController`s (parameters 3-day, upgrades 7-day). Findings below distinguish throughout between "a
trusted admin can do X" and "an attacker can do X"; several Mediums and Minors are filed not as centralization
complaints but because a documented invariant is unenforced, or because the failure mode is silent and irreversible
rather than a revert.

---

## 3. Severity classification

Impact × Likelihood, using the labels the existing professional reports in `audits/` use.

|                    | **Likelihood: High** | **Likelihood: Medium** | **Likelihood: Low** |
| ------------------ | -------------------- | ---------------------- | ------------------- |
| **Impact: High**   | Critical             | Critical               | Major               |
| **Impact: Medium** | Major                | Medium                 | Minor               |
| **Impact: Low**    | Medium               | Minor                  | Informational       |

- **Critical** — permissionless or realistically reachable path to direct theft, permanent loss, insolvency,
  unrestricted mint/withdraw, or capture of upgrade/admin control.
- **Major** — a core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path
  corrupts critical state.
- **Medium** — bounded loss, temporary stuck funds, realistic griefing/DoS of a funds path, admin footgun with a silent
  or irreversible failure mode, or a spec regression materially affecting users or operators.
- **Minor** — limited impact, weak validation blocked by another guard, confusing behavior, monitoring or integration
  weakness.
- **Informational** — documentation, hygiene, NatSpec-versus-behavior mismatch, missing non-critical test coverage.

---

## 4. Cross-contract composition

This section exists because the per-contract mode produced something the individual reviews structurally could not.

### R2-CYF-XC-01 — `setBondingCurveConfig` is one unvalidated write that independently breaks three §5 invariants — Medium

**Description.** `MultiVault.setBondingCurveConfig` assigns the whole `BondingCurveConfig` struct with **zero
validation**: it does not pin `registry` (which its own interface NatSpec declares "must not be changed after
initialization"), does not reject `address(0)` for either field, and does not check that `defaultCurveId` resolves to a
registered curve. Three reviewers, each seeing only their own contract, independently found a _different_ invariant that
this single write breaks:

1. **§5.3 — curve ledger mirrors vault shares.** The creation paths never dispatch the curve fee hook. If
   `defaultCurveId` points at a curve that keeps a ledger, every position minted through `createAtoms` / `createTriples`
   / `createAtomsFor` / `createTriplesFor` is recorded in the vault but not in the curve, and becomes **permanently
   unredeemable**. (Reviewer A2 — reproduced below as R2-CYF-01.)
2. **§5.1 / §5.2 — conservation and solvency.** `_getAtomCost` / `_getTripleCost` price the ghost-share seed at the raw
   `minShare` _share_ quantity, while the create path funds the vault with `_minAssetsForCurve(curveId, minShare)`
   _assets_. The two are equal only for a curve minting 1:1 from an empty domain. Repointing produces either
   under-collateralisation or permanently stranded value — **silently, with no revert and no event**. (Reviewer A5,
   independently noted as a latent coupling by A3 — reproduced as R2-CYF-05.)
3. **§5.4 — flat-price par.** Every asset-only credit (`entryFee`, `exitFee`, the triple atom-deposit fraction) routes
   through helpers that hard-read `defaultCurveId`. If that pointed at the flat-price curve, assets would be credited
   with no matching shares, driving `totalAssets > totalShares`, breaking par — and simultaneously desyncing §5.3, since
   the curve's ledger counts shares while the vault would hold more assets. (Reviewer A5.)

**Why the merge pass matters here.** A2 rated its facet Medium while explicitly noting it could not reach the state
permissionlessly. A5 rated its facet Low for the same reason. Each was locally correct. What neither could see is that
**all three facets share one trigger**, that the trigger has no validation whatsoever, and that two of the three failure
modes are silent rather than reverting. Considered together the setter is a single point at which three independent
load-bearing invariants can be broken in one transaction.

**Code.** `src/protocol/MultiVault.sol:825-828` (the setter, no validation); `src/interfaces/IMultiVaultCore.sol:70-71`
(the immutability claim it does not enforce); `src/libraries/MultiVaultLib.sol:771` (the sole `_recordCurveDeposit` call
site, on the deposit path only); `src/protocol/MultiVaultCore.sol:341-349` (`_getAtomCost` / `_getTripleCost`);
`src/libraries/MultiVaultLib.sol:1086-1091` (pro-rata credit hard-reading `defaultCurveId`).

**Coordinator verification.** Independently confirmed by direct source inspection: `_recordCurveDeposit` has exactly one
call site in the entire library, inside `_processDeposit`; both `_createAtom` (`:547`) and `_createTriple` (`:629`) mint
via `_updateVaultOnCreation` without ever dispatching the hook. `src/interfaces/IBaseCurve.sol:148-152` states the
opposite in terms — that on a hook curve `recordDeposit` "is ALWAYS called, even when the quoted fee is zero, so the
curve ledger stays in lockstep with vault shares." The deployed configuration is `defaultCurveId: 1` (`LinearCurve`,
hookless, 1:1), so **none of the three facets is live today**; all three are gated on one governance write.

**Recommendation.** Make the setter enforce what the system already assumes. Minimally, in `setBondingCurveConfig`:
reject a changed `registry` (or correct the NatSpec), reject `address(0)` on both fields, require
`registry.curveAddresses(defaultCurveId) != address(0)`, require
`registry.previewMint(minShare, 0, 0, defaultCurveId) == minShare`, and reject a `defaultCurveId` whose
`hasDepositFeeHook()` or `hasRedeemFeeHook()` is true. Re-validate the seed identity in `setGeneralConfig` when
`minShare` changes. Structurally better for facet 2: derive `_getAtomCost` / `_getTripleCost` from
`_minAssetsForCurve(defaultCurveId, minShare)` so the advertised cost and the funded credit are the same expression and
the invariant disappears rather than being asserted.

**Status.** Open. Not live under the deployed configuration.

---

## 5. Findings

### 5.1 Medium

---

### R2-CYF-01 — Creation paths bypass the curve fee-hook dispatch entirely — Medium

**Reviewer:** A2 (cluster C2). **Invariant broken:** §5.3 (curve ledger mirrors vault shares); secondarily §5.2.

**Description.** `MultiVault` resolves and dispatches the standardized `IBaseCurve` fee hooks on the deposit and redeem
paths only. The four creation entry points mint shares without ever resolving `_depositFeeHookCurve` or calling
`_recordCurveDeposit`. On a curve that maintains a per-user ledger, the vault and the curve therefore disagree from the
moment of creation, and the disagreement is not self-healing: a later deposit credits the ledger only for the deposited
amount, so redeeming the full vault balance still underflows.

The interface documents the opposite. `src/interfaces/IBaseCurve.sol:148-152` states that on a hook curve
`recordDeposit` "is ALWAYS called, even when the quoted fee is zero, so the curve ledger stays in lockstep with vault
shares."

**Code.**

```
src/libraries/MultiVaultLib.sol:771   _recordCurveDeposit(termId, receiver, hook, sharesForReceiver);   // the ONLY call site
src/libraries/MultiVaultLib.sol:547   function _createAtom(...)      → _updateVaultOnCreation, no hook dispatch
src/libraries/MultiVaultLib.sol:629   function _createTriple(...)    → _updateVaultOnCreation, no hook dispatch
src/protocol/curves/DynamicFeeFlatPriceCurve.sol:415-416              // the debit that underflows
src/interfaces/IBaseCurve.sol:148-152                                 // the contract this violates
```

**Proof of concept.** Reviewer PoC `tests/unit/security/v1.1.0/CurveHookDispatchCompleteness.t.sol`, 7 tests passing:

1. `setBondingCurveConfig({registry, defaultCurveId: 4})` as the timelock — accepted, no validation.
2. `createAtoms{value: atomCost + 10e18}` as alice. The vault mints alice a share balance on curve 4;
   `address(dynamicFeeCurve).balance` is unchanged; `dynamicFeeCurve.userStake(atomId, alice) == 0`;
   `dynamicFeeCurve.vaultAssets(atomId) == 0`.
3. `previewRedeem` still quotes a nonzero payout — the read path cannot see the missing ledger entry.
4. `redeem(alice, atomId, 4, shares/2, 0)` reverts `Panic(0x11)` at `userStake[termId][account] -= withdrawnStake`.
   `redeem(..., 1, 0)` reverts identically: **every** redeem size, not merely large ones.
5. A later 5e18 deposit credits the ledger only for the deposited amount, so the full balance still panics — the desync
   does not self-heal.

**Coordinator verification.** Confirmed independently by source inspection (see R2-CYF-XC-01). `_recordCurveDeposit` has
exactly one call site; both creation paths mint without it.

**Reachability.** Not permissionless. Requires the timelocked `setBondingCurveConfig` write. Filed at Medium — not as a
centralization complaint, which is out of scope — because the dispatch is _incomplete_, the interface documents the
opposite, and the failure mode is permanent fund-stranding with no contract-level repair path rather than a revert at
configuration time. The reviewer attempted to reach the state permissionlessly and could not: every `_mint` call site
reaching a real user is either covered by `_processDeposit` or hard-wired to `defaultCurveId`, shares are
non-transferable, and the only uncovered mint is to `BURN_ADDRESS`.

**Recommendation.** Either (a) dispatch the hook from the create paths — resolve `_depositFeeHookCurve(defaultCurveId)`
in `_calculateAtomCreate` / `_calculateTripleCreate` and call `_recordCurveDeposit` from `_createAtom` /
`_createTriple`, which is what the interface already promises; or (b) if creates are deliberately hook-free, enforce it
— have `setBondingCurveConfig` reject a `defaultCurveId` advertising either hook, and correct the `IBaseCurve` NatSpec.
(a) is the safer direction; (b) is cheaper.

**Regression test.** `CurveHookDispatchCompleteness.t.sol::test_creation_unrecordedPosition_isPermanentlyUnredeemable`.

**Variant sweep.** single deposit — safe · batch deposit — safe · on-behalf creates — same bug · preview — worse than
the bug (quotes a payout for an unredeemable position) · router (FeeProxy) — same bug, it composes creates ·
upgrade-initializer — n/a.

**Status.** Open. Not live under `defaultCurveId: 1`.

---

### R2-CYF-02 — Upgrade-epoch utilization carry is seeded from a possibly-zero slot, and the pre-`reinitialize` window is permissionless — Medium

**Reviewer:** A3 (cluster A). **Invariant broken:** none of §5 directly — a one-epoch mis-statement of the
system-utilization ledger that `TrustBonding` converts into an emissions multiplier.

**Description.** `MultiVault.reinitialize` pre-seeds `lastSystemUtilizationEpoch = _currentEpoch()` so the first
post-upgrade `_rollover` reads a meaningful source epoch. Two problems follow.

_(a) Cold-epoch seed._ If the upgrade epoch has seen no MultiVault activity when `reinitialize` runs, the seeded epoch's
`totalUtilization` is zero, so `_rollover`'s `sourceUtilization != 0` guard fails and the standing utilization carry is
**dropped**, not carried.

_(b) Permissionless window._ The deploy script explicitly requires the reinitializers to run as separate transactions,
never embedded in `upgradeAndCall`. In the window between the implementation swap and `reinitialize`,
`lastSystemUtilizationEpoch` is still `0`, so any caller can trigger a rollover that carries `totalUtilization[0]` into
the current epoch and consumes the once-per-epoch flag. `reinitialize` re-seeds the epoch pointer but **cannot undo the
consumed flag**, so the epoch's base is fixed at the attacker-chosen source.

**Code.**

```
src/protocol/MultiVault.sol:294-305        reinitialize — :304 lastSystemUtilizationEpoch = _currentEpoch();
src/libraries/MultiVaultLib.sol:1145-1157  _rollover — the once-per-epoch flag and the sourceUtilization != 0 guard
src/protocol/emissions/TrustBonding.sol:645-682, :563-564   the consumer that converts this into emissions
script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:113-122   "must run as SEPARATE transactions"
```

**Coordinator verification.** Both cited mechanisms confirmed by source inspection: `reinitialize` writes only
`lastSystemUtilizationEpoch` and never touches `hasRolledOverSystemUtilization`; `_rollover` sets the flag before the
carry and gates the carry on `sourceUtilization != 0`.

**Proof of concept.** Reviewer PoC `tests/unit/security/v1.1.0/UpgradeEpochUtilizationSeed.t.sol`, 3 tests. Branch (a):
with `totalUtilization[20] = 5_000_000e18` and epoch 21 cold, after `reinitialize` the first activity yields
`totalUtilization[21] == 1e18` — the standing carry is gone. Control: if epoch 21 was already warm the carry survives at
`5_000_000e18 + 1e18`, which is the boundary deciding whether the bug fires. Branch (b): an unprivileged call in the
window carries `totalUtilization[0]` and pins the epoch base at `7e18 + 1`, surviving the admin's later `reinitialize`.

**Impact.** `TrustBonding._getSystemUtilizationRatio` computes a delta against the previous epoch; a dropped carry makes
it strongly negative, returning `systemUtilizationLowerBound` and flooring the upgrade epoch's entire emissions budget.
Everyone bonding through that epoch is underpaid. Self-heals from the following epoch. In branch (b) the direction
depends on the live value of `totalUtilization[0]` on mainnet — if large, the effect is _inflation_ rather than
flooring. The reviewer could not read mainnet state, which is why confidence is Medium rather than High.

**Recommendation.** Cheapest: gate the upgrade runbook on `hasRolledOverSystemUtilization[currentEpoch] == true` — warm
the epoch with any activity before `upgradeAndCall`. Nothing enforces this today and it is not written down. Stronger:
have `reinitialize` take the source epoch as an explicit argument rather than inferring it, or have `_rollover` fall
back through a lookback when `totalUtilization[sourceEpoch] == 0`.

**Regression test.** `UpgradeEpochUtilizationSeed.t.sol::test_reinitializeInQuietEpochDropsStandingUtilizationCarry` and
`::test_unprivilegedCallerInReinitializeWindowSeedsCarryFromGenesisEpoch`.

**Variant sweep.** single / batch / on-behalf / router — same bug (any utilization-touching call triggers it) · preview
— n/a · upgrade-initializer — this _is_ the upgrade-initializer variant.

**Triage note.** The reviewer flagged adjacency to round-1 MED-03 (carry-forward deliberate, bounded, capped) and
INFO-02 (fixed non-sliding window) and filed anyway, on the basis that those describe steady-state carry semantics while
this concerns the seed value chosen at the upgrade boundary and the window before it is chosen —
`lastSystemUtilizationEpoch` being a new v1.1.0 slot. The coordinator concurs that this is new surface, and flags the
adjacency for triage rather than asserting it is not a duplicate.

**Status.** Open.

---

### 5.2 Minor

---

### R2-CYF-03 — Combined MultiVault + curve fee ceiling is validated by neither side — Minor

**Reviewers:** A2 and A1, independently. **Invariant broken:** §5.2 in its liveness sense; §5.4.

**Description.** The curve validates its own fee caps against `BPS` only; `MultiVault.setVaultFees` performs **no bounds
check at all**. The netting sites subtract all fees from the gross, so a schedule each side accepts as individually
valid can jointly underflow and brick the path. Sharper than it first appears: the naive ceiling a reviewer would derive
(`BPS − protocolFeeBps − exitFeeBps`) **also** underflows, because `protocolFee`, `exitFee`, and the curve quote each
round _up_ independently.

**Code.**

```
src/libraries/MultiVaultLib.sol:1067   assets - protocolFee - exitFee - hook.fee     // redeem netting
src/libraries/MultiVaultLib.sol:962, :1024   assetsAfterFees -= hook.fee              // deposit netting
src/protocol/curves/DynamicFeeFlatPriceCurve.sol:891-896   caps checked against BPS only
src/protocol/MultiVault.sol:819-822    setVaultFees — no validation whatsoever
src/protocol/curves/DynamicFeeFlatPriceCurve.sol:257-259   NatSpec naming this exact failure mode
```

**Proof of concept.** Reviewer PoC in `CurveHookDispatchCompleteness.t.sol`: with
`withdrawalBaseBps = withdrawalCapBps = 9900` accepted by `_setConfig`, `redeem` reverts `Panic(0x11)` and
`previewRedeem` reverts identically, so an integrator cannot even discover the payout. Deposit mirror at
`depositBaseBps = depositCapBps = 9900` reverts likewise. At 9800 — the naive ceiling — it still underflows; only 9700
settles.

**Impact.** Bounded and reversible by a timelocked retune, no value lost, but every redeem and preview on the curve is
down while it lasts, including for positions opened before the retune. The curve NatSpec anticipates the case; the guard
it points to is insufficient for it.

**Recommendation.** Validate where the two are composed. Clamp rather than subtract —
`hook.fee = min(quoted, assetsRemainingAfterMultiVaultFees)` — or add an explicit `MultiVault_CurveFeeExceedsNet()`
error so the failure is legible rather than a bare panic. Document the real ceiling on both setters.

**Regression test.**
`CurveHookDispatchCompleteness.t.sol::test_combinedRedeemFeeCeiling_naiveBoundaryAlreadyUnderflows`.

**Status.** Open.

---

### R2-CYF-04 — `multicallPayable` value integrity rests solely on `nonReentrant`; transient state is hard-cleared rather than restored — Minor

**Reviewers:** A2, A3, and A10 — **three independent corroborations**, each with its own mutation-check. **Invariant:**
§5.6 — defended today.

**Description.** `_effectiveMsgValue()` returns the live per-leg allocation to _any_ frame reaching an allowlisted
payable entry point while `_inMulticall` is set, with no check that the frame is actually a leg. Safety is an emergent
consequence of two facts held elsewhere: all six allowlisted entry points carry `nonReentrant`, and no
attacker-controlled address is reachable from inside a value-bearing leg. The multicall code neither asserts nor would
notice losing either. Compounding this, both multicalls **hard-clear** `_inMulticall` on exit rather than saving and
restoring it, so a nested batch that completed would demote an outer batch's context.

The v1.1.0 upgrade newly places an external, non-view, value-bearing call — the curve record hook — inside that window,
so the re-entry point that would exercise the failure now exists where it did not before.

**Code.**

```
src/protocol/MultiVault.sol:639-641   _effectiveMsgValue — no frame check
src/protocol/MultiVault.sol:614, :631-632   _inMulticall set true, hard-cleared on exit
src/protocol/MultiVault.sol:516, :535       same shape in canonical multicall
src/protocol/MultiVault.sol:592             the nested-multicall guard
src/libraries/MultiVaultLib.sol:851-865     the record hooks — the only non-view external calls on the path
```

**Proof of concept — mutation evidence from three reviewers.**

- **A3:** removing `nonReentrant` from `MultiVault.deposit:702` turns
  `MulticallValueVirtualizationBoundary.t.sol::test_recordHookReentrantDepositCannotClaimLiveVirtualValue` red, with the
  `-vvvv` trace showing a re-entrant frame that sent **1 wei** being handed `payment = 4000000000000000000` — the outer
  leg's whole allocation.
- **A2:** removing the nested-multicall guard at `:592` lets an inner _empty_ `multicallPayable` succeed and clear
  `_inMulticall`; leg 1 then reads raw `msg.value`, producing **11.4e18 of internal credit against 9e18 received** — a
  2.4e18 phantom credit.
- **A10:** removing `nonReentrant` from `deposit` flips the rejection selector from `ReentrancyGuardReentrantCall()`
  (`0x3ee5aeb5`) to `MultiVault_DepositBelowMinimumDeposit()` (`0xe219a6cd`), with gas moving 1,377,702 → 1,423,480
  confirming the mutant compiled and ran — i.e. with the guard gone, re-entrancy is no longer what stops the nested
  deposit; only the value-dependent minimum-deposit floor is, and the PoC merely happened to send 1 wei.

**Coordinator note.** This matches the coordinator's own independent read of the `_virtualMsgValue` re-entry path. All
six allowlisted entry points were verified to carry `whenNotPaused nonReentrant`: `createAtoms:653-658`,
`createTriples:664-669`, `createAtomsFor:674-679`, `createTriplesFor:685-691`, `deposit:698-703`,
`depositBatch:709-715`. **None lacks the modifier.** The property holds; the finding is that it holds for reasons stated
nowhere near the code that depends on them.

**Recommendation.** Make the property local rather than emergent. Save and restore `_inMulticall` / `_virtualMsgValue`
rather than hard-clearing, so a re-entrant batch cannot demote an outer one. Better still, write a transient depth/nonce
immediately before each `delegatecall` and clear it after, so a re-entrant frame reads a stale token and falls back to
raw `msg.value`. At minimum, a comment at `:639` naming `nonReentrant` on all six entry points as a load-bearing
precondition of the allowlist, so an allowlist edit cannot silently drop it.

**Regression test.**
`MulticallValueVirtualizationBoundary.t.sol::test_recordHookReentrantDepositCannotClaimLiveVirtualValue` — green today,
red the moment `nonReentrant` leaves `deposit`.

**Status.** Open (hardening; not currently exploitable).

---

### R2-CYF-05 — Static creation cost prices the ghost-share seed at `minShare`, decoupled from the default curve's mint quote — Minor

**Reviewers:** A5 (primary, with PoC); A3 independently flagged the same coupling. **Invariant broken:** §5.1, §5.2.

**Description.** `_getAtomCost()` returns `atomCreationProtocolFee + generalConfig.minShare`, treating `minShare` — a
_share_ quantity — as the _asset_ cost of seeding the ghost position. The create path funds the seed differently:
`_updateVaultOnCreation` credits `_minAssetsForCurve(curveId, minShare)` assets. The two agree only for a curve minting
1:1 from an empty domain. `_getTripleCost` has the same shape doubled. The deposit path is self-consistent for any curve
— it computes the seed cost from the same quote it later credits — so the asymmetry is confined to creation.

**Code.**

```
src/protocol/MultiVaultCore.sol:341-343, :347-349   _getAtomCost / _getTripleCost  (raw minShare)
src/libraries/MultiVaultLib.sol:916, :971            consumed by the create calcs
src/libraries/MultiVaultLib.sol:1434-1436            _minAssetsForCurve  (the actual quote)
src/libraries/MultiVaultLib.sol:1187, :1250          consumed by the create credits
src/protocol/curves/LinearCurve.sol:99               why the equality holds today
```

**Proof of concept.** `tests/unit/security/v1.1.0/DefaultCurveMinShareCoupling.t.sol`, 4/4 passing. Measured
empty-domain seed quotes `previewMint(1e6, 0, 0, id)`: curve 1 (`LinearCurve`) `1000000` = `minShare`; curve 2
(`OffsetProgressiveCurve`) `1000001`; curve 3 (`ProgressiveCurve`) `1`; curve 4 (`DynamicFeeFlatPriceCurve`) `1000000`.
After repointing `defaultCurveId` to 2, `getAtomCost()` is unchanged and a create yields the exact identity
`booked − received == previewMint(minShare,0,0,2) − minShare == 1` — the vault credits its own `totalAssets` 1 wei more
than the contract ever received.

**Impact.** Direction-dependent. Quote > `minShare`: under-collateralisation per term, a genuine
`sum(vault.totalAssets) > custody` break scaling with curve steepness. Quote < `minShare` (curve 3): the creator is
charged `minShare` but only 1 wei reaches the vault — **999,999 wei per term stranded**, not in any vault's totals, not
in `accumulatedProtocolFees` (so the sweep cannot reach it), with no code path that can ever release it.

**Corroborating mutation.** A5 changed `LinearCurve.previewMint`'s zero-supply branch from `shares` to `shares + 1`;
`test_flatPricePar_dynamicFeeVaultStaysAtPar_acrossDepositAndRedeem` went red immediately, confirming the par tests are
genuinely sensitive to the seed-quote identity and independently corroborating this finding.

**Recommendation.** Derive `_getAtomCost` / `_getTripleCost` from `_minAssetsForCurve(defaultCurveId, minShare)` so the
advertised cost and the funded credit are the same expression — this removes the invariant rather than asserting it.
Failing that, validate the equality in `setBondingCurveConfig` and re-validate in `setGeneralConfig`.

**Regression test.** `DefaultCurveMinShareCoupling.t.sol::test_defaultCurve_pricesMinShareSeedAtExactlyMinShare` and
`::test_atomCreate_conservationGapEqualsSeedMispricing_afterDefaultCurveRepoint`.

**Status.** Open. Not live under `defaultCurveId: 1`. See R2-CYF-XC-01.

---

### R2-CYF-06 — A credited fee slice whose per-share delta truncates to zero is marked assigned and never reaches `protocolAccrued` — Minor

**Reviewer:** A1. **Invariant broken:** §5.1 — "a distributed fee always has a defined home … and is never lost".

**Description.** In `_creditByWeight`, `assigned += share` executes whenever `share > 0`, even when the accumulator
delta `share.fullMulDiv(ACC_PRECISION, stakes[d-1])` floors to zero. The slice is counted as distributed but no holder
can ever claim it, and because it is counted, it never falls into `unassigned` and never reaches `protocolAccrued`. The
sibling `share == 0` case _does_ fall through and _is_ routed to the protocol — **the same condition produces two
different outcomes**.

**Code.**

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:644-656
uint256 share = pool.mulDiv(w, sumWeights);
if (share > 0) {
    accFeePerShare[termId][span - d] += share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
    assigned += share;          // counted as assigned even when the delta floored to 0
}
```

**Proof of concept.** `CurveFeeAccumulatorConservation.t.sol::test_creditWhosePerShareDeltaTruncatesToZeroIsStranded`,
passing. With `width0 = 1e30, g = 0`, alice staking `5e29` in tier 0 and bob `1e30`, a deposit with fee `499999999999`
wei (below `whaleStake/ACC_PRECISION`) leaves `accFeePerShare[T1][0]` unchanged, `protocolAccrued` unchanged, and
total-owed delta zero — the whole `499999999999` wei stranded with no home.

**Impact.** Per-event bound is `stake / ACC_PRECISION`, so magnitude is dust-class; with `minDeposit = 1e16` and
realistic tier stakes the per-event loss is sub-gwei. Filed as Minor rather than dismissed because the routing is
**asymmetric and inconsistent** with the adjacent path, and because it applies at all four credit sites.

**Recommendation.**

```solidity
uint256 delta = share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
if (delta > 0) { accFeePerShare[termId][span - d] += delta; assigned += share; }
```

so a zero-delta slice falls into `unassigned` and reaches `protocolAccrued` like the `share == 0` path already does.

**Variant sweep.** `_creditByWeight` — same bug · `_awardNearestOrProtocol` (`:714`) — same shape · `_payDepositFee`
spike (`:563`) — same shape · `recordRedeem` diamond slice (`:427`, `:436`) — same shape. **All four credit sites share
it.**

**Status.** Open.

---

### R2-CYF-07 — Vault retreat to tier 0 routes 100% of the deposit fee to the protocol despite occupied tiers — Minor

**Reviewer:** A1. **Invariant:** none broken — the fee has a home; this is an economics/spec deviation.

**Description.** `_payRecentTiers` short-circuits to `protocolAccrued` whenever `span == 0`, i.e. whenever the vault's
current tier is 0. But buckets are `round(avgEntryTier)`, not a function of current stake, so holders can remain
bucketed at high tiers with non-zero `tierStake` while `vaultAssets` has fallen back inside `edge(0)`. In that state the
entire deposit fee is captured by the protocol rather than redistributed, with no event distinguishing it from the
genuine "no holders at all" case. The redeem path handles structurally the same condition correctly, via
`_nearestOccupiedTier`.

**Code.**

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:604-610
uint256 span = tier;
if (span == 0) { protocolAccrued += pool; emit ProtocolAccruedIncreased(pool); return; }
```

Contrast `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:434-440` (redeem's whale-exit fallback).

**Proof of concept.** `test_vaultRetreatToTierZeroSendsWholeFeeToProtocol`, passing. Three holders grow the vault into
tier 3, then all redeem down to `1e15`-wei residuals so `vaultAssets` falls inside `edge(0)` while two remain bucketed
high. A subsequent deposit with a `1e18` fee sends `protocolAccrued` up by exactly `1e18`; the two holders' `claimable`
is unchanged. The ledger mirror still holds.

**Refutation attempted.** The reviewer checked whether `sum(tierStake) == vaultAssets` forces all stake into tier 0 when
`vaultAssets < edge(0)`. It does not — buckets are entry-tier-derived, so a holder can be bucketed at tier 5 while
holding 1e15 wei. Confirmed by the passing PoC.

**Impact.** Recoverable by the owner via `sweepProtocol`, so no loss to the protocol — but it silently reverses the
stated redistribution economics for any retreated vault.

**Recommendation.** Fall through to `_awardNearestOrProtocol` (or `_nearestOccupiedTier`, which the redeem path already
uses for this case) before defaulting to `protocolAccrued`. The asymmetry between the two paths appears unintentional.

**Status.** Open.

---

### R2-CYF-08 — Transient obligation deficit can revert a `claim()` on insufficient custody — Minor

**Reviewer:** A1, after coordinator correction. **Invariant:** §5.1 / §5.2, transiently only.

**Description.** `rewardDebt` is floored at every re-base while per-holder accrual is also floored. Each re-base at a
non-zero accumulator forgives the discarded fractional debt, so a holder can be credited up to **+1 wei** beyond what
the accumulator delta justifies. The offsetting per-credit surplus is `(C·1e18 mod D)/1e18`; when a recipient tier's
aggregate stake `D` is below `1e18` wei that surplus is sub-wei and cannot offset even one holder's +1. Such tiers are
ordinary — early holders bucket into tier 0 and later redeem down to residuals, and redeem has no residual floor.

**This is the round's most important negative result and is reported as such.** The reviewer's initial claim was a
durable conservation break. The coordinator re-ran its proofs and found the opposite sign; the reviewer confirmed and
corrected. See §6.1 for the full record.

**Code.** `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:530-538` (`_settle`), `:389` (deposit re-base), `:448`
(redeem re-base), `:636-657` (`_creditByWeight`), `:459-476` (`claim`).

**Proof of concept.** Foundry fuzz `testFuzz_ledgerAndConservationHold` failed at run 7901 with
`423469742731081637 > 423469742731081636` — owed exceeding fees received by 1 wei. Replaying that counterexample and
stopping at the violating step reproduced `owed − custody = +1` and a real claim revert:

```
claim ok: 123077722943990591
claim REVERTED for actor index: 2
  amount owed:   300392019787091046
  curve balance: 300392019787091045
```

**Impact.** One claimant's `claim()` reverts **entirely** — `Address.sendValue` fails, so they receive nothing rather
than being underpaid — until the next fee credit restores custody. 1 wei of over-obligation; no theft, no principal at
risk; self-healing.

**Scope of the claim, stated precisely.** In steady state the direction is surplus (§6.1). The reviewer attempted and
**failed** to show this compounds into a durable solvency break, which is the escape hatch the scope brief provides for
otherwise-accepted MasterChef dust. The durable-break case is **unproven and not claimed**.

**Recommendation.** Either clamp the payout in `claim` to `min(earned, address(this).balance)` and carry the remainder,
or round `rewardDebt` **up** on re-base (`fullMulDivUp` at `:389`, `:448`, `:537`) so debt is never under-recorded and
the surplus direction becomes unconditional. The latter is the smaller change and restores the invariant as a hard
property.

**Regression test.** `CurveFeeAccumulatorConservation.t.sol::testFuzz_ledgerAndConservationHold` — **currently red by
design**; it is the gating test.

**Status.** Open.

---

### R2-CYF-09 — Affiliate can nominate the proxy itself as `feeRecipient`, permanently stranding every fee it routes — Minor

**Reviewer:** A10. **Invariant broken:** §5.1.

**Description.** `registerAffiliate` and `updateFeeRecipient` validate only `feeRecipient != address(0)`. Nominating the
proxy itself is accepted; `_payAffiliate` then self-sends, and `receive()` accepts it via a
`msg.sender == address(this)` carve-out. The value lands with no ledger entry and no exit — the contract exposes no
sweep, no rescue, and is not `selfdestruct`-able. The refund axis has exactly this guard already: `claimRefundTo`
explicitly refuses `address(this)`.

**Code.** `src/periphery/FeeProxy.sol:508-512` (`receive()` carve-out), `:175` and `:243-247` (only zero-address
rejected), `:702-709` (`_payAffiliate`), `:397-403` (the asymmetric counter-example).

**Proof of concept.** `FeeProxyCurveHookComposition.t.sol::test_feeRecipientSetToProxy_strandsFeesWithNoLedgerEntry`,
passing. After registering with `feeRecipient = address(feeProxy)` and routing a 4-ether deposit,
`address(feeProxy).balance == 0.041 ether` while every relevant `pendingRefund` is zero and `claimRefund()` reverts
`FeeProxy_NoRefundOwed()`.

**Impact.** Permanent irreversible loss of every affiliate fee routed through the misconfigured row. Bounded to that
affiliate's take; no user principal at risk; no cross-user contamination. Permissionless but **self**-inflicted — no
attacker can impose it on a third party. Rated Minor for that reason despite the permanence.

**Recommendation.** Reject `recipient == address(this)` in both setters — the guard already present at `:401` for the
refund axis, applied to the fee axis. Consider also removing the `msg.sender == address(this)` branch from `receive()`;
with `claimRefundTo` already refusing self-sends it has no legitimate producer and only converts a would-be revert into
silent stranding.

**Status.** Open.

---

### R2-CYF-10 — Flat fixed fee is charged once per batch rather than once per leg, contradicting the interface spec — Minor

**Reviewer:** A10. **Invariant:** none — value is conserved exactly; this is spec-versus-behavior divergence.

**Description.** `_setupRoutingFlow` calls `_calcFee` once on the aggregate, so an N-leg batch pays `1×fixedFee` where
`src/interfaces/IFeeProxy.sol:598-600` states the batch "behaves like `{depositVia}` applied across `termIds`" — which
implies `N×`.

**Code.** `src/periphery/FeeProxy.sol:548-551` versus `:278`; spec at `src/interfaces/IFeeProxy.sol:598-600`.

**Proof of concept.** `test_depositBatchVia_fixedFeeIsChargedOncePerBatchNotPerLeg`, passing on both the equality and
the strict inequality: a 2-leg batch pays `0.101 ether`, strictly under the `0.102 ether` two separate calls would pay.

**Impact.** Affiliate revenue leaks linearly in batch size; `MAX_BATCH_SIZE = 150` bounds the worst case at a 150×
discount on the fixed component. Rational users always batch. The loser is the affiliate, and the divergence is
invisible because the interface documents the opposite. The preview surface diverges in the _same_ direction —
`previewDepositFee` takes a scalar gross, so an integrator summing per-leg previews gets `N×` while execution charges
`1×`.

**Recommendation.** Decide and align: either charge per leg (`_calcFee(totalGross, bps, fixedFee * assets.length)`,
keeping the `fee >= totalGross` guard) or keep aggregate semantics and correct the NatSpec. The latter is cheaper and
arguably the better product behaviour — the defect is the documentation, not the math. This needs a product decision,
not just an edit.

**Status.** Open.

---

### R2-CYF-11 — Personal-utilization target conflates "could not claim" with "chose not to claim" — Minor

**Reviewer:** A8. **Invariant:** none — the loss is a forfeit, not a mis-credit; a reward-accounting fairness defect.

**Description.** The personal-utilization target is read as the previous epoch's _claimed_ amount. When that is zero,
the code distinguishes only "was ineligible" (→ 100%) from "was eligible and did not claim" (→ floor). A holder who was
_blocked_ — by the emergency pause gate on `claimRewards`, or by losing the budget race to `EpochBudgetExhausted` —
lands in the second bucket and is penalised as though they had declined.

**Code.** `src/protocol/emissions/TrustBonding.sol:622-632` (target read and the two zero-target branches), `:413-415`
(the ledger entry doubling as the target), `:380` (`whenNotPaused` on `claimRewards`), `:420-422`
(`EpochBudgetExhausted`).

**Proof of concept.** `BondingPauseSurface.t.sol::test_pauseSpanningClaimWindow_alsoFloorsTheFollowingEpochRatio` and
`::test_budgetExhaustedClaimant_isFlooredForTheFollowingEpoch`, both passing. With identical utilization movement, the
holder who claimed reads `10000` bps while the holder blocked by the pause reads `3000` — the configured floor.

**Impact.** A pause covering one claim window costs a holder that epoch's reward **plus** up to 75% of the following
epoch's (100% → the 25% hardcoded minimum; 100% → 30% in the tested configuration). Forfeits route to the unclaimed
ledger and are reclaimed or burned — no theft, no over-emission, bounded to one extra epoch. The penalty does not
compound: the floored claim writes a non-zero target, so the third epoch is governed normally.

**Relation to round-1 MED-04.** The reviewer deliberately did **not** re-file MED-04: that disposition's bound (rewards
forfeited _during_ a pause) is real and holds. This is the distinct, undocumented **follow-on** epoch, and it also fires
with no pause at all.

**Recommendation.** Separate the "has claimed" flag from the "utilization target" — record an explicit `hasClaimed` bit
and let the target fall back to the _eligible_ rather than the _claimed_ amount, or treat a holder whose window was
closed by pause or exhaustion the same as a never-eligible holder.

**Severity note.** The reviewer rated this Low and flagged that if a pause spanning a claim window is considered a
realistic operational event, the one-extra-epoch penalty may warrant Medium. The coordinator retains Minor but records
the disagreement.

**Status.** Open.

---

### R2-CYF-12 — `unlock()` is the one irreversible lever and is not timelock-gated — Minor

**Reviewer:** A8. **Invariant:** none — a trust-boundary shape.

**Description.** Filed **not** as centralization — which is out of scope — but because the out-of-scope rule's stated
premise is that privileged actions are gated by a Safe acting through two `TimelockController`s. This specific action is
behind neither. Every reversible parameter setter on `TrustBonding` is `onlyTimelock`; the one irreversible action is
`DEFAULT_ADMIN_ROLE` and instantaneous. There is no inverse anywhere in the tree.

**Code.** `src/external/curve/VotingEscrow.sol:153-155` (`unlock()`, sets `unlocked = true`, no inverse setter),
`:135-138` (`notUnlocked`), `:478-480` (expiry check skipped once unlocked); contrast
`src/protocol/emissions/TrustBonding.sol:99-104`, `:503-525` (`onlyTimelock` setters) and `:136` (`DEFAULT_ADMIN_ROLE`
granted at init).

**Impact.** One instantaneous privileged transaction, with no notice window, permanently ends bonding and emissions
eligibility for the deployment. Not fund-loss — principal is released, not taken — but the largest single-transaction
blast radius on the contract and the only one users get zero warning of.

**Refutation attempted.** The reviewer searched for an inverse (none exists in `VotingEscrow` or `TrustBonding`);
checked whether an upgrade could restore it (yes, but via the 7-day upgrades timelock — so the _undo_ is timelocked
while the _do_ is not); checked whether `DEFAULT_ADMIN_ROLE` is held by a timelock rather than the Safe (`initialize`
grants it to `_owner`, which the deploy script sets to `ADMIN`, not to either timelock); and checked whether pausing
first would blunt it (`unlock()` carries no `whenNotPaused`).

**Recommendation.** Move `unlock()` behind `onlyTimelock`, or require both a `PAUSER_ROLE`-initiated pause and a
timelocked confirmation. Alternatively add an explicit `relock()` so the switch is not one-way. Note it also emits no
event, compounding the no-notice property.

**Status.** Open.

---

### R2-CYF-13 — `bridgeUnclaimedEmissions` carries no re-entrancy guard while both sibling value-movers do — Minor

**Reviewer:** A9. **Invariant:** none — a guard asymmetry. **PoC unresolved.**

**Description.** `bridgeUnclaimedEmissions` makes two external calls after its state write — the bridge dispatch and a
surplus gas refund to `msg.sender` — and carries no `nonReentrant`, while `transfer` and `withdrawUnclaimedEmissions`
both do. Requires `OPERATOR_ROLE`, which is a deliberate post-deploy grant.

**Code.** `src/protocol/emissions/SatelliteEmissionsController.sol:210-251`; compare `:131` and `:176-180`.

**PoC status — reported as unresolved, neither confirmed nor refuted.** The reviewer's
`EmissionReclaimLedger.t.sol::test_bridge_reentrantOperatorCanNestASecondEpoch` **fails on harness setup, not on the
hypothesis**: `AccessControlUnauthorizedAccount(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, 0x00…00)` — the `grantRole`
call was issued from the wrong prank context, so the nesting hypothesis was never reached. The coordinator independently
confirmed this failure mode in the suite run. **It proves nothing in either direction**, and is reported that way rather
than as a finding or as a clean negative.

**Refutation attempted.** Three double-spend routes were closed by code reading: same-epoch re-entry is blocked by the
per-epoch flag set before the external call; the inner frame's gas refund is drawn from its own `msg.value`, so no wei
is credited twice; and reserve draining is bounded because the amount is pinned per flagged epoch.

**Recommendation.** Add `nonReentrant` for symmetry. Zero behavioural cost; removes an asymmetry a reviewer must
re-derive each round. Fix the prank ordering and re-run the PoC before relying on the negative.

**Status.** Open, PoC outstanding.

---

### R2-CYF-34 — ECDSA signature encoding is non-unique on both signature surfaces — Minor

**Reviewer:** A7. **Invariant:** none — an integration-boundary class. Checklist `SOL-Signature-2`, `SOL-LL-1`.

**Description.** Neither signature surface enforces canonical encoding. Solady's `SignatureCheckerLib` states outright
that it does not check non-malleability. Anyone observing one valid signature can mint at least three further distinct
byte strings that all validate for the same digest and owner, **without the private key**: the high-`s` malleable
counterpart, the 64-byte EIP-2098 compact form, and arbitrarily many trailing-padded variants (the wrapper pre-decode
enforces only a _minimum_ length, and `abi.decode` ignores the tail).

**Code.** `src/libraries/CoinbaseSmartWalletLib.sol:105-129` (pre-decode), `:146`
(`SignatureCheckerLib.isValidSignatureNow`); reached from `src/protocol/wallet/AtomWallet.sol:338` and `:492`.

**Proof of concept.** `test_ecdsaEncodingIsNotUnique_malleableAndCompactAndPaddedAllValidate` and `..._onUserOpSurface`,
both passing — all four encodings return `0x1626ba7e`, and the same pair reproduces on `validateUserOp` with
`validationData == 0`.

**Impact.** No fund loss within this cluster — nothing here keys off signature bytes. The risk is entirely at the
integration boundary: any counterparty treating the blob as a unique identifier (order-cancellation sets, used-signature
mappings, off-chain dedup, indexer keys) can be bypassed. Note the existing
`test_validateSignature_returnsSigFailedOnInvalidSignatureSValue` _looks_ like malleability coverage but is not — it
uses `s == SECP256K1_CURVE_ORDER` (out of range), never `N − s`.

**Refutation attempted.** The reviewer tried to convert this into an authorization bypass and could not: a zero-signer
bypass is blocked by `SignatureCheckerLib.sol:36` (`if (signer == address(0)) return isValid;`), and decoder confusion
is blocked by layered bounds checks strictly stronger than Solidity's own. The P-256 branch is **not** malleable —
`P256.verifySignature` enforces low-`s`.

**Recommendation.** Enforce canonical form before dispatch: require `signatureData.length == 65`, `s <= N/2`,
`v ∈ {27,28}`, and exact wrapper length. Or document loudly that consumers must key replay protection off the digest,
never the signature bytes.

**Status.** Open.

---

### R2-CYF-35 — Two live `executeBatch` selectors disagree on access control and reentrancy protection — Minor

**Reviewer:** A7. **Invariant:** none. Checklist `SOL-Basics-Inheritance-1`, `SOL-Heuristics-16`.

**Description.** `AtomWallet` declares `executeBatch(address[],uint256[],bytes[])` with
`onlyMultiOwnableOwnerOrEntryPoint nonReentrant`, but does **not** override the inherited
`BaseAccount.executeBatch(Call[])`, which is gated only by `_requireFromEntryPoint()` and carries **no** `nonReentrant`.
Both selectors are live on the compiled ABI. The inherited surface is invisible in the source file.

**Code.** `src/protocol/wallet/AtomWallet.sol:198-216` versus
`lib/account-abstraction/contracts/core/BaseAccount.sol:60-75` and `:101-103`.

**Proof of concept.** `test_inheritedBatchSurfaceSkipsTheWalletGuards`, passing. From the EntryPoint, the **declared**
batch calling back into `claimAtomWalletDepositFees` reverts `ReentrancyGuardReentrantCall`; the **identical** call
through the inherited selector **succeeds**. A registered owner calling the inherited selector is rejected — so the two
surfaces also disagree on _who_ may call them.

**Impact.** Not an escalation — the inherited surface is EntryPoint-only, a strict subset of the declared function's
authority set. The reviewer could not convert it into a loss: double-claim is blocked by CEI plus `nonReentrant` on
`MultiVault.claimAtomWalletDepositFees`, cross-function reentrancy fails because a callback's `msg.sender` satisfies
neither owner check, and pre-claim the registry is empty so validation always fails. The defect is that the contract's
stated properties do not hold for its full ABI, and a future change relying on `nonReentrant` covering "all batch
execution" would be silently wrong. Predates this diff — v1.0.2 already sat on account-abstraction v0.8.

**Recommendation.** Override the inherited `executeBatch(Call[])` to revert, or apply the same modifier pair. Also
override `_requireForExecute()` so both execution surfaces share one authority definition.

**Status.** Open.

---

### R2-CYF-36 — Wallet CREATE2 identity is coupled to live `walletConfig`; an EntryPoint rotation re-derives every wallet — Minor

**Reviewer:** A7. **Invariant broken:** §5.1 — fees credited to identity A become unclaimable while new fees accrue to
identity B.

**Description.** `_getDeploymentData` reads `entryPoint` and `atomWalletBeacon` **live** from `walletConfig()` and folds
both into the BeaconProxy init code, so the CREATE2 address depends on them. Rotating the ERC-4337 EntryPoint — a normal
protocol-lifecycle event; v0.6→v0.7→v0.8 has already happened once — silently re-identifies every wallet in the system.

**Code.** `src/protocol/wallet/AtomWalletFactory.sol:144-161`, `:125-133`, `:88-93`. Consumers:
`src/protocol/MultiVault.sol:746-750`, `src/libraries/MultiVaultLib.sol:887`,
`src/protocol/wallet/AtomWarden.sol:539-544`.

**Proof of concept.** `test_entryPointRotationReDerivesWalletIdentityForTheSameAtom`, passing. After a timelock
`setWalletConfig` changing **only** `entryPoint`: `computeAtomWalletAddr(atomId)` returns a different, codeless address;
the live claimed wallet can no longer claim its own accrued fees (`MultiVault_OnlyAssociatedAtomWallet`); and the
permissionless `deployAtomWallet(atomId)` deploys a **second**, unclaimed wallet for the same atom, freshly claimable.
Control `test_walletIdentityIsOneToOnePerAtomUnderAFixedConfig` confirms the mapping is strictly one-to-one under a
fixed config.

**Impact.** Fees accrued to the old address are stranded permanently — `accumulatedAtomWalletDepositFees` is keyed by
address with no migration. Assets inside the old wallet remain accessible to its owner, but the atom's canonical wallet
and its future fee stream silently move. Trigger is `onlyTimelock`, so this is filed as an unintended consequence of a
routine governance action, not as centralization.

**Refutation attempted.** Salt collision is impossible (`atomId` is the salt directly). Address squatting is impossible
(init-code-hash binding; `BeaconProxy` has no `SELFDESTRUCT`). Rotating `atomWarden` — the far likelier action — does
**not** move addresses, since `_getDeploymentData` destructures past it.

**Recommendation.** Snapshot `entryPoint` and `atomWalletBeacon` into the factory at `initialize` so identity is
immutable, or record `atomId → deployedWallet` and have `computeAtomWalletAddr` prefer the recorded address. At minimum,
a NatSpec warning that changing either field re-derives every wallet address in the protocol.

**Status.** Open.

---

### R2-CYF-37 — An owner account that acquires code (EIP-7702) silently relocates the wallet's signature authority — Minor

**Reviewer:** A7. **Invariant:** none — outside checklist (post-Pectra).

**Description.** `SignatureCheckerLib` dispatches on `extcodesize(signer)`: no code → `ecrecover`, code → ERC-1271
staticcall. Post-Pectra, an owner EOA signing a 7702 delegation — a routine action requiring no interaction with
Intuition — flips that branch.

**Code.** `src/libraries/CoinbaseSmartWalletLib.sol:146` → `lib/solady/src/utils/SignatureCheckerLib.sol:42`.

**Proof of concept.** `test_ownerAccountThatAcquiresCodeSwitchesTheSignatureAuthority`, passing. After the owner account
acquires code, the previously-valid signature returns `0xffffffff` and `validateUserOp` returns `SIG_VALIDATION_FAILED`
— **every UserOp for that wallet stops working**. Conversely, a permissive ERC-1271 responder at the owner address makes
`isValidSignature` return success for _arbitrary bytes_.

**Impact.** Liveness loss in the common case (delegate to a batch executor without ERC-1271 → all account abstraction
for that wallet breaks, with no error pointing at the cause). Authority transfer in the adversarial case. Registry-gated
direct calls still work, so the owner is not locked out entirely — which, with the fact that a 7702 delegation requires
the account's own authorization, is what keeps this Minor. Mirrors upstream Coinbase behaviour, which predates Pectra.

**Recommendation.** Document the interaction in `addOwnerAddress`'s NatSpec, which currently warns only about _contract_
owners. Consider an owner-type flag set at registration so ECDSA recovery stays available for registered address owners.

**Status.** Open.

---

### R2-CYF-38 — `previewRedeem` quotes the curve redeem fee with `address(0)` while execution quotes with the real account — Minor

**Reviewers:** A4; independently observed by the coordinator during merge. **Invariant:** none — preview/execution
divergence.

**Description.** The public preview path passes `address(0)` as the account, so the curve is asked to price a redemption
for a non-holder; both execution paths quote with the real `receiver`. On any account-dependent fee curve the two
disagree. The interface explicitly delegates the fallback semantics to the curve, which is precisely the condition for
divergence.

**Code.** `src/libraries/MultiVaultLib.sol:438-444` (`calculateRedeem` → `_calculateRedeem(..., address(0))`), `:1064`
(the quote), versus `:794` (`_processRedeem`, real `receiver`) and `:1388` (`_validateRedeem`).

**Impact.** No fund loss — `minAssets` is enforced against the _real_ quote, so a user can never be silently underpaid;
the failure mode is a reverting redeem or an under-tight slippage bound. Cost is integrator correctness and a misleading
public view. Direction depends on the curve: for a holder whose tier sits below the vault's current tier the preview is
conservative, but a `setConfig` retune lowering tier edges can invert the sign.

**Refutation attempted.** The reviewer verified the two _execution-path_ quotes cannot disagree with each other — which
would be a genuine netted≠forwarded break — since `_validateRedeem` and `_processRedeem` are called with the same
`receiver` and **zero intervening state writes**. That is a clean PASS.

**Recommendation.** Add an account-aware preview overload, or forward `msg.sender`, or at minimum document the
`address(0)` semantics in `IMultiVault.previewRedeem`'s NatSpec, which today does not mention it.

**Status.** Open.

---

### R2-CYF-39 — Fee-hook probing hard-depends on every registered curve implementing the new getters — Minor

**Reviewer:** A4. **Invariant broken:** §5.2 in the temporary-stuck-funds sense. **Possible duplicate of round-1
INFO-05.**

**Description.** Both hook resolvers call `hasDepositFeeHook()` / `hasRedeemFeeHook()` unconditionally after the
zero-address guard, with no `try/catch` and no ERC-165 probe. The getters are new in v1.1.0. Any curve **proxy already
live whose implementation is not upgraded in the same batch** has no such selector; the staticcall hits the fallback and
reverts. Because the probe runs inside the deposit _and_ redeem calc paths, positions on that curve become temporarily
**unexitable**, not merely unenterable.

**Code.** `src/libraries/MultiVaultLib.sol:832-836`, `:839-843`; reached from `:959-963`, `:1021-1025`, `:1062-1065`.
Safe defaults exist at `src/protocol/curves/BaseCurve.sol:153-179`, so every **in-repo** curve is safe post-upgrade.

**Impact.** If mis-sequenced: total deposit and redeem DoS on every non-upgraded curve id until the curve proxies are
upgraded. Fully recoverable by governance; no loss. Reviewer A5 independently verified that the upgrade script marks
curve upgrades `[REQUIRED with [1]]` and that its dry-run asserts implementation pointers, that the hook getters
resolve, and that `registry.count()` equals exactly the covered curve set — which fails closed on a curve registered
after the script was written. **Those assertions live in the rehearsal path only**, so batch atomicity on the Safe is
what actually enforces ordering in production.

**Recommendation.** Wrap the two getter calls in `try/catch` returning `address(0)` on failure — failing open to
pre-upgrade behaviour, which matches the "a curve without hooks must be byte-identical to pre-upgrade" requirement. Or
keep the ordering precondition and add a pre-flight assertion to the execution path, not just the rehearsal.

**Status.** Open; close as a duplicate if INFO-05 already covers the ordering guarantee.

---

### R2-CYF-45 — `maxValidAfter` is a logically unreachable branch; the governance knob enforces nothing — Minor

**Reviewer:** A6. **Invariant:** none — governance-control efficacy and spec-versus-behavior.

**Description.** `_requireValidTimeWindow` runs two checks in sequence. The cap fires when
`validAfter > block.timestamp + maxValidAfter`; the ordering check requires `validAfter <= block.timestamp` for a claim
to proceed at all. **The two are mutually exclusive for every value of `maxValidAfter`, including `0`.** The cap branch
can therefore only fire on an authorization the ordering check would have rejected anyway — it changes the revert
selector, never the accept/reject decision.

The NatSpec is consequently wrong twice: a cap of `0` does **not** force `validAfter` to equal the current timestamp (an
authorization backdated by years is accepted), and tightening the cap retires nothing, because `now + maxValidAfter`
advances with `now` — a future-dated authorization is merely postponed until it would have activated on its own.

**Code.** `src/protocol/wallet/AtomWarden.sol:650-652` (the guard), `:657` (the check that subsumes it), `:77-81` and
`src/interfaces/IAtomWarden.sol:126-129` (the NatSpec it contradicts).

**Proof of concept.** `test_maxValidAfterZero_acceptsBackdatedValidAfter` — with the strictest possible setting
(`setMaxValidAfter(0)`), an authorization with `validAfter = now − 7 days` is **accepted** and the wallet is claimed.
`testFuzz_maxValidAfterCapBranchNeverGatesAdmissibleAuth` — 10,000 runs, no triple where the cap is the only thing
standing between an attacker and a claim.

**Mutation-check — the decisive evidence.** Deleting the guard entirely and re-running all 141 AtomWarden tests turns
exactly **one** test red, and it is a revert-selector assertion, not a behavioral one:
`AtomWarden_InvalidTimeWindow() != AtomWarden_ValidityWindowTooLong()`. Every accept/reject outcome in the suite is
unchanged. For contrast, the same mutation applied to the sibling `maxValidUntil` cap turns **four behavioral** tests
red — that guard is load-bearing; this one is not.

**Impact.** No value at risk. Operational: a documented incident-response lever that does nothing, plus NatSpec that
would mislead an external auditor and the off-chain signing service. Dead code on a hot path.

**Recommendation.** Either delete the guard, the variable, its setter and its event and correct the NatSpec; or, if the
intent was to bound _total_ authorization lifetime, bind the granted window into the signed struct and check
`validUntil − validAfter <= maxValidityDuration` — a quantity that does not drift with `block.timestamp`. The latter
also closes R2-CYF-46. **This is a public-API change and should be a product decision, not an auditor's default.**

**Status.** Open.

---

### R2-CYF-46 — `maxValidUntil` bounds remaining, not total, authorization lifetime — Minor

**Reviewer:** A6. **Invariant:** none — the blast-radius bound is weaker than the design intent.

**Description.** The cap is `validUntil <= block.timestamp + maxValidUntil`, evaluated at _claim_ time. Because
`block.timestamp` advances, it constrains an authorization's **remaining** lifetime, not the window the signer actually
granted. An authorization issued with a 30-day window under a 7-day cap is not rejected permanently — it is rejected for
23 days and then becomes claimable for its final 7, unchanged and never re-signed. The NatSpec is literally accurate,
but the property an operator would reasonably infer — "no signed claim may live longer than `maxValidUntil`" — does not
hold.

**Code.** `src/protocol/wallet/AtomWarden.sol:653-655`, `:86-91`.

**Proof of concept.** `test_overlongValidUntil_isDeferredNotRetired`, both legs passing: the out-of-policy authorization
first reverts `AtomWarden_ValidityWindowTooLong()` — so the operator sees the policy "working" — then, after
`vm.warp(23 days + 1)`, **the same bytes succeed with no re-signing**.

**Mutation-check.** Removing the guard turns four distinct tests red, so unlike R2-CYF-45 this guard _is_ load-bearing.
The defect is its semantics, not its existence.

**Impact.** The window in which a leaked authorization is usable is the signer-chosen `validUntil`, not the
governance-chosen cap. Attacker capability is anyone holding a stale or leaked signed bundle — no key material needed.
Bounded: one atom wallet per authorization, and the reviewer verified this does **not** compose into a cap bypass, since
budget is consumed on every authorized claim regardless of the authorization's age. Note also that rotating
`SIGNER_ROLE` keys does not retire outstanding authorizations, since the role is checked against the recovered address
only.

**Recommendation.** Check the signed duration against a governance ceiling so an out-of-policy authorization is rejected
for its whole life. Alternatively add a `signerSetVersion` field to `ClaimAuthorization` that an admin can bump to
retire every outstanding authorization in one call — which would also close the key-rotation gap. Today the only bulk
lever is `maxValidUntil = 0`, a total kill switch for the path.

**Status.** Open.

---

### R2-CYF-47 — Creator-expiry fallback pre-empts the address-atom owner and captures the wallet's accrued fees — Minor

**Reviewer:** A6. **Invariant:** none — identity/trust boundary. **Possible duplicate of round-1 MIN-01.**

**Description.** `claimOwnershipOverAddressAtom` exists so the holder of address `X` can claim the wallet of the atom
whose data is the hex string of `X`. `claimAsCreatorAfterExpiry` has **no exclusion for address atoms** — it checks only
creator identity, an elapsed claim window, and an accrued-fee threshold. Whichever fires first sets `isClaimed`, and the
other is permanently rejected. Atom creation is permissionless and records the creator, so a squatter simply creates the
atom for someone else's address first. The fee precondition is self-fundable.

**Code.** `src/protocol/wallet/AtomWarden.sol:324-355` versus `:251-269`; collision at `_requireWalletUnclaimed`
`:546-550`. Creator recorded at `src/libraries/MultiVaultLib.sol:566`.

**Proof of concept.** `test_creatorExpiry_preemptsAddressAtomOwner`, both legs passing: after the squatter's
creator-expiry claim succeeds, the address owner's `claimOwnershipOverAddressAtom` reverts `AtomWarden_AlreadyClaimed()`
permanently.

**Impact.** The victim permanently loses control of the ERC-4337 wallet canonically bound to their own address, and the
squatter takes the wallet's accrued deposit fees, withdrawable via `AtomWallet.claimAtomWalletDepositFees()`. Per-atom,
not systemic. The reviewer found **no recovery path**: `completeClaim` is one-shot, the address path has no override,
and even `OPERATOR_ROLE`'s `grantAtomWalletOwnership` runs the same unclaimed pre-check.

**Triage note.** The reviewer flagged this as possibly the same behavior as round-1 **MIN-01** (closed by design) and
filed it anyway on the basis that the _composition_ it demonstrates is a concrete value transfer rather than a flow
property. The coordinator carries that framing forward without asserting it is not a duplicate — triage holds the
round-1 detail needed to decide.

**Recommendation.** Have `claimAsCreatorAfterExpiry` reject atoms whose data matches the lowercase or checksummed hex
encoding of any address — the same two-way comparison already implemented on the address path. `setClaimWindow(0)`
disables the creator path entirely and is a working mitigation today.

**Status.** Open; may be Duplicate of MIN-01.

---

### 5.3 Informational

Presented in condensed form. Each carries a `file:line`, a mechanism, and a recommendation; none has security impact
under the deployed configuration.

| ID            | Reviewer    | Location                                                                                                              | Description and recommendation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------- | ----------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **R2-CYF-14** | Coordinator | 15 tracked test files (see below)                                                                                     | **Provenance markers already committed to the public mirror.** An internal issue-tracker identifier, sequential internal round/workstream labels, and the phrases `deep pre-audit` / `pre-audit` appear in the NatSpec titles — and in one case in a test function identifier — of tracked test files that ship publicly. Breaches the scope brief's "no internal ticket ids in anything that ships with the mirror" and the process rule that tests are provenance-free. The literal strings are deliberately not reproduced here, for the same reason. Retitle each to the mechanism under test; add a CI grep for provenance markers under `tests/` as the durable fix.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **R2-CYF-15** | A5          | `tests/unit/upgrades/v1.1.0/MultiVaultStorageLayout.t.sol`, `tests/unit/security/v1.1.0/StorageMirrorIntegrity.t.sol` | **Storage-layout suite does not pin intra-struct field ORDER** anywhere in the config region (slots 1–21). Mutation-checked **green/green**: swapping `minDeposit` and `minShare` in `GeneralConfig` left all 11 tests passing. Second-order result that changes the fix: a getter-relative slot assertion **cannot** detect an intra-struct reorder in principle, because the slot and the auto-getter's return position move together. Anchors must compare each raw slot against a **literal**. The library mirror cannot catch it either — both sides re-use the same imported struct type and move in lockstep. §5.5 asks for every field to be pinned; it is not.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **R2-CYF-16** | A5          | `src/protocol/MultiVault.sol:825-828`, `src/interfaces/IMultiVaultCore.sol:70-71`                                     | `setBondingCurveConfig` does not enforce the immutability its own NatSpec declares for `registry`, and validates neither field. Repointing `registry` remaps every `curveId` while vault state stays keyed by the old numbering; `defaultCurveId = 0` bricks every create and default-curve deposit/redeem. Either enforce or correct the NatSpec. Feeds R2-CYF-XC-01.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **R2-CYF-17** | A1          | `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:285-292`                                                            | Accumulator dust is **permanently unsweepable** — `sweepProtocol` pays exactly `protocolAccrued` and nothing else; truncation surplus is never booked anywhere. Measured growth over one 16-op sequence: `0 → −13 → −143` wei of custody in excess of obligations, monotone. Unbounded in principle, dust-class in magnitude, with no drain path for anyone, ever. Add a residual sweep, or fold the remainder into `protocolAccrued` at each credit site.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **R2-CYF-18** | A1          | `:265-273` vs `:811-819`, `:851-859`                                                                                  | A per-tier fee override is bounded against the caps **at set time** but returned **uncapped** thereafter, so it survives a later cap reduction. NatSpec `:257-258` states the override "does not bypass the cap"; it does, after any reduction. Composes directly into R2-CYF-03. Apply the live cap at read time.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **R2-CYF-19** | A2          | `src/libraries/MultiVaultLib.sol:832-836`, `:838-843`                                                                 | The two hook-capability getters are independent with no consistency check. A `deposit=false / redeem=true` curve is registerable and would debit a ledger no deposit ever credited — the same underflow as R2-CYF-01, reached without touching `defaultCurveId`. Collapse to one getter, or assert equality at registration. The shipped curve hard-codes both `pure true`, which is why this is Informational.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **R2-CYF-20** | A10         | `src/periphery/FeeProxy.sol:466-474`, `:477-485`                                                                      | Preview functions ignore registration, pause, and protocol caps, all of which routing enforces. An unregistered affiliate previews as `(0, grossAssets)` — reading as "free" rather than "not routable". Have previews revert with the same errors routing would, or return an explicit `routable` flag.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **R2-CYF-21** | A10         | `src/periphery/FeeProxy.sol:508-512`                                                                                  | No sweep or rescue for force-fed native value; `receive()` cannot prevent `selfdestruct` or coinbase feeding. No on-chain consequence — FeeProxy reads `address(this).balance` in zero places — but combined with R2-CYF-09 the contract has two ways to accrue unrecoverable value and none to release it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **R2-CYF-22** | A10         | `src/periphery/FeeProxy.sol:741-759`                                                                                  | Proportional `_allocate` makes per-leg funding unexpressible; a create batch sized at exactly `N × atomCost` has every leg shaved below `atomCost` and reverts wholesale. The atomic revert is _correct_; the gap is that no preview exposes the per-leg allocation. Add `previewBatchAllocation`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **R2-CYF-23** | A8          | `src/protocol/emissions/TrustBonding.sol:120-143`                                                                     | `initialize` never sets `multiVault`. Claims succeed for epochs 0–1 via a short-circuit and then hard-revert from epoch 2 onward if it is unset or non-contract. **Not applicable to the live deployment** — v1.1.0 upgrades an already-wired proxy — but it weakens the "initialization is atomic in the deploy scripts" reasoning. Take `_multiVault` in `initialize`, or short-circuit both ratio helpers on `address(0)`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **R2-CYF-24** | A9          | `src/protocol/emissions/CoreEmissionsController.sol:7`                                                                | The contract is a mixin (`internal` initializer, no external one) but is declared `contract` rather than `abstract`, so it compiles to a deployable artifact whose reads all divide by zero and revert with a bare `Panic(0x12)`. Declare it `abstract`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **R2-CYF-25** | A9          | `:163-169` vs `:197-201`                                                                                              | `getEmissionsAtEpoch(0)` returns the full base emission before `_START_TIMESTAMP` while `getEmissionsAtTimestamp` returns 0 for the same instant. No in-repo consumer reads the timestamp-keyed form, so no funds impact. Also makes epoch 0 wall-clock longer than `_EPOCH_LENGTH`; the reviewer confirmed this grants nothing, since epoch 0's budget is fixed regardless of duration and claiming is blocked at epoch 0.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **R2-CYF-26** | A9          | `SatelliteEmissionsController.sol:186`, `:196-201`, `:216`, `:222-227`; `TrustBonding.sol:369`                        | The upstream unclaimed-rewards read is stateless — after an epoch's residue is paid out, it still reports the same residue. Only a satellite-local flag prevents a second payout. Sound at today's single-consumer topology; hazardous for any second consumer. Subtract `_reclaimedEmissions[epoch]`, or document that the read is gross. **Reported as code-reading only — the supporting test has no confirmed run.**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **R2-CYF-27** | A3          | `src/libraries/MultiVaultLib.sol:1076-1084`                                                                           | `_increaseProRataVaultsAssets` divides by 3 and credits three equal shares, dropping `amount % 3` (up to 2 wei) per triple create or fee-charging triple deposit into unattributed contract balance. Safe direction — balance drifts above obligations. Route the remainder to `accumulatedProtocolFees` or to the subject vault.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **R2-CYF-28** | A2          | `src/libraries/MultiVaultLib.sol:790` → `:1388`, and `:794`                                                           | Redeem resolves the hook and re-quotes the fee twice per operation (2× `hasRedeemFeeHook`, 2× `quoteRedeemFee`, 3× registry `previewRedeem` round-trips per redeem, each `quoteRedeemFee` running `_tierOf` at up to 64 `rpow` iterations). Redundant gas only — the reviewer confirmed the two quotes **cannot** diverge, since both are `STATICCALL`s with only another `STATICCALL` between them. Not measured against the block gas limit, so no DoS is claimed. Compute once and pass the result into validation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **R2-CYF-29** | A1          | `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:483-492`                                                            | `claimable(account, termId)` folds in the **cross-vault** `earned` mapping, so any consumer summing it over a user's terms multiplies `earned` by the term count. No on-chain loss — `claim` pays `earned` once, verified against duplicate term ids. Split into a term-scoped `pendingFor` and a global `earned`, or document the composition rule.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **R2-CYF-30** | A5          | `src/protocol/MultiVaultCore.sol:204-206`, `:290-292`                                                                 | `getCounterIdFromTripleId` is `pure` and unvalidated; fed a counter-triple id it returns a well-formed "counter of a counter" that is not and can never be a term. The sibling `getInverseTripleId` resolves direction correctly. Internal callers are safe; the risk is to integrators reading the public ABI. Make it `view` and revert on a counter input, or rename to signal it is a pure derivation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **R2-CYF-31** | A8          | `src/interfaces/ITrustBonding.sol:66`, `:79`; `TrustBonding.sol:254-273`, `:287`                                      | Two declared errors are unreachable (no selector referenced anywhere under `src/`). `getUserInfo.eligibleRewards` is a forward-looking projection of the **open** epoch computed from extrapolated balances and still-moving counters, under a field name integrations read as "claimable now" — `getUserCurrentClaimableRewards` is the actual figure. Also a local shadowing the `locked` state mapping at `:287` (benign: declaration-point scoping resolves correctly). Delete the dead errors; rename or document the projection field.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **R2-CYF-32** | A7          | `src/protocol/wallet/AtomWallet.sol:87`, `:95`, `:281-304`, `:371-373`, `:451-470`                                    | **Latent upgrade-migration gap — filed as a FAILED disposition-override against MA-01; see §6.5.** The ownership root moved from the OZ `Ownable` namespace to a new `_claimant` slot that **no upgrade path ever writes**, while `isClaimed` carries forward with its meaning intact. A wallet claimed under v1.0.2 would therefore resolve `owner()` to `address(0)`, closing every authority surface, with `completeClaim` reverting `AlreadyClaimed` and `renounceOwnership` disabled — no in-implementation recovery. Confirmed by a 7/7 PoC, including a control proving unclaimed wallets upgrade cleanly, and confirmation that the legacy owner value survives in the abandoned slot so a future implementation _could_ migrate it. **The precondition does not exist** (no wallet claimed under the current implementation; one ever deployed) **and cannot be created against a third party** — the v1.0.2 claim path is self-only. Recommendation: add an on-chain pre-flight assertion to the upgrade script that reverts if any deployed wallet has `isClaimed == true && _claimant == address(0)`. Cheap, and converts an ops assumption into an enforced gate. |
| **R2-CYF-33** | A7          | `src/protocol/wallet/AtomWallet.sol:335-342`; `tests/unit/AtomWallet/AtomWallet.t.sol:1279-1331`                      | **The MED-01 fix has no negative regression test.** Under a _permissive_ mutation — accept the envelope **or** the bare digest — all 122 pre-existing wallet tests stay green; only the two new tests go red. Every existing test asserts "enveloped ⇒ accepted"; none asserts "bare ⇒ rejected". `test_isValidSignature_rejectsCrossWalletReplay` does not cover it, since the permissive mutant still separates wallets correctly. The fix is protected against deletion but not against a plausible backwards-compatibility refactor that would silently reopen MED-01. Adopt the two delivered negative tests as the gating regression.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **R2-CYF-40** | A7          | `src/protocol/wallet/AtomWallet.sol:385-387`; `src/libraries/CoinbaseSmartWalletLib.sol:192-194`                      | `addOwnerAddress` accepts `address(0)` unvalidated, while the sibling `completeClaim` and `transferOwnership` both reject it. Creates a permanently dead owner slot that counts toward the `LastOwner` guard. **No authentication bypass** — verified: `SignatureCheckerLib.sol:36` short-circuits on a zero signer, so no signature can validate against the slot. Residual is an inflated `ownerCount` that could keep `LastOwner` satisfied while zero _usable_ owners remain. Add the zero check.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **R2-CYF-41** | A7          | `src/protocol/wallet/AtomWallet.sol:491`                                                                              | `_validateSignature` applies the personal-sign prefix to `userOpHash`, whereas upstream Coinbase Smart Wallet validates the raw hash. **Not a replay issue** — the EIP-191 version byte (0x45 vs 0x01) cleanly separates it from the ERC-1271 path, verified in both directions. It is an interop trap: Coinbase-compatible SDKs and passkey clients will sign the raw `userOpHash` and be rejected, and on the WebAuthn branch the challenge becomes a value no standard passkey client produces. Either align with upstream or document the exact challenge construction. **Related, unverified:** `SignatureCheckerLib` executes `EXTCODESIZE` on an EOA owner during validation, which ERC-7562 rule **OP-041** forbids; upstream does the same and is production-proven, so this is flagged for a targeted bundler check rather than filed.                                                                                                                                                                                                                                                                                                                               |
| **R2-CYF-42** | A7          | `src/protocol/wallet/AtomWallet.sol:97-101`                                                                           | `__gap` NatSpec states a 50-slot footprint; `forge inspect` shows **53**. The append-only _rule_ the comment states was followed correctly (v1.0.2 `__gap[50]`@3 → `_claimant`@3 + `__gap[49]`@4, nothing moved, §5.5 satisfied at the slot level). Only the stated total is wrong — worth fixing because this is the comment a maintainer will trust during exactly the kind of migration that produced R2-CYF-32.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **R2-CYF-43** | A7          | `src/libraries/CoinbaseSmartWalletLib.sol:157`                                                                        | `requireUserVerification: false` is hardcoded, so a passkey assertion needs only user _presence_ — a tap — not a biometric or PIN. Matches the upstream Coinbase default with no on-chain toggle. Note Solady also does not verify `origin` or `rpIdHash`, delegating RP binding entirely to the authenticator — an upstream assumption the protocol inherits silently. Document the authenticator-trust assumption; consider a per-wallet flag for high-value wallets.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **R2-CYF-44** | A4          | `src/libraries/MultiVaultLib.sol:1157`                                                                                | `_rollover` sets `lastSystemUtilizationEpoch = currentEpoch` even when the carry was skipped, since the write sits outside the `sourceUtilization != 0` conditional. If an epoch's first action is a redeem large enough to drive `totalUtilization[epoch]` negative, that negative becomes the next epoch's carry source. The reviewer did not verify how `TrustBonding` consumes a negative `getTotalUtilizationForEpoch` and explicitly declined to file it against `MultiVaultLib`. Recorded as an open question; adjacent to R2-CYF-02.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **R2-CYF-48** | A6          | `src/protocol/wallet/AtomWarden.sol:475-505`, `:422-429`                                                              | `signerCount` is a role-grant tally, not a live usable-key census, and fails closed in both directions. **Inflation:** granting `SIGNER_ROLE` to `address(0)` succeeds and increments the count, permitting a threshold the quorum can never satisfy — the phantom entry can never sign, because recovery never returns the zero address and the ascending rule seeds at it. **Deflation:** any single signer can `renounceRole`, dropping the count to zero; the quorum then fails closed **and** the admin cannot repair it by lowering the threshold, since the setter requires `newThreshold <= signerCount` and every value reverts. Recovery needs a `grantRole` first. Liveness only, never authorization. Reject `address(0)` in the grant hook, and allow `setSignatureThreshold(1)` unconditionally so a wedged quorum is recoverable in one call.                                                                                                                                                                                                                                                                                                                   |

**R2-CYF-14 — the 15 affected files.** `AtomWalletAuthEdges.t.sol`, `AtomWalletTakeover.t.sol`,
`AtomWardenQuorum.t.sol`, `AtomWardenQuorumSoundness.t.sol`, `CrossCurveRedeemBound.t.sol`,
`DepositRedeemExtraction.t.sol`, `EmissionBudgetConservation.t.sol`, `FeeProxyConservation.t.sol`,
`MulticallPayableValue.t.sol`, `MulticallPayableValueAccounting.t.sol`, `StorageMirrorIntegrity.t.sol`,
`TrustBondingClaim.t.sol` (all under `tests/unit/security/v1.1.0/`), plus `AtomWardenUpgradeRegression.t.sol`,
`FeeProxyUpgradeRegression.t.sol`, `MultiVaultUpgradeRegression.t.sol` (under `tests/unit/upgrades/v1.1.0/`).

---

## 6. Properties checked — negatives

A `PASS` without an attempted refutation was treated as a `FAIL` throughout. Each line below records what was tried and
what defended it.

### 6.1 The refuted lead — curve conservation direction

This is recorded first because it is the round's most consequential negative.

**PASS — the curve's aggregate obligations never exceed its custody.** The curve reviewer's fuzzing initially indicated
the opposite. The coordinator re-ran its own PoCs and found:

- `test_sequenceDrivesOwedAboveCustody` **fails its own assertion**: `1099851135301953916 <= 1099851135301954008` — owed
  is 92 wei _below_ custody.
- The per-step trace is monotonically negative and widening:
  `0, 0, 0, 0, 0, 0, 0, 0, −13, −15, −29, −30, −30, −92, −92`.
- `test_rebaseFloorGrantsMoreThanCustodyHolds` "passed" only because it **contained no assertion** — it emitted logs,
  and its own log printed `owed − balance: −11`, the opposite of what its name asserted.
- The scratch variant never reached its solvency assertion, dying in setup on `vault tier: 2 != 3`.

The reviewer confirmed the correction on its corrected 16-step replay (`−143` wei, same direction), **owned the error**,
and deleted both misleading tests. Truncation surplus from the accumulator credit dominates over long sequences. **This
is the accepted MasterChef dust of the scope brief's curve framing and is not filed as a conservation or solvency
break.** The residual 1-wei transient in the opposite direction is filed at its true severity as R2-CYF-08, and the
unsweepability of the surplus as R2-CYF-17.

### 6.2 Landed round-1 fixes — verified with mutation-checks

**ERC-1271 replay-safe digest binding — VERIFIED, all three parts.** Note the brief's line anchors are one line off from
the tree: the guard is at `src/protocol/wallet/AtomWallet.sol:335-342`, and the domain fields are compile-time
`private constant`s at `:73-74` — not storage, so there is no setter and no initializer path an attacker or admin can
move.

- _What is bound:_ the EIP-712 domain typehash, the wallet (`verifyingContract`), the chain (`block.chainid`), and the
  `CoinbaseSmartWalletMessage(bytes32 hash)` struct wrapper.
- _Attacks on the new construction, all defended:_ two sibling wallets with identical owner, name and version produce
  different envelopes, because separation comes entirely from `verifyingContract`. The domain separator is **not
  cached** — it is a `view` recomputed per call, so a pre-fork signature is rejected after a chain-id change while a
  fresh one validates, which is strictly better than a cached design under beacon proxies. **Both the ECDSA and the
  P-256/WebAuthn branches bind identically** — structurally, because the digest is wrapped exactly once before dispatch,
  so the WebAuthn challenge _is_ the enveloped digest; a real P-256 assertion over the bare digest is rejected.
  clientDataJSON trickery fails: the reviewer planted the victim's enveloped challenge in the `origin` field of a
  genuinely-signed assertion and swept **every byte offset** (~110) as `challengeIndex` — all returned `0xffffffff`,
  none reverted. `isValidSignature` and `validateUserOp` are asymmetric by construction (EIP-191 version 0x01 vs 0x45)
  but **not replayable in either direction**, verified with positive controls on each surface so the test cannot pass
  vacuously. Pre-upgrade bare-digest signatures are rejected.
- _Mutation-check — completed, two mutations._ Removing the binding entirely turns four suites **red**, including the
  gating `test_isValidSignature_rejectsCrossWalletReplay`. The second, sharper mutation — permissive re-admission of the
  bare digest — is the one that matters and is filed as **R2-CYF-33**: the entire 122-test pre-existing suite stays
  **green**.

**Compatibility note worth surfacing:** rejecting pre-upgrade signatures is the correct security choice, but it is a
hard break for any counterparty holding an unexpired pre-upgrade ERC-1271 authorization (Permit2/Seaport-style). That is
a communication event, not a silent one.

**Zero epoch length rejected — VERIFIED, all four steps.**

- _Guard:_ `CoreEmissionsController.sol:129-133` rejects exactly `0`, called from the shared initializer at `:54`,
  inside the guard block `:53-57` that runs strictly before the five state writes at `:59-63`.
- _Coverage:_ exhaustive grep found **exactly five writes** to any schedule field in the entire `src/` tree, all in one
  function, all downstream of the guard block. **No `reinitializer` anywhere under `src/protocol/emissions/`**, and **no
  setter touches any schedule field** — the six satellite setters target only the bonding, controller and dispatcher
  addresses. The schedule is write-once-at-init by construction, which is itself the load-bearing property.
- _Other degenerate values:_ thirteen probed. `emissionsPerEpoch = 0`, `cliff = 0`, `cliff > 365`, and a past
  `startTimestamp` are all rejected. `emissionsLength = 1`, `type(uint256).max`, and `reductionBasisPoints = 0` are
  accepted but reach no divide-by-zero and no permanent brick. `block.timestamp < startTimestamp` neither underflows nor
  wraps; a far-future epoch index decays to zero without reverting; epoch→timestamp overflow **fails closed** with
  `Panic(0x11)` rather than wrapping to a low timestamp.
- _Mutation-check:_ deleting the call at `:54` turns **both** gating tests red —
  `CoreEmissionsControllerTest::test_initialize_revertsWhenEmissionsLengthIsZero` and
  `AccessControlTest::test_initialize_revertsWhenEmissionsLengthIsZero` — each with
  `next call did not revert as expected`, confirming a zero was storable and permanent pre-fix. Restored and re-verified
  green.

**Caveat carried forward:** the guard protects _future_ initializations. An instance already initialized with a zero
would not be helped, and no reinitializer exists. One on-chain read of the deployed satellite's `_EPOCH_LENGTH` before
the upgrade would close this.

### 6.5 Disposition-override attempts

The round-1 accepted list was supplied to every reviewer as ids and one-line rationales only, explicitly as a target to
be _defeated_ rather than a no-go zone. One override was attempted.

**MA-01 — override ATTEMPTED and FAILED. Disposition stands.** The `AtomWallet` reviewer filed a High against MA-01
("on-chain census shows the precondition does not exist"), arguing the census is a snapshot rather than an invariant and
that the precondition is _permissionlessly creatable_ during the 7-day upgrade timelock window. It was explicit that it
had no RPC access and could neither confirm nor refute the census itself.

Coordinator verification of the deployed v1.0.2 claim path defeats the override on its own terms:

- `v1.0.2:src/protocol/wallet/AtomWarden.sol:62-67` requires the atom's stored data to equal
  `abi.encodePacked(_toLowerCaseAddress(msg.sender))` — the claim is **self-only**. No caller can claim another user's
  wallet, so there is no third-party griefing path at all.
- `:71-73` requires the wallet to be already deployed.
- `:74` calls `transferOwnership`, which under v1.0.2's `Ownable2StepUpgradeable` sets only a _pending_ owner; the claim
  completes only on a second `acceptOwnership()` from the same party.

Creating the precondition therefore means a user bricking their own wallet in two self-sent transactions, for no gain.
Combined with the protocol team's census — no wallet claimed under the current implementation, exactly one ever deployed
— the precondition neither exists nor is adversarially reachable. **MA-01 remains correctly dispositioned.** The
underlying mechanism is nonetheless real and is retained as **R2-CYF-32**, because its only protection is a fact about
the world rather than a property of the code; the recommended pre-flight assertion converts it into an enforced gate at
negligible cost.

**Three further overrides were attempted against accepted dispositions and all failed**, recorded by reviewer A4 as
required: composing the accepted per-curve counter-stake scoping with the new fee hook to net a rebate (blocked — the
counter term is a distinct `termId`, so no accumulator is shared); using the accepted permissionless
`sweepAccumulatedProtocolFees` as a re-entrancy lever from the redeem payout (blocked — the mapping is zeroed before the
send and the recipient is a fixed governance address); and making the accepted below-threshold fee waiver interact with
the curve hook to produce an unbacked forward (blocked — `hook.fee` is withheld regardless of whether the vault waived
its own fee, so conservation holds). Reviewers A8 and A9 additionally considered and **declined** to re-file MED-03,
MED-04, MIN-02, MIN-04 and MIN-06 after verifying the relevant bounds actually bind.

### 6.3 Invariant verdicts

| Invariant                                            | Verdict                                                                         | Evidence and refutation attempted                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **§5.1 Conservation**                                | **PASS**, with R2-CYF-06 / R2-CYF-08 / R2-CYF-27 as bounded exceptions          | Curve direction re-verified by the coordinator (§6.1). FeeProxy: 10,000-run fuzz on the four-way zero-sum `spent == Δaffiliate + Δvault + Δcurve + Δproxy` with `Δproxy == 0`, with `assertGt` proving a nonzero curve cut every run. MultiVault: full ledger identity hand-derived for every path.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **§5.2 Solvency**                                    | **PASS**                                                                        | Principal never sits in the curve — the only payable entry points are the two `onlyMultiVault` record hooks, there is **no `receive()` and no `fallback()`**, and MultiVault forwards only `hook.fee` having already withheld it. Attempts to make the curve custody principal via zero-fee schedules and full-exit redeems all failed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **§5.3 Curve ledger mirrors vault shares**           | **FAIL** on the creation path (R2-CYF-01); **PASS** on deposit/redeem           | The mirror `sum(tierStake) == sum(userStake) == vaultAssets` held across every step of an 8-op deterministic sequence and a 16-op × 10,000-run fuzz, including tier migrations, partial exits and full exits — the mirror assertion **never** failed even in the run where the conservation assertion did. No share path bypasses the ledger: MultiVault has **no share transfer primitive**, so a position cannot be moved to an account with ledger headroom.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **§5.4 Flat-price par**                              | **PASS**, both directions                                                       | Direction 1 (no path redeems more than deposited): at par `_convertToShares`/`_convertToAssets` are exact — the identity, no rounding residue — and every fee uses `mulDivUp` against the user. 10,000-run fuzz with deposits split into 1–8 chunks: chunking never beat a lump. Direction 2 (no path prices below par): 10,000-run fuzz confirms `price >= 1e18` in the fee-donation regime. Structural reason par is _maintained_: every asset-only credit routes through helpers that hard-read `defaultCurveId`, so fees land in the linear vault, never the flat-price one. Mutation-checked: changing `LinearCurve.previewMint`'s zero-supply branch to `shares + 1` turns the par test red.                                                                                                                                                                                                                                                                                                          |
| **§5.5 Storage-layout upgrade-safety**               | **PASS** on the layout; **FAIL** on the regression suite's coverage (R2-CYF-15) | Verified twice, independently. A5 diffed `forge inspect MultiVaultCore` against `MultiVault` field-by-field; A4 built a throwaway probe placing `MultiVaultLib.Storage` at slot 0 and diffed its `forge inspect` output against both `MultiVault` and `MultiVaultMigrationMode` — **all 23 mirror fields agree on slot, offset, type and width**, and `MultiVaultMigrationMode` adds zero storage. No OZ base contributes a sequential slot (`_tripleIdFromCounterId`@25 → `approvals`@26 with nothing between), confirming ERC-7201 namespacing throughout rather than coincidence. Gap arithmetic traced through git history (`300df9f → b6ce785 → d312a95 → b223116 → HEAD`): footprint ends at slot 84 both before and after the three v1.1.0 tail fields, gap 50 → 47. The "never-released tail slots" exception **predates round 1** — `b52557b` already carries `__gap[47]`@38 — so it is not in this round's delta at all. But an intra-struct field-order mutation left the suite **green/green**. |
| **§5.6 No `msg.value`-replay in `multicallPayable`** | **PASS**, defended (R2-CYF-04 is hardening)                                     | `sum(values) == msg.value` enforced; `total += values[i]` sits **outside** the `unchecked` block so an overflow panics; nested multicalls rejected in all four combinations; canonical `multicall` forces `_virtualMsgValue = 0`; short calldata rejected before selector extraction so no padding can reach an allowlisted selector; EIP-1153 reverts transient writes in a reverted frame. **`MultiVaultLib` contains zero `msg.value` reads** — all six payable entry points read `_effectiveMsgValue()`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

### 6.4 Selected negatives by cluster

**Curve economy.** Depositor never earns from their own deposit fee (exclusion subtraction plus post-distribution debt
re-base) · exiter never earns from their own withdrawal fee · `claim` with duplicate term ids does not double-book
(`_settle` idempotent within a transaction; `earned` zeroed before send) · `sweepProtocol` cannot exceed
`protocolAccrued` · `_piecewiseDepositFee` always terminates and never underflows, branch-by-branch · an over-steep
schedule cannot brick `tierOf` on the hot path — `growthGBps = 100·BPS` with `tierCount = 64` reverts **inside
`_setConfig`'s top-edge probe**, before any position exists · a tight `sigma` cannot silently forfeit the pool (falls
through to nearest-occupied) · whale-exit fallback cannot pay the exiter (the search never returns `exitTier`) · retune
preserves booked and pending earnings (`setConfig` touches no accumulator, no stake, no debt) · `tierCount` grow-only
guard reads stored state before the config write.

**Hook dispatch.** Quote-then-record equality holds **by dataflow** — the `CurveHook` struct is populated once and
carried by value, never re-resolved after the vault writes. The property that makes this airtight, verified by
enumeration: **the entire deposit and redeem write path makes exactly one non-`view` external call — the record hook
itself**; every other is `STATICCALL`, so no curve can mutate state between quote and record. Both deposit quote sites
were fuzz-verified to agree with each other on the same fee base. Mutation-checked: replacing the carried `hook.fee`
with a re-quote turns four tests red, including a state-dependent curve diverging by ~78%. A lying, reverting, or
gas-exhausting curve **fails closed** on every variant — vault totals and user balances bit-identical after the revert.
A mid-transaction flip is **impossible** on the deposit path (one read, carried) and impossible on the redeem path (two
reads, but only `STATICCALL`s between them). Registry curve ids are append-only, never re-pointed, never reused.

**Value accounting.** Every allowlisted leg consumes its allocation **exactly** — `_validatePayment` requires
`payment == total` with no slack, so no leg can under-consume and strand a remainder. No native value stranded on the
vault after a batch. Selector allowlist cannot desynchronize from the dispatched selector.

**Emissions.** The MED-03 cap chain binds end-to-end: ratio ≤ 10,000 → budget ≤ max emissions → cumulative claims ≤
budget, **mutation-proven** (deleting the clamp produces a `615.38e18` overpay against a 1-wei remaining budget). The
sum of every user's epoch-end veTRUST snapshot equals the total **exactly** across 10,000 fuzz runs. The epoch budget is
immutable across the claim window. Precision loss is always downward and the remainder feeds the reclaim ledger. The
boundary-lock snipe is bounded at **+1.96%**, matching the documented `EPOCH_LENGTH / MAXTIME` bound. The fresh-address
target exemption is dominated by lock decay — a **102× weight penalty against a ≤4× ratio gain**. A malicious reward
recipient cannot re-enter; the un-gated `checkpoint` is idempotent with respect to elapsed time and does not corrupt
post-unpause accounting (verified by snapshot/revert against a control timeline). **No lock-taking entry point is
missing `whenNotPaused`** — full enumeration of every state-changing function, mutation-proven by removing the modifier
from three of them. A pause never traps principal.

**FeeProxy.** A malicious record-hook curve cannot re-enter usefully through any of five doors, with the ledger verified
unchanged after each. The only FeeProxy state half-written at hook time is benign — stats are deliberately deferred
until after the vault call, and `pendingRefund` is untouched. FeeProxy reaches **no** unguarded payable MultiVault entry
point: four hardcoded call sites, none parameterised by a caller-supplied selector, zero `delegatecall`/`assembly`, and
`multicallPayable` is unreachable. Approval bits do not leak across route families. The proxy cannot be made the share
receiver of a route it mediates — mutation-proven load-bearing. Pausing cannot strand credited refunds (verified under a
_double_ pause). `FeeGuard` is a complete front-run defence.

**Warden — the per-window claim cap.** This was the round's third priority thread and it came back **defended**, with
the strongest mutation evidence in the report. A `claimCapWindow` retune cannot reset or double the in-window budget,
attacked four ways: widen after exhaustion (count preserved, next claim still rejected); three chained retunes in one
block (count survives all three); a fuzz over `(oldWindow, newWindow, warpBy)` confirming the arithmetic reason it holds
— the retune writes `currentClaimWindowId = block.timestamp / newValue` using the **same divisor** the claim path will
read, so the two agree exactly at the retune instant and the rollover branch cannot fire; and an end-to-end fuzz over
any `newWindow`. **Mutation-checked:** deleting the re-anchor turns five tests red _including_ the end-to-end fuzz with
a concrete counterexample — without it, a retune **does** mint fresh budget. That single line is the load-bearing guard.

Also defended: the cap can only revert or increment, never admit a claim the quorum rejected — confirming the MIN-03
disposition's claim that it "degrades liveness, never authorizes", with **no override**. A failed claim consumes no
budget. Disabling then re-enabling the cap within one real window **inherits** the spent count rather than granting a
fresh one. No division by zero on a zero window, guarded twice independently. The cap counts claims, not signatures, so
a 150-signature bundle costs the same one unit and still claims exactly one wallet. Window-boundary straddle admits up
to `2 × cap` in a two-second span — inherent to fixed-window limiting, documented, bounded, and recorded rather than
filed.

**Warden — quorum soundness.** Ascending-order distinctness holds at the **first** and **last** element and on empty
sets; the rule compares recovered _addresses_, not signature bytes, so malleated encodings collapse to one signer rather
than counting twice. High-`s` malleability, `v ∉ {27,28}`, and 64-byte compact signatures are all rejected. **ERC-1271
contract signers cannot enter the quorum at all** — the verifier is raw `ECDSA.tryRecover` with no `SignatureChecker`
fallback anywhere in the file, so the "contract signer changes its answer mid-transaction" hazard is structurally
absent. A removed signer's signature stops counting and a raised threshold retroactively invalidates an undersized
bundle, both mutation-proven (8 and 4 tests red respectively). Malformed blobs cannot be parsed into more entries than
were signed. Every signed field is bound to the digest, verified member-by-member and each proven load-bearing. **No
replay across chain ids** — the EIP-712 domain separator is rebuilt on every call with no immutable cache, which answers
the cached-versus-live question in the safe direction for an upgradeable contract.

**Wallet (152 tests across six suites).** An out-of-range or vacated owner index fails closed without reverting, and
owner indices are never reused. A 64-byte passkey owner cannot collide with a 32-byte address owner — length-based
dispatch plus distinct mapping preimages. An ECDSA signature is never checked against a passkey slot. The owner registry
cannot be emptied: removing the primary owner and removing the last owner are separately guarded. An index mismatch
cannot delete a different owner's slot. `transferOwnership` can never strand `owner()` outside the registry, which would
wedge all later rotations. Ownership cannot be renounced. The claim transition is one-way, the warden cannot claim a
wallet to itself, and a non-warden cannot seed an owner. A pre-claim wallet cannot be taken over by a forged signature,
nor driven through the self path — reaching it requires `execute`, which requires an owner or a passing
`validateUserOp`, both closed pre-claim. Degenerate P-256 inputs (`r = 0`, `s = 0`, all-zero key, off-curve point) fail
closed **without reverting**, preserving the ERC-4337 no-revert contract, and a hostile ERC-1271 owner contract cannot
make `validateUserOp` revert. Unknown calldata does not silently succeed — the fallback reverts on an unrecognised
selector. Reentrancy into the fee-claim path cannot double-spend.

---

## 7. Coverage, gaps, and limits of this review

Stated plainly, because an implied-complete review is worse than an honestly partial one.

**All ten reviewers returned a narrative subreport**, though several arrived only after repeated infrastructure failures
and resumption from transcript. Depth is uneven; the differences are set out below and should be carried into the master
rather than flattened.

**The `MultiVaultLib` review is static-analysis only.** That reviewer never obtained a compiling `tests/` tree — two
concurrent reviewers' in-flight test files had compile errors, and Foundry compiles the whole test directory regardless
of `--match-path` — so it ran **no PoC and no mutation-check**. Its three headline verdicts (the §5.5 storage mirror,
the §5.6 `msg.value` census, and §5.1 quote-then-record equality) are mechanically derived and, in the case of the
storage mirror, independently corroborated by reviewer A5. But its §5.6 re-entrancy PASS and its green/green prediction
for R2-CYF-15 are **unconfirmed by execution**, and it says so. Notably, its `msg.value` census is a clean mechanical
result worth relying on: `MultiVaultLib` contains **zero executable `msg.value` reads** — all three occurrences are in
NatSpec.

**Four reviewers declared partial or absent checklist walks.** The `MultiVault`, `MultiVaultLib`, and curve reviewers
did not load any checklist reference file, so **none of their findings carries a checklist item id**. The curve reviewer
additionally performed **no mutation-checks** and ran all of its PoCs by driving the record hooks directly rather than
through the real MultiVault — so quote-versus-record equality, batch interleavings, `multicallPayable` composition, and
the FeeProxy router path are argued statically on that cluster rather than executed. The `MultiVaultCore` reviewer did
not walk `basics.md` (135 items) or `defi.md` (63 items); the emissions reviewer did not walk `basics.md` or `token.md`.
By contrast the `AtomWallet` and `FeeProxy` reviews were fully checklist-anchored.

**Unresolved probes.** `EmissionReclaimLedger.t.sol` has no confirmed passing run; one of its tests fails on harness
setup and proves nothing (R2-CYF-13). The curve reviewer's amplification PoC for the sub-`1e18` tier-stake regime was
never completed, so whether that regime produces a _durable_ rather than transient deficit is **unresolved**.
`CoreConfigSlotAnchors.t.sol` — the gating test for R2-CYF-15 — **does not exist**; it was left non-compiling and
removed.

**Not run at all.** Medusa (`tests/medusa/DynamicFeeMedusaHandler.sol`), Halmos
(`tests/symbolic/DynamicFeeSymbolic.t.sol`), `DynamicFeeThirteenTierExample.t.sol`, and any fork test against live
deployed state. Consequently the deployed values of `defaultCurveId`, `registry`, `totalUtilization[0]`, the satellite's
`_EPOCH_LENGTH`, and FeeProxy's `maxBps` / `maxFixedFee` / `registrationFee` are **unverified against chain** — several
findings above turn on them.

**Environment note.** Ten reviewers shared one working tree. Mutation-checks by one reviewer intermittently broke
another reviewer's build, and one reviewer's incomplete test file broke the shared build outright. Every result reported
here was re-confirmed by the coordinator against a verified-clean tree (`git status --porcelain src/` empty). Reviewers
that could not be re-confirmed are marked as such above.

---

## 8. Verdicts

| Cluster | Contract(s)                                                         | Verdict                                                                                                 |
| ------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| C1      | `DynamicFeeFlatPriceCurve`                                          | **PASS** (provisional — checklist walk and mutation-checks not performed)                               |
| C2      | `IBaseCurve` / `BaseCurve` / `BondingCurveRegistry` / hook dispatch | **FAIL** — R2-CYF-01, unresolved Medium on a funds path                                                 |
| A       | `MultiVault`                                                        | **PASS**                                                                                                |
| B       | `MultiVaultLib`                                                     | **PASS** — static analysis only; not backed by any executed PoC or mutation-check                       |
| —       | `MultiVaultCore` + `LinearCurve`                                    | **PASS**                                                                                                |
| D       | `AtomWarden`                                                        | **PASS** — fully checklist-anchored; 141/141 tests, ten mutation-checks                                 |
| E       | `AtomWallet` + factory + P-256 lib                                  | **PASS** — reviewer submitted FAIL on a High that the coordinator downgraded to Informational; see §6.5 |
| F       | `TrustBonding`                                                      | **PASS**                                                                                                |
| G       | `FeeProxy`                                                          | **PASS**                                                                                                |
| H       | Emissions controllers                                               | **PASS**                                                                                                |

### Round verdict

**VERDICT: FAIL**

Two unresolved Mediums sit on funds paths — R2-CYF-01 (creation-path ledger desync producing permanently unredeemable
positions) and R2-CYF-02 (upgrade-epoch utilization seed) — and the cross-contract composition R2-CYF-XC-01 shows a
single unvalidated governance write breaking three independent invariants. Neither Medium is live under the deployed
configuration, and no Critical or Major finding was reached. The verdict is FAIL on the scope brief's stated rule (any
unresolved Medium on a funds path), not because the upgrade is assessed as unsafe to ship.

### Severity disagreements recorded

Two reviewer severities were changed in the merge pass, both stated here rather than silently applied:

1. **A7-01 → R2-CYF-32, High → Informational.** The reviewer's disposition-override against MA-01 does not survive
   verification of the deployed v1.0.2 claim path (§6.5). The reviewer was explicit that it could not check the census;
   the coordinator could, and the precondition is neither existent nor adversarially reachable. Its cluster verdict is
   correspondingly changed from FAIL to PASS.
2. **A8-01 → R2-CYF-11, retained at Minor.** The reviewer rated it Low but flagged that if a pause spanning a claim
   window is a realistic operational event, the one-extra-epoch penalty may warrant Medium. The coordinator retains
   Minor; the disagreement is on the record and turns on an operational likelihood judgement the protocol team is better
   placed to make than either party here.

### Headline severity count

**0 Critical · 0 Major · 2 Medium · 20 Minor · 26 Informational** (+1 cross-contract composition, Medium)

---

## Appendix A — Methodology

**Mode.** Checklist-driven audit skill in per-contract multi-agent configuration: ten reviewers, one contract each, all
running concurrently against one pinned commit, each given the same shared scope brief and none given sight of any other
reviewer's output.

**Independence controls.** Every reviewer was barred from opening any prior round's directory, any other round-2
reviewer's output, or the private internal-audit tree. The complete round-1 disposition register — ids, statuses, and
one-line rationales only, with mechanisms and exploit paths deliberately withheld — was supplied to each reviewer so
that known-accepted design decisions would be recorded as negatives rather than re-filed, while leaving the accepted
list open to being _defeated_ by a concrete exploit path. No disposition override was produced this round; two reviewers
explicitly considered and declined to re-file MED-03 and MED-04 after verifying the relevant bounds actually bind.

**Verification protocol.** Every non-`N/A` verdict carries a `file:line`. A `PASS` without a recorded refutation attempt
was treated as a `FAIL`. Findings at Medium and above required an attempted Foundry PoC. Guard claims required a
mutation-check: apply the mutation, confirm the gating test goes red, restore, re-confirm green. Confirmed breaks
required a variant sweep across single / batch / on-behalf / preview / router / upgrade-initializer paths.

**Merge pass.** The coordinator de-duplicated by content rather than by id (R2-CYF-04 merges three independent
corroborations; R2-CYF-05 merges two; R2-CYF-03 merges two), resolved severity disagreements and recorded them where
they remain, independently re-derived and in one significant case **refuted** a reviewer's headline claim (§6.1),
verified the load-bearing source claims of every Medium directly, and searched for cross-contract compositions no single
reviewer could see (§4).

**Tooling.** Foundry `1.5.1` (`forge test`, `forge build`, `forge inspect … storageLayout`), Solidity `0.8.29`. Fuzz
runs at the repository's configured 10,000 iterations. All work local; no CI or `.github/**` files were touched; no
commits were made.

## Appendix B — Disclaimer

This is a **pre-audit artifact**: an internal, first-party, adversarial review conducted before external audit. It is
**not** a formal audit, certification, warranty, or guarantee of safety, and it does not constitute assurance that the
reviewed code is free of defects. Coverage is explicitly partial — §7 states what was and was not reviewed. Findings are
reported by mechanism; severity ratings reflect this reviewer's judgement under the stated trust model and deployment
assumptions, several of which were **not** verified against live chain state.
