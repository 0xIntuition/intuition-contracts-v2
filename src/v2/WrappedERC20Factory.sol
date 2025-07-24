// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {WrappedERC20} from "src/v2/WrappedERC20.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {IWrappedERC20Factory} from "src/interfaces/IWrappedERC20Factory.sol";

/**
 * @title  WrappedERC20Factory
 * @author 0xIntuition
 * @notice Factory contract for deploying WrappedERC20 token contracts using the BeaconProxy pattern.
 */
contract WrappedERC20Factory is IWrappedERC20Factory, Initializable {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice The MultiVault contract
    IMultiVault public multiVault;

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

    /// @notice Initializes the WrappedERC20Factory contract
    /// @param _multiVault The address of the MultiVault contract
    function initialize(address _multiVault) external initializer {
        if (_multiVault == address(0)) {
            revert Errors.WrappedERC20Factory_ZeroAddress();
        }

        multiVault = IMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                    WRITE FUNCTIONS                  */
    /* =================================================== */

    /// @notice Deploys a wrapped token for a given term ID and bonding curve ID pair
    /// @dev Deploys a WrappedERC20 token through a BeaconProxy or returns the existing one if already deployed
    ///
    /// @param termId The term ID for which this wrapper is created
    /// @param bondingCurveId The bonding curve ID for which this wrapper is created
    /// @param name The name of the WrappedERC20 token
    /// @param symbol The symbol of the WrappedERC20 token
    ///
    /// @return wrappedERC20 The address of the deployed WrappedERC20 token
    function deployWrapper(bytes32 termId, uint256 bondingCurveId, string calldata name, string calldata symbol)
        external
        returns (address)
    {
        (address admin,,,,,,,,,,) = multiVault.generalConfig();

        if (msg.sender != admin) {
            revert Errors.WrappedERC20Factory_OnlyAdmin();
        }

        if (!multiVault.isTermIdValid(termId)) {
            revert Errors.MultiVault_TermDoesNotExist();
        }

        if (!multiVault.isBondingCurveIdValid(bondingCurveId)) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        // compute salt for create2
        bytes32 salt = keccak256(abi.encodePacked(termId, bondingCurveId));

        // pre-compute wrapper address & bytecode
        bytes memory data = _getDeploymentData(termId, bondingCurveId, name, symbol);

        address predictedWrappedERC20Address = computeWrappedERC20Address(termId, bondingCurveId, name, symbol);

        uint256 codeLengthBefore = predictedWrappedERC20Address.code.length;

        // if wrapped ERC20 is already deployed, return its address
        if (codeLengthBefore != 0) {
            return predictedWrappedERC20Address;
        }

        address deployedWrappedERC20Address;

        // deploy WrappedERC20 with create2:
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where the length is),
        // length of `code` (first 32 bytes of code),
        // salt for create2
        assembly {
            deployedWrappedERC20Address := create2(0, add(data, 0x20), mload(data), salt)
        }

        if (deployedWrappedERC20Address == address(0)) {
            revert Errors.WrappedERC20Factory_DeployWrappedERC20Failed();
        }

        emit WrappedERC20Deployed(termId, bondingCurveId, deployedWrappedERC20Address);

        // register the wrapped token in the MultiVault upon deployment
        multiVault.registerWrappedERC20(termId, bondingCurveId, deployedWrappedERC20Address);

        return deployedWrappedERC20Address;
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /// @notice Returns the WrappedERC20 address for the given term ID and bonding curve ID
    /// @dev The create2 salt is based off of the term ID, bonding curve ID, name and symbol
    ///
    /// @param termId The term ID for which this wrapper is created
    /// @param bondingCurveId The bonding curve ID for which this wrapper is created
    /// @param name The name of the WrappedERC20 token
    /// @param symbol The symbol of the WrappedERC20 token
    ///
    /// @return wrappedERC20 the address of the WrappedERC20 token
    function computeWrappedERC20Address(
        bytes32 termId,
        uint256 bondingCurveId,
        string calldata name,
        string calldata symbol
    ) public view returns (address) {
        // compute salt for create2
        bytes32 salt = keccak256(abi.encodePacked(termId, bondingCurveId));

        // get contract deployment data
        bytes memory data = _getDeploymentData(termId, bondingCurveId, name, symbol);

        // compute the raw contract address
        bytes32 rawAddress = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(data)));

        return address(bytes20(rawAddress << 96));
    }

    /* =================================================== */
    /*                 INTERNAL HELPERS                     */
    /* =================================================== */

    /// @dev Returns the deployment data for the new WrappedERC20 contract
    ///
    /// @param termId The term ID for which this wrapper is created
    /// @param bondingCurveId The bonding curve ID for which this wrapper is created
    /// @param name The name of the WrappedERC20 token
    /// @param symbol The symbol of the WrappedERC20 token
    ///
    /// @return bytes memory the deployment data for the WrappedERC20 contract (using BeaconProxy pattern)
    function _getDeploymentData(bytes32 termId, uint256 bondingCurveId, string calldata name, string calldata symbol)
        internal
        view
        returns (bytes memory)
    {
        // Address of the wrappedERC20Beacon contract
        (address wrappedERC20Beacon,) = multiVault.wrapperConfig();

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the WrappedERC20 contract with the correct initialization arguments
        bytes memory initData = abi.encodeWithSelector(
            WrappedERC20.initialize.selector, address(multiVault), termId, bondingCurveId, name, symbol
        );

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(wrappedERC20Beacon, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }
}
