// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
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
import { BaseEmissionsController } from "src/protocol/emissions/BaseEmissionsController.sol";
import { SatelliteEmissionsController } from "src/protocol/emissions/SatelliteEmissionsController.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { OffsetProgressiveCurve } from "src/protocol/curves/OffsetProgressiveCurve.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";
import { ICoreEmissionsController } from "src/interfaces/ICoreEmissionsController.sol";

contract CoreMainnetUpgradeRegressionTest is Test {
    struct CoreImplementations {
        address multiVault;
        address trustBonding;
        address offsetProgressiveCurve;
        address atomWallet;
        address satelliteEmissionsController;
    }

    struct StorageSnapshot {
        bytes32 mvSlot0;
        bytes32 mvTotalUtilization;
        bytes32 mvPersonalUtilization;
        bytes32 mvUserEpoch0;
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

    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    // Intuition mainnet governance
    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant ADMIN_SAFE = 0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb;

    // Proxies + admins (contracts/core/README.md)
    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant MULTIVAULT_PROXY_ADMIN = 0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8;

    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant TRUST_BONDING_PROXY_ADMIN = 0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62;

    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY = 0x23afF95153aa88D28B9B97Ba97629E05D5fD335d;
    address internal constant OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN = 0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7;

    address internal constant ATOM_WALLET_BEACON = 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF;
    address internal constant ATOM_WALLET_FACTORY = 0x33827373a7D1c7C78a01094071C2f6CE74253B9B;

    // Emissions controller proxies
    address internal constant SATELLITE_EMISSIONS_CONTROLLER_PROXY = 0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6;
    address internal constant SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN = 0xdF60D18E86F3454309aD7734055843F7ee5f30a3;
    address internal constant BASE_EMISSIONS_CONTROLLER_PROXY = 0x7745bDEe668501E5eeF7e9605C746f9cDfb60667;
    address internal constant BASE_EMISSIONS_CONTROLLER_PROXY_ADMIN = 0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a;

    // Core dependencies
    address internal constant WRAPPED_TRUST = 0x81cFb09cb44f7184Ad934C09F82000701A4bF672;
    address internal constant ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

    uint256 internal constant DEFAULT_CURVE_ID = 1;
    uint256 internal constant OFFSET_CURVE_ID = 2;
    uint256 internal constant INTUITION_FORK_BLOCK = 2_367_274;
    uint256 internal constant BASE_BLOCK_NUMBER = 43_451_628;

    function setUp() external {
        _selectIntuitionFork();
        _ensureEpochAtLeastOne();
    }

    /*//////////////////////////////////////////////////////////////
                                  PREFLIGHT
    //////////////////////////////////////////////////////////////*/

    function test_preflight_rolesAndUpgradeOwnership() external view {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));

        // DEFAULT_ADMIN_ROLE is held by the Safe for both contracts.
        assertTrue(multiVault.hasRole(multiVault.DEFAULT_ADMIN_ROLE(), ADMIN_SAFE));
        assertTrue(trustBonding.hasRole(trustBonding.DEFAULT_ADMIN_ROLE(), ADMIN_SAFE));

        // Upgrade ownership is held by the upgrades timelock.
        assertEq(ProxyAdmin(MULTIVAULT_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(TRUST_BONDING_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(ProxyAdmin(SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN).owner(), UPGRADES_TIMELOCK);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).owner(), UPGRADES_TIMELOCK);
    }

    function test_upgradeInUnison() external {
        address oldMultiVaultImpl = _implementationOf(MULTIVAULT_PROXY);
        address oldTrustBondingImpl = _implementationOf(TRUST_BONDING_PROXY);
        address oldOffsetCurveImpl = _implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY);
        address oldAtomWalletImpl = UpgradeableBeacon(ATOM_WALLET_BEACON).implementation();
        address oldSatelliteEmissionsImpl = _implementationOf(SATELLITE_EMISSIONS_CONTROLLER_PROXY);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        assertEq(_implementationOf(MULTIVAULT_PROXY), impls.multiVault);
        assertEq(_implementationOf(TRUST_BONDING_PROXY), impls.trustBonding);
        assertEq(_implementationOf(OFFSET_PROGRESSIVE_CURVE_PROXY), impls.offsetProgressiveCurve);
        assertEq(UpgradeableBeacon(ATOM_WALLET_BEACON).implementation(), impls.atomWallet);
        assertEq(_implementationOf(SATELLITE_EMISSIONS_CONTROLLER_PROXY), impls.satelliteEmissionsController);

        assertTrue(oldMultiVaultImpl != impls.multiVault);
        assertTrue(oldTrustBondingImpl != impls.trustBonding);
        assertTrue(oldOffsetCurveImpl != impls.offsetProgressiveCurve);
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

        for (uint256 epoch = 0; epoch < 5; ++epoch) {
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

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        controller = ICoreEmissionsController(SATELLITE_EMISSIONS_CONTROLLER_PROXY);
        epochLength = controller.getEpochLength();
        startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 5; ++epoch) {
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
        vm.createSelectFork("base", BASE_BLOCK_NUMBER);

        ICoreEmissionsController controller = ICoreEmissionsController(BASE_EMISSIONS_CONTROLLER_PROXY);

        uint256 epochLength = controller.getEpochLength();
        uint256 startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 5; ++epoch) {
            _assertEpochBoundarySemantics(controller, epoch, epochLength, startTimestamp, false, "pre-upgrade base");
        }

        BaseEmissionsController newBaseImpl = new BaseEmissionsController();
        address baseProxyAdminOwner = ProxyAdmin(BASE_EMISSIONS_CONTROLLER_PROXY_ADMIN).owner();

        vm.prank(baseProxyAdminOwner);
        ProxyAdmin(BASE_EMISSIONS_CONTROLLER_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(BASE_EMISSIONS_CONTROLLER_PROXY)), address(newBaseImpl), bytes("")
            );

        controller = ICoreEmissionsController(BASE_EMISSIONS_CONTROLLER_PROXY);
        epochLength = controller.getEpochLength();
        startTimestamp = controller.getStartTimestamp();

        for (uint256 epoch = 0; epoch < 5; ++epoch) {
            _assertEpochBoundarySemantics(controller, epoch, epochLength, startTimestamp, true, "post-upgrade base");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIVAULT REGRESSION (PRE/POST)
    //////////////////////////////////////////////////////////////*/

    function test_multivault_zeroCrossingReplay_preThenPostUpgrade() external {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));

        address actor = makeAddr("mv-zero-crossing-actor");
        vm.deal(actor, 50 ether);

        bytes32 atomId = _createAtom(actor, "mv-zero-crossing-atom");

        uint256 epoch = multiVault.currentEpoch();
        if (epoch == 0) {
            // Ensure epoch > 0 because rollover copies from previous epoch.
            vm.warp(TrustBonding(payable(TRUST_BONDING_PROXY)).epochTimestampEnd(0) + 1);
            epoch = multiVault.currentEpoch();
        }
        uint256 previousEpoch = epoch - 1;

        int256 previousEpochUtilization = int256(1000 ether);
        uint256 firstDeposit = 2 ether;
        uint256 secondDeposit = 1 ether;

        _setMultiVaultTotalUtilization(previousEpoch, previousEpochUtilization);
        _setMultiVaultTotalUtilization(epoch, 0);

        // PRE-UPGRADE: vulnerable replay when current epoch utilization reaches 0 mid-epoch.
        _depositIntoAtom(actor, atomId, firstDeposit);
        assertEq(multiVault.totalUtilization(epoch), previousEpochUtilization + int256(firstDeposit));

        // Simulate legitimate mid-epoch zero crossing.
        _setMultiVaultTotalUtilization(epoch, 0);

        _depositIntoAtom(actor, atomId, secondDeposit);
        assertEq(
            multiVault.totalUtilization(epoch),
            previousEpochUtilization + int256(secondDeposit),
            "pre-upgrade replay should re-copy previous epoch"
        );

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // POST-UPGRADE: explicit rollover flag prevents replay.
        _setMultiVaultTotalUtilization(previousEpoch, previousEpochUtilization);
        _setMultiVaultTotalUtilization(epoch, 0);

        assertFalse(multiVault.hasRolledOverSystemUtilization(epoch));

        _depositIntoAtom(actor, atomId, firstDeposit);
        assertEq(multiVault.totalUtilization(epoch), previousEpochUtilization + int256(firstDeposit));

        _setMultiVaultTotalUtilization(epoch, 0);

        _depositIntoAtom(actor, atomId, secondDeposit);
        assertEq(
            multiVault.totalUtilization(epoch),
            int256(secondDeposit),
            "post-upgrade must not replay previous epoch after zero crossing"
        );
    }

    function test_multivault_midEpochUpgrade_doesNotOverwriteInitializedCurrentEpochUtilization() external {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));

        address actor = makeAddr("mv-mid-epoch-actor");
        vm.deal(actor, 50 ether);

        bytes32 atomId = _createAtom(actor, "mv-mid-epoch-atom");

        uint256 epoch = multiVault.currentEpoch();
        if (epoch == 0) {
            vm.warp(TrustBonding(payable(TRUST_BONDING_PROXY)).epochTimestampEnd(0) + 1);
            epoch = multiVault.currentEpoch();
        }
        uint256 previousEpoch = epoch - 1;

        _setMultiVaultTotalUtilization(previousEpoch, int256(1000 ether));
        _setMultiVaultTotalUtilization(epoch, int256(777 ether));

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        assertFalse(multiVault.hasRolledOverSystemUtilization(epoch));

        _depositIntoAtom(actor, atomId, 5 ether);

        assertEq(
            multiVault.totalUtilization(epoch),
            int256(782 ether),
            "upgrade safety guard must preserve existing current-epoch utilization"
        );
        assertTrue(multiVault.hasRolledOverSystemUtilization(epoch));
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

        CoreImplementations memory impls = _deployCoreImplementations();
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

        CoreImplementations memory impls = _deployCoreImplementations();
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

    /*//////////////////////////////////////////////////////////////
                    ATOM WALLET BEACON REGRESSION
    //////////////////////////////////////////////////////////////*/

    function test_atomWallet_beaconUpgrade_preservesState_andMalformedSigNoRevertPost() external {
        address creator = makeAddr("atom-wallet-creator");
        vm.deal(creator, 20 ether);

        bytes32 atomId = _createAtom(creator, "atom-wallet-regression-atom");

        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));
        AtomWalletState memory before = _captureAtomWalletState(atomWallet);

        // PRE-UPGRADE: malformed signature path reverts.
        bytes32 userOpHash = keccak256("core-upgrade-regression-malformed-op");

        vm.prank(ENTRY_POINT);
        vm.expectRevert();
        atomWallet.validateUserOp(_buildMalformedSignatureUserOperation(atomWalletAddress), userOpHash, 0);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // POST-UPGRADE: malformed signature must fail validation without reverting.
        vm.prank(ENTRY_POINT);
        uint256 validationData =
            atomWallet.validateUserOp(_buildMalformedSignatureUserOperation(atomWalletAddress), userOpHash, 0);
        assertEq(validationData, SIG_VALIDATION_FAILED);

        // Storage/state continuity across beacon implementation upgrade.
        _assertAtomWalletState(atomWallet, before);

        // Owner remains atomWarden before claim.
        assertEq(atomWallet.owner(), MultiVault(payable(MULTIVAULT_PROXY)).getAtomWarden());
    }

    function test_atomWallet_beaconUpgrade_preRejectsLegacyTimeWindow_postRejectsWithoutRevertAndAcceptsBound77()
        external
    {
        address creator = makeAddr("atom-wallet-s149-creator");
        vm.deal(creator, 20 ether);

        bytes32 atomId = _createAtom(creator, "atom-wallet-s149-regression-atom");
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        // Claim wallet ownership to a deterministic key so signatures can be generated in-test.
        uint256 ownerPrivateKey = 0xA11CE;
        address controlledOwner = vm.addr(ownerPrivateKey);
        address currentOwner = atomWallet.owner();

        vm.prank(currentOwner);
        atomWallet.transferOwnership(controlledOwner);
        vm.prank(controlledOwner);
        atomWallet.acceptOwnership();
        assertEq(atomWallet.owner(), controlledOwner);

        bytes32 userOpHash = keccak256("core-upgrade-regression-s149");
        uint48 originalValidUntil = uint48(block.timestamp + 1 days);
        uint48 tamperedValidUntil = uint48(block.timestamp + 30 days);
        uint48 validAfter = 0;

        bytes memory legacyRawSignature = _signUserOpHash(ownerPrivateKey, userOpHash);
        PackedUserOperation memory tamperedLegacyOp = _buildUserOperationWithSignature(
            atomWalletAddress, abi.encodePacked(legacyRawSignature, tamperedValidUntil, validAfter)
        );

        // PRE-UPGRADE (fork reality): legacy 77-byte signatures are rejected and revert.
        vm.prank(ENTRY_POINT);
        vm.expectRevert();
        atomWallet.validateUserOp(tamperedLegacyOp, userOpHash, 0);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // POST-UPGRADE: the same tampered legacy-format signature must fail without reverting.
        vm.prank(ENTRY_POINT);
        uint256 postValidation = atomWallet.validateUserOp(tamperedLegacyOp, userOpHash, 0);
        assertEq(postValidation, _packValidationData(true, tamperedValidUntil, validAfter));

        // 77-byte signatures remain valid when metadata is bound during signing.
        PackedUserOperation memory boundOp = _buildUserOperationWithSignature(
            atomWalletAddress,
            _signUserOpHashWithTimeWindow(ownerPrivateKey, userOpHash, originalValidUntil, validAfter)
        );

        vm.prank(ENTRY_POINT);
        uint256 boundValidation = atomWallet.validateUserOp(boundOp, userOpHash, 0);
        assertEq(boundValidation, _packValidationData(false, originalValidUntil, validAfter));
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

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        uint256 postAssets = curve.previewRedeem(sharesToRedeem, totalShares, 0);

        assertApproxEqAbs(postAssets, preAssets, 1, "production-config low-share redeem should remain stable");

        // Additional edge guard in current implementation for zero-offset local deployment.
        OffsetProgressiveCurve localCurve = _deployOffsetCurve("Local OPC Zero Offset", 2e18, 0);
        uint256 localAssets = localCurve.previewRedeem(sharesToRedeem, totalShares, 0);
        assertEq(localAssets, 0, "zero-offset low-share edge should not underflow");
    }

    /*//////////////////////////////////////////////////////////////
                    STORAGE CONTINUITY + SAFETY
    //////////////////////////////////////////////////////////////*/

    function test_storageContinuityAcrossUnisonUpgrade() external {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        OffsetProgressiveCurve curve = OffsetProgressiveCurve(payable(OFFSET_PROGRESSIVE_CURVE_PROXY));

        address actor = makeAddr("storage-actor");
        vm.deal(actor, 20 ether);

        bytes32 atomId = _createAtom(actor, "storage-continuity-atom");
        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);

        uint256 epoch = multiVault.currentEpoch();
        if (epoch == 0) {
            vm.warp(trustBonding.epochTimestampEnd(0) + 1);
            epoch = multiVault.currentEpoch();
        }

        // Seed known state values for continuity checks.
        _setMultiVaultTotalUtilization(epoch, int256(321 ether));
        _setMultiVaultPersonalUtilization(actor, epoch, int256(123 ether));
        vm.store(MULTIVAULT_PROXY, _multiVaultUserEpochHistorySlot(actor, 0), bytes32(epoch));
        StorageSnapshot memory before = _captureStorageSnapshot(actor, epoch, atomWalletAddress);

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        // Existing slots and mapping entries remain intact after implementation switch.
        _assertStorageSnapshot(before, actor, epoch, atomWalletAddress);

        // Slot 69 is part of the __gap (never used on mainnet), should remain zero.
        assertEq(vm.load(TRUST_BONDING_PROXY, bytes32(uint256(69))), bytes32(0));
        assertFalse(multiVault.hasRolledOverSystemUtilization(epoch));

        // Existing slots remain unchanged after upgrade.
        _assertTrustCoreSlots(before.tbCoreSlots);

        // Keep curve referenced to avoid compiler warnings in some optimization settings.
        assertTrue(address(curve) != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            POST-UPGRADE SMOKE
    //////////////////////////////////////////////////////////////*/

    function test_postUpgrade_coreSmokeFlows() external {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        OffsetProgressiveCurve curve = OffsetProgressiveCurve(payable(OFFSET_PROGRESSIVE_CURVE_PROXY));

        CoreImplementations memory impls = _deployCoreImplementations();
        _upgradeCoreInUnison(impls);

        address user = makeAddr("smoke-user");
        vm.deal(user, 20 ether);

        bytes32 atomId = _createAtom(user, "smoke-atom");
        uint256 shares = _depositIntoAtom(user, atomId, 1 ether);
        _redeemFromAtom(user, atomId, shares / 2);

        uint256 currentEpoch = trustBonding.currentEpoch();
        uint256 systemRatio = trustBonding.getSystemUtilizationRatio(currentEpoch);
        assertLe(systemRatio, trustBonding.BASIS_POINTS_DIVISOR());

        uint256 assetsPreview = curve.previewRedeem(699_560_508, 700_560_508, 0);
        assertGt(assetsPreview, 0);

        address atomWalletAddress = AtomWalletFactory(ATOM_WALLET_FACTORY).deployAtomWallet(atomId);
        AtomWallet atomWallet = AtomWallet(payable(atomWalletAddress));

        PackedUserOperation memory malformedOp = _buildMalformedSignatureUserOperation(atomWalletAddress);
        bytes32 userOpHash = keccak256("post-upgrade-smoke-malformed");

        vm.prank(ENTRY_POINT);
        uint256 validationData = atomWallet.validateUserOp(malformedOp, userOpHash, 0);
        assertEq(validationData, SIG_VALIDATION_FAILED);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _selectIntuitionFork() internal {
        vm.createSelectFork("intuition", INTUITION_FORK_BLOCK);
        // veTRUST checkpoints persist Base L2 `blk` values, while this fork executes on Intuition L3.
        // Rolling to a Base block keeps checkpoint-based block reads/actions from treating those blocks as "future".
        vm.roll(BASE_BLOCK_NUMBER);
    }

    function _ensureEpochAtLeastOne() internal {
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        if (trustBonding.currentEpoch() == 0) {
            vm.warp(trustBonding.epochTimestampEnd(0) + 1);
        }
    }

    function _deployCoreImplementations() internal returns (CoreImplementations memory impls) {
        impls.multiVault = address(new MultiVault());
        impls.trustBonding = address(new TrustBonding());
        impls.offsetProgressiveCurve = address(new OffsetProgressiveCurve());
        impls.atomWallet = address(new AtomWallet());
        impls.satelliteEmissionsController = address(new SatelliteEmissionsController());
    }

    function _upgradeCoreInUnison(CoreImplementations memory impls) internal {
        vm.startPrank(UPGRADES_TIMELOCK);

        ProxyAdmin(MULTIVAULT_PROXY_ADMIN)
            .upgradeAndCall(ITransparentUpgradeableProxy(payable(MULTIVAULT_PROXY)), impls.multiVault, bytes(""));

        ProxyAdmin(TRUST_BONDING_PROXY_ADMIN)
            .upgradeAndCall(ITransparentUpgradeableProxy(payable(TRUST_BONDING_PROXY)), impls.trustBonding, bytes(""));

        ProxyAdmin(OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(OFFSET_PROGRESSIVE_CURVE_PROXY)),
                impls.offsetProgressiveCurve,
                bytes("")
            );

        ProxyAdmin(SATELLITE_EMISSIONS_CONTROLLER_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(SATELLITE_EMISSIONS_CONTROLLER_PROXY)),
                impls.satelliteEmissionsController,
                bytes("")
            );

        UpgradeableBeacon(ATOM_WALLET_BEACON).upgradeTo(impls.atomWallet);

        vm.stopPrank();
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

    function _depositIntoAtom(address user, bytes32 atomId, uint256 amount) internal returns (uint256 shares) {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));

        vm.deal(user, user.balance + amount);
        vm.prank(user);
        shares = multiVault.deposit{ value: amount }(user, atomId, DEFAULT_CURVE_ID, 0);
    }

    function _redeemFromAtom(address user, bytes32 atomId, uint256 shares) internal returns (uint256 assetsReceived) {
        MultiVault multiVault = MultiVault(payable(MULTIVAULT_PROXY));

        vm.prank(user);
        assetsReceived = multiVault.redeem(user, atomId, DEFAULT_CURVE_ID, shares, 0);
    }

    function _createLock(address user, uint256 amount) internal {
        WrappedTrust wrappedTrust = WrappedTrust(payable(WRAPPED_TRUST));
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        vm.roll(BASE_BLOCK_NUMBER);

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

    function _setMultiVaultTotalUtilization(uint256 epoch, int256 value) internal {
        vm.store(MULTIVAULT_PROXY, _multiVaultTotalUtilizationSlot(epoch), bytes32(uint256(value)));
    }

    function _setMultiVaultPersonalUtilization(address user, uint256 epoch, int256 value) internal {
        vm.store(MULTIVAULT_PROXY, _multiVaultPersonalUtilizationSlot(user, epoch), bytes32(uint256(value)));
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

    function _captureStorageSnapshot(
        address actor,
        uint256 epoch,
        address atomWalletAddress
    )
        internal
        view
        returns (StorageSnapshot memory snapshot)
    {
        snapshot.mvSlot0 = vm.load(MULTIVAULT_PROXY, bytes32(uint256(0)));
        snapshot.mvTotalUtilization = vm.load(MULTIVAULT_PROXY, _multiVaultTotalUtilizationSlot(epoch));
        snapshot.mvPersonalUtilization = vm.load(MULTIVAULT_PROXY, _multiVaultPersonalUtilizationSlot(actor, epoch));
        snapshot.mvUserEpoch0 = vm.load(MULTIVAULT_PROXY, _multiVaultUserEpochHistorySlot(actor, 0));

        snapshot.tbCoreSlots = _loadTrustCoreSlots();
        snapshot.atomWalletCoreSlots = _loadSlots3(atomWalletAddress, 0);
        snapshot.offsetCurveCoreSlots = _loadSlots5(OFFSET_PROGRESSIVE_CURVE_PROXY, 1);
    }

    function _assertStorageSnapshot(
        StorageSnapshot memory expected,
        address actor,
        uint256 epoch,
        address atomWalletAddress
    )
        internal
        view
    {
        assertEq(vm.load(MULTIVAULT_PROXY, bytes32(uint256(0))), expected.mvSlot0);
        assertEq(vm.load(MULTIVAULT_PROXY, _multiVaultTotalUtilizationSlot(epoch)), expected.mvTotalUtilization);
        assertEq(
            vm.load(MULTIVAULT_PROXY, _multiVaultPersonalUtilizationSlot(actor, epoch)), expected.mvPersonalUtilization
        );
        assertEq(vm.load(MULTIVAULT_PROXY, _multiVaultUserEpochHistorySlot(actor, 0)), expected.mvUserEpoch0);

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

    function _multiVaultTotalUtilizationSlot(uint256 epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(epoch, uint256(30)));
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
