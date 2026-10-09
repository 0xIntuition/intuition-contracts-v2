# Round 4 — cold cross-model review — GPT-6 Astra (xhigh)

> **Lane:** cold cross-model review, read-only, OpenAI Codex CLI 0.161.0, model `gpt-6-astra`, reasoning effort `xhigh`. **Unit reviewed:** the full v1.1.0 contract set at public `ea6c239` plus the remediation delta `105fbe0..ea6c239`. **Prompt:** the project's cold PR-review prompt extended with the round-4 scope, priorities, trust model, threshold and accepted-behaviour list; no prior internal report and no other lane's output. **Attempts:** the first run exhausted the account's usage window after reading the sources once and produced no report; this is the second run, with a stated reading order. **Output below is verbatim.** Dispositions are in the master report (§6, R4-K-01 and R4-K-02).

---

## Verdict

- **Approve:** no
- **Blocking issues:** 1
- **Non-blocking issues:** 1
- **Summary:** At HEAD `ea6c23985a3d6f12e1e6b22b29836b3c450ac852`, permissionless `deposit_for` can spend another holder’s ERC-20 allowance and involuntarily lock their principal. This is pre-existing and explicitly documented in the source, but it is outside the accepted behaviours listed for this review. I also found a conditional utilization-migration defect; I found no additional blocker in the curve remediation, `a7f6d9f`, multicall accounting, or FeeProxy ordering.

This was source-only review: no Forge, execution tests, file changes, or formatting. Mainnet storage, allowances, deployed bytecode, and Safe payloads were **not verified**.

## Scope read

| Path | Read in full | Attacked hardest |
|---|---|---|
| `src/protocol/curves/DynamicFeeFlatPriceCurve.sol` | Yes | Lot conservation, fee ceilings, exclusion, fallbacks and claims |
| `src/interfaces/IDynamicFeeFlatPriceCurve.sol` | Yes | Claim and account-specific quote semantics |
| `src/interfaces/IBaseCurve.sol` | Yes | Hook accounting contract |
| `src/protocol/curves/BaseCurve.sol` | Yes | Hook defaults and arithmetic bounds |
| `src/protocol/curves/LinearCurve.sol` | Yes | Rounding and legacy-position compatibility |
| `src/libraries/MultiVaultLib.sol` | Yes | Storage mirror, value consumption and hook ordering |
| `src/protocol/MultiVault.sol` | Yes | Multicall context and upgrade initialization |
| `src/periphery/FeeProxy.sol` | Yes | Callback ordering, approvals and refund liabilities |
| `src/protocol/wallet/AtomWarden.sol` | Yes | Claim authorization before and after reinitialization |
| `src/protocol/wallet/AtomWallet.sol` | Yes | Legacy unclaimed-wallet storage and claim transition |
| `src/libraries/CoinbaseSmartWalletLib.sol` | Yes | Owner mutation and signature replay boundaries |
| `src/protocol/emissions/TrustBonding.sol` | Yes | Principal locking and utilization-dependent rewards |
| `src/external/curve/VotingEscrow.sol` | Yes | Transfer authorization, lock lifecycle and checkpoints |
| `src/protocol/MultiVaultCore.sol` | Yes | Inherited storage and configuration |
| `src/protocol/curves/BondingCurveRegistry.sol` | Yes | Registration privileges and curve dispatch |
| `src/protocol/wallet/AtomWalletFactory.sol` | Yes | Legacy wallet deployment and initialization |
| `src/protocol/curves/OffsetProgressiveCurve.sol` | Yes | Upgrade compatibility and rounding |
| `src/libraries/ProgressiveCurveMathLib.sol` | Yes | Directed rounding |
| `src/interfaces/IMultiVault.sol` | Yes | Payable surface and approval semantics |
| `src/interfaces/IMultiVaultCore.sol` | Yes | Storage-bearing configuration types |
| `src/interfaces/IAtomWallet.sol` | Yes | Claim and ownership surface |
| `src/interfaces/IAtomWalletFactory.sol` | Yes | Deployment assumptions |
| `src/interfaces/IAtomWarden.sol` | Yes | Authorization and administrative surface |
| `src/interfaces/IBondingCurveRegistry.sol` | Yes | Curve identity and dispatch |
| `src/interfaces/IFeeProxy.sol` | Yes | Fee guards and refund ownership |
| `src/interfaces/ITrustBonding.sol` | Yes | Reward and epoch semantics |
| `src/interfaces/ICoreEmissionsController.sol` | Yes | Epoch boundaries |
| `src/interfaces/ISatelliteEmissionsController.sol` | Yes | Reward-transfer authorization boundary |

