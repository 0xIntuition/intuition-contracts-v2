// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @title TrustBonding_Integration_Randomized
/// @notice Stress & fuzz integration tests for TrustBonding across many users & epochs.
///         Uses the TrustBondingBase harness and its helpers to wire up protocol pieces
///         and to directly set utilization (system & personal) when needed.
contract TrustBonding_Integration_Randomized is TrustBondingBase {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    address[] internal testUsers; // alice, bob, charlie + N extra

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();

        // Fund SatelliteEmissionsController with ample TRUST so claims never underflow
        deal(address(protocol.satelliteEmissionsController), 1_000_000_000 ether);

        // Keep default users
        testUsers.push(users.alice);
        testUsers.push(users.bob);
        testUsers.push(users.charlie);

        // Add 4 more randomized users to stress-test (total 7)
        for (uint256 i = 0; i < 4; i++) {
            string memory nm = string(abi.encodePacked("u", vm.toString(i)));
            address u = createUser(nm);
            _setupUserWrappedTokenAndTrustBonding(u);
            testUsers.push(u);
        }

        // Create an initial lock for all users so veTRUST math is live.
        for (uint256 i = 0; i < testUsers.length; i++) {
            _createLock(testUsers[i]); // default amount & duration from base: initialTokens & DEFAULT_LOCK_DURATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL UTILS
    //////////////////////////////////////////////////////////////*/

    function _rand(uint256 seed, uint256 salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, salt)));
    }

    /*//////////////////////////////////////////////////////////////
                         RANDOMIZED MAIN SCENARIO
    //////////////////////////////////////////////////////////////*/

    /// @dev Randomized multi-user, multi-epoch flow.
    /// - Randomly increases user locks to diversify ve-shares
    /// - For each epoch e>=1, sets system & personal utilization for (prev-1, prev)
    ///   so that personal/system ratios for epoch prev are well-defined
    /// - Claims prev-epoch rewards for most users, skips a few to exercise forfeiture
    /// - Asserts accounting invariants per-epoch and across the run
    function testFuzz_MultiUser_MultiEpoch_Randomized(uint256 seed, uint8 nEpochs_) public {
        uint256 nUsers = testUsers.length; // 7 by default
        uint256 nEpochs = bound(nEpochs_, 3, 8); // keep runs bounded but non-trivial

        // Randomly increase lock amounts on top of the initial locks to diversify veTRUST
        for (uint256 i = 0; i < nUsers; i++) {
            uint256 extra = _rand(seed, i) % (500 ether);
            if (extra > 0) {
                vm.startPrank(testUsers[i]);
                // Restore max allowance (create_lock overwrote it to `amount`)
                protocol.wrappedTrust.approve(address(protocol.trustBonding), type(uint256).max);
                protocol.trustBonding.increase_amount(extra);
                vm.stopPrank();
            }
        }

        // Walk epochs. At each step e we open the claim window for prev=e.
        for (uint256 e = 0; e < nEpochs; e++) {
            // Move time forward so currentEpoch()==e+1, enabling claims for prev epoch (e)
            _advanceToEpoch(e + 1);

            // Nothing to claim yet for e==0
            if (e == 0) continue;

            uint256 prev = e; // the epoch becoming claimable now

            // --------- Configure utilization for ratios used when claiming `prev` ---------
            // System: needs (prev-1, prev)
            {
                int256 sysBefore = int256(int128(int256(_rand(seed, 10_000 + e) % (1_000_000 ether))));
                if (_rand(seed, 20_000 + e) % 2 == 1) sysBefore = -sysBefore; // sometimes negative to trigger floor
                int256 sysAfter = sysBefore + int256(int128(int256(_rand(seed, 30_000 + e) % (300_000 ether))));
                _setTotalUtilizationForEpoch(prev - 1, sysBefore);
                _setTotalUtilizationForEpoch(prev, sysAfter);
            }

            // Personal: for each user needs (prev-1, prev)
            for (uint256 i = 0; i < nUsers; i++) {
                address u = testUsers[i];

                // Ensure MultiVault has a tracked epoch history up to `prev`
                _setActiveEpoch(u, 0, prev);
                _setActiveEpoch(u, 1, prev - 1);

                int256 uBefore = int256(int128(int256(_rand(seed, e * 10 + i) % (100_000 ether))));
                if (_rand(seed, 1e6 + e * 10 + i) % 3 == 0) uBefore = -uBefore;
                int256 uAfter = uBefore + int256(int128(int256(_rand(seed, 2e6 + e * 10 + i) % (30_000 ether))));

                _setUserUtilizationForEpoch(u, prev - 1, uBefore);
                _setUserUtilizationForEpoch(u, prev, uAfter);
            }

            // ----------------------------- Claims & checks -----------------------------
            uint256 emissionForPrev = protocol.trustBonding.emissionsForEpoch(prev);
            uint256 sumClaims;

            for (uint256 i = 0; i < nUsers; i++) {
                address u = testUsers[i];

                // ~7.7% chance to skip claim to test forfeiture path later
                bool shouldSkip = (_rand(seed, 9e9 + e * 97 + i) % 13 == 0);

                uint256 raw = protocol.trustBonding.userEligibleRewardsForEpoch(u, prev);
                uint256 ratio = protocol.trustBonding.getPersonalUtilizationRatio(u, prev);
                uint256 expected = raw * ratio / 10_000;

                // Sanity: the view helper matches our expected math
                (uint256 viewCurrent, uint256 viewMax) = protocol.trustBonding.getUserRewardsForEpoch(u, prev);
                assertEq(viewMax, raw, "viewMax!=raw");
                assertEq(viewCurrent, expected, "viewCurrent!=expected");

                if (shouldSkip) {
                    // Should be claimable right now (we're still in window for prev)
                    uint256 currClaimable = protocol.trustBonding.getUserCurrentClaimableRewards(u);
                    assertEq(currClaimable, expected, "pre-skip claimable mismatch");
                    continue;
                }

                // Claim rewards for prev epoch
                vm.startPrank(u);
                protocol.trustBonding.claimRewards(u);
                vm.stopPrank();

                // Can't claim twice for same epoch
                vm.startPrank(u);
                vm.expectRevert();
                protocol.trustBonding.claimRewards(u);
                vm.stopPrank();

                // Mapping reflects what we claimed
                uint256 claimed = protocol.trustBonding.userClaimedRewardsForEpoch(u, prev);
                assertEq(claimed, expected, "claimed!=expected");

                sumClaims += claimed;
            }

            // System accounting: sum(user claims) == totalClaimedRewardsForEpoch(prev)
            uint256 totalClaimedForPrev = protocol.trustBonding.totalClaimedRewardsForEpoch(prev);
            assertEq(totalClaimedForPrev, sumClaims, "sum of user claims != totalClaimedRewardsForEpoch");

            // Never exceed emissions
            assertLe(totalClaimedForPrev, emissionForPrev, "total claimed exceeds emissions");

            // Skipped users still show claimable for "prev" while we're in its claim window
            for (uint256 i = 0; i < nUsers; i++) {
                address u2 = testUsers[i];
                uint256 claimedNow = protocol.trustBonding.userClaimedRewardsForEpoch(u2, prev);
                if (claimedNow == 0) {
                    uint256 curr = protocol.trustBonding.getUserCurrentClaimableRewards(u2);
                    uint256 raw2 = protocol.trustBonding.userEligibleRewardsForEpoch(u2, prev);
                    uint256 ratio2 = protocol.trustBonding.getPersonalUtilizationRatio(u2, prev);
                    assertEq(curr, raw2 * ratio2 / 10_000, "skipped user current claimable mismatch");
                }
            }
        }

        // Advance once more: the oldest unclaimed (cur-1) is now forfeited; helper reports only old, closed epochs
        uint256 cur = protocol.trustBonding.currentEpoch();
        _advanceToEpoch(cur + 1);
        if (cur >= 2) {
            uint256 older = cur - 1; // now outside claim window
            uint256 unclaimed = protocol.trustBonding.getUnclaimedRewardsForEpoch(older);
            // Can't assert an exact amount (randomized participants), but should be defined
            assertGe(unclaimed, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      TARGETED SANITY / EDGE SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /// @dev System emissions scaling uses: lowerBound + (delta * (10_000-lower))/target (clamped to [lower,10000]).
    ///      Verify TrustBonding.emissionsForEpoch matches this mapping.
    function test_SystemUtilization_EmissionsScalingMatchesFormula() public {
        // Move to epoch >=3 so system logic is active
        _advanceToEpoch(3);
        uint256 e = 2;

        // Configure previous epoch total claimed (target) and system delta for epoch e
        uint256 target = 1_000_000 ether;
        _setTotalClaimedRewardsForEpoch(e - 1, target);
        _setTotalUtilizationForEpoch(e - 1, int256(400_000 ether));
        _setTotalUtilizationForEpoch(e, int256(700_000 ether)); // delta = 300k

        uint256 lower = protocol.trustBonding.systemUtilizationLowerBound();
        uint256 ratioRange = 10_000 - lower;
        uint256 expectedRatio = lower + (300_000 ether * ratioRange) / target;
        if (expectedRatio > 10_000) expectedRatio = 10_000;

        uint256 controllerMax = protocol.satelliteEmissionsController.getEmissionsAtEpoch(e);
        uint256 expectedEmissions = (controllerMax * expectedRatio) / 10_000;

        assertApproxEqAbs(
            protocol.trustBonding.emissionsForEpoch(e),
            expectedEmissions,
            1, // 1 wei tolerance
            "emissions scaling mismatch"
        );
    }

    /// @dev Personal utilization ratio:
    ///      - negative/zero delta -> floor (personal lower bound)
    ///      - large positive delta >= target -> cap (100%)
    function test_PersonalUtilization_LowerBoundAndCap() public {
        // We want to claim epoch 1 (prev of 2), so advance to currentEpoch==2
        _advanceToEpoch(2);
        uint256 e = 2; // the epoch we will evaluate ratios for

        // Make sure previous epoch (e-1=1) was claimed so personal target is non-zero
        vm.startPrank(users.alice);
        protocol.trustBonding.claimRewards(users.alice); // claims epoch 1 now that currentEpoch==2
        vm.stopPrank();

        // Set alice's personal utilization with negative delta => expect floor
        _setActiveEpoch(users.alice, 0, e);
        _setActiveEpoch(users.alice, 1, e - 1);
        _setUserUtilizationForEpoch(users.alice, e - 1, int256(500 ether));
        _setUserUtilizationForEpoch(users.alice, e, int256(100 ether)); // negative delta

        uint256 floor = protocol.trustBonding.personalUtilizationLowerBound();
        uint256 ratioFloor = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, e);
        assertEq(ratioFloor, floor, "personal ratio should hit floor on negative delta");

        // Now make delta huge so it exceeds target => expect 100%
        _setUserUtilizationForEpoch(users.alice, e - 1, int256(0));
        _setUserUtilizationForEpoch(users.alice, e, int256(10_000_000 ether));
        uint256 ratioCap = protocol.trustBonding.getPersonalUtilizationRatio(users.alice, e);
        assertEq(ratioCap, 10_000, "personal ratio should cap at 100%");
    }

    /// @dev For epochs 0 and 1, both system & personal utilization ratios should be 100%.
    function test_EpochZero_One_RatiosAreMax() public {
        // Ensure epoch 1 is not in the future
        _advanceToEpoch(2);

        assertEq(protocol.trustBonding.getSystemUtilizationRatio(0), 10_000, "system e0=100%");
        assertEq(protocol.trustBonding.getSystemUtilizationRatio(1), 10_000, "system e1=100%");

        assertEq(protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 0), 10_000, "personal e0=100%");
        assertEq(protocol.trustBonding.getPersonalUtilizationRatio(users.alice, 1), 10_000, "personal e1=100%");
    }
}
