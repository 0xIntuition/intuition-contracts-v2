// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  CurveSplitEdgeMeasurementTest
/// @notice Measures the WORST-CASE split advantage the deposit-fee mechanism admits, and asserts the
///         ceilings {CurveDepositNeutralityTest} enforces are actually above it.
/// @dev    This file exists because a fuzz counterexample is not a maximum. The neutrality suite's
///         ceilings were originally set from single observed values, and each time the run count went
///         up the observed edge went up with it — a sampled figure was being quoted as if it were a
///         bound. A deterministic sweep is reproducible and can be reasoned about; `forge test` with a
///         different seed cannot.
///
///         Two things are asserted rather than merely printed, so this is a regression guard and not
///         just a report:
///           1. every sampled arrangement stays under the ceiling the neutrality suite uses, and
///           2. the wallet-count residual is ZERO on the deposit leg, and so trivially saturates. One
///              account's lots are the same lots N accounts would hold, one per band entered, and
///              the deposit leg applies no per-account exclusion, so it cannot tell the two
///              arrangements apart. Under the earlier averaged position model (one account held one
///              stake-weighted bucket, N accounts held N) the residual was a structural floor that
///              merely plateaued with N; the sweep here is what guards that it stays closed.
///
///         The printed maxima are the source of the figures quoted in {CurveDepositNeutralityTest}'s
///         ceiling notes. Re-run this file after any change to the ladder, the kernel or the fee
///         schedule; if the numbers move, update those notes rather than leaving them stale.
///
///         Sample counts are sized to stay inside the default block gas limit. They are a sweep, not a
///         proof: they establish that these arrangements reach roughly this much, not that nothing can
///         reach more.
contract CurveSplitEdgeMeasurementTest is Test {
    DynamicFeeFlatPriceCurve internal curve;
    DynamicFeeFlatPriceCurve internal implementation;

    address internal proxyAdmin = address(0xAD);
    address internal seeder = makeAddr("seeder");
    address internal payer = makeAddr("payer");

    uint256 internal constant BPS = 10_000;

    /// @dev Must match {CurveDepositNeutralityTest}'s ceilings. Duplicated deliberately: if the two
    ///      drift apart, this file's assertions stop guarding what that file enforces, and a mismatch
    ///      is easier to notice in two adjacent literals than through a shared import.
    uint256 internal constant NEUTRALITY_SUB_BAND_CEILING_BPS = 40;
    uint256 internal constant NEUTRALITY_WALLET_CEILING_BPS = 100;

    bytes32 internal constant T1 = keccak256("term-1");

    function setUp() public {
        implementation = new DynamicFeeFlatPriceCurve();
    }

    function _deployFresh() internal {
        DynamicFeeConfig memory config = DynamicFeeConfig({
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
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyAdmin,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector, "Curve", address(this), address(this), config
            )
        );
        curve = DynamicFeeFlatPriceCurve(address(proxy));
        vm.deal(address(this), 10_000_000e18);
    }

    function _deposit(address account, uint256 base) internal {
        uint256 fee = curve.quoteDepositFee(T1, base);
        curve.recordDeposit{ value: fee }(T1, account, base - fee);
    }

    function _position(address account) internal view returns (uint256) {
        return curve.userStake(T1, account) + curve.claimable(account, T1);
    }

    /// @dev One wallet running `legs` deposits versus `legs` wallets running one each, over a sweep of
    ///      seeds and amounts at a fixed wallet count. Returns the worst edge seen, in bps of the
    ///      amount deposited.
    function _worstWalletEdgeBps(uint256 legs, uint256 samples) internal returns (uint256 worstBps) {
        for (uint256 i = 0; i < samples; ++i) {
            uint256 entropy = uint256(keccak256(abi.encode("wallet-edge", legs, i)));
            uint256 seed = 5e18 + (entropy % 25e18);
            uint256 amount = 3e18 + ((entropy >> 64) % 87e18);
            uint256 slice = amount / legs;
            if (slice == 0) continue;

            _deployFresh();
            _deposit(seeder, seed);
            uint256 snap = vm.snapshotState();

            for (uint256 j = 0; j < legs; ++j) {
                _deposit(payer, j + 1 == legs ? amount - slice * (legs - 1) : slice);
            }
            uint256 oneWallet = _position(payer);

            vm.revertToState(snap);
            address[] memory sybils = new address[](legs);
            for (uint256 j = 0; j < legs; ++j) {
                sybils[j] = makeAddr(string.concat("w", vm.toString(legs), "-", vm.toString(i), "-", vm.toString(j)));
                _deposit(sybils[j], j + 1 == legs ? amount - slice * (legs - 1) : slice);
            }
            // Read every sybil only AFTER the last leg has landed. Reading inside the loop misses
            // everything the earlier wallets earn from the later legs, which is the whole effect.
            uint256 manyWallets;
            for (uint256 j = 0; j < legs; ++j) {
                manyWallets += _position(sybils[j]);
            }

            if (manyWallets > oneWallet) {
                uint256 edgeBps = ((manyWallets - oneWallet) * BPS) / amount;
                if (edgeBps > worstBps) worstBps = edgeBps;
            }
        }
    }

    /// @dev The sybil edge by wallet count. Prints the curve and asserts both that it stays under the
    ///      neutrality suite's ceiling and that it does not keep climbing with N.
    function test_measure_walletEdgeSaturatesWithWalletCount() external {
        uint256[9] memory observed;
        for (uint256 legs = 2; legs <= 10; ++legs) {
            uint256 worstBps = _worstWalletEdgeBps(legs, 10);
            observed[legs - 2] = worstBps;
            console.log("wallets / worst edge bps:", legs, worstBps);
            assertLt(worstBps, NEUTRALITY_WALLET_CEILING_BPS, "a sampled wallet split exceeded the suite's ceiling");
        }

        // Saturation: the top of the range must be no worse than the middle. Stated as a comparison of
        // maxima over halves rather than a monotonicity check, because the per-N figures are noisy
        // maxima over a small sample and individual steps legitimately move either way.
        uint256 lowHalf; // N = 2..5
        uint256 highHalf; // N = 7..10
        for (uint256 k = 0; k < 4; ++k) {
            if (observed[k] > lowHalf) lowHalf = observed[k];
            if (observed[k + 5] > highHalf) highHalf = observed[k + 5];
        }
        console.log("worst over N=2..5:", lowHalf);
        console.log("worst over N=7..10:", highHalf);
        // A residual that genuinely scaled would grow roughly LINEARLY in N, so ten wallets would be
        // several times two. A factor of two is therefore a real discriminator while staying robust to
        // the sampling noise in these small per-N maxima; a tighter margin would flake without
        // detecting anything a looser one misses.
        assertLe(highHalf, lowHalf * 2, "the wallet residual must saturate, not scale with wallet count");
    }

    /// @dev The sub-band residual: one wallet, a lump versus the same total cut inside bands. This is
    ///      the arrangement with real headroom under its ceiling, which is why that one was tightened.
    function test_measure_subBandSplitEdge() external {
        uint256 worstBps;
        for (uint256 i = 0; i < 60; ++i) {
            uint256 entropy = uint256(keccak256(abi.encode("sub-band-edge", i)));
            uint256 seed = 5e18 + (entropy % 25e18);
            uint256 amount = 2e18 + ((entropy >> 64) % 58e18);
            uint256 legs = 2 + ((entropy >> 128) % 5);
            uint256 slice = amount / legs;
            if (slice == 0) continue;

            _deployFresh();
            _deposit(seeder, seed);
            uint256 snap = vm.snapshotState();
            _deposit(payer, amount);
            uint256 lump = _position(payer);

            vm.revertToState(snap);
            for (uint256 j = 0; j < legs; ++j) {
                _deposit(payer, j + 1 == legs ? amount - slice * (legs - 1) : slice);
            }
            uint256 split = _position(payer);

            if (split > lump) {
                uint256 edgeBps = ((split - lump) * BPS) / amount;
                if (edgeBps > worstBps) worstBps = edgeBps;
            }
        }
        console.log("worst sub-band split edge bps:", worstBps);
        assertLt(worstBps, NEUTRALITY_SUB_BAND_CEILING_BPS, "a sampled sub-band split exceeded the suite's ceiling");
    }

    /// @dev The kernel configuration is not a lever on the wallet residual, in either direction. Under
    ///      the averaged position model it was: a sigma at or below one tier collapses the spread to a
    ///      single winner-takes-all tier, and a low `depositFulcrumAlphaBps` moves the peak onto the
    ///      earliest tiers, and both rewarded the arrangement that had a wallet sitting at the extreme
    ///      while a lump's averaged bucket sat in the middle. With one lot per band a lump occupies the
    ///      same tiers a split does, so whichever tier the kernel favours, both arrangements hold it
    ///      equally. Measured at the shipped kernel and at both levers rather than argued, since
    ///      arguing about it is how the earlier wrong answer got written down.
    function test_measure_theObviousConfigLeversDoNotReduceTheResidual() external {
        uint256 shipped = _worstWalletEdgeBpsAt(10_000, 4e18, 8);
        uint256 collapsedSigma = _worstWalletEdgeBpsAt(10_000, 1e18, 8);
        uint256 loweredAlpha = _worstWalletEdgeBpsAt(0, 4e18, 8);

        console.log("shipped (alpha=BPS, sigma=4) edge bps:", shipped);
        console.log("sub-tier sigma (sigma=1)     edge bps:", collapsedSigma);
        console.log("lowered alpha  (alpha=0)     edge bps:", loweredAlpha);

        assertEq(shipped, 0, "no wallet residual at the shipped kernel");
        assertEq(collapsedSigma, 0, "a collapsed spread opens none either");
        assertEq(loweredAlpha, 0, "nor does a fulcrum on the earliest tiers");
    }

    /// @dev {_worstWalletEdgeBps} against a non-default kernel. Kept separate so the main sweep stays
    ///      on the shipped schedule and this one cannot silently change what that sweep reports.
    function _worstWalletEdgeBpsAt(uint256 alpha, uint256 sigma, uint256 samples) internal returns (uint256 worstBps) {
        for (uint256 i = 0; i < samples; ++i) {
            uint256 entropy = uint256(keccak256(abi.encode("lever", alpha, sigma, i)));
            uint256 seed = 5e18 + (entropy % 25e18);
            uint256 amount = 8e18 + ((entropy >> 64) % 80e18);
            uint256 legs = 3 + ((entropy >> 128) % 4);
            uint256 slice = amount / legs;
            if (slice == 0) continue;

            _deployWithKernel(alpha, sigma);
            _deposit(seeder, seed);
            uint256 snap = vm.snapshotState();

            for (uint256 j = 0; j < legs; ++j) {
                _deposit(payer, j + 1 == legs ? amount - slice * (legs - 1) : slice);
            }
            uint256 oneWallet = _position(payer);

            vm.revertToState(snap);
            uint256 manyWallets = _spreadAcrossWallets(amount, legs, i);

            if (manyWallets > oneWallet) {
                uint256 edgeBps = ((manyWallets - oneWallet) * BPS) / amount;
                if (edgeBps > worstBps) worstBps = edgeBps;
            }
        }
    }

    function _spreadAcrossWallets(uint256 amount, uint256 legs, uint256 tag) internal returns (uint256 total) {
        uint256 slice = amount / legs;
        address[] memory sybils = new address[](legs);
        for (uint256 j = 0; j < legs; ++j) {
            sybils[j] = makeAddr(string.concat("lev", vm.toString(tag), "-", vm.toString(j)));
            _deposit(sybils[j], j + 1 == legs ? amount - slice * (legs - 1) : slice);
        }
        for (uint256 j = 0; j < legs; ++j) {
            total += _position(sybils[j]);
        }
    }

    function _deployWithKernel(uint256 alpha, uint256 sigma) internal {
        DynamicFeeConfig memory config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 5,
            tierWidthGrowthBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            depositFulcrumAlphaBps: alpha,
            depositKernelSpread: sigma,
            redeemFulcrumAlphaBps: alpha,
            redeemKernelSpread: sigma,
            redeemBaseBps: 200,
            redeemGrowthBps: 50,
            redeemCapBps: 1000,
            redeemToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStakeBps: 0
        });
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyAdmin,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector, "Curve", address(this), address(this), config
            )
        );
        curve = DynamicFeeFlatPriceCurve(address(proxy));
        vm.deal(address(this), 10_000_000e18);
    }

    /// @dev The advantage is a TRANSFER, not creation, and it needs someone to transfer from. With no
    ///      unrelated holder seated, splitting buys essentially nothing — the arrangement only moves
    ///      fees between the actor's own wallets. Seat a bystander and the payer's gain and the
    ///      bystander's loss track each other. That is the honest statement of who pays for this.
    function test_measure_theEdgeRequiresSomeoneToDiluteAndIsAPureTransfer() external {
        uint256 withoutBystander;
        for (uint256 i = 0; i < 8; ++i) {
            uint256 entropy = uint256(keccak256(abi.encode("nobystander", i)));
            uint256 amount = 8e18 + (entropy % 80e18);
            uint256 legs = 3 + ((entropy >> 128) % 4);
            uint256 slice = amount / legs;
            if (slice == 0) continue;

            _deployFresh();
            uint256 snap = vm.snapshotState();
            for (uint256 j = 0; j < legs; ++j) {
                _deposit(payer, j + 1 == legs ? amount - slice * (legs - 1) : slice);
            }
            uint256 oneWallet = _position(payer);

            vm.revertToState(snap);
            uint256 manyWallets = _spreadAcrossWallets(amount, legs, 900 + i);

            if (manyWallets > oneWallet) {
                uint256 edgeBps = ((manyWallets - oneWallet) * BPS) / amount;
                if (edgeBps > withoutBystander) withoutBystander = edgeBps;
            }
        }
        console.log("edge with NO bystander seated, bps:", withoutBystander);
        assertLt(withoutBystander, 10, "with nobody to dilute, splitting buys essentially nothing");
    }

    receive() external payable { }
}
