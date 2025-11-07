// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { AutomationCompatibleInterface } from "src/interfaces/external/chainlink/AutomationCompatibleInterface.sol";
import { IBaseEmissionsController } from "src/interfaces/IBaseEmissionsController.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";

/**
 * @title EmissionsAutomationAdapter
 * @author 0xIntuition
 * @notice A contract that integrates with keepers to automate the minting and bridging of emissions
 */
contract EmissionsAutomationAdapter is AccessControl, ReentrancyGuard, AutomationCompatibleInterface {
    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @notice Role identifier for upkeep operations
    bytes32 public constant UPKEEP_ROLE = keccak256("UPKEEP_ROLE");

    /* =================================================== */
    /*                    IMMUTABLES                       */
    /* =================================================== */

    /// @notice Reference to the BaseEmissionsController contract
    IBaseEmissionsController public immutable baseEmissionsController;

    /* =================================================== */
    /*                     EVENTS                          */
    /* =================================================== */

    /**
     * @notice Event emitted when emissions are minted and bridged via automation
     * @param epoch The epoch for which emissions were minted
     * @param amount The amount of emissions minted and bridged
     */
    event AutomationMintedAndBridged(uint256 epoch, uint256 amount);

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    /// @notice Error for invalid address inputs
    error EmissionsAutomationAdapter_InvalidAddress();

    /* =================================================== */
    /*                 CONSTRUCTOR                         */
    /* =================================================== */

    /**
     * @notice Constructor for the EmissionsAutomationAdapter
     * @param _baseEmissionsController The address of the BaseEmissionsController contract
     */
    constructor(address _admin, address _baseEmissionsController) {
        if (_admin == address(0)) revert EmissionsAutomationAdapter_InvalidAddress();
        if (_baseEmissionsController == address(0)) revert EmissionsAutomationAdapter_InvalidAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        baseEmissionsController = IBaseEmissionsController(_baseEmissionsController);
    }

    /* =================================================== */
    /*                 EXTERNAL FUNCTIONS                  */
    /* =================================================== */

    /**
     * @notice A function for designated keepers to call to mint and bridge emissions for the current epoch if needed
     * @dev If minting is not needed, the function exits early (no-op)
     */
    function mintAndBridgeCurrentEpochIfNeeded() external nonReentrant onlyRole(UPKEEP_ROLE) {
        _mintAndBridgeCurrentEpochIfNeeded();
    }

    /// @inheritdoc AutomationCompatibleInterface
    function performUpkeep(
        bytes calldata /* performData */
    )
        external
        override
        nonReentrant
        onlyRole(UPKEEP_ROLE)
    {
        _mintAndBridgeCurrentEpochIfNeeded();
    }

    /* =================================================== */
    /*                 VIEW FUNCTIONS                  */
    /* =================================================== */

    /**
     * @notice Function to check if minting is needed for the current epoch
     * @return bool True if minting is needed, false otherwise
     */
    function shouldMint() external view returns (bool) {
        return _shouldMint();
    }

    /// @inheritdoc AutomationCompatibleInterface
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = _shouldMint();
        performData = bytes("");
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    /// @notice Internal function to mint and bridge emissions for the current epoch if needed
    function _mintAndBridgeCurrentEpochIfNeeded() internal {
        if (!_shouldMint()) return;
        baseEmissionsController.mintAndBridgeCurrentEpoch();

        uint256 currentEpoch = ICoreEmissionsController(address(baseEmissionsController)).getCurrentEpoch();
        emit AutomationMintedAndBridged(currentEpoch, baseEmissionsController.getEpochMintedAmount(currentEpoch));
    }

    /// @notice Internal function to determine if minting is needed for the current epoch
    function _shouldMint() internal view returns (bool) {
        uint256 currentEpoch = ICoreEmissionsController(address(baseEmissionsController)).getCurrentEpoch();
        return baseEmissionsController.getEpochMintedAmount(currentEpoch) == 0;
    }
}
