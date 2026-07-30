// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import {
    IDynamicFeeFlatPriceCurve,
    DynamicFeeConfig,
    TierFeeOverride
} from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/**
 * @title  DynamicFeeFlatPriceCurve
 * @author 0xIntuition
 * @notice Self-contained flat-price / dynamic-fee bonding curve. A single address is both the audited
 *         flat 1:1 pricing surface (inherited verbatim from {LinearCurve}) AND the entire per-vault fee
 *         economy: a tunable tier schedule, per-tier deposit and withdrawal fees, an optional sparse
 *         per-tier manual override, and the pull-based accounting that redistributes those fees to
 *         earlier / adjacent tiers. {MultiVault} discovers the fee surface through the standardized
 *         {IBaseCurve} hook getters and routes deposits and redeems through the quote + record hooks,
 *         forwarding each fee as native TRUST; holders pull their earnings via {claim}.
 *
 * @dev    Packaging: folds the former standalone `DynamicFeeSidePocket` into the curve itself, so the
 *         registry-resolved curve address and the fee-routing target are one and the same contract.
 *         Pricing (`previewDeposit`/`previewRedeem`/`currentPrice`/...) comes entirely from {LinearCurve};
 *         nothing about the 1:1-at-par math changes.
 *
 * @dev    The economics, stated in full here rather than by reference to anything outside this repo:
 *         - Tiers are bands of cumulative net vault assets. The cumulative upper edge of tier `k` is
 *           the geometric series `edge(k) = width0 * ((1+g)^(k+1) - 1) / g` with `g = growthGBps / BPS`,
 *           and a tier's width is exactly the span between edges, `width(k) = edge(k) - edge(k-1)`.
 *           The edges are the single source of truth: `tierOf` and the piecewise fee walk both key off
 *           them, and the width view is derived from them so it can never disagree with the band a
 *           deposit is actually charged. Conceptually widths grow GEOMETRICALLY — each band is `(1+g)x`
 *           the one below it — which is what lets the ladder widen asymptotically so the top tier
 *           absorbs a very large band. Compounding is the single fixed SHAPE of the ladder: there is
 *           no arithmetic-vs-geometric mode to toggle at runtime. The growth RATE `growthGBps` itself
 *           stays admin-tunable via `setConfig` (a retune re-prices the edges but preserves booked and
 *           pending earnings — the accumulators are index-keyed).
 *         - Deposit fee `min(cap, base + tier*growth)` (or the tier's manual override) is distributed
 *           across the prior tiers by a sliding-fulcrum TRIANGULAR kernel: each prior tier at distance
 *           `d` from the source earns `max(0, 1 - |d - dStar|/sigma)`, peaking at a fulcrum
 *           `dStar = (1 - fulcrumAlpha/BPS) * span` tiers down (a fraction of the span, so the
 *           most-earning band slides up the ladder as the vault grows). Weights are normalized over the
 *           OCCUPIED prior tiers and split pro-rata by stake, with the depositor excluded from their own
 *           fee; `fulcrumAlpha = BPS`, `kernelSpread = 4e18` (σ = 4 tiers) reproduces the legacy
 *           nearest-first window. A `depositToPriorTierBps` slice can additionally be paid as a
 *           lump to the nearest occupied prior tier BEFORE the fulcrum spread (0 by default = pure
 *           fulcrum), letting the immediately preceding cohort earn a configurable premium.
 *
 *           THE EARNING WINDOW, and why it is stated rather than left to be derived. Because `dStar`
 *           is a FRACTION of the span, which prior tiers earn depends on where the vault currently
 *           sits, not on the recipient tier alone. Substituting `d = tier - j` and
 *           `dStar = (1 - alpha) * tier` into the weight, prior tier `j` earns a non-zero share iff
 *
 *               |alpha * tier - j| < sigma        (`tier` = the SOURCE tier, i.e. the vault's tier)
 *
 *           For a non-zero `alpha` that is a bounded band of source tiers,
 *           `(j - sigma)/alpha < tier < (j + sigma)/alpha`, about `2*sigma/alpha` tiers wide. A cohort
 *           therefore drops out of the spread once the vault climbs past the upper end of its band,
 *           and it participates again if the vault falls back inside — the condition is evaluated
 *           afresh on every fee, so nothing about it is permanent or one-way. Nothing already accrued
 *           is affected either: `accFeePerShare` is monotonic and is never decremented, so leaving the
 *           window stops NEW credit and touches nothing earned before. At `alpha = 0` the condition
 *           collapses to `j < sigma`: the earliest `sigma` tiers earn from every source tier and no
 *           window ever closes.
 *           Two examples. At `alpha = 1, sigma = 4` and a vault in tier 6, `|6 - j| < 4` admits tiers
 *           3..5 — the legacy nearest-first window, in the documented 50 / 33.3 / 16.7 split. At
 *           `alpha = 0.6, sigma = 3` and the same vault, `|3.6 - j| < 3` admits tiers 1..5 and tier 0
 *           receives nothing, because `|3.6 - 0|` exceeds sigma.
 *         - Withdrawal fee `min(cap, base + exitTier*growth)` (or the tier's manual override) goes to
 *           the residual holders of the exiting tier, with a configurable
 *           `withdrawalToFulcrumTiersBps` slice routed to the prior tiers via the same fulcrum kernel;
 *           the exiter is excluded from the fee they themselves pay.
 *
 *           NOTE on what "residual holder" does and does not mean. Entitlement is established at
 *           `recordDeposit` time against the tier's then-current accumulator; there is deliberately
 *           NO dwell requirement, NO time-weighting and NO minimum holding period — this is an
 *           activity-driven redistribution, not a yield-accrual product, and earning from a later
 *           depositor or a later exiter is the intended mechanic — bounded, in that a sandwich around
 *           a deposit can never extract more than the victim's own fee. A position opened one transaction
 *           before an exit is therefore as entitled as one held for a year, and because the credit
 *           divides across the recipient tier's stake, a small position that is the tier's only
 *           other occupant receives the whole slice. Conservation still binds: no party can ever
 *           earn more than the fees actually collected. Read "residual holder" as "whoever is in the
 *           tier when the fee lands", not as a commitment or loyalty reward.
 *
 *         The spec's O(cohort) push-credit is replaced by an O(1) MasterChef-style accumulator:
 *         `accFeePerShare[termId][tier]` tracks fee-per-unit-stake; a holder's pending is
 *         `stake * accFeePerShare[tier] - rewardDebt`. Exclusion of the depositor / exiter is exact:
 *         the fee is added to each recipient tier's accumulator using a denominator that omits the
 *         excluded party's stake, and the excluded party's `rewardDebt` is re-based to the
 *         post-distribution accumulator so they earn nothing from their own fee.
 *
 *         Custody: this contract physically holds the redistributed fee TRUST (native). Principal is
 *         never held here — it stays in {MultiVault} at par. `Ownable`, with the deploy script
 *         assigning ownership to the parameters `TimelockController` on governed networks, so every
 *         fee action runs through the same Safe + timelock path as the equivalent MultiVault setters.
 *
 *         Precision: integer accumulator division leaves sub-wei-per-share dust that stays as an
 *         unattributed contract balance (standard MasterChef trade-off); whole fee slices with no
 *         eligible recipient (no prior tier / empty bucket / rounding remainder) route to
 *         `protocolAccrued`, sweepable by the owner. No holder's principal is ever at risk here.
 */
