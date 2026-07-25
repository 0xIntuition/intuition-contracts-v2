# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 5 of 6 — HumanPages.ai skill (`audit-contract`, multi-agent specialist selection)

> **How this report was produced:** the HumanPages.ai `audit-contract` skill auto-selected specialist reviewers by
> contract feature (from an 11-agent roster), each attacking a distinct angle over the whole in-scope set, followed by a
> false-positive gate, a variant sweep, and a Foundry proof-of-concept for the confirmed finding. Provenance ID prefix:
> `HMN-`. This is one of six independent round reports; the consolidated, de-duplicated view is
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

|                     |                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Artifact**        | Internal AI pseudo-audit — pre-external-audit adversarial review round                                                                                    |
| **Date**            | 2026-07-25                                                                                                                                                |
| **Reviewers**       | Internal AI pseudo-audit — multi-agent specialist-selection round (auto-selected specialist reviewers, one per attack angle, over the whole in-scope set) |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)                                                                            |
| **Repository**      | `intuition-contracts-v2` (public mirror)                                                                                                                  |
| **Toolchain**       | Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun` (EIP-1153), OpenZeppelin `5.4.0`, solady; TransparentUpgradeableProxy throughout                         |
| **Networks**        | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`)                                                                                 |

> **This is not a formal audit, certification, warranty, or guarantee of safety.** It is one independent, adversarial AI
> review round produced internally **before** the external audit, to add breadth and adversarial pressure and to feed a
> single found → fixed log to the external auditors. For contracts managing significant value, commission an independent
> audit from a qualified security firm before relying on this document.

---

## 1. Executive Summary

This round performed a **whole-contract** adversarial review of the v1.1.0 core-upgrade in-scope set — every function of
every in-scope contract, not just the delta — against a fixed set of load-bearing invariants (value conservation,
solvency, flat-price par, storage-layout upgrade safety, and no `msg.value`-replay in the payable multicall). The round
auto-selected specialist reviewers by contract feature (the multi-agent specialist-selection round), each attacking a
distinct angle, then applied a false-positive gate, a variant sweep, and a Foundry proof-of-concept for the one
confirmed finding.

The headline result is **one Medium, three Minor, and eleven Informational** issues, and **no Critical or Major (High)**
issue on the in-scope surface.

| Severity      | Count |
| ------------- | ----- |
| Critical      | 0     |
| Major         | 0     |
| Medium        | 1     |
| Minor         | 3     |
| Informational | 11    |

The single Medium (**HMN-01**) is an asymmetry between how the protocol reads _system_ utilization versus _personal_
utilization when computing emission rewards: the system-side read uses a raw per-epoch storage slot while the
personal-side read uses a self-healing 3-slot lookback. The consequence is that the epoch immediately following a
fully-quiescent epoch scores standing utilization as brand-new activity, inflating that epoch's emission ratio toward
100% and distributing up to the funded per-epoch maximum. The effect is bounded by the funded emission cap (no unbacked
mint, no over-claim, and vault solvency is unaffected), but it is a repeatable emissions-policy/accounting-integrity
defect that contradicts the stated "utilization survives multi-epoch quiescence" design intent. It is reproduced and
mutation-checked by a committed Foundry PoC.

The value-critical machinery introduced in v1.1.0 held up well under adversarial pressure. In particular: the
payable-multicall value accounting conserves native value on every path (the write-path library never reads raw
`msg.value`; per-leg allocations are enforced to sum to `msg.value`; legs are `nonReentrant` and nesting is rejected);
the delegatecall library's storage view is byte-exact with the vault's layout (verified by `forge inspect` slot diff and
11 passing storage-lock tests); the AtomWarden EIP-712 quorum and per-window claim cap resist replay, malleability, and
boundary gaming; and the FeeProxy refund ledger conserves native value (verified by a 10k-run conservation fuzz).

A load-bearing scope note: **Cluster C — the `DynamicFeeFlatPriceCurve` and the standardized curve fee-hook economy — is
not present at this commit** and was therefore not audited (see §2).

---

## 2. Scope

This review focused on the v1.1.0 core-upgrade in-scope set as it exists in the public mirror at revision
`b52557bc5d1e87537e621fc13917240d40044c24`. The following files were in scope (SHA-1 of the reviewed file content):

