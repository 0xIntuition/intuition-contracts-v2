// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @dev Bounded actor that drives random deposit / redeem / claim / retune sequences against the
///      dynamic-fee vault. All calls are wrapped in try/catch so a legitimately-reverting action
///      (e.g. a min-share breach) doesn't halt the invariant run; the invariants are asserted by the
///      parent after every call.
contract DynamicFeeInvariantHandler is Test {
    MultiVault internal immutable MULTI_VAULT;
    DynamicFeeFlatPriceCurve internal immutable CURVE;
    uint256 internal immutable CURVE_ID;
    bytes32 internal immutable ATOM_ID;
    address internal immutable OWNER;

    address[] internal actors;

    /// @dev Successful deposits. The invariants below are all "nothing bad happened" statements, which
    ///      hold trivially over a run in which nothing happened — so the count is what proves the lane
    ///      ran at all. See {afterInvariant}.
    uint256 public depositsLanded;

    /// @dev Same anti-vacuity role as {depositsLanded}, for the two ladder/kernel retune actions. A
    ///      retune that always bounced off validation would leave this lane looking like it covers the
    ///      admin surface while covering none of it, and every `setConfig` here is inside a try/catch
    ///      that would hide it.
    uint256 public ladderRetunesLanded;
    uint256 public kernelRetunesLanded;

    constructor(
        MultiVault multiVault,
        DynamicFeeFlatPriceCurve curve,
        uint256 curveId,
        bytes32 atomId,
        address owner,
        address[] memory actors_
    ) {
        MULTI_VAULT = multiVault;
        CURVE = curve;
        CURVE_ID = curveId;
        ATOM_ID = atomId;
        OWNER = owner;
        actors = actors_;
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i];
    }

    function deposit(uint256 actorSeed, uint256 amountSeed) external {
        address actor = actors[actorSeed % actors.length];
        uint256 amount = bound(amountSeed, 1e17, 200e18);
        vm.deal(actor, actor.balance + amount);
        vm.prank(actor);
        try MULTI_VAULT.deposit{ value: amount }(actor, ATOM_ID, CURVE_ID, 0) {
            ++depositsLanded;
        } catch { }
    }

    function redeem(uint256 actorSeed, uint256 sharesSeed) external {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = MULTI_VAULT.getShares(actor, ATOM_ID, CURVE_ID);
        if (balance == 0) return;
        uint256 shares = bound(sharesSeed, 1, balance);
        vm.prank(actor);
        try MULTI_VAULT.redeem(actor, ATOM_ID, CURVE_ID, shares, 0) { } catch { }
    }

    function claim(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        if (CURVE.claimable(actor, ATOM_ID) == 0) return;
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = ATOM_ID;
        vm.prank(actor);
        try CURVE.claim(terms) { } catch { }
    }

    function retune(uint256 depositBaseSeed, uint256 redeemBaseSeed) external {
        DynamicFeeConfig memory cfg = CURVE.getConfig();
        cfg.depositBaseBps = uint16(bound(depositBaseSeed, 0, cfg.depositCapBps));
        cfg.redeemBaseBps = uint16(bound(redeemBaseSeed, 0, cfg.redeemCapBps));
        vm.prank(OWNER);
        try CURVE.setConfig(cfg) { } catch { }
    }

    /// @dev Retune the LADDER SHAPE, not just the fee rates — the riskier half of the admin surface.
    ///      Changing `width0`, `tierWidthGrowthBps` or `tierCount` moves where every FUTURE tier decision lands
    ///      while live positions keep the buckets they were recorded with, so the accounting has to
    ///      survive a ladder that no longer matches the one those buckets were assigned under. That is
    ///      the stated model of this admin surface ("a retune is an economic action") and it was
    ///      previously never exercised: the fuzzer only ever moved the base rates.
    ///
    ///      Bounds are chosen so most proposals are ACCEPTED rather than bouncing off validation. A
    ///      range that mostly reverts would leave the lane looking exercised while testing nothing —
    ///      the same failure mode the open-prank bug produced. {ladderRetunesLanded} is the tripwire.
    function retuneLadder(uint256 widthSeed, uint256 growthSeed, uint256 tierSeed, uint256 floorSeed) external {
        DynamicFeeConfig memory cfg = CURVE.getConfig();
        cfg.width0 = bound(widthSeed, 1e17, 500e18);
        cfg.tierWidthGrowthBps = bound(growthSeed, 0, 8000);
        // Grow-only, so never propose a shrink: `_setConfig` rejects it outright and every call would
        // silently bounce. Growing by at most two at a time keeps the ladder reachable by test-scale
        // deposits instead of jumping straight to the 64-tier ceiling.
        cfg.tierCount = bound(tierSeed, cfg.tierCount, cfg.tierCount + 2);
        if (cfg.tierCount > CURVE.MAX_TIER_COUNT()) cfg.tierCount = CURVE.MAX_TIER_COUNT();
        cfg.minEligibleTierStake = bound(floorSeed, 0, CURVE.MAX_MIN_ELIGIBLE_TIER_STAKE());
        vm.prank(OWNER);
        try CURVE.setConfig(cfg) {
            ++ladderRetunesLanded;
        } catch { }
    }

    /// @dev The kernel knobs. `depositFulcrumAlphaBps` slides the most-earning band along the ladder and
    ///      `depositKernelSpread` sets how wide the earning window is. Neither changes how much fee is
    ///      CHARGED — only who receives it — which makes them the levers most likely to surface an
    ///      asymmetry between what is collected and what is credited. Includes the sub-tier spreads
    ///      that collapse the distribution into a single-tier lump, since that is reachable by
    ///      governance and the accounting must hold there too.
    function retuneKernel(uint256 alphaSeed, uint256 spreadSeed) external {
        DynamicFeeConfig memory cfg = CURVE.getConfig();
        cfg.depositFulcrumAlphaBps = bound(alphaSeed, 0, 10_000);
        cfg.depositKernelSpread = bound(spreadSeed, 1, CURVE.MAX_KERNEL_SPREAD());
        cfg.redeemFulcrumAlphaBps = bound(spreadSeed, 0, 10_000);
        cfg.redeemKernelSpread = bound(alphaSeed, 1, CURVE.MAX_KERNEL_SPREAD());
        vm.prank(OWNER);
        try CURVE.setConfig(cfg) {
            ++kernelRetunesLanded;
        } catch { }
    }
}

