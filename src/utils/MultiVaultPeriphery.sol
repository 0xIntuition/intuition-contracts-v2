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
    function createTripleWithAtoms(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData
    )
        external
        payable
        nonReentrant
        returns (bytes32 tripleId)
    {
        return _createTripleWithAtomsFor(subjectData, predicateData, objectData, msg.sender);
    }

    /// @inheritdoc IMultiVaultPeriphery
    function createTripleWithAtomsFor(
        bytes calldata subjectData,
        bytes calldata predicateData,
        bytes calldata objectData,
        address creator
    )
        external
        payable
        nonReentrant
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

        uint256 newAtomsCount;

        // Count only the distinct new atoms
        if (!multiVaultCore.isAtom(subjectId)) {
            ++newAtomsCount;
        }

        if (predicateId != subjectId) {
            if (!multiVaultCore.isAtom(predicateId)) {
                ++newAtomsCount;
            }
        }

        if (objectId != subjectId && objectId != predicateId) {
            if (!multiVaultCore.isAtom(objectId)) {
                ++newAtomsCount;
            }
        }

        uint256 expectedValue = newAtomsCount * atomCost + tripleCost;

        // Check if the provided msg.value is enough to cover the costs
        if (msg.value < expectedValue) {
            revert MultiVaultPeriphery_InsufficientMsgValue(expectedValue, msg.value);
        }

        // Refund any excess value sent
        _refundExcessValue(msg.value - expectedValue);

        // 2) Create missing atoms, each with exactly atomCost (no extra deposit)
        if (!multiVaultCore.isAtom(subjectId)) {
            _createSingleAtom(subjectData, subjectId, creator, atomCost);
        }

        if (predicateId != subjectId && !multiVaultCore.isAtom(predicateId)) {
            _createSingleAtom(predicateData, predicateId, creator, atomCost);
        }

        if (objectId != subjectId && objectId != predicateId && !multiVaultCore.isAtom(objectId)) {
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
