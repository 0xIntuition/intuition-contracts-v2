// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import { AccessControlUpgradeable } from "@openzeppelinV4/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { TrustToken } from "src/legacy/TrustToken.sol";

/**
 * @title  Trust
 * @author 0xIntuition
 * @notice The Intuition TRUST token.
 */
contract Trust is TrustToken, AccessControlUpgradeable {
    /*//////////////////////////////////////////////////////////////
                            V2 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the initial admin, which is allowed to perform the contract reinitialization
    address public constant INITIAL_ADMIN = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;

    /*//////////////////////////////////////////////////////////////
                            V2 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice BaseEmissionsController contract address
    address public baseEmissionsController;

    /// @dev Gap for upgrade safety (reduced to account for AccessControl storage)
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the BaseEmissionsController address is set
    /// @param newBaseEmissionsController The new BaseEmissionsController address
    event BaseEmissionsControllerSet(address indexed newBaseEmissionsController);

    /*//////////////////////////////////////////////////////////////
                                 CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Custom error for when a zero address is provided
    error Trust_ZeroAddress();

    /// @notice Custom error for when the caller is not the BaseEmissionsController
    error Trust_OnlyBaseEmissionsController();

    /// @notice Custom error for when the caller is not the initial admin
    error Trust_OnlyInitialAdmin();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict access to only the BaseEmissionsController
    modifier onlyBaseEmissionsController() {
        if (msg.sender != baseEmissionsController) {
            revert Trust_OnlyBaseEmissionsController();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reinitializes the Trust contract with AccessControl
     * @param _admin Admin address (multisig)
     * @param _baseEmissionsController BaseEmissionsController address
     */
    function reinitialize(address _admin, address _baseEmissionsController) external reinitializer(2) {
        if (msg.sender != INITIAL_ADMIN) {
            revert Trust_OnlyInitialAdmin();
        }

        if (_admin == address(0) || _baseEmissionsController == address(0)) {
            revert Trust_ZeroAddress();
        }

        // Initialize AccessControl
        __AccessControl_init();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        baseEmissionsController = _baseEmissionsController;

        emit BaseEmissionsControllerSet(_baseEmissionsController);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the name of the token
     * @dev Overrides the `name` function in ERC20Upgradeable
     * @return Name of the token
     */
    function name() public view virtual override returns (string memory) {
        return "Intuition";
    }

    /*//////////////////////////////////////////////////////////////
                             MINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint new TRUST tokens to an address
     * @dev Only BaseEmissionsController contract can call this function
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public override onlyBaseEmissionsController {
        _mint(to, amount);
    }

    /**
     * @notice Burn TRUST tokens from the caller's address
     * @dev Caller must have enough balance to burn and can only burn their own tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
