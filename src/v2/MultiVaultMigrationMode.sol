// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Errors} from "src/libraries/Errors.sol";
import {MultiVault} from "src/MultiVault.sol";
import {MultiVaultConfig} from "src/v2/MultiVaultConfig.sol";

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

    /// @notice Role for the state migration
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

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when the term count is set
     * @param termCount The new term count
     */
    event TermCountSet(uint256 termCount);

    /**
     * @notice Event emitted when the vault totals are set
     * @param termId The term ID of the vault
     * @param bondingCurveId The bonding curve ID of the vault
     * @param totalAssets The total assets in the vault
     * @param totalShares The total shares in the vault
     */
    event VaultTotalsSet(bytes32 termId, uint256 bondingCurveId, uint256 totalAssets, uint256 totalShares);

    /**
     * @notice Event emitted when the user balance is set
     * @param termId The term ID of the vault
     * @param bondingCurveId The bonding curve ID of the vault
     * @param user The user address
     * @param balance The user's share balance
     */
    event UserBalanceSet(bytes32 termId, uint256 bondingCurveId, address user, uint256 balance);

    /**
     * @notice Event emitted when the atom data is set
     * @param atomId The atom ID
     * @param atomData The atom data
     */
    event AtomDataSet(bytes32 atomId, bytes atomData);

    /**
     * @notice Event emitted when the triple data is set
     * @param tripleId The triple ID
     * @param subjectId The subject atom ID
     * @param predicateId The predicate atom ID
     * @param objectId The object atom ID
     */
    event TripleDataSet(bytes32 tripleId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId);

    /*//////////////////////////////////////////////////////////////
                             MIGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the term count
     * @param _termCount The new term count
     */
    function setTermCount(uint256 _termCount) external onlyRole(MIGRATOR_ROLE) {
        if (_termCount == 0) {
            revert Errors.MultiVault_ZeroValue();
        }

        termCount = _termCount;

        emit TermCountSet(_termCount);
    }

    /**
     * @notice Sets the vault totals for each vault
     * @param termIds The term IDs of the vaults
     * @param bondingCurveId The bonding curve ID of all of the vaults
     * @param vaultTotals The vault totals for each vault
     */
    function batchSetVaultTotals(bytes32[] calldata termIds, uint256 bondingCurveId, VaultTotals[] calldata vaultTotals)
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (bondingCurveId == 0) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        if (termIds.length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        if (termIds.length != vaultTotals.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < termIds.length; i++) {
            vaults[termIds[i]][bondingCurveId].totalAssets = vaultTotals[i].totalAssets;
            vaults[termIds[i]][bondingCurveId].totalShares = vaultTotals[i].totalShares;

            emit VaultTotalsSet(termIds[i], bondingCurveId, vaultTotals[i].totalAssets, vaultTotals[i].totalShares);
        }
    }

    /**
     * @notice Sets the user balances for each vault
     * @param termIds The term IDs of the vaults
     * @param bondingCurveId The bonding curve ID of all of the vaults
     * @param user The user address
     * @param userBalances The user balances for each vault
     */
    function batchSetUserBalances(
        bytes32[] calldata termIds,
        uint256 bondingCurveId,
        address user,
        uint256[] calldata userBalances
    ) external onlyRole(MIGRATOR_ROLE) {
        if (bondingCurveId == 0) {
            revert Errors.MultiVault_InvalidBondingCurveId();
        }

        if (user == address(0)) {
            revert Errors.MultiVault_ZeroAddress();
        }

        if (termIds.length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        if (termIds.length != userBalances.length) {
            revert Errors.MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < termIds.length; i++) {
            vaults[termIds[i]][bondingCurveId].balanceOf[user] = userBalances[i];

            emit UserBalanceSet(termIds[i], bondingCurveId, user, userBalances[i]);
        }
    }

    /**
     * @notice Sets the atom mappings data
     * @param atomDataArray The atom data array
     */
    function batchSetAtomData(bytes[] calldata atomDataArray)
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (atomDataArray.length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        for (uint256 i = 0; i < atomDataArray.length; i++) {
            bytes32 atomId = getAtomIdFromData(atomDataArray[i]);
            atomData[atomId] = atomDataArray[i];
            emit AtomDataSet(atomId, atomDataArray[i]);
        }
    }

    /**
     * @notice Sets the triple mappings data
     * @param tripleAtomIds The atom IDs for each triple (array of arrays)
     */
    function batchSetTripleData(bytes32[3][] calldata tripleAtomIds)
        external
        onlyRole(MIGRATOR_ROLE)
    {
        if (tripleAtomIds.length == 0) {
            revert Errors.MultiVault_EmptyArray();
        }

        for (uint256 i = 0; i < tripleAtomIds.length; i++) {
            bytes32 tripleId = tripleIdFromAtomIds(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            triples[tripleId] = tripleAtomIds[i];
            isTriple[tripleId] = true;
            emit TripleDataSet(tripleId, tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
        }
    }
}
