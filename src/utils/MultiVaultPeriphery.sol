// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IMultiVaultCore } from "src/interfaces/IMultiVaultCore.sol";
import { IMultiVaultPeriphery } from "src/interfaces/IMultiVaultPeriphery.sol";
import { Multicall3 } from "src/external/multicall/Multicall3.sol";

/**
 * @title MultiVaultPeriphery
 * @author 0xIntuition
 * @notice A periphery contract to facilitate and batch common MultiVault operations with proper attribution.
 */
contract MultiVaultPeriphery is
    IMultiVaultPeriphery,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    Multicall3
{
    /* =================================================== */
    /*                       STATE                         */
    /* =================================================== */

    /// @notice The MultiVault contract this periphery contract interacts with
    IMultiVault public multiVault;

    /// @notice The MultiVaultCore interface for helper functions (references to the same underlying MultiVault
    /// contract)
    IMultiVaultCore public multiVaultCore;

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

    /// @inheritdoc IMultiVaultPeriphery
    function initialize(address _admin, address _multiVault) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _setMultiVault(_multiVault);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /* =================================================== */
    /*                  ADMIN FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc IMultiVaultPeriphery
    function setMultiVault(address _multiVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                 EXTERNAL FUNCTIONS                  */
    /* =================================================== */

    /// @inheritdoc IMultiVaultPeriphery
    function createAtomsFor(
        bytes[] calldata atomData,
        address creator
    )
        external
        payable
        nonReentrant
        returns (bytes32[] memory atomIds)
    {
        if (creator == address(0)) {
            revert MultiVaultPeriphery_InvalidAddress();
        }

        uint256 length = atomData.length;
        if (length == 0) {
            revert MultiVaultPeriphery_ZeroLengthArray();
        }

        uint256 atomCost = multiVaultCore.getAtomCost();
        uint256 requiredValue = atomCost * length;

        if (msg.value < requiredValue) {
            revert MultiVaultPeriphery_InsufficientMsgValue(requiredValue, msg.value);
        }

        // Refund anything above the minimum cost * number of atoms
        _refundExcessValue(msg.value - requiredValue);

        // Build assets array with fixed atomCost
        uint256[] memory atomAssets = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            atomAssets[i] = atomCost;
            unchecked {
                ++i;
            }
        }

        // Only requiredValue gets forwarded to the MultiVault (no extra shares get minted for this periphery contract)
        atomIds = multiVault.createAtoms{ value: requiredValue }(atomData, atomAssets);

        for (uint256 i = 0; i < length;) {
            emit AtomCreatedBy(msg.sender, creator, atomIds[i], atomData[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IMultiVaultPeriphery
    function createTriplesFor(
        bytes32[] calldata subjects,
        bytes32[] calldata predicates,
        bytes32[] calldata objects,
        address creator
    )
        external
        payable
        nonReentrant
        returns (bytes32[] memory tripleIds)
    {
        if (creator == address(0)) {
            revert MultiVaultPeriphery_InvalidAddress();
        }

        uint256 length = subjects.length;
        if (length == 0) {
            revert MultiVaultPeriphery_ZeroLengthArray();
        }

        if (predicates.length != length || objects.length != length) {
            revert MultiVaultPeriphery_ArrayLengthMismatch();
        }

        uint256 tripleCost = multiVaultCore.getTripleCost();
        uint256 requiredValue = tripleCost * length;

        if (msg.value < requiredValue) {
            revert MultiVaultPeriphery_InsufficientMsgValue(requiredValue, msg.value);
        }

        // Refund anything above the minimum cost * number of triples
        _refundExcessValue(msg.value - requiredValue);

        // Build assets array with fixed tripleCost
        uint256[] memory tripleAssets = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            tripleAssets[i] = tripleCost;
            unchecked {
                ++i;
            }
        }

        tripleIds = multiVault.createTriples{ value: requiredValue }(subjects, predicates, objects, tripleAssets);

        _emitTripleCreatedBatch(msg.sender, creator, tripleIds, subjects, predicates, objects);
    }

    /**
     * @notice Bootstraps a counter triple vault (if needed) and deposits for a specified receiver
     */
    /**
     * @dev Internal helper that:
     *
     *  1. Optionally bootstraps the positive triple vault on a non-default curve by:
     *     - Depositing `minDeposit` into the positive triple vault with `receiver = address(this)`
     *     - Redeeming all newly minted shares back to this periphery
     *     - This initializes both the positive triple and its counter triple vaults on that curve.
     *
     *  2. Deposits `userAssets` into the *counter triple* vault on the same non-default curve
     *     with `receiver = receiver`, assuming the receiver has previously approved this
     *     periphery contract as a depositor in MultiVault.
     *
     *  Invariants:
     *  - No vault shares are durably minted to this periphery contract. Bootstrap shares are
     *    fully redeemed within the same transaction.
     *  - No net TRUST (ETH) remains in this contract as a result of this call; any net new
     *    ETH introduced by `msg.value` and/or bootstrap redeem is either forwarded into
     *    MultiVault deposits or refunded back to the caller.
     *  - If the receiver has NOT approved this periphery as a depositor in MultiVault,
     *    the final `multiVault.deposit` will revert with `MultiVault_SenderNotApproved`,
     *    and the entire transaction (including bootstrap steps) reverts atomically.
     *
     *  Requirements:
     *  - `tripleId` MUST correspond to an existing triple term.
     *  - `curveId` MUST NOT be the default bonding curve ID.
     *  - `userAssets` MUST be > 0.
     *  - `msg.value` MUST be at least `userAssets + minDeposit` when bootstrap is required,
     *    or at least `userAssets` when the positive triple vault on that curve is already initialized.
     */
    function bootstrapCounterTripleVaultAndDepositFor(
        bytes32 tripleId,
        uint256 curveId,
        uint256 userAssets,
        uint256 minSharesForUser,
        address receiver
    )
        external
        payable
        nonReentrant
        returns (uint256 userShares)
    {
        if (receiver == address(0)) {
            revert MultiVaultPeriphery_InvalidAddress();
        }

        if (userAssets == 0) {
            revert MultiVaultPeriphery_InvalidUserAssets();
        }

        // Ensure we're dealing with a triple term
        if (!multiVaultCore.isTriple(tripleId)) {
            revert MultiVaultPeriphery_OnlyTriplesAllowed();
        }

        {
            // Only allow bootstrapping / depositing on non-default curves
            uint256 defaultCurveId = multiVaultCore.getBondingCurveConfig().defaultCurveId;
            if (curveId == defaultCurveId) {
                revert MultiVaultPeriphery_DefaultCurveIdNotAllowed();
            }

            // Check whether the positive triple vault on this curve is new (uninitialized)
            (, uint256 positiveShares) = multiVault.getVault(tripleId, curveId);
            if (positiveShares != 0) {
                revert MultiVaultPeriphery_VaultAlreadyInitialized(tripleId, curveId);
            }
        }

        // Compute the counter triple ID from the triple ID
        bytes32 counterTripleId = multiVaultCore.getCounterIdFromTripleId(tripleId);

        uint256 minDeposit = multiVaultCore.getGeneralConfig().minDeposit;

        // The minimum ETH this call intends to actually use for MultiVault deposits
        uint256 requiredValue = minDeposit + userAssets;

        if (msg.value < requiredValue) {
            revert MultiVaultPeriphery_InsufficientMsgValue(requiredValue, msg.value);
        }

        // Refund any excess ETH the caller sent beyond what this function will actually use
        _refundExcessValue(msg.value - requiredValue);

        // Step 1: Deposit minDeposit into the positive triple vault on the non-default curve,
        // with receiver = this periphery contract.
        uint256 bootstrapShares = multiVault.deposit{ value: minDeposit }(
            address(this),
            tripleId,
            curveId,
            0 // minShares = 0 (no slippage constraint for this internal bootstrap step)
        );

        // Step 2: Redeem all bootstrap shares back to this periphery, again with no slippage guard.
        // This initializes the counter triple vault on this curve via MultiVault internally, while
        // leaving only minShare in each of the vaults (positive and counter triple vaults) and
        // returning assetsAfterFees to this periphery contract.
        uint256 redeemedAssets = multiVault.redeem(address(this), tripleId, curveId, bootstrapShares, 0);

        // Step 3: Deposit the user's intended assets into the counter triple vault
        // NOTE: This call will revert with MultiVault_SenderNotApproved if `receiver` has not
        // granted this periphery deposit approval in MultiVault. Because this happens within
        // the same transaction, any bootstrap steps above are rolled back as well.
        userShares = multiVault.deposit{ value: redeemedAssets + userAssets }(
            receiver, counterTripleId, curveId, minSharesForUser
        );

        emit CounterTripleVaultBootstrappedAndDeposited(
            msg.sender, receiver, tripleId, counterTripleId, curveId, userAssets, userShares
        );
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    /// @dev Internal function to set the MultiVault contract address
    function _setMultiVault(address _multiVault) internal {
        if (_multiVault == address(0)) {
            revert MultiVaultPeriphery_InvalidAddress();
        }
        multiVault = IMultiVault(_multiVault);
        multiVaultCore = IMultiVaultCore(_multiVault);
        emit MultiVaultSet(_multiVault);
    }

    //// @dev Internal function to refund excess ETH value to msg.sender
    function _refundExcessValue(uint256 value) internal {
        if (value > 0) {
            (bool success,) = msg.sender.call{ value: value }("");
            if (!success) {
                revert MultiVaultPeriphery_RefundFailed();
            }
        }
    }

    /// @dev Internal helper to emit TripleCreatedBy events in batch
    function _emitTripleCreatedBatch(
        address caller,
        address creator,
        bytes32[] memory tripleIds,
        bytes32[] calldata subjects,
        bytes32[] calldata predicates,
        bytes32[] calldata objects
    )
        internal
    {
        uint256 length = tripleIds.length;
        for (uint256 i; i < length; ++i) {
            emit TripleCreatedBy(caller, creator, tripleIds[i], subjects[i], predicates[i], objects[i]);
        }
    }
}
