// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @dev Thin harness that seeds the tier schedule directly into storage (a subclass may write the
///      `internal config`), avoiding the proxy/delegatecall so the symbolic engine only reasons about
///      the fee math. The pricing surface and record hooks are untouched and unused here.
contract DynamicFeeCurveHarness is DynamicFeeFlatPriceCurve {
    constructor(DynamicFeeConfig memory config_, address multiVault_) {
        config = config_;
        multiVault = multiVault_;
    }
}

/// @title  DynamicFeeSymbolicTest
/// @notice Halmos symbolic proofs of the fee-bound properties that underpin "max loss = fees paid":
///         for ALL inputs, no fee rate exceeds its cap (and hence BPS), and no quoted fee exceeds the
///         amount it is charged on. Run with: `halmos --match-contract DynamicFeeSymbolicTest`.
/// @dev    A small concrete tier schedule (`tierCount = 3`) is initialized in setUp so the piecewise
///         deposit walk unrolls to a finite, solver-tractable depth; the fee arguments stay symbolic.
contract DynamicFeeSymbolicTest is Test {
    DynamicFeeFlatPriceCurve internal curve;

    uint256 internal constant BPS = 10_000;
    uint256 internal constant DEPOSIT_CAP_BPS = 1000;
    uint256 internal constant WITHDRAWAL_CAP_BPS = 1000;
    bytes32 internal constant TERM = keccak256("symbolic-term");

    function setUp() public {
        DynamicFeeConfig memory config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 3,
            tierWidthGrowthBps: 2000,
            depositBaseBps: 100,
            depositGrowthBps: 50,
            depositCapBps: DEPOSIT_CAP_BPS,
            fulcrumAlphaBps: 10_000,
            kernelSpread: 4e18,
            redeemBaseBps: 200,
            redeemGrowthBps: 50,
            redeemCapBps: WITHDRAWAL_CAP_BPS,
            redeemToFulcrumTiersBps: 0,
            depositToPriorTierBps: 0,
            minEligibleTierStake: 0
        });

        curve = new DynamicFeeCurveHarness(config, address(this));
    }

    /// @notice The formulaic deposit rate never exceeds the configured cap, across the whole schedulable
    ///         tier domain `[0, MAX_TIER_COUNT)`.
    /// @dev `tier` is clamped to the schedulable range so the proof covers the real domain rather than
    ///      the arithmetic-overflow paths (`base + tier*growth` reverts for astronomically large tiers,
    ///      which is safe but not the property under test).
    function check_depositFeeBps_neverExceedsCap(uint256 tier) public view {
        tier = tier % curve.MAX_TIER_COUNT();
        assert(curve.depositFeeBps(tier) <= DEPOSIT_CAP_BPS);
    }

    /// @notice The formulaic redeem rate never exceeds the configured cap, across the whole
    ///         schedulable tier domain `[0, MAX_TIER_COUNT)`.
    function check_redeemFeeBps_neverExceedsCap(uint256 tier) public view {
        tier = tier % curve.MAX_TIER_COUNT();
        assert(curve.redeemFeeBps(tier) <= WITHDRAWAL_CAP_BPS);
    }

    /// @notice A redeem fee never exceeds the gross assets it is charged on (principal at par: the
    ///         most a redeemer can lose is the fee, never more than they hold).
    function check_quoteRedeemFee_neverExceedsGross(address account, uint256 grossAssets) public view {
        grossAssets = uint256(uint128(grossAssets)); // keep gross * bps within 256 bits
        assert(curve.quoteRedeemFee(TERM, account, grossAssets) <= grossAssets);
    }

    /// @notice A deposit fee never exceeds the base assets it is charged on, across the piecewise walk.
    function check_quoteDepositFee_neverExceedsBase(uint256 baseAssets) public view {
        baseAssets = uint256(uint128(baseAssets));
        assert(curve.quoteDepositFee(TERM, baseAssets) <= baseAssets);
    }
}