| File                                                      | SHA-1                                      |
| --------------------------------------------------------- | ------------------------------------------ |
| `src/protocol/MultiVault.sol`                             | `fa047fa88210b9bfb11380265fff16de6d2a3f50` |
| `src/protocol/MultiVaultCore.sol`                         | `10e49f0e0678bd1c82e9c0f00cd1d1f0cbd4ad1d` |
| `src/libraries/MultiVaultLib.sol`                         | `79ec0ef0d91da4b24fc5a572617f34664534b8c6` |
| `src/protocol/curves/BaseCurve.sol`                       | `9cea954df7591d10a9178eb517a32f3dd4093b69` |
| `src/protocol/curves/BondingCurveRegistry.sol`            | `8f939b889665c75911b2d03c21437b852079b9fb` |
| `src/protocol/curves/LinearCurve.sol`                     | `63482405429b0ee3f550de0af4f4c8857d15f55c` |
| `src/protocol/wallet/AtomWallet.sol`                      | `33eee01d67efc13fa8ec86272facd1a9bf5a093c` |
| `src/protocol/wallet/AtomWalletFactory.sol`               | `8f2733e27b7561f0f0cb4e8680ef1c4926de33ba` |
| `src/protocol/wallet/AtomWarden.sol`                      | `8364b3480ced16bef424493b8af8b9793666ce70` |
| `src/protocol/emissions/TrustBonding.sol`                 | `d01ccd6b48356fdf9495cf715ddb7630c9cbea5b` |
| `src/protocol/emissions/CoreEmissionsController.sol`      | `b96858d5dc98c105c50762e57dc526298fe8ede1` |
| `src/protocol/emissions/SatelliteEmissionsController.sol` | `cec17d4e7f95ca1be3ab1215de13414f1130d0f7` |
| `src/periphery/FeeProxy.sol`                              | `47de7f99d8fd8d0c18145efbba15bd435d9055fa` |
| `src/libraries/CoinbaseSmartWalletLib.sol`                | `34380a7fadd6c8b3916932dbdbefc550f68bbc5d` |

The `IMultiVault`, `IBaseCurve`, `IAtomWallet`, `IAtomWarden`, and `IFeeProxy` interfaces were reviewed for context
where reachable.

### Scope reconciliation — Cluster C not present

At this commit, **`DynamicFeeFlatPriceCurve` and the standardized curve fee-hook economy are not merged.** There is no
`src/protocol/curves/DynamicFeeFlatPriceCurve.sol`, and there are no `quoteDepositFee` / `quoteRedeemFee` /
`recordDeposit` / `recordRedeem` hooks or `IBaseCurve` fee getters anywhere under `src/`. Consequently the "curve ledger
mirrors vault shares" invariant and the dynamic-fee curve are **n/a — not present, not audited**. The curves that do
exist (`BaseCurve`, `BondingCurveRegistry`, `LinearCurve`, plus the pre-existing progressive curves) were reviewed for
the invariants that still apply (flat-price par, first-depositor inflation, registry dispatch).

### Out of scope

The following were treated as out of scope; where a boundary was touched it is noted and no finding is filed:

