// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

contract IIGPMock {
    function quoteGasPayment(uint32, /* domain */ uint256 /* gasLimit */ ) external pure returns (uint256) {
        return 0 ether; // Return a fixed gas quote for testing
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

contract MetaERC20HubMock {
    address public router;

    constructor(address _router) {
        router = _router;
    }

    function metalayerRouter() external view returns (address) {
        return router;
    }

    function transferRemote(
        uint32, /* _recipientDomain */
        bytes32, /* _recipientAddress */
        uint256, /* _amount */
        uint256, /* _gasLimit */
        FinalityState /* _finalityState */
    )
        external
        payable
    {
        return;
    }
}
