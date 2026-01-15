// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Counter
 * @author 0xIntuition
 * @notice A simple counter contract with access control for testing purposes
 */
contract Counter is Ownable {
    /// @notice The current count value
    uint256 private count;

    /// @notice Events
    event CountIncremented(uint256 newCount);
    event CountDecremented(uint256 newCount);
    event CountReset();

    /// @notice Errors
    error Counter_Underflow();

    /**
     * @notice Constructor sets the owner
     * @param _owner The address of the owner
     */
    constructor(address _owner) Ownable(_owner) { }

    /**
     * @notice Increments the count by 1
     * @dev Only callable by the owner
     */
    function incrementCount() external onlyOwner {
        ++count;
        emit CountIncremented(count);
    }

    /**
     * @notice Decrements the count by 1
     * @dev Only callable by the owner
     */
    function decrementCount() external onlyOwner {
        if (count == 0) revert Counter_Underflow();
        --count;
        emit CountDecremented(count);
    }

    /**
     * @notice Resets the count to 0
     * @dev Only callable by the owner
     */
    function resetCount() external onlyOwner {
        count = 0;
        emit CountReset();
    }

    /// @notice Returns the current count value
    function getCount() external view returns (uint256) {
        return count;
    }
}
