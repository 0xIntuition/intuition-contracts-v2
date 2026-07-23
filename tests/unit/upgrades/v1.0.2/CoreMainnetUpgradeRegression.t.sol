// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { console2 } from "forge-std/src/console2.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_FAILED, _packValidationData } from "@account-abstraction/core/Helpers.sol";
import { MultiVault } from "src/protocol/MultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";
import { IMultiVaultCore, GeneralConfig, BondingCurveConfig } from "src/interfaces/IMultiVaultCore.sol";

interface ILegacyAtomWalletOwnership {
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}

/// @title  CoreMainnetUpgradeRegressionTest (v1.0.2 baseline)
/// @notice Cross-contract "in-unison" mainnet upgrade regression. Forks the pre-v1.0.2 baseline
///         (intuition block 3_208_388 / base block 45_206_800), captures the pre-upgrade state, applies
///         the core implementations in unison, and asserts the post-upgrade surface. The pre-upgrade
///         assertions are pinned to that baseline, so newer fork blocks (past the v1.0.2 deploy) will
///         break them. v1.1.0-specific upgrade regression lives in the MultiVault / AtomWarden
///         UpgradeRegression suites and MultiVaultStorageLayout.
contract CoreMainnetUpgradeRegressionTest is Test {
    struct CoreImplementations {
        address trustBonding;
        address offsetProgressiveCurve;
        address atomWarden;
        address atomWallet;
        address satelliteEmissionsController;
    }

    struct StorageSnapshot {
        bytes32[7] tbCoreSlots;
        bytes32[3] atomWalletCoreSlots;
        bytes32[5] offsetCurveCoreSlots;
    }

    struct AtomWalletState {
        address owner;
        address multiVault;
        address entryPoint;
        bytes32 termId;
        bool isClaimed;
    }

    struct EpochSnapshot {
        uint256 startTimestamp;
        uint256 epochLength;
        uint256 currentEpoch;
        uint256 currentEpochStart;
        uint256 currentEpochEnd;
        uint256 nextEpochStart;
    }

    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    // Intuition mainnet governance
    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant ADMIN_SAFE = 0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb;

    // Base mainnet governance
    address internal constant BASE_UPGRADES_TIMELOCK = 0x1E442BbB08c98100b18fa830a88E8A57b5dF9157;

    // Live protocol dependencies on Intuition mainnet.
    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant TRUST_BONDING_PROXY_ADMIN = 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62;

    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY = 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d;
    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN = 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7;

    address internal constant ATOM_WARDEN_PROXY = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;
    address internal constant ATOM_WARDEN_PROXY_ADMIN = 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A;
    address internal constant ATOM_WALLET_BEACON = 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF;
    address internal constant ATOM_WALLET_FACTORY = 0x33827373a7D1c7C78a01094071C2f6CE74253B9B;

    // Emissions controller proxies
    address internal constant SATELLITE_EMISSIONS_CONTROLLER_PROXY = 0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6;
    address internal constant SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN = 0xdF60D18E86F3454309aD7734055843F7ee5f30a3;
    address internal constant BASE_EMISSIONS_CONTROLLER_PROXY = 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667;
    address internal constant BASE_EMISSIONS_CONTROLLER_PROXY_ADMIN = 0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a;

    // Predeployed upgrade implementations supplied by deployment output.
    address internal constant TRUST_BONDING_IMPLEMENTATION = 0xd1716D4430466397Fc88e938e97C7e12adcEcF24;
    address internal constant OFFSET_PROGRESSIVE_CURVE_IMPLEMENTATION = 0xea5B87984253AE3D8472df3738e5Ad421297c246;
    address internal constant ATOM_WALLET_IMPLEMENTATION = 0xbCb1526A8de4a155e4dE003361b122eDe2f22908;
    address internal constant SATELLITE_EMISSIONS_CONTROLLER_IMPLEMENTATION =
        0x0D1a22119c23920d24DCcF5387EAEf1E472D9639;
    address internal constant BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION = 0xd235B804f25B062D99457dA82F3787671573c355;

    // Existing atom wallet on Intuition mainnet (factory event at block 150634).
    address internal constant KNOWN_ATOM_WALLET = 0xD52d9eD3309207Ab4f696A21023c60F7947a4a56;
    bytes32 internal constant KNOWN_ATOM_ID = 0x70400f554d8b44b2b4e1edc61b42421c57844932a47efb6b3815d3e44f384730;
    address internal constant KNOWN_ATOM_WALLET_OWNER = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;

    // Core dependencies
    address internal constant WRAPPED_TRUST = 0x81cFb09cb44f7184Ad934C09F82000701A4bF672;
    address internal constant ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

    uint256 internal constant OFFSET_PROGRESSIVE_CURVE_ID = 2;
    uint256 internal constant DEFAULT_WARDEN_CLAIM_WINDOW = 365 days;
    uint256 internal constant DEFAULT_WARDEN_MIN_FEE_THRESHOLD = 0;
    uint256 internal constant DEFAULT_WARDEN_SIGNATURE_THRESHOLD = 1;
    uint48 internal constant DEFAULT_WARDEN_MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant DEFAULT_WARDEN_MAX_VALID_UNTIL = uint48(1 days);
    /// @dev 0 = authorized-claim cap disabled (baseline parity with the pre-cap deploy defaults).
    uint256 internal constant DEFAULT_WARDEN_MAX_CLAIMS_PER_WINDOW = 0;
    uint256 internal constant DEFAULT_WARDEN_CLAIM_CAP_WINDOW = 1 days;

    // Fork block numbers
    uint256 internal constant INTUITION_FORK_BLOCK = 3_208_388;
    uint256 internal constant BASE_BLOCK_NUMBER = 45_206_800;

    uint256 internal intuitionFork;
    uint256 internal baseFork;
    uint256 internal baseForkBlockNumber;

    function setUp() external {
        baseFork = vm.createFork("base", BASE_BLOCK_NUMBER);
        baseForkBlockNumber = BASE_BLOCK_NUMBER;

        intuitionFork = vm.createFork("intuition", INTUITION_FORK_BLOCK);
        _selectIntuitionFork();
        _ensureEpochAtLeastOne();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  PREFLIGHT
    //////////////////////////////////////////////////////////////*/

    function test_preflight_rolesAndUpgradeOwnership() external view {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));

        // DEFAULT_ADMIN_ROLE is held by the Safe.
        assertTrue(trustBonding.hasRole(trustBonding.DEFAULT_ADMIN_ROLE(), ADMIN_SAFE));

        // Upgrade ownership is held by the upgrades timelock.
        assertEq(ProxyAdmin(TRUST_BONDING_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(ATOM_WARDEN_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).owner(), UPGRADES_TIMELOCK);
    }

    function test_upgradeInUnison() external {
        address oldTrustBondingImpl = _implementationOf(TRUST_BONDING_PROXY);
        address oldOffsetCurveImpl = _implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY);
        address oldAtomWardenImpl = _implementationOf(ATOM_WARDEN_PROXY);
        address oldAtomWalletImpl = UpgradeableBeacon(ATOM_WALLET_BEACON).implementation();
        address oldSatelliteEmissionsImpl = _implementationOf(SATELLITE_EMISSIONS_CONTROLLER_PROXY);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        assertEq(_implementationOf(TRUST_BONDING_PROXY), impls.trustBonding);
        assertEq(_implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY), impls.offsetProgressiveCurve);
        assertEq(_implementationOf(ATOM_WARDEN_PROXY), impls.atomWarden);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).implementation(), impls.atomWallet);
        assertEq(_implementationOf(SATELLITE_EMISSIONS_CONTROLLER_PROXY), impls.satelliteEmissionsController);

        assertTrue(oldTrustBondingImpl != impls.trustBonding);
        assertTrue(oldOffsetCurveImpl != impls.offsetProgressiveCurve);
        assertTrue(oldAtomWardenImpl != impls.atomWarden);
        assertTrue(oldAtomWalletImpl != impls.atomWallet);
        assertTrue(oldSatelliteEmissionsImpl != impls.satelliteEmissionsController);
    }

    /*//////////////////////////////////////////////////////////////
              COREEMISSIONSCONTROLLER EPOCH MATH VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies pre-upgrade and post-upgrade epoch boundary semantics on satellite emissions controller.
    function test_coreEmissionsController_epochBoundariesNoOverlap() external {
        ICoreEmissionsController controller = ICoreEmissionsController(SATELLITE_EMISSIONS_CONTROLLER_PROXY);

        uint256 epochLength = controller.getEpochLength();
        uint256 startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 15; ++epoch) {
            _assertEpochBoundarySemantics(
                controller, epoch, epochLength, startTimestamp, false, "pre-upgrade satellite"
            );

            uint256 epochStart = controller.getEpochTimestampStart(epoch);
            uint256 emissionsByEpoch = controller.getEmissionsAtEpoch(epoch);
            uint256 emissionsByTimestamp = controller.getEmissionsAtTimestamp(epochStart + epochLength / 2);
            assertEq(
                emissionsByEpoch,
                emissionsByTimestamp,
                "pre-upgrade satellite: emissions must match between epoch and timestamp queries"
            );
        }

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        controller = ICoreEmissionsController(SATELLITE_EMISSIONS_CONTROLLER_PROXY);
        epochLength = controller.getEpochLength();
        startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 15; ++epoch) {
            _assertEpochBoundarySemantics(
                controller, epoch, epochLength, startTimestamp, true, "post-upgrade satellite"
            );

            uint256 epochStart = controller.getEpochTimestampStart(epoch);
            uint256 emissionsByEpoch = controller.getEmissionsAtEpoch(epoch);
            uint256 emissionsByTimestamp = controller.getEmissionsAtTimestamp(epochStart + epochLength / 2);
            assertEq(
                emissionsByEpoch,
                emissionsByTimestamp,
                "post-upgrade satellite: emissions must match between epoch and timestamp queries"
            );
        }
    }

    /// @notice Verifies pre-upgrade and post-upgrade epoch boundary semantics on base emissions controller.
    function test_baseEmissionsController_epochBoundariesNoOverlap() external {
        _selectBaseFork();

        ICoreEmissionsController controller = ICoreEmissionsController(BASE_EMISSIONS_CONTROLLER_PROXY);

        uint256 epochLength = controller.getEpochLength();
        uint256 startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 15; ++epoch) {
            _assertEpochBoundarySemantics(controller, epoch, epochLength, startTimestamp, false, "pre-upgrade base");
        }

        _upgradeBaseEmissionsControllerViaScheduledOperation();
        assertEq(_implementationOf(BASE_EMISSIONS_CONTROLLER_PROXY), BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION);

        controller = ICoreEmissionsController(BASE_EMISSIONS_CONTROLLER_PROXY);
        epochLength = controller.getEpochLength();
        startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 15; ++epoch) {
            _assertEpochBoundarySemantics(controller, epoch, epochLength, startTimestamp, true, "post-upgrade base");
        }
    }

    function test_scheduledUpgrades_keepBaseAndIntuitionEpochsInSync() external {
        _selectIntuitionFork();
        _upgradeCoreInUnison(_configuredCoreImplementations());

        ICoreEmissionsController intuitionController = ICoreEmissionsController(SATELLITE_EMISSIONS_CONTROLLER_PROXY);
        EpochSnapshot memory intuitionEpoch = _captureEpochSnapshot(intuitionController);
        uint256 synchronizedTimestamp = block.timestamp;

        if (intuitionEpoch.currentEpoch > 0) {
            _assertEpochBoundarySemantics(
                intuitionController,
                intuitionEpoch.currentEpoch - 1,
                intuitionEpoch.epochLength,
                intuitionEpoch.startTimestamp,
                true,
                "scheduled intuition previous"
            );
        }

        _assertEpochBoundarySemantics(
            intuitionController,
            intuitionEpoch.currentEpoch,
            intuitionEpoch.epochLength,
            intuitionEpoch.startTimestamp,
            true,
            "scheduled intuition current"
        );
        assertEq(_implementationOf(TRUST_BONDING_PROXY), TRUST_BONDING_IMPLEMENTATION);
        assertEq(_implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY), OFFSET_PROGRESSIVE_CURVE_IMPLEMENTATION);
        assertEq(_implementationOf(SATELLITE_EMISSIONS_CONTROLLER_PROXY), SATELLITE_EMISSIONS_CONTROLLER_IMPLEMENTATION);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).implementation(), ATOM_WALLET_IMPLEMENTATION);
        _logEpochSnapshot("Intuition", intuitionEpoch);

        _selectBaseFork();
        vm.warp(synchronizedTimestamp);
        _upgradeBaseEmissionsControllerViaScheduledOperation();

        ICoreEmissionsController baseController = ICoreEmissionsController(BASE_EMISSIONS_CONTROLLER_PROXY);
        EpochSnapshot memory baseEpoch = _captureEpochSnapshot(baseController);

        if (baseEpoch.currentEpoch > 0) {
            _assertEpochBoundarySemantics(
                baseController,
                baseEpoch.currentEpoch - 1,
                baseEpoch.epochLength,
                baseEpoch.startTimestamp,
                true,
                "scheduled base previous"
            );
        }

        _assertEpochBoundarySemantics(
            baseController,
            baseEpoch.currentEpoch,
            baseEpoch.epochLength,
            baseEpoch.startTimestamp,
            true,
            "scheduled base current"
        );
        assertEq(_implementationOf(BASE_EMISSIONS_CONTROLLER_PROXY), BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION);
        _logEpochSnapshot("Base", baseEpoch);

        assertEq(baseEpoch.startTimestamp, intuitionEpoch.startTimestamp, "base/intuition startTimestamp mismatch");
        assertEq(baseEpoch.epochLength, intuitionEpoch.epochLength, "base/intuition epochLength mismatch");
        assertEq(baseEpoch.currentEpoch, intuitionEpoch.currentEpoch, "base/intuition currentEpoch mismatch");
        assertEq(
            baseEpoch.currentEpochStart, intuitionEpoch.currentEpochStart, "base/intuition currentEpochStart mismatch"
        );
        assertEq(baseEpoch.currentEpochEnd, intuitionEpoch.currentEpochEnd, "base/intuition currentEpochEnd mismatch");
        assertEq(baseEpoch.nextEpochStart, intuitionEpoch.nextEpochStart, "base/intuition nextEpochStart mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                    TRUSTBONDING REGRESSION (PRE/POST)
    //////////////////////////////////////////////////////////////*/

    /// @notice After upgrade, epochTimestampEnd(N) is the last second of epoch N.
    ///         Locks at epochTimestampEnd(N) + 1 (first second of epoch N+1) must be excluded
    ///         from epoch N's reward snapshot.
    function test_trustBonding_nextEpochStartExclusion_postUpgrade() external {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));

        address alice = makeAddr("tb-boundary-alice");
        address bob = makeAddr("tb-boundary-bob");

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        _createLock(alice, 50 ether);

        uint256 targetEpoch = trustBonding.currentEpoch();
        uint256 nextEpochStart = trustBonding.epochTimestampEnd(targetEpoch) + 1;
        vm.warp(nextEpochStart);

        uint256 totalBefore = trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        _createLock(bob, 50 ether);

        uint256 bobBalanceAtEpochEnd = trustBonding.userBondedBalanceAtEpochEnd(bob, targetEpoch);
        uint256 totalAfter = trustBonding.totalBondedBalanceAtEpochEnd(targetEpoch);

        assertEq(bobBalanceAtEpochEnd, 0, "post-upgrade next-epoch-start lock must be excluded from prior epoch");
        assertEq(totalAfter, totalBefore, "post-upgrade total must remain immutable after epoch end");
    }

    function test_trustBonding_budgetGuardrail_preOverallocates_thenPostCaps() external {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));

        address preUser = makeAddr("tb-budget-pre-user");
        _createLock(preUser, 100 ether);

        uint256 preCurrentEpoch = trustBonding.currentEpoch();
        // Move strictly into the next epoch regardless of boundary semantics.
        vm.warp(trustBonding.epochTimestampEnd(preCurrentEpoch) + 1);

        uint256 preClaimEpoch = trustBonding.currentEpoch() - 1;
        assertGt(preClaimEpoch, 0);

        _primeUserUtilizationForClaim(preUser, preClaimEpoch);

        uint256 preBudget = trustBonding.emissionsForEpoch(preClaimEpoch);
        vm.store(TRUST_BONDING_PROXY, _trustTotalClaimedRewardsSlot(preClaimEpoch), bytes32(preBudget - 1));

        uint256 preClaimable = trustBonding.getUserCurrentClaimableRewards(preUser);
        assertGt(preClaimable, 1, "pre-claimable rewards must exceed remaining budget");

        vm.prank(preUser);
        trustBonding.claimRewards(preUser);

        uint256 preTotalClaimed = trustBonding.totalClaimedRewardsForEpoch(preClaimEpoch);
        assertGt(preTotalClaimed, preBudget, "pre-upgrade claim should exceed epoch budget");

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        address postUser = makeAddr("tb-budget-post-user");
        _createLock(postUser, 100 ether);

        uint256 postCurrentEpoch = trustBonding.currentEpoch();
        // Move strictly into the next epoch regardless of boundary semantics.
        vm.warp(trustBonding.epochTimestampEnd(postCurrentEpoch) + 1);

        uint256 postClaimEpoch = trustBonding.currentEpoch() - 1;
        assertGt(postClaimEpoch, 0);

        _primeUserUtilizationForClaim(postUser, postClaimEpoch);

        uint256 postBudget = trustBonding.emissionsForEpoch(postClaimEpoch);
        vm.store(TRUST_BONDING_PROXY, _trustTotalClaimedRewardsSlot(postClaimEpoch), bytes32(postBudget - 1));

        uint256 postClaimable = trustBonding.getUserCurrentClaimableRewards(postUser);
        assertGt(postClaimable, 1, "post-claimable rewards must exceed remaining budget");

        vm.prank(postUser);
        trustBonding.claimRewards(postUser);

        uint256 postClaimedByUser = trustBonding.userClaimedRewardsForEpoch(postUser, postClaimEpoch);
        uint256 postTotalClaimed = trustBonding.totalClaimedRewardsForEpoch(postClaimEpoch);

        assertEq(postClaimedByUser, 1, "post-upgrade claim should be clamped to remaining budget");
        assertEq(postTotalClaimed, postBudget, "post-upgrade total claimed should be capped at budget");
        assertLe(postTotalClaimed, postBudget, "budget invariant must hold");
    }

    function test_trustBonding_boundaryInclusion_retryProtectionAndSameEpochClaimBlock_postUpgrade() external {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        address boundaryUser = makeAddr("tb-boundary-inclusive-user");

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);
        assertEq(_implementationOf(TRUST_BONDING_PROXY), TRUST_BONDING_IMPLEMENTATION);

        uint256 targetEpoch = trustBonding.currentEpoch();
        assertGt(targetEpoch, 0, "boundary claim test requires a prior epoch");

        uint256 boundaryTimestamp = trustBonding.epochTimestampEnd(targetEpoch);
        vm.warp(boundaryTimestamp);

        _createLock(boundaryUser, 10_000 ether);

        assertEq(
            trustBonding.userBondedBalanceAtEpochEnd(boundaryUser, targetEpoch - 1),
            0,
            "boundary lock must not overlap into the previous epoch"
        );
        assertGt(
            trustBonding.userBondedBalanceAtEpochEnd(boundaryUser, targetEpoch),
            0,
            "boundary lock must be included in the closed interval epoch"
        );

        vm.startPrank(boundaryUser);
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_NoRewardsToClaim.selector));
        trustBonding.claimRewards(boundaryUser);
        vm.stopPrank();

        vm.warp(boundaryTimestamp + 1);
        _primeUserUtilizationForClaim(boundaryUser, targetEpoch);

        uint256 claimableRewards = trustBonding.getUserCurrentClaimableRewards(boundaryUser);
        assertGt(claimableRewards, 0, "boundary-inclusive lock should become claimable in the next epoch");

        vm.prank(boundaryUser);
        trustBonding.claimRewards(boundaryUser);

        assertEq(
            trustBonding.userClaimedRewardsForEpoch(boundaryUser, targetEpoch),
            claimableRewards,
            "boundary-inclusive rewards must settle exactly once"
        );

        vm.startPrank(boundaryUser);
        vm.expectRevert(abi.encodeWithSelector(ITrustBonding.TrustBonding_RewardsAlreadyClaimedForEpoch.selector));
        trustBonding.claimRewards(boundaryUser);
        vm.stopPrank();
    }

    function test_trustBonding_epochBoundariesRemainDisjointAcrossManyEpochsPostUpgrade() external {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);
        assertEq(_implementationOf(TRUST_BONDING_PROXY), TRUST_BONDING_IMPLEMENTATION);

        uint256 startEpoch = trustBonding.currentEpoch();
        uint256 epochLength = trustBonding.epochLength();

        for (uint256 epochOffset = 0; epochOffset < 12; ++epochOffset) {
            uint256 epoch = startEpoch + epochOffset;
            uint256 epochEnd = trustBonding.epochTimestampEnd(epoch);
            uint256 nextEpochEnd = trustBonding.epochTimestampEnd(epoch + 1);

            assertEq(
                trustBonding.epochAtTimestamp(epochEnd),
                epoch,
                "epoch end timestamp must stay within its own epoch across repeated epochs"
            );
            assertEq(
                trustBonding.epochAtTimestamp(epochEnd + 1),
                epoch + 1,
                "the first second after epoch end must move into the next epoch across repeated epochs"
            );
            assertEq(
                nextEpochEnd - epochEnd,
                epochLength,
                "epoch boundaries must stay evenly spaced without overlap across repeated epochs"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                    ATOM WALLET BEACON REGRESSION
    //////////////////////////////////////////////////////////////*/

    function test_atomWallet_beaconUpgrade_preservesState_andMalformedSigNoRevertPost() external {
        AtomWallet atomWallet = AtomWallet(payable(KNOWN_ATOM_WALLET));
        AtomWalletState memory before = _captureAtomWalletState(atomWallet);
        assertEq(atomWallet.termId(), KNOWN_ATOM_ID);

        // PRE-UPGRADE: malformed signature path reverts.
        bytes32 userOpHash = keccak256("core-upgrade-regression-malformed-op");

        vm.prank(ENTRY_POINT);
        vm.expectRevert();
        atomWallet.validateUserOp(_buildMalformedSignatureUserOperation(KNOWN_ATOM_WALLET), userOpHash, 0);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        // POST-UPGRADE: malformed signature must fail validation without reverting.
        vm.prank(ENTRY_POINT);
        uint256 validationData =
            atomWallet.validateUserOp(_buildMalformedSignatureUserOperation(KNOWN_ATOM_WALLET), userOpHash, 0);
        assertEq(validationData, SIG_VALIDATION_FAILED);

        // Storage/state continuity across beacon implementation upgrade.
        _assertAtomWalletState(atomWallet, before);

        // Owner remains unchanged before claim.
        assertEq(atomWallet.owner(), KNOWN_ATOM_WALLET_OWNER);
    }

    function test_atomWarden_proxyUpgrade_bootstrapsAndSupportsSelfClaimAndDirectTransfer() external {
        _assertAtomWardenSelfClaimAndDirectTransfer(false);
    }

    function test_atomWarden_proxyUpgrade_bootstrapsAndSupportsChecksumSelfClaimAndDirectTransfer() external {
        _assertAtomWardenSelfClaimAndDirectTransfer(true);
    }

    function _assertAtomWardenSelfClaimAndDirectTransfer(bool useChecksumAddressAtom) internal {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));
        AtomWarden atomWarden = AtomWarden(payable(ATOM_WARDEN_PROXY));

        address claimant = makeAddr("atom-warden-claimant");
        address secondOwner = makeAddr("atom-warden-second-owner");
        vm.deal(claimant, 20 ether);

        string memory addressAtom =
            useChecksumAddressAtom ? Strings.toChecksumHexString(claimant) : Strings.toHexString(claimant);
        bytes memory atomData = bytes(addressAtom);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256 atomCost = multiVault.getAtomCost();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;

        vm.prank(claimant);
        multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);

        bytes32 atomId = multiVault.calculateAtomId(atomData);
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        assertTrue(atomWarden.hasRole(atomWarden.DEFAULT_ADMIN_ROLE(), ADMIN_SAFE));
        assertTrue(atomWarden.hasRole(atomWarden.OPERATOR_ROLE(), ADMIN_SAFE));
        // reinitialize(...) lands the operational config atomically — no follow-up
        // setter calls are needed before exercising claim paths.
        assertEq(atomWarden.claimWindow(), DEFAULT_WARDEN_CLAIM_WINDOW);
        assertEq(atomWarden.minFeeThreshold(), DEFAULT_WARDEN_MIN_FEE_THRESHOLD);
        assertEq(atomWarden.signatureThreshold(), DEFAULT_WARDEN_SIGNATURE_THRESHOLD);

        vm.prank(claimant);
        atomWarden.claimOwnershipOverAddressAtom(atomId);
        assertEq(atomWallet.owner(), claimant);
        assertTrue(atomWallet.isClaimed());

        vm.prank(claimant);
        atomWallet.transferOwnership(secondOwner);
        assertEq(atomWallet.owner(), secondOwner);
    }

    function test_atomWallet_beaconUpgrade_preRejectsLegacyTimeWindow_postNeutralizesLegacyFormats() external {
        address creator = makeAddr("atom-wallet-s149-creator");
        vm.deal(creator, 20 ether);

        bytes32 atomId = _createAtom(creator, "atom-wallet-s149-regression-atom");
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        uint256 ownerPrivateKey = 0xA11CE;
        address controlledOwner = vm.addr(ownerPrivateKey);
        address currentOwner = atomWallet.owner();

        vm.prank(currentOwner);
        ILegacyAtomWalletOwnership(atomWalletAddress).transferOwnership(controlledOwner);
        vm.prank(controlledOwner);
        ILegacyAtomWalletOwnership(atomWalletAddress).acceptOwnership();
        assertEq(atomWallet.owner(), controlledOwner);

        bytes32 userOpHash = keccak256("core-upgrade-regression-s149");
        uint48 originalValidUntil = uint48(block.timestamp + 1 days);
        uint48 tamperedValidUntil = uint48(block.timestamp + 30 days);
        uint48 validAfter = 0;

        bytes memory legacyRawSignature = _signUserOpHash(ownerPrivateKey, userOpHash);
        PackedUserOperation memory tamperedLegacyOp = _buildUserOperationWithSignature(
            atomWalletAddress, abi.encodePacked(legacyRawSignature, tamperedValidUntil, validAfter)
        );

        // PRE-UPGRADE (fork reality): legacy 77-byte signatures revert.
        vm.prank(ENTRY_POINT);
        vm.expectRevert();
        atomWallet.validateUserOp(tamperedLegacyOp, userOpHash, 0);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // POST-UPGRADE: the Coinbase-aligned AtomWallet drops the legacy 65/77-byte dual-path.
        // Both tampered and "bound" legacy-format signatures must fail without reverting — the
        // wallet attempts Coinbase SignatureWrapper decoding and returns SIG_VALIDATION_FAILED.
        vm.prank(ENTRY_POINT);
        uint256 tamperedPostValidation = atomWallet.validateUserOp(tamperedLegacyOp, userOpHash, 0);
        assertEq(tamperedPostValidation, SIG_VALIDATION_FAILED);

        PackedUserOperation memory boundOp = _buildUserOperationWithSignature(
            atomWalletAddress,
            _signUserOpHashWithTimeWindow(ownerPrivateKey, userOpHash, originalValidUntil, validAfter)
        );
        vm.prank(ENTRY_POINT);
        uint256 boundPostValidation = atomWallet.validateUserOp(boundOp, userOpHash, 0);
        assertEq(boundPostValidation, SIG_VALIDATION_FAILED);

        // The Coinbase SignatureWrapper format also fails pre-claim on a legacy wallet
        // because MultiOwnable is empty — the rollout precondition for removing the
        // legacy fallback is that claimed wallets go through `completeClaim`.
        _assertWrappedSigFailsOnLegacyWallet(atomWalletAddress, ownerPrivateKey, userOpHash);
    }

    function _assertWrappedSigFailsOnLegacyWallet(
        address atomWalletAddress,
        uint256 signerPrivateKey,
        bytes32 userOpHash
    )
        internal
    {
        bytes memory wrappedSig = abi.encode(uint256(0), _signUserOpHash(signerPrivateKey, userOpHash));
        PackedUserOperation memory wrappedOp = _buildUserOperationWithSignature(atomWalletAddress, wrappedSig);
        vm.prank(ENTRY_POINT);
        uint256 result = AtomWallet(payable(atomWalletAddress)).validateUserOp(wrappedOp, userOpHash, 0);
        assertEq(result, SIG_VALIDATION_FAILED);
    }

    /*//////////////////////////////////////////////////////////////
            COINBASE SUCCESSOR: ADDRESS STABILITY + NEW FEATURES
    //////////////////////////////////////////////////////////////*/

    function test_atomWallet_beaconUpgrade_preservesComputedAddresses() external {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));
        AtomWalletFactory factory = AtomWalletFactory(ATOM_WALLET_FACTORY);

        // Create atoms and record pre-upgrade computed addresses.
        bytes32 atomId1 = _createAtom(makeAddr("addr-stability-1"), "addr-stability-atom-1");
        bytes32 atomId2 = _createAtom(makeAddr("addr-stability-2"), "addr-stability-atom-2");

        address preAddr1 = factory.computeAtomWalletAddr(atomId1);
        address preAddr2 = factory.computeAtomWalletAddr(atomId2);

        // Deploy one wallet before upgrade.
        factory.deployAtomWallet(atomId1);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // Post-upgrade: addresses must be identical.
        address postAddr1 = factory.computeAtomWalletAddr(atomId1);
        address postAddr2 = factory.computeAtomWalletAddr(atomId2);
        assertEq(preAddr1, postAddr1, "Deployed wallet address shifted after beacon upgrade");
        assertEq(preAddr2, postAddr2, "Undeployed wallet address shifted after beacon upgrade");

        // Deploy the second wallet post-upgrade and verify address matches prediction.
        address deployed2 = factory.deployAtomWallet(atomId2);
        assertEq(deployed2, postAddr2, "Post-upgrade deployment address mismatch");
    }

    function test_atomWallet_beaconUpgrade_supportsERC1271PostUpgrade() external {
        address creator = makeAddr("erc1271-creator");
        vm.deal(creator, 20 ether);

        bytes32 atomId = _createAtom(creator, "erc1271-regression-atom");
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // Claim wallet to a deterministic key.
        uint256 ownerPrivateKey = 0xE1C1271;
        address controlledOwner = vm.addr(ownerPrivateKey);

        AtomWarden atomWarden = AtomWarden(payable(ATOM_WARDEN_PROXY));
        vm.prank(ADMIN_SAFE);
        atomWarden.grantAtomWalletOwnership(atomId, controlledOwner);
        assertEq(atomWallet.owner(), controlledOwner);
        assertTrue(atomWallet.isClaimed());

        // ERC-1271: sign a raw digest and validate with SignatureWrapper format (post-claim).
        bytes32 hash = keccak256("erc1271-post-upgrade-test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);
        // Post-claim: wrap in SignatureWrapper (ownerIndex=0, signatureData=rawSig)
        bytes memory signature = abi.encode(uint256(0), rawSig);

        bytes4 result = atomWallet.isValidSignature(hash, signature);
        assertEq(result, bytes4(0x1626ba7e), "ERC-1271 should return magic value post-upgrade");
    }

    function test_atomWallet_beaconUpgrade_supportsTokenReceiversPostUpgrade() external {
        address creator = makeAddr("token-receiver-creator");
        vm.deal(creator, 20 ether);

        bytes32 atomId = _createAtom(creator, "token-receiver-regression-atom");
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // Token receivers should work post-upgrade (Solady Receiver handles via fallback).
        (bool erc721Ok, bytes memory erc721Data) =
            address(atomWallet).call(abi.encodeWithSelector(bytes4(0x150b7a02), address(0), address(0), uint256(0), ""));
        assertTrue(erc721Ok, "onERC721Received call failed post-upgrade");
        assertEq(
            abi.decode(erc721Data, (bytes4)), bytes4(0x150b7a02), "onERC721Received selector mismatch post-upgrade"
        );

        (bool erc1155Ok, bytes memory erc1155Data) = address(atomWallet)
            .call(abi.encodeWithSelector(bytes4(0xf23a6e61), address(0), address(0), uint256(0), uint256(0), ""));
        assertTrue(erc1155Ok, "onERC1155Received call failed post-upgrade");
        assertEq(
            abi.decode(erc1155Data, (bytes4)), bytes4(0xf23a6e61), "onERC1155Received selector mismatch post-upgrade"
        );

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        (bool batchOk, bytes memory batchData) = address(atomWallet)
            .call(abi.encodeWithSelector(bytes4(0xbc197c81), address(0), address(0), ids, amounts, ""));
        assertTrue(batchOk, "onERC1155BatchReceived call failed post-upgrade");
        assertEq(
            abi.decode(batchData, (bytes4)), bytes4(0xbc197c81), "onERC1155BatchReceived selector mismatch post-upgrade"
        );

        // ERC-165 should report correct interfaces.
        assertTrue(atomWallet.supportsInterface(bytes4(0x01ffc9a7)), "IERC165 not supported post-upgrade");
        assertTrue(atomWallet.supportsInterface(bytes4(0x1626ba7e)), "IERC1271 not supported post-upgrade");
    }

    function test_atomWallet_computeAddress_remainsStableAcrossBeaconUpgrade() external {
        IMultiVault multiVault = IMultiVault(MULTIVAULT_PROXY);

        address computedBefore = multiVault.computeAtomWalletAddr(KNOWN_ATOM_ID);
        assertEq(computedBefore, KNOWN_ATOM_WALLET);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).implementation(), ATOM_WALLET_IMPLEMENTATION);

        address computedAfter = multiVault.computeAtomWalletAddr(KNOWN_ATOM_ID);
        assertEq(computedAfter, KNOWN_ATOM_WALLET);
        assertEq(computedAfter, computedBefore);
    }

    function test_atomWallet_beaconUpgrade_invalidSignersAndTimeWindows_preserveValidationMetadataPost() external {
        AtomWallet atomWallet = AtomWallet(payable(KNOWN_ATOM_WALLET));

        uint256 ownerPrivateKey = 0xA11CE;
        uint256 attackerPrivateKey = 0xB0B;
        address controlledOwner = vm.addr(ownerPrivateKey);

        assertEq(IMultiVault(MULTIVAULT_PROXY).computeAtomWalletAddr(KNOWN_ATOM_ID), KNOWN_ATOM_WALLET);

        vm.prank(atomWallet.owner());
        atomWallet.transferOwnership(controlledOwner);
        vm.prank(controlledOwner);
        ILegacyAtomWalletOwnership(address(atomWallet)).acceptOwnership();
        assertEq(atomWallet.owner(), controlledOwner);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).implementation(), ATOM_WALLET_IMPLEMENTATION);

        {
            bytes32 userOpHash = keccak256("core-upgrade-regression-invalid-window-cases");
            uint48 expiredValidUntil = uint48(block.timestamp - 1);
            uint48 futureValidUntil = uint48(block.timestamp + 3 days);
            uint48 futureValidAfter = uint48(block.timestamp + 1 days);

            PackedUserOperation memory wrongSignerOp = _buildUserOperationWithSignature(
                KNOWN_ATOM_WALLET,
                _signUserOpHashWithTimeWindow(attackerPrivateKey, userOpHash, futureValidUntil, futureValidAfter)
            );
            PackedUserOperation memory expiredWindowOp = _buildUserOperationWithSignature(
                KNOWN_ATOM_WALLET, _signUserOpHashWithTimeWindow(ownerPrivateKey, userOpHash, expiredValidUntil, 0)
            );
            PackedUserOperation memory futureWindowOp = _buildUserOperationWithSignature(
                KNOWN_ATOM_WALLET,
                _signUserOpHashWithTimeWindow(ownerPrivateKey, userOpHash, futureValidUntil, futureValidAfter)
            );

            vm.startPrank(ENTRY_POINT);
            uint256 wrongSignerValidation = atomWallet.validateUserOp(wrongSignerOp, userOpHash, 0);
            uint256 expiredWindowValidation = atomWallet.validateUserOp(expiredWindowOp, userOpHash, 0);
            uint256 futureWindowValidation = atomWallet.validateUserOp(futureWindowOp, userOpHash, 0);
            vm.stopPrank();

            assertEq(wrongSignerValidation, _packValidationData(true, futureValidUntil, futureValidAfter));
            assertEq(expiredWindowValidation, _packValidationData(false, expiredValidUntil, 0));
            assertEq(futureWindowValidation, _packValidationData(false, futureValidUntil, futureValidAfter));
        }

        assertEq(IMultiVault(MULTIVAULT_PROXY).computeAtomWalletAddr(KNOWN_ATOM_ID), KNOWN_ATOM_WALLET);
    }

    /*//////////////////////////////////////////////////////////////
                    OFFSET CURVE REGRESSION (PRE/POST)
    //////////////////////////////////////////////////////////////*/

    function test_offsetProgressiveCurve_lowShareEdge_productionConfig_prePost() external {
        OffsetProgressiveCurve curve = OffsetProgressiveCurve(payable(OFFSET_PROGRESSIVE_CURVE_PROXY));

        uint256 totalShares = 700_560_508;
        uint256 sharesToRedeem = 699_560_508;

        uint256 preAssets = curve.previewRedeem(sharesToRedeem, totalShares, 0);
        assertGt(preAssets, 0, "production-config offset curve should redeem without underflow");

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        uint256 postAssets = curve.previewRedeem(sharesToRedeem, totalShares, 0);

        assertApproxEqAbs(postAssets, preAssets, 1, "production-config low-share redeem should remain stable");

        // Additional edge guard in current implementation for zero-offset local deployment.
        OffsetProgressiveCurve localCurve = _deployOffsetCurve("Local OPC Zero Offset", 2e18, 0);
        uint256 localAssets = localCurve.previewRedeem(sharesToRedeem, totalShares, 0);
        assertEq(localAssets, 0, "zero-offset low-share edge should not underflow");
    }

    function test_offsetProgressiveCurve_liveCurve2_smallDeposits_stopReverting_postUpgrade() external {
        uint256[4] memory minShareAssetSamples;
        uint256[4] memory minDepositSamples;

        {
            IMultiVaultCore multiVaultCore = IMultiVaultCore(MULTIVAULT_PROXY);
            GeneralConfig memory generalConfig = multiVaultCore.getGeneralConfig();
            BondingCurveConfig memory bondingCurveConfig = multiVaultCore.getBondingCurveConfig();
            (uint256 totalAssets, uint256 totalShares) =
                IMultiVault(MULTIVAULT_PROXY).getVault(KNOWN_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID);

            uint256 minShareAssetCost = IBondingCurveRegistry(bondingCurveConfig.registry)
                .previewMint(generalConfig.minShare, totalShares, totalAssets, OFFSET_PROGRESSIVE_CURVE_ID);
            assertGt(minShareAssetCost, 0, "live curve-2 minShare cost must be non-zero");

            minShareAssetSamples =
                [minShareAssetCost, minShareAssetCost * 10, minShareAssetCost * 100, minShareAssetCost * 1000];
            minDepositSamples = [
                generalConfig.minDeposit,
                generalConfig.minDeposit * 10,
                generalConfig.minDeposit * 100,
                generalConfig.minDeposit * 1000
            ];
        }

        (uint256[4] memory preMinShareShares, uint256[4] memory preMinShareNetAssets) =
            _capturePreviewDepositSeries(KNOWN_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, minShareAssetSamples);
        (uint256[4] memory preMinDepositShares, uint256[4] memory preMinDepositNetAssets) =
            _capturePreviewDepositSeries(KNOWN_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, minDepositSamples);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);
        assertEq(_implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY), OFFSET_PROGRESSIVE_CURVE_IMPLEMENTATION);

        _assertPreviewDepositSeriesStable(
            KNOWN_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, minShareAssetSamples, preMinShareShares, preMinShareNetAssets
        );
        _assertPreviewDepositSeriesStable(
            KNOWN_ATOM_ID, OFFSET_PROGRESSIVE_CURVE_ID, minDepositSamples, preMinDepositShares, preMinDepositNetAssets
        );
    }

    /*//////////////////////////////////////////////////////////////
                    STORAGE CONTINUITY + SAFETY
    //////////////////////////////////////////////////////////////*/

    function test_storageContinuityAcrossUnisonUpgrade() external {
        OffsetProgressiveCurve curve = OffsetProgressiveCurve(payable(OFFSET_PROGRESSIVE_CURVE_PROXY));
        StorageSnapshot memory before = _captureStorageSnapshot(KNOWN_ATOM_WALLET);

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        // Existing slots and mapping entries remain intact after implementation switch.
        _assertStorageSnapshot(before, KNOWN_ATOM_WALLET);

        // Slot 69 is part of the __gap (never used on mainnet), should remain zero.
        assertEq(vm.load(TRUST_BONDING_PROXY, bytes32(uint256(69))), bytes32(0));

        // Existing slots remain unchanged after upgrade.
        _assertTrustCoreSlots(before.tbCoreSlots);

        // Keep curve referenced to avoid compiler warnings in some optimization settings.
        assertTrue(address(curve) != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            POST-UPGRADE SMOKE
    //////////////////////////////////////////////////////////////*/

    function test_postUpgrade_coreSmokeFlows() external {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        OffsetProgressiveCurve curve = OffsetProgressiveCurve(payable(OFFSET_PROGRESSIVE_CURVE_PROXY));
        AtomWallet atomWallet = AtomWallet(payable(KNOWN_ATOM_WALLET));

        CoreImplementations memory impls = _configuredCoreImplementations();
        _upgradeCoreInUnison(impls);

        address user = makeAddr("smoke-user");
        vm.deal(user, 20 ether);

        uint256 totalLockedBefore = trustBonding.totalLocked();
        _createLock(user, 1 ether);
        assertEq(trustBonding.totalLocked(), totalLockedBefore + 1 ether);

        uint256 assetsPreview = curve.previewRedeem(699_560_508, 700_560_508, 0);
        assertGt(assetsPreview, 0);

        PackedUserOperation memory malformedOp = _buildMalformedSignatureUserOperation(KNOWN_ATOM_WALLET);
        bytes32 userOpHash = keccak256("post-upgrade-smoke-malformed");

        vm.prank(ENTRY_POINT);
        uint256 validationData = atomWallet.validateUserOp(malformedOp, userOpHash, 0);
        assertEq(validationData, SIG_VALIDATION_FAILED);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _selectIntuitionFork() internal {
        vm.selectFork(intuitionFork);
        // veTRUST checkpoints persist Base L2 `blk` values, while this fork executes on Intuition L3.
        // Rolling to a Base block keeps checkpoint-based block reads/actions from treating those blocks as "future".
        vm.roll(baseForkBlockNumber);
    }

    function _selectBaseFork() internal {
        vm.selectFork(baseFork);
    }

    function _ensureEpochAtLeastOne() internal {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        if (trustBonding.currentEpoch() == 0) {
            vm.warp(trustBonding.epochTimestampEnd(0) + 1);
        }
    }

    function _deployCoreImplementations() internal returns (CoreImplementations memory impls) {
        impls.trustBonding = address(new TrustBonding());
        impls.offsetProgressiveCurve = address(new OffsetProgressiveCurve());
        impls.atomWarden = address(new AtomWarden());
        impls.atomWallet = address(new AtomWallet());
        impls.satelliteEmissionsController = address(new SatelliteEmissionsController());
    }

    function _configuredCoreImplementations() internal returns (CoreImplementations memory impls) {
        impls.trustBonding = TRUST_BONDING_IMPLEMENTATION;
        impls.offsetProgressiveCurve = OFFSET_PROGRESSIVE_CURVE_IMPLEMENTATION;
        impls.atomWarden = address(new AtomWarden());
        impls.atomWallet = ATOM_WALLET_IMPLEMENTATION;
        impls.satelliteEmissionsController = SATELLITE_EMISSIONS_CONTROLLER_IMPLEMENTATION;
    }

    function _upgradeCoreInUnison(CoreImplementations memory impls) internal {
        vm.warp(block.timestamp + 7 days);
        vm.startPrank(UPGRADES_TIMELOCK);

        ProxyAdmin(TRUST_BONDING_PROXY_ADMIN)
            .upgradeAndCall(ITransparentUpgradeableProxy(payable(TRUST_BONDING_PROXY)), impls.trustBonding, bytes(""));

        ProxyAdmin(OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(OFFSET_PROGRESSIVE_CURVE_PROXY)),
                impls.offsetProgressiveCurve,
                bytes("")
            );

        // AtomWarden upgrade is split: the proxy admin (timelock) lands the new
        // impl bare, then the MultiVault admin reinitializes with config values
        // directly against the proxy. `reinitialize` is gated to that admin.
        ProxyAdmin(ATOM_WARDEN_PROXY_ADMIN)
            .upgradeAndCall(ITransparentUpgradeableProxy(payable(ATOM_WARDEN_PROXY)), impls.atomWarden, bytes(""));

        ProxyAdmin(SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(SATELLITE_EMISSIONS_CONTROLLER_PROXY)),
                impls.satelliteEmissionsController,
                bytes("")
            );

        UpgradeableBeacon(ATOM_WALLET_BEACON).upgradeTo(impls.atomWallet);

        vm.stopPrank();

        vm.prank(ADMIN_SAFE);
        AtomWarden(payable(ATOM_WARDEN_PROXY))
            .reinitialize(
                DEFAULT_WARDEN_CLAIM_WINDOW,
                DEFAULT_WARDEN_MIN_FEE_THRESHOLD,
                DEFAULT_WARDEN_SIGNATURE_THRESHOLD,
                DEFAULT_WARDEN_MAX_VALID_AFTER,
                DEFAULT_WARDEN_MAX_VALID_UNTIL,
                DEFAULT_WARDEN_MAX_CLAIMS_PER_WINDOW,
                DEFAULT_WARDEN_CLAIM_CAP_WINDOW
            );
    }

    function _upgradeBaseEmissionsControllerViaScheduledOperation() internal {
        if (BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION.code.length == 0) {
            BaseEmissionsController implementation = new BaseEmissionsController();
            vm.etch(BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION, address(implementation).code);
        }

        vm.prank(BASE_UPGRADES_TIMELOCK);
        ProxyAdmin(BASE_EMISSIONS_CONTROLLER_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(BASE_EMISSIONS_CONTROLLER_PROXY)),
                BASE_EMISSIONS_CONTROLLER_IMPLEMENTATION,
                bytes("")
            );
    }

    function _captureEpochSnapshot(ICoreEmissionsController controller)
        internal
        view
        returns (EpochSnapshot memory snapshot)
    {
        snapshot.startTimestamp = controller.getStartTimestamp();
        snapshot.epochLength = controller.getEpochLength();
        snapshot.currentEpoch = controller.getCurrentEpoch();
        snapshot.currentEpochStart = controller.getEpochTimestampStart(snapshot.currentEpoch);
        snapshot.currentEpochEnd = controller.getEpochTimestampEnd(snapshot.currentEpoch);
        snapshot.nextEpochStart = controller.getEpochTimestampStart(snapshot.currentEpoch + 1);
    }

    function _logEpochSnapshot(string memory label, EpochSnapshot memory snapshot) internal {
        console2.log(label);
        console2.log("  block.timestamp", block.timestamp);
        console2.log("  startTimestamp", snapshot.startTimestamp);
        console2.log("  epochLength", snapshot.epochLength);
        console2.log("  currentEpoch", snapshot.currentEpoch);
        console2.log("  currentEpochStart", snapshot.currentEpochStart);
        console2.log("  currentEpochEnd", snapshot.currentEpochEnd);
        console2.log("  nextEpochStart", snapshot.nextEpochStart);
    }

    function _assertEpochBoundarySemantics(
        ICoreEmissionsController controller,
        uint256 epoch,
        uint256 epochLength,
        uint256 startTimestamp,
        bool expectClosedInterval,
        string memory phaseLabel
    )
        internal
        view
    {
        uint256 epochStart = controller.getEpochTimestampStart(epoch);
        uint256 epochEnd = controller.getEpochTimestampEnd(epoch);
        uint256 nextEpochStart = controller.getEpochTimestampStart(epoch + 1);

        assertEq(
            epochStart,
            startTimestamp + (epoch * epochLength),
            string.concat(phaseLabel, ": epochStart must match formula")
        );

        if (expectClosedInterval) {
            assertEq(
                epochEnd,
                epochStart + epochLength - 1,
                string.concat(phaseLabel, ": epochEnd must equal epochStart + epochLength - 1")
            );
            assertEq(
                epochEnd + 1, nextEpochStart, string.concat(phaseLabel, ": epochEnd + 1 must equal next epoch start")
            );
            assertEq(
                controller.getEpochAtTimestamp(epochEnd),
                epoch,
                string.concat(phaseLabel, ": epochEnd must belong to current epoch")
            );
            assertEq(
                controller.getEpochAtTimestamp(epochEnd + 1),
                epoch + 1,
                string.concat(phaseLabel, ": epochEnd + 1 must belong to next epoch")
            );
            return;
        }

        assertEq(
            epochEnd,
            epochStart + epochLength,
            string.concat(phaseLabel, ": epochEnd must equal epochStart + epochLength")
        );
        assertEq(nextEpochStart, epochEnd, string.concat(phaseLabel, ": next epoch start must equal epochEnd"));
        assertEq(
            controller.getEpochAtTimestamp(epochEnd - 1),
            epoch,
            string.concat(phaseLabel, ": epochEnd - 1 must belong to current epoch")
        );
        assertEq(
            controller.getEpochAtTimestamp(epochEnd),
            epoch + 1,
            string.concat(phaseLabel, ": epochEnd boundary must belong to next epoch")
        );
    }

    function _implementationOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function _createAtom(address user, string memory atomLabel) internal returns (bytes32 atomId) {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));

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

    function _capturePreviewDepositSeries(
        bytes32 termId,
        uint256 curveId,
        uint256[4] memory assetSamples
    )
        internal
        view
        returns (uint256[4] memory sharesOut, uint256[4] memory netAssetsOut)
    {
        uint256 previousShares;
        uint256 previousNetAssets;

        for (uint256 i = 0; i < assetSamples.length; ++i) {
            (sharesOut[i], netAssetsOut[i]) =
                IMultiVault(MULTIVAULT_PROXY).previewDeposit(termId, curveId, assetSamples[i]);

            assertLe(netAssetsOut[i], assetSamples[i], "live curve-2 preview net assets must not exceed gross assets");
            assertGe(netAssetsOut[i], previousNetAssets, "live curve-2 preview net assets must stay monotonic");
            assertGe(sharesOut[i], previousShares, "live curve-2 preview shares must stay monotonic");

            previousShares = sharesOut[i];
            previousNetAssets = netAssetsOut[i];
        }
    }

    function _assertPreviewDepositSeriesStable(
        bytes32 termId,
        uint256 curveId,
        uint256[4] memory assetSamples,
        uint256[4] memory expectedShares,
        uint256[4] memory expectedNetAssets
    )
        internal
        view
    {
        (uint256[4] memory sharesOut, uint256[4] memory netAssetsOut) =
            _capturePreviewDepositSeries(termId, curveId, assetSamples);

        for (uint256 i = 0; i < assetSamples.length; ++i) {
            assertEq(sharesOut[i], expectedShares[i], "live curve-2 preview shares changed across upgrade");
            assertEq(netAssetsOut[i], expectedNetAssets[i], "live curve-2 preview net assets changed across upgrade");
        }
    }

    function _createLock(address user, uint256 amount) internal {
        WrappedTrust wrappedTrust = WrappedTrust(payable(WRAPPED_TRUST));
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        vm.roll(baseForkBlockNumber);

        vm.deal(user, user.balance + amount);

        vm.startPrank(user, user);
        wrappedTrust.deposit{ value: amount }();
        wrappedTrust.approve(TRUST_BONDING_PROXY, type(uint256).max);

        uint256 unlockTime = _defaultUnlockTime(trustBonding);
        trustBonding.create_lock(amount, unlockTime);
        vm.stopPrank();
    }

    function _defaultUnlockTime(TrustBonding trustBonding) internal view returns (uint256 unlockTime) {
        unlockTime = ((block.timestamp + 2 * 365 days) / 1 weeks) * 1 weeks;
        uint256 minUnlock = block.timestamp + trustBonding.MINTIME();
        if (unlockTime <= minUnlock) {
            unlockTime += 1 weeks;
        }
    }

    function _primeUserUtilizationForClaim(address user, uint256 claimEpoch) internal {
        // MultiVault user utilization + history slots used by TrustBonding.getPersonalUtilizationRatio.
        vm.store(MULTIVAULT_PROXY, _multiVaultUserEpochHistorySlot(user, 0), bytes32(claimEpoch));
        vm.store(MULTIVAULT_PROXY, _multiVaultUserEpochHistorySlot(user, 1), bytes32(claimEpoch - 1));

        vm.store(
            MULTIVAULT_PROXY,
            _multiVaultPersonalUtilizationSlot(user, claimEpoch - 1),
            bytes32(uint256(int256(100 ether)))
        );
        vm.store(
            MULTIVAULT_PROXY, _multiVaultPersonalUtilizationSlot(user, claimEpoch), bytes32(uint256(int256(200 ether)))
        );

        // Non-zero prior target utilization so ratio resolves to max when delta >= target.
        vm.store(TRUST_BONDING_PROXY, _trustUserClaimedRewardsSlot(user, claimEpoch - 1), bytes32(uint256(1)));
    }

    function _buildMalformedSignatureUserOperation(address sender)
        internal
        pure
        returns (PackedUserOperation memory userOp)
    {
        bytes memory callDataWithLegacyHeader = new bytes(24);
        bytes memory malformedSignature = new bytes(76);

        userOp = PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: "",
            callData: callDataWithLegacyHeader,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: malformedSignature
        });
    }

    function _buildUserOperationWithSignature(
        address sender,
        bytes memory signature
    )
        internal
        pure
        returns (PackedUserOperation memory userOp)
    {
        bytes memory callDataWithLegacyHeader = new bytes(24);

        userOp = PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: "",
            callData: callDataWithLegacyHeader,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: signature
        });
    }

    function _signUserOpHash(uint256 signerPrivateKey, bytes32 userOpHash) internal returns (bytes memory) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 signatureV, bytes32 signatureR, bytes32 signatureS) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(signatureR, signatureS, signatureV);
    }

    function _signUserOpHashWithTimeWindow(
        uint256 signerPrivateKey,
        bytes32 userOpHash,
        uint48 validUntil,
        uint48 validAfter
    )
        internal
        returns (bytes memory)
    {
        bytes32 signedPayload = keccak256(abi.encodePacked(userOpHash, validUntil, validAfter));
        bytes memory rawSignature = _signUserOpHash(signerPrivateKey, signedPayload);
        return abi.encodePacked(rawSignature, validUntil, validAfter);
    }

    function _trustBondingUpgradeExecuteCalldata() internal pure returns (bytes memory) {
        return hex"134008d3000000000000000000000000f10fee90b3c633c4fcd49aa557ec7d51e5aeef62000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000849623609d000000000000000000000000635bbd1367b66e7b16a21d6e5a63c812ffc00617000000000000000000000000d1716d4430466397fc88e938e97c7e12adcecf240000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    }

    function _offsetProgressiveCurveUpgradeExecuteCalldata() internal pure returns (bytes memory) {
        return hex"134008d3000000000000000000000000e58b117adfb0a141dc1cc22b98297294f6e2c5e7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000849623609d00000000000000000000000023aff95153aa88d28b9b97ba97629e05d5fd335d000000000000000000000000ea5b87984253ae3d8472df3738e5ad421297c2460000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    }

    function _satelliteEmissionsControllerUpgradeExecuteCalldata() internal pure returns (bytes memory) {
        return hex"134008d3000000000000000000000000df60d18e86f3454309ad7734055843f7ee5f30a3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000849623609d00000000000000000000000073b8819f9b157be42172e3866fb0ba0d5fa0a5c60000000000000000000000000d1a22119c23920d24dccf5387eaef1e472d96390000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    }

    function _atomWalletBeaconUpgradeExecuteCalldata() internal pure returns (bytes memory) {
        return hex"134008d3000000000000000000000000c23cd55cf924b3fe4b97deaa0eaf222a5082a1ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000243659cfe6000000000000000000000000bcb1526a8de4a155e4de003361b122ede2f2290800000000000000000000000000000000000000000000000000000000";
    }

    function _deployOffsetCurve(
        string memory name,
        uint256 slope,
        uint256 offset
    )
        internal
        returns (OffsetProgressiveCurve)
    {
        OffsetProgressiveCurve impl = new OffsetProgressiveCurve();
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(impl), address(UPGRADES_TIMELOCK), bytes(""));
        OffsetProgressiveCurve deployed = OffsetProgressiveCurve(address(proxy));
        deployed.initialize(name, slope, offset);
        return deployed;
    }

    function _captureAtomWalletState(AtomWallet atomWallet) internal view returns (AtomWalletState memory state) {
        state.owner = atomWallet.owner();
        state.multiVault = address(atomWallet.multiVault());
        state.entryPoint = address(atomWallet.entryPoint());
        state.termId = atomWallet.termId();
        state.isClaimed = atomWallet.isClaimed();
    }

    function _assertAtomWalletState(AtomWallet atomWallet, AtomWalletState memory expected) internal view {
        assertEq(atomWallet.owner(), expected.owner);
        assertEq(address(atomWallet.multiVault()), expected.multiVault);
        assertEq(address(atomWallet.entryPoint()), expected.entryPoint);
        assertEq(atomWallet.termId(), expected.termId);
        assertEq(atomWallet.isClaimed(), expected.isClaimed);
    }

    function _captureStorageSnapshot(address atomWalletAddress)
        internal
        view
        returns (StorageSnapshot memory snapshot)
    {
        snapshot.tbCoreSlots = _loadTrustCoreSlots();
        snapshot.atomWalletCoreSlots = _loadSlots3(atomWalletAddress, 0);
        snapshot.offsetCurveCoreSlots = _loadSlots5(OFFSET_PROGRESSIVE_CURVE_PROXY, 1);
    }

    function _assertStorageSnapshot(StorageSnapshot memory expected, address atomWalletAddress) internal view {
        _assertTrustCoreSlots(expected.tbCoreSlots);
        _assertSlots3(atomWalletAddress, 0, expected.atomWalletCoreSlots);
        _assertSlots5(OFFSET_PROGRESSIVE_CURVE_PROXY, 1, expected.offsetCurveCoreSlots);
    }

    function _loadTrustCoreSlots() internal view returns (bytes32[7] memory slots) {
        for (uint256 i = 0; i < 7; ++i) {
            slots[i] = vm.load(TRUST_BONDING_PROXY, bytes32(uint256(62 + i)));
        }
    }

    function _assertTrustCoreSlots(bytes32[7] memory expected) internal view {
        for (uint256 i = 0; i < 7; ++i) {
            assertEq(vm.load(TRUST_BONDING_PROXY, bytes32(uint256(62 + i))), expected[i]);
        }
    }

    function _loadSlots3(address account, uint256 startSlot) internal view returns (bytes32[3] memory slots) {
        for (uint256 i = 0; i < 3; ++i) {
            slots[i] = vm.load(account, bytes32(startSlot + i));
        }
    }

    function _assertSlots3(address account, uint256 startSlot, bytes32[3] memory expected) internal view {
        for (uint256 i = 0; i < 3; ++i) {
            assertEq(vm.load(account, bytes32(startSlot + i)), expected[i]);
        }
    }

    function _loadSlots5(address account, uint256 startSlot) internal view returns (bytes32[5] memory slots) {
        for (uint256 i = 0; i < 5; ++i) {
            slots[i] = vm.load(account, bytes32(startSlot + i));
        }
    }

    function _assertSlots5(address account, uint256 startSlot, bytes32[5] memory expected) internal view {
        for (uint256 i = 0; i < 5; ++i) {
            assertEq(vm.load(account, bytes32(startSlot + i)), expected[i]);
        }
    }

    function _multiVaultPersonalUtilizationSlot(address user, uint256 epoch) internal pure returns (bytes32) {
        bytes32 userSlot = keccak256(abi.encode(user, uint256(31)));
        return keccak256(abi.encode(epoch, uint256(userSlot)));
    }

    function _multiVaultUserEpochHistorySlot(address user, uint256 index) internal pure returns (bytes32) {
        bytes32 baseSlot = keccak256(abi.encode(user, uint256(32)));
        return bytes32(uint256(baseSlot) + index);
    }

    function _trustTotalClaimedRewardsSlot(uint256 epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(epoch, uint256(62)));
    }

    function _trustUserClaimedRewardsSlot(address user, uint256 epoch) internal pure returns (bytes32) {
        bytes32 userSlot = keccak256(abi.encode(user, uint256(63)));
        return keccak256(abi.encode(epoch, uint256(userSlot)));
    }
}
