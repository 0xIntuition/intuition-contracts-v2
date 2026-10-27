// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";

/// @notice Scenario-level integration tests for the v1.1.0 counter-triple non-default-curve deposit
///         fix. The unit suite covers the surgical guard tightening and helper rename; this file
///         exercises the full lifecycle (create -> counter-first deposit -> positive-side join ->
///         multi-actor redeem) and verifies the symmetric bootstrap invariants end-to-end across
///         every registered non-default curve.
contract CounterTripleSymmetricBootstrapTest is BaseTest {
    uint256 internal DEFAULT_CURVE_ID;
    address internal BURN_ADDR;

    function setUp() public override {
        super.setUp();
        DEFAULT_CURVE_ID = getDefaultCurveId();
        BURN_ADDR = protocol.multiVault.BURN_ADDRESS();
    }

    /// @notice Full lifecycle scenario the fix unlocks:
    ///   1. Alice creates a positive triple on the default curve (seeds counter-default).
    ///   2. Bob deposits into the counter-triple on a non-default curve — previously blocked.
    ///      Opposite-side (positive) same-curve vault is seeded with min-shares to BURN_ADDRESS.
    ///   3. Charlie deposits into the positive-triple on the same non-default curve, against the
    ///      already-seeded vault.
    ///   4. Every party redeems their shares; the min-share seeds remain intact and unredeemable
    ///      by anyone other than BURN_ADDRESS.
    function test_scenario_CounterFirstBootstrap_FullLifecycle() public {
        uint256 nonDefaultCurve = _firstNonDefaultCurve();
        vm.assume(nonDefaultCurve != 0);

        (bytes32 tripleId,) =
            createTripleWithAtoms("scn-s", "scn-p", "scn-o", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        uint256 amount = 4 ether;

        // Phase 1 — Bob: counter-first on non-default curve.
        vm.deal(users.bob, amount);
        uint256 bobShares = makeDeposit(users.bob, users.bob, counterId, nonDefaultCurve, amount, 0);
        assertGt(bobShares, 0, "bob counter-first deposit must mint shares");
        _assertOppositeSeedExists(tripleId, nonDefaultCurve, minShare);

        // Phase 2 — Charlie: positive-side on the same non-default curve.
        vm.deal(users.charlie, amount);
        uint256 charlieShares = makeDeposit(users.charlie, users.charlie, tripleId, nonDefaultCurve, amount, 0);
        assertGt(charlieShares, 0, "charlie positive deposit on bootstrapped non-default must mint shares");

        // Counter-stake guard still blocks bob from also taking the positive side on the same curve.
        vm.deal(users.bob, amount);
        vm.expectRevert(MultiVault.MultiVault_HasCounterStake.selector);
        makeDeposit(users.bob, users.bob, tripleId, nonDefaultCurve, amount, 0);

        // Phase 3 — multi-actor redeem.
        uint256 bobAssets = redeemShares(users.bob, users.bob, counterId, nonDefaultCurve, bobShares, 0);
        uint256 charlieAssets = redeemShares(users.charlie, users.charlie, tripleId, nonDefaultCurve, charlieShares, 0);
        assertGt(bobAssets, 0, "bob redeem returns assets");
        assertGt(charlieAssets, 0, "charlie redeem returns assets");

        // Post-redeem invariants — both bootstrap seeds remain on BURN_ADDRESS.
        assertEq(
            protocol.multiVault.getShares(BURN_ADDR, tripleId, nonDefaultCurve),
            minShare,
            "positive non-default seed preserved post-redeem"
        );
        assertEq(
            protocol.multiVault.getShares(BURN_ADDR, counterId, nonDefaultCurve),
            minShare,
            "counter non-default seed preserved post-redeem"
        );
    }

    /// @notice Across every registered non-default curve, `previewDeposit` for the counter-first
    ///         path must agree with the actual shares minted by `deposit`. Pins lockstep behavior
    ///         between the execution-path and calc-path guard tightenings.
    function test_scenario_PreviewAndDepositAgreement_AcrossAllRegisteredCurves() public {
        (address registryAddr,) = protocol.multiVault.bondingCurveConfig();
        IBondingCurveRegistry reg = IBondingCurveRegistry(registryAddr);
        uint256 count = reg.count();
        // Sanity — the test environment must register more than just the default curve, otherwise
        // there is no non-default surface to iterate over and the test would silently pass.
        assertGt(count, 1, "test setup must register multiple curves");

        uint256 amount = 4 ether;
        uint256 covered;
        for (uint256 cid = 1; cid <= count; cid++) {
            if (cid == DEFAULT_CURVE_ID || reg.curveAddresses(cid) == address(0)) continue;
            _assertPreviewMatchesActual(cid, amount);
            covered++;
        }
        assertGt(covered, 0, "must cover at least one non-default curve");
    }

    function _assertPreviewMatchesActual(uint256 nonDefaultCurve, uint256 amount) internal {
        // A fresh triple per iteration so each curve sees a clean counter-first first-deposit.
        (bytes32 tripleId,) = createTripleWithAtoms(
            string.concat("preview-s-", _toString(nonDefaultCurve)),
            string.concat("preview-p-", _toString(nonDefaultCurve)),
            string.concat("preview-o-", _toString(nonDefaultCurve)),
            ATOM_COST[0],
            TRIPLE_COST[0],
            users.alice
        );
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        (uint256 previewShares,) = protocol.multiVault.previewDeposit(counterId, nonDefaultCurve, amount);

        vm.deal(users.bob, amount);
        uint256 actualShares = makeDeposit(users.bob, users.bob, counterId, nonDefaultCurve, amount, 0);

        assertEq(actualShares, previewShares, "previewDeposit must equal deposit for counter-first non-default");
    }

    function _assertOppositeSeedExists(bytes32 tripleId, uint256 nonDefaultCurve, uint256 minShare) internal view {
        (uint256 posTotalAssets, uint256 posTotalShares) = protocol.multiVault.getVault(tripleId, nonDefaultCurve);
        assertEq(posTotalShares, minShare, "positive non-default totalShares == minShare seed");
        assertGt(posTotalAssets, 0, "positive non-default totalAssets seeded with minAssetsForCurve(minShare)");
        assertEq(
            protocol.multiVault.getShares(BURN_ADDR, tripleId, nonDefaultCurve),
            minShare,
            "BURN_ADDRESS holds the positive-side seed"
        );
    }

    function _firstNonDefaultCurve() internal view returns (uint256) {
        (address registryAddr,) = protocol.multiVault.bondingCurveConfig();
        IBondingCurveRegistry reg = IBondingCurveRegistry(registryAddr);
        uint256 count = reg.count();
        for (uint256 cid = 1; cid <= count; cid++) {
            if (cid != DEFAULT_CURVE_ID && reg.curveAddresses(cid) != address(0)) return cid;
        }
        return 0;
    }

    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v;
        uint256 digits;
        while (tmp != 0) {
            digits++;
            tmp /= 10;
        }
        bytes memory buf = new bytes(digits);
        while (v != 0) {
            digits--;
            buf[digits] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(buf);
    }
}
