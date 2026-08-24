# Core variable-naming alignment proposal

Review target: `330980a6e2cad0aa602b5d11c961b75f2236a690` (`feat/v1.1.0-core-upgrade`)  
Review date: 2026-08-23  
Status: proposal only; no Solidity changes have been made  
Scope: `IBaseCurve`, `BaseCurve`, `IDynamicFeeFlatPriceCurve`, `DynamicFeeFlatPriceCurve`, `IMultiVault`, `MultiVault`,
`MultiVaultLib`, and the core configuration names directly used by these paths.

## Executive conclusion

The motivating `IBaseCurve` parameter is a share quantity, not a deposit-asset quantity. The interface is semantically
correct but insufficiently specific:

1. `MultiVaultLib._processDeposit` calculates and mints `sharesForReceiver`.
2. After the vault write and mint, `_recordCurveDeposit` passes that exact value to
   `IBaseCurve.recordDeposit` (`MultiVaultLib.sol:800-848, 922-927`).
3. The redeem path burns `shares`, then passes that same value to `recordRedeem`
   (`MultiVaultLib.sol:851-895, 933-935`).

Therefore:

- `IBaseCurve.recordDeposit(..., shares)` should become `sharesMinted`, not `assets`.
- `IBaseCurve.recordRedeem(..., shares)` should become `sharesBurned`.
- `DynamicFeeFlatPriceCurve.recordDeposit(..., netStake)` should become `sharesMinted`.
- `DynamicFeeFlatPriceCurve.recordRedeem(..., withdrawnStake)` should become `sharesBurned`.

The misleading part is the dynamic implementation's use of **stake** for a share ledger. The curve tracks minted and
burned shares, while tier widths are denominated in TRUST assets. Those quantities happen to be numerically equal only
because this curve maintains a 1:1 price. Naming the ledger as shares makes that dependency visible and prevents a
future maintainer from treating `netStake` as net vault assets.

## Canonical lifecycle vocabulary

Every variable in the affected flow should identify both its lifecycle stage and its unit.

### Deposit/create

```text
grossAssets
  - one-time atom/triple creation cost or new-vault min-share cost
  = feeBaseAssets
  - MultiVault protocol/entry/atom-wallet/atom-fraction fees
  - curveFeeAssets
  = netAssets
  -> curve conversion
  = sharesMinted
```

### Redeem

```text
sharesToRedeem
  -> curve conversion
  = grossRedeemAssets
  - protocolFeeAssets
  - exitFeeAssets
  - curveFeeAssets
  = netAssets

execution: sharesToRedeem becomes sharesBurned once validation succeeds
```

Recommended meanings:

| Name | Exact meaning |
|---|---|
| `grossAssets` | User-supplied or per-item allocated TRUST before costs and fees. |
| `feeBaseAssets` | TRUST remaining after a creation/min-share cost and used as the base for percentage fees. |
| `netAssets` | TRUST credited to the position on deposit, or paid to the receiver on redeem, after all applicable fees. |
| `curveFeeAssets` | Native TRUST withheld by `MultiVault` and forwarded to the curve hook. |
| `sharesToRedeem` | Requested/previewed share input before execution. |
| `sharesMinted` / `sharesBurned` | The actual share delta after the operation succeeds. |
| `userSharesAfter` | The account's share balance after the mint or burn; never a vault-wide total. |
| `grossRedeemAssets` | Asset value of the redeemed shares before any redeem-side fees. |
| `...Bps` | A basis-point value. |
| `...Scaled` / `...Wad` | A fixed-point value; the scale must be stated in NatSpec. |

Avoid bare `assets`, `amount`, `fee`, `shares`, and `stake` where more than one lifecycle stage or unit is in scope.

## P0 — Required hook and dynamic-ledger alignment

These are the highest-confidence changes. They correct names that currently obscure the value's actual unit.

### `src/interfaces/IBaseCurve.sol`

| Current line | Current | Proposed | Reason |
|---:|---|---|---|
| 135-137 | `assets`, return `fee` in `quoteDepositFee` | `depositFeeBaseAssets`, return `curveFeeAssets` | The input is post-min-share-cost but pre-MultiVault-fees; it is not the final deposited asset amount. |
| 144-146 | `assets`, return `fee` in `quoteRedeemFee` | `grossRedeemAssets`, return `curveFeeAssets` | This is the gross conversion value before all redeem fees. |
| 161-164 | `shares` in `recordDeposit` | `sharesMinted` | It is the exact post-mint share delta forwarded by `MultiVaultLib`. |
| 171-174 | `shares` in `recordRedeem` | `sharesBurned` | It is the exact burned share delta. |

