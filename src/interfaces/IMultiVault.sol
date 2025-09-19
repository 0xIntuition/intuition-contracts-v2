// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IPermit2 } from "src/interfaces/IPermit2.sol";

/// @title IMultiVault
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IMultiVault {
    /* =================================================== */
    /*                          STRUCTS                    */
    /* =================================================== */

    /// @notice Vault state struct
    struct VaultState {
        /// @dev total assets in the vault
        uint256 totalAssets;
        /// @dev total shares in the vault
        uint256 totalShares;
        // address -> balanceOf, amount of shares an account has in a vault
        mapping(address account => uint256 balance) balanceOf;
    }

    /* =================================================== */
    /*                        ENUMS                        */
    /* =================================================== */

    /// @notice Enum for the approval types
    /// @dev NONE = 0b00, DEPOSIT = 0b01, REDEMPTION = 0b10, BOTH = 0b11
    enum ApprovalTypes {
        NONE,
        DEPOSIT,
        REDEMPTION,
        BOTH
    }

    /// @notice Enum for the vault types
    enum VaultType {
        ATOM,
        TRIPLE,
        COUNTER_TRIPLE
    }

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when a receiver changes the approval type for a sender
    ///
    /// @param sender address of the sender being approved/disapproved
    /// @param receiver address of the receiver granting/revoking approval
    /// @param approvalType the type of approval granted (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
    event ApprovalTypeUpdated(address indexed sender, address indexed receiver, ApprovalTypes approvalType);

    /// @notice emitted upon claiming the fees from the atom wallet
    ///
    /// @param termId atom id of the atom
    /// @param atomWalletOwner address of the atom wallet owner
    /// @param feesClaimed amount of fees claimed from the atom wallet
    event AtomWalletDepositFeesClaimed(
        bytes32 indexed termId, address indexed atomWalletOwner, uint256 indexed feesClaimed
    );

    /// @notice emitted upon adding the total utilization for the epoch
    ///
    /// @param epoch epoch in which the total utilization was added
    /// @param valueAdded value of the utilization added (in TRUST tokens)
    /// @param totalUtilization total utilization for the epoch after adding the value
    event TotalUtilizationAdded(uint256 indexed epoch, int256 indexed valueAdded, int256 indexed totalUtilization);

    /// @notice emitted upon adding the personal utilization to the user
    ///
    /// @param user address of the user
    /// @param epoch epoch in which the utilization was added
    /// @param valueAdded value of the utilization added (in TRUST tokens)
    /// @param personalUtilization personal utilization for the user after adding the value
    event PersonalUtilizationAdded(
        address indexed user, uint256 indexed epoch, int256 indexed valueAdded, int256 personalUtilization
    );

    /// @notice emitted upon removing the total utilization for the epoch
    ///
    /// @param epoch epoch in which the total utilization was removed
    /// @param valueRemoved value of the utilization removed (in TRUST tokens)
    /// @param totalUtilization total utilization for the epoch after removing the value
    event TotalUtilizationRemoved(uint256 indexed epoch, int256 indexed valueRemoved, int256 indexed totalUtilization);

    /// @notice emitted upon removing the personal utilization from the user
    ///
    /// @param user address of the user
    /// @param epoch epoch in which the utilization was removed
    /// @param valueRemoved value of the utilization removed (in TRUST tokens)
    /// @param personalUtilization personal utilization for the user after removing the value
    event PersonalUtilizationRemoved(
        address indexed user, uint256 indexed epoch, int256 indexed valueRemoved, int256 personalUtilization
    );

    /// @notice emitted upon depositing assets into a vault
    ///
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param termId term id of the vault
    /// @param curveId bonding curve id of the vault
    /// @param assets amount of assets deposited (gross assets deposited by the sender, including atomCost/tripleCost
    /// where applicable)
    /// @param assetsAfterFees amount of assets after all fees for the deposit are deducted
    /// @param shares amount of shares minted to the receiver
    /// @param totalShares balance of the user in the vault after the deposit
    /// @param vaultType type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    event Deposited(
        address indexed sender,
        address indexed receiver,
        bytes32 indexed termId,
        uint256 curveId,
        uint256 assets,
        uint256 assetsAfterFees,
        uint256 shares,
        uint256 totalShares,
        VaultType vaultType
    );

    /// @notice emitted upon redeeming shares from the vault
    ///
    /// @param termId term id of the vault
    /// @param curveId bonding curve id of the vault
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param shares amount of shares redeemed
    /// @param totalShares balance of the user in the vault after the redemption
    /// @param assets amount of assets withdrawn (net assets received by the receiver)
    /// @param fees amount of fees charged
    /// @param vaultType type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    event Redeemed(
        address indexed sender,
        address indexed receiver,
        bytes32 indexed termId,
        uint256 curveId,
        uint256 shares,
        uint256 totalShares,
        uint256 assets,
        uint256 fees,
        VaultType vaultType
    );

    /// @notice emitted after atom wallet deposit fee is collected
    /// @dev atom wallet deposit fee is charged when depositing assets into the atom vaults and it's used
    ///      to accumulate more claimable fees for the atom wallet owner of the given atom vault
    ///
    /// @param termId term id of the vault
    /// @param sender address of the sender
    /// @param amount amount of atom wallet deposit fee collected
    event AtomWalletDepositFeeCollected(bytes32 indexed termId, address indexed sender, uint256 amount);

    /// @notice emitted after protocol fee is accrued internally.
    ///
    /// @param epoch epoch in which the protocol fee was accrued (current epoch)
    /// @param amount amount of protocol fee accrued
    event ProtocolFeeAccrued(uint256 indexed epoch, uint256 amount);

    /// @notice emitted after protocol fee is transferred to the protocol multisig or the TrustBonding contract
    /// @dev protocol fee is charged both when depositing assets and redeeming shares from the vault, with the only
    ///      exception being if the contract is paused
    ///
    /// @param epoch epoch for which the protocol fee was transferred (previous epoch)
    /// @param destination address of the destination (protocol multisig or TrustBonding contract)
    /// @param amount amount of protocol fee transferred
    event ProtocolFeeTransferred(uint256 indexed epoch, address indexed destination, uint256 amount);

    /// @notice emitted when the share price is changed
    ///
    /// @param termId term id of the vault
    /// @param curveId bonding curve id of the vault
    /// @param sharePrice new share price
    /// @param totalAssets total assets in the vault after the change
    /// @param totalShares total shares in the vault after the change
    /// @param vaultType type of the vault (ATOM, TRIPLE, COUNTER_TRIPLE)
    event SharePriceChanged(
        bytes32 indexed termId,
        uint256 indexed curveId,
        uint256 sharePrice,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    );

    /// @notice emitted when the atom vault is created
    ///
    /// @param termId term id of the atom vault
    /// @param creator address of the creator
    /// @param atomWallet address of the atom wallet associated with the atom vault
    event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet);

    /// @notice emitted when the triple vault is created
    ///
    /// @param creator address of the creator
    /// @param termId term id of the triple vault
    /// @param subjectId atom id of the subject vault
    /// @param predicateId atom id of the predicate vault
    /// @param objectId atom id of the object vault
    event TripleCreated(
        address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    // function syncConfig() external;

    /**
     * @notice Creates multiple atom vaults with initial deposits
     * @param atomDatas Array of atom data (metadata) for each atom to be created
     * @param assets Array of asset amounts to deposit into each atom vault
     * @return Array of atom IDs (termIds) for the created atoms
     */
    function createAtoms(
        bytes[] calldata atomDatas,
        uint256[] calldata assets
    )
        external
        payable
        returns (bytes32[] memory);

    /**
     * @notice Creates multiple triple vaults with initial deposits
     * @param subjectIds Array of atom IDs to use as subjects
     * @param predicateIds Array of atom IDs to use as predicates
     * @param objectIds Array of atom IDs to use as objects
     * @param assets Array of asset amounts to deposit into each triple vault
     * @return Array of triple IDs (termIds) for the created triples
     */
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    )
        external
        payable
        returns (bytes32[] memory);

    /**
     * @notice Deposits assets into a vault and mints shares to the receiver
     * @param receiver Address to receive the minted shares
     * @param termId ID of the term (atom or triple) to deposit into
     * @param curveId Bonding curve ID to use for the deposit
     * @param minShares Minimum number of shares expected to be minted
     * @return Number of shares minted to the receiver
     */
    function deposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 minShares
    )
        external
        payable
        returns (uint256);

    /**
     * @notice Deposits assets into multiple vaults in a single transaction
     * @param receiver Address to receive the minted shares
     * @param termIds Array of term IDs to deposit into
     * @param curveIds Array of bonding curve IDs to use for each deposit
     * @param assets Array of asset amounts to deposit into each vault
     * @param minShares Array of minimum shares expected for each deposit
     * @return Array of shares minted for each deposit
     */
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    )
        external
        payable
        returns (uint256[] memory);

    /**
     * @notice Redeems shares from a vault and returns assets to the receiver
     * @param receiver Address to receive the redeemed assets
     * @param termId ID of the term (atom or triple) to redeem from
     * @param curveId Bonding curve ID to use for the redemption
     * @param shares Number of shares to redeem
     * @param minAssets Minimum number of assets expected to be returned
     * @return Number of assets returned to the receiver
     */
    function redeem(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        external
        returns (uint256);

    /**
     * @notice Redeems shares from multiple vaults in a single transaction
     * @param receiver Address to receive the redeemed assets
     * @param termIds Array of term IDs to redeem from
     * @param curveIds Array of bonding curve IDs to use for each redemption
     * @param shares Array of share amounts to redeem from each vault
     * @param minAssets Array of minimum assets expected for each redemption
     * @return Array of assets returned for each redemption
     */
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    )
        external
        returns (uint256[] memory);

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    /**
     * @notice Returns a user's utilization for a specific epoch
     * @param user The user address to query
     * @param epoch The epoch number to query
     * @return The user's utilization value (can be positive or negative)
     */
    function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256);

    /**
     * @notice Returns the total system utilization for a specific epoch
     * @param epoch The epoch number to query
     * @return The total utilization value for the epoch (can be positive or negative)
     */
    function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256);

    /**
     * @notice Returns the accumulated protocol fees for a specific epoch
     * @param epoch The epoch number to query
     * @return The accumulated protocol fees for the epoch
     */
    function accumulatedProtocolFees(uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns the AtomWarden contract address
     * @return The address of the AtomWarden contract
     */
    function getAtomWarden() external view returns (address);

    /**
     * @notice Claims accumulated deposit fees for an atom wallet owner
     * @param atomId The ID of the atom to claim fees for
     */
    function claimAtomWalletDepositFees(bytes32 atomId) external;

    /**
     * @notice Checks if a term (atom or triple) has been created
     * @param id The term ID to check
     * @return True if the term has been created, false otherwise
     */
    function isTermCreated(bytes32 id) external view returns (bool);

    /**
     * @notice Checks if a term ID corresponds to a triple vault
     * @param id The term ID to check
     * @return True if the term ID is a triple, false otherwise
     */
    function isTriple(bytes32 id) external view returns (bool);

    /**
     * @notice Returns the wallet configuration for ERC-4337 compatibility
     * @return permit2 The Permit2 contract instance
     * @return entryPoint The EntryPoint contract address for ERC-4337
     * @return atomWarden The AtomWarden contract address
     * @return atomWalletBeacon The UpgradeableBeacon contract address for AtomWallets
     * @return atomWalletFactory The AtomWalletFactory contract address
     */
    function walletConfig()
        external
        view
        returns (
            IPermit2 permit2,
            address entryPoint,
            address atomWarden,
            address atomWalletBeacon,
            address atomWalletFactory
        );
}
