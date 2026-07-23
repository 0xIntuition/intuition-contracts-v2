// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

/// @dev forge test --match-path 'tests/unit/TrustBonding/PausableVotingEscrow.t.sol'
///
/// Pause policy under test:
/// - Bonding entry points (`deposit_for`, `create_lock`, `increase_amount`,
///   `increase_unlock_time`, `increase_amount_and_time`, `withdraw_and_create_lock`)
///   revert with `EnforcedPause` while the contract is paused and work again after unpause.
/// - `withdraw` and `checkpoint` deliberately remain callable while paused; the
///   policy-pinning tests below enforce that decision so it cannot regress silently.
contract PausableVotingEscrowTest is TrustBondingBase {
    uint256 internal constant SHORT_LOCK_DURATION = 26 weeks;

    function _pause() internal {
        vm.startPrank(users.admin);
        protocol.trustBonding.pause();
        vm.stopPrank();
    }

    function _unpause() internal {
        vm.startPrank(users.admin);
        protocol.trustBonding.unpause();
        vm.stopPrank();
    }

    function _lockedAmount(address user) internal view returns (uint256) {
        (int128 amount,) = protocol.trustBonding.locked(user);
        return uint256(int256(amount));
    }

    function _lockedEnd(address user) internal view returns (uint256) {
        (, uint256 end) = protocol.trustBonding.locked(user);
        return end;
    }

    /*//////////////////////////////////////////////////////////////
                        GATED: deposit_for
    //////////////////////////////////////////////////////////////*/

    function test_deposit_for_revertsWhenPaused() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.deposit_for(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_deposit_for_revertsWhenPaused_thirdPartyDepositor() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        // The gate must also stop third parties depositing on behalf of a lock holder
        vm.startPrank(users.bob);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.deposit_for(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_deposit_for_succeedsAfterUnpause() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();
        _unpause();

        uint256 supplyBefore = protocol.trustBonding.supply();

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT);
        protocol.trustBonding.deposit_for(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT * 2, "locked amount should double");
        assertEq(protocol.trustBonding.supply(), supplyBefore + DEFAULT_DEPOSIT_AMOUNT, "supply should increase");
    }

    function testFuzz_deposit_for_revertsWhenPaused(uint256 amount) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.deposit_for(users.alice, amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        GATED: create_lock
    //////////////////////////////////////////////////////////////*/

    function test_create_lock_revertsWhenPaused() external {
        _pause();

        uint256 unlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.create_lock(DEFAULT_DEPOSIT_AMOUNT, unlockTime);
        vm.stopPrank();
    }

    function test_create_lock_succeedsAfterUnpause() external {
        _pause();
        _unpause();

        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT, "lock should be created after unpause");
        assertEq(protocol.trustBonding.supply(), DEFAULT_DEPOSIT_AMOUNT, "supply should reflect the new lock");
        assertGt(protocol.trustBonding.balanceOf(users.alice), 0, "veTRUST balance should be non-zero");
    }

    function testFuzz_create_lock_revertsWhenPaused(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        duration = bound(duration, TRUST_BONDING_EPOCH_LENGTH + ONE_WEEK, DEFAULT_LOCK_DURATION);
        _pause();

        uint256 unlockTime = _calculateUnlockTime(duration);

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function testFuzz_create_lock_succeedsAfterUnpause(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        duration = bound(duration, TRUST_BONDING_EPOCH_LENGTH + ONE_WEEK, DEFAULT_LOCK_DURATION);
        _pause();
        _unpause();

        uint256 unlockTime = _calculateUnlockTime(duration);

        vm.startPrank(users.alice);
        protocol.trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), amount, "lock should be created after unpause");
    }

    /*//////////////////////////////////////////////////////////////
                        GATED: increase_amount
    //////////////////////////////////////////////////////////////*/

    function test_increase_amount_revertsWhenPaused() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_amount(DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_increase_amount_succeedsAfterUnpause() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();
        _unpause();

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT);
        protocol.trustBonding.increase_amount(DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT * 2, "locked amount should double");
    }

    function testFuzz_increase_amount_revertsWhenPaused(uint256 amount) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_amount(amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        GATED: increase_unlock_time
    //////////////////////////////////////////////////////////////*/

    function test_increase_unlock_time_revertsWhenPaused() external {
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();

        uint256 newUnlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_unlock_time(newUnlockTime);
        vm.stopPrank();
    }

    function test_increase_unlock_time_succeedsAfterUnpause() external {
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();
        _unpause();

        uint256 endBefore = _lockedEnd(users.alice);
        uint256 newUnlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        protocol.trustBonding.increase_unlock_time(newUnlockTime);
        vm.stopPrank();

        assertGt(_lockedEnd(users.alice), endBefore, "unlock time should be extended");
    }

    function testFuzz_increase_unlock_time_revertsWhenPaused(uint256 newDuration) external {
        newDuration = bound(newDuration, SHORT_LOCK_DURATION + ONE_WEEK, DEFAULT_LOCK_DURATION);
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_unlock_time(block.timestamp + newDuration);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    GATED: increase_amount_and_time
    //////////////////////////////////////////////////////////////*/

    function test_increase_amount_and_time_revertsWhenPaused() external {
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();

        uint256 newUnlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_amount_and_time(DEFAULT_DEPOSIT_AMOUNT, newUnlockTime);
        vm.stopPrank();
    }

    function test_increase_amount_and_time_succeedsAfterUnpause() external {
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();
        _unpause();

        uint256 endBefore = _lockedEnd(users.alice);
        uint256 newUnlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT);
        protocol.trustBonding.increase_amount_and_time(DEFAULT_DEPOSIT_AMOUNT, newUnlockTime);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT * 2, "locked amount should double");
        assertGt(_lockedEnd(users.alice), endBefore, "unlock time should be extended");
    }

    function testFuzz_increase_amount_and_time_revertsWhenPaused(uint256 amount, uint256 newDuration) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        newDuration = bound(newDuration, SHORT_LOCK_DURATION + ONE_WEEK, DEFAULT_LOCK_DURATION);
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.increase_amount_and_time(amount, block.timestamp + newDuration);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    GATED: withdraw_and_create_lock
    //////////////////////////////////////////////////////////////*/

    function test_withdraw_and_create_lock_revertsWhenPaused() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        // Expire the lock so the call would otherwise succeed, then pause
        vm.warp(_lockedEnd(users.alice) + 1);
        _pause();

        uint256 lockedBefore = _lockedAmount(users.alice);
        uint256 unlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.withdraw_and_create_lock(DEFAULT_DEPOSIT_AMOUNT, unlockTime);
        vm.stopPrank();

        // The gate fires before the withdraw half runs, so the expired lock is untouched
        assertEq(_lockedAmount(users.alice), lockedBefore, "expired lock must remain untouched");
    }

    function test_withdraw_and_create_lock_succeedsAfterUnpause() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        vm.warp(_lockedEnd(users.alice) + 1);
        _pause();
        _unpause();

        uint256 unlockTime = block.timestamp + DEFAULT_LOCK_DURATION;

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT * 2);
        protocol.trustBonding.withdraw_and_create_lock(DEFAULT_DEPOSIT_AMOUNT * 2, unlockTime);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT * 2, "new lock should be created after unpause");
    }

    function testFuzz_withdraw_and_create_lock_revertsWhenPaused(uint256 amount) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        vm.warp(_lockedEnd(users.alice) + 1);
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        protocol.trustBonding.withdraw_and_create_lock(amount, block.timestamp + DEFAULT_LOCK_DURATION);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
            POLICY PINS: withdraw / checkpoint STAY UN-GATED
    //////////////////////////////////////////////////////////////*/

    /// @dev Pins the exit policy: a pause must never trap users' locked TRUST.
    function test_withdraw_succeedsWhenPaused() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);

        vm.warp(_lockedEnd(users.alice) + 1);
        _pause();

        uint256 balanceBefore = protocol.wrappedTrust.balanceOf(users.alice);
        uint256 supplyBefore = protocol.trustBonding.supply();

        vm.startPrank(users.alice);
        protocol.trustBonding.withdraw();
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), 0, "lock should be fully withdrawn while paused");
        assertEq(
            protocol.wrappedTrust.balanceOf(users.alice),
            balanceBefore + DEFAULT_DEPOSIT_AMOUNT,
            "tokens should be returned while paused"
        );
        assertEq(protocol.trustBonding.supply(), supplyBefore - DEFAULT_DEPOSIT_AMOUNT, "supply should decrease");
    }

    function testFuzz_withdraw_succeedsWhenPaused(uint256 amount) external {
        amount = bound(amount, 1, XLARGE_DEPOSIT_AMOUNT);
        _createLock(users.alice, amount);

        vm.warp(_lockedEnd(users.alice) + 1);
        _pause();

        uint256 balanceBefore = protocol.wrappedTrust.balanceOf(users.alice);

        vm.startPrank(users.alice);
        protocol.trustBonding.withdraw();
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), 0, "lock should be fully withdrawn while paused");
        assertEq(
            protocol.wrappedTrust.balanceOf(users.alice),
            balanceBefore + amount,
            "tokens should be returned while paused"
        );
    }

    /// @dev Pins the bookkeeping policy: global accounting must stay current during a pause.
    function test_checkpoint_succeedsWhenPaused() external {
        _createLock(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        _pause();

        uint256 epochBefore = protocol.trustBonding.epoch();

        vm.warp(block.timestamp + ONE_WEEK);
        protocol.trustBonding.checkpoint();

        assertGt(protocol.trustBonding.epoch(), epochBefore, "global checkpoint should advance while paused");
    }

    /*//////////////////////////////////////////////////////////////
                    PAUSE / UNPAUSE ROUND TRIP
    //////////////////////////////////////////////////////////////*/

    /// @dev All six gated entry points revert during the same pause window, then all
    ///      work again after unpause — the gate is a single switch, not per-method state.
    function test_allGatedMethods_revertDuringSinglePauseWindow() external {
        _createLockWithDuration(users.alice, DEFAULT_DEPOSIT_AMOUNT, _calculateUnlockTime(SHORT_LOCK_DURATION));
        _pause();

        uint256 farUnlockTime = block.timestamp + DEFAULT_LOCK_DURATION;
        bytes memory enforcedPause = abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector);

        vm.startPrank(users.bob);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.create_lock(DEFAULT_DEPOSIT_AMOUNT, farUnlockTime);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.deposit_for(users.alice, DEFAULT_DEPOSIT_AMOUNT);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.withdraw_and_create_lock(DEFAULT_DEPOSIT_AMOUNT, farUnlockTime);
        vm.stopPrank();

        vm.startPrank(users.alice);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.increase_amount(DEFAULT_DEPOSIT_AMOUNT);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.increase_unlock_time(farUnlockTime);
        vm.expectRevert(enforcedPause);
        protocol.trustBonding.increase_amount_and_time(DEFAULT_DEPOSIT_AMOUNT, farUnlockTime);
        vm.stopPrank();

        _unpause();

        vm.startPrank(users.alice);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), DEFAULT_DEPOSIT_AMOUNT);
        protocol.trustBonding.increase_amount(DEFAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(_lockedAmount(users.alice), DEFAULT_DEPOSIT_AMOUNT * 2, "bonding should resume after unpause");
    }
}
