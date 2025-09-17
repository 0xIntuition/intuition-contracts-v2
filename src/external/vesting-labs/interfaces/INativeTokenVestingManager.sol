// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import "src/external/vesting-labs/libraries/TokenVestingLib.sol";
import "src/external/vesting-labs/interfaces/ITypes.sol";

interface INativeTokenVestingManager {
	/// @notice Parameters for vesting creation with a predefined ID
	struct VestingCreationParams {
		bytes32 vestingId;
		address recipient;
		uint32 startTimestamp;
		uint32 endTimestamp;
		uint32 timelock;
		uint256 initialUnlock;
		uint32 cliffReleaseTimestamp;
		uint256 cliffAmount;
		uint32 releaseIntervalSecs;
		uint256 linearVestAmount;
		bool isRevocable;
	}
	/// @notice Parameters for batch creation of vesting schedules
	/// @dev Arrays must be of equal length
	struct CreateVestingBatchParams {
		address[] _recipients;
		uint32[] _startTimestamps;
		uint32[] _endTimestamps;
		uint32[] _timelocks;
		uint256[] _initialUnlocks;
		uint32[] _cliffReleaseTimestamps;
		uint256[] _cliffAmounts;
		uint32[] _releaseIntervalSecs;
		uint256[] _linearVestAmounts;
		bool[] _isRevocables;
	}

	/// @notice Emitted when an admin withdraws tokens not tied up in vesting
	/// @param recipient Address of the recipient (admin) making the withdrawal
	/// @param amountRequested Amount of tokens withdrawn by the admin
	event AdminWithdrawn(address indexed recipient, uint256 amountRequested);

	/// @notice Emitted when a claim is made by a vesting recipient
	/// @param vestingId Unique identifier of the recipient's vesting arrangement
	/// @param recipient Address of the recipient making the claim
	/// @param withdrawalAmount Amount of tokens withdrawn in the claim
	event Claimed(
		bytes32 indexed vestingId,
		address indexed recipient,
		uint256 withdrawalAmount
	);

	/// @notice Emitted when new fee collector is set
	/// @param oldFeeCollector Address of the previous fee collector
	/// @param newFeeCollector Address of the new fee collector
	event FeeCollectorUpdated(
		address indexed oldFeeCollector,
		address indexed newFeeCollector
	);

	/// @notice Emitted when gas fees (ETH) are withdrawn by the fee collector
	/// @param recipient Address receiving the withdrawn fees
	/// @param amount Amount of ETH withdrawn
	event GasFeeWithdrawn(address indexed recipient, uint256 amount);

	/// @notice Emitted when a new vesting is created
	/// @param vestingId Unique identifier for the vesting
	/// @param recipient Address of the vesting recipient
	/// @param vesting Details of the created vesting
	event VestingCreated(
		bytes32 indexed vestingId,
		address indexed recipient,
		TokenVestingLib.Vesting vesting
	);

	/// @notice Emitted when a vesting is funded or additionally funded
	/// @param vestingId Unique identifier of the vesting
	/// @param funder Address of the account funding the vesting
	/// @param amount Amount of tokens added to the vesting
	/// @param totalFunded Total amount funded for this vesting so far
	/// @param totalRequired Total amount required by the vesting
	event VestingFunded(
		bytes32 indexed vestingId,
		address indexed funder,
		uint256 amount,
		uint256 totalFunded,
		uint256 totalRequired
	);

	/// @notice Emitted when a vesting is revoked
	/// @param vestingId Identifier of the revoked vesting
	/// @param numTokensWithheld Amount of tokens withheld during the revocation
	/// @param vesting Details of the revoked vesting
	event VestingRevoked(
		bytes32 indexed vestingId,
		uint256 numTokensWithheld,
		TokenVestingLib.Vesting vesting
	);

	/// @notice Emitted when a vesting ownership is transferred
	/// @param previousOwner Address of the previous vesting owner
	/// @param newOwner Address of the new vesting owner
	/// @param vestingId Unique identifier of the transferred vesting
	event VestingTransferred(
		address indexed previousOwner,
		address indexed newOwner,
		bytes32 indexed vestingId
	);

	/// @notice Emitted when a vesting transfer is initiated
	/// @param currentOwner Address of the current vesting owner
	/// @param newOwner Address of the proposed new vesting owner
	/// @param vestingId Unique identifier of the vesting to be transferred
	event VestingTransferInitiated(
		address indexed currentOwner,
		address indexed newOwner,
		bytes32 indexed vestingId
	);

	/// @notice Emitted when a vesting transfer is cancelled
	/// @param currentOwner Address of the current vesting owner
	/// @param vestingId Unique identifier of the vesting transfer that was cancelled
	event VestingTransferCancelled(
		address indexed currentOwner,
		bytes32 indexed vestingId
	);

