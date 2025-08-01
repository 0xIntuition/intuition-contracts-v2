// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title MockMultiVault
 * @author 0xIntuition
 * @notice Mock contract for testing the TrustBonding <> MultiVault interactions and TrustUnlock MultiVault operations
 */
contract MockMultiVault {
    mapping(uint256 epoch => int256 trustAmount) public totalUtilization;
    mapping(address user => mapping(uint256 epoch => int256 trustAmount)) public utilization;
    mapping(uint256 epoch => bool isProtocolFeeDistributionEnabled) public protocolFeeDistributionEnabledAtEpoch;
    mapping(uint256 epoch => uint256 accumulatedFees) public accumulatedProtocolFees;

    uint256 private atomIdCounter = 1;
    uint256 private tripleIdCounter = 1;

    function getTotalUtilizationForEpoch(uint256 _epoch) external view returns (int256) {
        return totalUtilization[_epoch];
    }

    function getUserUtilizationForEpoch(address _account, uint256 _epoch) external view returns (int256) {
        return utilization[_account][_epoch];
    }

    function setTotalUtilizationForEpoch(uint256 _epoch, int256 _trustAmount) external {
        totalUtilization[_epoch] = _trustAmount;
    }

    function setUserUtilizationForEpoch(address _account, uint256 _epoch, int256 _trustAmount) external {
        utilization[_account][_epoch] = _trustAmount;
    }

    function setIsProtocolFeeDistributionEnabledAtEpoch(uint256 _epoch, bool _enabled) external {
        protocolFeeDistributionEnabledAtEpoch[_epoch] = _enabled;
    }

    function setAccumulatedProtocolFees(uint256 _epoch, uint256 _amount) external {
        accumulatedProtocolFees[_epoch] = _amount;
    }

    function createAtoms(bytes[] calldata atomDataArray, uint256 value)
        external
        returns (bytes32[] memory atomIds)
    {
        atomIds = new bytes32[](atomDataArray.length);
        for (uint256 i = 0; i < atomDataArray.length; i++) {
            atomIds[i] = keccak256(abi.encodePacked("atom", atomIdCounter++));
        }
        return atomIds;
    }

    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256 value
    ) external returns (bytes32[] memory tripleIds) {
        tripleIds = new bytes32[](subjectIds.length);
        for (uint256 i = 0; i < subjectIds.length; i++) {
            tripleIds[i] = keccak256(abi.encodePacked("triple", tripleIdCounter++));
        }
        return tripleIds;
    }

    function deposit(
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 value,
        uint256 minSharesToReceive
    ) external returns (uint256 shares) {
        shares = value; // 1:1 conversion for simplicity
        require(shares >= minSharesToReceive, "MockMultiVault: insufficient shares");
        return shares;
    }

    function batchDeposit(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata amounts,
        uint256[] calldata minSharesToReceive
    ) external returns (uint256[] memory shares) {
        shares = new uint256[](termIds.length);
        for (uint256 i = 0; i < termIds.length; i++) {
            shares[i] = amounts[i]; // 1:1 conversion for simplicity
            require(shares[i] >= minSharesToReceive[i], "MockMultiVault: insufficient shares");
        }
        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 minAssetsToReceive
    ) external returns (uint256 assets) {
        assets = shares; // 1:1 conversion for simplicity
        require(assets >= minAssetsToReceive, "MockMultiVault: insufficient assets");
        return assets;
    }

    function batchRedeem(
        uint256[] calldata shares,
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata minAssetsToReceive
    ) external returns (uint256[] memory assets) {
        assets = new uint256[](shares.length);
        for (uint256 i = 0; i < shares.length; i++) {
            assets[i] = shares[i]; // 1:1 conversion for simplicity
            require(assets[i] >= minAssetsToReceive[i], "MockMultiVault: insufficient assets");
        }
        return assets;
    }
}
