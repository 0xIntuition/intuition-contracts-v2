// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DynamicFeeFlatPriceCurve } from "src/protocol/curves/DynamicFeeFlatPriceCurve.sol";
import { DynamicFeeConfig } from "src/interfaces/IDynamicFeeFlatPriceCurve.sol";

/// @title  DynamicFeeMedusaHandler
/// @author 0xIntuition
/// @notice Self-contained Medusa (and Echidna) fuzz harness for the flat-price dynamic-fee curve. It
///         deploys the curve behind a proxy, stands in as the authorized MultiVault, and drives random
///         deposit / redeem / claim sequences while asserting the value-conservation and solvency
///         properties. Curve-isolated (no full MultiVault system) so the fuzzer spends its budget on the
///         fee-accounting math, not system setup.
/// @dev    Run with: `medusa fuzz --config medusa.dynamicfee.json`. Ghost accounting mirrors the
///         MultiVault Medusa handler: `ghost_feesIn - ghost_valueOut` must always equal the curve's
///         native balance, and the balance must always cover every claimable + the protocol accrual.
contract DynamicFeeMedusaHandler is Test {
    DynamicFeeFlatPriceCurve internal curve;

    bytes32 internal constant TERM = keccak256("medusa-dynamic-fee");
    address[3] internal actors = [address(0x1111), address(0x2222), address(0x3333)];

    /// @dev Total native value forwarded into the curve as fees on successful record hooks.
    uint256 public ghost_feesIn;
    /// @dev Total native value paid back out of the curve to claimers.
    uint256 public ghost_valueOut;

    /// @dev `payable` is load-bearing: Medusa funds the harness by attaching value to the deployment
    ///      transaction, and a non-payable constructor rejects that transfer before any code runs —
    ///      which surfaces only as a bare "execution reverted" with no revert data.
    constructor() payable {
        DynamicFeeConfig memory config = DynamicFeeConfig({
            width0: 10e18,
            tierCount: 5,
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

        DynamicFeeFlatPriceCurve impl = new DynamicFeeFlatPriceCurve();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(0xDEAD),
            abi.encodeWithSelector(
                DynamicFeeFlatPriceCurve.initialize.selector, "Medusa Curve", address(this), address(this), config
            )
        );
        curve = DynamicFeeFlatPriceCurve(address(proxy));
    }

    /// @dev The fuzzer funds this handler at deployment (Medusa via the constructor's `value`, Echidna
    ///      via `balanceContract`), so no cheat-code top-up is needed — and a construction-time
    ///      cheat call is exactly what prevented this harness from deploying under Medusa.
    receive() external payable { }

    /* ============ FUZZED ACTIONS ============ */

    function recordDeposit(uint256 actorSeed, uint256 stake, uint256 fee) public {
        address actor = actors[actorSeed % actors.length];
        stake = _bound(stake, 1, 1e24);
        fee = _bound(fee, 0, 100 ether);
        try curve.recordDeposit{ value: fee }(TERM, actor, stake) {
            ghost_feesIn += fee;
        } catch { }
    }

    function recordRedeem(uint256 actorSeed, uint256 shares, uint256 fee) public {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = curve.userStake(TERM, actor);
        if (balance == 0) return;
        shares = _bound(shares, 1, balance);
        fee = _bound(fee, 0, 100 ether);
        try curve.recordRedeem{ value: fee }(TERM, actor, shares) {
            ghost_feesIn += fee;
        } catch { }
    }

    function claim(uint256 actorSeed) public {
        address actor = actors[actorSeed % actors.length];
        if (curve.claimable(actor, TERM) == 0) return;
        bytes32[] memory terms = new bytes32[](1);
        terms[0] = TERM;
        vm.prank(actor);
        try curve.claim(terms) returns (uint256 amount) {
            ghost_valueOut += amount;
        } catch { }
    }

    /// @notice Let the campaign explore the deposit prior-tier spike across its full range so the
    ///         stateful net exercises the lump-to-nearest-occupied-prior-tier path, not just the
    ///         pure-fulcrum default. Owner-only setter; the handler is the curve owner.
    function setPriorTierShare(uint256 shareBps) public {
        DynamicFeeConfig memory config = curve.getConfig();
        config.depositToPriorTierBps = _bound(shareBps, 0, 10_000);
        curve.setConfig(config);
    }

    /* ============ PROPERTIES ============ */

    /// @notice Exact native-value conservation: the curve holds precisely what came in minus what went out.
    /// @dev Written in addition form (`balance + out == in`) so that if an accounting bug ever made
    ///      `ghost_valueOut` exceed `ghost_feesIn`, the property reports the violation by returning
    ///      `false` rather than reverting on a checked-arithmetic underflow.
    function property_valueConserved() public view returns (bool) {
        return address(curve).balance + ghost_valueOut == ghost_feesIn;
    }

    /// @notice Solvency: the curve's balance always covers every obligation it owes.
    function property_solvent() public view returns (bool) {
        uint256 obligations = curve.protocolAccrued();
        for (uint256 i = 0; i < actors.length; ++i) {
            obligations += curve.claimable(actors[i], TERM);
        }
        return address(curve).balance >= obligations;
    }
}
