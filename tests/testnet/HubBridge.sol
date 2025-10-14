// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract HubBridge is MetaERC20Dispatcher, AccessControl {
    address public token;

    error NotEnoughValueSent();

    constructor(address _owner, address _token, MetaERC20DispatchInit memory metaERC20DispatchInit) {
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        __MetaERC20Dispatcher_init(
            metaERC20DispatchInit.hubOrSpoke,
            metaERC20DispatchInit.recipientDomain,
            metaERC20DispatchInit.gasLimit,
            metaERC20DispatchInit.finalityState
        );
    }

    function bridge(address to, uint256 amount) external payable {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(_metaERC20SpokeOrHub, amount);

        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (msg.value < gasLimit) {
            revert NotEnoughValueSent();
        }

        _bridgeTokensViaERC20(
            _metaERC20SpokeOrHub, _recipientDomain, bytes32(uint256(uint160(to))), amount, gasLimit, _finalityState
        );

        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit); // refund excess
        }
    }

    function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMessageGasCost(newGasCost);
    }
}
