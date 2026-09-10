// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IMultiVault } from "src/interfaces/IMultiVault.sol";

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

    /**
     * @notice Deploys a new AtomWallet for the given atom ID
     * @param atomId The ID of the atom to deploy a wallet for
     * @return The address of the newly deployed AtomWallet
     */
    function deployAtomWallet(bytes32 atomId) external returns (address);

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Returns the MultiVault contract address
     * @return The MultiVault contract instance
     */
    function multiVault() external view returns (address);

    /**
     * @notice Computes the deterministic address of an AtomWallet for a given atom ID
     * @param atomId The ID of the atom
     * @return The computed address where the AtomWallet would be deployed
     */
    function computeAtomWalletAddr(bytes32 atomId) external view returns (address);
}