| Out of scope                                                                                        | Reason                                                                                                                                                                                           |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Trust Swap / swap periphery                                                                         | Not in the public core mirror.                                                                                                                                                                   |
| Bridge router / MetaLayer cross-chain transport (`MetaERC20Dispatcher` transport leg, `IMetaLayer`) | Cross-chain transport is a trust boundary; only Intuition-side emissions accounting is in scope.                                                                                                 |
| `BaseEmissionsController` and all Base-chain components                                             | v1.1.0 is Intuition-chain only.                                                                                                                                                                  |
| TVL exit circuit breaker / rate limiter                                                             | Deliberately parked; its absence is a decision, not a gap.                                                                                                                                       |
| Unbounded cross-curve counter-stake checks                                                          | Rejected on principle (unbounded hot-path loop).                                                                                                                                                 |
| `MultiVaultMigrationMode`                                                                           | Migration-only; `MIGRATOR_ROLE` permanently revoked after migration.                                                                                                                             |
| `ProgressiveCurve` / `OffsetProgressiveCurve` / `ProgressiveCurveMathLib`                           | Pre-existing, not the v1.1.0 delta (in scope only for `IBaseCurve` conformance).                                                                                                                 |
| Legacy `Trust` / `TrustToken` / `WrappedTrust` / `VotingEscrow` (`external/`, `legacy/`)            | Vendored/legacy; not the v1.1.0 delta.                                                                                                                                                           |
| Trusted-admin centralization (privileged setters, upgrades)                                         | Gated by a 4-of-8 Safe through two TimelockControllers (parameters 3-day, upgrades 7-day) — an accepted trust assumption. "Trusted admin can do X" is distinguished from "an attacker can do X." |
| `AtomWallet` `executeFromExecutor` delegation framework                                             | Held out of merge.                                                                                                                                                                               |
| Whole-surface `multicallPayable` mixing payable + non-payable legs                                  | Deliberately deferred; the value-bearing-batches-are-create/deposit-only wall is intended (attacking the wall is in scope).                                                                      |

---

## 3. Severity Classification

Severity is assigned as Impact × Likelihood, using the same labels as the project's prior external reports (Critical /
Major / Medium / Minor, plus Informational). The round's working severities map onto these labels as: Critical →
Critical, High → Major, Medium → Medium, Low → Minor, Informational → Informational.

- **Critical** — a permissionless or realistically reachable path to direct theft, permanent loss, insolvency,
  unrestricted mint/withdraw, or capture of upgrade/admin control.
- **Major** — a core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path
  corrupts critical state.
- **Medium** — bounded loss, temporarily stuck funds, realistic griefing/DoS of a funds path, an admin footgun, or a
  spec regression that materially affects users/operators.
- **Minor** — limited impact, weak validation blocked by another guard, or a monitoring/integration weakness.
- **Informational** — documentation, hygiene, NatSpec-vs-behaviour mismatch, or a missing non-critical test.

Permissionless exploitability is separated from trusted-admin misuse throughout; centralization risk is an accepted
trust assumption in this engagement.

---

## 4. System Overview (in-scope surface)

`MultiVault` is the core contract; users deposit native TRUST to create and back atoms and triples, receiving internal
shares priced by a bonding curve resolved from `BondingCurveRegistry`. v1.1.0 adds a payable multicall
(`multicallPayable`) that virtualizes per-sub-call value in transient storage (EIP-1153) behind a selector allowlist,
on-behalf-of creation (`createAtomsFor` / `createTriplesFor`), atom creation attribution, a system-utilization epoch
rollover, `PAUSER_ROLE` and timelock-gated setters, and a `reinitialize(2)` bootstrap. The heavy write-path bodies live
in `MultiVaultLib`, invoked by `delegatecall` under a storage-slot mirror of the vault's layout. `AtomWallet`
(ERC-4337 + P-256/WebAuthn) and its factory and warden govern per-atom smart wallets, with `AtomWarden` adding an
EIP-712 quorum claim path and a governable per-window claim cap. `TrustBonding` bonds TRUST for veTRUST voting power and
distributes epoch emissions weighted by system and personal utilization sourced from `MultiVault`; the
`CoreEmissionsController` / `SatelliteEmissionsController` supply the emission schedule and the Intuition-side TRUST
transfers. `FeeProxy` is a funds-touching periphery that routes create/deposit calls, charges affiliate fees bounded by
caps, and maintains a push+pull refund ledger. The burn/ghost-share sink is `BURN_ADDRESS` =
`0x000000000000000000000000000000000000dEaD`.

---

## 5. Findings

Findings are ordered highest-severity first. Each carries a working id with round provenance (`HMN-*`). All statuses are
**Open** (this is a pre-remediation review round).

---

### 5.1 [Medium] HMN-01 — System-utilization carry-forward asymmetry inflates post-quiescence emissions

**Status:** Open · **Confidence:** High · **Invariant:** §5.1 (conservation of value)

**Description.** `TrustBonding` weights epoch emissions by a _system_ utilization ratio and a _personal_ utilization
ratio, each computed as a delta between two epochs. The two reads are asymmetric:

