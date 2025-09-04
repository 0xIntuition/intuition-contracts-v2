// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { TrustBonding } from "../../src/protocol/emissions/TrustBonding.sol";

/**
 * @title TrustBondingMock
 * @notice Mock contract that exposes internal functions from TrustBonding for testing
 */
contract TrustBondingMock is TrustBonding {
    /**
     * @notice Exposes the internal _getNormalizedUtilizationRatio function
     */
    function exposed_getNormalizedUtilizationRatio(
        uint256 delta,
        uint256 target,
        uint256 lowerBound
    )
        external
        pure
        returns (uint256)
    {
        return _getNormalizedUtilizationRatio(delta, target, lowerBound);
    }

    /**
     * @notice Exposes the internal _getSystemUtilizationRatio function
     */
    function exposed_getSystemUtilizationRatio(uint256 _epoch) external view returns (uint256) {
        return _getSystemUtilizationRatio(_epoch);
    }

    /* =================================================== */
    /*                TESTING UTILITIES                    */
    /* =================================================== */

    /**
     * @notice Helper function to set total claimed rewards for testing
     */
    function setTotalClaimedRewardsForEpoch(uint256 epoch, uint256 amount) external {
        totalClaimedRewardsForEpoch[epoch] = amount;
    }

    /**
     * @notice Helper function to set user claimed rewards for testing
     */
    function setUserClaimedRewardsForEpoch(address user, uint256 epoch, uint256 amount) external {
        userClaimedRewardsForEpoch[user][epoch] = amount;
    }

    /**
     * @notice Helper function to set max claimable protocol fees for testing
     */
    function setMaxClaimableProtocolFeesForEpoch(uint256 epoch, uint256 amount) external {
        maxClaimableProtocolFeesForEpoch[epoch] = amount;
    }
}
