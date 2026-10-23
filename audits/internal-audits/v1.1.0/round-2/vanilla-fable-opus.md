# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 1 of 7 — Vanilla frontier reasoner (no audit skill; whole-contract, hypothesis-driven)

> **How this report was produced:** a vanilla frontier reasoner working from first principles against the shared round
> brief and the pinned source — no audit skill, checklist, or subagent fan-out. Coverage: the `DynamicFeeFlatPriceCurve`
> fee economy (C1), the standardized `IBaseCurve` hook surface and its MultiVault dispatch (C2), the delta since the
> last audited commit (Δ), and `MultiVault` payable-multicall value accounting (A) plus `MultiVaultLib` storage-mirror
> integrity (B) reviewed whole-contract. Verification: hand-derivation of the value-conservation arithmetic on both
> write paths, executable Foundry probes against the real deployment harness for every confirmed finding, and
> guard-removal mutation checks on both landed round-1 fixes. Provenance ID prefix: `R2-CLD-`. One of 7 independent
> round reports; consolidated view: [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

## Cover / metadata

|                      |                                                                                                                                                                                                                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Artifact type**    | Internal AI pseudo-audit — **not** a formal audit, certification, warranty, or guarantee of safety                                                                                                                                                                                   |
| **Target**           | Intuition v1.1.0 core upgrade, public mirror `intuition-contracts-v2` (extending PR #153)                                                                                                                                                                                            |
| **Branch**           | `feat/v1.1.0-core-upgrade`                                                                                                                                                                                                                                                           |
| **Reviewed commit**  | `ac567b2ecd03d12e3e27c0ce570381ef9e383196`                                                                                                                                                                                                                                           |
| **Commit note**      | The round brief pins `8579c5e02e6fd1b58620565d5a6d06d3b9391548`. `HEAD` was one commit ahead at review time; `git diff 8579c5e..HEAD` touches `package.json` only (2 lines), so **`src/` is byte-identical** to the pinned commit. All citations resolve identically at either hash. |
| **Toolchain**        | Solidity `0.8.29`, Foundry `1.5.1` (`forge 1.5.1-stable`), `evm_version = cancun`                                                                                                                                                                                                    |
| **Target networks**  | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                                                                                                                                                                                            |
| **Round / reviewer** | Round 2, report 1 of 7 — vanilla frontier reasoner, no audit skill                                                                                                                                                                                                                   |
| **Date**             | 2026-07-27                                                                                                                                                                                                                                                                           |

---

## Executive summary

This round reviewed the two surfaces the v1.1.0 pipeline had never audited — the new `DynamicFeeFlatPriceCurve` and the
standardized curve fee-hook interface `MultiVault` dispatches through it — plus the payable-multicall value machinery
and the write-path library extraction, read whole-contract rather than diff-only.

The headline result is **one Major finding**: the atom and triple **creation** paths mint vault shares without ever
invoking the curve's record hook. Today that is unreachable, because the dynamic-fee curve deploys under a fresh
non-default `curveId` while `defaultCurveId` remains `1` (`LinearCurve`). But `setBondingCurveConfig` can retarget
`defaultCurveId` at any registered curve, and pointing it at a fee-hook curve — the obvious next step once the fee
economy is proven — makes every subsequent creation mint shares that the curve's own ledger never records. The creator's
exit then reverts on an arithmetic underflow inside the curve, **permanently and irreversibly**: the position cannot be
recovered by seeding the ledger, by later deposits, or by reverting the configuration. This is not admin misuse of a
dangerous power; it is a latent trap behind an individually innocuous parameter, with no on-chain guard. Reproduced with
an executable proof of concept.

Below that, two config-reachable defects on the redeem and deposit fee stack: a withdrawal rate **strictly below the
curve's own configured cap** can burn a user's shares for a **zero payout without reverting** (the NatSpec asserts the
failure mode is a revert — it is not), and the deposit-side fee stack can drive minted shares to zero while
`previewDeposit` silently reports `(0, 0)` instead of surfacing the condition.

Everything else held under attempted refutation. Native value conservation reconciles exactly on both write paths; the
MasterChef accumulator's depositor/exiter exclusion is arithmetically exact and did not over-distribute; the curve's
share ledger mirrored vault shares exactly under interleaved traffic; the hook gate fails closed against a curve
advertising a hook it does not implement, consuming no user value; a hookless curve moved no native value and stayed at
par; and the delegatecall library never reads `msg.value`, so a `multicallPayable` sub-call cannot observe the batch's
full `CALLVALUE`.

**Both landed round-1 fixes verify, with a working mutation check.** Removing the ERC-1271 digest binding makes a
signature over the raw unbound digest validate; removing the emissions-length guard makes a zero epoch length
initialize. Both gating tests go red on mutation and green on restore.

### Findings by severity

| Severity      | Count |
| ------------- | ----- |
| Critical      | 0     |
| **Major**     | **1** |
| Medium        | 1     |
| Minor         | 2     |
| Informational | 1     |
| **Total**     | **5** |

### Coverage caveat — stated plainly

Two limits on this round, both material to how much weight the clean results should carry:

1. **Cluster Δ was not completed.** The 30-file / +1537 −875 delta since `b52557bc5d1e87537e621fc13917240d40044c24` was
   enumerated and its heaviest hunks in `MultiVaultLib`, `MultiVault`, `BaseCurve`, `LinearCurve`,
   `BondingCurveRegistry`, `AtomWallet`, and `CoreEmissionsController` were read in their current form as part of the
   whole-contract passes. The remaining files — notably `FeeProxy`, `TrustBonding`, `MultiVaultCore`, `AtomWarden`, and
   the interface deltas — were **not** reviewed hunk by hunk. Treat Δ as partial.
2. **Two hypotheses were reasoned but not proven by execution:** re-entrancy through the record hook and the `claim`
   payout (argued safe from the `nonReentrant` placement on every write path, but no PoC), and retune with live
   positions (`setConfig` preserving booked and pending earnings across an edge re-price). Both are recorded as
   un-refuted rather than as passes.

A third condition affected the run and is reported for process reasons, not as a finding: the working tree carried a
**concurrent round-2 reviewer's in-progress edits** (untracked tests under `tests/unit/security/v1.1.0/` and, at
different points during the session, modifications to `FeeProxy.sol`, `TrustBonding.sol`, and `AtomWarden.sol`). Per the
independence guard, none of those files or diffs were opened. Every file in this round's own clusters —
`MultiVault.sol`, `MultiVaultLib.sol`, all of `src/protocol/curves/`, `MultiVaultCore.sol`, `AtomWallet.sol`,
`CoinbaseSmartWalletLib.sol`, `CoreEmissionsController.sol`, and the relevant interfaces — was confirmed **unmodified**
against the pinned commit before analysis, so no conclusion here rests on another reviewer's edits. Tests for this round
were run from an isolated directory to avoid compiling their work.

---

## Scope

### In scope and reviewed

| Contract                                | Path (`src/…`)                                                           | Depth this round             |
| --------------------------------------- | ------------------------------------------------------------------------ | ---------------------------- |
| `DynamicFeeFlatPriceCurve`              | `protocol/curves/DynamicFeeFlatPriceCurve.sol`                           | Whole-contract (C1, primary) |
| `IDynamicFeeFlatPriceCurve`             | `interfaces/IDynamicFeeFlatPriceCurve.sol`                               | Whole-file                   |
| `IBaseCurve`                            | `interfaces/IBaseCurve.sol`                                              | Whole-file (C2, primary)     |
| `BaseCurve`                             | `protocol/curves/BaseCurve.sol`                                          | Whole-contract (C2)          |
| `LinearCurve`                           | `protocol/curves/LinearCurve.sol`                                        | Whole-contract (C2)          |
| `BondingCurveRegistry`                  | `protocol/curves/BondingCurveRegistry.sol`                               | Whole-contract (C2)          |
| `MultiVaultLib`                         | `libraries/MultiVaultLib.sol`                                            | Whole-contract (B)           |
| `MultiVault`                            | `protocol/MultiVault.sol`                                                | Whole-contract (A)           |
| `MultiVaultCore`                        | `protocol/MultiVaultCore.sol`                                            | Read for fee/config surface  |
| `AtomWallet` + `CoinbaseSmartWalletLib` | `protocol/wallet/AtomWallet.sol`, `libraries/CoinbaseSmartWalletLib.sol` | Landed-fix verification only |
| `CoreEmissionsController`               | `protocol/emissions/CoreEmissionsController.sol`                         | Landed-fix verification only |

Clusters D, E, F, G, H were assigned to other round-2 reviewers and were entered only where a C1/C2 path led there.

### Out of scope

Per the round brief, and not filed: Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain transport;
`BaseEmissionsController` and all Base-chain components; the deliberately parked TVL exit rate limiter; unbounded
cross-curve counter-stake aggregation; `MultiVaultMigrationMode`; legacy `Trust` / `TrustToken` / `WrappedTrust` /
`VotingEscrow`; `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib` beyond conformance to the new
hook defaults; the held-out `AtomWallet` delegation framework; whole-surface mixed payable/non-payable multicall
batching; and trusted-admin centralization as such (privileged actions are gated by a 4-of-8 Safe acting through two
`TimelockController`s — an accepted trust assumption).

Two boundaries were touched and are noted rather than filed. `BaseEmissionsController.initialize` is a second caller of
the shared emissions initializer and was checked only far enough to confirm the in-scope guard's coverage. `FeeProxy`
was reached in the variant sweep for R2-CLD-01 but not reviewed.

**Finding R2-CLD-01 is deliberately filed despite the trusted-admin exclusion.** The exclusion covers "a trusted admin
can do something harmful." This is a different shape: a routine, individually reasonable configuration change that
silently and irreversibly destroys user funds, with no guard and no warning. The distinction between "trusted admin can
do X" and "an attacker can do X" is preserved throughout — this is neither, and is called out as such in the finding.

---

## Severity classification

Severity is assigned as **Impact × Likelihood**, taking the highest severity a _credible_ path reaches under the
intended deployment and trust model. Permissionless exploitability is separated from trusted-configuration reachability,
and each finding states which applies.

| Severity          | Use when                                                                                                                                                                                                              |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control.                                                          |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade/configuration path corrupts critical state — unsafe storage layout, exploitable reentrancy, serious accounting break. |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing or DoS of a funds path, admin footgun, or a spec regression that materially affects users or operators.                                                       |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behavior, monitoring or integration weakness.                                                                                                     |
| **Informational** | Documentation, hygiene, NatSpec-versus-behavior mismatch, or a missing non-critical test.                                                                                                                             |

### Summary table

| ID        | Severity      | Confidence | Cluster | Title                                                                                                                           | Invariant       | Status |
| --------- | ------------- | ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------- | ------ |
| R2-CLD-01 | **Major**     | High       | C2 / B  | Creation paths mint fee-hook-curve shares without recording them; a `defaultCurveId` retarget strands creator stake permanently | §5.3, §5.2      | Open   |
| R2-CLD-02 | Medium        | High       | C1      | Redeem burns shares for a zero payout without reverting; the curve's own cap does not bound it                                  | §5.1, §5.4      | Open   |
| R2-CLD-03 | Minor         | High       | C1 / C2 | Layered deposit fee can zero the minted shares; `previewDeposit` reports `(0, 0)` where the write path reverts                  | §5.1            | Open   |
| R2-CLD-04 | Minor         | High       | B       | MultiVault entry and exit fees paid by non-default-curve users accrue entirely to the default curve's vault                     | n/a — new class | Open   |
| R2-CLD-05 | Informational | High       | C1      | Emissions-length guard is one-sided; only the zero case is rejected                                                             | n/a — new class | Open   |

---

## Findings

### R2-CLD-01 — Creation paths mint fee-hook-curve shares without recording them; a `defaultCurveId` retarget strands creator stake permanently — **Major**

**Severity:** Major · **Confidence:** High · **Status:** Open · **Cluster:** C2 (hook dispatch) / B (storage mirror)
**Invariant broken:** §5.3 (curve ledger mirrors vault shares), and consequently §5.2 (solvency — funds become
unrecoverable)

#### Description

`MultiVault` reaches a curve's fee hooks through exactly one path: `_processDeposit` resolves the hook during
`_calculateDeposit` and forwards it in `_recordCurveDeposit` after its state writes. The **creation** paths do not
participate. `_calculateAtomCreate` and `_calculateTripleCreate` return
`(shares, assetsAfterFixedFees, assetsAfterFees)` with **no `CurveHook` member at all** — they never call
`quoteDepositFee`, and no creation path calls `recordDeposit`.

That is harmless while creation can only ever touch a curve without hooks. Today it can only touch the **default**
curve: `_processDeposit` explicitly rejects initializing a default-curve vault through the deposit path
(`MultiVault_DefaultCurveMustBeInitializedViaCreatePaths`), and the dynamic-fee curve deploys under a fresh non-default
`curveId` while `defaultCurveId` stays `1` (`LinearCurve`). So the hookless creation path and the hook-bearing curve
never meet.

`setBondingCurveConfig` breaks that separation. It accepts any `defaultCurveId` with no validation of the target curve's
hook surface. Point it at the dynamic-fee curve — the natural step once the fee economy is proven, and the whole reason
the curve exists — and every subsequent `createAtoms` / `createTriples` mints vault shares on a curve whose ledger
records nothing.

The consequence is not a stuck transaction. `recordRedeem` decrements `userStake[termId][account]` by the burned share
count. For a creator that value is zero, so the subtraction underflows and the redeem reverts with `Panic(0x11)` —
permanently. Nothing repairs it: the curve exposes no way to write `userStake`, seeding the ledger with a later
depositor does not help (verified), and reverting `defaultCurveId` does not help either, because the shares are already
minted against an empty ledger entry. The creator's entire creation stake is irrecoverable.

This is filed despite the trusted-admin exclusion because it is not the excluded shape. `setBondingCurveConfig` is not a
dangerous power being misused — it is a routine parameter whose plainly intended use silently destroys user funds. There
is no guard, no revert, and no signal at configuration time.

#### Code

Creation calc returns no hook — `src/libraries/MultiVaultLib.sol:910-932`:

```solidity
function _calculateAtomCreate(bytes32 termId, uint256 assets)
    private view
    returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)
{   // ...no CurveHook; quoteDepositFee is never called on the create path
    shares = _convertToShares(termId, curveId, assetsAfterFees);
```

Deposit calc, by contrast, resolves and carries the hook — `src/libraries/MultiVaultLib.sol:959-963`:

```solidity
hook.curve = _depositFeeHookCurve(curveId);
if (hook.curve != address(0)) {
    hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
    assetsAfterFees -= hook.fee;
}
```

The unguarded retarget — `src/protocol/MultiVault.sol:825-828`:

```solidity
function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyTimelock {
    bondingCurveConfig = _bondingCurveConfig;   // no check on the target curve's hook surface
```

The underflow site — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:414-417`:

```solidity
_settle(termId, account);
userStake[termId][account] -= withdrawnStake;   // 0 - shares  ->  Panic(0x11)
tierStake[termId][exitTier] -= withdrawnStake;
```

Also relevant: `src/libraries/MultiVaultLib.sol:697-771` (`_processDeposit`, the only hook-bearing path) and `:723-725`
(the guard that forces default-curve vaults through creation).

#### Proof of concept

Executed against the repository's own deployment harness at the reviewed commit.

1. **Setup** — standard harness: `defaultCurveId = 1` (`LinearCurve`), `DynamicFeeFlatPriceCurve` registered at
   `curveId = 4` with both hook getters returning `true`.
2. `vm.prank(timelock)` → `setBondingCurveConfig({ registry, defaultCurveId: 4 })`.
3. `vm.prank(bob)` → `createAtoms{value: 10e18}(...)`.
4. Read the two ledgers.
5. `vm.prank(bob)` → `redeem(bob, termId, 4, vaultShares / 2, 0)`.
6. Seed the curve ledger with an unrelated depositor, then retry step 5.

Observed:

```
default curve id now:                 4
creator vault shares:                 9799019999999020000
creator curve userStake:              0
curve vaultAssets mirror:             0
creator PARTIAL redeem REVERTED:      0x4e487b71...0011      (Panic 0x11 — arithmetic underflow)
after seeding: curve vaultAssets      19071000000000000000
after seeding: other userStake        19071000000000000000
creator redeem AFTER seeding REVERTED: 0x4e487b71...0011     (still unrecoverable)
```

The assertion that fails: `curveStake == vaultShares` → `0 != 9799019999999020000`. §5.3 is broken at the moment of
creation, and the position is unrecoverable from that point on.

#### Impact

Permanent, irreversible loss of the creation stake for **every atom and triple created while a fee-hook curve is the
protocol default** — `assets − atomCost` per creation, across all creators, with no recovery path. The vault remains
globally solvent (the wei stays in `MultiVault`), so this surfaces as silently unredeemable user positions rather than a
shortfall, which makes it correspondingly hard to detect.

#### Refutation attempted

- **Tried:** reaching the same desync without touching `defaultCurveId`, via a first deposit onto a new non-default
  hook-curve vault. **Defended:** `_processDeposit` routes that through `_updateVaultOnCreation` at
  `src/libraries/MultiVaultLib.sol:755-757` and still calls `_recordCurveDeposit` at `:771`, so the ledger stays in
  lockstep.
- **Tried:** an unhooked burn path desyncing the ledger from the other direction. **Defended:** `_burn` has no callers
  in `MultiVault` beyond its own definition at `src/protocol/MultiVault.sol:896-898`.
- **Tried:** swapping a registered curve's address under live positions to strand a ledger. **Defended:**
  `BondingCurveRegistry.addBondingCurve` is append-only with no address mutation
  (`src/protocol/curves/BondingCurveRegistry.sol:86-119`).
- **Tried:** recovering a stranded position by seeding `userStake` through another depositor. **Not defended — confirmed
  unrecoverable** (step 6 above).
- **Confirmed harmless:** `_initializeOppositeTripleVault` mints `minShare` only to `BURN_ADDRESS`
  (`src/libraries/MultiVaultLib.sol`, `_initializeOppositeTripleVault`), which never redeems.

#### Recommendation

Either is sufficient; the second is minimal and fails closed.

1. Route the creation paths through the same quote/record dispatch as `_processDeposit`, so a hook curve's ledger is
   written on creation exactly as on deposit.
2. Reject the configuration at the boundary: in `setBondingCurveConfig`, revert when the proposed `defaultCurveId`
   resolves to a curve whose `hasDepositFeeHook()` or `hasRedeemFeeHook()` returns `true`, until (1) lands. This makes
   the trap unreachable in one guard and preserves the current deployment exactly.

Whichever is chosen, add an explicit NatSpec statement on `setBondingCurveConfig` that the default curve must be
hookless, and pin it with a regression test.

#### Regression test

`test_defaultCurveRetargetPreservesCurveLedger` — assert `userStake == vault share balance` immediately after a creation
performed while a hook curve is the default, and assert the creator can redeem. Must go red against the current
implementation.

#### Variant sweep

| Path                       | Result                                                                                                            |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `createAtoms`              | **Same bug** — routes through `_calculateAtomCreate`                                                              |
| `createTriples`            | **Same bug** — routes through `_calculateTripleCreate`                                                            |
| `createAtomsFor`           | **Same bug** — same calc                                                                                          |
| `createTriplesFor`         | **Same bug** — same calc                                                                                          |
| `deposit` / `depositBatch` | Safe — `_processDeposit` always calls `_recordCurveDeposit`                                                       |
| Preview                    | **Same bug** — `previewAtomCreate` / `previewTripleCreate` are equally hookless, so previews under-report the fee |
| Router (`FeeProxy`)        | Inherits the bug for whichever creation entry point it routes to; not independently reviewed                      |
| Upgrade-initializer        | n/a                                                                                                               |

---

### R2-CLD-02 — Redeem burns shares for a zero payout without reverting; the curve's own cap does not bound it — **Medium**

**Severity:** Medium · **Confidence:** High · **Status:** Open · **Cluster:** C1 **Invariant broken:** §5.1
(conservation — the user's credit has no matching debit back to them), §5.4 (maximum loss is the fees paid)

#### Description

The curve's withdrawal-rate NatSpec makes a specific safety claim: that bounding the override by `withdrawalCapBps`
prevents a rate that "consumes the entire redeem and underflows `assets - fees` in MultiVault, bricking redeems for that
tier until retuned." Two parts of that are wrong in a way that matters.

First, the cap does not bound the hazard, because the cap itself may be `BPS`. `_setConfig` accepts `withdrawalCapBps`
up to `10_000` and `withdrawalBaseBps` up to the cap, so a rate arbitrarily close to 100% is inside the validated
envelope.

Second — and this is the substantive part — the failure mode below the underflow point is **not** a revert. It is a
**successful redeem that pays out zero**. `_calculateRedeem` computes `assets - protocolFee - exitFee - hook.fee`, and
the only floor on the result is the caller's own `minAssets` slippage argument, which is `0` on the overwhelmingly
common "redeem everything" call. When the fee stack sums to exactly the gross assets, the user's shares are burned, the
payout is zero, and nothing reverts.

A revert is safe: the funds stay where they are and the configuration can be corrected. A zero payout is irreversible
loss of that user's principal. The documented failure mode is the safe one; the actual failure mode across a band of
configurations strictly _below_ the cap is the unsafe one.

#### Code

The claim, and the cap that does not bound it — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:256-261`:

```
///         formulaic `min(cap, base + tier*growth)` but must stay within the schedule's declared
///         per-tier caps (`depositCapBps` / `withdrawalCapBps`): the override retunes a tier's rate
///         inside the same envelope the formula respects, it does not bypass the cap. Bounding the
///         withdrawal rate matters — a BPS-level withdrawal fee consumes the entire redeem and
///         underflows `assets - fees` in MultiVault, bricking redeems for that tier until retuned.
```

The validated envelope — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:894-896`:

```solidity
if (_config.withdrawalBaseBps > _config.withdrawalCapBps || _config.withdrawalCapBps > BPS) {
    revert DynamicFeeFlatPriceCurve_InvalidConfig();
}
```

The unfloored subtraction — `src/libraries/MultiVaultLib.sol:1062-1069`:

```solidity
hook.curve = _redeemFeeHookCurve(curveId);
if (hook.curve != address(0)) {
    hook.fee = IBaseCurve(hook.curve).quoteRedeemFee(termId, account, assets);
}
uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;
```

The only floor is caller-supplied — `src/libraries/MultiVaultLib.sol` (`_validateRedeem`):

```solidity
(uint256 expectedAssets,,) = _calculateRedeem(termId, curveId, shares, account);
if (expectedAssets < minAssets) revert MultiVault.MultiVault_SlippageExceeded();
```

#### Proof of concept

1. **Setup** — harness defaults; `protocolFee = 100` bps; user holds `9.675e18` shares on the hook curve.
2. Owner calls `setConfig` with `withdrawalBaseBps = 9900`, `withdrawalGrowthBps = 0`, **`withdrawalCapBps = 10_000`** —
   the effective rate is strictly _below_ the cap.
3. `vm.prank(bob)` → `redeem(bob, termId, 4, shares / 2, 0)`.

Observed:

```
shares burned:        4837499999999517500
assets returned:      0
bob balance delta:    0
curve balance delta:  4789124999999522325
```

No revert. `9900 + 100 = 10_000` bps, so `assets - protocolFee - hook.fee == 0` exactly. The assertion
`assertGt(assets, 0, "burning shares must not return zero assets")` fails. Above roughly `9900` bps the same expression
underflows and reverts with `Panic(0x11)` — so both the documented behavior and the undocumented one exist, separated by
a single basis point.

#### Impact

Total loss of the redeemed principal for any user calling with `minAssets = 0` under a configuration inside the curve's
own validated envelope. Reachable by the curve owner (`onlyOwner` on `setConfig` / `setTierFeeOverride`), which in
production is the parameters timelock — so this is configuration-reachable, not attacker-reachable. It is filed on the
strength of the documentation-versus-behavior mismatch and the missing floor, not on "governance can set a large
number."

#### Refutation attempted

- **Tried:** reaching a zero or negative payout without touching the curve configuration, through MultiVault's own fees.
  **Not defended, but out of this round's novelty claim:** `setVaultFees` (`src/protocol/MultiVault.sol:819-822`) has no
  validation either, so the same shape is reachable pre-upgrade. This finding therefore does **not** claim the curve
  bypasses a previously enforced ceiling — there was none. The novel part is the guard that exists and documents a
  safety property it does not deliver.
- **Tried:** having the slippage check catch it. **Not defended:** `minAssets = 0` is the natural argument for a full
  exit and passes `expectedAssets < minAssets` trivially.
- **Tried:** treating this as a duplicate of the round-1 disposition on unvalidated governance parameters. **Rejected on
  content:** that disposition covers the absence of on-chain validation of trusted input. Here the validation is present
  and deliberate, and its NatSpec asserts a failure mode (revert) that does not match behavior (silent zero payout).

#### Recommendation

Add a payout floor in `_processRedeem`: revert when `shares > 0` and `assetsAfterFees == 0`, with a named error rather
than the current silent success or bare `Panic`. Separately, correct the NatSpec at
`DynamicFeeFlatPriceCurve.sol:256-261` to describe both failure modes, and consider bounding `withdrawalCapBps` and
`depositCapBps` below `BPS` by a margin that leaves headroom for MultiVault's own fee stack.

#### Regression test

`test_redeemNeverBurnsSharesForZeroPayout` — fuzz the withdrawal rate across the validated envelope and assert
`assets > 0` whenever `shares > 0`.

#### Variant sweep

| Path                | Result                                                                        |
| ------------------- | ----------------------------------------------------------------------------- |
| `redeem`            | **Same bug**                                                                  |
| `redeemBatch`       | **Same bug** — same `_processRedeem` body per leg                             |
| On-behalf-of        | **Same bug** — approval only gates who may call; the payout math is identical |
| Preview             | Divergent — `previewRedeem` returns the same zero without signalling it       |
| Router (`FeeProxy`) | Not reviewed                                                                  |
| Upgrade-initializer | n/a                                                                           |

---

### R2-CLD-03 — Layered deposit fee can zero the minted shares; `previewDeposit` reports `(0, 0)` where the write path reverts — **Minor**

**Severity:** Minor · **Confidence:** High · **Status:** Open · **Cluster:** C1 / C2 **Invariant broken:** §5.1 (as an
integration-honesty defect, not a value leak)

#### Description

The curve's deposit fee is subtracted from a base that is **already net** of MultiVault's protocol, entry, and
atom-wallet fees, while being _quoted_ on the gross `assetsAfterMinSharesCost`. The available headroom is therefore
`BPS` minus MultiVault's own fee total, not `BPS` — but `_setConfig` validates `depositCapBps` against `BPS` alone, with
no knowledge of the vault's fee stack.

At the boundary the write path reverts cleanly with `MultiVault_DepositOrRedeemZeroShares`. The read path does not:
`previewDeposit` skips `_validateMinShares` and returns `(0, 0)` as if it were a successful quote. An integrator sizing
a deposit against the preview sees a valid-looking zero rather than the condition that will revert their transaction.
Past the boundary, `assetsAfterFees -= hook.fee` underflows and surfaces as a bare `Panic(0x11)` instead of a named
error.

#### Code

`src/libraries/MultiVaultLib.sol:959-963` (atom) and `:1021-1025` (triple) — the two deposit quote sites, both
subtracting from the post-MultiVault-fee net:

```solidity
hook.curve = _depositFeeHookCurve(curveId);
if (hook.curve != address(0)) {
    hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
    assetsAfterFees -= hook.fee;   // underflows once the fee stack exceeds the base
}
```

The preview that skips the zero-shares guard — `src/libraries/MultiVaultLib.sol:426-433`:

```solidity
(shares, assetsAfterMinSharesCost, assetsAfterFees,) = _calculateDeposit(termId, curveId, assets, isAtomVault);
```

The cap validated against `BPS` only — `src/protocol/curves/DynamicFeeFlatPriceCurve.sol:891-893`.

#### Proof of concept

With `depositBaseBps = depositCapBps = 9800` and MultiVault's protocol + atom-wallet fees at 100 bps each:

```
quoted fee on 10e18:  9800000000000000000
deposit reverted:     0x78dd5f88            (MultiVault_DepositOrRedeemZeroShares)
preview shares:       0
preview assets:       0                     (no error surfaced)
```

#### Impact

Integration-level: a preview that reports a successful zero rather than the failing condition, and an unnamed `Panic`
past the boundary. No value is lost — the write path fails closed.

#### Refutation attempted

- **Tried:** driving `assetsAfterFees` negative to mint shares against value never received. **Defended:** Solidity 0.8
  checked arithmetic reverts on the subtraction at `MultiVaultLib.sol:962` / `:1024`; the deposit fails closed and no
  shares are minted.
- **Tried:** using the `(0, 0)` preview to pass a `minShares` slippage check with a zero mint. **Defended:**
  `_validateMinShares` rejects `sharesForReceiver == 0` unconditionally before any state write.

#### Recommendation

Mirror the zero-shares condition in the preview path (return a typed error or an explicit sentinel), and validate
`depositCapBps` against the headroom actually available after MultiVault's fee stack rather than against `BPS`.

#### Regression test

`test_previewDepositAgreesWithWritePathAtFeeCeiling` — assert that whenever `deposit` reverts for a given
`(termId, curveId, assets)`, `previewDeposit` does not return a success-shaped result.

---

### R2-CLD-04 — MultiVault entry and exit fees paid by non-default-curve users accrue entirely to the default curve's vault — **Minor**

**Severity:** Minor · **Confidence:** High · **Status:** Open · **Cluster:** B **Invariant broken:** n/a — new class
(economic attribution)

#### Description

`_increaseProRataVaultAssets` hard-codes `defaultCurveId` as its target vault. That is correct for its
atom-deposit-fraction use, where a triple's fraction is credited to the three underlying **atom** vaults. It is applied
unchanged to the **entry-fee** and **exit-fee** paths, where the correct target is the vault the user is actually
transacting with.

The result: a user depositing into or redeeming from a term's dynamic-fee-curve vault pays MultiVault's entry and exit
fees, and the entire economic benefit accrues to holders of the _same term's default-curve vault_ — a different cohort
entirely. Hook-curve holders receive no pro-rata fee accrual at all.

This is very likely deliberate rather than a defect, and it is **load-bearing for invariant §5.4**: the dynamic-fee
curve's price holds at exactly par precisely because these credits never reach its vault (see the negatives section). It
is filed at Minor for a narrower reason — the behavior is a material, undisclosed cross-cohort value transfer that
appears nowhere in the curve's NatSpec, and a shared helper silently applying one target to two use cases with different
correct answers is a fragile construction to leave unremarked.

#### Code

`src/libraries/MultiVaultLib.sol:1086-1091`:

```solidity
function _increaseProRataVaultAssets(bytes32 termId, uint256 amount, VaultType vaultType) private {
    Storage storage s = _s();
    uint256 curveId = s.bondingCurveConfig.defaultCurveId;   // always the default vault
    VaultState storage vaultState = s.vaults[termId][curveId];
    _setVaultTotals(termId, curveId, vaultState.totalAssets + amount, vaultState.totalShares, vaultType);
}
```

Called for the entry fee at `src/libraries/MultiVaultLib.sol:738-742` and the exit fee at `:798-800`. The fee _gates_
are likewise keyed on the default vault (`_shouldChargeFees`, `_shouldChargeExitFees`), which is what makes the routing
look deliberate.

#### Proof of concept

Term pushed above `feeThreshold` on the default vault, then a 10e18 deposit and a partial redeem on the hook curve:

```
[deposit] default assets delta:  99999999999990000     (the 1% entry fee)
[deposit] default shares delta:  0
[deposit] default price before:  1000000000000000000
[deposit] default price after:   1002040816326530366
[deposit] dynamic price after:   1000000000000000000
[redeem]  default assets delta:  47874999999995225     (the exit fee)
[redeem]  default price after:   1003017857142856779
[redeem]  dynamic price after:   1000000000000000000
```

Global conservation is unaffected — the wei stays in `MultiVault` — so this is attribution, not leakage.

#### Refutation attempted

- **Tried:** turning this into a solvency break by making credited liabilities exceed native holdings. **Defended:**
  hand-derivation of both write paths reconciles exactly. On deposit, liabilities added
  (`protocolFee + atomWalletFee + entryFee + assetsAfterFees`) equal `assets − hook.fee`, against native in `assets` and
  native out `hook.fee`. On redeem, the liability delta `exitFee − raw + protocolFee` equals the negated native outflow
  `raw − protocolFee − exitFee`.
- **Tried:** establishing this as a v1.1.0 regression from the library extraction. **Inconclusive:** the public mirror's
  history is squashed, and the pre-extraction `MultiVault.sol` is a stub at the relevant parent commit, so this could
  not be compared against v1.0.x from this repository. **Flagged for the team to confirm against the monorepo history.**

#### Recommendation

If deliberate, document it explicitly in `DynamicFeeFlatPriceCurve`'s NatSpec and in the integrator docs — holders on a
non-default curve should know their price is pinned at par by construction and that they receive no share of
MultiVault's entry/exit fees. If not deliberate, parameterize `_increaseProRataVaultAssets` by the transacting `curveId`
for the fee paths while keeping `defaultCurveId` for the atom-deposit-fraction path — and note that doing so would move
the hook curve's price off par, changing §5.4.

---

### R2-CLD-05 — Emissions-length guard is one-sided; only the zero case is rejected — **Informational**

**Severity:** Informational · **Confidence:** High · **Status:** Open · **Cluster:** C1 (landed-fix follow-up)

#### Description

The round-1 fix added `_validateEmissionsLength`, which rejects `emissionsLength == 0`. It correctly closes the
division-by-zero at `_calculateTotalEpochsToTimestamp`, and it is reachable from every in-scope initialization path
(verified below). The guard is one-sided: there is no upper bound. An `emissionsLength` large relative to the chain's
timeline makes `_currentEpoch()` return `0` indefinitely, so the schedule never advances — the same class of
bricked-schedule outcome the zero case produced, reached from the other end and without reverting.

Same trust class as the original: a one-shot trusted initialization parameter. Recorded so the guard's coverage is
documented, not because a new attacker path exists.

#### Code

`src/protocol/emissions/CoreEmissionsController.sol:129-133`:

```solidity
function _validateEmissionsLength(uint256 emissionsLength) internal pure {
    if (emissionsLength == 0) revert CoreEmissionsController_InvalidEmissionsLength();
}
```

Consumers at `:180`, `:189`, `:222`.

#### Recommendation

Bound `emissionsLength` above as well (a sane maximum epoch length), so the guard covers both degenerate ends.

---

## Landed round-1 fixes — verification and mutation check

Both fixes were read, attacked in their new construction, and mutation-checked by removing the guard from source and
confirming the gating test turns red. Source was restored and re-verified green afterward.

### MED-01 — ERC-1271 digest binding — **Verified**

The validated digest is wrapped in a wallet- and chain-bound EIP-712 envelope before reaching the MultiOwnable path
(`src/protocol/wallet/AtomWallet.sol:335-342`, `src/libraries/CoinbaseSmartWalletLib.sol:293-305`).

Attacks attempted on the new construction, all defended:

| Attack                                           | Result                  | Defence                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------ | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Signature over the raw, unbound digest           | Rejected (`0xffffffff`) | `replaySafeHash` wrap at `AtomWallet.sol:336-337`                                                                                                                                                                                                                                               |
| Replay of a wallet-A-bound signature on wallet B | Rejected                | `verifyingContract` in the domain separator                                                                                                                                                                                                                                                     |
| Replay across chain ids (`vm.chainId`)           | Rejected                | `chainId` in the domain separator                                                                                                                                                                                                                                                               |
| Pre-claim wallet, every owner index 0–2          | Rejected                | Empty registry → `ownerBytes.length == 0` → `false`, `CoinbaseSmartWalletLib.sol`                                                                                                                                                                                                               |
| `validateUserOp` / `isValidSignature` asymmetry  | **Correct, not a gap**  | `_validateSignature` wraps `userOpHash` in the eth-signed-message prefix rather than `replaySafeHash`; ERC-4337's `userOpHash` already commits to chain id, EntryPoint, and sender, so double-wrapping would break interop. The two preimages are structurally distinct with no collision path. |

**Mutation check:** replacing `replaySafeHash(hash, …)` with `hash` makes
`test_erc1271_rejectsSignatureOverRawUnboundDigest` go **red** — the unbound signature validates with `0x1626ba7e`,
which is exactly the vulnerability the fix closes. Restored → green.

_Noted, not filed (cluster E, another reviewer's scope):_ the P-256/WebAuthn path uses `requireUserVerification: false`,
matching the upstream Coinbase default.

### MED-02 — Zero epoch length rejected — **Verified**

`_validateEmissionsLength` is called from the shared initializer at
`src/protocol/emissions/CoreEmissionsController.sol:54`. Coverage confirmed exhaustively: `_EPOCH_LENGTH` is written at
exactly one site (`:60`), inside the validated initializer, with **no setter anywhere in `src/` that bypasses it**. The
initializer has exactly two callers — `SatelliteEmissionsController.sol:74` (in scope) and
`BaseEmissionsController.sol:78` (out of scope, Base chain). `TrustBonding` does not store its own epoch length; it
reads through `ICoreEmissionsController.getEpochLength()`, inheriting the validated value.

Other degenerate values reaching the same failure mode: the `timestamp < _START_TIMESTAMP` underflow is guarded by early
returns at `_currentEpoch()` and `_calculateTotalEpochsToTimestamp`. The unbounded upper end is recorded as R2-CLD-05.

**Mutation check:** removing `_validateEmissionsLength(emissionsLength)` from `:54` makes
`test_emissions_zeroEpochLengthRejectedAtInit` go **red** — a zero epoch length initializes successfully. Restored →
green. The companion `test_emissions_nonZeroEpochLengthAccepted` stays green in both states, pinning the first test to
the zero check specifically.

---

## Properties checked (negatives)

Each line is a property this round tried to break and could not, with the attack attempted and the guard that defended
it.

**Conservation and solvency**

- `PASS` — **§5.1, every fee has exactly one home.** Tried over-distribution by driving multi-actor deposit and redeem
  rounds through the accumulator and summing `claimable` against native received;
  `sum(claimable) + protocolAccrued <= received` held. Defended by exclusion denominators at
  `DynamicFeeFlatPriceCurve.sol:674-676` and `:424`, with the post-distribution debt re-base at `:389` and `:448`.
- `PASS` — **§5.2, principal never sits in the curve.** Tried to make credited liabilities exceed native holdings by
  hand-deriving both write paths; deposit liabilities equal `assets − hook.fee` against native in `assets` / out
  `hook.fee`, and redeem liabilities equal the negated outflow. Defended by `MultiVaultLib.sol:736-771` and `:796-810`.
- `PASS` — **Fee-slice exhaustiveness by construction.** Every branch of `_payRecentTiers` terminates in an occupied
  tier, the nearest-occupied fallback, or `protocolAccrued`; the `sumWeights == 0` degenerate case routes to
  `_awardNearestOrProtocol` rather than silently forfeiting. `DynamicFeeFlatPriceCurve.sol:599-632`, `:693-719`.

**Ledger integrity**

- `PASS` (with one exception) — **§5.3, curve ledger mirrors vault shares.** Tried desyncing via interleaved multi-actor
  deposits and partial redeems; `userStake == getShares(...)` held exactly for every actor and
  `sum(userStake) == vaultAssets` held exactly, net of the `1e6` min-share seed. Defended by the paired mutation of
  `userStake` / `tierStake` / `vaultAssets` in both record hooks. **The exception is R2-CLD-01**, which breaks this at
  creation.
- `PASS` — **No unhooked burn path.** Tried finding a share burn that bypasses `recordRedeem`. Defended: `_burn` has no
  callers beyond its definition at `MultiVault.sol:896-898`.
- `PASS` — **Registry cannot swap a curve under live positions.** Tried re-pointing a live `curveId`. Defended by the
  append-only `addBondingCurve` at `BondingCurveRegistry.sol:86-119` — `curveAddresses` is never rewritten.

**Pricing**

- `PASS` — **§5.4, flat-price par.** Tried driving the hook curve's price off `1e18` through entry fees, exit fees, and
  repeated deposit/redeem cycles; it stayed at exactly `1000000000000000000` in every probe. **Mechanism identified:**
  `LinearCurve` is pro-rata, not literally flat (`assets = shares * totalAssets / totalShares`,
  `LinearCurve.sol:166-173`), so par holds only because pro-rata fee credits are routed to the _default_ curve's vault
  and never reach the hook curve's (`MultiVaultLib.sol:1086-1091`) — see R2-CLD-04. Par is a consequence of that
  routing, not an independent property.
- `PASS` — **Piecewise deposit-fee walk.** Verified numerically: a `10e18` deposit from an empty vault across edges
  `5e18` / `11e18` charged `1%` on the first band and `1.5%` on the second, totalling exactly `0.125e18`.
  `DynamicFeeFlatPriceCurve.sol:828-848`.

**Hook dispatch (C2)**

- `PASS` — **Curve advertising a hook it does not implement fails closed, consuming no value.** Registered a curve
  overriding both getters to `true` while inheriting `BaseCurve`'s reverting defaults; the deposit reverted with
  `BaseCurve_FeeHooksNotSupported` (`0x0e94648f`) and the caller's balance was asserted unchanged. Defended by
  `BaseCurve.sol:163-180` plus the CEI ordering that places the record call after state writes but inside the same
  reverting transaction.
- `PASS` — **Hookless curve is a no-op.** A `LinearCurve` deposit moved zero native value to the curve
  (`address(linearCurve).balance` unchanged) and left the vault at par. Defended by the `hasDepositFeeHook()` /
  `hasRedeemFeeHook()` gates at `MultiVaultLib.sol:832-843`.
- `PASS` — **Quote↔record parity is structural.** Tried finding vault state written between quote and record that could
  move the quote. Defended by dataflow: the quote is resolved once during `_calculateDeposit` / `_calculateRedeem`,
  carried in `CurveHook memory hook`, and forwarded verbatim at `MultiVaultLib.sol:851-865` — never re-resolved or
  re-quoted. Both deposit quote sites (`:961` atom, `:1023` triple) use the identical expression on the identical base.
- `PASS` — **Quote and record agree on the account.** Tried a `receiver != msg.sender` redeem to make the quote key on
  one account and the record on another. Defended: `_processRedeem` passes `receiver` to `_calculateRedeem` (`:794`),
  `_updateVaultOnRedeem` (`:803`), and `_recordCurveRedeem` (`:808`) consistently.

**Payable multicall and value accounting (A, §5.6)**

- `PASS` — **No `msg.value` replay.** Tried making a `delegatecall` sub-call observe the batch's full `CALLVALUE`.
  Defended structurally: `msg.value` **never appears in executable code** anywhere in `MultiVaultLib.sol` (verified by
  exhaustive grep — the three occurrences are all in comments), so no library body can read it; the six allowlisted
  selectors all forward `_effectiveMsgValue()` (`MultiVault.sol:660, 670, 681, 693, 705, 716`), and
  `sum(values) == msg.value` is enforced upfront at `:612`.
- `PASS` — **Transient state cannot leak.** Tried a caught-revert path leaving `_inMulticall` / `_virtualMsgValue` set.
  Defended: `multicallPayable` has no `try`/`catch`; a sub-call revert bubbles raw at `MultiVault.sol:620-624` and
  reverts the whole transaction, discarding transient state. Both are cleared on the success path at `:631-632`, and
  canonical `multicall` forces `_virtualMsgValue = 0` at `:518`.
- `PASS` — **Nested multicalls rejected.** `_inMulticall` guards both entry points (`:516`, `:592`), backed by the
  selector allowlist which excludes both multicall selectors.
- `PASS` — **Re-entrancy through the record hook.** _Reasoned, not PoC'd._ Every payable write path carries
  `nonReentrant` (`MultiVault.sol:653-717`), and `multicallPayable` sub-calls each enter and exit the guard
  independently, so a curve re-entering `deposit` / `redeem` during `recordDeposit` / `recordRedeem` reverts on the
  guard. Recorded as un-refuted rather than proven.

**Round-1 dispositions re-tested against the new fee surface**

- `PASS` — **Unvalidated governance parameters (MIN-02 shape).** Re-tested against the new curve config surface.
  R2-CLD-02 is filed on a distinct basis (a guard that exists and documents a safety property it does not deliver), not
  as a re-file. No disposition-override was established.
- `PASS` — **Storage-layout / library mirror (INFO-07 shape).** `BaseCurve` declares exactly one state variable (`name`)
  with the single-slot rationale documented at `BaseCurve.sol:24-26`; `DynamicFeeFlatPriceCurve` owns every slot from 1
  onward. Consistent with the recorded disposition; nothing new found.

**Not established either way**

- `UNPROVEN` — **Retune with live positions (H8).** `setConfig` re-prices edges while accumulators stay index-keyed and
  unmigrated, guarded only by `TierCountCannotShrink` (`DynamicFeeFlatPriceCurve.sol:882-884`). Reasoned as safe for
  booked earnings (they are already in `earned`) and for pending (index-keyed accumulators are untouched by an edge
  re-price), but not exercised. **Recommend a dedicated test.**
- `UNPROVEN` — **Cluster Δ, remaining files.** See the coverage caveat above.

---

## Cluster verdicts

| Cluster                                                   | Verdict                                  | Basis                                                 |
| --------------------------------------------------------- | ---------------------------------------- | ----------------------------------------------------- |
| **C1** — `DynamicFeeFlatPriceCurve` fee economy           | `VERDICT: FAIL`                          | R2-CLD-02 (Medium, unresolved, funds path)            |
| **C2** — `IBaseCurve` hook surface and dispatch           | `VERDICT: FAIL`                          | R2-CLD-01 (Major)                                     |
| **Δ** — delta since `b52557b`                             | `VERDICT: PASS` _(partial — see caveat)_ | No finding in the hunks reviewed; coverage incomplete |
| **A** — `MultiVault` payable multicall + value accounting | `VERDICT: PASS`                          | All §5.6 properties held under refutation             |
| **B** — `MultiVaultLib` storage-mirror integrity          | `VERDICT: FAIL`                          | R2-CLD-01 (mirror break), R2-CLD-04 (Minor)           |

**Headline severity count: 0 Critical · 1 Major · 1 Medium · 2 Minor · 1 Informational.**

---

## Appendix

### A1 — Methodology

Single vanilla frontier reasoner, no audit skill, no checklist, no subagent fan-out — working from the shared round
brief and the pinned source, deriving hypotheses from first principles and then attempting to refute each one. The round
was run under an independence guard: round-1 reports, the private internal-audits tree, and other round-2 reviewers'
outputs were not opened at any point.

Sequence:

1. **Pin scope.** Confirm the commit, confirm every assigned symbol resolves at that commit, and confirm the in-scope
   source is unmodified.
2. **Whole-contract read** of the assigned clusters, not diff-only.
3. **Hand-derive the conservation arithmetic** on both write paths before writing any test, so tests would be checking a
   specific predicted property rather than fishing.
4. **Rank hypotheses** by expected severity × novelty, then attack each with an executable probe against the
   repository's own deployment harness.
5. **Verify the landed fixes**, then **mutation-check** each by removing the guard from source and confirming the gating
   test turns red — a test green in both states proves nothing.
6. **Variant sweep** every confirmed break across single / batch / on-behalf-of / preview / router / upgrade-initializer
   paths.

### A2 — Tooling

Foundry `1.5.1-stable`, Solidity `0.8.29`, `evm_version = cancun`, optimizer on at 10 000 runs. All work local; no CI,
no `.github/**`, and the v1.0.2 baseline fork blocks untouched. Probes were executed from an isolated test root so that
a concurrent reviewer's in-progress files were not compiled into this round's runs.

### A3 — Reproducing the proofs of concept

The probes behind R2-CLD-01 through R2-CLD-04 and the two mutation checks were run as local, **uncommitted** Foundry
tests against the harness in `tests/BaseTest.t.sol` (`DynamicFeeFlatPriceCurve` at `curveId 4`, `LinearCurve` at
`curveId 1`, `defaultCurveId = 1`). They are not part of this repository's test suite by design — this round ships a
report, not test surface. Each finding above states its setup, call sequence, and observed values in full, so the
behavior can be re-derived without them.

Should any finding be accepted for remediation, the corresponding regression test named in that finding is the gate the
fix should be held to, and it must be shown red against the current implementation before the fix lands.

### A4 — Disclaimer

This is a **pre-audit artifact**: an internal, first-party adversarial review run before the external audit. It is
**not** a formal audit, certification, warranty, or guarantee of safety. It reflects one reviewer's coverage of the
clusters listed in Scope at one commit, with the limitations stated in the coverage caveat. Absence of a finding here is
not evidence of absence of a defect. Findings that exist only in not-yet-deployed code are not live-exploitable;
reconcile the go/no-go against what is actually deployed on-chain before treating any finding as blocking.
