// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { VotingEscrow, Point, LockedBalance } from "src/external/curve/VotingEscrow.sol";
import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";

/// @dev Test harness to expose internal VotingEscrow initializer function
contract VotingEscrowHarness is VotingEscrow {
    function initialize(address admin, address tokenAddress, uint256 minTime) external initializer {
        __VotingEscrow_init(admin, tokenAddress, minTime);
    }
}

/// @dev Mock smart contract for testing of the whitelist functionality
contract MockSmartContract {
    function execute(address target, bytes calldata data) external returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Call failed");
        return result;
    }
}

contract VotingEscrowTest is Test {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    VotingEscrowHarness public votingEscrowImplementation;
    TransparentUpgradeableProxy public votingEscrowProxy;
    VotingEscrowHarness public votingEscrow;
    ERC20Mock public token;

    address public admin;
    address public alice;
    address public bob;
    address public charlie;
    address public smartContract;

    uint256 public constant WEEK = 1 weeks;
    uint256 public constant MAXTIME = 2 * 365 * 86_400;
    uint256 public constant DEFAULT_MINTIME = 2 weeks;
    uint256 public constant INITIAL_BALANCE = 1_000_000e18;

    /* =================================================== */
    /*                      EVENTS                         */
    /* =================================================== */

    event TokenSet(address token);
    event MinTimeSet(uint256 min_time);
    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 indexed locktime,
        VotingEscrow.DepositType deposit_type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    /* =================================================== */
    /*                      SETUP                          */
    /* =================================================== */

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        smartContract = address(new MockSmartContract());

        vm.deal(admin, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        token = new ERC20Mock("Test Token", "TEST", 18);

        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);
        token.mint(charlie, INITIAL_BALANCE);

        _deployVotingEscrow();

        vm.startPrank(alice);
        token.approve(address(votingEscrow), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(votingEscrow), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(charlie);
        token.approve(address(votingEscrow), type(uint256).max);
        vm.stopPrank();
    }

    function _deployVotingEscrow() internal {
        votingEscrowImplementation = new VotingEscrowHarness();

        votingEscrowProxy = new TransparentUpgradeableProxy(address(votingEscrowImplementation), admin, "");

        votingEscrow = VotingEscrowHarness(address(votingEscrowProxy));
        votingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);
    }

    /* =================================================== */
    /*              INITIALIZATION TESTS                   */
    /* =================================================== */

    function test_initialize_setsTokenCorrectly() external view {
        assertEq(votingEscrow.token(), address(token));
    }

    function test_initialize_setsMintimeCorrectly() external view {
        assertEq(votingEscrow.MINTIME(), DEFAULT_MINTIME);
    }

    function test_initialize_setsAdminRole() external view {
        assertTrue(votingEscrow.hasRole(votingEscrow.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_initialize_setsControllerToAdmin() external view {
        assertEq(votingEscrow.controller(), admin);
    }

    function test_initialize_enablesTransfers() external view {
        assertTrue(votingEscrow.transfersEnabled());
    }

    function test_initialize_setsInitialPointHistory() external view {
        (int128 bias, int128 slope, uint256 timestamp, uint256 blockNumber) = votingEscrow.point_history(0);
        assertEq(bias, 0);
        assertEq(slope, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(blockNumber, block.number);
    }

    function test_initialize_revertsOnZeroTokenAddress() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));

        vm.expectRevert("Token address cannot be 0");
        newVotingEscrow.initialize(admin, address(0), DEFAULT_MINTIME);
    }

    function test_initialize_revertsOnTooShortMinTime() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));

        vm.expectRevert("Min lock time must be at least 2 weeks");
        newVotingEscrow.initialize(admin, address(token), 1 weeks);
    }

    function test_initialize_emitsTokenSetEvent() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));

        vm.expectEmit(true, true, true, true);
        emit TokenSet(address(token));
        newVotingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);
    }

    function test_initialize_emitsMinTimeSetEvent() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));

        vm.expectEmit(true, true, true, true);
        emit MinTimeSet(DEFAULT_MINTIME);
        newVotingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);
    }

    function test_initialize_setsConstantsCorrectly() external view {
        assertEq(votingEscrow.name(), "Vote-escrowed TRUST");
        assertEq(votingEscrow.symbol(), "veTRUST");
        assertEq(votingEscrow.version(), "1.0.0");
        assertEq(votingEscrow.decimals(), 18);
        assertEq(votingEscrow.MAXTIME(), MAXTIME);
    }

    /* =================================================== */
    /*              ACCESS CONTROL TESTS                   */
    /* =================================================== */

    function test_add_to_whitelist_successByAdmin() external {
        vm.prank(admin);
        votingEscrow.add_to_whitelist(smartContract);
        assertTrue(votingEscrow.contracts_whitelist(smartContract));
    }

    function test_add_to_whitelist_revertsForNonAdmin() external {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, votingEscrow.DEFAULT_ADMIN_ROLE()
            )
        );
        votingEscrow.add_to_whitelist(smartContract);
    }

    function test_remove_from_whitelist_successByAdmin() external {
        vm.startPrank(admin);
        votingEscrow.add_to_whitelist(smartContract);
        votingEscrow.remove_from_whitelist(smartContract);
        vm.stopPrank();
        assertFalse(votingEscrow.contracts_whitelist(smartContract));
    }

    function test_remove_from_whitelist_revertsForNonAdmin() external {
        vm.prank(admin);
        votingEscrow.add_to_whitelist(smartContract);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, votingEscrow.DEFAULT_ADMIN_ROLE()
            )
        );
        votingEscrow.remove_from_whitelist(smartContract);
    }

    function test_unlock_successByAdmin() external {
        vm.prank(admin);
        votingEscrow.unlock();
        assertTrue(votingEscrow.unlocked());
    }

    function test_unlock_revertsForNonAdmin() external {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, votingEscrow.DEFAULT_ADMIN_ROLE()
            )
        );
        votingEscrow.unlock();
    }

    function test_changeController_successByCurrentController() external {
        vm.prank(admin);
        votingEscrow.changeController(alice);
        assertEq(votingEscrow.controller(), alice);
    }

    function test_changeController_revertsForNonController() external {
        vm.prank(alice);
        vm.expectRevert();
        votingEscrow.changeController(bob);
    }

    /* =================================================== */
    /*              CREATE LOCK TESTS                      */
    /* =================================================== */

    function test_create_lock_successfulLockCreation() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
        assertEq(lockedEnd, (unlockTime / WEEK) * WEEK);
    }

    function test_create_lock_revertsOnZeroValue() external {
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        vm.expectRevert();
        votingEscrow.create_lock(0, unlockTime);
    }

    function test_create_lock_revertsOnExistingLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.expectRevert("Withdraw old tokens first");
        votingEscrow.create_lock(lockAmount, unlockTime);
        vm.stopPrank();
    }

    function test_create_lock_revertsOnTooShortLockTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + 1 weeks;

        vm.prank(alice);
        vm.expectRevert("Voting lock must be at least MINTIME");
        votingEscrow.create_lock(lockAmount, unlockTime);
    }

    function test_create_lock_revertsOnTooLongLockTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME + 1 weeks;

        vm.prank(alice);
        vm.expectRevert("Voting lock can be 2 years max");
        votingEscrow.create_lock(lockAmount, unlockTime);
    }

    function test_create_lock_revertsWhenUnlockedGlobally() external {
        vm.prank(admin);
        votingEscrow.unlock();

        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        vm.expectRevert("unlocked globally");
        votingEscrow.create_lock(lockAmount, unlockTime);
    }

    function test_create_lock_revertsForNonWhitelistedSmartContract() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        token.mint(smartContract, lockAmount);

        vm.startPrank(smartContract);
        token.approve(address(votingEscrow), lockAmount);
        vm.expectRevert("Smart contract not allowed");
        votingEscrow.create_lock(lockAmount, unlockTime);
        vm.stopPrank();
    }

    function test_create_lock_successForWhitelistedSmartContract() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        token.mint(smartContract, lockAmount);

        vm.prank(admin);
        votingEscrow.add_to_whitelist(smartContract);

        vm.startPrank(smartContract);
        token.approve(address(votingEscrow), lockAmount);
        votingEscrow.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        (int128 lockedAmount,) = votingEscrow.locked(smartContract);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
    }

    function test_create_lock_roundsUnlockTimeToWeek() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME + 3 days;
        uint256 expectedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(lockedEnd, expectedUnlockTime);
    }

    function test_create_lock_updatesSupply() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        uint256 supplyBefore = votingEscrow.supply();

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        assertEq(votingEscrow.supply(), supplyBefore + lockAmount);
    }

    function test_create_lock_emitsDepositEvent() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, lockAmount, roundedUnlockTime, VotingEscrow.DepositType.CREATE_LOCK_TYPE, block.timestamp);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
    }

    function test_create_lock_emitsSupplyEvent() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.expectEmit(true, true, true, true);
        emit Supply(0, lockAmount);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
    }

    /* =================================================== */
    /*              DEPOSIT FOR TESTS                      */
    /* =================================================== */

    function test_deposit_for_successfulDeposit() external {
        uint256 lockAmount = 100e18;
        uint256 depositAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        token.mint(bob, depositAmount);
        vm.startPrank(bob);
        token.approve(address(votingEscrow), depositAmount);
        votingEscrow.deposit_for(alice, depositAmount);
        vm.stopPrank();

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount + depositAmount);
    }

    function test_deposit_for_revertsOnZeroValue() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.prank(bob);
        vm.expectRevert();
        votingEscrow.deposit_for(alice, 0);
    }

    function test_deposit_for_revertsOnNoExistingLock() external {
        uint256 depositAmount = 50e18;

        vm.prank(bob);
        vm.expectRevert("No existing lock found");
        votingEscrow.deposit_for(alice, depositAmount);
    }

    function test_deposit_for_revertsOnExpiredLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        vm.prank(bob);
        vm.expectRevert("Cannot add to expired lock. Withdraw");
        votingEscrow.deposit_for(alice, 50e18);
    }

    function test_deposit_for_revertsWhenUnlockedGlobally() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.prank(admin);
        votingEscrow.unlock();

        vm.prank(bob);
        vm.expectRevert("unlocked globally");
        votingEscrow.deposit_for(alice, 50e18);
    }

    function test_deposit_for_emitsDepositEvent() external {
        uint256 lockAmount = 100e18;
        uint256 depositAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        token.mint(bob, depositAmount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            alice, depositAmount, roundedUnlockTime, VotingEscrow.DepositType.DEPOSIT_FOR_TYPE, block.timestamp
        );

        vm.startPrank(bob);
        token.approve(address(votingEscrow), depositAmount);
        votingEscrow.deposit_for(alice, depositAmount);
        vm.stopPrank();
    }

    /* =================================================== */
    /*              INCREASE AMOUNT TESTS                  */
    /* =================================================== */

    function test_increase_amount_successfulIncrease() external {
        uint256 lockAmount = 100e18;
        uint256 increaseAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        votingEscrow.increase_amount(increaseAmount);
        vm.stopPrank();

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount + increaseAmount);
    }

    function test_increase_amount_revertsOnZeroValue() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        vm.expectRevert();
        votingEscrow.increase_amount(0);
        vm.stopPrank();
    }

    function test_increase_amount_revertsOnNoExistingLock() external {
        vm.prank(alice);
        vm.expectRevert("No existing lock found");
        votingEscrow.increase_amount(50e18);
    }

    function test_increase_amount_revertsOnExpiredLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        vm.prank(alice);
        vm.expectRevert("Cannot add to expired lock. Withdraw");
        votingEscrow.increase_amount(50e18);
    }

    function test_increase_amount_emitsDepositEvent() external {
        uint256 lockAmount = 100e18;
        uint256 increaseAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            alice, increaseAmount, roundedUnlockTime, VotingEscrow.DepositType.INCREASE_LOCK_AMOUNT, block.timestamp
        );

        vm.prank(alice);
        votingEscrow.increase_amount(increaseAmount);
    }

    /* =================================================== */
    /*           INCREASE UNLOCK TIME TESTS                */
    /* =================================================== */

    function test_increase_unlock_time_successfulIncrease() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 newUnlockTime = block.timestamp + 4 weeks;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        votingEscrow.increase_unlock_time(newUnlockTime);
        vm.stopPrank();

        (, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(lockedEnd, (newUnlockTime / WEEK) * WEEK);
    }

    function test_increase_unlock_time_revertsOnExpiredLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        vm.prank(alice);
        vm.expectRevert("Lock expired");
        votingEscrow.increase_unlock_time(block.timestamp + 4 weeks);
    }

    function test_increase_unlock_time_revertsOnNoLock() external {
        vm.prank(alice);
        vm.expectRevert("Nothing is locked");
        votingEscrow.increase_unlock_time(block.timestamp + 4 weeks);
    }

    function test_increase_unlock_time_revertsOnShorterDuration() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + 4 weeks;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 shorterUnlockTime = block.timestamp + 3 weeks;
        vm.expectRevert("Can only increase lock duration");
        votingEscrow.increase_unlock_time(shorterUnlockTime);
        vm.stopPrank();
    }

    function test_increase_unlock_time_revertsOnTooLongDuration() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 tooLongUnlockTime = block.timestamp + MAXTIME + 1 weeks;
        vm.expectRevert("Voting lock can be 2 years max");
        votingEscrow.increase_unlock_time(tooLongUnlockTime);
        vm.stopPrank();
    }

    function test_increase_unlock_time_emitsDepositEvent() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 newUnlockTime = block.timestamp + 4 weeks;
        uint256 roundedNewUnlockTime = (newUnlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, 0, roundedNewUnlockTime, VotingEscrow.DepositType.INCREASE_UNLOCK_TIME, block.timestamp);

        vm.prank(alice);
        votingEscrow.increase_unlock_time(newUnlockTime);
    }

    /* =================================================== */
    /*         INCREASE AMOUNT AND TIME TESTS              */
    /* =================================================== */

    function test_increase_amount_and_time_successfulBoth() external {
        uint256 lockAmount = 100e18;
        uint256 increaseAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 newUnlockTime = block.timestamp + 4 weeks;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        votingEscrow.increase_amount_and_time(increaseAmount, newUnlockTime);
        vm.stopPrank();

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount + increaseAmount);
        assertEq(lockedEnd, (newUnlockTime / WEEK) * WEEK);
    }

    function test_increase_amount_and_time_onlyAmount() external {
        uint256 lockAmount = 100e18;
        uint256 increaseAmount = 50e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        votingEscrow.increase_amount_and_time(increaseAmount, 0);
        vm.stopPrank();

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount + increaseAmount);
        assertEq(lockedEnd, roundedUnlockTime);
    }

    function test_increase_amount_and_time_onlyTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 newUnlockTime = block.timestamp + 4 weeks;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);
        votingEscrow.increase_amount_and_time(0, newUnlockTime);
        vm.stopPrank();

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
        assertEq(lockedEnd, (newUnlockTime / WEEK) * WEEK);
    }

    function test_increase_amount_and_time_revertsOnBothZero() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.expectRevert("Value and Unlock cannot both be 0");
        votingEscrow.increase_amount_and_time(0, 0);
        vm.stopPrank();
    }

    /* =================================================== */
    /*                WITHDRAW TESTS                       */
    /* =================================================== */

    function test_withdraw_successfulWithdrawAfterExpiry() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.warp(unlockTime + 1);

        vm.prank(alice);
        votingEscrow.withdraw();

        assertEq(token.balanceOf(alice), balanceBefore + lockAmount);

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(lockedAmount, 0);
        assertEq(lockedEnd, 0);
    }

    function test_withdraw_revertsBeforeExpiry() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.prank(alice);
        vm.expectRevert("The lock didn't expire");
        votingEscrow.withdraw();
    }

    function test_withdraw_successWhenUnlockedGlobally() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.prank(admin);
        votingEscrow.unlock();

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        votingEscrow.withdraw();

        assertEq(token.balanceOf(alice), balanceBefore + lockAmount);
    }

    function test_withdraw_updatesSupply() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        uint256 supplyBefore = votingEscrow.supply();

        vm.prank(alice);
        votingEscrow.withdraw();

        assertEq(votingEscrow.supply(), supplyBefore - lockAmount);
    }

    function test_withdraw_emitsWithdrawEvent() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, lockAmount, block.timestamp);

        vm.prank(alice);
        votingEscrow.withdraw();
    }

    function test_withdraw_emitsSupplyEvent() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyBefore = votingEscrow.supply();

        vm.warp(unlockTime + 1);

        vm.expectEmit(true, true, true, true);
        emit Supply(supplyBefore, 0);

        vm.prank(alice);
        votingEscrow.withdraw();
    }

    /* =================================================== */
    /*          WITHDRAW AND CREATE LOCK TESTS             */
    /* =================================================== */

    function test_withdraw_and_create_lock_successful() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        uint256 newLockAmount = 200e18;
        uint256 newUnlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.withdraw_and_create_lock(newLockAmount, newUnlockTime);

        (int128 lockedAmount, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), newLockAmount);
        assertEq(lockedEnd, (newUnlockTime / WEEK) * WEEK);
    }

    function test_withdraw_and_create_lock_revertsWhenUnlockedGlobally() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        vm.prank(admin);
        votingEscrow.unlock();

        vm.prank(alice);
        vm.expectRevert("unlocked globally");
        votingEscrow.withdraw_and_create_lock(lockAmount, block.timestamp + DEFAULT_MINTIME);
    }

    /* =================================================== */
    /*               CHECKPOINT TESTS                      */
    /* =================================================== */

    function test_checkpoint_updatesGlobalState() external {
        uint256 epochBefore = votingEscrow.epoch();

        vm.prank(alice);
        votingEscrow.checkpoint();

        assertGe(votingEscrow.epoch(), epochBefore);
    }

    function test_checkpoint_revertsWhenUnlockedGlobally() external {
        vm.prank(admin);
        votingEscrow.unlock();

        vm.prank(alice);
        vm.expectRevert("unlocked globally");
        votingEscrow.checkpoint();
    }

    /* =================================================== */
    /*              BALANCE OF TESTS                       */
    /* =================================================== */

    function test_balanceOf_returnsZeroForUserWithNoLock() external view {
        assertEq(votingEscrow.balanceOf(alice), 0);
    }

    function test_balanceOf_returnsPositiveForUserWithActiveLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balance = votingEscrow.balanceOf(alice);
        assertGt(balance, 0);
    }

    function test_balanceOf_decaysOverTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balanceNow = votingEscrow.balanceOf(alice);

        vm.warp(block.timestamp + 30 days);

        uint256 balanceLater = votingEscrow.balanceOf(alice);
        assertLt(balanceLater, balanceNow);
    }

    function test_balanceOf_returnsZeroAfterExpiry() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        assertEq(votingEscrow.balanceOf(alice), 0);
    }

    function test_balanceOf_higherForLongerLockTime() external {
        uint256 lockAmount = 100e18;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, block.timestamp + DEFAULT_MINTIME);

        vm.prank(bob);
        votingEscrow.create_lock(lockAmount, block.timestamp + MAXTIME);

        uint256 aliceBalance = votingEscrow.balanceOf(alice);
        uint256 bobBalance = votingEscrow.balanceOf(bob);

        assertGt(bobBalance, aliceBalance);
    }

    function test_balanceOf_proportionalToLockAmount() external {
        uint256 aliceLockAmount = 100e18;
        uint256 bobLockAmount = 200e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(aliceLockAmount, unlockTime);

        vm.prank(bob);
        votingEscrow.create_lock(bobLockAmount, unlockTime);

        uint256 aliceBalance = votingEscrow.balanceOf(alice);
        uint256 bobBalance = votingEscrow.balanceOf(bob);

        assertApproxEqRel(bobBalance, aliceBalance * 2, 0.01e18);
    }

    /* =================================================== */
    /*            BALANCE OF AT T TESTS                    */
    /* =================================================== */

    function test_balanceOfAtT_returnsZeroForFutureTimeWithNoCheckpoint() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 futureTime = block.timestamp - 1000;
        uint256 balance = votingEscrow.balanceOfAtT(alice, futureTime);
        assertEq(balance, 0);
    }

    function test_balanceOfAtT_returnsCorrectBalanceForPastTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockTime = block.timestamp;

        vm.warp(block.timestamp + 30 days);

        uint256 pastBalance = votingEscrow.balanceOfAtT(alice, lockTime);
        uint256 currentBalance = votingEscrow.balanceOf(alice);

        assertGt(pastBalance, currentBalance);
    }

    function test_balanceOfAtT_returnsZeroForTimeBeforeFirstCheckpoint() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balance = votingEscrow.balanceOfAtT(alice, block.timestamp - 1);
        assertEq(balance, 0);
    }

    function test_balanceOfAtT_returnsCurrentBalanceForCurrentTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balanceAtT = votingEscrow.balanceOfAtT(alice, block.timestamp);
        uint256 balanceOf = votingEscrow.balanceOf(alice);

        assertEq(balanceAtT, balanceOf);
    }

    /* =================================================== */
    /*            BALANCE OF AT TESTS (BLOCK)              */
    /* =================================================== */

    function test_balanceOfAt_returnsZeroForUserWithNoLock() external view {
        assertEq(votingEscrow.balanceOfAt(alice, block.number), 0);
    }

    function test_balanceOfAt_revertsForFutureBlock() external {
        vm.expectRevert("block in the future");
        votingEscrow.balanceOfAt(alice, block.number + 1);
    }

    function test_balanceOfAt_returnsCorrectBalanceForHistoricalBlock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockBlock = block.number;

        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 30 days);

        uint256 historicalBalance = votingEscrow.balanceOfAt(alice, lockBlock);
        uint256 currentBalance = votingEscrow.balanceOf(alice);

        assertGt(historicalBalance, currentBalance);
    }

    function test_balanceOfAt_returnsZeroForBlockBeforeFirstCheckpoint() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        uint256 blockBeforeLock = block.number;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balance = votingEscrow.balanceOfAt(alice, blockBeforeLock);
        assertEq(balance, 0);
    }

    function test_balanceOfAt_returnsZeroWhenEpochIsZero() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));
        newVotingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);

        uint256 balance = newVotingEscrow.balanceOfAt(alice, block.number);
        assertEq(balance, 0);
    }

    function test_balanceOfAt_returnsZeroForBlockBeforeFirstPointHistoryBlock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (,,, uint256 firstBlock) = votingEscrow.point_history(0);

        if (firstBlock > 0) {
            uint256 balance = votingEscrow.balanceOfAt(alice, firstBlock - 1);
            assertEq(balance, 0);
        }
    }

    /* =================================================== */
    /*             TOTAL SUPPLY TESTS                      */
    /* =================================================== */

    function test_totalSupply_returnsZeroWithNoLocks() external view {
        assertEq(votingEscrow.totalSupply(), 0);
    }

    function test_totalSupply_returnsPositiveWithActiveLocks() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        assertGt(votingEscrow.totalSupply(), 0);
    }

    function test_totalSupply_decaysOverTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyNow = votingEscrow.totalSupply();

        vm.warp(block.timestamp + 30 days);

        uint256 supplyLater = votingEscrow.totalSupply();
        assertLt(supplyLater, supplyNow);
    }

    function test_totalSupply_increasesWithMoreLocks() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyWithOneLock = votingEscrow.totalSupply();

        vm.prank(bob);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyWithTwoLocks = votingEscrow.totalSupply();
        assertGt(supplyWithTwoLocks, supplyWithOneLock);
    }

    function test_totalSupply_equalsZeroAfterAllLocksExpire() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        vm.warp(unlockTime + 1);

        assertEq(votingEscrow.totalSupply(), 0);
    }

    function test_totalSupply_consistentWithSumOfBalances() external {
        uint256 aliceLockAmount = 100e18;
        uint256 bobLockAmount = 150e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(aliceLockAmount, unlockTime);

        vm.prank(bob);
        votingEscrow.create_lock(bobLockAmount, unlockTime);

        uint256 totalSupply = votingEscrow.totalSupply();
        uint256 sumOfBalances = votingEscrow.balanceOf(alice) + votingEscrow.balanceOf(bob);

        assertApproxEqRel(totalSupply, sumOfBalances, 0.01e18);
    }

    /* =================================================== */
    /*           TOTAL SUPPLY AT T TESTS                   */
    /* =================================================== */

    function test_totalSupplyAtT_returnsZeroForTimeBeforeFirstCheckpoint() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supply = votingEscrow.totalSupplyAtT(block.timestamp - 1);
        assertEq(supply, 0);
    }

    function test_totalSupplyAtT_returnsCorrectSupplyForPastTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockTime = block.timestamp;

        vm.warp(block.timestamp + 30 days);

        uint256 pastSupply = votingEscrow.totalSupplyAtT(lockTime);
        uint256 currentSupply = votingEscrow.totalSupply();

        assertGt(pastSupply, currentSupply);
    }

    function test_totalSupplyAtT_returnsCurrentSupplyForCurrentTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyAtT = votingEscrow.totalSupplyAtT(block.timestamp);
        uint256 totalSupply = votingEscrow.totalSupply();

        assertEq(supplyAtT, totalSupply);
    }

    function test_totalSupplyAtT_returnsZeroWhenEpochIsZero() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));
        newVotingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);

        uint256 supply = newVotingEscrow.totalSupplyAtT(block.timestamp);
        assertEq(supply, 0);
    }

    /* =================================================== */
    /*          TOTAL SUPPLY AT TESTS (BLOCK)              */
    /* =================================================== */

    function test_totalSupplyAt_revertsForFutureBlock() external {
        vm.expectRevert("block in the future");
        votingEscrow.totalSupplyAt(block.number + 1);
    }

    function test_totalSupplyAt_returnsZeroWithNoLocks() external view {
        assertEq(votingEscrow.totalSupplyAt(block.number), 0);
    }

    function test_totalSupplyAt_returnsCorrectSupplyForHistoricalBlock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockBlock = block.number;

        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 30 days);

        uint256 historicalSupply = votingEscrow.totalSupplyAt(lockBlock);
        uint256 currentSupply = votingEscrow.totalSupply();

        assertGt(historicalSupply, currentSupply);
    }

    function test_totalSupplyAt_returnsZeroForBlockBeforeFirstCheckpoint() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        uint256 blockBeforeLock = block.number;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supply = votingEscrow.totalSupplyAt(blockBeforeLock);
        assertEq(supply, 0);
    }

    function test_totalSupplyAt_returnsZeroWhenEpochIsZero() external {
        VotingEscrowHarness newImplementation = new VotingEscrowHarness();
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(address(newImplementation), admin, "");
        VotingEscrowHarness newVotingEscrow = VotingEscrowHarness(address(newProxy));
        newVotingEscrow.initialize(admin, address(token), DEFAULT_MINTIME);

        uint256 supply = newVotingEscrow.totalSupplyAt(block.number);
        assertEq(supply, 0);
    }

    function test_totalSupplyAt_returnsZeroForBlockBeforeFirstPointHistoryBlock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (,,, uint256 firstBlock) = votingEscrow.point_history(0);

        if (firstBlock > 0) {
            uint256 supply = votingEscrow.totalSupplyAt(firstBlock - 1);
            assertEq(supply, 0);
        }
    }

    /* =================================================== */
    /*              VIEW FUNCTIONS TESTS                   */
    /* =================================================== */

    function test_get_last_user_slope_returnsZeroForUserWithNoLock() external view {
        assertEq(votingEscrow.get_last_user_slope(alice), 0);
    }

    function test_get_last_user_slope_returnsPositiveForUserWithLock() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        int128 slope = votingEscrow.get_last_user_slope(alice);
        assertGt(slope, 0);
    }

    function test_user_point_history__ts_returnsCorrectTimestamp() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 userEpoch = votingEscrow.user_point_epoch(alice);
        uint256 timestamp = votingEscrow.user_point_history__ts(alice, userEpoch);

        assertEq(timestamp, block.timestamp);
    }

    function test_locked__end_returnsCorrectEndTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        assertEq(votingEscrow.locked__end(alice), roundedUnlockTime);
    }

    function test_locked__end_returnsZeroForUserWithNoLock() external view {
        assertEq(votingEscrow.locked__end(alice), 0);
    }

    /* =================================================== */
    /*                 FUZZING TESTS                       */
    /* =================================================== */

    function testFuzz_create_lock_variousAmounts(uint256 lockAmount) external {
        lockAmount = bound(lockAmount, 1, INITIAL_BALANCE);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
        assertGt(votingEscrow.balanceOf(alice), 0);
    }

    function testFuzz_create_lock_variousUnlockTimes(uint256 unlockDuration) external {
        unlockDuration = bound(unlockDuration, DEFAULT_MINTIME, MAXTIME);
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + unlockDuration;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (, uint256 lockedEnd) = votingEscrow.locked(alice);
        uint256 expectedEnd = (unlockTime / WEEK) * WEEK;
        assertEq(lockedEnd, expectedEnd);
    }

    function testFuzz_increase_amount(uint256 initialAmount, uint256 increaseAmount) external {
        initialAmount = bound(initialAmount, 1, INITIAL_BALANCE / 2);
        increaseAmount = bound(increaseAmount, 1, INITIAL_BALANCE / 2);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.startPrank(alice);
        votingEscrow.create_lock(initialAmount, unlockTime);
        votingEscrow.increase_amount(increaseAmount);
        vm.stopPrank();

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), initialAmount + increaseAmount);
    }

    function testFuzz_balanceOf_decaysCorrectly(uint256 lockAmount, uint256 timePassed) external {
        lockAmount = bound(lockAmount, 1e18, INITIAL_BALANCE);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balanceBefore = votingEscrow.balanceOf(alice);

        timePassed = bound(timePassed, 1, MAXTIME - 1);
        vm.warp(block.timestamp + timePassed);

        uint256 balanceAfter = votingEscrow.balanceOf(alice);
        assertLe(balanceAfter, balanceBefore);
    }

    function testFuzz_totalSupply_decaysCorrectly(uint256 lockAmount, uint256 timePassed) external {
        lockAmount = bound(lockAmount, 1e18, INITIAL_BALANCE);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 supplyBefore = votingEscrow.totalSupply();

        timePassed = bound(timePassed, 1, MAXTIME - 1);
        vm.warp(block.timestamp + timePassed);

        uint256 supplyAfter = votingEscrow.totalSupply();
        assertLe(supplyAfter, supplyBefore);
    }

    function testFuzz_deposit_for_variousAmounts(uint256 initialAmount, uint256 depositAmount) external {
        initialAmount = bound(initialAmount, 1, INITIAL_BALANCE / 2);
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE / 2);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(initialAmount, unlockTime);

        token.mint(bob, depositAmount);
        vm.startPrank(bob);
        token.approve(address(votingEscrow), depositAmount);
        votingEscrow.deposit_for(alice, depositAmount);
        vm.stopPrank();

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), initialAmount + depositAmount);
    }

    function testFuzz_multiple_users_total_supply(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 charlieAmount
    )
        external
    {
        aliceAmount = bound(aliceAmount, 1e18, INITIAL_BALANCE / 3);
        bobAmount = bound(bobAmount, 1e18, INITIAL_BALANCE / 3);
        charlieAmount = bound(charlieAmount, 1e18, INITIAL_BALANCE / 3);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(aliceAmount, unlockTime);

        vm.prank(bob);
        votingEscrow.create_lock(bobAmount, unlockTime);

        vm.prank(charlie);
        votingEscrow.create_lock(charlieAmount, unlockTime);

        uint256 totalSupply = votingEscrow.totalSupply();
        uint256 sumOfBalances =
            votingEscrow.balanceOf(alice) + votingEscrow.balanceOf(bob) + votingEscrow.balanceOf(charlie);

        assertApproxEqRel(totalSupply, sumOfBalances, 0.01e18);
    }

    function testFuzz_withdraw_after_expiry(uint256 lockAmount, uint256 extraTime) external {
        lockAmount = bound(lockAmount, 1e18, INITIAL_BALANCE);
        extraTime = bound(extraTime, 1, 365 days);
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.warp(unlockTime + extraTime);

        vm.prank(alice);
        votingEscrow.withdraw();

        assertEq(token.balanceOf(alice), balanceBefore + lockAmount);
    }

    function testFuzz_balanceOfAtT_pastTime(uint256 lockAmount, uint256 timeOffset) external {
        lockAmount = bound(lockAmount, 1e18, INITIAL_BALANCE);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockTime = block.timestamp;

        timeOffset = bound(timeOffset, 1, MAXTIME - 1);
        vm.warp(block.timestamp + timeOffset);

        uint256 pastBalance = votingEscrow.balanceOfAtT(alice, lockTime);
        uint256 currentBalance = votingEscrow.balanceOf(alice);

        assertGe(pastBalance, currentBalance);
    }

    function testFuzz_totalSupplyAtT_pastTime(uint256 lockAmount, uint256 timeOffset) external {
        lockAmount = bound(lockAmount, 1e18, INITIAL_BALANCE);
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 lockTime = block.timestamp;

        timeOffset = bound(timeOffset, 1, MAXTIME - 1);
        vm.warp(block.timestamp + timeOffset);

        uint256 pastSupply = votingEscrow.totalSupplyAtT(lockTime);
        uint256 currentSupply = votingEscrow.totalSupply();

        assertGe(pastSupply, currentSupply);
    }

    /* =================================================== */
    /*              EDGE CASE TESTS                        */
    /* =================================================== */

    function test_create_lock_atWeekBoundary() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = ((block.timestamp + DEFAULT_MINTIME) / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (, uint256 lockedEnd) = votingEscrow.locked(alice);
        assertEq(lockedEnd, unlockTime);
    }

    function test_create_lock_maxAmount() external {
        uint256 maxLockAmount = INITIAL_BALANCE;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(maxLockAmount, unlockTime);

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), maxLockAmount);
    }

    function test_create_lock_minAmount() external {
        uint256 minLockAmount = 1;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(minLockAmount, unlockTime);

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), minLockAmount);
    }

    function test_create_lock_exactMinTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
    }

    function test_create_lock_exactMaxTime() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (int128 lockedAmount,) = votingEscrow.locked(alice);
        assertEq(uint256(int256(lockedAmount)), lockAmount);
    }

    function test_multiple_checkpoints_over_time() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 epochAfterCreate = votingEscrow.epoch();

        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 1 weeks);
            vm.prank(alice);
            votingEscrow.checkpoint();
        }

        uint256 epochAfterCheckpoints = votingEscrow.epoch();
        assertGt(epochAfterCheckpoints, epochAfterCreate);
    }

    function test_voting_power_approaches_zero_near_expiry() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + DEFAULT_MINTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        (, uint256 lockedEnd) = votingEscrow.locked(alice);

        vm.warp(lockedEnd - 1);

        uint256 balanceNearExpiry = votingEscrow.balanceOf(alice);
        assertLt(balanceNearExpiry, lockAmount / 100);
    }

    function test_multiple_users_different_lock_times() external {
        uint256 lockAmount = 100e18;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, block.timestamp + DEFAULT_MINTIME);

        vm.prank(bob);
        votingEscrow.create_lock(lockAmount, block.timestamp + 6 * 4 weeks);

        vm.prank(charlie);
        votingEscrow.create_lock(lockAmount, block.timestamp + MAXTIME);

        uint256 aliceBalance = votingEscrow.balanceOf(alice);
        uint256 bobBalance = votingEscrow.balanceOf(bob);
        uint256 charlieBalance = votingEscrow.balanceOf(charlie);

        assertLt(aliceBalance, bobBalance);
        assertLt(bobBalance, charlieBalance);
    }

    function test_binary_search_with_many_epochs() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + 1 weeks);
            vm.roll(block.number + 1);
            vm.prank(alice);
            votingEscrow.checkpoint();
        }

        uint256 totalSupply = votingEscrow.totalSupply();
        assertGt(totalSupply, 0);

        uint256 balance = votingEscrow.balanceOf(alice);
        assertGt(balance, 0);
    }

    function test_supply_consistency_after_multiple_operations() external {
        uint256 aliceLockAmount = 100e18;
        uint256 bobLockAmount = 200e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        vm.prank(alice);
        votingEscrow.create_lock(aliceLockAmount, unlockTime);

        vm.prank(bob);
        votingEscrow.create_lock(bobLockAmount, unlockTime);

        uint256 supply1 = votingEscrow.supply();
        assertEq(supply1, aliceLockAmount + bobLockAmount);

        vm.prank(alice);
        votingEscrow.increase_amount(50e18);

        uint256 supply2 = votingEscrow.supply();
        assertEq(supply2, supply1 + 50e18);

        vm.warp(unlockTime + 1);

        vm.prank(alice);
        votingEscrow.withdraw();

        uint256 supply3 = votingEscrow.supply();
        assertEq(supply3, bobLockAmount);

        vm.prank(bob);
        votingEscrow.withdraw();

        uint256 supply4 = votingEscrow.supply();
        assertEq(supply4, 0);
    }

    function test_historical_queries_across_many_blocks() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        uint256 blockBeforeLock = block.number;
        uint256 timeBeforeLock = block.timestamp;

        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 blockAtLock = block.number;
        uint256 timeAtLock = block.timestamp;

        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 30 days);

        assertEq(votingEscrow.balanceOfAt(alice, blockBeforeLock), 0);
        assertGt(votingEscrow.balanceOfAt(alice, blockAtLock), 0);

        assertEq(votingEscrow.totalSupplyAt(blockBeforeLock), 0);
        assertGt(votingEscrow.totalSupplyAt(blockAtLock), 0);

        assertEq(votingEscrow.balanceOfAtT(alice, timeBeforeLock), 0);
        assertGt(votingEscrow.balanceOfAtT(alice, timeAtLock), 0);

        assertEq(votingEscrow.totalSupplyAtT(timeBeforeLock), 0);
        assertGt(votingEscrow.totalSupplyAtT(timeAtLock), 0);
    }

    function test_user_point_epoch_increments_correctly() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;

        uint256 epochBefore = votingEscrow.user_point_epoch(alice);
        assertEq(epochBefore, 0);

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        uint256 epochAfterCreate = votingEscrow.user_point_epoch(alice);
        assertEq(epochAfterCreate, 1);

        vm.prank(alice);
        votingEscrow.increase_amount(50e18);

        uint256 epochAfterIncrease = votingEscrow.user_point_epoch(alice);
        assertEq(epochAfterIncrease, 2);
    }

    function test_slope_changes_are_recorded_correctly() external {
        uint256 lockAmount = 100e18;
        uint256 unlockTime = block.timestamp + MAXTIME;
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;

        vm.prank(alice);
        votingEscrow.create_lock(lockAmount, unlockTime);

        int128 slopeChange = votingEscrow.slope_changes(roundedUnlockTime);
        assertLt(slopeChange, 0);
    }
}