Also reviewed the remediation changes since `105fbe01`, the complete `a7f6d9f` diff, launch schedule, PR description, final report, upgrade runbook and deployment script. The v1.0.2 comparisons covered wallet/warden sources and relevant storage, initialization and behavioural changes in the other upgraded implementations. This was not an independent audit of all vendored cryptographic primitives.

**Remediation conclusions:**

| Finding/change | Assessment |
|---|---|
| **5.1 — minimum-stake fee capture** | Closes the economic class: credits scale with occupancy, and the normalizer retains the scheduled weight of empty/ineligible tiers. The spike, reroute and fallback paths also apply occupancy caps. |
| **5.2 — affiliate callback before routing** | Closes the reported ordering class across the routing entry points: MultiVault executes before affiliate payment; excess refund follows payment. |
| **5.3 — sentinel/repositioning** | Closes the reported ratcheting class: deposits append tier-specific lots; partial redemption removes highest lots first instead of repricing the surviving position. |
| **5.4 — approved deposit changes receiver’s tier** | Closes repricing of existing stake. An approved sender can add new lots, but cannot move existing lots or rewrite their accumulated entitlement. |
| **5.5 — split-position recovery** | **Acknowledged**, rather than eliminated. The remaining redeem-side recovery is within the accepted behaviour; I found no materially larger path. |
| **5.6 — hook-bearing default curve** | Closes the configuration-entry class through initialization and setter checks. Existing hookless curves 1/2 satisfy the supplied migration assumptions. |
| **Carryover triple preview correction** | Uses the supplied atom identifiers when deciding the atom-deposit fraction, avoiding dependence on an as-yet-uninitialized triple mapping. |
| **`a7f6d9f`** | Behaviour-preserving in the branches reviewed: returned residual mask equals the mask just stored; cached rates cannot change between loops; merged eligibility/capping preserves zero-stake, floor-disabled, threshold and partial-credit outcomes. No intervening external call invalidates those equivalences. |

## Pending Comments Review

There are no pending PR comments or review threads, as supplied.

## New Findings

### 1. Permissionless `deposit_for` spends the victim’s allowance and locks their liquid principal

- **Severity:** blocking
- **Why it matters:** Anyone can force an existing lock holder’s approved ERC-20 balance into that holder’s lock without funding the deposit themselves or obtaining authorization from the holder. Withdrawal remains unavailable until the existing expiry, absent the privileged global unlock.
- **File:** `src/external/curve/VotingEscrow.sol:380`, specifically the transfer at `:353`; reachable through `src/protocol/emissions/TrustBonding.sol:453`. Withdrawal restriction: `src/external/curve/VotingEscrow.sol:479`.

**Attacker sequence:**

1. The victim has an active lock containing **100 tokens**, with **100 days remaining**, plus **10,000 liquid tokens** of TrustBonding’s configured ERC-20. Their allowance to TrustBonding is at least `10_000e18`.
2. The attacker calls `TrustBonding.deposit_for(victim, 10_000e18)`, supplying **zero tokens and zero native TRUST**, apart from gas.
3. The existing-lock checks pass. `_deposit_for` calls `safeTransferFrom(victim, address(this), 10_000e18)`, consuming the victim’s allowance.
4. The victim’s lock now contains **10,100 tokens** and their liquid balance has fallen by **10,000 tokens**. They cannot withdraw that added principal during the remaining 100 days.

