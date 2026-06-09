// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { ApprovalTypes } from "src/interfaces/IMultiVault.sol";

/// @title  Track 2 — deposit↔redeem value extraction hunt (ENG-12460)
/// @notice Attempts to pull more assets out than were put in (rounding asymmetry,
///         first-depositor inflation, pro-rata asset injection) and confirms the
///         ghost-shares-to-BURN seeding blocks the classic inflation grief.
///         All NEGATIVE results: value is conserved / shares stay non-zero.
contract DepositRedeemExtractionTest is BaseTest {
    address internal constant BURN = 0x000000000000000000000000000000000000dEaD;

    uint256 internal DEFAULT_CURVE;
    uint256 internal constant OFFSET_PROGRESSIVE_CURVE = 2;
    uint256 internal constant PROGRESSIVE_CURVE = 3;

    function setUp() public override {
        super.setUp();
        DEFAULT_CURVE = getDefaultCurveId();
    }

    /// @dev H1: a single deposit→full-redeem round-trip can never be net-positive on
    ///      any curve. Entry/exit/protocol fees + ghost seeding guarantee out < in.
    function test_roundTripNeverProfits_defaultCurve() public {
        _assertNoProfit(DEFAULT_CURVE, 10 ether);
    }

    function test_roundTripNeverProfits_offsetProgressiveCurve() public {
        _assertNoProfit(OFFSET_PROGRESSIVE_CURVE, 10 ether);
    }

    function test_roundTripNeverProfits_progressiveCurve() public {
        _assertNoProfit(PROGRESSIVE_CURVE, 10 ether);
    }

    function testFuzz_roundTripNeverProfits(uint256 depositSeed, uint256 curveSeed) public {
        uint256 curveId = bound(curveSeed, 1, 3);
        uint256 deposit = bound(depositSeed, MIN_DEPOSIT * 2, 1000 ether);
        _assertNoProfit(curveId, deposit);
    }

    /// @dev H2/H3: pro-rata asset injection into an atom vault (via a large triple
    ///      deposit, which routes `atomDepositFractionForTriple` into the three
    ///      underlying atom vaults *without minting shares*) raises the share price.
    ///      A victim's subsequent minimum deposit must still mint > 0 shares — the
    ///      ghost `minShare` to BURN blocks the round-to-zero inflation grief.
    function test_proRataInjection_victimStillGetsNonZeroShares() public {
        (bytes32 tripleId, bytes32[] memory atomIds) =
            createTripleWithAtoms("t2-subj", "t2-pred", "t2-obj", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 subjectAtom = atomIds[0];

        // Attacker dumps a large deposit into the triple → injects assets pro-rata
        // into the subject/predicate/object atom vaults, inflating their price.
        resetPrank(users.bob);
        protocol.multiVault.deposit{ value: 500 ether }(users.bob, tripleId, DEFAULT_CURVE, 0);

        (uint256 assetsAfter, uint256 sharesAfter) = protocol.multiVault.getVault(subjectAtom, DEFAULT_CURVE);
        assertGt(assetsAfter, 0, "subject vault received injected assets");
        assertGt(sharesAfter, 0, "subject vault retains shares (ghost + creator)");

        // Victim deposits the protocol minimum into the now-inflated atom vault.
        uint256 victimShares = makeDeposit(users.charlie, users.charlie, subjectAtom, DEFAULT_CURVE, MIN_DEPOSIT, 0);

        assertGt(victimShares, 0, "victim still mints non-zero shares despite price inflation");
    }

    /// @dev H4: the on-behalf-of create path seeds ghost shares to BURN exactly like
    ///      the direct path — it does not sidestep first-depositor protection.
    function test_createAtomsFor_seedsGhostShares() public {
        // bob is approved by alice to create on her behalf, bob pays.
        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked("t2-on-behalf-ghost");
        uint256[] memory assets = new uint256[](1);
        assets[0] = ATOM_COST[0] + 1 ether;

        resetPrank(users.bob);
        bytes32[] memory ids = protocol.multiVault.createAtomsFor{ value: assets[0] }(users.alice, data, assets);
        bytes32 atomId = ids[0];

        assertEq(protocol.multiVault.getShares(BURN, atomId, DEFAULT_CURVE), MIN_SHARES, "BURN holds ghost minShare");
        // Shares were attributed to the creator (alice), not the payer (bob).
        assertGt(protocol.multiVault.getShares(users.alice, atomId, DEFAULT_CURVE), 0, "creator got shares");
        assertEq(protocol.multiVault.getShares(users.bob, atomId, DEFAULT_CURVE), 0, "payer got no shares");
    }

    /* =================================================== */
    /*                       HELPERS                       */
    /* =================================================== */

    function _assertNoProfit(uint256 curveId, uint256 deposit) internal {
        bytes32 atomId = createSimpleAtom(
            string.concat("t2-rt-", vm.toString(curveId), "-", vm.toString(deposit)), ATOM_COST[0], users.alice
        );

        uint256 balBefore = users.bob.balance;
        uint256 shares = makeDeposit(users.bob, users.bob, atomId, curveId, deposit, 0);
        assertGt(shares, 0, "deposit minted shares");

        redeemShares(users.bob, users.bob, atomId, curveId, shares, 0);
        uint256 balAfter = users.bob.balance;

        // Bob can never end with more native value than he started with.
        assertLe(balAfter, balBefore, "round-trip is not net-positive");
    }
}
