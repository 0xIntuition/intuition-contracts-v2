<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# DynamicFeeFlatPriceCurve.recordDeposit

Books the depositor position and distributes the forwarded fee across the prior tiers.

Reached functions: 14. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph DynamicFeeFlatPriceCurve["DynamicFeeFlatPriceCurve"]
    DynamicFeeFlatPriceCurve__awardNearestOrProtocol["_awardNearestOrProtocol"]
    DynamicFeeFlatPriceCurve__creditByWeight["_creditByWeight"]
    DynamicFeeFlatPriceCurve__fulcrumDistance["_fulcrumDistance"]
    DynamicFeeFlatPriceCurve__isEligibleStake["_isEligibleStake"]
    DynamicFeeFlatPriceCurve__nearestOccupiedPriorTier["_nearestOccupiedPriorTier"]
    DynamicFeeFlatPriceCurve__payDepositFee["_payDepositFee"]
    DynamicFeeFlatPriceCurve__payFulcrumTiers["_payFulcrumTiers"]
    DynamicFeeFlatPriceCurve__roundTier["_roundTier"]
    DynamicFeeFlatPriceCurve__settle["_settle"]
    DynamicFeeFlatPriceCurve__tierOf["_tierOf"]
    DynamicFeeFlatPriceCurve__tierUpperEdge["_tierUpperEdge"]
    DynamicFeeFlatPriceCurve__triangularWeight["_triangularWeight"]
    DynamicFeeFlatPriceCurve__weighPriorTiers["_weighPriorTiers"]
    DynamicFeeFlatPriceCurve_recordDeposit["recordDeposit"]
  end
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__payDepositFee
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__roundTier
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__settle
  DynamicFeeFlatPriceCurve_recordDeposit --> DynamicFeeFlatPriceCurve__tierOf
  DynamicFeeFlatPriceCurve__payDepositFee --> DynamicFeeFlatPriceCurve__nearestOccupiedPriorTier
  DynamicFeeFlatPriceCurve__payDepositFee --> DynamicFeeFlatPriceCurve__payFulcrumTiers
  DynamicFeeFlatPriceCurve__tierOf --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__nearestOccupiedPriorTier --> DynamicFeeFlatPriceCurve__isEligibleStake
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__awardNearestOrProtocol
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__creditByWeight
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__weighPriorTiers
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
    DynamicFeeFlatPriceCurve._nearestOccupiedPriorTier
      DynamicFeeFlatPriceCurve._isEligibleStake
    DynamicFeeFlatPriceCurve._payFulcrumTiers
      DynamicFeeFlatPriceCurve._awardNearestOrProtocol
        DynamicFeeFlatPriceCurve._fulcrumDistance
      DynamicFeeFlatPriceCurve._creditByWeight
      DynamicFeeFlatPriceCurve._weighPriorTiers
        DynamicFeeFlatPriceCurve._fulcrumDistance
        DynamicFeeFlatPriceCurve._isEligibleStake
        DynamicFeeFlatPriceCurve._triangularWeight
  DynamicFeeFlatPriceCurve._roundTier
  DynamicFeeFlatPriceCurve._settle
  DynamicFeeFlatPriceCurve._tierOf
    DynamicFeeFlatPriceCurve._tierUpperEdge
```
