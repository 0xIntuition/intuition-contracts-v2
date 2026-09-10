<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->

# Contract-level call graph

One node per first-party contract, one edge per cross-contract call. Vendored dependencies, tests, deploy scripts, `src/legacy` and `src/external` are excluded.

```mermaid
flowchart LR
  AtomWallet["AtomWallet"]
  AtomWalletFactory["AtomWalletFactory"]
  AtomWarden["AtomWarden"]
  BondingCurveRegistry["BondingCurveRegistry"]
  CoinbaseSmartWalletLib["CoinbaseSmartWalletLib"]
  FeeProxy["FeeProxy"]
  IAtomWallet["IAtomWallet"]
  IAtomWalletFactory["IAtomWalletFactory"]
  IBaseCurve["IBaseCurve"]
  IBondingCurveRegistry["IBondingCurveRegistry"]
  ICoreEmissionsController["ICoreEmissionsController"]
  IIGP["IIGP"]
  IMetaERC20HubOrSpoke["IMetaERC20HubOrSpoke"]
  IMetalayerRouter["IMetalayerRouter"]
  IMultiVault["IMultiVault"]
  IMultiVaultCore["IMultiVaultCore"]
  ISatelliteEmissionsController["ISatelliteEmissionsController"]
  ITrustBonding["ITrustBonding"]
  MetaERC20Dispatcher["MetaERC20Dispatcher"]
  MultiVault["MultiVault"]
  MultiVaultLib["MultiVaultLib"]
  OffsetProgressiveCurve["OffsetProgressiveCurve"]
  ProgressiveCurve["ProgressiveCurve"]
  ProgressiveCurveMathLib["ProgressiveCurveMathLib"]
  SatelliteEmissionsController["SatelliteEmissionsController"]
  TrustBonding["TrustBonding"]
  AtomWallet --> CoinbaseSmartWalletLib
  AtomWallet --> IMultiVault
  AtomWalletFactory --> IMultiVault
  AtomWalletFactory --> IMultiVaultCore
  AtomWarden --> IAtomWallet
  AtomWarden --> IMultiVault
  AtomWarden --> IMultiVaultCore
  BondingCurveRegistry --> IBaseCurve
  FeeProxy --> IMultiVault
  MetaERC20Dispatcher --> IIGP
  MetaERC20Dispatcher --> IMetaERC20HubOrSpoke
  MetaERC20Dispatcher --> IMetalayerRouter
  MultiVault --> IAtomWallet
  MultiVault --> MultiVaultLib
  MultiVaultLib --> IAtomWalletFactory
  MultiVaultLib --> IBaseCurve
  MultiVaultLib --> IBondingCurveRegistry
  MultiVaultLib --> ITrustBonding
  OffsetProgressiveCurve --> ProgressiveCurveMathLib
  ProgressiveCurve --> ProgressiveCurveMathLib
  SatelliteEmissionsController --> ITrustBonding
  TrustBonding --> ICoreEmissionsController
  TrustBonding --> IMultiVault
  TrustBonding --> ISatelliteEmissionsController
```

Contracts with no first-party cross-contract calls: `BaseCurve`, `BaseEmissionsController`, `CoreEmissionsController`, `DynamicFeeFlatPriceCurve`, `IAtomWarden`, `IBaseEmissionsController`, `IDynamicFeeFlatPriceCurve`, `IFeeProxy`, `LinearCurve`, `MultiVaultCore`, `MultiVaultMigrationMode`.