- The **personal** ratio reads `getUserUtilizationInEpoch` (`src/libraries/MultiVaultLib.sol:520-541`), which walks a
  3-slot `userEpochHistory` lookback and therefore returns the _carried cumulative_ for an epoch that had no activity.
- The **system** ratio reads `getTotalUtilizationForEpoch` (`src/protocol/MultiVault.sol:321-323`), which returns the
  **raw** `totalUtilization[epoch]` slot.

Utilization is maintained as a cumulative running total by `_rollover` (`src/libraries/MultiVaultLib.sol:1125-1153`),
which carries the last-active total forward — but only into an epoch that is _touched_ by activity. A fully-quiescent
epoch is never touched, so its raw slot stays `0`. For the epoch immediately following such a gap, the system "before"
term reads `0` instead of the carried cumulative, so the standing utilization is counted as a fresh positive delta,
driving the system ratio toward 100% and inflating that epoch's emissions toward the funded maximum.

**Code.**

`src/protocol/emissions/TrustBonding.sol:648-685` (system side — raw read):

```solidity
int256 utilizationBefore = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch - 1);
int256 utilizationAfter  = IMultiVault(multiVault).getTotalUtilizationForEpoch(_epoch);
int256 rawUtilizationDelta = utilizationAfter - utilizationBefore;
...
uint256 utilizationTarget = totalClaimedRewardsForEpoch[_epoch - 1];
if (utilizationDelta >= utilizationTarget) { return BASIS_POINTS_DIVISOR; } // 100%
```

`src/protocol/emissions/TrustBonding.sol:610-611` (personal side — 3-slot lookback):

```solidity
int256 userUtilizationBefore = IMultiVault(multiVault).getUserUtilizationInEpoch(_account, _epoch - 1);
int256 userUtilizationAfter  = IMultiVault(multiVault).getUserUtilizationInEpoch(_account, _epoch);
```

`src/protocol/MultiVault.sol:321-323` (raw slot, no lookback):

```solidity
function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256) {
    return totalUtilization[epoch];
}
```

`src/libraries/MultiVaultLib.sol:1136-1142` (carry only on first touch of an epoch):

```solidity
uint256 sourceEpoch = s.lastSystemUtilizationEpoch;
int256 sourceUtilization = s.totalUtilization[sourceEpoch];
if (sourceUtilization != 0 && s.totalUtilization[currentEpochLocal] == 0) {
    s.totalUtilization[currentEpochLocal] = sourceUtilization;
}
s.lastSystemUtilizationEpoch = currentEpochLocal;
```

**Proof of concept.** Reproduced by `tests/unit/security/v1.1.0/MultiAgentRound_SystemUtilizationCarryAsymmetry.t.sol`
(both tests green at this commit):

1. Reach an epoch `E0 >= 2` (epochs 0 and 1 are hardcoded to a 100% ratio). Build system utilization `U > 0` in `E0`.
   State: `totalUtilization[E0] = U`, `lastSystemUtilizationEpoch = E0`.
2. Let epoch `E1 = E0 + 1` pass with **no** `MultiVault` deposit/redeem/create by anyone. `_rollover` is never invoked
   for `E1`; `totalUtilization[E1]` stays `0`.
3. In epoch `E2 = E0 + 2`, a single small action `d` re-touches the system. `_rollover` carries
   `totalUtilization[E2] = U`, then adds `d`, giving `U + d`.
4. `_getSystemUtilizationRatio(E2)` computes
   `delta = getTotalUtilizationForEpoch(E2) − getTotalUtilizationForEpoch(E1) = (U + d) − 0 = U + d`, where the true
   incremental utilization is only `d`. The PoC asserts `getTotalUtilizationForEpoch(E1) == 0` while
   `getUserUtilizationInEpoch(user, E1) == U`, and that `systemDelta − correctDelta == U` — the carried cumulative `U`
   is double-counted as fresh activity. When `totalClaimedRewardsForEpoch[E1] > 0` (the normal case — stakers accrue and
   claim each epoch independent of MultiVault activity), the inflated delta drives the ratio to 100% where the correct
   delta would have produced a value below 100%.

