// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Errors} from "src/libraries/Errors.sol";
import {TrustBonding} from "src/v2/TrustBonding.sol";

import {MockMultiVault} from "test/mocks/MockMultiVault.sol";
import {MockTrust} from "test/mocks/MockTrust.t.sol";

contract TrustBondingBaseTest is Test {
    /// @notice Core contracts to be deployed
    MockTrust public trustToken;
    TrustBonding public trustBonding;
    MockMultiVault public multiVault;
    ProxyAdmin public proxyAdmin = ProxyAdmin(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2); // pre-calculated proxy admin address

    /// @notice Constants
    uint256 public dealAmount = 100 * 1e18;
    uint256 public initialTokens = 10_000 * 1e18;
    uint256 public defaultUnlockDuration = 2 * 365 days; // 2 years
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = 1e8 * 1e18; // 10% of the initial supply
    address public alice = address(1);
    address public bob = address(2);
    address public admin = address(3);
    uint256 public constant systemUtilizationLowerBound = 2500; // 25%
    uint256 public constant personalUtilizationLowerBound = 2500; // 25%
    uint256 additionalTokens = 10_000 * 1e18;

    /// @notice TrustBonding config
    uint256 public epochLength_ = 14 days;
    uint256 public withdrawalDelay_ = 14 days;
    uint256 public emissionPercentage = 10_000; // 100%
    uint256 public startTimestamp = block.timestamp + 10 minutes;

    /// @notice Set up the test environment
    function setUp() public virtual {
        // Deploy the mock Trust token contract
        trustToken = new MockTrust("Intuition", "TRUST", MAX_POSSIBLE_ANNUAL_EMISSION);

        // Deploy MultiVault contract
        multiVault = new MockMultiVault();

        // Deploy TrustBonding contract
        trustBonding = new TrustBonding();

        TransparentUpgradeableProxy trustBondingProxy =
            new TransparentUpgradeableProxy(address(trustBonding), admin, "");

        trustBonding = TrustBonding(address(trustBondingProxy));

        // Initialize TrustBonding contract
        trustBonding.initialize(admin, address(trustToken), epochLength_, startTimestamp);

        // Reinitialize TrustBonding contract with MultiVault and utilization bounds
        vm.prank(admin);
        trustBonding.reinitialize(address(multiVault), systemUtilizationLowerBound, personalUtilizationLowerBound);

        // Deal ether to test addresses
        vm.deal(alice, dealAmount);
        vm.deal(bob, dealAmount);
        vm.deal(admin, dealAmount);

        trustToken.mint(alice, initialTokens);
        trustToken.mint(bob, initialTokens);
        trustToken.mint(admin, initialTokens);

        vm.startPrank(alice);

        trustToken.approve(address(trustBonding), type(uint256).max);

        vm.stopPrank();

        vm.startPrank(bob);

        trustToken.approve(address(trustBonding), type(uint256).max);

        vm.stopPrank();

        vm.startPrank(admin);

        trustToken.approve(address(trustBonding), type(uint256).max);

        vm.stopPrank();

        vm.warp(startTimestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to deploy a new TrustBonding contract and return its proxy contract instance
    function _deployNewTrustBondingContract() internal returns (TrustBonding) {
        TrustBonding newTrustBonding = new TrustBonding();
        TransparentUpgradeableProxy newTrustBondingProxy =
            new TransparentUpgradeableProxy(address(newTrustBonding), admin, "");
        newTrustBonding = TrustBonding(address(newTrustBondingProxy));

        return newTrustBonding;
    }

    /// @dev Internal function to bond some tokens for a given user
    function _bondSomeTokens(address user) internal {
        vm.startPrank(user, user);
        uint256 unlockTime = block.timestamp + defaultUnlockDuration;
        trustBonding.create_lock(initialTokens, unlockTime);
        vm.stopPrank();
    }

    /// @dev Internal function to advance the epoch by a given number of epochs
    function _advanceEpochs(uint256 epochs) internal {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 currentEpochEndTimestamp = trustBonding.epochEndTimestamp(currentEpoch);
        uint256 targetTimestamp = currentEpochEndTimestamp + epochs * trustBonding.epochLength();
        vm.warp(targetTimestamp - 1);
    }

    function _setTotalClaimedRewardsForEpoch(uint256 epoch, uint256 claimedRewards) internal {
        // Compute the slot
        bytes32 slot = keccak256(abi.encode(epoch, uint256(13))); // 13 = storage slot of totalClaimedRewardsForEpoch mapping

        vm.store(address(trustBonding), slot, bytes32(uint256(claimedRewards)));
    }

    function _setUserClaimedRewardsForEpoch(address user, uint256 epoch, uint256 claimedRewards) internal {
        // Compute the outer slot
        bytes32 outerSlot = keccak256(abi.encode(user, uint256(14))); // 14 = storage slot of userClaimedRewardsForEpoch mapping

        // Compute the final slot
        bytes32 finalSlot = keccak256(abi.encode(epoch, outerSlot));

        vm.store(address(trustBonding), finalSlot, bytes32(uint256(claimedRewards)));
    }
}

contract TrustBondingTest is TrustBondingBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize_verifyInitParams() external {
        vm.startPrank(admin);

        assertEq(trustBonding.owner(), admin);
        assertEq(address(trustBonding.token()), address(trustToken));
        assertEq(trustBonding.epochLength(), epochLength_);
        assertEq(trustBonding.startTimestamp(), startTimestamp);

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfAdminIsAddressZero() external {
        vm.startPrank(admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        newTrustBonding.initialize(address(0), address(trustToken), epochLength_, startTimestamp);

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfTrustTokenIsAddressZero() external {
        vm.startPrank(admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        vm.expectRevert("Token address cannot be 0");
        newTrustBonding.initialize(admin, address(0), epochLength_, startTimestamp);

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfEpochLengthIsBelowTwoWeeks() external {
        vm.startPrank(admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        uint256 invalidEpochLength = 2 weeks - 1;

        vm.expectRevert("Min lock time must be at least 2 weeks");
        newTrustBonding.initialize(admin, address(trustToken), invalidEpochLength, startTimestamp);

        vm.stopPrank();
    }

    function test_initialize_shouldRevertIfStartTimestampIsInThePast() external {
        vm.startPrank(admin);

        TrustBonding newTrustBonding = _deployNewTrustBondingContract();

        uint256 pastTimestamp = block.timestamp - 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidStartTimestamp.selector));
        newTrustBonding.initialize(admin, address(trustToken), epochLength_, pastTimestamp);

        vm.stopPrank();
    }

    function test_epochLength() external view {
        assertEq(trustBonding.epochLength(), epochLength_);
    }

    function test_epochsPerYear() external view {
        uint256 expectedEpochsPerYear = 365 days / epochLength_;

        assertEq(trustBonding.epochsPerYear(), expectedEpochsPerYear);
    }

    function test_epochEndTimestamp() external {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 currentEpochEndTimestamp = trustBonding.epochEndTimestamp(currentEpoch);

        assertEq(currentEpochEndTimestamp, startTimestamp + epochLength_);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(startTimestamp + 20 days);

        currentEpoch = trustBonding.currentEpoch();
        currentEpochEndTimestamp = trustBonding.epochEndTimestamp(currentEpoch);

        assertEq(currentEpochEndTimestamp, startTimestamp + 2 * epochLength_);
    }

    function test_epochAtTimestamp() external {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 currentTimestamp = block.timestamp;

        assertEq(trustBonding.epochAtTimestamp(currentTimestamp), currentEpoch);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(startTimestamp + 20 days);

        currentEpoch = trustBonding.currentEpoch();
        currentTimestamp = block.timestamp;

        assertEq(trustBonding.epochAtTimestamp(currentTimestamp), currentEpoch);
    }

    function test_currentEpoch() external {
        uint256 currentEpoch = trustBonding.currentEpoch();

        assertEq(currentEpoch, 0);

        // Warp 20 days into the future (should be in the middle of epoch 1)
        vm.warp(startTimestamp + 20 days);

        currentEpoch = trustBonding.currentEpoch();

        assertEq(currentEpoch, 1);
    }

    function test_totalLocked() external {
        uint256 totalLocked = trustBonding.totalLocked();

        assertEq(totalLocked, 0);

        _bondSomeTokens(alice);

        totalLocked = trustBonding.totalLocked();

        assertEq(totalLocked, initialTokens);
    }

    function test_lockedTrustPercentage_shouldReturnZeroIfTrustTotalSupplyIsZero() external {
        // Slot 5 as can be seen when running the `forge inspect MockToken storage-layout` command
        bytes32 slot = bytes32(uint256(2));

        // Set totalSupply() to zero for the need of this test
        vm.store(address(trustToken), slot, bytes32(uint256(0)));
        assertEq(trustToken.totalSupply(), 0);

        uint256 lockedTrustPercentage = trustBonding.lockedTrustPercentage();
        assertEq(lockedTrustPercentage, 0);
    }

    function test_lockedTrustPercentage() external {
        uint256 lockedTrustPercentage = trustBonding.lockedTrustPercentage();

        assertEq(lockedTrustPercentage, 0);

        _bondSomeTokens(alice);

        lockedTrustPercentage = trustBonding.lockedTrustPercentage();

        uint256 expectedLockedTrustPercentage =
            (initialTokens * trustBonding.BASIS_POINTS_DIVISOR()) / trustToken.totalSupply();

        assertEq(lockedTrustPercentage, expectedLockedTrustPercentage);
    }

    function test_totalBondedBalance() external {
        _bondSomeTokens(alice);
        _bondSomeTokens(bob);

        uint256 totalBondedBalance = trustBonding.totalBondedBalance();

        uint256 aliceVeTrust = trustBonding.balanceOf(alice);
        uint256 bobVeTrust = trustBonding.balanceOf(bob);
        uint256 expectedTotalBondedBalance = aliceVeTrust + bobVeTrust;

        assertEq(totalBondedBalance, expectedTotalBondedBalance);
    }

    function test_totalBondedBalanceAtEpochEnd_shouldRevertIfEpochIsInTheFuture() external {
        vm.startPrank(admin);

        uint256 futureEpoch = trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidEpoch.selector));
        trustBonding.totalBondedBalanceAtEpochEnd(futureEpoch);

        vm.stopPrank();
    }

    function test_totalBondedBalanceAtEpochEnd() external {
        _bondSomeTokens(alice);
        _bondSomeTokens(bob);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 totalBondedBalanceAtEpochEnd = trustBonding.totalBondedBalanceAtEpochEnd(currentEpoch);

        uint256 aliceVeTrust = trustBonding.userBondedBalanceAtEpochEnd(alice, currentEpoch);
        uint256 bobVeTrust = trustBonding.userBondedBalanceAtEpochEnd(bob, currentEpoch);
        uint256 expectedTotalBondedBalanceAtEpochEnd = aliceVeTrust + bobVeTrust;

        assertEq(totalBondedBalanceAtEpochEnd, expectedTotalBondedBalanceAtEpochEnd);
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertIfAccountIsZero() external {
        vm.startPrank(admin);

        uint256 currentEpoch = trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_ZeroAddress.selector));
        trustBonding.userBondedBalanceAtEpochEnd(address(0), currentEpoch);

        vm.stopPrank();
    }

    function test_userBondedBalanceAtEpochEnd_shouldRevertIfEpochIsInTheFuture() external {
        vm.startPrank(admin);

        uint256 futureEpoch = trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidEpoch.selector));
        trustBonding.userBondedBalanceAtEpochEnd(alice, futureEpoch);

        vm.stopPrank();
    }

    function test_userBondedBalanceAtEpochEnd() external {
        _bondSomeTokens(alice);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 aliceInitialVeTrust = trustBonding.balanceOf(alice);
        uint256 aliceVeTrustAtEpochEnd = trustBonding.userBondedBalanceAtEpochEnd(alice, currentEpoch);

        // veTRUST balances decay linearly over time
        assertLt(aliceVeTrustAtEpochEnd, aliceInitialVeTrust);
    }

    function test_userEligibleRewardsForEpoch_shouldRevertIfAccountIsZero() external {
        vm.startPrank(admin);

        uint256 currentEpoch = trustBonding.currentEpoch();

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_ZeroAddress.selector));
        trustBonding.userEligibleRewardsForEpoch(address(0), currentEpoch);

        vm.stopPrank();
    }

    function test_userEligibleRewardsForEpoch_shouldRevertIfEpochIsInTheFuture() external {
        vm.startPrank(admin);

        uint256 futureEpoch = trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidEpoch.selector));
        trustBonding.userEligibleRewardsForEpoch(alice, futureEpoch);

        vm.stopPrank();
    }

    function test_userEligibleRewardsForEpoch_shouldReturnZeroIfTotalLockedIsZero() external view {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 eligibleRewards = trustBonding.userEligibleRewardsForEpoch(alice, currentEpoch);

        assertEq(eligibleRewards, 0);
    }

    function test_userEligibleRewardsForEpoch() external {
        _bondSomeTokens(alice);
        _bondSomeTokens(bob);
        _bondSomeTokens(admin);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 trustPerEpoch = trustBonding.trustPerEpoch(currentEpoch);
        uint256 expectedRewards = trustPerEpoch / 3; // 1/3 of the total rewards for each user

        uint256 eligibleRewards = trustBonding.userEligibleRewardsForEpoch(alice, currentEpoch);

        assertEq(eligibleRewards, expectedRewards);
    }

    function test_hasClaimedRewardsForEpoch() external {
        _bondSomeTokens(alice);
        vm.warp(startTimestamp + trustBonding.epochLength());

        uint256 currentEpoch = trustBonding.currentEpoch();

        // Current epoch is still not claimable while it's ongoing
        assertEq(trustBonding.hasClaimedRewardsForEpoch(alice, currentEpoch), false);

        uint256 previousEpoch = currentEpoch - 1;

        // Alice claims rewards for the previous epoch (`n - 1`)
        assertEq(trustBonding.hasClaimedRewardsForEpoch(alice, previousEpoch), false);

        vm.prank(alice);
        trustBonding.claimRewards(alice);

        assertEq(trustBonding.hasClaimedRewardsForEpoch(alice, previousEpoch), true);
    }

    function test_trustPerEpoch_whenLockedPercentageIsZero() external view {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 trustPerEpoch = trustBonding.trustPerEpoch(currentEpoch);

        assertEq(trustPerEpoch, 0);
    }

    function test_trustPerEpoch_whenLockedPercentageIsAtOrBelowOnePercent() external {
        vm.startPrank(alice, alice);
        uint256 unlockTime = block.timestamp + defaultUnlockDuration;
        uint256 onePercentOfTotalSupply = trustToken.totalSupply() / 100;
        trustBonding.create_lock(onePercentOfTotalSupply, unlockTime);
        vm.stopPrank();

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 trustPerEpoch = trustBonding.trustPerEpoch(currentEpoch);

        uint256 epochsPerYear = trustBonding.epochsPerYear();
        uint256 expectedAnnualEmission = trustBonding.totalLocked() * 10; // enforce the capped 1,000% APR
        uint256 expectedTrustPerEpoch = expectedAnnualEmission / epochsPerYear;

        assertEq(trustPerEpoch, expectedTrustPerEpoch);
    }

    function test_trustPerEpoch_whenLockedPercentageIsAboveOnePercent() external {
        _bondSomeTokens(alice);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 trustPerEpoch = trustBonding.trustPerEpoch(currentEpoch);

        uint256 epochsPerYear = trustBonding.epochsPerYear();
        uint256 expectedAnnualEmission = trustToken.maxAnnualEmission();
        uint256 expectedTrustPerEpoch = expectedAnnualEmission / epochsPerYear;

        assertEq(trustPerEpoch, expectedTrustPerEpoch);
    }

    function test_getAPRAtEpoch_whenTotalLockedIsZero() external view {
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 currentAPR = trustBonding.getAPRAtEpoch(currentEpoch);

        assertEq(currentAPR, 0);
    }

    function test_getAPRAtEpoch_whenTotalLockedIsAboveZero() external {
        _bondSomeTokens(alice);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 currentAPR = trustBonding.getAPRAtEpoch(currentEpoch);

        uint256 trustPerYear = trustBonding.trustPerEpoch(currentEpoch) * trustBonding.epochsPerYear();
        uint256 expectedAPR = (trustPerYear * trustBonding.BASIS_POINTS_DIVISOR()) / trustBonding.totalLocked();

        assertEq(currentAPR, expectedAPR);
    }

    function test_claimRewards_shouldRevertIfContractIsPaused() external {
        _bondSomeTokens(alice);
        _advanceEpochs(1);

        vm.prank(admin);
        trustBonding.pause();

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        trustBonding.claimRewards(alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfRecipientIsAddressZero() external {
        _bondSomeTokens(alice);
        _advanceEpochs(1);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_ZeroAddress.selector));
        trustBonding.claimRewards(address(0));

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfClaimingRewardsDuringFirstEpoch() external {
        _bondSomeTokens(alice);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_NoClaimingDuringFirstEpoch.selector));
        trustBonding.claimRewards(alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfThereAreNoRewardsToClaim() external {
        _advanceEpochs(1);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_NoRewardsToClaim.selector));
        trustBonding.claimRewards(alice);

        vm.stopPrank();
    }

    function test_claimRewards_shouldRevertIfAlreadyClaimedRewardsForEpoch() external {
        _bondSomeTokens(alice);
        _advanceEpochs(1);

        vm.prank(alice);
        trustBonding.claimRewards(alice);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_RewardsAlreadyClaimedForEpoch.selector));
        trustBonding.claimRewards(alice);

        vm.stopPrank();
    }

    function test_claimRewards_differentScenarios() external {
        _bondSomeTokens(alice);
        _advanceEpochs(1);

        // Case 1: Regular rewards claim
        vm.startPrank(alice);

        uint256 aliceInitialBalance = trustToken.balanceOf(alice);
        uint256 expectedRewards = trustBonding.userEligibleRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);

        trustBonding.claimRewards(alice);
        uint256 aliceFinalBalance = trustToken.balanceOf(alice);

        uint256 totalClaimedRewardsForEpoch = trustBonding.totalClaimedRewardsForEpoch(trustBonding.currentEpoch() - 1);
        uint256 aliceClaimedRewardsForEpoch =
            trustBonding.userClaimedRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards);
        assertEq(totalClaimedRewardsForEpoch, expectedRewards);
        assertEq(aliceClaimedRewardsForEpoch, expectedRewards);

        vm.stopPrank();

        // Case 2: Claimed amount for alice goes down if more people bonded in the meantime
        _bondSomeTokens(bob);
        _advanceEpochs(1);

        vm.startPrank(alice, alice);

        aliceInitialBalance = trustToken.balanceOf(alice);
        uint256 rawRewards = trustBonding.userEligibleRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);
        uint256 expectedRewards2 = rawRewards;

        trustBonding.claimRewards(alice);
        aliceFinalBalance = trustToken.balanceOf(alice);

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards2);
        assertLt(expectedRewards2, expectedRewards);

        // Case 3: Claimed amount calculation with utilization ratio
        trustToken.mint(alice, additionalTokens);
        trustBonding.increase_amount(additionalTokens);
        _advanceEpochs(1);

        aliceInitialBalance = trustToken.balanceOf(alice);

        // Get raw rewards for epoch 2
        uint256 rawRewards3 = trustBonding.userEligibleRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);

        // Get personal utilization ratio for epoch 2
        uint256 personalUtilizationRatio =
            trustBonding.getPersonalUtilizationRatio(alice, trustBonding.currentEpoch() - 1);

        // Calculate expected rewards after applying personal utilization ratio
        uint256 expectedRewards3 = rawRewards3 * personalUtilizationRatio / trustBonding.BASIS_POINTS_DIVISOR();

        // Calculate Alice's share of the total bonded balance for epoch 2
        uint256 aliceBondedBalance = trustBonding.userBondedBalanceAtEpochEnd(alice, trustBonding.currentEpoch() - 1);
        uint256 totalBondedBalance = trustBonding.totalBondedBalanceAtEpochEnd(trustBonding.currentEpoch() - 1);
        uint256 aliceShareBasisPoints = (aliceBondedBalance * trustBonding.BASIS_POINTS_DIVISOR()) / totalBondedBalance;

        // Alice's share should have increased (from ~50% to ~66.7%)
        assertGt(aliceShareBasisPoints, 5000); // Alice has more than 50% share

        trustBonding.claimRewards(alice);
        aliceFinalBalance = trustToken.balanceOf(alice);

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards3);

        // The actual rewards will be less than raw rewards due to utilization ratio
        assertLt(expectedRewards3, rawRewards3);

        vm.stopPrank();

        // Case 4: Claimed amount goes down if no more tokens are added to the existing bond
        _testCase4();

        // Case 5: Verify that the claimed rewards tracking is accurate with multiple claims from different users
        _testCase5();
    }

    // Helper function for Case 4
    function _testCase4() internal {
        _advanceEpochs(1);

        vm.startPrank(alice, alice);

        uint256 aliceInitialBalance = trustToken.balanceOf(alice);
        uint256 rawRewards = trustBonding.userEligibleRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);
        uint256 expectedRewards4 = rawRewards * personalUtilizationLowerBound / trustBonding.BASIS_POINTS_DIVISOR();

        trustBonding.claimRewards(alice);
        uint256 aliceFinalBalance = trustToken.balanceOf(alice);

        assertEq(aliceFinalBalance, aliceInitialBalance + expectedRewards4);

        // Store for comparison in case 5
        _setUserClaimedRewardsForEpoch(alice, trustBonding.currentEpoch() - 1, expectedRewards4);

        vm.stopPrank();
    }

    // Helper function for Case 5
    function _testCase5() internal {
        vm.startPrank(bob, bob);

        uint256 bobInitialBalance = trustToken.balanceOf(bob);
        uint256 bobRawRewards = trustBonding.userEligibleRewardsForEpoch(bob, trustBonding.currentEpoch() - 1);
        uint256 bobExpectedRewards = bobRawRewards * personalUtilizationLowerBound / trustBonding.BASIS_POINTS_DIVISOR();

        trustBonding.claimRewards(bob);

        uint256 totalClaimedRewardsForEpoch = trustBonding.totalClaimedRewardsForEpoch(trustBonding.currentEpoch() - 1);
        uint256 bobClaimedRewardsForEpoch =
            trustBonding.userClaimedRewardsForEpoch(bob, trustBonding.currentEpoch() - 1);
        uint256 aliceClaimedRewardsForEpoch =
            trustBonding.userClaimedRewardsForEpoch(alice, trustBonding.currentEpoch() - 1);

        assertEq(trustToken.balanceOf(bob), bobInitialBalance + bobExpectedRewards);

        // For epoch 3 (currentEpoch() - 1), only Alice and Bob claimed
        assertEq(totalClaimedRewardsForEpoch, aliceClaimedRewardsForEpoch + bobExpectedRewards);
        assertEq(bobClaimedRewardsForEpoch, bobExpectedRewards);

        vm.stopPrank();
    }

    function test_increase_unlock_time_and_withdraw() external {
        // 1. Lock some tokens
        vm.startPrank(alice, alice);
        trustBonding.create_lock(initialTokens, block.timestamp + defaultUnlockDuration);

        (int128 rawLockedAmount, uint256 lockEndTimestamp) = trustBonding.locked(alice);
        uint256 lockedAmount = uint256(uint128(rawLockedAmount));
        // unlock time is rounded down to the number of whole weeks
        uint256 expectedLockEndTimestamp = ((block.timestamp + defaultUnlockDuration) / 1 weeks) * 1 weeks;

        assertEq(lockedAmount, initialTokens);
        assertEq(lockEndTimestamp, expectedLockEndTimestamp);

        // 2. Increase the unlock time after some time passes
        vm.warp(block.timestamp + 30 days);
        trustBonding.increase_unlock_time(expectedLockEndTimestamp + 30 days);

        (rawLockedAmount, lockEndTimestamp) = trustBonding.locked(alice);
        expectedLockEndTimestamp = ((expectedLockEndTimestamp + 30 days) / 1 weeks) * 1 weeks;

        assertEq(lockEndTimestamp, expectedLockEndTimestamp);

        // 3. Once the lock fully expires, withdraw the bonded tokens
        vm.warp(expectedLockEndTimestamp + 1);
        trustBonding.withdraw();

        (rawLockedAmount, lockEndTimestamp) = trustBonding.locked(alice);
        lockedAmount = uint256(uint128(rawLockedAmount));

        assertEq(lockedAmount, 0);
        assertEq(lockEndTimestamp, 0);

        // Now alice has all of her tokens back
        assertEq(trustToken.balanceOf(alice), initialTokens);
        vm.stopPrank();
    }

    function test_pause_shouldRevertIfCalledByNonOwner() external {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        trustBonding.pause();

        vm.stopPrank();
    }

    function test_pause_shouldRevertIfAlreadyPaused() external {
        vm.startPrank(admin);

        trustBonding.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        trustBonding.pause();

        vm.stopPrank();
    }

    function test_pause() external {
        vm.startPrank(admin);

        trustBonding.pause();

        assertEq(trustBonding.paused(), true);

        vm.stopPrank();
    }

    function test_unpause_shouldRevertIfCalledByNonOwner() external {
        vm.startPrank(admin);

        trustBonding.pause();

        vm.stopPrank();

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        trustBonding.unpause();

        vm.stopPrank();
    }

    function test_unpause_shouldRevertIfAlreadyUnpaused() external {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector));
        trustBonding.unpause();

        vm.stopPrank();
    }

    function test_unpause() external {
        vm.startPrank(admin);

        trustBonding.pause();
        trustBonding.unpause();

        assertEq(trustBonding.paused(), false);

        vm.stopPrank();
    }
}

