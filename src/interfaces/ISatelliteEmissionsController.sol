// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { FinalityState } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

/**
 * @title  ISatelliteEmissionsController
 * @author 0xIntuition
 * @notice Interface for the SatelliteEmissionsController that controls the transfers of TRUST tokens from the
 * TrustBonding contract.
 */
interface ISatelliteEmissionsController {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Event emitted when the TrustBonding address is updated
     * @param newTrustBonding The new TrustBonding address
     */
    event TrustBondingUpdated(address indexed newTrustBonding);

    /**
     * @notice Event emitted when the Base Emissions Controller address is updated
     * @param newBaseEmissionsController The new Base Emissions Controller address
     */
    event BaseEmissionsControllerUpdated(address indexed newBaseEmissionsController);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */
    error SatelliteEmissionsController_InvalidAddress();
    error SatelliteEmissionsController_InvalidAmount();
    error SatelliteEmissionsController_InvalidBridgeAmount();
    error SatelliteEmissionsController_PreviouslyBridgedUnclaimedRewards();
    error SatelliteEmissionsController_InsufficientBalance();
    error SatelliteEmissionsController_InsufficientGasPayment();

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    /**
     * @notice Transfer native tokens to a specified recipient
     * @dev Only callable by addresses with CONTROLLER_ROLE
     * @param recipient The address to transfer tokens to
     * @param amount The amount of native tokens to transfer
     */
    function transfer(address recipient, uint256 amount) external;

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    /**
     * @notice Set the TrustBonding contract address
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newTrustBonding The new TrustBonding address
     */
    function setTrustBonding(address newTrustBonding) external;

    /**
     * @notice Set the BaseEmissionsController contract address
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newBaseEmissionsController The new BaseEmissionsController address
     */
    function setBaseEmissionsController(address newBaseEmissionsController) external;

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
     * @notice Bridges unclaimed rewards for a specific epoch back to the BaseEmissionsController
     * @dev The SatelliteEmissionsController can only bridge unclaimed rewards once the claiming period for that epoch
     * has ended, which is enforced in the TrustBonding contract. Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @param epoch The epoch for which to bridge unclaimed rewards
     */
    function bridgeUnclaimedRewards(uint256 epoch) external payable;
}
