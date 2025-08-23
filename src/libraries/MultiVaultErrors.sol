// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title  MultiVaultErrorsErrors Library
/// @author 0xIntuition
/// @notice Library containing all custom errors detailing cases where the Intuition Protocol may revert.
library MultiVaultErrors {
    ///////// WRAPPEDERC20FACTORY ERRORS ////////////////////////////////////////////////////

    error WrappedERC20Factory_DeployWrappedERC20Failed();
    error WrappedERC20Factory_OnlyAdmin();
    error WrappedERC20Factory_WrappedERC20AlreadyExists();
    error WrappedERC20Factory_ZeroAddress();

    ///////// WRAPPEDERC20 ERRORS ///////////////////////////////////////////////////////////

    error WrappedERC20_ZeroAddress();
    error WrappedERC20_ZeroShares();
    error WrappedERC20_ZeroTokens();

    ///////// ATOMWALLETFACTORY ERRORS //////////////////////////////////////////////////////

    error AtomWalletFactory_DeployAtomWalletFailed();
    error AtomWalletFactory_ZeroAddress();

    ///////// ATOMWALLET ERRORS /////////////////////////////////////////////////////////////

    error AtomWallet_InvalidCallDataLength();
    error AtomWallet_InvalidSignature();
    error AtomWallet_InvalidSignatureLength(uint256 length);
    error AtomWallet_InvalidSignatureS(bytes32 s);
    error AtomWallet_OnlyOwner();
    error AtomWallet_OnlyOwnerOrEntryPoint();
    error AtomWallet_WrongArrayLengths();
    error AtomWallet_ZeroAddress();

    ///////// ATOMWARDEN ERRORS /////////////////////////////////////////////////////////////

    error AtomWarden_AtomIdDoesNotExist();
    error AtomWarden_AtomWalletNotDeployed();
    error AtomWarden_ClaimOwnershipFailed();
    error AtomWarden_InvalidMultiVaultAddress();
    error AtomWarden_InvalidNewOwner();

    ///////// MULTIVAULT ERRORS /////////////////////////////////////////////////////////////

    error MultiVault_AccessControlUnauthorizedAccount(address account, bytes32 role);
    error MultiVault_ArraysNotSameLength();
    error MultiVault_AtomExists(bytes atomData);
    error MultiVault_AtomDoesNotExist(bytes32 atomId);
    error MultiVault_AtomDataTooLong();
    error MultiVault_BurnFromZeroAddress();
    error MultiVault_BurnInsufficientBalance();
    error MultiVault_CannotApproveOrRevokeSelf();
    error MultiVault_CannotDirectlyInitializeCounterTripleVault();
    error MultiVault_CannotRecoverTrust();
    error MultiVault_ContractPaused();
    error MultiVault_DeployAccountFailed();
    error MultiVault_DepositBelowMinimumDeposit();
    error MultiVault_DepositOrRedeemZeroShares();
    error MultiVault_DepositTooSmallToCoverGhostShares();
    error MultiVault_EmptyArray();
    error MultiVault_HasCounterStake();
    error MultiVault_InsufficientBalance();
    error MultiVault_InsufficientRemainingSharesInVault(uint256 remainingShares);
    error MultiVault_InsufficientSharesInVault();
    error MultiVault_InvalidBondingCurveId();
    error MultiVault_InvalidReceiver();
    error MultiVault_NoAtomDataProvided();
    error MultiVault_NoTriplesProvided();
    error MultiVault_NoSharesToMigrate();
    error MultiVault_OnlyAssociatedAtomWallet();
    error MultiVault_OnlyAssociatedWrappedERC20();
    error MultiVault_OnlyWrappedERC20Factory();
    error MultiVault_RedeemerNotApproved();
    error MultiVault_SenderNotApproved();
    error MultiVault_SlippageExceeded();
    error MultiVault_TransfersNotEnabled();
    error MultiVault_TripleExists(bytes32 subjectId, bytes32 predicateId, bytes32 objectId);
    error MultiVault_TermDoesNotExist();
    error MultiVault_TermNotAtom();
    error MultiVault_TermNotTriple();
    error MultiVault_TransferToNonERC1155Receiver();
    error MultiVault_WrappedERC20AlreadySet();
    error MultiVault_WalletsAreTheSame();
    error MultiVault_ZeroAddress();
    error MultiVault_ZeroValue();

    ///////// MULTIVAULTCONFIG ERRORS ///////////////////////////////////////////////////////

    error MultiVaultConfig_InvalidAtomDepositFractionForTriple();
    error MultiVaultConfig_InvalidAtomWalletDepositFee();
    error MultiVaultConfig_InvalidEntryFee();
    error MultiVaultConfig_InvalidExitFee();
    error MultiVaultConfig_InvalidProtocolFee();
    error MultiVaultConfig_ZeroAddress();
    error MultiVaultConfig_ZeroValue();

    ///////// TRUSTBONDING ERRORS ///////////////////////////////////////////////////////////

    error TrustBonding_ClaimableProtocolFeesExceedBalance();
    error TrustBonding_InvalidEpoch();
    error TrustBonding_InvalidUtilizationLowerBound();
    error TrustBonding_InvalidStartTimestamp();
    error TrustBonding_ProtocolFeesNotSentToTrustBondingYet();
    error TrustBonding_MaxClaimableProtocolFeesAlreadySet();
    error TrustBonding_NoClaimingDuringFirstEpoch();
    error TrustBonding_NoRewardsToClaim();
    error TrustBonding_OnlyMultiVault();
    error TrustBonding_ProtocolFeesAlreadyClaimedForEpoch();
    error TrustBonding_ProtocolFeesExceedMaxClaimable();
    error TrustBonding_RewardsAlreadyClaimedForEpoch();
    error TrustBonding_ZeroAddress();

    ///////// BONDINGCURVEREGISTRY ERRORS ///////////////////////////////////////////////////

    error BondingCurveRegistry_CurveAlreadyExists();
    error BondingCurveRegistry_CurveNameNotUnique();
    error BondingCurveRegistry_EmptyCurveName();
    error BondingCurveRegistry_ZeroAddress();

    ///////// BASECURVE ERRORS //////////////////////////////////////////////////////////////

    error BaseCurve_EmptyStringNotAllowed();

    ///////// BONDINGCURVE ERRORS ///////////////////////////////////////////////////////////

    error BondingCurve_ActionExceedsMaxAssets();

    ///////// UNLOCK ERRORS /////////////////////////////////////////////////////////////////

    error Unlock_ApprovalFailed();
    error Unlock_ArrayLengthMismatch();
    error Unlock_CliffIsTooEarly();
    error Unlock_EndIsTooEarly();
    error Unlock_InsufficientBalance(uint256 balance, uint256 required);
    error Unlock_InvalidCliffPercentage();
    error Unlock_InvalidUnlockCliff();
    error Unlock_InvalidUnlockDuration();
    error Unlock_NotEnoughBalance();
    error Unlock_NotEnoughVested();
    error Unlock_NotTimeYet();
    error Unlock_OnlyAdmin();
    error Unlock_OnlyRecipient();
    error Unlock_SuspensionBeforeVestingBegin();
    error Unlock_SuspensionTimestampInFuture();
    error Unlock_TGETimestampAlreadySet();
    error Unlock_TrustUnlockAlreadyExists();
    error Unlock_UnlockBeginTooEarly();
    error Unlock_VestingAlreadyEnded();
    error Unlock_VestingAlreadySuspended();
    error Unlock_VestingBeginTooEarly();
    error Unlock_ZeroAddress();
    error Unlock_ZeroAmount();
    error Unlock_ZeroLengthArray();
}
