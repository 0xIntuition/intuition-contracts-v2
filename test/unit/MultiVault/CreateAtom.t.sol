// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {Errors} from "src/libraries/Errors.sol";

contract CreateAtomTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                                   Helpers
    ──────────────────────────────────────────────────────────────────────────*/

    function _atomCost() internal view returns (uint256) {
        return multiVault.getAtomCost();
    }

    function _defaultCurve() internal view returns (uint256) {
        return getBondingCurveConfig().defaultCurveId;
    }

    function _approveTrust(uint256 amount) internal {
        trustToken.approve(address(multiVault), amount);
    }

    /*──────────────────────────────────────────────────────────────────────────
                              1. Happy-path (single)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createAtom_happyPath() external {
        bytes memory data = "hello-world";
        uint256 value = _atomCost() + 1 ether;
        _approveTrust(value);

        bytes32 id = multiVault.createAtom(data, value);

        // basic invariants
        assertEq(id, multiVault.getAtomIdFromData(data));
        assertEq(multiVault.termCount(), 1);
        assertEq(multiVault.atomData(id), data);

        // vault totals & balances
        (uint256 totAssets, uint256 totShares) = multiVault.getVaultTotals(id, _defaultCurve());
        uint256 userShares = multiVault.balanceOf(address(this), id, _defaultCurve());
        assertGt(userShares, 0);
        assertEq(totShares, userShares + getGeneralConfig().minShare);
        assertEq(totAssets, totShares); // share-price == 1 on creation

        // protocol fees – static creation fee is accumulated together with the dynamic protocol fee
        uint256 epoch = multiVault.currentEpoch();
        assertEq(
            multiVault.accumulatedProtocolFees(epoch),
            getAtomConfig().atomCreationProtocolFee + multiVault.protocolFeeAmount(1 ether)
        );
    }

    /*──────────────────────────────────────────────────────────────────────────
                       2. Revert paths (single createAtom)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createAtom_revertIfDataTooLong() external {
        bytes memory longData = new bytes(getGeneralConfig().atomDataMaxLength + 1);
        uint256 val = _atomCost() + 1 ether;
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomDataTooLong.selector));
        multiVault.createAtom(longData, val);
    }

    function test_createAtom_revertIfDuplicate() external {
        bytes memory data = "dup";
        uint256 val = _atomCost() + 1 ether;
        _approveTrust(val * 2);

        multiVault.createAtom(data, val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomExists.selector, data));
        multiVault.createAtom(data, val);
    }

    function test_createAtom_revertIfPaused() external {
        // pause via config and sync
        vm.prank(admin);
        multiVaultConfig.pause();
        multiVault.syncConfig();
        assertTrue(multiVault.paused());

        bytes memory data = "paused-fail";
        uint256 val = _atomCost() + 1 ether;
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ContractPaused.selector));
        multiVault.createAtom(data, val);
    }

    function test_createAtom_revertIfInsufficientBalance() external {
        uint256 shortVal = _atomCost() - 1;
        _approveTrust(shortVal);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        multiVault.createAtom("x", shortVal);
    }

    /*──────────────────────────────────────────────────────────────────────────
                           3. Happy-path (batch)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createAtoms_happyPath() external {
        bytes[] memory arr = new bytes[](2);
        arr[0] = "A";
        arr[1] = "B";

        uint256 val = (_atomCost() + 5 ether) * arr.length;
        _approveTrust(val);

        bytes32[] memory ids = multiVault.createAtoms(arr, val);
        assertEq(ids.length, 2);
        assertEq(multiVault.termCount(), 2);
        assertEq(multiVault.atomData(ids[0]), "A");
        assertEq(multiVault.atomData(ids[1]), "B");
    }

    /*──────────────────────────────────────────────────────────────────────────
                            4. Revert paths (batch)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_createAtoms_revertIfEmptyArray() external {
        bytes[] memory empty;
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_NoAtomDataProvided.selector));
        multiVault.createAtoms(empty, 0);
    }

    function test_createAtoms_revertIfInsufficientBalance() external {
        bytes[] memory arr = new bytes[](2);
        arr[0] = "a";
        arr[1] = "b";

        uint256 tooLittle = (_atomCost() * arr.length) - 1;
        _approveTrust(tooLittle);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        multiVault.createAtoms(arr, tooLittle);
    }

    function test_createAtoms_revertIfDuplicateData() external {
        bytes[] memory arr = new bytes[](2);
        arr[0] = "dup-batch";
        arr[1] = "dup-batch";

        uint256 val = (_atomCost() + 1 ether) * 2;
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_AtomExists.selector, arr[0]));
        multiVault.createAtoms(arr, val);
    }
}
