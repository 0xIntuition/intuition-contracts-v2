// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

contract PowTest is Test {
    using FixedPointMathLib for uint256;

    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    function testApplyingCliffReductions() external pure {
        uint256 baseEmissions = 1_000_000e18;
        uint256 retentionFactor = 9000; // 90%
        uint256 cliffsToApply = 13; // it fails with any value > 13
        uint256 adjustedEmissions = _applyCliffReductions(baseEmissions, retentionFactor, cliffsToApply);
        console2.log("Adjusted Emissions:", adjustedEmissions);
    }

    function testApplyingCliffReductionsOptimized() external pure {
        uint256 baseEmissions = 1_000_000e18;
        uint256 retentionFactor = 9000; // 90%
        uint256 cliffsToApply = 50;
        uint256 adjustedEmissions = _applyCliffReductionsOptimized(baseEmissions, retentionFactor, cliffsToApply);
        console2.log("Adjusted Emissions (Optimized):", adjustedEmissions);
    }

    function _pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        if (exponent == 0) {
            return 1;
        }

        uint256 result = 1;
        uint256 currentBase = base;

        // Use binary exponentiation for O(log n) complexity
        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = result * currentBase;
            }
            currentBase = currentBase * currentBase;
            exponent >>= 1; // Right shift by 1 (divide by 2)
        }

        return result;
    }

    function _applyCliffReductions(
        uint256 baseEmissions,
        uint256 retentionFactor,
        uint256 cliffsToApply
    )
        internal
        pure
        returns (uint256)
    {
        if (cliffsToApply == 0) {
            return baseEmissions;
        }

        // Apply compound reduction: emissions * (retentionFactor / 10000)^cliffs
        uint256 numerator = _pow(retentionFactor, cliffsToApply);
        uint256 denominator = _pow(BASIS_POINTS_DIVISOR, cliffsToApply);

        return (baseEmissions * numerator) / denominator;
    }

    function _applyCliffReductionsOptimized(
        uint256 baseEmissions,
        uint256 retentionFactorBps,
        uint256 cliffsToApply
    )
        internal
        pure
        returns (uint256)
    {
        if (cliffsToApply == 0) return baseEmissions;

        // Convert retentionFactor (e.g. 9000 bps) to WAD (1e18) ratio
        // rWad = retentionFactorBps / 10000
        uint256 rWad = (retentionFactorBps * 1e18) / BASIS_POINTS_DIVISOR;

        // factorWad = rWad^cliffs (scaled by 1e18), O(log n) unlike the naive O(n) approach used above
        uint256 factorWad = FixedPointMathLib.rpow(rWad, cliffsToApply, 1e18);

        // baseEmissions * factorWad / 1e18
        return FixedPointMathLib.mulWad(baseEmissions, factorWad);
    }
}