contract DynamicFeeFlatPriceCurve is
    LinearCurve,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    IDynamicFeeFlatPriceCurve
{
    using FixedPointMathLib for uint256;
    using LibSort for uint256[];

    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    /// @notice Basis-points denominator for all fee rates.
    uint256 public constant BPS = 10_000;

    /// @notice Fixed-point scale for the per-tier fee accumulator.
    uint256 public constant ACC_PRECISION = 1e18;

    /// @notice Fixed-point scale for the stake-weighted average entry tier.
    uint256 public constant TIER_PRECISION = 1e18;

    /// @dev Fixed-point one, for the compounding tier-width math.
    uint256 private constant WAD = 1e18;

    /// @notice Upper bound on the triangular spread `σ`, in `TIER_PRECISION` tier units. Bounds the
    ///         earning window and keeps the weight math well away from overflow; far wider than any
    ///         legible schedule needs (the whole ladder is <= MAX_TIER_COUNT tiers).
    uint256 public constant MAX_KERNEL_SPREAD = 64e18;

    /// @notice Upper bound on the tier count (bounds the `tierOf` / edge loops).
    uint256 public constant MAX_TIER_COUNT = 64;

    /// @notice Hard ceiling on `depositCapBps`, above which no schedule may be stored.
    /// @dev    The curve fee is netted out of an amount MultiVault has already reduced by its own
    ///         entry, protocol and atom-wallet fees, so a curve cap approaching `BPS` can underflow
    ///         that subtraction and brick every deposit on the curve. This ceiling bounds the CURVE's
    ///         contribution to that envelope. Note it does not bound the whole envelope on its own:
    ///         `MultiVault.setVaultFees` is timelock-gated but carries no numeric bound, so a
    ///         sufficiently extreme vault schedule could still exhaust the netting. Immutable by
    ///         design: it bounds what governance may configure, so it is deliberately not settable.
    uint256 public constant MAX_DEPOSIT_CAP_BPS = 2000;

    /// @notice Hard ceiling on `withdrawalCapBps`, above which no schedule may be stored.
    /// @dev    Bounds the redeem side of the same envelope. Critically, it also bounds the
    ///         zero-payout mode: a withdrawal rate strictly inside a near-`BPS` cap consumes the
    ///         entire redemption and pays the redeemer nothing WITHOUT reverting. Capping the cap
    ///         removes that configuration from the reachable set entirely, rather than relying on
    ///         the redeemer supplying a protective `minAssets`. Immutable by design.
    uint256 public constant MAX_WITHDRAWAL_CAP_BPS = 2000;

    /// @notice Hard ceiling on `config.minEligibleTierStake`, above which no floor may be stored.
    /// @dev    Bounds how much of the fee stream governance can starve into {protocolAccrued}. Without
    ///         it the floor would be a STRICT EXPANSION of owner power rather than a restatement of it:
    ///         a huge `width0` can already route every DEPOSIT fee to the protocol bucket (the vault
    ///         falls inside tier 0, so `_payFulcrumTiers` short-circuits on `span == 0`), but withdrawal
    ///         fees key on the holder's recorded `userTier` and still reach real cohorts. An unbounded
    ///         floor would starve BOTH streams in one transaction, and `sweepProtocol` would collect.
    ///         What the ceiling guarantees is narrow, and it is worth stating precisely rather than
    ///         overclaiming: the floor can never exceed 1000 TRUST, so any tier whose EXCLUSION-ADJUSTED
    ///         recipient stake is at least that much always qualifies, no matter what governance sets.
    ///         That is the whole of it. Note the guarantee is on the adjusted cohort, not on raw
    ///         `tierStake`: a tier holding far more than the ceiling can still fail the test for a given
    ///         distribution once the payer's own stake is removed from it.
    ///         It does NOT guarantee that some tier always qualifies. Two reasons, both real:
    ///         (1) eligibility is judged POST-exclusion, and `Σ tierStake[termId][t] == vaultAssets`
    ///             bounds only the raw bucket totals, not the exclusion-adjusted cohort that a given
    ///             distribution actually tests; and
    ///         (2) the redeem path's sub-floor branch does not look for a qualifying tier at all — an
    ///             orphaned diamond slice accrues straight to {protocolAccrued}, by design.
    ///         So a term of ANY size can route a fee wholly to {protocolAccrued} under a high floor. Do
    ///         not read the ceiling as an anti-starvation invariant; read it as a cap on the absolute
    ///         magnitude of a governance parameter, backed by the timelock for everything else.
    ///         The value is 20% of the shipped tier-0 width (`width0 = 5000e18`), which leaves real
    ///         policy room while keeping the cap meaningful. It is a POLICY ceiling, not a derived
    ///         constant, and must be re-reasoned if `width0` moves by orders of magnitude. Immutable by
    ///         design: it bounds what governance may configure, so it is deliberately not settable.
    uint256 public constant MAX_MIN_ELIGIBLE_TIER_STAKE = 1000e18;

    /* =================================================== */
    /*                    STATE VARIABLES                  */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    address public multiVault;

    /// @dev The tunable tier + fee schedule. Exposed via {getConfig} (dynamic-array member blocks the
    ///      auto-getter).
    DynamicFeeConfig internal config;

    /// @notice Sparse per-tier manual fee override; `isSet` distinguishes an explicit 0-bps rate from
    ///         "inherit the formula". Consulted before the formulaic schedule in {_depositFeeBps} /
    ///         {_withdrawalFeeBps}, so the piecewise deposit walk picks up each traversed band's own
    ///         override automatically.
    mapping(uint256 tier => TierFeeOverride tierOverride) public tierFeeOverride;

    /// @notice Cumulative net user stake per vault (mirrors the spec's `totalAssets`; excludes the
    ///         MultiVault min-share seed). Drives the current tier for fee rate + distribution.
    /// @dev    UNIT COUPLING — load-bearing and not otherwise asserted. This accumulates SHARE amounts
    ///         (the record hooks are handed `sharesForReceiver` / `shares`), while the tier ladder it
    ///         is compared against (`_tierUpperEdge`, `width0`) is denominated in ASSETS (TRUST wei).
    ///         The two agree only because a vault on this curve holds price at exactly 1:1: MultiVault
    ///         routes entry and exit fees to the DEFAULT curve's vault, never to a non-default curve's,
    ///         so this vault's `totalAssets / totalShares` never drifts off par. Every tier decision and
    ///         therefore every fee rate depends on that. If a future change ever credits pro-rata value
    ///         to a non-default curve's vault, the ladder silently starts reading the wrong quantity.
    ///         Pin it with an invariant test asserting `currentSharePrice(term, thisCurveId) == 1e18`
    ///         rather than relying on this comment.
    mapping(bytes32 termId => uint256 assets) public vaultAssets;

    /// @notice Sum of stake held by users whose bucket (`round(avgEntryTier)`) is `tier`.
    mapping(bytes32 termId => mapping(uint256 tier => uint256 stake)) public tierStake;

    /// @notice ACC_PRECISION-scaled accumulated fee per unit of stake, per vault and tier.
    mapping(bytes32 termId => mapping(uint256 tier => uint256 acc)) public accFeePerShare;

    /// @notice A user's tracked stake in a vault (equal to their dynamic-curve share balance).
    mapping(bytes32 termId => mapping(address user => uint256 stake)) public userStake;

    /// @notice A user's bucket, `round(avgEntryTier)`; selects which tier accumulator they earn from.
    mapping(bytes32 termId => mapping(address user => uint256 tier)) public userTier;

    /// @notice A user's TIER_PRECISION-scaled stake-weighted average entry tier.
    mapping(bytes32 termId => mapping(address user => uint256 avgTierScaled)) public userAvgTier;

    /// @notice A user's settled reward debt: `stake * accFeePerShare[userTier] / ACC_PRECISION`.
    mapping(bytes32 termId => mapping(address user => uint256 debt)) public rewardDebt;

    /// @notice Booked, withdrawable native earnings per user (cross-vault).
    mapping(address user => uint256 amount) public earned;

    /// @notice Fee slices with no eligible recipient, sweepable by the owner.
    /// @dev    NOT only rounding dust — the balance has three sources and two of them are whole slices:
    ///         (1) rounding remainders from the per-share accumulator division, which are genuinely
    ///             dust-scale;
    ///         (2) the ENTIRE deposit fee whenever the vault sits in tier 0, because there is no prior
    ///             tier to redistribute to (`_payFulcrumTiers` short-circuits on `span == 0`). Note this
    ///             is keyed on the vault's tier, not on whether holders exist: buckets are
    ///             `round(avgEntryTier)`, so holders can remain recorded at higher tiers with non-zero
    ///             `tierStake` while `vaultAssets` has fallen back inside `edge(0)`;
    ///         (3) a withdrawal fee when no other tier holds stake at all — the last-redeemer case.
    ///         (2) and (3) are the intended terminal behaviour: with no cohort to reward, the protocol
    ///         absorbs the fee rather than forfeiting it, and no value is ever lost. Read the name as
    ///         "undistributable", not "negligible" — for a young or shrunken vault it can be the whole
    ///         fee stream.
    uint256 public protocolAccrued;

    /* =================================================== */
    /*                        EVENTS                       */
    /* =================================================== */

    event ConfigUpdated(
        uint256 width0, uint256 tierCount, uint256 growthGBps, uint256 fulcrumAlpha, uint256 kernelSpread
    );
    event DepositRecorded(bytes32 indexed termId, address indexed account, uint256 netStake, uint256 fee, uint256 tier);
    event RedeemRecorded(
        bytes32 indexed termId, address indexed account, uint256 withdrawnStake, uint256 fee, uint256 exitTier
    );
    event Claimed(address indexed account, uint256 amount);
    event ProtocolAccruedIncreased(uint256 amount);
    event ProtocolSwept(address indexed to, uint256 amount);
    event WithdrawalFeeRerouted(bytes32 indexed termId, uint256 exitTier, uint256 recipientTier, uint256 amount);
    event TierFeeOverrideSet(uint256 indexed tier, uint16 depositFeeBps, uint16 withdrawalFeeBps);
    event TierFeeOverrideCleared(uint256 indexed tier);
    event MinEligibleTierStakeUpdated(uint256 previousMinEligibleTierStake, uint256 newMinEligibleTierStake);

    /* =================================================== */
    /*                        ERRORS                       */
    /* =================================================== */

    error DynamicFeeFlatPriceCurve_ZeroAddress();
    error DynamicFeeFlatPriceCurve_OnlyMultiVault();
    error DynamicFeeFlatPriceCurve_NothingToClaim();
    error DynamicFeeFlatPriceCurve_InvalidConfig();
    error DynamicFeeFlatPriceCurve_TierCountCannotShrink();
    error DynamicFeeFlatPriceCurve_InvalidTierOverride();
    error DynamicFeeFlatPriceCurve_DuplicateTermIds();
    error DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake();

    /* =================================================== */
    /*                      MODIFIERS                      */
    /* =================================================== */

    /// @notice Restricts the record hooks to the wired {MultiVault}.
    /// @dev    The check lives in {_onlyMultiVault} so the modifier inlines a single JUMP per use
    ///         site instead of duplicating the body — smaller deployed bytecode at negligible
    ///         runtime cost.
    modifier onlyMultiVault() {
        _onlyMultiVault();
        _;
    }

    /// @dev Body of {onlyMultiVault}; reverts unless the caller is the wired {MultiVault}.
    function _onlyMultiVault() private view {
        if (msg.sender != multiVault) revert DynamicFeeFlatPriceCurve_OnlyMultiVault();
    }

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initialize the merged curve: pricing name + fee economy in one call.
    /// @dev    The inherited {LinearCurve.initialize} (name-only) selector remains on the ABI but is
    ///         inert: proxy deployment invokes THIS 4-arg initializer atomically, consuming the
    ///         one-shot `initializer` slot, so the name-only path can never run on a live proxy.
    /// @param _name The curve name registered with the {BondingCurveRegistry}
    /// @param _owner The owner allowed to tune config, set tier overrides, and sweep protocol dust
    /// @param _multiVault The MultiVault authorized to call the record hooks
    /// @param _config The initial tier + fee schedule
    function initialize(string calldata _name, address _owner, address _multiVault, DynamicFeeConfig calldata _config)
        external
        initializer
    {
        if (_owner == address(0) || _multiVault == address(0)) revert DynamicFeeFlatPriceCurve_ZeroAddress();
        __BaseCurve_init(_name);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        multiVault = _multiVault;
        _setConfig(_config);
    }

    /* =================================================== */
    /*                      ADMIN                          */
    /* =================================================== */

    /// @notice Update the tier + fee schedule.
    /// @dev    Retuning semantics with live positions (intentional, so the economy stays tunable
    ///         while ENG-level mechanics converge):
    ///         - Existing holders keep their recorded numeric bucket ids (`userTier`, `tierStake`,
    ///           `accFeePerShare` are index-keyed and are NOT migrated); already-booked and pending
    ///           earnings are unaffected, so solvency can never be impacted by a retune.
    ///         - All FUTURE tier decisions (`tierOf`, fee rates, distribution targets) use the new
    ///           schedule immediately.
    ///         - `tierCount` may only grow once set, so no occupied bucket can be stranded above
    ///           the schedule (`_roundTier` and the distribution walk always cover every live
    ///           bucket index).
    /// @dev    RETUNE SEMANTICS, with live positions. A retune re-prices the ladder going FORWARD and
    ///         is never applied retroactively: earnings already accrued under the old schedule are
    ///         preserved exactly, which is the guarantee that matters. A rate moving from, say, 10% to
    ///         12% applies only to subsequent activity.
    ///         The consequence to understand is that positions are NOT migrated. The accumulators are
    ///         index-keyed (`accFeePerShare[termId][tier]`), and changing `width0`, `growthGBps` or
    ///         `tierCount` changes what each index MEANS without moving any holder between indices. A
    ///         holder therefore keeps their recorded bucket while that bucket now denotes a different
    ///         band, so the fee stream silently re-targets: the cohort a slice was promised to is not
    ///         necessarily the cohort that receives it afterwards. This is deliberate — migrating
    ///         positions would be unbounded in the number of holders — but it means a retune is an
    ///         economic action, not a parameter tweak. Prefer retuning when the vault is quiet, and
    ///         monitor the emitted before/after ladder.
    /// @param _config The new configuration
    function setConfig(DynamicFeeConfig calldata _config) external onlyOwner {
        _setConfig(_config);
    }

    /// @notice Set a sparse manual fee override for a single tier (replaces the formula for that tier).
    /// @dev    Overriding one tier does not touch any other tier. The stored rates fully replace the
    ///         formulaic `min(cap, base + tier*growth)` but must stay within the schedule's declared
    ///         per-tier caps (`depositCapBps` / `withdrawalCapBps`), which are themselves bounded by
    ///         the immutable {MAX_DEPOSIT_CAP_BPS} / {MAX_WITHDRAWAL_CAP_BPS} ceilings.
    ///         An override is also CLAMPED AT READ TIME against the live cap, so lowering a cap
    ///         tightens every tier uniformly — including tiers that already carry an override — and
    ///         no separate clear-then-retune step is required when tightening.
    ///         Those two bounds together are what keep a withdrawal rate from consuming a whole
    ///         redemption. That mode is worth understanding: it does NOT surface as a revert from the
    ///         rate itself. Absent a bound, a rate strictly inside a near-`BPS` cap would let a
    ///         redemption succeed while paying the redeemer ZERO and burning their shares. The
    ///         ceilings remove that configuration from the reachable set, and `MultiVault` carries an
    ///         independent floor that rejects a redemption returning no assets.
    ///         An explicit 0-bps rate remains expressible (via `isSet == true`). Only tiers within the
    ///         live `tierCount` may be overridden.
    /// @param tier The tier index to override (`< config.tierCount`)
    /// @param newDepositFeeBps The manual deposit fee for the tier, in bps (`<= config.depositCapBps`)
    /// @param newWithdrawalFeeBps The manual withdrawal fee for the tier, in bps (`<= config.withdrawalCapBps`)
    function setTierFeeOverride(uint256 tier, uint16 newDepositFeeBps, uint16 newWithdrawalFeeBps) external onlyOwner {
        if (tier >= config.tierCount) revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
        if (newDepositFeeBps > config.depositCapBps || newWithdrawalFeeBps > config.withdrawalCapBps) {
            revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
        }
        tierFeeOverride[tier] =
            TierFeeOverride({ isSet: true, depositFeeBps: newDepositFeeBps, withdrawalFeeBps: newWithdrawalFeeBps });
        emit TierFeeOverrideSet(tier, newDepositFeeBps, newWithdrawalFeeBps);
    }

    /// @notice Clear a tier's manual override, restoring the formulaic rate for that tier.
    /// @param tier The tier index whose override is cleared
    function clearTierFeeOverride(uint256 tier) external onlyOwner {
        delete tierFeeOverride[tier];
        emit TierFeeOverrideCleared(tier);
    }

    /// @notice Sweep accrued protocol dust (unassigned fee slices) to `to`.
    /// @param to Recipient of the swept native TRUST
    /// @return amount The amount swept
    function sweepProtocol(address to) external onlyOwner nonReentrant returns (uint256 amount) {
        if (to == address(0)) revert DynamicFeeFlatPriceCurve_ZeroAddress();
        amount = protocolAccrued;
        if (amount == 0) return 0;
        protocolAccrued = 0;
        Address.sendValue(payable(to), amount);
        emit ProtocolSwept(to, amount);
    }

    /* =================================================== */
    /*                    FEE GETTERS                      */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    function hasDepositFeeHook() external pure override returns (bool) {
        return true;
    }

    /// @inheritdoc IBaseCurve
    function hasRedeemFeeHook() external pure override returns (bool) {
        return true;
    }

    /// @inheritdoc IBaseCurve
    /// @dev Piecewise across the tier bands the deposit traverses: each portion is charged at its
    ///      own band's rate, so a large deposit that crosses several tiers pays the blended rate
    ///      instead of the pre-deposit tier's rate on the whole amount. Without this, lumping was
    ///      strictly cheaper than chunking — a regressive discount for exactly the depositors who
    ///      move the vault the most.
    function quoteDepositFee(bytes32 termId, uint256 baseAssets) external view override returns (uint256 fee) {
        return _piecewiseDepositFee(vaultAssets[termId], baseAssets);
    }

    /// @inheritdoc IBaseCurve
    /// @dev The rate keys on `account`'s tracked entry tier; an account with no tracked stake (e.g.
    ///      the account-less preview path passing address(0)) falls back to the vault's current tier.
    function quoteRedeemFee(bytes32 termId, address account, uint256 grossAssets)
        external
        view
        override
        returns (uint256 fee)
    {
        uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultAssets[termId]);
        return grossAssets.mulDivUp(_withdrawalFeeBps(tier), BPS);
    }

    /* =================================================== */
    /*                    RECORD HOOKS                     */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    /// @dev Receives the deposit fee as native value and distributes it across the prior tiers: an
    ///      optional `depositToPriorTierBps` lump to the nearest occupied prior tier, the rest by
    ///      the sliding-fulcrum kernel, with the depositor excluded from their own fee. `onlyMultiVault`.
    function recordDeposit(bytes32 termId, address account, uint256 netStake)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        uint256 pool = msg.value;
        // Tier BEFORE this deposit is added — matches the spec's `currentTier = tierOf(totalAssets)`.
        uint256 tier = _tierOf(vaultAssets[termId]);
        uint256 oldTier = userTier[termId][account];
        uint256 oldStake = userStake[termId][account];

        // Bank the depositor's pending at the pre-distribution accumulator so the fee they are about
        // to pay cannot flow back to them.
        if (oldStake > 0) {
            _settle(termId, account);
        }

        // Distribute the deposit fee across the prior tiers, excluding the depositor's own stake from
        // every recipient denominator. A `depositToPriorTierBps` slice is paid as a lump to the
        // nearest occupied prior tier (the prior-tier spike); the remainder spreads by the sliding
        // fulcrum. The fee AMOUNT is piecewise across the tiers the deposit traverses (see
        // {quoteDepositFee}); the distribution TARGET stays keyed on the pre-deposit tier — per-band
        // targeting is a candidate refinement for the mechanics lock.
        _payDepositFee(termId, pool, tier, oldTier, oldStake);

        // Move the depositor's position with a stake-weighted average entry tier.
        uint256 newStake = oldStake + netStake;
        uint256 newAvg;
        if (oldStake == 0) {
            newAvg = tier * TIER_PRECISION;
        } else {
            // Unrolled into per-term 512-bit-intermediate mulDivs so the weighted average cannot
            // overflow for any stake magnitude (the naive sum-of-products form already had ~99 bits
            // of headroom at max tier x total native supply, but this removes the question
            // permanently). The two floors under-round the average by at most 2 wei-tier units
            // (2e-18 of a tier) per deposit — far below the half-up bucket-rounding threshold.
            newAvg = userAvgTier[termId][account].fullMulDiv(oldStake, newStake)
                + (tier * TIER_PRECISION).fullMulDiv(netStake, newStake);
        }
        uint256 newTier = _roundTier(newAvg);

        if (newTier != oldTier) {
            if (oldStake > 0) {
                tierStake[termId][oldTier] -= oldStake;
            }
            tierStake[termId][newTier] += newStake;
        } else {
            tierStake[termId][newTier] += netStake;
        }

        userStake[termId][account] = newStake;
        userAvgTier[termId][account] = newAvg;
        userTier[termId][account] = newTier;
        // Re-base against the post-distribution accumulator: excludes the depositor from their own fee.
        rewardDebt[termId][account] = newStake.fullMulDiv(accFeePerShare[termId][newTier], ACC_PRECISION);
        vaultAssets[termId] += netStake;

        emit DepositRecorded(termId, account, netStake, pool, tier);
    }

    /// @inheritdoc IBaseCurve
    /// @dev Receives the withdrawal fee as native value and distributes it to the residual holders
    ///      of the exiting tier (and optionally the nearest-N tiers per policy), excluding the exiter.
    ///      When the exiting tier has no residual cohort, the diamond slice falls through to the
    ///      nearest occupied tier (above first, then below) rather than to the protocol, so a stayer
    ///      earns a departing whale's exit fee. `onlyMultiVault`.
    function recordRedeem(bytes32 termId, address account, uint256 withdrawnStake)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        uint256 pool = msg.value;
        // Tier BEFORE the exit is removed — matches the spec's `currentTier` for the frontier split.
        uint256 tier = _tierOf(vaultAssets[termId]);
        uint256 exitTier = userTier[termId][account];

        // Bank the exiter's pending, then remove the exiting portion so they are excluded from the
        // fee they are about to pay.
        _settle(termId, account);
        userStake[termId][account] -= withdrawnStake;
        tierStake[termId][exitTier] -= withdrawnStake;
        uint256 residual = userStake[termId][account];

        uint256 toFulcrum = pool.mulDiv(config.withdrawalToFulcrumTiersBps, BPS);
        uint256 toExitingTier = pool - toFulcrum;
        uint256 undistributed;

        // (1) Diamond-hands slice -> the residual holders of the exiting tier (exiter excluded).
        // `denom` is exactly the OTHER holders' stake in the exiting tier: `tierStake` has already had
        // `withdrawnStake` removed above and `residual` is the exiter's remainder, so the withdrawal
        // size cancels out. An exiter therefore cannot size a partial redeem to push their own tier
        // under the floor and steer the fee — `denom` does not depend on `withdrawnStake`.
        uint256 denom = tierStake[termId][exitTier] - residual;
        if (toExitingTier > 0) {
            if (_isEligibleStake(denom)) {
                accFeePerShare[termId][exitTier] += toExitingTier.fullMulDiv(ACC_PRECISION, denom);
            } else if (denom == 0) {
                // Whale-exit fallback: the exiting tier has no residual cohort AT ALL, so rather than
                // forfeit the diamond slice to the protocol, route it to the nearest occupied tier —
                // searched ABOVE first (the stayer who sat above the exiting whale earns it), then
                // below. Only when NO other tier holds stake (the last-withdrawer / empty-vault case)
                // does it fall through to `_payFulcrumTiers`, and ultimately to protocol accrual.
                (uint256 recipientTier, uint256 recipientStake) = _nearestOccupiedTier(termId, exitTier);
                // Sentinel, not an occupancy test: {_nearestOccupiedTier} already applies the floor and
                // returns `(0, 0)` when nothing qualifies. This only asks whether the scan found one.
                if (recipientStake > 0) {
                    accFeePerShare[termId][recipientTier] += toExitingTier.fullMulDiv(ACC_PRECISION, recipientStake);
                    emit WithdrawalFeeRerouted(termId, exitTier, recipientTier, toExitingTier);
                } else {
                    undistributed += toExitingTier;
                }
            } else {
                // The cohort EXISTS but is sub-floor: the slice is ORPHANED. Its intended recipients are
                // disqualified, and no other party has a principled claim on it. Reachable only once the
                // floor is live — `0 < denom < minEligibleTierStake` is an empty domain at the zero
                // default — so this branch must not inherit the routing of either branch above.
                // It accrues to the protocol rather than being redistributed, and that is deliberate:
                // every redistribution route available here concentrates, and each one is steerable by
                // whoever is willing to post the floor.
                //   - The whale-exit reroute above is winner-takes-all and searches UPWARD first, so a
                //     seat one tier up takes 100% of an unbounded exit fee, undiluted.
                //   - Folding into the fulcrum spread is no better. A sole eligible prior tier takes its
                //     entire kernel share, and worse, {_weighPriorTiers} records a non-zero `stakes`
                //     entry for an eligible tier even when the kernel gives it ZERO weight. Once the
                //     floor disqualifies every positive-weight tier, `sumWeights` is zero and
                //     {_awardNearestOrProtocol} — which reads `stakes` and ignores `weights` — hands the
                //     whole pool to a seat the kernel says earns nothing.
                // At floor 0 none of this arises: the residual cohort is eligible and simply receives
                // the slice. The floor must not manufacture a payday that the mechanism it replaces did
                // not have, so the orphaned slice goes to the one sink with no beneficiary to game.
                protocolAccrued += toExitingTier;
                emit ProtocolAccruedIncreased(toExitingTier);
            }
        }

        // (2) Frontier slice (+ any un-distributable diamond slice) -> the nearest-N prior tiers.
        _payFulcrumTiers(termId, toFulcrum + undistributed, tier, exitTier, residual);

        // Re-base against the post-distribution accumulator: excludes the exiter from their own fee.
        rewardDebt[termId][account] = residual.fullMulDiv(accFeePerShare[termId][exitTier], ACC_PRECISION);
        vaultAssets[termId] -= withdrawnStake;

        emit RedeemRecorded(termId, account, withdrawnStake, pool, exitTier);
    }

    /* =================================================== */
    /*                       CLAIM                         */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    function claim(bytes32[] calldata termIds) external nonReentrant returns (uint256 amount) {
        uint256 length = termIds.length;
        for (uint256 i = 0; i < length;) {
            if (userStake[termIds[i]][msg.sender] > 0) {
                _settle(termIds[i], msg.sender);
            }
            unchecked {
                ++i;
            }
        }

        amount = earned[msg.sender];
        if (amount == 0) revert DynamicFeeFlatPriceCurve_NothingToClaim();

        earned[msg.sender] = 0;
        Address.sendValue(payable(msg.sender), amount);
        emit Claimed(msg.sender, amount);
    }

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    /// @dev WARNING — this figure is NOT additive across terms. It is `bankedEarnings(account)`, which is a
    ///      single account-wide balance, PLUS this term's unsettled pending. Summing it over several terms
    ///      counts the banked component once per term. Use {claimableAcross} for a total, or compose
    ///      {bankedEarnings} once with {pendingFor} per term. Retained with this signature for compatibility.
    function claimable(address account, bytes32 termId) external view returns (uint256 amount) {
        return earned[account] + _pendingFor(account, termId);
    }

    /// @notice Unsettled pending earnings for ONE term only. Additive across terms.
    /// @param  account The account to read
    /// @param  termId  The term (atom or triple) to read
    /// @return amount  The term-scoped pending amount, excluding any banked balance
    function pendingFor(address account, bytes32 termId) external view returns (uint256 amount) {
        return _pendingFor(account, termId);
    }

    /// @notice Banked, term-independent earnings already settled to the account's balance.
    /// @dev    Add this ONCE across any set of terms — it is not per-term.
    /// @param  account The account to read
    /// @return amount  The banked balance
    function bankedEarnings(address account) external view returns (uint256 amount) {
        return earned[account];
    }

    /// @notice Total withdrawable across the supplied terms — the figure {claim} would pay.
    /// @dev    Input is validated first, then the total is accumulated. `termIds` must be free of
    ///         repeats; order is irrelevant. Uniqueness is ENFORCED rather than documented, because a
    ///         repeated term would have its pending counted once per occurrence here while {claim}
    ///         settles it once — silently breaking the equality with the payout that this function
    ///         exists to provide.
    /// @dev    An EMPTY set is valid and returns {bankedEarnings}. That is not a special case: {claim}
    ///         accepts an empty array too and pays out any banked balance, so `earned` genuinely is
    ///         what {claim} would pay for zero terms. Rejecting it would break the very equality this
    ///         function documents, for no benefit.
    /// @dev    Uniqueness is proved in EXPECTED `O(n log n)`: a scratch copy is sorted so that any
    ///         repeat becomes adjacent, then one linear scan settles it. The bound is expected rather
    ///         than worst case — the underlying sort is quicksort-based and retains a theoretical
    ///         quadratic worst case — but that still beats the unconditional pairwise comparison the
    ///         same check would otherwise need. Sorting here rather than demanding a pre-sorted array
    ///         keeps the burden off every integrator. A storage or transient-storage set would be
    ///         cheaper still but is unavailable: both are state writes, which `view` forbids.
    /// @param  account The account to read
    /// @param  termIds The terms to include, in any order, without repeats; may be empty
    /// @return amount  The total claimable amount, equal to what {claim} would pay for these terms
    function claimableAcross(address account, bytes32[] calldata termIds) external view returns (uint256 amount) {
        uint256 length = termIds.length;

        // Pass 1 — validate. Sorting a scratch copy makes any repeat adjacent, so a single linear scan
        // proves uniqueness without comparing every pair.
        uint256[] memory sorted = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            sorted[i] = uint256(termIds[i]);
            unchecked {
                ++i;
            }
        }
        sorted.sort();
        for (uint256 i = 1; i < length;) {
            if (sorted[i] == sorted[i - 1]) revert DynamicFeeFlatPriceCurve_DuplicateTermIds();
            unchecked {
                ++i;
            }
        }

        // Pass 2 — accumulate. A sum is order-independent, so the sorted copy is read directly. The
        // banked balance is account-wide and is added exactly once.
        amount = earned[account];
        for (uint256 i = 0; i < length;) {
            amount += _pendingFor(account, bytes32(sorted[i]));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Shared term-scoped pending computation behind {claimable}, {pendingFor} and {claimableAcross}.
    ///      DELIBERATELY DOES NOT CONSULT `config.minEligibleTierStake`. The floor is a gate on who receives
    ///      FUTURE credit, never on who may surface credit already earned. Adding `_isEligibleStake`
    ///      here — or to {_settle}, {claim}, {claimable} or {claimableAcross} — would permanently strand
    ///      earned funds: `accFeePerShare` would still hold the credit, but nothing would read it out,
    ///      and `earned` is only ever written from {_settle}. Read this before "making the floor
    ///      consistent" across the read path; the inconsistency is the correct behaviour.
    function _pendingFor(address account, bytes32 termId) private view returns (uint256) {
        uint256 stake = userStake[termId][account];
        if (stake == 0) return 0;
        uint256 accumulated = stake.fullMulDiv(accFeePerShare[termId][userTier[termId][account]], ACC_PRECISION);
        uint256 debt = rewardDebt[termId][account];
        return accumulated > debt ? accumulated - debt : 0;
    }

    /// @notice Account-aware redeem preview: the net assets `account` would receive for `shares`,
    ///         after this curve's withdrawal fee priced at THAT ACCOUNT's recorded tier.
    /// @dev    `IMultiVault.previewRedeem` is account-agnostic and reaches {quoteRedeemFee} with
    ///         `address(0)`, which falls back to the VAULT's current tier. A holder's tier is their
    ///         stake-weighted average ENTRY tier and routinely differs, so the vault-level preview
    ///         diverges from execution in both directions. Use this function for a holder-accurate
    ///         quote, and never derive a redemption `minAssets` from the account-less preview.
    ///         Flat 1:1 pricing means gross assets equal shares; only the curve fee is applied here,
    ///         so this figure still excludes MultiVault's own protocol and exit fees.
    /// @dev    NOT an execution-net payout. The returned figure is net of THIS CURVE's withdrawal fee
    ///         only; MultiVault additionally charges its own protocol and exit fees on the same
    ///         redemption, which this contract does not model. To derive a holder-accurate net,
    ///         compose: take `MultiVault.previewRedeem(...)`, add back the account-less curve fee it
    ///         used (`quoteRedeemFee(termId, address(0), grossAssets)`), then subtract `fee` below.
    ///         Do not pass `assetsAfterCurveFee` to a redemption as `minAssets` — it is strictly
    ///         larger than the payout and the slippage guard would reject the redemption.
    /// @param  termId  The term being redeemed from
    /// @param  account The redeeming account
    /// @param  shares  The share amount to preview
    /// @return assetsAfterCurveFee Gross assets less this curve's withdrawal fee for `account`,
    ///                             still gross of MultiVault's own protocol and exit fees
    /// @return fee     The curve withdrawal fee `account` would pay
    function previewRedeemFor(bytes32 termId, address account, uint256 shares)
        external
        view
        returns (uint256 assetsAfterCurveFee, uint256 fee)
    {
        uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultAssets[termId]);
        fee = shares.mulDivUp(_withdrawalFeeBps(tier), BPS);
        assetsAfterCurveFee = shares - fee;
    }

    /// @notice Return the full tier + fee configuration.
    function getConfig() external view returns (DynamicFeeConfig memory) {
        return config;
    }

    /// @notice Cumulative asset upper edge of tier `k` (TRUST wei).
    function tierUpperEdge(uint256 k) external view returns (uint256) {
        return _tierUpperEdge(k);
    }

    /// @notice Asset width of tier `k` (TRUST wei).
    function tierWidthAt(uint256 k) external view returns (uint256) {
        return _tierWidthAt(k);
    }

    /// @notice Tier index for a cumulative-asset position (capped at the top tier).
    function tierOf(uint256 assets) external view returns (uint256) {
        return _tierOf(assets);
    }

    /// @notice Deposit fee (bps) charged while a vault sits in `tier`.
    function depositFeeBps(uint256 tier) external view returns (uint256) {
        return _depositFeeBps(tier);
    }

    /// @notice Withdrawal fee (bps) charged to a holder exiting from `tier`.
    function withdrawalFeeBps(uint256 tier) external view returns (uint256) {
        return _withdrawalFeeBps(tier);
    }

    /* =================================================== */
    /*                  INTERNAL: ACCOUNTING              */
    /* =================================================== */

    /// @dev Bank a user's pending fees into `earned` and re-base their reward debt to the current
    ///      accumulator of their tier.
    /// @dev DELIBERATELY DOES NOT CONSULT `config.minEligibleTierStake` — see the note on {_pendingFor}. This
    ///      banks pending against the tier's accumulator as it stands; whether that tier still clears
    ///      the floor is irrelevant, because the floor only ever prevented further increments.
    function _settle(bytes32 termId, address account) private {
        uint256 tier = userTier[termId][account];
        uint256 accumulated = userStake[termId][account].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
        uint256 debt = rewardDebt[termId][account];
        if (accumulated > debt) {
            earned[account] += accumulated - debt;
        }
        rewardDebt[termId][account] = accumulated;
    }

    /// @dev Distribute a deposit fee `pool` across the prior tiers. A `depositToPriorTierBps`
    ///      slice is paid as a single lump to the nearest OCCUPIED prior tier — the "prior-tier" spike
    ///      that rewards the immediately preceding cohort — and the remainder spreads across the prior
    ///      tiers by the sliding-fulcrum kernel ({_payFulcrumTiers}). The depositor's own pre-deposit
    ///      stake (`excludeStake` at `excludeTier`) is removed from every recipient denominator, and the
    ///      result must clear `config.minEligibleTierStake` to qualify. When no prior tier qualifies the spike
    ///      folds into the fulcrum pool, which routes it to the nearest eligible tier or, failing that,
    ///      the protocol bucket — so the fee is never forfeited or
    ///      double-counted. `depositToPriorTierBps == 0` (the default) reduces to a pure fulcrum
    ///      distribution, identical to the pre-split behavior.
    function _payDepositFee(bytes32 termId, uint256 pool, uint256 tier, uint256 excludeTier, uint256 excludeStake)
        private
    {
        if (pool == 0) return;

        uint256 toPriorTier = pool.mulDiv(config.depositToPriorTierBps, BPS);
        uint256 toFulcrum = pool - toPriorTier;

        // Prior-tier spike -> the single nearest occupied prior tier (depositor excluded). If none is
        // occupied, fold the slice into the fulcrum pool rather than forfeiting it.
        if (toPriorTier > 0) {
            (uint256 recipientTier, uint256 recipientStake) =
                _nearestOccupiedPriorTier(termId, tier, excludeTier, excludeStake);
            // Sentinel, not an occupancy test: the scan above already applies the floor.
            if (recipientStake > 0) {
                accFeePerShare[termId][recipientTier] += toPriorTier.fullMulDiv(ACC_PRECISION, recipientStake);
            } else {
                toFulcrum += toPriorTier;
            }
        }

        // Fulcrum slice (+ any un-spikable remainder) -> the prior tiers by the triangular kernel.
        _payFulcrumTiers(termId, toFulcrum, tier, excludeTier, excludeStake);
    }

    /// @dev Whether `stake` may receive redistributed fees. The single predicate behind every
    ///      recipient gate — the fulcrum spread, the degenerate fallback, the deposit-side spike, the
    ///      diamond slice and both whale-exit reroute scans — so a tier can never be dropped from one
    ///      and admitted to another.
    ///      The `> 0` conjunct is LOAD-BEARING, not defensive. At a zero floor a bare
    ///      `stake >= minEligibleTierStake` is true for an EMPTY recipient set, and the diamond-hands
    ///      branch of {recordRedeem} divides by `denom` immediately — no sentinel stands behind it — so
    ///      a last-holder exit would revert on `fullMulDiv` by zero instead of routing to the protocol.
    ///      The scans would likewise return `(tier, 0)`, saved only by their callers' `> 0` sentinels,
    ///      which is not a guarantee worth resting on. With the conjunct, the shipped default reduces to
    ///      exactly the plain occupancy test it replaced.
    ///
    ///      A tier below the floor earns nothing and sits in NO recipient denominator: it is absent from
    ///      the fulcrum spread, the degenerate whole-pool fallback, the deposit-side prior-tier spike,
    ///      and both whale-exit reroute scans.
    ///      Where its share goes depends on the path, and the two differ deliberately:
    ///      - On the DEPOSIT-fee spread, the excluded tier's share is absorbed by the tiers that already
    ///        qualified, in proportion to their existing kernel weights. The earning window does NOT
    ///        slide down to pull in a further tier, because the triangular kernel returns a hard zero
    ///        beyond `sigma` and crediting a tier it says earns nothing would change the mechanism
    ///        rather than fix the dust case.
    ///      - On the REDEEM-fee diamond slice, a sub-floor residual cohort orphans the slice and it
    ///        accrues to {protocolAccrued} instead of being redistributed. Every redistribution route out
    ///        of that branch concentrates on a single tier and is purchasable by anyone willing to post
    ///        the floor; see the branch itself in {recordRedeem} for the two that were tried.
    ///      Nothing is forfeited on either path — every wei terminates in a recipient tier or in
    ///      {protocolAccrued}. Read that as a statement about THIS mechanism's branches, not about the
    ///      whole fee path: {_creditByWeight} separately counts a slice as assigned when its per-share
    ///      increment truncates to zero, which leaves sub-wei-scale dust unattributable. That is
    ///      pre-existing and is documented on {protocolAccrued} and on {setConfig}.
    ///
    ///      DENOMINATED IN SHARES, matching `tierStake` (see the UNIT COUPLING note above it). Shares and
    ///      assets coincide here only because this curve holds price at exactly 1:1.
    ///
    ///      READ LIVE at distribution time. There is deliberately NO per-epoch or per-position snapshot
    ///      and no migration on change: whatever value is set when a fee lands is the value that applies.
    ///      That is safe because the gate reads `tierStake` directly and stores no derived "eligible
    ///      denominator" state, so nothing can go stale. Already-accrued earnings are equally safe —
    ///      `accFeePerShare` is monotonic and never decremented or cleared, so raising the floor freezes
    ///      a tier's accumulator but never strands what it already holds.
    ///
    ///      Callers pass the EXCLUSION-ADJUSTED stake wherever an exclusion applies — the stake that will
    ///      actually receive the fee, after the depositor's or exiter's own position is removed. Judging
    ///      raw stake instead would reintroduce the very pathology this floor exists to close: a tier
    ///      whose non-excluded cohort is one wei would qualify on its raw total and that one wei would
    ///      capture the whole slice. The trade-off is that a large holder in a tier can make that tier
    ///      ineligible FOR THEIR OWN DEPOSITS ONLY (it stays eligible for everyone else's), redirecting
    ///      their own fee toward whatever other tier they hold. Measured on the shipped ladder at a
    ///      1000e18 floor with a 900e18 honest remainder, that moves sybil recapture of the attacker's
    ///      OWN deposit fee from 40% to 100% and the honest cohort from 60% to 0. It is an amplification
    ///      of the accepted no-dwell design rather than a new class — the value at stake is the
    ///      attacker's own fee, and it requires the honest remainder of the tier to itself be below the
    ///      floor, which is exactly the case the floor exists to drop — but the 100% figure is the number
    ///      to weigh when choosing a floor, not the 40%.
    function _isEligibleStake(uint256 stake) private view returns (bool) {
        return stake > 0 && stake >= config.minEligibleTierStake;
    }

    /// @dev Triangular fulcrum weight for a prior tier at distance `dist` from the fulcrum: a tent
    ///      that peaks at the fulcrum and falls off linearly to a hard zero at `sigma`, i.e.
    ///      `max(0, 1 - dist/sigma)`. `dist` and `sigma` are in `TIER_PRECISION` tier units; the
    ///      returned weight is in `TIER_PRECISION` (0..1e18). Pure integer math — no transcendental.
    function _triangularWeight(uint256 dist, uint256 sigma) private pure returns (uint256) {
        uint256 ratio = dist.mulDiv(TIER_PRECISION, sigma);
        return ratio < TIER_PRECISION ? TIER_PRECISION - ratio : 0;
    }

    /// @dev Distance (in `TIER_PRECISION` units) from a prior tier at integer distance `d` to the
    ///      fulcrum `dStar`.
    function _fulcrumDistance(uint256 d, uint256 dStar) private pure returns (uint256) {
        uint256 dP = d * TIER_PRECISION;
        return dP > dStar ? dP - dStar : dStar - dP;
    }

    /// @dev Distribute `pool` across the prior tiers `[0, tier)` by the triangular fulcrum kernel.
    ///      The peak sits at `dStar = (1 - fulcrumAlpha/BPS) * span` tiers from the source (fraction of
    ///      the span, so it slides up the ladder as the vault grows); each ELIGIBLE prior tier earns
    ///      `max(0, 1 - |d - dStar|/sigma)`, normalized over eligible tiers and split pro-rata by stake,
    ///      with `excludeStake` removed from the recipient denominator at `excludeTier`. A tier below
    ///      `config.minEligibleTierStake` is absent from that normalization, so its share is absorbed by the
    ///      tiers that already qualified in proportion to their existing weights — the earning window
    ///      does NOT slide down to pull in a further tier, because the kernel returns a hard zero beyond
    ///      `sigma` and crediting a tier it says earns nothing would change the mechanism. If a tight
    ///      `sigma` zeroes every eligible tier's weight, the whole pool goes to the eligible tier
    ///      nearest the fulcrum (nearest-first tie-break) rather than leaking to the protocol; only when
    ///      NO prior tier qualifies, and any rounding remainder, accrue to `protocolAccrued`. The
    ///      pass-1 weighting and the degenerate-award scan are extracted to keep this write path within
    ///      the 16-slot stack ceiling.
    function _payFulcrumTiers(bytes32 termId, uint256 pool, uint256 tier, uint256 excludeTier, uint256 excludeStake)
        private
    {
        if (pool == 0) return;

        // No prior tiers (first-tier deposit): nothing to reward, route to the protocol bucket.
        uint256 span = tier;
        if (span == 0) {
            protocolAccrued += pool;
            emit ProtocolAccruedIncreased(pool);
            return;
        }

        // `weights`/`stakes` are indexed by `d - 1` (d = 1 is the nearest prior tier `tier - 1`;
        // d = span is the farthest, tier 0). `weights[i] > 0` implies the tier is ELIGIBLE — occupancy
        // alone is no longer sufficient once `config.minEligibleTierStake` is live.
        uint256 dStar = ((BPS - config.fulcrumAlpha) * span).mulDiv(TIER_PRECISION, BPS);
        uint256[] memory weights = new uint256[](span);
        uint256[] memory stakes = new uint256[](span);
        uint256 sumWeights = _weighPriorTiers(termId, span, dStar, excludeTier, excludeStake, weights, stakes);

        // Degenerate: the window missed every occupied tier (or there is no occupied tier). Award to
        // the nearest occupied tier, else to the protocol — never silently forfeit the pool.
        if (sumWeights == 0) {
            _awardNearestOrProtocol(termId, pool, span, dStar, stakes);
            return;
        }

        // Credit each occupied tier; any rounding remainder accrues to the protocol bucket.
        uint256 unassigned = pool - _creditByWeight(termId, pool, span, sumWeights, weights, stakes);
        if (unassigned > 0) {
            protocolAccrued += unassigned;
            emit ProtocolAccruedIncreased(unassigned);
        }
    }

    /// @dev Pass 2 of {_payFulcrumTiers}: credit each occupied prior tier its normalized, stake-pro-rata
    ///      share of `pool` and return the total assigned (the shortfall vs `pool` is rounding dust).
    function _creditByWeight(
        bytes32 termId,
        uint256 pool,
        uint256 span,
        uint256 sumWeights,
        uint256[] memory weights,
        uint256[] memory stakes
    ) private returns (uint256 assigned) {
        for (uint256 d = 1; d <= span;) {
            uint256 w = weights[d - 1];
            if (w > 0) {
                uint256 share = pool.mulDiv(w, sumWeights);
                if (share > 0) {
                    accFeePerShare[termId][span - d] += share.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
                    assigned += share;
                }
            }
            unchecked {
                ++d;
            }
        }
    }

    /// @dev Pass 1 of {_payFulcrumTiers}: fill `weights` and `stakes` (both length `span`, indexed by
    ///      `d - 1`) for every prior tier and return the summed weights over occupied tiers.
    function _weighPriorTiers(
        bytes32 termId,
        uint256 span,
        uint256 dStar,
        uint256 excludeTier,
        uint256 excludeStake,
        uint256[] memory weights,
        uint256[] memory stakes
    ) private view returns (uint256 sumWeights) {
        uint256 sigma = config.kernelSpread;
        for (uint256 d = 1; d <= span;) {
            uint256 targetTier = span - d; // == tier - d
            uint256 recipientStake = tierStake[termId][targetTier];
            if (targetTier == excludeTier) {
                recipientStake -= excludeStake;
            }
            // Zeroing an INELIGIBLE tier's entry here, rather than re-testing at each read site, is what
            // makes "`stakes[i] > 0` implies eligible" a structural invariant of this array. Both
            // readers ({_creditByWeight} and {_awardNearestOrProtocol}) depend on it and neither
            // re-checks. Dropping this and gating only `sumWeights` would be strictly worse than having
            // no floor at all: a dust tier would be excluded from the proportional spread and then
            // handed the ENTIRE pool by the degenerate fallback, which scans this same array.
            if (!_isEligibleStake(recipientStake)) {
                recipientStake = 0;
            }
            stakes[d - 1] = recipientStake;
            if (recipientStake > 0) {
                uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma);
                weights[d - 1] = w;
                sumWeights += w;
            }
            unchecked {
                ++d;
            }
        }
    }

    /// @dev Degenerate branch of {_payFulcrumTiers}: award the whole `pool` to the ELIGIBLE tier nearest
    ///      the fulcrum, reusing the `stakes` computed in pass 1. Falls through to the protocol bucket
    ///      only when no prior tier qualifies.
    ///      TIE-BREAK, stated precisely because two tiers can be exactly equidistant from the fulcrum
    ///      whenever `dStar` lands on a half-integer (e.g. `span = 3, alpha = 0.5` puts it at 1.5, so
    ///      `d = 1` and `d = 2` are both 0.5 away). The scan runs `d = 1..span` — nearest prior tier
    ///      first — and keeps the incumbent on equality via strict `<`, so a tie resolves to the tier
    ///      NEAREST the source. That is the intended rule on both legs: whichever eligible cohort is
    ///      closest wins, regardless of the direction the scan approached from.
    ///      The two `> 0` tests below are sentinels, not occupancy tests: {_weighPriorTiers} zeroes the
    ///      entry of any tier that fails {_isEligibleStake}, so a non-zero entry here is eligible by
    ///      construction. That invariant is the whole reason this function needs no floor logic of its
    ///      own — and it is also why this is the branch to check first if the floor ever appears to
    ///      hand a whole pool to a dust tier.
    function _awardNearestOrProtocol(bytes32 termId, uint256 pool, uint256 span, uint256 dStar, uint256[] memory stakes)
        private
    {
        uint256 bestTier;
        uint256 bestStake;
        uint256 bestDist = type(uint256).max;
        for (uint256 d = 1; d <= span;) {
            uint256 recipientStake = stakes[d - 1];
            if (recipientStake > 0) {
                uint256 dist = _fulcrumDistance(d, dStar);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestTier = span - d;
                    bestStake = recipientStake;
                }
            }
            unchecked {
                ++d;
            }
        }
        if (bestStake > 0) {
            accFeePerShare[termId][bestTier] += pool.fullMulDiv(ACC_PRECISION, bestStake);
        } else {
            protocolAccrued += pool;
            emit ProtocolAccruedIncreased(pool);
        }
    }

    /* =================================================== */
    /*                 INTERNAL: TIER MATH               */
    /* =================================================== */

    /// @dev Asset width of tier `k`, DEFINED as the span between its cumulative edges:
    ///      `width(k) = edge(k) - edge(k-1)` (with `edge(-1) = 0`, so `width(0) = edge(0) = width0`).
    ///      Conceptually this is the compounding law `width0 * (1+g)^k` — each tier is `(1+g)x` the one
    ///      below it — but it is derived from {_tierUpperEdge} rather than computed independently. That
    ///      is load-bearing: the edges are the single source of truth for tier boundaries ({_tierOf})
    ///      and for the piecewise fee walk, which charges each band's `edge`-to-`edge` span. Computing
    ///      the width from its own rounded `rpow` would let `edge(k) - edge(k-1)` and the advertised
    ///      width disagree by a wei or two for non-exactly-representable ratios; deriving it here makes
    ///      the reported width equal the fee-charged band by construction. `_tierUpperEdge` is
    ///      strictly increasing (config-time probe + monotonicity fuzz), so the subtraction never
    ///      underflows.
    function _tierWidthAt(uint256 k) private view returns (uint256) {
        if (k == 0) return _tierUpperEdge(0);
        return _tierUpperEdge(k) - _tierUpperEdge(k - 1);
    }

    /// @dev Cumulative asset upper edge of tier `k` (Σ_{j<=k} width(j)), in closed form:
    ///      `edge(k) = width0 * ((1+g)^(k+1) - 1) / g`, the geometric-series sum.
    function _tierUpperEdge(uint256 k) private view returns (uint256) {
        uint256 g = config.growthGBps;
        if (g == 0) return config.width0 * (k + 1); // constant width -> plain multiple
        uint256 ratioWad = (BPS + g).fullMulDiv(WAD, BPS); // (1+g) in WAD
        uint256 powWad = FixedPointMathLib.rpow(ratioWad, k + 1, WAD); // (1+g)^(k+1) in WAD
        uint256 gWad = g.fullMulDiv(WAD, BPS); // g in WAD
        return config.width0.fullMulDiv(powWad - WAD, gWad);
    }

    /// @dev First tier `k` whose upper edge exceeds `assets`, capped at the top tier.
    function _tierOf(uint256 assets) private view returns (uint256) {
        if (assets == 0) return 0;
        uint256 tierCount = config.tierCount;
        for (uint256 k = 0; k < tierCount;) {
            if (assets < _tierUpperEdge(k)) return k;
            unchecked {
                ++k;
            }
        }
        return tierCount - 1;
    }

    /// @dev Nearest tier to `fromTier` holding ELIGIBLE stake, searched ABOVE first (`fromTier+1` upward
    ///      to the top), then below (`fromTier-1` down to 0). Returns `(tier, stake)`, or `(0, 0)` when
    ///      no other tier qualifies. Above-first is deliberate: it routes a departing whale's orphaned
    ///      exit fee to the stayer who sat above them. Bounded by `tierCount` (<= MAX_TIER_COUNT).
    ///      Both scans apply `config.minEligibleTierStake`, so a dust tier can no longer intercept the whole
    ///      slice simply by being nearest. Unlike the deposit-side scan there is no exclusion to apply:
    ///      the caller reaches this branch only once the exiting tier has been established as having no
    ///      eligible residual cohort, and both loops skip `fromTier` structurally.
    function _nearestOccupiedTier(bytes32 termId, uint256 fromTier) private view returns (uint256 tier, uint256 stake) {
        uint256 tierCount = config.tierCount;
        for (uint256 k = fromTier + 1; k < tierCount;) {
            uint256 s = tierStake[termId][k];
            if (_isEligibleStake(s)) return (k, s);
            unchecked {
                ++k;
            }
        }
        for (uint256 k = fromTier; k > 0;) {
            unchecked {
                --k;
            }
            uint256 s = tierStake[termId][k];
            if (_isEligibleStake(s)) return (k, s);
        }
        return (0, 0);
    }

    /// @dev Nearest ELIGIBLE tier strictly below `tier` (within the prior tiers `[0, tier)`), searched
    ///      downward from `tier - 1`, with `excludeStake` removed at `excludeTier` so the depositor's
    ///      own pre-deposit stake can never be a recipient of its own fee. Returns `(tier, stake)` after
    ///      exclusion, or `(0, 0)` when no prior tier holds eligible stake. Bounded by `tierCount`.
    ///      `config.minEligibleTierStake` is applied to the POST-exclusion stake, so the prior-tier spike
    ///      cannot be intercepted by a dust tier. This gate matters even though the spike is dormant at
    ///      the shipped `depositToPriorTierBps == 0`: without it, turning the spike on would hand
    ///      a sub-floor tier the whole lump that the fulcrum spread had just excluded it from.
    function _nearestOccupiedPriorTier(bytes32 termId, uint256 tier, uint256 excludeTier, uint256 excludeStake)
        private
        view
        returns (uint256 recipientTier, uint256 recipientStake)
    {
        for (uint256 k = tier; k > 0;) {
            unchecked {
                --k;
            }
            uint256 s = tierStake[termId][k];
            if (k == excludeTier) {
                s -= excludeStake;
            }
            if (_isEligibleStake(s)) return (k, s);
        }
        return (0, 0);
    }

    /// @dev The tier's manual override if set, else the formulaic min(cap, base + tier*growth).
    function _depositFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        uint256 cap = config.depositCapBps;
        if (tierOverride.isSet) {
            // Clamp against the LIVE cap, not the cap that was in force when the override was set,
            // so that lowering `depositCapBps` tightens every tier uniformly.
            uint256 overrideFee = tierOverride.depositFeeBps;
            return overrideFee < cap ? overrideFee : cap;
        }
        uint256 fee = config.depositBaseBps + tier * config.depositGrowthBps;
        return fee < cap ? fee : cap;
    }

    /// @dev Piecewise deposit fee: walks the tier bands from `startAssets` and charges each portion
    ///      of `baseAssets` at its own band's rate. Traversal is measured over the fee base (not the
    ///      post-fee net stake) — a deliberate, slightly conservative approximation that keeps the
    ///      quote a pure function of (vault state, base), so the calc-path quote and the record-hook
    ///      forward remain equal by construction. The top tier absorbs everything past its lower
    ///      edge, bounding the walk at `tierCount` (≤ MAX_TIER_COUNT) iterations; a deposit contained
    ///      in a single band costs one multiplication.
    function _piecewiseDepositFee(uint256 startAssets, uint256 baseAssets) private view returns (uint256 fee) {
        uint256 remaining = baseAssets;
        uint256 cursor = startAssets;
        uint256 tier = _tierOf(startAssets);
        uint256 topTier = config.tierCount - 1;

        while (remaining > 0) {
            uint256 chunk = remaining;
            if (tier < topTier) {
                // `cursor` is strictly below this band's upper edge, so `room` is nonzero.
                uint256 room = _tierUpperEdge(tier) - cursor;
                if (room < chunk) chunk = room;
            }
            fee += chunk.mulDivUp(_depositFeeBps(tier), BPS);
            remaining -= chunk;
            cursor += chunk;
            unchecked {
                ++tier;
            }
        }
    }

    /// @dev The tier's manual override if set, else the formulaic min(cap, base + tier*growth).
    function _withdrawalFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        uint256 cap = config.withdrawalCapBps;
        if (tierOverride.isSet) {
            // Clamp against the LIVE cap, not the cap that was in force when the override was set,
            // so that lowering `withdrawalCapBps` tightens every tier uniformly.
            uint256 overrideFee = tierOverride.withdrawalFeeBps;
            return overrideFee < cap ? overrideFee : cap;
        }
        uint256 fee = config.withdrawalBaseBps + tier * config.withdrawalGrowthBps;
        return fee < cap ? fee : cap;
    }

    /// @dev round(avgEntryTier) (half-up), capped at the top tier.
    function _roundTier(uint256 avgTierScaled) private view returns (uint256) {
        uint256 rounded = (avgTierScaled + TIER_PRECISION / 2) / TIER_PRECISION;
        uint256 maxTier = config.tierCount - 1;
        return rounded > maxTier ? maxTier : rounded;
    }

    /* =================================================== */
    /*                 INTERNAL: CONFIG                  */
    /* =================================================== */

    /// @dev Validate and store the tier + fee schedule. `width0` and `growthGBps` are bounded so the
    ///      closed-form edge math can never overflow and a fat-fingered schedule cannot brick
    ///      `tierOf` (and with it every deposit/redeem on the dynamic curve).
    function _setConfig(DynamicFeeConfig calldata _config) private {
        if (_config.width0 == 0 || _config.width0 > type(uint128).max) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.tierCount == 0 || _config.tierCount > MAX_TIER_COUNT) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.growthGBps > 100 * BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        // Grow-only once live: shrinking could strand occupied buckets above the schedule.
        if (config.tierCount != 0 && _config.tierCount < config.tierCount) {
            revert DynamicFeeFlatPriceCurve_TierCountCannotShrink();
        }
        // Fulcrum position is a fraction of the span; `kernelSpread` (σ) must be non-zero (it divides
        // the weight) and is bounded so the triangular math stays well clear of overflow.
        if (_config.fulcrumAlpha > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.kernelSpread == 0 || _config.kernelSpread > MAX_KERNEL_SPREAD) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        // Caps are bounded by the immutable ceilings, not by `BPS`. See {MAX_DEPOSIT_CAP_BPS} and
        // {MAX_WITHDRAWAL_CAP_BPS}: a cap near `BPS` can underflow MultiVault's fee netting on the
        // deposit side and can silently zero a redeemer's payout on the withdrawal side.
        if (_config.depositBaseBps > _config.depositCapBps || _config.depositCapBps > MAX_DEPOSIT_CAP_BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.withdrawalBaseBps > _config.withdrawalCapBps || _config.withdrawalCapBps > MAX_WITHDRAWAL_CAP_BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.withdrawalToFulcrumTiersBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.depositToPriorTierBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        // Bounded by an immutable ceiling rather than by `BPS` like the share knobs: this one is an
        // absolute stake amount, and the ceiling is what keeps governance from starving the fee stream.
        if (_config.minEligibleTierStake > MAX_MIN_ELIGIBLE_TIER_STAKE) {
            revert DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake();
        }

        // Captured before the store so a raise is monitorable on its own. {ConfigUpdated} carries only
        // the ladder shape, and no config field emits its previous value; the eligibility floor is the
        // one parameter that silently changes WHO earns, so it gets a dedicated before/after signal.
        uint256 previousMinEligibleTierStake = config.minEligibleTierStake;

        config = _config;

        // Probe the top edge under the stored schedule. The compounding math would overflow on an
        // over-steep ladder, and this computation reverts (checked `rpow` / `fullMulDiv`) — so a config
        // that could brick `tierOf` on the deposit/redeem hot path is rejected here, before any
        // position exists, rather than after. A zero top edge (degenerate schedule) is rejected too.
        if (_tierUpperEdge(_config.tierCount - 1) == 0) revert DynamicFeeFlatPriceCurve_InvalidConfig();

        emit ConfigUpdated(
            _config.width0, _config.tierCount, _config.growthGBps, _config.fulcrumAlpha, _config.kernelSpread
        );
        if (_config.minEligibleTierStake != previousMinEligibleTierStake) {
            emit MinEligibleTierStakeUpdated(previousMinEligibleTierStake, _config.minEligibleTierStake);
        }
    }
}
