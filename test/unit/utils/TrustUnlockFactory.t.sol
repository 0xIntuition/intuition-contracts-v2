// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/*//////////////////////////////////////////////////////////////
                         IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test, console} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";
import {TrustUnlockFactory} from "src/v2/TrustUnlockFactory.sol";
import {TrustUnlock} from "src/v2/TrustUnlock.sol";

import {MockTrust} from "test/mocks/MockTrust.t.sol";

/*//////////////////////////////////////////////////////////////
                      TEST CONTRACT
//////////////////////////////////////////////////////////////*/

contract TrustUnlockFactoryTest is Test {
    /*//////////////////////////////////////////////////////////////
                              STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Contracts
    TrustUnlockFactory public factory;
    TrustBonding public trustBonding;
    MockTrust public trustToken;

    /// @notice Addresses
    address public owner = makeAddr("owner");
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public rescueAcct = makeAddr("rescuer");

    /// @notice TrustUnlock config
    uint256 public constant UNLOCK_AMOUNT = 500_000 * 1e18;
    uint256 public constant BASIS_POINTS_DIV = 10_000;
    uint256 public constant CLIFF_PCT = 2_500; // 25 %
    uint256 public constant ONE_WEEK = 1 weeks;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public unlockBegin;
    uint256 public unlockCliff;
    uint256 public unlockEnd;

    /// @notice TrustBonding config
    uint256 epochLength = 2 * ONE_WEEK;
    uint256 startTime = block.timestamp + 1 days;

    /*//////////////////////////////////////////////////////////////
                             SET-UP
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        vm.startPrank(deployer);

        // 1. Deploy mock TRUST
        trustToken = new MockTrust("Intuition", "TRUST", type(uint256).max);
        trustToken.mint(address(deployer), type(uint96).max); // mint tokens to deployer

        // 2. Deploy TrustBonding proxy
        TrustBonding logic = new TrustBonding();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), owner, "");
        trustBonding = TrustBonding(address(proxy));
        trustBonding.initialize(owner, address(trustToken), 14 days, block.timestamp + 1 hours);

        // 3. Deploy factory, fund it with tokens
        factory = new TrustUnlockFactory(address(trustToken), owner, address(trustBonding));
        trustToken.transfer(address(factory), UNLOCK_AMOUNT * 3);

        // 4. Common schedule example
        unlockBegin = block.timestamp + 1 days;
        unlockCliff = unlockBegin + ONE_YEAR;
        unlockEnd = unlockBegin + 3 * ONE_YEAR;

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_factoryDeploymentParams() external view {
        assertEq(address(factory.trustToken()), address(trustToken));
        assertEq(factory.trustBonding(), address(trustBonding));
        assertEq(factory.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                       createTrustUnlock()
    //////////////////////////////////////////////////////////////*/

    function test_createTrustUnlock_deploysAndFunds() external {
        vm.startPrank(owner);

        factory.createTrustUnlock(alice, UNLOCK_AMOUNT, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        address vesting = factory.trustUnlocks(alice);
        assertTrue(vesting != address(0), "vesting not recorded");

        _checkHasCode(vesting); // check that the code size is > 0

        assertEq(trustToken.balanceOf(vesting), UNLOCK_AMOUNT);
        assertEq(trustToken.balanceOf(address(factory)), UNLOCK_AMOUNT * 2);

        // basic smoke-check on vesting params
        assertEq(TrustUnlock(vesting).recipient(), alice);
        assertEq(TrustUnlock(vesting).unlockAmount(), UNLOCK_AMOUNT);
        assertEq(TrustUnlock(vesting).unlockBegin(), unlockBegin);

        vm.stopPrank();
    }

    function test_createTrustUnlock_revertIfExists() external {
        vm.startPrank(owner);

        factory.createTrustUnlock(alice, UNLOCK_AMOUNT, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_TrustUnlockAlreadyExists.selector));
        factory.createTrustUnlock(alice, UNLOCK_AMOUNT, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        vm.stopPrank();
    }

    function test_createTrustUnlock_revertIfInsufficientBalance() external {
        vm.startPrank(owner);

        // Drain factory first.
        factory.recoverTokens(address(trustToken), owner);

        vm.expectRevert(); // exact selector checked inside helper
        factory.createTrustUnlock(bob, UNLOCK_AMOUNT, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    batchCreateTrustUnlock()
    //////////////////////////////////////////////////////////////*/

    function test_batchCreateTrustUnlock_happyPath() external {
        vm.startPrank(owner);

        address[] memory recips = new address[](2);
        uint256[] memory amts = new uint256[](2);
        recips[0] = bob;
        recips[1] = charlie;
        amts[0] = UNLOCK_AMOUNT;
        amts[1] = UNLOCK_AMOUNT;

        factory.batchCreateTrustUnlock(recips, amts, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        address vestingBob = factory.trustUnlocks(bob);
        address vestingCharlie = factory.trustUnlocks(charlie);

        assertTrue(vestingBob != address(0), "vesting not recorded");
        assertTrue(vestingCharlie != address(0), "vesting not recorded");
        _checkHasCode(vestingBob); // check that the code size is > 0
        _checkHasCode(vestingCharlie); // check that the code size is > 0

        assertEq(trustToken.balanceOf(factory.trustUnlocks(bob)), UNLOCK_AMOUNT);
        assertEq(trustToken.balanceOf(factory.trustUnlocks(charlie)), UNLOCK_AMOUNT);
        assertEq(trustToken.balanceOf(address(factory)), UNLOCK_AMOUNT); // one left

        vm.stopPrank();
    }

    function test_batchCreateTrustUnlock_revertZeroLength() external {
        vm.startPrank(owner);
        address[] memory recips;
        uint256[] memory amts;
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroLengthArray.selector));
        factory.batchCreateTrustUnlock(recips, amts, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);
        vm.stopPrank();
    }

    function test_batchCreateTrustUnlock_revertLengthMismatch() external {
        vm.startPrank(owner);
        address[] memory recips = new address[](1);
        uint256[] memory amts = new uint256[](2);
        recips[0] = bob;
        amts[0] = UNLOCK_AMOUNT;
        amts[1] = UNLOCK_AMOUNT;
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ArrayLengthMismatch.selector));
        factory.batchCreateTrustUnlock(recips, amts, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        recoverTokens()
    //////////////////////////////////////////////////////////////*/

    function test_recoverTokens_happyPath() external {
        vm.startPrank(owner);

        uint256 preBal = trustToken.balanceOf(rescueAcct);
        uint256 toRecover = trustToken.balanceOf(address(factory));

        factory.recoverTokens(address(trustToken), rescueAcct);

        assertEq(trustToken.balanceOf(rescueAcct), preBal + toRecover);
        assertEq(trustToken.balanceOf(address(factory)), 0);

        vm.stopPrank();
    }

    function test_recoverTokens_revertWhenTokenIsZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        factory.recoverTokens(address(0), rescueAcct);
        vm.stopPrank();
    }

    function test_recoverTokens_revertWhenRecipientIsZeroAddress() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unlock_ZeroAddress.selector));
        factory.recoverTokens(address(trustToken), address(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     ACCESS-CONTROL GUARDS
    //////////////////////////////////////////////////////////////*/

    function test_onlyOwnerProtectedFunctions() external {
        vm.startPrank(alice);

        address[] memory recips = new address[](0);
        uint256[] memory amts = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        factory.createTrustUnlock(alice, UNLOCK_AMOUNT, unlockBegin, unlockCliff, unlockEnd, CLIFF_PCT);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        factory.batchCreateTrustUnlock(recips, amts, 0, 0, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        factory.recoverTokens(address(trustToken), rescueAcct);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkHasCode(address _address) internal view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_address)
        }
        assertTrue(codeSize > 0, "address has no code --> not a contract");
    }
}
