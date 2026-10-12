# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 2

## Report 2 of 7 — Vanilla cross-model reasoner (different model family; whole-contract, hypothesis-driven)

> **How this report was produced:** Vanilla cross-model, first-principles review of C1, C2, the complete 30-file source
> delta, and whole-contract F/G/H; verification included targeted Foundry tests, 10,000-run fuzz cases, invariants,
> guard mutation checks, upgrade/storage regressions, Halmos, and the full Foundry suite. Provenance ID prefix:
> `R2-GPT-`. One of 7 independent round reports; consolidated view:
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

## Report metadata

| Field                 | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| Artifact              | Internal pre-audit review; not a formal audit                                |
| Review date           | 28 July 2026                                                                 |
| Repository            | `intuition-contracts-v2`                                                     |
| Upgrade               | Intuition v1.1.0 core upgrade, PR #153                                       |
| Reviewed commit       | `ac567b2ecd03d12e3e27c0ce570381ef9e383196`                                   |
| Differential baseline | `b52557bc5d1e87537e621fc13917240d40044c24`                                   |
| Toolchain             | Foundry 1.5.1; Solidity 0.8.29                                               |
| Review posture        | Independent vanilla reasoner; whole-contract, adversarial, hypothesis-driven |

The supplied expected commit was `8579c5e02e6fd1b58620565d5a6d06d3b9391548`. The mirror had advanced to the reviewed
commit above. The in-scope Solidity tree at the reviewed commit was byte-identical to the corresponding monorepo source
tree; the observed drift from the expected revision was outside the reviewed Solidity sources.

## Executive summary

No exploitable security finding was confirmed in the assigned scope. The review attacked the new dynamic-fee accounting
and generic hook dispatch first, then every source hunk changed since the round-1 baseline, and finally `TrustBonding`,
`FeeProxy`, and the Intuition-side emissions controllers as whole contracts.

The most funds-sensitive hypotheses—fee accumulator inflation, self-fee capture, quote/record divergence, curve/vault
ledger drift, refund double-spend, emissions budget overrun, and reclaim duplication—were refuted by code-path tracing
and targeted execution. The two landed guards were independently mutation-checked: the cross-wallet ERC-1271 replay test
and both zero-epoch initialization tests passed on the reviewed code and failed after their respective guards were
temporarily removed.

The full Foundry suite passed. Halmos proved all seven repository symbolic properties exercised in this round. Medusa
did not reach property execution: after correcting the local compiler selection and enabling test-contract compilation
in a temporary configuration, Medusa reverted while deploying the existing `DynamicFeeMedusaHandler`. This is reported
as a validation limitation, not as a passing campaign or a contract finding. All temporary edits and generated artifacts
were removed.

**Release gate: PASS.** There is no Critical/Major issue and no unresolved Medium funds-path issue in this report.

## Severity summary

| Severity      | Open | Fixed in this round | Total |
| ------------- | ---: | ------------------: | ----: |
| Critical      |    0 |                   0 |     0 |
| Major         |    0 |                   0 |     0 |
| Medium        |    0 |                   0 |     0 |
| Minor         |    0 |                   0 |     0 |
| Informational |    0 |                   0 |     0 |

No `R2-GPT-*` finding was opened, and no known disposition was overridden.

## Severity classification

Severity is selected from realistic impact and likelihood under the intended deployment and trust model. “Major” is the
report-label mapping for “High” in the working rubric.

| Impact \ Likelihood                                                                       | High     | Medium | Low           |
| ----------------------------------------------------------------------------------------- | -------- | ------ | ------------- |
| Critical impact: direct theft, insolvency, unrestricted mint/withdraw, or control capture | Critical | Major  | Medium        |
| Major impact: severe invariant or authorization break, or critical upgrade corruption     | Major    | Major  | Medium        |
| Medium impact: bounded loss, temporary funds-path lock, or realistic griefing             | Medium   | Medium | Minor         |
| Minor impact: limited integration, monitoring, or defense-in-depth weakness               | Minor    | Minor  | Informational |

