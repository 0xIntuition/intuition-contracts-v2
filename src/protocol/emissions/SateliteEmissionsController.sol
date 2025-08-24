// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  SateliteEmissionsController
 * @author 0xIntuition
 * @notice Controls the transfers of TRUST tokens from the TrustBonding contract.
 */
contract SateliteEmissionsController is ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /* =================================================== */
    /*                  CONSTANTS                          */
    /* =================================================== */

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* =================================================== */
    /*                  INTERNAL STATE                     */
    /* =================================================== */

    IERC20 public _token;

    /// @notice Maximum annual emission of Trust tokens
    uint256 internal _maxAnnualEmission;

    /// @notice Initial supply of TRUST on Base.
    uint256 internal _supplyBase;

    /// @notice  Trust tokens minted and bridged to Intuition.
    uint256 internal _supplyReceived;

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error Unauthorized();

    error SateliteEmissionsController_InvalidAddress();

    error SateliteEmissionsController_InvalidAmount();
    error SateliteEmissionsController_InsufficientBalance();

    modifier onlyController() {
        if (!hasRole(CONTROLLER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address controller) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        // Initialize access control
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, controller);
    }

    function transfer(address recipient, uint256 amount) external onlyController nonReentrant {
        if (amount == 0) revert SateliteEmissionsController_InvalidAmount();
        if (address(this).balance < amount) revert SateliteEmissionsController_InsufficientBalance();
        Address.sendValue(payable(recipient), amount);
    }
}
