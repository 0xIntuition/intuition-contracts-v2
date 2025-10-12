// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import {
    MetaERC20DispatchInit,
    FinalityState,
    IMetaERC20HubOrSpoke,
    IMetalayerRouter,
    IIGP
} from "src/interfaces/IMetaLayer.sol";

contract SpokeBridge is MetaERC20Dispatcher, AccessControl {
    error NotEnoughValueSent();

    constructor(address _owner, MetaERC20DispatchInit memory metaERC20DispatchInit) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        __MetaERC20Dispatcher_init(
            metaERC20DispatchInit.hubOrSpoke,
            metaERC20DispatchInit.recipientDomain,
            metaERC20DispatchInit.gasLimit,
            metaERC20DispatchInit.finalityState
        );
    }
    
    function bridge(address to) external payable {
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (msg.value <= gasLimit) {
            revert NotEnoughValueSent();
        }
        uint256 amount = msg.value - gasLimit;
        _bridgeTokensViaNativeToken(
            _metaERC20SpokeOrHub, _recipientDomain, bytes32(uint256(uint160(to))), amount, gasLimit, _finalityState
        );
    }
}
