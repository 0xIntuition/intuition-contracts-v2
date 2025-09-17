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

    /// @notice Role for minting tokens
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Address of the initial admin, which is allowed to perform the contract reinitialization
    address public constant INITIAL_ADMIN = 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Custom error for when a zero address is provided
    error Trust_ZeroAddress();

    /// @notice Custom error for when the caller is not the initial admin
    error Trust_OnlyInitialAdmin();

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
     * @param _controller Initial minter address
     */
    function reinitialize(address _admin, address _controller) external reinitializer(2) {
        if (msg.sender != INITIAL_ADMIN) {
            revert Trust_OnlyInitialAdmin();
        }

        if (_admin == address(0) || _controller == address(0)) {
            revert Trust_ZeroAddress();
        }

        // Initialize AccessControl
        __AccessControl_init();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CONTROLLER_ROLE, _controller);
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
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public override onlyRole(CONTROLLER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _burn(from, amount);
    }
}
