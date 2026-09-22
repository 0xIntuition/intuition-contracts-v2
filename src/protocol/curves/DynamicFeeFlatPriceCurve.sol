// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { LibBit } from "solady/utils/LibBit.sol";
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
 * @notice Flat-price bonding curve with a tiered fee economy. Pricing is {LinearCurve}'s, unmodified
 *         — the vault holds 1:1 — and everything curve-specific is in the fees: a tunable tier
 *         ladder, per-tier deposit and redeem rates, an optional sparse per-tier manual override,
 *         and the pull-based accounting that redistributes each fee to earlier cohorts. The fee
 *         accounting lives in the curve, so the registry-resolved curve address and the fee-routing
 *         target are the same contract. {MultiVault} reads the fee surface through the {IBaseCurve}
 *         hook getters and forwards each fee as native TRUST through the record hooks; holders pull
 *         their earnings with {claim}.
 *
 * @dev    Tiers are bands of cumulative net vault assets, widening geometrically. The edges are the
 *         single source of truth: {tierOf}, {tierWidthAt} and the piecewise fee walk all key off
 *         {_tierUpperEdge}, so the advertised width equals the band a deposit is charged on.
 *
 * @dev    A deposit is replayed band by band: each band is charged its own rate and distributes its
 *         slice of the fee to the tiers strictly below it, before that band's own stake lands
 *         ({_replayDepositBands}). Stake is held as lots, one per holder and tier, each keyed to
 *         the band it landed in. A redeem unwinds the holder's lots highest tier first, charges each
 *         portion at its own lot's rate, and splits each portion between that tier's other holders
 *         and the prior tiers ({recordRedeem}). Both legs reach the prior tiers through the same
 *         sliding-fulcrum triangular kernel ({_payFulcrumTiers}), and both rates come from
 *         {_depositFeeBps} / {_redeemFeeBps}.
 *
 * @dev    Credit uses an O(1) MasterChef-style accumulator rather than an O(cohort) push:
 *         `accFeePerShare[termId][tier]` tracks fee per unit of stake, and a lot's unsettled amount
 *         is `lotStake * accFeePerShare[tier] - lotRewardDebt`. A holder's position is the set of
 *         lots flagged in `lotMask`, at most one per tier, so settling is O(lots) with lots bounded
 *         by `tierCount`. Settling moves a term's unsettled amount into the account-wide settled
 *         balance that {claim} pays out. The redeem leg excludes the exiter exactly, by omitting
 *         their residual lots from every recipient denominator and re-basing their lot debts; the
 *         deposit leg applies no such subtraction.
 *
 * @dev    Custody: this contract holds the redistributed fee TRUST (native), and principal stays in
 *         {MultiVault} at par. `Ownable`, and on governed networks the owner is the parameters
 *         `TimelockController`, so every fee action runs the same Safe and timelock path as the
 *         equivalent MultiVault setters. Integer accumulator division leaves sub-wei-per-share dust
 *         as an unattributed contract balance; undistributable fee accrual goes to {protocolAccrued}.
 *         Neither path touches principal.
 */
