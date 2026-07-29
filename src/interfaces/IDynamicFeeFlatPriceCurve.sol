// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/// @notice Tunable configuration for the {DynamicFeeFlatPriceCurve}. All fee rates are expressed in
///         basis points (bps) over {DynamicFeeFlatPriceCurve.BPS}. The tier schedule and split are the
///         fixed-point port of the `flatFeeModel3.ts` playground spec; the exact production numbers
///         are still being finalized by the ongoing mechanics-lock and modeling work, so every field
///         is tunable.
/// @dev    Storage note: {DynamicFeeFlatPriceCurve} stores this struct inline (`config`) BEFORE its
///         fee-accounting mappings, so appending a field grows the struct and shifts every subsequent
///         curve storage slot. That is safe for a FRESH deploy (a new curve id) — which is how this
///         curve ships — but a live-proxy upgrade that grows this struct would orphan the accounting and
///         must reserve or migrate slots.
///         Read that as a deadline, not just a warning: every field this struct will ever hold must be
///         added BEFORE the first deploy, because pre-deploy is the only moment the layout is free to
///         change. `minEligibleTierStake` was added under exactly that rule. Anything added after the
///         curve is live must go in its own slot after `protocolAccrued` instead.
struct DynamicFeeConfig {
    /// @dev Asset width (TRUST wei) of tier 0; later tiers widen geometrically by `growthGBps`.
    uint256 width0;
    /// @dev Number of tiers before the schedule tops out. `1..MAX_TIER_COUNT`.
    uint256 tierCount;
    /// @dev Per-tier compounding width growth, in bps. The cumulative tier edge is the geometric series
    ///      `edge(k) = width0 * ((1 + growthGBps/BPS)^(k+1) - 1) / (growthGBps/BPS)`, and a tier's width
    ///      is defined as the span between edges, `width(k) = edge(k) - edge(k-1)` — conceptually
    ///      `width0 * (1 + growthGBps/BPS)^k`, but derive it from the edges rather than re-computing the
    ///      power independently, or fixed-point rounding will make the two disagree by a wei or two.
    ///      Each band is thus `(1 + growthGBps/BPS)x` the one below it and the ladder widens
    ///      asymptotically. 0 = flat (every band is `width0` wide).
    uint256 growthGBps;
    /// @dev Deposit fee in tier 0, in bps.
    uint256 depositBaseBps;
    /// @dev Added deposit-fee bps per tier climbed (the FOMO tax).
    uint256 depositGrowthBps;
    /// @dev Cap on the per-tier deposit fee, in bps.
    uint256 depositCapBps;
    /// @dev Sliding-fulcrum position, in bps `[0, BPS]`. A released deposit fee is split across the
    ///      prior tiers by a triangular weight kernel that peaks at a fulcrum a fraction of the way
    ///      down the ladder: `dStar = (1 - fulcrumAlpha/BPS) * span` (distance from the source, where
    ///      `span` is the number of prior tiers). `fulcrumAlpha = BPS` peaks on the NEAREST tier
    ///      (nearest-first — the legacy nearest-N window); `0` peaks on the FARTHEST (earliest holders);
    ///      intermediate values place the most-earning band mid-ladder, and because the peak is a
    ///      fraction of `span` it slides UP the ladder as the vault grows.
    uint256 fulcrumAlpha;
    /// @dev Triangular spread `σ` in `TIER_PRECISION` (1e18) units of TIERS — how many tiers around the
    ///      fulcrum still earn. A tier at distance `d` earns weight `max(0, 1 - |d - dStar| / σ)`, so
    ///      the earning window is ~`2σ` tiers wide with a hard zero beyond it. Must be > 0. Default 4e18
    ///      with `fulcrumAlpha = BPS` reproduces the legacy nearest-first window at 50 / 33.3 / 16.7.
    uint256 kernelSpread;
    /// @dev Withdrawal fee in tier 0, in bps.
    uint256 withdrawalBaseBps;
    /// @dev Added withdrawal-fee bps per tier climbed.
    uint256 withdrawalGrowthBps;
    /// @dev Cap on the per-tier withdrawal fee, in bps.
    uint256 withdrawalCapBps;
    /// @dev Fraction (bps, 0..BPS) of each withdrawal fee routed to the prior tiers via the same
    ///      triangular fulcrum kernel (the "frontier" slice); the remainder goes to the leaver's OWN
    ///      tier, split across whoever else occupies it at that moment. 0 (the shipped default)
    ///      routes the ENTIRE withdrawal fee to the exiting tier's other occupants. Entitlement
    ///      carries no dwell requirement — see the `recordRedeem` notes on the implementation.
    ///
    ///      NAMING NOTE (covers this field and `depositToPriorTierBps`): the two knobs name OPPOSITE
    ///      sides of their respective splits. That asymmetry is deliberate, not an oversight. Each is
    ///      named for the allocation you opt INTO, so `0` means "default behaviour only" on both legs,
    ///      and a larger value always means "more of the thing the name points at". The defaults differ
    ///      because the primary lever differs per leg: the fulcrum spread is the deposit default,
    ///      while the exiting tier is the withdrawal default. Naming both after the same side would
    ///      have forced one of them to default to `BPS` rather than `0`, which is the more error-prone
    ///      arrangement for a value that is set by hand.
    uint256 withdrawalToFulcrumTiersBps;
    /// @dev Fraction (bps, 0..BPS) of each DEPOSIT fee paid as a single lump to the nearest OCCUPIED
    ///      prior tier — the "prior-tier" spike that rewards the immediately preceding cohort on top of
    ///      the sliding-fulcrum spread. Like `withdrawalToFulcrumTiersBps` it names the opt-in side of
    ///      its split, which on this leg is the single-tier lump rather than the fulcrum spread — see
    ///      the naming note on that field. The remaining `BPS - depositToPriorTierBps` is distributed
    ///      across the prior tiers by the triangular fulcrum kernel exactly as before. The nearest
    ///      occupied prior tier is searched downward from the source tier (depositor's own stake
    ///      excluded); if no prior tier holds stake the spike folds back into the fulcrum pool, and
    ///      ultimately the protocol bucket, so nothing is forfeited. 0 = pure fulcrum — the deposit-side
    ///      default, leaving distribution unchanged.
    uint256 depositToPriorTierBps;
    /// @dev Minimum stake a tier must hold to receive redistributed fees. `0` (the shipped default)
    ///      disables the filter entirely and reproduces the plain "holds any stake at all" test, so the
    ///      mechanism is inert until governance turns it on. Bounded above by
    ///      {DynamicFeeFlatPriceCurve.MAX_MIN_ELIGIBLE_TIER_STAKE}.
    ///      DENOMINATED IN SHARES, matching `tierStake` — not in the asset units the width fields use.
    ///      Shares and assets coincide here only because this curve holds price at exactly 1:1.
    ///      Judged on the EXCLUSION-ADJUSTED stake: the payer's own position is removed before the test,
    ///      so the quantity that must clear the floor is the stake that will actually receive the fee.
    ///      Read live at distribution time — no snapshot, no migration on change. See the field's notes
    ///      on the implementation for where an excluded tier's share goes, which differs between the
    ///      deposit and redeem paths.
    uint256 minEligibleTierStake;
}