NatSpec should explicitly call both record functions **post-operation accounting callbacks**. That distinguishes
`recordDeposit` from the public payable `MultiVault.deposit`, whose economic input is native assets through `msg.value`.

`src/protocol/curves/BaseCurve.sol:163-179` should keep its hook arguments unnamed. These default implementations only
revert, so naming unused arguments adds no clarity inside the body and can introduce unused-parameter warnings. They
inherit the authoritative names and documentation from `IBaseCurve`; this is intentional, not an alignment gap.

### `src/protocol/curves/DynamicFeeFlatPriceCurve.sol`

#### Public state and fixed-point values

| Current line(s) | Current | Proposed | Reason |
|---:|---|---|---|
| 112-137 | `MAX_MIN_ELIGIBLE_TIER_STAKE` and related comments | `MAX_MIN_ELIGIBLE_TIER_SHARES` | The eligibility denominator is shares. |
| 155-165 | `vaultStake` | `trackedVaultShares` | Sum of hook-recorded user shares; it intentionally excludes the MultiVault burn seed, so `vaultShares` alone would be ambiguous. |
| 167-168 | `tierStake` | `tierShares` | Sum of user shares bucketed in a tier. |
| 173-174 | `userStake` | `userShares` | Exact dynamic-curve share balance recorded for a user. |
| 179-180 | `userAvgTier` | `userAvgTierScaled` | The value is scaled by `TIER_PRECISION`, unlike `userTier`. |
| 182 | formula comment uses `stake` | use `userShares` | Align the reward-debt formula with the ledger's real unit. |
| 75, 170 | “stake-weighted” / “per unit of stake” | “share-weighted” / “per share” | Makes the unit consistent with `accFeePerShare`. |

Keep `accFeePerShare`, `userTier`, `rewardDebt`, `earned`, and `protocolAccrued`; these already describe their values
accurately.

#### Hook functions and events

| Current line(s) | Current | Proposed |
|---:|---|---|
| 410-412 | `baseAssets`, return `fee` | `depositFeeBaseAssets`, return `curveFeeAssets` |
| 417-425 | `grossAssets`, return `fee` | `grossRedeemAssets`, return `curveFeeAssets` |
| 448-471 | `netStake` | `sharesMinted` |
| 455 | `feeAmount` | `curveFeeAssets` |
| 456-467 | `startAssets` | `startingTrackedShares` |
| 482-558 | `withdrawnStake` | `sharesBurned` |
| 489 | `feeAmount` | `curveFeeAssets` |
| 499, 552, 555 | `residual` | `remainingUserShares` |
| 506-524 | `denom` | `otherTierShares` |
| 520-524 | `recipientStake` | `recipientShares` |
| 224-232 | event `netStake`, `fee`, `accountAvgTier` | `sharesMinted`, `curveFeeAssets`, `accountAvgTierScaled` |
| 238-240 | event `bandStake`, `bandFee` | `bandShares`, `bandFeeAssets` |
| 241-243 | event `withdrawnStake`, `fee` | `sharesBurned`, `curveFeeAssets` |

#### Internal accounting ripple

The same unit correction should be applied atomically through the internal call graph, rather than stopping at the
external hook signature.

| Current line(s) | Current | Proposed |
|---:|---|---|
| 665-675, 742-750 | local `stake` | `userShares` |
| 755-800 | `_walkDepositBands(startAssets, netStake, ...)`, `bandStake`, `remaining` | `_walkDepositBands(startingTrackedShares, sharesMinted, ...)`, `bandShares`, `remainingShares` |
| 802-862 | `_replayDepositBands(... startAssets, netStake, feeAmount)`, local `bandStake` | `startingTrackedShares`, `sharesMinted`, `curveFeeAssets`, `bandShares` |
| 882-923 | `_applyDepositBand(... bandStake, bandFee)`, `oldStake`, `newStake` | `bandShares`, `bandFeeAssets`, `oldUserShares`, `newUserShares` |
| 926-961 | `_payDepositFee(... feeAmount)` and `recipientStake` | `curveFeeAssets` and `recipientShares` |
| 972-973 | `_isEligibleStake(stake)` | `_isEligibleTierShares(tierShares_)` |
| 993-1028 | `excludeStake` | `excludedShares` |
| 1073-1105 | array `stakes`, `recipientStake`, `sigma` | `eligibleTierShares`, `recipientShares`, `kernelSpreadTierWad` |
| 1124-1143 | `recipientStake`, `bestStake` | `recipientShares`, `bestRecipientShares` |
| 1184-1243 | local `s`, return `recipientStake` | `candidateTierShares`, return `recipientShares` |
| 1260-1304 | `_piecewiseDepositFee(startAssets, baseAssets)` | `_piecewiseDepositFee(startingTrackedShares, depositFeeBaseAssets)` |

