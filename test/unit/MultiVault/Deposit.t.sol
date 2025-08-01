// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {Errors} from "src/libraries/Errors.sol";

contract DepositTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                                   Helpers
    ──────────────────────────────────────────────────────────────────────────*/

    function _defCurve() internal view returns (uint256) {
        return getBondingCurveConfig().defaultCurveId;
    }

    function _altCurve() internal pure returns (uint256) {
        return 2; // OffsetProgressive added in setUp (id == 2)
    }

    function _approveTrust(uint256 amt) internal {
        trustToken.approve(address(multiVault), amt);
    }

    function _createAtoms() internal returns (bytes32, bytes32, bytes32) {
        uint256 val = multiVault.getAtomCost() + 1 ether;
        _approveTrust(val * 3);
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "A";
        atomDataArray[1] = "B";
        atomDataArray[2] = "C";
        bytes32[] memory atomIds = multiVault.createAtoms(atomDataArray, val * 3);
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /*──────────────────────────────────────────────────────────────────────────
                               1. Happy paths
    ──────────────────────────────────────────────────────────────────────────*/

    /// deposit into existing atom vault (non-creation branch)
    function test_deposit_existingAtom() external {
        (bytes32 atomId,,) = _createAtoms(); // only need first
        uint256 value = 5 ether;
        _approveTrust(value);

        uint256 userSharesBefore = multiVault.balanceOf(address(this), atomId, _defCurve());
        (, uint256 totAssetsBefore) = multiVault.getVaultTotals(atomId, _defCurve());

        uint256 minted =
            multiVault.deposit(address(this), atomId, _defCurve(), value, _minAmount(value, defaultSlippage));

        // shares > 0, vault totals updated
        assertGt(minted, 0);
        // (, uint256 totShares) = multiVault.getVaultTotals(atomId, _defCurve());
        assertEq(multiVault.balanceOf(address(this), atomId, _defCurve()), userSharesBefore + minted);
        (, uint256 atomAssets) = multiVault.getVaultTotals(atomId, _defCurve());
        assertEq(
            atomAssets,
            totAssetsBefore + value - multiVault.protocolFeeAmount(value)
                - multiVault.atomWalletDepositFeeAmount(value, atomId)
        );
    }

    /// first deposit on an alternative curve (creation branch)
    function test_deposit_createsAltCurveVault() external {
        (bytes32 atomId,,) = _createAtoms();
        uint256 curve = _altCurve();
        uint256 value = 3 ether;
        _approveTrust(value);

        uint256 previewShares = multiVault.previewDeposit(value, atomId, curve);
        uint256 minted =
            multiVault.deposit(address(this), atomId, curve, value, _minAmount(previewShares, defaultSlippage));

        // ghost-share minShare minted to admin
        uint256 minShare = getGeneralConfig().minShare;
        (uint256 totalShares,) = multiVault.getVaultTotals(atomId, curve);
        assertEq(totalShares, minted + minShare);
        assertEq(multiVault.balanceOf(multiVault.BURN_ADDRESS(), atomId, curve), minShare);
    }

    /// deposit into triple vault (no counter-stake)
    function test_deposit_tripleHappyPath() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createAtoms();
        _approveTrust(type(uint256).max); // approve max to cover costs
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;
        bytes32 tId = multiVault.createTriples(subjectIds, predicateIds, objectIds, multiVault.getTripleCost() + 1 ether)[0];

        uint256 val = 2 ether;

        uint256 minted = multiVault.deposit(address(this), tId, _defCurve(), val, _minAmount(val, defaultSlippage));
        assertGt(minted, 0);
    }

    /*──────────────────────────────────────────────────────────────────────────
                              2. Revert branches
    ──────────────────────────────────────────────────────────────────────────*/

    function test_deposit_revertIfSenderNotApproved() external {
        (bytes32 atomId,,) = _createAtoms();

        uint256 val = 1 ether;
        vm.prank(bob);
        trustToken.approve(address(multiVault), val);

        uint256 defaultCurveId = _defCurve();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_SenderNotApproved.selector));
        multiVault.deposit(alice, atomId, defaultCurveId, val, _minAmount(val, defaultSlippage));
    }

    function test_deposit_revertIfTermMissing() external {
        uint256 val = 1 ether;
        _approveTrust(val);

        uint256 defaultCurveId = _defCurve();

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermDoesNotExist.selector));
        multiVault.deposit(address(this), bytes32("777"), defaultCurveId, val, _minAmount(val, defaultSlippage));
    }

    function test_deposit_revertIfCurveInvalid() external {
        (bytes32 atomId,,) = _createAtoms();
        uint256 val = 1 ether;
        _approveTrust(val);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVault.deposit(address(this), atomId, 99, val, _minAmount(val, defaultSlippage));
    }

    function test_deposit_revertIfBelowMin() external {
        (bytes32 atomId,,) = _createAtoms();
        uint256 val = getGeneralConfig().minDeposit - 1;
        _approveTrust(val);

        uint256 defaultCurveId = _defCurve();

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_DepositBelowMinimumDeposit.selector));
        multiVault.deposit(address(this), atomId, defaultCurveId, val, _minAmount(val, defaultSlippage));
    }

    /// make bob hold counter-stake then try deposit to opposite triple
    function test_deposit_revertIfHasCounterStake() external {
        (bytes32 s, bytes32 p, bytes32 o) = _createAtoms();
        _approveTrust(type(uint256).max); // approve max to cover costs
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;
        bytes32 tId = multiVault.createTriples(subjectIds, predicateIds, objectIds, multiVault.getTripleCost() + 1 ether)[0];
        bytes32 ctId = multiVault.getCounterIdFromTriple(tId);

        uint256 defaultCurveId = _defCurve();

        // Bob deposits into counter-triple first
        uint256 val1 = 2 ether;
        vm.startPrank(bob);
        trustToken.approve(address(multiVault), val1);
        multiVault.deposit(bob, ctId, defaultCurveId, val1, _minAmount(val1, defaultSlippage));
        vm.stopPrank();

        // Bob now tries to deposit into original triple; this should revert
        uint256 val2 = 1 ether;
        vm.startPrank(bob);
        trustToken.approve(address(multiVault), val2);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_HasCounterStake.selector));
        multiVault.deposit(bob, tId, defaultCurveId, val2, _minAmount(val2, defaultSlippage));
        vm.stopPrank();
    }

    function test_deposit_revertIfPaused() external {
        (bytes32 atomId,,) = _createAtoms();
        vm.prank(admin);
        multiVaultConfig.pause();
        multiVault.syncConfig();

        uint256 val = 1 ether;
        _approveTrust(val);

        uint256 defaultCurveId = _defCurve();

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ContractPaused.selector));
        multiVault.deposit(address(this), atomId, defaultCurveId, val, _minAmount(val, defaultSlippage));
    }

    /*──────────────────────────────────────────────────────────────────────────
                                3. batchDeposit
    ──────────────────────────────────────────────────────────────────────────*/

    function test_batchDeposit_happyPath() external {
        (bytes32 a1, bytes32 a2,) = _createAtoms();
        bytes32[] memory ids = new bytes32[](2);
        uint256[] memory curve = new uint256[](2);
        uint256[] memory amts = new uint256[](2);
        uint256[] memory minAmts = new uint256[](2);

        ids[0] = a1;
        ids[1] = a2;
        curve[0] = _defCurve();
        curve[1] = _defCurve();
        amts[0] = 2 ether;
        amts[1] = 3 ether;
        minAmts[0] = _minAmount(amts[0], 1000);

        uint256 total = amts[0] + amts[1];
        _approveTrust(total);

        uint256[] memory minted = multiVault.batchDeposit(address(this), ids, curve, amts, minAmts);
        assertEq(minted.length, 2);
        assertGt(minted[0], 0);
        assertGt(minted[1], 0);
    }

    function test_batchDeposit_revertIfEmpty() external {
        bytes32[] memory emptyId;
        uint256[] memory empty;
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        multiVault.batchDeposit(address(this), emptyId, empty, empty, empty);
    }

    function test_batchDeposit_revertIfLengthMismatch() external {
        (bytes32 a,,) = _createAtoms();
        bytes32[] memory ids = new bytes32[](1);
        uint256[] memory curs = new uint256[](2);
        uint256[] memory vals = new uint256[](1);
        uint256[] memory minAmts = new uint256[](2);
        ids[0] = a;
        vals[0] = 1;
        minAmts[0] = _minAmount(vals[0], 1000);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        multiVault.batchDeposit(address(this), ids, curs, vals, minAmts);
    }

    function test_batchDeposit_revertIfSenderNotApproved() external {
        (bytes32 a,,) = _createAtoms();
        bytes32[] memory ids = new bytes32[](1);
        uint256[] memory curs = new uint256[](1);
        uint256[] memory vals = new uint256[](1);
        uint256[] memory minAmts = new uint256[](1);
        ids[0] = a;
        curs[0] = _defCurve();
        vals[0] = 1 ether;
        minAmts[0] = _minAmount(vals[0], 1000);

        vm.prank(bob);
        trustToken.approve(address(multiVault), vals[0]);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_SenderNotApproved.selector));
        multiVault.batchDeposit(alice, ids, curs, vals, minAmts);
    }
}
