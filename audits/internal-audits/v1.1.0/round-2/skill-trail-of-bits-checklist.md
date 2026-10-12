# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 4 of 7 — 370-item checklist, single reviewer (Solodit-anchored, 13 categories)

> **How this report was produced:** a single reviewer driving a 370-item, Solodit-anchored security checklist (13
> categories; `attacker-s-mindset`, `basics`, `heuristics`, `defi`, `token`, `signature`, `low-level`, `external-call`,
> `centralization-risk`, `timelock` loaded for this scope) over the v1.1.0 in-scope contract set, with every non-`N/A`
> verdict carried to a `file:line` citation and every confirmed break carried to an executed Foundry proof of concept.
> Verification was performed against an isolated checkout of the reviewed commit, with mutation checks on each claimed
> guard. Provenance ID prefix: `R2-TOB-`. One of 7 independent round reports; consolidated view:
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

---

## Metadata

| Field           | Value                                                                                                                  |
| --------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Artifact type   | Internal AI pseudo-audit — **pre-audit artifact**, not a formal audit, certification, warranty, or guarantee of safety |
| Target          | Intuition v1.1.0 core upgrade, public mirror (`intuition-contracts-v2`), extending PR #153                             |
| Reviewed commit | `8579c5e02e6fd1b58620565d5a6d06d3b9391548` (branch `feat/v1.1.0-core-upgrade`)                                         |
| Source root     | `src/`                                                                                                                 |
| Diff basis      | `main...HEAD`; delta-since-last-audit basis `b52557bc5d1e87537e621fc13917240d40044c24..8579c5e`                        |
| Target networks | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                              |
| Toolchain       | Solidity `0.8.29`, Foundry `1.5.1`, TransparentUpgradeableProxy                                                        |
| Date            | 2026-07-28                                                                                                             |
| Method          | Checklist-driven single-reviewer review + executed Foundry PoCs + guard mutation checks                                |

**Reviewed-tree note.** The reviewer's initial checkout carried in-flight modifications to `src/periphery/FeeProxy.sol`,
`src/protocol/emissions/TrustBonding.sol` and `tests/mocks/MockFeeHookCurve.sol` from a concurrent work stream. All
analysis, all proofs of concept and all mutation checks in this report were re-run against a **clean, isolated checkout
of `8579c5e`** so that no finding depends on uncommitted local state. `src/` at `8579c5e` is byte-identical to `src/` at
the branch tip `ac567b2ecd03d12e3e27c0ce570381ef9e383196` (the two commits differ only in `package.json`), so the
findings apply equally to the branch tip.

---

## 1. Executive summary

This round took the **`DynamicFeeFlatPriceCurve` fee economy** and the **standardized `IBaseCurve` hook surface and its
dispatch** as primary scope at full checklist depth — the two surfaces in the v1.1.0 pipeline with zero prior audit
coverage — then swept the delta since the last audited commit and the remaining in-scope set.

The MasterChef-style redistribution accumulator at the heart of the new curve **holds up**. Fee conservation,
depositor/exiter exclusion, quote-versus-record equality, the curve-ledger-to-vault-share mirror, retune-with-live-
positions, and flat-price round-trip non-profitability were each attacked directly and each survived with a cited
defence; the record-hook re-entry path — an external call moving native value after the vault's state writes — is closed
by the vault's reentrancy guard, confirmed by an adversarial curve that attempts the re-entry and is rejected. The
existing suite (1,984 tests) is green at the reviewed commit, and none of it covers the findings below.

The breaks are **not** in the accumulator arithmetic. They are at the **trust boundary around it** and in the **quote
surface exposed to integrators**:

- The curve owns a fee schedule that can consume **100% of a redemption**, its fee setters are **plain `onlyOwner` with
  immediate effect** while every equivalent `MultiVault` setter is timelock-gated, the shipped deploy script assigns
  that owner to the **deploying key** rather than a timelock, and `MultiVault` enforces **no floor on the redemption
  payout**. Composed, these let a single transaction burn a holder's shares, pay them nothing, and route their entire
  principal to a co-positioned account that can immediately withdraw it. Demonstrated end to end.
- Pointing `defaultCurveId` at a fee-hook curve **permanently and irrecoverably locks** every position created
  afterwards, because the term-creation paths mint vault shares without invoking the record hook and the curve's redeem
  hook then underflows on a ledger entry that was never written.
- `previewRedeem` quotes the curve's withdrawal fee off the **vault's** tier rather than the **holder's**, so it
  disagrees with execution in both directions — under-quoting the payout for early holders and over-quoting it after a
  retune, which turns `minAssets = previewRedeem(...)` into a redemption revert.

Both round-1 fixes carried into this round were verified and mutation-checked: removing the ERC-1271 digest binding
turns 8 signature tests red, and removing the zero-epoch-length guard turns its gating test red.

### Severity counts

| Severity          | Count | IDs                       |
| ----------------- | ----- | ------------------------- |
| **Critical**      | 0     | —                         |
| **Major**         | 2     | `R2-TOB-01`, `R2-TOB-02`  |
| **Medium**        | 1     | `R2-TOB-03`               |
| **Minor**         | 2     | `R2-TOB-04`, `R2-TOB-05`  |
| **Informational** | 5     | `R2-TOB-06` … `R2-TOB-10` |

**Headline:** 2 Major, 1 Medium, 2 Minor, 5 Informational.

---

## 2. Scope

### 2.1 In scope (reviewed at commit `8579c5e`)

| Contract                                      | Path                                                      | Depth this round                                         |
| --------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| `DynamicFeeFlatPriceCurve`                    | `src/protocol/curves/DynamicFeeFlatPriceCurve.sol`        | **Primary** — full checklist                             |
| `IDynamicFeeFlatPriceCurve`                   | `src/interfaces/IDynamicFeeFlatPriceCurve.sol`            | **Primary** — full checklist                             |
| `IBaseCurve`                                  | `src/interfaces/IBaseCurve.sol`                           | **Primary** — full checklist                             |
| `BaseCurve`                                   | `src/protocol/curves/BaseCurve.sol`                       | **Primary** — full checklist                             |
| `MultiVaultLib` (hook dispatch + write paths) | `src/libraries/MultiVaultLib.sol`                         | **Primary** — full checklist                             |
| `BondingCurveRegistry`                        | `src/protocol/curves/BondingCurveRegistry.sol`            | **Primary** — full checklist                             |
| `LinearCurve`                                 | `src/protocol/curves/LinearCurve.sol`                     | **Primary** — full checklist                             |
| `MultiVault`                                  | `src/protocol/MultiVault.sol`                             | Full — multicall/value accounting, setters, entry points |
| `MultiVaultCore`                              | `src/protocol/MultiVaultCore.sol`                         | Full                                                     |
| `AtomWallet`                                  | `src/protocol/wallet/AtomWallet.sol`                      | Full — plus landed-fix verification                      |
| `CoinbaseSmartWalletLib`                      | `src/libraries/CoinbaseSmartWalletLib.sol`                | Targeted — ERC-1271 hashing                              |
| `AtomWalletFactory`                           | `src/protocol/wallet/AtomWalletFactory.sol`               | Survey                                                   |
| `AtomWarden`                                  | `src/protocol/wallet/AtomWarden.sol`                      | Survey — delta is formatting-only                        |
| `TrustBonding`                                | `src/protocol/emissions/TrustBonding.sol`                 | Survey — pause-gating matrix                             |
| `CoreEmissionsController`                     | `src/protocol/emissions/CoreEmissionsController.sol`      | Full — plus landed-fix verification                      |
| `SatelliteEmissionsController`                | `src/protocol/emissions/SatelliteEmissionsController.sol` | Survey — Intuition-side accounting                       |
| `FeeProxy`                                    | `src/periphery/FeeProxy.sol`                              | Survey — refund-ledger conservation                      |

