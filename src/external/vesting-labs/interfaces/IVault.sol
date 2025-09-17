// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC5805 } from "@openzeppelin/contracts/interfaces/IERC5805.sol"; // OpenZeppelin's ERC20Votes interface

/**
 * @title IVault
 * @notice Interface for a Vault contract that holds vested tokens and enables delegating voting power
 * @author Maurizio Murru (https://www.linkedin.com/in/mauriziomurru/)
 */
interface IVault {
	/**
	 * @notice Event emitted when tokens are released to the beneficiary
	 * @param beneficiary The address receiving the tokens
	 * @param amount The amount of tokens released
	 */
	event TokensReleased(address indexed beneficiary, uint256 amount);

	/**
	 * @notice Event emitted when voting power is delegated
	 * @param delegator The vault address
	 * @param delegatee The address receiving delegation
	 */
	event VotingPowerDelegated(
		address indexed delegator,
		address indexed delegatee
	);
	/**
	 * @notice Event emitted when tokens are revoked from the vault
	 * @param beneficiary The address receiving the tokens
	 */
	event TokensRevoked(address indexed beneficiary);

	/**
	 * @notice Initializes the vault
	 * @param token_ The ERC20Votes token to be vested
	 * @param beneficiary_ The address that will receive the vested tokens
	 * @param vestingManager_ The address of the vesting manager contract
	 */
	function initialize(
		address token_,
		address beneficiary_,
		address vestingManager_
	) external;

	/**
	 * @notice Releases the vested tokens to the beneficiary
	 * @param amount The amount of tokens to release
	 * @return The amount of tokens released
	 */
	function release(uint256 amount) external returns (uint256);

	/**
	 * @notice Revokes the vested tokens and transfers them to the beneficiary
	 * @param amount The amount of tokens to revok
	 */
	function revoke(uint256 amount) external;

	/**
	 * @notice Withdraws the fee from the vault
	 * @param amount The amount of tokens to withdraw
	 * @return The amount of tokens withdrawn
	 */
	function withdrawFee(uint256 amount) external returns (uint256);

	/**
	 * @notice Changes the beneficiary of the vault
	 * @param newBeneficiary The address of the new beneficiary
	 */
	function changeBeneficiary(address newBeneficiary) external;

	/**
	 * @notice Delegates voting power to a delegatee
	 * @param delegatee The address to delegate voting power to
	 */
	function delegate(address delegatee) external;

	function getPastVotes(
		address account,
		uint256 blockNumber
	) external view returns (uint256);
	function getVotes(address account) external view returns (uint256);
	function getClockMode() external view returns (string memory);
	function getClock() external view returns (uint48);

	/**
	 * @notice Returns the amount of tokens held by the vault
	 * @return The balance of tokens in the vault
	 */
	function balance() external view returns (uint256);
}
