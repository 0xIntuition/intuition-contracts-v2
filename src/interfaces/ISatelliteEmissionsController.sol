// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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
     * @notice Event emitted when the BaseEmissionsController address is updated
     * @param newBaseEmissionsController The new BaseEmissionsController address
     */
    event BaseEmissionsControllerUpdated(address indexed newBaseEmissionsController);

    /**
     * @notice Event emitted when native tokens are transferred
     * @param recipient Address that received the native tokens
     * @param amount Amount of native tokens transferred
     */
    event NativeTokenTransferred(address indexed recipient, uint256 amount);

    /**
     * @notice Event emitted when unclaimed rewards are bridged back to the BaseEmissionsController
     * @param epoch The epoch for which unclaimed rewards were bridged
     * @param amount The amount of unclaimed rewards bridged
     */
    event UnclaimedRewardsBridged(uint256 indexed epoch, uint256 amount);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error SatelliteEmissionsController_InvalidAddress();
    error SatelliteEmissionsController_InvalidAmount();
    error SatelliteEmissionsController_InvalidBridgeAmount();
    error SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions();
    error SatelliteEmissionsController_InsufficientBalance();
    error SatelliteEmissionsController_InsufficientGasPayment();

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    /**
     * @notice Get the TrustBonding contract address
     * @return The address of the TrustBonding contract
     */
    function getTrustBonding() external view returns (address);

    /**
     * @notice Get the BaseEmissionsController contract address
     * @return The address of the BaseEmissionsController contract
     */
    function getBaseEmissionsController() external view returns (address);

    /**
     * @notice Get the amount of emissions bridged back to Base for a specific epoch
     * @param epoch The epoch to query
     * @return The amount of emissions bridged back to Base for the given epoch
     */
    function getBridgedEmissions(uint256 epoch) external view returns (uint256);

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
     * @param newTrustBonding The new TrustBonding contract address
     */
    function setTrustBonding(address newTrustBonding) external;

    /**
     * @notice Set the BaseEmissionsController contract address
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
     * @param newBaseEmissionsController The new BaseEmissionsController contract address
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
     * @notice Bridges unclaimed emissions for a specific epoch back to the BaseEmissionsController
     * @dev The SatelliteEmissionsController can only bridge unclaimed emission once the claiming period for that epoch
     * has ended, which is enforced in the TrustBonding contract. Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @param epoch The epoch for which to bridge unclaimed emissions
     */
    function bridgeUnclaimedEmissions(uint256 epoch) external payable;
}