Also reviewed where reachable: `IMultiVault`, `IMultiVaultCore`, `IBondingCurveRegistry`, `IAtomWallet`, `IAtomWarden`,
`ITrustBonding`, and the deploy script `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol`.

### 2.2 Out of scope (not filed; boundary noted where touched)

Trust Swap and swap periphery; the bridge router / MetaLayer cross-chain transport leg; `BaseEmissionsController` and
all Base-chain components; the parked TVL exit circuit breaker / rate limiter; unbounded cross-curve counter-stake
aggregation; `MultiVaultMigrationMode`; `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib` except
insofar as they must remain safe hook no-ops; legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow`; the
held-out `AtomWallet` delegation framework (`executeFromExecutor`); and whole-surface mixed payable/non-payable
`multicallPayable` batching.

**One boundary note, filed because it is a precondition and not a centralization complaint.** The out-of-scope
acceptance of trusted-admin centralization is stated as resting on privileged actions being _"gated by a 4-of-8 Safe
acting through two `TimelockController`s (parameters 3-day, upgrades 7-day)."_ `R2-TOB-01` reports that the new curve's
privileged fee surface is **not** gated that way in code and is **not** wired that way by the shipped deploy script. The
finding is that the stated precondition does not hold for this contract — not that centralization exists.

### 2.3 Delta since the last audited commit

`git diff b52557b..8579c5e -- src/` reports 30 files, +1,537 / −875. Re-running the same diff with whitespace suppressed
shows the overwhelming majority is a **formatter reflow** (`forge fmt` parameter-list re-wrapping) with no semantic
content. The substantive delta is four changes:

1. the new `DynamicFeeFlatPriceCurve` (+912) and its interface;
2. the `IBaseCurve` fee-hook surface plus `BaseCurve`'s reverting/no-op defaults, and the `CurveHook` quote-carry struct
   and dispatch in `MultiVaultLib`;
3. the ERC-1271 replay-safe digest binding in `AtomWallet`;
4. the zero-epoch-length guard in `CoreEmissionsController`.

`AtomWarden` (±25), `LinearCurve` (±48), `BondingCurveRegistry` (±48), `TrustBonding` (±11), `MultiVaultCore` (±35),
`FeeProxy` (±78) and the interface files carry **no** semantic change in this delta. This is recorded because it
materially narrows what "unreviewed in its current form" means for this round.

---

## 3. Severity classification

Severity is assigned as **Impact × Likelihood**, taking the highest severity a _credible_ path reaches under the
intended deployment and trust model. Permissionless exploitability is scored separately from trusted-role misuse; a
trusted-role path is scored on impact when the trust assumption it relies on is **not actually implemented**.

|                       | **High impact** | **Medium impact** | **Low impact** |
| --------------------- | --------------- | ----------------- | -------------- |
| **High likelihood**   | Critical        | Major             | Medium         |
| **Medium likelihood** | Major           | Medium            | Minor          |
| **Low likelihood**    | Medium          | Minor             | Informational  |

| Label             | Meaning                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Critical**      | Permissionless or realistically reachable path to direct theft, permanent loss, insolvency, unrestricted mint/withdraw, or capture of upgrade/admin control.             |
| **Major**         | A core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade/configuration path corrupts critical state or permanently strands funds. |
| **Medium**        | Bounded loss, temporary stuck funds, realistic griefing or DoS of a funds path, an admin footgun, or a spec regression that materially affects users or operators.       |
| **Minor**         | Limited impact, weak validation blocked by another guard, confusing behaviour, monitoring or integration weakness.                                                       |
| **Informational** | Documentation, hygiene, NatSpec-versus-behaviour mismatch, missing non-critical test.                                                                                    |

---

## 4. Findings

### 4.1 `R2-TOB-01` — **Major** — A single non-timelocked curve fee retune burns an exiting holder's shares for zero payout and routes their principal to a co-positioned account

**Severity:** Major **Confidence:** High **Status:** Open **Invariant broken:** §5.2 (solvency / custody — the curve
must custody _only_ redistributed fee value, never principal) and §5.4 (flat-price par — "a holder's **maximum loss is
the fees they paid**"). **Disposition-override:** the §3 trusted-admin acceptance, whose stated precondition is timelock
gating.

#### Description

The dynamic-fee curve's withdrawal rate is owner-tunable with immediate effect, is bounded only by a cap that itself may
be set to `BPS` (100%), and is applied by `MultiVault` as a straight subtraction from the redeemer's payout with **no
floor**. Three independent gaps compose into one path:

1. **The fee can consume the whole redemption.** `_setConfig` accepts `withdrawalCapBps` up to `BPS` and
   `withdrawalBaseBps` up to that cap. `setTierFeeOverride` accepts any rate up to the same cap, for a **single tier** —
   which makes the action surgically targetable at one cohort, or one holder.
2. **There is no timelock and no delay.** `setConfig`, `setTierFeeOverride` and `clearTierFeeOverride` are plain
   `onlyOwner` and take effect in the same transaction. Every equivalent `MultiVault` fee setter is `onlyTimelock`. The
   shipped deploy script initializes the curve's owner to `msg.sender` — the deploying key — on **every** chain
   including mainnet, with an inline comment marking it as a PoC placeholder.
3. **`MultiVault` never checks that the redeemer receives anything.** `_calculateRedeem` subtracts the curve fee and
   `_validateRedeem` only compares the result against a **caller-supplied** `minAssets`. With `minAssets = 0` — the
   default in every convenience path — a redemption that returns zero succeeds and burns the shares. `previewRedeem`
   returns the same zero, so a front end deriving `minAssets` from the preview derives no protection either.

The confiscated value is not burned: it is credited to `accFeePerShare` for the residual holders of the exiting tier — a
position the owner can hold — and is immediately withdrawable via `claim`. This is value capture, not only griefing.

#### Code

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:249-251 — immediate, no timelock
function setConfig(DynamicFeeConfig calldata _config) external onlyOwner {
    _setConfig(_config);
}

// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:265-273 — single-tier targeting, cap is the only bound
function setTierFeeOverride(uint256 tier, uint16 newDepositFeeBps, uint16 newWithdrawalFeeBps) external onlyOwner {
    if (tier >= config.tierCount) revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
    if (newDepositFeeBps > config.depositCapBps || newWithdrawalFeeBps > config.withdrawalCapBps) {
        revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
    }
    ...
}

// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:894-896 — the cap may itself be BPS
if (_config.withdrawalBaseBps > _config.withdrawalCapBps || _config.withdrawalCapBps > BPS) {
    revert DynamicFeeFlatPriceCurve_InvalidConfig();
}
```

