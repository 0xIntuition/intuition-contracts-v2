// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
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
abstract contract MultiVaultCore is Initializable, IMultiVault, IMultiVaultCore {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice Salt used for counterfactual triples
    bytes32 public constant COUNTER_SALT = keccak256("COUNTER_SALT");

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
    /*                    HELPER FUNCTIONS                 */
    /* =================================================== */

    /// @dev Internal function to set and validate the general configuration struct
    function _setGeneralConfig(GeneralConfig memory _generalConfig) internal {
        if (_generalConfig.admin == address(0)) revert MultiVaultCore_InvalidAdmin();
        generalConfig = _generalConfig;
    }

    /* =================================================== */
    /*                  Protocol Getters                   */
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

    function getDefaultCurveId() public view returns (uint256) {
        return bondingCurveConfig.defaultCurveId;
    }

    /* =================================================== */
    /*                     Atom Getters                    */
    /* =================================================== */

    function atom(bytes32 atomId) public view returns (bytes memory data) {
        return _atoms[atomId];
    }

    function calculateAtomId(bytes memory data) public pure returns (bytes32 id) {
        return keccak256(abi.encodePacked(data));
    }

    function getAtom(bytes32 atomId) public view returns (bytes memory data) {
        bytes memory _data = _atoms[atomId];
        if (_data.length == 0) {
            revert MultiVaultCore_AtomDoesNotExist(atomId);
        }
        return _data;
    }

    /// @notice the total cost of creating an atom
    /// @return atomCost the cost of creating an atom
    function getAtomCost() public view returns (uint256) {
        return atomConfig.atomCreationProtocolFee + generalConfig.minShare;
    }

    function isAtom(bytes32 atomId) public view returns (bool) {
        return _atoms[atomId].length != 0;
    }

    /* =================================================== */
    /*                   Triple Getters                    */
    /* =================================================== */

    /// @notice returns the underlying atom ids for a given triple id
    /// @dev If the triple does not exist, instead of reverting, this function returns (bytes32(0), bytes32(0),
    /// bytes32(0))
    /// @param tripleId term id of the triple
    function triple(bytes32 tripleId) public view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds =
            isCounterTriple(tripleId) ? _triples[getTripleIdFromCounterId(tripleId)] : _triples[tripleId];
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @notice returns the cost of creating a triple
    /// @return tripleCost the cost of creating a triple
    function getTripleCost() public view returns (uint256) {
        return tripleConfig.tripleCreationProtocolFee + tripleConfig.totalAtomDepositsOnTripleCreation
            + generalConfig.minShare * 2;
    }

    /// @notice returns the underlying atom ids for a given triple id
    /// @dev If the triple does not exist, this function reverts
    /// @param tripleId term id of the triple
    function getTriple(bytes32 tripleId) public view returns (bytes32, bytes32, bytes32) {
        bytes32[3] memory atomIds = _triples[tripleId];
        if (atomIds[0] == bytes32(0) && atomIds[1] == bytes32(0) && atomIds[2] == bytes32(0)) {
            revert MultiVaultCore_TripleDoesNotExist(tripleId);
        }
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @notice returns the counter id from the given triple id
    /// @param tripleId term id of the triple
    /// @return counterId the counter vault id from the given triple id
    function getCounterIdFromTripleId(bytes32 tripleId) public pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(COUNTER_SALT, tripleId)));
    }

    /// @notice returns the triple id from the given counter id
    /// @param counterId term id of the counter triple
    /// @return tripleId the triple vault id from the given counter id
    function getTripleIdFromCounterId(bytes32 counterId) public view returns (bytes32) {
        return _tripleIdFromCounterId[counterId];
    }

    function calculateTripleId(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(subjectId, predicateId, objectId));
    }

    function calculateCounterTripleId(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    )
        public
        pure
        returns (bytes32)
    {
        bytes32 _tripleId = keccak256(abi.encodePacked(subjectId, predicateId, objectId));
        return bytes32(keccak256(abi.encodePacked(COUNTER_SALT, _tripleId)));
    }

    /// @notice returns whether the supplied vault id is a triple
    /// @param termId atom or triple (term) id to check
    /// @return bool whether the supplied term id is a triple
    function isTriple(bytes32 termId) public view returns (bool) {
        return isCounterTriple(termId) ? _isTriple[getTripleIdFromCounterId(termId)] : _isTriple[termId];
    }

    /// @notice returns whether the supplied vault id is a counter triple
    /// @param termId atom or triple (term) id to check
    /// @return bool whether the supplied term id is a counter triple
    function isCounterTriple(bytes32 termId) public view returns (bool) {
        return _tripleIdFromCounterId[termId] != bytes32(0);
    }

    /// @notice Get the vault type for a given term ID
    /// @param termId The term ID to check
    /// @return vaultType The type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)
    function getVaultType(bytes32 termId) public view returns (VaultType) {
        bool _isVaultAtom = isAtom(termId);
        bool _isVaultTriple = _isTriple[termId];
        bool _isVaultCounterTriple = isCounterTriple(termId);

        if (!_isVaultAtom && !_isVaultTriple && !_isVaultCounterTriple) {
            revert MultiVaultCore_TermDoesNotExist(termId);
        }

        if (_isVaultAtom) return VaultType.ATOM;
        if (_isVaultCounterTriple) return VaultType.COUNTER_TRIPLE;
        return VaultType.TRIPLE;
    }
}
