// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { LinearCurve } from "src/protocol/curves/LinearCurve.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { GeneralConfig } from "src/interfaces/IMultiVaultCore.sol";
import { IMultiVault, ApprovalTypes } from "src/interfaces/IMultiVault.sol";

/// @title  MultiVault v1.1.0 Upgrade Regression
/// @author 0xIntuition
/// @notice Fork-based regression for the v1.1.0 MultiVault core upgrade. Verifies the upgrade preserves
///         pre-upgrade state and activates the new surface: RBAC + timelock config gating, atom-creator
///         attribution, on-behalf-of `createAtomsFor` / `createTriplesFor`, canonical and payable
///         multicall value accounting, MultiVaultLib-extraction legacy write-flow parity, and the
///         system-utilization rollover replay / self-heal guard (#623, carry source at slot 37).
/// @dev    Forks Intuition Mainnet. Part of the v1.1.0 upgrade-regression set, grouped under
///         `tests/unit/upgrades/v1.1.0/` (mirroring the v1.0.2 grouping of `CoreMainnetUpgradeRegression`).
/// @custom:upgrade v1.1.0
contract MultiVaultUpgradeRegressionTest is Test {
    // --- Intuition Mainnet addresses (chain ID 1155) ---
    // These should be updated to mainnet addresses for production regression testing
    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant PROXY_ADMIN = 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8;
    address internal constant LINEAR_CURVE_PROXY = 0xc3eFD5471dc63d74639725f381f9686e3F264366;
    address internal constant LINEAR_CURVE_PROXY_ADMIN = 0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c;
    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY = 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d;
    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN = 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7;
    uint256 internal constant INTUITION_FORK_BLOCK = 2_369_449;
    uint256 internal constant OFFSET_PROGRESSIVE_CURVE_ID = 2;
    uint256 internal constant TOTAL_UTILIZATION_SLOT = 30;
    uint256 internal constant HAS_ROLLED_OVER_SYSTEM_UTILIZATION_SLOT = 33;
    uint256 internal constant LAST_SYSTEM_UTILIZATION_EPOCH_SLOT = 37;

    struct VaultCheckpoint {
        uint256 totalAssets;
        uint256 totalShares;
        uint256 userShares;
    }

    struct LegacyBaseline {
        uint256 epoch;
        uint256 totalTerms;
        uint256 protocolFees;
        uint256 atomWalletFees;
        int256 totalUtilization;
        int256 userUtilization;
    }

    struct LegacyTerms {
        bytes32 atomOne;
        bytes32 atomTwo;
        bytes32 atomThree;
        bytes32 tripleId;
        address atomWallet;
    }

    struct LegacyActions {
        uint256 atomDefaultSharesMinted;
        uint256 atomOffsetSharesMinted;
        uint256 tripleDefaultSharesMinted;
        uint256 tripleOffsetSharesMinted;
        uint256 atomRedeemAssets;
        uint256 tripleRedeemAssets;
    }

    // --- State snapshots ---
    MultiVault internal multiVault;
    ProxyAdmin internal proxyAdmin;

    // Pre-upgrade state
    uint256 internal preUpgradeTotalTerms;
    address internal preUpgradeAdmin;
    address internal preUpgradeMultisig;
    uint256 internal preUpgradeFeeDenominator;
    uint256 internal preUpgradeMinDeposit;

    function setUp() external {
        vm.createSelectFork("intuition", INTUITION_FORK_BLOCK);

        multiVault = MultiVault(MULTIVAULT_PROXY);
        proxyAdmin = ProxyAdmin(PROXY_ADMIN);

        // Snapshot pre-upgrade state
        preUpgradeTotalTerms = multiVault.totalTermsCreated();
        (preUpgradeAdmin, preUpgradeMultisig, preUpgradeFeeDenominator,, preUpgradeMinDeposit,,,) =
            multiVault.generalConfig();
    }

    function test_upgradePreservesStateAndActivatesRBAC() external {
        _upgradeMultiVault();

        // 3. Verify state preserved
        assertEq(multiVault.totalTermsCreated(), preUpgradeTotalTerms, "totalTermsCreated changed");
        (address admin, address multisig, uint256 feeDenom,, uint256 minDep,,,) = multiVault.generalConfig();
        assertEq(admin, preUpgradeAdmin, "admin changed");
        assertEq(multisig, preUpgradeMultisig, "protocolMultisig changed");
        assertEq(feeDenom, preUpgradeFeeDenominator, "feeDenominator changed");
        assertEq(minDep, preUpgradeMinDeposit, "minDeposit changed");

        // 4. Verify timelock is unset (zero before reinitialize)
        assertEq(multiVault.timelock(), address(0), "timelock should be zero before reinitialize");

        // 5. Admin calls reinitialize to set timelock
        assertTrue(
            multiVault.hasRole(multiVault.DEFAULT_ADMIN_ROLE(), preUpgradeAdmin),
            "preUpgradeAdmin must hold DEFAULT_ADMIN_ROLE"
        );
        vm.startPrank(preUpgradeAdmin);
        multiVault.reinitialize(preUpgradeAdmin); // Set admin as initial timelock
        vm.stopPrank();

        assertEq(multiVault.timelock(), preUpgradeAdmin, "timelock should be admin after reinitialize");

        // 6. Verify config setters now require timelock (admin IS the timelock temporarily)
        vm.startPrank(preUpgradeAdmin);
        GeneralConfig memory gc = GeneralConfig({
            admin: preUpgradeAdmin,
            protocolMultisig: preUpgradeMultisig,
            feeDenominator: preUpgradeFeeDenominator,
            trustBonding: address(0),
            minDeposit: preUpgradeMinDeposit + 1,
            minShare: 0,
            atomDataMaxLength: 0,
            feeThreshold: 0
        });
        // This should succeed since admin is currently the timelock
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // 7. Non-timelock user cannot call config setters
        address randomUser = makeAddr("random");
        vm.startPrank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // 8. Verify reinitialize granted PAUSER_ROLE to admin and pause works
        assertTrue(multiVault.hasRole(multiVault.PAUSER_ROLE(), preUpgradeAdmin), "admin should have PAUSER_ROLE");
        vm.startPrank(preUpgradeAdmin);
        multiVault.pause();
        assertTrue(multiVault.paused(), "should be paused");
        multiVault.unpause();
        assertFalse(multiVault.paused(), "should be unpaused");
        vm.stopPrank();

        // 9. User without PAUSER_ROLE cannot pause
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, multiVault.PAUSER_ROLE()
            )
        );
        multiVault.pause();
        vm.stopPrank();

        // 10. Transfer timelock to a new address and verify old timelock loses access
        address newTimelock = makeAddr("newTimelock");
        vm.startPrank(preUpgradeAdmin);
        multiVault.setTimelock(newTimelock);
        vm.stopPrank();

        assertEq(multiVault.timelock(), newTimelock, "timelock should be updated");

        // Old timelock (admin) can no longer call config setters
        vm.startPrank(preUpgradeAdmin);
        vm.expectRevert(abi.encodeWithSelector(MultiVault.MultiVault_OnlyTimelock.selector));
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();

        // New timelock can call config setters
        vm.startPrank(newTimelock);
        multiVault.setGeneralConfig(gc);
        vm.stopPrank();
    }

    function test_reinitializeCannotBeCalledTwice() external {
        _upgradeMultiVault();

        // First reinitialize succeeds
        vm.startPrank(preUpgradeAdmin);
        multiVault.reinitialize(preUpgradeAdmin);

        // Second reinitialize reverts
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        multiVault.reinitialize(preUpgradeAdmin);
        vm.stopPrank();
    }

    function test_reinitializeRevertsForNonAdmin() external {
        _upgradeMultiVault();

        // Non-admin cannot call reinitialize
        address randomUser = makeAddr("random");
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, multiVault.DEFAULT_ADMIN_ROLE()
            )
        );
        multiVault.reinitialize(randomUser);
        vm.stopPrank();
    }

    function test_upgrade_enablesCreatorAttributionForNewAtoms() external {
        bytes memory atomData = bytes("upgrade-regression-creator-atom");
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;

        _upgradeMultiVault();

        address creator = makeAddr("creator");
        vm.deal(creator, 10 ether);
        uint256 atomCost = multiVault.getAtomCost();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;

        vm.prank(creator);
        multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);

        bytes32 atomId = multiVault.calculateAtomId(atomData);
        assertEq(multiVault.getAtomCreator(atomId), creator, "creator attribution should be recorded");
        assertEq(multiVault.getAtomCreatedAt(atomId), uint48(block.timestamp), "creation time should be recorded");
    }

    function test_upgrade_enablesUriAwareCreationWithSafeDefaults() external {
        _upgradeMultiVault();

        (uint32 maxUriCount, uint32 maxUriLength) = multiVault.getAtomUriConfig();
        assertEq(maxUriCount, 5, "zeroed upgrade slot must resolve to default URI count");
        assertEq(maxUriLength, 700, "zeroed upgrade slot must resolve to default URI length");

        address creator = makeAddr("uri-creator");
        uint256 atomCost = multiVault.getAtomCost();
        vm.deal(creator, atomCost * 2);

        bytes[] memory atomDatas = new bytes[](1);
        atomDatas[0] = bytes("upgrade-regression-uri-atom");
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;
        bytes[][] memory uris = new bytes[][](1);
        uris[0] = new bytes[](1);
        uris[0][0] = bytes("ipfs://upgrade-regression");

        vm.prank(creator);
        bytes32[] memory ids = multiVault.createAtomsWithUris{ value: atomCost }(creator, atomDatas, assets, uris);

        assertEq(ids[0], multiVault.calculateAtomId(atomDatas[0]), "URI context must not affect identity");
        assertEq(multiVault.getAtomCreator(ids[0]), creator, "URI-aware creation must preserve attribution");

        atomDatas[0] = bytes("upgrade-regression-too-many-uris");
        uris[0] = new bytes[](6);
        vm.prank(creator);
        vm.expectRevert(MultiVault.MultiVault_AtomUriCountExceeded.selector);
        multiVault.createAtomsWithUris{ value: atomCost }(creator, atomDatas, assets, uris);
    }

    function test_upgrade_preservesLegacyWriteFlowBehaviorAcrossMultiVaultLibExtraction() external {
        uint256 cleanFork = vm.snapshotState();

        bytes32 preUpgradeOutcome = _runLegacyWriteFlow("legacy-write-flow");

        require(vm.revertToState(cleanFork), "failed to revert to clean fork state");
        _upgradeMultiVault();
        bytes32 postUpgradeOutcome = _runLegacyWriteFlow("legacy-write-flow");

        assertEq(postUpgradeOutcome, preUpgradeOutcome, "legacy write-flow outcome changed across upgrade");
    }

    function test_upgrade_createForOnBehalf_recordsCreatorAndCreditsCreatorUtilization() external {
        _upgradeMultiVault();

        address creator = makeAddr("on-behalf-creator");
        address operator = makeAddr("on-behalf-operator");
        vm.deal(operator, 20 ether);

        vm.prank(creator);
        multiVault.approve(operator, ApprovalTypes.CREATION);

        _assertCreateAtomsForCreditsCreator(creator, operator);
        _assertCreateTriplesForCreditsCreator(creator, operator);
    }

    function _assertCreateAtomsForCreditsCreator(address creator, address operator) internal {
        uint256 epoch = multiVault.currentEpoch();
        int256 creatorUtilizationBefore = multiVault.getUserUtilizationForEpoch(creator, epoch);
        int256 operatorUtilizationBefore = multiVault.getUserUtilizationForEpoch(operator, epoch);

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = bytes("upgrade-regression-createAtomsFor-atom");

        uint256 atomCost = multiVault.getAtomCost();
        uint256[] memory atomAmounts = new uint256[](1);
        atomAmounts[0] = atomCost;

        vm.prank(operator);
        bytes32[] memory atomIds = multiVault.createAtomsFor{ value: atomCost }(creator, atomDataArray, atomAmounts);

        assertEq(multiVault.getAtomCreator(atomIds[0]), creator, "createAtomsFor must record supplied creator");
        assertEq(multiVault.getAtomCreatedAt(atomIds[0]), uint48(block.timestamp), "createAtomsFor must record time");
        assertEq(
            multiVault.getUserUtilizationForEpoch(creator, epoch),
            creatorUtilizationBefore + int256(atomCost),
            "createAtomsFor must credit creator utilization"
        );
        assertEq(
            multiVault.getUserUtilizationForEpoch(operator, epoch),
            operatorUtilizationBefore,
            "createAtomsFor must not credit operator utilization"
        );
    }

    function _assertCreateTriplesForCreditsCreator(address creator, address operator) internal {
        uint256 epoch = multiVault.currentEpoch();
        uint256 tripleCost = multiVault.getTripleCost();
        uint256[] memory tripleAmounts = new uint256[](1);
        tripleAmounts[0] = tripleCost;

        (bytes32[] memory subjectIds, bytes32[] memory predicateIds, bytes32[] memory objectIds) = _singleTripleArrays(
            _createAtom(creator, "upgrade-regression-createTriplesFor-subject"),
            _createAtom(creator, "upgrade-regression-createTriplesFor-predicate"),
            _createAtom(creator, "upgrade-regression-createTriplesFor-object")
        );
        int256 creatorUtilizationBefore = multiVault.getUserUtilizationForEpoch(creator, epoch);
        int256 operatorUtilizationBefore = multiVault.getUserUtilizationForEpoch(operator, epoch);

        vm.prank(operator);
        bytes32[] memory tripleIds = multiVault.createTriplesFor{ value: tripleCost }(
            creator, subjectIds, predicateIds, objectIds, tripleAmounts
        );

        assertTrue(multiVault.isTermCreated(tripleIds[0]), "createTriplesFor must create triple");
        assertEq(
            multiVault.getUserUtilizationForEpoch(creator, epoch),
            creatorUtilizationBefore + int256(tripleCost),
            "createTriplesFor must credit creator utilization"
        );
        assertEq(
            multiVault.getUserUtilizationForEpoch(operator, epoch),
            operatorUtilizationBefore,
            "createTriplesFor must not credit operator utilization"
        );
    }

    function test_upgrade_multicallRedeemsAndPayableMulticallAccountsValues() external {
        _upgradeMultiVault();

        _assertCanonicalMulticallRedeems();
        _assertPayableMulticallCreatesDepositsAndCreatesFor();
    }

    function test_upgrade_systemUtilizationRolloverCannotReplayAfterZeroCrossing() external {
        _upgradeMultiVault();

        uint256 epoch = multiVault.currentEpoch();
        assertGt(epoch, 0, "rollover regression requires current epoch > 0");

        int256 previousEpochUtilization = 100 ether;
        vm.store(MULTIVAULT_PROXY, _totalUtilizationSlot(epoch - 1), bytes32(uint256(previousEpochUtilization)));
        vm.store(MULTIVAULT_PROXY, _totalUtilizationSlot(epoch), bytes32(0));
        vm.store(MULTIVAULT_PROXY, _hasRolledOverSystemUtilizationSlot(epoch), bytes32(0));
        // The self-healing rollover (no-activity-epoch defense) sources the carry from
        // `lastSystemUtilizationEpoch` (slot 37), not `epoch - 1`. Point it at the seeded previous
        // epoch so the carry-forward is deterministic against forked state.
        vm.store(MULTIVAULT_PROXY, bytes32(LAST_SYSTEM_UTILIZATION_EPOCH_SLOT), bytes32(epoch - 1));

        // Precondition: confirm the seeded state is actually in effect before the first action.
        // This forks an old block from a public (non-archive) RPC; if a flaky archive read ever
        // serves inconsistent storage, fail here with a clear message instead of silently carrying
        // a real on-chain baseline into the rollover assertion below.
        assertEq(
            multiVault.getTotalUtilizationForEpoch(epoch - 1),
            previousEpochUtilization,
            "seed precondition: previous-epoch utilization must equal the seeded value"
        );
        assertEq(
            multiVault.getTotalUtilizationForEpoch(epoch),
            int256(0),
            "seed precondition: current-epoch utilization must be zeroed before first action"
        );
        assertFalse(
            multiVault.hasRolledOverSystemUtilization(epoch), "seed precondition: rollover guard must start unset"
        );
        assertEq(
            multiVault.lastSystemUtilizationEpoch(), epoch - 1, "seed precondition: carry source must be previous epoch"
        );

        uint256 firstAtomCost = multiVault.getAtomCost();
        _createAtom(makeAddr("rollover-first-actor"), "rollover-first-action");

        assertTrue(multiVault.hasRolledOverSystemUtilization(epoch), "first action must set rollover guard");
        assertEq(
            multiVault.getTotalUtilizationForEpoch(epoch),
            previousEpochUtilization + int256(firstAtomCost),
            "first action must carry previous epoch once"
        );

        vm.store(MULTIVAULT_PROXY, _totalUtilizationSlot(epoch), bytes32(0));

        uint256 secondAtomCost = multiVault.getAtomCost();
        _createAtom(makeAddr("rollover-second-actor"), "rollover-second-action");

        assertTrue(multiVault.hasRolledOverSystemUtilization(epoch), "rollover guard must remain set");
        assertEq(
            multiVault.getTotalUtilizationForEpoch(epoch),
            int256(secondAtomCost),
            "second action must not replay previous epoch utilization after zero crossing"
        );
    }

    /// @dev The full Upgrades-Timelock batch, mirroring the live governance sequence: the new
    ///      MultiVault calls the standardized fee-hook getters on the registry-resolved curve on
    ///      every deposit/redeem, so every registered curve proxy MUST be upgraded to a recompiled
    ///      implementation in the same batch — swapping MultiVault alone bricks all deposits with a
    ///      missing-selector revert. The write-flow tests below (which deposit on curve ids 1 and 2
    ///      post-upgrade) are the executable proof of that sequencing requirement.
    function _upgradeMultiVault() internal {
        MultiVault newImpl = new MultiVault();
        LinearCurve newLinearCurveImpl = new LinearCurve();
        OffsetProgressiveCurve newOffsetProgressiveCurveImpl = new OffsetProgressiveCurve();

        vm.startPrank(UPGRADES_TIMELOCK);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY)), address(newImpl), bytes(""));
        ProxyAdmin(LINEAR_CURVE_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(LINEAR_CURVE_PROXY)), address(newLinearCurveImpl), bytes("")
            );
        ProxyAdmin(OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(OFFSET_PROGRESSIVE_CURVE_PROXY)),
                address(newOffsetProgressiveCurveImpl),
                bytes("")
            );
        vm.stopPrank();
    }

    function _runLegacyWriteFlow(string memory label) internal returns (bytes32 digest) {
        address user = makeAddr(string.concat(label, "-user"));
        vm.deal(user, 200 ether);

        (, uint256 defaultCurveId) = multiVault.bondingCurveConfig();
        address atomWallet = _atomWalletForLabel(label);
        LegacyBaseline memory beforeState = _captureLegacyBaseline(user, atomWallet);
        LegacyTerms memory terms = _createLegacyTerms(label, user, atomWallet);
        LegacyActions memory actions = _runLegacyActions(user, terms, defaultCurveId);

        digest = keccak256(
            abi.encode(
                terms,
                actions,
                multiVault.totalTermsCreated() - beforeState.totalTerms,
                multiVault.accumulatedProtocolFees(beforeState.epoch) - beforeState.protocolFees,
                multiVault.accumulatedAtomWalletDepositFees(atomWallet) - beforeState.atomWalletFees,
                multiVault.getTotalUtilizationForEpoch(beforeState.epoch) - beforeState.totalUtilization,
                multiVault.getUserUtilizationForEpoch(user, beforeState.epoch) - beforeState.userUtilization
            )
        );
        digest = keccak256(abi.encode(digest, _vaultCheckpoint(user, terms.atomOne, defaultCurveId)));
        digest = keccak256(abi.encode(digest, _vaultCheckpoint(user, terms.atomTwo, OFFSET_PROGRESSIVE_CURVE_ID)));
        digest = keccak256(abi.encode(digest, _vaultCheckpoint(user, terms.tripleId, defaultCurveId)));
        digest = keccak256(abi.encode(digest, _vaultCheckpoint(user, terms.tripleId, OFFSET_PROGRESSIVE_CURVE_ID)));
    }

    function _atomWalletForLabel(string memory label) internal view returns (address) {
        return multiVault.computeAtomWalletAddr(multiVault.calculateAtomId(bytes(string.concat(label, "-atom-one"))));
    }

    function _captureLegacyBaseline(address user, address atomWallet)
        internal
        view
        returns (LegacyBaseline memory baseline)
    {
        baseline.epoch = multiVault.currentEpoch();
        baseline.totalTerms = multiVault.totalTermsCreated();
        baseline.protocolFees = multiVault.accumulatedProtocolFees(baseline.epoch);
        baseline.atomWalletFees = multiVault.accumulatedAtomWalletDepositFees(atomWallet);
        baseline.totalUtilization = multiVault.getTotalUtilizationForEpoch(baseline.epoch);
        baseline.userUtilization = multiVault.getUserUtilizationForEpoch(user, baseline.epoch);
    }

    function _createLegacyTerms(string memory label, address user, address atomWallet)
        internal
        returns (LegacyTerms memory terms)
    {
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = bytes(string.concat(label, "-atom-one"));
        atomDataArray[1] = bytes(string.concat(label, "-atom-two"));
        atomDataArray[2] = bytes(string.concat(label, "-atom-three"));

        uint256 atomCost = multiVault.getAtomCost();
        uint256[] memory atomAmounts = _uniformAmounts(3, atomCost);

        vm.prank(user);
        bytes32[] memory atomIds = multiVault.createAtoms{ value: atomCost * 3 }(atomDataArray, atomAmounts);
        terms.atomOne = atomIds[0];
        terms.atomTwo = atomIds[1];
        terms.atomThree = atomIds[2];
        terms.atomWallet = atomWallet;
        assertEq(multiVault.computeAtomWalletAddr(terms.atomOne), terms.atomWallet, "atom wallet drifted");

        uint256 tripleCost = multiVault.getTripleCost();
        (bytes32[] memory subjectIds, bytes32[] memory predicateIds, bytes32[] memory objectIds) =
            _singleTripleArrays(terms.atomOne, terms.atomTwo, terms.atomThree);

        vm.prank(user);
        bytes32[] memory tripleIds = multiVault.createTriples{ value: tripleCost }(
            subjectIds, predicateIds, objectIds, _uniformAmounts(1, tripleCost)
        );
        terms.tripleId = tripleIds[0];
    }

    function _runLegacyActions(address user, LegacyTerms memory terms, uint256 defaultCurveId)
        internal
        returns (LegacyActions memory actions)
    {
        actions.atomDefaultSharesMinted = _deposit(user, terms.atomOne, defaultCurveId, 4 ether);
        actions.atomOffsetSharesMinted = _deposit(user, terms.atomTwo, OFFSET_PROGRESSIVE_CURVE_ID, 7 ether);
        actions.tripleDefaultSharesMinted = _deposit(user, terms.tripleId, defaultCurveId, 6 ether);
        actions.tripleOffsetSharesMinted = _deposit(user, terms.tripleId, OFFSET_PROGRESSIVE_CURVE_ID, 9 ether);

        actions.atomRedeemAssets = _redeem(user, terms.atomOne, defaultCurveId, actions.atomDefaultSharesMinted / 2);
        actions.tripleRedeemAssets =
            _redeem(user, terms.tripleId, OFFSET_PROGRESSIVE_CURVE_ID, actions.tripleOffsetSharesMinted / 2);
    }

    function _assertCanonicalMulticallRedeems() internal {
        address user = makeAddr("canonical-multicall-user");
        (, uint256 defaultCurveId) = multiVault.bondingCurveConfig();

        bytes32 atomOne = _createAtom(user, "canonical-multicall-atom-one");
        bytes32 atomTwo = _createAtom(user, "canonical-multicall-atom-two");

        _deposit(user, atomOne, defaultCurveId, 3 ether);
        _deposit(user, atomTwo, defaultCurveId, 4 ether);

        uint256 atomOneSharesBefore = multiVault.getShares(user, atomOne, defaultCurveId);
        uint256 atomTwoSharesBefore = multiVault.getShares(user, atomTwo, defaultCurveId);
        uint256 redeemOneShares = atomOneSharesBefore / 3;
        uint256 redeemTwoShares = atomTwoSharesBefore / 3;
        assertGt(redeemOneShares, 0, "first redeem shares must be non-zero");
        assertGt(redeemTwoShares, 0, "second redeem shares must be non-zero");

        (uint256 expectedAssetsOne,) = multiVault.previewRedeem(atomOne, defaultCurveId, redeemOneShares);
        (uint256 expectedAssetsTwo,) = multiVault.previewRedeem(atomTwo, defaultCurveId, redeemTwoShares);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(IMultiVault.redeem, (user, atomOne, defaultCurveId, redeemOneShares, 0));
        data[1] = abi.encodeCall(IMultiVault.redeem, (user, atomTwo, defaultCurveId, redeemTwoShares, 0));

        vm.prank(user);
        bytes[] memory results = multiVault.multicall(data, new uint256[](data.length));

        assertEq(abi.decode(results[0], (uint256)), expectedAssetsOne, "first multicall redeem assets mismatch");
        assertEq(abi.decode(results[1], (uint256)), expectedAssetsTwo, "second multicall redeem assets mismatch");
        assertEq(multiVault.getShares(user, atomOne, defaultCurveId), atomOneSharesBefore - redeemOneShares);
        assertEq(multiVault.getShares(user, atomTwo, defaultCurveId), atomTwoSharesBefore - redeemTwoShares);
    }

    function _assertPayableMulticallCreatesDepositsAndCreatesFor() internal {
        address operator = makeAddr("payable-multicall-operator");
        address creator = makeAddr("payable-multicall-creator");
        vm.deal(operator, 50 ether);

        vm.prank(creator);
        multiVault.approve(operator, ApprovalTypes.CREATION);

        (, uint256 defaultCurveId) = multiVault.bondingCurveConfig();
        uint256 epoch = multiVault.currentEpoch();
        int256 creatorUtilizationBefore = multiVault.getUserUtilizationForEpoch(creator, epoch);

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = bytes("payable-multicall-created-atom");
        bytes32 atomId = multiVault.calculateAtomId(atomDataArray[0]);

        bytes[] memory creatorAtomDataArray = new bytes[](1);
        creatorAtomDataArray[0] = bytes("payable-multicall-created-for-atom");
        bytes32 creatorAtomId = multiVault.calculateAtomId(creatorAtomDataArray[0]);

        uint256 atomCost = multiVault.getAtomCost();
        uint256 depositAmount = 3 ether;

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(IMultiVault.createAtoms, (atomDataArray, _uniformAmounts(1, atomCost)));
        data[1] = abi.encodeCall(IMultiVault.deposit, (operator, atomId, defaultCurveId, 0));
        data[2] =
            abi.encodeCall(IMultiVault.createAtomsFor, (creator, creatorAtomDataArray, _uniformAmounts(1, atomCost)));

        uint256[] memory values = new uint256[](3);
        values[0] = atomCost;
        values[1] = depositAmount;
        values[2] = atomCost;

        vm.prank(operator);
        multiVault.multicall{ value: atomCost + depositAmount + atomCost }(data, values);

        assertTrue(multiVault.isTermCreated(atomId), "multicall must create first atom");
        assertTrue(multiVault.isTermCreated(creatorAtomId), "multicall must create creator atom");
        assertGt(multiVault.getShares(operator, atomId, defaultCurveId), 0, "multicall deposit must mint shares");
        assertEq(multiVault.getAtomCreator(atomId), operator, "direct create sub-call must record operator");
        assertEq(multiVault.getAtomCreator(creatorAtomId), creator, "createAtomsFor sub-call must record creator");
        assertEq(
            multiVault.getUserUtilizationForEpoch(creator, epoch),
            creatorUtilizationBefore + int256(atomCost),
            "createAtomsFor sub-call must credit creator utilization"
        );
    }

    function _deposit(address user, bytes32 termId, uint256 curveId, uint256 amount) internal returns (uint256 shares) {
        vm.prank(user);
        shares = multiVault.deposit{ value: amount }(user, termId, curveId, 0);
        assertGt(shares, 1, "deposit must mint enough shares for partial redeem");
    }

    function _redeem(address user, bytes32 termId, uint256 curveId, uint256 shares) internal returns (uint256 assets) {
        assertGt(shares, 0, "redeem shares must be non-zero");
        vm.prank(user);
        assets = multiVault.redeem(user, termId, curveId, shares, 0);
        assertGt(assets, 0, "redeem must return assets");
    }

    function _createAtom(address user, string memory atomLabel) internal returns (bytes32 atomId) {
        uint256 atomCost = multiVault.getAtomCost();
        vm.deal(user, user.balance + atomCost + 10 ether);

        bytes[] memory data = new bytes[](1);
        data[0] = bytes(atomLabel);

        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.prank(user);
        bytes32[] memory atomIds = multiVault.createAtoms{ value: atomCost }(data, assets);

        atomId = atomIds[0];
    }

    function _vaultCheckpoint(address user, bytes32 termId, uint256 curveId)
        internal
        view
        returns (VaultCheckpoint memory checkpoint)
    {
        (checkpoint.totalAssets, checkpoint.totalShares) = multiVault.getVault(termId, curveId);
        checkpoint.userShares = multiVault.getShares(user, termId, curveId);
    }

    function _singleTripleArrays(bytes32 subjectId, bytes32 predicateId, bytes32 objectId)
        internal
        pure
        returns (bytes32[] memory subjectIds, bytes32[] memory predicateIds, bytes32[] memory objectIds)
    {
        subjectIds = new bytes32[](1);
        predicateIds = new bytes32[](1);
        objectIds = new bytes32[](1);
        subjectIds[0] = subjectId;
        predicateIds[0] = predicateId;
        objectIds[0] = objectId;
    }

    function _uniformAmounts(uint256 length, uint256 amount) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amount;
        }
    }

    function _totalUtilizationSlot(uint256 epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(epoch, TOTAL_UTILIZATION_SLOT));
    }

    function _hasRolledOverSystemUtilizationSlot(uint256 epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(epoch, HAS_ROLLED_OVER_SYSTEM_UTILIZATION_SLOT));
    }
}
