// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/// @notice Owner-set tier and fee configuration for {DynamicFeeFlatPriceCurve}. Fee rates are in basis
///         points over {DynamicFeeFlatPriceCurve.BPS}. The struct is validated on write: the tier
///         count, kernel spread, fee caps and eligibility floor against immutable ceilings on the
///         curve, the rest against `BPS`, relational or type bounds, except the two growth rates,
///         which are unbounded on write and clamped to their cap at read time. The mechanism is
///         specified on the implementation.
/// @dev    The curve stores this struct inline (`config`) before its fee-accounting mappings, so
///         appending a field shifts every subsequent storage slot. That is safe for a fresh deploy
///         under a new curve id, but an in-place proxy upgrade that grows the struct would orphan the
///         accounting and needs reserved slots or a migration. Fields added once the curve is live
///         belong in their own slot after `protocolAccrued`.
struct DynamicFeeConfig {
    /// @dev Asset width (TRUST wei) of tier 0; later tiers widen geometrically by `growthGBps`.
    uint256 width0;
    /// @dev Number of tiers before the schedule tops out. `1..MAX_TIER_COUNT`.
    uint256 tierCount;
    /// @dev Per-tier compounding width growth, in bps. The cumulative tier edge is the geometric series
    ///      `edge(k) = width0 * ((1 + growthGBps/BPS)^(k+1) - 1) / (growthGBps/BPS)`, and a tier's width
    ///      is the span between edges, `width(k) = edge(k) - edge(k-1)`. Widths are derived from the
    ///      edges rather than from an independently rounded `width0 * (1 + growthGBps/BPS)^k`, so the
    ///      advertised width and the band a deposit is charged on cannot disagree. The target
    ///      progression is geometric, each band `(1 + growthGBps/BPS)x` the one below, and the edge
    ///      difference is the exact on-chain width, so fixed-point rounding can leave the realized
    ///      ratio slightly off target. 0 gives a flat ladder of `width0`-wide bands.
    uint256 growthGBps;
    /// @dev Deposit fee in tier 0, in bps.
    uint256 depositBaseBps;
    /// @dev Added deposit-fee bps per tier climbed.
    uint256 depositGrowthBps;
    /// @dev Cap on the per-tier deposit fee, in bps.
    uint256 depositCapBps;
    /// @dev Sliding-fulcrum position, in bps `[0, BPS]`. A deposit fee is split across the prior tiers
    ///      by a triangular weight kernel peaking at `dStar = (1 - fulcrumAlpha/BPS) * span` tiers from
    ///      the source, where `span` is the number of prior tiers. `BPS` peaks on the nearest tier, `0`
    ///      on the farthest. Because the peak is a fraction of the span, it moves up the ladder as the
    ///      vault grows.
    uint256 fulcrumAlpha;
    /// @dev Triangular spread, in `TIER_PRECISION` (1e18) units of tiers. A tier at distance `d` earns
    ///      `max(0, 1 - |d - dStar| / kernelSpread)`, an earning window roughly `2 * kernelSpread` tiers
    ///      wide with a hard zero beyond it. Must be non-zero. At `4e18` with `fulcrumAlpha = BPS`
    ///      the three nearest tiers earn 50 / 33.3 / 16.7 when all three are eligible; an empty or
    ///      sub-floor tier drops out of the normalization and changes the split.
    uint256 kernelSpread;
    /// @dev Withdrawal fee in tier 0, in bps.
    uint256 withdrawalBaseBps;
    /// @dev Added withdrawal-fee bps per tier climbed.
    uint256 withdrawalGrowthBps;
    /// @dev Cap on the per-tier withdrawal fee, in bps.
    uint256 withdrawalCapBps;
    /// @dev Fraction (bps, `0..BPS`) of each withdrawal fee routed to the prior tiers through the
    ///      triangular kernel. The remainder goes to the exiting tier's other holders, so `0` routes
    ///      the whole withdrawal fee there. If that cohort is empty the remainder reroutes to the
    ///      nearest eligible tier; if it holds stake but less than `minEligibleTierStake` the
    ///      remainder accrues to the protocol bucket. Entitlement carries no dwell requirement.
    uint256 withdrawalToFulcrumTiersBps;
    /// @dev Fraction (bps, `0..BPS`) of each deposit fee paid as a single lump to the nearest eligible
    ///      prior tier, on top of the kernel spread. The remaining `BPS - depositToPriorTierBps` is
    ///      spread by the kernel. The search runs downward from the source tier and applies
    ///      `minEligibleTierStake`; no stake is excluded on the deposit path. If no prior tier
    ///      qualifies, the lump rejoins the kernel pool and ultimately the protocol bucket, so it is
    ///      never forfeited. `0` gives a pure kernel spread and is the default.
    ///      This field and `withdrawalToFulcrumTiersBps` each name the allocation being opted into
    ///      rather than a common side of the split, so on both legs `0` is the default and a larger
    ///      value means more of what the name points at.
    uint256 depositToPriorTierBps;
    /// @dev Minimum stake a tier must hold to receive redistributed fees, denominated in shares to match
    ///      `tierStake`. Shares and assets coincide here only because this curve holds price at 1:1.
    ///      `0` disables the filter, reducing eligibility to a non-zero occupancy check. Bounded above
    ///      by {DynamicFeeFlatPriceCurve.MAX_MIN_ELIGIBLE_TIER_STAKE}.
    ///
    ///      Judged on the stake that will receive the fee: the redeem leg removes the exiter's own
    ///      residual first, the deposit leg judges a tier on its full stake. Applied at distribution
    ///      time from the current config, with no snapshot and no migration on change. Where an excluded
    ///      tier's share goes differs between the two legs; see the implementation.
    uint256 minEligibleTierStake;
}

