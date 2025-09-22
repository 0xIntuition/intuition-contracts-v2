// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FinalityState } from "src/interfaces/IMetaLayer.sol";

contract IIGPMock {
    function quoteGasPayment(uint32 domain, uint256 gasLimit) external view returns (uint256) {
        return 0.025 ether; // Return a fixed gas quote for testing
    }
}

contract MetalayerRouterMock {
    address public igpAddress;

    constructor(address _igp) {
        igpAddress = _igp;
    }

    function igp() external view returns (address) {
        return igpAddress;
    }
}

contract MetaERC20HubOrSpokeMock {
    address public router;

    constructor(address _router) {
        router = _router;
    }

    function metalayerRouter() external view returns (address) {
        return router;
    }

    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    )
        external
        payable
    {
        return;
    }
}