	/// @notice The block number when this contract was deployed
	function DEPLOYMENT_BLOCK_NUMBER() external view returns (uint256);

	/// @notice The fee percentage charged for vesting operations
	function FEE() external view returns (uint256);

	/// @notice The type of fee (flat, percentage, etc)
	function FEE_TYPE() external view returns (ITypes.FeeType);

	/// @notice The funding type for vestings (full or partial)
	function FUNDING_TYPE() external view returns (ITypes.FundingType);

	/// @notice Complete a vesting transfer by accepting it as the new owner
	/// @param _vestingId The ID of the vesting to accept
	function acceptVestingTransfer(bytes32 _vestingId) external;

	/// @notice Allows an admin to claim vested tokens on behalf of a recipient
	/// @param _vestingId Unique identifier of the vesting arrangement
	function adminClaim(bytes32 _vestingId) external payable;

	/// @notice Allows an admin to claim vested tokens for multiple vesting arrangements
	/// @param _vestingIds Array of vesting identifiers to claim
	function batchAdminClaim(bytes32[] memory _vestingIds) external payable;

	/// @notice Revokes multiple vesting arrangements in batch
	/// @param _vestingIds Array of vesting identifiers to revoke
	function batchRevokeVestings(bytes32[] memory _vestingIds) external;

	/// @notice Cancels a pending vesting transfer
	/// @param _vestingId The ID of the vesting with a pending transfer
	function cancelVestingTransfer(bytes32 _vestingId) external;

	/// @notice Allows a recipient to claim their vested tokens
	/// @param _vestingId Unique identifier of the recipient's vesting arrangement
	function claim(bytes32 _vestingId) external payable;

