// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title Counter
 * @author 0xIntuition
 * @notice A simple counter contract for testing purposes
 */
contract Counter {
    /// @notice The current count value
    uint256 private count;

    /// @notice Events
    event CountIncremented(uint256 newCount);
    event CountDecremented(uint256 newCount);
    event CountReset();

    /// @notice Errors
    error Counter_Underflow();

    /// @notice Increments the count by 1
    function incrementCount() external {
        ++count;
        emit CountIncremented(count);
    }

    /// @notice Decrements the count by 1
    function decrementCount() external {
        if (count == 0) revert Counter_Underflow();
        --count;
        emit CountDecremented(count);
    }

    /// @notice Resets the count to 0
    function resetCount() external {
        count = 0;
        emit CountReset();
    }

    /// @notice Returns the current count value
    function getCount() external view returns (uint256) {
        return count;
    }
}
