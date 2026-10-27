# Round 4 — isolated adversarial lane — Claude Fable 5.1

> **Lane:** isolated adversarial review, Claude Fable 5.1 via the Agent tool (model pinned; reasoning effort inherited from the orchestrating session), in its own detached worktree at public `ea6c239` with its own build. **Brief:** the identical round-4 lane brief (scope, five priorities, trust model, launch schedule, risk threshold, stop condition, the auditor's final report as text, the PR description, the funds-touching rubric, the accepted-behaviour list); no prior internal report and no other lane's output. **Proofs of concept:** 21 tests under a gitignored scratch directory, rerun by the orchestrator with the same result (21/21), including the mainnet-fork reproduction of its finding. **Interruptions:** paused once externally and resumed with context intact. **Output below is verbatim.** Dispositions are in the master report (§6: `R4-01`, `R4-02`, below-threshold notes).

---

# Adversarial review lane report: Intuition v1.1.0 core upgrade, pass 4

## Lane

- Model: Fable 5.1 (`claude-fable-5-1`), running as an isolated review lane.
- Worktree: `<lane worktree>`
- Commit: `ea6c239` (`ea6c23985a3d6f12e1e6b22b29836b3c450ac852`, head of PR #158).
- Date: 2026-10-08 (report written 21:45 UTC).
- Time spent: about 3.5 hours wall time, one external pause.
- REVIEW-ROUND: 1. RISK-THRESHOLD and STOP-CONDITION as in the brief.

## Scope read

| Path | Read in full | Attacked hardest |
| --- | --- | --- |
| `src/protocol/curves/DynamicFeeFlatPriceCurve.sol` (1,681) | yes | lot ledger consistency, exiter exclusion and re-base, the fill-capped single-target credits, `_payFulcrumTiers` normaliser `max(Σe, Σw)`, net-anchored quote vs replay, `_unwindLots` termination, solvency |
| `src/protocol/curves/BaseCurve.sol` | yes | hookless defaults, `_checkRedeem` bounds for 1:1 |
| `src/libraries/MultiVaultLib.sol` (1,726) | yes | `CurveHook` carry (netted == forwarded), par invariant on hook-curve vaults, every `_mint`/`_burn` site vs the curve ledger, `_validatePayment`, `_processRedeem` CEI |
| `src/protocol/MultiVault.sol` | yes | `multicall` transient allocation, `requiresZeroValue`, re-entry from a redeem payout, `reinitialize` gating, storage appends vs v1.0.2 |
| `src/protocol/MultiVaultCore.sol` | yes | slot order 0-25 vs v1.0.2, `_getAtomCost` 1:1 assumption |
| `src/periphery/FeeProxy.sol` | yes | post-5.2 ordering (recipient after routed call, refund last), `receive()`, `_allocate` dust, approval model |
| `src/protocol/wallet/AtomWarden.sol` | yes | `reinitialize` version and caller gate, quorum verification, claim paths for pre-upgrade wallets |
| `src/protocol/wallet/AtomWallet.sol` | yes | `owner()` / `completeClaim` for wallets that carry v1.0.2 state (**F-01**), storage slots vs v1.0.2 |
| `src/libraries/CoinbaseSmartWalletLib.sol` | yes | signature decode pinning, owner-index dispatch, `removeOwnerByAddress` |
| `src/protocol/emissions/TrustBonding.sol` | yes | pause gating vs `withdraw`, storage vs v1.0.2, APY reordering |
| `src/external/curve/VotingEscrow.sol` | yes | storage vs v1.0.2, `withdraw` always callable |
| `src/interfaces/IBaseCurve.sol` | yes | hook contract wording vs implementation |
| `src/interfaces/IDynamicFeeFlatPriceCurve.sol` | yes | config bounds and documented semantics vs code |
| `src/interfaces/IMultiVault.sol` | yes | approval semantics (5.4 wording), `previewRedeem` caveat |
| `src/interfaces/IMultiVaultCore.sol` | yes | struct slot counts for the layout mirror |
| `src/interfaces/IFeeProxy.sol` | yes | struct field order, documented refund/approval rules |
| `src/protocol/curves/LinearCurve.sol` | yes | exact 1:1 under equal totals (par proof) |
| `src/protocol/curves/BondingCurveRegistry.sol` | yes | append-only ids, `onlyValidCurveId` |
| `src/protocol/wallet/AtomWalletFactory.sol` | yes | address stability across the beacon swap |
| `script/intuition/v1.1.0/safe-txs/execution-order.md` | yes | missing pre-flight for already-claimed wallets (F-01), step 02 to 03 window |
| `script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol` | yes | reinit defaults, atomic curve batch |
| `script/intuition/DynamicFeeLaunchSchedule.sol` | yes | used as the PoC schedule |
| `tests/unit/upgrades/v1.1.0/MultiVaultStorageLayout.t.sol`, `AtomWardenUpgradeRegression.t.sol` | yes | what they pin and what they miss (no claimed-wallet case) |
| `tests/unit/MultiVault/DynamicFeeCurveRouting.t.sol`, `tests/unit/curves/DynamicFeeFlatPriceCurve.t.sol` (setUp + helpers, lines 1-420) | partial (harness only) | copied the harness pattern |
| v1.0.2 sources via `git show v1.0.2:` for `AtomWallet.sol`, `AtomWarden.sol`, `MultiVault.sol`, `MultiVaultCore.sol` (storage and claim sections) | partial | storage alignment and the pre-upgrade claim path |
| `lib/solady/src/utils/LibBit.sol` (`fls`), `FixedPointMathLib.sol` (`rpow`) | partial | `fls(0) == 256` sentinel, `rpow` overflow revert |
| `git show a7f6d9f -- src/` | yes (whole diff) | hunk-by-hunk behaviour equivalence |

Not read: anything under `audits/`.

## Findings

### F-01 Wallets claimed under v1.0.2 become ownerless and inoperable after the AtomWallet beacon swap

- **Severity:** Medium (bounded loss, conditional on a pre-upgrade claim; recoverable only by a further 7-day-timelocked beacon upgrade). If any such wallet exists at execution time the impact is a permanent lock of that wallet's balance and of the atom's entire future fee stream, which is High for that holder.
- **Confidence:** High. Reproduced on a mainnet fork against the live v1.0.2 code, and by storage emulation in the unit harness.
- **Affected code:**
  - `src/protocol/wallet/AtomWallet.sol:93-97` (`_primaryOwner`, new slot 3, zero for every pre-upgrade wallet), `:342-365` (`completeClaim` refuses `isClaimed`), `:432-434` (`owner()` returns `_primaryOwner` when claimed; never consults the ERC-7201 Ownable slot v1.0.2 wrote), `:512-531` (every operating gate requires a MultiOwnable owner, which `completeClaim` alone seeds).
  - `src/protocol/wallet/AtomWarden.sol:557-561` (`_requireWalletUnclaimed`: all four claim/grant paths refuse a claimed wallet).
  - `script/intuition/v1.1.0/safe-txs/execution-order.md` (no pre-flight check for claimed wallets; no mitigation).
  - v1.0.2 `AtomWarden.claimOwnershipOverAddressAtom` (permissionless, no pause) and v1.0.2 `AtomWallet.acceptOwnership` (sets `isClaimed = true`, writes `OwnableStorage._owner` at `0x9016…9300`).
- **Attacker sequence** (no attacker needed; any ordinary user before 2026-10-26, all permissionless on today's mainnet code):
  1. User `U` creates the atom whose data is `U`'s lowercase hex address (`createAtoms`, at the atom cost) and calls `AtomWalletFactory.deployAtomWallet(atomId)`.
  2. `U` calls `AtomWarden.claimOwnershipOverAddressAtom(atomId)` (v1.0.2), then `AtomWallet.acceptOwnership()` (v1.0.2). Now `isClaimed == true`, `owner() == U`, `U` can `execute`. Fees for the atom accrue to the wallet in `MultiVault.accumulatedAtomWalletDepositFees`.
  3. The Admin Safe executes step 02: `UpgradeableBeacon.upgradeTo(newAtomWalletImpl)`.
  4. The same wallet now has `owner() == address(0)`, `ownerCount() == 0`. `execute`, `executeBatch`, `addOwnerAddress`, `transferOwnership`, `claimAtomWalletDepositFees` revert for `U`. `AtomWarden.grantAtomWalletOwnership`, `claimWithAuthorization`, `claimAsCreatorAfterExpiry` and `claimOwnershipOverAddressAtom` all revert `AtomWarden_AlreadyClaimed`. Nothing in v1.1.0 reads the legacy owner slot.
- **Impact:** For every wallet claimed under v1.0.2 before the upgrade: the TRUST held by the wallet and the atom's accumulated and future atom-wallet deposit fees (`MultiVault.claimAtomWalletDepositFees` is callable only by the wallet itself, `MultiVault.sol:733-752`) are locked until another beacon implementation ships that reads the orphaned slot. The brief states no mainnet wallet is claimed today; the precondition is nonetheless open and permissionless for 18 more days and cannot be closed with v1.0.2's surface (no pause on the v1.0.2 warden). Testnet wallets claimed under v1.0.2 are affected by the same mechanism, which the testnet rehearsal should surface.
- **Reproduction:**
  - `tests/scratch/LegacyClaimFork.t.sol` (mainnet fork at the regression block 3,270,618, v1.0.2 live):
    `FOUNDRY_PROFILE=test FOUNDRY_FUZZ_RUNS=32 FOUNDRY_INVARIANT_RUNS=8 FOUNDRY_INVARIANT_DEPTH=128 forge test --match-path 'tests/scratch/LegacyClaimFork.t.sol' -vv`
    `[PASS] test_fork_v102ClaimedWallet_isBrickedByV110BeaconSwap() (gas: 3634835)` — asserts the v1.0.2 claim succeeds and `execute` works, then after the beacon swap `owner() == 0`, `ownerCount() == 0`, `execute` reverts `AtomWallet_OnlyOwnerOrEntryPoint`, `addOwnerAddress` reverts `AtomWallet_OnlyOwner`, and 0.9 TRUST stays in the wallet.
  - `tests/scratch/LegacyClaimedWalletBrick.t.sol` (unit harness, emulates the v1.0.2 post-claim storage on a v1.1.0 wallet; includes a control showing an unclaimed pre-upgrade wallet claims normally):
    `… forge test --match-path 'tests/scratch/LegacyClaimedWalletBrick.t.sol' -vv`
    `[PASS] test_legacyClaimedWallet_isBrickedUnderV110() (gas: 845726)`, `[PASS] test_control_unclaimedLegacyWallet_claimsNormally() (gas: 826791)`.
- **Recommendation (smallest fix, pick one or both):**
  1. Code: add a permissionless one-shot `migrateLegacyOwner()` to `AtomWallet` that requires `isClaimed && _primaryOwner == address(0)`, reads the v1.0.2 `OwnableStorage._owner` slot (`0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300`), requires it non-zero and not the warden, sets `_primaryOwner` and `CoinbaseSmartWalletLib.addOwnerAddress(legacy)`, and emits `ClaimCompleted`. It restores exactly what the orphaned slot says and nothing else. Ship it in the same beacon implementation (bytecode change; re-run the AtomWallet regression set).
  2. Operations, if the bytecode must not change: (a) add to `execution-order.md` step 02 pre-flight a scan of every deployed AtomWallet for `isClaimed() == true` (or of `OwnershipTransferred` logs from wallet addresses) at the execution block, and stop if any is found; (b) close the window now by pointing the v1.0.2 warden away from the live MultiVault (`AtomWarden.setMultiVault`, owner-only) so `claimOwnershipOverAddressAtom` reverts on `isAtom` until the upgrade, then let `reinitialize`/`setMultiVault` restore it. (b) is a product decision; (a) alone cannot prevent a claim landing between the scan and execution on a chain where the claim path cannot be paused.
- **Variant analysis:** single-call: n/a; batch/multicall: n/a; preview: `owner()` already reads `address(0)` post-swap; FeeProxy route: not involved; upgrade path: this is the upgrade path. Unclaimed pre-upgrade wallets are unaffected (control test, and `tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol:266-299` deploys wallets pre-upgrade and claims them post-upgrade). Wallets claimed post-upgrade are unaffected.

No other above-threshold finding was reproduced. Every other candidate was refuted or sits below threshold (sections below).

## Refuted hypotheses

Priority 1, the curve (launch schedule unless stated; all checks in `tests/scratch/CurveAdversarial.t.sol`):

- Lot ledger desync (`userStake != Σ lots`, `tierStake[t] != Σ lots at t`, mask bit set over a zero lot) under multi-wallet drawdowns that over-fill a tier and under a 24-step random sequence across 4 actors: refuted. `_applyDepositBand` sets the bit only when the lot was zero and lands stake in lot, tier and user in one block (`DynamicFeeFlatPriceCurve.sol:1156-1174`); `_unwindLots` debits lot, tier and clears the bit at zero before any distribution (`:829-853`). Asserted after every step of `test_overfullTier_ledgerSolvencyAndCeilings` and `testFuzz_randomSequence_ledgerSolvencyCeiling`.
- `_unwindLots` runs out of lots (would read tier 256 via `fls(0)` and overrun the arrays): refuted. `userStake -= shares` reverts first (`:829`) and `userStake == Σ lots` holds (above), so `remaining` is exhausted before the mask is.
- Exiter paid out of its own redeem fee on any tier (partial and full exits, residual lots at several tiers): refuted. `_settle` banks pending before the unwind (`:510`), every denominator subtracts the exiter's residual lot (`:945`, `:984`, `:1001`, `:1433`), and `_rebaseLots` re-bases every residual lot after the distributions (`:534`, `:786-793`). `claimableAcross(exiter)` unchanged across every exit in the PoC.
- Schedule-rate ceiling: a dust seat (1 wei) in a band the vault moved past, or an over-full tier, earns more per share than the schedule: refuted. Single-target credits cap at `amount * stake / width` (`:1262`), the spread's per-share rate is `pool * w / (width * D)` with `D >= Σw` (`:1351-1361`, `:1419-1451`). Checked kernel-tight on both legs (`_depositCeiling`, `_redeemCeiling`) and with the universal bound `Δacc_t <= fee / width_t` after every fuzz step. The dust seat earned at most 5 wei from 23 TRUST of fees.
- Cohort fallback and exit slice double-pay the same tier above the schedule when the vault sits in tier 0: refuted. Both are capped at fill and together stay within `fee / width0` (`test_tierZeroExit_cohortCappedAtFill`, conservation to 2 wei against `protocolAccrued`).
- Solvency: `balance < protocolAccrued + Σ claimable` after random sequences and after every actor claims and the owner sweeps: refuted (asserted at every step; `claim` and `sweepProtocol` complete). Residual rounding is discussed under "Below threshold".
- Quote vs execution disagreement on redeem for multi-lot positions: refuted. `_lotRedeemFee` (`:799-813`) and `_unwindLots` (`:836-852`) walk the same mask highest-first with the same `min(lot, remaining)` take; MultiVault quotes once and forwards the same value (`MultiVaultLib.sol:1147-1150`, `:942-945`). Pinned per lot in `test_multiLotRedeemQuote_matchesPerLotRates`.
- Deposit-leg split beats lump (5.3's deposit half): refuted at the launch schedule. A 9,000-net lump and the same four bands in four legs produce identical lots and fees equal to within the per-band round-up (`test_depositSplitNeutrality_lotsAndFee`; `:1554-1583` net-anchored walk).
- `setConfig` on a live ladder stranding a lot above the schedule or bricking `tierOf`: refuted. `tierCount` is grow-only (`:1613-1615`), the top edge is probed under the stored schedule so an overflowing ladder is rejected before commit (`:1661-1666`), and every walk is bounded by `tierCount <= 64`.
- Floor (`minEligibleTierStakeBps != 0`) admitting a tier in one gate and dropping it in another: refuted. `_creditEligibleCapped` applies exactly `_isEligibleStake` (`:1258-1261` vs `:1232-1237`); a sub-floor tier is skipped by the spike walk, the exit-slice reroute, the cohort fallback and the spread alike, and the whole fee accrues (`test_floor_ineligibleTiersSkippedByEveryGate`).
- Accumulator overflow by inflating `accFeePerShare` against a 1-wei tier: refuted. Reaching `acc > 2^256 / lot` needs `paid / stake > 1e32`, i.e. about 1e14 TRUST against a 1-wei seat; all products use 512-bit `fullMulDiv`.
- Division by zero in `_creditByWeight` or `_creditEligibleCapped`: refuted. `weights[i] > 0` implies `stakes[i] > 0` (`:1437-1441`), `lastStake` is set only when `e > 0` (`:1391-1392`), and `recipientStake == 0` returns early (`:1258`).
- A path that changes hook-curve share balances without a hook call (ledger desync): refuted. The only `_mint`/`_burn` sites are creation (default curve only, guarded by `_assertDefaultCurveIsHookless`, `MultiVault.sol:843-850`), `_updateVaultOnDeposit`/`_updateVaultOnCreation` followed by `_recordCurveDeposit` (`MultiVaultLib.sol:829-845`), `_updateVaultOnRedeem` followed by `_recordCurveRedeem` (`:884-890`), and `BURN_ADDRESS` seeds that can never redeem (`:1302`, `:1365`, `:1491-1494`).
- Hook-curve vault drifting off par so that `vaultStake` (shares) and the asset ladder disagree: refuted by induction. Entry/exit fees and atom fractions go only to `defaultCurveId` vaults (`MultiVaultLib.sol:1183-1188`), the seed is minted 1:1 (`:1295-1296`, `LinearCurve.sol:91-101`), and `LinearCurve._convertToShares/_convertToAssets` are exact when totals are equal (`LinearCurve.sol:156-173`). Pinned by `tests/unit/MultiVault/DynamicFeeCurveRouting.t.sol` par tests.

Priority 2, commit `a7f6d9f`:

- Behaviour change in any branch: refuted hunk by hunk. (1) `_rebaseLots` now takes the mask `_unwindLots` wrote; no code between `:512` and `:534` writes `lotMask`, so it equals the storage read it replaced. (2) `_distributeLotFees` caches `weights[i]`; same values, same remainder branch. (3) `_creditEligibleCapped` returns `(amount, false)` exactly when `_isEligibleStake` returned false (zero stake, or floor set and stake below it) and otherwise performs the old `_creditCapped`; the `RedeemFeeRerouted` event fires only when eligible with the same `amount - unpaid`. (4) `_creditLotCohorts` and `_creditDownward` collapse the old `if (_isEligibleStake) _creditCapped` into the same call. Exercised with the floor on and off in the PoC.

Priority 3, multicall value accounting (`tests/scratch/MulticallValue.t.sol`):

- A leg spends another leg's value or value is stranded in a mixed `createAtoms + deposit(hook curve) + approve + redeem` batch: refuted. MultiVault's balance moves by exactly `msg.value - curveFee - payout`, the depositor's by `-msg.value + payout`, the curve's by `curveFee`. Each payable entry consumes exactly `_effectiveMsgValue()` (`MultiVault.sol:610-612`): `deposit` uses it as `assets`, `createAtoms`/`depositBatch` require `Σ assets == payment` (`MultiVaultLib.sol:1427-1445`).
- Redeem leg with a non-zero allocation, or a direct `redeem{value}`: refuted, both revert `MultiVault_UnexpectedValue` (`MultiVault.sol:289-292`, `:614-617`).
- Zero-allocation deposit leg, over-allocated create leg, allocation sum mismatch, nested multicall: refuted (`MultiVault_DepositBelowMinimumDeposit`, `MultiVault_InsufficientBalance`, `MultiVault_MulticallValueMismatch`, `MultiVault_NestedMulticall`).
- Re-entry from a redeem leg's payout into `multicall`, `deposit` or `approve` while the batch is live: refuted. `_inMulticall` rejects nesting (`:572`), and every other write entry carries `nonReentrant`, which is shared across the delegatecalls because storage is the proxy's (`:684-726`). Verified by a contract receiver that attempted all three.
- Transient flags left set after a batch: refuted. Cleared at `:602-603`; any leg revert unwinds the whole transaction.

Priority 4, FeeProxy (`tests/scratch/FeeProxyAdversarial.t.sol`):

- Fee recipient repricing or re-gating the user's operation after the 5.2 fix: refuted. `_payAffiliate` runs after the routed call on all five routes (`FeeProxy.sol:276`, `:308`, `:337`, `:367`, `:412`); shares equal the pre-call preview; the recipient's re-entry into `depositVia` hits `ReentrancyGuardReentrantCall`; its `updateAffiliateFees` only affects later calls, where the caller's `FeeGuard` rejects it (`:716-726`).
- Refund tampering or stranded value: refuted. `_refundExcess` is last with a fixed amount (`:277`, `:760-767`); a reverting receiver is credited to `pendingRefund` and recovers via `claimRefundTo`, which refuses the proxy itself (`:431-437`). Proxy balance is zero after every successful route.
- Delegated receiver griefing (5.4 via the proxy): refuted. `_assertDepositReceiverApproved` requires the receiver's approval of both the proxy and the caller (`:672-682`).
- `_allocate` starving or overflowing a leg: refuted. Zero legs are rejected (`:772-781`), dust goes to the last leg which is provably positive (`:787-805`).
- `receive()` as a value sink: refuted. Only `multiVault` or self may send (`:542-546`); MultiVault never sends to the proxy on any route (it never redeems through it).

Priority 5, upgrade-time effects:

- MultiVault storage shifted by the library mirror or the new fields: refuted. v1.0.2 ends at slot 33 (`hasRolledOverSystemUtilization`); v1.1.0 appends 34-38 and a 46-slot gap (`MultiVault.sol:144-167`), mirrored at `MultiVaultLib.sol:93-149`; OZ parents are ERC-7201. Pinned by `tests/unit/upgrades/v1.1.0/MultiVaultStorageLayout.t.sol`.
- AtomWarden `reinitializer(2)` rejected on mainnet (proxy already past version 1): refuted. v1.0.2 used `initializer` only; `tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol::test_reinitialize_bootstrapsQuorumStateAndPreservesMultiVault` passes on the mainnet fork (run in this lane). `reinitialize` is caller-gated to `generalConfig.admin` (`AtomWarden.sol:231-234`), so it cannot be front-run.
- MultiVault `reinitializer(2)` rejected: refuted. v1.0.2 has no reinitializer; `MultiVaultUpgradeRegression.t.sol:187-197` pins single use on the fork.
- Pre-upgrade (unclaimed) wallets cannot be claimed post-upgrade: refuted. Slots 0-2 are identical in both layouts (`isClaimed` at slot 1 offset 20), `_primaryOwner` lands on the old `__gap[0]`, MultiOwnable storage is empty, so `completeClaim` proceeds (control test; regression `:266-299`).
- Signed claims possible in the window between step 02 and step 04: refuted. `signatureThreshold == 0` makes `segments < threshold` vacuous, but every segment must recover to a `SIGNER_ROLE` holder (`AtomWarden.sol:607`) and AccessControl storage is fresh. Creator fallback is disabled while `claimWindow == 0` (`:336-338`).
- Existing LinearCurve/OffsetProgressiveCurve positions routed through hooks: refuted. `hasDepositFeeHook`/`hasRedeemFeeHook` default false (`BaseCurve.sol:153-160`), the atomic batch upgrades both curve implementations, and the hook-curve id is registered only later.
- `timelock == address(0)` between steps 02 and 03 letting anyone call the setters: refuted. `onlyTimelock` compares to `address(0)`, which no caller is (`MultiVault.sol:952-954`).
- Wallet address drift from the beacon swap: refuted. `computeAtomWalletAddr` depends on the beacon address, not its implementation (`AtomWalletFactory.sol:137-173`; regression `:237-264`).

## Below threshold

- Rollover mis-seed window: if an epoch boundary falls between step 02 and step 03 and any deposit/redeem lands before `reinitialize`, `_rollover` carries `totalUtilization[0]` instead of the previous epoch (`MultiVaultLib.sol:1257-1263`, `lastSystemUtilizationEpoch == 0`), flooring that epoch's system utilization ratio at `systemUtilizationLowerBound`; bounded emissions shaping, no principal. Execute step 03 in the same epoch as step 02 (next boundary 2026-11-03 15:00 UTC).
- MasterChef floor rounding: `floor(lot * acc_new) - floor(lot * acc_old)` can over-credit up to 1 wei per lot re-base, while each credit leaves up to `stake / 1e18` wei unattributed; net effect is sub-wei per event and solvency held in every run.
- Deposit quote is blind to MultiVault's own fees: the quote walk advances by `chunk - curveFee` while the vault advances by `chunk - mvFees - curveFee`, so a lump is charged the next band's rate about 2.25% early (about 0.3% of the curve fee on a 100k deposit); protocol-favouring, documented at `:1545-1550`.
- Sweep self-recovery magnitude at launch: a lone 10,000 TRUST depositor from empty pays 170.35 TRUST of curve fee and immediately holds 149.99 claimable (88%), 20.37 to the protocol (band 0). Accepted by the owners; quantified in `test_quantify_sweepSelfRecovery_loneWhale`.
- A 1-wei (dust) redeem reverts `MultiVault_RedeemYieldsNoAssets` because three fees each round up to 1 wei; a holder with a 1-wei position cannot exit it. Negligible.
- FeeProxy affiliate that sets `feeRecipient == FeeProxy` strands its own fees in the proxy via `receive()` self-acceptance (`FeeProxy.sol:542-546`); self-inflicted.
- Between step 02 and step 04 nobody holds AtomWarden `DEFAULT_ADMIN_ROLE`, so the warden cannot be paused in that window; claims by address remain possible, which is the intended function.
- `MultiVault.claimAtomWalletDepositFees` pre-claim would `sendValue` to AtomWarden, which has no `receive`; unreachable since only the wallet can call it and pre-claim wallets cannot be operated.
- `_creditByWeight` `exact` branch books the integer-division remainder (< span wei) to the last credited tier (`:1398-1401`); documented.
- Testnet: wallets claimed under v1.0.2 on testnet will be bricked by the same mechanism as F-01 during the rehearsal; treat that as the signal, not as noise.

## Rubric scorecard

1. Reentrancy and external calls
- CEI honoured: PASS. `MultiVaultLib.sol:884-892` burns and lowers totals, records the hook, then pays; curve `claim` zeroes before `sendValue` (`DynamicFeeFlatPriceCurve.sol:559-560`); FeeProxy pays and refunds after the routed call (`FeeProxy.sol:273-277`). Refutation attempted: re-entry from a redeem payout and from an affiliate recipient (PoCs).
- Guards on every untrusted write path: PASS. `MultiVault.sol:629-726` all `nonReentrant`; curve hooks and `claim` `nonReentrant` (`:459-465`, `:494-500`, `:545`); FeeProxy routes and refunds `nonReentrant` (`:251-437`). Refutation: `multicall` is unguarded by design and nesting is rejected (`:572`); tested.
- Read-only reentrancy: PASS. No view consumed mid-modification; `quoteRedeemFee`/`quoteDepositFee` are read before any state write and carried verbatim (`MultiVaultLib.sol:166-171`).
- Cross-function/contract: PASS. Shared guard across delegatecalls; curve guard blocks `recordDeposit` during `claim`. Tested.
- Callbacks/hooks: PASS. Native value only; `Receiver` fallback on AtomWallet is inert for value paths.

2. Access control
- Explicit modifiers: PASS. `MultiVault.sol:759-870`, `AtomWarden.sol:373-476`, curve `:348-398`, `FeeProxy.sol:190-209`, `:444-477`.
- No unauthenticated state change: PASS. `sweepAccumulatedProtocolFees` is permissionless by design with a fixed recipient (`MultiVault.sol:856-865`); `deployAtomWallet` permissionless by design.
- No loosening: PASS. `setBondingCurveConfig` gained a check (`:823-850`); AtomWarden moved from single owner to roles with a 4-of-8 admin.
- Two-step/timelock preserved: PASS. Parameters behind `onlyTimelock`; upgrades behind the Upgrades Timelock (`execution-order.md`).
- Initializers: PASS. `MultiVault.reinitialize` `onlyRole + reinitializer(2)` (`:337`), `AtomWarden.reinitialize` caller-gated (`:230-234`), curve and FeeProxy `initializer` with `_disableInitializers` constructors. Refutation: fork regression on both reinitializers.

3. Asset accounting
- SafeERC20: N/A (native). `VotingEscrow` uses SafeERC20 (`:56`), unchanged.
- Fee-on-transfer: N/A.
- Rebasing: N/A.
- Decimals: N/A (18 everywhere; curve ladder in wei).
- Internal vs actual balances: PASS. Netted == forwarded by dataflow (`MultiVaultLib.sol:1038-1044`, `:933-945`); curve ledger == vault shares (`DynamicFeeCurveRouting.t.sol`, PoC); every wei of a batch accounted (PoC).
- Native handling without exact-balance reliance: PASS. Nothing reads `address(this).balance` for logic; curve pays only credited amounts.

4. Oracles: N/A throughout.

5. Math, rounding, precision
- Rounding favours the pool: PASS. Fee quotes round up (`:806`, `:1572`), credits floor (`:1264`, `:1388`), payouts floor (`LinearCurve.sol:172`). Refutation: dust and 1-wei cases in PoC.
- No early division: PASS. 512-bit `fullMulDiv` on every weight and accumulator product (`:1386-1388`, `:1431-1441`).
- `unchecked` justified: PASS. `:849-851` loop index bounded by array length; `:1013-1016` `--k` guarded by `k > 0`; `AtomWarden.sol:318-320` nonce increment; `MultiVaultLib.sol:1409-1412` after an explicit balance check at `:1404`.
- Casts: PASS. `uint48(block.timestamp)` (`MultiVaultLib.sol:636`), `uint16(segments)` bounded by 150 (`AtomWarden.sol:620-623`), `uint64(block.timestamp)` (`FeeProxy.sol:179`).
- Dust/zero edges: PASS. `shares == 0` deposit path (`:473-477`), zero-weight remainder branches (`:896-900`, `:1123-1128`), zero-stake early returns (`:1258`). Refutation: dust seat and 1-wei tests.

6. Upgradeability and storage
- Layout preserved: PASS for MultiVault, MultiVaultCore, AtomWarden, TrustBonding, VotingEscrow, AtomWallet slots (compared to `git show v1.0.2:`; pinned by the layout tests). **FAIL for AtomWallet semantics**: the v1.0.2 owner lives in an ERC-7201 slot the new code never reads, so a claimed wallet's state is orphaned (F-01).
- No immutable/constructor misuse: PASS. Constructors only `_disableInitializers`.
- Append-only: PASS. `MultiVault.sol:144-167`, `AtomWarden.sol:69-134`, `AtomWallet.sol:97-103`.
- `_authorizeUpgrade` guarded: PASS. Transparent proxies with ProxyAdmins owned by the Upgrades Timelock; beacon owned by the timelock (`execution-order.md`, regression pranks `UPGRADES_TIMELOCK`).

7. Cross-chain: N/A (Intuition-chain-only release).

8. DeFi economic
- Slippage: PASS. `minShares` (`MultiVaultLib.sol:1457`), `minAssets` (`:1498`), `RedeemYieldsNoAssets` floor (`:1158-1161`), FeeProxy `FeeGuard` (`:716-726`).
- First depositor: PASS. Min-share seed on every new vault (`:1280-1305`); hook-curve ladder starts at 0 by design.
- Donation: PASS. Hook-curve vault never receives donated assets (`:1183-1188`); `vaultStake` counts recorded shares only.
- Liquidation: N/A.
- Index accrual order: PASS. `_settle` before every lot change (`:510`, `:1162`).
- Flash-loan invariance: PASS. Curve state is per-transaction-consistent; the lot model removes the average-tier ratchet (5.3). Refutation: adversarial drawdown sequences in PoC.
- MEV: MEDIUM exposure acknowledged (single sequencer, no public mempool); FeeProxy recipient ordering fixed (5.2) and verified.

9. Pausing and recovery
- Pause does not trap funds: PASS. `TrustBonding.withdraw` ungated (`:497-499`); curve `claim` has no pause (`:545`); FeeProxy `claimRefund` works while paused (`:426-437`); MultiVault pause blocks exits by design, reversible by admin.
- Circuit breakers: N/A (no single-tx drain surface beyond the existing one).
- Sweeps cannot touch user funds: PASS. `sweepProtocol` pays only `protocolAccrued` (`:391-398`); `sweepAccumulatedProtocolFees` only accrued protocol fees.

10. Approvals and signatures
- Approval race: N/A (bit-flag set, not an allowance).
- Infinite approvals: N/A.
- EIP-712 binding: PASS. Domain `("AtomWarden","2")` with chain id and contract (`AtomWarden.sol:187`, `:242`), nonce (`:305`), window (`:653-671`); AtomWallet ERC-1271 wraps in a wallet- and chain-bound domain (`AtomWallet.sol:396-403`; regression `:266-299`).
- `ecrecover` zero/malleability: PASS. `ECDSA.tryRecover` with error check and strictly ascending signers (`:599-605`); the library's non-unique encodings are pinned to canonical (`CoinbaseSmartWalletLib.sol:120-127`).

11. Verification gates
- Scoped tests pass: PASS. 14 scratch tests (13 local + 1 fork) and `tests/invariant/MultiVaultInvariants.t.sol` (4/4) under the capped settings.
- Mutation check: N/A for this lane (no fix in the diff); the fix for F-01 needs a regression that fails against `ea6c239` (the fork PoC is that test).
- Fuzz counterexamples captured: PASS (none found; the universal ceiling, ledger and solvency fuzz are in `CurveAdversarial.t.sol`).
- Fork test for the upgrade: PASS for the covered cases; **FAIL** for the uncovered claimed-wallet case (F-01, now covered by the scratch fork test).
- Static analysis: not run in this lane.

12. Must-not-change scan: no guard, modifier, bound or slippage check removed; no storage reordered; one new `unchecked` with a bounds argument; no access widened; events kept; no spot-price decisions. One "yes": an upgrade orphans state a live, permissionless pre-upgrade path can create (F-01).

## PoC inventory

All runs: `cd <worktree> && FOUNDRY_PROFILE=test FOUNDRY_FUZZ_RUNS=32 FOUNDRY_INVARIANT_RUNS=8 FOUNDRY_INVARIANT_DEPTH=128 forge test --match-path '<file>' -vv`

| File | Tests | Result |
| --- | --- | --- |
| `tests/scratch/LegacyClaimFork.t.sol` (mainnet fork, block 3,270,618) | `test_fork_v102ClaimedWallet_isBrickedByV110BeaconSwap` | PASS (defect reproduced) |
| `tests/scratch/LegacyClaimedWalletBrick.t.sol` | `test_legacyClaimedWallet_isBrickedUnderV110`, `test_control_unclaimedLegacyWallet_claimsNormally` | 2/2 PASS (defect reproduced; control clean) |
| `tests/scratch/CurveAdversarial.t.sol` | `test_overfullTier_ledgerSolvencyAndCeilings`, `test_dustSeatInVacantBand_earnsDust`, `test_tierZeroExit_cohortCappedAtFill`, `test_multiLotRedeemQuote_matchesPerLotRates`, `test_depositSplitNeutrality_lotsAndFee`, `test_quantify_sweepSelfRecovery_loneWhale`, `test_floor_ineligibleTiersSkippedByEveryGate`, `testFuzz_randomSequence_ledgerSolvencyCeiling` (32 runs) | 8/8 PASS (all refutations hold) |
| `tests/scratch/MulticallValue.t.sol` | 6 tests (mixed batch accounting, zero allocation, redeem with allocation, mismatch and nesting, excess create allocation, re-entry from payout) | 6/6 PASS (refutations hold) |
| `tests/scratch/FeeProxyAdversarial.t.sol` | 4 tests (recipient ordering and re-entry, refund fallback and `claimRefundTo`, delegated receiver approvals, batch allocation) | 4/4 PASS (refutations hold) |
| `tests/invariant/MultiVaultInvariants.t.sol` (existing, confirmation) | 4 invariants | 4/4 PASS |
| `tests/unit/upgrades/v1.1.0/AtomWardenUpgradeRegression.t.sol --match-test test_reinitialize_bootstrapsQuorumStateAndPreservesMultiVault` (existing, fork) | 1 | PASS |

No file outside `tests/scratch/` and this lane directory was modified. Neither the coverage command nor the whole suite was run.

## Verdict

VERDICT: FAIL

One reproduced, unresolved Medium on a funds path: the AtomWallet beacon swap leaves any wallet claimed under v1.0.2 ownerless and inoperable, locking its balance and the atom's fee stream, and the pre-upgrade claim path is permissionless and unpausable on today's mainnet code, so the precondition stays open until execution (F-01, reproduced on a mainnet fork). It is cheap to close: a one-shot legacy-owner migration in the new AtomWallet implementation, or, without a bytecode change, repointing the v1.0.2 warden off the live MultiVault now plus a claimed-wallet scan in the step 02 pre-flight. Everything else in the five priorities, including the lot model, the occupancy-weighted spread, the a7f6d9f refactor, multicall value accounting, the FeeProxy ordering fix and the storage/reinitializer surface, was attacked with concrete sequences at the launch schedule and held; the verdict flips to PASS once F-01 is fixed or its precondition is verifiably closed at execution time.
