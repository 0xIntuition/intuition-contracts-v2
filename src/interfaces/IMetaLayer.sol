// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

struct MetaERC20DispatchInit {
    address hubOrSpoke;
    uint32 recipientDomain;
    address recipientAddress;
    uint256 gasLimit;
    FinalityState finalityState;
}

enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

interface IMetaERC20HubOrSpoke {
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    )
        external
        payable;

    function metalayerRouter() external view returns (address);
}

interface IMetalayerRouter {
    function igp() external view returns (address);
}

interface IIGP {
    function quoteGasPayment(uint32 destinationDomain, uint256 gasLimit) external view returns (uint256);
}
