// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { ITrust } from "src/interfaces/ITrust.sol";
import { MetaERC20DispatchInit } from "src/interfaces/IMetaLayer.sol";
import { CoreEmissionsControllerInit } from "src/interfaces/ICoreEmissionsController.sol";
import { CoreEmissionsController } from "src/protocol/emissions/CoreEmissionsController.sol";
import { FinalityState, MetaERC20Dispatcher } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

/**
 * @title  BaseEmissionsController
 * @author 0xIntuition
 * @notice Controls the release of TRUST tokens by sending mint requests to the TRUST token.
 */
contract BaseEmissionsController is
    IBaseEmissionsController,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    CoreEmissionsController,
    MetaERC20Dispatcher
{
    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @notice Access control role for controllers who can mint tokens
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* =================================================== */
    /*                       STATE                         */
    /* =================================================== */

    /// @notice Trust token contract address
    address internal _TRUST_TOKEN;

    /// @notice Address of the emissions controller on the satellite chain
    address internal _SATELLITE_EMISSIONS_CONTROLLER;

    /// @notice Total amount of Trust tokens minted
    uint256 internal _totalMintedAmount;

    /// @notice Mapping of minted amounts for each epoch
    mapping(uint256 epoch => uint256 amount) internal _epochToMintedAmount;

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
        address controller,
        address token,
        MetaERC20DispatchInit memory metaERC20DispatchInit,
        CoreEmissionsControllerInit memory checkpointInit
    )
        external
        initializer
    {
        if (admin == address(0) || controller == address(0) || token == address(0)) {
            revert BaseEmissionsController_InvalidAddress();
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

        // Assign the roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, controller);

        // Set the Trust token contract address
        _setTrustToken(token);
    }

    /// @notice Receive native gas token to fund cross-chain messages
    receive() external payable {
        emit Transfer(_msgSender(), address(this), msg.value);
     }

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc IBaseEmissionsController
    function getTrustToken() external view returns (address) {
        return _TRUST_TOKEN;
    }

    /// @inheritdoc IBaseEmissionsController
    function getSatelliteEmissionsController() external view returns (address) {
        return _SATELLITE_EMISSIONS_CONTROLLER;
    }

    /// @inheritdoc IBaseEmissionsController
    function getTotalMinted() external view returns (uint256) {
        return _totalMintedAmount;
    }

    /// @inheritdoc IBaseEmissionsController
    function getEpochMintedAmount(uint256 epoch) external view returns (uint256) {
        return _epochToMintedAmount[epoch];
    }

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    /// @inheritdoc IBaseEmissionsController
    function mintAndBridgeCurrentEpoch() external nonReentrant onlyRole(CONTROLLER_ROLE) {
        uint256 currentEpoch = _currentEpoch();
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        _mintAndBridge(currentEpoch, gasLimit);
    }

    /// @inheritdoc IBaseEmissionsController
    function mintAndBridge(uint256 epoch) external payable nonReentrant onlyRole(CONTROLLER_ROLE) {
        _mintAndBridge(epoch, msg.value);
    }

    /* =================================================== */
    /*                       ADMIN                         */
    /* =================================================== */

    /// @inheritdoc IBaseEmissionsController
    function setTrustToken(address newToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustToken(newToken);
    }

    /// @inheritdoc IBaseEmissionsController
    function setSatelliteEmissionsController(address newSatellite) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSatelliteEmissionsController(newSatellite);
    }

    /// @inheritdoc IBaseEmissionsController
    function setMessageGasCost(uint256 newGasCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMessageGasCost(newGasCost);
    }

    /// @inheritdoc IBaseEmissionsController
    function setFinalityState(FinalityState newFinalityState) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFinalityState(newFinalityState);
    }

    /// @inheritdoc IBaseEmissionsController
    function setMetaERC20SpokeOrHub(address newMetaERC20SpokeOrHub) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMetaERC20SpokeOrHub(newMetaERC20SpokeOrHub);
    }

    /// @inheritdoc IBaseEmissionsController
    function setRecipientDomain(uint32 newRecipientDomain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRecipientDomain(newRecipientDomain);
    }

    /// @inheritdoc IBaseEmissionsController
    function burn(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount > _balanceBurnable()) {
            revert BaseEmissionsController_InsufficientBurnableBalance();
        }

        ITrust(_TRUST_TOKEN).burn(amount);

        emit TrustBurned(address(this), amount);
    }

    /// @inheritdoc IBaseEmissionsController
    function withdraw(uint256 amount) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        emit Transfer(address(this), _msgSender(), amount);
        Address.sendValue(payable(_msgSender()), amount);
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    function _mintAndBridge(uint256 epoch, uint256 value) internal onlyRole(CONTROLLER_ROLE) {
        if (_SATELLITE_EMISSIONS_CONTROLLER == address(0)) {
            revert BaseEmissionsController_SatelliteEmissionsControllerNotSet();
        }

        uint256 currentEpoch = _currentEpoch();

        if (epoch > currentEpoch) {
            revert BaseEmissionsController_InvalidEpoch();
        }

        if (_epochToMintedAmount[epoch] > 0) {
            revert BaseEmissionsController_EpochMintingLimitExceeded();
        }

        uint256 amount = _emissionsAtEpoch(epoch);
        _totalMintedAmount += amount;
        _epochToMintedAmount[epoch] = amount;

        // Mint new TRUST using the calculated epoch emissions
        ITrust(_TRUST_TOKEN).mint(address(this), amount);
        IERC20(_TRUST_TOKEN).approve(_metaERC20SpokeOrHub, amount);

        // Bridge new emissions to the Satellite Emissions Controller
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (value < gasLimit) {
            revert BaseEmissionsController_InsufficientGasPayment();
        }

        _bridgeTokensViaERC20(
            _metaERC20SpokeOrHub,
            _recipientDomain,
            bytes32(uint256(uint160(_SATELLITE_EMISSIONS_CONTROLLER))),
            amount,
            gasLimit,
            _finalityState
        );

        if (value > gasLimit) {
            Address.sendValue(payable(_msgSender()), value - gasLimit);
        }

        emit TrustMintedAndBridged(_SATELLITE_EMISSIONS_CONTROLLER, amount, epoch);
    }

    function _setTrustToken(address newToken) internal {
        if (newToken == address(0)) {
            revert BaseEmissionsController_InvalidAddress();
        }
        _TRUST_TOKEN = newToken;
        emit TrustTokenUpdated(newToken);
    }

    function _setSatelliteEmissionsController(address newSatellite) internal {
        if (newSatellite == address(0)) {
            revert BaseEmissionsController_InvalidAddress();
        }
        _SATELLITE_EMISSIONS_CONTROLLER = newSatellite;
        emit SatelliteEmissionsControllerUpdated(newSatellite);
    }

    function _balanceBurnable() internal view returns (uint256) {
        return IERC20(_TRUST_TOKEN).balanceOf(address(this));
    }
}
