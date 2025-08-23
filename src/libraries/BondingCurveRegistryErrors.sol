// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title  MultiVaultErrorsErrors Library
/// @author 0xIntuition
/// @notice Library containing all custom errors detailing cases where the Intuition Protocol may revert.
library BondingCurveRegistryErrors {
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
}