```solidity
// src/libraries/MultiVaultLib.sol:1067 — no floor on the payout
uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;

// src/libraries/MultiVaultLib.sol:1388-1392 — the only guard is the caller's own minAssets
(uint256 expectedAssets,,) = _calculateRedeem(termId, curveId, shares, account);
if (expectedAssets < minAssets) {
    revert MultiVault.MultiVault_SlippageExceeded();
}
```

```solidity
// script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:80 — owner is the deploying key on all chains
msg.sender, // owner for the PoC; migrate to the parameters timelock / admin Safe in prod
```

Contrast, same upgrade: `src/protocol/MultiVault.sol:819-822` — `setVaultFees(...) external onlyTimelock`.

#### Proof of concept

Executed against a clean checkout of `8579c5e`, default 13-tier schedule.

1. Beneficiary account deposits `2e18` into the term on the dynamic-fee curve and is bucketed at tier `0`.
2. Victim account deposits `40e18` into the same term and is also bucketed at tier `0`.
3. **Baseline (state snapshot, then reverted):** victim redeems in full and receives `37 118 408 000 000 018 818` wei.
4. Curve owner, in one transaction with no delay, calls `setConfig` raising `withdrawalCapBps` to `10_000`, then
   `setTierFeeOverride(0, 0, 9900)` — a 99% withdrawal rate applied to tier `0` only.
5. Victim executes the identical redemption with `minAssets = 0`.

Result:

| Quantity                                       | Value (wei)                  |
| ---------------------------------------------- | ---------------------------- |
| Victim payout, honest schedule                 | `37 118 408 000 000 018 818` |
| Victim payout, after retune                    | `0`                          |
| Beneficiary `claimable` gain                   | `37 883 736 000 000 019 204` |
| Beneficiary amount actually pulled via `claim` | `37 883 736 000 000 019 204` |

The victim's shares are burned; the victim receives nothing; the beneficiary withdraws the principal.

**Variant sweep.** The same zero payout reproduces via the schedule-wide `withdrawalBaseBps` (no override needed). At
exactly `BPS` the behaviour changes to a revert — the failure mode the NatSpec at `DynamicFeeFlatPriceCurve.sol:257-260`
documents — which means **the documented failure mode is the safe one and the undocumented one (99%, strictly inside the
cap) is the damaging one**. `previewRedeem` reports `0` and raises no error. Path coverage: single redeem — same bug;
`redeemBatch` — same bug (same `_processRedeem` body); on-behalf-of redeem — same bug; preview — silently agrees;
FeeProxy router — not a redeem router, n/a; upgrade initializer — n/a.

**Mutation check.** Re-running the identical sequence with `clearTierFeeOverride(0)` interposed pays the victim
`> 30e18`. The override is the operative cause, not a setup artefact.

#### Recommendation

1. **Floor the payout in `MultiVault`.** Reject a redemption that returns nothing, independently of `minAssets`:

   ```solidity
   // src/libraries/MultiVaultLib.sol, in _calculateRedeem
   -  uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;
   +  if (protocolFee + exitFee + hook.fee >= assets) revert MultiVault.MultiVault_RedeemYieldsNoAssets();
   +  uint256 assetsAfterFees = assets - protocolFee - exitFee - hook.fee;
   ```

2. **Bound the curve's cap against the vault's own fees, at config time**, so no schedule can be stored that is capable
   of zeroing a payout — e.g. require `withdrawalCapBps + protocolFeeBps + exitFeeBps <= BPS - MIN_PAYOUT_BPS` for a
   protocol-chosen `MIN_PAYOUT_BPS`.
3. **Put the curve's privileged surface behind the parameters `TimelockController`**, matching `MultiVault`'s
   `onlyTimelock` setters, and change the deploy script so the owner argument is the timelock rather than `msg.sender`.
   If a same-block emergency retune is genuinely required, split it: an immediate _fee-lowering_ path and a timelocked
   _fee-raising_ path.
4. Emit the previous and new rates in `ConfigUpdated` / `TierFeeOverrideSet` so a raise is monitorable.

#### Regression test

`CurveWithdrawalFeePayoutFloor.t.sol` — asserts a redemption always returns non-zero assets for non-zero shares across
the full admissible `withdrawalCapBps` range, and that a schedule capable of a zero payout is rejected at `setConfig`.
`CurveAdminTimelockParity.t.sol` — asserts the curve's fee setters revert for a non-timelock caller.

---

### 4.2 `R2-TOB-02` — **Major** — Pointing `defaultCurveId` at a fee-hook curve permanently locks every position created afterwards

**Severity:** Major **Confidence:** High **Status:** Open **Invariant broken:** §5.3 (the curve ledger mirrors vault
shares).

#### Description

The curve's redeem hook decrements a per-user ledger entry that only the **deposit** hook ever writes. The term-creation
paths (`_createAtom`, `_createTriple`) mint vault shares on the **default** curve and **never invoke the record hook** —
the hook is wired only into `_processDeposit`. While the default curve is hookless this is consistent. The moment
`defaultCurveId` is pointed at a curve that advertises the hooks, every term created afterwards mints vault shares with
no corresponding curve-ledger entry, and the holder's first redemption underflows inside the curve.

There is **no recovery path**. The curve exposes no function to seed or repair `userStake` / `tierStake` /
`vaultAssets`; the vault shares exist and can never be burned; and the registry is append-only so the curve id cannot be
re-pointed. Pointing `defaultCurveId` back at a hookless curve does not help — the affected vaults are keyed to the hook
curve's id.

`setBondingCurveConfig` accepts any `defaultCurveId` with no check that the target curve is hookless, and the asymmetry
between the create paths and the deposit path is not documented anywhere in the hook contract.

#### Code

