// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { VaultType } from "src/interfaces/IMultiVault.sol";

/// @notice General configuration struct
struct GeneralConfig {
    /// @dev The admin address
    address admin;
    /// @dev The protocol multisig address
    address protocolMultisig;
    /// @dev The fee denominator used for fee calculations: fees are calculated as `amount * (fee / feeDenominator)`
    uint256 feeDenominator;
    /// @dev The address of the TrustBonding contract
    address trustBonding;
    /// @dev The minimum amount of assets that must be deposited into an atom or triple vault
    uint256 minDeposit;
    /// @dev The number of shares minted to the zero address upon vault creation to initialize the vault
    uint256 minShare;
    /// @dev The maximum length of atom data that can be passed when creating atom vaults
    uint256 atomDataMaxLength;
    /// @dev Threshold in terms of total shares in a default curve vault at which entry and exit fees start to be
    /// charged
    uint256 feeThreshold;
}

/// @notice Atom configuration struct
struct AtomConfig {
    /// @dev The fee paid to the protocol when depositing vault shares for atom vault creation
    uint256 atomCreationProtocolFee;
    /// @dev The portion of the deposit amount used to collect assets for the associated atom wallet
    uint256 atomWalletDepositFee;
}

/// @notice Triple configuration struct
struct TripleConfig {
    /// @dev The fee paid to the protocol when depositing vault shares for triple vault creation
    uint256 tripleCreationProtocolFee;
    /// @dev The percentage of the triple deposit amount used to purchase equity in the underlying atoms
    uint256 atomDepositFractionForTriple;
}

/// @notice Atom wallet configuration struct
struct WalletConfig {
    /// @dev The EntryPoint contract address used for ERC-4337 atom accounts
    address entryPoint;
    /// @dev The AtomWarden address, which is the initial owner of all atom accounts
    address atomWarden;
    /// @dev The UpgradeableBeacon contract address that points to the AtomWallet implementation
    address atomWalletBeacon;
    /// @dev The AtomWalletFactory contract address used to create new atom wallets
    address atomWalletFactory;
}

/// @notice Vault fees struct
struct VaultFees {
    /// @dev Entry fees charged when depositing assets into the vault; they remain in the vault as assets
    ///      rather than being used to mint shares for the recipient
    uint256 entryFee;
    /// @dev Exit fees charged when redeeming shares from the vault; they remain in the vault as assets
    ///      rather than being sent to the receiver
    uint256 exitFee;
    /// @dev Protocol fees charged when depositing assets and redeeming shares from the vault;
    ///      they are sent to the protocol multisig address as defined in `generalConfig.protocolMultisig`
    uint256 protocolFee;
}

/// @notice Bonding curve configuration struct
struct BondingCurveConfig {
    /// @dev The BondingCurveRegistry contract address
    address registry;
    /// @dev The default bonding curve ID to use for new terms (ID '1' is suggested for the linear curve)
    uint256 defaultCurveId;
}

/// @title IMultiVaultCore
/// @author 0xIntuition
/// @notice Interface for the MultiVaultCore contract
interface IMultiVaultCore {
    /* =================================================== */
    /*                    EVENTS                           */
    /* =================================================== */

    /**
     * @notice Emitted when the general configuration is updated
     * @param admin The new admin address
     * @param protocolMultisig The new protocol multisig address
     * @param feeDenominator The new fee denominator
     * @param trustBonding The new TrustBonding contract address
     * @param minDeposit The new minimum deposit amount
     * @param minShare The new minimum share amount
     * @param atomDataMaxLength The new maximum atom data length
     * @param feeThreshold The new fee threshold
     */
    event GeneralConfigUpdated(
        address indexed admin,
        address indexed protocolMultisig,
        uint256 feeDenominator,
        address indexed trustBonding,
        uint256 minDeposit,
        uint256 minShare,
        uint256 atomDataMaxLength,
        uint256 feeThreshold
    );

