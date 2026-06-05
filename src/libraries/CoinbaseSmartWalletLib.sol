// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { WebAuthn } from "solady/utils/WebAuthn.sol";

/// @title CoinbaseSmartWalletLib
/// @author 0xIntuition
/// @notice Stateless library extracted from Coinbase Smart Wallet (MultiOwnable + signature validation).
///         Provides multi-owner management (ERC-7201 storage at 0x97e2…) and multi-type signature
///         validation (ECDSA + WebAuthn/passkey dispatch via Solady).
/// @dev    All functions are `internal` and get inlined into the calling contract at compile time.
///         Storage is accessed via ERC-7201 namespace at MULTI_OWNABLE_STORAGE_LOCATION.
///         The calling contract owns the storage; this library only provides logic.
///         Access control is NOT enforced here — the calling contract must apply its own modifiers.
///
///         Upstream source: github.com/coinbase/smart-wallet/blob/main/src/CoinbaseSmartWallet.sol
library CoinbaseSmartWalletLib {
    /* =================================================== */
    /*                     STRUCTS                         */
    /* =================================================== */

    /// @dev ERC-7201 namespaced storage for multi-owner management.
    ///      Verbatim from upstream Coinbase MultiOwnable.sol.
    struct MultiOwnableStorage {
        uint256 nextOwnerIndex;
        uint256 removedOwnersCount;
        mapping(uint256 index => bytes owner) ownerAtIndex;
        mapping(bytes bytes_ => bool isOwner_) isOwner;
    }

    /// @dev Signature wrapper for dispatching between ECDSA and WebAuthn.
    ///      Verbatim from upstream Coinbase CoinbaseSmartWallet.sol.
    struct SignatureWrapper {
        uint256 ownerIndex;
        bytes signatureData;
    }

    /* =================================================== */
    /*                    CONSTANTS                        */
    /* =================================================== */

    /// @dev ERC-7201 storage slot for MultiOwnableStorage.
    ///      Same slot value as upstream Coinbase (upstream constant name has a typo: "MUTLI").
    bytes32 internal constant MULTI_OWNABLE_STORAGE_LOCATION =
        0x97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f00;

    /// @dev EIP-712 typehash for replay-safe hashing.
    ///      Verbatim from upstream Coinbase ERC1271.sol.
    bytes32 internal constant MESSAGE_TYPEHASH = keccak256("CoinbaseSmartWalletMessage(bytes32 hash)");

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    /// @dev Owner bytes are already registered.
    error AlreadyOwner(bytes owner);

    /// @dev No owner is registered at the given index.
    error NoOwnerAtIndex(uint256 index);

    /// @dev Owner at the given index does not match the expected value.
    error WrongOwnerAtIndex(uint256 index, bytes expectedOwner, bytes actualOwner);

    /// @dev Owner bytes length is not 32 (address) or 64 (public key).
    error InvalidOwnerBytesLength(bytes owner);

    /// @dev Encoded address exceeds uint160 range.
    error InvalidEthereumAddressOwner(bytes owner);

    /// @dev Cannot remove the last remaining owner via removeOwnerAtIndex.
    error LastOwner();

    /// @dev Expected exactly one owner remaining but found more.
    error NotLastOwner(uint256 ownersRemaining);

    /// @dev Address not found in the owner registry (removeOwnerByAddress).
    error OwnerNotFound(address owner);

    /* =================================================== */
    /*                      EVENTS                         */
    /* =================================================== */

    /// @dev Emitted when an owner is added at the given index.
    event AddOwner(uint256 indexed index, bytes owner);

    /// @dev Emitted when an owner is removed from the given index.
    event RemoveOwner(uint256 indexed index, bytes owner);

    /* =================================================== */
    /*              SIGNATURE VALIDATION                   */
    /* =================================================== */

    /// @notice Non-reverting signature validation that dispatches between ECDSA and WebAuthn
    ///         based on the owner type at the specified index.
    /// @dev    Adapted from upstream CoinbaseSmartWallet._isValidSignature.
    ///         Upstream revert paths are replaced with `return false` to satisfy the ERC-4337
    ///         non-revert contract (SIG_VALIDATION_FAILED instead of revert).
    /// @param hash The digest to validate the signature against.
    /// @param signature ABI-encoded SignatureWrapper (ownerIndex, signatureData).
    /// @return True if the signature is valid for the owner at the specified index.
    function isValidSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        // ── Safe decode of SignatureWrapper ──
        // Minimum ABI-encoded (uint256, bytes): 32 (ownerIndex) + 32 (offset) + 32 (length) = 96
        if (signature.length < 96) return false;

        // Validate ABI structure: offset field must point to 0x40 (64)
        uint256 offset;
        assembly ("memory-safe") {
            offset := mload(add(signature, 0x40))
        }
        if (offset != 64) return false;

        // Read signatureData length and verify total length (overflow-safe)
        uint256 dataLen;
        assembly ("memory-safe") {
            dataLen := mload(add(signature, 0x60))
        }
        if (dataLen > signature.length) return false;
        uint256 paddedDataLen = (dataLen + 31) & ~uint256(31);
        if (signature.length < 96 + paddedDataLen) return false;

        // Now safe to decode
        SignatureWrapper memory sigWrapper = abi.decode(signature, (SignatureWrapper));

        // ── Check owner exists at index (non-reverting) ──
        MultiOwnableStorage storage $ = _getStorage();
        bytes memory ownerBytes = $.ownerAtIndex[sigWrapper.ownerIndex];
        if (ownerBytes.length == 0) return false;

        // ── Dispatch based on owner type ──
        if (ownerBytes.length == 32) {
            // EOA owner (address encoded as bytes32)
            if (uint256(bytes32(ownerBytes)) > type(uint160).max) return false;

            address ownerAddr;
            assembly ("memory-safe") {
                ownerAddr := mload(add(ownerBytes, 32))
            }

            return SignatureCheckerLib.isValidSignatureNow(ownerAddr, hash, sigWrapper.signatureData);
        }

        if (ownerBytes.length == 64) {
            // Passkey owner (P-256 public key)
            (bytes32 x, bytes32 y) = abi.decode(ownerBytes, (bytes32, bytes32));

            // Non-reverting decode via Solady's tryDecodeAuth
            WebAuthn.WebAuthnAuth memory auth = WebAuthn.tryDecodeAuth(sigWrapper.signatureData);

            return
                WebAuthn.verify({ challenge: abi.encode(hash), requireUserVerification: false, auth: auth, x: x, y: y });
        }

        return false; // Unknown owner bytes length
    }

    /* =================================================== */
    /*                OWNER MANAGEMENT                     */
    /* =================================================== */

    /// @notice Initializes the owner registry with a set of owners.
    /// @dev    Verbatim logic from upstream MultiOwnable._initializeOwners.
    ///         No access control — the calling contract must gate this appropriately.
    /// @param owners Array of owner bytes (32 bytes for addresses, 64 bytes for public keys).
    function initializeOwners(bytes[] memory owners) internal {
        MultiOwnableStorage storage $ = _getStorage();
        uint256 nextOwnerIndex_ = $.nextOwnerIndex;

        for (uint256 i; i < owners.length; i++) {
            if (owners[i].length != 32 && owners[i].length != 64) {
                revert InvalidOwnerBytesLength(owners[i]);
            }

            if (owners[i].length == 32 && uint256(bytes32(owners[i])) > type(uint160).max) {
                revert InvalidEthereumAddressOwner(owners[i]);
            }

            _addOwnerAtIndex(owners[i], nextOwnerIndex_++);
        }

        $.nextOwnerIndex = nextOwnerIndex_;
    }

    /// @notice Adds an address as an owner.
    /// @param owner The address to add.
    function addOwnerAddress(address owner) internal {
        _addOwner(abi.encode(owner));
    }

    /// @notice Adds a P-256 public key as an owner.
    /// @param x The x coordinate of the public key.
    /// @param y The y coordinate of the public key.
    function addOwnerPublicKey(bytes32 x, bytes32 y) internal {
        _addOwner(abi.encode(x, y));
    }

    /// @notice Removes the owner at the given index.
    /// @dev    Verbatim logic from upstream MultiOwnable.removeOwnerAtIndex (minus onlyOwner).
    ///         Reverts if this would remove the last owner.
    /// @param index The index of the owner to remove.
    /// @param owner The expected owner bytes at that index (safety check).
    function removeOwnerAtIndex(uint256 index, bytes calldata owner) internal {
        if (ownerCount() == 1) {
            revert LastOwner();
        }

        _removeAtIndex(index, owner);
    }

    /// @notice Removes the last remaining owner at the given index.
    /// @dev    Verbatim logic from upstream MultiOwnable.removeLastOwner (minus onlyOwner).
    ///         Reverts if more than one owner remains.
    /// @param index The index of the owner to remove.
    /// @param owner The expected owner bytes at that index (safety check).
    function removeLastOwner(uint256 index, bytes calldata owner) internal {
        uint256 ownersRemaining = ownerCount();
        if (ownersRemaining > 1) {
            revert NotLastOwner(ownersRemaining);
        }

        _removeAtIndex(index, owner);
    }

    /// @notice Removes an owner by address via linear scan.
    /// @dev    NOT in upstream Coinbase — this is an intentional divergence.
    ///         O(n) over nextOwnerIndex. Acceptable given expected signer counts (single digits).
    ///         Reverts with OwnerNotFound if the address is not in the registry.
    /// @param owner The address to remove.
    function removeOwnerByAddress(address owner) internal {
        MultiOwnableStorage storage $ = _getStorage();
        bytes memory ownerBytes = abi.encode(owner);
        uint256 length = $.nextOwnerIndex;

        for (uint256 i; i < length; i++) {
            bytes memory stored = $.ownerAtIndex[i];
            if (stored.length > 0 && keccak256(stored) == keccak256(ownerBytes)) {
                // Use the shared removal helper (bytes memory variant)
                _removeAtIndexMemory(i, ownerBytes);
                return;
            }
        }

        revert OwnerNotFound(owner);
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /// @notice Returns whether the given address is a registered owner.
    function isOwnerAddress(address account) internal view returns (bool) {
        return _getStorage().isOwner[abi.encode(account)];
    }

    /// @notice Returns whether the given P-256 public key is a registered owner.
    function isOwnerPublicKey(bytes32 x, bytes32 y) internal view returns (bool) {
        return _getStorage().isOwner[abi.encode(x, y)];
    }

    /// @notice Returns whether the given bytes are a registered owner.
    function isOwnerBytes(bytes memory account) internal view returns (bool) {
        return _getStorage().isOwner[account];
    }

    /// @notice Returns the owner bytes at the given index (empty if no owner).
    function ownerAtIndex(uint256 index) internal view returns (bytes memory) {
        return _getStorage().ownerAtIndex[index];
    }

    /// @notice Returns the current owner count (nextOwnerIndex - removedOwnersCount).
    function ownerCount() internal view returns (uint256) {
        MultiOwnableStorage storage $ = _getStorage();
        return $.nextOwnerIndex - $.removedOwnersCount;
    }

    /// @notice Returns the next owner index (monotonically increasing).
    function nextOwnerIndex() internal view returns (uint256) {
        return _getStorage().nextOwnerIndex;
    }

    /// @notice Returns the number of removed owners.
    function removedOwnersCount() internal view returns (uint256) {
        return _getStorage().removedOwnersCount;
    }

    /* =================================================== */
    /*                ERC-1271 HASHING                     */
    /* =================================================== */

    /// @notice Produces a replay-safe hash by wrapping in EIP-712 typed data.
    /// @dev    Adapted from upstream Coinbase ERC1271.replaySafeHash.
    ///         Domain name/version are parameterized (not hardcoded "Coinbase Smart Wallet").
    /// @param hash The raw hash to wrap.
    /// @param name The EIP-712 domain name.
    /// @param version The EIP-712 domain version.
    /// @return The replay-safe EIP-712 hash.
    function replaySafeHash(bytes32 hash, string memory name, string memory version) internal view returns (bytes32) {
        return _eip712Hash(hash, name, version);
    }

    /// @notice Returns the EIP-712 domain separator.
    /// @param name The EIP-712 domain name.
    /// @param version The EIP-712 domain version.
    /// @return The domain separator hash.
    function domainSeparator(string memory name, string memory version) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    /* =================================================== */
    /*                 PRIVATE HELPERS                     */
    /* =================================================== */

    /// @dev Returns the ERC-7201 namespaced storage pointer.
    ///      Verbatim from upstream MultiOwnable._getMultiOwnableStorage.
    function _getStorage() private pure returns (MultiOwnableStorage storage $) {
        assembly ("memory-safe") {
            $.slot := MULTI_OWNABLE_STORAGE_LOCATION
        }
    }

    /// @dev Adds owner bytes at the next available index.
    ///      Verbatim logic from upstream MultiOwnable.addOwnerAddress/addOwnerPublicKey.
    function _addOwner(bytes memory owner) private {
        _addOwnerAtIndex(owner, _getStorage().nextOwnerIndex++);
    }

    /// @dev Adds owner bytes at a specific index. Reverts if already registered.
    ///      Verbatim from upstream MultiOwnable._addOwnerAtIndex.
    function _addOwnerAtIndex(bytes memory owner, uint256 index) private {
        if (isOwnerBytes(owner)) revert AlreadyOwner(owner);

        MultiOwnableStorage storage $ = _getStorage();
        $.isOwner[owner] = true;
        $.ownerAtIndex[index] = owner;

        emit AddOwner(index, owner);
    }

    /// @dev Shared removal logic for calldata owner bytes.
    ///      Called by removeOwnerAtIndex and removeLastOwner.
    ///      Verbatim from upstream MultiOwnable._removeOwnerAtIndex.
    function _removeAtIndex(uint256 index, bytes calldata owner) private {
        MultiOwnableStorage storage $ = _getStorage();
        bytes memory owner_ = $.ownerAtIndex[index];

        if (owner_.length == 0) revert NoOwnerAtIndex(index);
        if (keccak256(owner_) != keccak256(owner)) {
            revert WrongOwnerAtIndex({ index: index, expectedOwner: owner, actualOwner: owner_ });
        }

        delete $.isOwner[owner];
        delete $.ownerAtIndex[index];
        $.removedOwnersCount++;

        emit RemoveOwner(index, owner);
    }

    /// @dev Shared removal logic for memory owner bytes.
    ///      Called by removeOwnerByAddress. Same logic as _removeAtIndex but accepts bytes memory.
    ///      NOT in upstream Coinbase — this is an intentional divergence.
    function _removeAtIndexMemory(uint256 index, bytes memory owner) private {
        MultiOwnableStorage storage $ = _getStorage();
        bytes memory owner_ = $.ownerAtIndex[index];

        if (owner_.length == 0) revert NoOwnerAtIndex(index);
        if (keccak256(owner_) != keccak256(owner)) {
            revert WrongOwnerAtIndex({ index: index, expectedOwner: owner, actualOwner: owner_ });
        }

        delete $.isOwner[owner];
        delete $.ownerAtIndex[index];
        $.removedOwnersCount++;

        emit RemoveOwner(index, owner);
    }

    /// @dev Computes the EIP-712 hash struct for replay-safe hashing.
    function _hashStruct(bytes32 hash) private pure returns (bytes32) {
        return keccak256(abi.encode(MESSAGE_TYPEHASH, hash));
    }

    /// @dev Computes the full EIP-712 typed data hash.
    function _eip712Hash(bytes32 hash, string memory name, string memory version) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(name, version), _hashStruct(hash)));
    }
}
