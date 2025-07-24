// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IAtomWallet} from "src/interfaces/IAtomWallet.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";

/**
 * @title  AtomWarden
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It acts as an initial owner of all newly
 *         created atom wallets, and it also allows users to automatically claim ownership over
 *         the atom wallets for which they've proven ownership over.
 */
contract AtomWarden is Initializable, Ownable2StepUpgradeable {
    /// @notice The reference to the MultiVault contract addressC
    IMultiVault public multiVault;

    /// @notice Event emitted when the MultiVault contract address is set
    /// @param multiVault MultiVault contract address
    event MultiVaultSet(address multiVault);

    /// @notice Event emitted when ownership transfer over an atom wallet has been initiated
    event AtomWalletOwnershipClaimed(bytes32 atomId, address pendingOwner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the AtomWarden contract
    ///
    /// @param admin The address of the admin
    /// @param _multiVault MultiVault contract address
    function initialize(address admin, address _multiVault) external initializer {
        __Ownable_init(admin);
        multiVault = IMultiVault(_multiVault);
    }

    /// @notice Sets the MultiVault contract address
    /// @param _multiVault MultiVault contract address
    function setMultiVault(address _multiVault) external onlyOwner {
        if (address(_multiVault) == address(0)) {
            revert Errors.AtomWarden_InvalidMultiVaultAddress();
        }

        multiVault = IMultiVault(_multiVault);

        emit MultiVaultSet(_multiVault);
    }

    /// @notice Allows the caller to claim ownership over an atom wallet address in case
    ///         atomUri is equal to the caller's address
    /// @param atomId The atom ID
    function claimOwnershipOverAddressAtom(bytes32 atomId) external {
        // validate atomId refers to an existing atom
        if (atomId == bytes32(0) || !multiVault.isTermIdValid(atomId) || multiVault.isTripleId(atomId)) {
            revert Errors.AtomWarden_AtomIdDoesNotExist();
        }

        // stored atom data must equal lowercase string address
        bytes memory storedAtomData = multiVault.atomData(atomId);
        bytes memory expectedAtomData = abi.encodePacked(_toLowerCaseAddress(msg.sender));

        if (keccak256(storedAtomData) != keccak256(expectedAtomData)) {
            revert Errors.AtomWarden_ClaimOwnershipFailed();
        }

        address payable atomWalletAddress = payable(multiVault.computeAtomWalletAddr(atomId));

        if (atomWalletAddress.code.length == 0) {
            revert Errors.AtomWarden_AtomWalletNotDeployed();
        }
        IAtomWallet(atomWalletAddress).transferOwnership(msg.sender);

        emit AtomWalletOwnershipClaimed(atomId, msg.sender);
    }

    /// @notice Allows the owner to assign ownership of an atom wallet to a new owner in
    ///         cases where the automated ownership recovery is not possible yet
    /// @param atomId The atom ID
    /// @param newOwner The new owner address
    function claimOwnership(bytes32 atomId, address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert Errors.AtomWarden_InvalidNewOwner();
        }

        // validate atomId refers to an existing atom (not triple)
        if (atomId == bytes32(0) || !multiVault.isTermIdValid(atomId) || multiVault.isTripleId(atomId)) {
            revert Errors.AtomWarden_AtomIdDoesNotExist();
        }

        address payable atomWalletAddress = payable(multiVault.computeAtomWalletAddr(atomId));

        if (atomWalletAddress.code.length == 0) {
            revert Errors.AtomWarden_AtomWalletNotDeployed();
        }
        IAtomWallet(atomWalletAddress).transferOwnership(newOwner);

        emit AtomWalletOwnershipClaimed(atomId, newOwner);
    }

    /// @notice Converts an address to its lowercase hexadecimal string representation.
    /// @param _address The address to be converted.
    /// @return The lowercase hexadecimal string of the address.
    function _toLowerCaseAddress(address _address) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef"; // Lowercase hexadecimal characters
        bytes20 addrBytes = bytes20(_address);
        bytes memory str = new bytes(42);

        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(addrBytes[i] >> 4)]; // Upper 4 bits (first hex character)
            str[3 + i * 2] = alphabet[uint8(addrBytes[i] & 0x0f)]; // Lower 4 bits (second hex character)
        }

        return string(str);
    }
}