/// @notice Owner-set manual fee rate for a single tier, consulted before the formulaic schedule.
///         `isSet == false` inherits `min(cap, base + tier * growth)`. `isSet == true` replaces both the
///         deposit and withdrawal rate for that tier, bounded by the schedule's `depositCapBps` and
///         `withdrawalCapBps`, so an override stays inside the same envelope while an explicit 0-bps
///         override remains expressible.
struct TierFeeOverride {
    /// @dev Whether this tier carries a manual override, distinguishing an explicit 0 bps from unset.
    bool isSet;
    /// @dev Manual deposit fee for the tier, in bps.
    uint16 depositFeeBps;
    /// @dev Manual withdrawal fee for the tier, in bps.
    uint16 withdrawalFeeBps;
}

/**
 * @title  IDynamicFeeFlatPriceCurve
 * @author 0xIntuition
 * @notice Curve-specific surface of {DynamicFeeFlatPriceCurve}: the authorized caller and the claim
 *         economy. Pricing and the standard fee hooks come from {IBaseCurve}.
 *
 *         Earnings sit in two places. Each term accrues unsettled earnings in its own accumulator,
 *         and every account has one settled balance shared across all terms. Settling a term moves
 *         its unsettled amount into that balance; {claim} settles the terms it is given and then pays
 *         out the whole settled balance, reverting `NothingToClaim` when that total is zero.
 *
 *         The read functions are that same total for different arguments, each equal to what the
 *         matching {claim} call pays whenever the total is non-zero:
 *           {bankedEarnings}(a)        == `claim([])`      — settled balance only
 *           {claimable}(a, t)          == `claim([t])`     — settled balance + term `t`
 *           {claimableAcross}(a, ts)   == `claim(ts)`      — settled balance + those terms
 *           {pendingFor}(a, t)         — term `t` unsettled only; the one figure that excludes the
 *                                        settled balance, and so the only one additive across terms
 */
interface IDynamicFeeFlatPriceCurve {
    /// @notice The {MultiVault} authorized to call the record hooks.
    function multiVault() external view returns (address);

    /// @notice Pull all earned fees (native TRUST) for `msg.sender`, settling the supplied vaults first.
    /// @dev Reverts `NothingToClaim` when the settled balance is zero after settling `termIds`.
    /// @param termIds The caller's dynamic-fee vaults to settle before paying out
    /// @return amount The TRUST wei transferred to the caller
    function claim(bytes32[] calldata termIds) external returns (uint256 amount);

    /// @notice What `claim([termId])` would pay `account`: the settled balance plus this term's
    ///         unsettled earnings.
    /// @dev Carries the account-wide settled balance, so summing this across terms counts that balance
    ///      once per term. {claimableAcross} gives a multi-term total.
    /// @param account The account to read
    /// @param termId The term (atom or triple) to read
    /// @return amount The settled balance plus this term's unsettled earnings
    function claimable(address account, bytes32 termId) external view returns (uint256 amount);

    /// @notice Term-scoped unsettled earnings, excluding the settled balance. Additive across terms.
    /// @param account The account to read
    /// @param termId The term (atom or triple) to read
    /// @return amount The term-scoped pending amount
    function pendingFor(address account, bytes32 termId) external view returns (uint256 amount);

    /// @notice The account's settled balance: earnings already moved out of the per-term accumulators
    ///         and awaiting claim, which is what `claim([])` pays when it is non-zero. This excludes
    ///         anything still unsettled in a term, so it is not an account-wide total —
    ///         {claimableAcross} is.
    /// @param account The account to read
    /// @return amount The settled, unclaimed balance
    function bankedEarnings(address account) external view returns (uint256 amount);

    /// @notice What `claim(termIds)` would pay: the settled balance plus those terms' unsettled earnings.
    /// @dev `termIds` must be unique; order is irrelevant and an empty set returns the settled balance,
    ///      matching `claim([])`. Reverts on a repeated term.
    /// @param account The account to read
    /// @param termIds The terms to include, without repeats; may be empty
    /// @return amount The total claimable amount
    function claimableAcross(address account, bytes32[] calldata termIds) external view returns (uint256 amount);

    /// @notice Account-aware redeem preview, net of this curve's withdrawal fee only.
    /// @dev MultiVault's protocol and exit fees are not modelled here, so `assetsAfterCurveFee` is
    ///      gross of them and may exceed the execution payout, equalling it only when those fees are
    ///      zero or round to zero. It has to be composed with them to give a `minAssets` value.
    /// @param termId The term being redeemed from
    /// @param account The redeeming account
    /// @param shares The share amount to preview
    /// @return assetsAfterCurveFee Gross assets less this curve's withdrawal fee for `account`,
    ///                             still gross of MultiVault's own protocol and exit fees
    /// @return fee The curve withdrawal fee `account` would pay
    function previewRedeemFor(bytes32 termId, address account, uint256 shares)
        external
        view
        returns (uint256 assetsAfterCurveFee, uint256 fee);
}
