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
        try MULTI_VAULT.deposit{ value: amount }(actor, ATOM_ID, CURVE_ID, 0) { } catch { }
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

    function retune(uint256 depositBaseSeed, uint256 withdrawalBaseSeed) external {
        DynamicFeeConfig memory cfg = CURVE.getConfig();
        cfg.depositBaseBps = uint16(bound(depositBaseSeed, 0, cfg.depositCapBps));
        cfg.withdrawalBaseBps = uint16(bound(withdrawalBaseSeed, 0, cfg.withdrawalCapBps));
        vm.prank(OWNER);
        try CURVE.setConfig(cfg) { } catch { }
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

        address[] memory actors = new address[](ACTOR_COUNT);
        actors[0] = users.alice;
        actors[1] = users.bob;
        actors[2] = users.charlie;

        handler = new DynamicFeeInvariantHandler(
            protocol.multiVault, dynamicFeeCurve, DYNAMIC_FEE_CURVE_ID, atomId, users.admin, actors
        );
        targetContract(address(handler));
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
