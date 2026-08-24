# v1.1.0 identifier alignment — proposed renames

**Branch:** `feat/v1.1.0-core-upgrade` · **Date:** 2026-08-23 · **Status:** proposal, nothing changed yet

Scope: every function parameter, return name, local, struct field and event param in the code that is core to this upgrade — `IBaseCurve` + all curve implementations, `DynamicFeeFlatPriceCurve` / `IDynamicFeeFlatPriceCurve`, `MultiVault` / `MultiVaultLib` / `IMultiVault` / `IMultiVaultCore` / `MultiVaultCore`, and `FeeProxy` / `IFeeProxy`. Line numbers are against the current branch head (`330980a` + uncommitted `.planning/`). Nothing here is a behaviour change; every item is a rename or a natspec correction.

---

## 0. Summary and the decisions you need to make

### 0.1 The headline question: `shares` on `recordDeposit` / `recordRedeem`

**The interface is right; the curve is wrong.** `MultiVaultLib` hands the record hooks the *minted* / *burned* share count (`sharesForReceiver` at `:926`, `shares` at `:935`) — never the deposit amount. The deposit amount goes to the *quote* hooks, and the fee comes back in as `msg.value`. `IBaseCurve.recordDeposit(…, uint256 shares)` and the mock are therefore correct, and `DynamicFeeFlatPriceCurve.recordDeposit(…, uint256 netStake)` / `recordRedeem(…, uint256 withdrawnStake)` are the misnomers — they name the value in the curve's private ledger unit ("stake", TRUST wei) and only agree with what is passed because this curve pins price at 1:1. Full trace in §1.0.

Proposal: keep `shares` on the interface, rename the curve's hook params to `shares`, state the 1:1 equivalence once at the hook entry, and drop the meaningless `net` qualifier from the internal helpers (§1.1–1.2).

### 0.2 Decisions (each changes a block of items below)

| # | Decision | Options | My recommendation | Affects |
|---|---|---|---|---|
| D1 | Quote-hook param names | (a) promote the curve's `baseAssets` / `grossAssets` up into `IBaseCurve`; (b) `assets` everywhere | **(a)** — more informative, and `grossAssets` is already the protocol-wide name for that quantity in FeeProxy/IMultiVault | H3, H4 |
| D2 | Inside the curve, after the hook param is `shares` | (A) keep the `stake` ledger vocabulary, drop `net`; (B) rename the ledger to `shares` throughout | **(A)** — "stake" is a real domain word for a booked position; (B) churns ~70 test refs and the spec docs for no gain | C1–C5 |
| D3 | Curve fee vocabulary: `withdrawal*` vs `redeem*` | (a) rename to `redeem*` so the curve's fee pair is `deposit`/`redeem`, matching the hook names and MultiVault's operation; (b) keep `withdrawal` as a deliberate product term and say so in the header | **(a)** — it is the single largest change here (~230 occurrences, all mechanical) but it removes a third word for the redeem side, and ERC-4626 "withdraw" means the *asset-denominated* exit, which is precisely what `recordRedeem` is not | §1.7 |
| D4 | `DynamicFeeConfig` struct fields (`growthGBps`, `fulcrumAlpha`) | rename now (ABI of a calldata struct; frozen after deploy) or never | **rename now** — `growthGBps` reads as a typo; `fulcrumAlpha` is the only bps field without the suffix | G1, G2 |
| D5 | Event param names that indexers read (`Deposited.totalShares`, `Redeemed.totalShares`, `Redeemed.assets/fees`, `DepositRecorded.netStake`, FeeProxy `totalFee`) | rename (ABI-JSON only, topic hash unchanged) or keep + doc | **rename**, coordinated with the indexer team — `totalShares` for a per-user balance is the single most misleading name in the set | M5, M7, M19, C3, C4, P2 |
| D6 | LEGACY MultiVault items (§2, tagged LEGACY) | fix in this pass, or leave for a separate PR so the upgrade diff stays reviewable | **fix the WRONG-severity ones now** (M3/M4 receiver, M8 `feeBps`, M23 `maxRedeem(sender)`, M25 utilization, M5 `totalShares`, doc fixes); defer STYLE | §2 |
| D7 | `bankedEarnings()` + public `earned` mapping duplicate getters | make `earned` internal and rename to `settledEarnings`, or leave | **do it** — one public read, one name, matches the natspec vocabulary | L6 |

### 0.3 Conventions the proposals follow

These are the rules the rest of the document applies. If you disagree with a rule, the items under it fall out together.

1. **Unit in the name.** A quantity is `…Assets` / `…Shares` / `…Bps` / `…Fee` (amount) / `…FeeBps` or `…FeeRate` (rate). Bare `amount` / `value` / `fee` are only acceptable where the surrounding surface is uniformly bare and documented (FeeProxy refund surface).
2. **"value" means `msg.value`.** Errors and params named `…Value` are about native value sent, not asset amounts (`FeeProxy_ZeroValue` violates this).
3. **Fee base is named once.** Whatever the rate-fees are computed on is called the same thing on the create and deposit paths.
4. **Role names are fixed:** `account` = the address whose position is read/written; `receiver` = the address that receives shares or assets; `sender` = `msg.sender`/operator; `creator` = on-behalf-of principal on create paths; `user` = utilization-ledger subject (MultiVault) or proxy `msg.sender` (FeeProxy); `feeRecipient` / `recipient` (refund) in FeeProxy.
5. **Tier roles are named:** `sourceTier`, `exitTier`, `bandTier`, `recipientTier`, `fromTier`, `topTier`, `currentTier`; a bare `tier` is only a loop cursor.
6. **"share" is a unit, never a portion.** A portion of a fee pool is a `slice`.
7. **Interface, implementation and mock agree** on every parameter name of the same selector.

### 0.4 Severity key

- **WRONG** — the name states a different quantity or role than the one held (or the natspec does).
- **INCONSISTENT** — one concept, several names across interface/impl/siblings/paths.
- **AMBIGUOUS** — bare `amount`/`value`/`tier`/`data` with no unit or role.
- **STYLE** — convention only.

Tags in §2: **NEW** = introduced on this branch; **LEGACY** = identical on `main`.

---
## 1. The hook surface — `IBaseCurve` ↔ `DynamicFeeFlatPriceCurve` ↔ `MultiVaultLib`

### 1.0 Premise check (read this first)

The question was: *"we call the inputs `shares`, but they can't be shares, because a deposit is usually the amount."*

Traced, the value MultiVault actually passes **is** shares:

| Call site | What is passed | Where it comes from |
|---|---|---|
| `src/libraries/MultiVaultLib.sol:926` `recordDeposit{value: hook.fee}(termId, receiver, sharesForReceiver)` | **minted shares** | `_calculateDeposit` → `_depositShares(...)` → `previewDeposit(assetsAfterFees, …)` |
| `src/libraries/MultiVaultLib.sol:935` `recordRedeem{value: hook.fee}(termId, receiver, shares)` | **burned shares** | the `shares` argument of `redeem(...)` |

The asset amount never reaches the record hooks — it reaches the **quote** hooks (`quoteDepositFee(termId, assetsAfterMinSharesCost)` at `:1032`/`:1094`, `quoteRedeemFee(termId, account, assets)` at `:1135`), and the quoted *fee* (in assets) comes back in as `msg.value`.

