// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

struct BatchSetUserBalancesParams {
    bytes32[] termIds;
    uint256 bondingCurveId;
    address user;
    uint256[] userBalances;
}

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
     * @notice Emitted when the term count is set
     * @param termCount new term count
     */
    event TermCountSet(uint256 termCount);


    error MultiVault_EmptyArray();
    error MultiVault_InvalidBondingCurveId();

    /*//////////////////////////////////////////////////////////////
                             MIGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the term count
     * @param _termCount The new term count
     */
    function setTermCount(uint256 _termCount) external onlyRole(MIGRATOR_ROLE) {
        if (_termCount == 0) {
            revert MultiVault_ZeroValue();
        }

        totalTermsCreated = _termCount;

        emit TermCountSet(_termCount);
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
        if (atomDataArray.length == 0) {
            revert MultiVault_EmptyArray();
        }

        if (atomDataArray.length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < atomDataArray.length; i++) {
            bytes32 atomId = calculateAtomId(atomDataArray[i]);
            _atoms[atomId] = atomDataArray[i];
            emit AtomCreated(creators[i], atomId, atomDataArray[i], address(0)); // we do not emit the atom wallet
                // address here
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
        if (tripleAtomIds.length == 0) {
            revert MultiVault_EmptyArray();
        }

        if (tripleAtomIds.length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < tripleAtomIds.length; i++) {
            bytes32 tripleId = calculateTripleId(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            bytes32 counterTripleId = getCounterIdFromTripleId(tripleId);

            // Set the triple mappings
            _triples[tripleId] = tripleAtomIds[i];
            _isTriple[tripleId] = true;

            // Set the counter triple mappings
            _isTriple[counterTripleId] = true;
            _triples[counterTripleId] = tripleAtomIds[i];
            _tripleIdFromCounterId[counterTripleId] = tripleId;

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

        if (termIds.length == 0) {
            revert MultiVault_EmptyArray();
        }

        if (termIds.length != vaultTotals.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < termIds.length; i++) {
            _vaults[termIds[i]][bondingCurveId].totalAssets = vaultTotals[i].totalAssets;
            _vaults[termIds[i]][bondingCurveId].totalShares = vaultTotals[i].totalShares;

            emit SharePriceChanged(
                termIds[i],
                bondingCurveId,
                currentSharePrice(bondingCurveId, vaultTotals[i].totalShares, vaultTotals[i].totalAssets),
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

        if (params.termIds.length == 0) {
            revert MultiVault_EmptyArray();
        }

        if (params.termIds.length != params.userBalances.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < params.termIds.length; i++) {
            _vaults[params.termIds[i]][params.bondingCurveId].balanceOf[params.user] = params.userBalances[i];

            emit Deposited(
                params.user,
                params.user,
                params.termIds[i],
                params.bondingCurveId,
                convertToAssets(
                    params.bondingCurveId,
                    _vaults[params.termIds[i]][params.bondingCurveId].totalShares,
                    _vaults[params.termIds[i]][params.bondingCurveId].totalAssets,
                    params.userBalances[i]
                ),
                0, // assetsAfterFees are not set here, as this is a migration
                params.userBalances[i],
                getShares(params.user, params.termIds[i], params.bondingCurveId),
                getVaultType(params.termIds[i])
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the current share price for a certain bonding curve ID given total shares and total assets
     * @param bondingCurveId The bonding curve ID of the vault
     * @param totalShares The total shares in the vault
     * @param totalAssets The total assets in the vault
     * @return The current share price
     */
    function currentSharePrice(
        uint256 bondingCurveId,
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        view
        returns (uint256)
    {
        if (bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(ONE_SHARE, totalShares, totalAssets, bondingCurveId);
    }

    /**
     * @notice Converts a certain amount of shares to assets for a given bonding curve ID
     * @param bondingCurveId The bonding curve ID of the vault
     * @param totalShares The total shares in the vault
     * @param totalAssets The total assets in the vault
     * @param shares The amount of shares to convert to assets
     * @return The amount of assets corresponding to the given shares
     */
    function convertToAssets(
        uint256 bondingCurveId,
        uint256 totalShares,
        uint256 totalAssets,
        uint256 shares
    )
        public
        view
        returns (uint256)
    {
        if (bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        IBondingCurveRegistry bcRegistry = IBondingCurveRegistry(bondingCurveConfig.registry);
        return bcRegistry.previewRedeem(shares, totalShares, totalAssets, bondingCurveId);
    }
}
