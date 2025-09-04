// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

abstract contract Constants {
    uint256 internal constant FEE = 0.001e18;
    uint40 internal constant JULY_1_2024 = 1_719_792_000;
    UD60x18 internal constant MAX_BROKER_FEE = UD60x18.wrap(0.1e18); // 10%
    uint128 internal constant MAX_UINT128 = type(uint128).max;
    uint256 internal constant MAX_UINT256 = type(uint256).max;
    uint40 internal constant MAX_UINT40 = type(uint40).max;
    uint40 internal constant MAX_UNIX_TIMESTAMP = 2_147_483_647; // 2^31 - 1

    // Max value
    uint128 internal constant UINT128_MAX = type(uint128).max;
    uint40 internal constant UINT40_MAX = type(uint40).max;

    uint128 internal constant TRANSFER_VALUE = 50_000;
    uint128 internal constant WITHDRAW_AMOUNT_18D = 500e18;
    uint128 internal constant WITHDRAW_AMOUNT_6D = 500e6;
}