So the interface name `shares` is literally correct, and `tests/mocks/MockFeeHookCurve.sol:58,66` already uses `shares`. The misnomer is on the **curve side**: `DynamicFeeFlatPriceCurve.recordDeposit(..., uint256 netStake)` and `recordRedeem(..., uint256 withdrawnStake)` name the value in the curve's private ledger vocabulary ("stake", denominated in TRUST wei) and only agree with what is passed because the curve pins price at 1:1. The curve's own natspec admits this (`DynamicFeeFlatPriceCurve.sol:161-168`: *"This accumulates share amounts (the record hooks are handed `sharesForReceiver` / `shares`), while the tier ladder … is denominated in assets"*).

**Recommendation:** keep `shares` on `IBaseCurve`; rename the curve's hook parameters to `shares` and state the 1:1 equivalence once at the hook entry. Do **not** rename the interface to an asset-flavoured name — that would make the interface wrong for every future non-flat curve.

### 1.1 Hook parameter matrix (current state)

| Function | `IBaseCurve` (`src/interfaces/IBaseCurve.sol`) | `DynamicFeeFlatPriceCurve` | `MockFeeHookCurve` | Value actually passed by `MultiVaultLib` |
|---|---|---|---|---|
| `quoteDepositFee(termId, ·)` | `assets` (:137) | `baseAssets` (:410) | `assets` (:50) | `assetsAfterMinSharesCost` (:1032, :1094) — deposit base after min-share seed, before MV fees and before curve fee |
| `quoteRedeemFee(termId, account, ·)` | `assets` (:146) | `grossAssets` (:417) | `assets` (:54) | `assets = _convertToAssets(shares)` (:1126, :1135) — gross, pre-all-fees |
| `recordDeposit(termId, account, ·)` | `shares` (:164) | `netStake` (:448) | `shares` (:58) | `sharesForReceiver` (:926) — minted shares |
| `recordRedeem(termId, account, ·)` | `shares` (:174) | `withdrawnStake` (:482) | `shares` (:66) | `shares` (:935) — burned shares |

Three names for each slot. Proposed alignment:

