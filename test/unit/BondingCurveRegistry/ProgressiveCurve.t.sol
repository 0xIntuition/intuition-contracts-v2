// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StringUtils} from "./StringUtils.sol";
import {CurveUtils} from "./CurveUtils.sol";
import {ProgressiveCurve} from "src/curves/ProgressiveCurve.sol";

contract ProgressiveCurveTest is Test {
    using StringUtils for uint256;

    ProgressiveCurve internal curve;

    // Standard test values
    uint256 constant SLOPE = 0.0025e18; // 25 basis points
    uint256 constant ERROR_MARGIN = 126; // 0.03% error margin

    function setUp() public {
        curve = new ProgressiveCurve("Test Progressive Curve", SLOPE);
    }

    function test_littleJumps() public {
        CurveUtils.testCurveActions(address(curve), 1e18, 10, ERROR_MARGIN, "Little Jumps (1 ETH x 10)");
    }

    function test_bigJump() public {
        CurveUtils.testCurveActions(address(curve), 10000e18, 1, ERROR_MARGIN, "Big Jump (10,000 ETH at once)");
    }

    function test_whaleSplash() public {
        CurveUtils.testCurveActions(address(curve), 1000000000e18, 1, ERROR_MARGIN, "Whale Splash (1B ETH at once)");
    }

    function test_pebbleToss() public {
        // This is going to have a higher error % because the amount is so small
        CurveUtils.testCurveActions(address(curve), 0.01e18, 1, ERROR_MARGIN * 10, "Pebble Toss (0.01 ETH)");
    }

    function test_hamburgerToss() public {
        CurveUtils.testCurveActions(address(curve), 1e18, 1, ERROR_MARGIN, "Hamburger Toss (1 ETH)");
    }
}