`startingTrackedShares` is intentionally not called `startingAssets`: `_tierOf` interprets it against an asset-based
tier ladder only because the flat-price curve is 1:1. Preserve and tighten the existing NatSpec warning at
`DynamicFeeFlatPriceCurve.sol:155-164`; do not hide this coupling behind an asset name.

### `src/interfaces/IDynamicFeeFlatPriceCurve.sol`

| Current line(s) | Current | Proposed | Unit |
|---:|---|---|---|
| 16-28 | `width0` | `tier0WidthAssets` | TRUST wei |
| 20-28 | `growthGBps` | `tierWidthGrowthBps` | bps |
| 35-40 | `fulcrumAlpha` | `fulcrumPositionBps` | bps |
| 41-46 | `kernelSpread` | `kernelSpreadTierWad` | `1e18`-scaled tiers |
| 69-78 | `minEligibleTierStake` | `minEligibleTierShares` | shares |
| 155-168 | `shares`, `assetsAfterCurveFee`, `fee` in `previewRedeemFor` | `sharesToRedeem`, `grossAssetsAfterCurveFee`, `curveFeeAssets` | shares / TRUST wei |

The first four configuration renames are strong unit-clarity improvements but are grouped with the ABI-sensitive
decisions below because they affect public struct component names throughout deployment tooling.

## P1 — Align `MultiVault` lifecycle names

These changes make the asset-to-share stages readable end to end. They do not alter calculations.

### `src/interfaces/IMultiVault.sol`

#### Events

| Current line(s) | Current | Proposed |
|---:|---|---|
| 131-146 | `Deposited.assets` | `grossAssets` |
| 133-146 | `Deposited.assetsAfterFees` | `netAssets` |
| 134-146 | `Deposited.shares` | `sharesMinted` |
| 135-146 | `Deposited.totalShares` | `userSharesAfter` |
| 155-169 | `Redeemed.shares` | `sharesBurned` |
| 156-169 | `Redeemed.totalShares` | `userSharesAfter` |
| 157-169 | `Redeemed.assets` | `netAssets` |
| 158-169 | `Redeemed.fees` | `totalFeeAssets` |

`totalShares` is the most materially misleading event name: the implementation passes the user's post-operation
balance, not `VaultState.totalShares` (`MultiVaultLib.sol:825-845, 873-893`).

#### Previews and write entry points

| Current line(s) | Current | Proposed |
|---:|---|---|
| 425-436 | `previewAtomCreate(... assets) -> (shares, assetsAfterFixedFees, assetsAfterFees)` | `(... grossAssets) -> (sharesMinted, feeBaseAssets, netAssets)` |
| 438-448 | `previewDeposit(... assets) -> (shares, assetsAfterFees)` | `(... grossAssets) -> (sharesMinted, netAssets)` |
| 450-476 | `previewRedeem(... shares) -> (assetsAfterFees, sharesUsed)` | `(... sharesToRedeem) -> (netAssets, sharesRedeemed)` |
| 478-489 | triple-create names mirror atom-create names | use `grossAssets`, `sharesMinted`, `feeBaseAssets`, `netAssets` |
| 510-600 | creation arrays `assets` | `grossAssets` |
| 610-613 | unnamed `deposit` return | `returns (uint256 sharesMinted)` |
| 624-630 | batch `assets`, unnamed return | `grossAssets`, `returns (uint256[] memory sharesMinted)` |
| 643-646 | `redeem(... shares, minAssets)`, unnamed return | `redeem(... sharesToRedeem, minAssets) returns (uint256 netAssets)` |
| 659-665 | batch `shares`, unnamed return | `sharesToRedeem`, `returns (uint256[] memory netAssets)` |

For create calls, each array entry includes the creation cost and initial vault allocation, so `grossAssets` is more
accurate than `depositAssets` or `assetsToDeposit`.

### `src/protocol/MultiVault.sol`

Mirror the interface names at these forwarding boundaries:

- Previews at lines 454-489: `grossAssets`, `feeBaseAssets`, `netAssets`, `sharesMinted`, `sharesToRedeem`,
  `sharesRedeemed`.
