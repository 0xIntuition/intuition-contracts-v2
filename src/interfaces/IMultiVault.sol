// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {
    BondingCurveConfig,
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees
} from "src/interfaces/IMultiVaultCore.sol";

/* =================================================== */
/*                          STRUCTS                    */
/* =================================================== */

/// @notice Vault state struct
struct VaultState {
    /// @dev Total assets held in the vault
    uint256 totalAssets;
    /// @dev Total shares issued by the vault
    uint256 totalShares;
    /// @dev Mapping of account addresses to their share balances in the vault
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

/// @title IMultiVault
/// @author 0xIntuition
/// @notice Interface for managing many ERC4626 style vaults in a single contract
interface IMultiVault {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when a receiver changes the approval type for a sender
    ///
    /// @param sender The address of the sender being approved or disapproved
    /// @param receiver The address of the receiver granting or revoking approval
    /// @param approvalType The type of approval granted (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
    event ApprovalTypeUpdated(address indexed sender, address indexed receiver, ApprovalTypes approvalType);

    /// @notice Emitted when atom wallet deposit fees are claimed
    ///
    /// @param termId The ID of the atom
    /// @param atomWalletOwner The address of the atom wallet owner
    /// @param feesClaimed The amount of fees claimed from the atom wallet
    event AtomWalletDepositFeesClaimed(
        bytes32 indexed termId, address indexed atomWalletOwner, uint256 indexed feesClaimed
    );

    /// @notice Emitted when total utilization is added for an epoch
    ///
    /// @param epoch The epoch in which the total utilization was added
    /// @param valueAdded The value of the utilization added (in TRUST tokens)
    /// @param totalUtilization The total utilization for the epoch after adding the value
    event TotalUtilizationAdded(uint256 indexed epoch, int256 indexed valueAdded, int256 indexed totalUtilization);

    /// @notice Emitted when personal utilization is added for a user
    ///
    /// @param user The address of the user
    /// @param epoch The epoch in which the utilization was added
    /// @param valueAdded The value of the utilization added (in TRUST tokens)
    /// @param personalUtilization The personal utilization for the user after adding the value
    event PersonalUtilizationAdded(
        address indexed user, uint256 indexed epoch, int256 indexed valueAdded, int256 personalUtilization
    );

    /// @notice Emitted when total utilization is removed for an epoch
    ///
    /// @param epoch The epoch in which the total utilization was removed
    /// @param valueRemoved The value of the utilization removed (in TRUST tokens)
    /// @param totalUtilization The total utilization for the epoch after removing the value
    event TotalUtilizationRemoved(uint256 indexed epoch, int256 indexed valueRemoved, int256 indexed totalUtilization);

    /// @notice Emitted when personal utilization is removed for a user
    ///
    /// @param user The address of the user
    /// @param epoch The epoch in which the utilization was removed
    /// @param valueRemoved The value of the utilization removed (in TRUST tokens)
    /// @param personalUtilization The personal utilization for the user after removing the value
    event PersonalUtilizationRemoved(
        address indexed user, uint256 indexed epoch, int256 indexed valueRemoved, int256 personalUtilization
    );

    /// @notice Emitted when assets are deposited into a vault
    ///
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param assets The amount of assets deposited (gross assets deposited by the sender, including atomCost or
    /// tripleCost where applicable)
    /// @param assetsAfterFees The amount of assets after all deposit fees are deducted
    /// @param shares The amount of shares minted to the receiver
    /// @param totalShares The user's share balance in the vault after the deposit
    /// @param vaultType The type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)
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

    /// @notice Emitted when shares are redeemed from a vault
    ///
    /// @param sender The address of the sender
    /// @param receiver The address of the receiver
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param shares The amount of shares redeemed
    /// @param totalShares The user's share balance in the vault after the redemption
    /// @param assets The amount of assets withdrawn (net assets received by the receiver)
    /// @param fees The amount of fees charged
    /// @param vaultType The type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)
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

    /// @notice Emitted when an atom wallet deposit fee is collected
    /// @dev The atom wallet deposit fee is charged when depositing assets into atom vaults and accumulates
    ///      as claimable fees for the atom wallet owner of the corresponding atom vault
    ///
    /// @param termId The ID of the term (atom)
    /// @param sender The address of the sender
    /// @param amount The amount of atom wallet deposit fee collected
    event AtomWalletDepositFeeCollected(bytes32 indexed termId, address indexed sender, uint256 amount);

    /// @notice Emitted when a protocol fee is accrued internally
    ///
    /// @param epoch The epoch in which the protocol fee was accrued (current epoch)
    /// @param sender The address of the user who paid the protocol fee
    /// @param amount The amount of protocol fee accrued
    event ProtocolFeeAccrued(uint256 indexed epoch, address indexed sender, uint256 amount);

    /// @notice Emitted when a protocol fee is transferred to the protocol multisig or the TrustBonding contract
    /// @dev The protocol fee is charged when depositing assets and redeeming shares from the vault, except
    ///      when the contract is paused
    ///
    /// @param epoch The epoch for which the protocol fee was transferred (previous epoch)
    /// @param destination The address of the destination (protocol multisig or TrustBonding contract)
    /// @param amount The amount of protocol fee transferred
    event ProtocolFeeTransferred(uint256 indexed epoch, address indexed destination, uint256 amount);

    /// @notice Emitted when the share price changes
    ///
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param sharePrice The new share price
    /// @param totalAssets The total assets in the vault after the change
    /// @param totalShares The total shares in the vault after the change
    /// @param vaultType The type of vault (ATOM, TRIPLE, or COUNTER_TRIPLE)
    event SharePriceChanged(
        bytes32 indexed termId,
        uint256 indexed curveId,
        uint256 sharePrice,
        uint256 totalAssets,
        uint256 totalShares,
        VaultType vaultType
    );

    /// @notice Emitted when an atom vault is created
    ///
    /// @param creator The address of the creator
    /// @param termId The ID of the atom vault
    /// @param atomData The data associated with the atom
    /// @param atomWallet The address of the atom wallet associated with the atom vault
    event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet);

