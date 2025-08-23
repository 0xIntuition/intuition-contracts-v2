// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IAtomWalletFactory } from "src/interfaces/IAtomWalletFactory.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

/**
 * @title AtomWalletFactory
 * @author 0xIntuition
 * @notice Factory contract for deploying AtomWallets (ERC-4337 accounts) using the BeaconProxy pattern.
 */
contract AtomWalletFactory is IAtomWalletFactory, Initializable {
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

    /// @notice Initializes the AtomWalletFactory contract
    /// @param _multiVault The address of the MultiVault contract
    function initialize(address _multiVault) external initializer {
        if (_multiVault == address(0)) {
            revert Errors.AtomWalletFactory_ZeroAddress();
        }

        multiVault = IMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                    WRITE FUNCTIONS                  */
    /* =================================================== */

    /// @notice Deploys an AtomWallet for a given atom ID
    /// @dev Deploys an ERC-4337 account (atom wallet) through a BeaconProxy or returns the existing one if already
    /// deployed
    /// @param atomId id of atom
    /// @return atomWallet the address of the atom wallet
    function deployAtomWallet(bytes32 atomId) external returns (address) {
        if (!multiVault.isTermCreated(atomId)) {
            revert Errors.MultiVault_TermDoesNotExist();
        }

        // if (multiVault.isTripleId(atomId)) {
        //     revert Errors.MultiVault_TermNotAtom();
        // }

        // get contract deployment data
        bytes memory data = _getDeploymentData(atomId);

        address predictedAtomWalletAddress = computeAtomWalletAddr(atomId);

        uint256 codeLengthBefore = predictedAtomWalletAddress.code.length;

        // if wallet is already deployed, return its address
        if (codeLengthBefore != 0) {
            return predictedAtomWalletAddress;
        }

        address deployedAtomWalletAddress;

        // deploy atom wallet with create2:
        // value sent in wei,
        // memory offset of `code` (after first 32 bytes where the length is),
        // length of `code` (first 32 bytes of code),
        // salt for create2
        assembly {
            deployedAtomWalletAddress := create2(0, add(data, 0x20), mload(data), atomId)
        }

        if (deployedAtomWalletAddress == address(0)) {
            revert Errors.AtomWalletFactory_DeployAtomWalletFailed();
        }

        emit AtomWalletDeployed(atomId, deployedAtomWalletAddress);

        return deployedAtomWalletAddress;
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /// @notice Returns the AtomWallet address for the given atom data
    /// @dev The create2 salt is based off of the vault ID
    /// @param atomId id of the atom associated to the atom wallet
    /// @return atomWallet the address of the atom wallet
    function computeAtomWalletAddr(bytes32 atomId) public view returns (address) {
        // get contract deployment data
        bytes memory data = _getDeploymentData(atomId);

        // compute the raw contract address
        bytes32 rawAddress = keccak256(abi.encodePacked(bytes1(0xff), address(this), atomId, keccak256(data)));

        return address(bytes20(rawAddress << 96));
    }

    /* =================================================== */
    /*                    INTERNAL HELPERS                 */
    /* =================================================== */

    /// @dev Returns the deployment data for the new AtomWallet contract
    /// @param atomId the term ID of the atom wallet
    /// @return bytes memory the deployment data for the AtomWallet contract (using BeaconProxy pattern)
    function _getDeploymentData(bytes32 atomId) internal view returns (bytes memory) {
        // Addresses of the atomWalletBeacon and entryPoint contracts
        (, address entryPoint,, address atomWalletBeacon,) = multiVault.walletConfig();

        // BeaconProxy creation code
        bytes memory code = type(BeaconProxy).creationCode;

        // encode the init function of the AtomWallet contract with the correct initialization arguments
        bytes memory initData =
            abi.encodeWithSelector(AtomWallet.initialize.selector, IEntryPoint(entryPoint), address(multiVault), atomId);

        // encode constructor arguments of the BeaconProxy contract (address beacon, bytes memory data)
        bytes memory encodedArgs = abi.encode(atomWalletBeacon, initData);

        // concatenate the BeaconProxy creation code with the ABI-encoded constructor arguments
        return abi.encodePacked(code, encodedArgs);
    }
}
