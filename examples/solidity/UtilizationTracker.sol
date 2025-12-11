// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title UtilizationTracker
 * @notice Example contract that tracks and analyzes protocol utilization for rewards optimization
 * @dev Demonstrates:
 *      - Reading utilization data from MultiVault
 *      - Calculating optimal deposit/redemption strategies
 *      - Tracking user activity across epochs
 *      - Estimating reward potential
 *
 * Utilization impacts rewards:
 * - Personal utilization: Your deposits/redemptions over time
 * - System utilization: Total protocol deposits/redemptions
 * - Higher utilization = Higher reward multipliers
 *
 * @author 0xIntuition
 *
 * Usage:
 *   1. Deploy with MultiVault and TrustBonding addresses
 *   2. Call analyzeUserUtilization() to get user stats
 *   3. Call recommendActions() for optimization suggestions
 *
 * Example:
 *   UtilizationTracker tracker = new UtilizationTracker(multiVault, trustBonding);
 *   (int256 personal, int256 system, uint256 efficiency) = tracker.analyzeUserUtilization(alice);
 */

import "src/interfaces/IMultiVault.sol";
import "src/interfaces/ITrustBonding.sol";

contract UtilizationTracker {
    /* =================================================== */
    /*                    INTERFACES                       */
    /* =================================================== */

    IMultiVault public immutable multiVault;
    ITrustBonding public immutable trustBonding;

    /* =================================================== */
    /*                     STRUCTS                         */
    /* =================================================== */

    /**
     * @notice User utilization statistics
     * @param personalUtilization User's utilization in current epoch (can be negative)
     * @param systemUtilization Total system utilization in current epoch
     * @param utilizationRatio User's ratio compared to system (scaled by 1e18)
     * @param lastActiveEpoch Last epoch where user had activity
     * @param currentEpoch Current epoch number
     */
    struct UtilizationStats {
        int256 personalUtilization;
        int256 systemUtilization;
        uint256 utilizationRatio;
        uint256 lastActiveEpoch;
        uint256 currentEpoch;
    }

    /**
     * @notice User reward information
     * @param bondedBalance Amount of veWTRUST bonded
     * @param eligibleRewards Current claimable rewards
     * @param maxRewards Maximum possible rewards (with 100% utilization)
     * @param currentApy Current APY based on actual utilization
     * @param maxApy Maximum possible APY
     */
    struct RewardInfo {
        uint256 bondedBalance;
        uint256 eligibleRewards;
        uint256 maxRewards;
        uint256 currentApy;
        uint256 maxApy;
    }

    /**
     * @notice Action recommendations for optimizing rewards
     * @param shouldDeposit Whether user should increase deposits
     * @param shouldBondMore Whether user should bond more TRUST
     * @param optimalDepositAmount Suggested deposit amount to optimize utilization
     * @param reasoning Human-readable explanation
     */
    struct ActionRecommendation {
        bool shouldDeposit;
        bool shouldBondMore;
        uint256 optimalDepositAmount;
        string reasoning;
    }

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /**
     * @notice Initializes the tracker with protocol contracts
     * @param _multiVault Address of MultiVault contract
     * @param _trustBonding Address of TrustBonding contract
     */
    constructor(address _multiVault, address _trustBonding) {
        multiVault = IMultiVault(_multiVault);
        trustBonding = ITrustBonding(_trustBonding);
    }

    /* =================================================== */
    /*                 ANALYSIS FUNCTIONS                  */
    /* =================================================== */

    /**
     * @notice Analyzes a user's utilization across epochs
     * @dev Reads data from MultiVault for current and previous epochs
     *
     * @param user Address of the user to analyze
     * @return stats Complete utilization statistics
     *
     * @custom:example
     *   UtilizationStats memory stats = tracker.analyzeUserUtilization(alice);
     *   if (stats.personalUtilization > 0) {
     *       // User has net deposits this epoch
     *   }
     */
    function analyzeUserUtilization(address user) external view returns (UtilizationStats memory stats) {
        uint256 currentEpoch = multiVault.currentEpoch();

        // Get user's personal utilization for current epoch
        int256 personalUtil = multiVault.getUserUtilizationForEpoch(user, currentEpoch);

        // Get system-wide utilization for current epoch
        int256 systemUtil = multiVault.getTotalUtilizationForEpoch(currentEpoch);

        // Calculate utilization ratio (user vs system)
        uint256 ratio = 0;
        if (systemUtil > 0) {
            // Convert to positive for ratio calculation
            uint256 absPersonal = personalUtil >= 0 ? uint256(personalUtil) : uint256(-personalUtil);
            uint256 absSystem = uint256(systemUtil);
            ratio = (absPersonal * 1e18) / absSystem; // Scaled by 1e18
        }

        // Get user's last active epoch
        uint256 lastActive = multiVault.getUserLastActiveEpoch(user);

        return UtilizationStats({
            personalUtilization: personalUtil,
            systemUtilization: systemUtil,
            utilizationRatio: ratio,
            lastActiveEpoch: lastActive,
            currentEpoch: currentEpoch
        });
    }

    /**
     * @notice Gets user's reward information from TrustBonding
     * @param user Address of the user
     * @return info Complete reward information
     */
    function getUserRewardInfo(address user) external view returns (RewardInfo memory info) {
        UserInfo memory userInfo = trustBonding.getUserInfo(user);
        (uint256 currentApy, uint256 maxApy) = trustBonding.getUserApy(user);

        return RewardInfo({
            bondedBalance: userInfo.bondedBalance,
            eligibleRewards: userInfo.eligibleRewards,
            maxRewards: userInfo.maxRewards,
            currentApy: currentApy,
            maxApy: maxApy
        });
    }

    /**
     * @notice Recommends actions to optimize user's rewards
     * @dev Analyzes utilization and bonded balance to provide suggestions
     *
     * @param user Address of the user
     * @return recommendation Action recommendations with reasoning
     *
     * @custom:example
     *   ActionRecommendation memory rec = tracker.recommendActions(alice);
     *   if (rec.shouldDeposit) {
     *       // User should deposit rec.optimalDepositAmount
     *   }
     */
    function recommendActions(address user) external view returns (ActionRecommendation memory recommendation) {
        UtilizationStats memory stats = this.analyzeUserUtilization(user);
        RewardInfo memory rewards = this.getUserRewardInfo(user);

        // Check if user has bonded balance
        if (rewards.bondedBalance == 0) {
            return ActionRecommendation({
                shouldDeposit: false,
                shouldBondMore: true,
                optimalDepositAmount: 0,
                reasoning: "Bond TRUST tokens first to earn rewards"
            });
        }

        // Calculate utilization efficiency (actual rewards vs max possible)
        uint256 efficiency = 0;
        if (rewards.maxRewards > 0) {
            efficiency = (rewards.eligibleRewards * 100) / rewards.maxRewards;
        }

        // Low efficiency means user should increase utilization
        if (efficiency < 50) {
            // Suggest deposit amount based on bonded balance
            // Rule of thumb: utilization should be proportional to bonded balance
            uint256 suggestedDeposit = rewards.bondedBalance / 10; // 10% of bonded balance

            return ActionRecommendation({
                shouldDeposit: true,
                shouldBondMore: false,
                optimalDepositAmount: suggestedDeposit,
                reasoning: "Low utilization efficiency - increase deposits to maximize rewards"
            });
        }

        // If efficiency is good but could be better
        if (efficiency < 80) {
            uint256 suggestedDeposit = rewards.bondedBalance / 20; // 5% of bonded balance

            return ActionRecommendation({
                shouldDeposit: true,
                shouldBondMore: false,
                optimalDepositAmount: suggestedDeposit,
                reasoning: "Good efficiency - small deposit increase could optimize rewards"
            });
        }

        // If utilization is optimal, suggest bonding more to increase absolute rewards
        return ActionRecommendation({
            shouldDeposit: false,
            shouldBondMore: true,
            optimalDepositAmount: 0,
            reasoning: "Excellent utilization - bond more TRUST to increase total rewards"
        });
    }

    /* =================================================== */
    /*                 HELPER FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Calculates expected rewards for a given utilization
     * @dev Simulates what rewards would be with different utilization levels
     *
     * @param user Address of the user
     * @param simulatedUtilization Hypothetical utilization value to test
     * @return expectedRewards Estimated rewards with this utilization
     */
    function simulateRewards(
        address user,
        int256 simulatedUtilization
    )
        external
        view
        returns (uint256 expectedRewards)
    {
        RewardInfo memory rewards = this.getUserRewardInfo(user);

        if (rewards.bondedBalance == 0 || rewards.maxRewards == 0) {
            return 0;
        }

        // Get current system utilization for context
        uint256 currentEpoch = multiVault.currentEpoch();
        int256 systemUtil = multiVault.getTotalUtilizationForEpoch(currentEpoch);

        // Calculate utilization ratio
        uint256 ratio = 0;
        if (systemUtil > 0) {
            uint256 absSimulated = simulatedUtilization >= 0
                ? uint256(simulatedUtilization)
                : uint256(-simulatedUtilization);
            uint256 absSystem = uint256(systemUtil);
            ratio = (absSimulated * 1e18) / absSystem;
        }

        // Estimate rewards as proportion of max rewards based on utilization ratio
        // This is simplified - actual calculation in TrustBonding is more complex
        expectedRewards = (rewards.maxRewards * ratio) / 1e18;

        return expectedRewards;
    }

    /**
     * @notice Gets historical utilization for multiple epochs
     * @param user Address of the user
     * @param epochCount Number of past epochs to retrieve
     * @return epochs Array of epoch numbers
     * @return utilizations Array of utilization values for each epoch
     */
    function getHistoricalUtilization(
        address user,
        uint256 epochCount
    )
        external
        view
        returns (uint256[] memory epochs, int256[] memory utilizations)
    {
        uint256 currentEpoch = multiVault.currentEpoch();

        // Limit to available history
        uint256 count = epochCount > currentEpoch ? currentEpoch + 1 : epochCount;

        epochs = new uint256[](count);
        utilizations = new int256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 epoch = currentEpoch - i;
            epochs[i] = epoch;

            // Get utilization for this epoch
            // Note: This may revert for very old epochs if not tracked
            try multiVault.getUserUtilizationForEpoch(user, epoch) returns (int256 util) {
                utilizations[i] = util;
            } catch {
                utilizations[i] = 0;
            }
        }

        return (epochs, utilizations);
    }

    /**
     * @notice Compares user's utilization to system average
     * @param user Address of the user
     * @return isAboveAverage Whether user is above system average
     * @return percentDifference How much above/below average (in percentage points)
     */
    function compareToSystemAverage(address user)
        external
        view
        returns (bool isAboveAverage, uint256 percentDifference)
    {
        UtilizationStats memory stats = this.analyzeUserUtilization(user);

        if (stats.systemUtilization == 0) {
            return (false, 0);
        }

        // Calculate if user is above average
        isAboveAverage = stats.personalUtilization > (stats.systemUtilization / 2);

        // Calculate percentage difference
        int256 avgUtilization = stats.systemUtilization / 2;
        int256 diff = stats.personalUtilization - avgUtilization;

        uint256 absDiff = diff >= 0 ? uint256(diff) : uint256(-diff);
        percentDifference = (absDiff * 100) / uint256(stats.systemUtilization);

        return (isAboveAverage, percentDifference);
    }
}

