// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseAccount } from "@account-abstraction/core/BaseAccount.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Receiver } from "solady/accounts/Receiver.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { CoinbaseSmartWalletLib } from "src/libraries/CoinbaseSmartWalletLib.sol";

// For SIG_VALIDATION_FAILED
import "@account-abstraction/core/Helpers.sol";

/**
 * @title  AtomWallet
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. This contract is an ERC-4337 abstract account
 *         associated with a corresponding atom. Implements ERC-1271 for contract-signature
 *         validation and standard token receiver interfaces (ERC-721, ERC-1155).
 * @dev    Ownership is rooted entirely in the Coinbase Smart Wallet MultiOwnable model via
 *         `CoinbaseSmartWalletLib`. A single `_claimant` slot records the primary owner that
 *         completed the claim — `owner()` returns either the AtomWarden (pre-claim) or
 *         `_claimant` (post-claim) so ERC-1271 integrations that expect a single principal
 *         keep working. Execution and signer-management surfaces gate on the MultiOwnable
 *         peer-owner set seeded by `completeClaim`. Signature validation is delegated to
 *         `CoinbaseSmartWalletLib`; pre-claim wallets reject all signatures because the
 *         registry is empty until `completeClaim` seeds the claimant.
 */
contract AtomWallet is Initializable, BaseAccount, ReentrancyGuardUpgradeable, IERC1271, Receiver {
    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error AtomWallet_OnlyOwnerOrEntryPoint();
    error AtomWallet_ZeroAddress();
    error AtomWallet_WrongArrayLengths();
    error AtomWallet_OnlyOwner();
    error AtomWallet_OnlyAtomWarden();
    error AtomWallet_InvalidClaimOwner();
    error AtomWallet_InvalidOwner();
    error AtomWallet_AlreadyClaimed();
    error AtomWallet_OwnerCannotBeRemoved();
    error AtomWallet_RenounceDisabled();
    error AtomWallet_NoLegacyOwnerToMigrate();

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    event ClaimCompleted(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when `transferOwnership` rotates the primary owner post-claim.
    ///         Mirrors the historical OZ `OwnershipTransferred` signal removed when the
    ///         contract dropped `OwnableUpgradeable`; indexers tracking the canonical
    ///         primary owner key off this event.
    event PrimaryOwnerTransferred(address indexed previousClaimant, address indexed newClaimant);

    /// @notice Emitted when a claimed pre-v1.1.0 wallet's Ownable owner is migrated into
    ///         the MultiOwnable registry.
    event LegacyOwnerMigrated(address indexed legacyOwner);

    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @dev ERC-1271 magic value returned for a valid signature (`IERC1271.isValidSignature.selector`).
    bytes4 private constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

    /// @dev ERC-1271 sentinel returned for an invalid signature.
    bytes4 private constant ERC1271_INVALID_SIGNATURE = 0xffffffff;

    /// @dev EIP-712 domain fields used to bind ERC-1271 authorizations to this wallet and chain.
    string private constant ERC1271_DOMAIN_NAME = "AtomWallet";
    string private constant ERC1271_DOMAIN_VERSION = "1";

    /**
     * @dev ERC-7201 storage slot used by OwnableUpgradeable in the pre-v1.1.0 implementation.
     *      Claimed wallets upgraded through the shared beacon retain their owner here until
     *      the first post-upgrade owner action migrates it into MultiOwnable.
     */
    bytes32 private constant LEGACY_OWNABLE_STORAGE_LOCATION =
        0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

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

    /// @notice The primary owner address recorded at `completeClaim` / `transferOwnership`.
    ///         Zero until claim. Read through `owner()` rather than directly so the
    ///         pre-claim AtomWarden resolution remains the single source of truth there.
    address private _claimant;

    /// @dev Storage gap for upgrade safety. Any new storage variable added above this
    ///      line MUST decrement the gap size by an equal number of slots so the total
    ///      reserved layout footprint stays at 50 slots. Failure to do so will shift
    ///      every downstream slot when this wallet is inherited from or upgraded.
    uint256[49] private __gap;

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    /// @notice Restricts access to the ERC-4337 EntryPoint, any registered MultiOwnable
    ///         address owner, or the wallet itself (self-call from `execute`).
    /// @dev    Pre-claim, MultiOwnable is empty and only EntryPoint/self satisfy the check;
    ///         in practice pre-claim `_validateSignature` always fails so no UserOp reaches
    ///         this path. Reuses `AtomWallet_OnlyOwnerOrEntryPoint` for ABI stability.
    modifier onlyMultiOwnableOwnerOrEntryPoint() {
        _checkMultiOwnableOwnerOrEntryPoint();
        _migrateLegacyOwnerIfNeeded();
        _;
    }

    /// @notice Restricts access to the AtomWarden contract (resolved via MultiVault)
    modifier onlyAtomWarden() {
        _checkAtomWarden();
        _;
    }

    /// @notice Restricts access to any registered MultiOwnable address owner or the wallet
    ///         itself (self-call from `execute`). Used for signer-management surfaces.
    /// @dev    Pre-claim, MultiOwnable is empty and no external caller passes the check, so
    ///         signer management is effectively dormant until `completeClaim` seeds the
    ///         registry. Reuses `AtomWallet_OnlyOwner` for ABI stability.
    modifier onlyMultiOwnableOwnerOrSelf() {
        _checkMultiOwnableOwnerOrSelf();
        _migrateLegacyOwnerIfNeeded();
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

        __ReentrancyGuard_init();

        _entryPoint = IEntryPoint(anEntryPoint);
        multiVault = IMultiVault(_multiVault);
        termId = _termId;
    }

    // NOTE: receive() and token receiver callbacks (ERC-721, ERC-1155) are provided
    // by Solady's Receiver base contract via its fallback + receiverFallback modifier.

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice Execute a transaction (called by the EntryPoint, any MultiOwnable address owner,
     *         or the wallet itself)
     * @param dest the target address
     * @param value the value to send
     * @param data the function calldata
     */
    function execute(address dest, uint256 value, bytes calldata data)
        external
        override
        onlyMultiOwnableOwnerOrEntryPoint
        nonReentrant
    {
        _call(dest, value, data);
    }

    /**
     * @notice Execute a sequence (batch) of transactions (called by the EntryPoint, any
     *         MultiOwnable address owner, or the wallet itself)
     * @param dest the target addresses array
     * @param values the values to send array
     * @param data the function calldata array
     */
    function executeBatch(address[] calldata dest, uint256[] calldata values, bytes[] calldata data)
        external
        payable
        onlyMultiOwnableOwnerOrEntryPoint
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
     * @notice Withdraws value from the account's deposit (callable by the EntryPoint,
     *         any MultiOwnable address owner, or the wallet itself)
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount)
        external
        onlyMultiOwnableOwnerOrEntryPoint
    {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
     * @notice Transfers primary ownership of a claimed wallet to a new owner.
     * @dev Callable by any registered MultiOwnable address owner or the wallet itself —
     *      the same trust model as `addOwnerAddress` / `removeOwnerAtIndex`. Rotates the
     *      primary `_claimant` slot and the MultiOwnable peer-owner registry atomically.
     *      Pre-claim is implicitly forbidden because the MultiOwnable registry is empty
     *      until `completeClaim` seeds it; no external caller can pass the modifier check.
     * @param newOwner the new primary owner of the wallet
     */
    function transferOwnership(address newOwner) external onlyMultiOwnableOwnerOrSelf {
        if (newOwner == address(0)) {
            revert AtomWallet_InvalidOwner();
        }

        address oldOwner = _claimant;
        _claimant = newOwner;

        // Sync the MultiOwnable registry with the new primary owner: remove the
        // outgoing owner, then add the incoming one. The `isOwnerAddress(newOwner)`
        // check is NOT a no-op guard — it handles the legitimate case where the
        // incoming owner was already registered as a co-signer prior to this call
        // (a common ownership-promotion pattern). Calling `addOwnerAddress` on an
        // already-registered address would revert with `AlreadyOwner`, breaking the
        // transfer; the skip preserves the existing co-signer slot and lets the
        // rotation succeed.
        CoinbaseSmartWalletLib.removeOwnerByAddress(oldOwner);
        if (!CoinbaseSmartWalletLib.isOwnerAddress(newOwner)) {
            CoinbaseSmartWalletLib.addOwnerAddress(newOwner);
        }

        emit PrimaryOwnerTransferred(oldOwner, newOwner);
    }

    /// @notice Renouncing ownership is disabled — the MultiOwnable registry cannot survive
    ///         the primary owner being zeroed out, and ERC-4337 wallets without an owner
    ///         become unrecoverable. Kept as an explicit selector so any caller migrating
    ///         from the previous OZ-Ownable surface fails loudly instead of silently.
    function renounceOwnership() external pure {
        revert AtomWallet_RenounceDisabled();
    }

    /**
     * @notice Migrates a claimed pre-v1.1.0 Ownable owner into the MultiOwnable registry.
     * @dev The migration also happens automatically on the first authorized owner action.
     *      Only the owner retained in the legacy Ownable storage slot may call this function.
     */
    function migrateLegacyOwner() external {
        address legacyOwner = _legacyOwnerPendingMigration();
        if (legacyOwner == address(0) || msg.sender != legacyOwner) {
            revert AtomWallet_NoLegacyOwnerToMigrate();
        }
        _migrateLegacyOwner(legacyOwner);
    }

    /**
     * @notice Completes a Warden-driven claim in a single step
     * @param newOwner the new owner of the wallet
     */
    function completeClaim(address newOwner) external onlyAtomWarden {
        if (newOwner == address(0)) {
            revert AtomWallet_InvalidClaimOwner();
        }
        // Defense-in-depth: handing the warden's own address as the claimant would
        // collapse the pre/post-claim distinction — `owner()` would resolve to the
        // warden post-claim and the MultiOwnable registry would carry the warden as
        // a peer. Reject it explicitly so the two phases stay cleanly separated.
        if (newOwner == multiVault.getAtomWarden()) {
            revert AtomWallet_InvalidClaimOwner();
        }
        if (isClaimed) {
            revert AtomWallet_AlreadyClaimed();
        }

        address previousOwner = owner();
        isClaimed = true;
        _claimant = newOwner;

        // Seed MultiOwnable registry so signature validation uses the Coinbase path
        CoinbaseSmartWalletLib.addOwnerAddress(newOwner);

        emit ClaimCompleted(previousOwner, newOwner);
    }

    /**
     * @notice Claims the accumulated fees from the MultiVault contract to the AtomWallet owner
     * @dev Callable by the EntryPoint, any MultiOwnable address owner, or the wallet itself.
     *      Proceeds are routed to `owner()` (the primary owner — pre-claim AtomWarden,
     *      post-claim `_claimant`) by the MultiVault. `nonReentrant` is shared with
     *      `execute`/`executeBatch`, so a nested `execute → claimAtomWalletDepositFees`
     *      self-call reverts on the guard; peer owners should invoke this function directly
     *      (EOA call, or a UserOp targeting `claimAtomWalletDepositFees()`) rather than
     *      wrapping it in `execute`.
     */
    function claimAtomWalletDepositFees() external onlyMultiOwnableOwnerOrEntryPoint nonReentrant {
        multiVault.claimAtomWalletDepositFees(termId);
    }

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice ERC-1271: validates that `signature` is a valid owner signature over `hash`
     * @dev Wraps the supplied digest in a wallet- and chain-bound EIP-712 envelope before
     *      validating it through the Coinbase MultiOwnable path. Callers must request a
     *      signature over `replaySafeHash(hash, "AtomWallet", "1")`, matching the upstream
     *      Coinbase Smart Wallet replay-safe ERC-1271 convention. Pre-claim wallets have an
     *      empty MultiOwnable registry and unconditionally return the failure magic value.
     * @param hash the digest to validate against
     * @param signature the encoded `SignatureWrapper` (owner index + signature data)
     * @return magicValue `0x1626ba7e` if valid, `0xffffffff` otherwise
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) external view override returns (bytes4) {
        bytes32 replaySafeHash =
            CoinbaseSmartWalletLib.replaySafeHash(hash, ERC1271_DOMAIN_NAME, ERC1271_DOMAIN_VERSION);
        if (CoinbaseSmartWalletLib.isValidSignature(replaySafeHash, signature)) {
            return ERC1271_MAGIC_VALUE;
        }
        return ERC1271_INVALID_SIGNATURE;
    }

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
     * @notice Returns the primary owner of the wallet. If the wallet has been claimed,
     *         the owner is the recorded `_claimant`. Otherwise the owner is the
     *         AtomWarden, resolved dynamically from the MultiVault.
     * @dev Pre-claim reads resolve through `multiVault.getAtomWarden()` and therefore
     *      reflect the *current* AtomWarden proxy address — including any address change
     *      that happens after this wallet was deployed (e.g. an admin pointing MultiVault
     *      at a redeployed AtomWarden). Post-claim, the value is the `_claimant` slot set
     *      by `completeClaim` / `transferOwnership` and is immune to AtomWarden rotation.
     *      Exposed for ERC-1271 integrations and downstream consumers that expect a single
     *      primary-owner principal alongside the MultiOwnable peer-owner set.
     * @return the primary owner of the wallet
     */
    function owner() public view returns (address) {
        if (!isClaimed) {
            return multiVault.getAtomWarden();
        }
        if (_claimant != address(0)) {
            return _claimant;
        }
        return _legacyOwnableOwner();
    }

    /* =================================================== */
    /*                SIGNER MANAGEMENT                   */
    /* =================================================== */

    /// @notice Adds an address as an authorized signer.
    /// @dev Callable by any registered MultiOwnable address owner or the wallet itself.
    ///      Contract owners are supported for direct ERC-1271 calls but will be rejected
    ///      by ERC-4337 bundlers during UserOp validation (prohibited external storage
    ///      access). Mirrors upstream Coinbase Smart Wallet behavior.
    /// @param signer The address to add as a signer
    function addOwnerAddress(address signer) external onlyMultiOwnableOwnerOrSelf {
        CoinbaseSmartWalletLib.addOwnerAddress(signer);
    }

    /// @notice Adds a passkey public key as an authorized signer.
    /// @dev Callable by any registered MultiOwnable address owner or the wallet itself.
    /// @param x The x coordinate of the P-256 public key
    /// @param y The y coordinate of the P-256 public key
    function addOwnerPublicKey(bytes32 x, bytes32 y) external onlyMultiOwnableOwnerOrSelf {
        CoinbaseSmartWalletLib.addOwnerPublicKey(x, y);
    }

    /// @notice Removes a signer at the given index.
    /// @dev Callable by any registered MultiOwnable address owner or the wallet itself.
    ///      The current primary `owner()` cannot be removed from the MultiOwnable registry
    ///      so that `transferOwnership` sync assumptions remain intact.
    /// @param index The index of the owner to remove
    /// @param ownr The expected owner bytes at that index (safety check)
    function removeOwnerAtIndex(uint256 index, bytes calldata ownr) external onlyMultiOwnableOwnerOrSelf {
        // Enforce invariant: cannot remove the primary `owner()` from MultiOwnable
        bytes memory ownerBytes = abi.encode(owner());
        if (keccak256(ownr) == keccak256(ownerBytes)) revert AtomWallet_OwnerCannotBeRemoved();
        CoinbaseSmartWalletLib.removeOwnerAtIndex(index, ownr);
    }

    /// @notice Returns whether the given address is a registered MultiOwnable owner
    function isOwnerAddress(address account) external view returns (bool) {
        return CoinbaseSmartWalletLib.isOwnerAddress(account);
    }

    /// @notice Returns whether the given P-256 public key is a registered MultiOwnable owner
    function isOwnerPublicKey(bytes32 x, bytes32 y) external view returns (bool) {
        return CoinbaseSmartWalletLib.isOwnerPublicKey(x, y);
    }

    /// @notice Returns the owner bytes at the given MultiOwnable index
    function ownerAtIndex(uint256 index) external view returns (bytes memory) {
        return CoinbaseSmartWalletLib.ownerAtIndex(index);
    }

    /// @notice Returns the current MultiOwnable owner count
    function ownerCount() external view returns (uint256) {
        return CoinbaseSmartWalletLib.ownerCount();
    }

    /// @notice Returns the next MultiOwnable owner index
    function nextOwnerIndex() external view returns (uint256) {
        return CoinbaseSmartWalletLib.nextOwnerIndex();
    }

    /* =================================================== */
    /*               INTERFACE SUPPORT                     */
    /* =================================================== */

    /// @notice ERC-165: reports supported interfaces
    /// @dev Token receiver callbacks are handled by Solady Receiver's fallback.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1271).interfaceId
            || interfaceId == bytes4(0x150b7a02) // IERC721Receiver
            || interfaceId == bytes4(0x4e2312e0); // IERC1155Receiver
    }

    /* =================================================== */
    /*                    INTERNAL FUNCTIONS               */
    /* =================================================== */

    function _checkMultiOwnableOwnerOrEntryPoint() internal view {
        if (
            msg.sender != address(entryPoint()) && msg.sender != address(this)
                && !CoinbaseSmartWalletLib.isOwnerAddress(msg.sender) && msg.sender != _legacyOwnerPendingMigration()
        ) {
            revert AtomWallet_OnlyOwnerOrEntryPoint();
        }
    }

    function _checkAtomWarden() internal view {
        if (msg.sender != multiVault.getAtomWarden()) {
            revert AtomWallet_OnlyAtomWarden();
        }
    }

    function _checkMultiOwnableOwnerOrSelf() internal view {
        if (
            msg.sender != address(this) && !CoinbaseSmartWalletLib.isOwnerAddress(msg.sender)
                && msg.sender != _legacyOwnerPendingMigration()
        ) {
            revert AtomWallet_OnlyOwner();
        }
    }

    /**
     * @notice Validate the signature of the user operation via the Coinbase MultiOwnable path.
     * @dev Implements the template method of BaseAccount. Applies the personal_sign prefix and
     *      delegates to `CoinbaseSmartWalletLib.isValidSignature`, which dispatches on the
     *      signature wrapper's owner type (ECDSA for address owners, WebAuthn for P-256 owners).
     *      Pre-claim wallets have an empty MultiOwnable registry and unconditionally return
     *      `SIG_VALIDATION_FAILED` because the library returns false on any decode or dispatch
     *      failure. Time bounds are (0, 0); bounded signatures can be reintroduced by a future
     *      upgrade if needed.
     * @param userOp the user operation
     * @param userOpHash the hash of the user operation
     * @return validationData the validation data (0 if successful)
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        address legacyOwner = _legacyOwnerPendingMigration();
        if (legacyOwner != address(0)) {
            (uint48 validUntil, uint48 validAfter, bytes memory signature, bool isMalformedSignature) =
                _extractLegacySignature(userOp.signature);
            if (isMalformedSignature) {
                return _packValidationData(true, 0, 0);
            }

            bytes32 legacySignedHash = userOpHash;
            if (userOp.signature.length == 77) {
                legacySignedHash = keccak256(abi.encodePacked(userOpHash, validUntil, validAfter));
            }
            bytes32 legacyHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", legacySignedHash));
            (address recovered, ECDSA.RecoverError recoverError,) = ECDSA.tryRecover(legacyHash, signature);
            bool isValidLegacySignature = recoverError == ECDSA.RecoverError.NoError && recovered == legacyOwner;
            return _packValidationData(!isValidLegacySignature, validUntil, validAfter);
        }

        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        bool isValid = CoinbaseSmartWalletLib.isValidSignature(signedHash, userOp.signature);
        return _packValidationData(!isValid, 0, 0);
    }

    /**
     * @dev Returns the claimed pre-v1.1.0 owner while migration is pending.
     */
    function _legacyOwnerPendingMigration() internal view returns (address) {
        if (!isClaimed || _claimant != address(0)) {
            return address(0);
        }
        return _legacyOwnableOwner();
    }

    /**
     * @dev Seeds the MultiOwnable registry from the pre-v1.1.0 Ownable storage slot.
     */
    function _migrateLegacyOwnerIfNeeded() internal {
        address legacyOwner = _legacyOwnerPendingMigration();
        if (legacyOwner != address(0)) {
            _migrateLegacyOwner(legacyOwner);
        }
    }

    function _migrateLegacyOwner(address legacyOwner) private {
        _claimant = legacyOwner;
        if (!CoinbaseSmartWalletLib.isOwnerAddress(legacyOwner)) {
            CoinbaseSmartWalletLib.addOwnerAddress(legacyOwner);
        }
        emit LegacyOwnerMigrated(legacyOwner);
    }

    /**
     * @dev Reads the OwnableUpgradeable owner retained by pre-v1.1.0 BeaconProxy wallets.
     */
    function _legacyOwnableOwner() private view returns (address legacyOwner) {
        bytes32 storageLocation = LEGACY_OWNABLE_STORAGE_LOCATION;
        assembly {
            legacyOwner := sload(storageLocation)
        }
    }

    /**
     * @dev Parses the 65-byte or 77-byte signature format accepted by the pre-v1.1.0
     *      AtomWallet implementation.
     */
    function _extractLegacySignature(bytes calldata signature)
        private
        pure
        returns (uint48 validUntil, uint48 validAfter, bytes memory rawSignature, bool isMalformedSignature)
    {
        uint256 signatureLength = signature.length;
        if (signatureLength == 65) {
            return (0, 0, signature, false);
        }
        if (signatureLength != 77) {
            return (0, 0, "", true);
        }

        uint256 metadataOffset = signatureLength - 12;
        rawSignature = signature[:metadataOffset];

        bytes memory metadata = signature[metadataOffset:];
        uint256 word;
        assembly {
            word := mload(add(metadata, 32))
        }
        uint96 packed = uint96(word >> 160);
        validUntil = uint48(packed >> 48);
        validAfter = uint48(packed);
        return (validUntil, validAfter, rawSignature, false);
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
}
