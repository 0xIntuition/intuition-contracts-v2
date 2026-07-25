// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseAccount } from "@account-abstraction/core/BaseAccount.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Test } from "forge-std/src/Test.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";

contract FrontierRoundWalletMultiVaultMock {
    address internal immutable ATOM_WARDEN;

    constructor(address atomWarden) {
        ATOM_WARDEN = atomWarden;
    }

    function getAtomWarden() external view returns (address) {
        return ATOM_WARDEN;
    }
}

/// @dev Minimal storage-faithful copy of the pre-v1.1 AtomWallet ownership surface.
contract FrontierRoundLegacyAtomWallet is
    Initializable,
    BaseAccount,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public multiVault;
    IEntryPoint private _entryPoint;
    bool public isClaimed;
    bytes32 public termId;
    uint256[50] private __gap;

    constructor() {
        _disableInitializers();
    }

    function initialize(address entryPointAddress, address multiVaultAddress, bytes32 atomId) external initializer {
        __Ownable_init(FrontierRoundWalletMultiVaultMock(multiVaultAddress).getAtomWarden());
        __ReentrancyGuard_init();

        _entryPoint = IEntryPoint(entryPointAddress);
        multiVault = multiVaultAddress;
        termId = atomId;
    }

    function acceptOwnership() public override {
        isClaimed = true;
        super.acceptOwnership();
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    function _validateSignature(PackedUserOperation calldata, bytes32)
        internal
        pure
        override
        returns (uint256 validationData)
    {
        return 1;
    }
}

contract FrontierRound_WalletUpgradeTest is Test {
    bytes32 internal constant ATOM_ID = keccak256("frontier-wallet-upgrade-atom");
    uint256 internal constant CLAIMANT_PRIVATE_KEY = 0xC1A1;
    uint256 internal constant WALLET_BALANCE = 5 ether;
    uint256 internal constant TRANSFER_AMOUNT = 1 ether;

    address internal constant ATOM_WARDEN = address(0xA701);
    address internal constant ENTRY_POINT = address(0xE170);
    address internal constant RECIPIENT = address(0xBEEF);

    bytes32 internal constant OWNABLE_STORAGE_LOCATION =
        0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
    bytes32 internal constant MULTI_OWNABLE_STORAGE_LOCATION =
        0x97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f00;

    UpgradeableBeacon internal atomWalletBeacon;
    AtomWallet internal atomWallet;
    address internal claimant;

    function setUp() external {
        claimant = vm.addr(CLAIMANT_PRIVATE_KEY);

        FrontierRoundWalletMultiVaultMock multiVault = new FrontierRoundWalletMultiVaultMock(ATOM_WARDEN);
        FrontierRoundLegacyAtomWallet legacyImplementation = new FrontierRoundLegacyAtomWallet();
        atomWalletBeacon = new UpgradeableBeacon(address(legacyImplementation), address(this));

        bytes memory initializationData =
            abi.encodeCall(FrontierRoundLegacyAtomWallet.initialize, (ENTRY_POINT, address(multiVault), ATOM_ID));
        BeaconProxy proxy = new BeaconProxy(address(atomWalletBeacon), initializationData);
        FrontierRoundLegacyAtomWallet legacyWallet = FrontierRoundLegacyAtomWallet(payable(address(proxy)));

        vm.startPrank(ATOM_WARDEN);
        legacyWallet.transferOwnership(claimant);
        vm.stopPrank();

        vm.startPrank(claimant);
        legacyWallet.acceptOwnership();
        vm.stopPrank();

        assertTrue(legacyWallet.isClaimed());
        assertEq(legacyWallet.owner(), claimant);

        vm.deal(address(proxy), WALLET_BALANCE);

        AtomWallet newImplementation = new AtomWallet();
        atomWalletBeacon.upgradeTo(address(newImplementation));
        atomWallet = AtomWallet(payable(address(proxy)));
    }

    function test_beaconUpgrade_claimedLegacyWalletPreservesOwnerAndExecution() external {
        assertTrue(atomWallet.isClaimed());
        assertEq(atomWallet.owner(), claimant);
        assertEq(atomWallet.ownerCount(), 0);
        assertFalse(atomWallet.isOwnerAddress(claimant));

        address legacyOwner = address(uint160(uint256(vm.load(address(atomWallet), OWNABLE_STORAGE_LOCATION))));
        assertEq(legacyOwner, claimant);
        assertEq(vm.load(address(atomWallet), MULTI_OWNABLE_STORAGE_LOCATION), bytes32(0));

        vm.startPrank(claimant);
        atomWallet.execute(RECIPIENT, TRANSFER_AMOUNT, "");
        vm.stopPrank();

        assertEq(address(atomWallet).balance, WALLET_BALANCE - TRANSFER_AMOUNT);
        assertEq(RECIPIENT.balance, TRANSFER_AMOUNT);
        assertEq(atomWallet.owner(), claimant);
        assertEq(atomWallet.ownerCount(), 1);
        assertTrue(atomWallet.isOwnerAddress(claimant));
    }

    function test_beaconUpgrade_claimedLegacyOwnerCanExplicitlyMigrate() external {
        vm.startPrank(claimant);
        atomWallet.migrateLegacyOwner();
        vm.stopPrank();

        assertEq(atomWallet.owner(), claimant);
        assertEq(atomWallet.ownerCount(), 1);
        assertTrue(atomWallet.isOwnerAddress(claimant));
    }

    function test_beaconUpgrade_transferOwnershipMigratesBeforeRotation() external {
        address newOwner = makeAddr("newOwner");

        vm.startPrank(claimant);
        atomWallet.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(atomWallet.owner(), newOwner);
        assertEq(atomWallet.ownerCount(), 1);
        assertFalse(atomWallet.isOwnerAddress(claimant));
        assertTrue(atomWallet.isOwnerAddress(newOwner));
    }
}
