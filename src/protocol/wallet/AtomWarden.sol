// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { IAtomWallet } from "src/interfaces/IAtomWallet.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IMultiVaultCore } from "src/interfaces/IMultiVaultCore.sol";

/**
 * @title  AtomWarden
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It acts as an initial owner of all newly
 *         created atom wallets, and it also allows users to automatically claim ownership over
 *         the atom wallets for which they've proven ownership over.
 */
contract AtomWarden is IAtomWarden, Initializable, Ownable2StepUpgradeable {
    /* =================================================== */
    /*                      STATE                          */
    /* =================================================== */

    /// @notice The reference to the MultiVault contract addressC
    address public multiVault;

    /* =================================================== */
    /*                      CONSTRUCTOR                    */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                      INITIALIZER                    */
    /* =================================================== */

    /**
     * @notice Initializes the AtomWarden contract
     * @param admin The address of the admin
     * @param _multiVault MultiVault contract address
     */
    function initialize(address admin, address _multiVault) external initializer {
        __Ownable_init(admin);
        _setMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                   USER FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc IAtomWarden
    function claimOwnershipOverAddressAtom(bytes32 atomId) external {
        // validate atomId refers to an existing atom
        if (!IMultiVaultCore(multiVault).isAtom(atomId)) {
            revert AtomWarden_AtomIdDoesNotExist();
        }

        // stored atom data must equal lowercase string address
        bytes memory storedAtomData = IMultiVaultCore(multiVault).atom(atomId);
        bytes memory expectedAtomData = abi.encodePacked(_toLowerCaseAddress(msg.sender));

        if (keccak256(storedAtomData) != keccak256(expectedAtomData)) {
            revert AtomWarden_ClaimOwnershipFailed();
        }

        address payable atomWalletAddress = payable(IMultiVault(multiVault).computeAtomWalletAddr(atomId));

        if (atomWalletAddress.code.length == 0) {
            revert AtomWarden_AtomWalletNotDeployed();
        }
        IAtomWallet(atomWalletAddress).transferOwnership(msg.sender);

        emit AtomWalletOwnershipClaimed(atomId, msg.sender);
    }

    /* =================================================== */
    /*                      ADMIN FUNCTIONS                */
    /* =================================================== */

    /// @inheritdoc IAtomWarden
    function claimOwnership(bytes32 atomId, address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert AtomWarden_InvalidNewOwnerAddress();
        }

        // validate the vault exists and is an atom
        if (!IMultiVaultCore(multiVault).isAtom(atomId)) {
            revert AtomWarden_AtomIdDoesNotExist();
        }

        address payable atomWalletAddress = payable(IMultiVault(multiVault).computeAtomWalletAddr(atomId));

        if (atomWalletAddress.code.length == 0) {
            revert AtomWarden_AtomWalletNotDeployed();
        }
        IAtomWallet(atomWalletAddress).transferOwnership(newOwner);

        emit AtomWalletOwnershipClaimed(atomId, newOwner);
    }

    /// @inheritdoc IAtomWarden
    function setMultiVault(address _multiVault) external onlyOwner {
        _setMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                   INTERNAL FUNCTIONS                */
    /* =================================================== */

    /**
     * @notice Converts an address to its lowercase hexadecimal string representation.
     * @param _address The address to be converted.
     * @return The lowercase hexadecimal string of the address.
     */
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

    function _setMultiVault(address _multiVault) internal {
        if (address(_multiVault) == address(0)) {
            revert AtomWarden_InvalidAddress();
        }

        multiVault = _multiVault;

        emit MultiVaultSet(_multiVault);
    }
}
