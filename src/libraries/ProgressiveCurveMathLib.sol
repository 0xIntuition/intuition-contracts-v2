// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { UD60x18, wrap, unwrap, uUNIT, mul } from "@prb/math/src/UD60x18.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

/**
 * @title  ProgressiveCurveMathLib
 * @author 0xIntuition
 * @notice A library for performing precise arithmetic operations on UD60x18 numbers,
 *         specifically tailored for progressive curve calculations.
 */
library ProgressiveCurveMathLib {
    /// @dev Multiplies two UD60x18 numbers, rounding up.
    function mulUp(UD60x18 x, UD60x18 y) internal pure returns (UD60x18) {
        return wrap(FixedPointMathLib.fullMulDivUp(unwrap(x), unwrap(y), uUNIT));
    }

    /// @dev Divides two UD60x18 numbers, rounding up.
    function divUp(UD60x18 x, UD60x18 y) internal pure returns (UD60x18) {
        return wrap(FixedPointMathLib.fullMulDivUp(unwrap(x), uUNIT, unwrap(y)));
    }

    /// @dev Squares a UD60x18 number, rounding down.
    function square(UD60x18 x) internal pure returns (UD60x18) {
        return mul(x, x);
    }

    /// @dev Squares a UD60x18 number, rounding up.
    function squareUp(UD60x18 x) internal pure returns (UD60x18) {
        return mulUp(x, x);
    }
}
