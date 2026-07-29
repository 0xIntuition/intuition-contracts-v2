<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# DynamicFeeFlatPriceCurve.recordRedeem

Books the exit and distributes the forwarded fee to the exiting tier, then the prior tiers.

Reached functions: 11. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into
the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph DynamicFeeFlatPriceCurve["DynamicFeeFlatPriceCurve"]
    DynamicFeeFlatPriceCurve__awardNearestOrProtocol["_awardNearestOrProtocol"]
    DynamicFeeFlatPriceCurve__creditByWeight["_creditByWeight"]
    DynamicFeeFlatPriceCurve__fulcrumDistance["_fulcrumDistance"]
    DynamicFeeFlatPriceCurve__nearestOccupiedTier["_nearestOccupiedTier"]
    DynamicFeeFlatPriceCurve__payFulcrumTiers["_payFulcrumTiers"]
    DynamicFeeFlatPriceCurve__settle["_settle"]
    DynamicFeeFlatPriceCurve__tierOf["_tierOf"]
    DynamicFeeFlatPriceCurve__tierUpperEdge["_tierUpperEdge"]
    DynamicFeeFlatPriceCurve__triangularWeight["_triangularWeight"]
    DynamicFeeFlatPriceCurve__weighPriorTiers["_weighPriorTiers"]
    DynamicFeeFlatPriceCurve_recordRedeem["recordRedeem"]
  end
  DynamicFeeFlatPriceCurve_recordRedeem --> DynamicFeeFlatPriceCurve__nearestOccupiedTier
  DynamicFeeFlatPriceCurve_recordRedeem --> DynamicFeeFlatPriceCurve__payFulcrumTiers
  DynamicFeeFlatPriceCurve_recordRedeem --> DynamicFeeFlatPriceCurve__settle
  DynamicFeeFlatPriceCurve_recordRedeem --> DynamicFeeFlatPriceCurve__tierOf
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__awardNearestOrProtocol
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__creditByWeight
  DynamicFeeFlatPriceCurve__payFulcrumTiers --> DynamicFeeFlatPriceCurve__weighPriorTiers
  DynamicFeeFlatPriceCurve__tierOf --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__awardNearestOrProtocol --> DynamicFeeFlatPriceCurve__fulcrumDistance
  DynamicFeeFlatPriceCurve__weighPriorTiers --> DynamicFeeFlatPriceCurve__fulcrumDistance
  DynamicFeeFlatPriceCurve__weighPriorTiers --> DynamicFeeFlatPriceCurve__triangularWeight
  style DynamicFeeFlatPriceCurve_recordRedeem stroke-width:3px
```

## Trace

```text
DynamicFeeFlatPriceCurve.recordRedeem
  DynamicFeeFlatPriceCurve._nearestOccupiedTier
  DynamicFeeFlatPriceCurve._payFulcrumTiers
    DynamicFeeFlatPriceCurve._awardNearestOrProtocol
      DynamicFeeFlatPriceCurve._fulcrumDistance
    DynamicFeeFlatPriceCurve._creditByWeight
    DynamicFeeFlatPriceCurve._weighPriorTiers
      DynamicFeeFlatPriceCurve._fulcrumDistance
      DynamicFeeFlatPriceCurve._triangularWeight
  DynamicFeeFlatPriceCurve._settle
  DynamicFeeFlatPriceCurve._tierOf
    DynamicFeeFlatPriceCurve._tierUpperEdge
```
