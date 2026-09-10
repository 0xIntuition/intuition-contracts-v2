// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { TrustBondingBase } from "tests/unit/TrustBonding/TrustBondingBase.t.sol";
import { ISatelliteEmissionsController } from "src/interfaces/ISatelliteEmissionsController.sol";

/// @dev forge test --match-path 'tests/unit/SatelliteEmissionsController/Transfer.t.sol'
contract TransferTest is TrustBondingBase {
    event NativeTokenTransferred(address indexed recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        vm.deal(address(protocol.satelliteEmissionsController), 10 ether);
    }

    function test_transfer_successful() external {
        uint256 recipientBalanceBefore = users.bob.balance;

        resetPrank(address(protocol.trustBonding));
        vm.expectEmit(true, true, true, true);
        emit NativeTokenTransferred(users.bob, 1 ether);
        protocol.satelliteEmissionsController.transfer(users.bob, 1 ether);

        assertEq(users.bob.balance, recipientBalanceBefore + 1 ether, "recipient should receive the transfer");
        assertEq(address(protocol.satelliteEmissionsController).balance, 9 ether, "satellite balance should decrease");
    }

    function test_transfer_revertsOnZeroRecipient() external {
        resetPrank(address(protocol.trustBonding));
        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAddress.selector)
        );
        protocol.satelliteEmissionsController.transfer(address(0), 1 ether);
    }

    function test_transfer_revertsOnZeroAmount() external {
        resetPrank(address(protocol.trustBonding));
        vm.expectRevert(
            abi.encodeWithSelector(ISatelliteEmissionsController.SatelliteEmissionsController_InvalidAmount.selector)
        );
        protocol.satelliteEmissionsController.transfer(users.bob, 0);
    }

    function test_transfer_revertsOnInsufficientBalance() external {
        uint256 tooMuch = address(protocol.satelliteEmissionsController).balance + 1;

        resetPrank(address(protocol.trustBonding));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISatelliteEmissionsController.SatelliteEmissionsController_InsufficientBalance.selector
            )
        );
        protocol.satelliteEmissionsController.transfer(users.bob, tooMuch);
    }

    function test_transfer_revertsWithUnauthorizedCaller() external {
        bytes32 controllerRole = protocol.satelliteEmissionsController.CONTROLLER_ROLE();

        resetPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, controllerRole
            )
        );
        protocol.satelliteEmissionsController.transfer(users.bob, 1 ether);
    }
}
