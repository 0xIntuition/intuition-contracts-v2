/** Public artifact surface. Missing build output must fail the release. */
export const contracts = [
  "MultiVault",
  "MultiVaultMigrationMode",
  "FeeProxy",
  "BaseEmissionsController",
  "SatelliteEmissionsController",
  "TrustBonding",
  "BondingCurveRegistry",
  "LinearCurve",
  "OffsetProgressiveCurve",
  "DynamicFeeFlatPriceCurve",
  "AtomWallet",
  "AtomWalletFactory",
  "AtomWarden",
  "Trust",
  "TrustToken",
  "WrappedTrust",
  "MultiVaultLib",
  "TimelockController",
] as const;
export const abiOnly = ["IBaseCurve"] as const;
