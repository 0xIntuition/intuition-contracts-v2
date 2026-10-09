// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";
import { DynamicFeeLaunchSchedule } from "script/intuition/DynamicFeeLaunchSchedule.sol";

/*
Deploys the flat-price / dynamic-fee curve:
  1. ONE `DynamicFeeFlatPriceCurve` proxy — a single contract that is both the flat 1:1 pricing
     surface (inherited from LinearCurve) and the tier schedule + fee accounting that custodies the
     fees. Registered under a fresh curveId.
  2. The single wiring transaction (registry.addBondingCurve) that must be executed by the registry
     owner — done inline on anvil, printed as calldata elsewhere. Who that owner is differs by
     network and is worth checking rather than assuming: on MAINNET the registry is timelock-owned,
     so the calldata goes through the governed path; on INTUITION SEPOLIA it is a plain EOA, so
     registration there is one ordinary transaction and involves no timelock or Safe at all. No
     MultiVault-side wiring exists: the MultiVault discovers the curve's fee hooks through the
     standardized `IBaseCurve` hook getters on every deposit/redeem.

WARNING: the curve's `_multiVault` initializer argument MUST be the production MultiVault proxy.
The curve's record hooks are `onlyMultiVault`, so a miswired curve makes every deposit/redeem on
its (append-only, unrecoverable) curve id revert. Before executing the governance tx on a live
chain, fork-simulate `registry.addBondingCurve` followed by a deposit on the new curve id and
assert it succeeds.

Requires env vars pointing at the live deployment on the target chain:
  BONDING_CURVE_REGISTRY_ADDRESS, MULTIVAULT_ADDRESS

Fresh testnet deployments must also provide the upgrades timelock created by
`IntuitionDeployAndSetup` and the admin address that owns the curve:
  INTUITION_SEPOLIA_UPGRADES_TIMELOCK_CONTROLLER,
  INTUITION_SEPOLIA_ADMIN_ADDRESS

LOCAL
forge script script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:DeployDynamicFeeFlatPriceCurve \
--optimizer-runs 10000 --rpc-url anvil --broadcast --slow

TESTNET
forge script script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol:DeployDynamicFeeFlatPriceCurve \
--optimizer-runs 10000 --rpc-url intuition_sepolia --broadcast --slow --verify \
--chain 13579 --verifier blockscout \
--verifier-url 'https://intuition-testnet.explorer.caldera.xyz/api/'
*/

