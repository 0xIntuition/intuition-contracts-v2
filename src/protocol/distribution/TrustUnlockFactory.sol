// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { TrustUnlock } from "src/protocol/distribution/TrustUnlock.sol";

/**
 * @title  TrustUnlock
 * @author 0xIntuition
 * @notice This contract is a factory for creating TrustUnlock contracts.
 */
contract TrustUnlockFactory is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the Wrapped Trust (WTRUST) token
    address payable public immutable trustToken;

    /// @notice Address of the TrustBonding contract
    address public immutable trustBonding;

    /// @notice Address of the MultiVault contract
    address payable public immutable multiVault;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The mapping of recipients to their respective TrustUnlock contracts
    mapping(address recipient => address trustUnlock) public trustUnlocks;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new TrustUnlock contract is created
     * @param recipient The address of the recipient of the TrustUnlock
     * @param trustUnlock The address of the newly created TrustUnlock contract
     */
    event TrustUnlockCreated(address indexed recipient, address indexed trustUnlock);

    /**
     * @notice Emitted when tokens are recovered from the TrustUnlockFactory contract
     * @param token The address of the token that was recovered
     * @param recipient The address of the recipient of the recovered tokens
     * @param amount The amount of tokens that were recovered
     */
    event TokensRecovered(address indexed token, address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unlock_ZeroAddress();
    error Unlock_ZeroLengthArray();
    error Unlock_ArrayLengthMismatch();
    error Unlock_TrustUnlockAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for the TrustUnlockFactory contract
     * @param _trustToken The address of the TRUST token contract
     * @param _admin Address of the admin who can create TrustUnlock contracts
     */
    constructor(address _trustToken, address _admin, address _trustBonding, address _multiVault) Ownable(_admin) {
        if (_trustToken == address(0) || _trustBonding == address(0) || _multiVault == address(0)) {
            revert Unlock_ZeroAddress();
        }

        trustToken = payable(_trustToken);
        trustBonding = _trustBonding;
        multiVault = payable(_multiVault);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new TrustUnlock contract for a recipient
     *  @param recipient The address of the recipient of the TrustUnlock
     * @param unlockAmount The amount of tokens to be unlocked
     * @param unlockCliff The timestamp when the unlock cliff ends
     * @param unlockEnd The timestamp when the unlock period ends
     * @param cliffPercentage The percentage of the unlock amount that is released at the cliff
     */
    function createTrustUnlock(
        address recipient,
        uint256 unlockAmount,
        uint256 unlockCliff,
        uint256 unlockEnd,
        uint256 cliffPercentage
    )
        external
        onlyOwner
        nonReentrant
    {
        // Deploy a TrustUnlock contract for the recipient
        _createTrustUnlock(recipient, unlockAmount, unlockCliff, unlockEnd, cliffPercentage);
    }

    /**
     * @notice Creates multiple TrustUnlock contracts for a list of recipients in a single transaction
     * @dev Only recipients and unlockAmounts vary for each TrustUnlock contract - the rest of the parameters are the
     * same
     *      and assume that multiple recipients are subject to the same unlock schedule.
     * @param recipients The addresses of the recipients of the TrustUnlock contracts
     * @param unlockAmounts The amounts of tokens to be unlocked for each recipient
     * @param unlockCliff The timestamp when the unlock cliff ends
     * @param unlockEnd The timestamp when the unlock period ends
     * @param cliffPercentage The percentage of the unlock amount that is released at the cliff
     */
    function batchCreateTrustUnlock(
        address[] calldata recipients,
        uint256[] calldata unlockAmounts,
        uint256 unlockCliff,
        uint256 unlockEnd,
        uint256 cliffPercentage
    )
        external
        onlyOwner
        nonReentrant
    {
        // Validate the recipients and unlockAmounts arrays
        if (recipients.length == 0) {
            revert Unlock_ZeroLengthArray();
        }

        if (recipients.length != unlockAmounts.length) {
            revert Unlock_ArrayLengthMismatch();
        }

        // Deploy TrustUnlock contracts for each recipient
        for (uint256 i; i < recipients.length;) {
            _createTrustUnlock(recipients[i], unlockAmounts[i], unlockCliff, unlockEnd, cliffPercentage);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Recovers any ERC20 token from TrustUnlockFactory contract and sends it to the specified recipient
     * @param token The address of the token to be recovered
     * @param recipient The address of the recipient of the recovered tokens
     */
    function recoverTokens(address token, address recipient) external onlyOwner nonReentrant {
        if (token == address(0) || recipient == address(0)) {
            revert Unlock_ZeroAddress();
        }

        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(recipient, balance);

        emit TokensRecovered(token, recipient, balance);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to create a new TrustUnlock contract for a recipient with the specified parameters
     * @param recipient The address of the recipient of the TrustUnlock
     * @param unlockAmount The amount of tokens to be unlocked
     * @param unlockCliff The timestamp when the unlock cliff ends
     * @param unlockEnd The timestamp when the unlock period ends
     * @param cliffPercentage The percentage of the unlock amount that is released at the cliff
     */
    function _createTrustUnlock(
        address recipient,
        uint256 unlockAmount,
        uint256 unlockCliff,
        uint256 unlockEnd,
        uint256 cliffPercentage
    )
        internal
    {
        // Check if the TrustUnlock contract already exists for the recipient
        if (trustUnlocks[recipient] != address(0)) {
            revert Unlock_TrustUnlockAlreadyExists();
        }

        // Build the TrustUnlock contract parameters
        TrustUnlock.UnlockParams memory unlockParams = TrustUnlock.UnlockParams({
            owner: recipient,
            registry: address(this),
            unlockAmount: unlockAmount,
            unlockCliff: unlockCliff,
            unlockEnd: unlockEnd,
            cliffPercentage: cliffPercentage
        });

        // Create the TrustUnlock contract
        address trustUnlock = address(new TrustUnlock(unlockParams));

        // Add the TrustUnlock contract to the mapping for the recipient
        trustUnlocks[recipient] = trustUnlock;

        // Emit an event to indicate that the TrustUnlock contract has been created
        emit TrustUnlockCreated(recipient, trustUnlock);
    }
}
