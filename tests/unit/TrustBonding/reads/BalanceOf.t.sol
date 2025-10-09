// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/reads/BalanceOf.t.sol'

contract TrustBondingSystemApyTest is TrustBondingBase {
    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public override {
        super.setUp();
        vm.deal(users.alice, DEAL_AMOUNT * 10);
        _setupUserWrappedTokenAndTrustBonding(users.alice);
        vm.deal(address(protocol.satelliteEmissionsController), 10_000_000 ether);
    }

    /* =================================================== */
    /*                  BALANCE FUNCTIONS                  */
    /* =================================================== */
    function test_balanceOf_nolock() external view {
        uint256 balance = protocol.trustBonding.balanceOf(users.alice);
        assertEq(balance, 0);
    }

    function test_balanceOf_MINTIME() external {
        uint256 MINTIME = protocol.trustBonding.MINTIME();
        uint256 LOCK_DURATION = _calculateUnlockTime(MINTIME);
        _createLockWithDuration(users.alice, SMALL_DEPOSIT_AMOUNT, LOCK_DURATION);
        uint256 balanceNow = protocol.trustBonding.balanceOf(users.alice);
        assertEq(balanceNow, 287_671_074_326_259_282); // approx 0.2877 TRUST
        uint256 balanceAtOneWeek = protocol.trustBonding.balanceOfAtT(users.alice, block.timestamp + ONE_WEEK);
        assertEq(balanceAtOneWeek, 191_780_663_367_852_882); // approx 0.1918 TRUST

        uint256 totalSupply = protocol.trustBonding.totalSupply();
        assertEq(totalSupply, 287_671_074_326_259_282); // approx 0.2877 TRUST
    }

    function test_balanceOf_ONE_YEAR() external {
        uint256 LOCK_DURATION = _calculateUnlockTime(ONE_YEAR);
        _createLockWithDuration(users.alice, SMALL_DEPOSIT_AMOUNT, LOCK_DURATION);
        uint256 balanceNow = protocol.trustBonding.balanceOf(users.alice);
        assertEq(balanceNow, 4_986_301_211_288_172_882); // approx 4.9863 TRUST
        uint256 balanceAtSixMonths = protocol.trustBonding.balanceOfAtT(users.alice, block.timestamp + (ONE_YEAR / 2));
        assertEq(balanceAtSixMonths, 2_486_301_211_301_148_882); // approx 2.4863 TRUST
    }

    function test_balanceOf_MAXTIME() external {
        uint256 MAXTIME = protocol.trustBonding.MAXTIME();
        uint256 LOCK_DURATION = _calculateUnlockTime(MAXTIME);
        _createLockWithDuration(users.alice, SMALL_DEPOSIT_AMOUNT, LOCK_DURATION);
        uint256 balance = protocol.trustBonding.balanceOf(users.alice);
        assertEq(balance, 9_972_602_581_125_305_682); // approx 9.9726 TRUST
        uint256 balanceAtOneYear = protocol.trustBonding.balanceOfAtT(users.alice, block.timestamp + ONE_YEAR);
        assertEq(balanceAtOneYear, 4_972_602_581_151_257_682); // approx 4.9726 TRUST

        uint256 totalSupply = protocol.trustBonding.totalSupply();
        assertEq(totalSupply, 9_972_602_581_125_305_682); // approx 9.9726 TRUST
    }
}
