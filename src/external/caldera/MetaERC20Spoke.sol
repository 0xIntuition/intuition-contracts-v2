// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.26 >=0.6.11 >=0.8.0 ^0.8.0 ^0.8.1 ^0.8.2;

// node_modules/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions
     * pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success,) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use
     * https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    )
        internal
        returns (bytes memory)
    {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    )
        internal
        returns (bytes memory)
    {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    )
        internal
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    )
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    )
        internal
        view
        returns (bytes memory)
    {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    )
        internal
        pure
        returns (bytes memory)
    {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// node_modules/@openzeppelin/contracts-upgradeable/interfaces/IERC5313Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC5313.sol)

/**
 * @dev Interface for the Light Contract Ownership Standard.
 *
 * A standardized minimal interface required to identify an account that controls a contract
 *
 * _Available since v4.9._
 */
interface IERC5313Upgradeable {
    /**
     * @dev Gets the address of the owner.
     */
    function owner() external view returns (address);
}

// src/interfaces/IMetalayerRecipient.sol

/**
 * @title IMetalayerRecipient
 * @notice Interface for contracts that can receive messages through the Metalayer protocol
 * @dev Implement this interface to receive cross-chain messages and read results from Metalayer
 */
interface IMetalayerRecipient {
    /**
     * @notice Handles an incoming message from another chain via Metalayer
     * @dev This function is called by the MetalayerRouter when a message is delivered
     * @param _origin The domain ID of the chain where the message originated
     * @param _sender The address of the contract that sent the message on the origin chain
     * @param _message The payload of the message to be handled
     * @param _reads Array of read operations that were requested in the original message
     * @param _readResults Array of results from the read operations, provided by the relayer
     * @custom:security The caller must be the MetalayerRouter contract
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message,
        ReadOperation[] calldata _reads,
        bytes[] calldata _readResults
    )
        external
        payable;
}

/**
 * @notice Represents a cross-chain read operation
 * @dev Used to specify what data should be read from other chains.
 * The read operations are only compatible with EVM chains, so the
 * target is packed as an address to save bytes.
 */
struct ReadOperation {
    /// @notice The domain ID of the chain to read from
    uint32 domain;
    /// @notice The address of the contract to read from
    address target;
    /// @notice The calldata to execute on the target contract
    bytes callData;
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always
            // >= 1. See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// src/lib/MetaERC20Types.sol

/// @title MetaERC20MessageType
/// @notice Enumerates supported MetaERC20 message intents for cross-chain dispatch
enum MetaERC20MessageType {
    /// @notice Mint synthetic tokens on the destination chain
    MintRequest,
    /// @notice Unlock canonical tokens on the destination chain
    UnlockRequest,
    /// @notice Relays a Spoke-to-Spoke transfer via the Hub for security inspection
    SecurityRelay,
    /// @notice Admin-triggered reissuance or override action
    AdminAction,
    /// @dev Sentinel value for bounds checking and enum size
    __MessageTypeCount
}

/// @title MetaERC20MessageStruct
/// @notice Fully packed message used for MetaERC20 cross-chain communication
/// @dev Serialized as a 128-byte abi.encodePacked payload with no dynamic fields.
///      Layout: transferId(32) + timestamp(32) + version(1) + messageType(1) +
///      padding(5) + sourceDecimals(1) + recipientDomain(4) + recipient(20) + amount(32)
struct MetaERC20MessageStruct {
    /// @notice Unique ID for this transfer, generated deterministically at source
    bytes32 transferId;
    /// @notice Local block.timestamp when the message was created at source
    uint256 timestamp;
    /// @notice Version of the MetaERC20 message protocol used
    uint8 metaERC20Version;
    /// @notice Type of message intent (MintRequest, UnlockRequest, SecurityRelay, AdminAction)
    MetaERC20MessageType messageType;
    // 5 bytes padding (bytes 66-70)

    /// @notice Number of decimal places used by the source token (e.g., 6 for USDC, 18 for WETH)
    uint8 sourceDecimals;
    /// @notice Metalayer domain ID of the intended final destination chain
    uint32 recipientDomain;
    /// @notice Address that will receive the tokens on the destination chain
    address recipient;
    /// @notice Amount of tokens in source token's native units (no decimal scaling applied)
    uint256 amount;
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 248 bits");
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 240 bits");
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 232 bits");
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 224 bits");
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 216 bits");
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 208 bits");
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 200 bits");
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 192 bits");
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 184 bits");
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 176 bits");
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 168 bits");
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 160 bits");
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 152 bits");
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 144 bits");
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 136 bits");
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 120 bits");
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 112 bits");
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 104 bits");
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 96 bits");
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 88 bits");
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 80 bits");
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 72 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 56 bits");
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 48 bits");
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 40 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/math/SignedMathUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// node_modules/@hyperlane-xyz/core/contracts/libs/TypeCasts.sol

library TypeCasts {
    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        require(uint256(_buf) <= uint256(type(uint160).max), "TypeCasts: bytes32ToAddress overflow");
        return address(uint160(uint256(_buf)));
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/access/IAccessControlDefaultAdminRulesUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/IAccessControlDefaultAdminRules.sol)

/**
 * @dev External interface of AccessControlDefaultAdminRules declared to support ERC165 detection.
 *
 * _Available since v4.9._
 */
interface IAccessControlDefaultAdminRulesUpgradeable is IAccessControlUpgradeable {
    /**
     * @dev Emitted when a {defaultAdmin} transfer is started, setting `newAdmin` as the next
     * address to become the {defaultAdmin} by calling {acceptDefaultAdminTransfer} only after `acceptSchedule`
     * passes.
     */
    event DefaultAdminTransferScheduled(address indexed newAdmin, uint48 acceptSchedule);

    /**
     * @dev Emitted when a {pendingDefaultAdmin} is reset if it was never accepted, regardless of its schedule.
     */
    event DefaultAdminTransferCanceled();

    /**
     * @dev Emitted when a {defaultAdminDelay} change is started, setting `newDelay` as the next
     * delay to be applied between default admin transfer after `effectSchedule` has passed.
     */
    event DefaultAdminDelayChangeScheduled(uint48 newDelay, uint48 effectSchedule);

    /**
     * @dev Emitted when a {pendingDefaultAdminDelay} is reset if its schedule didn't pass.
     */
    event DefaultAdminDelayChangeCanceled();

    /**
     * @dev Returns the address of the current `DEFAULT_ADMIN_ROLE` holder.
     */
    function defaultAdmin() external view returns (address);

    /**
     * @dev Returns a tuple of a `newAdmin` and an accept schedule.
     *
     * After the `schedule` passes, the `newAdmin` will be able to accept the {defaultAdmin} role
     * by calling {acceptDefaultAdminTransfer}, completing the role transfer.
     *
     * A zero value only in `acceptSchedule` indicates no pending admin transfer.
     *
     * NOTE: A zero address `newAdmin` means that {defaultAdmin} is being renounced.
     */
    function pendingDefaultAdmin() external view returns (address newAdmin, uint48 acceptSchedule);

    /**
     * @dev Returns the delay required to schedule the acceptance of a {defaultAdmin} transfer started.
     *
     * This delay will be added to the current timestamp when calling {beginDefaultAdminTransfer} to set
     * the acceptance schedule.
     *
     * NOTE: If a delay change has been scheduled, it will take effect as soon as the schedule passes, making this
     * function returns the new delay. See {changeDefaultAdminDelay}.
     */
    function defaultAdminDelay() external view returns (uint48);

    /**
     * @dev Returns a tuple of `newDelay` and an effect schedule.
     *
     * After the `schedule` passes, the `newDelay` will get into effect immediately for every
     * new {defaultAdmin} transfer started with {beginDefaultAdminTransfer}.
     *
     * A zero value only in `effectSchedule` indicates no pending delay change.
     *
     * NOTE: A zero value only for `newDelay` means that the next {defaultAdminDelay}
     * will be zero after the effect schedule.
     */
    function pendingDefaultAdminDelay() external view returns (uint48 newDelay, uint48 effectSchedule);

    /**
     * @dev Starts a {defaultAdmin} transfer by setting a {pendingDefaultAdmin} scheduled for acceptance
     * after the current timestamp plus a {defaultAdminDelay}.
     *
     * Requirements:
     *
     * - Only can be called by the current {defaultAdmin}.
     *
     * Emits a DefaultAdminRoleChangeStarted event.
     */
    function beginDefaultAdminTransfer(address newAdmin) external;

    /**
     * @dev Cancels a {defaultAdmin} transfer previously started with {beginDefaultAdminTransfer}.
     *
     * A {pendingDefaultAdmin} not yet accepted can also be cancelled with this function.
     *
     * Requirements:
     *
     * - Only can be called by the current {defaultAdmin}.
     *
     * May emit a DefaultAdminTransferCanceled event.
     */
    function cancelDefaultAdminTransfer() external;

    /**
     * @dev Completes a {defaultAdmin} transfer previously started with {beginDefaultAdminTransfer}.
     *
     * After calling the function:
     *
     * - `DEFAULT_ADMIN_ROLE` should be granted to the caller.
     * - `DEFAULT_ADMIN_ROLE` should be revoked from the previous holder.
     * - {pendingDefaultAdmin} should be reset to zero values.
     *
     * Requirements:
     *
     * - Only can be called by the {pendingDefaultAdmin}'s `newAdmin`.
     * - The {pendingDefaultAdmin}'s `acceptSchedule` should've passed.
     */
    function acceptDefaultAdminTransfer() external;

    /**
     * @dev Initiates a {defaultAdminDelay} update by setting a {pendingDefaultAdminDelay} scheduled for getting
     * into effect after the current timestamp plus a {defaultAdminDelay}.
     *
     * This function guarantees that any call to {beginDefaultAdminTransfer} done between the timestamp this
     * method is called and the {pendingDefaultAdminDelay} effect schedule will use the current {defaultAdminDelay}
     * set before calling.
     *
     * The {pendingDefaultAdminDelay}'s effect schedule is defined in a way that waiting until the schedule and then
     * calling {beginDefaultAdminTransfer} with the new delay will take at least the same as another {defaultAdmin}
     * complete transfer (including acceptance).
     *
     * The schedule is designed for two scenarios:
     *
     * - When the delay is changed for a larger one the schedule is `block.timestamp + newDelay` capped by
     * {defaultAdminDelayIncreaseWait}.
     * - When the delay is changed for a shorter one, the schedule is `block.timestamp + (current delay - new delay)`.
     *
     * A {pendingDefaultAdminDelay} that never got into effect will be canceled in favor of a new scheduled change.
     *
     * Requirements:
     *
     * - Only can be called by the current {defaultAdmin}.
     *
     * Emits a DefaultAdminDelayChangeScheduled event and may emit a DefaultAdminDelayChangeCanceled event.
     */
    function changeDefaultAdminDelay(uint48 newDelay) external;

    /**
     * @dev Cancels a scheduled {defaultAdminDelay} change.
     *
     * Requirements:
     *
     * - Only can be called by the current {defaultAdmin}.
     *
     * May emit a DefaultAdminDelayChangeCanceled event.
     */
    function rollbackDefaultAdminDelay() external;

    /**
     * @dev Maximum time in seconds for an increase to {defaultAdminDelay} (that is scheduled using
     * {changeDefaultAdminDelay})
     * to take effect. Default to 5 days.
     *
     * When the {defaultAdminDelay} is scheduled to be increased, it goes into effect after the new delay has passed
     * with
     * the purpose of giving enough time for reverting any accidental change (i.e. using milliseconds instead of
     * seconds)
     * that may lock the contract. However, to avoid excessive schedules, the wait is capped by this function and it can
     * be overrode for a custom {defaultAdminDelay} increase scheduling.
     *
     * IMPORTANT: Make sure to add a reasonable amount of time while overriding this value, otherwise,
     * there's a risk of setting a high new delay that goes into effect almost immediately without the
     * possibility of human intervention in the case of an input error (eg. set milliseconds instead of seconds).
     */
    function defaultAdminDelayIncreaseWait() external view returns (uint48);
}

// node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1)
                || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// src/lib/MetaERC20Message.sol

/// @title MetaERC20Message
/// @notice Library for encoding and decoding MetaERC20 protocol messages
/// @dev Provides low-level serialization for MetaERC20MessageStruct with fixed 128-byte layout.
///      Uses raw amounts with source decimal metadata instead of pre-scaled values for maximum
///      precision and cross-chain compatibility. Supports tokens with any decimal count.
///
/// Message layout (128 bytes total):
/// - transferId (32B) + timestamp (32B) + version (1B) + messageType (1B)
/// - padding (5B) + sourceDecimals (1B) + recipientDomain (4B)
/// - recipient (20B) + amount (32B)
///
/// Key features:
/// - Fixed-size encoding for predictable gas costs
/// - Comprehensive validation during encoding
/// - Raw amount preservation with decimal metadata
/// - Block explorer friendly field ordering (smaller fields grouped)
/// - Zero-tolerance validation for critical fields
///
library MetaERC20Message {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Byte offsets for message field decoding
    uint8 private constant TRANSFERID_OFFSET = 0;
    uint8 private constant TRANSFERID_SIZE = 32;

    uint8 private constant TIMESTAMP_OFFSET = 32;
    uint8 private constant TIMESTAMP_SIZE = 32;

    uint8 private constant VERSION_OFFSET = 64;
    uint8 private constant VERSION_SIZE = 1;

    uint8 private constant MESSAGETYPE_OFFSET = 65;
    uint8 private constant MESSAGETYPE_SIZE = 1;

    // 5 bytes padding here (66-70)

    uint8 private constant SOURCEDECIMALS_OFFSET = 71;
    uint8 private constant SOURCEDECIMALS_SIZE = 1;

    uint8 private constant RECIPIENTDOMAIN_OFFSET = 72;
    uint8 private constant RECIPIENTDOMAIN_SIZE = 4;

    uint8 private constant RECIPIENT_OFFSET = 76;
    uint8 private constant RECIPIENT_SIZE = 20;

    uint8 private constant AMOUNT_OFFSET = 96;
    uint8 private constant AMOUNT_SIZE = 32;

    /// @dev Fixed size of a MetaERC20MessageStruct when encoded (128 bytes)
    uint8 private constant MESSAGE_SIZE = 128;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when attempting to decode a message shorter than MESSAGE_SIZE
    error IncompleteMessage();

    /// @notice Thrown when encoding a message with an unknown or out-of-bounds messageType
    error InvalidMessageType(uint8 messageType);

    /// @notice Thrown when encoding a message with version == 0 (unsupported)
    error UnsupportedVersion(uint8 version);

    /// @notice Thrown when encoding a message with recipientDomain == 0
    error ZeroRecipientDomain();

    /// @notice Thrown when encoding a message with timestamp == 0
    error ZeroTimestamp();

    /// @notice Thrown when attempting to encode a message with zero transferId
    error ZeroTransferId();

    /// @notice Thrown when encoding a message with a zero recipient address
    error ZeroRecipient();

    /*//////////////////////////////////////////////////////////////
                            DECODERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes a MetaERC20 message from raw calldata
    /// @param _data ABI-encoded message bytes (expected length = MESSAGE_SIZE)
    /// @return msgStruct Decoded MetaERC20MessageStruct
    function decodeMessage(bytes calldata _data) internal pure returns (MetaERC20MessageStruct memory msgStruct) {
        if (_data.length < MESSAGE_SIZE) revert IncompleteMessage();

        msgStruct.transferId = bytes32(_data[TRANSFERID_OFFSET:TRANSFERID_OFFSET + TRANSFERID_SIZE]);
        msgStruct.timestamp = uint256(bytes32(_data[TIMESTAMP_OFFSET:TIMESTAMP_OFFSET + TIMESTAMP_SIZE]));
        msgStruct.metaERC20Version = uint8(_data[VERSION_OFFSET]);
        msgStruct.messageType = MetaERC20MessageType(uint8(_data[MESSAGETYPE_OFFSET]));
        msgStruct.sourceDecimals = uint8(_data[SOURCEDECIMALS_OFFSET]);
        msgStruct.recipientDomain =
            uint32(bytes4(_data[RECIPIENTDOMAIN_OFFSET:RECIPIENTDOMAIN_OFFSET + RECIPIENTDOMAIN_SIZE]));
        msgStruct.recipient = address(bytes20(_data[RECIPIENT_OFFSET:RECIPIENT_OFFSET + RECIPIENT_SIZE]));
        msgStruct.amount = uint256(bytes32(_data[AMOUNT_OFFSET:AMOUNT_OFFSET + AMOUNT_SIZE]));

        return msgStruct;
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encodes a MetaERC20MessageStruct into bytes
    /// @param _message The fully populated message struct
    /// @return Encoded bytes representation of the message (length = MESSAGE_SIZE)
    function encodeMessage(MetaERC20MessageStruct memory _message) internal pure returns (bytes memory) {
        if (_message.transferId == bytes32(0)) revert ZeroTransferId();
        if (_message.timestamp == 0) revert ZeroTimestamp();
        if (_message.metaERC20Version == 0) revert UnsupportedVersion(0);
        if (uint8(_message.messageType) >= uint8(MetaERC20MessageType.__MessageTypeCount)) {
            revert InvalidMessageType(uint8(_message.messageType));
        }
        if (_message.recipientDomain == 0) revert ZeroRecipientDomain();
        if (_message.recipient == address(0)) revert ZeroRecipient();

        return abi.encodePacked(
            _message.transferId, // 32 bytes (0-31)
            _message.timestamp, // 32 bytes (32-63)
            _message.metaERC20Version, // 1 byte  (64)
            uint8(_message.messageType), // 1 byte  (65)
            bytes5(0), // 5 bytes padding (66-70)
            _message.sourceDecimals, // 1 byte  (71)
            _message.recipientDomain, // 4 bytes (72-75)
            _message.recipient, // 20 bytes (76-95)
            _message.amount // 32 bytes (96-127)
        ); // Total: 128 bytes
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing { }

    function __Context_init_unchained() internal onlyInitializing { }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// src/lib/MetalayerMessage.sol

enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

/**
 * @title Metalayer Message Library
 * @notice Library for formatted messages for the metalayer. These will be the message body of Hyperlane messages.
 *
 */
library MetalayerMessage {
    using TypeCasts for bytes32;

    /**
     * @notice Safely casts uint256 to uint32, reverting on overflow
     * @param value The value to cast
     * @return The value as uint32
     */
    function safeCastToUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "MetalayerMessage: value exceeds uint32 range");
        return uint32(value);
    }

    uint256 private constant VERSION_OFFSET = 0;
    uint256 private constant FINALITY_STATE_FLAG_OFFSET = 1;
    uint256 private constant NONCE_OFFSET = 2;
    uint256 private constant ORIGIN_OFFSET = 6;
    uint256 private constant SENDER_OFFSET = 10;
    uint256 private constant DESTINATION_OFFSET = 42;
    uint256 private constant RECIPIENT_OFFSET = 46;
    uint256 private constant BODY_OFFSET = 78;

    // Constants for read operation parsing within message body
    uint256 private constant READ_COUNT_OFFSET = 0;
    uint256 private constant READS_OFFSET = 4; // uint32 size for read count

    /**
     * @notice Returns formatted message supporting multiple read operations
     * @param _version The version of the origin and destination Mailboxes
     * @param _finalityState What sort of finality we should wait for before the message is valid. Currently only have 0
     * for instant, 1 for final.
     * @param _nonce A nonce to uniquely identify the message on its origin chain
     * @param _originDomain Domain of origin chain
     * @param _sender Address of sender
     * @param _destinationDomain Domain of destination chain
     * @param _recipient Address of recipient on destination chain
     * @param _reads Array of read operations to perform
     * @param _writeCallData The call data for the final write operation
     * @return Formatted message with reads
     */
    function formatMessageWithReads(
        uint8 _version,
        FinalityState _finalityState,
        uint32 _nonce,
        uint32 _originDomain,
        bytes32 _sender,
        uint32 _destinationDomain,
        bytes32 _recipient,
        ReadOperation[] memory _reads,
        bytes memory _writeCallData
    )
        internal
        pure
        returns (bytes memory)
    {
        uint256 _readsLength = _reads.length;
        bytes memory messageBody = abi.encodePacked(safeCastToUint32(_readsLength));

        // this is n^2 -> optimize later by just preallocating the appropriate size
        // can keep slow for test
        for (uint256 i = 0; i < _readsLength; i++) {
            messageBody = abi.encodePacked(
                messageBody,
                _reads[i].domain,
                _reads[i].target,
                safeCastToUint32(_reads[i].callData.length),
                _reads[i].callData
            );
        }

        messageBody = abi.encodePacked(messageBody, _writeCallData);

        return abi.encodePacked(
            _version, uint8(_finalityState), _nonce, _originDomain, _sender, _destinationDomain, _recipient, messageBody
        );
    }

    /**
     * @notice Returns the message ID.
     * @param _message ABI encoded Metalayer message.
     * @return ID of `_message`
     */
    function id(bytes memory _message) internal pure returns (bytes32) {
        return keccak256(_message);
    }

    /**
     * @notice Returns the message version
     * @param _message ABI encoded Metalayer message
     * @return Version of `_message`
     */
    function version(bytes calldata _message) internal pure returns (uint8) {
        return uint8(bytes1(_message[VERSION_OFFSET:FINALITY_STATE_FLAG_OFFSET]));
    }

    /**
     * @notice Returns the message nonce
     * @param _message ABI encoded Metalayer message
     * @return Nonce of `_message`
     */
    function nonce(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[NONCE_OFFSET:ORIGIN_OFFSET]));
    }

    /**
     * @notice Returns whether the message should use finalized ISM
     * @param _message ABI encoded Metalayer message
     * @return Whether to use finalized ISM
     */
    function finalityState(bytes calldata _message) internal pure returns (FinalityState) {
        return FinalityState(uint8(bytes1(_message[FINALITY_STATE_FLAG_OFFSET:NONCE_OFFSET])));
    }

    /**
     * @notice Returns the message origin domain
     * @param _message ABI encoded Metalayer message
     * @return Origin domain of `_message`
     */
    function origin(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[ORIGIN_OFFSET:SENDER_OFFSET]));
    }

    /**
     * @notice Returns the message sender as address
     * @param _message ABI encoded Metalayer message
     * @return Sender of `_message` as a bytes32-encoded address
     */
    function senderAddress(bytes calldata _message) internal pure returns (bytes32) {
        return bytes32(_message[SENDER_OFFSET:DESTINATION_OFFSET]);
    }

    /**
     * @notice Returns the message destination domain
     * @param _message ABI encoded Metalayer message
     * @return Destination domain of `_message`
     */
    function destination(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(_message[DESTINATION_OFFSET:RECIPIENT_OFFSET]));
    }

    /**
     * @notice Returns the message recipient as address. We only support evm chains for now, so address only.
     * @param _message ABI encoded Metalayer message
     * @return Recipient of `_message` as address
     */
    function recipientAddress(bytes calldata _message) internal pure returns (bytes32) {
        return bytes32(_message[RECIPIENT_OFFSET:BODY_OFFSET]);
    }

    /**
     * @notice Returns the message body
     * @param _message ABI encoded Metalayer message
     * @return Body of `_message`
     */
    function body(bytes calldata _message) internal pure returns (bytes calldata) {
        return bytes(_message[BODY_OFFSET:]);
    }

    /**
     * @notice Returns the number of read operations in the message
     * @param _message ABI encoded Metalayer message
     * @return Number of read operations
     */
    function readCount(bytes calldata _message) internal pure returns (uint32) {
        return uint32(bytes4(body(_message)[READ_COUNT_OFFSET:READS_OFFSET]));
    }

    /**
     * @notice Returns the read operation at the specified index
     * @param _message ABI encoded Metalayer message
     * @param _index Index of the read operation to retrieve
     * @return The read operation at the specified index
     */
    function getRead(bytes calldata _message, uint256 _index) internal pure returns (ReadOperation memory) {
        require(_index < readCount(_message), "Index out of bounds");

        bytes calldata messageBody = body(_message);
        uint256 currentOffset = READS_OFFSET;

        for (uint256 i = 0; i < _index; i++) {
            uint256 lesserCallDataLength = uint32(bytes4(messageBody[currentOffset + 24:currentOffset + 28]));
            currentOffset += 28 + lesserCallDataLength; // 4 (domain) + 20 (contract) + 4 (length) +
            // lesserCallDataLength
        }

        // first 4 bytes are the uint32 sourceChainId.
        uint32 sourceChainId = uint32(bytes4(messageBody[currentOffset:currentOffset + 4]));
        // next 20 bytes are the address of the contract to read from. Offset computed as starting after the previous 4
        // bytes, ending 20 bytes later (==24)
        address sourceContract = address(bytes20(messageBody[currentOffset + 4:currentOffset + 24]));
        // next 4 bytes are the uint32 length of the call data. Offset computed as starting after the previous 24 bytes,
        // ending 4 bytes later (==28)
        uint256 callDataLength = uint32(bytes4(messageBody[currentOffset + 24:currentOffset + 28]));
        // next callDataLength bytes are the call data. Offset computed as starting after the previous 28 bytes, ending
        // callDataLength bytes later (==28 + callDataLength)
        bytes calldata callData = messageBody[currentOffset + 28:currentOffset + 28 + callDataLength];

        return ReadOperation({ domain: sourceChainId, target: sourceContract, callData: callData });
    }

    /**
     * @notice Returns all read operations from the message. Use this instead of getRead repeatedly if you want all
     * operations as that is O(n) to find one read, O(n^2) total.
     * @param _message ABI encoded Metalayer message
     * @return Array of all read operations
     */
    function reads(bytes calldata _message) internal pure returns (ReadOperation[] memory) {
        uint256 numReads = readCount(_message);
        ReadOperation[] memory tempReads = new ReadOperation[](numReads);

        bytes calldata messageBody = body(_message);
        uint256 currentOffset = READS_OFFSET;

        for (uint256 i = 0; i < numReads; i++) {
            // first 4 bytes are the uint32 sourceChainId. Offset computed as starting at the current offset, ending 4
            // bytes later (==4)
            uint32 sourceChainId = uint32(bytes4(messageBody[currentOffset:currentOffset + 4]));
            // next 20 bytes are the address of the contract to read from. Offset computed as starting after the
            // previous 4 bytes, ending 20 bytes later (==24)
            address sourceContract = address(bytes20(messageBody[currentOffset + 4:currentOffset + 24]));
            // next 4 bytes are the uint32 length of the call data. Offset computed as starting after the previous 24
            // bytes, ending 4 bytes later (==28)
            uint256 callDataLength = uint32(bytes4(messageBody[currentOffset + 24:currentOffset + 28]));
            // next callDataLength bytes are the call data. Offset computed as starting after the previous 28 bytes,
            // ending callDataLength bytes later (==28 + callDataLength)
            bytes calldata callData = messageBody[currentOffset + 28:currentOffset + 28 + callDataLength];

            tempReads[i] = ReadOperation({ domain: sourceChainId, target: sourceContract, callData: callData });

            currentOffset += 28 + callDataLength; // 4 (domain) + 20 (contract) + 4 (length) + callDataLength
        }

        return tempReads;
    }

    /**
     * @notice Returns the write call data from the message
     * @param _message ABI encoded Metalayer message
     * @return The write call data
     */
    function writeCallData(bytes calldata _message) internal pure returns (bytes calldata) {
        bytes calldata messageBody = body(_message);
        uint256 currentOffset = READS_OFFSET;

        uint256 numReads = readCount(_message);
        for (uint256 i = 0; i < numReads; i++) {
            // an encoded read operation starts with 4 bytes for the sourceChainId, 20 bytes for the contract address, 4
            // bytes for the callDataLength, and then the callDataLength bytes for the callData. calldata length can be
            // extracted as the uint32 beginning after the sourceChainId and contract address (20+4=24 bytes in total),
            // and ending 4 bytes later (==28).
            uint256 callDataLength = uint32(bytes4(messageBody[currentOffset + 24:currentOffset + 28]));
            // the next callDataLength bytes are the call data. This read ends after the 28 byte header and the
            // callDataLength bytes.
            currentOffset += 28 + callDataLength;
        }

        return messageBody[currentOffset:];
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing { }

    function __ERC165_init_unchained() internal onlyInitializing { }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// src/interfaces/IMetalayerRouter.sol

interface IMetalayerRouter {
    /**
     * @notice Dispatches a message to the destination domain & recipient with the given reads and write.
     * @dev Convenience function for EVM chains.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as bytes32
     * @param _reads Read operations
     * @param _writeCallData The raw bytes to be called on the recipient address.
     * @param _finalityState What sort of finality we should wait for before the message is valid. Currently only have 0
     * for instant, 1 for final.
     * @param _gasLimit The gas limit for the submission transaction on the destination chain
     */
    function dispatch(
        uint32 _destinationDomain,
        address _recipientAddress,
        ReadOperation[] memory _reads, // can be empty
        bytes memory _writeCallData,
        FinalityState _finalityState,
        uint256 _gasLimit
    )
        external
        payable;

    /**
     * @notice Dispatches a message to the destination domain & recipient with the given reads and write.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as bytes32
     * @param _reads Read operations
     * @param _writeCallData The raw bytes to be called on the recipient address.
     * @param _finalityState What sort of finality we should wait for before the message is valid. Currently only have 0
     * for instant, 1 for final.
     * @param _gasLimit The gas limit for the submission transaction on the destination chain
     */
    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        ReadOperation[] memory _reads, // can be empty
        bytes memory _writeCallData,
        FinalityState _finalityState,
        uint256 _gasLimit
    )
        external
        payable;

    /**
     * @notice Quotes the Metalayer gas fee for a message to the destination domain & recipient with the given reads and
     * write.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as bytes32
     * @param _reads Read operations
     * @param _writeCallData The raw bytes to be called on the recipient address.
     * @param _finalityState What sort of finality we should wait for before the message is valid. Currently only have 0
     * for instant, 1 for final.
     * @param _gasLimit The gas limit for the submission transaction on the destination chain
     */
    function quoteDispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        ReadOperation[] calldata _reads, // can be empty
        bytes calldata _writeCallData,
        FinalityState _finalityState,
        uint256 _gasLimit
    )
        external
        view
        returns (uint256);

    /**
     * @notice Quotes the Metalayer gas fee for a message to the destination domain & recipient with the given reads and
     * write.
     * @param _destinationDomain Domain of destination chain
     * @param _recipientAddress Address of recipient on destination chain as address
     * @param _reads Read operations
     * @param _writeCallData The raw bytes to be called on the recipient address.
     * @param _finalityState What sort of finality we should wait for before the message is valid. Currently only have 0
     * for instant, 1 for final.
     * @param _gasLimit The gas limit for the submission transaction on the destination chain
     */
    function quoteDispatch(
        uint32 _destinationDomain,
        address _recipientAddress,
        ReadOperation[] calldata _reads, // can be empty
        bytes calldata _writeCallData,
        FinalityState _finalityState,
        uint256 _gasLimit
    )
        external
        view
        returns (uint256);

    /**
     * @notice Computes quote for dipatching a message to the destination domain & recipient
     * using the default hook and empty metadata.
     * @param destinationDomain Domain of destination chain
     * @param recipientAddress Address of recipient on destination chain as bytes32
     * @param messageBody Raw bytes content of message body
     * @return fee The payment required to dispatch the message
     */
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    )
        external
        view
        returns (uint256 fee);
}