## Scope

The primary scope was:

- C1: `DynamicFeeFlatPriceCurve` and `IDynamicFeeFlatPriceCurve`, including accounting, distribution, tiers, retuning,
  custody, and solvency.
- C2: `IBaseCurve` hook standardization and dispatch through `BaseCurve`, `BondingCurveRegistry`, `MultiVaultLib`,
  `MultiVault`, `LinearCurve`, and the hookless curves.
- Δ: every source hunk in the 30 changed files between `b52557b…` and the reviewed commit.
- F: `TrustBonding` emissions, snapshots, epoch interleavings, claims, and pause asymmetry.
- G: `FeeProxy` refunds, callbacks, approval gates, batch routing, pauses, caps, and dynamic-curve composition.
- H: `CoreEmissionsController` schedule math and `SatelliteEmissionsController` Intuition-side transfer/reclaim
  accounting.
- Landed-fix verification: ERC-1271 replay-safe binding and zero emissions-epoch rejection.

### Complete 30-file delta ledger

| Changed source                                            | Review treatment                                                                                | Result          |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | --------------- |
| `src/external/curve/VotingEscrow.sol`                     | Diff reviewed; legacy mechanics excluded, override compatibility checked through `TrustBonding` | Boundary held   |
| `src/interfaces/IBaseCurve.sol`                           | Full hook ABI and default-contract consistency                                                  | PASS            |
| `src/interfaces/IBondingCurveRegistry.sol`                | Registry ABI/removal consistency                                                                | PASS            |
| `src/interfaces/ICoreEmissionsController.sol`             | Error and controller ABI consistency                                                            | PASS            |
| `src/interfaces/IDynamicFeeFlatPriceCurve.sol`            | Full new interface and storage/getter surface                                                   | PASS            |
| `src/interfaces/IFeeProxy.sol`                            | Full routing/refund/admin ABI consistency                                                       | PASS            |
| `src/interfaces/IMetaLayer.sol`                           | Diff reviewed; transport semantics excluded                                                     | Boundary held   |
| `src/interfaces/IMultiVault.sol`                          | Hook, preview, payable-multicall, approval, and create/deposit ABI consistency                  | PASS            |
| `src/interfaces/IMultiVaultCore.sol`                      | Core ABI consistency                                                                            | PASS            |
| `src/interfaces/ITrustBonding.sol`                        | Rewards, pause, and getter ABI consistency                                                      | PASS            |
| `src/interfaces/ITrustUnlock.sol`                         | Removal reviewed; no live in-scope reference remained                                           | PASS            |
| `src/interfaces/ITrustUnlockFactory.sol`                  | Removal reviewed; no live in-scope reference remained                                           | PASS            |
| `src/libraries/MultiVaultLib.sol`                         | Whole write-path, storage mirror, hook dispatch, fee/value accounting                           | PASS            |
| `src/periphery/FeeProxy.sol`                              | Whole-contract F/G review                                                                       | PASS            |
| `src/protocol/MultiVault.sol`                             | Delta, storage, reinitializer, approvals, and value virtualization                              | PASS            |
| `src/protocol/MultiVaultCore.sol`                         | Delta and storage/config compatibility                                                          | PASS            |
| `src/protocol/MultiVaultMigrationMode.sol`                | Diff reviewed; migration-only behavior excluded                                                 | Boundary held   |
| `src/protocol/curves/BaseCurve.sol`                       | Full standardized hook defaults                                                                 | PASS            |
| `src/protocol/curves/BondingCurveRegistry.sol`            | Full append-only registration and resolution                                                    | PASS            |
| `src/protocol/curves/DynamicFeeFlatPriceCurve.sol`        | Whole-contract primary review                                                                   | PASS            |
| `src/protocol/curves/LinearCurve.sol`                     | Hookless conformance and inherited 1:1 pricing                                                  | PASS            |
| `src/protocol/curves/OffsetProgressiveCurve.sol`          | Hookless conformance only; legacy pricing excluded                                              | PASS            |
| `src/protocol/curves/ProgressiveCurve.sol`                | Hookless conformance only; legacy pricing excluded                                              | PASS            |
| `src/protocol/emissions/BaseEmissionsController.sol`      | Shared initializer path only; Base-chain behavior excluded                                      | PASS / boundary |
| `src/protocol/emissions/CoreEmissionsController.sol`      | Whole schedule and shared initialization                                                        | PASS            |
| `src/protocol/emissions/MetaERC20Dispatcher.sol`          | Diff reviewed; MetaLayer transport excluded                                                     | Boundary held   |
| `src/protocol/emissions/SatelliteEmissionsController.sol` | Intuition-side roles, transfers, reclaim-once, and solvency                                     | PASS            |
| `src/protocol/emissions/TrustBonding.sol`                 | Whole-contract F review                                                                         | PASS            |
| `src/protocol/wallet/AtomWallet.sol`                      | Delta plus ERC-1271/ERC-4337 binding verification                                               | PASS            |
| `src/protocol/wallet/AtomWarden.sol`                      | Changed claim-cap/validity surface reviewed; no new override found                              | PASS            |

