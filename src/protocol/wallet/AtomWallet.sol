// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseAccount } from "@account-abstraction/core/BaseAccount.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";

// For SIG_VALIDATION_FAILED
import "@account-abstraction/core/Helpers.sol";

/**
 * @title  AtomWallet
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is an abstract account
 *         associated with a corresponding atom.
 */
contract AtomWallet is Initializable, BaseAccount, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using ECDSA for bytes32;

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error AtomWallet_OnlyOwnerOrEntryPoint();
    error AtomWallet_ZeroAddress();
    error AtomWallet_WrongArrayLengths();
    error AtomWallet_OnlyOwner();
    error AtomWallet_InvalidSignature();
    error AtomWallet_InvalidSignatureLength(uint256 length);
    error AtomWallet_InvalidSignatureS(bytes32 s);

    /* =================================================== */
    /*                  CONSTANTS                          */
    /* =================================================== */

    /**
     * @notice The storage slot for the AtomWallet owner
     * @dev Corresponds to the keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) &
     * ~bytes32(uint256(0xff))
     */
    bytes32 private constant AtomWalletOwnerStorageLocation =
        0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    /**
     * @notice The storage slot for the AtomWallet pending owner
     * @dev Corresponds to the keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable2Step")) - 1)) &
     * ~bytes32(uint256(0xff))
     */
    bytes32 private constant AtomWalletPendingOwnerStorageLocation =
        0x237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00;

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice The MultiVault contract address
    IMultiVault public multiVault;

    /// @notice The entry point contract address
    IEntryPoint private _entryPoint;

    /// @notice The flag to indicate if the wallet's ownership has been claimed by the user
    bool public isClaimed;

    /// @notice The term ID of the atom associated with this wallet
    bytes32 public termId;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    /// @dev Modifier to allow only the owner or entry point to call a function
    modifier onlyOwnerOrEntryPoint() {
        if (!(msg.sender == address(entryPoint()) || msg.sender == owner())) {
            revert AtomWallet_OnlyOwnerOrEntryPoint();
        }
        _;
    }

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

    /**
     * @notice Initialize the AtomWallet contract
     * @param anEntryPoint the EntryPoint contract address
     * @param _multiVault the MultiVault contract address
     * @param _termId the term ID of the atom associated with this wallet
     */
    function initialize(address anEntryPoint, address _multiVault, bytes32 _termId) external initializer {
        if (anEntryPoint == address(0)) {
            revert AtomWallet_ZeroAddress();
        }

        if (_multiVault == address(0)) {
            revert AtomWallet_ZeroAddress();
        }

        __Ownable_init(IMultiVault(_multiVault).getAtomWarden());
        __ReentrancyGuard_init();

        _entryPoint = IEntryPoint(anEntryPoint);
        multiVault = IMultiVault(_multiVault);
        termId = _termId;
    }

    /* =================================================== */
    /*                     RECEIVE                         */
    /* =================================================== */

    /// @notice Receive function to accept native TRUST transfers
    receive() external payable { }

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice Execute a transaction (called directly from owner, or by entryPoint)
     * @param dest the target address
     * @param value the value to send
     * @param data the function calldata
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata data
    )
        external
        override
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        _call(dest, value, data);
    }

    /**
     * @notice Execute a sequence (batch) of transactions
     * @param dest the target addresses array
     * @param values the values to send array
     * @param data the function calldata array
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata values,
        bytes[] calldata data
    )
        external
        payable
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        uint256 length = dest.length;

        if (length != values.length || values.length != data.length) {
            revert AtomWallet_WrongArrayLengths();
        }

        for (uint256 i = 0; i < length;) {
            _call(dest[i], values[i], data[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Add deposit to the account in the entry point contract
    function addDeposit() external payable {
        entryPoint().depositTo{ value: msg.value }(address(this));
    }

    /**
     * @notice Withdraws value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) external {
        if (!(msg.sender == owner() || msg.sender == address(this))) {
            revert AtomWallet_OnlyOwner();
        }
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
     * @notice Initiates the ownership transfer over the wallet to a new owner
     * @dev Overrides the transferOwnership function of Ownable2StepUpgradeable
     * @param newOwner the new owner of the wallet (becomes the pending owner)
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        Ownable2StepStorage storage $ = _getAtomWalletPendingOwnerStorage();
        $._pendingOwner = newOwner;

        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @notice The new owner accepts the ownership over the wallet. If the wallet's ownership
     *         is being accepted by the user, the wallet is considered claimed. Once claimed,
     *         the wallet is considered owned by the user and this action cannot be undone.
     * @dev Overrides the acceptOwnership function of Ownable2StepUpgradeable
     */
    function acceptOwnership() public override {
        address sender = msg.sender;

        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }

        if (!isClaimed) {
            isClaimed = true;
        }

        super._transferOwnership(sender);
    }

    /**
     * @notice Claims the accumulated fees from the MultiVault contract to the AtomWallet owner
     * @dev Can only be called by the owner
     */
    function claimAtomWalletDepositFees() external onlyOwner nonReentrant {
        multiVault.claimAtomWalletDepositFees(termId);
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /// @notice Returns the deposit of the account in the entry point contract
    function getDeposit() external view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * @notice Get the entry point contract address
     * @dev Overrides the entryPoint function of BaseAccount
     * @return the entry point contract address
     */
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @notice Returns the owner of the wallet. If the wallet has been claimed, the owner
     *         is the user. Otherwise, the owner is the atomWarden.
     * @dev Overrides the owner function of OwnableUpgradeable
     * @return the owner of the wallet
     */
    function owner() public view override returns (address) {
        OwnableStorage storage $ = _getAtomWalletOwnerStorage();
        return isClaimed ? $._owner : multiVault.getAtomWarden();
    }

    /* =================================================== */
    /*                    INTERNAL FUNCTIONS               */
    /* =================================================== */

    /**
     * @notice Validate the signature of the user operation
     * @dev Implements the template method of BaseAccount
     * @param userOp the user operation
     * @param userOpHash the hash of the user operation
     * @return validationData the validation data (0 if successful)
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        (uint48 validUntil, uint48 validAfter, bytes memory signature) =
            _extractValidUntilAndValidAfterFromSignature(userOp.signature);

        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));

        (address recovered, ECDSA.RecoverError recoverError, bytes32 errorArg) = ECDSA.tryRecover(hash, signature);

        if (recoverError == ECDSA.RecoverError.InvalidSignatureLength) {
            revert AtomWallet_InvalidSignatureLength(uint256(errorArg));
        } else if (recoverError == ECDSA.RecoverError.InvalidSignatureS) {
            revert AtomWallet_InvalidSignatureS(errorArg);
        } else if (recoverError == ECDSA.RecoverError.InvalidSignature) {
            return _packValidationData(true, validUntil, validAfter);
        }

        bool sigFailed = recovered != owner();
        return _packValidationData(sigFailed, validUntil, validAfter);
    }

    /**
     * @notice An internal method that calls a target address with value and data
     * @param target the target address
     * @param value the value to send
     * @param data the function calldata
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{ value: value }(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @notice Extracts validUntil and validAfter from a signature suffix and returns the raw signature
     * @dev Signature format: abi.encodePacked(r, s, v) or abi.encodePacked(r, s, v, uint48 validUntil, uint48
     *      validAfter)
     * @param signature the full signature bytes
     * @return validUntil the valid until timestamp (0 means no expiry)
     * @return validAfter the valid after timestamp
     * @return rawSignature the 65-byte ECDSA signature (r,s,v)
     */
    function _extractValidUntilAndValidAfterFromSignature(bytes calldata signature)
        internal
        pure
        returns (uint48 validUntil, uint48 validAfter, bytes memory rawSignature)
    {
        uint256 signatureLength = signature.length;
        if (signatureLength == 65) {
            return (0, 0, signature);
        }
        if (signatureLength != 77) {
            revert AtomWallet_InvalidSignatureLength(signatureLength);
        }

        uint256 metaOffset = signatureLength - 12;
        rawSignature = signature[:metaOffset];

        bytes memory meta = signature[metaOffset:];
        uint256 word;
        assembly {
            word := mload(add(meta, 32))
        }
        uint96 packed = uint96(word >> 160);
        validUntil = uint48(packed >> 48);
        validAfter = uint48(packed);
    }

    /**
     * @dev Get the storage slot for the AtomWallet contract owner
     * @return $ the storage slot
     */
    function _getAtomWalletOwnerStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := AtomWalletOwnerStorageLocation
        }
    }

    /**
     * @dev Get the storage slot for the AtomWallet contract pending owner
     * @return $ the storage slot
     */
    function _getAtomWalletPendingOwnerStorage() private pure returns (Ownable2StepStorage storage $) {
        assembly {
            $.slot := AtomWalletPendingOwnerStorageLocation
        }
    }
}