contract DeployDynamicFeeFlatPriceCurve is SetupScript {
    DynamicFeeFlatPriceCurve public dynamicFeeCurveImpl;
    TransparentUpgradeableProxy public dynamicFeeCurveProxy;

    address public UPGRADES_TIMELOCK_CONTROLLER;

    /// @dev Owner of the deployed curve — holds `setConfig`, `setTierFeeOverride`,
    ///      `clearTierFeeOverride`, `sweepProtocol` and `renounceOwnership`. On governed networks this is
    ///      the admin Safe (`ADMIN`), so fee retunes execute without a timelock delay while launch
    ///      parameters are being tuned. The fee caps are immutable, and the proxy's upgrade admin stays
    ///      the upgrades `TimelockController`. The curve is `Ownable2Step`, so ownership can later move
    ///      to a `TimelockController` with `transferOwnership` + `acceptOwnership`.
    address public CURVE_OWNER;

    /// @dev Must be globally unique in the registry; distinct from the default "Linear Curve".
    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            UPGRADES_TIMELOCK_CONTROLLER = msg.sender;
            CURVE_OWNER = msg.sender;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            UPGRADES_TIMELOCK_CONTROLLER = vm.envAddress("INTUITION_SEPOLIA_UPGRADES_TIMELOCK_CONTROLLER");
            CURVE_OWNER = ADMIN;
        } else if (block.chainid == NETWORK_INTUITION) {
            UPGRADES_TIMELOCK_CONTROLLER = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
            CURVE_OWNER = ADMIN;
        } else {
            revert("Unsupported chain for DeployDynamicFeeFlatPriceCurve script");
        }

        require(UPGRADES_TIMELOCK_CONTROLLER != address(0), "Upgrades timelock not provided");
        require(CURVE_OWNER != address(0), "Curve owner not provided");
    }

    function run() public broadcast {
        address registry = vm.envAddress("BONDING_CURVE_REGISTRY_ADDRESS");
        address multiVaultAddr = vm.envAddress("MULTIVAULT_ADDRESS");

        // 1. The single merged curve: flat 1:1 pricing + the fee economy, wired to the MultiVault and
        //    seeded with the default schedule ported from `flatFeeModel3.ts` (tunable later by the
        //    owner). It does NOT need to know its own curve id — the MultiVault resolves the curve
        //    through the registry on every deposit/redeem.
        dynamicFeeCurveImpl = new DynamicFeeFlatPriceCurve();
        dynamicFeeCurveProxy = new TransparentUpgradeableProxy(
            address(dynamicFeeCurveImpl),
            UPGRADES_TIMELOCK_CONTROLLER,
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector,
                CURVE_NAME,
                CURVE_OWNER, // governed networks: the admin Safe, never the deploying key
                multiVaultAddr,
                _defaultConfig()
            )
        );

        info("DynamicFeeFlatPriceCurve Proxy", address(dynamicFeeCurveProxy));
        // PREDICTED id only: registration has not executed yet (and on governed networks happens
        // later via the Safe). It drifts if another curve registers first — after the governance tx,
        // verify with `registry.curveIds(<curve proxy>)`.
        console2.log(
            "Predicted curveId (registry.count() + 1 at deploy time):", BondingCurveRegistry(registry).count() + 1
        );

        // 2. Register it. On anvil the broadcaster owns the registry, so do it inline; elsewhere emit
        //    the calldata for whoever owns the registry on that network to execute — a timelock on
        //    mainnet, but a plain EOA on Intuition Sepolia, where this is a single ordinary
        //    transaction rather than a governance action. Registration is the ONLY wiring step: once
        //    registered, the MultiVault detects the curve's fee hooks through `hasDepositFeeHook()` /
        //    `hasRedeemFeeHook()` on the curve itself.
        if (block.chainid == NETWORK_ANVIL) {
            BondingCurveRegistry(registry).addBondingCurve(address(dynamicFeeCurveProxy));
            console2.log("Registered inline (anvil).");
        } else {
            console2.log("--- Governance tx: registry.addBondingCurve ---");
            console2.log("target:", registry);
            console2.logBytes(abi.encodeCall(BondingCurveRegistry.addBondingCurve, (address(dynamicFeeCurveProxy))));
        }
    }

    /// @dev Seed schedule: 16 tiers, `width0 = 2,000 TRUST`, `tierWidthGrowthBps = 3500` so each band
    ///      is 1.35x the one below it (compounding: the terminal band is about 90x the first, and the
    ///      terminal tier begins near 510,000 TRUST and absorbs everything above it unbounded). Deposit
    ///      fees 1% + 0.45%/tier capped at 5.5%; withdrawal fees 1.5% + 0.35%/tier capped at 4.5%.
    ///      Both legs use a triangular fulcrum with alpha = 5000 bps and sigma = 6 tiers, so the peak
    ///      sits mid-span and slides up as the vault grows. 10% of each deposit fee walks down the
    ///      prior tiers, nearest first, each taking up to its fill; 75% of each redeem fee goes to
    ///      the prior tiers through the kernel and 25% to the other holders of the redeemed lot's
    ///      tier, falling through to the nearest eligible tiers, above first then below, when that
    ///      tier cannot take it. The kernel
    ///      spread weights every prior tier by its occupancy at a common rate capped at the schedule,
    ///      so a thin tier earns its fill, an over-full tier earns proportionally more, and only what
    ///      no stake is there to earn at the schedule rate accrues to the protocol bucket.
    ///      These are the values the curve DEPLOYS with, not fixed constants: tier widths/edges, per-tier
    ///      fees, and the fulcrum alpha/sigma are all retunable post-deploy via `setConfig`, so treat any
    ///      number below as the starting schedule rather than a permanent one. Note `tierWidthGrowthBps`
    ///      is a COMPOUNDING rate — the same numeric value stretches the ladder far more than a linear
    ///      ramp would.
    ///      `minEligibleTierStakeBps` — the floor a tier must hold to receive redistributed fees, as a
    ///      fraction of that tier's width — ships at 0, i.e. disabled, reducing eligibility to a non-zero
    ///      occupancy check. The occupancy weighting of the kernel spread and the fill cap on the
    ///      single-target credits (the spike and the exiting-tier slice each pay a tier at most its
    ///      `stake / width` of the amount) are always on and do not depend on this value. Raising the floor
    ///      is a `setConfig` action by the owner like any other parameter, bounded by
    ///      `BPS`, and it emits `MinEligibleTierStakeUpdated` with the before/after values so a raise is
    ///      monitorable.
    /// @dev The currently chosen launch-optimized configuration, deployed on the Intuition
    ///      Sepolia QA stack as "The Launch Optimized Config v3".
    ///
    ///      All fields are owner-settable post-deploy through `setConfig`. The ladder geometry —
    ///      `width0`, `tierWidthGrowthBps` and `tierCount` — shouldn't be changed after positions
    ///      exist, since it defines the tier edges those positions sit under (and `tierCount` can
    ///      only grow).
    function _defaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeLaunchSchedule.config();
    }
}
