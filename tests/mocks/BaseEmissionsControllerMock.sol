// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { FinalityState } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

contract BaseEmissionsControllerMock is IBaseEmissionsController, ICoreEmissionsController {
    uint256 private currentEpoch;
    mapping(uint256 => uint256) private epochMintedAmounts;
    bool public mintAndBridgeCurrentEpochCalled;
    uint256 public mintAndBridgeCallCount;

    function setCurrentEpoch(uint256 _epoch) external {
        currentEpoch = _epoch;
    }

    function setEpochMintedAmount(uint256 epoch, uint256 amount) external {
        epochMintedAmounts[epoch] = amount;
    }

    function mintAndBridgeCurrentEpoch() external {
        mintAndBridgeCurrentEpochCalled = true;
        mintAndBridgeCallCount++;
        epochMintedAmounts[currentEpoch] = 1000 ether;
    }

    function getCurrentEpoch() external view returns (uint256) {
        return currentEpoch;
    }

    function getEpochMintedAmount(uint256 epoch) external view returns (uint256) {
        return epochMintedAmounts[epoch];
    }

    function resetMintAndBridgeCalled() external {
        mintAndBridgeCurrentEpochCalled = false;
    }

    function getTrustToken() external pure returns (address) {
        return address(0);
    }

    function getSatelliteEmissionsController() external pure returns (address) {
        return address(0);
    }

    function getTotalMinted() external pure returns (uint256) {
        return 0;
    }

    function withdraw(uint256) external pure { }

    function mintAndBridge(uint256) external payable { }

    function setTrustToken(address) external pure { }

    function setSatelliteEmissionsController(address) external pure { }

    function setMessageGasCost(uint256) external pure { }

    function setFinalityState(FinalityState) external pure { }

    function setMetaERC20SpokeOrHub(address) external pure { }

    function setRecipientDomain(uint32) external pure { }

    function burn(uint256) external pure { }

    function getStartTimestamp() external pure returns (uint256) {
        return 0;
    }

    function getEpochLength() external pure returns (uint256) {
        return 0;
    }

    function getCurrentEpochTimestampStart() external pure returns (uint256) {
        return 0;
    }

    function getCurrentEpochEmissions() external pure returns (uint256) {
        return 0;
    }

    function getEpochTimestampStart(uint256) external pure returns (uint256) {
        return 0;
    }

    function getEpochTimestampEnd(uint256) external pure returns (uint256) {
        return 0;
    }

    function getEpochAtTimestamp(uint256) external pure returns (uint256) {
        return 0;
    }

    function getEmissionsAtEpoch(uint256) external pure returns (uint256) {
        return 0;
    }

    function getEmissionsAtTimestamp(uint256) external pure returns (uint256) {
        return 0;
    }
}