// node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        internal
    {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool)))
            && AddressUpgradeable.isContract(address(token));
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// node_modules/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is
    Initializable,
    ContextUpgradeable,
    IAccessControlUpgradeable,
    ERC165Upgradeable
{
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing { }

    function __AccessControl_init_unchained() internal onlyInitializing { }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// node_modules/@openzeppelin/contracts-upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControlDefaultAdminRules.sol)

/**
 * @dev Extension of {AccessControl} that allows specifying special rules to manage
 * the `DEFAULT_ADMIN_ROLE` holder, which is a sensitive role with special permissions
 * over other roles that may potentially have privileged rights in the system.
 *
 * If a specific role doesn't have an admin role assigned, the holder of the
 * `DEFAULT_ADMIN_ROLE` will have the ability to grant it and revoke it.
 *
 * This contract implements the following risk mitigations on top of {AccessControl}:
 *
 * * Only one account holds the `DEFAULT_ADMIN_ROLE` since deployment until it's potentially renounced.
 * * Enforces a 2-step process to transfer the `DEFAULT_ADMIN_ROLE` to another account.
 * * Enforces a configurable delay between the two steps, with the ability to cancel before the transfer is accepted.
 * * The delay can be changed by scheduling, see {changeDefaultAdminDelay}.
 * * It is not possible to use another role to manage the `DEFAULT_ADMIN_ROLE`.
 *
 * Example usage:
 *
 * ```solidity
 * contract MyToken is AccessControlDefaultAdminRules {
 *   constructor() AccessControlDefaultAdminRules(
 *     3 days,
 *     msg.sender // Explicit initial `DEFAULT_ADMIN_ROLE` holder
 *    ) {}
 * }
 * ```
 *
 * _Available since v4.9._
 */
abstract contract AccessControlDefaultAdminRulesUpgradeable is
    Initializable,
    IAccessControlDefaultAdminRulesUpgradeable,
    IERC5313Upgradeable,
    AccessControlUpgradeable
{
    // pending admin pair read/written together frequently
    address private _pendingDefaultAdmin;
    uint48 private _pendingDefaultAdminSchedule; // 0 == unset

    uint48 private _currentDelay;
    address private _currentDefaultAdmin;

    // pending delay pair read/written together frequently
    uint48 private _pendingDelay;
    uint48 private _pendingDelaySchedule; // 0 == unset

    /**
     * @dev Sets the initial values for {defaultAdminDelay} and {defaultAdmin} address.
     */
    function __AccessControlDefaultAdminRules_init(
        uint48 initialDelay,
        address initialDefaultAdmin
    )
        internal
        onlyInitializing
    {
        __AccessControlDefaultAdminRules_init_unchained(initialDelay, initialDefaultAdmin);
    }

    function __AccessControlDefaultAdminRules_init_unchained(
        uint48 initialDelay,
        address initialDefaultAdmin
    )
        internal
        onlyInitializing
    {
        require(initialDefaultAdmin != address(0), "AccessControl: 0 default admin");
        _currentDelay = initialDelay;
        _grantRole(DEFAULT_ADMIN_ROLE, initialDefaultAdmin);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlDefaultAdminRulesUpgradeable).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC5313-owner}.
     */
    function owner() public view virtual returns (address) {
        return defaultAdmin();
    }

    ///
    /// Override AccessControl role management
    ///

    /**
     * @dev See {AccessControl-grantRole}. Reverts for `DEFAULT_ADMIN_ROLE`.
     */
    function grantRole(
        bytes32 role,
        address account
    )
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't directly grant default admin role");
        super.grantRole(role, account);
    }

    /**
     * @dev See {AccessControl-revokeRole}. Reverts for `DEFAULT_ADMIN_ROLE`.
     */
    function revokeRole(
        bytes32 role,
        address account
    )
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't directly revoke default admin role");
        super.revokeRole(role, account);
    }

    /**
     * @dev See {AccessControl-renounceRole}.
     *
     * For the `DEFAULT_ADMIN_ROLE`, it only allows renouncing in two steps by first calling
     * {beginDefaultAdminTransfer} to the `address(0)`, so it's required that the {pendingDefaultAdmin} schedule
     * has also passed when calling this function.
     *
     * After its execution, it will not be possible to call `onlyRole(DEFAULT_ADMIN_ROLE)` functions.
     *
     * NOTE: Renouncing `DEFAULT_ADMIN_ROLE` will leave the contract without a {defaultAdmin},
     * thereby disabling any functionality that is only available for it, and the possibility of reassigning a
     * non-administrated role.
     */
    function renounceRole(
        bytes32 role,
        address account
    )
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        if (role == DEFAULT_ADMIN_ROLE && account == defaultAdmin()) {
            (address newDefaultAdmin, uint48 schedule) = pendingDefaultAdmin();
            require(
                newDefaultAdmin == address(0) && _isScheduleSet(schedule) && _hasSchedulePassed(schedule),
                "AccessControl: only can renounce in two delayed steps"
            );
            delete _pendingDefaultAdminSchedule;
        }
        super.renounceRole(role, account);
    }

    /**
     * @dev See {AccessControl-_grantRole}.
     *
     * For `DEFAULT_ADMIN_ROLE`, it only allows granting if there isn't already a {defaultAdmin} or if the
     * role has been previously renounced.
     *
     * NOTE: Exposing this function through another mechanism may make the `DEFAULT_ADMIN_ROLE`
     * assignable again. Make sure to guarantee this is the expected behavior in your implementation.
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(defaultAdmin() == address(0), "AccessControl: default admin already granted");
            _currentDefaultAdmin = account;
        }
        super._grantRole(role, account);
    }

    /**
     * @dev See {AccessControl-_revokeRole}.
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        if (role == DEFAULT_ADMIN_ROLE && account == defaultAdmin()) {
            delete _currentDefaultAdmin;
        }
        super._revokeRole(role, account);
    }

    /**
     * @dev See {AccessControl-_setRoleAdmin}. Reverts for `DEFAULT_ADMIN_ROLE`.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual override {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't violate default admin rules");
        super._setRoleAdmin(role, adminRole);
    }

    ///
    /// AccessControlDefaultAdminRules accessors
    ///

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function defaultAdmin() public view virtual returns (address) {
        return _currentDefaultAdmin;
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function pendingDefaultAdmin() public view virtual returns (address newAdmin, uint48 schedule) {
        return (_pendingDefaultAdmin, _pendingDefaultAdminSchedule);
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function defaultAdminDelay() public view virtual returns (uint48) {
        uint48 schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && _hasSchedulePassed(schedule)) ? _pendingDelay : _currentDelay;
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function pendingDefaultAdminDelay() public view virtual returns (uint48 newDelay, uint48 schedule) {
        schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && !_hasSchedulePassed(schedule)) ? (_pendingDelay, schedule) : (0, 0);
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function defaultAdminDelayIncreaseWait() public view virtual returns (uint48) {
        return 5 days;
    }

    ///
    /// AccessControlDefaultAdminRules public and internal setters for defaultAdmin/pendingDefaultAdmin
    ///

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function beginDefaultAdminTransfer(address newAdmin) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _beginDefaultAdminTransfer(newAdmin);
    }

    /**
     * @dev See {beginDefaultAdminTransfer}.
     *
     * Internal function without access restriction.
     */
    function _beginDefaultAdminTransfer(address newAdmin) internal virtual {
        uint48 newSchedule = SafeCastUpgradeable.toUint48(block.timestamp) + defaultAdminDelay();
        _setPendingDefaultAdmin(newAdmin, newSchedule);
        emit DefaultAdminTransferScheduled(newAdmin, newSchedule);
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function cancelDefaultAdminTransfer() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _cancelDefaultAdminTransfer();
    }

    /**
     * @dev See {cancelDefaultAdminTransfer}.
     *
     * Internal function without access restriction.
     */
    function _cancelDefaultAdminTransfer() internal virtual {
        _setPendingDefaultAdmin(address(0), 0);
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function acceptDefaultAdminTransfer() public virtual {
        (address newDefaultAdmin,) = pendingDefaultAdmin();
        require(_msgSender() == newDefaultAdmin, "AccessControl: pending admin must accept");
        _acceptDefaultAdminTransfer();
    }

    /**
     * @dev See {acceptDefaultAdminTransfer}.
     *
     * Internal function without access restriction.
     */
    function _acceptDefaultAdminTransfer() internal virtual {
        (address newAdmin, uint48 schedule) = pendingDefaultAdmin();
        require(_isScheduleSet(schedule) && _hasSchedulePassed(schedule), "AccessControl: transfer delay not passed");
        _revokeRole(DEFAULT_ADMIN_ROLE, defaultAdmin());
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        delete _pendingDefaultAdmin;
        delete _pendingDefaultAdminSchedule;
    }

    ///
    /// AccessControlDefaultAdminRules public and internal setters for defaultAdminDelay/pendingDefaultAdminDelay
    ///

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function changeDefaultAdminDelay(uint48 newDelay) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _changeDefaultAdminDelay(newDelay);
    }

    /**
     * @dev See {changeDefaultAdminDelay}.
     *
     * Internal function without access restriction.
     */
    function _changeDefaultAdminDelay(uint48 newDelay) internal virtual {
        uint48 newSchedule = SafeCastUpgradeable.toUint48(block.timestamp) + _delayChangeWait(newDelay);
        _setPendingDelay(newDelay, newSchedule);
        emit DefaultAdminDelayChangeScheduled(newDelay, newSchedule);
    }

    /**
     * @inheritdoc IAccessControlDefaultAdminRulesUpgradeable
     */
    function rollbackDefaultAdminDelay() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _rollbackDefaultAdminDelay();
    }

    /**
     * @dev See {rollbackDefaultAdminDelay}.
     *
     * Internal function without access restriction.
     */
    function _rollbackDefaultAdminDelay() internal virtual {
        _setPendingDelay(0, 0);
    }

    /**
     * @dev Returns the amount of seconds to wait after the `newDelay` will
     * become the new {defaultAdminDelay}.
     *
     * The value returned guarantees that if the delay is reduced, it will go into effect
     * after a wait that honors the previously set delay.
     *
     * See {defaultAdminDelayIncreaseWait}.
     */
    function _delayChangeWait(uint48 newDelay) internal view virtual returns (uint48) {
        uint48 currentDelay = defaultAdminDelay();

        // When increasing the delay, we schedule the delay change to occur after a period of "new delay" has passed, up
        // to a maximum given by defaultAdminDelayIncreaseWait, by default 5 days. For example, if increasing from 1 day
        // to 3 days, the new delay will come into effect after 3 days. If increasing from 1 day to 10 days, the new
        // delay will come into effect after 5 days. The 5 day wait period is intended to be able to fix an error like
        // using milliseconds instead of seconds.
        //
        // When decreasing the delay, we wait the difference between "current delay" and "new delay". This guarantees
        // that an admin transfer cannot be made faster than "current delay" at the time the delay change is scheduled.
        // For example, if decreasing from 10 days to 3 days, the new delay will come into effect after 7 days.
        return newDelay > currentDelay
            ? uint48(MathUpgradeable.min(newDelay, defaultAdminDelayIncreaseWait()))  // no need to safecast, both
            // inputs are uint48
            : currentDelay - newDelay;
    }

    ///
    /// Private setters
    ///

    /**
     * @dev Setter of the tuple for pending admin and its schedule.
     *
     * May emit a DefaultAdminTransferCanceled event.
     */
    function _setPendingDefaultAdmin(address newAdmin, uint48 newSchedule) private {
        (, uint48 oldSchedule) = pendingDefaultAdmin();

        _pendingDefaultAdmin = newAdmin;
        _pendingDefaultAdminSchedule = newSchedule;

        // An `oldSchedule` from `pendingDefaultAdmin()` is only set if it hasn't been accepted.
        if (_isScheduleSet(oldSchedule)) {
            // Emit for implicit cancellations when another default admin was scheduled.
            emit DefaultAdminTransferCanceled();
        }
    }

    /**
     * @dev Setter of the tuple for pending delay and its schedule.
     *
     * May emit a DefaultAdminDelayChangeCanceled event.
     */
    function _setPendingDelay(uint48 newDelay, uint48 newSchedule) private {
        uint48 oldSchedule = _pendingDelaySchedule;

        if (_isScheduleSet(oldSchedule)) {
            if (_hasSchedulePassed(oldSchedule)) {
                // Materialize a virtual delay
                _currentDelay = _pendingDelay;
            } else {
                // Emit for implicit cancellations when another delay was scheduled.
                emit DefaultAdminDelayChangeCanceled();
            }
        }

        _pendingDelay = newDelay;
        _pendingDelaySchedule = newSchedule;
    }

    ///
    /// Private helpers
    ///

    /**
     * @dev Defines if an `schedule` is considered set. For consistency purposes.
     */
    function _isScheduleSet(uint48 schedule) private pure returns (bool) {
        return schedule != 0;
    }

    /**
     * @dev Defines if an `schedule` is considered passed. For consistency purposes.
     */
    function _hasSchedulePassed(uint48 schedule) private view returns (bool) {
        return schedule < block.timestamp;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

// src/token/MetaERC20Base.sol

// for sweep functions

/// @title MetaERC20Base
/// @notice Abstract base contract for MetaERC20Hub and MetaERC20Spoke
/// @dev Implements shared storage, decimal conversion logic, message dispatch, and upgradeable behavior.
///      Inheriting contracts must override validation and message handling hooks to enforce custom routing logic.
///      Uses raw amounts with source decimal metadata instead of pre-scaling for maximum precision and flexibility.
///
/// Key features:
/// - Configurable gas limits with admin controls
/// - Efficient O(1) domain registration using dual-mapping pattern
/// - CEI pattern throughout for reentrancy protection
/// - Transfer record management with TTL-based pruning
/// - Replay protection using transferId tracking
///
/// Skipped features:
/// - supportsInterface(...) - Not needed for current use case
/// - reclaimETH or sweep() - No ETH handling planned
/// - quoteDispatch(...) - Gas estimation handled externally
///
/// @custom:oz-upgrades-unsafe-allow constructor
abstract contract MetaERC20Base is Initializable, AccessControlDefaultAdminRulesUpgradeable, IMetalayerRecipient {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using TypeCasts for bytes32;
    using TypeCasts for address;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ADMIN_ROLE = keccak256("METAERC20ADMIN_ROLE");

    /// @notice Maximum number of transfer IDs allowed in a batch prune
    /// @dev Used in batchPruneTransfers to limit gas usage
    uint256 public constant MAX_PRUNE_BATCH = 100;

    /// @notice Maximum number of transfer IDs allowed in a batch query
    /// @dev Used in getTransferRecords to prevent excessive RPC response sizes
    uint256 public constant MAX_QUERY_BATCH = 500;

    /// @notice Maximum number of domains that can be registered in a single batch call
    /// @dev Used in setDomainAddressBatch to prevent out-of-gas errors
    uint256 public constant MAX_DOMAIN_BATCH = 50;

    /// @notice Default maximum gas limit (can be adjusted by admin)
    uint256 public constant DEFAULT_MAX_GAS_LIMIT = 10_000_000; // 10M = 1/3 of block

    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                        STORAGE LAYOUT (SLOT MAP)
    ---------------------------------------------------------------
    | Slot  | Field                    | Size   | Notes           |
    |-------|--------------------------|--------|-----------------|
    | 0     | _initialized             | 1 B    |                 |
    |       | _initializing            | 1 B    |                 |
    |       | unused                   | 30 B   |                 |
    | 1     | _supportedInterfaces     | 32 B   |                 |
    | 2     | _roles                   | 32 B   |                 |
    | 3     | _pendingDefaultAdmin     | 26 B   |                 |
    |       | unused                   | 6 B    |                 |
    | 4     | _currentDelay            | 6 B    |                 |
    |       | _currentAdmin            | 20 B   |                 |
    |       | unused                   | 8 B    |                 |
    | 5     | _pendingDelay            | 12 B   |                 |
    |-------|--------------------------|--------|-----------------|
    | 6     | metalayerRouter          | 20 B   |                 |
    |       | localDomain              | 4 B    |                 |
    | 7     | ttlWindow                | 32 B   |                 |
    | 8     | transferNonce            | 32 B   |                 |
    | 9     | maxGasLimit              | 32 B   |                 |
    | 10    | __reservedSlot5          | 30 B   | Padding         |
    |       | tokenDecimals            | 1 B    |                 |
    |       | metaERC20Version         | 1 B    |                 |
    | 11    | _transferRecords         | —      | Mapping anchor  |
    | 12    | executedTransfers        | —      | Mapping anchor  |
    | 13    | metaERC20Addresses       | —      | Mapping anchor  |
    | 14    | registeredDomainByIndex  | —      | Mapping anchor  |
    | 15    | registeredDomainIndex    | —      | Mapping anchor  |
    | 16    | registeredDomainCount    | 32 B   |                 |
    | 17–66 | __gap                    | 50x32B | Reserved (Base) |
    ---------------------------------------------------------------
    Total declared slots: 67 (17 + 50 gap)
    //////////////////////////////////////////////////////////////*/

    /// @notice Domain ID of this contract's local chain (Hyperlane domain, not EVM chainid)
    uint32 public localDomain;

    /// @notice Address of the MetalayerRouter used to dispatch and receive cross-chain messages
    IMetalayerRouter public metalayerRouter;

    /// @notice Number of seconds after which a transfer is eligible for pruning
    uint256 public ttlWindow;

    /// @notice Monotonically increasing nonce used for transfer ID generation
    uint256 public transferNonce;

    /// @notice Maximum gas limit allowed for cross-chain dispatch
    /// @dev Prevents accidental or malicious consumption of entire block gas
    uint256 public maxGasLimit;

    /// @notice Pad top of slot 5 for alignment; tokenDecimals and metaERC20Version share the remaining bytes
    uint240 private __reservedSlot5;

    /// @notice Number of decimals the token uses for unit conversion
    uint8 public tokenDecimals;

    /// @notice Current MetaERC20 message version used for outbound messages
    uint8 public metaERC20Version;

    // Track tokens locked or burnt for handling failed mints
    mapping(bytes32 => MetaERC20MessageStruct) internal _transferRecords;

    /// @notice Tracks whether a given MetaERC20 transferId has been successfully executed
    /// @dev Used to enforce idempotent handling of incoming messages and prevent double execution
    mapping(bytes32 => bool) public executedTransfers;

    /// @notice Maps a Metalayer domain ID to the expected MetaERC20 contract address on that domain
    /// @dev Used for dynamic routing and message validation
    mapping(uint32 domain => bytes32 metaERC20Address) public metaERC20Addresses;

    /// @notice Mapping from index to domain ID for efficient enumeration of registered domains
    /// @dev Used with registeredDomainIndex to provide O(1) add operations while preserving enumeration capability
    mapping(uint256 => uint32) public registeredDomainByIndex; // index → domain

    /// @notice Mapping from domain ID to index for efficient lookups and validation
    /// @dev Used to check if a domain is already registered and to locate its position for potential future operations
    mapping(uint32 => uint256) public registeredDomainIndex; // domain → index

    /// @notice Total number of domains currently registered in the system
    /// @dev Incremented when new domains are added. Used as the next available index and for bounds checking.
    uint256 public registeredDomainCount;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a duplicate MetaERC20 message is received and already processed
    error AlreadyExecuted();

    /// @notice Thrown when domain and address arrays differ in length
    error ArrayLengthMismatch();

    /// @notice Thrown when setDomainAddressBatch exceeds MAX_DOMAIN_BATCH
    error ExceedsDomainBatchLimit();

    /// @notice Thrown when batchPruneTransfers is called with more than MAX_PRUNE_BATCH IDs
    error ExceedsPruneBatchLimit();

    /// @notice Thrown when getTransferRecords is called with too many IDs
    error ExceedsQueryBatchLimit();

    /// @notice Thrown when a provided domain ID is zero or otherwise invalid
    error InvalidDomain();

    /// @notice Thrown when attempting to dispatch to the local domain (loopback)
    error InvalidDomainLoopback();

    /// @notice Thrown when an invalid or unsupported finality state is provided
    /// @param state The invalid finality state value
    error InvalidFinalityState(uint8 state);

    /// @notice Thrown when the gas limit for dispatch is zero or clearly invalid
    error InvalidGasLimit();

    /// @notice Thrown when the origin domain or sender is not authorized to send messages
    error InvalidOrigin();

    /// @notice Thrown when the recipient address is zero or not allowed
    error InvalidRecipient();

    /// @notice Thrown when the router address is zero or not properly configured
    error InvalidRouter();

    /// @notice Thrown when the TTL (time-to-live) value is zero during initialization
    error InvalidTTL();

    /// @notice Thrown when a MetaERC20 version is not supported or is zero
    error InvalidVersion();

    /// @notice Thrown when no MetaERC20 contract address is registered for the given destination domain
    /// @param DestinationDomain The Metalayer domain ID for which no contract is known
    error MetaERC20NotRegistered(uint32 DestinationDomain);

    /// @notice Thrown when a virtual function is not implemented in a child contract
    error ParentContractImplements();

    /// @notice Thrown when a transfer record cannot be found by its ID
    error TransferNotFound();

    /// @notice Thrown when a transfer is not yet eligible for pruning
    error TransferNotPrunable();

    /// @notice Thrown when a message is received from an address that is not authorized
    error UnauthorizedSender();

    /// @notice Thrown when attempting to dispatch a transfer with zero amount
    error ZeroAmount();

    /// @notice Thrown when attempting to encode a message with zero transferId
    error ZeroTransferId();

    /// @notice Thrown when attempting to set a domain address to zero
    error ZeroDomainAddress();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a MetaERC20 transfer is dispatched to another domain
    /// @param transferId The unique ID of the transfer (deterministically generated)
    /// @param originDomain The domain ID of the originating chain (i.e., local chain)
    /// @param senderAddress The address initiating the transfer
    /// @param recipientDomain The target domain ID where the message is being sent
    /// @param recipientAddress The address of the recipient on the remote domain (bytes32 format)
    /// @param amount The token amount in source chain units (no decimal scaling applied)
    /// @param sourceDecimals Number of decimals used by the source chain token
    /// @param messageType The type of MetaERC20 message being dispatched
    /// @param metaERC20Version The MetaERC20 protocol version of the dispatched message
    /// @param finality The required finality for message execution (INSTANT or FINALIZED)
    /// @param gasLimit The gas limit provided for execution on the remote chain
    event MetaERC20Dispatch(
        bytes32 indexed transferId,
        uint32 originDomain,
        bytes32 indexed senderAddress,
        uint32 indexed recipientDomain,
        bytes32 recipientAddress,
        uint256 amount,
        uint8 sourceDecimals,
        MetaERC20MessageType messageType,
        uint8 metaERC20Version,
        FinalityState finality,
        uint256 gasLimit,
        bytes32 sourceTokenAddress,
        bytes32 destinationTokenAddress
    );

    /// @notice Emitted when a MetaERC20 message is successfully handled on the destination domain
    /// @param transferId The unique ID of the transfer this message corresponds to
    /// @param originDomain The domain ID where the message originated
    /// @param senderAddress The address that initiated the transfer on the origin domain
    /// @param recipientDomain The local domain receiving and processing the message
    /// @param recipientAddress The address receiving the tokens or finalization result on this domain
    /// @param amount The token amount from the original message in source chain units
    /// @param sourceDecimals Number of decimals used by the source chain token
    /// @param messageType The type of message that was processed
    /// @param metaERC20Version The MetaERC20 protocol version of the received message
    event MetaERC20Received(
        bytes32 indexed transferId,
        uint32 indexed originDomain,
        bytes32 senderAddress,
        uint32 recipientDomain,
        bytes32 indexed recipientAddress,
        uint256 amount,
        uint8 sourceDecimals,
        MetaERC20MessageType messageType,
        uint8 metaERC20Version,
        bytes32 sourceTokenAddress,
        bytes32 destinationTokenAddress
    );

    /// @notice Emitted when an unrecognized MetaERC20 message is received
    /// @param transferId The unique ID of the transfer attempt
    /// @param originDomain The domain where the message originated
    /// @param senderAddress The address that sent the message on the origin domain
    /// @param recipientDomain The local domain receiving the message
    /// @param recipientAddress The intended recipient address on this domain
    /// @param amount The token amount from the unhandled message
    /// @param sourceDecimals The source token decimals from the unhandled message
    /// @param messageType The unrecognized message type
    /// @param metaERC20Version The MetaERC20 protocol version of the unhandled message
    event MetaERC20UnhandledMessage(
        bytes32 indexed transferId,
        uint32 indexed originDomain,
        bytes32 senderAddress,
        uint32 recipientDomain,
        address indexed recipientAddress,
        uint256 amount,
        uint8 sourceDecimals,
        MetaERC20MessageType messageType,
        uint8 metaERC20Version
    );

    /// @notice Emitted when a transfer record is manually pruned after exceeding its TTL
    /// @param transferId The unique ID of the expired transfer that was deleted
    event TransferExpired(bytes32 indexed transferId);

    /// @notice Emitted when the local domain ID is explicitly set or updated
    /// @param newDomain The Metalayer domain ID assigned to this contract
    event LocalDomainSet(uint32 newDomain);

    /// @notice Emitted when the MetalayerRouter address is updated
    /// @param newRouter The address of the newly configured MetalayerRouter contract
    event MetalayerRouterSet(address indexed newRouter);

    /// @notice Emitted when the default MetaERC20 message version is updated
    /// @param newVersion The new protocol version to be used for future messages
    event MetaERC20VersionSet(uint8 newVersion);

    /// @notice Emitted when a MetaERC20 contract address is registered or updated for a domain
    /// @param domain The Metalayer domain ID being registered
    /// @param metaERC20Address The bytes32-encoded MetaERC20 contract address associated with the domain
    event MetaERC20AddressSet(uint32 domain, bytes32 metaERC20Address);

    /// @notice Emitted when the maximum gas limit for cross-chain transfers is updated by an admin
    /// @param newMaxGasLimit The new maximum gas limit value
    event MaxGasLimitUpdated(uint256 newMaxGasLimit);

    /// @notice Emitted when the TTL window is updated
    /// @param newTtlWindow The new TTL window value in seconds
    event TtlWindowUpdated(uint256 newTtlWindow);

    /// @dev Emitted when finality state is updated by admin
    event FinalityStateSet(FinalityState newFinalityState);

    /// @dev Emitted when gas limit is updated by admin
    event GasLimitSet(uint256 newGasLimit);

    /// @notice Emitted when ETH is recovered from the contract
    /// @param to Address that received the recovered ETH
    /// @param amount Amount of ETH recovered (in wei)
    event ETHRecovered(address indexed to, uint256 amount);

    /// @notice Emitted when ERC20 tokens are recovered from the contract
    /// @param token Address of the recovered token
    /// @param to Address that received the recovered tokens
    /// @param amount Amount of tokens recovered
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    /// @notice Emitted when an admin manually marks a transfer as executed
    /// @param transferId The unique identifier of the transfer
    /// @param timestamp The block timestamp when the transfer was marked executed
    /// @param domain The local domain where this action was taken
    event AdminRegisteredTransfer(bytes32 indexed transferId, uint256 timestamp, uint32 indexed domain);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal initializer for shared MetaERC20 configuration
    /// @dev Used by inheriting contracts (Hub/Spoke) to set initial state.
    ///      Sets maxGasLimit to DEFAULT_MAX_GAS_LIMIT (10M gas).
    /// @param _localDomain The Metalayer domain ID of the local chain
    /// @param _metalayerRouter The address of the MetalayerRouter contract
    /// @param _metaERC20Version The version of the MetaERC20 protocol being used
    /// @param _ttlWindow The time window (in seconds) after which transfers can be pruned
    /// @param _tokenDecimals The number of decimals used by the local token (for decimal conversion)
    function _initializeBase(
        uint32 _localDomain,
        address _metalayerRouter,
        uint8 _metaERC20Version,
        uint256 _ttlWindow,
        uint8 _tokenDecimals
    )
        internal
        onlyInitializing
    {
        if (_localDomain == 0) revert InvalidDomain();
        if (_metalayerRouter == address(0)) revert InvalidRouter();
        if (_metaERC20Version == 0) revert InvalidVersion();
        if (_ttlWindow == 0) revert InvalidTTL();
        // Token decimals of 0 is technically valid, so no check

        localDomain = _localDomain;
        metalayerRouter = IMetalayerRouter(_metalayerRouter);
        ttlWindow = _ttlWindow;
        metaERC20Version = _metaERC20Version;
        tokenDecimals = _tokenDecimals;

        maxGasLimit = DEFAULT_MAX_GAS_LIMIT;
        finalityState = FinalityState.INSTANT; // Default to INSTANT
        gasLimit = 100_000; // Default to 100k gas
    }

    /*//////////////////////////////////////////////////////////////
                        OUTGOING FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Dispatches a MetaERC20 transfer to a remote domain
    /// @dev Constructs, validates, stores, and sends a cross-chain MetaERC20MessageStruct.
    ///      Amount is sent in source token units; destination will convert using sourceDecimals.
    /// @param _recipientDomain The Metalayer domain ID of the destination chain
    /// @param _recipientAddress The recipient address on the destination chain (bytes32 format)
    /// @param _amount The amount of tokens to transfer in local token units (no decimal scaling)
    /// @return transferId A unique hash representing this cross-chain transfer
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount
    )
        public
        payable
        virtual
        returns (bytes32 transferId)
    {
        if (_amount == 0) revert ZeroAmount();

        _validateDestination(_recipientDomain, _recipientAddress);

        transferNonce++;
        transferId = _generateTransferId(msg.sender, _amount, _recipientDomain);

        MetaERC20MessageStruct memory metaERC20Message = MetaERC20MessageStruct({
            transferId: transferId,
            timestamp: block.timestamp,
            metaERC20Version: metaERC20Version,
            messageType: MetaERC20MessageType.MintRequest, // default, frequently overriden
            recipientDomain: _recipientDomain,
            recipient: _recipientAddress.bytes32ToAddress(),
            amount: _amount,
            sourceDecimals: tokenDecimals
        });

        bytes32 destinationRouterAddress;
        uint32 destinationDomain;
        (metaERC20Message.messageType, destinationRouterAddress, destinationDomain) =
            _resolveDispatchArguments(_recipientDomain, metaERC20Message);

        _recordTransfer(metaERC20Message);

        bytes memory message = MetaERC20Message.encodeMessage(metaERC20Message);

        _preDispatchHook(msg.sender, _amount);

        metalayerRouter.dispatch{ value: msg.value }(
            destinationDomain, destinationRouterAddress, new ReadOperation[](0), message, finalityState, gasLimit
        );

        emit MetaERC20Dispatch(
            transferId,
            localDomain,
            msg.sender.addressToBytes32(),
            _recipientDomain,
            _recipientAddress,
            _amount,
            tokenDecimals,
            metaERC20Message.messageType,
            metaERC20Version,
            finalityState,
            gasLimit,
            _getSourceTokenAddress(), // sourceTokenAddress
            metaERC20Addresses[_recipientDomain] // destinationTokenAddress
        );

        return transferId;
    }

    /**
     * @notice Quote the cost of a remote transfer without executing it
     * @param _recipientDomain The domain of the destination chain
     * @param _recipientAddress The recipient address on the destination chain (bytes32 format)
     * @param _amount The amount of tokens to transfer
     * @return The quoted cost in wei for the transfer
     */
    function quoteTransferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount
    )
        public
        view
        virtual
        returns (uint256)
    {
        if (_amount == 0) revert ZeroAmount();

        _validateDestination(_recipientDomain, _recipientAddress);

        // Build the same MetaERC20 message that transferRemote would build
        // Inline _generateTransferId logic but use transferNonce + 1 (don't actually increment)
        bytes32 transferId = keccak256(
            abi.encodePacked(
                msg.sender,
                _amount,
                tokenDecimals,
                transferNonce + 1, // Simulate what the nonce would be without incrementing
                localDomain,
                _recipientDomain
            )
        );

        MetaERC20MessageStruct memory metaERC20Message = MetaERC20MessageStruct({
            transferId: transferId,
            timestamp: uint32(block.timestamp),
            metaERC20Version: metaERC20Version,
            messageType: MetaERC20MessageType.MintRequest, // default, frequently overriden
            recipientDomain: _recipientDomain,
            recipient: _recipientAddress.bytes32ToAddress(),
            amount: _amount,
            sourceDecimals: tokenDecimals
        });

        bytes32 destinationRouterAddress;
        uint32 destinationDomain;
        (metaERC20Message.messageType, destinationRouterAddress, destinationDomain) =
            _resolveDispatchArguments(_recipientDomain, metaERC20Message);

        bytes memory message = MetaERC20Message.encodeMessage(metaERC20Message);

        // Use router's fallback quote path
        return metalayerRouter.quoteDispatch(destinationDomain, destinationRouterAddress, message);
    }

    /**
     * @notice Returns the source token address for events
     * @dev Virtual function to be overridden by Hub (wrappedToken) and Spoke (address(this))
     * @return The token address as bytes32
     */
    function _getSourceTokenAddress() internal view virtual returns (bytes32) {
        return address(this).addressToBytes32(); // Default for Spoke
    }

    /*//////////////////////////////////////////////////////////////
                        INCOMING FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Handles an incoming MetaERC20 message from another domain
    /// @dev Called by MetalayerRouter. Validates sender and dispatches to type-specific handler.
    ///      Enforces replay protection using transferId and routes based on messageType.
    /// @param _originDomain The domain ID where the message originated
    /// @param _senderAddress The contract address that sent the message (as bytes32)
    /// @param _rawMessage The full cross-chain message containing a MetaERC20-encoded payload
    /// @param _reads Not used — reserved for future read-verification support
    /// @param _results Not used — reserved for future read-verification support
    function handle(
        uint32 _originDomain,
        bytes32 _senderAddress,
        bytes calldata _rawMessage,
        ReadOperation[] calldata _reads,
        bytes[] calldata _results
    )
        public
        payable
        virtual
        override
    {
        // silence unused variable warnings
        _reads;
        _results;

        if (msg.sender != address(metalayerRouter)) revert UnauthorizedSender();
        _validateOrigin(_originDomain, _senderAddress);

        MetaERC20MessageStruct memory message = MetaERC20Message.decodeMessage(_rawMessage);

        if (executedTransfers[message.transferId]) revert AlreadyExecuted();
        executedTransfers[message.transferId] = true;

        MetaERC20MessageType t = message.messageType;
        uint8 v = message.metaERC20Version;

        if (t == MetaERC20MessageType.MintRequest) {
            _handleMintRequest(_originDomain, _senderAddress, v, _rawMessage);
        } else if (t == MetaERC20MessageType.UnlockRequest) {
            _handleUnlockRequest(_originDomain, _senderAddress, v, _rawMessage);
        } else if (t == MetaERC20MessageType.SecurityRelay) {
            _handleSecurityRelay(_originDomain, _senderAddress, v, _rawMessage);
        } else {
            _handleUnknownMessageType(_senderAddress, _originDomain, _rawMessage);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INCOMING FUNCTIONS (internal)
    //////////////////////////////////////////////////////////////*/

    /// @notice Handles a MetaERC20 message that does not match any known message type
    /// @dev Called when message type decoding succeeds but the type is not implemented.
    ///      Emits diagnostic event for monitoring and does not revert to avoid blocking message flow.
    /// @param _senderAddress The address of the sender on the origin domain (in bytes32 format)
    /// @param _originDomain The Hyperlane domain ID of the origin chain
    /// @param _rawMessage The full encoded message payload received from MetalayerRouter
    function _handleUnknownMessageType(
        bytes32 _senderAddress,
        uint32 _originDomain,
        bytes calldata _rawMessage
    )
        internal
    {
        MetaERC20MessageStruct memory message = MetaERC20Message.decodeMessage(_rawMessage);

        emit MetaERC20UnhandledMessage(
            message.transferId,
            _originDomain,
            _senderAddress,
            localDomain,
            message.recipient,
            message.amount, // ADD: for better diagnostics
            message.sourceDecimals, // ADD: for better diagnostics
            message.messageType,
            message.metaERC20Version
        );
    }

    /*//////////////////////////////////////////////////////////////
                    TRANSFER RECORD FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deletes a transfer record if its TTL window has expired
    /// @dev Only callable after the `ttlWindow` period has passed since message creation.
    ///      Uses message.amount to check for record existence (non-zero = exists).
    /// @param _transferId The ID of the transfer to prune
    /// @custom:reverts TransferNotFound If no transfer is recorded with the given ID
    /// @custom:reverts TransferNotPrunable If the TTL window has not yet elapsed
    /// @custom:emits TransferExpired When the transfer record is successfully deleted
    function pruneTransfer(bytes32 _transferId) public {
        MetaERC20MessageStruct memory entry = _transferRecords[_transferId];
        if (entry.amount == 0) revert TransferNotFound();
        if (block.timestamp <= entry.timestamp + ttlWindow) {
            revert TransferNotPrunable();
        }

        _deleteTransfer(_transferId);
        emit TransferExpired(_transferId);
    }

    /// @notice Attempts to delete multiple expired transfer records
    /// @dev Skips transfers that are not found or not yet prunable.
    /// Reverts if more than MAX_PRUNE_BATCH records are passed.
    /// @param _transferIds An array of transfer IDs to attempt pruning on
    /// @custom:reverts ExceedsPruneBatchLimit If the number of IDs exceeds MAX_PRUNE_BATCH
    /// @custom:emits TransferExpired For each successfully pruned transfer
    function batchPruneTransfers(bytes32[] calldata _transferIds) external {
        uint256 len = _transferIds.length;
        if (len > MAX_PRUNE_BATCH) revert ExceedsPruneBatchLimit();

        for (uint256 i = 0; i < len; i++) {
            bytes32 id = _transferIds[i];
            MetaERC20MessageStruct memory entry = _transferRecords[id];
            if (entry.amount > 0 && block.timestamp > entry.timestamp + ttlWindow) {
                _deleteTransfer(id);
                emit TransferExpired(id);
            }
        }
    }

    /// @notice Checks whether a given transfer is eligible for pruning
    /// @dev Returns true if the transfer exists and its TTL window has elapsed
    /// @param _transferId The ID of the transfer to check
    /// @return True if the transfer is prunable, false otherwise
    function isTransferPrunable(bytes32 _transferId) external view returns (bool) {
        MetaERC20MessageStruct memory entry = _transferRecords[_transferId];
        return entry.amount > 0 && block.timestamp > entry.timestamp + ttlWindow;
    }

    /// @notice Returns the full transfer records for a set of transfer IDs
    /// @dev Will return zeroed entries for IDs that do not correspond to any recorded transfer.
    /// Reverts if more than MAX_QUERY_BATCH IDs are provided.
    /// @param _transferIds An array of transfer IDs to look up
    /// @return results An array of MetaERC20MessageStructs matching the requested IDs
    /// @custom:reverts ExceedsQueryBatchLimit If the number of IDs exceeds MAX_QUERY_BATCH
    function getTransferRecords(bytes32[] calldata _transferIds)
        external
        view
        returns (MetaERC20MessageStruct[] memory results)
    {
        if (_transferIds.length > MAX_QUERY_BATCH) {
            revert ExceedsQueryBatchLimit();
        }

        results = new MetaERC20MessageStruct[](_transferIds.length);
        for (uint256 i = 0; i < _transferIds.length; i++) {
            results[i] = _transferRecords[_transferIds[i]];
        }
    }

    /*//////////////////////////////////////////////////////////////
                    TRANSFER RECORD FUNCTIONS (internal)
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal helper to retrieve a stored transfer record
    /// @param _transferId The ID of the transfer to fetch
    /// @return The MetaERC20MessageStruct associated with the given ID
    function _getTransferRecord(bytes32 _transferId) internal view returns (MetaERC20MessageStruct memory) {
        return _transferRecords[_transferId];
    }

    /// @notice Stores a new transfer record keyed by its transferId
    /// @dev Overwrites any existing record with the same transferId
    /// @param _message The fully constructed MetaERC20 message to store
    function _recordTransfer(MetaERC20MessageStruct memory _message) internal {
        _transferRecords[_message.transferId] = _message;
    }

    /// @notice Deletes a transfer record by ID
    /// @param _transferId The ID of the transfer to remove from storage
    function _deleteTransfer(bytes32 _transferId) internal {
        delete _transferRecords[_transferId];
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the MetaERC20 message version
    /// @dev Version must be non-zero. Callable only by ADMIN_ROLE.
    /// @param _newVersion The new MetaERC20 protocol version to use
    function setMessageVersion(uint8 _newVersion) external onlyRole(ADMIN_ROLE) {
        if (_newVersion == 0) revert InvalidVersion();
        metaERC20Version = _newVersion;
        emit MetaERC20VersionSet(_newVersion);
    }

    /// @notice Sets or updates the local domain ID for this contract
    /// @dev Callable only by ADMIN_ROLE. Emits LocalDomainSet.
    /// @param _newdomain The Metalayer domain ID to assign to this contract
    function setLocalDomain(uint32 _newdomain) external onlyRole(ADMIN_ROLE) {
        if (_newdomain == 0) revert InvalidDomain();
        localDomain = _newdomain;
        emit LocalDomainSet(_newdomain);
    }

    /// @notice Sets the address of the MetalayerRouter
    /// @dev Must be a non-zero address. Callable only by ADMIN_ROLE.
    /// @param _newRouter The address of the new MetalayerRouter contract
    function setMetalayerRouter(address _newRouter) external onlyRole(ADMIN_ROLE) {
        if (_newRouter == address(0)) revert InvalidRouter();
        metalayerRouter = IMetalayerRouter(_newRouter);
        emit MetalayerRouterSet(_newRouter);
    }

    /// @notice Updates the maximum gas limit allowed for cross-chain transfers
    /// @dev Gas limit must be non-zero. Callable only by ADMIN_ROLE.
    ///      Used to prevent excessive gas consumption and potential DoS attacks.
    /// @param _newMaxGasLimit The new maximum gas limit value
    function setMaxGasLimit(uint256 _newMaxGasLimit) external onlyRole(ADMIN_ROLE) {
        if (_newMaxGasLimit == 0) revert InvalidGasLimit();
        maxGasLimit = _newMaxGasLimit;
        emit MaxGasLimitUpdated(_newMaxGasLimit);
    }

    /// @notice Updates the TTL window for transfer record pruning
    /// @dev TTL window must be non-zero. Callable only by ADMIN_ROLE.
    ///      This setting controls how long transfer records are kept before they can be pruned.
    /// @param _newTtlWindow The new TTL window value in seconds
    function setTtlWindow(uint256 _newTtlWindow) external onlyRole(ADMIN_ROLE) {
        if (_newTtlWindow == 0) revert InvalidTTL();
        ttlWindow = _newTtlWindow;
        emit TtlWindowUpdated(_newTtlWindow);
    }

    /// @notice Sets the required finality state for all cross-chain transfers
    /// @dev Can only be called by ADMIN_ROLE to enforce security model
    /// @param _finalityState The finality state to require for all transfers
    function setFinalityState(FinalityState _finalityState) external onlyRole(ADMIN_ROLE) {
        finalityState = _finalityState;
        emit FinalityStateSet(_finalityState);
    }

    /// @notice Sets the gas limit for all cross-chain transfers
    /// @dev Can only be called by ADMIN_ROLE to enforce consistent gas usage
    /// @param _gasLimit The gas limit to use for all transfers
    function setGasLimit(uint256 _gasLimit) external onlyRole(ADMIN_ROLE) {
        if (_gasLimit == 0 || _gasLimit > maxGasLimit) revert InvalidGasLimit();
        gasLimit = _gasLimit;
        emit GasLimitSet(_gasLimit);
    }

    /// @notice Registers or updates a MetaERC20 contract address for a given domain
    /// @dev Adds the domain to registered domain tracking if it hasn't been seen before.
    ///      Uses mapping-based enumeration for efficient O(1) operations.
    /// @param _domain The Metalayer domain ID to register
    /// @param _metaERC20Address The bytes32-encoded MetaERC20 contract address for that domain
    function setDomainAddress(uint32 _domain, bytes32 _metaERC20Address) external onlyRole(ADMIN_ROLE) {
        if (_metaERC20Address == 0) revert ZeroDomainAddress();

        bool isNewDomain = metaERC20Addresses[_domain] == 0;
        metaERC20Addresses[_domain] = _metaERC20Address;

        if (isNewDomain) {
            registeredDomainByIndex[registeredDomainCount] = _domain;
            registeredDomainIndex[_domain] = registeredDomainCount;
            registeredDomainCount++;
        }

        emit MetaERC20AddressSet(_domain, _metaERC20Address);
        domainsLastUpdated = block.number;
    }

    /// @notice Registers or updates multiple MetaERC20 contract addresses in a single call
    /// @dev Adds any new domains to the registered domain tracking using efficient mapping-based enumeration.
    ///      Fails if array lengths mismatch or batch size is too large. Emits MetaERC20AddressSet for each domain.
    /// @param _domains Array of Metalayer domain IDs
    /// @param _metaERC20Addresses Array of bytes32-encoded MetaERC20 contract addresses
    /// @custom:reverts ArrayLengthMismatch If `_domains` and `_metaERC20Addresses` differ in length
    /// @custom:reverts ExceedsDomainBatchLimit If the number of entries exceeds MAX_DOMAIN_BATCH
    function setDomainAddressBatch(
        uint32[] calldata _domains,
        bytes32[] calldata _metaERC20Addresses
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        uint256 len = _domains.length;

        if (len > MAX_DOMAIN_BATCH) revert ExceedsDomainBatchLimit();
        if (len != _metaERC20Addresses.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < len; i++) {
            uint32 domain = _domains[i];
            bytes32 addr = _metaERC20Addresses[i];

            if (addr == 0) revert ZeroDomainAddress();

            bool isNewDomain = metaERC20Addresses[domain] == 0;
            metaERC20Addresses[domain] = addr;

            if (isNewDomain) {
                // Add to mapping-based tracking instead of array
                registeredDomainByIndex[registeredDomainCount] = domain;
                registeredDomainIndex[domain] = registeredDomainCount;
                registeredDomainCount++;
            }

            emit MetaERC20AddressSet(domain, addr);
        }

        domainsLastUpdated = block.number;
    }

    /// @notice Returns a paginated list of registered Metalayer domain IDs
    /// @dev Provides enumeration over the mapping-based domain tracking system.
    ///      Returns empty array if start index is beyond the total count.
    ///      Automatically clamps the end index to prevent out-of-bounds access.
    /// @param _start Index to begin reading from (0-based)
    /// @param _count Maximum number of domain IDs to return
    /// @return domains Array of registered Metalayer domain IDs in the requested range
    function getRegisteredDomains(uint256 _start, uint256 _count) external view returns (uint32[] memory domains) {
        if (_start >= registeredDomainCount) {
            return new uint32[](0);
        }

        uint256 end = _start + _count;
        if (end > registeredDomainCount) end = registeredDomainCount;

        domains = new uint32[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            domains[i - _start] = registeredDomainByIndex[i];
        }
    }

    /// @notice Admin function to manually mark a transfer as executed to prevent double-spending
    /// @dev This is the first step in a two-step recovery process for stuck transfers.
    ///      Must be called on the DESTINATION chain before using EMERGENCY_UNLOCK or EMERGENCY_REISSUE
    ///      on the source chain. This prevents the original message from being processed if it
    ///      arrives late, which would result in double-minting/unlocking.
    ///
    ///      Recovery workflow:
    ///      1. Call REGISTER_TRANSFER_EXECUTION on destination chain (prevents double-spend)
    ///      2. Call EMERGENCY_UNLOCK (Hub) or EMERGENCY_REISSUE (Spoke) on source chain
    ///
    /// @param _transferId The unique identifier of the transfer to mark as executed
    /// @custom:access ADMIN_ROLE required
    /// @custom:security Critical function - ensure the transfer is truly stuck before use
    /// @custom:emits AdminRegisteredTransfer when the transfer is marked as executed
    function REGISTER_TRANSFER_EXECUTION(bytes32 _transferId) external onlyRole(ADMIN_ROLE) {
        if (_transferId == bytes32(0)) revert ZeroTransferId();
        if (executedTransfers[_transferId]) revert AlreadyExecuted();

        executedTransfers[_transferId] = true;

        emit AdminRegisteredTransfer(_transferId, block.timestamp, localDomain);
    }

    /*//////////////////////////////////////////////////////////////
                        RECOVERY FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Recovers ETH accidentally sent to the contract
    /// @dev Only callable by ADMIN_ROLE. ETH may accumulate from overpaying for cross-chain gas
    ///      or failed cross-chain calls that don't consume all provided ETH.
    /// @param _to Address to send the recovered ETH to
    /// @param _amount Amount of ETH to recover (in wei)
    function recoverETH(address payable _to, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (_to == address(0)) revert InvalidRecipient();
        if (_amount > address(this).balance) revert("Insufficient ETH balance");

        (bool success,) = _to.call{ value: _amount }("");
        require(success, "ETH transfer failed");

        emit ETHRecovered(_to, _amount);
    }

    /// @notice Recovers ERC20 tokens accidentally sent to the contract
    /// @dev Only callable by ADMIN_ROLE. Use with caution on Hub contracts to avoid
    ///      recovering wrapped tokens that are part of the locked balance.
    /// @param _token Address of the ERC20 token to recover
    /// @param _to Address to send the recovered tokens to
    /// @param _amount Amount of tokens to recover
    function recoverERC20(address _token, address _to, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (_token == address(0)) revert("Invalid token address");
        if (_to == address(0)) revert InvalidRecipient();

        IERC20Upgradeable token = IERC20Upgradeable(_token);
        if (_amount > token.balanceOf(address(this))) {
            revert("Insufficient token balance");
        }

        token.safeTransfer(_to, _amount);

        emit ERC20Recovered(_token, _to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS (internal)
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts token amounts between different decimal precisions
    /// @dev Scales up for fewer source decimals, scales down for more source decimals
    /// @param _amount The amount to convert
    /// @param _fromDecimals Source token decimal places (e.g., 6 for USDC)
    /// @param _toDecimals Target token decimal places (e.g., 18 for local token)
    /// @return Converted amount in target decimal precision
    function _convertDecimals(uint256 _amount, uint8 _fromDecimals, uint8 _toDecimals) internal pure returns (uint256) {
        if (_fromDecimals == _toDecimals) {
            return _amount;
        } else if (_fromDecimals < _toDecimals) {
            // Scale up: 6 decimals → 18 decimals
            return _amount * (10 ** (_toDecimals - _fromDecimals));
        } else {
            // Scale down: 24 decimals → 18 decimals
            return _amount / (10 ** (_fromDecimals - _toDecimals));
        }
    }

    /// @notice Generates a unique transfer ID for a cross-chain dispatch
    /// @dev Combines sender, amount, source decimals, nonce, local domain, and destination domain
    /// @param _sender The address initiating the transfer
    /// @param _amount The token amount in source token units (no scaling)
    /// @param _recipientDomain The Metalayer domain ID of the recipient chain
    /// @return A unique hash used to identify this transfer across chains
    function _generateTransferId(
        address _sender,
        uint256 _amount,
        uint32 _recipientDomain
    )
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(abi.encodePacked(_sender, _amount, tokenDecimals, transferNonce, localDomain, _recipientDomain));
    }

    /*//////////////////////////////////////////////////////////////
                        VIRTUALS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates the sender of an incoming message
    /// @dev Reverts if the origin is the local domain or if the sender does not match the expected MetaERC20 contract
    /// @param _originDomain The Metalayer domain ID where the message originated
    /// @param _senderAddress The address that sent the message on the origin domain (bytes32-encoded)
    function _validateOrigin(uint32 _originDomain, bytes32 _senderAddress) internal view virtual {
        if (_originDomain == localDomain) revert InvalidOrigin();

        if (_senderAddress != metaERC20Addresses[_originDomain]) {
            revert UnauthorizedSender();
        }
    }

    /// @notice Validates the destination of an outbound message
    /// @dev Reverts on loopback domain or if recipient address is zero. Does not check address correctness beyond
    /// format. @param _recipientDomain The Metalayer domain ID of the destination chain
    /// @param _recipientAddress The address of the expected MetaERC20 recipient contract on the destination chain
    /// (bytes32-encoded)
    function _validateDestination(uint32 _recipientDomain, bytes32 _recipientAddress) internal view virtual {
        if (_recipientDomain == localDomain) revert InvalidDomainLoopback();
        if (_recipientAddress == bytes32(0)) revert InvalidRecipient();
        if (metaERC20Addresses[_recipientDomain] == 0) {
            revert MetaERC20NotRegistered(_recipientDomain);
        }
    }

    /// @notice Determines the final message type, destination address, and destination domain for a cross-chain
    /// transfer @dev Inheriting contracts must implement this to apply routing logic, such as SecurityRelay thresholds,
    ///      domain restrictions, or policy-based overrides. The destination domain may differ from the originally
    ///      requested recipient domain (e.g., SecurityRelay routes through hub before reaching final destination).
    /// @param _recipientDomain The originally requested domain for the transfer (user's intended destination)
    /// @param _message The partially constructed MetaERC20 message, including transferId, recipient, and amount
    /// @return messageType The finalized MetaERC20 message type to dispatch (e.g., MintRequest, SecurityRelay)
    /// @return destinationRouterAddress The address of the receiving MetaERC20 contract on the destination domain
    /// @return destinationDomain The actual domain where the message will be sent (may differ from _recipientDomain)
    /// @custom:example For SecurityRelay: user requests domain 3, but function returns domain 1 (hub) as destination
    function _resolveDispatchArguments(
        uint32 _recipientDomain,
        MetaERC20MessageStruct memory _message
    )
        internal
        view
        virtual
        returns (MetaERC20MessageType messageType, bytes32 destinationRouterAddress, uint32 destinationDomain)
    {
        revert ParentContractImplements();
    }

    /// @notice Performs contract-specific logic before dispatching a cross-chain transfer
    /// @dev Called after transferId is generated but before message dispatch.
    ///      Hub implementation: locks tokens via safeTransferFrom
    ///      Spoke implementation: burns synthetic tokens and updates mintedBalance
    /// @param _sender The address initiating the transfer
    /// @param _amount The token amount in local units (no decimal scaling applied)
    function _preDispatchHook(address _sender, uint256 _amount) internal virtual {
        revert ParentContractImplements();
    }

    /// @notice Handles an incoming MintRequest message
    /// @dev Must be overridden by the implementing contract to mint synthetic tokens.
    ///      Spoke implementation: converts decimals and mints tokens to recipient.
    ///      Hub implementation: not used (Hub doesn't receive MintRequests).
    /// @param _originDomain The Metalayer domain ID where the message originated
    /// @param _senderAddress The address that sent the message on the origin chain
    /// @param _metaERC20Version The message version of the MetaERC20 protocol
    /// @param _writeData The raw message payload (already validated and version-matched)
    function _handleMintRequest(
        uint32 _originDomain,
        bytes32 _senderAddress,
        uint8 _metaERC20Version,
        bytes calldata _writeData
    )
        internal
        virtual
    {
        revert ParentContractImplements();
    }

    /// @notice Handles an incoming UnlockRequest message
    /// @dev Must be overridden by the implementing contract to release canonical tokens.
    ///      Hub implementation: converts decimals and transfers locked tokens to recipient.
    ///      Spoke implementation: not used (Spoke doesn't receive UnlockRequests).
    /// @param _originDomain The Metalayer domain ID where the message originated
    /// @param _senderAddress The address that sent the message on the origin chain
    /// @param _metaERC20Version The message version of the MetaERC20 protocol
    /// @param _writeData The raw message payload (already validated and version-matched)
    function _handleUnlockRequest(
        uint32 _originDomain,
        bytes32 _senderAddress,
        uint8 _metaERC20Version,
        bytes calldata _writeData
    )
        internal
        virtual
    {
        revert ParentContractImplements();
    }

    /// @notice Handles a SecurityRelay message for high-value Spoke-to-Spoke transfers
    /// @dev Must be overridden to buffer the relay for manual approval before final minting.
    ///      Hub implementation: buffers message and waits for VALIDATOR_ROLE approval.
    ///      Spoke implementation: not used (Spoke doesn't receive SecurityRelays).
    /// @param _originDomain The Metalayer domain ID where the message originated
    /// @param _senderAddress The address that sent the message on the origin chain
    /// @param _metaERC20Version The MetaERC20 protocol version
    /// @param _writeData The raw message payload (already validated and version-matched)
    function _handleSecurityRelay(
        uint32 _originDomain,
        bytes32 _senderAddress,
        uint8 _metaERC20Version,
        bytes calldata _writeData
    )
        internal
        virtual
    {
        revert ParentContractImplements();
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE GAP
    //////////////////////////////////////////////////////////////*/

    /// @notice The required finality state for all cross-chain transfers
    /// @dev Set by admin to enforce consistent security model across all transfers
    FinalityState public finalityState;

    /// @notice The gas limit for all cross-chain transfers
    /// @dev Set by admin to enforce consistent gas usage across all transfers
    uint256 public gasLimit;

    /// @notice Simple indicator if the local deployment is a Hub or Spoke
    /// @dev Set during deployment
    bool public isHub;

    /// @notice Block number when domains were last updated
    /// @dev Updated whenever setDomainAddress or setDomainAddressBatch is called
    uint256 public domainsLastUpdated;

    /// @dev Reserved storage space to allow for layout upgrades in the future
    uint256[46] private __gap;
}

// src/token/MetaERC20Spoke.sol

/// @title MetaERC20Spoke
/// @notice Synthetic bridge-side contract for minting and burning cross-chain ERC20 tokens
/// @dev Mints synthetic tokens on receipt of MintRequest, burns tokens during transferRemote.
///      Uses ERC20's built-in balance tracking for mint/burn operations.
///      Implements smart routing: direct transfers to other Spokes, or via Hub for high-value transfers.
///
/// Spoke behavior:
/// - Mints synthetic tokens when receiving MintRequest messages
/// - Burns synthetic tokens before dispatching transferRemote
/// - Routes to Hub (UnlockRequest) when users want canonical tokens
/// - Routes high-value transfers through Hub (SecurityRelay) for manual approval
/// - Routes normal transfers directly to destination Spokes (MintRequest)
/// - Converts between source and local token decimal precision
/// - Uses ERC20 balance validation to prevent over-burning
///
/// Must be paired with a MetaERC20Hub on the canonical domain.
///
contract MetaERC20Spoke is MetaERC20Base, ERC20Upgradeable {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                        STORAGE LAYOUT (SLOT MAP)
    ----------------------------------------------------------------
    |        | MetaERC20Base           |        |                  |
    |--------|-------------------------|--------|------------------|
    | 67     | __reservedSlot67        | 32 B   | Reserved         |
    | 68     | __reservedSlot63        | 28 B   | Spoke-specific   |
    |        | hubDomain               | 4 B    | Spoke-specific   |
    | 69     | securityThreshold       | 32 B   |                  |
    | 70–120 | __gap (Spoke)           | 50x32B | Reserved (Spoke) |
    ----------------------------------------------------------------
    Total declared slots: 121
    //////////////////////////////////////////////////////////////*/

    /// @dev Reserved padding - slot 67 previously used for mintedBalance, now available
    uint256 private __reservedSlot67;

    /// @dev Reserved padding to align `hubDomain` at the low bytes of slot 63
    uint224 private __reservedSlot63;

    /// @notice The Metalayer domain ID of the canonical Hub contract
    /// @dev Used to route messages and validate origin in `_validateOrigin`
    uint32 public hubDomain;

    /// @notice Transfers >= securityThreshold must route through the Hub for manual approval
    /// @dev Threshold is in local token units. High-value transfers use SecurityRelay for additional security.
    uint256 public securityThreshold;
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the configured hubDomain is zero or otherwise invalid
    error InvalidHubDomain();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an admin manually reissues synthetic tokens using EMERGENCY_REISSUE
    /// @param transferId The ID of the transfer that was force-reissued
    /// @param adminAddress The address of the admin who triggered the reissue
    /// @param recipientAddress The address that received the reissued tokens
    event MetaERC20AdminReissue(bytes32 indexed transferId, address indexed adminAddress, address recipientAddress);

    /// @notice Emitted when the MetaERC20Spoke is initialized
    /// @param localDomain The Metalayer domain ID of this Spoke chain
    /// @param hubDomain The Metalayer domain ID of the canonical Hub
    /// @param tokenDecimals The number of decimals the synthetic token uses
    /// @param metaERC20Version The protocol version used by this Spoke
    /// @param securityThreshold Transfers >= this value are routed through the Hub (in local token units)
    /// @param name The ERC20 name string
    /// @param symbol The ERC20 symbol string
    event MetaERC20SpokeInitialized(
        uint32 indexed localDomain,
        uint32 indexed hubDomain,
        uint8 tokenDecimals,
        uint8 metaERC20Version,
        uint256 securityThreshold,
        string name,
        string symbol
    );

    /// @notice Emitted when the security threshold is updated by an admin
    /// @param newThreshold The new threshold value for high-value transfer routing (in local token units)
    event SecurityThresholdUpdated(uint256 newThreshold);

    /// @notice Emitted when the hub domain is updated
    /// @param newHubDomain The new hub domain ID
    event HubDomainUpdated(uint32 newHubDomain);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the MetaERC20Spoke with required configuration
    /// @dev Callable only once. Initializes ERC20 metadata, router config, and decimal conversion settings.
    ///      Grants ADMIN_ROLE to the initializer. Sets up 1-day delay for admin role transfers.
    ///      Validates hubDomain is non-zero and different from localDomain.
    /// @param _localDomain The Metalayer domain ID of the current chain
    /// @param _metalayerRouter The address of the MetalayerRouter used for message dispatch and receive
    /// @param _ttlWindow The time (in seconds) after which transfer records can be pruned
    /// @param _metaERC20Version The MetaERC20 protocol version to use for outbound messages
    /// @param _hubDomain The Metalayer domain ID of the canonical Hub
    /// @param name_ The name of the synthetic ERC20 token
    /// @param symbol_ The symbol of the synthetic ERC20 token
    /// @param _tokenDecimals The number of decimals the token uses
    /// @param _securityThreshold The threshold for high-value transfers (in local token units)
    function initialize(
        uint32 _localDomain,
        address _metalayerRouter,
        uint256 _ttlWindow,
        uint8 _metaERC20Version,
        uint32 _hubDomain,
        string memory name_,
        string memory symbol_,
        uint8 _tokenDecimals,
        uint256 _securityThreshold,
        address _initialAdmin
    )
        public
        initializer
    {
        __ERC20_init(name_, symbol_);
        __AccessControlDefaultAdminRules_init(1 days, _initialAdmin);

        if (_hubDomain == 0 || _hubDomain == _localDomain) {
            revert InvalidHubDomain();
        }

        _initializeBase(_localDomain, _metalayerRouter, _metaERC20Version, _ttlWindow, _tokenDecimals);

        hubDomain = _hubDomain;
        securityThreshold = _securityThreshold;
        isHub = false;

        _grantRole(ADMIN_ROLE, _initialAdmin);

        emit MetaERC20SpokeInitialized(
            _localDomain, _hubDomain, _tokenDecimals, _metaERC20Version, _securityThreshold, name_, symbol_
        );
    }

    /*//////////////////////////////////////////////////////////////
                        OUTGOING FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc MetaERC20Base
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount
    )
        public
        payable
        override
        returns (bytes32 transferId)
    {
        return super.transferRemote(_recipientDomain, _recipientAddress, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INCOMING FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc MetaERC20Base
    function handle(
        uint32 _originDomain,
        bytes32 _senderAddress,
        bytes calldata _message,
        ReadOperation[] calldata _reads,
        bytes[] calldata _results
    )
        public
        payable
        override
    {
        super.handle(_originDomain, _senderAddress, _message, _reads, _results);
    }

    /*//////////////////////////////////////////////////////////////
                        INCOMING FUNCTIONS (internal)
    //////////////////////////////////////////////////////////////*/

    /// @notice Handles a MintRequest to mint synthetic tokens to a user
    /// @dev Decodes MetaERC20MessageStruct, converts decimal precision from source to local units,
    ///      and mints synthetic tokens to the recipient.
    ///      Uses CEI pattern: validates recipient, converts decimals, checks amount, then mints.
    /// @param _originDomain The Metalayer domain ID where the message originated
    /// @param _senderAddress The address that sent the message on the origin chain (bytes32 format)
    /// @param _metaERC20Version The version of the MetaERC20 protocol
    /// @param _writeData The raw encoded message payload (already validated and version-matched)
    function _handleMintRequest(
        uint32 _originDomain,
        bytes32 _senderAddress,
        uint8 _metaERC20Version,
        bytes calldata _writeData
    )
        internal
        override
    {
        MetaERC20MessageStruct memory _message = MetaERC20Message.decodeMessage(_writeData);

        if (_message.recipient == address(0)) revert InvalidRecipient();

        uint256 localAmount = _convertDecimals(_message.amount, _message.sourceDecimals, tokenDecimals);
        if (localAmount == 0) revert ZeroAmount();

        _mint(_message.recipient, localAmount);

        emit MetaERC20Received(
            _message.transferId,
            _originDomain,
            _senderAddress,
            localDomain,
            _message.recipient.addressToBytes32(),
            _message.amount,
            _message.sourceDecimals,
            _message.messageType,
            _metaERC20Version,
            metaERC20Addresses[_originDomain], // sourceTokenAddress
            address(this).addressToBytes32() // destinationTokenAddress (Spoke contract itself)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of decimals used by the synthetic token
    /// @dev Overrides ERC20 to return the value configured at initialization.
    ///      Critical for proper external contract integration and display.
    /// @return The number of decimals for this token
    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS (external)
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin-only emergency function to reissue synthetic tokens for a failed or unprocessed transfer
    /// @dev Bypasses normal message flow and directly mints synthetic tokens to recipient.
    ///      Converts amounts from source decimals to local token decimals before minting.
    ///      Emits MetaERC20Received with originDomain = 0 to signal admin override flow.
    /// @param _transferId The ID of the original transfer to reissue from storage
    /// @param _recipientAddress The address that will receive the reissued synthetic tokens
    function EMERGENCY_REISSUE(bytes32 _transferId, address _recipientAddress) external onlyRole(ADMIN_ROLE) {
        if (_recipientAddress == address(0)) revert InvalidRecipient();

        MetaERC20MessageStruct memory _message = _getTransferRecord(_transferId);
        if (_message.amount == 0) revert TransferNotFound();

        uint256 localAmount = _convertDecimals(_message.amount, _message.sourceDecimals, tokenDecimals);

        _deleteTransfer(_transferId);
        _mint(_recipientAddress, localAmount);

        emit MetaERC20Received(
            _transferId,
            0, // originDomain unknown in admin override
            msg.sender.addressToBytes32(),
            localDomain,
            _recipientAddress.addressToBytes32(),
            _message.amount,
            _message.sourceDecimals,
            MetaERC20MessageType.AdminAction,
            metaERC20Version,
            bytes32(0), // sourceTokenAddress unknown in admin flow
            address(this).addressToBytes32() // destinationTokenAddress (Spoke contract itself)
        );

        emit MetaERC20AdminReissue(_transferId, msg.sender, _recipientAddress);
    }

    /// @notice Updates the security threshold for high-value transfers
    /// @dev Transfers >= this threshold will be routed to the Hub as SecurityRelay
    /// @param newThreshold The new threshold value in local token units
    function setSecurityThreshold(uint256 newThreshold) external onlyRole(ADMIN_ROLE) {
        securityThreshold = newThreshold;
        emit SecurityThresholdUpdated(newThreshold);
    }

    /// @notice Updates the hub domain for cross-chain routing
    /// @dev Hub domain must be non-zero and different from local domain. Callable only by ADMIN_ROLE.
    ///      This setting controls which domain is treated as the canonical Hub for routing decisions.
    /// @param newHubDomain The new hub domain ID
    function setHubDomain(uint32 newHubDomain) external onlyRole(ADMIN_ROLE) {
        if (newHubDomain == 0 || newHubDomain == localDomain) {
            revert InvalidHubDomain();
        }
        hubDomain = newHubDomain;
        emit HubDomainUpdated(newHubDomain);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS (internal)
    //////////////////////////////////////////////////////////////*/

    /// @notice Determines the dispatch parameters for a Spoke-originating transfer
    /// @dev Implements Spoke's routing logic:
    ///      - High-value transfers (>= securityThreshold) to other spokes route through Hub as SecurityRelay
    ///      - Transfers to Hub become UnlockRequest
    ///      - Low-value transfers to other spokes become direct MintRequest
    ///      The destination domain may differ from recipient domain for SecurityRelay routing.
    /// @param _recipientDomain The user's intended final destination domain
    /// @param _message The partially constructed MetaERC20MessageStruct containing amount for threshold check
    /// @return messageType The type of message to send (MintRequest, UnlockRequest, or SecurityRelay)
    /// @return destinationRouterAddress The MetaERC20 contract address on the destination domain
    /// @return destinationDomain The actual domain to send to (hubDomain for SecurityRelay, otherwise _recipientDomain)
    function _resolveDispatchArguments(
        uint32 _recipientDomain,
        MetaERC20MessageStruct memory _message
    )
        internal
        view
        override
        returns (MetaERC20MessageType messageType, bytes32 destinationRouterAddress, uint32 destinationDomain)
    {
        if (_recipientDomain == localDomain) {
            revert InvalidDomainLoopback();
        }

        if (_message.amount >= securityThreshold && _recipientDomain != hubDomain) {
            // High-value spoke→spoke transfer → route through Hub
            messageType = MetaERC20MessageType.SecurityRelay;
            destinationRouterAddress = metaERC20Addresses[hubDomain];
            destinationDomain = hubDomain;
        } else if (_recipientDomain == hubDomain) {
            // Standard unlock flow
            messageType = MetaERC20MessageType.UnlockRequest;
            destinationRouterAddress = metaERC20Addresses[hubDomain];
            destinationDomain = hubDomain;
        } else {
            // Normal MintRequest to remote Spoke
            messageType = MetaERC20MessageType.MintRequest;
            destinationRouterAddress = metaERC20Addresses[_recipientDomain];
            destinationDomain = _recipientDomain;
        }

        if (destinationRouterAddress == 0) {
            revert MetaERC20NotRegistered(destinationDomain);
        }

        return (messageType, destinationRouterAddress, destinationDomain);
    }

    /// @notice Burns tokens prior to dispatching a cross-chain transfer
    /// @dev Burns synthetic tokens from sender. The ERC20 _burn function handles balance validation.
    /// @param _sender The address initiating the transfer
    /// @param _amount The token amount to be burned in local token units
    function _preDispatchHook(address _sender, uint256 _amount) internal override {
        _burn(_sender, _amount);
    }
    /*//////////////////////////////////////////////////////////////
                                UPGRADE GAP
    //////////////////////////////////////////////////////////////*/

    /// @dev Reserved storage space to allow for layout upgrades in the future
    uint256[50] private __gap;
}