```solidity
// src/libraries/MultiVaultLib.sol:568,577 — atom creation: default curve, no record hook
uint256 curveId = s.bondingCurveConfig.defaultCurveId;
...
_updateVaultOnCreation(sender, atomId, curveId, assetsAfterFees, sharesForReceiver, VaultType.ATOM);
// (no _recordCurveDeposit call anywhere in this path)

// src/libraries/MultiVaultLib.sol:646,654 — triple creation: same omission

// src/libraries/MultiVaultLib.sol:771 — only the deposit path records
_recordCurveDeposit(termId, receiver, hook, sharesForReceiver);
```

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:414-416 — the underflow site
_settle(termId, account);
userStake[termId][account] -= withdrawnStake;   // <-- reverts Panic(0x11) when never recorded
tierStake[termId][exitTier] -= withdrawnStake;
```

```solidity
// src/protocol/MultiVault.sol:825-828 — no guard on the target curve
function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external onlyTimelock {
    bondingCurveConfig = _bondingCurveConfig;
    emit BondingCurveConfigUpdated(_bondingCurveConfig.registry, _bondingCurveConfig.defaultCurveId);
}
```

#### Proof of concept

Executed against a clean checkout of `8579c5e`.

1. Timelock calls `setBondingCurveConfig({registry: <unchanged>, defaultCurveId: <dynamic-fee curve id>})`.
2. A user creates an atom with `10e18` through the ordinary `createAtoms` path.
3. Read back both ledgers.

| Reading                                   | Value                                                           |
| ----------------------------------------- | --------------------------------------------------------------- |
| Creator's vault shares on the curve id    | `9 799 019 999 999 020 000`                                     |
| Creator's `userStake` on the curve        | `0`                                                             |
| Curve's `vaultAssets` mirror for the term | `0`                                                             |
| `redeem(...)` of half the position        | reverts `0x4e487b71…0011` — `Panic(0x11)`, arithmetic underflow |

The position is unrecoverable by any on-chain action available to the user, the admin, the timelock, or the curve owner.

**Variant sweep.** `createAtoms` / `createAtomsFor` / `createTriples` / `createTriplesFor` — all four omit the record
hook, all four produce the same orphaned position. `deposit` / `depositBatch` — safe, they call `_recordCurveDeposit` on
both the new-vault and existing-vault branches (`MultiVaultLib.sol:755-771`). Preview — `previewRedeem` returns a
plausible non-zero number and gives no warning that execution will revert. Upgrade initializer — n/a. Min-share ghost
shares minted to `BURN_ADDRESS` are correctly excluded from the curve ledger by design and are not affected.

**Refutation attempted.** I tried to reach the same desync without touching `defaultCurveId`, and could not:
`BondingCurveRegistry` is strictly append-only (`addBondingCurve` rejects a duplicate address at
`BondingCurveRegistry.sol:92-94` and a duplicate name at `:104-106`, and no function overwrites `curveAddresses[id]`),
`MultiVault` exposes no share-transfer function, and `BURN_ADDRESS` cannot be redeemed from (`_isApprovedToRedeem` at
`MultiVaultLib.sol:1403-1405` plus the min-share floor at `:1383-1386`). The registry-swap variant — replacing the whole
`registry` address with one that maps the same id to a different curve — reaches the same class of desync and deserves
the same guard.

#### Recommendation

1. **Reject the configuration.** In `setBondingCurveConfig`, require that the target default curve advertises neither
   hook:

   ```solidity
   address defaultCurve = IBondingCurveRegistry(_bondingCurveConfig.registry)
       .curveAddresses(_bondingCurveConfig.defaultCurveId);
   if (defaultCurve == address(0)) revert MultiVault_InvalidDefaultCurve();
   if (IBaseCurve(defaultCurve).hasDepositFeeHook() || IBaseCurve(defaultCurve).hasRedeemFeeHook()) {
       revert MultiVault_DefaultCurveMustBeHookless();
   }
   ```

2. **Or** close the asymmetry properly by invoking `_recordCurveDeposit` from the create paths as well, which is the
   more durable fix and removes the constraint entirely.
3. Either way, state the invariant explicitly in `IBaseCurve`'s `recordDeposit` NatSpec: the hook surface assumes the
   curve is never the default curve, because term creation bypasses it.

#### Regression test

`DefaultCurveHookExclusion.t.sol` — asserts `setBondingCurveConfig` reverts when the target default curve advertises
either hook, and that a term created on a hook curve through every create path is redeemable.

---

### 4.3 `R2-TOB-03` — **Medium** — `previewRedeem` quotes the curve fee off the vault's tier, not the holder's, and disagrees with execution in both directions

**Severity:** Medium **Confidence:** High **Status:** Open **Invariant broken:** none of §5 directly — spec/integration
regression that materially affects users and operators.

#### Description

`quoteRedeemFee` keys the withdrawal rate on the redeeming account's recorded tier, falling back to the vault's current
tier when the account has no tracked stake. The account-less preview path passes `address(0)`, so `previewRedeem` always
takes the fallback and prices the redemption at the **vault's** tier. Because a holder's tier is their stake-weighted
average _entry_ tier, it routinely differs from the vault's current tier — in either direction — so the preview and the
execution disagree.

The direction matters:

- **Holder below the vault's tier** (an early holder in a grown vault): the preview applies the _higher_ vault-tier rate
  and **under-states** the payout. Integrators quote users a worse number than they get.
- **Holder above the vault's tier** (after a net outflow, or after a `setConfig` retune that widens the ladder): the
  preview applies the _lower_ vault-tier rate and **over-states** the payout. An integrator that sets
  `minAssets = previewRedeem(...)` — the natural and documented use of a preview function — has its redemption
  **reverted** by the slippage guard.

The second direction is a functional denial of service on the redeem path, triggerable by an ordinary owner retune with
no malicious intent.

#### Code

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:321-329
function quoteRedeemFee(bytes32 termId, address account, uint256 grossAssets)
    external view override returns (uint256 fee)
{
    uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultAssets[termId]);
    return grossAssets.mulDivUp(_withdrawalFeeBps(tier), BPS);
}
```

```solidity
// src/libraries/MultiVaultLib.sol:1062-1065 — execution passes the real account …
hook.curve = _redeemFeeHookCurve(curveId);
if (hook.curve != address(0)) {
    hook.fee = IBaseCurve(hook.curve).quoteRedeemFee(termId, account, assets);
}
// … while the account-less preview wrapper reached from MultiVault.previewRedeem
//    (src/protocol/MultiVault.sol:447-454) supplies address(0).
```

#### Proof of concept

Both directions executed against a clean checkout of `8579c5e`.

**Under-statement.** Holder enters with `3e18` (tier `0`); vault then grows to tier `4` via two `120e18` deposits.

|                    | Value (wei)                 | Rate    |
| ------------------ | --------------------------- | ------- |
| Vault tier / rate  | 4                           | 400 bps |
| Holder tier / rate | 0                           | 200 bps |
| `previewRedeem`    | `2 764 499 999 999 078 500` |         |
| Actual `redeem`    | `2 822 699 999 999 059 100` |         |

Preview under-states by `58 200 000 000 019 400` wei (~2.1%).

**Over-statement (redeem DoS).** Two holders enter at `60e18` each, reaching tier `4`; owner then calls `setConfig`
raising `width0` from `5 000e18` to `10 000e18`, which drops the vault into tier `0` while holders remain recorded at
tier `4`.

|                                | Value (wei)                  | Rate    |
| ------------------------------ | ---------------------------- | ------- |
| Holder recorded tier / rate    | 4                            | 400 bps |
| Vault tier after retune / rate | 0                            | 200 bps |
| `previewRedeem`                | `55 290 000 000 000 000 000` |         |
| Actual `redeem`                | `54 150 000 000 000 000 000` |         |

Preview over-states by `1 140 000 000 000 000 000` wei. Passing that preview as `minAssets` reverts the redemption with
`MultiVault_SlippageExceeded`.

**Variant sweep.** `previewRedeem` — broken both directions. `convertToAssets` — does not apply curve fees at all, so it
is not affected but is also not a usable payout quote. `maxRedeem` — share-denominated, unaffected. Execution paths
(`redeem`, `redeemBatch`, on-behalf-of) — all pass the real account and are internally consistent; the divergence is
preview-versus-execution only, so no value is lost on-chain.

#### Recommendation

Add an account-aware preview. Either overload `previewRedeem(bytes32,uint256,uint256,address)` and route the account
through to `_calculateRedeem`, or make the existing `previewRedeem` take the caller as the account. If the account-less
signature must stay for ABI compatibility, document in `IBaseCurve.quoteRedeemFee` and in `IMultiVault.previewRedeem`
that the returned figure is **not** the fee a specific holder will pay, and that it must not be used to derive
`minAssets`.

#### Regression test

`RedeemPreviewAccountParity.t.sol` — asserts `previewRedeem(..., account) == redeem(...)` for holders both above and
below the vault's current tier, and across a `setConfig` retune.

