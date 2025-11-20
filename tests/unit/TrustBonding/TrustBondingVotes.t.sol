// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console, Vm } from "forge-std/src/Test.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC6372 } from "@openzeppelin/contracts/interfaces/IERC6372.sol";

import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";

contract TrustBondingVotesTest is TrustBondingBase {
    TrustBonding internal trustBonding;

    function setUp() public virtual override {
        super.setUp();
        trustBonding = TrustBonding(address(protocol.trustBonding));
    }

    /*//////////////////////////////////////////////////////////////
                            GETVOTES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getVotes_returnsZero_whenUserHasNoLock() public {
        address userAddress = address(0x1234);

        uint256 votes = trustBonding.getVotes(userAddress);

        assertEq(votes, 0, "Votes must be zero for user without any lock");
    }

    function test_getVotes_matchesVotingEscrowBalance_whenUserHasLock() public {
        address userAddress = users.alice;

        // Create a lock for the user
        uint256 unlockTime = _calculateUnlockTime(DEFAULT_LOCK_DURATION);
        _createLockWithDuration(userAddress, initialTokens, unlockTime);

        // getVotes should equal current VotingEscrow balance
        uint256 votes = trustBonding.getVotes(userAddress);
        uint256 currentBalance = trustBonding.balanceOf(userAddress);

        assertEq(votes, currentBalance, "getVotes must equal current veTRUST (VotingEscrow) balance");
    }

    /*//////////////////////////////////////////////////////////////
                         GETPASTVOTES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPastVotes_revertsWhenTimepointIsInFuture() public {
        address userAddress = users.alice;

        vm.expectRevert(ITrustBonding.TrustBonding_TimepointMustBeInPast.selector);
        trustBonding.getPastVotes(userAddress, block.timestamp);
    }

    function test_getPastVotes_returnsZero_whenNoLockAtThatTime() public {
        address userAddress = address(0xBEEF);

        // Choose an arbitrary timestamp in the past
        vm.warp(1_000_000);
        uint256 snapshotTime = block.timestamp;
        vm.warp(snapshotTime + 1);

        uint256 pastVotes = trustBonding.getPastVotes(userAddress, snapshotTime);

        assertEq(pastVotes, 0, "Past votes must be zero for user with no lock history");
    }

    function test_getPastVotes_returnsPositiveValue_whenUserHadLockAtThatTime() public {
        address userAddress = users.alice;

        vm.warp(1_000_000);

        // Create a lock at current timestamp
        uint256 unlockTime = _calculateUnlockTime(DEFAULT_LOCK_DURATION);
        _createLockWithDuration(userAddress, initialTokens, unlockTime);

        uint256 snapshotTime = block.timestamp;

        // Move forward so that snapshotTime is strictly in the past
        vm.warp(snapshotTime + 1);

        uint256 pastVotes = trustBonding.getPastVotes(userAddress, snapshotTime);

        assertGt(pastVotes, 0, "Past votes must be positive when user had an active lock at that time");
    }

    /*//////////////////////////////////////////////////////////////
                     GETPASTTOTALSUPPLY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getPastTotalSupply_revertsWhenTimepointIsInFuture() public {
        vm.expectRevert(ITrustBonding.TrustBonding_TimepointMustBeInPast.selector);
        trustBonding.getPastTotalSupply(block.timestamp);
    }

    function test_getPastTotalSupply_returnsZero_whenNoSupplyAtThatTime() public {
        // Warp far into the future, but query time = 0 (before any locks)
        vm.warp(10_000_000);

        uint256 pastTotalSupply = trustBonding.getPastTotalSupply(0);

        assertEq(pastTotalSupply, 0, "Past total supply must be zero before any locks exist");
    }

    function test_getPastTotalSupply_isAtLeastUserVotes_whenUserHasLock() public {
        address userAddress = users.alice;

        vm.warp(2_000_000);

        uint256 unlockTime = _calculateUnlockTime(DEFAULT_LOCK_DURATION);
        _createLockWithDuration(userAddress, initialTokens, unlockTime);

        uint256 snapshotTime = block.timestamp;
        vm.warp(snapshotTime + 5);

        uint256 userVotes = trustBonding.getPastVotes(userAddress, snapshotTime);
        uint256 totalVotes = trustBonding.getPastTotalSupply(snapshotTime);

        assertLe(userVotes, totalVotes, "User past votes cannot exceed past total supply at the same timepoint");
    }

    /*//////////////////////////////////////////////////////////////
                         DELEGATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_delegates_returnsSelfForAnyAccount() public {
        address userAddressWithLock = users.alice;
        address userAddressWithoutLock = address(0xCAFE);

        address delegateForLockedUser = trustBonding.delegates(userAddressWithLock);
        address delegateForUnlockedUser = trustBonding.delegates(userAddressWithoutLock);

        assertEq(delegateForLockedUser, userAddressWithLock, "delegates must equal the account itself for locked users");
        assertEq(
            delegateForUnlockedUser,
            userAddressWithoutLock,
            "delegates must equal the account itself for users without a lock"
        );
    }

    function test_delegate_allowsSelfDelegationWithoutRevert() public {
        address userAddress = users.alice;

        vm.startPrank(userAddress);
        trustBonding.delegate(userAddress);
        vm.stopPrank();
    }

    function test_delegate_revertsWhenDelegatingToAnotherAccount() public {
        address userAddress = users.alice;
        address otherAddress = users.bob;

        vm.startPrank(userAddress);
        vm.expectRevert(ITrustBonding.TrustBonding_DelegationNotSupported.selector);
        trustBonding.delegate(otherAddress);
        vm.stopPrank();
    }

    function test_delegateBySig_alwaysRevertsWithDelegationNotSupported() public {
        // Parameters are irrelevant; function always reverts
        vm.expectRevert(ITrustBonding.TrustBonding_DelegationNotSupported.selector);
        trustBonding.delegateBySig(users.bob, 0, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
    }

    function test_delegate_selfDelegationDoesNotEmitDelegateEvents() public {
        address userAddress = users.alice;

        vm.startPrank(userAddress);
        vm.recordLogs();
        trustBonding.delegate(userAddress);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        bytes32 delegateChangedTopic = keccak256("DelegateChanged(address,address,address)");
        bytes32 delegateVotesChangedTopic = keccak256("DelegateVotesChanged(address,uint256,uint256)");

        for (uint256 index = 0; index < logs.length; index++) {
            Vm.Log memory logEntry = logs[index];

            if (logEntry.topics.length == 0) {
                continue;
            }

            bytes32 topic0 = logEntry.topics[0];

            assertTrue(
                topic0 != delegateChangedTopic && topic0 != delegateVotesChangedTopic,
                "Delegate events must not be emitted by TrustBonding.delegate"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                     IERC6372 CLOCK / MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_clock_returnsCurrentTimestampAsUint48() public {
        vm.warp(5_000_000);

        uint256 currentTimestamp = block.timestamp;
        uint48 clockValue = trustBonding.clock();

        assertEq(clockValue, uint48(currentTimestamp), "clock() must return block.timestamp truncated to uint48");
    }

    function test_clock_increasesMonotonicallyWhenTimeAdvances() public {
        vm.warp(7_000_000);
        uint48 clockBefore = trustBonding.clock();

        vm.warp(7_000_010);
        uint48 clockAfter = trustBonding.clock();

        assertGt(clockAfter, clockBefore, "clock() value must increase when time advances");
    }

    function test_CLOCK_MODE_isTimestampMode() public {
        string memory clockMode = trustBonding.CLOCK_MODE();
        assertEq(clockMode, "mode=timestamp", "CLOCK_MODE must be 'mode=timestamp'");
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getPastVotes_neverExceedsPastTotalSupply(address userAddress, uint48 secondsAgo) public {
        // Ensure we have a non-zero current time
        vm.warp(10_000_000);
        uint256 currentTimestamp = block.timestamp;

        uint256 offset = uint256(secondsAgo);
        if (offset == 0) {
            offset = 1;
        }
        if (offset >= currentTimestamp) {
            offset = currentTimestamp - 1;
        }

        uint256 timepoint = currentTimestamp - offset;

        uint256 userVotes = trustBonding.getPastVotes(userAddress, timepoint);
        uint256 totalVotes = trustBonding.getPastTotalSupply(timepoint);

        assertLe(userVotes, totalVotes, "getPastVotes must never exceed getPastTotalSupply for the same timepoint");
    }

    function testFuzz_getVotes_neverExceedsCurrentTotalSupply(address userAddress) public {
        // This is a simple sanity property:
        // getVotes(user) <= total supply at current timestamp
        vm.warp(20_000_000);

        uint256 userVotes = trustBonding.getVotes(userAddress);
        uint256 currentTotalSupply = trustBonding.totalBondedBalance();

        assertLe(userVotes, currentTotalSupply, "Current user votes must not exceed total bonded balance");
    }
}
