// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title  ISatelliteEmissionsController
 * @author 0xIntuition
 * @notice Interface for the SatelliteEmissionsController that controls the release of TRUST tokens to the TrustBonding contract.
 */
interface ISatelliteEmissionsController {
    /**
     * @notice Transfers TRUST tokens to the specified recipient
     * @param recipient The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     */
    function transfer(address recipient, uint256 amount) external;
}
