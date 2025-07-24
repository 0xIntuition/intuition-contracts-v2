// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPermit2} from "src/interfaces/IPermit2.sol";

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
    /// @dev Address of the Trust token (underlying asset)
    address trust;
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
    /// @dev Base URI for the ERC1155 metadata
    string baseURI;
    /// @dev If true, accrued protocol fees are routed to the TrustBonding contract for the pro-rata
    ///      distribution among the bonders. If false, accrued protocol fees are simply sent to the
    ///      protocol multisig address instead.
    bool protocolFeeDistributionEnabled;
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

/// @dev WrappedERC20 configuration struct
struct WrapperConfig {
    /// @dev UpgradeableBeacon contract address, which points to the WrappedERC20 implementation
    address wrappedERC20Beacon;
    /// @dev Address of the WrappedERC20Factory contract, used to create wrapped ERC20 tokens for each vault
    address wrappedERC20Factory;
}

/// @title IMultiVaultConfig
/// @author 0xIntuition
/// @notice Interface for the MultiVaultConfig contract
interface IMultiVaultConfig {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice emitted upon changing the admin
    /// @param newAdmin address of the new admin
    event AdminSet(address indexed newAdmin);

    /// @notice emitted upon changing the multiVault address
    /// @param newMultiVault address of the new multiVault
    event MultiVaultSet(address indexed newMultiVault);

    /// @notice emitted upon changing the protocol multisig
    /// @param newProtocolMultisig address of the new protocol multisig
    event ProtocolMultisigSet(address indexed newProtocolMultisig);

    /// @notice emitted upon changing the TrustBonding contract
    /// @param newTrustBonding address of the new TrustBonding contract
    event TrustBondingSet(address indexed newTrustBonding);

    /// @notice emitted upon changing the minimum deposit amount
    /// @param newMinDeposit new minimum deposit amount
    event MinDepositSet(uint256 indexed newMinDeposit);

    /// @notice emitted upon changing the minimum share amount
    /// @param newMinShare new minimum share amount
    event MinShareSet(uint256 indexed newMinShare);

    /// @notice emitted upon changing the atom data max length
    /// @param newAtomDataMaxLength new atom data max length
    event AtomDataMaxLengthSet(uint256 indexed newAtomDataMaxLength);

    /// @notice emitted upon changing the base URI
    /// @param newBaseURI new base URI
    event BaseURISet(string indexed newBaseURI);

    /// @notice emitted upon changing the protocol fee distribution setting
    /// @param enabled whether the protocol fee distribution in the TrustBonding contract is enabled or not
    event ProtocolFeeDistributionEnabledSet(bool enabled);

    /// @notice emitted upon changing the atom creation fee
    /// @param newAtomCreationProtocolFee new atom creation fee
    event AtomCreationProtocolFeeSet(uint256 indexed newAtomCreationProtocolFee);

    /// @notice emitted upon changing the atom wallet fee
    /// @param newAtomWalletDepositFee new atom wallet fee
    event AtomWalletDepositFeeSet(uint256 indexed newAtomWalletDepositFee);

    /// @notice emitted upon changing the triple creation fee
    /// @param newTripleCreationProtocolFee new triple creation fee
    event TripleCreationProtocolFeeSet(uint256 indexed newTripleCreationProtocolFee);

    /// @notice emitted upon changing the atom deposit fraction on triple creation
    /// @param newTotalAtomDepositsOnTripleCreation new atom deposit fraction on triple creation
    event TotalAtomDepositsOnTripleCreationSet(uint256 indexed newTotalAtomDepositsOnTripleCreation);

    /// @notice emitted upon changing the atom deposit fraction for triples
    /// @param newAtomDepositFractionForTriple new atom deposit fraction for triples
    event AtomDepositFractionForTripleSet(uint256 indexed newAtomDepositFractionForTriple);

    /// @notice emitted upon changing the entry fee
    /// @param newEntryFee new entry fee for the atom
    event EntryFeeSet(uint256 indexed newEntryFee);

    /// @notice emitted upon changing the exit fee
    /// @param newExitFee new exit fee for the atom
    event ExitFeeSet(uint256 indexed newExitFee);

    /// @notice emitted upon changing the protocol fee
    /// @param newProtocolFee new protocol fee for the atom
    event ProtocolFeeSet(uint256 indexed newProtocolFee);

    /// @notice emitted upon changing the atomWarden
    /// @param newAtomWarden address of the new atomWarden
    event AtomWardenSet(address indexed newAtomWarden);

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    function initialize(
        GeneralConfig memory _generalConfig,
        AtomConfig memory _atomConfig,
        TripleConfig memory _tripleConfig,
        WalletConfig memory _walletConfig,
        VaultFees memory _vaultFees,
        BondingCurveConfig memory _bondingCurveConfig,
        WrapperConfig memory _wrapperConfig,
        address _migrator,
        address _multiVault
    ) external;

    /* =================================================== */
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

    function pause() external;

    function unpause() external;

    function setMultiVault(address multiVault) external;

    function setAdmin(address admin) external;

    function setProtocolMultisig(address protocolMultisig) external;

    function setTrustBonding(address trustBonding) external;

    function setMinDeposit(uint256 minDeposit) external;

    function setMinShare(uint256 minShare) external;

    function setAtomDataMaxLength(uint256 atomDataMaxLength) external;

    function setBaseURI(string calldata baseURI) external;

    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external;

    function setAtomWalletDepositFee(uint256 atomWalletDepositFee) external;

    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external;

    function setTotalAtomDepositsOnTripleCreation(uint256 totalAtomDepositsOnTripleCreation) external;

    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple) external;

    function setEntryFee(uint256 entryFee) external;

    function setExitFee(uint256 exitFee) external;

    function setProtocolFee(uint256 protocolFee) external;

    function setAtomWarden(address atomWarden) external;

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    function getGeneralConfig() external view returns (GeneralConfig memory);

    function getAtomConfig() external view returns (AtomConfig memory);

    function getTripleConfig() external view returns (TripleConfig memory);

    function getWalletConfig() external view returns (WalletConfig memory);

    function getVaultFees() external view returns (VaultFees memory);

    function getBondingCurveConfig() external view returns (BondingCurveConfig memory);

    function getWrapperConfig() external view returns (WrapperConfig memory);
}