### Explicit boundaries

The review did not assess MetaLayer or bridge transport, Base-chain mint/bridge behavior beyond the shared initializer,
migration-only steady-state assumptions, legacy `VotingEscrow` mechanics, progressive-curve pricing math, cross-curve
counter-stake aggregation, the parked rate limiter, the held-out wallet delegation framework, or trusted-admin
centralization. Mixed payable/non-payable batching was treated as an intentional boundary; attacks against the
selector/value wall remained in scope.

## Findings

No findings were opened.

## Properties checked

Every PASS below records the attempted refutation and the code mechanism that defeated it.

### C1 — Dynamic-fee curve

- **PASS — accumulator conservation and debt rebasing.** Repeated deposit, redeem, settle, multi-term claim, and
  claim-reentry sequences were used to seek duplicated or dropped entitlement. `_settle` banks only positive accumulator
  delta and resets debt, while `claim` zeroes global earned before transfer
  (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:459-475`, `530-538`). The accumulator conservation and reentrancy
  tests passed.
- **PASS — no own-fee capture.** Existing depositor stake was settled before deposit distribution, removed from every
  eligible denominator, and rebased after distribution; an exiter was settled and its withdrawing stake removed before
  its fee was credited (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:339-390`, `401-449`). Attacks covered sole
  holder, partial exit, same-tier cohort, and “only prior tier is self” cases.
- **PASS — kernel gives every fee one home.** Empty tiers, a tight kernel whose weights all round to zero, gaps,
  first-tier deposits, and whale exits above/below occupied tiers were exercised. The degenerate branch selects one
  nearest occupied tier or `protocolAccrued`, and normalized split remainder also goes only to `protocolAccrued`
  (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:599-631`, `693-717`). No fee was credited to two accumulators.
- **PASS — tier edges and fee-band traversal.** Zero assets, exact edges, non-exact geometric ratios, zero growth, the
  top tier, and maximum configured geometry were tested. Width is derived from adjacent cumulative edges, tier bands are
  half-open, and configuration probes the top edge (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:736-763`,
  `875-906`).
- **PASS — vault ledger mirror and live retune.** Deposit/redeem/retune interleavings were used to seek disagreement
  among `userStake`, `tierStake`, `vaultAssets`, and vault shares. The record paths move the full net stake through all
  three ledgers and rebase debt (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:376-390`, `414-450`); tier count
  cannot shrink (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:881-884`). Foundry ledger invariants held.