- Creation and deposit forwarding at lines 620-693: `assets` arrays to `grossAssets`; name deposit returns
  `sharesMinted`.
- Redeem forwarding at lines 697-716: `shares` to `sharesToRedeem`; name returns `netAssets`.
- Internal `_burn` wrapper around line 879: `amount` to `shares`.
- The redeem calculation comment around line 106: `rawAssetsBeforeFees` to `grossRedeemAssets`.

Keep `convertToShares(... assets)` and `convertToAssets(... shares)` at lines 493-501. These are generic conversion
functions and the current names are correct.

### `src/libraries/MultiVaultLib.sol`

The library is where stage-specific names matter most.

| Current line(s) | Current | Proposed |
|---:|---|---|
| 161-170 | `CurveHook.curve`, `CurveHook.fee` | `curveAddress`, `curveFeeAssets` |
| 180-420 | entry-point `payment`, `_amount`, `_assetsSum` | `suppliedValue`, `totalGrossAssets`, `totalGrossAssets` as applicable |
| 321-390 | `rawAssetsBeforeFees`, `assetsAfterFees`, return arrays `assets` | `grossRedeemAssets`, `netAssets`, `netAssets` |
| 433-467 | public calculation return names | mirror the interface preview names |
| 800-848 | `assets`, `sharesForReceiver`, `assetsAfterMinSharesCost`, `assetsAfterFees`, `userBalanceAfter` | `grossAssets`, `sharesMinted`, `feeBaseAssets`, `netAssets`, `userSharesAfter` |
| 851-895 | `shares`, `rawAssetsBeforeFees`, `assetsAfterFees` | `sharesBurned`, `grossRedeemAssets`, `netAssets` |
| 922-927 | `receiver`, `hook`, `sharesForReceiver` | `account`, `hook`, `sharesMinted` |
| 933-935 | `receiver`, `shares` | `account`, `sharesBurned` |
| 969-1037 | deposit calculators' `assets`, `shares`, `assetsAfterMinSharesCost`, `assetsAfterFees` | `grossAssets`, `sharesMinted`, `feeBaseAssets`, `netAssets` |
| 981-1002 | create calculator's `assetsAfterFixedFees` | `feeBaseAssets` |
| 1039-1058 | triple-create equivalents | `grossAssets`, `feeBaseAssets`, `netAssets`, `sharesMinted` |
| 1104-1115 | `_depositShares(... assetsAfterFees)` | `_depositShares(... netAssets)` |
| 1118-1151 | `_calculateRedeem(... shares)`, local `assets`, `totalFees`, `assetsAfterFees` | `sharesToRedeem`, `grossRedeemAssets`, `totalFeeAssets`, `netAssets` |
| 1265-1310 | creation/deposit update args `assets`, `shares` | `netAssets`, `sharesMinted` |
| 1312-1325 | redeem update args `assets`, `shares` | `grossRedeemAssets`, `sharesBurned` |
| 1375-1397 | `_mint/_burn(... amount)` | `_mint/_burn(... shares)` |
| 1404-1408 | `_validateMinDeposit(assets)` | `_validateMinDeposit(grossAssets)` |
| 1410-1428 | `_validatePayment(assets, payment) -> total` | `_validatePayment(grossAssets, suppliedValue) -> totalGrossAssets` |
| 1430-1458 | validation stage names | `grossAssets`, `sharesMinted`, `feeBaseAssets`, `netAssets`, `minShares` |
| 1461 onward | `_validateRedeem(... shares)` | `_validateRedeem(... sharesToRedeem)` |

Also rename fee-accumulator parameters that are currently bare `assets` to `feeBaseAssets`, and utilization deltas to
`grossAssetsDeposited` / `grossRedeemAssets`. Keep `_feeOnRaw(amount, fee)` generic only if it remains truly unit-agnostic;
otherwise prefer `feeBaseAssets` and `feeBps`.

## P1 — Standardize redeem versus withdrawal terminology

The protocol entry point and hook are `redeem`: the caller supplies shares and receives assets. “Withdraw” normally
means the inverse API, where the caller specifies an asset amount. The dynamic curve currently mixes both words for the
same share-input operation.

Recommended comprehensive rename:

| Location | Current | Proposed |
|---|---|---|
| `IDynamicFeeFlatPriceCurve.sol:47-58` | `withdrawalBaseBps` | `redeemBaseBps` |
| same | `withdrawalGrowthBps` | `redeemGrowthBps` |
| same | `withdrawalCapBps` | `redeemCapBps` |
| same | `withdrawalToFulcrumTiersBps` | `redeemToFulcrumTiersBps` |
| `IDynamicFeeFlatPriceCurve.sol:81-92` | `withdrawalFeeBps` | `redeemFeeBps` |
| `DynamicFeeFlatPriceCurve.sol:105-110` | `MAX_WITHDRAWAL_CAP_BPS` | `MAX_REDEEM_CAP_BPS` |
| `DynamicFeeFlatPriceCurve.sol:149-152, 424` | `_withdrawalFeeBps` | `_redeemFeeBps` |
| dynamic public getter | `withdrawalFeeBps(uint256 tier)` | `redeemFeeBps(uint256 tier)` |
| `DynamicFeeFlatPriceCurve.sol:247` | `WithdrawalFeeRerouted` | `RedeemFeeRerouted` |
| `DynamicFeeFlatPriceCurve.sol:248` | event field `withdrawalFeeBps` | `redeemFeeBps` |
| `DynamicFeeFlatPriceCurve.sol:476-558` | comments saying withdrawal/exiter | use redeem/redeemer where referring to the operation/account |

Keep `VaultFees.exitFee` as the MultiVault business-fee term if desired; “entry/exit fee” is a coherent pair distinct
from the operation's API verb. If the unit-suffix pass below is approved, use `entryFeeBps` and `exitFeeBps`.

## P2 — Core configuration unit suffixes

These names are not mathematically wrong, but they make values easy to misconfigure. This is a wider surface than the
dynamic curve and should be approved as a separate batch.

### `src/interfaces/IMultiVaultCore.sol`

| Current line(s) | Current | Proposed |
|---:|---|---|
| 16-17 | `minDeposit` | `minDepositAssets` |
| 18-19 | `minShare` | `minShares` |
| 22-24 | `feeThreshold` | `defaultCurveFeeThresholdShares` |
| 29-30 | `atomCreationProtocolFee` | `atomCreationProtocolFeeAssets` |
| 31-32 | `atomWalletDepositFee` | `atomWalletDepositFeeBps` |
| 45-46 | `tripleCreationProtocolFee` | `tripleCreationProtocolFeeAssets` |
| 47-48 | `atomDepositFractionForTriple` | `atomDepositFractionForTripleBps` |
| 65-73 | `entryFee`, `exitFee`, `protocolFee` | `entryFeeBps`, `exitFeeBps`, `protocolFeeBps` |
| 92-160 | corresponding event parameter names | mirror all names above |

The fixed creation fees are TRUST wei; the wallet/fraction/vault fee fields are numerator values over
`feeDenominator`. If governance may set a denominator other than 10,000, `...Bps` would be inaccurate; in that case use
`...FeeRate` and make the denominator explicit instead. The current code and dynamic configuration should first confirm
that `feeDenominator == 10_000` is an invariant before choosing the `Bps` suffix.

## Names that should not change

| Name | Decision |
|---|---|
| `recordDeposit` / `recordRedeem` | Keep the function names. They describe callbacks for completed operations; fix their arguments and NatSpec instead. |
| `recordDeposit` argument unit | Keep it as shares. Do not change it to gross or net assets. The curve ledger mirrors minted shares. |
| `accFeePerShare` | Keep. It accurately identifies an asset-fee accumulator divided by eligible shares. |
| `userTier` | Keep. It is an integer bucket, unlike scaled `userAvgTierScaled`. |
| `convertToShares(assets)` / `convertToAssets(shares)` | Keep. The generic input units are unambiguous. |
| public `deposit` asset argument | Do not add one to the single-deposit API solely for naming symmetry; its asset input is `msg.value`. |
| `entryFee` / `exitFee` terminology | Keep the entry/exit pair conceptually; only add unit suffixes if the P2 pass is approved. |

## ABI, storage, event, and integration impact

No proposed rename changes storage order or numeric behavior, but not all are ABI-neutral.

| Rename type | On-chain effect |
|---|---|
| Function parameter or return **name only** | Selector and encoding unchanged; ABI JSON names and generated client fields change. |
| Internal/local variable | No ABI or storage effect. |
| Event parameter name | Event signature/topic unchanged; ABI metadata and indexer-decoded field keys change. |
| Struct field name | Tuple encoding and storage layout unchanged; Solidity member access, ABI component names, scripts, and generated types change. |
| Public mapping variable name | Getter function selector changes. This is a real external ABI break. |
| External/public function or event name | Function selector or event topic changes. This is a real external ABI break. |

