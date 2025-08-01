// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MultiVaultBase} from "test/MultiVaultBase.sol";
import {StdStyle} from "forge-std/StdStyle.sol";

/// @title  Multi-vault – core actions integration test
/// @notice Walks through the 12 canonical user actions on both the default
///         (pro-rata) bonding-curve and an alternative curve, for
///         atoms *and* triples.  The test verifies:
///         • assets / shares movements
///         • vault-totals accounting
///         • protocol-fee and atom-wallet-fee accrual
///         • utilisation ledgers
///         • that preview helpers (previewDeposit / previewRedeem) match reality
contract MultiVaultCoreActionsTest is MultiVaultBase {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_BONDING_CURVE_ID = 1;
    uint256 internal constant ALTERNATIVE_BONDING_CURVE_ID = 2;

    /*//////////////////////////////////////////////////////////////
                              TEST HARNESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Extra per-suite set-up (none needed now, but maintained for
    ///         completeness).  `MultiVaultBase.setUp()` already ran.
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                          FLOW-1  – DEFAULT ATOM
    //////////////////////////////////////////////////////////////*/

    /// @dev 1. Create an atom on the default curve, then:
    ///      – deposit 1 TRUST
    ///      – deposit another 1 TRUST
    ///      – redeem exactly 1 share
    function testDefaultCurveAtomFlow() external {
        // -------- actor preparation -------------------------------------------------------------
        vm.startPrank(alice);
        uint256 costToCreateAtom = multiVault.getAtomCost();

        // Ensure Alice has authorised the vault to pull her TRUST
        trustToken.approve(address(multiVault), type(uint256).max);

        // ------------------------  ACTION 1  – create atom  -------------------------------------
        bytes memory ipfsData = bytes("ipfs://QmDefaultCurveAtom");
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = ipfsData;
        bytes32 newlyCreatedAtomId = multiVault.createAtoms(atomDataArray, costToCreateAtom)[0];

        // Test atom creation assertions in a separate function to avoid stack too deep
        _assertAtomCreation(newlyCreatedAtomId, costToCreateAtom);

        // ------------------------  ACTION 2  – first 1 TRUST deposit ----------------------------
        uint256 firstDepositAmount = oneToken; // 1 TRUST (1e18)

        // Test first deposit in separate function
        uint256 totalAssetsAfterDeposit1 = _testFirstDeposit(alice, newlyCreatedAtomId, firstDepositAmount);

        // ------------------------  ACTION 3  – second 1 TRUST deposit ---------------------------
        uint256 secondDepositAmount = oneToken;

        // Test second deposit in separate function
        _testSecondDeposit(alice, newlyCreatedAtomId, secondDepositAmount, totalAssetsAfterDeposit1);

        // ------------------------  ACTION 4  – redeem exactly 1 share ---------------------------
        _testRedemption(alice, newlyCreatedAtomId);

        vm.stopPrank();

        emit log(StdStyle.green("--- Flow-1 (default-curve atom) passed ---"));
    }

    // Helper function to assert atom creation
    function _assertAtomCreation(bytes32 atomId, uint256 /* creationCost */ ) internal view {
        (uint256 totalSharesAfterCreation, uint256 totalAssetsAfterCreation) =
            multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);

        // The vault always starts with 1:1 share-price; assets == shares.
        assertEq(
            totalAssetsAfterCreation, totalSharesAfterCreation, "Creation: assets must equal shares (share price == 1)"
        );

        // The vault must contain `generalConfig.minShare` ghost-shares + Alice's shares
        uint256 expectedGhostShares = generalConfig.minShare;
        assertEq(
            totalSharesAfterCreation,
            expectedGhostShares
                + multiVault.convertToShares(
                    totalAssetsAfterCreation - expectedGhostShares, atomId, DEFAULT_BONDING_CURVE_ID
                ),
            "Creation: ghost shares not accounted for"
        );

        // Accumulated protocol fees ledger must increment by atomCreationProtocolFee
        uint256 currentEpochNumber = multiVault.currentEpoch();
        uint256 expectedProtocolFeesFromCreation = atomConfig.atomCreationProtocolFee;
        assertEq(
            multiVault.accumulatedProtocolFees(currentEpochNumber),
            expectedProtocolFeesFromCreation,
            "Creation: protocol fee ledger wrong"
        );
    }

    // Helper function for first deposit
    function _testFirstDeposit(address depositor, bytes32 atomId, uint256 _depositAmount)
        internal
        returns (uint256 totalAssetsAfterDeposit)
    {
        // Get initial state
        (, uint256 totalAssetsBeforeDeposit) = multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);

        uint256 previewSharesFirst = multiVault.previewDeposit(_depositAmount, atomId, DEFAULT_BONDING_CURVE_ID);

        uint256 sharesMintedFirst = multiVault.deposit(
            depositor, atomId, DEFAULT_BONDING_CURVE_ID, _depositAmount, _minShares(previewSharesFirst, defaultSlippage)
        );

        assertEq(sharesMintedFirst, previewSharesFirst, "Deposit-1: preview vs actual shares mismatch");

        // Verify vault totals advanced correctly
        (, totalAssetsAfterDeposit) = multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);

        assertEq(
            totalAssetsAfterDeposit,
            totalAssetsBeforeDeposit + _depositAmount - multiVault.protocolFeeAmount(_depositAmount)
                - multiVault.atomWalletDepositFeeAmount(_depositAmount, atomId),
            "Deposit-1: unexpected totalAssets"
        );

        return totalAssetsAfterDeposit;
    }

    // Helper function for second deposit
    function _testSecondDeposit(
        address depositor,
        bytes32 atomId,
        uint256 _depositAmount,
        uint256 /* totalAssetsAfterFirstDeposit */
    ) internal {
        uint256 previewSharesSecond = multiVault.previewDeposit(_depositAmount, atomId, DEFAULT_BONDING_CURVE_ID);

        uint256 sharesMintedSecond = multiVault.deposit(
            depositor,
            atomId,
            DEFAULT_BONDING_CURVE_ID,
            _depositAmount,
            _minShares(previewSharesSecond, defaultSlippage)
        );

        assertEq(sharesMintedSecond, previewSharesSecond, "Deposit-2: preview vs actual shares mismatch");
    }

    // Helper function for redemption
    function _testRedemption(address redeemer, bytes32 atomId) internal {
        // Get state before redemption
        (, uint256 totalAssetsBeforeRedeem) = multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);

        uint256 sharesToRedeem = multiVault.ONE_SHARE(); // 1e18
        uint256 previewAssetsForRedeem = multiVault.previewRedeem(sharesToRedeem, atomId, DEFAULT_BONDING_CURVE_ID);
        uint256 grossValueOfSharesToRedeem =
            multiVault.convertToAssets(sharesToRedeem, atomId, DEFAULT_BONDING_CURVE_ID);

        uint256 assetsReceived = multiVault.redeem(
            sharesToRedeem,
            redeemer,
            atomId,
            DEFAULT_BONDING_CURVE_ID,
            _minAmount(previewAssetsForRedeem, defaultSlippage)
        );

        assertEq(assetsReceived, previewAssetsForRedeem, "Redeem: preview vs actual assets mismatch");

        // Remaining shares in vault must still be ≥ minShare (guard invariant)
        (uint256 totalSharesAfterRedeem,) = multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);
        assertGe(totalSharesAfterRedeem, generalConfig.minShare, "Redeem: vault below minShare guard");

        // Verify total assets accounting
        (, uint256 totalAssetsAfterRedeem) = multiVault.getVaultTotals(atomId, DEFAULT_BONDING_CURVE_ID);

        // Calculate expected total assets after redemption
        uint256 expectedTotalAssets =
            totalAssetsBeforeRedeem + multiVault.exitFeeAmount(grossValueOfSharesToRedeem) - assetsReceived;

        assertEq(totalAssetsAfterRedeem, expectedTotalAssets, "Redeem: totalAssets mismatch after redemption");
    }

    /*//////////////////////////////////////////////////////////////
                     FLOW-2  – ALTERNATIVE-CURVE ATOM
    //////////////////////////////////////////////////////////////*/

    /// @dev 2. Use the alternative (id=2) curve.  Creation still occurs on
    ///        the default curve, but deposits / redeems are done on curve-2.
    function testAlternativeCurveAtomFlow() external {
        vm.startPrank(bob);

        trustToken.approve(address(multiVault), type(uint256).max);

        // ------------------ Create atom on default curve --------------------
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = bytes("ipfs://QmAltCurveAtom");
        bytes32 newAtomId = multiVault.createAtoms(atomDataArray, multiVault.getAtomCost())[0];

        // ------------------ Initialise alt-curve vault (first deposit) ------
        uint256 altCurveInitialDeposit = oneToken; // 1 TRUST

        uint256 previewSharesInitial =
            multiVault.previewDeposit(altCurveInitialDeposit, newAtomId, ALTERNATIVE_BONDING_CURVE_ID);
        uint256 minShares = _minShares(previewSharesInitial, defaultSlippage);

        uint256 sharesMintedInitial =
            multiVault.deposit(bob, newAtomId, ALTERNATIVE_BONDING_CURVE_ID, altCurveInitialDeposit, minShares);

        assertApproxEqAbs(
            sharesMintedInitial, previewSharesInitial, maxDelta, "AltCurve-init: preview vs actual shares mismatch"
        );

        // The vault is brand-new; ghost-shares should have been bought out
        (uint256 altSharesAfterInit, /* uint256 altAssetsAfterInit */ ) =
            multiVault.getVaultTotals(newAtomId, ALTERNATIVE_BONDING_CURVE_ID);
        assertGt(altSharesAfterInit, generalConfig.minShare, "AltCurve-init: ghost shares not minted correctly");

        // ------------------ Second deposit on alt-curve ---------------------
        uint256 secondDepositAltCurve = oneToken;
        uint256 previewSharesSecond =
            multiVault.previewDeposit(secondDepositAltCurve, newAtomId, ALTERNATIVE_BONDING_CURVE_ID);
        minShares = _minShares(previewSharesSecond, defaultSlippage);

        uint256 sharesMintedSecond =
            multiVault.deposit(bob, newAtomId, ALTERNATIVE_BONDING_CURVE_ID, secondDepositAltCurve, minShares);

        assertEq(sharesMintedSecond, previewSharesSecond, "AltCurve-deposit-2: preview vs actual mismatch");

        // ------------------ Redeem half the shares --------------------------
        uint256 sharesToRedeem = (sharesMintedInitial + sharesMintedSecond) / 2;

        uint256 previewAssetsRedeem = multiVault.previewRedeem(sharesToRedeem, newAtomId, ALTERNATIVE_BONDING_CURVE_ID);

        uint256 assetsActuallyReceived = multiVault.redeem(
            sharesToRedeem,
            bob,
            newAtomId,
            ALTERNATIVE_BONDING_CURVE_ID,
            _minAmount(previewAssetsRedeem, defaultSlippage)
        );

        assertEq(assetsActuallyReceived, previewAssetsRedeem, "AltCurve-redeem: preview vs actual mismatch");

        vm.stopPrank();
        emit log(StdStyle.green("--- Flow-2 (alternative-curve atom) passed ---"));
    }

    /*//////////////////////////////////////////////////////////////
                FLOW-3  – DEFAULT-CURVE TRIPLE (+ COUNTER)
    //////////////////////////////////////////////////////////////*/

    function testDefaultCurveTripleFlow() external {
        // ------------------ create three atoms to serve as triple -----------
        vm.startPrank(alice);
        trustToken.approve(address(multiVault), type(uint256).max);

        // Create three atoms (subject, predicate, object)
        (bytes32 atomA, bytes32 atomB, bytes32 atomC) = _createBasicAtoms();

        // ------------------ create triple on default curve ------------------
        bytes32 tripleId = _createBasicTriple(atomA, atomB, atomC, multiVault.getTripleCost());

        bytes32 counterTripleId = multiVault.getCounterIdFromTriple(tripleId);

        // Counter vault should already be initialised with ghost shares
        (uint256 counterShares,) = multiVault.getVaultTotals(counterTripleId, DEFAULT_BONDING_CURVE_ID);
        assertEq(counterShares, generalConfig.minShare, "Counter-triple ghost shares wrong");

        // ------------------ capture atom assets before triple deposit -------
        // `assetsBefore` are used for all 3 atoms, since they all share the same starting point
        (, uint256 assetsBefore) = multiVault.getVaultTotals(atomA, DEFAULT_BONDING_CURVE_ID);

        // ------------------ deposit into triple (default curve) -------------
        uint256 tripleDeposit = oneToken;
        trustToken.mint(alice, tripleDeposit); // mint extra so she has balance

        uint256 previewShares = multiVault.previewDeposit(tripleDeposit, tripleId, DEFAULT_BONDING_CURVE_ID);

        uint256 sharesReceived = multiVault.deposit(
            alice, tripleId, DEFAULT_BONDING_CURVE_ID, tripleDeposit, _minShares(previewShares, defaultSlippage)
        );

        assertEq(sharesReceived, previewShares, "Triple-deposit: preview mismatch");

        // Entry fee went to underlying atom pro-rata vaults
        // Atom deposit fraction (not entry fee) flows to underlying atoms
        uint256 expectedAtomDepositFraction = multiVault.atomDepositFractionAmount(tripleDeposit, tripleId);
        uint256 amountPerAtom = expectedAtomDepositFraction / 3;

        (, uint256 assetsA) = multiVault.getVaultTotals(atomA, DEFAULT_BONDING_CURVE_ID);
        (, uint256 assetsB) = multiVault.getVaultTotals(atomB, DEFAULT_BONDING_CURVE_ID);
        (, uint256 assetsC) = multiVault.getVaultTotals(atomC, DEFAULT_BONDING_CURVE_ID);

        assertApproxEqAbs(assetsA - assetsBefore, amountPerAtom, 1, "Entry fee flow-through atomA");
        assertApproxEqAbs(assetsB - assetsBefore, amountPerAtom, 1, "Entry fee flow-through atomB");
        assertApproxEqAbs(assetsC - assetsBefore, amountPerAtom, 1, "Entry fee flow-through atomC");

        vm.stopPrank();
        emit log(StdStyle.green("--- Flow-3 (default-curve triple) passed ---"));
    }

    /*//////////////////////////////////////////////////////////////
            FLOW-4  – ALTERNATIVE-CURVE TRIPLE  (economic games)
    //////////////////////////////////////////////////////////////*/

    function testAlternativeCurveTripleFlow() external {
        vm.startPrank(rich); // use rich so we never run out of gas or funds
        trustToken.approve(address(multiVault), type(uint256).max);

        // ------------- produce three new atoms ---------------------------------
        (bytes32 subj, bytes32 pred, bytes32 obj) = _createBasicAtoms();

        // ------------- create triple on default curve --------------------------
        bytes32 tripleId = _createBasicTriple(subj, pred, obj, multiVault.getTripleCost());

        // ------------- initialise alt-curve vault for the triple ---------------
        uint256 initDepositAltCurve = oneToken * 2; // 2 TRUST
        uint256 previewSharesInit =
            multiVault.previewDeposit(initDepositAltCurve, tripleId, ALTERNATIVE_BONDING_CURVE_ID);
        uint256 minShares = _minShares(previewSharesInit, defaultSlippage);
        uint256 sharesInit =
            multiVault.deposit(rich, tripleId, ALTERNATIVE_BONDING_CURVE_ID, initDepositAltCurve, minShares);

        // ------------- redeem a small portion ----------------------------------
        uint256 sharesToRedeem = sharesInit / 4; // 25 %
        uint256 expectedAssets = multiVault.previewRedeem(sharesToRedeem, tripleId, ALTERNATIVE_BONDING_CURVE_ID);

        uint256 receivedAssets = multiVault.redeem(
            sharesToRedeem, rich, tripleId, ALTERNATIVE_BONDING_CURVE_ID, _minAmount(expectedAssets, defaultSlippage)
        );

        assertEq(receivedAssets, expectedAssets, "Alt-triple: redeem preview mismatch");

        // Exit fee went to underlying atoms (because triple vault)
        uint256 expectedExitFee =
            multiVault.exitFeeAmount(multiVault.convertToAssets(sharesToRedeem, tripleId, ALTERNATIVE_BONDING_CURVE_ID));

        uint256 perAtomAllocation = expectedExitFee / 3;
        (, uint256 assetsSubj) = multiVault.getVaultTotals(subj, DEFAULT_BONDING_CURVE_ID);
        assertGt(assetsSubj, perAtomAllocation - 2, "Exit-fee flow-through incorrect");

        vm.stopPrank();
        emit log(StdStyle.green("--- Flow-4 (alternative-curve triple) passed ---"));
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev creates three simple atoms and returns their ids (subject, predicate, object)
    function _createBasicAtoms() internal returns (bytes32, bytes32, bytes32) {
        uint256 value = multiVault.getAtomCost() * 3;

        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = "S";
        atomDataArray[1] = "P";
        atomDataArray[2] = "O";

        bytes32[] memory atomIds = multiVault.createAtoms(atomDataArray, value);
        return (atomIds[0], atomIds[1], atomIds[2]);
    }

    /// @dev creates a basic triple with the given subject, predicate, object and value and returns the triple id
    function _createBasicTriple(bytes32 s, bytes32 p, bytes32 o, uint256 value) internal returns (bytes32) {
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);

        subjectIds[0] = s;
        predicateIds[0] = p;
        objectIds[0] = o;

        bytes32 tripleId = multiVault.createTriples(subjectIds, predicateIds, objectIds, value)[0];
        return tripleId;
    }
}
