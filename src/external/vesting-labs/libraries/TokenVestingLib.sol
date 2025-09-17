// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Errors } from "src/external/vesting-labs/libraries/Errors.sol";

library TokenVestingLib {
	/**
	 * @notice A structure representing a Vesting - supporting linear and cliff vesting.
	 * @param releaseIntervalSecs used for calculating the vested amount
	 * @param linearVestAmount vesting allocation, excluding cliff
	 * @param claimedAmount claimed so far, excluding cliff
	 */
	struct Vesting {
		address recipient; // 160 bits 160/256 slot space - 1st slot
		uint32 startTimestamp; // 32 bits 192/256 slot space - 1st slot
		uint32 endTimestamp; // 32 bits  224/256 slot space - 1st slot
		uint32 deactivationTimestamp; // 32 bits 256/256 slot space - 1st slot
		uint32 timelock; // 32 bits 32/256 slot space - 2nd slot
		uint32 releaseIntervalSecs; // 32 bits 64/256 slot space - 2nd slot
		uint32 cliffReleaseTimestamp; // 32 bits 96/256 slot space - 2nd slot
		uint256 initialUnlock; // 256 bits 256/256 slot space - 3nd slot
		uint256 cliffAmount; // 256 bits 256/256 slot space - 4nd slots
		uint256 linearVestAmount; // 256 bits 256/256 slot space - 5th slot
		uint256 claimedAmount; // 256 bits 256/256 slot space - 6th slot
		bool isRevocable; // Flag to determine if vesting can be revoked
	}

	/**
	 * @notice A structure representing a Vesting - supporting linear and cliff vesting.
	 * @param _vestingId The ID of the vesting
	 * @param _recipient The recipient of the vesting
	 * @param _startTimestamp The start timestamp of the vesting
	 * @param _endTimestamp The end timestamp of the vesting
	 * @param _timelock The timelock period for the vesting
	 * @param _initialUnlock The initial unlock amount for the vesting
	 * @param _cliffReleaseTimestamp The cliff release timestamp for the vesting
	 * @param _cliffAmount The cliff amount for the vesting
	 * @param _releaseIntervalSecs The release interval in seconds for the vesting
	 * @param _linearVestAmount The linear vest amount for the vesting
	 * @param _isRevocable Flag to determine if vesting can be revoked
	 */
	struct VestingParams {
		bytes32 _vestingId;
		address _recipient;
		uint32 _startTimestamp;
		uint32 _endTimestamp;
		uint32 _timelock;
		uint256 _initialUnlock;
		uint32 _cliffReleaseTimestamp;
		uint256 _cliffAmount;
		uint32 _releaseIntervalSecs;
		uint256 _linearVestAmount;
		bool _isRevocable;
	}

	/**
	 * @notice Calculate the vested amount for a given Vesting, at a given timestamp.
	 * @param _vesting The vesting in question
	 * @param _referenceTimestamp Timestamp for which we're calculating
	 */
	function calculateVestedAmount(
		Vesting memory _vesting,
		uint32 _referenceTimestamp
	) internal pure returns (uint256) {
		// Does the Vesting exist?
		if (_vesting.deactivationTimestamp != 0) {
			if (_referenceTimestamp > _vesting.deactivationTimestamp) {
				_referenceTimestamp = _vesting.deactivationTimestamp;
			}
		}

		uint256 vestingAmount;

		// Has the Vesting ended?
		if (_referenceTimestamp > _vesting.endTimestamp) {
			_referenceTimestamp = _vesting.endTimestamp;
		}

		// Has the start passed?
		if (_referenceTimestamp >= _vesting.startTimestamp) {
			vestingAmount += _vesting.initialUnlock;
		}

		// Has the cliff passed?
		if (_referenceTimestamp >= _vesting.cliffReleaseTimestamp) {
			vestingAmount += _vesting.cliffAmount;
		}

		// Has the vesting started? If so, calculate the vested amount linearly
		uint256 startTimestamp;
		if (_vesting.cliffReleaseTimestamp != 0) {
			startTimestamp = _vesting.cliffReleaseTimestamp;
		} else {
			startTimestamp = _vesting.startTimestamp;
		}
		if (_referenceTimestamp > startTimestamp) {
			uint256 currentVestingDurationSecs = _referenceTimestamp -
				startTimestamp;

			// Round to releaseIntervalSecs
			uint256 truncatedCurrentVestingDurationSecs = (currentVestingDurationSecs /
					_vesting.releaseIntervalSecs) *
					_vesting.releaseIntervalSecs;

			uint256 finalVestingDurationSecs = _vesting.endTimestamp -
				startTimestamp;

			// Calculate vested amount
			uint256 linearVestAmount = (_vesting.linearVestAmount *
				truncatedCurrentVestingDurationSecs) / finalVestingDurationSecs;

			vestingAmount += linearVestAmount;
		}
		return vestingAmount;
	}
}
