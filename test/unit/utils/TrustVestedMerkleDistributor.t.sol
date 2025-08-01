// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TrustVestedMerkleDistributor} from "src/v2/TrustVestedMerkleDistributor.sol";
import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract MockTrustBonding {
    using SafeERC20 for IERC20;

    uint256 public constant MAXTIME = 2 * 365 * 86400;
    uint256 public constant MINTIME = 2 weeks;

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    IERC20 public immutable token;
    mapping(address => LockedBalance) public locked;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function create_lock_for(address _addr, uint256 _value, uint256 _unlock_time) external {
        token.safeTransferFrom(msg.sender, address(this), _value);
        locked[_addr] = LockedBalance({amount: int128(int256(_value)), end: _unlock_time});
    }

    function deposit_for(address _addr, uint256 _value) external {
        LockedBalance storage lockedBalance = locked[_addr];
        require(lockedBalance.amount > 0, "No locked balance");
        token.safeTransferFrom(msg.sender, address(this), _value);
        lockedBalance.amount += int128(int256(_value));
    }
}

contract TrustVestedMerkleDistributorTest is Test {
    using SafeERC20 for IERC20;

    /// @notice Test actors
    address public constant OWNER = address(0x1);
    address public constant PROTOCOL_TREASURY = address(0x2);
    address public constant ALICE = address(0x3);
    address public constant BOB = address(0x4);
    address public constant CAROL = address(0x5);
    address public constant DAVE = address(0x6);

    /// @notice Core contracts
    MockTrust public trustToken;
    MockTrustBonding public trustBonding;
    TrustVestedMerkleDistributor public distributor;
    ProxyAdmin public proxyAdmin;

    /// @notice Configuration constants
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = 1e8 * 1e18;
    uint256 public constant INITIAL_MINT = 10_000e18;
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant TGE_BPS = 2500; // 25%
    uint256 public constant RAGE_QUIT_BPS = 4000; // 40%
    uint256 public constant VESTING_DURATION = 365 days;

    /// @notice Time configuration
    uint256 public vestingStartTimestamp;
    uint256 public claimEndTimestamp;

    /// @notice Merkle tree data
    bytes32 public merkleRoot;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public carolProof;
    bytes32[] public daveProof;

    /// @notice User allocations
    uint256 public constant ALICE_ALLOCATION = 1_000e18;
    uint256 public constant BOB_ALLOCATION = 2_000e18;
    uint256 public constant CAROL_ALLOCATION = 3_000e18;
    uint256 public constant DAVE_ALLOCATION = 500e18;

    function setUp() public {
        vm.startPrank(OWNER);

        trustToken = new MockTrust("Intuition", "TRUST", MAX_POSSIBLE_ANNUAL_EMISSION);
        trustToken.mint(OWNER, INITIAL_MINT);
        trustBonding = new MockTrustBonding(address(trustToken));

        _generateMerkleTree();

        proxyAdmin = new ProxyAdmin(msg.sender);
        TrustVestedMerkleDistributor implementation = new TrustVestedMerkleDistributor();
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), "");
        distributor = TrustVestedMerkleDistributor(address(proxy));

        vestingStartTimestamp = block.timestamp + 1 days;
        claimEndTimestamp = vestingStartTimestamp + VESTING_DURATION + 30 days;

        TrustVestedMerkleDistributor.VestingParams memory params = TrustVestedMerkleDistributor.VestingParams({
            owner: OWNER,
            trust: address(trustToken),
            trustBonding: address(trustBonding),
            protocolTreasury: PROTOCOL_TREASURY,
            feeInBPS: FEE_BPS,
            vestingStartTimestamp: vestingStartTimestamp,
            vestingDuration: VESTING_DURATION,
            claimEndTimestamp: claimEndTimestamp,
            tgeBPS: TGE_BPS,
            rageQuitBPS: RAGE_QUIT_BPS,
            merkleRoot: merkleRoot
        });

        distributor.initialize(params);
        trustToken.transfer(address(distributor), INITIAL_MINT);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialState() public view {
        assertEq(address(distributor.trust()), address(trustToken));
        assertEq(address(distributor.trustBonding()), address(trustBonding));
        assertEq(distributor.protocolTreasury(), PROTOCOL_TREASURY);
        assertEq(distributor.feeInBPS(), FEE_BPS);
        assertEq(distributor.merkleRoot(), merkleRoot);
        assertEq(distributor.vestingStartTimestamp(), vestingStartTimestamp);
        assertEq(distributor.vestingDuration(), VESTING_DURATION);
        assertEq(distributor.claimEndTimestamp(), claimEndTimestamp);
        assertEq(distributor.tgeBPS(), TGE_BPS);
        assertEq(distributor.rageQuitBPS(), RAGE_QUIT_BPS);
        assertEq(distributor.owner(), OWNER);
    }

    function test_initialize_revertsOnZeroOwner() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.owner = address(0);

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroTrust() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.trust = address(0);

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroTrustBonding() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.trustBonding = address(0);

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroProtocolTreasury() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.protocolTreasury = address(0);

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnExcessiveFee() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.feeInBPS = 1001; // > MAX_FEE_IN_BPS

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidFeeInBPS.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroMerkleRoot() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.merkleRoot = bytes32(0);

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroVestingStart() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.vestingStartTimestamp = 0;

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnVestingStartInPast() public {
        _deployFreshDistributor();
        vm.warp(block.timestamp + 1 days); // warp to ensure block.timestamp is not zero
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.vestingStartTimestamp = block.timestamp - 1;

        vm.expectRevert(TrustVestedMerkleDistributor.VestingStartInThePast.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroVestingDuration() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.vestingDuration = 0;

        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnInvalidClaimEnd() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.claimEndTimestamp = params.vestingStartTimestamp + params.vestingDuration; // Should be >

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidClaimEnd.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnZeroTgeBPS() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.tgeBPS = 0;

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidPercentageBPS.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnTgeBPSEqualToMax() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.tgeBPS = 10_000;

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidPercentageBPS.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnRageQuitBPSLessOrEqualTgeBPS() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.rageQuitBPS = params.tgeBPS; // Should be >

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidPercentageBPS.selector);
        distributor.initialize(params);
    }

    function test_initialize_revertsOnRageQuitBPSEqualToMax() public {
        _deployFreshDistributor();
        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.rageQuitBPS = 10_000;

        vm.expectRevert(TrustVestedMerkleDistributor.InvalidPercentageBPS.selector);
        distributor.initialize(params);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIMABLE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getClaimableAmount_beforeVestingStart() public view {
        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        uint256 expected = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        assertEq(claimable, expected);
    }

    function test_getClaimableAmount_afterTGE() public {
        // Claim TGE portion
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        assertEq(claimable, 0); // No more claimable before vesting starts
    }

    function test_getClaimableAmount_duringVesting() public {
        // Claim TGE first
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Move to halfway through vesting
        vm.warp(vestingStartTimestamp + VESTING_DURATION / 2);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 remaining = ALICE_ALLOCATION - immediate;
        uint256 expectedVested = remaining / 2; // Half of remaining should be vested

        assertEq(claimable, expectedVested);
    }

    function test_getClaimableAmount_afterVestingEnd() public {
        // Claim TGE first
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Move past vesting end
        vm.warp(vestingStartTimestamp + VESTING_DURATION + 1);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedRemaining = ALICE_ALLOCATION - immediate;

        assertEq(claimable, expectedRemaining);
    }

    function test_getClaimableAmount_afterClaimEnd() public {
        // Claim TGE first
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Move past claim end
        vm.warp(claimEndTimestamp + 1);

        vm.expectRevert(TrustVestedMerkleDistributor.ClaimClosed.selector);
        distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
    }

    function test_getClaimableAmount_lateInitialClaim() public {
        // Move past vesting start without claiming TGE
        vm.warp(vestingStartTimestamp + 1);

        vm.expectRevert(TrustVestedMerkleDistributor.LateInitialClaim.selector);
        distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
    }

    function test_getClaimableAmount_afterRageQuit() public {
        vm.prank(ALICE);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);

        vm.warp(vestingStartTimestamp + VESTING_DURATION / 2);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        assertEq(claimable, 0); // No more claimable after rage quit
    }

    function test_getClaimableAmount_fullyClaimedUser() public {
        // Claim TGE
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Move to end of vesting and claim all
        vm.warp(vestingStartTimestamp + VESTING_DURATION);
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        assertEq(claimable, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claim_tgeOnly() public {
        uint256 initialBalance = trustToken.balanceOf(ALICE);
        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedFee = (immediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = immediate - expectedFee;

        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        assertEq(trustToken.balanceOf(ALICE), initialBalance + expectedNet);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee);

        (uint256 lastClaim, uint256 amountClaimed, bool rageQuit) = distributor.userClaims(ALICE);
        assertEq(lastClaim, block.timestamp);
        assertEq(amountClaimed, immediate);
        assertFalse(rageQuit);
    }

    function test_claim_duringVesting() public {
        // First claim TGE
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        uint256 balanceAfterTGE = trustToken.balanceOf(ALICE);
        uint256 treasuryAfterTGE = trustToken.balanceOf(PROTOCOL_TREASURY);

        // Move to middle of vesting and claim again
        vm.warp(vestingStartTimestamp + VESTING_DURATION / 2);

        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 remaining = ALICE_ALLOCATION - immediate;
        uint256 expectedVested = remaining / 2;
        uint256 expectedFee = (expectedVested * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = expectedVested - expectedFee;

        assertEq(trustToken.balanceOf(ALICE), balanceAfterTGE + expectedNet);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), treasuryAfterTGE + expectedFee);
    }

    function test_claim_revertsWithInvalidProof() public {
        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.InvalidMerkleProof.selector);
        distributor.claim(ALICE_ALLOCATION, bobProof); // Wrong proof
    }

    function test_claim_revertsWithZeroUser() public {
        vm.prank(address(0));
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.claim(ALICE_ALLOCATION, aliceProof);
    }

    function test_claim_revertsWithZeroAmount() public {
        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.claim(0, aliceProof);
    }

    function test_claim_revertsWhenNoTokensToClaim() public {
        // Claim everything first
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        vm.warp(vestingStartTimestamp + VESTING_DURATION);
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Try to claim again
        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.NoTokensToClaim.selector);
        distributor.claim(ALICE_ALLOCATION, aliceProof);
    }

    function test_claim_revertsWhenPaused() public {
        vm.prank(OWNER);
        distributor.pause();

        vm.prank(ALICE);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        distributor.claim(ALICE_ALLOCATION, aliceProof);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM AND BOND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimAndBond_successful() public {
        uint256 unlockTime = block.timestamp + 365 days;
        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedFee = (immediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = immediate - expectedFee;

        vm.prank(ALICE);
        distributor.claimAndBond(ALICE_ALLOCATION, unlockTime, aliceProof);

        (int128 lockedBalance, uint256 lockEnd) = trustBonding.locked(ALICE);

        assertEq(trustToken.balanceOf(ALICE), 0); // Should be bonded, not transferred
        assertEq(uint256(uint128(lockedBalance)), expectedNet);
        assertEq(lockEnd, unlockTime);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee);
    }

    function test_claimAndBond_revertsWithInvalidUnlockTime() public {
        uint256 invalidUnlockTime = block.timestamp; // Current time

        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.InvalidUnlockTime.selector);
        distributor.claimAndBond(ALICE_ALLOCATION, invalidUnlockTime, aliceProof);
    }

    function test_claimAndBond_revertsWhenPaused() public {
        vm.prank(OWNER);
        distributor.pause();

        uint256 unlockTime = block.timestamp + 365 days;
        vm.prank(ALICE);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        distributor.claimAndBond(ALICE_ALLOCATION, unlockTime, aliceProof);
    }

    /*//////////////////////////////////////////////////////////////
                            RAGE QUIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_rageQuit_successful() public {
        uint256 expectedImmediate = (ALICE_ALLOCATION * RAGE_QUIT_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedForfeited = ALICE_ALLOCATION - expectedImmediate;
        uint256 expectedFee = (expectedImmediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = expectedImmediate - expectedFee;

        vm.prank(ALICE);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);

        assertEq(trustToken.balanceOf(ALICE), expectedNet);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee + expectedForfeited);

        (uint256 lastClaim, uint256 amountClaimed, bool rageQuit) = distributor.userClaims(ALICE);
        assertEq(lastClaim, block.timestamp);
        assertEq(amountClaimed, ALICE_ALLOCATION); // Marked as fully claimed
        assertTrue(rageQuit);
    }

    function test_rageQuit_revertsOnSecondAttempt() public {
        vm.prank(ALICE);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);

        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.AlreadyRageQuit.selector);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);
    }

    function test_rageQuit_revertsIfAlreadyClaimed() public {
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.AlreadyClaimed.selector);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);
    }

    function test_rageQuit_revertsWhenPaused() public {
        vm.prank(OWNER);
        distributor.pause();

        vm.prank(ALICE);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        distributor.rageQuit(ALICE_ALLOCATION, aliceProof);
    }

    /*//////////////////////////////////////////////////////////////
                            RAGE QUIT AND BOND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_rageQuitAndBond_successful() public {
        uint256 unlockTime = block.timestamp + 365 days;
        uint256 expectedImmediate = (ALICE_ALLOCATION * RAGE_QUIT_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedForfeited = ALICE_ALLOCATION - expectedImmediate;
        uint256 expectedFee = (expectedImmediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = expectedImmediate - expectedFee;

        vm.prank(ALICE);
        distributor.rageQuitAndBond(ALICE_ALLOCATION, unlockTime, aliceProof);

        (int128 lockedBalance, uint256 lockEnd) = trustBonding.locked(ALICE);

        assertEq(trustToken.balanceOf(ALICE), 0); // Should be bonded
        assertEq(uint256(uint128(lockedBalance)), expectedNet);
        assertEq(lockEnd, unlockTime);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee + expectedForfeited);

        (, uint256 amountClaimed, bool rageQuit) = distributor.userClaims(ALICE);
        assertTrue(rageQuit);
        assertEq(amountClaimed, ALICE_ALLOCATION);
    }

    function test_rageQuitAndBond_revertsWithInvalidUnlockTime() public {
        uint256 invalidUnlockTime = block.timestamp;

        vm.prank(ALICE);
        vm.expectRevert(TrustVestedMerkleDistributor.InvalidUnlockTime.selector);
        distributor.rageQuitAndBond(ALICE_ALLOCATION, invalidUnlockTime, aliceProof);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setTrustBonding_successful() public {
        MockTrustBonding newBonding = new MockTrustBonding(address(trustToken));

        vm.prank(OWNER);
        distributor.setTrustBonding(address(newBonding));

        assertEq(address(distributor.trustBonding()), address(newBonding));
    }

    function test_setTrustBonding_revertsOnZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.setTrustBonding(address(0));
    }

    function test_setTrustBonding_revertsWhenNotOwner() public {
        MockTrustBonding newBonding = new MockTrustBonding(address(trustToken));

        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ALICE));
        distributor.setTrustBonding(address(newBonding));
    }

    function test_setProtocolTreasury_successful() public {
        address newTreasury = address(0x999);

        vm.prank(OWNER);
        distributor.setProtocolTreasury(newTreasury);

        assertEq(distributor.protocolTreasury(), newTreasury);
    }

    function test_setProtocolTreasury_revertsOnZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.setProtocolTreasury(address(0));
    }

    function test_setFeeInBPS_successful() public {
        uint256 newFee = 300; // 3%

        vm.prank(OWNER);
        distributor.setFeeInBPS(newFee);

        assertEq(distributor.feeInBPS(), newFee);
    }

    function test_setFeeInBPS_revertsOnExcessiveFee() public {
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.InvalidFeeInBPS.selector);
        distributor.setFeeInBPS(1001); // > MAX_FEE_IN_BPS
    }

    function test_setVestingStartTimestamp_successful() public {
        uint256 newStart = block.timestamp + 2 days;

        vm.prank(OWNER);
        distributor.setVestingStartTimestamp(newStart);

        assertEq(distributor.vestingStartTimestamp(), newStart);
    }

    function test_setVestingStartTimestamp_revertsOnZero() public {
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.setVestingStartTimestamp(0);
    }

    function test_setVestingStartTimestamp_revertsIfVestingAlreadyStarted() public {
        vm.warp(vestingStartTimestamp + 1);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.VestingAlreadyStarted.selector);
        distributor.setVestingStartTimestamp(block.timestamp + 1 days);
    }

    function test_setVestingStartTimestamp_revertsIfInPast() public {
        vm.warp(block.timestamp + 1 days - 1); // Ensure block.timestamp is not zero

        // Create a simple merkle tree for this user
        bytes32 leaf = keccak256(abi.encodePacked(ALICE, ALICE_ALLOCATION));

        _deployFreshDistributorWithRoot(leaf);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.VestingStartInThePast.selector);
        distributor.setVestingStartTimestamp(block.timestamp - 1);
    }

    function test_setClaimEndTimestamp_successful() public {
        uint256 newEnd = claimEndTimestamp + 10 days;

        vm.prank(OWNER);
        distributor.setClaimEndTimestamp(newEnd);

        assertEq(distributor.claimEndTimestamp(), newEnd);
    }

    function test_setClaimEndTimestamp_revertsOnInvalidEnd() public {
        uint256 invalidEnd = vestingStartTimestamp + VESTING_DURATION; // Should be >

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.InvalidClaimEnd.selector);
        distributor.setClaimEndTimestamp(invalidEnd);
    }

    function test_setClaimEndTimestamp_revertsIfInPast() public {
        vm.warp(vestingStartTimestamp + VESTING_DURATION + 1 days); // Ensure claim end is in the past
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.VestingEndInThePast.selector);
        distributor.setClaimEndTimestamp(block.timestamp - 1);
    }

    function test_setClaimEndTimestamp_revertsIfCannotShortenWindow() public {
        vm.warp(vestingStartTimestamp + 1); // After vesting starts

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.CannotShortenClaimWindow.selector);
        distributor.setClaimEndTimestamp(claimEndTimestamp - 1 days);
    }

    function test_setClaimEndTimestamp_revertsIfClaimClosed() public {
        vm.warp(claimEndTimestamp + 1);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ClaimClosed.selector);
        distributor.setClaimEndTimestamp(claimEndTimestamp + 10 days);
    }

    function test_withdrawTokens_successful() public {
        // Move past claim end
        vm.warp(claimEndTimestamp + 1);

        uint256 contractBalance = trustToken.balanceOf(address(distributor));
        uint256 ownerBalanceBefore = trustToken.balanceOf(OWNER);

        vm.prank(OWNER);
        distributor.withdrawTokens(address(trustToken), contractBalance, OWNER);

        assertEq(trustToken.balanceOf(OWNER), ownerBalanceBefore + contractBalance);
        assertEq(trustToken.balanceOf(address(distributor)), 0);
    }

    function test_withdrawTokens_revertsOnZeroToken() public {
        vm.warp(claimEndTimestamp + 1);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.withdrawTokens(address(0), 1e18, OWNER);
    }

    function test_withdrawTokens_revertsOnZeroRecipient() public {
        vm.warp(claimEndTimestamp + 1);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroAddress.selector);
        distributor.withdrawTokens(address(trustToken), 1e18, address(0));
    }

    function test_withdrawTokens_revertsOnZeroAmount() public {
        vm.warp(claimEndTimestamp + 1);

        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ZeroValueProvided.selector);
        distributor.withdrawTokens(address(trustToken), 0, OWNER);
    }

    function test_withdrawTokens_revertsWhenClaimOngoing() public {
        vm.prank(OWNER);
        vm.expectRevert(TrustVestedMerkleDistributor.ClaimOngoing.selector);
        distributor.withdrawTokens(address(trustToken), 1e18, OWNER);
    }

    function test_pause_successful() public {
        vm.prank(OWNER);
        distributor.pause();

        assertTrue(distributor.paused());
    }

    function test_unpause_successful() public {
        vm.prank(OWNER);
        distributor.pause();

        vm.prank(OWNER);
        distributor.unpause();

        assertFalse(distributor.paused());
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_claim_validAmounts(uint256 allocation) public {
        allocation = bound(allocation, 1e18, 100_000e18);

        // Create a simple merkle tree for this user
        bytes32 leaf = keccak256(abi.encodePacked(ALICE, allocation));
        bytes32[] memory proof = new bytes32[](0);

        // Deploy fresh distributor with single leaf tree
        _deployFreshDistributorWithRoot(leaf);

        // Mint required allocation to the distributor
        trustToken.mint(address(distributor), allocation);

        uint256 expectedImmediate = (allocation * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedFee = (expectedImmediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = expectedImmediate - expectedFee;

        vm.prank(ALICE);
        distributor.claim(allocation, proof);

        assertEq(trustToken.balanceOf(ALICE), expectedNet);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee);
    }

    function testFuzz_rageQuit_validAmounts(uint256 allocation) public {
        allocation = bound(allocation, 1e18, 100_000e18);

        bytes32 leaf = keccak256(abi.encodePacked(ALICE, allocation));
        bytes32[] memory proof = new bytes32[](0);

        _deployFreshDistributorWithRoot(leaf);

        // Mint required allocation to the distributor
        trustToken.mint(address(distributor), allocation);

        uint256 expectedImmediate = (allocation * RAGE_QUIT_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedForfeited = allocation - expectedImmediate;
        uint256 expectedFee = (expectedImmediate * FEE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 expectedNet = expectedImmediate - expectedFee;

        vm.prank(ALICE);
        distributor.rageQuit(allocation, proof);

        assertEq(trustToken.balanceOf(ALICE), expectedNet);
        assertEq(trustToken.balanceOf(PROTOCOL_TREASURY), expectedFee + expectedForfeited);
    }

    function testFuzz_setFeeInBPS_validRange(uint256 newFee) public {
        newFee = bound(newFee, 0, 1000); // 0-10%

        vm.prank(OWNER);
        distributor.setFeeInBPS(newFee);

        assertEq(distributor.feeInBPS(), newFee);
    }

    function testFuzz_vestingCalculation_differentTimepoints(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 0, VESTING_DURATION);

        // Claim TGE first
        vm.prank(ALICE);
        distributor.claim(ALICE_ALLOCATION, aliceProof);

        // Move to specified time during vesting
        vm.warp(vestingStartTimestamp + timeElapsed);

        uint256 claimable = distributor.getClaimableAmount(ALICE, ALICE_ALLOCATION);
        uint256 immediate = (ALICE_ALLOCATION * TGE_BPS) / distributor.FEE_DENOMINATOR();
        uint256 remaining = ALICE_ALLOCATION - immediate;
        uint256 expectedVested = (remaining * timeElapsed) / VESTING_DURATION;

        assertEq(claimable, expectedVested);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _generateMerkleTree() internal {
        bytes32 leafAlice = keccak256(abi.encodePacked(ALICE, ALICE_ALLOCATION));
        bytes32 leafBob = keccak256(abi.encodePacked(BOB, BOB_ALLOCATION));
        bytes32 leafCarol = keccak256(abi.encodePacked(CAROL, CAROL_ALLOCATION));
        bytes32 leafDave = keccak256(abi.encodePacked(DAVE, DAVE_ALLOCATION));

        // Build tree: [Alice, [Bob, [Carol, Dave]]]
        bytes32 carolDave = _combineHashes(leafCarol, leafDave);
        bytes32 bobCarolDave = _combineHashes(leafBob, carolDave);
        merkleRoot = _combineHashes(leafAlice, bobCarolDave);

        // Generate proofs
        aliceProof = new bytes32[](1);
        aliceProof[0] = bobCarolDave;

        bobProof = new bytes32[](2);
        bobProof[0] = carolDave;
        bobProof[1] = leafAlice;

        carolProof = new bytes32[](3);
        carolProof[0] = leafDave;
        carolProof[1] = leafBob;
        carolProof[2] = leafAlice;

        daveProof = new bytes32[](3);
        daveProof[0] = leafCarol;
        daveProof[1] = leafBob;
        daveProof[2] = leafAlice;
    }

    function _combineHashes(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _deployFreshDistributor() internal {
        TrustVestedMerkleDistributor implementation = new TrustVestedMerkleDistributor();
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), "");
        distributor = TrustVestedMerkleDistributor(address(proxy));
    }

    function _deployFreshDistributorWithRoot(bytes32 root) internal {
        _deployFreshDistributor();

        TrustVestedMerkleDistributor.VestingParams memory params = _getValidParams();
        params.merkleRoot = root;

        vm.prank(OWNER);
        distributor.initialize(params);
    }

    function _getValidParams() internal view returns (TrustVestedMerkleDistributor.VestingParams memory) {
        return TrustVestedMerkleDistributor.VestingParams({
            owner: OWNER,
            trust: address(trustToken),
            trustBonding: address(trustBonding),
            protocolTreasury: PROTOCOL_TREASURY,
            feeInBPS: FEE_BPS,
            vestingStartTimestamp: block.timestamp + 1 days,
            vestingDuration: VESTING_DURATION,
            claimEndTimestamp: block.timestamp + 1 days + VESTING_DURATION + 30 days,
            tgeBPS: TGE_BPS,
            rageQuitBPS: RAGE_QUIT_BPS,
            merkleRoot: merkleRoot
        });
    }
}
