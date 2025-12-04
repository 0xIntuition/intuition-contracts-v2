// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IMultiVaultCore } from "src/interfaces/IMultiVaultCore.sol";

/// -----------------------------------------------------------------------
/// MultiVault periphery / multicall PoC
/// -----------------------------------------------------------------------

contract MultiVaultPeriphery {
    IMultiVault public immutable multiVault;
    IMultiVaultCore public immutable multiVaultCore;

    /// @notice Emitted whenever this periphery creates an atom on behalf of a user.
    /// @param payer  msg.sender that funded this call (could be a relayer)
    /// @param creator logical/attributed creator (off-chain identity you care about)
    /// @param atomId id of the atom in MultiVault
    /// @param data   raw atom data
    event AtomCreatedFor(address indexed payer, address indexed creator, bytes32 indexed atomId, bytes data);

    /// @notice Emitted whenever this periphery creates a triple on behalf of a user.
    /// @param payer     msg.sender that funded this call (could be a relayer)
    /// @param creator   logical/attributed creator
    /// @param tripleId  id of the triple in MultiVault
    /// @param subjectId subject atom id
    /// @param predicateId predicate atom id
    /// @param objectId  object atom id
    event TripleCreatedFor(
        address indexed payer,
        address indexed creator,
        bytes32 indexed tripleId,
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    );

    /// @notice Emitted when the MultiVault address is updated.
    /// @param multiVault new MultiVault address
    event MultiVaultSet(address indexed multiVault);

    error MultiVaultPeriphery_InvalidAddress();
    error MultiVaultPeriphery_InvalidCreator();
    error MultiVaultPeriphery_InvalidMsgValue(uint256 expected, uint256 provided);
    error MultiVaultPeriphery_InvalidArrayLength();
    error MultiVaultPeriphery_InvalidPredicateOrObject();

    constructor(address multiVault_) {
        if (multiVault_ == address(0)) {
            revert MultiVaultPeriphery_InvalidAddress();
        }
        multiVault = IMultiVault(multiVault_);
        multiVaultCore = IMultiVaultCore(multiVault_);
        emit MultiVaultSet(multiVault_);
    }

    // --------------------------------------------------------------------
    // Helper: use msg.sender as creator
    // --------------------------------------------------------------------

    /// @notice Convenience wrapper: creator == msg.sender
    function createTripleWithAtoms(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData
    )
        external
        payable
        returns (bytes32 tripleId)
    {
        return createTripleWithAtomsFor(subjectData, predicateData, objectData, msg.sender);
    }

    /// @notice Convenience wrapper for list pattern; creator == msg.sender
    function batchCreateListTriples(
        bytes[] calldata subjectData,
        bytes32 predicateId,
        bytes32 objectId
    )
        external
        payable
        returns (bytes32[] memory subjectIds, bytes32[] memory tripleIds)
    {
        return batchCreateListTriplesFor(subjectData, predicateId, objectId, msg.sender);
    }

    // --------------------------------------------------------------------
    // Core example: 3 atoms (s, p, o) -> 1 triple
    // --------------------------------------------------------------------

    /// @notice Creates up to 3 atoms (subject / predicate / object) and then a triple between them,
    ///         charging only `atomCost` per new atom and `tripleCost` for the triple.
    ///
    /// msg.value **must be exactly**:
    ///     (#newAtoms * atomCost) + tripleCost
    ///
    /// This guarantees:
    /// - No extra ETH is left sitting on this periphery.
    /// - No extra shares are minted to this contract (we always pass exactly atomCost / tripleCost).
    function createTripleWithAtomsFor(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData,
        address creator
    )
        public
        payable
        returns (bytes32 tripleId)
    {
        if (creator == address(0)) revert MultiVaultPeriphery_InvalidCreator();

        uint256 atomCost = multiVaultCore.getAtomCost();
        uint256 tripleCost = multiVaultCore.getTripleCost();

        // 1) Precompute ids & determine which atoms are missing
        bytes32 subjectId = multiVaultCore.calculateAtomId(subjectData);
        bytes32 predicateId = multiVaultCore.calculateAtomId(predicateData);
        bytes32 objectId = multiVaultCore.calculateAtomId(objectData);

        bool subjectExists = multiVaultCore.isAtom(subjectId);
        bool predicateExists = multiVaultCore.isAtom(predicateId);
        bool objectExists = multiVaultCore.isAtom(objectId);

        uint256 newAtomsCount;
        if (!subjectExists) newAtomsCount++;
        if (!predicateExists) newAtomsCount++;
        if (!objectExists) newAtomsCount++;

        uint256 expectedValue = newAtomsCount * atomCost + tripleCost;
        if (msg.value != expectedValue) {
            revert MultiVaultPeriphery_InvalidMsgValue(expectedValue, msg.value);
        }

        // 2) Create missing atoms, each with exactly atomCost (no extra deposit)
        if (!subjectExists) {
            _createSingleAtom(subjectData, subjectId, creator, atomCost);
        }

        if (!predicateExists) {
            _createSingleAtom(predicateData, predicateId, creator, atomCost);
        }

        if (!objectExists) {
            _createSingleAtom(objectData, objectId, creator, atomCost);
        }

        // 3) Create the triple, paying exactly tripleCost
        bytes32[] memory subjects = new bytes32[](1);
        bytes32[] memory predicates = new bytes32[](1);
        bytes32[] memory objects = new bytes32[](1);
        uint256[] memory tripleAssets = new uint256[](1);

        subjects[0] = subjectId;
        predicates[0] = predicateId;
        objects[0] = objectId;
        tripleAssets[0] = tripleCost;

        bytes32[] memory tripleIds =
            multiVault.createTriples{ value: tripleCost }(subjects, predicates, objects, tripleAssets);

        tripleId = tripleIds[0];

        emit TripleCreatedFor(msg.sender, creator, tripleId, subjectId, predicateId, objectId);
    }

    // --------------------------------------------------------------------
    // List example: [X/Y/Z] [has tag] [bullish]
    //   - Array of subjects
    //   - Single fixed predicateId + objectId (atoms already existing)
    //   - Only subjects may need to be created
    // --------------------------------------------------------------------

    /// @notice Creates (if needed) subject atoms for each `subjectData[i]` and then creates a triple:
    ///         (subject[i], predicateId, objectId) for each i.
    ///
    /// Assumes `predicateId` and `objectId` are already existing atoms.
    ///
    /// msg.value **must be exactly**:
    ///     (#newSubjects * atomCost) + (subjectData.length * tripleCost)
    ///
    /// This matches the “list of [X/Y/Z] [has tag] [bullish]” use case.
    function batchCreateListTriplesFor(
        bytes[] calldata subjectData,
        bytes32 predicateId,
        bytes32 objectId,
        address creator
    )
        public
        payable
        returns (bytes32[] memory subjectIds, bytes32[] memory tripleIds)
    {
        if (creator == address(0)) revert MultiVaultPeriphery_InvalidCreator();
        uint256 length = subjectData.length;
        if (length == 0) revert MultiVaultPeriphery_InvalidArrayLength();

        // Make sure predicate and object atoms exist
        if (!multiVaultCore.isAtom(predicateId) || !multiVaultCore.isAtom(objectId)) {
            revert MultiVaultPeriphery_InvalidPredicateOrObject();
        }

        uint256 atomCost = multiVaultCore.getAtomCost();
        uint256 tripleCost = multiVaultCore.getTripleCost();

        subjectIds = new bytes32[](length);
        bool[] memory needsCreation = new bool[](length);
        uint256 newSubjectCount;

        // 1) Precompute subject ids and track which ones need creation
        for (uint256 i = 0; i < length;) {
            bytes32 id = multiVaultCore.calculateAtomId(subjectData[i]);
            subjectIds[i] = id;

            bool exists = multiVaultCore.isAtom(id);
            if (!exists) {
                needsCreation[i] = true;
                newSubjectCount++;
            }

            unchecked {
                ++i;
            }
        }

        uint256 expectedValue = newSubjectCount * atomCost + length * tripleCost;
        if (msg.value != expectedValue) {
            revert MultiVaultPeriphery_InvalidMsgValue(expectedValue, msg.value);
        }

        // 2) Create all missing subject atoms in a single MultiVault.createAtoms call
        if (newSubjectCount > 0) {
            bytes[] memory newSubjectData = new bytes[](newSubjectCount);
            uint256[] memory atomAssets = new uint256[](newSubjectCount);

            uint256 cursor;
            for (uint256 i = 0; i < length;) {
                if (needsCreation[i]) {
                    newSubjectData[cursor] = subjectData[i];
                    atomAssets[cursor] = atomCost;
                    cursor++;
                }
                unchecked {
                    ++i;
                }
            }

            multiVault.createAtoms{ value: newSubjectCount * atomCost }(newSubjectData, atomAssets);

            // Emit attribution events for each new subject atom
            cursor = 0;
            for (uint256 i = 0; i < length;) {
                if (needsCreation[i]) {
                    emit AtomCreatedFor(msg.sender, creator, subjectIds[i], subjectData[i]);
                    cursor++;
                }
                unchecked {
                    ++i;
                }
            }
        }

        // 3) Create triples for all subjects using the same predicateId and objectId
        bytes32[] memory subjectIdsForTriple = new bytes32[](length);
        bytes32[] memory predicateIds = new bytes32[](length);
        bytes32[] memory objectIds = new bytes32[](length);
        uint256[] memory tripleAssets = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            subjectIdsForTriple[i] = subjectIds[i];
            predicateIds[i] = predicateId;
            objectIds[i] = objectId;
            tripleAssets[i] = tripleCost;
            unchecked {
                ++i;
            }
        }

        tripleIds = multiVault.createTriples{ value: length * tripleCost }(
            subjectIdsForTriple, predicateIds, objectIds, tripleAssets
        );

        // Emit attribution events for each triple created
        for (uint256 i = 0; i < length;) {
            emit TripleCreatedFor(msg.sender, creator, tripleIds[i], subjectIds[i], predicateId, objectId);
            unchecked {
                ++i;
            }
        }
    }

    // --------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------

    /// @dev Create a single new atom with exactly `atomCost` and emit attribution event.
    function _createSingleAtom(bytes calldata atomData, bytes32 atomId, address creator, uint256 atomCost) internal {
        // Single-element arrays as MultiVault expects
        bytes[] memory dataArr = new bytes[](1);
        uint256[] memory assetArr = new uint256[](1);

        dataArr[0] = atomData;
        assetArr[0] = atomCost;

        multiVault.createAtoms{ value: atomCost }(dataArr, assetArr);

        emit AtomCreatedFor(msg.sender, creator, atomId, atomData);
    }
}