    /// @notice Emitted when a triple vault is created
    ///
    /// @param creator The address of the creator
    /// @param termId The ID of the triple vault
    /// @param subjectId The ID of the subject atom
    /// @param predicateId The ID of the predicate atom
    /// @param objectId The ID of the object atom
    event TripleCreated(
        address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );

    /* =================================================== */
    /*                        GETTERS                      */
    /* =================================================== */

    /// @notice Returns the amount of assets deposited into underlying atoms when depositing into a triple vault
    function atomDepositFractionAmount(uint256 assets) external view returns (uint256);

    /**
     * @notice Claims accumulated deposit fees for an atom wallet owner
     * @param atomId The ID of the atom to claim fees for
     */
    function claimAtomWalletDepositFees(bytes32 atomId) external;

    /**
     * @notice Computes the deterministic address of an atom wallet for a given atom ID
     * @param atomId The ID of the atom to compute the wallet address for
     * @return The computed address of the atom wallet
     */
    function computeAtomWalletAddr(bytes32 atomId) external view returns (address);

    /// @notice Returns the amount of assets that would be exchanged by the vault for a given amount of shares
    ///
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param shares The amount of shares to convert to assets
    ///
    /// @return assets The amount of assets that would be exchanged for the given shares
    function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) external view returns (uint256);