/// @title  DynamicFeeInvariantTest
/// @notice Stateful invariant suite for the flat-price / dynamic-fee curve. Over any random sequence of
///         deposits, redeems, claims and live retunes, the protocol-level economic + accounting
///         invariants must always hold:
///         - flat price never moves (the dynamic vault is always exactly 1:1);
///         - the curve is always solvent (its native balance covers every fee it owes);
///         - each user's side-pocket ledger exactly mirrors their MultiVault share balance.
contract DynamicFeeInvariantTest is BaseTest {
    DynamicFeeInvariantHandler internal handler;
    bytes32 internal atomId;
    uint256 internal constant ACTOR_COUNT = 3;

    function setUp() public override {
        super.setUp();
        atomId = createSimpleAtom("invariant", ATOM_COST[0], users.alice);
        // Seed the dynamic vault so it exists before the fuzzer starts.
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 10e18, 0);
        // `makeDeposit` leaves a prank open (via `resetPrank`). An open prank makes every `vm.prank`
        // inside the handler revert with "cannot override an ongoing prank", and because each action is
        // wrapped in try/catch that failure is silent — the whole lane dies and the invariants below are
        // asserted against a vault frozen exactly as `setUp` left it. Closing it here is what makes the
        // fuzzer able to transact at all.
        vm.stopPrank();

        address[] memory actors = new address[](ACTOR_COUNT);
        actors[0] = users.alice;
        actors[1] = users.bob;
        actors[2] = users.charlie;

        handler = new DynamicFeeInvariantHandler(
            protocol.multiVault, dynamicFeeCurve, DYNAMIC_FEE_CURVE_ID, atomId, users.admin, actors
        );
        targetContract(address(handler));
    }

    /// @dev Anti-vacuity tripwire. Runs once the fuzzer is done, when "the run did something" is a
    ///      meaningful thing to assert — an `invariant_` function cannot express it, because invariants
    ///      are also evaluated against the initial state before any call has been made.
    function afterInvariant() external view {
        assertGt(handler.depositsLanded(), 0, "the fuzz run must land at least one deposit");
        assertGt(handler.ladderRetunesLanded(), 0, "the fuzz run must land at least one ladder retune");
        assertGt(handler.kernelRetunesLanded(), 0, "the fuzz run must land at least one kernel retune");
    }

    /// @dev Flat par: totalAssets == totalShares on the dynamic vault, always.
    function invariant_flatPriceStays1to1() external view {
        (uint256 totalAssets, uint256 totalShares) = protocol.multiVault.getVault(atomId, DYNAMIC_FEE_CURVE_ID);
        assertEq(totalAssets, totalShares, "dynamic vault must stay exactly 1:1");
    }

    /// @dev Solvency: the curve's native balance always covers every obligation it owes (all users'
    ///      claimable + the protocol accrual). It can never be made to owe more than it holds.
    function invariant_curveIsAlwaysSolvent() external view {
        uint256 obligations = dynamicFeeCurve.protocolAccrued();
        for (uint256 i = 0; i < ACTOR_COUNT; ++i) {
            obligations += dynamicFeeCurve.claimable(handler.actorAt(i), atomId);
        }
        assertGe(address(dynamicFeeCurve).balance, obligations, "curve must cover every obligation (solvency)");
    }

    /// @dev The side-pocket per-user ledger exactly mirrors the MultiVault share balance, always.
    function invariant_ledgerMirrorsVaultShares() external view {
        for (uint256 i = 0; i < ACTOR_COUNT; ++i) {
            address actor = handler.actorAt(i);
            assertEq(
                dynamicFeeCurve.userStake(atomId, actor),
                protocol.multiVault.getShares(actor, atomId, DYNAMIC_FEE_CURVE_ID),
                "side-pocket ledger must mirror vault shares"
            );
        }
    }
}
