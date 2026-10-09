// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @notice The schedule `DynamicFeeFlatPriceCurve` deploys with, as data. Kept apart from the deploy
///         script so the test suite can pin the shipped values and validate them against the curve
///         without constructing the script (whose base reads deployer keys from the environment).
/// @dev    Every field is owner-settable post-deploy through `setConfig`; the ladder geometry
///         (`width0`, `tierWidthGrowthBps`, `tierCount`) should not change once positions exist. The
///         reasoning behind each value is on the deploy script's `_defaultConfig`.
library DynamicFeeLaunchSchedule {
    function config() internal pure returns (DynamicFeeConfig memory) {
        return DynamicFeeConfig({
            width0: 2000e18,
            tierCount: 16,
            tierWidthGrowthBps: 3500,
            depositBaseBps: 100,
            depositGrowthBps: 45,
            depositCapBps: 550,
            depositFulcrumAlphaBps: 5000,
            depositKernelSpread: 6e18,
            redeemFulcrumAlphaBps: 5000,
            redeemKernelSpread: 6e18,
            redeemBaseBps: 150,
            redeemGrowthBps: 35,
            redeemCapBps: 450,
            redeemToFulcrumTiersBps: 7500,
            depositToPriorTierBps: 1000,
            minEligibleTierStakeBps: 0
        });
    }
}
