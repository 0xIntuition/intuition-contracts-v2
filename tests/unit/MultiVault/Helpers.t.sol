// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { BaseTest } from "tests/BaseTest.t.sol";
import { IPermit2 } from "src/interfaces/IPermit2.sol";
import { WalletConfig } from "src/interfaces/IMultiVaultCore.sol";

contract MultiVaultHelpersTest is BaseTest {
    /*////////////////////////////////////////////////////////////////////
                                INTERNAL HELPERS
    ////////////////////////////////////////////////////////////////////*/

    function _ceilMulDiv(uint256 a, uint256 b, uint256 denom) internal pure returns (uint256) {
        // ceil(a*b/denom)
        if (a == 0 || b == 0) return 0;
        unchecked {
            uint256 prod = a * b;
            return (prod + denom - 1) / denom;
        }
    }

    /*////////////////////////////////////////////////////////////////////
                            Fee Helpers: unit & fuzz
    ////////////////////////////////////////////////////////////////////*/

    function test_protocolFeeAmount_ZeroAndNonZero() public view {
        (,, uint256 protocolFeeBps) = protocol.multiVault.vaultFees();
        uint256 denom = FEE_DENOMINATOR;

        // zero
        assertEq(protocol.multiVault.protocolFeeAmount(0), 0);

        // non-even divisor to exercise rounding up (e.g., 101 * 100 / 10000 => ceil = 2)
        uint256 assets = 101;
        uint256 expected = _ceilMulDiv(assets, protocolFeeBps, denom);
        assertEq(protocol.multiVault.protocolFeeAmount(assets), expected);
    }

    function test_entryFeeAmount_ZeroAndNonZero() public view {
        (uint256 entryFeeBps,,) = protocol.multiVault.vaultFees();
        uint256 denom = FEE_DENOMINATOR;

        assertEq(protocol.multiVault.entryFeeAmount(0), 0);

        uint256 assets = 123_456_789; // arbitrary, non-multiple of denom
        uint256 expected = _ceilMulDiv(assets, entryFeeBps, denom);
        assertEq(protocol.multiVault.entryFeeAmount(assets), expected);
    }

    function test_exitFeeAmount_ZeroAndNonZero() public view {
        (, uint256 exitFeeBps,) = protocol.multiVault.vaultFees();
        uint256 denom = FEE_DENOMINATOR;

        assertEq(protocol.multiVault.exitFeeAmount(0), 0);

        uint256 assets = 7_777_777;
        uint256 expected = _ceilMulDiv(assets, exitFeeBps, denom);
        assertEq(protocol.multiVault.exitFeeAmount(assets), expected);
    }

    function test_atomDepositFractionAmount_ZeroAndNonZero() public view {
        (,, uint256 atomFracBps) = protocol.multiVault.tripleConfig();
        uint256 denom = FEE_DENOMINATOR;

        assertEq(protocol.multiVault.atomDepositFractionAmount(0), 0);

        uint256 assets = 999_999_999_999;
        uint256 expected = _ceilMulDiv(assets, atomFracBps, denom);
        assertEq(protocol.multiVault.atomDepositFractionAmount(assets), expected);
    }

    function testFuzz_feeHelpers(uint256 assets) public view {
        // bound assets to something big but not to overflow in our helper (mul fits in 256 anyway)
        assets = bound(assets, 0, type(uint128).max);

        (uint256 entryBps, uint256 exitBps, uint256 protBps) = protocol.multiVault.vaultFees();
        (,, uint256 atomFracBps) = protocol.multiVault.tripleConfig();

        uint256 denom = FEE_DENOMINATOR;

        assertEq(protocol.multiVault.protocolFeeAmount(assets), _ceilMulDiv(assets, protBps, denom));
        assertEq(protocol.multiVault.entryFeeAmount(assets), _ceilMulDiv(assets, entryBps, denom));
        assertEq(protocol.multiVault.exitFeeAmount(assets), _ceilMulDiv(assets, exitBps, denom));
        assertEq(protocol.multiVault.atomDepositFractionAmount(assets), _ceilMulDiv(assets, atomFracBps, denom));
    }

    /*////////////////////////////////////////////////////////////////////
                              getAtomWarden
    ////////////////////////////////////////////////////////////////////*/

    function test_getAtomWarden_DefaultAndAfterUpdate() public {
        // default from BaseTest wallet config is zero
        assertEq(protocol.multiVault.getAtomWarden(), address(0));

        // update via admin and verify
        resetPrank({ msgSender: users.admin });
        (, address entryPoint,, address beacon, address factory) = protocol.multiVault.walletConfig();
        protocol.multiVault.setWalletConfig(
            // set only the fields we change/keep; keep factory same as in deployment
            WalletConfig({
                permit2: IPermit2(address(0)),
                entryPoint: entryPoint,
                atomWarden: address(0xAbCd),
                atomWalletBeacon: beacon,
                atomWalletFactory: factory
            })
        );

        assertEq(protocol.multiVault.getAtomWarden(), address(0xAbCd));
    }

    /*////////////////////////////////////////////////////////////////////
                               currentEpoch
    ////////////////////////////////////////////////////////////////////*/

    function test_currentEpoch_matchesTrustBonding_andWarps() public {
        uint256 mvEpoch = protocol.multiVault.currentEpoch();
        uint256 tbEpoch = protocol.trustBonding.currentEpoch();
        assertEq(mvEpoch, tbEpoch);

        // warp past one epoch and verify both reflect the change
        uint256 epochLen = protocol.trustBonding.epochLength();
        vm.warp(block.timestamp + epochLen + 1);

        uint256 mvEpoch2 = protocol.multiVault.currentEpoch();
        uint256 tbEpoch2 = protocol.trustBonding.currentEpoch();
        assertEq(mvEpoch2, tbEpoch2);
        assertGt(mvEpoch2, mvEpoch);
    }

    /*////////////////////////////////////////////////////////////////////
                              currentSharePrice
    ////////////////////////////////////////////////////////////////////*/

    function test_currentSharePrice_equalsConvertToAssets1Share() public {
        // create a real atom so the vault exists with non-zero totals
        bytes32 atomId = createSimpleAtom("price-atom", getAtomCreationCost(), users.admin);
        uint256 curveId = getDefaultCurveId();

        uint256 oneShareAssets = protocol.multiVault.convertToAssets(atomId, curveId, protocol.multiVault.ONE_SHARE());
        uint256 reported = protocol.multiVault.currentSharePrice(atomId, curveId);

        assertEq(reported, oneShareAssets);
    }

    /*////////////////////////////////////////////////////////////////////
                         previewAtomCreate / previewTripleCreate
    ////////////////////////////////////////////////////////////////////*/

    function test_previewAtomCreate_calculatesFeesAndShares() public {
        // Use a pre-atom id (not created) to keep vault state at zero during preview
        bytes memory data = abi.encodePacked("pre-atom");
        bytes32 preAtomId = calculateAtomId(data);
        uint256 curveId = getDefaultCurveId();

        uint256 atomCost = getAtomCreationCost();
        uint256 assets = atomCost + 5 ether;

        (uint256 shares, uint256 assetsAfterFixed, uint256 assetsAfterFees) =
            protocol.multiVault.previewAtomCreate(preAtomId, curveId, assets);

        // sanity: assetsAfterFixed = assets - atomCost
        assertEq(assetsAfterFixed, assets - atomCost);

        // shares should equal convertToShares(termId, curveId, assetsAfterFees) on empty vault
        uint256 sharesFromView = protocol.multiVault.convertToShares(preAtomId, curveId, assetsAfterFees);
        assertEq(shares, sharesFromView);
    }

    function test_previewTripleCreate_calculatesFeesAndShares() public {
        // Compute an id that isn't created yet: hash of three atoms (we don't need real atoms for preview)
        bytes32 preTripleId = keccak256(abi.encodePacked("s", "p", "o", "triple"));
        uint256 curveId = getDefaultCurveId();

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        uint256 assets = tripleCost + 7 ether;

        (uint256 shares, uint256 assetsAfterFixed, uint256 assetsAfterFees) =
            protocol.multiVault.previewTripleCreate(preTripleId, curveId, assets);

        assertEq(assetsAfterFixed, assets - tripleCost);

        uint256 sharesFromView = protocol.multiVault.convertToShares(preTripleId, curveId, assetsAfterFees);
        assertEq(shares, sharesFromView);
    }

    /*////////////////////////////////////////////////////////////////////
                                previewDeposit
    ////////////////////////////////////////////////////////////////////*/

    function test_previewDeposit_atom_defaultCurve_existingVault() public {
        // create an atom on default curve (vault is initialized)
        bytes32 atomId = createSimpleAtom("pd-atom", getAtomCreationCost(), users.alice);
        uint256 curveId = getDefaultCurveId();

        uint256 gross = 3 ether;
        (uint256 shares, uint256 netAssets) = protocol.multiVault.previewDeposit(atomId, curveId, gross);

        // internal consistency: shares should be convertToShares(termId, curveId, netAssets)
        uint256 shares2 = protocol.multiVault.convertToShares(atomId, curveId, netAssets);
        assertEq(shares, shares2);
        assertGt(shares, 0);
        assertGt(netAssets, 0);
    }

    function test_previewDeposit_atom_nonDefaultCurve_newVault_subtractsMinShare() public {
        // create an atom (only default curve is initialized)
        bytes32 atomId = createSimpleAtom("pd-atom2", getAtomCreationCost(), users.bob);
        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1; // we have 1 and 2 registered in BaseTest

        uint256 minShareCost = protocol.multiVault.getGeneralConfig().minShare;
        uint256 gross = minShareCost + 2 ether;

        (, uint256 netAssets) = protocol.multiVault.previewDeposit(atomId, nonDefaultCurve, gross);

        // Protocol fee + (entry fee waived for new) + atom wallet fee are taken from base = gross - minShare
        // We cannot reconstruct exact net here without fees, but we can assert base decreased by at least minShare:
        assertLt(netAssets, gross); // some fees are taken
        assertGe(gross - netAssets, minShareCost); // at least minShare difference + fees
    }

    function test_previewDeposit_triple_nonDefaultCurve_newVault_subtracts2xMinShare() public {
        // create triple properly so it exists (default curve initialized)
        (bytes32 tripleId,) = createTripleWithAtoms(
            "s", "p", "o", getAtomCreationCost(), protocol.multiVault.getTripleCost(), users.admin
        );
        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        uint256 gross = (minShare * 2) + 3 ether;

        (, uint256 netAssets) = protocol.multiVault.previewDeposit(tripleId, nonDefaultCurve, gross);

        assertLt(netAssets, gross);
        assertGe(gross - netAssets, minShare * 2); // at least 2*minShare difference + fees
    }

    /*////////////////////////////////////////////////////////////////////
                               previewRedeem
    ////////////////////////////////////////////////////////////////////*/

    function test_previewRedeem_atom_returnsNetAssetsAndSharesEcho() public {
        // create and then deposit to get some extra shares
        bytes32 atomId = createSimpleAtom("pr-atom", getAtomCreationCost(), users.alice);
        uint256 curveId = getDefaultCurveId();

        // deposit a bit so redeeming is meaningful
        uint256 amount = 2 ether;
        uint256 minShares = 0;
        makeDeposit(users.alice, users.alice, atomId, curveId, amount, minShares);

        // take a small slice of user's shares
        uint256 userBal = protocol.multiVault.getShares(users.alice, atomId, curveId);
        uint256 sharesToRedeem = userBal / 4;

        (uint256 netAssets, uint256 sharesEcho) = protocol.multiVault.previewRedeem(atomId, curveId, sharesToRedeem);

        assertEq(sharesEcho, sharesToRedeem);
        assertGt(netAssets, 0);
    }

    function test_previewRedeem_triple_returnsNetAssetsAndSharesEcho() public {
        (bytes32 tripleId,) = createTripleWithAtoms(
            "s2", "p2", "o2", getAtomCreationCost(), protocol.multiVault.getTripleCost(), users.bob
        );
        uint256 curveId = getDefaultCurveId();

        // extra deposit into triple
        makeDeposit(users.bob, users.bob, tripleId, curveId, 2 ether, 0);

        uint256 userBal = protocol.multiVault.getShares(users.bob, tripleId, curveId);
        uint256 sharesToRedeem = userBal / 3;

        (uint256 netAssets, uint256 sharesEcho) = protocol.multiVault.previewRedeem(tripleId, curveId, sharesToRedeem);

        assertEq(sharesEcho, sharesToRedeem);
        assertGt(netAssets, 0);
    }

    /*////////////////////////////////////////////////////////////////////
                         convertToShares / convertToAssets
    ////////////////////////////////////////////////////////////////////*/

    function test_convertToSharesAndBack_basicConsistency_atom() public {
        bytes32 atomId = createSimpleAtom("c2s-atom", getAtomCreationCost(), users.charlie);
        uint256 curveId = getDefaultCurveId();

        // use a small assets amount to avoid large state shifts in implicit reasoning
        uint256 assets = 1 ether;
        uint256 shares = protocol.multiVault.convertToShares(atomId, curveId, assets);
        // Converting back at current state should be close; we assert monotonic: non-zero roundtrip
        uint256 assetsBack = protocol.multiVault.convertToAssets(atomId, curveId, shares);

        assertGt(shares, 0);
        assertGt(assetsBack, 0);
    }

    function test_convertToSharesAndBack_basicConsistency_triple() public {
        (bytes32 tripleId,) = createTripleWithAtoms(
            "sx", "px", "ox", getAtomCreationCost(), protocol.multiVault.getTripleCost(), users.admin
        );
        uint256 curveId = getDefaultCurveId();

        uint256 assets = 1 ether;
        uint256 shares = protocol.multiVault.convertToShares(tripleId, curveId, assets);
        uint256 assetsBack = protocol.multiVault.convertToAssets(tripleId, curveId, shares);

        assertGt(shares, 0);
        assertGt(assetsBack, 0);
    }

    /*////////////////////////////////////////////////////////////////////
                                  maxRedeem
    ////////////////////////////////////////////////////////////////////*/

    function test_maxRedeem_matchesUserBalance() public {
        bytes32 atomId = createSimpleAtom("mr-atom", getAtomCreationCost(), users.alice);
        uint256 curveId = getDefaultCurveId();

        // extra deposit to alice
        uint256 minted = makeDeposit(users.alice, users.alice, atomId, curveId, 2 ether, 0);

        uint256 bal = protocol.multiVault.getShares(users.alice, atomId, curveId);
        uint256 mr = protocol.multiVault.maxRedeem(users.alice, atomId, curveId);

        assertEq(bal, mr);
        assertGe(bal, minted); // minted might be less than total (includes initial create)
    }
}
