// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import { FinalityState, IMetaERC20HubOrSpoke, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BaseSepoliaMinterAndBridge is MetaERC20Dispatcher, AccessControl {
    address public token;

    address public metaERC20Hub;

    constructor(address _owner, address _token, address _metaERC20Hub) {
        token = _token;
        metaERC20Hub = _metaERC20Hub;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    receive() external payable { }

    function bridge(address to, uint32 domain, uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(metaERC20Hub, amount);

        IIGP igp = IIGP(IMetalayerRouter(IMetaERC20HubOrSpoke(metaERC20Hub).metalayerRouter()).igp());

        uint256 gasLimit;
        try igp.quoteGasPayment(domain, GAS_CONSTANT + 125_000) returns (uint256 _gasLimit) {
            gasLimit = _gasLimit;
        } catch {
            gasLimit = 34_750_000_000_000;
        }
        require(msg.value >= gasLimit, "Not enough value sent");

        _bridgeTokensViaERC20(
            metaERC20Hub, domain, bytes32(uint256(uint160(to))), amount, gasLimit, FinalityState.INSTANT
        );

        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit);
        }
    }
}
