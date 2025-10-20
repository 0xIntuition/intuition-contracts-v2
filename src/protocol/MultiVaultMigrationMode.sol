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

    /**
     * @notice Struct representing the parameters for batch setting user balances
     * @param termIds The term IDs of the vaults
     * @param bondingCurveId The bonding curve ID of all of the vaults
     * @param user The user whose balances are being set
     * @param userBalances The user balances for each vault
     */
    struct BatchSetUserBalancesParams {
        bytes32[][] termIds;
        uint256 bondingCurveId;
        address[] users;
        uint256[][] userBalances;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MultiVault_InvalidBondingCurveId();

    error MultiVault_ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                             MIGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows contract to receive TRUST to back the migrated shares
    receive() external payable { }

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
    function batchSetAtomData(address[] calldata creators, bytes[] calldata atomDataArray)
        external
        onlyRole(MIGRATOR_ROLE)
    {
        uint256 length = atomDataArray.length;
        if (length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < length;) {
            bytes32 atomId = _calculateAtomId(atomDataArray[i]);
            _atoms[atomId] = atomDataArray[i];

            emit AtomCreated(creators[i], atomId, atomDataArray[i], _computeAtomWalletAddr(atomId));
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
    function batchSetTripleData(address[] calldata creators, bytes32[3][] calldata tripleAtomIds)
        external
        onlyRole(MIGRATOR_ROLE)
    {
        uint256 length = tripleAtomIds.length;

        if (length != creators.length) {
            revert MultiVault_ArraysNotSameLength();
        }

        for (uint256 i = 0; i < length;) {
            bytes32 tripleId = _calculateTripleId(tripleAtomIds[i][0], tripleAtomIds[i][1], tripleAtomIds[i][2]);
            bytes32 counterTripleId = _calculateCounterTripleId(tripleId);

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
    function batchSetVaultTotals(bytes32[] calldata termIds, uint256 bondingCurveId, VaultTotals[] calldata vaultTotals)
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
                _getVaultType(termIds[i])
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets balances for multiple users across multiple termIds on a single bondingCurveId.
     *         For each user i, we take termIds[i] and userBalances[i] (lengths must match),
     *         and set balanceOf[user] for each termId.
     * @param params The parameters for the batch set user balances.
     */
    function batchSetUserBalances(BatchSetUserBalancesParams calldata params) external onlyRole(MIGRATOR_ROLE) {
        if (params.bondingCurveId == 0) {
            revert MultiVault_InvalidBondingCurveId();
        }

        uint256 usersLength = params.users.length;
        if (usersLength == 0 || usersLength != params.termIds.length || usersLength != params.userBalances.length) {
            revert MultiVault_InvalidArrayLength();
        }

        for (uint256 i = 0; i < usersLength;) {
            if (params.users[i] == address(0)) {
                revert MultiVault_ZeroAddress();
            }

            bytes32[] calldata terms = params.termIds[i];
            uint256[] calldata balances = params.userBalances[i];

            if (terms.length != balances.length) {
                revert MultiVault_InvalidArrayLength();
            }

            for (uint256 j = 0; j < terms.length;) {
                // Write user balance
                _vaults[terms[j]][params.bondingCurveId].balanceOf[params.users[i]] = balances[j];

                // Compute assets at current share price
                uint256 assets = _convertToAssets(terms[j], params.bondingCurveId, balances[j]);

                emit Deposited(
                    address(this), // sender (migration)
                    params.users[i], // receiver
                    terms[j],
                    params.bondingCurveId,
                    assets, // assets
                    assets, // assetsAfterFees (equivalent to assets for migration)
                    balances[j], // shares that were minted (i.e. set during migration)
                    balances[j], // totalShares (equivalent to shares for migration)
                    _getVaultType(terms[j])
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
