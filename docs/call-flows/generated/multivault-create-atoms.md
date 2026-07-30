<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# MultiVault.createAtoms

Term creation, which seeds the default-curve vault before any deposit can route to it.

Reached functions: 29. Solid arrows are calls inside one contract; dashed arrows leave it (either a `delegatecall` into the linked library, which still executes in the caller's storage context, or a genuine external call).

## Graph

```mermaid
flowchart LR
  subgraph IAtomWalletFactory["IAtomWalletFactory"]
    IAtomWalletFactory_computeAtomWalletAddr["computeAtomWalletAddr"]
  end
  subgraph IBondingCurveRegistry["IBondingCurveRegistry"]
    IBondingCurveRegistry_currentPrice["currentPrice"]
    IBondingCurveRegistry_getCurveMaxAssets["getCurveMaxAssets"]
    IBondingCurveRegistry_getCurveMaxShares["getCurveMaxShares"]
    IBondingCurveRegistry_previewDeposit["previewDeposit"]
    IBondingCurveRegistry_previewMint["previewMint"]
  end
  subgraph ITrustBonding["ITrustBonding"]
    ITrustBonding_currentEpoch["currentEpoch"]
  end
  subgraph MultiVault["MultiVault"]
    MultiVault__effectiveMsgValue["_effectiveMsgValue"]
    MultiVault_createAtoms["createAtoms"]
  end
  subgraph MultiVaultLib["MultiVaultLib"]
    MultiVaultLib__accumulateAtomWalletFees["_accumulateAtomWalletFees"]
    MultiVaultLib__accumulateStaticProtocolFees["_accumulateStaticProtocolFees"]
    MultiVaultLib__accumulateVaultProtocolFees["_accumulateVaultProtocolFees"]
    MultiVaultLib__addUtilization["_addUtilization"]
    MultiVaultLib__calculateAtomCreate["_calculateAtomCreate"]
    MultiVaultLib__calculateAtomId["_calculateAtomId"]
    MultiVaultLib__convertToShares["_convertToShares"]
    MultiVaultLib__createAtom["_createAtom"]
    MultiVaultLib__createAtoms["_createAtoms"]
    MultiVaultLib__feeOnRaw["_feeOnRaw"]
    MultiVaultLib__getAtomCost["_getAtomCost"]
    MultiVaultLib__minAssetsForCurve["_minAssetsForCurve"]
    MultiVaultLib__mint["_mint"]
    MultiVaultLib__rollover["_rollover"]
    MultiVaultLib__s["_s"]
    MultiVaultLib__setVaultTotals["_setVaultTotals"]
    MultiVaultLib__updateVaultOnCreation["_updateVaultOnCreation"]
    MultiVaultLib__validatePayment["_validatePayment"]
    MultiVaultLib_createAtoms["createAtoms"]
    MultiVaultLib_currentEpoch["currentEpoch"]
  end
  MultiVault_createAtoms --> MultiVault__effectiveMsgValue
  MultiVault_createAtoms -.-> MultiVaultLib_createAtoms
  MultiVaultLib_createAtoms --> MultiVaultLib__createAtoms
  MultiVaultLib_createAtoms --> MultiVaultLib__validatePayment
  MultiVaultLib__createAtoms --> MultiVaultLib__accumulateStaticProtocolFees
  MultiVaultLib__createAtoms --> MultiVaultLib__addUtilization
  MultiVaultLib__createAtoms --> MultiVaultLib__createAtom
  MultiVaultLib__createAtoms --> MultiVaultLib__s
  MultiVaultLib__accumulateStaticProtocolFees --> MultiVaultLib__s
  MultiVaultLib__accumulateStaticProtocolFees --> MultiVaultLib_currentEpoch
  MultiVaultLib__addUtilization --> MultiVaultLib__rollover
  MultiVaultLib__addUtilization --> MultiVaultLib__s
  MultiVaultLib__addUtilization --> MultiVaultLib_currentEpoch
  MultiVaultLib__createAtom --> MultiVaultLib__accumulateAtomWalletFees
  MultiVaultLib__createAtom --> MultiVaultLib__accumulateVaultProtocolFees
  MultiVaultLib__createAtom --> MultiVaultLib__calculateAtomCreate
  MultiVaultLib__createAtom --> MultiVaultLib__calculateAtomId
  MultiVaultLib__createAtom --> MultiVaultLib__s
  MultiVaultLib__createAtom --> MultiVaultLib__updateVaultOnCreation
  MultiVaultLib_currentEpoch -.-> ITrustBonding_currentEpoch
  MultiVaultLib_currentEpoch --> MultiVaultLib__s
  MultiVaultLib__rollover --> MultiVaultLib__s
  MultiVaultLib__rollover --> MultiVaultLib_currentEpoch
  MultiVaultLib__accumulateAtomWalletFees -.-> IAtomWalletFactory_computeAtomWalletAddr
  MultiVaultLib__accumulateAtomWalletFees --> MultiVaultLib__feeOnRaw
  MultiVaultLib__accumulateAtomWalletFees --> MultiVaultLib__s
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib__feeOnRaw
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib__s
  MultiVaultLib__accumulateVaultProtocolFees --> MultiVaultLib_currentEpoch
  MultiVaultLib__calculateAtomCreate --> MultiVaultLib__convertToShares
  MultiVaultLib__calculateAtomCreate --> MultiVaultLib__feeOnRaw
  MultiVaultLib__calculateAtomCreate --> MultiVaultLib__getAtomCost
  MultiVaultLib__calculateAtomCreate --> MultiVaultLib__s
  MultiVaultLib__updateVaultOnCreation --> MultiVaultLib__minAssetsForCurve
  MultiVaultLib__updateVaultOnCreation --> MultiVaultLib__mint
  MultiVaultLib__updateVaultOnCreation --> MultiVaultLib__s
  MultiVaultLib__updateVaultOnCreation --> MultiVaultLib__setVaultTotals
  MultiVaultLib__feeOnRaw --> MultiVaultLib__s
  MultiVaultLib__convertToShares -.-> IBondingCurveRegistry_previewDeposit
  MultiVaultLib__convertToShares --> MultiVaultLib__s
  MultiVaultLib__getAtomCost --> MultiVaultLib__s
  MultiVaultLib__minAssetsForCurve -.-> IBondingCurveRegistry_previewMint
  MultiVaultLib__minAssetsForCurve --> MultiVaultLib__s
  MultiVaultLib__mint --> MultiVaultLib__s
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_currentPrice
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_getCurveMaxAssets
  MultiVaultLib__setVaultTotals -.-> IBondingCurveRegistry_getCurveMaxShares
  MultiVaultLib__setVaultTotals --> MultiVaultLib__s
  style MultiVault_createAtoms stroke-width:3px
```

## Trace

```text
MultiVault.createAtoms
  MultiVault._effectiveMsgValue
  MultiVaultLib.createAtoms
    MultiVaultLib._createAtoms
      MultiVaultLib._accumulateStaticProtocolFees
        MultiVaultLib._s
        MultiVaultLib.currentEpoch
          ITrustBonding.currentEpoch
          MultiVaultLib._s
      MultiVaultLib._addUtilization
        MultiVaultLib._rollover
          MultiVaultLib._s
          MultiVaultLib.currentEpoch  (expanded above)
        MultiVaultLib._s
        MultiVaultLib.currentEpoch  (expanded above)
      MultiVaultLib._createAtom
        MultiVaultLib._accumulateAtomWalletFees
          IAtomWalletFactory.computeAtomWalletAddr
          MultiVaultLib._feeOnRaw
            MultiVaultLib._s
          MultiVaultLib._s
        MultiVaultLib._accumulateVaultProtocolFees
          MultiVaultLib._feeOnRaw  (expanded above)
          MultiVaultLib._s
          MultiVaultLib.currentEpoch  (expanded above)
        MultiVaultLib._calculateAtomCreate
          MultiVaultLib._convertToShares
            IBondingCurveRegistry.previewDeposit
            MultiVaultLib._s
          MultiVaultLib._feeOnRaw  (expanded above)
          MultiVaultLib._getAtomCost
            MultiVaultLib._s
          MultiVaultLib._s
        MultiVaultLib._calculateAtomId
        MultiVaultLib._s
        MultiVaultLib._updateVaultOnCreation
          MultiVaultLib._minAssetsForCurve
            IBondingCurveRegistry.previewMint
            MultiVaultLib._s
          MultiVaultLib._mint
            MultiVaultLib._s
          MultiVaultLib._s
          MultiVaultLib._setVaultTotals
            IBondingCurveRegistry.currentPrice
            IBondingCurveRegistry.getCurveMaxAssets
            IBondingCurveRegistry.getCurveMaxShares
            MultiVaultLib._s
      MultiVaultLib._s
    MultiVaultLib._validatePayment
```
