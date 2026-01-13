// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { GovernanceWrapper } from "src/protocol/governance/GovernanceWrapper.sol";
import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";

contract GovernanceWrapperTest is BaseTest {
    GovernanceWrapper public governanceWrapperImpl;
    TransparentUpgradeableProxy public governanceWrapperProxy;
    GovernanceWrapper public governanceWrapper;

    address public owner;
    address public nonOwner;

    function setUp() public override {
        super.setUp();

        vm.stopPrank();

        owner = users.admin;
        nonOwner = users.alice;

        governanceWrapperImpl = new GovernanceWrapper();

        governanceWrapperProxy = new TransparentUpgradeableProxy(address(governanceWrapperImpl), users.admin, "");

        governanceWrapper = GovernanceWrapper(address(governanceWrapperProxy));

        vm.label(address(governanceWrapperImpl), "GovernanceWrapperImpl");
        vm.label(address(governanceWrapperProxy), "GovernanceWrapperProxy");
        vm.label(address(governanceWrapper), "GovernanceWrapper");
    }

    /* =================================================== */
    /*                  INITIALIZE TESTS                   */
    /* =================================================== */

    function test_initialize_successful() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        assertEq(governanceWrapper.owner(), owner);
        assertEq(address(governanceWrapper.trustBonding()), address(protocol.trustBonding));
    }

    function test_initialize_revertsOnZeroOwnerAddress() external {
        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_InvalidAddress.selector);
        governanceWrapper.initialize(address(0), address(protocol.trustBonding));
    }

    function test_initialize_revertsOnZeroTrustBondingAddress() external {
        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_InvalidAddress.selector);
        governanceWrapper.initialize(owner, address(0));
    }

    function test_initialize_revertsWhenCalledTwice() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert();
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));
    }

    function test_initialize_emitsTrustBondingSetEvent() external {
        vm.expectEmit(true, true, true, true);
        emit IGovernanceWrapper.TrustBondingSet(address(protocol.trustBonding));

        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));
    }

    function testFuzz_initialize(address _owner, address _trustBonding) external {
        vm.assume(_owner != address(0));
        vm.assume(_trustBonding != address(0));

        GovernanceWrapper newGovernanceWrapperImpl = new GovernanceWrapper();
        TransparentUpgradeableProxy newGovernanceWrapperProxy =
            new TransparentUpgradeableProxy(address(newGovernanceWrapperImpl), users.admin, "");
        GovernanceWrapper newGovernanceWrapper = GovernanceWrapper(address(newGovernanceWrapperProxy));

        vm.prank(_owner);
        newGovernanceWrapper.initialize(_owner, _trustBonding);

        assertEq(newGovernanceWrapper.owner(), _owner);
        assertEq(address(newGovernanceWrapper.trustBonding()), _trustBonding);
    }

    /* =================================================== */
    /*               SET TRUST BONDING TESTS               */
    /* =================================================== */

    function test_setTrustBonding_successful() external {
        address firstTrustBonding = address(0x123);
        vm.prank(owner);
        governanceWrapper.initialize(owner, firstTrustBonding);

        address newTrustBondingAddress = address(protocol.trustBonding);

        vm.prank(owner);
        governanceWrapper.setTrustBonding(newTrustBondingAddress);

        assertEq(address(governanceWrapper.trustBonding()), newTrustBondingAddress);
    }

    function test_setTrustBonding_revertsOnZeroAddress() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_InvalidAddress.selector);
        vm.prank(owner);
        governanceWrapper.setTrustBonding(address(0));
    }

    function test_setTrustBonding_revertsWhenCalledByNonOwner() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert();
        vm.prank(nonOwner);
        governanceWrapper.setTrustBonding(address(protocol.trustBonding));
    }

    function test_setTrustBonding_emitsTrustBondingSetEvent() external {
        address firstTrustBonding = address(0x123);
        vm.prank(owner);
        governanceWrapper.initialize(owner, firstTrustBonding);

        address newTrustBondingAddress = address(protocol.trustBonding);

        vm.expectEmit(true, true, true, true);
        emit IGovernanceWrapper.TrustBondingSet(newTrustBondingAddress);

        vm.prank(owner);
        governanceWrapper.setTrustBonding(newTrustBondingAddress);
    }

    function testFuzz_setTrustBonding(address _trustBonding) external {
        vm.assume(_trustBonding != address(0));

        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(owner);
        governanceWrapper.setTrustBonding(_trustBonding);

        assertEq(address(governanceWrapper.trustBonding()), _trustBonding);
    }

    /* =================================================== */
    /*           ERC20 DISABLED FUNCTION TESTS             */
    /* =================================================== */

    function test_transfer_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.transfer(users.bob, 100 ether);
    }

    function testFuzz_transfer(address to, uint256 amount) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.transfer(to, amount);
    }

    function test_transferFrom_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.transferFrom(users.bob, users.charlie, 100 ether);
    }

    function testFuzz_transferFrom(address from, address to, uint256 amount) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.transferFrom(from, to, amount);
    }

    function test_approve_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_ApprovalsDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.approve(users.bob, 100 ether);
    }

    function testFuzz_approve(address spender, uint256 amount) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_ApprovalsDisabled.selector);
        vm.prank(users.alice);
        governanceWrapper.approve(spender, amount);
    }

    function test_permit_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_PermitDisabled.selector);
        governanceWrapper.permit(
            users.alice, users.bob, 100 ether, block.timestamp + 1 days, 27, bytes32(0), bytes32(0)
        );
    }

    function testFuzz_permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_PermitDisabled.selector);
        governanceWrapper.permit(owner_, spender, value, deadline, v, r, s);
    }

    /* =================================================== */
    /*             ERC20 VIEW FUNCTION TESTS               */
    /* =================================================== */

    function test_name_returnsTrustBondingName() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        string memory expectedName = protocol.trustBonding.name();
        string memory actualName = governanceWrapper.name();

        assertEq(actualName, expectedName);
    }

    function test_symbol_returnsTrustBondingSymbol() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        string memory expectedSymbol = protocol.trustBonding.symbol();
        string memory actualSymbol = governanceWrapper.symbol();

        assertEq(actualSymbol, expectedSymbol);
    }

    function test_decimals_returnsTrustBondingDecimals() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint8 expectedDecimals = protocol.trustBonding.decimals();
        uint8 actualDecimals = governanceWrapper.decimals();

        assertEq(actualDecimals, expectedDecimals);
    }

    function test_totalSupply_returnsTrustBondingTotalSupply() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 expectedSupply = protocol.trustBonding.totalSupply();
        uint256 actualSupply = governanceWrapper.totalSupply();

        assertEq(actualSupply, expectedSupply);
    }

    function test_totalSupply_updatesWithTrustBondingSupply() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 initialSupply = governanceWrapper.totalSupply();

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 newSupply = governanceWrapper.totalSupply();
        assertGt(newSupply, initialSupply);
    }

    function test_balanceOf_returnsTrustBondingBalance() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 expectedBalance = protocol.trustBonding.balanceOf(users.bob);
        uint256 actualBalance = governanceWrapper.balanceOf(users.bob);

        assertEq(actualBalance, expectedBalance);
    }

    function test_balanceOf_updatesWithTrustBondingBalance() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 initialBalance = governanceWrapper.balanceOf(users.bob);
        assertEq(initialBalance, 0);

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 newBalance = governanceWrapper.balanceOf(users.bob);
        assertGt(newBalance, initialBalance);
    }

    function testFuzz_balanceOf(address account) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 expectedBalance = protocol.trustBonding.balanceOf(account);
        uint256 actualBalance = governanceWrapper.balanceOf(account);

        assertEq(actualBalance, expectedBalance);
    }

    /* =================================================== */
    /*                  CLOCK MODE TESTS                   */
    /* =================================================== */

    function test_CLOCK_MODE_returnsCorrectValue() external view {
        string memory clockMode = governanceWrapper.CLOCK_MODE();
        assertEq(clockMode, "mode=blocknumber");
    }

    /* =================================================== */
    /*                    CLOCK TESTS                      */
    /* =================================================== */

    function test_clock_returnsCurrentBlockNumber() external {
        uint256 currentBlockNumber = block.number;
        uint48 clockValue = governanceWrapper.clock();
        assertEq(clockValue, uint48(currentBlockNumber));
    }

    function test_clock_updatesWithBlockNumber() external {
        uint48 initialClock = governanceWrapper.clock();

        vm.roll(block.number + 100);

        uint48 newClock = governanceWrapper.clock();
        assertEq(newClock, initialClock + 100);
    }

    function testFuzz_clock(uint48 blocksToAdvance) external {
        vm.assume(blocksToAdvance > 0);
        vm.assume(block.number + blocksToAdvance < type(uint48).max);

        uint48 initialClock = governanceWrapper.clock();

        vm.roll(block.number + blocksToAdvance);

        uint48 newClock = governanceWrapper.clock();
        assertEq(newClock, initialClock + blocksToAdvance);
    }

    /* =================================================== */
    /*                 GET VOTES TESTS                     */
    /* =================================================== */

    function test_getVotes_returnsZeroWhenNoLock() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 votes = governanceWrapper.getVotes(users.bob);
        assertEq(votes, 0);
    }

    function test_getVotes_returnsCorrectVotingPower() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 expectedVotes = protocol.trustBonding.balanceOf(users.bob);
        uint256 actualVotes = governanceWrapper.getVotes(users.bob);

        assertEq(actualVotes, expectedVotes);
        assertGt(actualVotes, 0);
    }

    function testFuzz_getVotes(address account) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 expectedVotes = protocol.trustBonding.balanceOf(account);
        uint256 actualVotes = governanceWrapper.getVotes(account);

        assertEq(actualVotes, expectedVotes);
    }

    /* =================================================== */
    /*              GET PAST VOTES TESTS                   */
    /* =================================================== */

    function test_getPastVotes_returnsHistoricalVotingPower() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 snapshotBlock = block.number;

        vm.roll(block.number + 1);

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 pastVotes = governanceWrapper.getPastVotes(users.bob, snapshotBlock);
        assertEq(pastVotes, 0);
    }

    function test_getPastVotes_matchesTrustBondingBalanceOfAt() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 snapshotBlock = block.number;

        vm.roll(block.number + 10);

        uint256 expectedPastVotes = protocol.trustBonding.balanceOfAt(users.bob, snapshotBlock);
        uint256 actualPastVotes = governanceWrapper.getPastVotes(users.bob, snapshotBlock);

        assertEq(actualPastVotes, expectedPastVotes);
    }

    function testFuzz_getPastVotes(address account, uint256 blockNumber) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        blockNumber = bound(blockNumber, 0, block.number);

        uint256 expectedPastVotes = protocol.trustBonding.balanceOfAt(account, blockNumber);
        uint256 actualPastVotes = governanceWrapper.getPastVotes(account, blockNumber);

        assertEq(actualPastVotes, expectedPastVotes);
    }

    /* =================================================== */
    /*           GET PAST TOTAL SUPPLY TESTS               */
    /* =================================================== */

    function test_getPastTotalSupply_returnsHistoricalTotalSupply() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 snapshotBlock = block.number;

        vm.roll(block.number + 1);

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 pastTotalSupply = governanceWrapper.getPastTotalSupply(snapshotBlock);
        assertEq(pastTotalSupply, 0);
    }

    function test_getPastTotalSupply_matchesTrustBondingTotalSupplyAt() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 snapshotBlock = block.number;

        vm.roll(block.number + 10);

        uint256 expectedPastTotalSupply = protocol.trustBonding.totalSupplyAt(snapshotBlock);
        uint256 actualPastTotalSupply = governanceWrapper.getPastTotalSupply(snapshotBlock);

        assertEq(actualPastTotalSupply, expectedPastTotalSupply);
    }

    function testFuzz_getPastTotalSupply(uint256 blockNumber) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        blockNumber = bound(blockNumber, 0, block.number);

        uint256 expectedPastTotalSupply = protocol.trustBonding.totalSupplyAt(blockNumber);
        uint256 actualPastTotalSupply = governanceWrapper.getPastTotalSupply(blockNumber);

        assertEq(actualPastTotalSupply, expectedPastTotalSupply);
    }

    /* =================================================== */
    /*                 DELEGATES TESTS                     */
    /* =================================================== */

    function test_delegates_returnsZeroAddressBeforeDelegation() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, address(0));
    }

    function test_delegates_returnsSelfAfterDelegation() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegate(users.bob);

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, users.alice);
    }

    function testFuzz_delegates(address account) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        address delegateeBefore = governanceWrapper.delegates(account);
        assertEq(delegateeBefore, address(0));

        vm.prank(account);
        governanceWrapper.delegate(users.bob);

        address delegateeAfter = governanceWrapper.delegates(account);
        assertEq(delegateeAfter, account);
    }

    /* =================================================== */
    /*                  DELEGATE TESTS                     */
    /* =================================================== */

    function test_delegate_setsSenderAsOwnDelegate() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegate(users.bob);

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, users.alice);
    }

    function test_delegate_ignoresProvidedAddress() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegate(users.charlie);

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, users.alice);
        assertTrue(delegatee != users.charlie);
    }

    function test_delegate_emitsDelegateChangedEvent() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(users.alice, address(0), users.alice);

        vm.prank(users.alice);
        governanceWrapper.delegate(users.bob);
    }

    function test_delegate_emitsDelegateChangedEventWithOldDelegate() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegate(users.bob);

        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(users.alice, users.alice, users.alice);

        vm.prank(users.alice);
        governanceWrapper.delegate(users.charlie);
    }

    function testFuzz_delegate(address providedDelegatee) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegate(providedDelegatee);

        address actualDelegatee = governanceWrapper.delegates(users.alice);
        assertEq(actualDelegatee, users.alice);
    }

    /* =================================================== */
    /*              DELEGATE BY SIG TESTS                  */
    /* =================================================== */

    function test_delegateBySig_setsSenderAsOwnDelegate() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegateBySig(users.bob, 0, 0, 0, bytes32(0), bytes32(0));

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, users.alice);
    }

    function test_delegateBySig_ignoresAllParameters() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegateBySig(users.charlie, 12_345, 67_890, 27, bytes32(uint256(1)), bytes32(uint256(2)));

        address delegatee = governanceWrapper.delegates(users.alice);
        assertEq(delegatee, users.alice);
        assertTrue(delegatee != users.charlie);
    }

    function test_delegateBySig_emitsDelegateChangedEvent() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(users.alice, address(0), users.alice);

        vm.prank(users.alice);
        governanceWrapper.delegateBySig(users.bob, 0, 0, 0, bytes32(0), bytes32(0));
    }

    function testFuzz_delegateBySig(
        address providedDelegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.prank(users.alice);
        governanceWrapper.delegateBySig(providedDelegatee, nonce, expiry, v, r, s);

        address actualDelegatee = governanceWrapper.delegates(users.alice);
        assertEq(actualDelegatee, users.alice);
    }

    /* =================================================== */
    /*                  INTEGRATION TESTS                  */
    /* =================================================== */

    function test_integration_fullSetupAndQueries() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        assertEq(governanceWrapper.owner(), owner);
        assertEq(address(governanceWrapper.trustBonding()), address(protocol.trustBonding));
        assertEq(governanceWrapper.CLOCK_MODE(), "mode=blocknumber");
        assertEq(governanceWrapper.clock(), uint48(block.number));
        assertEq(governanceWrapper.name(), protocol.trustBonding.name());
        assertEq(governanceWrapper.symbol(), protocol.trustBonding.symbol());
        assertEq(governanceWrapper.decimals(), protocol.trustBonding.decimals());
        assertEq(governanceWrapper.totalSupply(), protocol.trustBonding.totalSupply());
    }

    function test_integration_ownershipTransfer() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        address newOwner = users.bob;

        vm.prank(owner);
        governanceWrapper.transferOwnership(newOwner);

        assertEq(governanceWrapper.owner(), newOwner);

        address newTrustBonding = address(0x456);
        vm.prank(newOwner);
        governanceWrapper.setTrustBonding(newTrustBonding);

        assertEq(address(governanceWrapper.trustBonding()), newTrustBonding);
    }

    function test_integration_multipleSetTrustBondingCalls() external {
        address firstTrustBonding = address(protocol.trustBonding);
        vm.prank(owner);
        governanceWrapper.initialize(owner, firstTrustBonding);
        assertEq(address(governanceWrapper.trustBonding()), firstTrustBonding);

        address secondTrustBonding = address(0x123);
        vm.prank(owner);
        governanceWrapper.setTrustBonding(secondTrustBonding);
        assertEq(address(governanceWrapper.trustBonding()), secondTrustBonding);

        address thirdTrustBonding = address(0x456);
        vm.prank(owner);
        governanceWrapper.setTrustBonding(thirdTrustBonding);
        assertEq(address(governanceWrapper.trustBonding()), thirdTrustBonding);
    }

    function test_integration_votingPowerWithMultipleUsers() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 lockAmount1 = 1000 ether;
        uint256 unlockTime1 = block.timestamp + 365 days;

        vm.startPrank(users.bob);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount1);
        protocol.trustBonding.create_lock(lockAmount1, unlockTime1);
        vm.stopPrank();

        uint256 lockAmount2 = 2000 ether;
        uint256 unlockTime2 = block.timestamp + 730 days;

        vm.startPrank(users.charlie);
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount2);
        protocol.trustBonding.create_lock(lockAmount2, unlockTime2);
        vm.stopPrank();

        uint256 bobVotes = governanceWrapper.getVotes(users.bob);
        uint256 charlieVotes = governanceWrapper.getVotes(users.charlie);
        uint256 totalSupply = governanceWrapper.totalSupply();

        assertGt(bobVotes, 0);
        assertGt(charlieVotes, 0);
        assertGt(charlieVotes, bobVotes);
        assertEq(totalSupply, bobVotes + charlieVotes);
    }

    function test_integration_delegationFlow() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        address delegateBefore = governanceWrapper.delegates(users.alice);
        assertEq(delegateBefore, address(0));

        vm.prank(users.alice);
        governanceWrapper.delegate(users.bob);

        address delegateAfter = governanceWrapper.delegates(users.alice);
        assertEq(delegateAfter, users.alice);

        vm.prank(users.alice);
        governanceWrapper.delegateBySig(users.charlie, 0, 0, 0, bytes32(0), bytes32(0));

        address finalDelegate = governanceWrapper.delegates(users.alice);
        assertEq(finalDelegate, users.alice);
    }

    function test_integration_historicalVotingPower() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 blockBeforeLock = block.number;

        vm.roll(block.number + 1);

        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 blockAfterLock = block.number;

        // Advance both block number AND timestamp to see voting power decay
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 100 days);

        uint256 votesBefore = governanceWrapper.getPastVotes(users.bob, blockBeforeLock);
        uint256 votesAfter = governanceWrapper.getPastVotes(users.bob, blockAfterLock);
        uint256 currentVotes = governanceWrapper.getVotes(users.bob);

        assertEq(votesBefore, 0);
        assertGt(votesAfter, 0);
        assertLt(currentVotes, votesAfter);
    }

    function test_integration_allDisabledFunctionsRevert() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        governanceWrapper.transfer(users.bob, 100);

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_TransfersDisabled.selector);
        governanceWrapper.transferFrom(users.alice, users.bob, 100);

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_ApprovalsDisabled.selector);
        governanceWrapper.approve(users.bob, 100);

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_PermitDisabled.selector);
        governanceWrapper.permit(users.alice, users.bob, 100, 0, 0, bytes32(0), bytes32(0));
    }

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
}
