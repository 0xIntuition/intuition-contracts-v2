// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

/// @title  DynamicFeeGasProfileTest
/// @notice Gas profile for the flat-price dynamic-fee curve paths: the marginal overhead the
///         dynamic-fee curve adds to a steady-state deposit and redeem (vs the same operation on the
///         default curve), and how `claim` scales with the number of vaults settled (10/20/50).
///         The measured numbers are logged for the profiling report; the assertions pin loose
///         upper bounds so a future regression that blows up the hot path fails loudly here.
contract DynamicFeeGasProfileTest is BaseTest {
    uint256 internal constant DEFAULT_CURVE_ID = 1;

    /// @dev Loose ceilings: steady-state ops and the dynamic-fee overhead on top of them.
    uint256 internal constant MAX_DEPOSIT_OVERHEAD = 200_000;
    uint256 internal constant MAX_REDEEM_OVERHEAD = 200_000;
    uint256 internal constant MAX_CLAIM_PER_TERM = 30_000;

    /// @dev A deposit that sweeps the WHOLE ladder is a different cost class from a steady-state one
    ///      and gets its own ceiling rather than loosening the one above. The hook replays the deposit
    ///      band by band — one fee distribution and one position move each — so the work is
    ///      O(bands x span), dominated by `sum(k) for k in 1..bands` accumulator writes.
    ///
    ///      Measured: ~232k overhead sweeping this suite's 5-tier ladder, and ~887k for the whole
    ///      `recordDeposit` on a 13-tier ladder (see
    ///      {DynamicFeeThirteenTierExampleTest.test_thirteenTier_fullLadderSweepGas}). Both are far
    ///      inside a block, and the depositor pays in full — there is no path by which the cost of
    ///      one account's ladder sweep can be imposed on anyone else. This ceiling is set to catch a
    ///      regression in KIND (a replay that becomes quadratic in something other than tier count),
    ///      not to pin the constant.
    uint256 internal constant MAX_FULL_LADDER_DEPOSIT_OVERHEAD = 400_000;

    /// @dev Absolute ceilings for the NON-hook (default-curve) steady-state path. Optimized builds
    ///      measure ~89k deposit / ~87k redeem with the generic fee-hook dispatch in place (the
    ///      per-operation registry resolution + hook-getter staticcalls cost ~5k on deposit and
    ///      ~7.5k on redeem vs the pre-hook baseline); `forge coverage` builds run unoptimized and
    ///      measure ~125k, so the ceiling clears both while still failing loudly on a regression
    ///      that materially blows up the hookless hot path (e.g. extra per-op external calls).
    uint256 internal constant MAX_DEFAULT_DEPOSIT_GAS = 150_000;
    uint256 internal constant MAX_DEFAULT_REDEEM_GAS = 150_000;

    /* =================================================== */
    /*                      HELPERS                        */
    /* =================================================== */

    function _measuredDeposit(address user, bytes32 termId, uint256 curveId, uint256 amount)
        internal
        returns (uint256 gasUsed)
    {
        resetPrank(user);
        uint256 gasBefore = gasleft();
        protocol.multiVault.deposit{ value: amount }(user, termId, curveId, 0);
        gasUsed = gasBefore - gasleft();
    }

    function _measuredRedeem(address user, bytes32 termId, uint256 curveId, uint256 shares)
        internal
        returns (uint256 gasUsed)
    {
        resetPrank(user);
        uint256 gasBefore = gasleft();
        protocol.multiVault.redeem(user, termId, curveId, shares, 0);
        gasUsed = gasBefore - gasleft();
    }

    /// @dev Builds `count` vaults in which alice has claimable dynamic-fee earnings: alice enters
    ///      each vault at tier 0 and pushes it into tier 1; bob then deposits from tier 1, whose
    ///      fee pays the recent prior tier (tier 0 = alice).
    function _earnAcrossVaults(uint256 count) internal returns (bytes32[] memory termIds) {
        termIds = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 atomId = createSimpleAtom(
                string.concat("gas-claim-", vm.toString(count), "-", vm.toString(i)), ATOM_COST[0], users.alice
            );
            termIds[i] = atomId;
            makeDeposit(users.alice, users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 6e18, 0);
            makeDeposit(users.bob, users.bob, atomId, DYNAMIC_FEE_CURVE_ID, 6e18, 0);
            assertGt(dynamicFeeCurve.claimable(users.alice, atomId), 0, "alice must have earnings per vault");
        }
    }

    function _measuredClaim(uint256 count) internal returns (uint256 gasUsed, uint256 claimed) {
        bytes32[] memory termIds = _earnAcrossVaults(count);
        resetPrank(users.alice);
        uint256 gasBefore = gasleft();
        claimed = dynamicFeeCurve.claim(termIds);
        gasUsed = gasBefore - gasleft();
        assertGt(claimed, 0, "claim must pay out");
    }

    /* =================================================== */
    /*                 DEPOSIT / REDEEM                    */
    /* =================================================== */

    function test_gasProfile_deposit_dynamicOverheadVsDefault() external {
        bytes32 atomId = createSimpleAtom("gas-deposit", ATOM_COST[0], users.alice);

        // Prime both vaults so the measured deposits hit the steady-state (warm-vault) path.
        makeDeposit(users.alice, users.alice, atomId, DEFAULT_CURVE_ID, 2e18, 0);
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 2e18, 0);

        uint256 gasDefault = _measuredDeposit(users.alice, atomId, DEFAULT_CURVE_ID, 3e18);
        uint256 gasDynamic = _measuredDeposit(users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 3e18);

        console2.log("deposit gas (default curve):        ", gasDefault);
        console2.log("deposit gas (dynamic-fee curve):    ", gasDynamic);
        console2.log("deposit dynamic-fee overhead:       ", gasDynamic - gasDefault);

        assertLt(gasDefault, MAX_DEFAULT_DEPOSIT_GAS, "hookless deposit absolute ceiling");
        assertLt(gasDynamic - gasDefault, MAX_DEPOSIT_OVERHEAD, "dynamic-fee deposit overhead ceiling");
    }

    /// @dev Worst case for the per-band deposit replay: a single deposit that crosses the WHOLE
    ///      ladder, so the hook runs one fee distribution and one position move per band instead of
    ///      one for the transaction. The work is O(bands x span), bounded by `tierCount`, and the
    ///      depositor pays it — nobody else can be made to. Recorded here so the cost of crossing the
    ///      ladder is a measured number rather than an assumption.
    function test_gasProfile_deposit_fullLadderCrossing() external {
        bytes32 atomId = createSimpleAtom("gas-deposit-ladder", ATOM_COST[0], users.alice);

        // Populate the low tiers so every band the sweep crosses has a real cohort to credit, which
        // is what makes each band's distribution do its full amount of work.
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 3e18, 0);
        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_FEE_CURVE_ID, 5e18, 0);
        makeDeposit(users.charlie, users.charlie, atomId, DYNAMIC_FEE_CURVE_ID, 8e18, 0);

        makeDeposit(users.alice, users.alice, atomId, DEFAULT_CURVE_ID, 3e18, 0);

        // The BaseTest ladder tops out at 26.84e18, so 60e18 sweeps every remaining band.
        uint256 gasDefault = _measuredDeposit(users.alice, atomId, DEFAULT_CURVE_ID, 60e18);
        uint256 gasDynamic = _measuredDeposit(users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 60e18);

        console2.log("full-ladder deposit gas (default):  ", gasDefault);
        console2.log("full-ladder deposit gas (dynamic):  ", gasDynamic);
        console2.log("full-ladder dynamic-fee overhead:   ", gasDynamic - gasDefault);
        console2.log("bands crossed (depositor userTier): ", dynamicFeeCurve.userTier(atomId, users.alice));

        assertLt(gasDynamic - gasDefault, MAX_FULL_LADDER_DEPOSIT_OVERHEAD, "full-ladder deposit overhead ceiling");
    }

    function test_gasProfile_redeem_dynamicOverheadVsDefault() external {
        bytes32 atomId = createSimpleAtom("gas-redeem", ATOM_COST[0], users.alice);

        makeDeposit(users.alice, users.alice, atomId, DEFAULT_CURVE_ID, 6e18, 0);
        makeDeposit(users.alice, users.alice, atomId, DYNAMIC_FEE_CURVE_ID, 6e18, 0);
        // A second holder keeps the exiting tier populated so the redeem hook takes its real path.
        makeDeposit(users.bob, users.bob, atomId, DYNAMIC_FEE_CURVE_ID, 6e18, 0);

        uint256 sharesDefault = protocol.multiVault.getShares(users.alice, atomId, DEFAULT_CURVE_ID);
        uint256 sharesDynamic = protocol.multiVault.getShares(users.alice, atomId, DYNAMIC_FEE_CURVE_ID);

        uint256 gasDefault = _measuredRedeem(users.alice, atomId, DEFAULT_CURVE_ID, sharesDefault / 2);
        uint256 gasDynamic = _measuredRedeem(users.alice, atomId, DYNAMIC_FEE_CURVE_ID, sharesDynamic / 2);

        console2.log("redeem gas (default curve):         ", gasDefault);
        console2.log("redeem gas (dynamic-fee curve):     ", gasDynamic);
        console2.log("redeem dynamic-fee overhead:        ", gasDynamic - gasDefault);

        assertLt(gasDefault, MAX_DEFAULT_REDEEM_GAS, "hookless redeem absolute ceiling");
        assertLt(gasDynamic - gasDefault, MAX_REDEEM_OVERHEAD, "dynamic-fee redeem overhead ceiling");
    }

    /* =================================================== */
    /*                   CLAIM SCALING                     */
    /* =================================================== */

    function test_gasProfile_claim_10Terms() external {
        (uint256 gasUsed,) = _measuredClaim(10);
        console2.log("claim gas (10 terms):               ", gasUsed);
        assertLt(gasUsed, 10 * MAX_CLAIM_PER_TERM + 60_000, "claim(10) ceiling");
    }

    function test_gasProfile_claim_20Terms() external {
        (uint256 gasUsed,) = _measuredClaim(20);
        console2.log("claim gas (20 terms):               ", gasUsed);
        assertLt(gasUsed, 20 * MAX_CLAIM_PER_TERM + 60_000, "claim(20) ceiling");
    }

    function test_gasProfile_claim_50Terms() external {
        (uint256 gasUsed,) = _measuredClaim(50);
        console2.log("claim gas (50 terms):               ", gasUsed);
        assertLt(gasUsed, 50 * MAX_CLAIM_PER_TERM + 60_000, "claim(50) ceiling");
    }

    /// @dev The per-term marginal cost of settling one more vault inside `claim`, derived from the
    ///      10-vs-50 spread. This is the number that decides whether pagination is ever needed:
    ///      callers can already chunk `termIds` freely (earnings are cross-vault and claimable
    ///      incrementally), so a bounded marginal cost means chunking IS the pagination.
    function test_gasProfile_claim_marginalPerTermIsBounded() external {
        (uint256 gas10,) = _measuredClaim(10);
        (uint256 gas50,) = _measuredClaim(50);

        uint256 marginalPerTerm = (gas50 - gas10) / 40;
        console2.log("claim marginal gas per extra term:  ", marginalPerTerm);

        assertLt(marginalPerTerm, MAX_CLAIM_PER_TERM, "marginal settle cost per term ceiling");
    }
}