    /**
     * @notice Emitted when the atom configuration is updated
     * @param atomCreationProtocolFee The new atom creation protocol fee
     * @param atomWalletDepositFee The new atom wallet deposit fee
     */
    event AtomConfigUpdated(uint256 atomCreationProtocolFee, uint256 atomWalletDepositFee);

    /**
     * @notice Emitted when the triple configuration is updated
     * @param tripleCreationProtocolFee The new triple creation protocol fee
     * @param atomDepositFractionForTriple The new atom deposit fraction for triple
     */
    event TripleConfigUpdated(uint256 tripleCreationProtocolFee, uint256 atomDepositFractionForTriple);

    /**
     * @notice Emitted when the wallet configuration is updated
     * @param entryPoint The new EntryPoint contract address
     * @param atomWarden The new AtomWarden contract address
     * @param atomWalletBeacon The new AtomWallet beacon address
     * @param atomWalletFactory The new AtomWallet factory address
     */
    event WalletConfigUpdated(
        address indexed entryPoint,
        address indexed atomWarden,
        address indexed atomWalletBeacon,
        address atomWalletFactory
    );

    /**
     * @notice Emitted when the vault fees configuration is updated
     * @param entryFee The new entry fee
     * @param exitFee The new exit fee
     * @param protocolFee The new protocol fee
     */
    event VaultFeesUpdated(uint256 entryFee, uint256 exitFee, uint256 protocolFee);

    /**
     * @notice Emitted when the bonding curve configuration is updated
     * @param registry The new BondingCurveRegistry contract address
     * @param defaultCurveId The new default bonding curve ID
     */
    event BondingCurveConfigUpdated(address indexed registry, uint256 defaultCurveId);

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /**
     * @notice Initializes the MultiVaultCore contract with configuration parameters
     * @param _generalConfig General configuration settings including admin addresses and protocol parameters
     * @param _atomConfig Configuration specific to atom vault creation and fees
     * @param _tripleConfig Configuration specific to triple vault creation and deposits
     * @param _walletConfig Configuration for ERC-4337 atom wallet setup
     * @param _vaultFees Fee configuration for entry, exit, and protocol fees
     * @param _bondingCurveConfig Bonding curve registry and default curve settings
     */
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
    /*                      GETTERS                        */
    /* =================================================== */

    /**
     * @notice Retrieves the atom data for a given atom ID
     * @param atomId The ID of the atom to retrieve data for
     * @return The atom data for the specified atom ID
     */
    function atom(bytes32 atomId) external view returns (bytes memory);

    /// @notice Calculates the atom ID from the atom data
    /// @param data The data of the atom
    function calculateAtomId(bytes memory data) external pure returns (bytes32 id);

    /// @notice Calculates the counter triple ID from the subject, predicate, and object atom IDs
    /// @param subjectId The ID of the subject atom
    /// @param predicateId The ID of the predicate atom
    /// @param objectId The ID of the object atom
    /// @return id The calculated counter triple ID
    function calculateCounterTripleId(
        bytes32 subjectId,
        bytes32 predicateId,
        bytes32 objectId
    )
        external
        pure
        returns (bytes32);

