// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

/// @title  TrustErrors
/// @author 0xIntuition
/// @notice Library containing all custom errors detailing cases where the Intuition Protocol may revert.
library TrustErrors {
    error Trust_AnnualMintingLimitExceeded();
    error Trust_EpochMintingLimitExceeded();
    error Trust_ContractPaused();
    error Trust_ContractNotPaused();
    error Trust_InvalidAnnualReductionBasisPoints();
    error Trust_InvalidMaxAnnualEmission();
    error Trust_InvalidMaxEmissionPerEpochBasisPoints();
    error Trust_InvalidStartTimestamp();
    error Trust_OnlyAdmin();
    error Trust_OnlyInitialAdmin();
    error Trust_OnlyMinter();
    error Trust_ReentrancyGuard();
    error Trust_ZeroAddress();
    error Trust_ZeroAmount();
}
