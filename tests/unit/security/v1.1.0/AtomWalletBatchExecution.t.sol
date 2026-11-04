// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseAccount } from "@account-abstraction/core/BaseAccount.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";

/// @dev Records calls and can be told to revert, so batch failure semantics are observable.
contract BatchTarget {
    uint256 public callCount;
    uint256 public lastValue;

    error BatchTarget_Rejected();

    function ping() external payable {
        callCount += 1;
        lastValue = msg.value;
    }

    function boom() external payable {
        revert BatchTarget_Rejected();
    }
}

/// @title  AtomWalletBatchExecutionTest
/// @notice Gating coverage for the `executeBatch(Call[])` override.
///
///         `BaseAccount` ships a live `executeBatch(Call[])` gated only by `_requireForExecute()`
///         (EntryPoint only) and carrying no reentrancy guard. Leaving it inherited would expose a
///         second batch selector with weaker protection than the protocol's own overload and a
///         different authorization notion from the MultiOwnable set. These tests pin the override's
///         authorization matrix, its failure semantics, and the selector itself — the selector
///         because changing it would silently break every bundler and SDK that encodes ERC-4337
///         batches against the standard ABI.
contract AtomWalletBatchExecutionTest is BaseTest {
    AtomWallet internal wallet;
    address internal warden;
    address internal owner;
    address internal coOwner;
    address internal outsider;
    BatchTarget internal target;

    function setUp() public override {
        super.setUp();

        warden = protocol.multiVault.getAtomWarden();
        owner = makeAddr("batch-owner");
        coOwner = makeAddr("batch-co-owner");
        outsider = makeAddr("batch-outsider");
        target = new BatchTarget();

        bytes32 atomId = createSimpleAtom("batch-wallet", ATOM_COST[0], users.alice);
        wallet = AtomWallet(payable(protocol.atomWalletFactory.deployAtomWallet(atomId)));

        resetPrank(warden);
        wallet.completeClaim(owner);

        resetPrank(owner);
        wallet.addOwnerAddress(coOwner);

        vm.deal(address(wallet), 10 ether);
    }

    function _calls(uint256 n) internal view returns (BaseAccount.Call[] memory calls) {
        calls = new BaseAccount.Call[](n);
        for (uint256 i = 0; i < n; ++i) {
            calls[i] =
                BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.ping, ()) });
        }
    }

    /* =================================================== */
    /*                     SELECTOR                        */
    /* =================================================== */

    /// @dev The override must keep the inherited selector, or every ERC-4337 bundler and SDK that
    ///      encodes a standard batch against this account breaks.
    function test_executeBatchCalls_preservesInheritedSelector() external pure {
        assertEq(
            bytes4(keccak256("executeBatch((address,uint256,bytes)[])")),
            BaseAccount.executeBatch.selector,
            "the Call[] batch selector must match BaseAccount"
        );
    }

    /* =================================================== */
    /*                  AUTHORIZATION                      */
    /* =================================================== */

    function test_executeBatchCalls_primaryOwnerSucceeds() external {
        resetPrank(owner);
        wallet.executeBatch(_calls(2));
        assertEq(target.callCount(), 2, "primary owner may batch");
    }

    function test_executeBatchCalls_coOwnerSucceeds() external {
        resetPrank(coOwner);
        wallet.executeBatch(_calls(1));
        assertEq(target.callCount(), 1, "co-owner may batch");
    }

    function test_executeBatchCalls_entryPointSucceeds() external {
        resetPrank(address(wallet.entryPoint()));
        wallet.executeBatch(_calls(1));
        assertEq(target.callCount(), 1, "EntryPoint may batch");
    }

    /// @dev The authorization guard. It is enforced by the `_requireForExecute()` call in the override
    ///      body, resolving to AtomWallet's hook override — NOT by a modifier on the override itself.
    ///      Neutering that hook (or removing the `_requireForExecute()` call) passes this through and
    ///      turns the test red.
    function test_executeBatchCalls_revertsForUnauthorizedCaller() external {
        resetPrank(outsider);
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector));
        wallet.executeBatch(_calls(1));
    }

    /* =================================================== */
    /*                 FAILURE SEMANTICS                   */
    /* =================================================== */

    /// @dev A single failing call bubbles the target's own revert data unwrapped.
    function test_executeBatchCalls_singleCallBubblesRawRevert() external {
        BaseAccount.Call[] memory calls = new BaseAccount.Call[](1);
        calls[0] = BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.boom, ()) });

        resetPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(BatchTarget.BatchTarget_Rejected.selector));
        wallet.executeBatch(calls);
    }

    /// @dev A multi-call batch wraps the failure so the failing leg index is identifiable.
    function test_executeBatchCalls_multiCallWrapsWithIndex() external {
        BaseAccount.Call[] memory calls = new BaseAccount.Call[](3);
        calls[0] = BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.ping, ()) });
        calls[1] = BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.boom, ()) });
        calls[2] = BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.ping, ()) });

        resetPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseAccount.ExecuteError.selector,
                uint256(1),
                abi.encodeWithSelector(BatchTarget.BatchTarget_Rejected.selector)
            )
        );
        wallet.executeBatch(calls);
    }

    /// @dev Native value is forwarded per leg from the wallet's own balance.
    function test_executeBatchCalls_forwardsValuePerLeg() external {
        BaseAccount.Call[] memory calls = new BaseAccount.Call[](1);
        calls[0] =
            BaseAccount.Call({ target: address(target), value: 1 ether, data: abi.encodeCall(BatchTarget.ping, ()) });

        resetPrank(owner);
        wallet.executeBatch(calls);

        assertEq(address(target).balance, 1 ether, "value forwarded to the leg");
        assertEq(target.lastValue(), 1 ether, "leg observed its own value");
    }

    /* =================================================== */
    /*                    REENTRANCY                       */
    /* =================================================== */

    /// @dev The override carries `nonReentrant`, matching the sibling overload. A batch leg that
    ///      re-enters a guarded wallet surface must revert rather than execute. Removing the modifier
    ///      lets the nested call through and turns this red.
    function test_executeBatchCalls_rejectsNestedGuardedSelfCall() external {
        BaseAccount.Call[] memory inner = new BaseAccount.Call[](1);
        inner[0] = BaseAccount.Call({ target: address(target), value: 0, data: abi.encodeCall(BatchTarget.ping, ()) });

        BaseAccount.Call[] memory calls = new BaseAccount.Call[](1);
        calls[0] = BaseAccount.Call({
            target: address(wallet), value: 0, data: abi.encodeWithSelector(BaseAccount.executeBatch.selector, inner)
        });

        resetPrank(owner);
        // Exact selector, not a bare expectRevert: the single-call branch bubbles the inner revert
        // data unwrapped, so the reentrancy guard's own error must be what surfaces. Accepting any
        // revert would let an unrelated future failure keep this test green for the wrong reason.
        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector));
        wallet.executeBatch(calls);

        assertEq(target.callCount(), 0, "no leg executed through the nested guarded call");
    }
}
