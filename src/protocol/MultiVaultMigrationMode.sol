// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/**
 * @title MultiVaultMigrationMode
 * @author 0xIntuition
 * @notice Contract for migrating the MultiVault data using an external script
 *         and the MIGRATOR_ROLE. After the core data is migrated, the MIGRATOR_ROLE
 *         should be permanently revoked. Final step of the migration also includes
 *         sending the correct amount of the underlying asset (TRUST tokens) to the
 *         MultiVault contract to back the shares. This contract will ultimately be
 *         upgraded to the standard MultiVault contract.
 */
contract MultiVaultMigrationMode is MultiVault {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role used for the state migration
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct representing the vault totals
     * @param totalAssets Total assets in the vault
     * @param totalShares Total shares in the vault
     */
    struct VaultTotals {
        uint256 totalAssets;
        uint256 totalShares;
    }

    /**
     * @notice Struct representing the parameters for batch setting user balances
     * @param termIds The term IDs of the vaults
     * @param bondingCurveId The bonding curve ID of all of the vaults
     * @param user The user whose balances are being set
     * @param userBalances The user balances for each vault
     */
    struct BatchSetUserBalancesParams {
        bytes32[] termIds;
        uint256 bondingCurveId;
        address user;
        uint256[] userBalances;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MultiVault_InvalidBondingCurveId();

    error MultiVault_ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                             MIGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the term count
     * @param _termCount The new term count
     */
    function setTermCount(uint256 _termCount) external onlyRole(MIGRATOR_ROLE) {
        totalTermsCreated = _termCount;
    }

    /**
     * @notice Sets the atom mappings data
     * @param creators The creators of the atoms
     * @param atomDataArray The atom data array
     */
    function batchSetAtomData(
        address[] calldata creators,
        bytes[] calldata atomDataArray
    )
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (atomDataArray.length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < atomDataArray.length; i++) {
            bytes32 atomId = calculateAtomId(atomDataArray[i]);
            _atoms[atomId] = atomDataArray[i];
            emit AtomCreated(creators[i], atomId, atomDataArray[i], computeAtomWalletAddr(atomId));
        }
    }

    /**
     * @notice Sets the triple mappings data
     * @param creators The creators of the triples
     * @param tripleAtomIds The atom IDs for each triple (array of arrays)
     */
    function batchSetTripleData(
        address[] calldata creators,
        bytes32[3][] calldata tripleAtomIds
    )
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (tripleAtomIds.length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < tripleAtomIds.length; i++) {
            bytes32 tripleId = calculateTripleId(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            bytes32 counterTripleId = getCounterIdFromTripleId(tripleId);
            _initializeTripleState(tripleId, counterTripleId, tripleAtomIds[i]);
            emit TripleCreated(creators[i], tripleId, tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
        }
    }

    /**
     * @notice Sets the vault totals for each vault
     * @param termIds The term IDs of the vaults
     * @param bondingCurveId The bonding curve ID of all of the vaults
     * @param vaultTotals The vault totals for each vault
     */
    function batchSetVaultTotals(
        bytes32[] calldata termIds,
        uint256 bondingCurveId,
        VaultTotals[] calldata vaultTotals
    )
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        if (termIds.length != vaultTotals.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < termIds.length; i++) {
            _setVaultTotals(
                termIds[i],
                bondingCurveId,
                vaultTotals[i].totalAssets,
                vaultTotals[i].totalShares,
                getVaultType(termIds[i])
            );
        }
    }

    /**
     * @notice Sets the user balances for each vault
     * @param params The parameters for the batch set user balances.
     */
    function batchSetUserBalances(BatchSetUserBalancesParams calldata params) external onlyRole(MIGRATOR_ROLE) {
        if (params.bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        if (params.user == address(0)) {
            revert MultiVault_ZeroAddress();
        }

        if (params.termIds.length != params.userBalances.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < params.termIds.length; i++) {
            _vaults[params.termIds[i]][params.bondingCurveId].balanceOf[params.user] = params.userBalances[i];
            uint256 assets = _convertToAssets(params.termIds[i], params.bondingCurveId, params.userBalances[i]);

            emit Deposited(
                address(this),
                params.user,
                params.termIds[i],
                params.bondingCurveId,
                assets,
                assets,
                params.userBalances[i],
                getShares(params.user, params.termIds[i], params.bondingCurveId),
                getVaultType(params.termIds[i])
            );
        }
    }
}
