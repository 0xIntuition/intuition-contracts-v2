<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# MultiVault.redeem

Single-term redeem. Vault state is lowered, the curve records the exit, and only then is the payout sent.

Reached functions: 32. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph IBaseCurve["IBaseCurve"]
    IBaseCurve_hasRedeemFeeHook["hasRedeemFeeHook"]
    IBaseCurve_quoteRedeemFee["quoteRedeemFee"]
    IBaseCurve_recordRedeem["recordRedeem"]
  end
  subgraph IBondingCurveRegistry["IBondingCurveRegistry"]
    IBondingCurveRegistry_currentPrice["currentPrice"]
    IBondingCurveRegistry_curveAddresses["curveAddresses"]
    IBondingCurveRegistry_getCurveMaxAssets["getCurveMaxAssets"]
    IBondingCurveRegistry_getCurveMaxShares["getCurveMaxShares"]
    IBondingCurveRegistry_previewRedeem["previewRedeem"]
  end
  subgraph ITrustBonding["ITrustBonding"]
    ITrustBonding_currentEpoch["currentEpoch"]
  end
  subgraph MultiVault["MultiVault"]
    MultiVault_redeem["redeem"]
  end
  subgraph MultiVaultLib["MultiVaultLib"]
    MultiVaultLib__accumulateVaultProtocolFees["_accumulateVaultProtocolFees"]
    MultiVaultLib__burn["_burn"]
    MultiVaultLib__calculateRedeem["_calculateRedeem"]
    MultiVaultLib__convertToAssets["_convertToAssets"]
    MultiVaultLib__feeOnRaw["_feeOnRaw"]
    MultiVaultLib__getVaultType["_getVaultType"]
    MultiVaultLib__increaseProRataVaultAssets["_increaseProRataVaultAssets"]
    MultiVaultLib__isApprovedToRedeem["_isApprovedToRedeem"]
    MultiVaultLib__isAtom["_isAtom"]
    MultiVaultLib__isCounterTriple["_isCounterTriple"]
    MultiVaultLib__processRedeem["_processRedeem"]
    MultiVaultLib__recordCurveRedeem["_recordCurveRedeem"]
    MultiVaultLib__redeemFeeHookCurve["_redeemFeeHookCurve"]
    MultiVaultLib__removeUtilization["_removeUtilization"]
    MultiVaultLib__rollover["_rollover"]
    MultiVaultLib__s["_s"]
    MultiVaultLib__setVaultTotals["_setVaultTotals"]
    MultiVaultLib__shouldChargeExitFees["_shouldChargeExitFees"]
    MultiVaultLib__updateVaultOnRedeem["_updateVaultOnRedeem"]
    MultiVaultLib__validateRedeem["_validateRedeem"]
    MultiVaultLib_currentEpoch["currentEpoch"]
    MultiVaultLib_redeem["redeem"]
  end
  MultiVault_redeem -.-> MultiVaultLib_redeem
  MultiVaultLib_redeem --> MultiVaultLib__isApprovedToRedeem
  MultiVaultLib_redeem --> MultiVaultLib__processRedeem
  MultiVaultLib_redeem --> MultiVaultLib__removeUtilization
  MultiVaultLib__isApprovedToRedeem --> MultiVaultLib__s
  MultiVaultLib__processRedeem --> MultiVaultLib__accumulateVaultProtocolFees
  MultiVaultLib__processRedeem --> MultiVaultLib__calculateRedeem
  MultiVaultLib__processRedeem --> MultiVaultLib__convertToAssets
  MultiVaultLib__processRedeem --> MultiVaultLib__feeOnRaw
  MultiVaultLib__processRedeem --> MultiVaultLib__getVaultType
  MultiVaultLib__processRedeem --> MultiVaultLib__increaseProRataVaultAssets
  MultiVaultLib__processRedeem --> MultiVaultLib__recordCurveRedeem
  MultiVaultLib__processRedeem --> MultiVaultLib__s
  MultiVaultLib__processRedeem --> MultiVaultLib__shouldChargeExitFees
  MultiVaultLib__processRedeem --> MultiVaultLib__updateVaultOnRedeem
  MultiVaultLib__processRedeem --> MultiVaultLib__validateRedeem
  MultiVaultLib__removeUtilization --> MultiVaultLib__rollover
  MultiVaultLib__removeUtilization --> MultiVaultLib__s
  MultiVaultLib__removeUtilization --> MultiVaultLib_currentEpoch
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib__feeOnRaw
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib__s
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib_currentEpoch
  MultiVaultLib__calculateRedeem -.-> IBaseCurve_quoteRedeemFee
  MultiVaultLib__calculateRedeem --> MultiVaultLib__convertToAssets
  MultiVaultLib__calculateRedeem --> MultiVaultLib__feeOnRaw
  MultiVaultLib__calculateRedeem --> MultiVaultLib__redeemFeeHookCurve
  MultiVaultLib__calculateRedeem --> MultiVaultLib__s
  MultiVaultLib__calculateRedeem --> MultiVaultLib__shouldChargeExitFees
  MultiVaultLib__convertToAssets -.-> IBondingCurveRegistry_previewRedeem
  MultiVaultLib__convertToAssets --> MultiVaultLib__s
  MultiVaultLib__feeOnRaw --> MultiVaultLib__s
  MultiVaultLib__getVaultType --> MultiVaultLib__isAtom
  MultiVaultLib__getVaultType --> MultiVaultLib__isCounterTriple
  MultiVaultLib__getVaultType --> MultiVaultLib__s
  MultiVaultLib__increaseProRataVaultAssets --> MultiVaultLib__s
  MultiVaultLib__increaseProRataVaultAssets --> MultiVaultLib__setVaultTotals
  MultiVaultLib__recordCurveRedeem -.-> IBaseCurve_recordRedeem
  MultiVaultLib__shouldChargeExitFees --> MultiVaultLib__s
  MultiVaultLib__updateVaultOnRedeem --> MultiVaultLib__burn
  MultiVaultLib__updateVaultOnRedeem --> MultiVaultLib__s
  MultiVaultLib__updateVaultOnRedeem --> MultiVaultLib__setVaultTotals
  MultiVaultLib__validateRedeem --> MultiVaultLib__calculateRedeem
  MultiVaultLib__validateRedeem --> MultiVaultLib__s
  MultiVaultLib__rollover --> MultiVaultLib__s
  MultiVaultLib__rollover --> MultiVaultLib_currentEpoch
  MultiVaultLib_currentEpoch -.-> ITrustBonding_currentEpoch
  MultiVaultLib_currentEpoch --> MultiVaultLib__s
  MultiVaultLib__redeemFeeHookCurve -.-> IBaseCurve_hasRedeemFeeHook
  MultiVaultLib__redeemFeeHookCurve -.-> IBondingCurveRegistry_curveAddresses
  MultiVaultLib__redeemFeeHookCurve --> MultiVaultLib__s
  MultiVaultLib__isAtom --> MultiVaultLib__s
  MultiVaultLib__isCounterTriple --> MultiVaultLib__s
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_currentPrice
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_getCurveMaxAssets
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_getCurveMaxShares
  MultiVaultLib__setVaultTotals --> MultiVaultLib__s
  MultiVaultLib__burn --> MultiVaultLib__s
  style MultiVault_redeem stroke-width:3px
