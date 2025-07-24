// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPermit2} from "src/interfaces/IPermit2.sol";

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

    /// @notice Fees struct to return all applicable fees for a given transaction
    struct FeesAndSharesBreakdown {
        /// @dev the amount of shares to be minted for the receiver
        uint256 sharesForReceiver;
        /// @dev the amount of assets to be withdrawn to the receiver
        uint256 assetsForReceiver;
        /// @dev the assets delta used for setting the vault totals
        uint256 assetsDelta;
        /// @dev entry fee that is charged when depositing assets into the vault
        uint256 entryFee;
        /// @dev exit fee that is charged when redeeming shares from the vault
        uint256 exitFee;
        /// @dev protocol fee that is charged when depositing assets into the vault
        uint256 protocolFee;
        /// @dev atom wallet fee that is charged when depositing assets into the atom vault
        uint256 atomWalletDepositFee;
        /// @dev atom deposit fraction that is charged when depositing assets into the triple vault
        uint256 atomDepositFraction;
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

    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice emitted when a wrapped ERC20 token is registered for a term and bonding curve id combination
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param wrappedERC20 address of the wrapped ERC20 token
    event WrappedERC20Registered(bytes32 indexed termId, uint256 indexed bondingCurveId, address indexed wrappedERC20);

    /// @notice emitted when an internal wrapper transfer is made in order to wrap or unwrap the wrapped ERC20 tokens
    ///
    /// @param from address of the sender
    /// @param to address of the receiver
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param shares amount of shares transferred
    event WrapperTransfer(
        address indexed from, address indexed to, bytes32 indexed termId, uint256 bondingCurveId, uint256 shares
    );

    /// @notice emitted when the config is synced between the MultiVault and the MultiVaultConfig
    /// @param caller address of the caller
    event ConfigSynced(address indexed caller);

    /// @notice emitted upon recovering accidentally sent tokens from the contract
    ///
    /// @param token address of the token
    /// @param recipient address of the recipient
    /// @param amount amount of tokens recovered
    event TokensRecovered(address indexed token, address indexed recipient, uint256 indexed amount);

    /// @notice Emitted when a receiver changes the approval type for a sender
    ///
    /// @param sender address of the sender being approved/disapproved
    /// @param receiver address of the receiver granting/revoking approval
    /// @param approvalType the type of approval granted (NONE = 0, DEPOSIT = 1, REDEMPTION = 2, BOTH = 3)
    event ApprovalTypeUpdated(address indexed sender, address indexed receiver, ApprovalTypes approvalType);

    /// @notice emitted upon claiming the fees from the atom wallet
    ///
    /// @param atomId atom id of the atom
    /// @param atomWalletOwner address of the atom wallet owner
    /// @param feesClaimed amount of fees claimed from the atom wallet
    event AtomWalletDepositFeesClaimed(
        bytes32 indexed atomId, address indexed atomWalletOwner, uint256 indexed feesClaimed
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

    /// @notice emitted upon depositing assets into the vault
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param assetsIn amount of assets deposited (gross assets deposited by the sender, including atomCost/tripleCost where applicable)
    /// @param assetsAfterTotalFees amount of assets after all fees for the deposit are deducted
    /// @param sharesOut amount of shares minted to the receiver
    event Deposited(
        bytes32 indexed termId,
        uint256 indexed bondingCurveId,
        address indexed sender,
        address receiver,
        uint256 assetsIn,
        uint256 assetsAfterTotalFees,
        uint256 sharesOut
    );

    /// @notice emitted upon redeeming shares from the vault
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sender address of the sender
    /// @param receiver address of the receiver
    /// @param sharesIn amount of shares redeemed
    /// @param assetsOut amount of assets withdrawn (net assets received by the receiver)
    event Redeemed(
        bytes32 indexed termId,
        uint256 indexed bondingCurveId,
        address indexed sender,
        address receiver,
        uint256 sharesIn,
        uint256 assetsOut
    );

    /// @notice emitted after entry fee is collected
    /// @dev entry fee is charged when depositing assets into the vault and they stay in the vault as assets
    ///      rather than going towards minting shares for the receiver
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sender address of the sender
    /// @param amount amount of entry fee collected
    event EntryFeeCollected(
        bytes32 indexed termId, uint256 indexed bondingCurveId, address indexed sender, uint256 amount
    );

    /// @notice emitted after exit fee is collected
    /// @dev exit fee is charged when redeeming shares from the vault and they stay in the vault as assets
    ///      rather than being sent to the receiver
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sender address of the sender
    /// @param amount amount of exit fee collected
    event ExitFeeCollected(
        bytes32 indexed termId, uint256 indexed bondingCurveId, address indexed sender, uint256 amount
    );

    /// @notice emitted after atom wallet deposit fee is collected
    /// @dev atom wallet deposit fee is charged when depositing assets into the atom vaults and it's used
    ///      to accumulate more claimable fees for the atom wallet owner of the given atom vault
    ///
    /// @param termId term id of the vault
    /// @param sender address of the sender
    /// @param amount amount of atom wallet deposit fee collected
    event AtomWalletDepositFeeCollected(bytes32 indexed termId, address indexed sender, uint256 amount);

    /// @notice emitted after atom deposit fraction is deposited into the underlying vaults
    /// @dev atom deposit fraction is charged when depositing assets into the triple vaults and it's used
    ///      to purchase shares in the underlying atoms for the receiver
    ///
    /// @param termId term id of the vault
    /// @param sender address of the sender
    /// @param amount amount of atom deposit fraction deposited
    event AtomDepositFractionDeposited(bytes32 indexed termId, address indexed sender, uint256 amount);

    /// @notice emitted after protocol fee is accrued internally. It's later transferred either to the protocol multisig
    ///         or to the TrustBonding contract for pro-rata distribution among the bonders, depending on the
    ///         `generalConfig.protocolFeeDistributionEnabled` setting
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

    /// @notice emitted when the vault totals are changed
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param totalAssets total assets in the vault
    /// @param totalShares total shares in the vault
    event VaultTotalsChanged(
        bytes32 indexed termId, uint256 indexed bondingCurveId, uint256 totalAssets, uint256 totalShares
    );

    /// @notice emitted when the share price is changed
    ///
    /// @param termId term id of the vault
    /// @param bondingCurveId bonding curve id of the vault
    /// @param sharePrice new share price
    event SharePriceChanged(bytes32 indexed termId, uint256 indexed bondingCurveId, uint256 sharePrice);

    /// @notice emitted when the atom vault is created
    ///
    /// @param atomId atom id of the atom vault
    /// @param creator address of the creator
    /// @param atomWallet address of the atom wallet associated with the atom vault
    event AtomCreated(bytes32 indexed atomId, address indexed creator, address atomWallet);

    /// @notice emitted when the triple vault is created
    ///
    /// @param tripleId triple id of the triple vault
    /// @param creator address of the creator
    /// @param subjectId atom id of the subject vault
    /// @param predicateId atom id of the predicate vault
    /// @param objectId atom id of the object vault
    event TripleCreated(
        bytes32 indexed tripleId, address indexed creator, bytes32 subjectId, bytes32 predicateId, bytes32 objectId
    );

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    function initialize(address _multiVaultConfig) external;

    /* =================================================== */
    /*                    ADMIN FUNCTIONS                  */
    /* =================================================== */

    function recoverTokens(address token, address recipient) external;

    function registerWrappedERC20(bytes32 termId, uint256 bondingCurveId, address wrappedERC20) external;

    function wrapperTransfer(address from, address to, bytes32 termId, uint256 bondingCurveId, uint256 shares)
        external;

    /* =================================================== */
    /*                MUTATIVE FUNCTIONS                   */
    /* =================================================== */

    function syncConfig() external;

    function claimAtomWalletDepositFees(bytes32 atomId) external;

    function safeTransferFrom(
        address from,
        address to,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 value,
        bytes calldata data
    ) external pure;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata termIds,
        uint256 bondingCurveId,
        uint256[] calldata values,
        bytes calldata data
    ) external pure;

    function approve(address sender, ApprovalTypes approvalType) external;

    function atomData(bytes32 atomId) external returns (bytes calldata data);

    function createAtom(bytes calldata data, uint256 value) external returns (bytes32);

    function batchCreateAtom(bytes[] calldata atomDataArray, uint256 value) external returns (bytes32[] memory);

    function createTriple(bytes32 subjectId, bytes32 predicateId, bytes32 objectId, uint256 value)
        external
        returns (bytes32);

    function batchCreateTriple(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256 value
    ) external returns (bytes32[] memory);

    function deposit(
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 value,
        uint256 minSharesToReceive
    ) external returns (uint256);

    function batchDeposit(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata amounts,
        uint256[] calldata minSharesToReceive
    ) external returns (uint256[] memory);

    function redeem(
        uint256 shares,
        address receiver,
        bytes32 termId,
        uint256 bondingCurveId,
        uint256 minAssetsToReceive
    ) external returns (uint256);

    function batchRedeem(
        uint256[] calldata shares,
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata bondingCurveIds,
        uint256[] calldata minAssetsToReceive
    ) external returns (uint256[] memory);

    /* =================================================== */
    /*                    VIEW FUNCTIONS                   */
    /* =================================================== */

    function termCount() external view returns (uint256);

    function getAtomCost() external view returns (uint256);

    function getTripleCost() external view returns (uint256);

    function entryFeeAmount(uint256 assets) external view returns (uint256);

    function exitFeeAmount(uint256 assets) external view returns (uint256);

    function protocolFeeAmount(uint256 assets) external view returns (uint256);

    function atomDepositFractionAmount(uint256 assets, bytes32 termId) external view returns (uint256);

    function atomWalletDepositFeeAmount(uint256 assets, bytes32 termId) external view returns (uint256);

    function currentSharePrice(bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function maxDeposit() external view returns (uint256);

    function maxRedeem(address sender, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function convertToShares(uint256 assets, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function convertToAssets(uint256 shares, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function previewDeposit(uint256 assets, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function previewRedeem(uint256 shares, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function isTripleId(bytes32 termId) external view returns (bool);

    function isCounterTripleId(bytes32 termId) external view returns (bool);

    function getTripleAtoms(bytes32 tripleId) external view returns (bytes32, bytes32, bytes32);

    function tripleIdFromAtomIds(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        external
        pure
        returns (bytes32);

    function getCounterIdFromTriple(bytes32 termId) external pure returns (bytes32);

    function getTripleIdFromCounter(bytes32 counterId) external view returns (bytes32);

    function balanceOf(address account, bytes32 termId, uint256 bondingCurveId) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, bytes32[] calldata termIds, uint256 bondingCurveId)
        external
        view
        returns (uint256[] memory);

    function getIsProtocolFeeDistributionEnabled() external view returns (bool);

    function protocolFeeDistributionEnabledAtEpoch(uint256 epoch) external view returns (bool);

    function getAtomWarden() external view returns (address);

    function getVaultStateForUser(bytes32 termId, uint256 bondingCurveId, address receiver)
        external
        view
        returns (uint256, uint256);

    function getVaultTotals(bytes32 termId, uint256 bondingCurveId) external view returns (uint256, uint256);

    function computeAtomWalletAddr(bytes32 atomId) external view returns (address);

    function currentEpoch() external view returns (uint256);

    function getUserUtilizationForEpoch(address user, uint256 epoch) external view returns (int256);

    function getTotalUtilizationForEpoch(uint256 epoch) external view returns (int256);

    function accumulatedProtocolFees(uint256 epoch) external view returns (uint256);

    function isApprovedToDeposit(address sender, address receiver) external view returns (bool);

    function isApprovedToRedeem(address sender, address receiver) external view returns (bool);

    function isTermIdValid(bytes32 id) external view returns (bool);

    function isBondingCurveIdValid(uint256 bondingCurveId) external view returns (bool);

    function generalConfig()
        external
        view
        returns (
            address admin,
            address protocolMultisig,
            uint256 feeDenominator,
            address trust,
            address trustBonding,
            uint256 minDeposit,
            uint256 minShare,
            uint256 atomDataMaxLength,
            uint256 decimalPrecision,
            string memory baseURI,
            bool protocolFeeDistributionEnabled
        );

    function atomConfig() external view returns (uint256 atomCreationProtocolFee, uint256 atomWalletDepositFee);

    function tripleConfig()
        external
        view
        returns (
            uint256 tripleCreationProtocolFee,
            uint256 totalAtomDepositsOnTripleCreation,
            uint256 atomDepositFractionForTriple
        );

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

    function vaultFees() external view returns (uint256 entryFee, uint256 exitFee, uint256 protocolFee);

    function bondingCurveConfig() external view returns (address registry, uint256 defaultCurveId);

    function wrapperConfig() external view returns (address wrappedERC20Beacon, address wrappedERC20Factory);
}
