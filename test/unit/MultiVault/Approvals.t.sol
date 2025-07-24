// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {Errors} from "src/libraries/Errors.sol";

contract ApprovalsTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                                   Helpers
    ──────────────────────────────────────────────────────────────────────────*/

    IMultiVault.ApprovalTypes private constant NONE = IMultiVault.ApprovalTypes.NONE;
    IMultiVault.ApprovalTypes private constant DEPOSIT = IMultiVault.ApprovalTypes.DEPOSIT;
    IMultiVault.ApprovalTypes private constant REDEMPTION = IMultiVault.ApprovalTypes.REDEMPTION;
    IMultiVault.ApprovalTypes private constant BOTH = IMultiVault.ApprovalTypes.BOTH;

    /*──────────────────────────────────────────────────────────────────────────
                           approve()  – happy-path branches
    ──────────────────────────────────────────────────────────────────────────*/

    function test_approve_depositOnly() external {
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit IMultiVault.ApprovalTypeUpdated(bob, alice, DEPOSIT);

        multiVault.approve(bob, DEPOSIT);
        vm.stopPrank();

        assertTrue(multiVault.isApprovedToDeposit(bob, alice));
        assertTrue(!multiVault.isApprovedToRedeem(bob, alice));
    }

    function test_approve_redeemOnly() external {
        vm.prank(alice);
        multiVault.approve(bob, REDEMPTION);

        assertTrue(!multiVault.isApprovedToDeposit(bob, alice));
        assertTrue(multiVault.isApprovedToRedeem(bob, alice));
    }

    function test_approve_both() external {
        vm.prank(alice);
        multiVault.approve(bob, BOTH);

        assertTrue(multiVault.isApprovedToDeposit(bob, alice));
        assertTrue(multiVault.isApprovedToRedeem(bob, alice));
    }

    /*──────────────────────────────────────────────────────────────────────────
                           approve()  – NONE branch (deletion)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_approve_none_deletesMapping() external {
        vm.startPrank(alice);
        // first give BOTH
        multiVault.approve(bob, BOTH);
        assertTrue(multiVault.isApprovedToDeposit(bob, alice));

        // now revoke
        multiVault.approve(bob, NONE);
        vm.stopPrank();

        assertTrue(!multiVault.isApprovedToDeposit(bob, alice));
        assertTrue(!multiVault.isApprovedToRedeem(bob, alice));
    }

    /*──────────────────────────────────────────────────────────────────────────
                               Revert path
    ──────────────────────────────────────────────────────────────────────────*/

    function test_approve_shouldRevertIfSelf() external {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_CannotApproveOrRevokeSelf.selector));
        multiVault.approve(alice, DEPOSIT);
        vm.stopPrank();
    }

    /*──────────────────────────────────────────────────────────────────────────
                              Fuzz - idempotent
    ──────────────────────────────────────────────────────────────────────────*/

    /// @notice Fuzz over non-zero approval types to confirm storage mirrors enum
    function test_fuzz_approve_setsCorrectBits(address sender, address receiver, uint8 rawType) external {
        vm.assume(sender != receiver && sender != address(0) && receiver != address(0));

        uint8 bounded = uint8(bound(rawType, 1, 3)); // map to 1-3
        IMultiVault.ApprovalTypes aType = IMultiVault.ApprovalTypes(bounded);

        vm.prank(receiver);
        multiVault.approve(sender, aType);

        bool d = multiVault.isApprovedToDeposit(sender, receiver);
        bool r = multiVault.isApprovedToRedeem(sender, receiver);

        assertEq(d, (bounded & 1) != 0);
        assertEq(r, (bounded & 2) != 0);
    }
}