/**
 * @dev Example usage in a dApp:
 *
 * ```solidity
 * // Deploy tracker
 * UtilizationTracker tracker = new UtilizationTracker(
 *     0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e, // MultiVault
 *     0x635bBD1367B66E7B16a21D6E5A63C812fFC00617  // TrustBonding
 * );
 *
 * // Analyze user
 * UtilizationTracker.UtilizationStats memory stats = tracker.analyzeUserUtilization(alice);
 * console.log("Personal utilization:", stats.personalUtilization);
 * console.log("Utilization ratio:", stats.utilizationRatio);
 *
 * // Get reward info
 * UtilizationTracker.RewardInfo memory rewards = tracker.getUserRewardInfo(alice);
 * console.log("Bonded balance:", rewards.bondedBalance);
 * console.log("Current APY:", rewards.currentApy);
 *
 * // Get recommendations
 * UtilizationTracker.ActionRecommendation memory rec = tracker.recommendActions(alice);
 * if (rec.shouldDeposit) {
 *     console.log("Suggested deposit:", rec.optimalDepositAmount);
 *     console.log("Reason:", rec.reasoning);
 * }
 *
 * // Simulate different strategies
 * uint256 expectedRewards = tracker.simulateRewards(alice, 1000 ether);
 * console.log("Expected rewards with 1000 utilization:", expectedRewards);
 * ```
 */
