# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 6 of 7 — Specialist-selection multi-agent (feature-driven agent roster + false-positive gate + PoC)

> **How this report was produced:** a specialist-selection multi-agent round. An orchestration skill was vendored at a
> pinned commit and read end-to-end before use; it detects contract features and selects a roster of adversarial
> specialists from a fixed catalogue. Six specialists ran independently over the in-scope set — accounting/conservation,
> economic exploit and game theory, reentrancy and external calls, DoS/griefing/fund-locking, state machine and access
> control, and signatures/ERC-4337 — plus a delta-regression pass against the previously reviewed commit. Each was given
> the invariant set, the out-of-scope denylist, and an independence guard, and each was required to attempt a refutation
> before recording a pass. Findings were then put through a six-gate false-positive review (reachability, upstream
> validation, math bounds, state preconditions, economic viability, environmental guards) by the orchestrator, which
> adjudicated conflicts between specialists and re-derived every promoted finding against source. Two findings carry an
> executed Foundry proof of concept; both previously landed fixes were verified by executed mutation-check (guard
> removed, gating tests confirmed red, source restored). Provenance ID prefix: `R2-HMN-`. One of 7 independent round
> reports; consolidated view: [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

## 1. Report metadata

| Field                       | Value                                                                                                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Artifact type               | Internal AI pseudo-audit — **not** a formal audit, certification, warranty, or guarantee of safety                                                                           |
| Target                      | Intuition v1.1.0 core upgrade, public mirror (`intuition-contracts-v2`), extending PR #153                                                                                   |
| Reviewed commit             | `8579c5e02e6fd1b58620565d5a6d06d3b9391548` (branch `feat/v1.1.0-core-upgrade`)                                                                                               |
| Working tree                | `ac567b2ecd03d12e3e27c0ce570381ef9e383196` — `src/` is **byte-identical** to the reviewed commit (`git diff 8579c5e..ac567b2 -- src/` is empty; only `package.json` differs) |
| Baseline for the delta pass | `b52557bc5d1e87537e621fc13917240d40044c24`                                                                                                                                   |
| Source root                 | `src/`                                                                                                                                                                       |
| Toolchain                   | Solidity `0.8.29`, Foundry `1.5.1-stable`, EVM `cancun`, optimizer on (10,000 runs)                                                                                          |
| Dependencies                | OpenZeppelin `5.4.0` (+ upgradeable `5.4.0`), Solady `0.1.26`, account-abstraction EntryPoint `v0.8.0`                                                                       |
| Target networks             | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                                                                                    |
| Date                        | 2026-07-28                                                                                                                                                                   |

**Headline result: 0 Critical, 2 Major, 7 Medium, 7 Minor, 12 Informational.**

Both Major findings are **latent under the shipped configuration** — neither is exploitable against the deployment as
currently parameterised. Each is one ordinary governance action away from being live, and neither has an on-chain guard.
See §5 for the precise preconditions.

---

## 2. Executive summary

This round reviewed the v1.1.0 in-scope set whole-contract, with primary weight on the two surfaces that carried **zero
prior audit coverage**: the new `DynamicFeeFlatPriceCurve` fee economy, and the standardized `IBaseCurve` fee-hook
interface together with its dispatch through `MultiVaultLib`. It also covered the `AtomWarden` quorum and per-window
cap, the `AtomWallet` ERC-4337 / P-256 authentication surface, and the full delta since the previously reviewed commit.

**The core accounting is sound.** The MasterChef-style fee accumulator, its exclusion arithmetic, and its rounding
discipline were derived algebraically case by case and hold exactly: every distributed fee sums to the pool it came
from, every excluded party is rebased out to the wei, and no user-facing charge rounds down. Value conservation, curve
solvency, the curve-ledger-to-vault-share mirror, and flat-price par all hold. The `multicallPayable` transient-value
machinery resists the double-spend it was designed against, and the reentrancy surface opened by the new record hooks
was traced step by step and found benign. The storage-layout mirror between `MultiVault` and the delegatecalled
`MultiVaultLib` was verified byte-exact against live `forge inspect` output across all 38 fields, and the
`ApprovalTypes` bitmask enum is byte-identical to the previous commit — so no previously granted on-chain approval
changes meaning on upgrade.

**The findings cluster in two places instead.**

The first is the fee **distribution shape**, not its arithmetic. Fee slices are allocated _between_ tiers by kernel
weight and only then divided _within_ a tier by stake. A tier's stake therefore does not affect how much that tier
receives — only how the receipt is split among its occupants. The sole occupant of a recipient tier collects the entire
slice regardless of position size. We confirmed this by execution: a 0.01 TRUST position captured the whole 0.9 TRUST
exit fee of a 15 TRUST holder who was the last occupant of their own tier, a 90× return on stake funded entirely by the
exiting holder. The same shape lets a holder who runs two addresses refund their own withdrawal fee in full, paying an
effective 0% exit rate where a single-address holder pays 2–8%.

The second is a family of **unguarded configuration couplings**. Several invariants that the code's own NatSpec asserts
are not actually enforced: a per-tier fee override survives a reduction of the cap it was validated against; a fee
schedule that the validator explicitly blesses can brick every redeem on the curve protocol-wide (measured threshold
9901 bps, no override required, against a validator that permits up to 10000); pointing `defaultCurveId` at a
hook-bearing curve permanently locks principal on every subsequently created term, because the create paths mint shares
without ever invoking the record hook that the interface documents as always called. That last one was reached
independently by four of the six specialists and by the orchestrator.

A distinct concern sits outside the contracts: the mainnet deploy script hands curve ownership — `setConfig`,
`setTierFeeOverride`, `sweepProtocol`, and a live `renounceOwnership` — to the broadcasting EOA, with a source comment
deferring migration to the Safe. The accepted trust model for this upgrade is a 4-of-8 Safe behind TimelockControllers,
not a single hot key, so the assumption several other findings are risk-rated against does not hold as the script is
written.

Both previously landed fixes were verified and mutation-checked by execution. Removing the ERC-1271 replay-safe envelope
turns eight committed tests red; neutering the zero-epoch-length guard turns both gating tests red. Both fixes are
genuinely guarded, and the source was restored and confirmed clean.

---

## 3. Scope

### 3.1 In scope (reviewed at `8579c5e`)

| Contract                       | Path (`src/…`)                                               | Depth this round                                                                   |
| ------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `DynamicFeeFlatPriceCurve`     | `protocol/curves/DynamicFeeFlatPriceCurve.sol`               | Whole-contract, all 912 lines, by four specialists                                 |
| `IDynamicFeeFlatPriceCurve`    | `interfaces/IDynamicFeeFlatPriceCurve.sol`                   | Whole-interface                                                                    |
| `IBaseCurve` / `BaseCurve`     | `interfaces/IBaseCurve.sol`, `protocol/curves/BaseCurve.sol` | Whole-contract                                                                     |
| `MultiVaultLib`                | `libraries/MultiVaultLib.sol`                                | Hook dispatch, create/deposit/redeem write paths, storage mirror, whole-file delta |
| `MultiVault`                   | `protocol/MultiVault.sol`                                    | Multicall value machinery, setters, delta                                          |
| `MultiVaultCore`               | `protocol/MultiVaultCore.sol`                                | Delta                                                                              |
| `BondingCurveRegistry`         | `protocol/curves/BondingCurveRegistry.sol`                   | Whole-contract, all 267 lines                                                      |
| `LinearCurve`                  | `protocol/curves/LinearCurve.sol`                            | Whole-contract                                                                     |
| `AtomWarden`                   | `protocol/wallet/AtomWarden.sol`                             | Whole-contract, all 754 lines                                                      |
| `AtomWallet`                   | `protocol/wallet/AtomWallet.sol`                             | Whole-contract, all 510 lines                                                      |
| `AtomWalletFactory`            | `protocol/wallet/AtomWalletFactory.sol`                      | Whole-contract                                                                     |
| `CoinbaseSmartWalletLib`       | `libraries/CoinbaseSmartWalletLib.sol`                       | Whole-file, all 400 lines                                                          |
| `CoreEmissionsController`      | `protocol/emissions/CoreEmissionsController.sol`             | Fix verification + schedule arithmetic                                             |
| `SatelliteEmissionsController` | `protocol/emissions/SatelliteEmissionsController.sol`        | Initialization paths                                                               |
| `TrustBonding`                 | `protocol/emissions/TrustBonding.sol`                        | Delta + read-only reentrancy surface                                               |
| `FeeProxy`                     | `periphery/FeeProxy.sol`                                     | Whole-file + curve-hook composition                                                |

Deploy scripts under `script/` were read to establish the shipped configuration and are cited where a finding depends on
it.

### 3.2 Out of scope

Not reviewed, per the engagement scope: Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain
transport leg; `BaseEmissionsController` and all Base-chain components; the deliberately parked TVL exit rate limiter
(its absence is a decision, not a gap); unbounded cross-curve counter-stake aggregation (rejected on principle);
`MultiVaultMigrationMode`; `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib` except insofar as
they must remain safe hook no-ops; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow` under `external/` and
`legacy/`; the `AtomWallet` delegation framework (`executeFromExecutor`), held out of merge; and mixed payable /
non-payable `multicallPayable` batching, where the current wall is the intended boundary.

**Trusted-admin centralization is an accepted trust assumption** — privileged actions are gated by a 4-of-8 Safe acting
through two `TimelockController`s (parameters 3-day, upgrades 7-day). "A trusted admin can do X" is therefore not filed
as a finding. What _is_ filed is the narrower case where a routine, well-intentioned privileged action silently breaks
an invariant the code documents as held, or where the deployment does not actually place a privileged function behind
that accepted structure.

### 3.3 Static analysis

Slither and Semgrep are both installed on the review host, but **Slither could not be run**: crytic-compile forces a
`solc-select` artifact download that the sandboxed environment blocks (HTTP 403), and it does so even when an explicit
local `--solc` binary is supplied. No static-analysis pass contributed to this report. Findings are from source reading,
hand-derived arithmetic, and executed Foundry probes.

---

## 4. Severity classification

Impact × Likelihood, assessed against the intended deployment and trust model. Permissionless exploitability is
separated from trusted-admin misuse throughout.

| Severity          | Criterion                                                                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control. |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path corrupts critical state.                                |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing or DoS of a funds path, admin footgun, or a spec regression materially affecting users or operators. |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behaviour, monitoring or integration weakness.                                           |
| **Informational** | Documentation, hygiene, NatSpec-versus-behaviour mismatch, or missing non-critical test coverage.                                                            |

---

## 5. Findings

| ID        | Severity | Confidence | Cluster | Title                                                                                                         | Invariant                   | Status |
| --------- | -------- | ---------- | ------- | ------------------------------------------------------------------------------------------------------------- | --------------------------- | ------ |
| R2-HMN-01 | Major    | High       | C1      | Tier fee awards are winner-take-all by tier, so a dust position captures a departing holder's entire exit fee | Economic design (new class) | Open   |
| R2-HMN-02 | Major    | High       | C2      | A hook-bearing default curve permanently locks principal on every created term                                | §5.3                        | Open   |
| R2-HMN-03 | Medium   | High       | C1      | `_setConfig` accepts a fee schedule that bricks every redeem on the curve                                     | §5.2                        | Open   |
| R2-HMN-04 | Medium   | High       | C1      | Per-tier fee overrides survive a reduction of the cap they were validated against                             | Spec regression             | Open   |
| R2-HMN-05 | Medium   | High       | C2      | `setBondingCurveConfig` replaces the registry pointer with no validation                                      | §5.3                        | Open   |
| R2-HMN-06 | Medium   | High       | Deploy  | Mainnet deploy assigns curve ownership to the broadcasting EOA                                                | Trust boundary              | Open   |
| R2-HMN-07 | Medium   | High       | C1      | A retune with live positions silently re-targets the entire fee stream                                        | Spec regression             | Open   |
| R2-HMN-08 | Medium   | Medium     | E       | Rotating the EntryPoint re-derives every AtomWallet address                                                   | Trust boundary              | Open   |
| R2-HMN-09 | Medium   | High       | C2      | `previewRedeem` does not reproduce the fee an actual redeem charges                                           | Spec regression             | Open   |
| R2-HMN-10 | Minor    | High       | C1      | `renounceOwnership` is live on the fee custodian and the registry                                             | —                           | Open   |
| R2-HMN-11 | Minor    | High       | E       | Inherited `BaseAccount.executeBatch(Call[])` is not overridden                                                | —                           | Open   |
| R2-HMN-12 | Minor    | High       | C1      | `claim` has no recipient parameter, so a reverting holder strands earnings permanently                        | —                           | Open   |
| R2-HMN-13 | Minor    | High       | C1      | Chunking a deposit is cheaper than lumping it and yields a better bucket                                      | Spec regression             | Open   |
| R2-HMN-14 | Minor    | High       | E       | ECDSA signature encodings are non-unique on the AtomWallet surfaces                                           | —                           | Open   |
| R2-HMN-15 | Minor    | Medium     | C2      | Hook-getter symmetry is not enforced at registration and there is no cross-transaction latch                  | —                           | Open   |
| R2-HMN-16 | Minor    | High       | C1      | The gas ceiling regression test does not bound the configuration space `setConfig` permits                    | Test debt                   | Open   |

Informational findings are listed in §5.17.

---

### R2-HMN-01 — Tier fee awards are winner-take-all by tier, so a dust position captures a departing holder's entire exit fee

- **Severity / Confidence / Status:** Major / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:424-441`, `:769-786`, `:636-657`,
  `:693-719`, `:371-374`
- **Invariant broken:** None of §5.1–§5.4 — conservation, solvency, the ledger mirror and flat-price par all hold. This
  is a break of the mechanism's stated economic purpose, filed as a new class.
- **Attacker capability:** Permissionless. Requires only a minimum-size deposit (`MIN_DEPOSIT = 1e16`, 0.01 TRUST)
  placed in the right tier, and public state (`tierStake`, `userStake`, `userTier`, `vaultAssets` are all public
  getters) to know which tier that is.

#### Description

Every site that awards a fee slice divides it by the _recipient tier's_ stake and adds the quotient to that tier's
accumulator:

```solidity
// :649  normal kernel credit
accFeePerShare[termId][span - d] += share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
// :714  degenerate award (kernel window missed every occupied tier)
accFeePerShare[termId][bestTier]  += pool.fullMulDiv(ACC_PRECISION, bestStake);
// :436  whale-exit fallback (exiting tier has no residual cohort)
accFeePerShare[termId][recipientTier] += toTier.fullMulDiv(ACC_PRECISION, recipientStake);
```

A holder's pending is `stake · acc / 1e18`, so the arithmetic is exact and conserves value — but the allocation
**between** tiers is by kernel weight only. A tier's stake determines how a slice is split among that tier's occupants;
it does not affect how large a slice the tier receives. The sole occupant of a recipient tier therefore collects 100% of
the slice whether they hold one wei or a million TRUST.

The sharpest instance is the whale-exit fallback at `:424-441`. When an exiting holder is the last occupant of their own
tier, `denom` is zero and the whole diamond slice is rerouted by `_nearestOccupiedTier` (`:769-786`), which searches
**upward first** and returns the first occupied tier it finds — winner-take-all, with no stake floor. Under the shipped
schedule `withdrawalToRecentShareBps = 0`, so that slice is the entire withdrawal fee. It also fires on **partial**
exits, because `residual` is subtracted out at `:424`.

Two consequences follow. A third party who plants a dust position one tier above a known sole-occupant holder takes that
holder's entire exit fee. And a holder who runs two addresses refunds their own withdrawal fee in full — an effective 0%
exit rate against the 2–8% a single-address holder pays.

The same shape governs the deposit side: a dust position alone in a weighted prior tier pre-empts the fee stream that
would otherwise reach larger holders further down the ladder. The bucket that position occupies is cheaply selectable,
because `userTier` is `round(stake-weighted average entry tier)` (`:371-374`, `:862-866`) and the cost of moving buckets
is proportional to the mover's _own_ stake while the payoff is absolute. Return on capital is thus inversely
proportional to position size.

#### Proof of concept

Executed against the reviewed commit; both assertions pass. The curve is driven in isolation with the test contract
standing in as the authorized MultiVault, mirroring the repo's existing curve unit tests. Config: `width0 = 10e18`,
`tierCount = 5`, `growthGBps = 2000`, `fulcrumAlpha = 10000`, `kernelSpread = 4e18`, both `*ToRecentShareBps = 0` — the
shipped kernel parameters, with a smaller `width0` so the ladder is legible.

```solidity
function test_soleOccupantExitFee_routesEntirelyToTierAboveRegardlessOfStake() external {
    // Whale enters at tier 0 (vaultAssets == 0) and is the only holder of bucket 0.
    curve.recordDeposit{ value: 0 }(TERM, whale, 15e18);
    assertEq(curve.userTier(TERM, whale), 0, "whale in bucket 0");

    // Dust enters while the vault sits at tier 1 (10e18 <= 15e18 < 22e18), landing one bucket
    // above the whale, and is the only holder of bucket 1.
    curve.recordDeposit{ value: 0 }(TERM, dust, 0.01e18);
    assertEq(curve.userTier(TERM, dust), 1, "dust in bucket 1");

    uint256 exitFee = 0.9e18;                       // 6% of 15e18, the tier-0 withdrawal band
    uint256 dustBefore = curve.claimable(dust, TERM);

    // Whale exits in full. tierStake[0] drops to zero, so the exiting tier has no residual
    // cohort and the diamond slice falls through to the nearest occupied tier, searched upward.
    curve.recordRedeem{ value: exitFee }(TERM, whale, 15e18);

    uint256 dustGained = curve.claimable(dust, TERM) - dustBefore;

    assertEq(dustGained, exitFee, "dust captures the whole exit fee");   // 0.9e18 on a 0.01e18 stake
    assertEq(curve.claimable(whale, TERM), 0, "exiter is excluded from their own fee");
    assertEq(curve.protocolAccrued(), 0, "nothing routed to the protocol bucket");
}
```

Result: the 0.01 TRUST position gains exactly `0.9e18` — the whale's entire exit fee, a 90× return on stake. The exiter
is correctly excluded from their own fee, and nothing leaks to the protocol bucket, so the accounting is internally
correct; the value simply lands somewhere the mechanism did not intend.

#### Refutation attempted

Several routes were tried and did **not** hold, and the finding is narrower as a result:

- _Self-dealing on one's own deposit fee is not profitable._ With the depositor excluded from every recipient
  denominator (`:674-676`), a coalition recovers at most `W_B · f_B ≤ 1` of the fee the depositor paid, so
  round-tripping one's own fee caps at a full refund and can never profit. The break requires third-party fee flow.
- _Holders far below the source tier are not stripped of the fee._ An initial hypothesis held that the triangular window
  (`σ = 4`) starves holders more than four tiers down. Executed test refutes it: when **every** occupied prior tier
  falls outside the window, `sumWeights` is zero and `_awardNearestOrProtocol` (`:693-719`) awards the whole pool to the
  nearest occupied tier, split pro-rata. A whale holding 9 of 54 in bucket 0 at `d == σ` received exactly `pool · 9/54`,
  to within 4 wei of accumulator dust and never above it. The loss only occurs when a dust position occupies a
  _weighted_ tier and pre-empts them.
- _Forcing another holder to exit is blocked._ `redeem` and `redeemBatch` require
  `_isApprovedToRedeem(msg.sender, receiver)` (`src/libraries/MultiVaultLib.sol:293`, `:323`, guard at `:1403`), so the
  exit fee cannot be triggered against an unwilling holder.
- _Unsolicited bucket-dragging is blocked_ by the mirrored `_isApprovedToDeposit` (`:1399`).

#### Six-gate false-positive review

| Gate                 | Verdict                                                                                                           |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Reachability         | Pass — all three award sites are on the ordinary deposit/redeem hot path; `sender == receiver` is permitted.      |
| Upstream validation  | Pass — no minimum stake, dwell time, or stake-weight floor exists on the recipient side anywhere in the contract. |
| Math bounds          | Pass — recovery is exact to the wei; `fullMulDiv` is 512-bit with ~54 orders of magnitude of headroom.            |
| State preconditions  | Pass — "sole occupant of a tier" and "target bucket empty" are both readable from public getters before acting.   |
| Economic viability   | Pass — cost is one `MIN_DEPOSIT` (0.01 TRUST) plus gas; the PoC returns 90× on stake from a single exit.          |
| Environmental guards | Pass — no pause, no cap, no timelock on the curve's earning path; `claim` pays `earned` in full with no fee.      |

#### Impact

Fee revenue is transferred from large, passive, long-term holders to small, active, well-positioned addresses, and the
withdrawal fee becomes optional for anyone willing to run a second address. No principal is at risk and the protocol
never becomes insolvent — flat-price par holds and every fee is conserved. What is lost is the mechanism's intent: the
curve is meant to reward committed earlier cohorts, and as written it rewards bucket placement instead of commitment.

#### Recommendation

Make single-tier awards proportional to the recipient tier's stake rather than winner-take-all. Two changes cover it:
weight each tier by `weight(d) × tierStake(d)` in `_weighPriorTiers` (`:661-687`) so a tier's share scales with the
capital it represents; and route the `denom == 0` fallback in `recordRedeem` (`:434-437`) pro-rata across all occupied
tiers rather than to `_nearestOccupiedTier`. Both preserve the fulcrum shape and the exclusion arithmetic. If
winner-take-all is intended, a minimum eligible stake or a minimum dwell time would bound the dust asymmetry.

#### Regression test

`CurveFeeAwardProportionality.t.sol` — assert that when a sole-occupant holder exits, the rerouted fee is distributed
across occupied tiers in proportion to stake, and that a dust position cannot receive more than its pro-rata share of
any slice.

#### Variant sweep

| Path                                   | Result                                                                                                         |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Single deposit / redeem                | Same bug — the primary vector.                                                                                 |
| Batch (`depositBatch` / `redeemBatch`) | Same bug; each leg records independently.                                                                      |
| On-behalf-of                           | Blocked by the approval guards (`:1399`, `:1403`) for an unwilling counterparty; identical when self-directed. |
| Preview                                | N/A — preview does not distribute.                                                                             |
| Router (`FeeProxy`)                    | Same bug; `FeeProxy` forwards to `MultiVault` and makes no assumption about the share count.                   |
| Upgrade initializer                    | N/A.                                                                                                           |

---

### R2-HMN-02 — A hook-bearing default curve permanently locks principal on every created term

- **Severity / Confidence / Status:** Major / High / Open
- **Cluster + affected code:** C2 — `src/protocol/MultiVault.sol:824-827`; `src/libraries/MultiVaultLib.sol:567-586`,
  `:645-680`, `:910-932`, `:968-988`, `:723-725`, `:771`, `:808`, `:839-843`;
  `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:415-416`, `:304-306`
- **Invariant broken:** §5.3 — the curve ledger must mirror vault shares.
- **Attacker capability:** Not an attacker path. A single ordinary governance action through the parameters timelock,
  with no on-chain guard and no revert at the configuring transaction.

#### Description

`IBaseCurve` documents the record hook as unconditional on a hook-bearing curve:

> "…only on curves whose `hasDepositFeeHook` is true — but on those curves it is **ALWAYS** called, even when the quoted
> fee is zero, so the curve ledger stays in lockstep with vault shares." — `src/interfaces/IBaseCurve.sol:150-152`

The create paths do not honour that. `_createAtom` (`:567-586`) and `_createTriple` (`:645-680`) mint via
`_updateVaultOnCreation` against `s.bondingCurveConfig.defaultCurveId`, and their pricing helpers `_calculateAtomCreate`
(`:910-932`) and `_calculateTripleCreate` (`:968-988`) never resolve a `CurveHook` at all — unlike
`_calculateAtomDeposit` (`:959-963`) and `_calculateTripleDeposit` (`:1021-1025`). `_recordCurveDeposit` has exactly one
call site in the file, `_processDeposit:771`.

The redeem path, by contrast, is gated only on the curve's own getter: `_redeemFeeHookCurve` (`:839-843`) consults
`hasRedeemFeeHook()`, which `DynamicFeeFlatPriceCurve` returns `pure true` (`:304-306`).

Nothing couples the two. `setBondingCurveConfig` (`src/protocol/MultiVault.sol:824-827`) is a two-line `onlyTimelock`
assignment with no zero-address check, no `isCurveIdValid`, and no check that the incoming default curve is hookless.
The adjacent guard makes the coupling worse rather than better: `MultiVault_DefaultCurveMustBeInitializedViaCreatePaths`
(`:723-725`) **forces** new default-curve vaults through the create path, which is precisely the path that skips the
hook.

#### Proof of concept

Attacker sequence (governance-initiated, no attacker required):

1. Governance executes `setBondingCurveConfig({registry, defaultCurveId: <dynamic curve id>})` — a natural product step,
   since the fee curve is the flagship of this upgrade. The call succeeds; nothing reverts and nothing warns.
2. Any user calls `createAtoms`. `_createAtom` mints `sharesForReceiver` into
   `vaults[atomId][dynamicId].balanceOf[creator]` (`:1194`). On the curve, `userStake[atomId][creator]` remains `0` and
   `tierStake` is untouched.
3. The creator calls `redeem(...)`. `_validateRedeem` passes (the vault balance is real). `_calculateRedeem` resolves
   the hook because `hasRedeemFeeHook()` is `true`, and `quoteRedeemFee` falls back to `_tierOf(vaultAssets)` since the
   account has no tracked stake, returning a nonzero fee. `_recordCurveRedeem` (`:808`) then calls `recordRedeem`, which
   executes `userStake[termId][account] -= withdrawnStake` at `DynamicFeeFlatPriceCurve.sol:415` — **`0 - shares`,
   arithmetic underflow, panic `0x11`.** Line `:416` underflows identically.
4. **Assertion that fails:** the creator's principal is unredeemable. Reverting `defaultCurveId` does not heal it —
   those positions live at `(termId, dynamicId)` permanently, and every redeem there still routes through
   `recordRedeem`. Recovery requires a 7-day implementation upgrade of the curve.

This was reached independently by four of the six specialists and by the orchestrator, each from a different starting
point (ledger-mirror algebra, registry/state-machine analysis, external-call dispatch, and the delta regression pass).

#### Refutation attempted

- _Is there another unhooked mint path?_ No. `_mint` (`:1284-1288`) is reachable only from `_updateVaultOnCreation`,
  `_updateVaultOnDeposit`, and `_initializeOppositeTripleVault`; the last mints only to `BURN_ADDRESS`, whose shares are
  made permanently unredeemable by the minimum-remaining-shares check at `:1383-1386`. Vault shares are
  **non-transferable** — there is no `transfer` surface, and `balanceOf` is written only by `_mint` and `_burn`. So the
  mirror is maintained by construction for every path _except_ create-on-a-hook-curve.
- _Is it live today?_ No. The shipped configuration sets `defaultCurveId: 1`
  (`script/intuition/IntuitionDeployAndSetup.s.sol:398`), the hookless `LinearCurve`; the dynamic curve is registered
  under a separate id. **The finding is latent, not live-exploitable against the current deployment.**
- _Does the timelock make it acceptable?_ The accepted trust assumption covers privileged actors taking privileged
  actions. It does not cover a privileged action whose consequence is silent, permanent, and contradicts a documented
  interface invariant — the configuring transaction gives no signal at all.

#### Impact

Permanent, unrecoverable loss of user principal on every atom and triple created during the window, recoverable only by
a 7-day upgrade of the curve implementation.

#### Recommendation

Either close the gap at the setter or at the create path; the second is structurally cleaner.

- In `setBondingCurveConfig`, require `registry != address(0)`,
  `IBondingCurveRegistry(registry).isCurveIdValid(defaultCurveId)`, and
  `!IBaseCurve(curve).hasDepositFeeHook() && !IBaseCurve(curve).hasRedeemFeeHook()` for the incoming default curve.
- Or route `_createAtom` / `_createTriple` through `_depositFeeHookCurve` + `_recordCurveDeposit`, making the create
  path hook-symmetric with `_processDeposit` and honouring the `IBaseCurve` contract.

#### Regression test

`DefaultCurveHookSymmetry.t.sol` — point `defaultCurveId` at a hook curve, create an atom, and assert either that the
configuring call reverts (setter fix) or that a subsequent full redeem succeeds and the curve ledger matches the vault
balance (create-path fix).

#### Variant sweep

| Path                                                 | Result                                                            |
| ---------------------------------------------------- | ----------------------------------------------------------------- |
| Single create (`createAtoms` / `createTriples`)      | Same bug.                                                         |
| Batch create                                         | Same bug per element.                                             |
| On-behalf-of (`createAtomsFor` / `createTriplesFor`) | Same bug — they share `_createAtom` / `_createTriple`.            |
| Deposit                                              | Safe — `_processDeposit` invokes the hook at `:771`.              |
| Preview                                              | Safe — preview does not mint.                                     |
| Router (`FeeProxy`)                                  | Same bug when routing a create onto a hook-bearing default curve. |
| Upgrade initializer                                  | N/A.                                                              |

---

### R2-HMN-03 — `_setConfig` accepts a fee schedule that bricks every redeem on the curve

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:891`, `:894`, `:872-874`;
  `src/libraries/MultiVaultLib.sol:1067`, `:961-962`, `:1023-1024`; `src/protocol/MultiVault.sol:819-822`
- **Invariant broken:** §5.2 — solvency, in the sense that principal becomes temporarily unwithdrawable.
- **Attacker capability:** Curve owner. Note this is **not** behind a timelock (see R2-HMN-06).

#### Description

The curve quotes its fee on a **gross** base and `MultiVaultLib` subtracts it from an **already-net** amount. On redeem,
`hook.fee = quoteRedeemFee(termId, account, assets)` (`:1064`) is subtracted at `:1067` from
`assets - protocolFee - exitFee`. On deposit, `hook.fee` is quoted on `assetsAfterMinSharesCost` (`:961`, `:1023`) and
subtracted from `assetsAfterFees`, already reduced by the protocol, entry, and atom-wallet fees. All of these use
`mulDivUp`, so three independent ceilings can exceed the base even at an exactly 100% nominal sum.

`_setConfig` bounds only `depositCapBps <= BPS` (`:891`) and `withdrawalCapBps <= BPS` (`:894`). The real threshold is
strictly below `BPS`, because it must also leave room for MultiVault's own fees — and nothing couples the two
configuration surfaces. `MultiVault.setVaultFees` (`:819-822`) is a bare assignment with no cap validation at all.

Measured thresholds, by bisection through real `deposit` / `redeem` calls under the BaseTest fee set (protocol / entry /
exit = 100 bps each):

- **First withdrawal rate that reverts redeem: 9901 bps.**
- **First `depositCapBps` that reverts every deposit: 9800 bps.**

Critically, **no per-tier override is required**. A plain `setConfig(withdrawalBaseBps = withdrawalCapBps = 9901)`
passes all ten validation branches at `:876-898` — the top-edge probe at `:906` is orthogonal — after which **every
redeem on the curve reverts, for every vault and every tier**. The function's own NatSpec at `:872-874` states it exists
so that "a fat-fingered schedule cannot brick `tierOf` (and with it every deposit/redeem on the dynamic curve)"; the
validation does not deliver that for the fee fields.

#### Refutation attempted

- _Is it reachable at shipped values?_ No — shipped caps are 1000 bps on both sides
  (`script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:128`, `:133`), a wide margin below 9800/9901. Latent, not
  live.
- _Is it permanent?_ No. Recoverable by retune — **unless** ownership has been renounced (R2-HMN-10), in which case it
  is permanent. Principal is frozen, never lost.

#### Impact

A schedule the validator explicitly accepts freezes every holder's exit on the curve until an owner retune. Because the
curve owner is not timelocked, this can occur with no governance delay and no on-chain notice.

#### Recommendation

Validate the curve's caps against the wired MultiVault's live fee configuration — readable via
`IMultiVaultCore.getVaultFees()` and `getGeneralConfig()` from the stored `multiVault` — rejecting any cap that could
underflow. Alternatively, and more robustly, clamp `hook.fee` to the remaining net at `MultiVaultLib.sol:1067`, `:962`,
and `:1024` instead of subtracting blind.

#### Regression test

`CurveFeeCapCoupling.t.sol` — assert `setConfig` rejects a cap that, combined with the live vault fees, would underflow
the deposit or redeem net.

#### Variant sweep

Deposit and redeem both affected; atom and triple paths both affected; batch identical per leg; preview **not** affected
on the redeem side (see R2-HMN-09, which is why the discrepancy is easy to miss); `FeeProxy` inherits the deposit-side
revert.

---

### R2-HMN-04 — Per-tier fee overrides survive a reduction of the cap they were validated against

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:265-273`, `:811-819`, `:851-859`,
  `:875-911`; NatSpec at `:256-261` and `src/interfaces/IDynamicFeeFlatPriceCurve.sol:70-72`
- **Invariant broken:** Spec regression — a documented safety envelope is not enforced.

#### Description

`setTierFeeOverride` validates the override against `config.depositCapBps` / `withdrawalCapBps` **at set time only**
(`:267-269`). `_setConfig` (`:875-911`) contains no reference to `tierFeeOverride` and never re-validates or clears
existing entries. The read paths return the stored override **without re-applying the cap**:

```solidity
function _withdrawalFeeBps(uint256 tier) private view returns (uint256) {
    TierFeeOverride storage tierOverride = tierFeeOverride[tier];
    if (tierOverride.isSet) {
        return tierOverride.withdrawalFeeBps;   // :854 — returned raw, no min(cap, …)
    }
    uint256 fee = config.withdrawalBaseBps + tier * config.withdrawalGrowthBps;
    uint256 cap = config.withdrawalCapBps;
    return fee < cap ? fee : cap;               // the formula branch *is* clamped
}
```

`_depositFeeBps` (`:811-819`) has the identical shape. The interface NatSpec states overrides are "bounded by the
schedule's `depositCapBps` / `withdrawalCapBps`, so the override stays within the same envelope as the formula", and the
contract NatSpec at `:256-261` repeats it. Both are false after any cap reduction.

Proven by execution: with `withdrawalCapBps = 10000`, set `setTierFeeOverride(3, 100, 10000)`, then `setConfig` with
`withdrawalCapBps = 500`. `withdrawalFeeBps(3)` still returns **10000** against a live cap of 500, and a holder in tier
3 can no longer redeem. `clearTierFeeOverride(3)` restores it.

#### Refutation attempted

- _Does the cap bound the documented hazard?_ No. `:258-259` names the exact consequence — "a BPS-level withdrawal fee
  consumes the entire redeem and underflows `assets - fees` in MultiVault, bricking redeems for that tier" — and
  presents the cap as the mitigation. But `_setConfig` permits `withdrawalCapBps == BPS` (`:894`), so the hazard is
  reachable through the override path even without a retune, and through the formula path without any override at all
  (R2-HMN-03).
- _Recoverable?_ Yes, via `clearTierFeeOverride` (`:277-280`) — but only if someone notices, and only while an owner
  exists.

#### Impact

The routine, well-intentioned administrative action "tighten the withdrawal cap" silently leaves a stale,
now-out-of-envelope rate in force, up to and including a rate that bricks redeems for that tier.

#### Recommendation

One line closes both this and any future cap change: clamp at read time in `_depositFeeBps` / `_withdrawalFeeBps` with
`return FixedPointMathLib.min(stored, cap);`. Re-validating inside `_setConfig` closes only the retune case and leaves
the read path asserting an envelope it does not enforce.

#### Regression test

`TierOverrideCapClamp.t.sol` — set an override at the cap, lower the cap, and assert the effective rate is the new cap
rather than the stale override.

---

### R2-HMN-05 — `setBondingCurveConfig` replaces the registry pointer with no validation

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** C2 — `src/protocol/MultiVault.sol:824-827`; `src/libraries/MultiVaultLib.sol:833`,
  `:841`, `:1268-1279`; `src/protocol/curves/BondingCurveRegistry.sol:86-119`
- **Invariant broken:** §5.3.

#### Description

`BondingCurveRegistry` is strictly append-only and was verified so line by line across all 267 lines: `addBondingCurve`
(`:86-119`) is the only mutator, ids increment monotonically, an already-registered address is rejected (`:92-94`),
names are unique (`:104-106`), and there is no `delete`, no reassignment, and no `count` decrement anywhere. A curve id
can therefore never be reassigned **within** the registry.

`MultiVault.setBondingCurveConfig` defeats that guarantee one level up by replacing the whole struct — registry pointer
included — with no validation whatsoever. Since vault state is keyed `(termId, curveId)` and the curve is resolved
through the registry on **every** deposit and redeem (`:833`, `:841`), swapping the pointer re-maps every curve id at
once: existing vaults are repriced by a different curve, the dynamic curve's entire ledger and its custodied fee TRUST
are stranded at the old address, and the hook getters begin answering for a different contract. A codeless address
bricks the vault entirely, since every `_setVaultTotals` path calls into the registry.

#### Refutation attempted

Confirmed there is no compensating check: no zero-address guard, no `isCurveIdValid`, no `extcodesize`, and no
requirement that ids `1..oldCount` resolve identically in the new registry. Re-deploying a registry is routine
operations work, which is what makes this more than theoretical.

#### Recommendation

Validate both fields in the setter: non-zero, non-empty code, `isCurveIdValid(defaultCurveId)`, hookless default (which
also closes R2-HMN-02), and require every previously used id to resolve to the same address in the incoming registry —
or forbid changing `registry` once set.

#### Regression test

`BondingCurveConfigValidation.t.sol` — assert the setter reverts on a zero registry, a codeless registry, an invalid
default id, and a registry that remaps an in-use curve id.

---

### R2-HMN-06 — Mainnet deploy assigns curve ownership to the broadcasting EOA

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:80` (contrast `:58`, `:76`)
- **Invariant broken:** Trust boundary — the accepted trust assumption does not hold as deployed.

#### Description

The script correctly passes the real upgrades timelock (`0x321e5d4b20158648dFd1f360A79CAFc97190bAd1` on chain id `1155`)
as the **proxy admin** at `:76`, but passes `msg.sender` as the curve **owner** at `:80`:

```solidity
abi.encodeWithSelector(
    DynamicFeeFlatPriceCurve.initialize.selector,
    CURVE_NAME,
    msg.sender, // owner for the PoC; migrate to the parameters timelock / admin Safe in prod
    multiVaultAddr,
    _defaultConfig()
)
```

As written, the broadcasting EOA holds `setConfig`, `setTierFeeOverride`, `clearTierFeeOverride`, `sweepProtocol`, and a
live `renounceOwnership` on mainnet, with no timelock delay on any of them.

This matters beyond hygiene because it changes the risk rating of other findings. R2-HMN-03 and R2-HMN-04 are rated
Medium on the assumption that reaching a redeem-bricking state requires a timelocked governance action that observers
can see coming. Under this deployment they require one EOA transaction with no delay and no notice. `sweepProtocol` is
also more than a dust sink: `_payRecentTiers` routes **100%** of every deposit fee to `protocolAccrued` whenever the
vault sits in tier 0 (`:605-610`), which is the whole of every vault's early life.

#### Recommendation

Pass the parameters timelock or the admin Safe as `_owner` for chain id `1155`, matching how
`UPGRADES_TIMELOCK_CONTROLLER` is already resolved per chain at `:50-62`. Treat this as a pre-launch gate rather than a
code change.

#### Regression test

A deploy-script assertion that `_owner` is not `msg.sender` on a governed chain id.

---

### R2-HMN-07 — A retune with live positions silently re-targets the entire fee stream

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:237-247`, `:605-610`, `:621-624`,
  `:693-719`, `:753-763`, `:875-911`
- **Invariant broken:** Spec regression.

#### Description

Accumulators are index-keyed and deliberately not migrated on a retune — holders keep their numeric bucket ids while all
future tier decisions use the new schedule. The NatSpec at `:237-247` asserts that "solvency can never be impacted by a
retune". That is literally true and was verified: no accounting term is a function of `config`, `earned` is untouched,
and every credit floors. But solvency is the only property asserted, and the omission is material.

Raising `width0` can collapse `_tierOf(vaultAssets)` to 0, at which point `_payRecentTiers` short-circuits at `:605-610`
and routes **100% of every deposit fee to `protocolAccrued`** — sweepable by the owner — for as long as it takes vault
TVL to re-climb the new ladder. Lowering `width0` far enough pushes `_tierOf` to the top tier, after which the kernel
window (`σ = 4` at shipped values) misses every occupied bucket, `sumWeights` is zero, and `_awardNearestOrProtocol`
concentrates **100% of every deposit fee onto a single bucket** indefinitely. In both cases holders' exit rates also
diverge: `quoteRedeemFee` (`:327`) keys existing holders on their stale `userTier` while a fresh depositor records a
bucket under the new schedule, so two holders in the same vault at the same TVL can face materially different withdrawal
rates.

#### Refutation attempted

Every other NatSpec claim in the block was checked and holds: bucket ids are preserved, accumulators are not migrated,
booked and pending earnings are unaffected, and the grow-only `tierCount` rule genuinely prevents stranding — in fact
`_roundTier`'s cap at `:864` can never bind, because `userAvgTier` is a convex combination of already-capped `_tierOf`
outputs under a monotone `tierCount`.

#### Recommendation

Amend the NatSpec at `:242` — solvency is not the property a reader needs assured. Consider bounding `width0` /
`growthGBps` deltas per call, or requiring a retune to preserve `_tierOf(vaultAssets)` within ±1 for a supplied list of
live terms.

#### Regression test

`TierRetuneLivePositions.t.sol` — assert that after a retune, deposit fees still reach holder tiers rather than
collapsing entirely into `protocolAccrued` or onto one bucket.

---

### R2-HMN-08 — Rotating the EntryPoint re-derives every AtomWallet address

- **Severity / Confidence / Status:** Medium / Medium / Open
- **Cluster + affected code:** E — `src/protocol/wallet/AtomWalletFactory.sol:144-161`, `:125-133`;
  `src/protocol/MultiVault.sol:746-751`, `:807-816`

`_getDeploymentData` folds the live `walletConfig.entryPoint` into the beacon proxy's `initData`, hence into the
init-code hash, hence into the CREATE2 address. Rotating the EntryPoint via `setWalletConfig` therefore re-derives the
deterministic address for **every atom**. A claimed, live wallet is orphaned from its fee-claim identity —
`MultiVault.claimAtomWalletDepositFees` recomputes the address and rejects the old wallet at `:749-751` — and a second,
unclaimed wallet for the same atom becomes permissionlessly deployable and claimable. Timelock-gated, so it may be
intended to sit inside the accepted admin bucket; flagged because the consequence is materially worse than a typical
parameter change and is silent.

**Recommendation:** exclude the EntryPoint from the CREATE2 salt/init-code derivation, or document the rotation as a
migration requiring wallet redeployment.

---

### R2-HMN-09 — `previewRedeem` does not reproduce the fee an actual redeem charges

- **Severity / Confidence / Status:** Medium / High / Open
- **Cluster + affected code:** C2 — `src/libraries/MultiVaultLib.sol:443`, `:794`, `:1388`;
  `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:321-329`

`calculateRedeem` passes `address(0)` as the account (`:443`), so `quoteRedeemFee` takes its no-stake fallback and keys
on `_tierOf(vaultAssets[termId])` — the **vault's current tier**. An actual redeem passes `receiver` (`:794`) and keys
on **the holder's own entry tier**. Because the withdrawal rate is `withdrawalBaseBps + tier * withdrawalGrowthBps`,
these diverge whenever the vault has moved since the holder entered, which is the normal case. The fallback also misses
any per-tier override, so a preview can return a passing quote for a tier whose real rate bricks the redeem (R2-HMN-04).

Before this upgrade the preview and write paths computed the identical number by construction — the account parameter
did not exist. `IMultiVault.previewRedeem` still documents its return as "the net assets that would be sent to the
user".

Slippage protection itself is **not** compromised: `_validateRedeem` calls `_calculateRedeem` with the real account
(`:1388`). The impact is on integrators deriving `minAssets` from `previewRedeem`, who will see spurious
`MultiVault_SlippageExceeded` reverts or, in the opposite direction, set an ineffective bound. `previewDeposit` is
unaffected — `quoteDepositFee` takes no account.

**Recommendation:** add an account-aware preview, or document the account-less fallback explicitly in the `IMultiVault`
NatSpec.

---

### R2-HMN-10 — `renounceOwnership` is live on the fee custodian and the registry

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:78`, `:285`;
  `src/protocol/curves/BondingCurveRegistry.sol:25`; contrast `src/protocol/wallet/AtomWallet.sol:273`

Neither the curve nor the registry overrides `renounceOwnership`. `Ownable2Step` does not help: `renounceOwnership`
calls `_transferOwnership(address(0))` directly, bypassing the two-step handshake, so it is single-step and
irreversible. Renouncing on the curve permanently strands `protocolAccrued` (only `sweepProtocol`, `onlyOwner`, can move
it) and freezes `setConfig` and `clearTierFeeOverride` — which are the recovery levers for R2-HMN-03, R2-HMN-04, and
R2-HMN-07, turning each from temporary into permanent. Renouncing on the registry permanently freezes curve
registration.

The repo already establishes the fix as its own convention at `AtomWallet.sol:273`; these two contracts diverge from it.
**Recommendation:** `function renounceOwnership() public pure override { revert(); }` on both.

---

### R2-HMN-11 — Inherited `BaseAccount.executeBatch(Call[])` is not overridden

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** E — `src/protocol/wallet/AtomWallet.sol:198-216`;
  `lib/account-abstraction/contracts/core/BaseAccount.sol:62-77`

`AtomWallet` declares `executeBatch(address[],uint256[],bytes[])` with `onlyMultiOwnableOwnerOrEntryPoint` and
`nonReentrant`, but this is a _different signature_ from the inherited `BaseAccount.executeBatch(Call[])`, which
therefore remains live as a second selector carrying neither modifier — only `_requireFromEntryPoint()`.
(`BaseAccount.execute` **is** properly overridden at `:182`; only the batch overload leaks.)

Not an authorization bypass — reaching it still requires a UserOp that passed `_validateSignature` with a valid owner
signature — but it is a reentrancy-guard bypass and an access-control inconsistency between two identically named
surfaces. It is also currently the de facto workaround for the shared-guard collision noted in §5.17, so removing it
without providing another route would tighten that trap.

**Recommendation:** override `executeBatch(Call[])` to revert, or apply the same modifiers.

---

### R2-HMN-12 — `claim` has no recipient parameter, so a reverting holder strands earnings permanently

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:459-476`, `:285-292`

`claim` pays `Address.sendValue(payable(msg.sender), amount)` (`:474`) with no `claimTo(address)` alternative. A
contract holder whose `receive()` reverts can never withdraw its earnings, and the value is **not** recoverable by
`sweepProtocol`, which only pays out `protocolAccrued`. The same holder also cannot redeem principal out of
`MultiVault`, so its stake remains in every co-tier denominator (`:424`, `:673`) forever, permanently diluting the other
occupants of that tier. Verified by execution: a reverting-receiver contract accrued earnings, `claim` reverts
permanently, and the value is unrecoverable by any admin path.

Self-inflicted and uneconomic — the holder burns its own principal — but permanent, with collateral dilution of innocent
co-tier holders. **Recommendation:** add `claim(bytes32[] calldata, address to)` or an owner rescue path.

---

### R2-HMN-13 — Chunking a deposit is cheaper than lumping it and yields a better bucket

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** C1 — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:309-313` (the claim), `:315`,
  `:828-848`, `:390`

The NatSpec at `:309-313` states that piecewise pricing exists so that "lumping was strictly cheaper than chunking — a
regressive discount for exactly the depositors who move the vault the most" is no longer true. The inversion is not
complete. `_piecewiseDepositFee` advances its `cursor` by the **fee base**, while `vaultAssets` advances between
transactions by only `netStake` (`:390`) — lower by MultiVault's 225 bps plus the curve fee. Since the rate is
non-decreasing in the cursor, the chunked walk integrates over a strictly lower domain, so `fee_chunked <= fee_lumped`
always.

Worked example at the shipped schedule, vault at 64,000 TRUST, deposit 40,000: lumped 1,904.652736 TRUST versus two
20,000 chunks at 1,904.62528 — chunking is 0.027 TRUST cheaper, about 0.0014%.

The fee difference is negligible; the **bucket** difference is not. The lump books `_tierOf(64,000) = ` bucket 6, while
the chunked pair averages to 6.997 and rounds to bucket 7. With the vault ending at tier 8, bucket 7 sits at `d = 1`
(weight 0.75) and bucket 6 at `d = 2` (weight 0.50) — **1.5× the kernel weight for the same capital, at a lower fee.**
Chunking weakly dominates on fee and strictly dominates on placement, so the naive large depositor still overpays and
under-earns relative to the sophisticated one. This compounds R2-HMN-01.

**Recommendation:** advance the walk cursor over the post-fee net, or accept and document the residual.

---

### R2-HMN-14 — ECDSA signature encodings are non-unique on the AtomWallet surfaces

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** E — `src/libraries/CoinbaseSmartWalletLib.sol:146`; contrast
  `src/protocol/wallet/AtomWarden.sol:588-592`

Solady's `SignatureCheckerLib` does not enforce low-`s`. High-`s`, EIP-2098 compact 64-byte, and trailing-padded
wrappers all validate, so a single authorization has three or more distinct valid byte encodings on **both** the
ERC-1271 and the ERC-4337 surface. Only exploitable by integrations that key replay protection off signature bytes
rather than the digest. Worth noting that `AtomWarden` takes the opposite approach and **does** reject high-`s` via
OpenZeppelin's `ECDSA.tryRecover` — the inconsistency between the two contracts is itself a source of integrator
confusion.

---

### R2-HMN-15 — Hook-getter symmetry is not enforced at registration and there is no cross-transaction latch

- **Severity / Confidence / Status:** Minor / Medium / Open
- **Cluster + affected code:** C2 — `src/libraries/MultiVaultLib.sol:832-843`, `:851-865`;
  `src/protocol/curves/BaseCurve.sol:153-160`; `src/protocol/curves/BondingCurveRegistry.sol:86-119`

Within a transaction the dispatch is **structurally** safe, and this is worth stating precisely because it is easy to
assume otherwise: each getter is consulted exactly once per operation (`:959` / `:1021` / `:1062`), and both the boolean
decision and the fee quote are carried in the `CurveHook` struct to the record call (`:771`, `:808`). A curve whose
getter flips mid-transaction therefore cannot produce a quote-without-record or a record-without-quote.

What is unprotected is the cross-transaction case. Nothing latches the decision per `(termId, curveId)`, and the two
getters are independent. A curve that reports a deposit hook but not a redeem hook accrues `userStake` that is never
decremented, so exited holders keep earning on burned shares — a direct insolvency of the curve's custody. The mirror
case produces the R2-HMN-02 underflow. `addBondingCurve` does not probe the getters at all, and registration is
permanent.

**Recommendation:** require `hasDepositFeeHook() == hasRedeemFeeHook()` at registration, or latch the decision per vault
on first record; and document the getters in `IBaseCurve` as required to be constant.

---

### R2-HMN-16 — The gas ceiling regression test does not bound the configuration space `setConfig` permits

- **Severity / Confidence / Status:** Minor / High / Open
- **Cluster + affected code:** C1 — `tests/unit/MultiVault/DynamicFeeGasProfile.t.sol:18`;
  `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:875-911`, `:103`, `:106`

Measured, optimized profile, end-to-end through `MultiVault`:

| Scenario                                               | Deposit                | Redeem  |
| ------------------------------------------------------ | ---------------------- | ------- |
| Hookless curve (baseline)                              | 88,589                 | 85,001  |
| 5-tier default config, sparse (what the test measures) | 115,989 (+29,557)      | 180,583 |
| **13-tier shipped schedule, all tiers occupied**       | **267,095 (+178,506)** | 150,533 |
| 64-tier, `σ = MAX_KERNEL_SPREAD`, warm                 | 601,154 – 728,324      | 369,135 |
| 64-tier, 63 cold accumulator writes                    | **2,003,553**          | —       |

The test declares `MAX_DEPOSIT_OVERHEAD = 200_000` but never calls `setConfig`, so it measures the 5-tier default at
sparse occupancy with 6.8× headroom. The shipped 13-tier schedule at full occupancy leaves 11% headroom, and the
admin-reachable 64-tier configuration exceeds the declared ceiling by 2.6× warm and 9.6× cold. No configuration bricks a
deposit at a 30M block limit, so this is test debt rather than a liveness break — but `tierCount` is **grow-only**
(`:882-884`), so a gas-regrettable widening cannot be undone.

**Recommendation:** parametrize the ceiling test at `tierCount = MAX_TIER_COUNT` and `kernelSpread = MAX_KERNEL_SPREAD`.

---

### 5.17 Informational

| #    | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                             | `file:line`                                                                            |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| I-01 | `_creditByWeight` books `assigned += share` even when the accumulator bump floors to zero, so that slice reaches neither a holder nor `protocolAccrued` and is unrecoverable by any path. Bounded by `stakes/1e18` — **the same bound as the accepted per-share dust** — and requires `tierStake > pool·1e18` (≥1e32 wei), so unreachable in production. Direction is conservative: it strengthens solvency. Filed only for the recoverability gap. | `DynamicFeeFlatPriceCurve.sol:646-652`, `:627-631`                                     |
| I-02 | Record hooks carry no `nonReentrant`; correctness rests entirely on the settle-then-distribute-then-rebase ordering. Traced and sound today, but any future edit moving a distribution above its `_settle`, or adding an external call inside a record hook, converts this to a live double-credit.                                                                                                                                                 | `DynamicFeeFlatPriceCurve.sol:339`, `:401`, `:348-349`, `:358`, `:389`, `:414`, `:448` |
| I-03 | `rewardDebt` floors at `:389` / `:448` while `accumulated` floors at `:532`, permitting ≤1 wei of over-credit per user per stake-change interval — dominated roughly 1000:1 by the stranded per-distribution dust.                                                                                                                                                                                                                                  | `DynamicFeeFlatPriceCurve.sol:389`, `:448`, `:532`                                     |
| I-04 | `protocolAccrued` is documented as "dust" but receives **100%** of every deposit fee while a vault sits in tier 0.                                                                                                                                                                                                                                                                                                                                  | `DynamicFeeFlatPriceCurve.sol:74`, `:282`, `:605-610`                                  |
| I-05 | Utilization is stale-high during the receiver payout at `MultiVaultLib.sol:810`; safe only because every current reader keys on a past epoch. Any future reader keyed on the current epoch becomes exploitable through this window.                                                                                                                                                                                                                 | `MultiVaultLib.sol:810`, `:299`, `:338`; `TrustBonding.sol:607-608`                    |
| I-06 | `clearTierFeeOverride` has no `tier < tierCount` bound while `setTierFeeOverride` does; harmless given grow-only `tierCount`, but emits a misleading event.                                                                                                                                                                                                                                                                                         | `DynamicFeeFlatPriceCurve.sol:277-280` vs `:266`                                       |
| I-07 | `_setConfig` does not verify strict edge monotonicity; a non-monotonic ladder would make `_piecewiseDepositFee` spin. Covered by fuzz and by the geometric-series derivation, not by an on-chain guard.                                                                                                                                                                                                                                             | `DynamicFeeFlatPriceCurve.sol:875-906`, `:834-847`                                     |
| I-08 | `claimType` is signed into the `ClaimAuthorization` typehash but never validated on-chain — the distinction is off-chain policy only.                                                                                                                                                                                                                                                                                                               | `AtomWarden.sol:43`, `:634`                                                            |
| I-09 | `AtomWallet.addOwnerAddress` accepts `address(0)`: burns an owner index and inflates `ownerCount` while being unable to authenticate.                                                                                                                                                                                                                                                                                                               | `AtomWallet.sol:385-387`                                                               |
| I-10 | A co-owner can evict the primary owner via `transferOwnership`, even though `removeOwnerAtIndex` blocks the direct route. Documented as intended, but "add a co-signer" does not obviously imply "grant the ability to remove yourself".                                                                                                                                                                                                            | `AtomWallet.sol:245-267`, `:405-406`                                                   |
| I-11 | `claimAtomWalletDepositFees` shares `nonReentrant` with `execute` / `executeBatch`, so a nested `execute → self` call reverts. Fees are not strandable (three independent routes exist) but it is a trap for SDKs that funnel everything through `execute`.                                                                                                                                                                                         | `AtomWallet.sol:316-318`, `:311-314`                                                   |
| I-12 | Test coverage gaps on the §5 invariants — see §6.3.                                                                                                                                                                                                                                                                                                                                                                                                 | —                                                                                      |

---

## 6. Properties checked (negatives)

Each entry records a property that held **and** the refutation that was attempted against it. A pass with no attempted
refutation is not recorded as a pass.

### 6.1 Invariants

**§5.1 Conservation of value — PASS.** Derived algebraically for all three exclusion cases. Deposit with
`newTier != oldTier`: the accumulator is bumped by `floor(F·P/S)` against a denominator `S` that omits the depositor,
and `:378` then removes exactly `oldStake` from that tier, so the surviving members' summed claim is `F − r/P` with
`r ∈ [0,S)`. Deposit with `newTier == oldTier` — the adversarial case, where `tierStake` **grows** at `:382` after the
bump — the depositor's term collapses to exactly zero because `:389` re-bases with the identical
`fullMulDiv(stake, acc, P)` form used at `:532`; instantiated numerically and confirmed to the wei (`399999999999999996`
against a `4e17` target, with the 4-wei residual matching `r/P` exactly). Redeem: the exiting tier can receive two bumps
(`:427` and via `:649`) but both use the same post-`:416` denominator and the exiter is re-based once at `:448` against
the final accumulator, which nullifies both because pending is linear in `acc`. Every branch of `_payDepositFee`
(`:549-571`) and `_payRecentTiers` (`:599-632`) was enumerated and sums to exactly `pool`; the `else` at `:565` folds
the spike into the fulcrum pool in a mutually exclusive branch, so there is no double-add. _Tried:_ farming by repeated
settling (telescopes — N settles pay identically to 1); skipping a settle by tier-hopping (every `userStake`/`userTier`
write is preceded by a settle at the old tier); driving `accumulated < debt` (impossible — `accFeePerShare` is `+=`-only
and every debt write uses the same floor form on the same pair).

**§5.2 Solvency — PASS.** Inflows are exactly `msg.value` at `:340` and `:407`; outflows are `claim` (`:474`) and
`sweepProtocol` (`:290`), both zeroing state before the send and both `nonReentrant`. Every credit floors, so
`Σ(earned + pending) ≤ Σ(credited) ≤ Σ(received)`. Measured on a live probe: balance `279,074,999,999,980,175` against
`protocolAccrued 64,999,999,999,985,000` plus `Σclaimable 214,074,999,999,995,160`; after a full sweep all three holders
still claimed successfully with 15 wei of residual dust. _Tried:_ making a sweep starve a later claim — refuted,
`protocolAccrued` is credited only from slices never added to any accumulator (`:607`, `:629`, `:716`). _Tried:_ a
`sweepProtocol` revert leaving state zeroed — refuted empirically, the revert unwinds the zeroing and the subsequent
sweep pays the full amount.

**§5.3 Curve ledger mirrors vault shares — PASS, conditional on R2-HMN-02.** `userStake` is written only at `:385` /
`:415` and `tierStake` only at `:378` / `:380` / `:382` / `:416`, and every branch pairs them — including the re-entry
case where a fully-exited user re-deposits with a stale `userTier`, which is safe because `oldStake == 0` makes
`newStake == netStake` so both branches credit identically, and the `if (oldStake > 0)` guard at `:377` suppresses the
only subtraction that would read the stale bucket. Vault shares are non-transferable, and `_mint` is reachable only from
the three update helpers. _Tried:_ desyncing via share transfer (no transfer surface exists); via `BURN_ADDRESS`
min-share seeding (those shares are made unredeemable by `:1383-1386`); via a retune (`_setConfig` writes only
`config`); via `tierCount` growth un-capping a previously capped bucket (refuted — `_roundTier`'s cap can never bind).
The one path that **does** break it is the create path on a hook-bearing default curve, filed as R2-HMN-02.

**§5.4 Flat-price par — PASS, for a non-obvious reason worth recording.** `LinearCurve` is **not** a hardcoded 1:1
curve: it is pro-rata (`assets · totalShares / totalAssets`, `LinearCurve.sol:156-173`), and its own NatSpec says share
value rises through fee accumulation. Price would leave par if assets were added without minting shares — and entry
fees, exit fees, and the atom-deposit fraction are added exactly that way. The reason par holds is that
`_increaseProRataVaultAssets` hardcodes `s.bondingCurveConfig.defaultCurveId` (`MultiVaultLib.sol:1088`), so those
donations land in the **default** curve's vault, never the dynamic curve's own. Creation seeds both sides equally
(`_minAssetsForCurve` = `previewMint(minShare,0,0)` = `minShare`), and `fullMulDiv(x,k,k) == x` keeps the induction
exact through every deposit and redeem. So `totalAssets ≡ totalShares` for the dynamic vault at every reachable state
and `vaultAssets ≡ totalAssets − minShare`. **This is load-bearing and undocumented as a safety property** — if the
dynamic curve ever became the default, par would break in addition to R2-HMN-02. Contested during the round: one
specialist reported systematic drift from these donations; adjudicated against it by direct source read of `:1088` and
by two other specialists' independent derivations.

**§5.5 Storage-layout upgrade-safety — PASS.** Verified against live `forge inspect` output rather than by inspection:
all 38 fields of `MultiVaultLib.Storage` (`:97-150`) match `MultiVault`'s layout in order, type, slot, and packing, from
slot 0 `totalTermsCreated` through slot 34 `timelock` to slot 37 `lastSystemUtilizationEpoch`. `_s()` resolving
`s.slot := 0` is correct because MultiVault's OZ v5 bases are ERC-7201-namespaced and consume no sequential slots. The
library omits the trailing `__gap` — harmless, it is the tail.

**§5.6 No `msg.value`-replay hazard in `multicallPayable` — PASS.** `sum(values) == msg.value` is enforced with
**checked** arithmetic (`total += values[i]` at `:607` sits outside the `unchecked` block), so a crafted `values` array
cannot overflow into a small total; the comparison is equality, not `<=`, so no residue is left unattributed. Array
lengths are matched (`:593`), sub-4-byte calldata is rejected (`:598`), and the selector allowlist (`:600-605`) is
exactly the six payable entry points. An exhaustive grep confirms raw `msg.value` appears in executable code in exactly
two places — the outer sum check (`:612`) and the fallback branch of `_effectiveMsgValue` itself (`:640`); every one of
the six forwards reads `_effectiveMsgValue()`, and `MultiVaultLib` never reads `msg.value` at all. _Tried:_ the
double-spend — a curve record hook re-entering a payable entry point while `_virtualMsgValue` is set, which would credit
`V` wei for a 0-wei call. Blocked, and the sufficient condition holds exhaustively: every function that reads
`_effectiveMsgValue()` is `nonReentrant`. _Tried:_ leaving transient state set via a swallowed revert — refuted;
EIP-1153 TSTORE is rolled back with the frame, and every non-reverting exit path clears both flags. _Tried:_ nesting —
rejected at `:516` and `:592`; canonical `multicall` additionally pins `_virtualMsgValue = 0`, so a payable leg composed
inside it credits zero.

### 6.2 Cluster properties

- **Quote-then-record equality — PASS.** The fee is quoted once at `:961` (atom), `:1023` (triple), and `:1064` (redeem)
  and forwarded as the identical struct member at `:855` / `:864`. The two deposit quote sites were checked against each
  other and agree. The hook is never re-resolved or re-quoted after the vault-state writes, so `netted == forwarded`
  holds by dataflow, not by convention.
- **Hookless no-op parity — PASS.** `BaseCurve` returns `false` on both getters and reverts on all four hook functions
  (`:153-181`); `hook.curve == address(0)` short-circuits at `:854` / `:863` with `hook.fee` zero, so no call is made
  and no value moves. Byte-identical to pre-upgrade behaviour for `LinearCurve`, `ProgressiveCurve`, and
  `OffsetProgressiveCurve`.
- **Reentrancy through the record hooks — PASS.** The guard is OZ 5.4.0 `ReentrancyGuardUpgradeable` (SSTORE-based,
  contract-wide), and `MultiVaultLib` runs under it via `delegatecall`. Every other external call in the write path is a
  `STATICCALL`; the only non-static untrusted targets are the two record hooks and the receiver payout. _Tried:_ the
  cross-guard route — `claim`'s `sendValue` re-entering `MultiVault.deposit` → `recordDeposit`, which has no
  `nonReentrant` of its own. Traced step by step: `_settle` at `:349` is a no-op because `claim` already re-based
  `rewardDebt` at `:537`; the depositor is excluded from their own fee at `:674-676` and re-based post-distribution at
  `:389`; and the outer payout amount was fixed in a local at `:470` before the zeroing. No double-pay. The same route
  through `sweepProtocol` and through `recordRedeem` was checked and is likewise safe.
- **Registry integrity — PASS.** Append-only across all 267 lines; no `delete`, no reassignment, no `count` decrement.
  `curveAddresses[id]` is write-once. The break is at the MultiVault setter (R2-HMN-05), not in the registry.
- **`AtomWarden` quorum — PASS.** The ordering check is `if (recovered <= previous) revert` (`:593`), which is the
  **strict** form: a duplicated signer reverts, not merely an out-of-order one. _Tried:_ concatenating one valid
  signature three times to fake a 3-of-3 — defeated at `:593`. Every segment must independently recover and hold
  `SIGNER_ROLE` at execution time, so a revoked signer's segment reverts and a raised threshold reverts. ERC-1271
  contract signers cannot occupy a quorum slot at all — the path uses `ECDSA.tryRecover` only. Replay is closed across
  atoms (`atomId` in the struct), chains (chainId in the domain), nonces (`:294-296`, incremented before the external
  call), and domain version (bumped to `"2"`).
- **`AtomWarden` per-window cap — PASS.** `_setClaimCapWindow` (`:713-721`) writes only `claimCapWindow` and re-anchors
  the window id; it contains **no** write to `claimsInWindow`. _Tried:_ exhausting the cap then widening the window to
  mint fresh budget — count survives, next claim still reverts. _Tried:_ chained retunes in one block — count survives
  all three. The residual is that a _narrowing_ retune releases budget one tick later, which is a genuine but
  timelock-gated limitation of the preservation property. Cap-disabled (`0`) semantics freeze both fields and cannot
  mint budget; the divisor is never reached because a nonzero cap cannot be enabled while the window is zero.
- **`AtomWallet` claim/deploy ordering — PASS.** The CREATE2 address commits to the init-code hash, so an attacker
  deploying "first" merely does the honest user's work. Pre-claim the MultiOwnable registry is empty and cannot be
  seeded — `addOwnerAddress` requires an existing owner or a self-call, and a UserOp cannot bootstrap it because
  `_validateSignature` fails against an empty registry.
- **Tier math and config bricking — PASS.** `_piecewiseDepositFee`'s `room > 0` assertion holds by induction on strictly
  increasing edges, and termination does not depend on it because `tier` increments unconditionally and the top tier
  absorbs the remainder. `tierCount == 0` is unreachable post-init. Confirmed by an 800-run × 24-operation adversarial
  fuzz that retuned `setConfig` with a random legal schedule between **every** deposit and redeem, asserting no
  `Panic(0x11)` escapes and that every actor can still fully exit and claim: **0 failures**.
- **Accumulator overflow — PASS.** A sole 1-wei holder inflates `accFeePerShare` fastest; overflow needs
  `stake · acc > 2^256`. With lifetime fees bounded by native supply, that requires a ~1e14 TRUST position — unreachable
  by roughly five orders of magnitude.

### 6.3 Test-coverage observations

The existing curve suites are substantial but do not pin the §5 invariants tightly. §5.1 is asserted only with
**absolute** hard-coded slacks (100 and 1000 wei) that do not scale with tier stake, and no test books stranded dust as
an explicit term — so I-01 is structurally invisible to it. §5.2's invariant uses `assertGe` only, which passes
precisely _because_ value leaks and cannot distinguish "solvent" from "leaking"; `sweepProtocol` is absent from the
handler. §5.3's two sum identities — `Σ tierStake == vaultAssets` and `vaultAssets == totalAssets − minShare` — are
asserted **nowhere**, and adding them would both machine-check the derivation in §6.1 and catch R2-HMN-02. §5.4's price
half is asserted but the max-loss half is not. Both `*ToRecentShareBps` splits are zero in every config in the repo and
the invariant handler's retune mutates only the two base rates, so the deposit spike branch and the withdrawal split are
never stateful-fuzzed. Handler deposits are bounded such that most sequences never leave tiers 0–1, leaving the
multi-tier kernel and the degenerate branch effectively unfuzzed.

---

## 7. Verification of previously landed fixes

Both were verified by **executed** mutation-check, not by inspection. Source was restored afterwards and
`git status --porcelain src/` confirmed empty.

### 7.1 ERC-1271 replay-safe digest binding — VERIFIED, mutation-check RED

`isValidSignature` (`src/protocol/wallet/AtomWallet.sol:335-342`) wraps the supplied digest via
`CoinbaseSmartWalletLib.replaySafeHash(hash, "AtomWallet", "1")` before validation. The envelope is a full EIP-712 hash
whose domain includes **both `block.chainid` and `address(this)`** (`CoinbaseSmartWalletLib.sol:311-321`), read live on
every call rather than cached, so a chain fork or a different wallet instance immediately re-derives the separator.

_Attacked:_ the `validateUserOp` / `isValidSignature` asymmetry — `_validateSignature` (`:485-494`) does **not** apply
the envelope, using the personal-sign prefix over `userOpHash` instead. Verified this is correct rather than a gap,
against the actual submodule (EntryPoint **v0.8.0**): `getUserOpHash` is itself an EIP-712 hash over a domain containing
chainId and the EntryPoint address, and `UserOperationLib.encode` places `sender` first — so the digest is already bound
to sender, chain, EntryPoint, nonce, and calldata. Cross-surface collision is structurally impossible because the two
preimages differ at byte 1 (`0x19 0x01` versus `0x19 0x45`). _Attacked:_ a P-256/WebAuthn versus ECDSA divergence —
refuted, both branches receive the same single `hash` argument; there is only one hashing site. _Attacked:_ the same
wallet address on two chains, reachable via deterministic factory deployment — defended by the live `block.chainid` in
the separator. _Attacked:_ a legacy fallback accepting the old format — none exists; `replaySafeHash` is applied
unconditionally and the library is reached from exactly two places.

**Mutation-check (executed):** replacing `replaySafeHash(hash, …)` with the raw `hash` at `:336` turns **8 committed
tests red** in `tests/unit/security/v1.1.0/AtomWalletAuthEdges.t.sol`, including `test_index0PrimaryOwnerValidates` and
`test_postTransferOwnership_newOwnerValidates`, each failing with `0xffffffff != 0x1626ba7e`. The fix is genuinely
guarded. Residual noted as R2-HMN-14 and, separately, that the committed suite pins the happy path ("envelope works")
more strongly than the security property ("bare digest must be rejected").

### 7.2 Zero epoch length rejected — VERIFIED, mutation-check RED

`_validateEmissionsLength` (`src/protocol/emissions/CoreEmissionsController.sol:129-133`) is called first in the shared
initializer at `:54`. An exhaustive grep confirms the initializer has exactly two callers —
`BaseEmissionsController.sol:78` and `SatelliteEmissionsController.sol:74`, both inside once-only `initializer`
functions — and that `_EPOCH_LENGTH` has exactly **one write site**, inside that guarded initializer. There is no
setter, no `reinitializer` anywhere in the emissions directory, and therefore no bypass. `TrustBonding` does not share
the initializer; its separate epoch-length parameter feeds `VotingEscrow`, which enforces the strictly stronger
`min_time >= 2 * WEEK`.

_Attacked:_ other degenerate values. `1` passes and behaves consistently; `type(uint256).max` passes and freezes the
schedule at epoch 0, with `_calculateEpochTimestampStart` reverting on checked overflow rather than wrapping to a bogus
timestamp. Only `0` is a true failure mode, and it is now closed.

**Mutation-check (executed):** neutering the guard turns **both** gating tests red —
`tests/unit/CoreEmissionsController/Reads.t.sol::test_initialize_revertsWhenEmissionsLengthIsZero` and
`tests/unit/SatelliteEmissionsController/AccessControl.t.sol::test_initialize_revertsWhenEmissionsLengthIsZero` — each
with "call did not revert as expected". Noted as a coverage gap: there is no equivalent test on
`BaseEmissionsController.initialize`, so that controller's own initializer is unguarded by test even though the shared
call site is covered twice.

---

## 8. Delta since the previously reviewed commit

`git diff b52557b..HEAD -- src/` is 30 files, +1537/−875. Comparing against a whitespace-ignoring diff shows roughly
**95% of the raw delta is a formatting profile change**; the true semantic surface was isolated by stripping formatting
and comment-only hunks per file.

Verified clean: `MultiVault.sol` (NatSpec only; the `reinitialize` body is byte-identical to `b52557b`), `FeeProxy.sol`
(**zero** semantic change — all 78 lines are formatting), `IMultiVault.sol` (formatting and NatSpec only, with
`ApprovalTypes` and `VaultType` byte-identical, so no previously granted approval changes meaning),
`IBondingCurveRegistry.sol`, `ITrustBonding.sol` (a NatSpec correction — ratios were documented as 1e18-scaled but are
and always were basis points), `MultiVaultCore.sol` (sole change is the removal of a `_getTriple` whose only caller
retains identical semantics), the four curve files, and the emissions files. `CoreEmissionsController.sol`'s addition is
strictly narrowing.

The fee-application ordering in `_processDeposit` and `_processRedeem` is unchanged; the only insertions are the two
record-hook calls, both strictly after the vault-state writes and, on redeem, before the receiver payout — correct CEI
under a `nonReentrant` outer frame. The `isNew` / `isDefault` stack collapse is provably equivalent. No `unchecked`
block or narrowing cast was added anywhere outside the new curve, where every `unchecked` is a loop counter bounded by
`tierCount <= MAX_TIER_COUNT`.

Semantic changes reaching findings above: the curve fee-hook layering (R2-HMN-03, R2-HMN-09), the `_calculateRedeem`
account parameter (R2-HMN-09), the `isValidSignature` envelope (§7.1, R2-HMN-14), and the `BaseCurve` hook surface,
which introduces a **sequencing requirement**: every registered curve must be upgraded in the same timelock batch as
`MultiVault`, because the dispatch calls `hasDepositFeeHook()` on each registry-resolved curve and a pre-v1.1.0
implementation lacks that selector. That mitigation is present and explicit in
`script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:41-50`, which ships both curve upgrades in the same
batch and asserts the registry holds exactly those two curves. It is a Safe-batch convention rather than an on-chain
invariant, and it silently expires the moment a third curve is registered — recorded as Informational.

---

## 9. Cluster verdicts

| Cluster                                         | Scope                                                                                                                                                                      | Verdict                                                                                                                                                     |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **C1** — `DynamicFeeFlatPriceCurve` fee economy | `protocol/curves/DynamicFeeFlatPriceCurve.sol`, `interfaces/IDynamicFeeFlatPriceCurve.sol`                                                                                 | **VERDICT: FAIL** — R2-HMN-01 (Major) plus four unresolved Medium findings on a funds path.                                                                 |
| **C2** — `IBaseCurve` hook surface and dispatch | `interfaces/IBaseCurve.sol`, `protocol/curves/BaseCurve.sol`, `libraries/MultiVaultLib.sol`, `protocol/curves/BondingCurveRegistry.sol`, `protocol/curves/LinearCurve.sol` | **VERDICT: FAIL** — R2-HMN-02 (Major), plus R2-HMN-05 and R2-HMN-09. Quote-record equality, hookless parity, and the reentrancy surface all pass.           |
| **Δ** — delta since `b52557b`                   | 30 files                                                                                                                                                                   | **VERDICT: PASS** — no regression; storage mirror and enum integrity verified. Delta-originated issues are carried under C1/C2 and cluster E.               |
| **D** — `AtomWarden` quorum + per-window cap    | `protocol/wallet/AtomWarden.sol`                                                                                                                                           | **VERDICT: PASS** — quorum distinctness, replay resistance, and cap preservation all verified with refutations recorded.                                    |
| **E** — `AtomWallet` ERC-4337 / P-256 auth      | `protocol/wallet/AtomWallet.sol`, `AtomWalletFactory.sol`, `libraries/CoinbaseSmartWalletLib.sol`                                                                          | **VERDICT: FAIL** — R2-HMN-08 (Medium) on the accepted-admin boundary, plus R2-HMN-11 and R2-HMN-14. The landed ERC-1271 fix is sound and mutation-guarded. |

**Headline severity count: 0 Critical, 2 Major, 7 Medium, 7 Minor, 12 Informational.**

---

## 10. Appendix — methodology, tooling, and disclaimer

### 10.1 Method

Scope was pinned before any review: `git rev-parse HEAD`, a symbol search confirming every cluster exists at the
reviewed commit, and a `git diff` establishing that `src/` is byte-identical between the briefed commit and the working
tree. The orchestration skill was vendored at a pinned commit — not a moving branch — and its instructions were read
end-to-end and treated as untrusted until read; it is a read-only orchestration skill invoking benign tooling only.

Six specialists ran independently over the in-scope set, each receiving the invariant set, the out-of-scope denylist,
the register of previously dispositioned findings (ids and statuses only, so that accepted design decisions were not
re-filed), an independence guard barring access to any other reviewer's output, and a rule that any test written must be
named for the mechanism it exercises and carry no provenance marker. Specialists were required to attempt refutation
before recording a pass and to report what did not work.

The orchestrator acted as review gate: it read the primary curve and the dispatch surface directly before delegating,
applied a six-gate false-positive review to every promoted finding, re-derived each against source, and adjudicated
conflicts. Three claims were **downgraded or rejected** on that review — a "holders outside the kernel window earn
nothing" claim (refuted by executed test: the degenerate branch awards them the whole pool), a "share/asset unit drift"
claim (refuted by direct source read and two independent derivations), and a value-leak claim promoted at higher
severity by one specialist and shown to sit inside the accepted dust bound. Those refutations are recorded in §6 rather
than dropped.

Findings that could not be executed are labelled as hand-derived. Where a claim is numeric, the arithmetic is shown.

### 10.2 Tooling

Foundry `1.5.1-stable`, Solidity `0.8.29`, EVM `cancun`, optimizer on at 10,000 runs. Gas figures were measured
end-to-end through `MultiVault` under the optimized default profile against a same-vault hookless baseline. Storage
layouts were compared against live `forge inspect` output.

**Slither and Semgrep did not contribute.** Both are installed on the review host, but crytic-compile forces a
`solc-select` artifact download that the sandboxed environment blocks (HTTP 403) even when a local `solc` binary is
supplied explicitly. No static-analysis pass was run; this report should not be read as including static-analysis
coverage.

### 10.3 Limitations

This round audited the in-scope set at a single commit. It did not perform formal verification, did not review off-chain
infrastructure, and did not exercise the deployed system on a live fork beyond the harnesses noted. Two findings carry
executed proofs of concept; the remainder are derived from source reading and hand-executed arithmetic, and are labelled
accordingly. The existing invariant, Medusa, and symbolic harnesses were treated as inputs, not as evidence — their
prior green is not a proof of the properties in §6, and §6.3 records where they fall short.

### 10.4 Disclaimer

This is a **pre-audit artifact** — an internal, first-party adversarial review conducted before external audit. It is
**not** a formal audit, certification, warranty, or guarantee of safety. It does not constitute an assurance that the
reviewed code is free of defects. Findings are reported by mechanism and should be independently reproduced before being
relied upon for a deployment decision. For contracts managing significant value, an independent audit by a qualified
security firm remains necessary.