Consequences for the recommended comprehensive pass:

- Renaming `vaultStake`, `tierStake`, `userStake`, or `userAvgTier` changes their autogenerated getter selectors.
- Renaming public constants such as `MAX_WITHDRAWAL_CAP_BPS` and `MAX_MIN_ELIGIBLE_TIER_STAKE` also changes their
  autogenerated getter selectors.
- Renaming `withdrawalFeeBps(...)` changes its selector; renaming `WithdrawalFeeRerouted` changes the event topic.
- Renaming dynamic/core config fields requires deployment scripts, fixtures, tests, ABI artifacts, TypeScript bindings,
  subgraphs/indexers, and documentation to update even though the tuple layout is unchanged.
- Event-field-only renames require indexer schema/mapping review even when the topic is stable.

If this curve has not been deployed under its final curve ID, the comprehensive rename is preferable now. If consumers
already depend on the ABI, use a compatibility-safe pass: keep legacy public getter/function/event names, add precise
NatSpec, rename hook parameters/events fields/internal variables, and optionally add new alias getters before deprecating
the old ones.

## Optional future semantic change — not part of this rename proposal

The generic hook currently quotes fees in assets but records positions in shares. That is coherent:

```text
quoteDepositFee(feeBaseAssets) -> curveFeeAssets
recordDeposit(sharesMinted)

quoteRedeemFee(grossRedeemAssets) -> curveFeeAssets
recordRedeem(sharesBurned)
```

Do not expand `recordDeposit` or `recordRedeem` to receive both assets and shares merely to make the signatures look
symmetrical. If a future non-flat hook needs asset-denominated tier accounting, that is an interface redesign: pass both
the relevant asset delta and the share delta, define which asset stage is authoritative, version the hook, and test
non-1:1 price drift. It should not be smuggled into a naming-only change.

## Recommended approval package

For a pre-deployment core upgrade, approve these as one atomic naming PR:

1. P0 hook names and the entire dynamic share-ledger ripple.
2. P1 MultiVault lifecycle-stage names, including the misleading event `totalShares -> userSharesAfter`.
3. P1 withdrawal-to-redeem terminology.
4. Dynamic config unit names (`tier0WidthAssets`, `tierWidthGrowthBps`, `fulcrumPositionBps`,
   `kernelSpreadTierWad`, `minEligibleTierShares`).
5. Regenerate ABI/bindings and update all event consumers in the same PR.

Treat the P2 `IMultiVaultCore` configuration suffixes as a separate approval because their blast radius extends beyond
the dynamic-fee upgrade. Confirm whether `feeDenominator` is permanently 10,000 before using `Bps` in those field names.

## Implementation and verification checklist after approval

- Rename interface, implementation, library, tests, deploy fixtures, scripts, and docs in a single mechanical pass.
- Compile after the interface/dynamic changes, then after the MultiVault changes, to catch stale named returns and struct
  literals early.
- Search for every old name in `src/`, `test/`, `script/`, `docs/`, and generated bindings.
- Update direct dependents already present at `tests/unit/curves/DynamicFeeFlatPriceCurve.t.sol:93-98`,
  `tests/medusa/DynamicFeeMedusaHandler.sol:70-81`, `tests/mocks/MockFeeHookCurve.sol:58-66`, the dynamic security and
  symbolic suites, `script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:128-158`, and
  `abis/DynamicFeeFlatPriceCurve.ts`.
- Assert hook dataflow in tests: recorded deposit delta equals minted shares; recorded redeem delta equals burned shares;
  forwarded native value equals the previously quoted curve fee.
- Assert event values and renamed decoded fields for deposit and redeem.
- Assert `trackedVaultShares == sum(tierShares) == sum(userShares)` for the dynamic ledger, excluding the MultiVault
  min-share burn seed as designed.
- Re-run dynamic lifecycle, integration, adversarial, fuzz, invariant, and ABI snapshot tests.
- Review subgraph/indexer migrations before deployment.
- Verify the final diff contains naming/NatSpec/artifact changes only; any arithmetic or storage-layout change requires a
  separate review.

## Decisions requested before implementation

1. Is the dynamic curve still pre-deployment, so public mapping getters and event/function names may break cleanly?
2. Approve `withdrawal* -> redeem*` across the curve ABI, or preserve legacy aliases?
3. Approve the broad `IMultiVaultCore` unit-suffix pass, or keep it separate?
4. Confirm that the hook remains share-ledger-only; the recommendation is **yes**, with no interface expansion.