A differential control test (`test_HMN01_control_noAsymmetryWhenGapEpochIsTouched`) shows that when the gap epoch is
_touched_, `systemBefore == personalBefore` and the inflation disappears — confirming the assertions are non-vacuous and
specific to the quiescent gap, and standing in for the source-mutation check (applying the recommended fix flips the
finding test's `assertGt(personalBefore, systemBefore)`).

**Impact.** Repeatable over-emission of inflationary TRUST in every epoch that immediately follows a fully-quiescent
epoch; this dilutes non-stakers and accelerates the emission schedule beyond the utilization model's intent, and is
self-servingly gameable by a dominant staker who alternates active and quiescent epochs. The effect is **bounded** by
the funded `maxEmissions` per epoch (the "excess" is TRUST that would otherwise be reclaimed/bridged as unclaimed), so
there is no unbacked mint, no over-claim or double-claim, and vault solvency (§5.2) is unaffected. It is an
emissions-policy/accounting-integrity defect, directly analogous in class to the prior external audit's
utilization-gaming finding.

**Recommendation.** Make the system read symmetric with the personal read — any of: (i) give
`getTotalUtilizationForEpoch` / `_getSystemUtilizationRatio` a lookback to `lastSystemUtilizationEpoch` so an untouched
epoch returns the last cumulative `<= epoch` instead of a raw `0`; (ii) have `_rollover` backfill skipped intermediate
epochs' baseline; or (iii) compute the system delta against `totalUtilization[lastSystemUtilizationEpoch]` rather than
`totalUtilization[epoch − 1]`.

**Resolution / Status.** Open. Gating regression test: `MultiAgentRound_SystemUtilizationCarryAsymmetry.t.sol` (both
cases). Reviewers should also confirm whether the existing `NoActivityEpochDefense` / `RolloverSystemUtilization`
coverage already exercises the system-read path specifically.

---

### 5.2 [Minor] HMN-02 — `_verifyQuorum` has no `signatureThreshold == 0` floor

**Status:** Open · **Confidence:** High · **Invariant:** n/a (config robustness)

**Description & code.** `AtomWarden._verifyQuorum` (`src/protocol/wallet/AtomWarden.sol:592-596`) accepts
`segments >= threshold`; if `signatureThreshold` were `0`, the check `segments < 0` is always false and quorum degrades
to 1-of-N (line 611 still requires one currently-authorized `SIGNER_ROLE` key). Both initializers (`:172-174`,
`:230-232`) hard-require `_signatureThreshold != 0`, so this is reachable only if the proxy is upgraded to this
implementation **without** running `reinitialize(2)`.

**Proof of concept.** Not permissionless: requires a half-completed upgrade leaving `signatureThreshold == 0`. In that
state a single valid signer signature satisfies quorum. A mismatched EIP-712 domain version from the prior deployment
would additionally fail recovery, further limiting real reachability.

**Recommendation.** Add `if (threshold == 0) revert AtomWarden_InsufficientSigners();` at the top of `_verifyQuorum` so
a misconfigured/half-upgraded proxy fails closed.

**Resolution / Status.** Open.

---

### 5.3 [Minor] HMN-03 — ERC-1271 rejects the legitimate legacy owner during the pre-migration window

**Status:** Open · **Confidence:** High · **Invariant:** n/a (auth-surface consistency)

**Description.** For a pre-v1.1.0 wallet claimed under the old ownership flow and then beacon-upgraded
(`isClaimed == true`, `_claimant == 0`, MultiOwnable registry empty), the ERC-4337 userOp path
(`src/protocol/wallet/AtomWallet.sol:544-562`) accepts the legacy owner's signature, but the ERC-1271 path (`:375-382`)
routes only through the empty registry and returns `0xffffffff`, rejecting even the legitimate legacy owner until the
first authorized action migrates the registry.

**Proof of concept.** The inconsistency is strictly fail-closed — ERC-1271 never over-accepts (verified against the
dangerous direction: post-migration both surfaces use distinct digests, so no cross-surface replay). The window
self-heals on the first `execute`/owner-management call.

**Recommendation.** Document the transition, or have `isValidSignature` fall back to validating against
`_legacyOwnerPendingMigration()` for parity.

**Resolution / Status.** Open.

---

### 5.4 [Minor] HMN-04 — `setMaxFixedFee` has no absolute ceiling

**Status:** Open · **Confidence:** High · **Invariant:** §5.1 (holds)

**Description & code.** `FeeProxy.setMaxFixedFee` (`src/periphery/FeeProxy.sol:451-455`) accepts any `uint256` (contrast
`setMaxBps:443`, bounded by `BPS_DIVISOR`). It is `DEFAULT_ADMIN_ROLE`-gated (governance Safe behind a timelock) — not
permissionless.

**Proof of concept.** A hostile/misconfigured admin could raise `maxFixedFee`, letting affiliates set large fixed fees.
The user side is bounded by three independent guards: the caller-supplied `FeeGuard` re-checked at execution
(`_assertFeeGuard:730-737`); `fee >= grossAssets` reverts (`:291`, `:598`); and the fee is subtracted from the user's
chosen `grossAssets`, so the user's maximum outflow is exactly the amount they chose. No third-party victim can be
charged.

**Recommendation.** Add an absolute ceiling to `setMaxFixedFee` and an integration guideline ("always pass a real
`FeeGuard`, never `type(uint256).max`").

**Resolution / Status.** Open (trusted-admin footgun; centralization is an accepted trust assumption).

---

### 5.5 Informational findings

Each is Open. None is permissionlessly exploitable; several are trusted-admin/config or deploy-hygiene notes.

- **HMN-05 — Create-path min-share backing assumes a flat-price default curve.**
  `src/libraries/MultiVaultLib.sol:1591,1596` charge raw `minShare` while `_updateVaultOnCreation` (`:1174-1187`)
  credits `_minAssetsForCurve(defaultCurveId, minShare)`; these are equal only because the default curve is Linear (1:1,
  `LinearCurve.sol:111`). If governance ever pointed `defaultCurveId` at a non-1:1 curve, create-path conservation would
  skew. _Recommendation:_ add a "default curve MUST be flat-price" guard/assert for upgrade safety.

- **HMN-06 — `sweepAccumulatedProtocolFees` is permissionless (benign).** `src/protocol/MultiVault.sol:857-867` has no
  access modifier, but it zeroes the epoch bucket before `Address.sendValue` (CEI) and can only send to the fixed
  `generalConfig.protocolMultisig`; a second call reads `0`. No value at risk. _Recommendation:_ optionally gate behind
  a keeper role for hygiene.

- **HMN-07 — `reinitialize(2)` correctness is coupled to the never-executed-on-chain assumption.**
  `src/protocol/MultiVault.sol:278-289`; if the live proxy had ever consumed initializer version 2, the upgrade's
  `PAUSER_ROLE` grant and `lastSystemUtilizationEpoch` seed would silently be skipped. The in-repo fork regression
  validates the deployed baseline had not executed reinitializer(2). _Recommendation:_ read the proxy's initializer
  version on-chain (`< 2`) before the production upgrade; consider decoupling the role/seed bootstrap in a future
  version.

- **HMN-08 — Fresh deploy leaves the protocol un-bootstrapped until `reinitialize`.** `initialize()`
  (`src/protocol/MultiVault.sol:254-273`) sets no `timelock` and grants no `PAUSER_ROLE`; both live only in
  `reinitialize`. A deploy that omits `reinitialize()` bricks all `onlyTimelock` setters and leaves no pauser.
  _Recommendation:_ ensure the deploy sequence always runs `reinitialize` atomically.

- **HMN-09 — Fixed-window claim cap permits up to `2 × maxClaimsPerWindow` across a boundary.**
  `src/protocol/wallet/AtomWarden.sol:750-768`; inherent to any fixed-window limiter and explicitly documented at
  `:743-745`. Requires an already-compromised quorum. Accepted by design; a sliding-window accumulator would remove the
  doubling if desired.

- **HMN-10 — EOA-owner ECDSA path is signature-malleable.** `src/libraries/CoinbaseSmartWalletLib.sol:146` (no low-s
  enforcement); non-exploitable because the userOp digest is bound to `userOpHash` and the nonce, so only one signature
  twin can execute. The P-256 path enforces low-s. Matches upstream Coinbase Smart Wallet. _Recommendation:_ note in
  integration docs.

- **HMN-11 — Passkey UserOp validation depends on the RIP-7212 precompile on the Intuition chain.**
  `src/libraries/CoinbaseSmartWalletLib.sol:154-157`; a liveness precondition for passkey UserOps through public
  bundlers (soundness holds regardless of backend). _Recommendation:_ confirm RIP-7212 availability (or a deployed
  verifier) on the target chains.

- **HMN-12 — `emissionsReductionBasisPoints == 0` is accepted → no hard supply cap.**
  `src/protocol/emissions/CoreEmissionsController.sol:149-153` rejects only `> 1000`; with `0`, emissions are constant
  every epoch and there is no cumulative cap. Init-only, admin-set. _Recommendation:_ enforce `> 0` (or an explicit cap)
  if a hard cap/decay is intended; otherwise document the perpetual schedule as intentional.

- **HMN-13 — `bridgeUnclaimedEmissions` lacks `nonReentrant`.**
  `src/protocol/emissions/SatelliteEmissionsController.sol:216-257`; safe today via CEI (`_reclaimedEmissions[epoch]`
  set at `:233` before external calls, once-per-epoch guard at `:228`), unlike the sibling
  `transfer`/`withdrawUnclaimedEmissions`. _Recommendation:_ add `nonReentrant` for parity.

- **HMN-14 — `__CoreEmissionsController_init` lacks `onlyInitializing`.**
  `src/protocol/emissions/CoreEmissionsController.sol:46-70` relies on all callers being `initializer`-guarded.
  _Recommendation:_ add `onlyInitializing`.

- **HMN-15 — FeeProxy locked-under-pay residual + recipient not screened for self.**
  `src/periphery/FeeProxy.sol:550-554` (`receive()`), `:181`/`:250` (recipient setters reject only `address(0)`); native
  value can be _locked_ (over-pay/misconfig direction) but never stolen or over-paid — the only balance-derived payout
  pays the caller's own `pendingRefund`, credited by exactly-retained wei. _Recommendation:_ reject `address(this)` in
  the recipient setters (mirroring `claimRefundTo:434`); optionally add a sweep for locked residuals.

### Boundary observations (recorded, not filed — root cause out of scope)

- `VotingEscrow._supply_at` pre-genesis unsigned-subtraction underflow (`src/external/curve/VotingEscrow.sol:736`) and
  `VotingEscrow.deposit_for` force-lock griefing (`:382-389`) both have their root cause in vendored/legacy
  `VotingEscrow` (out of scope, §2), reachable via in-scope `TrustBonding`. Neither is attacker-exploitable for fund
  loss; suggested to the maintainer for the vendored library.

---

## 6. Properties Checked (what held, and how we tried to break it)

Each cluster below carries the round's verdict; a representative refutation is given per cluster. The full negative list
is in the companion findings log.

- **Payable multicall + value accounting — PASS.** Tried cross-leg `msg.value` replay, mid-leg reentrancy into a
  different leg, transient-state leakage on a bubbled revert, `data`/`values` mismatch, surplus-wei stranding, and
  nested-multicall bypass. Defended by per-leg `_effectiveMsgValue()` with `sum(values) == msg.value`, the write-path
  library never reading raw `msg.value`, shared-`_status` `nonReentrant` legs with no untrusted external call on the
  create/deposit path, EIP-1153 frame-revert rollback, exact `payment == sum(assets)`, and the `_inMulticall` +
  selector-allowlist nesting guard.
- **Storage-mirror + upgrade safety — PASS.** `forge inspect` slot diff shows the `MultiVaultLib` delegatecall mirror is
  byte-exact with the vault layout across all 38 fields; `__gap` reduced `[50] → [47]` for exactly the 3 appended tail
  fields; transient vars isolated in EIP-1153 space; `reinitialize` single-shot + admin-gated + `_disableInitializers()`
  in the constructor; 11/11 storage-lock tests pass.
- **Curves — PASS.** Flat-price par holds (LinearCurve rounds against the user, ratio only moves up, `currentPrice`
  never below par); first-depositor inflation blocked (min-share ghost seed to `BURN_ADDRESS`, internal accounting
  immune to raw donations, 0-share deposit reverts); registry dispatch is `view` → STATICCALL (no curve reentrancy).
  Cluster C absent.
- **AtomWarden — PASS.** Quorum requires distinct, currently-authorized signers (strict-ascending, `ECDSA.tryRecover`
  rejecting `s > n/2` and 0-address); EIP-712 replay protection (live-chainid domain, per-claimant nonce burned before
  the external call); cap retune preserves the in-window count; no div-by-zero.
- **AtomWallet — PASS.** Non-owner cannot `execute` or pass userOp validation; pre-claim wallet inert even to the
  warden; CREATE2 non-hijackable; deploy/claim ordering safe both directions; owner-removal lockout guarded; WebAuthn
  challenge bound to the userOp/1271 digest.
- **TrustBonding — PASS.** Reward budget bounded by the per-epoch clamp; no double-claim; retroactive epoch-end stuffing
  blocked (immutable checkpoints); pause asymmetry safe (`withdraw`/`checkpoint` open, no funds trapped). The
  utilization _read_ asymmetry is HMN-01.
- **FeeProxy — PASS.** Never pays out more native than taken in (balance returns to baseline every tx;
  `Σ pendingRefund ≤ balance`, CEI + `nonReentrant`, `msg.sender`-keyed); approval gating cannot charge a victim; fees
  cap-bounded and cannot underflow. Verified by a 10k-run conservation fuzz.
- **Emissions controllers — PASS.** No per-epoch over-emission (factor ≤ 1 structurally, overflow-safe); closed-interval
  epoch boundaries; adjacent non-overlapping claim/reclaim windows; Intuition-side solvency equals the funding boundary.
- **SWC baseline + access control — PASS.** No funds-touching function is Public-Unrestricted with an exploitable gap;
  every `MultiVault` setter is `onlyTimelock`, `pause`/`unpause` split `PAUSER_ROLE`/`DEFAULT_ADMIN_ROLE`;
  counter-triple cannot be directly initialized; no user-favoring fee/share rounding on a funds path.

---

## 7. Appendix

**Methodology.** The round auto-selected specialist reviewers by contract feature (the multi-agent specialist-selection
round) — value-accounting/reentrancy, storage-mirror/upgrade, curve/Cluster-C reconciliation, EIP-712 quorum/cap,
ERC-4337/P-256 auth, emissions/pause, refund-ledger, emissions-controller, and an SWC/access-control/accounting breadth
sweep — each attacking a distinct angle over the whole in-scope set. Findings passed through a false-positive gate
(reachability, upstream validation, math bounds, state preconditions, economic viability, environmental protections) and
a variant sweep across single / batch / on-behalf-of / preview / router / upgrade paths. The one confirmed finding
(HMN-01) received a Foundry proof-of-concept with a differential control standing in for a source-mutation check; the
finding's severity is consistent with the prior external audit's analogous utilization-gaming class.

**Tooling.** Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun`, OpenZeppelin `5.4.0`, solady. Static analysis (Slither,
Semgrep) was attempted but is unavailable under the round's zero-egress constraint: Slither's `crytic-compile` Foundry
integration forces an online `solc-select` version fetch (HTTP 403 offline) and its `--foundry-ignore-compile` path
lacks the AST; Semgrep's rule configs require registry/metrics network access. This is a graceful skip — the multi-agent
adversarial review plus the existing Foundry suites (re-run per cluster where useful) are the primary method.

**One false positive was raised and dropped:** a claim that TrustBonding has no unit tests, from a reviewer that grepped
`test/` (singular) rather than the repo's `tests/` directory, which contains extensive TrustBonding coverage.

**Round provenance.** Every finding id (`HMN-*`) preserves this round's provenance for the cross-round triage merge.
This is a pre-audit artifact; issues are described by mechanism only.

**Disclaimer.** This document is an internal, pre-external-audit AI pseudo-audit artifact. It is not a formal audit,
certification, or guarantee of safety, and does not prove the absence of vulnerabilities. Coverage is limited to the
in-scope Solidity source at the reviewed commit; dependency/supply-chain analysis, formal verification, and exhaustive
fuzzing are out of scope. Commission an independent audit from a qualified security firm before deploying to mainnet.
