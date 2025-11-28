// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { GovernanceWrapper } from "src/protocol/governance/GovernanceWrapper.sol";
import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { IVotesERC20V1 } from "src/interfaces/external/decent/IVotesERC20V1.sol";

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
    /*          IVOTESERC20V1 INITIALIZE TEST              */
    /* =================================================== */

    function test_initializeVotesERC20V1_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        IVotesERC20V1.Metadata memory metadata = IVotesERC20V1.Metadata({ name: "Test Token", symbol: "TEST" });

        IVotesERC20V1.Allocation[] memory allocations = new IVotesERC20V1.Allocation[](0);

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotInitializeVotesERC20V1.selector);
        governanceWrapper.initialize(metadata, allocations, owner, true, 1000 ether);
    }

    /* =================================================== */
    /*                  CLOCK MODE TESTS                   */
    /* =================================================== */

    function test_CLOCK_MODE_returnsCorrectValue() external view {
        string memory clockMode = governanceWrapper.CLOCK_MODE();
        assertEq(clockMode, "mode=timestamp");
    }

    /* =================================================== */
    /*                    CLOCK TESTS                      */
    /* =================================================== */

    function test_clock_returnsCurrentTimestamp() external {
        uint256 currentTimestamp = block.timestamp;
        uint48 clockValue = governanceWrapper.clock();
        assertEq(clockValue, uint48(currentTimestamp));
    }

    function test_clock_updatesWithTime() external {
        uint48 initialClock = governanceWrapper.clock();

        vm.warp(block.timestamp + 1 days);

        uint48 newClock = governanceWrapper.clock();
        assertEq(newClock, initialClock + 1 days);
    }

    function testFuzz_clock(uint48 timeToAdvance) external {
        vm.assume(timeToAdvance > 0);
        vm.assume(block.timestamp + timeToAdvance < type(uint48).max);

        uint48 initialClock = governanceWrapper.clock();

        vm.warp(block.timestamp + timeToAdvance);

        uint48 newClock = governanceWrapper.clock();
        assertEq(newClock, initialClock + timeToAdvance);
    }

    /* =================================================== */
    /*                   LOCKED TESTS                      */
    /* =================================================== */

    function test_locked_returnsTrue() external view {
        bool isLocked = governanceWrapper.locked();
        assertTrue(isLocked);
    }

    /* =================================================== */
    /*              MINTING RENOUNCED TESTS                */
    /* =================================================== */

    function test_mintingRenounced_returnsTrue() external view {
        bool isMintingRenounced = governanceWrapper.mintingRenounced();
        assertTrue(isMintingRenounced);
    }

    /* =================================================== */
    /*              MAX TOTAL SUPPLY TESTS                 */
    /* =================================================== */

    function test_maxTotalSupply_returnsZeroWhenTrustBondingNotSet() external view {
        uint256 maxSupply = governanceWrapper.maxTotalSupply();
        assertEq(maxSupply, 0);
    }

    function test_maxTotalSupply_returnsCorrectValue() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 expectedSupply = protocol.trustBonding.totalSupply();
        uint256 actualSupply = governanceWrapper.maxTotalSupply();

        assertEq(actualSupply, expectedSupply);
    }

    function test_maxTotalSupply_updatesWithTrustBondingSupply() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        uint256 initialSupply = governanceWrapper.maxTotalSupply();

        _setupUserWrappedTokenAndTrustBonding(users.bob);
        vm.startPrank(users.bob);
        uint256 lockAmount = 1000 ether;
        uint256 unlockTime = block.timestamp + 365 days;
        protocol.wrappedTrust.approve(address(protocol.trustBonding), lockAmount);
        protocol.trustBonding.create_lock(lockAmount, unlockTime);
        vm.stopPrank();

        uint256 newSupply = governanceWrapper.maxTotalSupply();
        assertGt(newSupply, initialSupply);
    }

    /* =================================================== */
    /*               GET UNLOCK TIME TESTS                 */
    /* =================================================== */

    function test_getUnlockTime_returnsZero() external view {
        uint48 unlockTime = governanceWrapper.getUnlockTime();
        assertEq(unlockTime, 0);
    }

    /* =================================================== */
    /*                    LOCK TESTS                       */
    /* =================================================== */

    function test_lock_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotChangeLockStatus.selector);
        governanceWrapper.lock(true);
    }

    function test_lock_revertsWithFalse() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotChangeLockStatus.selector);
        governanceWrapper.lock(false);
    }

    function testFuzz_lock(bool lockStatus) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotChangeLockStatus.selector);
        governanceWrapper.lock(lockStatus);
    }

    /* =================================================== */
    /*             RENOUNCE MINTING TESTS                  */
    /* =================================================== */

    function test_renounceMinting_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotRenounceMinting.selector);
        governanceWrapper.renounceMinting();
    }

    /* =================================================== */
    /*            SET MAX TOTAL SUPPLY TESTS               */
    /* =================================================== */

    function test_setMaxTotalSupply_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotOverrideMaxTotalSupply.selector);
        governanceWrapper.setMaxTotalSupply(1000 ether);
    }

    function testFuzz_setMaxTotalSupply(uint256 newMaxSupply) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_CannotOverrideMaxTotalSupply.selector);
        governanceWrapper.setMaxTotalSupply(newMaxSupply);
    }

    /* =================================================== */
    /*                    MINT TESTS                       */
    /* =================================================== */

    function test_mint_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_MintingIsNotAllowed.selector);
        governanceWrapper.mint(users.alice, 100 ether);
    }

    function testFuzz_mint(address to, uint256 amount) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_MintingIsNotAllowed.selector);
        governanceWrapper.mint(to, amount);
    }

    /* =================================================== */
    /*                    BURN TESTS                       */
    /* =================================================== */

    function test_burn_revertsAlways() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_BurningIsNotAllowed.selector);
        governanceWrapper.burn(100 ether);
    }

    function testFuzz_burn(uint256 amount) external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        vm.expectRevert(IGovernanceWrapper.GovernanceWrapper_BurningIsNotAllowed.selector);
        governanceWrapper.burn(amount);
    }

    /* =================================================== */
    /*                  INTEGRATION TESTS                  */
    /* =================================================== */

    function test_integration_fullSetupAndQueries() external {
        vm.prank(owner);
        governanceWrapper.initialize(owner, address(protocol.trustBonding));

        assertEq(governanceWrapper.owner(), owner);
        assertEq(address(governanceWrapper.trustBonding()), address(protocol.trustBonding));
        assertEq(governanceWrapper.CLOCK_MODE(), "mode=timestamp");
        assertEq(governanceWrapper.clock(), uint48(block.timestamp));
        assertTrue(governanceWrapper.locked());
        assertTrue(governanceWrapper.mintingRenounced());
        assertEq(governanceWrapper.getUnlockTime(), 0);
        assertEq(governanceWrapper.maxTotalSupply(), protocol.trustBonding.totalSupply());
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
    }
}
