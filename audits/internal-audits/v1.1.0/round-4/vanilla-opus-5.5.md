# Round 4 — isolated adversarial lane — Claude Opus 5.5

> **Lane:** isolated adversarial review, Claude Opus 5.5 via the Agent tool (model pinned; reasoning effort inherited from the orchestrating session), in its own detached worktree at public `ea6c239` with its own build. **Brief:** the identical round-4 lane brief, with one extra line on the accepted-behaviour list (`deposit_for`, added after the cold lane re-raised it); no prior internal report and no other lane's output. **Proofs of concept:** 14 tests under a gitignored scratch directory (random-sequence runs at the launch schedule, a differential fuzz of the gas refactor against its parent commit, replays of the auditor's 5.1 and 5.3 sequences, integration tests through the real MultiVault and FeeProxy, and the finding's reproduction with the verbatim v1.0.2 wallet behind a real beacon), rerun by the orchestrator with the same result (14/14). **Interruptions:** two earlier starts were stopped during the scope read by external pauses; this is a fresh start in a clean worktree. **Output below is verbatim.** Dispositions are in the master report (§6: `R4-01`, `R4-02`, below-threshold notes).

---

# Lane report: Intuition v1.1.0 core upgrade, adversarial pass 4

## Lane

- Model: Claude Opus 5.5 (`claude-opus-5-5`), running as the isolated "lane-opus2" reviewer.
- Worktree: `<lane worktree>`
- Commit: `ea6c239` (head of PR #158). Compared against `v1.0.2`, `52b206f` (pre gas pass) and `a7f6d9f`.
- Date: 2026-10-09. REVIEW-ROUND 1.
- Time: lane started 00:10 CEST (build log), report written 11:55 CEST. The wall clock includes idle time; the active review time cannot be measured from inside the lane.
- Nothing under `audits/` was read. No file under `src/`, `script/`, `tests/unit`, `tests/invariant`, `docs/`, `lib/` or `node_modules/` was modified.

## Scope read

| File | Read in full | Attacked hardest |
| --- | --- | --- |
| `src/protocol/curves/DynamicFeeFlatPriceCurve.sol` (1,681) | yes | Exiter exclusion and re-base across every credit path; per-op conservation and solvency under random sequences at the launch schedule |
| `src/protocol/curves/BaseCurve.sol` | yes | Hook defaults on the upgraded hookless curves (must return false, never revert) |
| `src/libraries/MultiVaultLib.sol` (1,726) | yes | Quote/record dataflow (`CurveHook`), 1:1 par on a hook-curve vault, seeding of new non-default vaults |
| `src/protocol/MultiVault.sol` | yes | `multicall` value accounting, `_effectiveMsgValue`, re-entry while the transient context is live |
| `src/protocol/MultiVaultCore.sol` | yes | Storage order against the library mirror |
| `src/periphery/FeeProxy.sol` | yes | 5.2 ordering, hostile fee recipient, receiver/creator approval model |
| `src/protocol/wallet/AtomWarden.sol` | yes | Reinitializer gating and the post-upgrade claim paths for v1.0.2 wallets |
| `src/protocol/wallet/AtomWallet.sol` | yes | State a v1.0.2 wallet carries into the v1.1.0 implementation (finding F-01) |
| `src/libraries/CoinbaseSmartWalletLib.sol` | yes | Empty registry on pre-upgrade wallets; owner removal and rotation |
| `src/protocol/emissions/TrustBonding.sol` | yes | Pause overrides; storage unchanged since v1.0.2 |
| `src/external/curve/VotingEscrow.sol` | yes | `public virtual` conversion and modifier inheritance through `super` |
| `src/interfaces/IBaseCurve.sol` | yes | Hook contract and the "creation paths skip hooks" rule |
| `src/interfaces/IDynamicFeeFlatPriceCurve.sol` | yes | Config bounds and claim-view equalities |
| `src/interfaces/IMultiVault.sol` | yes | Approval semantics; redeem receiver = share owner |
| `src/interfaces/IMultiVaultCore.sol` | yes | Struct slot counts |
| `src/interfaces/IFeeProxy.sol` | yes | Documented guarantees vs implementation |
| `src/protocol/curves/LinearCurve.sol` | yes | Exact 1:1 conversions used by the hook curve |
| `src/protocol/curves/BondingCurveRegistry.sol` | yes | Id validation; registry is not upgraded |
| `src/protocol/wallet/AtomWalletFactory.sol` | yes | Address determinism across the beacon swap |
| `src/protocol/curves/OffsetProgressiveCurve.sol` | partly (math section) | Effect of ghost-share seeding on a non-empty progressive vault |
| `script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol` | yes | Batch contents and reinitializer separation |
| `script/intuition/v1.1.0/safe-txs/execution-order.md` | yes | Windows between steps 02, 03 and 04 |
| `script/intuition/DynamicFeeLaunchSchedule.sol` | yes | Launch values used in every PoC |
| `git show v1.0.2:` AtomWallet, AtomWarden, MultiVault, MultiVaultCore, IMultiVaultCore | yes (diff-relevant parts) | Pre-upgrade layouts, claim flow and `_rollover` |
| `git show a7f6d9f -- src/` | yes | Behaviour preservation (differential PoC) |
| Solady `Receiver`, `LibBit.fls`, `FixedPointMathLib.rpow/fullMulDiv/mulDivUp` | relevant parts | Fallback behaviour; `fls(0) == 256`; rounding direction |

## Findings

### F-01: A wallet claimed under v1.0.2 before step 02 is bricked by the AtomWallet beacon swap

- **Severity:** Medium (lock of a wallet's funds and of all its accrued atom-wallet fees until a further governance upgrade; conditional on a v1.0.2 claim completing before the upgrade executes).
- **Confidence:** High for the mechanism (reproduced end to end against the real v1.0.2 wallet source). The likelihood depends on whether any address-atom holder completes the v1.0.2 claim between now and execution; the brief states none has done so yet, but the v1.0.2 path stays live and permissionless until step 02.
- **Affected code:**
  - `src/protocol/wallet/AtomWallet.sol:97` — the owner now lives in the new `_primaryOwner` slot (slot 3, which was `__gap[0]` in v1.0.2, so it is zero for every pre-upgrade wallet).
  - `src/protocol/wallet/AtomWallet.sol:432-434` — `owner()` returns `_primaryOwner` when `isClaimed`, so it returns `address(0)` for a v1.0.2-claimed wallet.
  - `src/protocol/wallet/AtomWallet.sol:512-531, 546-555` — every gate and the ERC-4337 signature check read only the Coinbase MultiOwnable registry, which is empty for every pre-upgrade wallet.
  - `src/protocol/wallet/AtomWallet.sol:353-355` — `completeClaim` rejects a wallet whose `isClaimed` is already true.
  - `src/protocol/wallet/AtomWarden.sol:557-561` — `_requireWalletUnclaimed`, used by every claim and grant path (lines 275, 303, 351, 529), refuses the same wallet.
  - `src/protocol/MultiVault.sol:733-752` — only the wallet itself can pull its accrued fees.
  - v1.0.2 side: `AtomWallet.acceptOwnership` sets `isClaimed = true` and writes the owner to the OZ Ownable slot `0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300`; v1.0.2 `AtomWarden.claimOwnershipOverAddressAtom` is callable by the address any address atom encodes. Nothing in v1.1.0 reads that slot again.
- **Attacker sequence** (the "attacker" is any address-atom holder, typically a legitimate user; the loser is the same user):
  1. Any time before step 02 executes (including the 7-day timelock wait), the holder of address X, whose lowercase-address atom exists, calls `AtomWalletFactory.deployAtomWallet(atomId)` if the wallet is not deployed yet (permissionless).
  2. X calls v1.0.2 `AtomWarden.claimOwnershipOverAddressAtom(atomId)`; the warden calls `wallet.transferOwnership(X)` (pending owner).
  3. X calls `wallet.acceptOwnership()`; `isClaimed = true`, legacy owner slot = X.
  4. Step 02 executes; the beacon points every wallet at the v1.1.0 AtomWallet.
  5. `wallet.owner() == address(0)`, `ownerCount() == 0`. X cannot `execute`, cannot `claimAtomWalletDepositFees`, cannot `addOwnerAddress` or `transferOwnership`; no UserOp validates. The operator's `grantAtomWalletOwnership` and every AtomWarden claim path revert `AtomWarden_AlreadyClaimed`; `completeClaim` reverts `AtomWallet_AlreadyClaimed`.
  6. Every later deposit into atom X keeps accruing the 0.50% atom-wallet fee (`MultiVaultLib.sol:965-972`) into `accumulatedAtomWalletDepositFees[wallet]`, which nobody can claim.
- **Impact:** the affected wallet's native TRUST, any tokens it holds, and all atom-wallet deposit fees accrued for that atom (before and after the upgrade) are locked until governance ships and executes, through the 7-day Upgrades Timelock, another AtomWallet implementation that restores the owner. Bounded by the affected wallets' balances; no other holder's funds are touched. The admin path (v1.0.2 `AtomWarden.claimOwnership` followed by the user's `acceptOwnership`) produces the same state. Testnet 13579, upgraded by the same script, has the same exposure for any wallet QA claimed under v1.0.2.
- **Reproduction:** `tests/scratch/Lane2LegacyClaimedWallet.t.sol` (uses the verbatim v1.0.2 source as `tests/scratch/LegacyAtomWalletV102.sol`, behind a real `UpgradeableBeacon`/`BeaconProxy`, with the real v1.1.0 `AtomWarden`).
  - Command: `FOUNDRY_PROFILE=test FOUNDRY_FUZZ_RUNS=32 FOUNDRY_INVARIANT_RUNS=8 FOUNDRY_INVARIANT_DEPTH=128 forge test --match-path 'tests/scratch/Lane2LegacyClaimedWallet.t.sol' -vv`
  - Output: `[PASS] test_preUpgradeClaimedWallet_isBrickedByBeaconSwap() (gas: 3048604)` (asserts `owner() == address(0)`, every owner action and every repair path reverts, 4 TRUST in the wallet and 3 TRUST of accrued fees unreachable) and `[PASS] test_control_pendingOnlyWallet_stillClaimableAfterUpgrade() (gas: 3074769)` (a wallet with only the pending leg done stays claimable).
- **Recommendation (smallest fix):** add a one-time, permissionless `migrateLegacyClaim()` to AtomWallet: when `isClaimed && _primaryOwner == address(0) && CoinbaseSmartWalletLib.ownerCount() == 0`, read the v1.0.2 owner from slot `0x9016d0…9300`, require it non-zero, set `_primaryOwner` and seed the registry with it. It can only restore the owner v1.0.2 recorded, so it needs no access control. If no code change ships, make it a hard pre-flight for step 02: enumerate `AtomWalletDeployed` events from the factory and assert `isClaimed() == false` for every wallet immediately before signing step 02 (and again right before execution), and take any v1.0.2 claim UI offline for the timelock window.
- **Variant analysis:** single call — the two-transaction v1.0.2 claim above, plus the admin `claimOwnership` variant; batch / multicall — not applicable (the trigger is the beacon swap); preview — not applicable; FeeProxy route — not applicable; upgrade path — this is the upgrade path: the swap is in the step-01/02 timelock batch (`DeployCoreUpgradeImplementations.s.sol:417`), and no fork regression covers a wallet claimed under v1.0.2 (`tests/unit/upgrades/v1.1.0/` has none). A wallet whose pending owner was set but not accepted is not affected (control test); the legacy `acceptOwnership()` selector now reverts `FnSelectorNotRecognized`, so such users must claim again through the v1.1.0 paths.

## Refuted hypotheses

- **Lot ledger drift** (`userStake != Σ lots`, `tierStake != Σ lots`, mask bit without a lot): every write keeps them in step (`DynamicFeeFlatPriceCurve.sol:829-853` debit, `:1160-1174` credit). Checked after every step of 32 × 160-step and 1,500-step random runs at the launch schedule with 8 accounts, 2 terms, dust to 126k-TRUST amounts (`Lane2CurveSequences`), and by the repo's own invariant suite (4/4 pass).
- **Unwind walks past the last lot** (`fls(0) == 256`): unreachable because `userStake -= shares` underflows first (`:829`) and `userStake == Σ lots`.
- **Exiter paid from its own redeem fee at any tier**: every denominator subtracts the exiter's residual lot (`:945, :984, :1001, :1433`) and `_rebaseLots` (`:534, :786-793`) re-bases every residual lot after the distributions; `_settle` (`:510`) banked the pre-redeem pending first. Asserted per redeem: the exiter's total claimable is unchanged across its own redeem, across all random runs.
- **Over-credit / insolvency**: per-op check "liabilities grow by at most the fee received" never tripped (max over-credit 0 wei over 1,188 fee-bearing ops; 132,962,882 wei of dust left as surplus); final drain with everyone exiting and claiming stays solvent. Accumulator writes floor (`:1264, :1388, :1399`).
- **Dust seat keeps a tier's share (5.1 regression)**: fill weighting (`:1440`) and fill caps (`:1262`) stop it. Replay at the launch schedule: a 1-wei tier-0 seat earned 0 wei from 643.6 TRUST of later deposit fees (`test_replay51_dustSeatEarnsDust`).
- **Sentinel repositioning (5.3 regression)**: lots never average and redeems draw the top lots first (`:836-852`), so the 10,529 round trip leaves the 8,345 at tiers 0-2 (`userTopTier == 2`). The 288.1 TRUST redeem fee goes entirely to the bucket; only the deposit leg (272.1 TRUST) comes back, and only because the group owns every prior tier (`test_replay53_noRepositionAndRedeemLegNotRecaptured`).
- **Dust seats across the whole prior ladder**: 10 × 1-wei seats earned 0 wei while the honest full bands earned 3,149.8 TRUST (`test_dustSeatsAcrossLadder_earnFillOnly`).
- **Spread pays a thin or over-full tier above the schedule rate**: `D = max(Σe, Σw)` (`:1357`) keeps the common per-share rate at or below the schedule; an over-full tier only absorbs what thin tiers leave, at the same per-share rate.
- **Window fallback lets an out-of-window seat take the pool**: `_weighByFill` normalizes over `span × WEIGHT_PRECISION` (`:1449`); a dust seat still earns dust, and the fallback engages only when no in-window tier is eligible, so no other holder loses.
- **Revert that blocks a deposit, redeem or claim**: every division has a non-zero denominator by construction (`:1258` stake guard, `:1351` `sumWeights == 0` guard, `lastStake > 0` whenever `exact`), `room > 0` in the band walk (`:1064`, `_tierOf` strictness), arrays sized to their maximum (`:831, :1056`). No revert in any random run, including full exits of 16-lot positions and 126k-TRUST sweeps.
- **Quote vs execution disagreement**: MultiVault resolves the hook and quote once in the calc phase and forwards that exact value (`MultiVaultLib.sol:1038-1042, 1105-1109, 1147-1150, 933-945`); no curve state changes between quote and record; both quotes are pure functions of curve state (`DynamicFeeFlatPriceCurve.sol:420-436`). Differential runs also matched quotes between `52b206f` and `ea6c239`.
- **Hook-curve vault drifts off 1:1** (tier ladder reads the wrong unit): pro-rata value only reaches `defaultCurveId` (`MultiVaultLib.sol:1183-1188`); seeds add `minShare` shares with `previewMint(minShare,0,0) == minShare` assets (`:1295-1296, :1360-1361`). Par asserted after every integration step, including a vault created inside a multicall.
- **`a7f6d9f` changed behaviour** (residual mask, cached weights, eligibility fold): the mask returned by `_unwindLots` equals the stored mask because nothing between `:512` and `:534` writes `lotMask`; `_creditEligibleCapped` (`:1254-1267`) evaluates the same predicate as `_isEligibleStake` (`:1232-1237`). Differential fuzz of `ea6c239` against `52b206f` over 32 seeds × 4 configs (floor 0 / 500 / 5000 / 10000 bps, both routing levers at their extremes) compared every accumulator, lot, debt, mask, bucket and balance after every step: identical.
- **A multicall leg spends another leg's value**: each payable entry consumes exactly its allocation (`MultiVault.sol:636-702` pass `_effectiveMsgValue()`; `MultiVaultLib.sol:1427-1445` require `payment == Σ assets`; deposit uses `payment` as `assets`), and `Σ values == msg.value` (`MultiVault.sol:583`). Integration test: value out of the user equals value into MultiVault plus the curve, exactly.
- **Value on a non-consuming leg**: `requiresZeroValue` on `redeem`, `redeemBatch`, `approve` (`MultiVault.sol:518, 709, 724`) reverts `MultiVault_UnexpectedValue` (test).
- **Re-entry while the transient context is live** (redeem payout re-enters a payable path or nests a batch): every payable entry is `nonReentrant` and `multicall` rejects nesting (`MultiVault.sol:572`); the reproduced attempt failed on both (test). Transient writes revert with their frame, so a caught failing batch cannot leak `_inMulticall`.
- **FeeProxy recipient acts before the user's operation (5.2 regression)**: `_payAffiliate` runs after the MultiVault call on all five routes (`FeeProxy.sol:276, 308, 337, 367, 412`) and the refund runs last; hostile-recipient test: the user's shares equal the pre-call preview, FeeProxy re-entry is blocked.
- **FeeProxy lets a third party open lots for a receiver who only approved the proxy**: `_assertDepositReceiverApproved` also requires the receiver's approval of the caller (`FeeProxy.sol:679-681`); reverts `FeeProxy_ReceiverNotApproved` (test).
- **FeeProxy strands or double-spends value**: `msg.value - gross` is refunded, fee + forwarded == gross, `_allocate` sums exactly (`FeeProxy.sol:787-805`); `receive()` accepts only MultiVault or self (`:542-546`), and MultiVault never pays the proxy because the proxy can never hold shares (nobody can make it a deposit receiver).
- **Hook-bearing default curve (5.6 regression)**: `_assertDefaultCurveIsHookless` on both write paths (`MultiVault.sol:330, 824, 843-850`).
- **Reinitializers front-run or re-run**: `MultiVault.reinitialize` is `onlyRole(DEFAULT_ADMIN_ROLE) reinitializer(2)` (`:337`); `AtomWarden.reinitialize` is `reinitializer(2)` gated to MultiVault's `generalConfig.admin` (`AtomWarden.sol:230-234`); neither proxy ever consumed version 2 (git history: only Trust and an early TrustBonding used `reinitializer(2)`).
- **AtomWarden exploitable between step 02 and step 04**: no role holders, `claimWindow == 0` (creator path off), `signatureThreshold == 0` but no `SIGNER_ROLE` holder, so `_verifyQuorum` rejects every signature (`AtomWarden.sol:604-609`); only the legitimate address-atom path is live.
- **Storage layouts**: MultiVault (repo layout tests 14/14 pass), AtomWallet (`forge inspect`: `_primaryOwner` at slot 3, gap 49), AtomWarden (v1.0.2 used only slot 0), TrustBonding/VotingEscrow (no state change since v1.0.2).
- **Positions opened under v1.0.2 on curves 1 and 2**: the upgraded curves report `false` on both hook getters (`BaseCurve.sol:153-160`), so deposit and redeem math is unchanged against v1.0.2 (`git show v1.0.2` `_processDeposit`/`_processRedeem`/`_calculateRedeem` compared line by line).

## Below threshold

- Rebase floors can over-credit up to 1 wei per lot lifetime (`DynamicFeeFlatPriceCurve.sol:772-779, 1172`); accumulator dust dominates (observed surplus 1.3e8 wei, over-credit 0); worst case the last claimer is a few wei short until any fee or a force-feed arrives.
- `lastSystemUtilizationEpoch` is 0 until step 03 (`MultiVault.sol:337-343`, `MultiVaultLib.sol:1251-1264`); if the first action of an epoch lands after step 02 and before step 03 (for example step 03 slips past 2026-11-03 15:00 UTC, or the runbook's own verification deposit is the first action of a fresh epoch), that epoch's system utilization is carried from epoch 0, distorting one epoch's emission ratio within [40%, 100%]. Fall back to `currentEpoch - 1` when the slot is 0, or send steps 02 and 03 as one Safe MultiSend.
- Between steps 02 and 03 nobody holds MultiVault `PAUSER_ROLE` (`MultiVault.sol:759`), so the "pause after step 02" rollback needs an extra `grantRole` first.
- A redeem whose fees reach its gross value now reverts `MultiVault_RedeemYieldsNoAssets` (`MultiVaultLib.sol:1158-1161`); positions of about 1-3 wei can no longer be exited (v1.0.2 paid 0).
- Opposite-triple seeding adds `minShare` at the empty-curve price to a possibly non-empty vault (`MultiVaultLib.sol:1350-1366`); on OffsetProgressiveCurve this under-collateralizes by about 1e11 wei at `minShare = 1e6`; pre-existing in v1.0.2, and in v1.1.0 also reachable from a counter-first deposit on migrated terms.
- An affiliate that sets `feeRecipient = FeeProxy` leaves its own fee untracked in the proxy (`FeeProxy.sol:543, 753`); self-harm only.
- Exit-slice reroutes cost O(lots × tierCount); bounded at 16 tiers, but an owner raising `tierCount` toward 64 grows redeem gas quadratically (`DynamicFeeFlatPriceCurve.sol:956-974`).
- The curve owner at launch is the Admin Safe directly, so `setConfig` on a live ladder has no timelock delay (bounded by the immutable ceilings at `:117, :124`); the NatSpec at `:54` describes a timelock owner.
- The deposit quote walks the gross range while the record replays the net range (`:1036-1040, :1554-1583`); near an edge a slice of fee priced at band k+1 can be distributed from band k. Wei-scale.
- `previewRedeem` is account-agnostic for hook curves (documented on the interface).

## Rubric scorecard

| Item | Verdict | Evidence (`file:line`) and refutation attempted |
| --- | --- | --- |
| 1.1 CEI | PASS | Curve claim/sweep zero before send (`DynamicFeeFlatPriceCurve.sol:559-560, 395-396`); MultiVault records the curve hook before the payout (`MultiVaultLib.sol:884-892`). `_removeUtilization` runs after the payout (`MultiVaultLib.sol:322-323`), guarded by `nonReentrant`; re-entry from the payout failed (integration test). |
| 1.2 Reentrancy guards | PASS | All MultiVault write paths (`MultiVault.sol:633-725`), curve hooks/claim/sweep (`:464, :499, :545, :391`), FeeProxy routes (`FeeProxy.sol:259-383`). Re-entry from the redeem payout and from the affiliate recipient tested. |
| 1.3 Read-only reentrancy | PASS | During the redeem payout utilization still shows pre-redeem values, but TrustBonding reads only closed epochs (`TrustBonding.sol:615-616`); curve state is final before the payout. |
| 1.4 Cross-function/contract | PASS | The transient multicall context cannot be reached by a re-entrant direct call (`MultiVault.sol:572, 610-612` plus guards); `test_multicall_reentrantHolder_cannotSpendBatchValue`. |
| 1.5 Token callbacks | N/A | Native TRUST only on the funds paths; AtomWallet `Receiver` fallback carries no value logic. |
| 2.1 Admin modifiers | PASS | Curve `onlyOwner` (`:348, :371, :383, :391`), MultiVault `onlyTimelock` (`MultiVault.sol:769-870`), FeeProxy roles (`FeeProxy.sol:190-475`), AtomWarden roles. |
| 2.2 Unauthenticated entrypoints | PASS | Curve hooks `onlyMultiVault` (`:283-291`); AtomWarden user paths check the claimant (`AtomWarden.sol:262-280, 296, 343-348`); third-party FeeProxy routing tried and reverts. |
| 2.3 No loosening | PASS | Setters moved behind the timelock; pause moved to a dedicated `PAUSER_ROLE` (`MultiVault.sol:759`). |
| 2.4 Multisig/timelock assumptions | PASS | All privileged actions remain on the 4-of-8 Safe or its timelocks; curve owner is the Safe without delay (below threshold). |
| 2.5 Initializers | PASS | `_disableInitializers` in every implementation; reinitializers gated (`MultiVault.sol:337`, `AtomWarden.sol:230-234`); windows between steps checked (no exploitable state). |
| 3.1 SafeERC20 | PASS | `VotingEscrow.sol:353, 491`. |
| 3.2 Fee-on-transfer | N/A | Native TRUST; WTRUST is a plain wrapper. |
| 3.3 Rebasing | N/A | None. |
| 3.4 Decimals / unit coupling | PASS | Hook-curve vault stays exactly 1:1 (`LinearCurve.sol:156-173`, `MultiVaultLib.sol:1183-1188, 1295-1296`); par asserted in every integration test. |
| 3.5 Conservation | PASS | Per-op liabilities never exceeded the fee received (Lane2CurveSequences); multicall value conserved exactly (integration). |
| 3.6 `address(this).balance` | PASS | Curve and FeeProxy account by ledger; force-fed value only adds surplus. |
| 4.x Oracles | N/A | No oracle in scope. |
| 5.1 Rounding direction | PASS | Fee quotes round up (`:806, :1569, :1572`); credits floor (`:1264, :1388`); 1-wei-per-lot rebase residue below threshold. |
| 5.2 Precision | PASS | `fullMulDiv` throughout the spread (`:1386-1388, :1440`). |
| 5.3 `unchecked` | PASS | Loop counters only, plus `_burn` after its balance check (`MultiVaultLib.sol:1404-1412`). |
| 5.4 Casting | PASS | `uint16(segments)` bounded by 150 (`AtomWarden.sol:623`); `uint48(block.timestamp)` (`MultiVaultLib.sol:636`). |
| 5.5 Dust / zero | PASS | Dust deposits and 1-wei redeems exercised in random runs; dust exits blocked (below threshold). |
| 6.1 Layout preserved | PASS (layout) | MultiVault tests 14/14; AtomWallet slot 3 = old gap; AtomWarden appended. The semantic carry-over of a v1.0.2 claim is broken: see F-01. |
| 6.2 Immutable/constructor under proxy | PASS | Only constants and `_disableInitializers`. |
| 6.3 Append-only | PASS | As 6.1. |
| 6.4 Upgrade authorization | PASS | ProxyAdmins and the beacon are owned by the Upgrades Timelock (runbook §1). |
| 7.x Cross-chain | N/A | Intuition-chain only. |
| 8.1 Slippage | PASS | `minShares`/`minAssets` (`MultiVaultLib.sol:1447-1501`), `FeeGuard` (`FeeProxy.sol:716-726`); FeeProxy test passes the pre-call preview as `minShares`. |
| 8.2 First depositor | PASS | Ghost shares on every new vault (`MultiVaultLib.sol:1280-1305`); flat price. |
| 8.3 Donation | PASS | Vault totals are ledger-only; fee routing only to the default vault. |
| 8.4 Liquidation | N/A | None. |
| 8.5 Accrual before reads | PASS | Settle before every stake change (`DynamicFeeFlatPriceCurve.sol:510, 1161-1165`). |
| 8.6 Flash-capital invariance | PASS | Per-share ceilings and exiter exclusion hold for any amount (random runs up to 126k TRUST per deposit). |
| 8.7 MEV | PASS | Single sequencer, no public mempool; the 5.2 ordering removes the in-tx recipient window. |
| 9.1 Pause | PASS | MultiVault pause blocks deposit and redeem (pre-existing design); TrustBonding `withdraw` ungated (`VotingEscrow.sol:497`); curve claim never paused. |
| 9.2 Circuit breakers | N/A | Not introduced by this release. |
| 9.3 Sweep | PASS | Curve sweep pays only `protocolAccrued` (`:393`). |
| 10.1 Approval race | N/A | MultiVault approvals are set, not incremented. |
| 10.2 Infinite approvals by protocol | PASS | None granted by protocol contracts. |
| 10.3 EIP-712 | PASS | AtomWarden domain v2 + per-claimant nonce + validity window (`AtomWarden.sol:42-44, 305-309, 653-671`); AtomWallet replay-safe hash binds chain and wallet (`AtomWallet.sol:396-403`). |
| 10.4 `ecrecover` | PASS | OZ `tryRecover` with error check (`AtomWarden.sol:599-603`); solady `SignatureCheckerLib`. |
| 11.1 Tests + invariants | PASS (scoped) | Ran repo DynamicFeeInvariant (4/4) and v1.1.0 layout suites (14/14) with capped runs; full suite not run, by instruction. |
| 11.2 Mutation check | N/A | No fix authored in this lane. |
| 11.3 Counterexamples captured | N/A | No counterexample found in the curve. |
| 11.4 Fork test for live state | FAIL | Fork regressions exist but none models a wallet claimed under v1.0.2 (F-01). Not run here (network). |
| 11.5 Static analysis | N/A | Not run in this lane. |
| 12 Must-not-change scan | PASS | No guard removed, no layout reorder, no unproven `unchecked`, no widened access, no oracle use. |

## PoC inventory

All files are under `tests/scratch/` in the worktree. Every command was `FOUNDRY_PROFILE=test FOUNDRY_FUZZ_RUNS=32 FOUNDRY_INVARIANT_RUNS=8 FOUNDRY_INVARIANT_DEPTH=128 forge test --match-path '<file>' -vv`.

| File | Purpose | Result |
| --- | --- | --- |
| `tests/scratch/LegacyAtomWalletV102.sol` | Verbatim `git show v1.0.2:src/protocol/wallet/AtomWallet.sol`, contract renamed (support) | compiles |
| `tests/scratch/Lane2LegacyClaimedWallet.t.sol` | F-01 reproduction plus pending-only control | 2 passed (`test_preUpgradeClaimedWallet_isBrickedByBeaconSwap`, `test_control_pendingOnlyWallet_stillClaimableAfterUpgrade`) |
| `tests/scratch/Lane2CurveSequences.t.sol` | Launch-schedule random sequences: lot ledger, vault stake, per-op conservation, exiter non-self-payment, solvency, drain | 2 passed (fuzz 32 runs; long run: 778 deposits, 410 redeems, 203 claims, max over-credit 0 wei, surplus 132,962,882 wei) |
| `tests/scratch/DynamicFeeFlatPriceCurvePreGas.sol` | Curve at `52b206f`, contract renamed (support) | compiles |
| `tests/scratch/Lane2GasPassDifferential.t.sol` | `a7f6d9f` differential over 4 configs | 1 passed (fuzz 32 runs, all state identical every step) |
| `tests/scratch/Lane2CurveReplays.t.sol` | 5.1 and 5.3 replays, dust seats across the ladder | 3 passed (dust seat 0 wei; 5.3 redeem fee 288.1 TRUST all to bucket; farmer 0 wei vs honest 3,149.8 TRUST) |
| `tests/scratch/Lane2Integration.t.sol` | Real MultiVault + FeeProxy: multicall value, value on a redeem leg, re-entrant holder, hostile affiliate recipient, third-party routing, create-then-deposit batch | 6 passed |

Confirmation runs of existing suites: `--match-path 'tests/unit/upgrades/v1.1.0/MultiVault{StorageLayout,ConfigSlotAnchors}.t.sol'` 14 passed; `--match-path 'tests/unit/MultiVault/DynamicFeeInvariant.t.sol'` 4 passed (8 runs × 128 depth). One `forge inspect AtomWallet storageLayout` ran without the test profile (read-only, no test execution).

## Verdict

VERDICT: FAIL

The curve rewrite, the gas pass, multicall value accounting and the FeeProxy reordering held against every hypothesis tried; random-sequence, differential and replay PoCs found no above-threshold defect there. The one reproduced Medium is an upgrade-path gap: any AtomWallet that completes the still-live v1.0.2 two-step claim before step 02 loses its owner at the beacon swap and locks its balance and accrued fees until another upgrade. A permissionless legacy-owner migration in AtomWallet, or a hard pre-flight check that `isClaimed() == false` for every deployed wallet right before step 02, closes it.
