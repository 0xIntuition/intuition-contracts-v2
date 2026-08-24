# Verification record

## Review basis

Reviewed commit:

```text
330980a6e2cad0aa602b5d11c961b75f2236a690
```

Primary files read:

- `src/protocol/curves/DynamicFeeFlatPriceCurve.sol`
- `src/interfaces/IDynamicFeeFlatPriceCurve.sol`
- `src/interfaces/IBaseCurve.sol`
- `src/libraries/MultiVaultLib.sol`
- `src/protocol/MultiVault.sol`
- `src/protocol/MultiVaultCore.sol`
- `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol`
- dynamic-curve unit, integration, security, symbolic, invariant, Medusa, and gas fixtures
- the prior v1.1.0 internal-audit master report and dispositions
- `docs/call-flows/dynamic-fee-curve.md` and generated hook flows

No on-chain transaction or external deployment was performed.

## First-principles invariants checked

| Invariant                                                        | Result               | Basis                                                           |
| ---------------------------------------------------------------- | -------------------- | --------------------------------------------------------------- |
| withheld curve fee equals forwarded hook value                   | Pass                 | one `CurveHook.fee` value is carried from calculation to record |
| principal stays outside fee contract                             | Pass                 | only hook fee is sent to the curve; vault retains net principal |
| flat dynamic vault remains 1:1                                   | Pass                 | inherited linear pricing plus integration/fuzz tests            |
| curve ledger mirrors user shares                                 | Pass                 | hooks run on every dynamic deposit/redeem, including zero fee   |
| `vaultStake = Σ userStake = Σ tierStake`                         | Pass                 | transition proof plus fuzz assertions                           |
| depositor cannot earn from a band before that band's stake lands | Pass                 | distribute → settle → land order                                |
| exiter account cannot earn its own withdrawal fee                | Pass                 | settle/remove/exclude/rebase order                              |
| every whole fee slice has one destination                        | Pass                 | recipient accumulator or `protocolAccrued`; fee total conserved |
| accumulated obligations do not exceed curve custody              | Pass                 | unit, adversarial, stateful, and Medusa-style properties        |
| tier edges are contiguous and half-open                          | Pass                 | one edge function drives tier lookup, widths, and walks         |
| current tier is monotonic on deposits under fixed config         | Pass                 | positive net stake only increases `vaultStake`                  |
| current tier is monotonic over full lifecycle                    | **Not an invariant** | redeems and config retunes can lower it                         |
| holder bucket follows current vault tier                         | **Not an invariant** | bucket is sticky average entry history                          |
| dynamic fee alone makes actor-level wash negative                | **Does not hold**    | two-address curve-only round trip reaches break-even            |
| all configs accepted by `_setConfig` keep fee getters live       | **Fail — DF-01**     | unbounded growth can overflow before cap clamp                  |

## Executed tests

### Current dynamic-fee core and integration selection

Command:

```bash
forge test --match-contract \
  'DynamicFee(FlatPriceCurve|ThirteenTierExample|CurveRouting|AdversarialEconomics|Invariant|GasProfile)Test' -vv
```

Result:

```text
6 suites
128 passed
0 failed
0 skipped
```

This included 10,000-run fuzz cases. Notable observed gas figures:

| Path                                                       | Observed gas |
| ---------------------------------------------------------- | -----------: |
| production-shaped 13-tier full sweep, isolated record hook |      883,762 |
| integration full-ladder dynamic deposit                    |      317,777 |
| steady dynamic deposit                                     |      120,411 |
| steady dynamic redeem                                      |      122,672 |
| claim marginal cost per additional term                    |        2,374 |

The isolated 13-tier sweep booked the depositor in tier 10 while the vault reached the terminal tier, confirming that
holder bucket and current vault tier are distinct.

### Deterministic split-edge measurement

Command:

```bash
forge test --match-contract CurveSplitEdgeMeasurementTest -vv
```

Result: 4 passed, 0 failed.

Observed sample maxima:

| Measurement                            |                               Result |
| -------------------------------------- | -----------------------------------: |
| sub-band one-wallet split edge         |                                4 bps |
| no-bystander multi-wallet edge         |                                5 bps |
| shipped kernel sampled edge            |                               22 bps |
| sigma = 1 tier sampled edge            |                              106 bps |
| alpha = 0 sampled edge                 |                               63 bps |
| sampled wallet-count maxima, N = 2..10 | 0, 5, 59, 37, 54, 33, 32, 66, 59 bps |

These are deterministic sampled measurements, not formal global maxima. They confirm the committed test's stated
direction: the residual saturates in the sampled range and is a redistribution from bystanders, not value creation.

### Average-atom evidence selection

Command:

```bash
forge test --match-test \
  'test_(deployedProductionSchedule_edgesWidthsAndSum|recordDeposit_feeFlowsToPriorTier|recordDeposit_avgEntryTierMovesBucket|vaultFallsBelowItsHolders_feeGoesToProtocolAndRecoversOnTheWayBackUp|setConfig_retune_keepsBucketsStickyAndSolvent|previewRedeemFor_matchesTheHolderTier|previewDeposit_matchesActual_dynamicCurve)' \
  -vv
```

Result: 7 passed, 0 failed.

This selection anchors the average-atom report's production edges, prior-tier-only fee flow, rounded holder buckets,
drawdown blackout/recovery, sticky retune behavior, holder-specific redeem fee, and exact dynamic deposit preview. The
numeric 1k–10k production matrix remains an independent model pending the QA-01 committed full-stack fixture.

### DF-01 proof

A temporary, removed Foundry test executed two cases:

```text
[PASS] validated depositGrowthBps = uint256.max; tier-1 quote panics with 0x11
[PASS] validated withdrawalGrowthBps = uint256.max; tier-1 quote panics with 0x11
```

The proof file was deleted after execution so the requested output remains documents only.

## Independent numeric calculations

The production tier table was recomputed with integer fixed-point arithmetic matching:

```text
edge(k) = width0 * ((1 + growth)^(k+1) - 1) / growth
```

The full table agrees with `test_deployedProductionSchedule_edgesWidthsAndSum` and the deployment script's terminal
threshold.

The corrected 6,000/20,000 reference-ladder quote was independently replayed with the contract's two upward roundings
per band:

```text
fee = 675.771115735927978865 TRUST
curve-fee-net advance = 19,324.228884264072021135 TRUST
```

This is the value used in the scenario report and the evidence for DF-02.

### Average-atom production model

The tier-3/tier-4 scenarios in `05-average-atom-model.md` were independently calculated with integer `BigInt` values at
18-decimal TRUST precision. The model mirrors these contract operations in order:

1. locate the production tier using the committed 5,000-TRUST, 20%-growth edges;
2. quote the dynamic fee with curve-fee-net gross-up and upward fee rounding;
3. subtract upward-rounded 1.25% protocol, 0.50% entry, and 0.50% atom-wallet fees;
4. replay the resulting net stake across actual production bands;
5. compute the stake-weighted average band and half-up holder bucket; and
6. subtract the bucket withdrawal fee plus upward-rounded 1.25% protocol and 0.75% exit fees.

Selected exact results before display rounding:

```text
start 20,000; deposit 10,000
curve fee       264.923076923076923078
net stake     9,510.076923076923076922
replay        t3 6,840 + t4 2,670.076923076923076922
holder bucket 3
roundtrip loss 1,012.977307692307692310

start 25,000; deposit 5,000
curve fee       140.564102564102564104
net stake     4,746.935897435897435896
replay        t3 1,840 + t4 2,906.935897435897435896
holder bucket 4
roundtrip loss   537.880256410256410259

start 36,000; deposit 5,000
curve fee       168.773195876288659795
net stake     4,718.726804123711340205
replay        t4 1,208 + t5 3,510.726804123711340205
holder bucket 5
roundtrip loss   587.990438144329896910
```

The full-band cohort model solves for the minimum gross deposit whose post-`MultiVault`, post-curve net exactly fills
each band. It then applies the production kernel weights to the exact forwarded curve fee. Gross deposits for tiers 0–4
were 5,168.568804, 6,234.509814, 7,520.488510, 9,071.970773, and 10,943.826738 TRUST. These checks are deterministic
scenario calculations, not a formal proof over every configuration or occupancy state.

## Existing assurance reviewed

The repository also contains, but this review did not rerun in full:

- symbolic fee-cap properties in `tests/symbolic/DynamicFeeSymbolic.t.sol`;
- a Medusa conservation/solvency handler and `medusa.dynamicfee.json`;
- security regression suites for fee guardrails, redistribution bounds, floor behavior, neutrality, and curve routing;
- prior multi-reviewer v1.1.0 internal pseudo-audit rounds and disposition registers.

The symbolic deposit/withdrawal cap properties restrict the queried tier domain and a normal-sized configured growth;
they do not refute DF-01's accepted-configuration overflow.

## Coverage limits

- This was a targeted dynamic-fee and lifecycle review, not a new whole-repository audit.
- No mainnet/testnet state was queried; “production” means the committed deploy seed and setup constants.
- Economic edge measurements are sampled or scenario-based unless a committed invariant states otherwise.
- The production average-atom values are an external exact-arithmetic reproduction of the code path, not yet committed
  as an executable Foundry regression; adding that suite is QA-01.
- Beneficial ownership across addresses is not observable on-chain; any actor-level conclusion must account for Sybils.
- Governance actions are assumed to pass through the configured timelock, but operational proposal tooling was not
  reviewed.
- Accumulator dust was reasoned and covered by existing tests; no new global closed-form dust bound was proven.
