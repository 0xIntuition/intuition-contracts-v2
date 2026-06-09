// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

/// @title  Track 6 — TrustBonding reward / utilization-carry hunt (ENG-12460)
/// @notice Pins the utilization-ratio normalization against the suspected
///         zero-target division (a cleared false-positive) and proves the ratio is
///         always bounded and never reverts for any permissionless utilization
///         input. Double-claim / budget-cap / forfeit are already covered by
///         tests/unit/TrustBonding/ClaimRewards.t.sol; this file closes the
///         normalization-safety gap.
contract TrustBondingClaimTest is TrustBondingBase {
    /// @dev The branch order in `_getSystemUtilizationRatio`: when the previous
    ///      epoch had ZERO total claimed rewards (target == 0) and utilization grew
    ///      (delta > 0), the `delta >= target` check returns 100% BEFORE the
    ///      normalization division — so the division-by-zero is unreachable.
    function test_systemUtilizationRatio_zeroTarget_returns100_noRevert() public {
        _advanceToEpoch(3);
        uint256 epoch = 2;

        // Utilization grows across the measured window; previous-epoch claims stay 0.
        _setTotalUtilizationForEpoch(epoch - 1, 1000 ether);
        _setTotalUtilizationForEpoch(epoch, 1500 ether);
        // totalClaimedRewardsForEpoch[epoch-1] is 0 by default (the target).

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);
        assertEq(ratio, BASIS_POINTS_DIVISOR, "zero-target + positive delta -> 100%, no division");
    }

    /// @dev The normalization division is only reached when 0 < delta < target, which
    ///      forces target > 0. Sweep the input space and assert: never reverts, and
    ///      the result is always within [systemUtilizationLowerBound, 10000].
    function testFuzz_systemUtilizationRatio_alwaysBoundedNeverReverts(
        uint256 beforeSeed,
        uint256 afterSeed,
        uint256 targetSeed
    )
        public
    {
        _advanceToEpoch(3);
        uint256 epoch = 2;

        uint256 utilBefore = bound(beforeSeed, 0, 1_000_000 ether);
        uint256 utilAfter = bound(afterSeed, 0, 1_000_000 ether);
        uint256 target = bound(targetSeed, 0, 1_000_000 ether);

        _setTotalUtilizationForEpoch(epoch - 1, int256(utilBefore));
        _setTotalUtilizationForEpoch(epoch, int256(utilAfter));
        _setTotalClaimedRewardsForEpoch(epoch - 1, target);

        uint256 ratio = protocol.trustBonding.getSystemUtilizationRatio(epoch);

        uint256 lower = protocol.trustBonding.systemUtilizationLowerBound();
        assertGe(ratio, lower, "ratio >= lower bound");
        assertLe(ratio, BASIS_POINTS_DIVISOR, "ratio <= 100%");
    }

    /// @dev Personal ratio: when last-epoch claims are zero (target == 0), the two
    ///      explicit zero-target branches (100% if no prior eligibility, lower-bound
    ///      if eligible-but-unclaimed) both avoid the normalization division. The
    ///      call must not revert and must land on one of those two safe outcomes.
    function test_personalUtilizationRatio_zeroTarget_noDivByZero() public {
        _advanceToEpoch(3);
        uint256 epoch = 2;
        address user = users.alice;

        _setUserUtilizationForEpoch(user, epoch - 1, 100 ether);
        _setUserUtilizationForEpoch(user, epoch, 250 ether);
        // userClaimedRewardsForEpoch[user][epoch-1] == 0 (the target).

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(user, epoch);
        uint256 lower = protocol.trustBonding.personalUtilizationLowerBound();
        assertTrue(
            ratio == BASIS_POINTS_DIVISOR || ratio == lower,
            "zero-target -> safe branch (100% or lower bound), no division"
        );
    }

    /// @dev Personal ratio is likewise always bounded and revert-free across inputs.
    function testFuzz_personalUtilizationRatio_alwaysBoundedNeverReverts(
        uint256 beforeSeed,
        uint256 afterSeed,
        uint256 targetSeed
    )
        public
    {
        _advanceToEpoch(3);
        uint256 epoch = 2;
        address user = users.bob;

        _setUserUtilizationForEpoch(user, epoch - 1, int256(bound(beforeSeed, 0, 1_000_000 ether)));
        _setUserUtilizationForEpoch(user, epoch, int256(bound(afterSeed, 0, 1_000_000 ether)));
        _setUserClaimedRewardsForEpoch(user, epoch - 1, bound(targetSeed, 0, 1_000_000 ether));

        uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(user, epoch);
        assertLe(ratio, BASIS_POINTS_DIVISOR, "personal ratio <= 100%");
    }
}
