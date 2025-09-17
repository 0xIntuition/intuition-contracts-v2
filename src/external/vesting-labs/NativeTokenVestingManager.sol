// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessProtected } from "src/external/vesting-labs/libraries/AccessProtected.sol";
import { TokenVestingLib } from "src/external/vesting-labs/libraries/TokenVestingLib.sol";
import { Errors } from "src/external/vesting-labs/libraries/Errors.sol";
import { ITypes } from "src/external/vesting-labs/interfaces/ITypes.sol";
import { INativeTokenVestingManager } from "src/external/vesting-labs/interfaces/INativeTokenVestingManager.sol";

/**
 * @title Native Token Vesting Manager
 * @notice Contract to manage ETH/native token vesting
 */
contract NativeTokenVestingManager is
	AccessProtected,
	INativeTokenVestingManager
{
	using TokenVestingLib for TokenVestingLib.Vesting;
	using SafeERC20 for IERC20;

	/// Fee type for this contract (only Gas fee is supported)
	ITypes.FeeType public constant FEE_TYPE = ITypes.FeeType.Gas;
	/// Funding type for this contract
	ITypes.FundingType public immutable FUNDING_TYPE;
	/// Block number when this contract was deployed
	uint256 public immutable DEPLOYMENT_BLOCK_NUMBER;
	/// Fee amount for this contract
	uint256 public immutable FEE;
	/// Total number of native tokens reserved for vesting
	uint256 public numTokensReservedForVesting;
	/// Total number of accumulated fees
	uint256 public numTokensReservedForFees;
	/// Nonce to generate vesting IDs
	uint256 private vestingIdNonce;
	/// Address of the fee collector
	address public feeCollector;
	/// List of all recipients
	address[] public recipients;
	/// Mapping: recipient address => index+1 in recipients array (0 means not in array)
	mapping(address => uint256) private recipientToIndex;

	// Mappings for vesting data
	/// Mapping: vestingId => funding amount
	mapping(bytes32 => uint256) public vestingFunding;
	/// Mapping: recipient => vestingIds
	mapping(address => bytes32[]) public recipientVestings;
	/// Mapping: recipient => vestingId => index+1 in recipientVestings array (0 means not in array)
	mapping(address => mapping(bytes32 => uint256))
		private vestingToRecipientIndex;
	/// Mapping: vestingId => vesting
	mapping(bytes32 => TokenVestingLib.Vesting) public vestingById;
	/// Mapping: vestingId => newOwner
	mapping(bytes32 => address) public pendingVestingTransfers;

	/**
	 * @dev Reverts if the vesting is not active
	 */
	modifier isVestingActive(bytes32 _vestingId) {
		if (vestingById[_vestingId].deactivationTimestamp != 0)
			revert Errors.VestingNotActive();
		_;
	}

	/**
	 * @dev Reverts if caller is not the recipient of the vesting
	 */
	modifier onlyVestingRecipient(bytes32 _vestingId) {
		if (msg.sender != vestingById[_vestingId].recipient)
			revert Errors.NotVestingOwner();
		_;
	}

	// This checks if the msg.sender is the fee collector
	modifier onlyFeeCollector() {
		if (msg.sender != feeCollector) revert Errors.NotFeeCollector();
		_;
	}

	/**
	 * @notice Initialize the native token vesting manager
	 * @param fee_ - Fee amount for this contract
	 * @param feeCollector_ - Address of the fee collector
	 * @param fundingType_ - Type of funding for this contract (Full or Partial)
	 */
	constructor(
		uint256 fee_,
		address feeCollector_,
		ITypes.FundingType fundingType_
	) {
		if (feeCollector_ == address(0)) revert Errors.InvalidAddress();
		FEE = fee_;
		feeCollector = feeCollector_;
		FUNDING_TYPE = fundingType_;
		DEPLOYMENT_BLOCK_NUMBER = block.number;
	}

	/**
	 * @notice Create a new vesting
	 * @param _recipient - Address of the recipient
	 * @param _startTimestamp - Start timestamp of the vesting
	 * @param _endTimestamp - End timestamp of the vesting
	 * @param _timelock - Timelock for the vesting
	 * @param _initialUnlock - Initial unlock amount
	 * @param _cliffReleaseTimestamp - Cliff release timestamp
	 * @param _cliffAmount - Cliff amount
	 * @param _releaseIntervalSecs - Release interval in seconds
	 * @param _linearVestAmount - Linear vest amount
	 * @param _isRevocable - Whether the vesting is revocable
	 */
	function createVesting(
		address _recipient,
		uint32 _startTimestamp,
		uint32 _endTimestamp,
		uint32 _timelock,
		uint256 _initialUnlock,
		uint32 _cliffReleaseTimestamp,
		uint256 _cliffAmount,
		uint32 _releaseIntervalSecs,
		uint256 _linearVestAmount,
		bool _isRevocable
	) external payable onlyAdmin {
		// Partial funding mode doesn't handle sent tokens
		if (FUNDING_TYPE == ITypes.FundingType.Partial) {
			if (msg.value != 0) revert Errors.InvalidFundingAmount();
		} else {
			// For full funding, require exact ETH amount to be sent
			uint256 totalExpectedAmount = _initialUnlock +
				_cliffAmount +
				_linearVestAmount;

			if (msg.value != totalExpectedAmount)
				revert Errors.InsufficientBalance();
			numTokensReservedForVesting += totalExpectedAmount;
		}

		bytes32 vestingId = bytes32(vestingIdNonce++);

		// Create the vesting
		_createVesting(
			TokenVestingLib.VestingParams({
				_vestingId: vestingId,
				_recipient: _recipient,
				_startTimestamp: _startTimestamp,
				_endTimestamp: _endTimestamp,
				_timelock: _timelock,
				_initialUnlock: _initialUnlock,
				_cliffReleaseTimestamp: _cliffReleaseTimestamp,
				_cliffAmount: _cliffAmount,
				_releaseIntervalSecs: _releaseIntervalSecs,
				_linearVestAmount: _linearVestAmount,
				_isRevocable: _isRevocable
			})
		);
	}

	/**
	 * @notice Create a batch of vestings
	 * @param params - Parameters for creating the vesting batch
	 */
	function createVestingBatch(
		CreateVestingBatchParams calldata params
	) external payable onlyAdmin {
		uint256 length = params._recipients.length;

		// Check array lengths match
		_checkArrayLengthMismatch(params, length);

		// For full funding, require exact ETH amount to be sent
		if (FUNDING_TYPE == ITypes.FundingType.Partial) {
			if (msg.value != 0) revert Errors.InvalidFundingAmount();
		} else {
			uint256 totalExpectedAmount;
			// Calculate total required amount
			for (uint256 i; i < length; ++i) {
				totalExpectedAmount +=
					params._initialUnlocks[i] +
					params._cliffAmounts[i] +
					params._linearVestAmounts[i];
			}
			if (msg.value != totalExpectedAmount)
				revert Errors.InsufficientFunding();
			numTokensReservedForVesting += totalExpectedAmount;
		}

		// Create all vestings
		for (uint256 i; i < length; ++i) {
			bytes32 vestingId = bytes32(vestingIdNonce++);
			_createVesting(
				TokenVestingLib.VestingParams({
					_vestingId: vestingId,
					_recipient: params._recipients[i],
					_startTimestamp: params._startTimestamps[i],
					_endTimestamp: params._endTimestamps[i],
					_timelock: params._timelocks[i],
					_initialUnlock: params._initialUnlocks[i],
					_cliffReleaseTimestamp: params._cliffReleaseTimestamps[i],
					_cliffAmount: params._cliffAmounts[i],
					_releaseIntervalSecs: params._releaseIntervalSecs[i],
					_linearVestAmount: params._linearVestAmounts[i],
					_isRevocable: params._isRevocables[i]
				})
			);
		}
	}

	/**
	 * @notice Fund an existing vesting schedule
	 * @param _vestingId - Identifier of the vesting to fund
	 */
	function fundVesting(
		bytes32 _vestingId
	) external payable isVestingActive(_vestingId) onlyAdmin {
		if (FUNDING_TYPE == ITypes.FundingType.Full)
			revert Errors.VestingFullyFunded();
		if (msg.value == 0) revert Errors.InvalidFundingAmount();

		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();

		// Calculate total tokens needed for the vesting
		uint256 totalRequired = vesting.initialUnlock +
			vesting.cliffAmount +
			vesting.linearVestAmount;
		uint256 currentFunding = vestingFunding[_vestingId];

		// Ensure we don't overfund
		if (currentFunding >= totalRequired) revert Errors.VestingFullyFunded();

		// Calculate how much more funding is allowed
		uint256 remainingFunding = totalRequired - currentFunding;
		if (msg.value > remainingFunding) revert Errors.FundingLimitExceeded();

		// Update funding records
		vestingFunding[_vestingId] += msg.value;
		numTokensReservedForVesting += msg.value;

		emit VestingFunded(
			_vestingId,
			msg.sender,
			msg.value,
			vestingFunding[_vestingId],
			totalRequired
		);
	}

	/**
	 * @notice Fund multiple vestings in batch
	 * @param _vestingIds - Array of vesting identifiers to fund
	 * @param _fundingAmounts - Array of funding amounts for each vesting
	 */
	function fundVestingBatch(
		bytes32[] calldata _vestingIds,
		uint256[] calldata _fundingAmounts
	) external payable onlyAdmin {
		if (FUNDING_TYPE == ITypes.FundingType.Full)
			revert Errors.VestingFullyFunded();
		uint256 length = _vestingIds.length;
		if (length == 0) revert Errors.EmptyArray();
		if (length != _fundingAmounts.length)
			revert Errors.ArrayLengthMismatch();

		// Check if total sent ETH is zero
		if (msg.value == 0) revert Errors.InsufficientFunding();

		uint256 totalFundingAmount;
		for (uint256 i; i < length; ++i) {
			totalFundingAmount += _fundingAmounts[i];
		}

		// Check if total sent ETH matches required amount
		if (msg.value != totalFundingAmount)
			revert Errors.InsufficientFunding();

		// validate, update state, and calculate total
		for (uint256 i; i < length; ++i) {
			bytes32 vestingId = _vestingIds[i];
			uint256 fundingAmount = _fundingAmounts[i];

			// Skip entries with zero funding amount
			if (fundingAmount == 0) continue;

			TokenVestingLib.Vesting storage vesting = vestingById[vestingId];
			if (vesting.recipient == address(0)) revert Errors.EmptyVesting();
			if (vesting.deactivationTimestamp != 0)
				revert Errors.VestingNotActive();

			// Calculate total tokens needed for the vesting
			uint256 totalRequired = vesting.initialUnlock +
				vesting.cliffAmount +
				vesting.linearVestAmount;
			uint256 currentFunding = vestingFunding[vestingId];

			// Ensure we don't overfund
			if (currentFunding >= totalRequired)
				revert Errors.VestingFullyFunded();

			// Calculate how much more funding is allowed
			uint256 remainingFunding = totalRequired - currentFunding;
			if (fundingAmount > remainingFunding)
				revert Errors.FundingLimitExceeded();

			// Update funding records
			vestingFunding[vestingId] += fundingAmount;
			numTokensReservedForVesting += fundingAmount;

			// Emit event for this funding
			emit VestingFunded(
				vestingId,
				msg.sender,
				fundingAmount,
				vestingFunding[vestingId],
				totalRequired
			);
		}
	}

	/**
	 * @notice Claim vested native tokens
	 * @param _vestingId - Identifier of the vesting
	 */
	function claim(
		bytes32 _vestingId
	) external payable onlyVestingRecipient(_vestingId) {
		if (msg.value != FEE) revert Errors.InsufficientFee();
		numTokensReservedForFees += msg.value;

		_claim(_vestingId);
	}

	/**
	 * @notice Admin claims vested tokens on behalf of a recipient (gas sponsoring)
	 * @param _vestingId - Identifier of the vesting
	 */
	function adminClaim(bytes32 _vestingId) external payable onlyAdmin {
		if (msg.value != FEE) revert Errors.InsufficientFee();
		numTokensReservedForFees += msg.value;

		_claim(_vestingId);
	}

	/**
	 * @notice Admin claims vested tokens for multiple recipients (batch gas sponsoring)
	 * @param _vestingIds - Array of vesting identifiers to claim
	 */
	function batchAdminClaim(
		bytes32[] calldata _vestingIds
	) external payable onlyAdmin {
		uint256 length = _vestingIds.length;
		if (length == 0) revert Errors.EmptyArray();
		if (msg.value != FEE * length) revert Errors.InsufficientFee();
		numTokensReservedForFees += msg.value;

		for (uint256 i; i < length; ++i) _claim(_vestingIds[i]);
	}

	/**
	 * @notice Revoke active Vesting
	 * @param _vestingId - Vesting Identifier
	 */
	function revokeVesting(bytes32 _vestingId) external onlyAdmin {
		_revokeVesting(_vestingId);
	}

	/**
	 * @notice Revoke multiple vestings in batch
	 * @param _vestingIds - Array of vesting identifiers to revoke
	 * @dev More gas efficient than calling revokeVesting multiple times
	 */
	function batchRevokeVestings(
		bytes32[] calldata _vestingIds
	) external onlyAdmin {
		uint256 length = _vestingIds.length;
		if (length == 0) revert Errors.EmptyArray();

		for (uint256 i; i < length; ++i) _revokeVesting(_vestingIds[i]);
	}

	/**
	 * @notice Allow the owner to withdraw any balance not currently tied up in Vestings
	 * @param _amountRequested - Amount to withdraw
	 */
	function withdrawAdmin(uint256 _amountRequested) external onlyAdmin {
		uint256 amountRemaining = amountAvailableToWithdrawByAdmin();
		if (_amountRequested > amountRemaining)
			revert Errors.InsufficientBalance();

		emit AdminWithdrawn(msg.sender, _amountRequested);

		// Use call instead of transfer for better gas optimization and compatibility
		(bool success, ) = msg.sender.call{ value: _amountRequested }("");
		if (!success) revert Errors.TransferFailed();
	}

	/**
	 * @notice Withdraw a token which isn't controlled by the vesting contract. Useful when someone accidentally sends tokens to the contract
	 * @param _otherTokenAddress - the token which we want to withdraw
	 */
	function withdrawOtherToken(address _otherTokenAddress) external onlyAdmin {
		if (_otherTokenAddress == address(0)) revert Errors.InvalidAddress();
		uint256 balance = IERC20(_otherTokenAddress).balanceOf(address(this));
		IERC20(_otherTokenAddress).safeTransfer(msg.sender, balance);
	}

	/**
	 * @notice Initiate the transfer of vesting ownership to a new address
	 * @param _vestingId The ID of the vesting to transfer
	 * @param _newOwner The address of the new owner
	 */
	function initiateVestingTransfer(
		bytes32 _vestingId,
		address _newOwner
	) external onlyVestingRecipient(_vestingId) isVestingActive(_vestingId) {
		if (_newOwner == address(0)) revert Errors.InvalidAddress();
		if (pendingVestingTransfers[_vestingId] != address(0))
			revert Errors.PendingTransferExists();

		pendingVestingTransfers[_vestingId] = _newOwner;
		emit VestingTransferInitiated(msg.sender, _newOwner, _vestingId);
	}

	/**
	 * @notice Cancel a pending vesting transfer
	 * @param _vestingId The ID of the vesting with a pending transfer
	 */
	function cancelVestingTransfer(
		bytes32 _vestingId
	) external onlyVestingRecipient(_vestingId) {
		if (pendingVestingTransfers[_vestingId] == address(0))
			revert Errors.NoPendingTransfer();

		delete pendingVestingTransfers[_vestingId];
		emit VestingTransferCancelled(msg.sender, _vestingId);
	}

	/**
	 * @notice Accept a vesting transfer as the new owner
	 * @param _vestingId The ID of the vesting to accept
	 */
	function acceptVestingTransfer(
		bytes32 _vestingId
	) external isVestingActive(_vestingId) {
		address pendingOwner = pendingVestingTransfers[_vestingId];
		if (pendingOwner != msg.sender)
			revert Errors.NotAuthorizedForTransfer();

		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		address previousOwner = vesting.recipient;

		// Remove vesting ID from previous owner's mapping
		_removeVestingFromRecipient(previousOwner, _vestingId);

		// Update vesting recipient to new owner
		vesting.recipient = pendingOwner;

		// Add new owner to recipients list if they're not already in it
		if (!_isRecipient(pendingOwner)) {
			recipients.push(pendingOwner);
			recipientToIndex[pendingOwner] = recipients.length;
		}

		// Add vesting ID to new owner's mapping
		recipientVestings[pendingOwner].push(_vestingId);

		// Update the vesting index mapping for the new owner
		vestingToRecipientIndex[pendingOwner][_vestingId] = recipientVestings[
			pendingOwner
		].length;

		// Clear the pending transfer
		delete pendingVestingTransfers[_vestingId];

		// Emit transfer event
		emit VestingTransferred(previousOwner, pendingOwner, _vestingId);
	}

	/**
	 * @notice Direct transfer of vesting ownership by admin (for contract compatibility)
	 * @param _vestingId The ID of the vesting to transfer
	 * @param _newOwner The address of the new owner
	 * @dev This is specifically for compatibility with contracts that cannot call acceptVestingTransfer
	 */
	function directVestingTransfer(
		bytes32 _vestingId,
		address _newOwner
	) external onlyVestingRecipient(_vestingId) isVestingActive(_vestingId) {
		if (_newOwner == address(0)) revert Errors.InvalidAddress();

		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		address previousOwner = vesting.recipient;

		// Remove vesting ID from previous owner's mapping
		_removeVestingFromRecipient(previousOwner, _vestingId);

		// Update vesting recipient to new owner
		vesting.recipient = _newOwner;

		// Add new owner to recipients list if they're not already in it
		if (!_isRecipient(_newOwner)) {
			recipients.push(_newOwner);
			recipientToIndex[_newOwner] = recipients.length;
		}

		// Add vesting ID to new owner's mapping
		recipientVestings[_newOwner].push(_vestingId);

		// Update the vesting index mapping for the new owner
		vestingToRecipientIndex[_newOwner][_vestingId] = recipientVestings[
			_newOwner
		].length;

		// Clear any pending transfer if it exists
		if (pendingVestingTransfers[_vestingId] != address(0))
			delete pendingVestingTransfers[_vestingId];

		// Emit transfer event
		emit VestingTransferred(previousOwner, _newOwner, _vestingId);
	}

	/**
	 * @notice Allows only fee collector to withdraw collected gas fees
	 * @dev This function is completely separate from distributor admin controls
	 * @param recipient Address to receive the fee
	 * @param amount Amount to withdraw, if 0 withdraws all available fees
	 */
	function withdrawGasFee(
		address recipient,
		uint256 amount
	) external onlyFeeCollector {
		if (recipient == address(0)) revert Errors.InvalidAddress();
		if (numTokensReservedForFees == 0) revert Errors.InsufficientFee();

		// If amount is 0, withdraw all fees
		if (amount == 0) amount = numTokensReservedForFees;
		if (amount > numTokensReservedForFees) revert Errors.FeeTooLow();
		numTokensReservedForFees -= amount;

		emit GasFeeWithdrawn(recipient, amount);

		(bool success, ) = recipient.call{ value: amount }("");
		if (!success) revert Errors.TransferFailed();
	}

	/**
	 * @notice Updates the fee collector address
	 * @param newFeeCollector Address of the new fee collector
	 * @dev Can only be called by the fee collector
	 */
	function transferFeeCollectorRole(
		address newFeeCollector
	) external onlyFeeCollector {
		if (newFeeCollector == address(0)) revert Errors.InvalidAddress();

		address oldFeeCollector = feeCollector;
		feeCollector = newFeeCollector;

		emit FeeCollectorUpdated(oldFeeCollector, newFeeCollector);
	}

	/**
	 * @notice Get funding information for a vesting
	 * @param _vestingId - Identifier of the vesting
	 * @return fundingType - Type of funding (Full or Partial)
	 * @return totalFunded - Total amount of tokens funded so far
	 * @return totalRequired - Total amount of tokens required for full funding
	 */
	function getVestingFundingInfo(
		bytes32 _vestingId
	)
		external
		view
		returns (uint8 fundingType, uint256 totalFunded, uint256 totalRequired)
	{
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();

		fundingType = uint8(FUNDING_TYPE);

		totalRequired =
			vesting.initialUnlock +
			vesting.cliffAmount +
			vesting.linearVestAmount;

		totalFunded = FUNDING_TYPE == ITypes.FundingType.Full
			? totalRequired
			: vestingFunding[_vestingId];

		return (fundingType, totalFunded, totalRequired);
	}

	/**
	 * @notice Check if a vesting is fully funded
	 * @param _vestingId - Identifier of the vesting
	 * @return isFullyFunded - True if the vesting is fully funded
	 */
	function isVestingFullyFunded(
		bytes32 _vestingId
	) external view returns (bool) {
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();
		if (FUNDING_TYPE == ITypes.FundingType.Full) return true;

		uint256 totalRequired = vesting.initialUnlock +
			vesting.cliffAmount +
			vesting.linearVestAmount;
		uint256 totalFunded = vestingFunding[_vestingId];

		return totalFunded >= totalRequired;
	}

	/**
	 * @notice Get the vesting information
	 * @param _vestingId - Identifier of the vesting
	 * @return vesting - Vesting information
	 */
	function getVestingInfo(
		bytes32 _vestingId
	) external view returns (TokenVestingLib.Vesting memory) {
		return vestingById[_vestingId];
	}

	/**
	 * @notice Get the vested amount for a Vesting, at a given timestamp.
	 * @param _vestingId The vesting ID
	 * @param _referenceTimestamp Timestamp for which we're calculating
	 */
	function getVestedAmount(
		bytes32 _vestingId,
		uint32 _referenceTimestamp
	) external view returns (uint256) {
		TokenVestingLib.Vesting memory vesting = vestingById[_vestingId];
		return vesting.calculateVestedAmount(_referenceTimestamp);
	}

	/**
	 * @notice Get the claimable amount for a vesting
	 * @param _vestingId - Identifier of the vesting
	 * @return claimable - The amount of tokens that can be claimed at the current time
	 */
	function getClaimableAmount(
		bytes32 _vestingId
	) external view returns (uint256 claimable) {
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];

		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();

		// If timelock is active, nothing can be claimed
		if (vesting.timelock > uint32(block.timestamp)) return 0;

		// Calculate vested amount as of now
		uint256 vestedAmount = vesting.calculateVestedAmount(
			uint32(block.timestamp)
		);

		// Calculate claimable amount (vested - already claimed)
		claimable = vestedAmount > vesting.claimedAmount
			? vestedAmount - vesting.claimedAmount
			: 0;

		// For partial funding, ensure we don't return more than what's funded
		if (FUNDING_TYPE == ITypes.FundingType.Partial) {
			uint256 currentFunding = vestingFunding[_vestingId];

			// If funding is less than what's vested, adjust claimable
			if (currentFunding < vestedAmount) {
				claimable = currentFunding > vesting.claimedAmount
					? currentFunding - vesting.claimedAmount
					: 0;
			}
		}

		return claimable;
	}

	/**
	 * @notice Get all recipients
	 * @return recipients - The list of recipients
	 */
	function getAllRecipients() external view returns (address[] memory) {
		return recipients;
	}

	/**
	 * @notice Get the length of all recipients
	 * @return length - The length of all recipients
	 */
	function getAllRecipientsLength() external view returns (uint256) {
		return recipients.length;
	}

	/**
	 * @notice Get all recipients in a range
	 * @param _from - The start index (inclusive)
	 * @param _to - The end index (exclusive)
	 * @return recipientsSliced - The list of recipients in the range
	 */
	function getAllRecipientsSliced(
		uint256 _from,
		uint256 _to
	) external view returns (address[] memory) {
		if (_from >= _to || _to > recipients.length)
			revert Errors.InvalidRange();

		address[] memory recipientsSliced = new address[](_to - _from);
		for (uint256 i = _from; i < _to; ++i)
			recipientsSliced[i - _from] = recipients[i];
		return recipientsSliced;
	}

	/**
	 * @notice Get all vestings for a recipient
	 * @param _recipient - The recipient address
	 * @return recipientVestings - The list of vestings for the recipient
	 */
	function getAllRecipientVestings(
		address _recipient
	) external view returns (bytes32[] memory) {
		return recipientVestings[_recipient];
	}

	/**
	 * @notice Get all vestings for a recipient in a range
	 * @param _from - The start index (inclusive)
	 * @param _to - The end index (exclusive)
	 * @param _recipient - The recipient address
	 * @return recipientVestingsSliced - The list of vestings for the recipient in the range
	 */
	function getAllRecipientVestingsSliced(
		uint256 _from,
		uint256 _to,
		address _recipient
	) external view returns (bytes32[] memory) {
		if (_recipient == address(0)) revert Errors.InvalidAddress();
		if (_from >= _to || _to > recipientVestings[_recipient].length)
			revert Errors.InvalidRange();

		bytes32[] memory recipientVestingsSliced = new bytes32[](_to - _from);
		for (uint256 i = _from; i < _to; ++i) {
			recipientVestingsSliced[i - _from] = recipientVestings[_recipient][
				i
			];
		}
		return recipientVestingsSliced;
	}

	/**
	 * @notice Get the length of all vestings for a recipient
	 * @param _recipient - The recipient address
	 * @return length - The length of all vestings for the recipient
	 */
	function getAllRecipientVestingsLength(
		address _recipient
	) external view returns (uint256) {
		if (_recipient == address(0)) revert Errors.InvalidAddress();
		return recipientVestings[_recipient].length;
	}

	/**
	 * @notice Get the pending owner for a vesting transfer
	 * @param _vestingId The ID of the vesting
	 * @return The address of the pending owner if there is one, or zero address
	 */
	function getPendingVestingTransfer(
		bytes32 _vestingId
	) external view returns (address) {
		return pendingVestingTransfers[_vestingId];
	}

	/**
	 * @notice Amount of tokens available to withdraw by the admin
	 * @return The amount of tokens available to withdraw
	 */
	function amountAvailableToWithdrawByAdmin() public view returns (uint256) {
		return
			address(this).balance -
			numTokensReservedForVesting -
			numTokensReservedForFees;
	}

	/**
	 * @notice Check if a recipient has vestings
	 * @param recipient - The recipient address
	 * @return isRecipient - True if the recipient has vestings
	 */
	function isRecipient(address recipient) external view returns (bool) {
		return _isRecipient(recipient);
	}

	/**
	 * @dev Internal function to create a new vesting
	 * @param params - Vesting parameters
	 */
	function _createVesting(
		TokenVestingLib.VestingParams memory params
	) internal {
		if (params._recipient == address(0)) revert Errors.InvalidAddress();
		if (
			params._linearVestAmount +
				params._initialUnlock +
				params._cliffAmount ==
			0
		) revert Errors.InvalidVestedAmount();
		if (params._startTimestamp == 0) revert Errors.InvalidStartTimestamp();
		if (params._startTimestamp > params._endTimestamp)
			revert Errors.InvalidEndTimestamp();
		if (
			params._startTimestamp == params._endTimestamp &&
			params._linearVestAmount > 0
		) revert Errors.InvalidEndTimestamp();
		if (params._releaseIntervalSecs == 0)
			revert Errors.InvalidReleaseInterval();
		if (params._cliffReleaseTimestamp == 0) {
			if (params._cliffAmount != 0) revert Errors.InvalidCliffAmount();
			if (
				(params._endTimestamp - params._startTimestamp) %
					params._releaseIntervalSecs !=
				0
			) revert Errors.InvalidIntervalLength();
		} else {
			// Cliff release is set but amount can be zero
			if (
				((params._startTimestamp > params._cliffReleaseTimestamp) ||
					(params._cliffReleaseTimestamp >= params._endTimestamp))
			) revert Errors.InvalidCliffRelease();
			if (
				(params._endTimestamp - params._cliffReleaseTimestamp) %
					params._releaseIntervalSecs !=
				0
			) revert Errors.InvalidIntervalLength();
		}

		TokenVestingLib.Vesting memory vesting = TokenVestingLib.Vesting({
			recipient: params._recipient,
			startTimestamp: params._startTimestamp,
			endTimestamp: params._endTimestamp,
			deactivationTimestamp: 0,
			timelock: params._timelock,
			initialUnlock: params._initialUnlock,
			cliffReleaseTimestamp: params._cliffReleaseTimestamp,
			cliffAmount: params._cliffAmount,
			releaseIntervalSecs: params._releaseIntervalSecs,
			linearVestAmount: params._linearVestAmount,
			claimedAmount: 0,
			isRevocable: params._isRevocable
		});

		if (!_isRecipient(params._recipient)) {
			// Add the recipient to the array and update the index mapping
			recipients.push(params._recipient);
			recipientToIndex[params._recipient] = recipients.length; // Store index+1
		}

		vestingById[params._vestingId] = vesting;
		recipientVestings[params._recipient].push(params._vestingId);

		// Update the vesting index mapping for efficient removal (store index+1 to distinguish from 0)
		vestingToRecipientIndex[params._recipient][
			params._vestingId
		] = recipientVestings[params._recipient].length;

		emit VestingCreated(params._vestingId, params._recipient, vesting);
	}

	/**
	 * @dev Internal function to claim vested tokens
	 * @param _vestingId - Identifier of the vesting
	 */
	function _claim(bytes32 _vestingId) internal {
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];

		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();
		if (vesting.timelock > uint32(block.timestamp))
			revert Errors.TimelockEnabled();

		uint256 vested = vesting.calculateVestedAmount(uint32(block.timestamp));
		uint256 claimable = vested - vesting.claimedAmount;

		if (claimable == 0) revert Errors.InsufficientBalance();

		// If partial funding is enabled, check if there's enough funding
		if (FUNDING_TYPE == ITypes.FundingType.Partial) {
			uint256 currentFunding = vestingFunding[_vestingId];

			// Check if there's enough funding for the claim
			if (currentFunding < vested) {
				// If not enough funding, adjust claimable to what's available
				claimable = currentFunding > vesting.claimedAmount
					? currentFunding - vesting.claimedAmount
					: 0;

				if (claimable == 0) revert Errors.InsufficientFunding();
			}
		}

		vesting.claimedAmount += claimable;
		numTokensReservedForVesting -= claimable;

		emit Claimed(_vestingId, vesting.recipient, claimable);

		// Send ETH to recipient
		(bool success, ) = vesting.recipient.call{ value: claimable }("");
		if (!success) revert Errors.TransferFailed();
	}

	/**
	 * @dev Internal function to revoke a vesting
	 * @param _vestingId - Vesting Identifier
	 */
	function _revokeVesting(
		bytes32 _vestingId
	) internal isVestingActive(_vestingId) {
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];

		if (block.timestamp >= vesting.endTimestamp)
			revert Errors.FullyVested();
		if (!vesting.isRevocable) revert Errors.VestingNotRevocable();

		uint256 vestedAmountNow = vesting.calculateVestedAmount(
			uint32(block.timestamp)
		);
		uint256 finalVestAmount = vesting.calculateVestedAmount(
			vesting.endTimestamp
		);
		uint256 amountRemaining = finalVestAmount - vestedAmountNow;

		// In partial funding mode, we need to adjust the amount based on what was actually funded
		if (FUNDING_TYPE == ITypes.FundingType.Partial) {
			uint256 totalFunded = vestingFunding[_vestingId];

			// If there's not enough funding to cover what's already vested, we need to adjust
			if (totalFunded <= vestedAmountNow) {
				// All funded tokens are already vested, nothing to release
				amountRemaining = 0;
			} else {
				// Only release what's actually funded and not yet vested
				amountRemaining = totalFunded - vestedAmountNow;
			}
		}

		vesting.deactivationTimestamp = uint32(block.timestamp);
		numTokensReservedForVesting -= amountRemaining;

		emit VestingRevoked(_vestingId, amountRemaining, vesting);
	}

	/**
	 * @dev Helper function to remove a vesting ID from a recipient's array
	 * @param _recipient The address of the recipient
	 * @param _vestingId The ID of the vesting to remove
	 */
	function _removeVestingFromRecipient(
		address _recipient,
		bytes32 _vestingId
	) internal {
		bytes32[] storage vestingIds = recipientVestings[_recipient];
		uint256 indexPlusOne = vestingToRecipientIndex[_recipient][_vestingId];

		if (indexPlusOne == 0) return; // Vesting not found

		uint256 index = indexPlusOne - 1;
		uint256 lastIndex = vestingIds.length - 1;

		// If this is not the last element, move the last element to this position
		if (index != lastIndex) {
			bytes32 lastVestingId = vestingIds[lastIndex];
			vestingIds[index] = lastVestingId;
			// Update the index mapping for the moved element
			vestingToRecipientIndex[_recipient][lastVestingId] = index + 1;
		}

		// Remove the last element and clear the mapping
		vestingIds.pop();
		delete vestingToRecipientIndex[_recipient][_vestingId];

		// If recipient has no more vestings, remove from recipients array
		if (vestingIds.length == 0) _removeRecipient(_recipient);
	}

	/**
	 * @dev Helper function to remove a recipient from the recipients array
	 * @param _recipient The address of the recipient to remove
	 */
	function _removeRecipient(address _recipient) internal {
		uint256 indexPlusOne = recipientToIndex[_recipient];
		if (indexPlusOne == 0) return; // Not in array

		uint256 index = indexPlusOne - 1; // Convert from index+1 to zero-based index
		uint256 lastIndex = recipients.length - 1;

		// If this is not the last element, move the last element to this position
		if (index != lastIndex) {
			address lastRecipient = recipients[lastIndex];
			recipients[index] = lastRecipient;
			recipientToIndex[lastRecipient] = index + 1; // Update index+1 for the moved element
		}

		// Remove the last element and clear the mapping
		recipients.pop();
		delete recipientToIndex[_recipient];
	}

	/// @dev Internal function to check if an address is a recipient
	/// @param recipient The address to check
	/// @return True if the address is a recipient, false otherwise
	function _isRecipient(address recipient) internal view returns (bool) {
		if (recipient == address(0)) revert Errors.InvalidAddress();
		return recipientToIndex[recipient] != 0;
	}

	/**
	 * @dev Internal function to check if all array lengths in batch params match the expected length
	 * @param params - Batch parameters to validate
	 * @param expectedLength - The expected length all arrays should match
	 */
	function _checkArrayLengthMismatch(
		CreateVestingBatchParams calldata params,
		uint256 expectedLength
	) internal pure {
		if (
			params._startTimestamps.length != expectedLength ||
			params._endTimestamps.length != expectedLength ||
			params._timelocks.length != expectedLength ||
			params._initialUnlocks.length != expectedLength ||
			params._cliffAmounts.length != expectedLength ||
			params._cliffReleaseTimestamps.length != expectedLength ||
			params._releaseIntervalSecs.length != expectedLength ||
			params._linearVestAmounts.length != expectedLength ||
			params._isRevocables.length != expectedLength
		) {
			revert Errors.ArrayLengthMismatch();
		}
	}
}