The launch curve schedule and MultiVault’s 125/50/75/50-bps fees do not constrain this sequence: it calls TrustBonding directly. No public mempool or transaction sandwich is required.

- **Which invariant or check should have stopped it, and why it does not:** A third party must either fund a deposit itself or possess authorization to spend the holder’s funds. The function checks only a positive amount and an existing, unexpired lock; ERC-20 allowance authorizes **TrustBonding**, without authenticating the third-party caller. `whenNotPaused`, `nonReentrant` and `notUnlocked` do not provide that authorization.

**Provenance:** This behaviour already exists in v1.0.2 and is explicitly documented at `VotingEscrow.sol:369`. It is not introduced by PR #158. Nevertheless, it meets the requested principal-locking threshold and was not included in the accepted-risk list.

**Correction:** Make permissionless deposits caller-funded, or require holder authorization before pulling from `_addr`.

### 2. Reinitialization can select an empty epoch as the legacy utilization baseline

- **Severity:** non-blocking
- **Why it matters:** An upgrade before the current epoch’s first activity can discard the carried system-utilization baseline. TrustBonding then observes an artificial utilization decline and can apply the minimum system reward ratio.
- **File:** `src/protocol/MultiVault.sol:342`; `src/libraries/MultiVaultLib.sol:1257`; downstream calculation at `src/protocol/emissions/TrustBonding.sol:665`.

For example, let the previous epoch contain **1,000 TRUST** of utilization, while the current epoch has no activity and therefore no materialized utilization entry. `reinitialize` selects that empty current epoch. A subsequent **10 TRUST** utilization addition records **10**, where carrying the legacy baseline would produce **1,010**; TrustBonding observes **−990** instead of **+10**.

The separate-transaction sequence also exposes the new `_rollover` before initialization: it can use the default epoch-zero source and mark the current epoch rolled over. Reinitialization does not repair an already incorrect total.

- **Which invariant or check should have stopped it, and why it does not:** The rollover source must reference a populated legacy balance. `reinitialize` writes the epoch number without carrying or validating its balance, while `_rollover` treats `hasRolledOverSystemUtilization` as conclusive.

This affects utilization and emissions accounting; the demonstrated sequence does not remove vault principal or divert curve fees. Whether mainnet satisfies the empty-current-epoch precondition at execution is **not verified**.

**Correction:** Migrate a valid legacy utilization baseline and explicitly handle operations occurring before reinitialization; assigning the current epoch alone is insufficient.

## Refuted hypotheses