	/// @notice Create a vesting schedule for a recipient
	/// @param _recipient Address of the recipient for whom vesting is being created
	/// @param _startTimestamp Start time of the vesting period as a timestamp
	/// @param _endTimestamp End time of the vesting period as a timestamp
	/// @param _timelock Period during which the tokens are locked and cannot be claimed
	/// @param _initialUnlock Amount of tokens that are initially unlocked and claimable at the start time
	/// @param _cliffReleaseTimestamp Timestamp after which the cliff amount can be released
	/// @param _cliffAmount Amount of tokens that are released at once after the cliff period is reached
	/// @param _releaseIntervalSecs Interval in seconds between subsequent releases
	/// @param _linearVestAmount Total amount of tokens that will be vested linearly after the cliff
	/// @param _isRevocable Whether the vesting can be revoked by the admin
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
	) external payable;

	/// @notice Create vesting schedules in batch for multiple recipients
	/// @param params Struct containing arrays of parameters for each vesting schedule
	function createVestingBatch(
		CreateVestingBatchParams memory params
	) external payable;

	/// @notice Direct transfer of vesting ownership
	/// @param _vestingId The ID of the vesting to transfer
	/// @param _newOwner The address of the new owner
	/// @dev This is specifically for compatibility with contracts that cannot call acceptVestingTransfer
	function directVestingTransfer(
		bytes32 _vestingId,
		address _newOwner
	) external;

	/// @notice Returns the address of the current fee collector
	/// @return Address of the fee collector
	function feeCollector() external view returns (address);

	/// @notice Adds funding to a vesting schedule
	/// @param _vestingId The identifier of the vesting to fund
	function fundVesting(bytes32 _vestingId) external payable;

	/// @notice Adds funding to multiple vesting schedules in batch
	/// @param _vestingIds Array of vesting identifiers to fund
	/// @param _fundingAmounts Array of funding amounts for each vesting
	function fundVestingBatch(
		bytes32[] memory _vestingIds,
		uint256[] memory _fundingAmounts
	) external payable;

	/// @notice Get all vesting IDs for a specific recipient
	/// @param _recipient Address of the recipient
	/// @return Array of vesting IDs belonging to the recipient
	function getAllRecipientVestings(
		address _recipient
	) external view returns (bytes32[] memory);

	/// @notice Get the number of vestings for a specific recipient
	/// @param _recipient Address of the recipient
	/// @return Number of vestings for the recipient
	function getAllRecipientVestingsLength(
		address _recipient
	) external view returns (uint256);

	/// @notice Get a slice of vesting IDs for a specific recipient
	/// @param _from Start index (inclusive)
	/// @param _to End index (exclusive)
	/// @param _recipient Address of the recipient
	/// @return Array of vesting IDs in the specified range
	function getAllRecipientVestingsSliced(
		uint256 _from,
		uint256 _to,
		address _recipient
	) external view returns (bytes32[] memory);

	/// @notice Fetches a list of all recipient addresses who have at least one vesting schedule
	/// @return An array of addresses, each representing a recipient with an active or historical vesting schedule
	function getAllRecipients() external view returns (address[] memory);

	/// @notice Get the total number of recipients
	/// @return Number of recipients
	function getAllRecipientsLength() external view returns (uint256);

	/// @notice Get a slice of recipient addresses
	/// @param _from Start index (inclusive)
	/// @param _to End index (exclusive)
	/// @return Array of recipient addresses in the specified range
	function getAllRecipientsSliced(
		uint256 _from,
		uint256 _to
	) external view returns (address[] memory);

	/// @notice Get the amount of tokens that can be claimed from a vesting
	/// @param _vestingId The identifier of the vesting
	/// @return claimable The amount of tokens that can be claimed
	function getClaimableAmount(
		bytes32 _vestingId
	) external view returns (uint256 claimable);

	/// @notice Checks if a vesting has a pending transfer
	/// @param _vestingId The ID of the vesting to check
	/// @return The address of the pending owner if there is one, or zero address if none
	function getPendingVestingTransfer(
		bytes32 _vestingId
	) external view returns (address);

	/// @notice Get the amount of tokens that have vested by a specific timestamp
	/// @param _vestingId The identifier of the vesting
	/// @param _referenceTimestamp The timestamp to check vesting status at
	/// @return The amount of tokens vested at the reference timestamp
	function getVestedAmount(
		bytes32 _vestingId,
		uint32 _referenceTimestamp
	) external view returns (uint256);

	/// @notice Get funding information for a vesting schedule
	/// @param _vestingId The identifier of the vesting
	/// @return fundingType The type of funding (Full or Partial)
	/// @return totalFunded Total amount of tokens funded so far
	/// @return totalRequired Total amount of tokens required for full funding
	function getVestingFundingInfo(
		bytes32 _vestingId
	)
		external
		view
		returns (uint8 fundingType, uint256 totalFunded, uint256 totalRequired);

	/// @notice Retrieves information about a specific vesting arrangement
	/// @param _vestingId Unique identifier of the vesting
	/// @return Details of the specified vesting
	function getVestingInfo(
		bytes32 _vestingId
	) external view returns (TokenVestingLib.Vesting memory);

	/// @notice Initiates the transfer of vesting ownership
	/// @param _vestingId The ID of the vesting to transfer
	/// @param _newOwner The address of the new owner
	function initiateVestingTransfer(
		bytes32 _vestingId,
		address _newOwner
	) external;

	/// @notice Determine if a vesting is fully funded
	/// @param _vestingId The identifier of the vesting
	/// @return True if the vesting is fully funded
	function isVestingFullyFunded(
		bytes32 _vestingId
	) external view returns (bool);

	/// @notice Returns the total amount of tokens reserved for vesting
	/// @return Amount of tokens reserved for vesting
	function numTokensReservedForVesting() external view returns (uint256);

	/// @notice Returns the pending transfer address for a vesting ID
	/// @param vestingId The vesting ID to check
	/// @return Address of the pending transfer, if any
	function pendingVestingTransfers(
		bytes32 vestingId
	) external view returns (address);

	/// @notice Returns a vesting ID for a specific recipient at a specific index
	/// @param recipient The recipient address
	/// @param index The index in the recipient's vestings array
	/// @return The vesting ID
	function recipientVestings(
		address recipient,
		uint256 index
	) external view returns (bytes32);

	/// @notice Revokes a vesting arrangement before it has been fully claimed
	/// @param _vestingId Unique identifier of the vesting to be revoked
	function revokeVesting(bytes32 _vestingId) external;

	/// @notice Updates the fee collector address
	/// @param newFeeCollector The new fee collector address
	function transferFeeCollectorRole(address newFeeCollector) external;

	/// @notice Returns the amount of funding for a specific vesting ID
	/// @param vestingId The vesting ID to check
	/// @return Amount of funding for the vesting
	function vestingFunding(bytes32 vestingId) external view returns (uint256);

	/// @notice Allows the admin to withdraw tokens not locked in vesting
	/// @param _amountRequested Amount of tokens the admin wishes to withdraw
	function withdrawAdmin(uint256 _amountRequested) external;

	/// @notice Withdraws gas fees (ETH) collected by the contract
	/// @param recipient Address to receive the fees
	/// @param amount Amount of ETH to withdraw
	function withdrawGasFee(address recipient, uint256 amount) external;

	/// @notice Withdraws tokens accidentally sent to the contract's address
	/// @param _otherTokenAddress Address of the token to be withdrawn
	function withdrawOtherToken(address _otherTokenAddress) external;
}
