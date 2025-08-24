// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { FinalityState, IMetaERC20Hub, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

contract MetaERC20Dispatcher {
    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */
    uint256 public constant GAS_CONSTANT = 100_000;

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    uint32 internal _recipientDomain;
    address internal _metaERC20SpokeOrHub;
    FinalityState internal _finalityState;
    uint256 internal _messageGasCost;

    /* =================================================== */
    /*                      EVENTS                         */
    /* =================================================== */

    event FinalityStateUpdated(FinalityState newFinalityState);

    event MessageGasCostUpdated(uint256 newMessageGasCost);

    event RecipientDomainUpdated(uint32 newRecipientDomain);

    event MetaERC20SpokeOrHubUpdated(address newMetaERC20SpokeOrHub);

    /* =================================================== */
    /*                      INTERNAL                       */
    /* =================================================== */
    function _quoteGasPayment(uint32 domain, uint256 gasLimit) internal view returns (uint256) {
        IIGP igp = IIGP(IMetalayerRouter(IMetaERC20Hub(_metaERC20SpokeOrHub).metalayerRouter()).igp());
        return igp.quoteGasPayment(domain, gasLimit);
    }

    function _bridgeTokens(
        address _hubOrSpoke,
        uint32 _domain,
        bytes32 _recipient,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finality
    )
        internal
    {
        IMetaERC20Hub(_hubOrSpoke).transferRemote{ value: _gasLimit }(
            _domain, _recipient, _amount, GAS_CONSTANT, _finality
        );
    }

    function _setMessageGasCost(uint256 newGasCost) internal {
        _messageGasCost = newGasCost;
        emit MessageGasCostUpdated(newGasCost);
    }

    function _setFinalityState(FinalityState newFinalityState) internal {
        _finalityState = newFinalityState;
        emit FinalityStateUpdated(newFinalityState);
    }

    function _setRecipientDomain(uint32 newDomain) internal {
        _recipientDomain = newDomain;
        emit RecipientDomainUpdated(newDomain);
    }

    function _setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) internal {
        _metaERC20SpokeOrHub = newMetaERC20SpokeOrHub;
        emit MetaERC20SpokeOrHubUpdated(newMetaERC20SpokeOrHub);
    }
}
