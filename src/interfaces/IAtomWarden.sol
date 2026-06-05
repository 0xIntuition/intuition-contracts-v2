// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IAtomWarden
 * @author 0xIntuition
 * @notice Interface for the AtomWarden contract
 */
interface IAtomWarden {
    struct ClaimAuthorization {
        address claimant;
        bytes32 atomId;
        /// @dev Informational claim-method identifier with no on-chain branching.
        ///      Included in the EIP-712 signed payload so the signer commits to the
        ///      verification method used. Indexed off-chain for audit trail purposes.
        uint8 claimType;
        uint256 nonce;
        uint48 validAfter;
        uint48 validUntil;
    }

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    event MultiVaultSet(address multiVault);
    event ClaimWindowSet(uint256 oldValue, uint256 newValue);
    event MinFeeThresholdSet(uint256 oldValue, uint256 newValue);
    event SignatureThresholdSet(uint256 oldValue, uint256 newValue);
    event MaxValidAfterSet(uint48 oldValue, uint48 newValue);
    event MaxValidUntilSet(uint48 oldValue, uint48 newValue);

    event AtomWalletOwnershipClaimed(bytes32 indexed atomId, address indexed claimant);

    /// @dev `firstSigner` is the lowest recovered SIGNER_ROLE address from the verified
    ///      quorum bundle (canonical representative). `signers` is the total number of
    ///      distinct signers verified for this claim, always >= signatureThreshold.
    event AtomWalletOwnershipClaimedByAuthorization(
        bytes32 indexed atomId, address indexed claimant, address indexed firstSigner, uint8 claimType, uint16 signers
    );

    event AtomWalletOwnershipGranted(bytes32 indexed atomId, address indexed newOwner, address indexed operator);

    event AtomWalletOwnershipClaimedByCreator(bytes32 indexed atomId, address indexed creator, uint256 accumulatedFees);

    event ClaimNonceIncremented(address indexed claimant, uint256 newNonce);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error AtomWarden_InvalidAddress();
    error AtomWarden_AtomIdDoesNotExist();
    error AtomWarden_ClaimOwnershipFailed();
    error AtomWarden_AtomWalletNotDeployed();
    error AtomWarden_InvalidNewOwnerAddress();
    error AtomWarden_InvalidSignature();
    error AtomWarden_InvalidNonce();
    error AtomWarden_InvalidTimeWindow();
    error AtomWarden_UnauthorizedClaimant();
    error AtomWarden_AlreadyClaimed();
    error AtomWarden_NotAtomCreator();
    error AtomWarden_CreatorUnknown();
    error AtomWarden_ClaimWindowNotElapsed();
    error AtomWarden_MinFeeThresholdNotMet();
    error AtomWarden_ArrayLengthMismatch();
    error AtomWarden_BatchTooLarge();
    error AtomWarden_SignatureLengthInvalid();
    error AtomWarden_InsufficientSigners();
    error AtomWarden_NonCanonicalSignerOrder();
    error AtomWarden_InvalidThreshold();
    error AtomWarden_CreatorClaimDisabled();
    error AtomWarden_UnauthorizedReinitializer();
    error AtomWarden_ValidityWindowTooLong();

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    function OPERATOR_ROLE() external view returns (bytes32);
    function SIGNER_ROLE() external view returns (bytes32);
    function MAX_BATCH_SIZE() external view returns (uint256);
    function CLAIM_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function claimNonces(address claimant) external view returns (uint256);
    function claimWindow() external view returns (uint256);
    function minFeeThreshold() external view returns (uint256);
    function signatureThreshold() external view returns (uint256);
    function signerCount() external view returns (uint256);
    function maxValidAfter() external view returns (uint48);
    function maxValidUntil() external view returns (uint48);

    function claimOwnershipOverAddressAtom(bytes32 atomId) external;

    function claimWithAuthorization(ClaimAuthorization calldata authorization, bytes calldata signature) external;

    function grantAtomWalletOwnership(bytes32 atomId, address newOwner) external;

    function batchGrantAtomWalletOwnership(bytes32[] calldata atomIds, address[] calldata newOwners) external;

    function claimAsCreatorAfterExpiry(bytes32 atomId) external;

    function incrementNonce(address claimant) external;

    function setMultiVault(address _multiVault) external;

    /// @notice Sets the creator-fallback claim window.
    /// @param newClaimWindow Duration (seconds) the creator must wait after atom creation
    ///        before they can claim via the expiry fallback. Pass `0` to disable the
    ///        creator-fallback path entirely — `claimAsCreatorAfterExpiry` will then revert
    ///        with `AtomWarden_CreatorClaimDisabled` regardless of other parameters.
    function setClaimWindow(uint256 newClaimWindow) external;

    function setMinFeeThreshold(uint256 newThreshold) external;

    function setSignatureThreshold(uint256 newThreshold) external;

    /// @notice Sets the maximum allowed `validAfter - block.timestamp` for a
    ///         `ClaimAuthorization`. `0` forbids delayed activation entirely;
    ///         `type(uint48).max` disables the cap. Admin-only.
    function setMaxValidAfter(uint48 newValue) external;

    /// @notice Sets the maximum allowed `validUntil - block.timestamp` for a
    ///         `ClaimAuthorization`. `0` makes every signed claim instantly expired;
    ///         `type(uint48).max` disables the cap. Admin-only.
    function setMaxValidUntil(uint48 newValue) external;
}
