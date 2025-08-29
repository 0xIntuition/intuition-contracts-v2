// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ITrust } from "src/interfaces/ITrust.sol";
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

struct BaseEmissionsControllerInitializeParams {
    address admin;
    address minter;
    address trustToken;
    address metaERC20Hub;
    address satelliteEmissionsController;
    uint32 recipientDomain;
    uint256 maxAnnualEmission;
    uint256 maxEmissionPerEpochBasisPoints;
    uint256 annualReductionBasisPoints;
    uint256 startTimestamp;
    uint256 epochDuration;
}

/**
 * @title  BaseEmissionsController
 * @author 0xIntuition
 * @notice Controls the release of TRUST tokens by sending mint requests to the TRUST token.
 */
contract BaseEmissionsController is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    MetaERC20Dispatcher,
    CoreEmissionsController
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
    address public trustToken;

    /// @notice Address of the emissions controller on the satellite chain
    address public satelliteEmissionsController;

    /// @notice Total amount of Trust tokens minted
    uint256 internal _totalMintedAmount;

    mapping(uint256 epoch => uint256 amount) internal _epochToMintedAmount;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Event emitted when Trust tokens are minted
     * @param to Address that received the minted Trust tokens
     * @param amount Amount of Trust tokens minted
     */
    event TrustMinted(address indexed to, uint256 amount);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error BaseEmissionsController_InvalidEpoch();

    error BaseEmissionsController_InsufficientGasPayment();

    error BaseEmissionsController_EpochMintingLimitExceeded();

    error BaseEmissionsController_InsufficientBurnableBalance();

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
        address satellite,
        MetaERC20DispatchInit memory metaERC20DispatchInit,
        CoreEmissionsControllerInit memory checkpointInit
    )
        external
        initializer
    {
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
        trustToken = token;
        satellite = satellite;
    }

    function getTotalMinted() external view returns (uint256) {
        return _totalMintedAmount;
    }

    function getEpochMintedAmount(uint256 epoch) external view returns (uint256) {
        return _epochToMintedAmount[epoch];
    }

    /* =================================================== */
    /*                    CONTROLLER                       */
    /* =================================================== */

    /**
     * @notice Mint new energy tokens to an address
     */
    function mintAndBridge(uint256 epoch) external payable nonReentrant onlyRole(CONTROLLER_ROLE) {
        uint256 currentEpoch = _currentEpoch();

        if (epoch > currentEpoch) {
            revert BaseEmissionsController_InvalidEpoch();
        }

        if (_epochToMintedAmount[epoch] > 0) {
            revert BaseEmissionsController_EpochMintingLimitExceeded();
        }

        uint256 emissionsAmount = _emissionsAtEpoch(epoch);
        _totalMintedAmount += emissionsAmount;
        _epochToMintedAmount[epoch] = emissionsAmount;

        // Mint new TRUST using the calculated epoch emissions
        ITrust(trustToken).mint(address(this), emissionsAmount);
        ITrust(trustToken).approve(_metaERC20SpokeOrHub, emissionsAmount);

        // Bridge new emissions to the Satellite Emissions Controller
        uint256 gasLimit = _quoteGasPayment(_recipientDomain, GAS_CONSTANT + _messageGasCost);
        if (msg.value < gasLimit) {
            revert BaseEmissionsController_InsufficientGasPayment();
        }
        _bridgeTokens(
            _metaERC20SpokeOrHub,
            _recipientDomain,
            bytes32(uint256(uint160(satelliteEmissionsController))),
            emissionsAmount,
            gasLimit,
            _finalityState
        );
        if (msg.value > gasLimit) {
            Address.sendValue(payable(msg.sender), msg.value - gasLimit);
        }
    }

    function burn(uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        if (amount > _balanceBurnable()) {
            revert BaseEmissionsController_InsufficientBurnableBalance();
        }
        ITrust(trustToken).burn(address(this), amount);
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

    /* =================================================== */
    /*                      INTERNAL                       */
    /* =================================================== */

    function _balanceBurnable() internal view returns (uint256) {
        return ITrust(trustToken).balanceOf(address(this));
    }
}
