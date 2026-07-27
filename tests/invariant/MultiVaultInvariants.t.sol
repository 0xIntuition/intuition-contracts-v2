// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "tests/BaseTest.t.sol";

import { MultiVaultInvariantHandler } from "tests/invariant/handlers/MultiVaultInvariantHandler.sol";

/// @title  MultiVaultInvariants
/// @author 0xIntuition
/// @notice Stateful invariant campaign for the v1.1.0 MultiVault. Drives random create / deposit /
///         redeem / multicall / multicallPayable sequences (atoms, triples, counter-triples) through
///         {MultiVaultInvariantHandler} against the full proxy + linked-library deployment from
///         {BaseTest}, and asserts the protocol-level safety properties the on-behalf-of, multicall,
///         and counter-stake changes must preserve:
///
///         - native-value conservation: with no fee sweeps, `MultiVault.balance` always equals
///           `valueIn - valueOut`, so a multicallPayable sub-call can never duplicate, borrow, or leak
///           `msg.value` (the headline multicall accounting property);
///         - ghost (min) shares minted to `BURN_ADDRESS` are never burned below `minShare`;
///         - the closed set of share holders (actors + `BURN_ADDRESS`) can never collectively exceed a
///           vault's total shares (no phantom mint / accounting drift);
///         - no single account ever holds both the positive and counter side of a triple on the same
///           curve (the counter-stake guard is exhaustive across random sequences).
///
/// @dev    Runs natively under `forge test`; the same handler is consumed by Medusa via `medusa.json`
///         (`fuzzing.targetContracts = ["MultiVaultInvariantHandler"]`). Iteration counts are kept low
///         (inline `forge-config` below) so the suite is a fast smoke signal rather than a long
///         campaign. Curve scope is the default LinearCurve (curve id 1), where accounting is simplest.
contract MultiVaultInvariants is BaseTest {
    /// @dev Ghost-share sink: min shares are minted here on vault creation (see {MultiVaultLib}).
    address internal constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    MultiVaultInvariantHandler internal handler;

    uint256 internal defaultCurveId;
    uint256 internal minShare;

    function setUp() public override {
        super.setUp();

        // BaseTest.setUp leaves an ambient prank active; clear it so the handler can prank its actors.
        vm.stopPrank();

        defaultCurveId = getDefaultCurveId();
        minShare = protocol.multiVault.getGeneralConfig().minShare;

        handler =
            new MultiVaultInvariantHandler(protocol.multiVault, defaultCurveId, users.alice, users.bob, users.charlie);

        targetContract(address(handler));
    }

    /// @notice With no fee sweeps during the campaign, MultiVault's native balance must equal exactly
    ///         the value moved in minus the value redeemed out. Any multicallPayable value duplication,
    ///         borrowing across sub-calls, or leak would break this identity.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 50
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_nativeValueConservation() external view {
        assertEq(
            address(protocol.multiVault).balance,
            handler.ghost_valueIn() - handler.ghost_valueOut(),
            "MultiVault native balance drifted from valueIn - valueOut"
        );
    }

    /// @notice Every initialized vault retains at least `minShare` ghost shares (never burned away).
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 50
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_ghostSharesPreserved() external view {
        bytes32[] memory terms = _allTerms();
        for (uint256 i = 0; i < terms.length; ++i) {
            (, uint256 totalShares) = protocol.multiVault.getVault(terms[i], defaultCurveId);
            if (totalShares == 0) continue;
            assertGe(totalShares, minShare, "ghost shares burned below minShare");
        }
    }

    /// @notice Actor + burn-address share balances can never collectively exceed a vault's total shares.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 50
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_holderSharesNeverExceedTotal() external view {
        bytes32[] memory terms = _allTerms();
        uint256 actorCount = handler.actorCount();
        for (uint256 i = 0; i < terms.length; ++i) {
            (, uint256 totalShares) = protocol.multiVault.getVault(terms[i], defaultCurveId);
            uint256 sumHolderShares = protocol.multiVault.getShares(BURN_ADDRESS, terms[i], defaultCurveId);
            for (uint256 a = 0; a < actorCount; ++a) {
                sumHolderShares += protocol.multiVault.getShares(handler.actorAt(a), terms[i], defaultCurveId);
            }
            assertLe(sumHolderShares, totalShares, "holder shares exceed vault total");
        }
    }

    /// @notice No account holds both the positive and counter side of any triple on the same curve.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 50
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_noSimultaneousCounterStake() external view {
        uint256 tripleCount = handler.tripleTermsLength();
        uint256 actorCount = handler.actorCount();
        for (uint256 t = 0; t < tripleCount; ++t) {
            bytes32 tripleId = handler.tripleTerms(t);
            bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);
            for (uint256 a = 0; a < actorCount; ++a) {
                address actor = handler.actorAt(a);
                bool holdsPositive = protocol.multiVault.getShares(actor, tripleId, defaultCurveId) > 0;
                bool holdsCounter = protocol.multiVault.getShares(actor, counterId, defaultCurveId) > 0;
                assertFalse(holdsPositive && holdsCounter, "account holds both sides of a triple");
            }
        }
    }

    /// @dev Aggregates all atoms plus both sides of every triple for vault-level sweeps.
    function _allTerms() internal view returns (bytes32[] memory terms) {
        uint256 atomLen = handler.atomTermsLength();
        uint256 tripleLen = handler.tripleTermsLength();
        terms = new bytes32[](atomLen + tripleLen * 2);

        uint256 idx;
        for (uint256 i = 0; i < atomLen; ++i) {
            terms[idx++] = handler.atomTerms(i);
        }
        for (uint256 i = 0; i < tripleLen; ++i) {
            bytes32 tripleId = handler.tripleTerms(i);
            terms[idx++] = tripleId;
            terms[idx++] = protocol.multiVault.getCounterIdFromTripleId(tripleId);
        }
    }
}
