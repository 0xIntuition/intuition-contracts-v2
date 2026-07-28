// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

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
 * @dev    Economics port of `lab/curve-playground/src/model/flatFeeModel3.ts` (the executable spec):
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
 *           nearest-first window. A `depositToRecentTierShareBps` slice can additionally be paid as a
 *           lump to the nearest occupied prior tier BEFORE the fulcrum spread (0 by default = pure
 *           fulcrum), letting the immediately preceding cohort earn a configurable premium.
 *         - Withdrawal fee `min(cap, base + exitTier*growth)` (or the tier's manual override) goes to
 *           the residual holders of the exiting tier, with a configurable
 *           `withdrawalToRecentShareBps` slice routed to the prior tiers via the same fulcrum kernel;
 *           the exiter is excluded from the fee they themselves pay.
 *
 *           NOTE on what "residual holder" does and does not mean. Entitlement is established at
 *           `recordDeposit` time against the tier's then-current accumulator; there is deliberately
 *           NO dwell requirement, NO time-weighting and NO minimum holding period — this is an
 *           activity-driven redistribution, not a yield-accrual product, and earning from a later
 *           depositor or a later exiter is the intended mechanic (asserted by
 *           `test_frontRun_sandwichEarningsBoundedByVictimFee`). A position opened one transaction
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
 *         never held here — it stays in {MultiVault} at par. `Ownable` for the PoC; ownership can
 *         migrate to the parameters timelock / admin Safe in production.
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

    /* =================================================== */
    /*                        ERRORS                       */
    /* =================================================== */

    error DynamicFeeFlatPriceCurve_ZeroAddress();
    error DynamicFeeFlatPriceCurve_OnlyMultiVault();
    error DynamicFeeFlatPriceCurve_NothingToClaim();
    error DynamicFeeFlatPriceCurve_InvalidConfig();
    error DynamicFeeFlatPriceCurve_TierCountCannotShrink();
    error DynamicFeeFlatPriceCurve_InvalidTierOverride();

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
    /// @param _config The new configuration
    function setConfig(DynamicFeeConfig calldata _config) external onlyOwner {
        _setConfig(_config);
    }

    /// @notice Set a sparse manual fee override for a single tier (replaces the formula for that tier).
    /// @dev    Overriding one tier does not touch any other tier. The stored rates fully replace the
    ///         formulaic `min(cap, base + tier*growth)` but must stay within the schedule's declared
    ///         per-tier caps (`depositCapBps` / `withdrawalCapBps`) AT THE TIME THE OVERRIDE IS SET.
    ///         Note the override is read back UNCLAMPED: it is not re-validated if a cap is later
    ///         LOWERED, so a cap reduction does not retroactively tighten a tier that already carries
    ///         an override. Clear the override explicitly when tightening a cap.
    ///         Bounding the withdrawal rate matters, and the damaging failure mode is NOT a revert:
    ///         at exactly `BPS` the redeem underflows `assets - fees` in MultiVault and reverts, but
    ///         at any rate strictly INSIDE the cap that still exceeds the payout, the redemption
    ///         SUCCEEDS and pays the redeemer ZERO while burning their shares — MultiVault enforces
    ///         no floor on the payout and `previewRedeem` reports the same zero without erroring.
    ///         Keep `withdrawalCapBps` at a value that cannot consume a redemption (the shipped
    ///         schedule uses 1000 bps = 10%).
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
    ///      optional `depositToRecentTierShareBps` lump to the nearest occupied prior tier, the rest by
    ///      the sliding-fulcrum kernel, with the depositor excluded from their own fee. `onlyMultiVault`.
    function recordDeposit(bytes32 termId, address account, uint256 netStake) external payable override onlyMultiVault {
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
        // every recipient denominator. A `depositToRecentTierShareBps` slice is paid as a lump to the
        // nearest occupied prior tier (the recent-tier spike); the remainder spreads by the sliding
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
    ///      of the exiting tier (and optionally the recent-N tiers per policy), excluding the exiter.
    ///      When the exiting tier has no residual cohort, the diamond slice falls through to the
    ///      nearest occupied tier (above first, then below) rather than to the protocol, so a stayer
    ///      earns a departing whale's exit fee. `onlyMultiVault`.
    function recordRedeem(bytes32 termId, address account, uint256 withdrawnStake)
        external
        payable
        override
        onlyMultiVault
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

        uint256 toRecent = pool.mulDiv(config.withdrawalToRecentShareBps, BPS);
        uint256 toTier = pool - toRecent;
        uint256 undistributed;

        // (1) Diamond-hands slice -> the residual holders of the exiting tier (exiter excluded).
        uint256 denom = tierStake[termId][exitTier] - residual;
        if (toTier > 0) {
            if (denom > 0) {
                accFeePerShare[termId][exitTier] += toTier.fullMulDiv(ACC_PRECISION, denom);
            } else {
                // Whale-exit fallback: the exiting tier has no residual cohort, so rather than forfeit
                // the diamond slice to the protocol, route it to the nearest occupied tier — searched
                // ABOVE first (the stayer who sat above the exiting whale earns it), then below. Only
                // when NO other tier holds stake (the last-withdrawer / empty-vault case) does it fall
                // through to `_payRecentTiers`, and ultimately to protocol accrual.
                (uint256 recipientTier, uint256 recipientStake) = _nearestOccupiedTier(termId, exitTier);
                if (recipientStake > 0) {
                    accFeePerShare[termId][recipientTier] += toTier.fullMulDiv(ACC_PRECISION, recipientStake);
                    emit WithdrawalFeeRerouted(termId, exitTier, recipientTier, toTier);
                } else {
                    undistributed += toTier;
                }
            }
        }

        // (2) Frontier slice (+ any un-distributable diamond slice) -> the recent-N prior tiers.
        _payRecentTiers(termId, toRecent + undistributed, tier, exitTier, residual);

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
    function claimable(address account, bytes32 termId) external view returns (uint256 amount) {
        uint256 stake = userStake[termId][account];
        uint256 pending;
        if (stake > 0) {
            uint256 accumulated = stake.fullMulDiv(accFeePerShare[termId][userTier[termId][account]], ACC_PRECISION);
            uint256 debt = rewardDebt[termId][account];
            pending = accumulated > debt ? accumulated - debt : 0;
        }
        return earned[account] + pending;
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
    function _settle(bytes32 termId, address account) private {
        uint256 tier = userTier[termId][account];
        uint256 accumulated = userStake[termId][account].fullMulDiv(accFeePerShare[termId][tier], ACC_PRECISION);
        uint256 debt = rewardDebt[termId][account];
        if (accumulated > debt) {
            earned[account] += accumulated - debt;
        }
        rewardDebt[termId][account] = accumulated;
    }

    /// @dev Distribute a deposit fee `pool` across the prior tiers. A `depositToRecentTierShareBps`
    ///      slice is paid as a single lump to the nearest OCCUPIED prior tier — the "recent-tier" spike
    ///      that rewards the immediately preceding cohort — and the remainder spreads across the prior
    ///      tiers by the sliding-fulcrum kernel ({_payRecentTiers}). The depositor's own pre-deposit
    ///      stake (`excludeStake` at `excludeTier`) is removed from every recipient denominator. When no
    ///      prior tier holds stake the spike folds into the fulcrum pool, which routes it to the nearest
    ///      occupied tier or, failing that, the protocol bucket — so the fee is never forfeited or
    ///      double-counted. `depositToRecentTierShareBps == 0` (the default) reduces to a pure fulcrum
    ///      distribution, identical to the pre-split behavior.
    function _payDepositFee(bytes32 termId, uint256 pool, uint256 tier, uint256 excludeTier, uint256 excludeStake)
        private
    {
        if (pool == 0) return;

        uint256 toRecentTier = pool.mulDiv(config.depositToRecentTierShareBps, BPS);
        uint256 toFulcrum = pool - toRecentTier;

        // Recent-tier spike -> the single nearest occupied prior tier (depositor excluded). If none is
        // occupied, fold the slice into the fulcrum pool rather than forfeiting it.
        if (toRecentTier > 0) {
            (uint256 recipientTier, uint256 recipientStake) =
                _nearestOccupiedPriorTier(termId, tier, excludeTier, excludeStake);
            if (recipientStake > 0) {
                accFeePerShare[termId][recipientTier] += toRecentTier.fullMulDiv(ACC_PRECISION, recipientStake);
            } else {
                toFulcrum += toRecentTier;
            }
        }

        // Fulcrum slice (+ any un-spikable remainder) -> the prior tiers by the triangular kernel.
        _payRecentTiers(termId, toFulcrum, tier, excludeTier, excludeStake);
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
    ///      the span, so it slides up the ladder as the vault grows); each occupied prior tier earns
    ///      `max(0, 1 - |d - dStar|/sigma)`, normalized over occupied tiers and split pro-rata by stake,
    ///      with `excludeStake` removed from the recipient denominator at `excludeTier`. If a tight
    ///      `sigma` zeroes every occupied tier's weight, the whole pool goes to the occupied tier
    ///      nearest the fulcrum (nearest-first tie-break) rather than leaking to the protocol; only when
    ///      NO prior tier holds stake, and any rounding remainder, accrue to `protocolAccrued`. The
    ///      pass-1 weighting and the degenerate-award scan are extracted to keep this write path within
    ///      the 16-slot stack ceiling.
    function _payRecentTiers(bytes32 termId, uint256 pool, uint256 tier, uint256 excludeTier, uint256 excludeStake)
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
        // d = span is the farthest, tier 0). `weights[i] > 0` implies the tier is occupied.
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

    /// @dev Pass 2 of {_payRecentTiers}: credit each occupied prior tier its normalized, stake-pro-rata
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

    /// @dev Pass 1 of {_payRecentTiers}: fill `weights` and `stakes` (both length `span`, indexed by
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

    /// @dev Degenerate branch of {_payRecentTiers}: award the whole `pool` to the occupied tier nearest
    ///      the fulcrum (nearest-first tie-break via strict `<`, matching the playground spec), reusing
    ///      the `stakes` computed in pass 1. Falls through to the protocol bucket only when no prior
    ///      tier holds stake.
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

    /// @dev Nearest tier to `fromTier` that holds stake, searched ABOVE first (`fromTier+1` upward to
    ///      the top), then below (`fromTier-1` down to 0). Returns `(tier, stake)`, or `(0, 0)` when no
    ///      other tier is occupied. Above-first is deliberate: it routes a departing whale's orphaned
    ///      exit fee to the stayer who sat above them. Bounded by `tierCount` (<= MAX_TIER_COUNT).
    function _nearestOccupiedTier(bytes32 termId, uint256 fromTier) private view returns (uint256 tier, uint256 stake) {
        uint256 tierCount = config.tierCount;
        for (uint256 k = fromTier + 1; k < tierCount;) {
            uint256 s = tierStake[termId][k];
            if (s > 0) return (k, s);
            unchecked {
                ++k;
            }
        }
        for (uint256 k = fromTier; k > 0;) {
            unchecked {
                --k;
            }
            uint256 s = tierStake[termId][k];
            if (s > 0) return (k, s);
        }
        return (0, 0);
    }

    /// @dev Nearest OCCUPIED tier strictly below `tier` (within the prior tiers `[0, tier)`), searched
    ///      downward from `tier - 1`, with `excludeStake` removed at `excludeTier` so the depositor's
    ///      own pre-deposit stake can never be a recipient of its own fee. Returns `(tier, stake)` after
    ///      exclusion, or `(0, 0)` when no prior tier holds eligible stake. Bounded by `tierCount`.
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
            if (s > 0) return (k, s);
        }
        return (0, 0);
    }

    /// @dev The tier's manual override if set, else the formulaic min(cap, base + tier*growth).
    function _depositFeeBps(uint256 tier) private view returns (uint256) {
        TierFeeOverride storage tierOverride = tierFeeOverride[tier];
        if (tierOverride.isSet) {
            return tierOverride.depositFeeBps;
        }
        uint256 fee = config.depositBaseBps + tier * config.depositGrowthBps;
        uint256 cap = config.depositCapBps;
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
        if (tierOverride.isSet) {
            return tierOverride.withdrawalFeeBps;
        }
        uint256 fee = config.withdrawalBaseBps + tier * config.withdrawalGrowthBps;
        uint256 cap = config.withdrawalCapBps;
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
        if (_config.depositBaseBps > _config.depositCapBps || _config.depositCapBps > BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.withdrawalBaseBps > _config.withdrawalCapBps || _config.withdrawalCapBps > BPS) {
            revert DynamicFeeFlatPriceCurve_InvalidConfig();
        }
        if (_config.withdrawalToRecentShareBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();
        if (_config.depositToRecentTierShareBps > BPS) revert DynamicFeeFlatPriceCurve_InvalidConfig();

        config = _config;

        // Probe the top edge under the stored schedule. The compounding math would overflow on an
        // over-steep ladder, and this computation reverts (checked `rpow` / `fullMulDiv`) — so a config
        // that could brick `tierOf` on the deposit/redeem hot path is rejected here, before any
        // position exists, rather than after. A zero top edge (degenerate schedule) is rejected too.
        if (_tierUpperEdge(_config.tierCount - 1) == 0) revert DynamicFeeFlatPriceCurve_InvalidConfig();

        emit ConfigUpdated(
            _config.width0, _config.tierCount, _config.growthGBps, _config.fulcrumAlpha, _config.kernelSpread
        );
    }
}
