## Commands run

- `git rev-parse HEAD` → `b52557bc5d1e87537e621fc13917240d40044c24`
- `forge build`
- `forge test --match-path 'tests/invariant/MultiVaultInvariants.t.sol' -q`
- `forge test --match-path 'tests/unit/MultiVault/Multicall.t.sol' -q`
- `forge test --match-path 'tests/unit/MultiVault/MulticallPayableAdversarial.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/MulticallPayableValue.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/MulticallPayableValueAccounting.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/TransientReentry.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/StorageMirrorIntegrity.t.sol' -q`
- `forge test --match-path 'tests/unit/upgrades/v1.1.0/MultiVaultStorageLayout.t.sol' -q`
- `forge test --match-path 'tests/unit/upgrades/v1.1.0/MultiVaultUpgradeRegression.t.sol' -q`
- `forge test --match-path 'tests/unit/curves/BondingCurveRegistry.t.sol' -q`
- `forge test --match-path 'tests/unit/curves/LinearCurve.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/AtomWardenQuorum.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/AtomWardenQuorumSoundness.t.sol' -q`
- `forge test --match-path 'tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/AtomWalletAuthEdges.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/AtomWalletClaim.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/AtomWalletTakeover.t.sol' -q`
- `forge test --match-path 'tests/unit/TrustBonding/PausableVotingEscrow.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/TrustBondingClaim.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/TrustBondingEpoch.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/EmissionBudgetConservation.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/FeeProxyConservation.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/FeeProxyMultiVault.t.sol' -q`
- `forge test --match-path 'tests/unit/FeeProxy/Refund.t.sol' -q`
- `forge test --match-path 'tests/unit/CoreEmissionsController/Reads.t.sol' -q`
- `forge test --match-path 'tests/unit/SatelliteEmissionsController/AccessControl.t.sol' -q`
- `forge test --match-path 'tests/unit/SatelliteEmissionsController/WithdrawUnclaimedEmissions.t.sol' -q`
- `forge test --match-path 'tests/unit/security/v1.1.0/CrossModelEphemeralCoreEpochLength.t.sol' -q` (temporary local reproduction; removed after the successful run)

## Summary table

| ID | Severity | Status | Cluster | Title |
|---|---|---|---|---|
| CM-01 | Informational | Open | C | Documented dynamic-fee curve and hook surface is absent from the reviewed commit |
| CM-02 | Medium | Open | H | Zero epoch length is accepted and permanently disables epoch math |

## Cluster A — MultiVault accounting and payable multicall

PASS — The payable batch sum is checked against the outer value before dispatch, each subcall receives only its assigned virtual value, and nested batches are rejected (`src/protocol/MultiVault.sol:571-620`). The effective-value accessor is used by all payable entry points (`src/protocol/MultiVault.sol:626-764`). I attempted mismatched sums, repeated-value replay, nested batches, reverting subcalls, and callback re-entry; the focused tests and the conservation invariant passed.

PASS — Deposit/redeem accounting updates the vault ledgers before value leaves the contract and applies fee accounting on the respective paths (`src/libraries/MultiVaultLib.sol:749-864`). The native-balance conservation invariant passed.

VERDICT: PASS

## Cluster B — Storage compatibility

PASS — The explicit `MultiVaultLib.Storage` mirror covers the inherited-core and MultiVault state sequence (`src/libraries/MultiVaultLib.sol:96-146`); the contract’s appended state and reserved gap remain at the documented end of the layout (`src/protocol/MultiVault.sol:75-129`). I attempted mirror/implementation slot divergence and upgrade-layout regressions through the dedicated storage and upgrade tests; all passed.

PASS — The AtomWarden v2 state is initialized through the guarded reinitializer and its upgrade regression test passed (`src/protocol/wallet/AtomWarden.sol:214-250`).

VERDICT: PASS

## Cluster C — Curves and dynamic fee economy

### CM-01 [Informational] — Documented dynamic-fee curve and hook surface is absent from the reviewed commit

