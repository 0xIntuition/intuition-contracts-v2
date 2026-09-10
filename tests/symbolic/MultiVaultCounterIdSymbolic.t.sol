// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";

/// @title  MultiVaultCounterIdSymbolic
/// @author 0xIntuition
/// @notice Halmos symbolic proofs for the counter-triple id derivation that underpins the MultiVault
///         counter-stake guard. The guard (`_hasCounterStake`) blocks an account from holding both the
///         positive and counter side of a triple on the same curve; its correctness rests on the id
///         derivation being collision-free, injective, and consistent across the two public derivation
///         paths. These are pure, keccak-based properties — exactly what symbolic execution proves
///         exhaustively where bounded fuzzing only samples.
/// @dev    Run: `halmos --contract MultiVaultCounterIdSymbolic`. Targets the MultiVault implementation
///         directly (no proxy / no init needed — the functions are `pure`). Deeper symbolic execution
///         over the stateful multicall / rollover paths is impractical against the proxy +
///         delegatecall-linked-library + transient-storage architecture; those properties are covered
///         by the Foundry invariant campaign in `tests/invariant/` instead.
contract MultiVaultCounterIdSymbolic is Test {
    MultiVault internal multiVault;

    function setUp() public {
        multiVault = new MultiVault();
    }

    /// @notice A (derived) triple id can never equal its own counter id, so positive and counter
    ///         vaults are always distinct terms and the guard can never confuse the two sides. The
    ///         triple id is derived from symbolic subject/predicate/object (as it always is on-chain)
    ///         rather than taken free-symbolic: the counter id then hashes a different-length preimage
    ///         (`COUNTER_SALT‖tripleId`) than the triple id (`TRIPLE_SALT‖s‖p‖o`), so keccak injectivity
    ///         proves inequality soundly. (A free-symbolic `tripleId` would admit a spurious
    ///         `keccak(x) == x` fixed point that is preimage-infeasible in reality.)
    function check_counterIdNeverCollidesWithTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        external
        view
    {
        bytes32 tripleId = multiVault.calculateTripleId(subjectId, predicateId, objectId);
        assert(multiVault.getCounterIdFromTripleId(tripleId) != tripleId);
    }

    /// @notice Counter ids are injective: two distinct triples never share a counter vault.
    function check_counterIdInjective(bytes32 a, bytes32 b) external view {
        vm.assume(a != b);
        assert(multiVault.getCounterIdFromTripleId(a) != multiVault.getCounterIdFromTripleId(b));
    }

    /// @notice The two public derivation paths agree: deriving the counter id from a computed triple id
    ///         equals computing the counter id directly from the same subject/predicate/object.
    function check_counterDerivationConsistency(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        external
        view
    {
        bytes32 tripleId = multiVault.calculateTripleId(subjectId, predicateId, objectId);
        assert(
            multiVault.getCounterIdFromTripleId(tripleId)
                == multiVault.calculateCounterTripleId(subjectId, predicateId, objectId)
        );
    }
}