---

### 4.4 `R2-TOB-04` — **Minor** — A deposit-fee cap inside the allowed envelope underflows the fee netting and bricks all deposits on the curve

**Severity:** Minor **Confidence:** High **Status:** Open **Invariant broken:** none — availability / admin footgun.

#### Description

The curve's deposit fee is quoted on `assetsAfterMinSharesCost` — the base **before** MultiVault's own fees — but is
then subtracted from `assetsAfterFees`, the amount **after** protocol, entry and atom-wallet fees have already been
taken. When the curve's deposit rate plus MultiVault's own rates exceed 100%, the subtraction underflows and every
deposit on that curve reverts until the schedule is retuned.

`_setConfig` permits `depositCapBps` up to `BPS`, so a schedule that bricks the curve is storable. The mirror hazard on
the withdrawal side is explicitly documented at `DynamicFeeFlatPriceCurve.sol:257-260`; the deposit side is not
documented anywhere.

#### Code

```solidity
// src/libraries/MultiVaultLib.sol:959-963 (atom) and :1021-1025 (triple) — identical shape
hook.curve = _depositFeeHookCurve(curveId);
if (hook.curve != address(0)) {
    hook.fee = IBaseCurve(hook.curve).quoteDepositFee(termId, assetsAfterMinSharesCost);
    assetsAfterFees -= hook.fee;    // <-- underflows; assetsAfterFees is already net of MultiVault fees
}

// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:891-893 — cap may be BPS
if (_config.depositBaseBps > _config.depositCapBps || _config.depositCapBps > BPS) {
    revert DynamicFeeFlatPriceCurve_InvalidConfig();
}
```

#### Proof of concept

With `depositBaseBps = 9990`, `depositGrowthBps = 0`, `depositCapBps = 10_000` — all accepted by `setConfig` — a `10e18`
deposit on the curve reverts. Confirmed by execution. Both the atom and triple calculation paths carry the identical
expression, so the failure is total for the curve.

