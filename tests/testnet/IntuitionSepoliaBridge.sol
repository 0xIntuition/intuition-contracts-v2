// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";
import { FinalityState, IMetaERC20HubOrSpoke, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

contract IntuitionSepoliaBridge is MetaERC20Dispatcher, AccessControl {
    address public metaERC20Hub;

    error NotEnoughValueSent();

    constructor(address _owner, address _metaERC20Hub) {
        metaERC20Hub = _metaERC20Hub;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    receive() external payable { }

    function bridge(address to, uint32 domain, uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        IIGP igp = IIGP(IMetalayerRouter(IMetaERC20HubOrSpoke(metaERC20Hub).metalayerRouter()).igp());

        uint256 gasLimit = igp.quoteGasPayment(domain, GAS_CONSTANT + 125_000);

        uint256 totalValueNeeded = gasLimit + amount;

        if (msg.value < totalValueNeeded) {
            revert NotEnoughValueSent();
        }

        _bridgeTokensViaNativeToken(
            metaERC20Hub, domain, bytes32(uint256(uint160(to))), amount, gasLimit, FinalityState.INSTANT
        );
    }
}