/// @notice A sparse, owner-set manual fee rate for a single tier. Consulted before the formulaic
///         schedule: `isSet == false` inherits `min(cap, base + tier*growth)`; `isSet == true`
///         replaces both the deposit and withdrawal rate for that tier with the stored bps (bounded
///         by the schedule's `depositCapBps` / `withdrawalCapBps`, so the override stays within the
///         same envelope as the formula while an explicit 0-bps override remains expressible).
struct TierFeeOverride {
    /// @dev Whether this tier carries a manual override (distinguishes an explicit 0-bps from "unset").
    bool isSet;
    /// @dev Manual deposit fee for the tier, in bps.
    uint16 depositFeeBps;
    /// @dev Manual withdrawal fee for the tier, in bps.
    uint16 withdrawalFeeBps;
}

/**
 * @title  IDynamicFeeFlatPriceCurve
 * @author 0xIntuition
 * @notice Interface for the {DynamicFeeFlatPriceCurve}, the self-contained flat-price bonding curve
 *         that also owns the per-vault fee-accounting + redistribution economy. The pricing surface
 *         (1:1 at par) and the standardized fee-hook surface (quote + record, signaled via the
 *         per-path hook getters) are both served through {IBaseCurve}; this interface covers only
 *         the curve-specific extras: the authorized caller getter and the claim economy.
 */
interface IDynamicFeeFlatPriceCurve {
    /// @notice The {MultiVault} that is authorized to call the record hooks.
    function multiVault() external view returns (address);

    /// @notice Pull all earned fees (native TRUST) for `msg.sender`, settling the supplied vaults first.
    /// @param termIds The caller's dynamic-fee vaults to settle before paying out
    /// @return amount The TRUST wei transferred to the caller
    function claim(bytes32[] calldata termIds) external returns (uint256 amount);

    /// @notice View the caller-claimable amount for a user in a vault (booked + unsettled pending).
    function claimable(address account, bytes32 termId) external view returns (uint256 amount);

    /// @notice Unsettled pending earnings for ONE term only. Additive across terms.
    /// @param account The account to read
    /// @param termId The term (atom or triple) to read
    /// @return amount The term-scoped pending amount, excluding any banked balance
    function pendingFor(address account, bytes32 termId) external view returns (uint256 amount);

    /// @notice Banked, term-independent earnings already settled to the account's balance.
    /// @dev Add this ONCE across any set of terms — it is not per-term.
    /// @param account The account to read
    /// @return amount The banked balance
    function bankedEarnings(address account) external view returns (uint256 amount);

    /// @notice Total withdrawable across the supplied terms — the figure `claim` would pay.
    /// @dev `termIds` must be non-empty and unique; order is irrelevant. Reverts on an empty array or a repeat.
    /// @param account The account to read
    /// @param termIds The terms to include, non-empty, in any order, without repeats
    /// @return amount The total claimable amount
    function claimableAcross(address account, bytes32[] calldata termIds) external view returns (uint256 amount);

    /// @notice Account-aware redeem preview, net of THIS CURVE's withdrawal fee only.
    /// @dev Not an execution-net payout — MultiVault's protocol and exit fees are not modelled here.
    ///      See the implementation NatSpec for the composition rule. Never use as `minAssets`.
    /// @param termId The term being redeemed from
    /// @param account The redeeming account
    /// @param shares The share amount to preview
    /// @return assetsAfterCurveFee Gross assets less this curve's withdrawal fee for `account`
    /// @return fee The curve withdrawal fee `account` would pay
    function previewRedeemFor(bytes32 termId, address account, uint256 shares)
        external
        view
        returns (uint256 assetsAfterCurveFee, uint256 fee);
}
