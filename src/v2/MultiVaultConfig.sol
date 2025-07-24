// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Errors} from "src/libraries/Errors.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {
    IMultiVaultConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig,
    WrapperConfig
} from "src/interfaces/IMultiVaultConfig.sol";

contract MultiVaultConfig is IMultiVaultConfig, Initializable, AccessControlUpgradeable, PausableUpgradeable {
    /* =================================================== */
    /*                  CONSTANTS                          */
    /* =================================================== */

    /// @notice Maximum fees (in basis points) that can be set by the admin
    uint256 public constant MAX_ENTRY_FEE = 1000;
    uint256 public constant MAX_EXIT_FEE = 1000; // 10%
    uint256 public constant MAX_PROTOCOL_FEE = 1000; // 10%
    uint256 public constant MAX_ATOM_WALLET_DEPOSIT_FEE = 1000; // 10%
    uint256 public constant MAX_ATOM_DEPOSIT_FRACTION_FOR_TRIPLE = 9000; // 90%

    /// @notice Role used for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role used for the timelocked operations
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice Role for the state migration
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    /// @notice Configuration structs
    GeneralConfig public generalConfig;
    AtomConfig public atomConfig;
    TripleConfig public tripleConfig;
    WalletConfig public walletConfig;
    VaultFees public vaultFees;
    BondingCurveConfig public bondingCurveConfig;
    WrapperConfig public wrapperConfig;

    /// @notice Address of the multi vault
    IMultiVault public multiVault;

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

    /// @notice Initializes the MultiVault contract
    /// @dev This function is called only once (during the contract initialization)
    ///
    /// @param _generalConfig General configuration struct
    /// @param _atomConfig Atom configuration struct
    /// @param _tripleConfig Triple configuration struct
    /// @param _walletConfig Wallet configuration struct
    /// @param _vaultFees Vault fees struct
    /// @param _bondingCurveConfig Bonding curve configuration struct
    /// @param _migrator address of the migrator (will perform the state migration)
    /// @param _multiVault address of the MultiVault contract
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
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();

        if (_multiVault == address(0) || _migrator == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _generalConfig.admin);
        _grantRole(PAUSER_ROLE, _generalConfig.admin);
        _grantRole(MIGRATOR_ROLE, _migrator);

        generalConfig = _generalConfig;
        atomConfig = _atomConfig;
        tripleConfig = _tripleConfig;
        walletConfig = _walletConfig;
        vaultFees = _vaultFees;
        bondingCurveConfig = _bondingCurveConfig;
        wrapperConfig = _wrapperConfig;
        multiVault = IMultiVault(_multiVault);
    }

    /* =================================================== */
    /*              ACCESS-RESTRICTED FUNCTIONS            */
    /* =================================================== */

    /// @dev pauses the pausable contract methods
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @dev unpauses the pausable contract methods
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @dev set the address of the MultiVault contract
    /// @param _multiVault address of the new MultiVault contract
    function setMultiVault(address _multiVault) external onlyRole(TIMELOCK_ROLE) {
        if (_multiVault == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        multiVault = IMultiVault(_multiVault);

        multiVault.syncConfig();

        emit MultiVaultSet(_multiVault);
    }

    /// @dev set admin to mint the ghost shares to
    /// @param admin address of the new admin
    function setAdmin(address admin) external onlyRole(TIMELOCK_ROLE) {
        if (admin == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        generalConfig.admin = admin;

        multiVault.syncConfig();

        emit AdminSet(admin);
    }

    /// @dev set protocol multisig
    /// @param protocolMultisig address of the new protocol multisig
    function setProtocolMultisig(address protocolMultisig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (protocolMultisig == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        generalConfig.protocolMultisig = protocolMultisig;

        multiVault.syncConfig();

        emit ProtocolMultisigSet(protocolMultisig);
    }

    /// @dev set TrustBonding address
    /// @param trustBonding address of the new TrustBonding contract
    function setTrustBonding(address trustBonding) external onlyRole(TIMELOCK_ROLE) {
        if (trustBonding == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        generalConfig.trustBonding = trustBonding;

        multiVault.syncConfig();

        emit TrustBondingSet(trustBonding);
    }

    /// @dev sets the minimum deposit amount for atoms and triples
    /// @param minDeposit new minimum deposit amount
    function setMinDeposit(uint256 minDeposit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (minDeposit == 0) {
            revert Errors.MultiVaultConfig_ZeroValue();
        }

        generalConfig.minDeposit = minDeposit;

        multiVault.syncConfig();

        emit MinDepositSet(minDeposit);
    }

    /// @dev sets the minimum share amount for atoms and triples
    /// @param minShare new minimum share amount
    function setMinShare(uint256 minShare) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (minShare == 0) {
            revert Errors.MultiVaultConfig_ZeroValue();
        }

        generalConfig.minShare = minShare;

        multiVault.syncConfig();

        emit MinShareSet(minShare);
    }

    /// @dev sets the atom data max length
    /// @param atomDataMaxLength new atom data max length
    function setAtomDataMaxLength(uint256 atomDataMaxLength) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (atomDataMaxLength == 0) {
            revert Errors.MultiVaultConfig_ZeroValue();
        }

        generalConfig.atomDataMaxLength = atomDataMaxLength;

        multiVault.syncConfig();

        emit AtomDataMaxLengthSet(atomDataMaxLength);
    }

    /// @dev sets the base URI for the ERC1155 metadata
    /// @param baseURI new base URI
    function setBaseURI(string calldata baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        generalConfig.baseURI = baseURI;

        multiVault.syncConfig();

        emit BaseURISet(baseURI);
    }

    /// @dev Sets whether the protocol fee distribution is enabled or not
    /// @param isEnabled true if the protocol fee distribution is enabled, false otherwise
    function setIsProtocolFeeDistributionEnabled(bool isEnabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        generalConfig.protocolFeeDistributionEnabled = isEnabled;

        multiVault.syncConfig();

        emit ProtocolFeeDistributionEnabledSet(isEnabled);
    }

    /// @dev sets the atom creation fee
    /// @param atomCreationProtocolFee new atom creation fee
    function setAtomCreationProtocolFee(uint256 atomCreationProtocolFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        atomConfig.atomCreationProtocolFee = atomCreationProtocolFee;

        multiVault.syncConfig();

        emit AtomCreationProtocolFeeSet(atomCreationProtocolFee);
    }

    /// @dev sets the atom wallet fee
    /// @param atomWalletDepositFee new atom wallet fee
    function setAtomWalletDepositFee(uint256 atomWalletDepositFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (atomWalletDepositFee > MAX_ATOM_WALLET_DEPOSIT_FEE) {
            revert Errors.MultiVaultConfig_InvalidAtomWalletDepositFee();
        }

        atomConfig.atomWalletDepositFee = atomWalletDepositFee;

        multiVault.syncConfig();

        emit AtomWalletDepositFeeSet(atomWalletDepositFee);
    }

    /// @dev sets fee charged in wei when creating a triple to protocol multisig
    /// @param tripleCreationProtocolFee new fee in wei
    function setTripleCreationProtocolFee(uint256 tripleCreationProtocolFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tripleConfig.tripleCreationProtocolFee = tripleCreationProtocolFee;

        multiVault.syncConfig();

        emit TripleCreationProtocolFeeSet(tripleCreationProtocolFee);
    }

    /// @dev sets the atom deposit fraction on triple creation used to increase the amount of assets
    ///      in the underlying atom vaults on triple creation
    /// @param totalAtomDepositsOnTripleCreation new atom deposit fraction on triple creation
    function setTotalAtomDepositsOnTripleCreation(uint256 totalAtomDepositsOnTripleCreation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tripleConfig.totalAtomDepositsOnTripleCreation = totalAtomDepositsOnTripleCreation;

        multiVault.syncConfig();

        emit TotalAtomDepositsOnTripleCreationSet(totalAtomDepositsOnTripleCreation);
    }

    /// @dev sets the atom deposit fraction percentage for atoms used in triples
    ///      (number to be divided by `generalConfig.feeDenominator`)
    /// @param atomDepositFractionForTriple new atom deposit fraction percentage
    function setAtomDepositFractionForTriple(uint256 atomDepositFractionForTriple)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (atomDepositFractionForTriple > MAX_ATOM_DEPOSIT_FRACTION_FOR_TRIPLE) {
            revert Errors.MultiVaultConfig_InvalidAtomDepositFractionForTriple();
        }

        tripleConfig.atomDepositFractionForTriple = atomDepositFractionForTriple;

        multiVault.syncConfig();

        emit AtomDepositFractionForTripleSet(atomDepositFractionForTriple);
    }

    /// @dev sets the atomWarden address
    /// @param atomWarden address of the new atomWarden
    function setAtomWarden(address atomWarden) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (atomWarden == address(0)) {
            revert Errors.MultiVaultConfig_ZeroAddress();
        }

        walletConfig.atomWarden = atomWarden;

        multiVault.syncConfig();

        emit AtomWardenSet(atomWarden);
    }

    /// @dev sets the entry fee charged to the user when depositing assets into the vault
    /// @param entryFee entry fee to set
    function setEntryFee(uint256 entryFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (entryFee > MAX_ENTRY_FEE) {
            revert Errors.MultiVaultConfig_InvalidEntryFee();
        }

        vaultFees.entryFee = entryFee;

        multiVault.syncConfig();

        emit EntryFeeSet(entryFee);
    }

    /// @dev sets the exit fee charged to the user when redeeming assets from the vault
    /// @param exitFee exit fee to set
    function setExitFee(uint256 exitFee) external onlyRole(TIMELOCK_ROLE) {
        if (exitFee > MAX_EXIT_FEE) {
            revert Errors.MultiVaultConfig_InvalidExitFee();
        }

        vaultFees.exitFee = exitFee;

        multiVault.syncConfig();

        emit ExitFeeSet(exitFee);
    }

    /// @dev sets the protocol fee charged on all deposits and withdrawals
    /// @param protocolFee protocol fee to set
    function setProtocolFee(uint256 protocolFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (protocolFee > MAX_PROTOCOL_FEE) {
            revert Errors.MultiVaultConfig_InvalidProtocolFee();
        }

        vaultFees.protocolFee = protocolFee;

        multiVault.syncConfig();

        emit ProtocolFeeSet(protocolFee);
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /// @notice returns the general configuration struct
    function getGeneralConfig() external view returns (GeneralConfig memory) {
        return generalConfig;
    }

    /// @notice returns the atom configuration struct
    function getAtomConfig() external view returns (AtomConfig memory) {
        return atomConfig;
    }

    /// @notice returns the triple configuration struct
    function getTripleConfig() external view returns (TripleConfig memory) {
        return tripleConfig;
    }

    /// @notice returns the wallet configuration struct
    function getWalletConfig() external view returns (WalletConfig memory) {
        return walletConfig;
    }

    /// @notice returns the vault fees struct
    function getVaultFees() external view returns (VaultFees memory) {
        return vaultFees;
    }

    /// @notice returns the bonding curve configuration struct
    function getBondingCurveConfig() external view returns (BondingCurveConfig memory) {
        return bondingCurveConfig;
    }

    /// @notice returns the wrapper configuration struct
    function getWrapperConfig() external view returns (WrapperConfig memory) {
        return wrapperConfig;
    }
}