- **Status:** Open
- **Invariant:** §5.3 and §5.4 are not evaluable; the documented deposit-fee accounting, reward-debt accounting, and flat-par property have no implementation in this checkout.
- **Affected code:** `src/interfaces/IBaseCurve.sol:34-134`, `src/protocol/curves/BondingCurveRegistry.sol:125-283`, and the expected `src/protocol/curves/DynamicFeeFlatPriceCurve.sol` / `IDynamicFeeFlatPriceCurve.sol` sources, which are absent.
- **Attacker capability:** None required. This is a reviewed-scope and release-artifact mismatch, rather than an independently exploitable on-chain path.
- **Attack / reproduction sequence:**
  1. Inspect the `IBaseCurve` surface: it exposes only the seven baseline pricing methods, with no deposit-fee quote, record, or reward-debt hook (`src/interfaces/IBaseCurve.sol:34-134`).
  2. Inspect registry dispatch: it forwards only those baseline pricing methods (`src/protocol/curves/BondingCurveRegistry.sol:125-283`).
  3. Search the production source tree for `DynamicFeeFlatPriceCurve`, `IDynamicFeeFlatPriceCurve`, `quoteDepositFee`, `recordDeposit`, and `accFeePerShare`; none is present.
  4. Therefore the handoff’s dynamic-fee accounting and hook-dispatch requirements cannot be exercised or certified against commit `b52557bc5d1e87537e621fc13917240d40044c24`.
- **Impact:** The v1.1.0 dynamic-fee feature described by the handoff is not represented in the review target. In particular, this round cannot establish the stated fee-conservation, reward-debt, or flat-par guarantees for that feature.
- **Refutation attempted:** Existing linear-curve and registry behavior was exercised with the focused curve tests; both passed. That only establishes the baseline curve implementation, not the absent dynamic-fee surface.
- **Recommendation:** Reconcile the audited commit with the intended release artifact. Add the dynamic-fee contract, interface, registry forwarding, MultiVault integration, and invariant/fuzz coverage to the review target, then rerun Cluster C before treating its requirements as verified.
- **Regression test:** A compile-time/API presence check for the curve and hook selectors, followed by property tests for all §5.3 and §5.4 requirements.
- **Variant sweep:** Direct curve calls, registry-dispatched calls, MultiVault deposit paths, zero-activity configuration, and upgrade/reinitialization paths are all untestable for this absent feature.

PASS — Baseline curve bounds and registry dispatch passed the focused LinearCurve and BondingCurveRegistry tests. This does not resolve CM-01.

VERDICT: FAIL

## Cluster D — AtomWarden authorizations

PASS — Claim authorization binds claimant, atom, claim type, nonce, and validity window; the nonce is consumed before the external completion call (`src/protocol/wallet/AtomWarden.sol:287-325`). Quorum validation enforces strictly increasing recovered signers and role membership (`src/protocol/wallet/AtomWarden.sol:584-628`), while cap retuning preserves consumed capacity (`src/protocol/wallet/AtomWarden.sol:710-768`). I attempted replay, duplicate signatures, insufficient quorum, malformed segments, expired windows, and cap-retune variants; the focused tests passed.

VERDICT: PASS

## Cluster E — AtomWallet and factory authorization

PASS — Pre-claim ownership resolves to AtomWarden and post-claim ownership resolves to the claimant (`src/protocol/wallet/AtomWallet.sol:288-311`, `src/protocol/wallet/AtomWallet.sol:375-377`). Claim completion is restricted to AtomWarden, and ownership/signer changes preserve the primary signer (`src/protocol/wallet/AtomWallet.sol:252-274`, `src/protocol/wallet/AtomWallet.sol:407-412`). I attempted permissionless deployment/takeover, pre-claim execution, invalid signatures, wrong entry point, and primary-signer removal; the focused tests passed.

VERDICT: PASS

## Cluster F — TrustBonding claims and pauses

PASS — Claims are constrained to the previous epoch, cannot exceed the epoch reward budget, record the claim before transfer, and use non-reentrancy (`src/protocol/emissions/TrustBonding.sol:383-439`). State-mutating voting-escrow extensions are paused where required (`src/protocol/emissions/TrustBonding.sol:448-483`). I attempted duplicate/over-budget claims, epoch-boundary variants, and paused-state mutations; the focused tests passed.