- **Deposit/redeem corrupts lot totals or leaves stale mask bits:** Band application updates the lot and aggregate ledgers together; highest-first unwind reduces the same ledgers and clears exhausted bits — `DynamicFeeFlatPriceCurve.sol:1151`, `:825`.
- **Partial withdrawal preserves an artificially cheap/high-earning averaged position:** Lots retain their entry tiers and the highest lots leave first — `DynamicFeeFlatPriceCurve.sol:799`, `:825`.
- **A dust seat captures a whole scheduled slice:** Occupancy caps and the full scheduled-weight denominator prevent that; at launch, one share in an otherwise empty 2,000-share tier receives only its occupancy fraction — `DynamicFeeFlatPriceCurve.sol:1254`, `:1372`, `:1419`, `:1458`.
- **Unplaced spike/exit fees are paid twice through the spread:** Residual single-target amounts terminate in protocol accrual rather than enlarging the fulcrum allocation — `DynamicFeeFlatPriceCurve.sol:917`, `:1194`.
- **The exiter collects its own fee through another residual lot:** Recipient stakes exclude the account at every visited tier, followed by rebasing of all remaining lots — `DynamicFeeFlatPriceCurve.sol:978`, `:1419`, `:786`.
- **Quote/replay disagreement makes MultiVault forward a different fee from the one withheld:** The calculated hook fee is carried into execution and forwarded unchanged; band replay allocates that received amount — `MultiVaultLib.sol:933`, `:942`, `DynamicFeeFlatPriceCurve.sol:1098`. This does not claim exact equality between gross quote traversal and the net stake trajectory after MultiVault’s own fees.
- **Live reconfiguration strands lots above a shortened ladder or installs overflowing edge math:** Tier count cannot shrink, and configuration probes the top edge; accrued entitlement remains indexed by lot tier — `DynamicFeeFlatPriceCurve.sol:348`, `:1606`.
- **Launch fees consume principal through subtraction underflow:** The configured rates and immutable curve ceilings leave room for the supplied MultiVault fees — `DynamicFeeFlatPriceCurve.sol:1606`, `MultiVaultLib.sol:1014`, `:1131`.
- **Repeated terms or callback reentry double-claim earnings:** Settlement updates debt, payment clears banked earnings, and claim is non-reentrant — `DynamicFeeFlatPriceCurve.sol:545`, `:757`.
- **A multicall leg spends the entire outer `msg.value`:** Allocation sum is checked, payable funding paths receive `_effectiveMsgValue()`, and approve/redeem paths require a zero allocation — `MultiVault.sol:567`, `:610`, `:615`, `:629`.
- **Nested batches or callbacks reuse a live allocation:** The transient nesting flag rejects nested multicalls; value-moving entry points retain their reentrancy guards — `MultiVault.sol:567`, `:684`, `:706`.
- **Affiliate callbacks alter the routed operation before execution:** Routing precedes affiliate payment on all five routes, with excess refund last — `FeeProxy.sol:251`, `:283`, `:317`, `:346`, `:398`.
- **Failed refunds become affiliate funds or can be claimed twice:** Failed sends credit the caller’s refund ledger; withdrawal clears that caller’s balance before transferring — `FeeProxy.sol:760`, `:599`.
- **FeeProxy bypasses receiver approval or one dimension of a fee guard:** Receiver authorization checks cover both proxy and caller; guards constrain both percentage and fixed fees — `FeeProxy.sol:672`, `:716`.
- **A hook curve becomes the default and silently misses creation accounting:** Both initialization and the configuration setter enforce hooklessness — `MultiVault.sol:314`, `:823`, `:843`.
- **Zero-valued pre-reinitializer Warden configuration permits an unsigned claim:** Empty/malformed bundles fail, and recovered signers still need `SIGNER_ROLE`; reinitialization authenticates the bootstrap administrator — `AtomWarden.sol:222`, `:583`, `:607`.
- **The beacon swap lets someone seize a legacy unclaimed wallet:** Existing fields remain aligned; `completeClaim` is Warden-only and initializes the new primary owner and owner registry together — `AtomWallet.sol:97`, `:342`, `:521`.
- **Signature reuse authorizes another wallet’s ownership operations:** Contract-bound signature hashing and current-owner verification prevent cross-wallet replay — `CoinbaseSmartWalletLib.sol:102`, `:309`, `AtomWallet.sol:546`.
- **Pause or a zero reward target permanently prevents principal withdrawal:** Withdrawal remains available outside the paused bonding entry points; nonpositive utilization and satisfied targets exit before normalization — `VotingEscrow.sol:497`, `TrustBonding.sol:653`.

## GitHub-Ready Comments

src/external/curve/VotingEscrow.sol:353

**Blocking — third-party calls can involuntarily lock the holder’s liquid tokens.** `deposit_for(holder, amount)` is permissionless, but this transfer pulls from `holder`. Anyone can consume an active holder’s remaining allowance—for example, locking 10,000 additional tokens until their existing expiry without supplying any tokens themselves. This is pre-existing and documented, but still meets the principal-locking threshold. Please make permissionless deposits caller-funded or require holder authorization.

src/protocol/MultiVault.sol:342

Please migrate the utilization balance as well as its epoch pointer. If the current epoch has no activity, this selects an empty source: a legacy total of 1,000 followed by a 10-TRUST addition becomes 10 instead of 1,010. Operations between implementation upgrade and reinitialization can also roll from epoch zero, and this assignment does not repair them. That can force the system reward ratio to its minimum.

