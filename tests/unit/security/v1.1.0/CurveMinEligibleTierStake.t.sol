// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, Vm } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveMinEligibleTierStakeTest
/// @notice Covers the two recipient gates that decide what a partly filled tier earns: the per-tier
///         cap, which scales every credit by `min(1, stake / width)` and is always on, and
///         `minEligibleTierStakeBps`, the floor a tier must hold, as a fraction of its width, to take
///         part in a distribution at all.
/// @dev    Driven in ISOLATION — the test contract stands in as the authorized MultiVault and calls the
///         record hooks directly, forwarding the fee as native value. That is what makes exact per-tier
///         amounts assertable: every suite driven through the real MultiVault can only assert bounds,
///         because MultiVault's own entry/exit/protocol fees move the numbers.
///
///         The ladder used throughout: `width0 = 10 TRUST`, 5 tiers, `g = 0.2`. Widths compound 1.2x —
///         10, 12, 14.4, 17.28, 20.736 — so the cumulative edges are 10, 22, 36.4, 53.68, 74.416 (x1e18).
///         With `depositFulcrumAlphaBps = BPS` the fulcrum sits on the source (`dStar = 0`) and `sigma = 4e18`
///         gives the nearest-first triangular window: weights 0.75 / 0.5 / 0.25 / 0 at distances
///         d = 1 / 2 / 3 / 4.
///
///         A partly filled tier cannot be built by deposit alone — a fresh depositor is bucketed into
///         the tier the vault currently occupies, so whoever pushes the vault past a band also lands in
///         it. Thin tiers are therefore created by redeeming a seated position down, with a zero fee so
///         the teardown distributes nothing of its own, while a topper in the terminal tier keeps the
///         vault above the tiers being thinned.
///
///         "Diamond slice" and "diamond-hands slice" below both mean the exiting-tier slice: the
///         portion of a redeem fee that goes to the exiting tier's other holders.
contract CurveMinEligibleTierStakeTest is Test {
    DynamicFeeFlatPriceCurve internal curve;

    address internal proxyAdmin = address(0xAD);
    address internal owner = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal eve = makeAddr("eve");
    address internal frank = makeAddr("frank");

    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";
    uint256 internal constant BPS = 10_000;

    bytes32 internal constant T1 = keccak256("term-1");

    /// @dev Ceiling on the custody that may go unattributed across the fuzz fixture's two distributions —
    ///      the accumulator's per-share truncation, bounded by `tierStake / ACC_PRECISION` per credited
    ///      tier per distribution. Generous against the real bound and still nine orders of magnitude
    ///      below the fees moved.
    uint256 internal constant MAX_TRUNCATION_DUST_WEI = 1000;

    function setUp() public {
        curve = _deploy(_defaultConfig());
        vm.deal(address(this), 1_000_000e18);
    }

    /* =================================================== */
    /*                      HELPERS                        */
    /* =================================================== */

    function _deploy(DynamicFeeConfig memory config) internal returns (DynamicFeeFlatPriceCurve) {
        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdmin,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector, CURVE_NAME, owner, address(this), config
            )
        );
        return DynamicFeeFlatPriceCurve(address(proxy));
    }

    function _defaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 5,
            tierWidthGrowthBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            depositFulcrumAlphaBps: 10_000,
            depositKernelSpread: 4e18,
            redeemFulcrumAlphaBps: 10_000,
            redeemKernelSpread: 4e18,
            redeemBaseBps: 200,
            redeemGrowthBps: 50,
            redeemCapBps: 1000,
            redeemToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStakeBps: 0
        });
    }

    /// @dev Populate tiers 0..3 with one holder each, leaving the vault in tier 4. Stakes are exactly the
    ///      tier widths: 10 / 12 / 14.4 / 17.28 TRUST, so every tier is exactly full and the cap is
    ///      inert. A holder's bucket is the vault's tier at the moment they deposit, so walking the
    ///      vault up the ladder one band at a time seats them in ascending tiers.
    function _seatFourTiers(DynamicFeeFlatPriceCurve c) internal {
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18   (tier 2)
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // bucket 2; vault -> 36.4e18 (tier 3)
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // bucket 3; vault -> 53.68e18 (tier 4)
    }

    /// @dev {_seatFourTiers} plus a large topper seated in the terminal tier, so that thinning any of
    ///      the four lower tiers afterwards leaves the vault in tier 4 and every probe deposit spreads
    ///      over the same four prior tiers. Tier 4 is the top tier, so the vault may exceed its edge.
    function _seatFourTiersToppedAt4(DynamicFeeFlatPriceCurve c) internal {
        _seatFourTiers(c);
        c.recordDeposit{ value: 0 }(T1, eve, 40e18); // bucket 4; vault -> 93.68e18 (tier 4, the top)
    }

    /// @dev Redeem `amount` from `holder` with a zero fee: thins the holder's tier without distributing.
    function _thin(DynamicFeeFlatPriceCurve c, address holder, uint256 amount) internal {
        c.recordRedeem{ value: 0 }(T1, holder, amount);
    }

    /// @dev Seat a FUNDED holder in tier 0 and a DUST holder in tier 1, with the vault left in tier 2.
    ///      Result: tier 0 = alice 10e18 (full), tier 1 = bob 1 wei (dust), tier 2 = carol 14.4e18.
    function _seatDustTierOneAboveFundedTierZero(DynamicFeeFlatPriceCurve c) internal {
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18   (tier 2)
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // bucket 2; vault -> 36.4e18 (tier 3)
        c.recordRedeem{ value: 0 }(T1, bob, 12e18 - 1); // tier 1 -> 1 wei; vault -> 24.4e18 (tier 2)
    }

    /// @dev The floor is a {DynamicFeeConfig} field, so it is changed the same way every other curve
    ///      parameter is: read the live config, modify one field, write it back. There is deliberately no
    ///      dedicated setter — a second writer for a field {setConfig} also overwrites would invite the
    ///      two to disagree.
    function _setFloor(DynamicFeeFlatPriceCurve c, uint256 floorBps) internal {
        DynamicFeeConfig memory config = c.getConfig();
        config.minEligibleTierStakeBps = floorBps;
        vm.prank(c.owner());
        c.setConfig(config);
    }

    function _floor(DynamicFeeFlatPriceCurve c) internal view returns (uint256) {
        return c.getConfig().minEligibleTierStakeBps;
    }

    /* =================================================== */
    /*             THE DEFAULT IS INERT ON FULL TIERS      */
    /* =================================================== */

    /// @dev With every tier exactly full the cap pays each slice whole and a zero floor admits every
    ///      tier, so the shipped default reproduces the plain kernel split byte for byte. The reference
    ///      split is the nearest-first window: 50 / 33.3 / 16.7 % over d = 1/2/3, with d = 4 a hard
    ///      zero at the kernel edge.
    function test_defaultFloorIsZero_andFullTiersReproduceTheUnfilteredSplit() external {
        assertEq(_floor(curve), 0, "the floor must ship disabled");

        _seatFourTiers(curve);
        curve.recordDeposit{ value: 6e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(curve.claimable(dave, T1), 3e18, 1e4, "d=1 earns 50%");
        assertApproxEqAbs(curve.claimable(carol, T1), 2e18, 1e4, "d=2 earns 33.3%");
        assertApproxEqAbs(curve.claimable(bob, T1), 1e18, 1e4, "d=3 earns 16.7%");
        assertEq(curve.claimable(alice, T1), 0, "d=4 == sigma earns nothing (hard zero)");
    }

    /// @dev A ladder with holes: one large deposit jumps the vault two bands, so the kernel window spans
    ///      tiers that hold nothing. The distribution must skip them and pay the one occupied tier in
    ///      full rather than crediting a weight against a zero stake. That tier holds far more than
    ///      its width, so the cap pays it whole.
    function test_zeroFloor_distributesOverAGappedLadderWithoutCreditingEmptyTiers() external {
        // A single large deposit jumps the vault from tier 0 to tier 3, leaving tiers 1 and 2 unoccupied.
        curve.recordDeposit{ value: 0 }(T1, alice, 36.4e18); // bucket 0; vault -> 36.4e18 (tier 3)

        curve.recordDeposit{ value: 4e18 }(T1, bob, 1e18);

        assertApproxEqAbs(curve.claimable(alice, T1), 4e18, 1e4, "the sole occupied prior tier takes the whole pool");
        assertEq(curve.protocolAccrued(), 0, "an empty tier must not absorb or leak any part of the pool");
    }

    /* =================================================== */
    /*              THE CAP ON A PARTLY FILLED TIER         */
    /* =================================================== */

    /// @dev The schedule ceiling, at a zero floor. A tier holding a quarter of its width earns a quarter
    ///      of its schedule slice; the full tiers earn exactly theirs, not more. Tier 1 is thinned to 3
    ///      of 12 TRUST, so its 1e18 kernel slice pays 0.25e18, and since no prior tier holds more than
    ///      its width there is nobody to absorb the 0.75e18 shortfall at the schedule rate: it accrues.
    ///      Tier 0 sits at d = 4 = sigma, a hard zero, and stays at zero.
    function test_partlyFilledTier_keepsItsFillShare_andTheShortfallAccrues() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18); // tier 1: 12e18 -> 3e18, a quarter of its width

        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);

        assertApproxEqAbs(curve.claimable(dave, T1), 3e18, 1e4, "d=1 earns exactly its 50%");
        assertApproxEqAbs(curve.claimable(carol, T1), 2e18, 1e4, "d=2 earns its 33.3%");
        assertApproxEqAbs(
            curve.claimable(bob, T1), 0.25e18, 1e4, "the quarter-filled tier keeps a quarter of its slice"
        );
        assertEq(curve.claimable(alice, T1), 0, "the window does not slide: tier 0 is still beyond sigma");
        assertEq(curve.claimable(eve, T1), 0, "the topper sits at the source tier and is not a recipient");
        assertApproxEqAbs(
            curve.protocolAccrued(), 0.75e18, 1e4, "the thin tier's shortfall has no over-full tier to absorb it"
        );
    }

    /// @dev Per-share income is what the cap bounds. The quarter-filled cohort above earns exactly the
    ///      same per unit of stake as it would if the band were full: `slice / width` either way.
    function test_partlyFilledTier_earnsTheScheduleRatePerShare() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18);
        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);
        uint256 thinPerShare = (curve.claimable(bob, T1) * 1e18) / 3e18;

        DynamicFeeFlatPriceCurve full = _deploy(_defaultConfig());
        _seatFourTiersToppedAt4(full);
        full.recordDeposit{ value: 6e18 }(T1, frank, 1e18);
        uint256 fullPerShare = (full.claimable(bob, T1) * 1e18) / 12e18;

        assertApproxEqAbs(thinPerShare, fullPerShare, 1e4, "per-share income does not depend on how full the tier is");
    }

    /* =================================================== */
    /*             EXCLUSION FROM THE SPREAD               */
    /* =================================================== */

    /// @dev The ceiling contract for an excluded tier. A sub-floor tier leaves the effective sum, but
    ///      the schedule normalizer still counts it, so the qualifying tiers earn exactly their
    ///      schedule shares and the excluded tier's share accrues instead of being redistributed above
    ///      schedule. The earning window does NOT slide down to pull in a further tier: tier 0 sits at
    ///      d = 4 = sigma, where the triangular kernel is a hard zero, and it must stay at zero.
    ///      Tier 1 is thinned to a quarter of its width and the floor set to half, so tier 1 drops out
    ///      while tiers 2 and 3 stay full at weights 0.75 (d=1) and 0.5 (d=2) over the schedule's 1.5:
    ///      the split stays 50 / 33.3 / 0, and the missing 16.7 accrues.
    function test_subFloorTier_leavesTheSpread_andItsShareAccrues() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18); // tier 1 at 25% of its width
        _setFloor(curve, 5000); // half a width required

        curve.recordDeposit{ value: 10e18 }(T1, frank, 1e18);

        assertApproxEqAbs(curve.claimable(dave, T1), 5e18, 1e4, "d=1 keeps exactly its 50%");
        assertApproxEqAbs(curve.claimable(carol, T1), uint256(10e18) / 3, 1e4, "d=2 keeps exactly its 33.3%");
        assertEq(curve.claimable(bob, T1), 0, "the sub-floor tier earns nothing");
        assertEq(curve.claimable(alice, T1), 0, "the window does not slide: tier 0 is still beyond sigma");

        // The surviving tiers stay in their 0.75 : 0.5 kernel ratio; nothing is redistributed by stake.
        assertApproxEqAbs(
            curve.claimable(dave, T1) * 2, curve.claimable(carol, T1) * 3, 1e5, "still 3:2 by kernel weight"
        );
        assertApproxEqAbs(curve.protocolAccrued(), uint256(10e18) / 6, 1e4, "the excluded tier's share accrues");
    }

    /// @dev The fallback reads the same `stakes` array the spread was built from, so it must inherit
    ///      the same filter. If it did not, a thin tier dropped from the weighted spread would be handed
    ///      a share of the pool by the fallback — strictly worse than having no floor. Here
    ///      `alpha = 3750` puts the fulcrum at dStar = 2.5 and `sigma = 1e18 + 1` gives weight only to
    ///      the two tiers half a step away (tiers 2 and 1). Both are thinned under a 50% floor, so every
    ///      distribution takes the fill-only fallback, which splits the pool across the qualifying
    ///      tiers at the equal-share ceiling: full tiers 3 and 0 each earn a quarter of it (one share
    ///      in four prior tiers), and the two excluded tiers' shares accrue.
    function test_subFloorTier_isAlsoExcludedFromTheFillOnlyFallback() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositFulcrumAlphaBps = 3750; // dStar = (1 - 0.375) * 4 = 2.5 tiers from the source
        config.depositKernelSpread = 1e18 + 1; // tightest legal window
        DynamicFeeFlatPriceCurve c = _deploy(config);
        _seatFourTiersToppedAt4(c);
        _thin(c, bob, 9e18); // tier 1 at 25%
        _thin(c, carol, 11.4e18); // tier 2 at ~21%
        _setFloor(c, 5000);

        c.recordDeposit{ value: 5e18 }(T1, frank, 1e18);

        assertEq(c.claimable(carol, T1), 0, "the nearest tier is sub-floor and must not take any of the pool");
        assertEq(c.claimable(bob, T1), 0, "nor the other sub-floor tier");
        assertApproxEqAbs(c.claimable(dave, T1), 1.25e18, 1e4, "a full qualifying tier earns one share in four");
        assertApproxEqAbs(c.claimable(alice, T1), 1.25e18, 1e4, "as does the other full qualifying tier");
        assertApproxEqAbs(c.protocolAccrued(), 2.5e18, 1e4, "the two excluded tiers' shares accrue");
    }

    /* =================================================== */
    /*                THE ORIGINAL DUST SEATS              */
    /* =================================================== */

    /// @dev First reported pathology: a one-wei seat out-earning a funded position, because occupancy was
    ///      a boolean and the nearer tier carries the larger kernel weight. Unfiltered, tier 1 (1 wei,
    ///      d = 1, w = 0.75) used to take 60% and tier 0 (10 TRUST, d = 2, w = 0.5) 40%.
    ///      Occupancy-weighted spreading closes it at any floor: the dust seat's effective weight is
    ///      one wei over a 12 TRUST width, which floors to nothing. The funded tier below earns exactly
    ///      its schedule share, 40% of the pool; the 60% the schedule reserved for tier 1 has no stake
    ///      there to earn it and accrues, rather than being handed to the funded tier above schedule.
    function test_dustSeat_earnsNothingAtAnyFloor_andTheFundedTierEarnsItsScheduleShare() external {
        _seatDustTierOneAboveFundedTierZero(curve);
        curve.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertEq(curve.claimable(bob, T1), 0, "at a zero floor the weighting alone keeps the one-wei seat from earning");
        assertApproxEqAbs(curve.claimable(alice, T1), 2e18, 1e4, "the funded tier earns its 40% schedule share");
        assertApproxEqAbs(curve.protocolAccrued(), 3e18, 1e4, "the dust tier's 60% has no stake to earn it");

        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        _seatDustTierOneAboveFundedTierZero(c);
        _setFloor(c, 5000);

        c.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertEq(c.claimable(bob, T1), 0, "with the floor live the seat is excluded outright");
        assertApproxEqAbs(c.claimable(alice, T1), 2e18, 1e4, "and the funded tier still earns its schedule share");
        assertApproxEqAbs(c.protocolAccrued(), 3e18, 1e4, "and the excluded tier's share still accrues");
    }

    /// @dev Second reported pathology: a one-wei co-occupant of the exiting tier capturing the whole
    ///      redeem fee through the diamond-hands slice. The cap scales that slice by the cohort's fill,
    ///      which for one wei is nothing, and the unpaid slice rejoins the fulcrum pool, where the full
    ///      tier below takes it. Note the cohort denominator is exactly the OTHER holders' stake and does
    ///      not depend on the redemption size — an exiter cannot size a partial redeem to steer this.
    function test_dustResidualCohort_doesNotTakeTheDiamondSlice() external {
        // alice funds tier 0; bob and carol both land in tier 1, carol with one wei.
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, bob, 1e18); // bucket 1; vault -> 11e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, carol, 1); // bucket 1; vault -> 11e18 (tier 1)

        curve.recordRedeem{ value: 2e18 }(T1, bob, 1e18);

        assertEq(curve.claimable(carol, T1), 0, "the dust cohort earns nothing from the exit fee");
        assertEq(curve.claimable(bob, T1), 0, "the exiter never earns from their own fee");
        assertApproxEqAbs(curve.claimable(alice, T1), 2e18, 1e4, "the slice rejoins the pool and reaches the full tier");
        assertEq(curve.protocolAccrued(), 0, "nothing accrues to the protocol while a full prior tier exists");

        // With the floor live the cohort is excluded outright; the destination is the same.
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 1e18);
        c.recordDeposit{ value: 0 }(T1, carol, 1);
        _setFloor(c, 5000);

        c.recordRedeem{ value: 2e18 }(T1, bob, 1e18);

        assertEq(c.claimable(carol, T1), 0, "the sub-floor cohort earns nothing");
        assertApproxEqAbs(c.claimable(alice, T1), 2e18, 1e4, "the folded slice reaches the full tier below");
        assertEq(c.protocolAccrued(), 0, "a sub-floor cohort no longer sends the slice to the protocol");
    }

    /// @dev The whale-exit reroute scans upward first and then downward. A dust tier sitting above the
    ///      exiting tier must not intercept the slice by being nearest: at a zero floor the cap pays it
    ///      nothing and the slice rejoins the pool, with the floor live the scan skips it. Either way
    ///      the funded tier below receives the fee. bob is the sole occupant of tier 1, carol holds one
    ///      wei in tier 2 (above), alice is full in tier 0 (below).
    function test_dustTierAbove_doesNotInterceptTheWhaleExitReroute() external {
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18 (tier 2)
        curve.recordDeposit{ value: 0 }(T1, carol, 1); // bucket 2; one wei above the exiting tier

        curve.recordRedeem{ value: 2e18 }(T1, bob, 12e18);

        assertEq(curve.claimable(carol, T1), 0, "at a zero floor the cap pays the dust tier nothing");
        assertApproxEqAbs(curve.claimable(alice, T1), 2e18, 1e4, "the slice reaches the funded tier below");

        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 12e18);
        c.recordDeposit{ value: 0 }(T1, carol, 1);
        _setFloor(c, 5000);

        c.recordRedeem{ value: 2e18 }(T1, bob, 12e18);

        assertEq(c.claimable(carol, T1), 0, "with the floor live the scan skips the dust tier");
        assertApproxEqAbs(c.claimable(alice, T1), 2e18, 1e4, "and continues to the funded tier below");
    }

    /// @dev A sub-floor residual cohort is treated like an absent one: the slice reroutes to the nearest
    ///      eligible tier above first, capped at that tier's fill, then continues below. Floor 5% of
    ///      width: tier 1 needs 0.6 TRUST, so carol's 0.5 is sub-floor and earns nothing; tier 2 needs
    ///      0.72, so dave's 1 TRUST qualifies and takes its fill of the slice, one part in 14.4; the
    ///      rest continues to alice's full tier 0. Nothing accrues while a holder can take it.
    function test_subFloorResidualCohort_reroutesLikeAnAbsentOne() external {
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        c.recordDeposit{ value: 0 }(T1, carol, 0.5e18); // bucket 1; the honest sub-floor cohort
        c.recordDeposit{ value: 0 }(T1, bob, 11.5e18); // bucket 1; the whale, vault -> 22e18 (tier 2)
        c.recordDeposit{ value: 0 }(T1, dave, 1e18); // bucket 2; the would-be interceptor, above the floor
        _setFloor(c, 500);

        // The whale exits tier 1, leaving a cohort that exists (0.5e18) but does not clear the floor.
        c.recordRedeem{ value: 2e18 }(T1, bob, 11.5e18);

        uint256 daveFill = (uint256(2e18) * 1e18) / c.tierWidthAt(2);
        assertApproxEqAbs(c.claimable(dave, T1), daveFill, 1e4, "the tier above takes its fill of the slice, no more");
        assertEq(c.claimable(carol, T1), 0, "the sub-floor cohort does not earn");
        assertApproxEqAbs(c.claimable(alice, T1), 2e18 - daveFill, 1e4, "the rest continues to the full tier below");
        assertEq(c.protocolAccrued(), 0, "nothing accrues to the protocol while a holder can take it");
    }

    /// @dev A seat parked exactly at the floor in a zero-weight tier cannot take any of an orphaned
    ///      slice. The slice has no eligible cohort at its own tier, so it reroutes to the nearest
    ///      eligible tier above first: the topper's full tier 4, which takes all of it. Nothing reaches
    ///      the spread, so the seat, which sits at d = 4 = sigma and would only be reachable through
    ///      the fill-only fallback, sees none of it. The ladder: attacker alone in tier 0 at exactly
    ///      the floor, tiers 1 and 2 emptied via bridge accounts, a sub-floor residual plus the victim
    ///      in tier 3, vault held in tier 4 by a topper.
    function test_seatAtTheFloorInAZeroWeightTier_earnsNothingOfTheOrphanedSlice() external {
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        address bridgeOne = makeAddr("bridge-one");
        address bridgeTwo = makeAddr("bridge-two");
        address bridgeThree = makeAddr("bridge-three");
        address topper = makeAddr("topper");

        c.recordDeposit{ value: 0 }(T1, alice, 1e18); // attacker; bucket 0; vault -> 1e18    (tier 0)
        c.recordDeposit{ value: 0 }(T1, bridgeOne, 9.5e18); // bucket 0; vault -> 10.5e18 (tier 1)
        c.recordDeposit{ value: 0 }(T1, bridgeTwo, 12e18); // bucket 1; vault -> 22.5e18 (tier 2)
        c.recordDeposit{ value: 0 }(T1, bridgeThree, 14.4e18); // bucket 2; vault -> 36.9e18 (tier 3)
        c.recordDeposit{ value: 0 }(T1, carol, 0.5e18); // sub-floor residual; bucket 3
        c.recordDeposit{ value: 0 }(T1, bob, 16e18); // victim; stays inside tier 3; vault -> 53.4e18
        c.recordDeposit{ value: 0 }(T1, topper, 37e18); // bucket 4; vault -> 90.4e18 (tier 4)
        assertEq(c.userTopTier(T1, bob), 3, "the victim must be a tier-3 holder");

        // Withdraw the bridges so tiers 1 and 2 are empty and tier 0 holds exactly the attacker's seat.
        c.recordRedeem{ value: 0 }(T1, bridgeOne, 9.5e18);
        c.recordRedeem{ value: 0 }(T1, bridgeTwo, 12e18);
        c.recordRedeem{ value: 0 }(T1, bridgeThree, 14.4e18);
        assertEq(c.tierStake(T1, 0), 1e18, "tier 0 must hold exactly the attacker's seat");
        assertEq(c.tierStake(T1, 1), 0, "tier 1 must be empty");
        assertEq(c.tierStake(T1, 2), 0, "tier 2 must be empty");
        assertEq(c.tierOf(c.vaultStake(T1)), 4, "source tier must be 4 so tier 0 is exactly sigma away");

        _setFloor(c, 1000); // a tenth of each width: tier 0 needs 1e18, tier 3 needs 1.728e18
        c.recordRedeem{ value: 4e18 }(T1, bob, 16e18);

        assertEq(c.claimable(alice, T1), 0, "the seat at the floor earns nothing of a slice its tier did not earn");
        assertEq(c.claimable(carol, T1), 0, "the sub-floor residual does not earn either");
        assertApproxEqAbs(c.claimable(topper, T1), 4e18, 1e4, "the full tier above the exiter takes the whole slice");
        assertEq(c.protocolAccrued(), 0, "nothing accrues while a holder above can take it at the schedule rate");
    }

    /// @dev The deposit-side prior-tier spike routes a configurable lump to the nearest eligible prior
    ///      tier through its own downward scan — a separate gate from the fulcrum spread. The lump is
    ///      capped like every credit, so a dust tier that is nearest absorbs next to nothing of it and
    ///      the rest cascades to the full tier below. With the floor live the scan skips the dust tier
    ///      and pays the full tier directly. The spike is dormant at the
    ///      shipped `depositToPriorTierBps == 0`, so this configures it on.
    function test_dustTier_doesNotAbsorbTheDepositPriorTierSpike() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = uint256(BPS); // route the whole fee as the spike lump
        DynamicFeeFlatPriceCurve c = _deploy(config);
        _seatDustTierOneAboveFundedTierZero(c);

        c.recordDeposit{ value: 5e18 }(T1, eve, 1e18);
        assertEq(c.claimable(bob, T1), 0, "the dust tier absorbs nothing of the spike");
        assertApproxEqAbs(c.claimable(alice, T1), 5e18, 1e4, "the lump folds into the pool and reaches the full tier");

        DynamicFeeFlatPriceCurve filtered = _deploy(config);
        _seatDustTierOneAboveFundedTierZero(filtered);
        _setFloor(filtered, 5000);

        filtered.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertEq(filtered.claimable(bob, T1), 0, "the dust tier earns nothing from the spike");
        assertApproxEqAbs(filtered.claimable(alice, T1), 5e18, 1e4, "the spike falls through to the qualifying tier");
    }

    /* =================================================== */
    /*                  NOTHING IS FORFEITED               */
    /* =================================================== */

    /// @dev When the floor disqualifies every prior tier the pool must still land somewhere. The
    ///      terminal sink is the protocol bucket, exactly as it is when no tier holds stake at all.
    ///      Tier 0 is thinned to a fifth of its width under a 30% floor, with the vault left in tier 1
    ///      so tier 0 is the only prior tier.
    function test_noQualifyingTierAnywhere_routesTheWholePoolToTheProtocol() external {
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18 (tier 2)
        _thin(curve, alice, 8e18); // tier 0 at 20%; vault -> 14e18 (tier 1)
        _setFloor(curve, 3000);

        curve.recordDeposit{ value: 4e18 }(T1, carol, 1e18);

        assertEq(curve.claimable(alice, T1), 0, "no tier qualifies");
        assertEq(curve.protocolAccrued(), 4e18, "the pool accrues to the protocol rather than being forfeited");
    }

    /// @dev Without a floor the same thin sole prior tier keeps its fill share and the rest, having no
    ///      full prior tier to flow to, is undistributable. The protocol bucket is the sink of last
    ///      resort, never a destination the cap prefers.
    function test_thinSolePriorTier_keepsItsFillShare_andTheRestIsUndistributable() external {
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18);
        curve.recordDeposit{ value: 0 }(T1, bob, 12e18);
        _thin(curve, alice, 8e18); // tier 0 at 20%; vault -> 14e18 (tier 1)

        curve.recordDeposit{ value: 4e18 }(T1, carol, 1e18);

        assertApproxEqAbs(curve.claimable(alice, T1), 0.8e18, 1e4, "a fifth-filled tier keeps a fifth of the pool");
        assertApproxEqAbs(curve.protocolAccrued(), 3.2e18, 1e4, "the rest has no full prior tier to reach");
    }

    /// @dev The last holder exiting leaves the tier with no residual cohort at all, so `denom` is zero
    ///      and the diamond slice must fall through to the protocol. This pins the `> 0` conjunct of the
    ///      eligibility predicate: {recordRedeem} divides by `denom` with no sentinel behind it, so a
    ///      bare `stake >= floor` would make the zero denominator "eligible" at the shipped zero floor
    ///      and revert this ordinary exit on a division by zero.
    function test_zeroFloor_lastHolderExit_routesToProtocolRatherThanDividingByZero() external {
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18);

        curve.recordRedeem{ value: 1e18 }(T1, alice, 10e18);

        assertEq(curve.claimable(alice, T1), 0, "the sole exiter earns nothing from their own fee");
        assertEq(curve.protocolAccrued(), 1e18, "the whole exit fee accrues to the protocol");
    }

    /// @dev Conservation in BOTH directions, on both fee paths, across the whole floor range. The floor
    ///      and the cap change WHO is owed, never how much.
    ///      The upper bound is solvency. The lower bound is the one that carries weight here: an
    ///      `owed <= balance` assertion on its own would still pass if a gate quietly made an
    ///      arbitrary share of every fee unattributable, which is precisely the failure mode a recipient
    ///      filter could introduce. So this also pins how much custody may go unaccounted.
    ///      The permitted gap is the pre-existing per-share truncation dust, once per credited tier per
    ///      distribution, comfortably under 1000 wei at these stakes.
    function testFuzz_custodyIsFullyAttributableUpToTruncationDust(uint256 floor, uint256 depositFee, uint256 exitFee)
        external
    {
        floor = bound(floor, 0, BPS);
        depositFee = bound(depositFee, 0, 50e18);
        exitFee = bound(exitFee, 0, 50e18);

        // `eve` is seated as a SMALL co-occupant of the exiting tier, so `dave`'s exit leaves a residual
        // cohort of 0.4e18 and the diamond slice runs through every branch as the floor sweeps.
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        curve.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18   (tier 2)
        curve.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // bucket 2; vault -> 36.4e18 (tier 3)
        curve.recordDeposit{ value: 0 }(T1, eve, 0.4e18); // bucket 3; the residual cohort
        curve.recordDeposit{ value: 0 }(T1, dave, 17e18); // bucket 3; vault -> 53.8e18 (tier 4)
        _setFloor(curve, floor);

        curve.recordDeposit{ value: depositFee }(T1, frank, 20.736e18);
        curve.recordRedeem{ value: exitFee }(T1, dave, 17e18);

        uint256 owed = curve.claimable(alice, T1) + curve.claimable(bob, T1) + curve.claimable(carol, T1)
            + curve.claimable(dave, T1) + curve.claimable(eve, T1) + curve.claimable(frank, T1)
            + curve.protocolAccrued();
        uint256 held = address(curve).balance;

        assertLe(owed, held, "obligations must never exceed custody");
        assertLe(held - owed, MAX_TRUNCATION_DUST_WEI, "custody must be attributable up to truncation dust");
    }

    /* =================================================== */
    /*              EARNINGS SURVIVE A RAISE               */
    /* =================================================== */

    /// @dev The floor gates who receives FUTURE credit; it must never gate who may surface credit already
    ///      earned. The accumulator is monotonic, so raising the floor above a tier's fill freezes that
    ///      tier's future income but must leave every wei it already accrued claimable in full. Adding
    ///      the predicate to the settle or read path would strand these funds permanently.
    function test_raisingTheFloor_doesNotStrandAlreadyAccruedEarnings() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18); // tier 1 at 25%
        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);

        uint256 pendingBefore = curve.pendingFor(bob, T1);
        assertGt(pendingBefore, 0, "the fixture must leave the tier with real pending");

        _setFloor(curve, BPS); // a full width required; bob's tier is far below it

        assertEq(curve.pendingFor(bob, T1), pendingBefore, "a floor raise must not reprice accrued earnings");
        assertEq(curve.claimable(bob, T1), pendingBefore, "the claimable view must not consult the floor");

        bytes32[] memory terms = new bytes32[](1);
        terms[0] = T1;
        vm.prank(bob);
        uint256 paid = curve.claim(terms);

        assertEq(paid, pendingBefore, "claim must pay the accrued amount in full");
        assertEq(bob.balance, pendingBefore, "the funds actually reach the holder");
    }

    /* =================================================== */
    /*                     CONFIGURATION                   */
    /* =================================================== */

    /// @dev A raise must be monitorable on its own. {ConfigUpdated} carries only the ladder shape and no
    ///      field emits its previous value, so the floor — the one parameter that silently changes WHO
    ///      earns — gets a dedicated before/after signal out of {setConfig}.
    function test_setConfig_storesTheFloorAndEmitsBothSides() external {
        _setFloor(curve, 500);
        assertEq(_floor(curve), 500, "the floor is stored");

        DynamicFeeConfig memory config = curve.getConfig();
        config.minEligibleTierStakeBps = 900;

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.MinEligibleTierStakeUpdated(500, 900);
        vm.prank(curve.owner());
        curve.setConfig(config);

        assertEq(_floor(curve), 900, "the floor is updated");
    }

    /// @dev A retune that leaves the floor alone must not emit the signal, or a monitor watching for a
    ///      raise drowns in noise from unrelated fee changes.
    function test_setConfig_doesNotEmitTheFloorSignalWhenItIsUnchanged() external {
        _setFloor(curve, 500);

        DynamicFeeConfig memory config = curve.getConfig();
        config.depositBaseBps = 250; // an unrelated retune

        vm.recordLogs();
        vm.prank(curve.owner());
        curve.setConfig(config);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; ++i) {
            assertTrue(
                logs[i].topics[0] != DynamicFeeFlatPriceCurve.MinEligibleTierStakeUpdated.selector,
                "an unchanged floor must stay silent"
            );
        }
    }

    function test_setConfig_revertsForNonOwner() external {
        DynamicFeeConfig memory config = curve.getConfig();
        config.minEligibleTierStakeBps = 1000;

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        curve.setConfig(config);
    }

    /// @dev The floor is a fraction of each tier's width, so a full band is the natural ceiling: above
    ///      it no tier could qualify on its own width and the owner could route the entire fee stream —
    ///      deposit AND redeem — into the sweepable protocol bucket in a single transaction.
    function test_setConfig_revertsWhenTheFloorExceedsAFullWidth() external {
        address curveOwner = curve.owner();

        DynamicFeeConfig memory config = curve.getConfig();
        config.minEligibleTierStakeBps = BPS + 1;

        vm.prank(curveOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake.selector
            )
        );
        curve.setConfig(config);

        // A full width itself remains settable.
        _setFloor(curve, BPS);
        assertEq(_floor(curve), BPS, "the ceiling is an inclusive bound");
    }

    /// @dev The gate reads the floor live, so a change applies from the next distribution with no
    ///      snapshot, no migration and no effect on what has already been distributed.
    function test_floorChange_appliesFromTheNextDistributionOnly() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18); // tier 1 at 25%

        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);
        uint256 earnedUnderTheOldFloor = curve.claimable(bob, T1);
        assertGt(earnedUnderTheOldFloor, 0, "the first distribution pays the tier its fill share");

        _setFloor(curve, 5000); // bob's tier is now sub-floor
        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);

        assertEq(curve.claimable(bob, T1), earnedUnderTheOldFloor, "the earlier distribution is untouched");
    }

    /// @dev Lowering the floor back to zero re-admits a thin tier, but only to its fill share: the cap
    ///      is not a floor setting and cannot be switched off.
    function test_zeroFloor_readmitsAThinTier_butOnlyToItsFillShare() external {
        _seatFourTiersToppedAt4(curve);
        _thin(curve, bob, 9e18);
        _setFloor(curve, 5000);
        _setFloor(curve, 0);

        curve.recordDeposit{ value: 6e18 }(T1, frank, 1e18);

        assertApproxEqAbs(curve.claimable(bob, T1), 0.25e18, 1e4, "re-admitted, the tier keeps a quarter of its slice");
        assertApproxEqAbs(curve.claimable(dave, T1), 3e18, 1e4, "and the full tier keeps exactly its schedule share");
        assertApproxEqAbs(curve.protocolAccrued(), 0.75e18, 1e4, "the thin tier's shortfall accrues");
    }
}
