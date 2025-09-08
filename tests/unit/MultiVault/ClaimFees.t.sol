// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";

/* -------------------------------------------------------------------------- */
/*                              Local test events                              */
/* -------------------------------------------------------------------------- */
interface ClaimEvents {
    event AtomWalletDepositFeesClaimed(
        bytes32 indexed termId, address indexed atomWalletOwner, uint256 indexed feesClaimed
    );

    event ProtocolFeeTransferred(uint256 indexed epoch, address indexed destination, uint256 amount);
}

/* -------------------------------------------------------------------------- */
/*                               Simple wallet mock                            */
/* -------------------------------------------------------------------------- */
contract AtomWalletOwnerMock {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}

contract ClaimTest is BaseTest, ClaimEvents {
    /*//////////////////////////////////////////////////////////////////////////
                                  HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    // Match the contract's mulDivUp(assets, fee, feeDenominator)
    function _feeOnRaw(uint256 amount, uint256 feeBp) internal view returns (uint256) {
        // FEE_DENOMINATOR is 10_000 in BaseTest
        return (amount * feeBp + (FEE_DENOMINATOR - 1)) / FEE_DENOMINATOR;
    }

    function _installAtomWalletMock(bytes32 atomId, address owner) internal returns (address walletAddr) {
        walletAddr = protocol.multiVault.computeAtomWalletAddr(atomId);

        // Deploy a mock that exposes owner()
        AtomWalletOwnerMock m = new AtomWalletOwnerMock(owner);

        // Copy its runtime code to the precomputed wallet address
        bytes memory code = address(m).code;
        vm.etch(walletAddr, code);

        // Set slot 0 to `owner` so owner() returns correctly
        vm.store(walletAddr, bytes32(uint256(0)), bytes32(uint256(uint160(owner))));
    }

    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////////////////
                   claimAtomWalletDepositFees — happy path
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAtomWalletDepositFees_SendsAndZeros() public {
        // Arrange: create atom with extra to accrue wallet deposit fees
        uint256 extra = 10 ether;
        bytes32 atomId = createSimpleAtom("claimable-atom", ATOM_COST[0] + extra, users.alice);

        // Expected fees: atomWalletDepositFee% of assetsAfterFixedFees (extra)
        uint256 expectedFee = _feeOnRaw(extra, ATOM_WALLET_DEPOSIT_FEE);

        // Install wallet mock at the precomputed address that returns Alice as owner
        address walletAddr = _installAtomWalletMock(atomId, users.alice);

        // Sanity: fees accumulated under wallet address
        uint256 beforeAcc = protocol.multiVault.accumulatedAtomWalletDepositFees(walletAddr);
        assertEq(beforeAcc, expectedFee, "pre - accumulated atom wallet fees mismatch");

        // Act: call claim from the wallet address
        uint256 ownerBalBefore = users.alice.balance;

        resetPrank(walletAddr);
        vm.expectEmit(true, true, true, true);
        emit AtomWalletDepositFeesClaimed(atomId, users.alice, expectedFee);
        protocol.multiVault.claimAtomWalletDepositFees(atomId);

        // Assert: owner received ETH, accumulator zeroed
        uint256 ownerBalAfter = users.alice.balance;
        assertEq(ownerBalAfter - ownerBalBefore, expectedFee, "owner should receive the accumulated fees");

        uint256 afterAcc = protocol.multiVault.accumulatedAtomWalletDepositFees(walletAddr);
        assertEq(afterAcc, 0, "accumulator must be zero after claim");
    }

    /*//////////////////////////////////////////////////////////////////////////
            claimAtomWalletDepositFees — revert when caller not wallet
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAtomWalletDepositFees_RevertWhen_NotAssociatedWallet() public {
        // Arrange: create atom (fees present or not is irrelevant for the permission check)
        bytes32 atomId = createSimpleAtom("no-perm-atom", ATOM_COST[0] + 1 ether, users.bob);

        // Act & Assert
        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_OnlyAssociatedAtomWallet.selector);
        protocol.multiVault.claimAtomWalletDepositFees(atomId);
    }

    /*//////////////////////////////////////////////////////////////////////////
            claimAtomWalletDepositFees — no fees => no transfer, no revert
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAtomWalletDepositFees_NoFees_NoOp() public {
        // Arrange: deposit exactly atomCost => assetsAfterFixedFees = 0 => fee = 0
        bytes32 atomId = createSimpleAtom("no-fees-atom", ATOM_COST[0], users.alice);

        // Install wallet mock with Alice as owner
        address walletAddr = _installAtomWalletMock(atomId, users.alice);

        // Sanity: accumulator is zero
        assertEq(protocol.multiVault.accumulatedAtomWalletDepositFees(walletAddr), 0, "should be zero pre-claim");

        // Act: claim — should do nothing & not revert
        uint256 ownerBalBefore = users.alice.balance;
        resetPrank(walletAddr);
        protocol.multiVault.claimAtomWalletDepositFees(atomId);

        // Assert: still zero, owner's balance unchanged
        assertEq(protocol.multiVault.accumulatedAtomWalletDepositFees(walletAddr), 0, "still zero after claim");
        assertEq(users.alice.balance, ownerBalBefore, "no transfer when no fees");
    }

    /*//////////////////////////////////////////////////////////////////////////
                 sweepAccumulatedProtocolFees — happy path
    //////////////////////////////////////////////////////////////////////////*/

    function test_sweepAccumulatedProtocolFees_TransfersAndZeros() public {
        // Arrange: current epoch
        uint256 epoch = protocol.multiVault.currentEpoch();

        // Create a single atom with EXACT atom cost so dynamic protocol fees = 0,
        // but static atomCreationProtocolFee is accrued to accumulatedProtocolFees[epoch].
        createSimpleAtom("protocol-fee-atom", ATOM_COST[0], users.charlie);

        // Read accumulated amount
        uint256 accrued = protocol.multiVault.accumulatedProtocolFees(epoch);
        assertGt(accrued, 0, "expected static protocol fee accrued");

        // Destination is protocol multisig (admin in BaseTest generalConfig)
        address multisig = protocol.multiVault.getGeneralConfig().protocolMultisig;

        uint256 beforeMultisigBal = multisig.balance;

        // Act
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeeTransferred(epoch, multisig, accrued);
        protocol.multiVault.sweepAccumulatedProtocolFees(epoch);

        // Assert: mapping zeroed and multisig funded
        assertEq(protocol.multiVault.accumulatedProtocolFees(epoch), 0, "accumulated fees should be zero");
        assertEq(multisig.balance, beforeMultisigBal + accrued, "multisig should receive swept fees");
    }

    /*//////////////////////////////////////////////////////////////////////////
              sweepAccumulatedProtocolFees — no-op when zero
    //////////////////////////////////////////////////////////////////////////*/

    function test_sweepAccumulatedProtocolFees_NoOpWhenZero() public {
        // Pick a fresh epoch number with no accruals (or just current if we ensure zero)
        uint256 epoch = protocol.multiVault.currentEpoch();

        // Ensure zero: if something already accrued earlier in the test run, sweep it once
        uint256 pre = protocol.multiVault.accumulatedProtocolFees(epoch);
        if (pre > 0) {
            protocol.multiVault.sweepAccumulatedProtocolFees(epoch);
            assertEq(protocol.multiVault.accumulatedProtocolFees(epoch), 0, "should be zero after setup sweep");
        }

        // No revert and no transfer expected
        uint256 multisigBalBefore = protocol.multiVault.getGeneralConfig().protocolMultisig.balance;
        protocol.multiVault.sweepAccumulatedProtocolFees(epoch);
        assertEq(
            protocol.multiVault.getGeneralConfig().protocolMultisig.balance,
            multisigBalBefore,
            "no transfer when nothing accrued"
        );
    }
}
