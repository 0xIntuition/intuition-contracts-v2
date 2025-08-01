// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

import {Errors} from "src/libraries/Errors.sol";

contract RedeemTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                                   helpers
    ──────────────────────────────────────────────────────────────────────────*/

    function _defCurve() internal view returns (uint256) {
        return getBondingCurveConfig().defaultCurveId;
    }

    function _createNewAtom() internal returns (bytes32) {
        uint256 val = multiVault.getAtomCost() + 2 ether;
        trustToken.approve(address(multiVault), val);
        return multiVault.createAtom("new atom", val);
    }

    function _createAnotherNewAtom() internal returns (bytes32) {
        uint256 val = multiVault.getAtomCost() + 2 ether;
        trustToken.approve(address(multiVault), val);
        return multiVault.createAtom("another new atom", val);
    }

    function _depositFor(address user, bytes32 atomId, uint256 value) internal returns (uint256 shares) {
        vm.prank(user);
        trustToken.approve(address(multiVault), value);

        uint256 defaultCurveId = _defCurve();

        vm.prank(user);
        shares = multiVault.deposit(user, atomId, defaultCurveId, value, _minAmount(value, defaultSlippage));
    }

    /*──────────────────────────────────────────────────────────────────────────
                               1. happy single redeem
    ──────────────────────────────────────────────────────────────────────────*/

    function test_redeem_happyPath() external {
        bytes32 id = _createNewAtom();

        uint256 val = 5 ether;
        uint256 sharesMinted = _depositFor(address(this), id, val);

        uint256 redeemAmount = sharesMinted / 2;
        uint256 shareBalanceBefore = multiVault.balanceOf(address(this), id, _defCurve());

        uint256 balBefore = trustToken.balanceOf(address(this));
        uint256 previewAssets = multiVault.previewRedeem(redeemAmount, id, _defCurve()); // previewAssets is the amount of assets we expect to get back
        uint256 assetsGot =
            multiVault.redeem(redeemAmount, address(this), id, _defCurve(), _minAmount(previewAssets, defaultSlippage));
        assertGt(assetsGot, 0);
        assertEq(trustToken.balanceOf(address(this)), balBefore + assetsGot);

        // internal share balance decreased appropriately
        uint256 shareBalanceAfter = multiVault.balanceOf(address(this), id, _defCurve());
        assertEq(shareBalanceAfter, shareBalanceBefore - redeemAmount);
    }

    /*──────────────────────────────────────────────────────────────────────────
                              2. revert branches
    ──────────────────────────────────────────────────────────────────────────*/

    function test_redeem_revertIfRedeemerNotApproved() external {
        bytes32 id = _createNewAtom();
        uint256 value = 3 ether;

        uint256 shares = _depositFor(bob, id, value); // bob now holds shares

        uint256 defaultCurveId = _defCurve();

        vm.prank(bob);
        // receiver is alice, bob has no redeem approval
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_RedeemerNotApproved.selector));
        multiVault.redeem(shares / 2, alice, id, defaultCurveId, _minAmount(value, defaultSlippage));
    }

    function test_redeem_revertIfZeroShares() external {
        bytes32 id = _createNewAtom();
        uint256 defaultCurveId = _defCurve();

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_DepositOrRedeemZeroShares.selector));
        multiVault.redeem(0, address(this), id, defaultCurveId, _minAmount(0, defaultSlippage));
    }

    function test_redeem_revertIfTryingToRedeemOverAvailableBalance() external {
        bytes32 id = _createNewAtom();
        uint256 val = 2 ether;
        _depositFor(address(this), id, val);

        uint256 defaultCurveId = _defCurve();
        (uint256 shares,) = multiVault.getVaultStateForUser(id, defaultCurveId, address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientSharesInVault.selector));
        multiVault.redeem(shares + 1, address(this), id, defaultCurveId, _minAmount(val, defaultSlippage));
    }

    function test_redeem_revertIfRemainingSharesBelowMinShare() external {
        bytes32 id = _createNewAtom();
        uint256 val = 2 ether;
        _depositFor(address(this), id, val);

        uint256 minShare = getGeneralConfig().minShare;
        uint256 defaultCurveId = _defCurve();
        (uint256 userShares,) = multiVault.getVaultStateForUser(id, defaultCurveId, address(this));
        uint256 previewAssets = multiVault.previewRedeem(userShares, id, defaultCurveId); // previewAssets is the amount of assets we expect to get back

        multiVault.redeem(userShares, address(this), id, defaultCurveId, _minAmount(previewAssets, defaultSlippage)); // redeem all user shares so that only minShare remains

        uint256 burnAddressRedeemAmount = 1;
        uint256 remainingShares = minShare - burnAddressRedeemAmount;
        previewAssets = multiVault.previewRedeem(burnAddressRedeemAmount, id, defaultCurveId); // previewAssets is the amount of assets we expect to get back

        address burnAddress = multiVault.BURN_ADDRESS();

        vm.prank(burnAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MultiVault_InsufficientRemainingSharesInVault.selector, remainingShares)
        );
        multiVault.redeem(1, burnAddress, id, defaultCurveId, _minAmount(previewAssets, defaultSlippage));
    }

    function test_redeem_revertIfTermInvalid() external {
        uint256 defaultCurveId = _defCurve();

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermDoesNotExist.selector));
        multiVault.redeem(1, address(this), bytes32("555"), defaultCurveId, _minAmount(1 ether, defaultSlippage));
    }

    function test_redeem_revertIfCurveInvalid() external {
        bytes32 id = _createNewAtom();
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVault.redeem(1, address(this), id, 99, _minAmount(1 ether, defaultSlippage));
    }

    /*──────────────────────────────────────────────────────────────────────────
                                3. batchRedeem
    ──────────────────────────────────────────────────────────────────────────*/

    function test_batchRedeem_happyPath() external {
        bytes32 id1 = _createNewAtom();
        bytes32 id2 = _createAnotherNewAtom();

        uint256 s1 = _depositFor(address(this), id1, 3 ether);
        uint256 s2 = _depositFor(address(this), id2, 4 ether);

        uint256[] memory shares = new uint256[](2);
        bytes32[] memory ids = new bytes32[](2);
        uint256[] memory curves = new uint256[](2);
        uint256[] memory minAmts = new uint256[](2);
        shares[0] = s1 / 2;
        shares[1] = s2 / 2;
        ids[0] = id1;
        ids[1] = id2;
        curves[0] = _defCurve();
        curves[1] = _defCurve();

        uint256 previewAssets0 = multiVault.previewRedeem(shares[0], id1, curves[0]);
        uint256 previewAssets1 = multiVault.previewRedeem(shares[1], id2, curves[1]);

        minAmts[0] = _minAmount(previewAssets0, defaultSlippage);
        minAmts[1] = _minAmount(previewAssets1, defaultSlippage);

        uint256 balBefore = trustToken.balanceOf(address(this));
        uint256[] memory assets = multiVault.batchRedeem(shares, address(this), ids, curves, minAmts);

        assertEq(assets.length, 2);
        assertGt(assets[0], 0);
        assertEq(trustToken.balanceOf(address(this)), balBefore + assets[0] + assets[1]);
    }

    function test_batchRedeem_revertIfEmpty() external {
        bytes32[] memory emptyIds;
        uint256[] memory empty;
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_EmptyArray.selector));
        multiVault.batchRedeem(empty, address(this), emptyIds, empty, empty);
    }

    function test_batchRedeem_revertIfLengthMismatch() external {
        uint256[] memory shares = new uint256[](1);
        bytes32[] memory ids = new bytes32[](2);
        uint256[] memory curves = new uint256[](1);
        uint256[] memory minAmts = new uint256[](2);
        shares[0] = 1 ether;
        ids[0] = _createNewAtom();
        ids[1] = _createAnotherNewAtom();
        curves[0] = _defCurve();
        minAmts[0] = _minAmount(shares[0], defaultSlippage);
        minAmts[1] = _minAmount(2 ether, defaultSlippage);

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        multiVault.batchRedeem(shares, address(this), ids, curves, minAmts);
    }

    function test_batchRedeem_revertIfNotApproved() external {
        bytes32 id = _createNewAtom();
        uint256 sh = _depositFor(bob, id, 2 ether);

        uint256[] memory shares = new uint256[](1);
        bytes32[] memory ids = new bytes32[](1);
        uint256[] memory curves = new uint256[](1);
        uint256[] memory minAmts = new uint256[](1);
        shares[0] = sh;
        ids[0] = id;
        curves[0] = _defCurve();
        minAmts[0] = _minAmount(2 ether, defaultSlippage);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_RedeemerNotApproved.selector));
        multiVault.batchRedeem(shares, alice, ids, curves, minAmts);
    }
}