contract DynamicFeeFlatPriceCurve is
    LinearCurve,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    IDynamicFeeFlatPriceCurve
{
    using FixedPointMathLib for uint256;
    using LibBit for uint256;
    using LibSort for uint256[];

    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    /// @notice Basis-points denominator for all fee rates.
    uint256 public constant BPS = 10_000;

    /// @notice Fixed-point scale for the per-tier fee accumulator.
    uint256 public constant ACC_PRECISION = 1e18;

    /// @notice Fixed-point scale for tier distances in the fulcrum kernel.
    uint256 public constant TIER_PRECISION = 1e18;

    /// @notice Sentinel returned by {userTopTier} and carried by {DepositRecorded} when the account
    ///         holds no lot: one past the highest tier index a 256-bit lot mask can hold.
    uint256 public constant NO_LOT = 256;

    /// @dev Fixed-point one, for the compounding tier-width math.
    uint256 private constant WAD = 1e18;

    /// @dev Scale of an effective weight in the fulcrum spread: a kernel weight in `TIER_PRECISION`
    ///      times a fill ratio carried at `TIER_PRECISION`, so a tier at the edge of the window, whose
    ///      kernel weight is a single unit, keeps its share instead of rounding to nothing.
    uint256 private constant WEIGHT_PRECISION = TIER_PRECISION * TIER_PRECISION;

    /// @notice Upper bound on the triangular spread `σ`, in `TIER_PRECISION` tier units. Bounds the
    ///         earning window and keeps the weight math well away from overflow; far wider than any
    ///         legible schedule needs (the whole ladder is <= MAX_TIER_COUNT tiers).
    uint256 public constant MAX_KERNEL_SPREAD = 64e18;

    /// @notice Upper bound on the tier count (bounds the `tierOf` / edge loops).
    /// @dev    Also bounds the worst-case cost of a deposit: a deposit sweeping the whole ladder walks
    ///         one band per tier and distributes from each, so hook cost grows with the square of the
    ///         tier count. The depositor pays it and cannot impose it on another account.
    ///         {setConfig} makes `tierCount` grow-only, so lengthening the ladder is a one-way door
    ///         that permanently raises that floor, and the schedule is sized against the chain's block
    ///         gas limit before it is grown.
    uint256 public constant MAX_TIER_COUNT = 64;

    /// @notice Hard ceiling on `depositCapBps`, above which no schedule may be stored.
    /// @dev    The curve fee is netted out of an amount MultiVault has already reduced by its own
    ///         entry, protocol and atom-wallet fees, so a curve cap approaching `BPS` can underflow
    ///         that subtraction and brick every deposit on the curve. This ceiling bounds the curve's
    ///         contribution to that envelope, not the whole envelope: `MultiVault.setVaultFees` is
    ///         timelock-gated but carries no numeric bound, so a sufficiently extreme vault schedule
    ///         could still exhaust the netting. Immutable, since it bounds what governance may
    ///         configure.
    uint256 public constant MAX_DEPOSIT_CAP_BPS = 2000;

    /// @notice Hard ceiling on `redeemCapBps`, above which no schedule may be stored.
    /// @dev    Bounds the redeem side of the same envelope, and with it the zero-payout mode: a
    ///         redeem rate strictly inside a near-`BPS` cap consumes the entire redemption and
    ///         pays the redeemer nothing without reverting. Capping the cap removes that
    ///         configuration from the reachable set. Immutable.
    uint256 public constant MAX_REDEEM_CAP_BPS = 2000;

    /* =================================================== */
    /*                    STATE VARIABLES                  */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    address public multiVault;

    /// @dev The tunable tier + fee schedule, internal and exposed through {getConfig}.
    DynamicFeeConfig internal config;

    /// @notice Sparse per-tier manual fee override; `isSet` distinguishes an explicit 0-bps rate from
    ///         "inherit the formula". Consulted before the formulaic schedule in {_depositFeeBps} /
    ///         {_redeemFeeBps}, so the piecewise deposit walk picks up each traversed band's own
    ///         override automatically.
    mapping(uint256 tier => TierFeeOverride tierOverride) public tierFeeOverride;

    /// @notice Cumulative net user stake per vault (mirrors the spec's `totalAssets`; excludes the
    ///         MultiVault min-share seed). Drives the current tier for fee rate + distribution.
    /// @dev    Unit coupling, not otherwise asserted. This accumulates share amounts (the record hooks
    ///         are handed `sharesForReceiver` / `shares`), while the tier ladder it is compared
    ///         against (`_tierUpperEdge`, `width0`) is denominated in assets (TRUST wei). The two
    ///         agree only because a vault on this curve holds price at exactly 1:1: MultiVault routes
    ///         entry and exit fees to the default curve's vault, never to a non-default curve's, so
    ///         this vault's `totalAssets / totalShares` never drifts off par. Every tier decision, and
    ///         so every fee rate, depends on that. Crediting pro-rata value to a non-default curve's
    ///         vault would make the ladder read the wrong quantity.
    mapping(bytes32 termId => uint256 stake) public vaultStake;

    /// @notice Sum of the lots sitting at `tier`: the stake that entered through that band and has
    ///         not been redeemed. Every lot stays at its entry tier for life.
    mapping(bytes32 termId => mapping(uint256 tier => uint256 stake)) public tierStake;

    /// @notice ACC_PRECISION-scaled accumulated fee per unit of stake, per vault and tier.
    mapping(bytes32 termId => mapping(uint256 tier => uint256 acc)) public accFeePerShare;

    /// @notice A user's tracked stake in a vault (equal to their dynamic-curve share balance), the
    ///         sum of their lots.
    mapping(bytes32 termId => mapping(address account => uint256 stake)) public userStake;

    /// @notice A user's lot at `tier`: the stake they hold that entered through that band. A holder
    ///         has at most one lot per tier; a later deposit landing in the same band tops it up.
    mapping(bytes32 termId => mapping(address account => mapping(uint256 tier => uint256 stake))) public lotStake;

    /// @notice A lot's settled reward debt: `lotStake * accFeePerShare[tier] / ACC_PRECISION`.
    mapping(bytes32 termId => mapping(address account => mapping(uint256 tier => uint256 debt))) public lotRewardDebt;

    /// @notice Bit `tier` is set iff `lotStake[termId][account][tier] > 0`. The position's index: the
    ///         settle and unwind loops walk its set bits, and its highest bit is the holder's top lot.
    mapping(bytes32 termId => mapping(address account => uint256 mask)) public lotMask;

    /// @notice Settled native earnings per account, across all terms, awaiting {claim}.
    mapping(address account => uint256 amount) internal settledEarnings;

    /// @notice Fee accrual with no eligible recipient, sweepable by the owner.
    /// @dev    Mostly whole slices rather than rounding dust. The balance accrues from:
    ///         (1) a deposit or redeem fee whose source tier is 0, leaving no prior tier to spread
    ///             to ({_payFulcrumTiers} short-circuits on `span == 0`). This keys on the source
    ///             tier, not on whether holders exist: lots stay at their entry tier, so holders
    ///             can remain recorded at higher tiers with non-zero `tierStake` while `vaultStake`
    ///             has fallen back inside `edge(0)`;
    ///         (2) a fulcrum pool for which no prior tier is eligible at all, neither inside the
    ///             kernel window nor in the fill-only fallback across the whole prior ladder,
    ///             including the last-redeemer case;
    ///         (3) the part of a pool that no stake is there to earn at the schedule rate: the spread
    ///             weights each tier by its occupancy, so over-full tiers absorb what thinner ones
    ///             leave, but once the prior ladder as a whole holds less than its widths every tier
    ///             is paid at the schedule ceiling and the shortfall lands here ({_payFulcrumTiers});
    ///         (4) the part of a single-target credit, the deposit spike or a redeemed lot's
    ///             exiting-tier slice, that no candidate tier could take at its fill
    ///             ({_creditDownward}, {_rerouteExitSlice}). Every tier has already taken its fill of
    ///             it, so the spread would pay the same tiers a second time.
    ///         All four are the intended terminal behaviour: with no cohort to reward at the schedule
    ///         rate, the protocol absorbs the fee rather than forfeiting it or paying a thin seat above
    ///         the schedule. The name means "undistributable", not "negligible" — for a young vault it
    ///         can be the whole fee stream, since every first band and every exit while the vault sits
    ///         in tier 0 has no prior tier to reach.
    ///
    ///         Not covered by this balance: {_creditByWeight} counts a slice as assigned even when its
    ///         per-share increment floors to zero. Such a slice credits no account, is not added here,
    ///         and stays in the contract balance with no path out, since this sweep pays only
    ///         `protocolAccrued`. The per-band replay makes that dust scale with bands times prior
    ///         tiers rather than prior tiers alone. Recovering it would need a second accumulator or a
    ///         per-tier remainder ledger, each costing more gas per deposit than the dust is worth.
    uint256 public protocolAccrued;

    /* =================================================== */
    /*                        EVENTS                       */
    /* =================================================== */

    event ConfigUpdated(
        uint256 width0,
        uint256 tierCount,
        uint256 tierWidthGrowthBps,
        uint256 depositFulcrumAlphaBps,
        uint256 depositKernelSpread,
        uint256 redeemFulcrumAlphaBps,
        uint256 redeemKernelSpread
    );
    /// @notice One deposit, summarized. `sourceTier` is the vault's tier before the deposit (the
    ///         first band the stake traversed); `topTier` is the account's highest lot after it, or
    ///         `NO_LOT` when the account still holds none. {DepositBandRecorded} carries the
    ///         per-band breakdown that produced them.
    event DepositRecorded(
        bytes32 indexed termId,
        address indexed account,
        uint256 shares,
        uint256 fee,
        uint256 sourceTier,
        uint256 topTier
    );

    /// @notice One tier band of one deposit: the portion of the stake that landed in `bandTier` and
    ///         the portion of the fee charged and distributed from it. Emitted once per band a
    ///         deposit traverses, in ascending band order, so the decomposition behind a
    ///         {DepositRecorded} is observable without re-deriving the tier ladder off-chain.
    event DepositBandRecorded(
        bytes32 indexed termId, address indexed account, uint256 bandTier, uint256 bandStake, uint256 bandFee
    );
    /// @notice One redeem, summarized. `topTier` is the account's highest lot before the unwind,
    ///         the first lot the redeem drew from. {RedeemLotRecorded} carries the per-lot breakdown.
    event RedeemRecorded(bytes32 indexed termId, address indexed account, uint256 shares, uint256 fee, uint256 topTier);

    /// @notice One lot's portion of one redeem: `lotShares` taken from the account's lot at
    ///         `lotTier` and the portion of the fee charged and distributed for it. Emitted once per
    ///         lot the redeem draws from, highest tier first.
    event RedeemLotRecorded(
        bytes32 indexed termId, address indexed account, uint256 lotTier, uint256 lotShares, uint256 lotFee
    );
    event Claimed(address indexed account, uint256 amount);
    event ProtocolAccruedIncreased(uint256 amount);
    event ProtocolSwept(address indexed to, uint256 amount);
    event RedeemFeeRerouted(bytes32 indexed termId, uint256 exitTier, uint256 recipientTier, uint256 amount);
    event TierFeeOverrideSet(uint256 indexed tier, uint16 depositFeeBps, uint16 redeemFeeBps);
    event TierFeeOverrideCleared(uint256 indexed tier);
    event MinEligibleTierStakeUpdated(uint256 previousMinEligibleTierStakeBps, uint256 newMinEligibleTierStakeBps);

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
    /// @dev    The check lives in {_onlyMultiVault} so the modifier inlines a single jump per use
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
    ///         inert: proxy deployment invokes this 4-arg initializer atomically, consuming the
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
    /// @dev    A retune re-prices the ladder going forward and is never applied retroactively:
    ///         earnings already accrued under the old schedule are preserved exactly, so a retune
    ///         cannot affect solvency. A rate moving from 10% to 12% applies only to subsequent
    ///         activity.
    ///
    ///         Positions are not migrated. The accumulators are index-keyed
    ///         (`accFeePerShare[termId][tier]`), and changing `width0`, `tierWidthGrowthBps` or `tierCount`
    ///         changes what each index means without moving any lot between indices. A lot keeps
    ///         its recorded tier while that tier denotes a different band, so the fee stream
    ///         re-targets: the cohort a slice was promised to is not necessarily the cohort that
    ///         receives it afterwards. Migrating positions instead would be unbounded in the number
    ///         of holders, which makes a retune an economic action rather than a parameter tweak.
    ///         {ConfigUpdated} emits the new ladder shape, which makes one observable.
    ///
    ///         `tierCount` may only grow once set, so no occupied lot tier can be stranded above the
    ///         schedule (the distribution walk always covers every live tier index).
    /// @param _config The new configuration
    function setConfig(DynamicFeeConfig calldata _config) external onlyOwner {
        _setConfig(_config);
    }

    /// @notice Set a sparse manual fee override for a single tier (replaces the formula for that tier).
    /// @dev    Overriding one tier does not touch any other tier. The stored rates fully replace the
    ///         formulaic `min(cap, base + tier*growth)` but must stay within the schedule's declared
    ///         per-tier caps (`depositCapBps` / `redeemCapBps`), which are themselves bounded by
    ///         the immutable {MAX_DEPOSIT_CAP_BPS} / {MAX_REDEEM_CAP_BPS} ceilings.
    ///         An override is also clamped at read time against the live cap, so lowering a cap
    ///         tightens every tier uniformly, including tiers that already carry an override, with no
    ///         separate clear-then-retune step.
    ///         Those two bounds together keep a redeem rate from consuming a whole redemption.
    ///         That mode does not surface as a revert from the rate itself: absent a bound, a rate
    ///         strictly inside a near-`BPS` cap would let a redemption succeed while paying the
    ///         redeemer zero and burning their shares. The ceilings remove that configuration from
    ///         the reachable set, and `MultiVault` carries an independent floor that rejects a
    ///         redemption returning no assets.
    ///         An explicit 0-bps rate remains expressible (via `isSet == true`). Only tiers within the
    ///         live `tierCount` may be overridden.
    /// @param tier The tier index to override (`< config.tierCount`)
    /// @param newDepositFeeBps The manual deposit fee for the tier, in bps (`<= config.depositCapBps`)
    /// @param newRedeemFeeBps The manual redeem fee for the tier, in bps (`<= config.redeemCapBps`)
    function setTierFeeOverride(uint256 tier, uint16 newDepositFeeBps, uint16 newRedeemFeeBps) external onlyOwner {
        if (tier >= config.tierCount) revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
        if (newDepositFeeBps > config.depositCapBps || newRedeemFeeBps > config.redeemCapBps) {
            revert DynamicFeeFlatPriceCurve_InvalidTierOverride();
        }
        tierFeeOverride[tier] =
            TierFeeOverride({ isSet: true, depositFeeBps: newDepositFeeBps, redeemFeeBps: newRedeemFeeBps });
        emit TierFeeOverrideSet(tier, newDepositFeeBps, newRedeemFeeBps);
    }

    /// @notice Clear a tier's manual override, restoring the formulaic rate for that tier.
    /// @param tier The tier index whose override is cleared
    function clearTierFeeOverride(uint256 tier) external onlyOwner {
        delete tierFeeOverride[tier];
        emit TierFeeOverrideCleared(tier);
    }

    /// @notice Sweep `protocolAccrued` — undistributable fee accrual — to `to`.
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
    ///      instead of the pre-deposit tier's rate on the whole amount. A single band rate would make
    ///      one lump strictly cheaper than the same total in chunks, discounting exactly the
    ///      depositors who move the vault the most.
    function quoteDepositFee(bytes32 termId, uint256 baseAssets) external view override returns (uint256 fee) {
        return _piecewiseDepositFee(vaultStake[termId], baseAssets);
    }

    /// @inheritdoc IBaseCurve
    /// @dev Piecewise across `account`'s lots, highest tier first, each portion at its own lot's
    ///      rate ({_lotRedeemFee}). Flat 1:1 pricing means `grossAssets` is also the share count the
    ///      unwind walks. An account with no lots (e.g. the account-less preview path passing
    ///      address(0)) is priced at the vault's current tier.
    function quoteRedeemFee(bytes32 termId, address account, uint256 grossAssets)
        external
        view
        override
        returns (uint256 fee)
    {
        return _lotRedeemFee(termId, account, grossAssets);
    }

    /* =================================================== */
    /*                    RECORD HOOKS                     */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    /// @dev Receives the deposit fee as native value and replays the deposit band by band, so the end
    ///      state matches one deposit per tier band carrying that band's apportioned slice of the
    ///      single quoted fee. Each band's share is distributed from that band as its source —
    ///      recipients are the tiers strictly below it — against the depositor's position as it stands
    ///      once the previous bands have landed. `onlyMultiVault`.
    ///
    ///      The fee amount is piecewise across the traversed bands ({quoteDepositFee}) and the
    ///      distribution target is per band rather than the single pre-deposit tier. Deposit-side
    ///      denominators use each tier's full stake, including any the depositor already holds, so the
    ///      distribution does not depend on which account pays.
    ///
    ///      The guard against self-payment is structural rather than a subtraction: a band's fee
    ///      reaches only the tiers below that band, and the band's own stake is applied after its fee
    ///      has been distributed, so no portion of a deposit can be paid out of the fee it generated.
    ///      What a depositor recovers is bounded by their pro-rata ownership of the prior tiers at the
    ///      moment each band lands, which is what any other holder receives.
    function recordDeposit(bytes32 termId, address account, uint256 shares)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        // Flat 1:1 pricing: one share is one TRUST wei of stake, so `shares` is booked directly as
        // stake on the curve's ledger. See the unit-coupling note on {vaultStake}.
        uint256 feeAmount = msg.value;
        uint256 startAssets = vaultStake[termId];
        // Tier before this deposit is added — the first band the stake traverses.
        uint256 sourceTier = _tierOf(startAssets);

        if (shares == 0) {
            // The hook is invoked on every deposit into a hook curve, including ones that mint
            // nothing. There is no band to walk, so the fee (if any) is distributed once from the
            // vault's current tier.
            _payDepositFee(termId, feeAmount, sourceTier);
        } else {
            _replayDepositBands(termId, account, startAssets, shares, feeAmount);
            vaultStake[termId] = startAssets + shares;
        }

        emit DepositRecorded(termId, account, shares, feeAmount, sourceTier, lotMask[termId][account].fls());
    }

    /// @inheritdoc IBaseCurve
    /// @dev Receives the redeem fee as native value and distributes it per lot drawn: a configurable
    ///      `redeemToFulcrumTiersBps` slice to the eligible prior tiers through the occupancy-weighted
    ///      fulcrum kernel, the rest to the other holders of that lot's tier up to their fill, then
    ///      to the eligible tiers above and below, each up to its fill. The exiter is excluded from
    ///      the fee they pay at every tier. When the kernel spread can place nothing, the fulcrum
    ///      slices go to the cohorts of the drawn lots' tiers, capped; what no holder can take
    ///      accrues to the protocol bucket. `onlyMultiVault`.
    function recordRedeem(bytes32 termId, address account, uint256 shares)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        // Flat 1:1 pricing: one share is one TRUST wei of stake, so `shares` is debited directly
        // from the curve's stake ledger. See the unit-coupling note on {vaultStake}.
        uint256 feeAmount = msg.value;
        // Tier before the exit is removed — matches the spec's `currentTier` for the fulcrum split.
        uint256 currentTier = _tierOf(vaultStake[termId]);
        uint256 topTier = lotMask[termId][account].fls();

        // Bank everything the position has earned so far, then take the exiting stake from the lots,
        // highest tier first, so the exiter's residual lots are outside every denominator below.
        _settle(termId, account);
        (uint256[] memory lotTiers, uint256[] memory lotShares, uint256 residualMask) =
            _unwindLots(termId, account, shares);

        // (1) Per lot: its portion of the fee splits into an exiting-tier slice for that tier's other
        //     holders and a fulcrum slice. Whatever the exiting-tier slice cannot place across every
        //     tier at the schedule rate is carried as `leftover` and accrues: every tier has already
        //     taken its fill of it, and the spread would offer it to the same tiers a second time.
        (uint256 fulcrum, uint256 leftover) = _distributeLotFees(termId, account, feeAmount, lotTiers, lotShares);

        // (2) One fulcrum spread for the whole redeem, from the vault's tier, with every residual lot
        //     of the exiter excluded. If the spread could place nothing at all (the vault sits in
        //     tier 0, or every prior tier is empty), the fulcrum slices go to the cohorts of the tiers
        //     this redeem drew from instead. Only what nobody can take accrues to the protocol.
        uint256 unpaid = _payFulcrumTiers(
            termId, fulcrum, currentTier, account, config.redeemFulcrumAlphaBps, config.redeemKernelSpread
        );
        if (unpaid == fulcrum && fulcrum > 0) {
            unpaid = _creditLotCohorts(termId, account, lotTiers, fulcrum);
        }
        _accrueToProtocol(unpaid + leftover);

        // Re-base every residual lot against the post-distribution accumulators: excludes the exiter
        // from their own fee on every tier it reached.
        _rebaseLots(termId, account, residualMask);
        vaultStake[termId] -= shares;

        emit RedeemRecorded(termId, account, shares, feeAmount, topTier);
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

        amount = settledEarnings[msg.sender];
        if (amount == 0) revert DynamicFeeFlatPriceCurve_NothingToClaim();

        settledEarnings[msg.sender] = 0;
        Address.sendValue(payable(msg.sender), amount);
        emit Claimed(msg.sender, amount);
    }

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    /// @dev Not additive across terms: this is {bankedEarnings}, a single account-wide settled balance,
    ///      plus this term's unsettled earnings. Summing it over several terms counts the settled
    ///      balance once per term. {claimableAcross} gives a total, as does {bankedEarnings} once
    ///      together with {pendingFor} per term.
    function claimable(address account, bytes32 termId) external view returns (uint256 amount) {
        return settledEarnings[account] + _pendingFor(account, termId);
    }

    /// @notice Term-scoped unsettled earnings, excluding the settled balance. Additive across terms.
    /// @param  account The account to read
    /// @param  termId  The term (atom or triple) to read
    /// @return amount  The term-scoped unsettled amount, excluding the settled balance
    function pendingFor(address account, bytes32 termId) external view returns (uint256 amount) {
        return _pendingFor(account, termId);
    }

    /// @notice The account's settled balance: earnings already moved out of the per-term accumulators
    ///         and awaiting claim, which is what `claim([])` pays when it is non-zero. Excludes
    ///         anything still unsettled in a term, so it is not an account-wide total —
    ///         {claimableAcross} is.
    /// @param  account The account to read
    /// @return amount  The settled, unclaimed balance
    function bankedEarnings(address account) external view returns (uint256 amount) {
        return settledEarnings[account];
    }

    /// @notice What `claim(termIds)` would pay: the settled balance plus those terms' unsettled
    ///         earnings.
    /// @dev    Input is validated first, then the total is accumulated. `termIds` must be free of
    ///         repeats; order is irrelevant. Uniqueness is enforced rather than assumed, since a
    ///         repeated term would have its unsettled amount counted once per occurrence here while
    ///         {claim} settles it once, breaking the equality this function exists to provide.
    /// @dev    An empty set is valid and returns {bankedEarnings}, matching `claim([])`. {claim}
    ///         reverts `NothingToClaim` when the amount computed here is zero.
    /// @dev    Uniqueness is proved in expected `O(n log n)`: a scratch copy is sorted so any repeat
    ///         becomes adjacent, then one linear scan detects it. The bound is expected rather than
    ///         worst case, since the underlying sort is quicksort-based, but it still beats the
    ///         unconditional pairwise comparison the same check would otherwise need. Sorting here
    ///         rather than requiring a pre-sorted array keeps that burden off callers. A storage or
    ///         transient-storage set would be cheaper but is a state write, which `view` forbids.
    /// @param  account The account to read
    /// @param  termIds The terms to include, in any order, without repeats; may be empty
    /// @return amount  The total, equal to what {claim} would pay for these terms
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
        // settled balance is account-wide and is added exactly once.
        amount = settledEarnings[account];
        for (uint256 i = 0; i < length;) {
            amount += _pendingFor(account, bytes32(sorted[i]));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Shared term-scoped pending computation behind {claimable}, {pendingFor} and {claimableAcross}.
    ///      Does not consult `config.minEligibleTierStakeBps`. The floor gates who receives future credit,
    ///      not who may surface credit already earned. Applying `_isEligibleStake` here, or in
    ///      {_settle}, {claim}, {claimable} or {claimableAcross}, would strand earned funds:
    ///      `accFeePerShare` would still hold the credit but nothing would read it out, and `settledEarnings` is
    ///      only ever written from {_settle}.
    function _pendingFor(address account, bytes32 termId) private view returns (uint256 pending) {
        uint256 mask = lotMask[termId][account];
        while (mask != 0) {
            uint256 tier = mask.fls();
            uint256 accumulated =
                lotStake[termId][account][tier].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
            uint256 debt = lotRewardDebt[termId][account][tier];
            if (accumulated > debt) pending += accumulated - debt;
            mask ^= 1 << tier;
        }
    }

    /// @notice Account-aware redeem preview: the net assets `account` would receive for `shares`,
    ///         after this curve's redeem fee priced across that account's lots.
    /// @dev    `IMultiVault.previewRedeem` is account-agnostic and reaches {quoteRedeemFee} with
    ///         `address(0)`, which falls back to the vault's current tier. A holder's shares are
    ///         priced lot by lot from their highest tier down and routinely differ, so the
    ///         vault-level preview diverges from execution in both directions; this function is the
    ///         holder-accurate quote. Flat 1:1 pricing means gross assets equal shares.
    /// @dev    Not an execution-net payout. The returned figure is net of this curve's redeem fee
    ///         only; MultiVault additionally charges its own protocol and exit fees on the same
    ///         redemption, which this contract does not model. `assetsAfterCurveFee` is therefore
    ///         gross of those fees and may exceed the payout, equalling it only when they are zero or
    ///         round to zero, so it is not a `minAssets` value on its own. A holder-accurate net
    ///         composes: take `MultiVault.previewRedeem(...)`, add back the account-less curve fee it
    ///         used (`quoteRedeemFee(termId, address(0), grossAssets)`), then subtract `fee` below.
    /// @param  termId  The term being redeemed from
    /// @param  account The redeeming account
    /// @param  shares  The share amount to preview
    /// @return assetsAfterCurveFee Gross assets less this curve's redeem fee for `account`,
    ///                             still gross of MultiVault's own protocol and exit fees
    /// @return fee     The curve redeem fee `account` would pay
    function previewRedeemFor(bytes32 termId, address account, uint256 shares)
        external
        view
        returns (uint256 assetsAfterCurveFee, uint256 fee)
    {
        fee = _lotRedeemFee(termId, account, shares);
        assetsAfterCurveFee = shares - fee;
    }

    /// @notice The highest tier at which `account` holds a lot in `termId`: the lot a redeem draws
    ///         from first, and so the rate the next share out is charged at. `NO_LOT` when the
    ///         account holds no lot.
    function userTopTier(bytes32 termId, address account) external view returns (uint256) {
        return lotMask[termId][account].fls();
    }

    /// @notice Every lot `account` holds in `termId`, highest tier first, which is the order a
    ///         redeem unwinds them.
    function userLots(bytes32 termId, address account)
        external
        view
        returns (uint256[] memory tiers, uint256[] memory stakes)
    {
        uint256 mask = lotMask[termId][account];
        uint256 count = mask.popCount();
        tiers = new uint256[](count);
        stakes = new uint256[](count);
        for (uint256 i; i < count;) {
            uint256 tier = mask.fls();
            tiers[i] = tier;
            stakes[i] = lotStake[termId][account][tier];
            mask ^= 1 << tier;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Return the full tier + fee configuration.
    function getConfig() external view returns (DynamicFeeConfig memory) {
        return config;
    }

    /// @notice Cumulative asset upper edge of `tier` (TRUST wei).
    function tierUpperEdge(uint256 tier) external view returns (uint256) {
        return _tierUpperEdge(tier);
    }

    /// @notice Asset width of `tier` (TRUST wei).
    function tierWidthAt(uint256 tier) external view returns (uint256) {
        return _tierWidthAt(tier);
    }

    /// @notice Tier index for a cumulative-asset position (capped at the top tier).
    function tierOf(uint256 assets) external view returns (uint256) {
        return _tierOf(assets);
    }

    /// @notice Deposit fee (bps) charged while a vault sits in `tier`.
    function depositFeeBps(uint256 tier) external view returns (uint256) {
        return _depositFeeBps(tier);
    }

    /// @notice Redeem fee (bps) charged to a holder exiting from `tier`.
    function redeemFeeBps(uint256 tier) external view returns (uint256) {
        return _redeemFeeBps(tier);
    }

    /* =================================================== */
    /*                  INTERNAL: ACCOUNTING              */
    /* =================================================== */

    /// @dev Settle every lot of a user's position into `settledEarnings` and re-base each lot's
    ///      reward debt to the current accumulator of its tier. Settles against those accumulators as
    ///      they stand, without consulting `config.minEligibleTierStakeBps`; see {_pendingFor} for
    ///      why.
    function _settle(bytes32 termId, address account) private {
        uint256 mask = lotMask[termId][account];
        uint256 earned;
        while (mask != 0) {
            uint256 tier = mask.fls();
            earned += _settleLot(termId, account, tier);
            mask ^= 1 << tier;
        }
        if (earned > 0) {
            settledEarnings[account] += earned;
        }
    }

    /// @dev Settle one lot: return what it has earned since its last settlement and re-base its
    ///      debt to its tier's current accumulator. The caller books the return value.
    function _settleLot(bytes32 termId, address account, uint256 tier) private returns (uint256 earned) {
        uint256 accumulated = lotStake[termId][account][tier].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
        uint256 debt = lotRewardDebt[termId][account][tier];
        if (accumulated > debt) {
            earned = accumulated - debt;
        }
        lotRewardDebt[termId][account][tier] = accumulated;
    }

    /// @dev Re-base every lot of `account`'s position to its tier's current accumulator without
    ///      settling. Used after a redeem's distributions so the exiter is excluded from the credit
    ///      those distributions just wrote, on every tier they still hold a lot at; the pending
    ///      amount those lots carried was banked by {_settle} before the distributions ran. `mask` is
    ///      the position's residual lot mask as {_unwindLots} left it in storage.
    function _rebaseLots(bytes32 termId, address account, uint256 mask) private {
        while (mask != 0) {
            uint256 tier = mask.fls();
            lotRewardDebt[termId][account][tier] =
                lotStake[termId][account][tier].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
            mask ^= 1 << tier;
        }
    }

    /// @dev Redeem fee for `shares` taken from `account`'s lots, highest tier first, each portion at
    ///      its own lot's rate and rounded up. Shares beyond the recorded lots (an account with no
    ///      lots, such as the account-less preview) are priced at the vault's current tier. Bounded
    ///      by the number of lots, at most `tierCount`.
    function _lotRedeemFee(bytes32 termId, address account, uint256 shares) private view returns (uint256 fee) {
        uint256 mask = lotMask[termId][account];
        uint256 remaining = shares;
        while (remaining > 0 && mask != 0) {
            uint256 tier = mask.fls();
            uint256 lot = lotStake[termId][account][tier];
            uint256 take = lot < remaining ? lot : remaining;
            fee += take.mulDivUp(_redeemFeeBps(tier), BPS);
            remaining -= take;
            mask ^= 1 << tier;
        }
        if (remaining > 0) {
            fee += remaining.mulDivUp(_redeemFeeBps(_tierOf(vaultStake[termId])), BPS);
        }
    }

    /// @dev Take `shares` from `account`'s lots, highest tier first, and report what was taken from
    ///      each: `lotTiers[i]` / `lotShares[i]` for the `i`-th lot drawn from, in draw order. The
    ///      arrays are allocated for the position's lot count and trimmed to the lots actually drawn
    ///      from, so their length is the draw count. Also returns the residual lot mask, already
    ///      written to storage, so the re-base after the distributions need not read it back.
    ///
    ///      `userStake` is debited first: a redeem larger than the position underflows there, as it
    ///      did before, and the walk below never runs out of lots because `userStake` is the sum of
    ///      them. Lots and tier occupancy are reduced here, before any distribution, so that every
    ///      denominator the distributions read already excludes the exiting stake.
    function _unwindLots(bytes32 termId, address account, uint256 shares)
        private
        returns (uint256[] memory lotTiers, uint256[] memory lotShares, uint256 mask)
    {
        userStake[termId][account] -= shares;
        mask = lotMask[termId][account];
        lotTiers = new uint256[](mask.popCount());
        lotShares = new uint256[](lotTiers.length);

        uint256 remaining = shares;
        uint256 drawn;
        while (remaining > 0) {
            uint256 tier = mask.fls();
            uint256 lot = lotStake[termId][account][tier];
            uint256 take = lot < remaining ? lot : remaining;

            lotTiers[drawn] = tier;
            lotShares[drawn] = take;

            lot -= take;
            lotStake[termId][account][tier] = lot;
            tierStake[termId][tier] -= take;
            if (lot == 0) mask ^= 1 << tier;
            remaining -= take;
            unchecked {
                ++drawn;
            }
        }
        lotMask[termId][account] = mask;

        // Trim to the lots drawn from. Shrinking a memory array's length in place is safe: the
        // allocation past the new length is simply never read again.
        assembly ("memory-safe") {
            mstore(lotTiers, drawn)
            mstore(lotShares, drawn)
        }
    }

    /// @dev Apportion the collected redeem fee across the lots the redeem drew from, by their
    ///      notional fee `lotShares[i] * rate / BPS`, the last lot taking the remainder so the split
    ///      sums to `feeAmount` exactly. Weighting by the notional fee keeps every multiplication
    ///      inside a 512-bit `mulDiv`, as the deposit replay does. Returns the sum of the lots'
    ///      fulcrum slices, which feeds the single fulcrum spread, and separately the sum of whatever
    ///      their exiting-tier slices could not place anywhere ({_distributeLotFee}), which accrues.
    ///
    ///      A `totalWeight` of zero with a non-zero `feeAmount` (every drawn lot on a zero rate, or
    ///      dust lots whose notional fee floors to zero) is covered by the remainder branch, which
    ///      hands the whole fee to the last lot; a redeem that drew nothing hands it to the spread.
    function _distributeLotFees(
        bytes32 termId,
        address account,
        uint256 feeAmount,
        uint256[] memory lotTiers,
        uint256[] memory lotShares
    ) private returns (uint256 fulcrum, uint256 leftover) {
        uint256 count = lotShares.length;
        // Each lot's notional fee is read once and reused by the apportioning loop, so the rate
        // (config and any override) is resolved once per lot rather than twice.
        uint256[] memory weights = new uint256[](count);
        uint256 totalWeight;
        for (uint256 i; i < count;) {
            weights[i] = lotShares[i].mulDiv(_redeemFeeBps(lotTiers[i]), BPS);
            totalWeight += weights[i];
            unchecked {
                ++i;
            }
        }

        uint256 assigned;
        for (uint256 i; i < count;) {
            uint256 lotFee;
            if (i + 1 == count) {
                lotFee = feeAmount - assigned;
            } else if (totalWeight > 0) {
                lotFee = feeAmount.mulDiv(weights[i], totalWeight);
            }
            assigned += lotFee;
            (uint256 toFulcrum, uint256 unplaced) =
                _distributeLotFee(termId, account, lotTiers[i], lotShares[i], lotFee);
            fulcrum += toFulcrum;
            leftover += unplaced;
            unchecked {
                ++i;
            }
        }
        fulcrum += feeAmount - assigned;
    }

    /// @dev One lot's portion of a redeem fee: a `redeemToFulcrumTiersBps` slice is reserved for the
    ///      fulcrum spread and the rest is paid to the lot tier's other holders, then rerouted
    ///      ({_payExitingTierSlice}). Returns the reserved slice and, separately, whatever the
    ///      exiting-tier slice could not place anywhere. Emits {RedeemLotRecorded}.
    function _distributeLotFee(bytes32 termId, address account, uint256 tier, uint256 take, uint256 lotFee)
        private
        returns (uint256 toFulcrum, uint256 unplaced)
    {
        toFulcrum = lotFee.mulDiv(config.redeemToFulcrumTiersBps, BPS);
        unplaced = _payExitingTierSlice(termId, account, tier, lotFee - toFulcrum);
        emit RedeemLotRecorded(termId, account, tier, take, lotFee);
    }

    /// @dev Pay one lot's exiting-tier slice to the other holders of `tier`, the exiter's residual
    ///      lot there excluded, capped at the cohort's fill of the band. What the cohort cannot take,
    ///      because it is thin, under the floor, or absent, is rerouted through the neighbouring tiers
    ///      ({_rerouteExitSlice}); what no tier can take is returned for the caller to accrue. It
    ///      never enters the fulcrum pool: every tier has already taken its fill of it, so the spread
    ///      would pay the same tiers a second time, above the schedule rate. A dust seat that happens
    ///      to be nearest cannot divert the slice either, since it takes only its fill and the walk
    ///      moves on.
    ///
    ///      `cohortStake` is exactly the other holders' stake in the tier: `tierStake` has already
    ///      had the exiting portion removed and the exiter's residual lot is subtracted, so the
    ///      redemption size cancels out. An exiter therefore cannot size a partial redeem to push
    ///      their own tier under the floor and steer the fee.
    function _payExitingTierSlice(bytes32 termId, address account, uint256 tier, uint256 slice)
        private
        returns (uint256 undistributed)
    {
        if (slice == 0) return 0;
        (undistributed,) =
            _creditEligibleCapped(termId, tier, slice, tierStake[termId][tier] - lotStake[termId][account][tier]);
        if (undistributed > 0) {
            undistributed = _rerouteExitSlice(termId, account, tier, undistributed);
        }
    }

    /// @dev Reroute the part of an exiting-tier slice its own cohort could not take: the eligible
    ///      tiers above `tier`, nearest first, so the holders who sat above the exiter earn it, then
    ///      the eligible tiers below, nearest first. Each takes up to its fill of its band, net of
    ///      the exiter's residual lot there. Emits {RedeemFeeRerouted} for every tier paid. Returns
    ///      what no tier could take, which is the last-withdrawer case or a ladder thin everywhere.
    function _rerouteExitSlice(bytes32 termId, address account, uint256 tier, uint256 amount)
        private
        returns (uint256 unpaid)
    {
        unpaid = amount;
        uint256 tierCount = config.tierCount;
        for (uint256 k = tier + 1; k < tierCount && unpaid > 0;) {
            unpaid = _creditRerouted(termId, account, tier, k, unpaid);
            unchecked {
                ++k;
            }
        }
        for (uint256 k = tier; k > 0 && unpaid > 0;) {
            unchecked {
                --k;
            }
            unpaid = _creditRerouted(termId, account, tier, k, unpaid);
        }
    }

    /// @dev One step of {_rerouteExitSlice}: credit `amount` to tier `k` if it holds eligible stake
    ///      net of the exiter, capped at its fill, and report the rerouting. Returns the unpaid part.
    function _creditRerouted(bytes32 termId, address account, uint256 exitTier, uint256 k, uint256 amount)
        private
        returns (uint256 unpaid)
    {
        bool eligible;
        (unpaid, eligible) =
            _creditEligibleCapped(termId, k, amount, tierStake[termId][k] - lotStake[termId][account][k]);
        if (eligible) emit RedeemFeeRerouted(termId, exitTier, k, amount - unpaid);
    }

    /// @dev When the fulcrum spread of a redeem could place nothing at all, because the vault sits in
    ///      tier 0 or every prior tier is empty, the pool goes to the cohorts of the tiers this redeem
    ///      drew from, highest first, each up to its fill of its band net of the exiter. Those holders
    ///      are the ones still in the vault beside the exiter, so the protocol bucket is reached only
    ///      for what they cannot take at their fill. Returns what no cohort could take.
    function _creditLotCohorts(bytes32 termId, address account, uint256[] memory lotTiers, uint256 amount)
        private
        returns (uint256 unpaid)
    {
        unpaid = amount;
        for (uint256 i; i < lotTiers.length && unpaid > 0;) {
            uint256 tier = lotTiers[i];
            (unpaid,) =
                _creditEligibleCapped(termId, tier, unpaid, tierStake[termId][tier] - lotStake[termId][account][tier]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Credit `amount` down the prior tiers of `fromTier`, nearest first, each eligible tier
    ///      taking up to its fill of its band. The deposit-side spike: no stake is excluded on that
    ///      leg. Returns what no prior tier could take, which the caller accrues.
    function _creditDownward(bytes32 termId, uint256 amount, uint256 fromTier) private returns (uint256 unpaid) {
        unpaid = amount;
        for (uint256 k = fromTier; k > 0 && unpaid > 0;) {
            unchecked {
                --k;
            }
            (unpaid,) = _creditEligibleCapped(termId, k, unpaid, tierStake[termId][k]);
        }
    }

    /// @dev Book `amount` to the protocol bucket, if any.
    function _accrueToProtocol(uint256 amount) private {
        if (amount > 0) {
            protocolAccrued += amount;
            emit ProtocolAccruedIncreased(amount);
        }
    }

    /// @dev Walk the tier bands that `stake` traverses starting from `startAssets`, and report the
    ///      stake landing in each. `bandStake` is indexed from the source tier, so entry `i` belongs
    ///      to tier `_tierOf(startAssets) + i`; `bandCount` is how many of those entries are live.
    ///      `totalWeight` is the sum of the bands' notional fees, `Σ bandStake[i] * rate / BPS`, the
    ///      basis on which the already collected fee is apportioned back across the bands that
    ///      generated it.
    ///
    ///      This walks the net stake, which is what the vault actually books, and is therefore a
    ///      different range from the one {_piecewiseDepositFee} walked when the fee was quoted (that
    ///      one starts from the gross base and cannot see MultiVault's own fees). The two are not
    ///      reconciled: the fee total is whatever MultiVault forwarded, and this only decides how to
    ///      split that total across the bands the stake really crossed.
    ///
    ///      `room` is never zero — {_tierOf} returns the first tier whose upper edge strictly exceeds
    ///      `startAssets`, and each iteration either exhausts `remaining` or lands the cursor exactly
    ///      on an edge before moving to the next (strictly larger) one — so the walk cannot stall.
    function _walkDepositBands(uint256 startAssets, uint256 stake, uint256 sourceTier, uint256 topTier)
        private
        view
        returns (uint256[] memory bandStake, uint256 bandCount, uint256 totalWeight)
    {
        // `sourceTier <= topTier` holds for the only caller, which derives `sourceTier` from
        // {_tierOf} — already capped at `tierCount - 1`. The clamp is defence in depth: that
        // invariant now lives in the caller rather than here, and an inverted pair would otherwise
        // underflow into an enormous allocation rather than failing legibly. Costs one comparison
        // and cannot mask a wrong result, since a walk starting above the top tier has no band to
        // fill either way.
        bandStake = new uint256[](sourceTier > topTier ? 1 : topTier - sourceTier + 1);

        uint256 remaining = stake;
        uint256 cursor = startAssets;
        uint256 bandTier = sourceTier;
        while (remaining > 0) {
            uint256 chunk = remaining;
            if (bandTier < topTier) {
                uint256 room = _tierUpperEdge(bandTier) - cursor;
                if (room < chunk) chunk = room;
            }
            bandStake[bandCount] = chunk;
            totalWeight += chunk.mulDiv(_depositFeeBps(bandTier), BPS);
            remaining -= chunk;
            cursor += chunk;
            unchecked {
                ++bandTier;
                ++bandCount;
            }
        }
    }

    /// @dev Replay `stake` band by band, distributing each band's slice of `feeAmount` from that band
    ///      and then landing that band's stake, so the end state matches one deposit per band.
    ///
    ///      Apportionment: each band takes `feeAmount * bandNotionalFee / totalWeight`, where a band's
    ///      notional fee is `bandStake * rate / BPS`. Weighting by the notional fee rather than the raw
    ///      `stake * bps` product keeps every multiplication inside a 512-bit `mulDiv`; the proportions
    ///      are identical either way, since both scale every band by the same factor. The last band
    ///      takes the exact remainder instead of its computed slice, making `Σ bandFee` identically
    ///      `feeAmount` so no rounding dust escapes and none is double-counted. That places the remainder on
    ///      the highest band, which has the most prior tiers and so is least likely to lack an eligible
    ///      recipient.
    ///
    ///      A `totalWeight` of zero is reachable with a non-zero `feeAmount`, and the remainder branch is
    ///      what covers it. Every band being on a zero rate is one way to get there; the other is that
    ///      every band's notional fee floors to zero, which needs `bandStake * rate < BPS` on all of
    ///      them — dust bands only, since that bounds each band under `BPS / rate` wei. The fee quote
    ///      rounds up, so a dust deposit straddling an edge really can forward one wei against zero
    ///      total weight. The whole fee then falls to the last band as its remainder and is
    ///      distributed from there, which is why the `totalWeight > 0` guard sits on the proportional
    ///      branch only and never on the remainder.
    function _replayDepositBands(bytes32 termId, address account, uint256 startAssets, uint256 stake, uint256 feeAmount)
        private
    {
        uint256 sourceTier = _tierOf(startAssets);
        uint256 topTier = config.tierCount - 1;

        // Single-band fast path. Most deposits land entirely inside the band the vault already sits
        // in. Returning here skips a second `_tierOf` (which loops over `rpow`-based edges), the
        // scratch-array allocation and the whole weighting pass.
        //
        // It dispatches into the same {_applyDepositBand} the loop below uses rather than
        // reimplementing band application, so the two cannot diverge. With one band, that band's fee
        // is the whole `feeAmount`, so there is no apportionment to do.
        if (sourceTier == topTier || startAssets + stake <= _tierUpperEdge(sourceTier)) {
            _applyDepositBand(termId, account, sourceTier, stake, feeAmount);
            return;
        }

        (uint256[] memory bandStake, uint256 bandCount, uint256 totalWeight) =
            _walkDepositBands(startAssets, stake, sourceTier, topTier);

        uint256 assigned;
        for (uint256 i = 0; i < bandCount;) {
            uint256 bandTier = sourceTier + i;
            uint256 bandFee;
            if (i + 1 == bandCount) {
                bandFee = feeAmount - assigned;
            } else if (totalWeight > 0) {
                bandFee = feeAmount.mulDiv(bandStake[i].mulDiv(_depositFeeBps(bandTier), BPS), totalWeight);
                assigned += bandFee;
            }
            _applyDepositBand(termId, account, bandTier, bandStake[i], bandFee);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev One band of a replayed deposit. The order of these steps is the whole mechanism:
    ///
    ///      1. Distribute this band's fee, sourced at `bandTier`, so it reaches only the tiers below
    ///         it. The depositor's lots at those tiers sit in the denominators like anyone else's and
    ///         keep what they are credited as pending, since their debts are not touched here; the
    ///         stake being deposited has not landed yet, so it cannot be paid out of its own fee.
    ///      2. Settle the lot at `bandTier`, if one exists, banking whatever it has earned so far.
    ///         Step 1 never credits `bandTier` itself, so this is about earlier credit only: skip it
    ///         and step 3's re-base discards it.
    ///      3. Add this band's stake to the lot at `bandTier` and re-base that lot's debt.
    ///
    ///      The lot lands where the money actually did and stays there. A holder's other lots are
    ///      untouched: nothing averages, so a deposit never moves stake already recorded at another
    ///      tier, up or down, and the rate a holder pays on the way out is the rate of the lot each
    ///      share came in through.
    function _applyDepositBand(bytes32 termId, address account, uint256 bandTier, uint256 bandStake, uint256 bandFee)
        private
    {
        _payDepositFee(termId, bandFee, bandTier);
        emit DepositBandRecorded(termId, account, bandTier, bandStake, bandFee);
        // The band walk never yields an empty band, but a set mask bit over a zero lot would break
        // the mask invariant, so the landing is gated on stake rather than on that guarantee.
        if (bandStake == 0) return;

        uint256 lot = lotStake[termId][account][bandTier];
        if (lot > 0) {
            uint256 earned = _settleLot(termId, account, bandTier);
            if (earned > 0) {
                settledEarnings[account] += earned;
            }
        } else {
            lotMask[termId][account] |= 1 << bandTier;
        }

        uint256 newLot = lot + bandStake;
        lotStake[termId][account][bandTier] = newLot;
        lotRewardDebt[termId][account][bandTier] = newLot.fullMulDiv(accFeePerShare[termId][bandTier], ACC_PRECISION);
        tierStake[termId][bandTier] += bandStake;
        userStake[termId][account] += bandStake;
    }

    /// @dev Distribute one band's deposit fee `feeAmount` across the tiers below `tier`. A
    ///      `depositToPriorTierBps` slice is a lump aimed at the nearest eligible prior tier — the
    ///      spike that rewards the immediately preceding cohort — and the remainder spreads across
    ///      the prior tiers by the sliding-fulcrum kernel ({_payFulcrumTiers}). Every recipient must
    ///      clear the eligibility floor. The lump walks down the prior tiers, nearest first, each
    ///      taking up to its fill of its band ({_creditDownward}), so a thin tier keeps its fill and
    ///      the next tier down takes the rest; what no prior tier can take accrues to the protocol
    ///      bucket rather than entering the fulcrum pool, which would pay the same tiers a second
    ///      time. The spread weights each tier by its occupancy and returns what it cannot place,
    ///      which on this leg has no other home and accrues as well. The fee is never forfeited or
    ///      double-counted. `depositToPriorTierBps == 0` (the default) reduces to a pure fulcrum
    ///      distribution.
    ///
    ///      No exclusion is applied here: denominators are each tier's full stake, so the distribution
    ///      does not depend on which account pays. The zero arguments passed to {_payFulcrumTiers}
    ///      keep that helper usable by the redeem path, which does exclude the exiter so that no
    ///      account is paid out of its own exit fee.
    function _payDepositFee(bytes32 termId, uint256 feeAmount, uint256 sourceTier) private {
        if (feeAmount == 0) return;

        uint256 toPriorTier = feeAmount.mulDiv(config.depositToPriorTierBps, BPS);

        // Prior-tier spike -> down the prior tiers, nearest first, each taking up to its fill. What no
        // prior tier can take at that rate accrues: offered to the spread it would reach the same
        // tiers a second time.
        uint256 unpaid;
        if (toPriorTier > 0) {
            unpaid = _creditDownward(termId, toPriorTier, sourceTier);
        }

        // Fulcrum pool -> the prior tiers by the occupancy-weighted triangular kernel; on this leg
        // whatever the spread cannot place has no other home.
        unpaid += _payFulcrumTiers(
            termId,
            feeAmount - toPriorTier,
            sourceTier,
            address(0),
            config.depositFulcrumAlphaBps,
            config.depositKernelSpread
        );
        _accrueToProtocol(unpaid);
    }

    /// @dev Whether `stake` may receive redistributed fees at `tier`: the recipient gate of the kernel
    ///      spread. The single-target credits apply the identical predicate inside
    ///      {_creditEligibleCapped}, on the tier width the cap needs anyway, so a tier can never be
    ///      dropped from one gate and admitted to another. Callers pass the stake that will actually
    ///      receive the fee: exclusion-adjusted on the redeem leg, raw `tierStake` on the deposit leg.
    ///      The floor is a fraction of the tier's own width; its semantics are on
    ///      {DynamicFeeConfig.minEligibleTierStakeBps}.
    ///
    ///      The `> 0` conjunct is not redundant with the floor. At a zero floor a bare
    ///      `stake >= floor` holds for an empty recipient set, and the exiting-tier branch of
    ///      {recordRedeem} divides by that stake immediately, so a last-holder exit would revert on
    ///      division by zero instead of routing to the protocol.
    function _isEligibleStake(uint256 tier, uint256 stake) private view returns (bool) {
        if (stake == 0) return false;
        uint256 floorBps = config.minEligibleTierStakeBps;
        if (floorBps == 0) return true;
        return stake >= _tierWidthAt(tier).mulDiv(floorBps, BPS);
    }

    /// @dev Credit `amount` to the `recipientStake` recorded at `tier` if that stake is eligible,
    ///      capped at the schedule rate per share: a cohort holding at least the band's width takes
    ///      the whole amount, a thinner one takes `amount * stake / width`, so per-share income at
    ///      any tier never exceeds what a full band would pay and a dust seat cannot collect a tier's
    ///      slice for the price of one wei. Eligibility is the same predicate as {_isEligibleStake},
    ///      evaluated here on the one tier width the cap needs anyway, so a walk computes each
    ///      candidate's width once. Returns the unpaid remainder, the whole `amount` when the stake is
    ///      ineligible, and whether it was eligible; the caller walks the remainder on to its next
    ///      candidate tier, and what a whole walk cannot place accrues rather than entering the
    ///      fulcrum pool, which would offer it to tiers that already took their fill. Used only by the
    ///      single-target credits (the deposit spike, an exiting-tier slice, a reroute): a lump with
    ///      one recipient has no other tier to normalize against, so the fill is the only bound on
    ///      it. The spread itself needs no cap, since occupancy is already inside its weights. A
    ///      `paid` amount whose per-share increment floors to zero is still reported as placed; that
    ///      is the same sub-wei-per-share dust noted on {protocolAccrued}.
    function _creditEligibleCapped(bytes32 termId, uint256 tier, uint256 amount, uint256 recipientStake)
        private
        returns (uint256 unpaid, bool eligible)
    {
        if (recipientStake == 0) return (amount, false);
        uint256 width = _tierWidthAt(tier);
        uint256 floorBps = config.minEligibleTierStakeBps;
        if (floorBps != 0 && recipientStake < width.mulDiv(floorBps, BPS)) return (amount, false);
        uint256 paid = recipientStake >= width ? amount : amount.mulDiv(recipientStake, width);
        if (paid > 0) {
            accFeePerShare[termId][tier] += paid.fullMulDiv(ACC_PRECISION, recipientStake);
        }
        return (amount - paid, true);
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

    /// @dev Distribute `fulcrumFeePool` across the prior tiers `[0, tier)` by the triangular fulcrum
    ///      kernel, weighted by occupancy. The peak sits at `dStar = (1 - alphaBps/BPS) * span` tiers
    ///      from the source (a fraction of the span, so it slides up the ladder as the vault grows).
    ///      Each eligible prior tier carries the effective weight
    ///
    ///          e_t = max(0, 1 - |d - dStar| / sigma) * stake_t / width_t
    ///
    ///      the kernel weight times the tier's fill ratio, with the fill left uncapped, and takes the
    ///      slice `pool * e_t / D`. Dividing that slice by the tier's stake gives its per-share income,
    ///      `pool * w_t / (width_t * D)`: the kernel weight per unit of width times one rate common to
    ///      every tier in the spread. Occupancy never enters the per-share figure. A tier holding a
    ///      tenth of its band earns a tenth of the slice a full one would, at the same rate per share;
    ///      a tier holding twice its band earns twice, at the same rate per share, so a refilled band
    ///      is not diluted relative to its neighbours; a dust seat earns dust. `excludeAccount`'s lot
    ///      is removed from every stake read. A tier under the eligibility floor is absent from the
    ///      normalization, and the window does not slide down to pull in a further tier, because the
    ///      kernel returns a hard zero beyond `sigma`.
    ///
    ///      The normalizer `D` is `max(Σe, Σw)`, where `Σw` is the plain kernel sum over every prior
    ///      tier, the figure a ladder holding exactly its widths would normalize over. When the prior
    ///      ladder holds at least that much, `D = Σe`: the pool is spread whole, nothing is left over,
    ///      and the common rate is at or below the schedule. When it holds less, `D = Σw`: every tier
    ///      is paid exactly the schedule rate for the stake it has, and the part of the pool that no
    ///      stake is there to earn accrues to `protocolAccrued`. The ceiling is what stops a lone thin
    ///      tier, left as the only eligible recipient by a drawdown or by design, from taking a whole
    ///      pool for the price of one seat; without it the relative rule alone would hand it
    ///      everything. Over-full tiers therefore absorb what thinner tiers leave, up to the schedule
    ///      rate, and only the shortfall beyond that reaches the protocol.
    ///
    ///      If the window misses every eligible tier (a tight `sigma`, or the near tiers emptied by a
    ///      drawdown), the spread falls back to the same rule with every kernel weight set to one, so
    ///      the pool is split across all eligible prior tiers by fill alone, with `Σw = span`. The
    ///      fallback keys on the window, not on the effective sum: weights are carried at
    ///      `WEIGHT_PRECISION`, so an eligible tier inside the window keeps a non-zero weight down to
    ///      a fill of one part in `TIER_PRECISION`, and a tier whose fill is below even that earns
    ///      nothing rather than pulling tiers outside the window into the split. Integer-division
    ///      dust of an uncapped spread goes to the last tier credited. Returns what could not be
    ///      placed, the whole pool when no prior tier is eligible at all; the caller decides where
    ///      that goes, since the two legs differ (the deposit leg has no other home for it, the
    ///      redeem leg still has the exiting cohorts). The weighting passes and the credit pass are
    ///      extracted to keep this write path within the 16-slot stack ceiling. `alphaBps` and
    ///      `sigma` are the kernel pair for the calling leg.
    function _payFulcrumTiers(
        bytes32 termId,
        uint256 fulcrumFeePool,
        uint256 sourceTier,
        address excludeAccount,
        uint256 alphaBps,
        uint256 sigma
    ) private returns (uint256 unpaid) {
        if (fulcrumFeePool == 0) return 0;

        // No prior tiers (the vault sits in tier 0): nothing below to reward.
        uint256 span = sourceTier;
        if (span == 0) return fulcrumFeePool;

        // `weights`/`stakes` are indexed by `d - 1` (d = 1 is the nearest prior tier `sourceTier - 1`;
        // d = span is the farthest, tier 0). `stakes[i] > 0` implies the tier is eligible: once the
        // floor is live, occupancy alone is not sufficient. The fulcrum sits at
        // `dStar = (1 - alpha/BPS) * span` tiers from the source.
        uint256[] memory weights = new uint256[](span);
        uint256[] memory stakes = new uint256[](span);
        (uint256 sumWeights, uint256 sumRef) = _weighPriorTiers(
            termId, span, ((BPS - alphaBps) * span).mulDiv(TIER_PRECISION, BPS), sigma, excludeAccount, weights, stakes
        );

        uint256 paid = sumWeights == 0
            ? 0
            : _creditByWeight(
                termId,
                fulcrumFeePool,
                span,
                sumWeights >= sumRef ? sumWeights : sumRef,
                sumWeights >= sumRef,
                weights,
                stakes
            );
        unpaid = fulcrumFeePool - paid;
    }

    /// @dev Credit pass of {_payFulcrumTiers}: each tier with a non-zero effective weight takes
    ///      `pool * e_t / denominator`, booked to its accumulator per unit of stake. `exact` says the
    ///      denominator is the effective sum itself, so the pool is meant to be spread whole: the
    ///      integer-division dust then goes to the last tier credited and the return equals the pool.
    ///      Otherwise the denominator is the schedule's normalizer, the credits are each tier's
    ///      schedule-rate share, and the shortfall returned is a genuine remainder for the caller to
    ///      book. `weights[i] > 0` implies `stakes[i] > 0`, so the per-share division cannot hit zero.
    function _creditByWeight(
        bytes32 termId,
        uint256 fulcrumFeePool,
        uint256 span,
        uint256 denominator,
        bool exact,
        uint256[] memory weights,
        uint256[] memory stakes
    ) private returns (uint256 paid) {
        uint256 lastTier;
        uint256 lastStake;
        for (uint256 d = 1; d <= span;) {
            uint256 e = weights[d - 1];
            if (e > 0) {
                uint256 slice = fulcrumFeePool.fullMulDiv(e, denominator);
                if (slice > 0) {
                    accFeePerShare[termId][span - d] += slice.fullMulDiv(ACC_PRECISION, stakes[d - 1]);
                    paid += slice;
                }
                lastTier = span - d;
                lastStake = stakes[d - 1];
            }
            unchecked {
                ++d;
            }
        }
        if (exact && paid < fulcrumFeePool) {
            accFeePerShare[termId][lastTier] += (fulcrumFeePool - paid).fullMulDiv(ACC_PRECISION, lastStake);
            paid = fulcrumFeePool;
        }
    }

    /// @dev Weighting pass of {_payFulcrumTiers}: fill `stakes` (net of `excludeAccount`'s lot, zeroed
    ///      for ineligible tiers) and `weights` (the effective weight `w_t * stake_t / width_t`, in
    ///      `WEIGHT_PRECISION`) for every prior tier, both length `span` and indexed by `d - 1`.
    ///      Returns the summed effective weight and the plain kernel sum over every prior tier
    ///      regardless of occupancy in the same units, which is the normalizer a ladder holding
    ///      exactly its widths would have. If no eligible tier fell inside the window, both are
    ///      replaced by the fill-only fallback ({_weighByFill}) before returning; a window that holds
    ///      an eligible tier is never replaced, even when every effective weight in it is zero. The
    ///      deposit leg passes `address(0)`, which holds no lots, so nothing is excluded on that path.
    ///      Zeroing an ineligible tier's entry here, rather than re-testing at each read site, is what
    ///      makes "`stakes[i] > 0` implies eligible" a structural invariant of the array; both
    ///      {_creditByWeight} and {_weighByFill} depend on it and neither re-checks. A kernel weight
    ///      of zero (outside the window) leaves the effective weight zero as well, so the fill-only
    ///      fallback can tell "eligible but outside the window" from "ineligible" by the stake entry
    ///      alone.
    function _weighPriorTiers(
        bytes32 termId,
        uint256 span,
        uint256 dStar,
        uint256 sigma,
        address excludeAccount,
        uint256[] memory weights,
        uint256[] memory stakes
    ) private view returns (uint256 sumWeights, uint256 sumRef) {
        bool inWindow;
        for (uint256 d = 1; d <= span;) {
            // The recipient tier is `span - d` (== sourceTier - d).
            uint256 w = _triangularWeight(_fulcrumDistance(d, dStar), sigma) * TIER_PRECISION;
            sumRef += w;
            uint256 recipientStake = tierStake[termId][span - d] - lotStake[termId][excludeAccount][span - d];
            if (!_isEligibleStake(span - d, recipientStake)) {
                recipientStake = 0;
            }
            stakes[d - 1] = recipientStake;
            if (recipientStake > 0 && w > 0) {
                inWindow = true;
                weights[d - 1] = w.fullMulDiv(recipientStake, _tierWidthAt(span - d));
                sumWeights += weights[d - 1];
            }
            unchecked {
                ++d;
            }
        }
        if (!inWindow) {
            sumWeights = _weighByFill(span, weights, stakes);
            sumRef = span * WEIGHT_PRECISION;
        }
    }

    /// @dev Fallback weighting of {_payFulcrumTiers} for a window that admits no eligible tier: the
    ///      same rule with every kernel weight set to one, so `weights` becomes each eligible prior
    ///      tier's fill ratio `stake_t / width_t` in `WEIGHT_PRECISION` and the pool splits by fill
    ///      alone across the whole prior ladder. Reuses the `stakes` pass-1 computed, so eligibility is
    ///      not re-tested. Returns the summed fill; zero only when no prior tier is eligible at all.
    function _weighByFill(uint256 span, uint256[] memory weights, uint256[] memory stakes)
        private
        view
        returns (uint256 sumWeights)
    {
        for (uint256 d = 1; d <= span;) {
            uint256 recipientStake = stakes[d - 1];
            if (recipientStake > 0) {
                uint256 e = WEIGHT_PRECISION.fullMulDiv(recipientStake, _tierWidthAt(span - d));
                weights[d - 1] = e;
                sumWeights += e;
            }
            unchecked {
                ++d;
            }
        }
    }

    /* =================================================== */
    /*                 INTERNAL: TIER MATH               */
    /* =================================================== */

    /// @dev Asset width of `tier`, defined as the span between its cumulative edges:
    ///      `width(tier) = edge(tier) - edge(tier-1)` (with `edge(-1) = 0`, so `width(0) = edge(0) = width0`).
    ///      The target law is compounding, `width0 * (1+g)^k`, each tier `(1+g)x` the one below, but
    ///      the width is derived from {_tierUpperEdge} rather than computed independently. The edges
    ///      are the single source of truth for tier boundaries ({_tierOf}) and for the piecewise fee
    ///      walk, which charges each band's `edge`-to-`edge` span. Computing the width from its own
    ///      rounded `rpow` would let `edge(tier) - edge(tier-1)` and the advertised width disagree by a wei
    ///      or two for non-exactly-representable ratios; deriving it here makes the reported width
    ///      equal the fee-charged band by construction, at the cost of a realized ratio slightly off
    ///      the target. `_tierUpperEdge` is strictly increasing, so the subtraction never underflows.
    function _tierWidthAt(uint256 tier) private view returns (uint256) {
        if (tier == 0) return _tierUpperEdge(0);
        return _tierUpperEdge(tier) - _tierUpperEdge(tier - 1);
    }

    /// @dev Cumulative asset upper edge of `tier` (Σ_{k<=tier} width(k)), in closed form:
    ///      `edge(tier) = width0 * ((1+g)^(tier+1) - 1) / g`, the geometric-series sum.
    function _tierUpperEdge(uint256 tier) private view returns (uint256) {
        uint256 g = config.tierWidthGrowthBps;
        if (g == 0) return config.width0 * (tier + 1); // constant width -> plain multiple
        uint256 ratioWad = (BPS + g).fullMulDiv(WAD, BPS); // (1+g) in WAD
        uint256 powWad = FixedPointMathLib.rpow(ratioWad, tier + 1, WAD); // (1+g)^(tier+1) in WAD
        uint256 gWad = g.fullMulDiv(WAD, BPS); // g in WAD
        return config.width0.fullMulDiv(powWad - WAD, gWad);
    }

    /// @dev First tier whose upper edge exceeds `assets`, capped at the top tier.
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

    /// @dev The tier's manual override if set, else the formulaic min(cap, base + tier*growth).
    function _depositFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        uint256 cap = config.depositCapBps;
        if (tierOverride.isSet) {
            // Clamp against the live cap, not the cap that was in force when the override was set,
            // so that lowering `depositCapBps` tightens every tier uniformly.
            uint256 overrideFee = tierOverride.depositFeeBps;
            return overrideFee < cap ? overrideFee : cap;
        }
        uint256 fee = config.depositBaseBps + tier * config.depositGrowthBps;
        return fee < cap ? fee : cap;
    }

    /// @dev Piecewise deposit fee: walks the tier bands from `startAssets` and charges each portion
    ///      of `baseAssets` at its own band's rate. The top tier absorbs everything past its lower
    ///      edge, bounding the walk at `tierCount` (≤ MAX_TIER_COUNT) iterations; a deposit contained
    ///      in a single band costs one multiplication.
    ///
    ///      The traversal is net-anchored, which is what the gross-up below is for. The vault books
    ///      the base less this fee, not the gross base, so advancing the cursor by the gross portion
    ///      would climb the ladder faster than the vault does and let each later slice of a split
    ///      re-anchor on a lower vault state and buy cheaper bands. Advancing by `chunk - chunkFee`
    ///      makes the union of bands a split walks the same range the lump walks, so the fee is
    ///      additive across any decomposition up to the per-band round-up, which favours the lump.
    ///
    ///      The residual gap this does not close is MultiVault's own protocol / entry / atom-wallet
    ///      fees, which shrink the net further and are invisible from here — the curve is
    ///      quoted on `feeBaseAssets` and never learns what MultiVault withheld. That
    ///      leftover is bounded by the rate spread across the traversed bands times those fees, i.e.
    ///      fee-on-fee, and closing it would mean changing what {IBaseCurve.quoteDepositFee} is
    ///      quoted on for every hook curve.
    ///
    ///      Still a pure function of `(vault state, base)`, so the calc-path quote and the
    ///      record-hook forward remain equal by construction.
    function _piecewiseDepositFee(uint256 startAssets, uint256 baseAssets) private view returns (uint256 fee) {
        uint256 remaining = baseAssets;
        uint256 cursor = startAssets;
        uint256 tier = _tierOf(startAssets);
        uint256 topTier = config.tierCount - 1;

        while (remaining > 0) {
            uint256 rate = _depositFeeBps(tier);
            uint256 chunk = remaining;
            if (tier < topTier) {
                // `cursor` is strictly below this band's upper edge, so `roomNet` is nonzero. Gross
                // it up by the band's own rate to get the portion whose net advance fills the band.
                // `rate <= MAX_DEPOSIT_CAP_BPS` keeps `BPS - rate` at 8000 or more, so this division
                // can neither divide by zero nor blow up.
                uint256 roomNet = _tierUpperEdge(tier) - cursor;
                uint256 roomGross = roomNet.mulDivUp(BPS, BPS - rate);
                if (roomGross < chunk) chunk = roomGross;
            }
            uint256 chunkFee = chunk.mulDivUp(rate, BPS);
            fee += chunkFee;
            remaining -= chunk;
            // Both roundings are up, so the net advance lands on the edge rather than short of it.
            // Termination does not rest on that in any case: `tier` increments unconditionally and
            // `remaining` strictly decreases, so the walk is bounded by `tierCount` either way.
            cursor += chunk - chunkFee;
            unchecked {
                ++tier;
            }
        }
    }

    /// @dev The tier's manual override if set, else the formulaic min(cap, base + tier*growth).
    function _redeemFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        uint256 cap = config.redeemCapBps;
        if (tierOverride.isSet) {
            // Clamp against the live cap, not the cap that was in force when the override was set,
            // so that lowering `redeemCapBps` tightens every tier uniformly.
            uint256 overrideFee = tierOverride.redeemFeeBps;
            return overrideFee < cap ? overrideFee : cap;
        }
        uint256 fee = config.redeemBaseBps + tier * config.redeemGrowthBps;
        return fee < cap ? fee : cap;
    }

    /* =================================================== */
    /*                 INTERNAL: CONFIG                  */
    /* =================================================== */

    /// @dev Validate and store the tier + fee schedule. `width0` and `tierWidthGrowthBps` are bounded so the
    ///      closed-form edge math can never overflow and a fat-fingered schedule cannot brick
    ///      `tierOf` (and with it every deposit/redeem on the dynamic curve).
    function _setConfig(DynamicFeeConfig calldata _config) private {
        if (_config.width0 == 0 || _config.width0 > type(uint128).max) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.tierCount == 0 || _config.tierCount > MAX_TIER_COUNT) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.tierWidthGrowthBps > 100 * BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        // Grow-only once live: shrinking could strand occupied lot tiers above the schedule.
        if (config.tierCount != 0 && _config.tierCount < config.tierCount) {
            revert DynamicFeeFlatPriceCurve_TierCountCannotShrink();
        }
        // Same bounds for both legs' kernel pairs. The fulcrum position is a fraction of the span; the
        // spread (σ) must be non-zero (it divides the weight) and is bounded above so the triangular
        // math stays clear of overflow.
        //
        // A spread small enough that no eligible prior tier falls inside the window makes the spread
        // fall back to a split by fill alone across the whole prior ladder, at the schedule ceiling.
        // The fee still reaches real cohorts and no wei is forfeited, but the configured kernel and
        // the observable split stop matching. No static bound prevents this: keyed on the spread
        // alone it rejects legitimate schedules, since at alpha 0 the farthest tier sits at distance
        // zero and carries full weight at any spread; keyed on alpha `BPS` it does not prevent the
        // fallback, since one tier inside the window is still a one-tier kernel. Whether a given pair
        // spreads depends on live occupancy at distribution time, which `setConfig` cannot observe.
        if (_config.depositFulcrumAlphaBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.depositKernelSpread == 0 || _config.depositKernelSpread > MAX_KERNEL_SPREAD) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.redeemFulcrumAlphaBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.redeemKernelSpread == 0 || _config.redeemKernelSpread > MAX_KERNEL_SPREAD) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        // Caps are bounded by the immutable ceilings, not by `BPS`. See {MAX_DEPOSIT_CAP_BPS} and
        // {MAX_REDEEM_CAP_BPS}: a cap near `BPS` can underflow MultiVault's fee netting on the
        // deposit side and can silently zero a redeemer's payout on the redeem side.
        if (_config.depositBaseBps > _config.depositCapBps || _config.depositCapBps > MAX_DEPOSIT_CAP_BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.redeemBaseBps > _config.redeemCapBps || _config.redeemCapBps > MAX_REDEEM_CAP_BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.redeemToFulcrumTiersBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.depositToPriorTierBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        // A fraction of each tier's own width, so `BPS` (a full band) is the natural ceiling: above it
        // no tier could ever qualify on its own width and the whole fee stream would accrue to the
        // protocol bucket.
        if (_config.minEligibleTierStakeBps > BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake();
        }

        // Captured before the store so a change is monitorable on its own. {ConfigUpdated} carries only
        // the ladder shape, and no config field emits its previous value; the eligibility floor is the
        // one parameter that silently changes who earns, so it gets a dedicated before/after signal.
        uint256 previousMinEligibleTierStakeBps = config.minEligibleTierStakeBps;

        config = _config;

        // Probe the top edge under the stored schedule. The compounding math would overflow on an
        // over-steep ladder, and this computation reverts (checked `rpow` / `fullMulDiv`), so a config
        // that could brick `tierOf` on the deposit/redeem hot path is rejected before the update can
        // be committed, whether it is the initial schedule or a live retune. A zero top edge
        // (degenerate schedule) is rejected too.
        if (_tierUpperEdge(_config.tierCount - 1) == 0) revert DynamicFeeFlatPriceCurve_InvalidConfig();

        emit ConfigUpdated(
            _config.width0,
            _config.tierCount,
            _config.tierWidthGrowthBps,
            _config.depositFulcrumAlphaBps,
            _config.depositKernelSpread,
            _config.redeemFulcrumAlphaBps,
            _config.redeemKernelSpread
        );
        if (_config.minEligibleTierStakeBps != previousMinEligibleTierStakeBps) {
            emit MinEligibleTierStakeUpdated(previousMinEligibleTierStakeBps, _config.minEligibleTierStakeBps);
        }
    }
}
