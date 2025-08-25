// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title  IUnlock
 * @author 0xIntuition
 * @notice A shared interface for the Intuition's Trust vesting and unlock contracts
 */
interface IUnlock {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when Trust tokens are claimed
     * @param recipient The address of the recipient
     * @param amount The amount of Trust tokens claimed
     * @param timestamp The time of the claim
     */
    event Transferred(address indexed recipient, uint256 amount, uint256 timestamp);

    /**
     * @notice Emitted when the new recipient is set
     * @param newRecipient The new recipient address
     */
    event RecipientSet(address indexed newRecipient);

    /**
     * @notice Emitted when the TrustBonding contract is set
     * @param newTrustBonding The new TrustBonding contract address
     */
    event TrustBondingSet(address indexed newTrustBonding);

    /**
     * @notice Emitted when the unlock start timestamp is set
     * @param unlockStartTimestamp The timestamp of the unlock start
     */
    event UnlockStartTimestampSet(uint256 indexed unlockStartTimestamp);

    /**
     * @notice Emitted when the bondedAmount is updated in the TrustVestingAndUnlock contract
     * @param newBondedAmount The new bonded amount
     */
    event BondedAmountUpdated(uint256 indexed newBondedAmount);

    /**
     * @notice Emitted when the vesting for the recipient is suspended
     * @param suspensionTimestamp The timestamp at which the vesting was suspended
     * @param finalVested The final amount of Trust tokens vested as of suspension
     * @param finalUnlocked The final amount of Trust tokens unlocked as of suspension
     * @param alreadyClaimed The amount of Trust tokens already claimed by the recipient
     * @param withdrawnAmount The amount of Trust tokens withdrawn to the owner (admin) of the contract
     */
    event VestingSuspended(
        uint256 suspensionTimestamp,
        uint256 finalVested,
        uint256 finalUnlocked,
        uint256 alreadyClaimed,
        uint256 withdrawnAmount
    );
}
