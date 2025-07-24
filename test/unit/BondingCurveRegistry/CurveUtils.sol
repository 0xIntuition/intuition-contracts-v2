// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StringUtils} from "test/unit/BondingCurveRegistry/StringUtils.sol";

/**
 * @title  CurveUtils
 * @author 0xIntuition
 * @notice Utility functions for testing bonding curves
 */
library CurveUtils {
    using StringUtils for uint256;

    struct CurveTestResult {
        uint256 totalAssetsDeposited;
        uint256 totalSharesMinted;
        uint256 totalAssetsWithdrawn;
        uint256 totalSharesBurned;
        uint256 assetDiscrepancy;
        uint256 discrepancyPercentage;
    }

    /// @notice Test a curve by performing multiple deposits and withdrawals
    /// @param curve The curve to test
    /// @param assetsPerDeposit Amount of assets to deposit in each transaction
    /// @param numActions Number of deposit/withdraw actions to perform
    /// @param errorMargin Maximum allowed discrepancy in basis points (1 = 0.01%)
    /// @param description Description of the test for logging
    /// @return result The test results including discrepancy calculations
    function testCurveActions(
        address curve,
        uint256 assetsPerDeposit,
        uint256 numActions,
        uint256 errorMargin,
        string memory description
    ) internal returns (CurveTestResult memory result) {
        console.log("=== Testing %s ===", description);
        console.log("Assets per deposit: %s", assetsPerDeposit.toString());
        console.log("Number of actions: %d", numActions);

        // Track economic state
        uint256 totalAssetsInCurve = 0;
        uint256 totalSharesInCurve = 0;

        // Deposit phase
        for (uint256 i = 0; i < numActions; i++) {
            (bool success, bytes memory data) = curve.call(
                abi.encodeWithSignature(
                    "previewDeposit(uint256,uint256,uint256)", assetsPerDeposit, totalAssetsInCurve, totalSharesInCurve
                )
            );
            require(success, "previewDeposit failed");
            uint256 sharesToMint = abi.decode(data, (uint256));

            totalAssetsInCurve += assetsPerDeposit;
            totalSharesInCurve += sharesToMint;
            result.totalAssetsDeposited += assetsPerDeposit;
            result.totalSharesMinted += sharesToMint;

            if (numActions > 1) {
                console.log(
                    "Deposit %d: %s assets -> %s shares", i + 1, assetsPerDeposit.toString(), sharesToMint.toString()
                );
            }
        }

        console.log(
            "Total after %d deposits: %s assets, %s shares",
            numActions,
            totalAssetsInCurve.toString(),
            totalSharesInCurve.toString()
        );

        // Withdraw phase
        uint256 sharesPerWithdraw = totalSharesInCurve / numActions;
        for (uint256 i = 0; i < numActions; i++) {
            (bool success, bytes memory data) = curve.call(
                abi.encodeWithSignature(
                    "previewRedeem(uint256,uint256,uint256)", sharesPerWithdraw, totalSharesInCurve, totalAssetsInCurve
                )
            );
            require(success, "previewRedeem failed");
            uint256 assetsToWithdraw = abi.decode(data, (uint256));

            totalAssetsInCurve -= assetsToWithdraw;
            totalSharesInCurve -= sharesPerWithdraw;
            result.totalAssetsWithdrawn += assetsToWithdraw;
            result.totalSharesBurned += sharesPerWithdraw;

            if (numActions > 1) {
                console.log(
                    "Withdraw %d: %s shares -> %s assets",
                    i + 1,
                    sharesPerWithdraw.toString(),
                    assetsToWithdraw.toString()
                );
            }
        }

        // Handle any remaining shares due to rounding
        if (totalSharesInCurve > 0) {
            (bool success, bytes memory data) = curve.call(
                abi.encodeWithSignature(
                    "previewRedeem(uint256,uint256,uint256)", totalSharesInCurve, totalSharesInCurve, totalAssetsInCurve
                )
            );
            require(success, "previewRedeem failed");
            uint256 assetsToWithdraw = abi.decode(data, (uint256));

            result.totalAssetsWithdrawn += assetsToWithdraw;
            result.totalSharesBurned += totalSharesInCurve;
            console.log(
                "Withdrawing remainder: %s shares -> %s assets",
                totalSharesInCurve.toString(),
                assetsToWithdraw.toString()
            );
        }

        // Calculate discrepancy
        result.assetDiscrepancy = result.totalAssetsDeposited > result.totalAssetsWithdrawn
            ? result.totalAssetsDeposited - result.totalAssetsWithdrawn
            : result.totalAssetsWithdrawn - result.totalAssetsDeposited;

        // Add summary of total redemption
        console.log(
            "Withdrew a total of %s assets by redeeming %s shares",
            result.totalAssetsWithdrawn.toString(),
            result.totalSharesBurned.toString()
        );

        // Calculate percentage (in basis points)
        result.discrepancyPercentage = (result.assetDiscrepancy * 10000) / result.totalAssetsDeposited;

        console.log(
            "Final discrepancy: %s (%s of %s)",
            result.assetDiscrepancy.toString(),
            result.assetDiscrepancy.toPercentage(result.totalAssetsDeposited),
            result.totalAssetsDeposited.toString()
        );

        // Check if within error margin
        require(
            result.discrepancyPercentage <= errorMargin,
            string(
                abi.encodePacked(
                    "Discrepancy too high: ",
                    result.discrepancyPercentage.toString(),
                    " bps > ",
                    errorMargin.toString(),
                    " bps"
                )
            )
        );

        console.log("=== Test Passed ===\n");
        return result;
    }
}
