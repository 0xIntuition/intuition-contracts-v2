// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import { ERC20Upgradeable } from "@openzeppelinV4/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelinV4/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelinV4/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title  Trust
 * @author 0xIntuition
 * @notice The Intuition TRUST token.
 */
contract Trust is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    /*//////////////////////////////////////////////////////////////
                        LEGACY CONSTANTS & VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Legacy variable - maximum supply of Trust tokens (this now represents the initial supply)
    uint256 public constant LEGACY_MAX_SUPPLY = 1e9 * 1e18;

    /// @notice Legacy variables - initial minter addresses
    address public constant LEGACY_MINTER_A = 0xBc01aB3839bE8933f6B93163d129a823684f4CDF;
    address public constant LEGACY_MINTER_B = 0xA4Df56842887cF52C9ad59C97Ec0C058e96Af533;

    /**
     * @notice Legacy variable - total amount of Trust tokens minted initially, equals the LEGACY_MAX_SUPPLY and
     * INITIAL_SUPPLY
     * @dev This variable is kept here in order to make sure storage layout is the same as the original contract
     */
    uint256 public legacyTotalMinted;

    /**
     * @notice Legacy variable - mapping of minter addresses to the amount of Trust tokens minted by them when
     *         the initial supply was minted
     * @dev This variable is kept here in order to make sure storage layout is the same as the original contract
     */
    mapping(address minter => uint256 amountMinted) public legacyMinterAmountMinted;

    /*//////////////////////////////////////////////////////////////
                            V2 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role for minting tokens
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Role for pausing/unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role for initializing the contract
    /// WARNING: UPDATE TO BASE ADMIN BEFORE DEPLOY
    address public constant INITIAL_ADMIN = address(0);

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Gap for upgrade safety (reduced to account for AccessControl storage)
    uint256[50] private __gap;

    error Trust_ZeroAddress();
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
        // WARNING: UPDATE TO BASE ADMIN BEFORE DEPLOY
        if (INITIAL_ADMIN != address(0)) {
            if (msg.sender != INITIAL_ADMIN) {
                revert Trust_OnlyInitialAdmin();
            }
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
     * @notice Mint new energy tokens to an address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _burn(from, amount);
    }
}