```

## Trace

```text
MultiVault.redeem
  MultiVaultLib.redeem
    MultiVaultLib._isApprovedToRedeem
      MultiVaultLib._s
    MultiVaultLib._processRedeem
      MultiVaultLib._accumulateVaultProtocolFees
        MultiVaultLib._feeOnRaw
          MultiVaultLib._s
        MultiVaultLib._s
        MultiVaultLib.currentEpoch
          ITrustBonding.currentEpoch
          MultiVaultLib._s
      MultiVaultLib._calculateRedeem
        IBaseCurve.quoteRedeemFee
        MultiVaultLib._convertToAssets
          IBondingCurveRegistry.previewRedeem
          MultiVaultLib._s
        MultiVaultLib._feeOnRaw  (expanded above)
        MultiVaultLib._redeemFeeHookCurve
          IBaseCurve.hasRedeemFeeHook
          IBondingCurveRegistry.curveAddresses
          MultiVaultLib._s
        MultiVaultLib._s
        MultiVaultLib._shouldChargeExitFees
          MultiVaultLib._s
      MultiVaultLib._convertToAssets  (expanded above)
      MultiVaultLib._feeOnRaw  (expanded above)
      MultiVaultLib._getVaultType
        MultiVaultLib._isAtom
          MultiVaultLib._s
        MultiVaultLib._isCounterTriple
          MultiVaultLib._s
        MultiVaultLib._s
      MultiVaultLib._increaseProRataVaultAssets
        MultiVaultLib._s
        MultiVaultLib._setVaultTotals
          IBondingCurveRegistry.currentPrice
          IBondingCurveRegistry.getCurveMaxAssets
          IBondingCurveRegistry.getCurveMaxShares
          MultiVaultLib._s
      MultiVaultLib._recordCurveRedeem
        IBaseCurve.recordRedeem
      MultiVaultLib._s
      MultiVaultLib._shouldChargeExitFees  (expanded above)
      MultiVaultLib._updateVaultOnRedeem
        MultiVaultLib._burn
          MultiVaultLib._s
        MultiVaultLib._s
        MultiVaultLib._setVaultTotals  (expanded above)
      MultiVaultLib._validateRedeem
        MultiVaultLib._calculateRedeem  (expanded above)
        MultiVaultLib._s
    MultiVaultLib._removeUtilization
      MultiVaultLib._rollover
        MultiVaultLib._s
        MultiVaultLib.currentEpoch  (expanded above)
      MultiVaultLib._s
      MultiVaultLib.currentEpoch  (expanded above)
```
