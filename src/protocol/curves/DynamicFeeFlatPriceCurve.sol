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
 * @notice Flat-price bonding curve with a tiered fee economy. Pricing is {LinearCurve}'s, unmodified
 *         — the vault holds 1:1 — and everything curve-specific is in the fees: a tunable tier
 *         ladder, per-tier deposit and withdrawal rates, an optional sparse per-tier manual override,
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
 *         share of the fee to the tiers strictly below it, before that band's own stake lands
 *         ({_replayDepositBands}). A withdrawal fee is charged at the exiting holder's bucket and
 *         splits between that tier's other holders and the prior tiers ({recordRedeem}). Both legs
 *         reach the prior tiers through the same sliding-fulcrum triangular kernel
 *         ({_payFulcrumTiers}), and both rates come from {_depositFeeBps} / {_withdrawalFeeBps}.
 *
 * @dev    Credit uses an O(1) MasterChef-style accumulator rather than an O(cohort) push:
 *         `accFeePerShare[termId][tier]` tracks fee per unit of stake, and a holder's unsettled amount
 *         is `stake * accFeePerShare[bucket] - rewardDebt`. A bucket is `round(avgEntryTier)`, the
 *         holder's stake-weighted average entry tier. Settling moves a term's unsettled amount into
 *         the account-wide settled balance that {claim} pays out. The redeem leg excludes the exiter
 *         exactly, by omitting their stake from the recipient denominator and re-basing their
 *         `rewardDebt`; the deposit leg applies no such subtraction.
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

    /// @notice Hard ceiling on `withdrawalCapBps`, above which no schedule may be stored.
    /// @dev    Bounds the redeem side of the same envelope, and with it the zero-payout mode: a
    ///         withdrawal rate strictly inside a near-`BPS` cap consumes the entire redemption and
    ///         pays the redeemer nothing without reverting. Capping the cap removes that
    ///         configuration from the reachable set. Immutable.
    uint256 public constant MAX_WITHDRAWAL_CAP_BPS = 2000;

    /// @notice Hard ceiling on `config.minEligibleTierStake`, above which no floor may be stored.
    /// @dev    Bounds how much of the fee stream governance can starve into {protocolAccrued}. Without
    ///         it the floor would expand owner power rather than restate it: a huge `width0` can
    ///         already route every deposit fee to the protocol bucket (the vault falls inside tier 0,
    ///         so {_payFulcrumTiers} short-circuits on `span == 0`), but withdrawal fees key on the
    ///         holder's bucket and still reach real cohorts. An unbounded floor would starve both
    ///         streams in one transaction, and {sweepProtocol} would collect.
    ///
    ///         The guarantee is narrow: the floor can never exceed 1000 TRUST, so any tier whose
    ///         recipient stake is at least that much always qualifies. Recipient stake is raw
    ///         `tierStake` on the deposit leg, which applies no exclusion, and `tierStake` less the
    ///         exiter's own residual on the redeem leg — so on that leg a tier holding far more than
    ///         the ceiling can still fail the test.
    ///
    ///         It does not guarantee that some tier always qualifies. `Σ tierStake[termId][t] ==
    ///         vaultStake` bounds only the raw bucket totals, and the redeem path's sub-floor branch
    ///         does not search for a qualifying tier at all, so an orphaned slice accrues straight to
    ///         {protocolAccrued}. A term of any size can therefore route a fee wholly to
    ///         {protocolAccrued} under a high floor. The ceiling caps the magnitude of a governance
    ///         parameter; it is not an anti-starvation invariant.
    ///
    ///         The value is a policy ceiling rather than a constant derived from a particular schedule.
    ///         It is sized against a tier-0 width on the order of a few thousand TRUST, and a `width0`
    ///         configured orders of magnitude away from that would need it revisited. Immutable, since
    ///         it bounds what governance may configure.
    uint256 public constant MAX_MIN_ELIGIBLE_TIER_STAKE = 1000e18;

    /* =================================================== */
    /*                    STATE VARIABLES                  */
    /* =================================================== */

    /// @inheritdoc IDynamicFeeFlatPriceCurve
    address public multiVault;

    /// @dev The tunable tier + fee schedule, internal and exposed through {getConfig}.
    DynamicFeeConfig internal config;

    /// @notice Sparse per-tier manual fee override; `isSet` distinguishes an explicit 0-bps rate from
    ///         "inherit the formula". Consulted before the formulaic schedule in {_depositFeeBps} /
    ///         {_withdrawalFeeBps}, so the piecewise deposit walk picks up each traversed band's own
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

    /// @notice Settled native earnings per account, across all terms, awaiting {claim}.
    mapping(address user => uint256 amount) public earned;

    /// @notice Fee accrual with no eligible recipient, sweepable by the owner.
    /// @dev    Mostly whole slices rather than rounding dust. The balance accrues from:
    ///         (1) a deposit or withdrawal fee whose source tier is 0, leaving no prior tier to spread
    ///             to ({_payFulcrumTiers} short-circuits on `span == 0`). This keys on the source
    ///             tier, not on whether holders exist: buckets are `round(avgEntryTier)`, so holders
    ///             can remain recorded at higher tiers with non-zero `tierStake` while `vaultStake`
    ///             has fallen back inside `edge(0)`;
    ///         (2) a fulcrum pool for which no prior tier is eligible at all, including the
    ///             last-redeemer case ({_awardNearestOrProtocol});
    ///         (3) the exiting-tier slice when that tier's residual cohort holds stake but less than
    ///             `config.minEligibleTierStake` ({recordRedeem});
    ///         (4) the kernel-allocation remainder — `fulcrumFeePool` less the sum of the credited shares —
    ///             which also absorbs any single share that floors to zero ({_payFulcrumTiers}).
    ///         (1) through (3) are the intended terminal behaviour: with no cohort to reward, the
    ///         protocol absorbs the fee rather than forfeiting it. The name means "undistributable",
    ///         not "negligible" — for a young or shrunken vault it can be the whole fee stream.
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
        uint256 width0, uint256 tierCount, uint256 growthGBps, uint256 fulcrumAlpha, uint256 kernelSpread
    );
    /// @notice One deposit, summarized. `sourceTier` is the vault's tier before the deposit (the
    ///         first band the stake traversed); `accountTier` / `accountAvgTier` are the account's
    ///         `userTier` / `userAvgTier` after it. {DepositBandRecorded} carries the per-band
    ///         breakdown that produced them.
    event DepositRecorded(
        bytes32 indexed termId,
        address indexed account,
        uint256 netStake,
        uint256 fee,
        uint256 sourceTier,
        uint256 accountTier,
        uint256 accountAvgTier
    );

    /// @notice One tier band of one deposit: the portion of the stake that landed in `bandTier` and
    ///         the portion of the fee charged and distributed from it. Emitted once per band a
    ///         deposit traverses, in ascending band order, so the decomposition behind a
    ///         {DepositRecorded} is observable without re-deriving the tier ladder off-chain.
    event DepositBandRecorded(
        bytes32 indexed termId, address indexed account, uint256 bandTier, uint256 bandStake, uint256 bandFee
    );
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
    ///         (`accFeePerShare[termId][tier]`), and changing `width0`, `growthGBps` or `tierCount`
    ///         changes what each index means without moving any holder between indices. A holder
    ///         keeps their recorded bucket while that bucket denotes a different band, so the fee
    ///         stream re-targets: the cohort a slice was promised to is not necessarily the cohort
    ///         that receives it afterwards. Migrating positions instead would be unbounded in the
    ///         number of holders, which makes a retune an economic action rather than a parameter
    ///         tweak. {ConfigUpdated} emits the new ladder shape, which makes one observable.
    ///
    ///         `tierCount` may only grow once set, so no occupied bucket can be stranded above the
    ///         schedule ({_roundTier} and the distribution walk always cover every live bucket index).
    /// @param _config The new configuration
    function setConfig(DynamicFeeConfig calldata _config) external onlyOwner {
        _setConfig(_config);
    }

    /// @notice Set a sparse manual fee override for a single tier (replaces the formula for that tier).
    /// @dev    Overriding one tier does not touch any other tier. The stored rates fully replace the
    ///         formulaic `min(cap, base + tier*growth)` but must stay within the schedule's declared
    ///         per-tier caps (`depositCapBps` / `withdrawalCapBps`), which are themselves bounded by
    ///         the immutable {MAX_DEPOSIT_CAP_BPS} / {MAX_WITHDRAWAL_CAP_BPS} ceilings.
    ///         An override is also clamped at read time against the live cap, so lowering a cap
    ///         tightens every tier uniformly, including tiers that already carry an override, with no
    ///         separate clear-then-retune step.
    ///         Those two bounds together keep a withdrawal rate from consuming a whole redemption.
    ///         That mode does not surface as a revert from the rate itself: absent a bound, a rate
    ///         strictly inside a near-`BPS` cap would let a redemption succeed while paying the
    ///         redeemer zero and burning their shares. The ceilings remove that configuration from
    ///         the reachable set, and `MultiVault` carries an independent floor that rejects a
    ///         redemption returning no assets.
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
    /// @dev The rate keys on `account`'s tracked entry tier; an account with no tracked stake (e.g.
    ///      the account-less preview path passing address(0)) falls back to the vault's current tier.
    function quoteRedeemFee(bytes32 termId, address account, uint256 grossAssets)
        external
        view
        override
        returns (uint256 fee)
    {
        uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultStake[termId]);
        return grossAssets.mulDivUp(_withdrawalFeeBps(tier), BPS);
    }

    /* =================================================== */
    /*                    RECORD HOOKS                     */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    /// @dev Receives the deposit fee as native value and replays the deposit band by band, so the end
    ///      state matches one deposit per tier band carrying that band's apportioned share of the
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
    function recordDeposit(bytes32 termId, address account, uint256 netStake)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        uint256 feeAmount = msg.value;
        uint256 startAssets = vaultStake[termId];
        // Tier before this deposit is added — the first band the stake traverses.
        uint256 sourceTier = _tierOf(startAssets);

        if (netStake == 0) {
            // The hook is invoked on every deposit into a hook curve, including ones that mint
            // nothing. There is no band to walk, so the fee (if any) is distributed once from the
            // vault's current tier.
            _payDepositFee(termId, feeAmount, sourceTier);
        } else {
            _replayDepositBands(termId, account, startAssets, netStake, feeAmount);
            vaultStake[termId] = startAssets + netStake;
        }

        emit DepositRecorded(
            termId, account, netStake, feeAmount, sourceTier, userTier[termId][account], userAvgTier[termId][account]
        );
    }

    /// @inheritdoc IBaseCurve
    /// @dev Receives the withdrawal fee as native value and distributes it to the residual holders of
    ///      the exiting tier, with a configurable `withdrawalToFulcrumTiersBps` slice routed to the
    ///      eligible prior tiers through the triangular fulcrum kernel; the exiter is excluded from
    ///      the fee they pay. When the exiting tier has no residual cohort, its slice falls through to
    ///      the nearest eligible tier (above first, then below) rather than to the protocol.
    ///      `onlyMultiVault`.
    function recordRedeem(bytes32 termId, address account, uint256 withdrawnStake)
        external
        payable
        override
        onlyMultiVault
        nonReentrant
    {
        uint256 feeAmount = msg.value;
        // Tier before the exit is removed — matches the spec's `currentTier` for the fulcrum split.
        uint256 tier = _tierOf(vaultStake[termId]);
        uint256 exitTier = userTier[termId][account];

        // Settle the exiter, then remove the exiting portion so they are excluded from the fee they
        // are about to pay.
        _settle(termId, account);
        userStake[termId][account] -= withdrawnStake;
        tierStake[termId][exitTier] -= withdrawnStake;
        uint256 residual = userStake[termId][account];

        uint256 toFulcrum = feeAmount.mulDiv(config.withdrawalToFulcrumTiersBps, BPS);
        uint256 toExitingTier = feeAmount - toFulcrum;
        uint256 undistributed;

        // (1) Exiting-tier slice -> the residual holders of the exiting tier (exiter excluded).
        // `denom` is exactly the other holders' stake in the exiting tier: `tierStake` has already had
        // `withdrawnStake` removed above and `residual` is the exiter's remainder, so the withdrawal
        // size cancels out. An exiter therefore cannot size a partial redeem to push their own tier
        // under the floor and steer the fee — `denom` does not depend on `withdrawnStake`.
        uint256 denom = tierStake[termId][exitTier] - residual;
        if (toExitingTier > 0) {
            if (_isEligibleStake(denom)) {
                accFeePerShare[termId][exitTier] += toExitingTier.fullMulDiv(ACC_PRECISION, denom);
            } else if (denom == 0) {
                // The exiting tier has no residual cohort at all, so rather than forfeit its slice to
                // the protocol, route it to the nearest eligible tier — searched above first, so the
                // holder who sat above the exiter earns it, then below. Only when no other tier holds
                // eligible stake (the last-withdrawer / empty-vault case) does it fall through to
                // {_payFulcrumTiers}, and ultimately to protocol accrual.
                (uint256 recipientTier, uint256 recipientStake) = _nearestEligibleTier(termId, exitTier);
                // Sentinel, not an occupancy test: {_nearestEligibleTier} already applies the floor and
                // returns `(0, 0)` when nothing qualifies. This only asks whether the scan found one.
                if (recipientStake > 0) {
                    accFeePerShare[termId][recipientTier] += toExitingTier.fullMulDiv(ACC_PRECISION, recipientStake);
                    emit WithdrawalFeeRerouted(termId, exitTier, recipientTier, toExitingTier);
                } else {
                    undistributed += toExitingTier;
                }
            } else {
                // The cohort exists but is sub-floor, which orphans the slice: its intended recipients
                // are disqualified. Reachable only once the floor is live, since
                // `0 < denom < minEligibleTierStake` is an empty domain at the zero default.
                // It accrues to the protocol rather than being redistributed, because every
                // redistribution route available here concentrates on one tier and is steerable by
                // whoever is willing to post the floor:
                //   - The reroute above is winner-takes-all and searches upward first, so a position
                //     one tier up takes the whole exit fee, undiluted.
                //   - Folding into the fulcrum spread is no better. A sole eligible prior tier takes
                //     its entire kernel share, and {_weighPriorTiers} records a non-zero `stakes`
                //     entry for an eligible tier even when the kernel gives it zero weight. Once the
                //     floor disqualifies every positive-weight tier, `sumWeights` is zero and
                //     {_awardNearestOrProtocol} — which reads `stakes` and ignores `weights` — hands
                //     the whole pool to a tier the kernel says earns nothing.
                // At floor 0 none of this arises: the residual cohort is eligible and receives the
                // slice, so the orphaned slice goes to the one sink with no beneficiary to steer.
                protocolAccrued += toExitingTier;
                emit ProtocolAccruedIncreased(toExitingTier);
            }
        }

        // (2) Fulcrum slice (+ any undistributable exiting-tier slice) -> the eligible prior tiers.
        _payFulcrumTiers(termId, toFulcrum + undistributed, tier, exitTier, residual);

        // Re-base against the post-distribution accumulator: excludes the exiter from their own fee.
        rewardDebt[termId][account] = residual.fullMulDiv(accFeePerShare[termId][exitTier], ACC_PRECISION);
        vaultStake[termId] -= withdrawnStake;

        emit RedeemRecorded(termId, account, withdrawnStake, feeAmount, exitTier);
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
    /// @dev Not additive across terms: this is {bankedEarnings}, a single account-wide settled balance,
    ///      plus this term's unsettled earnings. Summing it over several terms counts the settled
    ///      balance once per term. {claimableAcross} gives a total, as does {bankedEarnings} once
    ///      together with {pendingFor} per term.
    function claimable(address account, bytes32 termId) external view returns (uint256 amount) {
        return earned[account] + _pendingFor(account, termId);
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
        return earned[account];
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
        amount = earned[account];
        for (uint256 i = 0; i < length;) {
            amount += _pendingFor(account, bytes32(sorted[i]));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Shared term-scoped pending computation behind {claimable}, {pendingFor} and {claimableAcross}.
    ///      Does not consult `config.minEligibleTierStake`. The floor gates who receives future credit,
    ///      not who may surface credit already earned. Applying `_isEligibleStake` here, or in
    ///      {_settle}, {claim}, {claimable} or {claimableAcross}, would strand earned funds:
    ///      `accFeePerShare` would still hold the credit but nothing would read it out, and `earned` is
    ///      only ever written from {_settle}.
    function _pendingFor(address account, bytes32 termId) private view returns (uint256) {
        uint256 stake = userStake[termId][account];
        if (stake == 0) return 0;
        uint256 accumulated = stake.fullMulDiv(accFeePerShare[termId][userTier[termId][account]], ACC_PRECISION);
        uint256 debt = rewardDebt[termId][account];
        return accumulated > debt ? accumulated - debt : 0;
    }

    /// @notice Account-aware redeem preview: the net assets `account` would receive for `shares`,
    ///         after this curve's withdrawal fee priced at that account's recorded tier.
    /// @dev    `IMultiVault.previewRedeem` is account-agnostic and reaches {quoteRedeemFee} with
    ///         `address(0)`, which falls back to the vault's current tier. A holder's tier is their
    ///         stake-weighted average entry tier and routinely differs, so the vault-level preview
    ///         diverges from execution in both directions; this function is the holder-accurate
    ///         quote. Flat 1:1 pricing means gross assets equal shares.
    /// @dev    Not an execution-net payout. The returned figure is net of this curve's withdrawal fee
    ///         only; MultiVault additionally charges its own protocol and exit fees on the same
    ///         redemption, which this contract does not model. `assetsAfterCurveFee` is therefore
    ///         gross of those fees and may exceed the payout, equalling it only when they are zero or
    ///         round to zero, so it is not a `minAssets` value on its own. A holder-accurate net
    ///         composes: take `MultiVault.previewRedeem(...)`, add back the account-less curve fee it
    ///         used (`quoteRedeemFee(termId, address(0), grossAssets)`), then subtract `fee` below.
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
        uint256 tier = userStake[termId][account] > 0 ? userTier[termId][account] : _tierOf(vaultStake[termId]);
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

    /// @dev Settle a user's unsettled fees into `earned` and re-base their reward debt to the current
    ///      accumulator of their tier. Settles against that accumulator as it stands, without
    ///      consulting `config.minEligibleTierStake`; see {_pendingFor} for why.
    function _settle(bytes32 termId, address account) private {
        uint256 tier = userTier[termId][account];
        uint256 accumulated = userStake[termId][account].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
        uint256 debt = rewardDebt[termId][account];
        if (accumulated > debt) {
            earned[account] += accumulated - debt;
        }
        rewardDebt[termId][account] = accumulated;
    }

    /// @dev Walk the tier bands that `netStake` traverses starting from `startAssets`, and report the
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
    function _walkDepositBands(uint256 startAssets, uint256 netStake, uint256 tier, uint256 topTier)
        private
        view
        returns (uint256[] memory bandStake, uint256 bandCount, uint256 totalWeight)
    {
        // `tier <= topTier` holds for the only caller, which derives `tier` from {_tierOf} — already
        // capped at `tierCount - 1`. The clamp is defence in depth: that invariant now lives in the
        // caller rather than here, and an inverted pair would otherwise underflow into an enormous
        // allocation rather than failing legibly. Costs one comparison and cannot mask a wrong result,
        // since a walk starting above the top tier has no band to fill either way.
        bandStake = new uint256[](tier > topTier ? 1 : topTier - tier + 1);

        uint256 remaining = netStake;
        uint256 cursor = startAssets;
        while (remaining > 0) {
            uint256 chunk = remaining;
            if (tier < topTier) {
                uint256 room = _tierUpperEdge(tier) - cursor;
                if (room < chunk) chunk = room;
            }
            bandStake[bandCount] = chunk;
            totalWeight += chunk.mulDiv(_depositFeeBps(tier), BPS);
            remaining -= chunk;
            cursor += chunk;
            unchecked {
                ++tier;
                ++bandCount;
            }
        }
    }

    /// @dev Replay `netStake` band by band, distributing each band's share of `feeAmount` from that band
    ///      and then landing that band's stake, so the end state matches one deposit per band.
    ///
    ///      Apportionment: each band takes `feeAmount * bandNotionalFee / totalWeight`, where a band's
    ///      notional fee is `bandStake * rate / BPS`. Weighting by the notional fee rather than the raw
    ///      `stake * bps` product keeps every multiplication inside a 512-bit `mulDiv`; the proportions
    ///      are identical either way, since both scale every band by the same factor. The last band
    ///      takes the exact remainder instead of its computed share, making `Σ bandFee` identically
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
    function _replayDepositBands(
        bytes32 termId,
        address account,
        uint256 startAssets,
        uint256 netStake,
        uint256 feeAmount
    ) private {
        uint256 sourceTier = _tierOf(startAssets);
        uint256 topTier = config.tierCount - 1;

        // Single-band fast path. Most deposits land entirely inside the band the vault already sits
        // in. Returning here skips a second `_tierOf` (which loops over `rpow`-based edges), the
        // scratch-array allocation and the whole weighting pass.
        //
        // It dispatches into the same {_applyDepositBand} the loop below uses rather than
        // reimplementing band application, so the two cannot diverge. With one band, that band's fee
        // is the whole `feeAmount`, so there is no apportionment to do.
        if (sourceTier == topTier || startAssets + netStake <= _tierUpperEdge(sourceTier)) {
            _applyDepositBand(termId, account, sourceTier, netStake, feeAmount);
            return;
        }

        (uint256[] memory bandStake, uint256 bandCount, uint256 totalWeight) =
            _walkDepositBands(startAssets, netStake, sourceTier, topTier);

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

    /// @dev One band of a replayed deposit. The order of these three steps is the whole mechanism:
    ///
    ///      1. Distribute this band's fee, sourced at `bandTier`, so it reaches only the tiers below
    ///         it. The depositor's position sits in the denominators like anyone else's, but the
    ///         stake being deposited here has not landed yet, so it cannot be paid out of its own fee.
    ///      2. Settle, moving whatever step 1 just credited to the position at the tier it currently
    ///         occupies. This must come after step 1 and before step 3: settle first and the
    ///         depositor's share of their own fee is stranded in the accumulator; skip it and step 3's
    ///         re-base against the new tier discards it.
    ///      3. Land this band's stake at `bandTier` and re-base the reward debt against the resulting
    ///         bucket.
    ///
    ///      The average entry tier therefore ends up weighted by where the money actually landed
    ///      rather than by the single pre-deposit tier. The new bucket is the rounded stake-weighted
    ///      average of the previous position and the bands entered, so it can move in either
    ///      direction: upward for a holder climbing the ladder, downward for one whose recorded
    ///      bucket sits above the bands this deposit lands in. The withdrawal rate follows it, since
    ///      that rate keys on where a holder entered.
    function _applyDepositBand(bytes32 termId, address account, uint256 bandTier, uint256 bandStake, uint256 bandFee)
        private
    {
        _payDepositFee(termId, bandFee, bandTier);

        uint256 oldStake = userStake[termId][account];
        uint256 oldTier = userTier[termId][account];

        if (oldStake > 0) {
            _settle(termId, account);
        }

        uint256 newStake = oldStake + bandStake;
        uint256 newAvg;
        if (oldStake == 0) {
            newAvg = bandTier * TIER_PRECISION;
        } else {
            // Unrolled into per-term 512-bit-intermediate mulDivs so the weighted average cannot
            // overflow for any stake magnitude (the naive sum-of-products form already had ~99 bits
            // of headroom at max tier x total native supply, but this removes the question
            // permanently). The two floors under-round the average by at most 2 wei-tier units
            // (2e-18 of a tier) per band — far below the half-up bucket-rounding threshold.
            newAvg = userAvgTier[termId][account].fullMulDiv(oldStake, newStake)
                + (bandTier * TIER_PRECISION).fullMulDiv(bandStake, newStake);
        }
        uint256 newTier = _roundTier(newAvg);

        if (newTier != oldTier) {
            if (oldStake > 0) {
                tierStake[termId][oldTier] -= oldStake;
            }
            tierStake[termId][newTier] += newStake;
        } else {
            tierStake[termId][newTier] += bandStake;
        }

        userStake[termId][account] = newStake;
        userAvgTier[termId][account] = newAvg;
        userTier[termId][account] = newTier;
        rewardDebt[termId][account] = newStake.fullMulDiv(accFeePerShare[termId][newTier], ACC_PRECISION);

        emit DepositBandRecorded(termId, account, bandTier, bandStake, bandFee);
    }

    /// @dev Distribute one band's deposit fee `feeAmount` across the tiers below `tier`. A
    ///      `depositToPriorTierBps` slice is paid as a single lump to the nearest eligible prior tier
    ///      — the spike that rewards the immediately preceding cohort — and the remainder spreads
    ///      across the prior tiers by the sliding-fulcrum kernel ({_payFulcrumTiers}). Every recipient
    ///      denominator must clear `config.minEligibleTierStake` to qualify. When no prior tier
    ///      qualifies the spike folds into the fulcrum pool, which routes it to the nearest eligible
    ///      tier or, failing that, the protocol bucket, so the fee is never forfeited or
    ///      double-counted. `depositToPriorTierBps == 0` (the default) reduces to a pure fulcrum
    ///      distribution.
    ///
    ///      No exclusion is applied here: denominators are each tier's full stake, so the distribution
    ///      does not depend on which account pays. The zero arguments passed to {_payFulcrumTiers}
    ///      keep that helper usable by the redeem path, which does exclude the exiter so that no
    ///      account is paid out of its own exit fee.
    function _payDepositFee(bytes32 termId, uint256 feeAmount, uint256 tier) private {
        if (feeAmount == 0) return;

        uint256 toPriorTier = feeAmount.mulDiv(config.depositToPriorTierBps, BPS);
        uint256 toFulcrum = feeAmount - toPriorTier;

        // Prior-tier spike -> the single nearest eligible prior tier. If none qualifies, fold the
        // slice into the fulcrum pool rather than forfeiting it.
        if (toPriorTier > 0) {
            (uint256 recipientTier, uint256 recipientStake) = _nearestEligiblePriorTier(termId, tier);
            // Sentinel, not an occupancy test: the scan above already applies the floor.
            if (recipientStake > 0) {
                accFeePerShare[termId][recipientTier] += toPriorTier.fullMulDiv(ACC_PRECISION, recipientStake);
            } else {
                toFulcrum += toPriorTier;
            }
        }

        // Fulcrum slice (+ any un-spikable remainder) -> the prior tiers by the triangular kernel.
        _payFulcrumTiers(termId, toFulcrum, tier, 0, 0);
    }

    /// @dev Whether `stake` may receive redistributed fees — the single predicate behind every
    ///      recipient gate, so a tier can never be dropped from one and admitted to another. Callers
    ///      pass the stake that will actually receive the fee: exclusion-adjusted on the redeem leg,
    ///      raw `tierStake` on the deposit leg. The floor's own semantics are on
    ///      {DynamicFeeConfig.minEligibleTierStake}.
    ///
    ///      The `> 0` conjunct is not redundant with the floor. At a zero floor a bare
    ///      `stake >= minEligibleTierStake` holds for an empty recipient set, and the exiting-tier
    ///      branch of {recordRedeem} divides by that stake immediately, so a last-holder exit would
    ///      revert on division by zero instead of routing to the protocol.
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

    /// @dev Distribute `fulcrumFeePool` across the prior tiers `[0, tier)` by the triangular fulcrum kernel.
    ///      The peak sits at `dStar = (1 - fulcrumAlpha/BPS) * span` tiers from the source (fraction of
    ///      the span, so it slides up the ladder as the vault grows); each eligible prior tier earns
    ///      `max(0, 1 - |d - dStar|/sigma)`, normalized over eligible tiers and split pro-rata by stake,
    ///      with `excludeStake` removed from the recipient denominator at `excludeTier`. A tier below
    ///      `config.minEligibleTierStake` is absent from that normalization, so its share is absorbed by the
    ///      tiers that already qualified in proportion to their existing weights — the earning window
    ///      does not slide down to pull in a further tier, because the kernel returns a hard zero beyond
    ///      `sigma`. If a tight `sigma` zeroes every eligible tier's weight, the whole pool goes to the
    ///      eligible tier nearest the fulcrum (nearest-first tie-break) rather than leaking to the
    ///      protocol; only when no prior tier qualifies, and any rounding remainder, accrue to
    ///      `protocolAccrued`. The pass-1 weighting and the degenerate-award scan are extracted to keep
    ///      this write path within the 16-slot stack ceiling.
    function _payFulcrumTiers(
        bytes32 termId,
        uint256 fulcrumFeePool,
        uint256 tier,
        uint256 excludeTier,
        uint256 excludeStake
    ) private {
        if (fulcrumFeePool == 0) return;

        // No prior tiers (first-tier deposit): nothing to reward, route to the protocol bucket.
        uint256 span = tier;
        if (span == 0) {
            protocolAccrued += fulcrumFeePool;
            emit ProtocolAccruedIncreased(fulcrumFeePool);
            return;
        }

        // `weights`/`stakes` are indexed by `d - 1` (d = 1 is the nearest prior tier `tier - 1`;
        // d = span is the farthest, tier 0). `weights[i] > 0` implies the tier is eligible: once
        // `config.minEligibleTierStake` is live, occupancy alone is not sufficient.
        uint256 dStar = ((BPS - config.fulcrumAlpha) * span).mulDiv(TIER_PRECISION, BPS);
        uint256[] memory weights = new uint256[](span);
        uint256[] memory stakes = new uint256[](span);
        uint256 sumWeights = _weighPriorTiers(termId, span, dStar, excludeTier, excludeStake, weights, stakes);

        // Degenerate: the window missed every eligible tier, or there is none. Award to the eligible
        // tier nearest the fulcrum, else to the protocol, rather than forfeiting the pool.
        if (sumWeights == 0) {
            _awardNearestOrProtocol(termId, fulcrumFeePool, span, dStar, stakes);
            return;
        }

        // Credit each eligible tier; any rounding remainder accrues to the protocol bucket.
        uint256 unassigned = fulcrumFeePool - _creditByWeight(termId, fulcrumFeePool, span, sumWeights, weights, stakes);
        if (unassigned > 0) {
            protocolAccrued += unassigned;
            emit ProtocolAccruedIncreased(unassigned);
        }
    }

    /// @dev Pass 2 of {_payFulcrumTiers}: credit each eligible prior tier its normalized, stake-pro-rata
    ///      share of `fulcrumFeePool` and return the total assigned (the shortfall vs `fulcrumFeePool` is rounding
    /// dust).
    function _creditByWeight(
        bytes32 termId,
        uint256 fulcrumFeePool,
        uint256 span,
        uint256 sumWeights,
        uint256[] memory weights,
        uint256[] memory stakes
    ) private returns (uint256 assigned) {
        for (uint256 d = 1; d <= span;) {
            uint256 w = weights[d - 1];
            if (w > 0) {
                uint256 share = fulcrumFeePool.mulDiv(w, sumWeights);
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
    ///      `d - 1`) for every prior tier and return the summed weights over eligible tiers.
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
            // Zeroing an ineligible tier's entry here, rather than re-testing at each read site, is
            // what makes "`stakes[i] > 0` implies eligible" a structural invariant of this array. Both
            // readers ({_creditByWeight} and {_awardNearestOrProtocol}) depend on it and neither
            // re-checks. Gating only `sumWeights` instead would exclude a sub-floor tier from the
            // proportional spread and then hand it the entire pool through the degenerate fallback,
            // which scans this same array.
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

    /// @dev Degenerate branch of {_payFulcrumTiers}: award the whole `fulcrumFeePool` to the eligible tier nearest
    ///      the fulcrum, reusing the `stakes` computed in pass 1. Falls through to the protocol bucket
    ///      only when no prior tier qualifies.
    ///      Tie-break: two tiers are exactly equidistant from the fulcrum whenever `dStar` lands on a
    ///      half-integer (`span = 3, alpha = 0.5` puts it at 1.5, so `d = 1` and `d = 2` are both 0.5
    ///      away). The scan runs `d = 1..span`, nearest prior tier first, and keeps the incumbent on
    ///      equality through a strict `<`, so a tie resolves to the tier nearest the source on both
    ///      legs.
    ///      The two `> 0` tests below are sentinels rather than occupancy tests: {_weighPriorTiers}
    ///      zeroes the entry of any tier failing {_isEligibleStake}, so a non-zero entry here is
    ///      eligible by construction and this function needs no floor logic of its own.
    function _awardNearestOrProtocol(
        bytes32 termId,
        uint256 fulcrumFeePool,
        uint256 span,
        uint256 dStar,
        uint256[] memory stakes
    ) private {
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
            accFeePerShare[termId][bestTier] += fulcrumFeePool.fullMulDiv(ACC_PRECISION, bestStake);
        } else {
            protocolAccrued += fulcrumFeePool;
            emit ProtocolAccruedIncreased(fulcrumFeePool);
        }
    }

    /* =================================================== */
    /*                 INTERNAL: TIER MATH               */
    /* =================================================== */

    /// @dev Asset width of tier `k`, defined as the span between its cumulative edges:
    ///      `width(k) = edge(k) - edge(k-1)` (with `edge(-1) = 0`, so `width(0) = edge(0) = width0`).
    ///      The target law is compounding, `width0 * (1+g)^k`, each tier `(1+g)x` the one below, but
    ///      the width is derived from {_tierUpperEdge} rather than computed independently. The edges
    ///      are the single source of truth for tier boundaries ({_tierOf}) and for the piecewise fee
    ///      walk, which charges each band's `edge`-to-`edge` span. Computing the width from its own
    ///      rounded `rpow` would let `edge(k) - edge(k-1)` and the advertised width disagree by a wei
    ///      or two for non-exactly-representable ratios; deriving it here makes the reported width
    ///      equal the fee-charged band by construction, at the cost of a realized ratio slightly off
    ///      the target. `_tierUpperEdge` is strictly increasing, so the subtraction never underflows.
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

    /// @dev Nearest tier to `fromTier` holding eligible stake, searched above first (`fromTier+1`
    ///      upward to the top), then below (`fromTier-1` down to 0). Returns `(tier, stake)`, or
    ///      `(0, 0)` when no other tier qualifies. Searching above first routes an orphaned exit fee to
    ///      the holders who sat above the exiter. Bounded by `tierCount` (<= MAX_TIER_COUNT). Both
    ///      scans apply `config.minEligibleTierStake`, so a sub-floor tier cannot intercept the whole
    ///      slice merely by being nearest. Unlike the deposit-side scan there is no exclusion to apply:
    ///      the caller reaches this branch only once the exiting tier has been established as having no
    ///      eligible residual cohort, and both loops skip `fromTier` structurally.
    function _nearestEligibleTier(bytes32 termId, uint256 fromTier) private view returns (uint256 tier, uint256 stake) {
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

    /// @dev Nearest eligible tier strictly below `tier` (within the prior tiers `[0, tier)`), searched
    ///      downward from `tier - 1`. Returns `(tier, stake)`, or `(0, 0)` when no prior tier holds
    ///      eligible stake. Bounded by `tierCount`. `config.minEligibleTierStake` is applied so the
    ///      prior-tier spike cannot be intercepted by a sub-floor tier. That gate matters even though
    ///      the spike is dormant while `depositToPriorTierBps == 0`: without it, turning the spike on
    ///      would hand a sub-floor tier the whole lump that the fulcrum spread had just excluded it
    ///      from. Unlike the redeem-side scans there is no exclusion to apply — the
    ///      deposit leg puts nobody outside the denominator, see {_payDepositFee}.
    function _nearestEligiblePriorTier(bytes32 termId, uint256 tier)
        private
        view
        returns (uint256 recipientTier, uint256 recipientStake)
    {
        for (uint256 k = tier; k > 0;) {
            unchecked {
                --k;
            }
            uint256 s = tierStake[termId][k];
            if (_isEligibleStake(s)) return (k, s);
        }
        return (0, 0);
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
    ///      quoted on `assetsAfterMinSharesCost` and never learns what MultiVault withheld. That
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
    function _withdrawalFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        uint256 cap = config.withdrawalCapBps;
        if (tierOverride.isSet) {
            // Clamp against the live cap, not the cap that was in force when the override was set,
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
        // the weight) and is bounded above so the triangular math stays clear of overflow.
        //
        // A `kernelSpread` small enough that no eligible prior tier falls inside the window collapses
        // the spread into a single-tier award. The fee still reaches a real cohort and no wei is
        // forfeited, but the configured schedule and the observable behaviour stop matching. No static
        // bound prevents this: keyed on the spread alone it rejects legitimate schedules, since at
        // `fulcrumAlpha = 0` the farthest tier sits at distance zero and carries full weight at any
        // spread; keyed on `fulcrumAlpha == BPS` it does not prevent the collapse, since one tier
        // inside the window is still winner-takes-all. Whether a given pair spreads depends on live
        // occupancy at distribution time, which `setConfig` cannot observe.
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
        // one parameter that silently changes who earns, so it gets a dedicated before/after signal.
        uint256 previousMinEligibleTierStake = config.minEligibleTierStake;

        config = _config;

        // Probe the top edge under the stored schedule. The compounding math would overflow on an
        // over-steep ladder, and this computation reverts (checked `rpow` / `fullMulDiv`), so a config
        // that could brick `tierOf` on the deposit/redeem hot path is rejected before the update can
        // be committed, whether it is the initial schedule or a live retune. A zero top edge
        // (degenerate schedule) is rejected too.
        if (_tierUpperEdge(_config.tierCount - 1) == 0) revert DynamicFeeFlatPriceCurve_InvalidConfig();

        emit ConfigUpdated(
            _config.width0, _config.tierCount, _config.growthGBps, _config.fulcrumAlpha, _config.kernelSpread
        );
        if (_config.minEligibleTierStake != previousMinEligibleTierStake) {
            emit MinEligibleTierStakeUpdated(previousMinEligibleTierStake, _config.minEligibleTierStake);
        }
    }
}
