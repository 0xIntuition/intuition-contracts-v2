<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# DynamicFeeFlatPriceCurve.recordDeposit

Books the depositor position and distributes the forwarded fee across the prior tiers.

Reached functions: 18. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph DynamicFeeFlatPriceCurve["DynamicFeeFlatPriceCurve"]
    DynamicFeeFlatPriceCurve__applyDepositBand["_applyDepositBand"]
    DynamicFeeFlatPriceCurve__awardNearestOrProtocol["_awardNearestOrProtocol"]
    DynamicFeeFlatPriceCurve__creditByWeight["_creditByWeight"]
    DynamicFeeFlatPriceCurve__depositFeeBps["_depositFeeBps"]
    DynamicFeeFlatPriceCurve__fulcrumDistance["_fulcrumDistance"]
    DynamicFeeFlatPriceCurve__isEligibleStake["_isEligibleStake"]
    DynamicFeeFlatPriceCurve__nearestEligiblePriorTier["_nearestEligiblePriorTier"]
    DynamicFeeFlatPriceCurve__payDepositFee["_payDepositFee"]
    DynamicFeeFlatPriceCurve__payFulcrumTiers["_payFulcrumTiers"]
    DynamicFeeFlatPriceCurve__replayDepositBands["_replayDepositBands"]
    DynamicFeeFlatPriceCurve__roundTier["_roundTier"]
    DynamicFeeFlatPriceCurve__settle["_settle"]
    DynamicFeeFlatPriceCurve__tierOf["_tierOf"]
    DynamicFeeFlatPriceCurve__tierUpperEdge["_tierUpperEdge"]
    DynamicFeeFlatPriceCurve__triangularWeight["_triangularWeight"]
    DynamicFeeFlatPriceCurve__walkDepositBands["_walkDepositBands"]
    DynamicFeeFlatPriceCurve__weighPriorTiers["_weighPriorTiers"]
    DynamicFeeFlatPriceCurve_recordDeposit["recordDeposit"]
  end
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__payDepositFee
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__replayDepositBands
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__tierOf
  DynamicFeeFlatPriceCurve__payDepositFee --> DynamicFeeFlatPriceCurve__nearestEligiblePriorTier
  DynamicFeeFlatPriceCurve__payDepositFee --> DynamicFeeFlatPriceCurve__payFulcrumTiers
  DynamicFeeFlatPriceCurve__replayDepositBands --> DynamicFeeFlatPriceCurve__applyDepositBand
  DynamicFeeFlatPriceCurve__replayDepositBands --> DynamicFeeFlatPriceCurve__depositFeeBps
  DynamicFeeFlatPriceCurve__replayDepositBands --> DynamicFeeFlatPriceCurve__tierOf
  DynamicFeeFlatPriceCurve__replayDepositBands --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__replayDepositBands --> DynamicFeeFlatPriceCurve__walkDepositBands
  DynamicFeeFlatPriceCurve__tierOf --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__nearestEligiblePriorTier --> DynamicFeeFlatPriceCurve__isEligibleStake
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__awardNearestOrProtocol
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__creditByWeight
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__weighPriorTiers
  DynamicFeeFlatPriceCurve__applyDepositBand --> DynamicFeeFlatPriceCurve__payDepositFee
  DynamicFeeFlatPriceCurve__applyDepositBand --> DynamicFeeFlatPriceCurve__roundTier
  DynamicFeeFlatPriceCurve__applyDepositBand --> DynamicFeeFlatPriceCurve__settle
  DynamicFeeFlatPriceCurve__walkDepositBands --> DynamicFeeFlatPriceCurve__depositFeeBps
  DynamicFeeFlatPriceCurve__walkDepositBands --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__awardNearestOrProtocol --> DynamicFeeFlatPriceCurve__fulcrumDistance
  DynamicFeeFlatPriceCurve__weighPriorTiers --> DynamicFeeFlatPriceCurve__fulcrumDistance
  DynamicFeeFlatPriceCurve__weighPriorTiers --> DynamicFeeFlatPriceCurve__isEligibleStake
  DynamicFeeFlatPriceCurve__weighPriorTiers --> DynamicFeeFlatPriceCurve__triangularWeight
  style DynamicFeeFlatPriceCurve_recordDeposit stroke-width:3px
```

## Trace

```text
DynamicFeeFlatPriceCurve.recordDeposit
  DynamicFeeFlatPriceCurve._payDepositFee
    DynamicFeeFlatPriceCurve._nearestEligiblePriorTier
      DynamicFeeFlatPriceCurve._isEligibleStake
    DynamicFeeFlatPriceCurve._payFulcrumTiers
      DynamicFeeFlatPriceCurve._awardNearestOrProtocol
        DynamicFeeFlatPriceCurve._fulcrumDistance
      DynamicFeeFlatPriceCurve._creditByWeight
      DynamicFeeFlatPriceCurve._weighPriorTiers
        DynamicFeeFlatPriceCurve._fulcrumDistance
        DynamicFeeFlatPriceCurve._isEligibleStake
        DynamicFeeFlatPriceCurve._triangularWeight
  DynamicFeeFlatPriceCurve._replayDepositBands
    DynamicFeeFlatPriceCurve._applyDepositBand
      DynamicFeeFlatPriceCurve._payDepositFee  (expanded above)
      DynamicFeeFlatPriceCurve._roundTier
      DynamicFeeFlatPriceCurve._settle
    DynamicFeeFlatPriceCurve._depositFeeBps
    DynamicFeeFlatPriceCurve._tierOf
      DynamicFeeFlatPriceCurve._tierUpperEdge
    DynamicFeeFlatPriceCurve._tierUpperEdge
    DynamicFeeFlatPriceCurve._walkDepositBands
      DynamicFeeFlatPriceCurve._depositFeeBps
      DynamicFeeFlatPriceCurve._tierUpperEdge
  DynamicFeeFlatPriceCurve._tierOf  (expanded above)
```
