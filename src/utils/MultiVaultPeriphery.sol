// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { IMultiVaultCore } from "src/interfaces/IMultiVaultCore.sol";
import { IMultiVaultPeriphery } from "src/interfaces/IMultiVaultPeriphery.sol";

/**
 * @title MultiVaultPeriphery
 * @author 0xIntuition
 * @notice A periphery contract to facilitate and batch common MultiVault operations with proper attribution.
 */
contract MultiVaultPeriphery is
    IMultiVaultPeriphery,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
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

    /**
     * @notice Initializer for MultiVaultPeriphery
     * @param _admin Admin address for AccessControl
     * @param _multiVault MultiVault contract address
     */
    function initialize(address _admin, address _multiVault) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _setMultiVault(_multiVault);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /* =================================================== */
    /*                  ADMIN FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Sets the MultiVault contract address
     * @param _multiVault New MultiVault contract address
     */
    function setMultiVault(address _multiVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMultiVault(_multiVault);
    }

    /* =================================================== */
    /*                 EXTERNAL FUNCTIONS                  */
    /* =================================================== */

    /**
     * @notice Convenience wrapper for createTripleWithAtomsFor, using msg.sender as the creator
     * @param subjectData Raw subject atom data
     * @param predicateData Raw predicate atom data
     * @param objectData Raw object atom data
     * @return tripleId Created triple id
     */
    function createTripleWithAtoms(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData
    )
        external
        payable
        returns (bytes32 tripleId)
    {
        return _createTripleWithAtomsFor(subjectData, predicateData, objectData, msg.sender);
    }

    /**
     * @notice Creates up to 3 atoms (subject / predicate / object) and then a triple with them,
     *         charging only `atomCost` per new atom and `tripleCost` for the triple.
     *
     * msg.value must be at least:
     *     (newAtomsCount * atomCost) + tripleCost --> Any excess msg.value is refunded to msg.sender
     *
     * This guarantees:
     * - No extra ETH is left sitting on this periphery contract.
     * - No extra shares are minted to this contract (we always pass exactly atomCost / tripleCost).
     *
     * @param subjectData Raw subject atom data
     * @param predicateData Raw predicate atom data
     * @param objectData Raw object atom data
     * @param creator Logical/attributed creator address
     * @return tripleId Created triple id
     */
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
        return _createTripleWithAtomsFor(subjectData, predicateData, objectData, creator);
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

    /// @dev Internal function to create triple with atoms for a specified creator
    function _createTripleWithAtomsFor(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData,
        address creator
    )
        internal
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
        if (!subjectExists) ++newAtomsCount;
        if (!predicateExists) ++newAtomsCount;
        if (!objectExists) ++newAtomsCount;

        uint256 expectedValue = newAtomsCount * atomCost + tripleCost;

        // Check if the provided msg.value is enough to cover the costs
        if (msg.value < expectedValue) {
            revert MultiVaultPeriphery_InsufficientMsgValue(expectedValue, msg.value);
        }

        // Refund any excess value sent
        _refundExcessValue(msg.value - expectedValue);

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

    /// @dev Creates a single new atom with exactly `atomCost` and emits an appropriate attribution event
    function _createSingleAtom(bytes calldata atomData, bytes32 atomId, address creator, uint256 atomCost) internal {
        // Create single-element arrays as MultiVault expects
        bytes[] memory dataArr = new bytes[](1);
        uint256[] memory assetArr = new uint256[](1);

        dataArr[0] = atomData;
        assetArr[0] = atomCost;

        multiVault.createAtoms{ value: atomCost }(dataArr, assetArr);

        emit AtomCreatedFor(msg.sender, creator, atomId, atomData);
    }

    //// @dev Internal function to refund excess ETH value to msg.sender
    function _refundExcessValue(uint256 value) internal {
        if (value > 0) {
            (bool success,) = msg.sender.call{ value: value }("");
            require(success, "MultiVaultPeriphery: Refund failed");
        }
    }
}
