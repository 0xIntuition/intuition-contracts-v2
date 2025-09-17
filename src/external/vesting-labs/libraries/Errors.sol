// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title Errors
 * @notice Central library for all custom errors used across the TokenOps vesting contracts
 */
library Errors {
	// ============== Access Control Errors ==============
	/// @notice Thrown when an operation requires admin access but caller is not an admin
	error AdminAccessRequired();
	/// @notice Thrown when an operation requires fee collector access but caller is not the fee collector
	error NotFeeCollector();
	/// @notice Thrown when an operation requires vesting ownership but caller is not the owner
	error NotVestingOwner();
	/// @notice Thrown when an operation requires milestone ownership but caller is not the owner
	error NotMilestoneOwner();
	/// @notice Thrown when an operation requires transfer authorization but caller is not authorized
	error NotAuthorizedForTransfer();
	/// @notice Thrown when a vault operation is attempted by an unauthorized address
	error VaultUnauthorized();
	/// @notice Thrown when an operation requires at least one admin but would leave none
	error CannotRemoveLastAdmin();

	// ============== Input Validation Errors ==============
	/// @notice Thrown when an invalid address (typically zero address) is provided
	error InvalidAddress();
	/// @notice Thrown when a range of values is invalid
	error InvalidRange();
	/// @notice Thrown when arrays in a function call don't have the same length
	error ArrayLengthMismatch();
	/// @notice Thrown when an empty array is provided but non-empty is required
	error EmptyArray();
	/// @notice Thrown when a flag is already set with the same value for an address
	error AdminStatusAlreadyActive();
	/// @notice Thrown when an invalid token address is provided
	error InvalidToken();
	/// @notice Thrown when an invalid step index is provided
	error InvalidStepIndex();

	// ============== Fee-Related Errors ==============
	/// @notice Thrown when a fee is below the minimum required
	error FeeTooLow();
	/// @notice Thrown when a fee exceeds the maximum allowed
	error FeeTooHigh();
	/// @notice Thrown when insufficient fees are provided
	error InsufficientFee();
	/// @notice Thrown when a custom fee is not set for an address
	error CustomFeeNotSet();

	// ============== Token Operation Errors ==============
	/// @notice Thrown when a transfer operation fails
	error TransferFailed();
	/// @notice Thrown when there's insufficient balance for an operation
	error InsufficientBalance();
	/// @notice Thrown when an invalid funding amount is provided
	error InvalidFundingAmount();
	/// @notice Thrown when trying to exceed a funding limit
	error FundingLimitExceeded();
	/// @notice Thrown when a vesting is fully funded and additional funding is attempted
	error VestingFullyFunded();
	/// @notice Thrown when insufficient funding is provided
	error InsufficientFunding();
	/// @notice Thrown when an operation would delegate to a zero address
	error VaultZeroAddressDelegate();

	// ============== Vault-Related Errors ==============
	/// @notice Thrown when a vault is already initialized
	error VaultAlreadyInitialized();
	/// @notice Thrown when vault deployment fails
	error VaultDeploymentFailed();
	/// @notice Thrown when vault initialization fails
	error VaultInitializationFailed();

	// ============== Vesting State Errors ==============
	/// @notice Thrown when a vesting is empty (not initialized)
	error EmptyVesting();
	/// @notice Thrown when a vesting is not active
	error VestingNotActive();
	/// @notice Thrown when a vesting is fully vested
	error FullyVested();
	/// @notice Thrown when a vesting is not revocable but revocation is attempted
	error VestingNotRevocable();
	/// @notice Thrown when a timelock is enabled but an operation would violate it
	error TimelockEnabled();

	// ============== Vesting Parameter Errors ==============
	/// @notice Thrown when an invalid vested amount is provided
	error InvalidVestedAmount();
	/// @notice Thrown when an invalid start timestamp is provided
	error InvalidStartTimestamp();
	/// @notice Thrown when an invalid end timestamp is provided
	error InvalidEndTimestamp();
	/// @notice Thrown when an invalid release interval is provided
	error InvalidReleaseInterval();
	/// @notice Thrown when an invalid interval length is provided
	error InvalidIntervalLength();
	/// @notice Thrown when an invalid cliff release timestamp is provided
	error InvalidCliffRelease();
	/// @notice Thrown when an invalid cliff release timestamp is provided
	error InvalidCliffReleaseTimestamp();
	/// @notice Thrown when an invalid cliff amount is provided
	error InvalidCliffAmount();
	/// @notice Thrown when an invalid unlock timestamp is provided
	error InvalidUnlockTimestamp();

	// ============== Transfer Ownership Errors ==============
	/// @notice Thrown when no pending transfer exists but one is expected
	error NoPendingTransfer();
	/// @notice Thrown when a pending transfer exists but none is expected
	error PendingTransferExists();

	// ============== Milestone State Errors ==============
	/// @notice Thrown when a milestone with the same ID already exists
	error MilestoneAlreadyExists(bytes32 milestoneId);
	/// @notice Thrown when a milestone doesn't exist
	error MilestoneNotExists();
	/// @notice Thrown when a milestone is not active
	error MilestoneNotActive();
	/// @notice Thrown when a milestone is already revoked
	error MilestoneAlreadyRevoked();
	/// @notice Thrown when a milestone is revoked but operation assumes it's active
	error MilestoneIsRevoked();
	/// @notice Thrown when a step is already approved but approval is attempted again
	error StepAlreadyApproved();
	/// @notice Thrown when a step is already revoked but revocation is attempted again
	error StepAlreadyRevoked();
	/// @notice Thrown when a step needs to be approved but isn't
	error StepNotApproved();
	/// @notice Thrown when a milestone is fully funded but additional funding is attempted
	error MilestoneFullyFunded();
	/// @notice Thrown when a milestone step is fully funded but additional funding is attempted
	error StepFullyFunded();
	/// @notice Thrown when a start timestamp is not reached but operation requires it
	error StartTimestampNotReached();
	/// @notice Thrown when a vesting has already ended but operation assumes it's active
	error VestingAlreadyEnded();
}
