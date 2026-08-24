// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// Cross-check harness: drives the real curve with a fixed op script and dumps state for the Python model to diff.
contract ScenariosTest is Test {
    DynamicFeeFlatPriceCurve internal c;
    bytes32 internal constant TERM = keccak256("term");
    address[6] internal users;

    function setUp() public {
        DynamicFeeConfig memory cfg = DynamicFeeConfig({
            width0: 5000e18, tierCount: 13, growthGBps: 2000,
            depositBaseBps: 100, depositGrowthBps: 50, depositCapBps: 1000,
            fulcrumAlpha: 10_000, kernelSpread: 4e18,
            withdrawalBaseBps: 200, withdrawalGrowthBps: 50, withdrawalCapBps: 1000,
            withdrawalToFulcrumTiersBps: 0, depositToPriorTierBps: 0, minEligibleTierStake: 0
        });
        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl), address(0xAD),
            abi.encodeWithSelector(DynamicFeeFlatPriceCurve.initialize.selector, "dyn", address(this), address(this), cfg)
        );
        c = DynamicFeeFlatPriceCurve(address(proxy));
        vm.deal(address(this), 10_000_000e18);
        users = [address(0xA1), address(0xB2), address(0xC3), address(0xD4), address(0xE5), address(0xF6)];
    }

    function dep(uint256 u, uint256 assets) internal {
        uint256 fee = c.quoteDepositFee(TERM, assets);
        c.recordDeposit{ value: fee }(TERM, users[u], assets - fee);
        console2.log("OP dep", u, assets, fee);
    }

    function red(uint256 u, uint256 shares) internal {
        uint256 fee = c.quoteRedeemFee(TERM, users[u], shares);
        c.recordRedeem{ value: fee }(TERM, users[u], shares);
        console2.log("OP red", u, shares, fee);
    }

    function test_script() external {
        dep(0, 3000e18);
        dep(1, 4000e18);
        dep(2, 12_000e18);
        dep(0, 20_000e18);
        red(1, 2000e18);
        dep(3, 50_000e18);
        red(2, c.userStake(TERM, users[2]));
        dep(4, 1e15);
        red(0, c.userStake(TERM, users[0]) / 2);
        dep(1, 100_000e18);
        red(3, c.userStake(TERM, users[3]));
        dep(5, 300_000e18);
        dep(2, 7_777e18);
        red(5, c.userStake(TERM, users[5]) / 3);
        dump();
    }

    function dump() internal view {
        console2.log("vaultStake", c.vaultStake(TERM));
        for (uint256 t = 0; t < 13; t++) {
            console2.log("tier", t, c.tierStake(TERM, t), c.accFeePerShare(TERM, t));
        }
        for (uint256 u = 0; u < 6; u++) {
            console2.log("user", u, c.userStake(TERM, users[u]), c.userTier(TERM, users[u]));
            console2.log("userx", u, c.userAvgTier(TERM, users[u]), c.rewardDebt(TERM, users[u]));
            console2.log("usery", u, c.earned(users[u]), c.pendingFor(users[u], TERM));
        }
        console2.log("protocolAccrued", c.protocolAccrued());
        console2.log("balance", address(c).balance);
    }
}

contract GasTest is ScenariosTest {
    function test_gas_profile() external {
        // one cohort per band so every prior tier is eligible (worst case for the kernel loops)
        uint256 g;
        for (uint256 k = 0; k < 12; k++) {
            uint256 w = c.tierWidthAt(k);
            uint256 fee = c.quoteDepositFee(TERM, w * 10_000 / (10_000 - c.depositFeeBps(k)) + 1e18);
            uint256 gross = w + fee + 1e18;
            g = gasleft();
            uint256 f2 = c.quoteDepositFee(TERM, gross);
            c.recordDeposit{ value: f2 }(TERM, users[k % 6], gross - f2);
            console2.log("GAS single-band-ish deposit at tier", k, g - gasleft());
        }
        // redeem from a populated tier (exit-tier credit path)
        g = gasleft();
        uint256 fr = c.quoteRedeemFee(TERM, users[1], 1e18);
        c.recordRedeem{ value: fr }(TERM, users[1], 1e18);
        console2.log("GAS redeem 1 TRUST (exit-tier credit)", g - gasleft());
        // worst case: a fresh vault swept from T0 to T12 in one deposit, with every tier occupied? No — fresh vault has no prior holders.
        // Instead: a second term where we first place 1 wei-ish holders at every tier, then sweep.
        bytes32 T2 = keccak256("term2");
        for (uint256 k = 0; k < 12; k++) {
            uint256 w = c.tierWidthAt(k);
            uint256 f = c.quoteDepositFee(T2, w * 10_000 / (10_000 - c.depositFeeBps(k)) + 1e18);
            uint256 gross = w + f + 1e18;
            uint256 f2 = c.quoteDepositFee(T2, gross);
            c.recordDeposit{ value: f2 }(T2, users[k % 6], gross - f2);
        }
        // now redeem everyone down to ~T0 but keep their buckets: redeem 99% of each
        for (uint256 u = 0; u < 6; u++) {
            uint256 s = c.userStake(T2, users[u]);
            uint256 f = c.quoteRedeemFee(T2, users[u], s * 99 / 100);
            c.recordRedeem{ value: f }(T2, users[u], s * 99 / 100);
        }
        console2.log("vault T2 now at", c.vaultStake(T2), "tier", c.tierOf(c.vaultStake(T2)));
        uint256 big = 300_000e18;
        g = gasleft();
        uint256 fb = c.quoteDepositFee(T2, big);
        uint256 gq = g - gasleft();
        g = gasleft();
        c.recordDeposit{ value: fb }(T2, address(0x999), big - fb);
        console2.log("GAS quote full sweep T0->T12", gq);
        console2.log("GAS recordDeposit full sweep T0->T12, all tiers occupied", g - gasleft());
        g = gasleft();
        bytes32[] memory ids = new bytes32[](1); ids[0] = T2;
        vm.prank(users[0]); c.claim(ids);
        console2.log("GAS claim (1 term)", g - gasleft());
    }
}
