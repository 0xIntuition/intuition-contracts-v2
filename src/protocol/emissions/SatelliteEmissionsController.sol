// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

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
    CoreEmissionsController,
    MetaERC20Dispatcher
{
    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    /// @notice Address of the TrustBonding contract
    address internal _TRUST_BONDING;

    /// @notice Address of the BaseEmissionsController contract
    address internal _BASE_EMISSIONS_CONTROLLER;

    /// @notice Mapping of reclaimed emissions for each epoch
    mapping(uint256 epoch => uint256 amount) internal _reclaimedEmissions;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address baseEmissionsController,
        MetaERC20DispatchInit memory metaERC20DispatchInit,
        CoreEmissionsControllerInit memory checkpointInit
    )
        external
        initializer
    {
        if (admin == address(0)) {
            revert SatelliteEmissionsController_InvalidAddress();
        }

        // Initialize the AccessControl and ReentrancyGuard contracts
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

        // Set BaseEmissionsController contract address
        _setBaseEmissionsController(baseEmissionsController);
    }

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    /// @inheritdoc ISatelliteEmissionsController
    function getTrustBonding() external view returns (address) {
        return _TRUST_BONDING;
    }

    /// @inheritdoc ISatelliteEmissionsController
    function getBaseEmissionsController() external view returns (address) {
        return _BASE_EMISSIONS_CONTROLLER;
    }

    /// @inheritdoc ISatelliteEmissionsController
    function getReclaimedEmissions(uint256 epoch) external view returns (uint256) {
        return _reclaimedEmissions[epoch];
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

        emit NativeTokenTransferred(recipient, amount);
    }

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    /// @inheritdoc ISatelliteEmissionsController
    function setTrustBonding(address newTrustBonding) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustBonding(newTrustBonding);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function setBaseEmissionsController(address newBaseEmissionsController) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseEmissionsController(newBaseEmissionsController);
    }

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
    function withdrawUnclaimedEmissions(
        uint256 epoch,
        address recipient
    )
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Prevent withdrawing zero amount if no unclaimed emissions are available.
        uint256 amount = ITrustBonding(_TRUST_BONDING).getUnclaimedRewardsForEpoch(epoch);
        if (amount == 0) {
            revert SatelliteEmissionsController_InvalidWithdrawAmount();
        }

        if (recipient == address(0)) {
            revert SatelliteEmissionsController_InvalidAddress();
        }

        // Check if emissions for this epoch have already been reclaimed.
        if (_reclaimedEmissions[epoch] > 0) {
            revert SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions();
        }

        // Mark the unclaimed emissions as reclaimed and prevent from being claimed again.
        _reclaimedEmissions[epoch] = amount;

        // Transfer the unclaimed emissions to the recipient.
        Address.sendValue(payable(recipient), amount);

        emit UnclaimedEmissionsWithdrawn(epoch, recipient, amount);
    }

    /// @inheritdoc ISatelliteEmissionsController
    function bridgeUnclaimedEmissions(uint256 epoch) external payable nonReentrant onlyRole(OPERATOR_ROLE) {
        // Prevent bridging of zero amount if no unclaimed emissions are available.
        uint256 amount = ITrustBonding(_TRUST_BONDING).getUnclaimedRewardsForEpoch(epoch);
        if (amount == 0) {
            revert SatelliteEmissionsController_InvalidBridgeAmount();
        }

        // Check if emissions for this epoch have already been reclaimed and bridged.
        if (_reclaimedEmissions[epoch] > 0) {
            revert SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions();
        }

        // Mark the unclaimed emissions as bridged and prevent from being claimed and bridged again.
        _reclaimedEmissions[epoch] = amount;

        // Calculate gas limit for the bridge transfer using the MetaLayer router.
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (msg.value < gasLimit) {
            revert SatelliteEmissionsController_InsufficientGasPayment();
        }

        // Bridge the unclaimed emissions back to the base emissions controller.
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

        emit UnclaimedEmissionsBridged(epoch, amount);
    }

    /* =================================================== */
    /*                       INTERNAL                      */
    /* =================================================== */

    function _setTrustBonding(address newTrustBonding) internal {
        if (newTrustBonding == address(0)) {
            revert SatelliteEmissionsController_InvalidAddress();
        }
        _TRUST_BONDING = newTrustBonding;
        emit TrustBondingUpdated(newTrustBonding);
    }

    function _setBaseEmissionsController(address newBaseEmissionsController) internal {
        if (newBaseEmissionsController == address(0)) {
            revert SatelliteEmissionsController_InvalidAddress();
        }
        _BASE_EMISSIONS_CONTROLLER = newBaseEmissionsController;
        emit BaseEmissionsControllerUpdated(newBaseEmissionsController);
    }
}