Note the quoting base is also a design wrinkle in its own right: because the fee is quoted on the pre-MultiVault-fee
base and deducted from the post-fee net, the _effective_ rate a depositor pays on their net stake is strictly higher
than the advertised bps. This is documented in `IBaseCurve.quoteDepositFee` ("post-min-shares cost,
pre-MultiVault-fees") and is therefore intended, but it is the reason the safe cap is well below `BPS`.

#### Recommendation

Validate the combined envelope at `setConfig` time rather than discovering it on the hot path, and document the
deposit-side hazard alongside the withdrawal-side one:

```solidity
// clamp so the curve fee can never exceed what remains after the vault's own fees
if (_config.depositCapBps > BPS - MAX_VAULT_SIDE_DEPOSIT_BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
```

Alternatively, saturate rather than underflow
(`assetsAfterFees = assetsAfterFees > hook.fee ? assetsAfterFees - hook.fee : 0`) — but only in combination with the
payout/mint floor from `R2-TOB-01`, since a silent zero is worse than a revert here.

#### Regression test

`DepositFeeEnvelopeBound.t.sol` — asserts every `setConfig`-accepted schedule admits a successful deposit.

---

### 4.5 `R2-TOB-05` — **Minor** — `claimable` folds the cross-vault `earned` balance into every per-term reading

**Severity:** Minor **Confidence:** High **Status:** Open **Invariant broken:** none — accounting view correctness.

#### Description

`earned` is a single balance keyed by user only, shared across every vault. `claimable(account, termId)` returns
`earned[account] + pending(termId)`. A holder with banked earnings and stake in more than one vault therefore sees the
same `earned` amount reported in each per-term reading. Any consumer that iterates a user's terms and sums `claimable`
over-reports the withdrawable total by `(numberOfTerms - 1) × earned`.

The on-chain payout is correct — `claim` zeroes `earned` once — so this is a view/indexer defect, not a value defect. It
is nonetheless a realistic source of a wrong balance in a UI or a rewards dashboard.

#### Code

```solidity
// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:147-148 — cross-vault, keyed by user only
mapping(address user => uint256 amount) public earned;

// src/protocol/curves/DynamicFeeFlatPriceCurve.sol:483-492
function claimable(address account, bytes32 termId) external view returns (uint256 amount) {
    ...
    return earned[account] + pending;   // <-- `earned` is not per-term
}
```

#### Proof of concept

A holder with stake in two terms re-deposits into the first term only, which banks that term's pending into `earned` via
`_settle` (`DynamicFeeFlatPriceCurve.sol:349`) while the second term's pending stays unsettled.

| Reading                                         | Value (wei)                 |
| ----------------------------------------------- | --------------------------- |
| `claimable(holder, term1)`                      | `2 014 049 999 999 971 044` |
| `claimable(holder, term2)`                      | `1 007 024 999 999 985 522` |
| Sum of per-term readings                        | `3 021 074 999 999 956 566` |
| Amount actually paid by `claim([term1, term2])` | `2 014 049 999 999 971 044` |

Over-reported by `1 007 024 999 999 985 522` wei — exactly the banked `earned` counted twice.

#### Recommendation

Split the view so the two components are separately addressable, and document that they must not be summed naively:

```solidity
/// @notice Unsettled pending for one vault only.
function pendingFor(address account, bytes32 termId) external view returns (uint256);
/// @notice Banked, vault-independent earnings.  Add ONCE across any set of terms.
function bankedEarnings(address account) external view returns (uint256);
/// @notice Total withdrawable across the supplied terms.
function claimableAcross(address account, bytes32[] calldata termIds) external view returns (uint256);
```

Keep `claimable` for ABI compatibility with a NatSpec warning.

#### Regression test

`CurveClaimableViewSummation.t.sol` — asserts `claimableAcross(user, terms) == claim(terms)` for a holder with banked
earnings across multiple vaults.

---

### 4.6 Informational

| ID          | Location                                                                            | Note                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ----------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `R2-TOB-06` | `DynamicFeeFlatPriceCurve.sol:127`, `:390`, `:449`; `MultiVaultLib.sol:855`, `:864` | **Unit coupling is implicit and unpinned.** The curve's `vaultAssets` accumulates _share_ amounts (the record hooks are handed `sharesForReceiver` / `shares`), while the tier ladder `_tierUpperEdge` is denominated in _assets_ (TRUST wei). The two agree only because a non-default-curve vault holds price at exactly 1:1 — entry and exit fees are routed to the **default** curve's vault (`MultiVaultLib.sol:1086-1091`), not the depositing curve's, so the dynamic curve's `totalAssets/totalShares` never drifts. That coupling is load-bearing for every tier decision and every fee rate, is not asserted anywhere, and would break silently if a future change credited pro-rata value to a non-default vault. Recommend an explicit invariant test pinning `currentSharePrice(term, dynamicCurveId) == 1e18` and a NatSpec note on `vaultAssets`. |
| `R2-TOB-07` | `MultiVaultLib.sol:790`, `:794`                                                     | **The curve fee is quoted twice per redemption.** `_validateRedeem` runs `_calculateRedeem` for the slippage check and `_processRedeem` runs it again for execution, so each redemption makes two extra `STATICCALL`s into the curve (four including the registry lookups). Correctness is safe — `quoteRedeemFee` is `view`, so the curve cannot mutate between the two calls, and no MultiVault state changes in between; I confirmed with an adversarial curve returning different answers on different _transactions_ that the guard binds and the redemption is rejected rather than slipping through. This is a gas and design-hygiene note, and the deposit path already solves it with the `CurveHook` quote-carry struct; the redeem path could carry the same way.                                                                                     |
| `R2-TOB-08` | `DynamicFeeFlatPriceCurve.sol:257-260`                                              | **NatSpec describes the wrong failure mode.** The comment states that an over-large withdrawal rate "underflows `assets - fees` in MultiVault, bricking redeems for that tier until retuned" — i.e. a revert, funds safe. Empirically the revert only occurs at exactly `BPS`; at any rate strictly inside the cap the redemption _succeeds_ and pays zero. Reword to describe the zero-payout mode, which is the one that loses value. See `R2-TOB-01`.                                                                                                                                                                                                                                                                                                                                                                                                         |
| `R2-TOB-09` | `DynamicFeeFlatPriceCurve.sol:139`, `:142`, `:862-866`                              | **`userTier` and `userAvgTier` diverge after a `tierCount` growth.** `_roundTier` caps the stored bucket at `tierCount - 1` while `userAvgTier` retains the uncapped weighted average. Growing `tierCount` later lets a holder's next deposit resolve to a much higher bucket than their previous one, in a single jump. Bookkeeping stays consistent (every `tierStake` move keys off the stored `userTier`, which I verified holds across the retune probe), so there is no accounting break — but the behaviour is surprising and undocumented.                                                                                                                                                                                                                                                                                                               |
| `R2-TOB-10` | `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:121-137`                     | **The shipped schedule is marked a placeholder.** `_defaultConfig` is explicitly labelled "PLACEHOLDER: the final production numbers … are pending the economic modeling". Because `setConfig` is the same immediate `onlyOwner` entry point discussed in `R2-TOB-01`, the intended post-deploy tuning workflow _is_ the risky path. Resolving `R2-TOB-01` also resolves the operational exposure here.                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

---

## 5. Properties checked (negatives)

Each line records the property, the attack attempted against it, and the guard that defeated the attack. Per the round's
protocol, a `PASS` without a recorded refutation attempt is not a `PASS`.

### Cluster C1 — `DynamicFeeFlatPriceCurve` fee economy

- **PASS — §5.1 fee conservation, no over-assignment.** Tried to make `sum(claimable) + protocolAccrued` exceed the
  curve's custody across a nine-step interleaving of deposits, partial redeems, a full exit and a re-entry across three
  holders. Result: assigned `1 841 855 819 999 941 678` wei against a balance of `1 841 855 819 999 941 742` wei — a
  64-wei under-assignment, never an over-assignment. Defended by floor-rounding in both directions: `mulDiv` on the
  per-tier share at `DynamicFeeFlatPriceCurve.sol:647` and `fullMulDiv` on the accumulator at `:649`, with the shortfall
  explicitly swept to `protocolAccrued` at `:627-631`.
- **PASS — every distributed fee has exactly one home.** Tried empty prior tiers, a whale exit leaving no residual
  cohort, and a first-tier deposit with no prior tier at all. Each routes deterministically: nearest-occupied-prior for
  the spike (`:559-567`), nearest-occupied above-then-below for the diamond slice (`:434-441`, `:769-786`),
  nearest-to-fulcrum for a σ-zeroed window (`:621-624`, `:693-719`), and `protocolAccrued` only when no tier holds stake
  (`:606-610`, `:715-718`). No path forfeits or double-books.
- **PASS — depositor excluded from their own deposit fee.** Tried to have a large depositor capture their own fee by
  depositing into a tier they already occupy. Claimable before and after the self-funded deposit are identical. Defended
  by the exclusion denominator at `:674-676` combined with the post-distribution debt re-base at `:389`.
- **PASS — exiter excluded from their own withdrawal fee.** Same attack on the redeem side; claimable unchanged across
  the exiter's own partial exit. Defended by `denom = tierStake[exitTier] - residual` at `:424` and the re-base at
  `:448`.
- **PASS — §5.3 curve ledger mirrors vault shares.** Tried to desync `userStake` from the vault's `balanceOf` through a
  four-deposit / one-partial-redeem interleaving across three holders. `userStake == getShares` held per holder, and
  `sum(userStake) == sum(tierStake) == vaultAssets` held exactly. (The _configuration_ that breaks this is filed as
  `R2-TOB-02`.)
- **PASS — §5.4 no profitable round trip.** Fuzzed 10,000 runs of deposit-then-full-redeem-then-claim over deposit
  amounts `1e18…500e18` against seed positions `1e18…500e18`. Ending balance never exceeded the starting balance.
- **PASS — retune with live positions preserves booked entitlement.** Tried to move a holder's earnings by
  simultaneously changing `width0` (5,000e18 → 500e18), `tierCount` (13 → 20), `growthGBps` (2000 → 500), `kernelSpread`
  (4e18 → 1e18) and `fulcrumAlpha` (BPS → 0). Claimable was byte-identical before and after, and a subsequent `claim`
  paid exactly the reported figure. Defended by index-keyed accumulators — `setConfig` writes no per-user or per-tier
  accounting slot (`:875-911`).
- **PASS — `tierCount` cannot shrink.** Tried to strand an occupied bucket above the schedule. Rejected by
  `DynamicFeeFlatPriceCurve_TierCountCannotShrink` at `:882-884`.
- **PASS — degenerate schedules rejected before any position exists.** Tried `width0 = 0`, `tierCount = 0`,
  `tierCount > MAX_TIER_COUNT`, `kernelSpread = 0`, `kernelSpread > MAX_KERNEL_SPREAD`, `fulcrumAlpha > BPS`, and an
  over-steep `growthGBps`. All rejected at `:876-906`, with the top-edge probe at `:906` catching the schedules whose
  `rpow` / `fullMulDiv` would revert on the hot path.
- **PASS — tier-edge math cannot underflow the piecewise fee walk.** Reasoned through `edge(k) - edge(k-1)` for the
  floor-divided geometric series and confirmed the per-step true difference is `>= width0 >= 1`, so edges are strictly
  increasing and `room = _tierUpperEdge(tier) - cursor` at `:838` cannot underflow; a degenerate zero-width band would
  yield `chunk = 0` and advance the loop rather than revert. The `g == 0` branch at `:745` is a plain multiple, bounded
  by `type(uint128).max * 64`.
- **PASS — accumulator inflation is not a practical DoS.** Tried to drive `accFeePerShare` toward overflow by repeatedly
  distributing into a 1-wei denominator so that `_settle` would revert and wedge redeems for a tier. Reaching an
  overflowing product requires on the order of `1e17` TRUST of fees at realistic stake sizes; not reachable. Bounded by
  `fullMulDiv`'s 512-bit intermediate at `:532`.
- **PASS — `claim` is re-entrancy safe and idempotent.** Tried duplicate `termIds` in one call and a re-entrant
  recipient. Duplicates settle to a no-op on the second pass (`accumulated == debt` at `:534`); `earned` is zeroed
  before `Address.sendValue` at `:473-474` and the function is `nonReentrant`.
- **PASS — principal never sits in the curve (§5.2).** Traced every value transfer: on deposit only `hook.fee` is
  forwarded (`MultiVaultLib.sol:855`); on redeem only `hook.fee` (`:864`), with the holder's `assetsAfterFees` paid
  directly from the vault at `:810`. `sweepProtocol` can only move `protocolAccrued` (`:285-292`).
- **PASS — `onlyMultiVault` gates both record hooks.** Tried calling `recordDeposit` and `recordRedeem` directly.
  Rejected at `:196-198`.

### Cluster C2 — `IBaseCurve` hook surface and dispatch

- **PASS — quote-then-record equality, single path.** Netted fee `412 149 999 999 990 350` wei equalled the value
  forwarded to the curve, exactly. Defended by dataflow: the quote is resolved once into `CurveHook` at
  `MultiVaultLib.sol:959-963` and forwarded verbatim at `:855`, never re-quoted.
- **PASS — quote-then-record equality, batch path.** Two-leg `depositBatch`: `q1 + q2 = 431 224 999 999 985 525` wei
  equalled the curve's balance delta exactly.
- **PASS — both deposit quote sites agree.** `_calculateAtomDeposit` (`:959-963`) and `_calculateTripleDeposit`
  (`:1021-1025`) are textually identical in shape and both quote on `assetsAfterMinSharesCost`; confirmed by inspection
  and by the atom/triple parity of the executed probes.
- **PASS — §5.6 the record hook cannot re-enter for phantom value.** Registered an adversarial curve that re-enters
  `MultiVault.deposit` from inside `recordDeposit`, executed inside a `multicallPayable` leg while `_inMulticall` is
  `true` and `_virtualMsgValue` is still set to that leg's allocation. The re-entry was attempted and **rejected** with
  `0x3ee5aeb5` (`ReentrancyGuardReentrantCall`); the curve received zero phantom shares. Defended by `nonReentrant` on
  `MultiVault.deposit` (`MultiVault.sol:702`), which holds even though the hook fires after the vault's state writes.
- **PASS — nested multicall rejected.** `multicallPayable` composed inside `multicallPayable` is rejected by the upfront
  selector allowlist with `MultiVault_PayableMulticallSelectorNotAllowed` (`MultiVault.sol:598-605`), before the
  `_inMulticall` guard is even reached.
- **PASS — multicall value conservation.** A two-leg payable batch moved exactly `msg.value` from the caller and no
  more; a `sum(values) != msg.value` batch was rejected with `MultiVault_MulticallValueMismatch` (`MultiVault.sol:612`).
- **PASS — hookless curves are safe no-ops.** A deposit and redeem on the default `LinearCurve` moved zero value to the
  curve address. A mock curve registered with both hook getters returning `false` recorded **zero** `recordDeposit` and
  `recordRedeem` calls and received zero value across a deposit and a redeem. Defended by the gating at
  `MultiVaultLib.sol:832-843` and the address-zero short-circuits at `:854`, `:863`.
- **PASS — the address-zero guard in hook resolution is load-bearing as documented.** An unregistered curve id resolves
  to `address(0)` and falls through, so the canonical `BondingCurveRegistry_InvalidCurveId` still surfaces from the
  pricing call rather than a bare call-to-codeless-account revert (`:832-836`).
- **PASS — a curve cannot flip its hook answer between quote and record.** The decision is captured once into
  `CurveHook.curve` during calculation and is never re-resolved (`:851-856`, `:862-865`), so a getter that flips
  mid-transaction cannot desync the netted and forwarded amounts.
- **PASS — a curve cannot drift its redeem quote between validation and execution.** Registered a curve returning
  different fees on different calls; the redemption was rejected by `MultiVault_SlippageExceeded` rather than slipping
  through. `quoteRedeemFee` is `view` (hence `STATICCALL`), and no MultiVault state changes between `_validateRedeem`
  and `_calculateRedeem`, so the two in-transaction quotes are necessarily equal. Noted as a design-hygiene item at
  `R2-TOB-07`.
- **PASS — the registry is strictly append-only.** Tried to re-point an existing curve id, register a duplicate address,
  and register a duplicate name. All three are impossible: no function writes `curveAddresses[id]` for an existing id,
  duplicates are rejected at `BondingCurveRegistry.sol:92-94`, and names at `:104-106`.
- **PASS — `BaseCurve` defaults fail closed.** The four default hook bodies revert with `BaseCurve_FeeHooksNotSupported`
  and the two getters return `false` (`BaseCurve.sol:152-180`), so a curve that forgets to override cannot silently
  accept value.

### Landed round-1 fixes — verify plus mutation check

- **`MED-01` ERC-1271 digest binding — VERIFIED, guard is load-bearing.** The validated digest is wrapped in
  `replaySafeHash` (`AtomWallet.sol:336-337`), whose EIP-712 domain separator commits to both `block.chainid` and
  `address(this)` (`CoinbaseSmartWalletLib.sol:303-320`), with fixed domain name/version constants at
  `AtomWallet.sol:73-74` that no caller can influence. **Mutation:** replacing the wrapped digest with the raw hash
  turns **8** signature tests red across `AtomWalletAuthEdges`, `AtomWalletTakeover` and `AtomWallet` — including the
  ECDSA, the P-256/WebAuthn, the multi-owner-index, the post-transfer and the re-added-owner cases. I additionally
  attacked the `validateUserOp` / `isValidSignature` asymmetry: `_validateSignature` uses an EIP-191 personal-sign
  wrapper over `userOpHash` (`AtomWallet.sol:491`) rather than `replaySafeHash`, but `userOpHash` is already bound to
  the wallet, the chain and the EntryPoint by the ERC-4337 hashing rule, and the two digests are structurally disjoint —
  so no signature is replayable across the two paths in either direction. Cross-wallet and cross-chain replay of an
  ERC-1271 signature are both closed by the domain separator. **PASS.**
- **`MED-02` zero epoch length rejected — VERIFIED, coverage is complete.** `_validateEmissionsLength` reverts on zero
  (`CoreEmissionsController.sol:129-133`) and is called from the shared initializer at `:54`. I enumerated every writer
  of `_EPOCH_LENGTH`: the only assignment is at `:60`, inside `__CoreEmissionsController_init`, downstream of the guard;
  no setter mutates it anywhere in the tree. Both controllers route through that initializer —
  `SatelliteEmissionsController.sol:74` (in scope) and `BaseEmissionsController.sol:78` (out of scope, checked for
  completeness). The sibling validators for start timestamp, per-epoch amount, cliff and reduction basis points are
  applied on the same path (`:53-57`), so no other degenerate value reaches the same failure mode. **Mutation:**
  deleting the `_validateEmissionsLength` call turns `test_initialize_revertsWhenEmissionsLengthIsZero` red. **PASS.**

### Remaining in-scope clusters

- **PASS — cluster A, `multicallPayable` value accounting (§5.6).** Covered by the four multicall negatives above.
  `_effectiveMsgValue()` is read by all six allowlisted payable entry points (`MultiVault.sol:660-717`) and never raw
  `msg.value`; canonical `multicall` forces `_virtualMsgValue = 0` (`:518`) so a payable leg composed inside it cannot
  claim phantom value; transient state is cleared on the success path (`:631-632`) and any revert unwinds the whole
  transaction, taking the transient slots with it.
- **PASS — cluster B, `MultiVaultLib` storage-mirror integrity (§5.5).** The library's `Storage` struct is anchored at
  slot 0 (`MultiVaultLib.sol:97-160`) and its field order matches `MultiVault`'s declaration order through
  `lastSystemUtilizationEpoch` at slot 37, with the `__gap[47]` following (`MultiVault.sol:145-148`). Tried to find a
  reordered, retyped or overlapping slot by walking both declarations side by side; found none. The repository's own
  storage-layout regression suite is green at this commit.
- **PASS — cluster D, `AtomWarden` quorum and window cap.** The delta since the last audited commit is **formatting
  only** — verified by a whitespace-suppressed diff showing no semantic change in `AtomWarden.sol`. The
  strictly-ascending-signer-order rule and the fixed-window cap accounting were re-read against the round-1 dispositions
  and no new angle was found that the disposition register does not already cover.
- **PASS — cluster E, `AtomWallet` auth.** Covered by the `MED-01` verification above.
- **PASS — cluster F, `TrustBonding` pause asymmetry.** Confirmed the intended matrix by enumeration: all six
  lock-taking entry points plus `claimRewards` carry `whenNotPaused` (`TrustBonding.sol:380`, `:445`, `:451`, `:457`,
  `:463`, `:469`, `:478`); `withdraw` and `checkpoint` carry no pause modifier, so no funds are trapped and accounting
  cannot go stale while paused. Matches the known accepted disposition; no new angle.
- **PASS — cluster G, `FeeProxy` refund ledger.** Tried double-claim, claim-after-push and cross-user attribution.
  `_claimRefundTo` zeroes `pendingRefund[msg.sender]` before `Address.sendValue` (`FeeProxy.sol:566-570`) and both entry
  points are `nonReentrant` (`:392`, `:397`); `_refundExcess` credits `msg.sender` only (`:714-718`); every
  value-bearing entry point asserts `msg.value >= totalGross` before forwarding (`:272`, `:549`). Delta since the last
  audited commit is formatting only.
- **PASS — cluster H, emissions controllers (Intuition side).** Covered by the `MED-02` verification above; the
  remaining schedule arithmetic carries no semantic delta in this window.

---

## 6. Cluster verdicts

| Cluster | Scope                                             | Verdict                                                                                                                         |
| ------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **C1**  | `DynamicFeeFlatPriceCurve` fee economy            | **VERDICT: FAIL** — `R2-TOB-01` (Major), `R2-TOB-04`, `R2-TOB-05`                                                               |
| **C2**  | `IBaseCurve` hook surface and dispatch            | **VERDICT: FAIL** — `R2-TOB-02` (Major), `R2-TOB-03` (Medium)                                                                   |
| **Δ**   | Delta since `b52557b`                             | **VERDICT: PASS** — substantive delta is four changes; two are the verified round-1 fixes, two are C1/C2 and are reported there |
| **A**   | `MultiVault` payable multicall + value accounting | **VERDICT: PASS**                                                                                                               |
| **B**   | `MultiVaultLib` storage-mirror integrity          | **VERDICT: PASS**                                                                                                               |
| **D**   | `AtomWarden` quorum + per-window cap              | **VERDICT: PASS**                                                                                                               |
| **E**   | `AtomWallet` ERC-4337 / P-256 auth                | **VERDICT: PASS**                                                                                                               |
| **F**   | `TrustBonding` emissions + pause                  | **VERDICT: PASS**                                                                                                               |
| **G**   | `FeeProxy` refund ledger + approval gating        | **VERDICT: PASS**                                                                                                               |
| **H**   | Emissions controllers (Intuition side)            | **VERDICT: PASS**                                                                                                               |

**Round verdict: FAIL** — two Major findings on funds paths, both open.

### Invariant scorecard (§5)

| Invariant                                             | Verdict  | Reference                 |
| ----------------------------------------------------- | -------- | ------------------------- |
| §5.1 Conservation of value                            | **PASS** | Negatives, cluster C1     |
| §5.2 Solvency / curve custody                         | **FAIL** | `R2-TOB-01`               |
| §5.3 Curve ledger mirrors vault shares                | **FAIL** | `R2-TOB-02`               |
| §5.4 Flat-price par ("max loss is the fees you paid") | **FAIL** | `R2-TOB-01`               |
| §5.5 Storage-layout upgrade safety                    | **PASS** | Negatives, cluster B      |
| §5.6 No `msg.value`-replay in `multicallPayable`      | **PASS** | Negatives, cluster C2 / A |

---

## 7. Appendix

### 7.1 Methodology

A single reviewer walked a 370-item Solodit-anchored checklist spanning 13 categories, loading `attacker-s-mindset`,
`basics`, `heuristics`, `defi`, `token`, `signature`, `low-level`, `external-call`, `centralization-risk` and `timelock`
as the scope justified. Because this round's primary surface is a fee-redistribution accumulator, the `defi` accounting
and rounding-direction items carried the most weight; `hash-merkle-tree`, `multi-chain-cross-chain` and `integrations`
were not loaded — the in-scope set contains no Merkle distribution, and the cross-chain transport leg and all
third-party protocol integrations are out of scope.

Every non-`N/A` verdict is carried to a `file:line` citation. Every property recorded as a negative carries the
refutation that was attempted against it, per the round's rule that an unattempted `PASS` is not a `PASS`. Every Major
finding carries an executed Foundry proof of concept with before/after figures. Every claimed guard was
mutation-checked: the guard was removed and the gating test confirmed to go red.

### 7.2 Tooling and environment

- Foundry `1.5.1` (`forge 1.5.1-stable`), Solidity `0.8.29`.
- Proofs of concept executed against an isolated `git worktree` at `8579c5e`, with dependency submodules linked from the
  primary checkout, to guarantee no uncommitted local modification influenced any result.
- Baseline: the repository's existing suite at the reviewed commit — **1,984 tests across 114 suites, 0 failures**.
  Every finding in this report is uncovered by that suite; prior green was treated as an input, not as evidence.
- Fuzzing: 10,000 runs on the round-trip extraction property.
- Local only. No CI, `.github/**`, or fork-block changes; no action against any live deployment.

### 7.3 Regression tests proposed

Named for the mechanism they exercise, carrying no round, reviewer or finding-id provenance:

| Test                                  | Gates       |
| ------------------------------------- | ----------- |
| `CurveWithdrawalFeePayoutFloor.t.sol` | `R2-TOB-01` |
| `CurveAdminTimelockParity.t.sol`      | `R2-TOB-01` |
| `DefaultCurveHookExclusion.t.sol`     | `R2-TOB-02` |
| `RedeemPreviewAccountParity.t.sol`    | `R2-TOB-03` |
| `DepositFeeEnvelopeBound.t.sol`       | `R2-TOB-04` |
| `CurveClaimableViewSummation.t.sol`   | `R2-TOB-05` |

### 7.4 Disclaimer

This is an **internal, first-party AI pseudo-audit run before the external audit**. It is **not** a formal audit,
certification, warranty, or guarantee of safety. It is one of seven independent round reports; findings are
de-duplicated by content into the consolidated master report, which is the artifact that drives the go/no-go gate. A
finding that exists only in not-yet-deployed code is not live-exploitable — reconcile against what is actually deployed
on-chain before treating any finding here as blocking.
