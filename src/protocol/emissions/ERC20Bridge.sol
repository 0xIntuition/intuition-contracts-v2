// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

interface IMetaERC20Hub {
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    ) payable external;
}

contract ERC20Bridge {

    function _bridgeTokens(
        address _metaERC20Hub,
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    ) internal {
        IMetaERC20Hub(_metaERC20Hub).transferRemote{value: msg.value}(
            _recipientDomain,
            _recipientAddress,
            _amount,
            _gasLimit,
            _finalityState
        );
    }
}