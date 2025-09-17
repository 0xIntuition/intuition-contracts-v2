// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "src/external/vesting-labs/libraries/Errors.sol";

/**
@title Access Limiter to multiple owner-specified accounts.
@dev Exposes the onlyAdmin modifier, which will revert (AdminAccessRequired) if the caller is not the owner nor the admin.
@notice An address with the role admin can grant that role to or revoke that role from any address via the function setAdmin().
*/
abstract contract AccessProtected is Context {
	mapping(address => bool) private _admins; // user address => admin? mapping
	uint256 public adminCount;

	event AdminAccessSet(address indexed _admin, bool _enabled);

	constructor() {
		_admins[_msgSender()] = true;
		adminCount = 1;
		emit AdminAccessSet(_msgSender(), true);
	}

	/**
	 * Throws if called by any account that isn't an admin or an owner.
	 */
	modifier onlyAdmin() {
		if (!_admins[_msgSender()]) revert Errors.AdminAccessRequired();
		_;
	}

	function isAdmin(address _addressToCheck) external view returns (bool) {
		return _admins[_addressToCheck];
	}

	/**
	 * @notice Set/unset Admin Access for a given address.
	 *
	 * @param admin - Address of the new admin (or the one to be removed)
	 * @param isEnabled - Enable/Disable Admin Access
	 */
	function setAdmin(address admin, bool isEnabled) public onlyAdmin {
		if (admin == address(0)) revert Errors.InvalidAddress();
		if (_admins[admin] == isEnabled)
			revert Errors.AdminStatusAlreadyActive();

		if (isEnabled) {
			adminCount++;
		} else {
			if (adminCount <= 1) revert Errors.CannotRemoveLastAdmin();
			adminCount--;
		}

		_admins[admin] = isEnabled;
		emit AdminAccessSet(admin, isEnabled);
	}
}