    /// @notice Returns the amount of shares that would be exchanged by the vault for a given amount of assets
    ///
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param assets The amount of assets to convert to shares
    ///
    /// @return shares The amount of shares that would be exchanged for the given assets
    function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) external view returns (uint256);

    /// @notice Returns the current epoch
    /// @return The current epoch number
    function currentEpoch() external view returns (uint256);

    /// @notice Returns the current share price for the specified vault
    /// @dev This method is provided primarily for ERC4626 compatibility and is not called internally
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @return price The current share price for the specified vault
    function currentSharePrice(bytes32 termId, uint256 curveId) external view returns (uint256);

    /// @notice Returns the amount of assets that would be charged as an entry fee for a given deposit amount
    /// @dev If the vault has zero total shares, the entry fee is not applied
    /// @param assets The amount of assets to calculate the fee on
    /// @return feeAmount The amount of assets that would be charged as the entry fee
    function entryFeeAmount(uint256 assets) external view returns (uint256);

    /// @notice Returns the amount of assets that would be charged as an exit fee for a given redemption amount
    /// @dev If redeeming the shares would result in zero total shares remaining in the vault, the exit fee is not
    /// applied
    /// @param assets The amount of assets to calculate the fee on
    /// @return feeAmount The amount of assets that would be charged as the exit fee
    function exitFeeAmount(uint256 assets) external view returns (uint256);

    /**
     * @notice Returns the AtomWarden contract address
     * @return The address of the AtomWarden contract
     */
    function getAtomWarden() external view returns (address);

    /// @notice Returns the number of shares held by an account in a specific vault
    /// @param account The address of the account to query
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @return shares The amount of shares held by the account that can be redeemed
    function getShares(address account, bytes32 termId, uint256 curveId) external view returns (uint256);

    /**
     * @notice Returns the total system utilization for a specific epoch
     * @param epoch The epoch number to query
     * @return The total utilization value for the epoch (can be positive or negative)
     */
    function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256);

    /**
     * @notice Returns a user's utilization for a specific epoch
     * @param user The user address to query
     * @param epoch The epoch number to query
     * @return The user's utilization value (can be positive or negative)
     */
    function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256);

    /**
     * @notice Returns the last active epoch for a user
     * @param user The user address to query
     * @return The last epoch number in which the user had activity
     */
    function getUserLastActiveEpoch(address user) external view returns (uint256);

    /**
     * @notice Returns a user's utilization value prior to a specified epoch
     * @dev If the user had no recorded activity in the epoch immediately preceding
     *      the given one, this function falls back to their last active epoch
     *      to determine the utilization before the specified epoch
     * @param user The address of the user to query
     * @param epoch The epoch number to check utilization before
     * @return utilization The user's utilization value before the specified epoch,
     *         which may be positive or negative
     */
    function getUserUtilizationBefore(address user, uint256 epoch) external view returns (int256 utilization);

    /// @notice Returns the total assets and total shares in a vault for a given term and bonding curve
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @return totalAssets The total assets held in the vault
    /// @return totalShares The total shares issued by the vault
    function getVault(bytes32 termId, uint256 curveId) external view returns (uint256, uint256);

    /**
     * @notice Checks if a term (atom or triple) has been created
     * @param id The term ID to check
     * @return True if the term has been created, false otherwise
     */
    function isTermCreated(bytes32 id) external view returns (bool);

    /// @notice Returns the maximum number of shares a user can redeem from a vault
    /// @param sender The address of the user
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @return The maximum number of redeemable shares for the user in the vault
    function maxRedeem(address sender, bytes32 termId, uint256 curveId) external view returns (uint256);

    /// @notice Simulates the creation of an atom with an initial deposit
    /// @dev Returns the expected shares to be minted and the net assets credited after fees
    /// @param termId The ID of the atom
    /// @param assets The amount of assets the user would send
    /// @return shares The expected shares to be minted for the user
    /// @return assetsAfterFixedFees The net assets that will be added to the vault (after fixed fees, before dynamic
    /// fees)
    /// @return assetsAfterFees The net assets that will be added to the vault (after all fees)
    function previewAtomCreate(
        bytes32 termId,
        uint256 assets
    )
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees);

    /// @notice Simulates a deposit of assets into a vault
    /// @dev Returns the expected shares to be minted and the net assets credited after fees
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param assets The amount of assets the user would send
    /// @return shares The expected shares to be minted for the user
    /// @return assetsAfterFees The net assets that will be added to the vault (after all fees)
    function previewDeposit(
        bytes32 termId,
        uint256 curveId,
        uint256 assets
    )
        external
        view
        returns (uint256 shares, uint256 assetsAfterFees);

    /// @notice Simulates a redemption of shares from a vault
    /// @dev Returns the net assets the user would receive after fees and the shares to be burned
    /// @param termId The ID of the term (atom or triple)
    /// @param curveId The ID of the bonding curve
    /// @param shares The amount of shares the user would redeem
    /// @return assetsAfterFees The net assets that would be sent to the user (after protocol and exit fees)
    /// @return sharesUsed The shares that would be burned (returned for convenience)
    function previewRedeem(
        bytes32 termId,
        uint256 curveId,
        uint256 shares
    )
        external
        view
        returns (uint256 assetsAfterFees, uint256 sharesUsed);

    /// @notice Simulates the creation of a triple with an initial deposit
    /// @dev Returns the expected shares to be minted and the net assets credited after fees
    /// @param termId The ID of the triple
    /// @param assets The amount of assets the user would send
    /// @return shares The expected shares to be minted for the user
    /// @return assetsAfterFixedFees The net assets that will be added to the vault (after fixed fees like protocol and
    /// entry fees)
    /// @return assetsAfterFees The net assets that will be added to the vault (after all fees)
    function previewTripleCreate(
        bytes32 termId,
        uint256 assets
    )
        external
        view
        returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees);

    /// @notice Returns the amount of assets that would be charged as a protocol fee for a given amount
    /// @param assets The amount of assets to calculate the fee on
    /// @return feeAmount The amount of assets that would be charged as the protocol fee
    function protocolFeeAmount(uint256 assets) external view returns (uint256);

    /* =================================================== */
    /*                        WRITES                       */
    /* =================================================== */

    /// @notice Sets the approval type for a sender to act on behalf of the receiver
    /// @param sender The address to grant or revoke approval for
    /// @param approvalType The type of approval to grant (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
    function approve(address sender, ApprovalTypes approvalType) external;

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
     * @notice Returns the accumulated protocol fees for a specific epoch
     * @param epoch The epoch number to query
     * @return The accumulated protocol fees for the epoch
     */
    function accumulatedProtocolFees(uint256 epoch) external view returns (uint256);

    /// @notice Sweeps the accumulated protocol fees for a specified epoch to the protocol multisig
    function sweepAccumulatedProtocolFees(uint256 epoch) external;

    /// @notice Pauses the contract, preventing deposits and redemptions
    function pause() external;

    /// @notice Unpauses the contract, allowing deposits and redemptions
    function unpause() external;

    /// @notice Sets the general configuration parameters
    function setGeneralConfig(GeneralConfig memory _generalConfig) external;

    /// @notice Sets the atom configuration parameters
    function setAtomConfig(AtomConfig memory _atomConfig) external;

    /// @notice Sets the triple configuration parameters
    function setTripleConfig(TripleConfig memory _tripleConfig) external;

    /// @notice Sets the vault fee configuration parameters
    function setVaultFees(VaultFees memory _vaultFees) external;

    /// @notice Sets the wallet configuration parameters
    function setWalletConfig(WalletConfig memory _walletConfig) external;

    /// @notice Sets the bonding curve configuration parameters
    function setBondingCurveConfig(BondingCurveConfig memory _bondingCurveConfig) external;
}