- **PASS — overrides, custody, sweep, and reentrancy.** Overrides at zero and at the configured cap, cap changes,
  reverting recipients, protocol sweep, and callback reentry were attacked. Overrides cannot exceed the active schedule
  caps (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:265-272`); only `protocolAccrued` is swept and it is zeroed
  before transfer (`src/protocol/curves/DynamicFeeFlatPriceCurve.sol:285-291`); claim and sweep are non-reentrant. A
  BPS-level aggregate trusted-admin fee configuration remains a governance-operational constraint matching known
  accepted dispositions, not a permissionless exploit.

### C2 — Curve hook dispatch

- **PASS — quote equals forward on both deposit paths and redeem.** A mutable/state-dependent mock quote was used to try
  to move the fee between calculation and record. Atom deposit, triple deposit, and redeem resolve one `CurveHook` and
  carry it through state writes; the exact cached fee is forwarded without re-query
  (`src/libraries/MultiVaultLib.sol:934-965`, `990-1027`, `1047-1069`, `851-864`). All 14 hook-detection/parity tests
  passed, including 10,000-run fuzz cases.
- **PASS — lying, reverting, and state-dependent hooks fail atomically.** A curve that advertises a hook but inherits a
  reverting record body, or whose getter/quote reverts, causes the entire vault transaction to revert. A state-dependent
  hook cannot flip the already-cached curve/fee decision (`src/libraries/MultiVaultLib.sol:162-172`, `827-864`). State
  writes preceding record are rolled back with the call.
- **PASS — hookless parity and registry immutability.** Hookless curves return false and their quote/record defaults
  revert if called directly; the vault gates them out before any quote, record call, or value movement
  (`src/protocol/curves/BaseCurve.sol:147-179`). Registry entries are appended under owner control with address/name
  uniqueness and have no replacement path (`src/protocol/curves/BondingCurveRegistry.sol:84-118`).
- **PASS — record-hook reentry and payable-multicall isolation.** Record hooks were used as external callback points
  while per-leg virtual value was live. The routed deposit/redeem entry points are non-reentrant, nested multicalls are
  rejected, selectors are pre-validated, allocations must sum exactly to `msg.value`, and transient value is cleared on
  success or transaction rollback (`src/protocol/MultiVault.sol:511-535`, `587-640`). The seven payable-value tests and
  five transient-reentry tests passed.

### Δ — Upgrade and changed-file surface

- **PASS — storage and linked-library layout.** Slot mismatch, tail-field overlap, gap drift, and upgrade round-trip
  hypotheses were exercised. `MultiVaultLib.Storage` explicitly mirrors slots 0–37 and anchors at slot zero
  (`src/libraries/MultiVaultLib.sol:93-159`); `MultiVault` appends the matching fields before its reduced gap
  (`src/protocol/MultiVault.sol:126-148`). Storage-mirror, storage-layout, and all 25 v1.1.0 upgrade tests passed.
- **PASS — ERC-1271 wallet/chain/domain binding.** The same ECDSA signature was replayed across wallets and chain/domain
  variants; WebAuthn/P-256 was checked through the same digest dispatch. `AtomWallet.isValidSignature` first wraps the
  supplied digest (`src/protocol/wallet/AtomWallet.sol:324-341`), and the domain includes name, version, chain id, and
  `address(this)` (`src/libraries/CoinbaseSmartWalletLib.sol:296-320`). Both address and P-256 owner paths validate that
  wrapped digest (`src/libraries/CoinbaseSmartWalletLib.sol:131-160`). ERC-4337 remains a distinct `userOpHash` path,
  signed with `personal_sign` and dispatched through the same owner registry
  (`src/protocol/wallet/AtomWallet.sol:472-494`); EntryPoint hashing supplies sender/chain/EntryPoint context.
  Pre-upgrade raw ERC-1271 signatures intentionally fail under the hardened scheme.
- **PASS — ERC-1271 mutation gate.** `test_isValidSignature_rejectsCrossWalletReplay` passed on the reviewed source,
  failed when `replaySafeHash` was temporarily bypassed, and passed after exact restoration.
- **PASS — zero emissions epoch rejected on every initializer path.** Zero, one, adjacent timestamp boundaries, zero
  emissions, zero cliff, and cap-edge reduction inputs were attacked. The shared initializer rejects zero length before
  storing it (`src/protocol/emissions/CoreEmissionsController.sol:46-63`, `129-157`), and both controller initializers
  route through it (`src/protocol/emissions/BaseEmissionsController.sol:63-84`,
  `src/protocol/emissions/SatelliteEmissionsController.sol:60-80`).
- **PASS — zero-epoch mutation gate.** The Core and Satellite `test_initialize_revertsWhenEmissionsLengthIsZero` tests
  passed on the reviewed source, both failed when the shared length validation call was temporarily removed, and passed
  after exact restoration.

### F — TrustBonding

- **PASS — epoch budget conservation and no double claim.** Many-user claims, reward rounding, claim callback reentry,
  and repeated claims were used to exceed one epoch’s emissions. The already-claimed check precedes the per-epoch
  remaining-budget clamp, state is recorded before the controller transfer, and the entry point is non-reentrant
  (`src/protocol/emissions/TrustBonding.sol:379-435`). The dedicated budget-conservation and claim suites passed.
- **PASS — quiet epochs, snapshots, and boundary interleavings.** Lock/deposit-for/withdraw/claim sequences were moved
  across epoch start/end and no-activity gaps to seek stale or inflated snapshots. Eligibility reads bonded balances at
  epoch end and divides against the epoch’s total bonded balance (`src/protocol/emissions/TrustBonding.sol:573-585`);
  epoch emissions remain bounded by controller emissions and the system-utilization ratio
  (`src/protocol/emissions/TrustBonding.sol:552-566`). Quiet-epoch carry-forward matched the known, bounded design
  disposition.
- **PASS — pause asymmetry does not trap funds.** Every lock-taking override and `claimRewards` was attacked while
  paused and reverted, while expired-lock withdrawal and checkpoint remained usable. The gates cover `claimRewards` and
  all six lock-taking overrides (`src/protocol/emissions/TrustBonding.sol:379-380`, `445-479`); the explicit
  escape/accounting boundary is documented and tested at `src/protocol/emissions/TrustBonding.sol:486-492`.

### G — FeeProxy

- **PASS — refund conservation and attribution.** Push success, reverting recipient, pull claim, claim-to, callback
  reentry, double claim, and cross-user attribution were attacked. Failed pushes credit only `pendingRefund[user]`
  (`src/periphery/FeeProxy.sol:711-720`); claims zero the caller’s slot before transfer under `nonReentrant`
  (`src/periphery/FeeProxy.sol:391-402`, `565-572`).
- **PASS — approvals, callbacks, pauses, caps, and batch rollback.** A malicious fee recipient attempted callback
  routing and deposits into an unapproving victim. Routing functions are non-reentrant; receiver and creator approval
  checks are explicit (`src/periphery/FeeProxy.sol:260-345`, `636-656`). Active-affiliate, protocol-cap, and caller
  guard checks occur before routing (`src/periphery/FeeProxy.sol:529-558`, `628-688`). Tiny allocated legs and
  downstream min-share failures reverted the full batch atomically.
- **PASS — composition with dynamic-fee vaults.** The affiliate fee was taken first, then exactly the post-affiliate
  amount was forwarded to `MultiVault`, where the curve fee was separately quoted, withheld, and forwarded. Single and
  batch routes conserved gross = affiliate fee + forwarded, and the downstream hook conserved forwarded =
  minted/preserved accounting + vault fees + curve fee (`src/periphery/FeeProxy.sol:278-289`, `309-320`;
  `src/libraries/MultiVaultLib.sol:947-965`).

### H — Intuition-side emissions

- **PASS — epoch zero, boundaries, cliffs, and arithmetic.** Timestamps before start, exact epoch boundaries, first/next
  cliff, full retention, maximum allowed reduction, and long schedules were attacked. Epochs are non-overlapping closed
  intervals and timestamp-to-epoch uses the same length (`src/protocol/emissions/CoreEmissionsController.sol:171-222`);
  cliff reduction is logarithmic exponentiation over a bounded basis-point retention factor
  (`src/protocol/emissions/CoreEmissionsController.sol:232-246`).
- **PASS — roles, transfer solvency, and reclaim once.** Unauthorized transfer/reclaim calls, zero recipient/amount,
  insufficient balance, repeated withdraw, and withdraw-then-bridge/bridge-then-withdraw were attacked. Controller
  transfers require role, nonzero values, and sufficient balance
  (`src/protocol/emissions/SatelliteEmissionsController.sol:130-138`). Reclaim state is set before payout and shared by
  withdraw/bridge (`src/protocol/emissions/SatelliteEmissionsController.sol:176-206`, `210-228`). MetaLayer transport
  and Base-chain behavior were excluded.

## Validation evidence

| Layer                                    | Result                                                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Dynamic-fee unit suite                   | 88/88 passed; five numeric fuzz properties ran with 10,000 cases each                                 |
| MultiVault dynamic-fee suites            | 28/28 passed                                                                                          |
| Hook detection and quote/record parity   | 14/14 passed; parity fuzz ran with 10,000 cases                                                       |
| FeeProxy whole unit suite                | 137/137 passed                                                                                        |
| FeeProxy adversarial security suites     | 10/10 passed                                                                                          |
| TrustBonding adversarial security suites | 8/8 passed; whole unit and reads suites also passed                                                   |
| Emissions budget security suite          | 6/6 passed                                                                                            |
| Payable multicall and transient reentry  | 7/7 and 5/5 passed                                                                                    |
| Storage mirror and v1.1.0 upgrade suites | 4/4 and 25/25 passed                                                                                  |
| Foundry invariants                       | Dynamic fee 3/3; MultiVault 4/4 passed                                                                |
| Halmos                                   | Dynamic fee 4/4; counter-ID 3/3 passed                                                                |
| Full Foundry suite                       | Exit 0; 1,984 test functions across 114 suites                                                        |
| Medusa                                   | Attempted; no property verdict because existing handler deployment reverted during Medusa chain setup |

The first full-suite invocation encountered a Foundry/macOS system-proxy initialization panic before tests ran. A direct
`forge test -q` invocation avoided that tool path and completed successfully.

## Methodology

The review pinned the actual mirror HEAD, confirmed the corresponding monorepo Solidity sources were identical,
symbol-searched every assigned surface, and read the 30-file differential before tracing whole-contract flows. Each
invariant was framed as an attacker sequence and checked against the exact state transition. Existing tests were treated
as harnesses, not as proof; the review cross-checked code paths first and then ran focused tests, fuzzing, invariants,
symbolic checks, storage/upgrade regressions, and the full suite.

Temporary source mutations removed the ERC-1271 replay-safe wrapping and the zero-epoch initializer call independently.
The relevant tests went red in each mutant. Source hashes were restored exactly afterward. A temporary Medusa
configuration change and handler experiment were likewise restored exactly; no public test or source change was
retained.

## Disclaimer

This document is an internal pre-audit artifact produced for defensive review before an external audit. It is not a
formal audit, certification, warranty, or guarantee of safety. A clean result means only that the stated hypotheses were
not broken under the reviewed code, assumptions, and validation described above. Future code, configuration, deployment,
governance actions, or integrations can change the risk.

**Headline severity count: Critical 0 | Major 0 | Medium 0 | Minor 0 | Informational 0**

**GATE: PASS**

VERDICT: PASS