VERDICT: PASS

## Cluster G — FeeProxy routing and refunds

PASS — FeeProxy validates delegated receiver approvals, computes allocations with final-leg dust assignment, and preserves a claimable pending refund before transferring it (`src/protocol/FeeProxy.sol:686-705`, `src/protocol/FeeProxy.sol:789-811`, `src/protocol/FeeProxy.sol:521-545`). I attempted allocation-conservation, MultiVault routing, excess-value, and repeated-refund variants; the focused tests passed.

VERDICT: PASS

## Cluster H — Emissions controllers

### CM-02 [Medium] — Zero epoch length is accepted and permanently disables epoch math

- **Status:** Open
- **Invariant:** Epoch-schedule liveness: a configured controller must be able to calculate current and timestamp epochs. This underpins reward scheduling and the §5.1 emissions path.
- **Affected code:** `src/protocol/emissions/CoreEmissionsController.sol:46-69`, `src/protocol/emissions/CoreEmissionsController.sol:166-172`, `src/protocol/emissions/CoreEmissionsController.sol:192-218`, `src/protocol/emissions/SatelliteEmissionsController.sol:60-97`.
- **Attacker capability:** A deployment or upgrade configuration submitter able to provide the initialization parameters. This is an irreversible operator-configuration footgun, not a permissionless exploit.
- **Attack / reproduction sequence:**
  1. Initialize `CoreEmissionsControllerMock` with a valid start time, a zero `emissionsLength`, nonzero emissions, a nonzero cliff, and valid reduction basis points.
  2. Initialization succeeds because `__CoreEmissionsController_init` validates the other parameters but directly assigns `emissionsLength` without validating it (`src/protocol/emissions/CoreEmissionsController.sol:55-64`).
  3. Call `getEpochAtTimestamp(startTimestamp)`. It reaches `_calculateTotalEpochsToTimestamp` and divides by `_EPOCH_LENGTH` (`src/protocol/emissions/CoreEmissionsController.sol:212-218`), reverting with Solidity panic `0x12`.
  4. The same unvalidated struct field is passed through Satellite initialization (`src/protocol/emissions/SatelliteEmissionsController.sol:77-83`), so a satellite may be initialized into the same unusable state.
- **Impact:** A zero epoch length makes current-epoch, timestamp-epoch, and timestamp-emissions calculations revert once the start time is reached. A satellite configured this way cannot support its intended TrustBonding reward schedule without a corrective upgrade or redeployment. Because the value is only initialized and has no setter, the configuration is not repairable through ordinary administration.
- **Local proof:** The temporary `CrossModelEphemeralCoreEpochLength.t.sol` test initialized the mock with zero length, asserted the stored zero, and proved `getEpochAtTimestamp` reverts with `stdError.divisionError`. The command is recorded above; the test file was removed immediately after the successful local run.
- **Refutation attempted:** Normal nonzero-length epoch reads passed in `tests/unit/CoreEmissionsController/Reads.t.sol`. The zero value is neither rejected by the initializer nor handled by the calculation path, so those normal-path tests do not refute the defect.
- **Recommendation:** Add `CoreEmissionsController_InvalidEpochLength()` and reject `emissionsLength == 0` before assigning `_EPOCH_LENGTH`. Apply the validation in the shared core initializer so satellite initialization inherits it.
- **Regression test:** Initialize the core mock and SatelliteEmissionsController with `emissionsLength == 0`; both must revert with the new explicit error. Retain existing boundary tests for the minimum nonzero length.
- **Variant sweep:** Direct core initialization and Satellite initialization are affected. Pre-start calls return zero before division, but all at/after-start paths (`getCurrentEpoch`, `getEpochAtTimestamp`, and timestamp-emissions computation) are affected. Upgradeability does not supply an ordinary configuration setter.

PASS — With a nonzero epoch length, the focused controller read tests, Satellite role tests, and unclaimed-emissions withdrawal tests passed. This does not resolve CM-02.

VERDICT: FAIL
