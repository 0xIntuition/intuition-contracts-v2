// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { IAtomWallet } from "src/interfaces/IAtomWallet.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IMultiVaultCore } from "src/interfaces/IMultiVaultCore.sol";

/**
 * @title  AtomWarden
 * @author 0xIntuition
 * @notice A utility contract of the Intuition protocol. It acts as an initial owner of all newly
 *         created atom wallets, and it also allows users and operators to complete confirmed
 *         ownership claims in one step.
 */
contract AtomWarden is IAtomWarden, Initializable, AccessControlUpgradeable, EIP712Upgradeable, PausableUpgradeable {
    using ECDSA for bytes32;

    /* =================================================== */
    /*                      CONSTANTS                      */
    /* =================================================== */

    /// @notice AccessControl role for routine operational actions (grants, nonce invalidation)
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice AccessControl role for backend keys that sign EIP-712 claim authorizations
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice Maximum number of grants per batch call. Calibrated for the L2 deployment
    ///         target's block gas limit; adjust if deploying to a more constrained chain.
    uint256 public constant MAX_BATCH_SIZE = 150;

    /// @notice EIP-712 typehash for ClaimAuthorization struct. Exposed publicly so off-chain
    ///         signers can verify they are hashing with the correct schema.
    bytes32 public constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );

    /* =================================================== */
    /*                      STATE                          */
    /* =================================================== */

    /// @notice The MultiVault contract address used for atom lookups and wallet resolution
    address public multiVault;

    /// @notice Per-claimant incrementing nonce for EIP-712 replay protection
    mapping(address claimant => uint256 nonce) public claimNonces;

    /// @notice Duration (seconds) after atom creation during which the creator cannot
    ///         claim via the expiry fallback path. A value of `0` disables the creator
    ///         fallback entirely — `claimAsCreatorAfterExpiry` will revert with
    ///         `AtomWarden_CreatorClaimDisabled` regardless of the other parameters.
    uint256 public claimWindow;

    /// @notice Minimum accumulated fees (wei) required for the creator expiry fallback claim
    uint256 public minFeeThreshold;

    /// @notice Minimum number of distinct SIGNER_ROLE signatures required for a quorum
    ///         claim. Defaults to 1 on initial deployment / v3 upgrade so behavior matches
    ///         the prior single-signer flow until the admin raises it.
    /// @dev Appended after `minFeeThreshold` for storage-layout compatibility with v2.
    uint256 public signatureThreshold;

    /// @notice Cached count of accounts currently holding `SIGNER_ROLE`. Maintained by the
    ///         `_grantRole` / `_revokeRole` overrides below. Used to bound
    ///         `setSignatureThreshold` so a misconfigured threshold cannot brick claims.
    /// @dev Appended after `signatureThreshold` for storage-layout compatibility with v2.
    uint256 public signerCount;

    /// @notice Maximum allowed `validAfter - block.timestamp` on a `ClaimAuthorization`,
    ///         in seconds. A value of `0` disables delayed activation entirely (`validAfter`
    ///         must equal the current block timestamp). `type(uint48).max` effectively
    ///         disables the cap. Evaluated at claim time against the *current* block
    ///         timestamp, so admin tightening immediately retires too-long auths.
    /// @dev Appended after `signerCount` for storage-layout compatibility. Packed into the
    ///      same 32-byte slot as `maxValidUntil` thanks to the `uint48` width.
    uint48 public maxValidAfter;

    /// @notice Maximum allowed `validUntil - block.timestamp` on a `ClaimAuthorization`,
    ///         in seconds. A value of `0` makes every signed claim instantly expired
    ///         (effectively a finer-grained pause for the signed-quorum path).
    ///         `type(uint48).max` effectively disables the cap.
    /// @dev Packed with `maxValidAfter` in the slot appended after `signerCount`.
    uint48 public maxValidUntil;

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
     * @notice Initializes the AtomWarden contract.
     * @param admin The address of the admin (granted DEFAULT_ADMIN_ROLE and OPERATOR_ROLE)
     * @param _multiVault MultiVault contract address
     * @param _claimWindow Claim window for the creator fallback path. A value of `0`
     *        disables the creator fallback entirely (see `claimAsCreatorAfterExpiry`).
     * @param _minFeeThreshold Minimum accumulated fees required for the creator fallback path
     * @param _signatureThreshold Initial quorum size for `claimWithAuthorization` (must be > 0).
     *        Callers must follow up with `grantRole(SIGNER_ROLE, ...)` for at least
     *        `_signatureThreshold` distinct accounts before quorum claims can succeed; the
     *        `> signerCount` check that guards the public setter does not apply at bootstrap
     *        because `signerCount` is 0 by construction here.
     * @param _maxValidAfter Max allowed `validAfter - block.timestamp` on a claim auth (seconds).
     *        See `maxValidAfter` for semantics. `0` disables delayed activation entirely.
     * @param _maxValidUntil Max allowed `validUntil - block.timestamp` on a claim auth (seconds).
     *        See `maxValidUntil` for semantics. `0` makes every signed claim instantly expired.
     */
    function initialize(
        address admin,
        address _multiVault,
        uint256 _claimWindow,
        uint256 _minFeeThreshold,
        uint256 _signatureThreshold,
        uint48 _maxValidAfter,
        uint48 _maxValidUntil
    )
        external
        initializer
    {
        if (_signatureThreshold == 0) {
            revert AtomWarden_InvalidThreshold();
        }

        __AccessControl_init();
        // Version "2" ensures the EIP-712 domain separator differs from any pre-existing
        // v1 deployment after an in-place upgrade.
        __EIP712_init("AtomWarden", "2");
        __Pausable_init();

        _bootstrapAdmin(admin);
        _setMultiVault(_multiVault);
        _setClaimWindow(_claimWindow);
        _setMinFeeThreshold(_minFeeThreshold);
        _setMaxValidAfter(_maxValidAfter);
        _setMaxValidUntil(_maxValidUntil);

        signatureThreshold = _signatureThreshold;
        emit SignatureThresholdSet(0, _signatureThreshold);
    }

    /**
     * @notice Bootstraps AccessControl, EIP-712, Pausable, and the multi-signer quorum
     *         surface on top of an already-initialized proxy, and atomically sets the
     *         operational configuration in a single transaction.
     * @dev Gated to the MultiVault-resolved admin so the upgrade tx cannot be front-run.
     *      `signerCount` remains 0 immediately after this call — claims revert until admin
     *      calls `grantRole(SIGNER_ROLE, ...)` for at least `_signatureThreshold` accounts.
     *      The `> signerCount` check that guards the public `setSignatureThreshold` does
     *      not apply here for the same bootstrap reason as `initialize`.
     * @param _claimWindow New creator-fallback claim window. A value of `0` disables the
     *        creator fallback (see `claimAsCreatorAfterExpiry`).
     * @param _minFeeThreshold New minimum accumulated fees required for the creator fallback.
     * @param _signatureThreshold New quorum size for `claimWithAuthorization` (must be > 0).
     * @param _maxValidAfter New cap on `validAfter - block.timestamp` for claim auths.
     * @param _maxValidUntil New cap on `validUntil - block.timestamp` for claim auths.
     */
    function reinitialize(
        uint256 _claimWindow,
        uint256 _minFeeThreshold,
        uint256 _signatureThreshold,
        uint48 _maxValidAfter,
        uint48 _maxValidUntil
    )
        external
        reinitializer(2)
    {
        address admin = IMultiVaultCore(multiVault).getGeneralConfig().admin;
        if (msg.sender != admin) {
            revert AtomWarden_UnauthorizedReinitializer();
        }
        if (_signatureThreshold == 0) {
            revert AtomWarden_InvalidThreshold();
        }

        __AccessControl_init();
        // Version "2" ensures the EIP-712 domain separator differs from any pre-existing
        // v1 deployment after an in-place upgrade.
        __EIP712_init("AtomWarden", "2");
        __Pausable_init();
        _bootstrapAdmin(admin);

        _setClaimWindow(_claimWindow);
        _setMinFeeThreshold(_minFeeThreshold);
        _setMaxValidAfter(_maxValidAfter);
        _setMaxValidUntil(_maxValidUntil);

        signatureThreshold = _signatureThreshold;
        emit SignatureThresholdSet(0, _signatureThreshold);
    }

    /* =================================================== */
    /*                   USER FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc IAtomWarden
    function claimOwnershipOverAddressAtom(bytes32 atomId) external whenNotPaused {
        bytes memory lowercaseAddressData = abi.encodePacked(Strings.toHexString(msg.sender));
        bytes memory checksumAddressData = abi.encodePacked(Strings.toChecksumHexString(msg.sender));
        bytes32 lowercaseAtomId = IMultiVaultCore(multiVault).calculateAtomId(lowercaseAddressData);
        bytes32 checksumAtomId = IMultiVaultCore(multiVault).calculateAtomId(checksumAddressData);

        if (atomId != lowercaseAtomId && atomId != checksumAtomId) {
            revert AtomWarden_ClaimOwnershipFailed();
        }

        _requireExistingAtom(atomId);

        address atomWalletAddress = _getAtomWallet(atomId);
        _requireWalletUnclaimed(atomWalletAddress);

        IAtomWallet(atomWalletAddress).completeClaim(msg.sender);

        emit AtomWalletOwnershipClaimed(atomId, msg.sender);
    }

    /**
     * @inheritdoc IAtomWarden
     * @dev `signature` is a packed bundle of `N * 65` bytes, where each 65-byte slice is an
     *      individual ECDSA signature `(r, s, v)` over the EIP-712 typed digest of
     *      `authorization`. `N` must be at least `signatureThreshold`. Each recovered
     *      address must (a) hold `SIGNER_ROLE` and (b) be strictly greater than the
     *      previous recovered address — the ascending-order rule (Gnosis Safe convention)
     *      provides O(1) deduplication and a canonical bundle layout. Off-chain producers
     *      MUST sort signers by recovered address (not by key index) before concatenating.
     */
    function claimWithAuthorization(
        ClaimAuthorization calldata authorization,
        bytes calldata signature
    )
        external
        whenNotPaused
    {
        if (msg.sender != authorization.claimant) {
            revert AtomWarden_UnauthorizedClaimant();
        }

        _requireExistingAtom(authorization.atomId);

        address atomWalletAddress = _getAtomWallet(authorization.atomId);
        _requireWalletUnclaimed(atomWalletAddress);

        if (authorization.nonce != claimNonces[authorization.claimant]) {
            revert AtomWarden_InvalidNonce();
        }

        _requireValidTimeWindow(authorization.validAfter, authorization.validUntil);

        (address firstSigner, uint16 verifiedSigners) = _verifyQuorum(authorization, signature);

        IAtomWallet(atomWalletAddress).completeClaim(authorization.claimant);

        unchecked {
            ++claimNonces[authorization.claimant];
        }

        emit AtomWalletOwnershipClaimedByAuthorization(
            authorization.atomId, authorization.claimant, firstSigner, authorization.claimType, verifiedSigners
        );
    }

    /// @inheritdoc IAtomWarden
    /// @dev Only works for atoms created after the v2 upgrade. Pre-upgrade atoms have no
    ///      recorded creator and will revert with AtomWarden_CreatorUnknown. The entire
    ///      creator-fallback path is disabled when `claimWindow == 0` — admins can flip
    ///      the path off without resetting the other parameters by calling
    ///      `setClaimWindow(0)`.
    function claimAsCreatorAfterExpiry(bytes32 atomId) external whenNotPaused {
        if (claimWindow == 0) {
            revert AtomWarden_CreatorClaimDisabled();
        }

        _requireExistingAtom(atomId);

        address creator = IMultiVaultCore(multiVault).getAtomCreator(atomId);
        if (creator == address(0)) {
            revert AtomWarden_CreatorUnknown();
        }
        if (creator != msg.sender) {
            revert AtomWarden_NotAtomCreator();
        }

        address atomWalletAddress = _getAtomWallet(atomId);
        _requireWalletUnclaimed(atomWalletAddress);

        uint256 accumulatedFees = IMultiVault(multiVault).accumulatedAtomWalletDepositFees(atomWalletAddress);
        if (accumulatedFees < minFeeThreshold) {
            revert AtomWarden_MinFeeThresholdNotMet();
        }

        uint48 createdAt = IMultiVaultCore(multiVault).getAtomCreatedAt(atomId);
        if (block.timestamp < uint256(createdAt) + claimWindow) {
            revert AtomWarden_ClaimWindowNotElapsed();
        }

        IAtomWallet(atomWalletAddress).completeClaim(msg.sender);

        emit AtomWalletOwnershipClaimedByCreator(atomId, msg.sender, accumulatedFees);
    }

    /* =================================================== */
    /*                  OPERATOR FUNCTIONS                 */
    /* =================================================== */

    /// @inheritdoc IAtomWarden
    function grantAtomWalletOwnership(bytes32 atomId, address newOwner) external onlyRole(OPERATOR_ROLE) {
        _grantAtomWalletOwnership(atomId, newOwner);
    }

    /// @inheritdoc IAtomWarden
    /// @dev Reverts atomically if any individual grant fails. Operators should filter out
    ///      already-claimed wallets off-chain before submitting a batch.
    function batchGrantAtomWalletOwnership(
        bytes32[] calldata atomIds,
        address[] calldata newOwners
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        uint256 length = atomIds.length;
        if (length != newOwners.length) {
            revert AtomWarden_ArrayLengthMismatch();
        }
        if (length > MAX_BATCH_SIZE) {
            revert AtomWarden_BatchTooLarge();
        }

        for (uint256 i = 0; i < length;) {
            _grantAtomWalletOwnership(atomIds[i], newOwners[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IAtomWarden
    function incrementNonce(address claimant) external onlyRole(OPERATOR_ROLE) {
        if (claimant == address(0)) {
            revert AtomWarden_InvalidAddress();
        }

        unchecked {
            ++claimNonces[claimant];
        }

        emit ClaimNonceIncremented(claimant, claimNonces[claimant]);
    }

    /* =================================================== */
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

    /// @inheritdoc IAtomWarden
    function setMultiVault(address _multiVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMultiVault(_multiVault);
    }

    /// @inheritdoc IAtomWarden
    function setClaimWindow(uint256 newClaimWindow) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setClaimWindow(newClaimWindow);
    }

    /// @inheritdoc IAtomWarden
    function setMinFeeThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMinFeeThreshold(newThreshold);
    }

    /// @inheritdoc IAtomWarden
    function setSignatureThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newThreshold == 0 || newThreshold > signerCount) {
            revert AtomWarden_InvalidThreshold();
        }
        uint256 oldValue = signatureThreshold;
        signatureThreshold = newThreshold;
        emit SignatureThresholdSet(oldValue, newThreshold);
    }

    /// @inheritdoc IAtomWarden
    function setMaxValidAfter(uint48 newValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaxValidAfter(newValue);
    }

    /// @inheritdoc IAtomWarden
    function setMaxValidUntil(uint48 newValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaxValidUntil(newValue);
    }

    /// @notice Halts all user-driven claim entry points (`claimOwnershipOverAddressAtom`,
    ///         `claimWithAuthorization`, `claimAsCreatorAfterExpiry`). Operator paths
    ///         (`grantAtomWalletOwnership`, `batchGrantAtomWalletOwnership`) are NOT gated
    ///         on pause by design — they remain available as a manual override during
    ///         incidents. Reverts with `EnforcedPause()` from `PausableUpgradeable` on
    ///         double-pause.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Lifts a `pause()`. Reverts with `ExpectedPause()` from `PausableUpgradeable`
    ///         if the contract is not currently paused.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /* =================================================== */
    /*                   ROLE HOOK OVERRIDES               */
    /* =================================================== */

    /// @dev Tracks `SIGNER_ROLE` cardinality without inheriting `AccessControlEnumerable`
    ///      (which would introduce a separate storage layout). The parent's return value
    ///      is `true` only when the role was newly granted, making this idempotent across
    ///      re-grants.
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool granted) {
        granted = super._grantRole(role, account);
        if (granted && role == SIGNER_ROLE) {
            unchecked {
                ++signerCount;
            }
        }
    }

    /// @dev Mirrors `_grantRole`. Decrements only on a real revocation. We intentionally
    ///      do NOT auto-clamp `signatureThreshold` when a revocation drops `signerCount`
    ///      below the current threshold — claims will revert with `InsufficientSigners`
    ///      until admin lowers the threshold, which surfaces the misconfiguration loudly
    ///      rather than silently weakening the quorum.
    ///
    ///      The `signerCount > 0` guard saturates at 0 instead of underflowing. Today the
    ///      live AtomWarden proxy has no pre-upgrade `SIGNER_ROLE` grants (verified via
    ///      historical `RoleGranted` logs at the upgrade fork block), so the role-hook
    ///      counter and the on-chain role set are paired by construction. The guard exists
    ///      to keep that invariant safe under future state — testnet rotations, a
    ///      hypothetical future `initialize` that grants `SIGNER_ROLE` directly, or any
    ///      out-of-band grant that bypasses the role hook — where `super._revokeRole`
    ///      could return `true` while `signerCount` is already 0.
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool revoked) {
        revoked = super._revokeRole(role, account);
        if (revoked && role == SIGNER_ROLE && signerCount > 0) {
            unchecked {
                --signerCount;
            }
        }
    }

    /* =================================================== */
    /*                   INTERNAL FUNCTIONS                */
    /* =================================================== */

    function _grantAtomWalletOwnership(bytes32 atomId, address newOwner) internal {
        if (newOwner == address(0)) {
            revert AtomWarden_InvalidNewOwnerAddress();
        }

        _requireExistingAtom(atomId);
        address atomWalletAddress = _getAtomWallet(atomId);
        _requireWalletUnclaimed(atomWalletAddress);
        IAtomWallet(atomWalletAddress).completeClaim(newOwner);

        emit AtomWalletOwnershipGranted(atomId, newOwner, msg.sender);
    }

    function _bootstrapAdmin(address admin) internal {
        if (admin == address(0)) {
            revert AtomWarden_InvalidAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function _requireExistingAtom(bytes32 atomId) internal view {
        if (!IMultiVaultCore(multiVault).isAtom(atomId)) {
            revert AtomWarden_AtomIdDoesNotExist();
        }
    }

    function _getAtomWallet(bytes32 atomId) internal view returns (address atomWalletAddress) {
        atomWalletAddress = IMultiVault(multiVault).computeAtomWalletAddr(atomId);
        if (atomWalletAddress.code.length == 0) {
            revert AtomWarden_AtomWalletNotDeployed();
        }
    }

    function _requireWalletUnclaimed(address atomWalletAddress) internal view {
        if (IAtomWallet(atomWalletAddress).isClaimed()) {
            revert AtomWarden_AlreadyClaimed();
        }
    }

    /**
     * @notice Verifies a packed multi-signer ECDSA bundle over the EIP-712 typed digest.
     * @param  authorization The claim authorization being verified.
     * @param  signature     Concatenation of N * 65-byte ECDSA signatures, each over the
     *                       same `_hashTypedDataV4` digest of `authorization`. Producers
     *                       MUST sort signers by recovered address ascending before
     *                       concatenating; the contract enforces strictly-ascending
     *                       recovered addresses to deduplicate and canonicalize the bundle.
     * @return firstSigner   The lowest recovered signer address — emitted as the
     *                       canonical representative on `AtomWalletOwnershipClaimedByAuthorization`.
     * @return verified      Number of signers verified for this claim, fits in `uint16`
     *                       since segment count is bounded by calldata size.
     * @dev Reverts with `AtomWarden_SignatureLengthInvalid` if the bundle length is zero
     *      or not a multiple of 65; `AtomWarden_BatchTooLarge` if the segment count exceeds
     *      `MAX_BATCH_SIZE`; `AtomWarden_InsufficientSigners` if the segment count
     *      is below `signatureThreshold`; `AtomWarden_InvalidSignature` if any segment
     *      fails ECDSA recovery or the recovered address lacks `SIGNER_ROLE`; and
     *      `AtomWarden_NonCanonicalSignerOrder` if any recovered address is not strictly
     *      greater than the previous one.
     */
    function _verifyQuorum(
        ClaimAuthorization calldata authorization,
        bytes calldata signature
    )
        internal
        view
        returns (address firstSigner, uint16 verified)
    {
        uint256 segments = _bundleSegmentCount(signature.length);
        uint256 threshold = signatureThreshold;
        if (segments < threshold) {
            revert AtomWarden_InsufficientSigners();
        }

        bytes32 digest = _hashTypedDataV4(_hashClaimAuthorization(authorization));
        address previous = address(0);

        for (uint256 i = 0; i < segments;) {
            uint256 start = i * 65;
            (address recovered, ECDSA.RecoverError recoverError,) =
                ECDSA.tryRecover(digest, signature[start:start + 65]);
            if (recoverError != ECDSA.RecoverError.NoError) {
                revert AtomWarden_InvalidSignature();
            }
            if (recovered <= previous) {
                revert AtomWarden_NonCanonicalSignerOrder();
            }
            if (!hasRole(SIGNER_ROLE, recovered)) {
                revert AtomWarden_InvalidSignature();
            }

            if (i == 0) {
                firstSigner = recovered;
            }
            previous = recovered;
            unchecked {
                ++i;
            }
        }

        // `segments` is bounded by `MAX_BATCH_SIZE` (150) in `_bundleSegmentCount`, so it always
        // fits in `uint16`.
        // forge-lint: disable-next-line(unsafe-typecast)
        verified = uint16(segments);
    }

    /// @dev Validates the packed `N x 65`-byte signature bundle length and returns the segment count
    ///      `N`. Reverts with `AtomWarden_SignatureLengthInvalid` if the bundle is empty or not a
    ///      multiple of 65, and `AtomWarden_BatchTooLarge` if `N` exceeds `MAX_BATCH_SIZE`.
    function _bundleSegmentCount(uint256 length) private pure returns (uint256 segments) {
        if (length == 0 || length % 65 != 0) {
            revert AtomWarden_SignatureLengthInvalid();
        }
        segments = length / 65;
        if (segments > MAX_BATCH_SIZE) {
            revert AtomWarden_BatchTooLarge();
        }
    }

    function _hashClaimAuthorization(ClaimAuthorization calldata authorization) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CLAIM_AUTHORIZATION_TYPEHASH,
                authorization.claimant,
                authorization.atomId,
                authorization.claimType,
                authorization.nonce,
                authorization.validAfter,
                authorization.validUntil
            )
        );
    }

    function _requireValidTimeWindow(uint48 validAfter, uint48 validUntil) internal view {
        // Cap checks first: surfaces the more specific `ValidityWindowTooLong` error
        // when an off-chain signer issued an out-of-policy auth, instead of falling
        // through to the generic `InvalidTimeWindow` ordering check below.
        //
        // Compare in `uint256` space to avoid uint48 overflow when admin sets a cap
        // close to `type(uint48).max`; the `validAfter` / `validUntil` inputs are
        // bounded by `uint48`, so the right-hand sums fit comfortably.
        if (uint256(validAfter) > block.timestamp + uint256(maxValidAfter)) {
            revert AtomWarden_ValidityWindowTooLong();
        }
        if (uint256(validUntil) > block.timestamp + uint256(maxValidUntil)) {
            revert AtomWarden_ValidityWindowTooLong();
        }

        if (validUntil < validAfter || block.timestamp < validAfter || block.timestamp > validUntil) {
            revert AtomWarden_InvalidTimeWindow();
        }
    }

    function _setMultiVault(address _multiVault) internal {
        if (_multiVault == address(0)) {
            revert AtomWarden_InvalidAddress();
        }

        multiVault = _multiVault;
        emit MultiVaultSet(_multiVault);
    }

    function _setClaimWindow(uint256 newClaimWindow) internal {
        uint256 oldValue = claimWindow;
        claimWindow = newClaimWindow;
        emit ClaimWindowSet(oldValue, newClaimWindow);
    }

    function _setMinFeeThreshold(uint256 newThreshold) internal {
        uint256 oldValue = minFeeThreshold;
        minFeeThreshold = newThreshold;
        emit MinFeeThresholdSet(oldValue, newThreshold);
    }

    function _setMaxValidAfter(uint48 newValue) internal {
        uint48 oldValue = maxValidAfter;
        maxValidAfter = newValue;
        emit MaxValidAfterSet(oldValue, newValue);
    }

    function _setMaxValidUntil(uint48 newValue) internal {
        uint48 oldValue = maxValidUntil;
        maxValidUntil = newValue;
        emit MaxValidUntilSet(oldValue, newValue);
    }
}
