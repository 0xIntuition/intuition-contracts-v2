// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { CoreEmissionsControllerMock } from "tests/mocks/CoreEmissionsControllerMock.sol";
import { EmissionsCheckpoint } from "src/interfaces/ICoreEmissionsController.sol";

abstract contract CoreEmissionsControllerBase is Test {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    CoreEmissionsControllerMock internal controller;

    // Test constants
    uint256 internal constant BASIS_POINTS_DIVISOR = 10_000;
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;
    uint256 internal constant MAX_CLIFF_REDUCTION_BASIS_POINTS = 1000; // 10%

    // Common test parameters
    uint256 internal constant DEFAULT_START_TIMESTAMP = 1;
    uint256 internal constant DEFAULT_EPOCH_LENGTH = 2 weeks;
    uint256 internal constant DEFAULT_EMISSIONS_PER_EPOCH = 1_000_000 * 1e18; // 1M tokens
    uint256 internal constant DEFAULT_REDUCTION_CLIFF = 26; // 26 epochs = ~1 year
    uint256 internal constant DEFAULT_REDUCTION_BASIS_POINTS = 1000; // 10%

    // Time constants for easier reading
    uint256 internal constant ONE_HOUR = 1 hours;
    uint256 internal constant ONE_DAY = 1 days;
    uint256 internal constant ONE_WEEK = 7 * ONE_DAY;
    uint256 internal constant TWO_WEEKS = 2 * ONE_WEEK;
    uint256 internal constant ONE_YEAR = 365 * ONE_DAY;
    uint256 internal constant TWO_YEARS = 2 * ONE_YEAR;

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public virtual {
        controller = new CoreEmissionsControllerMock();
        vm.warp(DEFAULT_START_TIMESTAMP);
    }

    /* =================================================== */
    /*                  HELPER FUNCTIONS                   */
    /* =================================================== */

    function _initializeController() internal {
        controller.initCoreEmissionsController(
            DEFAULT_START_TIMESTAMP,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_EMISSIONS_PER_EPOCH,
            DEFAULT_REDUCTION_CLIFF,
            DEFAULT_REDUCTION_BASIS_POINTS
        );
    }

    function _initializeControllerWithParams(
        uint256 startTimestamp,
        uint256 epochLength,
        uint256 emissionsPerEpoch,
        uint256 cliff,
        uint256 reductionBp
    )
        internal
    {
        controller.initCoreEmissionsController(startTimestamp, epochLength, emissionsPerEpoch, cliff, reductionBp);
    }

    function _warpToEpochStart(uint256 epoch) internal {
        uint256 timestamp = controller.getEpochTimestampStart(epoch);
        vm.warp(timestamp);
    }

    function _warpToEpochEnd(uint256 epoch) internal {
        uint256 endTimestamp = controller.getEpochTimestampEnd(epoch);
        vm.warp(endTimestamp - 1); // 1 second before end
    }

    function _warpByDuration(uint256 duration) internal {
        vm.warp(block.timestamp + duration);
    }
}
