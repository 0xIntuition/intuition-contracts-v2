// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { BondingCurveRegistry } from "src/protocol/curves/BondingCurveRegistry.sol";
import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

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
    ///      `clearTierFeeOverride`, `sweepProtocol` and `renounceOwnership`. On governed networks this
    ///      MUST be the parameters `TimelockController`, so every fee action goes through the same
    ///      4-of-8 Safe + timelock path as the equivalent `MultiVault` setters. The curve is `Ownable`
    ///      with no role system, so setting the owner to the timelock is the whole gating mechanism —
    ///      no separate `onlyTimelock` modifier is required or wanted.
    address public PARAMETERS_TIMELOCK_CONTROLLER;

    /// @dev Must be globally unique in the registry; distinct from the default "Linear Curve".
    string internal constant CURVE_NAME = "Dynamic Fee Flat Price Curve";

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ANVIL) {
            UPGRADES_TIMELOCK_CONTROLLER = msg.sender;
            PARAMETERS_TIMELOCK_CONTROLLER = msg.sender;
        } else if (block.chainid == NETWORK_INTUITION_SEPOLIA) {
            UPGRADES_TIMELOCK_CONTROLLER = 0x81c66D5dD09F1dEF8493E5A5B459e2E9028a4430;
            PARAMETERS_TIMELOCK_CONTROLLER = 0xA87E4EEd6C71966E938b45c0e2127344DC597D12;
        } else if (block.chainid == NETWORK_INTUITION) {
            UPGRADES_TIMELOCK_CONTROLLER = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
            PARAMETERS_TIMELOCK_CONTROLLER = 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA;
        } else {
            revert("Unsupported chain for DeployDynamicFeeFlatPriceCurve script");
        }
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
                PARAMETERS_TIMELOCK_CONTROLLER, // governed networks: the parameters timelock, never the deploying key
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

    /// @dev Seed schedule: the decided 13-tier cap with 1% + 0.5%/tier deposit fees and 2% + 0.5%/tier
    ///      withdrawal fees, both capped at 10%. Fee distribution: triangular fulcrum, alpha = BPS,
    ///      sigma = 4e18 (the nearest-first window). Exit fees go to the leaver's own
    ///      tier (the exiting-tier default), falling through to the nearest occupied tier when that tier
    ///      has no residual holders. `growthG = 0.2` -> `tierWidthGrowthBps = 2000`, i.e. each tier band is
    ///      1.2x the one below it (compounding): widths run 5,000 -> 44,581 TRUST across the 13 tiers.
    ///      The terminal tier 12 begins at the tier-11 edge, ~197,903 TRUST, and absorbs everything
    ///      above it unbounded; tier 12's own closed-form edge (~242,483 TRUST) is inert (never a
    ///      boundary, since `tierOf` caps at the terminal tier).
    ///      These are the values the curve DEPLOYS with, not fixed constants: tier widths/edges, per-tier
    ///      fees, and the fulcrum alpha/sigma are all retunable post-deploy via `setConfig`, so treat any
    ///      number below as the starting schedule rather than a permanent one. The 13-tier count and the
    ///      schedule shape are what stay put. Note `tierWidthGrowthBps` is a COMPOUNDING rate —
    ///      the same numeric value stretches the ladder far more than a linear ramp would.
    ///      `minEligibleTierStake` — the floor a tier must hold to receive redistributed fees — ships at
    ///      0, i.e. DISABLED, reproducing the plain occupancy behaviour, so the mechanism changes nothing
    ///      until governance turns it on. Raising it is a `setConfig` action by the parameters timelock
    ///      like any other parameter, bounded by the curve's immutable `MAX_MIN_ELIGIBLE_TIER_STAKE`, and
    ///      it emits `MinEligibleTierStakeUpdated` with the before/after values so a raise is monitorable.
    function _defaultConfig() internal pure returns (DynamicFeeConfig memory config) {
        config = DynamicFeeConfig({
            width0: 5000e18,
            tierCount: 13,
            tierWidthGrowthBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: 1000,
            fulcrumAlphaBps: 10_000,
            kernelSpread: 4e18,
            withdrawalBaseBps: 200,
            withdrawalGrowthBps: 50,
            withdrawalCapBps: 1000,
            withdrawalToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStake: 0
        });
    }
}
