// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { IFeeProxy, FeeConfig, FeeGuard, AffiliateStats } from "src/interfaces/IFeeProxy.sol";
import { IMultiVault, ApprovalTypes } from "src/interfaces/IMultiVault.sol";
import {
    GeneralConfig,
    AtomConfig,
    TripleConfig,
    WalletConfig,
    VaultFees,
    BondingCurveConfig
} from "src/interfaces/IMultiVaultCore.sol";
import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";

/// @title  Refund-rejecting smart wallet
/// @notice Minimal contract account whose `receive` reverts, so a FeeProxy push refund to it fails and
///         falls back to the pull ledger.
contract RefundRejectingWallet {
    error RefundRejectingWallet_CallFailed(bytes returnData);

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory result) {
        bool success;
        (success, result) = target.call{ value: value }(data);
        if (!success) revert RefundRejectingWallet_CallFailed(result);
    }

    receive() external payable {
        revert("refund rejected");
    }
}

/// @title  Intuition Mainnet v1.1.0 Execution Replay
/// @author 0xIntuition
/// @notice Replays the exact scheduled v1.1.0 governance transactions against a fork of Intuition Mainnet
///         and checks the protocol both before and after them. The transactions are read from the committed
///         Safe TX-Builder batches and sent from the Admin Safe unmodified:
///         `02` (Upgrades Timelock `executeBatch`), `03` (`MultiVault.reinitialize`) and `04`
///         (`AtomWarden.reinitialize`).
/// @dev    `setUp` forks the latest block (or `FORK_BLOCK`), snapshots protocol state, opens a position under
///         the live pre-upgrade code, warps to the operation's ready time and executes the three batches.
///         Every `test_` function then checks one post-upgrade property against that shared state.
///         The DynamicFeeFlatPriceCurve and the AtomWarden / AtomWallet claim flows are out of scope.
/// @custom:upgrade v1.1.0
contract MainnetV110ExecutionReplayTest is Test {
    /* =================================================== */
    /*                Intuition Mainnet (1155)             */
    /* =================================================== */

    address internal constant ADMIN_SAFE = 0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb;
    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant PARAMETERS_TIMELOCK = 0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA;

    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant ATOM_WARDEN_PROXY = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;
    address internal constant ATOM_WALLET_BEACON = 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF;
    address internal constant LINEAR_CURVE_PROXY = 0xc3eFD5471dc63d74639725f381f9686e3F264366;
    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY = 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d;
    address internal constant BONDING_CURVE_REGISTRY = 0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930;
    address internal constant FEE_PROXY = 0x45B65BB9FFC4BC51C9e3a56902d9183dcff51B55;

    address internal constant NEW_MULTIVAULT_IMPL = 0x07BF05d767414B36AC9259E41DB06f1f3A1D7b5f;
    address internal constant NEW_TRUST_BONDING_IMPL = 0xf43A386d6c470f3e257Fa2E2ed2A46f7abeA635A;
    address internal constant NEW_ATOM_WARDEN_IMPL = 0xDcc38557B1DEE342e71e8ABD5C53b4B897C50A2f;
    address internal constant NEW_LINEAR_CURVE_IMPL = 0x513C1DF0C05420789d14EfA3321a36B627365780;
    address internal constant NEW_OFFSET_PROGRESSIVE_CURVE_IMPL = 0x4335582985700E17B639Ea52F2908DBD871FA85c;
    address internal constant NEW_ATOM_WALLET_IMPL = 0x0A33b2FdB41afd6344434759f34E5ce75285EB30;

    /// @dev Live TrustBonding position holder, used to exercise the account-level views.
    address internal constant TRUST_BONDING_HOLDER = 0x2649FFAf400Ba641Fde2c597531C3611Da320ABA;

    /// @dev Existing mainnet atom with live vaults on curves 1 and 2.
    bytes32 internal constant EXISTING_ATOM_ID = 0x91e9bee20bdb43148f8317405322ce7c1cf4c2c1b61228f914427d8779ff8a78;

    /// @dev The operation scheduled by batch `01`, and the timestamp at which it becomes executable.
    bytes32 internal constant UPGRADE_OPERATION_ID = 0x14ef8b48864623ccdcc4b12a4ef2b6e3878dc1e0da2db96889c9cb8b3f5a5044;
    uint256 internal constant UPGRADE_READY_AT = 1_793_116_567;

    /// @dev `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`.
    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    uint256 internal constant TRANSACTION_BASE_GAS = 21_000;
    uint256 internal constant ZERO_CALLDATA_BYTE_GAS = 4;
    uint256 internal constant NONZERO_CALLDATA_BYTE_GAS = 16;

    uint256 internal constant LINEAR_CURVE_ID = 1;
    uint256 internal constant OFFSET_PROGRESSIVE_CURVE_ID = 2;
    uint256 internal constant EXPECTED_CURVE_COUNT = 2;

    /* =================================================== */
    /*                    Safe batches                     */
    /* =================================================== */

    string internal constant BATCH_DIR = "script/intuition/v1.1.0/safe-txs/";
    string internal constant EXECUTE_FILE = "02-intuition-1155-upgrades-timelock-execute.json";
    string internal constant MULTIVAULT_REINIT_FILE = "03-intuition-1155-admin-safe-multivault-reinitialize.json";
    string internal constant ATOM_WARDEN_REINIT_FILE = "04-intuition-1155-admin-safe-atomwarden-reinitialize.json";
    string internal constant BATCH_CHAIN_ID = "1155";

    /* =================================================== */
    /*                   FeeProxy fixtures                 */
    /* =================================================== */

    uint256 internal constant BPS_DIVISOR = 10_000;
    uint256 internal constant EXPECTED_REGISTRATION_FEE = 100 ether;
    uint256 internal constant EXPECTED_MAX_FEE_BPS = 2000;
    uint256 internal constant EXPECTED_MAX_FIXED_FEE = 50 ether;

    uint256 internal constant AFFILIATE_DEPOSIT_BPS = 150;
    uint256 internal constant AFFILIATE_CREATION_BPS = 300;
    uint256 internal constant AFFILIATE_DEPOSIT_FIXED_FEE = 0.05 ether;
    uint256 internal constant AFFILIATE_CREATION_FIXED_FEE = 0.1 ether;

    /* =================================================== */
    /*                  AtomWarden fixtures                */
    /* =================================================== */

    /// @dev Signers are granted by a later batch, so the reinitialized warden has none yet.
    uint256 internal constant EXPECTED_SIGNER_COUNT_AFTER_REINIT = 0;

    /* =================================================== */
    /*                  Amounts and limits                 */
    /* =================================================== */

    uint256 internal constant LEGACY_DEPOSIT_AMOUNT = 5 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 3 ether;
    uint256 internal constant USER_FUNDING = 1000 ether;
    uint256 internal constant ATOM_EXTRA_ASSETS = 0.5 ether;
    uint256 internal constant TRIPLE_EXTRA_ASSETS = 1 ether;
    uint32 internal constant DEFAULT_MAX_URI_COUNT = 5;
    uint32 internal constant DEFAULT_MAX_URI_LENGTH = 700;

    struct VaultSnapshot {
        uint256 totalAssets;
        uint256 totalShares;
    }

    struct ProtocolSnapshot {
        uint256 totalTermsCreated;
        uint256 curveCount;
        uint256 epoch;
        VaultSnapshot linearVault;
        VaultSnapshot offsetProgressiveVault;
        address atomWallet;
        address admin;
        address registry;
        uint256 defaultCurveId;
        uint256 atomCost;
        uint256 tripleCost;
    }

    struct TrustBondingSnapshot {
        uint256 epoch;
        uint256 epochLength;
        uint256 totalLocked;
        uint256 totalBondedBalance;
        uint256 emissions;
        uint256 systemApy;
        uint256 systemMaxApy;
        uint256 holderApy;
        uint256 holderMaxApy;
    }

    struct RoutedDepositExpectation {
        uint256 grossAssets;
        uint256 affiliateFee;
        uint256 forwardedAssets;
        uint256 shares;
        uint256 epoch;
        int256 userUtilizationBefore;
        int256 proxyUtilizationBefore;
        uint256 userBalanceBefore;
        uint256 recipientBalanceBefore;
        uint256 proxyBalanceBefore;
    }

    struct ImplementationSet {
        address multiVault;
        address trustBonding;
        address atomWarden;
        address linearCurve;
        address offsetProgressiveCurve;
        address atomWallet;
    }

    MultiVault internal multiVault;
    IFeeProxy internal feeProxy;
    ITrustBonding internal trustBonding;
    IAtomWarden internal atomWarden;

    uint256 internal forkBlockNumber;
    uint256 internal forkTimestamp;
    uint256 internal executionTimestamp;

    /// @dev Taken first, before the pre-upgrade position is opened.
    ProtocolSnapshot internal initialSnapshot;
    /// @dev Taken immediately before batch `02`, after the pre-upgrade position is opened.
    ProtocolSnapshot internal preExecutionSnapshot;
    TrustBondingSnapshot internal preExecutionTrustBonding;

    address internal legacyDepositor;
    uint256 internal legacyLinearShares;
    uint256 internal legacyOffsetProgressiveShares;

    /// @dev MultiVault state read between batch `02` and batch `03` (new code, not yet reinitialized).
    address internal timelockBeforeReinitialize;
    uint256 internal lastSystemUtilizationEpochBeforeReinitialize;
    uint256 internal epochAtReinitialize;

    /// @dev Live implementations before batch `02`.
    ImplementationSet internal preUpgradeImplementations;

    function setUp() external {
        uint256 forkBlockOverride = vm.envOr("FORK_BLOCK", uint256(0));
        if (forkBlockOverride == 0) {
            vm.createSelectFork("intuition");
        } else {
            vm.createSelectFork("intuition", forkBlockOverride);
        }
        forkBlockNumber = vm.getBlockNumber();
        forkTimestamp = vm.getBlockTimestamp();

        multiVault = MultiVault(MULTIVAULT_PROXY);
        feeProxy = IFeeProxy(FEE_PROXY);
        trustBonding = ITrustBonding(TRUST_BONDING_PROXY);
        atomWarden = IAtomWarden(ATOM_WARDEN_PROXY);

        TimelockController upgradesTimelock = TimelockController(payable(UPGRADES_TIMELOCK));
        require(
            upgradesTimelock.isOperationPending(UPGRADE_OPERATION_ID),
            "upgrade operation is not pending on this fork: already executed, cancelled, or never scheduled"
        );
        require(
            upgradesTimelock.getTimestamp(UPGRADE_OPERATION_ID) == UPGRADE_READY_AT,
            "upgrade operation ready-at drifted"
        );
        require(multiVault.isTermCreated(EXISTING_ATOM_ID), "existing atom missing on fork");

        preUpgradeImplementations = _currentImplementations();
        _requireNoneUpgraded(preUpgradeImplementations);

        // 1. Snapshot first, under the live pre-upgrade code.
        initialSnapshot = _snapshotProtocol();

        // 2. Open a position under the pre-upgrade code on both curves.
        _openLegacyPosition();

        // 3. Wait out the timelock delay.
        if (vm.getBlockTimestamp() < UPGRADE_READY_AT) {
            vm.warp(UPGRADE_READY_AT);
        }
        executionTimestamp = vm.getBlockTimestamp();
        require(upgradesTimelock.isOperationReady(UPGRADE_OPERATION_ID), "upgrade operation not ready after warp");

        preExecutionSnapshot = _snapshotProtocol();
        preExecutionTrustBonding = _snapshotTrustBonding();

        // 4. Execute the scheduled batches exactly as committed, from the Admin Safe.
        _executeSafeBatch(EXECUTE_FILE);

        timelockBeforeReinitialize = multiVault.timelock();
        lastSystemUtilizationEpochBeforeReinitialize = multiVault.lastSystemUtilizationEpoch();
        epochAtReinitialize = multiVault.currentEpoch();

        _executeSafeBatch(MULTIVAULT_REINIT_FILE);
        _executeSafeBatch(ATOM_WARDEN_REINIT_FILE);
    }

    /* =================================================== */
    /*                    Replay evidence                  */
    /* =================================================== */

    /// @notice Batch `02` completes the scheduled operation and moves every proxy and the beacon to the
    ///         recorded v1.1.0 implementations.
    function test_replay_executeBatchCompletesOperationAndPinsImplementations() external view {
        console2.log("fork block:", forkBlockNumber);
        console2.log("fork timestamp:", forkTimestamp);
        console2.log("execution timestamp:", executionTimestamp);
        console2.log("pre-upgrade MultiVault impl:", preUpgradeImplementations.multiVault);
        console2.log("pre-upgrade TrustBonding impl:", preUpgradeImplementations.trustBonding);
        console2.log("pre-upgrade AtomWarden impl:", preUpgradeImplementations.atomWarden);
        console2.log("pre-upgrade LinearCurve impl:", preUpgradeImplementations.linearCurve);
        console2.log("pre-upgrade OffsetProgressiveCurve impl:", preUpgradeImplementations.offsetProgressiveCurve);
        console2.log("pre-upgrade AtomWallet impl:", preUpgradeImplementations.atomWallet);

        TimelockController upgradesTimelock = TimelockController(payable(UPGRADES_TIMELOCK));
        assertTrue(upgradesTimelock.isOperationDone(UPGRADE_OPERATION_ID), "operation must be done");

        ImplementationSet memory current = _currentImplementations();
        assertEq(current.multiVault, NEW_MULTIVAULT_IMPL, "MultiVault implementation");
        assertEq(current.trustBonding, NEW_TRUST_BONDING_IMPL, "TrustBonding implementation");
        assertEq(current.atomWarden, NEW_ATOM_WARDEN_IMPL, "AtomWarden implementation");
        assertEq(current.linearCurve, NEW_LINEAR_CURVE_IMPL, "LinearCurve implementation");
        assertEq(current.offsetProgressiveCurve, NEW_OFFSET_PROGRESSIVE_CURVE_IMPL, "OffsetProgressiveCurve impl");
        assertEq(current.atomWallet, NEW_ATOM_WALLET_IMPL, "AtomWallet beacon implementation");
    }

    /// @notice Gas used by each replayed call, measured on a fresh fork of the same block so no account or slot
    ///         starts warm. Batch `02` is the first access on that fork; before `03` and `04`, every account the
    ///         earlier batches touched is cooled again, because on chain each batch is its own transaction.
    /// @dev    Figures cover the call from the Safe only: they exclude the Safe's `execTransaction` overhead and
    ///         the outer transaction's intrinsic and calldata gas, which are logged separately as a reference.
    function test_replay_gasUsedPerBatchFromColdState() external {
        vm.createSelectFork("intuition", forkBlockNumber);
        vm.warp(executionTimestamp);

        vm.startStateDiffRecording();
        uint256 executeBatchGas = _executeSafeBatch(EXECUTE_FILE);
        _coolAccessedAccounts(vm.stopAndReturnStateDiff());

        vm.startStateDiffRecording();
        uint256 multiVaultReinitializeGas = _executeSafeBatch(MULTIVAULT_REINIT_FILE);
        _coolAccessedAccounts(vm.stopAndReturnStateDiff());

        uint256 atomWardenReinitializeGas = _executeSafeBatch(ATOM_WARDEN_REINIT_FILE);

        console2.log("gas 02 executeBatch (call execution):", executeBatchGas);
        console2.log("gas 03 MultiVault.reinitialize (call execution):", multiVaultReinitializeGas);
        console2.log("gas 04 AtomWarden.reinitialize (call execution):", atomWardenReinitializeGas);
        console2.log("calldata+intrinsic 02:", _intrinsicGas(_batchTransactionData(EXECUTE_FILE, 0)));
        console2.log("calldata+intrinsic 03:", _intrinsicGas(_batchTransactionData(MULTIVAULT_REINIT_FILE, 0)));
        console2.log("calldata+intrinsic 04:", _intrinsicGas(_batchTransactionData(ATOM_WARDEN_REINIT_FILE, 0)));

        assertTrue(
            TimelockController(payable(UPGRADES_TIMELOCK)).isOperationDone(UPGRADE_OPERATION_ID),
            "fresh-fork replay completes the operation"
        );
        assertEq(multiVault.timelock(), PARAMETERS_TIMELOCK, "fresh-fork replay installs the Parameters Timelock");
        assertGt(atomWarden.signatureThreshold(), 0, "fresh-fork replay seeds the signature threshold");
    }

    /// @notice The upgrade and both reinitializers leave every snapshotted value and the pre-upgrade
    ///         position untouched.
    function test_replay_preservesProtocolStateAndPreUpgradePosition() external view {
        ProtocolSnapshot memory postSnapshot = _snapshotProtocol();

        assertEq(postSnapshot.totalTermsCreated, initialSnapshot.totalTermsCreated, "totalTermsCreated");
        assertEq(postSnapshot.curveCount, EXPECTED_CURVE_COUNT, "registry count");
        assertEq(postSnapshot.curveCount, initialSnapshot.curveCount, "registry count changed");
        assertEq(postSnapshot.epoch, preExecutionSnapshot.epoch, "epoch at execution");
        assertEq(postSnapshot.epoch, initialSnapshot.epoch, "epoch changed during the replay window");
        assertEq(postSnapshot.admin, initialSnapshot.admin, "admin");
        assertEq(postSnapshot.registry, initialSnapshot.registry, "registry");
        assertEq(postSnapshot.defaultCurveId, initialSnapshot.defaultCurveId, "default curve");
        assertEq(postSnapshot.atomCost, initialSnapshot.atomCost, "atom cost");
        assertEq(postSnapshot.tripleCost, initialSnapshot.tripleCost, "triple cost");

        // Vault totals move only by the pre-upgrade position, and not at all across the upgrade.
        _assertVaultEq(postSnapshot.linearVault, preExecutionSnapshot.linearVault, "curve 1 vault across upgrade");
        _assertVaultEq(
            postSnapshot.offsetProgressiveVault,
            preExecutionSnapshot.offsetProgressiveVault,
            "curve 2 vault across upgrade"
        );
        assertEq(
            preExecutionSnapshot.linearVault.totalShares,
            initialSnapshot.linearVault.totalShares + legacyLinearShares,
            "curve 1 shares grew by exactly the pre-upgrade position"
        );
        assertEq(
            preExecutionSnapshot.offsetProgressiveVault.totalShares,
            initialSnapshot.offsetProgressiveVault.totalShares + legacyOffsetProgressiveShares,
            "curve 2 shares grew by exactly the pre-upgrade position"
        );

        assertEq(
            multiVault.getShares(legacyDepositor, EXISTING_ATOM_ID, LINEAR_CURVE_ID),
            legacyLinearShares,
            "pre-upgrade curve 1 shares"
        );
        assertEq(
            multiVault.getShares(legacyDepositor, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID),
            legacyOffsetProgressiveShares,
            "pre-upgrade curve 2 shares"
        );

        IBondingCurveRegistry registry = IBondingCurveRegistry(BONDING_CURVE_REGISTRY);
        assertEq(registry.curveAddresses(LINEAR_CURVE_ID), LINEAR_CURVE_PROXY, "curve 1 address");
        assertEq(
            registry.curveAddresses(OFFSET_PROGRESSIVE_CURVE_ID), OFFSET_PROGRESSIVE_CURVE_PROXY, "curve 2 address"
        );
    }

    /// @notice The atom wallet address of an existing atom is the same before and after the upgrade, and
    ///         batch `04` applied the committed AtomWarden parameters.
    function test_atomWarden_preservesAtomWalletAddressAndAppliesReinitialize() external view {
        assertEq(
            multiVault.computeAtomWalletAddr(EXISTING_ATOM_ID),
            initialSnapshot.atomWallet,
            "atom wallet address changed across the upgrade"
        );

        (
            uint256 claimWindow,
            uint256 minFeeThreshold,
            uint256 signatureThreshold,
            uint48 maxValidAfter,
            uint48 maxValidUntil,
            uint256 maxClaimsPerWindow,
            uint256 claimCapWindow
        ) = abi.decode(
            _stripSelector(_batchTransactionData(ATOM_WARDEN_REINIT_FILE, 0)),
            (uint256, uint256, uint256, uint48, uint48, uint256, uint256)
        );

        assertEq(atomWarden.claimWindow(), claimWindow, "claimWindow");
        assertEq(atomWarden.minFeeThreshold(), minFeeThreshold, "minFeeThreshold");
        assertEq(atomWarden.signatureThreshold(), signatureThreshold, "signatureThreshold");
        assertEq(atomWarden.maxValidAfter(), maxValidAfter, "maxValidAfter");
        assertEq(atomWarden.maxValidUntil(), maxValidUntil, "maxValidUntil");
        assertEq(atomWarden.maxClaimsPerWindow(), maxClaimsPerWindow, "maxClaimsPerWindow");
        assertEq(atomWarden.claimCapWindow(), claimCapWindow, "claimCapWindow");
        assertEq(atomWarden.signerCount(), EXPECTED_SIGNER_COUNT_AFTER_REINIT, "signerCount");
    }

    /* =================================================== */
    /*              (a) Deposits and redeems               */
    /* =================================================== */

    /// @notice A fresh user can deposit into and redeem out of the existing atom on both curves.
    function test_depositAndRedeem_existingAtomOnBothCurves() external {
        address user = _fundedUser("deposit-redeem-user");

        _depositAndRedeemFully(user, LINEAR_CURVE_ID);
        _depositAndRedeemFully(user, OFFSET_PROGRESSIVE_CURVE_ID);
    }

    /// @notice A position opened under the pre-upgrade code redeems fully under the new code.
    function test_redeem_preUpgradePositionFullyOnBothCurves() external {
        _redeemLegacyPositionFully(LINEAR_CURVE_ID, legacyLinearShares);
        _redeemLegacyPositionFully(OFFSET_PROGRESSIVE_CURVE_ID, legacyOffsetProgressiveShares);
    }

    /* =================================================== */
    /*                    (b) Fee hooks                    */
    /* =================================================== */

    /// @notice Both registered curves answer the fee-hook probes, and report no hooks.
    function test_feeHooks_registeredCurvesReportNoHooks() external view {
        assertFalse(IBaseCurve(LINEAR_CURVE_PROXY).hasDepositFeeHook(), "curve 1 deposit hook");
        assertFalse(IBaseCurve(LINEAR_CURVE_PROXY).hasRedeemFeeHook(), "curve 1 redeem hook");
        assertFalse(IBaseCurve(OFFSET_PROGRESSIVE_CURVE_PROXY).hasDepositFeeHook(), "curve 2 deposit hook");
        assertFalse(IBaseCurve(OFFSET_PROGRESSIVE_CURVE_PROXY).hasRedeemFeeHook(), "curve 2 redeem hook");
    }

    /// @notice Deposit and redeem previews equal the executed results on both curves.
    function test_previews_matchExecutedDepositAndRedeemOnBothCurves() external {
        address user = _fundedUser("preview-user");

        _assertPreviewsMatch(user, LINEAR_CURVE_ID);
        _assertPreviewsMatch(user, OFFSET_PROGRESSIVE_CURVE_ID);
    }

    /* =================================================== */
    /*                (c) Payable multicall                */
    /* =================================================== */

    /// @notice Two deposits whose values sum to `msg.value` execute in one multicall.
    function test_multicall_payableDepositsWithMatchingValueSucceed() external {
        address user = _fundedUser("multicall-deposit-user");
        uint256 linearValue = 2 ether;
        uint256 offsetProgressiveValue = 1 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = linearValue;
        values[1] = offsetProgressiveValue;

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        bytes[] memory results = multiVault.multicall{ value: linearValue + offsetProgressiveValue }(data, values);

        uint256 linearShares = abi.decode(results[0], (uint256));
        uint256 offsetProgressiveShares = abi.decode(results[1], (uint256));
        assertGt(linearShares, 0, "curve 1 multicall deposit shares");
        assertGt(offsetProgressiveShares, 0, "curve 2 multicall deposit shares");
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, LINEAR_CURVE_ID), linearShares, "curve 1 shares");
        assertEq(
            multiVault.getShares(user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID),
            offsetProgressiveShares,
            "curve 2 shares"
        );
        assertEq(user.balance, balanceBefore - linearValue - offsetProgressiveValue, "user paid exactly msg.value");
    }

    /// @notice A multicall whose per-call values do not sum to `msg.value` reverts.
    function test_multicall_valueSumMismatchReverts() external {
        address user = _fundedUser("multicall-mismatch-user");

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.deposit, (user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, 0));
        data[1] = abi.encodeCall(IMultiVault.deposit, (user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, 0));
        uint256[] memory values = new uint256[](2);
        values[0] = 2 ether;
        values[1] = 1 ether;

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_MulticallValueMismatch.selector));
        multiVault.multicall{ value: 3 ether + 1 }(data, values);

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_MulticallValueMismatch.selector));
        multiVault.multicall{ value: 3 ether - 1 }(data, values);
        vm.stopPrank();
    }

    /// @notice A zero-value multicall of redeems on both curves executes and matches the previews.
    function test_multicall_redeemsOnBothCurvesSucceed() external {
        address user = _fundedUser("multicall-redeem-user");
        uint256 linearShares = _deposit(user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, DEPOSIT_AMOUNT);
        uint256 offsetProgressiveShares = _deposit(user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, DEPOSIT_AMOUNT);

        (uint256 expectedLinearAssets,) = multiVault.previewRedeem(EXISTING_ATOM_ID, LINEAR_CURVE_ID, linearShares);
        (uint256 expectedOffsetProgressiveAssets,) =
            multiVault.previewRedeem(EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, offsetProgressiveShares);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.redeem, (user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, linearShares, 0));
        data[1] = abi.encodeCall(
            IMultiVault.redeem, (user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, offsetProgressiveShares, 0)
        );
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        bytes[] memory results = multiVault.multicall(data, new uint256[](2));

        assertEq(abi.decode(results[0], (uint256)), expectedLinearAssets, "curve 1 redeem assets");
        assertEq(abi.decode(results[1], (uint256)), expectedOffsetProgressiveAssets, "curve 2 redeem assets");
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, LINEAR_CURVE_ID), 0, "curve 1 shares left");
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID), 0, "curve 2 shares left");
        assertEq(
            user.balance,
            balanceBefore + expectedLinearAssets + expectedOffsetProgressiveAssets,
            "redeemed assets paid out"
        );
    }

    /* =================================================== */
    /*              (d) Approvals and create-for           */
    /* =================================================== */

    /// @notice With CREATION approval, an operator's `createAtomsFor` records the user as creator.
    function test_createAtomsFor_withCreationApprovalRecordsUserAsCreator() external {
        address user = makeAddr("create-for-user");
        address operator = _fundedUser("create-for-operator");

        vm.prank(user);
        multiVault.approve(operator, ApprovalTypes.CREATION);
        assertTrue(multiVault.isApprovedToCreate(operator, user), "operator must be approved to create");

        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-create-for-atom"));
        uint256 atomAssets = multiVault.getAtomCost() + ATOM_EXTRA_ASSETS;

        vm.prank(operator);
        bytes32[] memory atomIds =
            multiVault.createAtomsFor{ value: atomAssets }(user, atomDatas, _singleAmount(atomAssets));

        assertEq(atomIds[0], multiVault.calculateAtomId(atomDatas[0]), "atom id");
        assertEq(multiVault.atomCreators(atomIds[0]), user, "atomCreators must record the user");
        assertEq(multiVault.atomCreatedAt(atomIds[0]), uint48(vm.getBlockTimestamp()), "atomCreatedAt");
        assertGt(multiVault.getShares(user, atomIds[0], LINEAR_CURVE_ID), 0, "creator receives the shares");
        assertEq(multiVault.getShares(operator, atomIds[0], LINEAR_CURVE_ID), 0, "operator receives no shares");
    }

    /// @notice Without CREATION approval, the same `createAtomsFor` call reverts.
    function test_createAtomsFor_withoutApprovalReverts() external {
        address user = makeAddr("create-for-unapproved-user");
        address operator = _fundedUser("create-for-unapproved-operator");

        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-create-for-unapproved-atom"));
        uint256 atomAssets = multiVault.getAtomCost() + ATOM_EXTRA_ASSETS;
        uint256[] memory amounts = _singleAmount(atomAssets);
        assertFalse(multiVault.isApprovedToCreate(operator, user), "operator must not be approved");

        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_CreatorNotApproved.selector));
        multiVault.createAtomsFor{ value: atomAssets }(user, atomDatas, amounts);
        vm.stopPrank();

        // DEPOSIT approval alone does not carry the CREATION bit.
        vm.prank(user);
        multiVault.approve(operator, ApprovalTypes.DEPOSIT);

        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_CreatorNotApproved.selector));
        multiVault.createAtomsFor{ value: atomAssets }(user, atomDatas, amounts);
        vm.stopPrank();
    }

    /* =================================================== */
    /*                (e) URIs and triples                 */
    /* =================================================== */

    /// @notice `createAtomsWithUris` with a valid URI creates the atom and emits its context.
    function test_createAtomsWithUris_validUriCreatesAtomAndEmitsContext() external {
        address creator = _fundedUser("uri-creator");

        (uint32 maxUriCount, uint32 maxUriLength) = multiVault.getAtomUriConfig();
        assertEq(maxUriCount, DEFAULT_MAX_URI_COUNT, "default max URI count");
        assertEq(maxUriLength, DEFAULT_MAX_URI_LENGTH, "default max URI length");

        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-uri-atom"));
        uint256 atomAssets = multiVault.getAtomCost() + ATOM_EXTRA_ASSETS;
        bytes[][] memory uris = new bytes[][](1);
        uris[0] = _singleBytes(bytes("ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"));
        bytes32 expectedAtomId = multiVault.calculateAtomId(atomDatas[0]);
        uint256[] memory amounts = _singleAmount(atomAssets);

        vm.expectEmit(true, true, false, true, MULTIVAULT_PROXY);
        emit IMultiVault.AtomContextRegistered(expectedAtomId, creator, uris[0]);

        vm.prank(creator);
        bytes32[] memory atomIds =
            multiVault.createAtomsWithUris{ value: atomAssets }(creator, atomDatas, amounts, uris);

        assertEq(atomIds[0], expectedAtomId, "URI context must not affect the atom id");
        assertTrue(multiVault.isTermCreated(expectedAtomId), "atom created");
        assertEq(multiVault.atomCreators(expectedAtomId), creator, "creator recorded");
    }

    /// @notice An over-long URI or too many URIs reverts.
    function test_createAtomsWithUris_oversizedInputReverts() external {
        address creator = _fundedUser("uri-oversized-creator");

        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-uri-oversized-atom"));
        uint256 atomAssets = multiVault.getAtomCost() + ATOM_EXTRA_ASSETS;
        uint256[] memory amounts = _singleAmount(atomAssets);

        bytes[][] memory tooLong = new bytes[][](1);
        tooLong[0] = _singleBytes(new bytes(uint256(DEFAULT_MAX_URI_LENGTH) + 1));

        bytes[][] memory tooMany = new bytes[][](1);
        tooMany[0] = new bytes[](uint256(DEFAULT_MAX_URI_COUNT) + 1);

        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_AtomUriLengthExceeded.selector));
        multiVault.createAtomsWithUris{ value: atomAssets }(creator, atomDatas, amounts, tooLong);

        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_AtomUriCountExceeded.selector));
        multiVault.createAtomsWithUris{ value: atomAssets }(creator, atomDatas, amounts, tooMany);
        vm.stopPrank();

        assertFalse(multiVault.isTermCreated(multiVault.calculateAtomId(atomDatas[0])), "no atom may be created");
    }

    /// @notice `createTriples` on fresh atoms succeeds, and the counter-triple accepts deposits on the default
    ///         curve and as the first deposit on a non-default curve, which seeds the positive side.
    function test_createTriples_freshAtomsThenCounterTripleDepositsSucceed() external {
        address creator = _fundedUser("triple-creator");
        address counterStaker = _fundedUser("counter-triple-staker");

        bytes32 subjectId = _createAtom(creator, "v110-replay-triple-subject");
        bytes32 predicateId = _createAtom(creator, "v110-replay-triple-predicate");
        bytes32 objectId = _createAtom(creator, "v110-replay-triple-object");

        uint256 termsBefore = multiVault.totalTermsCreated();
        uint256 tripleAssets = multiVault.getTripleCost() + TRIPLE_EXTRA_ASSETS;

        vm.prank(creator);
        bytes32[] memory tripleIds = multiVault.createTriples{ value: tripleAssets }(
            _singleId(subjectId), _singleId(predicateId), _singleId(objectId), _singleAmount(tripleAssets)
        );
        bytes32 tripleId = tripleIds[0];
        bytes32 counterTripleId = multiVault.getCounterIdFromTripleId(tripleId);

        assertEq(tripleId, multiVault.calculateTripleId(subjectId, predicateId, objectId), "triple id");
        assertEq(counterTripleId, multiVault.calculateCounterTripleId(subjectId, predicateId, objectId), "counter id");
        assertEq(multiVault.totalTermsCreated(), termsBefore + 2, "triple and counter-triple registered");
        assertTrue(multiVault.isCounterTriple(counterTripleId), "counter-triple registered");

        // Default curve: the counter-triple vault was seeded at creation, so a deposit goes straight in.
        _deposit(counterStaker, counterTripleId, LINEAR_CURVE_ID, DEPOSIT_AMOUNT);

        // Non-default curve: the counter-triple vault is new; its first deposit must succeed and seed the
        // positive side's vault with the burned minimum shares.
        (, uint256 tripleCurveTwoSharesBefore) = multiVault.getVault(tripleId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertEq(tripleCurveTwoSharesBefore, 0, "positive curve 2 vault starts empty");

        _deposit(counterStaker, counterTripleId, OFFSET_PROGRESSIVE_CURVE_ID, DEPOSIT_AMOUNT);

        uint256 minShare = multiVault.getGeneralConfig().minShare;
        (, uint256 tripleCurveTwoSharesAfter) = multiVault.getVault(tripleId, OFFSET_PROGRESSIVE_CURVE_ID);
        assertEq(tripleCurveTwoSharesAfter, minShare, "positive curve 2 vault seeded with min shares");
        assertEq(
            multiVault.getShares(multiVault.BURN_ADDRESS(), tripleId, OFFSET_PROGRESSIVE_CURVE_ID),
            minShare,
            "seed shares burned"
        );

        // The triple's creator holds the positive side and cannot take the counter side.
        vm.startPrank(creator);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_HasCounterStake.selector));
        multiVault.deposit{ value: DEPOSIT_AMOUNT }(creator, counterTripleId, LINEAR_CURVE_ID, 0);
        vm.stopPrank();
    }

    /* =================================================== */
    /*                    (f) FeeProxy                     */
    /* =================================================== */

    /// @notice An affiliate registers with the live 100 TRUST fee and a fee config inside the live caps; the fee
    ///         goes to the treasury, and an over-cap config is rejected.
    function test_feeProxy_registerAffiliateWithinCaps() external {
        assertEq(feeProxy.multiVault(), MULTIVAULT_PROXY, "FeeProxy targets the MultiVault proxy");
        assertEq(feeProxy.registrationFee(), EXPECTED_REGISTRATION_FEE, "registration fee");
        assertEq(feeProxy.maxFeeBps(), EXPECTED_MAX_FEE_BPS, "max fee bps");
        assertEq(feeProxy.maxFixedFee(), EXPECTED_MAX_FIXED_FEE, "max fixed fee");

        address treasury = feeProxy.treasury();
        uint256 treasuryBalanceBefore = treasury.balance;

        (address affiliate, address feeRecipient) = _registerAffiliate();

        assertEq(treasury.balance, treasuryBalanceBefore + EXPECTED_REGISTRATION_FEE, "registration fee forwarded");
        assertTrue(feeProxy.isAffiliateActive(affiliate), "affiliate active");
        assertEq(feeProxy.affiliateConfig(affiliate).feeRecipient, feeRecipient, "fee recipient");
        assertEq(feeProxy.affiliateConfig(affiliate).fees.depositBps, AFFILIATE_DEPOSIT_BPS, "deposit bps");

        address overCapAffiliate = makeAddr("over-cap-affiliate");
        vm.deal(overCapAffiliate, EXPECTED_REGISTRATION_FEE * 2);
        FeeConfig memory overBps = _affiliateFees();
        overBps.depositBps = EXPECTED_MAX_FEE_BPS + 1;
        FeeConfig memory overFixed = _affiliateFees();
        overFixed.creationFixedFee = EXPECTED_MAX_FIXED_FEE + 1;

        vm.startPrank(overCapAffiliate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCap.selector, EXPECTED_MAX_FEE_BPS + 1, EXPECTED_MAX_FEE_BPS
            )
        );
        feeProxy.registerAffiliate{ value: EXPECTED_REGISTRATION_FEE }(overBps, feeRecipient);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCap.selector, EXPECTED_MAX_FIXED_FEE + 1, EXPECTED_MAX_FIXED_FEE
            )
        );
        feeProxy.registerAffiliate{ value: EXPECTED_REGISTRATION_FEE }(overFixed, feeRecipient);
        vm.stopPrank();
    }

    /// @notice `depositVia` charges exactly the previewed fee, pays the affiliate, and credits the user as the
    ///         depositor of record: shares and utilization land on the user, not the proxy.
    function test_feeProxy_depositViaChargesPreviewedFeeAndCreditsUser() external {
        (address affiliate, address feeRecipient) = _registerAffiliate();
        address user = _fundedUser("fee-proxy-depositor");
        _approveFeeProxy(user);

        RoutedDepositExpectation memory expected;
        expected.grossAssets = 2 ether;
        (expected.affiliateFee, expected.forwardedAssets) = feeProxy.previewDepositFee(affiliate, expected.grossAssets);
        assertEq(
            expected.affiliateFee,
            expected.grossAssets * AFFILIATE_DEPOSIT_BPS / BPS_DIVISOR + AFFILIATE_DEPOSIT_FIXED_FEE,
            "previewed fee matches the configured rate"
        );
        assertEq(expected.forwardedAssets, expected.grossAssets - expected.affiliateFee, "previewed forward");

        (expected.shares,) = multiVault.previewDeposit(EXISTING_ATOM_ID, LINEAR_CURVE_ID, expected.forwardedAssets);
        expected.epoch = multiVault.currentEpoch();
        expected.userUtilizationBefore = multiVault.getUserUtilizationForEpoch(user, expected.epoch);
        expected.proxyUtilizationBefore = multiVault.getUserUtilizationForEpoch(FEE_PROXY, expected.epoch);
        expected.userBalanceBefore = user.balance;
        expected.recipientBalanceBefore = feeRecipient.balance;
        expected.proxyBalanceBefore = FEE_PROXY.balance;

        uint256 shares = _depositVia(user, affiliate, expected.grossAssets);

        assertEq(shares, expected.shares, "shares match the MultiVault preview of the forwarded assets");
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, LINEAR_CURVE_ID), shares, "user holds the shares");
        assertEq(multiVault.getShares(FEE_PROXY, EXISTING_ATOM_ID, LINEAR_CURVE_ID), 0, "proxy holds no shares");
        assertEq(
            feeRecipient.balance,
            expected.recipientBalanceBefore + expected.affiliateFee,
            "affiliate paid the previewed fee"
        );
        assertEq(user.balance, expected.userBalanceBefore - expected.grossAssets, "user paid gross assets");
        assertEq(FEE_PROXY.balance, expected.proxyBalanceBefore, "proxy retains nothing");
        assertEq(
            multiVault.getUserUtilizationForEpoch(user, expected.epoch),
            expected.userUtilizationBefore + int256(expected.forwardedAssets),
            "user credited with the forwarded utilization"
        );
        assertEq(
            multiVault.getUserUtilizationForEpoch(FEE_PROXY, expected.epoch),
            expected.proxyUtilizationBefore,
            "proxy not credited"
        );

        AffiliateStats memory stats = feeProxy.affiliateStats(affiliate);
        assertEq(stats.depositFees, expected.affiliateFee, "affiliate stats fee");
        assertEq(stats.depositForwardedAssets, expected.forwardedAssets, "affiliate stats forward");
    }

    /// @notice `createAtomsVia` makes the user the creator of record and pushes excess value back to the user.
    function test_feeProxy_createAtomsViaRecordsUserAsCreatorAndPushesRefund() external {
        (address affiliate, address feeRecipient) = _registerAffiliate();
        address user = _fundedUser("fee-proxy-creator");
        _approveFeeProxy(user);

        uint256 grossAssets = 1 ether;
        uint256 excessValue = 0.5 ether;
        (uint256 affiliateFee,) = feeProxy.previewCreationFee(affiliate, grossAssets);
        assertEq(
            affiliateFee,
            grossAssets * AFFILIATE_CREATION_BPS / BPS_DIVISOR + AFFILIATE_CREATION_FIXED_FEE,
            "previewed creation fee"
        );

        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-fee-proxy-atom"));
        uint256[] memory amounts = _singleAmount(grossAssets);
        FeeGuard memory creationGuard = _creationFeeGuard();
        uint256 userBalanceBefore = user.balance;
        uint256 recipientBalanceBefore = feeRecipient.balance;
        uint256 proxyBalanceBefore = FEE_PROXY.balance;

        vm.prank(user);
        bytes32[] memory atomIds =
            feeProxy.createAtomsVia{ value: grossAssets + excessValue }(affiliate, atomDatas, amounts, creationGuard);

        assertEq(multiVault.atomCreators(atomIds[0]), user, "user is the creator of record");
        assertEq(multiVault.atomCreatedAt(atomIds[0]), uint48(vm.getBlockTimestamp()), "creation time");
        assertGt(multiVault.getShares(user, atomIds[0], LINEAR_CURVE_ID), 0, "user holds the creation shares");
        assertEq(user.balance, userBalanceBefore - grossAssets, "excess pushed back to the user");
        assertEq(feeProxy.pendingRefund(user), 0, "nothing left on the pull ledger");
        assertEq(feeRecipient.balance, recipientBalanceBefore + affiliateFee, "affiliate paid the previewed fee");
        assertEq(FEE_PROXY.balance, proxyBalanceBefore, "proxy retains nothing");
    }

    /// @notice When the push refund fails, the excess lands on the pull ledger and `claimRefundTo` recovers it.
    function test_feeProxy_createAtomsViaFailedPushRefundIsClaimableViaClaimRefundTo() external {
        (address affiliate,) = _registerAffiliate();
        RefundRejectingWallet wallet = new RefundRejectingWallet();
        vm.deal(address(wallet), USER_FUNDING);
        address rescueRecipient = makeAddr("refund-rescue-recipient");

        wallet.execute(
            MULTIVAULT_PROXY, 0, abi.encodeCall(IMultiVault.approve, (FEE_PROXY, ApprovalTypes.DEPOSIT_AND_CREATION))
        );

        uint256 grossAssets = 1 ether;
        uint256 excessValue = 0.25 ether;
        bytes memory createCall = abi.encodeCall(
            IFeeProxy.createAtomsVia,
            (
                affiliate,
                _singleBytes(bytes("v110-replay-fee-proxy-pull-refund-atom")),
                _singleAmount(grossAssets),
                _creationFeeGuard()
            )
        );
        bytes32[] memory atomIds =
            abi.decode(wallet.execute(FEE_PROXY, grossAssets + excessValue, createCall), (bytes32[]));

        assertEq(multiVault.atomCreators(atomIds[0]), address(wallet), "wallet is the creator of record");
        assertEq(feeProxy.pendingRefund(address(wallet)), excessValue, "excess credited to the pull ledger");

        bytes memory claimed =
            wallet.execute(FEE_PROXY, 0, abi.encodeCall(IFeeProxy.claimRefundTo, (payable(rescueRecipient))));

        assertEq(abi.decode(claimed, (uint256)), excessValue, "claimed amount");
        assertEq(rescueRecipient.balance, excessValue, "refund delivered to the chosen recipient");
        assertEq(feeProxy.pendingRefund(address(wallet)), 0, "ledger cleared");
    }

    /// @notice A routed call whose configured fee exceeds the caller's fee guard reverts, on both sides.
    function test_feeProxy_feeAboveCallerGuardReverts() external {
        (address affiliate,) = _registerAffiliate();
        address user = _fundedUser("fee-proxy-guarded-user");
        _approveFeeProxy(user);

        uint256 grossAssets = 1 ether;
        FeeGuard memory lowBpsGuard =
            FeeGuard({ maxFeeBps: AFFILIATE_DEPOSIT_BPS - 1, maxFixedFee: AFFILIATE_DEPOSIT_FIXED_FEE });
        FeeGuard memory lowFixedGuard =
            FeeGuard({ maxFeeBps: AFFILIATE_DEPOSIT_BPS, maxFixedFee: AFFILIATE_DEPOSIT_FIXED_FEE - 1 });
        FeeGuard memory lowCreationBpsGuard =
            FeeGuard({ maxFeeBps: AFFILIATE_CREATION_BPS - 1, maxFixedFee: AFFILIATE_CREATION_FIXED_FEE });
        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-fee-proxy-guarded-atom"));
        uint256[] memory amounts = _singleAmount(grossAssets);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCallerGuard.selector, AFFILIATE_DEPOSIT_BPS, AFFILIATE_DEPOSIT_BPS - 1
            )
        );
        feeProxy.depositVia{ value: grossAssets }(
            affiliate, user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, grossAssets, 0, lowBpsGuard
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_FixedFeeExceedsCallerGuard.selector,
                AFFILIATE_DEPOSIT_FIXED_FEE,
                AFFILIATE_DEPOSIT_FIXED_FEE - 1
            )
        );
        feeProxy.depositVia{ value: grossAssets }(
            affiliate, user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, grossAssets, 0, lowFixedGuard
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IFeeProxy.FeeProxy_BpsExceedsCallerGuard.selector, AFFILIATE_CREATION_BPS, AFFILIATE_CREATION_BPS - 1
            )
        );
        feeProxy.createAtomsVia{ value: grossAssets }(affiliate, atomDatas, amounts, lowCreationBpsGuard);
        vm.stopPrank();
    }

    /// @notice Without the user's MultiVault approval for the proxy, routed deposits and creations revert.
    function test_feeProxy_withoutMultiVaultApprovalReverts() external {
        (address affiliate,) = _registerAffiliate();
        address user = _fundedUser("fee-proxy-unapproved-user");

        uint256 grossAssets = 1 ether;
        FeeGuard memory depositGuard = _depositFeeGuard();
        FeeGuard memory creationGuard = _creationFeeGuard();
        bytes[] memory atomDatas = _singleBytes(bytes("v110-replay-fee-proxy-unapproved-atom"));
        uint256[] memory amounts = _singleAmount(grossAssets);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IFeeProxy.FeeProxy_ProxyNotApprovedForDeposit.selector, user, FEE_PROXY));
        feeProxy.depositVia{ value: grossAssets }(
            affiliate, user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, grossAssets, 0, depositGuard
        );

        vm.expectRevert(
            abi.encodeWithSelector(IFeeProxy.FeeProxy_ProxyNotApprovedForCreation.selector, user, FEE_PROXY)
        );
        feeProxy.createAtomsVia{ value: grossAssets }(affiliate, atomDatas, amounts, creationGuard);
        vm.stopPrank();
    }

    /* =================================================== */
    /*              (g) Roles and utilization              */
    /* =================================================== */

    /// @notice `reinitialize` granted PAUSER_ROLE to the admin; the admin can pause and unpause, a stranger
    ///         cannot pause.
    function test_roles_pauserRoleGrantedToAdmin() external {
        bytes32 pauserRole = multiVault.PAUSER_ROLE();
        bytes32 defaultAdminRole = multiVault.DEFAULT_ADMIN_ROLE();
        assertEq(pauserRole, keccak256("PAUSER_ROLE"), "PAUSER_ROLE id");
        assertEq(multiVault.getGeneralConfig().admin, ADMIN_SAFE, "admin is the Admin Safe");
        assertTrue(multiVault.hasRole(pauserRole, ADMIN_SAFE), "Admin Safe holds PAUSER_ROLE");
        assertTrue(multiVault.hasRole(defaultAdminRole, ADMIN_SAFE), "Admin Safe holds the admin role");
        assertEq(multiVault.getRoleAdmin(pauserRole), defaultAdminRole, "PAUSER_ROLE admin");

        vm.startPrank(ADMIN_SAFE);
        multiVault.pause();
        assertTrue(multiVault.paused(), "paused");
        multiVault.unpause();
        assertFalse(multiVault.paused(), "unpaused");
        vm.stopPrank();

        address stranger = makeAddr("pause-stranger");
        vm.startPrank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, pauserRole)
        );
        multiVault.pause();
        vm.stopPrank();
    }

    /// @notice `reinitialize` installed the Parameters Timelock; every parameter setter rejects any other
    ///         caller, the Admin Safe included, and accepts the timelock.
    function test_timelock_parameterSettersRejectNonTimelockCallers() external {
        assertEq(timelockBeforeReinitialize, address(0), "timelock unset between 02 and 03");
        assertEq(multiVault.timelock(), PARAMETERS_TIMELOCK, "timelock is the Parameters Timelock");

        _assertSettersRejectCaller(ADMIN_SAFE);
        _assertSettersRejectCaller(makeAddr("setter-stranger"));

        vm.prank(PARAMETERS_TIMELOCK);
        multiVault.setAtomUriConfig(DEFAULT_MAX_URI_COUNT, DEFAULT_MAX_URI_LENGTH);
        (uint32 maxUriCount, uint32 maxUriLength) = multiVault.getAtomUriConfig();
        assertEq(maxUriCount, DEFAULT_MAX_URI_COUNT, "timelock write: URI count");
        assertEq(maxUriLength, DEFAULT_MAX_URI_LENGTH, "timelock write: URI length");
    }

    /// @notice `reinitialize` seeded `lastSystemUtilizationEpoch` to the epoch it ran in.
    function test_reinitialize_seedsLastSystemUtilizationEpoch() external view {
        assertEq(lastSystemUtilizationEpochBeforeReinitialize, 0, "slot empty between 02 and 03");
        assertGt(epochAtReinitialize, 0, "epoch must be non-zero for the seed to be meaningful");
        assertEq(multiVault.lastSystemUtilizationEpoch(), epochAtReinitialize, "seeded to the current epoch");
    }

    /// @notice A post-upgrade deposit updates personal and total utilization for the current epoch.
    function test_deposit_updatesPersonalAndTotalUtilizationForCurrentEpoch() external {
        address user = _fundedUser("utilization-user");
        uint256 epoch = multiVault.currentEpoch();
        assertEq(epoch, epochAtReinitialize, "still in the reinitialize epoch");

        int256 totalBefore = multiVault.getTotalUtilizationForEpoch(epoch);
        assertEq(multiVault.getUserUtilizationForEpoch(user, epoch), 0, "fresh user starts at zero");

        _deposit(user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, DEPOSIT_AMOUNT);

        assertEq(multiVault.getUserUtilizationForEpoch(user, epoch), int256(DEPOSIT_AMOUNT), "personal utilization");
        assertEq(
            multiVault.getTotalUtilizationForEpoch(epoch), totalBefore + int256(DEPOSIT_AMOUNT), "total utilization"
        );
        assertTrue(multiVault.hasRolledOverSystemUtilization(epoch), "epoch rollover recorded");
        assertEq(multiVault.lastSystemUtilizationEpoch(), epoch, "rollover source tracks the current epoch");
        assertEq(multiVault.getUserLastActiveEpoch(user), epoch, "user last active epoch");
    }

    /// @notice Neither reinitializer can be replayed.
    function test_reinitializers_cannotBeReplayed() external {
        bytes memory multiVaultReinit = _batchTransactionData(MULTIVAULT_REINIT_FILE, 0);
        bytes memory atomWardenReinit = _batchTransactionData(ATOM_WARDEN_REINIT_FILE, 0);

        vm.startPrank(ADMIN_SAFE);
        (bool multiVaultOk, bytes memory multiVaultRevert) = MULTIVAULT_PROXY.call(multiVaultReinit);
        (bool atomWardenOk, bytes memory atomWardenRevert) = ATOM_WARDEN_PROXY.call(atomWardenReinit);
        vm.stopPrank();

        bytes memory invalidInitialization = abi.encodeWithSelector(Initializable.InvalidInitialization.selector);
        assertFalse(multiVaultOk, "MultiVault.reinitialize replay must revert");
        assertEq(multiVaultRevert, invalidInitialization, "MultiVault replay reason");
        assertFalse(atomWardenOk, "AtomWarden.reinitialize replay must revert");
        assertEq(atomWardenRevert, invalidInitialization, "AtomWarden replay reason");
    }

    /* =================================================== */
    /*                   (h) TrustBonding                  */
    /* =================================================== */

    /// @notice TrustBonding's epoch, emissions, APY and account views answer after the upgrade. Values that the
    ///         upgrade does not touch are unchanged; APYs can only rise, because v1.1.0 drops the truncated
    ///         epochs-per-year factor.
    function test_trustBonding_viewPathsAnswerAfterUpgrade() external view {
        TrustBondingSnapshot memory post = _snapshotTrustBonding();
        console2.log("system APY bps pre / post:", preExecutionTrustBonding.systemApy, post.systemApy);
        console2.log("system max APY bps pre / post:", preExecutionTrustBonding.systemMaxApy, post.systemMaxApy);
        console2.log("holder APY bps pre / post:", preExecutionTrustBonding.holderApy, post.holderApy);
        console2.log("holder max APY bps pre / post:", preExecutionTrustBonding.holderMaxApy, post.holderMaxApy);

        assertEq(post.epoch, preExecutionTrustBonding.epoch, "currentEpoch");
        assertEq(post.epoch, multiVault.currentEpoch(), "TrustBonding and MultiVault epochs agree");
        assertEq(post.epochLength, preExecutionTrustBonding.epochLength, "epochLength");
        assertEq(post.totalLocked, preExecutionTrustBonding.totalLocked, "totalLocked");
        assertEq(post.totalBondedBalance, preExecutionTrustBonding.totalBondedBalance, "totalBondedBalance");
        assertEq(post.emissions, preExecutionTrustBonding.emissions, "emissionsForEpoch");
        assertGt(post.systemApy, 0, "system APY");
        assertGe(post.systemApy, preExecutionTrustBonding.systemApy, "system APY");
        assertGe(post.systemMaxApy, preExecutionTrustBonding.systemMaxApy, "system max APY");
        assertGe(post.holderApy, preExecutionTrustBonding.holderApy, "holder APY");
        assertGe(post.holderMaxApy, preExecutionTrustBonding.holderMaxApy, "holder max APY");

        uint256 previousEpoch = trustBonding.previousEpoch();
        assertEq(previousEpoch, post.epoch - 1, "previousEpoch");
        assertEq(trustBonding.epochAtTimestamp(vm.getBlockTimestamp()), post.epoch, "epochAtTimestamp");
        assertGt(trustBonding.epochTimestampEnd(post.epoch), vm.getBlockTimestamp(), "epochTimestampEnd");
        assertGt(trustBonding.epochsPerYear(), 0, "epochsPerYear");

        UserInfo memory holderInfo = trustBonding.getUserInfo(TRUST_BONDING_HOLDER);
        assertGt(holderInfo.lockedAmount, 0, "holder still bonded");
        assertGt(holderInfo.bondedBalance, 0, "holder bonded balance");

        trustBonding.getUserCurrentClaimableRewards(TRUST_BONDING_HOLDER);
        trustBonding.getUserRewardsForEpoch(TRUST_BONDING_HOLDER, previousEpoch);
        trustBonding.userEligibleRewardsForEpoch(TRUST_BONDING_HOLDER, previousEpoch);
        trustBonding.getPersonalUtilizationRatio(TRUST_BONDING_HOLDER, previousEpoch);
        trustBonding.getSystemUtilizationRatio(previousEpoch);
        trustBonding.hasClaimedRewardsForEpoch(TRUST_BONDING_HOLDER, previousEpoch);
        trustBonding.getUnclaimedRewardsForEpoch(previousEpoch - 1);
        assertGt(trustBonding.totalBondedBalanceAtEpochEnd(previousEpoch), 0, "bonded balance at epoch end");
        trustBonding.userBondedBalanceAtEpochEnd(TRUST_BONDING_HOLDER, previousEpoch);
    }

    /* =================================================== */
    /*                    Replay helpers                   */
    /* =================================================== */

    /// @dev Sends every transaction in a committed Safe batch from the Admin Safe, byte for byte, and returns
    ///      the execution gas of the calls (Safe signature checks and intrinsic gas excluded).
    function _executeSafeBatch(string memory file) internal returns (uint256 gasUsed) {
        string memory json = vm.readFile(string.concat(BATCH_DIR, file));
        require(
            keccak256(bytes(vm.parseJsonString(json, ".chainId"))) == keccak256(bytes(BATCH_CHAIN_ID)),
            "batch chainId must be 1155"
        );

        uint256 transactionCount;
        while (vm.keyExistsJson(json, _transactionKey(transactionCount, ""))) {
            address to = vm.parseJsonAddress(json, _transactionKey(transactionCount, ".to"));
            uint256 value = vm.parseUint(vm.parseJsonString(json, _transactionKey(transactionCount, ".value")));
            bytes memory data = vm.parseJsonBytes(json, _transactionKey(transactionCount, ".data"));

            vm.prank(ADMIN_SAFE);
            uint256 gasBefore = gasleft();
            (bool success, bytes memory returnData) = to.call{ value: value }(data);
            gasUsed += gasBefore - gasleft();

            if (!success) {
                assembly {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }
            ++transactionCount;
        }

        require(transactionCount == 1, "each replayed batch holds exactly one transaction");
    }

    /// @dev Marks every account (and with it, every slot) touched in a recorded state diff as cold again.
    function _coolAccessedAccounts(Vm.AccountAccess[] memory accesses) internal {
        for (uint256 i = 0; i < accesses.length; ++i) {
            address account = accesses[i].account;
            if (account != address(vm) && account != address(this)) {
                vm.cool(account);
            }
        }
    }

    /// @dev Base transaction cost plus EIP-2028 calldata cost for a direct call carrying `data`. Reference only:
    ///      the real transaction targets the Safe and carries the Safe's `execTransaction` encoding.
    function _intrinsicGas(bytes memory data) internal pure returns (uint256 gasCost) {
        gasCost = TRANSACTION_BASE_GAS;
        for (uint256 i = 0; i < data.length; ++i) {
            gasCost += data[i] == 0 ? ZERO_CALLDATA_BYTE_GAS : NONZERO_CALLDATA_BYTE_GAS;
        }
    }

    function _openLegacyPosition() internal {
        legacyDepositor = _fundedUser("pre-upgrade-depositor");

        vm.startPrank(legacyDepositor);
        legacyLinearShares =
            multiVault.deposit{ value: LEGACY_DEPOSIT_AMOUNT }(legacyDepositor, EXISTING_ATOM_ID, LINEAR_CURVE_ID, 0);
        legacyOffsetProgressiveShares = multiVault.deposit{ value: LEGACY_DEPOSIT_AMOUNT }(
            legacyDepositor, EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, 0
        );
        vm.stopPrank();

        require(legacyLinearShares > 0 && legacyOffsetProgressiveShares > 0, "pre-upgrade deposit minted no shares");
    }

    function _snapshotProtocol() internal view returns (ProtocolSnapshot memory snapshot) {
        snapshot.totalTermsCreated = multiVault.totalTermsCreated();
        snapshot.curveCount = IBondingCurveRegistry(BONDING_CURVE_REGISTRY).count();
        snapshot.epoch = multiVault.currentEpoch();
        (snapshot.linearVault.totalAssets, snapshot.linearVault.totalShares) =
            multiVault.getVault(EXISTING_ATOM_ID, LINEAR_CURVE_ID);
        (snapshot.offsetProgressiveVault.totalAssets, snapshot.offsetProgressiveVault.totalShares) =
            multiVault.getVault(EXISTING_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID);
        snapshot.atomWallet = multiVault.computeAtomWalletAddr(EXISTING_ATOM_ID);
        (snapshot.admin,,,,,,,) = multiVault.generalConfig();
        (snapshot.registry, snapshot.defaultCurveId) = multiVault.bondingCurveConfig();
        snapshot.atomCost = multiVault.getAtomCost();
        snapshot.tripleCost = multiVault.getTripleCost();
    }

    function _snapshotTrustBonding() internal view returns (TrustBondingSnapshot memory snapshot) {
        snapshot.epoch = trustBonding.currentEpoch();
        snapshot.epochLength = trustBonding.epochLength();
        snapshot.totalLocked = trustBonding.totalLocked();
        snapshot.totalBondedBalance = trustBonding.totalBondedBalance();
        snapshot.emissions = trustBonding.emissionsForEpoch(snapshot.epoch);
        (snapshot.systemApy, snapshot.systemMaxApy) = trustBonding.getSystemApy();
        (snapshot.holderApy, snapshot.holderMaxApy) = trustBonding.getUserApy(TRUST_BONDING_HOLDER);
    }

    /* =================================================== */
    /*                    Action helpers                   */
    /* =================================================== */

    function _depositAndRedeemFully(address user, uint256 curveId) internal {
        uint256 balanceBefore = user.balance;
        uint256 shares = _deposit(user, EXISTING_ATOM_ID, curveId, DEPOSIT_AMOUNT);
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, curveId), shares, "deposited shares held");

        vm.prank(user);
        uint256 assets = multiVault.redeem(user, EXISTING_ATOM_ID, curveId, shares, 0);

        assertGt(assets, 0, "redeem returned assets");
        assertLt(assets, DEPOSIT_AMOUNT, "round trip pays fees");
        assertEq(multiVault.getShares(user, EXISTING_ATOM_ID, curveId), 0, "all shares redeemed");
        assertEq(user.balance, balanceBefore - DEPOSIT_AMOUNT + assets, "redeemed assets paid out");
    }

    function _redeemLegacyPositionFully(uint256 curveId, uint256 legacyShares) internal {
        assertEq(multiVault.getShares(legacyDepositor, EXISTING_ATOM_ID, curveId), legacyShares, "legacy shares");
        (uint256 expectedAssets,) = multiVault.previewRedeem(EXISTING_ATOM_ID, curveId, legacyShares);
        uint256 balanceBefore = legacyDepositor.balance;

        vm.prank(legacyDepositor);
        uint256 assets = multiVault.redeem(legacyDepositor, EXISTING_ATOM_ID, curveId, legacyShares, 0);

        assertGt(assets, 0, "legacy redeem returned assets");
        assertEq(assets, expectedAssets, "legacy redeem matches preview");
        assertEq(multiVault.getShares(legacyDepositor, EXISTING_ATOM_ID, curveId), 0, "legacy position closed");
        assertEq(legacyDepositor.balance, balanceBefore + assets, "legacy assets paid out");
    }

    function _assertPreviewsMatch(address user, uint256 curveId) internal {
        (uint256 previewShares,) = multiVault.previewDeposit(EXISTING_ATOM_ID, curveId, DEPOSIT_AMOUNT);
        uint256 shares = _deposit(user, EXISTING_ATOM_ID, curveId, DEPOSIT_AMOUNT);
        assertEq(shares, previewShares, "deposit matches previewDeposit");

        uint256 redeemShares = shares / 2;
        (uint256 previewAssets, uint256 previewSharesUsed) =
            multiVault.previewRedeem(EXISTING_ATOM_ID, curveId, redeemShares);
        assertEq(previewSharesUsed, redeemShares, "previewRedeem shares used");

        vm.prank(user);
        uint256 assets = multiVault.redeem(user, EXISTING_ATOM_ID, curveId, redeemShares, 0);
        assertEq(assets, previewAssets, "redeem matches previewRedeem");
    }

    function _assertSettersRejectCaller(address caller) internal {
        GeneralConfig memory generalConfig = multiVault.getGeneralConfig();
        AtomConfig memory atomConfig = multiVault.getAtomConfig();
        TripleConfig memory tripleConfig = multiVault.getTripleConfig();
        WalletConfig memory walletConfig = multiVault.getWalletConfig();
        VaultFees memory vaultFees = multiVault.getVaultFees();
        BondingCurveConfig memory bondingCurveConfig = multiVault.getBondingCurveConfig();
        bytes memory onlyTimelock = abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector);

        vm.startPrank(caller);
        vm.expectRevert(onlyTimelock);
        multiVault.setGeneralConfig(generalConfig);
        vm.expectRevert(onlyTimelock);
        multiVault.setAtomConfig(atomConfig);
        vm.expectRevert(onlyTimelock);
        multiVault.setAtomUriConfig(DEFAULT_MAX_URI_COUNT, DEFAULT_MAX_URI_LENGTH);
        vm.expectRevert(onlyTimelock);
        multiVault.setTripleConfig(tripleConfig);
        vm.expectRevert(onlyTimelock);
        multiVault.setWalletConfig(walletConfig);
        vm.expectRevert(onlyTimelock);
        multiVault.setVaultFees(vaultFees);
        vm.expectRevert(onlyTimelock);
        multiVault.setBondingCurveConfig(bondingCurveConfig);
        vm.expectRevert(onlyTimelock);
        multiVault.setTimelock(caller);
        vm.stopPrank();
    }

    function _registerAffiliate() internal returns (address affiliate, address feeRecipient) {
        affiliate = makeAddr("replay-affiliate");
        feeRecipient = makeAddr("replay-affiliate-fee-recipient");
        vm.deal(affiliate, EXPECTED_REGISTRATION_FEE);
        FeeConfig memory fees = _affiliateFees();

        vm.prank(affiliate);
        address registered = feeProxy.registerAffiliate{ value: EXPECTED_REGISTRATION_FEE }(fees, feeRecipient);
        assertEq(registered, affiliate, "registered affiliate");
    }

    function _depositVia(address user, address affiliate, uint256 grossAssets) internal returns (uint256 shares) {
        FeeGuard memory depositGuard = _depositFeeGuard();

        vm.prank(user);
        shares = feeProxy.depositVia{ value: grossAssets }(
            affiliate, user, EXISTING_ATOM_ID, LINEAR_CURVE_ID, grossAssets, 0, depositGuard
        );
    }

    function _approveFeeProxy(address user) internal {
        vm.prank(user);
        multiVault.approve(FEE_PROXY, ApprovalTypes.DEPOSIT_AND_CREATION);
        assertTrue(multiVault.isApprovedToDeposit(FEE_PROXY, user), "FeeProxy approved to deposit");
        assertTrue(multiVault.isApprovedToCreate(FEE_PROXY, user), "FeeProxy approved to create");
    }

    function _deposit(address user, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256 shares) {
        vm.prank(user);
        shares = multiVault.deposit{ value: amount }(user, termId, curveId, 0);
        assertGt(shares, 0, "deposit minted shares");
    }

    function _createAtom(address creator, string memory atomLabel) internal returns (bytes32 atomId) {
        uint256 atomAssets = multiVault.getAtomCost() + ATOM_EXTRA_ASSETS;
        bytes[] memory atomDatas = _singleBytes(bytes(atomLabel));
        uint256[] memory amounts = _singleAmount(atomAssets);

        vm.prank(creator);
        bytes32[] memory atomIds = multiVault.createAtoms{ value: atomAssets }(atomDatas, amounts);
        atomId = atomIds[0];
    }

    function _fundedUser(string memory label) internal returns (address user) {
        user = makeAddr(label);
        vm.deal(user, USER_FUNDING);
    }

    /* =================================================== */
    /*                    Pure helpers                     */
    /* =================================================== */

    function _affiliateFees() internal pure returns (FeeConfig memory) {
        return FeeConfig({
            depositBps: AFFILIATE_DEPOSIT_BPS,
            creationBps: AFFILIATE_CREATION_BPS,
            depositFixedFee: AFFILIATE_DEPOSIT_FIXED_FEE,
            creationFixedFee: AFFILIATE_CREATION_FIXED_FEE
        });
    }

    function _depositFeeGuard() internal pure returns (FeeGuard memory) {
        return FeeGuard({ maxFeeBps: AFFILIATE_DEPOSIT_BPS, maxFixedFee: AFFILIATE_DEPOSIT_FIXED_FEE });
    }

    function _creationFeeGuard() internal pure returns (FeeGuard memory) {
        return FeeGuard({ maxFeeBps: AFFILIATE_CREATION_BPS, maxFixedFee: AFFILIATE_CREATION_FIXED_FEE });
    }

    function _implementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function _currentImplementations() internal view returns (ImplementationSet memory implementations) {
        implementations.multiVault = _implementation(MULTIVAULT_PROXY);
        implementations.trustBonding = _implementation(TRUST_BONDING_PROXY);
        implementations.atomWarden = _implementation(ATOM_WARDEN_PROXY);
        implementations.linearCurve = _implementation(LINEAR_CURVE_PROXY);
        implementations.offsetProgressiveCurve = _implementation(OFFSET_PROGRESSIVE_CURVE_PROXY);
        implementations.atomWallet = UpgradeableBeacon(ATOM_WALLET_BEACON).implementation();
    }

    /// @dev Guards against replaying on a fork where any target already runs v1.1.0 code: every pre-upgrade
    ///      assertion would then be measuring the new code, not the live one.
    function _requireNoneUpgraded(ImplementationSet memory implementations) internal pure {
        require(
            implementations.multiVault != address(0) && implementations.multiVault != NEW_MULTIVAULT_IMPL,
            "MultiVault already upgraded"
        );
        require(
            implementations.trustBonding != address(0) && implementations.trustBonding != NEW_TRUST_BONDING_IMPL,
            "TrustBonding already upgraded"
        );
        require(
            implementations.atomWarden != address(0) && implementations.atomWarden != NEW_ATOM_WARDEN_IMPL,
            "AtomWarden already upgraded"
        );
        require(
            implementations.linearCurve != address(0) && implementations.linearCurve != NEW_LINEAR_CURVE_IMPL,
            "LinearCurve already upgraded"
        );
        require(
            implementations.offsetProgressiveCurve != address(0)
                && implementations.offsetProgressiveCurve != NEW_OFFSET_PROGRESSIVE_CURVE_IMPL,
            "OffsetProgressiveCurve already upgraded"
        );
        require(
            implementations.atomWallet != address(0) && implementations.atomWallet != NEW_ATOM_WALLET_IMPL,
            "AtomWallet beacon already upgraded"
        );
    }

    function _batchTransactionData(string memory file, uint256 index) internal view returns (bytes memory) {
        string memory json = vm.readFile(string.concat(BATCH_DIR, file));
        return vm.parseJsonBytes(json, _transactionKey(index, ".data"));
    }

    function _transactionKey(uint256 index, string memory field) internal pure returns (string memory) {
        return string.concat(".transactions[", vm.toString(index), "]", field);
    }

    function _assertVaultEq(VaultSnapshot memory actual, VaultSnapshot memory expected, string memory label)
        internal
        pure
    {
        assertEq(actual.totalAssets, expected.totalAssets, string.concat(label, ": totalAssets"));
        assertEq(actual.totalShares, expected.totalShares, string.concat(label, ": totalShares"));
    }

    function _singleBytes(bytes memory value) internal pure returns (bytes[] memory values) {
        values = new bytes[](1);
        values[0] = value;
    }

    function _singleAmount(uint256 amount) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = amount;
    }

    function _singleId(bytes32 id) internal pure returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = id;
    }

    /// @dev Drops the 4-byte selector so the remainder can be `abi.decode`d.
    function _stripSelector(bytes memory data) internal pure returns (bytes memory stripped) {
        require(data.length >= 4, "calldata too short");
        stripped = new bytes(data.length - 4);
        for (uint256 i = 0; i < stripped.length; ++i) {
            stripped[i] = data[i + 4];
        }
    }
}
