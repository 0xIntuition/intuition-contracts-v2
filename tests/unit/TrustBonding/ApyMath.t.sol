// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console } from "forge-std/src/Test.sol";

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/ApyMath.t.sol'
///
/// @notice Regression suite for the APY-math precision fix in `getSystemApy`
///         and `getUserApy`. Both views annualise per-epoch values via the
///         inline `* YEAR / epochLength` form rather than the truncating
///         `* _epochsPerYear()` helper. These tests pin:
///           (a) bit-for-bit analytical equivalence at the production
///               14-day epoch,
///           (b) strict ≥-relationship vs. the previous truncating
///               formulation (with the residual equal to the rounding
///               remainder), and
///           (c) preservation of the existing short-circuit behavior on
///               zero supply / zero rewards / zero lock.
contract ApyMathTest is TrustBondingBase {
    /// @dev Local mirror of `TrustBonding.YEAR` (365 days).
    uint256 internal constant YEAR_SECONDS = 365 days;

    /// @dev Local mirror of `TrustBonding.BASIS_POINTS_DIVISOR` (10_000).
    uint256 internal constant BASIS_POINTS = 10_000;

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, DEAL_AMOUNT * 10);
        vm.deal(users.bob, DEAL_AMOUNT * 10);
        _setupUserForTrustBonding(users.alice);
        _setupUserForTrustBonding(users.bob);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /* ============================================================ */
    /*                getSystemApy — analytical accuracy            */
    /* ============================================================ */

    function test_getSystemApy_maxApy_matchesAnalyticalFormula() external {
        _createLock(users.alice);
        _createLock(users.bob);

        uint256 currEpoch = protocol.trustBonding.currentEpoch();
        uint256 supply = protocol.trustBonding.totalBondedBalance();
        uint256 epochLength = protocol.trustBonding.epochLength();
        uint256 maxEmissions = protocol.satelliteEmissionsController.getEmissionsAtEpoch(currEpoch);

        // Mirror the contract's exact operator order: ((maxEmissions * YEAR / epochLength) * BASIS) / supply.
        uint256 expectedMaxApy = ((maxEmissions * YEAR_SECONDS / epochLength) * BASIS_POINTS) / supply;

        (, uint256 maxApy) = protocol.trustBonding.getSystemApy();
        assertEq(maxApy, expectedMaxApy, "maxApy must match the inline analytical formula");
    }

    function test_getSystemApy_maxApy_strictlyGteOldTruncatingFormula() external {
        _createLock(users.alice);
        _createLock(users.bob);

        uint256 currEpoch = protocol.trustBonding.currentEpoch();
        uint256 supply = protocol.trustBonding.totalBondedBalance();
        uint256 maxEmissions = protocol.satelliteEmissionsController.getEmissionsAtEpoch(currEpoch);

        // The old truncating shape: `* _epochsPerYear()` truncates YEAR/epochLength before the multiply.
        uint256 epochsPerYearTruncated = protocol.trustBonding.epochsPerYear();
        uint256 oldFormulaMaxApy = (maxEmissions * epochsPerYearTruncated * BASIS_POINTS) / supply;

        (, uint256 newMaxApy) = protocol.trustBonding.getSystemApy();

        // For 14-day epochs, YEAR/epochLength = 26.071... → old truncates to 26.
        // The fix must produce a value ≥ the old truncating result.
        assertGe(newMaxApy, oldFormulaMaxApy, "new formula must be >= old truncating formula");

        // For the production 14-day config the strict-greater branch is reachable
        // (truncation residual is non-zero); pin that here so a future epoch-length
        // change that happens to be a clean divisor doesn't silently regress the
        // intent of the test.
        assertGt(newMaxApy, oldFormulaMaxApy, "new formula must be strictly > old truncating formula for 14d epoch");
    }

    function test_getSystemApy_zeroSupply_returnsZero() external view {
        // No locks created in this test → totalBondedBalance == 0 → short-circuit.
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getSystemApy();
        assertEq(currentApy, 0);
        assertEq(maxApy, 0);
    }

    /* ============================================================ */
    /*                 getUserApy — analytical accuracy             */
    /* ============================================================ */

    function test_getUserApy_maxApy_matchesAnalyticalFormula_afterWarp() external {
        // userRewards is zero in the genesis epoch (no claim path is reachable),
        // so warp into epoch 1 where userEligibleRewardsForEpoch returns non-zero.
        _createLock(users.alice);
        _createLock(users.bob);

        _advanceEpochs(1);

        uint256 currEpoch = protocol.trustBonding.currentEpoch();
        assertEq(currEpoch, 1);

        uint256 epochLength = protocol.trustBonding.epochLength();
        uint256 userRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currEpoch);
        uint256 locked = uint256(uint128(int128(_getLockedAmount(users.alice))));

        // Mirror the contract's exact operator order:
        // userRewardsPerYear = userRewards * YEAR / epochLength
        // maxApy             = (userRewardsPerYear * BASIS) / locked
        uint256 expectedMaxApy = ((userRewards * YEAR_SECONDS / epochLength) * BASIS_POINTS) / locked;

        (, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);
        assertEq(maxApy, expectedMaxApy, "user maxApy must match the inline analytical formula");
    }

    function test_getUserApy_maxApy_strictlyGteOldTruncatingFormula_afterWarp() external {
        _createLock(users.alice);
        _createLock(users.bob);

        _advanceEpochs(1);

        uint256 currEpoch = protocol.trustBonding.currentEpoch();
        uint256 userRewards = protocol.trustBonding.userEligibleRewardsForEpoch(users.alice, currEpoch);
        uint256 locked = uint256(uint128(int128(_getLockedAmount(users.alice))));

        uint256 epochsPerYearTruncated = protocol.trustBonding.epochsPerYear();
        uint256 oldFormulaMaxApy = (userRewards * epochsPerYearTruncated * BASIS_POINTS) / locked;

        (, uint256 newMaxApy) = protocol.trustBonding.getUserApy(users.alice);

        assertGe(newMaxApy, oldFormulaMaxApy);
        assertGt(newMaxApy, oldFormulaMaxApy, "new formula must be strictly > old truncating formula for 14d epoch");
    }

    function test_getUserApy_zeroLocked_returnsZero() external view {
        // Alice has no lock — locked == 0 → short-circuit branch returns
        // (0, 0) before any APY math is attempted. This covers the
        // `locked <= 0` half of the `userRewards == 0 || locked <= 0` OR.
        (uint256 currentApy, uint256 maxApy) = protocol.trustBonding.getUserApy(users.alice);
        assertEq(currentApy, 0);
        assertEq(maxApy, 0);
    }

    /* ============================================================ */
    /*           Public epochsPerYear() — still truncates           */
    /* ============================================================ */

    function test_epochsPerYear_publicHelper_stillTruncates() external view {
        // The public getter is kept for backward compatibility and still
        // returns `floor(YEAR / epochLength)`. Pinning the behavior so a
        // future "let's also fix the helper" change doesn't silently break
        // existing consumers that depend on the truncated value.
        uint256 epochsPerYear = protocol.trustBonding.epochsPerYear();
        uint256 expected = YEAR_SECONDS / protocol.trustBonding.epochLength();
        assertEq(epochsPerYear, expected);
        // For the production 14-day config this is `26` (exact: 26.0714…).
        assertEq(epochsPerYear, 26);
    }

    /* ============================================================ */
    /*                       Overflow / fuzz                        */
    /* ============================================================ */

    function testFuzz_getSystemApy_noOverflow_undersaneSupply(uint256 lockMultiplier) external {
        // Bound to realistic TRUST orders of magnitude. With `initialTokens =
        // 10_000 ether`, multipliers up to 10 keep total supply within
        // ~100_000 ether — far below any overflow risk in the
        // `(emissions * YEAR / epochLength) * BASIS / supply` chain.
        lockMultiplier = bound(lockMultiplier, 1, 10);

        _createLock(users.alice, initialTokens * lockMultiplier);

        // Should not revert under any of the bounded supply values.
        protocol.trustBonding.getSystemApy();
    }

    function testFuzz_getUserApy_noOverflow_undersaneLock(uint256 lockMultiplier) external {
        lockMultiplier = bound(lockMultiplier, 1, 10);

        _createLock(users.alice, initialTokens * lockMultiplier);
        _advanceEpochs(1);

        protocol.trustBonding.getUserApy(users.alice);
    }

    /* ============================================================ */
    /*                            Helpers                           */
    /* ============================================================ */

    function _getLockedAmount(address user) internal view returns (int128) {
        (int128 amount,) = protocol.trustBonding.locked(user);
        return amount;
    }
}
