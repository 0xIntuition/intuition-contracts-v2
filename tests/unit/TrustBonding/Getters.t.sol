// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/Getters.t.sol'
contract TrustBondingGettersTest is TrustBondingBase {
    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, DEAL_AMOUNT);
        vm.deal(users.bob, DEAL_AMOUNT);
        vm.deal(users.charlie, DEAL_AMOUNT);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        _setupUserWrappedTokenAndTrustBonding(users.bob);
        _setupUserWrappedTokenAndTrustBonding(users.charlie);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }
}
