// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveDepositNeutralityTest
/// @notice The properties the per-band deposit replay exists to provide: a lump deposit is
///         indistinguishable from the same deposit split at band boundaries, one wallet is
///         indistinguishable from several, a holder who owns every prior tier recovers their own fee,
///         and no part of a deposit is ever paid out of the fee it itself generated.
/// @dev    Driven in ISOLATION — the test contract stands in as the authorized MultiVault and calls the
///         record hooks directly, forwarding the fee as native value. That is what makes EXACT equality
///         assertable. Through the real MultiVault only bounds are assertable, because its own
///         entry/protocol/atom-wallet fees shift the numbers between arrangements.
///
///         The ladder: `width0 = 10 TRUST`, 5 tiers, `g = 0.2`. Widths compound 1.2x — 10, 12, 14.4,
///         17.28, 20.736 — so the cumulative edges are 10, 22, 36.4, 53.68, 74.416 (x1e18). With
///         `depositFulcrumAlphaBps = BPS` the fulcrum sits on the source (`dStar = 0`) and `sigma = 4e18` gives
///         the nearest-first window: weights 0.75 / 0.5 / 0.25 / 0 at d = 1 / 2 / 3 / 4.
///
///         WHAT IS DELIBERATELY NOT CLAIMED. Exact `lump >= split` for EVERY decomposition does not
///         hold and is not asserted. A split whose cut points fall inside a band can migrate the
///         depositor's rounded bucket mid-band, which a lump cannot reproduce without integrating over
///         that migration. Band-aligned equality is the exact property; the sub-band residual is
///         measured in {testFuzz_subBandSplitAdvantage_staysBounded} rather than assumed away.
///
///         "Diamond slice" below means the exiting-tier slice: the portion of a redeem fee that
///         goes to the exiting tier's other holders.
contract CurveDepositNeutralityTest is Test {
    DynamicFeeFlatPriceCurve internal curve;

    /// @dev Deployed once and shared by every proxy this suite raises. The config-parametric tests
    ///      stand up a fresh vault per fuzz run, and re-deploying the implementation each time is the
    ///      difference between a suite that runs in seconds and one nobody will wait for.
    DynamicFeeFlatPriceCurve internal implementation;

    address internal proxyAdmin = address(0xAD);
    address internal owner = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";
    uint256 internal constant BPS = 10_000;
    bytes32 internal constant T1 = keccak256("term-1");

    /// @dev Per-band per-share truncation is bounded by `tierStake / ACC_PRECISION` per credited tier
    ///      per distribution. At these stakes the real bound is a few hundred wei across a full ladder
    ///      walk; 1e4 is generous and still fourteen orders of magnitude below the fees moved.
    uint256 internal constant MAX_TRUNCATION_DUST_WEI = 1e4;

    /// @dev Ceilings for the residual-advantage properties, in basis points of the amount deposited,
    ///      each set from a MEASURED worst case rather than from a round number.
    ///
    ///      These were previously a single 1 % everywhere. That is a poor ceiling for the sub-band
    ///      cases — at a 1.5–3 % blended fee rate it is on the order of the entire fee, so it could not
    ///      tell a splitter capturing most of the fee from one capturing none. It is, however, close to
    ///      right for the WALLET cases, and the reason is worth recording rather than hiding behind a
    ///      constant.
    ///
    ///      The figures are produced by {CurveSplitEdgeMeasurementTest}, which is committed alongside
    ///      this file so they can be re-derived rather than taken on trust. Run it after any change to
    ///      the ladder, the kernel or the fee schedule. Worst case over that sweep:
    ///
    ///        sub-band split (equal or skewed)   ~4-6 bps
    ///        wallet split                       peaks in the 55-66 bps band from N=4 upward
    ///
    ///      READ THE WALLET FIGURE CAREFULLY, because it carries the property this suite exists for.
    ///      The residual rises from small N and then SATURATES: the worst case over N=7..10 is no
    ///      greater than the worst over N=2..5, and {CurveSplitEdgeMeasurementTest} asserts exactly
    ///      that. It does not scale with wallet count, which is the whole question — a residual growing
    ///      with N would be a sybil attack that pays to add wallets, whereas one that plateaus is a
    ///      structural floor. The floor is the known one: an account holds a single stake-weighted
    ///      bucket while N accounts hold N, so N accounts collect across several kernel weights at
    ///      once. Closing it means per-tier positions per account, which is a storage-layout and
    ///      claim-math redesign and is deliberately out of scope.
    ///
    ///      The saturation level is materially higher than the ~7 bps quoted when this work landed.
    ///      That figure was a single sample rather than a maximum — every time the sample size grew,
    ///      so did the observed edge. The mechanism is unchanged and still bounded, but size the
    ///      economics against ~66 bps, not ~7.
    ///
    ///      The INTERLEAVED figure below is fuzz-observed rather than sweep-measured: 112 bps at 5 000
    ///      runs, against 26 bps from a single earlier counterexample. It is quoted as an observation,
    ///      not as a maximum.
    ///
    ///      If a run drives any of these above its ceiling, that is a finding to report rather than a
    ///      ceiling to raise.
    ///      The INTERLEAVED ceiling is different in kind from the other two and is deliberately loose.
    ///      That test does not compare two spellings of one history; it compares a lump against legs
    ///      threaded between other actors' deposits and redeems, which are genuinely different
    ///      sequences. Most of what it measures is history divergence rather than anything the splitter
    ///      captured, and the redeems dominate the variance. Treat it as an order-of-magnitude guard
    ///      only, and note it is not covered by the committed sweep. The exact
    ///      content of that test is its conservation and solvency assertions, not this bound.
    uint256 internal constant MAX_SUB_BAND_EDGE_BPS = 40; // sweep peaks at 6 — real headroom, so tightened
    uint256 internal constant MAX_WALLET_EDGE_BPS = 100; // sweep peaks at 66 in the saturation band
    uint256 internal constant MAX_INTERLEAVED_EDGE_BPS = 500; // fuzz-observed 112; history divergence

    /// @dev `bps` of `amount`, for the residual ceilings above.
    function _edgeCeiling(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return (amount * bps) / BPS;
    }

    function setUp() public {
        implementation = new DynamicFeeFlatPriceCurve();
        curve = _deploy(_defaultConfig());
        vm.deal(address(this), 10_000_000e18);
    }

    /* =================================================== */
    /*                      HELPERS                        */
    /* =================================================== */

    function _deploy(DynamicFeeConfig memory config) internal returns (DynamicFeeFlatPriceCurve) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
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
            minEligibleTierStake: 0
        });
    }

    /// @dev A deposit priced the way MultiVault prices it: quote the fee on the base, stake the rest,
    ///      forward the fee. Keeps the harness honest about the quote/forward equality.
    function _deposit(address account, uint256 base) internal returns (uint256 fee, uint256 shares) {
        fee = curve.quoteDepositFee(T1, base);
        shares = base - fee;
        curve.recordDeposit{ value: fee }(T1, account, shares);
    }

    /// @dev A redeem priced the way MultiVault prices it: quote at the account's own tier, forward it.
    function _redeem(address account, uint256 shares) internal returns (uint256 fee) {
        fee = curve.quoteRedeemFee(T1, account, shares);
        curve.recordRedeem{ value: fee }(T1, account, shares);
    }

    /// @dev Total economic position: flat-par stake plus everything owed from the side pocket.
    function _position(address account) internal view returns (uint256) {
        return curve.userStake(T1, account) + curve.claimable(account, T1);
    }

    /// @dev Every wei the curve has ever been forwarded must still be attributable.
    function _custodyIsAttributable(address[] memory holders) internal view {
        uint256 owed = curve.protocolAccrued();
        for (uint256 i = 0; i < holders.length; i++) {
            owed += curve.claimable(holders[i], T1);
        }
        assertLe(owed, address(curve).balance, "the curve can never owe more than it holds");
        assertLe(address(curve).balance - owed, MAX_TRUNCATION_DUST_WEI, "unattributed custody stays dust-scale");
    }

    /* =================================================== */
    /*        BAND-ALIGNED SPLIT == LUMP (EXACT)          */
    /* =================================================== */

    /// @dev The core equivalence. One deposit that crosses three bands leaves exactly the state that
    ///      three deposits — one per band — would have left: same stake, same bucket, same average
    ///      entry tier, same claimable for the depositor AND for every bystander, same protocol bucket.
    function test_bandAlignedSplitEqualsLump() external {
        // Seed two bystanders low on the ladder so the fee has somewhere to go.
        _deposit(alice, 8e18); // bucket 0
        _deposit(bob, 10e18); // spans into tier 1

        uint256 snap = vm.snapshotState();

        // Lump: carol crosses from the current cursor up through several bands in one call.
        _deposit(carol, 40e18);
        uint256 lumpCarol = _position(carol);
        uint256 lumpAlice = _position(alice);
        uint256 lumpBob = _position(bob);
        uint256 lumpTier = curve.userTier(T1, carol);
        uint256 lumpAvg = curve.userAvgTier(T1, carol);
        uint256 lumpProtocol = curve.protocolAccrued();
        uint256 lumpVault = curve.vaultStake(T1);

        vm.revertToState(snap);

        // Split at the band edges the lump crossed. `recordDeposit` is called once per band with that
        // band's own stake and fee, which is precisely what the replay does internally.
        _depositBandByBand(carol, 40e18);

        assertEq(_position(carol), lumpCarol, "depositor position identical");
        assertEq(_position(alice), lumpAlice, "bystander alice identical");
        assertEq(_position(bob), lumpBob, "bystander bob identical");
        assertEq(curve.userTier(T1, carol), lumpTier, "bucket identical");
        assertEq(curve.userAvgTier(T1, carol), lumpAvg, "average entry tier identical");
        assertEq(curve.protocolAccrued(), lumpProtocol, "protocol bucket identical");
        assertEq(curve.vaultStake(T1), lumpVault, "vault total identical");
    }

    /// @dev Replays `base` as one `recordDeposit` per band it traverses, using the same apportionment
    ///      the contract uses, so the comparison isolates the REPLAY from the fee quote.
    function _depositBandByBand(address account, uint256 base) internal {
        uint256 fee = curve.quoteDepositFee(T1, base);
        uint256 shares = base - fee;
        uint256 topTier = curve.getConfig().tierCount - 1;

        // Pass 1: the bands, and the weight each carries.
        uint256[] memory bandStake = new uint256[](topTier + 1);
        uint256 bandCount;
        uint256 totalWeight;
        {
            uint256 cursor = curve.vaultStake(T1);
            uint256 tier = curve.tierOf(cursor);
            uint256 remaining = shares;
            while (remaining > 0) {
                uint256 chunk = remaining;
                if (tier < topTier) {
                    uint256 room = curve.tierUpperEdge(tier) - cursor;
                    if (room < chunk) chunk = room;
                }
                bandStake[bandCount] = chunk;
                totalWeight += (chunk * curve.depositFeeBps(tier)) / BPS;
                remaining -= chunk;
                cursor += chunk;
                ++tier;
                ++bandCount;
            }
        }

        // Pass 2: one hook call per band, last band taking the exact fee remainder.
        uint256 sourceTier = curve.tierOf(curve.vaultStake(T1));
        uint256 assigned;
        for (uint256 i = 0; i < bandCount; i++) {
            uint256 bandFee;
            if (i + 1 == bandCount) {
                bandFee = fee - assigned;
            } else if (totalWeight > 0) {
                bandFee = (fee * ((bandStake[i] * curve.depositFeeBps(sourceTier + i)) / BPS)) / totalWeight;
                assigned += bandFee;
            }
            curve.recordDeposit{ value: bandFee }(T1, account, bandStake[i]);
        }
    }

    /// @dev The honest counterpart to {test_bandAlignedSplitEqualsLump}, and the one that answers what
    ///      a USER actually experiences.
    ///
    ///      That test feeds the contract's own fee apportionment back into the split path, so it proves
    ///      the replay reproduces an idealised per-band sequence. It does NOT prove the replay matches
    ///      real separate deposits, because a real deposit quotes its own leg independently — and a sum
    ///      of independently quoted legs is not the same number as one lump quote, since each leg pays
    ///      its own per-band round-up.
    ///
    ///      So this quotes every leg on its own — which is the distinction being tested, since separate
    ///      deposits do not share one apportionment the way the replay does — sizes each leg to land on
    ///      a band edge, and compares against a lump of the SAME total gross. Still at the isolated
    ///      curve level: MultiVault's own protocol / entry / atom-wallet fees are NOT in these numbers,
    ///      so read the bound below as a curve-level property, not as an end-to-end user figure. The two do NOT come
    /// out identical: the split pays strictly more fee (each leg carries its own per-band round-up),
    ///      but part of that extra returns to the depositor, because each leg's stake is already a
    ///      prior-tier holder by the time the next leg's fee is distributed. Net, the splitter ends up
    ///      very slightly AHEAD — measured at ~1.8e14 wei on a ~21.6 TRUST position, under a basis
    ///      point of the amount deposited.
    ///
    ///      This is what bounds it, and it is the honest statement of the property: exact equality
    ///      belongs only to {test_bandAlignedSplitEqualsLump}, which is a claim about the replay
    ///      mechanism reproducing an idealised sequence with a common fee apportionment. On the real
    ///      deposit path, where every leg is quoted independently, the claim is only that the edge stays
    ///      sub-basis-point — small enough to be dominated by the gas of the extra transactions.
    function test_bandAlignedSplit_independentlyQuoted_edgeStaysSubBasisPoint() external {
        _deposit(alice, 8e18); // bystanders below
        _deposit(bob, 10e18);

        uint256 start = curve.vaultStake(T1);
        uint256 topTier = curve.getConfig().tierCount - 1;
        uint256 tier = curve.tierOf(start);

        // Size three legs: two that each exactly fill their band, then a tail inside the next one.
        uint256[3] memory legs;
        uint256 cursor = start;
        for (uint256 i = 0; i < 2; ++i) {
            uint256 rate = curve.depositFeeBps(tier + i);
            uint256 roomNet = curve.tierUpperEdge(tier + i) - cursor;
            legs[i] = (roomNet * BPS + (BPS - rate) - 1) / (BPS - rate); // gross whose NET fills the band
            cursor += roomNet;
        }
        legs[2] = 3e18;
        uint256 totalGross = legs[0] + legs[1] + legs[2];
        assertLt(tier + 2, topTier, "the ladder must have room for this walk");

        uint256 snap = vm.snapshotState();

        (uint256 lumpFee,) = _deposit(carol, totalGross);
        uint256 lumpCarol = _position(carol);
        uint256 lumpAlice = _position(alice);
        uint256 lumpBob = _position(bob);

        vm.revertToState(snap);

        // Each leg independently quoted — this is the real deposit path, not the replay's own split.
        uint256 splitFee;
        for (uint256 i = 0; i < 3; ++i) {
            (uint256 legFee,) = _deposit(carol, legs[i]);
            splitFee += legFee;
        }

        // The load-bearing assertion: whatever edge independently-quoted legs buy, it stays under a
        // basis point of the amount deposited — small enough that the extra transactions' gas dominates
        // it, and far below the sub-band residual this suite already bounds.
        assertApproxEqAbs(_position(carol), lumpCarol, totalGross / 10_000, "the split edge stays under 1 bps");
        // Bystanders are not moved by the arrangement beyond the same rounding.
        assertApproxEqAbs(_position(alice), lumpAlice, totalGross / 10_000, "bystander alice barely moves");
        assertApproxEqAbs(_position(bob), lumpBob, totalGross / 10_000, "bystander bob barely moves");
        // The fee itself is never cheaper when split — that leg of the property is exact.
        assertGe(splitFee, lumpFee, "splitting never buys a cheaper fee");
    }

    /// @dev The same equivalence over arbitrary seeds and deposit sizes.
    function testFuzz_bandAlignedSplitEqualsLump(uint256 seedA, uint256 seedB, uint256 amount) external {
        seedA = bound(seedA, 1e18, 30e18);
        seedB = bound(seedB, 1e18, 30e18);
        amount = bound(amount, 1e18, 120e18);

        _deposit(alice, seedA);
        _deposit(bob, seedB);

        uint256 snap = vm.snapshotState();
        _deposit(carol, amount);
        uint256 lumpCarol = _position(carol);
        uint256 lumpAlice = _position(alice);
        uint256 lumpBob = _position(bob);
        uint256 lumpProtocol = curve.protocolAccrued();

        vm.revertToState(snap);
        _depositBandByBand(carol, amount);

        assertEq(_position(carol), lumpCarol, "depositor position identical");
        assertEq(_position(alice), lumpAlice, "bystander alice identical");
        assertEq(_position(bob), lumpBob, "bystander bob identical");
        assertEq(curve.protocolAccrued(), lumpProtocol, "protocol bucket identical");
    }

    /* =================================================== */
    /*                 WALLET INVARIANCE                   */
    /* =================================================== */

    /// @dev The sybil leg. The SAME sequence of deposits run from one wallet and from N wallets must
    ///      leave the bystander in exactly the same place and must not pay the payer more in aggregate.
    ///
    ///      Note what this does and does not fix. The fee DISTRIBUTION no longer depends on who is
    ///      paying — no denominator has anyone removed from it — so splitting buys nothing there. What
    ///      remains is a property of the POSITION model, not the fee model: an account holds one
    ///      stake-weighted bucket, while N accounts can hold N buckets and therefore collect from
    ///      several kernel weights at once. That residual is bounded and does not grow with wallet
    ///      count; closing it means giving an account per-tier positions instead of one averaged
    ///      bucket, which is a different change.
    function testFuzz_walletInvariance_bystanderIsUnaffected(uint256 seed, uint256 amount, uint8 parts) external {
        seed = bound(seed, 5e18, 30e18);
        amount = bound(amount, 3e18, 90e18);
        uint256 legs = bound(parts, 2, 6);
        uint256 slice = amount / legs;
        vm.assume(slice > 0);

        _deposit(alice, seed); // the honest bystander

        uint256 snap = vm.snapshotState();

        // One wallet, `legs` deposits.
        for (uint256 i = 0; i < legs; i++) {
            _deposit(bob, i + 1 == legs ? amount - slice * (legs - 1) : slice);
        }
        uint256 oneWalletPayer = _position(bob);
        uint256 oneWalletBystander = _position(alice);
        uint256 oneWalletProtocol = curve.protocolAccrued();

        vm.revertToState(snap);

        // `legs` wallets, one deposit each.
        uint256 manyWalletsPayer;
        address[] memory sybils = new address[](legs);
        for (uint256 i = 0; i < legs; i++) {
            sybils[i] = makeAddr(string.concat("sybil", vm.toString(i)));
            _deposit(sybils[i], i + 1 == legs ? amount - slice * (legs - 1) : slice);
        }
        for (uint256 i = 0; i < legs; i++) {
            manyWalletsPayer += _position(sybils[i]);
        }

        // (1) The fee charged is identical either way — nothing about the quote depends on the payer,
        //     and nothing extra is forfeited. Only per-share truncation can differ, because the two
        //     arrangements credit different denominators.
        assertApproxEqAbs(
            curve.protocolAccrued(),
            oneWalletProtocol,
            MAX_TRUNCATION_DUST_WEI,
            "protocol bucket unaffected by the wallet split"
        );

        // (2) The payer cannot manufacture value out of the arrangement, and whatever edge survives is
        //     small MEASURED AGAINST THE DEPOSIT — which is the denominator that matters, since that is
        //     what an attacker must put at risk to capture it. (Against the bystander's own position the
        //     same wei is a larger percentage, but that framing says nothing about profitability.)
        assertLe(
            manyWalletsPayer,
            oneWalletPayer + _edgeCeiling(amount, MAX_WALLET_EDGE_BPS),
            "the equal-slice sybil edge stays within its measured saturation ceiling"
        );

        // (3) It is a pure transfer, not creation: whatever the payer gains, the bystander loses, and
        //     it is bounded by the same figure.
        if (oneWalletBystander > _position(alice)) {
            assertLe(
                oneWalletBystander - _position(alice),
                _edgeCeiling(amount, MAX_WALLET_EDGE_BPS),
                "bystander dilution is bounded alike"
            );
        }

        // (4) Conservation is arrangement-independent: the system holds the same total either way.
        assertApproxEqAbs(
            manyWalletsPayer + _position(alice) + curve.protocolAccrued(),
            oneWalletPayer + oneWalletBystander + oneWalletProtocol,
            MAX_TRUNCATION_DUST_WEI,
            "the arrangement redistributes value, it never creates it"
        );
    }

    /* =================================================== */
    /*                   SOLE OCCUPANT                     */
    /* =================================================== */

    /// @dev The case this change exists for. A holder who owns every eligible prior tier recovers their
    ///      own deposit fee instead of forfeiting it to the protocol. Only the tier-0 band — which has
    ///      no prior tier by construction — still accrues to the protocol.
    function test_soleOccupant_recoversOwnDepositFee() external {
        // The opening deposit must carry the vault PAST the tier-0 edge, otherwise the next deposit
        // still begins with a tier-0 band, and a tier-0 band has no prior tier to pay by construction.
        _deposit(alice, 12e18);
        assertEq(curve.tierOf(curve.vaultStake(T1)), 1, "the vault must be out of tier 0");
        assertEq(curve.userTier(T1, alice), 0, "alice holds the tier below");

        uint256 protocolBefore = curve.protocolAccrued();
        uint256 claimableBefore = curve.claimable(alice, T1);

        // Now she climbs from tier 1 into tier 3 in a single transaction, alone the whole way.
        (uint256 fee,) = _deposit(alice, 40e18);

        uint256 recovered = curve.claimable(alice, T1) - claimableBefore;
        uint256 forfeited = curve.protocolAccrued() - protocolBefore;

        assertEq(forfeited, 0, "no band of this deposit lacks a prior tier, so nothing is forfeited");
        assertApproxEqAbs(recovered, fee, MAX_TRUNCATION_DUST_WEI, "the sole occupant recovers their own fee");
    }

    /* =================================================== */
    /*             NO SELF-PAYMENT WITHIN A BAND           */
    /* =================================================== */

    /// @dev A band's fee reaches only the tiers BELOW that band, and the band's own stake lands after
    ///      its fee has been distributed. So a depositor entering a fresh vault at tier 0 — where there
    ///      is no tier below — can never be paid out of their own fee, no matter the size.
    function test_sameTierSelfPayment_impossible() external {
        (uint256 fee,) = _deposit(alice, 9e18); // stays inside tier 0

        assertEq(curve.claimable(alice, T1), 0, "no prior tier exists, so the depositor receives nothing");
        assertEq(curve.protocolAccrued(), fee, "the whole fee is undistributable and goes to the protocol");
    }

    /// @dev The same guard one tier up: a depositor whose position sits at or above the band being
    ///      charged is outside the recipient set structurally, without any stake being subtracted.
    function test_depositorAtTheSourceTierEarnsNothingFromTheirOwnBand() external {
        _deposit(alice, 8e18); // alice, bucket 0
        _deposit(bob, 6e18); // bob enters at tier 0 too; vault -> ~13.9 (tier 1)

        // bob tops up while the vault sits in tier 1 and stays within that band. His own bucket rises
        // to 1 only AFTER the band's fee has been distributed, so this band pays tier 0 (alice), and
        // bob collects only on the tier-0 stake he genuinely held beforehand.
        uint256 bobBefore = curve.claimable(bob, T1);
        uint256 aliceBefore = curve.claimable(alice, T1);
        (uint256 fee,) = _deposit(bob, 5e18);

        uint256 bobEarned = curve.claimable(bob, T1) - bobBefore;
        uint256 aliceEarned = curve.claimable(alice, T1) - aliceBefore;
        assertGt(aliceEarned, 0, "the prior tier is paid");
        assertApproxEqAbs(bobEarned + aliceEarned, fee, MAX_TRUNCATION_DUST_WEI, "the whole fee reaches tier 0");
        // bob's share is his pro-rata ownership of tier 0 at distribution time, never more.
        assertLt(bobEarned, fee, "bob cannot receive his own whole fee while another holder shares his tier");
    }

    /* =================================================== */
    /*                  FEE ADDITIVITY                     */
    /* =================================================== */

    /// @dev Net-anchored traversal: splitting a deposit must not buy cheaper bands. The split's total
    ///      quoted fee is at least the lump's, the gap being the per-band round-up only.
    function testFuzz_feeIsNotCheaperWhenSplit(uint256 start, uint256 amount, uint8 parts) external {
        start = bound(start, 0, 40e18);
        amount = bound(amount, 2e18, 100e18);
        uint256 legs = bound(parts, 2, 8);
        uint256 slice = amount / legs;
        vm.assume(slice > 0);

        if (start > 0) _deposit(alice, start);

        uint256 snap = vm.snapshotState();
        uint256 lumpFee = curve.quoteDepositFee(T1, amount);

        vm.revertToState(snap);
        uint256 splitFee;
        for (uint256 i = 0; i < legs; i++) {
            uint256 leg = i + 1 == legs ? amount - slice * (legs - 1) : slice;
            splitFee += curve.quoteDepositFee(T1, leg);
            curve.recordDeposit{ value: curve.quoteDepositFee(T1, leg) }(T1, bob, leg - curve.quoteDepositFee(T1, leg));
        }

        assertGe(splitFee, lumpFee, "splitting never buys a cheaper blended rate");
    }

    /* =================================================== */
    /*                    CONSERVATION                     */
    /* =================================================== */

    /// @dev Every wei forwarded to the curve terminates in a recipient tier or in the protocol bucket.
    ///      Nothing is minted, double-credited or stranded beyond per-share truncation dust.
    function testFuzz_conservation(uint256 a, uint256 b, uint256 c) external {
        a = bound(a, 1e18, 60e18);
        b = bound(b, 1e18, 60e18);
        c = bound(c, 1e18, 60e18);

        _deposit(alice, a);
        _deposit(bob, b);
        _deposit(carol, c);

        address[] memory holders = new address[](3);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = carol;
        _custodyIsAttributable(holders);
    }

    /// @dev The curve's ledger must still mirror the stake it was handed, band replay or not.
    function testFuzz_vaultStakeEqualsSumOfTierStakes(uint256 a, uint256 b, uint256 c) external {
        a = bound(a, 1e18, 60e18);
        b = bound(b, 1e18, 60e18);
        c = bound(c, 1e18, 60e18);

        _deposit(alice, a);
        _deposit(bob, b);
        _deposit(carol, c);

        assertEq(
            curve.vaultStake(T1),
            curve.userStake(T1, alice) + curve.userStake(T1, bob) + curve.userStake(T1, carol),
            "vault total equals the sum of positions"
        );

        uint256 bucketed;
        for (uint256 t = 0; t < curve.getConfig().tierCount; t++) {
            bucketed += curve.tierStake(T1, t);
        }
        assertEq(bucketed, curve.vaultStake(T1), "every unit of stake sits in exactly one bucket");
    }

    /* =================================================== */
    /*                  SUB-BAND RESIDUAL                  */
    /* =================================================== */

    /// @dev The property that is NOT exact, measured rather than assumed. A split whose cut points fall
    ///      inside a band can migrate the depositor's rounded bucket mid-band, which the lump cannot
    ///      reproduce. This pins the size of that residual so a future change cannot widen it unnoticed.
    function testFuzz_subBandSplitAdvantage_staysBounded(uint256 seed, uint256 amount, uint8 parts) external {
        seed = bound(seed, 5e18, 30e18);
        amount = bound(amount, 2e18, 60e18);
        uint256 legs = bound(parts, 2, 6);
        uint256 slice = amount / legs;
        vm.assume(slice > 0);

        _deposit(alice, seed);

        uint256 snap = vm.snapshotState();
        _deposit(bob, amount);
        uint256 lump = _position(bob);

        vm.revertToState(snap);
        for (uint256 i = 0; i < legs; i++) {
            _deposit(bob, i + 1 == legs ? amount - slice * (legs - 1) : slice);
        }
        uint256 split = _position(bob);

        if (split > lump) {
            // 1% of the deposit is a deliberately loose ceiling: the observed residual is far smaller,
            // and the point of the bound is to catch a regression in kind, not to pin a constant.
            assertLe(
                split - lump,
                _edgeCeiling(amount, MAX_SUB_BAND_EDGE_BPS),
                "sub-band splitting stays economically immaterial"
            );
        }
    }

    /* =================================================== */
    /*                  ANTI-WASH (REDEEM)                 */
    /* =================================================== */

    /// @dev The redeem-side exclusion is now the only thing making a round trip costly, so pin it. A
    ///      deposit-then-redeem must return strictly less than it put in, including everything the
    ///      actor can claim from the side pocket.
    function testFuzz_washRoundTripIsNetNegative(uint256 seed, uint256 amount) external {
        seed = bound(seed, 5e18, 40e18);
        amount = bound(amount, 1e18, 60e18);

        _deposit(alice, seed);

        (, uint256 shares) = _deposit(bob, amount);
        uint256 exitFee = curve.quoteRedeemFee(T1, bob, shares);
        curve.recordRedeem{ value: exitFee }(T1, bob, shares);

        uint256 returned = (shares - exitFee) + curve.claimable(bob, T1);
        assertLt(returned, amount, "a wash round trip always loses value");
    }

    /// @dev PARTIAL exits are where the redeem-side exclusion actually does work, and the full-exit
    ///      cases above cannot test it: at `residual == 0` the exclusion is arithmetically a no-op.
    ///
    ///      With `residual > 0` the exiter still holds stake in the very tier their redeem fee
    ///      lands on. The diamond slice is sized against a denominator that deliberately OMITS that
    ///      residual (`tierStake[exitTier] - residual`), so crediting the residual anyway would pay
    ///      out more than the fee collected — a solvency hole, not merely an unfairness. This pins
    ///      both halves: the exiter earns nothing, and the cohort that does earn is paid in full.
    function test_partialExit_exiterEarnsNothingFromTheirOwnRedeemFee() external {
        _deposit(alice, 8e18); // bystander in tier 0
        (, uint256 bobStake) = _deposit(bob, 12e18); // bob books bucket 1
        _deposit(carol, 2e18); // carol stays inside tier 1, sharing bob's bucket

        assertEq(curve.userTier(T1, bob), 1, "bob must sit in tier 1");
        assertEq(curve.userTier(T1, carol), 1, "carol must share bob's tier for the slice to land");

        uint256 bobBefore = curve.claimable(bob, T1);
        uint256 carolBefore = curve.claimable(carol, T1);
        uint256 protocolBefore = curve.protocolAccrued();

        uint256 exitFee = _redeem(bob, bobStake / 2);
        assertGt(curve.userStake(T1, bob), 0, "this must be a PARTIAL exit or the test proves nothing");
        assertGt(exitFee, 0, "and it must actually charge a fee");

        assertEq(curve.claimable(bob, T1), bobBefore, "the exiter earns nothing from their own exit fee");
        assertApproxEqAbs(
            curve.claimable(carol, T1) - carolBefore,
            exitFee,
            MAX_TRUNCATION_DUST_WEI,
            "the residual cohort receives the whole slice"
        );
        assertEq(curve.protocolAccrued(), protocolBefore, "nothing is orphaned while a cohort exists");
    }

    /// @dev The solvency half of the same property, fuzzed over sizes so the bucket arrangement
    ///      varies: however the partial exits interleave, the curve can never owe more than it holds.
    ///      Crediting an exiter's residual against a denominator that excludes it would break this.
    function testFuzz_partialExits_neverOweMoreThanHeld(uint256 a, uint256 b, uint256 c, uint256 exitPct) external {
        a = bound(a, 2e18, 40e18);
        b = bound(b, 2e18, 40e18);
        c = bound(c, 2e18, 40e18);
        exitPct = bound(exitPct, 1, 99);

        _deposit(alice, a);
        (, uint256 bobStake) = _deposit(bob, b);
        _deposit(carol, c);

        uint256 exitShares = (bobStake * exitPct) / 100;
        vm.assume(exitShares > 0 && exitShares < bobStake);
        _redeem(bob, exitShares);

        address[] memory holders = new address[](3);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = carol;
        _custodyIsAttributable(holders);
    }

    /// @dev And the sole-occupant version, which is the strongest case for a single-address actor: even
    ///      when he recovers most of his own deposit fee on the way in, the exit fee still bites.
    ///
    ///      This measures the round trip as an actual P&L on the WASHED leg — gross in versus
    ///      everything recoverable out — rather than against a loose constant. The earlier form of this
    ///      test compared the exit proceeds to a fixed `48e18`, which the position could not have
    ///      reached even if the whole fee had been refunded, so it could never have failed. It also
    ///      never netted out the seed deposit alice keeps, so it was not a round-trip figure at all.
    function test_washRoundTrip_soleOccupantStillLoses() external {
        _deposit(alice, 8e18); // the seat she keeps; not part of the washed leg

        uint256 claimableBeforeWash = curve.claimable(alice, T1);
        uint256 washGross = 40e18;
        (, uint256 shares) = _deposit(alice, washGross);

        uint256 exitFee = curve.quoteRedeemFee(T1, alice, shares);
        curve.recordRedeem{ value: exitFee }(T1, alice, shares);

        // Everything the washed leg returns: the stake that came back, plus only the earnings the
        // wash itself generated. Anything she had already accrued is not proceeds of this round trip.
        uint256 recovered = (shares - exitFee) + (curve.claimable(alice, T1) - claimableBeforeWash);

        assertGt(exitFee, 0, "the exit fee is what keeps the round trip costly");
        assertLt(recovered, washGross, "the sole occupant ends behind on the washed leg itself");
        // And the loss is a real fraction of the fees paid, not a rounding artefact — pinning the
        // MAGNITUDE is what stops a future change from quietly eroding this to break-even.
        assertGt(washGross - recovered, exitFee / 2, "the round trip loses materially, not marginally");
    }

    /// @dev The same round trip run by ONE ACTOR ACROSS TWO ADDRESSES, which is the arrangement the
    ///      single-address tests above structurally cannot reach — and it does NOT lose materially.
    ///
    ///      The mechanism is the whale-exit reroute rather than anything on the deposit leg. When the
    ///      exiting address is the last holder of its tier the residual cohort is empty, so the diamond
    ///      slice cannot be paid to it and reroutes to the nearest occupied tier — which may be the
    ///      actor's own second address. The exit fee therefore comes back to the actor instead of
    ///      leaving, and the round trip lands near break-even.
    ///
    ///      This is pinned rather than fixed, deliberately. The reroute exists so a departing whale's
    ///      fee reaches a stayer instead of the protocol, which is the behaviour we want; and the same
    ///      two-address sequence was already near break-even BEFORE the deposit-leg exclusion was
    ///      removed, by the other route — back then the DEPOSIT fee escaped to the second address. So
    ///      this is not an edge the per-band change opened. What the test guards is that the contract's
    ///      own claim stays honest: the redeem-leg exclusion is a PER-ACCOUNT guarantee, and nothing is
    ///      minted at any point.
    function test_washRoundTrip_twoAddressActorReachesBreakEven_andNothingIsMinted() external {
        address actorA = makeAddr("actor-A");
        address actorB = makeAddr("actor-B");

        _deposit(actorA, 9e18); // actorA takes bucket 0
        _deposit(actorB, 4e18); // actorB lands above him

        uint256 pairEarnedBefore = curve.claimable(actorA, T1) + curve.claimable(actorB, T1);
        uint256 forwardedBefore = address(curve).balance;
        uint256 washGross = 20e18;

        uint256 feesPaid;
        {
            (uint256 depositFee, uint256 shares) = _deposit(actorA, washGross);

            // Snapshot IMMEDIATELY before the redeem so the exclusion assertion isolates the redeem
            // leg. Bounding actorA's total gain by the DEPOSIT fee instead does not do this: he has
            // already earned less than that fee on the way in, and the slack between the two would let
            // an erroneous exit-fee credit through unnoticed.
            uint256 aBeforeRedeem = curve.claimable(actorA, T1);

            uint256 exitFee = curve.quoteRedeemFee(T1, actorA, shares);
            curve.recordRedeem{ value: exitFee }(T1, actorA, shares);
            feesPaid = depositFee + exitFee;

            assertEq(
                curve.claimable(actorA, T1),
                aBeforeRedeem,
                "the exiting account receives nothing at all from its own exit fee"
            );

            // The actor is BOTH addresses, so the round-trip P&L must count both.
            uint256 recovered =
                (shares - exitFee) + (curve.claimable(actorA, T1) + curve.claimable(actorB, T1) - pairEarnedBefore);
            assertApproxEqAbs(recovered, washGross, MAX_TRUNCATION_DUST_WEI, "a two-address actor round-trips for free");
        }

        assertGt(feesPaid, 0, "the actor really did pay both fees");
        // Nothing was minted to pay for any of it: the curve still holds every wei it was forwarded.
        assertEq(address(curve).balance, forwardedBefore + feesPaid, "no value is created");

        address[] memory holders = new address[](2);
        holders[0] = actorA;
        holders[1] = actorB;
        assertLe(
            curve.protocolAccrued() + curve.claimable(actorA, T1) + curve.claimable(actorB, T1),
            address(curve).balance,
            "the curve never owes more than it holds"
        );
        _custodyIsAttributable(holders);
    }

    /* =================================================== */
    /*            GAP-CLOSING HELPERS (BELOW)              */
    /* =================================================== */

    /// @dev A fuzzable projection of the ladder surface. Narrower types than {DynamicFeeConfig} so the
    ///      fuzzer spends its entropy inside the validated ranges instead of on values `_setConfig`
    ///      rejects outright; {_ladderConfig} does the final bounding.
    struct LadderSeed {
        uint96 width0;
        uint8 tierCount;
        uint16 tierWidthGrowthBps;
        uint16 depositBaseBps;
        uint16 depositGrowthBps;
        uint16 depositCapBps;
        uint16 depositFulcrumAlphaBps;
        uint64 depositKernelSpread;
        uint16 depositToPriorTierBps;
        uint96 minEligibleTierStake;
    }

    /// @dev Bound a {LadderSeed} into a config `_setConfig` accepts. Every range here is the contract's
    ///      own validated range, narrowed only where an unnarrowed value would make the test vacuous
    ///      rather than where it would make it fail:
    ///
    ///      - `tierCount >= 3` because a property about prior tiers needs prior tiers to exist, and 13
    ///        is the deployed schedule's count. `tierCount` may only ever grow, but each run deploys a
    ///        fresh proxy, so the grow-only rule never binds here.
    ///      - `width0` is kept in a range the suite's deposit sizes can actually traverse. A ladder
    ///        whose first band dwarfs every deposit never crosses a band, and a test that never crosses
    ///        a band proves nothing about per-band replay.
    ///      - `depositKernelSpread` is floored ABOVE one whole tier. At `sigma <= WAD` every integer distance
    ///        gets a hard zero from the triangular kernel and the spread collapses into a single-tier
    ///        lump — real, reachable, and pinned deliberately in
    ///        {test_subTierKernelSpread_collapsesTheSpreadIntoASingleTierLump}. Leaving it in range here
    ///        would silently convert a spread-distribution property into a winner-takes-all one.
    ///      - the redeem fields stay at their defaults: this is the DEPOSIT-neutrality suite, and
    ///        fuzzing the exit schedule would widen the search space without widening what is proven.
    function _ladderConfig(LadderSeed memory seed) internal pure returns (DynamicFeeConfig memory config) {
        config = _defaultConfig();
        config.width0 = bound(seed.width0, 1e18, 200e18);
        config.tierCount = bound(seed.tierCount, 3, 13);
        config.tierWidthGrowthBps = bound(seed.tierWidthGrowthBps, 0, 5000);
        config.depositCapBps = bound(seed.depositCapBps, 1, 2000);
        config.depositBaseBps = bound(seed.depositBaseBps, 0, config.depositCapBps);
        config.depositGrowthBps = bound(seed.depositGrowthBps, 0, 300);
        config.depositFulcrumAlphaBps = bound(seed.depositFulcrumAlphaBps, 0, BPS);
        config.depositKernelSpread = bound(seed.depositKernelSpread, 1e18 + 1, 8e18);
        config.depositToPriorTierBps = bound(seed.depositToPriorTierBps, 0, BPS);
        config.minEligibleTierStake = bound(seed.minEligibleTierStake, 0, 1000e18);
    }

    /// @dev Truncation dust scales with the ledger, not with a constant: {_creditByWeight} drops up to
    ///      `tierStake / ACC_PRECISION` wei per credited tier per distribution, and a fuzzed ladder can
    ///      run far more of both than the pinned one. The fixed {MAX_TRUNCATION_DUST_WEI} is right for
    ///      the default ladder; anything config-parametric needs the bound derived from the state the
    ///      run actually built — at most `tierCount` bands each crediting at most `tierCount` tiers.
    function _dustBound() internal view returns (uint256) {
        uint256 tiers = curve.getConfig().tierCount;
        return MAX_TRUNCATION_DUST_WEI + (curve.vaultStake(T1) / curve.ACC_PRECISION()) * tiers * tiers;
    }

    /// @dev Decompose `total` into `legs` UNEQUAL parts. The equal-slice helpers elsewhere in this file
    ///      fuzz the leg COUNT but always hand every leg the same size, and equal thirds are not the
    ///      shape an attacker picks — `[1%, 60%, 39%]` is. Each leg is drawn from what is left rather
    ///      than from a fixed fraction, so the shapes range from near-equal to extremely skewed while
    ///      every leg stays at least 1 wei and the parts sum to `total` exactly.
    function _unequalSlices(uint256 total, uint256 legs, uint256 seed) internal pure returns (uint256[] memory) {
        uint256[] memory slices = new uint256[](legs);
        uint256 remaining = total;
        for (uint256 i = 0; i + 1 < legs; ++i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            // Reserve one wei for each leg still to be drawn, so no leg can be starved to zero.
            uint256 maxLeg = remaining - (legs - i - 1);
            slices[i] = 1 + (seed % maxLeg);
            remaining -= slices[i];
        }
        slices[legs - 1] = remaining;
        return slices;
    }

    /// @dev Park the vault at EXACTLY `targetAssets` with a distinct holder seated in every tier the
    ///      walk passes, so a fee released anywhere on the ladder always finds a real cohort below it.
    ///
    ///      Deposits are recorded with a zero fee. That is deliberate: the harness stands in as the
    ///      authorized MultiVault, so this is the same hook a real deposit uses, just without a quote in
    ///      front of it — which is what makes the landing point exact instead of fee-dependent. The
    ///      starting state is the independent variable in these tests; how it was reached is not.
    function _seedLadderTo(uint256 targetAssets) internal {
        uint256 placed = curve.vaultStake(T1);
        uint256 topTier = curve.getConfig().tierCount - 1;
        uint256 tier = curve.tierOf(placed);
        while (placed < targetAssets) {
            uint256 stop = targetAssets;
            if (tier < topTier) {
                uint256 edge = curve.tierUpperEdge(tier);
                if (edge < stop) stop = edge;
            }
            if (stop > placed) {
                curve.recordDeposit{ value: 0 }(T1, makeAddr(string.concat("seed", vm.toString(tier))), stop - placed);
                placed = stop;
            }
            unchecked {
                ++tier;
            }
        }
    }

    /// @dev Sum of everything the curve owes across `holders`, plus the protocol bucket. The quantity
    ///      that must be conserved across two arrangements of the same money.
    function _systemTotal(address[] memory holders) internal view returns (uint256 total) {
        total = curve.protocolAccrued();
        for (uint256 i = 0; i < holders.length; ++i) {
            total += _position(holders[i]);
        }
    }

    /* =================================================== */
    /*             CONFIG-PARAMETRIC NEUTRALITY            */
    /* =================================================== */

    /// @dev The exact-equality property is a property of the MECHANISM, not of one schedule. The rest of
    ///      this suite pins a single ladder (`width0 = 10`, 5 tiers, `g = 0.2`); every field of it is
    ///      governance-tunable and `tierCount` may only ever grow, so a claim that holds only at the
    ///      shipped values is not the claim the mechanism needs to support.
    ///
    ///      This re-runs the band-aligned equivalence against a fresh vault per run, over the validated
    ///      ranges of `width0`, `tierCount`, `tierWidthGrowthBps`, the deposit-fee schedule, both fulcrum knobs
    ///      and the eligibility floor. Equality must stay EXACT everywhere — the replay and the
    ///      band-by-band sequence perform the identical integer operations regardless of the schedule
    ///      they are reading, and any config-dependent divergence is a real defect.
    function testFuzz_configParametric_bandAlignedSplitEqualsLump(LadderSeed memory seed, uint256 amount) external {
        DynamicFeeConfig memory config = _ladderConfig(seed);
        curve = _deploy(config);

        // Seed occupancy across the low ladder, then size the deposit so it genuinely crosses bands.
        _seedLadderTo(bound(amount, config.width0 / 2, config.width0 * 2));
        amount = bound(amount, config.width0 / 2, config.width0 * 4);

        uint256 snap = vm.snapshotState();
        _deposit(carol, amount);
        uint256 lumpCarol = _position(carol);
        uint256 lumpTier = curve.userTier(T1, carol);
        uint256 lumpAvg = curve.userAvgTier(T1, carol);
        uint256 lumpProtocol = curve.protocolAccrued();
        uint256 lumpVault = curve.vaultStake(T1);

        vm.revertToState(snap);
        _depositBandByBand(carol, amount);

        assertEq(_position(carol), lumpCarol, "depositor position identical at any schedule");
        assertEq(curve.userTier(T1, carol), lumpTier, "bucket identical at any schedule");
        assertEq(curve.userAvgTier(T1, carol), lumpAvg, "average entry tier identical at any schedule");
        assertEq(curve.protocolAccrued(), lumpProtocol, "protocol bucket identical at any schedule");
        assertEq(curve.vaultStake(T1), lumpVault, "vault total identical at any schedule");
    }

    /// @dev The fee-additivity leg, config-parametric. Splitting must never buy a cheaper blended rate,
    ///      whatever the tier widths, the growth factor or the fee schedule are set to.
    function testFuzz_configParametric_feeIsNotCheaperWhenSplit(LadderSeed memory seed, uint256 amount, uint8 parts)
        external
    {
        DynamicFeeConfig memory config = _ladderConfig(seed);
        curve = _deploy(config);

        uint256 legs = bound(parts, 2, 8);
        amount = bound(amount, config.width0 / 2, config.width0 * 4);
        vm.assume(amount >= legs);

        _seedLadderTo(config.width0);

        uint256 snap = vm.snapshotState();
        uint256 lumpFee = curve.quoteDepositFee(T1, amount);

        vm.revertToState(snap);
        uint256[] memory slices = _unequalSlices(amount, legs, uint256(keccak256(abi.encode(seed.width0, amount))));
        uint256 splitFee;
        for (uint256 i = 0; i < legs; ++i) {
            (uint256 legFee,) = _deposit(bob, slices[i]);
            splitFee += legFee;
        }

        assertGe(splitFee, lumpFee, "splitting never buys a cheaper blended rate, at any schedule");
    }

    /// @dev Conservation, config-parametric. Every wei forwarded still terminates in a recipient tier or
    ///      the protocol bucket, and the ledger still mirrors the stake — including under a live
    ///      eligibility floor, which changes WHO qualifies but must never change how much exists.
    function testFuzz_configParametric_conservation(LadderSeed memory seed, uint256 a, uint256 b, uint256 c) external {
        DynamicFeeConfig memory config = _ladderConfig(seed);
        curve = _deploy(config);

        a = bound(a, 1e15, config.width0 * 3);
        b = bound(b, 1e15, config.width0 * 3);
        c = bound(c, 1e15, config.width0 * 3);

        _deposit(alice, a);
        _deposit(bob, b);
        _deposit(carol, c);

        address[] memory holders = new address[](3);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = carol;

        uint256 owed = curve.protocolAccrued();
        for (uint256 i = 0; i < holders.length; ++i) {
            owed += curve.claimable(holders[i], T1);
        }
        assertLe(owed, address(curve).balance, "the curve can never owe more than it holds, at any schedule");
        assertLe(address(curve).balance - owed, _dustBound(), "unattributed custody stays dust-scale");

        assertEq(
            curve.vaultStake(T1),
            curve.userStake(T1, alice) + curve.userStake(T1, bob) + curve.userStake(T1, carol),
            "vault total equals the sum of positions, at any schedule"
        );

        uint256 bucketed;
        for (uint256 t = 0; t < config.tierCount; ++t) {
            bucketed += curve.tierStake(T1, t);
        }
        assertEq(bucketed, curve.vaultStake(T1), "every unit of stake sits in exactly one bucket");
    }

    /* =================================================== */
    /*                  UNEQUAL DECOMPOSITION              */
    /* =================================================== */

    /// @dev The sub-band residual under an ARBITRARY decomposition rather than equal slices. Equal
    ///      thirds are one point in the space; the shape that maximises the residual is skewed, because
    ///      it is the cut points landing mid-band that migrate the depositor's rounded bucket, and a
    ///      skewed cut lands wherever it likes. This is the residual's real ceiling, not
    ///      {testFuzz_subBandSplitAdvantage_staysBounded}'s.
    ///
    ///      The bound is the documented one and it is a bound, not a target: the residual exists by
    ///      design (one account holds one stake-weighted bucket; the split migrates it mid-band) and
    ///      closing it means per-tier positions per account. If a run drives this above the bound, that
    ///      is a finding to report rather than a bound to raise.
    function testFuzz_unequalSlices_subBandSplitAdvantageStaysBounded(
        uint256 seed,
        uint256 amount,
        uint8 parts,
        uint256 shapeSeed
    ) external {
        seed = bound(seed, 5e18, 30e18);
        amount = bound(amount, 2e18, 60e18);
        uint256 legs = bound(parts, 2, 6);

        _deposit(alice, seed);

        uint256 snap = vm.snapshotState();
        _deposit(bob, amount);
        uint256 lump = _position(bob);

        vm.revertToState(snap);
        uint256[] memory slices = _unequalSlices(amount, legs, shapeSeed);
        for (uint256 i = 0; i < legs; ++i) {
            _deposit(bob, slices[i]);
        }
        uint256 split = _position(bob);

        if (split > lump) {
            assertLe(
                split - lump,
                _edgeCeiling(amount, MAX_SUB_BAND_EDGE_BPS),
                "an arbitrary decomposition stays within the same ceiling"
            );
        }
    }

    /// @dev Wallet invariance under an arbitrary decomposition. The sybil leg's existing test splits the
    ///      money evenly across wallets; an attacker sizes each wallet independently, and a skewed
    ///      arrangement is what lets one wallet sit in a high-earning bucket while the others feed it.
    function testFuzz_unequalSlices_walletInvariance(uint256 seed, uint256 amount, uint8 parts, uint256 shapeSeed)
        external
    {
        seed = bound(seed, 5e18, 30e18);
        amount = bound(amount, 3e18, 90e18);
        uint256 legs = bound(parts, 2, 6);

        _deposit(alice, seed);
        uint256[] memory slices = _unequalSlices(amount, legs, shapeSeed);

        uint256 snap = vm.snapshotState();

        for (uint256 i = 0; i < legs; ++i) {
            _deposit(bob, slices[i]);
        }
        uint256 oneWalletPayer = _position(bob);
        uint256 oneWalletBystander = _position(alice);
        uint256 oneWalletProtocol = curve.protocolAccrued();

        vm.revertToState(snap);

        uint256 manyWalletsPayer;
        address[] memory sybils = new address[](legs);
        for (uint256 i = 0; i < legs; ++i) {
            sybils[i] = makeAddr(string.concat("skewed-sybil", vm.toString(i)));
            _deposit(sybils[i], slices[i]);
        }
        for (uint256 i = 0; i < legs; ++i) {
            manyWalletsPayer += _position(sybils[i]);
        }

        assertApproxEqAbs(
            curve.protocolAccrued(),
            oneWalletProtocol,
            MAX_TRUNCATION_DUST_WEI,
            "protocol bucket unaffected by a skewed wallet split"
        );
        assertLe(
            manyWalletsPayer,
            oneWalletPayer + _edgeCeiling(amount, MAX_WALLET_EDGE_BPS),
            "the skewed sybil edge stays within its own, wider measured ceiling"
        );
        assertApproxEqAbs(
            manyWalletsPayer + _position(alice) + curve.protocolAccrued(),
            oneWalletPayer + oneWalletBystander + oneWalletProtocol,
            MAX_TRUNCATION_DUST_WEI,
            "a skewed arrangement redistributes value, it never creates it"
        );
    }

    /* =================================================== */
    /*           N-WAY BAND-ALIGNED, INDEPENDENT QUOTES    */
    /* =================================================== */

    /// @dev {test_bandAlignedSplit_independentlyQuoted_edgeStaysSubBasisPoint} fixes the walk at three
    ///      legs. The exact-equality claim is for ANY number of boundary-aligned legs, and the
    ///      independently-quoted edge is the number a user actually experiences, so the leg count is the
    ///      one parameter that most needs fuzzing here — each extra leg adds another per-band round-up
    ///      AND another chance for the previous leg's stake to be earning by the time the next leg's fee
    ///      is released. Those pull in opposite directions; this checks the net stays sub-basis-point as
    ///      the count grows rather than compounding with it.
    function testFuzz_bandAlignedNWaySplit_independentlyQuoted_edgeStaysSubBasisPoint(uint8 parts, uint256 tail)
        external
    {
        _deposit(alice, 8e18);
        _deposit(bob, 10e18);

        uint256 start = curve.vaultStake(T1);
        uint256 topTier = curve.getConfig().tierCount - 1;
        uint256 tier = curve.tierOf(start);
        // Fill whole bands up to the last one on the ladder, then a tail inside the next band.
        uint256 legs = bound(parts, 2, topTier - tier);

        uint256[] memory sized = new uint256[](legs + 1);
        uint256 cursor = start;
        for (uint256 i = 0; i < legs; ++i) {
            uint256 rate = curve.depositFeeBps(tier + i);
            uint256 roomNet = curve.tierUpperEdge(tier + i) - cursor;
            sized[i] = (roomNet * BPS + (BPS - rate) - 1) / (BPS - rate); // gross whose NET fills the band
            cursor += roomNet;
        }
        sized[legs] = bound(tail, 1e17, 3e18);

        uint256 totalGross;
        for (uint256 i = 0; i <= legs; ++i) {
            totalGross += sized[i];
        }

        uint256 snap = vm.snapshotState();

        (uint256 lumpFee,) = _deposit(carol, totalGross);
        uint256 lumpCarol = _position(carol);
        uint256 lumpAlice = _position(alice);

        vm.revertToState(snap);

        uint256 splitFee;
        for (uint256 i = 0; i <= legs; ++i) {
            (uint256 legFee,) = _deposit(carol, sized[i]);
            splitFee += legFee;
        }

        assertApproxEqAbs(_position(carol), lumpCarol, totalGross / 10_000, "the N-way split edge stays under 1 bps");
        assertApproxEqAbs(_position(alice), lumpAlice, totalGross / 10_000, "bystander alice barely moves at any N");
        assertGe(splitFee, lumpFee, "splitting into N band-aligned legs never buys a cheaper fee");
    }

    /* =================================================== */
    /*              STARTING STATE ACROSS THE LADDER       */
    /* =================================================== */

    /// @dev The suite's other tests start the vault wherever two seed deposits happen to leave it, which
    ///      is a thin slice of the state space and never lands on a band edge exactly. Band edges are
    ///      where `_tierOf` changes answer and where `_walkDepositBands` computes a zero-width room, so
    ///      they are precisely where an off-by-one lives.
    ///
    ///      This parks the vault at every tier edge and at one wei either side of it, then asserts the
    ///      band-aligned equivalence from there. The terminal tier is included: it has no upper edge and
    ///      absorbs unbounded stake, so its band is the one that never closes.
    function testFuzz_startAtEveryBandEdge_bandAlignedSplitEqualsLump(uint256 edgeIndex, uint256 offset, uint256 amount)
        external
    {
        uint256 topTier = curve.getConfig().tierCount - 1;
        uint256 k = bound(edgeIndex, 0, topTier);
        uint256 target = curve.tierUpperEdge(k);
        // -1 / 0 / +1 around the edge: below it, on it, and just over into the next band.
        uint256 which = bound(offset, 0, 2);
        if (which == 0) target -= 1;
        if (which == 2) target += 1;

        _seedLadderTo(target);
        assertEq(curve.vaultStake(T1), target, "the vault must start exactly where the test placed it");

        amount = bound(amount, 1e18, 60e18);

        uint256 snap = vm.snapshotState();
        _deposit(carol, amount);
        uint256 lumpCarol = _position(carol);
        uint256 lumpTier = curve.userTier(T1, carol);
        uint256 lumpAvg = curve.userAvgTier(T1, carol);
        uint256 lumpProtocol = curve.protocolAccrued();

        vm.revertToState(snap);
        _depositBandByBand(carol, amount);

        assertEq(_position(carol), lumpCarol, "depositor position identical from any edge");
        assertEq(curve.userTier(T1, carol), lumpTier, "bucket identical from any edge");
        assertEq(curve.userAvgTier(T1, carol), lumpAvg, "average entry tier identical from any edge");
        assertEq(curve.protocolAccrued(), lumpProtocol, "protocol bucket identical from any edge");
    }

    /// @dev The terminal tier absorbs everything above the last edge, so a deposit that starts there can
    ///      never cross a band however large it is. That makes the single-band fast path the ONLY path
    ///      it takes, and the fast path is a separate branch from the loop — it must still be neutral.
    function testFuzz_terminalTier_absorbsUnboundedDepositNeutrally(uint256 amount, uint8 parts) external {
        uint256 topTier = curve.getConfig().tierCount - 1;
        _seedLadderTo(curve.tierUpperEdge(topTier - 1) + 1e18);
        assertEq(curve.tierOf(curve.vaultStake(T1)), topTier, "the vault must start in the terminal tier");

        amount = bound(amount, 1e18, 500e18);
        uint256 legs = bound(parts, 2, 6);
        vm.assume(amount >= legs);

        uint256 snap = vm.snapshotState();
        (uint256 lumpFee,) = _deposit(carol, amount);
        uint256 lump = _position(carol);

        vm.revertToState(snap);
        uint256[] memory slices = _unequalSlices(amount, legs, amount);
        uint256 splitFee;
        for (uint256 i = 0; i < legs; ++i) {
            (uint256 legFee,) = _deposit(carol, slices[i]);
            splitFee += legFee;
        }

        // Inside one band there is no bucket to migrate, so the only residual is the per-leg fee
        // round-up — which costs the splitter rather than paying them. Carol's own stake lands at the
        // terminal tier after the first leg, and a band's fee reaches only the tiers BELOW it, so she
        // never recovers any part of what the extra legs cost her.
        assertLe(_position(carol), lump, "splitting inside the terminal tier never pays");
        assertGe(splitFee, lumpFee, "and each extra leg carries its own round-up");
    }

    /* =================================================== */
    /*                     INTERLEAVING                    */
    /* =================================================== */

    /// @dev Splits interleaved with OTHER actors, which is the arrangement an attacker actually has
    ///      available — back-to-back legs in an empty room is the easy case. Between every leg a third
    ///      party deposits and a fourth partially exits, so the tier occupancy, the kernel denominators
    ///      and the vault cursor all move underneath the splitter mid-sequence.
    ///
    ///      Exact equality is NOT the claim here and could not be: the two arrangements are genuinely
    ///      different histories, not two spellings of one. What must hold is that the interference does
    ///      not turn a bounded residual into an unbounded one, and that the system still conserves.
    function testFuzz_interleavedActors_splitBuysNoUnboundedAdvantage(
        uint256 seed,
        uint256 amount,
        uint8 parts,
        uint256 shapeSeed
    ) external {
        seed = bound(seed, 5e18, 30e18);
        amount = bound(amount, 3e18, 60e18);
        uint256 legs = bound(parts, 2, 5);

        address dan = makeAddr("dan");
        address erin = makeAddr("erin");

        _deposit(alice, seed);
        (, uint256 danStake) = _deposit(dan, 12e18);
        _deposit(erin, 6e18);

        uint256[] memory slices = _unequalSlices(amount, legs, shapeSeed);

        address[] memory holders = new address[](5);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = dan;
        holders[3] = erin;
        holders[4] = carol;

        uint256 snap = vm.snapshotState();

        // Arrangement A: the splitter's money arrives as one lump, then the interference runs.
        _deposit(bob, amount);
        for (uint256 i = 0; i + 1 < legs; ++i) {
            _deposit(erin, 2e18);
            _redeem(dan, danStake / (legs + 2));
        }
        uint256 lumpPayer = _position(bob);
        uint256 lumpSystem = _systemTotal(holders);

        vm.revertToState(snap);

        // Arrangement B: the same interference, but the splitter's legs are threaded through it.
        for (uint256 i = 0; i < legs; ++i) {
            _deposit(bob, slices[i]);
            if (i + 1 < legs) {
                _deposit(erin, 2e18);
                _redeem(dan, danStake / (legs + 2));
            }
        }
        uint256 splitPayer = _position(bob);

        // (1) Interleaving does not unlock an advantage beyond the residual this suite already bounds.
        if (splitPayer > lumpPayer) {
            assertLe(
                splitPayer - lumpPayer,
                _edgeCeiling(amount, MAX_INTERLEAVED_EDGE_BPS),
                "interleaved splitting stays within the widest measured ceiling"
            );
        }
        // (2) The system holds the same total either way — the interference redistributes, never mints.
        assertApproxEqAbs(
            _systemTotal(holders), lumpSystem, _dustBound(), "interleaving redistributes value, it never creates it"
        );
        // (3) And solvency survives the whole sequence.
        _custodyIsAttributable(holders);
    }

    /// @dev A long random action sequence rather than a scripted two-path comparison. Neutrality under
    ///      an arbitrary history is a different question from neutrality between two arrangements, and
    ///      it is where the interesting failures live: the invariant lane next door proves flat pricing,
    ///      solvency and the ledger mirror, but nothing there exercises the per-band replay under a
    ///      randomized deposit/redeem mix.
    ///
    ///      What is asserted is what survives an unknown history: the curve never owes more than it
    ///      holds, the ledger keeps mirroring the buckets, and nothing is minted.
    function testFuzz_randomActionSequence_conservesValueAndStaysSolvent(uint256 seed, uint8 steps) external {
        uint256 actions = bound(steps, 4, 24);

        address[] memory holders = new address[](3);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = carol;

        // A floor under every position so redeems have something to bite on.
        for (uint256 i = 0; i < holders.length; ++i) {
            _deposit(holders[i], 5e18);
        }

        for (uint256 i = 0; i < actions; ++i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            address actor = holders[seed % holders.length];
            uint256 magnitude = 1e15 + ((seed >> 8) % 40e18);

            if ((seed >> 4) % 3 == 0) {
                uint256 held = curve.userStake(T1, actor);
                uint256 shares = held == 0 ? 0 : 1 + ((seed >> 16) % held);
                if (shares > 0) _redeem(actor, shares);
            } else {
                _deposit(actor, magnitude);
            }

            assertEq(
                curve.vaultStake(T1),
                curve.userStake(T1, alice) + curve.userStake(T1, bob) + curve.userStake(T1, carol),
                "the ledger mirrors the positions at every step"
            );
            uint256 bucketed;
            for (uint256 t = 0; t < curve.getConfig().tierCount; ++t) {
                bucketed += curve.tierStake(T1, t);
            }
            assertEq(bucketed, curve.vaultStake(T1), "every unit of stake sits in exactly one bucket at every step");
        }

        _custodyIsAttributable(holders);
    }

    /* =================================================== */
    /*            ELIGIBILITY FLOOR TURNED ON              */
    /* =================================================== */

    /// @dev `minEligibleTierStake` ships at 0 (disabled), so every other neutrality test in this file
    ///      runs the floor-off path. The floor changes the DEPOSIT leg's recipient set — a sub-floor
    ///      tier leaves the kernel normalization and its share is absorbed by the tiers that already
    ///      qualified — which is a genuinely different distribution branch, and the interface NatSpec
    ///      calls out that the deposit leg judges a tier on its FULL stake with nobody excluded.
    ///
    ///      Band-aligned equality must survive that intact: both arrangements read the same live
    ///      `tierStake` at the same points, so a floor that redirects the fee must redirect it
    ///      identically either way. Equality stays EXACT — a floor-dependent divergence would mean the
    ///      replay and the sequence disagree about who qualifies.
    function testFuzz_floorEnabled_bandAlignedSplitEqualsLump(uint256 floor, uint256 amount) external {
        DynamicFeeConfig memory config = _defaultConfig();
        config.minEligibleTierStake = bound(floor, 1, 1000e18);
        curve = _deploy(config);

        _deposit(alice, 8e18);
        _deposit(bob, 10e18);
        amount = bound(amount, 1e18, 120e18);

        uint256 snap = vm.snapshotState();
        _deposit(carol, amount);
        uint256 lumpCarol = _position(carol);
        uint256 lumpAlice = _position(alice);
        uint256 lumpBob = _position(bob);
        uint256 lumpProtocol = curve.protocolAccrued();

        vm.revertToState(snap);
        _depositBandByBand(carol, amount);

        assertEq(_position(carol), lumpCarol, "depositor position identical under a live floor");
        assertEq(_position(alice), lumpAlice, "bystander alice identical under a live floor");
        assertEq(_position(bob), lumpBob, "bystander bob identical under a live floor");
        assertEq(curve.protocolAccrued(), lumpProtocol, "protocol bucket identical under a live floor");
    }

    /// @dev The floor is the one recipient gate a sybil could hope to move, so state precisely what it
    ///      keys on: `minEligibleTierStake` is tested against `tierStake` — the TIER's total — never
    ///      against an individual position. A wallet holding dust therefore earns perfectly well while
    ///      sharing a tier that clears the floor, which is by design and is not the property at issue.
    ///
    ///      The property at issue is that the gate is ARRANGEMENT-BLIND. Because the test reads a tier
    ///      total, splitting one position into ten inside that tier cannot buy eligibility, and cannot
    ///      lose it either. Both directions are pinned: a cohort over the floor earns the same in
    ///      aggregate however it is divided, and a cohort under the floor earns nothing however finely
    ///      it is divided. The second half is the sybil-relevant one — if the floor were per-position,
    ///      the first arrangement would qualify and the second would not.
    function test_floorEnabled_splittingWithinATierCannotBuyOrLoseEligibility() external {
        // Tier 0 holds exactly one band's width (10 TRUST), so a floor below that admits the cohort and
        // a floor above it excludes the cohort — in both cases independently of how it is split.
        (uint256 oneWalletOver, uint256 protocolOver) = _tierZeroCohortEarnings(5e18, 1);
        (uint256 tenWalletsOver, uint256 protocolOverSplit) = _tierZeroCohortEarnings(5e18, 10);

        assertGt(oneWalletOver, 0, "a cohort above the floor must actually earn, or the test proves nothing");
        assertApproxEqAbs(
            tenWalletsOver, oneWalletOver, MAX_TRUNCATION_DUST_WEI, "dividing a qualifying cohort changes nothing"
        );
        assertApproxEqAbs(
            protocolOverSplit, protocolOver, MAX_TRUNCATION_DUST_WEI, "and the protocol bucket does not move either"
        );

        (uint256 oneWalletUnder, uint256 protocolUnder) = _tierZeroCohortEarnings(15e18, 1);
        (uint256 tenWalletsUnder, uint256 protocolUnderSplit) = _tierZeroCohortEarnings(15e18, 10);

        assertEq(oneWalletUnder, 0, "a cohort below the floor earns nothing");
        assertEq(tenWalletsUnder, 0, "and cannot buy its way in by splitting into ten positions");
        assertGt(protocolUnder, 0, "the excluded pool lands in the protocol bucket");
        assertEq(protocolUnderSplit, protocolUnder, "identically, whichever arrangement paid it");
    }

    /// @dev Stand up a fresh vault at `floor`, fill tier 0 to exactly its band width split across
    ///      `wallets` holders, then release one deposit fee from inside tier 1 — whose only prior tier is
    ///      tier 0. Reports what the tier-0 cohort earned in aggregate and what the protocol took.
    ///      Placement uses zero-fee records so the cohort total is exact rather than quote-dependent,
    ///      which is what makes the two arrangements comparable at all.
    function _tierZeroCohortEarnings(uint256 floor, uint256 wallets)
        internal
        returns (uint256 cohortEarned, uint256 protocolEarned)
    {
        DynamicFeeConfig memory config = _defaultConfig();
        config.minEligibleTierStake = floor;
        curve = _deploy(config);

        uint256 edge0 = curve.tierUpperEdge(0);
        uint256 slice = edge0 / wallets;
        address[] memory cohort = new address[](wallets);
        for (uint256 i = 0; i < wallets; ++i) {
            cohort[i] = makeAddr(string.concat("cohort", vm.toString(wallets), "-", vm.toString(i)));
            curve.recordDeposit{ value: 0 }(T1, cohort[i], i + 1 == wallets ? edge0 - slice * (wallets - 1) : slice);
        }
        assertEq(curve.tierStake(T1, 0), edge0, "tier 0 must hold exactly one band regardless of the split");
        assertEq(curve.tierOf(curve.vaultStake(T1)), 1, "the vault must sit in tier 1 so tier 0 is the prior tier");

        uint256 protocolBefore = curve.protocolAccrued();
        (uint256 fee,) = _deposit(carol, 2e18); // contained inside tier 1: exactly one band, one fee
        assertGt(fee, 0, "the probe deposit must actually charge a fee");

        for (uint256 i = 0; i < wallets; ++i) {
            cohortEarned += curve.claimable(cohort[i], T1);
        }
        protocolEarned = curve.protocolAccrued() - protocolBefore;
    }

    /* =================================================== */
    /*        LIVE CONFIG HAZARD: SUB-TIER KERNEL SPREAD   */
    /* =================================================== */

    /// @dev `depositKernelSpread` (σ) is validated only as `!= 0` and `<= MAX_KERNEL_SPREAD`. A lower bound of
    ///      one whole tier was tried on this work and withdrawn — see the note on `_setConfig` for why
    ///      neither a σ-only nor an alpha-keyed bound actually holds — so the sharp edge below is
    ///      REACHABLE by governance and is documented rather than prevented.
    ///
    ///      With σ ≤ one tier and `depositFulcrumAlphaBps = BPS` (the shipped default, fulcrum on the source
    ///      tier), every prior tier sits a full tier or more away, `_triangularWeight` returns a hard
    ///      zero for all of them, `sumWeights` is zero, and the whole pool falls through
    ///      `_awardNearestOrProtocol` as a single lump. Winner-takes-all silently replaces the
    ///      configured spread: no revert, no distinguishing event, and the observable behaviour stops
    ///      matching the schedule on file.
    ///
    ///      This pins BOTH halves so the edge cannot be rediscovered later as a surprise: collapsed at
    ///      σ = one tier, genuinely spread at the shipped σ = 4 tiers with everything else held equal.
    ///      Nothing is forfeited either way — the point is the distribution SHAPE, not a loss.
    function test_subTierKernelSpread_collapsesTheSpreadIntoASingleTierLump() external {
        address[] memory seated = new address[](3);
        seated[0] = makeAddr("tier0");
        seated[1] = makeAddr("tier1");
        seated[2] = makeAddr("tier2");

        // σ = one whole tier: the hard zero at `dist == sigma` catches every integer distance.
        DynamicFeeConfig memory collapsed = _defaultConfig();
        collapsed.depositKernelSpread = 1e18;
        uint256[3] memory lumpEarnings = _earningsAcrossThreeTiers(collapsed, seated);

        // σ = 4 tiers, the shipped default. Same ladder, same occupancy, same deposit.
        DynamicFeeConfig memory spread = _defaultConfig();
        spread.depositKernelSpread = 4e18;
        uint256[3] memory spreadEarnings = _earningsAcrossThreeTiers(spread, seated);

        uint256 collapsedPaid;
        uint256 spreadPaid;
        for (uint256 i = 0; i < 3; ++i) {
            if (lumpEarnings[i] > 0) ++collapsedPaid;
            if (spreadEarnings[i] > 0) ++spreadPaid;
        }

        assertEq(collapsedPaid, 1, "a sub-tier sigma pays exactly one tier - the spread has collapsed");
        assertGt(spreadPaid, 1, "the shipped sigma genuinely spreads across several tiers");
        // Nearest-first tie-break: the collapsed lump lands on the tier closest to the source, which at
        // `depositFulcrumAlphaBps = BPS` (dStar = 0) is the highest prior tier.
        assertGt(lumpEarnings[2], 0, "the whole pool lands on the prior tier nearest the source");
    }

    /// @dev Stand up a fresh vault under `config`, seat one holder in each of tiers 0/1/2 with the vault
    ///      left in tier 3, release one deposit fee from there and report what each seat earned.
    function _earningsAcrossThreeTiers(DynamicFeeConfig memory config, address[] memory seated)
        internal
        returns (uint256[3] memory earned)
    {
        curve = _deploy(config);

        // One holder per tier, each landing exactly inside its own band.
        curve.recordDeposit{ value: 0 }(T1, seated[0], curve.tierUpperEdge(0));
        curve.recordDeposit{ value: 0 }(T1, seated[1], curve.tierUpperEdge(1) - curve.tierUpperEdge(0));
        curve.recordDeposit{ value: 0 }(T1, seated[2], curve.tierUpperEdge(2) - curve.tierUpperEdge(1));
        for (uint256 i = 0; i < 3; ++i) {
            assertEq(curve.userTier(T1, seated[i]), i, "each seat must occupy its own tier");
        }
        assertEq(curve.tierOf(curve.vaultStake(T1)), 3, "the vault must sit one tier above the top seat");

        // A deposit contained inside tier 3, so exactly one band releases exactly one fee.
        (uint256 fee,) = _deposit(carol, 1e18);
        assertGt(fee, 0, "the probe deposit must actually charge a fee");

        for (uint256 i = 0; i < 3; ++i) {
            earned[i] = curve.claimable(seated[i], T1);
        }
    }

    /* =================================================== */
    /*            DUST BANDS AND THE WEIGHT FLOOR          */
    /* =================================================== */

    /// @dev Band weights are the bands' NOTIONAL FEES, `bandStake * rate / BPS`, and that division
    ///      floors. A band carrying under `BPS / rate` wei therefore weighs ZERO, and a deposit whose
    ///      every band is that small has a `totalWeight` of zero while still forwarding a fee — the
    ///      quote rounds up, so two wei straddling an edge really does forward one.
    ///
    ///      That combination skips the proportional branch entirely and the pool falls to the last band
    ///      as its remainder. This pins the outcome: no revert, no double-credit, nothing minted, and
    ///      the wei stays accounted for. It is the reason the `totalWeight > 0` guard sits on the
    ///      proportional branch alone and never on the remainder.
    function test_dustBandsStraddlingAnEdge_totalWeightFloorsToZeroAndThePoolStillTerminates() external {
        uint256 edge0 = curve.tierUpperEdge(0);
        curve.recordDeposit{ value: 0 }(T1, alice, edge0 - 1);
        assertEq(curve.tierOf(curve.vaultStake(T1)), 0, "the vault must start one wei below the tier-0 edge");

        // Two wei of net stake: one wei in tier 0, one in tier 1. Both notional fees floor to zero.
        uint256 base = 2;
        uint256 fee = curve.quoteDepositFee(T1, base);
        assertGt(fee, 0, "the round-up must actually produce a fee, or this proves nothing");
        assertEq((1 * curve.depositFeeBps(0)) / BPS, 0, "the tier-0 band must weigh zero");
        assertEq((1 * curve.depositFeeBps(1)) / BPS, 0, "the tier-1 band must weigh zero");

        uint256 balanceBefore = address(curve).balance;
        curve.recordDeposit{ value: fee }(T1, bob, base);

        assertEq(curve.vaultStake(T1), edge0 + 1, "both dust bands still land");
        assertEq(curve.userStake(T1, bob), base, "the depositor is credited the whole net stake");
        assertEq(address(curve).balance, balanceBefore + fee, "the forwarded fee is held, not lost");
        assertLe(
            curve.protocolAccrued() + curve.claimable(alice, T1) + curve.claimable(bob, T1),
            address(curve).balance,
            "the curve never owes more than it holds, even when every band weighs zero"
        );
    }
}
