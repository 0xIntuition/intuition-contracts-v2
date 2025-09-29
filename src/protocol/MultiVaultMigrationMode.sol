// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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
        uint256 length = atomDataArray.length;
        if (length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < length;) {
            bytes32 atomId = calculateAtomId(atomDataArray[i]);
            _atoms[atomId] = atomDataArray[i];
            emit AtomCreated(creators[i], atomId, atomDataArray[i], computeAtomWalletAddr(atomId));
            unchecked {
                ++i;
            }
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
        uint256 length = tripleAtomIds.length;

        if (length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < length;) {
            bytes32 tripleId = calculateTripleId(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            bytes32 counterTripleId = getCounterIdFromTripleId(tripleId);
            _initializeTripleState(tripleId, counterTripleId, tripleAtomIds[i]);
            emit TripleCreated(creators[i], tripleId, tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            unchecked {
                ++i;
            }
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

        uint256 length = termIds.length;

        if (length != vaultTotals.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < length;) {
            _setVaultTotals(
                termIds[i],
                bondingCurveId,
                vaultTotals[i].totalAssets,
                vaultTotals[i].totalShares,
                getVaultType(termIds[i])
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets the user balances for multiple users across multiple vaults
     * @param users Array of user addresses
     * @param termIds Array of term IDs (vault identifiers)
     * @param bondingCurveId The bonding curve ID for all vaults
     * @param userBalances 2D array where userBalances[i][j] = balance for users[i] in termIds[j]
     */
    function batchSetUserBalances(
        address[] calldata users,
        bytes32[] calldata termIds,
        uint256 bondingCurveId,
        uint256[][] calldata userBalances
    ) external onlyRole(MIGRATOR_ROLE) {
        if (bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        uint256 usersLength = users.length;
        uint256 termIdsLength = termIds.length;

        if (usersLength == 0 || termIdsLength == 0) {
            revert MultiVault_ArraysNotSameLength();
        }

        if (usersLength != userBalances.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        // Cache vault types to avoid repeated calculations
        VaultType[] memory vaultTypes = new VaultType[](termIdsLength);
        for (uint256 j = 0; j < termIdsLength;) {
            vaultTypes[j] = getVaultType(termIds[j]);
            unchecked {
                ++j;
            }
        }

        // Process each user
        for (uint256 i = 0; i < usersLength;) {
            address user = users[i];

            if (user == address(0)) {
                revert MultiVault_ZeroAddress();
            }

            if (userBalances[i].length != termIdsLength) {
                revert MultiVault_ArraysNotSameLength();
            }

            // Process each vault for this user
            for (uint256 j = 0; j < termIdsLength;) {
                bytes32 termId = termIds[j];
                uint256 balance = userBalances[i][j];

                _vaults[termId][bondingCurveId].balanceOf[user] = balance;
                uint256 assets = _convertToAssets(termId, bondingCurveId, balance);

                emit Deposited(
                    address(this),
                    user,
                    termId,
                    bondingCurveId,
                    assets,
                    assets,
                    balance,
                    getShares(user, termId, bondingCurveId),
                    vaultTypes[j]
                );
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