    /// @notice Calculates the triple ID from the subject, predicate, and object atom IDs
    /// @param subjectId The ID of the subject atom
    /// @param predicateId The ID of the predicate atom
    /// @param objectId The ID of the object atom
    /// @return id The calculated triple ID
    function calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId) external pure returns (bytes32);

    /// @notice Returns the atom data for a given atom ID
    /// @dev If the atom does not exist, this function reverts
    function getAtom(bytes32 atomId) external view returns (bytes memory data);

    /**
     * @notice Returns the atom configuration settings
     * @return AtomConfig struct containing atom creation fees and wallet deposit fee settings
     */
    function getAtomConfig() external view returns (AtomConfig memory);

    /// @notice Returns the static costs required to create an atom
    /// @return atomCost The static costs of creating an atom
    function getAtomCost() external view returns (uint256);

    /**
     * @notice Returns the bonding curve configuration
     * @return BondingCurveConfig struct containing registry address and default curve ID
     */
    function getBondingCurveConfig() external view returns (BondingCurveConfig memory);

    /// @notice Returns the counter ID from the given triple ID
    /// @param tripleId The ID of the triple
    /// @return counterId The counter vault ID for the given triple ID
    function getCounterIdFromTripleId(bytes32 tripleId) external pure returns (bytes32);

    /**
     * @notice Returns the general configuration settings
     * @return GeneralConfig struct containing admin addresses, protocol parameters, and system limits
     */
    function getGeneralConfig() external view returns (GeneralConfig memory);

    /// @notice Returns the inverse triple ID (counter or positive) for a given triple ID
    /// @param tripleId The ID of the triple or counter triple
    /// @return The inverse triple ID
    function getInverseTripleId(bytes32 tripleId) external view returns (bytes32);

    /// @notice Returns the underlying atom IDs for a given triple ID
    /// @dev If the triple does not exist, this function reverts
    /// @param tripleId The ID of the triple
    function getTriple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32);

    /**
     * @notice Returns the triple configuration settings
     * @return TripleConfig struct containing triple creation fees and atom deposit configuration
     */
    function getTripleConfig() external view returns (TripleConfig memory);

    /// @notice Returns the static costs required to create a triple
    /// @return tripleCost The static costs of creating a triple
    function getTripleCost() external view returns (uint256);

    /// @notice Returns the triple ID from the given counter ID
    /// @param counterId The ID of the counter triple
    /// @return tripleId The triple vault ID for the given counter ID
    function getTripleIdFromCounterId(bytes32 counterId) external view returns (bytes32);

    /**
     * @notice Returns the vault fees configuration
     * @return VaultFees struct containing entry, exit, and protocol fee settings
     */
    function getVaultFees() external view returns (VaultFees memory);

    /// @notice Returns the vault type for a given term ID
    /// @param termId The term ID to check
    /// @return vaultType The type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)
    function getVaultType(bytes32 termId) external view returns (VaultType);

    /**
     * @notice Returns the wallet configuration settings for ERC-4337 compatibility
     * @return WalletConfig struct containing EntryPoint, AtomWarden, AtomWallet beacon and AtomWallet factory addresses
     */
    function getWalletConfig() external view returns (WalletConfig memory);

    /**
     * @notice Checks if a term ID corresponds to an atom vault
     * @param atomId The term ID to check
     * @return True if the term ID is an atom, false otherwise
     */
    function isAtom(bytes32 atomId) external view returns (bool);

    /// @notice Returns whether the supplied vault ID is a counter triple
    /// @param termId The ID of the term (atom or triple) to check
    /// @return Whether the supplied term ID is a counter triple
    function isCounterTriple(bytes32 termId) external view returns (bool);

    /**
     * @notice Checks if a term ID corresponds to a triple vault
     * @param id The term ID to check
     * @return True if the term ID is a triple, false otherwise
     */
    function isTriple(bytes32 id) external view returns (bool);

    /// @notice Returns the underlying atom IDs for a given triple ID
    /// @dev If the triple does not exist, this function returns (bytes32(0), bytes32(0), bytes32(0)) instead of
    /// reverting
    /// @param tripleId The ID of the triple
    function triple(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32);

    /**
     * @notice Returns the wallet configuration for ERC-4337 compatibility
     * @return entryPoint The EntryPoint contract address for ERC-4337
     * @return atomWarden The AtomWarden contract address
     * @return atomWalletBeacon The UpgradeableBeacon contract address for AtomWallets
     * @return atomWalletFactory The AtomWalletFactory contract address
     */
    function walletConfig()
        external
        view
        returns (address entryPoint, address atomWarden, address atomWalletBeacon, address atomWalletFactory);
}
