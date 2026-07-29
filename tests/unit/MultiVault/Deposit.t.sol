// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Test, console } from "forge-std/src/Test.sol";

import { BaseTest } from "tests/BaseTest.t.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { MultiVaultCore } from "src/protocol/MultiVaultCore.sol";
import { IMultiVault, ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { GeneralConfig, BondingCurveConfig, VaultFees } from "src/interfaces/IMultiVaultCore.sol";

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

        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);

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
        vm.expectRevert(abi.encodeWithSelector(MultiVaultCore.MultiVaultCore_TermDoesNotExist.selector, nonExistentId));
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

    function test_deposit_RevertWhen_CurveRoundsToZeroShares() public {
        bytes32 atomId = createSimpleAtom("Zero shares atom", ATOM_COST[0], users.alice);
        (address registry,) = protocol.multiVault.bondingCurveConfig();
        vm.mockCall(registry, abi.encodeWithSelector(IBondingCurveRegistry.previewDeposit.selector), abi.encode(0));

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_DepositOrRedeemZeroShares.selector));
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);
        vm.clearMockedCalls();
    }

    function test_deposit_RevertWhen_ProjectedAssetsExceedCurveMaximum() public {
        bytes32 atomId = createSimpleAtom("Max assets atom", ATOM_COST[0], users.alice);
        (address registry,) = protocol.multiVault.bondingCurveConfig();
        vm.mockCall(
            registry, abi.encodeWithSelector(IBondingCurveRegistry.previewDeposit.selector), abi.encode(1 ether)
        );
        vm.mockCall(registry, abi.encodeWithSelector(IBondingCurveRegistry.getCurveMaxAssets.selector), abi.encode(0));

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ActionExceedsMaxAssets.selector));
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);
        vm.clearMockedCalls();
    }

    function test_deposit_RevertWhen_ProjectedSharesExceedCurveMaximum() public {
        bytes32 atomId = createSimpleAtom("Max shares atom", ATOM_COST[0], users.alice);
        (address registry,) = protocol.multiVault.bondingCurveConfig();
        vm.mockCall(
            registry, abi.encodeWithSelector(IBondingCurveRegistry.previewDeposit.selector), abi.encode(1 ether)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IBondingCurveRegistry.getCurveMaxAssets.selector),
            abi.encode(type(uint256).max)
        );
        vm.mockCall(registry, abi.encodeWithSelector(IBondingCurveRegistry.getCurveMaxShares.selector), abi.encode(0));

        resetPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_ActionExceedsMaxShares.selector));
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);
        vm.clearMockedCalls();
    }

    /*//////////////////////////////////////////////////////////////
        TRIPLE: counter-triple deposit on non-default curve (symmetric)
    //////////////////////////////////////////////////////////////*/

    /// @notice First-deposit on a counter-triple's non-default-curve vault must succeed once the
    ///         counter-triple's default-curve vault has been seeded by triple creation. The opposite
    ///         (positive) side same-curve vault is bootstrapped with min-shares burned to the
    ///         BURN_ADDRESS, mirroring the existing positive-first symmetric bootstrap.
    function test_deposit_CounterTripleNonDefault_BootstrapsOppositeSide() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("S-ctr", "P-ctr", "O-ctr", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        uint256 nonDefaultCurve = defaultCurveId == 1 ? 2 : 1;

        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        uint256 amount = 5 ether;

        // Counter-first deposit on a non-default curve (previously reverted).
        uint256 shares = makeDeposit(users.bob, users.bob, counterId, nonDefaultCurve, amount, 0);
        assertGt(shares, 0, "counter-first deposit should mint shares");

        // Counter vault on the non-default curve holds bob's shares plus the min-share seed for itself.
        // The min-share seed for the counter side is the same minShare burned to BURN_ADDRESS as the
        // calc path's _isNewVault branch deducted from assetsAfterMinSharesCost.
        (, uint256 counterTotalShares) = protocol.multiVault.getVault(counterId, nonDefaultCurve);
        assertEq(counterTotalShares, shares + minShare, "counter non-default totalShares == bob + minShare seed");
        assertEq(
            protocol.multiVault.getShares(users.bob, counterId, nonDefaultCurve),
            shares,
            "bob holds his minted counter shares"
        );

        // Opposite-side (positive) vault on the same non-default curve was seeded symmetrically.
        (uint256 posTotalAssets, uint256 posTotalShares) = protocol.multiVault.getVault(tripleId, nonDefaultCurve);
        assertEq(posTotalShares, minShare, "positive non-default totalShares == minShare seed");
        assertGt(posTotalAssets, 0, "positive non-default totalAssets seeded with minAssetsForCurve(minShare)");
        assertEq(
            protocol.multiVault.getShares(protocol.multiVault.BURN_ADDRESS(), tripleId, nonDefaultCurve),
            minShare,
            "BURN_ADDRESS holds the positive-side seed"
        );
        assertEq(
            protocol.multiVault.getShares(users.bob, tripleId, nonDefaultCurve), 0, "bob holds no positive-side shares"
        );
    }

    /// @notice Pins the surviving boundary of the counter-triple guard: once the positive-triple
    ///         create path has seeded the counter-triple's default-curve vault, a follow-up deposit
    ///         into that same counter-default vault must succeed — the tightened guard recognises
    ///         the term as already bootstrapped and does not fire. The genuine direct-init attack
    ///         path (depositing on counter-default when the term has not been created) is
    ///         unreachable because the term would not be classified as a counter-triple at all.
    function test_deposit_CounterTripleDefault_AfterBootstrap_Succeeds() public {
        (bytes32 tripleId,) =
            createTripleWithAtoms("S-def-ctr", "P-def-ctr", "O-def-ctr", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        uint256 minShare2x = protocol.multiVault.getGeneralConfig().minShare * 2;
        uint256 amount = minShare2x + 2 ether;
        uint256 shares = makeDeposit(users.bob, users.bob, counterId, CURVE_ID, amount, 0);
        assertGt(shares, 0, "counter-default deposit after creation must succeed");
    }

    /*//////////////////////////////////////////////////////////////
        FUZZ: counter-triple non-default symmetric bootstrap
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz over registered non-default curves and asset amounts: counter-first deposit on a
    ///         non-default curve must succeed and seed the opposite-side vault with min-shares to
    ///         BURN_ADDRESS, regardless of which non-default curve is used or how much is deposited.
    function testFuzz_deposit_CounterTripleNonDefault_BootstrapsOpposite(uint256 assets, uint256 curveSeed) public {
        uint256 nonDefaultCurve = _pickNonDefaultCurveFromSeed(curveSeed);
        vm.assume(nonDefaultCurve != 0);

        (bytes32 tripleId,) = createTripleWithAtoms("S-fz", "P-fz", "O-fz", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        uint256 minShare = protocol.multiVault.getGeneralConfig().minShare;
        assets = bound(assets, _minAssetsForBootstrap(minShare), 1e30);

        vm.deal(users.bob, assets);
        uint256 shares = makeDeposit(users.bob, users.bob, counterId, nonDefaultCurve, assets, 0);
        assertGt(shares, 0, "fuzz: counter-first deposit must mint shares");

        (, uint256 counterTotalShares) = protocol.multiVault.getVault(counterId, nonDefaultCurve);
        assertEq(counterTotalShares, shares + minShare, "fuzz: counter totalShares == user + minShare seed");

        (, uint256 posTotalShares) = protocol.multiVault.getVault(tripleId, nonDefaultCurve);
        assertEq(posTotalShares, minShare, "fuzz: positive totalShares == minShare seed");
        assertEq(
            protocol.multiVault.getShares(protocol.multiVault.BURN_ADDRESS(), tripleId, nonDefaultCurve),
            minShare,
            "fuzz: BURN_ADDRESS holds positive-side seed"
        );
    }

    /// @notice Fuzz: {previewDeposit} must agree with the actual shares minted by {deposit} for the
    ///         counter-first non-default path. Guards against preview/exec divergence after the
    ///         symmetric guard tightening across the execution and calc paths.
    function testFuzz_deposit_CounterTripleNonDefault_PreviewMatchesExecution(uint256 assets, uint256 curveSeed)
        public
    {
        uint256 nonDefaultCurve = _pickNonDefaultCurveFromSeed(curveSeed);
        vm.assume(nonDefaultCurve != 0);

        (bytes32 tripleId,) = createTripleWithAtoms("S-pf", "P-pf", "O-pf", ATOM_COST[0], TRIPLE_COST[0], users.alice);
        bytes32 counterId = protocol.multiVault.getCounterIdFromTripleId(tripleId);

        assets = bound(assets, _minAssetsForBootstrap(protocol.multiVault.getGeneralConfig().minShare), 1e30);
        (uint256 previewShares,) = protocol.multiVault.previewDeposit(counterId, nonDefaultCurve, assets);

        vm.deal(users.bob, assets);
        uint256 actualShares = makeDeposit(users.bob, users.bob, counterId, nonDefaultCurve, assets, 0);
        assertEq(actualShares, previewShares, "previewDeposit must match shares minted by deposit");
    }

    function _pickNonDefaultCurveFromSeed(uint256 curveSeed) internal view returns (uint256) {
        (address registryAddr, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        IBondingCurveRegistry reg = IBondingCurveRegistry(registryAddr);
        uint256 count = reg.count();
        if (count <= 1) return 0;
        uint256 start = (curveSeed % count) + 1;
        for (uint256 i = 0; i < count; i++) {
            uint256 cid = ((start + i - 1) % count) + 1;
            if (cid != defaultCurveId && reg.curveAddresses(cid) != address(0)) {
                return cid;
            }
        }
        return 0;
    }

    /// @dev Floor for fuzz `assets`: must clear both `minDeposit` and the 2*minShare bootstrap cost
    ///      that the triple calc path deducts from `assetsAfterMinSharesCost` for a new vault.
    function _minAssetsForBootstrap(uint256 minShare) internal view returns (uint256) {
        uint256 minDeposit = protocol.multiVault.getGeneralConfig().minDeposit;
        uint256 floor = minShare * 2 + 1;
        return minDeposit > floor ? minDeposit : floor;
    }

    /*//////////////////////////////////////////////////////////////
                        APPROVE() BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_approve_RevertWhen_SelfApprove() public {
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_CannotApproveOrRevokeSelf.selector);
        protocol.multiVault.approve(users.alice, ApprovalTypes.BOTH);
    }

    function test_isApprovedToDeposit_MirrorsDepositBitApproval() public {
        assertTrue(protocol.multiVault.isApprovedToDeposit(users.alice, users.alice), "self is approved");
        assertFalse(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "default false");

        setupApproval(users.bob, users.alice, ApprovalTypes.CREATION);
        assertFalse(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "creation only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.REDEMPTION);
        assertFalse(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "redemption only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);
        assertTrue(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "both true");

        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT_AND_CREATION);
        assertTrue(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "deposit and creation true");

        setupApproval(users.bob, users.alice, ApprovalTypes.ALL);
        assertTrue(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "all true");

        setupApproval(users.bob, users.alice, ApprovalTypes.NONE);
        assertFalse(protocol.multiVault.isApprovedToDeposit(users.alice, users.bob), "none deletes approval");
    }

    function test_isApprovedToRedeem_MirrorsRedemptionBitApproval() public {
        assertTrue(protocol.multiVault.isApprovedToRedeem(users.alice, users.alice), "self is approved");
        assertFalse(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "default false");

        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT);
        assertFalse(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "deposit only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.CREATION);
        assertFalse(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "creation only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);
        assertTrue(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "both true");

        setupApproval(users.bob, users.alice, ApprovalTypes.REDEMPTION_AND_CREATION);
        assertTrue(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "redemption and creation true");

        setupApproval(users.bob, users.alice, ApprovalTypes.ALL);
        assertTrue(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "all true");

        setupApproval(users.bob, users.alice, ApprovalTypes.NONE);
        assertFalse(protocol.multiVault.isApprovedToRedeem(users.alice, users.bob), "none deletes approval");
    }

    function test_isApprovedToCreate_MirrorsCreationBitApproval() public {
        assertTrue(protocol.multiVault.isApprovedToCreate(users.alice, users.alice), "self is approved");
        assertFalse(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "default false");

        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT);
        assertFalse(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "deposit only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.REDEMPTION);
        assertFalse(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "redemption only false");

        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);
        assertFalse(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "both false");

        setupApproval(users.bob, users.alice, ApprovalTypes.CREATION);
        assertTrue(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "creation true");

        setupApproval(users.bob, users.alice, ApprovalTypes.DEPOSIT_AND_CREATION);
        assertTrue(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "deposit and creation true");

        setupApproval(users.bob, users.alice, ApprovalTypes.REDEMPTION_AND_CREATION);
        assertTrue(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "redemption and creation true");

        setupApproval(users.bob, users.alice, ApprovalTypes.ALL);
        assertTrue(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "all true");

        setupApproval(users.bob, users.alice, ApprovalTypes.NONE);
        assertFalse(protocol.multiVault.isApprovedToCreate(users.alice, users.bob), "none deletes approval");
    }

    function test_approve_DeleteApproval_RemovesAccess() public {
        // Prepare a live atom
        bytes32 atomId = createSimpleAtom("approval-delete-atom", ATOM_COST[0], users.bob);

        // Bob (receiver) approves Alice (sender)
        setupApproval(users.bob, users.alice, ApprovalTypes.BOTH);

        // First deposit from Alice -> Bob succeeds
        uint256 amount1 = 1 ether;
        uint256 shares1 = makeDeposit(users.alice, users.bob, atomId, CURVE_ID, amount1, 0);
        assertGt(shares1, 0);

        // Bob revokes approval by setting NONE (deletes mapping entry)
        resetPrank(users.bob);
        protocol.multiVault.approve(users.alice, ApprovalTypes.NONE);

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
                  NEW ApprovalTypes VALUE COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_deposit_AllowedWith_DepositAndCreationApproval() public {
        // DEPOSIT_AND_CREATION = 0b101 must satisfy the DEPOSIT bit check.
        bytes32 atomId = createSimpleAtom("deposit-and-creation-allows-deposit", ATOM_COST[0], users.alice);

        setupApproval(users.alice, users.bob, ApprovalTypes.DEPOSIT_AND_CREATION);

        uint256 shares = makeDeposit(users.bob, users.alice, atomId, CURVE_ID, 1 ether, 0);
        assertGt(shares, 0, "DEPOSIT_AND_CREATION must grant deposit");
    }

    function test_deposit_AllowedWith_AllApproval() public {
        // ALL = 0b111 must satisfy DEPOSIT.
        bytes32 atomId = createSimpleAtom("all-approval-allows-deposit", ATOM_COST[0], users.alice);

        setupApproval(users.alice, users.bob, ApprovalTypes.ALL);

        uint256 shares = makeDeposit(users.bob, users.alice, atomId, CURVE_ID, 1 ether, 0);
        assertGt(shares, 0, "ALL must grant deposit");
    }

    function test_deposit_RevertWhen_OnlyCreationApproval() public {
        // CREATION = 0b100 must NOT satisfy the DEPOSIT bit check.
        bytes32 atomId = createSimpleAtom("creation-only-blocks-deposit", ATOM_COST[0], users.alice);

        setupApproval(users.alice, users.bob, ApprovalTypes.CREATION);

        resetPrank(users.bob);
        vm.expectRevert(MultiVault.MultiVault_SenderNotApproved.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, CURVE_ID, 0);
    }

    function test_deposit_RevertWhen_OnlyRedemptionAndCreationApproval() public {
        // REDEMPTION_AND_CREATION = 0b110 has no DEPOSIT bit.
        bytes32 atomId = createSimpleAtom("rc-blocks-deposit", ATOM_COST[0], users.alice);

        setupApproval(users.alice, users.bob, ApprovalTypes.REDEMPTION_AND_CREATION);

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

        resetPrank(users.timelock);
        protocol.multiVault
            .setBondingCurveConfig(BondingCurveConfig({ registry: registry, defaultCurveId: newDefault }));

        // Now try to deposit into the *new* default curve for this atom
        // That new default curve vault is brand-new (no shares), so this should revert
        resetPrank(users.alice);
        vm.expectRevert(MultiVault.MultiVault_DefaultCurveMustBeInitializedViaCreatePaths.selector);
        protocol.multiVault.deposit{ value: 1 ether }(users.alice, atomId, newDefault, 0);

        // Restore default to keep other tests deterministic (optional)
        resetPrank(users.timelock);
        protocol.multiVault
            .setBondingCurveConfig(BondingCurveConfig({ registry: registry, defaultCurveId: oldDefault }));
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

        resetPrank(users.timelock);
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

        resetPrank(users.timelock);
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

contract DefaultCurveEntryFeeImpactTest is BaseTest {
    uint256 internal DEFAULT_CURVE_ID;
    uint256 internal NON_DEFAULT_CURVE_ID; // offset progressive = 2 in our setup

    function setUp() public override {
        super.setUp();

        (, uint256 defaultCurveId) = protocol.multiVault.bondingCurveConfig();
        DEFAULT_CURVE_ID = defaultCurveId; // expected 1 (linear)
        NON_DEFAULT_CURVE_ID = 2; // expected 2 (offset progressive)
    }

    /// Proves: first deposit on a brand-new non-default vault waives entry fee,
    /// so default curve does NOT accrue fee on that first deposit.
    function test_defaultCurve_NoFeeOnFirstNonDefaultDeposit() public {
        // Create atom with only atomCost -> default curve vault has only minShare assets&shares
        bytes32 atomId = createSimpleAtom("atom-fee-first", ATOM_COST[0], users.alice);

        // Snapshot default vault state
        (uint256 defAssetsBefore, uint256 defSharesBefore) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
        uint256 priceBefore = protocol.multiVault.currentSharePrice(atomId, DEFAULT_CURVE_ID);

        // 1st non-default deposit (isNew = true on curveId=2) -> entry fee waived
        uint256 firstAmt = 5 ether;
        makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, firstAmt, 0);

        // Default vault must be unchanged
        (uint256 defAssetsAfter, uint256 defSharesAfter) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
        uint256 priceAfter = protocol.multiVault.currentSharePrice(atomId, DEFAULT_CURVE_ID);

        assertEq(defSharesAfter, defSharesBefore, "default shares should not change on first non-default deposit");
        assertEq(defAssetsAfter, defAssetsBefore, "default assets should not change on first non-default deposit");
        assertEq(priceAfter, priceBefore, "default price unchanged on first non-default deposit");
    }

    /// Proves: subsequent non-default deposits *do* drip entry fee into default curve,
    /// increasing default assets (not shares), raising price and reducing shares/asset on default curve.
    function test_defaultCurve_FeeDripFromSubsequentNonDefaultDeposits() public {
        vm.stopPrank();
        // Switch the fee threshold to 0 to ensure all fees drip immediately -this proves that the share price grows
        // much more than expected (not an issue from the technical standpoint, but may lead to bad UX in practice)
        _setFeeThreshold(0);

        bytes32 atomId = createSimpleAtom("atom-fee-next", ATOM_COST[0], users.alice);

        // Initialize the non-default vault with a first deposit (no entry fee)
        makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, 3 ether, 0);

        // Baselines on the default curve
        (uint256 defAssets0, uint256 defShares0) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
        uint256 previewFixedAssets = 10 ether;
        (uint256 sharesBefore,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, previewFixedAssets);

        // 2nd non-default deposit (now isNew=false) -> entry fee applies and drips to default
        uint256 secondAmt = 20 ether;
        makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, secondAmt, 0);

        (uint256 defAssets1, uint256 defShares1) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);

        // expected fee drip = ceil(secondAmt * entryFeeBps / feeDenominator)
        (uint256 entryFeeBps,, uint256 protocolFeeBps, uint256 feeDen) = _readVaultFees(); // we’ll write helper below
        // to fetch fees

        uint256 expectedDrip = _mulDivUp(secondAmt, entryFeeBps, feeDen);

        assertEq(defShares1, defShares0, "default shares remain constant");
        assertEq(defAssets1, defAssets0 + expectedDrip, "default assets increased by entry fee drip");

        // price (or more robustly: shares minted for fixed assets) should reflect it
        (uint256 sharesAfter,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, previewFixedAssets);
        assertLe(sharesAfter, sharesBefore, "default curve should mint <= shares for same assets after drip");
    }

    /// A simple staircase test: multiple non-default deposits add up linearly on the default
    /// curve’s assets, and previewed shares on default for a fixed asset amount is non-increasing.
    function test_defaultCurve_StaircaseIncreasingDeposits() public {
        vm.stopPrank();
        // Switch the fee threshold to 0 to ensure all fees drip immediately -this proves that the share price grows
        // much more than expected (not an issue from the technical standpoint, but may lead to bad UX in practice)
        _setFeeThreshold(0);

        bytes32 atomId = createSimpleAtom("atom-stair", ATOM_COST[0], users.alice);

        // prime non-default
        makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, 2 ether, 0);

        (uint256 entryFeeBps,,, uint256 feeDen) = _readVaultFees();

        // baseline on default
        (uint256 defAssetsBase, uint256 defSharesBase) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
        (uint256 sharesPrev,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, 1 ether);

        // deposit ladder on non-default
        uint256[4] memory ladder = [uint256(1 ether), 2 ether, 3 ether, 4 ether];

        uint256 expectedAdded = 0;
        for (uint256 i = 0; i < ladder.length; i++) {
            makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, ladder[i], 0);
            expectedAdded += _mulDivUp(ladder[i], entryFeeBps, feeDen);

            (uint256 defA, uint256 defS) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
            assertEq(defS, defSharesBase, "default shares stays constant throughout");
            assertEq(defA, defAssetsBase + expectedAdded, "default assets must equal base + sum(entry fees)");

            (uint256 sharesNow,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, 1 ether);
            assertLe(sharesNow, sharesPrev, "shares minted on default for same assets should be non-increasing");
            sharesPrev = sharesNow;
        }
    }

    function test_laddered_curve_deposits_simulation() public {
        vm.stopPrank();

        // create atom on default curve
        bytes32 atomId = createSimpleAtom("atom-stair", ATOM_COST[0], users.alice);

        // make a minimum deposit to initialize the non-default curve vault
        makeDeposit(
            users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, protocol.multiVault.getGeneralConfig().minDeposit, 0
        );

        // deposit ladder on non-default
        uint256[6] memory ladder = [uint256(1 ether), 10 ether, 50 ether, 100 ether, 500 ether, 1000 ether];

        // max share price that we want to see after all ladder deposits are made
        uint256 maxSharePriceAfterDepositLadder = 100 ether;

        uint256 expectedAdded = 0;
        for (uint256 i = 0; i < ladder.length; i++) {
            makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, ladder[i], 0);
            console.log(protocol.multiVault.currentSharePrice(atomId, NON_DEFAULT_CURVE_ID));
            assertLt(
                protocol.multiVault.currentSharePrice(atomId, NON_DEFAULT_CURVE_ID),
                maxSharePriceAfterDepositLadder,
                "share price exceeded max threshold"
            );
        }
    }

    /// For a sequence of non-default deposits:
    ///  - default curve’s totalAssets must equal minShare + sum(ceil(entryFee * amount)) excluding the first deposit
    ///  - previewed shares on the default curve for a fixed assets amount must be non-increasing
    function testFuzz_DefaultCurve_AccruesEntryFeeAndReducesSharesPerAsset(uint96[10] memory raw) public {
        vm.stopPrank();
        // Switch the fee threshold to 0 to ensure all fees drip immediately -this proves that the share price grows
        // much more than expected (not an issue from the technical standpoint, but may lead to bad UX in practice)
        _setFeeThreshold(0);

        bytes32 atomId = createSimpleAtom("atom-fuzz", ATOM_COST[0], users.alice);

        // prime non-default (no entry fee dripped)
        uint256 firstAmt = _sanitize(raw[0]);
        makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, firstAmt, 0);

        // snapshot default base
        (uint256 defAssetsBase, uint256 defSharesBase) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);

        uint256 feeDen = protocol.multiVault.getGeneralConfig().feeDenominator;
        (uint256 entryFeeBps,,) = protocol.multiVault.vaultFees();

        uint256 expectedAdded; // sum of subsequent fee drips
        uint256 previewAmt = 3 ether;
        (uint256 prevShares,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, previewAmt);

        for (uint256 i = 1; i < raw.length; i++) {
            uint256 amt = _sanitize(raw[i]);
            makeDeposit(users.alice, users.alice, atomId, NON_DEFAULT_CURVE_ID, amt, 0);
            expectedAdded += _mulDivUp(amt, entryFeeBps, feeDen);

            (uint256 defA, uint256 defS) = protocol.multiVault.getVault(atomId, DEFAULT_CURVE_ID);
            assertEq(defS, defSharesBase, "default shares immutable across non-default deposits");
            assertEq(defA, defAssetsBase + expectedAdded, "default assets == base + sum(drips)");

            (uint256 nowShares,) = protocol.multiVault.previewDeposit(atomId, DEFAULT_CURVE_ID, previewAmt);
            assertLe(nowShares, prevShares, "shares minted for same assets must be non-increasing");
            prevShares = nowShares;
        }
    }

    /* --------------------------- helpers --------------------------- */

    function _sanitize(uint96 x) internal view returns (uint256) {
        // keep deposits in a safe and meaningful band:
        //  >= minDeposit + minShare (to avoid min-share check on non-default new vault)
        //  and cap to avoid curve max-asset surprises in extreme fuzz
        uint256 min =
            protocol.multiVault.getGeneralConfig().minDeposit + protocol.multiVault.getGeneralConfig().minShare;
        uint256 capped = uint256(x) % (50 ether);
        if (capped < min) capped = min;
        return capped;
    }

    function _mulDivUp(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        return (a == 0 || b == 0) ? 0 : ((a * b) + (d - 1)) / d;
    }

    function _readVaultFees() internal view returns (uint256 entry, uint256 exit, uint256 protocolBps, uint256 den) {
        entry = protocol.multiVault.getVaultFees().entryFee; // 100
        exit = protocol.multiVault.getVaultFees().exitFee; // 100
        protocolBps = protocol.multiVault.getVaultFees().protocolFee; // 100
        den = protocol.multiVault.getGeneralConfig().feeDenominator; // 10_000
    }

    function _gc() internal view returns (GeneralConfig memory gc) {
        (
            address admin,
            address protocolMultisig,
            uint256 feeDenominator,
            address trustBonding,
            uint256 minDeposit,
            uint256 minShare,
            uint256 atomDataMaxLength,
            uint256 feeThreshold
        ) = protocol.multiVault.generalConfig();
        gc = GeneralConfig({
            admin: admin,
            protocolMultisig: protocolMultisig,
            feeDenominator: feeDenominator,
            trustBonding: trustBonding,
            minDeposit: minDeposit,
            minShare: minShare,
            atomDataMaxLength: atomDataMaxLength,
            feeThreshold: feeThreshold
        });
    }

    function _vf() internal view returns (VaultFees memory vf) {
        (uint256 entryFee, uint256 exitFee, uint256 protocolFee) = protocol.multiVault.vaultFees();
        vf = VaultFees({ entryFee: entryFee, exitFee: exitFee, protocolFee: protocolFee });
    }

    function _setFeeThreshold(uint256 newThreshold) internal {
        GeneralConfig memory gc = _gc();
        gc.feeThreshold = newThreshold;
        vm.prank(users.timelock);
        protocol.multiVault.setGeneralConfig(gc);
    }
}
