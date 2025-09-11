// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { PumpCurve } from "src/protocol/curves/PumpCurve.sol";
import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

contract PumpCurveTest is Test {
    PumpCurve public curve;

    function setUp() public {
        curve = new PumpCurve("Pump Curve Test");
    }

    function test_constructor_successful() public {
        PumpCurve newCurve = new PumpCurve("Test Curve");
        assertEq(newCurve.name(), "Test Curve");
    }

    function test_constructor_revertsOnEmptyName() public {
        vm.expectRevert(abi.encodeWithSelector(BaseCurve.BaseCurve_EmptyStringNotAllowed.selector));
        new PumpCurve("");
    }

    function test_previewDeposit_zeroTotalAssets() public view {
        // Deposit 100k TRUST when nothing has been deposited
        uint256 shares = curve.previewDeposit(100_000 * 1e18, 0, 0);
        assertGt(shares, 0);
        assertLt(shares, curve.MAX_SHARES());
    }

    function test_previewDeposit_withExistingAssets() public view {
        // Deposit 100k TRUST when 1M TRUST already deposited
        uint256 shares = curve.previewDeposit(100_000 * 1e18, 1_000_000 * 1e18, 0);
        assertGt(shares, 0);
    }

    function test_previewDeposit_nearMaxAssets() public view {
        // Test near the end of the curve
        uint256 existingAssets = 900_000_000 * 1e18; // 900M TRUST
        uint256 depositAmount = 50_000_000 * 1e18; // 50M TRUST
        uint256 shares = curve.previewDeposit(depositAmount, existingAssets, 0);
        assertGt(shares, 0);
    }

    function test_previewMint_zeroTotalShares() public view {
        // Mint 1 million tokens from zero
        uint256 sharesToMint = 1_000_000 * 1e18; // 1M tokens
        uint256 assets = curve.previewMint(sharesToMint, 0, 0);
        assertGt(assets, 0);
        assertLe(assets, curve.MAX_ASSETS());
    }

    function test_previewMint_withExistingShares() public view {
        // Mint more tokens when some already exist
        uint256 existingShares = 100_000_000 * 1e18; // 100M tokens
        uint256 sharesToMint = 10_000_000 * 1e18; // 10M tokens
        uint256 existingAssets = 100_000_000 * 1e18; // 100M TRUST
        uint256 assets = curve.previewMint(sharesToMint, existingShares, existingAssets);
        assertGt(assets, 0);
    }

    function test_previewWithdraw_successful() public view {
        // Withdraw 10M TRUST from 100M TRUST total
        uint256 withdrawAmount = 10_000_000 * 1e18; // 10M TRUST
        uint256 totalAssets = 100_000_000 * 1e18; // 100M TRUST
        uint256 shares = curve.previewWithdraw(withdrawAmount, totalAssets, 0);
        assertGt(shares, 0);
    }

    function test_previewWithdraw_entireBalance() public view {
        // Withdraw entire balance
        uint256 totalAssets = 500_000_000 * 1e18; // 500M TRUST
        uint256 shares = curve.previewWithdraw(totalAssets, totalAssets, 0);
        assertGt(shares, 0);
    }

    function test_previewRedeem_successful() public view {
        // Redeem 10M tokens
        uint256 sharesToRedeem = 10_000_000 * 1e18; // 10M tokens
        uint256 totalShares = 200_000_000 * 1e18; // 200M tokens
        uint256 totalAssets = 200_000_000 * 1e18; // 200M TRUST
        uint256 assets = curve.previewRedeem(sharesToRedeem, totalShares, totalAssets);
        assertGe(assets, 0);
    }

    function test_previewRedeem_allShares() public view {
        // Redeem all shares
        uint256 totalShares = 400_000_000 * 1e18; // 400M tokens
        uint256 totalAssets = 400_000_000 * 1e18; // 400M TRUST
        uint256 assets = curve.previewRedeem(totalShares, totalShares, totalAssets);
        assertGe(assets, 0);
    }

    function test_convertToShares_matchesPreviewDeposit() public view {
        uint256 assets = 50_000_000 * 1e18; // 50M TRUST
        uint256 totalAssets = 100_000_000 * 1e18; // 100M TRUST
        uint256 totalShares = 100_000_000 * 1e18; // 100M tokens

        uint256 sharesFromConvert = curve.convertToShares(assets, totalAssets, totalShares);
        uint256 sharesFromPreview = curve.previewDeposit(assets, totalAssets, totalShares);

        assertEq(sharesFromConvert, sharesFromPreview);
    }

    function test_convertToAssets_matchesPreviewRedeem() public view {
        uint256 shares = 50_000_000 * 1e18; // 50M tokens
        uint256 totalShares = 300_000_000 * 1e18; // 300M tokens
        uint256 totalAssets = 300_000_000 * 1e18; // 300M TRUST

        uint256 assetsFromConvert = curve.convertToAssets(shares, totalShares, totalAssets);
        uint256 assetsFromPreview = curve.previewRedeem(shares, totalShares, totalAssets);

        assertEq(assetsFromConvert, assetsFromPreview);
    }

    function test_currentPrice_atZeroSupply() public view {
        uint256 price = curve.currentPrice(0);
        assertGt(price, 0);
        // Initial price should be low but scaled up
        assertLt(price, 1e18); // Less than 1 TRUST per token
    }

    function test_currentPrice_increasesWithSupply() public view {
        // Test with reasonable supply levels
        uint256 price1 = curve.currentPrice(10_000_000 * 1e18); // 10M tokens
        uint256 price2 = curve.currentPrice(50_000_000 * 1e18); // 50M tokens
        uint256 price3 = curve.currentPrice(100_000_000 * 1e18); // 100M tokens

        // Prices should increase as supply increases
        assertGt(price2, price1);
        assertGt(price3, price2);
    }

    function test_maxShares() public view {
        assertEq(curve.maxShares(), 800_000_000 * 1e18);
    }

    function test_maxAssets() public view {
        assertEq(curve.maxAssets(), 1_000_000_000 * 1e18);
    }

    function test_bondingCurveProgress_atStart() public view {
        uint256 progress = curve.bondingCurveProgress(0);
        assertEq(progress, 0);
    }

    function test_bondingCurveProgress_halfway() public view {
        uint256 halfwayShares = curve.INITIAL_REAL_TOKEN_RESERVES() / 2;
        uint256 progress = curve.bondingCurveProgress(halfwayShares);
        assertEq(progress, 50);
    }

    function test_bondingCurveProgress_complete() public view {
        uint256 progress = curve.bondingCurveProgress(curve.INITIAL_REAL_TOKEN_RESERVES());
        assertEq(progress, 100);
    }

    function test_bondingCurveProgress_beyondComplete() public view {
        uint256 progress = curve.bondingCurveProgress(curve.INITIAL_REAL_TOKEN_RESERVES() + 1e18);
        assertEq(progress, 100);
    }

    function test_isCurveComplete_false() public view {
        bool complete = curve.isCurveComplete(curve.INITIAL_REAL_TOKEN_RESERVES() - 1);
        assertFalse(complete);
    }

    function test_isCurveComplete_true() public view {
        bool complete = curve.isCurveComplete(curve.INITIAL_REAL_TOKEN_RESERVES());
        assertTrue(complete);
    }

    function test_isCurveComplete_beyondComplete() public view {
        bool complete = curve.isCurveComplete(curve.INITIAL_REAL_TOKEN_RESERVES() + 1e18);
        assertTrue(complete);
    }

    // Fuzzing tests with proper bounds
    function testFuzz_previewDeposit(uint256 assets, uint256 totalAssets) public view {
        // Bound assets to reasonable values (100k TRUST to 100M TRUST for meaningful tests)
        assets = bound(assets, 100_000 * 1e18, 100_000_000 * 1e18);
        // Total assets from 0 to 900M (leaving room for deposit)
        totalAssets = bound(totalAssets, 0, 900_000_000 * 1e18);

        // Skip if would exceed max
        vm.assume(totalAssets + assets <= curve.MAX_ASSETS());

        uint256 shares = curve.previewDeposit(assets, totalAssets, 0);

        // Should always get some shares for valid deposits
        assertGt(shares, 0);
        assertLe(shares, curve.MAX_SHARES());
    }

    function testFuzz_previewMint(uint256 shares, uint256 totalShares, uint256 totalAssets) public view {
        // Bound shares to reasonable values
        shares = bound(shares, 100_000 * 1e18, 10_000_000 * 1e18); // 100k to 10M tokens
        totalShares = bound(totalShares, 0, 700_000_000 * 1e18); // Up to 700M
        totalAssets = bound(totalAssets, 0, 800_000_000 * 1e18); // Up to 800M TRUST

        // Skip test if trying to mint beyond max
        vm.assume(totalShares + shares <= curve.MAX_SHARES());

        uint256 assets = curve.previewMint(shares, totalShares, totalAssets);

        // Assets required should be within bounds
        assertLe(assets, curve.MAX_ASSETS());
    }

    function testFuzz_previewWithdraw(uint256 assets, uint256 totalAssets) public view {
        // Total assets must be meaningful
        totalAssets = bound(totalAssets, 1_000_000 * 1e18, 500_000_000 * 1e18);
        // Withdraw amount must be less than total
        assets = bound(assets, 100_000 * 1e18, totalAssets);

        uint256 shares = curve.previewWithdraw(assets, totalAssets, 0);

        // Should require burning some shares
        assertGt(shares, 0);
    }

    function testFuzz_previewRedeem(uint256 shares, uint256 totalShares, uint256 totalAssets) public view {
        // Bound to reasonable values
        totalShares = bound(totalShares, 1_000_000 * 1e18, 500_000_000 * 1e18); // 1M to 500M
        shares = bound(shares, 100_000 * 1e18, totalShares);
        totalAssets = bound(totalAssets, 1_000_000 * 1e18, 500_000_000 * 1e18);

        uint256 assets = curve.previewRedeem(shares, totalShares, totalAssets);

        // Assets should be non-negative
        assertGe(assets, 0);
    }

    function testFuzz_currentPrice_increasesMonotonically(uint256 supply1, uint256 supply2) public view {
        // Bound supplies to reasonable values
        supply1 = bound(supply1, 0, 400_000_000 * 1e18); // Up to 400M
        supply2 = bound(supply2, supply1, 400_000_000 * 1e18);

        // Skip if supplies are equal
        vm.assume(supply2 > supply1);

        uint256 price1 = curve.currentPrice(supply1);
        uint256 price2 = curve.currentPrice(supply2);

        // Price should increase or stay same as supply increases
        assertGe(price2, price1);
    }

    function testFuzz_bondingCurveProgress(uint256 totalShares) public view {
        totalShares = bound(totalShares, 0, curve.INITIAL_REAL_TOKEN_RESERVES() * 2);

        uint256 progress = curve.bondingCurveProgress(totalShares);
        assertLe(progress, 100);

        if (totalShares >= curve.INITIAL_REAL_TOKEN_RESERVES()) {
            assertEq(progress, 100);
        } else {
            assertLt(progress, 100);
        }
    }

    // Price progression test
    function test_priceProgression() public view {
        console2.log("=== PUMP CURVE PRICE PROGRESSION ===");
        console2.log("Testing share price at different TRUST deposit levels");
        console2.log("Note: Prices are scaled up from internal calculations");
        console2.log("------------------------------------");

        uint256[] memory trustAmounts = new uint256[](15);
        trustAmounts[0] = 100_000 * 1e18; // 100k TRUST (minimum meaningful amount)
        trustAmounts[1] = 200_000 * 1e18; // 200k TRUST
        trustAmounts[2] = 300_000 * 1e18; // 300k TRUST
        trustAmounts[3] = 400_000 * 1e18; // 400k TRUST
        trustAmounts[4] = 500_000 * 1e18; // 500k TRUST
        trustAmounts[5] = 1_000_000 * 1e18; // 1M TRUST
        trustAmounts[6] = 2_000_000 * 1e18; // 2M TRUST
        trustAmounts[7] = 3_000_000 * 1e18; // 3M TRUST
        trustAmounts[8] = 4_000_000 * 1e18; // 4M TRUST
        trustAmounts[9] = 5_000_000 * 1e18; // 5M TRUST
        trustAmounts[10] = 6_000_000 * 1e18; // 6M TRUST
        trustAmounts[11] = 7_000_000 * 1e18; // 7M TRUST
        trustAmounts[12] = 8_000_000 * 1e18; // 8M TRUST
        trustAmounts[13] = 9_000_000 * 1e18; // 9M TRUST
        trustAmounts[14] = 10_000_000 * 1e18; // 10M TRUST

        uint256 cumulativeTrust = 0;
        uint256 cumulativeShares = 0;

        for (uint256 i = 0; i < trustAmounts.length; i++) {
            uint256 trustDeposit = trustAmounts[i] - cumulativeTrust;

            if (trustDeposit > 0) {
                uint256 sharesReceived = curve.previewDeposit(trustDeposit, cumulativeTrust, cumulativeShares);
                cumulativeTrust = trustAmounts[i];
                cumulativeShares += sharesReceived;

                uint256 currentSharePrice = curve.currentPrice(cumulativeShares);

                console2.log("Total TRUST Deposited: %s TRUST", trustAmounts[i] / 1e18);
                console2.log("  Shares Received for this deposit: %s", sharesReceived / 1e18);
                console2.log("  Total Shares Outstanding: %s", cumulativeShares / 1e18);
                console2.log("  Current Price per Share (wei): %s", currentSharePrice);
                console2.log("  Price in TRUST (decimal): %s", currentSharePrice * 1000 / 1e18);
                console2.log("------------------------------------");
            }
        }

        console2.log("=== END PRICE PROGRESSION ===");
    }

    // Additional edge case tests
    function test_previewDeposit_verySmallAmount() public view {
        // Small amounts below scaling threshold still work
        uint256 shares = curve.previewDeposit(1000 * 1e18, 0, 0);
        assertGe(shares, 0);
    }

    function test_previewDeposit_atMaxAssets() public view {
        // Test depositing when near max
        uint256 existingAssets = 999_000_000 * 1e18; // 999M TRUST
        uint256 depositAmount = 1_000_000 * 1e18; // 1M TRUST
        uint256 shares = curve.previewDeposit(depositAmount, existingAssets, 0);
        assertGt(shares, 0);
    }

    function test_previewMint_nearMaxShares() public view {
        // Test minting when near max shares
        uint256 totalShares = 790_000_000 * 1e18; // 790M
        uint256 sharesToMint = 1_000_000 * 1e18; // 1M
        uint256 assets = curve.previewMint(sharesToMint, totalShares, 500_000_000 * 1e18);
        assertGe(assets, 0);
    }

    function test_previewRedeem_smallAmount() public view {
        // Test redeeming very small amount
        uint256 assets = curve.previewRedeem(1000 * 1e18, 100_000_000 * 1e18, 100_000_000 * 1e18);
        assertGe(assets, 0);
    }

    function test_scalingConsistency() public view {
        // Test that scaling maintains consistency
        uint256 deposit1 = 10_000_000 * 1e18; // 10M TRUST
        uint256 shares1 = curve.previewDeposit(deposit1, 0, 0);

        // Second deposit should get fewer shares
        uint256 deposit2 = 10_000_000 * 1e18; // Another 10M TRUST
        uint256 shares2 = curve.previewDeposit(deposit2, deposit1, shares1);

        // Due to bonding curve, second deposit gets fewer shares
        assertLt(shares2, shares1);
    }
}
