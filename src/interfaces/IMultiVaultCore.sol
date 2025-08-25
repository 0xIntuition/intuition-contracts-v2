// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IPermit2 } from "src/interfaces/IPermit2.sol";

/* =================================================== */
/*                   CONFIG STRUCTS                    */
/* =================================================== */

/// @dev General configuration struct
struct GeneralConfig {
    /// @dev Admin address
    address admin;
    /// @dev Protocol multisig address
    address protocolMultisig;
    /// @dev Fees are calculated by amount * (fee / feeDenominator);
    uint256 feeDenominator;
    /// @dev Address of the TrustBonding contract
    address trustBonding;
    /// @dev Minimum amount of assets that must be deposited into an atom/triple vault
    uint256 minDeposit;
    /// @dev Number of shares minted to zero address upon vault creation to initialize the vault
    uint256 minShare;
    /// @dev Maximum length of the atom data that can be passed when creating atom vaults
    uint256 atomDataMaxLength;
    /// @dev Decimal precision used for calculating share prices
    uint256 decimalPrecision;
}

/// @dev Atom configuration struct
struct AtomConfig {
    /// @dev Fee paid to the protocol when depositing vault shares for the atom vault upon creation
    uint256 atomCreationProtocolFee;
    /// @dev A portion of the deposit amount that is used to collect assets for the associated atom wallet
    uint256 atomWalletDepositFee;
}

/// @dev Triple configuration struct
struct TripleConfig {
    /// @dev Fee paid to the protocol when depositing vault shares for the triple vault upon creation
    uint256 tripleCreationProtocolFee;
    /// @dev Static fee going towards increasing the amount of assets in the underlying atom vaults
    uint256 totalAtomDepositsOnTripleCreation;
    /// @dev % of the Triple deposit amount that is used to purchase equity in the underlying atoms
    uint256 atomDepositFractionForTriple;
}

/// @dev Atom wallet configuration struct
struct WalletConfig {
    /// @dev Permit2
    IPermit2 permit2;
    /// @dev Entry Point contract address used for the erc4337 atom accounts
    address entryPoint;
    /// @dev AtomWallet Warden address, address that is the initial owner of all atom accounts
    address atomWarden;
    /// @dev UpgradeableBeacon contract address, which points to the AtomWallet implementation
    address atomWalletBeacon;
    /// @dev AtomWalletFactory contract address, which is used to create new atom wallets
    address atomWalletFactory;
}

/// @notice Vault fees struct
struct VaultFees {
    /// @dev entry fees are charged when depositing assets into the vault and they stay in the vault as assets
    ///      rather than going towards minting shares for the recipient
    uint256 entryFee;
    /// @dev exit fees are charged when redeeming shares from the vault and they stay in the vault as assets
    ///      rather than being sent to the receiver
    uint256 exitFee;
    /// @dev protocol fees are charged both when depositing assets and redeeming shares from the vault and
    ///      they are sent to the protocol multisig address, as defined in `generalConfig.protocolMultisig`
    uint256 protocolFee;
}

/// @dev Bonding curve configuration struct
struct BondingCurveConfig {
    /// @dev BondingCurveRegistry contract address - must not be changed after initialization
    address registry;
    /// @dev Default bonding curve ID to use for new terms - '1' is suggested for the linear curve
    uint256 defaultCurveId;
}

/// @title IMultiVaultCore
/// @author 0xIntuition
/// @notice Interface for the MultiVaultCore contract
interface IMultiVaultCore {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    function initialize(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _vaultFees,
        BondingCurveConfig memory _bondingCurveConfig
    )
        external;

    /* =================================================== */
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function getGeneralConfig() external view returns (GeneralConfig memory);

    function getAtomConfig() external view returns (AtomConfig memory);

    function getTripleConfig() external view returns (TripleConfig memory);

    function getWalletConfig() external view returns (WalletConfig memory);

    function getVaultFees() external view returns (VaultFees memory);

    function getBondingCurveConfig() external view returns (BondingCurveConfig memory);
}
