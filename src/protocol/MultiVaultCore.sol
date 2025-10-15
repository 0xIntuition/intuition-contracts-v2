// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IMultiVault, VaultType } from "src/interfaces/IMultiVault.sol";
import {
    IMultiVaultCore,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";

/**
 * @title  MultiVaultCore
 * @author 0xIntuition
 * @notice Core contract of the Intuition protocol. Manages atom state, triple state, and protocol configuration.
 */
abstract contract MultiVaultCore is IMultiVaultCore, Initializable {
    /* =================================================== */
    /*                       CONSTANTS                     */
    /* =================================================== */

    /// @notice Salt for atoms
    bytes32 public constant ATOM_SALT = keccak256("ATOM_SALT");

    /// @notice Salt used for positive triples
    bytes32 public constant TRIPLE_SALT = keccak256("TRIPLE_SALT");

    /// @notice Salt used for counter triples
    bytes32 public constant COUNTER_SALT = keccak256("COUNTER_SALT");

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice Total number of terms created
    uint256 public totalTermsCreated;

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;
    VaultFees public vaultFees;
    BondingCurveConfig public bondingCurveConfig;

    /*//////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of atom id to atom data
    mapping(bytes32 atomId => bytes data) internal _atoms;

    /// @notice Mapping of triple id to the underlying atom ids
    mapping(bytes32 tripleId => bytes32[3] tripleAtomIds) internal _triples;

    /// @notice Mapping of term IDs to determine whether a term is a triple or not
    mapping(bytes32 termId => bool isTriple) internal _isTriple;

    /// @notice Mapping of counter triple IDs to the corresponding triple IDs
    mapping(bytes32 counterTripleId => bytes32 tripleId) internal _tripleIdFromCounterId;

    /*//////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error MultiVaultCore_InvalidAdmin();

    error MultiVaultCore_AtomDoesNotExist(bytes32 termId);

    error MultiVaultCore_TripleDoesNotExist(bytes32 termId);

    error MultiVaultCore_TermDoesNotExist(bytes32 termId);

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /**
     * @notice Initializes the MultiVaultCore contract with the provided configuration structs
     * @param _generalConfig General configuration for the protocol
     * @param _atomConfig Configuration for atom creation and management
     * @param _tripleConfig Configuration for triple creation and management
     * @param _walletConfig Configuration for wallet management
     * @param _vaultFees Fees associated with vault operations
     * @param _bondingCurveConfig Configuration for bonding curves used in the protocol
     */
    function __MultiVaultCore_init(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _vaultFees,
        BondingCurveConfig memory _bondingCurveConfig
    )
        internal
        onlyInitializing
    {
        _setGeneralConfig(_generalConfig);
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
        vaultFees = _vaultFees;
        bondingCurveConfig = _bondingCurveConfig;
    }

    /* =================================================== */
    /*                 PROTOCOL GETTERS                    */
    /* =================================================== */

    /// @inheritdoc IMultiVaultCore
    function getGeneralConfig() external view returns (GeneralConfig memory) {
        return generalConfig;
    }

    /// @inheritdoc IMultiVaultCore
    function getAtomConfig() external view returns (AtomConfig memory) {
        return atomConfig;
    }

    /// @inheritdoc IMultiVaultCore
    function getTripleConfig() external view returns (TripleConfig memory) {
        return tripleConfig;
    }

    /// @inheritdoc IMultiVaultCore
    function getWalletConfig() external view returns (WalletConfig memory) {
        return walletConfig;
    }

    /// @inheritdoc IMultiVaultCore
    function getVaultFees() external view returns (VaultFees memory) {
        return vaultFees;
    }

    /// @inheritdoc IMultiVaultCore
    function getBondingCurveConfig() external view returns (BondingCurveConfig memory) {
        return bondingCurveConfig;
    }

    /* =================================================== */
    /*                      ATOM GETTERS                   */
    /* =================================================== */

    /// @inheritdoc IMultiVaultCore
    function atom(bytes32 atomId) external view returns (bytes memory data) {
        return _atoms[atomId];
    }

    /// @inheritdoc IMultiVaultCore
    function getAtom(bytes32 atomId) external view returns (bytes memory data) {
        return _getAtom(atomId);
    }

    /// @inheritdoc IMultiVaultCore
    function calculateAtomId(bytes memory data) external pure returns (bytes32 id) {
        return _calculateAtomId(data);
    }

    /// @inheritdoc IMultiVaultCore
    function getAtomCost() external view returns (uint256) {
        return _getAtomCost();
    }

    /// @inheritdoc IMultiVaultCore
    function isAtom(bytes32 atomId) external view returns (bool) {
        return _isAtom(atomId);
    }

    /* =================================================== */
    /*                    TRIPLE GETTERS                   */
    /* =================================================== */

    /// @inheritdoc IMultiVaultCore
    function triple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds = _triples[tripleId];
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @inheritdoc IMultiVaultCore
    function getTriple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds = _triples[tripleId];
        if (atomIds[0] == bytes32(0) && atomIds[1] == bytes32(0) && atomIds[2] == bytes32(0)) {
            revert MultiVaultCore_TripleDoesNotExist(tripleId);
        }
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @inheritdoc IMultiVaultCore
    function getTripleCost() external view returns (uint256) {
        return _getTripleCost();
    }

    /// @inheritdoc IMultiVaultCore
    function getCounterIdFromTripleId(bytes32 tripleId) external pure returns (bytes32) {
        return _calculateCounterTripleId(tripleId);
    }

    /// @inheritdoc IMultiVaultCore
    function getTripleIdFromCounterId(bytes32 counterId) external view returns (bytes32) {
        return _tripleIdFromCounterId[counterId];
    }

    /// @inheritdoc IMultiVaultCore
    function calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        external
        pure
        returns (bytes32)
    {
        return _calculateTripleId(subjectId, predicateId, objectId);
    }

    /// @inheritdoc IMultiVaultCore
    function calculateCounterTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        external
        pure
        returns (bytes32)
    {
        bytes32 tripleId = _calculateTripleId(subjectId, predicateId, objectId);
        return _calculateCounterTripleId(tripleId);
    }

    /// @inheritdoc IMultiVaultCore
    function isTriple(bytes32 termId) external view returns (bool) {
        return _isTriple[termId];
    }

    /// @inheritdoc IMultiVaultCore
    function isCounterTriple(bytes32 termId) external view returns (bool) {
        return _isCounterTriple(termId);
    }

    /// @inheritdoc IMultiVaultCore
    function getInverseTripleId(bytes32 tripleId) external view returns (bytes32) {
        return _getInverseTripleId(tripleId);
    }

    /// @inheritdoc IMultiVaultCore
    function getVaultType(bytes32 termId) external view returns (VaultType) {
        return _getVaultType(termId);
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    /// @dev Internal function to set and validate the general configuration struct
    function _setGeneralConfig(GeneralConfig memory _generalConfig) internal {
        if (_generalConfig.admin == address(0)) revert MultiVaultCore_InvalidAdmin();
        generalConfig = _generalConfig;
    }

    /// @dev Internal function to check if an atom exists
    /// @param atomId atom id to check
    function _isAtom(bytes32 atomId) internal view returns (bool) {
        return _atoms[atomId].length != 0;
    }

    /// @dev Internal function to calculate the atom id from the atom data
    /// @param data The data of the atom
    function _calculateAtomId(bytes memory data) internal pure returns (bytes32 id) {
        return keccak256(abi.encodePacked(ATOM_SALT, keccak256(data)));
    }

    /// @dev Internal function to calculate the triple id from the subject, predicate, and object atom ids
    /// @param subjectId The atom id of the subject
    /// @param predicateId The atom id of the predicate
    /// @param objectId The atom id of the object
    /// @return id The calculated triple id
    function _calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(TRIPLE_SALT, subjectId, predicateId, objectId));
    }

    /// @dev Internal function to calculate the counter triple id from the triple id
    /// @param tripleId The id of the triple
    /// @return id The calculated counter triple id
    function _calculateCounterTripleId(bytes32 tripleId) internal pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(COUNTER_SALT, tripleId)));
    }

    /// @dev Internal function to get the triple id from the given counter id
    /// @param termId term id of the counter triple
    /// @return tripleId the triple vault id from the given counter id
    function _isCounterTriple(bytes32 termId) internal view returns (bool) {
        return _tripleIdFromCounterId[termId] != bytes32(0);
    }

    /// @dev Internal function to get the atom data for a given atom id
    /// @dev If the atom does not exist, this function reverts
    /// @param atomId The id of the atom
    /// @return data The data of the atom
    function _getAtom(bytes32 atomId) internal view returns (bytes memory data) {
        bytes memory _data = _atoms[atomId];
        if (_data.length == 0) {
            revert MultiVaultCore_AtomDoesNotExist(atomId);
        }
        return _data;
    }

    /// @dev Internal function to get the underlying atom ids for a given triple id
    /// @dev If the triple does not exist, this function reverts
    /// @param tripleId term id of the triple
    /// @return The underlying atom ids of the triple
    function _getTriple(bytes32 tripleId) internal view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds = _triples[tripleId];
        if (atomIds[0] == bytes32(0) && atomIds[1] == bytes32(0) && atomIds[2] == bytes32(0)) {
            revert MultiVaultCore_TripleDoesNotExist(tripleId);
        }
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @dev Internal function to get the inverse triple id (counter or positive) for a given triple id
    /// @param tripleId The id of the triple or counter triple
    /// @return The inverse triple id
    function _getInverseTripleId(bytes32 tripleId) internal view returns (bytes32) {
        if (_isCounterTriple(tripleId)) {
            return _tripleIdFromCounterId[tripleId];
        } else {
            return _calculateCounterTripleId(tripleId);
        }
    }

    /// @dev Internal function to get the vault type for a given term ID
    /// @param termId The term ID to check
    function _getVaultType(bytes32 termId) internal view returns (VaultType) {
        bool _isVaultAtom = _isAtom(termId);
        bool _isVaultTriple = _isTriple[termId];
        bool _isVaultCounterTriple = _isCounterTriple(termId);

        if (!_isVaultAtom && !_isVaultTriple && !_isVaultCounterTriple) {
            revert MultiVaultCore_TermDoesNotExist(termId);
        }

        if (_isVaultAtom) return VaultType.ATOM;
        if (_isVaultCounterTriple) return VaultType.COUNTER_TRIPLE;
        return VaultType.TRIPLE;
    }

    /// @dev Internal function to get the static costs that go into creating an atom
    /// @return atomCost the static costs of creating an atom
    function _getAtomCost() internal view returns (uint256) {
        return atomConfig.atomCreationProtocolFee + generalConfig.minShare;
    }

    /// @dev Internal function to get the static costs that go into creating a triple
    /// @return tripleCost the static costs of creating a triple
    function _getTripleCost() internal view returns (uint256) {
        return tripleConfig.tripleCreationProtocolFee + tripleConfig.totalAtomDepositsOnTripleCreation
            + generalConfig.minShare * 2;
    }
}
