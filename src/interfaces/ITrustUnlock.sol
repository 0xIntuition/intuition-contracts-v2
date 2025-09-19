// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title  ITrustUnlock
 * @author 0xIntuition
 * @notice A shared interface for the Intuition's Trust vesting and unlock contracts
 */
interface ITrustUnlock {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when the bondedAmount is updated in the TrustVestingAndUnlock contract
     * @param newBondedAmount The new bonded amount
     */
    event BondedAmountUpdated(uint256 indexed newBondedAmount);
}