| # | Slot | Proposed name (all three files) | Rationale |
|---|---|---|---|
| **H1** | `recordDeposit` 3rd param | `shares` | It is the minted share count. Interface + mock already say so. Curve: `DynamicFeeFlatPriceCurve.sol:448`, event `:227`, usages `:460, :466, :467, :471`. |
| **H2** | `recordRedeem` 3rd param | `shares` | It is the burned share count. Curve: `:482`, usages `:497, :498, :507, :509, :556, :558`, event `:242`. |
| **H3** | `quoteDepositFee` 2nd param | `baseAssets` *(promote the curve's name up into the interface)* — alt: `assets` everywhere | The interface natspec (`:134`) already calls it "the deposit base the fee is quoted on"; `baseAssets` says that in the signature. Change `IBaseCurve.sol:137`, `MockFeeHookCurve.sol:50`. |
| **H4** | `quoteRedeemFee` 3rd param | `grossAssets` *(promote up)* — alt: `assets` everywhere | Interface natspec (`:144`) says "the gross asset value of the redeemed shares"; `grossAssets` is the name FeeProxy/IMultiVault already use for this quantity (`IMultiVault.sol:461`). Change `IBaseCurve.sol:146`, `MockFeeHookCurve.sol:54`. |

`BaseCurve.sol:163-178` declares the hook stubs with unnamed params — no change needed there.

### 1.2 Inside the curve: carrying H1/H2 through the call chain

Once the hook param is `shares`, the question is what to call it inside the curve, whose ledger is named `stake` (`vaultStake`, `tierStake`, `userStake`, `bandStake`). Two options:

- **Option A (recommended):** hook param is `shares`; the first line of each hook hands it to the ledger under the ledger's own name with a one-line comment (`// Flat 1:1 pricing: one share is one wei of stake, so shares are booked as stake directly.`). Internal helpers keep the `stake` vocabulary, but drop the `net` qualifier — inside the curve there is only one quantity, so "net" (net of what?) is noise. Ledger state-variable names (public getters, referenced ~70× in tests) stay.
- **Option B:** rename the whole internal vocabulary from `stake` to `shares` (`vaultStake → vaultShares`, etc.). Strictly more "correct" but churns ~70 test references, the spec docs (`docs/call-flows/dynamic-fee-curve.md`), and the `accFeePerShare`/`tierStake` pairing; and "stake" is a legitimate domain word for a booked position. Not recommended now.

Under Option A the internal changes are:

| # | Location | Current | Proposed | Note |
|---|---|---|---|---|
| C1 | `DynamicFeeFlatPriceCurve.sol:771` `_walkDepositBands(startAssets, netStake, tier, topTier)` | `netStake` | `stake` | usages `:783` |
| C2 | `:826` `_replayDepositBands(termId, account, startAssets, netStake, feeAmount)` | `netStake` | `stake` | usages `:839, :840, :845` |
| C3 | `:227` `event DepositRecorded(... uint256 netStake ...)` | `netStake` | `shares` | ABI param name; aligns with `IMultiVault.Deposited(... shares ...)`. Emitted `:471`. |
| C4 | `:242` `event RedeemRecorded(... uint256 withdrawnStake ...)` | `withdrawnStake` | `shares` | aligns with `IMultiVault.Redeemed(... shares ...)`. Emitted `:558`. |
| C5 | `:238` `event DepositBandRecorded(..., uint256 bandStake, uint256 bandFee)` | `bandStake` | keep `bandStake` (or `bandShares` if C3/C4 adopt `shares`) | Your call — band-level is an internal-ledger concept, so `bandStake` is defensible. Flagging for a conscious decision so the event set is consistent. |

### 1.3 `tier` parameters that mean different tiers

`tier` is used for at least four distinct roles in the curve. The named ones (`sourceTier`, `exitTier`, `bandTier`, `recipientTier`, `topTier`, `fromTier`) are good; these are the bare `tier`s that should adopt the matching role name:

| # | Location | Current | Holds | Proposed |
|---|---|---|---|---|
| T1 | `:940` `_payDepositFee(termId, feeAmount, tier)` | `tier` | the band the fee is sourced at (only recipients are `< tier`) | `sourceTier` |
| T2 | `:1008` `_payFulcrumTiers(termId, fulcrumFeePool, tier, excludeTier, excludeStake)` | `tier` | same — source tier; `span = tier` | `sourceTier` |
| T3 | `:1231` `_nearestEligiblePriorTier(termId, tier)` | `tier` | the tier to search *downward from* | `fromTier` — sibling `_nearestEligibleTier(termId, fromTier)` at `:1213` already uses this |
| T4 | `:491` `recordRedeem` local `uint256 tier = _tierOf(vaultStake[termId])` | `tier` | the vault's current tier (natspec: "matches the spec's `currentTier`") — distinct from `exitTier` on the next line | `currentTier` |
| T5 | `:423`, `:703` `quoteRedeemFee` / `previewRedeemFor` local `tier` | `tier` | the tier whose *rate* applies (user's bucket, else vault's current) | `rateTier` (optional) |
| T6 | `:771` `_walkDepositBands(..., uint256 tier, ...)` | `tier` | starts as source tier, mutated as the band cursor | `sourceTier` param + local `bandTier` cursor (mirrors `_replayDepositBands:831`), or leave as-is since it is mutated |
| T7 | `:714`, `:719`, `:1167`, `:1174` `tierUpperEdge(uint256 k)`, `tierWidthAt(uint256 k)`, `_tierWidthAt(k)`, `_tierUpperEdge(k)` | `k` | a tier index | `tier` — `k` is the spec's loop symbol; every other public view uses `tier` (`depositFeeBps(uint256 tier)`, `withdrawalFeeBps(uint256 tier)`). Public param names are in the ABI. |

### 1.4 "share" used to mean "portion of a fee"

In a protocol where `shares` is a unit, using *share* for "a slice of the fee pool" is a real collision. The code already uses **slice** for this in most places (`toExitingTier` "exiting-tier slice", "fulcrum slice"); these are the stragglers:

| # | Location | Current | Proposed |
|---|---|---|---|
| S1 | `:1059` `_creditByWeight` local `uint256 share = fulcrumFeePool.mulDiv(w, sumWeights)` | `share` | `slice` |
| S2 | natspec `:202-203` (`protocolAccrued`: "absorbs any single share that floors to zero"), `:802-806` (`_replayDepositBands`: "each band's share of `feeAmount`", "computed share"), `:993` (`_payFulcrumTiers`: "its share is absorbed"), `:431-433` (`recordDeposit`: "apportioned share of the single quoted fee") | "share" | "slice" / "portion" |

### 1.5 Other curve-local names

| # | Location | Current | Holds | Proposed | Sev |
|---|---|---|---|---|---|
| L1 | `:510` `recordRedeem` local `denom` | `denom` | the *other* holders' stake in the exiting tier (the recipient set) | `cohortStake` | AMBIGUOUS |
| L2 | `:499` `recordRedeem` local `residual` | `residual` | the exiter's remaining stake after the burn | `exiterResidual` (optional — "residual" is used consistently in the natspec, so this is low priority) | STYLE |
| L3 | `:1084-1086` `_weighPriorTiers` local `targetTier` | `targetTier` | the candidate recipient tier | `recipientTier` — matches `recipientStake` on the next line and the name used in `_payDepositFee`/`_nearestEligiblePriorTier` | INCONSISTENT |
| L4 | `:980` `_triangularWeight(dist, sigma)`, `:1082` local `sigma = config.kernelSpread` | `sigma` | the config's `kernelSpread` | `spread` or `kernelSpread` — the Greek symbol is fine in the natspec math, but the config field is `kernelSpread`. Optional. | STYLE |
| L5 | `:174-186` mapping key names `address user` (`userStake`, `userTier`, `userAvgTier`, `rewardDebt`, `earned`) | `user` | the account | `account` — every function param and event uses `account`; the `DepositRecorded` natspec even has to translate ("`accountTier` … are the account's `userTier`"). Key names are cosmetic in the ABI (getter input names). Renaming the *mappings* themselves (`userStake → accountStake`) is a bigger ABI/test change (~70 refs) — list as optional. | STYLE |
| L6 | `:186` `mapping(address user => uint256 amount) public earned` vs `:663` `bankedEarnings(account)` returning `earned[account]` | `earned` / `bankedEarnings` / natspec "settled balance" | one concept, three words | Make the mapping `internal` and name it `settledEarnings`; keep `bankedEarnings()` as the single public read (the natspec already defines it as "the settled balance"). Removes a duplicate public getter from the ABI. | INCONSISTENT |
| L7 | `:361` `setTierFeeOverride(tier, newDepositFeeBps, newWithdrawalFeeBps)` | `new*` prefix | the override rates | `depositFeeBps` / `withdrawalFeeBps` — no shadowing to avoid (struct fields are not in scope); the `new` prefix is only used here. Optional. | STYLE |
| L8 | `:1175` `_tierUpperEdge` local `g` | `g` | `config.growthGBps` | fine as math-local; flagged only because of G1 below | — |

### 1.6 `DynamicFeeConfig` struct fields (`src/interfaces/IDynamicFeeFlatPriceCurve.sol`)

These are ABI names on a `calldata` struct: renaming touches `initialize`/`setConfig` callers in tests (~30 refs each) and `script/`. Worth deciding now, before audit, because the struct is frozen after deploy.

| # | Field | Current | Issue | Proposed |
|---|---|---|---|---|
| G1 | `:28` | `growthGBps` | The only bps field whose "what grows" is a single letter; siblings are `depositGrowthBps`, `withdrawalGrowthBps`. Reads as a typo. | `tierWidthGrowthBps` (or `widthGrowthBps`) |
| G2 | `:40` | `fulcrumAlpha` | Is in bps `[0, BPS]` (natspec + `_setConfig:1361`), but is the **only** bps-denominated field without the `Bps` suffix. | `fulcrumAlphaBps` |
| G3 | `:17` | `width0` | Fine as the spec symbol; optionally `tier0Width` for symmetry with `tierCount`. | keep (or `tier0Width`) |
| G4 | `:44` | `kernelSpread` | In `TIER_PRECISION` tier units — not bps — and correctly *un*-suffixed. Keep. | keep |

### 1.7 "withdrawal" vs "redeem" vs "exit" — a vocabulary decision

Three words are in play for the redeem side:

| Word | Where | Meaning |
|---|---|---|
| `redeem` | `IMultiVault.redeem`, `IBaseCurve.hasRedeemFeeHook / quoteRedeemFee / recordRedeem`, `previewRedeemFor` | the operation |
| `exitFee` | `MultiVault.vaultFees.exitFee` | MultiVault's own vault-level fee on redeem |
| `withdrawal` | the curve's **fee** vocabulary: `withdrawalBaseBps / withdrawalGrowthBps / withdrawalCapBps / withdrawalToFulcrumTiersBps` (struct), `TierFeeOverride.withdrawalFeeBps`, `MAX_WITHDRAWAL_CAP_BPS:110`, `withdrawalFeeBps():734`, `_withdrawalFeeBps():1313`, `WithdrawalFeeRerouted:247`, `setTierFeeOverride(..., newWithdrawalFeeBps)`, ~40 natspec mentions, `MultiVaultLib.sol:929,1129` comments | the curve-level fee on redeem |

On the deposit side the curve fee is just `depositFee` — the operation's name. So the curve's pair is `deposit`/`withdrawal`, while the hook pair it implements is `Deposit`/`Redeem`, and "withdraw" in ERC-4626 means the *asset-denominated* exit (`previewWithdraw`), which is precisely *not* what `recordRedeem` is.

**Recommendation:** rename the curve's fee vocabulary `withdrawal*` → `redeem*` (`redeemBaseBps`, `redeemGrowthBps`, `redeemCapBps`, `redeemToFulcrumTiersBps`, `TierFeeOverride.redeemFeeBps`, `MAX_REDEEM_CAP_BPS`, `redeemFeeBps()`, `_redeemFeeBps()`, `RedeemFeeRerouted`). This is the largest single change in the list (src: ~70, tests: ~130, script: 6, docs: 18 occurrences) and is mechanical. The alternative is to keep "withdrawal" as a deliberate product term for *the curve fee specifically* and say so once in the contract header; if you go that way, nothing else in this section changes.

### 1.8 Already consistent on the curve side (checked, no change)

- Pricing surface: `previewDeposit/previewRedeem/previewMint/previewWithdraw/convertToShares/convertToAssets/currentPrice` have identical param names (`assets, totalAssets, totalShares` / `shares, totalShares, totalAssets`) across `IBaseCurve`, `BaseCurve`, `LinearCurve`, `ProgressiveCurve`, `OffsetProgressiveCurve`, `BondingCurveRegistry` and `IBondingCurveRegistry`. One pre-existing oddity: `BondingCurveRegistry.currentPrice(id, totalShares, totalAssets)` takes `id` *first* while every other registry function takes it *last* — pre-upgrade, ABI-visible, not worth touching now.
- `feeAmount` (= `msg.value`, an amount) vs `*Bps` (rates) vs `fee` (quoted amount) are used correctly throughout the curve.
- `fulcrumFeePool`, `toFulcrum`, `toExitingTier`, `toPriorTier`, `undistributed`, `unassigned`, `assigned` are all amounts and named as such.
- `sourceTier`, `exitTier`, `bandTier`, `topTier`, `recipientTier`, `excludeTier`, `excludeStake`, `recipientStake`, `bestTier/bestStake/bestDist` are role-named and correct.
- `startAssets` (`:456, :771, :825, :1281`) is assigned from `vaultStake` — a stake value under an asset name — but it is used as a **coordinate on the asset-denominated tier ladder** (`_tierOf(uint256 assets)`, `_tierUpperEdge`), and the `vaultStake` natspec (`:161-168`) documents the coupling. Keep; it is the ladder's unit, not the ledger's.
- `rewardDebt`, `accFeePerShare` — MasterChef convention; documented; keep. (`accFeePerShare` says "share" where the denominator is `tierStake`, but at 1:1 it is the same and renaming to `accFeePerStake` buys nothing.)
- `initialize(_name, _owner, _multiVault, _config)` / `setConfig(_config)` underscore-prefix convention for shadowing state vars matches the other curves' `initialize(string calldata _name)`.

## 2. `MultiVault` / `MultiVaultLib` / `IMultiVault` / `IMultiVaultCore` / `MultiVaultCore`

Most of MultiVault's deposit/redeem code moved verbatim from `MultiVault.sol` into the new `MultiVaultLib.sol` in this branch, so most of what follows is **pre-existing** naming debt that the move exposed, not something the upgrade introduced. Each item is tagged **NEW** (introduced on this branch) or **LEGACY** (identical on `main`) so you can scope the pass. Items touching the curve hook plumbing are listed first because they are the ones that interact with §1.

### 2.1 Hook plumbing (the `account` / `receiver` / `shares` chain)

| # | Location | Current | Holds | Proposed | Tag |
|---|---|---|---|---|---|
| M1 | `MultiVaultLib.sol:922` `_recordCurveDeposit(termId, address receiver, CurveHook hook, uint256 sharesForReceiver)` | `receiver`, `sharesForReceiver` | the account minted to; the minted shares | `account`, `shares` — forwarded into `IBaseCurve.recordDeposit(termId, account, shares)` | NEW |
| M2 | `MultiVaultLib.sol:933` `_recordCurveRedeem(termId, address receiver, CurveHook hook, uint256 shares)` | `receiver` | the account whose shares were burned, forwarded as the hook's `account` | `account` | NEW |
| M3 | `MultiVaultLib.sol:851-858` `_processRedeem(address sender, address receiver, …)` | `receiver` | 4 of 5 uses are the **share-owner** role: `_validateRedeem(…, receiver, …)` checks `balanceOf[receiver]` (`:861`→`:1470`), `_calculateRedeem(…, receiver)` quotes the curve fee at that account's tier (`:865`), `_updateVaultOnRedeem(receiver, …)` burns from it (`:874`), `_recordCurveRedeem(termId, receiver, …)` books the exit (`:879`); the 5th use is the payout (`:881`). The callees already name this `account` (`:1118`, `:1312`, `:1461`). | `account` inside the library; keep the external `redeem(address receiver, …)` name for ABI stability but fix its natspec (M4) | LEGACY |
| M4 | `IMultiVault.sol:636, :653` `@param receiver Address to receive the redeemed assets`; `:413` `isApprovedToRedeem` `@param receiver The address that would receive redeemed assets` | doc | the address must **hold** the shares — they are burned from it and its curve-fee tier is used; `msg.sender` must be it or hold its REDEMPTION approval | rewrite natspec: "The account whose shares are burned and which receives the assets; `msg.sender` must be this address or hold its redemption approval" | LEGACY (doc is now *more* wrong because the curve fee keys on this account's tier) |
| M5 | `IMultiVault.sol:145` `Deposited.totalShares`, `:166` `Redeemed.totalShares` | `totalShares` | the receiver's/account's **personal** balance after the op (`MultiVaultLib.sol:845` passes `userBalanceAfter`, `:887` passes `userSharesAfter`; natspec `:135, :156` says so) | `receiverSharesAfter` / `accountSharesAfter` — `totalShares` means vault supply everywhere else (`VaultState`, `SharePriceChanged`, `getVault`, `IBaseCurve`). Event param names are not in the topic hash, so this is ABI-JSON/indexer-only; coordinate with the indexer team. | LEGACY |
| M6 | `IMultiVault.sol:471` `previewRedeem` `@return assetsAfterFees … (after protocol and exit fees)` | doc | the curve hook fee is also subtracted (`MultiVaultLib.sol:1144-1149`); the `@dev` block above it says so, the `@return` line contradicts it | add "and the curve-level redeem fee" | NEW (doc) |
| M7 | `IMultiVault.sol:168` `Redeemed.fees` | `fees` | `assetsBeforeFees − assetsAfterFees` = protocol + exit + **curve hook** fee | `totalFees`, and natspec should say the curve fee is included | NEW (semantics changed; name LEGACY) |

### 2.2 Rate vs amount

| # | Location | Current | Holds | Proposed | Tag |
|---|---|---|---|---|---|
| M8 | `MultiVaultLib.sol:1595` `_feeOnRaw(uint256 amount, uint256 feeBps)`; `MultiVault.sol:856-862` duplicate + natspec "the fee bps (numerator)" | `feeBps` | a numerator over `generalConfig.feeDenominator`, which is a **configurable** storage value, not fixed 10 000 | `_feeOnRaw(uint256 assets, uint256 feeRate)` (or `feeNumerator`) | **NEW** — was `fee` on `main`; the rename to `feeBps` presumes bps |
| M9 | Local fee **amounts** named identically to the **rate** field they are computed from: `MultiVaultLib.sol:996, :1020, :1050, :1080, :1126` `uint256 protocolFee = _feeOnRaw(x, s.vaultFees.protocolFee)`; `:1021, :1081` `entryFee`; `:1127` `exitFee`; `:959, :997, :1023` `atomWalletDepositFee` | `protocolFee` etc. | amounts in assets | `protocolFeeAmount`, `entryFeeAmount`, `exitFeeAmount`, `atomWalletDepositFeeAmount` — the codebase already uses the suffix at `:950` (`protocolFeeAmount`), `:1051/:1083` (`atomDepositFractionAmount`) and on the external getters `protocolFeeAmount()/entryFeeAmount()/exitFeeAmount()` | LEGACY |
| M10 | `MultiVaultLib.sol:944` `_accumulateVaultProtocolFees` local `fees` | `fees` | protocol fee amount | `protocolFeeAmount` (match `:950`) | LEGACY |
| M11 | `IMultiVaultCore.sol:64-73` `VaultFees.entryFee/exitFee/protocolFee`, `:32` `atomWalletDepositFee`, `:48` `atomDepositFractionForTriple` (rates) vs `:30` `atomCreationProtocolFee`, `:46` `tripleCreationProtocolFee` (absolute wei) | `…Fee` for two units | — | **Conscious keep** (storage-getter ABI names); add the unit to each `@dev` ("numerator over `feeDenominator`" vs "absolute, wei"). `…FeeRate` if you are willing to break the getters. | LEGACY |

### 2.3 `assets*` dataflow in the deposit / redeem paths

| # | Location | Current | Holds | Proposed | Tag |
|---|---|---|---|---|---|
| M12 | `MultiVaultLib.sol:1265-1270` `_updateVaultOnCreation(…, uint256 assets, uint256 shares, …)`, `:1292-1297` `_updateVaultOnDeposit(…, uint256 assets, …)` | `assets` | `assetsAfterFees` at every call site (`:640, :725, :828, :835`) | `assetsAfterFees` | LEGACY |
| M13 | `MultiVaultLib.sol:1312-1317` `_updateVaultOnRedeem(account, …, uint256 assets, …)` | `assets` | `rawAssetsBeforeFees` (`:874`) — gross value of the burned shares | `assetsBeforeFees` | LEGACY |
| M14 | `MultiVaultLib.sol:321, :323, :863-895` `rawAssetsBeforeFees`; `:353, :355` `assetsBeforeFees`; `:351` `_totalAssetsBeforeFees`; `:1124` `_calculateRedeem` local `assets` | four spellings | the same quantity: `_convertToAssets(termId, curveId, shares)` | `assetsBeforeFees` everywhere (drop "raw"). Lockstep: `MultiVault.sol:106` natspec cites `rawAssetsBeforeFees` by name. | LEGACY |
| M15 | `MultiVaultLib.sol:1479` `_validateRedeem` local `expectedAssets` | `expectedAssets` | `assetsAfterFees` (first return of `_calculateRedeem`) | `assetsAfterFees` | LEGACY |
| M16 | create path `assetsAfterFixedFees` (`:436, :445, :984, :994, :999, :1048, :1055`) vs deposit path `assetsAfterMinSharesCost` (`:455, :972, :1008-1015, :1064-1075`) | two names | in both paths: the **fee base** — the figure every rate-fee and `quoteDepositFee` is applied to | one internal name, e.g. `feeBaseAssets`; keep `assetsAfterFixedFees` on the external `previewAtomCreate`/`previewTripleCreate` return if ABI names matter. Note "fixed fees" is itself loose: the `minShare` portion is a seed that stays in the vault, not a fee. Lockstep: `MultiVault.sol:457, :466`; `IMultiVault.sol:430-436, :483-489`. | LEGACY |
| M17 | `MultiVaultLib.sol:942` `_accumulateVaultProtocolFees(uint256 assets)`, `:956` `_accumulateAtomWalletFees(termId, uint256 assets)` | `assets` | the fee base, never the gross deposit | `feeBaseAssets` (goes with M16) | LEGACY |
| M18 | `IMultiVault.sol:430-431` `previewAtomCreate` `@return assetsAfterFixedFees The net assets that will be added to the vault (after fixed fees, before dynamic fees)`; `:483-484` `previewTripleCreate` "(after fixed fees like protocol and entry fees)" | doc | it is **not** added to the vault — it is the fee base; the triple fixed cost is `tripleCreationProtocolFee + 2·minShare`, no entry fee is charged on creation, and the rate protocol fee is deducted *after* this figure | fix natspec | LEGACY (doc) |
| M19 | `IMultiVault.sol:142` `Deposited.assets` (gross, incl. min-share cost) vs `:167` `Redeemed.assets` (net payout) | `assets` | opposite fee-inclusion on sibling events | `Redeemed.assetsAfterFees` (gross is recoverable as `assets + fees`) — ABI-JSON only | LEGACY |
| M20 | `MultiVaultLib.sol:825` `userBalanceAfter` vs `:873, :639, :724` `userSharesAfter` vs `:1285` `receiverSharesAfter` | three names | share balance after the op | `receiverSharesAfter` (deposit/create), `accountSharesAfter` (redeem) — pairs with M5 | LEGACY |
| M21 | `MultiVaultLib.sol:800-848` `sharesForReceiver`; `:1434-1437` `_validateMinShares(…, sharesForReceiver, …, minSharesForReceiver)` vs external `minShares` (`:260, :280, :774`) | `sharesForReceiver` / `minSharesForReceiver` | minted shares / slippage floor | either `shares`/`minShares` throughout or keep `sharesForReceiver` but match `minShares`. Minor — `sharesForReceiver` is at least explicit. | LEGACY |
| M22 | `MultiVaultLib.sol:1118-1121` `_calculateRedeem(…) returns (uint256, uint256, CurveHook memory hook)` (returns `(assetsAfterFees, shares, hook)` at `:1151`); `:1039` `_calculateTripleCreate(...) returns (uint256, uint256, uint256)` vs named sibling `_calculateAtomCreate` (`:981-984`) | unnamed | — | name them: `(uint256 assetsAfterFees, uint256 sharesUsed, CurveHook memory hook)` mirroring public `calculateRedeem`/`previewRedeem`; `(uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)` | NEW (the `hook` return is new; the unnamed pair is legacy) |

### 2.4 Bare `amount` / `value` / role names

| # | Location | Current | Holds | Proposed | Tag |
|---|---|---|---|---|---|
| M23 | `MultiVaultLib.sol:476` `maxRedeem(address sender, termId, curveId)`; `MultiVault.sol:424`; `IMultiVault.sol:395-399` | `sender` | the account whose `balanceOf` is read — `sender` means operator/`msg.sender` everywhere else | `account` (matches `getShares(address account, …)` at `IMultiVault.sol:338`) | LEGACY |
| M24 | `MultiVaultLib.sol:1375` `_mint(address to, …, uint256 amount)`, `:1381` `_burn(address from, …, uint256 amount)`, `:403` `burn(…, uint256 amount)`; `MultiVault.sol:879` | `amount` | shares, always | `shares` | LEGACY |
| M25 | `MultiVaultLib.sol:1183` `_addUtilization(address user, int256 totalValue)` vs `:1210` `_removeUtilization(address user, int256 amountToRemove)`; public mirrors `:416, :421`; `MultiVault.sol:906, :912` | `totalValue` / `amountToRemove` | a signed **delta** in assets (gross payment on add, `assetsBeforeFees` on remove) | same name in both — `int256 assets` or `utilizationDelta`; `totalValue` is additionally wrong since it is a delta, not a total (events already say `valueAdded`/`valueRemoved`) | LEGACY |
| M26 | `MultiVaultLib.sol:1158` `_increaseProRataVaultsAssets(tripleId, uint256 amount)`, `:1161` `amountPerTerm`, `:1168` `_increaseProRataVaultAssets(termId, uint256 amount, …)` | `amount` | assets | `assets`, `assetsPerTerm` | LEGACY |
| M27 | `MultiVaultLib.sol:661-667` `_createTriples(…, uint256[] assets, uint256 amount)` | `amount` | the validated total payment | `payment` — matches `_createAtoms(…, uint256 payment)` (`:541`) and the library's documented convention (`:37-39`) | NEW (library param) |
| M28 | `MultiVaultLib.sol:184, :207, :221, :237, :255` `_amount` vs `:283` `_assetsSum` | `_amount` | `_validatePayment`'s return (== `payment`) | `_assetsSum`, or drop the local and pass `payment` | LEGACY |
| M29 | `MultiVaultLib.sol:180, :191, :230, :541, :557` `bytes[] calldata data`, `:610` `bytes calldata data`; `MultiVault.sol:620, :632, :651` vs `IMultiVault.sol:515, :533, :572` `atomDatas` | `data` | atom metadata | `atomDatas` / `atomData` (matches `MultiVault_AtomExists(bytes atomData)`, `AtomCreated(…, bytes atomData, …)`); also disambiguates from `multicall(bytes[] data)` | LEGACY |
| M30 | `MultiVaultLib.sol:1568` `_hasCounterStake(tripleId, curveId, address receiver)` | `receiver` | the account whose opposite-side balance is read | `account` | LEGACY |
| M31 | `MultiVaultLib.sol:568` `_finalizeAtomBatch(creator, uint256 length, payment)` | `length` | multiplies a per-atom fee | `atomCount` | NEW (minor) |
| M32 | `MultiVaultLib.sol:282` `depositBatch … returns (uint256[] memory shares)` vs `:335` `redeemBatch … returns (uint256[] memory received)` | `received` | assets paid out | `assets` (or `assetsAfterFees`) | LEGACY |
| M33 | `IMultiVault.sol:179, :186, :199` `AtomWalletDepositFeeCollected.amount`, `ProtocolFeeAccrued.amount`, `ProtocolFeeTransferred.amount` | `amount` | fee amounts | `feeAmount` | LEGACY |
| M34 | `MultiVaultLib.sol:644-646, :737-739` `emit Deposited(creator, creator, …)` — `sender` slot carries `creator`, while `_processDeposit` (`:845`) emits `msg.sender` there and the `*For` paths make `creator != msg.sender`; in the same call `ProtocolFeeAccrued`/`AtomWalletDepositFeeCollected` emit `msg.sender` | semantics | `sender` = operator on one path, principal on the other | not a rename — a conscious decision + doc on `IMultiVault.sol:127` | LEGACY |

### 2.5 Term / atom / triple id names

| # | Location | Current | Proposed | Tag |
|---|---|---|---|---|
| M35 | `IMultiVaultCore.sol:227, :234` `getAtomCreator(bytes32 atomId)` / `getAtomCreatedAt(bytes32 atomId)` vs `IMultiVault.sol:324, :331` and `MultiVault.sol:398, :403` `termId` — same selector, two interfaces disagree | `atomId` / `termId` | `atomId` everywhere (natspec already says "The atom ID") | **NEW** (added to `IMultiVaultCore` on this branch) |
| M36 | `MultiVault.sol:724` `claimAtomWalletDepositFees(bytes32 termId)` vs `IMultiVault.sol:255` `atomId` | — | `atomId` | LEGACY |
| M37 | `MultiVault.sol:341` / `IMultiVault.sol:389-392` `isTermCreated(bytes32 id)`; `IMultiVaultCore.sol:328` `isTriple(bytes32 id)` vs `MultiVaultCore.sol:233` `isTriple(bytes32 termId)` | `id` | `termId` | LEGACY |
| M38 | `IMultiVaultCore.sol:316`, `MultiVaultCore.sol:175, :264` `isAtom(bytes32 atomId)` — the predicate tests whether an arbitrary term is an atom, so the name presupposes the answer | `atomId` | `termId` | LEGACY (minor) |
| M39 | `IMultiVaultCore.sol:292`, `MultiVaultCore.sol:209` `getTripleIdFromCounterId(bytes32 counterId)`; `:261` `@return counterId` vs storage `counterTripleId` and `_calculateCounterTripleId` | `counterId` | `counterTripleId` | LEGACY (minor) |
| M40 | `MultiVault.sol:192` `MultiVault_AtomDoesNotExist(bytes32 atomId)` vs `MultiVaultCore.sol:81` `MultiVaultCore_AtomDoesNotExist(bytes32 termId)`; `MultiVault.sol:238` `MultiVault_TripleExists(bytes32 termId, …)` carries a triple id | — | `atomId` / `tripleId` | LEGACY |
| M41 | `MultiVaultCore.sol:294-297` `_isCounterTriple` natspec: "get the triple id from the given counter id … @return tripleId" — copy-pasted from `getTripleIdFromCounterId`; the function returns a `bool` | doc | fix | LEGACY (doc) |
| M42 | `IMultiVaultCore.sol:29, :45` "The fee paid to the protocol when depositing vault shares for atom vault creation" — a flat creation fee; nothing is deposited as shares | doc | fix | LEGACY (doc) |

### 2.6 Style (pick a convention, low priority)

- `MultiVaultLib.sol:1298` `_updateVaultOnDeposit(…, VaultType _vaultType)` — siblings use `vaultType`.
- Underscore-prefixed locals appear with no rule: `:184 _amount`, `:283 _assetsSum`, `:351 _totalAssetsBeforeFees`, `:507 _currentEpochLocal` vs `:1233 currentEpochLocal`, `:512 _userEpochHistory`, `:778/:859 _vaultType`, `:1665-1667 _isVault*`.
- `MultiVaultLib.sol:1104` `_depositShares(termId, curveId, assetsAfterFees)` is a pure preview that reads as an action → `_previewDepositShares`.
- `MultiVaultLib.sol:1604` `_tripleExists(bytes32 termId, …)` is a revert-if-exists guard on a triple id → `_requireTripleNotExists(bytes32 tripleId, …)`.
- `MultiVaultLib.sol:1370` local `price` → `sharePrice` (event and `IBaseCurve` say `sharePrice`).
- Unnamed returns where the interface natspec names them: `MultiVault.sol:408` `getVault` (`totalAssets`, `totalShares`); `IMultiVault.sol:298, :304, :310, :493` (`price`, `feeAmount`); `IMultiVaultCore.sol:206-216` `calculateCounterTripleId`/`calculateTripleId`; `MultiVaultCore.sol:184, :190` `triple`/`getTriple` → `(subjectId, predicateId, objectId)`.
- `MultiVaultLib.sol:1579-1593` `_convertToShares`/`_convertToAssets` call the registry's `previewDeposit`/`previewRedeem`, not its `convertToShares`/`convertToAssets`; keep, but one natspec line on the external `convertToShares/convertToAssets` (`MultiVault.sol:493, :499`) saying they have preview semantics.
- `IMultiVault.sol:445-448` vs `:473-476`: `previewDeposit` returns `(shares, assetsAfterFees)`, `previewRedeem` returns `(assetsAfterFees, sharesUsed)` — mirrored order, `sharesUsed` echoes the input. ABI-breaking to change; consciously keep.

### 2.7 Already consistent (checked)

- `assets` vs `shares` is correct in every **external** signature across `IMultiVault`, `MultiVault` and the `MultiVaultLib` mirrors (`deposit`, `depositBatch`, `redeem`, `redeemBatch`, `previewDeposit`, `previewRedeem`, `convertTo*`, the `create*` families); `minShares`/`minAssets` match their path.
- The hook is wired with the right quantities: `quoteDepositFee(termId, assetsAfterMinSharesCost)` = IBaseCurve's "post-min-shares cost, pre-MultiVault-fees"; `quoteRedeemFee(termId, account, assets)` gets gross; `recordDeposit` gets minted `sharesForReceiver`; `recordRedeem` gets burned `shares`. `CurveHook.curve/.fee` are documented as address / asset amount; `_depositFeeHookCurve`/`_redeemFeeHookCurve` are symmetric.
- `_calculateRedeem`, `_validateRedeem`, `_updateVaultOnRedeem` already use `account` — M2/M3 only bring their callers into line.
- `assetsAfterFees` means the same thing at every site. `termId`/`curveId`/`tripleId`/`subjectId`/`predicateId`/`objectId` are uniform apart from the §2.5 strays.
- Approval vocabulary is self-consistent (`approvals[receiver][sender]`, `approve(sender, …)`, `_isApprovedToDeposit/Redeem(sender, receiver)`, `_isApprovedToCreate(sender, creator)`); `creator` is uniform on all create paths; `payment` is the library's explicit-value param everywhere except M27.
- `_setVaultTotals`, `SharePriceChanged`, `VaultState`, `getVault` all use `totalAssets`/`totalShares` for vault-wide totals (which is exactly why M5 matters).
- External `…Amount(uint256 assets)` getters and `_accumulateStaticProtocolFees(uint256 protocolFeeAmount)` follow the amount suffix (the model for M9).
- `minShare` (shares) vs `_minAssetsForCurve(curveId, minShare)` / `minShareCost` (assets) are kept distinct.
- Initializer/setter params (`_generalConfig`, `_atomConfig`, …, `_timelock`) match across all four files. `MultiVaultLib.Storage` field names intentionally drop the `_` prefix and the struct comment (`:89-92`) says so.
- Utilization role name `user` is uniform across `_addUtilization`, `_removeUtilization`, `_rollover`, `getUserUtilization*`, `userEpochHistory`, `personalUtilization` and the four utilization events.

## 3. `FeeProxy` / `IFeeProxy`

FeeProxy has no redeem path (deposit + creation only), so the axis here is *single deposit vs batch vs creation* and *interface vs events vs helpers*. Interface-vs-implementation parameter lists match exactly on every function; all drift is between siblings. Verified against `FeeProxy.sol:258-282` and `:585-598`.

### 3.1 Wrong or misleading

| # | Location | Current | Holds | Proposed | Sev |
|---|---|---|---|---|---|
| P1 | `IFeeProxy.sol:419` `error FeeProxy_ZeroValue()`; thrown at `FeeProxy.sol:262` (`grossAssets == 0`) and `:768` (`values[i] == 0`) | `ZeroValue` | a zero **asset** amount, never `msg.value` | `FeeProxy_ZeroAssets` | WRONG-ish — in this codebase "value" means `msg.value` (`MultiVault._checkZeroValue`, and the sibling `FeeProxy_InsufficientValue` *is* about `msg.value`). |
| P2 | `IFeeProxy.sol:272, :290, :308` events `DepositedBatchVia / CreatedAtomsVia / CreatedTriplesVia(..., uint256 totalFee, ...)` + natspec `:266, :283, :301` ("Sum of affiliate fees deducted across the batch") | `totalFee` | **one** fee computed once on the aggregate (`_calcFee(totalGrossAssets, bps, fixedFee)` at `FeeProxy.sol:590` — one bps cut + **one** fixed fee per call, not per leg) | `affiliateFee` (the name `RoutingFlow.affiliateFee:562` already uses) and fix the natspec to say "applied once to the aggregate" | WRONG natspec / misleading name — `total*` next to `totalGrossAssets` implies a per-leg sum. Same per-leg phrasing on the `feeGuard` natspec at `:618, :640, :661, :684`. |

### 3.2 Inconsistent

| # | Location | Current | Proposed | Why |
|---|---|---|---|---|
| P3 | `IFeeProxy.sol:616, :639, :659, :683` batch/creation `uint256[] assets` params; impl `FeeProxy.sol:289-394`, `_setupRoutingFlow:569-597`, `_allocate:779-790` | `assets` | `grossAssets` | Single-leg `depositVia` calls the same quantity `grossAssets` (`:594`); and these arrays are *pre-fee* while the `IMultiVault.depositBatch(..., assets)` slot they eventually feed receives `flow.forwardedAssets` (*post-fee*) — reusing `assets` invites equating the two. |
| P4 | `IFeeProxy.sol:254` `event DepositedVia(..., uint256 fee, ...)` | `fee` | `affiliateFee` | Impl local (`:269`), `RoutingFlow.affiliateFee`, `_recordAffiliateStats(... affiliateFee ...)` all say `affiliateFee`; batch events say `totalFee`; `AffiliateFeePaid` says `amount`. One quantity, four names. |
| P5 | `IFeeProxy.sol:320` `event AffiliateFeePaid(affiliate, user, uint256 amount)`; `FeeProxy.sol:741` `_payAffiliate(feeRecipient, affiliate, user, uint256 amount)` | `amount` | `affiliateFee` | Same as P4. |
| P6 | `IFeeProxy.sol:222` `event RegistrationFeeForwarded(treasury, uint256 amount)` | `amount` | `registrationFee` | `AffiliateRegistered(... registrationFee)` at `:190` names the identical value in the same tx. |
| P7 | `IFeeProxy.sol:779, :790` `previewDepositFee / previewCreationFee returns (uint256 fee, uint256 forwarded)`; impl `FeeProxy.sol:508-523` | `forwarded` | `forwardedAssets` (and `fee` → `affiliateFee`) | Every other site carries the unit: `totalForwardedAssets`, `RoutingFlow.forwardedAssets`, stats fields. |
| P8 | `IFeeProxy.sol:537` / `FeeProxy.sol:234` `updateFeeRecipient(address recipient)` | `recipient` | `feeRecipient` | `registerAffiliate(..., feeRecipient)` (`:478`), `AffiliateConfig.feeRecipient` (`:39`), `AffiliateRegistered.feeRecipient` all use `feeRecipient`; bare `recipient` is already the *refund* destination in `claimRefundTo(address payable recipient)` (`:721`). After this rename, `recipient` means exactly one thing. |
| P9 | `FeeProxy.sol:721` `_assertFeeGuard(configuredBps, configuredFixed, FeeGuard calldata guard)` | `configuredFixed` / `guard` | `configuredFixedFee` / `feeGuard` | Every other helper says `fixedFee` (`_assertSideWithinCaps(bps, fixedFee):712`, `_calcFee(..., fixedFee):733`); every entry point names the struct `feeGuard`. Also `:713-714` local `fixedCap` → `fixedFeeCap`. |
| P10 | `FeeProxy.sol:577` `_setupRoutingFlow(..., bool useCreationFees)` vs `:625` `_recordAffiliateStats(..., bool isCreation)` | two names | `isCreation` for both | Same flag, passed as literal `true`/`false` at paired call sites (`:300/277`, `:330/339`, `:361/370`, `:394/416`). |
| P11 | `IFeeProxy.sol:342` `FeeProxy_RegistrationFeeMismatch(uint256 sent, uint256 required)` vs `:428` `FeeProxy_InsufficientValue(uint256 supplied, uint256 required)` | `sent` / `supplied` | `supplied` for both | Both first args are `msg.value`. |
| P12 | `IFeeProxy.sol:434` `FeeProxy_FeeExceedsGross(uint256 fee, uint256 gross)`; `FeeProxy.sol:780` `_allocate(assets, uint256 totalForwarded, uint256 totalGross)` | `gross` / `totalForwarded` / `totalGross` | `grossAssets` / `totalForwardedAssets` / `totalGrossAssets` | The only places the gross/forwarded quantities drop their `Assets` suffix; the callers pass suffixed variables (`:597`). |

### 3.3 Conscious-keep candidates

| # | Location | Note |
|---|---|---|
| P13 | `IFeeProxy.sol:66-68` `struct FeeGuard { maxFeeBps; maxFixedFee; }` | Field names are identical to the protocol-level storage getters `maxFeeBps()` / `maxFixedFee()` (`:815, :820`) — a different concept (protocol cap vs caller guard). The errors already disambiguate (`…ExceedsCap` vs `…ExceedsCallerGuard`). Rename to `callerMaxFeeBps` / `callerMaxFixedFee` only if you want zero collision; otherwise keep. |
| P14 | `RoutingFlow.forwardedAssets` (array, `:565`) vs `_recordAffiliateStats(..., uint256 forwardedAssets, ...)` (scalar, `:624`) | Same name for a per-leg array and a per-tx scalar. Tolerable; `legForwardedAssets` for the array if you want it unambiguous. |
| P15 | Refund surface (`pendingRefund`, `claimRefund`, `claimRefundTo`, `_refundExcess`, `RefundCredited`, `RefundClaimed`) all use bare `amount` | Consistently bare and documented as TRUST. Optional `refundAssets` sweep. |

### 3.4 Already consistent (checked)

- Interface ↔ implementation param/return names match on every function.
- Names forwarded into `IMultiVault` (`receiver`, `termId(s)`, `curveId(s)`, `minShares`, `atomDatas`, `uris`, `subjectIds/predicateIds/objectIds`) match the slot they land in.
- Gross / fee / forwarded are correctly distinguished in the implementation bodies (`grossAssets`, `affiliateFee`, `forwardedAssets`); `_refundExcess(user, msg.value - grossAssets)` is correctly "excess".
- Every bps rate carries `Bps`; every fixed-fee amount carries `FixedFee`; no `fee` variable holds a rate.
- Role words: `user` = proxy `msg.sender`; `receiver` = share receiver; `affiliate` = registry key; `feeRecipient` = fee destination; `recipient` = refund destination (once P8 lands).
- Stats structs (`AffiliateStats`, `AffiliateUserStats`) and setter/event `(previous, current)` pattern are internally consistent.

---

## 4. Blast radius (occurrence counts, current branch)

Counts are raw string hits (`grep -rho … | wc -l`) so you can size each decision. `docs` = `docs/` + `.planning/`.

| Rename | src | tests | script | docs | Notes |
|---|---|---|---|---|---|
| `netStake` → `shares`/`stake` (H1, C1–C3) | 14 | 23 | 0 | 2 | tests: `DynamicFeeFlatPriceCurve.t.sol`, `DynamicFeeMedusaHandler.sol`, security suites |
| `withdrawnStake` → `shares` (H2, C4) | 8 | 2 | 0 | 0 | |
| `baseAssets` (H3, promote to interface) | 5 | 5 | 0 | 0 | interface + mock change; curve unchanged |
| `grossAssets` (H4, promote to interface) | 50 | 31 | 0 | 1 | curve has 3; the rest are FeeProxy and already correct |
| `withdrawal`/`Withdrawal` → `redeem`/`Redeem` (D3) | 72 | 133 | 6 | 18 | `script/` = deploy config field names; `docs/call-flows/dynamic-fee-curve.md` |
| `growthGBps` → `tierWidthGrowthBps` (G1) | 12 | 32 | 3 | 3 | struct field → every `DynamicFeeConfig({...})` literal |
| `fulcrumAlpha` → `fulcrumAlphaBps` (G2) | 10 | 27 | 1 | 3 | same |
| `userStake`/`userTier`/`userAvgTier` mapping renames (L5, optional) | 26 | 65 | 0 | 0 | public getters — only if you take the optional half of L5 |
| `bankedEarnings` / `earned` (L6) | 6 | 5 | 0 | 0 | |
| MultiVault §2 WRONG items (M3–M5, M8, M23, M25) | ~40 | unknown | 0 | 1 | `tests/unit/MultiVault/*` reference `maxRedeem`, events by position not name |
| FeeProxy §3 (P1–P12) | ~60 | ~20 | 0 | 0 | `tests/unit/FeeProxy/*` and `tests/unit/security/v1.1.0/FeeProxy*`; event param names are positional in Foundry `expectEmit`, so only error/function renames touch tests |

Everything in §1 and §3 is a fresh deploy (new curve id, new periphery contract), so ABI-name changes there have no live-contract cost. The §2 event-name items (M5, M7, M19) are on the **upgraded** `MultiVault` proxy — topic hashes do not change, but any indexer that decodes by parameter name must be updated in lockstep.

## 5. Suggested order of work (once you have picked D1–D7)

1. **Hook surface first** (H1–H4, C1–C5, M1–M2) — interface, curve, mock, lib in one commit; run the curve and `CurveFeeHookDetection` suites.
2. **Curve internals** (T1–T7, S1–S2, L1–L7, G1–G4, and D3 if taken) — one commit per group so the diff is reviewable; rerun `DynamicFeeFlatPriceCurve.t.sol`, the medusa handler, and the `v1.1.0` security suites.
3. **FeeProxy** (P1–P12) — one commit.
4. **MultiVault NEW-tagged items** (M6–M8, M22, M27, M31, M35) — one commit.
5. **MultiVault LEGACY WRONG items** (M3–M5, M23, M25 + the doc fixes M4, M18, M41, M42) — separate commit, flagged for the indexer team.
6. **Style sweep** (§1.5 optionals, §2.6, §3.3) — last, or skip.
7. Update `docs/call-flows/dynamic-fee-curve.md` and `docs/call-flows/multivault-value-paths.md` for any taken rename, and regenerate via `script/viz/generate-call-flows.ts` (it references `recordDeposit`/`recordRedeem` by name).

## 6. Method

Every hook parameter was traced from `MultiVaultLib` call site → value origin before judging its name (§1.0 table). The pricing surface (`preview*` / `convertTo*` / `currentPrice`) was diffed across `IBaseCurve`, `BaseCurve`, `LinearCurve`, `ProgressiveCurve`, `OffsetProgressiveCurve`, `BondingCurveRegistry`, `IBondingCurveRegistry` and found uniform. `DynamicFeeFlatPriceCurve` was read in full. `MultiVaultLib` / `MultiVault` / `IMultiVault` / `IMultiVaultCore` / `MultiVaultCore` and `FeeProxy` / `IFeeProxy` were swept by two parallel read-only passes; every WRONG-severity claim from those passes was re-verified by hand against the source before inclusion (`_feeOnRaw` denominator, `maxRedeem(sender)`, utilization params, `_mint/_burn(amount)`, `_createTriples(amount)`, `_isCounterTriple` natspec, `Deposited(creator, creator)`, `previewAtomCreate` / `previewRedeem` natspec, FeeProxy `totalFee` / `ZeroValue` / `forwarded` / `updateFeeRecipient`). Pre-existence tags were checked against `git show main:src/protocol/MultiVault.sol` and the `main` interfaces.

---

## 7. Applied — 2026-08-23 (branch `feat/v1.1.0-core-upgrade-variable-names`)

All sections applied as recommended (D1(a), D2(A), D3(a), D4, D5, D6 incl. LEGACY items, D7), in five commits:

1. `refactor: align curve hook parameter names with the values passed` — H1–H4, C1–C2, M1–M2.
2. `refactor: role-name the dynamic-fee curve's internals` — T1–T7, S1–S2, L1, L3, L5 (mapping keys), L6/D7 (`earned` → internal `settledEarnings`), C3–C4 event params.
3. `refactor: give DynamicFeeConfig's unit-less fields their unit suffixes` — G1, G2.
4. `refactor: rename the curve fee vocabulary from 'withdrawal' to 'redeem'` — §1.7, src + tests + script + docs.
5. `refactor: name MultiVault's quantities and roles for what they hold` — §2 in full (M3–M42 as listed, incl. LEGACY), M16 taken all the way: `feeBaseAssets` replaced `assetsAfterFixedFees` on the external previews too.

Deviations from the proposal, both deliberate:
- **L7 kept**: `setTierFeeOverride(..., newDepositFeeBps, newRedeemFeeBps)` keeps the `new` prefix — dropping it would shadow the public `depositFeeBps(uint256)` / `redeemFeeBps(uint256)` getters.
- **M21 kept**: `sharesForReceiver` stays (explicit and harmless); only `minSharesForReceiver` → `minShares` was aligned.
- Skipped as proposed: §2.6 style items (`_depositShares` fn name, underscore-local convention, unnamed getter returns), P13–P15 conscious-keeps, L2/L4 optionals.

Validation: full suite green after every phase; final run 2134 passed / 0 failed / 7 skipped (identical to the pre-change baseline). `forge fmt` applied; only pre-existing warnings remain (TrustBonding shadowing, WrappedTrust SPDX).
