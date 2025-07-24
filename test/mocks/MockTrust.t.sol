// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MockToken} from "test/mocks/MockToken.t.sol";

/**
 * @title MockTrust
 * @author 0xIntuition
 * @notice Mock contract for the Trust token contract
 */
contract MockTrust is MockToken {
    uint256 public maxAnnualEmission;

    constructor(string memory _name, string memory _symbol, uint256 _maxAnnualEmission) MockToken(_name, _symbol) {
        maxAnnualEmission = _maxAnnualEmission;
    }

    function setMaxAnnualEmission(uint256 _maxAnnualEmission) external {
        maxAnnualEmission = _maxAnnualEmission;
    }
}