contract TrustBondingUtilizationCalculationsTest is TrustBondingBaseTest {
    function setUp() public override {
        super.setUp();

        // advance into the 4th epoch to be able to claim rewards when the utilizationRatio is not guaranteed to be 100%
        _advanceEpochs(4);
    }

    function test_setMultiVault_shouldRevertIfCalledByNonOwner() external {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        trustBonding.setMultiVault(address(multiVault));

        vm.stopPrank();
    }

    function test_setMultiVault_shouldRevertIfAddressIsZero() external {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_ZeroAddress.selector));
        trustBonding.setMultiVault(address(0));

        vm.stopPrank();
    }

    function test_setMultiVault() external {
        vm.startPrank(admin);

        trustBonding.setMultiVault(address(multiVault));

        assertEq(address(trustBonding.multiVault()), address(multiVault));

        vm.stopPrank();
    }

    function test_trustPerEpoch_shouldRevertIfEpochIsInvalid() external {
        uint256 futureEpoch = trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidEpoch.selector));
        trustBonding.trustPerEpoch(futureEpoch);
    }

    function test_trustPerEpoch_shouldReturnMaxPossibleEmissionIfCalledWithEpochZeroOrOne() external {
        _bondSomeTokens(alice);

        uint256 trustPerEpoch = trustBonding.trustPerEpoch(0);
        uint256 expectedTrustPerEpoch = MAX_POSSIBLE_ANNUAL_EMISSION / trustBonding.epochsPerYear();

        assertEq(trustPerEpoch, expectedTrustPerEpoch);

        trustPerEpoch = trustBonding.trustPerEpoch(1);

        assertEq(trustPerEpoch, expectedTrustPerEpoch);
    }

    function test_trustPerEpoch_shouldReturnEmissionAmountScaledByTheSystemUtilization() external {
        uint256 currentEpoch = trustBonding.currentEpoch();
        multiVault.setTotalUtilizationForEpoch(currentEpoch - 1, 1000); // 100% utilizations

        // lock tokens so emission is non‑zero and verify scaling
        _bondSomeTokens(alice);
        uint256 maxPerEpoch = MAX_POSSIBLE_ANNUAL_EMISSION / trustBonding.epochsPerYear();
        uint256 expected = (maxPerEpoch * systemUtilizationLowerBound) / trustBonding.BASIS_POINTS_DIVISOR();
        assertEq(trustBonding.trustPerEpoch(trustBonding.currentEpoch()), expected);
    }

    function test_getAPRAtEpoch_shouldRevertIfEpochIsInTheFuture() external {
        uint256 futureEpoch = trustBonding.currentEpoch() + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.TrustBonding_InvalidEpoch.selector));
        trustBonding.getAPRAtEpoch(futureEpoch);
    }

    function test_getAPRAtEpoch_shouldReturnZeroIfTotalLockedIsZero() external view {
        // No one has bonded any tokens yet
        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 apr = trustBonding.getAPRAtEpoch(currentEpoch);

        assertEq(apr, 0);
    }

    function test_getAPRAtEpoch_11() external {
        _bondSomeTokens(alice);

        // Case 1: Utilization ratio is 100%
        _setTotalClaimedRewardsForEpoch(3, 1000);
        multiVault.setTotalUtilizationForEpoch(3, 1000);
        multiVault.setTotalUtilizationForEpoch(4, 2000);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 apr = trustBonding.getAPRAtEpoch(currentEpoch);

        uint256 trustPerYear = trustBonding.trustPerEpoch(currentEpoch) * trustBonding.epochsPerYear();
        uint256 expectedAPR = (trustPerYear * trustBonding.BASIS_POINTS_DIVISOR()) / trustBonding.totalLocked();

        assertEq(apr, expectedAPR);

        // Case 2: Utilization drops to 50%
        multiVault.setTotalUtilizationForEpoch(4, 1500);

        apr = trustBonding.getAPRAtEpoch(currentEpoch);
        uint256 expectedAPRScaled = expectedAPR
            * (systemUtilizationLowerBound + (trustBonding.BASIS_POINTS_DIVISOR() - systemUtilizationLowerBound) / 2)
            / trustBonding.BASIS_POINTS_DIVISOR();
        assertEq(apr, expectedAPRScaled);
    }

    function test_getSystemUtilizationRatio_shouldReturnMaxRatioIfEpochIsZeroOrOne() external view {
        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(0);
        assertEq(systemUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());

        systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(1);
        assertEq(systemUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getSystemUtilizationRatio_shouldReturnZeroIfEpochIsInTheFuture() external view {
        uint256 futureEpoch = trustBonding.currentEpoch() + 1;
        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(futureEpoch);

        assertEq(systemUtilizationRatio, 0);
    }

    function test_getSystemUtilizationRatio_shouldReturnLowerBoundIfUtilizationDroppedEpochOverEpoch() external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setTotalUtilizationForEpoch(previousEpoch - 1, 1000);
        multiVault.setTotalUtilizationForEpoch(previousEpoch, 500);

        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(previousEpoch);

        assertEq(systemUtilizationRatio, systemUtilizationLowerBound);
    }

    function test_getSystemUtilizationRatio_shouldReturnMaxRatioIfUtilizationIncreasedButNoRewardsWereClaimedPreviously(
    ) external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setTotalUtilizationForEpoch(previousEpoch - 1, 1000);
        multiVault.setTotalUtilizationForEpoch(previousEpoch, 2000);

        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(previousEpoch);

        assertEq(systemUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getSystemUtilizationRatio_shouldReturnMaxRatioIfUtilizationTargetWasExceeded() external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setTotalUtilizationForEpoch(previousEpoch - 1, 1000);
        multiVault.setTotalUtilizationForEpoch(previousEpoch, 2000);

        _setTotalClaimedRewardsForEpoch(previousEpoch - 1, 1000);

        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(previousEpoch);

        assertEq(systemUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getSystemUtilizationRatio_shouldReturnAProportionateRatioIfUtilizationTargetWasNotExceeded()
        external
    {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setTotalUtilizationForEpoch(previousEpoch - 1, 1000);
        multiVault.setTotalUtilizationForEpoch(previousEpoch, 1500); // utilization increased by 50% of the target

        _setTotalClaimedRewardsForEpoch(previousEpoch - 1, 1000);

        uint256 systemUtilizationRatio = trustBonding.getSystemUtilizationRatio(previousEpoch);
        uint256 expectedSystemUtilizationRatio =
            systemUtilizationLowerBound + (trustBonding.BASIS_POINTS_DIVISOR() - systemUtilizationLowerBound) / 2; // 25 % + half of remaining 75 % = 6250 bps

        assertEq(systemUtilizationRatio, expectedSystemUtilizationRatio);
    }

    function test_getPersonalUtilizationRatio_shouldReturnMaxRatioIfEpochIsZeroOrOne() external view {
        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, 0);
        assertEq(personalUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());

        personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, 1);
        assertEq(personalUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getPersonalUtilizationRatio_shouldReturnZeroIfEpochIsInTheFuture() external view {
        uint256 futureEpoch = trustBonding.currentEpoch() + 1;
        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, futureEpoch);

        assertEq(personalUtilizationRatio, 0);
    }

    function test_getPersonalUtilizationRatio_shouldReturnLowerBoundIfUtilizationDroppedEpochOverEpoch() external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch - 1, 1000);
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch, 500);

        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, previousEpoch);

        assertEq(personalUtilizationRatio, personalUtilizationLowerBound);
    }

    function test_getPersonalUtilizationRatio_shouldReturnMaxRatioIfUtilizationIncreasedButNoRewardsWereClaimedPreviously(
    ) external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch - 1, 1000);
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch, 2000);

        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, previousEpoch);

        assertEq(personalUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getPersonalUtilizationRatio_shouldReturnMaxRatioIfUtilizationTargetWasExceeded() external {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch - 1, 1000);
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch, 2000);

        _setUserClaimedRewardsForEpoch(alice, previousEpoch - 1, 1000);

        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, previousEpoch);

        assertEq(personalUtilizationRatio, trustBonding.BASIS_POINTS_DIVISOR());
    }

    function test_getPersonalUtilizationRatio_shouldReturnAProportionateRatioIfUtilizationTargetWasNotExceeded()
        external
    {
        uint256 previousEpoch = trustBonding.currentEpoch() - 1;
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch - 1, 1000);
        multiVault.setUserUtilizationForEpoch(alice, previousEpoch, 1500); // utilization increased by 50% of the target

        _setUserClaimedRewardsForEpoch(alice, previousEpoch - 1, 1000);

        uint256 personalUtilizationRatio = trustBonding.getPersonalUtilizationRatio(alice, previousEpoch);
        uint256 expectedPersonalUtilizationRatio =
            personalUtilizationLowerBound + (trustBonding.BASIS_POINTS_DIVISOR() - personalUtilizationLowerBound) / 2; // 6250 bps

        assertEq(personalUtilizationRatio, expectedPersonalUtilizationRatio);
    }
}
