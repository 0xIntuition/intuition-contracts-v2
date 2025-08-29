// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { MetaERC20DispatchInit } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { CoreEmissionsController } from "src/protocol/emissions/CoreEmissionsController.sol";
import {
    MetaERC20Dispatcher,
    FinalityState,
    IMetaERC20Hub,
    IIGP,
    IMetalayerRouter
} from "src/protocol/emissions/MetaERC20Dispatcher.sol";

/**
 * @title  SatelliteEmissionsController
 * @author 0xIntuition
 * @notice Controls the transfers of TRUST tokens from the TrustBonding contract.
 */
contract SatelliteEmissionsController is
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
    address internal _trustBonding;
    address internal _baseEmissionsController;

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error Unauthorized();
    error SatelliteEmissionsController_InvalidAddress();
    error SatelliteEmissionsController_InvalidAmount();
    error SatelliteEmissionsController_InsufficientBalance();
    error SatelliteEmissionsController_InsufficientGasPayment();

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

        _trustBonding = trustBonding;
        _baseEmissionsController = baseEmissionsController;
    }

    /* =================================================== */
    /*                       PUBLIC                        */
    /* =================================================== */

    function bridgeUnclaimedRewards() external payable nonReentrant {
        uint256 unclaimedRewards = ITrustBonding(_trustBonding).getUnclaimedRewards();
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);

        if (msg.value < gasLimit) {
            revert SatelliteEmissionsController_InsufficientGasPayment();
        }

        _bridgeTokens(
            _metaERC20SpokeOrHub,
            _recipientDomain,
            bytes32(uint256(uint160(_baseEmissionsController))),
            unclaimedRewards,
            gasLimit,
            _finalityState
        );

        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit);
        }
    }

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    function transfer(address recipient, uint256 amount) external nonReentrant onlyRole(CONTROLLER_ROLE) {
        if (recipient == address(0)) revert SatelliteEmissionsController_InvalidAddress();
        if (amount == 0) revert SatelliteEmissionsController_InvalidAmount();
        if (address(this).balance < amount) revert SatelliteEmissionsController_InsufficientBalance();
        Address.sendValue(payable(recipient), amount);
    }

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMessageGasCost(newGasCost);
    }

    function setFinalityState(FinalityState newFinalityState) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFinalityState(newFinalityState);
    }

    function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMetaERC20SpokeOrHub(newMetaERC20SpokeOrHub);
    }

    function setRecipientDomain(uint32 newRecipientDomain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRecipientDomain(newRecipientDomain);
    }

    function createCheckpoint(
        uint256 startTimestamp,
        uint256 emissionsLength,
        uint256 emissionsReductionCliff,
        uint256 emissionsPerEpoch,
        uint256 emissionsReductionBasisPoints
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _createCheckpoint(
            startTimestamp, emissionsLength, emissionsReductionCliff, emissionsPerEpoch, emissionsReductionBasisPoints
        );
    }

    function transferUnclaimedRewards(address to) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 unclaimedRewards = ITrustBonding(_trustBonding).getUnclaimedRewards();
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);

        if (msg.value < gasLimit) {
            revert SatelliteEmissionsController_InsufficientGasPayment();
        }

        _bridgeTokens(
            _metaERC20SpokeOrHub,
            _recipientDomain,
            bytes32(uint256(uint160(to))),
            unclaimedRewards,
            gasLimit,
            _finalityState
        );

        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit);
        }
    }
}
