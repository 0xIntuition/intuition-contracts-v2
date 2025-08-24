// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { FinalityState, IMetaERC20Hub, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

contract MetaERC20Dispatcher {
    uint256 public constant GAS_CONSTANT = 100_000;

    function _bridgeTokens(
        address _metaERC20Hub,
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    )
        internal
    {
        IMetaERC20Hub(_metaERC20Hub).transferRemote{ value: _gasLimit }(
            _recipientDomain, _recipientAddress, _amount, GAS_CONSTANT, _finalityState
        );
    }
}
