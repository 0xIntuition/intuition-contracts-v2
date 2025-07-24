// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IMultiVault} from "src/interfaces/IMultiVault.sol";

/**
 * @title IAtomWalletFactory
 * @author 0xIntuition
 * @notice The interface for the AtomWalletFactory contract
 */
interface IAtomWalletFactory {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when the atom wallet is deployed
    ///
    /// @param atomId atom id of the atom vault
    /// @param atomWallet address of the atom wallet associated with the atom vault
    event AtomWalletDeployed(bytes32 indexed atomId, address atomWallet);

    /* =================================================== */
    /*                   WRITE FUNCTIONS                   */
    /* =================================================== */

    function deployAtomWallet(bytes32 atomId) external returns (address);

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function multiVault() external view returns (IMultiVault);

    function computeAtomWalletAddr(bytes32 atomId) external view returns (address);
}
