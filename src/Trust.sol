// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { AccessControlUpgradeable } from "@openzeppelinV4/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ITrust } from "src/interfaces/ITrust.sol";
import { TrustToken } from "src/legacy/TrustToken.sol";

/**
 * @title  Trust
 * @author 0xIntuition
 * @notice The Intuition TRUST token.
 */
contract Trust is ITrust, TrustToken, AccessControlUpgradeable {
    /* =================================================== */
    /*                       V2 STATE                      */
    /* =================================================== */

    /// @notice BaseEmissionsController contract address
    address public baseEmissionsController;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                       MODIFIERS                     */
    /* =================================================== */

    /// @notice Modifier to restrict access to only the BaseEmissionsController
    modifier onlyBaseEmissionsController() {
        if (msg.sender != baseEmissionsController) {
            revert Trust_OnlyBaseEmissionsController();
        }
        _;
    }

    /* =================================================== */
    /*                       CONSTRUCTOR                   */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                      REINITIALIZER                  */
    /* =================================================== */

    /**
     * @notice Reinitializes the Trust contract with AccessControl
     * @param _admin Admin address (multisig)
     * @param _baseEmissionsController BaseEmissionsController address
     */
    function reinitialize(address _admin, address _baseEmissionsController) external reinitializer(2) {
        if (_admin == address(0) || _baseEmissionsController == address(0)) {
            revert Trust_ZeroAddress();
        }

        // Initialize AccessControl
        __AccessControl_init();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        // Set the BaseEmissionsController address
        _setBaseEmissionsController(_baseEmissionsController);
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice Returns the name of the token
     * @dev Overrides the `name` function from ERC20Upgradeable
     * @return Name of the token
     */
    function name() public view virtual override returns (string memory) {
        return "Intuition";
    }

    /* =================================================== */
    /*                    MINTER FUNCTIONS                 */
    /* =================================================== */

    /// @inheritdoc ITrust
    function mint(address to, uint256 amount) public override(ITrust, TrustToken) onlyBaseEmissionsController {
        _mint(to, amount);
    }

    /// @inheritdoc ITrust
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /* =================================================== */
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

    /// @inheritdoc ITrust
    function setBaseEmissionsController(address newBaseEmissionsController) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseEmissionsController(newBaseEmissionsController);
    }

    /* =================================================== */
    /*                    INTERNAL FUNCTIONS               */
    /* =================================================== */

    function _setBaseEmissionsController(address newBaseEmissionsController) internal {
        if (newBaseEmissionsController == address(0)) {
            revert Trust_ZeroAddress();
        }

        baseEmissionsController = newBaseEmissionsController;

        emit BaseEmissionsControllerSet(newBaseEmissionsController);
    }
}
