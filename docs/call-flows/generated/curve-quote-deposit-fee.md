<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# DynamicFeeFlatPriceCurve.quoteDepositFee

The piecewise deposit-fee walk across tier bands (view; called during deposit calculation).

Reached functions: 5. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph DynamicFeeFlatPriceCurve["DynamicFeeFlatPriceCurve"]
    DynamicFeeFlatPriceCurve__depositFeeBps["_depositFeeBps"]
    DynamicFeeFlatPriceCurve__piecewiseDepositFee["_piecewiseDepositFee"]
    DynamicFeeFlatPriceCurve__tierOf["_tierOf"]
    DynamicFeeFlatPriceCurve__tierUpperEdge["_tierUpperEdge"]
    DynamicFeeFlatPriceCurve_quoteDepositFee["quoteDepositFee"]
  end
  DynamicFeeFlatPriceCurve_quoteDepositFee --> DynamicFeeFlatPriceCurve__piecewiseDepositFee
  DynamicFeeFlatPriceCurve__piecewiseDepositFee --> DynamicFeeFlatPriceCurve__depositFeeBps
  DynamicFeeFlatPriceCurve__piecewiseDepositFee --> DynamicFeeFlatPriceCurve__tierOf
  DynamicFeeFlatPriceCurve__piecewiseDepositFee --> DynamicFeeFlatPriceCurve__tierUpperEdge
  DynamicFeeFlatPriceCurve__tierOf --> DynamicFeeFlatPriceCurve__tierUpperEdge
  style DynamicFeeFlatPriceCurve_quoteDepositFee stroke-width:3px
```

## Trace

```text
DynamicFeeFlatPriceCurve.quoteDepositFee
  DynamicFeeFlatPriceCurve._piecewiseDepositFee
    DynamicFeeFlatPriceCurve._depositFeeBps
    DynamicFeeFlatPriceCurve._tierOf
      DynamicFeeFlatPriceCurve._tierUpperEdge
    DynamicFeeFlatPriceCurve._tierUpperEdge
```
