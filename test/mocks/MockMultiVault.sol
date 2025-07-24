// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title MockMultiVault
 * @author 0xIntuition
 * @notice Mock contract for testing the TrustBonding <> MultiVault interactions
 */
contract MockMultiVault {
    mapping(uint256 epoch => uint256 trustAmount) public totalUtilization;
    mapping(address user => mapping(uint256 epoch => uint256 trustAmount)) public utilization;
    mapping(uint256 epoch => bool isProtocolFeeDistributionEnabled) public protocolFeeDistributionEnabledAtEpoch;

    function getTotalUtilizationForEpoch(uint256 _epoch) external view returns (uint256) {
        return totalUtilization[_epoch];
    }

    function getUserUtilizationForEpoch(address _account, uint256 _epoch) external view returns (uint256) {
        return utilization[_account][_epoch];
    }

    function setTotalUtilizationForEpoch(uint256 _epoch, uint256 _trustAmount) external {
        totalUtilization[_epoch] = _trustAmount;
    }

    function setUserUtilizationForEpoch(address _account, uint256 _epoch, uint256 _trustAmount) external {
        utilization[_account][_epoch] = _trustAmount;
    }

    function setIsProtocolFeeDistributionEnabledAtEpoch(uint256 _epoch, bool _enabled) external {
        protocolFeeDistributionEnabledAtEpoch[_epoch] = _enabled;
    }
}
