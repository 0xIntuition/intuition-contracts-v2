// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, Vm } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveMinEligibleTierStakeTest
/// @notice Covers `minEligibleTierStake`, the floor a tier must hold to receive redistributed fees.
/// @dev    Driven in ISOLATION — the test contract stands in as the authorized MultiVault and calls the
///         record hooks directly, forwarding the fee as native value. That is what makes exact per-tier
///         amounts assertable: every suite driven through the real MultiVault can only assert bounds,
///         because MultiVault's own entry/exit/protocol fees move the numbers. The renormalization case
///         below needs exact numbers, so it needs this harness.
///
///         The ladder used throughout: `width0 = 10 TRUST`, 5 tiers, `g = 0.2`. Widths compound 1.2x —
///         10, 12, 14.4, 17.28, 20.736 — so the cumulative edges are 10, 22, 36.4, 53.68, 74.416 (x1e18).
///         With `fulcrumAlpha = BPS` the fulcrum sits on the source (`dStar = 0`) and `sigma = 4e18`
///         gives the nearest-first triangular window: weights 0.75 / 0.5 / 0.25 / 0 at distances
///         d = 1 / 2 / 3 / 4.
///
///         "Diamond slice" and "diamond-hands slice" below both mean the exiting-tier slice: the
///         portion of a withdrawal fee that goes to the exiting tier's other holders.
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
    ///      tier per distribution. Generous against the real bound (~210 wei at these stakes) and still
    ///      nine orders of magnitude below the fees moved.
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
            growthGBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            fulcrumAlpha: 10_000,
            kernelSpread: 4e18,
            withdrawalBaseBps: 200,
            withdrawalGrowthBps: 50,
            withdrawalCapBps: 1000,
            withdrawalToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStake: 0
        });
    }

    /// @dev Populate tiers 0..3 with one holder each, leaving the vault in tier 4. Stakes are exactly the
    ///      tier widths: 10 / 12 / 14.4 / 17.28 TRUST. A holder's bucket is the vault's tier at the
    ///      moment they deposit, so walking the vault up the ladder one band at a time seats them in
    ///      ascending tiers.
    function _seatFourTiers(DynamicFeeFlatPriceCurve c) internal {
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18   (tier 2)
        c.recordDeposit{ value: 0 }(T1, carol, 14.4e18); // bucket 2; vault -> 36.4e18 (tier 3)
        c.recordDeposit{ value: 0 }(T1, dave, 17.28e18); // bucket 3; vault -> 53.68e18 (tier 4)
    }

    /// @dev Seat a FUNDED holder in tier 0 and a DUST holder in tier 1, with the vault left in tier 2.
    ///      A dust tier cannot be built by deposit alone — a fresh depositor is bucketed into the tier
    ///      the vault currently occupies, so whoever pushes the vault past a band also lands in it. The
    ///      dust is therefore created by redeeming a seated position down to one wei, with a zero fee so
    ///      the teardown distributes nothing of its own.
    ///      Result: tier 0 = alice 10e18 (funded), tier 1 = bob 1 wei (dust), tier 2 = carol 14.4e18.
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
    function _setFloor(DynamicFeeFlatPriceCurve c, uint256 floor) internal {
        DynamicFeeConfig memory config = c.getConfig();
        config.minEligibleTierStake = floor;
        vm.prank(c.owner());
        c.setConfig(config);
    }

    function _floor(DynamicFeeFlatPriceCurve c) internal view returns (uint256) {
        return c.getConfig().minEligibleTierStake;
    }

    /* =================================================== */
    /*                  THE DEFAULT IS INERT               */
    /* =================================================== */

    /// @dev The shipped default must reproduce the plain occupancy behaviour byte for byte, which is what
    ///      makes it safe to land this mechanism switched off. The reference split is the nearest-first
    ///      window: 50 / 33.3 / 16.7 % over d = 1/2/3, with d = 4 a hard zero at the kernel edge.
    function test_defaultFloorIsZero_andReproducesTheUnfilteredSplit() external {
        assertEq(_floor(curve), 0, "the floor must ship disabled");

        _seatFourTiers(curve);
        curve.recordDeposit{ value: 6e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(curve.claimable(dave, T1), 3e18, 1e4, "d=1 earns 50%");
        assertApproxEqAbs(curve.claimable(carol, T1), 2e18, 1e4, "d=2 earns 33.3%");
        assertApproxEqAbs(curve.claimable(bob, T1), 1e18, 1e4, "d=3 earns 16.7%");
        assertEq(curve.claimable(alice, T1), 0, "d=4 == sigma earns nothing (hard zero)");
    }

    /// @dev A ladder with holes: one large deposit jumps the vault two bands, so the kernel window spans
    ///      tiers that hold nothing. The distribution must skip them and pay the one funded tier in full
    ///      rather than crediting a weight against a zero stake.
    ///      Note this case does NOT pin the predicate's `> 0` conjunct — {_weighPriorTiers} re-tests
    ///      `recipientStake > 0` after zeroing, so it is immune on its own. The conjunct is pinned by
    ///      the last-holder exit below, where `denom` is divided by directly.
    function test_zeroFloor_distributesOverAGappedLadderWithoutCreditingEmptyTiers() external {
        // A single large deposit jumps the vault from tier 0 to tier 3, leaving tiers 1 and 2 unoccupied.
        curve.recordDeposit{ value: 0 }(T1, alice, 36.4e18); // bucket 0; vault -> 36.4e18 (tier 3)

        curve.recordDeposit{ value: 4e18 }(T1, bob, 1e18);

        // Within per-share truncation dust: the accumulator divides by the tier's stake, so a few wei
        // are unattributable. That is the pre-existing rounding behaviour, not an eligibility effect.
        assertApproxEqAbs(curve.claimable(alice, T1), 4e18, 1e4, "the sole occupied prior tier takes the whole pool");
        assertEq(curve.protocolAccrued(), 0, "an empty tier must not absorb or leak any part of the pool");
    }

    /* =================================================== */
    /*             EXCLUSION FROM THE SPREAD               */
    /* =================================================== */

    /// @dev The renormalization contract. A sub-floor tier leaves `sumWeights`, so the pool is split over
    ///      the tiers that ALREADY qualified, in proportion to their existing kernel weights. The earning
    ///      window does NOT slide down to pull in a further tier: tier 0 sits at d = 4 = sigma, where the
    ///      triangular kernel is a hard zero, and it must stay at zero.
    ///      Ladder stakes are 10 / 12 / 14.4 / 17.28; a floor of 13e18 drops tier 1 (12e18) and keeps
    ///      tiers 2 and 3. Weights 0.75 (d=1) and 0.5 (d=2) then normalize over 1.25 instead of 1.5,
    ///      moving the split from 50 / 33.3 / 16.7 to exactly 60 / 40 / 0.
    function test_subFloorTier_leavesTheSpread_andItsShareRenormalizesOntoTheQualifyingTiers() external {
        _seatFourTiers(curve);
        _setFloor(curve, 13e18);

        curve.recordDeposit{ value: 10e18 }(T1, eve, 20.736e18);

        assertApproxEqAbs(curve.claimable(dave, T1), 6e18, 1e4, "d=1 renormalizes from 50% to 60%");
        assertApproxEqAbs(curve.claimable(carol, T1), 4e18, 1e4, "d=2 renormalizes from 33.3% to 40%");
        assertEq(curve.claimable(bob, T1), 0, "the sub-floor tier earns nothing");
        assertEq(curve.claimable(alice, T1), 0, "the window does not slide: tier 0 is still beyond sigma");

        // The absorbed share is split 0.75 : 0.5, i.e. in the surviving tiers' existing weight ratio —
        // not evenly, and not by stake.
        assertApproxEqAbs(
            curve.claimable(dave, T1) * 2, curve.claimable(carol, T1) * 3, 1e5, "absorbed 3:2 by kernel weight"
        );
        assertLe(curve.protocolAccrued(), 1e4, "the excluded tier's share is redistributed, not leaked");
    }

    /// @dev The degenerate branch reads the same `stakes` array the spread was built from, so it must
    ///      inherit the same filter. If it does not, a dust tier is dropped from the proportional spread
    ///      and then handed the ENTIRE pool by the fallback — strictly worse than having no floor.
    ///      Here `alpha = 3750` puts the fulcrum at dStar = 2.5 and `sigma = 0.4` zeroes every weight, so
    ///      every distribution takes the fallback. The nearest-first scan would pick tier 2 (dist 0.5);
    ///      a floor of 15e18 makes tier 2 (14.4e18) ineligible, so the award must move to tier 3, the
    ///      nearest tier that actually qualifies.
    function test_subFloorTier_isAlsoExcludedFromTheDegenerateWholePoolFallback() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.fulcrumAlpha = 3750; // dStar = (1 - 0.375) * 4 = 2.5 tiers from the source
        config.kernelSpread = 1e18 + 1; // tightest legal window; only dave clears the floor, and he is out of it
        DynamicFeeFlatPriceCurve c = _deploy(config);
        _seatFourTiers(c);
        _setFloor(c, 15e18);

        c.recordDeposit{ value: 5e18 }(T1, eve, 20.736e18);

        assertEq(c.claimable(carol, T1), 0, "the nearest tier is sub-floor and must not take the pool");
        assertApproxEqAbs(c.claimable(dave, T1), 5e18, 1e4, "the award moves to the nearest QUALIFYING tier");
        assertEq(c.claimable(bob, T1), 0, "no other tier earns");
        assertEq(c.claimable(alice, T1), 0, "no other tier earns");
    }

    /* =================================================== */
    /*                THE ORIGINAL DUST SEATS              */
    /* =================================================== */

    /// @dev First reported pathology: a one-wei seat out-earning a funded position, because occupancy was
    ///      a boolean and the nearer tier carries the larger kernel weight. Unfiltered, tier 1 (1 wei,
    ///      d = 1, w = 0.75) takes 60% and tier 0 (10 TRUST, d = 2, w = 0.5) takes 40%.
    function test_dustSeat_outEarnsAFundedPositionWithoutTheFloor_andEarnsNothingWithIt() external {
        _seatDustTierOneAboveFundedTierZero(curve);

        // Baseline: the pathology, reproduced.
        curve.recordDeposit{ value: 5e18 }(T1, eve, 1e18);
        uint256 dustEarned = curve.claimable(bob, T1);
        uint256 fundedEarned = curve.claimable(alice, T1);
        assertGt(dustEarned, fundedEarned, "unfiltered, the one-wei seat out-earns the funded position");
        assertApproxEqAbs(dustEarned, 3e18, 1e4, "the dust seat takes 60% of the pool");

        // With the floor live, the same distribution pays the funded tier in full.
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        _seatDustTierOneAboveFundedTierZero(c);
        _setFloor(c, 1e18);

        c.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertEq(c.claimable(bob, T1), 0, "the one-wei seat earns nothing once the floor is live");
        assertApproxEqAbs(c.claimable(alice, T1), 5e18, 1e4, "the funded tier takes the whole pool");
    }

    /// @dev Second reported pathology: a one-wei co-occupant of the exiting tier capturing the whole
    ///      withdrawal fee through the diamond-hands slice. `denom` is the exiting tier's residual cohort,
    ///      so a sub-floor cohort must fall through to the reroute rather than collect.
    ///      Note `denom` is exactly the OTHER holders' stake and does not depend on the withdrawal size —
    ///      an exiter cannot size a partial redeem to steer this branch.
    function test_dustResidualCohort_doesNotTakeTheDiamondSlice() external {
        // alice funds tier 0; bob and carol both land in tier 1, carol with one wei.
        curve.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, bob, 1e18); // bucket 1; vault -> 11e18 (tier 1)
        curve.recordDeposit{ value: 0 }(T1, carol, 1); // bucket 1; vault -> 11e18 (tier 1)

        // Baseline: unfiltered, the one-wei co-occupant takes the departing holder's whole exit fee.
        curve.recordRedeem{ value: 2e18 }(T1, bob, 1e18);
        assertApproxEqAbs(curve.claimable(carol, T1), 2e18, 1e4, "unfiltered, the dust cohort takes the exit fee");

        // With the floor live the slice reroutes to the nearest qualifying tier instead.
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18);
        c.recordDeposit{ value: 0 }(T1, bob, 1e18);
        c.recordDeposit{ value: 0 }(T1, carol, 1);
        _setFloor(c, 1e18);

        c.recordRedeem{ value: 2e18 }(T1, bob, 1e18);

        assertEq(c.claimable(carol, T1), 0, "the dust cohort earns nothing");
        assertEq(c.claimable(bob, T1), 0, "the exiter never earns from their own fee");
        assertEq(c.claimable(alice, T1), 0, "nor is the slice redistributed to some other tier");
        assertEq(c.protocolAccrued(), 2e18, "an orphaned sub-floor slice accrues to the protocol");
    }

    /// @dev The whale-exit reroute scans upward first and then downward. Both scans must apply the floor,
    ///      or a dust tier sitting above the exiting tier intercepts the whole slice simply by being
    ///      nearest. Here bob is the sole occupant of tier 1, carol holds one wei in tier 2 (above), and
    ///      alice is funded in tier 0 (below).
    function test_dustTierAbove_doesNotInterceptTheWhaleExitReroute() external {
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18 (tier 1)
        c.recordDeposit{ value: 0 }(T1, bob, 12e18); // bucket 1; vault -> 22e18 (tier 2)
        c.recordDeposit{ value: 0 }(T1, carol, 1); // bucket 2; one wei above the exiting tier
        _setFloor(c, 1e18);

        // bob exits tier 1 entirely, so the tier has no residual cohort and the slice must reroute.
        c.recordRedeem{ value: 2e18 }(T1, bob, 12e18);

        assertEq(c.claimable(carol, T1), 0, "the dust tier above must not intercept the reroute");
        assertApproxEqAbs(c.claimable(alice, T1), 2e18, 1e4, "the scan continues to the funded tier below");
    }

    /// @dev A sub-floor residual cohort must NOT fall into the whale-exit reroute. That reroute is
    ///      winner-takes-all and searches upward first, so inheriting it here would let anyone parking
    ///      exactly the floor one tier above capture the whole exit fee of a whale leaving the tier
    ///      below — cheap, repeatable, and worth an unbounded amount. At a zero floor the reroute
    ///      requires a completely EMPTY tier, so this interception does not exist; the floor must not
    ///      introduce it. The orphaned slice accrues to the protocol instead.
    function test_subFloorResidualCohort_doesNotFeedATierAboveViaTheWhaleExitReroute() external {
        DynamicFeeFlatPriceCurve c = _deploy(_defaultConfig());
        c.recordDeposit{ value: 0 }(T1, alice, 10e18); // bucket 0; vault -> 10e18   (tier 1)
        c.recordDeposit{ value: 0 }(T1, carol, 0.5e18); // bucket 1; the honest sub-floor cohort
        c.recordDeposit{ value: 0 }(T1, bob, 11.5e18); // bucket 1; the whale, vault -> 22e18 (tier 2)
        c.recordDeposit{ value: 0 }(T1, dave, 1e18); // bucket 2; the would-be interceptor, exactly at the floor
        _setFloor(c, 1e18);

        // The whale exits tier 1, leaving a cohort that exists (0.5e18) but does not clear the floor.
        c.recordRedeem{ value: 2e18 }(T1, bob, 11.5e18);

        assertEq(c.claimable(dave, T1), 0, "a tier-above seat must not capture the exit fee");
        assertEq(c.claimable(carol, T1), 0, "the sub-floor cohort does not earn either");
        assertEq(c.claimable(alice, T1), 0, "nor does any prior tier absorb it");
        assertEq(c.protocolAccrued(), 2e18, "an orphaned sub-floor slice accrues to the protocol");
    }

    /// @dev The sub-floor fold must not be steerable into the degenerate whole-pool fallback either.
    ///      `_weighPriorTiers` records a non-zero `stakes` entry for any ELIGIBLE tier even when the
    ///      kernel gives it zero weight, and `_awardNearestOrProtocol` reads that array while ignoring
    ///      weights. So an attacker seated at exactly the floor in a hard-zero tier (d == sigma) can, once
    ///      the floor disqualifies every positive-weight tier, be the only non-zero entry left — and take
    ///      the whole slice. At floor 0 the sub-floor residual is eligible and simply receives the fee, so
    ///      this route is introduced by the floor and must be closed by it.
    ///      The ladder: attacker alone in tier 0 at exactly the floor, tiers 1 and 2 emptied via bridge
    ///      accounts, a sub-floor residual plus the victim in tier 3, vault left in tier 4 so that tier 0
    ///      sits at d = 4 = sigma.
    ///
    ///      The victim's own stake cannot be what holds the vault in tier 4: a deposit is booked band by
    ///      band, so a position large enough to carry the vault across the tier-3 edge books most of
    ///      itself at tier 4 and exits from there instead. A separate `topper` holds the vault up while
    ///      the victim stays a genuine tier-3 holder, which is the configuration under test.
    function test_subFloorFold_cannotBeSteeredIntoTheDegenerateFallbackByAZeroWeightSeat() external {
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
        assertEq(c.userTier(T1, bob), 3, "the victim must be a tier-3 holder");

        // Withdraw the bridges so tiers 1 and 2 are empty and tier 0 holds exactly the attacker's seat.
        // The topper's stake keeps the vault in tier 4, which is what puts tier 0 at d = sigma.
        c.recordRedeem{ value: 0 }(T1, bridgeOne, 9.5e18);
        c.recordRedeem{ value: 0 }(T1, bridgeTwo, 12e18);
        c.recordRedeem{ value: 0 }(T1, bridgeThree, 14.4e18);
        assertEq(c.tierStake(T1, 0), 1e18, "tier 0 must hold exactly the attacker's seat");
        assertEq(c.tierStake(T1, 1), 0, "tier 1 must be empty");
        assertEq(c.tierStake(T1, 2), 0, "tier 2 must be empty");
        assertEq(c.tierUpperEdge(3), 53.68e18, "the vault must sit in tier 4 for tier 0 to land at d = sigma");
        assertEq(c.tierOf(c.vaultStake(T1)), 4, "source tier must be 4 so tier 0 is exactly sigma away");

        _setFloor(c, 1e18);
        c.recordRedeem{ value: 4e18 }(T1, bob, 16e18);

        assertEq(c.claimable(alice, T1), 0, "a zero-weight seat must not capture the folded slice");
        assertEq(c.claimable(carol, T1), 0, "the sub-floor residual does not earn either");
        assertEq(c.protocolAccrued(), 4e18, "an orphaned sub-floor slice accrues to the protocol");
    }

    /// @dev The deposit-side prior-tier spike routes a configurable lump to the nearest occupied prior
    ///      tier through its own downward scan — a separate gate from the fulcrum spread. Without the
    ///      floor there, a dust tier excluded from the spread would still absorb the entire lump. The
    ///      spike is dormant at the shipped `depositToPriorTierBps == 0`, so this configures it on.
    function test_dustTier_doesNotAbsorbTheDepositPriorTierSpike() external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.depositToPriorTierBps = uint256(BPS); // route the whole fee as the spike lump
        DynamicFeeFlatPriceCurve c = _deploy(config);
        _seatDustTierOneAboveFundedTierZero(c);

        // Baseline: unfiltered, the nearest prior tier is the one-wei seat and it takes the whole lump.
        c.recordDeposit{ value: 5e18 }(T1, eve, 1e18);
        assertApproxEqAbs(c.claimable(bob, T1), 5e18, 1e4, "unfiltered, the dust tier absorbs the whole spike");

        DynamicFeeFlatPriceCurve filtered = _deploy(config);
        _seatDustTierOneAboveFundedTierZero(filtered);
        _setFloor(filtered, 1e18);

        filtered.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertEq(filtered.claimable(bob, T1), 0, "the dust tier earns nothing from the spike");
        assertApproxEqAbs(filtered.claimable(alice, T1), 5e18, 1e4, "the spike falls through to the qualifying tier");
    }

    /* =================================================== */
    /*                  NOTHING IS FORFEITED               */
    /* =================================================== */

    /// @dev When the floor disqualifies every tier the pool must still land somewhere. The terminal sink
    ///      is the protocol bucket, exactly as it is when no tier holds stake at all.
    function test_noQualifyingTierAnywhere_routesTheWholePoolToTheProtocol() external {
        curve.recordDeposit{ value: 0 }(T1, alice, 36.4e18); // bucket 0; vault -> tier 3
        _setFloor(curve, 100e18); // above every tier's stake

        curve.recordDeposit{ value: 4e18 }(T1, bob, 1e18);

        assertEq(curve.claimable(alice, T1), 0, "no tier qualifies");
        assertEq(curve.protocolAccrued(), 4e18, "the pool accrues to the protocol rather than being forfeited");
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

    /// @dev Conservation in BOTH directions, on both fee paths, at a disabled and a live floor. The floor
    ///      changes WHO is owed, never how much.
    ///      The upper bound is solvency. The lower bound is the one that carries weight here: an
    ///      `owed <= balance` assertion on its own would still pass if the floor quietly made an
    ///      arbitrary share of every fee unattributable, which is precisely the failure mode a
    ///      recipient filter could introduce. So this also pins how much custody may go unaccounted.
    ///      The permitted gap is the pre-existing per-share truncation dust: `_creditByWeight` divides
    ///      the slice by the recipient tier's stake, losing under one wei per share-unit of that stake,
    ///      once per credited tier per distribution. With tier stakes here under 64e18, at most 5 tiers
    ///      and 2 distributions, that is comfortably under 1000 wei — nine orders of magnitude below the
    ///      fees being moved, and independent of the floor.
    function testFuzz_custodyIsFullyAttributableUpToTruncationDust(uint256 floor, uint256 depositFee, uint256 exitFee)
        external
    {
        floor = bound(floor, 0, curve.MAX_MIN_ELIGIBLE_TIER_STAKE());
        depositFee = bound(depositFee, 0, 50e18);
        exitFee = bound(exitFee, 0, 50e18);

        // A dedicated ladder rather than {_seatFourTiers}: `eve` is seated as a SMALL co-occupant of the
        // exiting tier, so `dave`'s exit leaves a residual cohort of 0.4e18. Sweeping the floor across
        // [0, ceiling] therefore drives the diamond slice down all three branches — cohort eligible at a
        // low floor, cohort sub-floor above 0.4e18 — instead of only the empty-cohort one. Without the
        // co-occupant `dave` is the sole holder of his tier, `denom` is always zero, and the sub-floor
        // branch is never exercised at any floor value.
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
    ///      earned. The accumulator is monotonic, so raising the floor above a tier's stake freezes that
    ///      tier's future income but must leave every wei it already accrued claimable in full. Adding
    ///      the predicate to the settle or read path would strand these funds permanently.
    function test_raisingTheFloor_doesNotStrandAlreadyAccruedEarnings() external {
        _seatFourTiers(curve);
        curve.recordDeposit{ value: 6e18 }(T1, eve, 20.736e18);

        uint256 pendingBefore = curve.pendingFor(bob, T1);
        assertGt(pendingBefore, 0, "the fixture must leave the tier with real pending");

        _setFloor(curve, curve.MAX_MIN_ELIGIBLE_TIER_STAKE()); // far above bob's tier stake

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
        _setFloor(curve, 5e18);
        assertEq(_floor(curve), 5e18, "the floor is stored");

        DynamicFeeConfig memory config = curve.getConfig();
        config.minEligibleTierStake = 9e18;

        vm.expectEmit(true, true, true, true);
        emit DynamicFeeFlatPriceCurve.MinEligibleTierStakeUpdated(5e18, 9e18);
        vm.prank(curve.owner());
        curve.setConfig(config);

        assertEq(_floor(curve), 9e18, "the floor is updated");
    }

    /// @dev A retune that leaves the floor alone must not emit the signal, or a monitor watching for a
    ///      raise drowns in noise from unrelated fee changes.
    function test_setConfig_doesNotEmitTheFloorSignalWhenItIsUnchanged() external {
        _setFloor(curve, 5e18);

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
        config.minEligibleTierStake = 1e18;

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bob));
        vm.prank(bob);
        curve.setConfig(config);
    }

    /// @dev The ceiling is what keeps the floor from being a strict expansion of owner power: without it
    ///      the owner could disqualify every tier and route the entire fee stream — deposit AND
    ///      withdrawal — into the sweepable protocol bucket in a single transaction.
    function test_setConfig_revertsWhenTheFloorExceedsTheImmutableCeiling() external {
        uint256 ceiling = curve.MAX_MIN_ELIGIBLE_TIER_STAKE();
        address curveOwner = curve.owner();

        DynamicFeeConfig memory config = curve.getConfig();
        config.minEligibleTierStake = ceiling + 1;

        vm.prank(curveOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake.selector
            )
        );
        curve.setConfig(config);

        // The ceiling itself remains settable.
        _setFloor(curve, ceiling);
        assertEq(_floor(curve), ceiling, "the ceiling is an inclusive bound");
    }

    /// @dev The gate reads the floor live, so a change applies from the next distribution with no
    ///      snapshot, no migration and no effect on what has already been distributed.
    function test_floorChange_appliesFromTheNextDistributionOnly() external {
        _seatFourTiers(curve);

        curve.recordDeposit{ value: 6e18 }(T1, eve, 20.736e18);
        uint256 earnedUnderTheOldFloor = curve.claimable(bob, T1);
        assertGt(earnedUnderTheOldFloor, 0, "the first distribution pays the tier");

        _setFloor(curve, 13e18); // bob's tier holds 12e18 and is now sub-floor
        curve.recordDeposit{ value: 6e18 }(T1, eve, 1e18);

        assertEq(curve.claimable(bob, T1), earnedUnderTheOldFloor, "the earlier distribution is untouched");
    }

    function test_zeroFloor_restoresTheUnfilteredBehaviour() external {
        _seatDustTierOneAboveFundedTierZero(curve);
        _setFloor(curve, 1e18);
        _setFloor(curve, 0);

        curve.recordDeposit{ value: 5e18 }(T1, eve, 1e18);

        assertApproxEqAbs(curve.claimable(bob, T1), 3e18, 1e4, "a zero floor restores the plain occupancy split");
    }
}
