# Intuition v1.1.0 Core Upgrade — Internal AI Pseudo-Audit — Round 1

## Report 2 of 6 — Vanilla Cross-Model Reasoner (GPT-5.6), no audit skill

> **How this report was produced:** a second frontier reasoner from a **different model family** (vanilla — no external
> audit skill or checklist), run over the same in-scope set and the same §5 invariants as Report 1, to catch what the
> first family's blind spots miss. Findings were confirmed with local Foundry runs (commands below). Provenance ID
> prefix: `GPT-`. This is one of six independent round reports; the consolidated, de-duplicated view is
> [`MASTER-consolidated-report.md`](MASTER-consolidated-report.md).

|                     |                                                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Artifact type**   | Internal AI pseudo-audit — pre-external-audit. **Not** a formal audit, certification, warranty, or guarantee of safety. |
| **Project**         | `intuition-contracts-v2` public mirror — v1.1.0 core upgrade (PR #153)                                                  |
| **Reviewed commit** | `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)                                          |
| **Toolchain**       | Solidity `0.8.29`, Foundry `1.5.1`, EVM `cancun` (EIP-1153); TransparentUpgradeableProxy throughout                     |
| **Target networks** | Intuition Mainnet (chain id `1155`), Intuition Testnet (chain id `13579`) — Intuition-chain only                        |
| **Date**            | 2026-07-24                                                                                                              |
| **Method**          | Vanilla cross-model reasoner over clusters A–H, scoring against §5 invariants with local Foundry reproduction           |

---

## 1. Executive summary

A vanilla second-family reasoner reviewed the whole v1.1.0 in-scope set (clusters A–H) against the six load-bearing
invariants, corroborating the payable-multicall value accounting, the `MultiVaultLib` storage mirror, the AtomWarden
quorum/claim-cap, the AtomWallet auth surface, TrustBonding claims/pauses, the FeeProxy refund ledger, and the
Intuition-side emissions controllers, each with a local Foundry run.

**Headline result: no Critical or Major issue.** One **Medium** and one **Informational** were recorded. The Medium
(`GPT-02`) is an operator-configuration footgun in the emissions controller: a zero `emissionsLength` passes
initialization and then permanently reverts all epoch math, with no setter to repair it. The Informational (`GPT-01`) is
the release-scope observation — shared by every round — that the documented dynamic-fee curve surface (Cluster C) does
not exist at the reviewed commit and therefore could not be evaluated.

### Findings by severity

| Severity      | Count | IDs    |
| ------------- | ----- | ------ |
| Critical      | 0     | —      |
| Major         | 0     | —      |
| Medium        | 1     | GPT-02 |
| Minor         | 0     | —      |
| Informational | 1     | GPT-01 |

---

## 2. Scope

Whole-contract review of the v1.1.0 in-scope set at commit `b52557b` (clusters A, B, C, D, E, F, G, H per the pre-audit
handoff §6). Out of scope per handoff §3: the cross-chain bridge / MetaLayer transport leg, all Base-chain components,
migration mode, legacy `Trust` / `VotingEscrow` / vendored code, the progressive-curve family, the deliberately-omitted
TVL exit rate-limiter, and cross-curve counter-stake aggregation. **Cluster C caveat:** the dynamic-fee curve surface is
absent at this commit (see `GPT-01`).

---

## 3. Severity classification

Impact × Likelihood, using the Diligence house labels (Critical / Major / Medium / Minor / Informational). The §4
handoff severities map Critical→Critical, High→Major, Medium→Medium, Low→Minor, Informational→Informational.

---

## 4. Findings

### GPT-02 — Zero epoch length is accepted and permanently disables epoch math — Medium

- **Status:** Open (remediation in progress on-branch; see master report — not verified in this round)
- **Invariant:** Epoch-schedule liveness underpinning the §5.1 emissions path — a configured controller must be able to
  compute current and timestamp epochs.
- **Affected code:** `src/protocol/emissions/CoreEmissionsController.sol:46-69`, `:166-172`, `:192-218`;
  `src/protocol/emissions/SatelliteEmissionsController.sol:60-97`.
- **Description / mechanism:** `__CoreEmissionsController_init` validates the other schedule parameters but assigns
  `emissionsLength` directly, with no non-zero check (`CoreEmissionsController.sol:55-64`). A zero value is stored as
  `_EPOCH_LENGTH`. Once the start time is reached, `_calculateTotalEpochsToTimestamp` divides by `_EPOCH_LENGTH`
  (`:212-218`) and reverts with Solidity panic `0x12` (division by zero). The same unvalidated field flows through
  Satellite initialization (`SatelliteEmissionsController.sol:77-83`), so a satellite inherits the unusable state.
- **Proof of concept (local):** initialize `CoreEmissionsControllerMock` with a valid start time,
  `emissionsLength == 0`, non-zero emissions, a non-zero cliff, and valid reduction bps → initialization succeeds and
  stores zero. Call `getEpochAtTimestamp(startTimestamp)` → reverts `stdError.divisionError`. Reproduced by a temporary
  `CrossModelEphemeralCoreEpochLength.t.sol` (removed after the run; command recorded in §5).
- **Impact:** `getCurrentEpoch`, `getEpochAtTimestamp`, and timestamp-emissions computation all revert at/after the
  start time. Because the value has no setter, the misconfiguration is unrepairable through ordinary administration — it
  needs a corrective upgrade or redeployment. Operator-configuration footgun, not a permissionless exploit.
- **Recommendation:** add `CoreEmissionsController_InvalidEpochLength()` and reject `emissionsLength == 0` before
  assigning `_EPOCH_LENGTH`, in the shared core initializer so satellite init inherits it.
- **Regression test:** initialize the core mock and `SatelliteEmissionsController` with `emissionsLength == 0`; both
  must revert with the new explicit error. Keep the existing minimum-non-zero-length boundary tests.
- **Variant sweep:** direct core init and Satellite init affected; pre-start calls return zero before the division; all
  at/after-start read paths affected; no ordinary configuration setter exists.

### GPT-01 — Documented dynamic-fee curve and hook surface is absent from the reviewed commit — Informational

- **Status:** Open (release-scope reconciliation)
- **Invariant:** §5.3 and §5.4 are not evaluable — the documented deposit-fee, reward-debt, and flat-par accounting have
  no implementation in this checkout.
- **Affected code:** `src/interfaces/IBaseCurve.sol:34-134`, `src/protocol/curves/BondingCurveRegistry.sol:125-283`; the
  expected `DynamicFeeFlatPriceCurve.sol` / `IDynamicFeeFlatPriceCurve.sol` are absent.
- **Description / mechanism:** `IBaseCurve` exposes only the seven baseline pricing methods — no deposit-fee quote,
  record, or reward-debt hook — and the registry forwards only those. A source search for `DynamicFeeFlatPriceCurve`,
  `quoteDepositFee`, `recordDeposit`, and `accFeePerShare` returns nothing. The handoff's dynamic-fee requirements
  therefore cannot be exercised against commit `b52557b`.
- **Impact:** the v1.1.0 dynamic-fee feature described by the handoff is not represented in the review target; this
  round cannot establish its fee-conservation, reward-debt, or flat-par guarantees.
- **Recommendation:** reconcile the audited commit with the intended release artifact; add the curve, interface,
  registry forwarding, MultiVault integration, and invariant/fuzz coverage, then re-run Cluster C before treating it as
  verified.

---

## 5. Properties checked (negatives) and commands run

Clusters with a recorded `PASS` after an attempted refutation (negatives evidence coverage):

- **A — MultiVault payable multicall / accounting** — PASS. Mismatched value sums, repeated-value replay, nested
  batches, reverting subcalls, and callback re-entry all attempted; the batch sum is checked before dispatch, each
  subcall gets only its virtual value, nested batches are rejected (`MultiVault.sol:571-620`), and the effective-value
  accessor is used by all payable entry points (`:626-764`). Conservation invariant passed.
- **B — Storage compatibility** — PASS. `MultiVaultLib.Storage` mirror covers the inherited-core + MultiVault sequence
  (`MultiVaultLib.sol:96-146`); appended state + gap at the documented layout end; upgrade-layout regression passed.
- **C — Curves** — FAIL (only because the dynamic-fee surface is absent, `GPT-01`); baseline LinearCurve / registry
  dispatch passed.
- **D — AtomWarden** — PASS. Replay, duplicate signatures, insufficient quorum, malformed segments, expired windows, and
  cap-retune variants attempted; nonce consumed before the external completion call; cap retune preserves consumed
  capacity.
- **E — AtomWallet / factory** — PASS (this round). Permissionless deploy/takeover, pre-claim execution, invalid
  signatures, wrong entry point, and primary-signer removal attempted; all focused tests passed. _(Note: the Cyfrin
  10-agent round independently surfaced the `CYF-E-01` legacy-wallet beacon-brick Major that this vanilla round did not
  reach — see the master report.)_
- **F — TrustBonding** — PASS. Duplicate/over-budget claims, epoch-boundary variants, and paused-state mutations
  attempted; claims constrained to the previous epoch, recorded before transfer, non-reentrant.
- **G — FeeProxy** — PASS. Allocation-conservation, MultiVault routing, excess-value, and repeated-refund variants
  attempted; pending refund preserved before transfer.
- **H — Emissions controllers** — FAIL on `GPT-02`; non-zero-length reads otherwise pass.

**Commands run (local, this round):** `git rev-parse HEAD`; `forge build`; then focused `forge test --match-path` runs
over `tests/invariant/MultiVaultInvariants.t.sol`, `tests/unit/MultiVault/Multicall.t.sol` and
`MulticallPayableAdversarial.t.sol`,
`tests/unit/security/v1.1.0/{MulticallPayableValue,MulticallPayableValueAccounting,TransientReentry,StorageMirrorIntegrity,AtomWardenQuorum,AtomWardenQuorumSoundness,AtomWalletAuthEdges,AtomWalletClaim,AtomWalletTakeover,TrustBondingClaim,TrustBondingEpoch,EmissionBudgetConservation,FeeProxyConservation,FeeProxyMultiVault}.t.sol`,
`tests/unit/upgrades/v1.1.0/{MultiVaultStorageLayout,MultiVaultUpgradeRegression,AtomWardenUpgradeRegression}.t.sol`,
`tests/unit/curves/{BondingCurveRegistry,LinearCurve}.t.sol`, `tests/unit/TrustBonding/PausableVotingEscrow.t.sol`,
`tests/unit/FeeProxy/Refund.t.sol`, `tests/unit/CoreEmissionsController/Reads.t.sol`,
`tests/unit/SatelliteEmissionsController/{AccessControl,WithdrawUnclaimedEmissions}.t.sol`, and the temporary
`CrossModelEphemeralCoreEpochLength.t.sol` (removed after the successful run).

---

## 6. Appendix — method, constraints, disclaimer

- **Method:** vanilla cross-model reasoner (different model family from Report 1), whole-contract over clusters A–H,
  hypothesis-driven against the §5 invariants, each concern taken to a concrete exploit path or an evidenced refutation,
  confirmed with local Foundry runs.
- **Constraints honored:** local only; `src/` not modified; CI / `.github` untouched; reviewed commit `b52557b`;
  mechanism-only descriptions; full-length addresses; **pre-audit artifact — not a formal audit.**
- **Provenance:** ID prefix `GPT-`. Companion working record: `working-logs/vanilla-gpt-5.6.findings.md`.
- **Verdict:** cluster-level — A, B, D, E, F, G PASS; C FAIL (`GPT-01`, absent surface); H FAIL (`GPT-02`). No
  permissionless Critical/Major path reached this round.
