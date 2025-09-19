// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { FinalityState, IMetaERC20HubOrSpoke, IMetalayerRouter, IIGP } from "src/interfaces/IMetaLayer.sol";

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
    /*                      ERRORS                         */
    /* =================================================== */

    error MetaERC20Dispatcher_InvalidAddress();

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    function __MetaERC20Dispatcher_init(
        address metaERC20SpokeOrHub,
        uint32 recipientDomain,
        uint256 gasCost,
        FinalityState finalityState
    )
        internal
    {
        // Initialize MetaERC20Dispatcher
        _setMetaERC20SpokeOrHub(metaERC20SpokeOrHub);
        _setRecipientDomain(recipientDomain);
        _setMessageGasCost(gasCost);
        _setFinalityState(finalityState);
    }

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    function getRecipientDomain() external view returns (uint32) {
        return _recipientDomain;
    }

    function getMetaERC20SpokeOrHub() external view returns (address) {
        return _metaERC20SpokeOrHub;
    }

    function getFinalityState() external view returns (FinalityState) {
        return _finalityState;
    }

    function getMessageGasCost() external view returns (uint256) {
        return _messageGasCost;
    }

    /* =================================================== */
    /*                      INTERNAL                       */
    /* =================================================== */

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
        if (newMetaERC20SpokeOrHub == address(0)) {
            revert MetaERC20Dispatcher_InvalidAddress();
        }
        _metaERC20SpokeOrHub = newMetaERC20SpokeOrHub;
        emit MetaERC20SpokeOrHubUpdated(newMetaERC20SpokeOrHub);
    }

    function _quoteGasPayment(uint32 domain, uint256 gasLimit) internal view returns (uint256) {
        IIGP igp = IIGP(IMetalayerRouter(IMetaERC20HubOrSpoke(_metaERC20SpokeOrHub).metalayerRouter()).igp());
        return igp.quoteGasPayment(domain, gasLimit);
    }

    function _bridgeTokensViaERC20(
        address _hubOrSpoke,
        uint32 _domain,
        bytes32 _recipient,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finality
    )
        internal
    {
        IMetaERC20HubOrSpoke(_hubOrSpoke).transferRemote{ value: _gasLimit }(
            _domain, _recipient, _amount, GAS_CONSTANT, _finality
        );
    }

    /**
     * @notice Bridges tokens to a destination chain using a specific Arbitrum precompile responsible for minting and
     * burning a chains native gas token.
     * @dev
     * https://github.com/OffchainLabs/nitro/blob/8f4fec5e7cd2ed856f8ea42490271989659ea695/precompiles/ArbNativeTokenManager.go#L28-L57
     * @dev
     * https://github.com/OffchainLabs/nitro-precompile-interfaces/blob/fe4121240ca1ee2cbf07d67d0e6c38015d94e704/ArbNativeTokenManager.sol
     */
    function _bridgeTokensViaNativeToken(
        address _hubOrSpoke,
        uint32 _domain,
        bytes32 _recipient,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finality
    )
        internal
    {
        // When bridging using a native token the `value` must include the `_gasLimit` and `amount` before being
        // sent to the MetaERC20HubOrSpoke smart contract. Only the amount is burned and the `gasLimit` is used to pay
        // for the
        // cross-chain message.
        IMetaERC20HubOrSpoke(_hubOrSpoke).transferRemote{ value: _gasLimit + _amount }(
            _domain, _recipient, _amount, GAS_CONSTANT, _finality
        );
    }
}
