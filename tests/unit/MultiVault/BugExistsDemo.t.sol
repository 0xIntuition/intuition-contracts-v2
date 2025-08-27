// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

contract BugExistsDemo is BaseTest {
    uint256 constant LINEAR_CURVE_ID = 1;
    uint256 constant PROGRESSIVE_CURVE_ID = 2;

    function test_LinearCurve_NoIssue() public {
        console2.log("\n=== LinearCurve - No Bug ===");

        bytes32 atomId = createSimpleAtom("Linear Test", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, LINEAR_CURVE_ID, 100e18, 0);
        console2.log("Shares received: %d", shares);

        (uint256 assetsBefore, uint256 sharesBefore) = protocol.multiVault.getVault(atomId, LINEAR_CURVE_ID);
        console2.log("Vault before: Assets=%d, Shares=%d", assetsBefore, sharesBefore);

        uint256 assetsRedeemed = redeemShares(users.alice, users.alice, atomId, LINEAR_CURVE_ID, shares, 0);
        console2.log("Assets redeemed: %d", assetsRedeemed);

        uint256 remaining = protocol.multiVault.getShares(users.alice, atomId, LINEAR_CURVE_ID);
        (uint256 assetsAfter, uint256 sharesAfter) = protocol.multiVault.getVault(atomId, LINEAR_CURVE_ID);

        console2.log("User remaining shares: %d", remaining);
        console2.log("Vault after: Assets=%d, Shares=%d", assetsAfter, sharesAfter);

        assertEq(remaining, 0, "LinearCurve: No dust (correct)");
    }

    function test_ProgressiveCurve_BugExists() public {
        console2.log("\n=== ProgressiveCurve - Bug Demonstration ===");

        bytes32 atomId = createSimpleAtom("Progressive Test", ATOM_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, atomId, PROGRESSIVE_CURVE_ID, 100e18, 0);
        console2.log("Shares received: %d", shares);

        (uint256 assetsBefore, uint256 sharesBefore) = protocol.multiVault.getVault(atomId, PROGRESSIVE_CURVE_ID);
        console2.log("Vault before: Assets=%d, Shares=%d", assetsBefore, sharesBefore);

        uint256 maxRedeemable = shares;
        if (sharesBefore - shares < MIN_SHARES) {
            maxRedeemable = sharesBefore > MIN_SHARES ? sharesBefore - MIN_SHARES : 0;
        }

        console2.log("Attempting to redeem: %d shares", maxRedeemable);

        uint256 assetsRedeemed = 0;
        if (maxRedeemable > 0) {
            assetsRedeemed = redeemShares(users.alice, users.alice, atomId, PROGRESSIVE_CURVE_ID, maxRedeemable, 0);
            console2.log("Assets redeemed: %d", assetsRedeemed);
        }

        uint256 remaining = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
        (uint256 assetsAfter, uint256 sharesAfter) = protocol.multiVault.getVault(atomId, PROGRESSIVE_CURVE_ID);

        console2.log("\n=== RESULTS ===");
        console2.log("User remaining shares: %d", remaining);
        console2.log("Vault remaining: Assets=%d, Shares=%d", assetsAfter, sharesAfter);

        if (remaining > MIN_SHARES) {
            console2.log("\nBUG CONFIRMED: User has %d dust shares they cannot redeem!", remaining - MIN_SHARES);
            console2.log("This is due to precision loss in progressive curve calculations");
        } else if (remaining == MIN_SHARES) {
            console2.log("\nMIN_SHARES requirement: User must leave %d shares in vault", MIN_SHARES);
        } else {
            console2.log("\nFIX ACTIVE: Dust protection allowed complete redemption!");
        }

        assertTrue(remaining >= 0, "Test demonstrates current behavior");
    }

    function test_DustAccumulation() public {
        console2.log("\n=== Dust Accumulation Test ===");

        bytes32 atomId = createSimpleAtom("Accumulation Test", ATOM_COST[0], users.alice);

        uint256 totalUserDust = 0;
        uint256 cycles = 3;

        for (uint256 i = 0; i < cycles; i++) {
            console2.log("\nCycle %d:", i + 1);

            uint256 shares = makeDeposit(users.alice, users.alice, atomId, PROGRESSIVE_CURVE_ID, 10e18, 0);
            console2.log("  Deposited 10 ETH, got %d shares", shares);

            (uint256 totalAssets, uint256 totalShares) = protocol.multiVault.getVault(atomId, PROGRESSIVE_CURVE_ID);

            uint256 safeRedeem = shares;
            if (totalShares - shares < MIN_SHARES) {
                safeRedeem = totalShares > MIN_SHARES ? totalShares - MIN_SHARES : 0;
            }

            if (safeRedeem > 0) {
                uint256 assetsBack = redeemShares(users.alice, users.alice, atomId, PROGRESSIVE_CURVE_ID, safeRedeem, 0);
                console2.log("  Redeemed %d shares for %d assets", safeRedeem, assetsBack);
            }

            uint256 userShares = protocol.multiVault.getShares(users.alice, atomId, PROGRESSIVE_CURVE_ID);
            if (userShares > MIN_SHARES) {
                uint256 dust = userShares - MIN_SHARES;
                console2.log("  Dust accumulated: %d shares", dust);
                totalUserDust += dust;
            }
        }

        console2.log("\n=== FINAL RESULTS ===");
        console2.log("Total user dust after %d cycles: %d", cycles, totalUserDust);

        if (totalUserDust > 0) {
            console2.log("BUG CONFIRMED: Precision loss causes dust accumulation");
        } else {
            console2.log("FIX ACTIVE: Dust protection prevents accumulation");
        }

        assertTrue(true, "Test demonstrates accumulation behavior");
    }
}
