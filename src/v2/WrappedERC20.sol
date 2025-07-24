// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {IWrappedERC20} from "src/interfaces/IWrappedERC20.sol";
import {Errors} from "src/libraries/Errors.sol";

/**
 * @title WrappedERC20
 * @author 0xIntuition
 * @notice A wrapped ERC20 token representing shares in a MultiVault term.
 */
contract WrappedERC20 is IWrappedERC20, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice The MultiVault contract
    IMultiVault public multiVault;

    /// @notice Term ID and bonding curve ID combination for which this wrapper is created
    bytes32 public termId;
    uint256 public bondingCurveId;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initializes the WrappedERC20 contract
    ///
    /// @param _multiVault The address of the MultiVault contract
    /// @param _termId The term ID for which this wrapper is created
    /// @param _bondingCurveId The bonding curve ID for which this wrapper is created
    /// @param name_ The name of the WrappedERC20 token
    /// @param symbol_ The symbol of the WrappedERC20 token
    function initialize(
        address _multiVault,
        bytes32 _termId,
        uint256 _bondingCurveId,
        string calldata name_,
        string calldata symbol_
    ) external initializer {
        if (_multiVault == address(0)) {
            revert Errors.WrappedERC20_ZeroAddress();
        }

        multiVault = IMultiVault(_multiVault);
        termId = _termId;
        bondingCurveId = _bondingCurveId;

        // Initialize the ERC20 token with name and symbol
        __ERC20_init(name_, symbol_);
    }

    /* =================================================== */
    /*                     WRAP/UNWRAP                     */
    /* =================================================== */

    /// @notice Wraps MultiVault shares into WrappedERC20 tokens
    /// @param shares The amount of shares to wrap
    /// @dev Shares are wrapped 1:1 into WrappedERC20 tokens
    function wrap(uint256 shares) external nonReentrant {
        if (shares == 0) {
            revert Errors.WrappedERC20_ZeroShares();
        }

        multiVault.wrapperTransfer(msg.sender, address(this), termId, bondingCurveId, shares);

        _mint(msg.sender, shares);

        emit Wrapped(msg.sender, address(this), termId, bondingCurveId, shares);
    }

    /// @notice Unwraps WrappedERC20 tokens back into MultiVault shares
    /// @param tokens The amount of WrappedERC20 tokens to unwrap
    /// @dev Tokens are unwrapped 1:1 back into MultiVault shares
    function unwrap(uint256 tokens) external nonReentrant {
        if (tokens == 0) {
            revert Errors.WrappedERC20_ZeroTokens();
        }

        _burn(msg.sender, tokens);

        multiVault.wrapperTransfer(address(this), msg.sender, termId, bondingCurveId, tokens);

        emit Unwrapped(msg.sender, address(this), termId, bondingCurveId, tokens);
    }
}
