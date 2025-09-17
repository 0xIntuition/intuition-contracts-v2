// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { MetaERC20DispatchInit } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { CoreEmissionsController } from "src/protocol/emissions/CoreEmissionsController.sol";
import { FinalityState, MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

/**
 * @title  SatelliteEmissionsController
 * @author 0xIntuition
 * @notice Controls the transfers of TRUST tokens from the TrustBonding contract.
 */
contract SatelliteEmissionsController is
    ISatelliteEmissionsController,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    MetaERC20Dispatcher,
    CoreEmissionsController
{
    using SafeERC20 for IERC20;

    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    /// @notice Address of the TrustBonding contract
    address internal _TRUST_BONDING;

    /// @notice Address of the BaseEmissionsController contract
    address internal _BASE_EMISSIONS_CONTROLLER;

    /// @notice Mapping of bridged rewards for each epoch
    mapping(uint256 epoch => uint256 amount) internal _bridgedRewards;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address trustBonding,
        address baseEmissionsController,
        MetaERC20DispatchInit memory metaERC20DispatchInit,
        CoreEmissionsControllerInit memory checkpointInit
    )
        external
        initializer
    {
        if (admin == address(0) || trustBonding == address(0) || baseEmissionsController == address(0)) {
            revert SatelliteEmissionsController_InvalidAddress();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        __CoreEmissionsController_init(
            checkpointInit.startTimestamp,
            checkpointInit.emissionsLength,
            checkpointInit.emissionsPerEpoch,
            checkpointInit.emissionsReductionCliff,
            checkpointInit.emissionsReductionBasisPoints
        );

        __MetaERC20Dispatcher_init(
            metaERC20DispatchInit.hubOrSpoke,
            metaERC20DispatchInit.recipientDomain,
            metaERC20DispatchInit.gasLimit,
            metaERC20DispatchInit.finalityState
        );

        // Initialize access control
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, trustBonding);

        _TRUST_BONDING = trustBonding;
        _BASE_EMISSIONS_CONTROLLER = baseEmissionsController;
    }

    /* =================================================== */
    /*                      RECEIVE                        */
    /* =================================================== */

    /**
     * @notice The SatelliteEmissionsController will receive TRUST tokens from the BaseEmissionsController and hold
     * those tokens until a user claims their rewards or until they are bridged back to the BaseEmissionsController to
     * be burned.
     */
    receive() external payable { }

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    /// @inheritdoc ISatelliteEmissionsController
    function transfer(address recipient, uint256 amount) external nonReentrant onlyRole(CONTROLLER_ROLE) {
        if (recipient == address(0)) revert SatelliteEmissionsController_InvalidAddress();
        if (amount == 0) revert SatelliteEmissionsController_InvalidAmount();
        if (address(this).balance < amount) revert SatelliteEmissionsController_InsufficientBalance();
        Address.sendValue(payable(recipient), amount);
    }

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    /// @inheritdoc ISatelliteEmissionsController
    function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMessageGasCost(newGasCost);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function setFinalityState(FinalityState newFinalityState) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFinalityState(newFinalityState);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMetaERC20SpokeOrHub(newMetaERC20SpokeOrHub);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function setRecipientDomain(uint32 newRecipientDomain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRecipientDomain(newRecipientDomain);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function bridgeUnclaimedRewards(uint256 epoch) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        // Prevent bridging of zero amount if no unclaimed rewards are available.
        uint256 amount = ITrustBonding(_TRUST_BONDING).getUnclaimedRewardsForEpoch(epoch);
        if (amount == 0) {
            revert SatelliteEmissionsController_InvalidBridgeAmount();
        }

        // Check if rewards for this epoch have already been reclaimed and bridged.
        if (_bridgedRewards[epoch] > 0) {
            revert SatelliteEmissionsController_PreviouslyBridgedUnclaimedRewards();
        }

        // Mark the unclaimed rewards as bridged and prevent from being claimed again.
        _bridgedRewards[epoch] = amount;

        // Calculate gas limit for the bridge transfer using the MetaLayer router.
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (msg.value < gasLimit) {
            revert SatelliteEmissionsController_InsufficientGasPayment();
        }

        // Bridge the unclaimed rewards back to the base emissions controller.
        // Reference the MetaERC20Dispatcher smart contract for more details.
        _bridgeTokensViaNativeToken(
            _metaERC20SpokeOrHub,
            _recipientDomain,
            bytes32(uint256(uint160(_BASE_EMISSIONS_CONTROLLER))),
            amount,
            gasLimit,
            _finalityState
        );

        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit);
        }
    }
}
