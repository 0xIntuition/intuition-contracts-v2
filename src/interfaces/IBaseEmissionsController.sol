// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { FinalityState } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

/**
 * @title  IBaseEmissionsController
 * @author 0xIntuition
 * @notice Interface for the BaseEmissionsController that controls the release of TRUST tokens by sending mint requests
 * to the TRUST token.
 */
interface IBaseEmissionsController {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Event emitted when Trust tokens are minted and bridged
     * @param to Address that received the minted Trust tokens
     * @param amount Amount of Trust tokens minted
     * @param epoch Epoch for which the tokens were minted
     */
    event TrustMintedAndBridged(address indexed to, uint256 amount, uint256 epoch);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error BaseEmissionsController_InvalidEpoch();
    error BaseEmissionsController_InsufficientGasPayment();
    error BaseEmissionsController_EpochMintingLimitExceeded();
    error BaseEmissionsController_InsufficientBurnableBalance();

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    /**
     * @notice Get the Trust token contract address
     * @return The address of the Trust token contract
     */
    function getTrustToken() external view returns (address);

    /**
     * @notice Get the Satellite Emissions Controller contract address
     * @return The address of the Satellite Emissions Controller contract
     */
    function getSatelliteEmissionsController() external view returns (address);

    /**
     * @notice Get the total amount of Trust tokens minted
     * @return The total amount of Trust tokens minted
     */
    function getTotalMinted() external view returns (uint256);

    /**
     * @notice Get the amount of Trust tokens minted for a specific epoch
     * @param epoch The epoch to query
     * @return The amount of Trust tokens minted for the given epoch
     */
    function getEpochMintedAmount(uint256 epoch) external view returns (uint256);

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    /**
     * @notice Mint new TRUST tokens for a specific epoch and bridge them to the satellite chain
     * @dev Only callable by addresses with CONTROLLER_ROLE
     * @param epoch The epoch to mint tokens for
     */
    function mintAndBridge(uint256 epoch) external payable;

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    /**
     * @notice Set the message gas cost for cross-chain operations
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newGasCost The new gas cost value
     */
    function setMessageGasCost(uint256 newGasCost) external;

    /**
     * @notice Set the finality state for cross-chain operations
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newFinalityState The new finality state
     */
    function setFinalityState(FinalityState newFinalityState) external;

    /**
     * @notice Set the MetaERC20 spoke or hub contract address
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newMetaERC20SpokeOrHub The new MetaERC20 spoke or hub address
     */
    function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external;

    /**
     * @notice Set the recipient domain for cross-chain operations
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newRecipientDomain The new recipient domain
     */
    function setRecipientDomain(uint32 newRecipientDomain) external;

    /**
     * @notice Burn TRUST tokens held by the contract
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param amount The amount of TRUST tokens to burn
     */
    function burn(uint256 amount) external;
}
