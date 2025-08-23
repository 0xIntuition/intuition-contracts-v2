// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseTest } from "tests/BaseTest.t.sol";

// Concrete test implementation of MultiVault for testing
contract Template is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_function_Success() external view { }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_function_RevertsBecause() external view { }

    /// @dev Fuzz test that provides random values for an unsigned integer, but which rejects zero as an input.
    /// If you need more sophisticated input validation, you should use the `bound` utility instead.
    /// See https://twitter.com/PaulRBerg/status/1622558791685242880
    function testFuzz_Example(uint256 x) external view {
        vm.assume(x != 0); // or x = bound(x, 1, 100)
    }
}
