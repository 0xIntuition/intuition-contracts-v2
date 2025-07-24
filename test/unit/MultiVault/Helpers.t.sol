// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Errors} from "src/libraries/Errors.sol";
import {AtomWallet} from "src/AtomWallet.sol";

import {MultiVaultBase} from "test/MultiVaultBase.sol";
import {MockToken} from "test/mocks/MockToken.t.sol";

contract HelpersTest is MultiVaultBase {
    /*──────────────────────────────────────────────────────────────────────────
                          1. Fee-helper pure maths branches
    ──────────────────────────────────────────────────────────────────────────*/

    function test_feeHelpers_valuesMatchFormula() external view {
        uint256 assets = 10 ether;

        uint256 entry = multiVault.entryFeeAmount(assets);
        uint256 exit = multiVault.exitFeeAmount(assets);
        uint256 proto = multiVault.protocolFeeAmount(assets);

        uint256 denom = getGeneralConfig().feeDenominator;
        assertEq(
            entry, assets * getVaultFees().entryFee / denom + (assets * getVaultFees().entryFee % denom == 0 ? 0 : 1)
        );
        assertEq(exit, assets * getVaultFees().exitFee / denom + (assets * getVaultFees().exitFee % denom == 0 ? 0 : 1));
        assertEq(
            proto,
            assets * getVaultFees().protocolFee / denom + (assets * getVaultFees().protocolFee % denom == 0 ? 0 : 1)
        );
    }

    function test_atomDepositFractionOnlyForTriple() external {
        // create atom
        uint256 val = multiVault.getAtomCost() + 1 ether;
        trustToken.approve(address(multiVault), val);
        bytes32 atomId = multiVault.createAtom("Test", val);

        // create triple
        (bytes32 s, bytes32 p, bytes32 o) = (atomId, atomId, atomId); // duplicates ok for this test
        uint256 tripleVal = multiVault.getTripleCost() + 1 ether;
        trustToken.approve(address(multiVault), tripleVal);
        bytes32 tripleId = multiVault.createTriple(s, p, o, tripleVal);

        uint256 amt = 5 ether;
        assertEq(multiVault.atomDepositFractionAmount(amt, atomId), 0);
        assertGt(multiVault.atomDepositFractionAmount(amt, tripleId), 0);
    }

    function test_atomWalletFeeOnlyForAtoms() external {
        uint256 val = multiVault.getAtomCost() + 1 ether;
        trustToken.approve(address(multiVault), val);
        bytes32 atomId = multiVault.createAtom("AWF", val);

        (bytes32 s, bytes32 p, bytes32 o) = (atomId, atomId, atomId);
        uint256 tVal = multiVault.getTripleCost() + 1 ether;
        trustToken.approve(address(multiVault), tVal);
        bytes32 tripleId = multiVault.createTriple(s, p, o, tVal);

        uint256 amt = 3 ether;
        assertEq(multiVault.atomWalletDepositFeeAmount(amt, tripleId), 0);
        assertGt(multiVault.atomWalletDepositFeeAmount(amt, atomId), 0);
    }

    /*──────────────────────────────────────────────────────────────────────────
               2. Accounting helpers: convert / preview / max* / price
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_convertRoundTrip_previewHelpers() external {
    //     uint256 val = multiVault.getAtomCost() + 9 ether;
    //     trustToken.approve(address(multiVault), val);
    //     bytes32 id = multiVault.createAtom("ACC", val);

    //     uint256 curve = getBondingCurveConfig().defaultCurveId;

    //     uint256 assets = 2 ether;
    //     trustToken.approve(address(multiVault), assets);
    //     uint256 minted = multiVault.deposit(address(this), id, curve, assets);

    //     assertEq(multiVault.maxRedeem(address(this), id, curve), minted);
    //     assertEq(multiVault.convertToAssets(minted, id, curve), multiVault.previewRedeem(minted, id, curve));

    //     uint256 oneSharePrice = multiVault.currentSharePrice(id, curve);
    //     assertEq(oneSharePrice, multiVault.convertToAssets(1e18, id, curve));

    //     uint256 preview = multiVault.previewDeposit(assets, id, curve);
    //     assertGt(preview, 0);
    // }

    /*──────────────────────────────────────────────────────────────────────────
                          3. Triple-helper pure functions
    ──────────────────────────────────────────────────────────────────────────*/

    function test_tripleHelperFunctions() external {
        (bytes32 a, bytes32 b, bytes32 c) = _createBasicAtoms();
        uint256 tVal = multiVault.getTripleCost() + 1 ether;
        trustToken.approve(address(multiVault), tVal);
        bytes32 t = multiVault.createTriple(a, b, c, tVal);

        bytes32 ct = multiVault.getCounterIdFromTriple(t);
        assertTrue(multiVault.isTripleId(t));
        assertTrue(multiVault.isCounterTripleId(ct));
        assertEq(multiVault.getTripleIdFromCounter(ct), t);

        (bytes32 sa, bytes32 pa, bytes32 oa) = multiVault.getTripleAtoms(t);
        assertEq(sa, a);
        assertEq(pa, b);
        assertEq(oa, c);

        assertEq(t, multiVault.tripleIdFromAtomIds(a, b, c));
    }

    /*──────────────────────────────────────────────────────────────────────────
                  4. Misc view helpers & balanceOfBatch branch
    ──────────────────────────────────────────────────────────────────────────*/

    function test_miscViewFunctionsAndBatch() external {
        (bytes32 id,,) = _createBasicAtoms();

        address[] memory accts = new address[](2);
        bytes32[] memory ids = new bytes32[](2);
        accts[0] = address(this);
        accts[1] = bob;
        ids[0] = id;
        ids[1] = id;

        uint256[] memory bals = multiVault.balanceOfBatch(accts, ids, getBondingCurveConfig().defaultCurveId);
        assertEq(bals.length, 2);
        assertGt(bals[0], 0);
        assertEq(bals[1], 0);

        (uint256 userShares, uint256 userAssets) =
            multiVault.getVaultStateForUser(id, getBondingCurveConfig().defaultCurveId, address(this));
        assertEq(userShares, bals[0]);
        assertGt(userAssets, 0);

        assertEq(multiVault.getIsProtocolFeeDistributionEnabled(), getGeneralConfig().protocolFeeDistributionEnabled);
        assertEq(multiVault.getAtomWarden(), getWalletConfig().atomWarden);
    }

    /*──────────────────────────────────────────────────────────────────────────
                      5. computeAtomWalletAddr & deploy flow
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_deployAtomWallet_andComputeAddr() external {
    //     (bytes32 id,,) = _createBasicAtoms();
    //     address predicted = multiVault.computeAtomWalletAddr(id);

    //     uint256 codeLenBefore = predicted.code.length;
    //     address returned = multiVault.deployAtomWallet(id);

    //     // first call deploys, second returns predicted addr without reverting
    //     assertEq(returned, predicted);
    //     assertGt(predicted.code.length, codeLenBefore);

    //     // calling again -> idempotent path
    //     address returned2 = multiVault.deployAtomWallet(id);
    //     assertEq(returned2, predicted);
    // }

    /*──────────────────────────────────────────────────────────────────────────
                 6. claimAtomWalletDepositFees end-to-end branch
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_claimAtomWalletDepositFees_flow() external {
    //     (bytes32 id,,) = _createBasicAtoms();
    //     address walletAddr = multiVault.computeAtomWalletAddr(id);

    //     // make a second deposit to accrue atom wallet fees
    //     uint256 val = 5 ether;
    //     trustToken.approve(address(multiVault), val);
    //     multiVault.deposit(address(this), id, getBondingCurveConfig().defaultCurveId, val);

    //     uint256 feesAccrued = multiVault.accumulatedAtomWalletDepositFees(walletAddr);
    //     assertGt(feesAccrued, 0);

    //     // deploy wallet & set owner to this test contract (AtomWallet.initialize does that)
    //     multiVault.deployAtomWallet(id);

    //     uint256 balBefore = trustToken.balanceOf(address(this));
    //     // impersonate wallet contract to call claim
    //     vm.prank(walletAddr);
    //     multiVault.claimAtomWalletDepositFees(id);

    //     // assertEq(trustToken.balanceOf(address(this)), balBefore + feesAccrued);
    //     assertEq(multiVault.accumulatedAtomWalletDepositFees(walletAddr), 0);
    // }

    /*──────────────────────────────────────────────────────────────────────────
                          7. recoverTokens admin helper
    ──────────────────────────────────────────────────────────────────────────*/

    function test_recoverTokens_happyAndReverts() external {
        // deploy mock ERC20 and send to vault
        MockToken testToken = new MockToken("Test Token", "TST");
        testToken.mint(address(this), 1e18);
        testToken.transfer(address(multiVault), 1e18);

        // zero addr token revert
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        multiVault.recoverTokens(address(0), admin);

        // zero addr recipient revert
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ZeroAddress.selector));
        multiVault.recoverTokens(address(testToken), address(0));

        // cannot recover TRUST
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_CannotRecoverTrust.selector));
        multiVault.recoverTokens(address(trustToken), admin);

        // happy path
        uint256 balBefore = testToken.balanceOf(admin);
        vm.prank(admin);
        multiVault.recoverTokens(address(testToken), admin);
        assertEq(testToken.balanceOf(admin), balBefore + 1e18);
    }

    /*──────────────────────────────────────────────────────────────────────────
                      8. helper values & uri formatting
    ──────────────────────────────────────────────────────────────────────────*/

    // getAtomCost / getTripleCost exact-formula checks
    function test_getAtomAndTripleCost_components() external view {
        uint256 expectedAtom = getAtomConfig().atomCreationProtocolFee + getGeneralConfig().minShare;
        uint256 expectedTriple = getTripleConfig().tripleCreationProtocolFee
            + getTripleConfig().totalAtomDepositsOnTripleCreation + getGeneralConfig().minShare * 2;

        assertEq(multiVault.getAtomCost(), expectedAtom);
        assertEq(multiVault.getTripleCost(), expectedTriple);
    }

    // maxDeposit constant
    function test_maxDeposit_constant() external view {
        assertEq(multiVault.maxDeposit(), type(uint256).max);
    }

    // maxRedeem zero for non-holder
    function test_maxRedeem_zeroForOther() external view {
        bytes32 id = bytes32("1"); // before any deposits bob owns 0
        assertEq(multiVault.maxRedeem(bob, id, getBondingCurveConfig().defaultCurveId), 0);
    }

    /*──────────────────────────────────────────────────────────────────────────
             9. balanceOfBatch edge-case reverts (helper guard branches)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_balanceOfBatch_revertIfCurveInvalid() external {
        address[] memory ac = new address[](1);
        bytes32[] memory ids = new bytes32[](1);
        ac[0] = address(this);
        ids[0] = bytes32("1"); // any id

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        multiVault.balanceOfBatch(ac, ids, 99);
    }

    function test_balanceOfBatch_revertIfLengthMismatch() external {
        address[] memory ac = new address[](1);
        bytes32[] memory ids = new bytes32[](2);
        ac[0] = address(this);
        ids[0] = bytes32("1");
        ids[1] = bytes32("2");

        uint256 defaultCurveId = getBondingCurveConfig().defaultCurveId;

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_ArraysNotSameLength.selector));
        multiVault.balanceOfBatch(ac, ids, defaultCurveId);
    }

    /*──────────────────────────────────────────────────────────────────────────
           10. isApproved helper fast-path (sender == receiver branch)
    ──────────────────────────────────────────────────────────────────────────*/

    function test_isApproved_selfAlwaysTrue() external view {
        assertTrue(multiVault.isApprovedToDeposit(alice, alice));
        assertTrue(multiVault.isApprovedToRedeem(alice, alice));
    }

    /*──────────────────────────────────────────────────────────────────────────
         11. utilization & rollover helpers + protocol-fee claiming
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_rollover_movesUtilizationAndClaimsFees() external {
    //     // ─ 1) create atom & deposit once in epoch 0
    //     uint256 cost = multiVault.getAtomCost() + 5 ether;
    //     trustToken.approve(address(multiVault), cost);
    //     bytes32 id = multiVault.createAtom("UTIL", cost);

    //     uint256 epoch0 = multiVault.currentEpoch();
    //     uint256 protoFee0 = multiVault.accumulatedProtocolFees(epoch0);
    //     assertGt(protoFee0, 0);

    //     int256 util0 = multiVault.getTotalUtilizationForEpoch(epoch0);
    //     assertEq(util0, int256(cost)); // total util equals first deposit (no redeems yet)

    //     // ─ 2) warp to next epoch and deposit again to trigger rollover + fee transfer
    //     uint256 multisigBefore = trustToken.balanceOf(getGeneralConfig().protocolMultisig);

    //     vm.warp(block.timestamp + epochLength + 10);

    //     uint256 extra = 1 ether;
    //     trustToken.approve(address(multiVault), extra);
    //     multiVault.deposit(address(this), id, getBondingCurveConfig().defaultCurveId, extra);

    //     uint256 epoch1 = multiVault.currentEpoch();
    //     assertEq(epoch1, epoch0 + 1);

    //     // protocol fees for epoch0 should now be forwarded to multisig
    //     uint256 multisigAfter = trustToken.balanceOf(getGeneralConfig().protocolMultisig);
    //     assertEq(multisigAfter, multisigBefore + protoFee0);

    //     // utilization rolled over
    //     int256 util1 = multiVault.getTotalUtilizationForEpoch(epoch1);
    //     assertEq(util1, util0 + int256(extra));

    //     // personal utilization snapshot
    //     int256 personal1 = multiVault.getUserUtilizationForEpoch(address(this), epoch1);
    //     assertEq(personal1, util1);
    // }

    /*──────────────────────────────────────────────────────────────────────────
    12.  deployAtomWallet – negative branches
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_deployAtomWallet_revertIfTermMissing() external {
    //     uint256 fake = 999;
    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermDoesNotExist.selector));
    //     multiVault.deployAtomWallet(fake);
    // }

    // function test_deployAtomWallet_revertIfTermIsTriple() external {
    //     // make triple
    //     (uint256 a,,) = _createBasicAtoms();
    //     uint256 tVal = multiVault.getTripleCost() + 1 ether;
    //     trustToken.approve(address(multiVault), tVal);
    //     uint256 triple = multiVault.createTriple(a, a, a, tVal);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermNotAtom.selector));
    //     multiVault.deployAtomWallet(triple);
    // }

    /*──────────────────────────────────────────────────────────────────────────
    13.  claimAtomWalletDepositFees – wrong caller branch
    ──────────────────────────────────────────────────────────────────────────*/

    function test_claimAtomWalletDepositFees_revertIfNotWallet() external {
        (bytes32 id,,) = _createBasicAtoms();
        // address wallet = multiVault.computeAtomWalletAddr(id);

        // accrue some wallet fees
        uint256 v = multiVault.getAtomCost() + 1 ether;
        trustToken.approve(address(multiVault), v);
        multiVault.deposit(address(this), id, getBondingCurveConfig().defaultCurveId, v, _minAmount(v, defaultSlippage));

        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_OnlyAssociatedAtomWallet.selector));
        multiVault.claimAtomWalletDepositFees(id); // msg.sender is NOT wallet
    }

    /*──────────────────────────────────────────────────────────────────────────
    15.  _claimAccumulatedProtocolFees branch where distribution = true
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_rollover_feeDistributionEnabled_goesToBonding() external {
    //     // enable distribution
    //     vm.prank(admin);
    //     multiVaultConfig.setIsProtocolFeeDistributionEnabled(true);

    //     // create atom & deposit → earn protocol fee for epoch 0
    //     uint256 cost = multiVault.getAtomCost() + 5 ether;
    //     trustToken.approve(address(multiVault), cost);
    //     bytes32 id = multiVault.createAtom("PDF", cost);

    //     uint256 epoch0 = multiVault.currentEpoch();
    //     uint256 protoFee0 = multiVault.accumulatedProtocolFees(epoch0);
    //     assertGt(protoFee0, 0);

    //     // warp to next epoch and trigger rollover + fee transfer to multisig
    //     vm.warp(block.timestamp + trustBonding.epochLength() + 1);
    //     uint256 multisigBalanceBefore = trustToken.balanceOf(getGeneralConfig().protocolMultisig);

    //     trustToken.approve(address(multiVault), 1 ether);
    //     multiVault.deposit(address(this), id, getBondingCurveConfig().defaultCurveId, 1 ether);

    //     // since the switch happened mid-epoch, the protocol fees for epoch 0 are sent to the protocol multisig
    //     uint256 multisigBalanceAfter = trustToken.balanceOf(getGeneralConfig().protocolMultisig);
    //     assertEq(multisigBalanceAfter, multisigBalanceBefore + protoFee0);

    //     uint256 protoFee1 = multiVault.accumulatedProtocolFees(multiVault.currentEpoch());

    //     // warp to next epoch to trigger fee distribution to the TrustBonding contract
    //     vm.warp(block.timestamp + trustBonding.epochLength() + 1);

    //     uint256 trustBondingBalanceBefore = trustToken.balanceOf(address(trustBonding));

    //     // deposit again to trigger rollover and fee claiming
    //     trustToken.approve(address(multiVault), 1 ether);
    //     multiVault.deposit(address(this), id, getBondingCurveConfig().defaultCurveId, 1 ether);

    //     // protocolMultisig balance did not change
    //     assertEq(trustToken.balanceOf(getGeneralConfig().protocolMultisig), multisigBalanceAfter);

    //     // fees are now transferred to the TrustBonding contract, not multisig
    //     assertEq(trustToken.balanceOf(address(trustBonding)), trustBondingBalanceBefore + protoFee1);
    // }

    /*──────────────────────────────────────────────────────────────────────────
    16.  _hasCounterStake helper – TermNotTriple branch
    ──────────────────────────────────────────────────────────────────────────*/

    // function test_hasCounterStake_revertIfTermNotTriple() external {
    //     trustToken.approve(address(multiVault), 1 ether);

    //     uint256 defaultCurveId = getBondingCurveConfig().defaultCurveId;

    //     vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermNotTriple.selector));
    //     multiVault.deposit(address(this), 0, defaultCurveId, 1 ether);
    // }

    /*──────────────────────────────────────────────────────────────────────────
                                internal helper
    ──────────────────────────────────────────────────────────────────────────*/
    function _createBasicAtoms() internal returns (bytes32, bytes32, bytes32) {
        uint256 cost = multiVault.getAtomCost() + 1 ether;
        trustToken.approve(address(multiVault), cost * 3);
        bytes32 a = multiVault.createAtom("X", cost);
        bytes32 b = multiVault.createAtom("Y", cost);
        bytes32 c = multiVault.createAtom("Z", cost);
        return (a, b, c);
    }
}
