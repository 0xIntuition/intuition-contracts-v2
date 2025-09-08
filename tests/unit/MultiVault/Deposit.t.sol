// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Test } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { GeneralConfig, BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";

contract DepositTest is BaseTest {
    uint256 internal CURVE_ID; // Default linear curve ID
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATH TESTS
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        // Ensure the bonding curve registry is set up
        CURVE_ID = getDefaultCurveId();
    }

    function test_deposit_SingleAtom_Success() public {
        bytes32 atomId = createSimpleAtom("Deposit test atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 10e18;
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, depositAmount, 1e4);

        assertTrue(shares > 0, "Should receive some shares");

        uint256 vaultBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(vaultBalance, shares, "Vault balance should match shares received");
    }

    function test_deposit_MultipleDeposits_Success() public {
        bytes32 atomId = createSimpleAtom("Multi deposit atom", ATOM_COST[0], users.alice);

        uint256 firstShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 50e18, 1e4);
        uint256 secondShares = makeDeposit(users.alice, users.alice, atomId, CURVE_ID, 30e18, 1e4);

        assertTrue(firstShares > 0, "First deposit should receive shares");
        assertTrue(secondShares > 0, "Second deposit should receive shares");

        uint256 totalVaultBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(totalVaultBalance, firstShares + secondShares, "Total balance should equal sum of deposits");
    }

    function test_deposit_DifferentReceivers_Success() public {
        bytes32 atomId = createSimpleAtom("Different receivers atom", ATOM_COST[0], users.alice);

        setupApproval(users.bob, users.alice, IMultiVault.ApprovalTypes.BOTH);

        uint256 shares = makeDeposit(users.alice, users.bob, atomId, CURVE_ID, 10e18, 1e4);

        uint256 bobBalance = protocol.multiVault.getShares(users.bob, atomId, CURVE_ID);
        assertEq(bobBalance, shares, "Bob should receive the shares");

        uint256 aliceBalance = protocol.multiVault.getShares(users.alice, atomId, CURVE_ID);
        assertEq(aliceBalance, 0, "Alice should not receive shares");
    }

    function test_deposit_ToTriple_Success() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("Subject", "Predicate", "Object", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        uint256 shares = makeDeposit(users.alice, users.alice, tripleId, CURVE_ID, 2000e18, 1e4);

        assertTrue(shares > 0, "Should receive shares for triple deposit");

        uint256 vaultBalance = protocol.multiVault.getShares(users.alice, tripleId, CURVE_ID);
        assertEq(vaultBalance, shares, "Triple vault balance should match shares");
    }

    /*//////////////////////////////////////////////////////////////
                            ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_deposit_InsufficientAssets_Revert() public {
        bytes32 atomId = createSimpleAtom("Insufficient deposit atom", ATOM_COST[0], users.alice);

        resetPrank(users.alice);
        vm.expectRevert();
        protocol.multiVault.deposit{ value: 0 }(users.alice, atomId, CURVE_ID, 0);
    }

    function test_deposit_NonExistentTerm_Revert() public {
        bytes32 nonExistentId = keccak256("non-existent");
        uint256 depositAmount = 1000e18;

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_TermDoesNotExist.selector);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, nonExistentId, CURVE_ID, 0);
    }

    function test_deposit_MinSharesToReceive_Revert() public {
        bytes32 atomId = createSimpleAtom("Min shares atom", ATOM_COST[0], users.alice);

        uint256 depositAmount = 100e18;
        uint256 unreasonableMinShares = 10_000_000e18; // Way too high

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SlippageExceeded.selector);
        protocol.multiVault.deposit{ value: depositAmount }(users.alice, atomId, CURVE_ID, unreasonableMinShares);
    }

    /*//////////////////////////////////////////////////////////////
            TRIPLE: cannot directly init counter triple (non-default)
    //////////////////////////////////////////////////////////////*/

    function test_deposit_RevertWhen_CannotInitializeCounterTriple_OnNonDefaultCurve() public {
        // Create a positive triple on the default curve (counter is auto-initialized only on default)
        (bytes32 tripleId,) =
            createTripleWithAtoms("S-ctr", "P-ctr", "O-ctr", ATOM_COST[0], TRIPLE_COST[0], users.alice);

        // Get the counter triple id
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        // Choose a non-default curve (brand-new vault for counter side)
        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        // Try to deposit to the counter triple on a non-default curve => forbidden
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_CannotDirectlyInitializeCounterTriple.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, counterId, nonDefaultCurve, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        APPROVE() BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_approve_RevertWhen_SelfApprove() public {
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_CannotApproveOrRevokeSelf.selector);
        protocol.multiVault.approve(users.alice, IMultiVault.ApprovalTypes.BOTH);
    }

    function test_approve_DeleteApproval_RemovesAccess() public {
        // Prepare a live atom
        bytes32 atomId = createSimpleAtom("approval-delete-atom", ATOM_COST[0], users.bob);

        // Bob (receiver) approves Alice (sender)
        setupApproval(users.bob, users.alice, IMultiVault.ApprovalTypes.BOTH);

        // First deposit from Alice -> Bob succeeds
        uint256 amount1 = 1 ether;
        uint256 shares1 = makeDeposit(users.alice, users.bob, atomId, CURVE_ID, amount1, 0);
        assertGt(shares1, 0);

        // Bob revokes approval by setting NONE (deletes mapping entry)
        resetPrank(users.bob);
        protocol.multiVault.approve(users.alice, IMultiVault.ApprovalTypes.NONE);

        // Second deposit from Alice -> Bob now reverts with SenderNotApproved
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_SenderNotApproved.selector);
        protocol.multiVault.deposit{ value: 0.5 ether }(users.bob, atomId, CURVE_ID, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         SENDER NOT APPROVED
    //////////////////////////////////////////////////////////////*/

    function test_deposit_RevertWhen_SenderNotApproved() public {
        // Alice creates atom she will receive into
        bytes32 atomId = createSimpleAtom("sender-not-approved-atom", ATOM_COST[0], users.alice);

        // Bob tries to deposit to Alice without approval
        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_SenderNotApproved.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);
    }

    /*//////////////////////////////////////////////////////////////
                       DEPOSIT BATCH INVALID LENGTH
    //////////////////////////////////////////////////////////////*/

    function test_depositBatch_RevertWhen_InvalidArrayLengthZero() public {
        resetPrank(users.alice);
        bytes32[] memory termIds = new bytes32[](0);
        uint256[] memory curveIds = new uint256[](1);
        curveIds[0] = CURVE_ID;
        uint256[] memory assets = new uint256[](1);
        assets[0] = 1 ether;
        uint256[] memory minShares = new uint256[](1);
        minShares[0] = 0;

        vm.expectRevert(MultiVault.MultiVault_InvalidArrayLength.selector);
        protocol.multiVault.depositBatch{ value: 1 ether }(users.alice, termIds, curveIds, assets, minShares);
    }

    /*//////////////////////////////////////////////////////////////
            DEFAULT CURVE MUST BE INITIALIZED VIA CREATE PATHS
    //////////////////////////////////////////////////////////////*/

    function test_deposit_RevertWhen_DefaultCurveMustBeInitializedViaCreatePaths() public {
        // Create an atom while default curve is current CURVE_ID (e.g., 1)
        bytes32 atomId = createSimpleAtom("default-curve-guard-atom", ATOM_COST[0], users.alice);

        // Flip the protocol's default curve id to the OTHER curve
        // (so for this term, the new default curve vault is uninitialized)
        (address registry, uint256 oldDefault) = protocol.multiVault.bondingCurveConfig();
        uint256 newDefault = oldDefault == 1 ? 2 : 1;

        resetPrank(users.admin);
        protocol.multiVault.setBondingCurveConfig(
            BondingCurveConfig({ registry: registry, defaultCurveId: newDefault })
        );

        // Now try to deposit into the *new* default curve for this atom
        // That new default curve vault is brand-new (no shares), so this should revert
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveMustBeInitializedViaCreatePaths.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, newDefault, 0);

        // Restore default to keep other tests deterministic (optional)
        resetPrank(users.admin);
        protocol.multiVault.setBondingCurveConfig(
            BondingCurveConfig({ registry: registry, defaultCurveId: oldDefault })
        );
    }

    /*//////////////////////////////////////////////////////////////
                MIN SHARE COST BLOCK (NON-DEFAULT NEW VAULTS)
    //////////////////////////////////////////////////////////////*/

    function test_deposit_RevertWhen_AtomMinShareTooSmall_OnNonDefaultNewVault() public {
        // Create atom on default curve only
        bytes32 atomId = createSimpleAtom("atom-minshare-too-small", ATOM_COST[0], users.alice);

        // choose non-default curve id
        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        // For atom, minShareCost = minShare
        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;

        resetPrank(users.admin);
        // Set minDeposit to very small value to isolate the test case
        protocol.multiVault.setGeneralConfig(_getGeneralConfigWithVerySmallMinDeposit());

        // Amount <= minShare should revert with MultiVault_DepositTooSmallToCoverMinShares
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositTooSmallToCoverMinShares.selector);
        protocol.multiVault.deposit{ value: minShare }(users.alice, atomId, nonDefaultCurve, 0);
    }

    function test_deposit_AtomNonDefaultNewVault_SubtractsMinShareAndSucceeds() public {
        bytes32 atomId = createSimpleAtom("atom-minshare-succeeds", ATOM_COST[0], users.alice);

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        uint256 amount = minShare + 2 ether;

        // Should succeed and mint some shares
        uint256 shares = makeDeposit(users.alice, users.alice, atomId, nonDefaultCurve, amount, 0);
        assertGt(shares, 0, "Expected some shares after subtracting minShare base");
    }

    function test_deposit_RevertWhen_TripleMinShareTooSmall_OnNonDefaultNewVault() public {
        // Create a real triple (default curve initialized for both triple & counter)
        (bytes32 tripleId,) = createTripleWithAtoms(
            "s-ms-too-small", "p-ms-too-small", "o-ms-too-small", ATOM_COST[0], TRIPLE_COST[0], users.alice
        );

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        // For triple (or counter), minShareCost = 2 * minShare
        uint256 minShare2x = protocol.multiVault.getGeneralConfig().minShare * 2;

        resetPrank(users.admin);
        // Set minDeposit to very small value to isolate the test case
        protocol.multiVault.setGeneralConfig(_getGeneralConfigWithVerySmallMinDeposit());

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositTooSmallToCoverMinShares.selector);
        protocol.multiVault.deposit{ value: minShare2x }(users.alice, tripleId, nonDefaultCurve, 0);
    }

    function test_deposit_TripleNonDefaultNewVault_Subtracts2xMinShareAndSucceeds() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("s-ms-ok", "p-ms-ok", "o-ms-ok", ATOM_COST[0], TRIPLE_COST[0], users.bob);

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        uint256 minShare2x = protocol.multiVault.getGeneralConfig().minShare * 2;
        uint256 amount = minShare2x + 3 ether;

        uint256 shares = makeDeposit(users.bob, users.bob, tripleId, nonDefaultCurve, amount, 0);
        assertGt(shares, 0, "Expected shares after subtracting 2*minShare base");
    }

    function test_deposit_RevertWhen_AssetsBelowMinDeposit() public {
        bytes32 atomId = createSimpleAtom("min-deposit-guard", ATOM_COST[0], users.alice);

        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DepositBelowMinimumDeposit.selector);
        protocol.multiVault.deposit{ value: 0 }(users.alice, atomId, CURVE_ID, 0);
    }

    /*//////////////////////////////////////////////////////////////
                 INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getGeneralConfigWithVerySmallMinDeposit() internal view returns (GeneralConfig memory) {
        GeneralConfig memory gc = _getDefaultGeneralConfig();
        gc.minDeposit = 1; // Set to very small value for testing
        gc.trustBonding = protocol.multiVault.getGeneralConfig().trustBonding; // Preserve existing TrustBonding setting
        return gc;
    }
}
